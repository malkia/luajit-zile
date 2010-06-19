function write_temp_buffer (name, show, func, ...)
  local old_wp = cur_wp
  local old_bp = cur_bp

  -- Popup a window with the buffer "name".
  local wp = find_window (name)
  if show and wp then
    set_current_window (wp)
  else
    local bp = find_buffer (name)
    if show then
      set_current_window (popup_window ())
    end
    if bp == nil then
      bp = buffer_new ()
      bp.name = name
    end
    switch_to_buffer (bp)
  end

  -- Remove the contents of that buffer.
  local new_bp = buffer_new ()
  new_bp.name = cur_bp.name
  kill_buffer (cur_bp)
  cur_bp = new_bp
  cur_wp.bp = cur_bp

  -- Make the buffer a temporary one.
  cur_bp.needname = true
  cur_bp.noundo = true
  cur_bp.nosave = true
  set_temporary_buffer (cur_bp)

  -- Use the "callback" routine.
  func (...)

  gotobob ()
  cur_bp.readonly = true
  cur_bp.modified = false

  -- Restore old current window.
  set_current_window (old_wp)

  -- If we're not showing the new buffer, switch back to the old one.
  if not show then
    switch_to_buffer (old_bp)
  end
end
