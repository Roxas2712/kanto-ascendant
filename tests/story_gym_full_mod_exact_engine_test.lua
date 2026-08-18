-- Full-loader proof for the real Beyond-Kanto + repaired-receiver move gate.
-- Run per public engine and official R/B/Y generated-data cache.

local support = assert(os.getenv("KA_ENGINE_SUPPORT_ROOT"),
  "KA_ENGINE_SUPPORT_ROOT is required")
package.path = "./?.lua;./?/init.lua;" .. support .. "/?.lua;"
  .. support .. "/?/init.lua;" .. package.path

local T = require("tests.modkit") -- installs the headless LOVE filesystem
local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
local Data = require("src.core.Data")
local SaveData = require("src.core.SaveData")
local Pokemon = require("src.pokemon.Pokemon")
local BattleState = require("src.battle.BattleState")

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
assert(Version.engine == expectedEngine, "wrong exact engine")
GameVersion.set(edition)
Data:load()

local run = T.sdk.loadMod(root, { data = Data, root = "/" })
assert(run.mod and #(run.errors or {}) == 0,
  "full candidate did not load cleanly on exact engine")
local exports = assert(run.loader.exports.kanto_ascendant)
assert(exports.storyGymDifficulty and exports.beyondKanto,
  "production Story-Gym/Beyond exports missing")
assert(Data.moves.IRON_TAIL and (tonumber(Data.moves.IRON_TAIL.pp) or 0) > 0,
  "production registry did not provide the real Iron Tail definition")

run.loader.modOptions.kanto_ascendant =
  run.loader.modOptions.kanto_ascendant or {}
run.loader.modOptions.kanto_ascendant.difficulty = "high"

local function hasMove(mon, id)
  for _, move in ipairs(mon and mon.moves or {}) do
    if move.id == id then return true end
  end
  return false
end

local function scenario(boundaryActive, receiverRepaired)
  local save = SaveData.newGame({
    version = edition, playerName = "GYMGATE", rivalName = "RIVAL",
  })
  save.party[1] = Pokemon.new(Data, "PIKACHU", 30,
    function(lo, hi) return math.floor((lo + hi) / 2) end)
  save.modData.kanto_ascendant = save.modData.kanto_ascendant or {}
  save.modData.kanto_ascendant.beyond_kanto = {
    version = 1, active = boundaryActive == true,
    irreversible = boundaryActive and true or nil,
    decision = boundaryActive and "test_active" or "fresh_gen1",
  }
  save.modData.kanto_ascendant.johto_signals = {
    version = 2,
    earlyJohto = { receiverRepaired = receiverRepaired == true },
    resonance = {}, prismGrotto = {},
  }
  local game = {
    data = Data, save = save,
    overworld = { map = { id = "PEWTER_GYM", def = Data.maps.PEWTER_GYM } },
    stack = { push = function() end, pop = function() end },
    writeSave = function() return true end,
  }
  run.loader.modSave = save.modData
  run.loader.events:emit("save.loaded", { game = game, save = save })
  run.loader.events:emit("game.ready", { game = game })
  assert(exports.beyondKanto.isActive(game) == (boundaryActive == true),
    "production Beyond-Kanto state disagrees with scenario")
  local battle = BattleState.newTrainer(game, "OPP_BROCK", 1)
  run.loader.events:emit("battle.started", { battle = battle, kind = "trainer" })
  assert(battle.ascendantStoryGym == true,
    "full-loader battle missed Story-Gym policy")
  return battle
end

local sealed = scenario(false, false)
assert(not hasMove(sealed.enemyParty[2], "IRON_TAIL"),
  "sealed Kanto leaked a Generation-II move")
local copiedReceiver = scenario(false, true)
assert(not hasMove(copiedReceiver.enemyParty[2], "IRON_TAIL"),
  "copied receiver without Beyond authority leaked a Generation-II move")
local activeUnrepaired = scenario(true, false)
assert(not hasMove(activeUnrepaired.enemyParty[2], "IRON_TAIL"),
  "active-but-unrepaired save leaked a Generation-II move")
local unlocked = scenario(true, true)
assert(hasMove(unlocked.enemyParty[2], "IRON_TAIL"),
  "authoritative Beyond + repaired receiver missed legal Iron Tail")

run.release()
print(("story_gym_full_mod_exact_engine_test: PASS engine=%s edition=%s")
  :format(expectedEngine, edition))
