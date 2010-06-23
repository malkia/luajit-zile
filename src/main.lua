-- Program invocation, startup and shutdown
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

_DEBUG = true

-- Main editor structures.

-- Undo delta types.
UNDO_REPLACE_BLOCK = 0  -- Replace a block of characters.
UNDO_START_SEQUENCE = 1 -- Start a multi operation sequence.
UNDO_END_SEQUENCE = 2   -- End a multi operation sequence.

-- Keyboard handling

GETKEY_DELAYED = 0001
GETKEY_UNFILTERED = 0002

-- Special value returned for invalid key codes, or when no key is pressed
KBD_NOKEY = -1

-- Key modifiers.
KBD_CTRL = 512
KBD_META = 1024

-- Common non-alphanumeric keys.
KBD_CANCEL = bit.bor (KBD_CTRL, string.byte ('g'))
KBD_TAB = 258
KBD_RET = 259
KBD_PGUP = 260
KBD_PGDN = 261
KBD_HOME = 262
KBD_END = 263
KBD_DEL = 264
KBD_BS = 265
KBD_INS = 266
KBD_LEFT = 267
KBD_RIGHT = 268
KBD_UP = 269
KBD_DOWN = 270
KBD_F1 = 272
KBD_F2 = 273
KBD_F3 = 274
KBD_F4 = 275
KBD_F5 = 276
KBD_F6 = 277
KBD_F7 = 278
KBD_F8 = 279
KBD_F9 = 280
KBD_F10 = 281
KBD_F11 = 282
KBD_F12 = 283


-- Miscellaneous stuff.

-- Global flags, stored in thisflag and lastflag.
FLAG_NEED_RESYNC    = 0x01 -- A resync is required.
FLAG_QUIT           = 0x02 -- The user has asked to quit.
FLAG_SET_UNIARG     = 0x04 -- The last command modified the universal arg variable `uniarg'.
FLAG_UNIARG_EMPTY   = 0x08 -- Current universal arg is just C-u's with no number.
FLAG_DEFINING_MACRO = 0x10 -- We are defining a macro.

-- Zile font codes
FONT_NORMAL = 0
FONT_REVERSE = 1


-- Zile command to Lua bindings

leT = {data = "t"}
leNIL = {data = "nil"}

usercmd = {} -- table of user commands

-- User command constructors
function defun (l, interactive)
  usercmd[l[1]] = {doc = l[2], interactive = interactive, func = l[3]}
end

function Defun (l)
  defun (l, true)
end

function Defun_noninteractive (l)
  defun (l, false)
end

-- Turn a boolean into a Lisp boolean
function bool_to_lisp (b)
  return b and leT or leNIL
end

-- The current window
cur_wp = nil
-- The first window in list
head_wp = nil

-- The current buffer
cur_bp = nil
-- The first buffer in list
head_bp = nil

-- The global editor flags.
thisflag = 0
lastflag = 0

-- The universal argument repeat count.
last_uniarg = 1
