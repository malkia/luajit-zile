/* Terminal independent redisplay routines

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2008, 2009, 2010 Free Software Foundation, Inc.

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

#include <stdarg.h>

#include "config.h"
#include "main.h"
#include "extern.h"

void
resync_redisplay (int wp)
{
  int delta = get_point_n (get_buffer_pt (get_window_bp (wp))) - get_window_lastpointn (wp);

  if (delta)
    {
      if ((delta > 0 && get_window_topdelta (wp) + delta < get_window_eheight (wp)) ||
          (delta < 0 && get_window_topdelta (wp) >= (size_t) (-delta)))
        set_window_topdelta (wp, get_window_topdelta (wp) + delta);
      else if (get_point_n (get_buffer_pt (get_window_bp (wp))) > get_window_eheight (wp) / 2)
        set_window_topdelta (wp, get_window_eheight (wp) / 2);
      else
        set_window_topdelta (wp, get_point_n (get_buffer_pt (get_window_bp (wp))));
    }
  set_window_lastpointn (wp, get_point_n (get_buffer_pt (get_window_bp (wp))));
}

void
resize_windows (void)
{
  int wp;
  int hdelta;
  size_t h;
  (void) CLUE_DO (L, "w = term_height ()");
  CLUE_GET (L, h, integer, h);

  /* Resize windows horizontally. */
  for (wp = head_wp; wp != LUA_REFNIL; wp = get_window_next (wp))
    {
      size_t w;
      (void) CLUE_DO (L, "w = term_width ()");
      CLUE_GET (L, w, integer, w);
      set_window_fwidth (wp,  w);
      set_window_ewidth (wp, get_window_fwidth (wp));
    }

  /* Work out difference in window height; windows may be taller than
     terminal if the terminal was very short. */
  for (hdelta = h - 1, wp = head_wp;
       wp != LUA_REFNIL;
       hdelta -= get_window_fheight (wp), wp = get_window_next (wp))
    ;

  /* Resize windows vertically. */
  if (hdelta > 0)
    { /* Increase windows height. */
      for (wp = head_wp; hdelta > 0; wp = get_window_next (wp))
        {
          if (wp == LUA_REFNIL)
            wp = head_wp;
          set_window_fheight (wp, get_window_fheight (wp) + 1);
          set_window_eheight (wp, get_window_eheight (wp) + 1);
          --hdelta;
        }
    }
  else
    { /* Decrease windows' height, and close windows if necessary. */
      int decreased = true;
      while (decreased)
        {
          decreased = false;
          for (wp = head_wp; wp != LUA_REFNIL && hdelta < 0; wp = get_window_next (wp))
            {
              if (get_window_fheight (wp) > 2)
                {
                  set_window_fheight (wp, get_window_fheight (wp) - 1);
                  set_window_eheight (wp, get_window_eheight (wp) - 1);
                  ++hdelta;
                  decreased = true;
                }
              else if (cur_wp != head_wp || get_window_next (cur_wp) != LUA_REFNIL)
                {
                  int new_wp = get_window_next (wp);
                  delete_window (wp);
                  wp = new_wp;
                  decreased = true;
                }
            }
        }
    }

  FUNCALL (recenter);
}

void
recenter (int wp)
{
  int pt = window_pt (wp);

  if (get_point_n (pt) > get_window_eheight (wp) / 2)
    set_window_topdelta (wp, get_window_eheight (wp) / 2);
  else
    set_window_topdelta (wp, get_point_n (pt));
}

DEFUN ("recenter", recenter)
/*+
Center point in window and redisplay screen.
The desired position of point is always relative to the current window.
+*/
{
  recenter (cur_wp);
  term_full_redisplay ();
}
END_DEFUN
