-- Minimal local JSON decoder for checked-in starter-habitat authority data.
-- It deliberately performs no host I/O; callers provide bytes obtained via
-- mod:read(), which works identically from a directory, package or SDK mount.

local J = {}

function J.decode(text)
  assert(type(text) == "string", "starter habitat JSON bytes required")

  local function skip(index)
    return text:find("[^ \t\r\n]", index) or (#text + 1)
  end

  local decodeValue
  local function decodeString(index)
    local out = {}
    index = index + 1
    while index <= #text do
      local char = text:sub(index, index)
      if char == '"' then return table.concat(out), index + 1 end
      if char ~= "\\" then
        out[#out + 1] = char
        index = index + 1
      else
        local escape = text:sub(index + 1, index + 1)
        local simple = {
          ['"'] = '"', ["\\"] = "\\", ["/"] = "/",
          b = "\b", f = "\f", n = "\n", r = "\r", t = "\t",
        }
        if simple[escape] then
          out[#out + 1] = simple[escape]
          index = index + 2
        elseif escape == "u" then
          local code = tonumber(text:sub(index + 2, index + 5), 16)
          assert(code, "invalid unicode escape")
          if code < 0x80 then
            out[#out + 1] = string.char(code)
          elseif code < 0x800 then
            out[#out + 1] = string.char(
              0xC0 + math.floor(code / 0x40), 0x80 + code % 0x40)
          else
            out[#out + 1] = string.char(
              0xE0 + math.floor(code / 0x1000),
              0x80 + math.floor(code / 0x40) % 0x40,
              0x80 + code % 0x40)
          end
          index = index + 6
        else
          error("invalid JSON escape")
        end
      end
    end
    error("unterminated JSON string")
  end

  decodeValue = function(index)
    index = skip(index)
    local char = text:sub(index, index)
    if char == '"' then return decodeString(index) end
    if char == "{" then
      local object = {}
      index = skip(index + 1)
      if text:sub(index, index) == "}" then return object, index + 1 end
      while true do
        local key
        key, index = decodeString(skip(index))
        index = skip(index)
        assert(text:sub(index, index) == ":", "expected : in JSON object")
        local value
        value, index = decodeValue(index + 1)
        object[key] = value
        index = skip(index)
        local delimiter = text:sub(index, index)
        if delimiter == "}" then return object, index + 1 end
        assert(delimiter == ",", "expected , or } in JSON object")
        index = index + 1
      end
    end
    if char == "[" then
      local array = {}
      index = skip(index + 1)
      if text:sub(index, index) == "]" then return array, index + 1 end
      while true do
        local value
        value, index = decodeValue(index)
        array[#array + 1] = value
        index = skip(index)
        local delimiter = text:sub(index, index)
        if delimiter == "]" then return array, index + 1 end
        assert(delimiter == ",", "expected , or ] in JSON array")
        index = index + 1
      end
    end
    if text:sub(index, index + 3) == "true" then return true, index + 4 end
    if text:sub(index, index + 4) == "false" then return false, index + 5 end
    if text:sub(index, index + 3) == "null" then return nil, index + 4 end
    local number = text:match("^-?%d+%.?%d*[eE]?[+-]?%d*", index)
    assert(number and #number > 0, "unexpected JSON token at " .. index)
    return assert(tonumber(number)), index + #number
  end

  local value, nextIndex = decodeValue(1)
  assert(skip(nextIndex) == #text + 1, "trailing JSON data")
  return value
end

function J.read(mod, relative)
  assert(mod and type(mod.read) == "function", "mod:read unavailable")
  local bytes, err = mod:read(relative)
  assert(bytes, err or ("missing JSON asset: " .. tostring(relative)))
  local ok, decoded = pcall(J.decode, bytes)
  assert(ok and decoded, "invalid JSON asset " .. tostring(relative)
    .. ": " .. tostring(decoded))
  return decoded
end

return J
