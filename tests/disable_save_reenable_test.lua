-- Regression for the exact RC4 failure sequence:
-- ASC -> save -> ASC disabled -> load/save -> ASC re-enabled. Unknown content
-- must survive the serializer boundary. Standalone Useful Bag is no longer in
-- this fixture because it is now a declared hard conflict with ASC Bag.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local SaveData = require("src.core.SaveData")

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"

local function serializedCopy(value)
  local encoded = assert(SaveData.encode(value))
  local decoded, err = SaveData.decode(encoded)
  return assert(decoded, err)
end

local function boxes()
  local out = {}
  for i = 1, 12 do out[i] = {} end
  return out
end

-- The engine's ROM-free fixture intentionally has no complete Kanto catalog,
-- so postgame_species.lua skips the 100-species install. Recognize the exact
-- Ascendant species id at the validation seam, matching upgrade_matrix_test's
-- established mod-off lifecycle fixture.
local function recognizeChikorita(data)
  data.pokemon.CHIKORITA = {
    id = "CHIKORITA",
    name = "CHIKORITA",
    dex = 152,
  }
end

local base = T.fixtures.fresh()
local enabled = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })

T.eq(#enabled.errors, 0,
  "ASC loads cleanly before the disable/re-enable cycle")
T.eq(enabled.loader.mods.kanto_ascendant.state, "loaded",
  "ASC remains loaded before the serializer cycle")

local modSpecies = "CHIKORITA"
recognizeChikorita(enabled.data)
T.check(enabled.data.pokemon[modSpecies] ~= nil
    and base.pokemon[modSpecies] == nil,
  "fixture identifies a Pokémon owned by ASC")

local modItem
for id in pairs(enabled.data.items or {}) do
  if base.items[id] == nil then
    modItem = id
    break
  end
end
T.check(modItem ~= nil, "fixture identifies an item owned by ASC")
if modItem == nil then
  enabled.release()
  T.finish("disable_save_reenable")
  return
end

local save = {
  party = {
    {
      species = modSpecies,
      nickname = "SAVEFIX",
      level = 18,
      dvs = { attack = 10, defense = 10, speed = 10, special = 10 },
      statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 },
      moves = {},
      marker = "disable-save-reenable",
    },
  },
  boxes = boxes(),
  currentBox = 1,
  inventory = { [modItem] = 3 },
  pcItems = {},
  bagOrder = { modItem },
  pokedex = {
    seen = { [modSpecies] = true },
    owned = { [modSpecies] = true },
  },
}

local enabledReport = SaveData.validate(save, enabled.data)
T.eq(#enabledReport.lostMons, 0,
  "enabled ASC keeps its Pokémon in the live party")
T.eq(#enabledReport.lostItems, 0,
  "enabled ASC keeps its item in the live bag")
save = serializedCopy(save)
enabled.release()

local disabled = T.sdk.loadNone({ data = T.fixtures.fresh() })
local disabledReport = SaveData.validate(save, disabled.data)
T.eq(#disabledReport.lostMons, 1,
  "disabled ASC quarantines its Pokémon instead of deleting it")
T.eq(#disabledReport.lostItems, 1,
  "disabled ASC quarantines its item instead of deleting it")
T.eq(save.orphaned.mons[1].marker, "disable-save-reenable",
  "quarantine preserves the complete Pokémon record")
T.eq(save.orphaned.items[1].id, modItem,
  "quarantine preserves the item id")
T.eq(save.orphaned.items[1].count, 3,
  "quarantine preserves the item count")
save = serializedCopy(save)
disabled.release()

local reenabled = T.sdk.loadMod(modPath, { data = T.fixtures.fresh() })
T.eq(#reenabled.errors, 0,
  "ASC re-enables cleanly after the mod-off save cycle")
recognizeChikorita(reenabled.data)
local restoredReport = SaveData.validate(save, reenabled.data)
T.eq(#restoredReport.restoredMons, 1,
  "re-enabled ASC restores the quarantined Pokémon")
T.eq(#restoredReport.restoredItems, 1,
  "re-enabled ASC restores the quarantined item")
T.eq(save.orphaned, nil,
  "successful restoration clears the quarantine")

local restoredMon
for _, box in ipairs(save.boxes) do
  for _, mon in ipairs(box) do
    if mon.marker == "disable-save-reenable" then restoredMon = mon end
  end
end
T.eq(restoredMon and restoredMon.species, modSpecies,
  "the exact quarantined Pokémon record reaches storage")
T.eq(save.inventory[modItem], 3,
  "the exact quarantined item quantity returns to the bag")

reenabled.release()
T.finish("disable_save_reenable")
