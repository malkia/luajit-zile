# Top-level Makefile.am
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

SUBDIRS = src

ACLOCAL_AMFLAGS = -I m4

EXTRA_DIST = BUGS m4/gnulib-cache.m4

dist_pkgdata_DATA = FAQ

ChangeLog:
	git2cl > ChangeLog

# Announcement follows:
# I am happy to announce the release of $package_name $version,
# $description.
#
# $release_notes
#
# $package_name\'s web page is at http://www.gnu.org/software/$package/
#
# The signed source can be obtained from ftp.gnu.org and its world-wide
# mirrors:
#
#   http://ftp.gnu.org/gnu/$package/$package-$version.tar.gz
#   http://ftp.gnu.org/gnu/$package/$package-$version.tar.gz.sig
release: distcheck
	agrep -d '^Release' $(VERSION) NEWS | tail -n +3 | head -n -1 > release-notes && \
	woger freshmeat $(PACKAGE) "$(PACKAGE_NAME)" $(VERSION) "the tiny Emacs clone" release-notes && \
	rm -f release-notes
