/* Kill ring facility functions

   Copyright (c) 2001, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010 Free Software Foundation, Inc.

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
#include <stdlib.h>
#include <string.h>

#include "main.h"
#include "extern.h"

static astr kill_ring_text;

void
free_kill_ring (void)
{
  if (kill_ring_text != NULL)
    astr_delete (kill_ring_text);
  kill_ring_text = NULL;
}

static void
kill_ring_push (astr as)
{
  if (kill_ring_text == NULL)
    kill_ring_text = astr_new ();
  astr_cpy (kill_ring_text, as);
}

static bool
copy_or_kill_region (bool kill, int rp)
{
  astr as = copy_text_block (get_region_start (rp), get_region_size (rp));

  if (strcmp (last_command (), "kill-region") != 0)
    free_kill_ring ();
  kill_ring_push (as);
  astr_delete (as);

  if (kill)
    {
      if (get_buffer_readonly (cur_bp ()))
        minibuf_error ("Read only text copied to kill ring");
      else
        assert (delete_region (rp));
    }

  set_this_command ("kill-region");
  CLUE_DO (L, "deactivate_mark ()");

  return true;
}

static bool
kill_to_bol (void)
{
  bool ok = true;

  if (!bolp ())
    {
      int rp = region_new ();
      int pt = get_buffer_pt (cur_bp ());

      set_region_size (rp, get_point_o (pt));
      set_point_o (pt, 0);
      set_region_start (rp, pt);

      ok = copy_or_kill_region (true, rp);
      luaL_unref (L, LUA_REGISTRYINDEX, rp);
    }

  return ok;
}

static bool
kill_line (bool whole_line)
{
  bool ok = true;
  bool only_blanks_to_end_of_line = false;

  if (!whole_line)
    {
      int cur_pt = get_buffer_pt (cur_bp ());
      const char *cur_line = get_line_text (get_point_p (cur_pt));
      size_t i;

      for (i = get_point_o (cur_pt); i < strlen (cur_line); i++)
        {
          char c = cur_line[i];
          if (!(c == ' ' || c == '\t'))
            break;
        }

      if (i == strlen (cur_line))
        only_blanks_to_end_of_line = true;
    }

  if (eobp ())
    {
      minibuf_error ("End of buffer");
      return false;
    }

  undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);

  if (!eolp ())
    {
      int rp = region_new ();

      set_region_start (rp, get_buffer_pt (cur_bp ()));
      set_region_size (rp, strlen (get_line_text (get_point_p (get_buffer_pt (cur_bp ())))) - get_point_o (get_buffer_pt (cur_bp ())));

      ok = copy_or_kill_region (true, rp);
      luaL_unref (L, LUA_REGISTRYINDEX, rp);
    }

  if (ok && (whole_line || only_blanks_to_end_of_line) && !eobp ())
    {
      astr as;

      if (!FUNCALL (delete_char))
        return false;

      as = astr_new_cstr ("\n");
      kill_ring_push (as);
      astr_delete (as);
      set_this_command ("kill-region");
    }

  undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);

  return ok;
}

static bool
kill_whole_line (void)
{
  return kill_line (true);
}

static bool
kill_line_backward (void)
{
  return previous_line () && kill_whole_line ();
}

DEFUN_ARGS ("kill-line", kill_line,
            INT_OR_UNIARG (arg))
/*+
Kill the rest of the current line; if no nonblanks there, kill thru newline.
With prefix argument @i{arg}, kill that many lines from point.
Negative arguments kill lines backward.
With zero argument, kills the text before point on the current line.

If `kill-whole-line' is non-nil, then this command kills the whole line
including its terminating newline, when used at the beginning of a line
with no argument.
+*/
{
  if (strcmp (last_command (), "kill-region") != 0)
    free_kill_ring ();

  INT_OR_UNIARG_INIT (arg);

  if (noarg)
    ok = bool_to_lisp (kill_line (bolp () && get_variable_bool ("kill-whole-line")));
  else
    {
      undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
      if (arg <= 0)
        ok = bool_to_lisp (kill_to_bol ());
      if (arg != 0 && ok == leT)
        ok = execute_with_uniarg (true, arg, kill_whole_line, kill_line_backward);
      undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
    }

  CLUE_DO (L, "deactivate_mark ()");
}
END_DEFUN

static bool
copy_or_kill_the_region (bool kill)
{
  int rp = region_new ();
  bool ok = false;

  if (calculate_the_region (rp))
    ok = copy_or_kill_region (kill, rp);

  luaL_unref (L, LUA_REGISTRYINDEX, rp);
  return ok;
}

DEFUN ("kill-region", kill_region)
/*+
Kill between point and mark.
The text is deleted but saved in the kill ring.
The command @kbd{C-y} (yank) can retrieve it from there.
If the buffer is read-only, Zile will beep and refrain from deleting
the text, but put the text in the kill ring anyway.  This means that
you can use the killing commands to copy text from a read-only buffer.
If the previous command was also a kill command,
the text killed this time appends to the text killed last time
to make one entry in the kill ring.
+*/
{
  ok = bool_to_lisp (copy_or_kill_the_region (true));
}
END_DEFUN

DEFUN ("copy-region-as-kill", copy_region_as_kill)
/*+
Save the region as if killed, but don't kill it.
+*/
{
  ok = bool_to_lisp (copy_or_kill_the_region (false));
}
END_DEFUN

static le
kill_text (int uniarg, const char * mark_func)
{
  if (strcmp (last_command (), "kill-region") != 0)
    free_kill_ring ();

  if (warn_if_readonly_buffer ())
    return leNIL;

  push_mark ();
  undo_save (UNDO_START_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
  execute_function (mark_func, uniarg, true, LUA_REFNIL);
  FUNCALL (kill_region);
  undo_save (UNDO_END_SEQUENCE, get_buffer_pt (cur_bp ()), 0, 0);
  pop_mark ();

  set_this_command ("kill-region");
  minibuf_write ("");		/* Erase "Set mark" message.  */
  return leT;
}

DEFUN_ARGS ("kill-word", kill_word,
            INT_OR_UNIARG (arg))
/*+
Kill characters forward until encountering the end of a word.
With argument @i{arg}, do this that many times.
+*/
{
  INT_OR_UNIARG_INIT (arg);
  ok = kill_text (arg, "mark-word");
}
END_DEFUN

DEFUN_ARGS ("backward-kill-word", backward_kill_word,
            INT_OR_UNIARG (arg))
/*+
Kill characters backward until encountering the end of a word.
With argument @i{arg}, do this that many times.
+*/
{
  INT_OR_UNIARG_INIT (arg);
  ok = kill_text (-arg, "mark-word");
}
END_DEFUN

DEFUN ("kill-sexp", kill_sexp)
/*+
Kill the sexp (balanced expression) following the cursor.
With @i{arg}, kill that many sexps after the cursor.
Negative arg -N means kill N sexps before the cursor.
+*/
{
  ok = kill_text (uniarg, "mark-sexp");
}
END_DEFUN

DEFUN ("yank", yank)
/*+
Reinsert the last stretch of killed text.
More precisely, reinsert the stretch of killed text most recently
killed @i{or} yanked.  Put point at end, and set mark at beginning.
+*/
{
  if (kill_ring_text == NULL)
    {
      minibuf_error ("Kill ring is empty");
      return leNIL;
    }

  if (warn_if_readonly_buffer ())
    return leNIL;

  set_mark_interactive ();

  undo_save (UNDO_REPLACE_BLOCK, get_buffer_pt (cur_bp ()), 0,
             astr_len (kill_ring_text));
  set_undo_nosave (true);
  insert_astr (kill_ring_text);
  set_undo_nosave (false);

  CLUE_DO (L, "deactivate_mark ()");
}
END_DEFUN
