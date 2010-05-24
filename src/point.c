/* Point facility functions

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

#include "main.h"
#include "extern.h"


/*
 * Structure
 */

#define FIELD(cty, lty, field)              \
  LUA_GETTER (point, cty, lty, field)       \
  LUA_SETTER (point, cty, lty, field)

#define TABLE_FIELD(field)                       \
  LUA_TABLE_GETTER (point, field)                \
  LUA_TABLE_SETTER (point, field)

#include "point.h"
#undef FIELD
#undef TABLE_FIELD


int
point_new (void)
{
  lua_newtable (L);
  return luaL_ref (L, LUA_REGISTRYINDEX);
}

int
make_point (size_t lineno, size_t offset)
{
  int pt = point_new ();
  set_point_p (pt, get_line_next (get_buffer_lines (cur_bp)));
  set_point_n (pt, lineno);
  set_point_o (pt, offset);
  while (lineno > 0)
    {
      set_point_p (pt, get_line_next (get_point_p (pt)));
      lineno--;
    }
  return pt;
}

int
point_copy (int pt)
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, pt);
  lua_setglobal (L, "pt");
  (void) CLUE_DO (L, "newpt = table.clone (pt)");
  lua_getglobal (L, "newpt");
  return luaL_ref (L, LUA_REGISTRYINDEX);
}

int
cmp_point (int pt1, int pt2)
{
  if (get_point_n (pt1) < get_point_n (pt2))
    return -1;
  else if (get_point_n (pt1) > get_point_n (pt2))
    return +1;
  else
    return ((get_point_o (pt1) < get_point_o (pt2)) ? -1 : (get_point_o (pt1) > get_point_o (pt2)) ? +1 : 0);
}

int
point_min (void)
{
  int pt = point_new ();
  set_point_p (pt, get_line_next (get_buffer_lines (cur_bp)));
  set_point_n (pt, 0);
  set_point_o (pt, 0);
  return pt;
}

int
point_max (void)
{
  int pt = point_new ();
  set_point_p (pt, get_line_prev (get_buffer_lines (cur_bp)));
  set_point_n (pt, get_buffer_last_line (cur_bp));
  set_point_o (pt, astr_len (get_line_text (get_line_prev (get_buffer_lines (cur_bp)))));
  return pt;
}

int
line_beginning_position (int count)
{
  int pt;

  /* Copy current point position without offset (beginning of
   * line). */
  pt = point_copy (get_buffer_pt (cur_bp));
  set_point_o (pt, 0);

  count--;
  for (; count < 0 && !lua_refeq (L, get_line_prev (get_point_p (pt)), get_buffer_lines (cur_bp)); count++)
    {
      set_point_p (pt, get_line_prev (get_point_p (pt)));
      set_point_n (pt, get_point_n (pt) - 1);
    }
  for (; count > 0 && !lua_refeq (L, get_line_next (get_point_p (pt)), get_buffer_lines (cur_bp)); count--)
    {
      set_point_p (pt, get_line_next (get_point_p (pt)));
      set_point_n (pt, get_point_n (pt) + 1);
    }

  return pt;
}

int
line_end_position (int count)
{
  int pt = point_copy (line_beginning_position (count));
  set_point_o (pt, astr_len (get_line_text (get_point_p (pt))));
  return pt;
}

/* Go to coordinates described by pt (ignoring pt.p) */
void
goto_point (int pt)
{
  if (get_point_n (get_buffer_pt (cur_bp)) > get_point_n (pt))
    do
      FUNCALL (previous_line);
    while (get_point_n (get_buffer_pt (cur_bp)) > get_point_n (pt));
  else if (get_point_n (get_buffer_pt (cur_bp)) < get_point_n (pt))
    do
      FUNCALL (next_line);
    while (get_point_n (get_buffer_pt (cur_bp)) < get_point_n (pt));

  if (get_point_o (get_buffer_pt (cur_bp)) > get_point_o (pt))
    do
      FUNCALL (backward_char);
    while (get_point_o (get_buffer_pt (cur_bp)) > get_point_o (pt));
  else if (get_point_o (get_buffer_pt (cur_bp)) < get_point_o (pt))
    do
      FUNCALL (forward_char);
    while (get_point_o (get_buffer_pt (cur_bp)) < get_point_o (pt));
}
