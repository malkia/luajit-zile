-- Getting and ungetting key strokes
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

local _last_key

-- Return last key pressed
function lastkey ()
  return _last_key
end

-- Get a keystroke, waiting for up to timeout 10ths of a second if
-- mode contains GETKEY_DELAYED, and translating it into a
-- keycode unless mode contains GETKEY_UNFILTERED.
function xgetkey (mode, timeout)
  _last_key = term_xgetkey (mode, timeout)

  if bit.band (thisflag, FLAG_DEFINING_MACRO) ~= 0 then
    add_key_to_cmd (_last_key)
  end

  return _last_key
end

-- Wait for a keystroke indefinitely, and return the
-- corresponding keycode.
function getkey ()
  return xgetkey (0, 0)
end

-- Push a key into the input buffer.
function pushkey (key)
  term_ungetkey (key)
end

-- Unget a key as if it had not been fetched.
function ungetkey (key)
  pushkey (key)

  if bit.band (thisflag, FLAG_DEFINING_MACRO) ~= 0 then
    remove_key_from_cmd ()
  end
end

-- Wait for timeout 10ths if a second or until a key is pressed.
-- The key is then available with [x]getkey.
function waitkey (timeout)
  ungetkey (xgetkey (GETKEY_DELAYED, timeout))
end
