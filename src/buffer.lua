-- Copy a region of text into a string.
function copy_text_block (pt, size)
  local lp = pt.p
  local s = string.sub (lp.text, pt.o) .. "\n"

  lp = lp.next
  while #s < size do
    s = s .. lp.text .. "\n"
    lp = lp.next
  end

  return string.sub (s, 1, size)
end

function in_region (lineno, x, rp)
  if lineno < rp.start.n or lineno > rp.finish.n then
    return false
  elseif rp.start.n == rp.finish.n then
    return x >= rp.start.o and x < rp.finish.o
  elseif lineno == rp.start.n then
    return x >= rp.start.o
  elseif lineno == rp.finish.n then
    return x < rp.finish.o
  else
    return true
  end
  return false
end
