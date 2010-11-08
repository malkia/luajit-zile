-- Undo facility functions
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

-- Setting this variable to true stops undo_save saving the given
-- information.
undo_nosave = false

-- This variable is set to true when an undo is in execution.
local doing_undo = false

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

-- Revert an action.  Return the next undo entry.
local function revert_action (up)
  local pt = point_new ()

  pt.n = up.n
  pt.o = up.o

  doing_undo = true

  if up.type == UNDO_END_SEQUENCE then
    undo_save (UNDO_START_SEQUENCE, pt, 0, 0)
    up = up.next
    while up.type ~= UNDO_START_SEQUENCE do
      up = revert_action (up)
    end
    pt.n = up.n
    pt.o = up.o
    undo_save (UNDO_END_SEQUENCE, pt, 0, 0)
    goto_point (pt)
    return up.next
  end

  goto_point (pt)

  if up.type == UNDO_REPLACE_BLOCK then
    undo_save (UNDO_REPLACE_BLOCK, pt, up.size, #up.text)
    undo_nosave = true
    for i = 1, up.size do
      delete_char ()
    end
    insert_string (up.text)
    undo_nosave = false
  end

  doing_undo = false

  if up.unchanged then
    cur_bp.modified = false
  end

  return up.next
end

Defun ("undo",
       {},
[[
Undo some previous changes.
Repeat this command to undo more changes.
]],
  true,
  function ()
    if cur_bp.noundo then
      minibuf_error ("Undo disabled in this buffer")
      return leNIL
    end

    if warn_if_readonly_buffer () then
      return leNIL
    end

    if not cur_bp.next_undop then
      minibuf_error ("No further undo information")
      cur_bp.next_undop = cur_bp.last_undop
      return leNIL
    end

    cur_bp.next_undop = revert_action (cur_bp.next_undop)
    minibuf_write ("Undo!")
  end
)
