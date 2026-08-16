-- Full renderer-backed rival acceptance matrix.
--
-- Every authored rival encounter is opened for all three player identities
-- and all three starter branches: 8 stages x 3 identities x 3 branches =
-- 72 live trainer introductions.  Construction alone is not sufficient:
-- the driver also verifies the loaded Crystal front/back cards and writes a
-- screenshot for every individual battle.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant)
  local characters = assert(exports.extendedCharacters)
  local rivalTeams = assert(exports.rivalTeams)
  local pass, fail, liveCount = 0, 0, 0

  local function check(label, value)
    if value then pass = pass + 1 else fail = fail + 1 end
    U.log(value and "PASS" or "FAIL", label)
  end

  local function clearBattle(battle)
    -- Preserve the live overworld below the battle.  Emptying the complete
    -- stack can make the engine quit between identity blocks before the
    -- coroutine gets a chance to stage the next fight.
    while game.stack:top() and game.stack:top() ~= battle do
      game.stack:pop()
    end
    if game.stack:top() == battle then game.stack:pop() end
  end

  local function endsWith(value, suffix)
    return type(value) == "string" and value:sub(-#suffix) == suffix
  end

  local function rosterString(rows)
    local out = {}
    for _, row in ipairs(rows or {}) do
      out[#out + 1] = tostring(row.species) .. ":" .. tostring(row.level)
    end
    return table.concat(out, ",")
  end

  local identities = {
    { player = "RED", rival = "BLUE" },
    { player = "BLUE", rival = "GREEN" },
    { player = "GREEN", rival = "RED" },
  }
  local rbStages = {
    { id = "oaks_lab", class = "OPP_RIVAL1", first = 1 },
    { id = "route22_first", class = "OPP_RIVAL1", first = 4 },
    { id = "cerulean", class = "OPP_RIVAL1", first = 7 },
    { id = "ss_anne", class = "OPP_RIVAL2", first = 1 },
    { id = "pokemon_tower", class = "OPP_RIVAL2", first = 4 },
    { id = "silph", class = "OPP_RIVAL2", first = 7 },
    { id = "route22_second", class = "OPP_RIVAL2", first = 10 },
    { id = "champion", class = "OPP_RIVAL3", first = 1 },
  }
  -- Yellow authors one fixed early progression, then three Eevee-evolution
  -- branches for the later fights.  Its trainer tables therefore contain
  -- 16 real rival parties per identity rather than Red/Blue's 24.  Exercise
  -- every actual Yellow slot; never manufacture the absent early branches.
  local yellowStages = {
    { id = "oaks_lab", class = "OPP_RIVAL1", indexes = { 1 } },
    { id = "route22_first", class = "OPP_RIVAL1", indexes = { 2 } },
    { id = "cerulean", class = "OPP_RIVAL1", indexes = { 3 } },
    { id = "ss_anne", class = "OPP_RIVAL2", indexes = { 1 } },
    { id = "pokemon_tower", class = "OPP_RIVAL2", indexes = { 2, 3, 4 } },
    { id = "silph", class = "OPP_RIVAL2", indexes = { 5, 6, 7 } },
    { id = "route22_second", class = "OPP_RIVAL2", indexes = { 8, 9, 10 } },
    { id = "champion", class = "OPP_RIVAL3", indexes = { 1, 2, 3 } },
  }
  local stages = GameVersion.isYellow() and yellowStages or rbStages
  local expectedPerIdentity = GameVersion.isYellow() and 16 or 24
  local expectedLive = expectedPerIdentity * #identities
  local shotIndex = 0

  check("Crystal character family is the active default",
    characters.characterStyle() == "crystal")
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  for identityIndex, identity in ipairs(identities) do
    local state = characters.select(identity.player)
    characters.refreshVisuals(game)
    game.save.player.name = identity.player == "GREEN" and "CASEY"
      or identity.player
    game.save.player.rival = identity.rival
    game.save.party = { Pokemon.new(game.data, "PIKACHU", 100) }

    check(identity.player .. " maps to rival " .. identity.rival,
      state.player_character == identity.player
        and state.rival_character == identity.rival)

    local expectedFront = "assets/characters/crystal_chars/"
      .. identity.rival:lower() .. "_front.png"
    local expectedBack = "assets/characters/crystal_chars/"
      .. identity.player:lower() .. "_back.png"
    local rivalFront = assert(characters.getRivalSprite("rivalPortrait"))
    local playerBack = assert(characters.getPlayerSprite("battleBack"))
    check(identity.rival .. " resolver owns exact Crystal rival front",
      endsWith(rivalFront.path, expectedFront)
        and not rivalFront.path:find("frlg", 1, true)
        and not rivalFront.path:find("walk", 1, true))
    check(identity.player .. " resolver owns exact Crystal battle back",
      endsWith(playerBack.path, expectedBack)
        and not playerBack.path:find("frlg", 1, true)
        and not playerBack.path:find("walk", 1, true))

    for stageIndex, stage in ipairs(stages) do
      local trainer = assert(game.data.trainers[stage.class], stage.class)
      local indexes = stage.indexes
      if not indexes then
        indexes = { stage.first, stage.first + 1, stage.first + 2 }
      end
      for branch, partyIndex in ipairs(indexes) do
        local vanilla = assert(trainer.parties[partyIndex])
        local expected = rivalTeams.resolve(identity.rival, stage.class,
          partyIndex, vanilla)
        local battle = BattleState.newTrainer(game, stage.class, partyIndex)
        local exact = rosterString(battle.enemyParty) == rosterString(expected)
        local label = ("%s vs %s %s branch %d"):format(
          identity.player, identity.rival, stage.id, branch)
        U.log("ROSTER", label, rosterString(battle.enemyParty))
        check(label .. " exact species and levels", exact)

        U.teleport(game, "ROUTE_1", 5, 5, "down")
        game.overworld:pushBattle(battle)
        local introReady = false
        for _ = 1, 480 do
          if game.stack:top() == battle and battle.showEnemyTrainer
              and battle.showPlayerBack then
            introReady = true
            break
          end
          U.wait(1)
        end
        liveCount = liveCount + 1
        check(label .. " reaches live trainer introduction", introReady)

        if introReady then
          local frontW, frontH = battle.trainerPic:getDimensions()
          local backW, backH = battle.playerBackPic:getDimensions()
          check(label .. " loads native 64x64 Crystal front",
            frontW == 64 and frontH == 64)
          check(label .. " loads native 64x64 Crystal back",
            backW == 64 and backH == 64)
        else
          check(label .. " loads native 64x64 Crystal front", false)
          check(label .. " loads native 64x64 Crystal back", false)
        end

        -- The intro flags become visible as soon as the native sprites start
        -- sliding in.  Wait for the real Gen-I slide to finish so every QA
        -- screenshot proves the settled, fully visible front/back pair rather
        -- than recording a legitimate but misleading transition frame.
        for _ = 1, 80 do
          if (battle.introSlide or 0) <= 0 then break end
          U.wait(1)
        end
        U.wait(2)
        shotIndex = shotIndex + 1
        local shotName = ("%02d_%s_vs_%s_%s_b%d.png"):format(
          shotIndex,
          identity.player:lower(), identity.rival:lower(), stage.id, branch)
        check(label .. " screenshot written",
          U.shot(game, dir .. "/" .. shotName))
        clearBattle(battle)
        U.wait(2)
      end
    end
  end

  check(("all %d authored rival battles entered live"):format(expectedLive),
    liveCount == expectedLive)
  U.log(("PHASE8 ALL RIVAL BATTLES RESULT pass=%d fail=%d live=%d expected=%d version=%s")
    :format(pass, fail, liveCount, expectedLive, GameVersion.get()))
  love.event.quit(fail == 0 and 0 or 1)
end
