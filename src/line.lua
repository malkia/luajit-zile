-- Create an empty list, returning a pointer to the list
function line_new ()
  local l = {}
  l.next = l
  l.prev = l
  return l
end

-- Remove a line from a list.
function line_remove (l)
  l.prev.next = l.next
  l.next.prev = l.prev
end

-- Insert a line into list after the given point, returning the new line
function line_insert (l, s)
  local n = line_new ()
  n.next = l.next
  n.prev = l
  n.text = s
  l.next.prev = n
  l.next = n

  return n
end
