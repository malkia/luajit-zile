function get_variable_bp (bp, var)
  return ((bp and bp.vars or main_vars)[var] or {}).val
end

function get_variable_number_bp (bp, var)
  return tonumber (get_variable_bp (bp, var), 10) or 0
  -- FIXME: Check result and signal error.
end

function get_variable_bool (var)
  local p = get_variable (var)
  if p then
    return p ~= "nil"
  end

  return false
end
