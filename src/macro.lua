cmd_mp = nil
head_mp = nil

function cancel_kbd_macro ()
  cmd_mp = nil
  cur_mp = nil
  thisflag = bit.band (thisflag, bit.bnot (FLAG_DEFINING_MACRO))
end

-- FIXME: local
function process_keys (keys)
  local cur = term_buf_len ()

  for i = 1, #keys do
    term_ungetkey (keys[#keys - i + 1])
  end

  while term_buf_len () > cur do
    process_command ()
  end
end

-- Add macro names to a list.
function add_macros_to_list (cp)
  local mp = head_mp
  while mp do
    table.insert (cp.completions, mp.name)
    mp = mp.next
  end
end

local function append_key_list (to, from)
  to.keys = list.concat (to.keys, from.keys)
end

function add_cmd_to_macro ()
  assert (cmd_mp)
  append_key_list (cur_mp, cmd_mp)
  cmd_mp = nil
end
