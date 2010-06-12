function marker_new ()
  return {}
end

-- FIXME: Use a list of markers, not a chain
-- FIXME: local
function unchain_marker (marker)
  if not marker.bp then
    return
  end

  local prev
  local m = marker.bp.markers
  while m do
    if m == marker then
      if prev then
        prev.next = m.next
      else
        m.bp.markers = m.next
      end
      m.bp = nil
      break
    end
    prev = m
    m = m.next
  end
end

free_marker = unchain_marker

function move_marker (marker, bp, pt)
  if bp ~= get_marker_bp (marker) then
    -- Unchain from previous buffer.
    unchain_marker (marker)

    -- Change buffer.
    marker.bp = bp

    -- Add to new buffer's chain.
    marker.next = bp.markers
    bp.markers = marker
  end

  -- Change the point.
  marker.pt = table.clone (pt)
end

function copy_marker (m)
  local marker
  if m then
    marker = marker_new ()
    move_marker (marker, m.bp, m.pt)
  end
  return marker
end

function point_marker ()
  local marker = marker_new ()
  move_marker (marker, cur_bp, table.clone (cur_bp.pt))
  return marker
end
