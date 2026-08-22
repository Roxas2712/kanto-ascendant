-- Exact 0.1.96/0.1.98 battle-Bag regression for the POKe FLUTE.
--
-- Run from a pinned Gen1Recomp root with:
--   KA_EXPECT_ENGINE=0.1.96 KA_EXPECT_EDITION=red \
--   KANTO_ASCENDANT_MOD_DIR=/absolute/path/to/kanto-ascendant \
--     luajit /absolute/path/to/this/test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

love = love or require("tests.love_stub")
package.loaded["src.core.Sound"] = {
  play = function() end,
  playCry = function() end,
}

local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
local edition = assert(os.getenv("KA_EXPECT_EDITION"),
  "KA_EXPECT_EDITION is required")
local modDir = assert(os.getenv("KANTO_ASCENDANT_MOD_DIR"),
  "KANTO_ASCENDANT_MOD_DIR is required")

local Version = require("src.core.Version")
local GameVersion = require("src.core.GameVersion")
assert(expectedEngine == "0.1.96" or expectedEngine == "0.1.98",
  "unexpected engine " .. tostring(expectedEngine))
assert(edition == "red" or edition == "blue" or edition == "yellow",
  "unexpected edition " .. tostring(edition))
assert(Version.engine == expectedEngine,
  ("wrong engine: got %s expected %s"):format(
    tostring(Version.engine), expectedEngine))
GameVersion.set(edition)

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, "FAIL: " .. message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, "FAIL: " .. message .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end
local function row(menu, value)
  for _, candidate in ipairs(menu.items or {}) do
    if candidate.value == value then return candidate end
  end
end

-- Pin the engine-side premise rather than silently replacing it in KASC:
-- both supported engines already implement the vanilla link-item seal.
local linkFile = assert(io.open("src/link/LinkBattle.lua", "rb"))
local linkSource = assert(linkFile:read("*a"))
linkFile:close()
check(linkSource:find("self.openItems = function", 1, true) ~= nil
    and linkSource:find("Items can't be", 1, true) ~= nil,
  "the exact engine retains its no-items Classic Link boundary")

local Data = {
  items = {
    POKE_FLUTE = { id = "POKE_FLUTE", name = "POKe FLUTE",
      keyItem = true, pocket = "KEY_ITEM" },
    TOWN_MAP = { id = "TOWN_MAP", name = "TOWN MAP",
      keyItem = true, pocket = "KEY_ITEM" },
    BICYCLE = { id = "BICYCLE", name = "BICYCLE",
      keyItem = true, pocket = "KEY_ITEM" },
    ITEMFINDER = { id = "ITEMFINDER", name = "ITEMFINDER",
      keyItem = true, pocket = "KEY_ITEM" },
    X_ATTACK = { id = "X_ATTACK", name = "X ATTACK", pocket = "ITEM" },
    TM_THUNDER_WAVE = { id = "TM_THUNDER_WAVE", name = "TM45",
      machine = { kind = "TM", move = "THUNDER_WAVE" }, pocket = "TM_HM" },
  },
  moves = { THUNDER_WAVE = { id = "THUNDER_WAVE", name = "THUNDER WAVE" } },
  pokemon = {},
  text = {},
}

local registeredScreen
local ready
local mod = {
  id = "kanto_ascendant",
  exports = {},
  content = { screens = { override = function(_, id, factory)
    eq(id, "BagMenu", "Useful Bag registers the production Bag screen")
    registeredScreen = factory
  end } },
  events = { on = function(_, name, fn)
    if name == "game.ready" then ready = fn end
  end },
}
assert(loadfile(modDir .. "/useful_bag.lua"))()(mod)
check(registeredScreen ~= nil and ready ~= nil,
  "the integrated pocket Bag installs through its production entry point")

local function makeGame(inventory, order, party)
  local states = {}
  local game = {
    data = Data,
    save = {
      player = { name = "RED" },
      inventory = inventory,
      bagOrder = order,
      party = party or {},
      money = 0,
      flags = {},
    },
    input = {
      edge = nil,
      wasPressed = function(self, action) return self.edge == action end,
      isDown = function() return false end,
    },
  }
  game.stack = {
    states = states,
    push = function(_, state)
      states[#states + 1] = state
      return state
    end,
    pop = function() return table.remove(states) end,
    top = function() return states[#states] end,
  }
  return game
end

local function pushBattleBag(game, battle)
  local bag = registeredScreen.new(game, { battle = battle })
  game.stack:push(bag)
  return bag
end

local function tap(menu, key)
  menu.game.input.edge = key
  menu:update(0)
  menu.game.input.edge = nil
end

local function hasVisible(menu, value)
  return row(menu, value) ~= nil
end

local function cycleNeverShows(menu, value)
  for _ = 1, 12 do
    if hasVisible(menu, value) then return false end
    tap(menu, "right")
  end
  return not hasVisible(menu, value)
end

-- Ordinary trainer/wild battles: POKe FLUTE is the sole vanilla Key Item
-- that may enter the battle projection. It wakes every sleeper, spends the
-- turn only on a successful wake, and is never consumed.
local partyActive = { species = "PIKACHU", status = "SLP" }
local partyBench = { species = "SNORLAX", status = "SLP" }
local enemyActive = { species = "GASTLY", status = "SLP" }
local enemyBench = { species = "HAUNTER", status = "SLP" }
local ordinaryGame = makeGame({
  TOWN_MAP = 1, BICYCLE = 1, ITEMFINDER = 1, POKE_FLUTE = 1,
  TM_THUNDER_WAVE = 1,
}, { "TOWN_MAP", "BICYCLE", "ITEMFINDER", "POKE_FLUTE",
  "TM_THUNDER_WAVE" }, { partyActive, partyBench })
local turnUses = 0
local ordinaryBattle = {
  kind = "trainer",
  player = { mon = partyActive },
  enemy = { mon = enemyActive },
  enemyParty = { enemyActive, enemyBench },
  itemUsed = function() turnUses = turnUses + 1 end,
}
local ordinaryBag = pushBattleBag(ordinaryGame, ordinaryBattle)
eq(ordinaryBag.title, "KEY ITEMS",
  "only a legal POKe FLUTE makes the battle Key Items pocket available")
eq(#ordinaryBag.items, 1,
  "unusable Key Items and TMs stay out of the battle projection")
eq(ordinaryBag.items[1].value, "POKE_FLUTE",
  "the owned POKe FLUTE is visible in the battle Key Items pocket")
ordinaryBag.onChoose(ordinaryBag.items[1], ordinaryBag)
eq(ordinaryGame.save.inventory.POKE_FLUTE, 1,
  "successful battle POKe FLUTE use never consumes the Key Item")
eq(turnUses, 0, "the battle turn waits for the flute messages to finish")
for _, witness in ipairs({ partyActive, partyBench, enemyActive, enemyBench }) do
  eq(witness.status, nil, "successful POKe FLUTE wakes every battle sleeper")
end
local fluteText = ordinaryGame.stack:top()
check(fluteText and type(fluteText.onDone) == "function",
  "successful POKe FLUTE use follows the engine message callback")
fluteText.onDone()
eq(turnUses, 1, "successful POKe FLUTE use spends exactly one battle turn")
eq(ordinaryGame.save.inventory.POKE_FLUTE, 1,
  "message completion still cannot consume the POKe FLUTE")

-- With nobody asleep, vanilla reports no effect: Bag stays open underneath
-- the message, no turn is spent, and the Key Item remains owned.
local awake = { species = "PIKACHU" }
local awakeEnemy = { species = "RATTATA" }
local noEffectGame = makeGame({ POKE_FLUTE = 1 }, { "POKE_FLUTE" }, { awake })
local noEffectTurns = 0
local noEffectBattle = {
  kind = "wild", player = { mon = awake }, enemy = { mon = awakeEnemy },
  enemyParty = { awakeEnemy },
  itemUsed = function() noEffectTurns = noEffectTurns + 1 end,
}
local noEffectBag = pushBattleBag(noEffectGame, noEffectBattle)
noEffectBag.onChoose(assert(row(noEffectBag, "POKE_FLUTE")), noEffectBag)
eq(noEffectGame.save.inventory.POKE_FLUTE, 1,
  "no-effect POKe FLUTE use preserves ownership")
eq(noEffectTurns, 0, "no-effect POKe FLUTE use does not spend a turn")
eq(noEffectGame.stack.states[1], noEffectBag,
  "no-effect POKe FLUTE keeps the battle Bag open under its message")

-- B cancellation is side-effect free: no wake, use, or consumption.
local cancelMon = { species = "PIKACHU", status = "SLP" }
local cancelEnemy = { species = "GASTLY", status = "SLP" }
local cancelGame = makeGame({ POKE_FLUTE = 1 }, { "POKE_FLUTE" }, { cancelMon })
local cancelTurns, cancelCallbacks = 0, 0
local cancelBattle = {
  kind = "trainer", player = { mon = cancelMon }, enemy = { mon = cancelEnemy },
  enemyParty = { cancelEnemy },
  itemUsed = function() cancelTurns = cancelTurns + 1 end,
}
local cancelBag = registeredScreen.new(cancelGame, {
  battle = cancelBattle,
  onCancel = function() cancelCallbacks = cancelCallbacks + 1 end,
})
cancelGame.stack:push(cancelBag)
tap(cancelBag, "b")
eq(cancelGame.stack:top(), nil, "B closes the battle Bag")
eq(cancelCallbacks, 1, "B preserves the engine's battle-Bag cancel callback")
eq(cancelMon.status, "SLP", "B cancellation does not wake the party")
eq(cancelEnemy.status, "SLP", "B cancellation does not wake the opponent")
eq(cancelTurns, 0, "B cancellation spends no battle turn")
eq(cancelGame.save.inventory.POKE_FLUTE, 1,
  "B cancellation cannot consume the POKe FLUTE")

-- Link battles are globally itemless in the exact engine. Even a direct
-- registered-screen construction (bypassing LinkBattle.openItems) must not
-- expose the newly admitted Key Item.
local linkMon = { species = "PIKACHU", status = "SLP" }
local linkEnemy = { species = "GASTLY", status = "SLP" }
local linkGame = makeGame({ POKE_FLUTE = 1, TOWN_MAP = 1 },
  { "POKE_FLUTE", "TOWN_MAP" }, { linkMon })
local linkBag = pushBattleBag(linkGame, {
  kind = "link", player = { mon = linkMon }, enemy = { mon = linkEnemy },
  enemyParty = { linkEnemy },
})
check(cycleNeverShows(linkBag, "POKE_FLUTE"),
  "Classic Link never exposes POKe FLUTE through a direct Bag path")
eq(linkMon.status, "SLP", "link Bag navigation cannot mutate the party")
eq(linkEnemy.status, "SLP", "link Bag navigation cannot mutate the peer")
eq(linkGame.save.inventory.POKE_FLUTE, 1,
  "link Bag navigation cannot consume the POKe FLUTE")

-- 6.5's explicit no-item battle marker remains sealed. World Rank's separate
-- policy module is a 6.7-only feature and is intentionally not backported.
local sealedMon = { species = "PIKACHU", status = "SLP" }
local sealedEnemy = { species = "GASTLY", status = "SLP" }
local sealedGame = makeGame({ POKE_FLUTE = 1, TOWN_MAP = 1 },
  { "POKE_FLUTE", "TOWN_MAP" }, { sealedMon })
local sealedBag = pushBattleBag(sealedGame, {
  kind = "trainer", ascendantNoItems = true,
  player = { mon = sealedMon }, enemy = { mon = sealedEnemy },
  enemyParty = { sealedEnemy },
})
check(cycleNeverShows(sealedBag, "POKE_FLUTE"),
  "explicit no-item battles never expose POKe FLUTE")
eq(sealedMon.status, "SLP", "sealed Bag navigation cannot wake the party")
eq(sealedEnemy.status, "SLP", "sealed Bag navigation cannot wake the opponent")
eq(sealedGame.save.inventory.POKE_FLUTE, 1,
  "sealed Bag navigation cannot consume the POKe FLUTE")

print(("battle_pokeflute_keyitems_engine_test: PASS engine=%s edition=%s checks=%d")
  :format(expectedEngine, edition, checks))
