function get_variable (var)
  return get_variable_bp (cur_bp, var)
end

function get_variable_bp (bp, var)
  return ((bp and bp.vars and bp.vars[var]) or main_vars[var] or {}).val
end

function get_variable_number_bp (bp, var)
  return tonumber (get_variable_bp (bp, var), 10) or 0
  -- FIXME: Check result and signal error.
end

function get_variable_number (var)
  return get_variable_number_bp (cur_bp, var)
end

function get_variable_bool (var)
  local p = get_variable (var)
  if p then
    return p ~= "nil"
  end

  return false
end

function set_variable (var, val)
  local vars
  if (main_vars[var] or {}).islocal then
    cur_bp.vars = cur_bp.vars or {}
    vars = cur_bp.vars
  else
    vars = main_vars
  end
  vars[var] = vars[var] or {}

  vars[var].val = val
end

Defun ("set-variable",
       {"string", "string"},
[[
Set a variable value to the user-specified value.
]],
  true,
  function (var, val)
    local ok = leT

    if not var then
      var = minibuf_read_variable_name ("Set variable: ")
    end
    if not var then
      return leNIL
    end
    if not val then
      val = minibuf_read (string.format ("Set %s to value: ", var), "")
    end
    if not val then
      ok = execute_function ("keyboard-quit")
    end

    if ok == leT then
      set_variable (var, val)
    end

    return ok
  end
)

-- Initialise prefix arg
set_variable ("current-prefix-arg", "1")
