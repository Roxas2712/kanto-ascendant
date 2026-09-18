-- Keep the engine's writer, key order, numeric precision and save grammar.
-- Only whitespace OUTSIDE its quoted strings is compacted. In particular,
-- %q may emit an escaped physical newline: never gsub the complete save.
local M = {}

local function outside(text)
  -- A future/custom writer may use comments or long/single-quoted strings.
  -- Leave those formats alone instead of guessing where their strings end.
  if text:find("'", 1, true) or text:find("--", 1, true)
      or text:find("%[=*%[") then return nil end
  return (text:gsub("[ \t\r\n]+", " ")
    :gsub(" ?([{}%[%]=,]) ?", "%1"))
end

function M.compact(source)
  if type(source) ~= "string" or not source:match("^return%s*{") then
    return source
  end
  local parts, pos = {}, 1
  while pos <= #source do
    local quote = source:find('"', pos, true)
    local plain = outside(source:sub(pos, quote and quote - 1 or #source))
    if not plain then return source end
    parts[#parts + 1] = plain
    if not quote then break end
    local cursor, finish = quote + 1
    while cursor <= #source do
      local special = source:find('["\\]', cursor)
      if not special then return source end
      if source:sub(special, special) == '"' then
        finish = special
        break
      end
      cursor = special + 2 -- preserve the backslash AND its escaped byte
    end
    if not finish then return source end
    parts[#parts + 1] = source:sub(quote, finish)
    pos = finish + 1
  end
  local result = table.concat(parts):gsub(" +$", "") .. "\n"
  return #result < #source and result or source
end

local function isKascSave(data)
  return type(data) == "table" and type(data.version) == "string"
    and type(data.boxes) == "table" and type(data.modData) == "table"
    and type(data.modData.kanto_ascendant) == "table"
end

function M.install(mod)
  local ok, serializer = pcall(require, "src.core.SaveSerializer")
  if not ok or type(serializer) ~= "table"
      or type(serializer.encode) ~= "function" then
    if mod.log and mod.log.warn then
      mod.log:warn("Compact saves unavailable; keeping the engine save writer")
    end
    return false
  end
  -- Repeated KASC loads must not add another full pass over every save.
  if serializer.__kascCompactSave then return true end
  local original = serializer.encode
  serializer.encode = function(data, ...)
    local source = original(data, ...)
    if not isKascSave(data) then return source end
    local compactOk, result = pcall(M.compact, source)
    if compactOk and type(result) == "string" then return result end
    return source -- a formatting failure must never prevent a game save
  end
  serializer.__kascCompactSave = true
  return true
end

return M
