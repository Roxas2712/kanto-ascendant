-- Dedicated Gorochu visual routing.
--
-- Crystal battle cards stay at their intentional resolution. Dramatic
-- Shape/Voxel prefers a separate native 56 px Crystal-style front cycle and
-- falls back atomically to the approved illustrated 96 px cycle. The
-- overworld follower is resolved from its independent six-pose sheet. This
-- module never derives one presentation from another.

return function(mod, opts)
  opts = opts or {}
  local species = opts.species or "GOROCHU"
  local shinySystem = opts.shinySystem
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
  local V = {
    species = species,
    voxelSize = { width = 160, height = 144 },
    masterSize = 96,
    crystalPrimarySize = 56,
    crystalPrimaryRoot = "assets/voxel/gorochu/crystal",
    illustratedFallbackRoot = "assets/voxel/gorochu/animation",
  }
  local frameOffsets = {
    { 0, 0 }, { 0, -1 }, { 1, 0 },
    { 0, 1 }, { -1, 0 }, { 0, -1 },
  }

  local function isShiny(mon)
    if shinySystem and shinySystem.isShiny then
      return shinySystem.isShiny(mon)
    end
    return mon and mon.shiny == true or false
  end

  local function dramaticBattle(game)
    return voxelRenderer and voxelRenderer.module(game, "OverworldBattle")
  end

  local function wantsFront(overworldBattle)
    if not (overworldBattle and overworldBattle.wantsFront) then return false end
    local ok, value = pcall(overworldBattle.wantsFront)
    return ok and value == true
  end

  local function primaryReady()
    if V.crystalPrimaryAvailable ~= nil then
      return V.crystalPrimaryAvailable
    end
    for _, variant in ipairs({ "normal", "shiny" }) do
      for index = 1, 6 do
        local relative = ("%s/%s/%03d.png")
          :format(V.crystalPrimaryRoot, variant, index)
        local body = mod:read(relative)
        if type(body) ~= "string"
            or body:sub(1, 8) ~= "\137PNG\r\n\26\n" then
          V.crystalPrimaryAvailable = false
          V.crystalPrimaryFallbackReason = "incomplete-primary"
          return false
        end
      end
    end
    V.crystalPrimaryAvailable = true
    V.crystalPrimaryFallbackReason = nil
    return true
  end

  V.primaryReady = primaryReady

  local function relativePath(mon, side, frame, forceFallback)
    side = side == "back" and "back" or "front"
    local shiny = isShiny(mon)
    if side == "front" and frame then
      local variant = shiny and "shiny" or "normal"
      local index = (math.max(1, math.floor(tonumber(frame) or 1)) - 1) % 6 + 1
      if not forceFallback and primaryReady() then
        return ("%s/%s/%03d.png")
          :format(V.crystalPrimaryRoot, variant, index),
          "crystal-primary"
      end
      local animated = ("%s/%s/%03d.png")
        :format(V.illustratedFallbackRoot, variant, index)
      if mod:read(animated) then return animated, "illustrated-fallback" end
    end
    local suffix = shiny and "_shiny" or ""
    local relative = ("assets/voxel/gorochu/gorochu_%s%s.png")
      :format(side, suffix)
    return mod:read(relative) and relative or nil, "illustrated-fallback"
  end

  V.relativePath = relativePath

  function V.cataloguePath(mon)
    local variant = isShiny(mon) and "shiny" or "normal"
    if primaryReady() then
      return ("%s/%s/001.png"):format(V.crystalPrimaryRoot, variant),
        "crystal-primary"
    end
    -- Catalogue views must never fall back to the superseded illustrated
    -- identity. A damaged primary family may use the registered current
    -- Crystal front; the caller still constrains it to the catalogue slot.
    local suffix = variant == "shiny" and "_shiny" or ""
    local relative = "assets/crystal/gorochu_front" .. suffix .. ".png"
    return mod:read(relative) and relative or nil, "crystal-static-fallback"
  end

  function V.ownsCatalogue(target, kind)
    return target == species and (kind == "summary" or kind == "dex")
      and mod.options and mod.options.get
      and mod.options:get("dex_sprite_style") ~= "crystal"
  end

  function V.install(game)
    local overworldBattle = dramaticBattle(game)
    if not (overworldBattle and overworldBattle.sideTexture) then return false end
    if overworldBattle.kantoAscendantGorochuTextureHook then return true end

    local innerSideTexture = overworldBattle.sideTexture
    local canvases, images = {}, {}
    local MASTER_CARD = V.masterSize

    local function nativeCard(texture)
      local canvas = texture and texture.canvas
      local width, height
      if canvas and canvas.getDimensions then
        width, height = canvas:getDimensions()
      elseif canvas then
        width, height = canvas.width, canvas.height
      end
      width, height = tonumber(width) or V.voxelSize.width,
        tonumber(height) or V.voxelSize.height
      return width, height,
        tonumber(texture and texture.ax) or width / 2,
        tonumber(texture and texture.ay) or 96
    end

    local function imageFor(relative, lane)
      if images[relative] then return images[relative] end
      if not (love and love.graphics and love.graphics.newImage) then return nil end
      local ok, image = pcall(
        love.graphics.newImage, mod.path .. "/" .. relative)
      if not (ok and image) then return nil end
      if image.setFilter then
        local filter = lane == "crystal-primary" and "nearest" or "linear"
        image:setFilter(filter, filter)
      end
      images[relative] = image
      return image
    end

    local function canvasFor(side, width, height, lane)
      local key = side .. ":" .. width .. "x" .. height .. ":" .. lane
      local canvas = canvases[key]
      if canvas then return canvas end
      if not (love and love.graphics and love.graphics.newCanvas) then return nil end
      local ok, made = pcall(
        love.graphics.newCanvas, width, height, { dpiscale = 1 })
      if not (ok and made) then return nil end
      if made.setFilter then
        local filter = lane == "crystal-primary" and "nearest" or "linear"
        made:setFilter(filter, filter)
      end
      canvases[key] = made
      return made
    end

    local function supersampledTexture(texture, battler, side, battle)
      if not (texture and battler and battler.mon
          and battler.mon.species == species) then return texture end

      -- During the trainer-battle introduction the renderer deliberately
      -- returns the trainer/back card for this side while the eventual
      -- battler is already attached to the BattleState.  Do not replace that
      -- marked trainer card with Gorochu's Pokemon art: doing so shows a
      -- floating Gorochu before "Go!", followed by the real send-out.
      --
      -- The selected-character Voxel wrapper intentionally clears the
      -- renderer's `trainer` bit on Red/Blue/Green standing-front cards so
      -- their mirror transform is correct.  The BattleState visibility flags
      -- are therefore the authoritative guard across the full wrapper chain,
      -- including the optional throw poses and both trainer slide phases.
      local trainerPhase = battle and (
        side == "player" and battle.showPlayerBack == true
          or side == "enemy" and battle.showEnemyTrainer == true)
      if trainerPhase or texture.trainer == true then return texture end

      -- The renderer owns player view and card placement. Its world-space BACK
      -- SPRITES option needs the dedicated rear master just as its pinned
      -- OG-UI path does; FRONT SPRITES keeps the camera-facing master.
      local artSide = side == "player" and not wantsFront(overworldBattle)
        and "back" or "front"
      local animation = battler.__ascendantCrystalAnimation
      local animationFrame = math.max(1,
        math.floor(tonumber(animation and animation.frame) or 1))
      local relative, lane = relativePath(
        battler.mon,
        artSide,
        artSide == "front" and animationFrame or nil)
      local image = relative and imageFor(relative, lane)
      if lane == "crystal-primary" and not image then
        -- A complete on-disk family passed the cheap PNG signature gate but a
        -- renderer decode still failed. Disable the whole primary family for
        -- this run and retry the exact frame through the bytefixed fallback;
        -- never mix styles later in the same battle.
        V.crystalPrimaryAvailable = false
        V.crystalPrimaryFallbackReason = "primary-decode-failed"
        relative, lane = relativePath(
          battler.mon,
          artSide,
          artSide == "front" and animationFrame or nil,
          true)
        image = relative and imageFor(relative, lane)
      end
      local width, height, anchorX, anchorY = nativeCard(texture)
      local canvas = image and canvasFor(side, width, height, lane)
      if not canvas then return texture end
      local offset = lane == "crystal-primary" and { 0, 0 }
        or frameOffsets[(animationFrame - 1) % #frameOffsets + 1]

      local g = love.graphics
      local previousCanvas = g.getCanvas and g.getCanvas() or nil
      local previousBlend, previousAlpha = "alpha", nil
      if g.getBlendMode then
        previousBlend, previousAlpha = g.getBlendMode()
      end
      local red, green, blue, alpha = 1, 1, 1, 1
      if g.getColor then red, green, blue, alpha = g.getColor() end
      local ok = pcall(function()
        g.setCanvas(canvas)
        g.clear(0, 0, 0, 0)
        g.setBlendMode("alpha")
        g.setColor(1, 1, 1, 1)
        local width, height = image:getDimensions()
        local drawScale = lane == "crystal-primary" and 1
          or MASTER_CARD / math.max(width, height)
        local drawWidth, drawHeight = width * drawScale, height * drawScale
        local centerX, baselineY = anchorX, anchorY
        g.draw(
          image,
          centerX - drawWidth / 2 + offset[1],
          baselineY - drawHeight + offset[2],
          0,
          drawScale,
          drawScale)
      end)
      if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
      g.setBlendMode(previousBlend or "alpha", previousAlpha)
      g.setColor(red or 1, green or 1, blue or 1, alpha or 1)
      if not ok then return texture end

      texture.canvas = canvas
      texture.ax = anchorX
      texture.ay = anchorY
      texture.kantoAscendantGorochuSupersampled = true
      texture.kantoAscendantGorochuSource = relative
      texture.kantoAscendantGorochuSide = artSide
      texture.kantoAscendantGorochuAnimationFrame = animationFrame
      texture.kantoAscendantGorochuAssetLane = lane
      texture.kantoAscendantGorochuFallbackReason =
        V.crystalPrimaryFallbackReason
      return texture
    end

    overworldBattle.sideTexture = function(battle, side)
      local texture = innerSideTexture(battle, side)
      local battler = battle
        and (side == "enemy" and battle.enemy or battle.player)
      return supersampledTexture(texture, battler, side, battle)
    end
    overworldBattle.kantoAscendantGorochuTextureHook = true
    V.overworldBattle = overworldBattle
    return true
  end

  return V
end
