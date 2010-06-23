-- Signal an error, and abort any ongoing macro definition.
function ding ()
  if bit.band (thisflag, FLAG_DEFINING_MACRO) ~= 0 then
    cancel_kbd_macro ()
  end

  if get_variable_bool ("ring-bell") and cur_wp then
    term_beep ()
  end
end

-- Return true if point is at the beginning of the buffer.
function bobp ()
  return cur_bp.pt.p.prev == cur_bp.lines and bolp ()
end

-- Return true if point is at the end of the buffer.
function eobp (void)
  return cur_bp.pt.p.next == cur_bp.lines and eolp ()
end

-- Return true if point is at the beginning of a line.
function bolp ()
  return cur_bp.pt.o == 0
end

-- Return true if point is at the end of a line.
function eolp ()
  return cur_bp.pt.o == #cur_bp.pt.p.text
end

-- Set the mark to point.
function set_mark ()
  if cur_bp.mark == nil then
    cur_bp.mark = point_marker ()
  else
    move_marker (cur_bp.mark, cur_bp, table.clone (cur_bp.pt))
  end
end
