-- Zile Lisp interpreter
--
-- Copyright (c) 2009 Free Software Foundation, Inc.
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

function read_char (s, pos)
  if pos <= #s then
    return string.sub (s, pos, pos), pos + 1
  end
  return -1, pos
end

T_EOF = 0
T_CLOSEPAREN = 1
T_OPENPAREN = 2
T_NEWLINE = 3
T_QUOTE = 4
T_WORD = 5

function read_token (s, pos)
  local c
  local doublequotes = false
  local tok = ""

  -- Chew space to next token
  repeat
    c, pos = read_char (s, pos)

    -- Munch comments
    if c == ";" then
      repeat
        c, pos = read_char (s, pos)
      until c == -1 or c == "\n"
    end
  until c ~= " " and c ~= "\t"

  -- Snag token
  if c == "(" then
    return tok, T_OPENPAREN, pos
  elseif c == ")" then
    return tok, T_CLOSEPAREN, pos
  elseif c == "\'" then
    return tok, T_QUOTE, pos
  elseif c == "\n" then
    return tok, T_NEWLINE, pos
  elseif c == -1 then
    return tok, T_EOF, pos
  end

  -- It looks like a string. Snag to the next whitespace.
  if c == "\"" then
    doublequotes = true
    c, pos = read_char (s, pos)
  end

  repeat
    tok = tok .. c
    if not doublequotes then
      if c == ")" or c == "(" or c == ";" or c == " " or c == "\n"
        or c == "\r" or c == -1 then
        pos = pos - 1
        tok = string.sub (tok, 1, -2)
        return tok, T_WORD, pos
      end
    else
      if c == "\n" or c == "\r" or c == -1 then
        pos = pos - 1
      end
      if c == "\"" then
        tok = string.sub (tok, 1, -2)
        return tok, T_WORD, pos
      end
    end
    c, pos = read_char (s, pos)
  until false
end
