-- Engine-backed contract test for Crystal learnsets, optional Kanto Johto
-- Move Resonance and the shared Route 5 Move Reminder.
--
-- Run from the Gen1 Recomp checkout:
--   TRAINER_REMATCH_MOD_DIR=/path/to/kanto-ascendant \
--     ./.tools/luajit-src/src/luajit \
--     /path/to/kanto-ascendant/tests/johto_move_reminder_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = require("src.core.Data")
if not (Data.pokemon and Data.pokemon.SCYTHER) then Data:load() end

local checks = 0
local function equal(actual, expected, label)
  checks = checks + 1
  assert(actual == expected, (label or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function truthy(value, label)
  checks = checks + 1
  assert(value, label)
end

local function scheduleSignature(def)
  local rows = {}
  for _, move in ipairs(def and def.level1Moves or {}) do
    rows[#rows + 1] = "1:" .. move
  end
  for _, row in ipairs(def and def.learnset or {}) do
    rows[#rows + 1] = tostring(row.level) .. ":" .. row.move
  end
  return table.concat(rows, ";")
end

local scytherRbyBefore = scheduleSignature(Data.pokemon.SCYTHER)
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
truthy(run.mod, "Kanto Ascendant must load")
equal(#(run.errors or {}), 0, "the real engine/mod merge must be clean")
local ex = assert(run.loader.exports.kanto_ascendant)

-- Johto owns its regular Crystal schedules. Every one of #152-251 must pass
-- through the same generic Reminder path without a per-species exception.
equal(#ex.johtoData.order, 100, "the complete Johto roster remains present")
equal(ex.crystalLearnsetAudit.patchedSpecies, 100,
  "Crystal compatibility patches exactly all 100 Johto species")
local reminderCovered = 0
for _, species in ipairs(ex.johtoData.order) do
  local def = assert(Data.pokemon[species], "missing Johto species " .. species)
  truthy(type(def.level1Moves) == "table",
    species .. " has a regular level-one schedule")
  truthy(type(def.learnset) == "table",
    species .. " has a regular Crystal level schedule")
  local rows = ex.fieldTech.reminderMoves({ data = Data }, {
    species = species, level = 100, moves = {},
  })
  truthy(type(rows) == "table",
    species .. " is accepted by the generic Route 5 Reminder")
  reminderCovered = reminderCovered + 1
end
equal(reminderCovered, 100,
  "all Johto species use the regular Crystal/Reminder contract")

-- Kanto's actual level-up data stays RBY. Its optional additions come only
-- from the species/level-specific Resonance provider.
equal(scheduleSignature(Data.pokemon.SCYTHER), scytherRbyBefore,
  "loading Resonance must not replace Scyther's RBY level-up schedule")
local root = ex.johtoSignalsState.root()
root.earlyJohto.receiverRepaired = false
ex.johtoSignalsState.persist()
local game = { data = Data, save = { inventory = {}, party = {} } }
local function mon(species, level)
  return {
    species = species, level = level,
    moves = { { id = "TACKLE", pp = 35 } },
  }
end
local function sourceFor(target, move)
  for _, row in ipairs(ex.fieldTech.reminderMoves(game, target)) do
    if row.id == move then return row.source end
  end
end

equal(sourceFor(mon("SCYTHER", 18), "FALSE_SWIPE"), nil,
  "Scyther cannot bypass the optional Resonance unlock")
root.earlyJohto.receiverRepaired = true
ex.johtoSignalsState.persist()
equal(sourceFor(mon("SCYTHER", 17), "FALSE_SWIPE"), nil,
  "level-17 Scyther cannot receive level-18 False Swipe")
local readyScyther = mon("SCYTHER", 18)
equal(sourceFor(readyScyther, "FALSE_SWIPE"), "resonance",
  "level-18 Scyther sees False Swipe as an optional Johto source")
equal(ex.fieldTech.rememberMove(
  game, readyScyther, "FALSE_SWIPE"), true,
  "Route 5 teaches unlocked False Swipe to Scyther")

equal(sourceFor(mon("SCIZOR", 17), "FALSE_SWIPE"), nil,
  "level-17 Scizor cannot receive level-18 False Swipe")
equal(sourceFor(mon("SCIZOR", 18), "FALSE_SWIPE"), "level",
  "Scizor receives False Swipe from its regular Crystal schedule")
equal(sourceFor(mon("ESPEON", 35), "PSYBEAM"), nil,
  "level-35 Espeon still cannot remember Psybeam early")
equal(sourceFor(mon("ESPEON", 36), "PSYBEAM"), "level",
  "level-36 Espeon still remembers Psybeam normally")
equal(sourceFor(mon("MAGIKARP", 100), "FALSE_SWIPE"), nil,
  "an unrelated Kanto species receives no blanket Johto move pool")

-- The 251-species source derives every newly vetted Kanto level move while
-- unsupported mechanics remain a machine-readable audit finding.
local audit = ex.driftglassPrisms.resonanceAudit
equal(audit.sourceAvailable, true,
  "the production Resonance audit reads the canonical Crystal source")
equal(ex.driftglassPrisms.resonanceRules.SCYTHER.FALSE_SWIPE.level, 18,
  "Scyther's derived rule keeps Crystal's exact level")
equal(ex.driftglassPrisms.resonanceRules.MACHOP.CROSS_CHOP.level, 37,
  "Machop derives canonical Cross Chop only for its own species")
equal(ex.driftglassPrisms.resonanceRules.MACHOP.VITAL_THROW.level, 31,
  "Machop derives canonical Vital Throw only for its own species")
local pursuitAudit, flameWheelActive, flameWheelUnsupported
for _, row in ipairs(audit.activeLevelRows or {}) do
  if row.species == "GROWLITHE" and row.move == "FLAME_WHEEL"
      and row.level == 34 then flameWheelActive = row break end
end
for _, row in ipairs(audit.unsupportedLevelRows or {}) do
  if row.species == "SCYTHER" and row.move == "PURSUIT"
      and row.level == 12 then pursuitAudit = row
  elseif row.species == "GROWLITHE" and row.move == "FLAME_WHEEL"
      and row.level == 34 then flameWheelUnsupported = row end
end
truthy(flameWheelActive,
  "an implemented curated Crystal level move is active in the audit")
equal(flameWheelUnsupported, nil,
  "implemented curated moves are not mislabeled mechanics-not-vetted")
truthy(pursuitAudit,
  "Pursuit stays audited until its switch-intercept mechanic is implemented")

-- False Swipe is a real damaging move with its defining one-HP floor. A
-- cleared Substitute (0) behaves like no Substitute; an active one takes the
-- uncapped hit because the protected monster itself was not damaged.
local Runtime = require("src.mods.Runtime")
truthy(Data.moves.FALSE_SWIPE,
  "False Swipe is registered in the real merged move catalog")
equal(Data.moves.FALSE_SWIPE.power, 40,
  "False Swipe keeps its canonical base power")
local info = { crit = false, typeMult = 10, marker = "preserved" }
local function damageFor(substituteHP, move)
  return Runtime.call("battle.damage", function()
    return 99, info
  end, {
    battle = {}, move = move or Data.moves.FALSE_SWIPE,
    target = { mon = { hp = 12 }, substituteHP = substituteHP },
  })
end
local damage, returnedInfo = damageFor(nil)
equal(damage, 11, "False Swipe leaves a direct target at one HP")
equal(returnedInfo, info, "False Swipe preserves damage metadata")
equal(damageFor(0), 11,
  "a cleared zero-HP Substitute still applies the one-HP floor")
equal(damageFor(5), 99,
  "an active Substitute receives uncapped False Swipe damage")
equal(damageFor(nil, Data.moves.TACKLE), 99,
  "False Swipe never changes another move's damage")

print(("johto_move_reminder_engine_test: ok (%d assertions)")
  :format(checks))
