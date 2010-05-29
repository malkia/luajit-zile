function get_variable_bool (var)
  local p = get_variable (var)
  if p then
    return p ~= "nil"
  end

  return false
end
