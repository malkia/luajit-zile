local function move_char (dir)
  if (dir > 0 and not eolp ()) or (dir < 0 and not bolp ()) then
    cur_bp.pt.o = cur_bp.pt.o + dir
    return true
  elseif (dir > 0 and not eobp ()) or (dir < 0 and not bobp ()) then
    thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
    if dir > 0 then
      cur_bp.pt.p = cur_bp.pt.p.next
    else
      cur_bp.pt.p = cur_bp.pt.p.prev
    end
    cur_bp.pt.n = cur_bp.pt.n + dir
    if dir > 0 then
      call_zile_command ("beginning-of-line")
    else
      call_zile_command ("end-of-line")
    end
    return true
  end

  return false
end

function backward_char ()
  return move_char (-1)
end

function forward_char ()
  return move_char (1)
end

-- Get the goal column, expanding tabs.
function get_goalc_bp (bp, pt)
  local col = 0
  local t = tab_width (bp)

  for i = 1, math.min (pt.o, #pt.p.text) do
    if string.sub (pt.p.text, i, 1) == '\t' then
      col = bit.bor (col, t - 1)
    end
    col = col + 1
  end

  return col
end

function get_goalc ()
  return get_goalc_bp (cur_bp, cur_bp.pt)
end

-- Move point to the beginning of the buffer; do not touch the mark.
function gotobob ()
  cur_bp.pt = point_min ()
  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
end

-- Move point to the end of the buffer; do not touch the mark.
function gotoeob ()
  cur_bp.pt = point_max ()
  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
end
