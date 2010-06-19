function point_new ()
  return {o = 0, n = 0, p = {}}
end

function point_min ()
  local pt = point_new ()
  pt.p = cur_bp.lines.next
  pt.n = 0
  pt.o = 0
  return pt
end

function point_max ()
  local pt = point_new ()
  pt.p = cur_bp.lines.prev
  pt.n = cur_bp.last_line
  pt.o = #pt.p.text
  return pt
end

function cmp_point (pt1, pt2)
  if pt1.n < pt2.n then
    return -1
  elseif pt1.n > pt2.n then
    return 1
  end
  return (pt1.o < pt2.o) and -1 or ((pt1.o > pt2.o) and 1 or 0)
end
