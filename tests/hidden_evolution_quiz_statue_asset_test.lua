-- Focused generated quiz-statue asset contract.  It is safe under the
-- plain-Lua SDK (where image authoring is intentionally unavailable) and
-- exercises the same recipe with real LÖVE ImageData whenever that backend
-- is present.
local engine = os.getenv("GEN1RECOMP_DIR") or os.getenv("GEN1RECOMP_ROOT") or "."
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD")
  or os.getenv("KA_HEVO_MOD"), "KA_HIDDEN_EVOLUTION_MOD is required")
local transform = assert(loadfile(root .. "/shiny_transforms.lua"))()

-- A missing imported GYM sheet and a missing image backend are both normal
-- headless/install states.  The recipe must remain loadable and non-fatal;
-- in particular it must not emit a misleading placeholder statue.
local absentWrites = {}
local absentOk, absentWhy = pcall(transform, {
  exists = function() return false end,
  readImage = function() error("readImage must not run without input") end,
  blank = function() error("no image backend") end,
  blit = function() error("blit must not run without input") end,
  recolor = function() error("recolor must not run without input") end,
  writeImage = function(_, rel) absentWrites[rel] = true end,
})
assert(absentOk, "missing GYM/input must be non-fatal: " .. tostring(absentWhy))
assert(next(absentWrites) == nil, "missing image backend wrote derived art")

local campaignFile = assert(io.open(root .. "/hidden_evolution_campaign.lua", "rb"))
local campaignSource = campaignFile:read("*a")
campaignFile:close()
assert(campaignSource:find("SPRITE_KA_HEVO_QUIZ_STATUE", 1, true),
  "quiz statue sprite registration missing")
assert(campaignSource:find('derivedAsset .. "quiz_statue.png"', 1, true),
  "quiz statue registration must use the generated-cache path")

-- Keep the headless gate useful without pretending a table-shaped image is
-- pixel proof.  The exact real-ImageData branch below runs in LÖVE.
local imageFactory = love and love.image and love.image.newImageData
local realOk, probe = false, nil
if type(imageFactory) == "function" then
  realOk, probe = pcall(imageFactory, 1, 1)
end
if not (realOk and probe and type(probe.typeOf) == "function"
    and probe:typeOf("ImageData")) then
  local recipeFile = assert(io.open(root .. "/shiny_transforms.lua", "rb"))
  local recipe = recipeFile:read("*a")
  recipeFile:close()
  for _, token in ipairs({
    'read("tilesets/gym.png")',
    '"hidden_evolution/quiz_statue.png"',
    "{ 0x02, 0, 0 }", "{ 0x38, 8, 0 }",
    "{ 0x12, 0, 8 }", "{ 0x13, 8, 8 }",
  }) do
    assert(recipe:find(token, 1, true), "quiz statue recipe token missing: " .. token)
  end
  print("hidden_evolution_quiz_statue_asset_test: PASS (headless contract; real ImageData branch deferred)")
  return
end

local ImageWriter = require("src.import.ImageWriter")
local gym = ImageWriter.blank(128, 48, 1, 1, 1, 1)
local figureTiles = {
  { 0x02, 0, 0 }, { 0x38, 8, 0 },
  { 0x12, 0, 8 }, { 0x13, 8, 8 },
}

local function sourceForComposed(x, y)
  local column, row = x >= 8 and 2 or 1, y >= 8 and 2 or 1
  local tile = figureTiles[(row - 1) * 2 + column][1]
  return tile % 16 * 8 + x % 8,
    math.floor(tile / 16) * 8 + y % 8
end
local function setComposed(x, y, value)
  local sourceX, sourceY = sourceForComposed(x, y)
  gym:setPixel(sourceX, sourceY, value, value, value, 1)
end

-- The synthetic source is fully opaque like an imported GYM atlas.  Its
-- three non-black shades all touch the edge and therefore count as possible
-- background.  A closed black outline encloses those same shades, proving
-- the flood removes only edge-connected ground and preserves statue detail.
local shades = { 1, 2 / 3, 1 / 3 }
for y = 0, 15 do
  for x = 0, 15 do setComposed(x, y, shades[(x + y) % 3 + 1]) end
end
for x = 3, 12 do setComposed(x, 2, 0); setComposed(x, 13, 0) end
for y = 2, 13 do setComposed(3, y, 0); setComposed(12, y, 0) end

-- One surviving sample per source quadrant pins the exact tile assembly.
setComposed(4, 4, 1)
setComposed(11, 4, 2 / 3)
setComposed(4, 11, 1 / 3)
setComposed(11, 11, 0)

-- Poison the native plinth tiles.  A 16x32/plinth crop regression would put
-- this color into the result; the bounded renderer contract is figure-only.
for _, id in ipairs({ 0x22, 0x23, 0x32, 0x33 }) do
  local originX, originY = id % 16 * 8, math.floor(id / 16) * 8
  for y = 0, 7 do for x = 0, 7 do
    gym:setPixel(originX + x, originY + y, 1, 0, 1, 1)
  end end
end

local written = {}
local function realContext(input)
  return {
    exists = function(rel) return rel == "tilesets/gym.png" end,
    readImage = function(rel)
      assert(rel == "tilesets/gym.png", "unexpected image read: " .. tostring(rel))
      return input
    end,
    blank = ImageWriter.blank,
    blit = ImageWriter.blit,
    recolor = function(image) return image end,
    writeImage = function(image, rel)
      assert(image and image.typeOf and image:typeOf("ImageData"),
        rel .. " is not real ImageData")
      written[rel] = image
    end,
  }
end

assert(transform(realContext(gym)) == nil)
local statue = assert(written["hidden_evolution/quiz_statue.png"],
  "real GYM input did not produce the quiz statue")
assert(statue:getWidth() == 16 and statue:getHeight() == 16,
  "quiz statue must stay one universal 16x16 renderer frame")

local function close(actual, expected)
  return math.abs(actual - expected) < 1 / 1000
end
for _, sample in ipairs({
  { 4, 4, 1 }, { 11, 4, 2 / 3 },
  { 4, 11, 1 / 3 }, { 11, 11, 0 },
}) do
  local r, g, b, a = statue:getPixel(sample[1], sample[2])
  assert(close(r, sample[3]) and close(g, sample[3]) and close(b, sample[3])
      and close(a, 1),
    ("wrong figure tile at %d:%d"):format(sample[1], sample[2]))
end

local visible, transparent, magenta = 0, 0, 0
for y = 0, 15 do for x = 0, 15 do
  local r, g, b, a = statue:getPixel(x, y)
  if a == 0 then transparent = transparent + 1 else visible = visible + 1 end
  if r > 0.99 and g < 0.01 and b > 0.99 and a > 0.99 then
    magenta = magenta + 1
  end
end end
assert(visible == 120 and transparent == 136,
  ("outline flood changed: visible=%d transparent=%d"):format(visible, transparent))
assert(magenta == 0, "native plinth pixels leaked into the figure sprite")
for _, point in ipairs({ { 0, 0 }, { 15, 0 }, { 0, 15 }, { 15, 15 } }) do
  local _, _, _, a = statue:getPixel(point[1], point[2])
  assert(a == 0, "quiz statue retained an opaque rectangular corner")
end

-- A malformed/partial imported sheet is skipped rather than crashing or
-- registering fake pixels.  The campaign may still register its declarative
-- sprite record; the next normal ROM import produces the missing cache file.
written = {}
local smallOk, smallWhy = pcall(transform, realContext(ImageWriter.blank(16, 16)))
assert(smallOk, "undersized GYM input must be non-fatal: " .. tostring(smallWhy))
assert(written["hidden_evolution/quiz_statue.png"] == nil,
  "undersized GYM input wrote a truncated statue")

-- Optional local-import proof used by the private acceptance harness.  The
-- package test remains self-contained, but when a real imported GYM PNG is
-- supplied it runs the exact same recipe over those pixels as well.
local importedGymPath = os.getenv("KA_HEVO_REAL_GYM")
if importedGymPath and importedGymPath ~= "" then
  local handle = assert(io.open(importedGymPath, "rb"))
  local bytes = handle:read("*a")
  handle:close()
  local fileData = assert(love.filesystem.newFileData(bytes, "gym.png"))
  local importedGym = assert(love.image.newImageData(fileData))
  written = {}
  assert(transform(realContext(importedGym)) == nil)
  local imported = assert(written["hidden_evolution/quiz_statue.png"])
  local importedVisible, importedTransparent = 0, 0
  local minX, minY, maxX, maxY = 16, 16, -1, -1
  for y = 0, 15 do for x = 0, 15 do
    local _, _, _, a = imported:getPixel(x, y)
    if a == 0 then
      importedTransparent = importedTransparent + 1
    else
      importedVisible = importedVisible + 1
      minX, minY = math.min(minX, x), math.min(minY, y)
      maxX, maxY = math.max(maxX, x), math.max(maxY, y)
    end
  end end
  assert(importedVisible > 0 and importedTransparent > 0,
    "imported statue must contain both figure pixels and real transparency")
  assert(maxX - minX >= 5 and maxY - minY >= 7,
    "imported statue silhouette collapsed during background flood")
  local outputPath = os.getenv("KA_HEVO_QUIZ_STATUE_OUTPUT")
  if outputPath and outputPath ~= "" then
    local encoded = assert(imported:encode("png"))
    local output = assert(io.open(outputPath, "wb"))
    output:write(encoded:getString())
    output:close()
  end
  print(("quiz statue imported GYM proof: visible=%d transparent=%d bbox=%d,%d-%d,%d")
    :format(importedVisible, importedTransparent, minX, minY, maxX, maxY))
end

print("hidden_evolution_quiz_statue_asset_test: PASS (real ImageData)")
