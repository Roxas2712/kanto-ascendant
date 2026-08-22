local source = debug.getinfo(1, "S").source:sub(2)
local ROOT = source:match("^(.*)/tests/[^/]+$") or "."

local function check(value, message)
  if not value then error(message, 2) end
end

local function key(x, y) return tostring(x) .. "," .. tostring(y) end

local randomCalls = 0
local makePlacement = assert(loadfile(ROOT .. "/runtime_npc_placement.lua"))()
local placement = makePlacement({
  exports = {},
}, {
  random = function(limit)
    randomCalls = randomCalls + 1
    return limit
  end,
})

local hazards = {
  blocked = {}, warp = {}, warpTile = {}, sign = {}, npc = {},
  wild = {}, reserved = {}, authored = {},
}
local occupancy = {
  isOccupied = function(_, x, y) return hazards.wild[key(x, y)] end,
  isReserved = function(_, x, y) return hazards.reserved[key(x, y)] end,
}
local placementMod = {
  exports = { internalWilds = { exports = {
    occupancy = function() return occupancy end,
  } } },
}
placement = makePlacement(
  placementMod, {
    random = function(limit)
      randomCalls = randomCalls + 1
      return limit
    end,
  })

local map = {
  def = { objects = {} }, widthCells = 20, heightCells = 20,
  inBounds = function(_, x, y) return x >= 0 and y >= 0 and x < 20 and y < 20 end,
  isWalkableCell = function(_, x, y) return not hazards.blocked[key(x, y)] end,
  warpAtCell = function(_, x, y) return hazards.warp[key(x, y)] end,
  isWarpTileCell = function(_, x, y) return hazards.warpTile[key(x, y)] end,
  signAtCell = function(_, x, y) return hazards.sign[key(x, y)] end,
}
local ow = {
  map = map, player = { cellX = 1, cellY = 1 },
  npcAtCell = function(_, x, y) return hazards.npc[key(x, y)] end,
}

local candidates = { { 5, 5 }, { 10, 10 } }
local x, y = placement.findWideRandom(ow, candidates)
check(x == 10 and y == 10, "random placement did not choose among safe cells")
check(randomCalls == 1, "random placement did not use the injected RNG once")

-- A hazard anywhere in the host's 3x2 footprint rejects that candidate.
for _, row in ipairs({
  { "blocked", 4, 6 }, { "warp", 5, 5 }, { "warpTile", 6, 6 },
  { "sign", 4, 5 }, { "npc", 6, 5 }, { "wild", 5, 6 },
  { "reserved", 4, 6 },
}) do
  hazards[row[1]][key(row[2], row[3])] = true
  check(not placement.candidateSafe(ow, 5, 5),
    "wide placement accepted " .. row[1])
  hazards[row[1]][key(row[2], row[3])] = nil
end
map.def.objects = { { x = 6, y = 6, name = "STORY_NPC" } }
check(not placement.candidateSafe(ow, 5, 5),
  "wide placement accepted an authored object")
map.def.objects = {}

-- No whole-map fallback is allowed when every authored candidate is unsafe.
hazards.sign[key(4, 6)] = true
hazards.warp[key(9, 10)] = true
x, y = placement.findWideRandom(ow, candidates)
check(x == nil and y == nil,
  "bounded placement escaped to an arbitrary map cell")
hazards.sign[key(4, 6)] = nil
hazards.warp[key(9, 10)] = nil

local relicMod = {
  save = { get = function() end, set = function() end },
  hooks = { wrap = function() end }, events = { on = function() end },
  world = {}, ui = {},
}
local relics = assert(loadfile(ROOT .. "/starter_relic_quests.lua"))()(relicMod, {
  placement = placement,
  megaEvolution = {
    hasStone = function() return false end,
    grantStone = function() return false end,
  },
  ascendantTyphlosion = {
    state = function() end, goldCleared = function() return false end,
    ownedCount = function() return 0 end, typhlosion = function() end,
    ready = function() return false end, statusText = function() return "" end,
  },
})
local verdant = assert(relics.quests.chikorita)
check(verdant.preferred[1][1] == 36 and verdant.preferred[1][2] == 12,
  "Verdant Relic keeper still starts in the Game Corner alley")
for _, cell in ipairs(verdant.preferred) do
  check(not (cell[2] >= 19 and cell[2] <= 21),
    "Verdant Relic candidate still blocks the Game Corner approach")
end

local ascendantData = assert(loadfile(ROOT .. "/ascendant_data.lua"))()
local grandTourData = assert(loadfile(ROOT .. "/grand_tour_data.lua"))()
local johtoMastersData = assert(loadfile(ROOT .. "/johto_masters_data.lua"))()
local eventData = assert(loadfile(ROOT .. "/event_data.lua"))()
local johtoData = assert(loadfile(ROOT .. "/johto_data.lua"))()
local indigo = {
  tournament = ascendantData.tournament,
  steward = ascendantData.newGamePlus,
  factory = grandTourData.factory,
  johto = johtoMastersData,
}
for label, def in pairs(indigo) do
  check(def.map == "INDIGO_PLATEAU_LOBBY", label .. " moved off Indigo")
  check(type(def.publicArea) == "table", label .. " has no public-area guard")
  check(type(def.preferred) == "table" and #def.preferred >= 2,
    label .. " needs multiple random-safe visitor cells")
  for _, cell in ipairs(def.preferred) do
    check(cell[1] >= def.publicArea.minX and cell[1] <= def.publicArea.maxX
        and cell[2] >= def.publicArea.minY and cell[2] <= def.publicArea.maxY,
      label .. " candidate escapes the visitor area")
    check(cell[2] >= 8 and cell[2] <= 9,
      label .. " candidate is behind the service counter or in a wall")
  end
end

local expected = {
  { "University Cup", eventData.cups.university_magikarp, 14, 12 },
  { "Stamp Sky Cup", eventData.cups.stamp_fearow, 16, 12 },
  { "Balloon Cup", eventData.cups.flying_pikachu, 24, 14 },
  { "Stamp Fire Cup", eventData.cups.stamp_rapidash, 46, 29 },
  { "Wave Cup", eventData.cups.surfing_pikachu, 12, 20 },
  { "Verdant Guide", johtoData.starters.chikorita, 16, 22 },
  { "Ember Guide", johtoData.starters.cyndaquil, 7, 12 },
  { "Torrent Guide", johtoData.starters.totodile, 16, 20 },
}
for _, row in ipairs(expected) do
  local def = assert(row[2], row[1] .. " definition missing")
  check(def.preferred[1][1] == row[3] and def.preferred[1][2] == row[4],
    row[1] .. " still starts in its reported unsafe area")
end

local function read(path)
  local file = assert(io.open(ROOT .. "/" .. path, "rb"))
  local text = file:read("*a")
  file:close()
  return text
end
for _, path in ipairs({
  "ascendant.lua", "grand_tour.lua", "johto_masters.lua",
  "starter_relic_quests.lua", "event_archive.lua", "johto_research.lua",
}) do
  check(read(path):find("findWideRandom", 1, true),
    path .. " does not use bounded randomized wide placement")
end
check(read("main.lua"):find("runtimeNpcPlacement", 1, true),
  "main.lua does not wire the shared runtime placement helper")

print("runtime_npc_public_placement_test: PASS")
