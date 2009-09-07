/* Completion facility functions

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

#include <sys/stat.h>
#include <assert.h>
#include <dirent.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "dirname.h"

#include "main.h"
#include "extern.h"


/*
 * Structure
 */
#define FIELD(cty, lty, field)                  \
  LUA_GETTER (completion, cty, lty, field)      \
  LUA_SETTER (completion, cty, lty, field)

#define FIELD_STR(field)                                 \
  LUA_GETTER (completion, const char *, string, field)   \
  LUA_SETTER (completion, const char *, string, field)

#include "completion.h"
#undef FIELD
#undef FIELD_STR

/*
 * Scroll completions up.
 */
void
completion_scroll_up (void)
{
  Window *wp, *old_wp = cur_wp;
  Point pt;

  wp = find_window ("*Completions*");
  assert (wp != NULL);
  set_current_window (wp);
  pt = get_buffer_pt (cur_bp);
  if (pt.n >= get_buffer_last_line (cur_bp) - get_window_eheight (cur_wp) || !FUNCALL (scroll_up))
    gotobob ();
  set_current_window (old_wp);

  term_redisplay ();
}

/*
 * Scroll completions down.
 */
void
completion_scroll_down (void)
{
  Window *wp, *old_wp = cur_wp;
  Point pt;

  wp = find_window ("*Completions*");
  assert (wp != NULL);
  set_current_window (wp);
  pt = get_buffer_pt (cur_bp);
  if (pt.n == 0 || !FUNCALL (scroll_down))
    {
      gotoeob ();
      resync_redisplay ();
    }
  set_current_window (old_wp);

  term_redisplay ();
}

static void
write_completion (va_list ap)
{
  Completion cp = va_arg (ap, Completion);
  size_t width = va_arg (ap, size_t);
  const char *s;
  lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
  lua_setglobal (L, "cp");
  CLUE_SET (L, width, integer, width);
  (void) CLUE_DO (L, "s = completion_write (cp, width)");
  CLUE_GET (L, s, string, s);
  bprintf ("%s", s);
}

/*
 * Popup the completion window.
 */
void
popup_completion (Completion cp)
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
  lua_setglobal (L, "cp");
  (void) CLUE_DO (L, "cp.poppedup = true");
  if (get_window_next (head_wp) == NULL)
    (void) CLUE_DO (L, "cp.close = true");

  write_temp_buffer ("*Completions*", true, write_completion, cp, get_window_ewidth (cur_wp));

  if (!get_completion_close (cp))
    set_completion_old_bp (cp, cur_bp);

  term_redisplay ();
}

/*
 * Match completions.
 */
int
completion_try (Completion cp, astr search)
{
  int matches;
  const char *s;

  CLUE_SET (L, search, string, astr_cstr (search));
  (void) CLUE_DO (L, "search = completion_try (cp, search)");
  (void) CLUE_DO (L, "matches = #cp.matches");
  CLUE_GET (L, matches, integer, matches);
  CLUE_GET (L, search, string, s);
  astr_cpy_cstr (search, s);

  if (matches == 0)
    return COMPLETION_NOTMATCHED;
  else if (matches == 1)
    return COMPLETION_MATCHED;
  else if (strncmp (get_completion_match (cp), astr_cstr (search), astr_len (search)) == 0 && matches > 1)
    return COMPLETION_MATCHEDNONUNIQUE;
  else
    return COMPLETION_NONUNIQUE;
}

char *
minibuf_read_variable_name (char *fmt, ...)
{
  va_list ap;
  char *ms;
  Completion cp;

  (void) CLUE_DO (L, "cp = completion_new ()");
  (void) CLUE_DO (L, "for v in pairs (main_vars) do table.insert (cp.completions, v) end");

  lua_getglobal (L, "cp");
  cp = luaL_ref (L, LUA_REGISTRYINDEX);

  va_start (ap, fmt);
  ms = minibuf_vread_completion (fmt, "", cp, LUA_NOREF,
                                 "No variable name given",
                                 minibuf_test_in_completions,
                                 "Undefined variable name `%s'", ap);
  va_end (ap);

  return ms;
}

Completion
make_buffer_completion (void)
{
  Buffer *bp;

  (void) CLUE_DO (L, "cp = completion_new ()");
  for (bp = head_bp; bp != NULL; bp = get_buffer_next (bp))
    {
      CLUE_SET (L, s, string, get_buffer_name (bp));
      (void) CLUE_DO (L, "table.insert (cp.completions, s)");
    }

  lua_getglobal (L, "cp");
  return luaL_ref (L, LUA_REGISTRYINDEX);
}
