root_bindings = tree.new ()

function init_default_bindings ()
  -- Bind all printing keys to self_insert_command
  for i = 0, 0xff do
    if isprint (string.char (i)) then
      root_bindings[{i}] = "self-insert-command"
    end
  end

  -- FIXME: Load from path
  lisp_loadfile ("default-bindings.el")
end

function do_binding_completion (as)
  local key
  local bs = ""

  if bit.band (lastflag, FLAG_SET_UNIARG) ~= 0 then
    local arg = last_uniarg

    if arg < 0 then
      bs = bs .. "- "
      arg = -arg
    end

    repeat
      bs = " " .. bs
      bs = string.char (arg % 10 + string.byte ('0')) .. bs
      arg = math.floor (arg / 10)
    until arg == 0
  end

  minibuf_write ((bit.band (lastflag, bit.bor (FLAG_SET_UNIARG, FLAG_UNIARG_EMPTY)) ~= 0 and "C-u " or "") ..
                 bs .. as)
  key = getkey ()
  minibuf_clear ()

  return key
end

local function walk_bindings (tree, process, st)
  local function walk_bindings_tree (tree, keys, process, st)
    for key, node in pairs (tree) do
      if type (node) == "string" then
        process (table.concat (keys, " ") .. chordtostr (key), node, st)
      else
        table.insert (keys, chordtostr (key))
        walk_bindings_tree (node, keys, process, st)
        tree.remove (keys)
      end
    end
  end

  walk_bindings_tree (tree, {}, process, st)
end

-- Get a key sequence from the keyboard; the sequence returned
-- has at most the last stroke unbound.
function get_key_sequence ()
  local keys = {}

  local key
  repeat
    key = getkey ()
  until key ~= KBD_NOKEY
  table.insert (keys, key)

  local func
  while true do
    func = root_bindings[keys]
    if type (func) ~= "table" then
      break
    end
    local s = keyvectostr (keys) .. '-'
    table.insert (keys, do_binding_completion (s))
  end

  return keys, func
end

function get_function_by_keys (keys)
  -- Detect Meta-digit
  if #keys == 1 then
    local key = keys[1]
    if bit.band (key, KBD_META) and (isdigit (bit.band (key, 0xff)) or bit.band (key, 0xff) == string.byte ('-')) then
      return "universal-argument"
    end
  end

  local func = root_bindings[keys]
  return type (func) == "string" and func or nil
end

-- gather_bindings_state:
-- {
--   f: name of function
--   bindings: bindings
-- }

function gather_bindings (key, p, g)
  if p.func == g.f then
    if #g.bindings > 0 then
      g.bindings = g.bindings .. ", "
    end
    g.bindings = g.bindings .. key
  end
end

Defun {"where-is",
[[
Print message listing key sequences that invoke the command DEFINITION.
Argument is a command name.  If the prefix arg is non-nil, insert the
message in the buffer.
]],
  function (l)
    local name = minibuf_read_function_name ("Where is command: ")
    local g = {}

    ok = leNIL

    if name then
      g.f = name
      if function_exists (g.f) then
        g.bindings = ""
        walk_bindings (root_bindings, gather_bindings, g)

        if #g.bindings == 0 then
          minibuf_write (name .. " is not on any key")
        else
          local s = string.format ("%s is on %s", name, g.bindings)
          if bit.band (lastflag, FLAG_SET_UNIARG) ~= 0 then
            insert_string (s)
          else
            minibuf_write (s)
          end
        end
        ok = leT
      end
    end
  end
}

local function print_binding (key, p)
  insert_string (string.format ("%-15s %s\n", key, get_binding_func (p)))
end

local function write_bindings_list (key, binding)
  insert_string ("Key translations:\n")
  insert_string (string.format ("%-15s %s\n", "key", "binding"))
  insert_string (string.format ("%-15s %s\n", "---", "-------"))

  walk_bindings (root_bindings, print_binding)
end

Defun {"describe-bindings",
[[
Show a list of all defined keys, and their definitions.
]],
  function ()
    write_temp_buffer ("*Help*", true, write_bindings_list)
  end
}
