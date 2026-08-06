-- FireRed-inspired Bag and Pokémon Storage presentation for Kanto Ascendant.
--
-- This module deliberately changes presentation and navigation only. The
-- engine still owns item use, throwing away items, transfers, release
-- confirmation, save writes and all compatibility hooks.

return function(mod)
  if mod.options:get("modern_storage_ui") == false then return end

  local Font = require("src.render.Font")
  local Boxes = require("src.pokemon.Boxes")
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")

  local C = {
    ink = { 0.08, 0.12, 0.19, 1 },
    paper = { 0.96, 0.93, 0.76, 1 },
    paper2 = { 0.88, 0.83, 0.60, 1 },
    blue = { 0.12, 0.35, 0.65, 1 },
    blue2 = { 0.24, 0.55, 0.82, 1 },
    blue3 = { 0.07, 0.20, 0.40, 1 },
    cream = { 1.00, 0.98, 0.86, 1 },
    orange = { 0.90, 0.45, 0.12, 1 },
    gold = { 1.00, 0.76, 0.18, 1 },
    green = { 0.30, 0.68, 0.43, 1 },
    red = { 0.78, 0.20, 0.22, 1 },
    white = { 1, 1, 1, 1 },
  }

  local function color(value)
    love.graphics.setColor(value[1], value[2], value[3], value[4])
  end

  local function panel(x, y, w, h, fill, border)
    color(fill)
    love.graphics.rectangle("fill", x, y, w, h)
    color(border or C.ink)
    love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1)
  end

  local function german()
    return mod.find("deutsch") ~= nil
      or mod.find("deutsch-blau") ~= nil
      or mod.find("deutsch-gelb") ~= nil
      or mod.options:get("language") == "de"
  end

  local function tr(en, de)
    return german() and de or en
  end

  local function truncate(text, budget)
    text = tostring(text or "")
    if Font.width(text) <= budget then return text end
    local spans = Font.split(text)
    local fit = Font.spansFitting(spans, math.max(0, budget - 8))
    if fit < 1 then return "." end
    return text:sub(1, spans[fit].to) .. "."
  end

  local function trueColor()
    local PaletteFX = require("src.render.PaletteFX")
    return { PaletteFX.trueColorZone(0, 0, 19, 17) }
  end

  local pocketNames = {
    ITEMS = { "ITEMS", "ITEMS" },
    MEDICINE = { "MEDICINE", "MEDIZIN" },
    ["POKé BALLS"] = { "POKé BALLS", "POKéBÄLLE" },
    ["TMs / HMs"] = { "TMs / HMs", "TMs / VMs" },
    ["BATTLE ITEMS"] = { "BATTLE ITEMS", "KAMPF-ITEMS" },
    ["KEY ITEMS"] = { "KEY ITEMS", "BASIS-ITEMS" },
  }

  local function pocketLabel(title)
    local pair = pocketNames[title]
    return pair and pair[german() and 2 or 1] or title
  end

  local function drawPocketIcon(index, x, y, selected)
    color(selected and C.red or C.blue3)
    if index == 1 then
      love.graphics.rectangle("fill", x, y + 2, 7, 5)
      love.graphics.rectangle("line", x + .5, y + .5, 6, 7)
    elseif index == 2 then
      love.graphics.rectangle("fill", x + 2, y, 3, 8)
      love.graphics.rectangle("fill", x, y + 2, 7, 3)
    elseif index == 3 then
      love.graphics.circle("line", x + 3.5, y + 3.5, 3.5)
      love.graphics.rectangle("fill", x, y + 3, 7, 1)
      love.graphics.circle("fill", x + 3.5, y + 3.5, 1)
    elseif index == 4 then
      love.graphics.circle("line", x + 3.5, y + 3.5, 3.5)
      love.graphics.circle("fill", x + 3.5, y + 3.5, 1.5)
    elseif index == 5 then
      love.graphics.polygon("fill", x + 3.5, y, x + 4.5, y + 2.5,
        x + 7, y + 3, x + 5, y + 5, x + 5.5, y + 8,
        x + 3.5, y + 6.5, x + 1.5, y + 8, x + 2, y + 5,
        x, y + 3, x + 2.5, y + 2.5)
    else
      love.graphics.circle("line", x + 2, y + 2, 2)
      love.graphics.rectangle("fill", x + 4, y + 1, 4, 2)
      love.graphics.rectangle("fill", x + 6, y + 3, 2, 2)
    end
  end

  local function drawPocketRail(active)
    local order = {
      "ITEMS", "MEDICINE", "POKé BALLS", "TMs / HMs",
      "BATTLE ITEMS", "KEY ITEMS",
    }
    local labels = german()
      and { "IT", "MD", "PB", "TM", "KP", "BS" }
      or { "IT", "MD", "PB", "TM", "BT", "KY" }
    for i, id in ipairs(order) do
      local y = 23 + (i - 1) * 13
      local selected = id == active
      color(selected and C.gold or C.paper2)
      love.graphics.rectangle("fill", 3, y, selected and 48 or 42, 11)
      color(selected and C.red or C.blue3)
      love.graphics.rectangle("fill", 3, y + 9, selected and 48 or 42, 2)
      drawPocketIcon(i, 8, y + 1, selected)
      color(C.ink)
      Font.draw(labels[i], 21, y + 1)
      if selected then
        Font.drawCode(Theme.cursor, 40, y + 1)
      end
    end
  end

  local function drawBagIcon()
    color(C.orange)
    love.graphics.rectangle("fill", 13, 2, 26, 17)
    love.graphics.rectangle("fill", 9, 7, 34, 10)
    color(C.gold)
    love.graphics.rectangle("fill", 17, 5, 18, 3)
    color(C.blue3)
    love.graphics.rectangle("fill", 20, 10, 12, 6)
    love.graphics.rectangle("line", 13.5, 2.5, 25, 16)
  end

  local function drawBag(menu, game)
    color(C.paper)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    color(C.orange)
    love.graphics.rectangle("fill", 0, 0, 53, 112)
    color(C.paper2)
    love.graphics.rectangle("fill", 0, 104, 53, 8)
    drawBagIcon()
    drawPocketRail(menu.title)

    color(C.blue3)
    love.graphics.rectangle("fill", 53, 0, 107, 18)
    color(C.blue2)
    love.graphics.rectangle("fill", 53, 16, 107, 3)
    color(C.white)
    Font.draw(pocketLabel(menu.title), 59, 5)

    panel(56, 21, 101, 87, C.cream, C.blue3)
    local rows = 5
    if #menu.items == 0 then
      color(C.ink)
      Font.draw(tr("Nothing here.", "Nichts vorhanden."), 68, 58)
    end
    for row = 1, rows do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 25 + (row - 1) * 16
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 59, y - 2, 95, 13)
      end
      color(C.ink)
      local right = item.right or ""
      local rightX = 152 - Font.width(right)
      Font.draw(truncate(item.label or "", math.max(16, rightX - 72)), 69, y)
      if item.right then
        Font.draw(item.right, rightX, y)
      end
      if index == menu.index then
        Font.drawCode(menu.swapIndex == index
          and Theme.cursorHollow or Theme.cursor, 60, y)
      elseif menu.swapIndex == index then
        Font.drawCode(Theme.cursorHollow, 60, y)
      end
    end

    panel(3, 114, 154, 27, C.cream, C.blue3)
    local selected = menu.items[menu.index]
    color(C.ink)
    if selected then
      local name = selected.label or selected.value or ""
      Font.draw(truncate(name, 140), 8, 118)
      Font.draw(tr("A:USE L/R:POCKET", "A:WAHL L/R:FACH"), 8, 130)
    else
      Font.draw(tr("This pocket is empty.", "Dieses Fach ist leer."), 8, 122)
    end
    color(C.white)
  end

  local spriteCache = {}
  local function monSprite(game, mon)
    if not (mon and mon.species and love.graphics.newImage) then return nil end
    local key = table.concat({
      mon.species,
      mon.shiny and "s" or "n",
      tostring(mod.options:get("pokemon_sprite_style")),
      tostring(mod.options:get("sprite_style_box")),
    }, ":")
    if spriteCache[key] ~= nil then
      return spriteCache[key] or nil
    end
    local ok, path = pcall(require("src.pokemon.Sprites").path,
      game.data, mon.species, "front", {
        kind = "box", mon = mon, shiny = mon.shiny,
      })
    if not ok or not path then
      spriteCache[key] = false
      return nil
    end
    local made, image = pcall(love.graphics.newImage, path)
    spriteCache[key] = made and image or false
    return made and image or nil
  end

  local function drawMonImage(game, mon, x, y, w, h)
    local image = monSprite(game, mon)
    if not image or not love.graphics.draw then return false end
    local okW, iw = pcall(image.getWidth, image)
    local okH, ih = pcall(image.getHeight, image)
    if not okW or not okH or iw <= 0 or ih <= 0 then return false end
    local scale = math.min(w / iw, h / ih)
    color(C.white)
    love.graphics.draw(image, x + (w - iw * scale) / 2,
      y + (h - ih * scale) / 2, 0, scale, scale)
    return true
  end

  local function drawBall(x, y, selected)
    color(selected and C.gold or C.white)
    love.graphics.circle("fill", x, y, 5)
    color(C.red)
    love.graphics.arc("fill", x, y, 5, math.pi, math.pi * 2)
    color(C.ink)
    love.graphics.rectangle("fill", x - 5, y - 1, 10, 2)
    love.graphics.circle("line", x, y, 5)
    love.graphics.circle("fill", x, y, 1.5)
  end

  local function boxMonForItem(game, item, title)
    if not item then return nil end
    if title:find("PARTY", 1, true) or title:find("TEAM", 1, true) then
      return game.save.party and game.save.party[item.value]
    end
    local box = Boxes.active(game.save)
    return box and box[item.value]
  end

  local function drawBoxGrid(menu, game)
    color(C.blue3)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    color(C.blue2)
    love.graphics.rectangle("fill", 0, 0, 160, 17)
    color(C.white)
    Font.draw(tr("STORAGE", "LAGERUNG"), 5, 5)
    local current = game.save.currentBox or 1
    Font.draw(Strings("BOX %02d", current), 112, 5)

    panel(3, 20, 47, 105, C.cream, C.blue3)
    local chosen = menu.items[menu.index]
    local mon = boxMonForItem(game, chosen, menu.title or "")
    if mon then
      drawMonImage(game, mon, 7, 24, 39, 45)
      local def = game.data.pokemon[mon.species] or {}
      color(C.ink)
      Font.draw(truncate(mon.nickname or def.name or mon.species, 47), 7, 73)
      Font.draw(Strings("Lv.%d", mon.level or 0), 7, 85)
      Font.draw("A:OK", 7, 108)
      Font.draw(tr("B:BACK", "B:ZUR"), 7, 116)
    end

    panel(53, 20, 104, 105, C.paper, C.blue3)
    color(C.paper2)
    for row = 0, 3 do
      for col = 0, 4 do
        local x, y = 57 + col * 19, 25 + row * 23
        love.graphics.rectangle("fill", x, y, 17, 21)
      end
    end
    for index, item in ipairs(menu.items) do
      if index > 20 then break end
      local col, row = (index - 1) % 5, math.floor((index - 1) / 5)
      local x, y = 65 + col * 19, 35 + row * 23
      local slotMon = boxMonForItem(game, item, menu.title or "")
      local selected = index == menu.index
      if selected then
        color(C.gold)
        love.graphics.rectangle("line", x - 8.5, y - 10.5, 18, 22)
      end
      if not drawMonImage(game, slotMon, x - 7, y - 8, 14, 16) then
        drawBall(x, y, selected)
      end
    end

    color(C.blue2)
    love.graphics.rectangle("fill", 3, 128, 154, 13)
    color(C.white)
    local count = #menu.items
    local selectedDef = mon and game.data.pokemon[mon.species] or nil
    local selectedName = mon
      and (mon.nickname or (selectedDef and selectedDef.name) or mon.species)
      or tr("EMPTY", "LEER")
    Font.draw(truncate(selectedName, 96), 7, 131)
    Font.draw(Strings("%02d/20", count), 116, 131)
    color(C.white)
  end

  local function isBoxList(title)
    if type(title) ~= "string" then return false end
    return title:find("WITHDRAW", 1, true)
      or title:find("RELEASE", 1, true)
      or title:find("DEPOSIT", 1, true)
      or title:find("ABHEBEN", 1, true)
      or title:find("FREILASSEN", 1, true)
      or title:find("ABLEGEN", 1, true)
  end

  local function actionLabel(label)
    label = tostring(label or "")
    if label:find("WITHDRAW", 1, true) or label:find("ABHEBEN", 1, true) then
      return tr("WITHDRAW", "NEHMEN")
    elseif label:find("DEPOSIT", 1, true) or label:find("ABLEGEN", 1, true) then
      return tr("DEPOSIT", "ABLEGEN")
    elseif label:find("RELEASE", 1, true)
        or label:find("FREILASSEN", 1, true) then
      return tr("RELEASE", "FREILASS.")
    elseif label:find("CHANGE", 1, true) or label:find("WECHSEL", 1, true) then
      return tr("CHANGE BOX", "BOX WECHS.")
    elseif label:find("PRINT", 1, true) or label:find("DRUCK", 1, true) then
      return tr("PRINT BOX", "BOX DRUCK.")
    elseif label:find("SEE", 1, true) or label:find("TSCH", 1, true) then
      return tr("EXIT", "ENDE")
    end
    return truncate(label, 72)
  end

  local function gridUpdate(self)
    local input, count = self.game.input, #self.items
    if count == 0 then
      if input:wasPressed("a") or input:wasPressed("b") then
        self.game.stack:pop()
        if self.onCancel then self.onCancel() end
      end
      return
    end
    local nextIndex = self.index
    if input:wasPressed("left") then
      nextIndex = math.max(1, self.index - 1)
    elseif input:wasPressed("right") then
      nextIndex = math.min(count, self.index + 1)
    elseif input:wasPressed("up") then
      nextIndex = math.max(1, self.index - 5)
    elseif input:wasPressed("down") then
      nextIndex = math.min(count, self.index + 5)
    elseif input:wasPressed("b") then
      self.game.stack:pop()
      if self.onCancel then self.onCancel() end
      return
    elseif input:wasPressed("a") then
      if self.onChoose then self.onChoose(self.items[self.index], self) end
      return
    end
    self.index = nextIndex
  end

  local okList, ListMenu = pcall(require, "src.ui.ListMenu")
  if okList and ListMenu and not ListMenu.__ascendantFireRedStorage then
    ListMenu.__ascendantFireRedStorage = true
    local newList = ListMenu.new
    ListMenu.new = function(game, title, items, opts)
      local list = newList(game, title, items, opts)
      if isBoxList(title) then
        list.__ascendantBoxGrid = true
        list.sgbPalettes = trueColor
        list.update = gridUpdate
        list.draw = function(self) drawBoxGrid(self, game) end
      end
      return list
    end
  end

  local okBox, BoxMenu = pcall(require, "src.ui.BoxMenu")
  if okBox and BoxMenu and not BoxMenu.__ascendantModernStorage then
    BoxMenu.__ascendantModernStorage = true
    local newBox = BoxMenu.new
    BoxMenu.new = function(game, ...)
      local menu = newBox(game, ...)
      menu.sgbPalettes = trueColor
      menu.draw = function(self)
        color(C.blue3)
        love.graphics.rectangle("fill", 0, 0, 160, 144)
        color(C.blue2)
        love.graphics.rectangle("fill", 0, 0, 160, 18)
        color(C.white)
        Font.draw(tr("POKéMON STORAGE", "POKéMON-LAGERUNG"), 6, 5)

        panel(4, 22, 91, 116, C.cream, C.blue3)
        for index, item in ipairs(self.items or {}) do
          local y = 28 + (index - 1) * 18
          if index == self.index then
            color(C.gold)
            love.graphics.rectangle("fill", 7, y - 3, 85, 14)
          end
          color(C.ink)
          Font.draw(actionLabel(item.label), 17, y)
          if index == self.index then Font.drawCode(Theme.cursor, 8, y) end
        end

        panel(99, 22, 57, 116, C.paper, C.blue3)
        local box = Boxes.active(game.save)
        local count = box and #box or 0
        color(C.blue)
        love.graphics.rectangle("fill", 103, 27, 49, 17)
        color(C.white)
        Font.draw(Strings("BOX %02d", game.save.currentBox or 1), 107, 32)
        for i = 1, math.min(count, 20) do
          local col, row = (i - 1) % 4, math.floor((i - 1) / 4)
          drawBall(108 + col * 12, 55 + row * 13, false)
        end
        color(C.ink)
        Font.draw(Strings("%02d/20", count), 113, 122)
        color(C.white)
      end
      return menu
    end
  end

  -- The integrated Useful Bag still owns item behavior and pockets. This
  -- wrapper replaces only the inherited monochrome ListMenu renderer.
  if not mod.exports.externalUsefulBag then
    local okBag, BagMenu = pcall(require, "src.ui.BagMenu")
    if okBag and BagMenu and not BagMenu.__ascendantModernStorage then
      BagMenu.__ascendantModernStorage = true
      local newBag = BagMenu.new
      BagMenu.new = function(game, ...)
        local menu = newBag(game, ...)
        menu.rows = 5
        menu.__ascendantModernBag = true
        menu.sgbPalettes = trueColor
        menu.draw = function(self) drawBag(self, game) end
        return menu
      end
    end
  end

  mod.exports.modernStorageUi = {
    isBoxList = isBoxList,
    drawBag = drawBag,
    drawBoxGrid = drawBoxGrid,
  }
end
