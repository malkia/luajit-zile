-- Create an empty list, returning a pointer to the list
function line_new ()
  local l = {}
  l.next = l
  l.prev = l
  return l
end

-- Remove a line from a list.
function line_remove (l)
  l.prev.next = l.next
  l.next.prev = l.prev
end

-- Insert a line into list after the given point, returning the new line
function line_insert (l, s)
  local n = line_new ()
  n.next = l.next
  n.prev = l
  n.text = s
  l.next.prev = n
  l.next = n

  return n
end

-- Adjust markers (including point) when line at point is split, or
-- next line is joined on, or where a line is edited.
--   newlp is the line to which characters were moved, oldlp the line
--    moved from (if dir == 0, newlp == oldlp)
--   pointo is point at which oldlp was split (to make newlp) or
--     joined to newlp
--   dir is 1 for split, -1 for join or 0 for line edit (newlp == oldlp)
--   if dir == 0, delta gives the number of characters inserted (>0) or
--     deleted (<0)
local function adjust_markers (newlp, oldlp, pointo, dir, delta)
  local m_pt = point_marker ()

  assert (dir == -1 or dir == 0 or dir == 1)

  local m = cur_bp.markers
  while m do
    if m.pt.p == oldlp and (dir == -1 or m.pt.o > pointo) then
      m.pt.p = newlp
      m.pt.o = m.pt.o + delta - (pointo * dir)
      m.pt.n = m.pt.n + dir
    elseif m.pt.n > cur_bp.pt.n then
      m.pt.n = m.pt.n + dir
    end
    m = m.next
  end

  -- This marker has been updated to new position.
  cur_bp.pt = table.clone (m_pt.pt)
  unchain_marker (m_pt)
end

-- Insert the character at the current position and move the text at its right
-- whatever the insert/overwrite mode is.
-- This function doesn't change the current position of the pointer.
local function intercalate_char (c)
  if warn_if_readonly_buffer () then
    return false
  end

  local as = cur_bp.pt.p.text
  undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 0, 1)
  as = string.sub (as, 1, cur_bp.pt.o) .. c .. string.sub (as, cur_bp.pt.o + 1)
  cur_bp.pt.p.text = as
  cur_bp.modified = true

  return true
end

-- Insert the character `c' at the current point position
-- into the current buffer.
function insert_char (c)
  local t = tab_width (cur_bp)

  if warn_if_readonly_buffer () then
    return false
  end

  if cur_bp.overwrite then
    local pt = cur_bp.pt
    -- (Current character isn't the end of line or a \t) or
    -- (current character is a \t and we are in the tab limit).
    if pt.o < #pt.p.text and string.sub (pt.p.text, pt.o + 1, pt.o + 1) ~= '\t' or
      string.sub (pt.p.text, pt.o + 1, pt.o + 1) == '\t' and get_goalc () % t == t then
      -- Replace the character.
      undo_save (UNDO_REPLACE_BLOCK, pt, 1, 1)
      pt.p.text = string.sub (pt.p.text, 1, pt.o) .. c .. string.sub (pt.p.text, pt.o + 2)
      pt.o = pt.o + 1
      cur_bp.modified = true

      return true
    end
    -- Fall through to insertion mode of a character at the end
    -- of the line, since it is the same as overwrite mode.
  end

  intercalate_char (c)
  forward_char ()
  adjust_markers (cur_bp.pt.p, cur_bp.pt.p, cur_bp.pt.o, 0, 1)

  return true
end

-- Insert a character at the current position in insert mode
-- whatever the current insert mode is.
function insert_char_in_insert_mode (c)
  local old_overwrite = cur_bp.overwrite

  cur_bp.overwrite = false
  local ret = insert_char (c)
  cur_bp.overwrite = old_overwrite

  return ret
end

function insert_string (s)
  local i
  undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 0, #s)
  undo_nosave = true
  for i = 1, #s do
    if string.sub (s, i, i) == '\n' then
      insert_newline ()
    else
      insert_char_in_insert_mode (string.sub (s, i, i))
    end
  end
  undo_nosave = false
end

-- Insert a newline at the current position without moving the cursor.
-- Update markers after point in the split line.
-- FIXME: local
function intercalate_newline ()
  if warn_if_readonly_buffer () then
    return false
  end

  undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 0, 1)

  -- Move the text after the point into a new line.
  line_insert (cur_bp.pt.p, string.sub (cur_bp.pt.p.text, cur_bp.pt.o + 1))
  cur_bp.last_line = cur_bp.last_line + 1
  cur_bp.pt.p.text = string.sub (cur_bp.pt.p.text, 1, cur_bp.pt.o)
  adjust_markers (cur_bp.pt.p.next, cur_bp.pt.p, cur_bp.pt.o, 1, 0)

  cur_bp.modified = true
  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)

  return true
end

function insert_newline ()
  return intercalate_newline () and forward_char ()
end

local function insert_expanded_tab (inschr)
  local c = get_goalc ()
  local t = tab_width (cur_bp)

  undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)

  for c = t - c % t, 1, -1 do
    inschr (' ')
  end

  undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
end

local function insert_tab ()
  if warn_if_readonly_buffer () then
    return false
  end

  if get_variable_bool ("indent-tabs-mode") then
    insert_char_in_insert_mode ('\t')
  else
    insert_expanded_tab (insert_char_in_insert_mode)
  end

  return true
end

function delete_char ()
  deactivate_mark ()

  if eobp () then
    minibuf_error ("End of buffer")
    return false
  end

  if warn_if_readonly_buffer () then
    return false
  end

  undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 1, 0)

  if eolp () then
    local oldlen = #cur_bp.pt.p.text
    local oldlp = cur_bp.pt.p.next

    -- Join the lines.
    local as = cur_bp.pt.p.text
    local bs = oldlp.text
    as = as .. bs
    cur_bp.pt.p.text = as
    line_remove (oldlp)

    adjust_markers (cur_bp.pt.p, oldlp, oldlen, -1, 0)
    cur_bp.last_line = cur_bp.last_line - 1
    thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
  else
    local as = cur_bp.pt.p.text
    as = string.sub (as, 1, cur_bp.pt.o) .. string.sub (as, cur_bp.pt.o + 2)
    cur_bp.pt.p.text = as
    adjust_markers (cur_bp.pt.p, cur_bp.pt.p, cur_bp.pt.o, 0, -1)
  end

  cur_bp.modified = true

  return true
end

-- FIXME: local
function backward_delete_char ()
  deactivate_mark ()

  if not backward_char () then
    minibuf_error ("Beginning of buffer")
    return false
  end

  delete_char ()
  return true
end

local function backward_delete_char_overwrite ()
  if bolp () or eolp () then
    return backward_delete_char ()
  end

  deactivate_mark ()

  if warn_if_readonly_buffer () then
    return false
  end

  backward_char ()
  if following_char () == '\t' then
    insert_expanded_tab (insert_char)
  else
    insert_char (' ')
  end
  backward_char ()

  return true
end
