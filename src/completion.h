/* Completion fields

   Copyright (c) 2009, 2010 Free Software Foundation, Inc.

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

FIELD(const char *, string, match)	/* The match buffer. */
TABLE_FIELD(old_bp)			/* The buffer from which the completion was invoked. */
FIELD(size_t, integer, matchsize)	/* The match buffer size. */
FIELD(int, boolean, poppedup)		/* Completion window has been popped up. */
FIELD(int, boolean, close)		/* The completion window should be closed. */
FIELD(int, boolean, filename)		/* This is a filename completion. */
FIELD(const char *, string, path)	/* Path for a filename completion. */
