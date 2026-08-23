-- Focused lifecycle contract for Surprise/Legacy Wanderer farewells.

local root = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message or "check failed")
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ") .. ": expected "
    .. tostring(expected) .. ", got " .. tostring(actual))
end

local priorBattle = package.preload["src.battle.BattleState"]
local priorTextBox = package.preload["src.render.TextBox"]

local activeHarness
package.preload["src.battle.BattleState"] = function()
  return { newTrainer = function()
    local battle = { trainer = {} }
    activeHarness.battle = battle
    return battle
  end }
end
package.preload["src.render.TextBox"] = function()
  return { new = function(_, text, done)
    return { text = text, done = done }
  end }
end

local function harness(config)
  config = config or {}
  local store, handlers, pushed, removals = {}, {}, {}, {}
  local removeMode = "ok"
  local map = {
    id = "ROUTE_2",
    inBounds = function(_, x, y) return x >= 0 and x <= 11 and y >= 0 and y <= 9 end,
    isWalkableCell = function(_, x, y)
      if config.blockDeparture then return x == 7 and y == 5 end
      return x >= 0 and x <= 11 and y >= 0 and y <= 9
    end,
    warpAtCell = function() return nil end,
    signAtCell = function() return nil end,
    isWarpTileCell = function() return false end,
  }
  local ow = {
    map = map,
    player = { cellX = 5, cellY = 5 },
    camera = { x = 64, y = 48 },
    scriptMoves = {}, engaging = false,
  }
  ow.npcAtCell = function() return nil end
  local game = {
    save = { money = 4000, player = { name = "RED" }, party = {} },
    data = { trainers = {}, pokemon = {}, sprites = {} },
    overworld = ow,
    renderer = { worldViewSize = function() return 64, 64 end },
  }
  local top = ow
  game.stack = {
    top = function() return top end,
    push = function(_, state)
      pushed[#pushed + 1] = state
      return true
    end,
  }
  ow.afterBattle = function()
    top = ow
  end
  ow.pushBattle = function(_, battle)
    if config.pushMode == "throw" then error("push failed") end
    if config.pushMode == "false" then return false end
    top = battle
    return nil
  end

  local handle = {
    npc = { cellX = 7, cellY = 5 },
    face = function() return true end,
    scriptMove = function(self, direction, _, done)
      if config.moveMode == "throw" then error("movement failed") end
      if config.moveMode == "false" then return false end
      ow.scriptMoves[#ow.scriptMoves + 1] = direction
      local delta = {
        up = { 0, -1 }, down = { 0, 1 },
        left = { -1, 0 }, right = { 1, 0 },
      }
      self.npc.cellX = self.npc.cellX + delta[direction][1]
      self.npc.cellY = self.npc.cellY + delta[direction][2]
      if done then done() end
      return true
    end,
  }
  local mod = {
    id = "kanto_ascendant",
    save = {
      get = function(_, key) return store[key] end,
      set = function(_, key, value) store[key] = value end,
    },
    hooks = { wrap = function() end },
    events = { on = function(_, name, fn) handlers[name] = fn end },
    options = { get = function() return "normal" end },
    world = {
      spawnNpc = function() return "ROUTE_2_obj_99" end,
      npc = function() return handle end,
      removeNpc = function(_, id)
        removals[#removals + 1] = id
        if removeMode == "throw" then error("remove failed") end
        if removeMode == "false" then return false end
        return true
      end,
    },
  }
  local journey = {
    wanderersEnabled = function() return true end,
    state = function()
      return { cycle = 3, runId = "FAREWELL", wanderersEnabled = true }
    end,
    profile = function() return { completedPaths = {} } end,
  }
  local surprise = {
    challengeText = function()
      return "LASS:\nRED, I followed your trail.\fShow me where it leads!"
    end,
    farewellText = function(_, result)
      if result == "win" then
        return "LASS:\nThat settles it.\fI'll train on the next road. See you!"
      end
      return "LASS:\nNot this time.\fI'll find an easier trail. See you!"
    end,
    recordWin = function() return nil, "no-drop", true end,
  }
  local make = assert(loadfile(root .. "/legacy_wanderers.lua"))()
  local wanderers = make(mod, { journey = journey, surprise = surprise,
    random = function(low) return low end })
  wanderers.syncFrequency = function() return "normal" end
  wanderers.mapCanHostEncounter = function() return true end
  wanderers.findApproach = function()
    return { x = 7, y = 5, path = {} }
  end
  wanderers.prepareEncounter = function(_, s)
    local encounter = {
      token = "legacy-wanderer:farewell", mapId = "ROUTE_2",
      class = "OPP_LASS", sprite = "SPRITE_GIRL", partyIndex = 1,
      team = { { species = "PIDGEY", level = 20 } },
      tier = { targetLevel = 20, aiLayers = 0, lossRelief = 0,
        pact = "journey" },
      expBonusPercent = 15,
    }
    s.encounter = encounter
    return encounter
  end
  wanderers.configureBattle = function(_, battle)
    battle.ascendantLegacyWanderer = true
    return battle
  end
  wanderers.resolveEncounter = function(_, _, _, result)
    return result == "win" and "no_reward" or "resolved_loss"
  end
  local H = {
    game = game, ow = ow, mod = mod, wanderers = wanderers,
    handlers = handlers, pushed = pushed, removals = removals,
    setRemoveMode = function(value) removeMode = value end,
  }
  activeHarness = H
  return H
end

local function start(H)
  check(H.wanderers.trySpawn(H.game), "fixture spawns one Surprise trainer")
  check(H.wanderers.active ~= nil, "spawn owns one live actor")
  H.ow.emote.onDone()
  local intro = H.pushed[#H.pushed]
  check(type(intro.done) == "function", "intro owns an approach callback")
  intro.done()
  return assert(H.battle, "approach starts one battle")
end

for _, row in ipairs({
    { result = "win", phrase = "train on the next road" },
    { result = "loss", phrase = "easier trail" },
  }) do
  local H = harness()
  local battle = start(H)
  H.handlers["battle.ended"]({ battle = battle, result = row.result })
  eq(#H.removals, 0,
    row.result .. " battle event cannot remove before farewell")
  check(H.wanderers.active ~= nil,
    row.result .. " actor remains authoritative through field return")
  battle.onFinish(row.result)
  local farewell = H.pushed[#H.pushed]
  check(farewell.text:find(row.phrase, 1, true) ~= nil
      and farewell.text:find("See you", 1, true) ~= nil,
    row.result .. " has distinct authored opponent farewell")
  eq(#H.removals, 0, "farewell speaker remains visible while text is open")
  farewell.done()
  check(#H.ow.scriptMoves > 0,
    row.result .. " farewell visibly walks the trainer out of frame")
  eq(#H.removals, 1, "farewell completion removes actor exactly once")
  eq(H.wanderers.active, nil, "farewell completion retires live authority")
  farewell.done()
  H.handlers["battle.ended"]({ battle = battle, result = row.result })
  eq(#H.removals, 1,
    "duplicate farewell/battle callbacks cannot remove twice")
end

local blockedDeparture = harness({ blockDeparture = true })
local blockedBattle = start(blockedDeparture)
blockedDeparture.handlers["battle.ended"]({
  battle = blockedBattle, result = "win",
})
blockedBattle.onFinish("win")
blockedDeparture.pushed[#blockedDeparture.pushed].done()
eq(#blockedDeparture.ow.scriptMoves, 0,
  "blocked departure never scripts movement through collision")
eq(#blockedDeparture.removals, 1,
  "blocked departure uses the bounded removal fallback")

local rejectedDeparture = harness({ moveMode = "false" })
local rejectedBattle = start(rejectedDeparture)
rejectedDeparture.handlers["battle.ended"]({
  battle = rejectedBattle, result = "win",
})
rejectedBattle.onFinish("win")
rejectedDeparture.pushed[#rejectedDeparture.pushed].done()
eq(#rejectedDeparture.removals, 1,
  "rejected scripted movement uses the bounded removal fallback")
eq(rejectedDeparture.wanderers.active, nil,
  "rejected movement cannot retain an invisible encounter lock")

local pushFailure = harness({ pushMode = "false" })
start(pushFailure)
eq(pushFailure.wanderers.active, nil,
  "pushBattle rejection retires the Surprise actor")
eq(#pushFailure.removals, 1,
  "pushBattle rejection removes the Surprise actor exactly once")

local mapHandoff = harness()
local mapBattle = start(mapHandoff)
mapHandoff.handlers["battle.ended"]({ battle = mapBattle, result = "win" })
mapBattle.onFinish("win")
local staleFarewell = mapHandoff.pushed[#mapHandoff.pushed]
mapHandoff.ow.map.id = "VERMILION_CITY"
mapHandoff.handlers["map.entered"]({ game = mapHandoff.game,
  mapId = "VERMILION_CITY" })
eq(mapHandoff.wanderers.active, nil,
  "map handoff retires the old Surprise actor")
eq(#mapHandoff.removals, 1, "map handoff removes old actor once")
staleFarewell.done()
eq(#mapHandoff.removals, 1,
  "late pre-map callback cannot remove a future actor")

local reload = harness()
local reloadBattle = start(reload)
reload.handlers["battle.ended"]({ battle = reloadBattle, result = "win" })
reloadBattle.onFinish("win")
local staleReloadFarewell = reload.pushed[#reload.pushed]
reload.handlers["save.loaded"]({ game = reload.game })
eq(reload.wanderers.active, nil, "reload retires old Surprise authority")
eq(#reload.removals, 1, "reload removes old Surprise actor exactly once")
staleReloadFarewell.done()
eq(#reload.removals, 1,
  "late pre-reload callback cannot remove a future actor")

local retry = harness()
local retryBattle = start(retry)
retry.handlers["battle.ended"]({ battle = retryBattle, result = "win" })
retryBattle.onFinish("win")
retry.setRemoveMode("false")
retry.pushed[#retry.pushed].done()
check(retry.wanderers.active ~= nil,
  "failed removeNpc retains exact Surprise authority")
eq(#retry.removals, 1, "failed removal makes one bounded attempt")
retry.setRemoveMode("ok")
retry.handlers["world.stepped"]({ game = retry.game, mapId = "ROUTE_2" })
eq(retry.wanderers.active, nil,
  "next safe world edge retries retained Surprise removal")
eq(#retry.removals, 2, "retained removal succeeds on one explicit retry")

package.preload["src.battle.BattleState"] = priorBattle
package.preload["src.render.TextBox"] = priorTextBox

print(("legacy_wanderer_farewell_lifecycle_test: PASS (%d checks)"):format(checks))
