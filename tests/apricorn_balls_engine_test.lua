-- Real-engine integration contract for the P1 Apricorn Ball package.
-- Run from gen1recomp with the bundled LuaJIT:
--   TRAINER_REMATCH_MOD_DIR=mods/ka_rc11_integration \
--     ./.tools/luajit-src/src/luajit \
--     mods/ka_rc11_integration/tests/apricorn_balls_engine_test.lua

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
local ItemEffects = require("src.inventory.ItemEffects")
local BattleState = require("src.battle.BattleState")
local Runtime = require("src.mods.Runtime")
local Version = require("src.core.Version")
local originalEngineVersion = Version.engine
Version.engine = "0.1.90"

if not (Data.pokemon and Data.pokemon.BULBASAUR) then Data:load() end

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

local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "mods/ka_rc11_integration"
local sdkOpts = { data = Data }
if modPath:sub(1, 1) == "/" then sdkOpts.root = "/" end
local run = T.sdk.loadMod(modPath, sdkOpts)
check(run.mod and run.mod.state == "loaded", "Authority mod loads via real Loader")
eq(#(run.errors or {}), 0, "Loader merge has no errors")
local exports = assert(run.loader.exports.kanto_ascendant)
local apricorn = assert(exports.apricornBalls, "Apricorn runtime exported by main.lua")

local ids = {
  "HEAVY_BALL", "LEVEL_BALL", "LURE_BALL", "FAST_BALL",
  "LOVE_BALL", "FRIEND_BALL", "MOON_BALL",
}
for _, id in ipairs(ids) do
  local item, ball = Data.items[id], Data.balls[id]
  check(item and item.ball == id, id .. " is a merged item-to-ball record")
  check(ball and type(ball.attempt) == "function", id .. " is a merged catch record")
  check(ItemEffects.isBall(id), id .. " goes through the actual BagMenu ball path")
  eq(ItemEffects.use(Data, { player = { name = "RED" } }, id, nil, {}, nil, nil),
    "ball", id .. " is battle-usable through ItemEffects")
end
check(Data.items.GS_BALL == nil and Data.balls.GS_BALL == nil, "GS Ball remains absent")

local coverage = apricorn.validateSpecies(Data)
check(coverage.complete, "live #001-251 weight/speed/gender data are complete")
eq(coverage.species, 251, "live data coverage has exactly 251 species")

-- Exercise BattleState:catchAttempt itself; this reaches the merged
-- content.balls callback and then the engine's Catching.vanillaAttempt.
local function wildBattle(species, playerSpecies, playerLevel, targetLevel, playerAttackDv)
  local target = {
    species = species, level = targetLevel, hp = 100, stats = { hp = 100 },
    dvs = { attack = 0 },
  }
  return setmetatable({
    kind = "wild", data = Data, game = { data = Data },
    player = { mon = { species = playerSpecies or species, level = playerLevel,
      dvs = { attack = playerAttackDv or 15 } } },
    enemy = { mon = target, def = Data.pokemon[species] },
    rng = function() return 0 end,
  }, { __index = BattleState })
end

local heavy = wildBattle("SNORLAX", "BULBASAUR", 20, 20)
local caught, shakes = BattleState.catchAttempt(heavy, "HEAVY_BALL")
eq(heavy.apricornBallQuote.reason, "weight_300kg_plus", "Heavy Ball reads live local weight data")
eq(heavy.apricornBallQuote.rate, 55, "Heavy Ball uses +30 catch-rate rule")
eq(caught, true, "Heavy Ball reaches the real engine roll")
eq(shakes, 3, "real catch roll reports shakes")

local fast = wildBattle("ELECTRODE", "BULBASAUR", 20, 20)
BattleState.catchAttempt(fast, "FAST_BALL")
eq(fast.apricornBallQuote.reason, "base_speed_100_plus", "Fast Ball reads live base Speed")
eq(fast.apricornBallQuote.multiplier, 4, "Fast Ball live positive threshold")
eq(fast.apricornBallQuote.formatted.text,
  "CATCH RATE x4\nBASE SPEED HIGH",
  "real catch callback stores the shared positive display")
local slowFast = wildBattle("SNORLAX", "BULBASAUR", 20, 20)
BattleState.catchAttempt(slowFast, "FAST_BALL")
eq(slowFast.apricornBallQuote.multiplier, 1, "Fast Ball live negative threshold")
eq(slowFast.apricornBallQuote.formatted.text,
  "CATCH RATE x1\nBASE SPEED LOW",
  "real catch callback stores the shared negative display")

local level = wildBattle("PIKACHU", "BULBASAUR", 40, 10)
BattleState.catchAttempt(level, "LEVEL_BALL")
eq(level.apricornBallQuote.multiplier, 8, "Level Ball uses live level ratio")

local love = wildBattle("PIKACHU", "PIKACHU", 20, 20, 15)
BattleState.catchAttempt(love, "LOVE_BALL")
eq(love.apricornBallQuote.multiplier, 8, "Love Ball uses live Gen-II gender data")

local lure = wildBattle("MAGIKARP", "BULBASAUR", 20, 20)
lure.encounterSource = "fishing"
BattleState.catchAttempt(lure, "LURE_BALL")
eq(lure.apricornBallQuote.reason, "fishing", "Lure Ball recognizes native fishing encounter source")
local nonFishingLure = wildBattle("MAGIKARP", "BULBASAUR", 20, 20)
nonFishingLure.fishing = true
BattleState.catchAttempt(nonFishingLure, "LURE_BALL")
eq(nonFishingLure.apricornBallQuote.reason, "not_fishing",
  "Lure Ball rejects a loose non-runtime fishing flag")

local moon = wildBattle("CLEFAIRY", "BULBASAUR", 20, 20)
BattleState.catchAttempt(moon, "MOON_BALL")
eq(moon.apricornBallQuote.multiplier, 4, "Moon Ball uses live Moon-Stone line")
local nonMoon = wildBattle("GASTLY", "BULBASAUR", 20, 20)
BattleState.catchAttempt(nonMoon, "MOON_BALL")
eq(nonMoon.apricornBallQuote.multiplier, 1, "Moon Ball live negative line")

local trainerQuote = apricorn.quote("FAST_BALL", {
  battle = { kind = "trainer" }, targetMon = { species = "ELECTRODE", level = 20 },
  targetDef = Data.pokemon.ELECTRODE, data = Data,
})
eq(trainerQuote.reason, "trainer_battle", "trainer capture is explicitly blocked")
local storyQuote = apricorn.quote("MOON_BALL", {
  battle = { kind = "wild", noCatch = true }, targetMon = { species = "CLEFAIRY", level = 20 },
  targetDef = Data.pokemon.CLEFAIRY, data = Data,
})
eq(storyQuote.reason, "story_blocked", "story capture is explicitly blocked")

-- The custom item effect is called before BagMenu's consume() branch. A
-- trainer/story block must preserve the exact inventory count and not start a
-- throw, while an ordinary wild attempt still returns the stock "ball" flow.
local blockedSave = { inventory = { FAST_BALL = 2 }, player = { name = "RED" } }
local trainerBattle = wildBattle("ELECTRODE", "BULBASAUR", 20, 20)
trainerBattle.kind = "trainer"
local blockedUse, _, blockedExtra = ItemEffects.use(Data, blockedSave,
  "FAST_BALL", nil, trainerBattle)
eq(blockedUse, "failed", "trainer Apricorn item refuses before BagMenu consumption")
eq(blockedSave.inventory.FAST_BALL, 2, "trainer Apricorn refusal preserves Bag count")
eq(blockedExtra.apricornQuote.reason, "trainer_battle", "trainer refusal retains reason")
local noCatchBattle = wildBattle("ELECTRODE", "BULBASAUR", 20, 20)
noCatchBattle.noCatch = true
local noCatchUse, _, noCatchExtra = ItemEffects.use(Data, blockedSave,
  "FAST_BALL", nil, noCatchBattle)
eq(noCatchUse, "failed", "no-catch Apricorn item refuses before consumption")
eq(blockedSave.inventory.FAST_BALL, 2, "no-catch Apricorn refusal preserves Bag count")
eq(noCatchExtra.apricornQuote.reason, "story_blocked", "no-catch refusal retains reason")
check(noCatchExtra.apricornQuote.formatted == nil,
  "no-catch refusal has no bonus display")

local legalBattle = wildBattle("ELECTRODE", "BULBASAUR", 20, 20)
local legalUse, legalMessages, legalExtra = ItemEffects.use(Data, blockedSave,
  "FAST_BALL", nil, legalBattle)
eq(legalUse, "ball", "legal wild use reaches the ball flow")
eq(legalMessages[1], "CATCH RATE x4\nBASE SPEED HIGH",
  "legal wild use returns its visible live quote")
eq(legalExtra.apricornDisplay.text, legalMessages[1],
  "ItemEffects and shared quote API use identical text")

-- Exercise the actual BagMenu branch. The preview is pushed before the Ball
-- is consumed or thrown; dismissing it performs both exactly once. Blocked
-- contexts may print the stock refusal, but never the bonus preview.
local BagMenu = require("src.ui.BagMenu")
local function bagFlow(battle, itemId)
  itemId = itemId or "FAST_BALL"
  local states, thrown = {}, nil
  local save = { inventory = { [itemId] = 2 }, bagOrder = { itemId },
    money = 0, player = { name = "RED" } }
  local game = { data = Data, save = save }
  game.stack = {
    top = function() return states[#states] end,
    push = function(_, state) states[#states + 1] = state; return state end,
    pop = function() return table.remove(states) end,
  }
  battle.game = game
  battle.throwBall = function(_, id) thrown = id end
  local list = BagMenu.new(game, { battle = battle })
  game.stack:push(list)
  list.onChoose(list.items[1], list)
  return game, save, function() return thrown end, states, list
end
local bagGame, bagSave, bagThrown, bagStates = bagFlow(
  wildBattle("ELECTRODE", "BULBASAUR", 20, 20))
local preview = bagGame.stack:top()
check(preview and preview.pages and preview.pages[1],
  "BagMenu pushes a real TextBox preview")
eq(table.concat(preview.pages[1], "\n"),
  "CATCH RATE x4\nBASE SPEED HIGH",
  "BagMenu TextBox contains bonus and reason")
eq(bagSave.inventory.FAST_BALL, 2,
  "ball remains in Bag while the quote is visible")
eq(bagThrown(), nil, "ball is not thrown before quote dismissal")
bagGame.stack:pop()
preview.onDone()
eq(bagSave.inventory.FAST_BALL, 1,
  "quote dismissal consumes exactly one ball")
eq(bagThrown(), "FAST_BALL", "quote dismissal throws the selected ball")

local _, vanillaSave, vanillaThrown, vanillaStates = bagFlow(
  wildBattle("PIDGEY", "BULBASAUR", 20, 20), "POKE_BALL")
eq(#vanillaStates, 0, "vanilla Ball keeps the immediate stock Bag path")
eq(vanillaSave.inventory.POKE_BALL, 1,
  "vanilla Ball still consumes immediately")
eq(vanillaThrown(), "POKE_BALL",
  "vanilla Ball still throws immediately without an Apricorn preview")

for _, blocked in ipairs({
  (function() local b = wildBattle("ELECTRODE", "BULBASAUR", 20, 20)
    b.kind = "trainer"; return b end)(),
  (function() local b = wildBattle("ELECTRODE", "BULBASAUR", 20, 20)
    b.noCatch = true; return b end)(),
}) do
  local game, save, thrown = bagFlow(blocked)
  local refusal = game.stack:top()
  local visible = refusal and refusal.pages and refusal.pages[1]
    and table.concat(refusal.pages[1], "\n") or ""
  check(not visible:find("CATCH RATE", 1, true),
    "blocked Bag use never displays an Apricorn bonus")
  eq(save.inventory.FAST_BALL, 2,
    "blocked Bag use preserves inventory")
  eq(thrown(), nil, "blocked Bag use never throws")
end

-- The compatibility wrapper is process-stable: hot import only refreshes
-- its bridge, while restore either removes a directly owned wrapper or
-- safely disables one that later Ascendant wrappers have layered above.
local previewState = assert(apricorn.stockBagPreview0186,
  "stock 0.1.90 Apricorn Bag bridge is installed")
local beforeRefresh = BagMenu.new
local refreshed, refreshMode = apricorn.refreshStock0186BagPreview()
eq(refreshed, true, "0.1.90 Bag bridge refresh succeeds")
eq(refreshMode, "refreshed", "hot import reuses the existing Bag bridge")
eq(BagMenu.new, beforeRefresh, "hot import does not stack a Bag constructor")
eq(apricorn.stockBagPreview0186, previewState,
  "hot import preserves the process-stable bridge state")
Version.engine = "0.1.91"
local forwardRefreshed, forwardMode = apricorn.refreshStock0186BagPreview()
eq(forwardRefreshed, true,
  "minimum-engine contract keeps the guarded Bag bridge forward active")
eq(forwardMode, "refreshed",
  "forward-compatible Bag refresh does not stack a constructor")
Version.engine = "0.1.90"
local restored, restoreReason = previewState.restore()
if restored then
  eq(BagMenu.new, previewState.originalNew,
    "direct bridge restore recovers the exact prior constructor")
else
  eq(restoreReason, "not_direct_owner",
    "buried bridge restore refuses to clobber a later wrapper")
  eq(BagMenu.new, beforeRefresh,
    "buried bridge restore preserves the later wrapper chain")
end
local reactivated, reactivateMode = apricorn.refreshStock0186BagPreview()
eq(reactivated, true, "restored Bag bridge can be reactivated")
eq(reactivateMode, restored and "installed" or "refreshed",
  "reactivation follows the owned-wrapper topology")
local _, reactivatedSave, reactivatedThrown, reactivatedStates = bagFlow(
  wildBattle("ELECTRODE", "BULBASAUR", 20, 20))
check(reactivatedStates[#reactivatedStates]
    and reactivatedStates[#reactivatedStates].pages,
  "reactivated bridge still displays the Apricorn preview")
eq(reactivatedSave.inventory.FAST_BALL, 2,
  "reactivated preview still preserves the ball before dismissal")
eq(reactivatedThrown(), nil,
  "reactivated preview still delays the throw")

-- The Loader-installed event bus is the same bus BattleState.storeCaughtMon
-- emits after the party/PC destination has been decided.
local pcMon = { species = "CLEFAIRY", johtoBond = 0,
  eventDistribution = { id = "APRICON_TEST" } }
local capturedGame = { data = Data, save = { party = {}, options = { modOptions = {} } } }
Runtime.emit("pokemon.caught", { ball = "FRIEND_BALL", mon = pcMon,
  destination = "box", game = capturedGame })
eq(pcMon.johtoBond, 200, "Friend Ball awards only after successful PC capture")
Runtime.emit("pokemon.caught", { ball = "FRIEND_BALL", mon = pcMon,
  destination = "box", game = capturedGame })
eq(pcMon.johtoBond, 200, "Friend Ball reward is idempotent")

-- The pocket/sort and PC-order exports are the actual bundled Useful Bag
-- helpers enabled by main.lua.  Dynamic `item.ball` works even without the
-- fallback list; the explicit ids protect older order-only saves too.
eq(exports.classify(Data, "FAST_BALL"), "balls", "Bag pocket classifies Fast Ball")
local save = { inventory = { POTION = 1, FAST_BALL = 2 },
  bagOrder = { "POTION", "FAST_BALL" }, pcItems = { MOON_BALL = 1 } }
local pocket = exports.pocketItems(save.bagOrder, Data, "balls")
eq(pocket[1], "FAST_BALL", "Bag pocket projection retains Apricorn Ball")
eq(exports.pcOrder(save)[1], "MOON_BALL", "PC order retains Apricorn Ball")
exports.applySort(save, Data, "name")
eq(save.bagOrder[1], "FAST_BALL", "normal bag sort uses registered item names")

local itemHelp = assert(exports.itemHelp)
check(itemHelp.describe({ data = Data }, "MOON_BALL"):find("Moon Stone", 1, true),
  "item-help exposes Moon Ball rule")
check(run.loader.modSave.kanto_ascendant
  and run.loader.modSave.kanto_ascendant.apricorn_balls
  and run.loader.modSave.kanto_ascendant.apricorn_balls.version == 1,
  "Apricorn save migration initializes through real mod.save")

run.release()
Version.engine = originalEngineVersion
print("apricorn_balls_engine_test: PASS (" .. checks .. " checks)")
