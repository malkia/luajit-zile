/* Line-oriented editing functions

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.

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
#include <ctype.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"


/*
 * Structure
 */
#define FIELD(cty, lty, field)                  \
  LUA_GETTER (line, cty, lty, field)            \
  LUA_SETTER (line, cty, lty, field)
#define TABLE_FIELD(field)                     \
  LUA_TABLE_GETTER (line, field)               \
  LUA_TABLE_SETTER (line, field)

#include "line.h"
#undef FIELD
#undef TABLE_FIELD

/*
 * Adjust markers (including point) when line at point is split, or
 * next line is joined on, or where a line is edited.
 *   newlp is the line to which characters were moved, oldlp the line
 *    moved from (if dir == 0, newlp == oldlp)
 *   pointo is point at which oldlp was split (to make newlp) or
 *     joined to newlp
 *   dir is 1 for split, -1 for join or 0 for line edit (newlp == oldlp)
 *   if dir == 0, delta gives the number of characters inserted (>0) or
 *     deleted (<0)
 */
static void
adjust_markers (int newlp, int oldlp, size_t pointo, int dir, ptrdiff_t delta)
{
  int m_pt = point_marker (), m;

  assert (dir >= -1 && dir <= 1);

  for (m = get_buffer_markers (cur_bp ()); m != LUA_REFNIL; m = get_marker_next (m))
    {
      int pt = get_marker_pt (m);

      if (lua_refeq (L, get_point_p (pt), oldlp) && (dir == -1 || get_point_o (pt) > pointo))
        {
          set_point_p (pt, newlp);
          set_point_o (pt, get_point_o (pt) + delta - (pointo * dir));
          set_point_n (pt, get_point_n (pt) + dir);
        }
      else if (get_point_n (pt) > get_point_n (get_buffer_pt (cur_bp ())))
        set_point_n (pt, get_point_n (pt) + dir);
    }

  /* This marker has been updated to new position. */
  set_buffer_pt (cur_bp (), point_copy (get_marker_pt (m_pt)));
  free_marker (m_pt);
}

/*
 * Insert a character at the current position in insert mode
 * whatever the current insert mode is.
 */
int
insert_char_in_insert_mode (int c)
{
  int ret;
  CLUE_SET (L, c, integer, c);
  CLUE_DO (L, "ret = insert_char_in_insert_mode (string.char (c))");
  CLUE_GET (L, ret, integer, ret);
  return ret;
}

DEFUN ("tab-to-tab-stop", tab_to_tab_stop)
/*+
Insert a tabulation at the current point position into the current
buffer.
+*/
{
  CLUE_DO (L, "ok = execute_with_uniarg (true, uniarg, insert_tab)");
  lua_getglobal (L, "ok");
  ok = luaL_ref (L, LUA_REGISTRYINDEX);
}
END_DEFUN

/*
 * Check the case of a string.
 * Returns 2 if it is all upper case, 1 if just the first letter is,
 * and 0 otherwise.
 */
static int
check_case (const char *s, size_t len)
{
  size_t i;

  if (!isupper ((int) *s))
    return 0;

  for (i = 1; i < len; i++)
    if (!isupper ((int) s[i]))
      return 1;

  return 2;
}

/*
 * Replace text in the line "lp" with "newtext". If "replace_case" is
 * true then the new characters will be the same case as the old.
 */
void
line_replace_text (int lp, size_t offset, size_t oldlen,
                   char *newtext, int replace_case)
{
  int case_type = 0;
  size_t newlen = strlen (newtext);
  astr as, bs;

  replace_case = replace_case && get_variable_bool ("case-replace");

  if (replace_case)
    {
      case_type = check_case (get_line_text (lp) + offset, oldlen);

      if (case_type != 0)
        {
          as = astr_new_cstr (newtext);
          astr_recase (as, case_type == 1 ? case_capitalized : case_upper);
        }
    }

  set_buffer_modified (cur_bp (), true);
  bs = astr_new_cstr (get_line_text (lp));
  astr_replace_cstr (bs, offset, oldlen, newtext);
  set_line_text (lp, xstrdup (astr_cstr (bs)));
  astr_delete (bs);
  adjust_markers (lp, lp, offset, 0, (ptrdiff_t) (newlen - oldlen));

  if (case_type != 0)
    astr_delete (as);
}

/*
 * If point is greater than fill-column, then split the line at the
 * right-most space character at or before fill-column, if there is
 * one, or at the left-most at or after fill-column, if not. If the
 * line contains no spaces, no break is made.
 *
 * Return flag indicating whether break was made.
 */
bool
fill_break_line (void)
{
  size_t i, break_col = 0, old_col;
  size_t fillcol = get_variable_number ("fill-column");
  bool break_made = false;

  /* Only break if we're beyond fill-column. */
  if (get_goalc () > fillcol)
    {
      /* Save point. */
      int m = point_marker ();

      /* Move cursor back to fill column */
      old_col = get_point_o (get_buffer_pt (cur_bp ()));
      while (get_goalc () > fillcol + 1)
        {
          int pt = get_buffer_pt (cur_bp ());
          set_point_o (pt, get_point_o (pt) - 1);
        }

      /* Find break point moving left from fill-column. */
      for (i = get_point_o (get_buffer_pt (cur_bp ())); i > 0; i--)
        {
          int c = get_line_text (get_point_p (get_buffer_pt (cur_bp ())))[i - 1];
          if (isspace (c))
            {
              break_col = i;
              break;
            }
        }

      /* If no break point moving left from fill-column, find first
         possible moving right. */
      if (break_col == 0)
        {
          for (i = get_point_o (get_buffer_pt (cur_bp ())) + 1;
               i < strlen (get_line_text (get_point_p (get_buffer_pt (cur_bp ()))));
               i++)
            {
              int c = get_line_text (get_point_p (get_buffer_pt (cur_bp ())))[i - 1];
              if (isspace (c))
                {
                  break_col = i;
                  break;
                }
            }
        }

      if (break_col >= 1) /* Break line. */
        {
          int pt = get_buffer_pt (cur_bp ());
          set_point_o (pt, break_col);
          FUNCALL (delete_horizontal_space);
          CLUE_DO (L, "insert_newline ()");
          set_buffer_pt (cur_bp (), point_copy (get_marker_pt (m)));
          break_made = true;
        }
      else /* Undo fiddling with point. */
        {
          int pt = get_buffer_pt (cur_bp ());
          set_point_o (pt, old_col);
        }

      free_marker (m);
    }

  return break_made;
}

static bool
newline (void)
{
  bool ret;
  if (get_buffer_autofill (cur_bp ()) &&
      get_goalc () > (size_t) get_variable_number ("fill-column"))
    fill_break_line ();
  CLUE_DO (L, "ret = insert_newline ()");
  CLUE_GET (L, ret, boolean, ret);
  return ret;
}

DEFUN ("newline", newline)
/*+
Insert a newline at the current point position into
the current buffer.
+*/
{
  ok = execute_with_uniarg (true, uniarg, newline, NULL);
}
END_DEFUN

DEFUN ("open-line", open_line)
/*+
Insert a newline and leave point before it.
+*/
{
  CLUE_SET (L, uniarg, integer, uniarg);
  CLUE_DO (L, "ok = execute_with_uniarg (true, uniarg, intercalate_newline)");
  lua_getglobal (L, "ok");
  ok = luaL_ref (L, LUA_REGISTRYINDEX);
}
END_DEFUN

void
insert_nstring (const char *s, size_t len)
{
  size_t i;
  undo_save (UNDO_REPLACE_BLOCK, get_buffer_pt (cur_bp ()), 0, len);
  set_undo_nosave (true);
  for (i = 0; i < len; i++)
    {
      if (s[i] == '\n')
        CLUE_DO (L, "insert_newline ()");
      else
        insert_char_in_insert_mode (s[i]);
    }
  set_undo_nosave (false);
}

DEFUN_NONINTERACTIVE_ARGS ("insert", insert,
                           STR_ARG (arg))
/*+
Insert the argument at point.
+*/
{
  STR_INIT (arg);
  insert_nstring (arg, strlen (arg));
  STR_FREE (arg);
}
END_DEFUN

void
insert_astr (astr as)
{
  insert_nstring (astr_cstr (as), astr_len (as));
}

void
bprintf (const char *fmt, ...)
{
  va_list ap;
  char *buf;

  va_start (ap, fmt);
  xvasprintf (&buf, fmt, ap);
  va_end (ap);
  insert_nstring (buf, strlen (buf));
  free (buf);
}

bool
delete_char (void)
{
  deactivate_mark ();

  if (eobp ())
    {
      minibuf_error ("End of buffer");
      return false;
    }

  if (warn_if_readonly_buffer ())
    return false;

  undo_save (UNDO_REPLACE_BLOCK, get_buffer_pt (cur_bp ()), 1, 0);

  if (eolp ())
    {
      size_t oldlen = strlen (get_line_text (get_point_p (get_buffer_pt (cur_bp ()))));
      int oldlp = get_line_next (get_point_p (get_buffer_pt (cur_bp ())));
      astr as, bs;

      /* Join the lines. */
      as = astr_new_cstr (get_line_text (get_point_p (get_buffer_pt (cur_bp ()))));
      bs = astr_new_cstr (get_line_text (oldlp));
      astr_cat (as, bs);
      set_line_text (get_point_p (get_buffer_pt (cur_bp ())), xstrdup (astr_cstr (as)));
      astr_delete (as);
      astr_delete (bs);
      lua_rawgeti (L, LUA_REGISTRYINDEX, oldlp);
      lua_setglobal (L, "l");
      CLUE_DO (L, "line_remove (l)");

      adjust_markers (get_point_p (get_buffer_pt (cur_bp ())), oldlp, oldlen, -1, 0);
      set_buffer_last_line (cur_bp (), get_buffer_last_line (cur_bp ()) - 1);
      set_thisflag (thisflag () | FLAG_NEED_RESYNC);
    }
  else
    {
      astr as = astr_new_cstr (get_line_text (get_point_p (get_buffer_pt (cur_bp ()))));
      astr_remove (as, get_point_o (get_buffer_pt (cur_bp ())), 1);
      set_line_text ((get_point_p (get_buffer_pt (cur_bp ()))), xstrdup (astr_cstr (as)));
      astr_delete (as);
      adjust_markers (get_point_p (get_buffer_pt (cur_bp ())), get_point_p (get_buffer_pt (cur_bp ())), get_point_o (get_buffer_pt (cur_bp ())), 0, -1);
    }

  set_buffer_modified (cur_bp (), true);

  return true;
}

DEFUN_ARGS ("delete-char", delete_char,
            INT_OR_UNIARG (n))
/*+
Delete the following @i{n} characters (previous if @i{n} is negative).
+*/
{
  INT_OR_UNIARG_INIT (n);
  CLUE_SET (L, n, integer, n);
  {
    bool ret;
    CLUE_DO (L, "ret = execute_with_uniarg (true, n, delete_char, backward_delete_char)");
    CLUE_GET (L, ret, boolean, ret);
    ok = bool_to_lisp (ret);
  }
}
END_DEFUN

DEFUN_ARGS ("backward-delete-char", backward_delete_char,
            INT_OR_UNIARG (n))
/*+
Delete the previous @i{n} characters (following if @i{n} is negative).
+*/
{
  INT_OR_UNIARG_INIT (n);
  CLUE_SET (L, n, integer, n);
  {
    bool ret;
    CLUE_DO (L, "ret = execute_with_uniarg (true, n, cur_bp.overwrite and backward_delete_char_overwrite or backward_delete_char, delete_char)");
    CLUE_GET (L, ret, boolean, ret);
    ok = bool_to_lisp (ret);
  }
}
END_DEFUN

DEFUN ("delete-horizontal-space", delete_horizontal_space)
/*+
Delete all spaces and tabs around point.
+*/
{
  undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);

  while (!eolp () && isspace (following_char ()))
    delete_char ();

  while (!bolp () && isspace (preceding_char ()))
    CLUE_DO (L, "backward_delete_char ()");

  undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
}
END_DEFUN

DEFUN ("just-one-space", just_one_space)
/*+
Delete all spaces and tabs around point, leaving one space.
+*/
{
  undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
  FUNCALL (delete_horizontal_space);
  insert_char_in_insert_mode (' ');
  undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
}
END_DEFUN

/***********************************************************************
                         Indentation command
***********************************************************************/
/*
 * Go to cur_goalc () in the previous non-blank line.
 */
static void
previous_nonblank_goalc (void)
{
  size_t cur_goalc = get_goalc ();

  /* Find previous non-blank line. */
  while (FUNCALL_ARG (forward_line, -1) == leT && is_blank_line ());

  /* Go to `cur_goalc' in that non-blank line. */
  while (!eolp () && get_goalc () < cur_goalc)
    forward_char ();
}

DEFUN ("indent-relative", indent_relative)
/*+
Space out to under next indent point in previous nonblank line.
An indent point is a non-whitespace character following whitespace.
The following line shows the indentation points in this line.
    ^         ^    ^     ^   ^           ^      ^  ^    ^
If the previous nonblank line has no indent points beyond the
column point starts at, `tab-to-tab-stop' is done instead, unless
this command is invoked with a numeric argument, in which case it
does nothing.
+*/
{
  size_t target_goalc = 0, cur_goalc = get_goalc ();
  size_t t = tab_width (cur_bp ());

  ok = leNIL;

  if (warn_if_readonly_buffer ())
    return leNIL;

  deactivate_mark ();

  /* If we're on first line, set target to 0. */
  if (lua_refeq (L, get_line_prev (get_point_p (get_buffer_pt (cur_bp ()))), get_buffer_lines (cur_bp ())))
    target_goalc = 0;
  else
    { /* Find goalc in previous non-blank line. */
      int m = point_marker ();

      previous_nonblank_goalc ();

      /* Now find the next blank char. */
      if (!(preceding_char () == '\t' && get_goalc () > cur_goalc))
        while (!eolp () && (!isspace (following_char ())))
          forward_char ();

      /* Find next non-blank char. */
      while (!eolp () && (isspace (following_char ())))
        forward_char ();

      /* Target column. */
      if (!eolp ())
        target_goalc = get_goalc ();

      set_buffer_pt (cur_bp (), point_copy (get_marker_pt (m)));
      free_marker (m);
    }

  /* Insert indentation.  */
  undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
  if (target_goalc > 0)
    {
      /* If not at EOL on target line, insert spaces & tabs up to
         target_goalc; if already at EOL on target line, insert a tab.
       */
      cur_goalc = get_goalc ();
      if (cur_goalc < target_goalc)
        {
          do
            {
              if (cur_goalc % t == 0 && cur_goalc + t <= target_goalc)
                {
                  bool ret;
                  CLUE_DO (L, "ret = insert_tab ()");
                  CLUE_GET (L, ret, boolean, ret);
                  ok = bool_to_lisp (ret);
                }
              else
                ok = bool_to_lisp (insert_char_in_insert_mode (' '));
            }
          while (ok == leT && (cur_goalc = get_goalc ()) < target_goalc);
        }
      else
        {
          bool ret;
          CLUE_DO (L, "ret = insert_tab ()");
          CLUE_GET (L, ret, boolean, ret);
          ok = bool_to_lisp (ret);
        }
    }
  else
    {
      bool ret;
      CLUE_DO (L, "ret = insert_tab ()");
      CLUE_GET (L, ret, boolean, ret);
      ok = bool_to_lisp (ret);
    }
  undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
}
END_DEFUN

static size_t
previous_line_indent (void)
{
  size_t cur_indent;
  int m = point_marker ();

  FUNCALL (previous_line);
  FUNCALL (beginning_of_line);

  /* Find first non-blank char. */
  while (!eolp () && (isspace (following_char ())))
    forward_char ();

  cur_indent = get_goalc ();

  /* Restore point. */
  set_buffer_pt (cur_bp (), point_copy (get_marker_pt (m)));
  free_marker (m);

  return cur_indent;
}

DEFUN ("indent-for-tab-command", indent_for_tab_command)
/*+
Indent line or insert a tab.
Depending on `tab-always-indent', either insert a tab or indent.
If initial point was within line's indentation, position after
the indentation.  Else stay at same point in text.
+*/
{
  if (get_variable_bool ("tab-always-indent"))
    {
      bool ret;
      CLUE_DO (L, "ret = insert_tab ()");
      CLUE_GET (L, ret, boolean, ret);
      return bool_to_lisp (ret);
    }
  else if (get_goalc () < previous_line_indent ())
    return FUNCALL (indent_relative);
}
END_DEFUN

DEFUN ("newline-and-indent", newline_and_indent)
/*+
Insert a newline, then indent.
Indentation is done using the `indent-for-tab-command' function.
+*/
{
  bool ret;

  ok = leNIL;

  if (warn_if_readonly_buffer ())
    return leNIL;

  deactivate_mark ();

  undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
  CLUE_DO (L, "ret = insert_newline ()");
  CLUE_GET (L, ret, boolean, ret);
  if (ret)
    {
      int m = point_marker (), indent;
      size_t pos;

      /* Check where last non-blank goalc is. */
      previous_nonblank_goalc ();
      pos = get_goalc ();
      indent = pos > 0 || (!eolp () && isspace (following_char ()));
      set_buffer_pt (cur_bp (), point_copy (get_marker_pt (m)));
      free_marker (m);
      /* Only indent if we're in column > 0 or we're in column 0 and
         there is a space character there in the last non-blank line. */
      if (indent)
        FUNCALL (indent_for_tab_command);
      ok = leT;
    }
  undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
}
END_DEFUN
