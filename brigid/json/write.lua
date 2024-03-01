-- Copyright (c) 2024 <dev@brigid.jp>
-- This software is released under the MIT License.
-- https://opensource.org/licenses/mit-license.php

local brigid = require "brigid"

local quote_table = {
  ["\b"] = [[\b]];
  ["\t"] = [[\t]];
  ["\n"] = [[\n]];
  ["\f"] = [[\f]];
  ["\r"] = [[\r]];
  ["\""] = [[\"]];
  ["\\"] = [[\\]];

  -- JavaScript互換
  ["\x7F"]         = [[\u007F]]; -- DELETE
  ["\xE2\x80\xA8"] = [[\u2028]]; -- LINE SEPARATOR
  ["\xE2\x80\xA9"] = [[\u2029]]; -- PARAGRAPH SEPARATOR
}

for byte = 0x00, 0x1F do
  local char = string.char(byte)
  if not quote_table[char] then
    quote_table[char] = ([[\u%04X]]):format(byte)
  end
end

local function quote(s)
  return [["]]..s:gsub("[\x00-\x1F\"\\\x7F]", quote_table):gsub("\xE2\x80[\xA8\xA9]", quote_table)..[["]]
end

local function is_array(t)
  if t[1] ~= nil then
    return true
  else
    local m = getmetatable(t)
    return m and m.__name == "brigid.json.array"
  end
end

local function write(writer, u)
  local t = type(u)
  if t == "number" then
    return writer:write(("%.17g"):format(u))
  elseif t == "string" then
    return writer:write(quote(u))
  elseif t == "boolean" then
    if u then
      return writer:write "true"
    else
      return writer:write "false"
    end
  elseif t == "table" then
    if is_array(u) then
      writer:write "["
      for i, v in ipairs(u) do
        if i > 1 then
          writer:write ","
        end
        write(writer, v)
      end
      return writer:write "]"
    else
      writer:write "{"
      local first = true
      for k, v in pairs(u) do
        if first then
          first = false
        else
          writer:write ","
        end
        write(writer, tostring(k))
        writer:write ":"
        write(writer, v)
      end
      return writer:write "}"
    end
  else
    return writer:write "null"
  end
end

return write
