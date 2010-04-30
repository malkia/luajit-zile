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

-- Add a string to the terminal
function term_addstr (s)
  for i = 1, #s do
    term_addch (string.byte (s, i))
  end
end

function show_splash_screen (splash)
  local h = term_height ()

  for i = 0, h - 3 do
    term_move (i, 0)
    term_clrtoeol ()
  end

  term_move (0, 0)
  local i, j = 1, 0
  while i <= #splash and j < h - 2 do
    if string.sub (splash, i, i) == '\n' then
      j = j + 1
      term_move (j, 0)
    else
      term_addch (string.byte (splash, i))
    end
    i = i + 1
  end
end
