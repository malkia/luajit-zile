dnl configure.ac
dnl
dnl Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011 Free Software Foundation, Inc.
dnl
dnl This file is part of GNU Zile.
dnl
dnl GNU Zile is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published
dnl by the Free Software Foundation; either version 3, or (at your
dnl option) any later version.
dnl
dnl GNU Zile is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with GNU Zile; see the file COPYING.  If not, write to the
dnl Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
dnl MA 02111-1301, USA.

dnl Initialise autoconf and automake
AC_INIT(Zile, 2.4.0, bug-zile@gnu.org)
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([-Wall -Werror std-options check-news])
AM_SILENT_RULES([yes])

dnl Set up gnulib
gl_EARLY
gl_INIT

dnl Lua 5.1
AX_PROG_LUA(501)

dnl help2man
AX_WITH_PROG(HELP2MAN, help2man, false)

dnl Emacs >= 23.1 (optional)
AX_WITH_PROG(EMACS, emacs)
if test -n "$EMACS"; then
  emacs_min_version=23.1
  emacs_version=$($EMACS --version 2>&1 | head -n 1 | cut -d' ' -f3)
  AC_MSG_CHECKING([Emacs version $emacs_version >= $emacs_min_version])
  AX_COMPARE_VERSION($emacs_version, ge, $emacs_min_version,
    AC_MSG_RESULT([yes]),
    [AC_MSG_RESULT([no])
    unset EMACS])
fi

dnl Extra definitions
AC_SUBST(CONFIGURE_DATE, ["`date '+%a %b %d %Y'`"])
AC_SUBST(CONFIGURE_HOST, ["${ac_hostname}"])

dnl Generate output
AC_CONFIG_FILES(Makefile src/Makefile src/zile.lua)
AC_OUTPUT
