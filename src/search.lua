-- Search and replace functions
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

-- Return true if there are no upper-case letters in the given string.
-- If `regex' is true, ignore escaped letters.
local function no_upper (s, regex)
  local quote_flag = false
  for i = 1, #s do
    if regex and s[i] == '\\' then
      quote_flag = not quote_flag
    elseif not quote_flag and s[i] == string.upper (s[i]) then
      return false
    end
  end
  return true
end

local re_flags = rex_gnu.flags ()
local re_find_err

local function find_substr (as, s, from, to, forward, notbol, noteol, regex, icase)
  local ret = -1
  local cf = 0

  if not regex then
    cf = bit.bor (cf, re_flags.PLAIN)
  end
  if icase then
    cf = bit.bor (cf, re_flags.ICASE)
  end

  local r, re_find_err = rex_gnu.new (s, cf)
  if r then
    local ef = 0
    if notbol then
      ef = bit.bor (ef, re_flags.not_bol)
    end
    if noteol then
      ef = bit.bor (ef, re_flags.not_eol)
    end
    if not forward then
      ef = bit.bor (ef, re_flags.backward)
    end
    ret = r:find (string.sub (as, from + 1, to), nil, ef)
    if ret then
      ret = ret + from
    end
  end

  return ret
end

local function search (pt, s, forward, regexp)
  local lp = pt.p
  local as = lp.text
  local from, to = 0, #as
  local downcase = get_variable_bool ("case-fold-search") and no_upper (s, regexp)
  local notbol, noteol  = false, false

  if #s < 1 then
    return false
  end

  -- Match first line.
  if forward then
    notbol = pt.o > from
    from = pt.o
  else
    noteol = pt.o < to
    to = pt.o
  end
  local pos = find_substr (as, s, from, to, forward, notbol, noteol, regexp, downcase)

  -- Match following lines.
  while not pos do
    lp = lp[forward and "next" or "prev"]
    if lp == cur_bp.lines then
      break
    end
    as = lp.text
    pos = find_substr (as, s, 0, #as, forward, false, false, regexp, downcase)
  end

  if not pos then
    return false
  end

  while cur_bp.pt.p ~= lp do
    if forward then
      next_line ()
    else
      previous_line ()
    end
  end
  cur_bp.pt.o = pos + (forward and #s or 0) - 1
  thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
  return true
end

local last_search

function do_search (forward, regexp, pattern)
  local ok = leNIL
  local ms

  if not pattern then
    ms = minibuf_read ("%s%s: ", last_search, regexp and "RE search" or "Search", forward and "" or " backward")
    pattern = ms
  end

  if not pattern then
    return execute_function ("keyboard-quit")
  end
  if #pattern > 0 then
    last_search = pattern

    if not search (cur_bp.pt, pattern, forward, regexp) then
      minibuf_error (string.format ("Search failed: \"%s\"", pattern))
    else
      ok = leT
    end
  end

  return ok
end

Defun ("search-forward",
       {"string"},
[[
Search forward from point for the user specified text.
]],
  true,
  function (pattern)
    return do_search (true, false, pattern)
  end
)

Defun ("search-backward",
       {"string"},
[[
Search backward from point for the user specified text.
]],
  true,
  function (pattern)
    return do_search (false, false, pattern)
  end
)

Defun ("search-forward-regexp",
       {"string"},
[[
Search forward from point for regular expression REGEXP.
]],
  true,
  function (pattern)
    return do_search (true, true, pattern)
  end
)

Defun ("search-backward-regexp",
       {"string"},
[[
Search backward from point for match for regular expression REGEXP.
]],
  true,
  function (pattern)
    return do_search (false, true, pattern)
  end
)


-- Incremental search engine.
local function isearch (forward, regexp)
  local c
  local last = true
  local buf = ""
  local pattern = ""
  local old_mark = copy_marker (cur_wp.bp.mark)
  local start = table.clone (cur_bp.pt)
  local cur = table.clone (start)

  -- I-search mode.
  cur_wp.bp.isearch = true

  while true do
    -- Make the minibuf message.
    local buf = string.format ("%sI-search%s: %s",
                               (last and
                                (regexp and "Regexp " or "") or
                                (regexp and "Failing regexp " or "Failing ")),
                               forward and "" or " backward",
                               pattern)

    -- Regex error.
    if re_find_err then
      if string.sub (re_find_err, 1, 10) == "Premature " or
        string.sub (re_find_err, 1, 10) == "Unmatched " or
        string.sub (re_find_err, 1, 8) == "Invalid " then
        re_find_err = "incomplete input"
      end
      buf = string.format (" [%s]", re_find_err)
      re_find_err = nil
    end

    minibuf_write (buf)

    local c = getkey ()

    if c == KBD_CANCEL then
      cur_bp.pt = start
      thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)

      -- Quit.
      execute_function ("keyboard-quit")

      -- Restore old mark position.
      if cur_bp.mark then
        unchain_marker (cur_bp.mark)
      end
      cur_bp.mark = old_mark
      break
    elseif c == KBD_BS then
      if #pattern > 0 then
        pattern = string.sub (pattern, 1, -2)
        cur = table.clone (start)
        cur_bp.pt = table.clone (start)
        thisflag = bit.bor (thisflag, FLAG_NEED_RESYNC)
      else
        ding ()
      end
    elseif bit.band (c, KBD_CTRL) ~= 0 and bit.band (c, 0xff) == string.byte ('q') then
      minibuf_write (string.format ("%s^Q-", buf))
      pattern = pattern .. string.char (xgetkey (GETKEY_UNFILTERED, 0))
    elseif bit.band (c, KBD_CTRL) ~= 0 and (bit.band (c, 0xff) == string.byte ('r') or bit.band (c, 0xff) == string.byte ('s')) then
      -- Invert direction.
      if bit.band (c, 0xff) == string.byte ('r') then
        forward = false
      elseif bit.band (c, 0xff) == string.byte ('s') then
        forward = true
      end
      if #pattern > 0 then
        -- Find next match.
        cur = table.clone (cur_bp.pt)
        -- Save search string.
        last_search = pattern
      elseif last_search then
        pattern = last_search
      end
    elseif bit.band (c, KBD_META) ~= 0 or bit.band (c, KBD_CTRL) ~= 0 or c > KBD_TAB then
      if c == KBD_RET and #pattern == 0 then
        do_search (forward, regexp)
      else
        if #pattern > 0 then
          -- Save mark.
          set_mark ()
          cur_bp.mark.pt = table.clone (start)

          -- Save search string.
          last_search = pattern

          minibuf_write ("Mark saved when search started")
        else
          minibuf_clear ()
        end
        if c ~= KBD_RET then
          ungetkey (c)
        end
      end
      break
    else
      pattern = pattern .. string.char (c)
    end

    if #pattern > 0 then
      last = search (cur, pattern, forward, regexp)
    else
      last = true
    end

    if bit.band (thisflag, FLAG_NEED_RESYNC) ~= 0 then
      resync_redisplay (cur_wp)
    end
  end

  -- done
  cur_wp.bp.isearch = false

  return leT
end

Defun ("isearch-forward",
       {},
[[
Do incremental search forward.
With a prefix argument, do an incremental regular expression search instead.
As you type characters, they add to the search string and are found.
Type return to exit, leaving point at location found.
Type @kbd{C-s} to search again forward, @kbd{C-r} to search again backward.
@kbd{C-g} when search is successful aborts and moves point to starting point.
]],
  true,
  function ()
    return isearch (true, bit.band (lastflag, FLAG_SET_UNIARG) ~= 0)
  end
)

Defun ("isearch-backward",
       {},
[[
Do incremental search backward.
With a prefix argument, do a regular expression search instead.
As you type characters, they add to the search string and are found.
Type return to exit, leaving point at location found.
Type @kbd{C-r} to search again backward, @kbd{C-s} to search again forward.
@kbd{C-g} when search is successful aborts and moves point to starting point.
]],
  true,
  function ()
    return isearch (false, bit.band (lastflag, FLAG_SET_UNIARG) ~= 0)
  end
)

Defun ("isearch-forward-regexp",
       {},
[[
Do incremental search forward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input
is treated as a regexp.  See @kbd{M-x isearch-forward} for more info.
]],
  true,
  function ()
    return isearch (true, bit.band (lastflag, FLAG_SET_UNIARG) == 0)
  end
)

Defun ("isearch-backward-regexp",
       {},
[[
Do incremental search forward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input
is treated as a regexp.  See @kbd{M-x isearch-forward} for more info.
]],
  true,
  function ()
    return isearch (false, bit.band (lastflag, FLAG_SET_UNIARG) ~= 0)
  end
)

Defun ("query-replace",
       {},
[[
Replace occurrences of a string with other text.
As each match is found, the user must type a character saying
what to do with it.
]],
  true,
  function ()
    local ok = leT
    local noask = false
    local count = 0

    local find = minibuf_read ("Query replace string: ", "")

    if not find then
      return execute_function ("keyboard-quit")
    end
    if find == "" then
      return leNIL
    end
    local find_no_upper = no_upper (find, false)

    local repl = minibuf_read (string.format ("Query replace `%s' with: ", find), "")
    if not repl then
      execute_function ("keyboard-quit")
    end

    while search (cur_bp.pt, find, true, false) do
      local c = string.byte (' ')

      if not noask then
        if bit.band (thisflag, FLAG_NEED_RESYNC) ~= 0 then
          resync_redisplay (cur_wp)
        end
        while true do
          minibuf_write (string.format ("Query replacing `%s' with `%s' (y, n, !, ., q)? ", find, repl))
          c = getkey ()
          if c == KBD_CANCEL or c == KBD_RET or c == string.byte (' ') or c == string.byte ('y') or c == string.byte ('n') or c == string.byte ('q') or c == string.byte ('.') or c == string.byte ('!') then
            break
          end
          minibuf_error ("Please answer y, n, !, . or q.")
          waitkey (WAITKEY_DEFAULT)
        end
        minibuf_clear ()

        if c == string.byte ('q') then -- Quit immediately.
          break
        elseif c == KBD_CANCEL then -- C-g
          ok = execute_function ("keyboard-quit")
          break
        elseif c == string.byte ('!') then -- Replace all without asking.
          noask = true
        end
      end

      if c ~= string.byte ('n') and c ~= KBD_RET and c ~= KBD_DEL then -- Do not replace.
        -- Perform replacement.
        count = count + 1
        undo_save (UNDO_REPLACE_BLOCK, make_point (cur_bp.pt.n, cur_bp.pt.o - #find), #find, #repl)
        line_replace_text (cur_bp.pt.p, cur_bp.pt.o - #find, #find, repl, find_no_upper)

        if c == string.byte ('.') then -- Replace and quit.
          break
        end
      end
    end

    if bit.band (thisflag, FLAG_NEED_RESYNC) ~= 0 then
      resync_redisplay (cur_wp)
    end

    if ok then
      minibuf_write (string.format ("Replaced %d occurrence%s", count, count ~= 1 and "s" or ""))
    end
  end
)
