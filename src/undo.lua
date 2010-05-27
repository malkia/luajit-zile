-- Setting this variable to true stops undo_save saving the given
-- information.
undo_nosave = false

-- This variable is set to true when an undo is in execution.
-- FIXME: local
doing_undo = false

-- Save a reverse delta for doing undo.
function undo_save (ty, pt, osize, size)
  if cur_bp.noundo or undo_nosave then
    return
  end

  local up = {type = ty, n = pt.n, o = pt.o}
  if not cur_bp.modified then
    up.unchanged = true
  end

  if ty == UNDO_REPLACE_BLOCK then
    local lp = cur_bp.pt.p
    local n = cur_bp.pt.n

    if n > pt.n then
      repeat
        lp = lp.prev
        n = n - 1
      until n <= pt.n
    elseif n < pt.n then
      repeat
        lp = lp.next
        n = n + 1
      until n >= pt.n
    end

    pt.p = lp
    up.osize = osize
    up.size = size
    up.text = copy_text_block (table.clone (pt), osize)
  end

  up.next = cur_bp.last_undop
  cur_bp.last_undop = up

  if not doing_undo then
    cur_bp.next_undop = up
  end
end

-- Set unchanged flags to false.
function undo_set_unchanged (up)
  while up do
    up.unchanged = false
    up = up.next
  end
end
