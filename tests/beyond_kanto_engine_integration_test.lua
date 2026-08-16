-- Run from the exact 0.1.90 Gen1 Recomp checkout. The repository checkout
-- carries a development version string, so this focused loader test stamps
-- the release version before manifest validation without editing the engine.

package.path = "./?.lua;./?/init.lua;" .. package.path
require("src.core.Version").engine = "0.1.90"

local T = require("tests.modkit")
local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end

local checks = 0
local function ok(value, label)
  checks = checks + 1
  assert(value, "FAIL: " .. label)
end
local function eq(actual, expected, label)
  ok(actual == expected, label .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local run = T.sdk.loadMod(modPath, { data = Data })
ok(run.mod ~= nil, "Kanto Ascendant loads through the exact-.90 SDK")
eq(#(run.errors or {}), 0, "exact-.90 mod merge is clean")
local ex = assert(run.loader.exports.kanto_ascendant)
local boundary = assert(ex.beyondKanto)

local save = {
  version = "red", player = { id = 86, name = "RED" }, flags = {},
  party = {}, boxes = {}, inventory = {},
  pokedex = { seen = {}, owned = {} },
  modData = { kanto_ascendant = { beyond_kanto = {
    version = 1, active = false, decision = "fresh_gen1",
  } } },
}
local game = { data = Data, save = save, writeSave = function() return true end }
boundary.sync(game, save, "engine-integration-off")

-- A carried repaired receiver is not sufficient on its own: the save-local
-- irreversible boundary must also be ON before Kanto rematches see Gen-II
-- legal moves.
local signal = ex.johtoSignals.state()
signal.receiverRepaired = true
local pikachu = { species = "PIKACHU", level = 100, moves = {} }
local legalOff = ex.rematchMastery.legalMoves(game, pikachu, {})
ok(not legalOff.IRON_TAIL,
  "sealed rematch mastery rejects Iron Tail despite copied receiver repair")

local Evolution = require("src.pokemon.Evolution")
local golbat = { species = "GOLBAT", level = 50, johtoBond = 100 }
eq(Evolution.pendingFor(game, golbat, { kind = "levelup" }), nil,
  "real evolution dispatcher blocks high-friendship Golbat while sealed")

local activated, reason = boundary.activate(game)
ok(activated and reason == "activated",
  "real engine save activates Beyond Kanto explicitly")
local legalOn = ex.rematchMastery.legalMoves(game, pikachu, {})
ok(legalOn.IRON_TAIL,
  "activation plus repaired receiver restores Iron Tail to rematch mastery")
eq(Evolution.pendingFor(game, golbat, { kind = "levelup" }), "CROBAT",
  "real evolution dispatcher restores Golbat to Crobat after activation")

run.release()
print(("beyond_kanto_engine_integration_test: %d checks passed"):format(checks))
