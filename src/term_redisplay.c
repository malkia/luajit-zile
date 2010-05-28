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

static void
calculate_highlight_region (int wp, int rp, int *highlight)
{
  if ((wp != cur_wp
       && !get_variable_bool ("highlight-nonselected-windows"))
      || (get_buffer_mark (get_window_bp (wp)) == LUA_REFNIL)
      || (!transient_mark_mode ())
      || (transient_mark_mode () && !get_buffer_mark_active (get_window_bp (wp))))
    {
      *highlight = false;
      return;
    }

  *highlight = true;
  set_region_start (rp, window_pt (wp));
  set_region_finish (rp, get_marker_pt (get_buffer_mark (get_window_bp (wp))));
  if (cmp_point (get_region_finish (rp), get_region_start (rp)) < 0)
    {
      int pt = point_copy (get_region_start (rp));
      set_region_start (rp, get_region_finish (rp));
      set_region_finish (rp, pt);
    }
}

static void
draw_window (size_t topline, int wp)
{
  size_t i, startcol, lineno;
  int lp, highlight;
  int rp = region_new ();
  int pt = window_pt (wp);

  calculate_highlight_region (wp, rp, &highlight);

  /* Find the first line to display on the first screen line. */
  for (lp = get_point_p (pt), lineno = get_point_n (pt), i = get_window_topdelta (wp);
       i > 0 && !lua_refeq (L, get_line_prev (lp), get_buffer_lines (get_window_bp (wp)));
       lp = get_line_prev (lp), --i, --lineno)
    ;

  CLUE_SET (L, cur_tab_width, integer, tab_width (get_window_bp (wp)));

  /* Draw the window lines. */
  for (i = topline; i < get_window_eheight (wp) + topline; ++i, ++lineno)
    {
      /* Clear the line. */
      CLUE_SET (L, y, integer, i);
      (void) CLUE_DO (L, "term_move (y, 0)");
      (void) CLUE_DO (L, "term_clrtoeol ()");

      /* If at the end of the buffer, don't write any text. */
      if (lua_refeq (L, lp, get_buffer_lines (get_window_bp (wp))))
        continue;

      startcol = get_window_start_column (wp);

      CLUE_SET (L, i, integer, i);
      CLUE_SET (L, startcol, integer, startcol);
      CLUE_SET (L, lineno, integer, lineno);
      CLUE_SET (L, highlight, boolean, highlight);
      lua_rawgeti (L, LUA_REGISTRYINDEX, wp);
      lua_setglobal (L, "wp");
      lua_rawgeti (L, LUA_REGISTRYINDEX, lp);
      lua_setglobal (L, "lp");
      lua_rawgeti (L, LUA_REGISTRYINDEX, rp);
      lua_setglobal (L, "rp");
      (void) CLUE_DO (L, "draw_line (i, startcol, wp, lp, lineno, rp, highlight)");

      if (get_window_start_column (wp) > 0)
        {
          CLUE_SET (L, y, integer, i);
          (void) CLUE_DO (L, "term_move (y, 0)");
          (void) CLUE_DO (L, "term_addch (string.byte ('$'))");
        }

      lp = get_line_next (lp);
    }

  luaL_unref (L, LUA_REGISTRYINDEX, rp);
}

static char *
make_mode_line_flags (int wp)
{
  static char buf[3];

  if (get_buffer_modified (get_window_bp (wp)) && get_buffer_readonly (get_window_bp (wp)))
    buf[0] = '%', buf[1] = '*';
  else if (get_buffer_modified (get_window_bp (wp)))
    buf[0] = buf[1] = '*';
  else if (get_buffer_readonly (get_window_bp (wp)))
    buf[0] = buf[1] = '%';
  else
    buf[0] = buf[1] = '-';

  return buf;
}

static size_t point_screen_column;

/*
 * This function calculates the best start column to draw if the line
 * needs to get truncated.
 * Called only for the line where is the point.
 */
static void
calculate_start_column (int wp)
{
  size_t col = 0, lastcol = 0, t = tab_width (get_window_bp (wp));
  int lpfact;
  size_t lp, p;
  int pt = window_pt (wp);
  size_t rp = get_point_o (pt);
  int rpfact = get_point_o (pt) / (get_window_ewidth (wp) / 3);

  for (lp = rp; lp != SIZE_MAX; --lp)
    {
      for (col = 0, p = lp; p < rp; ++p)
        if (get_line_text (get_point_p (pt))[p] == '\t')
          {
            col |= t - 1;
            ++col;
          }
        else if (isprint ((int) get_line_text (get_point_p (pt))[p]))
          ++col;
        else
          {
            const char *buf;
            char c = get_line_text (get_point_p (pt))[p];
            CLUE_SET (L, c, integer, c);
            (void) CLUE_DO (L, "s = make_char_printable (c)");
            CLUE_GET (L, s, string, buf);
            col += strlen (buf);
          }

      lpfact = lp / (get_window_ewidth (wp) / 3);

      if (col >= get_window_ewidth (wp) - 1 || lpfact < (rpfact - 2))
        {
          set_window_start_column (wp, lp + 1);
          point_screen_column = lastcol;
          return;
        }

      lastcol = col;
    }

  set_window_start_column (wp, 0);
  point_screen_column = col;
}

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
                  eol_type, make_mode_line_flags (wp), get_buffer_name (bp),
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

  calculate_start_column (cur_wp);

  for (wp = head_wp; wp != LUA_REFNIL; wp = get_window_next (wp))
    {
      if (wp == cur_wp)
        cur_topline = topline;

      draw_window (topline, wp);

      /* Draw the status line only if there is available space after the
         buffer text space. */
      if (get_window_fheight (wp) - get_window_eheight (wp) > 0)
        draw_status_line (topline + get_window_eheight (wp), wp);

      topline += get_window_fheight (wp);
    }

  /* Redraw cursor. */
  CLUE_SET (L, y, integer, cur_topline + get_window_topdelta (cur_wp));
  CLUE_SET (L, x, integer, point_screen_column);
  (void) CLUE_DO (L, "term_move (y, x)");
}

void
term_full_redisplay (void)
{
  (void) CLUE_DO (L, "term_clear ()");
  term_redisplay ();
}
