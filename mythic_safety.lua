-- Scoped Nuzlocke compatibility for Kanto Ascendant's mythical encounters.

return function(mod)
  local M = {}
  local PROTECTED = { HO_OH = true, CELEBI = true, MEW = true }
  local protectedReturns = setmetatable({}, { __mode = "k" })
  local RETURN_GUARD_KEY = "_kantoAscendantMythicReturnGuard"

  function M.classify(battle)
    local mon = battle and battle.enemy and battle.enemy.mon
    local species = mon and mon.species
    if not PROTECTED[species] then return nil end
    if battle.ascendantMew and species == "MEW" then return "ascendant_mew" end
    if battle.postgameLegend == species then return "postgame_legend" end
    if battle.kaMythicTrue == species then return "mythic_true" end
    if battle.kaMythicEcho == species then return "mythic_echo" end
    return nil
  end

  local function withNuzlockeExemption(original, self, ...)
    local previous = self.demo
    self.demo = true
    local ok, a, b, c = pcall(original, self, ...)
    self.demo = previous
    if not ok then error(a, 0) end
    return a, b, c
  end

  function M.isProtectedReturn(save)
    return save ~= nil and (protectedReturns[save] or 0) > 0
  end

  local function beginProtectedReturn(save)
    if save then protectedReturns[save] = (protectedReturns[save] or 0) + 1 end
  end

  local function endProtectedReturn(save)
    local count = save and protectedReturns[save] or 0
    if count <= 1 then protectedReturns[save] = nil
    else protectedReturns[save] = count - 1 end
  end

  M._beginProtectedReturn = beginProtectedReturn
  M._endProtectedReturn = endProtectedReturn

  function M.installGuard()
    local BattleState = require("src.battle.BattleState")
    if not BattleState._kantoAscendantMythicSafety then
      for _, method in ipairs({ "onFaint", "playerMonFainted" }) do
        local original = BattleState[method]
        if type(original) == "function" then
          BattleState[method] = function(self, ...)
            if not self.ascendantMythicProtected then
              return original(self, ...)
            end
            return withNuzlockeExemption(original, self, ...)
          end
        end
      end
      BattleState._kantoAscendantMythicSafety = true
    end

    -- OverworldState emits world.blacked_out synchronously from afterBattle.
    -- Publish a transient, save-scoped receipt only during that authored
    -- return path; it cannot leak and forgive a later ordinary blackout.
    local okOverworld, OverworldState = pcall(require,
      "src.world.OverworldController")
    if okOverworld and type(OverworldState) == "table"
        and type(OverworldState.afterBattle) == "function" then
      local prior = rawget(OverworldState, RETURN_GUARD_KEY)
      if type(prior) == "table" and type(prior.wrapped) == "function" then
        prior.controller = M
      else
        local original = OverworldState.afterBattle
        local state = { original = original, controller = M }
        state.wrapped = function(self, result, battle, ...)
          local live = rawget(OverworldState, RETURN_GUARD_KEY)
          local controller = live and live.controller or M
          local save = battle and battle.game and battle.game.save
          local protected = result == "lose" and save
            and controller and controller.classify
            and controller.classify(battle) ~= nil
          if protected then controller._beginProtectedReturn(save) end
          local out = { pcall(original, self, result, battle, ...) }
          if protected then controller._endProtectedReturn(save) end
          if not out[1] then error(out[2], 0) end
          return unpack(out, 2)
        end
        OverworldState.afterBattle = state.wrapped
        rawset(OverworldState, RETURN_GUARD_KEY, state)
      end
    end
    return BattleState
  end

  function M.protect(battle)
    local source = M.classify(battle)
    if not source then return false end
    battle.ascendantMythicProtected = source
    M.installGuard()
    return true
  end

  -- Mythic Signals applies its encounter ticket at priority 500. Running
  -- later lets this handler recognize both its echo and true manifestations.
  mod.events:on("battle.started", function(ev)
    M.protect(ev and ev.battle)
  end, -1000)

  return M
end
