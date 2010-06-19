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

char *
minibuf_read_variable_name (char *fmt)
{
  char *ms;
  int cp;

  CLUE_DO (L, "cp = completion_new ()");
  CLUE_DO (L, "for v in pairs (main_vars) do table.insert (cp.completions, v) end");

  lua_getglobal (L, "cp");
  cp = luaL_ref (L, LUA_REGISTRYINDEX);

  ms = minibuf_vread_completion (fmt, "", cp, LUA_REFNIL,
                                 "No variable name given",
                                 "Undefined variable name `%s'");

  return ms;
}

int
make_buffer_completion (void)
{
  int bp;

  CLUE_DO (L, "cp = completion_new ()");
  for (bp = head_bp (); bp != LUA_REFNIL; bp = get_buffer_next (bp))
    {
      CLUE_SET (L, s, string, get_buffer_name (bp));
      CLUE_DO (L, "table.insert (cp.completions, s)");
    }

  lua_getglobal (L, "cp");
  return luaL_ref (L, LUA_REGISTRYINDEX);
}
