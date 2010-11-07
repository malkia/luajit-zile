/* Program invocation, startup and shutdown

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
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <signal.h>
#include "dirname.h"

#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#define ZILE_VERSION_STRING	"GNU " PACKAGE_NAME " " VERSION

#include "extern.h"

#define ZILE_COPYRIGHT_STRING \
  "Copyright (C) 2010 Free Software Foundation, Inc."

lua_State *L;

/* The executable name. */
char *program_name = PACKAGE;

static void
segv_sig_handler (int signo __attribute__ ((unused)))
{
  fprintf (stderr,
           "%s: " PACKAGE_NAME
           " crashed.  Please send a bug report to <"
           PACKAGE_BUGREPORT ">.\r\n",
           program_name);
  assert (luaL_loadstring(L, "zile_exit (true)") == 0);
  lua_call (L, 0, 1);
}

static void
other_sig_handler (int signo __attribute__ ((unused)))
{
  fprintf (stderr, "%s: terminated with signal %d.\r\n",
           program_name, signo);
  assert (luaL_loadstring(L, "zile_exit (false)") == 0);
  lua_call (L, 0, 1);
}

static void
signal_init (void)
{
  /* Set up signal handling */
  signal (SIGSEGV, segv_sig_handler);
  signal (SIGBUS, segv_sig_handler);
  signal (SIGHUP, other_sig_handler);
  signal (SIGINT, other_sig_handler);
  signal (SIGTERM, other_sig_handler);
}

static void l_message (const char *pname, const char *msg) {
  if (pname) fprintf(stderr, "%s: ", pname);
  fprintf(stderr, "%s\n", msg);
  fflush(stderr);
}

static int report (lua_State *L, int status) {
  if (status && !lua_isnil(L, -1)) {
    const char *msg = lua_tostring(L, -1);
    if (msg == NULL) msg = "(error object is not a string)";
    l_message(program_name, msg);
    lua_pop(L, 1);
  }
  return status;
}

static void sig_catch(int sig, void (*handler)(int))
{
  struct sigaction sa;
  sa.sa_handler = handler;
  sa.sa_flags = 0;
  sigemptyset(&sa.sa_mask);
  sigaction(sig, &sa, 0);         /* XXX ignores errors */
}

static void lstop (lua_State *L, lua_Debug *ar) {
  (void)ar;  /* unused arg. */
  lua_sethook(L, NULL, 0, 0);
  luaL_error(L, "interrupted!");
}

static void laction (int i) {
  (void) i;
  lua_sethook(L, lstop, LUA_MASKCALL | LUA_MASKRET | LUA_MASKCOUNT, 1);
}

static int traceback (lua_State *L) {
  if (!lua_isstring(L, 1))  /* 'message' not a string? */
    return 1;  /* keep it intact */
  lua_getfield(L, LUA_GLOBALSINDEX, "debug");
  if (!lua_istable(L, -1)) {
    lua_pop(L, 1);
    return 1;
  }
  lua_getfield(L, -1, "traceback");
  if (!lua_isfunction(L, -1)) {
    lua_pop(L, 2);
    return 1;
  }
  lua_pushvalue(L, 1);  /* pass error message */
  lua_pushinteger(L, 2);  /* skip this function and traceback */
  lua_call(L, 2, 1);  /* call debug.traceback */
  return 1;
}

static int docall (lua_State *L, int narg, int clear) {
  int status;
  int base = lua_gettop(L) - narg;  /* function index */
  lua_pushcfunction(L, traceback);  /* push traceback function */
  lua_insert(L, base);  /* put it under chunk and args */
  sig_catch(SIGINT, laction);
  status = lua_pcall(L, narg, (clear ? 0 : LUA_MULTRET), base);
  sig_catch(SIGINT, SIG_DFL);
  lua_remove(L, base);  /* remove traceback function */
  /* force a complete garbage collection in case of errors */
  if (status != 0) lua_gc(L, LUA_GCCOLLECT, 0);
  return status;
}

static int dostring (lua_State *L, const char *s, const char *name) {
  int status = luaL_loadbuffer(L, s, strlen(s), name) || docall(L, 0, 1);
  return report(L, status);
}

static void getargs (lua_State *L, int argc, char **argv) {
  int i;
  lua_checkstack(L, 3);
  lua_createtable(L, argc, 0);
  for (i = 0; i < argc; i++)
    {
      lua_pushstring(L, argv[i]);
      lua_rawseti(L, -2, i);
    }
}

int
main (int argc, char **argv)
{
  /* Set program_name to executable name, if available */
  if (argv[0])
    program_name = base_name (argv[0]);
  else
    program_name = PACKAGE;

  /* Set up Lua environment. */
  assert (L = luaL_newstate ());
  luaL_openlibs (L);
  lua_init (L);
  getargs (L, argc, argv);
  lua_setglobal (L, "arg");
  lua_pushstring (L, program_name);
  lua_setglobal (L, "program_name");
  signal_init ();

  /* Load Lua files. */
  /* FIXME: Use a single absolute path for either the build or install directory. */
  assert (dostring (L, "package.path = \"" PATH_DATA "/?.lua;?.lua\"; require (\"loadlua\"); main ()", "C main()") == 0);

  return 0;
}
