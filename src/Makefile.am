# Source Makefile.am
#
# Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008, 2009, 2010, 2011 Free Software Foundation, Inc.
#
# This file is part of GNU Zile.
#
# GNU Zile is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# GNU Zile is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with GNU Zile; see the file COPYING.  If not, write to the
# Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
# MA 02111-1301, USA.

LUA_ENV = LUA_INIT= LUA_PATH="$(srcdir)/?.lua"

bin_SCRIPTS = zile

zile_LUA =						\
	lib.lua						\
	history.lua					\
	lisp.lua					\
	tbl_vars.lua					\
	variables.lua					\
	main.lua					\
	basic.lua					\
	bind.lua					\
	buffer.lua					\
	completion.lua					\
	editfns.lua					\
	funcs.lua					\
	getkey.lua					\
	help.lua					\
	file.lua					\
	keycode.lua					\
	killring.lua					\
	line.lua					\
	macro.lua					\
	marker.lua					\
	minibuf.lua					\
	point.lua					\
	redisplay.lua					\
	registers.lua					\
	search.lua					\
	undo.lua					\
	window.lua					\
	term_curses.lua					\
	term_minibuf.lua				\
	term_redisplay.lua

LUA_RUNTIME =						\
	std.lua						\
	$(zile_LUA)

PRODUCTIONSOURCES =					\
	$(zile_SOURCES)					\
	$(zile_LUA)					\
	Makefile.am ../Makefile.am ../configure.ac	\
	*.el

LUA_CLIBS = posix curses bit rex_gnu

loadlua.lua: $(LUA_RUNTIME) Makefile.am
	echo "-- Generated file - do not edit!" > $@
	for i in $(LUA_CLIBS) $(LUA_RUNTIME); do echo 'require "'`echo $$i | sed -e 's/\\.lua$$//g'`'"' >> $@; done

edit = sed \
	-e 's|@pkgdatadir[@]|$(pkgdatadir)|g'

zile: zile.lua loadlua.lua Makefile
	rm -f $@ $@.tmp
	$(edit) '$(srcdir)/$@.lua' >$@.tmp
	mv $@.tmp $@
	chmod +x $@

zile.1: zile zile.1.in Makefile
	rm -f $@ $@.tmp
	$(edit) '$(srcdir)/$@.in' >$@.tmp
	mv $@.tmp $@

zile.1.in: zile man-extras zile-help2man-wrapper
	builddir=$(builddir) $(HELP2MAN) --output=$@ --no-info --name="Zile Is Lossy Emacs" --include $(srcdir)/man-extras $(srcdir)/zile-help2man-wrapper

dist_pkgdata_DATA = dotzile-extra.el

dist_man_MANS = zile.1

CLEANFILES = $(bin_SCRIPTS)

DISTCLEANFILES = 					\
	zile.1

MAINTAINERCLEANFILES =					\
	loadlua.lua

CLOC = cloc --force-lang="C",h

TESTSOURCES = $(LISP_TESTS) $(LISP_TESTS_ZILE_ONLY) $(TESTSCRIPTS)

ALLSOURCES = $(TESTSOURCES) $(PRODUCTIONSOURCES)

loc:
	$(CLOC) $(PRODUCTIONSOURCES)

loc-tests:
	$(CLOC) $(TESTSOURCES)

loc-all:
	$(CLOC) $(ALLSOURCES)

TESTS_VARS = srcdir=$(srcdir) builddir=$(builddir)
TESTS_ENVIRONMENT = $(TESTS_VARS)

check-local:
	echo $(LISP_TESTS) | $(TESTS_VARS) EMACS="$(EMACS)" xargs $(LUA) "$(srcdir)/run-lisp-tests.lua"
	echo $(LISP_TESTS_ZILE_ONLY) | $(TESTS_VARS) EMACS= xargs $(LUA) "$(srcdir)/run-lisp-tests.lua"

TESTSCRIPTS =						\
	run-lisp-tests.lua				\
	test-bad-argument

# FIXME: Find a way of making these work
#	lisp-tests/disabled/*.el

# FIXME: Make these work in Emacs too
LISP_TESTS_ZILE_ONLY = $(srcdir)/lisp-tests/zile-only/*.el

LISP_TESTS = $(srcdir)/lisp-tests/*.el

LISP_TESTS_OUTPUTS = $(srcdir)/lisp-tests/*.output $(srcdir)/lisp-tests/zile-only/*.output

EXTRA_DIST =						\
	$(zile_LUA)					\
	zile.lua.in					\
	std.lua						\
	$(LISP_TESTS)					\
	$(LISP_TESTS_ZILE_ONLY)				\
	$(LISP_TESTS_OUTPUTS)				\
	lisp-tests/test.input				\
	$(TESTSCRIPTS)					\
	quit.el						\
	man-extras					\
	zile.1.in					\
	zile-help2man-wrapper
