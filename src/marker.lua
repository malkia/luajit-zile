-- Marker facility functions
--
-- Copyright (c) 2010 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- GNU Zile is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- GNU Zile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with GNU Zile; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.

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

function move_marker (marker, bp, pt)
  if bp ~= marker.bp then
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
