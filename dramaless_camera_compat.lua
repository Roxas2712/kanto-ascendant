-- Opt-in compatibility camera for DRAMALESS_SHAPE's enlarged battle rig.
--
-- Dramaless intentionally moves its telephoto battle camera 1.5x further
-- back to make the larger Stadium models read comfortably.  Kanto Ascendant
-- used the original Dramatic Shape framing, so players who prefer that
-- composition can select CLASSIC VOXEL without editing either renderer.

return function(mod)
  local C = {}
  local installed = false
  local game
  local originals = setmetatable({}, { __mode = "k" })

  local CLASSIC_TELE = {
    back = 144.96,
    height = 37.88,
  }

  local function classicEnabled()
    return mod.options and type(mod.options.get) == "function"
      and mod.options:get("dramaless_battle_camera") == "classic"
  end

  local function battleCam(currentGame)
    local exports = currentGame and currentGame.mods
      and currentGame.mods.exports
    local dramatic = exports and exports.DRAMALESS_SHAPE
    if not (dramatic and dramatic.lib
        and type(dramatic.lib.require) == "function") then
      return nil
    end
    local ok, camera = pcall(dramatic.lib.require, "BattleCam")
    return ok and type(camera) == "table" and camera or nil
  end

  function C.apply(currentGame)
    local camera = battleCam(currentGame or game)
    local tele = camera and camera.RIGS and camera.RIGS.tele
    if type(tele) ~= "table" then return false end

    local original = originals[tele]
    if not original then
      original = { back = tele.back, height = tele.height }
      originals[tele] = original
    end
    if classicEnabled() then
      tele.back = CLASSIC_TELE.back
      tele.height = CLASSIC_TELE.height
    else
      tele.back = original.back
      tele.height = original.height
    end
    return true
  end

  function C.install(currentGame)
    game = currentGame or game
    C.apply(game)
    if installed then return true end
    installed = true

    -- Dramaless keeps the rig table stable, but re-apply at a native battle
    -- boundary in case a future renderer update rebuilds its camera module.
    mod.events:on("battle.started", function(ev)
      C.apply(ev and ev.battle and ev.battle.game or game)
    end, 250)
    mod.events:on("mod.options_changed", function(ev)
      if ev and ev.mod == mod.id and ev.key == "dramaless_battle_camera" then
        C.apply(game)
      end
    end, 250)
    return true
  end

  C.CLASSIC_TELE = CLASSIC_TELE
  return C
end
