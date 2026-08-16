-- Luminance-based shading: derive the 3-shade DMG ramp for the mod's
-- follower / wild / submerged sheets at LOAD time, so no separate
-- -grayscale asset files need to ship.
--
-- The engine's shade/zone pass colorizes a sprite out of the active COLORS
-- mode's palette by keying on the art's RED channel (r > 0.83 → c0,
-- > 0.5 → c1, > 0.17 → c2, else c3), after SpriteRenderer bakes rOBP0 = $D0
-- (which also keys every pixel with r > 0.83 TRANSPARENT).  Full-color art
-- has an arbitrary red channel, so it cannot go through that path.  This
-- module converts each colored sheet into the luminance ramp the engine
-- expects — r = g = b = one of shades chosen by pixel brightness — with
-- the lightest shade clamped under 0.83 so no interior pixel ever punches
-- through.  The result is cached as a PNG in love.filesystem's save
-- directory (one file per source sheet, regenerated only when missing), and
-- callers serve the cache path exactly like a normal asset.  The zone pass
-- then colors it per mode (SGB map tints, OG RED/BLUE object greens/pinks,
-- OG YELLOW CGB zones, CLASSIC/OG/OG INV ramps, SGB INV permuted).
--
-- Shade assignment is per-sheet adaptive, not a fixed ladder: the OBP0 bake
-- collapses EVERYTHING above r = 0.5 into a single zone (c0), so a fixed
-- light bucket turns light mons into one flat white blob (Snorlax's cream
-- ~0.79 and body ~0.52 both became c0).  For each sheet the lightest
-- high-coverage color keeps c0 and a second, distinctly darker light color
-- is pulled down to c1 so the mon keeps its tonal separation.
--
-- Luminance alone cannot separate colors of DIFFERENT HUE at the same
-- brightness (Blastoise's light-blue shell ~0.63 vs cream belly ~0.66
-- collapse to the same zone).  The shade metric therefore darkens
-- blue-dominant pixels: saturated blue reads as a mid shade while a
-- same-brightness warm/neutral color keeps the light zone, matching how
-- the GSC art renders blue shells against cream bodies.
--
-- Headless / no-LÖVE environments fall back to the original colored path
-- (callers then keep trueColor = true); derivation is a rendering nicety.
local V = ...

local LuminanceSheet = {}

-- Engine-safe shade ramp.  After the OBP0 bake these land on:
--   0.8  → bake white → zone c0 (lightest)
--   0.45 → bake 170   → zone c1 (mid)
--   0.1  → bake black → zone c3 (darkest)
-- Lightest must stay < 0.83 (the bake's transparency key) and > 0.5.
local SHADE_LIGHT = 0.8
local SHADE_MID = 0.45
local SHADE_DARK = 0.1

-- The bake maps any r > 0.5 to the same zone, so the light bucket is
-- split by rank: lightest color → c0, a second light color → c1.  This
-- floor decides where that split happens; default 0.5 (single light
-- bucket) unless the sheet has two clearly separated light colors.
local DEFAULT_LIGHT_FLOOR = 0.5

-- Luma bins are 0.05 wide; a bin is a "real" color when it covers at
-- least this share of the opaque pixels (AA and dither noise stay below).
local MIN_BIN_COVERAGE = 0.02
local MIN_BIN_PIXELS = 3

-- Hue-aware shade value: Rec. 601 luma minus a penalty for blue-dominant
-- pixels (b clearly above the max of r/g).  Breaks the luma tie between
-- same-brightness blue shells and cream/warm bodies (Blastoise, Squirtle,
-- Lapras ...) so the two land in different zones.
local BLUE_PENALTY = 0.5
local function shadeValue(r, g, b)
  local luma = 0.299 * r + 0.587 * g + 0.114 * b
  local pen = BLUE_PENALTY * math.max(0, b - math.max(r, g))
  return luma - pen
end

-- Runtime cache paths are flat because sandboxed mods cannot call
-- love.filesystem.createDirectory. ImageData:encode is deliberately allowed
-- by engine 0.1.86 and remains confined to LÖVE's save identity.
local lumaCache, siloCache = {}, {}

function LuminanceSheet.available()
  return love and love.image and love.image.newImageData
end

local function pathHash(value)
  local hash = 5381
  for index = 1, #value do
    hash = (hash * 33 + value:byte(index)) % 4294967296
  end
  return ("%08x"):format(hash)
end

local function cacheFileName(kind, version, sourcePath)
  local tail = tostring(sourcePath):gsub("[^%w%.%-_]", "_")
  if #tail > 72 then tail = tail:sub(#tail - 71) end
  return ("ka_wilds_%s_v%d_%s_%s.png")
    :format(kind, version, pathHash(tostring(sourcePath)), tail)
end

-- Coverage-weighted shade histogram of the opaque pixels (blue-penalized
-- luma, see shadeValue).
local function shadeHistogram(id)
  local bins, opaque = {}, 0
  id:mapPixel(function(_, _, r, g, b, a)
    if a <= 0 then return r, g, b, a end
    opaque = opaque + 1
    local value = shadeValue(r, g, b)
    local bin = math.floor(value * 20 + 0.5) / 20
    bins[bin] = (bins[bin] or 0) + 1
    return r, g, b, a
  end)
  return bins, opaque
end

local function realLevels(bins, opaque)
  local result = {}
  local threshold = math.max(MIN_BIN_PIXELS, opaque * MIN_BIN_COVERAGE)
  for bin, count in pairs(bins) do
    if count >= threshold then result[#result + 1] = bin end
  end
  table.sort(result, function(a, b) return a > b end)
  return result
end

local function lightFloorFor(levels)
  local first = levels[1]
  if not first or first <= DEFAULT_LIGHT_FLOOR then
    return DEFAULT_LIGHT_FLOOR
  end
  local second = levels[2]
  if not second or second < DEFAULT_LIGHT_FLOOR
      or first - second < 0.08 then return DEFAULT_LIGHT_FLOOR end
  return (first + second) / 2
end

local function shadeFor(value, lightFloor)
  if value > lightFloor then return SHADE_LIGHT end
  if value > 0.17 then return SHADE_MID end
  return SHADE_DARK
end

local function encodeAndVerify(image, target)
  image:encode("png", target)
  -- An encode that did not throw is not enough: a damaged/unsupported save
  -- target must fail closed before SpriteRenderer receives it.
  local decoded = love.image.newImageData(target)
  return decoded and target or nil
end

--- Derive (once) an engine-safe luminance copy of `coloredPath` in the save
--- dir and return its runtime path.  Returns nil when derivation is
--- unavailable or fails — the caller then keeps the colored path.
function LuminanceSheet.pathFor(coloredPath)
  if type(coloredPath) ~= "string" or coloredPath == "" then return nil end
  if not LuminanceSheet.available() then return nil end
  if lumaCache[coloredPath] ~= nil then return lumaCache[coloredPath] or nil end
  local ok, result = pcall(function()
    local image = love.image.newImageData(coloredPath)
    local bins, opaque = shadeHistogram(image)
    local floor = lightFloorFor(realLevels(bins, opaque))
    image:mapPixel(function(_, _, r, g, b, a)
      if a <= 0 then return r, g, b, a end
      local shade = shadeFor(shadeValue(r, g, b), floor)
      return shade, shade, shade, a
    end)
    return encodeAndVerify(image, cacheFileName("luma", 4, coloredPath))
  end)
  if not ok or type(result) ~= "string" or result == "" then result = false end
  lumaCache[coloredPath] = result
  return result or nil
end

-- Silhouette derivation: every opaque pixel becomes the darkest shade so the
-- engine's OBP0 bake maps the whole sheet to the darkest zone color — a
-- solid black-out that keeps the sprite's shape (alpha still carries the
-- outline).  Same save-dir cache as pathFor, in its own silo_vN namespace so
-- silhouette files never collide with (or overwrite) the luma ramps.
function LuminanceSheet.silhouetteFor(coloredPath)
  if type(coloredPath) ~= "string" or coloredPath == "" then return nil end
  if not LuminanceSheet.available() then return nil end
  if siloCache[coloredPath] ~= nil then return siloCache[coloredPath] or nil end
  local ok, result = pcall(function()
    local image = love.image.newImageData(coloredPath)
    image:mapPixel(function(_, _, r, g, b, a)
      if a <= 0 then return r, g, b, a end
      return SHADE_DARK, SHADE_DARK, SHADE_DARK, a
    end)
    return encodeAndVerify(image, cacheFileName("silo", 2, coloredPath))
  end)
  if not ok or type(result) ~= "string" or result == "" then result = false end
  siloCache[coloredPath] = result
  return result or nil
end

return LuminanceSheet
