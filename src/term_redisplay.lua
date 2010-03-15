-- Redisplay engine
--
-- Copyright (c) 2009, 2010 Free Software Foundation, Inc.
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

local width, height = 0, 0

function term_width ()
  return width
end

function term_height ()
  return height
end

function term_set_size (cols, rows)
  width = cols
  height = rows
end

-- Tidy up the term ready to leave Zile (temporarily or permanently!).
function term_tidy ()
  term_move (term_height () - 1, 0)
  term_clrtoeol ()
  term_attrset (FONT_NORMAL)
  term_refresh ()
end

-- Tidy and close the terminal ready to leave Zile.
function term_finish ()
  term_tidy ()
  term_close ()
end
