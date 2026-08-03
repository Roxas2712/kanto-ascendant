-- Sanitized trainer_rematch save buckets used by upgrade_matrix_test.lua.
--
-- 1.1.0 and 2.0.0 were generated from the schemas in the exact public
-- GitHub release archives named below.  3.1.0 and 4.1.1 are reduced copies
-- of real launcher saves whose save metadata records that mod version.
-- Player names, IDs and unrelated mod data are deliberately omitted.

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
}
