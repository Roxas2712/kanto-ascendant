-- Guarded real-LÖVE acceptance for Rematch 2.0 Phase 6.
-- Pass one constructs real trainer battles through the installed overworld
-- talk hook and writes reserved slot 6606. Pass two reloads the process and
-- proves compact progression/history persistence.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local SaveData = require("src.core.SaveData")
  local Overworld = require("src.world.OverworldController")
  local BattleState = require("src.battle.BattleState")

  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("rematch%-phase6"),
    "refusing to write outside rematch-phase6 identity")
  assert(GameVersion.get() == version, "wrong ROM cache mounted")
  assert(SaveData.setActiveSlot(version, "slot6606") == "slot6606")

  local loaded, recovered = SaveData.load()
  if loaded then game:restoreSave(loaded, recovered) end
  U.wait(5)

  -- Driver boots begin on the title skeleton. A real overworld is required
  -- for the production save capture path, and a healthy party keeps the real
  -- trainer constructor on its ordinary battle path.
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  local Pokemon = require("src.pokemon.Pokemon")
  game.save.party = { Pokemon.new(game.data, "RATTATA", 50) }

  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local probe = game.save._rematchPhase6Probe
  if probe and probe.stage == 1 then
    local states = api.trainerStates()
    local won = assert(states[probe.winKey], "won trainer state missing")
    local lost = assert(states[probe.lossKey], "lost trainer state missing")
    assert(won.rematches == probe.wins,
      "successful rematch count did not survive reload")
    assert(lost.rematches == probe.losses,
      "loss-only trainer count changed after reload")
    assert(won.rematchProgressionVersion == 3,
      "Phase-7 trainer state version did not survive reload")
    assert(type(won.originalStages) == "table"
        and next(won.originalStages) ~= nil,
      "original evolution progression did not survive reload")
    assert(type(won.recruitHistory) == "table" and #won.recruitHistory >= 1,
      "anti-repeat history did not survive reload")
    assert(#won.recruitHistory <= 3,
      "compact history exceeded its three-rematch cap")
    game.save._rematchPhase6Probe.stage = 2
    assert(game:writeSave(), "Phase-6 reload save write failed")
    U.log("REMATCH PHASE 6 RELOAD PASS", version,
      "stable per-trainer wins evolution and anti-repeat history")
    love.event.quit(0)
    return
  end

  game.save.player.name = "PHASE6"
  game.save.defeatedTrainers = game.save.defeatedTrainers or {}
  local record = assert(game.data.trainers.OPP_BUG_CATCHER,
    "Bug Catcher class missing")
  local partyIndex, baseTeam
  for index, team in ipairs(record.parties or {}) do
    for _, slot in ipairs(team) do
      local def = game.data.pokemon[slot.species]
      if def and #(def.evolutions or {}) > 0 then
        partyIndex, baseTeam = index, team
        break
      end
    end
    if partyIndex then break end
  end
  assert(partyIndex and baseTeam, "no progressive Bug Catcher party found")

  -- A normal constructor remains untouched and does not become a rematch.
  local ordinary = BattleState.newTrainer(game, "OPP_BUG_CATCHER", partyIndex)
  assert(not ordinary.rematch and #ordinary.enemyParty == #baseTeam,
    "ordinary trainer construction was modified by Rematch 2.0")

  local function fakeNpc(id)
    return {
      id = id, frozen = false,
      def = { trainerClass = "OPP_BUG_CATCHER",
        trainerParty = partyIndex, index = 1, text = "__PHASE6__",
        name = "PHASE6 BUG" },
      facePlayer = function() end,
    }
  end

  local captured, afterResults = {}, {}
  local fakeWorld = {
    map = { id = "ROUTE_2", def = { label = "Route2" } },
    player = {},
    trainerDefeated = function() return true end,
    pushBattle = function(_, battle) captured[#captured + 1] = battle end,
    afterBattle = function(_, result)
      afterResults[#afterResults + 1] = result
    end,
  }

  local states = api.trainerStates()
  local winKey = "PHASE6_" .. version .. "_WIN"
  local lossKey = "PHASE6_" .. version .. "_LOSS"
  states[winKey] = { rematches = 6, trainingCycles = 0, readyAt = 0,
    originalStages = {}, originalBranches = {}, recruitFamilies = {},
    recruitHistory = {} }
  states[lossKey] = { rematches = 3, trainingCycles = 0, readyAt = 0,
    originalStages = {}, originalBranches = {}, recruitFamilies = {},
    recruitHistory = {} }
  for index = 1, #baseTeam do states[winKey].originalStages[index] = 9 end

  local function start(id)
    local npc = fakeNpc(id)
    game.save.defeatedTrainers[id] = true
    Overworld.talkTo(fakeWorld, npc)
    local prompt = game.stack:top()
    assert(prompt and type(prompt.choice) == "function",
      "real rematch prompt did not open")
    game.stack:pop()
    prompt.choice(true)
    local battle = captured[#captured]
    assert(battle and battle.rematch and battle.rematchTrainerKey == id,
      "real rematch battle was not constructed for the stable trainer key")
    return battle
  end

  local wonBattle = start(winKey)
  assert(wonBattle.rematchNumber == 7,
    "won trainer did not use its persisted next rematch number")
  assert(wonBattle.rematchOriginalEvolutions > 0,
    "real battle did not apply persisted original-family evolution")
  assert(wonBattle.rematchRecruits > 0,
    "long-running real trainer did not gain gradual additional members")
  assert(#wonBattle.enemyParty <= 6,
    "real rematch exceeded the engine team-size limit")
  for _, mon in ipairs(wonBattle.enemyParty) do
    assert(mon.level >= 1 and mon.level <= 100,
      "real rematch generated an illegal level")
  end
  wonBattle.onFinish("win")
  assert(states[winKey].rematches == 7,
    "successful real rematch did not increment exactly once")
  assert(states[winKey].rematchProgressionVersion == 3,
    "successful real rematch did not migrate Phase-7 mastery state")
  assert(#states[winKey].recruitHistory == 1,
    "real battle did not record one transient-team history row")

  local lostBattle = start(lossKey)
  local beforeLoss = states[lossKey].rematches
  lostBattle.onFinish("loss")
  assert(states[lossKey].rematches == beforeLoss,
    "lost real rematch incremented the win count")
  assert(afterResults[#afterResults - 1] == "win"
      and afterResults[#afterResults] == "loss",
    "real afterBattle results were not preserved")

  game.save._rematchPhase6Probe = {
    stage = 1, winKey = winKey, lossKey = lossKey,
    wins = states[winKey].rematches, losses = states[lossKey].rematches,
  }
  assert(game:writeSave(), "Phase-6 save write failed")
  U.log("REMATCH PHASE 6 WRITE PASS", version,
    "ordinary battle win-only count original evolution recruits cap")
  love.event.quit(0)
end
