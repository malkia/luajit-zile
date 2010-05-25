local codetoname = {
  [KBD_PGUP]  = "<prior>",
  [KBD_PGDN]  = "<next>",
  [KBD_HOME]  = "<home>",
  [KBD_END]   = "<end>",
  [KBD_DEL]   = "<delete>",
  [KBD_BS]    = "<backspace>",
  [KBD_INS]   = "<insert>",
  [KBD_LEFT]  = "<left>",
  [KBD_RIGHT] = "<right>",
  [KBD_UP]    = "<up>",
  [KBD_DOWN]  = "<down>",
  [KBD_RET]   = "<RET>",
  [KBD_TAB]   = "<TAB>",
  [KBD_F1]    = "<f1>",
  [KBD_F2]    = "<f2>",
  [KBD_F3]    = "<f3>",
  [KBD_F4]    = "<f4>",
  [KBD_F5]    = "<f5>",
  [KBD_F6]    = "<f6>",
  [KBD_F7]    = "<f7>",
  [KBD_F8]    = "<f8>",
  [KBD_F9]    = "<f9>",
  [KBD_F10]   = "<f10>",
  [KBD_F11]   = "<f11>",
  [KBD_F12]   = "<f12>",
  [' ']       = "SPC",
}

-- Convert a key chord into its ASCII representation
function chordtostr (key)
  local s = ""

  if bit.band (key, KBD_CTRL) ~= 0 then
    s = s .. "C-"
  end
  if bit.band (key, KBD_META) ~= 0 then
    s = s .. "M-"
  end
  key = bit.band (key, bit.bnot (bit.bor (KBD_CTRL, KBD_META)))

  if codetoname[key] then
    s = s .. codetoname[key]
  elseif key <= 0xff and isgraph (key) then
    s = s .. string.char (key)
  else
    s = s .. string.format ("<%x>", key)
  end

  return s
end


-- Convert a key code sequence into a key code sequence string.
function keyvectostr (keys)
  return table.concat (list.map (chordtostr, keys), " ")
end

-- Array of key names
local keynametocode_map = {
  ["\\BACKSPACE"] = KBD_BS,
  ["\\C-"] = KBD_CTRL,
  ["\\DELETE"] = KBD_DEL,
  ["\\DOWN"] = KBD_DOWN,
  ["\\END"] = KBD_END,
  ["\\F1"] = KBD_F1,
  ["\\F10"] = KBD_F10,
  ["\\F11"] = KBD_F11,
  ["\\F12"] = KBD_F12,
  ["\\F2"] = KBD_F2,
  ["\\F3"] = KBD_F3,
  ["\\F4"] = KBD_F4,
  ["\\F5"] = KBD_F5,
  ["\\F6"] = KBD_F6,
  ["\\F7"] = KBD_F7,
  ["\\F8"] = KBD_F8,
  ["\\F9"] = KBD_F9,
  ["\\HOME"] = KBD_HOME,
  ["\\INSERT"] = KBD_INS,
  ["\\LEFT"] = KBD_LEFT,
  ["\\M-"] = KBD_META,
  ["\\NEXT"] = KBD_PGDN,
  ["\\PAGEDOWN"] = KBD_PGDN,
  ["\\PAGEUP"] = KBD_PGUP,
  ["\\PRIOR"] = KBD_PGUP,
  ["\\r"] = KBD_RET, -- FIXME: Kludge to make keystrings work in both Emacs and Zile.
  ["\\RET"] = KBD_RET,
  ["\\RIGHT"] = KBD_RIGHT,
  ["\\SPC"] = string.byte (' '),
  ["\\TAB"] = KBD_TAB,
  ["\\UP"] = KBD_UP,
  ["\\\\"] = string.byte ('\\'),
}

-- Convert a prefix of a key string to its key code.
local function strtokey (s)
  if string.sub (s, 1, 1) == '\\' then
    local p
    for i in pairs (keynametocode_map) do
      if i == string.sub (s, 2, #i + 1) then
        p = i
      end
    end
    if p then
      return keynametocode_map [p], string.sub (s, #p + 2)
    end
    return KBD_NOKEY, ""
  end

  return string.byte (s), string.sub (s, 2)
end

-- Convert a key chord string to its key code.
function strtochord (s)
  local key = 0

  local k
  repeat
    k, s = strtokey (s)
    if k == KBD_NOKEY then
      return KBD_NOKEY
    end
    key = bit.bor (key, k)
  until k ~= KBD_CTRL and k ~= KBD_META

  return s, key
end

-- Convert a key sequence string into a key code sequence, or nil if
-- it can't be converted.
function keystrtovec (s)
  local keys = {}

  while s ~= "" do
    local s, code = strtochord (s)
    if code == KBD_NOKEY then
      return nil
    end
    table.insert (keys, code)
  end

  return keys
end
