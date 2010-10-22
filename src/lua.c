/*
** Lua stand-alone interpreter adapted from lua.c in Lua distribution:
** $Id: lua.c,v 1.160.1.2 2007/12/28 15:32:23 roberto Exp $
**
******************************************************************************
* Copyright (C) 1994-2008 Lua.org, PUC-Rio.  All rights reserved.
*
* Permission is hereby granted, free of charge, to any person obtaining
* a copy of this software and associated documentation files (the
* "Software"), to deal in the Software without restriction, including
* without limitation the rights to use, copy, modify, merge, publish,
* distribute, sublicense, and/or sell copies of the Software, and to
* permit persons to whom the Software is furnished to do so, subject to
* the following conditions:
*
* The above copyright notice and this permission notice shall be
* included in all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
* EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
* MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
* IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
* CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
* TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
* SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
******************************************************************************/

#include "config.h"

#include <stdlib.h>
#include <ctype.h>
#include <unistd.h>
#include <getopt.h>
#include "xalloc.h"

#define lua_c

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "extern.h"


void lua_getargs (lua_State *L, int argc, char **argv) {
  int i;
  lua_checkstack(L, 3);
  lua_createtable(L, argc, 0);
  for (i = 0; i < argc; i++)
    {
      lua_pushstring(L, argv[i]);
      lua_rawseti(L, -2, i);
    }
}


/* FIXME: Put this somewhere else. */
/* The following is by Reuben Thomas. */

/* FIXME: Package this properly */
#define bind_ctype(f)                                     \
  static int                                              \
  zlua_ ## f (lua_State *L)                               \
  {                                                       \
    const char *s = luaL_checkstring (L, 1);              \
    char c = *s;                                          \
    lua_pop (L, 1);                                       \
    lua_pushboolean (L, f ((int) c));                     \
    return 1;                                             \
  }

bind_ctype (isdigit)
bind_ctype (isgraph)
bind_ctype (isprint)
bind_ctype (isspace)

#define register_zlua(f) \
  lua_register (L, #f, zlua_ ## f)

/* FIXME: Add to lposix, use string modes */
static int
zlua_euidaccess (lua_State *L)
{
  const char *pathname = lua_tostring (L, 1);
  int mode = luaL_checkint (L, 2);
  lua_pushinteger (L, euidaccess (pathname, mode));
  lua_pop (L, 2);
  return 1;
}

/* FIXME: Add to lposix */
/* N.B. We don't use the symbolic constants no_argument,
   optional_argument and required_argument, since their values are
   defined as 0, 1 and 2 respectively. */
static const char *const arg_types[] = {
  "none", "required", "optional", NULL
};

/* ret, longindex = getopt_long (arg, shortopts, longopts) */
static int
zlua_getopt_long (lua_State *L)
{
  int longindex = 0, argc, i, n, ret;
  const char *shortopts;
  char **argv;
  struct option *longopts;

  luaL_checktype (L, 1, LUA_TTABLE);
  shortopts = luaL_checkstring (L, 2);
  luaL_checktype (L, 3, LUA_TTABLE);

  argc = (int) lua_objlen (L, 1) + 1;
  argv = XCALLOC (argc + 1, char *);
  for (i = 0; i < argc; i++)
    {
      lua_pushinteger (L, i);
      lua_gettable (L, 1);
      argv[i] = xstrdup (luaL_checkstring (L, -1));
      lua_pop (L, 1);
    }

  n = (int) lua_objlen (L, 3);
  longopts = XCALLOC (n + 1, struct option);
  for (i = 1; i <= n; i++)
    {
      const char *name;
      int has_arg, val;

      lua_pushinteger (L, i);
      lua_gettable (L, 3);
      luaL_checktype (L, -1, LUA_TTABLE);

      lua_pushinteger (L, 1);
      lua_gettable (L, -2);
      name = xstrdup (luaL_checkstring (L, -1));
      lua_pop (L, 1);

      lua_pushinteger (L, 2);
      lua_gettable (L, -2);
      has_arg = luaL_checkoption (L, -1, NULL, arg_types); /* Not ideal: misleading argument number */
      lua_pop (L, 1);

      lua_pushinteger (L, 3);
      lua_gettable (L, -2);
      val = luaL_checkinteger (L, -1);
      lua_pop (L, 1);

      longopts[i - 1].name = name;
      longopts[i - 1].has_arg = has_arg;
      longopts[i - 1].val = val;
      lua_pop (L, 1);
    }

  opterr = 0; /* Don't display errors for unknown options */
  ret = getopt_long (argc, argv, shortopts, longopts, &longindex);
  lua_pop (L, 3);
  lua_pushinteger (L, ret);
  lua_pushinteger (L, longindex);

  lua_pushinteger (L, optind);
  lua_setglobal (L, "optind");
  lua_pushstring (L, optarg);
  lua_setglobal (L, "optarg");

  /* FIXME: Free xstrdup'ed argv and longopts strings */

  return 2;
}

void
lua_init (lua_State *L)
{
  register_zlua (isdigit);
  register_zlua (isgraph);
  register_zlua (isprint);
  register_zlua (isspace);
  register_zlua (euidaccess);
  register_zlua (getopt_long);

  lua_pushinteger (L, 1); /* FIXME: Ideally initialize to nil, but this doesn't work with strict.lua */
  lua_setglobal (L, "optind");
}
