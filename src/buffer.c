/* Buffer-oriented functions

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2008, 2009, 2010 Free Software Foundation, Inc.

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
  LUA_GETTER (buffer, cty, lty, field)      \
  LUA_SETTER (buffer, cty, lty, field)

#define TABLE_FIELD(field)                       \
  LUA_TABLE_GETTER (buffer, field)               \
  LUA_TABLE_SETTER (buffer, field)

#define FIELD_STR(field)                                \
  LUA_GETTER (buffer, const char *, string, field)      \
  LUA_SETTER (buffer, const char *, string, field)

#include "buffer.h"
#undef FIELD
#undef TABLE_FIELD
#undef FIELD_STR

#define FIELD(cty, lty, field)              \
  LUA_GETTER (region, cty, lty, field)      \
  LUA_SETTER (region, cty, lty, field)

#define TABLE_FIELD(field)                       \
  LUA_TABLE_GETTER (region, field)               \
  LUA_TABLE_SETTER (region, field)

#include "region.h"
#undef FIELD
#undef TABLE_FIELD

int
buffer_new (void)
{
  CLUE_DO (L, "bp = buffer_new ()");
  lua_getglobal (L, "bp");
  return luaL_ref (L, LUA_REGISTRYINDEX);
}

/*
 * Get filename, or buffer name if NULL.
 */
const char *
get_buffer_filename_or_name (int bp)
{
  const char *fname = get_buffer_filename (bp);
  return fname ? fname : get_buffer_name (bp);
}

/*
 * Create a buffer name using the file name.
 */
static char *
make_buffer_name (const char *filename)
{
  const char *p = strrchr (filename, '/');

  if (p == NULL)
    p = filename;
  else
    ++p;

  if (find_buffer (p) == LUA_REFNIL)
    return xstrdup (p);
  else
    {
      char *name;
      size_t i;

      /* Note: there can't be more than SIZE_MAX buffers. */
      for (i = 2; true; i++)
        {
          xasprintf (&name, "%s<%ld>", p, i);
          if (find_buffer (name) == LUA_REFNIL)
            return name;
          free (name);
        }
    }
}

/*
 * Set a new filename, and from it a name, for the buffer.
 */
void
set_buffer_names (int bp, const char *filename)
{
  astr as = NULL;

  if (filename[0] != '/')
    {
      as = agetcwd ();
      astr_cat_char (as, '/');
      astr_cat_cstr (as, filename);
      set_buffer_filename (bp, astr_cstr (as));
      filename = astr_cstr (as);
    }
  else
    set_buffer_filename (bp, filename);

  free ((char *) get_buffer_name (bp));
  set_buffer_name (bp, make_buffer_name (filename));
  if (as)
    astr_delete (as);
}

/*
 * Search for a buffer named `name'.
 */
int
find_buffer (const char *name)
{
  int bp;

  for (bp = head_bp (); bp != LUA_REFNIL; bp = get_buffer_next (bp))
    {
      const char *bname = get_buffer_name (bp);
      if (bname && !strcmp (bname, name))
        return bp;
    }

  return LUA_REFNIL;
}

/*
 * Print an error message into the echo area and return true
 * if the current buffer is readonly; otherwise return false.
 */
int
warn_if_readonly_buffer (void)
{
  if (get_buffer_readonly (cur_bp ()))
    {
      minibuf_error ("Buffer is readonly: %s", get_buffer_name (cur_bp ()));
      return true;
    }

  return false;
}

static int
warn_if_no_mark (void)
{
  if (get_buffer_mark (cur_bp ()) == LUA_REFNIL)
    {
      minibuf_error ("The mark is not set now");
      return true;
    }
  else if (!get_buffer_mark_active (cur_bp ()) && get_variable_bool ("transient-mark-mode"))
    {
      minibuf_error ("The mark is not active now");
      return true;
    }
  else
    return false;
}

int
region_new (void)
{
  lua_newtable (L);
  return luaL_ref (L, LUA_REGISTRYINDEX);
}

/*
 * Calculate the region size between point and mark and set the
 * region.
 */
int
calculate_the_region (int rp)
{
  if (warn_if_no_mark ())
    return false;

  if (cmp_point (get_buffer_pt (cur_bp ()), get_marker_pt (get_buffer_mark (cur_bp ()))) < 0)
    {
      /* Point is before mark. */
      set_region_start (rp, point_copy (get_buffer_pt (cur_bp ())));
      set_region_finish (rp, point_copy (get_marker_pt (get_buffer_mark (cur_bp ()))));
    }
  else
    {
      /* Mark is before point. */
      set_region_start (rp, point_copy (get_marker_pt (get_buffer_mark (cur_bp ()))));
      set_region_finish (rp, point_copy (get_buffer_pt (cur_bp ())));
    }

  {
    int pt1 = get_region_start (rp), pt2 = get_region_finish (rp);
    int size = -get_point_o (pt1) + get_point_o (pt2), lp;

    for (lp = get_point_p (pt1); !lua_refeq (L, lp, get_point_p (pt2)); lp = get_line_next (lp))
      size += strlen (get_line_text (lp)) + 1;

    set_region_size (rp, size);
  }

  return true;
}

bool
delete_region (int rp)
{
  size_t size = get_region_size (rp);
  int m = point_marker ();

  if (warn_if_readonly_buffer ())
    return false;

  goto_point (get_region_start (rp));
  undo_save (UNDO_REPLACE_BLOCK, get_region_start (rp), size, 0);
  set_undo_nosave (true);
  while (size--)
    delete_char ();
  set_undo_nosave (false);
  set_buffer_pt (cur_bp (), point_copy (get_marker_pt (m)));
  free_marker (m);

  return true;
}

size_t
calculate_buffer_size (int bp)
{
  int lp = get_line_next (get_buffer_lines (bp));
  size_t size = 0;

  if (lua_refeq (L, lp, get_buffer_lines (bp)))
    return 0;

  for (;;)
    {
      size += strlen (get_line_text (lp));
      lp = get_line_next (lp);
      if (lua_refeq (L, lp, get_buffer_lines (bp)))
        break;
      ++size;
    }

  return size;
}

void
activate_mark (void)
{
  set_buffer_mark_active (cur_bp (), true);
}

void
deactivate_mark (void)
{
  set_buffer_mark_active (cur_bp (), false);
}

/*
 * Return a safe tab width for the given buffer.
 */
size_t
tab_width (int bp)
{
  return MAX (get_variable_number_bp (bp, "tab-width"), 1);
}

/*
 * Copy a region of text into an allocated buffer.
 */
astr
copy_text_block (int pt, size_t size)
{
  int lp = get_point_p (pt);
  astr as = astr_new_cstr (get_line_text (get_point_p (pt)));

  as = astr_substr (as, get_point_o (pt), strlen (get_line_text (lp)) - get_point_o (pt));

  astr_cat_char (as, '\n');
  for (lp = get_line_next (lp); astr_len (as) < size; lp = get_line_next (lp))
    {
      astr_cat_cstr (as, get_line_text (lp));
      astr_cat_char (as, '\n');
    }
  astr_truncate (as, size);

  return as;
}

int
create_scratch_buffer (void)
{
  int bp = buffer_new ();
  set_buffer_name (bp, "*scratch*");
  set_buffer_needname (bp, true);
  set_buffer_temporary (bp, true);
  set_buffer_nosave (bp, true);
  return bp;
}

DEFUN_ARGS ("kill-buffer", kill_buffer,
            STR_ARG (buffer))
/*+
Kill buffer BUFFER.
With a nil argument, kill the current buffer.
+*/
{
  int bp;

  STR_INIT (buffer)
  else
    {
      int cp = make_buffer_completion ();
      buffer = minibuf_read_completion (astr_cstr (astr_afmt (astr_new (), "Kill buffer (default %s): ",
                                                              get_buffer_name (cur_bp ()))), "", cp, LUA_REFNIL);
      if (buffer == NULL)
        ok = FUNCALL (keyboard_quit);
    }

  if (buffer && buffer[0] != '\0')
    {
      bp = find_buffer (buffer);
      if (bp == LUA_REFNIL)
        {
          minibuf_error ("Buffer `%s' not found", buffer);
          free ((char *) buffer);
          ok = leNIL;
        }
    }
  else
    bp = cur_bp ();

  if (ok == leT)
    {
      if (!check_modified_buffer (bp))
        ok = leNIL;
      else
        {
          lua_rawgeti (L, LUA_REGISTRYINDEX, bp);
          lua_setglobal (L, "bp");
          CLUE_DO (L, "kill_buffer (bp)");
        }
    }

  STR_FREE (buffer);
}
END_DEFUN

/*
 * Check if the buffer has been modified.  If so, asks the user if
 * he/she wants to save the changes.  If the response is positive, return
 * true, else false.
 */
bool
check_modified_buffer (int bp)
{
  if (get_buffer_modified (bp) && !get_buffer_nosave (bp))
    for (;;)
      {
        int ans = minibuf_read_yesno
          (astr_cstr (astr_afmt (astr_new (), "Buffer %s modified; kill anyway? (yes or no) ", get_buffer_name (bp))));
        if (ans == -1)
          {
            FUNCALL (keyboard_quit);
            return false;
          }
        else if (!ans)
          return false;
        break;
      }

  return true;
}
