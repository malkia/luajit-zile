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

local codetokey_map, keytocode_map

function term_init ()
  curses.initscr ()

  keytocode_map = {
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

  codetokey_map = table.invert (keytocode_map)
  codetokey_map = table.merge (codetokey_map,
                               {
                                 [27] = KBD_META,
                                 [127] = KBD_BS,
                                 [curses.KEY_SUSPEND] = bit.bor (KBD_CTRL, string.byte ('z')), -- C-z
                               })

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
  if codetokey_map[c] then
    ret = codetokey_map[c]
  elseif c > 0xff or c < 0 then
    ret = KBD_NOKEY -- Undefined behaviour.
  else
    ret = c
  end

  return ret
end

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
      curses.stdscr ():timeout (timeout * 100)
    end

    local c = get_char ()
    if bit.band (mode, GETKEY_DELAYED) ~= 0 then
      curses.stdscr ():timeout (-1)
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
