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
local function legacyMeta(policy)
  return { itemPolicy = policy or "safe", runRules = DEFAULT_RUN_RULES }
end

local function memfs()
  local files = {}
  return {
    files = files,
    getInfo = function(path)
      return files[path] ~= nil and { type = "file" } or nil
    end,
    read = function(path) return files[path] end,
    write = function(path, bytes) files[path] = bytes return true end,
    remove = function(path) files[path] = nil return true end,
    createDirectory = function() return true end,
  }
end

local basePokemon = {
  PIKACHU = { name = "PIKACHU" }, EEVEE = { name = "EEVEE" },
  BULBASAUR = { name = "BULBASAUR" },
}
local baseMoves = {
  TACKLE = { name = "TACKLE" }, GROWL = { name = "GROWL" },
}
local baseItems = {
  POTION = { name = "POTION" }, ANTIDOTE = { name = "ANTIDOTE" },
  BICYCLE = { name = "BICYCLE", tossable = false },
  HM_SURF = { name = "HM03", machine = { kind = "HM", move = "SURF" } },
  TM_THUNDERBOLT = { name = "TM24",
    machine = { kind = "TM", move = "THUNDERBOLT" } },
  FIELD_KIT = { name = "FIELD KIT", tossable = false },
  MEGA_RING = { name = "MEGA RING", tossable = false },
  MEGA_STONE_CASE = { name = "MEGA STONE CASE", tossable = false },
  BLAZIKENITE = { name = "BLAZIKENITE", tossable = false },
  SWAMPERTITE = { name = "SWAMPERTITE", tossable = false },
  SCEPTILITE = { name = "SCEPTILITE", tossable = false },
  VENUSAURITE = { name = "VENUSAURITE", tossable = false },
  SHINY_CHARM = { name = "SHINY CHARM", tossable = false },
  PROTECTOR = { name = "PROTECTOR", tossable = false, needsTarget = true },
  UNREVIEWED_RELIC = { name = "UNREVIEWED RELIC", tossable = false },
}

local fs = memfs()
local function make(pokemon, items, moves)
  return createArchive({
    fs = fs, serializer = Serializer, edition = "red",
    modId = "kanto_ascendant", directory = "test/integrity",
    pokemonRegistry = pokemon, itemRegistry = items, moveRegistry = moves,
    isBadge = function(id) return id == "BOULDER_BADGE" end,
  })
end

local strictFs = memfs()
local strict = createArchive({
  fs = strictFs, serializer = Serializer, edition = "red",
  directory = "test/strict", requireRegistryValidation = true,
})
local strictBlocked, strictErr = strict.beginJourney({
  version = "red", player = { id = 999 }, party = {}, boxes = { {} },
  inventory = {}, pcItems = {}, modData = {},
})
eq(strictBlocked, nil, "production mode fails closed without registries")
ok(tostring(strictErr):find("validation", 1, true),
  "missing-registry failure is explicit")
eq(strictFs.files[strict.filename], nil,
  "missing registry cannot create an unvalidated archive")

local archive = make(basePokemon, baseItems, baseMoves)
local function champion(id, species, move, item)
  return {
    version = "red", player = { id = id, name = "RED" },
    flags = { EVENT_BEAT_CHAMPION_RIVAL = true }, hallOfFame = { {} },
    party = { { species = species or "PIKACHU", level = 50,
      moves = { move or "TACKLE" } } }, boxes = { {} },
    inventory = { [item or "POTION"] = 1, BICYCLE = 1, HM_SURF = 1,
      TM_THUNDERBOLT = 2, FIELD_KIT = 1, MEGA_RING = 1,
      MEGA_STONE_CASE = 1, BLAZIKENITE = 3, SWAMPERTITE = 2,
      SCEPTILITE = 4, VENUSAURITE = 2, SHINY_CHARM = 1,
      PROTECTOR = 2, UNREVIEWED_RELIC = 1,
      BOULDER_BADGE = 1 }, pcItems = {}, money = 100,
    modData = { kanto_ascendant = { mega_evolution = {
      ring = true, case = true, stones = {
        BLAZIKENITE = true, SWAMPERTITE = true, SCEPTILITE = true,
        VENUSAURITE = true,
      },
    } } },
  }
end

local vanillaHeld = champion(1)
vanillaHeld.daycare = { mon = { species = "EEVEE", moves = { "TACKLE" } } }
local blocked, blockErr = archive.beginJourney(vanillaHeld)
eq(blocked, nil, "vanilla Day-Care Pokémon blocks the destructive hand-off")
ok(tostring(blockErr):find("Day%-Care"), "vanilla blocker is actionable")
eq(fs.files[archive.filename], nil, "blocked hand-off writes no archive")

local plusHeld = champion(2)
plusHeld.modData.kanto_ascendant.daycare_plus = {
  parents = { { mon = { species = "PIKACHU", moves = { "TACKLE" } } } },
  reservedEggs = { { species = "EEVEE", steps = 10 } },
}
local plusBlocked, plusErr = archive.beginJourney(plusHeld)
eq(plusBlocked, nil, "Day-Care Plus parents and reservations block Legacy")
ok(tostring(plusErr):find("parent") and tostring(plusErr):find("reserved"),
  "Day-Care Plus blocker names both outstanding containers")
eq(fs.files[archive.filename], nil, "Day-Care Plus blocker is side-effect free")

local first = champion(10)
assert(archive.beginJourney(first, legacyMeta()))
local stored = archive.load()
eq(#stored.bank, 1, "cycle one archives its registered Pokémon")
eq(stored.locker.items.POTION, 1, "ordinary item enters the locker")
eq(stored.locker.items.TM_THUNDERBOLT, 2,
  "one-use TMs retain their exact counted quantity")
eq(stored.locker.items.BICYCLE, nil, "key item never enters the locker")
eq(stored.locker.items.HM_SURF, nil, "HM never enters the locker")
eq(stored.locker.items.BOULDER_BADGE, nil, "badge never enters the locker")
eq(stored.locker.items.FIELD_KIT, nil,
  "Field Kit is a current-run milestone, not a counted locker copy")
eq(stored.locker.items.MEGA_RING, nil,
  "Mega Ring is re-earned from the current journey event, not copied")
eq(stored.locker.items.MEGA_STONE_CASE, nil,
  "Mega Stone Case is re-earned from the current journey event, not copied")
eq(stored.locker.items.BLAZIKENITE, 1,
  "Mega Stone Bag residue and Stone Case state collapse to one unique receipt")
eq(stored.locker.items.SWAMPERTITE, 1,
  "Blue's Hoenn relic collapses to one unique receipt")
eq(stored.locker.items.SCEPTILITE, 1,
  "Green's Hoenn relic collapses to one unique receipt")
eq(stored.locker.items.VENUSAURITE, 1,
  "SAFE still carries other owned Mega Stones as unique receipts")
eq(stored.locker.items.SHINY_CHARM, nil,
  "explicit mod story items are re-earned instead of duplicated")
eq(stored.locker.items.PROTECTOR, 2,
  "reviewed non-tossable evolution tools retain exact counted quantity")
eq(stored.locker.items.UNREVIEWED_RELIC, nil,
  "unreviewed non-tossable items fail closed instead of becoming key items")
eq(stored.quarantine.items.UNREVIEWED_RELIC.count, 1,
  "unreviewed non-tossable item is preserved in quarantine for review")
eq(stored.quarantine.items.BICYCLE, nil,
  "key item is dropped instead of accumulating in quarantine")
eq(stored.quarantine.items.HM_SURF, nil,
  "HM is dropped instead of accumulating in quarantine")

local expectedPolicies = {
  POTION = { "consumable", true, "counted" },
  TM_THUNDERBOLT = { "tm", true, "counted" },
  HM_SURF = { "hm", false, "current_story" },
  BICYCLE = { "key_item", false, "current_story_once" },
  FIELD_KIT = { "field_kit", false, "current_story_once" },
  MEGA_RING = { "mega_access", false, "current_story_once" },
  BLAZIKENITE = { "mega_stone", true, "unique_after_mega_access" },
  SWAMPERTITE = { "mega_stone", true, "unique_after_mega_access" },
  SCEPTILITE = { "mega_stone", true, "unique_after_mega_access" },
  VENUSAURITE = { "mega_stone", true, "unique_after_mega_access" },
  SHINY_CHARM = { "key_item", false, "current_story_once" },
  PROTECTOR = { "consumable", true, "counted" },
  UNREVIEWED_RELIC = { "unknown", false, "quarantine" },
  BOULDER_BADGE = { "badge", false, "current_story" },
}
for id, expected in pairs(expectedPolicies) do
  local policy = archive.classifyItem(id)
  eq(policy.category, expected[1], id .. " has an explicit Legacy category")
  eq(policy.transferable, expected[2], id .. " transferability is explicit")
  eq(policy.claimMode, expected[3], id .. " has an explicit claim mode")
end
for _, id in ipairs({ "BLAZIKENITE", "SWAMPERTITE", "SCEPTILITE" }) do
  eq(archive.classifyItem(id).legacySouvenir, true,
    id .. " is explicitly marked as an always-carried Legacy souvenir")
  eq(archive.hoennRelicStoneIds[id], true,
    id .. " is exported in the reviewed Hoenn souvenir set")
end
eq(archive.classifyItem("VENUSAURITE").legacySouvenir, false,
  "ordinary Mega Stones remain governed by SAFE/EMPTY")
eq(archive.itemPolicyCategories.mega_stone.transferable, true,
  "the public category table documents unique transferable Mega Stones")
eq(archive.classifyItem("UNREVIEWED_RELIC").lockReason,
  "unclassified_non_tossable",
  "registered non-tossable item reports why it is quarantined")
local safeSummary = archive.summary(champion(90), { itemPolicy = "safe" })
local emptySummary = archive.summary(champion(91), {
  itemPolicy = "empty",
})
eq(safeSummary.itemPolicy, "safe",
  "SAFE item policy seam is normalized and exposed")
ok(safeSummary.items > 0, "SAFE keeps explicitly transferable item classes")
eq(emptySummary.itemPolicy, "empty",
  "EMPTY item policy seam is normalized and exposed")
eq(emptySummary.items, 3,
  "EMPTY still carries exactly the three owned Hoenn souvenir receipts")
ok(safeSummary.items > emptySummary.items,
  "EMPTY still excludes ordinary Bag and PC item cargo")
local partialRelics = champion(92)
partialRelics.inventory.SWAMPERTITE = nil
partialRelics.inventory.SCEPTILITE = nil
partialRelics.modData.kanto_ascendant.mega_evolution.stones.SWAMPERTITE = nil
partialRelics.modData.kanto_ascendant.mega_evolution.stones.SCEPTILITE = nil
local partialSummary = archive.summary(partialRelics, { itemPolicy = "empty" })
eq(partialSummary.items, 1,
  "EMPTY never grants unearned Hoenn stones from a partial souvenir set")

-- The summary contract is backed by the real hand-off and checkout ledger:
-- EMPTY carries the earned three souvenirs, not an ordinary Mega Stone;
-- cancelled payout retains the receipt and completed payout consumes it once.
local relicFs = memfs()
local relicArchive = createArchive({
  fs = relicFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/relic_empty",
  pokemonRegistry = basePokemon, itemRegistry = baseItems,
  moveRegistry = baseMoves,
  isBadge = function(id) return id == "BOULDER_BADGE" end,
})
local allRelics = champion(93)
assert(relicArchive.beginJourney(allRelics, legacyMeta("empty")))
local relicLocker = relicArchive.locker()
for _, id in ipairs({ "BLAZIKENITE", "SWAMPERTITE", "SCEPTILITE" }) do
  eq(relicLocker.items[id], 1,
    "EMPTY hand-off stores one durable receipt for " .. id)
end
eq(relicLocker.items.VENUSAURITE, nil,
  "EMPTY excludes ordinary Mega Stones even when their Stone Case flag is set")
eq(relicLocker.items.POTION, nil,
  "EMPTY excludes ordinary consumables beside the souvenir exception")

local relicFresh = { version = "red", player = { id = 94 }, party = {},
  boxes = { {} }, inventory = {}, pcItems = {}, modData = {} }
assert(relicArchive.seedNewSave(relicFresh))
assert(relicArchive.markRunStarted(relicFresh))
local relicBucket = relicFresh.modData.kanto_ascendant
relicBucket.legacy_journey.partnerChosen = true
eq(select(2, relicArchive.itemClaimStatus(relicFresh, "SWAMPERTITE")),
  "mega_access_required",
  "always-carried souvenir still needs this run's Stone Case")
relicBucket.mega_evolution = { ring = true, case = true, stones = {} }
local cancelledRelic = assert(relicArchive.beginItemCheckout(
  relicFresh, "BLAZIKENITE", 99))
eq(cancelledRelic.count, 1,
  "souvenir payout remains a unique one-stone transaction")
assert(relicArchive.cancelCheckout(cancelledRelic.id))
eq(relicArchive.locker().items.BLAZIKENITE, 1,
  "cancelled souvenir payout leaves its Locker receipt intact")
for _, id in ipairs({ "BLAZIKENITE", "SWAMPERTITE", "SCEPTILITE" }) do
  local payout = assert(relicArchive.beginItemCheckout(relicFresh, id, 99))
  eq(payout.count, 1, id .. " payout is hard-capped at one")
  relicBucket.mega_evolution.stones[id] = true
  assert(relicArchive.completeCheckout(relicFresh, payout.id))
  eq(relicArchive.locker().items[id], nil,
    id .. " exact-once receipt is consumed after saved ownership")
  eq(select(2, relicArchive.itemClaimStatus(relicFresh, id)),
    "already_owned", id .. " is idempotently recognized after payout")
end

local partialFs = memfs()
local partialArchive = createArchive({
  fs = partialFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/relic_partial",
  pokemonRegistry = basePokemon, itemRegistry = baseItems,
  moveRegistry = baseMoves,
  isBadge = function(id) return id == "BOULDER_BADGE" end,
})
assert(partialArchive.beginJourney(partialRelics, legacyMeta("empty")))
local partialLocker = partialArchive.locker().items
eq(partialLocker.BLAZIKENITE, 1,
  "partial EMPTY hand-off carries its one actually earned souvenir")
eq(partialLocker.SWAMPERTITE, nil,
  "partial EMPTY hand-off does not fabricate Blue's souvenir")
eq(partialLocker.SCEPTILITE, nil,
  "partial EMPTY hand-off does not fabricate Green's souvenir")

-- The real HEVO cache ledger stores permanent stones as booleans rather than
-- Bag counts. A later run may have no stale inventory/Stone Case copy left,
-- so that durable, secret-bound witness must remain sufficient by itself.
local ledgerFs = memfs()
local ledgerArchive = createArchive({
  fs = ledgerFs, serializer = Serializer, edition = "red",
  modId = "kanto_ascendant", directory = "test/relic_ledger",
  pokemonRegistry = basePokemon, itemRegistry = baseItems,
  moveRegistry = baseMoves,
  isBadge = function(id) return id == "BOULDER_BADGE" end,
})
local ledgerOnly = champion(95)
ledgerOnly.inventory.BLAZIKENITE = nil
ledgerOnly.inventory.SWAMPERTITE = nil
ledgerOnly.inventory.SCEPTILITE = nil
ledgerOnly.modData.kanto_ascendant.mega_evolution.stones = {}
ledgerOnly.modData.kanto_ascendant.hevo_persistent = {
  permanentItems = { BLAZIKENITE = true, SWAMPERTITE = true },
  secretUnlocks = { RED = true, BLUE = true },
}
assert(ledgerArchive.beginJourney(ledgerOnly, legacyMeta("empty")))
local ledgerLocker = ledgerArchive.locker().items
eq(ledgerLocker.BLAZIKENITE, 1,
  "boolean HEVO ledger carries Red's souvenir under EMPTY")
eq(ledgerLocker.SWAMPERTITE, 1,
  "boolean HEVO ledger carries Blue's souvenir under EMPTY")
eq(ledgerLocker.SCEPTILITE, nil,
  "boolean HEVO ledger does not fabricate Green's missing secret")

-- Old preview archives could already contain persistent story items. A live
-- locker read must scrub those entries rather than exposing, duplicating or
-- indefinitely quarantining them.
stored.locker.items.BICYCLE = 5
stored.locker.items.HM_SURF = 3
stored.quarantine.items.BICYCLE = { count = 2, reason = "story_item" }
stored.quarantine.items.HM_SURF = { count = 4, reason = "story_item" }
assert(archive.write(stored))
local scrubbedLocker = archive.locker()
eq(scrubbedLocker.items.BICYCLE, nil,
  "old key item is scrubbed from an existing locker")
eq(scrubbedLocker.items.HM_SURF, nil,
  "old HM is scrubbed from an existing locker")
eq(archive.quarantine().items.BICYCLE, nil,
  "old key item is not stranded in quarantine")
eq(archive.quarantine().items.HM_SURF, nil,
  "old HM is not stranded in quarantine")

local fresh1 = { version = "red", player = { id = 11 }, party = {},
  boxes = { {} }, inventory = {}, pcItems = {}, modData = {} }
ok(archive.seedNewSave(fresh1), "cycle one seeds a real fresh save")
ok(archive.markRunStarted(fresh1), "cycle one becomes active")
fresh1.modData.kanto_ascendant.legacy_journey.partnerChosen = true
eq(#archive.availableMons(fresh1), 1, "registered bank Pokémon is payable")

-- A species and item supplied by another mod disappear before cycle two.
local withGuestPokemon = {
  PIKACHU = basePokemon.PIKACHU, EEVEE = basePokemon.EEVEE,
  BULBASAUR = basePokemon.BULBASAUR, GUESTMON = { name = "GUESTMON" },
}
local withGuestMoves = {
  TACKLE = baseMoves.TACKLE, GROWL = baseMoves.GROWL,
  GUEST_MOVE = { name = "GUEST MOVE" },
}
local withGuestItems = {
  POTION = baseItems.POTION, ANTIDOTE = baseItems.ANTIDOTE,
  BICYCLE = baseItems.BICYCLE, HM_SURF = baseItems.HM_SURF,
  GUEST_ITEM = { name = "GUEST ITEM" },
}
archive.bindData({ pokemon = withGuestPokemon, moves = withGuestMoves,
  items = withGuestItems })
fresh1.flags = { EVENT_BEAT_CHAMPION_RIVAL = true }
fresh1.hallOfFame = { {} }
fresh1.player.id = 11
fresh1.party = { { species = "GUESTMON", level = 40,
  moves = { "GUEST_MOVE" } } }
fresh1.inventory = { GUEST_ITEM = 2 }
assert(archive.beginJourney(fresh1, legacyMeta()))
local fresh2 = { version = "red", player = { id = 12 }, party = {},
  boxes = { {} }, inventory = {}, pcItems = {}, modData = {} }
ok(archive.seedNewSave(fresh2), "cycle two seeds after a real beginJourney")
ok(archive.markRunStarted(fresh2), "cycle two becomes active")
fresh2.modData.kanto_ascendant.legacy_journey.partnerChosen = true
eq(archive.profile().cycle, 2, "second hand-off advances exactly one cycle")

-- Recreate the archive as a new process with the guest mod absent.
archive = make(basePokemon, baseItems, baseMoves)
local absentRows = archive.availableMons(fresh2)
eq(#absentRows, 1, "removed-mod Pokémon is not paid into the live game")
eq(archive.locker().items.GUEST_ITEM, nil,
  "removed-mod item is not paid into the live bag")
local held = archive.quarantine()
ok(next(held.bank) ~= nil, "removed-mod Pokémon remains byte-complete in quarantine")
eq(held.items.GUEST_ITEM.count, 2,
  "removed-mod item count remains in quarantine")

-- Re-enable the supplier: reconciliation restores the exact rows once.
archive.bindData({ pokemon = withGuestPokemon, moves = withGuestMoves,
  items = withGuestItems })
eq(#archive.availableMons(fresh2), 2,
  "reactivating the supplier restores the quarantined Pokémon")
eq(archive.locker().items.GUEST_ITEM, 2,
  "reactivating the supplier restores the quarantined item")
eq(next(archive.quarantine().bank), nil,
  "successful restore clears the Pokémon quarantine")
eq(archive.quarantine().items.GUEST_ITEM, nil,
  "successful restore clears the item quarantine")

-- Unknown moves quarantine the entire record rather than stripping a move.
archive.bindData({ pokemon = withGuestPokemon, moves = baseMoves,
  items = withGuestItems })
eq(#archive.availableMons(fresh2), 1,
  "a missing move registry entry fail-closes the whole guest Pokémon")
archive.bindData({ pokemon = withGuestPokemon, moves = withGuestMoves,
  items = withGuestItems })
eq(#archive.availableMons(fresh2), 2,
  "restoring the move registry restores the unmodified Pokémon")

fresh2.flags = { EVENT_BEAT_CHAMPION_RIVAL = true }
fresh2.hallOfFame = { {} }
fresh2.player.id = 12
fresh2.party = { { species = "BULBASAUR", level = 44,
  moves = { "TACKLE", "GROWL" } } }
fresh2.inventory = { ANTIDOTE = 3 }
assert(archive.beginJourney(fresh2, legacyMeta()))
local fresh3 = { version = "red", player = { id = 13 }, party = {},
  boxes = { {} }, inventory = {}, pcItems = {}, modData = {} }
ok(archive.seedNewSave(fresh3), "third true journey seeds")
ok(archive.markRunStarted(fresh3), "third journey activates")
fresh3.modData.kanto_ascendant.legacy_journey.partnerChosen = true
eq(archive.profile().cycle, 3, "three beginJourney/new-save cycles accumulate")
eq(#archive.availableMons(fresh3), 3,
  "three cycles retain each distinct archived Pokémon exactly once")
eq(archive.locker().items.POTION, 1,
  "cycle one item count remains exact after three cycles")
eq(archive.locker().items.GUEST_ITEM, 2,
  "cycle two mod item remains exact after three cycles")
eq(archive.locker().items.ANTIDOTE, 3,
  "cycle three item count remains exact")
eq(archive.quarantine().items.BICYCLE, nil,
  "key items do not accumulate anywhere after three cycles")

-- Mega Stones are unique Locker receipts, gated by the current journey's
-- Stone Case and committed against the save-local Mega state. This makes a
-- crash after the game save but before archive finalization recoverable, and
-- an already-owned claim consumes no duplicate.
local claimReady, claimReason = archive.itemClaimStatus(fresh3, "BLAZIKENITE")
eq(claimReady, false, "Mega Stone claim is locked before current-run access")
eq(claimReason, "mega_access_required",
  "Mega Stone lock reports the exact missing prerequisite")
local noCase, noCaseErr = archive.beginItemCheckout(
  fresh3, "BLAZIKENITE", 1)
eq(noCase, nil, "archive API also enforces the Stone Case gate")
ok(tostring(noCaseErr):find("Stone Case", 1, true),
  "Stone Case API denial is actionable")
local currentBucket = fresh3.modData.kanto_ascendant
currentBucket.mega_evolution = {
  ring = true, case = true, stones = {},
}
eq(select(2, archive.itemClaimStatus(fresh3, "BLAZIKENITE")), "ready",
  "Mega Stone becomes claimable after current-run Mega access")
local stoneCheckout = assert(archive.beginItemCheckout(
  fresh3, "BLAZIKENITE", 99))
eq(stoneCheckout.count, 1, "Mega Stone checkout is hard-capped at one")
currentBucket.mega_evolution.stones.BLAZIKENITE = true
assert(archive.completeCheckout(fresh3, stoneCheckout.id))
eq(archive.locker().items.BLAZIKENITE, nil,
  "saved Stone Case receipt transactionally consumes unique Locker stone")

local duplicateArchive = archive.load()
duplicateArchive.locker.items.BLAZIKENITE = 7
assert(archive.write(duplicateArchive))
eq(archive.locker().items.BLAZIKENITE, 1,
  "old duplicate Mega Stone counts reconcile to one unique receipt")
eq(select(2, archive.itemClaimStatus(fresh3, "BLAZIKENITE")),
  "already_owned", "already-owned Stone Case state is idempotently reported")
local duplicateCheckout = assert(archive.beginItemCheckout(
  fresh3, "BLAZIKENITE", 1))
assert(archive.completeCheckout(fresh3, duplicateCheckout.id))
eq(archive.locker().items.BLAZIKENITE, nil,
  "already-owned claim clears receipt without duplicating Stone Case state")
eq(currentBucket.mega_evolution.stones.BLAZIKENITE, true,
  "idempotent claim leaves the single boolean Stone Case entitlement intact")

-- The archive is a dynamic ledger, not one of the engine's finite PC boxes.
-- A large historical population remains visible without a capacity rejection
-- or a display-side truncation, and a transactional deposit appends normally.
local unbounded = archive.load()
for index = #unbounded.bank + 1, 521 do
  unbounded.bank[index] = {
    id = ("UNLIMITED:%04d"):format(index),
    mon = { species = "PIKACHU", level = 5, moves = { "TACKLE" } },
  }
end
assert(archive.write(unbounded))
eq(#archive.availableMons(fresh3), 521,
  "Legacy Pokémon archive has no hidden 240/box capacity truncation")
local deposited = assert(archive.stageDeposit(fresh3,
  { species = "EEVEE", level = 7, moves = { "TACKLE" } }))
assert(archive.completeDeposit(fresh3, deposited))
eq(#archive.availableMons(fresh3), 522,
  "transactional deposit appends beyond 521 archived Pokémon")

print(("LEGACY ARCHIVE INTEGRITY PASS: %d assertions"):format(assertions))
