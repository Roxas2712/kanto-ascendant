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

  local function option(game, key)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    local value = bucket and bucket[key]
    if value == nil then value = mod.options:get(key) end
    return value
  end

  local function bagMode(game)
    if option(game, "ascendant_useful_bag") == false then return "off" end
    return option(game, "ascendant_bag_mode") or "pockets"
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
    local mode = bagMode(game)
    local hasPockets = mode == "pockets"
    color(C.paper)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    color(C.orange)
    love.graphics.rectangle("fill", 0, 0, 53, 112)
    color(C.paper2)
    love.graphics.rectangle("fill", 0, 104, 53, 8)
    drawBagIcon()
    if hasPockets then
      drawPocketRail(menu.title)
    else
      color(C.cream)
      love.graphics.rectangle("fill", 5, 34, 43, 52)
      color(C.blue3)
      Font.draw(tr("BAG", "BEUTEL"), 9, 43)
      Font.draw(mode == "expanded" and "999" or "20", 13, 61)
    end

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
      -- Keep the empty-state copy inside the 101 px item panel in every
      -- language. The previous German line was 128 px wide and visibly
      -- escaped through the right-hand border at wide desktop layouts.
      Font.draw(tr("Empty.", "Fach leer."), 68, 58)
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
      Font.draw(hasPockets
        and tr("A:USE L/R:POCKET", "A:WAHL L/R:FACH")
        or tr("A:USE  B:BACK", "A:WAHL B:ZUR"), 8, 130)
    else
      Font.draw(tr("This pocket", "Dieses Fach"), 8, 118)
      Font.draw(tr("is empty.", "ist leer."), 8, 130)
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

  -- Optional right-hand Box-grid art. These sheets already ship inside the
  -- vendored Wilds runtime; no asset is copied or transformed here. Keep this
  -- resolver independent from monSprite() so the large left preview continues
  -- to use the exact existing Box/front-sprite path.
  local boxGridSheetCache = {}
  local BOX_GRID_SHEET_ROOT =
    "vendor/wilds_1_12_2/assets/bundled_runtime/followsprites_runtime"

  local function boxGridSourceDex(game, mon)
    if not (game and game.data and game.data.pokemon and mon and mon.species) then
      return nil, "missing species"
    end
    -- Gorochu has dedicated Ascendant art but no HGSS source identity. It must
    -- stay on the established Box renderer rather than borrow another species.
    if mon.species == "GOROCHU" then return nil, "gorochu" end
    if mon.form ~= nil and mon.form ~= false and mon.form ~= 0
        and mon.form ~= ""
        and mon.form ~= "base" and mon.form ~= "default" then
      return nil, "unsupported form"
    end

    local runtime = mod.exports and mod.exports.extendedSpeciesRuntime
    if runtime and type(runtime.sourceDex) == "function" then
      local ok, value = pcall(runtime.sourceDex, mon, game.data)
      value = ok and tonumber(value) or nil
      if value and value >= 1 then return math.floor(value), "runtime" end
    end

    local def = game.data.pokemon[mon.species]
    local source = def and tonumber(def.sourceDex)
    if source and source >= 1 then return math.floor(source), "definition" end
    -- A private catalogue slot is never a National-Dex art identity. If the
    -- source mapping is unavailable, fail closed to the existing grid icon.
    if def and def.internalRuntimeDex ~= nil then
      return nil, "private sourceDex missing"
    end
    local ordinaryDex = def and tonumber(def.dex)
    if ordinaryDex and ordinaryDex >= 1 then
      return math.floor(ordinaryDex), "ordinary dex"
    end
    return nil, "sourceDex missing"
  end

  local function boxGridWalkerRelative(game, mon)
    local dex, identity = boxGridSourceDex(game, mon)
    if not dex then return nil, identity end
    local isShiny = mon.shiny == true
    local shiny = mod.exports and mod.exports.shinySystem
    if shiny and type(shiny.isShiny) == "function" then
      local ok, value = pcall(shiny.isShiny, mon)
      if ok then isShiny = value == true end
    end
    local variant = isShiny and "shiny" or "normal"
    return ("%s/%03d-%s.png"):format(BOX_GRID_SHEET_ROOT, dex, variant),
      variant, dex, identity
  end

  local function readableAsset(relative)
    if type(relative) ~= "string" or type(mod.read) ~= "function" then
      return false
    end
    local ok, bytes = pcall(mod.read, mod, relative)
    return ok and bytes ~= nil
  end

  local function boxGridWalkerAsset(game, mon)
    local relative, variant, dex, identity = boxGridWalkerRelative(game, mon)
    if not relative then return nil, variant end
    local key = tostring(dex) .. ":" .. variant
    local cached = boxGridSheetCache[key]
    if cached ~= nil then
      return cached or nil, cached and identity or "missing asset"
    end
    if not readableAsset(relative) or not (love.graphics.newImage
        and love.graphics.newQuad and love.graphics.draw) then
      boxGridSheetCache[key] = false
      return nil, "missing asset"
    end

    local loadPath = relative
    if mod.assets and type(mod.assets.path) == "function" then
      local ok, resolved = pcall(mod.assets.path, mod.assets, relative)
      if ok and type(resolved) == "string" and resolved ~= "" then
        loadPath = resolved
      end
    end
    local made, image = pcall(love.graphics.newImage, loadPath)
    if not made or not image then
      boxGridSheetCache[key] = false
      return nil, "image load failed"
    end
    local okW, width = pcall(image.getWidth, image)
    local okH, height = pcall(image.getHeight, image)
    if not okW or not okH or width ~= 16 or height ~= 96 then
      boxGridSheetCache[key] = false
      return nil, "invalid sheet dimensions"
    end
    local madeQuad, quad = pcall(love.graphics.newQuad,
      0, 0, 16, 16, width, height)
    if not madeQuad or not quad then
      boxGridSheetCache[key] = false
      return nil, "quad creation failed"
    end
    local asset = {
      image = image,
      quad = quad,
      relative = relative,
      variant = variant,
      sourceDex = dex,
    }
    boxGridSheetCache[key] = asset
    return asset, identity
  end

  local function drawBoxGridWalker(game, mon, x, y)
    if option(game, "box_grid_icon_style") ~= "hgss_walker" then
      return false
    end
    local asset = boxGridWalkerAsset(game, mon)
    if not asset then return false end
    color(C.white)
    love.graphics.draw(asset.image, asset.quad, x - 8, y - 8)
    return true
  end

  local function drawWrapped(text, x, y, width)
    text = tostring(text or "")
    local whole = Font.split(text)
    -- Species names do not contain spaces.  If one exceeds the compact
    -- detail column, balance the two visible lines instead of leaving a
    -- stranded last glyph (the old BLAZIKE / N result was technically whole
    -- but not a readable name treatment).
    if #whole > Font.spansFitting(whole, width) and not text:find("%s") then
      local middle = math.ceil(#whole / 2)
      Font.draw(text:sub(1, whole[middle].to), x, y)
      Font.draw(text:sub(whole[middle + 1].from), x, y + 8)
      return 2
    end
    local lines, offset = 0, 1
    while offset <= #text do
      local tail = text:sub(offset)
      local spans = Font.split(tail)
      local fit = Font.spansFitting(spans, width)
      fit = math.max(1, fit)
      local line = tail:sub(1, spans[fit].to)
      Font.draw(line, x, y + lines * 8)
      lines, offset = lines + 1, offset + spans[fit].to
    end
    return lines
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

  local function storageGenderSymbol(game, mon)
    local gender = mod.exports and mod.exports.pokemonGender
    if not (gender and type(gender.symbol) == "function" and mon) then
      return nil
    end
    return gender.symbol(mon, game)
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

    panel(3, 20, 64, 105, C.cream, C.blue3)
    local chosen = menu.items[menu.index]
    local mon = boxMonForItem(game, chosen, menu.title or "")
    if mon then
      drawMonImage(game, mon, 7, 24, 56, 45)
      local def = game.data.pokemon[mon.species] or {}
      color(C.ink)
      -- Keep full names in sharp 8px glyphs.  The previous horizontal scale
      -- made TREECKO technically complete but visually muddy; wrap the rare
      -- long name instead, and move the following fields as one block.
      local nameLines = drawWrapped(mon.nickname or def.name or mon.species, 7, 73, 56)
      local detailsY = 81 + nameLines * 4
      Font.draw(Strings("Lv.%d", mon.level or 0), 7, detailsY)
      -- The previous late gender overlay started at x=35 on the level row,
      -- which overwrote the first digit of every two/three-digit level.  The
      -- FireRed panel has a clean unused row below it; keep a permanent field
      -- there so female, male and genderless records never collide with name,
      -- status or Lv.100.
      Font.draw(tr("SEX:", "GES:"), 7, detailsY + 10)
      Font.draw(storageGenderSymbol(game, mon) or "-", 39, detailsY + 10)
      Font.draw("A:OK", 7, detailsY + 19)
      Font.draw(tr("B:BACK", "B:ZUR"), 7, detailsY + 27)
    end

    panel(70, 20, 87, 105, C.paper, C.blue3)
    color(C.paper2)
    for row = 0, 3 do
      for col = 0, 4 do
        local x, y = 72 + col * 17, 25 + row * 23
        love.graphics.rectangle("fill", x, y, 15, 21)
      end
    end
    for index, item in ipairs(menu.items) do
      if index > 20 then break end
      local col, row = (index - 1) % 5, math.floor((index - 1) / 5)
      local x, y = 79 + col * 17, 35 + row * 23
      local slotMon = boxMonForItem(game, item, menu.title or "")
      local selected = index == menu.index
      if selected then
        color(C.gold)
        love.graphics.rectangle("line", x - 7.5, y - 10.5, 16, 22)
      end
      if not drawBoxGridWalker(game, slotMon, x, y)
          and not drawMonImage(game, slotMon, x - 7, y - 8, 14, 16) then
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
    -- PlayerPC uses WITHDRAW ITEM / DEPOSIT ITEM for item storage. Those
    -- are ordinary four-row ListMenus with a bottom message box, not
    -- Pokémon grids; treating them as box lists hides the quantity footer
    -- and lets rows overlap the prompt.
    if title:find("ITEM", 1, true) then return false end
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

  local function localizedBoxTitle(title)
    title = tostring(title or "")
    if not german() then return title end
    return title:gsub("PARTY", "TEAM")
      :gsub("DEPOSIT", "ABLEGEN")
      :gsub("WITHDRAW", "NEHMEN")
      :gsub("RELEASE", "FREILASSEN")
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
        list.title = localizedBoxTitle(title)
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
      menu.__ascendantBoxSwitchLegend =
        option(game, "fast_box_switch") ~= false and "L/R BOX" or nil
      local vanillaUpdate = menu.update
      menu.update = function(self, dt)
        local input = self.game.input
        if option(self.game, "fast_box_switch") ~= false
            and (input:wasPressed("left") or input:wasPressed("right")) then
          local direction = input:wasPressed("right") and 1 or -1
          local count = Boxes.COUNT or #Boxes.ensure(self.game.save)
          self.game.save.currentBox =
            (((self.game.save.currentBox or 1) - 1 + direction) % count) + 1
          require("src.core.Sound").play(self.game.data, "Swap")
          if self.game.writeSave then self.game:writeSave() end
          return
        end
        return vanillaUpdate(self, dt)
      end
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
        if option(game, "fast_box_switch") ~= false then
          color(C.blue)
          Font.draw("L/R  BOX", 17, 124)
        end

        panel(99, 22, 57, 116, C.paper, C.blue3)
        local box = Boxes.active(game.save)
        local count = box and #box or 0
        color(C.blue)
        love.graphics.rectangle("fill", 103, 27, 49, 17)
        color(C.white)
        -- The Gen-I font has no angle-bracket glyphs. Keep the header inside
        -- the 49 px panel and let the live left/right controls communicate
        -- switching without rendering replacement squares.
        Font.draw(Strings("BOX %02d", game.save.currentBox or 1), 104, 32)
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
  local mode = bagMode()
  if not mod.exports.externalUsefulBag
      and (mode == "skin" or mode == "expanded" or mode == "pockets") then
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

  -- Engine PC submenus pass these labels as raw English strings. Keep the
  -- wrapper active even when the language changes after load. This preserves
  -- the exact player name and uses the German possessive without rewriting
  -- ASH/RED or any custom name.
  local okMenu, Menu = pcall(require, "src.ui.Menu")
  if okMenu and Menu and not Menu.__ascendantStorageLabels then
    Menu.__ascendantStorageLabels = true
    local newMenu = Menu.new
    Menu.new = function(game, items, opts)
      for _, row in ipairs(items or {}) do
        local playerName = game.save and game.save.player
          and game.save.player.name or "RED"
        if type(row.label) == "string"
            and row.label == playerName .. "'s PC" then
          row.label = playerName .. (german() and "s PC" or "'s PC")
        elseif german() and row.label == "DEPOSIT" then
          row.label = "ABLEGEN"
        elseif german() and row.label == "WITHDRAW" then
          row.label = "NEHMEN"
        elseif german() and row.label == "RELEASE" then
          row.label = "FREILASSEN"
        end
      end
      return newMenu(game, items, opts)
    end
  end

  mod.exports.modernStorageUi = {
    isBoxList = isBoxList,
    genderSymbol = storageGenderSymbol,
    drawBag = drawBag,
    drawBoxGrid = drawBoxGrid,
    boxGridSourceDex = boxGridSourceDex,
    boxGridWalkerRelative = boxGridWalkerRelative,
    boxGridWalkerAsset = boxGridWalkerAsset,
  }
end
