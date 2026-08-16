-- Compatibility for apps predating SpriteRenderer's alpha-safe true-colour
-- late pass.  Those builds exempted a complete 16x16 world-canvas rectangle
-- from the palette shader; transparent pixels therefore restored raw grey
-- terrain as the conspicuous box seen around Crystal players/followers.

return function()
  local C = {}

  function C.install()
    local SpriteRenderer = require("src.render.SpriteRenderer")
    local PaletteFX = require("src.render.PaletteFX")
    if SpriteRenderer.__alphaSafeTrueColorWorld
        or SpriteRenderer.__kantoAscendantAlphaSafeTrueColor then
      return true, "native"
    end
    if type(PaletteFX.spriteRedrawPassActive) ~= "function"
        or type(PaletteFX.markSpriteRedraw) ~= "function" then
      return false, "unsupported"
    end

    SpriteRenderer.__kantoAscendantAlphaSafeTrueColor = true
    local innerDraw = assert(SpriteRenderer.draw)
    local innerDrawTile = assert(SpriteRenderer.drawTile)
    local innerMarkTrueColor = assert(PaletteFX.markTrueColor)
    local active

    -- Keep the interception permanently installed so no per-frame function
    -- replacement can leak across an error.  It is inert unless one of the
    -- two narrow SpriteRenderer wrappers below has entered its true-colour
    -- world call.
    PaletteFX.markTrueColor = function(x, y, w, h, ...)
      if active and w == active.width and h == active.height then
        active.suppressed = true
        return
      end
      return innerMarkTrueColor(x, y, w, h, ...)
    end

    local function protectedCall(fn, ...)
      local args = { ... }
      local receipt = active
      local ok, result = xpcall(function()
        return fn(unpack(args))
      end, function(err) return tostring(err) end)
      active = nil
      if not ok then error(result, 0) end
      return result, receipt
    end

    SpriteRenderer.draw = function(self, px, py, camX, camY, facing,
        walkPhase, stepFlip, topHalf)
      if not (self.def and self.def.trueColor
          and PaletteFX.spriteRedrawPassActive()) then
        return innerDraw(self, px, py, camX, camY, facing,
          walkPhase, stepFlip, topHalf)
      end
      local before = #PaletteFX.spriteRedraws()
      active = { width = 16, height = 16, suppressed = false }
      local result, receipt = protectedCall(innerDraw, self, px, py, camX, camY,
        facing, walkPhase, stepFlip, topHalf)
      -- The old renderer was the only path that emitted the intercepted
      -- rectangle.  Reconstruct exactly the already-drawn image/quad and
      -- queue it for the existing alpha-respecting late sprite pass.
      -- (The native renderer grows spriteRedraws itself and never reaches
      -- this compatibility module because of its capability bit.)
      if receipt.suppressed and #PaletteFX.spriteRedraws() == before then
        local frame
        if (self.def.frames or 0) <= 1 then
          frame = 0
        elseif self.def.walker and walkPhase == 1 then
          frame = SpriteRenderer.WALK[facing]
        else
          frame = SpriteRenderer.STAND[facing]
        end
        frame = frame or 0
        local quad = topHalf and self.halfFrames and self.halfFrames[frame]
          or self.frames[frame] or self.frames[0]
        local x = math.floor(px - camX)
        local y = math.floor(py - camY) - 4
        local flip = facing == "right"
          or (facing == "down" or facing == "up")
            and walkPhase == 1 and stepFlip
        PaletteFX.markSpriteRedraw(self.image, quad,
          flip and x + 16 or x, y, flip and -1 or 1)
      end
      return result
    end

    SpriteRenderer.drawTile = function(self, path, x, y, flip)
      if not (self.def and self.def.trueColor
          and PaletteFX.spriteRedrawPassActive()) then
        return innerDrawTile(self, path, x, y, flip)
      end
      local before = #PaletteFX.spriteRedraws()
      active = { width = 16, height = 8, suppressed = false }
      local result, receipt = protectedCall(innerDrawTile,
        self, path, x, y, flip)
      if receipt.suppressed and #PaletteFX.spriteRedraws() == before then
        local image = require("src.render.Assets").image(path)
        local quad = self.tileQuads and self.tileQuads[path]
        PaletteFX.markSpriteRedraw(image, quad,
          flip and x + 16 or x, y, flip and -1 or 1)
      end
      return result
    end

    return true, "compat"
  end

  return C
end
