/* Window handling functions

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
#define FIELD(cty, lty, field)              \
  LUA_GETTER (window, cty, lty, field)      \
  LUA_SETTER (window, cty, lty, field)

#define TABLE_FIELD(field)                       \
  LUA_TABLE_GETTER (window, field)               \
  LUA_TABLE_SETTER (window, field)

#include "window.h"
#undef FIELD
#undef TABLE_FIELD

void
delete_window (int del_wp)
{
  int wp;

  if (del_wp == head_wp ())
    {
      wp = get_window_next (head_wp ());
      set_head_wp (wp);
    }
  else
    for (wp = head_wp (); wp != LUA_REFNIL; wp = get_window_next (wp))
      if (get_window_next (wp) == del_wp)
        {
          set_window_next (wp, get_window_next (get_window_next (wp)));
          break;
        }

  if (wp != LUA_REFNIL)
    {
      set_window_fheight (wp, get_window_fheight (wp) + get_window_fheight (del_wp));
      set_window_eheight (wp, get_window_eheight (wp) + get_window_eheight (del_wp) + 1);
      lua_rawgeti (L, LUA_REGISTRYINDEX, wp);
      lua_setglobal (L, "wp");
      CLUE_DO (L, "set_current_window (wp)");
    }

  if (get_window_saved_pt (del_wp) != LUA_REFNIL)
    free_marker (get_window_saved_pt (del_wp));

  luaL_unref (L, LUA_REGISTRYINDEX, del_wp);
}

DEFUN ("delete-window", delete_window)
/*+
Remove the current window from the screen.
+*/
{
  if (cur_wp () == head_wp () && get_window_next (cur_wp ()) == LUA_REFNIL)
    {
      minibuf_error ("Attempt to delete sole ordinary window");
      return leNIL;
    }

  delete_window (cur_wp ());
}
END_DEFUN

DEFUN ("enlarge-window", enlarge_window)
/*+
Make current window one line bigger.
+*/
{
  int wp;

  if (cur_wp () == head_wp () && get_window_next (cur_wp ()) == LUA_REFNIL)
    return leNIL;

  wp = get_window_next (cur_wp ());
  if (wp == LUA_REFNIL || get_window_fheight (wp) < 3)
    for (wp = head_wp (); wp != LUA_REFNIL; wp = get_window_next (wp))
      if (get_window_next (wp) == cur_wp ())
        {
          if (get_window_fheight (wp) < 3)
            return leNIL;
          break;
        }

  if (cur_wp () == head_wp () && get_window_fheight (get_window_next (cur_wp ())) < 3)
    return leNIL;

  set_window_fheight (wp, get_window_fheight (wp) - 1);
  set_window_eheight (wp, get_window_eheight (wp) - 1);
  if (get_window_topdelta (wp) >= get_window_eheight (wp))
    {
      lua_rawgeti (L, LUA_REGISTRYINDEX, wp);
      lua_setglobal (L, "wp");
      CLUE_DO (L, "recenter (wp)");
    }
  set_window_fheight (cur_wp (), get_window_fheight (cur_wp ()) + 1);
  set_window_eheight (cur_wp (), get_window_eheight (cur_wp ()) + 1);
}
END_DEFUN

DEFUN ("shrink-window", shrink_window)
/*+
Make current window one line smaller.
+*/
{
  int wp;

  if ((cur_wp () == head_wp () && get_window_next (cur_wp ()) == LUA_REFNIL) || get_window_fheight (cur_wp ()) < 3)
    return leNIL;

  wp = get_window_next (cur_wp ());
  if (wp == LUA_REFNIL)
    {
      for (wp = head_wp (); wp != LUA_REFNIL; wp = get_window_next (wp))
        if (get_window_next (wp) == cur_wp ())
          break;
    }

  set_window_fheight (wp, get_window_fheight (wp) + 1);
  set_window_eheight (wp, get_window_eheight (wp) + 1);
  set_window_fheight (cur_wp (), get_window_fheight (cur_wp ()) - 1);
  set_window_eheight (cur_wp (), get_window_eheight (cur_wp ()) - 1);
  if (get_window_topdelta (cur_wp ()) >= get_window_eheight (cur_wp ()))
    {
      lua_rawgeti (L, LUA_REGISTRYINDEX, cur_wp ());
      lua_setglobal (L, "wp");
      CLUE_DO (L, "recenter (wp)");
    }
}
END_DEFUN

DEFUN ("delete-other-windows", delete_other_windows)
/*+
Make the selected window fill the screen.
+*/
{
  int wp, nextwp;
  size_t w, h;

  CLUE_DO (L, "w, h = term_width (), term_height ()");
  CLUE_GET (L, w, integer, w);
  CLUE_GET (L, h, integer, h);

  for (wp = head_wp (); wp != LUA_REFNIL; wp = nextwp)
    {
      nextwp = get_window_next (wp);
      if (wp != cur_wp ())
        delete_window (wp);
    }
}
END_DEFUN

DEFUN ("other-window", other_window)
/*+
Select the first different window on the screen.
All windows are arranged in a cyclic order.
This command selects the window one step away in that order.
+*/
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, (get_window_next (cur_wp ()) != LUA_REFNIL) ? get_window_next (cur_wp ()) : head_wp ());
  lua_setglobal (L, "wp");
  CLUE_DO (L, "set_current_window (wp)");
}
END_DEFUN

/*
 * This function creates the scratch buffer and window when there are
 * no other windows (and possibly no other buffers).
 */
void
create_scratch_window (void)
{
  int wp;
  int bp = create_scratch_buffer ();
  size_t w, h;

  CLUE_DO (L, "w, h = term_width (), term_height ()");
  CLUE_GET (L, w, integer, w);
  CLUE_GET (L, h, integer, h);
  CLUE_DO (L, "wp = window_new ()");
  lua_getglobal (L, "wp");
  wp = luaL_ref (L, LUA_REGISTRYINDEX);

  set_cur_wp (wp);
  set_head_wp (wp);
  set_window_fwidth (wp, w);
  set_window_ewidth (wp, w);
  /* Save space for minibuffer. */
  set_window_fheight (wp, h - 1);
  /* Save space for status line. */
  set_window_eheight (wp, get_window_fheight (wp) - 1);
  set_cur_bp (bp);
  set_window_bp (wp, cur_bp ());
}

int
window_pt (int wp)
{
  /* The current window uses the current buffer point; all other
     windows have a saved point, except that if a window has just been
     killed, it needs to use its new buffer's current point. */
  assert (wp != LUA_REFNIL);
  if (wp == cur_wp ())
    {
      assert (lua_refeq (L, get_window_bp (wp), cur_bp ()));
      assert (get_window_saved_pt (wp) == LUA_REFNIL);
      assert (cur_bp ());
      return point_copy (get_buffer_pt (cur_bp ()));
    }
  else
    {
      if (get_window_saved_pt (wp) != LUA_REFNIL)
        return point_copy (get_marker_pt (get_window_saved_pt (wp)));
      else
        return point_copy (get_buffer_pt (get_window_bp (wp)));
    }
}

bool
window_top_visible (int wp)
{
  return get_point_n (window_pt (wp)) == get_window_topdelta (wp);
}

bool
window_bottom_visible (int wp)
{
  return get_point_n (window_pt (wp)) + (get_window_eheight (wp) - get_window_topdelta (wp)) >
    get_buffer_last_line (get_window_bp (wp));
}
