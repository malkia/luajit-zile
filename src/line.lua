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

-- If point is greater than fill-column, then split the line at the
-- right-most space character at or before fill-column, if there is
-- one, or at the left-most at or after fill-column, if not. If the
-- line contains no spaces, no break is made.
--
-- Return flag indicating whether break was made.
function fill_break_line ()
  local i, old_col
  local break_col = 0
  local fillcol = get_variable_number ("fill-column")
  local break_made = false

  -- Only break if we're beyond fill-column.
  if get_goalc () > fillcol then
    -- Save point.
    local m = point_marker ()

    -- Move cursor back to fill column
    old_col = cur_bp.pt.o
    while get_goalc () > fillcol + 1 do
      cur_bp.pt.o = cur_bp.pt.o - 1
    end

    -- Find break point moving left from fill-column.
    for i = cur_bp.pt.o, 1, -1 do
      if isspace (cur_bp.pt.p.text[i]) then
        break_col = i
        break
      end
    end

    -- If no break point moving left from fill-column, find first
    -- possible moving right.
    if break_col == 0 then
      for i = cur_bp.pt.o + 1, #cur_bp.pt.p.text do
        if isspace (cur_bp.pt.p.text[i]) then
          break_col = i
          break
        end
      end
    end

    if break_col >= 1 then -- Break line.
      cur_bp.pt.o = break_col
      execute_function ("delete-horizontal-space")
      insert_newline ()
      cur_bp.pt = table.clone (m.pt)
      break_made = true
    else -- Undo fiddling with point.
      cur_bp.pt.o = old_col
    end

    unchain_marker (m)
  end

  return break_made
end

-- Insert a newline at the current position without moving the cursor.
-- Update markers after point in the split line.
local function intercalate_newline ()
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

local function backward_delete_char ()
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

-- Indentation command
-- Go to cur_goalc () in the previous non-blank line.
local function previous_nonblank_goalc ()
  local cur_goalc = get_goalc ()

  -- Find previous non-blank line.
  while execute_function ("forward-line", -1, true) == leT and is_blank_line () do
  end

  -- Go to `cur_goalc' in that non-blank line.
  while not eolp () and get_goalc () < cur_goalc do
    forward_char ()
  end
end

local function previous_line_indent ()
  local cur_indent
  local m = point_marker ()

  execute_function ("previous-line")
  execute_function ("beginning-of-line")

  -- Find first non-blank char.
  while not eolp () and isspace (following_char ()) do
    forward_char ()
  end

  cur_indent = get_goalc ()

  -- Restore point.
  cur_bp.pt = table.clone (m.pt)
  unchain_marker (m)

  return cur_indent
end

Defun ("indent-for-tab-command",
       {},
[[
Indent line or insert a tab.
Depending on `tab-always-indent', either insert a tab or indent.
If initial point was within line's indentation, position after
the indentation.  Else stay at same point in text.
]],
  true,
  function ()
    if get_variable_bool ("tab-always-indent") then
      return bool_to_lisp (insert_tab ())
    elseif (get_goalc () < previous_line_indent ()) then
      return execute_function ("indent-relative")
    end
  end
)

Defun ("indent-relative",
       {},
[[
Space out to under next indent point in previous nonblank line.
An indent point is a non-whitespace character following whitespace.
The following line shows the indentation points in this line.
    ^         ^    ^     ^   ^           ^      ^  ^    ^
If the previous nonblank line has no indent points beyond the
column point starts at, `tab-to-tab-stop' is done instead, unless
this command is invoked with a numeric argument, in which case it
does nothing.
]],
  true,
  function ()
    local target_goalc = 0
    local cur_goalc = get_goalc ()
    local t = tab_width (cur_bp)
    local ok = leNIL

    if warn_if_readonly_buffer () then
      return leNIL
    end

    deactivate_mark ()

    -- If we're on first line, set target to 0.
    if cur_bp.pt.p.prev == cur_bp.lines then
      target_goalc = 0
    else
      -- Find goalc in previous non-blank line.
      local m = point_marker ()

      previous_nonblank_goalc ()

      -- Now find the next blank char.
      if preceding_char () ~= '\t' or get_goalc () <= cur_goalc then
        while not eolp () and not isspace (following_char ()) do
          forward_char ()
        end
      end

      -- Find next non-blank char.
      while not eolp () and isspace (following_char ()) do
        forward_char ()
      end

      -- Target column.
      if not eolp () then
        target_goalc = get_goalc ()
      end
      cur_bp.pt = table.clone (m.pt)
      unchain_marker (m)
    end

    -- Insert indentation.
    undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
    if target_goalc > 0 then
      -- If not at EOL on target line, insert spaces & tabs up to
      -- target_goalc; if already at EOL on target line, insert a tab.
      cur_goalc = get_goalc ()
      if cur_goalc < target_goalc then
        repeat
          if cur_goalc % t == 0 and cur_goalc + t <= target_goalc then
            ok = bool_to_lisp (insert_tab ())
          else
            ok = bool_to_lisp (insert_char_in_insert_mode (' '))
          end
          cur_goalc = get_goalc ()
        until ok ~= leT or cur_goalc >= target_goalc
      else
        ok = bool_to_lisp (insert_tab ())
      end
    else
      ok = bool_to_lisp (insert_tab ())
    end
    undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  end
)

Defun ("newline-and-indent",
       {},
[[
Insert a newline, then indent.
Indentation is done using the `indent-for-tab-command' function.
]],
  true,
  function ()
    local ret

    local ok = leNIL

    if warn_if_readonly_buffer () then
      return leNIL
    end

    deactivate_mark ()

    undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
    if insert_newline () then
      local m = point_marker ()
      local pos

      -- Check where last non-blank goalc is.
      previous_nonblank_goalc ()
      pos = get_goalc ()
      local indent = pos > 0 or (not eolp () and isspace (following_char ()))
      cur_bp.pt = table.clone (m.pt)
      unchain_marker (m)
      -- Only indent if we're in column > 0 or we're in column 0 and
      -- there is a space character there in the last non-blank line.
      if indent then
        execute_function ("indent-for-tab-command")
      end
      ok = leT
    end
    undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  end
)

-- Check the case of a string.
-- Returns "uppercase" if it is all upper case, "capitalized" if just
-- the first letter is, and nil otherwise.
local function check_case (s)
  if string.match (s, "^%u+$") then
    return "uppercase"
  elseif string.match (s, "^%u%U*") then
    return "capitalized"
  end
end

-- Replace text in the line "lp" with "newtext". If "replace_case" is
-- true then the new characters will be the same case as the old.
function line_replace_text (lp, offset, oldlen, newtext, replace_case)
  if replace_case and get_variable_bool ("case-replace") then
    local case_type = check_case (string.sub (lp.text, offset, offset + oldlen))
    if case_type then
      astr_recase (newtext, case_type)
    end
  end

  cur_bp.modified = true
  lp.text = string.sub (lp.text, 1, offset) .. newtext .. string.sub (lp.text, offset + 1 + oldlen)
  adjust_markers (lp, lp, offset, 0, #newtext - oldlen)
end


Defun ("delete-char",
       {"number"},
[[
Delete the following @i{n} characters (previous if @i{n} is negative).
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, delete_char, backward_delete_char)
  end
)

Defun ("backward-delete-char",
       {"number"},
[[
Delete the previous @i{n} characters (following if @i{n} is negative).
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, cur_bp.overwrite and backward_delete_char_overwrite or backward_delete_char, delete_char)
  end
)

Defun ("delete-horizontal-space",
       {},
[[
Delete all spaces and tabs around point.
]],
  true,
  function ()
    undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)

    while not eolp () and isspace (following_char ()) do
      delete_char ()
    end

    while not bolp () and isspace (preceding_char ()) do
      backward_delete_char ()
    end

    undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  end
)

Defun ("just-one-space",
       {},
[[
Delete all spaces and tabs around point, leaving one space.
]],
  true,
  function ()
    undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
    execute_function ("delete-horizontal-space")
    insert_char_in_insert_mode (' ')
    undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  end
)

Defun ("tab-to-tab-stop",
       {"number"},
[[
Insert a tabulation at the current point position into the current
buffer.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, insert_tab)
  end
)

local function newline ()
  if cur_bp.autofill and get_goalc () > get_variable_number ("fill-column") then
    fill_break_line ()
  end
  return insert_newline ()
end

Defun ("newline",
       {"number"},
[[
Insert a newline at the current point position into
the current buffer.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, newline)
  end
)

Defun ("open-line",
       {"number"},
[[
Insert a newline and leave point before it.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, intercalate_newline)
  end
)

Defun ("insert",
       {"string"},
[[
Insert the argument at point.
]],
  true,
  function (arg)
    insert_string (arg)
  end
)
