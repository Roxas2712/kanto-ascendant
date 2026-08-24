-- FireRed Bag presentation for Kanto Ascendant 6.5.16.
--
-- This module deliberately owns presentation only. The ListMenu passed in
-- already contains KASC's FIELD KIT, Quick Select, SELECT move, battle-item,
-- USE/TOSS and safety callbacks; none of those callbacks are replaced here.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local Font = require("src.render.Font")
  local Theme = require("src.ui.Theme")

  local C = {
    aqua = { 192 / 255, 248 / 255, 248 / 255, 1 },
    aquaDark = { 48 / 255, 144 / 255, 136 / 255, 1 },
    blue = { 8 / 255, 120 / 255, 184 / 255, 1 },
    blueDark = { 0 / 255, 72 / 255, 120 / 255, 1 },
    cream = { 255 / 255, 248 / 255, 208 / 255, 1 },
    paper = { 255 / 255, 248 / 255, 224 / 255, 1 },
    gold = { 248 / 255, 184 / 255, 72 / 255, 1 },
    orange = { 208 / 255, 104 / 255, 40 / 255, 1 },
    ink = { 32 / 255, 48 / 255, 56 / 255, 1 },
    white = { 1, 1, 1, 1 },
  }

  local SPRITES = {
    closed = { x = 199, y = 35, w = 52, h = 61 },
    balls = { x = 278, y = 35, w = 53, h = 61 },
    key = { x = 199, y = 111, w = 53, h = 67 },
    items = { x = 278, y = 111, w = 53, h = 67 },
    berry = { x = 356, y = 39, w = 54, h = 60 },
    tmcase = { x = 358, y = 126, w = 53, h = 52 },
  }
  local POCKET_SPRITE = {
    items = "items", medicine = "berry", balls = "balls",
    tms = "tmcase", battle = "closed", key = "key",
  }
  local SHORT_EN = {
    items = "ITEMS", medicine = "MED", balls = "BALLS",
    tms = "TMs", battle = "BATTLE", key = "KEY",
  }
  local SHORT_DE = {
    items = "ITEMS", medicine = "MED", balls = "BÄLLE",
    tms = "TMs", battle = "KAMPF", key = "BASIS",
  }

  local function color(g, value)
    g.setColor(value[1], value[2], value[3], value[4])
  end

  local function tr(list, en, de)
    if i18n and type(i18n.text) == "function" then
      local ok, value = pcall(i18n.text, en, de)
      if ok and type(value) == "string" then return value end
    end
    local translate = list and list.__ascendantTr
    if type(translate) == "function" then
      local ok, value = pcall(translate, en, de)
      if ok and type(value) == "string" then return value end
    end
    return en
  end

  local function panel(g, x, y, w, h, border, inside)
    color(g, border)
    g.rectangle("fill", x, y, w, h)
    color(g, inside)
    g.rectangle("fill", x + 2, y + 2, w - 4, h - 4)
  end

  local function truncate(value, budget)
    local text = tostring(value or "")
    if Font.width(text) <= budget then return text end
    local spans = Font.split(text)
    local fit = Font.spansFitting(spans, math.max(0, budget - 8))
    if fit < 1 then return "." end
    return text:sub(1, spans[fit].to) .. "."
  end

  local function wrap(value, columns)
    local lines = {}
    local pages = require("src.render.TextBox").paginate(value or "", columns or 17)
    for _, page in ipairs(pages) do
      for _, line in ipairs(page) do lines[#lines + 1] = line end
    end
    return lines
  end

  local function pingPongOffset(time, overflow, hold, speed)
    if not (overflow and overflow > 0) then return 0 end
    local travel = overflow / speed
    local cycle = 2 * hold + 2 * travel
    local phase = (time or 0) % cycle
    if phase < hold then return 0 end
    phase = phase - hold
    if phase < travel then return -phase * speed end
    phase = phase - travel
    if phase < hold then return -overflow end
    return -overflow + (phase - hold) * speed
  end

  local function tickerOffset(time, overflow)
    return pingPongOffset(time, overflow, 1.6, 16)
  end

  local function helpOffset(time, overflow)
    return pingPongOffset(time, overflow, 2.0, 6)
  end

  local sheet, failed = nil, false
  local quads = {}
  local function image()
    if sheet or failed then return sheet end
    local ok, result = pcall(function()
      return mod.assets:image("assets/bag-ui-sheet.png")
    end)
    if not ok or not result then failed = true return nil end
    if result.setFilter then result:setFilter("nearest", "nearest") end
    sheet = result
    return sheet
  end

  local function fallbackBag(g, key)
    color(g, C.orange)
    if key == "tmcase" then
      g.rectangle("fill", 8, 20, 37, 21)
      color(g, C.blue); g.circle("fill", 34, 26, 8)
      color(g, C.cream); g.circle("fill", 34, 26, 4)
      return
    end
    g.rectangle("fill", 10, 13, 34, 43)
    g.rectangle("fill", 6, 25, 42, 24)
    color(g, C.gold); g.rectangle("fill", 17, 22, 20, 4)
    color(g, C.blueDark); g.rectangle("fill", 19, 32, 17, 11)
  end

  local function drawBagSprite(g, pocketId)
    local key = POCKET_SPRITE[pocketId] or "closed"
    local source = image()
    if not (source and g.newQuad and g.draw) then
      fallbackBag(g, key)
      return
    end
    local crop = SPRITES[key]
    if not quads[key] then
      quads[key] = g.newQuad(crop.x, crop.y, crop.w, crop.h,
        source:getWidth(), source:getHeight())
    end
    local scale = math.min(48 / crop.w, 57 / crop.h)
    local x = 2 + (48 - crop.w * scale) / 2
    local y = 4 + (57 - crop.h * scale) / 2
    color(g, C.white)
    g.draw(source, quads[key], x, y, 0, scale, scale)
  end

  local function description(list, item)
    if item and type(list.ascendantBagDescription) == "function" then
      local ok, body = pcall(list.ascendantBagDescription, item, list)
      if ok and type(body) == "string" and body ~= "" then return body end
    end
    return tr(list, "Choose an item.", "Wähle ein Item.")
  end

  local function drawRowLabel(g, item, x, y, budget, time)
    local label = tostring(item.label or item.value or "")
    local width = Font.width(label)
    if width <= budget or not g.setScissor then
      Font.draw(truncate(label, budget), x, y)
      return
    end
    local prefixW = item.prefixW or 0
    if item.prefix and prefixW < budget then
      Font.draw(item.prefix, x, y)
      local suffixX, suffixW = x + prefixW, budget - prefixW
      local move = item.move or label
      local overflow = math.max(0, Font.width(move) - suffixW)
      g.setScissor(suffixX, y, suffixW, 8)
      Font.draw(move, suffixX + tickerOffset(time, overflow), y)
      g.setScissor()
      return
    end
    g.setScissor(x, y, budget, 8)
    Font.draw(label, x + tickerOffset(time, width - budget), y)
    g.setScissor()
  end

  local function helpOverlay(list, game, item)
    local overlay = {
      game = game,
      title = item.label or tostring(item.value or "ITEM"),
      lines = wrap(description(list, item), 16),
      helpLabel = tr(list, "HELP", "HILFE"),
      closeLabel = tr(list, "A/B: BACK", "A/B: ZURÜCK"),
      time = 0,
      __kascBagHelp = true,
    }
    function overlay:update(dt)
      self.time = self.time + (dt or 0)
      local input = self.game and self.game.input
      if input and input.wasPressed
          and (input:wasPressed("a") or input:wasPressed("b")
            or input:wasPressed("start")) then
        require("src.core.Sound").play(self.game.data, "Press_AB")
        self.game.stack:pop()
      end
    end
    function overlay:draw()
      local g = love and love.graphics
      if not g then return end
      Font.drawBox(1, 3, 18, 11)
      color(g, C.ink)
      Font.draw(self.helpLabel, 16, 32)
      color(g, C.blueDark); g.rectangle("fill", 16, 43, 128, 1)
      color(g, C.ink); Font.draw(truncate(self.title, 128), 16, 48)
      local viewportY, viewportH = 62, 29
      local overflow = math.max(0, (#self.lines - 3) * 10)
      local offset = helpOffset(self.time, overflow)
      if g.setScissor then g.setScissor(16, viewportY, 128, viewportH) end
      for index, line in ipairs(self.lines) do
        Font.draw(line, 16, viewportY + (index - 1) * 10 + offset)
      end
      if g.setScissor then g.setScissor() end
      color(g, C.blueDark)
      Font.draw(self.closeLabel, 16, 96)
      color(g, C.white)
    end
    return overlay
  end

  local function decorate(list, game, pockets)
    list.__ascendantModernBag = true
    list.__fireRedSkin = true
    list.rows = 4

    -- Replace only this Bag instance's help seam. KASC's other guided/help
    -- menus keep using ascendant_ui.HelpPopup unchanged.
    list.__ascendantShowItemInfo = function(item)
      if not item then return false end
      game.stack:push(helpOverlay(list, game, item))
      return true
    end

    local previousUpdate = list.update
    list.update = function(self, dt)
      self.__fireRedTime = (self.__fireRedTime or 0) + (dt or 0)
      local current = self.items[self.index]
      local id = current and current.value or nil
      if self.__fireRedHelpId ~= id then
        self.__fireRedHelpId = id
        self.__fireRedHelpTime = 0
      else
        self.__fireRedHelpTime = (self.__fireRedHelpTime or 0) + (dt or 0)
      end
      return previousUpdate(self, dt)
    end

    list.draw = function(self)
      local g = love and love.graphics
      if not g then return end
      local pocket = pockets[self.__pocketIndex or 1] or pockets[1]
      color(g, C.aqua); g.rectangle("fill", 0, 0, 160, 144)
      drawBagSprite(g, pocket.id)

      color(g, C.blueDark); g.rectangle("fill", 1, 63, 50, 13)
      color(g, C.white)
      Font.draw(tr(self, SHORT_EN[pocket.id] or "BAG",
        SHORT_DE[pocket.id] or "BEUTEL"), 6, 66)
      for index = 1, #pockets do
        local x, y = 6 + (index - 1) * 8, 83
        color(g, index == self.__pocketIndex and C.gold or C.paper)
        g.circle("fill", x, y, 3.5)
        color(g, index == self.__pocketIndex and C.orange or C.aquaDark)
        g.circle("line", x, y, 3.5)
        if index == self.__pocketIndex then g.circle("fill", x, y, 1.5) end
      end

      color(g, C.blue); g.rectangle("fill", 52, 0, 108, 18)
      color(g, C.blueDark); g.rectangle("fill", 52, 16, 108, 3)
      color(g, C.white); Font.draw(truncate(self.title, 94), 58, 5)
      panel(g, 53, 20, 106, 69, C.aquaDark, C.paper)
      if #self.items == 0 then
        color(g, C.ink)
        Font.draw(tr(self, "Nothing here.", "Fach leer."), 65, 51)
      end
      for row = 1, self.rows do
        local index = (self.scroll or 0) + row
        local item = self.items[index]
        if not item then break end
        local y = 24 + (row - 1) * 16
        if index == self.index then
          color(g, C.gold); g.rectangle("fill", 56, y - 3, 100, 14)
        end
        color(g, C.ink)
        local right = item.right or ""
        local rightX = 155 - Font.width(right)
        drawRowLabel(g, item, 68, y, math.max(8, rightX - 71),
          self.__fireRedTime or 0)
        if right ~= "" then Font.draw(right, rightX, y) end
        if index == self.index then
          Font.drawCode(self.swapIndex == index and Theme.cursorHollow
            or Theme.cursor, 58, y)
        elseif self.swapIndex == index then
          Font.drawCode(Theme.cursorHollow, 58, y)
        end
      end

      panel(g, 2, 91, 156, 51, C.blueDark, C.cream)
      local current = self.items[self.index]
      color(g, C.ink)
      if current then
        local lines = wrap(description(self, current), 17)
        if self.__fireRedHelpId ~= current.value then
          self.__fireRedHelpId = current.value
          self.__fireRedHelpTime = 0
        end
        local offset = helpOffset(self.__fireRedHelpTime or 0,
          math.max(0, (#lines - 3) * 10))
        if g.setScissor then g.setScissor(8, 95, 144, 29) end
        for index, line in ipairs(lines) do
          Font.draw(line, 8, 95 + (index - 1) * 10 + offset)
        end
        if g.setScissor then g.setScissor() end
      else
        Font.draw(tr(self, "This pocket is empty.", "Dieses Fach ist leer."),
          8, 105)
      end
      color(g, C.blueDark); g.rectangle("fill", 4, 128, 152, 12)
      color(g, C.white)
      Font.draw(tr(self, "START:HELP", "START:HILFE"), 7, 131)
      local money = ("¥%d"):format(game.save.money or 0)
      Font.draw(money, 153 - Font.width(money), 131)
      color(g, C.white)
    end

    list.sgbPalettes = function()
      local ok, PaletteFX = pcall(require, "src.render.PaletteFX")
      if ok and PaletteFX and PaletteFX.trueColorZone then
        return { PaletteFX.trueColorZone(0, 0, 19, 17) }
      end
    end
    return list
  end

  return {
    decorate = decorate,
    helpOffset = helpOffset,
  }
end
