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
static char *prog_name = PACKAGE;

static void
segv_sig_handler (int signo __attribute__ ((unused)))
{
  fprintf (stderr,
           "%s: " PACKAGE_NAME
           " crashed.  Please send a bug report to <"
           PACKAGE_BUGREPORT ">.\r\n",
           prog_name);
  assert (luaL_loadstring(L, "zile_exit (true)") == 0);
  lua_call (L, 0, 1);
}

static void
other_sig_handler (int signo __attribute__ ((unused)))
{
  fprintf (stderr, "%s: terminated with signal %d.\r\n",
           prog_name, signo);
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

int
main (int argc, char **argv)
{
  /* Set prog_name to executable name, if available */
  if (argv[0])
    prog_name = base_name (argv[0]);

  /* Set up Lua environment. */
  assert (L = luaL_newstate ());
  luaL_openlibs (L);
  lua_init (L);
  lua_getargs (L, argc, argv);
  lua_setglobal (L, "arg");
  signal_init ();

  /* Load Lua files. */
  /* FIXME: Use a single absolute path for either the build or install directory. */
  assert (luaL_loadstring (L, "package.path = \"" PATH_DATA "/?.lua;?.lua\"; require (\"loadlua\"); main ()") == 0);
  lua_call (L, 0, 1);

  return 0;
}
