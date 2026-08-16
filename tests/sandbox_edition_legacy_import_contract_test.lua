local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local engine = assert(os.getenv("GEN1RECOMP_EDITION_DIR"),
  "GEN1RECOMP_EDITION_DIR must point to the reviewed 0.1.86 engine tree")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

love = require("tests.love_stub")
local Serializer = require("src.core.SaveSerializer")
local SaveData = require("src.core.SaveData")
local Storage = require("src.mods.Storage")

local files = {}
local fs = {}
function fs.getInfo(path)
  return files[path] and { type = "file", size = #files[path] } or nil
end
function fs.read(path) return files[path], files[path] and nil or "missing" end
function fs.write(path, body) files[path] = body; return true end
function fs.remove(path) files[path] = nil; return true end
function fs.createDirectory() return true end
love.filesystem = fs
SaveData.resetSlotState()

local raw = {
  version = 6, cycle = 0,
  bank = { { id = "BLITZ:PIKA", mon = {
    species = "PIKACHU", level = 81, moves = {},
  } } },
  locker = { items = { NUGGET = 2 }, money = 654321 },
  quarantine = { bank = {}, items = {} }, hallOfLegacy = {},
  appliedTransactions = {},
  completedPaths = { red = false, blue = false, green = false },
  pathSealCycles = {}, legacyPass = false,
  titles = { unlocked = { johto_master = true }, selectedTitle = "johto_master" },
  hevoPersistent = { meta = { RED = true }, packageUnlocks = {},
    evolutionUnlocks = {}, permanentItems = {}, firstGrants = {},
    pendingItems = {}, dex = {}, questionIds = { red_q = true },
    secretUnlocks = {} },
  johtoMastersPersistent = { clears = 3, gifts = 1, title = true,
    goldenTrainerCardDecor = true, cadenceVersion = 1, cadenceSerial = 3,
    connectedClears = 3, journeyClears = 0, activeRun = false,
    runSerial = 3, rewardedRunSerial = 3,
    passages = { red = { clears = 3 } } },
  current = {},
}
local sourceBody = Serializer.encode(raw)
files["kanto_ascendant/legacy/red.lua"] = sourceBody

package.loaded["src.core.GameVersion"] = { get = function() return "red" end }
package.loaded["src.inventory.Bag"] = {
  isBadge = function(id) return tostring(id):find("BADGE", 1, true) ~= nil end,
}
package.loaded["src.core.Data"] = {
  pokemon = { PIKACHU = {} }, items = { NUGGET = {} }, moves = {},
}

local function makeRuntime()
  local core = Storage.new("kanto_ascendant", fs)
  local storage = {}
  function storage:edition(game)
    assert(game and game.save and game.save.version,
      "KA did not bind edition storage to the active game")
    return core:edition(game.save.version)
  end
  function storage:read(game, key) return core:read(game, key) end
  function storage:write(game, key, value) return core:write(game, key, value) end
  function storage:delete(game, key) return core:delete(game, key) end
  local hooks, events, errors = {}, {}, {}
  local mod = {
    id = "kanto_ascendant", storage = storage, ui = {},
    log = { info = function() end, error = function(_, msg)
      errors[#errors + 1] = tostring(msg)
    end },
    hooks = { wrap = function(_, name, callback) hooks[name] = callback end },
    events = { on = function(_, name, callback) events[name] = callback end },
  }
  local journey = assert(loadfile(root .. "/legacy_journey.lua"))()(mod, {
    makeArchive = assert(loadfile(root .. "/legacy_archive.lua"))(),
    i18n = { text = function(en) return en end },
  })
  return journey, events, errors
end

local game = { save = { version = "red", meta = {}, modData = {
  kanto_ascendant = { johto_masters = { clears = 3 } },
} } }
local journey, events, errors = makeRuntime()
events["game.ready"]({ game = game })
events["save.loaded"]({ game = game, save = game.save })

local imported = assert(journey.archive.load())
assert(imported.version == 7 and imported.johtoMastersPersistent.clears == 3
    and imported.bank[1].mon.species == "PIKACHU"
    and imported.locker.money == 654321,
  "KA adapter did not consume the engine-imported raw v7 archive: cycle="
    .. tostring(imported.cycle) .. " clears="
    .. tostring(imported.johtoMastersPersistent.clears) .. " bank="
    .. tostring(imported.bank[1] and imported.bank[1].mon.species)
    .. " money=" .. tostring(imported.locker.money)
    .. " errors=" .. table.concat(errors, " | ")
    .. " old=" .. tostring(files["kanto_ascendant/legacy/red.lua"] ~= nil)
    .. " target=" .. tostring(files["mod_storage_edition/red/kanto_ascendant/legacy/archive.lua"] ~= nil))
assert(files["kanto_ascendant/legacy/red.lua"] == sourceBody,
  "engine-owned importer changed its immutable old recovery witness")

local target = "mod_storage_edition/red/kanto_ascendant/legacy/archive.lua"
local stored = assert(Serializer.decode(assert(files[target])))
assert(stored.version == 7 and stored.body == nil
    and stored.johtoMastersPersistent.clears == 3,
  "edition destination is wrapped or not the raw archive table")

-- Product write remains raw and a complete mod/runtime restart reads it with
-- no old external witness and no playthrough id dependency.
imported.cycle = 1
imported.locker.money = 654322
assert(journey.archive.write(imported))
stored = assert(Serializer.decode(assert(files[target])))
assert(stored.version == 7 and stored.body == nil and stored.locker.money == 654322)

local restarted, restartEvents = makeRuntime()
restartEvents["game.ready"]({ game = game })
restartEvents["save.loaded"]({ game = game, save = game.save })
local cold = assert(restarted.archive.load())
assert(cold.cycle == 1 and cold.locker.money == 654322
    and cold.johtoMastersPersistent.clears == 3,
  "restart lost the engine-imported edition archive")

-- A real pre-0.1.86 edition save can have no opaque playthrough id at all.
-- Its complete durable save image, never the 16-bit trainer id by itself,
-- owns a pending first transaction across an app restart.
game.save.player = { id = 4242, name = "BLITZ" }
game.save.flags = { EVENT_BEAT_CHAMPION_RIVAL = true }
game.save.hallOfFame = { {} }
game.save.party, game.save.boxes = {}, { {} }
game.save.inventory, game.save.pcItems, game.save.money = {}, {}, 0
assert(game.save.meta.playthroughId == nil)
local pending = assert(restarted.archive.beginJourney(game.save, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
  runRules = restarted.archive.safeRunRulesSnapshot(game.save),
}))
assert(pending.status == "pending_new_game")
local durableNoIdSource = Serializer.decode(Serializer.encode(game.save))

local retryRuntime, retryEvents = makeRuntime()
game.save = durableNoIdSource
retryEvents["game.ready"]({ game = game })
retryEvents["save.loaded"]({ game = game, save = game.save })
local resumed = assert(retryRuntime.archive.beginJourney(game.save, {
  pact = "legacy", bankPolicy = "sealed", playerAvatar = "RED",
}))
assert(resumed.runId == pending.runId and resumed.cycle == pending.cycle,
  "no-id edition source could not resume its exact pending transaction")

-- A genuine new campaign on edition storage has no opaque playthrough id.
-- Its save.new_game receipt is still sufficient first-lineage authority. A
-- present id must remain well formed and match the save exactly; the edition
-- exemption never accepts a stale or foreign playthrough receipt.
files["kanto_ascendant/legacy/red.lua"] = nil
files["mod_storage_edition/blue/kanto_ascendant/legacy/archive.lua"] = nil
files["mod_storage_edition/blue/kanto_ascendant/legacy/archive.lua.bak"] = nil
local freshGame = { save = {
  version = "blue", meta = {}, player = { id = 77, name = "FRESH" },
  flags = {}, party = {}, boxes = { {} }, inventory = {}, pcItems = {},
  money = 0, modData = {},
} }
local freshRuntime, freshEvents = makeRuntime()
freshEvents["game.ready"]({ game = freshGame })
assert(freshRuntime.archive.markFreshOrigin(freshGame.save),
  "edition-scoped new save did not receive a fresh-origin receipt")
local origin = freshGame.save.modData.kanto_ascendant.legacy_fresh_origin
assert(origin and origin.version == 1 and origin.edition == "blue"
    and origin.playthroughId == nil,
  "edition-scoped origin unexpectedly invented a playthrough id")
local firstOk, firstReason = freshRuntime.archive.lineageStatus(freshGame.save)
assert(firstOk == true and firstReason == "verified_first_journey",
  "no-id edition fresh origin was rejected: " .. tostring(firstReason))

local function clone(value)
  return assert(Serializer.decode(assert(Serializer.encode(value))))
end
local foreignReceipt = clone(freshGame.save)
foreignReceipt.modData.kanto_ascendant.legacy_fresh_origin.playthroughId = "other"
firstOk, firstReason = freshRuntime.archive.lineageStatus(foreignReceipt)
assert(firstOk == false and tostring(firstReason):find("another playthrough", 1, true),
  "edition scope accepted a receipt id absent from its save")

local stampedFresh = clone(freshGame.save)
stampedFresh.meta.playthroughId = "blue_fresh_1"
firstOk, firstReason = freshRuntime.archive.lineageStatus(stampedFresh)
assert(firstOk == true and firstReason == "verified_first_journey"
    and stampedFresh.modData.kanto_ascendant.legacy_fresh_origin.playthroughId
      == "blue_fresh_1",
  "edition scope rejected a matching valid optional playthrough id")
local mismatchedReceipt = clone(stampedFresh)
mismatchedReceipt.modData.kanto_ascendant.legacy_fresh_origin.playthroughId
  = "blue_fresh_2"
firstOk, firstReason = freshRuntime.archive.lineageStatus(mismatchedReceipt)
assert(firstOk == false and tostring(firstReason):find("another playthrough", 1, true),
  "edition scope accepted a mismatched present playthrough id")

local malformedReceipt = clone(freshGame.save)
malformedReceipt.modData.kanto_ascendant.legacy_fresh_origin.playthroughId = "../bad"
firstOk, firstReason = freshRuntime.archive.lineageStatus(malformedReceipt)
assert(firstOk == false and tostring(firstReason):find("corrupt", 1, true),
  "edition scope accepted a malformed present playthrough id")

local wrongEdition = clone(freshGame.save)
wrongEdition.modData.kanto_ascendant.legacy_fresh_origin.edition = "red"
firstOk, firstReason = freshRuntime.archive.lineageStatus(wrongEdition)
assert(firstOk == false and tostring(firstReason):find("corrupt", 1, true),
  "edition scope accepted a fresh-origin receipt from another edition")

print("PASS edition storage contract: engine raw-v7 import, KA native adapter, restart")
