function marker_new ()
  return {}
end

local function unchain_marker (marker)
  if not marker.bp then
    return
  end

  local m = marker.bp.markers
  while m do
    local next = m.next
    if m == marker then
      if prev then
        prev.next = next
      else
        m.bp.markers = next
      end
        m.bp = nil
      break
    end
    prev = m
  end
end

function free_marker (marker)
  unchain_marker (marker)
end

function move_marker (marker, bp, pt)
  if bp ~= get_marker_bp (marker) then
    -- Unchain with the previous pointed buffer.
    unchain_marker (marker)

    -- Change the buffer.
    marker.bp = bp

    -- Chain with the new buffer.
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
