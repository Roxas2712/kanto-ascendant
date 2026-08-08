-- Dedicated Gorochu visual routing.
--
-- Crystal battle cards stay at their intentional 56 px resolution. Dramatic
-- Shape/Voxel instead receives the approved 96 px master on a supersampled
-- side texture, and the overworld follower is resolved from its independent
-- six-pose sheet. This module never derives one presentation from another.

return function(mod, opts)
  opts = opts or {}
  local species = opts.species or "GOROCHU"
  local shinySystem = opts.shinySystem
  local V = {
    species = species,
    voxelSize = { width = 230, height = 207 },
    masterSize = 96,
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
    local exports = game and game.mods and game.mods.exports
    -- Dramaless Shape preserves Dramatic Shape's public OverworldBattle
    -- companion API under its own maintained mod id.
    local dramatic = exports and (exports.DRAMALESS_SHAPE
      or exports.DRAMATIC_SHAPE)
    if not (dramatic and dramatic.lib and dramatic.lib.require) then
      return nil
    end
    local ok, battle = pcall(dramatic.lib.require, "OverworldBattle")
    return ok and battle or nil
  end

  local function wantsFront(overworldBattle)
    if not (overworldBattle and overworldBattle.wantsFront) then return false end
    local ok, value = pcall(overworldBattle.wantsFront)
    return ok and value == true
  end

  local function relativePath(mon, side)
    side = side == "back" and "back" or "front"
    local suffix = isShiny(mon) and "_shiny" or ""
    local relative = ("assets/voxel/gorochu/gorochu_%s%s.png")
      :format(side, suffix)
    return mod:read(relative) and relative or nil
  end

  V.relativePath = relativePath

  function V.install(game)
    local overworldBattle = dramaticBattle(game)
    if not (overworldBattle and overworldBattle.sideTexture) then return false end
    if overworldBattle.kantoAscendantGorochuTextureHook then return true end

    local innerSideTexture = overworldBattle.sideTexture
    local canvases, images = {}, {}
    local VOXEL_W, VOXEL_H = V.voxelSize.width, V.voxelSize.height
    local MASTER_CARD = V.masterSize
    -- 230:207 is the same aspect ratio as the native 160:144 battle frame.
    local VOXEL_SCALE = VOXEL_W / 160
    local VOXEL_AX, VOXEL_AY = VOXEL_W / 2, 96 * VOXEL_SCALE

    local function imageFor(relative)
      if images[relative] then return images[relative] end
      if not (love and love.graphics and love.graphics.newImage) then return nil end
      local ok, image = pcall(
        love.graphics.newImage, mod.path .. "/" .. relative)
      if not (ok and image) then return nil end
      if image.setFilter then image:setFilter("nearest", "nearest") end
      images[relative] = image
      return image
    end

    local function canvasFor(side)
      local canvas = canvases[side]
      if canvas then return canvas end
      if not (love and love.graphics and love.graphics.newCanvas) then return nil end
      local ok, made = pcall(
        love.graphics.newCanvas, VOXEL_W, VOXEL_H, { dpiscale = 1 })
      if not (ok and made) then return nil end
      if made.setFilter then made:setFilter("nearest", "nearest") end
      canvases[side] = made
      return made
    end

    local function supersampledTexture(texture, battler, side)
      if not (texture and battler and battler.mon
          and battler.mon.species == species) then return texture end

      -- Dramaless Shape owns player view and card placement. Its world-space BACK
      -- SPRITES option needs the dedicated rear master just as its pinned
      -- OG-UI path does; FRONT SPRITES keeps the camera-facing master.
      local artSide = side == "player" and not wantsFront(overworldBattle)
        and "back" or "front"
      local relative = relativePath(battler.mon, artSide)
      local image = relative and imageFor(relative)
      local canvas = image and canvasFor(side)
      if not canvas then return texture end
      local animation = battler.__ascendantCrystalAnimation
      local animationFrame = math.max(1,
        math.floor(tonumber(animation and animation.frame) or 1))
      local offset = frameOffsets[
        (animationFrame - 1) % #frameOffsets + 1]

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
        local drawScale = MASTER_CARD / math.max(width, height)
        local drawWidth, drawHeight = width * drawScale, height * drawScale
        local centerX = VOXEL_W / 2
        local baselineY = 96 * VOXEL_SCALE
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
      texture.ax = VOXEL_AX
      texture.ay = VOXEL_AY
      texture.kantoAscendantGorochuSupersampled = true
      texture.kantoAscendantGorochuSource = relative
      texture.kantoAscendantGorochuSide = artSide
      texture.kantoAscendantGorochuAnimationFrame = animationFrame
      return texture
    end

    overworldBattle.sideTexture = function(battle, side)
      local texture = innerSideTexture(battle, side)
      local battler = battle
        and (side == "enemy" and battle.enemy or battle.player)
      return supersampledTexture(texture, battler, side)
    end
    overworldBattle.kantoAscendantGorochuTextureHook = true
    V.overworldBattle = overworldBattle
    return true
  end

  return V
end
