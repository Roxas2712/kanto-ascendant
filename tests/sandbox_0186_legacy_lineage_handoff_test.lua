-- Exact 0.1.86 Legacy lineage transaction: the archive may move only through
-- mod.storage and a data-only fresh-save capsule. No filesystem is exposed.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

package.loaded["src.core.GameVersion"] = { get = function() return "red" end }
package.loaded["src.inventory.Bag"] = {
  isBadge = function(id) return tostring(id):find("BADGE", 1, true) ~= nil end,
}
package.loaded["src.core.Data"] = {
  pokemon = { PIKACHU = {}, EEVEE = {}, BULBASAUR = {} },
  items = { POTION = {}, NUGGET = {} },
  moves = {},
}
local Serializer = require("src.core.SaveSerializer")

local scopes, nextId = {}, 0
local failNextStorageWrite = false
local failStorageReads = 0
local storage = {}
local function scope(game)
  local save = assert(game and game.save, "storage needs game.save")
  save.meta = save.meta or {}
  if not save.meta.playthroughId then
    nextId = nextId + 1
    save.meta.playthroughId = "playthrough_" .. tostring(nextId)
  end
  local id = save.meta.playthroughId
  scopes[id] = scopes[id] or {}
  return scopes[id], id
end
function storage:read(game, key)
  if failStorageReads > 0 then
    failStorageReads = failStorageReads - 1
    return nil, "read_failed", "injected source archive read failure"
  end
  local values = scope(game)
  local value = values[key]
  if value == nil then return nil, "not_found", "missing" end
  return copy(value)
end
function storage:write(game, key, value)
  local values = scope(game)
  if failNextStorageWrite then
    failNextStorageWrite = false
    return false, "write_failed", "injected target failure"
  end
  values[key] = copy(value)
  return true
end
function storage:delete(game, key)
  local values = scope(game)
  if values[key] == nil then return false, "not_found", "missing" end
  values[key] = nil
  return true
end
function storage:context(game)
  local _, id = scope(game)
  return { engineVersion = "0.1.86", gameVersion = game.save.version,
    playthroughId = id }
end

local hooks, events, errors = {}, {}, {}
local mod = {
  id = "kanto_ascendant",
  storage = storage,
  log = {
    info = function() end,
    error = function(_, message) errors[#errors + 1] = message end,
  },
  ui = {},
  hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
  events = { on = function(_, name, callback) events[name] = callback end },
}

local makeArchive = assert(loadfile(root .. "/legacy_archive.lua"))()
local makeJourney = assert(loadfile(root .. "/legacy_journey.lua"))()
local journey = makeJourney(mod, {
  makeArchive = makeArchive,
  i18n = { text = function(en) return en end },
})
assert(journey.archive.persistent == true,
  "official mod.storage adapter was not selected")
assert(type(hooks["save.new_game"]) == "function"
    and type(hooks["save.write"]) == "function",
  "Legacy handoff hooks are missing")

local source = {
  version = "red",
  meta = { playthroughId = "source" },
  player = { id = 42, name = "BLITZ" },
  flags = { EVENT_BEAT_CHAMPION_RIVAL = true, HEVO_META_RED = true },
  party = { { species = "PIKACHU", level = 81, moves = {} } },
  box = { { species = "EEVEE", level = 72, moves = {} } },
  inventory = { POTION = 7, NUGGET = 2 },
  pcItems = {}, money = 654321,
  hallOfFame = { { { species = "PIKACHU", level = 81 } } },
  modData = { kanto_ascendant = {
    extended_characters = { player_character = "RED" },
    hevo_persistent = {
      packageUnlocks = { red_trial = true }, evolutionUnlocks = {},
      permanentItems = {}, firstGrants = {}, pendingItems = {},
      dex = { PIKACHU = true }, questionIds = { red_q = true },
      secretUnlocks = {},
    },
    ascendant = { achievements = { rematch_10 = true },
      selectedTitle = "rematch_10" },
  } },
}
local durableSource = copy(source)
local game = { save = source }
events["game.ready"]({ game = game })
assert(journey.archive.markFreshOrigin(source),
  "legitimate first source did not receive a fresh-origin receipt")
events["save.loaded"]({ save = source })

local state, committed = journey.archive.beginJourney(source, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
  runRules = journey.archive.safeRunRulesSnapshot(source),
})
assert(state and committed and state.status == "pending_new_game",
  "source transaction did not commit")
local sourceArchive = assert(journey.archive.load())
assert(sourceArchive.cycle == 1 and #sourceArchive.bank == 2,
  "source Bank payload was not committed")
assert(sourceArchive.locker.items.POTION == 7
    and sourceArchive.locker.money == 654321,
  "source Locker payload was not committed")

-- Exact fail-closed UI transition: after the source transaction commits, an
-- official-storage read failure must prevent the fresh save from being
-- adopted or written. The old progress image and source scope stay retryable.
local failureHooks, failureEvents, failureErrors = {}, {}, {}
local failureMod = {
  id = mod.id, storage = storage, ui = {},
  log = {
    info = function() end,
    error = function(_, message)
      failureErrors[#failureErrors + 1] = tostring(message)
    end,
  },
  hooks = { wrap = function(_, name, callback) failureHooks[name] = callback end },
  events = { on = function(_, name, callback) failureEvents[name] = callback end },
}
local failureJourney = makeJourney(failureMod, {
  makeArchive = makeArchive,
  i18n = { text = function(en) return en end },
})
local adopted, progressWrites, emitted = 0, 0, 0
local failureStack = { values = { { old = true }, { pc = true } } }
function failureStack:top() return self.values[#self.values] end
function failureStack:pop() return table.remove(self.values) end
function failureStack:push(value) self.values[#self.values + 1] = value end
local failureGame = {
  save = source,
  stack = failureStack,
  bootConfig = function() return { version = "red" } end,
  adoptSave = function() adopted = adopted + 1 end,
  applyOptions = function() end,
  writeSave = function() progressWrites = progressWrites + 1; return true end,
}
failureEvents["game.ready"]({ game = failureGame })
failureEvents["save.loaded"]({ game = failureGame, save = source })
local oldSaveBody = Serializer.encode(source)
local oldScopeBody = Serializer.encode(scopes.source)
local oldNextId = nextId
local previousSaveData = package.loaded["src.core.SaveData"]
local previousRuntime = package.loaded["src.mods.Runtime"]
local previousOverworld = package.loaded["src.world.OverworldController"]
package.loaded["src.core.SaveData"] = {
  newGame = function()
    return failureHooks["save.new_game"](function(save) return save end, {
      version = "red", meta = {}, options = {}, flags = {},
      player = { id = 77, map = "REDS_HOUSE_2F", x = 3, y = 6 },
      inventory = {}, pcItems = {}, party = {}, box = {}, modData = {},
    })
  end,
}
package.loaded["src.mods.Runtime"] = {
  emit = function() emitted = emitted + 1 end,
}
package.loaded["src.world.OverworldController"] = { id = "OVERWORLD" }
failStorageReads = 3
local failedTransition, failedTransitionErr =
  failureJourney.startFreshGame(failureGame)
local unreadFaults = failStorageReads
failStorageReads = 0
package.loaded["src.core.SaveData"] = previousSaveData
package.loaded["src.mods.Runtime"] = previousRuntime
package.loaded["src.world.OverworldController"] = previousOverworld
assert(failedTransition == nil
    and tostring(failedTransitionErr):find("injected source archive read failure", 1, true),
  "official-storage read failure did not propagate out of Fresh Save staging: "
    .. tostring(failedTransition) .. " / " .. tostring(failedTransitionErr))
assert(unreadFaults == 0,
  "focused official-storage read fault was not consumed by Fresh Save staging")
assert(failureGame.save == source and adopted == 0 and progressWrites == 0
    and emitted == 0 and #failureStack.values == 2,
  "failed Fresh Save staging adopted, wrote or replaced the old UI/save state")
assert(Serializer.encode(source) == oldSaveBody
    and Serializer.encode(scopes.source) == oldScopeBody
    and nextId == oldNextId,
  "failed Fresh Save staging changed the source save/scope or allocated a target")

local function freshSave()
  return {
    version = "red", meta = {},
    player = { id = 77, name = "RED", map = "OAKS_LAB", x = 5, y = 5 },
    flags = {}, inventory = {}, pcItems = {}, party = {}, box = {},
    modData = {}, options = {},
  }
end

-- A capsule is transient, but a copied/tampered save could try to load one.
-- lineageStatus must validate it before save.loaded reconciliation can touch
-- target storage.
game.save = source
local invalidCapsuleFresh = hooks["save.new_game"](
  function(save) return save end, freshSave())
invalidCapsuleFresh.meta.playthroughId = "invalid_capsule"
invalidCapsuleFresh.modData.kanto_ascendant.legacy_lineage_handoff.cycle =
  invalidCapsuleFresh.modData.kanto_ascendant.legacy_lineage_handoff.cycle + 1
game.save = invalidCapsuleFresh
local capsuleOk, capsuleErr = journey.archive.lineageStatus(invalidCapsuleFresh)
assert(capsuleOk == false and tostring(capsuleErr):find("does not match", 1, true),
  "malformed persisted handoff bypassed lineage validation")

-- A target with the same run id/cycle is not sufficient authority. Poisoning
-- any durable payload family must reject the target and retain the capsule.
for index, poison in ipairs({
  function(value)
    value.bank[#value.bank + 1] = { id = "poison:bank", mon = {
      species = "BULBASAUR", level = 99, moves = {},
    } }
  end,
  function(value) value.johtoMastersPersistent.clears = 999 end,
  function(value) value.hevoPersistent.meta.BLUE = true end,
}) do
  game.save = source
  local poisonedFresh = hooks["save.new_game"](
    function(save) return save end, freshSave())
  poisonedFresh.meta.playthroughId = "poison_" .. tostring(index)
  local capsule = poisonedFresh.modData.kanto_ascendant.legacy_lineage_handoff
  local poisoned = copy(capsule.archive)
  poison(poisoned)
  game.save = poisonedFresh
  assert(journey.archive.write(poisoned), "could not seed poisoned target")
  capsuleOk, capsuleErr = journey.archive.lineageStatus(poisonedFresh)
  assert(capsuleOk == false
      and tostring(capsuleErr):find("different lineage", 1, true),
    "foreign handoff target reached save.loaded reconciliation")
  local vanillaCalls = 0
  assert(hooks["save.write"](function()
    vanillaCalls = vanillaCalls + 1
    return true
  end, game) == false and vanillaCalls == 0,
    "same-run poisoned target was accepted")
  assert(poisonedFresh.modData.kanto_ascendant.legacy_lineage_handoff,
    "rejected poisoned target lost its retry capsule")
end

-- A crash after the exact activation transform is a legitimate retry. The
-- imported archive may differ only by active status, borrowed startedAt,
-- transaction -> lastTransaction and a cleared transaction field.
game.save = source
local activeRetryFresh = hooks["save.new_game"](
  function(save) return save end, freshSave())
activeRetryFresh.meta.playthroughId = "active_retry"
local activeCapsule = activeRetryFresh.modData.kanto_ascendant.legacy_lineage_handoff
game.save = activeRetryFresh
assert(journey.archive.write(copy(activeCapsule.archive)))
assert(journey.archive.markRunStarted(activeRetryFresh))
assert(hooks["save.write"](function() return true end, game) == true,
  "exact already-active handoff retry was rejected")
assert(activeRetryFresh.modData.kanto_ascendant.legacy_lineage_handoff == nil,
  "active retry retained its verified capsule")
assert(activeRetryFresh.modData.kanto_ascendant.legacy_storage_binding
    .playthroughId == "active_retry",
  "active retry did not receive a scoped storage receipt")
game.save = source

-- Crash/failure before target import: save.write must veto, retain the capsule,
-- and leave the complete old source scope available for an idempotent retry.
local failedFresh = hooks["save.new_game"](function(save) return save end,
  freshSave())
assert(failedFresh.modData.kanto_ascendant.legacy_lineage_handoff,
  "fresh save did not receive the full handoff capsule")
game.save = failedFresh
failNextStorageWrite = true
assert(hooks["save.write"](function() return true end, game) == false,
  "failed target storage did not veto the progress save")
assert(failedFresh.modData.kanto_ascendant.legacy_lineage_handoff,
  "failed target import removed its recovery capsule")
game.save = source
local retryState = assert(journey.archive.beginJourney(source, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
}))
assert(retryState.runId == state.runId,
  "source retry created a duplicate transaction")
assert(#assert(journey.archive.load()).bank == 2,
  "failed target import damaged the source Bank")

-- A later failure in the engine's normal save writer happens after target
-- verification. The target copy may remain orphaned, but the durable old save
-- still resolves its untouched source scope and can retry the same run id.
local diskFailedFresh = hooks["save.new_game"](
  function(save) return save end, freshSave())
game.save = diskFailedFresh
assert(hooks["save.write"](function() return false end, game) == false,
  "injected progress-save failure was not propagated")
assert(diskFailedFresh.modData.kanto_ascendant.legacy_lineage_handoff == nil,
  "verified target kept its transient capsule after downstream save failure")
game.save = source
local postDiskFailureRetry = assert(journey.archive.beginJourney(source, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
}))
assert(postDiskFailureRetry.runId == state.runId
    and #assert(journey.archive.load()).bank == 2,
  "downstream save failure made the source transaction non-retryable")

-- Successful target: import/readback, active-marker/readback and capsule
-- removal all happen before the vanilla save writer is allowed to run.
local fresh = hooks["save.new_game"](function(save) return save end, freshSave())
game.save = fresh
local vanillaCalls = 0
assert(hooks["save.write"](function()
  vanillaCalls = vanillaCalls + 1
  return true
end, game) == true and vanillaCalls == 1,
  "verified handoff did not reach the vanilla save writer exactly once")
assert(type(fresh.meta.playthroughId) == "string"
    and fresh.meta.playthroughId ~= "source",
  "target did not receive a fresh opaque playthrough id")
assert(fresh.modData.kanto_ascendant.legacy_lineage_handoff == nil,
  "verified target retained the transient handoff capsule")
local targetBinding = fresh.modData.kanto_ascendant.legacy_storage_binding
assert(targetBinding and targetBinding.version == 1
    and targetBinding.scope == "playthrough"
    and targetBinding.playthroughId == fresh.meta.playthroughId
    and type(targetBinding.archiveDigest) == "string"
    and #targetBinding.archiveDigest == 16,
  "verified target did not persist its complete storage binding receipt")
local targetArchive = assert(journey.archive.load())
assert(targetArchive.current.status == "active"
    and targetArchive.current.runId == state.runId,
  "target archive was not activated")
assert(#targetArchive.bank == 2
    and targetArchive.locker.items.NUGGET == 2
    and targetArchive.hevoPersistent.meta.RED == true
    and targetArchive.hevoPersistent.questionIds.red_q == true
    and targetArchive.titles.unlocked.rematch_10 == true,
  "Bank/Locker/seal/question/title payload did not survive target import")

-- Simulated app restart after a completed transition: only the fresh save and
-- official target scope are available. The archive must be complete without
-- an in-memory closure or source-scope lookup.
local persistedFresh = copy(fresh)
local restartHooks, restartEvents = {}, {}
local restartMod = {
  id = mod.id, storage = storage, ui = {}, log = mod.log,
  hooks = { wrap = function(_, name, callback) restartHooks[name] = callback end },
  events = { on = function(_, name, callback) restartEvents[name] = callback end },
}
local restarted = makeJourney(restartMod, {
  makeArchive = makeArchive,
  i18n = { text = function(en) return en end },
})
local restartGame = { save = persistedFresh }
restartEvents["game.ready"]({ game = restartGame })
restartEvents["save.loaded"]({ save = persistedFresh })
local afterRestart = assert(restarted.archive.load())
assert(afterRestart.current.status == "active"
    and #afterRestart.bank == 2
    and afterRestart.locker.money == 654321,
  "app restart lost the sequential Legacy archive")

-- A receipt turns storage existence into a hard invariant. Missing/corrupt
-- generations and a malformed receipt are never reclassified as a fresh run.
local targetId = persistedFresh.meta.playthroughId
local durableTargetScope = copy(scopes[targetId])
local foreign = copy(afterRestart)
foreign.current.runId = "foreign_same_scope"
assert(restarted.archive.write(foreign))
local receiptOk, receiptErr = restarted.archive.lineageStatus(persistedFresh)
assert(receiptOk == false and tostring(receiptErr):find("different active run", 1, true),
  "receipt accepted a valid but foreign archive in the same scope")
local noBindingForeign = copy(persistedFresh)
noBindingForeign.modData.kanto_ascendant.legacy_storage_binding = nil
receiptOk, receiptErr = restarted.archive.lineageStatus(noBindingForeign)
assert(receiptOk == false
    and tostring(receiptErr):find("different active run", 1, true),
  "missing receipt let a local run join a foreign active archive")
scopes[targetId] = copy(durableTargetScope)
local noRunAuthority = copy(persistedFresh)
noRunAuthority.modData.kanto_ascendant.legacy_journey = nil
receiptOk, receiptErr = restarted.archive.lineageStatus(noRunAuthority)
assert(receiptOk == false and tostring(receiptErr):find("cannot prove", 1, true),
  "receipt without a save run id accepted a foreign active lineage")
scopes[targetId] = {}
receiptOk, receiptErr = restarted.archive.lineageStatus(persistedFresh)
assert(receiptOk == false and tostring(receiptErr):find("every archive", 1, true),
  "receipt with missing archive generations did not fail closed")
scopes[targetId] = copy(durableTargetScope)
for key in pairs(scopes[targetId]) do
  scopes[targetId][key] = { version = 1, body = "return {" }
end
receiptOk, receiptErr = restarted.archive.lineageStatus(persistedFresh)
assert(receiptOk == false and tostring(receiptErr):find("every archive", 1, true),
  "receipt with only corrupt archive generations did not fail closed")
local corruptNoBinding = copy(persistedFresh)
corruptNoBinding.modData.kanto_ascendant.legacy_storage_binding = nil
receiptOk, receiptErr = restarted.archive.lineageStatus(corruptNoBinding)
assert(receiptOk == false and tostring(receiptErr):find("every generation is corrupt", 1, true),
  "corrupt-only storage without a receipt was mistaken for an empty archive")
scopes[targetId] = durableTargetScope
local corruptReceipt = copy(persistedFresh)
corruptReceipt.modData.kanto_ascendant.legacy_storage_binding.archiveDigest = "bad"
receiptOk, receiptErr = restarted.archive.lineageStatus(corruptReceipt)
assert(receiptOk == false and tostring(receiptErr):find("receipt", 1, true),
  "corrupt storage binding receipt did not fail closed")

-- An opaque Storage id alone cannot distinguish a genuinely new save from an
-- old save that Storage stamped while looking for a missing archive. Only the
-- save.new_game origin receipt can authorize the first campaign.
local legitimateFirst = freshSave()
legitimateFirst.meta.playthroughId = "legitimate_first"
restartGame.save = legitimateFirst
receiptOk, receiptErr = restarted.archive.lineageStatus(legitimateFirst)
assert(receiptOk == false
    and tostring(receiptErr):find("no verified fresh origin", 1, true),
  "an opaque id alone was accepted as first-journey authority")
assert(restarted.archive.markFreshOrigin(legitimateFirst))
receiptOk = restarted.archive.lineageStatus(legitimateFirst)
assert(receiptOk == true,
  "explicit fresh-origin receipt did not authorize a legitimate first journey")

local stampedMasters = copy(durableSource)
stampedMasters.meta.playthroughId = "stamped_jm_history"
stampedMasters.modData.kanto_ascendant.legacy_journey = nil
stampedMasters.modData.kanto_ascendant.legacy_storage_binding = nil
stampedMasters.modData.kanto_ascendant.legacy_fresh_origin = nil
stampedMasters.modData.kanto_ascendant.johto_masters = {
  clears = 5, gifts = 1, title = true,
}
restartGame.save = stampedMasters
receiptOk, receiptErr = restarted.archive.lineageStatus(stampedMasters)
assert(receiptOk == false and tostring(receiptErr):find("Legacy history", 1, true),
  "stamped Johto Masters history without archive authority was called fresh")

-- Merely finding a syntactically valid empty v7 archive in an opaque stock
-- scope is not authority. An inspection/allocation side effect must not turn a
-- historical stamped save into a new lineage without a migration receipt.
local emptyStampedArchive = assert(restarted.archive.load())
assert(emptyStampedArchive.version == 7
    and emptyStampedArchive.cycle == 0
    and next(emptyStampedArchive.current) == nil,
  "focused empty-archive fixture is not an unstarted v7 archive")
assert(restarted.archive.write(emptyStampedArchive),
  "could not seed the focused empty v7 stock archive")
receiptOk, receiptErr = restarted.archive.lineageStatus(stampedMasters)
assert(receiptOk == false and tostring(receiptErr):find("Legacy history", 1, true)
    and tostring(receiptErr):find("binding", 1, true),
  "empty v7 stock archive authorized stamped historical progress")

-- The same durable empty archive is legal for a genuinely new stock save,
-- because save.new_game supplies the one-time fresh-origin authority.
local freshEmptyArchive = freshSave()
freshEmptyArchive.meta.playthroughId = "fresh_empty_archive"
restartGame.save = freshEmptyArchive
assert(restarted.archive.markFreshOrigin(freshEmptyArchive))
assert(restarted.archive.write(assert(restarted.archive.load())),
  "could not seed the fresh-origin empty v7 archive")
receiptOk, receiptErr = restarted.archive.lineageStatus(freshEmptyArchive)
assert(receiptOk == true and receiptErr == "verified_first_journey",
  "fresh-origin stock save lost authority when its empty archive existed")

-- A pre-0.1.86 active Legacy save without a migrated scoped archive is
-- detectable and must never silently start an empty lineage.
local unmigrated = copy(durableSource)
unmigrated.meta.playthroughId = "unmigrated"
unmigrated.modData.kanto_ascendant.legacy_journey = {
  version = 6, cycle = 2, runId = "old-external-run",
}
restartGame.save = unmigrated
local lineageOk, lineageErr = restarted.archive.lineageStatus(unmigrated)
assert(lineageOk == false and tostring(lineageErr):find("offline Legacy migration", 1, true),
  "missing pre-0.1.86 archive did not fail closed with migration guidance")
local denied = restarted.archive.beginJourney(unmigrated, {})
assert(denied == nil, "unmigrated active lineage silently created a fresh archive")

-- BLITZ-shaped first migration: old builds can have valuable Johto Masters
-- history with cycle 0 and no legacy_journey runId or playthrough identity.
-- Looking for storage must not allocate an empty scope and call this fresh.
local blitz = copy(durableSource)
blitz.meta = {}
blitz.modData.kanto_ascendant.legacy_journey = nil
blitz.modData.kanto_ascendant.johto_masters = {
  clears = 2, gifts = 1, passages = { red = { clears = 2 } },
}
restartGame.save = blitz
lineageOk, lineageErr = restarted.archive.lineageStatus(blitz)
assert(lineageOk == false
    and tostring(lineageErr):find("offline Legacy migration", 1, true),
  "cycle-0 Johto Masters witness was mistaken for a fresh archive")
assert(blitz.meta.playthroughId == nil,
  "migration guard allocated a playthrough scope before verification")
denied = restarted.archive.beginJourney(blitz, {})
assert(denied == nil and blitz.meta.playthroughId == nil,
  "BLITZ-shaped unmigrated history initialized an empty scoped archive")

print("PASS sandbox 0.1.86 Legacy lineage: transactional handoff, retry, restart, migration guard")
