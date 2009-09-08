-- Completion facility functions
--
-- Copyright (c) 2007, 2009 Free Software Foundation, Inc.
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

-- Completions table:
-- {
--   completions - list of completion strings
--   matches - list of matches
--   match - the current matched string
--   filename - true if the completion is a filename completion
--   poppedup - true if the completion is currently displayed
--   close - true if the completion window should be closed
-- }

-- Make a new completions table
function completion_new ()
  return {completions = {}, matches = {}}
end

-- Write the matches in `l' in a set of columns. The width of the
-- columns is chosen to be big enough for the longest string, with a
-- COLUMN_GAP-character gap between each column.
local COLUMN_GAP = 5
function completion_write (cp, width)
  local s = "Possible completions are:\n"
  local maxlen = 0
  for i, v in ipairs (cp.matches) do
    maxlen = math.max (maxlen, #v)
  end
  maxlen = maxlen + COLUMN_GAP
  local numcols = math.floor ((width - 1) / maxlen)
  local col = 0
  for i, v in ipairs (cp.matches) do
    if col >= numcols then
      col = 0
      s = s .. "\n"
    end
    s = s .. v
    col = col + 1
    s = s .. string.rep (" ", maxlen - #v)
  end
  return s
end

-- Returns the length of the longest string that is a prefix of
-- both s1 and s2.
local function common_prefix_length (s1, s2)
  local len = math.min (#s1, #s2)
  for i = 1, len do
    if string.sub (s1, 1, i) ~= string.sub (s2, 1, i) then
      return i - 1
    end
  end
  return len
end


-- Reread directory for completions.
local function completion_readdir (cp, path)
  cp.completions = {}

  -- Normalize path, and abort if it fails
  path = normalize_path (path)
  if not path then
    return false
  end

  -- Split up path with dirname and basename, unless it ends in `/',
  -- in which case it's considered to be entirely dirname.
  local pdir, base
  if path[-1] ~= "/" then
    pdir = posix.dirname (path)
    if pdir ~= "/" then
      pdir = pdir .. "/"
    end
    base = posix.basename (path)
  else
    pdir = path
    base = ""
  end

  local dir = posix.dir (pdir)
  if dir then
    local buf = ""
    for _, d in ipairs (dir) do
      local s = posix.stat (pdir .. d)
      if s and s.type == "directory" then
        d = d .. "/"
      end
      table.insert (cp.completions, d)
    end

    cp.path = compact_path (pdir)
  end

  return base
end

-- Match completions
--
-- cp - the completions
-- search - the prefix to search for
--
-- Returns the base of the search string (the same as the search
-- string except for a filename completion, where it is the basename
-- of the path).
--
-- The effect on cp is as follows:
--
--   cp.completions - not modified except for a filename completion,
--     in which case reread
--   cp.matches - replaced with the list of matching completions, sorted
--   cp.match - replaced with the longest common prefix of the matches
--
-- To format the completions for a popup, you should call completion_write
-- after this method.
COMPLETION_NOTMATCHED = 0
COMPLETION_MATCHED = 1
COMPLETION_MATCHEDNONUNIQUE = 2
COMPLETION_NONUNIQUE = 3

function completion_try (cp, search)
  cp.matches = {}

  if cp.filename then
    search = completion_readdir (cp, search)
  end

  for _, v in ipairs (cp.completions) do
    if type (v) == "string" then
      local len = math.min (#v, #search)
      if string.sub (v, 1, len) == string.sub (search, 1, len) then
        table.insert (cp.matches, v)
      end
    end
  end

  table.sort (cp.matches)
  local match = cp.matches[1] or ""
  local prefix_len = #match
  for _, v in ipairs (cp.matches) do
    prefix_len = math.min (prefix_len, common_prefix_length (match, v))
  end
  cp.match = string.sub (match, 1, prefix_len)

  local ret = COMPLETION_NONUNIQUE
  if #cp.matches == 0 then
    ret = COMPLETION_NOTMATCHED
  elseif #cp.matches == 1 then
    ret = COMPLETION_MATCHED
  elseif #cp.matches > 1 then
    local len = math.min (#search, #cp.match)
    if string.sub (cp.match, 1, len) == string.sub (search, 1, len) then
      ret = COMPLETION_MATCHEDNONUNIQUE
    end
  end

  return ret, search
end
