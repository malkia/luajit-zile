#!/usr/bin/env luajit
-- Program initialisation
--
-- Copyright (c) 2010 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- GNU Zile is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- GNU Zile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with GNU Zile; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.

_DEBUG = true

-- Constants set by configure
PACKAGE = "zile"
PACKAGE_NAME = "Zile"
PACKAGE_BUGREPORT = "bug-zile@gnu.org"
VERSION = "2.4.0"
CONFIGURE_DATE = "Thu Mar 10 2011"
CONFIGURE_HOST = "malkiaBook.local"
PATH_DATA = "."

package.path = PATH_DATA .. "/?.lua"
require ("loadlua")
main ()
