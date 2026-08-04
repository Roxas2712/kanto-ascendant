-- Creates an isolated manual-acceptance save suite for Gorochu.
--
-- Run this driver once for each POKEPORT_VERSION (red, blue and yellow)
-- against a throwaway POKEPORT_IDENTITY. It never targets the player's
-- ordinary saves. Yellow receives the complete partner path and seven
-- dedicated expression slots; Red/Blue receive the edition-wide Surge,
-- condenser, Tear and battle checkpoints.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Bag = require("src.inventory.Bag")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")
  local Stats = require("src.pokemon.Stats")

  U.wait(24)

  local version = (os.getenv("GOROCHU_SAVE_VERSION")
    or GameVersion.get() or ""):lower()
  assert(GameVersion.VERSIONS[version],
    "GOROCHU_SAVE_VERSION must be red, blue or yellow")
  assert(GameVersion.get() == version,
    "POKEPORT_VERSION and GOROCHU_SAVE_VERSION must match")

  local ascendant = assert(
    game.mods and game.mods.exports
      and game.mods.exports.trainer_rematch,
    "Kanto Ascendant must be loaded while creating acceptance saves")
  local gorochu = assert(ascendant.gorochu,
    "Gorochu controller is missing")
  local partner = assert(ascendant.yellowPartner,
    "Yellow partner controller is missing")
  local shiny = assert(ascendant.shinySystem,
    "shiny controller is missing")
  assert(gorochu.available and game.data.pokemon.GOROCHU,
    "Gorochu species is unavailable")

  local isYellow = version == "yellow"
  local playerName = isYellow and "GORO UAT" or version:upper() .. " UAT"
  local now = os.time()

  local function copy(value)
    return assert(SaveData.decode(SaveData.encode(value)))
  end

  local function moveSlots(ids)
    local out = {}
    for _, id in ipairs(ids) do
      local def = assert(game.data.moves[id], "missing move " .. id)
      out[#out + 1] = { id = id, pp = def.pp }
    end
    return out
  end

  local function makeMon(species, level, shinyWanted)
    local mon = Pokemon.new(game.data, species, level,
      function() return 9 end)
    BattleState.stampOT(game.save, mon)
    if shinyWanted then
      assert(shiny.forceMon(mon, game.data.pokemon[species]),
        "could not make " .. species .. " shiny")
      assert(Stats.isShiny(mon.dvs),
        species .. " shiny DVs were not retained")
    end
    if species == "GOROCHU" then
      mon.moves = moveSlots({
        "THUNDERBOLT", "BITE", "AGILITY", "THUNDER",
      })
    elseif species == "RAICHU" then
      mon.moves = moveSlots({
        "THUNDERBOLT", "BITE", "THUNDER_WAVE", "AGILITY",
      })
    end
    mon.hp = mon.stats.hp
    return mon
  end

  local function baseGorochuState(fields)
    local out = {
      version = 4,
      offered = false,
      declined = false,
      heartGiven = false,
      tearGenerated = false,
      tearClaims = 0,
      completed = false,
      playerEvolved = false,
    }
    for key, value in pairs(fields or {}) do out[key] = value end
    return out
  end

  local function basePartnerState(fields)
    local out = {
      version = 2,
      initialized = true,
      offered = false,
      accepted = false,
      declined = false,
      legacy = false,
      steps = 0,
      wins = 0,
      heartGiven = false,
    }
    for key, value in pairs(fields or {}) do out[key] = value end
    return out
  end

  local function modMeta()
    return SaveData.buildMeta({
      { id = "DRAMATIC_SHAPE", version = "1.4.0", api = 2 },
      { id = "PokePCFollowers_VoxelMerge", version = "1.3.0", api = 2 },
      { id = "trainer_rematch", version = "5.4.1", api = 2 },
    })
  end

  local function prepare(mapId, x, y, facing, leadSpecies, opts)
    opts = opts or {}
    U.teleport(game, mapId, x, y, facing or "down")
    local save = game.save
    save.version = version
    save.player = save.player or {}
    save.player.name = playerName
    save.player.rival = "RIVAL"
    save.player.id = 5402
    save.player.map = mapId
    save.player.x, save.player.y = x, y
    save.player.facing = facing or "down"
    save.flags = {
      EVENT_GOT_STARTER = true,
      EVENT_CHOSE_PIKACHU = isYellow,
      EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true,
      EVENT_BEAT_BROCK = true,
      EVENT_BEAT_MISTY = true,
      EVENT_BEAT_LT_SURGE = true,
      EVENT_BEAT_VERMILION_GYM_TRAINER_0 = true,
      EVENT_BEAT_VERMILION_GYM_TRAINER_1 = true,
      EVENT_BEAT_VERMILION_GYM_TRAINER_2 = true,
      EVENT_1ST_LOCK_OPENED = true,
      EVENT_2ND_LOCK_OPENED = true,
    }
    save.inventory = {
      BOULDERBADGE = 1,
      CASCADEBADGE = 1,
      THUNDERBADGE = 1,
      POKE_BALL = 30,
      GREAT_BALL = 20,
      POTION = 20,
      SUPER_POTION = 20,
      ESCAPE_ROPE = 10,
      REPEL = 10,
    }
    save.bagOrder = nil
    save.pcItems = {}
    save.boxes = {}
    save.party = {
      makeMon(leadSpecies, opts.level or 61, opts.shiny),
      makeMon("BLASTOISE", 55, false),
    }
    local lead = save.party[1]
    lead.ot, lead.otId = playerName, save.player.id
    save.party[2].ot, save.party[2].otId = playerName, save.player.id
    if isYellow then lead[partner.marker] = true end
    if isYellow and opts.awakened then
      lead[partner.awakeningMarker] = true
      lead.stats = Stats.calc(
        game.data.pokemon.PIKACHU,
        lead.level, lead.dvs, lead.statExp, lead)
    end
    if opts.gorochuCandidate then lead[gorochu.marker] = true end
    save.pikachuHappiness = opts.happiness or 230
    save.pikachuMood = opts.mood or 128
    lead.status = opts.status
    lead.hp = lead.stats.hp
    save.pokedex = { seen = {}, owned = {} }
    for _, mon in ipairs(save.party) do
      save.pokedex.seen[mon.species] = true
      save.pokedex.owned[mon.species] = true
    end
    save.money = 999999
    save.playTime = 12 * 3600 + 54 * 60
    save.repelSteps = 0
    save.defeatedTrainers = {}
    save.objectToggles = {}
    save.visited = {
      PALLET_TOWN = true,
      ROUTE_1 = true,
      PEWTER_CITY = true,
      CERULEAN_CITY = true,
      VERMILION_CITY = true,
      ROUTE_10 = true,
      POWER_PLANT = true,
    }
    save.lastHeal = { map = "VERMILION_CITY", x = 15, y = 6 }
    save.lastOutdoor = { id = mapId, x = x, y = y }
    save.hallOfFame = {}
    save.modData = {
      trainer_rematch = {
        gorochu_quest = baseGorochuState(opts.gorochuState),
      },
    }
    if isYellow then
      save.modData.trainer_rematch.yellow_partner =
        basePartnerState(opts.partnerState)
    end
    save.meta = modMeta()
    Bag.order(save)
    return copy(save)
  end

  local function give(save, item)
    save.inventory[item] = 1
    Bag.order(save)
  end

  local function completeState(save)
    save.modData.trainer_rematch.gorochu_quest =
      baseGorochuState({
        offered = true,
        heartGiven = true,
        heartGivenAt = now,
        tearGenerated = true,
        tearGeneratedAt = now,
        tearClaims = 1,
        completed = true,
        playerEvolved = true,
        completedAt = now,
      })
    if isYellow then
      save.modData.trainer_rematch.yellow_partner =
        basePartnerState({
          offered = true,
          accepted = true,
          steps = partner.requiredSteps,
          wins = partner.requiredWins,
          heartGiven = true,
          heartGivenAt = now,
          choice = "evolved",
        })
    end
    give(save, gorochu.heartItemId)
    save.inventory[gorochu.tearItemId] = nil
    save.pokedex.seen.GOROCHU = true
    save.pokedex.owned.GOROCHU = true
    Bag.order(save)
  end

  local rows = {}
  local function add(label, save)
    rows[#rows + 1] = {
      id = "slot" .. tostring(#rows + 1),
      label = label,
      save = save,
    }
  end

  if isYellow then
    add("01 QUEST OFFER", prepare(
      "VERMILION_GYM", 4, 13, "up", "PIKACHU", {
        level = 35,
        partnerState = {
          offered = false, accepted = false, steps = 0, wins = 0,
        },
      }))

    add("02 QUEST REWARD", prepare(
      "VERMILION_GYM", 4, 13, "up", "PIKACHU", {
        level = 35,
        partnerState = {
          offered = true, accepted = true,
          steps = partner.requiredSteps, wins = partner.requiredWins,
        },
      }))

    local heartChoice = prepare(
      "VERMILION_CITY", 20, 18, "down", "PIKACHU", {
        level = 35,
        gorochuState = {
          offered = true, heartGiven = true, heartGivenAt = now,
        },
        partnerState = {
          offered = true, accepted = true,
          steps = partner.requiredSteps, wins = partner.requiredWins,
          heartGiven = true, heartGivenAt = now,
        },
      })
    give(heartChoice, gorochu.heartItemId)
    add("03 HEART CHOICE", heartChoice)

    local awakenedPikachu = prepare(
      "VERMILION_CITY", 20, 18, "down", "PIKACHU", {
        level = 35,
        awakened = true,
        gorochuState = {
          offered = true, heartGiven = true, heartGivenAt = now,
        },
        partnerState = {
          offered = true, accepted = true,
          steps = partner.requiredSteps, wins = partner.requiredWins,
          heartGiven = true, heartGivenAt = now,
          choice = "stay", awakenedAt = now,
        },
      })
    give(awakenedPikachu, gorochu.heartItemId)
    add("04 AWAKENED PIKA", awakenedPikachu)

    local powerPlant = prepare(
      "POWER_PLANT", 37, 4, "up", "RAICHU", {
        level = 61,
        gorochuCandidate = true,
        gorochuState = {
          offered = true, heartGiven = true, heartGivenAt = now,
        },
        partnerState = {
          offered = true, accepted = true,
          steps = partner.requiredSteps, wins = partner.requiredWins,
          heartGiven = true, heartGivenAt = now, choice = "evolved",
        },
      })
    give(powerPlant, gorochu.heartItemId)
    add("05 POWER PLANT", powerPlant)

    local tearReady = prepare(
      "VERMILION_CITY", 20, 18, "down", "RAICHU", {
        level = 61,
        gorochuCandidate = true,
        gorochuState = {
          offered = true, heartGiven = true, heartGivenAt = now,
          tearGenerated = true, tearGeneratedAt = now, tearClaims = 1,
        },
        partnerState = {
          offered = true, accepted = true,
          steps = partner.requiredSteps, wins = partner.requiredWins,
          heartGiven = true, heartGivenAt = now, choice = "evolved",
        },
      })
    give(tearReady, gorochu.heartItemId)
    give(tearReady, gorochu.tearItemId)
    add("06 TEAR EVOLVE", tearReady)
  else
    add("01 SURGE HEART", prepare(
      "VERMILION_GYM", 4, 13, "up", "RAICHU", {
        gorochuCandidate = true,
      }))

    local powerPlant = prepare(
      "POWER_PLANT", 37, 4, "up", "RAICHU", {
        gorochuCandidate = true,
        gorochuState = {
          offered = true, heartGiven = true, heartGivenAt = now,
        },
      })
    give(powerPlant, gorochu.heartItemId)
    add("02 POWER PLANT", powerPlant)

    local tearReady = prepare(
      "VERMILION_CITY", 20, 18, "down", "RAICHU", {
        gorochuCandidate = true,
        gorochuState = {
          offered = true, heartGiven = true, heartGivenAt = now,
          tearGenerated = true, tearGeneratedAt = now, tearClaims = 1,
        },
      })
    give(tearReady, gorochu.heartItemId)
    give(tearReady, gorochu.tearItemId)
    add("03 TEAR EVOLVE", tearReady)
  end

  local normalBattle = prepare(
    "ROUTE_1", 10, 12, "down", "GOROCHU", {
      level = 80,
      gorochuCandidate = true,
      gorochuState = {
        offered = true, heartGiven = true, tearGenerated = true,
        tearClaims = 1, completed = true,
      },
      partnerState = {
        offered = true, accepted = true,
        steps = partner.requiredSteps, wins = partner.requiredWins,
        heartGiven = true, choice = "evolved",
      },
    })
  completeState(normalBattle)
  add(isYellow and "07 GORO BATTLE" or "04 GORO BATTLE",
    normalBattle)

  local shinyBattle = prepare(
    "ROUTE_1", 10, 12, "down", "GOROCHU", {
      level = 80,
      shiny = true,
      gorochuCandidate = true,
      gorochuState = {
        offered = true, heartGiven = true, tearGenerated = true,
        tearClaims = 1, completed = true,
      },
      partnerState = {
        offered = true, accepted = true,
        steps = partner.requiredSteps, wins = partner.requiredWins,
        heartGiven = true, choice = "evolved",
      },
    })
  completeState(shinyBattle)
  add(isYellow and "08 SHINY BATTLE" or "05 SHINY BATTLE",
    shinyBattle)

  if isYellow then
    local moods = {
      { label = "SLEEPY", status = "SLP",
        happiness = 230, mood = 128 },
      { label = "UNWELL", status = "PSN",
        happiness = 230, mood = 128 },
      { label = "UPSET", happiness = 30, mood = 50 },
      { label = "WARY", happiness = 90, mood = 100 },
      { label = "CONTENT", happiness = 150, mood = 128 },
      { label = "DEVOTED", happiness = 220, mood = 128 },
      { label = "EXCITED", happiness = 240, mood = 150 },
    }
    for index, mood in ipairs(moods) do
      local save = prepare(
        "VERMILION_CITY", 20, 18, "down", "GOROCHU", {
          level = 80,
          status = mood.status,
          happiness = mood.happiness,
          mood = mood.mood,
          gorochuCandidate = true,
          gorochuState = {
            offered = true, heartGiven = true, tearGenerated = true,
            tearClaims = 1, completed = true,
          },
          partnerState = {
            offered = true, accepted = true,
            steps = partner.requiredSteps, wins = partner.requiredWins,
            heartGiven = true, choice = "evolved",
          },
        })
      completeState(save)
      add(("%02d FACE %s"):format(index + 8, mood.label), save)
    end
  end

  local expectedCount = isYellow and 15 or 5
  assert(#rows == expectedCount,
    ("wrong %s slot count: %d"):format(version, #rows))

  for _, row in ipairs(rows) do
    assert(SaveData.setActiveSlot(version, row.id) == row.id)
    assert(SaveData.writeSlot(version, row.id, row.save))
    assert(SaveData.renameSlot(version, row.id, row.label))
  end
  SaveData.setActiveSlot(version, "slot1")

  local options = SaveData.loadOptions()
  options.animations = true
  options.battleLayout = "og"
  options.colors = "gbc"
  options.speed = 1
  options.pipelines = { voxel = 1, tiltshift = 3 }
  options.mods = {
    DRAMATIC_SHAPE = true,
    PokePCFollowers_VoxelMerge = true,
    trainer_rematch = true,
    deutsch = false,
    ["deutsch-blau"] = false,
    ["deutsch-gelb"] = false,
    example_mew_starter = false,
    nuzlocke = false,
  }
  options.modOptions = options.modOptions or {}
  options.modOptions.DRAMATIC_SHAPE = {
    battles = true,
    battleBack = false,
    curve = 0,
    water = "full",
  }
  assert(SaveData.saveOptions(options))

  local listed = SaveData.listSlots(version)
  assert(#listed == expectedCount,
    ("launcher registered %d/%d %s slots")
      :format(#listed, expectedCount, version))
  for index, row in ipairs(rows) do
    local listedRow = assert(listed[index],
      "missing launcher row " .. tostring(index))
    assert(listedRow.id == row.id and listedRow.exists,
      "launcher row does not point at " .. row.id)
    assert(listedRow.label == row.label,
      "launcher label mismatch for " .. row.id)
    local path = assert(SaveData.slotDiskPath(version, row.id))
    local handle = assert(io.open(path, "rb"))
    local decoded = assert(SaveData.decode(handle:read("*a")))
    handle:close()
    assert(decoded.version == version)
    assert(decoded.player and decoded.player.name == playerName)
    assert(decoded.meta and decoded.meta.format,
      row.id .. " has no save metadata")
    local lead = assert(decoded.party and decoded.party[1],
      row.id .. " has no lead")
    if row.label:find("QUEST ", 1, true)
        or row.label:find("SURGE HEART", 1, true) then
      assert(decoded.flags.EVENT_2ND_LOCK_OPENED == true,
        row.id .. " leaves Major Bob's electric gate closed")
    end
    if row.label:find("AWAKENED PIKA", 1, true) then
      assert(lead.species == "PIKACHU"
        and lead[partner.marker] == true
        and lead[partner.awakeningMarker] == true,
        row.id .. " is not the marked awakened partner")
      local expected = Stats.calc(
        game.data.pokemon.RAICHU,
        lead.level, lead.dvs, lead.statExp)
      for _, stat in ipairs(Stats.ORDER) do
        assert(lead.stats[stat] == expected[stat],
          row.id .. " lost Raichu-equivalent " .. stat)
      end
    end
    if row.label:find("GORO BATTLE", 1, true)
        or row.label:find("SHINY BATTLE", 1, true)
        or row.label:find("FACE ", 1, true) then
      assert(lead.species == "GOROCHU",
        row.id .. " is not a Gorochu checkpoint")
      assert(#lead.moves == 4 and lead.hp == lead.stats.hp,
        row.id .. " Gorochu is not battle-ready")
      assert(decoded.modData.trainer_rematch.gorochu_quest.completed,
        row.id .. " completion flag is missing")
      if isYellow then
        assert(lead[partner.marker] == true,
          row.id .. " lost Yellow partner identity")
      end
    end
    if row.label:find("SHINY", 1, true) then
      assert(Stats.isShiny(lead.dvs),
        row.id .. " lead is not shiny")
    end
  end

  U.log("PASS created Gorochu acceptance saves",
    version, expectedCount,
    SaveData.slotDiskPath(version, "slot1"))
  love.event.quit(0)
end
