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

-- FIXME: local
function make_char_printable (c)
  if c == 0 then
    return "^@"
  elseif c > 0 and c <= 27 then
    return string.format ("^%c", string.byte ("A") + c - 1)
  else
    return string.format ("\\%o", bit.band (c, 0xff))
  end
end

local cur_tab_width = 0

-- FIXME: local
function outch (c, font, x)
  local tw = term_width ()

  if x >= tw then
    return x
  end

  term_attrset (font)

  if c == string.byte ('\t') then
    for w = cur_tab_width - x % cur_tab_width, 1, -1 do
      term_addch (string.byte (' '))
      x = x + 1
      if x >= tw then
        break
      end
    end
  elseif isprint (string.char (c)) then
    term_addch (c)
    x = x + 1
  else
    local s = make_char_printable (c)
    local j = #s
    for i = 1, j do
      term_addch (string.byte (s, i))
      x = x + 1
      if x >= tw then
        break
      end
    end
  end

  term_attrset (FONT_NORMAL)

  return x
end

local function draw_end_of_line (line, wp, lineno, rp, highlight, x, i)
  if x >= term_width () then
    term_move (line, term_width () - 1)
    term_addch (string.byte ('$'))
  elseif highlight == true then
    while x < wp.ewidth do
      if in_region (lineno, i, rp) then
        x = outch (string.byte (' '), FONT_REVERSE, x)
      else
        x = x + 1
      end
      i = i + 1
    end
  end
end

-- FIXME: local
function draw_line (line, startcol, wp, lp, lineno, rp, highlight)
  term_move (line, 0)

  local x = 0
  for i = startcol, #lp.text do
    if x >= wp.ewidth then
      break
    end
    x = outch (string.byte (lp.text, i + 1), highlight and in_region (lineno, i, rp) and FONT_REVERSE or FONT_NORMAL, x)
  end

  draw_end_of_line (line, wp, lineno, rp, highlight, x, i)
end
