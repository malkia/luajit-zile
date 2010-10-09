-- Registers facility functions
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

local regs = {}

Defun ("copy-to-register",
       {"number"},
[[
Copy region into register @i{register}.
]],
  true,
  function (reg)
    if not reg then
      minibuf_write ("Copy to register: ")
      reg = getkey ()
    end

    if reg == KBD_CANCEL then
      return execute_function ("keyboard-quit")
    else
      local rp = {}

      minibuf_clear ()
      if reg < 0 then
        reg = 0
      end

      if not calculate_the_region (rp) then
        return leNIL
      else
        regs[reg] = copy_text_block (rp.start, rp.size)
      end
    end

    return leT
  end
)

local regnum

function insert_register ()
  undo_save (UNDO_REPLACE_BLOCK, cur_bp.pt, 0, #regs[regnum])
  undo_nosave = true
  insert_string (regs[regnum])
  undo_nosave = false
  return true
end

Defun ("insert-register",
       {"number"},
[[
Insert contents of the user specified register.
Puts point before and mark after the inserted text.
]],
  true,
  function (reg)
    local ok = leT

    if warn_if_readonly_buffer () then
      return leNIL
    end

    if not reg then
      minibuf_write ("Insert register: ")
      reg = getkey ()
    end

    if reg == KBD_CANCEL then
      ok = execute_function ("keyboard-quit")
    else
      minibuf_clear ()
      if not regs[reg] then
        minibuf_error ("Register does not contain text")
        ok = leNIL
      else
        set_mark_interactive ()
        regnum = reg
        execute_with_uniarg (true, get_variable_number ("current-prefix-arg"), insert_register)
        execute_function ("exchange_point_and_mark")
        deactivate_mark ()
      end
    end

    return ok
  end
)

local function write_registers_list (i)
  for i, r in pairs (regs) do
    if r then
      local as = ""

      if isprint (string.char (i)) then
        as = string.format ("%c", i)
      else
        as = string.format ("\\%o", i)
      end

      insert_string (string.format ("Register %s contains ", as))
      if r == "" then
        insert_string ("the empty string\n")
      elseif string.match (r, "^%s+$") then
        insert_string ("whitespace\n")
      else
        local len = math.min (20, math.max (0, cur_wp.ewidth - 6)) + 1
        insert_string (string.format ("text starting with\n    %s\n", string.sub (s, 1, len)))
      end
    end
  end
end

Defun ("list-registers",
       {},
[[
List defined registers.
]],
  true,
  function ()
    write_temp_buffer ("*Registers List*", true, write_registers_list)
  end
)
