function cmp_point (pt1, pt2)
  if pt1.n < pt2.n then
    return -1
  elseif pt1.n > pt2.n then
    return 1
  end
  return (pt1.o < pt2.o) and -1 or ((pt1.o > pt2.o) and 1 or 0);
end
