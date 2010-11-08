-- Buffer-oriented functions
--
-- Copyright (c) 2010 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- GNU Zile is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- GNU Zile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with GNU Zile; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.

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

-- Get filename, or buffer name if nil.
function get_buffer_filename_or_name (bp)
  return bp.filename or bp.name
end

function activate_mark ()
  cur_bp.mark_active = true
end

function deactivate_mark ()
  cur_bp.mark_active = false
end

function delete_region (rp)
  local m = point_marker ()

  if warn_if_readonly_buffer () then
    return false
  end

  goto_point (rp.start)
  undo_save (UNDO_REPLACE_BLOCK, rp.start, rp.size, 0)
  undo_nosave = true
  for i = rp.size, 1, -1 do
    delete_char ()
  end
  undo_nosave = false
  cur_bp.pt = table.clone (m.pt)
  unchain_marker (m)

  return true
end

function calculate_buffer_size (bp)
  local lp = bp.lines.next
  local size = 0

  if lp == bp.lines then
    return 0
  end

  while true do
    size = size + #lp.text
    lp = lp.next
    if lp == bp.lines then
      break
    end
    size = size + 1
  end

  return size
end

-- Return a safe tab width for the given buffer.
function tab_width (bp)
  return math.max (get_variable_number_bp (bp, "tab-width"), 1)
end

-- Copy a region of text into a string.
function copy_text_block (pt, size)
  local lp = pt.p
  local s = string.sub (lp.text, pt.o + 1) .. "\n"

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

local function warn_if_no_mark ()
  if not cur_bp.mark then
    minibuf_error ("The mark is not set now")
    return true
  elseif not cur_bp.mark_active and get_variable_bool ("transient-mark-mode") then
    minibuf_error ("The mark is not active now")
    return true
  end
  return false
end

function region_new ()
  return {}
end

-- Calculate the region size between point and mark and set the
-- region.
function calculate_the_region (rp)
  if warn_if_no_mark () then
    return false
  end

  if cmp_point (cur_bp.pt, cur_bp.mark.pt) < 0 then
    -- Point is before mark.
    rp.start = table.clone (cur_bp.pt)
    rp.finish = table.clone (cur_bp.mark.pt)
  else
    -- Mark is before point.
    rp.start = table.clone (cur_bp.mark.pt)
    rp.finish = table.clone (cur_bp.pt)
  end

  local size = rp.finish.o - rp.start.o
  local lp = rp.start.p
  while lp ~= rp.finish.p do
    size = size + #lp.text + 1
    lp = lp.next
  end

  rp.size = size
  return true
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

-- Create a buffer name using the file name.
local function make_buffer_name (filename)
  local s = posix.basename (filename)

  if not find_buffer (s) then
    return s
  else
    local i = 2
    while true do
      local name = string.format ("%s<%ld>", p, i)
      if not find_buffer (name) then
        return name
      end
      i = i + 1
    end
  end
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

-- Set a new filename, and from it a name, for the buffer.
function set_buffer_names (bp, filename)
  if filename[1] ~= '/' then
      filename = posix.getcwd () .. "/" .. filename
      bp.filename = filename
  else
    bp.filename = filename
  end

  bp.name = make_buffer_name (filename)
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

function activate_mark ()
  cur_bp.mark_active = true
end

function deactivate_mark ()
  cur_bp.mark_active = false
end

-- Check if the buffer has been modified.  If so, asks the user if
-- he/she wants to save the changes.  If the response is positive, return
-- true, else false.
function check_modified_buffer (bp)
  if bp.modified and not bp.nosave then
    while true do
      local ans = minibuf_read_yesno (string.format ("Buffer %s modified; kill anyway? (yes or no) ", bp.name))
      if ans == nil then
        execute_function ("keyboard-quit")
        return false
      elseif not ans then
        return false
      end
      break
    end
  end

  return true
end


Defun ("kill-buffer",
       {"string"},
[[
Kill buffer BUFFER.
With a nil argument, kill the current buffer.
]],
  true,
  function (buffer)
    local ok = leT

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read_completion (string.format ("Kill buffer (default %s): ", cur_bp.name), "", cp)
      if not buffer then
        ok = execute_command ("keyboard-quit")
      end
    end

    local bp
    if buffer and buffer ~= "" then
      bp = find_buffer (buffer)
      if not bp then
        minibuf_error (string.format ("Buffer `%s' not found", buffer))
        ok = leNIL
      end
    else
      bp = cur_bp
    end

    if ok == leT then
      if not check_modified_buffer (bp) then
        ok = leNIL
      else
        kill_buffer (bp)
      end
    end

    return ok
  end
)

Defun ("switch-to-buffer",
       {"string"},
[[
Select buffer @i{buffer} in the current window.
]],
  true,
  function (buffer)
    local ok = leT
    local bp = cur_bp.next or head_bp

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read_completion (string.format ("Switch to buffer (default %s): ", bp.name), "", cp)

      if not buffer then
        ok = execute_function ("keyboard-quit")
      end
    end

    if ok == leT then
      if buffer and buffer ~= "" then
        bp = find_buffer (buffer)
        if not bp then
          bp = buffer_new ()
          bp.name = buffer
          bp.needname = true
          bp.nosave = true
        end
      end

      switch_to_buffer (bp)
    end

    return ok
  end
)

function create_scratch_buffer ()
  local bp = buffer_new ()
  bp.name = "*scratch*"
  bp.needname = true
  bp.temporary = true
  bp.nosave = true
  return bp
end
