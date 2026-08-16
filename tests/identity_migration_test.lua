local assertions = 0
local function check(value, label)
  assertions = assertions + 1
  if not value then error("FAIL: " .. label, 2) end
end

-- The hardened 0.1.86 facade intentionally exposes only newGame.  Identity
-- migration must not ask it for raw option load/save helpers.
local SaveData = { newGame = function() return {} end }
package.loaded["src.core.SaveData"] = SaveData

local loader = {
  modOptions = {
    trainer_rematch = {
      kanto_151 = "wild",
      ascendant_qol = true,
      qol_easy_interactions = false,
      trainer_portrait_style = "frlg",
      living_world_random_encounters = false,
    },
    other_mod = { untouched = { value = 17 } },
  },
  modSave = {},
}
local function optionGet(_, key)
  local bucket = loader.modOptions.kanto_ascendant
  return bucket and bucket[key]
end

local events = {}
local savedOptions
local game = {
  mods = loader,
  save = { options = { modOptions = loader.modOptions } },
  writeOptions = function(self)
    savedOptions = self.save.options
    return true
  end,
}
local mod = {
  id = "kanto_ascendant",
  version = "6.5.0",
  manifest = { api = 2 },
  options = { get = optionGet },
  game = game,
  exports = {},
  events = {
    on = function(_, name, callback, priority)
      events[name] = { callback = callback, priority = priority }
    end,
  },
}

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local migration = assert(loadfile(modPath .. "/identity_migration.lua"))()
check(migration.install(mod) == true, "identity bridge installs")
check(loader.modOptions.kanto_ascendant.kanto_151 == "wild",
  "legacy Kanto options migrate to the canonical id")
check(loader.modOptions.kanto_ascendant.trainer_portrait_style == "frlg",
  "trainer portrait selection migrates to the canonical id")
check(loader.modOptions.kanto_ascendant.living_world_random_encounters == false,
  "an explicit legacy Random Battles OFF choice remains OFF")
check(loader.modOptions.kanto_ascendant
    ~= loader.modOptions.trainer_rematch,
  "options migration does not alias the rollback bucket")
check(mod.exports.identityMigration.bootOptions.modOptions.kanto_ascendant == nil
    and mod.exports.identityMigration.bootOptions.modOptions
      .trainer_rematch.kanto_151 == "wild",
  "pre-merge identity snapshot is data-only and preserves the old authority")
check(mod.exports.identityMigration.bootOptions.modOptions.other_mod == nil,
  "identity export never exposes a foreign option bucket")
check(events["save.loading"].priority == 10000,
  "save namespace migrates before normal load handlers")
check(events["save.writing"].priority == -10000,
  "rollback shadow runs after feature snapshots")

local oldBucket = {
  step_clock = 222,
  trainers = { TREE = { rematches = 4 } },
  postgame = { catches = { ARTICUNO = true } },
  extended_characters = {
    version = 1, enabled = true, player_character = "GREEN",
    rival_character = "RED", third_character = "BLUE",
  },
}
local save = {
  modData = { trainer_rematch = oldBucket },
  meta = {
    format = 2,
    mods = {
      { id = "deutsch", version = "1.0.0", api = 2 },
      { id = "trainer_rematch", version = "5.3.0", api = 2 },
    },
  },
}
events["save.loading"].callback({ raw = save })
check(save.modData.kanto_ascendant.step_clock == 222,
  "old progress migrates before validation")
check(save.modData.kanto_ascendant ~= oldBucket,
  "save migration deep-copies the old namespace")
check(save.modData.kanto_ascendant.extended_characters.player_character == "GREEN",
  "extended character identity migrates with the canonical namespace")
check(save.modData.trainer_rematch == oldBucket,
  "loading leaves the old namespace available for rollback")
check(save.meta.mods[1].id == "deutsch"
    and save.meta.mods[2].id == "kanto_ascendant",
  "load metadata replaces the obsolete identity")
check(save.meta.mods[2].version == "5.3.0",
  "canonical migrations see the actual prior Kanto version")

save.modData.kanto_ascendant.step_clock = 999
save.modData.kanto_ascendant.postgame.catches.MEWTWO = true
save.meta.mods = {
  { id = "deutsch", version = "1.0.0", api = 2 },
  { id = "kanto_ascendant", version = "6.5.0", api = 2 },
}
events["save.writing"].callback({ save = save, meta = save.meta })
check(save.modData.trainer_rematch.step_clock == 999,
  "save writing mirrors current progress for RC9 rollback")
check(save.modData.trainer_rematch.postgame.catches.MEWTWO == true,
  "rollback shadow includes newly earned nested progress")
check(save.modData.trainer_rematch ~= save.modData.kanto_ascendant,
  "rollback save namespace is an independent copy")
check(save.meta.mods[2].id == "kanto_ascendant"
    and save.meta.mods[3].id == "trainer_rematch",
  "written metadata carries canonical and rollback identities")

loader.modOptions.kanto_ascendant.qol_easy_interactions = true
game:writeOptions()
check(savedOptions.modOptions.trainer_rematch.qol_easy_interactions == true,
  "every game options write refreshes the RC9 rollback shadow")
check(savedOptions.modOptions.other_mod.untouched.value == 17,
  "rollback refresh leaves foreign option buckets untouched")
check(SaveData.loadOptions == nil and SaveData.saveOptions == nil,
  "identity bridge needs no raw SaveData option helpers")

local validationEvents = {}
local validationMod = {
  id = "kanto_ascendant", version = "6.5.0", manifest = { api = 2 },
  options = {}, exports = {},
  events = { on = function(_, name, callback)
    validationEvents[name] = callback
  end },
}
check(migration.install(validationMod) == true,
  "game-less official validation context still loads the mod")
check(validationMod.exports.identityMigration.legacyOptionsDetected == false
    and next(validationMod.exports.identityMigration.bootOptions.modOptions) == nil,
  "game-less validation exposes no guessed option authority")
local validationSave = {
  modData = { trainer_rematch = { step_clock = 7 } },
  meta = { mods = { { id = "trainer_rematch", version = "5.3.0", api = 2 } } },
}
validationEvents["save.loading"]({ raw = validationSave })
check(validationSave.modData.kanto_ascendant.step_clock == 7,
  "game-less install retains signature-gated save migration")

print(("identity migration: %d assertions passed"):format(assertions))
