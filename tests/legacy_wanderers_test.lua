local engine = assert(os.getenv("GEN1RECOMP_DIR"),
  "GEN1RECOMP_DIR is required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
local Serializer = require("src.core.SaveSerializer")
local Collision = require("src.world.Collision")
local ItemEffects = require("src.inventory.ItemEffects")

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function contains(text, fragment, message)
  ok(type(text) == "string" and text:find(fragment, 1, true) ~= nil,
    message .. " (text: " .. tostring(text) .. ")")
end
local function ids(rows)
  local out = {}
  for _, row in ipairs(rows or {}) do out[row.item or row.class] = row end
  return out
end

local hooks, events, saveBucket = {}, {}, {}
local optionFrequency
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return saveBucket[key] end,
    set = function(_, key, value) saveBucket[key] = value end,
  },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  options = { get = function(_, key)
    if key == "legacy_wanderer_frequency" then return optionFrequency end
  end },
  world = {
    spawnNpc = function() return nil end,
    removeNpc = function() return true end,
    npc = function() return nil end,
  },
}

local legacyState = {
  version = 5, cycle = 3, runId = "legacy-run-3", pact = "trainer",
  bankUnlocked = true, wanderersEnabled = true,
}
local profile = { completedPaths = {}, legacyPass = false }
local journey = {
  wanderersEnabled = function() return legacyState.wanderersEnabled == true end,
  state = function() return legacyState end,
  profile = function() return profile end,
}
local titleId
local titles = {
  currentTitle = function()
    return titleId, titleId == "factory_architect" and "FACTORY ARCHITECT"
      or "CHAMPION"
  end,
}
local function deterministic(low, high, purpose)
  if purpose == "master" then return high end
  return low
end

local makeWanderers = assert(loadfile("legacy_wanderers.lua"))()
local wanderers = makeWanderers(mod, {
  journey = journey, titles = titles, random = deterministic,
})

local profiles = wanderers.FREQUENCY_PROFILES
eq(profiles.rare.minSteps, 600, "RARE starts no earlier than 600 outdoor steps")
eq(profiles.rare.minMaps, 4, "RARE starts at four genuine map changes")
eq(profiles.rare.maxMaps, 6, "RARE can target six genuine map changes")
eq(profiles.rare.hardMaxSteps, 5000, "RARE fail-safe is exactly 5000 steps")
eq(profiles.normal.minSteps, 200, "NORMAL starts no earlier than 200 steps")
eq(profiles.normal.minMaps, 2, "NORMAL targets at least two map changes")
eq(profiles.normal.maxMaps, 3, "NORMAL targets at most three map changes")
eq(profiles.normal.hardMaxSteps, 1800, "NORMAL fail-safe is 1800 steps")
eq(profiles.often.minSteps, 200, "OFTEN retains the fair 200-step floor")
eq(profiles.often.minMaps, 1, "OFTEN may trigger after one map change")
eq(profiles.often.maxMaps, 2, "OFTEN targets at most two map changes")
eq(profiles.often.hardMaxSteps, 900, "OFTEN fail-safe is 900 steps")
ok(profiles.never.disabled, "NEVER is an explicit disabled profile")

-- ----------------------------------------- outdoor-only hybrid cadence

ok(wanderers.isEligibleMap("ROUTE_1"), "ordinary route is eligible")
ok(wanderers.isEligibleMap("ROUTE_22"), "outdoor story route is eligible once safe")
ok(wanderers.isEligibleMap("ROUTE_25"), "late safe route is eligible")
ok(wanderers.isEligibleMap("PALLET_TOWN"), "town exterior is eligible")
ok(wanderers.isEligibleMap("SAFFRON_CITY"), "city exterior is eligible")
ok(not wanderers.isEligibleMap("ROCK_TUNNEL_1F"), "dungeon is excluded")
ok(not wanderers.isEligibleMap("OAKS_LAB"), "interior is excluded")
ok(not wanderers.isEligibleMap("HEVO_RED_CORE"), "HEVO dungeon is excluded")

local floor = {}
wanderers.scheduleNext(floor, { targetMapChanges = 2, startMap = "ROUTE_1" })
ok(not wanderers.advanceCadence(floor, "ROUTE_1"),
  "first outdoor step begins the persisted cycle")
ok(not wanderers.advanceCadence(floor, "VIRIDIAN_CITY"),
  "first real outdoor map change cannot bypass the floor")
ok(not wanderers.advanceCadence(floor, "ROUTE_2"),
  "second target map change still cannot bypass 200 steps")
for _ = 4, 199 do
  ok(not wanderers.advanceCadence(floor, "ROUTE_1"),
    "hybrid cadence cannot trigger before 200 eligible steps")
end
ok(wanderers.advanceCadence(floor, "ROUTE_1"),
  "the 200th eligible step triggers after the map target is met")
eq(floor.stepsRemaining, 0, "due cadence is pinned at zero")
ok(not wanderers.advanceCadence(floor, "ROCK_TUNNEL_1F"),
  "ineligible cave steps never start a due encounter")
ok(floor.due, "unsafe map cannot consume the due transaction")
ok(wanderers.advanceCadence(floor, "ROUTE_1"),
  "the due transaction remains armed on the next safe route step")

local ceiling = {}
wanderers.scheduleNext(ceiling, { targetMapChanges = 3,
  startMap = "ROUTE_25" })
for _ = 1, 1799 do
  ok(not wanderers.advanceCadence(ceiling, "ROUTE_25"),
    "1800-step fail-safe cannot trigger early")
end
ok(wanderers.advanceCadence(ceiling, "ROUTE_25"),
  "the 1800th eligible step is the hard fail-safe")
eq(ceiling.eligibleSteps, 1800, "only eligible outdoor steps are counted")

local rareFloor = {}
wanderers.scheduleNext(rareFloor, { frequency = "rare",
  targetMapChanges = 4, startMap = "ROUTE_1" })
for _, mapId in ipairs({ "VIRIDIAN_CITY", "ROUTE_2", "PEWTER_CITY",
    "ROUTE_3" }) do
  ok(not wanderers.advanceCadence(rareFloor, mapId),
    "RARE map target alone cannot bypass its 600-step floor")
end
for _ = 5, 599 do wanderers.advanceCadence(rareFloor, "ROUTE_3") end
ok(not rareFloor.due, "RARE remains held through step 599")
ok(wanderers.advanceCadence(rareFloor, "ROUTE_3"),
  "RARE can trigger on exact step 600 after four maps")

local rareCap = {}
wanderers.scheduleNext(rareCap, { frequency = "rare",
  targetMapChanges = 6, startMap = "ROUTE_25" })
for _ = 1, 4999 do wanderers.advanceCadence(rareCap, "ROUTE_25") end
ok(not rareCap.due, "RARE hard cap cannot trigger at step 4999")
ok(wanderers.advanceCadence(rareCap, "ROUTE_25"),
  "RARE hard cap triggers at exact step 5000")

local oftenFloor = {}
wanderers.scheduleNext(oftenFloor, { frequency = "often",
  targetMapChanges = 1, startMap = "ROUTE_1" })
wanderers.advanceCadence(oftenFloor, "VIRIDIAN_CITY")
for _ = 2, 199 do wanderers.advanceCadence(oftenFloor, "VIRIDIAN_CITY") end
ok(not oftenFloor.due, "OFTEN still cannot trigger before step 200")
ok(wanderers.advanceCadence(oftenFloor, "VIRIDIAN_CITY"),
  "OFTEN triggers on step 200 when its one-map target is met")

local oftenCap = {}
wanderers.scheduleNext(oftenCap, { frequency = "often",
  targetMapChanges = 2, startMap = "ROUTE_25" })
for _ = 1, 899 do wanderers.advanceCadence(oftenCap, "ROUTE_25") end
ok(not oftenCap.due, "OFTEN hard cap cannot trigger at step 899")
ok(wanderers.advanceCadence(oftenCap, "ROUTE_25"),
  "OFTEN hard cap triggers at exact step 900")

local never = { frequency = "never", cycleSteps = 77, eligibleSteps = 88 }
ok(not wanderers.advanceCadence(never, "ROUTE_1"),
  "NEVER cannot roll a new due encounter")
eq(never.cycleSteps, 77, "NEVER does not advance cadence")
eq(never.eligibleSteps, 88, "NEVER does not count encounter steps")

local scheduled = {}
eq(wanderers.scheduleNext(scheduled, 1), 2,
  "configured map draws clamp to the two-change boundary")
eq(wanderers.scheduleNext(scheduled, 99), 3,
  "configured map draws clamp to the three-change boundary")

local mapDraws = { 2, 3, 2 }
local drawIndex = 0
local drawProbe = makeWanderers(mod, {
  journey = journey, titles = titles,
  random = function(low, high, purpose)
    if purpose ~= "maps" then return low end
    drawIndex = drawIndex + 1
    return mapDraws[drawIndex]
  end,
})
eq(drawProbe.scheduleNext({}), 2,
  "injected map draw reaches the inclusive lower endpoint")
eq(drawProbe.scheduleNext({}), 3,
  "injected map draw reaches the inclusive upper endpoint")
eq(drawProbe.scheduleNext({}), 2,
  "map cadence distribution remains deterministically injectable")

local reentry = {}
wanderers.scheduleNext(reentry, { targetMapChanges = 2,
  startMap = "ROUTE_1" })
for _ = 1, 200 do wanderers.advanceCadence(reentry, "ROUTE_1") end
wanderers.advanceCadence(reentry, "OAKS_LAB")
wanderers.advanceCadence(reentry, "ROUTE_1")
eq(reentry.mapChanges, 0,
  "house re-entry onto the same outdoor map adds no fake map change")
ok(not wanderers.advanceCadence(reentry, "VIRIDIAN_CITY"),
  "one real outdoor transition is still below a two-map target")
wanderers.advanceCadence(reentry, "VIRIDIAN_MART")
wanderers.advanceCadence(reentry, "VIRIDIAN_CITY")
eq(reentry.mapChanges, 1,
  "city interior re-entry also leaves the outdoor map count unchanged")
ok(wanderers.advanceCadence(reentry, "ROUTE_2"),
  "second genuine outdoor transition arms the encounter")
-- Restore the controller whose deterministic reward roll avoids Master Ball.
wanderers = makeWanderers(mod, {
  journey = journey, titles = titles, random = deterministic,
})

-- The live WorldAPI/Collision contract accepts lowercase movement ids.  A
-- renderer-only title test used to clean the NPC up before it walked, hiding
-- uppercase path rows until a real LÖVE approach crashed in Collision.target.
local approach = wanderers.findApproach({
  player = { cellX = 5, cellY = 5 },
  map = {
    inBounds = function(_, x, y)
      return x >= 0 and x <= 10 and y >= 0 and y <= 10
    end,
    isWalkableCell = function() return true end,
    warpAtCell = function() return nil end,
    signAtCell = function() return nil end,
    isWarpTileCell = function() return false end,
  },
  npcAtCell = function() return nil end,
})
ok(approach and #approach.path >= 2,
  "safe approach search returns a real scripted path")
for _, direction in ipairs(approach.path) do
  ok(direction == direction:lower(),
    "wanderer approach direction uses the lowercase WorldAPI contract")
  local moved, x = pcall(function()
    local tx = Collision.target(0, 0, direction)
    return tx
  end)
  ok(moved and tonumber(x),
    "every generated approach direction is accepted by Collision.target")
end

-- ------------------------------------------------ live registries / pools

local pokemon = {
  PLAYER_A = { tmhm = { "IRON_TAIL", "PLACEHOLDER_MOVE" } },
  PLAYER_B = { tmhm = { "DRAGON_CLAW" } },
  PLAYER_C = { tmhm = {} },
  RATTATA = { tmhm = {} }, PIDGEY = { tmhm = {} },
  SPEAROW = { tmhm = {} }, EKANS = { tmhm = {} },
  MANKEY = { tmhm = {} }, MACHOP = { tmhm = {} },
}
local items = {
  POKE_BALL = { name = "POKé BALL", ball = "POKE_BALL" },
  GREAT_BALL = { name = "GREAT BALL", ball = "GREAT_BALL" },
  ULTRA_BALL = { name = "ULTRA BALL", ball = "ULTRA_BALL" },
  SAFARI_BALL = { name = "SAFARI BALL", ball = "SAFARI_BALL" },
  MASTER_BALL = { name = "MASTER BALL", ball = "MASTER_BALL" },
  FAST_BALL = { name = "FAST BALL" }, FRIEND_BALL = { name = "FRIEND BALL" },
  HEAVY_BALL = { name = "HEAVY BALL" }, LEVEL_BALL = { name = "LEVEL BALL" },
  LOVE_BALL = { name = "LOVE BALL" }, LURE_BALL = { name = "LURE BALL" },
  MOON_BALL = { name = "MOON BALL" },
  EXP_ALL = { name = "EXP.ALL" },
  ASCENDANT_EXP_MULTIPLIER = { name = "EXP MULTIPLIER", keyItem = true },
  TM_IRON_TAIL = { name = "TM23", machine = {
    kind = "TM", number = 23, move = "IRON_TAIL" } },
  TM_HOENN_CLAW = { name = "TM02", machine = {
    kind = "TM", number = 2, move = "DRAGON_CLAW" } },
  TM_NO_COMPAT = { name = "TM30", machine = {
    kind = "TM", number = 30, move = "SHADOW_BALL" } },
  TM_KANTO_NOOP = { name = "TM34", machine = {
    kind = "TM", number = 34, move = "BIDE" } },
  TM_DANGLING = { name = "TM99", machine = {
    kind = "TM", number = 99, move = "MISSING_MOVE", generation = 2 } },
  TM_PLACEHOLDER = { name = "TM23", machine = {
    kind = "TM", number = 23, move = "PLACEHOLDER_MOVE", generation = 2 } },
  HM_SURF = { name = "HM03", machine = {
    kind = "HM", number = 3, move = "SURF", generation = 2 } },
  FILLER = { name = "FILLER" }, PC_FILLER = { name = "PC FILLER" },
}
local trainers = {
  OPP_YOUNGSTER = { name = "YOUNGSTER", parties = {
    { { species = "RATTATA", level = 5 },
      { species = "PIDGEY", level = 6 } },
    { { species = "SPEAROW", level = 12 },
      { species = "EKANS", level = 13 } },
  } },
  OPP_SCIENTIST = { name = "SCIENTIST", parties = {
    { { species = "EKANS", level = 20 } },
  } },
  OPP_BLACKBELT = { name = "BLACKBELT", parties = {
    { { species = "MACHOP", level = 30 } }, -- story Karate Master
    { { species = "MANKEY", level = 31 } },
  } },
  OPP_CUSTOM_SCOUT = { name = "SCOUT", parties = {
    { { species = "PIDGEY", level = 9 } },
  } },
  OPP_RIVAL1 = { name = "RIVAL", parties = {
    { { species = "RATTATA", level = 5 } },
  } },
  OPP_TECH_TEST = { name = "TEST", technical = true, parties = {
    { { species = "RATTATA", level = 5 } },
  } },
  -- These are live, structurally valid trainer records with no story/boss
  -- metadata in their authored registration. Class identity must keep them
  -- out of the ordinary road pool fail-closed.
  KA_JOHTO_SILVER = { name = "SILVER", parties = {
    { { species = "SPEAROW", level = 50 } },
  } },
  KA_JOHTO_KRIS = { name = "KRIS", parties = {
    { { species = "EKANS", level = 50 } },
  } },
  KA_JOHTO_GOLD = { name = "GOLD", parties = {
    { { species = "PIKACHU", level = 50 } },
  } },
  KA_FUTURE_STORY = { name = "FUTURE", parties = {
    { { species = "RATTATA", level = 50 } },
  } },
}
local sprites = {
  SPRITE_YOUNGSTER = {}, SPRITE_SCIENTIST = {}, SPRITE_HIKER = {},
  SPRITE_COOLTRAINER_M = {}, SPRITE_RED = {},
}
local save = {
  inventory = {}, bagOrder = {}, pcItems = {}, pcOrder = {},
  party = {
    { species = "PLAYER_A", level = 10, hp = 0 },
    { species = "PLAYER_B", level = 50, hp = 1 },
    { species = "PLAYER_C", level = 100, hp = 1 },
    { species = "MISSING", level = 99, hp = 1 },
  },
  money = 1234,
}
local game = {
  save = save,
  data = {
    items = items, balls = {}, moves = {
      IRON_TAIL = {}, DRAGON_CLAW = {}, SHADOW_BALL = {}, BIDE = {},
      PLACEHOLDER_MOVE = { placeholder = true },
      SURF = {},
    },
    pokemon = pokemon, trainers = trainers, sprites = sprites,
    maps = {
      ROUTE_1 = { width = 10, height = 18 },
      PALLET_TOWN = { width = 10, height = 9 },
    },
    constants = { bagSize = 20, badges = {
      { id = "BOULDERBADGE" }, { id = "CASCADEBADGE" },
      { id = "THUNDERBADGE" }, { id = "RAINBOWBADGE" },
      { id = "SOULBADGE" }, { id = "MARSHBADGE" },
      { id = "VOLCANOBADGE" }, { id = "EARTHBADGE" },
    } },
    field = { pcItemCap = 50 },
  },
}

local balls = ids(wanderers.rewardPool(game))
for _, id in ipairs(wanderers.APRICORN_BALLS) do
  ok(balls[id] and balls[id].apricorn,
    id .. " is explicit in the registered Apricorn reward pool")
end
ok(not balls.MASTER_BALL,
  "Master Ball is absent from the ordinary weighted pool")
local masterHits, masterDenominator = wanderers.masterBallOdds(game)
eq(masterHits, 1, "Master Ball has one dedicated rare hit")
eq(masterDenominator, 32,
  "Master Ball uses its own obtainable 1-in-32 group")
local rematchMasterSpec = assert(loadfile("rematch_loot.lua"))()
  .SPECIAL.rematchMaster
ok(masterDenominator < rematchMasterSpec.denominator,
  "1-in-32 Surprise Master Ball is more frequent than 1-in-50 rematch loot")
local enumeratedMasterHits = 0
for roll = 1, masterDenominator do
  if wanderers.selectReward(game, roll, 1).kind == "master" then
    enumeratedMasterHits = enumeratedMasterHits + 1
  end
end
eq(enumeratedMasterHits, 1,
  "enumerating the Surprise rare group yields exactly one hit in 32")
local master = wanderers.selectReward(game, 1, 1)
eq(master.item, "MASTER_BALL", "dedicated rare roll selects Master Ball")
eq(master.qty, 1, "Master Ball rare group always grants exactly one")
ok(master.separate and master.rare,
  "Master Ball result is marked separate from normal rewards")

local stackRows = {}
for _, row in ipairs(wanderers.rewardPool(game)) do
  stackRows[row.item .. ":" .. tostring(row.qty)] = row
end
for qty = 3, 8 do
  if qty == 3 or qty == 5 or qty == 8 then
    ok(stackRows["POKE_BALL:" .. qty],
      "Poké Ball stack " .. qty .. " is reachable")
  end
end
for _, qty in ipairs({ 2, 3, 5 }) do
  ok(stackRows["GREAT_BALL:" .. qty],
    "Great Ball stack " .. qty .. " is reachable")
end
for _, qty in ipairs({ 1, 2, 3 }) do
  ok(stackRows["ULTRA_BALL:" .. qty],
    "Ultra Ball stack " .. qty .. " is reachable")
end
for _, id in ipairs(wanderers.APRICORN_BALLS) do
  ok(stackRows[id .. ":1"] and stackRows[id .. ":2"],
    id .. " has both one- and two-ball stack results")
end

local machines = ids(wanderers.registeredTMs(game))
eq(machines.TM_IRON_TAIL.generation, 2,
  "live-shaped TM23 Iron Tail is admitted as a Johto machine")
eq(machines.TM_HOENN_CLAW.generation, 3,
  "registered compatible Hoenn TM is admitted")
ok(not machines.TM_NO_COMPAT,
  "a registered TM with no compatible species is not a no-op drop")
ok(not machines.TM_KANTO_NOOP,
  "an unrelated Kanto-only machine is outside the Johto/Hoenn pool")
ok(not machines.TM_DANGLING,
  "a TM whose move is not registered is excluded")
ok(not machines.TM_PLACEHOLDER,
  "a registered placeholder move is not an engine-effective drop")
ok(not machines.HM_SURF, "HMs never enter the TM reward pool")

local tmUse, tmMove = ItemEffects.use(game.data, save, "TM_IRON_TAIL", {
  species = "PLAYER_A", moves = { { id = "TACKLE", pp = 35 } },
})
eq(tmUse, "learn",
  "TM23 enters the engine's ordinary single-use teaching flow")
eq(tmMove, "IRON_TAIL",
  "TM23 teaches its registered Johto move to a compatible species")

local tmBagState = {
  rewardedTokens = {}, pendingRewards = {}, rotation = {},
}
local tmBagPlacement = wanderers.grantReward(game, tmBagState, {
  item = "TM_IRON_TAIL", qty = 1, kind = "tm",
}, "tm23-bag")
eq(tmBagPlacement, "bag",
  "a Wanderer TM23 reward uses the real Bag placement path")
eq(save.inventory.TM_IRON_TAIL, 1,
  "the Bag contains exactly one awarded TM23")
local tmBagReload = Serializer.decode(Serializer.encode(save))
eq(tmBagReload.inventory.TM_IRON_TAIL, 1,
  "the awarded TM23 survives a save serialization round-trip")
save.inventory, save.bagOrder = {}, {}

-- Every integer in the ordinary weighted range maps deterministically to
-- exactly the published weight; this proves there are no gaps or bias.
local distribution = {}
local totalWeight = wanderers.rewardPoolTotal(game)
for roll = 1, totalWeight do
  local row = wanderers.selectReward(game, masterDenominator, roll)
  local key = row.item .. ":" .. tostring(row.qty)
  distribution[key] = (distribution[key] or 0) + 1
end
for _, row in ipairs(wanderers.rewardPool(game)) do
  local key = row.item .. ":" .. tostring(row.qty)
  eq(distribution[key], row.weight,
    key .. " receives exactly its deterministic weight")
end

local catchState = { share = false, multiplierStage = 0 }
local catchUnlockCalls = {}
local catchController = {
  catchupStatus = function()
    return {
      expShareMissing = not catchState.share,
      multiplier2Missing = catchState.multiplierStage < 2,
      nextMultiplier = catchState.multiplierStage == 2 and 3
        or catchState.multiplierStage == 3 and 5 or nil,
    }
  end,
  unlock = function(_, kind, grantOptions)
    catchUnlockCalls[#catchUnlockCalls + 1] = {
      kind = kind, pcFallback = grantOptions and grantOptions.pcFallback,
    }
    if kind == "expShare" and not catchState.share then
      catchState.share = true
      return "EXP SHARE unlocked!", true, "bag"
    elseif kind == 2 and catchState.multiplierStage < 2 then
      catchState.multiplierStage = 2
      return "EXP MULTIPLIER ×2 unlocked!", true, "bag"
    elseif kind == 3 and catchState.multiplierStage == 2 then
      catchState.multiplierStage = 3
      return "EXP MULTIPLIER ×3 unlocked!", true, "owned"
    elseif kind == 5 and catchState.multiplierStage == 3 then
      catchState.multiplierStage = 5
      return "EXP MULTIPLIER ×5 unlocked!", true, "owned"
    end
    return nil, false, "owned"
  end,
}
wanderers.setRewardController(catchController)
local catchHits = 0
for roll = 1, wanderers.EXP_SHARE_CATCHUP_DENOMINATOR do
  local row = wanderers.selectReward(game, masterDenominator, 1,
    { expShare = roll, multiplier2 = 2 })
  if row.kind == "catchup" and row.unlock == "expShare" then
    catchHits = catchHits + 1
  end
end
eq(catchHits, 1, "EXP Share catch-up band is exactly one in four")
catchHits = 0
for roll = 1, wanderers.MULTIPLIER2_CATCHUP_DENOMINATOR do
  local row = wanderers.selectReward(game, masterDenominator, 1,
    { expShare = 2, multiplier2 = roll })
  if row.kind == "catchup" and row.unlock == 2 then
    catchHits = catchHits + 1
  end
end
eq(catchHits, 1, "first ×2 catch-up band is exactly one in six")
eq(wanderers.selectReward(game, 1, 1,
  { expShare = 1, multiplier2 = 1 }).kind, "master",
  "independent Master Ball group resolves before catch-up bands")

local catchRewardState = {
  rewardedTokens = {}, pendingRewards = {}, rotation = {},
}
local shareReward = wanderers.selectReward(game, masterDenominator, 1,
  { expShare = 1, multiplier2 = 2 })
local catchPlacement, _, catchText = wanderers.grantReward(
  game, catchRewardState, shareReward, "catch-share")
eq(catchPlacement, "bag", "catch-up unlock delegates its physical placement")
contains(catchText, "EXP SHARE", "catch-up uses the controller unlock text")
ok(catchUnlockCalls[1].pcFallback,
  "Wanderer catch-up explicitly requests Bag-to-PC-to-pending placement")
ok(not wanderers.catchupStatus(game).expShareMissing,
  "earned EXP Share immediately leaves the catch-up band")
local multiplierReward = wanderers.selectReward(game, masterDenominator, 1,
  { expShare = 1, multiplier2 = 1 })
eq(multiplierReward.unlock, 2,
  "after EXP Share, the elevated band offers only the first ×2 stage")
wanderers.grantReward(game, catchRewardState, multiplierReward,
  "catch-multiplier")
ok(not wanderers.catchupStatus(game).multiplier2Missing,
  "earned ×2 state immediately leaves its catch-up band")
catchHits = 0
for roll = 1, wanderers.MULTIPLIER3_CATCHUP_DENOMINATOR do
  local row = wanderers.selectReward(game, masterDenominator, 1,
    { multiplier3 = roll })
  if row.kind == "catchup" and row.unlock == 3 then catchHits = catchHits + 1 end
end
eq(catchHits, 1, "next ×3 stage is exactly one in twelve")
local multiplier3 = wanderers.selectReward(game, masterDenominator, 1,
  { multiplier3 = 1 })
eq(multiplier3.unlock, 3, "×3 is offered only after functional ×2")
wanderers.grantReward(game, catchRewardState, multiplier3, "catch-multiplier3")
catchHits = 0
for roll = 1, wanderers.MULTIPLIER5_CATCHUP_DENOMINATOR do
  local row = wanderers.selectReward(game, masterDenominator, 1,
    { multiplier5 = roll })
  if row.kind == "catchup" and row.unlock == 5 then catchHits = catchHits + 1 end
end
eq(catchHits, 1, "final ×5 stage is exactly one in twenty-four")
local multiplier5 = wanderers.selectReward(game, masterDenominator, 1,
  { multiplier5 = 1 })
eq(multiplier5.unlock, 5, "×5 is offered only after functional ×3")
wanderers.grantReward(game, catchRewardState, multiplier5, "catch-multiplier5")
local ordinaryAfterCatchup = wanderers.selectReward(game,
  masterDenominator, 1, { expShare = 1, multiplier2 = 1,
    multiplier3 = 1, multiplier5 = 1 })
ok(ordinaryAfterCatchup.kind ~= "catchup",
  "owned/unlocked helpers remove all catch-up weight")

local live = wanderers.liveTrainerPool(game)
local liveByClass = ids(live)
ok(liveByClass.OPP_YOUNGSTER and liveByClass.OPP_SCIENTIST
    and liveByClass.OPP_BLACKBELT and liveByClass.OPP_CUSTOM_SCOUT,
  "broad live ordinary trainer classes enter the pool")
ok(not liveByClass.OPP_RIVAL1 and not liveByClass.OPP_TECH_TEST,
  "story and technical trainer records are excluded")
ok(not liveByClass.KA_JOHTO_SILVER
    and not liveByClass.KA_JOHTO_KRIS
    and not liveByClass.KA_JOHTO_GOLD,
  "all three registered Johto finale bosses are excluded")
ok(not liveByClass.KA_FUTURE_STORY
    and wanderers.isStoryTrainer("KA_FUTURE_STORY",
      trainers.KA_FUTURE_STORY),
  "unclassified KA feature trainers fail closed outside the ordinary pool")
eq(#liveByClass.OPP_BLACKBELT.partyIndexes, 1,
  "the story-only Karate Master party is excluded from its live class")
eq(liveByClass.OPP_BLACKBELT.partyIndexes[1], 2,
  "ordinary Blackbelt parties remain available")
ok(liveByClass.OPP_CUSTOM_SCOUT.fieldSpriteFallback,
  "unknown live class honestly records its neutral field-sprite fallback")

-- ------------------------------------------------ title, scaling, EXP

local scientist = {
  game = game, archetype = { class = "OPP_SCIENTIST" },
  team = { { species = "EKANS", level = 20 } },
}
titleId = nil
eq(wanderers.reactionContext(scientist).kind, "fallback",
  "no selected title keeps the neutral road introduction")
contains(wanderers.challengeText(scientist), "sought you out",
  "neutral introduction clearly challenges the player")
titleId = "factory_architect"
eq(wanderers.reactionContext(scientist).kind, "title_factory",
  "matching live trainer reacts to the selected title")
contains(wanderers.challengeText(scientist), "BATTLE FACTORY",
  "title-reactive introduction names the achievement naturally")
titleId = nil

local tier1 = wanderers.challengeTier(game, 1, { lossRelief = 0 })
eq(tier1.teamSize, 2,
  "only healthy registered party members set the challenge size")
eq(tier1.baselineLevel, 75,
  "two strongest usable monsters use their rounded median baseline")
eq(tier1.targetLevels[1], 76,
  "minimum road edge is exactly one level above the fair baseline")
eq(tier1.targetLevels[2], 76,
  "the compact opponent team shares the same readable target level")
local tier3 = wanderers.challengeTier(game, 3, { lossRelief = 0 })
eq(tier3.targetLevels[2], 78,
  "maximum road edge is exactly three levels above the fair baseline")
eq(tier3.aiLayers, 3, "a fresh challenge retains all three AI layers")

local rotation = { rotation = {} }
local firstIndex, firstTeam = wanderers.teamFor(game,
  liveByClass.OPP_YOUNGSTER, rotation, 1)
local secondIndex, secondTeam = wanderers.teamFor(game,
  liveByClass.OPP_YOUNGSTER, rotation, 3)
eq(firstIndex, 1, "first challenge starts at the first valid live party")
eq(secondIndex, 2, "next challenge rotates to the next rematch-like party")
eq(firstTeam[1].level, 76, "rotated roster uses the fair live-party baseline")
eq(secondTeam[2].level, 78, "second roster uses its configured small edge")
eq(#firstTeam, 2, "opponent roster matches usable player party size")

local ordinaryScalingParty = save.party
save.party = {
  { species = "PLAYER_A", level = 60, hp = 1 },
  { species = "PLAYER_B", level = 50, hp = 1 },
  { species = "PLAYER_C", level = 40, hp = 1 },
  { species = "RATTATA", level = 30, hp = 1 },
  { species = "PIDGEY", level = 20, hp = 1 },
  { species = "SPEAROW", level = 10, hp = 1 },
}
local fullTier = wanderers.challengeTier(game, 3, { lossRelief = 0 })
eq(fullTier.baselineLevel, 50,
  "six-mon parties scale from the median of their three strongest members")
eq(fullTier.teamSize, 4,
  "a surprise trainer can never bring more than four monsters")
eq(fullTier.targetLevel, 53, "fresh maximum edge remains only three levels")
local relief1 = wanderers.challengeTier(game, 3, { lossRelief = 1 })
eq(relief1.targetLevel, 52, "one loss immediately reduces the level edge")
eq(relief1.teamSize, 4, "first relief step keeps the compact team shape")
eq(relief1.aiLayers, 2, "one loss also removes one AI pressure layer")
ok(not relief1.perfectMastery,
  "the challenge tier itself does not fabricate perfect mastery")
local relief2 = wanderers.challengeTier(game, 3, { lossRelief = 2 })
eq(relief2.targetLevel, 51, "second loss reduces the edge again")
eq(relief2.teamSize, 3, "second loss makes the next enemy team smaller")
eq(relief2.aiLayers, 1, "second loss leaves only one AI pressure layer")
local relief3 = wanderers.challengeTier(game, 3, { lossRelief = 99 })
eq(relief3.lossRelief, 3, "loss relief is capped at three persisted steps")
eq(relief3.targetLevel, 50, "maximum relief removes the level edge")
eq(relief3.teamSize, 3, "maximum relief keeps the one-slot reduction")
eq(relief3.aiLayers, 0, "maximum relief removes extra AI pressure")
save.party = ordinaryScalingParty

eq(wanderers.applyExpBonus(100, 15), 115,
  "encounter EXP bonus is exactly 15 percent")
eq(wanderers.applyExpBonus(100, 20), 120,
  "encounter EXP bonus is exactly 20 percent")
eq(wanderers.applyExpBonus(100, 1), 115,
  "configured EXP below the contract clamps to 15 percent")
eq(wanderers.applyExpBonus(100, 99), 120,
  "configured EXP above the contract clamps to 20 percent")
eq(hooks["exp.gain"](function() return 100 end, {}), 100,
  "ordinary battle EXP is untouched")
wanderers.active = {
  expBonusPercent = 17,
  battle = { ascendantLegacyWanderer = true },
}
eq(hooks["exp.gain"](function() return 100 end, {}), 117,
  "active surprise battle receives only its persisted 17-percent bonus")
wanderers.active = nil

-- The shared progression API remains unchanged for fixed legacy_paths fights.
save.inventory.BOULDERBADGE = 1
save.inventory.CASCADEBADGE = 1
save.inventory.THUNDERBADGE = 1
local fixedTier = wanderers.progressTier(game)
eq(fixedTier.targetLevel, 31,
  "fixed Legacy path scaling retains badge/cycle/pact progression")
save.party[1].level, save.party[2].level = 1, 1
eq(wanderers.progressTier(game).targetLevel, fixedTier.targetLevel,
  "new live-party scaling does not repurpose shared progressTier")
save.party[1].level, save.party[2].level = 10, 50

-- ------------------------------------------------ persistence / retry / exact once

saveBucket.legacy_wanderers = {
  version = 3, frequency = "rare", cadenceMode = "normal",
  cycleSteps = 250, mapChanges = 1, targetMapChanges = 2,
  wins = 0, rotation = {}, pendingRewards = {}, rewardedTokens = {},
}
eq(wanderers.state().frequency, "normal",
  "existing active NG+ save migrates to the NORMAL frequency default")

saveBucket.legacy_wanderers = {
  version = 4, frequency = "normal", cadenceMode = "normal", cycleSteps = 777,
  mapChanges = 1, targetMapChanges = 3, lastEligibleMap = "ROUTE_1",
  due = false, eligibleSteps = 42,
  wins = 0, streak = 0, marks = 0, nextToken = 7,
  encounter = {
    token = "legacy-wanderer:6", class = "OPP_SCIENTIST",
    sprite = "SPRITE_SCIENTIST", partyIndex = 1,
    team = { { species = "EKANS", level = 58 } },
    tier = { scalePercent = 15, teamSize = 1 },
  },
  rotation = {}, pendingRewards = {}, rewardedTokens = {},
}
local persisted = wanderers.state()
eq(persisted.cycleSteps, 777,
  "save normalization preserves the exact hybrid step progress")
eq(persisted.mapChanges, 1,
  "save normalization preserves the exact outdoor transition count")
eq(persisted.targetMapChanges, 3,
  "save normalization preserves the exact randomized map target")
eq(persisted.stepsRemaining, 0,
  "v4 replacement remains immediately due instead of adding a new cooldown")
ok(persisted.encounter == nil and persisted.due,
  "v4 over-tuned persisted encounter is discarded but remains due for a fair rebuild")
eq(persisted.nextToken, 7,
  "fair migration never reuses the obsolete encounter token")
saveBucket.legacy_wanderers = Serializer.decode(Serializer.encode(persisted))
local reloaded = makeWanderers(mod, {
  journey = journey, titles = titles, random = deterministic,
  rewards = catchController,
})
eq(reloaded.state().cycleSteps, 777,
  "a fresh controller reload keeps the same exact step progress")
eq(reloaded.state().mapChanges, 1,
  "a fresh controller reload keeps the same exact map progress")
eq(reloaded.state().targetMapChanges, 3,
  "a fresh controller reload keeps the same exact target")

persisted.due, persisted.stepsRemaining = true, 0
local prepared = assert(wanderers.prepareEncounter(game, persisted))
prepared.mapId = "ROUTE_1"
eq(wanderers.resolveEncounter(game, persisted, prepared, "lose"),
  "resolved_loss", "loss resolves the surprise encounter without a rematch")
ok(not persisted.due and persisted.encounter == nil
    and persisted.losses == 1 and persisted.lossRelief == 1
    and persisted.forceMapChanges,
  "loss removes the trainer and schedules a fresh encounter behind map cadence")
contains(wanderers.lossText(persisted.lossRelief), "ROAD TRIAL: LOST.",
  "loss receipt visibly names the result")
contains(wanderers.lossText(persisted.lossRelief), "Your money is safe.",
  "loss receipt explicitly confirms no money penalty")
saveBucket.legacy_wanderers = Serializer.decode(Serializer.encode(persisted))
local afterLossReload = reloaded.state()
ok(afterLossReload.encounter == nil and not afterLossReload.due
    and afterLossReload.losses == 1 and afterLossReload.lossRelief == 1,
  "loss resolution survives reload without reviving the same trainer")
ok(afterLossReload.stepsRemaining > 0,
  "loss cannot respawn a surprise trainer on the next outdoor step")

-- Use a known registered reward so placement assertions are independent of
-- the deterministic pool's alphabetical first row.
afterLossReload.due, afterLossReload.stepsRemaining = true, 0
local wonEncounter = assert(reloaded.prepareEncounter(game, afterLossReload))
wonEncounter.mapId = "ROUTE_1"
wonEncounter.reward = { item = "POKE_BALL", qty = 1 }
eq(reloaded.resolveEncounter(game, afterLossReload, wonEncounter, "win"),
  "bag", "winning grants the encounter reward once")
eq(afterLossReload.lossRelief, 0,
  "one recovery win removes exactly one persisted relief step")
eq(save.inventory.POKE_BALL, 1, "win places one reward in the Bag")
local stale, staleReason = reloaded.resolveEncounter(
  game, afterLossReload, wonEncounter, "win")
eq(stale, nil, "duplicate win callback grants nothing")
eq(staleReason, "stale", "duplicate callback is recognized as stale")
eq(save.inventory.POKE_BALL, 1, "duplicate callback cannot duplicate reward")
eq(afterLossReload.cadenceMode, "encore",
  "a deterministic ten-percent hit schedules the rare same-map encore")
eq(afterLossReload.encoreMap, "ROUTE_1",
  "encore is bound to the large outdoor victory map")
eq(afterLossReload.encoreStepTarget, 240,
  "encore lower boundary is an exact 240 eligible steps")
for _ = 1, 239 do
  ok(not reloaded.advanceCadence(afterLossReload, "ROUTE_1"),
    "encore cannot occur before its persisted step target")
end
reloaded.advanceCadence(afterLossReload, "OAKS_LAB")
ok(reloaded.advanceCadence(afterLossReload, "ROUTE_1"),
  "encore becomes due on exactly the 240th same-map outdoor step")
local encoreEncounter = assert(reloaded.prepareEncounter(game, afterLossReload))
encoreEncounter.mapId, encoreEncounter.reward = "ROUTE_1", nil
eq(reloaded.resolveEncounter(game, afterLossReload,
  encoreEncounter, "win"), "no_reward",
  "second same-map victory resolves normally")
ok(afterLossReload.forceMapChanges
    and afterLossReload.targetMapChanges == 3,
  "two encounters on one map force the next three real map changes")
for _ = 1, 1800 do
  ok(not reloaded.advanceCadence(afterLossReload, "ROUTE_1"),
    "forced post-encore cycle cannot be bypassed by the step cap")
end
ok(not reloaded.advanceCadence(afterLossReload, "VIRIDIAN_CITY"),
  "first forced outdoor transition remains below three")
ok(not reloaded.advanceCadence(afterLossReload, "ROUTE_2"),
  "second forced outdoor transition remains below three")
ok(reloaded.advanceCadence(afterLossReload, "PEWTER_CITY"),
  "third forced outdoor transition arms the next encounter")
ok(not reloaded.mapCanHostEncounter(game, afterLossReload, "ROUTE_1"),
  "a map that already hosted two consecutive fights cannot host a third")
ok(reloaded.mapCanHostEncounter(game, afterLossReload, "ROUTE_2"),
  "a different eligible outdoor map can host the due encounter")

local encoreHits = 0
for roll = 1, reloaded.ENCORE_DENOMINATOR do
  if reloaded.shouldEncore(game, { mapWinCount = 1 }, "ROUTE_1", roll) then
    encoreHits = encoreHits + 1
  end
end
eq(encoreHits, 1, "same-map encore rate is exactly ten percent")
local rareEncoreHits = 0
for roll = 1, 100 do
  if reloaded.shouldEncore(game,
      { mapWinCount = 1, frequency = "rare" }, "ROUTE_1", roll) then
    rareEncoreHits = rareEncoreHits + 1
  end
end
eq(rareEncoreHits, 3, "RARE same-map encore rate is exactly three percent")
local oftenEncoreHits = 0
for roll = 1, 5 do
  if reloaded.shouldEncore(game,
      { mapWinCount = 1, frequency = "often" }, "ROUTE_1", roll) then
    oftenEncoreHits = oftenEncoreHits + 1
  end
end
eq(oftenEncoreHits, 1, "OFTEN same-map encore rate is exactly twenty percent")
ok(reloaded.shouldEncore(game, { mapWinCount = 1, frequency = "normal" },
  "PALLET_TOWN", 1),
  "whitelisted town surfaces may host the same capped rare encore")
local cancelledEncore = {}
reloaded.scheduleEncore(cancelledEncore, "ROUTE_1", 480)
for _ = 1, 100 do reloaded.advanceCadence(cancelledEncore, "ROUTE_1") end
reloaded.advanceCadence(cancelledEncore, "OAKS_LAB")
eq(cancelledEncore.cadenceMode, "encore",
  "an interior visit does not cancel a return to the same encore map")
reloaded.advanceCadence(cancelledEncore, "VIRIDIAN_CITY")
ok(cancelledEncore.cadenceMode == "normal"
    and cancelledEncore.forceMapChanges
    and cancelledEncore.mapChanges == 1,
  "a genuinely different outdoor map cancels encore into a three-map cycle")

-- BAG full -> PC, with the token ledger preventing replay.
game.data.constants.bagSize = 1
save.inventory, save.bagOrder = { FILLER = 1 }, { "FILLER" }
save.pcItems, save.pcOrder = {}, {}
local rewardState = reloaded.state()
local pcPlacement = reloaded.grantReward(game, rewardState,
  { item = "GREAT_BALL", qty = 2 }, "pc-token")
eq(pcPlacement, "pc", "full Bag sends a reward to available PC storage")
eq(save.pcItems.GREAT_BALL, 2, "PC receives the exact Ball stack")
local duplicate, duplicateReason = reloaded.grantReward(game, rewardState,
  { item = "GREAT_BALL", qty = 2 }, "pc-token")
eq(duplicate, nil, "replayed PC token grants nothing")
eq(duplicateReason, "duplicate", "PC replay is rejected by token ledger")
eq(save.pcItems.GREAT_BALL, 2, "PC Ball stack remains exact-once")
local tmPcPlacement = reloaded.grantReward(game, rewardState,
  { item = "TM_IRON_TAIL", qty = 1, kind = "tm" }, "tm23-pc-token")
eq(tmPcPlacement, "pc",
  "a full Bag sends the Wanderer TM23 through the real PC fallback")
eq(save.pcItems.TM_IRON_TAIL, 1,
  "PC storage receives exactly one TM23")
local tmPcReload = Serializer.decode(Serializer.encode(save))
eq(tmPcReload.pcItems.TM_IRON_TAIL, 1,
  "the PC-stored TM23 survives a save serialization round-trip")
local duplicateTmPc = reloaded.grantReward(game, rewardState,
  { item = "TM_IRON_TAIL", qty = 1, kind = "tm" }, "tm23-pc-token")
eq(duplicateTmPc, nil,
  "replaying the TM23 reward token cannot duplicate the PC item")

-- BAG and PC full -> persistent queue -> later exact one-time delivery.
game.data.field.pcItemCap = 1
save.pcItems, save.pcOrder = { PC_FILLER = 1 }, { "PC_FILLER" }
local pendingPlacement = reloaded.grantReward(game, rewardState,
  { item = "ULTRA_BALL", qty = 3 }, "pending-token")
eq(pendingPlacement, "pending", "full Bag and PC reserve the reward")
eq(#rewardState.pendingRewards, 1, "one persistent pending row is created")
reloaded.grantReward(game, rewardState,
  { item = "ULTRA_BALL", qty = 3 }, "pending-token")
eq(#rewardState.pendingRewards, 1,
  "replaying a pending token cannot duplicate its reservation")
saveBucket.legacy_wanderers = Serializer.decode(Serializer.encode(rewardState))
rewardState = reloaded.state()
eq(rewardState.pendingRewards[1].token, "pending-token",
  "pending reservation survives save/controller reload")
save.inventory, save.bagOrder = {}, {}
local deliveredAt, delivered, row = reloaded.deliverPending(game, rewardState)
eq(deliveredAt, "bag", "making Bag room delivers the reservation")
ok(delivered and row.item == "ULTRA_BALL",
  "delivery reports the exact reserved item")
eq(save.inventory.ULTRA_BALL, 3,
  "reserved Ball stack arrives at its exact quantity once")
eq(#rewardState.pendingRewards, 0, "delivered reservation is consumed")
local none, deliveredAgain = reloaded.deliverPending(game, rewardState)
eq(none, nil, "empty pending queue has nothing to deliver")
ok(not deliveredAgain, "pending reward cannot be delivered twice")
eq(save.inventory.ULTRA_BALL, 3, "second claim cannot duplicate the stack")

-- ------------------------------------------------ only Legacy / no interference

ok(reloaded.legacyRunEnabled(game), "active Legacy NG+ enables encounters")
optionFrequency = "often"
eq(reloaded.frequency(game, reloaded.state()), "often",
  "active Legacy NG+ reads the persisted OFTEN option")
legacyState.runId, legacyState.cycle = nil, 1
ok(not reloaded.legacyRunEnabled(game),
  "ordinary non-Legacy run cannot enable surprise trainers")
eq(reloaded.frequency(game, reloaded.state()), "never",
  "fresh normal game is hard-off regardless a stored OFTEN value")
legacyState.runId, legacyState.cycle = "legacy-run-3", 3
legacyState.wanderersEnabled = false
ok(not reloaded.legacyRunEnabled(game),
  "explicitly disabled Legacy run remains untouched")
legacyState.wanderersEnabled = true
optionFrequency = nil

local legacyBucket = saveBucket.legacy_wanderers
saveBucket.legacy_wanderers = nil
legacyState.runId, legacyState.cycle = nil, 1
events["save.loaded"]({ game = game, save = save })
eq(saveBucket.legacy_wanderers, nil,
  "loading an ordinary run creates no surprise-trainer state")
saveBucket.legacy_wanderers = legacyBucket
legacyState.runId, legacyState.cycle = "legacy-run-3", 3

local ordinaryParty = { { species = "RATTATA", level = 5 } }
local forwarded = hooks["trainer.party"](
  function(_, _, party) return party end, "OPP_YOUNGSTER", 1, ordinaryParty)
eq(forwarded, ordinaryParty,
  "wanderer roster hook cannot alter unrelated trainer battles")
local encounterSentinel = {}
eq(hooks["encounter.species"](function() return encounterSentinel end, {}, {}),
  encounterSentinel, "ordinary wild encounter pipeline is untouched")

local ow = {
  map = { id = "ROUTE_1" },
  player = { moving = false, inputLocked = false, surfing = false,
    spinning = false },
  scriptMoves = {}, engaging = false, emote = nil, transitioning = false,
  runner = { isRunning = function() return false end },
}
game.overworld = ow
game.stack = { top = function() return {} end, push = function() end }
ok(not reloaded.contextSafe(game),
  "cutscene/menu stack makes a due route context unsafe")
rewardState.due, rewardState.stepsRemaining = true, 0
events["game.ready"]({ game = game })
events["world.stepped"]({ mapId = "ROUTE_1" })
ok(rewardState.due and rewardState.stepsRemaining == 0,
  "unsafe cutscene holds the due encounter without rerolling")

-- NEVER blocks cadence/spawn but does not strand an already reserved item.
optionFrequency = "never"
save.inventory, save.bagOrder, save.pcItems, save.pcOrder = {}, {}, {}, {}
rewardState = reloaded.state()
rewardState.pendingRewards = {
  { token = "never-pending", item = "POKE_BALL", qty = 3 },
}
rewardState.cycleSteps = 321
saveBucket.legacy_wanderers = rewardState
game.stack = { top = function() return ow end, push = function() end }
events["game.ready"]({ game = game })
events["world.stepped"]({ mapId = "ROUTE_1" })
eq(save.inventory.POKE_BALL, 3,
  "NEVER still delivers a previously reserved reward")
eq(#rewardState.pendingRewards, 0,
  "NEVER delivery consumes the reservation exactly once")
eq(rewardState.cycleSteps, 321,
  "NEVER pending delivery does not advance a battle cadence")
optionFrequency = nil

-- ------------------------------------------------ Beyond-Kanto boundary

local dexes = {
  RATTATA = 19, PIDGEY = 16, SPEAROW = 21, EKANS = 23,
  MANKEY = 56, MACHOP = 66, HOUNDOUR = 228,
}
for species, dex in pairs(dexes) do
  pokemon[species] = pokemon[species] or { tmhm = {} }
  pokemon[species].dex = dex
end
trainers.OPP_CUSTOM_SCOUT.parties = { {
  { species = "HOUNDOUR", level = 20 },
  { species = "PIDGEY", level = 9 },
} }
local beyondOn = false
reloaded.setBeyondKantoBoundary({
  isActive = function() return beyondOn end,
  speciesDex = function(g, species)
    return g and g.data and g.data.pokemon[species]
      and g.data.pokemon[species].dex
  end,
})
local originalParty = save.party
save.party = { { species = "RATTATA", level = 50, hp = 1 } }
local sealedPool = ids(reloaded.liveTrainerPool(game))
ok(sealedPool.OPP_CUSTOM_SCOUT,
  "sealed mode preserves an ordinary Surprise trainer with Kanto slots")
local _, sealedTeam = reloaded.teamFor(game,
  sealedPool.OPP_CUSTOM_SCOUT, { rotation = {} }, 3, false)
eq(#sealedTeam, 1, "sealed Surprise team remains playable")
eq(sealedTeam[1].species, "PIDGEY",
  "sealed Surprise roster filters every species above #151")
eq(#reloaded.registeredTMs(game), 0,
  "sealed Surprise rewards contain no Gen-II/III TMs")
local sealedBalls = ids(reloaded.rewardPool(game))
for _, id in ipairs(reloaded.APRICORN_BALLS) do
  ok(not sealedBalls[id], id .. " remains sealed before activation")
end
ok(sealedBalls.POKE_BALL and sealedBalls.GREAT_BALL
    and sealedBalls.ULTRA_BALL,
  "sealed Surprise keeps ordinary Kanto Ball rewards functional")

beyondOn = true
local activePool = ids(reloaded.liveTrainerPool(game))
local _, activeTeam = reloaded.teamFor(game,
  activePool.OPP_CUSTOM_SCOUT, { rotation = {} }, 3, false)
eq(activeTeam[1].species, "HOUNDOUR",
  "activated Surprise restores the authored extended roster")
ok(#reloaded.registeredTMs(game) >= 2,
  "activated Surprise restores registered Johto/Hoenn TMs")
local activeBalls = ids(reloaded.rewardPool(game))
ok(activeBalls.FAST_BALL and activeBalls.FRIEND_BALL,
  "activated Surprise restores Apricorn rewards")
ok(not activePool.KA_JOHTO_SILVER and not activePool.KA_JOHTO_KRIS
    and not activePool.KA_JOHTO_GOLD,
  "Silver/Kris/Gold remain dedicated Masters, never random Surprise rows")
save.party = originalParty

local germanMod = {
  id = mod.id, save = mod.save, options = mod.options,
  hooks = { wrap = function() end }, events = { on = function() end },
  world = { spawnNpc = function() end, removeNpc = function() end,
    npc = function() end },
}
local germanWanderers = makeWanderers(germanMod, {
  journey = journey, random = deterministic,
  i18n = { text = function(_, de) return de end },
})
contains(germanWanderers.lossText(2), "WEGPRÜFUNG: VERLOREN.",
  "German loss receipt visibly names the result")
contains(germanWanderers.lossText(2), "Dein Geld bleibt sicher.",
  "German loss receipt confirms that money is protected")
contains(germanWanderers.lossText(2), "Nächstes Team ist kleiner.",
  "German loss receipt explains the second-step team relief")

print(("legacy wanderers scope: %d assertions"):format(assertions))
