#include "config.h"

#include <stdlib.h>
#include <getopt.h>
#include "xalloc.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "extern.h"


/* N.B. We don't need the symbolic constants no_argument,
   optional_argument and required_argument, since their values are
   defined as 0, 1 and 2 respectively. */
static const char *const arg_types[] = {
  "none", "required", "optional", NULL
};

/* for ret, longindex, optind, optarg in getopt_long (arg, shortopts, longopts) do ... end */
static int iter_getopt_long(lua_State *L)
{
  int longindex = 0, ret;
  char **argv = (char **)lua_touserdata(L, lua_upvalueindex(2));
  struct option *longopts = (struct option *)lua_touserdata(L, lua_upvalueindex( 4));

  opterr = 0; /* Don't display errors for unknown options; FIXME: make this optional? */

  /* Fetch upvalues to pass to getopt_long. */
  ret = getopt_long(lua_tointeger(L, lua_upvalueindex(1)), argv,
                    lua_tostring(L, lua_upvalueindex(3)),
                    longopts,
                    &longindex);
  if (ret == -1) { /* Free everything allocated. */
    /* FIXME: Ensure that the freed values can't be accessed. */
    int i;

    for (i = 0; argv[i]; i++)
      free(argv[i]);
    free(argv);
    for (i = 0; longopts[i].name != NULL; i++)
      free((char *)longopts[i].name);
    free(longopts);

    return 0;
  } else {
    lua_pushinteger(L, ret);
    lua_pushinteger(L, longindex);
    lua_pushinteger(L, optind);
    lua_pushstring(L, optarg);
    return 4;
  }
}

static int Pgetopt_long(lua_State *L)
{
  int argc, i, n;
  const char *shortopts;
  char **argv;
  struct option *longopts;

  luaL_checktype(L, 1, LUA_TTABLE);
  shortopts = luaL_checkstring(L, 2);
  luaL_checktype(L, 3, LUA_TTABLE);

  argc = (int)lua_objlen(L, 1) + 1;
  argv = XCALLOC(argc + 1, char *);
  for (i = 0; i < argc; i++)
    {
      lua_pushinteger(L, i);
      lua_gettable(L, 1);
      argv[i] = xstrdup(luaL_checkstring(L, -1));
      lua_pop(L, 1);
    }

  n = (int)lua_objlen(L, 3);
  longopts = XCALLOC(n + 1, struct option);
  for (i = 1; i <= n; i++)
    {
      const char *name;
      int has_arg, val;

      lua_pushinteger(L, i);
      lua_gettable(L, 3);
      luaL_checktype(L, -1, LUA_TTABLE);

      lua_pushinteger(L, 1);
      lua_gettable(L, -2);
      name = xstrdup(luaL_checkstring(L, -1));
      lua_pop(L, 1);

      lua_pushinteger(L, 2);
      lua_gettable(L, -2);
      has_arg = luaL_checkoption(L, -1, NULL, arg_types);
      lua_pop(L, 1);

      lua_pushinteger(L, 3);
      lua_gettable(L, -2);
      val = luaL_checkinteger(L, -1);
      lua_pop(L, 1);

      longopts[i - 1].name = name;
      longopts[i - 1].has_arg = has_arg;
      longopts[i - 1].val = val;
      lua_pop(L, 1);
    }

  lua_pop(L, 3);

  /* Push upvalues and closure. */
  lua_pushinteger(L, argc);
  lua_pushlightuserdata(L, argv);
  lua_pushstring(L, shortopts);
  lua_pushlightuserdata(L, longopts);
  lua_pushcclosure(L, iter_getopt_long, 4);

  /* FIXME: Allow optind to be set to other values e.g. to use GNU extensions. */
  lua_pushinteger(L, 1); /* Initial value of optind. */

  return 2;
}

void lua_init (lua_State *L)
{
  lua_register(L, "getopt_long", Pgetopt_long);
}
