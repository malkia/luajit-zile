/* Redisplay engine

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

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "config.h"
#include "extern.h"

static size_t cur_topline;

void
term_redisplay (void)
{
  size_t topline;
  int wp;

  cur_topline = topline = 0;

  (void) CLUE_DO (L, "calculate_start_column (cur_wp)");

  for (wp = head_wp (); wp != LUA_REFNIL; wp = get_window_next (wp))
    {
      if (wp == cur_wp ())
        cur_topline = topline;

      CLUE_SET (L, topline, integer, topline);
      lua_rawgeti (L, LUA_REGISTRYINDEX, wp);
      lua_setglobal (L, "wp");
      (void) CLUE_DO (L, "draw_window (topline, wp)");

      /* Draw the status line only if there is available space after the
         buffer text space. */
      if (get_window_fheight (wp) - get_window_eheight (wp) > 0)
        {
          CLUE_SET (L, topline, integer, topline);
          lua_rawgeti (L, LUA_REGISTRYINDEX, wp);
          lua_setglobal (L, "wp");
          (void) CLUE_DO (L, "draw_status_line (topline + wp.eheight, wp)");
        }

      topline += get_window_fheight (wp);
    }

  /* Redraw cursor. */
  CLUE_SET (L, y, integer, cur_topline + get_window_topdelta (cur_wp ()));
  (void) CLUE_DO (L, "term_move (y, point_screen_column)");
}

void
term_full_redisplay (void)
{
  (void) CLUE_DO (L, "term_clear ()");
  term_redisplay ();
}
