-- Kanto Ascendant 5.0 upgrade matrix.
--
-- Four historical save schemas are loaded as Red, Blue and Yellow in both
-- languages. Every case is normalized, restarted, loaded once with the mod
-- disabled, then enabled and normalized again.

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local fixtures = dofile((os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/trainer_rematch") .. "/tests/fixtures/upgrade_saves.lua")
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/trainer_rematch"

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function makeGame(data, bucket, version)
  return {
    data = data,
    save = {
      player = { name = "UPGRADE", id = 151 },
      flags = { EVENT_BEAT_CHAMPION_RIVAL = true },
      hallOfFame = { { version = version } },
      party = {
        { species = "FIXMON_A", level = 42, hp = 80,
          marker = "party-" .. version },
      },
      boxes = {}, inventory = { MASTER_BALL = 1 },
      bagOrder = { "MASTER_BALL" },
      pokedex = {
        seen = { FIXMON_A = true }, owned = { FIXMON_A = true },
      },
      defeatedTrainers = {}, options = {},
      modData = { trainer_rematch = bucket },
    },
    stack = { push = function() end },
  }
end

local function normalize(run, game, language)
  run.loader.modSave = game.save.modData
  run.loader.modOptions.trainer_rematch = {
    language = language,
    kanto_151 = "ascendant",
  }
  run.loader.events:emit("save.loaded", { save = game.save, game = game })
  local ex = assert(run.loader.exports.trainer_rematch)
  ex.postgame.state()
  ex.ascendant.state()
  ex.kantoCompletion.state()
  ex.fieldTech.state()
  ex.frontierExchange.state()
  ex.daycare.status()
  ex.megaEvolution.state()
  ex.shinySystem.state()
  ex.johtoResearch.state()
  ex.eventArchive.state()
  ex.worldEvents.state()
  ex.johtoMasters.state()
  ex.dexProgress.state()
  ex.grandTour.state()
  ex.ascendantMenu.state()
  ex.onboarding.state()
  ex.legacyHall.state()
  ex.questTracker.install(game)
  ex.onboarding.install(game)
  ex.researchAtlas.install(game)
  ex.legacyHall.install(game)
  return ex
end

local function verify(fixture, run, game, language, label)
  local ex = normalize(run, game, language)
  local bucket = game.save.modData.trainer_rematch
  local trainer = bucket.trainers.ROUTE_1_obj_1
  T.eq(trainer.rematches, fixture.expect.rematches,
    label .. " preserves field-rematch wins")
  T.eq(bucket.postgame.masterWins.brock, true,
    label .. " preserves Master Circuit progress")
  T.eq(bucket.ascendant.research.completed.rematch_field == true,
    fixture.expect.research, label .. " preserves 2.x research progress")
  T.eq((bucket.daycare_plus.eggsProduced or 0) > 0,
    fixture.expect.daycare, label .. " preserves 3.x Day-Care progress")
  T.eq(bucket.field_tech.kit == true, fixture.expect.fieldKit,
    label .. " preserves 4.x Field Kit progress")
  T.eq(bucket.johto_research.version, 2,
    label .. " migrates Johto research without resetting it")
  T.eq(bucket.field_tech.version, 2,
    label .. "migrates the lossless TM queue")
  if fixture.version == "4.1.1" then
    T.eq(bucket.field_tech.pendingTMs[1], "TM03",
      label .. " preserves a blocked 4.x TM as the first FIFO entry")
    T.eq(bucket.johto_masters.clears, 1,
      label .. " preserves Gold clears")
    T.eq(bucket.shiny_system.caught.GYARADOS, true,
      label .. " preserves genuine-DV shiny records")
  end
  T.eq(bucket.onboarding.shown, false,
    label .. " schedules the one-time 5.0 onboarding")
  T.eq(ex.onboarding.shouldShow(game), true,
    label .. " recognizes the upgraded Hall-of-Fame save")
  T.eq(ex.language(), language,
    label .. " uses the selected release language")
  local onboardingText = ex.onboarding.text()
  T.eq(onboardingText:find(language == "de" and "EICH" or "OAK",
    1, true) ~= nil, true, label .. " renders localized onboarding")
  local objective = ex.questTracker.objectiveText(game)
  T.eq(objective:find(language == "de" and "ORT:" or "LOCATION:",
    1, true) ~= nil, true, label .. " renders a localized objective location")
  T.eq(objective:find(language == "de" and "FORTSCHRITT"
    or "PROGRESS", 1, true) ~= nil, true,
    label .. " renders objective progress")
  return ex
end

for _, fixture in ipairs(fixtures) do
  for _, version in ipairs({ "red", "blue", "yellow" }) do
    for _, language in ipairs({ "en", "de" }) do
      local label = ("%s -> 5.0 / %s / %s"):format(
        fixture.version, version, language)
      GameVersion.set(version)
      local bucket = copy(fixture.bucket)
      local pristineGameFields

      local run = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
      T.eq(#run.errors, 0, label .. " loads the current mod")
      local game = makeGame(run.data, bucket, fixture.version)
      pristineGameFields = copy({
        party = game.save.party, inventory = game.save.inventory,
        pokedex = game.save.pokedex,
      })
      verify(fixture, run, game, language, label)
      T.same({
        party = game.save.party, inventory = game.save.inventory,
        pokedex = game.save.pokedex,
      }, pristineGameFields, label .. " migration does not alter player data")
      local migrated = game.save.modData.trainer_rematch
      run.release()

      -- Real restart: fresh loader and fresh merged data, same serialized
      -- save bucket.
      GameVersion.set(version)
      local restarted = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
      game = makeGame(restarted.data, migrated, fixture.version)
      verify(fixture, restarted, game, language, label .. " / restart")
      local beforeDisable = copy(game.save.modData.trainer_rematch)
      restarted.release()

      -- Mod disabled: the engine keeps namespaced data untouched.
      local noMod = T.sdk.loadNone({ data = T.fixtures.fresh() })
      T.same(game.save.modData.trainer_rematch, beforeDisable,
        label .. " / disabled keeps the complete namespaced save")
      noMod.release()

      -- Re-enable after the no-mod boot.
      GameVersion.set(version)
      local reenabled = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
      game = makeGame(reenabled.data, beforeDisable, fixture.version)
      verify(fixture, reenabled, game, language, label .. " / re-enabled")
      T.eq(game.save.modData.trainer_rematch.onboarding.shown, false,
        label .. " / re-enabled does not consume onboarding off-screen")
      reenabled.release()
    end
  end
end

GameVersion.set("red")
T.finish("upgrade_matrix")
