cmd_mp = {}
cur_mp = {}
macros = {}

function add_cmd_to_macro ()
  cur_mp = list.concat (cur_mp, cmd_mp)
  cmd_mp = {}
end

function add_key_to_cmd (key)
  table.insert (cmd_mp, key)
end

function remove_key_from_cmd ()
  table.remove (cmd_mp)
end

function cancel_kbd_macro ()
  cmd_mp = {}
  cur_mp = {}
  thisflag = bit.band (thisflag, bit.bnot (FLAG_DEFINING_MACRO))
end

-- FIXME: move this to a more appropriate module
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
  for name in pairs (macros) do
    table.insert (cp.completions, name)
  end
end

Defun ("start-kbd-macro",
       {},
[[
Record subsequent keyboard input, defining a keyboard macro.
The commands are recorded even as they are executed.
Use @kbd{C-x )} to finish recording and make the macro available.
Use @kbd{M-x name-last-kbd-macro} to give it a permanent name.
]],
  true,
  function ()
    if bit.band (thisflag, FLAG_DEFINING_MACRO) ~= 0 then
      minibuf_error ("Already defining a keyboard macro")
      return leNIL
    end

    if cur_mp ~= nil then
      cancel_kbd_macro ()
    end

    minibuf_write ("Defining keyboard macro...")

    thisflag = bit.bor (thisflag, FLAG_DEFINING_MACRO)
    cur_mp = {}
  end
)

Defun ("end-kbd-macro",
       {},
[[
Finish defining a keyboard macro.
The definition was started by @kbd{C-x (}.
The macro is now available for use via @kbd{C-x e}.
]],
  true,
  function ()
    if bit.band (thisflag, FLAG_DEFINING_MACRO) == 0 then
      minibuf_error ("Not defining a keyboard macro")
      return leNIL
    end

    thisflag = bit.band (thisflag, bit.bnot (FLAG_DEFINING_MACRO))
  end
)

Defun ("name-last-kbd-macro",
       {},
[[
Assign a name to the last keyboard macro defined.
Argument SYMBOL is the name to define.
The symbol's function definition becomes the keyboard macro string.
Such a \"function\" cannot be called from Lisp, but it is a valid editor command.
]],
  true,
  function ()
    local name = minibuf_read ("Name for last kbd macro: ", "")

    if not name then
      minibuf_error ("No command name given")
      return leNIL
    end

    if cur_mp == nil then
      minibuf_error ("No keyboard macro defined")
      return leNIL
    end

    -- Copy the keystrokes from cur_mp.
    macros[name] = table.clone (cur_mp)
  end
)

Defun ("call-last-kbd-macro",
       {},
[[
Call the last keyboard macro that you defined with @kbd{C-x (}.
A prefix argument serves as a repeat count.

To make a macro permanent so you can call it even after
defining others, use @kbd{M-x name-last-kbd-macro}.
]],
  true,
  function ()
    if cur_mp == nil then
      minibuf_error ("No kbd macro has been defined")
      return leNIL
    end

    undo_save (UNDO_START_SEQUENCE, cur_bp.pt, 0, 0)
    for _ = 1, get_variable_number ("current-prefix-arg") do
      process_keys (cur_mp)
    end
    undo_save (UNDO_END_SEQUENCE, cur_bp.pt, 0, 0)
  end
)

Defun ("execute-kbd-macro",
  {"string"},
[[
Execute macro as string of editor command characters.
]],
  false,
  function (keystr)
    local keys = keystrtovec (keystr)
    if keys ~= nil then
      process_keys (keys)
      return leT
    else
      return leNIL
    end
  end
)
