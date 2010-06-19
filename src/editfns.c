/* Useful editing functions

   Copyright (c) 2004, 2008, 2009, 2010 Free Software Foundation, Inc.

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
#include <stdlib.h>
#include <ctype.h>
#include <string.h>
#include "gl_linked_list.h"

#include "main.h"
#include "extern.h"

static gl_list_t mark_ring = NULL;	/* Mark ring. */

/* Push the current mark to the mark-ring. */
void
push_mark (void)
{
  if (!mark_ring)
    mark_ring = gl_list_create_empty (GL_LINKED_LIST,
                                      NULL, NULL, NULL, true);

  /* Save the mark.  */
  if (get_buffer_mark (cur_bp ()) != LUA_REFNIL)
    gl_list_add_last (mark_ring, (void *) copy_marker (get_buffer_mark (cur_bp ())));
  else
    { /* Save an invalid mark.  */
      int m;
      CLUE_DO (L, "m = marker_new ()");
      CLUE_DO (L, "move_marker (m, cur_bp, point_min ())");
      lua_getglobal (L, "m");
      m = luaL_ref (L, LUA_REGISTRYINDEX);
      set_point_p (get_marker_pt (m), LUA_REFNIL);
      gl_list_add_last (mark_ring, (void *) m);
    }
}

/* Pop a mark from the mark-ring and make it the current mark. */
void
pop_mark (void)
{
  int m = (int) gl_list_get_at (mark_ring, gl_list_size (mark_ring) - 1);

  /* Replace the mark. */
  if (get_buffer_mark (get_marker_bp (m)))
    free_marker (get_buffer_mark (get_marker_bp (m)));

  set_buffer_mark (get_marker_bp (m), copy_marker (m));

  assert (gl_list_remove_at (mark_ring, gl_list_size (mark_ring) - 1));
  free_marker (m);
}

/* Set the mark to point. */
void
set_mark (void)
{
  if (get_buffer_mark (cur_bp ()) == LUA_REFNIL)
    set_buffer_mark (cur_bp (), point_marker ());
  else
    move_marker (get_buffer_mark (cur_bp ()), cur_bp (), point_copy (get_buffer_pt (cur_bp ())));
}

bool
is_empty_line (void)
{
  int pt = get_buffer_pt (cur_bp ());
  return strlen (get_line_text (get_point_p (pt))) == 0;
}

bool
is_blank_line (void)
{
  int pt = get_buffer_pt (cur_bp ());
  size_t c;
  for (c = 0; c < strlen (get_line_text (get_point_p (pt))); c++)
    if (!isspace ((int) get_line_text (get_point_p (pt))[c]))
      return false;
  return true;
}

/* Returns the character following point in the current buffer. */
int
following_char (void)
{
  if (eobp ())
    return 0;
  else if (eolp ())
    return '\n';
  else
    {
      int pt = get_buffer_pt (cur_bp ());
      return get_line_text (get_point_p (pt))[get_point_o (pt)];
    }
}

/* Return the character preceding point in the current buffer. */
int
preceding_char (void)
{
  if (bobp ())
    return 0;
  else if (bolp ())
    return '\n';
  else
    {
      int pt = get_buffer_pt (cur_bp ());
      return get_line_text (get_point_p (pt))[get_point_o (pt) - 1];
    }
}

/* Return true if point is at the beginning of the buffer. */
bool
bobp (void)
{
  int pt = get_buffer_pt (cur_bp ());
  return (lua_refeq (L, get_line_prev (get_point_p (pt)), get_buffer_lines (cur_bp ())) && get_point_o (pt) == 0);
}

/* Return true if point is at the end of the buffer. */
bool
eobp (void)
{
  int pt = get_buffer_pt (cur_bp ());
  return (lua_refeq (L, get_line_next (get_point_p (pt)), get_buffer_lines (cur_bp ())) &&
          get_point_o (pt) == strlen (get_line_text (get_point_p (pt))));
}

/* Return true if point is at the beginning of a line. */
bool
bolp (void)
{
  int pt = get_buffer_pt (cur_bp ());
  return get_point_o (pt) == 0;
}

/* Return true if point is at the end of a line. */
bool
eolp (void)
{
  int pt = get_buffer_pt (cur_bp ());
  return get_point_o (pt) == strlen (get_line_text (get_point_p (pt)));
}
