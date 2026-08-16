-- Real-LOVE capture-animation matrix for all five Gen-I ball items plus the
-- uncapturable-target and trainer-block paths.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local DIR = os.getenv("SHOT_DIR") or "/tmp/ka65-ball-capture"
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")

  local pass, fail = 0, 0
  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  game.save.party = { Pokemon.new(game.data, "PIKACHU", 15) }
  game.save.pokedex = game.save.pokedex or { owned = {}, seen = {} }
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local overworld = game.overworld

  local function reachMove(battle, wanted, limit)
    for frame = 1, (limit or 900) do
      local player = battle.animPlayer
      if player and player.__ascendantBallMove == wanted
          and not player:isDone() then
        local step = player.steps[player.stepIndex]
        if step and #step.sprites > 0 then return true end
      end
      if frame % 8 == 0 then U.tap(game, "a") end
      U.wait(1)
    end
    return false
  end

  local function finishBattle(battle)
    for _ = 1, 180 do
      if game.stack:top() == overworld then return true end
      U.tap(game, "a")
      U.wait(2)
    end
    while game.stack:top() ~= overworld do game.stack:pop() end
    U.wait(2)
    return false
  end

  local function attempt(tag, ball, rng, caught)
    local battle = BattleState.newWild(game, "PIDGEY", 8)
    battle.onFinish = function() end
    battle.rng = rng
    overworld:pushBattle(battle)
    for _ = 1, 16 do U.tap(game, "a"); U.wait(4) end
    battle.phase = "messages"
    battle.afterQueue = "menu"
    battle:throwBall(ball)

    local toss = ball == "POKE_BALL" and "TOSS_ANIM"
      or ball == "GREAT_BALL" and "GREATTOSS_ANIM"
      or "ULTRATOSS_ANIM"
    check(tag .. " reaches toss", reachMove(battle, toss))
    check(tag .. " toss screenshot",
      U.shot(game, ("%s/%s_toss.png"):format(DIR, tag)))
    U.wait(5)
    check(tag .. " rolling toss screenshot",
      U.shot(game, ("%s/%s_toss_roll.png"):format(DIR, tag)))

    check(tag .. " reaches closed-ball shake",
      reachMove(battle, "SHAKE_ANIM"))
    check(tag .. " shake screenshot",
      U.shot(game, ("%s/%s_shake.png"):format(DIR, tag)))

    if caught then
      for _ = 1, 180 do
        if battle.lockedBall then break end
        U.wait(1)
      end
      check(tag .. " leaves one locked success ball",
        type(battle.lockedBall) == "table"
          and #battle.lockedBall == 4)
      check(tag .. " success screenshot",
        U.shot(game, ("%s/%s_success.png"):format(DIR, tag)))
    else
      check(tag .. " reaches escape poof",
        reachMove(battle, "POOF_ANIM"))
      check(tag .. " escape screenshot",
        U.shot(game, ("%s/%s_escape.png"):format(DIR, tag)))
      -- SHOWPIC is a very short zero-damage effect and can complete between
      -- a screenshot request and the next driver tick. Its durable contract
      -- is that the enemy picture is visible again after the breakout.
      local restored = false
      for _ = 1, 120 do
        if battle.enemyHidden == false then restored = true; break end
        U.wait(1)
      end
      check(tag .. " restores the wild Pokémon", restored)
    end

    finishBattle(battle)
  end

  local function noCatchAttempt()
    local battle = BattleState.newWild(game, "PIDGEY", 8)
    battle.onFinish = function() end
    battle.noCatch = true
    overworld:pushBattle(battle)
    for _ = 1, 16 do U.tap(game, "a"); U.wait(4) end
    battle.phase = "messages"
    battle.afterQueue = "menu"
    battle:throwBall("ULTRA_BALL")
    check("uncatchable reaches Ultra Ball toss",
      reachMove(battle, "ULTRATOSS_ANIM"))
    check("uncatchable Ultra Ball screenshot",
      U.shot(game, DIR .. "/ultra_uncatchable_toss.png"))
    finishBattle(battle)
  end

  local function trainerBlockAttempt()
    local battle = BattleState.newTrainer(game, "OPP_YOUNGSTER", 1)
    battle.onFinish = function() end
    overworld:pushBattle(battle)
    for _ = 1, 16 do U.tap(game, "a"); U.wait(4) end
    battle.phase = "messages"
    battle.afterQueue = "menu"
    battle:throwBall("MASTER_BALL")
    check("trainer block reaches Master Ball toss",
      reachMove(battle, "TOSS_ANIM"))
    check("trainer Master Ball toss screenshot",
      U.shot(game, DIR .. "/master_trainer_toss.png"))
    check("trainer block keeps the Master Ball skin",
      reachMove(battle, "BLOCKBALL_ANIM"))
    check("trainer blocked Master Ball screenshot",
      U.shot(game, DIR .. "/master_trainer_block.png"))
    finishBattle(battle)
  end

  attempt("poke_breakout", "POKE_BALL",
    function(_, upper) return upper end, false)
  attempt("great_caught", "GREAT_BALL",
    function(lower) return lower end, true)
  attempt("ultra_breakout", "ULTRA_BALL",
    function(_, upper) return upper end, false)
  attempt("master_caught", "MASTER_BALL",
    function(lower) return lower end, true)
  attempt("safari_caught", "SAFARI_BALL",
    function(lower) return lower end, true)
  noCatchAttempt()
  trainerBlockAttempt()

  U.log(("RESULT pass=%d fail=%d"):format(pass, fail))
end
