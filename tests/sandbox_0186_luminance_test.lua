-- Exact 0.1.86 ImageData-only contract for Wilds luminance and silhouettes.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local function copyPixels(pixels)
  local out = {}
  for index, pixel in ipairs(pixels) do
    out[index] = { pixel[1], pixel[2], pixel[3], pixel[4] }
  end
  return out
end

local Image = {}
Image.__index = Image
function Image:getDimensions() return self.width, self.height end
function Image:mapPixel(callback)
  for y = 0, self.height - 1 do
    for x = 0, self.width - 1 do
      local index = y * self.width + x + 1
      local p = self.pixels[index]
      self.pixels[index] = { callback(x, y, p[1], p[2], p[3], p[4]) }
    end
  end
end
function Image:getPixel(x, y)
  return unpack(self.pixels[y * self.width + x + 1])
end

local sources, encoded, decodeCount = {}, {}, {}
local corruptTargets = {}
local function image(width, height, pixels)
  return setmetatable({
    width = width, height = height, pixels = copyPixels(pixels),
  }, Image)
end
function Image:clone()
  return image(self.width, self.height, self.pixels)
end
function Image:encode(_, target)
  encoded[target] = self:clone()
  if corruptTargets[target] then encoded[target] = nil end
  return true
end

sources.land = image(4, 1, {
  { 1.00, 0.90, 0.70, 1 },
  { 0.40, 0.40, 0.40, 1 },
  { 0.05, 0.05, 0.05, 1 },
  { 0.20, 0.20, 0.20, 0 },
})
sources.water = image(2, 1, {
  { 0.70, 0.70, 0.70, 1 }, { 0.20, 0.20, 0.20, 0 },
})
sources.corrupt = image(1, 1, { { 0.7, 0.6, 0.5, 1 } })

local deniedLoveReads = 0
love = setmetatable({ image = { newImageData = function(path)
  decodeCount[path] = (decodeCount[path] or 0) + 1
  local found = sources[path] or encoded[path]
  if not found then error("decode failed: " .. tostring(path)) end
  return found:clone()
end } }, { __index = function(_, key)
  if key == "filesystem" or key == "system" or key == "thread"
      or key == "event" then
    deniedLoveReads = deniedLoveReads + 1
    error("love." .. key .. " denied", 2)
  end
end })

local module = assert(loadfile(root
  .. "/vendor/wilds_1_12_2/lib/luminance_sheet.lua"))({})

local landPath = assert(module.pathFor("land"), "land luminance did not encode")
local land = assert(encoded[landPath], "land cache target was not written")
local expected = { 0.8, 0.45, 0.1 }
for x = 0, 2 do
  local r, g, b, a = land:getPixel(x, 0)
  assert(math.abs(r - expected[x + 1]) < 0.001 and r == g and g == b and a == 1,
    "luminance ramp mismatch at pixel " .. x)
end
local _, _, _, transparent = land:getPixel(3, 0)
assert(transparent == 0, "luminance conversion lost alpha")
local firstLandDecodes = decodeCount.land
assert(module.pathFor("land") == landPath and decodeCount.land == firstLandDecodes,
  "land luminance result was not cached")

local siloPath = assert(module.silhouetteFor("water"),
  "water/submerged silhouette did not encode")
local silo = assert(encoded[siloPath], "silhouette cache target was not written")
local r, g, b, a = silo:getPixel(0, 0)
assert(r == 0.1 and g == 0.1 and b == 0.1 and a == 1,
  "opaque silhouette pixel was not the dark engine shade")
local _, _, _, siloAlpha = silo:getPixel(1, 0)
assert(siloAlpha == 0, "silhouette conversion lost transparent pixels")

-- The target name is deterministic. Mark it corrupt before the first call
-- for this distinct source and verify the module returns nil rather than a
-- path SpriteRenderer cannot decode.
local probeTarget
do
  local originalEncode = Image.encode
  function Image:encode(kind, target)
    probeTarget = target
    corruptTargets[target] = true
    return originalEncode(self, kind, target)
  end
  assert(module.pathFor("corrupt") == nil,
    "corrupt encoded luminance target did not fail closed")
  Image.encode = originalEncode
end
assert(probeTarget and encoded[probeTarget] == nil,
  "corrupt-output test did not exercise encode/decode verification")
assert(deniedLoveReads == 0,
  "luminance pipeline touched a denied love facade property")

print("PASS sandbox 0.1.86 Wilds luminance: land, submerged silhouette, corrupt fallback")
