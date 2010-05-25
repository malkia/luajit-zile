-- local
function walk_bindings (tree, process, st)
  local function walk_bindings_tree (tree, keys, process, st)
    if tree.key then
      table.insert (keys, chordtostr (tree.key))
    end

    for _, p in ipairs (tree.vec) do
      if p.func then
        process (table.concat (keys, " ") .. chordtostr (p.key), p, st)
      else
        walk_bindings_tree (p, keys, process, st)
      end
    end

    if tree.key then
      table.remove (keys)
    end
  end

  walk_bindings_tree (tree, {}, process, st)
end

-- gather_bindings_state:
-- {
--   f - name of function
--   bindings - bindings
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
          minibuf_write ("%s is not on any key", name)
        else
          local s = string.format ("%s is on %s", name, g.bindings)
          if bit.band (lastflag, FLAG_SET_UNIARG) ~= 0 then
            bprintf ("%s", s)
          else
            minibuf_write ("%s", s)
          end
        end
        ok = leT
      end
    end
  end
}
