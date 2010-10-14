-- Zile Lisp interpreter
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

leT = {data = "t"}
leNIL = {data = "nil"}


-- User commands
usercmd = {}

function Defun (name, argtypes, doc, interactive, func)
  usercmd[name] = {
    doc = doc,
    interactive = interactive,
    func = function (arglist)
             local args = {}
             local i = 1
             while arglist and arglist.next do
               local val = arglist.next
               local ty = argtypes[i]
               if ty == "string" then
                 val = val.data
               elseif ty == "number" then
                 val = tonumber (val.data, 10)
               elseif ty == "boolean" then
                 val = not (val.data == "nil")
               end
               table.insert (args, val)
               arglist = arglist.next
               i = i + 1
             end
             local ret = func (unpack (args))
             if not ret then
               return leNIL
             elseif ret == true then
               return leT
             end
             return ret
           end
  }
end

-- Return function's interactive field, or nil if not found.
function get_function_interactive (name)
  if usercmd[name] then
    return usercmd[name].interactive
  end
end

function get_function_doc (name)
  if usercmd[name] then
    return usercmd[name].doc
  end
end

-- Turn a boolean into a Lisp boolean
function bool_to_lisp (b)
  return b and leT or leNIL
end
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
  return execute_function (branch.data, 1, false, branch)
end

function execute_function (name, uniarg, is_uniarg, list)
  if is_uniarg then
    list = { next = { data = uniarg and tostring (uniarg) or nil }}
  end
  if usercmd[name] and usercmd[name].func then
    if type (usercmd[name].func) == "function" then
      return usercmd[name].func (list)
    else
      return call_zile_c_command (name, is_uniarg, list)
    end
  else
    if macros[name] then
      process_keys (macros[name])
      return leT
    end
    return leNIL
  end
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

Defun ("load",
       {"string"},
[[
Execute a file of Lisp code named FILE.
]],
  true,
  function (file)
    if file then
      return lisp_loadfile (file)
    end
  end
)

Defun ("setq",
       {},
[[
(setq [sym val]...)

Set each sym to the value of its val.
The symbols sym are variables; they are literal (not evaluated).
The values val are expressions; they are evaluated.
]],
  false,
  function (...)
    local ret
    local l = {...}
    for i = 1, #l/2 do
      ret = evaluateNode (l[i + 1])
      set_variable (l[i].data, ret.data)
    end
    return ret
  end
)

function function_exists (f)
  return usercmd[f] ~= nil
end

-- Read a function name from the minibuffer.
functions_history = nil
function minibuf_read_function_name (s)
  local cp = completion_new ()

  for name, func in pairs (usercmd) do
    if func.interactive then
      table.insert (cp.completions, name)
    end
  end
  add_macros_to_list (cp)

  return minibuf_vread_completion (s, "", cp, functions_history,
                                   "No function name given",
                                   "Undefined function name `%s'")
end

function execute_with_uniarg (undo, uniarg, forward, backward)
  local func = forward
  uniarg = uniarg or 1

  if backward and uniarg < 0 then
    func = backward
    uniarg = -uniarg
  end
  if undo then
    undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
  end
  local ret = true
  for uni = 1, uniarg do
    ret = func ()
    if not ret then
      break
    end
  end
  if undo then
    undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  end

  return bool_to_lisp (ret)
end

Defun ("execute-extended-command",
       {"number"},
[[
Read function name, then read its arguments and call it.
]],
  true,
  function (n)
    local name
    local msg = ""

    if bit.band (lastflag, FLAG_SET_UNIARG) ~= 0 then
      if bit.band (lastflag, FLAG_UNIARG_EMPTY) ~= 0 then
        msg = "C-u "
      end
    else
      msg = string.format ("%d ", get_variable_number ("current-prefix-arg"))
    end
    msg = msg .. "M-x "

    name = minibuf_read_function_name (msg)
    if name then
      return execute_function (name, n, true)
    end
  end
)

-- Read a function name from the minibuffer.
local functions_history
function minibuf_read_function_name (fmt)
  local cp = completion_new ()

  for name, func in pairs (usercmd) do
    if func.interactive then
      table.insert (cp.completions, name)
    end
  end
  add_macros_to_list (cp)

  return minibuf_vread_completion (fmt, "", cp, functions_history,
                                   "No function name given",
                                   "Undefined function name `%s'")
end
