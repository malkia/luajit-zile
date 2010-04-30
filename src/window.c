/* Window handling functions

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2008, 2009 Free Software Foundation, Inc.

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

#include <assert.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"

/*
 * Structure
 */
struct Window
{
#define FIELD(ty, name) ty name;
#include "window.h"
#undef FIELD
};

#define FIELD(ty, field)                        \
  GETTER (Window, window, ty, field)            \
  SETTER (Window, window, ty, field)

#include "window.h"
#undef FIELD

static Window *
window_new (void)
{
  return (Window *) XZALLOC (Window);
}

/*
 * Free a window's allocated memory.
 */
static void
free_window (Window * wp)
{
  if (get_window_saved_pt (wp))
    free_marker (get_window_saved_pt (wp));

  free (wp);
}

/*
 * Free all the allocated windows (used at Zile exit).
 */
void
free_windows (void)
{
  Window *wp, *next;

  for (wp = head_wp; wp != NULL; wp = next)
    {
      next = get_window_next (wp);
      free_window (wp);
    }
}

/*
 * Set the current window and his buffer as the current buffer.
 */
void
set_current_window (Window * wp)
{
  /* Save buffer's point in a new marker.  */
  if (get_window_saved_pt (cur_wp))
    free_marker (get_window_saved_pt (cur_wp));

  set_window_saved_pt (cur_wp, point_marker ());

  /* Change the current window.  */
  cur_wp = wp;

  /* Change the current buffer.  */
  cur_bp = get_window_bp (wp);

  /* Update the buffer point with the window's saved point
     marker.  */
  if (get_window_saved_pt (cur_wp))
    {
      set_buffer_pt (cur_bp, get_marker_pt (get_window_saved_pt (cur_wp)));
      free_marker (get_window_saved_pt (cur_wp));
      set_window_saved_pt (cur_wp, NULL);
    }
}

DEFUN ("split-window", split_window)
/*+
Split current window into two windows, one above the other.
Both windows display the same buffer now current.
+*/
{
  Window *newwp;

  /* Windows smaller than 4 lines cannot be split. */
  if (get_window_fheight (cur_wp) < 4)
    {
      minibuf_error ("Window height %d too small for splitting",
                     get_window_fheight (cur_wp));
      return leNIL;
    }

  newwp = window_new ();
  set_window_fwidth (newwp, get_window_fwidth (cur_wp));
  set_window_ewidth (newwp, get_window_ewidth (cur_wp));
  set_window_fheight (newwp, get_window_fheight (cur_wp) / 2 + get_window_fheight (cur_wp) % 2);
  set_window_eheight (newwp, get_window_fheight (newwp) - 1);
  set_window_fheight (cur_wp, get_window_fheight (cur_wp) / 2);
  set_window_eheight (cur_wp, get_window_fheight (cur_wp) - 1);
  if (get_window_topdelta (cur_wp) >= get_window_eheight (cur_wp))
    recenter (cur_wp);
  set_window_bp (newwp, get_window_bp (cur_wp));
  set_window_saved_pt (newwp, point_marker ());
  set_window_next (newwp, get_window_next (cur_wp));
  set_window_next (cur_wp, newwp);
}
END_DEFUN

void
delete_window (Window * del_wp)
{
  Window *wp;

  if (cur_wp == head_wp)
    wp = head_wp = get_window_next (head_wp);
  else
    for (wp = head_wp; wp != NULL; wp = get_window_next (wp))
      if (get_window_next (wp) == cur_wp)
        {
          set_window_next (wp, get_window_next (get_window_next (wp)));
          break;
        }

  if (wp != NULL)
    {
      set_window_fheight (wp, get_window_fheight (wp) + get_window_fheight (del_wp));
      set_window_eheight (wp, get_window_eheight (wp) + get_window_eheight (del_wp) + 1);
      set_current_window (wp);
    }

  free_window (del_wp);
}

DEFUN ("delete-window", delete_window)
/*+
Remove the current window from the screen.
+*/
{
  if (cur_wp == head_wp && get_window_next (cur_wp) == NULL)
    {
      minibuf_error ("Attempt to delete sole ordinary window");
      return leNIL;
    }

  delete_window (cur_wp);
}
END_DEFUN

DEFUN ("enlarge-window", enlarge_window)
/*+
Make current window one line bigger.
+*/
{
  Window *wp;

  if (cur_wp == head_wp && get_window_next (cur_wp) == NULL)
    return leNIL;

  wp = get_window_next (cur_wp);
  if (wp == NULL || get_window_fheight (wp) < 3)
    for (wp = head_wp; wp != NULL; wp = get_window_next (wp))
      if (get_window_next (wp) == cur_wp)
        {
          if (get_window_fheight (wp) < 3)
            return leNIL;
          break;
        }

  if (cur_wp == head_wp && get_window_fheight (get_window_next (cur_wp)) < 3)
    return leNIL;

  set_window_fheight (wp, get_window_fheight (wp) - 1);
  set_window_eheight (wp, get_window_eheight (wp) - 1);
  if (get_window_topdelta (wp) >= get_window_eheight (wp))
    recenter (wp);
  set_window_fheight (cur_wp, get_window_fheight (cur_wp) + 1);
  set_window_eheight (cur_wp, get_window_eheight (cur_wp) + 1);
}
END_DEFUN

DEFUN ("shrink-window", shrink_window)
/*+
Make current window one line smaller.
+*/
{
  Window *wp;

  if ((cur_wp == head_wp && get_window_next (cur_wp) == NULL) || get_window_fheight (cur_wp) < 3)
    return leNIL;

  wp = get_window_next (cur_wp);
  if (wp == NULL)
    {
      for (wp = head_wp; wp != NULL; wp = get_window_next (wp))
        if (get_window_next (wp) == cur_wp)
          break;
    }

  set_window_fheight (wp, get_window_fheight (wp) + 1);
  set_window_eheight (wp, get_window_eheight (wp) + 1);
  set_window_fheight (cur_wp, get_window_fheight (cur_wp) - 1);
  set_window_eheight (cur_wp, get_window_eheight (cur_wp) - 1);
  if (get_window_topdelta (cur_wp) >= get_window_eheight (cur_wp))
    recenter (cur_wp);
}
END_DEFUN

Window *
popup_window (void)
{
  if (get_window_next (head_wp) == NULL)
    {
      /* There is only one window on the screen, so split it. */
      FUNCALL (split_window);
      return get_window_next (cur_wp);
    }

  /* Use the window after the current one. */
  if (get_window_next (cur_wp) != NULL)
    return get_window_next (cur_wp);

  /* Use the first window. */
  return head_wp;
}

DEFUN ("delete-other-windows", delete_other_windows)
/*+
Make the selected window fill the screen.
+*/
{
  Window *wp, *nextwp;
  size_t w, h;

  (void) CLUE_DO (L, "w, h = term_width (), term_height ()");
  CLUE_GET (L, w, integer, w);
  CLUE_GET (L, h, integer, h);

  for (wp = head_wp; wp != NULL; wp = nextwp)
    {
      nextwp = get_window_next (wp);
      if (wp != cur_wp)
        free_window (wp);
    }

  set_window_fwidth (cur_wp, w);
  set_window_ewidth (cur_wp, w);
  /* Save space for minibuffer. */
  set_window_fheight (cur_wp, h - 1);
  /* Save space for status line. */
  set_window_eheight (cur_wp, get_window_fheight (cur_wp) - 1);
  set_window_next (cur_wp, NULL);
  head_wp = cur_wp;
}
END_DEFUN

DEFUN ("other-window", other_window)
/*+
Select the first different window on the screen.
All windows are arranged in a cyclic order.
This command selects the window one step away in that order.
+*/
{
  set_current_window ((get_window_next (cur_wp) != NULL) ? get_window_next (cur_wp) : head_wp);
}
END_DEFUN

/*
 * This function creates the scratch buffer and window when there are
 * no other windows (and possibly no other buffers).
 */
void
create_scratch_window (void)
{
  Window *wp;
  Buffer *bp = create_scratch_buffer ();
  size_t w, h;

  (void) CLUE_DO (L, "w, h = term_width (), term_height ()");
  CLUE_GET (L, w, integer, w);
  CLUE_GET (L, h, integer, h);

  wp = window_new ();
  cur_wp = head_wp = wp;
  set_window_fwidth (wp, w);
  set_window_ewidth (wp, w);
  /* Save space for minibuffer. */
  set_window_fheight (wp, h - 1);
  /* Save space for status line. */
  set_window_eheight (wp, get_window_fheight (wp) - 1);
  set_window_bp (wp, cur_bp = bp);
}

Window *
find_window (const char *name)
{
  Window *wp;

  for (wp = head_wp; wp != NULL; wp = get_window_next (wp))
    if (!strcmp (get_buffer_name (get_window_bp (wp)), name))
      return wp;

  return NULL;
}

Point
window_pt (Window * wp)
{
  /* The current window uses the current buffer point; all other
     windows have a saved point, except that if a window has just been
     killed, it needs to use its new buffer's current point. */
  assert (wp != NULL);
  if (wp == cur_wp)
    {
      assert (get_window_bp (wp) == cur_bp);
      assert (get_window_saved_pt (wp) == NULL);
      assert (cur_bp);
      return get_buffer_pt (cur_bp);
    }
  else
    {
      if (get_window_saved_pt (wp) != NULL)
        return get_marker_pt (get_window_saved_pt (wp));
      else
        return get_buffer_pt (get_window_bp (wp));
    }
}

/*
 * Scroll completions up.
 */
void
completion_scroll_up (void)
{
  Window *wp, *old_wp = cur_wp;
  Point pt;

  wp = find_window ("*Completions*");
  assert (wp != NULL);
  set_current_window (wp);
  pt = get_buffer_pt (cur_bp);
  if (pt.n >= get_buffer_last_line (cur_bp) - get_window_eheight (cur_wp) || !FUNCALL (scroll_up))
    gotobob ();
  set_current_window (old_wp);

  term_redisplay ();
}

/*
 * Scroll completions down.
 */
void
completion_scroll_down (void)
{
  Window *wp, *old_wp = cur_wp;
  Point pt;

  wp = find_window ("*Completions*");
  assert (wp != NULL);
  set_current_window (wp);
  pt = get_buffer_pt (cur_bp);
  if (pt.n == 0 || !FUNCALL (scroll_down))
    {
      gotoeob ();
      resync_redisplay ();
    }
  set_current_window (old_wp);

  term_redisplay ();
}

bool
window_top_visible (Window * wp)
{
  return window_pt (wp).n == get_window_topdelta (wp);
}

bool
window_bottom_visible (Window * wp)
{
  return window_pt (wp).n + (get_window_eheight (wp) - get_window_topdelta (wp)) >
    get_buffer_last_line (get_window_bp (wp));
}
