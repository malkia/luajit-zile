/* Undo facility functions

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

/* Setting this variable to true stops undo_save saving the given
   information. */
int undo_nosave = false;

/* This variable is set to true when an undo is in execution. */
static int doing_undo = false;

/*
 * Save a reverse delta for doing undo.
 */
void
undo_save (int type, int pt, size_t osize, size_t size)
{
  int up;

  if (get_buffer_noundo (cur_bp) || undo_nosave)
    return;

  lua_newtable (L);
  up = luaL_ref (L, LUA_REGISTRYINDEX);
  set_undo_type (up, type);
  set_undo_pt (up, point_copy (pt));
  if (!get_buffer_modified (cur_bp))
    set_undo_unchanged (up, true);

  if (type == UNDO_REPLACE_BLOCK)
    {
      set_undo_osize (up, osize);
      set_undo_size (up, size);
      set_undo_text (up, copy_text_block (point_copy (pt), osize));
    }

  set_undo_next (up, get_buffer_last_undop (cur_bp));
  set_buffer_last_undop (cur_bp, up);

  if (!doing_undo)
    set_buffer_next_undop (cur_bp, up);
}

/*
 * Revert an action.  Return the next undo entry.
 */
static int
revert_action (int up)
{
  size_t i;

  doing_undo = true;

  if (get_undo_type (up) == UNDO_END_SEQUENCE)
    {
      undo_save (UNDO_START_SEQUENCE, get_undo_pt (up), 0, 0);
      up = get_undo_next (up);
      while (get_undo_type (up) != UNDO_START_SEQUENCE)
        up = revert_action (up);
      undo_save (UNDO_END_SEQUENCE, get_undo_pt (up), 0, 0);
      goto_point (get_undo_pt (up));
      return get_undo_next (up);
    }

  goto_point (get_undo_pt (up));

  if (get_undo_type (up) == UNDO_REPLACE_BLOCK)
    {
      undo_save (UNDO_REPLACE_BLOCK, get_undo_pt (up), get_undo_size (up), get_undo_osize (up));
      undo_nosave = true;
      for (i = 0; i < get_undo_size (up); ++i)
        delete_char ();
      insert_nstring (astr_cstr (get_undo_text (up)), get_undo_osize (up));
      undo_nosave = false;
    }

  doing_undo = false;

  if (get_undo_unchanged (up))
    set_buffer_modified (cur_bp, false);

  return get_undo_next (up);
}

DEFUN ("undo", undo)
/*+
Undo some previous changes.
Repeat this command to undo more changes.
+*/
{
  if (get_buffer_noundo (cur_bp))
    {
      minibuf_error ("Undo disabled in this buffer");
      return leNIL;
    }

  if (warn_if_readonly_buffer ())
    return leNIL;

  if (get_buffer_next_undop (cur_bp) == LUA_REFNIL)
    {
      minibuf_error ("No further undo information");
      set_buffer_next_undop (cur_bp, get_buffer_last_undop (cur_bp));
      return leNIL;
    }

  set_buffer_next_undop (cur_bp, revert_action (get_buffer_next_undop (cur_bp)));
  minibuf_write ("Undo!");
}
END_DEFUN

void
free_undo (int up)
{
  while (up != LUA_REFNIL)
    {
      int next_up = get_undo_next (up);
      if (get_undo_type (up) == UNDO_REPLACE_BLOCK)
        astr_delete (get_undo_text (up));
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
