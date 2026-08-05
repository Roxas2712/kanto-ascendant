-- Kanto Ascendant 6.0 upgrade matrix.
--
-- Historical schemas plus explicit schema-derived 5.3 Red/Blue/Yellow
-- fixtures are loaded in both languages. Every case is normalized,
-- restarted, loaded once with the mod disabled, then enabled and normalized
-- again. The 5.3 rows are intentionally not called published player saves.

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local GameVersion = require("src.core.GameVersion")
local SaveData = require("src.core.SaveData")
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

local function serializedCopy(value)
  local encoded = assert(SaveData.encode(value))
  local decoded, err = SaveData.decode(encoded)
  return assert(decoded, err)
end

local function makeGame(data, bucket, gameVersion, sourceVersion, fixture)
  local fixtureSave = fixture.save or {}
  local seen = { FIXMON_A = true }
  local owned = { FIXMON_A = true }
  for species, value in pairs(fixtureSave.pokedexSeen or {}) do
    seen[species] = value
  end
  for species, value in pairs(fixtureSave.pokedexOwned or {}) do
    owned[species] = value
  end
  local flags = {
    EVENT_GOT_STARTER = true,
    EVENT_GOT_POKEDEX = true,
  }
  if fixtureSave.champion ~= false then
    flags.EVENT_BEAT_CHAMPION_RIVAL = true
  end
  if gameVersion == "yellow" then
    flags.EVENT_CHOSE_PIKACHU = true
    flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true
  else
    flags.EVENT_CHOSE_BULBASAUR = true
  end
  return {
    data = data,
    save = {
      version = gameVersion,
      player = {
        name = "UPGRADE", id = 151, map = "PALLET_TOWN",
        x = 10, y = 12, facing = "down",
      },
      flags = flags,
      hallOfFame = fixtureSave.hallOfFame == false
        and {} or { { sourceVersion = sourceVersion } },
      party = {
        { species = "FIXMON_A", level = 42, hp = 80,
          marker = "party-" .. gameVersion },
      },
      boxes = {
        {
          { species = "PIDGEY", level = 9, hp = 24,
            marker = "boxed-" .. gameVersion },
        },
      },
      inventory = { MASTER_BALL = 1, POKE_BALL = 17 },
      bagOrder = { "MASTER_BALL" },
      money = 53151,
      pokedex = { seen = seen, owned = owned },
      lastHeal = { map = "PALLET_TOWN", x = 10, y = 12 },
      lastOutdoor = { id = "PALLET_TOWN", x = 10, y = 12 },
      meta = {
        format = 4,
        engine = "0.0.0-dev",
        mods = {
          { id = "trainer_rematch", version = sourceVersion, api = 2 },
        },
      },
      defeatedTrainers = {
        ["upgrade-fixture-" .. gameVersion] = true,
      },
      options = {},
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
  ex.johtoSignalsState.install(game)
  ex.johtoSignals.state()
  ex.mythicSignals.state()
  ex.onboarding.state()
  ex.legacyHall.state()
  ex.questTracker.install(game)
  ex.onboarding.install(game)
  ex.researchAtlas.install(game)
  ex.legacyHall.install(game)
  return ex
end

local function verifySignals(fixture, bucket, label)
  local root = bucket.johto_signals
  T.eq(type(root), "table",
    label .. " creates the production Signals root")
  T.eq(root.version, 1,
    label .. " writes the stable Signals root schema")

  local rootKeys = {}
  for key in pairs(root) do rootKeys[#rootKeys + 1] = key end
  table.sort(rootKeys)
  T.same(rootKeys, { "earlyJohto", "resonance", "version" },
    label .. " keeps only the two production Signals sections")

  local early = root.earlyJohto
  T.eq(early.version, 2,
    label .. " initializes early-Johto schema v2")
  T.eq(early.mode, "KANTO_FIRST",
    label .. " upgrades into the non-invasive Kanto current")
  T.eq(early.modeChosen, false,
    label .. " does not make a migration choice for the player")
  T.eq(early.receiverRepaired, false,
    label .. " does not invent a repaired receiver")
  T.eq(early.questStarted, false,
    label .. " does not invent quest progress")
  T.eq(early.capsuleFound, false,
    label .. " does not invent a found capsule")
  T.eq(early.capsuleAvailable, false,
    label .. " does not force a capsule prompt")
  T.eq(early.pokedexSteps, 0,
    label .. " starts the new post-Dex counter at zero")
  T.eq(early.palletVisits, 0,
    label .. " starts the Pallet guarantee counter at zero")
  T.eq(early.capsuleTarget, nil,
    label .. " rolls no hidden target merely by loading")
  T.eq(early.onboardingComplete, false,
    label .. " leaves optional Signals onboarding unconsumed")
  T.eq(early.startPolicy, "quest",
    label .. " preserves the opt-in field-quest default")
  for _, trace in ipairs({ "forest", "coast", "ember", "stone" }) do
    T.eq(early.traces[trace], false,
      label .. " does not invent the " .. trace .. " trace")
  end
  for _, species in ipairs({
    "CHIKORITA", "TOTODILE", "CYNDAQUIL", "LARVITAR",
  }) do
    T.eq(early.rarePity[species], 0,
      label .. " initializes " .. species .. " pity without a free roll")
  end

  local resonance = root.resonance
  T.eq(resonance.version, 2,
    label .. " initializes Mythic Signals schema v2")
  T.eq(resonance.echoes, 0,
    label .. " does not invent witnessed echoes")
  T.eq(resonance.echoRolls, 0,
    label .. " does not invent echo pressure")
  T.eq(resonance.trueRolls, 0,
    label .. " does not invent true-manifestation pressure")
  T.eq(resonance.sealed, false,
    label .. " does not invent a Resonance Seal")
  T.eq(resonance.bound, nil,
    label .. " does not invent a bound mythical")

  local completed = fixture.expect.signalsCompleted or {}
  for _, species in ipairs({ "MEW", "CELEBI" }) do
    T.eq(resonance.completed[species] == true,
      completed[species] == true,
      label .. " reconciles existing " .. species .. " ownership")
  end

  for _, section in ipairs({ early, resonance }) do
    for _, transient in ipairs({
      "capsulePromptOpen", "confirmationOpen", "dialogOpen", "menuOpen",
      "pendingBattle", "pendingEncounter", "pendingSpecies", "promptOpen",
    }) do
      T.eq(section[transient], nil,
        label .. " does not persist runtime-only " .. transient)
    end
  end
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
  verifySignals(fixture, bucket, label)
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
  if fixture.version == "5.3.0" then
    T.eq(game.save.meta.mods[1].version, "5.3.0",
      label .. " retains the source 5.3 metadata until a real save write")
    T.eq(bucket.johto_signals ~= nil, true,
      label .. " adds Signals without resetting the 5.3 bucket")
    if fixture.expect.yellowPartner then
      T.eq(bucket.yellow_partner.accepted, true,
        label .. " preserves the 5.3 Yellow partner decision")
      T.eq(bucket.yellow_partner.heartGiven, true,
        label .. " preserves the 5.3 Yellow partner reward")
      T.eq(bucket.mega_evolution.stones.RAICHUNITE_X, true,
        label .. " preserves the 5.3 Yellow Mega stone")
    end
    if fixture.expect.canonicalMewRepair then
      T.eq(bucket.ascendant.mewCaught, true,
        label .. " repairs owned Mew into canonical completion")
      T.eq(bucket.ascendant.mewStage, 4,
        label .. "repairs the canonical Mew clue stage")
    end
    if fixture.expect.canonicalCelebiRepair then
      T.eq(bucket.postgame.catches.CELEBI, true,
        label .. " repairs owned Celebi into canonical completion")
      T.eq(bucket.postgame.roamers.CELEBI, nil,
        label .. " removes the obsolete Celebi roamer")
    end
    if fixture.expect.worldEvent then
      T.same(bucket.world_events.active, fixture.expect.worldEvent,
        label .. " preserves the active legacy Johto migration event")
    end
  end
  T.eq(bucket.onboarding.shown, false,
    label .. " schedules the one-time 5.0 onboarding")
  local onboardingExpected = fixture.expect.onboarding ~= false
  T.eq(ex.onboarding.shouldShow(game), onboardingExpected,
    onboardingExpected
      and label .. " recognizes the upgraded Hall-of-Fame save"
      or label .. " does not show postgame onboarding before the Hall of Fame")
  if not onboardingExpected then
    T.eq(game.save.player.map, "PALLET_TOWN",
      label .. " does not warp the pre-Hall-of-Fame player")
    T.eq(game.save.player.x, 10,
      label .. " preserves the pre-Hall-of-Fame return x coordinate")
    T.eq(game.save.player.y, 12,
      label .. " preserves the pre-Hall-of-Fame return y coordinate")
  end
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
  if fixture.version == "5.3.0" then
    T.eq(fixture.provenance.kind, "schema-derived-synthetic",
      "5.3 fixture provenance is explicit")
    T.eq(fixture.provenance.publishedSave, false,
      "5.3 fixture is not misrepresented as a published player save")
    T.eq(fixture.provenance.packageSha256,
      "ebcbdbee9f416f9c58ff675b5e97c6d35931348946817b526152fd4b423ca666",
      "5.3 fixture pins the exact public package")
    T.eq(fixture.bucket.johto_signals, nil,
      "5.3 source schema predates Signals")
  end
  for _, version in ipairs(fixture.gameVersions
      or { "red", "blue", "yellow" }) do
    for _, language in ipairs({ "en", "de" }) do
      local label = ("%s -> 6.0 / %s / %s"):format(
        fixture.version, version, language)
      GameVersion.set(version)
      local bucket = copy(fixture.bucket)
      local pristineGameFields

      local run = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
      T.eq(#run.errors, 0, label .. " loads the current mod")
      local game = makeGame(
        run.data, bucket, version, fixture.version, fixture)
      pristineGameFields = copy({
        version = game.save.version, player = game.save.player,
        flags = game.save.flags, meta = game.save.meta,
        party = game.save.party, boxes = game.save.boxes,
        inventory = game.save.inventory, bagOrder = game.save.bagOrder,
        money = game.save.money,
        pokedex = game.save.pokedex,
        defeatedTrainers = game.save.defeatedTrainers,
        lastHeal = game.save.lastHeal,
        lastOutdoor = game.save.lastOutdoor,
      })
      verify(fixture, run, game, language, label)
      T.same({
        version = game.save.version, player = game.save.player,
        flags = game.save.flags, meta = game.save.meta,
        party = game.save.party, boxes = game.save.boxes,
        inventory = game.save.inventory, bagOrder = game.save.bagOrder,
        money = game.save.money,
        pokedex = game.save.pokedex,
        defeatedTrainers = game.save.defeatedTrainers,
        lastHeal = game.save.lastHeal,
        lastOutdoor = game.save.lastOutdoor,
      }, pristineGameFields, label .. " migration does not alter player data")
      local persistedSave = serializedCopy(game.save)
      run.release()

      -- Real serializer boundary: fresh loader and merged data, with the
      -- complete save round-tripped through the engine's native codec.
      GameVersion.set(version)
      local restarted = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
      game = {
        data = restarted.data,
        save = persistedSave,
        stack = { push = function() end },
      }
      verify(fixture, restarted, game, language, label .. " / restart")
      local beforeDisable = serializedCopy(game.save)
      restarted.release()

      -- Mod disabled: the engine keeps namespaced data untouched.
      local noMod = T.sdk.loadNone({ data = T.fixtures.fresh() })
      T.same(game.save, beforeDisable,
        label .. " / disabled keeps the complete namespaced save")
      noMod.release()

      -- Re-enable after the no-mod boot, again through the native serializer.
      GameVersion.set(version)
      local reenabled = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
      game = {
        data = reenabled.data,
        save = serializedCopy(beforeDisable),
        stack = { push = function() end },
      }
      verify(fixture, reenabled, game, language, label .. " / re-enabled")
      T.eq(game.save.modData.trainer_rematch.onboarding.shown, false,
        label .. " / re-enabled does not consume onboarding off-screen")
      reenabled.release()
    end
  end
end

-- Exact lifecycle behind UAT slot 6024: a Johto Pokémon is boxed and known,
-- the whole mod is disabled long enough for real SaveData validation and a
-- serialized save, then 6.0 is re-enabled. The engine restores the physical
-- Pokémon; Dex Progress must restore only the ownership facts proven by it.
do
  GameVersion.set("red")
  local withMod = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
  withMod.data.pokemon.CHIKORITA = {
    id = "CHIKORITA",
    name = "CHIKORITA",
    dex = 152,
  }
  local fixture = fixtures[#fixtures]
  local game = makeGame(
    withMod.data, copy(fixture.bucket), "red", "5.3.0", fixture)
  game.save.boxes = { {
    {
      species = "CHIKORITA",
      level = 18,
      hp = 42,
      marker = "signals-mod-off-cycle",
    },
  } }
  game.save.pokedex.seen.CHIKORITA = true
  game.save.pokedex.owned.CHIKORITA = true
  local ex = normalize(withMod, game, "en")
  local signals = game.save.modData.trainer_rematch.johto_signals
  signals.earlyJohto.rarePity.CHIKORITA = 212
  signals.resonance.echoRolls = 778
  T.eq(#SaveData.validate(game.save, withMod.data).lostMons, 0,
    "6024 enabled validation keeps boxed Chikorita")
  withMod.release()

  local noMod = T.sdk.loadNone({ data = T.fixtures.fresh() })
  local disabledReport = SaveData.validate(game.save, noMod.data)
  T.eq(#disabledReport.lostMons, 1,
    "6024 mod-off validation quarantines the unknown Johto Pokémon")
  T.eq(game.save.pokedex.seen.CHIKORITA, nil,
    "6024 reproduces the engine clearing an unknown seen flag")
  T.eq(game.save.pokedex.owned.CHIKORITA, nil,
    "6024 reproduces the engine clearing an unknown owned flag")
  local disabledBytes = serializedCopy(game.save)
  noMod.release()

  local reenabled = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
  reenabled.data.pokemon.CHIKORITA = {
    id = "CHIKORITA",
    name = "CHIKORITA",
    dex = 152,
  }
  reenabled.data.pokemon.BAYLEEF = {
    id = "BAYLEEF",
    name = "BAYLEEF",
    dex = 153,
  }
  reenabled.data.pokemon.CYNDAQUIL = {
    id = "CYNDAQUIL",
    name = "CYNDAQUIL",
    dex = 155,
  }
  -- game.ready installs controllers before CONTINUE adopts the selected
  -- slot. Keep the same Game object, then replace only its save reference;
  -- the engine's real save.loaded payload contains no `game` field.
  game = {
    data = reenabled.data,
    save = { pokedex = { seen = {}, owned = {} } },
    stack = { push = function() end },
  }
  ex = assert(reenabled.loader.exports.trainer_rematch)
  ex.dexProgress.install(game)
  game.save = disabledBytes
  reenabled.loader.modSave = game.save.modData
  local restoredReport = SaveData.validate(game.save, reenabled.data)
  T.eq(#restoredReport.restoredMons, 1,
    "6024 re-enabled validation restores quarantined Chikorita")
  game.save.party[#game.save.party + 1] = {
    species = "CYNDAQUIL",
    eggSpecies = "CYNDAQUIL",
    isEgg = true,
    nickname = "EGG",
    level = 5,
    hp = 0,
  }
  reenabled.loader.events:emit("save.loaded", {
    save = game.save,
  })
  T.eq(game.save.pokedex.seen.CHIKORITA, true,
    "6024 re-enable rebuilds seen from physical storage")
  T.eq(game.save.pokedex.owned.CHIKORITA, true,
    "6024 re-enable rebuilds owned from physical storage")
  T.eq(game.save.pokedex.seen.BAYLEEF, nil,
    "6024 does not reveal a registered species absent from storage")
  T.eq(game.save.pokedex.owned.BAYLEEF, nil,
    "6024 does not own a registered species absent from storage")
  T.eq(game.save.pokedex.seen.CYNDAQUIL, nil,
    "6024 does not reveal an unhatched Johto egg")
  T.eq(game.save.pokedex.owned.CYNDAQUIL, nil,
    "6024 does not own an unhatched Johto egg")
  T.eq(ex.dexProgress.repairOwnedFromStorage(game), 0,
    "6024 Dex reconstruction is idempotent")
  local restoredSignals =
    game.save.modData.trainer_rematch.johto_signals
  T.eq(restoredSignals.earlyJohto.rarePity.CHIKORITA, 212,
    "6024 mod-off cycle preserves Early Johto pity")
  T.eq(restoredSignals.resonance.echoRolls, 778,
    "6024 mod-off cycle preserves Mythic echo pressure")
  local restored
  for _, box in ipairs(game.save.boxes or {}) do
    for _, mon in ipairs(box) do
      if mon.species == "CHIKORITA"
          and mon.marker == "signals-mod-off-cycle" then
        restored = mon
      end
    end
  end
  T.eq(restored ~= nil, true,
    "6024 restores the exact boxed Chikorita record")
  reenabled.release()
end

GameVersion.set("red")
T.finish("upgrade_matrix")
