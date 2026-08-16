-- QA-only real-input contract. The caller must point KA_BLITZ_QA_ROOT at an
-- isolated COPY of options.lua, active red/slot7 and the pre-0.1.86 archive.
-- This test never names or opens the user's live persistence root.

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
local qaRoot = assert(os.getenv("KA_BLITZ_QA_ROOT"),
  "KA_BLITZ_QA_ROOT must be an isolated copy")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local Serializer = require("src.core.SaveSerializer")
local Storage = require("src.mods.Storage")
local Tool = assert(loadfile(root .. "/tools/migrate_legacy_archive_0186.lua"))()
local ArchiveFactory = assert(loadfile(root .. "/legacy_archive.lua"))()
local fs = Tool.hostFs(qaRoot)

local sourcePath = "kanto_ascendant/legacy/red.lua"
local sourceBefore = assert(fs.read(sourcePath))
local optionsBefore = assert(fs.read("options.lua"))
local saveBefore = assert(fs.read("saves/red/slot7.lua"))
local opaqueId = string.rep("c", 32)
local deps = {
  fs = fs,
  serializer = Serializer,
  archiveFactory = ArchiveFactory,
  newPlaythroughId = function() return opaqueId end,
  now = function() return 1723665600 end,
}

local plan = assert(Tool.run({
  edition = "red", slot = "slot7", allocateId = true,
}, deps))
assert(plan.mode == "dry-run" and plan.scope == "slot7")
assert(plan.playthroughId == "(allocate on apply)")
assert(fs.read(sourcePath) == sourceBefore)
assert(fs.read("options.lua") == optionsBefore)
assert(fs.read("saves/red/slot7.lua") == saveBefore)
assert(not fs.getInfo(Tool.allocationWitnessRelative("red", "slot7")))

local report = assert(Tool.run({
  edition = "red", slot = "slot7", allocateId = true,
  apply = true, appStoppedConfirmed = true,
  backupStamp = "BLITZ_COPY",
}, deps))
assert(report.applied and report.playthroughId == opaqueId)

local stampedSaveBody = assert(fs.read("saves/red/slot7.lua"))
local stampedSave = assert(Serializer.decode(stampedSaveBody))
assert(stampedSave.meta and stampedSave.meta.playthroughId == opaqueId)
local binding = stampedSave.modData and stampedSave.modData.kanto_ascendant
  and stampedSave.modData.kanto_ascendant.legacy_storage_binding
assert(binding and binding.version == 1 and binding.scope == "playthrough"
    and binding.playthroughId == opaqueId
    and binding.archiveDigest == report.archiveDigest,
  "BLITZ copy did not receive its verified storage binding receipt")

-- Read through the exact stock-0.1.86 engine Storage implementation, not by
-- opening the target path directly. This is the same public value shape the
-- KA playthrough adapter receives from mod.storage:read.
local storage = Storage.new("kanto_ascendant", fs)
local wrapped, code, message = storage:read(
  { save = stampedSave }, Tool.storageKey("red"))
assert(type(wrapped) == "table", tostring(message or code))
assert(wrapped.version == 1 and type(wrapped.body) == "string")
local migrated = assert(Serializer.decode(wrapped.body))
local jm = assert(migrated.johtoMastersPersistent)
assert(jm.clears == 5 and jm.connectedClears == 1
  and jm.journeyClears == 1 and jm.title == true,
  "BLITZ Johto Masters history was not preserved")

assert(fs.read(sourcePath) == sourceBefore,
  "copied pre-0.1.86 source archive changed")
assert(fs.read("legacy_migration_backups/ka_0186_BLITZ_COPY/source_red.lua")
  == sourceBefore, "backup is not byte-identical to copied source")

print("PASS BLITZ copy: dry-run/apply, JM 5/1/title, stock Storage read, immutable source")
