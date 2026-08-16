-- Real stock-0.1.86 lifecycle contract: SaveData, Storage, Runtime buses and
-- Game's actual adoptSave/writeSave methods over an injected faultable FS.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

love = require("tests.love_stub")

local Serializer = require("src.core.SaveSerializer")
local SaveData = require("src.core.SaveData")
local GameVersion = require("src.core.GameVersion")
local Storage = require("src.mods.Storage")
local Runtime = require("src.mods.Runtime")
local Events = require("src.mods.Events")
local Hooks = require("src.mods.Hooks")
local Game = require("src.core.Game")

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}; if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function memfs()
  local files = {}
  local fs = { files = files }
  function fs.getInfo(path)
    local body = files[path]
    return body ~= nil and { type = "file", size = #body } or nil
  end
  function fs.read(path) return files[path], files[path] and nil or "missing" end
  function fs.write(path, body)
    local rule = fs.rule
    if rule and rule.path == path then
      fs.rule = nil
      if rule.mode == "false_partial" then
        files[path] = rule.body or "return {\n"
        return false, "injected partial write"
      elseif rule.mode == "false" then
        return false, "injected write failure"
      elseif rule.mode == "true_wrong" then
        files[path] = assert(rule.body)
        return true
      end
    end
    files[path] = body
    return true
  end
  function fs.remove(path) files[path] = nil; return true end
  function fs.createDirectory() return true end
  return fs
end

local makeArchive = assert(loadfile(root .. "/legacy_archive.lua"))()
local makeJourney = assert(loadfile(root .. "/legacy_journey.lua"))()

local DATA = {
  pokemon = { PIKACHU = {}, EEVEE = {}, BULBASAUR = {} },
  items = { POTION = {}, NUGGET = {} }, moves = {}, trainers = {},
  field = { boot = { version = "red", startMap = "REDS_HOUSE_2F" } },
}
package.loaded["src.core.Data"] = DATA

local function install(fs)
  love.filesystem = fs
  GameVersion.set("red")
  SaveData.resetSlotState()
  local events, hooks, errors = Events.new(), Hooks.new(), {}
  Runtime.install(events, hooks, errors)
  local core = Storage.new("kanto_ascendant", fs)
  local facade = {}
  function facade:read(game, key) return core:read(game, key) end
  function facade:write(game, key, value) return core:write(game, key, value) end
  function facade:delete(game, key) return core:delete(game, key) end
  function facade:context(game) return core:context(game) end
  local mod = {
    id = "kanto_ascendant", storage = facade, ui = {},
    log = { info = function() end, error = function(_, message)
      errors[#errors + 1] = tostring(message)
    end },
    hooks = { wrap = function(_, name, callback, priority)
      return hooks:wrap(name, callback, priority, "kanto_ascendant")
    end },
    events = { on = function(_, name, callback, priority)
      return events:on(name, callback, priority, "kanto_ascendant")
    end },
  }
  local journey = makeJourney(mod, {
    makeArchive = makeArchive,
    i18n = { text = function(en) return en end },
  })
  return journey, events, hooks, errors
end

local function prepareGame(save)
  Game.data = DATA
  Game.save = save
  Game.mods = { modSave = {} }
  Game.modStatus = { loaded = {} }
  Game.overworld = nil
  Game:adoptSave(save)
end

local fs = memfs()
local journey, events = install(fs)

-- This source begins without an id. The first real stock Storage read stamps
-- it and writes the legacy mapping before any New Game can replace that map.
local source = SaveData.newGame(DATA.field.boot)
source.player.id, source.player.name = 4242, "BLITZ"
source.party = { { species = "PIKACHU", level = 81, moves = {} } }
source.inventory = { POTION = 7, NUGGET = 2 }
source.money = 654321
prepareGame(source)
events:emit("game.ready", { game = Game })
events:emit("save.loaded", { game = Game, save = source })
assert(type(source.meta.playthroughId) == "string",
  "real Storage did not stamp the source before New Game")
local sourceId = source.meta.playthroughId
local options = assert(Serializer.decode(assert(fs.files["options.lua"])))
assert(options.playthroughIds.red.legacy == sourceId,
  "source engine mapping was not durable before New Game")
assert(Game:writeSave() == true and fs.files["save.lua"]
    and fs.files["save.lua.tmp"] == nil,
  "real source save did not complete main/tmp transaction")
local sourceOrigin = source.modData.kanto_ascendant.legacy_fresh_origin
assert(sourceOrigin and sourceOrigin.version == 1
    and sourceOrigin.playthroughId == sourceId,
  "real save.new_game/write lifecycle did not persist fresh-origin authority")

local state = assert(journey.archive.beginJourney(source, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
  runRules = journey.archive.safeRunRulesSnapshot(source),
}))
assert(state.status == "pending_new_game")

local function newTarget()
  local fresh = SaveData.newGame(Game:bootConfig())
  Game.save = fresh
  Game:adoptSave(fresh)
  Runtime.emit("save.created", { game = Game, save = fresh })
  return fresh
end

-- Crash window: target storage is imported/activated first, then the normal
-- progress tmp write fails. Old main save and its stamped source scope remain.
local failedFresh = newTarget()
fs.rule = { path = "save.lua.tmp", mode = "false" }
assert(Game:writeSave() == false, "progress tmp failure was not propagated")
assert(assert(Serializer.decode(fs.files["save.lua"])).meta.playthroughId == sourceId,
  "failed target progress write replaced the old source save")
local failedTargetId = failedFresh.meta.playthroughId
assert(type(failedTargetId) == "string" and failedTargetId ~= sourceId,
  "target Storage did not allocate a separate fresh scope")

-- Cold-reload the durable old source, independent of the options mapping now
-- pointing at the provisional target. Its own stamp selects the old archive.
local reloadedSource = assert(SaveData.load("red"))
assert(reloadedSource.meta.playthroughId == sourceId)
prepareGame(reloadedSource)
events:emit("save.loaded", { game = Game, save = reloadedSource })
local retried = assert(journey.archive.beginJourney(reloadedSource, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
}))
assert(retried.runId == state.runId,
  "crash retry duplicated the source transaction")

local fresh = newTarget()
assert(Game:writeSave() == true, "verified target progress save failed")
local firstTargetId = fresh.meta.playthroughId
assert(firstTargetId ~= sourceId and firstTargetId ~= failedTargetId)
local firstBinding = fresh.modData.kanto_ascendant.legacy_storage_binding
assert(firstBinding and firstBinding.scope == "playthrough"
    and firstBinding.playthroughId == firstTargetId,
  "first target did not bind its archive receipt to the fresh scope")
assert(fresh.modData.kanto_ascendant.legacy_fresh_origin == nil,
  "durable target binding retained the one-time fresh-origin receipt")
assert(fs.files["save.lua.tmp"] == nil and fs.files["save.lua.bak"],
  "successful progress transaction did not settle main/bak/tmp")
local active = assert(journey.archive.load())
assert(active.current.status == "active" and #active.bank == 1
    and active.bank[1].mon.species == "PIKACHU")

-- A second genuine New Game cycle carries the same first Bank row once and
-- adds only the new source mon; no capsule/import duplication. Deliberately
-- reuse the original 16-bit trainer id: that id is not lineage authority and
-- must not reopen the already-active first transaction.
fresh.party = { { species = "EEVEE", level = 72, moves = {} } }
fresh.player.id = source.player.id
prepareGame(fresh)
assert(Game:writeSave() == true,
  "second-cycle source was not durable before its transaction")
local state2 = assert(journey.archive.beginJourney(fresh, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "BLUE",
  runRules = journey.archive.safeRunRulesSnapshot(fresh),
}))
assert(state2.cycle == 2 and state2.runId ~= state.runId,
  "same trainer id reopened the old active transaction")

-- Power loss after the archive committed PENDING_NEW_GAME but before any
-- target exists: the durable predecessor save proves ownership through its
-- opaque scope + predecessor run proof and must resume exactly cycle two.
local reloadedCycleOne = assert(SaveData.load("red"))
assert(reloadedCycleOne.meta.playthroughId == firstTargetId)
prepareGame(reloadedCycleOne)
events:emit("save.loaded", { game = Game, save = reloadedCycleOne })
local resumedSecond = assert(journey.archive.beginJourney(reloadedCycleOne, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "BLUE",
}))
assert(resumedSecond.runId == state2.runId and resumedSecond.cycle == 2,
  "second-cycle source restart did not resume the committed transaction")

-- The next progress write reaches the exact stock save.lua.tmp short-write
-- window after its target archive was imported and activated. The old cycle-
-- one progress save stays retryable and must still select the source scope.
local failedSecondTarget = newTarget()
fs.rule = { path = "save.lua.tmp", mode = "false_partial" }
assert(Game:writeSave() == false,
  "second-cycle progress short-write was not vetoed")
local failedSecondId = failedSecondTarget.meta.playthroughId
assert(type(failedSecondId) == "string"
    and failedSecondId ~= firstTargetId,
  "second-cycle failed target did not get an isolated scope")
local retryCycleOne = assert(SaveData.load("red"))
assert(retryCycleOne.meta.playthroughId == firstTargetId,
  "second-cycle short-write replaced the durable predecessor save")
prepareGame(retryCycleOne)
events:emit("save.loaded", { game = Game, save = retryCycleOne })
local retriedSecond = assert(journey.archive.beginJourney(retryCycleOne, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "BLUE",
}))
assert(retriedSecond.runId == state2.runId and retriedSecond.cycle == 2,
  "second-cycle short-write retry forked a new lineage transaction")

local fresh2 = newTarget()
assert(Game:writeSave() == true)
local secondBinding = fresh2.modData.kanto_ascendant.legacy_storage_binding
assert(secondBinding and secondBinding.scope == "playthrough"
    and secondBinding.playthroughId == fresh2.meta.playthroughId
    and secondBinding.playthroughId ~= firstBinding.playthroughId
    and secondBinding.playthroughId ~= failedSecondId,
  "second target did not propagate a receipt for its own fresh scope")
local twice = assert(journey.archive.load())
local counts = {}
for _, row in ipairs(twice.bank) do
  counts[row.mon.species] = (counts[row.mon.species] or 0) + 1
end
assert(counts.PIKACHU == 1 and counts.EEVEE == 1 and #twice.bank == 2,
  "second real cycle lost or duplicated Bank rows")

-- Full cold mod/runtime restart: only the progress file + stock Storage files
-- remain. The same target scope reopens the two-row Bank.
local persisted = assert(SaveData.load("red"))
assert(persisted.modData.kanto_ascendant.legacy_storage_binding.playthroughId
    == fresh2.meta.playthroughId,
  "cold progress save lost the second-cycle storage receipt")
prepareGame(persisted)
local restarted, restartEvents = install(fs)
prepareGame(persisted)
restartEvents:emit("game.ready", { game = Game })
restartEvents:emit("save.loaded", { game = Game, save = persisted })
local cold = assert(restarted.archive.load())
assert(#cold.bank == 2 and cold.current.status == "active",
  "cold stock-Storage restart lost the sequential archive")

local function encodedLogical(path)
  return "legacy_lineage/files/" .. tostring(path):gsub("[^%w_-]", function(char)
    return "_" .. tostring(string.byte(char)) .. "_"
  end)
end

local function baseArchive()
  return {
    version = 6, cycle = 1,
    bank = { { id = "base:1", mon = {
      species = "PIKACHU", level = 81, moves = {},
    } } },
    locker = { items = {}, money = 0 }, quarantine = { bank = {}, items = {} },
    hallOfLegacy = {}, appliedTransactions = {},
    completedPaths = { red = false, blue = false, green = false },
    pathSealCycles = {}, legacyPass = false,
    titles = { unlocked = {}, selectedTitle = nil },
    hevoPersistent = { meta = {}, packageUnlocks = {}, evolutionUnlocks = {},
      permanentItems = {}, firstGrants = {}, pendingItems = {}, dex = {},
      questionIds = {}, secretUnlocks = {} },
    johtoMastersPersistent = { clears = 0, gifts = 0, passages = {} },
    current = { cycle = 1, runId = "base", status = "active" },
  }
end

local function storageFault(mode)
  local faultFs = memfs()
  local archiveJourney, faultEvents = install(faultFs)
  local save = SaveData.newGame(DATA.field.boot)
  save.meta.playthroughId = "faultscope"
  prepareGame(save)
  faultEvents:emit("game.ready", { game = Game })
  faultEvents:emit("save.loaded", { game = Game, save = save })
  assert(archiveJourney.archive.write(baseArchive()))

  local physical = "mod_storage/red/faultscope/kanto_ascendant/"
    .. encodedLogical(archiveJourney.archive.filename) .. ".lua"
  local changed = baseArchive()
  changed.cycle = 2
  changed.bank[#changed.bank + 1] = { id = "new:1", mon = {
    species = "EEVEE", level = 72, moves = {},
  } }

  if mode == "bak_false" then
    faultFs.rule = { path = physical .. ".bak", mode = "false" }
  elseif mode == "main_false_partial" then
    faultFs.rule = { path = physical, mode = "false_partial" }
  elseif mode == "main_true_wrong" then
    local wrong = Serializer.encode({ version = 1,
      body = Serializer.encode({ version = 6, cycle = 999 }) })
    faultFs.rule = { path = physical, mode = "true_wrong", body = wrong }
  elseif mode == "tmp_false" then
    faultFs.rule = { path = physical .. ".tmp", mode = "false" }
  end
  local writeOk = archiveJourney.archive.write(changed)
  assert(writeOk == false, mode .. " unexpectedly committed")

  -- Cold reader, no closure state. It may recover the new witness or retain the
  -- previous main, but the source Bank row must remain exactly once.
  local coldJourney, coldEvents = install(faultFs)
  prepareGame(save)
  coldEvents:emit("game.ready", { game = Game })
  coldEvents:emit("save.loaded", { game = Game, save = save })
  local recovered = assert(coldJourney.archive.load())
  local baseCount = 0
  for _, row in ipairs(recovered.bank) do
    if row.mon.species == "PIKACHU" then baseCount = baseCount + 1 end
  end
  assert(baseCount == 1, mode .. " lost or duplicated the source Bank")
end

for _, mode in ipairs({ "bak_false", "main_false_partial",
    "main_true_wrong", "tmp_false" }) do
  storageFault(mode)
end

print("PASS real stock 0.1.86 Storage lifecycle: IDs, New Game, veto, restart, two cycles, short writes")
