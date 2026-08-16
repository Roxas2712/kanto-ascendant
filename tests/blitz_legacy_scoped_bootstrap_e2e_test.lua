-- Exact private-fixture regression for BLITZ's stock-0.1.95 Legacy Journey
-- blocker. The release gate supplies read-only copies of slot8 and its
-- playthrough-scoped Storage wrapper; this test mutates only in-memory maps.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
local saveFixture = assert(os.getenv("BLITZ_SAVE_FIXTURE"),
  "BLITZ_SAVE_FIXTURE is required")
local storageFixture = assert(os.getenv("BLITZ_STORAGE_ARCHIVE_FIXTURE"),
  "BLITZ_STORAGE_ARCHIVE_FIXTURE is required")
local rawFixture = os.getenv("BLITZ_PRESANDBOX_ARCHIVE_FIXTURE")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
  .. package.path

local Serializer = require("src.core.SaveSerializer")
local makeArchive = assert(loadfile(root .. "/legacy_archive.lua"))()

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[copy(key, seen)] = copy(child, seen)
  end
  return out
end

local fixtureSave = assert(loadfile(saveFixture))()
local fixtureWrapper = assert(loadfile(storageFixture))()
ok(fixtureSave.player and fixtureSave.player.name == "BLITZ",
  "the exact source fixture belongs to BLITZ")
eq(fixtureSave.meta and fixtureSave.meta.engine, "0.1.95",
  "the exact source fixture retains its stock engine stamp")
local sourceId = assert(fixtureSave.meta and fixtureSave.meta.playthroughId)
eq(sourceId, "6a80b12c00639ad6178ac4d800000001",
  "the exact fixture retains the reported opaque playthrough identity")
ok(fixtureWrapper.version == 1 and type(fixtureWrapper.body) == "string",
  "the exact Storage fixture is the stock versioned data wrapper")

local archivePath = "kanto_ascendant/legacy/red.lua"
local function memfs(body)
  local files = { [archivePath] = body }
  local fs = { files = files, writes = 0 }
  function fs.getInfo(path)
    local value = files[path]
    return value ~= nil and { type = "file", size = #value } or nil
  end
  function fs.read(path)
    return files[path], files[path] and nil or "missing"
  end
  function fs.write(path, value)
    fs.writes = fs.writes + 1
    files[path] = value
    return true
  end
  function fs.remove(path) files[path] = nil; return true end
  function fs.createDirectory() return true end
  return fs
end

local function archiveFor(fs, requireData)
  return makeArchive({
    edition = "red", modId = "kanto_ascendant", fs = fs,
    editionScoped = false, enforceLegacyMigrationGuard = true,
    requireRegistryValidation = requireData == true,
  })
end

local function exactCase()
  local fs = memfs(fixtureWrapper.body)
  return archiveFor(fs), copy(fixtureSave), fs
end

local archive, blitz, fs = exactCase()
local lineageOk, lineageWhy = archive.lineageStatus(blitz)
ok(lineageOk == false
    and tostring(lineageWhy):find("no verified scoped archive binding", 1, true),
  "the exact old build failure is the missing receipt, not a future schema")
local beforeProfile = archive.profile()
eq(beforeProfile.futureVersion, nil,
  "the exact BLITZ archive is not from a newer mod")
eq(beforeProfile.cycle, 0,
  "the exact scoped file is an unstarted original-run bootstrap")
ok(beforeProfile.completedPaths.red == true,
  "the exact bootstrap contains BLITZ's locally proven RED seal")

local wrongContext = {
  gameVersion = "red", playthroughId = "different_playthrough",
}
local writesBeforeWrongContext = fs.writes
local adopted, adoptWhy = archive.adoptScopedBootstrap(blitz, wrongContext)
ok(adopted == false
    and tostring(adoptWhy):find("identity does not match", 1, true),
  "a different official Storage context remains fail-closed")
eq(fs.writes, writesBeforeWrongContext,
  "identity rejection performs no archive write")
ok(not (blitz.modData.kanto_ascendant.legacy_storage_binding),
  "identity rejection cannot stamp a save receipt")
local wrongVersionWrites = fs.writes
adopted, adoptWhy = archive.adoptScopedBootstrap(blitz, {
  gameVersion = "blue", playthroughId = sourceId,
})
ok(adopted == false
    and tostring(adoptWhy):find("identity does not match", 1, true),
  "a context for another game version remains fail-closed")
eq(fs.writes, wrongVersionWrites,
  "game-version rejection performs no archive write")

adopted, adoptWhy = archive.adoptScopedBootstrap(blitz, {
  gameVersion = "red", playthroughId = sourceId,
})
ok(adopted == true and adoptWhy == "adopted",
  "the exact self-derived scoped bootstrap is adopted")
local binding = blitz.modData.kanto_ascendant.legacy_storage_binding
ok(binding and binding.version == 1 and binding.scope == "playthrough"
    and binding.playthroughId == sourceId
    and type(binding.archiveDigest) == "string"
    and #binding.archiveDigest == 16,
  "adoption stamps a digest-bound receipt for the exact source scope")
lineageOk, lineageWhy = archive.lineageStatus(blitz)
ok(lineageOk == true and lineageWhy == "storage_binding",
  "the exact adopted save passes the production lineage guard")
local summary, summaryWhy = archive.summary(blitz)
ok(summary.readOnly == false and summary.nextCycle == 1
    and summaryWhy == "storage_binding",
  "the exact adopted save reaches Legacy cycle one instead of newer-mod UI")

local merged = archive.load()
local liveBucket = blitz.modData.kanto_ascendant
eq(merged.johtoMastersPersistent.clears,
  liveBucket.johto_masters.clears,
  "adoption preserves BLITZ's current Johto clear total")
eq(merged.johtoMastersPersistent.cadenceSerial,
  liveBucket.johto_masters.cadenceSerial,
  "adoption preserves BLITZ's current Johto cadence")
ok(merged.hevoPersistent.meta.RED == true
    and merged.completedPaths.red == true,
  "adoption preserves BLITZ's RED HEVO progress")
local mergedTitles = 0
for _ in pairs(merged.titles.unlocked) do mergedTitles = mergedTitles + 1 end
eq(mergedTitles, 16,
  "adoption preserves every authored BLITZ achievement title")
local adoptedBootstrapBody = fs.files[archivePath]

-- RED's exact legacy-identity absence is covered above. Generate the exact
-- same self-write shape for explicit BLUE/GREEN identities and require each
-- to bind only its own matching seal.
local function syntheticHero(character)
  local save = copy(fixtureSave)
  local bucket = save.modData.kanto_ascendant
  local id = "synthetic_" .. character:lower() .. "_scope"
  save.meta.playthroughId = id
  bucket.legacy_storage_binding = nil
  bucket.legacy_fresh_origin = nil
  bucket.legacy_lineage_handoff = nil
  bucket.legacy_journey = nil
  bucket.extended_characters = { player_character = character }
  bucket.hevo_run = { dungeonLegacy = {
    seals = { [character] = true }, reentered = { [character] = true },
  } }
  bucket.hevo_persistent = {
    version = 1, meta = { [character] = true }, packageUnlocks = {},
    evolutionUnlocks = {}, permanentItems = {}, firstGrants = {},
    pendingItems = {}, dex = {}, questionIds = {}, secretUnlocks = {},
  }
  save.flags.HEVO_META_RED = nil
  save.flags.HEVO_META_BLUE = nil
  save.flags.HEVO_META_GREEN = nil
  save.flags["HEVO_META_" .. character] = true

  local buildFs = memfs(nil)
  local builder = makeArchive({
    edition = "red", modId = "kanto_ascendant", fs = buildFs,
  })
  ok(builder.completeHevoPath(save, character),
    character .. " produces its deterministic original-run bootstrap")
  return save, assert(buildFs.files[archivePath]), id
end

local heroFixtures = {}
for _, character in ipairs({ "BLUE", "GREEN" }) do
  local heroSave, body, id = syntheticHero(character)
  heroFixtures[character] = { save = copy(heroSave), body = body, id = id }
  local heroFs = memfs(body)
  local heroArchive = archiveFor(heroFs)
  local heroAdopted = heroArchive.adoptScopedBootstrap(heroSave, {
    gameVersion = "red", playthroughId = id,
  })
  ok(heroAdopted == true,
    character .. " matching self-bootstrap is adopted")
  local heroBinding = heroSave.modData.kanto_ascendant.legacy_storage_binding
  ok(heroBinding and heroBinding.playthroughId == id,
    character .. " receipt binds its exact official scope")
  local heroLineage, heroWhy = heroArchive.lineageStatus(heroSave)
  ok(heroLineage == true and heroWhy == "storage_binding",
    character .. " reopens through its verified receipt")
  local heroProfile = heroArchive.profile()
  ok(heroProfile.completedPaths[character:lower()] == true,
    character .. " keeps its own completed path")
end

do
  local blueSave = copy(heroFixtures.BLUE.save)
  blueSave.meta.playthroughId = "cross_character_scope"
  local crossFs = memfs(heroFixtures.GREEN.body)
  local crossArchive = archiveFor(crossFs)
  local accepted = crossArchive.adoptScopedBootstrap(blueSave, {
    gameVersion = "red", playthroughId = "cross_character_scope",
  })
  ok(accepted == false,
    "BLUE cannot adopt a GREEN original-run bootstrap")
  eq(crossFs.writes, 0,
    "cross-character rejection performs no archive write")
  ok(not blueSave.modData.kanto_ascendant.legacy_storage_binding,
    "cross-character rejection cannot stamp a receipt")
end

-- The exact save has one real Day-Care Plus parent. Adoption fixes the
-- lineage blocker but must not silently delete a Pokémon to force New Game.
local blockers = archive.journeyBlockers(blitz)
eq(#blockers, 1,
  "the exact BLITZ source exposes its one remaining loss-prevention gate")
ok(blockers[1]:find("1 Day%-Care Plus parent"),
  "the remaining gate identifies the occupied Day-Care Plus")
local parents = liveBucket.daycare_plus and liveBucket.daycare_plus.parents
eq(parents and parents[1]
    and (parents[1].species or parents[1].mon and parents[1].mon.species),
  "DITTO",
  "the exact remaining BLITZ parent is DITTO")

-- Exercise the real archive transaction only after removing DITTO from the
-- in-memory copy, matching the user-visible instruction. Build registries
-- from the exact save so beginJourney uses its production validation path.
liveBucket.daycare_plus.parents = {}
local pokemon, items, moves, visited = {}, {}, {}, {}
local function collect(value)
  if type(value) ~= "table" or visited[value] then return end
  visited[value] = true
  if type(value.species) == "string" then
    pokemon[value.species] = pokemon[value.species] or {}
    for _, move in ipairs(value.moves or {}) do
      if type(move) == "string" then moves[move] = moves[move] or {} end
    end
  end
  for _, child in pairs(value) do collect(child) end
end
collect(blitz)
for id, count in pairs(blitz.inventory or {}) do
  if type(count) == "number" then items[id] = {} end
end
for id, count in pairs(blitz.pcItems or {}) do
  if type(count) == "number" then items[id] = {} end
end
ok(archive.bindData({ pokemon = pokemon, items = items, moves = moves }),
  "the exact transaction binds production-style registries")
local pending, pendingResult = archive.beginJourney(blitz, {
  pact = "journey", bankPolicy = "open", playerAvatar = "RED",
  runRules = archive.safeRunRulesSnapshot(blitz),
})
ok(pending and pending.status == "pending_new_game"
    and pending.cycle == 1 and type(pending.runId) == "string",
  "BLITZ reaches one committed pending New Game after DITTO is collected: "
    .. tostring(pending and "ok" or pendingResult))

-- Follow the same source -> fresh-save capsule -> new official Storage scope
-- sequence used by legacy_journey.save.new_game/save.write.
local fresh = {
  version = "red", meta = { playthroughId = "blitz_target_cycle_1" },
  player = { id = 0, name = "BLITZ" }, inventory = {}, pcItems = {},
  party = {}, boxes = {}, flags = {}, modData = {},
}
ok(archive.seedNewSave(fresh),
  "the exact committed source seeds one fresh-save handoff capsule")
local targetFs = memfs(nil)
local target = archiveFor(targetFs)
ok(target.importHandoff(fresh),
  "the fresh playthrough imports the complete BLITZ capsule")
ok(target.markRunStarted(fresh),
  "the fresh playthrough activates the pending Legacy run")
ok(target.stampStorageBinding(fresh, {
  gameVersion = "red", playthroughId = "blitz_target_cycle_1",
}), "the target receipt binds to its own new official scope")
ok(target.finishHandoff(fresh),
  "the transient handoff is removed only after target readback")
local targetOk, targetWhy = target.lineageStatus(fresh)
ok(targetOk == true and targetWhy == "storage_binding",
  "the cold target save reopens its own verified Legacy lineage")
local active = target.load()
ok(active.current.status == "active" and active.current.cycle == 1
    and active.current.runId == pending.runId,
  "the full exact BLITZ handoff ends in one active cycle-one archive")
ok(not fresh.modData.kanto_ascendant.legacy_lineage_handoff,
  "the active target retains no reusable transfer capsule")

local function rejectedArchive(mutator, message)
  local candidate = assert(Serializer.decode(fixtureWrapper.body))
  mutator(candidate)
  local badFs = memfs(Serializer.encode(candidate))
  local bad = archiveFor(badFs)
  local save = copy(fixtureSave)
  local before = Serializer.encode(save)
  local accepted = bad.adoptScopedBootstrap(save, {
    gameVersion = "red", playthroughId = sourceId,
  })
  ok(accepted == false, message)
  eq(Serializer.encode(save), before,
    message .. " leaves the source save byte-semantically unchanged")
  eq(badFs.writes, 0, message .. " performs no archive write")
end

rejectedArchive(function(value)
  value.bank = { { id = "foreign:1", mon = {
    species = "PIKACHU", level = 100, moves = {},
  } } }
end, "a foreign Bank row is never adopted")
rejectedArchive(function(value)
  value.current = { runId = "foreign-run", cycle = 1, status = "active" }
  value.cycle = 1
end, "an active foreign run is never adopted")
rejectedArchive(function(value)
  value.completedPaths.green = true
  value.pathSealCycles.green = 0
end, "a seal absent from the same BLITZ save is never adopted")
rejectedArchive(function(value)
  value.johtoMastersPersistent.clears = 1
end, "an intermediate/tampered Johto counter is never adopted")
rejectedArchive(function(value)
  value.unrecognizedAuthority = { enabled = true }
end, "an unknown archive authority field is never adopted")
rejectedArchive(function(value)
  value.version = 8
end, "a genuine future-schema archive remains read-only")

do
  local emptyFs = memfs(Serializer.encode({ version = 6 }))
  local emptyArchive = archiveFor(emptyFs)
  local historical = copy(fixtureSave)
  local accepted = emptyArchive.adoptScopedBootstrap(historical, {
    gameVersion = "red", playthroughId = sourceId,
  })
  ok(accepted == false,
    "an empty probe-created scope is not lineage authority")
  eq(emptyFs.writes, 0,
    "an empty probe-created scope remains untouched")
  ok(not historical.modData.kanto_ascendant.legacy_storage_binding,
    "an empty probe-created scope cannot stamp a receipt")
end

if rawFixture and rawFixture ~= "" then
  local rawBody = assert(io.open(rawFixture, "rb")):read("*a")
  local rawFs = memfs(rawBody)
  local rawArchive = archiveFor(rawFs)
  local rawSave = copy(fixtureSave)
  local accepted = rawArchive.adoptScopedBootstrap(rawSave, {
    gameVersion = "red", playthroughId = sourceId,
  })
  ok(accepted == false,
    "the different valid pre-sandbox archive is not auto-claimed")
  eq(rawFs.writes, 0,
    "the different valid pre-sandbox archive remains untouched")
end

-- A crash after the verified archive merge but before the save receipt lands
-- is retryable: the fully merged deterministic bootstrap is one of the exact
-- accepted snapshots, while arbitrary intermediate values above are not.
local retrySave = copy(fixtureSave)
local retryFs = memfs(adoptedBootstrapBody)
local retryArchive = archiveFor(retryFs)
ok(retryArchive.adoptScopedBootstrap(retrySave, {
  gameVersion = "red", playthroughId = sourceId,
}), "a verified interrupted adoption retries idempotently")
local retryOk = retryArchive.lineageStatus(retrySave)
ok(retryOk == true,
  "the idempotent retry also produces a valid digest-bound receipt")

print(("PASS BLITZ scoped-bootstrap full E2E: %d assertions")
  :format(assertions))
