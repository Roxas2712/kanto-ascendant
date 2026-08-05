-- Real-engine collision and reachability gate for Driftglass Outpost.
--
-- Run from the Gen1 Recomp checkout:
--   KANTO_SIGNALS_MOD_DIR=../kanto-signals-staging \
--   ./.tools/luajit-src/src/luajit \
--   ../kanto-signals-staging/tests/johto_signals_map_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")

local root = os.getenv("KANTO_SIGNALS_MOD_DIR")
  or "../kanto-signals-staging"
local ContentModule =
  assert(loadfile(root .. "/johto_signals_content.lua"))()

local function registry()
  local values = {}
  return {
    values = values,
    register = function(_, id, value)
      assert(values[id] == nil, "duplicate registration: " .. id)
      values[id] = value
    end,
  }
end

local maps, items, scripts, mapSongs =
  registry(), registry(), registry(), registry()
local mod = {
  id = "trainer_rematch",
  content = {
    maps = maps,
    items = items,
    map_scripts = scripts,
    map_songs = mapSongs,
  },
}
local state = {
  section = function() return {} end,
  persist = function() end,
}
local content = ContentModule.create(mod, { state = state })
assert(content.register())

local Data = require("src.core.Data")
Data:load()
local Map = require("src.world.Map")
local SaveData = require("src.core.SaveData")
local def = assert(maps.values[content.MAP_ID])
assert(def.tileset == "OVERWORLD",
  "Driftglass must reuse the active Red/Blue/Yellow OVERWORLD tileset")
assert(def.palette == "CERULEAN",
  "Driftglass must use the shared water-blue CERULEAN palette")

-- A map palette is a named SGB/CGB palette, not a free-form mood label.
-- Guard every committed pack as well as the active imported ROM table so
-- Driftglass cannot silently fall back to uncoloured DMG rendering again.
local PaletteFX = require("src.render.PaletteFX")
local GameVersion = require("src.core.GameVersion")
local importedPalettes = Data.palettes and Data.palettes.palettes
if importedPalettes then
  assert(importedPalettes[def.palette],
    "active imported ROM has no Driftglass palette " .. def.palette)
end
local gbcPack = assert(PaletteFX.gbcPack(),
  "ADVANCED palette pack is unavailable")
local yellowPack = assert(PaletteFX.yellowPack(),
  "Yellow palette pack is unavailable")
assert(gbcPack.palettes and gbcPack.palettes[def.palette],
  "ADVANCED has no Driftglass palette " .. def.palette)
assert(yellowPack.palettes and yellowPack.palettes[def.palette],
  "Yellow SGB has no Driftglass palette " .. def.palette)
assert(yellowPack.cgbBase and yellowPack.cgbBase[def.palette],
  "OG YELLOW has no Driftglass palette " .. def.palette)

local previousVersion, previousMode = GameVersion.get(), PaletteFX.mode
for _, version in ipairs({ "red", "blue", "yellow" }) do
  GameVersion.set(version)
  for _, mode in ipairs({ "ogred", "redpp" }) do
    PaletteFX.mode = mode
    assert(PaletteFX.pal(Data, def.palette),
      ("%s %s cannot colour Driftglass with %s")
        :format(version, mode, def.palette))
  end
  -- SGB uses the active ROM's named table. The legal fixture intentionally
  -- omits imported palettes; imported Red/Blue/Yellow runs exercise it.
  if importedPalettes or version == "yellow" then
    PaletteFX.mode = "gbc"
    assert(PaletteFX.pal(Data, def.palette),
      ("%s SGB cannot colour Driftglass with %s")
        :format(version, def.palette))
  end
end
GameVersion.set(previousVersion)
PaletteFX.mode = previousMode

local tileset = Data.tilesets[def.tileset]

-- Defence in depth for a pre-6.0/custom save that still names Driftglass:
-- with the mod absent from merged data, the real engine validator must move
-- it to its native heal point before OverworldController boots.
local modOffProbe = SaveData.newGame(Data.field.boot)
modOffProbe.player.map = content.MAP_ID
modOffProbe.player.x = content.ARRIVAL.x
modOffProbe.player.y = content.ARRIVAL.y
modOffProbe.lastOutdoor = {
  id = content.MAP_ID,
  x = content.ARRIVAL.x,
  y = content.ARRIVAL.y,
}
modOffProbe.lastHeal = {
  map = "PALLET_TOWN",
  x = content.PALLET_RETURN.x,
  y = content.PALLET_RETURN.y,
}
local modOffReport = SaveData.validate(modOffProbe, Data)
assert(Data.maps[modOffProbe.player.map],
  "engine mod-off validation did not rescue Driftglass to a native map")
assert(modOffProbe.player.map ~= content.MAP_ID,
  "engine mod-off validation retained the unavailable custom map")
if Data.maps.PALLET_TOWN then
  assert(modOffProbe.player.map == "PALLET_TOWN",
    "engine mod-off validation did not rescue Driftglass to Pallet")
  assert(modOffProbe.player.x == content.PALLET_RETURN.x
      and modOffProbe.player.y == content.PALLET_RETURN.y,
    "engine mod-off validation did not preserve the native heal cell")
end
assert(modOffProbe.lastOutdoor == nil,
  "engine mod-off validation kept a dangling custom lastOutdoor")
assert(#modOffReport.remappedMaps >= 2,
  "engine mod-off validation did not report both custom map references")

-- GitHub's legal ROM-free fixture deliberately contains only FIX_OUT.  It
-- can still gate the complete authored map record, while a local imported
-- Red/Blue/Yellow data set runs the stronger collision flood below.
if not tileset then
  assert(Data.tilesets.FIX_OUT,
    "neither an imported OVERWORLD nor the official fixture is available")
  assert(def.index >= 1000, "custom map index must stay outside ROM ids")
  assert(#def.blocks == def.width * def.height,
    "Driftglass block grid is not rectangular")
  local widthCells, heightCells = def.width * 2, def.height * 2
  local function inBounds(x, y)
    return type(x) == "number" and type(y) == "number"
      and x >= 0 and y >= 0 and x < widthCells and y < heightCells
  end
  assert(inBounds(content.ARRIVAL.x, content.ARRIVAL.y),
    "arrival is outside the authored map record")
  local occupied = {}
  for _, object in ipairs(def.objects or {}) do
    assert(inBounds(object.x, object.y),
      object.name .. " is outside the authored map record")
    local key = tostring(object.x) .. ":" .. tostring(object.y)
    assert(not occupied[key], "two Driftglass NPCs overlap at " .. key)
    occupied[key] = true
  end
  assert(not occupied[tostring(content.ARRIVAL.x)
      .. ":" .. tostring(content.ARRIVAL.y)],
    "arrival overlaps an authored NPC")
  for _, sign in ipairs(def.signs or {}) do
    assert(inBounds(sign.x, sign.y),
      "a Driftglass sign is outside the authored map record")
  end
  print(("JOHTO SIGNALS MAP STRUCTURE PASS: %dx%d cells; "
    .. "real collision gate requires imported R/B/Y data")
    :format(widthCells, heightCells))
  return
end
local map = Map.new(def, tileset)

local function key(x, y) return tostring(x) .. ":" .. tostring(y) end
local occupied = {}
for _, object in ipairs(def.objects or {}) do
  occupied[key(object.x, object.y)] = true
end

local start = content.ARRIVAL
assert(map:inBounds(start.x, start.y), "arrival is outside Driftglass")
assert(map:isWalkableCell(start.x, start.y),
  "arrival is not on walkable ground")
assert(not occupied[key(start.x, start.y)],
  "arrival overlaps an authored NPC")

local seen = { [key(start.x, start.y)] = true }
local queue = { { start.x, start.y } }
local head = 1
while head <= #queue do
  local current = queue[head]
  head = head + 1
  for _, delta in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    local x, y = current[1] + delta[1], current[2] + delta[2]
    local id = key(x, y)
    if not seen[id] and map:inBounds(x, y)
        and map:isWalkableCell(x, y) and not occupied[id] then
      seen[id] = true
      queue[#queue + 1] = { x, y }
    end
  end
end

local function reachableInteraction(x, y, label)
  for _, delta in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    if seen[key(x + delta[1], y + delta[2])] then return end
  end
  error(label .. " has no reachable interaction cell")
end

for _, object in ipairs(def.objects or {}) do
  reachableInteraction(object.x, object.y, object.name)
end
for _, sign in ipairs(def.signs or {}) do
  reachableInteraction(sign.x, sign.y, sign.text)
end

local pallet = Map.new(
  assert(Data.maps[content.PALLET_MAP_ID]),
  assert(Data.tilesets[Data.maps[content.PALLET_MAP_ID].tileset]))
local home = content.PALLET_RETURN
assert(pallet:isWalkableCell(home.x, home.y),
  "the return boat lands on blocked Pallet ground")
assert(pallet:warpAtCell(home.x, home.y) == nil,
  "the return boat lands on a Pallet warp")

local safePreferred = 0
for _, cell in ipairs(content.PALLET_BOAT.preferred) do
  if pallet:isWalkableCell(cell[1], cell[2])
      and pallet:warpAtCell(cell[1], cell[2]) == nil then
    safePreferred = safePreferred + 1
  end
end
assert(safePreferred == #content.PALLET_BOAT.preferred,
  "one or more preferred Pallet boat cells are unsafe")

print(("JOHTO SIGNALS MAP PASS: %d reachable cells, %d safe Pallet cells")
  :format(#queue, safePreferred))
