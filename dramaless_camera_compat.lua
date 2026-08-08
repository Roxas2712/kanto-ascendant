-- Opt-in compatibility camera for the compatible Voxel renderer's enlarged
-- battle rig. The technical export ID remains part of its public API.
--
-- The renderer intentionally moves its telephoto battle camera 1.5x further
-- back to make the larger Stadium models read comfortably.  Kanto Ascendant
-- used the original Dramatic Shape framing, so players who prefer that
-- composition can select CLASSIC VOXEL without editing either renderer.
--
-- Camera position alone does not control the rendered composition in
-- that renderer. frameH is the actual vertical frame size. Its
-- uses larger battle models than the original renderer, so the live-reviewed
-- Classic Voxel framing doubles that size to match the original scale.

return function(mod)
  local C = {}
  local installed = false
  local game
  local originals = setmetatable({}, { __mode = "k" })

  local CLASSIC_TELE = {
    back = 144.96,
    height = 37.88,
    frameH = 34.11 * 2,
  }
  local WIDE_TELE = {
    back = 144.96,
    height = 37.88,
    -- 2x matches the historical Voxel composition. This intentionally goes another
    -- half-step out so tall Mega models, including Charizard, stay in frame
    -- without making the arena impractically distant.
    frameH = 34.11 * 3,
  }

  local function cameraMode()
    if not (mod.options and type(mod.options.get) == "function") then
      return "fork"
    end
    local value = mod.options:get("dramaless_battle_camera")
    if value == "classic" or value == "wide" then return value end
    return "fork"
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
      original = {
        back = tele.back,
        height = tele.height,
        frameH = tele.frameH,
      }
      originals[tele] = original
    end
    local preset = cameraMode() == "classic" and CLASSIC_TELE
      or cameraMode() == "wide" and WIDE_TELE
    if preset then
      tele.back = preset.back
      tele.height = preset.height
      tele.frameH = preset.frameH
    else
      tele.back = original.back
      tele.height = original.height
      tele.frameH = original.frameH
    end
    return true
  end

  function C.install(currentGame)
    game = currentGame or game
    C.apply(game)
    if installed then return true end
    installed = true

    -- The renderer keeps the rig table stable, but re-apply at a native battle
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
  C.WIDE_TELE = WIDE_TELE
  return C
end
