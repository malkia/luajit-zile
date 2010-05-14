/* Marker facility functions

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

#include <stdlib.h>
#include <ctype.h>
#include <string.h>

#include "main.h"
#include "extern.h"

/*
 * Structure
 */

#define FIELD(cty, lty, field)              \
  LUA_GETTER (marker, cty, lty, field)      \
  LUA_SETTER (marker, cty, lty, field)

#define TABLE_FIELD(field)                       \
  LUA_TABLE_GETTER (marker, field)               \
  LUA_TABLE_SETTER (marker, field)

#include "marker.h"
#undef FIELD

void
free_marker (int marker)
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, marker);
  lua_setglobal (L, "marker");
  (void) CLUE_DO (L, "unchain_marker (marker)");
  luaL_unref (L, LUA_REGISTRYINDEX, marker);
}

void
move_marker (int marker, int bp, Point * pt)
{
  if (!lua_refeq (L, bp, get_marker_bp (marker)))
    {
      /* Unchain with the previous pointed buffer.  */
      lua_rawgeti (L, LUA_REGISTRYINDEX, marker);
      lua_setglobal (L, "marker");
      (void) CLUE_DO (L, "unchain_marker (marker)");

      /* Change the buffer.  */
      set_marker_bp (marker, bp);

      /* Chain with the new buffer.  */
      set_marker_next (marker, get_buffer_markers (bp));
      set_buffer_markers (bp, marker);
    }

  /* Change the point.  */
  set_marker_pt (marker, point_copy (pt));
}

int
copy_marker (int m)
{
  int marker = LUA_NOREF;
  if (m != LUA_NOREF)
    {
      (void) CLUE_DO (L, "m = marker_new ()");
      lua_getglobal (L, "m");
      marker = luaL_ref (L, LUA_REGISTRYINDEX);
      move_marker (marker, get_marker_bp (m), get_marker_pt (m));
    }
  return marker;
}

int
point_marker (void)
{
  int marker;
  (void) CLUE_DO (L, "m = marker_new ()");
  lua_getglobal (L, "m");
  marker = luaL_ref (L, LUA_REGISTRYINDEX);
  move_marker (marker, cur_bp, point_copy (get_buffer_pt (cur_bp)));
  return marker;
}
