-- Focused Kanto Ascendant 5.0 field-tech and Frontier economy regression.
--
-- Run from the Gen1 Recomp checkout:
--   TRAINER_REMATCH_MOD_DIR=../kanto_ascendant \
--   POKEPORT_DATA_DIR=tests/fixture_data \
--   ./.tools/luajit-src/src/luajit \
--   ../kanto_ascendant/tests/field_economy_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local Data = T.fixtures.load()
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR")
  or "mods/kanto_ascendant"
local run = T.sdk.loadMod(modPath, { data = Data })
T.eq(#run.errors, 0, "Kanto Ascendant loads for field-economy tests")

local exports = run.loader.exports.kanto_ascendant
local tech = assert(exports.fieldTech)
local mega = assert(exports.megaEvolution)
T.neq(exports.frontierExchange, nil,
  "main exports the integrated Frontier Exchange")
T.eq(exports.frontierExchange.walletReady(), true,
  "the integrated Exchange receives Ascendant's clean wallet API")
local Bag = require("src.inventory.Bag")

local function gameWithInventory(inventory)
  return {
    data = Data,
    save = {
      player = { name = "RED", id = 151 },
      party = {}, inventory = inventory or {}, flags = {},
      hallOfFame = { {} }, pokedex = { seen = {}, owned = {} },
    },
  }
end

local function fullBag(keepKit)
  local inventory = {}
  if keepKit then inventory.FIELD_KIT = 1 end
  local remaining = Bag.capacity(Data) - (keepKit and 1 or 0)
  for index = 1, remaining do
    inventory[("FULL_SLOT_%02d"):format(index)] = 1
  end
  return inventory
end

-- Current-run Key Items are idempotent grants, not Legacy Locker counts. A
-- migrated save may have the inventory receipt but lack the mod-state bit;
-- repeated milestone or Route-5 callbacks must adopt it without duplicating.
run.loader.modSave = {}
local keyItemGame = gameWithInventory({
  FIELD_KIT = 1, MEGA_RING = 1, MEGA_STONE_CASE = 1,
})
tech.afterRematch(keyItemGame)
tech.afterRematch(keyItemGame)
T.eq(keyItemGame.save.inventory.FIELD_KIT, 1,
  "repeated rematch milestones never duplicate the Field Kit")
T.eq(tech.state().kit, true,
  "an existing Field Kit repairs its missing current-run state receipt")
mega.unlock(keyItemGame)
mega.unlock(keyItemGame)
T.eq(keyItemGame.save.inventory.MEGA_RING, 1,
  "repeated Mega unlock callbacks never duplicate the Mega Ring")
T.eq(keyItemGame.save.inventory.MEGA_STONE_CASE, 1,
  "repeated Mega unlock callbacks never duplicate the Stone Case")

-- Version-1 migration retains the blocked reward and removes only the
-- historical phantom first cycle.
run.loader.modSave = {
  kanto_ascendant = {
    field_tech = {
      version = 1, kit = true, rematchWins = 8, tmWins = 6,
      tmCursor = 1, tmCycles = 1, pendingTM = "TM_LEGACY",
      signatureUnlocked = { TM_FRENZY_PLANT = true },
      signatureAwarded = {},
    },
  },
}
local migrated = tech.state()
T.eq(migrated.version, 2, "field-tech save migrates to FIFO schema v2")
T.same(migrated.pendingTMs, { "TM_LEGACY", "TM_FRENZY_PLANT" },
  "legacy archive and failed Crown rewards migrate into FIFO order")
T.eq(migrated.signatureAwarded.TM_FRENZY_PLANT, true,
  "an old failed Crown hand-off becomes a permanent entitlement")
T.eq(migrated.pendingTM, nil, "legacy singleton pending field is retired")
T.eq(migrated.tmCycles, 0,
  "migration removes the old false first-cycle count")

-- A full Bag never freezes the win clock. Every second win queues another
-- concrete TM in deterministic order.
Data.items.TM_QUEUE_TEST_2 = {
  id = "TM_QUEUE_TEST_2", name = "TM02 TEST", price = 0,
  machine = { kind = "TM", move = "FIX_TACKLE", number = 2 },
}
Data.items.TM_QUEUE_TEST_3 = {
  id = "TM_QUEUE_TEST_3", name = "TM03 TEST", price = 0,
  machine = { kind = "TM", move = "FIX_EMBERISH", number = 3 },
}
run.loader.modSave = {}
local queueGame = gameWithInventory(fullBag(true))
local queueState = tech.state()
queueState.kit = true
queueState.tmWins = 1
tech.afterRematch(queueGame)
local pool = tech.renewableTMs(queueGame)
T.eq(queueState.tmWins, 2, "a full Bag still advances TM-archive wins")
T.eq(queueState.tmCursor, 1, "the first reward advances the archive cursor")
T.eq(queueState.tmCycles, 0,
  "the first archived TM is not a completed cycle")
T.same(queueState.pendingTMs, { pool[1].id },
  "the blocked first TM enters the FIFO")
T.eq(queueState.archivedTMs[pool[1].id], true,
  "a reserved entitlement counts as archived")

tech.afterRematch(queueGame)
tech.afterRematch(queueGame)
T.eq(queueState.tmWins, 4,
  "wins keep counting while an older TM remains reserved")
T.same(queueState.pendingTMs, { pool[1].id, pool[2].id },
  "later rewards wait behind older TMs in deterministic FIFO order")

queueGame.save.inventory.FULL_SLOT_01 = nil
tech.afterRematch(queueGame)
T.eq(queueGame.save.inventory[pool[1].id], 1,
  "the oldest queued TM auto-delivers when one Bag slot opens")
T.same(queueState.pendingTMs, { pool[2].id },
  "auto-delivery removes only the FIFO head when the Bag fills again")
queueGame.save.inventory.FULL_SLOT_02 = nil
local claimed, claimCount = tech.claimPendingTMs(queueGame)
T.eq(claimCount, 1, "the Route 5 archive claim delivers waiting TMs")
T.eq(queueGame.save.inventory[pool[2].id], 1,
  "the explicit claim preserves FIFO order")
T.eq(#queueState.pendingTMs, 0, "the delivered FIFO becomes empty")

-- Imported saves may carry only the story flag instead of a serialized Hall
-- of Fame entry. They still participate in the postgame TM archive.
run.loader.modSave = {}
local flagOnlyGame = gameWithInventory({})
flagOnlyGame.save.hallOfFame = {}
flagOnlyGame.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
local flagOnlyState = tech.state()
flagOnlyState.kit = true
flagOnlyState.tmWins = 1
tech.afterRematch(flagOnlyGame)
T.eq(flagOnlyState.tmWins, 2,
  "the Champion story flag alone unlocks postgame TM-archive progress")

-- A cycle completes only when the last pool entry wraps to the first.
run.loader.modSave = {}
queueState = tech.state()
queueState.kit = true
queueGame = gameWithInventory({})
pool = tech.renewableTMs(queueGame)
queueState.tmCursor = #pool
queueState.tmCycles = 0
queueState.tmWins = 5
queueGame.save.inventory.FULL_SLOT_03 = nil
tech.afterRematch(queueGame)
T.eq(queueState.tmCursor, 1, "the archive wraps after its final TM")
T.eq(queueState.tmCycles, 1,
  "a true last-to-first wrap records exactly one completed cycle")
T.eq(tech.nextArchiveTM(queueGame).id, pool[2].id,
  "the status API exposes the next concrete TM")

-- Signature TMs become permanent entitlements even when their Crown reward
-- cannot enter the Bag at the time.
run.loader.modSave = {}
local signatureGame = gameWithInventory(fullBag(false))
local signatureState = tech.state()
signatureState.kit = true
local signatureText = tech.afterBossWin(signatureGame, "erika", "crown")
T.eq(type(signatureText), "string",
  "a full-Bag Crown reward still produces a visible reservation")
T.eq(signatureState.signatureAwarded.TM_FRENZY_PLANT, true,
  "the one-time Crown entitlement is recorded immediately")
T.same(signatureState.pendingTMs, { "TM_FRENZY_PLANT" },
  "TM51 uses the same persistent FIFO as archive rewards")
signatureGame.save.inventory.FULL_SLOT_01 = nil
local signatureClaim, signatureCount =
  tech.claimPendingTMs(signatureGame)
T.eq(signatureCount, 1, "the Route 5 machine can claim a reserved TM51")
T.eq(signatureGame.save.inventory.TM_FRENZY_PLANT, 1,
  "the reserved signature TM reaches the Bag without another Crown win")

-- The Move Reminder offers level-up moves, exact event provenance and
-- per-mon move memory, but never arbitrary compatible TMs.
local reminderGame = gameWithInventory({})
local mon = {
  species = "FIXMON_A", level = 10,
  moves = {
    { id = "FIX_TACKLE", pp = 35 },
    { id = "FIX_EMBERISH", pp = 20 },
    { id = "CUT", pp = 30 },
    { id = "FLY", pp = 15 },
  },
  eventDistribution = { originalMoves = { "FIX_SCRATCH" } },
}
local reminder = tech.reminderMoves(reminderGame, mon)
local reminderSet = {}
for _, row in ipairs(reminder) do reminderSet[row.id] = row.source end
T.eq(reminderSet.FIX_SCRATCH, "event",
  "event provenance unlocks that move for this exact Pokémon")
T.eq(reminderSet.THUNDER, nil,
  "ordinary TM compatibility does not create free Reminder moves")
local remembered = tech.rememberMove(
  reminderGame, mon, "FIX_SCRATCH", 1)
T.eq(remembered, true, "the Reminder can replace one of four moves")
T.eq(mon.moves[1].id, "FIX_SCRATCH",
  "the selected move occupies the chosen slot")
T.eq(mon.rememberedMoves.FIX_TACKLE, true,
  "the replaced move is retained as per-Pokémon evidence")
T.eq(tech.forgetMove({ moves = { { id = "SURF" } } }, 1), false,
  "the final-move safeguard remains active")

-- Frontier Exchange: clean wallet API, research gates, renewable items,
-- archived-TM selection and no points loss on a full Bag.
run.loader.modSave = {}
local exchangeGame = gameWithInventory({})
local fieldState = tech.state()
fieldState.archivedTMs = {}
fieldState.archiveSeeded = true
local firstTM = tech.renewableTMs(exchangeGame)[1]
fieldState.archivedTMs[firstTM.id] = true

local points = 30
local wallet = {
  getFrontierPoints = function() return points end,
  spendFrontierPoints = function(amount)
    if points < amount then return false end
    points = points - amount
    return true
  end,
}
local researchState = {
  itemsClaimed = { ["3:SUN_STONE"] = true },
}
local research = { state = function() return researchState end }
local makeExchange =
  assert(loadfile(modPath .. "/frontier_exchange.lua"))()
local exchangeSave = {}
local exchangeMod = {
  save = {
    get = function(_, key) return exchangeSave[key] end,
    set = function(_, key, value) exchangeSave[key] = value end,
  },
  hooks = { wrap = function() end },
  ui = {},
}
local exchange = makeExchange(exchangeMod, {
  wallet = wallet, johtoResearch = research, fieldTech = tech,
})
T.eq(exchange.walletReady(), true,
  "the Exchange recognizes the clean Frontier wallet API")
T.eq(exchange.available(exchangeGame), true,
  "without a Crown controller, Hall of Fame unlocks the Exchange")
T.eq(exchange.researchItemUnlocked("SUN_STONE"), true,
  "the matching Elm milestone unlocks renewable Sun Stones")
T.eq(exchange.researchItemUnlocked("KINGS_ROCK"), false,
  "later evolution items remain research-gated")

local locked, lockedText =
  exchange.buyEvolutionItem(exchangeGame, "KINGS_ROCK")
T.eq(locked, false, "a locked research item cannot be purchased")
T.eq(points, 30, "a locked purchase spends no Frontier Points")
local boughtSun = exchange.buyEvolutionItem(exchangeGame, "SUN_STONE")
T.eq(boughtSun, true, "an unlocked evolution item is renewable")
T.eq(exchangeGame.save.inventory.SUN_STONE, 1,
  "the purchased evolution item enters the Bag")
T.eq(points, 24, "Sun Stone uses its documented six-point price")

local boughtTM = exchange.buyArchivedTM(exchangeGame, firstTM.id)
T.eq(boughtTM, true, "an earned archive TM can be selected again")
T.eq(points, 21, "an archived TM costs three Frontier Points")
local unknownTM = tech.renewableTMs(exchangeGame)[2].id
local deniedTM = exchange.buyArchivedTM(exchangeGame, unknownTM)
T.eq(deniedTM, false, "an unearned TM cannot be selected early")
T.eq(points, 21, "an unarchived TM attempt spends no points")

researchState.itemsClaimed["7:KINGS_ROCK"] = true
exchangeGame.save.inventory = fullBag(false)
exchangeGame.save.bagOrder = nil
local beforeFullPurchase = points
local fullPurchase = exchange.buyEvolutionItem(exchangeGame, "KINGS_ROCK")
T.eq(fullPurchase, false, "a full Bag rejects the Exchange purchase")
T.eq(points, beforeFullPurchase,
  "a full-Bag rejection never consumes Frontier Points")

local disconnected = makeExchange(exchangeMod, {
  johtoResearch = research, fieldTech = tech,
})
T.eq(disconnected.walletReady(), false,
  "the Exchange reports a missing Ascendant wallet instead of editing its save")
T.eq(disconnected.available(exchangeGame), false,
  "an unconnected wallet never exposes the Exchange")

local crownState = { crownChampion = false }
local crownExchange = makeExchange(exchangeMod, {
  wallet = wallet, johtoResearch = research, fieldTech = tech,
  postgame = { state = function() return crownState end },
})
points = 0
T.eq(crownExchange.available(exchangeGame), false,
  "a connected authored progression hides the Exchange before Crown")
crownState.crownChampion = true
T.eq(crownExchange.available(exchangeGame), true,
  "Crown Champion unlocks both Ascendant-menu and Route 5 access")

run.release()
T.finish("field_economy")
