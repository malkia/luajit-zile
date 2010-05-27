/* Completion facility functions

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
#include <stdlib.h>

#include "main.h"
#include "extern.h"


/*
 * Structure
 */
#define FIELD(cty, lty, field)                  \
  LUA_GETTER (completion, cty, lty, field)

#define TABLE_FIELD(field)                       \
  LUA_TABLE_GETTER (completion, field)

#include "completion.h"
#undef FIELD

static void
write_completion (va_list ap)
{
  int cp = va_arg (ap, int);
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
popup_completion (int cp)
{
  lua_rawgeti (L, LUA_REGISTRYINDEX, cp);
  lua_setglobal (L, "cp");
  (void) CLUE_DO (L, "cp.poppedup = true");
  if (get_window_next (head_wp) == LUA_REFNIL)
    (void) CLUE_DO (L, "cp.close = true");

  write_temp_buffer ("*Completions*", true, write_completion, cp, get_window_ewidth (cur_wp));

  if (!get_completion_close (cp))
    (void) CLUE_DO (L, "cp.old_bp = cur_bp");

  term_redisplay ();
}

char *
minibuf_read_variable_name (char *fmt, ...)
{
  va_list ap;
  char *ms;
  int cp;

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

int
make_buffer_completion (void)
{
  int bp;

  (void) CLUE_DO (L, "cp = completion_new ()");
  for (bp = head_bp (); bp != LUA_REFNIL; bp = get_buffer_next (bp))
    {
      CLUE_SET (L, s, string, get_buffer_name (bp));
      (void) CLUE_DO (L, "table.insert (cp.completions, s)");
    }

  lua_getglobal (L, "cp");
  return luaL_ref (L, LUA_REGISTRYINDEX);
}
