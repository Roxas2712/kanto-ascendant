local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local source = debug.getinfo(1, "S").source
local testFile = source:sub(1, 1) == "@" and source:sub(2) or source
local modRoot = testFile:match("^(.*)[/\\]tests[/\\][^/\\]+$") or "."
local fsRoot = modRoot:sub(1, 1) == "/" and "/" or "."

local T = require("tests.modkit")
local Data = require("src.core.Data")
local ItemEffects = require("src.inventory.ItemEffects")
local Serializer = require("src.core.SaveSerializer")

Data:load()
local run = T.sdk.loadMod(modRoot, { data = Data, root = fsRoot })
assert(run.mod, "Kanto Ascendant did not load: "
  .. table.concat(run.errors or {}, " | "))
assert(#(run.errors or {}) == 0, table.concat(run.errors, " | "))

local api = assert(run.loader.exports.kanto_ascendant,
  "Kanto Ascendant exports are unavailable")
local wanderers = assert(api.legacyWanderers,
  "Legacy Wanderers export is unavailable")
local game = {
  data = Data,
  save = {
    player = { name = "AUDIT" }, party = {},
    inventory = {}, bagOrder = {}, pcItems = {}, pcOrder = {},
  },
}

local counts = { [2] = 0, [3] = 0 }
local ironTail
for _, row in ipairs(wanderers.registeredTMs(game)) do
  counts[row.generation] = (counts[row.generation] or 0) + 1
  if row.item == "TM_IRON_TAIL" then ironTail = row end
end
assert(ironTail, "TM_IRON_TAIL is absent from the live Wanderer pool")
assert(ironTail.move == "IRON_TAIL" and ironTail.number == 23
    and ironTail.generation == 2,
  "TM_IRON_TAIL is not the functional Generation-II TM23")
assert(counts[2] > 0 and counts[3] > 0,
  "both Johto and Hoenn machine pools must be nonempty")

local witnesses, witnessSet = {}, {}
for id, def in pairs(Data.pokemon) do
  for _, move in ipairs(def.tmhm or {}) do
    if move == "IRON_TAIL" then
      witnesses[#witnesses + 1], witnessSet[id] = id, true
      break
    end
  end
end
table.sort(witnesses)
for _, id in ipairs({
    "FORRETRESS", "PINECO", "SCIZOR", "SKARMORY", "STEELIX",
  }) do
  assert(witnessSet[id], id .. " lost live TM23 compatibility")
end

local target = {
  species = "STEELIX", moves = { { id = "TACKLE", pp = 35 } },
}
local teachResult, taughtMove = ItemEffects.use(
  Data, game.save, "TM_IRON_TAIL", target)
assert(teachResult == "learn" and taughtMove == "IRON_TAIL",
  "TM23 did not enter the native machine teaching flow")

local reward
for _, row in ipairs(wanderers.rewardPool(game)) do
  if row.item == "TM_IRON_TAIL" then reward = row break end
end
assert(reward and reward.kind == "tm" and reward.generation == 2,
  "TM23 is not a selectable Johto Wanderer reward")

local state = { rewardedTokens = {}, pendingRewards = {}, rotation = {} }
assert(wanderers.grantReward(game, state, reward, "tm23-bag") == "bag",
  "TM23 did not use the Wanderer Bag path")
assert(game.save.inventory.TM_IRON_TAIL == 1,
  "TM23 Bag quantity is not exactly one")
local saved = Serializer.decode(Serializer.encode(game.save))
assert(saved.inventory.TM_IRON_TAIL == 1,
  "Bag TM23 did not survive SaveSerializer")

game.data.constants.bagSize = 1
game.save.inventory, game.save.bagOrder = { POTION = 1 }, { "POTION" }
game.save.pcItems, game.save.pcOrder = {}, {}
assert(wanderers.grantReward(game, state, reward, "tm23-pc") == "pc",
  "a full Bag did not send TM23 to the PC")
assert(game.save.pcItems.TM_IRON_TAIL == 1,
  "PC TM23 quantity is not exactly one")
saved = Serializer.decode(Serializer.encode(game.save))
assert(saved.pcItems.TM_IRON_TAIL == 1,
  "PC TM23 did not survive SaveSerializer")
local replay, reason = wanderers.grantReward(
  game, state, reward, "tm23-pc")
assert(replay == nil and reason == "duplicate"
    and game.save.pcItems.TM_IRON_TAIL == 1,
  "TM23 PC reward token is not exact-once")

print(("legacy wanderers TM Authority PASS: total=%d Gen2=%d Gen3=%d "
  .. "TM23=%s/%s compatibility=%d teach=%s Bag=1 PC=1")
  :format(counts[2] + counts[3], counts[2], counts[3],
    ironTail.item, ironTail.move, #witnesses, teachResult))
