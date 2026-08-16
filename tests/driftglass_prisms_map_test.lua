-- Real-engine collision, palette and reachability gate for Prism Grotto.
--
-- Run from the Gen1 Recomp checkout:
--   KANTO_SIGNALS_MOD_DIR=../kanto-ascendant \
--   ./.tools/luajit-src/src/luajit \
--   ../kanto-ascendant/tests/driftglass_prisms_map_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
love = require("tests.love_stub")

local root = os.getenv("KANTO_SIGNALS_MOD_DIR")
  or "../kanto-ascendant"
local ContentModule =
  assert(loadfile(root .. "/johto_signals_content.lua"))()
local PrismModule =
  assert(loadfile(root .. "/driftglass_prisms.lua"))()

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
  id = "kanto_ascendant",
  content = {
    maps = maps,
    items = items,
    map_scripts = scripts,
    map_songs = mapSongs,
  },
  events = { on = function() end },
}
local roots = {
  earlyJohto = { receiverRepaired = true },
  prismGrotto = {},
}
local state = {
  section = function(name)
    roots[name] = roots[name] or {}
    return roots[name]
  end,
  persist = function() end,
}
local content = ContentModule.create(mod, { state = state })
assert(content.register())
local prism = PrismModule.create(mod, {
  state = state,
  content = content,
})
assert(prism.register())

local Data = require("src.core.Data")
Data:load()
local Map = require("src.world.Map")
local def = assert(maps.values[prism.MAP_ID])
assert(def.tileset == "CAVERN",
  "Prism Grotto must reuse the native CAVERN tileset")
assert(def.palette == "CAVE",
  "Prism Grotto must use the native cave palette")
assert(def.index >= 1000, "custom map index must stay outside ROM ids")
assert(#def.blocks == def.width * def.height,
  "Prism Grotto block grid is not rectangular")

local widthCells, heightCells = def.width * 2, def.height * 2
local function inBounds(x, y)
  return type(x) == "number" and type(y) == "number"
    and x >= 0 and y >= 0 and x < widthCells and y < heightCells
end
assert(inBounds(prism.ARRIVAL.x, prism.ARRIVAL.y),
  "Prism Grotto arrival is outside the authored map")
assert(inBounds(prism.EXIT_STEP.x, prism.EXIT_STEP.y),
  "Prism Grotto exit step is outside the authored map")
assert(inBounds(prism.EXIT_ARCH.x, prism.EXIT_ARCH.y),
  "Prism Grotto exit arch is outside the authored map")

local occupied = {}
local function key(x, y) return tostring(x) .. ":" .. tostring(y) end
for _, object in ipairs(def.objects or {}) do
  assert(inBounds(object.x, object.y),
    object.name .. " is outside Prism Grotto")
  local id = key(object.x, object.y)
  assert(not occupied[id], "two Prism objects overlap at " .. id)
  occupied[id] = true
end
assert(not occupied[key(prism.ARRIVAL.x, prism.ARRIVAL.y)],
  "Prism Grotto arrival overlaps an object")
assert(not occupied[key(prism.EXIT_STEP.x, prism.EXIT_STEP.y)],
  "Prism Grotto movement exit is blocked by a static map object")
local exitArch
for _, object in ipairs(def.objects or {}) do
  if object.name == "PRISM_EXIT_ARCH" then exitArch = object break end
end
assert(exitArch and exitArch.x == prism.EXIT_ARCH.x
    and exitArch.y == prism.EXIT_ARCH.y,
  "the visible exit arch is not on its documented south approach cell")
assert(type(scripts.values[prism.MAP_ID].onStep) == "function",
  "Prism Grotto does not register its movement exit hook")
for _, sign in ipairs(def.signs or {}) do
  assert(inBounds(sign.x, sign.y),
    "a Prism Grotto sign is outside the map")
end

local tileset = Data.tilesets[def.tileset]
if not tileset then
  assert(Data.tilesets.FIX_OUT,
    "neither imported CAVERN nor the official fixture is available")
  print(("DRIFTGLASS PRISM MAP STRUCTURE PASS: %dx%d cells; "
    .. "real collision gate requires imported R/B/Y data")
    :format(widthCells, heightCells))
  return
end

local PaletteFX = require("src.render.PaletteFX")
local GameVersion = require("src.core.GameVersion")
local previousVersion, previousMode = GameVersion.get(), PaletteFX.mode
for _, version in ipairs({ "red", "blue", "yellow" }) do
  GameVersion.set(version)
  for _, mode in ipairs({ "ogred", "redpp" }) do
    PaletteFX.mode = mode
    assert(PaletteFX.pal(Data, def.palette),
      ("%s %s cannot colour Prism Grotto with %s")
        :format(version, mode, def.palette))
  end
end
GameVersion.set(previousVersion)
PaletteFX.mode = previousMode

local map = Map.new(def, tileset)
local Collision = require("src.world.Collision")
Collision.load(Data)
assert(map:inBounds(prism.ARRIVAL.x, prism.ARRIVAL.y),
  "arrival is outside Prism Grotto")
assert(map:isWalkableCell(prism.ARRIVAL.x, prism.ARRIVAL.y),
  "arrival is not on walkable cave ground")
assert(map:isWalkableCell(prism.EXIT_STEP.x, prism.EXIT_STEP.y),
  "exit trigger is not on walkable cave ground")
assert(map:isWalkableCell(prism.EXIT_ARCH.x, prism.EXIT_ARCH.y),
  "the native cave collision tile under the visible exit changed")

-- CAVERN's 32<->5 elevation pair blocks the apparently-walkable y=14 tile
-- in the real 0.1.96/0.1.98 movement path.  The trigger therefore belongs
-- on the last actually reachable floor cell, one step before that seam.
local mover = {
  cellX = prism.ARRIVAL.x, cellY = prism.ARRIVAL.y, surfing = false,
}
local canReachExit, reachReason =
  Collision.canMove(map, {}, mover, "down")
assert(canReachExit, "arrival cannot enter the exit trigger: "
  .. tostring(reachReason))
mover.cellX, mover.cellY = prism.EXIT_STEP.x, prism.EXIT_STEP.y
local canCrossSeam, seamReason =
  Collision.canMove(map, {}, mover, "down")
assert(not canCrossSeam and seamReason == "tile",
  "test fixture no longer exercises the directed CAVERN seam collision")

local seen = { [key(prism.ARRIVAL.x, prism.ARRIVAL.y)] = true }
local queue = { { prism.ARRIVAL.x, prism.ARRIVAL.y } }
local head = 1
while head <= #queue do
  local current = queue[head]
  head = head + 1
  for _, delta in ipairs({
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
  }) do
    local x, y = current[1] + delta[1], current[2] + delta[2]
    local id = key(x, y)
    if not seen[id] and map:inBounds(x, y)
        and map:isWalkableCell(x, y) and not occupied[id] then
      seen[id] = true
      queue[#queue + 1] = { x, y }
    end
  end
end
assert(seen[key(prism.EXIT_STEP.x, prism.EXIT_STEP.y)],
  "the movement exit cannot be reached from the arrival cell")

local function reachableInteraction(x, y, label)
  for _, delta in ipairs({
    { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 },
  }) do
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

print(("DRIFTGLASS PRISM MAP PASS: %d reachable cells, "
  .. "%d objects and %d signs reachable")
  :format(#queue, #(def.objects or {}), #(def.signs or {})))
