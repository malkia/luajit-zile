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
 * Allocate a new completion structure.
 */
Completion
completion_new (int fileflag)
{
  Completion cp;

  lua_newtable (L);
  cp = luaL_ref (L, LUA_REGISTRYINDEX);
  lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
  lua_setglobal (L, "cp");
  (void) CLUE_DO (L, "cp.matches, cp.completions = {}, {}");

  if (fileflag)
    {
      set_completion_path (cp, astr_new ());
      set_completion_flags (cp, CFLAG_FILENAME);
    }

  return cp;
}

/*
 * Free a completion structure.
 */
void
free_completion (Completion cp)
{
  if (get_completion_flags (cp) & CFLAG_FILENAME)
    astr_delete (get_completion_path (cp));
}

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
  set_completion_flags (cp, get_completion_flags (cp) | CFLAG_POPPEDUP);
  if (get_window_next (head_wp) == NULL)
    set_completion_flags (cp, get_completion_flags (cp) | CFLAG_CLOSE);

  write_temp_buffer ("*Completions*", true, write_completion, cp, get_window_ewidth (cur_wp));

  if (!(get_completion_flags (cp) & CFLAG_CLOSE))
    set_completion_old_bp (cp, cur_bp);

  term_redisplay ();
}

/*
 * Reread directory for completions.
 */
static int
completion_readdir (Completion cp, astr as)
{
  DIR *dir;
  char *s1, *s2;
  const char *pdir, *base;
  struct dirent *d;
  struct stat st;
  astr bs;

  lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
  lua_setglobal (L, "cp");
  (void) CLUE_DO (L, "cp.completions = {}");

  if (!expand_path (as))
    return false;

  bs = astr_new ();

  /* Split up path with dirname and basename, unless it ends in `/',
     in which case it's considered to be entirely dirname */
  s1 = xstrdup (astr_cstr (as));
  s2 = xstrdup (astr_cstr (as));
  if (astr_get (as, astr_len (as) - 1) != '/')
    {
      pdir = dir_name (s1);
      /* Append `/' to pdir */
      astr_cat_cstr (bs, pdir);
      if (astr_get (bs, astr_len (bs) - 1) != '/')
        astr_cat_char (bs, '/');
      free ((char *) pdir);
      pdir = astr_cstr (bs);
      base = base_name (s2);
    }
  else
    {
      pdir = s1;
      base = xstrdup ("");
    }

  astr_cpy_cstr (as, base);
  free ((char *) base);

  dir = opendir (pdir);
  if (dir != NULL)
    {
      astr buf = astr_new ();
      while ((d = readdir (dir)) != NULL)
        {
          astr_cpy_cstr (buf, pdir);
          astr_cat_cstr (buf, d->d_name);
          if (stat (astr_cstr (buf), &st) != -1)
            {
              astr_cpy_cstr (buf, d->d_name);
              if (S_ISDIR (st.st_mode))
                astr_cat_char (buf, '/');
            }
          else
            astr_cpy_cstr (buf, d->d_name);
          CLUE_SET (L, s, string, astr_cstr (buf));
          (void) CLUE_DO (L, "table.insert (cp.completions, s)");
        }
      closedir (dir);

      astr_delete (get_completion_path (cp));
      set_completion_path (cp, compact_path (astr_new_cstr (pdir)));
      astr_delete (buf);
    }

  astr_delete (bs);
  free (s1);
  free (s2);

  return dir != NULL;
}

/*
 * Match completions.
 */
int
completion_try (Completion cp, astr search)
{
  size_t i, j, ssize, completions;
  size_t fullmatches = 0;
  char c;

  set_completion_partmatches (cp, 0);
  lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
  lua_setglobal (L, "cp");
  (void) CLUE_DO (L, "cp.matches = {}");

  if (get_completion_flags (cp) & CFLAG_FILENAME)
    if (!completion_readdir (cp, search))
      return COMPLETION_NOTMATCHED;

  ssize = astr_len (search);

  (void) CLUE_DO (L, "completions = #cp.completions");
  CLUE_GET (L, completions, integer, completions);
  for (i = 0; i < completions; i++)
    {
      const char *s;
      CLUE_SET (L, i, integer, i + 1);
      (void) CLUE_DO (L, "s = cp.completions[i]");
      CLUE_GET (L, s, string, s);
      if (!strncmp (s, astr_cstr (search), ssize))
        {
          set_completion_partmatches (cp, get_completion_partmatches (cp) + 1);
          CLUE_SET (L, s, string, s);
          (void) CLUE_DO (L, "table.insert (cp.matches, s)");
          if (!strcmp (s, astr_cstr (search)))
            ++fullmatches;
        }
    }
  (void) CLUE_DO (L, "table.sort (cp.matches)");

  if (get_completion_partmatches (cp) == 0)
    return COMPLETION_NOTMATCHED;
  else if (get_completion_partmatches (cp) == 1)
    {
      const char *s;
      (void) CLUE_DO (L, "s = cp.matches[1]");
      CLUE_GET (L, s, string, s);
      set_completion_match (cp, s);
      set_completion_matchsize (cp, strlen (get_completion_match (cp)));
      return COMPLETION_MATCHED;
    }

  if (fullmatches == 1 && get_completion_partmatches (cp) > 1)
    {
      const char *s;
      (void) CLUE_DO (L, "s = cp.matches[1]");
      CLUE_GET (L, s, string, s);
      set_completion_match (cp, s);
      set_completion_matchsize (cp, strlen (get_completion_match (cp)));
      return COMPLETION_MATCHEDNONUNIQUE;
    }

  for (j = ssize;; ++j)
    {
      const char *s;
      (void) CLUE_DO (L, "s = cp.matches[1]");
      CLUE_GET (L, s, string, s);

      c = s[j];
      for (i = 1; i < get_completion_partmatches (cp); ++i)
        {
          CLUE_SET (L, i, integer, i + 1);
          (void) CLUE_DO (L, "s = cp.matches[i]");
          CLUE_GET (L, s, string, s);
          if (s[j] != c)
            {
              const char *s;
              (void) CLUE_DO (L, "s = cp.matches[1]");
              CLUE_GET (L, s, string, s);
              set_completion_match (cp, s);
              set_completion_matchsize (cp, j);
              return COMPLETION_NONUNIQUE;
            }
        }
    }

  abort ();
}

char *
minibuf_read_variable_name (char *fmt, ...)
{
  va_list ap;
  char *ms;
  Completion cp = completion_new (false);

  lua_getglobal (L, "main_vars");
  lua_pushnil (L);
  while (lua_next (L, -2) != 0) {
    assert (lua_tostring (L, -2));
    lua_setglobal (L, "s");
    (void) CLUE_DO (L, "table.insert (cp.completions, s)");
  }
  lua_pop (L, 1);

  va_start (ap, fmt);
  ms = minibuf_vread_completion (fmt, "", cp, NULL,
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
  Completion cp = completion_new (false);

  lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
  lua_setglobal (L, "cp");
  for (bp = head_bp; bp != NULL; bp = get_buffer_next (bp))
    {
      CLUE_SET (L, s, string, get_buffer_name (bp));
      (void) CLUE_DO (L, "table.insert (cp.completions, s)");
    }

  return cp;
}
