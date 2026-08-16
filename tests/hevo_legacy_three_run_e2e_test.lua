-- Real RED -> BLUE -> GREEN Hidden Evolution / Legacy Journey round trip.
--
-- This suite deliberately crosses the same separate durability boundaries as
-- production: game-save serialization, the Legacy archive filesystem, Fresh
-- Save seeding, character binding, dungeon finalization, pending first grants
-- and paid Workshop reacquisition.

local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
local root = assert(os.getenv("KA_HEVO_LEGACY_MOD"),
  "KA_HEVO_LEGACY_MOD is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;"
  .. package.path

local Data = require("src.core.Data")
local Serializer = require("src.core.SaveSerializer")
local Bag = require("src.inventory.Bag")
Data:load()

local makeArchive = assert(loadfile(root .. "/legacy_archive.lua"))()
local makeJourney = assert(loadfile(root .. "/legacy_journey.lua"))()
local makePackages = assert(loadfile(root .. "/hevo_packages.lua"))()
local makeAdapter = assert(loadfile(root .. "/legacy_dungeon_adapter.lua"))()
local makeWorkshop = assert(loadfile(root .. "/ngplus_legacy_workshop.lua"))()
local makePaths = assert(loadfile(root .. "/legacy_paths.lua"))()
local pathData = assert(loadfile(root .. "/legacy_paths_data.lua"))()
local makeStarters = assert(loadfile(root .. "/legacy_starters.lua"))()
local johto = assert(loadfile(root .. "/johto_data.lua"))()

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end

local function countTruthy(values)
  local count = 0
  for _, value in pairs(values or {}) do
    if value == true or (type(value) == "number" and value > 0) then
      count = count + 1
    end
  end
  return count
end

local function roundTrip(value)
  return assert(Serializer.decode(Serializer.encode(value)))
end

local files = {}
local archiveFs = {
  getInfo = function(path)
    return files[path] ~= nil and { type = "file" } or nil
  end,
  read = function(path) return files[path] end,
  write = function(path, bytes) files[path] = bytes return true end,
  remove = function(path) files[path] = nil return true end,
  createDirectory = function() return true end,
}

local function eventBus()
  local bus = { handlers = {} }
  function bus:on(name, callback, priority)
    self.handlers[name] = self.handlers[name] or {}
    self.handlers[name][#self.handlers[name] + 1] = {
      callback = callback, priority = priority or 0,
    }
    return callback
  end
  return bus
end

local function runtime()
  local archive = makeArchive({
    fs = archiveFs, serializer = Serializer, edition = "red",
    modId = "kanto_ascendant", directory = "test/hevo-three-run",
    now = function() return 650000 end,
    isBadge = Bag.isBadge,
  })
  local workshopState = {}
  local events = eventBus()
  local mod = {
    id = "kanto_ascendant", exports = {}, events = events,
    hooks = { wrap = function(_, _, callback) return callback end },
    log = { info = function() end, warn = function() end,
      error = function() end },
    save = {
      get = function(_, key) return workshopState[key] end,
      set = function(_, key, value) workshopState[key] = value end,
    },
  }
  local oakCalls = 0
  local journey = makeJourney(mod, {
    archive = archive,
    onOakCall = function(_, text, done)
      oakCalls = oakCalls + 1
      check(text:find("KASC PC", 1, true) ~= nil,
        "real Journey call names Oak's KASC PC")
      if done then done() end
      return true
    end,
  })
  local packages = makePackages(mod, {
    enabled = false, journey = journey, modId = "kanto_ascendant",
  })
  local mega = {}
  local function megaState(game, create)
    local bucket = game.save.modData.kanto_ascendant
    if type(bucket.mega_evolution) ~= "table" and create then
      bucket.mega_evolution = { version = 3, stones = {} }
    end
    local state = bucket.mega_evolution
    if state then state.stones = type(state.stones) == "table"
      and state.stones or {} end
    return state
  end
  function mega.hasStone(stoneId, game)
    local state = megaState(game, false)
    return state and state.stones[stoneId] == true or false
  end
  function mega.grantStone(stoneId, game)
    local state = megaState(game, true)
    if state.stones[stoneId] then return false end
    state.stones[stoneId] = true
    return true
  end
  local adapter = makeAdapter({
    archive = archive, journey = journey, packages = packages,
    megaEvolution = mega, events = events, modId = "kanto_ascendant",
  })
  local workshop = makeWorkshop(mod, {
    packages = packages, legacyProfile = function() return archive.profile() end,
  })
  local pathMod = {
    id = "kanto_ascendant", events = events, hooks = mod.hooks,
    log = mod.log,
  }
  local paths = makePaths(pathMod, {
    journey = journey, wanderers = {}, data = pathData,
  })
  local starterMod = {
    id = "kanto_ascendant", log = mod.log, events = events,
    content = { text = { register = function() end } },
  }
  local starters = makeStarters(starterMod, {
    journey = journey, hoenn = {}, johto = johto,
  })
  return {
    archive = archive, journey = journey, packages = packages,
    adapter = adapter, workshop = workshop, paths = paths,
    mega = mega,
    starters = starters,
    oakCalls = function() return oakCalls end,
  }
end

local function baseSave(playerId, character)
  return {
    version = "red",
    player = { id = playerId, name = character or "RED", rival = "BLUE" },
    flags = {}, party = {}, boxes = { {} }, daycare = {},
    inventory = {}, bagOrder = {}, pcItems = {}, money = 0,
    hallOfFame = {}, pokedex = { seen = {}, owned = {} },
    modData = character and { kanto_ascendant = {
      extended_characters = { enabled = true,
        player_character = character },
    } } or {},
  }
end

local function game(save)
  local result = { save = save, data = Data, writes = 0, persisted = nil }
  function result:writeSave()
    self.writes = self.writes + 1
    self.persisted = Serializer.encode(self.save)
    return true
  end
  return result
end

local function fillBag(save)
  local ids = {}
  for id in pairs(Data.items or {}) do
    if not Bag.isBadge(id) then ids[#ids + 1] = id end
  end
  table.sort(ids)
  local capacity = Bag.capacity(Data)
  for index = 1, capacity do
    local id = assert(ids[index], "not enough real items to fill the Bag")
    save.inventory[id] = 1
    save.bagOrder[#save.bagOrder + 1] = id
  end
  eq(Bag.slots(save), capacity, "the RED Bag starts genuinely full")
end

local packageIds = {
  RED = { "protector", "magmarizer", "rollout_knowledge",
    "ancient_power_red", "razor_fang" },
  BLUE = { "magnetic_field", "electirizer", "ice_field",
    "razor_claw", "dubious_disc" },
  GREEN = { "moss_field", "ancient_power_green", "shiny_stone",
    "double_hit_knowledge", "dusk_stone" },
}
local itemPackages = {
  protector = "PROTECTOR", magmarizer = "MAGMARIZER",
  razor_fang = "RAZOR_FANG", electirizer = "ELECTIRIZER",
  razor_claw = "RAZOR_CLAW", dubious_disc = "DUBIOUS_DISC",
  shiny_stone = "SHINY_STONE", dusk_stone = "DUSK_STONE",
}
local function ensureHevoItemFixture()
  local registry = makePackages({
    id = "kanto_ascendant", exports = {},
  }, {
    enabled = false, modId = "kanto_ascendant",
  })
  local directItems = 0
  for _, package in ipairs(registry.order) do
    if package.kind == "item" then
      assert(package.item, package.id .. " has no direct item")
      directItems = directItems + 1
      Data.items[package.item] = Data.items[package.item] or {
        id = package.item,
        name = package.itemName.en,
        price = 0,
        tossable = false,
        needsTarget = true,
        effect = registry.ITEM_EFFECT,
        lootExcluded = true,
        progressionItem = true,
      }
    end
  end
  assert(directItems == 8,
    "the authoritative HEVO registry must expose eight direct items")
end
local targetCounts = { RED = 5, BLUE = 5, GREEN = 7 }
local stone = { RED = "BLAZIKENITE", BLUE = "SWAMPERTITE",
  GREEN = "SCEPTILITE" }
local starter = { RED = "TORCHIC", BLUE = "MUDKIP",
  GREEN = "TREECKO" }
local ballPlans = {
  RED = { "HEAVY_BALL", "LEVEL_BALL" },
  BLUE = { "LURE_BALL", "FAST_BALL" },
  GREEN = { "FRIEND_BALL", "LOVE_BALL", "MOON_BALL" },
}
-- Full-mod authority tests load the real Apricorn item registry. Install the
-- isolated dependency fixture only after the original RED Bag has been
-- archived, so the fixture itself cannot seed a free Ball into that run.
local function ensureBallFixture()
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    for _, item in ipairs(ballPlans[character]) do
      Data.items[item] = Data.items[item] or {
        id = item, name = item:gsub("_", " "), price = 1000, ball = item,
      }
    end
  end
end

local function expectedState(rt, save, completed, secrets)
  secrets = secrets or {}
  local persistent = assert(rt.packages.persistent(save, false),
    "HEVO persistent state missing")
  local expectedPackages, expectedTargets, expectedFirstGrants = 0, 0, 0
  for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
    local shouldExist = completed[character] == true
    eq(persistent.meta[character] == true, shouldExist,
      character .. " metadata matches completed paths")
    local secretFound = secrets[character] == true
    eq(persistent.secretUnlocks[character] == true, secretFound,
      character .. " secret entitlement has no completion leak")
    eq(persistent.permanentItems[stone[character]] == true, secretFound,
      character .. " Mega stone exists only after its secret find")
    eq(rt.mega.hasStone(stone[character], { save = save }), secretFound,
      character .. " entitlement is synchronized into Mega runtime")
    eq(persistent.permanentItems["LEGACY_STARTER_"
      .. starter[character]] == true, shouldExist,
      character .. " starter lineage has no cross-run leak")
    eq(persistent.dex[starter[character]] == true, shouldExist,
      character .. " starter Dex metadata has no cross-run leak")
    for _, id in ipairs(packageIds[character]) do
      eq(persistent.packageUnlocks[id] == true, shouldExist,
        id .. " follows its character whitelist")
      if shouldExist then
        expectedPackages = expectedPackages + 1
        expectedTargets = expectedTargets + #rt.packages.byId[id].targets
        if itemPackages[id] then expectedFirstGrants = expectedFirstGrants + 1 end
      end
      for _, row in ipairs(rt.packages.byId[id].targets) do
        eq(persistent.evolutionUnlocks[row.target] == true, shouldExist,
          row.target .. " compatibility view follows its package")
      end
      if itemPackages[id] then
        eq(persistent.firstGrants[id] == true, shouldExist,
          id .. " first-grant sentinel is character-scoped")
      end
    end
  end
  eq(countTruthy(persistent.packageUnlocks), expectedPackages,
    "no foreign or duplicate package flags exist")
  eq(countTruthy(persistent.evolutionUnlocks), expectedTargets,
    "the derived target view has the exact expected size")
  eq(countTruthy(persistent.firstGrants), expectedFirstGrants,
    "only completed item packages have first-grant sentinels")
  return persistent
end

local function setSelectedTitle(save, id)
  local bucket = save.modData.kanto_ascendant
  bucket.ascendant = bucket.ascendant or { achievements = {} }
  bucket.legacy_hall = bucket.legacy_hall
    or { version = 1 }
  bucket.ascendant.selectedTitle = id
  bucket.legacy_hall.selectedTitle = id
end

local function reloadGame(sourceGame)
  local save = assert(Serializer.decode(assert(sourceGame.persisted,
    "the game did not write a durable save")))
  local rt = runtime()
  rt.archive.syncProfile(save)
  local reloaded = game(save)
  rt.packages.install(reloaded)
  check(rt.adapter.install(reloaded),
    "Mega secret entitlements reconcile on Save/Reload")
  reloaded:writeSave()
  return reloaded, rt
end

local function visitSharedDoor(sourceGame, rt, character)
  -- The shared-room focused suite proves that its physical door writes this
  -- exact campaign record only after currentHevoSeal().  This persistence E2E
  -- supplies that authored output, then exercises the real Journey callback.
  local bucket = sourceGame.save.modData.kanto_ascendant
  bucket.hidden_evolution_story_campaign =
    bucket.hidden_evolution_story_campaign or { version = 1, doorVisits = {} }
  bucket.hidden_evolution_story_campaign.doorVisits =
    bucket.hidden_evolution_story_campaign.doorVisits or {}
  bucket.hidden_evolution_story_campaign.doorVisits[character] = true
  local ok, why = rt.journey.notifyHevoSeal(sourceGame, character)
  check(ok and why == "hall",
    character .. " shared black door records its final beat before HOF")
  check(bucket.hidden_evolution_story_campaign.doorVisits[character] == true,
    character .. " matching shared-door visit is durable")
  check(not rt.journey.canBegin(sourceGame.save)
      and sourceGame.save.flags[rt.journey.HEVO_READY_FLAG] ~= true,
    character .. " door/seal never bypasses the HOF requirement")
end

local function nextJourney(sourceGame, rt, character, playerId)
  sourceGame.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  sourceGame.save.hallOfFame = { roundTrip(sourceGame.save.party) }
  sourceGame:writeSave()
  check(rt.journey.reconcileHevoSealGate(sourceGame.save, true),
    "HOF plus the matching current seal/black-door visit arms NG+")
  check(rt.journey.canBegin(sourceGame.save),
    "Journey readiness is true only after the full matching final beat")
  local callsBefore = rt.oakCalls()
  if sourceGame.save.flags[rt.journey.HEVO_OAK_CALLED_FLAG] == true then
    check(not rt.journey.deliverPendingHevoCall(sourceGame, "PALLET_TOWN"),
      "a previously completed matching-seal Oak call stays idempotent")
    eq(rt.oakCalls(), callsBefore,
      "Save/Reload/Journey hand-off cannot duplicate an Oak call")
  else
    check(rt.journey.deliverPendingHevoCall(sourceGame, "PALLET_TOWN"),
      "the pending matching-seal Oak call uses the runtime presentation seam")
    eq(rt.oakCalls(), callsBefore + 1,
      "each completed run delivers exactly one Oak call")
  end
  check(sourceGame.save.flags[rt.journey.HEVO_OAK_CALLED_FLAG] == true,
    "the completed Oak call survives the Journey hand-off")
  local current, err = rt.archive.beginJourney(sourceGame.save, {
    pact = "journey", playerAvatar = rt.journey.activeCharacter(sourceGame.save),
    runRules = rt.archive.safeRunRulesSnapshot(sourceGame.save),
  })
  check(current ~= nil, "Legacy transition failed: " .. tostring(err))
  local fresh = baseSave(playerId)
  check(rt.archive.seedNewSave(fresh), "Fresh Save receives Legacy state")
  check(rt.archive.importHandoff(fresh),
    "Fresh Save verifies the transient Legacy handoff")
  check(rt.archive.markRunStarted(fresh), "Fresh Save owns the active run")
  check(rt.archive.finishHandoff(fresh),
    "Fresh Save retires the verified Legacy handoff")
  check(rt.archive.setAvatar(fresh, character),
    "Fresh Save binds " .. character)
  fresh.modData.kanto_ascendant.extended_characters = {
    enabled = true, player_character = character,
  }
  local freshGame = game(roundTrip(fresh))
  freshGame:writeSave()
  return reloadGame(freshGame)
end

-- -------------------------------------------------------------- RED run

local red = game(baseSave(6501, "RED"))
fillBag(red.save)
-- Keep the deliberately full original Bag unchanged, then install the same
-- eight definitions production registers before the archive validates IDs.
ensureHevoItemFixture()
local rt = runtime()
rt.packages.install(red)
check(rt.adapter.install(red), "RED starts with a clean secret ledger")
eq(rt.starters.heroChoice(red.save).species, "TORCHIC",
  "RED's actual Oak left-ball contract is TORCHIC")
check(not rt.paths.titleUnlocked("legacy_path_red"),
  "RED title is locked before RED completion")

local redOk, redResult = rt.adapter.finalize(red, {
  character = "RED", questionIds = { "HEVO_RED_E2E" }, rivalWitness = true,
})
check(redOk, "RED dungeon finalizes")
visitSharedDoor(red, rt, "RED")
red.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
red.save.hallOfFame = { roundTrip(red.save.party) }
check(rt.journey.reconcileHevoSealGate(red.save, true)
    and rt.journey.deliverPendingHevoCall(red, "PALLET_TOWN")
    and rt.journey.canBegin(red.save),
  "RED HOF/seal/door unlocks the Journey before any Mega secret")
check(not rt.adapter.hasSecret(red.save, "RED"),
  "Legacy readiness is independent from optional BLAZIKENITE")
eq(#redResult.packages, 5, "RED finalizes all five packages atomically")
eq(redResult.targetCount, 5, "RED finalizes exactly five targets")
local redPersistent = expectedState(rt, red.save, { RED = true })
local redLedger = rt.workshop.ledger(red.save)
eq(#redLedger[1].packages, 5,
  "RED seal exposes the same five authority packages in the Ledger")
eq(#redLedger[1].balls, 2,
  "RED seal exposes Heavy and Level Ball plans")
eq(redLedger[1].openDiscoveries, 1,
  "RED completion reveals its starter but keeps the Mega cache hidden")
eq(#rt.workshop.ballOffers(red.save), 2,
  "RED completion permanently opens exactly two Ball plans")
eq(red.save.inventory.PROTECTOR, nil,
  "a full Bag does not receive an out-of-band PROTECTOR")
eq(redPersistent.pendingItems.PROTECTOR, 1,
  "RED PROTECTOR becomes a pending first grant")
eq(redPersistent.pendingItems.MAGMARIZER, 1,
  "RED MAGMARIZER becomes a pending first grant")
eq(redPersistent.pendingItems.RAZOR_FANG, 1,
  "RED RAZOR FANG becomes a pending first grant")
eq(countTruthy(redPersistent.pendingItems), 3,
  "RED has exactly three pending item grants")
local claimedFull, fullWhy = rt.workshop.claimPending(red)
eq(claimedFull, false, "a full Bag cannot claim pending grants")
eq(fullWhy, "bag-full", "the full-Bag failure is explicit")
eq(countTruthy(rt.packages.persistent(red.save).pendingItems), 3,
  "a failed pending claim is side-effect free")
check(rt.paths.titleUnlocked("legacy_path_red"),
  "RED completion unlocks the real Legacy title")
check(not rt.paths.titleUnlocked("legacy_path_blue"),
  "RED completion does not unlock BLUE's title")
local beforeDuplicate = Serializer.encode(red.save.modData.kanto_ascendant)
local duplicateOk, duplicateWhy = rt.adapter.finalize(red, { character = "RED" })
eq(duplicateOk, false, "RED cannot finalize twice in one run")
eq(duplicateWhy, "claimed", "duplicate RED completion reports claimed")
eq(Serializer.encode(red.save.modData.kanto_ascendant), beforeDuplicate,
  "duplicate RED completion cannot mutate rewards")
local crossSecret, crossSecretWhy = rt.adapter.claimSecret(red, {
  character = "BLUE", stone = "SWAMPERTITE",
  secret = "KA_HEVO_BLUE_SWAMPERTITE_CACHE",
})
check(not crossSecret and crossSecretWhy == "character",
  "RED cannot claim BLUE's secret")
check(rt.adapter.reenter(red.save, "RED"),
  "RED may re-enter its completed path for the optional cache")
local redSecret, redSecretResult = rt.adapter.claimSecret(red, {
  character = "RED", stone = "BLAZIKENITE",
  secret = "KA_RED_BLAZIKENITE_SECRET",
})
check(redSecret and redSecretResult.stone == "BLAZIKENITE",
  "RED's later cache interaction grants BLAZIKENITE")
expectedState(rt, red.save, { RED = true }, { RED = true })
eq(rt.workshop.ledger(red.save)[1].openDiscoveries, 0,
  "RED's Mega trace appears only after the actual cache interaction")
local duplicateSecret, duplicateSecretWhy = rt.adapter.claimSecret(red, {
  character = "RED", stone = "BLAZIKENITE",
  secret = "KA_RED_BLAZIKENITE_SECRET",
})
check(not duplicateSecret and duplicateSecretWhy == "claimed",
  "RED's cache is idempotent and cannot duplicate its stone")

setSelectedTitle(red.save, "legacy_path_red")
red:writeSave()
red, rt = reloadGame(red)
expectedState(rt, red.save, { RED = true }, { RED = true })

-- ------------------------------------------------------------- BLUE run

local blue
blue, rt = nextJourney(red, rt, "BLUE", 6502)
ensureBallFixture()
eq(rt.starters.heroChoice(blue.save).species, "MUDKIP",
  "BLUE's actual Oak left-ball contract is MUDKIP")
check(blue.save.modData.kanto_ascendant.legacy_journey.partnerChosen ~= true,
  "HEVO progression never silently chooses BLUE's Oak partner")
eq(blue.save.modData.kanto_ascendant.legacy_hall.selectedTitle,
  "legacy_path_red", "RED's selected title survives the Fresh Save")
local blueBefore = expectedState(rt, blue.save, { RED = true }, { RED = true })
eq(countTruthy(blueBefore.pendingItems), 3,
  "RED pending grants survive Save/Reload/NG+")
local redOnlyOffers = rt.workshop.offers(blue.save)
eq(#redOnlyOffers, 3,
  "before BLUE completion Workshop exposes only RED's item packages")
for _, offer in ipairs(redOnlyOffers) do
  eq(rt.packages.byId[offer.packageId].character, "RED",
    "pre-BLUE Workshop offer cannot cross-unlock")
end
eq(#rt.workshop.ballOffers(blue.save), 2,
  "RED Ball plans survive Save/Reload/Fresh BLUE NG+")

local claimed, claimedItems = rt.workshop.claimPending(blue)
check(claimed, "pending RED grants are claimable in BLUE's Fresh Save")
eq(#claimedItems, 3, "all three RED pending grants are claimed once")
for _, id in ipairs({ "PROTECTOR", "MAGMARIZER", "RAZOR_FANG" }) do
  eq(blue.save.inventory[id], 1, id .. " is present exactly once")
end
eq(next(rt.packages.persistent(blue.save).pendingItems), nil,
  "successful pending claim clears the durable queue")
blue, rt = reloadGame(blue)
eq(next(rt.archive.hevoPersistent().pendingItems), nil,
  "archive reload does not resurrect a claimed pending item")
local claimedAgain, emptyWhy = rt.workshop.claimPending(blue)
eq(claimedAgain, false, "claimed pending grants cannot duplicate")
eq(emptyWhy, "empty", "repeat pending claim reports empty")

Bag.remove(blue.save, "PROTECTOR", 1)
blue.save.money = 19600
local moneyBeforeCancel = blue.save.money
local cancelled = rt.workshop.purchase(blue, "protector", false)
eq(cancelled, false, "Workshop cancellation is side-effect free")
eq(blue.save.money, moneyBeforeCancel, "cancel does not charge money")
eq(blue.save.inventory.PROTECTOR, nil, "cancel does not duplicate PROTECTOR")
local bought, boughtItem = rt.workshop.purchase(blue, "protector", true)
check(bought, "RED's consumed PROTECTOR can be reacquired in NG+")
eq(boughtItem, "PROTECTOR", "Workshop returns the authored item")
eq(blue.save.inventory.PROTECTOR, 1,
  "one confirmed purchase adds exactly one PROTECTOR")
eq(blue.save.money, 9800, "one purchase charges exactly 9,800")
for _, item in ipairs(ballPlans.RED) do
  local purchased, purchasedItem = rt.workshop.purchaseBall(blue, item, true)
  check(purchased and purchasedItem == item,
    item .. " is purchasable from RED's permanent plan")
  eq(blue.save.inventory[item], 1,
    item .. " enters the normal Bag exactly once")
end
eq(blue.save.money, 7800,
  "two RED Ball plans charge exactly two authored prices")

local blueOk, blueResult = rt.adapter.finalize(blue, {
  character = "BLUE", questionIds = { "HEVO_BLUE_E2E" },
})
check(blueOk, "BLUE dungeon finalizes")
visitSharedDoor(blue, rt, "BLUE")
eq(#blueResult.packages, 5, "BLUE finalizes all five packages atomically")
eq(blueResult.targetCount, 5, "BLUE finalizes exactly five targets")
expectedState(rt, blue.save, { RED = true, BLUE = true }, { RED = true })
for _, id in ipairs({ "PROTECTOR", "MAGMARIZER", "RAZOR_FANG",
    "ELECTIRIZER", "RAZOR_CLAW", "DUBIOUS_DISC" }) do
  eq(blue.save.inventory[id], 1,
    id .. " is neither lost nor duplicated after BLUE completion")
end
eq(#rt.workshop.offers(blue.save), 6,
  "Workshop exposes exactly six RED/BLUE item packages")
eq(#rt.workshop.ballOffers(blue.save), 4,
  "BLUE completion adds only Lure and Fast Ball plans")
for _, item in ipairs(ballPlans.BLUE) do
  check(rt.workshop.purchaseBall(blue, item, true),
    item .. " is purchasable from BLUE's permanent plan")
  eq(blue.save.inventory[item], 1,
    item .. " enters the normal Bag exactly once")
end
eq(blue.save.money, 5800,
  "BLUE Ball plans also charge exactly ¥1,000 each")
local blueLedger = rt.workshop.ledger(blue.save)
eq(blueLedger[2].openDiscoveries, 1,
  "BLUE completion keeps SWAMPERTITE hidden")
check(rt.adapter.reenter(blue.save, "BLUE"),
  "BLUE may revisit the tidal cache after completion")
local blueSecret, blueSecretResult = rt.adapter.claimSecret(blue, {
  character = "BLUE", stone = "SWAMPERTITE",
  secret = "KA_HEVO_BLUE_SWAMPERTITE_CACHE",
})
check(blueSecret and blueSecretResult.stone == "SWAMPERTITE",
  "BLUE's explicit tidal cache grants SWAMPERTITE")
expectedState(rt, blue.save, { RED = true, BLUE = true },
  { RED = true, BLUE = true })
check(rt.paths.titleUnlocked("legacy_path_red")
    and rt.paths.titleUnlocked("legacy_path_blue"),
  "RED and BLUE titles are now unlocked")
check(not rt.paths.titleUnlocked("legacy_path_green"),
  "BLUE completion does not unlock GREEN's title")

setSelectedTitle(blue.save, "legacy_path_blue")
blue:writeSave()
blue, rt = reloadGame(blue)
expectedState(rt, blue.save, { RED = true, BLUE = true },
  { RED = true, BLUE = true })

-- ------------------------------------------------------------- GREEN run

local green
green, rt = nextJourney(blue, rt, "GREEN", 6503)
eq(rt.starters.heroChoice(green.save).species, "TREECKO",
  "GREEN's actual Oak left-ball contract is TREECKO")
check(green.save.modData.kanto_ascendant.legacy_journey.partnerChosen ~= true,
  "HEVO progression never silently chooses GREEN's Oak partner")
eq(green.save.modData.kanto_ascendant.legacy_hall.selectedTitle,
  "legacy_path_blue", "BLUE's selected title survives the Fresh Save")
expectedState(rt, green.save, { RED = true, BLUE = true },
  { RED = true, BLUE = true })
eq(next(green.save.inventory), nil,
  "Fresh Save does not silently duplicate prior first-grant items")
local locker = rt.archive.locker()
for _, id in ipairs({ "PROTECTOR", "MAGMARIZER", "RAZOR_FANG",
    "ELECTIRIZER", "RAZOR_CLAW", "DUBIOUS_DISC" }) do
  eq(locker.items[id], 1,
    id .. " is preserved exactly once in the Legacy Locker")
end
for _, character in ipairs({ "RED", "BLUE" }) do
  for _, item in ipairs(ballPlans[character]) do
    eq(locker.items[item], 1,
      item .. " is preserved exactly once through Fresh GREEN NG+")
  end
end

local greenOk, greenResult = rt.adapter.finalize(green, {
  character = "GREEN", questionIds = { "HEVO_GREEN_E2E" },
})
check(greenOk, "GREEN dungeon finalizes")
visitSharedDoor(green, rt, "GREEN")
eq(#greenResult.packages, 5,
  "GREEN finalizes five packages atomically")
eq(greenResult.targetCount, 7,
  "GREEN's five packages finalize exactly seven targets")
local allPersistent = expectedState(rt, green.save, {
  RED = true, BLUE = true, GREEN = true,
}, { RED = true, BLUE = true })
eq(countTruthy(allPersistent.packageUnlocks), 15,
  "all three runs produce exactly fifteen package unlocks")
eq(countTruthy(allPersistent.evolutionUnlocks), 17,
  "all three runs produce exactly seventeen target unlocks")
eq(countTruthy(allPersistent.firstGrants), 8,
  "all eight consumable package grants are recorded once")
eq(next(allPersistent.pendingItems), nil,
  "GREEN completion has no unexpected pending duplication")
eq(green.save.inventory.SHINY_STONE, 1,
  "GREEN receives one SHINY STONE first grant")
eq(green.save.inventory.DUSK_STONE, 1,
  "GREEN receives one DUSK STONE first grant")
eq(#rt.workshop.offers(green.save), 8,
  "complete Workshop exposes exactly eight consumable packages")
eq(#rt.workshop.ballOffers(green.save), 7,
  "complete Workshop exposes exactly seven authored Ball plans")
local greenLedger = rt.workshop.ledger(green.save)
eq(greenLedger[3].openDiscoveries, 1,
  "GREEN completion leaves SCEPTILITE as an optional secret")
check(rt.adapter.reenter(green.save, "GREEN"),
  "GREEN may revisit the grove's secret after completion")
local greenSecret, greenSecretResult = rt.adapter.claimSecret(green, {
  character = "GREEN", stone = "SCEPTILITE",
  secret = "KA_GREEN_SCEPTILITE_SECRET",
})
check(greenSecret and greenSecretResult.stone == "SCEPTILITE",
  "GREEN's explicit grove cache grants SCEPTILITE")
allPersistent = expectedState(rt, green.save, {
  RED = true, BLUE = true, GREEN = true,
}, { RED = true, BLUE = true, GREEN = true })
green.save.money = 3000
for _, item in ipairs(ballPlans.GREEN) do
  check(rt.workshop.purchaseBall(green, item, true),
    item .. " is purchasable from GREEN's permanent plan")
  eq(green.save.inventory[item], 1,
    item .. " enters the normal Bag exactly once")
end
eq(green.save.money, 0,
  "all three GREEN Ball plans charge exactly once")
local gs, gsWhy = rt.workshop.purchaseBall(green, "GS_BALL", true)
check(not gs and gsWhy == "gs-ball-excluded",
  "GS Ball remains excluded even after all three seals")
check(rt.paths.titleUnlocked("legacy_path_red")
    and rt.paths.titleUnlocked("legacy_path_blue")
    and rt.paths.titleUnlocked("legacy_path_green"),
  "all three character titles are unlocked")
check(not rt.paths.titleUnlocked("legacy_pass"),
  "the Legacy Pass title remains locked before the finale")
check(not rt.adapter.archiveReady(green.save),
  "three paths do not bypass the current-run Champion requirement")
green.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
check(rt.adapter.archiveReady(green.save),
  "three paths plus current Champion unlock the sealed archive hook")
check(rt.journey.completeFinale(green.save),
  "the real Legacy finale commits after all three paths")
check(rt.paths.titleUnlocked("legacy_pass"),
  "the finale unlocks the Legacy Keeper title")

setSelectedTitle(green.save, "legacy_pass")
green:writeSave()
green, rt = reloadGame(green)
expectedState(rt, green.save, { RED = true, BLUE = true, GREEN = true },
  { RED = true, BLUE = true, GREEN = true })

-- ----------------------------------------------- fourth Fresh Save proof

local fourth
fourth, rt = nextJourney(green, rt, "RED", 6504)
eq(rt.starters.heroChoice(fourth.save).species, "TORCHIC",
  "the next RED cycle still exposes TORCHIC without auto-selecting it")
check(fourth.save.modData.kanto_ascendant.legacy_journey.partnerChosen ~= true,
  "the next cycle receives one clean Oak choice")
eq(fourth.save.modData.kanto_ascendant.legacy_hall.selectedTitle,
  "legacy_pass", "selected Legacy Keeper title survives another Fresh Save")
local fourthPersistent = expectedState(rt, fourth.save, {
  RED = true, BLUE = true, GREEN = true,
}, { RED = true, BLUE = true, GREEN = true })
eq(next(fourthPersistent.pendingItems), nil,
  "another NG+ cannot resurrect any first-grant queue")
eq(next(fourth.save.inventory), nil,
  "another NG+ cannot duplicate package items into the new Bag")
local finalLocker = rt.archive.locker()
for _, id in ipairs({ "PROTECTOR", "MAGMARIZER", "RAZOR_FANG",
    "ELECTIRIZER", "RAZOR_CLAW", "DUBIOUS_DISC",
    "SHINY_STONE", "DUSK_STONE" }) do
  eq(finalLocker.items[id], 1,
    id .. " remains exactly once in the Legacy Locker after three runs")
end
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  for _, item in ipairs(ballPlans[character]) do
    eq(finalLocker.items[item], 1,
      item .. " remains exactly once in the Legacy Locker after three runs")
  end
end
fourth.save.money = 9800
local finalBought = rt.workshop.purchase(fourth, "dusk_stone", true)
check(finalBought, "a completed GREEN item remains reacquirable next cycle")
eq(fourth.save.inventory.DUSK_STONE, 1,
  "next-cycle Workshop purchase grants exactly one DUSK STONE")
eq(fourth.save.money, 0,
  "next-cycle Workshop purchase charges exactly once")
fourth, rt = reloadGame(fourth)
eq(fourth.save.inventory.DUSK_STONE, 1,
  "Workshop reacquisition survives a real game-save reload")
expectedState(rt, fourth.save, {
  RED = true, BLUE = true, GREEN = true,
}, { RED = true, BLUE = true, GREEN = true })

print(("HEVO LEGACY THREE-RUN E2E PASS: %d assertions"):format(assertions))
