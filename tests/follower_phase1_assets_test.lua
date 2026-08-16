-- Phase-1 contract for the native follower work.
--
-- This deliberately tests only facts the current 6.0 line already promises:
-- complete Johto catalogue coverage and a loadable six-pose runtime sheet for
-- every normal/shiny species.  It does not implement or assert Phase-2
-- follower behaviour.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local function read(path)
  local file = assert(io.open(root .. "/" .. path, "rb"),
    "missing " .. path)
  local bytes = assert(file:read("*a"))
  file:close()
  return bytes
end

local function pngDimensions(path)
  local bytes = read(path)
  assert(bytes:sub(1, 8) == "\137PNG\r\n\26\n", path .. " is not PNG")
  local function u32(offset)
    local a, b, c, d = bytes:byte(offset, offset + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

local johto = assert(loadfile(root .. "/johto_data.lua"))()
assert(type(johto.order) == "table", "Johto order is unavailable")
assert(#johto.order == 100,
  "expected exactly Johto #152-251, got " .. tostring(#johto.order))

local seen = {}
for index, species in ipairs(johto.order) do
  local def = assert(johto.species[species], "missing definition " .. species)
  assert(def.dex == 151 + index,
    ("Johto order mismatch at %d: %s is #%s"):format(
      index, species, tostring(def.dex)))
  assert(not seen[species], "duplicate Johto species " .. species)
  seen[species] = true
  for _, variant in ipairs({ "normal", "shiny" }) do
    local path = ("assets/followers_runtime/%s/follower_%s.png")
      :format(variant, species)
    local width, height = pngDimensions(path)
    assert(width == 16 and height == 96,
      ("%s must be a 16x96 six-pose sheet, got %dx%d")
        :format(path, width, height))
  end
end

for _, variant in ipairs({ "normal", "shiny" }) do
  local path = ("assets/followers_runtime/%s/follower_GOROCHU.png")
    :format(variant)
  local width, height = pngDimensions(path)
  assert(width == 16 and height == 96,
    ("%s must be a 16x96 six-pose sheet, got %dx%d")
      :format(path, width, height))
end

print("PASS follower Phase-1 assets: Johto 100/100 normal+shiny; Gorochu 2/2")
