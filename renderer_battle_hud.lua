-- Renderer-specific battle-HUD composition.
--
-- This bridge selects an explicit geometry profile from the reviewed public
-- renderer module.  It never guesses from a renderer version: Voxel
-- Ascendant's public wide-HUD seam is cooperative (the renderer may already
-- have snapped the current shot, otherwise KASC may do it); the exact reviewed
-- DRAMALESS and Battle Art packages remain renderer-owned.  Battle Art
-- 1.9.0/1.9.2 supply per-band placement objects because their HUD can be one
-- integer rung smaller than its text/world scale, while the other renderers
-- use legacy band origins.  This module normalizes both public forms.

return function(mod, opts)
  opts = opts or {}
  local resolver = opts.voxelRenderer
  local unpackValues = table.unpack or unpack
  local PROFILE_SCHEMA = "ka-renderer-battle-hud/v1"
  local CONTEXT_SCHEMA = "ka-renderer-battle-hud-context/v1"
  local SNAP_SCHEMA = "ka-renderer-battle-hud-snap/v1"
  local SNAP_RECEIPT_KEY = "__kascRendererBattleHudSnapReceipt"
  local SNAP_HOOK_KEY = "__kascRendererBattleHudSnapHook"
  local OWNER_KEY = "__kascWideBattleHudState"
  local PANEL_KEY = "__kascWideBattleHudPanelState"
  local PANEL_RECEIPT_KEY = "__kascWideBattleHudPanelReceipt"

  local H = {
    schema = PROFILE_SCHEMA,
    contextSchema = CONTEXT_SCHEMA,
    snapSchema = SNAP_SCHEMA,
    snapReceiptKey = SNAP_RECEIPT_KEY,
    snapHookKey = SNAP_HOOK_KEY,
    profile = "NATIVE_2D",
    rendererId = nil,
    rendererVersion = nil,
    lastError = nil,
    lastGeometry = nil,
  }
  local activeProfile

  local function pack(...)
    return { n = select("#", ...), ... }
  end

  local function unpackPacked(values, first)
    return unpackValues(values, first or 1, values.n)
  end

  local function number(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  local function rect(value)
    return type(value) == "table"
      and number(value[1]) and number(value[2])
      and number(value[3]) and value[3] >= 0
      and number(value[4]) and value[4] >= 0
  end

  local function copyRect(value)
    if not rect(value) then return nil end
    return { value[1], value[2], value[3], value[4] }
  end

  local function validShot(shot)
    return type(shot) == "table" and shot.canvas ~= nil
      and number(shot.scale) and shot.scale > 0
      and number(shot.pw) and shot.pw > 0
      and number(shot.ph) and shot.ph > 0
      and number(shot.lx) and number(shot.ly)
  end

  local function status(profile, rendererId, rendererVersion, reason)
    H.profile = profile
    H.rendererId = rendererId
    H.rendererVersion = rendererVersion
    H.lastError = reason
    H.lastGeometry = nil
  end

  local function markSnap(battle, shot, rendererId, snapped, reason)
    if not battle then return end
    battle[SNAP_RECEIPT_KEY] = {
      schema = SNAP_SCHEMA,
      rendererId = rendererId,
      shot = shot,
      snapped = snapped == true,
      reason = reason,
    }
  end

  -- Observe the renderer's public snap call without changing its result or
  -- error behaviour.  The shot identity makes the receipt frame-local even
  -- when a renderer reuses the battle object for the entire encounter.
  local function installSnapReceipt(renderer, rendererId)
    local hook = rawget(renderer, SNAP_HOOK_KEY)
    if type(hook) == "table" and type(hook.original) == "function" then
      hook.rendererId = rendererId
      return hook
    elseif hook ~= nil then
      return nil
    end
    if type(renderer.snapHUDs) ~= "function" then return nil end
    hook = { original = renderer.snapHUDs, rendererId = rendererId }
    hook.wrapper = function(battle, shot, ...)
      markSnap(battle, shot, hook.rendererId, false, "snap-pending")
      local results = pack(pcall(hook.original, battle, shot, ...))
      if not results[1] then
        markSnap(battle, shot, hook.rendererId, false, tostring(results[2]))
        error(results[2], 0)
      end
      markSnap(battle, shot, hook.rendererId, results[2] == true,
        results[2] == true and nil or "snap-declined")
      return unpackPacked(results, 2)
    end
    renderer.snapHUDs = hook.wrapper
    renderer[SNAP_HOOK_KEY] = hook
    return hook
  end

  local function standardWideCapability(renderer)
    if type(renderer) ~= "table"
        or type(renderer.shot) ~= "function"
        or type(renderer.snapHUDs) ~= "function"
        or type(renderer.snapRects) ~= "function"
        or type(renderer.textRects) ~= "function"
        or type(renderer.hudLive) ~= "function"
        or type(renderer.drawHudPanels) ~= "function"
        or type(renderer.HUD_RECT) ~= "table"
        or not rect(renderer.HUD_RECT.enemy)
        or not rect(renderer.HUD_RECT.player)
        or type(renderer.HUD_BAND) ~= "table"
        or not rect(renderer.HUD_BAND.enemy)
        or not rect(renderer.HUD_BAND.player)
        or type(renderer.TEXT_RECT) ~= "table"
        or not rect(renderer.TEXT_RECT.box)
        or not rect(renderer.TEXT_RECT.moves)
        or not rect(renderer.TEXT_RECT.mimic) then
      return false
    end
    return true
  end

  local function standardProfile(renderer, rendererId, name, shotField,
                                 snapOwner)
    if not standardWideCapability(renderer) then return nil end
    if not installSnapReceipt(renderer, rendererId) then return nil end
    return {
      schema = PROFILE_SCHEMA,
      name = name,
      rendererId = rendererId,
      renderer = renderer,
      shotField = shotField,
      snapOwner = snapOwner,
      layout = "wide-edge",
    }
  end

  local function battleStateOwner()
    local BattleState = require("src.battle.BattleState")
    local state = rawget(BattleState, OWNER_KEY)
    if type(state) == "table" and type(state.original) == "function" then
      return BattleState, state
    elseif state ~= nil then
      return BattleState, nil
    end

    local original = BattleState.drawHUDs
    if type(original) ~= "function" then return BattleState, nil end
    state = {
      activeProfile = nil,
      original = original,
      snapCount = 0,
      nativeSnapCount = 0,
      fallbackCount = 0,
      lastError = nil,
    }
    state.wrapper = function(self, slide, ...)
      local profile = state.activeProfile
      local renderer = profile and profile.renderer
      local shot = profile and self and rawget(self, profile.shotField)
      if profile and profile.snapOwner == "cooperative"
          and validShot(shot) and type(renderer.shot) == "function" then
        local gotShot, liveShot = pcall(renderer.shot)
        if gotShot and liveShot == shot then
          local receipt = rawget(self, SNAP_RECEIPT_KEY)
          if type(receipt) == "table" and receipt.schema == SNAP_SCHEMA
              and receipt.shot == shot and receipt.snapped == true then
            -- The renderer already snapped this exact frame (the RC path).
            -- Delegate through the captured chain so any unrelated wrappers
            -- still run; the renderer's own drawHUDs guard prevents a second
            -- compact HUD draw.
            state.nativeSnapCount = state.nativeSnapCount + 1
            state.lastError = nil
            return original(self, slide, ...)
          end

          -- KASC-owned snapping must leave the text/menu glass in the centred
          -- UI.  drawHudPanels still renders that glass; suppressing textRects
          -- only for this snap avoids a second, darker copy in the world layer.
          local textRects = renderer.textRects
          renderer.textRects = function() return {} end
          local results = pack(pcall(renderer.snapHUDs, self, shot))
          renderer.textRects = textRects
          if results[1] and results[2] == true then
            markSnap(self, shot, profile.rendererId, true)
            state.snapCount = state.snapCount + 1
            state.lastError = nil
            return
          end
          state.lastError = results[1] and "snap-declined"
            or tostring(results[2])
        elseif not gotShot then
          state.lastError = tostring(liveShot)
        else
          state.lastError = "shot-mismatch"
        end
      end
      state.fallbackCount = state.fallbackCount + 1
      if type(state.restoreCompactPanels) == "function" then
        local restored, restoreError = state.restoreCompactPanels(self, profile)
        if restored == false and restoreError then
          state.lastError = (state.lastError and state.lastError .. ";" or "")
            .. "panel-restore:" .. tostring(restoreError)
        end
      end
      return original(self, slide, ...)
    end
    BattleState.drawHUDs = state.wrapper
    BattleState[OWNER_KEY] = state
    return BattleState, state
  end

  local function existingBattleStateOwner()
    local BattleState = require("src.battle.BattleState")
    local state = rawget(BattleState, OWNER_KEY)
    if type(state) ~= "table" or type(state.original) ~= "function" then
      state = nil
    end
    return BattleState, state
  end

  local function installPanelBridge(profile, owner)
    local renderer = profile.renderer
    local panelState = rawget(renderer, PANEL_KEY)
    if type(panelState) == "table"
        and type(panelState.original) == "function" then
      panelState.owner = owner
      panelState.profile = profile
      return panelState
    elseif panelState ~= nil then
      return nil
    end
    local original = renderer.drawHudPanels
    if type(original) ~= "function" or type(renderer.hudLive) ~= "function" then
      return nil
    end
    panelState = { original = original, owner = owner, profile = profile }
    local function restoreCompactPanels(battle, selected)
      local receipt = battle and rawget(battle, PANEL_RECEIPT_KEY)
      if type(receipt) ~= "table" or receipt.profile ~= selected
          or receipt.shot ~= rawget(battle, selected.shotField)
          or receipt.restored then
        return nil
      end
      receipt.restored = true
      -- The first pass already laid down the centred text/menu glass.  A
      -- failed wide snap needs only the two compact HP panels back; drawing
      -- textRects again would frost the command area twice.
      local textRects = renderer.textRects
      renderer.textRects = function() return {} end
      local results = pack(pcall(original, battle))
      renderer.textRects = textRects
      if not results[1] then return false, results[2] end
      return true
    end
    owner.restoreCompactPanels = restoreCompactPanels
    panelState.wrapper = function(battle, ...)
      local selected = panelState.owner.activeProfile
      if selected ~= panelState.profile
          or not (battle and rawget(battle, selected.shotField)) then
        return original(battle, ...)
      end
      -- Keep text/menu glass in the centred battle frame while suppressing
      -- only the compact in-frame HP panels.  Party-ball and Safari rows live
      -- in the snap bands themselves, not in this panel pass.
      local hudLive = renderer.hudLive
      renderer.hudLive = function() return false, false end
      local results = pack(pcall(original, battle, ...))
      renderer.hudLive = hudLive
      if not results[1] then error(results[2], 0) end
      battle[PANEL_RECEIPT_KEY] = {
        profile = selected,
        shot = rawget(battle, selected.shotField),
        restored = false,
      }
      return unpackPacked(results, 2)
    end
    renderer.drawHudPanels = panelState.wrapper
    renderer[PANEL_KEY] = panelState
    return panelState
  end

  local function mapGbRect(value, shot)
    if not rect(value) then return nil end
    local mapped = {
      shot.lx + value[1] * shot.scale,
      shot.ly + value[2] * shot.scale,
      value[3] * shot.scale,
      value[4] * shot.scale,
    }
    return rect(mapped) and mapped or nil
  end

  local function bandPlacement(value, band, shot)
    if not rect(band) then return nil end
    if number(value) then
      return {
        x = value,
        y = shot.ly + band[2] * shot.scale,
        scale = shot.scale,
      }
    end
    if type(value) ~= "table" or not number(value.x)
        or not number(value.y) or not number(value.scale)
        or value.scale <= 0 then return nil end
    return { x = value.x, y = value.y, scale = value.scale }
  end

  local function mapBandRect(value, placement)
    if not rect(value) or type(placement) ~= "table" then return nil end
    local mapped = {
      placement.x + value[1] * placement.scale,
      placement.y,
      value[3] * placement.scale,
      value[4] * placement.scale,
    }
    return rect(mapped) and mapped or nil
  end

  local function buildWideContext(profile, battle, shot)
    if not validShot(shot) then return nil, "shot-invalid" end
    local receipt = rawget(battle, SNAP_RECEIPT_KEY)
    if type(receipt) ~= "table" or receipt.schema ~= SNAP_SCHEMA
        or receipt.rendererId ~= profile.rendererId
        or receipt.shot ~= shot or receipt.snapped ~= true then
      return nil, "current-shot-not-snapped"
    end

    local gotRects, hudRects, rawPlacements =
      pcall(profile.renderer.snapRects, shot)
    if not gotRects or type(hudRects) ~= "table"
        or not rect(hudRects.enemy) or not rect(hudRects.player)
        or type(rawPlacements) ~= "table" then
      return nil, "renderer-geometry-invalid"
    end

    local renderer = profile.renderer
    local enemyPlacement = bandPlacement(
      rawPlacements.enemy, renderer.HUD_BAND.enemy, shot)
    local playerPlacement = bandPlacement(
      rawPlacements.player, renderer.HUD_BAND.player, shot)
    if not enemyPlacement or not playerPlacement then
      return nil, "renderer-band-placement-invalid"
    end
    local enemyHud, playerHud = copyRect(hudRects.enemy), copyRect(hudRects.player)
    local enemyBand = mapBandRect(renderer.HUD_BAND.enemy, enemyPlacement)
    local playerBand = mapBandRect(renderer.HUD_BAND.player, playerPlacement)
    if not enemyBand or not playerBand then
      return nil, "renderer-band-geometry-invalid"
    end
    local enemyScale = enemyPlacement.scale
    local playerScale = playerPlacement.scale

    local text = {}
    local gotText, activeText = pcall(renderer.textRects, battle)
    if gotText and type(activeText) == "table" then
      for key, value in pairs(activeText) do
        local mapped = mapGbRect(value, shot)
        if mapped then text[key] = mapped end
      end
    end

    local geometry = {
      schema = CONTEXT_SCHEMA,
      profile = profile.name,
      rendererId = profile.rendererId,
      shot = shot,
      canvas = shot.canvas,
      -- `scale` remains the text/world scale for existing consumers.  HUD
      -- overlays must use the explicit side scale below because Battle Art's
      -- SCALED mode intentionally uses max(1, shot.scale - 1).
      scale = shot.scale,
      enemyScale = enemyScale,
      playerScale = playerScale,
      hp = { enemy = enemyHud, player = playerHud },
      bands = { enemy = enemyBand, player = playerBand },
      -- Both full bands are the renderer's documented coverage contract for
      -- intro/replacement Pokéball rows and the Safari-ball counter.
      partySafariCoverage = {
        enemyParty = copyRect(enemyBand),
        playerParty = copyRect(playerBand),
        safari = copyRect(playerBand),
      },
      text = text,
      anchors = {
        hudTop = shot.ly,
        enemyHudLeft = enemyHud[1],
        enemySourceX = renderer.HUD_RECT.enemy[1],
        enemyScale = enemyScale,
        playerHudRight = playerHud[1] + playerHud[3],
        playerScale = playerScale,
        expRight = playerHud[1] + playerHud[3] - 13 * playerScale,
        expY = playerPlacement.y
          + (89 - renderer.HUD_BAND.player[2]) * playerScale,
        caughtNameOrigin = enemyHud[1]
          - (renderer.HUD_RECT.enemy[1] + 1) * enemyScale,
        caughtY = enemyPlacement.y
          + (7 - renderer.HUD_BAND.enemy[2]) * enemyScale,
        textLeft = shot.lx,
        textScale = shot.scale,
      },
    }
    H.lastGeometry = geometry
    return geometry
  end

  function H.context(battle)
    local profile = activeProfile
    if not profile or not battle then return nil end
    local shot = rawget(battle, profile.shotField)
    local geometry, reason = buildWideContext(profile, battle, shot)
    if geometry then
      H.lastError = nil
    else
      H.lastError = reason
    end
    return geometry
  end

  function H.refresh(game)
    activeProfile = nil
    local owner = select(2, existingBattleStateOwner())
    if owner then owner.activeProfile = nil end
    if not resolver or type(resolver.module) ~= "function" then
      status("NATIVE_2D", nil, nil, "renderer-absent")
      return false
    end

    local renderer, rendererId, reason, receipt =
      resolver.module(game, "OverworldBattle")
    local version = receipt and receipt.rendererVersion
    if type(renderer) ~= "table" then
      status("NATIVE_2D", rendererId, version, reason or "renderer-absent")
      return false
    end

    local profile, profileError
    if rendererId == "VOXEL_ASCENDANT" then
      profile = standardProfile(renderer, rendererId, "KASC_VASC_WIDE",
        "voxelAscendantShot", "cooperative")
      if not profile then profileError = "wide-hud-capability-missing" end
    elseif rendererId == "DRAMALESS_SHAPE" then
      profile = standardProfile(renderer, rendererId,
        "DRAMALESS_RENDERER_NATIVE", "dramaticShapeShot", "renderer")
      if not profile then profileError = "renderer-hud-capability-missing" end
    elseif rendererId == "BATTLE_ART_VOXEL_FORK" then
      profile = standardProfile(renderer, rendererId,
        "BATTLE_ART_RENDERER_NATIVE", "dramaticShapeShot", "renderer")
      if not profile then profileError = "renderer-hud-capability-missing" end
    else
      status("RENDERER_NATIVE", rendererId, version, nil)
      return true
    end

    if not profile then
      status("RENDERER_NATIVE", rendererId, version, profileError)
      return false
    end

    if profile.snapOwner == "cooperative" then
      if not owner then owner = select(2, battleStateOwner()) end
      if not owner or not installPanelBridge(profile, owner) then
        status("RENDERER_NATIVE", rendererId, version,
          owner and "wide-hud-panel-seam-missing"
            or "battle-hud-seam-missing")
        return false
      end
      owner.activeProfile = profile
    end
    activeProfile = profile
    status(profile.name, rendererId, version, nil)
    return true
  end

  function H.inspect()
    local _, owner = existingBattleStateOwner()
    return {
      schema = H.schema,
      contextSchema = H.contextSchema,
      profile = H.profile,
      rendererId = H.rendererId,
      rendererVersion = H.rendererVersion,
      lastError = H.lastError or (owner and owner.lastError),
      snapCount = owner and owner.snapCount or 0,
      nativeSnapCount = owner and owner.nativeSnapCount or 0,
      fallbackCount = owner and owner.fallbackCount or 0,
      geometry = H.lastGeometry,
    }
  end

  mod.events:once("mods.loaded", function(ev)
    H.refresh(ev and ev.game)
  end)
  mod.events:on("game.ready", function(ev)
    H.refresh(ev and ev.game)
  end)

  return H
end
