local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local Serializer = require("src.core.SaveSerializer")
local Tool = assert(loadfile(root .. "/tools/migrate_legacy_archive_0186.lua"))()
local ArchiveFactory = assert(loadfile(root .. "/legacy_archive.lua"))()

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}; if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function memfs(seed)
  local files = copy(seed or {})
  local fs = { files = files, writes = 0 }
  function fs.getInfo(path)
    local body = files[path]
    return body ~= nil and { type = "file", size = #body } or nil
  end
  function fs.read(path)
    return files[path], files[path] == nil and "missing" or nil
  end
  function fs.write(path, body)
    fs.writes = fs.writes + 1
    if fs.failPath == path then
      if fs.partialBody then files[path] = fs.partialBody end
      fs.failPath = nil
      return false, "injected write failure"
    end
    files[path] = body
    return true
  end
  function fs.remove(path) files[path] = nil; return true end
  function fs.createDirectory() return true end
  return fs
end

local function archive(clears, bankSpecies)
  return {
    version = 6, cycle = 0,
    bank = bankSpecies and { { id = "old:1", mon = {
      species = bankSpecies, level = 81, moves = {},
    } } } or {},
    locker = { items = { NUGGET = 2 }, money = 654321 },
    quarantine = { bank = {}, items = {} }, hallOfLegacy = {},
    appliedTransactions = {},
    completedPaths = { red = false, blue = false, green = false },
    pathSealCycles = {}, legacyPass = false,
    titles = { unlocked = { johto_master = true }, selectedTitle = "johto_master" },
    hevoPersistent = {
      meta = { RED = true, BLUE = false, GREEN = false },
      packageUnlocks = {}, evolutionUnlocks = {}, permanentItems = {},
      firstGrants = {}, pendingItems = {}, dex = {},
      questionIds = { red_q = true }, secretUnlocks = {},
    },
    johtoMastersPersistent = {
      clears = clears or 2, gifts = 1, title = true,
      pendingGift = nil, goldenTrainerCardDecor = true,
      cadenceVersion = 1, cadenceSerial = 2,
      connectedClears = clears or 2, journeyClears = 0,
      activeRun = false, runSerial = 2, rewardedRunSerial = 2,
      passages = { red = { clears = clears or 2 } },
    },
    current = {},
  }
end

local function slotSeed(optsExtra, saveExtra, source)
  local opts = {
    saveSlots = { red = { list = { "slot1", "slot7" }, active = "slot7" } },
  }
  for key, value in pairs(optsExtra or {}) do opts[key] = copy(value) end
  local save = {
    version = "red", player = { id = 4444, name = "BLITZ" },
    meta = {}, modData = { kanto_ascendant = {
      johto_masters = { clears = 2, passages = { red = { clears = 2 } } },
    } },
  }
  for key, value in pairs(saveExtra or {}) do save[key] = copy(value) end
  return {
    ["options.lua"] = Serializer.encode(opts),
    ["saves/red/slot7.lua"] = Serializer.encode(save),
    ["saves/red/slot1.lua"] = Serializer.encode(copy(save)),
    ["kanto_ascendant/legacy/red.lua"] = Serializer.encode(source or archive()),
  }
end

local ID_A = string.rep("a", 32)
local ID_B = string.rep("b", 32)
local function deps(fs, id, checkpoint)
  return {
    fs = fs, serializer = Serializer, archiveFactory = ArchiveFactory,
    digest = function(body) return "D" .. tostring(#body) .. ":" .. body:sub(1, 12) end,
    newPlaythroughId = function() return id or ID_A end,
    now = function() return 1723665600 end,
    checkpoint = checkpoint,
  }
end

local function run(fs, options, id, checkpoint)
  options = options or {}
  options.edition = options.edition or "red"
  options.backupStamp = options.backupStamp or "TEST"
  return Tool.run(options, deps(fs, id, checkpoint))
end

local function decoded(fs, path)
  return assert(Serializer.decode(assert(fs.files[path], "missing " .. path)))
end

-- Dry-run is the default and allocates/writes nothing, even for the legitimate
-- BLITZ first-migration case with no pre-existing identity.
local fs = memfs(slotSeed())
local before = copy(fs.files)
local report = assert(run(fs, { slot = "slot7", allocateId = true }))
assert(report.mode == "dry-run" and report.playthroughId == "(allocate on apply)")
assert(fs.writes == 0)
for path, body in pairs(before) do assert(fs.files[path] == body, "dry-run changed " .. path) end
local optionsRecoveryFs = memfs(slotSeed())
optionsRecoveryFs.files["options.lua.bak"] = optionsRecoveryFs.files["options.lua"]
optionsRecoveryFs.files["options.lua"] = "return {\n"
report = assert(run(optionsRecoveryFs, { slot = "slot7", allocateId = true }))
assert(report.optionsReadPath == "options.lua.bak"
    and optionsRecoveryFs.files["options.lua"] == "return {\n",
  "dry-run did not read options main/tmp/bak without healing it")

-- Missing/ambiguous identity and the Trainer-ID-colliding slot1 are refused.
local refused, err = run(memfs(slotSeed()), { slot = "slot7" })
assert(refused == nil and tostring(err):find("--allocate-id", 1, true))
refused, err = run(memfs(slotSeed()), { allocateId = true })
assert(refused == nil and tostring(err):find("explicit --slot", 1, true))
refused, err = run(memfs(slotSeed()), { slot = "slot1", allocateId = true })
assert(refused == nil and tostring(err):find("active slot", 1, true))
local mismatchFs = memfs(slotSeed({
  playthroughIds = { red = { slot7 = ID_B } },
}, { meta = { playthroughId = ID_A } }))
refused, err = run(mismatchFs, { slot = "slot7" })
assert(refused == nil and tostring(err):find("disagree", 1, true))

-- Apply order: durable id witness, verified target, save stamp, options map.
fs = memfs(slotSeed())
local sourceBefore = fs.files["kanto_ascendant/legacy/red.lua"]
report = assert(run(fs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7", allocateId = true,
}, ID_A))
local target = Tool.targetRelative("red", ID_A)
local wrapper = decoded(fs, target)
local migrated = assert(Serializer.decode(wrapper.body))
assert(report.applied and report.playthroughId == ID_A)
assert(migrated.johtoMastersPersistent.clears == 2
    and migrated.bank[1] == nil and migrated.locker.money == 654321)
local migratedSave = decoded(fs, "saves/red/slot7.lua")
assert(migratedSave.meta.playthroughId == ID_A)
local migratedBinding = migratedSave.modData.kanto_ascendant.legacy_storage_binding
assert(migratedBinding and migratedBinding.version == 1
    and migratedBinding.scope == "playthrough"
    and migratedBinding.playthroughId == ID_A
    and migratedBinding.archiveDigest == report.archiveDigest,
  "migrator did not stamp the verified target storage receipt")
assert(decoded(fs, "options.lua").playthroughIds.red.slot7 == ID_A)
assert(fs.files["kanto_ascendant/legacy/red.lua"] == sourceBefore,
  "source archive changed")
assert(fs.files["legacy_migration_backups/ka_0186_TEST/source_red.lua"] == sourceBefore)

-- Idempotent retry keeps one semantic Bank and the same opaque identity.
report = assert(run(fs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7", allocateId = true,
  backupStamp = "RETRY",
}, ID_B))
assert(report.playthroughId == ID_A and report.alreadyMigrated)
assert(#assert(Serializer.decode(decoded(fs, target).body)).bank == 0)

-- A different existing target archive is never overwritten.
local conflictSeed = slotSeed({
  playthroughIds = { red = { slot7 = ID_A } },
}, { meta = { playthroughId = ID_A } })
local conflictFs = memfs(conflictSeed)
local otherBody = Serializer.encode(archive(99, "MEW"))
conflictFs.files[target] = Serializer.encode({ version = 1, body = otherBody })
refused, err = run(conflictFs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7",
})
assert(refused == nil and tostring(err):find("different Legacy archive", 1, true))
assert(conflictFs.files[target] == Serializer.encode({ version = 1, body = otherBody }))

-- Classify every generation before changing anything: an exact candidate may
-- heal corrupt siblings, but one valid conflicting sibling always vetoes.
local classifiedFs = memfs(slotSeed({
  playthroughIds = { red = { slot7 = ID_A } },
}, { meta = { playthroughId = ID_A } }))
local wantedBody = Serializer.encode(archive())
classifiedFs.files[target] = Serializer.encode({ version = 1, body = wantedBody })
classifiedFs.files[target .. ".tmp"] = "return {"
report = assert(run(classifiedFs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7",
  backupStamp = "CLASSIFY_HEAL",
}))
assert(report.alreadyMigrated and classifiedFs.files[target .. ".tmp"] == nil,
  "exact target did not heal its corrupt sibling")
local classifiedConflict = memfs(slotSeed({
  playthroughIds = { red = { slot7 = ID_A } },
}, { meta = { playthroughId = ID_A } }))
classifiedConflict.files[target] = Serializer.encode({ version = 1,
  body = wantedBody })
classifiedConflict.files[target .. ".bak"] = Serializer.encode({ version = 1,
  body = otherBody })
refused, err = run(classifiedConflict, {
  apply = true, appStoppedConfirmed = true, slot = "slot7",
})
assert(refused == nil and tostring(err):find("different Legacy archive", 1, true),
  "valid conflicting backup was ignored beside an exact main")
local invalidOnly = memfs(slotSeed({
  playthroughIds = { red = { slot7 = ID_A } },
}, { meta = { playthroughId = ID_A } }))
invalidOnly.files[target] = "return {"
refused, err = run(invalidOnly, {
  apply = true, appStoppedConfirmed = true, slot = "slot7",
})
assert(refused == nil and tostring(err):find("no valid recoverable", 1, true),
  "invalid-only pre-existing target was overwritten without a reservation witness")

-- Crash after verified storage but before save/options stamping: old
-- save/source remain retryable and the prior witness makes the target
-- discoverable with the exact same identity on retry.
local crashFs = memfs(slotSeed())
refused, err = run(crashFs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7", allocateId = true,
  backupStamp = "CRASH_TARGET",
}, ID_A, function(stage) return stage ~= "target_storage_verified" end)
assert(refused == nil and tostring(err):find("target_storage_verified", 1, true))
assert(decoded(crashFs, "saves/red/slot7.lua").meta.playthroughId == nil)
assert(decoded(crashFs, "options.lua").playthroughIds == nil)
assert(crashFs.files[Tool.targetRelative("red", ID_A)] ~= nil)
assert(decoded(crashFs,
  Tool.allocationWitnessRelative("red", "slot7")).playthroughId == ID_A)
assert(crashFs.files["kanto_ascendant/legacy/red.lua"]
  == slotSeed()["kanto_ascendant/legacy/red.lua"])

-- Crash immediately after allocation witness happens before ANY target
-- storage write, yet retry reuses the original id even if a later process
-- would generate another one. No second/orphan scope may appear.
local witnessFs = memfs(slotSeed())
refused = run(witnessFs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7", allocateId = true,
  backupStamp = "CRASH_WITNESS",
}, ID_A, function(stage) return stage ~= "allocation_witness" end)
assert(refused == nil)
assert(witnessFs.files[Tool.targetRelative("red", ID_A)] == nil)
assert(witnessFs.files[Tool.targetRelative("red", ID_B)] == nil)
assert(decoded(witnessFs,
  Tool.allocationWitnessRelative("red", "slot7")).playthroughId == ID_A)
report = assert(run(witnessFs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7", allocateId = true,
  backupStamp = "CRASH_WITNESS_RETRY",
}, ID_B))
assert(report.playthroughId == ID_A)
assert(decoded(witnessFs, "options.lua").playthroughIds.red.slot7 == ID_A)
assert(witnessFs.files[Tool.targetRelative("red", ID_A)] ~= nil)
assert(witnessFs.files[Tool.targetRelative("red", ID_B)] == nil)

-- Short-write crash windows recover through the already verified allocation
-- generation and always reuse the same id. This covers witness main, target
-- main and target tmp; none may create a second orphan scope or touch source.
for _, failure in ipairs({ "witness_main", "target_main", "target_tmp" }) do
  local partialFs = memfs(slotSeed())
  local partialTarget = Tool.targetRelative("red", ID_A)
  local witnessPath = Tool.allocationWitnessRelative("red", "slot7")
  local oldSource = partialFs.files["kanto_ascendant/legacy/red.lua"]
  partialFs.failPath = failure == "witness_main" and witnessPath
    or failure == "target_main" and partialTarget or (partialTarget .. ".tmp")
  partialFs.partialBody = "return {"
  refused, err = run(partialFs, {
    apply = true, appStoppedConfirmed = true, slot = "slot7",
    allocateId = true, backupStamp = "PARTIAL_" .. failure,
  }, ID_A)
  assert(refused == nil and err, failure .. " short write unexpectedly committed")
  assert(partialFs.files["kanto_ascendant/legacy/red.lua"] == oldSource,
    failure .. " short write changed the source archive")
  report = assert(run(partialFs, {
    apply = true, appStoppedConfirmed = true, slot = "slot7",
    allocateId = true, backupStamp = "PARTIAL_RETRY_" .. failure,
  }, ID_B))
  assert(report.playthroughId == ID_A,
    failure .. " retry allocated a different playthrough id")
  assert(partialFs.files[partialTarget] ~= nil
      and partialFs.files[Tool.targetRelative("red", ID_B)] == nil,
    failure .. " retry created an orphan second storage scope")
  assert(partialFs.files["kanto_ascendant/legacy/red.lua"] == oldSource,
    failure .. " retry changed the source archive")
end

-- Crash after save stamping recovers through the save's own id and completes
-- the options mapping without duplicating or changing archive data.
local saveCrashFs = memfs(slotSeed())
refused = run(saveCrashFs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7", allocateId = true,
  backupStamp = "CRASH_SAVE",
}, ID_A, function(stage) return stage ~= "save_stamp" end)
assert(refused == nil)
assert(decoded(saveCrashFs, "saves/red/slot7.lua").meta.playthroughId == ID_A)
assert(decoded(saveCrashFs, "options.lua").playthroughIds == nil)
report = assert(run(saveCrashFs, {
  apply = true, appStoppedConfirmed = true, slot = "slot7", allocateId = true,
  backupStamp = "CRASH_SAVE_RETRY",
}, ID_B))
assert(report.playthroughId == ID_A)

-- Physical target tmp/main/bak failures happen before save/options stamping;
-- every case keeps the old source byte-exact and is safely retryable.
for _, suffix in ipairs({ ".tmp", "", ".bak" }) do
  local writeFs = memfs(slotSeed())
  local writeTarget = Tool.targetRelative("red", ID_A)
  local oldSource = writeFs.files["kanto_ascendant/legacy/red.lua"]
  writeFs.failPath = writeTarget .. suffix
  if suffix == "" then writeFs.partialBody = "return {\n" end
  refused, err = run(writeFs, {
    apply = true, appStoppedConfirmed = true,
    slot = "slot7", allocateId = true,
    backupStamp = "WRITE_FAIL_" .. (suffix == "" and "MAIN" or suffix:sub(2)),
  }, ID_A)
  assert(refused == nil and err, "target " .. suffix .. " failure committed")
  assert(decoded(writeFs, "saves/red/slot7.lua").meta.playthroughId == nil)
  assert(decoded(writeFs, "options.lua").playthroughIds == nil)
  assert(writeFs.files["kanto_ascendant/legacy/red.lua"] == oldSource)
end

-- Flat/portable-style layout works when engine identity already exists.
local flatFs = memfs({
  ["options.lua"] = Serializer.encode({
    playthroughIds = { blue = { legacy = ID_B } },
  }),
  ["save_blue.lua"] = Serializer.encode({
    version = "blue", meta = { playthroughId = ID_B }, player = { name = "BLUE" },
  }),
  ["kanto_ascendant/legacy/blue.lua.bak"] = Serializer.encode(archive(3)),
})
report = assert(run(flatFs, {
  edition = "blue", apply = true, appStoppedConfirmed = true,
  backupStamp = "PORTABLE",
}))
assert(report.scope == "legacy" and report.sourceReadPath:sub(-4) == ".bak")
assert(flatFs.files[Tool.targetRelative("blue", ID_B)] ~= nil)

-- Edition mode has no slot/identity coupling and writes the engine contract's
-- raw v7 table directly under edition/red/.../legacy/archive.lua.
local editionFs = memfs({
  ["kanto_ascendant/legacy/red.lua"] = Serializer.encode(archive(4, "PIKACHU")),
})
report = assert(run(editionFs, {
  targetScope = "edition", apply = true, appStoppedConfirmed = true,
  backupStamp = "EDITION",
}))
assert(report.scope == "edition" and report.playthroughId == nil)
local rawEdition = decoded(editionFs, Tool.editionTargetRelative("red"))
assert(rawEdition.version == 7 and rawEdition.johtoMastersPersistent.clears == 4
    and rawEdition.bank[1].mon.species == "PIKACHU")

print("PASS Legacy 0.1.86 offline migrator: dry-run, slot7 allocation, backups, conflicts, retries, edition raw")
