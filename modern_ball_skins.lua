-- Distinct modern-style capture balls on the original Gen-I toss paths.
--
-- The engine still owns ball choice, catch math, trajectory, shake count,
-- sound and timing. The original ball is one 16x16 image assembled from
-- four 8x8 OAM tiles. This replaces that complete image once per frame with
-- a true-colour drawing keyed to the item actually thrown.

return function(mod)
  local ok, AnimPlayer = pcall(require, "src.battle.AnimPlayer")
  if not ok or type(AnimPlayer) ~= "table" then return end

  local BALL_ANIMS = {
    TOSS_ANIM = true,
    GREATTOSS_ANIM = true,
    ULTRATOSS_ANIM = true,
    BLOCKBALL_ANIM = true,
    SHAKE_ANIM = true,
  }

  local SKINS = {
    POKE_BALL = {
      top = { .92, .12, .16, 1 }, accent = { .92, .12, .16, 1 },
    },
    GREAT_BALL = {
      top = { .10, .36, .75, 1 }, accent = { .90, .12, .16, 1 },
    },
    ULTRA_BALL = {
      top = { .10, .11, .13, 1 }, accent = { 1.00, .76, .10, 1 },
    },
    MASTER_BALL = {
      top = { .48, .20, .66, 1 }, accent = { .95, .32, .66, 1 },
    },
    SAFARI_BALL = {
      top = { .26, .48, .24, 1 }, accent = { .72, .67, .36, 1 },
    },
  }

  local function option(game, key)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    local value = bucket and bucket[key]
    if value == nil then value = mod.options:get(key) end
    return value
  end

  local function enabled()
    local game = mod.world and mod.world.game
    return option(game, "modern_ball_skins") ~= false
  end

  local function set(c)
    love.graphics.setColor(c[1], c[2], c[3], c[4])
  end

  local function drawSkin(id, x, y, angle, flicker)
    local g = love.graphics
    local skin = SKINS[id] or SKINS.POKE_BALL
    local oldLineStyle = g.getLineStyle and g.getLineStyle() or nil
    if g.setLineStyle then g.setLineStyle("rough") end
    g.push()
    g.translate(x + 8, y + 8)
    g.rotate(angle or 0)

    set({ .98, .98, .94, 1 })
    g.circle("fill", 0, 0, 7.5)
    set(skin.top)
    g.arc("fill", 0, 0, 7.5, math.pi, math.pi * 2)

    -- Type markings remain readable while the ball rolls.
    set(skin.accent)
    if id == "GREAT_BALL" then
      g.rectangle("fill", -6, -6, 4, 3)
      g.rectangle("fill", 2, -6, 4, 3)
    elseif id == "ULTRA_BALL" then
      g.rectangle("fill", -6, -8, 4, 7)
      g.rectangle("fill", 2, -8, 4, 7)
    elseif id == "MASTER_BALL" then
      g.circle("fill", -5, -5, 2.5)
      g.circle("fill", 5, -5, 2.5)
      -- Compact white M marking, readable at the native 16x16 size.
      set({ .98, .98, .94, 1 })
      g.line(-3, -6, -3, -3, 0, -5, 3, -3, 3, -6)
    elseif id == "SAFARI_BALL" then
      g.rectangle("fill", -6, -6, 4, 4)
      g.rectangle("fill", 2, -2, 4, 4)
    end

    -- Preserve Gen-I's alternating Ultra/Master throw flash without
    -- replacing the modern type markings with the old monochrome palette.
    if flicker then
      set({ 1, 1, 1, .28 })
      g.circle("fill", 0, 0, 7)
    end

    set({ .05, .06, .08, 1 })
    g.rectangle("fill", -7.5, -1.5, 15, 3)
    g.circle("line", 0, 0, 7.5)
    set({ .98, .98, .94, 1 })
    g.circle("fill", 0, 0, 2.5)
    set({ .05, .06, .08, 1 })
    g.circle("line", 0, 0, 2.5)
    g.pop()

    if oldLineStyle and g.setLineStyle then g.setLineStyle(oldLineStyle) end
    -- True-color zones are rectangular re-blits. A single 16x16 zone would
    -- also restore the transparent tile corners and show a pale square over
    -- an SGB battle background. Mark only the circular pixel spans.
    local PaletteFX = require("src.render.PaletteFX")
    for py = 0, 15 do
      local first, last
      for px = 0, 15 do
        local dx, dy = px + .5 - 8, py + .5 - 8
        if dx * dx + dy * dy <= 64 then
          first = first or px
          last = px
        end
      end
      if first then
        PaletteFX.markTrueColor(x + first, y + py, last - first + 1, 1)
      end
    end
    g.setColor(1, 1, 1, 1)
  end

  AnimPlayer._ascendantBallBridge = AnimPlayer._ascendantBallBridge or {}
  AnimPlayer._ascendantBallBridge.enabled = enabled
  AnimPlayer._ascendantBallBridge.draw = drawSkin

  if not AnimPlayer.__ascendantModernBalls then
    AnimPlayer.__ascendantModernBalls = true
    local originalStart = AnimPlayer.start
    local originalDrawSprites = AnimPlayer.drawSprites

    AnimPlayer.start = function(self, moveId, attackerIsPlayer, opts)
      self.__ascendantBallMove = moveId
      if opts and opts.ball then
        self.__ascendantBallId = opts.ball
        self.__ascendantBallFlicker = opts.ballFlicker == true
      else
        self.__ascendantBallFlicker = false
      end
      return originalStart(self, moveId, attackerIsPlayer, opts)
    end

    AnimPlayer.drawSprites = function(self, sprites, colorFn)
      local bridge = AnimPlayer._ascendantBallBridge
      if not (bridge and bridge.enabled()
          and BALL_ANIMS[self.__ascendantBallMove]) then
        return originalDrawSprites(self, sprites, colorFn)
      end

      -- These subanimations contain one ball assembled from four OAM tiles.
      -- Use their bounding origin once; drawing once per tile causes the
      -- four-ball artifact.
      local minX, minY
      for _, sprite in ipairs(sprites or {}) do
        if sprite.x > 0 and sprite.x < 168
            and sprite.y > 0 and sprite.y < 160 then
          minX = math.min(minX or sprite.x, sprite.x)
          minY = math.min(minY or sprite.y, sprite.y)
        end
      end
      if not minX then return end
      local phase = (self.elapsed or 0) + (self.stepIndex or 1) * 3
      local angle
      if self.__ascendantBallMove == "SHAKE_ANIM" then
        angle = math.sin(phase * .9) * .42
      elseif self.__ascendantBallMove == "BLOCKBALL_ANIM" then
        angle = -phase * .24
      else
        angle = phase * .30
      end
      local flicker = self.__ascendantBallFlicker
        and self.stepIndex % 2 == 0
      bridge.draw(self.__ascendantBallId or "POKE_BALL",
        minX - 8, minY - 16, angle, flicker, {
          move = self.__ascendantBallMove,
          elapsed = self.elapsed or 0,
          stepIndex = self.stepIndex or 1,
        })
    end
  end

  mod.exports.modernBallSkins = {
    skins = SKINS,
    animations = BALL_ANIMS,
    enabled = enabled,
    draw = drawSkin,
  }
end
