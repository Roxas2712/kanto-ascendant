-- Opt-in compatibility camera for the compatible Voxel renderer's enlarged
-- battle rig. The technical export ID remains part of its public API.
--
-- Kanto Ascendant historically writes a three-times-taller tele rig so
-- complete Crystal trainer cards remain visible. DRAMALESS 2.0.2 keeps full
-- ownership of its later 1.3 resting zoom, steering, frameH() and rig(); KASC
-- preserves the reviewed raw `34.11 * 3` rig contract without replacing any
-- of those renderer semantics.
--
-- Camera position alone does not control the rendered composition in
-- that renderer. frameH is the actual vertical frame size. The reviewed
-- compatibility contract therefore pins the raw tele height explicitly.

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
    -- Keep the same proven three-times-taller raw tele frame for the wide
    -- legacy choice; renderer-owned zoom and steering still determine the
    -- final effective framing.
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
    -- Every renderer's battle cards are pinned against its own lens.  This
    -- compatibility row was authored for the reviewed Dramaless camera only.
    -- Applying its x3 frame height to Voxel Ascendant pulls both projected
    -- cards toward the centre, which puts the enemy card over the player HUD
    -- and makes portrait windows look dramatically zoomed out.  Voxel
    -- Ascendant and Battle Art therefore retain complete ownership of their
    -- authored rigs and options.
    if rendererId ~= "DRAMALESS_SHAPE" then return nil end
    return rendererId
  end

  local function battleCam(currentGame)
    if not cameraRenderer(currentGame) then return nil end
    local camera, rendererId, cameraReason, receipt
    if type(voxelRenderer.cameraModule) == "function" then
      camera, rendererId, cameraReason, receipt =
        voxelRenderer.cameraModule(currentGame)
      if type(camera) == "table" then return camera, receipt end
    end
    camera, rendererId, cameraReason, receipt =
      voxelRenderer.module(currentGame, "BattleCam")
    return type(camera) == "table" and camera or nil, receipt
  end

  local function installOakLabLens(camera)
    if not camera or camera.__kantoAscendantOakLabLens then return end
    local originalRigFor = camera.rigFor
    if type(originalRigFor) ~= "function" then return end
    local oakFrameH = OAKS_LAB_WIDE_FRAME_H
    camera.rigFor = function(arena)
      local rig = originalRigFor(arena)
      local map = arena and arena.map
      if map and map.id == "OAKS_LAB" and type(rig) == "table" then
        return {
          side = rig.side, back = rig.back, height = rig.height,
          lookX = rig.lookX, lookY = rig.lookY,
          frameH = math.max(tonumber(rig.frameH) or 0, oakFrameH),
        }
      end
      return rig
    end
    camera.__kantoAscendantOakLabLens = true
  end

  function C.apply(currentGame)
    local camera, receipt = battleCam(currentGame or game)
    if receipt
        and receipt.capability == "dramaless-2.0.2-battle-camera/v1" then
      return type(camera.apply) == "function"
        and camera.apply(cameraMode()) == true
    end
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
