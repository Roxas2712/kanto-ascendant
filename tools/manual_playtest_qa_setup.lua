-- One-shot builders for manual 6.5 playtest slots.
--
-- This file is deliberately a setup driver only: it writes one explicitly
-- allow-listed slot inside one explicitly allow-listed QA identity, then
-- quits.  The launcher restarts the game without POKEPORT_DRIVER so every
-- subsequent input is ordinary player input.  Never broaden the identity
-- checks or reuse this file for a normal player identity.

return function(game)
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local Bag = require("src.inventory.Bag")
  local GBCFX = require("src.render.GBCFX")

  local CONFIG = {
    full_transition_fresh = {
      identity = "ka65-playable-full-transition-v1",
      edition = "red", slot = "slot1",
      label = "RC A / Slot 1 - echtes NEW GAME",
      empty = true,
    },
    full_transition_pre_elite = {
      identity = "ka65-playable-full-transition-v1",
      edition = "red", slot = "slot2",
      label = "RC A / Slot 2 - vor Lorelei",
      setup = "fullTransitionPreElite",
    },
    ngplus_pre_pc = {
      identity = "ka65-playable-ngplus-pre-pc-v1",
      edition = "red", slot = "slot1",
      label = "RC B1 - vor NG+ am Labor-PC",
      setup = "ngplusPrePc",
    },
    scientist_red = {
      identity = "ka65-playable-scientist-red-v1",
      edition = "red", slot = "slotka65scientistred",
      label = "Weitere Tests - Wissenschaftler ROT",
      setup = "scientistRed",
    },
    scientist_green = {
      identity = "ka65-playable-scientist-green-v1",
      edition = "red", slot = "slotka65scientistgreen",
      label = "Weitere Tests - Wissenschaftler GRUEN",
      setup = "scientistGreen",
    },
    scientist_blue = {
      identity = "ka65-playable-scientist-blue-v1",
      edition = "red", slot = "slotka65scientistblue",
      label = "Weitere Tests - Wissenschaftler BLAU",
      setup = "scientistBlue",
    },
    surprise_wanderer = {
      identity = "ka65-playable-legacy-wanderer-v1",
      edition = "red", slot = "slotka65wanderer",
      label = "Weitere Tests - Ueberraschungstrainer",
      setup = "surpriseWanderer",
    },
    legacy_story_gate = {
      identity = "ka65-playable-legacy-story-gate-v1",
      edition = "red", slot = "slotka65storygate",
      label = "Weitere Tests - schwarze Tuer",
      setup = "legacyStoryGate",
    },
    oak_finale = {
      identity = "ka65-playable-oak-finale-v1",
      edition = "red", slot = "slotka65oakfinale",
      label = "Weitere Tests - Eich-Finale",
      setup = "oakFinale",
    },
  }

  local scenario = assert(os.getenv("KA_PLAYTEST_SCENARIO"),
    "KA_PLAYTEST_SCENARIO is required")
  local config = assert(CONFIG[scenario], "unknown manual playtest scenario")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "POKEPORT_IDENTITY is required")
  local edition = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION is required")
  assert(identity == config.identity,
    "refusing to write outside the scenario's exact QA identity")
  assert(identity:match("^ka65%-playable%-"),
    "refusing a non-playable-QA identity")
  assert(identity ~= "pokemon-love2d",
    "normal player identity is forbidden")
  assert(edition == config.edition and GameVersion.get() == edition,
    "playtest edition mismatch")
  assert(not SaveData.isPortable(),
    "portable mode would bypass QA identity isolation")

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant must be the loaded Authority mod")
  local archive = assert(api.legacyJourney and api.legacyJourney.archive,
    "Legacy archive API missing")

  local function slotExists(slot)
    for _, row in ipairs(SaveData.listSlots(edition)) do
      if row.id == slot then return true end
    end
    return false
  end

  local function activateSlot()
    assert(SaveData.setActiveSlot(edition, config.slot) == config.slot,
      "could not activate isolated QA slot")
    assert(SaveData.renameSlot(edition, config.slot, config.label),
      "could not label isolated QA slot")
  end

  -- Candidate A/Slot 1 must reach the real title-screen NEW GAME flow.  An
  -- empty registered slot does exactly that.  Delete only this exact slot in
  -- this exact QA identity; no directory and no normal save is ever touched.
  if config.empty then
    assert(archive.write({}), "could not reset the isolated Legacy archive")
    if slotExists(config.slot) then
      assert(SaveData.deleteSlot(edition, config.slot),
        "could not clear prior QA Slot 1")
    end
    activateSlot()
    assert(not SaveData.load(edition),
      "fresh candidate slot unexpectedly contains a save")
    print(("PLAYTEST SETUP PASS: %s / %s / empty NEW GAME slot")
      :format(identity, config.slot))
    love.event.quit(0)
    return
  end

  activateSlot()
  local fresh = SaveData.newGame(game:bootConfig())
  fresh.version = edition
  game.save = fresh
  game:adoptSave(fresh)
  Runtime.emit("save.created", { save = fresh })
  game.mods.modSave = fresh.modData

  local function bucket()
    game.save.modData = game.save.modData or {}
    game.save.modData.kanto_ascendant =
      game.save.modData.kanto_ascendant or {}
    game.mods.modSave = game.save.modData
    return game.save.modData.kanto_ascendant
  end

  local function setLanguageAndPresentation()
    game.save.options = game.save.options or SaveData.defaultOptions()
    game.save.options.textSpeed = 1
    game.save.options.gbcfx = 0
    game.save.options.touchControls = game.save.options.touchControls or {}
    game.save.options.touchControls.enabled = false
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions.kanto_ascendant =
      game.save.options.modOptions.kanto_ascendant or {}
    game.save.options.modOptions.kanto_ascendant.language = "de"
    game.mods.modOptions = game.mods.modOptions or {}
    game.mods.modOptions.kanto_ascendant =
      game.mods.modOptions.kanto_ascendant or {}
    game.mods.modOptions.kanto_ascendant.language = "de"
    GBCFX.setLevel(0)
  end

  local function setCharacter(character)
    assert(api.extendedCharacters.select(character),
      "could not select playtest character " .. character)
    api.extendedCharacters.refreshVisuals(game)
  end

  local function makeMon(species, level, moves)
    local mon = Pokemon.new(game.data, species, level,
      function(_, high) return high end)
    if moves then
      mon.moves = {}
      for _, moveId in ipairs(moves) do
        local move = assert(game.data.moves[moveId],
          "missing move " .. moveId)
        mon.moves[#mon.moves + 1] = { id = moveId, pp = move.pp }
      end
    end
    mon.hp = mon.stats.hp
    return mon
  end

  local function add(item, count)
    assert(game.data.items[item], "missing item " .. item)
    for _ = 1, count or 1 do
      assert(Bag.add(game.save, item, 1, game.data),
        "could not add " .. item)
    end
  end

  local function commonStarted(character)
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_GOT_STARTER = true
    game.save.flags.EVENT_GOT_POKEDEX = true
    game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
    game.save.inventory = game.save.inventory or {}
    game.save.bagOrder = game.save.bagOrder or {}
    game.save.player.name = character
    game.save.player.rival = character == "RED" and "BLUE" or "RED"
    setCharacter(character)
  end

  local setups = {}

  function setups.fullTransitionPreElite()
    assert(archive.write({}), "could not reset isolated transition archive")
    commonStarted("RED")
    local badges = {
      "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
      "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
    }
    for _, item in ipairs(badges) do add(item) end
    for _, item in ipairs({ "HM_CUT", "HM_FLY", "HM_SURF",
        "HM_STRENGTH", "HM_FLASH" }) do add(item) end
    for _, row in ipairs({
      { "FULL_RESTORE", 20 }, { "MAX_POTION", 15 },
      { "REVIVE", 15 }, { "MAX_REVIVE", 5 }, { "ETHER", 10 },
    }) do add(row[1], row[2]) end
    game.save.flags.EVENT_BEAT_BROCK = true
    game.save.flags.EVENT_BEAT_MISTY = true
    game.save.flags.EVENT_BEAT_LT_SURGE = true
    game.save.flags.EVENT_BEAT_ERIKA = true
    game.save.flags.EVENT_BEAT_KOGA = true
    game.save.flags.EVENT_BEAT_SABRINA = true
    game.save.flags.EVENT_BEAT_BLAINE = true
    game.save.flags.EVENT_BEAT_GIOVANNI = true
    game.save.flags.EVENT_BEAT_VIRIDIAN_GYM_GIOVANNI = true
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = nil
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL_THIS_RUN = nil
    game.save.flags.EVENT_STARTED_ELITE_4 = nil
    for _, flag in ipairs({
      "EVENT_BEAT_LORELEIS_ROOM_TRAINER_0",
      "EVENT_AUTOWALKED_INTO_LORELEIS_ROOM",
      "EVENT_BEAT_BRUNOS_ROOM_TRAINER_0",
      "EVENT_AUTOWALKED_INTO_BRUNOS_ROOM",
      "EVENT_BEAT_AGATHAS_ROOM_TRAINER_0",
      "EVENT_AUTOWALKED_INTO_AGATHAS_ROOM",
      "EVENT_BEAT_LANCES_ROOM_TRAINER_0", "EVENT_BEAT_LANCE",
      "EVENT_LANCES_ROOM_LOCK_DOOR",
    }) do game.save.flags[flag] = nil end
    game.save.defeatedTrainers = game.save.defeatedTrainers or {}
    for _, key in ipairs({ "LORELEIS_ROOM_obj_1", "BRUNOS_ROOM_obj_1",
        "AGATHAS_ROOM_obj_1", "LANCES_ROOM_obj_1" }) do
      game.save.defeatedTrainers[key] = nil
    end
    game.save.hallOfFame = {}
    game.save.party = {
      makeMon("CHARIZARD", 68, { "FLAMETHROWER", "FLY", "SLASH", "CUT" }),
      makeMon("BLASTOISE", 69, { "SURF", "ICE_BEAM", "STRENGTH", "BODY_SLAM" }),
      makeMon("VENUSAUR", 70, { "RAZOR_LEAF", "SLEEP_POWDER", "MEGA_DRAIN", "TOXIC" }),
      makeMon("ALAKAZAM", 70, { "PSYCHIC_M", "RECOVER", "THUNDER_WAVE", "FLASH" }),
      makeMon("SNORLAX", 71, { "BODY_SLAM", "EARTHQUAKE", "REST", "HYPER_BEAM" }),
      makeMon("JOLTEON", 72, { "THUNDERBOLT", "PIN_MISSILE", "DOUBLE_KICK", "THUNDER_WAVE" }),
    }
    for _, mon in ipairs(game.save.party) do
      game.save.pokedex.seen[mon.species] = true
      game.save.pokedex.owned[mon.species] = true
    end
    game.save.visited = {}
    for _, mapId in ipairs({
      "PALLET_TOWN", "VIRIDIAN_CITY", "PEWTER_CITY", "CERULEAN_CITY",
      "CELADON_CITY", "FUCHSIA_CITY", "CINNABAR_ISLAND",
      "INDIGO_PLATEAU_LOBBY",
    }) do game.save.visited[mapId] = true end
    game.save.money = 999999
    game.save.player.map = "LORELEIS_ROOM"
    game.save.player.x, game.save.player.y, game.save.player.facing = 4, 10, "up"
    game.save.lastHeal = { map = "INDIGO_PLATEAU_LOBBY", x = 9, y = 7 }
    game.save.lastOutdoor = { id = "INDIGO_PLATEAU_LOBBY", x = 9, y = 7 }
  end

  local SCIENTISTS = {
    RED = { map = "CELADON_CITY", x = 38, y = 23 },
    GREEN = { map = "PEWTER_CITY", x = 8, y = 4 },
    BLUE = { map = "CINNABAR_ISLAND", x = 6, y = 12 },
  }
  local function scientist(character)
    assert(archive.write({}), "could not reset isolated scientist archive")
    commonStarted(character)
    game.save.hallOfFame = { { qa = "manual-scientist" } }
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
    local row = SCIENTISTS[character]
    game.save.player.map = row.map
    game.save.player.x, game.save.player.y, game.save.player.facing =
      row.x, row.y, "up"
    game.save.lastHeal = { map = row.map, x = row.x, y = row.y }
    game.save.lastOutdoor = { id = row.map, x = row.x, y = row.y }
    game.save.party = { makeMon("MEW", 75,
      { "STRENGTH", "SURF", "CUT", "PSYCHIC_M" }) }
  end
  function setups.scientistRed() scientist("RED") end
  function setups.scientistGreen() scientist("GREEN") end
  function setups.scientistBlue() scientist("BLUE") end

  function setups.surpriseWanderer()
    assert(archive.write({}), "could not reset isolated Wanderer archive")
    commonStarted("RED")
    local b = bucket()
    b.legacy_journey = {
      version = 6, cycle = 2, runId = "manual-wanderer-v1",
      pact = "journey", bankPolicy = "open", bankUnlocked = true,
      wanderersEnabled = true, avatar = "RED", avatarQuestStage = 1,
      pathComplete = false, status = "active",
      completedPaths = { red = false, blue = false, green = false },
    }
    b.legacy_wanderers = {
      version = 4, eligibleSteps = 0, wins = 0, streak = 0, marks = 0,
      nextToken = 1, rotation = {}, rewardedTokens = {}, pendingRewards = {},
      due = false, frequency = "normal", cadenceMode = "normal",
      cycleSteps = 199, mapChanges = 2, targetMapChanges = 2,
      lastEligibleMap = "ROUTE_1", stepsRemaining = 1601,
      mapWinCount = 0, forceMapChanges = false,
    }
    game.save.options.modOptions.kanto_ascendant.legacy_wanderer_frequency =
      "normal"
    game.mods.modOptions.kanto_ascendant.legacy_wanderer_frequency = "normal"
    game.save.party = {
      makeMon("CHARIZARD", 70), makeMon("BLASTOISE", 70),
      makeMon("VENUSAUR", 70), makeMon("ALAKAZAM", 70),
      makeMon("SNORLAX", 70), makeMon("JOLTEON", 70),
    }
    game.save.repelSteps = 9999
    game.save.player.map = "ROUTE_1"
    game.save.player.x, game.save.player.y, game.save.player.facing = 5, 5, "down"
    game.save.lastHeal = { map = "VIRIDIAN_CITY", x = 19, y = 17 }
    game.save.lastOutdoor = { id = "ROUTE_1", x = 5, y = 5 }
  end

  local function stageCompletedRedPath()
    assert(archive.write({}), "could not reset isolated Legacy archive")
    commonStarted("RED")
    game.save.hallOfFame = { { qa = "manual-ngplus-gate" } }
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
    game.save.party = { makeMon("PIKACHU", 70,
      { "THUNDERBOLT", "THUNDER_WAVE", "BODY_SLAM", "SURF" }) }
    local ok, result = api.legacyDungeonAdapter.finalize(game, {
      character = "RED", questionIds = { "QA_MANUAL_NGPLUS_GATE" },
    })
    assert(ok and result.character == "RED",
      "could not stage the real RED HEVO completion boundary")
    local b = bucket()
    b.hidden_evolution_story_campaign =
      b.hidden_evolution_story_campaign or { version = 1, hints = {}, doorVisits = {} }
    b.hidden_evolution_story_campaign.doorVisits =
      b.hidden_evolution_story_campaign.doorVisits or {}
    b.hidden_evolution_story_campaign.doorVisits.RED = true
    b.legacy_journey_hevo_gate = {
      version = 1, character = "RED", ready = true, oakCalled = true,
      pendingCall = false, doorAcknowledged = true,
    }
    game.save.flags[api.legacyJourney.HEVO_READY_FLAG] = true
    game.save.flags[api.legacyJourney.HEVO_OAK_CALLED_FLAG] = true
    assert(api.legacyJourney.canBegin(game.save) == true,
      "staged NG+ gate is not actually ready")
  end

  function setups.ngplusPrePc()
    stageCompletedRedPath()
    game.save.player.map = "OAKS_LAB"
    game.save.player.x, game.save.player.y, game.save.player.facing = 1, 2, "up"
    game.save.lastHeal = { map = "PALLET_TOWN", x = 5, y = 6 }
    game.save.lastOutdoor = { id = "PALLET_TOWN", x = 5, y = 6 }
  end

  function setups.legacyStoryGate()
    assert(archive.write({}), "could not reset isolated story-gate archive")
    commonStarted("RED")
    game.save.hallOfFame = { { qa = "manual-story-gate" } }
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
    game.save.party = { makeMon("MEW", 75,
      { "STRENGTH", "SURF", "CUT", "PSYCHIC_M" }) }
    local ok, result = api.legacyDungeonAdapter.finalize(game, {
      character = "RED", questionIds = { "QA_MANUAL_STORY_GATE" },
    })
    assert(ok and result.character == "RED",
      "could not stage RED path before black door")
    game.save.player.map = "KA_HEVO_SHARED_SEALED_ANTECHAMBER"
    game.save.player.x, game.save.player.y, game.save.player.facing = 15, 6, "up"
    game.save.lastHeal = { map = "VIRIDIAN_CITY", x = 19, y = 17 }
    game.save.lastOutdoor = { id = "ROUTE_22", x = 35, y = 2 }
  end

  function setups.oakFinale()
    assert(archive.write({}), "could not reset isolated Oak archive")
    commonStarted("RED")
    local runId = "manual-oak-finale-v1"
    local stored = archive.load()
    stored.completedPaths = { red = true, blue = true, green = true }
    stored.pathSealCycles = { red = 1, blue = 2, green = 3 }
    stored.legacyPass = false
    stored.current = {
      cycle = 99, runId = runId, avatar = "RED", avatarQuestStage = 5,
      pathComplete = true, status = "active", pact = "journey",
      bankPolicy = "open", bankUnlocked = true, wanderersEnabled = true,
    }
    local roster = {
      { "MEWTWO", 100, { "PSYCHIC_M", "RECOVER" } },
      { "ZAPDOS", 100, { "THUNDERBOLT", "DRILL_PECK" } },
      { "MOLTRES", 100, { "FIRE_BLAST", "SKY_ATTACK" } },
      { "ARTICUNO", 100, { "BLIZZARD", "ICE_BEAM" } },
      { "DRAGONITE", 100, { "HYPER_BEAM", "THUNDERBOLT" } },
      { "SNORLAX", 100, { "BODY_SLAM", "EARTHQUAKE" } },
    }
    stored.bank = {}
    for index = 2, #roster do
      local row = roster[index]
      stored.bank[#stored.bank + 1] = {
        id = "MANUAL-OAK-" .. index,
        mon = makeMon(row[1], row[2], row[3]),
      }
    end
    assert(archive.write(stored), "could not write isolated Oak archive")
    local b = bucket()
    b.legacy_journey = {
      version = 6, cycle = 99, runId = runId, avatar = "RED",
      avatarQuestStage = 5, pathComplete = true,
      completedPaths = { red = true, blue = true, green = true },
      legacyPass = false, pact = "journey", bankPolicy = "open",
      bankUnlocked = true, wanderersEnabled = true,
    }
    game.save.party = { makeMon(roster[1][1], roster[1][2], roster[1][3]) }
    game.save.player.map = "OAKS_LAB"
    game.save.player.x, game.save.player.y, game.save.player.facing = 5, 5, "up"
    game.save.lastHeal = { map = "PALLET_TOWN", x = 5, y = 6 }
    game.save.lastOutdoor = { id = "PALLET_TOWN", x = 5, y = 6 }
  end

  setLanguageAndPresentation()
  assert(setups[config.setup], "scenario setup function missing")
  setups[config.setup]()
  local b = bucket()
  b.manual_playtest = {
    version = 1, scenario = scenario, identity = identity,
    slot = config.slot, createdAt = os.time(),
  }
  game.save.version = edition
  game:adoptSave(game.save)
  game.mods.modSave = game.save.modData
  assert(SaveData.saveOptions(game.save.options),
    "could not persist isolated playtest options")
  activateSlot()
  assert(SaveData.writeSlot(edition, config.slot, game.save),
    "could not write isolated manual playtest slot")
  local verified = assert(SaveData.load(edition),
    "could not reload isolated manual playtest slot")
  local marker = verified.modData and verified.modData.kanto_ascendant
    and verified.modData.kanto_ascendant.manual_playtest
  assert(marker and marker.scenario == scenario and marker.identity == identity,
    "manual playtest marker did not survive reload")
  assert(verified.player and verified.player.map == game.save.player.map,
    "manual playtest start did not survive reload")
  print(("PLAYTEST SETUP PASS: %s / %s / %s at %s (%d,%d)")
    :format(identity, config.slot, scenario, verified.player.map,
      verified.player.x, verified.player.y))
  love.event.quit(0)
end
