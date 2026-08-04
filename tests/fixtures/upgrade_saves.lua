-- Sanitized trainer_rematch save buckets used by upgrade_matrix_test.lua.
--
-- 1.1.0 and 2.0.0 were generated from the schemas in the exact public
-- GitHub release archives named below.  3.1.0 and 4.1.1 are reduced copies
-- of real launcher saves whose save metadata records that mod version.
-- Player names, IDs and unrelated mod data are deliberately omitted.
--
-- The three 5.3.0 rows are intentionally labelled schema-derived synthetic
-- fixtures.  They model Red, Blue and Yellow separately against the exact
-- public 5.3.0 package hash, but they are NOT represented as downloaded
-- player saves.  Yellow's partner/mega subtrees are additionally corroborated
-- by the local 5.3 release-UAT save named in its evidence block.

return {
  {
    version = "1.1.0",
    provenance = {
      kind = "public-release",
      archive = "kanto-ascendant-1.1.0.zip",
      sha256 =
        "8133a177910bfab25b7e4e674282e1e1b9f8546b4076a04ac18a01732ea61832",
    },
    bucket = {
      step_clock = 640,
      trainers = {
        ROUTE_1_obj_1 = {
          rematches = 4, trainingCycles = 2,
          readyAt = 700, nextTrainingAt = 860,
          lastRest = 160, lastTraining = 160,
        },
      },
      postgame = {
        masterWins = { brock = true },
        crownWins = {}, eliteApexWins = {}, eliteCrownWins = {},
        catches = { ARTICUNO = true }, roamers = {}, bossRest = {},
      },
    },
    expect = { rematches = 4, research = false, daycare = false,
      fieldKit = false },
  },
  {
    version = "2.0.0",
    provenance = {
      kind = "public-release",
      archive = "kanto-ascendant-2.0.0.zip",
      sha256 =
        "3ec473df41ac7e37663a2a90f3043fc686a0a968b29ba0e1a8ddb62b531274b5",
    },
    bucket = {
      step_clock = 2048,
      trainers = {
        ROUTE_1_obj_1 = {
          rematches = 12, trainingCycles = 5,
          readyAt = 1900, nextTrainingAt = 2200,
          lastRest = 151, lastTraining = 251,
        },
      },
      postgame = {
        masterWins = { brock = true, misty = true },
        crownWins = {}, eliteApexWins = {}, eliteCrownWins = {},
        catches = { ARTICUNO = true, ZAPDOS = true },
        roamers = {}, bossRest = {},
      },
      ascendant = {
        research = { completed = { rematch_field = true } },
        gymQuests = { brock = { done = true } },
        achievements = { rematch_10 = true },
        metrics = {}, bossBattles = { ["gym:brock:master"] = 1 },
        tournament = { runs = 1, wins = 0, best = 2 },
        rocketStage = 1, mewStage = 0, cycle = 0,
      },
    },
    expect = { rematches = 12, research = true, daycare = false,
      fieldKit = false },
  },
  {
    version = "3.1.0",
    provenance = {
      kind = "real-launcher-save",
      source = "red/slot2.lua.bak",
      savedModVersion = "3.1.0",
      archiveSha256 =
        "d84a5c2879622f5fa631c60d40387d0d46f236fcfe5302531fc064336942b4d9",
    },
    bucket = {
      step_clock = 10154,
      trainers = {
        ROUTE_1_obj_1 = {
          rematches = 18, trainingCycles = 7,
          readyAt = 9999, nextTrainingAt = 10250,
          lastRest = 192, lastTraining = 224,
        },
      },
      postgame = {
        masterWins = { brock = true },
        crownWins = {}, eliteApexWins = {}, eliteCrownWins = {},
        catches = { MEWTWO = true }, roamers = {},
        bossRest = { ["master:brock"] = 10269 },
      },
      ascendant = {
        research = { completed = { rematch_field = true } },
        gymQuests = {}, achievements = {
          rematch_10 = true, rematch_50 = true,
        },
        metrics = {}, bossBattles = { ["gym:brock:master"] = 1 },
        tournament = { runs = 0, wins = 0, best = 0 },
        rocketStage = 0, mewStage = 0, cycle = 0,
      },
      daycare_plus = {
        version = 2, parents = {}, eggMeter = 255,
        reservedEggs = {
          { species = "TOGEPI", steps = 96,
            origin = "ROUTE 5 DAY-CARE QA" },
        },
        eggsProduced = 1, eggsHatched = 0,
      },
      event_archive = {
        version = 1, claimed = {}, cups = {}, roamers = {}, visits = {},
      },
      johto_research = {
        version = 1, starters = { chikorita = true },
        rewards = { SENTRET = true }, trackWins = {},
        eggsQueued = {}, eggsHatched = {}, itemsClaimed = {},
        partnersClaimed = {}, eggQueue = {}, pendingMons = {},
        pendingItems = {},
      },
      mega_evolution = {
        version = 2, ring = true, case = true,
        stones = { VENUSAURITE = true, BLASTOISINITE = true },
        preferences = { CHARIZARD = "CHARIZARD_X" },
        activations = 1,
      },
    },
    expect = { rematches = 18, research = true, daycare = true,
      fieldKit = false },
  },
  {
    version = "4.1.1",
    provenance = {
      kind = "real-launcher-save",
      source = "red/slot1.lua.bak",
      savedModVersion = "4.1.1",
    },
    bucket = {
      step_clock = 622,
      trainers = {
        ROUTE_1_obj_1 = {
          rematches = 1, trainingCycles = 1,
          readyAt = 700, nextTrainingAt = 900,
          lastRest = 173, lastTraining = 223,
        },
      },
      postgame = {
        masterWins = { brock = true },
        crownWins = {}, eliteApexWins = {}, eliteCrownWins = {},
        catches = {}, roamers = {}, bossRest = {},
      },
      ascendant = {
        research = { completed = {} }, gymQuests = {},
        achievements = {}, metrics = {}, bossBattles = {},
        tournament = { runs = 0, wins = 0, best = 0 },
        frontierPoints = 0, typeMastery = {},
        rocketStage = 0, mewStage = 0, cycle = 0,
      },
      daycare_plus = {
        version = 2, parents = {}, eggMeter = 0, reservedEggs = {},
        eggsProduced = 0, eggsHatched = 0,
      },
      event_archive = {
        version = 1, claimed = {}, cups = {}, roamers = {}, visits = {},
      },
      johto_research = {
        version = 1, starters = {}, rewards = {}, trackWins = {},
        eggsQueued = {}, eggsHatched = {}, itemsClaimed = {},
        partnersClaimed = {}, eggQueue = {}, pendingMons = {},
        pendingItems = {},
      },
      mega_evolution = {
        version = 2, ring = false, case = false,
        stones = {}, preferences = {}, activations = 0,
      },
      field_tech = {
        version = 1, kit = true, rematchWins = 1,
        tmWins = 4, tmCursor = 2, tmCycles = 1,
        pendingTM = "TM03", signatureUnlocked = {},
        signatureAwarded = {},
      },
      johto_masters = {
        version = 1, attempts = 2, clears = 1, gifts = 1, title = true,
      },
      shiny_system = {
        version = 1, seen = { GYARADOS = true },
        caught = { GYARADOS = true }, rematchStreak = 1,
        bestStreak = 1, totalRematchWins = 1, outbreakIndex = 0,
        encounters = { ZUBAT = 9 }, caughtCounts = { GYARADOS = 1 },
        awards = {},
      },
      world_events = {
        version = 1, index = 2, nextAt = 2048,
        active = { id = "golden_wind", steps = 512 },
      },
    },
    expect = { rematches = 1, research = false, daycare = false,
      fieldKit = true },
  },
  {
    version = "5.3.0",
    gameVersions = { "red" },
    provenance = {
      kind = "schema-derived-synthetic",
      publishedSave = false,
      package = "kanto-ascendant-5.3.0.modpkg",
      packageSha256 =
        "ebcbdbee9f416f9c58ff675b5e97c6d35931348946817b526152fd4b423ca666",
      note = "Minimal Red bucket composed from the public 5.3.0 schema.",
    },
    bucket = {
      step_clock = 5300,
      trainer_step_clock = 6120,
      trainers = {
        ROUTE_1_obj_1 = {
          rematches = 53, trainingCycles = 21,
          readyAt = 6250, nextTrainingAt = 6500,
          lastRest = 251, lastTraining = 512,
        },
      },
      postgame = {
        masterWins = { brock = true, misty = true },
        crownWins = {}, eliteApexWins = {}, eliteCrownWins = {},
        catches = {}, roamers = {}, bossRest = {},
      },
      ascendant = {
        research = { completed = { rematch_field = true } },
        gymQuests = {}, achievements = { rematch_50 = true },
        metrics = {}, bossBattles = {},
        tournament = { runs = 2, wins = 1, best = 3 },
        frontierPoints = 7, typeMastery = {},
        rocketStage = 2, mewStage = 1, mewCaught = false, cycle = 1,
      },
      daycare_plus = {
        version = 2, parents = {}, eggMeter = 64, reservedEggs = {},
        eggsProduced = 2, eggsHatched = 1,
      },
      event_archive = {
        version = 1, claimed = {}, cups = {}, roamers = {}, visits = {},
      },
      johto_research = {
        version = 2, starters = { chikorita = true },
        rewards = { SENTRET = true }, trackWins = { nature = 3 },
        eggsQueued = {}, eggsHatched = {}, itemsClaimed = {},
        partnersClaimed = {}, eggQueue = {}, pendingMons = {},
        pendingItems = {}, compensations = {},
      },
      mega_evolution = {
        version = 3, ring = true, case = true,
        stones = { VENUSAURITE = true },
        preferences = {}, activations = 2,
        secretUnlocked = false, secretActivations = 0,
      },
      field_tech = {
        version = 2, kit = true, rematchWins = 8,
        tmWins = 12, tmCursor = 4, tmCycles = 1,
        pendingTMs = { "TM03" }, signatureUnlocked = {},
        signatureAwarded = {},
      },
      johto_masters = {
        version = 1, attempts = 1, clears = 1, gifts = 1, title = true,
      },
      shiny_system = {
        version = 1, seen = {}, caught = {}, rematchStreak = 3,
        bestStreak = 9, totalRematchWins = 53, outbreakIndex = 1,
        encounters = { ZUBAT = 17 }, caughtCounts = {}, awards = {},
      },
      world_events = {
        version = 1, index = 3, nextAt = 7000,
        active = {
          id = "johto_migration", steps = 512,
          map = "ROUTE_12", species = "MARILL",
        },
      },
    },
    save = {
      pokedexSeen = { MEW = true },
      pokedexOwned = { MEW = true },
    },
    expect = {
      rematches = 53, research = true, daycare = true, fieldKit = true,
      signalsCompleted = { MEW = true },
      canonicalMewRepair = true,
      worldEvent = {
        id = "johto_migration", steps = 512,
        map = "ROUTE_12", species = "MARILL",
      },
    },
  },
  {
    version = "5.3.0",
    gameVersions = { "blue" },
    provenance = {
      kind = "schema-derived-synthetic",
      publishedSave = false,
      package = "kanto-ascendant-5.3.0.modpkg",
      packageSha256 =
        "ebcbdbee9f416f9c58ff675b5e97c6d35931348946817b526152fd4b423ca666",
      note = "Minimal Blue bucket composed from the public 5.3.0 schema.",
    },
    bucket = {
      step_clock = 5353,
      trainer_step_clock = 6400,
      trainers = {
        ROUTE_1_obj_1 = {
          rematches = 35, trainingCycles = 14,
          readyAt = 6500, nextTrainingAt = 6751,
          lastRest = 201, lastTraining = 384,
        },
      },
      postgame = {
        masterWins = { brock = true },
        crownWins = {}, eliteApexWins = {}, eliteCrownWins = {},
        catches = { CELEBI = false },
        roamers = {
          CELEBI = {
            map = "ROUTE_2", level = 35, attempts = 2,
          },
        },
        bossRest = {},
      },
      ascendant = {
        research = { completed = { rematch_field = true } },
        gymQuests = {}, achievements = {}, metrics = {}, bossBattles = {},
        tournament = { runs = 1, wins = 0, best = 2 },
        frontierPoints = 3, typeMastery = {},
        rocketStage = 1, mewStage = 1, cycle = 0,
      },
      daycare_plus = {
        version = 2, parents = {}, eggMeter = 0, reservedEggs = {},
        eggsProduced = 0, eggsHatched = 0,
      },
      event_archive = {
        version = 1, claimed = {}, cups = {}, roamers = {}, visits = {},
      },
      johto_research = {
        version = 2, starters = { totodile = true },
        rewards = {}, trackWins = {}, eggsQueued = {}, eggsHatched = {},
        itemsClaimed = {}, partnersClaimed = {}, eggQueue = {},
        pendingMons = {}, pendingItems = {}, compensations = {},
      },
      mega_evolution = {
        version = 3, ring = true, case = true,
        stones = { BLASTOISINITE = true },
        preferences = {}, activations = 1,
        secretUnlocked = false, secretActivations = 0,
      },
      field_tech = {
        version = 2, kit = true, rematchWins = 4,
        tmWins = 6, tmCursor = 2, tmCycles = 0,
        pendingTMs = {}, signatureUnlocked = {}, signatureAwarded = {},
      },
      johto_masters = {
        version = 1, attempts = 0, clears = 0, gifts = 0, title = false,
      },
      shiny_system = {
        version = 1, seen = {}, caught = {}, rematchStreak = 0,
        bestStreak = 2, totalRematchWins = 35, outbreakIndex = 0,
        encounters = {}, caughtCounts = {}, awards = {},
      },
      world_events = {
        version = 1, index = 1, nextAt = 6900,
      },
    },
    save = {
      pokedexSeen = { CELEBI = true },
      pokedexOwned = { CELEBI = true },
    },
    expect = {
      rematches = 35, research = true, daycare = false, fieldKit = true,
      signalsCompleted = { CELEBI = true },
      canonicalCelebiRepair = true,
    },
  },
  {
    version = "5.3.0",
    gameVersions = { "yellow" },
    provenance = {
      kind = "schema-derived-synthetic",
      publishedSave = false,
      package = "kanto-ascendant-5.3.0.modpkg",
      packageSha256 =
        "ebcbdbee9f416f9c58ff675b5e97c6d35931348946817b526152fd4b423ca666",
      note = "Minimal Yellow bucket composed from the public 5.3.0 schema.",
      evidence = {
        kind = "local-release-uat-save",
        published = false,
        source = "releases/yellow-partner-manual-test/"
          .. "slot3-heart-mega.lua",
        sourceSha256 =
          "61eafeea3020a9394fd441746f5275ec5d3a08358d8f979302788dc4539fefd0",
        corroborates = { "yellow_partner", "mega_evolution" },
      },
    },
    bucket = {
      step_clock = 5251,
      trainer_step_clock = 6030,
      trainers = {
        ROUTE_1_obj_1 = {
          rematches = 25, trainingCycles = 10,
          readyAt = 6200, nextTrainingAt = 6451,
          lastRest = 251, lastTraining = 300,
        },
      },
      postgame = {
        masterWins = { brock = true },
        crownWins = {}, eliteApexWins = {}, eliteCrownWins = {},
        catches = {}, roamers = {}, bossRest = {},
      },
      ascendant = {
        research = { completed = { rematch_field = true } },
        gymQuests = {}, achievements = {}, metrics = {}, bossBattles = {},
        tournament = { runs = 1, wins = 1, best = 3 },
        frontierPoints = 5, typeMastery = {},
        rocketStage = 1, mewStage = 0, cycle = 0,
      },
      daycare_plus = {
        version = 2, parents = {}, eggMeter = 0, reservedEggs = {},
        eggsProduced = 0, eggsHatched = 0,
      },
      event_archive = {
        version = 1, claimed = {}, cups = {}, roamers = {}, visits = {},
      },
      johto_research = {
        version = 2, starters = {}, rewards = {}, trackWins = {},
        eggsQueued = {}, eggsHatched = {}, itemsClaimed = {},
        partnersClaimed = {}, eggQueue = {}, pendingMons = {},
        pendingItems = {}, compensations = {},
      },
      mega_evolution = {
        version = 3, ring = true, case = true,
        stones = { RAICHUNITE_X = true, RAICHUNITE_Y = true },
        preferences = { RAICHU = "RAICHU_X" },
        activations = 0, secretUnlocked = false, secretActivations = 0,
      },
      yellow_partner = {
        version = 1, initialized = true, offered = true, accepted = true,
        declined = false, legacy = true, steps = 251, wins = 3,
        heartGiven = true,
      },
      field_tech = {
        version = 2, kit = true, rematchWins = 3,
        tmWins = 5, tmCursor = 1, tmCycles = 0,
        pendingTMs = {}, signatureUnlocked = {}, signatureAwarded = {},
      },
      johto_masters = {
        version = 1, attempts = 0, clears = 0, gifts = 0, title = false,
      },
      shiny_system = {
        version = 1, seen = {}, caught = {}, rematchStreak = 1,
        bestStreak = 4, totalRematchWins = 25, outbreakIndex = 0,
        encounters = {}, caughtCounts = {}, awards = {},
      },
      world_events = {
        version = 1, index = 2, nextAt = 6800,
      },
    },
    save = {
      yellowPartner = true,
      champion = false,
      hallOfFame = false,
    },
    expect = {
      rematches = 25, research = true, daycare = false, fieldKit = true,
      signalsCompleted = {},
      yellowPartner = true,
      onboarding = false,
    },
  },
}
