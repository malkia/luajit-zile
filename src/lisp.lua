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

function lisp_read (s)
  local pos = 1
  local function append (l, e)
    if l == nil then
      l = e
    else
      local l2 = l
      while l2.next ~= nil do
        l2 = l2.next
      end
      l2.next = e
    end
    return l
  end
  local function read ()
    local l = nil
    local quoted = false
    repeat
      local tok, tokenid
      tok, tokenid, pos = read_token (s, pos)
      if tokenid == T_QUOTE then
        quoted = true
      else
        if tokenid == T_OPENPAREN then
          l = append (l, {branch = read (), quoted = quoted})
        elseif tokenid == T_WORD then
          l = append (l, {data = tok, quoted = quoted})
        end
        quoted = false
      end
    until tokenid == T_CLOSEPAREN or tokenid == T_EOF
    return l
  end

  return read ()
end

function evaluateBranch (branch)
  if branch == nil or branch.data == nil then
    return nil
  end
  local ret
  if usercmd[branch.data] and type (usercmd[branch.data].func) == "function" then
    ret = usercmd[branch.data].func (branch)
  else
    ret = call_zile_command (branch.data, branch)
  end
  return ret
end

function leEval (list)
  while list do
    evaluateBranch (list.branch)
    list = list.next
  end
end

function evaluateNode (node)
  if node == nil then
    return leNIL
  end
  local value
  if node.branch ~= nil then
    if node.quoted then
      value = node.branch
    else
      value = evaluateBranch (node.branch)
    end
  else
    value = {data = get_variable (node.data) or node.data}
  end
  return value
end

function lisp_loadstring (s)
  leEval (lisp_read (s))
end

function lisp_loadfile (file)
  local h = io.open (file, "r")

  if h then
    lisp_loadstring (h:read ("*a"))
    h:close ()
    return true
  end

  return false
end

Defun {"load",
[[
Execute a file of Lisp code named FILE.
]],
  function (l)
    local ok
    if l and #l >= 2 then
      ok = bool_to_lisp (lisp_loadfile (l.next.data))
    else
      ok = leNIL
    end
  end
}

Defun_noninteractive {"setq",
[[
(setq [sym val]...)

Set each sym to the value of its val.
The symbols sym are variables; they are literal (not evaluated).
The values val are expressions; they are evaluated.
]],
  function (l)
    local ret
    l = l.next
    while l and l.next do
      ret = evaluateNode (l.next)
      set_variable (l.data, ret.data)
      if l.next == nil then
        break
      end
      l = l.next.next
    end
    return ret
  end
}
