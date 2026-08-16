-- Installed-package acceptance for Rematch 2.0's longitudinal contract.
--
-- This is intentionally a two-launch driver.  Pass one uses the production
-- Overworld talk wrapper and real BattleState constructor for every one of
-- the 47 authored trainer providers, exercises multiple progression bands,
-- commits compact anti-repeat history, validates level-100 mastery/AI/Mega
-- eligibility, and drives the separate 1/50 post-Hall Master Ball
-- transaction through BAG -> PC -> pending.  Pass two reloads the native
-- save and proves that those persisted transactions survived the process.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Overworld = require("src.world.OverworldController")
  local Pokemon = require("src.pokemon.Pokemon")
  local Pipelines = require("src.render.Pipelines")
  local Runtime = require("src.mods.Runtime")
  local Screens = require("src.ui.Screens")

  local edition = GameVersion.get()
  local expected = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  assert(edition == expected, "wrong imported edition")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("rematch%-longitudinal", 1, false),
    "refusing to write outside rematch-longitudinal identity")
  local slot = os.getenv("QA_SLOT")
    or ("slot65rematchlong_" .. edition)
  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve rematch longitudinal slot")

  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local resultPath = shotDir .. "/driver_result.txt"
  local pass, fail, lines = 0, 0, {
    "scope=REMATCH-2-LONGITUDINAL-PACKAGE",
    "authority=installed-package/LÖVE",
    "edition=" .. edition,
  }

  local function line(key, value)
    lines[#lines + 1] = tostring(key) .. "=" .. tostring(value)
  end

  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    lines[#lines + 1] = (value and "PASS\t" or "FAIL\t") .. label
    U.log(value and "PASS" or "FAIL", label)
    return value
  end

  local function finish(code)
    line("pass", pass)
    line("fail", fail)
    local out = assert(io.open(resultPath, "wb"),
      "could not write longitudinal driver_result.txt")
    out:write(table.concat(lines, "\n"), "\n")
    out:close()
    love.event.quit(code or (fail == 0 and 0 or 1))
  end

  local loaded, recovered = SaveData.load()
  if loaded then game:restoreSave(loaded, recovered) end
  U.wait(5)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant,
    "installed Kanto Ascendant exports unavailable")
  local recruitment = assert(api.recruitment,
    "recruitment provider unavailable")
  local mastery = assert(api.rematchMastery,
    "mastery provider unavailable")
  local rewards = assert(api.rematchRewards,
    "rematch reward provider unavailable")
  local mega = assert(api.megaEvolution,
    "Mega provider unavailable")
  local probe = game.save._rematchLongitudinalPackage

  if probe and probe.stage == 1 then
    local states = api.trainerStates()
    local preserved, cappedHistory, persistedFields = 0, true, true
    for _, key in ipairs(probe.keys or {}) do
      local state = states[key]
      if state then
        preserved = preserved + 1
        cappedHistory = cappedHistory
          and type(state.recruitHistory) == "table"
          and #state.recruitHistory >= 1 and #state.recruitHistory <= 3
        persistedFields = persistedFields
          and type(state.originalStages) == "table"
          and type(state.recruitFamilies) == "table"
          and tonumber(state.rematchProgressionVersion) == 3
      end
    end
    check("all 47 trainer provider states survive native reload",
      preserved == 47)
    check("all persisted histories remain compact after reload", cappedHistory)
    check("evolution/recruitment schema survives reload", persistedFields)

    local rewardState = rewards.state(game)
    check("Master Ball Bag transaction survived reload",
      (game.save.inventory.MASTER_BALL or 0) == probe.bagMaster)
    check("Master Ball PC transaction survived reload",
      (game.save.pcItems.MASTER_BALL or 0) == probe.pcMaster)
    check("Master Ball pending transaction survived reload",
      #rewardState.pendingItems == probe.pendingCount)
    check("all deterministic Master receipts survive reload",
      #rewardState.masterReceiptOrder == probe.receiptCount
        and probe.receiptCount == 52)

    local evidenceKeys = {}
    for key in pairs(probe.passOneChecks or {}) do
      evidenceKeys[#evidenceKeys + 1] = key
    end
    table.sort(evidenceKeys)
    check("pass-one receipt contains every longitudinal contract",
      #evidenceKeys == 24)
    for _, key in ipairs(evidenceKeys) do
      check("persisted pass-one contract: " .. key,
        probe.passOneChecks[key] == true)
    end
    check("EXP Share state survives native reload",
      rewardState.expShareUnlocked == true
        and rewardState.expShareSetting == "team")
    check("ordered EXP multiplier state survives native reload",
      rewardState.expMultiplierUnlocked == 5
        and rewardState.expMultiplierSetting == 3)
    check("EXP multiplier hook survives native reload",
      Runtime.call("exp.gain", function() return 13 end, {}) == 39)

    Screens.push(game, "AscendantTrainerAtlas")
    local atlas = assert(game.stack:top(), "TRAINER LOG did not open")
    check("production TRAINER LOG exposes all 47 providers",
      atlas.screenId == "AscendantTrainerAtlas"
        and #(atlas.items or {}) == 47)
    atlas.index, atlas.scroll = 1, 0
    U.wait(10)
    U.shot(game, shotDir .. "/03_trainer_log_first.png")
    atlas.index = math.max(1, math.floor(#atlas.items / 2))
    atlas.scroll = math.max(0, atlas.index - math.floor(atlas.rows / 2))
    U.wait(10)
    U.shot(game, shotDir .. "/04_trainer_log_middle.png")
    atlas.index = #atlas.items
    atlas.scroll = math.max(0, #atlas.items - atlas.rows)
    U.wait(10)
    U.shot(game, shotDir .. "/05_trainer_log_last.png")

    probe.stage = 2
    assert(game:writeSave(), "longitudinal reload receipt write failed")
    finish()
    return
  end

  -- Disposable package state.  The Hall row is required only for the
  -- explicitly post-Hall reward and enemy-Mega contracts below.
  game.save.flags = game.save.flags or {}
  game.save.inventory = game.save.inventory or {}
  game.save.pcItems = game.save.pcItems or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.pcOrder = game.save.pcOrder or {}
  game.save.defeatedTrainers = game.save.defeatedTrainers or {}
  game.save.party = {
    Pokemon.new(game.data, "MEWTWO", 100,
      function(_, high) return high end),
  }
  game.save.party[1].hp = game.save.party[1].stats.hp
  game.save.hallOfFame = { { player = game.save.player.name or "RED" } }
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  local savedOptions = game.save.options.modOptions.kanto_ascendant
  savedOptions.team_growth = true
  savedOptions.level_gain = 2
  savedOptions.rest_min = 151
  savedOptions.rest_max = 151
  savedOptions.mega_evolution = true
  savedOptions.mega_opponents = "all"
  -- Provider construction runs with bonus loot disabled so its forty-five
  -- real wins cannot influence the deterministic reward sample below.
  savedOptions.loot_mode = "off"
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  for key, value in pairs(savedOptions) do
    game.mods.modOptions.kanto_ascendant[key] = value
  end
  game:adoptSave(game.save)
  game.mods.modSave = game.save.modData

  local states = api.trainerStates()
  local classes, classCount = {}, 0
  for class in pairs(api.recruitPools) do
    classes[#classes + 1] = class
    classCount = classCount + 1
  end
  table.sort(classes)
  check("installed package exposes exactly 47 trainer providers",
    classCount == 47)

  -- Enable the real Johto research callback without inventing species or
  -- changing product data: this disposable save owns every research family.
  local researchState = api.johtoResearch.state()
  for _, key in ipairs(api.johtoData.starterOrder or {}) do
    researchState.starters[key] = true
  end
  for _, row in ipairs(api.johtoData.rewards or {}) do
    researchState.rewards[row.species] = true
  end
  researchState.finalReward = true
  for species in pairs(game.data.pokemon) do
    if api.johtoResearch.isSpeciesResearched(species, researchState) then
      -- Read-only eligibility is enough; no Pokédex discovery is fabricated.
    end
  end

  local captured, completedKeys = {}, {}
  local fakeWorld = {
    game = game,
    map = { id = "ROUTE_2", def = { label = "Route2" } },
    player = {},
    trainerDefeated = function() return true end,
    pushBattle = function(_, battle) captured[#captured + 1] = battle end,
    afterBattle = function() end,
    showMapText = function() end,
  }

  local function firstPartyIndex(class)
    local record = assert(game.data.trainers[class],
      "missing live trainer class " .. tostring(class))
    for index, team in ipairs(record.parties or {}) do
      if type(team) == "table" and #team > 0 then return index, team end
    end
    return nil, nil
  end

  local function startRealRematch(class, key, partyIndex)
    local npc = {
      id = key, frozen = false,
      def = {
        trainerClass = class, trainerParty = partyIndex,
        index = 1, text = "__REMATCH_LONG__", name = class,
      },
      facePlayer = function() end,
    }
    game.save.defeatedTrainers[key] = true
    local before = #captured
    Overworld.talkTo(fakeWorld, npc)
    local prompt = assert(game.stack:top(),
      "rematch prompt missing for " .. class)
    assert(type(prompt.choice) == "function",
      "rematch choice missing for " .. class)
    game.stack:pop()
    prompt.choice(true)
    if #captured == before then
      local warning = assert(game.stack:top(),
        "strength warning missing for " .. class)
      assert(type(warning.choice) == "function",
        "strength warning choice missing for " .. class)
      game.stack:pop()
      warning.choice(true)
    end
    local battle = captured[#captured]
    assert(#captured == before + 1 and battle and battle.rematch,
      "production rematch not constructed for " .. class)
    return battle
  end

  local providersConstructed, providersWithJohto = 0, 0
  local legalTeams, allAiBounded, allMastery = true, true, true
  local badgeIds = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }
  local badgeCoverage = {}
  local bandSamples = {
    { rematches = 0, trainingCycles = 0, expectedProgress = 0 },
    { rematches = 1, trainingCycles = 0, expectedProgress = 1 },
    { rematches = 2, trainingCycles = 2, expectedProgress = 4 },
    { rematches = 7, trainingCycles = 8, expectedProgress = 15 },
    { rematches = 25, trainingCycles = 35, expectedProgress = 60 },
  }
  local bandCoverage = {}
  for index, class in ipairs(classes) do
    local badgeCount = ({ 0, 4, 8 })[((index - 1) % 3) + 1]
    for _, badge in ipairs(badgeIds) do game.save.inventory[badge] = nil end
    for badgeIndex = 1, badgeCount do
      game.save.inventory[badgeIds[badgeIndex]] = 1
    end
    local partyIndex, baseTeam = firstPartyIndex(class)
    -- Two unused base-game class ids own no registered party.  Their
    -- authored provider remains valid and is exercised through the genuine
    -- recruitment/mastery controllers; every class with a party additionally
    -- traverses the production Overworld -> BattleState path.
    local key = ("REMATCH_LONG_%s_%02d_%s"):format(edition, index, class)
    local state = {
      rematches = 60, trainingCycles = 0, masteryWins = 4, readyAt = 0,
      originalStages = {}, originalBranches = {}, recruitFamilies = {},
      recruitHistory = {}, trainerClass = class,
      trainerName = class:gsub("^OPP_", ""), mapId = "ROUTE_2",
      rematchProgressionVersion = 3,
    }
    states[key] = state
    completedKeys[#completedKeys + 1] = key

    local battle, team, generation
    if partyIndex then
      battle = startRealRematch(class, key, partyIndex)
      providersConstructed = providersConstructed + 1
      badgeCoverage[badgeCount] = true
    else
      local pool = assert(api.recruitPools[class],
        "missing authored pool " .. class)
      baseTeam = { { species = pool[1], level = 60 } }
      team, generation = recruitment.expand(game.data, baseTeam, class,
        key, 60, 99, true, {
          recentHistory = state.recruitHistory,
          selections = state.recruitFamilies,
          originalStages = state.originalStages,
          originalBranches = state.originalBranches,
          rematchNumber = 61,
          deferCommit = true,
        })
      battle = {
        game = game, kind = "trainer", oppClass = class,
        trainer = { name = class }, enemyParty = {},
        aiUsesFor = function() return 0 end,
      }
      for _, slot in ipairs(team) do
        battle.enemyParty[#battle.enemyParty + 1] =
          Pokemon.new(game.data, slot.species,
            math.min(100, (slot.level or 60) + 99))
      end
      mastery.apply(game, battle, {
        kind = "field", key = key, progress = 60,
        rematches = 60, masteryWins = 4, trainerClass = class,
      })
      recruitment.commit(state, generation, true)
    end

    local report = mastery.inspect(battle) or battle.rematchMasteryReport
    allMastery = allMastery and report and report.allLevel100 == true
      and #report.party == #(battle.enemyParty or {})
    allAiBounded = allAiBounded and type(battle.aiUses) == "number"
      and battle.aiUses >= 0 and battle.aiUses <= 3
    local families, hasJohto = {}, false
    for _, mon in ipairs(battle.enemyParty or {}) do
      local def = game.data.pokemon[mon.species]
      legalTeams = legalTeams and def ~= nil and mon.level == 100
        and #(mon.moves or {}) >= 1 and #(mon.moves or {}) <= 4
      local family = mon.johtoResearch and mon.johtoResearch.family
      families[family or mon.species] = true
      local dex = tonumber(def and (def.dex or def.index)) or 0
      hasJohto = hasJohto or (dex > 151 and dex <= 251)
    end
    if hasJohto then providersWithJohto = providersWithJohto + 1 end

    if partyIndex then
      battle.onFinish("win")
      if not (type(state.recruitHistory) == "table"
          and #state.recruitHistory >= 1 and #state.recruitHistory <= 3) then
        legalTeams = false
      end
    end
  end

  -- Representative early/mid/late states cover actual rematch wins plus
  -- silent real-step training without weakening the exhaustive all-47
  -- Level-100 end-tier sample above. They are removed before Atlas/reload so
  -- the persistent provider inventory remains exactly the canonical 47.
  local bandClass, bandParty = classes[1], firstPartyIndex(classes[1])
  assert(bandParty, "no live party for progression-band representative")
  for index, band in ipairs(bandSamples) do
    local key = ("REMATCH_LONG_BAND_%s_%d"):format(edition, index)
    states[key] = {
      rematches = band.rematches, trainingCycles = band.trainingCycles,
      masteryWins = 0, readyAt = 0,
      originalStages = {}, originalBranches = {}, recruitFamilies = {},
      recruitHistory = {}, trainerClass = bandClass,
      trainerName = "BAND", mapId = "ROUTE_2",
      rematchProgressionVersion = 3,
    }
    game.save.defeatedTrainers[key] = true
    local battle = startRealRematch(bandClass, key, bandParty)
    bandCoverage[band.expectedProgress] = {
      number = battle.rematchNumber,
      cycles = battle.rematchTrainingCycles,
      boost = battle.rematchLevelBoost,
    }
    states[key] = nil
    game.save.defeatedTrainers[key] = nil
  end

  -- Do not close the time/cycle row by staging numbers alone.  One
  -- production world.stepped event advances the installed trainer clock and
  -- settles an actually due silent-training interval.  The disposable state
  -- is removed again so the canonical provider inventory remains 47.
  local stepKey = "REMATCH_LONG_WORLD_STEP_" .. edition
  local beforeTrainerClock = api.trainerStepClock()
  states[stepKey] = {
    rematches = 0, trainingCycles = 0, masteryWins = 0,
    readyAt = beforeTrainerClock,
    nextTrainingAt = beforeTrainerClock + 1,
    lastTraining = 1,
    originalStages = {}, originalBranches = {}, recruitFamilies = {},
    recruitHistory = {}, trainerClass = bandClass,
    trainerName = "WORLD STEP", mapId = "ROUTE_2",
    rematchProgressionVersion = 3,
  }
  assert(game.mods.events and type(game.mods.events.emit) == "function",
    "installed package event bus unavailable")
  game.mods.events:emit("world.stepped", { mapId = "ROUTE_2" })
  local realStepCycle = api.trainerStepClock() > beforeTrainerClock
    and api.trainingCycles(stepKey) == 1
  states[stepKey] = nil

  check("every live class with a registered party uses Overworld/BattleState",
    providersConstructed == 45)
  check("all 47 providers produce legal capped teams", legalTeams)
  check("all 47 providers receive level-100 mastery", allMastery)
  check("all 47 providers retain bounded engine AI", allAiBounded)
  check("researched Johto families enter multiple thematic providers",
    providersWithJohto >= 10)
  local multipleBands = true
  for _, band in ipairs(bandSamples) do
    local row = bandCoverage[band.expectedProgress]
    multipleBands = multipleBands and row ~= nil
      and row.number == band.rematches + 1
      and row.cycles == band.trainingCycles
      and row.boost == math.min(99, (band.expectedProgress + 1) * 2)
  end
  check("multiple rematch and silent-training bands reach real battles",
    multipleBands)
  check("one real world step settles a due silent-training cycle",
    realStepCycle)
  check("zero/four/eight-badge saves all reach real rematch battles",
    badgeCoverage[0] and badgeCoverage[4] and badgeCoverage[8])

  -- Two consecutive direct provider commits must rotate eligible additions
  -- while history remains bounded.  This is the same production algorithm
  -- used by the Overworld battles above, isolated here so the assertion does
  -- not depend on a particular imported trainer's original team length.
  local antiState = { recruitHistory = {}, recruitFamilies = {},
    originalStages = {}, originalBranches = {} }
  local antiTeam = { { species = "CATERPIE", level = 70 } }
  local first, firstUpdate = recruitment.expand(game.data, antiTeam,
    "OPP_BUG_CATCHER", "REMATCH_LONG_ANTI", 5, 30, true, {
      recentHistory = antiState.recruitHistory,
      selections = antiState.recruitFamilies,
      originalStages = antiState.originalStages,
      originalBranches = antiState.originalBranches,
      rematchNumber = 6, deferCommit = true,
    })
  recruitment.commit(antiState, firstUpdate, true)
  local second, secondUpdate = recruitment.expand(game.data, antiTeam,
    "OPP_BUG_CATCHER", "REMATCH_LONG_ANTI", 5, 30, true, {
      recentHistory = antiState.recruitHistory,
      selections = {}, originalStages = antiState.originalStages,
      originalBranches = antiState.originalBranches,
      rematchNumber = 7, deferCommit = true,
    })
  recruitment.commit(antiState, secondUpdate, true)
  local antiRotates = first[2] and second[2]
    and first[2].species ~= second[2].species
  local antiCompact = #antiState.recruitHistory == 2
  check("anti-repeat rotates a newly recruited family", antiRotates)
  check("anti-repeat history remains compact", antiCompact)

  -- Story bosses are excluded by the installed talk dispatcher.  The real
  -- Route-22 first-rival object shape must pass to its authored script and
  -- never create a generic trainer state or battle.
  local scriptedBefore = #captured
  local scriptedKey = "ROUTE_22_obj_1"
  states[scriptedKey] = nil
  local scriptedNpc = {
    id = scriptedKey, frozen = false,
    def = { index = 1, name = "ROUTE22_RIVAL1",
      text = "TEXT_ROUTE22_RIVAL1" },
    facePlayer = function() end,
  }
  fakeWorld.map = { id = "ROUTE_22", def = { label = "Route22" } }
  Overworld.talkTo(fakeWorld, scriptedNpc)
  local storyExcluded = states[scriptedKey] == nil
    and #captured == scriptedBefore
  check("Route-22 story rival never becomes a generic rematch provider",
    storyExcluded)
  fakeWorld.map = { id = "ROUTE_2", def = { label = "Route2" } }

  -- Production opponent-Mega event: an eligible real L100 trainer carrying
  -- a registered Mega species is armed at battle.started.  This tests the
  -- automatic event seam, never calls mega.activate and never forges a form.
  local megaClass, megaParty
  for _, class in ipairs(classes) do
    local record = game.data.trainers[class]
    for partyIndex, team in ipairs(record and record.parties or {}) do
      for _, slot in ipairs(team) do
        if mega.formsBySpecies[slot.species] then
          megaClass, megaParty = class, partyIndex
          break
        end
      end
      if megaClass then break end
    end
    if megaClass then break end
  end
  local megaBattle = assert(megaClass
    and require("src.battle.BattleState").newTrainer(
      game, megaClass, megaParty), "no real Mega-capable trainer found")
  for _, mon in ipairs(megaBattle.enemyParty) do mon.level = 100 end
  require("src.mods.Runtime").emit("battle.started", { battle = megaBattle })
  local megaArmed = mega.opponentEligible(megaBattle)
    and megaBattle._ascMegaEnemyPending == true
  check("eligible L100 field trainer is armed for automatic enemy Mega",
    megaArmed)

  local function setLootMode(value)
    savedOptions.loot_mode = value
    game.mods.modOptions.kanto_ascendant.loot_mode = value
  end

  -- Exercise ordinary item and money rewards separately from the rare
  -- Master-Ball boundary. These are real controller transactions against
  -- the installed item registry, not pure loot-table inspection.
  setLootMode("balanced")
  local ordinaryHolder = {}
  local ordinaryBattle = {
    trainer = { name = "LONGITUDINAL" }, oppClass = "OPP_YOUNGSTER",
    rematch = true, rematchTrainerKey = "REMATCH_LONG_ORDINARY",
    rematchNumber = 1, rematchRewardToken = "long:ordinary:item",
    enemyParty = { Pokemon.new(game.data, "RATTATA", 50) },
  }
  local ballsBefore = game.save.inventory.POKE_BALL or 0
  rewards.afterWin(game, ordinaryBattle, ordinaryHolder, { rewardRolls = {
    expShare = 10000, multiplier2 = 300, rematchMaster = 50,
    normal = 1, money = 1,
  } })
  local ordinaryItem = (game.save.inventory.POKE_BALL or 0)
    == ballsBefore + 3
  check("ordinary rematch loot grants its registered item stack",
    ordinaryItem)

  ordinaryBattle.rematchNumber = 2
  ordinaryBattle.rematchRewardToken = "long:ordinary:money50"
  local moneyBefore = game.save.money or 0
  rewards.afterWin(game, ordinaryBattle, ordinaryHolder, { rewardRolls = {
    expShare = 10000, multiplier2 = 300, rematchMaster = 50,
    normal = rewards.loot.ROLL_MAX, money = 4501,
  } })
  local normalMoney = game.save.money == moneyBefore + 500
  check("ordinary level-band rematch grants its normal money fallback",
    normalMoney)

  ordinaryBattle.rematchNumber = 3
  ordinaryBattle.rematchRewardToken = "long:ordinary:money100"
  ordinaryBattle.enemyParty = { Pokemon.new(game.data, "RATTATA", 100) }
  moneyBefore = game.save.money
  rewards.afterWin(game, ordinaryBattle, ordinaryHolder, { rewardRolls = {
    expShare = 10000, multiplier2 = 300, rematchMaster = 50,
    normal = rewards.loot.ROLL_MAX, money = 1,
  } })
  local masteryMoney = game.save.money == moneyBefore + 1000
  check("level-100 mastery band grants its premium money fallback",
    masteryMoney)

  -- The special EXP helpers must unlock in order and never enable
  -- themselves. Drive their production afterWin path, then the real runtime
  -- EXP allocation/multiplier hooks, before the native reload below.
  local expState = rewards.state(game)
  expState.expShareUnlocked, expState.expShareSetting = false, "off"
  expState.expMultiplierUnlocked, expState.expMultiplierSetting = 0, 0
  expState.exp_multiplier_unlock_2x = false
  expState.exp_multiplier_unlock_3x = false
  expState.exp_multiplier_unlock_5x = false
  game.save.inventory.EXP_ALL, game.save.pcItems.EXP_ALL = nil, nil
  game.save.inventory[rewards.MULTIPLIER_ITEM] = nil
  game.save.pcItems[rewards.MULTIPLIER_ITEM] = nil
  game.save.flags.EVENT_GOT_EXP_ALL = nil
  setLootMode("off")
  local specialBattle = {
    trainer = { name = "LONGITUDINAL" }, oppClass = "OPP_YOUNGSTER",
    rematch = true, rematchTrainerKey = "REMATCH_LONG_SPECIAL",
    enemyParty = { Pokemon.new(game.data, "RATTATA", 100) },
  }
  specialBattle.rematchNumber = 1
  specialBattle.rematchRewardToken = "long:special:share"
  rewards.afterWin(game, specialBattle, {}, { rewardRolls = {
    expShare = 1, multiplier2 = 300, normal = rewards.loot.ROLL_MAX,
    money = 10000,
  } })
  local shareOff = expState.expShareUnlocked == true
    and expState.expShareSetting == "off"
  rewards.setExpShare(game, "team")

  specialBattle.rematchNumber = 2
  specialBattle.rematchRewardToken = "long:special:2x"
  rewards.afterWin(game, specialBattle, {}, { rewardRolls = {
    multiplier2 = 1, normal = rewards.loot.ROLL_MAX, money = 10000,
  } })
  local twoOff = expState.expMultiplierUnlocked == 2
    and expState.expMultiplierSetting == 0
  rewards.setMultiplier(game, 2)

  specialBattle.rematchNumber = 3
  specialBattle.rematchRewardToken = "long:special:3x"
  rewards.afterWin(game, specialBattle, {}, { rewardRolls = {
    multiplier3 = 1, normal = rewards.loot.ROLL_MAX, money = 10000,
  } })
  local threePreserves = expState.expMultiplierUnlocked == 3
    and expState.expMultiplierSetting == 2

  specialBattle.rematchNumber = 4
  specialBattle.rematchRewardToken = "long:special:5x"
  rewards.afterWin(game, specialBattle, {}, { rewardRolls = {
    multiplier5 = 1, normal = rewards.loot.ROLL_MAX, money = 10000,
  } })
  local fivePreserves = expState.expMultiplierUnlocked == 5
    and expState.expMultiplierSetting == 2
  rewards.setMultiplier(game, 3)
  local allocations = {}
  Runtime.call("battle.exp_award", function()
    error("installed TEAM allocation hook was skipped")
  end, {
    battle = { game = game }, alive = { game.save.party[1] },
    participants = 1,
    applyShare = function(mon, split)
      allocations[#allocations + 1] = { mon = mon, split = split }
    end,
  })
  local expHooks = #allocations == #game.save.party
    and allocations[1].split == 1
    and Runtime.call("exp.gain", function() return 11 end, {}) == 33
  check("EXP Share unlock starts OFF before explicit TEAM selection",
    shareOff)
  check("2x multiplier unlock starts OFF", twoOff)
  check("3x and 5x unlocks preserve the selected prior stage",
    threePreserves and fivePreserves)
  check("TEAM allocation and selected 3x hook execute exactly once",
    expHooks)

  -- Deterministic 1..50 boundary sample.  Before Hall there are zero hits.
  local function rewardBattle(token)
    return {
      trainer = { name = "LONGITUDINAL" }, oppClass = "OPP_YOUNGSTER",
      rematch = true, rematchTrainerKey = "REMATCH_LONG_REWARD",
      rematchNumber = token, rematchRewardToken = "long:" .. token,
      enemyParty = { Pokemon.new(game.data, "RATTATA", 100) },
    }
  end
  local rewardRolls = {
    expShare = 10000, multiplier2 = 300, multiplier3 = 250,
    multiplier5 = 250, normal = rewards.loot.ROLL_MAX, money = 10000,
  }
  setLootMode("balanced")
  game.save.hallOfFame = {}
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
  local beforePre = game.save.inventory.MASTER_BALL or 0
  rewards.afterWin(game, rewardBattle(1000), rewards.state(game), {
    rewardRolls = setmetatable({ rematchMaster = 1 },
      { __index = rewardRolls }),
  })
  local preHallZero = (game.save.inventory.MASTER_BALL or 0) == beforePre
  check("pre-Hall Master Ball chance is exactly zero", preHallZero)

  game.save.hallOfFame = { { player = game.save.player.name or "RED" } }
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  -- Clean reward-controller receipts within the disposable slot.
  local rewardState = rewards.state(game)
  rewardState.masterReceipts, rewardState.masterReceiptOrder = {}, {}
  game.save.inventory.MASTER_BALL = nil
  game.save.pcItems.MASTER_BALL = nil
  local hits = 0
  for roll = 1, 50 do
    local before = (game.save.inventory.MASTER_BALL or 0)
      + (game.save.pcItems.MASTER_BALL or 0)
      + #rewardState.pendingItems
    local rolls = {
      expShare = 10000, multiplier2 = 300, multiplier3 = 250,
      multiplier5 = 250, rematchMaster = roll,
      normal = rewards.loot.ROLL_MAX, money = 10000,
    }
    rewards.afterWin(game, rewardBattle(roll), rewardState,
      { rewardRolls = rolls })
    local after = (game.save.inventory.MASTER_BALL or 0)
      + (game.save.pcItems.MASTER_BALL or 0)
      + #rewardState.pendingItems
    if after > before then hits = hits + 1 end
  end
  local boundaryExact = hits == 1
    and #rewardState.masterReceiptOrder == 50
  check("post-Hall boundary rolls 1..50 yield exactly one Master Ball",
    boundaryExact)
  local firstBattle = rewardBattle(1)
  local beforeDuplicate = game.save.inventory.MASTER_BALL or 0
  rewards.afterWin(game, firstBattle, rewardState, { rewardRolls = {
    expShare = 10000, multiplier2 = 300, multiplier3 = 250,
    multiplier5 = 250, rematchMaster = 1,
    normal = rewards.loot.ROLL_MAX, money = 10000,
  } })
  local receiptIdempotent = (game.save.inventory.MASTER_BALL or 0)
    == beforeDuplicate
  check("Master Ball receipt is idempotent for the same battle token",
    receiptIdempotent)

  -- Force the next two real hit transactions through PC and safe pending.
  game.save.inventory.MASTER_BALL = 99
  game.save.pcItems.MASTER_BALL = nil
  rewards.afterWin(game, rewardBattle(51), rewardState, { rewardRolls = {
    expShare = 10000, multiplier2 = 300, multiplier3 = 250,
    multiplier5 = 250, rematchMaster = 1,
    normal = rewards.loot.ROLL_MAX, money = 10000,
  } })
  local pcFallback = (game.save.pcItems.MASTER_BALL or 0) == 1
  check("full Bag sends rare rematch Master Ball to PC", pcFallback)
  game.save.pcItems.MASTER_BALL = 99
  local pendingBefore = #rewardState.pendingItems
  rewards.afterWin(game, rewardBattle(52), rewardState, { rewardRolls = {
    expShare = 10000, multiplier2 = 300, multiplier3 = 250,
    multiplier5 = 250, rematchMaster = 1,
    normal = rewards.loot.ROLL_MAX, money = 10000,
  } })
  local pendingFallback = #rewardState.pendingItems == pendingBefore + 1
    and rewardState.pendingItems[#rewardState.pendingItems].item
      == "MASTER_BALL"
  check("full Bag and PC reserve rare rematch Master Ball safely",
    pendingFallback)

  -- Visual receipts come from the actual registered product screen and one
  -- real constructed level-100 battle; they supplement rather than replace
  -- the assertions above.
  Screens.push(game, "AscendantTrainerAtlas")
  local atlas = assert(game.stack:top(), "TRAINER LOG did not open")
  local atlasComplete = #(atlas.items or {}) == 47
  check("production TRAINER LOG contains all 47 provider states",
    atlasComplete)
  U.wait(10)
  U.shot(game, shotDir .. "/01_trainer_log_all_providers.png")
  game.stack:pop()
  local visualBattle = captured[1]
  if visualBattle and not visualBattle.dead then
    game.stack:push(visualBattle)
    U.wait(Pipelines.level("voxel") > 0 and 180 or 45)
    U.shot(game, shotDir .. "/02_level100_rematch_battle.png")
    if game.stack:top() == visualBattle then game.stack:pop() end
  end

  game.save._rematchLongitudinalPackage = {
    stage = 1, keys = completedKeys,
    bagMaster = game.save.inventory.MASTER_BALL or 0,
    pcMaster = game.save.pcItems.MASTER_BALL or 0,
    pendingCount = #rewardState.pendingItems,
    receiptCount = #rewardState.masterReceiptOrder,
    passOneChecks = {
      ["47 provider registry"] = classCount == 47,
      ["45 physical trainer classes"] = providersConstructed == 45,
      ["47 legal teams"] = legalTeams,
      ["47 mastery teams"] = allMastery,
      ["bounded AI"] = allAiBounded,
      ["Johto distribution"] = providersWithJohto >= 10,
      ["rematch and silent-training bands"] = multipleBands,
      ["real world-step training cycle"] = realStepCycle,
      ["zero four eight badge contexts"] = badgeCoverage[0]
        and badgeCoverage[4] and badgeCoverage[8],
      ["anti-repeat rotation"] = antiRotates,
      ["anti-repeat compact history"] = antiCompact,
      ["Route22 story exclusion"] = storyExcluded,
      ["automatic enemy Mega"] = megaArmed,
      ["pre-Hall zero chance"] = preHallZero,
      ["one-in-fifty boundary"] = boundaryExact,
      ["exact-once receipt"] = receiptIdempotent,
      ["Bag to PC fallback"] = pcFallback,
      ["PC to pending fallback"] = pendingFallback and atlasComplete,
      ["ordinary registered item loot"] = ordinaryItem,
      ["normal money band"] = normalMoney,
      ["level100 money band"] = masteryMoney,
      ["EXP Share explicit selection"] = shareOff,
      ["ordered multiplier unlocks"] = twoOff
        and threePreserves and fivePreserves,
      ["EXP allocation and multiplier hooks"] = expHooks,
    },
  }
  assert(game:writeSave(), "longitudinal package save write failed")
  finish()
end
