-- Crystal-style Egg hatch presentation for Kanto Ascendant.
--
-- Crystal-251 currently jumps from a short prompt to the hatch result.  This
-- state independently recreates the missing visual beat from pokecrystal:
-- the Egg settles, wobbles faster, cracks, throws shell fragments and finally
-- reveals the newborn Pokemon before the normal localized result text.

return function(mod, opts)
  opts = opts or {}
  local M = {}
  local CRYSTAL_251_EGG = "crystal_251/generated/egg/front.png"

  local SETTLE_END, WOBBLE_END, CRACK_END, REVEAL_END = 24, 112, 154, 210
  local FRAGMENT_END = 189

  function M.phase(frame)
    frame = math.max(0, math.floor(tonumber(frame) or 0))
    if frame < SETTLE_END then return "settle" end
    if frame < WOBBLE_END then return "wobble" end
    if frame < CRACK_END then return "crack" end
    if frame < REVEAL_END then return "reveal" end
    return "message"
  end

  function M.fragmentsVisible(frame)
    frame = math.max(0, math.floor(tonumber(frame) or 0))
    return frame >= CRACK_END and frame < FRAGMENT_END
  end

  local HatchState = {}
  HatchState.__index = HatchState
  HatchState.isOpaque = true

  function HatchState:sgbPalettes(game)
    local P = require("src.render.PaletteFX")
    if self.finalized and self.mon then
      local colors = P.monPal(game.data, self.mon.species)
      if colors then return { P.whole(colors) } end
    end
    return P.wholeNamed(game.data, "MEWMON")
  end

  local function loadFront(game, mon)
    local path, trueColor = require("src.pokemon.Sprites").path(
      game.data, mon.species, "front", { mon = mon, kind = "egg_hatch" })
    if not path then return nil, false end
    -- Some optional 251 packs use an opaque white canvas. Battles can hide
    -- that against their own paper field, but the hatch movie's tinted paper
    -- exposes a rectangle. Flood only the white area connected to the image
    -- border, preserving enclosed white highlights in the actual Pokemon.
    if trueColor and love.image and love.image.newImageData then
      local okData, data = pcall(love.image.newImageData, path)
      if okData and data then
        local w, h = data:getDimensions()
        local seen, qx, qy, first, last = {}, {}, {}, 1, 0
        local function key(x, y) return y * w + x end
        local function paper(x, y)
          local r, g, b, a = data:getPixel(x, y)
          return a > 0.5 and r > 0.92 and g > 0.92 and b > 0.92
        end
        local function push(x, y)
          if x < 0 or y < 0 or x >= w or y >= h then return end
          local k = key(x, y)
          if seen[k] or not paper(x, y) then return end
          seen[k], last = true, last + 1
          qx[last], qy[last] = x, y
        end
        for x = 0, w - 1 do push(x, 0); push(x, h - 1) end
        for y = 0, h - 1 do push(0, y); push(w - 1, y) end
        while first <= last do
          local x, y = qx[first], qy[first]
          first = first + 1
          local r, g, b = data:getPixel(x, y)
          data:setPixel(x, y, r, g, b, 0)
          push(x - 1, y); push(x + 1, y)
          push(x, y - 1); push(x, y + 1)
        end
        local okImage, image = pcall(love.graphics.newImage, data)
        -- The flood-cutout changes only border-connected paper alpha.  The
        -- Pokemon pixels remain authored full colour and must retain the
        -- resolver's true-colour contract through the hatch palette pass.
        if okImage then return image, true end
      end
    end
    local ok, image = pcall(love.graphics.newImage, path)
    -- A renderer without ImageData cannot perform the optional paper cutout,
    -- but it must still preserve the resolver's colour ownership bit.  Normal
    -- four-shade sprites continue to return false here.
    return ok and image or nil, trueColor == true
  end

  local function sound(data, id)
    pcall(require("src.core.Sound").play, data, id)
  end

  local function optionalCrystalEgg()
    local ok, image = pcall(love.graphics.newImage, CRYSTAL_251_EGG)
    return ok and image or nil
  end

  function HatchState.new(game, eggs, finalize)
    local self = setmetatable({}, HatchState)
    self.game = game
    self.eggs = {}
    for _, mon in ipairs(eggs or {}) do self.eggs[#self.eggs + 1] = mon end
    self.finalize = assert(finalize, "Egg hatch finalizer is required")
    -- Crystal-251 legally extracts this picture from the user's own ROM. Use
    -- it in-place when that mod/cache is mounted; never copy or require it.
    self.eggSprite = optionalCrystalEgg()
    self.index = 0
    self:beginNext()
    return self
  end

  function HatchState:beginNext()
    self.index = self.index + 1
    self.mon = self.eggs[self.index]
    self.frame = 0
    self.finalized = false
    self.messagePushed = false
    self.sprite, self.spriteTrueColor = nil, false
    if self.mon then
      local Music = require("src.core.Music")
      Music.play(self.game.data, Music.special(self.game.data, "evolution"))
    end
  end

  function HatchState:finishMessage()
    if self.eggs[self.index + 1] then
      self:beginNext()
      return
    end
    self.game.stack:pop()
    require("src.core.Music").restoreMap(self.game.data)
  end

  function HatchState:update()
    self.frame = self.frame + 1
    if self.frame == 36 or self.frame == 62 or self.frame == 84
        or self.frame == 101 then
      sound(self.game.data, "Tink")
    elseif self.frame == WOBBLE_END then
      sound(self.game.data, "Ball_Poof")
    end

    if not self.finalized and self.frame >= CRACK_END then
      self.finalized = true
      self.message = self.finalize(self.mon)
      self.sprite, self.spriteTrueColor = loadFront(self.game, self.mon)
      require("src.core.Sound").playCry(self.game.data, self.mon.species)
    end

    if not self.messagePushed and self.frame >= REVEAL_END then
      self.messagePushed = true
      self.game.stack:push(require("src.render.TextBox").new(
        self.game, self.message, function() self:finishMessage() end))
    end
  end

  local function eggOffset(frame)
    if M.phase(frame) ~= "wobble" then return 0, 0 end
    local p = (frame - SETTLE_END) / (WOBBLE_END - SETTLE_END)
    local period = math.max(4, 16 - math.floor(p * 10))
    local beat = math.floor(frame / period) % 4
    local amplitude = p < 0.45 and 1 or p < 0.75 and 2 or 3
    return ({ -amplitude, 0, amplitude, 0 })[beat + 1], beat == 1 and 1 or 0
  end

  -- A deliberately small, tile-like Egg.  It is drawn procedurally so the
  -- mod does not redistribute a Crystal ROM graphic.
  local EGG_SPANS = {
    { 16, 24 }, { 12, 28 }, { 8, 32 }, { 8, 32 }, { 4, 36 }, { 4, 36 },
    { 0, 40 }, { 0, 40 }, { 0, 40 }, { 4, 36 }, { 4, 36 }, { 8, 32 },
    { 12, 28 }, { 16, 24 },
  }

  local function drawEgg(frame, sprite)
    local ox, oy = eggOffset(frame)
    local x, y = 60 + ox, 34 + oy
    if sprite then
      x = math.floor((160 - sprite:getWidth()) / 2) + ox
      y = 42 + oy
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(sprite, x, y)
    else
      for row, span in ipairs(EGG_SPANS) do
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.rectangle("fill", x + span[1] - 4, y + (row - 1) * 4,
          span[2] - span[1] + 8, 4)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", x + span[1], y + (row - 1) * 4,
          span[2] - span[1], 4)
      end
      -- Crystal's Egg spots, kept in the same four-shade visual language.
      love.graphics.setColor(0.55, 0.55, 0.55, 1)
      love.graphics.rectangle("fill", x + 12, y + 12, 8, 8)
      love.graphics.rectangle("fill", x + 24, y + 28, 8, 8)
      love.graphics.rectangle("fill", x + 8, y + 40, 8, 8)
    end

    if frame >= WOBBLE_END then
      local depth = math.min(4, 1 + math.floor((frame - WOBBLE_END) / 9))
      local cracks = {
        { 20, 8, 16, 16 }, { 16, 16, 24, 22 },
        { 24, 22, 18, 30 }, { 18, 30, 28, 38 },
      }
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.setLineWidth(2)
      for i = 1, depth do
        local c = cracks[i]
        love.graphics.line(x + c[1], y + c[2], x + c[3], y + c[4])
      end
      love.graphics.setLineWidth(1)
    end
  end

  local FRAGMENTS = {
    { -22, -12, -34, -28 }, { 20, -10, 34, -24 },
    { -14, 8, -30, 20 }, { 16, 10, 31, 24 }, { 0, -18, 3, -38 },
  }

  local function drawFragments(frame)
    local p = math.min(1, math.max(0, (frame - CRACK_END) / 34))
    love.graphics.setColor(0.25, 0.25, 0.25, 1)
    local PaletteFX = require("src.render.PaletteFX")
    for i, f in ipairs(FRAGMENTS) do
      local x = 80 + f[1] + (f[3] - f[1]) * p
      local y = 62 + f[2] + (f[4] - f[2]) * p + p * p * 18
      local size = i % 2 == 0 and 5 or 4
      love.graphics.polygon("fill", x, y, x + size, y + 2,
        x + 2, y + size)
      -- Shell fragments are neutral animation ink, not Pokemon palette
      -- shades.  Excluding each tiny polygon from the SGB remap prevents gray
      -- pieces from becoming detached purple pixels during the reveal.
      PaletteFX.markTrueColor(math.floor(x), math.floor(y), size + 1, size + 1)
    end
  end

  function HatchState:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    local phase = M.phase(self.frame)
    if phase == "settle" or phase == "wobble" or phase == "crack" then
      drawEgg(self.frame, self.eggSprite)
    else
      if self.sprite then
        local w, h = self.sprite:getDimensions()
        local x, y = math.floor((160 - w) / 2), math.max(8, 72 - h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(self.sprite, x, y)
        if self.spriteTrueColor then
          require("src.render.PaletteFX").markTrueColor(x, y, w, h)
        end
      end
      if M.fragmentsVisible(self.frame) then drawFragments(self.frame) end
    end
    love.graphics.setColor(0, 0, 0, 1)
    if self.frame < 18 then require("src.render.Font").draw("Oh?", 8, 120) end
    love.graphics.setColor(1, 1, 1, 1)
  end

  function M.start(game, eggs, finalize)
    if not (game and game.stack and eggs and #eggs > 0) then return false end
    game.stack:push(HatchState.new(game, eggs, finalize))
    return true
  end

  M.State = HatchState
  M.optionalCrystalEggPath = CRYSTAL_251_EGG
  M.timeline = {
    settleEnd = SETTLE_END, wobbleEnd = WOBBLE_END,
    crackEnd = CRACK_END, fragmentEnd = FRAGMENT_END,
    revealEnd = REVEAL_END,
  }
  return M
end
