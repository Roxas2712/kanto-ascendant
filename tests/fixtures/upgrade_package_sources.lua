-- Immutable-source descriptions for the RC 6.5 package upgrade matrix.
--
-- IMPORTANT PROVENANCE NOTE
-- -------------------------
-- The four historical release archives pinned below contain product code and
-- manifests, but no published player save.  The save buckets in this file are
-- therefore deliberately small, sanitized, schema-derived fixtures.  They are
-- not represented as captured user data.  The package driver mounts the real
-- archive, checks its manifest/schema markers, then writes the corresponding
-- fixture through the engine's native slot API before the current package
-- performs the migration.

local function randomizer(enabled)
  return {
    enabled = enabled == true,
    wild = true, trainers = true, starters = true,
    gifts = false, static = false, items = false, legendary = false,
    balanced = true, consistent = true,
  }
end

local function nuzlocke(mode)
  return {
    mode = mode or "off", dupes = true, blackout = "end",
    shinyOdds = 4096,
  }
end

local function v1ReasonlessRules()
  return {
    version = 1, configured = true, locked = true,
    preset = "standard", seed = 650025,
    randomizer = randomizer(false), nuzlocke = nuzlocke("off"),
    mappings = { species = {}, items = {} }, areas = {}, deaths = {},
    encounterSerial = 0,
  }
end

local function v2ConfirmedRules(seed)
  return {
    version = 2, configured = true, locked = true,
    lockReason = "player_pc", legacyProgress = true,
    preset = "classic", seed = seed,
    randomizer = randomizer(true), nuzlocke = nuzlocke("standard"),
    mappings = { species = { RATTATA = "PIDGEY" }, items = {} },
    areas = { ROUTE_1 = { species = "RATTATA", family = "RATTATA" } },
    deaths = {}, encounterSerial = 7,
  }
end

local provenance = {
  kind = "schema-derived-sanitized",
  publishedSave = false,
  containsPlayerPII = false,
  statement = "Historical archive contains no player save; fixture is derived from the shipped schema.",
}

return {
  v6_0_11 = {
    key = "v6_0_11",
    archiveName = "kanto-ascendant-6.0.11.modpkg",
    archiveBytes = 16662061,
    archiveSha256 = "72779b0a9923e2e3908573552858718aa09bc6eae25222d1268bf3f1e41b62e7",
    manifestId = "trainer_rematch",
    manifestVersion = "6.0.11",
    schemaEntry = "main.lua",
    schemaEntryBytes = 75829,
    schemaEntrySha256 = "3c66e844c67ed10f63e8f5a9789496f31c350700cd7b3a8c6acd1d3e1f8d0bfe",
    schemaMarkers = { "mod.save:get(\"step_clock\"", "mod.exports.ascendant" },
    runRulesEntry = false,
    provenance = provenance,
    optionNamespace = "trainer_rematch",
    options = { kanto_151 = "wild", follower_count = 3 },
    saveNamespace = "trainer_rematch",
    sourceBucket = {
      step_clock = 6011,
      trainer_step_clock = 12022,
      ascendant = { rank = 4, research = { completed = { rematch_field = true } } },
      postgame = { catches = { ARTICUNO = true }, masterWins = { brock = true } },
      trainers = { ROUTE_1_obj_1 = { rematches = 6, readyAt = 0 } },
    },
    expectedInitialRuleState = "unlocked",
    expectedLegacyOptionMigration = true,
  },

  rc25 = {
    key = "rc25",
    archiveName = "kanto-ascendant-6.5.0-rc25-test.zip",
    archiveBytes = 37749193,
    archiveSha256 = "9d340d9badf940adc7bd1a36b43d66a4d02b84229a63df8c5caa85939fdab9a5",
    manifestId = "kanto_ascendant",
    manifestVersion = "6.5.0",
    schemaEntry = "run_rules.lua",
    schemaEntryBytes = 25216,
    schemaEntrySha256 = "f8dd2040b7aaf793ba6fd0203e09aaa6e1aa07b2cc46994572fa1898d043f884",
    schemaMarkers = {
      "version = 1, configured = progressed == true, locked = progressed == true",
      "s.version = 1",
    },
    runRulesEntry = true,
    provenance = provenance,
    optionNamespace = "kanto_ascendant",
    options = { kanto_151 = "ascendant", follower_count = 2 },
    saveNamespace = "kanto_ascendant",
    sourceBucket = {
      step_clock = 6525,
      ascendant = { rank = 5 },
      trainers = { ROUTE_1_obj_1 = { rematches = 25, readyAt = 0 } },
      run_rules = v1ReasonlessRules(),
    },
    expectedInitialRuleState = "unlocked",
    expectedLegacyOptionMigration = false,
  },

  rc26 = {
    key = "rc26",
    archiveName = "kanto-ascendant-6.5.0-rc26-test.zip",
    archiveBytes = 37794577,
    archiveSha256 = "0b0fcd765a1dd6d64584d2dd5c116bbabf9a8218c77314e7d5de5937d63e2418",
    manifestId = "kanto_ascendant",
    manifestVersion = "6.5.0",
    schemaEntry = "run_rules.lua",
    schemaEntryBytes = 26416,
    schemaEntrySha256 = "00cd36afb48aeea5ddaac83a4cb6295f5df3c89d66971d71ee9435775e7b8ecc",
    schemaMarkers = {
      "version = 2, configured = false, locked = false",
      "previousVersion < 2",
      "s.lockReason == nil",
    },
    runRulesEntry = true,
    provenance = provenance,
    optionNamespace = "kanto_ascendant",
    options = { kanto_151 = "ascendant", follower_count = 1 },
    saveNamespace = "kanto_ascendant",
    sourceBucket = {
      step_clock = 6526,
      ascendant = { rank = 6 },
      trainers = { ROUTE_1_obj_1 = { rematches = 26, readyAt = 0 } },
      run_rules = v2ConfirmedRules(650026),
    },
    expectedInitialRuleState = "locked",
    expectedLegacyOptionMigration = false,
  },

  rc27 = {
    key = "rc27",
    archiveName = "kanto-ascendant-6.5.0-rc27-test.zip",
    archiveBytes = 37983841,
    archiveSha256 = "fb870c51b22ac87be7a3c79ec98e6fe798196946c96abec439e5915d99af5912",
    manifestId = "kanto_ascendant",
    manifestVersion = "6.5.0",
    schemaEntry = "run_rules.lua",
    schemaEntryBytes = 26416,
    schemaEntrySha256 = "00cd36afb48aeea5ddaac83a4cb6295f5df3c89d66971d71ee9435775e7b8ecc",
    schemaMarkers = {
      "version = 2, configured = false, locked = false",
      "previousVersion < 2",
      "s.lockReason == nil",
    },
    runRulesEntry = true,
    provenance = provenance,
    optionNamespace = "kanto_ascendant",
    options = { kanto_151 = "ascendant", follower_count = 4 },
    saveNamespace = "kanto_ascendant",
    sourceBucket = {
      step_clock = 6527,
      ascendant = { rank = 7 },
      -- RC27 already stores follower configuration per save slot.  Keep the
      -- schema-derived fixture internally consistent with the historical
      -- process-global option below: on load follower_config deliberately
      -- mirrors this slot-local value back into the live option buckets.
      follower_config = {
        version = 1, count = 4, mode = "party",
        presentation = "ascendant_box", custom = {}, nextId = 0,
      },
      trainers = { ROUTE_1_obj_1 = { rematches = 27, readyAt = 0 } },
      run_rules = v2ConfirmedRules(650027),
    },
    expectedInitialRuleState = "locked",
    expectedLegacyOptionMigration = false,
  },
}
