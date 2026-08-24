local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local Serializer = require("src.core.SaveSerializer")
local createArchive = assert(loadfile("legacy_archive.lua"))()

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local DEFAULT_RUN_RULES = {
  version = 1,
  preset = "standard",
  seed = 650001,
  randomizer = {
    enabled = false, wild = true, trainers = true, starters = true,
    gifts = true, static = true, items = false, legendary = false,
    balanced = true, consistent = true,
  },
  nuzlocke = {
    mode = "off", dupes = true, blackout = "end", shinyOdds = 4096,
  },
}

local function legacyMeta(extra)
  local result = {
    itemPolicy = "safe",
    runRules = DEFAULT_RUN_RULES,
  }
  for key, value in pairs(extra or {}) do result[key] = value end
  return result
end

local function clone(value)
  return assert(Serializer.decode(assert(Serializer.encode(value))))
end

local function totalWrites(fs)
  local total = 0
  for _, count in pairs(fs.writeCounts or {}) do total = total + count end
  return total
end

local function memfs()
  local files, writeCounts = {}, {}
  return {
    files = files,
    writeCounts = writeCounts,
    getInfo = function(path)
      return files[path] ~= nil and { type = "file" } or nil
    end,
    read = function(path) return files[path] end,
    write = function(path, bytes)
      files[path] = bytes
      writeCounts[path] = (writeCounts[path] or 0) + 1
      return true
    end,
    remove = function(path) files[path] = nil return true end,
    createDirectory = function() return true end,
  }
end

local fs = memfs()
local archive = createArchive({
  fs = fs,
  serializer = Serializer,
  edition = "red",
  modId = "kanto_ascendant",
  directory = "test/legacy",
  now = function() return 123456 end,
  isBadge = function(id) return id == "BOULDER_BADGE" end,
})
local validatorArchive = createArchive({
  fs = {}, serializer = Serializer, edition = "red",
})
eq(validatorArchive.persistent, false,
  "a validator without persistent storage can load the archive module")
eq(validatorArchive.write({}), false,
  "a validator filesystem never pretends that an archive write succeeded")

local charmander = {
  species = "CHARMANDER", nickname = "BLAZE", level = 36,
  exp = 50000, moves = { "EMBER", "SLASH" }, dvs = { atk = 15 },
  ot = "RED", otId = 77,
}
local pikachu = { species = "PIKACHU", level = 28, moves = { "THUNDERSHOCK" } }
local eevee = { species = "EEVEE", level = 25, moves = { "TACKLE" } }
local save = {
  version = "red",
  player = { id = 77, name = "ASH", rival = "GARY" },
  hallOfFame = { { charmander, pikachu } },
  flags = {
    EVENT_BEAT_CHAMPION_RIVAL = true,
    HEVO_META_RED = true,
  },
  party = { charmander, pikachu },
  boxes = { { eevee }, {} },
  inventory = { POTION = 3, BOULDER_BADGE = 1 },
  pcItems = { ANTIDOTE = 2 },
  money = 4242,
  modData = {
    kanto_ascendant = {
      extended_characters = { player_character = "GREEN" },
      ascendant = {
        achievements = {
          rematch_50 = true,
          factory_architect = true,
          PHANTOM_FROM_OLD_MOD = true,
        },
        latestAchievement = "PHANTOM_FROM_OLD_MOD",
        selectedTitle = "factory_architect",
      },
      legacy_hall = {
        version = 1, selectedTitle = "factory_architect", visits = 4,
      },
      hevo_persistent = {
        packageUnlocks = { protector = true },
        evolutionUnlocks = { RHYPERIOR = true },
        permanentItems = { PROTECTOR = 1 },
        firstGrants = { protector = true }, pendingItems = { PROTECTOR = 1 },
        dex = { RHYPERIOR = true },
        questionIds = { HEVO_Q_RED_01 = true },
      },
      hevo_run = {
        puzzles = { red = 3 }, statues = { red = true }, runComplete = true,
      },
      johto_masters = {
        clears = 2, gifts = 1, title = true,
        pendingGift = { species = "SHINY_CELEBI", source = "gold" },
        goldenTrainerCardDecor = true,
        passages = {
          silver = { status = "cleared", attempts = 2, puzzle = false,
            rewarded = true, clue = true, step = 3, resets = 1 },
          kris = { status = "entered", attempts = 1, puzzle = true,
            rewarded = false, clue = true, step = 2, resets = 4 },
          gold = { status = "locked", attempts = 0, puzzle = false },
        },
      },
    },
  },
}

-- A new v7 transaction is fail-closed: only an explicit, canonical snapshot
-- may create durable state. Malformed input must neither mutate the outgoing
-- Champion save nor write even a witness file.
local strictFs = memfs()
local strictArchive = createArchive({
  fs = strictFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/strict-rules",
})
local strictSource = {
  version = "red", player = { id = 7001, name = "RED", rival = "BLUE" },
  flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = { {} },
  party = {}, boxes = { {} }, inventory = {}, pcItems = {}, money = 0,
  modData = { kanto_ascendant = {} },
}
local invalidSnapshots = {
  { label = "missing snapshot", value = nil },
  { label = "invalid boolean", value = (function()
      local rules = clone(DEFAULT_RUN_RULES)
      rules.randomizer.wild = 1
      return rules
    end)() },
  { label = "invalid Nuzlocke mode", value = (function()
      local rules = clone(DEFAULT_RUN_RULES)
      rules.nuzlocke.mode = "undoable"
      return rules
    end)() },
  { label = "invalid seed", value = (function()
      local rules = clone(DEFAULT_RUN_RULES)
      rules.seed = 0
      return rules
    end)() },
  { label = "unknown authority field", value = (function()
      local rules = clone(DEFAULT_RUN_RULES)
      rules.futureOverride = true
      return rules
    end)() },
}
for _, row in ipairs(invalidSnapshots) do
  local beforeSave = assert(Serializer.encode(strictSource))
  local beforeWrites = totalWrites(strictFs)
  local current, reason = strictArchive.beginJourney(strictSource, {
    itemPolicy = "safe", runRules = row.value,
  })
  eq(current, nil, row.label .. " is rejected before transaction staging")
  ok(type(reason) == "string" and reason ~= "",
    row.label .. " reports a validation reason")
  eq(assert(Serializer.encode(strictSource)), beforeSave,
    row.label .. " leaves the source save byte-semantically unchanged")
  eq(totalWrites(strictFs), beforeWrites,
    row.label .. " performs zero persistent writes")
end
for _, row in ipairs(invalidSnapshots) do
  if row.value ~= nil then
    local tamperFs = memfs()
    local tamperArchive = createArchive({
      fs = tamperFs, serializer = Serializer, edition = "red",
      modId = "kanto_ascendant",
      directory = "test/tampered-current-" .. row.label:gsub("[^%w]", "-"),
    })
    local tampered = {
      version = 7, cycle = 1,
      current = {
        cycle = 1, runId = "tampered-current", status = "active",
        itemPolicy = "safe", runRules = clone(row.value),
      },
    }
    local bytes = assert(Serializer.encode(tampered))
    tamperFs.files[tamperArchive.filename] = bytes
    local sourceBefore = assert(Serializer.encode(strictSource))
    local rejected = tamperArchive.beginJourney(strictSource, legacyMeta())
    eq(rejected, nil,
      "persisted " .. row.label .. " current snapshot fails closed")
    eq(tamperFs.files[tamperArchive.filename], bytes,
      "persisted " .. row.label .. " snapshot is never rewritten")
    eq(totalWrites(tamperFs), 0,
      "persisted " .. row.label .. " snapshot causes zero writes")
    eq(assert(Serializer.encode(strictSource)), sourceBefore,
      "persisted " .. row.label .. " snapshot cannot mutate the source save")
  end
end
local missingV7, missingV7Err = strictArchive.normalize({
  version = 7, current = {
    status = "pending_new_game", runId = "tampered-v7", itemPolicy = "safe",
  },
})
eq(missingV7, nil, "v7 current state cannot silently downgrade missing rules")
ok(tostring(missingV7Err):find("missing", 1, true) ~= nil,
  "missing v7 rules report the fail-closed snapshot error")

-- v6 is the sole nil-snapshot compatibility case. Both pending/active state
-- and prepared/committed witnesses receive explicit SAFE/OFF migration
-- markers so retries remain deterministic without trusting malformed v7.
for _, status in ipairs({ "pending_new_game", "active" }) do
  local migrated = assert(strictArchive.normalize({
    version = 6,
    current = { status = status, runId = "v6-" .. status },
  }))
  eq(migrated.current.itemPolicy, "safe",
    "v6 " .. status .. " migrates to SAFE item policy")
  eq(migrated.current.runRulesLegacyDefault, true,
    "v6 " .. status .. " receives the authenticated OFF marker")
end
for _, state in ipairs({ "prepared", "committed" }) do
  local migrated = assert(strictArchive.normalize({
    version = 6, current = {}, transaction = {
      state = state, hall = {},
    },
  }))
  eq(migrated.transaction.hall.itemPolicy, "safe",
    "v6 " .. state .. " witness migrates to SAFE")
  eq(migrated.transaction.hall.runRulesLegacyDefault, true,
    "v6 " .. state .. " witness receives the authenticated OFF marker")
end

-- EMPTY means no optional Bag/PC cargo. The three earned Hoenn path stones
-- are deliberately exceptional visible souvenirs; unrelated Mega Stones do
-- not cross unless SAFE was selected.
local pathFs = memfs()
local pathArchive = createArchive({
  fs = pathFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/path-stones",
})
local pathSource = clone(strictSource)
pathSource.player.id = 7002
pathSource.inventory = { POTION = 9 }
pathSource.pcItems = { ANTIDOTE = 4 }
pathSource.modData.kanto_ascendant.mega_evolution = {
  stones = {
    BLAZIKENITE = true, SWAMPERTITE = true, SCEPTILITE = true,
    VENUSAURITE = true,
  },
}
local pathCurrent, pathStored = assert(pathArchive.beginJourney(pathSource,
  legacyMeta({ itemPolicy = "empty" })))
eq(pathCurrent.itemPolicy, "empty", "EMPTY is frozen in current metadata")
for _, stone in ipairs({ "BLAZIKENITE", "SWAMPERTITE", "SCEPTILITE" }) do
  eq(pathStored.locker.items[stone], 1,
    stone .. " crosses EMPTY exactly once as a path souvenir")
end
eq(pathStored.locker.items.VENUSAURITE, nil,
  "an unrelated Mega Stone remains SAFE-only")
eq(pathStored.locker.items.POTION, nil,
  "EMPTY excludes ordinary Bag cargo")
eq(pathStored.locker.items.ANTIDOTE, nil,
  "EMPTY excludes ordinary PC cargo")

ok(archive.isEligible(save), "Champion save unlocks the journey")
local summary = archive.summary(save)
eq(summary.pokemon, 3, "summary counts party and every box")
eq(summary.items, 5, "summary excludes badges and includes PC items")
eq(summary.nextCycle, 1, "first journey is cycle one")

local current, stored = assert(archive.beginJourney(save, legacyMeta({
  pact = "journey", starter = "CHARMANDER",
})))
eq(current.status, "pending_new_game", "committed transfer waits for New Game")
eq(current.bankUnlocked, false,
  "new-format bank access is policy-driven rather than pre-unlocked")
eq(current.pact, "journey", "the selected pact enters current run metadata")
eq(current.bankPolicy, "open",
  "Journey defaults its independently selectable Bank rule to OPEN")
eq(current.wanderersEnabled, true, "wanderers are active from run creation")
eq(stored.cycle, 1, "archive advances exactly one cycle")
eq(#stored.bank, 3, "all full Pokémon structures enter the bank")
eq(stored.bank[1].mon.moves[2], "SLASH", "moves survive the archive")
eq(stored.bank[1].mon.dvs.atk, 15, "DVs survive the archive")
eq(stored.locker.items.POTION, 3, "bag items enter the locker")
eq(stored.locker.items.ANTIDOTE, 2, "PC items enter the locker")
eq(stored.locker.items.BOULDER_BADGE, nil, "badges never enter the locker")
eq(stored.locker.money, 4242, "money enters the locker")
eq(stored.current.runRules.seed, DEFAULT_RUN_RULES.seed,
  "confirmed rules snapshot enters current transaction authority")
eq(stored.hallOfLegacy[1].runRules.seed, DEFAULT_RUN_RULES.seed,
  "the Hall receipt keeps the same immutable rules snapshot")
eq(stored.hallOfLegacy[1].playerAvatar, "GREEN",
  "completed avatar enters the Hall of Legacy")
ok(stored.titles.unlocked.rematch_50
    and stored.titles.unlocked.factory_architect,
  "authored achievement titles enter the durable archive")
eq(stored.titles.unlocked.PHANTOM_FROM_OLD_MOD, nil,
  "unknown achievement ids never enter the durable archive")
eq(stored.titles.selectedTitle, "factory_architect",
  "the active authored title enters the durable archive")
eq(stored.johtoMastersPersistent.clears, 2,
  "Johto Masters clears enter the durable archive")
ok(stored.johtoMastersPersistent.title
    and stored.johtoMastersPersistent.goldenTrainerCardDecor,
  "Johto title and golden Trainer Card decor enter the durable archive")
eq(stored.johtoMastersPersistent.passages.kris.status, "entered",
  "an in-progress Johto passage is preserved for the next journey")
eq(stored.johtoMastersPersistent.passages.kris.step, 2,
  "Johto arena decision progress survives the durable hand-off")
eq(stored.johtoMastersPersistent.passages.kris.resets, 4,
  "Johto arena retry counters survive the durable hand-off")
ok(stored.johtoMastersPersistent.passages.silver.rewarded
    and stored.johtoMastersPersistent.passages.silver.clue,
  "Johto rewarded and clue states survive the durable hand-off")
ok(fs.files[archive.rollbackFilename], "a standalone rollback snapshot exists")

local resumed, resumedArchive = assert(archive.beginJourney(save))
eq(resumed.runId, current.runId, "same source resumes the committed hand-off")
eq(resumedArchive.cycle, 1, "resume never creates another cycle")
eq(#resumedArchive.bank, 3, "resume never duplicates Pokémon")
eq(resumedArchive.locker.items.POTION, 3, "resume never duplicates items")
eq(#resumedArchive.hallOfLegacy, 1, "resume never duplicates Hall entries")

local fresh = {
  version = "red", player = { id = 88 }, party = {}, boxes = { {} },
  inventory = {}, pcItems = {}, modData = {},
}
ok(archive.seedNewSave(fresh), "real New Game receives pending legacy metadata")
local run = fresh.modData.kanto_ascendant.legacy_journey
local hevoRun = fresh.modData.kanto_ascendant.hevo_run
local hevoPersistent = fresh.modData.kanto_ascendant.hevo_persistent
local freshAscendant = fresh.modData.kanto_ascendant.ascendant
local freshHall = fresh.modData.kanto_ascendant.legacy_hall
local freshMasters = fresh.modData.kanto_ascendant.johto_masters
eq(run.cycle, 1, "new save knows its cycle")
eq(run.bankUnlocked, false, "new save does not carry an unconditional Bank bit")
eq(run.pact, "journey", "new save retains its immutable pact")
eq(run.bankPolicy, "open", "new save retains its separate Bank policy")
eq(run.wanderersEnabled, true, "new save starts with wanderers enabled")
eq(run.itemPolicy, "safe", "fresh save inherits the archived item policy")
eq(run.pendingRunRules.seed, DEFAULT_RUN_RULES.seed,
  "fresh save inherits the archived rules before the 151/251 choice")
eq(run.runRulesLocked, false,
  "fresh save leaves only the pool-finalization step pending")
ok(archive.importHandoff(fresh), "first new-run archive is verified")
ok(archive.markRunStarted(fresh), "first new-run save commits the hand-off")
ok(archive.finishHandoff(fresh), "first transient hand-off is retired")
eq(archive.current().status, "active", "archive marks the new run active")
eq(run.avatarQuestStage, 0, "new journey resets its active path stage")
ok(not run.completedPaths.red, "new profile migrates the red completion flag")
eq(next(hevoRun.puzzles), nil,
  "a new Legacy run resets local cave puzzle state")
eq(next(hevoRun.statues), nil,
  "a new Legacy run resets local statue state")
eq(hevoRun.runComplete, false,
  "a new Legacy run resets the local completion marker")
ok(fresh.flags.HEVO_META_RED,
  "HEVO character metadata survives the true New Game reset")
ok(hevoPersistent.evolutionUnlocks.RHYPERIOR,
  "permanent evolution unlocks survive the true New Game reset")
eq(hevoPersistent.permanentItems.PROTECTOR, 1,
  "permanent evolution items keep their durable count")
ok(hevoPersistent.dex.RHYPERIOR and hevoPersistent.questionIds.HEVO_Q_RED_01,
  "Dex registration and globally used question ids remain durable")
ok(hevoPersistent.packageUnlocks.protector
    and hevoPersistent.firstGrants.protector,
  "package authority and one-time first-grant state survive true New Game")
eq(hevoPersistent.pendingItems.PROTECTOR, 1,
  "an unclaimed first-grant item survives true New Game")
hevoPersistent.pendingItems.PROTECTOR = nil
ok(archive.syncHevoPersistent(fresh),
  "claiming a pending first grant synchronizes independently")
eq(next(archive.hevoPersistent().pendingItems), nil,
  "the pending queue clears exactly instead of monotonic reappearing")
ok(freshAscendant.achievements.rematch_50
    and freshAscendant.achievements.factory_architect,
  "normal unlocked titles survive the real Legacy New Game")
eq(freshAscendant.achievements.PHANTOM_FROM_OLD_MOD, nil,
  "a real Legacy New Game does not restore unknown title ids")
eq(freshAscendant.selectedTitle, "factory_architect",
  "ascendant state restores the selected title")
eq(freshHall.selectedTitle, "factory_architect",
  "the Legacy Gallery restores the same selected title")
eq(freshAscendant.latestAchievement, nil,
  "an unknown latest-achievement id is filtered during restoration")
eq(freshMasters.clears, 2,
  "Johto Masters clears seed the true New Game")
ok(freshMasters.title and freshMasters.goldenTrainerCardDecor,
  "Johto title and golden Trainer Card decor seed the true New Game")
eq(freshMasters.pendingGift.species, "SHINY_CELEBI",
  "a pending Johto gift is neither lost nor duplicated at hand-off")
eq(freshMasters.passages.kris.status, "entered",
  "Johto passage status survives the true New Game")
eq(freshMasters.passages.kris.step, 2,
  "the exact Johto arena checkpoint seeds the true New Game")
eq(freshMasters.passages.kris.resets, 4,
  "the Johto arena retry state seeds the true New Game")
ok(freshMasters.passages.silver.rewarded,
  "the exact-once Silver reward marker seeds the true New Game")
freshMasters.pendingGift = nil
freshMasters.gifts = 2
ok(archive.syncJohtoMastersPersistent(fresh),
  "a delivered Gold gift synchronizes independently")
eq(archive.load().johtoMastersPersistent.pendingGift, nil,
  "a delivered pending Gold gift cannot reappear from the archive")
freshMasters.cadenceVersion = 1
freshMasters.cadenceSerial = 10
freshMasters.connectedClears = 5
freshMasters.journeyClears = 2
freshMasters.activeRun = false
freshMasters.runSerial = 5
freshMasters.rewardedRunSerial = 5
freshMasters.cadenceOwner = "red:88:RUN:1"
freshMasters.lastHallTicket = 7
freshMasters.runTicket = nil
freshMasters.passages = {
  silver = { status = "cleared", rewarded = true, attempts = 3,
    clue = true, step = 3 },
  kris = { status = "cleared", rewarded = true, attempts = 2,
    clue = true, step = 3 },
  gold = { status = "cleared", rewarded = true, attempts = 1,
    clue = true, step = 3 },
}
ok(archive.syncJohtoMastersPersistent(fresh),
  "a completed connected Johto run enters the cadence archive")
freshMasters.cadenceSerial = 11
freshMasters.activeRun = true
freshMasters.runSerial = 6
freshMasters.runTicket = 8
freshMasters.passages.silver = { status = "unlocked", rewarded = false,
  attempts = 3, clue = false, step = 0 }
freshMasters.passages.kris = { status = "locked", rewarded = false,
  attempts = 2, clue = false, step = 0 }
freshMasters.passages.gold = { status = "locked", rewarded = false,
  attempts = 1, clue = false, step = 0 }
ok(archive.syncJohtoMastersPersistent(fresh),
  "a newer Johto cadence reset synchronizes independently")
local resetMasters = archive.load().johtoMastersPersistent
eq(resetMasters.cadenceSerial, 11,
  "the archive keeps the newest Johto cadence generation")
eq(resetMasters.passages.silver.status, "unlocked",
  "a new farm run resets Silver to its live unlocked state")
eq(resetMasters.passages.kris.status, "locked",
  "the archive does not resurrect a cleared Kris from the prior run")
eq(resetMasters.passages.gold.status, "locked",
  "the archive does not resurrect a cleared Gold from the prior run")
ok(not resetMasters.passages.gold.rewarded and resetMasters.runTicket == 8,
  "the exact current-run reward and Elite-Four ticket state survives")
ok(archive.setAvatar(fresh, "RED"), "selected character binds the red path")
eq(run.avatar, "RED", "active save mirrors the durable avatar")
ok(archive.advancePath(fresh, 5, true), "red path can complete durably")
ok(run.completedPaths.red, "red seal is permanent in the active profile")
ok(not archive.completeFinale(fresh), "finale is locked before all paths")

local profile = archive.profile()
ok(profile.completedPaths.red, "durable profile keeps a completed path")
ok(not profile.completedPaths.blue and not profile.completedPaths.green,
  "unplayed paths remain incomplete")

local migrationFixtures = {
  [1] = {
    version = 1, current = {}, fixtureTag = "v1",
    bank = { { id = "V1:MON", mon = { species = "EEVEE" } } },
  },
  [2] = {
    version = 2, current = {}, fixtureTag = "v2",
    completedPaths = { red = true }, pathSealCycles = { red = 7 },
  },
  [3] = {
    version = 3, current = {}, fixtureTag = "v3",
    hevoPersistent = {
      meta = { BLUE = true }, evolutionUnlocks = { MAGNEZONE = true },
      permanentItems = { THUNDER_STONE = 2 }, dex = { MAGNEZONE = true },
      questionIds = { HEVO_Q_BLUE_01 = true },
    },
  },
  [4] = {
    version = 4, fixtureTag = "v4",
    titles = {
      unlocked = { factory_architect = true },
      selectedTitle = "factory_architect",
    },
    current = {
      cycle = 4, partnerChosen = true, partnerSpecies = "MUDKIP",
      partnerMode = "hoenn", partnerBall = "left",
      partnerChosenAtCycle = 4, rivalBallTaken = true,
      rivalPartner = {
        version = 1, lineId = "hoenn_grass", base = "TREECKO",
        mid = "GROVYLE", final = "SCEPTILE", sourcePartner = "MUDKIP",
      },
    },
  },
  [5] = {
    version = 5, current = {}, fixtureTag = "v5",
    johtoMastersPersistent = {
      clears = 1, gifts = 1, title = true,
      pendingGift = { species = "CELEBI" },
      passages = { silver = { status = "cleared", attempts = 3 } },
    },
  },
}
for version = 1, 5 do
  local migrated = assert(archive.normalize(migrationFixtures[version]))
eq(migrated.version, 7,
    ("schema v%d migrates all the way to v7"):format(version))
  eq(migrated.fixtureTag, "v" .. version,
    ("schema v%d keeps unknown authored data"):format(version))
end
local migratedV1 = migrationFixtures[1]
ok(not migratedV1.completedPaths.red and not migratedV1.legacyPass,
  "version-one archives migrate with safe path defaults")
eq(migratedV1.bank[1].mon.species, "EEVEE",
  "version-one migration retains complete bank rows")
local migratedV2 = migrationFixtures[2]
ok(migratedV2.completedPaths.red and migratedV2.pathSealCycles.red == 7,
  "version-two migration retains path completion and its award cycle")
local migratedV3 = migrationFixtures[3]
ok(migratedV3.hevoPersistent.meta.BLUE
    and migratedV3.hevoPersistent.evolutionUnlocks.MAGNEZONE,
  "version-three migration retains permanent HEVO metadata")
local migratedV4 = migrationFixtures[4]
eq(migratedV4.titles.selectedTitle, "factory_architect",
  "version-four migration retains its valid selected title")
eq(migratedV4.current.partnerSpecies, "MUDKIP",
  "version-four migration retains the graphical Oak partner")
eq(migratedV4.current.rivalPartner.final, "SCEPTILE",
  "version-four migration retains the delayed rival line")
ok(migratedV4.current.rivalBallTaken,
  "version-four migration keeps parallel partner-catalogue fields")
local migratedV5 = migrationFixtures[5]
eq(migratedV5.johtoMastersPersistent.passages.silver.status, "cleared",
  "version-five Johto passage status survives schema migration")
eq(migratedV5.johtoMastersPersistent.pendingGift.species, "CELEBI",
  "version-five Johto pending gift survives schema migration")
local sanitizedTitles = archive.normalize({
  version = 4,
  current = {},
  titles = {
    unlocked = { rematch_10 = true, NOT_A_REAL_TITLE = true },
    selectedTitle = "NOT_A_REAL_TITLE",
  },
})
ok(sanitizedTitles.titles.unlocked.rematch_10,
  "known title ids survive archive schema migration")
eq(sanitizedTitles.titles.unlocked.NOT_A_REAL_TITLE, nil,
  "archive normalization removes unknown unlocked-title ids")
eq(sanitizedTitles.titles.selectedTitle, nil,
  "archive normalization removes an unknown selected title")
local lockedPathTitle = archive.normalize({
  version = 5,
  current = {},
  completedPaths = { red = true, blue = false, green = false },
  titles = { unlocked = {}, selectedTitle = "legacy_path_blue" },
})
eq(lockedPathTitle.titles.selectedTitle, nil,
  "a path title cannot exist before its matching permanent seal")

local bankBeforePartner, bankWhy = archive.bankAccess(fresh)
eq(bankBeforePartner, false, "even OPEN waits for Oak's new partner")
eq(bankWhy, "partner", "the pre-partner Bank lock is explicit")
run.partnerChosen = true
local bankAfterPartner = archive.bankAccess(fresh)
eq(bankAfterPartner, true, "OPEN activates immediately after the partner")
local available = archive.availableMons(fresh)
eq(#available, 3, "all archived Pokémon begin available")
local originalFirstId, originalSecondId = available[1].id, available[2].id
local movedId = available[3].id
ok(archive.reorderAvailableMon(fresh, movedId, 1),
  "virtual Legacy Box move persists through archive authority")
local movedRows = archive.availableMons(fresh)
eq(movedRows[1].id, movedId,
  "virtual Legacy Box move changes the visible slot order")
ok(archive.reorderAvailableMon(fresh, movedId, 9999),
  "a Pokémon can occupy a sparse slot in virtual Bank Box 500")
movedRows = archive.availableMons(fresh)
local sparseRow
for _, row in ipairs(movedRows) do
  if row.id == movedId then sparseRow = row break end
end
eq(sparseRow and sparseRow.bankSlot, 9999,
  "virtual Box 500 slot survives an archive readback")
eq(sparseRow and sparseRow.bankBoxCount, 500,
  "using Box 500 does not expand the initial capacity")
ok(archive.reorderAvailableMon(fresh, movedId, 3),
  "virtual Legacy Box order can be restored without changing identity")
ok(archive.reorderAvailableMon(fresh, originalFirstId, 1),
  "first original Bank slot can be restored after sparse movement")
ok(archive.reorderAvailableMon(fresh, originalSecondId, 2),
  "second original Bank slot can be restored after sparse movement")
available = archive.availableMons(fresh)
local leased = assert(archive.leaseMon(fresh, available[1].id))
eq(leased.species, "CHARMANDER", "withdrawal returns the full archived Pokémon")
fresh.party = { leased }
eq(#archive.availableMons(fresh), 2,
  "a live leased Pokémon cannot also appear in the bank")

local depositId = assert(archive.stageDeposit(fresh, leased))
fresh.party = {}
ok(archive.completeDeposit(fresh, depositId), "party deposit completes")
eq(#archive.availableMons(fresh), 3, "deposited Pokémon becomes available again")

archive.setWithdrawalGate(function(_, mon)
  if mon.species == "EEVEE" then
    return false, "JENSEITS VON KANTO: safely sealed"
  end
  return true
end)
local gatedRows = archive.availableMons(fresh)
eq(#gatedRows, 3,
  "withdrawal gate keeps every archived Pokémon visible in the Bank")
local gatedEevee, gatedPikachu
for _, row in ipairs(gatedRows) do
  if row.mon.species == "EEVEE" then gatedEevee = row end
  if row.mon.species == "PIKACHU" then gatedPikachu = row end
end
ok(gatedEevee and gatedEevee.withdrawBlocked
    and gatedEevee.withdrawReason:find("safely sealed", 1, true),
  "sealed extended Bank row carries its safe visible reason")
local blockedMon, blockedWhy = archive.leaseMon(fresh, gatedEevee.id)
eq(blockedMon, nil, "sealed Bank row cannot be leased by direct API")
ok(blockedWhy:find("JENSEITS VON KANTO", 1, true),
  "direct lease repeats the localized boundary reason")
local allowedMon = assert(archive.leaseMon(fresh, gatedPikachu.id))
eq(allowedMon.species, "PIKACHU",
  "same sealed Bank still releases an allowed Gen-I row")
fresh.party = { allowedMon }
local allowedDeposit = assert(archive.stageDeposit(fresh, allowedMon))
fresh.party = {}
ok(archive.completeDeposit(fresh, allowedDeposit),
  "allowed gated lease returns to the Bank without loss")
archive.setWithdrawalGate(nil)

local itemCheckout = assert(archive.beginItemCheckout(fresh, "POTION", 2))
fresh.inventory.POTION = 2
ok(archive.completeCheckout(fresh, itemCheckout.id),
  "saved item checkout completes")
eq(archive.locker().items.POTION, 1,
  "completed checkout removes exactly the received quantity")

local interruptedItem = assert(archive.beginItemCheckout(fresh, "ANTIDOTE", 1))
ok(archive.reconcileCheckout(fresh), "an unsaved checkout is reconciled")
eq(archive.locker().items.ANTIDOTE, 2,
  "unsaved checkout returns to the locker without loss")
ok(interruptedItem.id ~= itemCheckout.id, "checkout journal ids never collide")

-- A counted withdrawal can span Bag + Player PC, but remains one durable
-- checkout.  Simulate a crash after the game save contains both grants and
-- before archive finalization; a cold factory must consume the receipt once.
do
  local splitFs = memfs()
  local function splitFactory()
    return createArchive({
      fs = splitFs, serializer = Serializer, edition = "red",
      modId = "kanto_ascendant", directory = "test/split-checkout",
      now = function() return 654001 end,
    })
  end
  local splitArchive = splitFactory()
  assert(splitArchive.write({
    version = 7,
    current = { runId = "SPLIT-RUN", bankUnlocked = true },
    locker = { items = { POTION = 150 }, money = 0 },
  }))
  local splitSave = {
    inventory = { POTION = 2 }, pcItems = { POTION = 3 },
    modData = { kanto_ascendant = { legacy_journey = {
      runId = "SPLIT-RUN", bankUnlocked = true,
    } } },
  }
  local malformed, malformedErr = splitArchive.beginItemCheckout(
    splitSave, "POTION", 5, { bag = 3, pc = 1 })
  eq(malformed, nil, "mismatched Bag/PC grant plan is rejected")
  ok(tostring(malformedErr):find("grant plan", 1, true),
    "mismatched Bag/PC plan reports its exact validation boundary")
  eq(splitArchive.locker().items.POTION, 150,
    "rejected grant plan leaves every Locker receipt intact")

  local split = assert(splitArchive.beginItemCheckout(
    splitSave, "POTION", 120, { bag = 97, pc = 23 }))
  eq(split.count, 120, "journal binds the selected aggregate quantity")
  eq(split.beforeBag, 2, "journal binds the exact Bag before-count")
  eq(split.beforePc, 3, "journal binds the exact Player-PC before-count")
  eq(split.grant.bag, 97, "journal binds the exact Bag destination count")
  eq(split.grant.pc, 23, "journal binds the exact PC destination count")
  eq(splitArchive.locker().items.POTION, 150,
    "staging alone never consumes the Locker receipt")

  splitSave.inventory.POTION = 99
  splitSave.pcItems.POTION = 26
  local coldArchive = splitFactory()
  ok(coldArchive.reconcileCheckout(splitSave),
    "cold reload finalizes the interrupted split checkout")
  eq(coldArchive.locker().items.POTION, 30,
    "cold reload consumes the saved aggregate quantity exactly once")
  ok(coldArchive.reconcileCheckout(splitSave),
    "second reload sees no pending checkout")
  eq(coldArchive.locker().items.POTION, 30,
    "second reload cannot duplicate the interrupted finalization")

  local cancelled = assert(coldArchive.beginItemCheckout(
    splitSave, "POTION", 7, { bag = 0, pc = 7 }))
  assert(coldArchive.cancelCheckout(cancelled.id))
  eq(coldArchive.locker().items.POTION, 30,
    "cancelled split checkout is a non-consuming archive operation")
end

local moneyCheckout = assert(archive.beginMoneyCheckout(fresh, 1000))
fresh.money = 1000
ok(archive.completeCheckout(fresh, moneyCheckout.id),
  "saved money checkout completes")
eq(archive.locker().money, 3242,
  "money checkout debits the locker exactly once")

local valid = fs.files[archive.filename]
fs.files[archive.filename] = "not a save"
fs.files[archive.filename .. ".tmp"] = valid
local recoveryWrites = fs.writeCounts[archive.filename] or 0
local recovered = archive.load()
eq(recovered.cycle, 1, "tmp witness recovers an interrupted archive write")
eq(#recovered.bank, 3, "recovery preserves every bank Pokémon")
ok(recovered.completedPaths.red, "recovery preserves permanent path seals")
eq((fs.writeCounts[archive.filename] or 0) - recoveryWrites, 1,
  "witness recovery rewrites the primary archive exactly once")

local oldFs = memfs()
local oldArchive = createArchive({
  fs = oldFs, serializer = Serializer, edition = "red",
  directory = "test/old-schema",
})
oldFs.files[oldArchive.filename] = Serializer.encode({
  version = 1, cycle = 8, current = {}, migrationSentinel = "KEEP",
})
local oldWrites = oldFs.writeCounts[oldArchive.filename] or 0
local upgraded = oldArchive.load()
eq(upgraded.version, 7, "loading a v1 archive returns schema v7")
eq(upgraded.migrationSentinel, "KEEP",
  "loading a v1 archive preserves non-schema data")
eq((oldFs.writeCounts[oldArchive.filename] or 0) - oldWrites, 1,
  "loading an old primary persists its migration exactly once")
local upgradedOnDisk = assert(Serializer.decode(
  oldFs.files[oldArchive.filename]))
eq(upgradedOnDisk.version, 7,
  "the persisted migrated archive records schema v7")

local futureFs = memfs()
local futureArchive = createArchive({
  fs = futureFs, serializer = Serializer, edition = "red",
  directory = "test/future-schema",
})
local futureBytes = Serializer.encode({
  version = 8, futureSentinel = { partner = "DO_NOT_TOUCH" },
})
futureFs.files[futureArchive.filename] = futureBytes
futureFs.files[futureArchive.filename .. ".bak"] = Serializer.encode({
  version = 6, cycle = 99, current = {},
})
local future, futureErr = futureArchive.load()
eq(future.version, 8, "a future primary remains the authoritative archive")
eq(future.futureSentinel.partner, "DO_NOT_TOUCH",
  "future-only data is returned intact for diagnostics")
ok(futureArchive.readOnly and futureArchive.futureVersion == 8,
  "a future archive puts this build into fail-closed read-only mode")
ok(type(futureErr) == "string" and futureErr:find("future schema", 1, true),
  "future archive reads report an actionable compatibility error")
eq(futureFs.files[futureArchive.filename], futureBytes,
  "loading a future archive never rewrites it or falls back to backup data")
local futureWrite = futureArchive.write({ version = 7, current = {} })
eq(futureWrite, false, "writes are rejected while a future archive is loaded")
eq(futureFs.files[futureArchive.filename], futureBytes,
  "a rejected write leaves every future byte untouched")
local safeLocker = futureArchive.locker()
eq(type(safeLocker.items), "table",
  "read-only locker UI receives a safe view when future fields are absent")
eq(type(futureArchive.current()), "table",
  "read-only current-profile UI does not index a missing future field")
ok(futureArchive.profile().readOnly,
  "the public profile exposes its read-only compatibility state")
local futureSummary = futureArchive.summary(save)
eq(futureSummary.nextCycle, nil,
  "future archives never advertise a writable next cycle")
local untouchedFresh = { modData = nil }
eq(futureArchive.seedNewSave(untouchedFresh), false,
  "future archives cannot seed an older-format New Game")
eq(untouchedFresh.modData, nil,
  "failed future seeding never partially mutates the new save")

local mixedFs = memfs()
local mixedArchive = createArchive({
  fs = mixedFs, serializer = Serializer, edition = "red",
  directory = "test/future-recovery",
})
mixedFs.files[mixedArchive.filename] = "broken primary"
mixedFs.files[mixedArchive.filename .. ".tmp"] = Serializer.encode({
  version = 5, cycle = 5, current = {},
})
local futureBackupBytes = Serializer.encode({
  version = 8, futureBackupSentinel = "KEEP_NEWEST",
})
mixedFs.files[mixedArchive.filename .. ".bak"] = futureBackupBytes
local mixedLoaded = mixedArchive.load()
eq(mixedLoaded.version, 8,
  "a future backup blocks recovery through an older witness")
eq(mixedLoaded.futureBackupSentinel, "KEEP_NEWEST",
  "future recovery evidence is returned rather than discarded")
eq(mixedFs.files[mixedArchive.filename], "broken primary",
  "future-guarded recovery never overwrites the primary")
eq(mixedFs.files[mixedArchive.filename .. ".bak"], futureBackupBytes,
  "future-guarded recovery never rewrites its only newer backup")

local titleFs = memfs()
local titleArchive = createArchive({
  fs = titleFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/title-precedence",
})
ok(titleArchive.write({
  version = 5, cycle = 0, current = {},
  titles = {
    unlocked = { factory_architect = true },
    selectedTitle = "factory_architect",
  },
}), "title-precedence fixture is durable")
local staleLocalTitle = {
  version = "red", player = { id = 9090 },
  flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = { {} },
  party = {}, boxes = { {} }, inventory = {}, pcItems = {},
  modData = { kanto_ascendant = {
    ascendant = {
      achievements = {}, selectedTitle = "PHANTOM_FROM_OLD_MOD",
    },
    legacy_hall = {
      version = 1, selectedTitle = "LOCKED_OR_REMOVED_TITLE",
    },
  } },
}
local _, afterStaleTitle = assert(titleArchive.beginJourney(
  staleLocalTitle, legacyMeta()))
eq(afterStaleTitle.titles.selectedTitle, "factory_architect",
  "invalid local title ids cannot erase a valid durable selection")
eq(titleArchive.profile().titles.selectedTitle, "factory_architect",
  "the preserved archive title survives the committed hand-off")
local futureHallDuringSeed = {
  version = 12, selectedTitle = "future_title",
  futureOnly = { marker = "KEEP" },
}
local seedWithFutureHall = {
  flags = {}, modData = { kanto_ascendant = {
    legacy_hall = futureHallDuringSeed,
  } },
}
ok(titleArchive.seedNewSave(seedWithFutureHall),
  "pending Legacy metadata can seed beside future Gallery state")
eq(futureHallDuringSeed.version, 12,
  "archive seeding never downgrades a future Gallery schema")
eq(futureHallDuringSeed.futureOnly.marker, "KEEP",
  "archive seeding retains future-only Gallery fields")

local cycleFs = memfs()
local cycles = createArchive({
  fs = cycleFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/cycles",
  now = function() return 987654 end,
})
local function champion(id)
  return {
    version = "red", player = { id = id, name = "LEGACY" },
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = { {} },
    party = {}, boxes = { {} }, inventory = {}, pcItems = {},
    modData = {},
  }
end
local function nextRun(source, newId)
  assert(cycles.beginJourney(source, legacyMeta()))
  local freshCycle = champion(newId)
  freshCycle.flags, freshCycle.hallOfFame = {}, {}
  ok(cycles.seedNewSave(freshCycle), "next cycle receives the durable profile")
  ok(cycles.importHandoff(freshCycle), "next cycle verifies its hand-off")
  ok(cycles.markRunStarted(freshCycle), "next cycle hand-off becomes active")
  ok(cycles.finishHandoff(freshCycle), "next cycle retires its hand-off")
  return freshCycle
end

local firstChampion = champion(1001)
firstChampion.modData.kanto_ascendant = {
  ascendant = {
    achievements = { rematch_10 = true }, selectedTitle = "rematch_10",
  },
}
local cycleOne = nextRun(firstChampion, 2001)
eq(cycleOne.modData.kanto_ascendant.legacy_hall.selectedTitle, "rematch_10",
  "older saves restore ascendant.selectedTitle without a Gallery bucket")
ok(cycles.setAvatar(cycleOne, "RED"), "cycle one binds Red")
ok(cycles.advancePath(cycleOne, 5, true), "cycle one earns the Red seal")
cycleOne.modData.kanto_ascendant.ascendant = {
  achievements = {}, selectedTitle = "legacy_path_red",
}
cycleOne.modData.kanto_ascendant.legacy_hall = {
  version = 1, selectedTitle = "legacy_path_red",
}
local afterRed = cycles.profile()
eq(afterRed.pathSealCycles.red, 1, "Red seal records its award cycle")

local cycleTwo = nextRun(cycleOne, 2002)
eq(cycles.profile().current.cycle, 2, "second true New Game advances the cycle")
eq(cycleTwo.modData.kanto_ascendant.legacy_journey.avatarQuestStage, 0,
  "cycle two resets the active path stage")
ok(cycleTwo.modData.kanto_ascendant.legacy_journey.completedPaths.red,
  "cycle two keeps the Red seal")
eq(cycleTwo.modData.kanto_ascendant.legacy_hall.selectedTitle,
  "legacy_path_red",
  "the selected Kanto Challenger title follows its permanent Red seal")
eq(cycleTwo.modData.kanto_ascendant.ascendant.selectedTitle,
  "legacy_path_red",
  "the selected path title is mirrored into ascendant state")
ok(cycles.setAvatar(cycleTwo, "BLUE"), "cycle two binds Blue")
ok(cycles.advancePath(cycleTwo, 4, true), "cycle two earns the Blue seal")
eq(cycles.profile().pathSealCycles.blue, 2,
  "Blue seal records its own award cycle")

local cycleThree = nextRun(cycleTwo, 2003)
ok(cycles.setAvatar(cycleThree, "GREEN"), "cycle three binds Green")
ok(cycles.advancePath(cycleThree, 4, true), "cycle three earns the Green seal")
eq(cycles.profile().pathSealCycles.green, 3,
  "Green seal records its own award cycle")
ok(not cycles.hevoDoorQuestReady(cycleThree),
  "three seals alone do not bypass the current-run Champion requirement")
cycleThree.flags.EVENT_BEAT_CHAMPION_RIVAL = true
ok(cycles.hevoDoorQuestReady(cycleThree),
  "three seals plus the current Champion expose the future door-quest hook")
ok(cycles.consumeHevoDoorQuest(cycleThree),
  "the future door-quest readiness hook is consumed exactly once")
ok(not cycles.hevoDoorQuestReady(cycleThree),
  "a consumed door-quest hook cannot be claimed twice in the same run")
ok(cycles.completeFinale(cycleThree), "three seals unlock the Legacy Pass")

local cycleFour = nextRun(cycleThree, 2004)
local finalProfile = cycleFour.modData.kanto_ascendant.legacy_journey
ok(finalProfile.completedPaths.red and finalProfile.completedPaths.blue
    and finalProfile.completedPaths.green,
  "all three seals survive into the next starter selection")
ok(finalProfile.legacyPass, "the Legacy Pass survives another true New Game")
eq(finalProfile.avatarQuestStage, 0,
  "a fourth journey still starts with a clean path stage")

-- -------------------------------------------------- Oak partner round trip

local partnerFs = memfs()
local partners = createArchive({
  fs = partnerFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/partners",
  now = function() return 246810 end,
})
local partnerSource = champion(3001)
assert(partners.beginJourney(partnerSource, legacyMeta()))
local partnerFresh = {
  version = "red", player = { id = 3002, name = "RED", rival = "BLUE" },
  flags = {}, party = {}, boxes = { {} }, daycare = {},
  inventory = {}, pcItems = {}, modData = {},
}
ok(partners.seedNewSave(partnerFresh),
  "the partner test enters a true fresh Legacy save")
ok(partners.importHandoff(partnerFresh),
  "the partner test verifies its transient hand-off")
ok(partners.markRunStarted(partnerFresh),
  "the partner test owns the active archive run")
ok(partners.finishHandoff(partnerFresh),
  "the partner test retires its transient hand-off")
local partnerRun = partnerFresh.modData.kanto_ascendant.legacy_journey
partnerFresh.party = {
  { species = "TORCHIC", level = 5, ot = "RED", otId = 3002 },
}
partnerRun.partnerChosen = true
partnerRun.partnerSpecies = "TORCHIC"
partnerRun.partnerMode = "hoenn"
partnerRun.partnerBall = "left"
partnerRun.partnerChosenAtCycle = partnerRun.cycle
partnerRun.rivalPartner = {
  version = 1, base = "MUDKIP", mid = "MARSHTOMP",
  final = "SWAMPERT", lineId = "hoenn_water",
  sourcePartner = "TORCHIC",
}
ok(partners.syncPartner(partnerFresh),
  "a durable fresh-save choice mirrors into the Legacy archive")
local partnerCurrent = partners.current()
eq(partnerCurrent.partnerSpecies, "TORCHIC",
  "the archive stores Oak's exact chosen species")
eq(partnerCurrent.partnerMode, "hoenn",
  "the archive stores the selected partner mode")
eq(partnerCurrent.partnerBall, "left",
  "the archive stores the physical ball role")
eq(partnerCurrent.rivalPartner.final, "SWAMPERT",
  "the archive stores the delayed rival line atomically")
local unchangedArchive = partnerFs.files[partners.filename]
ok(partners.syncPartner(partnerFresh),
  "repeating the same partner sync is a successful no-op")
eq(partnerFs.files[partners.filename], unchangedArchive,
  "idempotent partner sync performs no archive rewrite")

local reloadedPartner = assert(Serializer.decode(
  Serializer.encode(partnerFresh)))
local staleRun = reloadedPartner.modData.kanto_ascendant.legacy_journey
staleRun.partnerChosen, staleRun.partnerSpecies = nil, nil
staleRun.partnerMode, staleRun.partnerBall = nil, nil
staleRun.partnerChosenAtCycle, staleRun.rivalPartner = nil, nil
ok(partners.syncProfile(reloadedPartner),
  "save load restores mirrored partner metadata from the archive")
eq(staleRun.partnerSpecies, "TORCHIC",
  "fresh-save round trip restores the chosen partner")
eq(staleRun.rivalPartner.lineId, "hoenn_water",
  "fresh-save round trip restores the exact rival counterpart")
eq(#reloadedPartner.party, 1,
  "save load neither duplicates nor loses the chosen party Pokémon")

partnerRun.partnerSpecies = "BULBASAUR"
local swapped, swapErr = partners.syncPartner(partnerFresh)
eq(swapped, false, "a second species cannot replace the run's partner")
ok(tostring(swapErr):find("already fixed", 1, true),
  "the archive explains why a second partner is rejected")
partnerRun.partnerSpecies = "TORCHIC"

partnerFresh.flags.EVENT_BEAT_CHAMPION_RIVAL = true
partnerFresh.hallOfFame = { partnerFresh.party }
local _, partnerStored = assert(partners.beginJourney(partnerFresh, legacyMeta({
  pact = "journey", starter = partnerRun.partnerSpecies,
  partnerMode = partnerRun.partnerMode,
  rivalPartner = partnerRun.rivalPartner, playerAvatar = "RED",
})))
local partnerHall = partnerStored.hallOfLegacy[#partnerStored.hallOfLegacy]
eq(partnerHall.starter, "TORCHIC",
  "Hall of Legacy records the completed run's chosen partner")
eq(partnerHall.partnerMode, "hoenn",
  "Hall of Legacy records how the partner was chosen")
eq(partnerHall.rivalPartner.final, "SWAMPERT",
  "Hall of Legacy retains the matching rival line")
local nextPartnerFresh = {
  version = "red", player = { id = 3003 }, flags = {}, party = {},
  boxes = { {} }, daycare = {}, inventory = {}, pcItems = {}, modData = {},
}
ok(partners.seedNewSave(nextPartnerFresh),
  "the next true New Game receives a new Legacy run")
local nextPartnerRun = nextPartnerFresh.modData.kanto_ascendant.legacy_journey
ok(not nextPartnerRun.partnerChosen,
  "the next cycle starts with one new Oak choice available")
eq(nextPartnerRun.partnerSpecies, nil,
  "the prior partner is historical, not silently duplicated into the next run")

print(("LEGACY ARCHIVE PASS: %d assertions"):format(assertions))
