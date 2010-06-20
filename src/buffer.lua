-- Allocate a new buffer, set the default local variable values, and
-- insert it into the buffer list.
-- The allocation of the first empty line is done here to simplify
-- the code.
function buffer_new ()
  local bp = {}

  -- Allocate point.
  bp.pt = point_new ()

  -- Allocate a line.
  bp.pt.p = line_new ()
  bp.pt.p.text = ""

  -- Allocate the limit marker.
  bp.lines = line_new ()
  bp.lines.prev = bp.pt.p
  bp.lines.next = bp.pt.p
  bp.pt.p.prev = bp.lines
  bp.pt.p.next = bp.lines
  bp.last_line = 0

  -- Set default EOL string.
  bp.eol = coding_eol_lf

  -- Insert into buffer list.
  bp.next = head_bp
  head_bp = bp

  init_buffer (bp)

  return bp
end

-- Free the buffer's allocated memory.
function free_buffer (bp)
  while bp.markers do
    unchain_marker (bp.markers)
  end
end

-- Initialise a buffer
function init_buffer (bp)
  if get_variable_bool ("auto-fill-mode") then
    bp.autofill = true
  end
end

function activate_mark ()
  cur_bp.mark_active = true
end

function deactivate_mark ()
  cur_bp.mark_active = false
end

-- Return a safe tab width for the given buffer.
function tab_width (bp)
  return math.max (get_variable_number_bp (bp, "tab-width"), 1)
end

-- Copy a region of text into a string.
function copy_text_block (pt, size)
  local lp = pt.p
  local s = string.sub (lp.text, pt.o) .. "\n"

  lp = lp.next
  while #s < size do
    s = s .. lp.text .. "\n"
    lp = lp.next
  end

  return string.sub (s, 1, size)
end

function in_region (lineno, x, rp)
  if lineno < rp.start.n or lineno > rp.finish.n then
    return false
  elseif rp.start.n == rp.finish.n then
    return x >= rp.start.o and x < rp.finish.o
  elseif lineno == rp.start.n then
    return x >= rp.start.o
  elseif lineno == rp.finish.n then
    return x < rp.finish.o
  else
    return true
  end
  return false
end

-- Move the selected buffer to head.
function move_buffer_to_head (bp)
  local it = head_bp
  local prev
  while it do
    if bp == it then
      if prev then
        prev.next = bp.next
        bp.next = head_bp
        head_bp = bp
        break
      end
    end
    prev = it
    it = it.next
  end
end

-- Switch to the specified buffer.
function switch_to_buffer (bp)
  assert (cur_wp.bp == cur_bp)

  -- The buffer is the current buffer; return safely.
  if cur_bp == bp then
    return
  end

  -- Set current buffer.
  cur_bp = bp
  cur_wp.bp = cur_bp

  -- Move the buffer to head.
  move_buffer_to_head (bp)

  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
end

-- Search for a buffer named `name'.
function find_buffer (name)
  local bp = head_bp
  while bp do
    if bp.name == name then
      return bp
    end
    bp = bp.next
  end
end

-- Remove the specified buffer from the buffer list and deallocate
-- its space.  Recreate the scratch buffer when required.
function kill_buffer (kill_bp)
  local next_bp
  if kill_bp.next ~= nil then
    next_bp = kill_bp.next
  else
    if kill_bp == head_bp then
      next_bp = nil
    else
      next_bp = head_bp
    end
  end

  -- Search for windows displaying the buffer to kill.
  local wp = head_wp
  while wp do
    if wp.bp == kill_bp then
      wp.bp = next_bp
      wp.topdelta = 0
      wp.saved_pt = nil
    end
    wp = wp.next
  end

  -- Remove the buffer from the buffer list.
  if cur_bp == kill_bp then
    cur_bp = next_bp
  end
  if head_bp == kill_bp then
    head_bp = head_bp.next
  end
  local bp = head_bp
  while bp and bp.next do
    if bp.next == kill_bp then
      bp.next = bp.next.next
      break
    end
    bp = bp.next
  end

  free_buffer (kill_bp)

  -- If no buffers left, recreate scratch buffer and point windows at
  -- it.
  if next_bp == nil then
    next_bp = create_scratch_buffer ()
    cur_bp = next_bp
    head_bp = next_bp
    local wp = head_wp
    while wp do
      wp.bp = head_bp
      wp = wp.next
    end
  end

  -- Resync windows that need it.
  local wp = head_wp
  while wp do
    if wp.bp == next_bp then
      resync_redisplay (wp)
    end
    wp = wp.next
  end
end

-- Set the specified buffer temporary flag and move the buffer
-- to the end of the buffer list.
function set_temporary_buffer (bp)
  bp.temporary = true

  if bp == head_bp then
    if head_bp.next == nil then
      return
    end
    head_bp = head_bp.next
  elseif bp.next == nil then
    return
  end

  local bp0 = head_bp
  while bp0 do
    if bp0.next == bp then
      bp0.next = bp0.next.next
      break
    end
    bp0 = bp0.next
  end

  local bp0 = head_bp
  while bp0.next do
    bp0 = bp0.next
  end

  bp0.next = bp
  bp.next = nil
end

-- Print an error message into the echo area and return true
-- if the current buffer is readonly; otherwise return false.
function warn_if_readonly_buffer ()
  if cur_bp.readonly then
    minibuf_error (string.format ("Buffer is readonly: %s", cur_bp.name))
    return true
  end

  return false
end
