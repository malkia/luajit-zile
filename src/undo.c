/* Undo facility functions

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

#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"

/*
 * Undo action
 */
#define FIELD(cty, lty, field)                  \
  static LUA_GETTER (undo, cty, lty, field)     \
  static LUA_SETTER (undo, cty, lty, field)
#define TABLE_FIELD(field)                            \
  static LUA_TABLE_GETTER (undo, field)               \
  static LUA_TABLE_SETTER (undo, field)

#include "undo.h"
#undef FIELD
#undef TABLE_FIELD

int undo_nosave (void)
{
  int ret;
  CLUE_GET (L, undo_nosave, boolean, ret);
  return ret;
}

void set_undo_nosave (int undo_nosave)
{
  CLUE_SET (L, undo_nosave, boolean, undo_nosave);
}

/*
 * Save a reverse delta for doing undo.
 */
void
undo_save (int type, int pt, size_t osize, size_t size)
{
  CLUE_SET (L, t, integer, type);
  lua_rawgeti (L, LUA_REGISTRYINDEX, pt);
  lua_setglobal (L, "pt");
  CLUE_SET (L, os, integer, osize);
  CLUE_SET (L, s, integer, size);
  (void) CLUE_DO (L, "undo_save (t, pt, os, s)");
}

/*
 * Revert an action.  Return the next undo entry.
 */
static int
revert_action (int up)
{
  size_t i;
  int pt = point_new ();

  set_point_n (pt, get_undo_n (up));
  set_point_o (pt, get_undo_o (up));

  CLUE_SET (L, doing_undo, boolean, true);

  if (get_undo_type (up) == UNDO_END_SEQUENCE)
    {
      undo_save (UNDO_START_SEQUENCE, pt, 0, 0);
      up = get_undo_next (up);
      while (get_undo_type (up) != UNDO_START_SEQUENCE)
        up = revert_action (up);
      set_point_n (pt, get_undo_n (up));
      set_point_o (pt, get_undo_o (up));
      undo_save (UNDO_END_SEQUENCE, pt, 0, 0);
      goto_point (pt);
      return get_undo_next (up);
    }

  goto_point (pt);

  if (get_undo_type (up) == UNDO_REPLACE_BLOCK)
    {
      undo_save (UNDO_REPLACE_BLOCK, pt, get_undo_size (up), get_undo_osize (up));
      set_undo_nosave (true);
      for (i = 0; i < get_undo_size (up); ++i)
        delete_char ();
      insert_nstring (get_undo_text (up), get_undo_osize (up));
      set_undo_nosave (false);
    }

  CLUE_SET (L, doing_undo, boolean, false);

  if (get_undo_unchanged (up))
    set_buffer_modified (cur_bp (), false);

  return get_undo_next (up);
}

DEFUN ("undo", undo)
/*+
Undo some previous changes.
Repeat this command to undo more changes.
+*/
{
  if (get_buffer_noundo (cur_bp ()))
    {
      minibuf_error ("Undo disabled in this buffer");
      return leNIL;
    }

  if (warn_if_readonly_buffer ())
    return leNIL;

  if (get_buffer_next_undop (cur_bp ()) == LUA_REFNIL)
    {
      minibuf_error ("No further undo information");
      set_buffer_next_undop (cur_bp (), get_buffer_last_undop (cur_bp ()));
      return leNIL;
    }

  set_buffer_next_undop (cur_bp (), revert_action (get_buffer_next_undop (cur_bp ())));
  minibuf_write ("Undo!");
}
END_DEFUN

void
free_undo (int up)
{
  while (up != LUA_REFNIL)
    {
      int next_up = get_undo_next (up);
      /* if (get_undo_type (up) == UNDO_REPLACE_BLOCK) */
      /*   astr_delete (get_undo_text (up)); */
      luaL_unref (L, LUA_REGISTRYINDEX, up);
      up = next_up;
    }
}

/*
 * Set unchanged flags to false.
 */
void
undo_set_unchanged (int up)
{
  for (; up != LUA_REFNIL; up = get_undo_next (up))
    set_undo_unchanged (up, false);
}
