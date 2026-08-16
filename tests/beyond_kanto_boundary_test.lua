local checks = 0
local function ok(value, label)
  checks = checks + 1
  assert(value, "FAIL: " .. label)
end
local function eq(actual, expected, label)
  ok(actual == expected, label .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local hooks, events = {}, {}
local mod = {
  id = "kanto_ascendant",
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn)
    events[name] = events[name] or {}
    events[name][#events[name] + 1] = fn
  end },
  log = { error = function() end },
}
local german = false
local i18n = { text = function(en, de) return german and de or en end }
local makeBoundary = assert(loadfile("johto_unleashed.lua"))()
local boundary = makeBoundary(mod, { i18n = i18n, johtoData = {
  species = {
    CROBAT = { dex = 169 }, ESPEON = { dex = 196 },
    HOUNDOUR = { dex = 228 }, TREECKO = { dex = 252 },
  },
} })

local function data()
  return {
    pokemon = {
      MAGNEMITE = { dex = 81, types = { "ELECTRIC" } },
      MAGNETON = { dex = 82, types = { "ELECTRIC" } },
      GOLBAT = { dex = 42, types = { "POISON", "FLYING" } },
      CROBAT = { dex = 169, types = { "POISON", "FLYING" } },
      EEVEE = { dex = 133, types = { "NORMAL" } },
      ESPEON = { dex = 196, types = { "PSYCHIC_TYPE" } },
      HOUNDOUR = { dex = 228, types = { "DARK", "FIRE" } },
      TREECKO = { dex = 252, types = { "GRASS" } },
    },
    moves = {
      BITE = { type = "NORMAL", category = "physical" },
      GUST = { type = "NORMAL", category = "physical" },
      SAND_ATTACK = { type = "NORMAL", category = "status" },
      KARATE_CHOP = { type = "NORMAL", category = "physical" },
    },
  }
end

local function save(owner)
  return {
    version = "red", player = { id = 7 }, party = {}, boxes = {},
    pokedex = { seen = {}, owned = {} }, flags = {},
    modData = { kanto_ascendant = owner or {} },
  }
end

local shared = data()
local slotA, slotB = save(), save()
local game = { data = shared, save = slotA, writeSave = function() return true end }
local active, migrated = boundary.sync(game, slotA, "test-off")
ok(not active and not migrated, "fresh unmarked slot starts sealed")
eq(shared.pokemon.MAGNEMITE.types[2], nil,
  "sealed Magnemite retains exact Gen-I typing")
eq(shared.moves.BITE.type, "NORMAL", "sealed Bite retains Gen-I type")
eq(shared.moves.GUST.type, "NORMAL", "sealed Gust retains Gen-I type")
eq(shared.moves.SAND_ATTACK.type, "NORMAL",
  "sealed Sand-Attack retains Gen-I type")
eq(shared.moves.KARATE_CHOP.type, "NORMAL",
  "sealed Karate Chop retains Gen-I type")

ok(type(hooks["evolution.check"]) == "function",
  "boundary owns the real evolution.check dispatch")
local allow = function() return true end
ok(not hooks["evolution.check"](allow, game, { species = "GOLBAT" },
    { method = "FRIENDSHIP", species = "CROBAT" }, { kind = "levelup" }),
  "sealed high-friendship Golbat cannot evolve into Crobat")
ok(hooks["evolution.check"](allow, game, { species = "EEVEE" },
    { method = "ITEM", species = "VAPOREON" },
    { kind = "item", item = "WATER_STONE" }),
  "sealed boundary does not block a Kanto evolution")
ok(boundary.canWithdrawMon(slotA, { species = "GOLBAT" }),
  "sealed Legacy Bank still releases Gen-I species")
local bankAllowed, bankReason = boundary.canWithdrawMon(slotA,
  { species = "HOUNDOUR" })
ok(not bankAllowed and bankReason:find("remains safe", 1, true),
  "sealed Legacy Bank keeps extended rows safe and blocked")

local changed, reason = boundary.activate(game)
ok(changed and reason == "activated", "explicit activation succeeds")
ok(boundary.isActive(slotA), "activation is save-local and active")
eq(shared.pokemon.MAGNEMITE.types[2], "STEEL",
  "activation applies Magnemite Steel overlay")
eq(shared.pokemon.MAGNETON.types[2], "STEEL",
  "activation applies Magneton Steel overlay")
eq(shared.moves.BITE.type, "DARK", "activation applies Bite Dark overlay")
eq(shared.moves.GUST.type, "FLYING", "activation applies Gust Flying overlay")
eq(shared.moves.SAND_ATTACK.type, "GROUND",
  "activation applies Sand-Attack Ground overlay")
eq(shared.moves.KARATE_CHOP.type, "FIGHTING",
  "activation applies Karate Chop Fighting overlay")
ok(hooks["evolution.check"](allow, game, { species = "GOLBAT" },
    { method = "FRIENDSHIP", species = "CROBAT" }, { kind = "levelup" }),
  "activated high-friendship Golbat may evolve into Crobat")
ok(boundary.canWithdrawMon(slotA, { species = "HOUNDOUR" }),
  "activated Legacy Bank releases extended species")

local stateA = slotA.modData.kanto_ascendant.beyond_kanto
stateA.active = false
boundary.sync(game, slotA, "tamper-proof")
ok(boundary.isActive(slotA),
  "irreversible receipt prevents a boolean-only downgrade")
local sealed, sealedWhy = boundary.sealFresh(slotA)
ok(not sealed and sealedWhy == "irreversible",
  "ordinary API cannot reseal an activated save")

game.save = slotB
boundary.sync(game, slotB, "slot-b")
ok(not boundary.isActive(slotB), "second slot stays independently sealed")
eq(shared.pokemon.MAGNEMITE.types[2], nil,
  "loading sealed slot restores global species baseline")
eq(shared.moves.BITE.type, "NORMAL",
  "loading sealed slot restores global move baseline")
game.save = slotA
boundary.sync(game, slotA, "slot-a-return")
eq(shared.pokemon.MAGNEMITE.types[2], "STEEL",
  "returning to active slot reapplies its overlay")

local copiedActive = save({ beyond_kanto = {
  version = 1, active = true, irreversible = true,
} })
local fresh = hooks["save.new_game"](function(value) return value end,
  copiedActive)
ok(not boundary.isActive(fresh),
  "actual New Game/NG+ forcibly starts sealed despite copied state")
eq(fresh.modData.kanto_ascendant.beyond_kanto.decision, "fresh_gen1",
  "New Game records explicit fresh Gen-I authority")

local migratedMon = save()
migratedMon.party = { { species = "HOUNDOUR", level = 20 } }
game.save = migratedMon
local monActive, monMigrated, monWitness = boundary.sync(game, migratedMon)
ok(monActive and monMigrated and monWitness == "party:HOUNDOUR",
  "old save with an actual extended party mon migrates active")

local oldMasters = save({ johto_masters = { clears = 1 } })
game.save = oldMasters
local masterActive = boundary.sync(game, oldMasters)
ok(masterActive, "pre-cadence Masters history on its own old save migrates active")

local inheritedMasters = save({
  legacy_journey = { runId = "RUN:2", cycle = 2 },
  johto_masters = { clears = 8, gifts = 2, title = true },
  hevo_persistent = { packageUnlocks = { red_legacy = true } },
})
game.save = inheritedMasters
local inheritedActive, inheritedMigrated, inheritedWitness =
  boundary.sync(game, inheritedMasters)
ok(not inheritedActive and not inheritedMigrated and inheritedWitness == nil,
  "archived pre-cadence Masters/HEVO history cannot open a fresh Legacy run")

local currentHevo = save({
  legacy_journey = { runId = "RUN:3", cycle = 3 },
  hevo_run = { dungeonLegacy = {
    seals = { GREEN = true }, reentered = { GREEN = true },
  } },
  hevo_persistent = { packageUnlocks = { green_legacy = true } },
})
game.save = currentHevo
local hevoActive, hevoMigrated, hevoWitness = boundary.sync(game, currentHevo)
ok(hevoActive and hevoMigrated and hevoWitness == "hevo_seal",
  "current-run HEVO completion still migrates a Legacy save active")

local optionOnly = save({
  johto_research = { version = 3 },
  johto_signals = { earlyJohto = { mode = "unleashed" } },
})
game.save = optionOnly
local optionActive = boundary.sync(game, optionOnly)
ok(not optionActive, "mere Johto options are not migration witnesses")

local failed = save()
game.save = failed
game.writeSave = function() return false end
boundary.sync(game, failed)
local failedChange, failedReason = boundary.activate(game)
ok(not failedChange and failedReason == "save_failed",
  "activation fails closed when durable save write fails")
ok(not boundary.isActive(failed), "failed activation rolls boundary state back")
eq(shared.pokemon.MAGNEMITE.types[2], nil,
  "failed activation rolls global overlays back")

german = true
local _, germanGate = boundary.canWithdrawMon(failed, { species = "TREECKO" })
ok(germanGate:find("JENSEITS VON KANTO", 1, true),
  "sealed bank reason is localized in German")

print(("beyond_kanto_boundary_test: %d checks passed"):format(checks))
