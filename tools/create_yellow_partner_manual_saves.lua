-- Creates four isolated, playable Yellow save slots for manual testing of
-- Kanto Ascendant's partner path. Run only with a throwaway POKEPORT_IDENTITY.
--
-- Slot 1 deliberately contains no trainer_rematch save bucket or partner
-- marker. Loading it with Ascendant enabled reproduces installing the mod
-- after an ordinary Yellow playthrough was already in progress.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Bag = require("src.inventory.Bag")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")

  U.wait(20)
  assert(GameVersion.isYellow(), "manual partner saves require Yellow")

  local ascendant = assert(
    game.mods and game.mods.exports and game.mods.exports.trainer_rematch,
    "Kanto Ascendant must be installed while creating the test saves")
  local partnerApi = assert(ascendant.yellowPartner,
    "Yellow partner controller missing")

  local function copy(value)
    return assert(SaveData.decode(SaveData.encode(value)))
  end

  local function makeMon(species)
    local mon = Pokemon.new(game.data, species, 50, function() return 10 end)
    BattleState.stampOT(game.save, mon)
    mon.hp = mon.stats.hp
    return mon
  end

  local function prepare(mapId, x, y, species)
    U.teleport(game, mapId, x, y, "down")
    local save = game.save
    save.version = "yellow"
    save.player = save.player or {}
    save.player.name = "PARTNER"
    save.player.rival = "RIVAL"
    save.player.id = 5300
    save.player.map = mapId
    save.player.x, save.player.y, save.player.facing = x, y, "down"
    save.flags = {
      EVENT_GOT_STARTER = true,
      EVENT_CHOSE_PIKACHU = true,
      EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true,
      EVENT_BEAT_BROCK = true,
      EVENT_BEAT_MISTY = true,
      EVENT_BEAT_LT_SURGE = true,
    }
    save.inventory = {
      BOULDERBADGE = 1,
      CASCADEBADGE = 1,
      THUNDERBADGE = 1,
      POKE_BALL = 20,
      POTION = 20,
      ESCAPE_ROPE = 10,
    }
    save.bagOrder = nil
    save.pcItems = {}
    save.boxes = {}
    save.party = { makeMon(species or "PIKACHU") }
    save.party[1].ot = save.player.name
    save.party[1].otId = save.player.id
    save.party[1][partnerApi.marker] = nil
    save.pikachuHappiness = 230
    save.pokedex = {
      seen = { PIKACHU = true },
      owned = { PIKACHU = true },
    }
    if species == "RAICHU" then
      save.pokedex.seen.RAICHU = true
      save.pokedex.owned.RAICHU = true
    end
    save.money = 50000
    save.playTime = 5 * 3600 + 30 * 60
    save.repelSteps = 0
    save.defeatedTrainers = save.defeatedTrainers or {}
    save.objectToggles = save.objectToggles or {}
    save.visited = {
      PALLET_TOWN = true,
      PEWTER_CITY = true,
      CERULEAN_CITY = true,
      VERMILION_CITY = true,
      ROUTE_1 = true,
    }
    save.lastHeal = { map = "VERMILION_CITY", x = 15, y = 6 }
    save.lastOutdoor = { id = mapId, x = x, y = y }
    save.modData = {}
    save.meta = SaveData.buildMeta({})
    Bag.order(save)
    return copy(save)
  end

  local function modMeta()
    return SaveData.buildMeta({
      { id = "trainer_rematch", version = "5.3.0", api = 2 },
    })
  end

  local function partnerState(fields)
    local out = {
      version = 1,
      initialized = true,
      offered = true,
      accepted = true,
      declined = false,
      legacy = false,
      steps = 251,
      wins = 3,
      heartGiven = false,
    }
    for key, value in pairs(fields or {}) do out[key] = value end
    return out
  end

  local function armMega(save, preference)
    save.inventory.MEGA_RING = 1
    save.inventory.MEGA_STONE_CASE = 1
    save.modData.trainer_rematch.mega_evolution = {
      version = 3,
      ring = true,
      case = true,
      stones = {
        RAICHUNITE_X = true,
        RAICHUNITE_Y = true,
      },
      preferences = { RAICHU = preference or "RAICHU_X" },
      activations = 0,
      secretUnlocked = false,
      secretActivations = 0,
    }
    Bag.order(save)
  end

  -- True old save: no Ascendant state, no marker and no mod item.
  local legacy = prepare("VERMILION_CITY", 20, 18, "PIKACHU")
  legacy.modData = {}
  legacy.meta = SaveData.buildMeta({})
  legacy.party[1][partnerApi.marker] = nil
  legacy.inventory[partnerApi.itemId] = nil
  Bag.order(legacy)

  -- New-game quest state: return to Surge and speak to him once.
  local quest = prepare("VERMILION_GYM", 4, 13, "PIKACHU")
  quest.party[1][partnerApi.marker] = true
  quest.modData = {
    trainer_rematch = {
      yellow_partner = partnerState(),
    },
  }
  quest.meta = modMeta()

  -- Fully armed Pikachu: use the Heart from BAG or encounter a wild Pokémon
  -- on Route 1 and press SELECT to test direct Mega Raichu X/Y.
  local pikachu = prepare("ROUTE_1", 10, 12, "PIKACHU")
  pikachu.party[1][partnerApi.marker] = true
  pikachu.inventory[partnerApi.itemId] = 1
  pikachu.modData = {
    trainer_rematch = {
      yellow_partner = partnerState({
        legacy = true,
        heartGiven = true,
        heartGivenAt = os.time(),
      }),
    },
  }
  armMega(pikachu, "RAICHU_X")
  pikachu.meta = modMeta()

  -- Already evolved partner for immediate follower and bond-dialogue checks.
  local raichu = prepare("VERMILION_CITY", 20, 18, "RAICHU")
  raichu.party[1][partnerApi.marker] = true
  raichu.inventory[partnerApi.itemId] = 1
  raichu.modData = {
    trainer_rematch = {
      yellow_partner = partnerState({
        legacy = true,
        heartGiven = true,
        choice = "evolved",
        heartGivenAt = os.time(),
      }),
    },
  }
  armMega(raichu, "RAICHU_Y")
  raichu.meta = modMeta()

  local rows = {
    { id = "slot1", label = "1 LEGACY BEFORE MOD", save = legacy },
    { id = "slot2", label = "2 QUEST TURN-IN", save = quest },
    { id = "slot3", label = "3 HEART + MEGA", save = pikachu },
    { id = "slot4", label = "4 RAICHU FOLLOWER", save = raichu },
  }
  for _, row in ipairs(rows) do
    assert(SaveData.setActiveSlot("yellow", row.id) == row.id)
    assert(SaveData.writeSlot("yellow", row.id, row.save))
    assert(SaveData.renameSlot("yellow", row.id, row.label))
  end
  SaveData.setActiveSlot("yellow", "slot1")

  -- The source checkout also ships example/development mods. Keep this
  -- manual profile deterministic: only Ascendant and PokéPC Followers run.
  local options = SaveData.loadOptions()
  options.mods = {
    PokePCFollowers_VoxelMerge = true,
    trainer_rematch = true,
    deutsch = false,
    ["deutsch-blau"] = false,
    ["deutsch-gelb"] = false,
    example_mew_starter = false,
    nuzlocke = false,
  }
  assert(SaveData.saveOptions(options))

  for _, row in ipairs(rows) do
    local path = assert(SaveData.slotDiskPath("yellow", row.id))
    local handle = assert(io.open(path, "rb"))
    local decoded = assert(SaveData.decode(handle:read("*a")))
    handle:close()
    assert(decoded.version == "yellow")
    assert(decoded.player and decoded.player.name == "PARTNER")
  end

  U.log("PASS created Yellow partner manual saves",
    SaveData.slotDiskPath("yellow", "slot1"))
  love.event.quit(0)
end
