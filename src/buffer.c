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

/*
 * Allocate a new buffer, set the default local variable values, and
 * insert it into the buffer list.
 * The allocation of the first empty line is done here to simplify
 * the code.
 */
int
buffer_new (void)
{
  int bp;

  lua_newtable (L);
  bp = luaL_ref (L, LUA_REGISTRYINDEX);

  /* Allocate point. */
  set_buffer_pt (bp, point_new ());

  /* Allocate a line. */
  (void) CLUE_DO (L, "l = line_new ()");
  lua_getglobal (L, "l");
  set_point_p (get_buffer_pt (bp), luaL_ref (L, LUA_REGISTRYINDEX));
  set_line_text (get_point_p (get_buffer_pt (bp)), astr_new ());

  /* Allocate the limit marker. */
  (void) CLUE_DO (L, "l = line_new ()");
  lua_getglobal (L, "l");
  set_buffer_lines (bp, luaL_ref (L, LUA_REGISTRYINDEX));

  set_line_prev (get_buffer_lines (bp), get_point_p (get_buffer_pt (bp)));
  set_line_next (get_buffer_lines (bp), get_point_p (get_buffer_pt (bp)));
  set_line_prev (get_point_p (get_buffer_pt (bp)), get_buffer_lines (bp));
  set_line_next (get_point_p (get_buffer_pt (bp)), get_buffer_lines (bp));

  /* Set default EOL string. */
  set_buffer_eol (bp, coding_eol_lf);

  /* Insert into buffer list. */
  set_buffer_next (bp, head_bp);
  head_bp = bp;

  init_buffer (bp);

  return bp;
}

/*
 * Free the buffer's allocated memory.
 */
void
free_buffer (int bp)
{
  free_undo (get_buffer_last_undop (bp));

  while (get_buffer_markers (bp))
    free_marker (get_buffer_markers (bp));

  free ((char *) get_buffer_name (bp));
  free ((char *) get_buffer_filename (bp));
  luaL_unref (L, LUA_REGISTRYINDEX, bp);
}

/*
 * Initialise a buffer
 */
void
init_buffer (int bp)
{
  if (get_variable_bool ("auto-fill-mode"))
    set_buffer_autofill (bp, true);
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

  for (bp = head_bp; bp != LUA_REFNIL; bp = get_buffer_next (bp))
    {
      const char *bname = get_buffer_name (bp);
      if (bname && !strcmp (bname, name))
        return bp;
    }

  return LUA_REFNIL;
}

/* Move the selected buffer to head.  */

static void
move_buffer_to_head (int bp)
{
  int it, prev = LUA_REFNIL;

  for (it = head_bp; it; prev = it, it = get_buffer_next (it))
    {
      if (lua_refeq (L, bp, it))
        {
          if (prev != LUA_REFNIL)
            {
              set_buffer_next (prev, get_buffer_next (bp));
              set_buffer_next (bp, head_bp);
              head_bp = bp;
            }
          break;
        }
    }
}

/*
 * Switch to the specified buffer.
 */
void
switch_to_buffer (int bp)
{
  assert (lua_refeq (L, get_window_bp (cur_wp), cur_bp));

  /* The buffer is the current buffer; return safely.  */
  if (cur_bp == bp)
    return;

  /* Set current buffer.  */
  cur_bp = bp;
  set_window_bp (cur_wp, cur_bp);

  /* Move the buffer to head.  */
  move_buffer_to_head (bp);

  thisflag |= FLAG_NEED_RESYNC;
}

/*
 * Print an error message into the echo area and return true
 * if the current buffer is readonly; otherwise return false.
 */
int
warn_if_readonly_buffer (void)
{
  if (get_buffer_readonly (cur_bp))
    {
      minibuf_error ("Buffer is readonly: %s", get_buffer_name (cur_bp));
      return true;
    }

  return false;
}

static int
warn_if_no_mark (void)
{
  if (get_buffer_mark (cur_bp) == LUA_REFNIL)
    {
      minibuf_error ("The mark is not set now");
      return true;
    }
  else if (!get_buffer_mark_active (cur_bp) && transient_mark_mode ())
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

  if (cmp_point (get_buffer_pt (cur_bp), get_marker_pt (get_buffer_mark (cur_bp))) < 0)
    {
      /* Point is before mark. */
      set_region_start (rp, point_copy (get_buffer_pt (cur_bp)));
      set_region_end (rp, point_copy (get_marker_pt (get_buffer_mark (cur_bp))));
    }
  else
    {
      /* Mark is before point. */
      set_region_start (rp, point_copy (get_marker_pt (get_buffer_mark (cur_bp))));
      set_region_end (rp, point_copy (get_buffer_pt (cur_bp)));
    }

  {
    int pt1 = get_region_start (rp), pt2 = get_region_end (rp);
    int size = -get_point_o (pt1) + get_point_o (pt2), lp;

    for (lp = get_point_p (pt1); !lua_refeq (L, lp, get_point_p (pt2)); lp = get_line_next (lp))
      size += astr_len (get_line_text (lp)) + 1;

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
  undo_nosave = true;
  while (size--)
    delete_char ();
  undo_nosave = false;
  set_buffer_pt (cur_bp, point_copy (get_marker_pt (m)));
  free_marker (m);

  return true;
}

bool
in_region (size_t lineno, size_t x, int rp)
{
  if (lineno >= get_point_n (get_region_start (rp)) && lineno <= get_point_n (get_region_end (rp)))
    {
      if (get_point_n (get_region_start (rp)) == get_point_n (get_region_end (rp)))
        {
          if (x >= get_point_o (get_region_start (rp)) && x < get_point_o (get_region_end (rp)))
            return true;
        }
      else if (lineno == get_point_n (get_region_start (rp)))
        {
          if (x >= get_point_o (get_region_start (rp)))
            return true;
        }
      else if (lineno == get_point_n (get_region_end (rp)))
        {
          if (x < get_point_o (get_region_end (rp)))
            return true;
        }
      else
        return true;
    }

  return false;
}

/*
 * Set the specified buffer temporary flag and move the buffer
 * to the end of the buffer list.
 */
void
set_temporary_buffer (int bp)
{
  int bp0;

  set_buffer_temporary (bp, true);

  if (bp == head_bp)
    {
      if (get_buffer_next (head_bp) == LUA_REFNIL)
        return;
      head_bp = get_buffer_next (head_bp);
    }
  else if (get_buffer_next (bp) == LUA_REFNIL)
    return;

  for (bp0 = head_bp; bp0 != LUA_REFNIL; bp0 = get_buffer_next (bp0))
    if (lua_refeq (L, get_buffer_next (bp0), bp))
      {
        set_buffer_next (bp0, get_buffer_next (get_buffer_next (bp0)));
        break;
      }

  for (bp0 = head_bp; get_buffer_next (bp0) != LUA_REFNIL; bp0 = get_buffer_next (bp0))
    ;

  set_buffer_next (bp0, bp);
  set_buffer_next (bp, LUA_REFNIL);
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
      size += astr_len (get_line_text (lp));
      lp = get_line_next (lp);
      if (lua_refeq (L, lp, get_buffer_lines (bp)))
        break;
      ++size;
    }

  return size;
}

int
transient_mark_mode (void)
{
  return get_variable_bool ("transient-mark-mode");
}

void
activate_mark (void)
{
  set_buffer_mark_active (cur_bp, true);
}

void
deactivate_mark (void)
{
  set_buffer_mark_active (cur_bp, false);
}

/*
 * Return a safe tab width for the given buffer.
 */
size_t
tab_width (int bp)
{
  size_t t = get_variable_number_bp (bp, "tab-width");

  return t ? t : 1;
}

/*
 * Copy a region of text into an allocated buffer.
 */
astr
copy_text_block (int pt, size_t size)
{
  int lp = get_point_p (pt);
  astr as = astr_substr (get_line_text (get_point_p (pt)), get_point_o (pt), astr_len (get_line_text (get_point_p (pt))) - get_point_o (pt));

  astr_cat_char (as, '\n');
  for (lp = get_line_next (lp); astr_len (as) < size; lp = get_line_next (lp))
    {
      astr_cat (as, get_line_text (lp));
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

/*
 * Remove the specified buffer from the buffer list and deallocate
 * its space.  Recreate the scratch buffer when required.
 */
void
kill_buffer (int kill_bp)
{
  int next_bp, wp, bp;

  if (get_buffer_next (kill_bp) != LUA_REFNIL)
    next_bp = get_buffer_next (kill_bp);
  else
    next_bp = (head_bp == kill_bp) ? LUA_REFNIL : head_bp;

  /* Search for windows displaying the buffer to kill. */
  for (wp = head_wp; wp != LUA_REFNIL; wp = get_window_next (wp))
    if (get_window_bp (wp) == kill_bp)
      {
        set_window_bp (wp, next_bp);
        set_window_topdelta (wp, 0);
        set_window_saved_pt (wp, LUA_REFNIL); /* The old marker will be freed. */
      }

  /* Remove the buffer from the buffer list. */
  if (cur_bp == kill_bp)
    cur_bp = next_bp;
  if (head_bp == kill_bp)
    head_bp = get_buffer_next (head_bp);
  for (bp = head_bp; bp != LUA_REFNIL && get_buffer_next (bp) != LUA_REFNIL; bp = get_buffer_next (bp))
    if (get_buffer_next (bp) == kill_bp)
      {
        set_buffer_next (bp, get_buffer_next (get_buffer_next (bp)));
        break;
      }

  free_buffer (kill_bp);

  /* If no buffers left, recreate scratch buffer and point windows at
     it. */
  if (next_bp == LUA_REFNIL)
    {
      cur_bp = head_bp = next_bp = create_scratch_buffer ();
      for (wp = head_wp; wp != LUA_REFNIL; wp = get_window_next (wp))
        set_window_bp (wp, head_bp);
    }

  /* Resync windows that need it. */
  for (wp = head_wp; wp != LUA_REFNIL; wp = get_window_next (wp))
    if (get_window_bp (wp) == next_bp)
      resync_redisplay (wp);
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
      buffer = minibuf_read_completion ("Kill buffer (default %s): ",
                                        "", cp, LUA_NOREF, get_buffer_name (cur_bp));
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
    bp = cur_bp;

  if (ok == leT)
    {
      if (!check_modified_buffer (bp))
        ok = leNIL;
      else
        kill_buffer (bp);
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
          ("Buffer %s modified; kill anyway? (yes or no) ", get_buffer_name (bp));
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
