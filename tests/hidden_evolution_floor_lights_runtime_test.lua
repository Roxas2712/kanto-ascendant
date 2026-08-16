-- Exact-engine runtime contract for HEVO's first RED floor light and the
-- passable metadata anchors around it.
--
-- Run from Gen1Recomp 0.1.90 with:
--   POKEPORT_DATA_DIR=/path/to/data/generated \
--   KA_HIDDEN_EVOLUTION_MOD=/path/to/kanto-ascendant \
--     luajit /path/to/tests/hidden_evolution_floor_lights_runtime_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

-- Some richer headless authorities predeclare a partial `love` table.  The
-- SDK harness only installs its complete stub when `love` is entirely nil,
-- so normalize that partial case before importing the harness.
if not (_G.love and _G.love.image
    and type(_G.love.image.newImageData) == "function") then
  _G.love = require("tests.love_stub")
end
local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."

-- Loading the complete graph is required for the real merged map-script
-- chain.  Suppress only SDK image authoring so this headless contract never
-- writes derived PNGs; all gameplay modules still receive the normal LÖVE
-- stub and therefore keep their real runtime globals.
local originalNewImageData = love.image.newImageData
love.image.newImageData = function()
  error("headless HEVO runtime test does not author images")
end
local run = T.sdk.loadMod(root, { data = Data, root = sdkRoot })
love.image.newImageData = originalNewImageData
T.eq(#run.errors, 0, "complete Kanto Ascendant graph loads without errors")

local Collision = require("src.world.Collision")
local Font = require("src.render.Font")
local Game = require("src.core.Game")
local Input = require("src.core.Input")
local Renderer = require("src.render.Renderer")
local SaveData = require("src.core.SaveData")
local StateStack = require("src.core.StateStack")
local Overworld = require("src.world.OverworldController")

Game.data = Data
Game.input = Input
Input:init()
Game.renderer = Renderer
Renderer:init()
Game.stack = StateStack
StateStack:init()
Font.load(Data)

local save = SaveData.newGame()
save.player.name = "RED"
save.player.map = "KA_HEVO_RED_UPPER"
local redEntrance = assert(Data.maps.KA_HEVO_RED_UPPER.warps[1],
  "RED upper entrance warp missing")
save.player.x, save.player.y, save.player.facing =
  redEntrance.x, redEntrance.y, "up"
save.modData.kanto_ascendant = {
  extended_characters = { player_character = "RED" },
  hevo_run = { cycle = 1 },
}
save.options.modOptions = save.options.modOptions or {}
save.options.modOptions.kanto_ascendant = {
  living_world_enabled = false,
}
run.loader.modOptions.kanto_ascendant = {
  living_world_enabled = false,
}

Game.save = save
Game.mods = run.loader
run.loader.modSave = save.modData
run.loader.events:emit("game.ready", { game = Game })

local campaign = assert(run.loader.exports.kanto_ascendant
  .hiddenEvolutionCampaign, "HEVO campaign export missing")
local lights = assert(campaign.floorLights, "floor-light export missing")

StateStack:push(Overworld, "KA_HEVO_RED_UPPER",
  redEntrance.x, redEntrance.y, "up", { via = "boot" })
local ow = assert(Game.overworld, "real OverworldState was not entered")
T.eq(ow.map.id, "KA_HEVO_RED_UPPER", "runtime entered RED upper")

local function npcNamed(name)
  for _, npc in ipairs(ow.npcs or {}) do
    if npc.def and npc.def.name == name then return npc end
  end
end

local reset = assert(npcNamed("KA_RED_RESET_UPPER"),
  "RED reset metadata anchor missing")
T.eq(reset.def.passable, true, "RED reset definition is explicitly passable")
T.eq(reset.passable, true,
  "0.1.90 live RED reset anchor inherits authored passability")
T.eq(Collision.occupied(ow.entities, reset.cellX, reset.cellY, ow.player), nil,
  "RED reset anchor is not an invisible live collision wall")

-- Build the actual dry-foot collision component from the map entrance.  This
-- uses native Collision.canMove with the live NPC set; it neither assumes a
-- light coordinate nor treats passable=true definitions as free by fiat.
local directions = {
  { name = "up", dx = 0, dy = -1 },
  { name = "down", dx = 0, dy = 1 },
  { name = "left", dx = -1, dy = 0 },
  { name = "right", dx = 1, dy = 0 },
}
local collisionEntities = {}
for _, entity in ipairs(ow.entities or {}) do
  if entity ~= ow.player then collisionEntities[#collisionEntities + 1] = entity end
end
local queue = { { x = redEntrance.x, y = redEntrance.y } }
local seen = { [redEntrance.x .. "," .. redEntrance.y] = true }
local cursor = 1
while queue[cursor] do
  local point = queue[cursor]
  cursor = cursor + 1
  for _, direction in ipairs(directions) do
    local x, y = point.x + direction.dx, point.y + direction.dy
    local key = x .. "," .. y
    local probe = { cellX = point.x, cellY = point.y, surfing = false }
    if not seen[key]
        and Collision.canMove(ow.map, collisionEntities, probe,
          direction.name) then
      seen[key] = true
      queue[#queue + 1] = { x = x, y = y }
    end
  end
end
T.eq(seen[reset.cellX .. "," .. reset.cellY], true,
  "real collision graph reaches the RED reset anchor")

local stone = assert(npcNamed("KA_HEVO_FLOOR_LIGHT_RED_UPPER_1"),
  "first RED upper light missing from the live map")
T.eq(stone.def.index, 9, "first RED upper light keeps merged object index 9")
T.eq(stone.def.name, "KA_HEVO_FLOOR_LIGHT_RED_UPPER_1",
  "first RED upper light has the stable object name")
T.eq(stone.def.text, "TEXT_KA_HEVO_FLOOR_LIGHT_RED_UPPER_1",
  "first RED upper light has the stable talk id")
T.eq(stone.def.passable, false,
  "first RED upper light definition remains tangible")
T.eq(stone.passable, false,
  "passable-anchor repair never makes the floor light walk-through")
T.eq(lights.stage(save, ow.map.id, Game), 0,
  "fresh RED upper floor begins at light stage zero")
T.eq(ow.kaHevoRedSight.floorStage, 0,
  "live RED sight profile begins at stage zero")
T.eq(ow.kaHevoRedSight.radius, 1.9,
  "live RED sight profile begins at radius 1.9")

local approach
for _, direction in ipairs(directions) do
  local x, y = stone.cellX - direction.dx, stone.cellY - direction.dy
  if seen[x .. "," .. y] then
    approach = { x = x, y = y, facing = direction.name }
    break
  end
end
T.check(approach ~= nil,
  "first RED light has a cardinal approach in the real collision component")
ow.player.cellX, ow.player.cellY = approach.x, approach.y
ow.player.px, ow.player.py = approach.x * 16, approach.y * 16
ow.player.facing = approach.facing
T.eq(ow:npcAtCell(ow.player:facingCell()), stone,
  "the dynamically selected approach faces the first RED light")

-- This is the engine-facing A-button path: facingCell -> npcAtCell ->
-- talkTo -> merged map-script function.  Do not call the light helper or its
-- talk closure directly.
ow:interact()
T.eq(lights.stage(save, ow.map.id, Game), 1,
  "A on first RED light persists floor-local stage one")
T.eq(ow.kaHevoRedSight.floorStage, 1,
  "A on first RED light refreshes the live RED profile")
T.eq(ow.kaHevoRedSight.radius, 20,
  "first RED light expands the live aperture to radius 20")
T.eq(ow.visionRadius, 20,
  "engine-facing compatibility radius follows the floor profile")
T.eq(save.modData.kanto_ascendant.hevo_run.floorLights.floors
    .KA_HEVO_RED_UPPER.lit.KA_HEVO_FLOOR_LIGHT_RED_UPPER_1, true,
  "A interaction writes the exact first-light save record")
T.eq(save.flags.KA_HEVO_FISSURE_DISCOVERED_RED, nil,
  "floor light does not counterfeit researcher/fissure discovery")

-- Reproduce a newly constructed 0.1.90 NPC on another authored HEVO map:
-- def.passable survives, the live field does not.  The map-reload lifecycle
-- must restore that representative GREEN metadata anchor without changing a
-- neighboring solid object.
while StateStack:top() do StateStack:pop() end
save.modData.kanto_ascendant.extended_characters.player_character = "GREEN"
local greenEntrance = assert(Data.maps.KA_HEVO_GREEN_THRESHOLD.warps[1],
  "GREEN threshold entrance warp missing")
StateStack:push(Overworld, "KA_HEVO_GREEN_THRESHOLD",
  greenEntrance.x, greenEntrance.y, "up", { via = "boot" })
ow = assert(Game.overworld)
local greenAnchor = assert(npcNamed("KA_GREEN_SHORTCUT"),
  "representative GREEN shortcut anchor missing")
local greenSolid = assert(npcNamed("KA_GREEN_LANDMARK_THRESHOLD"),
  "representative GREEN solid landmark missing")
T.eq(greenAnchor.def.passable, true,
  "GREEN shortcut definition is explicitly passable")
T.eq(greenAnchor.passable, true,
  "GREEN shortcut is passable after real map entry")
T.check(greenSolid.def.passable ~= true and greenSolid.passable ~= true,
  "GREEN solid landmark remains solid after map entry")

greenAnchor.passable = nil
run.loader.events:emit("map.reloaded", {
  mapId = "KA_HEVO_GREEN_THRESHOLD", map = ow.map,
})
T.eq(greenAnchor.passable, true,
  "map.reloaded restores explicit GREEN anchor passability")
T.check(greenSolid.passable ~= true,
  "map.reloaded still leaves GREEN solid landmark untouched")

run.release()
T.finish("hidden_evolution_floor_lights_runtime_test")
