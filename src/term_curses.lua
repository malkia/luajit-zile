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
  term_set_size (curses.cols, curses.lines)
  curses.echo (false)
  curses.nl (false)
  curses.raw (true)
  stdscr ():meta (true);
  stdscr ():intrflush (false)
  stdscr ():keypad (true)
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

function codetokey (c)
  if c == '\0' then -- C-@
    ret = bit.bor (KBD_CTRL, string.byte ('@'))
  elseif (set.new {'\001', '\002', '\003', '\004', '\005', '\006', '\007', '\008',
                   '\010', '\011', '\012', '\014', '\015', '\016', '\017', '\018',
                   '\019', '\020', '\021', '\022', '\023', '\024', '\025', '\026'})[c] then -- C-a ... C-z
    ret = bit.bor (KBD_CTRL, string.byte ('a') + string.byte (c) - 1)
  elseif c == '\009' then
    ret = KBD_TAB
  elseif c == '\013' then
    ret = KBD_RET
  elseif c == '\031' then
    ret = bit.bor (KBD_CTRL, bit.xor (c, 64))
  elseif c == KEY_SUSPEND then -- C-z
    ret = bit.bor (KBD_CTRL, string.byte ('z'))
  elseif c == '\027' then -- META
    ret = KBD_META
  elseif c == KEY_PPAGE then -- PGUP
    ret = KBD_PGUP
  elseif c == KEY_NPAGE then -- PGDN
    ret = KBD_PGDN
  elseif c == KEY_HOME then
    ret = KBD_HOME
  elseif c == KEY_END then
    ret = KBD_END
  elseif c == KEY_DC then -- DEL
    ret = KBD_DEL
  elseif c == KEY_BACKSPACE or c == '\127' then -- BS
    ret = KBD_BS
  elseif c == KEY_IC then -- INSERT
    ret = KBD_INS
  elseif c == KEY_LEFT then
    ret = KBD_LEFT
  elseif c == KEY_RIGHT then
    ret = KBD_RIGHT
  elseif c == KEY_UP then
    ret = KBD_UP
  elseif c == KEY_DOWN then
    ret = KBD_DOWN
  elseif c == KEY_F1 then
    ret = KBD_F1
  elseif c == KEY_F2 then
    ret = KBD_F2
  elseif c == KEY_F3 then
    ret = KBD_F3
  elseif c == KEY_F4 then
    ret = KBD_F4
  elseif c == KEY_F5 then
    ret = KBD_F5
  elseif c == KEY_F6 then
    ret = KBD_F6
  elseif c == KEY_F7 then
    ret = KBD_F7
  elseif c == KEY_F8 then
    ret = KBD_F8
  elseif c == KEY_F9 then
    ret = KBD_F9
  elseif c == KEY_F10 then
    ret = KBD_F10
  elseif c == KEY_F11 then
    ret = KBD_F11
  elseif c == KEY_F12 then
    ret = KBD_F12
  else
    ret = string.byte (c)
  end

  return ret
end

-- static size_t
-- keytocodes (size_t key, int ** codevec)
-- {
--   int * p;

--   p = *codevec = XCALLOC (2, int);

--   if (key == KBD_NOKEY)
--     return 0;

--   if (key & KBD_META)				-- META
--     *p++ = '\33';
--   key &= ~KBD_META;

--   switch (key)
--     {
--     case KBD_CTRL | '@':			-- C-@
--       *p++ = '\0';
--       break;
--     case KBD_CTRL | 'a':
--     case KBD_CTRL | 'b':
--     case KBD_CTRL | 'c':
--     case KBD_CTRL | 'd':
--     case KBD_CTRL | 'e':
--     case KBD_CTRL | 'f':
--     case KBD_CTRL | 'g':
--     case KBD_CTRL | 'h':
--     case KBD_CTRL | 'j':
--     case KBD_CTRL | 'k':
--     case KBD_CTRL | 'l':
--     case KBD_CTRL | 'n':
--     case KBD_CTRL | 'o':
--     case KBD_CTRL | 'p':
--     case KBD_CTRL | 'q':
--     case KBD_CTRL | 'r':
--     case KBD_CTRL | 's':
--     case KBD_CTRL | 't':
--     case KBD_CTRL | 'u':
--     case KBD_CTRL | 'v':
--     case KBD_CTRL | 'w':
--     case KBD_CTRL | 'x':
--     case KBD_CTRL | 'y':
--     case KBD_CTRL | 'z':	-- C-a ... C-z
--       *p++ = (key & ~KBD_CTRL) + 1 - 'a';
--       break;
--     case KBD_TAB:
--       *p++ = '\11';
--       break;
--     case KBD_RET:
--       *p++ ='\15';
--       break;
--     case '\37':
--       *p++ = (key & ~KBD_CTRL) ^ 0x40;
--       break;
--     case KBD_PGUP:		-- PGUP
--       *p++ = KEY_PPAGE;
--       break;
--     case KBD_PGDN:		-- PGDN
--       *p++ = KEY_NPAGE;
--       break;
--     case KBD_HOME:
--       *p++ = KEY_HOME;
--       break;
--     case KBD_END:
--       *p++ = KEY_END;
--       break;
--     case KBD_DEL:		-- DEL
--       *p++ = KEY_DC;
--       break;
--     case KBD_BS:		-- BS
--       *p++ = KEY_BACKSPACE;
--       break;
--     case KBD_INS:		-- INSERT
--       *p++ = KEY_IC;
--       break;
--     case KBD_LEFT:
--       *p++ = KEY_LEFT;
--       break;
--     case KBD_RIGHT:
--       *p++ = KEY_RIGHT;
--       break;
--     case KBD_UP:
--       *p++ = KEY_UP;
--       break;
--     case KBD_DOWN:
--       *p++ = KEY_DOWN;
--       break;
--     case KBD_F1:
--       *p++ = KEY_F (1);
--       break;
--     case KBD_F2:
--       *p++ = KEY_F (2);
--       break;
--     case KBD_F3:
--       *p++ = KEY_F (3);
--       break;
--     case KBD_F4:
--       *p++ = KEY_F (4);
--       break;
--     case KBD_F5:
--       *p++ = KEY_F (5);
--       break;
--     case KBD_F6:
--       *p++ = KEY_F (6);
--       break;
--     case KBD_F7:
--       *p++ = KEY_F (7);
--       break;
--     case KBD_F8:
--       *p++ = KEY_F (8);
--       break;
--     case KBD_F9:
--       *p++ = KEY_F (9);
--       break;
--     case KBD_F10:
--       *p++ = KEY_F (10);
--       break;
--     case KBD_F11:
--       *p++ = KEY_F (11);
--       break;
--     case KBD_F12:
--       *p++ = KEY_F (12);
--       break;
--     default:
--       if ((key & 0xff) == key)
--         *p++ = key;
--       break;
--     }

--   return p - *codevec;
-- }

-- static int
-- get_char (void)
-- {
--   int c;
--   size_t size = term_buf_len ();

--   if (size > 0)
--     {
--       c = (int) gl_list_get_at (key_buf, size - 1);
--       gl_list_remove_at (key_buf, size - 1);
--     }
--   else
--     c = getch ();

--   return c;
-- }

-- size_t
-- term_xgetkey (int mode, size_t timeout)
-- {
--   size_t key;

--   for (;;)
--     {
--       int c;

--       if (mode & GETKEY_DELAYED)
--         wtimeout (stdscr, (int) timeout * 100);

--       c = get_char ();
--       if (mode & GETKEY_DELAYED)
--         wtimeout (stdscr, -1);

-- #ifdef KEY_RESIZE
--       if (c == KEY_RESIZE)
--         {
--           term_set_size ((size_t) COLS, (size_t) LINES);
--           resize_windows ();
--           continue;
--         }
-- #endif

--       if (mode & GETKEY_UNFILTERED)
--         key = (size_t) c;
--       else
--         {
--           key = codetokey (c);
--           while (key == KBD_META)
--             key = codetokey (get_char ()) | KBD_META;
--         }
--       break;
--     }

--   return key;
-- }

-- void
-- term_ungetkey (size_t key)
-- {
--   int * codes = NULL;
--   size_t i, n = keytocodes (key, &codes);

--   for (i = n; i > 0; i--)
--     gl_list_add_last (key_buf, (void *) codes[i - 1]);

--   free (codes);
-- }
