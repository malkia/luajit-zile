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

static char *
make_screen_pos (int wp, char **buf)
{
  bool tv = window_top_visible (wp);
  bool bv = window_bottom_visible (wp);

  if (tv && bv)
    xasprintf (buf, "All");
  else if (tv)
    xasprintf (buf, "Top");
  else if (bv)
    xasprintf (buf, "Bot");
  else
    xasprintf (buf, "%2d%%",
               (int) ((float) get_point_n (window_pt (wp)) / get_buffer_last_line (get_window_bp (wp)) * 100));

  return *buf;
}

static void
draw_status_line (size_t line, int wp)
{
  size_t i, tw;
  char *buf, *eol_type;
  int pt = window_pt (wp);
  int bp = get_window_bp (wp);
  astr as, bs;
  const char *mlf;

  lua_rawgeti (L, LUA_REGISTRYINDEX, wp);
  lua_setglobal (L, "wp");
  (void) CLUE_DO (L, "mlf = make_mode_line_flags (wp)");
  CLUE_GET (L, mlf, string, mlf);

  (void) CLUE_DO (L, "tw = term_width ()");
  CLUE_GET (L, w, integer, tw);

  (void) CLUE_DO (L, "term_attrset (FONT_REVERSE)");

  CLUE_SET (L, y, integer, line);
  (void) CLUE_DO (L, "term_move (y, 0)");
  for (i = 0; i < get_window_ewidth (wp); ++i)
    (void) CLUE_DO (L, "term_addch (string.byte ('-'))");

  if (get_buffer_eol (cur_bp ()) == coding_eol_cr)
    eol_type = "(Mac)";
  else if (get_buffer_eol (cur_bp ()) == coding_eol_crlf)
    eol_type = "(DOS)";
  else
    eol_type = ":";

  CLUE_SET (L, y, integer, line);
  (void) CLUE_DO (L, "term_move (y, 0)");
  bs = astr_afmt (astr_new (), "(%d,%d)", get_point_n (pt) + 1,
                  get_goalc_bp (bp, pt));
  as = astr_afmt (astr_new (), "--%s%2s  %-15s   %s %-9s (Fundamental",
                  eol_type, mlf, get_buffer_name (bp),
                  make_screen_pos (wp, &buf), astr_cstr (bs));
  free (buf);
  astr_delete (bs);

  if (get_buffer_autofill (bp))
    astr_cat_cstr (as, " Fill");
  if (get_buffer_overwrite (bp))
    astr_cat_cstr (as, " Ovwrt");
  if (thisflag & FLAG_DEFINING_MACRO)
    astr_cat_cstr (as, " Def");
  if (get_buffer_isearch (bp))
    astr_cat_cstr (as, " Isearch");

  astr_cat_char (as, ')');
  astr_truncate (as, MIN (tw, astr_len (as)));
  CLUE_SET (L, as, string, astr_cstr (as));
  (void) CLUE_DO (L, "term_addstr (as)");
  astr_delete (as);

  (void) CLUE_DO (L, "term_attrset (FONT_NORMAL)");
}

static size_t cur_topline;

void
term_redisplay (void)
{
  size_t topline;
  int wp;

  cur_topline = topline = 0;

  (void) CLUE_DO (L, "calculate_start_column (cur_wp)");
  fprintf (stderr, "startcol %d\n", get_window_start_column (cur_wp ()));

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
        draw_status_line (topline + get_window_eheight (wp), wp);

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
