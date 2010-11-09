#include <string.h>
#include <getopt.h>

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "extern.h"


/* N.B. We don't need the symbolic constants no_argument,
   required_argument and optional_argument, since their values are
   defined as 0, 1 and 2 respectively. */
static const char *const arg_types[] = {
  "none", "required", "optional", NULL
};

static int iter_getopt_long(lua_State *L)
{
  int longindex = 0, ret, argc = lua_tointeger(L, lua_upvalueindex(1));
  char **argv = (char **)lua_touserdata(L, lua_upvalueindex(3));
  struct option *longopts = (struct option *)lua_touserdata(L, lua_upvalueindex(3 + argc + 1));

  if (argv == NULL) /* If we have already completed, return now. */
    return 0;

  /* Fetch upvalues to pass to getopt_long. */
  ret = getopt_long(argc, argv,
                    lua_tostring(L, lua_upvalueindex(2)),
                    longopts,
                    &longindex);
  if (ret == -1)
    return 0;
  else {
    lua_pushinteger(L, ret);
    lua_pushinteger(L, longindex);
    lua_pushinteger(L, optind);
    lua_pushstring(L, optarg);
    return 4;
  }
}

/* for ret, longindex, optind, optarg in getopt_long (arg, shortopts, longopts, opterr, optind) do ... end */
static int Pgetopt_long(lua_State *L)
{
  int argc, i, n;
  const char *shortopts;
  char **argv;
  struct option *longopts;

  luaL_checktype(L, 1, LUA_TTABLE);
  shortopts = luaL_checkstring(L, 2);
  luaL_checktype(L, 3, LUA_TTABLE);
  opterr = luaL_optinteger (L, 4, 0);
  optind = luaL_optinteger (L, 5, 1);

  argc = (int)lua_objlen(L, 1) + 1;
  lua_pushinteger(L, argc);

  lua_pushstring(L, shortopts);

  argv = lua_newuserdata(L, (argc + 1) * sizeof(char *));
  memset (argv, 0, (argc + 1) * sizeof(char *));
  for (i = 0; i < argc; i++)
    {
      lua_pushinteger(L, i);
      lua_gettable(L, 1);
      argv[i] = (char *)luaL_checkstring(L, -1);
    }

  n = (int)lua_objlen(L, 3);
  longopts = lua_newuserdata(L, (n + 1) * sizeof(struct option));
  memset (longopts, 0, (n + 1) * sizeof(struct option));
  for (i = 1; i <= n; i++)
    {
      const char *name;
      int has_arg, val;

      lua_pushinteger(L, i);
      lua_gettable(L, 3);
      luaL_checktype(L, -1, LUA_TTABLE);

      lua_pushinteger(L, 1);
      lua_gettable(L, -2);
      name = luaL_checkstring(L, -1);

      lua_pushinteger(L, 2);
      lua_gettable(L, -3);
      has_arg = luaL_checkoption(L, -1, NULL, arg_types);
      lua_pop(L, 1);

      lua_pushinteger(L, 3);
      lua_gettable(L, -3);
      val = luaL_checkinteger(L, -1);
      lua_pop(L, 1);

      longopts[i - 1].name = name;
      longopts[i - 1].has_arg = has_arg;
      longopts[i - 1].val = val;
      lua_pop(L, 1);
    }

  /* Push remaining upvalues, and make and push closure. */
  lua_pushcclosure(L, iter_getopt_long, 4 + argc + n);

  return 1;
}

void lua_init (lua_State *L)
{
  lua_register(L, "getopt_long", Pgetopt_long);
}
