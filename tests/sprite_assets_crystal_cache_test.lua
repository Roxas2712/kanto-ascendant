local root = (arg and arg[1]) or "."
local factory = assert(loadfile(root .. "/sprite_assets.lua"))()

local checks = 0
local function check(value, message)
  assert(value, message)
  checks = checks + 1
end

local counters = {
  sourceDecodes = 0,
  targetDecodes = 0,
  floodWrites = 0,
  encodes = 0,
}
local sources, cache = {}, {}
local relativePaths = {}

for index = 1, 604 do
  local relative = ("assets/crystal/cache_probe_%03d.png"):format(index)
  relativePaths[index] = relative
  sources[relative] = "synthetic crystal source " .. index .. " revision A"
end

local function sourceImage()
  local image = {}
  function image:getDimensions() return 1, 1 end
  function image:getPixel() return 0.2, 0.3, 0.4, 1 end
  function image:setPixel()
    counters.floodWrites = counters.floodWrites + 1
  end
  function image:encode(_, target)
    counters.encodes = counters.encodes + 1
    cache[target] = "valid"
  end
  return image
end

local mod = {
  path = "/mods/kanto_ascendant",
  read = function(_, relative)
    return sources[relative]
  end,
}

local previousLove = love
love = {
  image = {
    newImageData = function(path)
      if path:sub(1, #mod.path + 1) == mod.path .. "/" then
        counters.sourceDecodes = counters.sourceDecodes + 1
        return sourceImage()
      end
      counters.targetDecodes = counters.targetDecodes + 1
      if cache[path] ~= "valid" then
        error("synthetic missing or corrupt cache target: " .. tostring(path))
      end
      return {}
    end,
  },
}

local first = factory(mod)
local targets = {}
for index, relative in ipairs(relativePaths) do
  targets[index] = first.crystal(relative)
end
check(counters.sourceDecodes == 604,
  "the initial cold load did not decode all 604 Crystal sources")
check(counters.floodWrites == 604,
  "the initial cold load did not clear each synthetic Crystal background")
check(counters.encodes == 604,
  "the initial cold load did not build all 604 Crystal cache targets")

local beforeSecond = {
  sourceDecodes = counters.sourceDecodes,
  floodWrites = counters.floodWrites,
  encodes = counters.encodes,
  targetDecodes = counters.targetDecodes,
}
local second = factory(mod)
for index, relative in ipairs(relativePaths) do
  check(second.crystal(relative) == targets[index],
    "a valid cold cache hit changed Crystal target " .. index)
end
check(counters.sourceDecodes == beforeSecond.sourceDecodes,
  "the second cold load decoded Crystal sources instead of using valid targets")
check(counters.floodWrites == beforeSecond.floodWrites,
  "the second cold load flood-cleared all Crystal sprites again")
check(counters.encodes == beforeSecond.encodes,
  "the second cold load rewrote valid Crystal cache targets")
check(counters.targetDecodes - beforeSecond.targetDecodes == 604,
  "the second cold load did not validate every persisted cache target")
check(targets[1]:match("^ka_sprite_cache_v9_") ~= nil,
  "Crystal cache targets do not carry the v9 preparation recipe version")

local changedRelative = relativePaths[1]
local originalTarget = targets[1]
sources[changedRelative] = sources[changedRelative] .. " revision B"
local beforeChanged = counters.sourceDecodes
local changedTarget = second.crystal(changedRelative)
check(changedTarget ~= originalTarget,
  "changed Crystal source bytes reused a stale cache target")
check(counters.sourceDecodes == beforeChanged + 1,
  "changed Crystal source bytes did not rebuild their cache target")

local beforeChangedCold = counters.sourceDecodes
check(factory(mod).crystal(changedRelative) == changedTarget,
  "the rebuilt source-addressed target was not reusable after a cold load")
check(counters.sourceDecodes == beforeChangedCold,
  "a valid rebuilt target decoded its unchanged source again")

cache[changedTarget] = "corrupt"
local beforeCorrupt = {
  sourceDecodes = counters.sourceDecodes,
  floodWrites = counters.floodWrites,
  encodes = counters.encodes,
}
check(factory(mod).crystal(changedRelative) == changedTarget,
  "a corrupt cache target did not rebuild at its deterministic path")
check(counters.sourceDecodes == beforeCorrupt.sourceDecodes + 1
    and counters.floodWrites == beforeCorrupt.floodWrites + 1
    and counters.encodes == beforeCorrupt.encodes + 1,
  "a corrupt cache target was reused instead of rebuilt")

cache[changedTarget] = nil
local beforeMissing = {
  sourceDecodes = counters.sourceDecodes,
  floodWrites = counters.floodWrites,
  encodes = counters.encodes,
}
check(factory(mod).crystal(changedRelative) == changedTarget,
  "a missing cache target did not rebuild at its deterministic path")
check(counters.sourceDecodes == beforeMissing.sourceDecodes + 1
    and counters.floodWrites == beforeMissing.floodWrites + 1
    and counters.encodes == beforeMissing.encodes + 1,
  "a missing cache target was not rebuilt")

sources[changedRelative] = nil
local beforeAbsent = counters.sourceDecodes
check(factory(mod).crystal(changedRelative) == nil,
  "an absent packaged Crystal source returned a cache target")
check(counters.sourceDecodes == beforeAbsent,
  "an absent packaged Crystal source reached the image decoder")

love = previousLove

print(("SPRITE ASSETS CRYSTAL CACHE PASS: %d checks"):format(checks))
