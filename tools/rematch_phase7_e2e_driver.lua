-- Guarded real-LÖVE acceptance for Rematch 2.0 Phase 7.
-- Pass one constructs real field, Elite Four and Champion battles, then
-- writes reserved slot 6707. Pass two proves mastery history survives reload.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local SaveData = require("src.core.SaveData")
  local Overworld = require("src.world.OverworldController")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")

  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("rematch%-phase7"),
    "refusing to write outside rematch-phase7 identity")
  assert(GameVersion.get() == version, "wrong ROM cache mounted")
  assert(SaveData.setActiveSlot(version, "slot6707") == "slot6707")

  local loaded, recovered = SaveData.load()
  if loaded then game:restoreSave(loaded, recovered) end
  U.wait(5)
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  game.save.party = { Pokemon.new(game.data, "RATTATA", 50) }

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local mastery = assert(api.rematchMastery, "mastery export missing")
  local probe = game.save._rematchPhase7Probe
  if probe and probe.stage == 1 then
    local saved = assert(api.trainerStates()[probe.key],
      "mastery trainer state missing after reload")
    assert(saved.masteryWins == probe.masteryWins,
      "post-100 mastery wins did not survive reload")
    assert(saved.rematchProgressionVersion == 3,
      "Phase-7 schema did not survive reload")
    game.save._rematchPhase7Probe.stage = 2
    assert(game:writeSave(), "Phase-7 reload save write failed")
    U.log("REMATCH PHASE 7 RELOAD PASS", version,
      "mastery history and schema persisted")
    love.event.quit(0)
    return
  end

  local record = assert(game.data.trainers.OPP_BUG_CATCHER,
    "Bug Catcher class missing")
  local partyIndex, baseTeam = 1, record.parties[1]
  assert(baseTeam and #baseTeam > 0, "Bug Catcher party missing")
  local key = "PHASE7_" .. version .. "_CAP"
  local states = api.trainerStates()
  states[key] = {
    rematches = 60, trainingCycles = 0, masteryWins = 0, readyAt = 0,
    originalStages = {}, originalBranches = {}, recruitFamilies = {},
    recruitHistory = {},
  }
  game.save.defeatedTrainers = game.save.defeatedTrainers or {}
  game.save.defeatedTrainers[key] = true

  local captured = {}
  local fakeWorld = {
    game = game,
    map = { id = "ROUTE_2", def = { label = "Route2" } }, player = {},
    trainerDefeated = function() return true end,
    pushBattle = function(_, battle) captured[#captured + 1] = battle end,
    afterBattle = function() end,
  }
  local function start()
    local before = #captured
    local npc = {
      id = key, frozen = false,
      def = { trainerClass = "OPP_BUG_CATCHER",
        trainerParty = partyIndex, index = 1, text = "__PHASE7__",
        name = "PHASE7 BUG" },
      facePlayer = function() end,
    }
    Overworld.talkTo(fakeWorld, npc)
    local prompt = assert(game.stack:top(), "rematch prompt missing")
    assert(type(prompt.choice) == "function", "rematch choice missing")
    game.stack:pop()
    prompt.choice(true)
    if #captured == before then
      local warning = assert(game.stack:top(), "strength warning missing")
      assert(type(warning.choice) == "function",
        "strength warning choice missing")
      game.stack:pop()
      warning.choice(true)
    end
    assert(#captured == before + 1, "rematch battle missing")
    return captured[#captured]
  end

  local capBattle = start()
  local capReport = assert(mastery.inspect(capBattle),
    "real field battle has no mastery report")
  assert(capReport.allLevel100, "long-running field trainer did not reach L100")
  for _, row in ipairs(capReport.party) do
    assert(row.level == 100, "field mastery exceeded or missed L100")
    assert(row.quality >= .70 and row.quality <= .80,
      "first L100 quality left its 70-80 percent band")
    for _, stat in ipairs({ "attack", "defense", "speed", "special" }) do
      assert(row.dvs[stat] >= 0 and row.dvs[stat] <= 15,
        "field mastery produced illegal DV")
    end
    for _, stat in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
      assert(row.statExp[stat] >= 0 and row.statExp[stat] <= 65535,
        "field mastery produced illegal stat EXP")
    end
  end
  states[key].masteryWins = 4
  local postBattle = start()
  local postReport = assert(mastery.inspect(postBattle),
    "post-100 field report missing")
  assert(postReport.party[1].quality >= .80
      and postReport.party[1].quality <= .90,
    "post-100 field quality left its 80-90 percent band: "
      .. tostring(postReport.party[1].quality) .. " wins="
      .. tostring(postReport.masteryWins))

  -- Real registered move data: Minimize survives and Driftglass gates the
  -- implemented Generation-II Shadow Ball resonance.
  local function clefairyProbe(wins)
    local value = Pokemon.new(game.data, "CLEFAIRY", 100)
    value.dvs = { hp = 0, attack = 8, defense = 8, speed = 8, special = 8 }
    value.statExp = { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }
    value.moves = {
      { id = "POUND", pp = game.data.moves.POUND.pp },
      { id = "MINIMIZE", pp = game.data.moves.MINIMIZE.pp },
    }
    local valueBattle = { enemyParty = { value } }
    mastery.apply(game, valueBattle, { kind = "debug", key = "CLEFAIRY",
      progress = 50, masteryWins = wins, johtoUnlocked = false })
    return value, valueBattle
  end
  local capClefairy = clefairyProbe(0)
  local clefairy, tactical = clefairyProbe(4)
  assert(clefairy.stats.attack > capClefairy.stats.attack,
    "identical real Pokémon stats did not improve beyond level 100")
  local kept = false
  for _, move in ipairs(clefairy.moves) do
    if move.id == "MINIMIZE" then kept = true end
    assert(move.id ~= "SHADOW_BALL", "Johto move leaked before unlock")
  end
  assert(kept, "real Clefairy lost Minimize")
  local locked = mastery.legalMoves(game, clefairy,
    { johtoUnlocked = false })
  local open = mastery.legalMoves(game, clefairy,
    { johtoUnlocked = true })
  assert(not locked.SHADOW_BALL and open.SHADOW_BALL,
    "real Driftglass move gate did not open exactly on unlock")

  -- Use the production forced-battle constructor and persistent boss counter
  -- for genuine Crown Elite Four and Champion post-100 mastery.
  local ascState = api.ascendant.state()
  ascState.bossBattles["elite:OPP_LORELEI:crown"] = 7
  ascState.bossBattles["elite:OPP_RIVAL3:crown"] = 12
  local lorelei = api.postgame.newForcedBattle(game, "OPP_LORELEI",
    api.postgameData.crown.OPP_LORELEI, "crown")
  api.postgame.applyMastery(game, lorelei,
    { kind = "elite", key = "OPP_LORELEI", tier = "crown" })
  local loreleiReport = assert(mastery.inspect(lorelei),
    "Crown Elite Four mastery report missing")
  assert(loreleiReport.allLevel100 and loreleiReport.party[1].quality >= .875,
    "Crown Elite Four did not continue post-100 mastery")

  local blue = api.postgame.newForcedBattle(game, "OPP_RIVAL3",
    api.postgameData.crown.OPP_RIVAL3, "crown")
  api.postgame.applyMastery(game, blue,
    { kind = "elite", key = "OPP_RIVAL3", tier = "crown" })
  local blueReport = assert(mastery.inspect(blue),
    "Crown Champion mastery report missing")
  assert(blueReport.allLevel100 and blueReport.party[1].quality >= .95,
    "Crown Champion did not approach perfect post-100 mastery")

  postBattle.onFinish("win")
  assert(states[key].masteryWins == 5,
    "won L100 rematch did not increment mastery exactly once")
  game.save._rematchPhase7Probe = {
    stage = 1, key = key, masteryWins = states[key].masteryWins,
  }
  assert(game:writeSave(), "Phase-7 save write failed")
  U.log("REMATCH PHASE 7 WRITE PASS", version,
    "field L100 post100 moves gate tactics Elite Champion")
  love.event.quit(0)
end
