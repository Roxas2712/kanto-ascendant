-- Guarded real-LÖVE acceptance for Rematch 2.0 Phase 8.
-- Pass one exercises real registry items, Runtime EXP hooks, the complete
-- Ascendant option tree and PC-independent unlock state, then writes the
-- reserved slot. Pass two proves settings/unlocks survive a real restart.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local SaveData = require("src.core.SaveData")
  local Runtime = require("src.mods.Runtime")
  local Pokemon = require("src.pokemon.Pokemon")
  local Bag = require("src.inventory.Bag")

  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("rematch%-phase8"),
    "refusing to write outside rematch-phase8 identity")
  assert(GameVersion.get() == version, "wrong ROM cache mounted")
  assert(SaveData.setActiveSlot(version, "slot6808") == "slot6808")

  local loaded, recovered = SaveData.load()
  if loaded then game:restoreSave(loaded, recovered) end
  U.wait(5)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local rewards = assert(api.rematchRewards, "Phase-8 rewards export missing")
  local probe = game.save._rematchPhase8Probe
  if probe and probe.stage == 1 then
    local s = rewards.state(game)
    assert(s.expShareUnlocked and s.expShareSetting == "team",
      "EXP Share unlock/setting did not survive reload")
    assert(s.expMultiplierUnlocked == 5 and s.expMultiplierSetting == 3,
      "EXP Multiplier unlock/setting did not survive reload")
    assert((game.save.pcItems.EXP_ALL or 0) >= 1,
      "stored EXP Share item disappeared after reload")
    assert((game.save.pcItems[rewards.MULTIPLIER_ITEM] or 0) >= 1,
      "stored multiplier item disappeared after reload")
    local multiplied = Runtime.call("exp.gain", function() return 13 end, {})
    assert(multiplied == 39, "×3 hook was not restored after reload")
    probe.stage = 2
    assert(game:writeSave(), "Phase-8 reload save write failed")
    U.log("REMATCH PHASE 8 RELOAD PASS", version,
      "unlocks settings PC storage and multiplier persisted")
    love.event.quit(0)
    return
  end

  game.save.inventory = game.save.inventory or {}
  game.save.pcItems = game.save.pcItems or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.flags = game.save.flags or {}
  game.save.party = {
    Pokemon.new(game.data, "RATTATA", 50),
    Pokemon.new(game.data, "PIDGEY", 50),
    Pokemon.new(game.data, "CATERPIE", 50),
  }
  for _, mon in ipairs(game.save.party) do mon.hp = mon.stats.hp end

  -- Reset only this reserved acceptance slot's Phase-8 probe/state.
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
  game.save.modData.kanto_ascendant.rematch_rewards = {
    version = 1, expShareUnlocked = false, expShareSetting = "off",
    expMultiplierUnlocked = 0, expMultiplierSetting = 0, pendingItems = {},
  }
  game.mods.modSave = game.save.modData
  game.save.inventory.EXP_ALL = nil
  game.save.pcItems.EXP_ALL = nil
  game.save.inventory[rewards.MULTIPLIER_ITEM] = nil
  game.save.pcItems[rewards.MULTIPLIER_ITEM] = nil
  game.save.flags.EVENT_GOT_EXP_ALL = nil
  Bag.order(game.save)

  local holder = {}
  local battle = {
    trainer = { name = "PHASE8 TRAINER" },
    enemyParty = { Pokemon.new(game.data, "RATTATA", 50) },
  }
  local beforeBalls = game.save.inventory.POKE_BALL or 0
  local text = rewards.afterWin(game, battle, holder, {
    rewardRolls = {
      expShare = 10000, multiplier2 = 300, normal = 1, money = 1,
    },
  })
  assert((game.save.inventory.POKE_BALL or 0) == beforeBalls + 3,
    "real normal reward did not grant Poke Ball x3")
  assert(text and text:find("BALL", 1, true),
    "real normal item reward was not announced")

  local money = game.save.money or 0
  rewards.afterWin(game, battle, holder, {
    rewardRolls = {
      expShare = 10000, multiplier2 = 300,
      normal = rewards.loot.ROLL_MAX, money = 4501,
    },
  })
  assert(game.save.money == money + 500,
    "real normal money fallback did not grant ¥500")
  battle.enemyParty = { Pokemon.new(game.data, "RATTATA", 100) }
  money = game.save.money
  rewards.afterWin(game, battle, holder, {
    rewardRolls = {
      expShare = 10000, multiplier2 = 300,
      normal = rewards.loot.ROLL_MAX, money = 1,
    },
  })
  assert(game.save.money == money + 1000,
    "real Level-100 money fallback did not use its premium pool")

  local _, changed = rewards.unlock(game, "expShare")
  assert(changed and rewards.state(game).expShareSetting == "off",
    "EXP Share acquisition did not remain OFF")
  assert(Bag.remove(game.save, "EXP_ALL", 1) == nil)
  game.save.pcItems.EXP_ALL = 1
  rewards.setExpShare(game, "team")

  _, changed = rewards.unlock(game, 2)
  assert(changed and rewards.state(game).expMultiplierSetting == 0,
    "×2 acquisition did not remain OFF")
  rewards.setMultiplier(game, 2)
  _, changed = rewards.unlock(game, 3)
  assert(changed and rewards.state(game).expMultiplierSetting == 2,
    "×3 acquisition changed the selected ×2")
  _, changed = rewards.unlock(game, 5)
  assert(changed and rewards.state(game).expMultiplierSetting == 2,
    "×5 acquisition changed the selected ×2")
  rewards.setMultiplier(game, 3)
  Bag.remove(game.save, rewards.MULTIPLIER_ITEM, 1)
  game.save.pcItems[rewards.MULTIPLIER_ITEM] = 1

  local allocations = {}
  Runtime.call("battle.exp_award", function()
    error("Ascendant TEAM allocation hook was skipped")
  end, {
    battle = { game = game }, alive = { game.save.party[1] }, participants = 1,
    applyShare = function(mon, split)
      allocations[#allocations + 1] = { mon = mon, split = split }
    end,
  })
  assert(#allocations == 3 and allocations[1].split == 1
      and allocations[2].split == 2 and allocations[3].split == 2,
    "real TEAM mode allocation is not participant-full/reserve-half")
  assert(Runtime.call("exp.gain", function() return 11 end, {}) == 33,
    "real ×3 final EXP multiplier did not apply exactly once")

  -- Walk the production menu tree rather than calling its screen factory.
  local startRows = Runtime.call("ui.start_menu.items",
    function(_, rows) return rows end, game, {
      { label = "POKéMON" }, { label = "ITEM" }, { label = "SAVE" },
    })
  local ascendant
  for _, row in ipairs(startRows) do if row.label == "ASCENDANT" then ascendant = row end end
  assert(ascendant and ascendant.onSelect, "ASCENDANT menu row missing")
  ascendant.onSelect()
  local gateway = assert(game.stack:top(), "Ascendant gateway missing")
  local optionRow
  for _, row in ipairs(gateway.items or {}) do
    if row.ascendantKey == "options" or row.label == "OPTIONS"
        or row.label == "OPTIONEN" then optionRow = row break end
  end
  assert(optionRow, "ASCENDANT -> OPTIONS row missing")
  gateway.onChoose(optionRow, gateway)
  local root = assert(game.stack:top(), "Ascendant options root missing")
  assert(root.title:find("OPTIONS", 1, true)
      or root.title:find("OPTIONEN", 1, true), "wrong options root")
  root.onChoose(root.items[1], root)
  local gameplay = assert(game.stack:top(), "GAMEPLAY screen missing")
  local trainingEntry
  for _, row in ipairs(gameplay.items or {}) do
    if row.value == "training" then trainingEntry = row break end
  end
  assert(trainingEntry, "EXP & TRAINING submenu missing from GAMEPLAY")
  gameplay.onChoose(trainingEntry, gameplay)
  local training = assert(game.stack:top(), "EXP & TRAINING screen missing")
  local shareRow, multiplierRow
  for _, row in ipairs(training.items or {}) do
    if row.value == "exp_share" then shareRow = row end
    if row.value == "exp_multiplier" then multiplierRow = row end
  end
  assert(shareRow and multiplierRow,
    "both unlocked EXP helpers are missing from EXP & TRAINING")

  -- Return the shortcut item to the Bag once, use the actual BagMenu row,
  -- then store it again. Using it may navigate but must not change ×3.
  game.save.pcItems[rewards.MULTIPLIER_ITEM] = nil
  assert(Bag.add(game.save, rewards.MULTIPLIER_ITEM, 1, game.data),
    "could not return multiplier shortcut to Bag")
  local BagMenu = require("src.ui.BagMenu")
  local bag = BagMenu.new(game, {})
  game.stack:push(bag)
  local shortcut
  for _, row in ipairs(bag.items) do
    if row.value == rewards.MULTIPLIER_ITEM then shortcut = row break end
  end
  assert(shortcut, "multiplier shortcut row missing from real Bag")
  bag.onChoose(shortcut, bag)
  local shortcutScreen = assert(game.stack:top(), "item shortcut opened no screen")
  assert(shortcutScreen.title == "EXP & TRAINING",
    "item shortcut did not jump directly to EXP & TRAINING")
  assert(rewards.state(game).expMultiplierSetting == 3,
    "using the item shortcut toggled gameplay assistance")
  Bag.remove(game.save, rewards.MULTIPLIER_ITEM, 1)
  game.save.pcItems[rewards.MULTIPLIER_ITEM] = 1

  game.save._rematchPhase8Probe = { stage = 1 }
  assert(game:writeSave(), "Phase-8 save write failed")
  U.log("REMATCH PHASE 8 WRITE PASS", version,
    "normal rewards money L100 EXP share multiplier UI shortcut PC")
  love.event.quit(0)
end
