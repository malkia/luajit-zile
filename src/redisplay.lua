-- Terminal independent redisplay routines
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

function recenter (wp)
  local pt = window_pt (wp)

  if pt.n > wp.eheight / 2 then
    wp.topdelta = wp.eheight / 2
  else
    wp.topdelta = pt.n
  end
end

Defun ("recenter",
       {},
[[
Center point in window and redisplay screen.
The desired position of point is always relative to the current window.
]],
  true,
  function ()
    recenter (cur_wp)
    term_full_redisplay ()
    return leT
  end
)

function resize_windows ()
  local wp

  -- Resize windows horizontally.
  wp = head_wp
  while wp ~= nil do
    local w = term_width ()
    wp.fwidth = w
    wp.ewidth = wp.fwidth
    wp = wp.next
  end

  -- Work out difference in window height; windows may be taller than
  -- terminal if the terminal was very short.
  local hdelta = term_height () - 1
  wp = head_wp
  while wp ~= nil do
    hdelta = hdelta - wp.fheight
    wp = wp.next
  end

  -- Resize windows vertically.
  if hdelta > 0 then
    -- Increase windows height.
    wp = head_wp
    while hdelta > 0 do
      if wp == nil then
        wp = head_wp
      end
      wp.fheight = wp.fheight + 1
      wp.eheight = wp.eheight + 1
      hdelta = hdelta - 1
      wp = wp.next
    end
  else
    -- Decrease windows' height, and close windows if necessary.
    local decreased
    repeat
      decreased = false
      wp = head_wp
      while wp and hdelta < 0 do
        if wp.fheight > 2 then
          wp.fheight = wp.fheight - 1
          wp.eheight = wp.eheight - 1
          hdelta = hdelta + 1
          decreased = true
        elseif cur_wp ~= head_wp or cur_wp.next then
          local new_wp = wp.next
          delete_window (wp)
          wp = new_wp
          decreased = true
        end
      end
      wp = wp.next
    until decreased == false
  end

  execute_function ("recenter")
end

function resync_redisplay (wp)
  local delta = wp.bp.pt.n - wp.lastpointn

  if delta ~= 0 then
    if (delta > 0 and wp.topdelta + delta < wp.eheight) or
      (delta < 0 and wp.topdelta >= -delta) then
      wp.topdelta = wp.topdelta + delta
    elseif wp.bp.pt.n > wp.eheight / 2 then
      wp.topdelta = math.floor (wp.eheight / 2)
    else
      wp.topdelta = wp.bp.pt.n
    end
  end
  wp.lastpointn = wp.bp.pt.n
end
