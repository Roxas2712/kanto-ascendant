-- Renderer-backed capture-art evidence driver.
--
-- Run from gen1recomp, once per original palette (red/blue/yellow) and once
-- with the default modern option.  It uses BattleState's actual toss, shake,
-- breakout, no-catch, trainer-block and full-party/PC routes; `SHOT_DIR`
-- receives one PNG per reachable state and ball.
--
-- POKEPORT_DRIVER=/absolute/path/to/tests/journeys_ball_skins_visual_driver.lua \
-- POKEPORT_VERSION=red SHOT_DIR=/tmp/journeys-balls-red love .

return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "KA_PACKAGE_GATE=1 is required; source runs are not package proof")
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/journeys-balls"
  local Pokemon = require("src.pokemon.Pokemon")
  local Boxes = require("src.pokemon.Boxes")
  local BattleState = require("src.battle.BattleState")
  local Bag = require("src.inventory.Bag")
  local ItemEffects = require("src.inventory.ItemEffects")
  local BALLS = {
    "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL", "SAFARI_BALL",
    "FAST_BALL", "LEVEL_BALL", "LURE_BALL", "HEAVY_BALL", "LOVE_BALL",
    "FRIEND_BALL", "MOON_BALL",
  }
  local apricornOnly = os.getenv("JOURNEYS_APRICORN_ONLY") == "1"
  if apricornOnly then
    BALLS = {
      "HEAVY_BALL", "LEVEL_BALL", "LURE_BALL", "FAST_BALL",
      "LOVE_BALL", "FRIEND_BALL", "MOON_BALL",
    }
  end
  local requestedLimit = tonumber(os.getenv("JOURNEYS_BALL_LIMIT"))
  if requestedLimit and requestedLimit >= 1 then
    while #BALLS > math.floor(requestedLimit) do table.remove(BALLS) end
  end

  local mode = (os.getenv("QA_RENDER_MODE") or "2d"):lower()
  assert(mode == "2d" or mode == "full", "bad QA_RENDER_MODE")
  local Pipelines = require("src.render.Pipelines")
  local exports = assert(game.mods and game.mods.exports, "exports missing")
  if mode == "full" then
    assert(exports.DRAMALESS_SHAPE, "FULL closure lacks DRAMALESS")
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    assert(Pipelines.level("voxel") == 1
      and Pipelines.worldPipeline() == "voxel", "FULL pipeline is not active")
  else
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    assert(Pipelines.level("voxel") == 0 and exports.DRAMALESS_SHAPE == nil,
      "2D closure is not flat")
  end
  game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60) }
  -- Explicit visual-route selection for the capture matrix.  The original
  -- route intentionally leaves the native R/B/Y renderer in control.
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.modern_ball_skins =
    os.getenv("JOURNEYS_SKIN") ~= "original"
  game.save.inventory = game.save.inventory or {}
  for _, ball in ipairs(BALLS) do game.save.inventory[ball] = 99 end
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local ow = assert(game.overworld, "overworld required")
  local legalConsumptions, blockedPreserved = 0, 0

  local function waitUntil(pred, frames)
    for _ = 1, frames or 360 do
      if pred() then return true end
      U.wait(1)
    end
    return false
  end
  local function stop(battle)
    for _ = 1, 30 do U.tap(game, "a"); U.wait(3) end
    while game.stack:top() ~= ow do game.stack:pop() end
    U.wait(3)
  end
  -- Queue rows start during Game:update.  Observing `animName` from the next
  -- driver resume can miss a boundary; schedule capture inside the genuine
  -- AnimPlayer:start call so love.draw receives precisely that state.
  local function observeAnimations(battle, plans)
    local player = assert(battle.animPlayer, "battle animation player required")
    local start = player.start
    local drawSprites = player.drawSprites
    player.start = function(self, name, ...)
      local plan = plans[name]
      if plan and not plan.frameAware and not plan.hit then
        plan.hit = true
        game.capturePath = plan.path
      end
      return start(self, name, ...)
    end
    player.drawSprites = function(self, sprites, ...)
      local plan = plans[battle.animName]
      local elapsed = tonumber(player.elapsed) or 0
      if plan and plan.frameAware and not plan.hit and sprites and #sprites > 0
          and elapsed >= (plan.minElapsed or 0) then
        plan.hit = true
        game.capturePath = plan.path
      end
      return drawSprites(self, sprites, ...)
    end
    return plans
  end
  local function waitShot(plan, label)
    assert(waitUntil(function() return plan.hit end, 720), label .. " was not started")
    -- The request was set during update; wait through love.draw's async PNG
    -- write before accepting the driver evidence.
    for _ = 1, 120 do
      local f = io.open(plan.path, "rb")
      if f then
        f:close()
        -- A speed-multiplied driver can otherwise queue the next capture in
        -- the same love.update batch and overwrite capturePath before draw.
        -- Cross two real draw boundaries before advancing to the next state.
        U.wait(math.max(2, (tonumber(os.getenv("POKEPORT_SPEED")) or 1) * 2))
        return true
      end
      U.wait(1)
    end
    error(label .. " screenshot did not reach disk: " .. plan.path)
  end
  local function waitToss(plans, label)
    assert(waitUntil(function()
      return plans.TOSS_ANIM.hit or plans.GREATTOSS_ANIM.hit
        or plans.ULTRATOSS_ANIM.hit
    end, 720), label .. " toss was not started")
    return plans.TOSS_ANIM.hit and plans.TOSS_ANIM
      or plans.GREATTOSS_ANIM.hit and plans.GREATTOSS_ANIM
      or plans.ULTRATOSS_ANIM
  end
  local function beginWild(ball, tag, outcome, noCatch, fullParty, plans)
    game.save.party = { Pokemon.new(game.data, "CHARIZARD", 60) }
    if fullParty then
      for _ = 2, 6 do table.insert(game.save.party, Pokemon.new(game.data, "RATTATA", 5)) end
      -- Fill every real PC box.  The capture still uses BattleState's normal
      -- success chain; only its final destination is the engine's no-space
      -- branch, rather than a synthetic UI state.
      game.save.boxes, game.save.currentBox = nil, 1
      local boxes = Boxes.ensure(game.save)
      for i = 1, Boxes.COUNT do
        for _ = 1, Boxes.CAPACITY do
          table.insert(boxes[i], Pokemon.new(game.data, "RATTATA", 5))
        end
      end
    end
    local battle = BattleState.newWild(game, "PIDGEY", 8)
    battle.onFinish = function() end
    -- The runtime queue remains genuine; only the probability result is
    -- pinned so a visual run cannot randomly skip its requested state.
    -- `{ false, 3 }` is breakout after three shakes, `{ true, 3 }` success.
    if outcome then
      battle.catchAttempt = function() return outcome[1], outcome[2] end
    end
    plans = observeAnimations(battle, plans or {})
    battle.noCatch = noCatch or false
    ow:pushBattle(battle)
    assert(waitUntil(function() return game.stack:top() == battle end, 360),
      tag .. " battle transition did not finish")
    -- Wait for the genuine intro (including its own POOF/send-out) before
    -- injecting the ball.  A fixed number of taps races presentation packs.
    assert(waitUntil(function()
      if battle.phase == "menu" then return true end
      U.tap(game, "a")
      return false
    end, 720), tag .. " battle did not reach command menu")
    battle.phase, battle.afterQueue = "messages", "menu"
    local before = assert(game.save.inventory[ball], ball .. " is absent from the Bag")
    local action = ItemEffects.use(game.data, game.save, ball, nil, battle)
    if noCatch then
      assert(action == "failed", ball .. " no-catch preflight was not blocked")
      assert(game.save.inventory[ball] == before,
        ball .. " no-catch preflight changed the Bag")
      blockedPreserved = blockedPreserved + 1
    else
      assert(action == "ball", ball .. " legal preflight did not reach Ball flow")
      Bag.remove(game.save, ball, 1)
      assert(game.save.inventory[ball] == before - 1,
        ball .. " legal throw did not consume exactly one Ball")
      legalConsumptions = legalConsumptions + 1
    end
    battle:throwBall(ball)
    -- `throwBall` prepends the regular "used BALL" message before the
    -- animation chain.  Advance it exactly as the battle UI does; otherwise
    -- a direct driver call can sit on text forever and falsely report a
    -- missing Toss animation.
    for _ = 1, 4 do U.tap(game, "a"); U.wait(4) end
    return battle, plans
  end

  for _, ball in ipairs(BALLS) do
    -- A high result produces the native roll/shake then breakout path.
    local plans = {
      TOSS_ANIM = { path = ("%s/%s_toss.png"):format(DIR, ball), frameAware=true, minElapsed=6 },
      GREATTOSS_ANIM = { path = ("%s/%s_toss.png"):format(DIR, ball), frameAware=true, minElapsed=6 },
      ULTRATOSS_ANIM = { path = ("%s/%s_toss.png"):format(DIR, ball), frameAware=true, minElapsed=6 },
      SHAKE_ANIM = { path = ("%s/%s_roll_shake.png"):format(DIR, ball), frameAware=true, minElapsed=12 },
      SHOWPIC_ANIM = { path = ("%s/%s_breakout.png"):format(DIR, ball) },
    }
    local b; b, plans = beginWild(ball, "breakout", { false, 3 }, nil, nil, plans)
    waitShot(waitToss(plans, ball), ball .. " toss")
    waitShot(plans.SHAKE_ANIM, ball .. " roll/shake")
    waitShot(plans.SHOWPIC_ANIM, ball .. " breakout")
    stop(b)

    -- A low result reaches the success chain.  The full-party / full-PC
    -- variation uses the same real success animation then exercises the
    -- engine destination branch with no free storage slot.
    plans = {
      SHAKE_ANIM = { path = ("%s/%s_success_shake.png"):format(DIR, ball), frameAware=true, minElapsed=21 },
    }
    b, plans = beginWild(ball, "success", { true, 3 }, false, true, plans)
    waitShot(plans.SHAKE_ANIM, ball .. " success")
    assert(waitUntil(function() return b.lockedBall ~= nil end, 720),
      ball .. " success did not leave a locked ball")
    assert(U.shot(game, ("%s/%s_success_full_box.png"):format(DIR, ball)))
    stop(b)

    plans = {
      TOSS_ANIM = { path = ("%s/%s_no_catch.png"):format(DIR, ball), frameAware=true, minElapsed=10 },
      GREATTOSS_ANIM = { path = ("%s/%s_no_catch.png"):format(DIR, ball), frameAware=true, minElapsed=10 },
      ULTRATOSS_ANIM = { path = ("%s/%s_no_catch.png"):format(DIR, ball), frameAware=true, minElapsed=10 },
    }
    b, plans = beginWild(ball, "no_catch", nil, true, nil, plans)
    waitShot(waitToss(plans, ball .. " no-catch"), ball .. " no-catch")
    stop(b)
  end

  -- Trainer block is independent of catch rolls; render it once for each
  -- master so the BLOCKBALL OAM state is evidenced per asset.
  for _, ball in ipairs(BALLS) do
    local b = BattleState.newTrainer(game, "OPP_YOUNGSTER", 1)
    b.onFinish = function() end
    ow:pushBattle(b)
    assert(waitUntil(function() return game.stack:top() == b end, 360),
      ball .. " trainer battle transition did not finish")
    assert(waitUntil(function()
      if b.phase == "menu" then return true end
      U.tap(game, "a")
      return false
    end, 720), ball .. " trainer battle did not reach command menu")
    local block = observeAnimations(b, {
      BLOCKBALL_ANIM = { path = ("%s/%s_block.png"):format(DIR, ball) },
    })
    b.phase, b.afterQueue = "messages", "menu"
    -- The installed Apricorn ItemEffect refuses a trainer throw before the
    -- Bag consumes anything.  The direct BattleState call that follows is
    -- renderer-only: it captures the stock BLOCKBALL frame while this
    -- assertion proves that normal gameplay preserved the inventory.
    local before = assert(game.save.inventory[ball])
    local action = ItemEffects.use(game.data, game.save, ball, nil, b)
    assert(action == "failed", ball .. " trainer preflight was not blocked")
    assert(game.save.inventory[ball] == before,
      ball .. " trainer preflight changed the Bag")
    blockedPreserved = blockedPreserved + 1
    b:throwBall(ball)
    for _ = 1, 4 do U.tap(game, "a"); U.wait(4) end
    waitShot(block.BLOCKBALL_ANIM, ball .. " trainer block")
    stop(b)
  end
  -- Per Ball: toss, roll/shake, breakout, success shake, full-box success,
  -- no-catch toss and trainer block.
  local states = #BALLS * 7
  local resultPath = os.getenv("JOURNEYS_VISUAL_RESULT")
    or (DIR .. "/journeys_visual_result.txt")
  local out = assert(io.open(resultPath, "wb"),
    "could not write Journeys visual receipt")
  out:write("status=PASS\n")
  out:write("scope=JOURNEYS-APRICORN-VISUALS\n")
  out:write("renderer=", mode, "\n")
  out:write("balls=", tostring(#BALLS), "/", tostring(#BALLS), "\n")
  out:write("states=", tostring(states), "/", tostring(states), "\n")
  out:write("legal_consumptions=", tostring(legalConsumptions), "/",
    tostring(#BALLS * 2), "\n")
  out:write("blocked_preserved=", tostring(blockedPreserved), "/",
    tostring(#BALLS * 2), "\n")
  out:close()
  U.log("PASS Journeys ball screenshot matrix:", DIR)
  love.event.quit(0)
end
