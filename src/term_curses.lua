-- Curses terminal
--
-- Copyright (c) 2009, 2010 Free Software Foundation, Inc.
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

local key_buf

function term_buf_len ()
  return #key_buf
end

function term_move (y, x)
  curses.stdscr ():move (y, x)
end

function term_clrtoeol ()
  curses.stdscr ():clrtoeol ()
end

function term_refresh ()
  curses.stdscr ():refresh ()
end

function term_clear ()
  curses.stdscr ():clear ()
end

function term_addch (c)
  curses.stdscr ():addch (bit.band (c, bit.bnot (curses.A_ATTRIBUTES)))
end

-- FIXME: Put next two lines in a better place
FONT_NORMAL = 0
FONT_REVERSE = 1
function term_attrset (attr)
  curses.stdscr ():attrset (attr == FONT_REVERSE and curses.A_REVERSE or 0)
end

function term_beep ()
  curses.beep ()
end

function term_init ()
  curses.initscr ()
  term_set_size (curses.cols (), curses.lines ())
  curses.echo (false)
  curses.nl (false)
  curses.raw (true)
  curses.stdscr ():meta (true)
  curses.stdscr ():intrflush (false)
  curses.stdscr ():keypad (true)
  key_buf = {}
end

function term_close ()
  -- Clear last line.
  term_move (curses.lines - 1, 0)
  term_clrtoeol ()
  term_refresh ()
  -- Finish with curses.
  curses.endwin ()
end

local function codetokey (c)
  if c == 0 then -- C-@
    ret = bit.bor (KBD_CTRL, string.byte ('@'))
  elseif (set.new {1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 12, 14, 15, 16, 17, 18,
                   19, 20, 21, 22, 23, 24, 25, 26})[c] then -- C-a ... C-z
    ret = bit.bor (KBD_CTRL, string.byte ('a') + c - 1)
  elseif c == 9 then
    ret = KBD_TAB
  elseif c == 13 then
    ret = KBD_RET
  elseif c == 31 then
    ret = bit.bor (KBD_CTRL, string.byte ('_'))
  elseif c == curses.KEY_SUSPEND then -- C-z
    ret = bit.bor (KBD_CTRL, string.byte ('z'))
  elseif c == 27 then -- META
    ret = KBD_META
  elseif c == curses.KEY_PPAGE then -- PGUP
    ret = KBD_PGUP
  elseif c == curses.KEY_NPAGE then -- PGDN
    ret = KBD_PGDN
  elseif c == curses.KEY_HOME then
    ret = KBD_HOME
  elseif c == curses.KEY_END then
    ret = KBD_END
  elseif c == curses.KEY_DC then -- DEL
    ret = KBD_DEL
  elseif c == curses.KEY_BACKSPACE or c == 127 then -- BS
    ret = KBD_BS
  elseif c == curses.KEY_IC then -- INSERT
    ret = KBD_INS
  elseif c == curses.KEY_LEFT then
    ret = KBD_LEFT
  elseif c == curses.KEY_RIGHT then
    ret = KBD_RIGHT
  elseif c == curses.KEY_UP then
    ret = KBD_UP
  elseif c == curses.KEY_DOWN then
    ret = KBD_DOWN
  elseif c == curses.KEY_F1 then
    ret = KBD_F1
  elseif c == curses.KEY_F2 then
    ret = KBD_F2
  elseif c == curses.KEY_F3 then
    ret = KBD_F3
  elseif c == curses.KEY_F4 then
    ret = KBD_F4
  elseif c == curses.KEY_F5 then
    ret = KBD_F5
  elseif c == curses.KEY_F6 then
    ret = KBD_F6
  elseif c == curses.KEY_F7 then
    ret = KBD_F7
  elseif c == curses.KEY_F8 then
    ret = KBD_F8
  elseif c == curses.KEY_F9 then
    ret = KBD_F9
  elseif c == curses.KEY_F10 then
    ret = KBD_F10
  elseif c == curses.KEY_F11 then
    ret = KBD_F11
  elseif c == curses.KEY_F12 then
    ret = KBD_F12
  elseif c > 0xff or c < 0 then
    ret = KBD_NOKEY -- Undefined behaviour.
  else
    ret = c
  end

  return ret
end

local keytocode_map = {
  [bit.bor (KBD_CTRL, string.byte ('@'))] = 0, -- C-@
  [bit.bor (KBD_CTRL, string.byte ('a'))] = 1, -- C-a
  [bit.bor (KBD_CTRL, string.byte ('b'))] = 2, -- C-b
  [bit.bor (KBD_CTRL, string.byte ('c'))] = 3, -- C-c
  [bit.bor (KBD_CTRL, string.byte ('d'))] = 4, -- C-d
  [bit.bor (KBD_CTRL, string.byte ('e'))] = 5, -- C-e
  [bit.bor (KBD_CTRL, string.byte ('f'))] = 6, -- C-f
  [bit.bor (KBD_CTRL, string.byte ('g'))] = 7, -- C-g
  [bit.bor (KBD_CTRL, string.byte ('h'))] = 8, -- C-h
  [KBD_TAB] = 9,
  [bit.bor (KBD_CTRL, string.byte ('j'))] = 10, -- C-j
  [bit.bor (KBD_CTRL, string.byte ('k'))] = 11, -- C-k
  [bit.bor (KBD_CTRL, string.byte ('l'))] = 12, -- C-l
  [KBD_RET] = 13,
  [bit.bor (KBD_CTRL, string.byte ('n'))] = 14, -- C-n
  [bit.bor (KBD_CTRL, string.byte ('o'))] = 15, -- C-o
  [bit.bor (KBD_CTRL, string.byte ('p'))] = 16, -- C-p
  [bit.bor (KBD_CTRL, string.byte ('q'))] = 17, -- C-q
  [bit.bor (KBD_CTRL, string.byte ('r'))] = 18, -- C-r
  [bit.bor (KBD_CTRL, string.byte ('s'))] = 19, -- C-s
  [bit.bor (KBD_CTRL, string.byte ('t'))] = 20, -- C-t
  [bit.bor (KBD_CTRL, string.byte ('u'))] = 21, -- C-u
  [bit.bor (KBD_CTRL, string.byte ('v'))] = 22, -- C-v
  [bit.bor (KBD_CTRL, string.byte ('w'))] = 23, -- C-w
  [bit.bor (KBD_CTRL, string.byte ('x'))] = 24, -- C-x
  [bit.bor (KBD_CTRL, string.byte ('y'))] = 25, -- C-y
  [bit.bor (KBD_CTRL, string.byte ('z'))] = 26, -- C-z
  [bit.bor (KBD_CTRL, string.byte ('_'))] = 31, -- C-_
  [KBD_PGUP] = curses.KEY_PPAGE,
  [KBD_PGDN] = curses.KEY_NPAGE,
  [KBD_HOME] = curses.KEY_HOME,
  [KBD_END] = curses.KEY_END,
  [KBD_DEL] = curses.KEY_DC,
  [KBD_BS] = curses.KEY_BACKSPACE,
  [KBD_INS] = curses.KEY_IC, -- INSERT
  [KBD_LEFT] = curses.KEY_LEFT,
  [KBD_RIGHT] = curses.KEY_RIGHT,
  [KBD_UP] = curses.KEY_UP,
  [KBD_DOWN] = curses.KEY_DOWN,
  [KBD_F1] = curses.KEY_F1,
  [KBD_F2] = curses.KEY_F2,
  [KBD_F3] = curses.KEY_F3,
  [KBD_F4] = curses.KEY_F4,
  [KBD_F5] = curses.KEY_F5,
  [KBD_F6] = curses.KEY_F6,
  [KBD_F7] = curses.KEY_F7,
  [KBD_F8] = curses.KEY_F8,
  [KBD_F9] = curses.KEY_F9,
  [KBD_F10] = curses.KEY_F10,
  [KBD_F11] = curses.KEY_F11,
  [KBD_F12] = curses.KEY_F12,
}

local function keytocodes (key)
  local codevec = {}

  if key ~= KBD_NOKEY then
    if bit.band (key, KBD_META) ~= 0 then
      table.insert (codevec, 27)
      key = bit.band (key, bit.bnot (KBD_META))
    end

    if keytocode_map[key] then
      table.insert (codevec, keytocode_map[key])
    elseif key < 0x100 then
      table.insert (codevec, key)
    end
  end

  return codevec
end

local function get_char ()
  local c

  if #key_buf > 0 then
    c = key_buf[#key_buf]
    table.remove (key_buf, #key_buf)
  else
    c = curses.stdscr ():getch ()
  end

  return c
end

function term_xgetkey (mode, timeout)
  while true do
    if bit.band (mode, GETKEY_DELAYED) ~= 0 then
      curses.stdscr ():wtimeout (timeout * 100)
    end

    local c = get_char ()
    if bit.band (mode, GETKEY_DELAYED) ~= 0 then
      curses.stdscr ():wtimeout (-1)
    end

    if c == curses.KEY_RESIZE then
      term_set_size (curses.cols, curses.lines)
      -- FIXME: resize_windows ()
    else
      local key
      if bit.band (mode, GETKEY_UNFILTERED) ~= 0 then
        key = c
      else
        key = codetokey (c)
        while key == KBD_META do
          key = bit.bor (codetokey (get_char ()), KBD_META)
        end
      end
      return key
    end
  end
end

function term_ungetkey (key)
  key_buf = list.concat (key_buf, list.reverse (keytocodes (key)))
end
