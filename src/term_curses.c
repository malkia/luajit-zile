/* Curses terminal

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.

   This file is part of GNU Zile.

   GNU Zile is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   GNU Zile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

#include "config.h"

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#ifdef HAVE_NCURSES_H
#include <ncurses.h>
#else
#include <curses.h>
#endif
#include "gl_array_list.h"

#include "main.h"
#include "extern.h"

static gl_list_t key_buf;

size_t
term_buf_len (void)
{
  return gl_list_size (key_buf);
}

void
term_init (void)
{
  (void) CLUE_DO (L, "curses.initscr ()");
  (void) CLUE_DO (L, "term_set_size (curses.cols (), curses.lines ())");
  noecho ();
  nonl ();
  raw ();
  meta (stdscr, true);
  intrflush (stdscr, false);
  keypad (stdscr, true);
  key_buf = gl_list_create_empty (GL_ARRAY_LIST, NULL, NULL, NULL, true);
}

static size_t
codetokey (int c)
{
  size_t ret;
  char s[2];

  s[0] = c;
  s[1] = '\0';
  CLUE_SET (L, s, string, s);
  (void) CLUE_DO (L, "ret = codetokey (s)");
  CLUE_GET (L, ret, integer, ret);

  return ret;
}

static size_t
keytocodes (size_t key, int ** codevec)
{
  int * p;

  p = *codevec = XCALLOC (2, int);

  if (key == KBD_NOKEY)
    return 0;

  if (key & KBD_META)				/* META */
    *p++ = '\33';
  key &= ~KBD_META;

  switch (key)
    {
    case KBD_CTRL | '@':			/* C-@ */
      *p++ = '\0';
      break;
    case KBD_CTRL | 'a':
    case KBD_CTRL | 'b':
    case KBD_CTRL | 'c':
    case KBD_CTRL | 'd':
    case KBD_CTRL | 'e':
    case KBD_CTRL | 'f':
    case KBD_CTRL | 'g':
    case KBD_CTRL | 'h':
    case KBD_CTRL | 'j':
    case KBD_CTRL | 'k':
    case KBD_CTRL | 'l':
    case KBD_CTRL | 'n':
    case KBD_CTRL | 'o':
    case KBD_CTRL | 'p':
    case KBD_CTRL | 'q':
    case KBD_CTRL | 'r':
    case KBD_CTRL | 's':
    case KBD_CTRL | 't':
    case KBD_CTRL | 'u':
    case KBD_CTRL | 'v':
    case KBD_CTRL | 'w':
    case KBD_CTRL | 'x':
    case KBD_CTRL | 'y':
    case KBD_CTRL | 'z':	/* C-a ... C-z */
      *p++ = (key & ~KBD_CTRL) + 1 - 'a';
      break;
    case KBD_TAB:
      *p++ = '\11';
      break;
    case KBD_RET:
      *p++ = '\15';
      break;
    case KBD_CTRL | '_':
      *p++ = '\37';
      break;
    case KBD_PGUP:		/* PGUP */
      *p++ = KEY_PPAGE;
      break;
    case KBD_PGDN:		/* PGDN */
      *p++ = KEY_NPAGE;
      break;
    case KBD_HOME:
      *p++ = KEY_HOME;
      break;
    case KBD_END:
      *p++ = KEY_END;
      break;
    case KBD_DEL:		/* DEL */
      *p++ = KEY_DC;
      break;
    case KBD_BS:		/* BS */
      *p++ = KEY_BACKSPACE;
      break;
    case KBD_INS:		/* INSERT */
      *p++ = KEY_IC;
      break;
    case KBD_LEFT:
      *p++ = KEY_LEFT;
      break;
    case KBD_RIGHT:
      *p++ = KEY_RIGHT;
      break;
    case KBD_UP:
      *p++ = KEY_UP;
      break;
    case KBD_DOWN:
      *p++ = KEY_DOWN;
      break;
    case KBD_F1:
      *p++ = KEY_F (1);
      break;
    case KBD_F2:
      *p++ = KEY_F (2);
      break;
    case KBD_F3:
      *p++ = KEY_F (3);
      break;
    case KBD_F4:
      *p++ = KEY_F (4);
      break;
    case KBD_F5:
      *p++ = KEY_F (5);
      break;
    case KBD_F6:
      *p++ = KEY_F (6);
      break;
    case KBD_F7:
      *p++ = KEY_F (7);
      break;
    case KBD_F8:
      *p++ = KEY_F (8);
      break;
    case KBD_F9:
      *p++ = KEY_F (9);
      break;
    case KBD_F10:
      *p++ = KEY_F (10);
      break;
    case KBD_F11:
      *p++ = KEY_F (11);
      break;
    case KBD_F12:
      *p++ = KEY_F (12);
      break;
    default:
      if ((key & 0xff) == key)
        *p++ = key;
      break;
    }

  return p - *codevec;
}

static int
get_char (void)
{
  int c;
  size_t size = term_buf_len ();

  if (size > 0)
    {
      c = (ptrdiff_t) gl_list_get_at (key_buf, size - 1);
      gl_list_remove_at (key_buf, size - 1);
    }
  else
    c = getch ();

  return c;
}

size_t
term_xgetkey (int mode, size_t timeout)
{
  size_t key;

  for (;;)
    {
      int c;

      if (mode & GETKEY_DELAYED)
        wtimeout (stdscr, (int) timeout * 100);

      c = get_char ();
      if (mode & GETKEY_DELAYED)
        wtimeout (stdscr, -1);

#ifdef KEY_RESIZE
      if (c == KEY_RESIZE)
        {
          (void) CLUE_DO (L, "term_set_size (curses.cols, curses.lines)");
          resize_windows ();
          continue;
        }
#endif

      if (mode & GETKEY_UNFILTERED)
        key = (size_t) c;
      else
        {
          key = codetokey (c);
          while (key == KBD_META)
            key = codetokey (get_char ()) | KBD_META;
        }
      break;
    }

  return key;
}

void
term_ungetkey (size_t key)
{
  int * codes = NULL;
  size_t i, n = keytocodes (key, &codes);

  for (i = n; i > 0; i--)
    gl_list_add_last (key_buf, (void *)(ptrdiff_t) codes[i - 1]);

  free (codes);
}
