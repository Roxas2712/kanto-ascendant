-- Collision audit against the imported Gen-I Celadon and Indigo maps.

local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR must point at the read-only test runtime")
local generated = os.getenv("GEN1RECOMP_DATA_DIR") or engine
package.path = generated .. "/?.lua;" .. generated .. "/?/init.lua;"
  .. engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
love = require("tests.love_stub")

local source = debug.getinfo(1, "S").source:sub(2)
local ROOT = source:match("^(.*)/tests/[^/]+$") or "."
local Data = require("src.core.Data")
Data:load()
local RuntimeMap = require("src.world.Map")

local spawned = {}
local function key(x, y) return x .. "," .. y end
local placement = assert(loadfile(ROOT .. "/runtime_npc_placement.lua"))()({
  exports = {},
}, { random = function() return 1 end })

local function runtimeMap(mapId)
  local def = assert(Data.maps[mapId], mapId .. " unavailable")
  return RuntimeMap.new(def, assert(Data.tilesets[def.tileset])), def
end

local function overworld(map)
  return {
    map = map, player = { cellX = -1, cellY = -1 },
    npcAtCell = function(_, x, y) return spawned[key(x, y)] end,
  }
end

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

local celadon = runtimeMap("CELADON_CITY")
local celadonOw = overworld(celadon)
local verdant = relics.quests.chikorita
for _, cell in ipairs(verdant.preferred) do
  assert(placement.candidateSafe(celadonOw, cell[1], cell[2]),
    ("Verdant Relic candidate %d,%d is unsafe in Celadon")
      :format(cell[1], cell[2]))
end
for _, cell in ipairs({ { 31, 21 }, { 30, 21 }, { 31, 20 } }) do
  assert(not placement.candidateSafe(celadonOw, cell[1], cell[2]),
    ("old Game Corner alley candidate %d,%d was not reproduced as unsafe")
      :format(cell[1], cell[2]))
end

local ascendantData = assert(loadfile(ROOT .. "/ascendant_data.lua"))()
local grandTourData = assert(loadfile(ROOT .. "/grand_tour_data.lua"))()
local johtoMastersData = assert(loadfile(ROOT .. "/johto_masters_data.lua"))()
local eventData = assert(loadfile(ROOT .. "/event_data.lua"))()
local johtoData = assert(loadfile(ROOT .. "/johto_data.lua"))()
local indigo = runtimeMap("INDIGO_PLATEAU_LOBBY")
local indigoOw = overworld(indigo)
local hosts = {
  { "Tournament", ascendantData.tournament },
  { "New Game Plus", ascendantData.newGamePlus },
  { "Johto Masters", johtoMastersData },
  { "Battle Factory", grandTourData.factory },
}
for _, row in ipairs(hosts) do
  local label, def = row[1], row[2]
  for _, cell in ipairs(def.preferred) do
    assert(placement.candidateSafe(indigoOw, cell[1], cell[2]),
      ("%s candidate %d,%d is unsafe in the real lobby")
        :format(label, cell[1], cell[2]))
  end
  local x, y = placement.findWideRandom(indigoOw, def.preferred)
  assert(x and y, label .. " has no free public-lobby candidate")
  spawned[key(x, y)] = label
end

-- Every old broken definition is either occupied, a wall/counter cell or has
-- an obstructed approach footprint in the real lobby.
for label, cells in pairs({
  tournament = { { 7, 5 }, { 8, 5 }, { 7, 6 } },
  steward = { { 4, 5 }, { 5, 5 }, { 4, 6 } },
  factory = { { 13, 5 }, { 12, 5 }, { 13, 6 }, { 12, 6 } },
}) do
  local unsafe = 0
  for _, cell in ipairs(cells) do
    if not placement.candidateSafe(indigoOw, cell[1], cell[2]) then
      unsafe = unsafe + 1
    end
  end
  assert(unsafe == #cells, label .. " old staff-area list was not fully unsafe")
end

-- Audit every optional wide host against its actual edition map, then activate
-- every host sharing a map at once. Dynamic occupancy must select another
-- vetted cell or fail closed; it may never escape into an arbitrary map row.
local allWide = {
  ascendantData.tournament, ascendantData.newGamePlus,
  grandTourData.factory, johtoMastersData,
}
for _, cup in pairs(eventData.cups or {}) do allWide[#allWide + 1] = cup end
for _, guide in pairs(johtoData.starters or {}) do
  allWide[#allWide + 1] = guide
end
for _, relic in pairs(relics.quests or {}) do
  if relic.map then allWide[#allWide + 1] = relic end
end

local byMap = {}
for _, def in ipairs(allWide) do
  byMap[def.map] = byMap[def.map] or {}
  byMap[def.map][#byMap[def.map] + 1] = def
  spawned = {}
  local map = runtimeMap(def.map)
  local ow = overworld(map)
  for _, cell in ipairs(def.preferred or {}) do
    assert(placement.candidateSafe(ow, cell[1], cell[2]),
      ((def.name or def.npc) .. " has unsafe authored candidate %d,%d on %s")
        :format(cell[1], cell[2], def.map))
  end
end
for mapId, definitions in pairs(byMap) do
  spawned = {}
  local map = runtimeMap(mapId)
  local ow = overworld(map)
  for _, def in ipairs(definitions) do
    local x, y = placement.findWideRandom(ow, def.preferred)
    assert(x and y, (def.name or def.npc) .. " has no simultaneous safe cell")
    spawned[key(x, y)] = def.name or def.npc
  end
end

print("runtime_npc_public_placement_engine_test: PASS")
