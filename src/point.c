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

#include "main.h"
#include "extern.h"


/*
 * Structure
 */

struct Point
{
#define FIELD(ty, name) ty name;
#include "point.h"
#undef FIELD
};

#define FIELD(ty, field)                       \
  GETTER (Point, point, ty, field)             \
  SETTER (Point, point, ty, field)

#include "point.h"
#undef FIELD


Point *
point_new (void)
{
  return XZALLOC (Point);
}

Point *
make_point (size_t lineno, size_t offset)
{
  Point * pt = XZALLOC (Point);
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

Point *
point_copy (Point *pt)
{
  Point * newpt = XZALLOC (Point);
  *newpt = *pt;
  return newpt;
}

int
cmp_point (Point * pt1, Point * pt2)
{
  if (get_point_n (pt1) < get_point_n (pt2))
    return -1;
  else if (get_point_n (pt1) > get_point_n (pt2))
    return +1;
  else
    return ((get_point_o (pt1) < get_point_o (pt2)) ? -1 : (get_point_o (pt1) > get_point_o (pt2)) ? +1 : 0);
}

Point *
point_min (void)
{
  Point * pt = XZALLOC (Point);
  set_point_p (pt, get_line_next (get_buffer_lines (cur_bp)));
  set_point_n (pt, 0);
  set_point_o (pt, 0);
  return pt;
}

Point *
point_max (void)
{
  Point * pt = XZALLOC (Point);
  set_point_p (pt, get_line_prev (get_buffer_lines (cur_bp)));
  set_point_n (pt, get_buffer_last_line (cur_bp));
  set_point_o (pt, astr_len (get_line_text (get_line_prev (get_buffer_lines (cur_bp)))));
  return pt;
}

Point *
line_beginning_position (int count)
{
  Point * pt;

  /* Copy current point position without offset (beginning of
   * line). */
  pt = point_copy (get_buffer_pt (cur_bp));
  set_point_o (pt, 0);

  count--;
  for (; count < 0 && get_line_prev (get_point_p (pt)) != get_buffer_lines (cur_bp); count++)
    {
      set_point_p (pt, get_line_prev (get_point_p (pt)));
      set_point_n (pt, get_point_n (pt) - 1);
    }
  for (; count > 0 && get_line_next (get_point_p (pt)) != get_buffer_lines (cur_bp); count--)
    {
      set_point_p (pt, get_line_next (get_point_p (pt)));
      set_point_n (pt, get_point_n (pt) + 1);
    }

  return pt;
}

Point *
line_end_position (int count)
{
  Point * pt = point_copy (line_beginning_position (count));
  set_point_o (pt, astr_len (get_line_text (get_point_p (pt))));
  return pt;
}

void
goto_point (Point * pt)
{
  if (get_buffer_pt (cur_bp)->n > get_point_n (pt))
    do
      FUNCALL (previous_line);
    while (get_buffer_pt (cur_bp)->n > get_point_n (pt));
  else if (get_buffer_pt (cur_bp)->n < get_point_n (pt))
    do
      FUNCALL (next_line);
    while (get_buffer_pt (cur_bp)->n < get_point_n (pt));

  if (get_buffer_pt (cur_bp)->o > get_point_o (pt))
    do
      FUNCALL (backward_char);
    while (get_buffer_pt (cur_bp)->o > get_point_o (pt));
  else if (get_buffer_pt (cur_bp)->o < get_point_o (pt))
    do
      FUNCALL (forward_char);
    while (get_buffer_pt (cur_bp)->o < get_point_o (pt));
}
