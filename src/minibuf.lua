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

files_history = history_new ()

minibuf_contents = nil


-- Minibuffer wrapper functions.

function minibuf_refresh ()
  if cur_wp then
    if minibuf_contents then
      term_minibuf_write (minibuf_contents)
    end

    -- Redisplay (and leave the cursor in the correct position).
    term_redisplay ()
    term_refresh ()
  end
end

-- Clear the minibuffer.
function minibuf_clear ()
  minibuf_write ("")
end

-- Write the specified string in the minibuffer.
function minibuf_write (s)
  minibuf_contents = s
  minibuf_refresh ()
end

-- Write the specified error string in the minibuffer and signal an error.
function minibuf_error (s)
  minibuf_write (s)
  ding ()
end

local function minibuf_test_in_completions (ms, cp)
  for _, v in pairs (cp.completions) do
    if v == ms then
      return true
    end
  end
  return false
end

-- Read a string from the minibuffer using a completion.
function minibuf_vread_completion (fmt, value, cp, hp, empty_err, invalid_err)
  local ms

  while true do
    ms = term_minibuf_read (fmt, value, -1, cp, hp)

    if not ms then -- Cancelled.
      execute_function ("keyboard-quit")
      break
    elseif ms == "" then
      minibuf_error (empty_err)
      ms = nil
      break
    else
      -- Complete partial words if possible.
      local comp = completion_try (cp, ms)
      if comp == COMPLETION_MATCHED then
        ms = cp.match
      elseif comp == COMPLETION_NONUNIQUE then
        popup_completion (cp)
      end

      if minibuf_test_in_completions (ms, cp) then
        if hp then
          add_history_element (hp, ms)
        end
        minibuf_clear ()
        break
      else
        minibuf_error (string.format (invalid_err, ms))
        waitkey (WAITKEY_DEFAULT)
      end
    end
  end

  return ms
end

-- Read a filename from the minibuffer.
function minibuf_read_filename (fmt, value, file)
  local p

  local as = value
  if normalize_path (as) then
    as = compact_path (as)

    local pos = #as
    if file then
      pos  = pos - #file
    end
    p = term_minibuf_read (fmt, as, pos, completion_new (), files_history)

    if p then
      local as = p
      if normalize_path (as) then
        add_history_element (files_history, p)
      else
        p = nil
      end
    end
  end

  return p
end

function minibuf_read_yesno (fmt)
  local errmsg = "Please answer yes or no."
  local ret = nil

  local cp = completion_new ()
  cp.completions = {"no", "yes"}
  local ms = minibuf_vread_completion (fmt, "", cp, nil, errmsg, errmsg)

  if ms then
    ret = ms == "yes"
  end

  return ret
end

function minibuf_read_yn (fmt)
  local errmsg = ""

  while true do
    minibuf_write (errmsg .. fmt)
    local key = getkey ()
    if key == string.byte ('y') then
      return true
    elseif key == string.byte ('n') then
      return false
    elseif key == bit.bor (KBD_CTRL, string.byte ('g')) then
      return -1
    else
      errmsg = "Please answer y or n.  "
    end
  end
end

-- Read a string from the minibuffer.
function minibuf_read (fmt, value)
  return term_minibuf_read (fmt, value or "", -1)
end

-- Read a non-negative number from the minibuffer.
function minibuf_read_number (fmt)
  local n
  repeat
    local ms = minibuf_read (fmt, "")
      if not ms then
        execute_function ("keyboard-quit")
        break
      elseif #ms == 0 then
        n = ""
      else
        n = tonumber (ms, 10)
      end
      if not n then
        minibuf_write ("Please enter a number.")
      end
  until n

  return n
end

-- FIXME: Make all callers use history
function minibuf_read_completion (fmt, value, cp, hp)
  return term_minibuf_read (fmt, value, -1, cp, hp)
end
