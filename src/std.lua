-- Lua stdlib
--
-- Copyright (c) 2000-2010 stdlib authors.
--
-- See http://luaforge.net/projects/stdlib/ for more information.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
-- THE SOFTWARE.

local function require (f)
  package.loaded[f] = true
end
--
-- strict.lua
-- checks uses of undeclared global variables
-- All global variables must be 'declared' through a regular assignment
-- (even assigning nil will do) in a main chunk before being used
-- anywhere or assigned to inside a function.
--
-- From Lua distribution (etc/strict.lua)
--

local getinfo, error, rawset, rawget = debug.getinfo, error, rawset, rawget

local mt = getmetatable(_G)
if mt == nil then
  mt = {}
  setmetatable(_G, mt)
end

mt.__declared = {}

local function what ()
  local d = getinfo(3, "S")
  return d and d.what or "C"
end

mt.__newindex = function (t, n, v)
  if not mt.__declared[n] then
    local w = what()
    if w ~= "main" and w ~= "C" then
      error("assign to undeclared variable '"..n.."'", 2)
    end
    mt.__declared[n] = true
  end
  rawset(t, n, v)
end

mt.__index = function (t, n)
  if not mt.__declared[n] and what() ~= "C" then
    error("variable '"..n.."' is not declared", 2)
  end
  return rawget(t, n)
end

-- @module base
-- Adds to the existing global functions

module ("base", package.seeall)

-- Functional forms of infix operators
-- Defined here so that other modules can write to it.
_G.op = {}

require "table_ext"
require "list"
require "string_ext"
--require "io_ext" FIXME: allow loops


-- @func metamethod: Return given metamethod, if any, or nil
--   @param x: object to get metamethod of
--   @param n: name of metamethod to get
-- @returns
--   @param m: metamethod function or nil if no metamethod or not a
--     function
function _G.metamethod (x, n)
  local _, m = pcall (function (x)
                        return getmetatable (x)[n]
                      end,
                      x)
  if type (m) ~= "function" then
    m = nil
  end
  return m
end

-- @func render: Turn tables into strings with recursion detection
-- N.B. Functions calling render should not recurse, or recursion
-- detection will not work
--   @param x: object to convert to string
--   @param open: open table renderer
--     @t: table
--   @returns
--     @s: open table string
--   @param close: close table renderer
--     @t: table
--   @returns
--     @s: close table string
--   @param elem: element renderer
--     @e: element
--   @returns
--     @s: element string
--   @param pair: pair renderer
--     N.B. this function should not try to render i and v, or treat
--     them recursively
--     @t: table
--     @i: index
--     @v: value
--     @is: index string
--     @vs: value string
--   @returns
--     @s: element string
--   @param sep: separator renderer
--     @t: table
--     @i: preceding index (nil on first call)
--     @v: preceding value (nil on first call)
--     @j: following index (nil on last call)
--     @w: following value (nil on last call)
--   @returns
--     @s: separator string
-- @returns
--   @param s: string representation
function _G.render (x, open, close, elem, pair, sep, roots)
  local function stopRoots (x)
    if roots[x] then
      return roots[x]
    else
      return render (x, open, close, elem, pair, sep, table.clone (roots))
    end
  end
  roots = roots or {}
  local s
  if type (x) ~= "table" or metamethod (x, "__tostring") then
    s = elem (x)
  else
    s = open (x)
    roots[x] = elem (x)
    local i, v = nil, nil
    for j, w in pairs (x) do
      s = s .. sep (x, i, v, j, w) .. pair (x, j, w, stopRoots (j), stopRoots (w))
      i, v = j, w
    end
    s = s .. sep(x, i, v, nil, nil) .. close (x)
  end
  return s
end

-- @func tostring: Extend tostring to work better on tables
--   @param x: object to convert to string
-- @returns
--   @param s: string representation
_G._tostring = tostring -- make original tostring available
local _tostring = tostring
function _G.tostring (x)
  return render (x,
                 function () return "{" end,
                 function () return "}" end,
                 _tostring,
                 function (t, _, _, i, v)
                   return i .. "=" .. v
                 end,
                 function (_, i, _, j)
                   if i and j then
                     return ","
                   end
                   return ""
                 end)
end

-- @func prettytostring: pretty-print a table
--   @t: table to print
--   @indent: indent between levels ["\t"]
--   @spacing: space before every line
-- @returns
--   @s: pretty-printed string
function _G.prettytostring (t, indent, spacing)
  indent = indent or "\t"
  spacing = spacing or ""
  return render (t,
                 function ()
                   local s = spacing .. "{"
                   spacing = spacing .. indent
                   return s
                 end,
                 function ()
                   spacing = string.gsub (spacing, indent .. "$", "")
                   return spacing .. "}"
                 end,
                 function (x)
                   if type (x) == "string" then
                     return string.format ("%q", x)
                   else
                     return tostring (x)
                   end
                 end,
                 function (x, i, v, is, vs)
                   local s = spacing .. "["
                   if type (i) == "table" then
                     s = s .. "\n"
                   end
                   s = s .. is
                   if type (i) == "table" then
                     s = s .. "\n"
                   end
                   s = s .. "] ="
                   if type (v) == "table" then
                     s = s .. "\n"
                   else
                     s = s .. " "
                   end
                   s = s .. vs
                   return s
                 end,
                 function (_, i)
                   local s = "\n"
                   if i then
                     s = "," .. s
                   end
                   return s
                 end)
end

-- @func totable: Turn an object into a table according to __totable
-- metamethod
--   @param x: object to turn into a table
-- @returns
--   @param t: table or nil
function _G.totable (x)
  local m = metamethod (x, "__totable")
  if m then
    return m (x)
  elseif type (x) == "table" then
    return x
  else
    return nil
  end
end

-- @func pickle: Convert a value to a string
-- The string can be passed to dostring to retrieve the value
-- TODO: Make it work for recursive tables
--   @param x: object to pickle
-- @returns
--   @param s: string such that eval (s) is the same value as x
function _G.pickle (x)
  if type (x) == "string" then
    return string.format ("%q", x)
  elseif type (x) == "number" or type (x) == "boolean" or
    type (x) == "nil" then
    return tostring (x)
  else
    x = totable (x) or x
    if type (x) == "table" then
      local s, sep = "{", ""
      for i, v in pairs (x) do
        s = s .. sep .. "[" .. pickle (i) .. "]=" .. pickle (v)
        sep = ","
      end
      s = s .. "}"
      return s
    else
      die ("cannot pickle " .. tostring (x))
    end
  end
end

-- @func id: Identity
--   @param ...
-- @returns
--   @param ...: the arguments passed to the function
function _G.id (...)
  return ...
end

-- @func pack: Turn a tuple into a list
--   @param ...: tuple
-- @returns
--   @param l: list
function _G.pack (...)
  return {...}
end

-- @func bind: Partially apply a function
--   @param f: function to apply partially
--   @param a1 ... an: arguments to bind
-- @returns
--   @param g: function with ai already bound
function _G.bind (f, ...)
  local fix = {...}
  return function (...)
           return f (unpack (list.concat (fix, {...})))
         end
end

-- @func curry: Curry a function
--   @param f: function to curry
--   @param n: number of arguments
-- @returns
--   @param g: curried version of f
function _G.curry (f, n)
  if n <= 1 then
    return f
  else
    return function (x)
             return curry (bind (f, x), n - 1)
           end
  end
end

-- @func compose: Compose functions
--   @param f1 ... fn: functions to compose
-- @returns
--   @param g: composition of f1 ... fn
--     @param args: arguments
--   @returns
--     @param f1 (...fn (args)...)
function _G.compose (...)
  local arg = {...}
  local fns, n = arg, #arg
  return function (...)
           local arg = {...}
           for i = n, 1, -1 do
             arg = {fns[i] (unpack (arg))}
           end
           return unpack (arg)
         end
end

-- @func eval: Evaluate a string
--   @param s: string
-- @returns
--   @param v: value of string
function _G.eval (s)
  return loadstring ("return " .. s)()
end

-- @func ripairs: An iterator like ipairs, but in reverse
--   @param t: table to iterate over
-- @returns
--   @param f: iterator function
--     @param t: table
--     @param n: index
--   @returns
--     @param i: index (n - 1)
--     @param v: value (t[n - 1])
--   @param t: the table, as above
--   @param n: #t + 1
function _G.ripairs (t)
  return function (t, n)
           n = n - 1
           if n > 0 then
             return n, t[n]
           end
         end,
  t, #t + 1
end

-- @func nodes: tree iterator
--   @param tr: tree to iterate over
-- @returns
--   @param f: iterator function
--     @param n: current node
--     @param p: path to node within the tree
--   @yields
--     @param ty: type ("leaf", "branch" (pre-order) or "join" (post-order))
--     @param p_: path to node ({i1...ik})
--     @param n_: node
function _G.nodes (tr)
  local function visit (n, p)
    if type (n) == "table" then
      coroutine.yield ("branch", p, n)
      for i, v in pairs (n) do
        table.insert (p, i)
        visit (v, p)
        table.remove (p)
      end
      coroutine.yield ("join", p, n)
    else
      coroutine.yield ("leaf", p, n)
    end
  end
  return coroutine.wrap (visit), tr, {}
end

-- @func collect: collect the results of an iterator
--   @param i: iterator
--   @param ...: arguments
-- @returns
--   @t: results of running the iterator on its arguments
function _G.collect (i, ...)
  local t = {}
  for e in i (...) do
    table.insert (t, e)
  end
  return t
end

-- @func map: Map a function over an iterator
--   @param f: function
--   @param i: iterator
--   @param ...: iterator's arguments
-- @returns
--   @param t: result table
function _G.map (f, i, ...)
  local t = {}
  for e in i (...) do
    local r = f (e)
    if r then
      table.insert (t, r)
    end
  end
  return t
end

-- @func filter: Filter an iterator with a predicate
--   @param p: predicate
--   @param i: iterator
--   @param ...:
-- @returns
--   @param t: result table containing elements e for which p (e)
function _G.filter (p, i, ...)
  local t = {}
  for e in i (...) do
    if p (e) then
      table.insert (t, e)
    end
  end
  return t
end

-- @func fold: Fold a binary function into an iterator
--   @param f: function
--   @param d: initial first argument
--   @param i: iterator
--   @param ...:
-- @returns
--   @param r: result
function _G.fold (f, d, i, ...)
  local r = d
  for e in i (...) do
    r = f (r, e)
  end
  return r
end

-- @func assert: Extend to allow formatted arguments
--   @param v: value
--   @param f, ...: arguments to format
-- @returns
--   @param v: value
function _G.assert (v, f, ...)
  if not v then
    if f == nil then
      f = ""
    end
    error (string.format (f, ...))
  end
  return v
end

-- @func warn: Give warning with the name of program and file (if any)
--   @param ...: arguments for format
function _G.warn (...)
  if prog.name then
    io.stderr:write (prog.name .. ":")
  end
  if prog.file then
    io.stderr:write (prog.file .. ":")
  end
  if prog.line then
    io.stderr:write (tostring (prog.line) .. ":")
  end
  if prog.name or prog.file or prog.line then
    io.stderr:write (" ")
  end
  io.writeLine (io.stderr, string.format (...))
end

-- @func die: Die with error
--   @param ...: arguments for format
function _G.die (...)
  warn (unpack (arg))
  error ()
end

-- Function forms of operators
_G.op["[]"] =
  function (t, s)
    return t[s]
  end

_G.op["+"] =
  function (a, b)
    return a + b
  end
_G.op["-"] =
  function (a, b)
    return a - b
  end
_G.op["*"] =
  function (a, b)
    return a * b
  end
_G.op["/"] =
  function (a, b)
    return a / b
  end
_G.op["and"] =
  function (a, b)
    return a and b
  end
_G.op["or"] =
  function (a, b)
    return a or b
  end
_G.op["not"] =
  function (a)
    return not a
  end
_G.op["=="] =
  function (a, b)
    return a == b
  end
_G.op["~="] =
  function (a, b)
    return a ~= b
  end

-- @module debug

-- Adds to the existing debug module

module ("debug", package.seeall)

require "io_ext"
require "string_ext"

-- Debugging is off by default
_G._DEBUG = nil

-- To activate debugging set _DEBUG either to any true value
-- (equivalent to {level = 1}), or a table with the following members:

-- level: debugging level
-- call: do call trace debugging
-- std: do standard library debugging (run examples & test code)


-- @func say: Print a debugging message
--   @param [n]: debugging level [1]
--   ...: objects to print (as for print)
function say (...)
  local level = 1
  local arg = {...}
  if type (arg[1]) == "number" then
    level = arg[1]
    table.remove (arg, 1)
  end
  if _DEBUG and
    ((type (_DEBUG) == "table" and type (_DEBUG.level) == "number" and
      _DEBUG.level >= level)
       or level <= 1) then
    io.writeLine (io.stderr, table.concat (list.map (tostring, arg), "\t"))
  end
end

-- Expose say as global function `debug'
getmetatable (_M).__call =
   function (self, ...)
     say (...)
   end

-- @func traceCall: Trace function calls
--   @param event: event causing the call
-- Use: debug.sethook (trace, "cr"), as below
-- based on test/trace-calls.lua from the Lua distribution
local level = 0
function trace (event)
  local t = getinfo (3)
  local s = " >>> " .. string.rep (" ", level)
  if t ~= nil and t.currentline >= 0 then
    s = s .. t.short_src .. ":" .. t.currentline .. " "
  end
  t = getinfo (2)
  if event == "call" then
    level = level + 1
  else
    level = math.max (level - 1, 0)
  end
  if t.what == "main" then
    if event == "call" then
      s = s .. "begin " .. t.short_src
    else
      s = s .. "end " .. t.short_src
    end
  elseif t.what == "Lua" then
    s = s .. event .. " " .. (t.name or "(Lua)") .. " <" ..
      t.linedefined .. ":" .. t.short_src .. ">"
  else
    s = s .. event .. " " .. (t.name or "(C)") .. " [" .. t.what .. "]"
  end
  io.writeLine (io.stderr, s)
end

-- Set hooks according to _DEBUG
if type (_DEBUG) == "table" and _DEBUG.call then
  sethook (trace, "cr")
end

-- @module table

module ("table", package.seeall)

--require "list" FIXME: allow require loops

-- FIXME: use consistent name for result table: t_? (currently r and
-- u)


-- @func sort: Make table.sort return its result
--   @param t: table
--   @param c: comparator function
-- @returns
--   @param t: sorted table
local _sort = sort
function sort (t, c)
  _sort (t, c)
  return t
end

-- @func empty: Say whether table is empty
--   @param t: table
-- @returns
--   @param f: true if empty or false otherwise
function empty (t)
  return not next (t)
end

-- @func size: Find the number of elements in a table
--   @param t: table
-- @returns
--   @param n: number of elements in t
function size (t)
  local n = 0
  for _ in pairs (t) do
    n = n + 1
  end
  return n
end

-- @func indices: Make the list of indices of a table
--   @param t: table
-- @returns
--   @param u: list of indices
function indices (t)
  local u = {}
  for i, v in pairs (t) do
    insert (u, i)
  end
  return u
end

-- @func values: Make the list of values of a table
--   @param t: table
-- @returns
--   @param u: list of values
function values (t)
  local u = {}
  for i, v in pairs (t) do
    insert (u, v)
  end
  return u
end

-- @func invert: Invert a table
--   @param t: table {i=v...}
-- @returns
--   @param u: inverted table {v=i...}
function invert (t)
  local u = {}
  for i, v in pairs (t) do
    u[v] = i
  end
  return u
end

-- @func rearrange: Rearrange some indices of a table
--   @param m: table {oldindex=newindex...}
--   @param t: table to rearrange
-- @returns
--   @param r: rearranged table
function rearrange (m, t)
  local r = clone (t)
  for i, v in pairs (m) do
    r[v] = t[i]
    r[i] = nil
  end
  return r
end

-- @func clone: Make a shallow copy of a table, including any
-- metatable
--   @param t: table
--   @param nometa: if non-nil don't copy metatable
-- @returns
--   @param u: copy of table
function clone (t, nometa)
  local u = {}
  if not nometa then
    setmetatable (u, getmetatable (t))
  end
  for i, v in pairs (t) do
    u[i] = v
  end
  return u
end

-- @func merge: Merge two tables
-- If there are duplicate fields, u's will be used. The metatable of
-- the returned table is that of t
--   @param t, u: tables
-- @returns
--   @param r: the merged table
function merge (t, u)
  local r = clone (t)
  for i, v in pairs (u) do
    r[i] = v
  end
  return r
end

-- @func new: Make a table with a default entry value
--   @param [x]: default entry value [nil]
--   @param [t]: initial table [{}]
-- @returns
--   @param u: table for which u[i] is x if u[i] does not exist
function new (x, t)
  return setmetatable (t or {},
                       {__index = function (t, i)
                                    return x
                                  end})
end

-- @module list

module ("list", package.seeall)

require "base"
require "table_ext"


-- @func elems: An iterator over the elements of a list
--   @param l: list to iterate over
-- @returns
--   @param f: iterator function
--     @param l: list
--     @param n: index
--   @returns
--     @param v: value (l[n - 1])
--   @param l: the list, as above
--   @param 0
function elems (l)
  local n = 0
  return function (l)
           n = n + 1
           if n <= #l then
             return l[n]
           end
         end,
  l, true
end

-- @func relems: An iterator over the elements of a list, in reverse
--   @param l: list to iterate over
-- @returns
--   @param f: iterator function
--     @param l: list
--     @param n: index
--   @returns
--     @param v: value (l[n - 1))
--   @param l: the list, as above
--   @param n: #l + 1
function relems (l)
  local n = #l + 1
  return function (l)
           n = n - 1
           if n > 0 then
             return l[n]
           end
         end,
  l, true
end

-- @func map: Map a function over a list
--   @param f: function
--   @param l: list
-- @returns
--   @param m: result list {f (l[1]), ..., f (l[#l])}
function map (f, l)
  return _G.map (f, elems, l)
end

-- @func mapWith: Map a function over a list of lists
--   @param f: function
--   @param ls: list of lists
-- @returns
--   @param m: result list {f (unpack (ls[1]))), ...,
--     f (unpack (ls[#ls]))}
function mapWith (f, l)
  return _G.map (compose (f, unpack), elems, l)
end

-- @func filter: Filter a list according to a predicate
--   @param p: predicate
--     @param a: argument
--   @returns
--     @param f: flag
--   @param l: list of lists
-- @returns
--   @param m: result list containing elements e of l for which p (e)
--     is true
function filter (p, l)
  return _G.filter (p, elems, l)
end

-- @func slice: Slice a list
--   @param l: list
--   @param [from], @param [to]: start and end of slice
--     from defaults to 1 and to to #l;
--     negative values count from the end
-- @returns
--   @param m: {l[from], ..., l[to]}
function slice (l, from, to)
  local m = {}
  local len = #l
  from = from or 1
  to = to or len
  if from < 0 then
    from = from + len + 1
  end
  if to < 0 then
    to = to + len + 1
  end
  for i = from, to do
    table.insert (m, l[i])
  end
  return m
end

-- @func tail: Return a list with its first element removed
--   @param l: list
-- @returns
--   @param m: {l[2], ..., l[#l]}
function tail (l)
  return slice (l, 2)
end

-- @func foldl: Fold a binary function through a list left
-- associatively
--   @param f: function
--   @param e: element to place in left-most position
--   @param l: list
-- @returns
--   @param r: result
function foldl (f, e, l)
  return _G.fold (f, e, elems, l)
end

-- @func foldr: Fold a binary function through a list right
-- associatively
--   @param f: function
--   @param e: element to place in right-most position
--   @param l: list
-- @returns
--   @param r: result
function foldr (f, e, l)
  return _G.fold (function (x, y) return f (y, x) end,
                  e, relems, l)
end

-- @func cons: Prepend an item to a list
--   @param x: item
--   @param l: list
-- @returns
--   @param r: {x, unpack (l)}
function cons (x, l)
  return {x, unpack (l)}
end

-- @func append: Append an item to a list
--   @param x: item
--   @param l: list
-- @returns
--   @param r: {l[1], ..., l[#l], x}
function append (x, l)
  local r = {unpack (l)}
  table.insert (r, x)
  return r
end

-- @func concat: Concatenate lists
--   @param l1, l2, ... ln: lists
-- @returns
--   @param r: result {l1[1], ..., l1[#l1], ...,
--                     ln[1], ..., ln[#ln]}
function concat (...)
  local r = {}
  for _, l in ipairs ({...}) do
    for _, v in ipairs (l) do
      table.insert (r, v)
    end
  end
  return r
end

-- @func rep: Repeat a list
--   @param n: number of times to repeat
--   @param l: list
-- @returns
--   @param r: n copies of l appended together
function rep (n, l)
  local r = {}
  for i = 1, n do
    r = list.concat (r, l)
  end
  return r
end

-- @func reverse: Reverse a list
--   @param l: list
-- @returns
--   @param m: list {l[#l], ..., l[1]}
function reverse (l)
  local m = {}
  for i = #l, 1, -1 do
    table.insert (m, l[i])
  end
  return m
end

-- @func transpose: Transpose a list of lists
--   @param ls: {{l11, ..., l1c}, ..., {lr1, ..., lrc}}
-- @returns
--   @param ms: {{l11, ..., lr1}, ..., {l1c, ..., lrc}}
-- This function is equivalent to zip and unzip in more strongly typed
-- languages
function transpose (ls)
  local ms, len = {}, #ls
  for i = 1, math.max (unpack (map (table.getn, ls))) do
    ms[i] = {}
    for j = 1, len do
      ms[i][j] = ls[j][i]
    end
  end
  return ms
end

-- @func zipWith: Zip lists together with a function
--   @param f: function
--   @param ls: list of lists
-- @returns
--   @param m: {f (ls[1][1], ..., ls[#ls][1]), ...,
--              f (ls[1][N], ..., ls[#ls][N])
--     where N = max {map (table.getn, ls)}
function zipWith (f, ls)
  return mapWith (f, zip (ls))
end

-- @func project: Project a list of fields from a list of tables
--   @param f: field to project
--   @param l: list of tables
-- @returns
--   @param m: list of f fields
function project (f, l)
  return map (function (t) return t[f] end, l)
end

-- @func enpair: Turn a table into a list of pairs
-- FIXME: Find a better name
--   @param t: table {i1=v1, ..., in=vn}
-- @returns
--   @param ls: list {{i1, v1}, ..., {in, vn}}
function enpair (t)
  local ls = {}
  for i, v in pairs (t) do
    table.insert (ls, {i, v})
  end
  return ls
end

-- @func depair: Turn a list of pairs into a table
-- FIXME: Find a better name
--   @param ls: list {{i1, v1}, ..., {in, vn}}
-- @returns
--   @param t: table {i1=v1, ..., in=vn}
function depair (ls)
  local t = {}
  for _, v in ipairs (ls) do
    t[v[1]] = v[2]
  end
  return t
end

-- @func flatten: Flatten a list
--   @param l: list to flatten
-- @returns
--   @param m: flattened list
function flatten (l)
  local m = {}
  for _, v in ipairs (l) do
    if type (v) == "table" then
      m = concat (m, flatten (v))
    else
      table.insert (m, v)
    end
  end
  return m
end

-- @func shape: Shape a list according to a list of dimensions
-- Dimensions are given outermost first and items from the original
-- list are distributed breadth first; there may be one 0 indicating
-- an indefinite number. Hence, {0} is a flat list, {1} is a
-- singleton, {2, 0} is a list of two lists, and {0, 2} is a list of
-- pairs.
--   @param s: {d1, ..., dn}
--   @param l: list to reshape
-- @returns
--   @param m: reshaped list
-- Algorithm: turn shape into all +ve numbers, calculating the zero if
-- necessary and making sure there is at most one; recursively walk
-- the shape, adding empty tables until the bottom level is reached at
-- which point add table items instead, using a counter to walk the
-- flattened original list.
function shape (s, l)
  l = flatten (l)
  -- Check the shape and calculate the size of the zero, if any
  local size = 1
  local zero
  for i, v in ipairs (s) do
    if v == 0 then
      if zero then -- bad shape: two zeros
        return nil
      else
        zero = i
      end
    else
      size = size * v
    end
  end
  if zero then
    s[zero] = math.ceil (#l / size)
  end
  local function fill (i, d)
    if d > #s then
      return l[i], i + 1
    else
      local t = {}
      for j = 1, s[d] do
        local e
        e, i = fill (i, d + 1)
        table.insert (t, e)
      end
      return t, i
    end
  end
  return (fill (1, 1))
end

-- @func indexKey: Make an index of a list of tables on a given
-- field
--   @param f: field
--   @param l: list of tables {t1, ..., tn}
-- @returns
--   @param m: index {t1[f]=1, ..., tn[f]=n}
function indexKey (f, l)
  local m = {}
  for i, v in ipairs (l) do
    local k = v[f]
    if k then
      m[k] = i
    end
  end
  return m
end

-- @func indexValue: Copy a list of tables, indexed on a given
-- field
--   @param f: field whose value should be used as index
--   @param l: list of tables {i1=t1, ..., in=tn}
-- @returns
--   @param m: index {t1[f]=t1, ..., tn[f]=tn}
function indexValue (f, l)
  local m = {}
  for i, v in ipairs (l) do
    local k = v[f]
    if k then
      m[k] = v
    end
  end
  return m
end
permuteOn = indexValue

-- @head Metamethods for lists
metatable = {
  -- list .. table = list.concat
  __concat = list.concat,
  -- @func append metamethod
  --   @param l: list
  --   @param e: list element
  -- @returns
  --   @param l_: {l[1], ..., l[#l], e}
  __append =
    function (l, e)
      local l_ = table.clone (l)
      table.insert (l_, e)
      return l_
    end,
}

-- @func new: List constructor
-- Needed in order to use metamethods
--   @param t: list (as a table)
-- @returns
--   @param l: list (with list metamethods)
function new (l)
  return setmetatable (l, metatable)
end

-- Function forms of operators
_G.op[".."] = list.concat

-- @module tree

module ("tree", package.seeall)

require "list"

-- @func new: Make a table into a tree
--   @param t: table
-- @returns
--   @param tr: tree
local metatable = {}
function new (t)
  return setmetatable (t or {}, metatable)
end

-- @func __index: Tree __index metamethod
--   @param tr: tree
--   @param i: non-table, or list of indices {i1 ... in}
-- @returns
--   @param v: tr[i]...[in] if i is a table, or tr[i] otherwise
function metatable.__index (tr, i)
  if type (i) == "table" then
    return list.foldl (op["[]"], tr, i)
  else
    return rawget (tr, i)
  end
end

-- @func __newindex: Tree __newindex metamethod
-- Sets tr[i1]...[in] = v if i is a table, or tr[i] = v otherwise
--   @param tr: tree
--   @param i: non-table, or list of indices {i1 ... in}
--   @param v: value
function metatable.__newindex (tr, i, v)
  if type (i) == "table" then
    for n = 1, #i - 1 do
      if type (tr[i[n]]) ~= "table" then
        tr[i[n]] = tree.new ()
      end
      tr = tr[i[n]]
    end
    rawset (tr, i[#i], v)
  else
    rawset (tr, i, v)
  end
end

-- @func clone: Make a deep copy of a tree, including any
-- metatables
--   @param t: table
--   @param nometa: if non-nil don't copy metatables
-- @returns
--   @param u: copy of table
function clone (t, nometa)
  local r = {}
  if not nometa then
    setmetatable (r, getmetatable (t))
  end
  local d = {[t] = r}
  local function copy (o, x)
    for i, v in pairs (x) do
      if type (v) == "table" then
        if not d[v] then
          d[v] = {}
          if not nometa then
            setmetatable (d[v], getmetatable (v))
          end
          o[i] = copy (d[v], v)
        else
          o[i] = d[v]
        end
      else
        o[i] = v
      end
    end
    return o
  end
  return copy (r, t)
end

-- Prototype-based objects

module ("object", package.seeall)

require "table_ext"


-- Usage:

-- Create an object/class:
--   object/class = prototype {value, ...; field = value ...}
--   An object's metatable is itself.
--   In the initialiser, unnamed values are assigned to the fields
--   given by _init (assuming the default _clone).
--   Private fields and methods start with "_"

-- Access an object field: object.field
-- Call an object method: object:method (...)
-- Call a class method: Class.method (object, ...)

-- Add a field: object.field = x
-- Add a method: function object:method (...) ... end


-- Root object
_G.Object = {
  -- List of fields to be initialised by the
  -- constructor: assuming the default _clone, the
  -- numbered values in an object constructor are
  -- assigned to the fields given in _init
  _init = {},

  -- @func _clone: Object constructor
  --   @param values: initial values for fields in
  --   _init
  -- @returns
  --   @param object: new object
  _clone = function (self, values)
             local object = table.merge (self, table.rearrange (self._init, values))
             return setmetatable (object, object)
           end,

  -- @func __call: Sugar instance creation
  __call = function (...)
             -- First (...) gets first element of list
             return (...)._clone (...)
           end,
}
setmetatable (Object, Object)

-- String

module ("string", package.seeall)


-- TODO: Pretty printing
--
--   (Use in getopt)
--
--   John Hughes's and Simon Peyton Jones's Pretty Printer Combinators
--
--   Based on The Design of a Pretty-printing Library in Advanced
--   Functional Programming, Johan Jeuring and Erik Meijer (eds), LNCS 925
--   http://www.cs.chalmers.se/~rjmh/Papers/pretty.ps
--   Heavily modified by Simon Peyton Jones, Dec 96
--
--   Haskell types:
--   data Doc     list of lines
--   quote :: Char -> Char -> Doc -> Doc    Wrap document in ...
--   (<>) :: Doc -> Doc -> Doc              Beside
--   (<+>) :: Doc -> Doc -> Doc             Beside, separated by space
--   ($$) :: Doc -> Doc -> Doc              Above; if there is no overlap it "dovetails" the two
--   nest :: Int -> Doc -> Doc              Nested
--   punctuate :: Doc -> [Doc] -> [Doc]     punctuate p [d1, ... dn] = [d1 <> p, d2 <> p, ... dn-1 <> p, dn]
--   render      :: Int                     Line length
--               -> Float                   Ribbons per line
--               -> (TextDetails -> a -> a) What to do with text
--               -> a                       What to do at the end
--               -> Doc                     The document
--               -> a                       Result


-- @func __index: Give strings a subscription operator
--   @param s: string
--   @param n: index
-- @returns
--   @param s_: string.sub (s, n, n)
getmetatable ("").__index =
  function (s, n)
    if type (n) == "number" then
      return sub (s, n, n)
    end
  end

-- @func __append: Give strings an append metamethod
--   @param s: string
--   @param c: character (1-character string)
-- @returns
--   @param s_: s .. c
getmetatable ("").__append =
  function (s, c)
    return s .. c
  end

-- @func caps: Capitalise each word in a string
--   @param s: string
-- @returns
--   @param s_: capitalised string
function caps (s)
  return (gsub (s, "(%w)([%w]*)",
                function (l, ls)
                  return upper (l) .. ls
                end))
end

-- @func chomp: Remove any final newline from a string
--   @param s: string to process
-- @returns
--   @param s_: processed string
function chomp (s)
  return (gsub (s, "\n$", ""))
end

-- @func escapePattern: Escape a string to be used as a pattern
--   @param s: string to process
-- @returns
--   @param s_: processed string
function escapePattern (s)
  return (gsub (s, "(%W)", "%%%1"))
end

-- @param escapeShell: Escape a string to be used as a shell token
-- Quotes spaces, parentheses, brackets, quotes, apostrophes and \s
--   @param s: string to process
-- @returns
--   @param s_: processed string
function escapeShell (s)
  return (gsub (s, "([ %(%)%\\%[%]\"'])", "\\%1"))
end

-- @func ordinalSuffix: Return the English suffix for an ordinal
--   @param n: number of the day
-- @returns
--   @param s: suffix
function ordinalSuffix (n)
  n = math.mod (n, 100)
  local d = math.mod (n, 10)
  if d == 1 and n ~= 11 then
    return "st"
  elseif d == 2 and n ~= 12 then
    return "nd"
  elseif d == 3 and n ~= 13 then
    return "rd"
  else
    return "th"
  end
end

-- @func format: Extend to work better with one argument
-- If only one argument is passed, no formatting is attempted
--   @param f: format
--   @param ...: arguments to format
-- @returns
--   @param s: formatted string
local _format = format
function format (f, arg1, ...)
  if arg1 == nil then
    return f
  else
    return _format (f, arg1, ...)
  end
end

-- @func pad: Justify a string
-- When the string is longer than w, it is truncated (left or right
-- according to the sign of w)
--   @param s: string to justify
--   @param w: width to justify to (-ve means right-justify; +ve means
--     left-justify)
--   @param [p]: string to pad with [" "]
-- @returns
--   s_: justified string
function pad (s, w, p)
  p = rep (p or " ", abs (w))
  if w < 0 then
    return sub (p .. s, -w)
  end
  return sub (s .. p, 1, w)
end

-- @func wrap: Wrap a string into a paragraph
--   @param s: string to wrap
--   @param w: width to wrap to [78]
--   @param ind: indent [0]
--   @param ind1: indent of first line [ind]
-- @returns
--   @param s_: wrapped paragraph
function wrap (s, w, ind, ind1)
  w = w or 78
  ind = ind or 0
  ind1 = ind1 or ind
  assert (ind1 < w and ind < w,
          "the indents must be less than the line width")
  s = rep (" ", ind1) .. s
  local lstart, len = 1, len (s)
  while len - lstart > w - ind do
    local i = lstart + w - ind
    while i > lstart and sub (s, i, i) ~= " " do
      i = i - 1
    end
    local j = i
    while j > lstart and sub (s, j, j) == " " do
      j = j - 1
    end
    s = sub (s, 1, j) .. "\n" .. rep (" ", ind) ..
      sub (s, i + 1, -1)
    local change = ind + 1 - (i - j)
    lstart = j + change
    len = len + change
  end
  return s
end

-- @func numbertosi: Write a number using SI suffixes
-- The number is always written to 3 s.f.
--   @param n: number
-- @returns
--   @param n_: string
function numbertosi (n)
  local SIprefix = {
    [-8] = "y", [-7] = "z", [-6] = "a", [-5] = "f",
    [-4] = "p", [-3] = "n", [-2] = "mu", [-1] = "m",
    [0] = "", [1] = "k", [2] = "M", [3] = "G",
    [4] = "T", [5] = "P", [6] = "E", [7] = "Z",
    [8] = "Y"
  }
  local t = format("% #.2e", n)
  local _, _, m, e = t:find(".(.%...)e(.+)")
  local man, exp = tonumber (m), tonumber (e)
  local siexp = math.floor (exp / 3)
  local shift = exp - siexp * 3
  local s = SIprefix[siexp] or "e" .. tostring (siexp)
  man = man * (10 ^ shift)
  return tostring (man) .. s
end

-- @func findl: Do find, returning captures as a list
--   @param s: target string
--   @param p: pattern
--   @param [init]: start position [1]
--   @param [plain]: inhibit magic characters [nil]
-- @returns
--   @param from, to: start and finish of match
--   @param capt: table of captures
function findl (s, p, init, plain)
  local function pack (from, to, ...)
    return from, to, {...}
  end
  return pack (p.find (s, p, init, plain))
end

-- @func finds: Do multiple find's on a string
--   @param s: target string
--   @param p: pattern
--   @param [init]: start position [1]
--   @param [plain]: inhibit magic characters [nil]
-- @returns
--   @param l: list of {from, to; capt = {captures}}
function finds (s, p, init, plain)
  init = init or 1
  local l = {}
  local from, to, r
  repeat
    from, to, r = findl (s, p, init, plain)
    if from ~= nil then
      table.insert (l, {from, to, capt = r})
      init = to + 1
    end
  until not from
  return l
end

-- @func gsubs: Perform multiple calls to gsub
--   @param s: string to call gsub on
--   @param sub: {pattern1=replacement1 ...}
--   @param [n]: upper limit on replacements [infinite]
-- @returns
--   @param s_: result string
--   @param r: number of replacements made
function gsubs (s, sub, n)
  local r = 0
  for i, v in pairs (sub) do
    local rep
    if n ~= nil then
      s, rep = gsub (s, i, v, n)
      r = r + rep
      n = n - rep
      if n == 0 then
        break
      end
    else
      s, rep = i.gsub (s, i, v)
      r = r + rep
    end
  end
  return s, r
end

-- FIXME: Consider Perl and Python versions.
-- @func split: Split a string at a given separator
--   @param sep: separator regex
--   @param s: string to split
-- @returns
--   @param l: list of strings
function split (sep, s)
  -- finds gets a list of {from, to, capt = {}} lists; we then
  -- flatten the result, discarding the captures, and prepend 0 (1
  -- before the first character) and append 0 (1 after the last
  -- character), and then read off the result in pairs.
  local pairs = list.concat ({0}, list.flatten (finds (s, sep)), {0})
  local l = {}
  for i = 1, #pairs, 2 do
    table.insert (l, sub (s, pairs[i] + 1, pairs[i + 1] - 1))
  end
  return l
end

-- @func ltrim: Remove leading matter from a string
--   @param [r]: leading regex ["%s+"]
--   @param s: string
-- @returns
--   @param s_: string without leading r
function ltrim (r, s)
  if s == nil then
    s, r = r, "%s+"
  end
  return (r.gsub (s, "^" .. r, ""))
end

-- @func rtrim: Remove trailing matter from a string
--   @param [r]: trailing regex ["%s+"]
--   @param s: string
-- @returns
--   @param s_: string without trailing r
function rtrim (r, s)
  if s == nil then
    s, r = r, "%s+"
  end
  return (r.gsub (s, r .. "$", ""))
end

-- @func trim: Remove leading and trailing matter from a string
--   @param [r]: leading/trailing regex ["%s+"]
--   @param s: string
-- @returns
--   @param s_: string without leading/trailing r
function trim (r, s)
  return ltrim (rtrim (r, s))
end

-- Math

-- Adds to the existing math module

module ("math", package.seeall)


local _floor = floor

-- @func floor: Extend to take the number of decimal places
--   @param n: number
--   @param [p]: number of decimal places to truncate to [0]
-- @returns
--   @param r: n truncated to p decimal places
function floor (n, p)
  local e = 10 ^ (p or 0)
  return _floor (n * e) / e
end

-- @func round: Round a number to p decimal places
--   @param n: number
--   @param [p]: number of decimal places to truncate to [0]
-- @returns
--   @param r: n to p decimal places
function round (n, p)
  local e = 10 ^ (p or 0)
  return _floor (n * e + 0.5) / e
end

-- I/O

module ("io", package.seeall)

require "base"


-- @func readLines: Read a file into a list of lines and close it
--   @param [h]: file handle or name [io.input ()]
-- @returns
--   @param l: list of lines
function readLines (h)
  if h == nil then
    h = input ()
  elseif _G.type (h) == "string" then
    h = io.open (h)
  end
  local l = {}
  for line in h:lines () do
    table.insert (l, line)
  end
  h:close ()
  return l
end

-- @func writeLine: Write values adding a newline after each
--   @param [h]: file handle [io.output ()]
--   @param ...: values to write (as for write)
function writeLine (h, ...)
  if io.type (h) ~= "file" then
    io.write (h, "\n")
    h = io.output ()
  end
  for _, v in ipairs ({...}) do
    h:write (v, "\n")
  end
end

-- @func splitdir: split a directory path into components
-- Empty components are retained: the root directory becomes {"", ""}.
-- The same as Perl's File::Spec::splitdir
--   @param path: path
-- @returns
--   @param: path1, ..., pathn: path components
function splitdir (path)
  return string.split ("/", path)
end

-- @func catdir: concatenate directories into a path
-- The same as Perl's File::Spec::catdir
--   @param: path1, ..., pathn: path components
-- @returns
--   @param path: path
function catdir (...)
  local path = table.concat ({...}, "/")
  -- Suppress trailing / on non-root path
  return (string.gsub (path, "(.)/$", "%1"))
end

-- @func shell: Perform a shell command and return its output
--   @param c: command
-- @returns
--   @param o: output, or nil if error
function shell (c)
  local h = io.popen (c)
  local o
  if h then
    o = h:read ("*a")
    h:close ()
  end
  return o
end

-- @func processFiles: Process files specified on the command-line
-- If no files given, process io.stdin; in list of files, "-" means
-- io.stdin
--   @param f: function to process files with
--     @param name: the name of the file being read
--     @param i: the number of the argument
function processFiles (f)
  -- N.B. "arg" below refers to the global array of command-line args
  if #arg == 0 then
    table.insert (arg, "-")
  end
  for i, v in ipairs (arg) do
    if v == "-" then
      io.input (io.stdin)
    else
      io.input (v)
    end
    prog.file = v
    f (v, i)
  end
end

-- getopt
-- Simplified getopt, based on Svenne Panne's Haskell GetOpt

module ("getopt", package.seeall)

require "base"
require "list"
require "string_ext"
require "object"
require "io_ext"


-- TODO: Sort out the packaging. getopt.Option is tedious to type, but
-- surely Option shouldn't be in the root namespace?
-- TODO: Wrap all messages; do all wrapping in processArgs, not
-- usageInfo; use sdoc-like library (see string.format todos)
-- TODO: Don't require name to be repeated in banner.
-- TODO: Store version separately (construct banner?).


-- Usage:

-- options = Options {Option {...} ...}
-- getopt.processArgs ()

-- Assumes prog = {name[, banner] [, purpose] [, notes] [, usage]}

-- options take a single dash, but may have a double dash
-- arguments may be given as -opt=arg or -opt arg
-- if an option taking an argument is given multiple times, only the
-- last value is returned; missing arguments are returned as 1

-- getOpt, usageInfo and dieWithUsage can be called directly (see
-- below, and the example at the end). Set _DEBUG.std to a non-nil
-- value to run the example.


-- @func getOpt: perform argument processing
--   @param argIn: list of command-line args
--   @param options: options table
-- @returns
--   @param argOut: table of remaining non-options
--   @param optOut: table of option key-value list pairs
--   @param errors: table of error messages
function getOpt (argIn, options)
  local noProcess = nil
  local argOut, optOut, errors = {[0] = argIn[0]}, {}, {}
  -- get an argument for option opt
  local function getArg (o, opt, arg, oldarg)
    if o.type == nil then
      if arg ~= nil then
        table.insert (errors, getopt.errNoArg (opt))
      end
    else
      if arg == nil and argIn[1] and
        string.sub (argIn[1], 1, 1) ~= "-" then
        arg = argIn[1]
        table.remove (argIn, 1)
      end
      if arg == nil and o.type == "Req" then
        table.insert (errors, getopt.errReqArg (opt, o.var))
        return nil
      end
    end
    if o.func then
      return o.func (arg, oldarg)
    end
    return arg or 1 -- make sure arg has a value
  end
  -- parse an option
  local function parseOpt (opt, arg)
    local o = options.name[opt]
    if o ~= nil then
      optOut[o.name[1]] = getArg (o, opt, arg, optOut[o.name[1]])
    else
      table.insert (errors, getopt.errUnrec (opt))
    end
  end
  while argIn[1] do
    local v = argIn[1]
    table.remove (argIn, 1)
    local _, _, dash, opt = string.find (v, "^(%-%-?)([^=-][^=]*)")
    local _, _, arg = string.find (v, "=(.*)$")
    if v == "--" then
      noProcess = 1
    elseif dash == nil or noProcess then -- non-option
      table.insert (argOut, v)
    else -- option
      parseOpt (opt, arg)
    end
  end
  return argOut, optOut, errors
end


-- Options table type

_G.Option = Object {_init = {
    "name", -- list of names
    "desc", -- description of this option
    "type", -- type of argument (if any): Req (uired), Opt (ional)
    "var",  -- descriptive name for the argument
    "func"  -- optional function (newarg, oldarg) to convert argument
    -- into actual argument, (if omitted, argument is left as it
    -- is)
}}

-- Options table constructor: adds lookup tables for the option names
function _G.Options (t)
  local name = {}
  for _, v in ipairs (t) do
    for j, s in pairs (v.name) do
      if name[s] then
        warn ("duplicate option '%s'", s)
      end
      name[s] = v
    end
  end
  t.name = name
  return t
end


-- Error and usage information formatting

-- @func errNoArg: argument when there shouldn't be one
--   @paramoptStr: option string
-- @returns
--   @param err: option error
function errNoArg (optStr)
  return "option `" .. optStr .. "' doesn't take an argument"
end

-- @func errReqArg: required argument missing
--   @param optStr: option string
--   @param desc: argument description
-- @returns
--   @param err: option error
function errReqArg (optStr, desc)
  return "option `" .. optStr .. "' requires an argument `" .. desc ..
    "'"
end

-- @func errUnrec: unrecognized option
--   @param optStr: option string
-- @returns
--   @param err: option error
function errUnrec (optStr)
  return "unrecognized option `-" .. optStr .. "'"
end


-- @func usageInfo: produce usage info for the given options
--   @param header: header string
--   @param optDesc: option descriptors
--   @param pageWidth: width to format to [78]
-- @returns
--   @param mess: formatted string
function usageInfo (header, optDesc, pageWidth)
  pageWidth = pageWidth or 78
  -- @func formatOpt: format the usage info for a single option
  --   @param opt: the Option table
  -- @returns
  --   @param opts: options
  --   @param desc: description
  local function fmtOpt (opt)
    local function fmtName (o)
      return "-" .. o
    end
    local function fmtArg ()
      if opt.type == nil then
        return ""
      elseif opt.type == "Req" then
        return "=" .. opt.var
      else
        return "[=" .. opt.var .. "]"
      end
    end
    local textName = list.map (fmtName, opt.name)
    textName[1] = textName[1] .. fmtArg ()
    return {table.concat ({table.concat (textName, ", ")}, ", "),
      opt.desc}
  end
  local function sameLen (xs)
    local n = math.max (unpack (list.map (string.len, xs)))
    for i, v in pairs (xs) do
      xs[i] = string.sub (v .. string.rep (" ", n), 1, n)
    end
    return xs, n
  end
  local function paste (x, y)
    return "  " .. x .. "  " .. y
  end
  local function wrapper (w, i)
    return function (s)
             return string.wrap (s, w, i, 0)
           end
  end
  local optText = ""
  if #optDesc > 0 then
    local cols = list.transpose (list.map (fmtOpt, optDesc))
    local width
    cols[1], width = sameLen (cols[1])
    cols[2] = list.map (wrapper (pageWidth, width + 4), cols[2])
    optText = "\n\n" ..
      table.concat (list.mapWith (paste,
                                  list.transpose ({sameLen (cols[1]),
                                                    cols[2]})),
                    "\n")
  end
  return header .. optText
end

-- @func dieWithUsage: die emitting a usage message
function dieWithUsage ()
  local name = prog.name
  prog.name = nil
  local usage, purpose, notes = "[OPTION...] FILE...", "", ""
  if prog.usage then
    usage = prog.usage
  end
  if prog.purpose then
    purpose = "\n" .. prog.purpose
  end
  if prog.notes then
    notes = "\n\n"
    if not string.find (prog.notes, "\n") then
      notes = notes .. string.wrap (prog.notes)
    else
      notes = notes .. prog.notes
    end
  end
  die (getopt.usageInfo ("Usage: " .. name .. " " .. usage .. purpose,
                         options)
         .. notes)
end


-- @func processArgs: simple getOpt wrapper
-- adds -version/-v and -help/-h/-? automatically; stops program
-- if there was an error or -help was used
_G.options = nil
function processArgs ()
  local totArgs = #arg
  options = Options (list.concat (options or {},
                                  {Option {{"version", "v"},
                                      "show program version"},
                                    Option {{"help", "h", "?"},
                                      "show this help"}}
                              ))
  local errors
  _G.arg, opt, errors = getopt.getOpt (arg, options)
  if (opt.version or opt.help) and prog.banner then
    io.stderr:write (prog.banner .. "\n")
  end
  if #errors > 0 or opt.help then
    local name = prog.name
    prog.name = nil
    if #errors > 0 then
      warn (table.concat (errors, "\n") .. "\n")
    end
    prog.name = name
    getopt.dieWithUsage ()
  elseif opt.version and #arg == 0 then
    os.exit ()
  end
end


-- A small and hopefully enlightening example:
if type (_DEBUG) == "table" and _DEBUG.std then

  function out (o)
    return o or io.stdout
  end

  options = Options {
    Option {{"verbose", "v"}, "verbosely list files"},
    Option {{"version", "release", "V", "?"}, "show version info"},
    Option {{"output", "o"}, "dump to FILE", "Opt", "FILE", out},
    Option {{"name", "n"}, "only dump USER's files", "Req", "USER"},
  }

  function test (cmdLine)
    local nonOpts, opts, errors = getopt.getOpt (cmdLine, options)
    if #errors == 0 then
      print ("options=" .. tostring (opts) ..
             "  args=" .. tostring (nonOpts) .. "\n")
    else
      print (table.concat (errors, "\n") .. "\n" ..
             getopt.usageInfo ("Usage: foobar [OPTION...] FILE...",
                               options))
    end
  end

  prog = {name = "foobar"} -- in case of errors
  -- example runs:
  test {"foo", "-v"}
  -- options={verbose=1}  args={1=foo,n=1}
  test {"foo", "--", "-v"}
  -- options={}  args={1=foo,2=-v,n=2}
  test {"-o", "-?", "-name", "bar", "--name=baz"}
  -- options={output=userdata(?): 0x????????,version=1,name=baz}  args={}
  test {"-foo"}
  -- unrecognized option `foo'
  -- Usage: foobar [OPTION...] FILE...
  --   -verbose, -v                verbosely list files
  --   -version, -release, -V, -?  show version info
  --   -output[=FILE], -o          dump to FILE
  --   -name=USER, -n              only dump USER's files

end

-- @module set

module ("set", package.seeall)


-- Primitive methods (know about representation)

-- The representation is a table whose tags are the elements, and
-- whose values are true.

-- @func member: Say whether an element is in a set
--   @param s: set
--   @param e: element
-- @returns
--   @param f: true if e is in set, false otherwise
function member (s, e)
  return s[e] == true
end

-- @func insert: Insert an element to a set
--   @param s: set
--   @param e: element
function insert (s, e)
  s[e] = true
end

-- @func new: Make a list into a set
--   @param l: list
-- @returns
--   @param s: set
local metatable = {}
function new (l)
  local s = setmetatable ({}, metatable)
  for _, e in ipairs (l) do
    insert (s, e)
  end
  return s
end

-- @func elements: Iterator for sets
-- TODO: Make the iterator return only the key
elements = pairs


-- High level methods (representation unknown)

-- @func difference: Find the difference of two sets
--   @param s, t: sets
-- @returns
--   @param r: s with elements of t removed
function difference (s, t)
  local r = new {}
  for e in elements (s) do
    if not member (t, e) then
      insert (r, e)
    end
  end
  return r
end

-- @func difference: Find the symmetric difference of two sets
--   @param s, t: sets
-- @returns
--   @param r: elements of s and t that are in s or t but not both
function symmetric_difference (s, t)
  return difference (union (s, t), intersection (t, s))
end

-- @func intersection: Find the intersection of two sets
--   @param s, t: sets
-- @returns
--   @param r: set intersection of s and t
function intersection (s, t)
  local r = new {}
  for e in elements (s) do
    if member (t, e) then
      insert (r, e)
    end
  end
  return r
end

-- @func union: Find the union of two sets
--   @param s, t: sets
-- @returns
--   @param r: set union of s and t
function union (s, t)
  local r = new {}
  for e in elements (s) do
    insert (r, e)
  end
  for e in elements (t) do
    insert (r, e)
  end
  return r
end

-- @func subset: Find whether one set is a subset of another
--   @param s, t: sets
-- @returns
--   @param r: true if s is a subset of t, false otherwise
function subset (s, t)
  for e in elements (s) do
    if not member (t, e) then
      return false
    end
  end
  return true
end

-- @func propersubset: Find whether one set is a proper subset of
-- another
--   @param s, t: sets
-- @returns
--   @param r: true if s is a proper subset of t, false otherwise
function propersubset (s, t)
  return subset (s, t) and not subset (t, s)
end

-- @func equal: Find whether two sets are equal
--   @param s, t: sets
-- @returns
--   @param r: true if sets are equal, false otherwise
function equal (s, t)
  return subset (s, t) and subset (t, s)
end

-- @head Metamethods for sets
-- set + table = union
metatable.__add = union
-- set - table = set difference
metatable.__sub = difference
-- set * table = intersection
metatable.__mul = intersection
-- set / table = symmetric difference
metatable.__div = symmetric_difference
-- set <= table = subset
metatable.__le = subset
-- set < table = proper subset
metatable.__lt = propersubset
