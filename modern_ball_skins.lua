-- Distinct modern-style capture balls on the original Gen-I toss paths.
--
-- The engine still owns ball choice, catch math, trajectory, shake count,
-- sound and timing. This replaces only the single 8x8 ball tile carried by
-- TOSS/GREATTOSS/ULTRATOSS/SHAKE with a true-colour drawing keyed to the
-- item actually thrown. Rotation follows the existing arc/shake frames.

return function(mod)
  local ok, AnimPlayer = pcall(require, "src.battle.AnimPlayer")
  if not ok or type(AnimPlayer) ~= "table" then return end

  local BALL_ANIMS = {
    TOSS_ANIM = true,
    GREATTOSS_ANIM = true,
    ULTRATOSS_ANIM = true,
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

  local function drawSkin(id, x, y, angle)
    local g = love.graphics
    local skin = SKINS[id] or SKINS.POKE_BALL
    local oldLineStyle = g.getLineStyle and g.getLineStyle() or nil
    if g.setLineStyle then g.setLineStyle("rough") end
    g.push()
    g.translate(x + 4, y + 4)
    g.rotate(angle or 0)

    set({ .98, .98, .94, 1 })
    g.circle("fill", 0, 0, 3.5)
    set(skin.top)
    g.arc("fill", 0, 0, 3.5, math.pi, math.pi * 2)

    -- Type markings remain readable while the ball rolls.
    set(skin.accent)
    if id == "GREAT_BALL" then
      g.rectangle("fill", -3, -3, 2, 2)
      g.rectangle("fill", 1, -3, 2, 2)
    elseif id == "ULTRA_BALL" then
      g.rectangle("fill", -3, -4, 2, 4)
      g.rectangle("fill", 1, -4, 2, 4)
    elseif id == "MASTER_BALL" then
      g.circle("fill", -2.5, -2.5, 1.5)
      g.circle("fill", 2.5, -2.5, 1.5)
    elseif id == "SAFARI_BALL" then
      g.rectangle("fill", -3, -3, 2, 2)
      g.rectangle("fill", 1, -1, 2, 2)
    end

    set({ .05, .06, .08, 1 })
    g.rectangle("fill", -3.5, -1, 7, 2)
    g.circle("line", 0, 0, 3.5)
    set({ .98, .98, .94, 1 })
    g.circle("fill", 0, 0, 1.4)
    set({ .05, .06, .08, 1 })
    g.circle("line", 0, 0, 1.4)
    g.pop()

    if oldLineStyle and g.setLineStyle then g.setLineStyle(oldLineStyle) end
    -- True-color zones are rectangular re-blits. A single 8x8 zone would
    -- also restore the transparent tile corners and show a pale square over
    -- an SGB battle background. Mark only the circular pixel spans.
    local PaletteFX = require("src.render.PaletteFX")
    for py = 0, 7 do
      local first, last
      for px = 0, 7 do
        local dx, dy = px + .5 - 4, py + .5 - 4
        if dx * dx + dy * dy <= 16 then
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
      if opts and opts.ball then self.__ascendantBallId = opts.ball end
      return originalStart(self, moveId, attackerIsPlayer, opts)
    end

    AnimPlayer.drawSprites = function(self, sprites, colorFn)
      local bridge = AnimPlayer._ascendantBallBridge
      if not (bridge and bridge.enabled()
          and BALL_ANIMS[self.__ascendantBallMove]) then
        return originalDrawSprites(self, sprites, colorFn)
      end

      -- These four original subanimations contain only the one ball tile;
      -- their OAM coordinates already encode the exact arc and wobble.
      for _, sprite in ipairs(sprites or {}) do
        if sprite.x > 0 and sprite.x < 168
            and sprite.y > 0 and sprite.y < 160 then
          local phase = (self.elapsed or 0) + (self.stepIndex or 1) * 3
          local angle
          if self.__ascendantBallMove == "SHAKE_ANIM" then
            angle = math.sin(phase * .9) * .42
          else
            angle = phase * .30
          end
          bridge.draw(self.__ascendantBallId or "POKE_BALL",
            sprite.x - 8, sprite.y - 16, angle)
        end
      end
    end
  end

  mod.exports.modernBallSkins = {
    skins = SKINS,
    enabled = enabled,
    draw = drawSkin,
  }
end
