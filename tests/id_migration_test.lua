package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local migration = dofile((os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant") .. "/id_migration.lua")

package.loaded["src.core.SaveData"] = {
  newGame = function() return {} end,
}

local legacyOptions = {
  modOptions = {
    trainer_rematch = {
      language = "de",
      kanto_151 = "wild",
      follower_count = 4,
      difficulty = "hard",
    },
  },
}

do
  local schema = {
    { key = "language", default = "auto" },
    { key = "kanto_151", default = "ascendant" },
    { key = "follower_count", default = 1 },
    { key = "unrelated", default = true },
  }
  T.eq(migration.applyOptionDefaults(schema, legacyOptions), true,
    "legacy options seed the renamed schema on first boot")
  T.eq(schema[1].default, "de", "language is retained")
  T.eq(schema[2].default, "wild", "Kanto mode is retained")
  T.eq(schema[3].default, 4, "follower count is retained")
  T.eq(schema[4].default, true, "new defaults remain untouched")

  local currentWins = {
    modOptions = {
      trainer_rematch = { language = "de" },
      kanto_ascendant = { language = "en" },
    },
  }
  T.eq(migration.applyOptionDefaults(schema, currentWins), false,
    "an existing current bucket is never overwritten")
  T.eq(schema[1].default, "de",
    "schema mutation from the earlier isolated case remains explicit")
end

do
  local mod = { id = "kanto_ascendant", exports = { identityMigration = {
    bootOptions = legacyOptions,
    legacyOptionsDetected = true,
  } } }
  local api = migration.new(mod)
  T.eq(api.bootOptions.modOptions.trainer_rematch.kanto_151, "wild",
    "sandbox bridge supplies the pre-merge legacy option snapshot")
  T.eq(package.loaded["src.core.SaveData"].loadOptions, nil,
    "id migration does not require raw SaveData.loadOptions")
end

do
  local unrelated = { modOptions = { trainer_rematch = {
    language = "de", difficulty = "hard",
  } } }
  local schema = { { key = "language", default = "auto" } }
  T.eq(migration.applyOptionDefaults(schema, unrelated), false,
    "unrelated trainer-rematch options without an Ascendant signature are ignored")
  T.eq(schema[1].default, "auto",
    "unproven legacy options do not alter canonical defaults")
end

-- Wild scaling did not exist in accepted 6.x saves. Identity migration must
-- not infer it from the old difficulty tier: absence keeps the new explicit
-- opt-in OFF, while a later canonical choice remains stored independently.
do
  local migrated = {
    { key = "difficulty", default = "standard" },
    { key = "wild_level_scaling", default = false },
  }
  T.eq(migration.applyOptionDefaults(migrated, legacyOptions), true,
    "legacy difficulty still migrates through the accepted KA signature")
  T.eq(migrated[1].default, "hard", "legacy trainer difficulty is retained")
  T.eq(migrated[2].default, false,
    "a migrated save cannot infer Wild scaling from trainer difficulty")

  local canonical = {
    { key = "wild_level_scaling", default = false },
  }
  T.eq(migration.applyOptionDefaults(canonical, { modOptions = {
    trainer_rematch = { kanto_151 = "wild" },
    kanto_ascendant = { wild_level_scaling = true },
  } }), false, "canonical Wild-scaling choice is never overwritten")
  T.eq(canonical[1].default, false,
    "schema default remains OFF beside a stored canonical opt-in")
end

-- The 6.5 Living World default changes only the absence case. A profile
-- without the key receives the new `true` schema default; a historical
-- explicit OFF value remains OFF through either identity-migration path.
do
  local freshSchema = {
    { key = "living_world_enabled", default = true },
    { key = "living_world_random_encounters", default = true },
  }
  T.eq(migration.applyOptionDefaults(freshSchema,
    { modOptions = { kanto_ascendant = {} } }), false,
    "a missing current key keeps the new both-enabled defaults")
  T.eq(freshSchema[2].default, true,
    "missing Random Battles defaults to ON")

  local legacyOffSchema = {
    { key = "living_world_enabled", default = true },
    { key = "living_world_random_encounters", default = true },
  }
  T.eq(migration.applyOptionDefaults(legacyOffSchema, { modOptions = {
    trainer_rematch = {
      living_world_enabled = true,
      living_world_random_encounters = false,
    },
  } }), true, "legacy explicit Random Battles OFF is migrated")
  T.eq(legacyOffSchema[1].default, true,
    "legacy visible Wilds ON remains ON")
  T.eq(legacyOffSchema[2].default, false,
    "legacy explicit Random Battles OFF remains OFF")

  local currentOffSchema = {
    { key = "living_world_random_encounters", default = true },
  }
  T.eq(migration.applyOptionDefaults(currentOffSchema, { modOptions = {
    trainer_rematch = { living_world_random_encounters = true },
    kanto_ascendant = { living_world_random_encounters = false },
  } }), false, "canonical explicit OFF is never overwritten")
  T.eq(currentOffSchema[1].default, true,
    "schema stays the absence fallback while canonical OFF stays stored")
end

do
  local save = {
    meta = { mods = {
      { id = "trainer_rematch", version = "6.0.7", api = 2 },
      { id = "deutsch", version = "1.0.0", api = 2 },
    } },
    options = legacyOptions,
    modData = {
      trainer_rematch = {
        step_clock = 151,
        ascendant = { rank = 4 },
        trainers = { ROUTE_1 = { rematches = 3 } },
      },
      kanto_ascendant = { step_clock = 200 },
    },
  }
  T.eq(migration.migrateSave(save), true,
    "accepted 6.0.7 save is recognized")
  T.eq(save.modData.kanto_ascendant.step_clock, 200,
    "current progress wins over the rollback snapshot")
  T.eq(save.modData.kanto_ascendant.ascendant.rank, 4,
    "missing Ascendant progress is copied")
  T.eq(save.modData.kanto_ascendant.trainers.ROUTE_1.rematches, 3,
    "rematch progression is copied")
  T.eq(save.modData.trainer_rematch.ascendant.rank, 4,
    "legacy rollback bucket is retained")
  T.eq(save.meta.mods[1].id, "kanto_ascendant",
    "save metadata adopts the permanent identity")
  T.eq(save.meta.mods[2].id, "deutsch",
    "unrelated metadata is preserved")
end

do
  local unrelated = {
    meta = { mods = {
      { id = "trainer_rematch", version = "1.0.0", api = 2 },
    } },
    modData = {
      trainer_rematch = { trainers = { ROUTE_1 = true } },
    },
  }
  T.eq(migration.migrateSave(unrelated), false,
    "the unrelated 1.x trainer-rematch mod is not claimed")
  T.eq(unrelated.modData.kanto_ascendant, nil,
    "no false-positive namespace is created")
end

do
  local writes = 0
  local game = {
    mods = { modOptions = { kanto_ascendant = {
      language = "de", kanto_151 = "wild", follower_count = 4,
    } } },
    save = { options = { modOptions = {} } },
    writeOptions = function(self)
      writes = writes + 1
      self.save.options.modOptions.trainer_rematch = {
        language = self.save.options.modOptions.kanto_ascendant.language,
      }
    end,
  }
  local schema = {
    { key = "language" }, { key = "kanto_151" },
    { key = "follower_count" },
  }
  T.eq(migration.persistOptions(game, schema, legacyOptions), true,
    "legacy options are persisted under the permanent ID")
  T.eq(game.mods.modOptions.kanto_ascendant.language, "de",
    "live loader sees migrated language")
  T.eq(game.save.options.modOptions.kanto_ascendant.follower_count, 4,
    "options.lua payload sees migrated follower count")
  T.eq(game.save.options.modOptions.kanto_ascendant.difficulty, "hard",
    "rollback-only historical option keys remain available")
  T.eq(game.save.options.modOptions.trainer_rematch.language, "de",
    "game write refreshes the rollback option shadow")
  T.eq(writes, 1, "migration writes options exactly once")
  T.eq(migration.persistOptions(game, schema, legacyOptions), false,
    "option migration is idempotent")
  T.eq(writes, 1, "idempotent rerun does not write again")
end

do
  local writes = 0
  local game = {
    mods = { modOptions = {
      kanto_ascendant = { language = "en" },
    } },
    save = { options = { modOptions = {
      kanto_ascendant = { language = "en" },
    } } },
    writeOptions = function() writes = writes + 1 end,
  }
  local schema = {
    { key = "language" }, { key = "kanto_151" },
    { key = "follower_count" },
  }
  T.eq(migration.persistOptions(game, schema, legacyOptions), true,
    "an interrupted partial migration resumes")
  T.eq(game.mods.modOptions.kanto_ascendant.language, "en",
    "current option remains authoritative")
  T.eq(game.mods.modOptions.kanto_ascendant.kanto_151, "wild",
    "missing legacy option is recovered")
  T.eq(writes, 1, "partial recovery persists once")
end

T.finish("id_migration")
