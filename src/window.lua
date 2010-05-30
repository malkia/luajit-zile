function window_pt (wp)
  -- The current window uses the current buffer point; all other
  -- windows have a saved point, except that if a window has just been
  -- killed, it needs to use its new buffer's current point.

  assert (wp ~= nil)
  if wp == cur_wp then
    assert (wp.bp == cur_bp)
    assert (wp.saved_pt == nil)
    assert (cur_bp ~= nil)
    return table.clone (cur_bp.pt)
  else
    if wp.saved_pt ~= nil then
      return table.clone (wp.saved_pt.pt)
    else
      return table.clone (wp.bp.pt)
    end
  end
end
