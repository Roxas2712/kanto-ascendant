-- Exact-engine runtime contract for the shared RGB completion stone/door.
--
-- Run from Gen1Recomp 0.1.90 with:
--   POKEPORT_DATA_DIR=/path/to/data/generated \
--   KA_HIDDEN_EVOLUTION_MOD=/path/to/kanto-ascendant \
--     luajit /path/to/tests/hidden_evolution_completion_stone_runtime_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

if not (_G.love and _G.love.image
    and type(_G.love.image.newImageData) == "function") then
  _G.love = require("tests.love_stub")
end

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local modName = root:gsub("/+$", ""):match("[^/]+$")
local modPrefix = "mods/" .. modName
local FsIo = require("tests.fs_io")
local disk = FsIo.new("/")
local memory = {}

-- The SDK's ordinary absolute-root alias is intentionally read-only and has
-- no createDirectory method.  That is correct for content merge tests, but
-- this contract also exercises official mod.storage.  Keep the installed mod
-- tree read-only while routing every engine-owned persistence path to a
-- private in-memory filesystem with the same transactional API.
local function mapped(path)
  if path == modPrefix then return root end
  if path:sub(1, #modPrefix + 1) == modPrefix .. "/" then
    return root .. path:sub(#modPrefix + 1)
  end
end
local function memoryItems(path)
  local prefix, seen, out = path .. "/", {}, {}
  for key in pairs(memory) do
    if key:sub(1, #prefix) == prefix then
      local child = key:sub(#prefix + 1):match("^[^/]+")
      if child and not seen[child] then
        seen[child], out[#out + 1] = true, child
      end
    end
  end
  table.sort(out)
  return out
end
local testFs = {
  read = function(path)
    local real = mapped(path)
    if real then return disk.read(real) end
    return memory[path]
  end,
  write = function(path, body)
    assert(not mapped(path), "completion-stone test tried to write mod source")
    memory[path] = body
    return true
  end,
  remove = function(path)
    assert(not mapped(path), "completion-stone test tried to remove mod source")
    memory[path] = nil
    return true
  end,
  createDirectory = function() return true end,
  load = function(path)
    local real = mapped(path)
    if real then return disk.load(real) end
    local body = memory[path]
    if not body then return nil, "no file: " .. tostring(path) end
    return (loadstring or load)(body, path)
  end,
  getInfo = function(path)
    if path == "mods" then return { type = "directory" } end
    local real = mapped(path)
    if real then return disk.getInfo(real) end
    if memory[path] ~= nil then return { type = "file" } end
    return #memoryItems(path) > 0 and { type = "directory" } or nil
  end,
  getDirectoryItems = function(path)
    if path == "mods" then return { modName } end
    local real = mapped(path)
    if real then return disk.getDirectoryItems(real) end
    return memoryItems(path)
  end,
}
local originalNewImageData = love.image.newImageData
love.image.newImageData = function()
  error("headless HEVO completion-stone test does not author images")
end
local run = T.sdk.loadMod(root, { data = Data, fs = testFs })
love.image.newImageData = originalNewImageData
T.eq(#run.errors, 0, "complete Kanto Ascendant graph loads without errors")

local Font = require("src.render.Font")
local Game = require("src.core.Game")
local Input = require("src.core.Input")
local MapScripts = require("src.script.MapScripts")
local Renderer = require("src.render.Renderer")
local SaveData = require("src.core.SaveData")
local SaveSerializer = require("src.core.SaveSerializer")
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

Game.mods = run.loader

-- Build the old state through the engine's real New Game/storage lifecycle.
-- A released, identified playthrough owns a verified scoped Legacy archive;
-- the compatibility case below is only that its older route-local completion
-- marker predates dungeonLegacy.seals and the shared-room handoff.  Never
-- manufacture archive authority by writing those newer completion records.
local save = SaveData.newGame(Game:bootConfig())
Game.save = save
Game:adoptSave(save)
run.loader.events:emit("game.ready", { game = Game })
run.loader.events:emit("save.created", { save = save })

local exports = assert(run.loader.exports.kanto_ascendant)
local journey = assert(exports.legacyJourney)
local archive = assert(journey.archive)
local initialArchive = assert(archive.load())
local archiveWritten, archiveWriteErr = archive.write(initialArchive)
assert(archiveWritten, archiveWriteErr)
assert(type(archive.load()) == "table",
  "official scoped Legacy archive did not survive readback")

-- Stock 0.1.90 allocates a playthrough identity on first storage access.  Its
-- offline-migration receipt is the exact authority an identified older save
-- carries.  Edition-scoped clients need no playthrough receipt and retain the
-- genuine save.new_game origin marker instead.
local playthroughId = save.meta and save.meta.playthroughId
if type(playthroughId) == "string" and playthroughId ~= "" then
  local bound, bindErr = archive.stampStorageBinding(save, {
    playthroughId = playthroughId,
  })
  assert(bound, bindErr)
  local binding, bindingErr = archive.storageBinding(save)
  assert(binding and binding.playthroughId == playthroughId, bindingErr)
else
  local fresh = save.modData and save.modData.kanto_ascendant
    and save.modData.kanto_ascendant.legacy_fresh_origin
  assert(type(fresh) == "table",
    "edition-scoped save lost its genuine New Game origin authority")
end

-- This is the released RED compatibility boundary: the old route controller
-- durably recorded its own completed marker after all five questions and all
-- three Strength sockets, but an interrupted/older save can lack the newer
-- dungeonLegacy seal and shared-room handoff records.  Extend (never replace)
-- the mod bucket so the verified archive lineage survives serialization.
save.player.name = "RED"
save.player.map, save.player.x, save.player.y, save.player.facing =
  "KA_HEVO_SHARED_SEALED_ANTECHAMBER", 3, 21, "up"
save.flags = save.flags or {}
save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
local bucket = save.modData.kanto_ascendant
bucket.beyond_kanto = {
  version = 1, active = true, irreversible = true,
  decision = "player_confirmed",
}
bucket.extended_characters = { player_character = "RED" }
bucket.hevo_run = {
  cycle = 1,
  red = {
    sight = 5, completed = true,
    boulders = { A = true, B = true, C = true },
  },
}
save.options.modOptions = save.options.modOptions or {}
save.options.modOptions.kanto_ascendant = { living_world_enabled = false }
save = assert(SaveSerializer.decode(SaveSerializer.encode(save)))
run.loader.modOptions.kanto_ascendant = { living_world_enabled = false }

Game.save = save
Game:adoptSave(save)
run.loader.events:emit("save.loaded", { save = save })

local campaign = assert(exports.hiddenEvolutionCampaign)
local shared = assert(campaign.modules.shared)
local red = assert(campaign.modules.RED)
assert(exports.legacyDungeonAdapter.character(save) == "RED",
  "fixture lost RED adapter authority")
assert(exports.beyondKanto.isActive(save) == true,
  "fixture lost Beyond-Kanto authority")
assert(red.canEnterShrine(save) == true,
  "fixture lost the five-question/three-socket RED gate")

StateStack:push(Overworld, shared.ID, 3, 21, "up", { via = "boot" })
local ow = assert(Game.overworld, "real OverworldState was not entered")
T.eq(ow.map.id, shared.ID, "runtime entered shared completion room")

local door
for _, npc in ipairs(ow.npcs or {}) do
  if npc.def and npc.def.name == shared.DOOR then door = npc end
end
door = assert(door, "live shared RGB completion stone is missing")
T.eq(door.cellX, 15, "shared RGB completion stone keeps cell x=15")
T.eq(door.cellY, 5, "shared RGB completion stone keeps cell y=5")
T.eq(door.def.text, shared.TEXT,
  "shared RGB completion stone keeps its talk constant")
T.eq(type(MapScripts.talkScript(shared.ID, shared.TEXT)), "function",
  "real merged MapScripts owns the completion-stone callback")

-- The arrival/reload lifecycle must recover the older RED completion marker
-- through the normal character-bound adapter before the player presses A.
local sealedBefore, ownerBefore = journey.currentHevoSeal(save, "RED")
local repairedRun = save.modData.kanto_ascendant.hevo_run
T.eq(repairedRun and repairedRun.dungeonLegacy
    and repairedRun.dungeonLegacy.seals
    and repairedRun.dungeonLegacy.seals.RED, true,
  "shared-room lifecycle backfills the raw RED dungeon seal")
T.eq(sealedBefore, true,
  "shared-room save lifecycle repairs the completed RED seal")
T.eq(ownerBefore, "RED", "repaired seal remains RED-owned")
local receiptBefore = shared.handoff()
T.check(receiptBefore and receiptBefore.character == "RED"
    and receiptBefore.seal == true,
  "shared-room lifecycle creates the durable RED handoff")

-- Exercise the actual engine A path: facingCell -> npcAtCell -> talkTo ->
-- merged MapScripts callback.  No helper or talk closure is called directly.
ow.player.cellX, ow.player.cellY, ow.player.facing = 15, 6, "up"
ow.player.px, ow.player.py = 15 * 16, 6 * 16
T.eq(ow:npcAtCell(ow.player:facingCell()), door,
  "player at (15,6) faces the RGB completion stone at (15,5)")
local topBefore = Game.stack:top()
ow:interact()
T.check(Game.stack:top() ~= topBefore,
  "real A press opens completion feedback")

local story = save.modData.kanto_ascendant.hidden_evolution_story_campaign
T.eq(story and story.doorVisits and story.doorVisits.RED, true,
  "real A press persists the RED RGB-door visit")
T.eq(story and story.handoff and story.handoff.acknowledged, true,
  "real A press acknowledges the durable RED handoff")
T.check(story and story.handoff
    and (story.handoff.stoneStatus == "granted"
      or story.handoff.stoneStatus == "claimed"),
  "completion lifecycle records a verified BLAZIKENITE result")

run.release()
T.finish("hidden_evolution_completion_stone_runtime_test")
