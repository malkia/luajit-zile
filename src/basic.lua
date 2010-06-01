-- Get the goal column, expanding tabs.
function get_goalc_bp (bp, pt)
  local col = 0
  local t = tab_width (bp)

  for i = 0, math.min (pt.o, #pt.p.text) do
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
