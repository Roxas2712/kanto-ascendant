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

return function(mod, opts)
  opts = opts or {}
  local C = {}
  local function sharedVoxelResolver(provided)
    if provided then return provided end
    if mod.exports and mod.exports.voxelRendererCompat then
      return mod.exports.voxelRendererCompat
    end
    local chunk
    if type(mod.read) == "function" then
      local body = mod:read("voxel_renderer_compat.lua")
      if type(body) == "string" then
        chunk = loadstring(body, "@voxel_renderer_compat.lua")
      end
    end
    local ok, factory = false, nil
    if chunk then
      ok, factory = pcall(chunk)
    else
      ok, factory = pcall(require, "voxel_renderer_compat")
    end
    local made, resolver = false, nil
    if ok and type(factory) == "function" then
      made, resolver = pcall(factory, mod)
    end
    return made and resolver or nil
  end
  local voxelRenderer = sharedVoxelResolver(opts.voxelRenderer)
  local installed = false
  local game
  local originals = setmetatable({}, { __mode = "k" })

  local CLASSIC_TELE = {
    back = 144.96,
    height = 37.88,
    -- Full standing Crystal trainer cards need more vertical headroom than
    -- Pokémon fronts. Keep the close classic composition without clipping
    -- caps or hair during the intro orbit.
    frameH = 34.11 * 3,
  }
  local WIDE_TELE = {
    back = 144.96,
    height = 37.88,
    -- 2x matches the historical Voxel composition. This intentionally goes another
    -- half-step out so tall Mega models, including Charizard, stay in frame
    -- without making the arena impractically distant.
    frameH = 34.11 * 3,
  }
  -- Oak's Lab uses the renderer's short indoor rig. Open only its lens so two
  -- standing trainer cards fit without changing the authored world cells.
  local OAKS_LAB_WIDE_FRAME_H = 55.62 * 1.35

  local function cameraMode()
    if not (mod.options and type(mod.options.get) == "function") then
      return "wide"
    end
    local value = mod.options:get("dramaless_battle_camera")
    if value == "fork" or value == "classic" or value == "wide" then
      return value
    end
    return "wide"
  end

  local function cameraRenderer(currentGame)
    if not (voxelRenderer and type(voxelRenderer.resolve) == "function") then
      return nil
    end
    local _, rendererId = voxelRenderer.resolve(currentGame)
    -- Battle Art owns its authored camera rigs and its own camera/options
    -- menu. This legacy KASC choice applies only to Voxel Ascendant and the
    -- reviewed Dramaless transition build.
    if rendererId ~= "VOXEL_ASCENDANT"
        and rendererId ~= "DRAMALESS_SHAPE" then return nil end
    return rendererId
  end

  local function battleCam(currentGame)
    if not cameraRenderer(currentGame) then return nil end
    local camera = voxelRenderer.module(currentGame, "BattleCam")
    return type(camera) == "table" and camera or nil
  end

  local function installOakLabLens(camera)
    if not camera or camera.__kantoAscendantOakLabLens then return end
    local originalRigFor = camera.rigFor
    if type(originalRigFor) ~= "function" then return end
    camera.rigFor = function(arena)
      local rig = originalRigFor(arena)
      local map = arena and arena.map
      if map and map.id == "OAKS_LAB" and type(rig) == "table" then
        return {
          side = rig.side, back = rig.back, height = rig.height,
          lookX = rig.lookX, lookY = rig.lookY,
          frameH = math.max(tonumber(rig.frameH) or 0,
                            OAKS_LAB_WIDE_FRAME_H),
        }
      end
      return rig
    end
    camera.__kantoAscendantOakLabLens = true
  end

  function C.apply(currentGame)
    local camera = battleCam(currentGame or game)
    installOakLabLens(camera)
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
    local mode = cameraMode()
    local preset = mode == "classic" and CLASSIC_TELE
      or mode == "wide" and WIDE_TELE
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
  C.OAKS_LAB_WIDE_FRAME_H = OAKS_LAB_WIDE_FRAME_H
  return C
end
