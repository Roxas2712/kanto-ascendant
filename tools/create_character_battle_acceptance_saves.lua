-- Builds isolated New-Game handoff and complete rival battle matrix saves.
-- Run under an isolated POKEPORT_IDENTITY only.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Bag = require("src.inventory.Bag")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")

  U.wait(24)
  local version = (os.getenv("CHARACTER_SAVE_VERSION")
    or GameVersion.get() or "red"):lower()
  assert(GameVersion.get() == version, "save version mismatch")

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Kanto Ascendant is not loaded")
  assert(exports.extendedCharacters and exports.rivalTeams
    and exports.battleAcceptance, "character battle exports are incomplete")

  local MATRIX = {
    RED = { rival = "BLUE", third = "GREEN", playerName = "RED", rivalName = "BLUE" },
    BLUE = { rival = "GREEN", third = "RED", playerName = "BLUE", rivalName = "CASEY" },
    GREEN = { rival = "RED", third = "BLUE", playerName = "CASEY", rivalName = "RED" },
  }

  local function copy(value)
    return assert(SaveData.decode(SaveData.encode(value)))
  end

  local function modMeta()
    return SaveData.buildMeta({
      { id = "kanto_ascendant", version = "6.5.0", api = 2 },
    })
  end

  local function stamp(save, mon)
    BattleState.stampOT(save, mon)
    mon.hp = mon.stats.hp
    return mon
  end

  local function characterState(character)
    local row = MATRIX[character]
    return {
      version = 1, enabled = true,
      player_character = character,
      rival_character = row.rival,
      third_character = row.third,
    }
  end

  local function base(character)
    local row = MATRIX[character]
    local save = SaveData.newGame({
      version = version,
      playerName = row.playerName,
      rivalName = row.rivalName,
    })
    save.meta = modMeta()
    save.modData.kanto_ascendant = {
      extended_characters = characterState(character),
    }
    return save
  end

  local function stockedSave(character)
    local save = base(character)
    save.lastHeal = { map = "PALLET_TOWN", x = 5, y = 6 }
    save.inventory = {
      FULL_RESTORE = 99, MAX_REVIVE = 99, ETHER = 99, ESCAPE_ROPE = 20,
    }
    save.money = 999999
    save.party = {
      stamp(save, Pokemon.new(game.data, "MEWTWO", 100)),
      stamp(save, Pokemon.new(game.data, "MEW", 100)),
      stamp(save, Pokemon.new(game.data, "SNORLAX", 100)),
      stamp(save, Pokemon.new(game.data, "ZAPDOS", 100)),
      stamp(save, Pokemon.new(game.data, "BLASTOISE", 100)),
      stamp(save, Pokemon.new(game.data, "CHARIZARD", 100)),
    }
    save.pokedex = { seen = {}, owned = {} }
    for _, mon in ipairs(save.party) do
      save.pokedex.seen[mon.species] = true
      save.pokedex.owned[mon.species] = true
    end
    Bag.order(save)
    return save
  end

  local function battleSave(character)
    local save = stockedSave(character)
    save.player.map = "ROUTE_1"
    save.player.x, save.player.y, save.player.facing = 5, 5, "down"
    save.lastOutdoor = { id = "ROUTE_1", x = 5, y = 5 }
    save.flags = {
      EVENT_GOT_STARTER = true,
      EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true,
      EVENT_BEAT_BROCK = true,
      EVENT_BEAT_MISTY = true,
      EVENT_BEAT_LT_SURGE = true,
    }
    save.modData.kanto_ascendant.battle_acceptance = {
      version = 1, enabled = true, character = character,
    }
    return save
  end

  -- Event saves intentionally do NOT enable the direct battle matrix menu.
  -- They exercise the real map onStep scripts and their canonical flags.
  local function labEventSave(character)
    local save = stockedSave(character)
    save.player.map = "OAKS_LAB"
    save.player.x, save.player.y, save.player.facing = 4, 5, "down"
    save.lastOutdoor = { id = "PALLET_TOWN", x = 12, y = 12 }
    save.flags = {
      EVENT_FOLLOWED_OAK_INTO_LAB = true,
      EVENT_GOT_STARTER = true,
      EVENT_CHOSE_SQUIRTLE = true,
    }
    return save
  end

  local function route22EventSave(character)
    local save = stockedSave(character)
    save.player.map = "ROUTE_22"
    save.player.x, save.player.y, save.player.facing = 28, 4, "right"
    save.lastOutdoor = { id = "ROUTE_22", x = 28, y = 4 }
    save.flags = {
      EVENT_GOT_STARTER = true,
      EVENT_CHOSE_SQUIRTLE = true,
      EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true,
      EVENT_GOT_POKEDEX = true,
      -- EVENT_BEAT_BROCK must remain absent: that is the canonical window.
    }
    return save
  end

  local rows = {}
  local function add(id, label, save)
    rows[#rows + 1] = { id = id, label = label, save = copy(save) }
  end
  add("slot6501", "01 START RED", base("RED"))
  add("slot6502", "02 START BLUE", base("BLUE"))
  add("slot6503", "03 START CASEY", base("GREEN"))
  add("slot6511", "11 BATTLES BLUE", battleSave("RED"))
  add("slot6512", "12 BATTLES CASEY", battleSave("BLUE"))
  add("slot6513", "13 BATTLES RED", battleSave("GREEN"))
  add("slot6521", "21 LAB RED", labEventSave("RED"))
  add("slot6522", "22 LAB BLUE", labEventSave("BLUE"))
  add("slot6523", "23 LAB CASEY", labEventSave("GREEN"))
  add("slot6531", "31 R22 RED", route22EventSave("RED"))
  add("slot6532", "32 R22 BLUE", route22EventSave("BLUE"))
  add("slot6533", "33 R22 CASEY", route22EventSave("GREEN"))

  for _, row in ipairs(rows) do
    assert(SaveData.setActiveSlot(version, row.id) == row.id)
    assert(SaveData.writeSlot(version, row.id, row.save))
    assert(SaveData.renameSlot(version, row.id, row.label))
  end
  SaveData.setActiveSlot(version, rows[1].id)

  local options = SaveData.loadOptions()
  options.animations = true
  options.battleLayout = "og"
  options.colors = "gbc"
  options.speed = 1
  options.mods = options.mods or {}
  options.mods.kanto_ascendant = true
  -- Preserve the user's edition-specific translation choices.  Event saves
  -- are data fixtures, not a reason to flip the whole launcher to English.
  assert(SaveData.saveOptions(options))

  local listed = SaveData.listSlots(version)
  local listedById = {}
  for _, listedRow in ipairs(listed) do listedById[listedRow.id] = listedRow end
  for _, row in ipairs(rows) do
    local listedRow = assert(listedById[row.id], "missing slot " .. row.id)
    assert(listedRow.id == row.id and listedRow.exists,
      "launcher slot mismatch for " .. row.id)
    assert(listedRow.label == row.label, "label mismatch for " .. row.id)
    local path = assert(SaveData.slotDiskPath(version, row.id))
    local handle = assert(io.open(path, "rb"))
    local decoded = assert(SaveData.decode(handle:read("*a")))
    handle:close()
    assert(decoded.modData.kanto_ascendant.extended_characters.enabled)
    if row.id:find("slot651", 1, true) then
      assert(decoded.modData.kanto_ascendant.battle_acceptance.enabled)
      assert(#decoded.party == 6)
    elseif row.id:find("slot652", 1, true) then
      assert(decoded.player.map == "OAKS_LAB")
      assert(decoded.flags.EVENT_GOT_STARTER == true)
      assert(decoded.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB ~= true)
    elseif row.id:find("slot653", 1, true) then
      assert(decoded.player.map == "ROUTE_22")
      assert(decoded.flags.EVENT_GOT_POKEDEX == true)
      assert(decoded.flags.EVENT_BEAT_BROCK ~= true)
    end
  end

  print(("CHARACTER BATTLE SAVES READY version=%s slots=%d")
    :format(version, #rows))
  love.event.quit(0)
end
