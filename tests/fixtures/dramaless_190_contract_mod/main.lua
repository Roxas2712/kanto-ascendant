-- Closed no-asset fixture for the reviewed DRAMALESS legacy module facade.
-- It exists only to exercise KASC's non-Battle-Art trainer source seam.

return function(mod)
  local stage = { active = false, finishCalls = 0 }
  local function sideTexture(battle, side)
    if side == "enemy" and battle and battle.showEnemyTrainer then
      return {
        sourceOwner = "DRAMALESS_NATIVE_TRAINER_CARD",
        sourceIdentity = battle.oppClass,
      }
    end
    return { sourceOwner = "DRAMALESS_OTHER_CARD" }
  end
  local overworldBattle = { sideTexture = sideTexture }
  function overworldBattle.begin(_, battle)
    stage.active, stage.battle = true, battle
    return true
  end
  function overworldBattle.ensure(battle)
    if not stage.active then return overworldBattle.begin(nil, battle) end
    return true
  end
  function overworldBattle.finish()
    stage.active, stage.battle = false, nil
    stage.finishCalls = stage.finishCalls + 1
  end

  local modules = { OverworldBattle = overworldBattle }
  local lib = {}
  function lib.require(name) return modules[name] end

  mod.exports.version = "1.6.2-ST.190.1"
  mod.exports.lib = lib
  mod.exports.overworldBattle = overworldBattle
  mod.exports.originalSideTexture = sideTexture
  mod.exports.stage = stage
end
