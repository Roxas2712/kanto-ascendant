-- FireRed-inspired Bag and Pokémon Storage presentation for Kanto Ascendant.
--
-- The engine remains the sole storage authority. The optional FRLG organizer
-- mutates only its existing party/Box arrays for explicit MOVE pick-up/drop;
-- item use, release confirmation, serialization and compatibility hooks stay
-- on their established engine paths.

return function(mod, opts)
  opts = opts or {}
  local i18n = assert(opts.i18n, "modern_storage_ui requires i18n")
  if mod.options:get("modern_storage_ui") == false then return end
  local legacyBankCard = opts.vascLegacyBankCard

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
    return i18n.isGerman()
  end

  local function tr(en, de)
    return i18n.text(en, de)
  end

  local function option(game, key)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    local value = bucket and bucket[key]
    if value == nil then value = mod.options:get(key) end
    return value
  end

  local function readableAsset(relative)
    if type(relative) ~= "string" or type(mod.read) ~= "function" then
      return false
    end
    local ok, bytes = pcall(mod.read, mod, relative)
    return ok and bytes ~= nil
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

  -- The source sheet is the original 240x160 FireRed/LeafGreen PC artwork.
  -- It stays intact and is sampled through nearest-neighbour Quads on the
  -- organizer's 480x320 integer surface. No derivative fragments are stored.
  local PC_ATLAS_PATH = "assets/ui/frlg_pc/interface.png"
  local PC_ATLAS_W, PC_ATLAS_H = 641, 1240
  local FRLG_UI_W, FRLG_UI_H, FRLG_UI_SCALE = 480, 320, 2
  local FRLG_WIDE_W, FRLG_WIDE_H = 512, 288
  -- The authentic 240x160 Box already uses its final row at logical y=145.
  -- Crystal and other oversized walkers can extend below the original 160px
  -- canvas, so keep a compact overflow lane before the persistent help plaque.
  -- The physical organizer surface is rendered at the usual 2x scale.
  local FRLG_HELP_Y = 164
  local FRLG_ORGANIZER_H = 360
  local PC_ATLAS_REGIONS = {
    blue = { 241, 0, 240, 160 },
    orange = { 0, 0, 240, 160 },
    dataPanel = { 0, 328, 80, 160 },
    partyPanel = { 83, 328, 94, 160 },
    cursorHand = { 493, 5, 18, 20 },
    arrowLeft = { 539, 10, 8, 12 },
    arrowRight = { 550, 10, 8, 12 },
    closeBox = { 491, 92, 70, 15 },
    partyPokemon = { 491, 108, 70, 16 },
  }
  local wallpaperXs = { 1, 162, 323, 484 }
  local wallpaperYs = { 686, 832, 978, 1124 }
  local wallpaperNames = {
    { "FOREST", "WALD" }, { "CITY", "STADT" },
    { "DESERT", "WÜSTE" }, { "MEADOW", "WIESE" },
    { "TWILIGHT", "DÄMMERUNG" }, { "VOLCANO", "VULKAN" },
    { "SNOW", "SCHNEE" }, { "CAVERN", "HÖHLE" },
    { "COAST", "KÜSTE" }, { "NIGHT", "NACHT" },
    { "SKY", "HIMMEL" }, { "CLOUDS", "WOLKEN" },
  }
  local pcAtlasCache

  local function pcAtlas()
    if pcAtlasCache ~= nil then return pcAtlasCache or nil end
    if not readableAsset(PC_ATLAS_PATH) or not (love.graphics.newImage
        and love.graphics.newQuad and love.graphics.draw) then
      pcAtlasCache = false
      return nil
    end
    local loadPath = PC_ATLAS_PATH
    if mod.assets and type(mod.assets.path) == "function" then
      local ok, resolved = pcall(mod.assets.path, mod.assets, PC_ATLAS_PATH)
      if ok and type(resolved) == "string" and resolved ~= "" then
        loadPath = resolved
      end
    end
    local made, image = pcall(love.graphics.newImage, loadPath)
    if not made or not image then
      pcAtlasCache = false
      return nil
    end
    local okW, width = pcall(image.getWidth, image)
    local okH, height = pcall(image.getHeight, image)
    if not okW or not okH or width ~= PC_ATLAS_W or height ~= PC_ATLAS_H then
      pcAtlasCache = false
      return nil
    end
    if type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    pcAtlasCache = { image = image, quads = {}, loadPath = loadPath }
    return pcAtlasCache
  end

  local function drawAtlasRegion(key, spec, x, y, w, h)
    local atlas = pcAtlas()
    if not atlas then return false end
    local quad = atlas.quads[key]
    if not quad then
      local made, value = pcall(love.graphics.newQuad,
        spec[1], spec[2], spec[3], spec[4], PC_ATLAS_W, PC_ATLAS_H)
      if not made or not value then return false end
      quad = value
      atlas.quads[key] = quad
    end
    color(C.white)
    love.graphics.draw(atlas.image, quad, x, y, 0,
      w / spec[3], h / spec[4])
    return true
  end

  local function drawPcBackdrop(kind)
    local spec = PC_ATLAS_REGIONS[kind == "orange" and "orange" or "blue"]
    if drawAtlasRegion("backdrop:" .. kind, spec, 0, 0, 160, 144) then
      return
    end
    color(kind == "orange" and C.orange or C.blue3)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    color(kind == "orange" and C.gold or C.blue)
    for y = 0, 144, 8 do
      love.graphics.rectangle("fill", 0, y, 160, 2)
    end
  end

  -- The original organizer is 240x160. Rendering every piece and text field
  -- at an exact 2x keeps its geometry and glyph stems intact.
  local function drawOnGbaCanvas(callback)
    local transformed = love.graphics.push and love.graphics.pop
      and love.graphics.scale
    if transformed then
      love.graphics.push()
      love.graphics.scale(FRLG_UI_SCALE, FRLG_UI_SCALE)
    end
    callback()
    if transformed then love.graphics.pop() end
  end

  local function wallpaperIndex(boxNumber)
    return ((math.max(1, tonumber(boxNumber) or 1) - 1)
      % #wallpaperNames) + 1
  end

  local function wallpaperLabel(boxNumber)
    local pair = wallpaperNames[wallpaperIndex(boxNumber)]
    return pair[german() and 2 or 1]
  end

  local function drawWallpaper(boxNumber, x, y, w, h)
    local index = wallpaperIndex(boxNumber)
    local col = (index - 1) % 4 + 1
    local row = math.floor((index - 1) / 4) + 1
    local spec = { wallpaperXs[col], wallpaperYs[row], 156, 115 }
    if drawAtlasRegion("wallpaper:" .. index, spec, x, y, w, h) then
      return true
    end
    color(C.paper2)
    love.graphics.rectangle("fill", x, y, w, h)
    return false
  end


  local function drawWallpaperTab(boxNumber, x, y, w, h)
    local index = wallpaperIndex(boxNumber)
    local col = (index - 1) % 4 + 1
    local row = math.floor((index - 1) / 4) + 1
    local spec = { 17 + (col - 1) * 161,
      wallpaperYs[row] - 26, 124, 21 }
    return drawAtlasRegion("wallpaper-tab:" .. index, spec, x, y, w, h)
  end

  -- Fill the Box-tab interior from the same wallpaper that is currently in
  -- the grid. This keeps the authentic atlas frame but avoids laying a flat,
  -- invented green rectangle over every theme.
  local function drawWallpaperTitleFill(boxNumber, x, y, w, h)
    local index = wallpaperIndex(boxNumber)
    local col = (index - 1) % 4 + 1
    local row = math.floor((index - 1) / 4) + 1
    local spec = {
      wallpaperXs[col] + 20, wallpaperYs[row] + 12, w, h,
    }
    return drawAtlasRegion("wallpaper-title-fill:" .. index,
      spec, x, y, w, h)
  end

  local function pcInterfaceStyle(game)
    -- Preserve the old master switch for upgraded saves.  The new three-way
    -- control is otherwise independent: FIRERED is the 6.5.16 default, KASC
    -- retains Ascendant's previous blue/cream renderer, and DEFAULT yields to
    -- the engine-owned Gen-I PC without relabeling or navigation wrappers.
    if option(game, "modern_storage_ui") == false then return "default" end
    local selected = option(game, "pc_interface_style") or "oras_fullscreen"
    if selected == "oras_fullscreen" then return "firered_wide" end
    if selected == "default" then return "default" end
    if selected == "ascendant" then return "ascendant" end
    if selected == "firered_wide" then
      return pcAtlas() and "firered_wide" or "ascendant"
    end
    -- A damaged/missing atlas must never leave a half-rendered terminal.
    return pcAtlas() and "firered" or "ascendant"
  end

  local function useFireRedPc(game)
    local style = pcInterfaceStyle(game)
    return style == "firered" or style == "firered_wide"
  end

  local function useWideFireRedPc(game)
    return pcInterfaceStyle(game) == "firered_wide"
  end

  local function fullscreenCard(game)
    if (option(game, "pc_interface_style") or "oras_fullscreen") ~= "oras_fullscreen" then return nil end
    local card=mod.exports and mod.exports.fullscreenUiCard
    return card and card.active and not card.usesVasc(game) and card or nil
  end

  local function legacyBankInterfaceStyle(game)
    if option(game, "modern_storage_ui") == false then return "ascendant" end
    local selected = option(game, "legacy_bank_interface_style")
      or "follow_pc"
    if selected == "follow_pc" then return pcInterfaceStyle(game) end
    if selected == "firered_wide" then
      return pcAtlas() and "firered_wide" or "ascendant"
    end
    if selected == "firered" then
      return pcAtlas() and "firered" or "ascendant"
    end
    return "ascendant"
  end

  local function useFireRedLegacyBank(game)
    local style = legacyBankInterfaceStyle(game)
    return style == "firered" or style == "firered_wide"
  end

  local function useWideFireRedLegacyBank(game)
    return legacyBankInterfaceStyle(game) == "firered_wide"
  end

  local function useCustomPc(game)
    return pcInterfaceStyle(game) ~= "default"
  end

  local function fireRedUiSize()
    return FRLG_UI_W, FRLG_UI_H
  end

  local function fireRedOrganizerUiSize()
    return FRLG_UI_W, FRLG_ORGANIZER_H
  end

  local function fireRedWideUiSize()
    return FRLG_WIDE_W, FRLG_WIDE_H
  end

  local function fireRedOrganizerTrueColor()
    local PaletteFX = require("src.render.PaletteFX")
    return { PaletteFX.trueColorZone(
      0, 0, FRLG_UI_W / 8 - 1, FRLG_ORGANIZER_H / 8 - 1) }
  end

  local function fireRedTrueColor()
    local PaletteFX = require("src.render.PaletteFX")
    return { PaletteFX.trueColorZone(
      0, 0, FRLG_UI_W / 8 - 1, FRLG_UI_H / 8 - 1) }
  end


  local function fireRedWideTrueColor()
    local PaletteFX = require("src.render.PaletteFX")
    return { PaletteFX.trueColorZone(
      0, 0, FRLG_WIDE_W / 8 - 1, FRLG_WIDE_H / 8 - 1) }
  end

  -- Widescreen storage remembers presentation navigation only. The engine's
  -- current Box, party and archive remain the sole persisted data authority;
  -- this weak table cannot enter a save and disappears with the game object.
  local wideNavigationMemory = setmetatable({}, { __mode = "k" })

  local function wideMemory(game)
    local memory = wideNavigationMemory[game]
    if not memory then
      memory = { lists = {} }
      wideNavigationMemory[game] = memory
    end
    return memory
  end

  local pocketNames = {
    ITEMS = { "ITEMS", "ALLGEMEIN" },
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
  local function monIsShiny(mon)
    local shiny = mon and mon.shiny == true or false
    local authority = mod.exports and mod.exports.shinySystem
    if authority and type(authority.isShiny) == "function" then
      local ok, value = pcall(authority.isShiny, mon)
      if ok then shiny = value == true end
    end
    return shiny
  end
  local function monSprite(game, mon)
    if not (mon and mon.species and love.graphics.newImage) then return nil end
    local shiny = monIsShiny(mon)
    local key = table.concat({
      mon.species,
      shiny and "s" or "n",
      tostring(mod.options:get("pokemon_sprite_style")),
      tostring(mod.options:get("sprite_style_box")),
    }, ":")
    if spriteCache[key] ~= nil then
      return spriteCache[key] or nil
    end
    local ok, path = pcall(require("src.pokemon.Sprites").path,
      game.data, mon.species, "front", {
        kind = "box", mon = mon, shiny = shiny,
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

  local transparentHandCache

  -- Keep the exact FRLG hand silhouette, but chroma-key the atlas sheet
  -- colour at load time. The crop's top-left pixel is the uniform pale-blue
  -- background; near-identical edge pixels become transparent while every
  -- glove/outline pixel is copied unchanged to a tiny cached ImageData.
  local function transparentHand()
    if transparentHandCache ~= nil then return transparentHandCache or nil end
    local atlas = pcAtlas()
    if not (atlas and atlas.loadPath and love.image
        and love.image.newImageData and love.graphics.newImage) then
      transparentHandCache = false
      return nil
    end
    local okSource, source = pcall(love.image.newImageData, atlas.loadPath)
    local okTarget, target = pcall(love.image.newImageData, 18, 20)
    if not okSource or not source or not okTarget or not target then
      transparentHandCache = false
      return nil
    end
    local sx, sy = PC_ATLAS_REGIONS.cursorHand[1],
      PC_ATLAS_REGIONS.cursorHand[2]
    local bgR, bgG, bgB = source:getPixel(sx, sy)
    local copied = pcall(function()
      for py = 0, 19 do
        for px = 0, 17 do
          local r, green, b, a = source:getPixel(sx + px, sy + py)
          local distance = math.abs(r - bgR) + math.abs(green - bgG)
            + math.abs(b - bgB)
          target:setPixel(px, py, r, green, b, distance < .10 and 0 or a)
        end
      end
    end)
    if not copied then
      transparentHandCache = false
      return nil
    end
    local made, image = pcall(love.graphics.newImage, target)
    if not made or not image then
      transparentHandCache = false
      return nil
    end
    if type(image.setFilter) == "function" then
      pcall(image.setFilter, image, "nearest", "nearest")
    end
    transparentHandCache = image
    return image
  end

  -- When MOVE is carrying a mon, the cursor owns a small sprite just above
  -- its fingertip. The polygon is a headless/old-LÖVE fallback only.
  local function drawPixelHand(x, y, game, carriedMon)
    if carriedMon then
      drawMonImage(game, carriedMon, x - 5, y - 13, 20, 20)
    end
    local hand = transparentHand()
    if hand then
      color(C.white)
      love.graphics.draw(hand, x, y)
      return
    end
    local points = {
      x + 2, y + 7, x + 2, y + 2, x + 5, y + 2,
      x + 5, y, x + 8, y, x + 8, y + 2,
      x + 11, y + 2, x + 11, y + 5, x + 14, y + 5,
      x + 14, y + 9, x + 11, y + 9, x + 11, y + 13,
      x + 5, y + 13, x + 5, y + 10,
    }
    color(C.white)
    love.graphics.polygon("fill", unpack(points))
    color(C.ink)
    love.graphics.polygon("line", unpack(points))
    love.graphics.rectangle("fill", x, y + 6, 5, 2)
    love.graphics.rectangle("fill", x + 5, y + 3, 2, 5)
    color(C.white)
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
    local variant = monIsShiny(mon) and "shiny" or "normal"
    return ("%s/%03d-%s.png"):format(BOX_GRID_SHEET_ROOT, dex, variant),
      variant, dex, identity
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

  local function drawAscendantBoxGrid(menu, game)
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

  local function isPartyGrid(title)
    title = tostring(title or "")
    return title:find("PARTY", 1, true) ~= nil
      or title:find("TEAM", 1, true) ~= nil
  end

  local function drawFireRedData(mon, game)
    drawAtlasRegion("data-panel", PC_ATLAS_REGIONS.dataPanel,
      0, 0, 80, 160)
    if not mon then return end

    drawMonImage(game, mon, 7, 18, 66, 72)
  end

  -- Text stays at the original GBA coordinates and receives only the exact
  -- 2x surface scale. Never squeeze a glyph horizontally: a long field is
  -- truncated or wrapped, but every visible stem keeps an integer width.
  local function drawFittedFireRedText(text, x, y, budget)
    text = tostring(text or "")
    Font.draw(truncate(text, budget), x, y)
  end

  local function drawFireRedDataText(mon, game)
    if not mon then return end
    local def = game.data.pokemon[mon.species] or {}
    local nickname = mon.nickname or def.name or mon.species
    local species = def.name or mon.species
    color(C.ink)
    drawFittedFireRedText(nickname, 6, 99, 68)
    if species ~= nickname then
      drawFittedFireRedText("/" .. species, 6, 110, 68)
    end
    local symbol = storageGenderSymbol(game, mon)
    if symbol then Font.draw(symbol, 6, 123) end
    drawFittedFireRedText(Strings("Lv%d", mon.level or 0), 24, 123, 48)
  end

  local function drawFireRedBoxHeading(game, boxNumber, prefix)
    boxNumber = boxNumber or game.save.currentBox or 1
    local heading = prefix
      and Strings(prefix .. " %03d", boxNumber)
      or Strings("BOX %02d", boxNumber)
    local headingX = 157 - math.floor(Font.width(heading) / 2)
    drawWallpaperTitleFill(boxNumber, 100, 26, 114, 14)
    color(C.ink)
    Font.draw(heading, headingX, 29)
  end

  local function drawFireRedTopButtons(party)
    drawAtlasRegion("party-button", PC_ATLAS_REGIONS.partyPokemon,
      82, 1, 76, 20)
    drawAtlasRegion("close-button", PC_ATLAS_REGIONS.closeBox,
      170, 1, 69, 20)
    if party then
      -- The selected green PARTY POKéMON artwork is already sampled above.
      -- A small hand on the button is the original FRLG focus language.
      drawPixelHand(79, 2, nil, nil)
    end
  end

  local function drawFireRedBoxShell(game, mon, slide, boxNumber)
    drawAtlasRegion("organizer-backdrop", PC_ATLAS_REGIONS.orange,
      0, 0, 240, 160)
    drawFireRedData(mon, game)
    drawFireRedTopButtons(false)

    local shifted = love.graphics.push and love.graphics.pop
      and love.graphics.translate and tonumber(slide) and slide ~= 0
    if shifted then
      love.graphics.push()
      love.graphics.translate(slide, 0)
    end
    boxNumber = boxNumber or game.save.currentBox or 1
    drawWallpaper(boxNumber, 84, 43, 156, 117)
    drawWallpaperTab(boxNumber, 95, 23, 124, 21)
    drawAtlasRegion("box-arrow-left", PC_ATLAS_REGIONS.arrowLeft,
      81, 27, 10, 14)
    drawAtlasRegion("box-arrow-right", PC_ATLAS_REGIONS.arrowRight,
      228, 27, 10, 14)
    if shifted then love.graphics.pop() end
  end

  local function fireRedSlotCenter(slot)
    local col = (slot - 1) % 5
    local row = math.floor((slot - 1) / 5)
    return 102 + col * 31, 58 + row * 29
  end

  local function drawFireRedBoxMons(menu, game, showCursor, slide, hiddenSlot)
    local shifted = love.graphics.push and love.graphics.pop
      and love.graphics.translate and tonumber(slide) and slide ~= 0
    if shifted then
      love.graphics.push()
      love.graphics.translate(slide, 0)
    end
    local cursorX, cursorY
    for index, item in ipairs(menu.items or {}) do
      local slot = math.max(1, math.min(20, tonumber(item.value) or index))
      local x, y = fireRedSlotCenter(slot)
      local slotMon = boxMonForItem(game, item, menu.title or "")
      if slotMon and slot ~= hiddenSlot then
        if not drawBoxGridWalker(game, slotMon, x, y) then
          drawMonImage(game, slotMon, x - 10, y - 10, 20, 20)
        end
      end
      if showCursor and index == menu.index then
        cursorX, cursorY = x, y
      end
    end
    if cursorX then
      drawPixelHand(cursorX - 8, cursorY - 13, game, nil)
    end
    if shifted then love.graphics.pop() end
  end

  local function drawFireRedParty(menu, game, mon)
    drawAtlasRegion("organizer-backdrop", PC_ATLAS_REGIONS.orange,
      0, 0, 240, 160)
    drawFireRedData(mon, game)
    drawAtlasRegion("party-panel", PC_ATLAS_REGIONS.partyPanel,
      80, 21, 160, 139)
    drawFireRedTopButtons(true)

    -- The sheet's party rail contains five slots: the currently inspected
    -- Pokémon lives in PKMN DATA, and the remaining party members occupy it.
    local positions = {
      { 116, 91 }, { 181, 45 }, { 181, 73 },
      { 181, 101 }, { 181, 129 },
    }
    local out = 1
    for index, item in ipairs(menu.items or {}) do
      if index ~= menu.index and positions[out] then
        local slotMon = boxMonForItem(game, item, menu.title or "")
        local p = positions[out]
        if slotMon then drawMonImage(game, slotMon, p[1] - 13, p[2] - 13, 26, 26) end
        out = out + 1
      end
    end
  end

  local function drawFireRedBoxGrid(menu, game)
    local party = isPartyGrid(menu.title)
    local chosen = menu.items[menu.index]
    local mon = boxMonForItem(game, chosen, menu.title or "")
    drawOnGbaCanvas(function()
      if party then
        drawFireRedParty(menu, game, mon)
      else
        drawFireRedBoxShell(game, mon)
        drawFireRedBoxMons(menu, game, true)
        drawFireRedBoxHeading(game)
      end
      drawFireRedDataText(mon, game)
    end)
    color(C.white)
  end

  -- The WIDE presentation is composed directly for a 512x288 surface. It
  -- reuses the authentic FRLG wallpaper/button artwork as independent pieces,
  -- but never scales the old 240x160 screen as a whole. This leaves permanent
  -- room for a readable detail card and a full-width help line.
  local function drawFireRedWideFrame(title)
    color(C.blue3)
    love.graphics.rectangle("fill", 0, 0, FRLG_WIDE_W, FRLG_WIDE_H)
    color(C.blue2)
    love.graphics.rectangle("fill", 0, 0, FRLG_WIDE_W, 36)
    color(C.orange)
    love.graphics.rectangle("fill", 0, 32, FRLG_WIDE_W, 4)
    color(C.white)
    drawFittedFireRedText(title, 14, 11, 300)
  end

  local function fireRedWideSlotCenter(slot)
    local col = (slot - 1) % 5
    local row = math.floor((slot - 1) / 5)
    return 45 + col * 65, 71 + row * 43
  end

  local function drawFireRedWideDetail(game, mon, slotLabel)
    panel(349, 44, 153, 197, C.cream, C.blue3)
    color(C.paper2)
    love.graphics.rectangle("fill", 356, 51, 139, 104)
    if mon then
      drawMonImage(game, mon, 367, 54, 117, 98)
      local def = game.data.pokemon[mon.species] or {}
      local nickname = mon.nickname or def.name or mon.species
      local species = def.name or mon.species
      color(C.ink)
      drawFittedFireRedText(nickname, 357, 162, 137)
      if species ~= nickname then
        drawFittedFireRedText("/" .. species, 357, 175, 137)
      end
      drawFittedFireRedText(Strings("Lv.%d", mon.level or 0),
        357, 192, 62)
      local symbol = storageGenderSymbol(game, mon)
      if symbol then Font.draw(symbol, 430, 192) end
      if slotLabel then
        drawFittedFireRedText(slotLabel, 357, 215, 137)
      end
    else
      color(C.ink)
      Font.draw(tr("EMPTY SLOT", "LEERER PLATZ"), 373, 98)
      if slotLabel then drawFittedFireRedText(slotLabel, 357, 215, 137) end
    end
  end

  local function drawFireRedWideFooter(text, right)
    panel(10, 248, 492, 30, C.cream, C.blue3)
    color(C.ink)
    drawFittedFireRedText(text or tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR"),
      20, 259, right and 390 or 470)
    if right then
      Font.draw(right, 490 - Font.width(right), 259)
    end
  end

  local function drawFireRedWideWallpaper(boxNumber, x, y, w, h, scale,
      screenOffsetX)
    local g = love.graphics
    if type(g.setScissor) == "function" and type(g.getScissor) == "function" then
      local oldX, oldY, oldW, oldH = g.getScissor()
      -- Scissors are screen-space in LÖVE and therefore do not inherit the
      -- transform used by Box slides and Box<->Party transitions. Resolve the
      -- active transform when available; old LÖVE/test harnesses use the
      -- explicit page-slide offset as a conservative fallback.
      local clipX, clipY, clipW, clipH =
        x + (tonumber(screenOffsetX) or 0), y, w, h
      if type(g.transformPoint) == "function" then
        local okA, ax, ay = pcall(g.transformPoint, x, y)
        local okB, bx, by = pcall(g.transformPoint, x + w, y + h)
        if okA and okB and tonumber(ax) and tonumber(ay)
            and tonumber(bx) and tonumber(by) then
          clipX, clipY = math.min(ax, bx), math.min(ay, by)
          clipW, clipH = math.abs(bx - ax), math.abs(by - ay)
        end
      end
      g.setScissor(clipX, clipY, clipW, clipH)
      -- The authentic wallpaper crop is 156x115. Keep its pixels square at an
      -- integer scale, centre it, and crop overflow instead of stretching it
      -- by unrelated horizontal/vertical factors.
      scale = math.max(1, math.floor(tonumber(scale) or 2))
      local scaledW, scaledH = 156 * scale, 115 * scale
      local ok, drawErr = pcall(drawWallpaper, boxNumber,
        x + math.floor((w - scaledW) / 2),
        y + math.floor((h - scaledH) / 2), scaledW, scaledH)
      if oldX ~= nil then g.setScissor(oldX, oldY, oldW, oldH)
      else g.setScissor() end
      if not ok then error(drawErr, 0) end
      return
    end
    drawWallpaper(boxNumber, x, y, w, h)
  end

  local function drawFireRedWideBoxBase(game, boxNumber, heading, slide)
    -- The Box tab, its two cartridge arrows and the PARTY/CLOSE atlas
    -- buttons already own most of this 36px rail.  A second long POKéMON
    -- STORAGE title used to run under the left arrow and was then partly
    -- painted over by the Box tab.  Keep a complete, readable section label
    -- in the only independent 70px lane instead of rendering clipped text.
    drawFireRedWideFrame(tr("STORAGE", "LAGER"))
    boxNumber = boxNumber or game.save.currentBox or 1
    local shifted = love.graphics.push and love.graphics.pop
      and love.graphics.translate and tonumber(slide) and slide ~= 0
    if shifted then
      love.graphics.push()
      love.graphics.translate(slide, 0)
    end
    panel(10, 44, 332, 197, C.paper, C.blue3)
    drawFireRedWideWallpaper(boxNumber, 14, 48, 324, 189, 2,
      shifted and slide or 0)
    if shifted then love.graphics.pop() end
    local title = heading or Strings("BOX %02d", boxNumber)
    panel(112, 6, 174, 25, C.cream, C.blue3)
    color(C.ink)
    Font.draw(title, 199 - math.floor(Font.width(title) / 2), 14)
    drawAtlasRegion("wide-arrow-left", PC_ATLAS_REGIONS.arrowLeft,
      92, 10, 8, 12)
    drawAtlasRegion("wide-arrow-right", PC_ATLAS_REGIONS.arrowRight,
      296, 10, 8, 12)
    drawAtlasRegion("wide-party-button", PC_ATLAS_REGIONS.partyPokemon,
      336, 9, 70, 16)
    drawAtlasRegion("wide-close-button", PC_ATLAS_REGIONS.closeBox,
      428, 9, 70, 15)
  end

  local function drawFireRedWideBoxSlots(game, box, selectedSlot, opts)
    opts = opts or {}
    local shifted = love.graphics.push and love.graphics.pop
      and love.graphics.translate and tonumber(opts.slide)
      and opts.slide ~= 0
    if shifted then
      love.graphics.push()
      love.graphics.translate(opts.slide, 0)
    end
    for slot = 1, 20 do
      local x, y = fireRedWideSlotCenter(slot)
      color({ C.cream[1], C.cream[2], C.cream[3], .76 })
      love.graphics.rectangle("fill", x - 27, y - 17, 54, 35)
      local mon = box and box[slot]
      local hidden = opts.hiddenSlot == slot
      if mon and not hidden then
        if not drawBoxGridWalker(game, mon, x, y) then
          drawMonImage(game, mon, x - 18, y - 17, 36, 34)
        end
      end
      if slot == selectedSlot then
        color(C.gold)
        love.graphics.rectangle("line", x - 29.5, y - 19.5, 59, 40)
      end
      if opts.decorate then opts.decorate(slot, mon, x, y) end
    end
    if opts.showCursor and selectedSlot then
      local x, y = fireRedWideSlotCenter(selectedSlot)
      drawPixelHand(x - 9, y - 18, game, opts.carriedMon)
    end
    if shifted then love.graphics.pop() end
  end

  local function drawFireRedWidePartyList(game, party, selected,
      hiddenSlot, carriedMon, showCursor)
    drawFireRedWideFrame(tr("PARTY POKéMON", "TEAM-POKéMON"))
    panel(10, 44, 332, 197, C.paper, C.blue3)
    for slot = 1, 6 do
      local col = (slot - 1) % 2
      local row = math.floor((slot - 1) / 2)
      local x, y = 17 + col * 161, 51 + row * 61
      panel(x, y, 154, 53, slot == selected and C.paper2 or C.cream,
        slot == selected and C.orange or C.blue3)
      local mon = party and party[slot]
      if mon and slot ~= hiddenSlot then
        drawMonImage(game, mon, x + 5, y + 4, 45, 44)
        local def = game.data.pokemon[mon.species] or {}
        color(C.ink)
        drawFittedFireRedText(mon.nickname or def.name or mon.species,
          x + 55, y + 10, 91)
        drawFittedFireRedText(Strings("Lv.%d", mon.level or 0),
          x + 55, y + 29, 58)
      else
        color(C.ink)
        Font.draw("-", x + 76, y + 22)
      end
      if showCursor and slot == selected then
        drawPixelHand(x - 5, y + 15, game, carriedMon)
      end
    end
    drawFireRedWideDetail(game, party and party[selected],
      Strings(tr("PARTY SLOT %d", "TEAM-PLATZ %d"), selected or 1))
  end

  local function drawFireRedWideBoxGrid(menu, game)
    local party = isPartyGrid(menu.title)
    local selectedItem = menu.items[menu.index]
    local selectedSlot = selectedItem
      and math.max(1, math.min(20, tonumber(selectedItem.value) or menu.index))
      or 1
    local card=fullscreenCard(game)
    if card and card.drawStorage({game=game},party,selectedSlot,selectedSlot,nil,false,
        tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR")) then return end
    if party then
      local partyIndex = selectedItem
        and math.max(1, math.min(6, tonumber(selectedItem.value) or menu.index))
        or 1
      local partyMons = game.save.party or {}
      drawFireRedWidePartyList(game, partyMons, partyIndex, nil, nil, true)
      drawFireRedWideFooter(tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR"),
        Strings("%d/6", #partyMons))
    else
      local box = Boxes.active(game.save) or {}
      drawFireRedWideBoxBase(game)
      drawFireRedWideBoxSlots(game, box, selectedSlot, { showCursor = true })
      drawFireRedWideDetail(game, box[selectedSlot],
        Strings(tr("BOX SLOT %02d", "BOX-PLATZ %02d"), selectedSlot))
      drawFireRedWideFooter(tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR"),
        Strings("%02d/20", #box))
    end
    color(C.white)
  end

  local function drawBoxGrid(menu, game)
    if useWideFireRedPc(game) then
      return drawFireRedWideBoxGrid(menu, game)
    elseif useFireRedPc(game) then
      return drawFireRedBoxGrid(menu, game)
    end
    return drawAscendantBoxGrid(menu, game)
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

  local function isChangeBoxList(title)
    title = tostring(title or "")
    return title:find("CHANGE BOX", 1, true) ~= nil
      or title:find("BOX WECH", 1, true) ~= nil
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
    elseif label:find("MOVE", 1, true) or label:find("BEWEG", 1, true) then
      return tr("MOVE", "BEWEGEN")
    elseif label:find("PRINT", 1, true) or label:find("DRUCK", 1, true) then
      return tr("PRINT BOX", "BOX DRUCK.")
    elseif label:find("SEE", 1, true) or label:find("TSCH", 1, true) then
      return tr("EXIT", "ENDE")
    end
    return truncate(label, 72)
  end

  local function compactPcLabel(label)
    label = tostring(label or "")
    if label:find("WITHDRAW ITEM", 1, true)
        or label:find("ITEM NEHMEN", 1, true) then
      return tr("GET ITEM", "ITEM NEHM.")
    elseif label:find("DEPOSIT ITEM", 1, true)
        or label:find("ITEM ABLEGEN", 1, true) then
      return tr("STORE", "ABLEGEN")
    elseif label:find("TOSS ITEM", 1, true)
        or label:find("ITEM WEGWERFEN", 1, true) then
      return tr("TOSS", "WEGWERF.")
    elseif label:find("PROF.OAK", 1, true) then
      return "OAK PC"
    elseif label:find("LOG OFF", 1, true)
        or label:find("SEE YA", 1, true) then
      return tr("LOG OFF", "ENDE")
    end
    return label:gsub("'s PC", " PC")
  end

  local function drawFireRedActionRows(items, selected, labeler, startY, step)
    color(C.ink)
    for index, item in ipairs(items or {}) do
      local y = startY + (index - 1) * step
      drawFittedFireRedText(labeler(item.label), 10, y, 64)
      if index == selected then Font.drawCode(Theme.cursor, 2, y) end
    end
  end

  local function localizedBoxTitle(title)
    title = tostring(title or "")
    if not german() then return title end
    return title:gsub("PARTY", "TEAM")
      :gsub("DEPOSIT", "ABLEGEN")
      :gsub("WITHDRAW", "NEHMEN")
      :gsub("RELEASE", "FREILASSEN")
  end

  local function isPcItemList(title)
    if type(title) ~= "string" then return false end
    return title:find("WITHDRAW ITEM", 1, true)
      or title:find("DEPOSIT ITEM", 1, true)
      or title:find("TOSS ITEM", 1, true)
      or title:find("ITEM NEHMEN", 1, true)
      or title:find("ITEM ABLEGEN", 1, true)
      or title:find("ITEM WEGWERFEN", 1, true)
  end

  local function localizedPcItemTitle(title)
    title = tostring(title or "")
    if not german() then return title end
    return title:gsub("WITHDRAW ITEM", "ITEM NEHMEN")
      :gsub("DEPOSIT ITEM", "ITEM ABLEGEN")
      :gsub("TOSS ITEM", "ITEM WEGWERFEN")
  end

  local function drawFireRedItemList(menu, game)
    drawPcBackdrop("orange")
    color(C.blue3)
    love.graphics.rectangle("fill", 0, 0, 160, 18)
    color(C.gold)
    love.graphics.rectangle("fill", 0, 16, 160, 2)
    color(C.white)
    Font.draw(localizedPcItemTitle(menu.title), 5, 5)

    panel(5, 21, 150, 86, C.cream, C.blue3)
    if #menu.items == 0 then
      color(C.ink)
      Font.draw(tr("No items stored.", "Keine Items gelagert."), 16, 57)
    end
    for row = 1, 4 do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 27 + (row - 1) * 19
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 8, y - 3, 144, 15)
      end
      color(C.ink)
      Font.draw(truncate(item.label or "", 105), 20, y)
      if item.right then
        Font.draw(item.right, 148 - Font.width(item.right), y)
      end
      if index == menu.index then Font.drawCode(Theme.cursor, 10, y) end
    end

    panel(5, 110, 150, 31, C.cream, C.blue3)
    color(C.ink)
    if menu.footer then
      local lines = tostring(menu.footer):gsub("\n", " ")
      Font.draw(truncate(lines, 134), 11, 116)
    else
      Font.draw(tr("A:SELECT", "A:WAHL"), 11, 116)
    end
    Font.draw(tr("B:BACK", "B:ZUR"), 11, 128)
    color(C.white)
  end

  local function drawFireRedWideItemList(menu, game)
    drawFireRedWideFrame(localizedPcItemTitle(menu.title))
    panel(10, 44, 332, 197, C.cream, C.blue3)
    local rows = 10
    if #menu.items == 0 then
      color(C.ink)
      Font.draw(tr("No items stored.", "Keine Items gelagert."), 91, 136)
    end
    for row = 1, rows do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 51 + (row - 1) * 18
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 16, y - 3, 320, 15)
      end
      color(C.ink)
      drawFittedFireRedText(item.label or "", 31, y, 238)
      if item.right then
        Font.draw(item.right, 329 - Font.width(item.right), y)
      end
      if index == menu.index then Font.drawCode(Theme.cursor, 19, y) end
    end
    panel(349, 44, 153, 197, C.paper, C.blue3)
    local selected = menu.items[menu.index]
    color(C.blue)
    love.graphics.rectangle("fill", 356, 51, 139, 25)
    color(C.white)
    Font.draw(tr("ITEM DATA", "ITEM-DATEN"), 366, 60)
    color(C.ink)
    if selected then
      drawWrapped(selected.label or selected.value or "", 357, 88, 137)
      if selected.right then
        drawFittedFireRedText(selected.right, 357, 130, 137)
      end
    else
      Font.draw(tr("EMPTY", "LEER"), 397, 105)
    end
    if menu.footer then
      local footer = tostring(menu.footer):gsub("\n", " ")
      drawWrapped(footer, 357, 169, 137)
    end
    drawFireRedWideFooter(tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR"),
      Strings("%d", #menu.items))
    color(C.white)
  end

  local function drawFireRedWideChangeBoxList(menu, game)
    drawFireRedWideFrame(tr("CHANGE BOX", "BOX WECHSELN"))
    panel(10, 44, 332, 197, C.cream, C.blue3)
    local rows = 10
    for row = 1, rows do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 51 + (row - 1) * 18
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 16, y - 3, 320, 15)
      end
      color(C.ink)
      drawFittedFireRedText(item.label or "", 31, y, 238)
      if item.right then Font.draw(item.right, 329 - Font.width(item.right), y) end
      if index == menu.index then Font.drawCode(Theme.cursor, 19, y) end
    end
    local selected = menu.items[menu.index]
    local boxNumber = selected and math.max(1,
      math.floor(tonumber(selected.value) or game.save.currentBox or 1))
      or game.save.currentBox or 1
    panel(349, 44, 153, 197, C.paper, C.blue3)
    drawFireRedWideWallpaper(boxNumber, 356, 51, 139, 104, 1)
    color(C.ink)
    drawFittedFireRedText(selected and selected.label
      or Strings("BOX %02d", boxNumber), 357, 164, 137)
    if selected and selected.right then
      drawFittedFireRedText(selected.right, 357, 184, 137)
    end
    drawFittedFireRedText(boxNumber == (game.save.currentBox or 1)
      and tr("CURRENT BOX", "AKTUELLE BOX")
      or tr("A:SELECT BOX", "A:BOX WÄHLEN"), 357, 214, 137)
    drawFireRedWideFooter(
      tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR"),
      Strings("%02d/%02d", menu.index or 1, #(menu.items or {})))
    color(C.white)
  end

  local function isPcTerminalRoot(items)
    if type(items) ~= "table" or #items ~= 4 then return false end
    local withPc = 0
    for _, item in ipairs(items) do
      if type(item.label) == "string" and item.label:find("PC", 1, true) then
        withPc = withPc + 1
      end
    end
    return withPc >= 3
  end

  local function isPlayerPcRoot(items)
    if type(items) ~= "table" or #items ~= 4 then return false end
    local text = {}
    for _, item in ipairs(items) do
      text[#text + 1] = tostring(item.label or "")
    end
    text = table.concat(text, " ")
    return (text:find("WITHDRAW ITEM", 1, true)
        or text:find("ITEM NEHMEN", 1, true))
      and (text:find("DEPOSIT ITEM", 1, true)
        or text:find("ITEM ABLEGEN", 1, true))
  end

  local function drawFireRedPcMenu(menu, game, playerPc)
    drawOnGbaCanvas(function()
      drawFireRedBoxShell(game, nil)
      local box = Boxes.active(game.save) or {}
      local previewItems = {}
      for slot = 1, 20 do
        if box[slot] then previewItems[#previewItems + 1] = { value = slot } end
      end
      drawFireRedBoxMons({ items = previewItems, title = "" }, game, false)
      drawFireRedBoxHeading(game)
      drawFireRedActionRows(menu.items, menu.index, compactPcLabel, 91, 11)
    end)
    color(C.white)
  end

  local function drawFireRedWidePcMenu(menu, game, playerPc)
    local box = Boxes.active(game.save) or {}
    drawFireRedWideBoxBase(game, nil,
      playerPc and tr("ITEM STORAGE", "ITEM-LAGER") or nil)
    drawFireRedWideBoxSlots(game, box, nil)
    panel(349, 44, 153, 197, C.cream, C.blue3)
    color(C.blue)
    love.graphics.rectangle("fill", 356, 51, 139, 25)
    color(C.white)
    Font.draw(playerPc and tr("PLAYER PC", "SPIELER-PC")
      or tr("PC MENU", "PC-MENÜ"), 365, 60)
    local itemCount = #(menu.items or {})
    -- Yellow adds PRINT BOX, and KASC appends MOVE POKéMON. Fit all seven
    -- rows above the fixed help footer without changing Red/Blue spacing.
    local rowStep = itemCount > 1
      and math.min(28, math.floor((226 - 88) / (itemCount - 1))) or 28
    for index, item in ipairs(menu.items or {}) do
      local y = 88 + (index - 1) * rowStep
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 356, y - 4, 139, 18)
      end
      color(C.ink)
      drawFittedFireRedText(compactPcLabel(item.label), 374, y, 112)
      if index == menu.index then Font.drawCode(Theme.cursor, 360, y) end
    end
    local selected = menu.items and menu.items[menu.index]
    drawFireRedWideFooter(selected
      and compactPcLabel(selected.label)
      or tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR"),
      Strings("%02d/20", #box))
    color(C.white)
  end

  -- The Legacy Bank action hub is a storage owner in its own right.  The
  -- organizer was already a native 512x288 surface, but J.openBank used to put
  -- a compact 160x144 ListMenu in front of it.  Compose the hub from the same
  -- FRLG pieces as the organizer so entering the Bank never changes aspect
  -- ratio before WITHDRAW/DEPOSIT is chosen.
  local function refreshLegacyRootRows(menu)
    local provider = menu and menu.__ascendantLegacyRootRows
    if type(provider) ~= "function" then
      menu.__ascendantLegacyRootRowsSnapshot = {}
      menu.__ascendantLegacyRootRowsError = nil
      return menu.__ascendantLegacyRootRowsSnapshot
    end
    local ok, rows, err = pcall(provider)
    if not ok or type(rows) ~= "table" then
      menu.__ascendantLegacyRootRowsSnapshot =
        menu.__ascendantLegacyRootRowsSnapshot or {}
      menu.__ascendantLegacyRootRowsError = tostring(err or rows)
      return nil, menu.__ascendantLegacyRootRowsError
    end
    menu.__ascendantLegacyRootRowsSnapshot = rows
    menu.__ascendantLegacyRootRowsError = nil
    return rows
  end

  local function legacyRootRows(menu)
    local rows = menu and menu.__ascendantLegacyRootRowsSnapshot
    return type(rows) == "table" and rows or {}
  end

  local function drawFireRedWideLegacyRoot(menu, game)
    local rows = legacyRootRows(menu)
    local preview, previewRows = {}, {}
    for index, row in ipairs(rows) do
      local slot = math.max(1, math.floor(tonumber(row and row.bankSlot)
        or index))
      if slot <= 20 and preview[slot] == nil then
        preview[slot] = row and row.mon or nil
        previewRows[slot] = row
      end
    end

    drawFireRedWideBoxBase(game, 1, tr("LEGACY BANK", "VERMÄCHTNIS-BANK"))
    drawFireRedWideBoxSlots(game, preview, nil, {
      decorate = function(slot, _, x, y)
        local row = previewRows[slot]
        if row and row.withdrawBlocked then
          color(C.red)
          love.graphics.rectangle("fill", x + 19, y - 17, 12, 12)
          color(C.white)
          Font.draw("X", x + 21, y - 15)
        end
      end,
    })

    panel(349, 44, 153, 197, C.cream, C.blue3)
    color(C.blue)
    love.graphics.rectangle("fill", 356, 51, 139, 25)
    color(C.white)
    drawFittedFireRedText(tr("BANK ACTIONS", "BANK-AKTIONEN"),
      365, 60, 122)
    local count = #(menu.items or {})
    local step = count > 1
      and math.min(36, math.floor((211 - 88) / (count - 1))) or 36
    for index, item in ipairs(menu.items or {}) do
      local y = 88 + (index - 1) * step
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 356, y - 4, 139, 20)
      end
      color(C.ink)
      local right = item and item.right
      drawFittedFireRedText(actionLabel(item and item.label), 374, y,
        right ~= nil and 78 or 112)
      if right ~= nil then
        local text = tostring(right)
        Font.draw(text, 488 - Font.width(text), y)
      end
      if index == menu.index then Font.drawCode(Theme.cursor, 360, y) end
    end
    local selected = menu.items and menu.items[menu.index]
    drawFireRedWideFooter(selected and actionLabel(selected.label)
      or tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR"),
      Strings(tr("%d POKéMON", "%d POKéMON"), #rows))
    color(C.white)
  end

  local function newLegacyBankRoot(game, title, items, opts)
    if not useWideFireRedLegacyBank(game) then
      return nil, "wide-legacy-bank-not-selected"
    end
    -- useWideFireRedLegacyBank already probes the atlas, but keep the factory
    -- fail-closed if a hot reload invalidates it between option resolution and
    -- construction.
    if not pcAtlas() then return nil, "frlg-atlas-unavailable" end
    local factory = mod.ui
      and (mod.ui.KantoListMenu or mod.ui.ListMenu) or nil
    if not (factory and type(factory.new) == "function") then
      local ok, ListMenu = pcall(require, "src.ui.ListMenu")
      if ok then factory = ListMenu end
    end
    if not (factory and type(factory.new) == "function") then
      return nil, "legacy-root-list-unavailable"
    end
    opts = opts or {}
    local made, menu = pcall(factory.new, game, title, items, opts)
    if not made or type(menu) ~= "table" then
      return nil, made and "legacy-root-invalid" or tostring(menu)
    end
    menu.__ascendantFireRedWideLegacyRoot = true
    menu.__ascendantLegacyRootRows = opts.legacyRows
    menu.refreshLegacyRows = refreshLegacyRootRows
    menu:refreshLegacyRows()
    menu.isOpaque = true
    menu.letterboxWhite = true
    menu.uiSize = fireRedWideUiSize
    menu.sgbPalettes = fireRedWideTrueColor
    menu.drawsWidescreen = function() return true end
    menu.wantsFillScale = function() return false end
    local memory = wideMemory(game)
    if memory.legacyRootIndex and #(menu.items or {}) > 0 then
      menu.index = math.max(1, math.min(#menu.items, memory.legacyRootIndex))
    end
    local update = menu.update
    if type(update) == "function" then
      menu.update = function(self, dt)
        local result = update(self, dt)
        wideMemory(self.game).legacyRootIndex = self.index
        return result
      end
    end
    menu.draw = function(self)
      return drawFireRedWideLegacyRoot(self, game)
    end
    return menu
  end

  -- FireRed's organizer is a single live surface, not three disconnected
  -- cartridge-era menus. It exposes the current Box, the party rail and a
  -- pick-up/drop move operation while leaving the engine's actual party and
  -- Boxes tables as the only storage authority.
  local function organizerItems(list)
    local items = {}
    for index = 1, #(list or {}) do items[index] = { value = index } end
    return items
  end

  local function organizerList(state, zone)
    if zone == "party" then return state.game.save.party or {} end
    return Boxes.active(state.game.save) or {}
  end

  local function organizerSelectedMon(state)
    local zone = state.zone == "party" and "party" or "box"
    local list = organizerList(state, zone)
    local index = zone == "party" and state.partyIndex or state.boxIndex
    return list[index]
  end

  local function organizerMessage(state, en, de)
    state.message = tr(en, de)
    state.messageTime = 1.8
  end

  local function drawOrganizerHelp(state)
    color(C.cream)
    love.graphics.rectangle("fill", 82, FRLG_HELP_Y, 158, 16)
    color(C.blue3)
    love.graphics.rectangle("line", 82.5, FRLG_HELP_Y + 0.5, 157, 15)
    local text = state.message
    if not text and state.carry then
      local def = state.game.data.pokemon[state.carry.mon.species] or {}
      text = tr("MOVE: ", "BEWEGT: ")
        .. (state.carry.mon.nickname or def.name or state.carry.mon.species)
    end
    text = text or (state.zone == "party"
      and tr("A:MOVE  SELECT:BOX", "A:BEWEG. SELECT:BOX")
      or tr("A:MOVE  SELECT:PARTY", "A:BEWEG. SELECT:TEAM"))
    color(C.ink)
    drawFittedFireRedText(text, 87, FRLG_HELP_Y + 4, 148)
  end

  local function drawOrganizerBox(state)
    local game = state.game
    local box = Boxes.active(game.save) or {}
    local mon = box[state.boxIndex]
    local fake = {
      items = organizerItems(box), index = state.boxIndex,
      title = Strings("BOX %d (MOVE)", game.save.currentBox or 1),
    }
    drawFireRedBoxShell(game, mon, state.slide)
    -- A carried mon stays in its engine-owned source list until a drop is
    -- committed.  Hide that slot only while its actual source Box is visible;
    -- otherwise the same slot number would disappear in every Box we browse.
    local hidden = state.carry and state.carry.zone == "box"
      and state.carry.list == box and state.carry.index or nil
    drawFireRedBoxMons(fake, game, false, state.slide, hidden)
    if not state.transition and state.zone == "close" then
      drawPixelHand(163, 2, game, state.carry and state.carry.mon)
    elseif not state.transition and state.zone == "box_tab" then
      drawPixelHand(149, 17, game, state.carry and state.carry.mon)
    elseif not state.transition then
      local x, y = fireRedSlotCenter(state.boxIndex)
      drawPixelHand(x - 8 + (state.slide or 0), y - 13,
        game, state.carry and state.carry.mon)
    end
    drawFireRedBoxHeading(game)
    drawFireRedDataText(mon, game)
    drawOrganizerHelp(state)
  end

  local function drawOrganizerParty(state)
    local game, party = state.game, state.game.save.party or {}
    local mon = party[state.partyIndex]
    drawAtlasRegion("organizer-backdrop", PC_ATLAS_REGIONS.orange,
      0, 0, 240, 160)
    drawFireRedData(mon, game)
    drawFireRedTopButtons(true)
    color(C.cream)
    love.graphics.rectangle("fill", 82, 23, 158, 137)
    color(C.blue3)
    love.graphics.rectangle("line", 82.5, 23.5, 157, 136)
    color(C.green)
    love.graphics.rectangle("fill", 86, 26, 148, 15)
    color(C.ink)
    Font.draw(tr("PARTY POKéMON", "TEAM-POKéMON"), 92, 30)
    for index = 1, 6 do
      local rowMon = party[index]
      local y = 45 + (index - 1) * 16
      if index == state.partyIndex then
        color(C.gold)
        love.graphics.rectangle("fill", 86, y - 2, 148, 15)
      end
      local hidden = state.carry and state.carry.zone == "party"
        and state.carry.index == index
      if rowMon and not hidden then
        drawMonImage(game, rowMon, 88, y - 3, 17, 17)
        local def = game.data.pokemon[rowMon.species] or {}
        color(C.ink)
        drawFittedFireRedText(
          rowMon.nickname or def.name or rowMon.species, 108, y, 80)
        drawFittedFireRedText(Strings("Lv%d", rowMon.level or 0),
          194, y, 37)
      else
        color(C.ink)
        Font.draw("-", 111, y)
      end
      if index == state.partyIndex and not state.transition then
        drawPixelHand(78, y - 5, game, state.carry and state.carry.mon)
      end
    end
    drawFireRedDataText(mon, game)
    drawOrganizerHelp(state)
  end

  local function wideOrganizerHelp(state, inParty)
    local text = state.message
    if not text and state.carry then
      local def = state.game.data.pokemon[state.carry.mon.species] or {}
      text = tr("MOVE: ", "BEWEGT: ")
        .. (state.carry.mon.nickname or def.name or state.carry.mon.species)
    end
    text = text or (inParty
      and tr("A:MOVE  SELECT:BOX  B:BACK", "A:BEWEG. SELECT:BOX  B:ZUR")
      or tr("A:MOVE  SELECT:PARTY  B:BACK",
        "A:BEWEG. SELECT:TEAM  B:ZUR"))
    drawFireRedWideFooter(text)
  end

  local function drawWideOrganizerBox(state)
    local game = state.game
    local box = Boxes.active(game.save) or {}
    local mon = box[state.boxIndex]
    drawFireRedWideBoxBase(game, nil, nil, state.slide)
    local hidden = state.carry and state.carry.zone == "box"
      and state.carry.list == box and state.carry.index or nil
    drawFireRedWideBoxSlots(game, box, state.boxIndex, {
      hiddenSlot = hidden,
      slide = state.slide,
      showCursor = not state.transition and state.zone == "box",
      carriedMon = state.carry and state.carry.mon,
    })
    drawFireRedWideDetail(game, mon,
      Strings(tr("BOX SLOT %02d", "BOX-PLATZ %02d"), state.boxIndex))
    if not state.transition and state.zone == "close" then
      drawPixelHand(419, 8, game, state.carry and state.carry.mon)
    elseif not state.transition and state.zone == "box_tab" then
      drawPixelHand(91, 8, game, state.carry and state.carry.mon)
    end
    wideOrganizerHelp(state, false)
  end

  local function drawWideOrganizerParty(state)
    local party = state.game.save.party or {}
    local hidden = state.carry and state.carry.zone == "party"
      and state.carry.index or nil
    drawFireRedWidePartyList(state.game, party, state.partyIndex, hidden,
      state.carry and state.carry.mon, not state.transition)
    wideOrganizerHelp(state, true)
  end

  local function wideOrganizerCursorPoint(state, zone)
    if zone == "party" then
      local col = (state.partyIndex - 1) % 2
      local row = math.floor((state.partyIndex - 1) / 2)
      return 12 + col * 161, 66 + row * 61
    end
    local x, y = fireRedWideSlotCenter(state.boxIndex)
    return x - 9, y - 18
  end

  local function rememberWideOrganizer(state)
    if not state.__ascendantFireRedWideOrganizer then return end
    local memory = wideMemory(state.game)
    memory.organizer = {
      zone = state.zone == "party" and "party" or "box",
      boxIndex = state.boxIndex,
      partyIndex = state.partyIndex,
    }
  end

  local function organizerSwitchBox(state, direction)
    local count = Boxes.COUNT or #Boxes.ensure(state.game.save)
    state.game.save.currentBox =
      (((state.game.save.currentBox or 1) - 1 + direction) % count) + 1
    if not state.__ascendantFireRedWideOrganizer then state.boxIndex = 1 end
    state.slide = direction * 48
    -- Deliberately no writeSave and no confirmation prompt: selecting a Box
    -- is navigation now. The current Box persists with the next normal save.
  end

  local function ensurePartyStats(game, mon)
    if not mon then return end
    local ok, Stats = pcall(require, "src.pokemon.Stats")
    local def = game.data.pokemon[mon.species]
    if ok and Stats and type(Stats.ensure) == "function" and def then
      Stats.ensure(def, mon)
    end
  end

  local function depositedFollower(game, mon)
    local ok, follower = pcall(require, "src.world.PikachuFollower")
    if ok and follower and type(follower.modifyHappiness) == "function" then
      pcall(follower.modifyHappiness, game.save, "DEPOSITED", mon)
    end
  end

  local function organizerDrop(state)
    local carry = state.carry
    if not carry then return end
    local targetZone = state.zone == "party" and "party" or "box"
    local targetIndex = targetZone == "party"
      and state.partyIndex or state.boxIndex
    local source, target = carry.list, organizerList(state, targetZone)
    local sourceIndex = carry.index
    if source[sourceIndex] ~= carry.mon then
      state.carry = nil
      organizerMessage(state, "MOVE CANCELLED", "BEWEGEN ABBRUCH")
      return
    end

    -- Engine Box/party arrays are packed. Visual slot 20 is therefore the
    -- next append position when only three records exist, not a sparse table
    -- index. Normalize before every branch and move the cursor to the actual
    -- committed seat so "MOVED" never leaves it pointing at an empty cell.
    local actualTargetIndex = math.min(targetIndex, #target + 1)

    if carry.zone == targetZone and source == target then
      if actualTargetIndex <= #target then
        target[sourceIndex], target[actualTargetIndex] =
          target[actualTargetIndex], target[sourceIndex]
      else
        local mon = table.remove(target, sourceIndex)
        actualTargetIndex = math.min(actualTargetIndex, #target + 1)
        table.insert(target, actualTargetIndex, mon)
      end
    elseif target[actualTargetIndex] then
      local other = target[actualTargetIndex]
      source[sourceIndex], target[actualTargetIndex] = other, carry.mon
      local newPartyMon = targetZone == "party" and carry.mon
        or carry.zone == "party" and other or nil
      if newPartyMon then ensurePartyStats(state.game, newPartyMon) end
      if carry.zone == "party" then depositedFollower(state.game, carry.mon) end
    else
      if targetZone == "party" and #target >= 6 then
        organizerMessage(state, "PARTY IS FULL", "TEAM IST VOLL")
        return
      end
      if carry.zone == "party" and #source <= 1 then
        organizerMessage(state, "KEEP ONE IN PARTY", "EINS MUSS IM TEAM BLEIBEN")
        return
      end
      if targetZone == "box" and #target >= (Boxes.CAPACITY or 20) then
        organizerMessage(state, "BOX IS FULL", "BOX IST VOLL")
        return
      end
      local mon = table.remove(source, sourceIndex)
      actualTargetIndex = math.min(actualTargetIndex, #target + 1)
      table.insert(target, actualTargetIndex, mon)
      if targetZone == "party" then ensurePartyStats(state.game, mon) end
      if carry.zone == "party" then depositedFollower(state.game, mon) end
    end
    if targetZone == "party" then state.partyIndex = actualTargetIndex
    else state.boxIndex = actualTargetIndex end
    state.carry = nil
    organizerMessage(state, "MOVED", "VERSCHOBEN")
  end

  local function organizerPickOrDrop(state)
    if state.zone == "box_tab" then
      state.zone = "party"
      return
    end
    if state.carry then return organizerDrop(state) end
    local zone = state.zone == "party" and "party" or "box"
    local list = organizerList(state, zone)
    local index = zone == "party" and state.partyIndex or state.boxIndex
    if not list[index] then
      organizerMessage(state, "EMPTY SLOT", "LEERER PLATZ")
      return
    end
    state.carry = {
      zone = zone, list = list, index = index, mon = list[index],
      box = zone == "box" and (state.game.save.currentBox or 1) or nil,
    }
  end

  local function organizerCursorPoint(state, zone)
    if zone == "party" then
      return 78, 40 + (state.partyIndex - 1) * 16
    end
    local x, y = fireRedSlotCenter(state.boxIndex)
    return x - 8, y - 13
  end

  local function organizerBeginViewTransition(state, target)
    local from = state.zone == "party" and "party" or "box"
    if from == target then return end
    state.transition = { from = from, to = target, progress = 0 }
  end

  local function newOrganizer(game, startOnTab)
    local wide = useWideFireRedPc(game)
    local remembered = wide and wideMemory(game).organizer or nil
    local state = {
      game = game, zone = startOnTab and "box_tab"
        or remembered and remembered.zone or "box",
      boxIndex = remembered and remembered.boxIndex or 1,
      partyIndex = remembered and remembered.partyIndex or 1, slide = 0,
      isOpaque = true, letterboxWhite = true,
      __ascendantFireRedOrganizer = true,
      __ascendantFireRedWideOrganizer = wide or nil,
    }
    state.boxIndex = math.max(1, math.min(20, state.boxIndex))
    state.partyIndex = math.max(1, math.min(6, state.partyIndex))
    state.uiSize = wide and fireRedWideUiSize or fireRedOrganizerUiSize
    state.sgbPalettes = wide and fireRedWideTrueColor
      or fireRedOrganizerTrueColor
    function state:update(dt)
      if self.messageTime then
        self.messageTime = self.messageTime - (tonumber(dt) or 0)
        if self.messageTime <= 0 then
          self.message, self.messageTime = nil, nil
        end
      end
      if self.slide ~= 0 then
        local factor = math.max(0, 1 - (tonumber(dt) or 0) * 14)
        self.slide = self.slide * factor
        if math.abs(self.slide) < .5 then self.slide = 0 end
      end
      if self.transition then
        local transition = self.transition
        transition.progress = math.min(1,
          transition.progress + (tonumber(dt) or 0) / .20)
        if transition.progress >= 1 then
          self.zone = transition.to
          self.transition = nil
        end
        return
      end
      local input = self.game.input
      if input:wasPressed("b") then
        if self.carry then
          self.carry = nil
          organizerMessage(self, "MOVE CANCELLED", "BEWEGEN ABBRUCH")
        else
          self.game.stack:pop()
        end
        return
      end
      -- SELECT is the FireRed PARTY POKéMON button and must remain available
      -- while carrying; otherwise a Pokémon could never cross between the
      -- Box grid and the party rail.
      if input:wasPressed("select") then
        organizerBeginViewTransition(self,
          self.zone == "party" and "box" or "party")
        return
      end
      if input:wasPressed("a") then
        if self.zone == "close" then
          -- Picking up is only a pending UI operation: the source record has
          -- not been removed yet, so closing safely cancels the carry.
          self.carry = nil
          self.game.stack:pop()
        else
          organizerPickOrDrop(self)
        end
        return
      end
      if self.zone == "close" then
        if input:wasPressed("left") then
          organizerBeginViewTransition(self, "party")
        elseif input:wasPressed("down") then
          self.zone = "box_tab"
        end
      elseif self.zone == "box_tab" then
        if input:wasPressed("left") then organizerSwitchBox(self, -1)
        elseif input:wasPressed("right") then organizerSwitchBox(self, 1)
        elseif input:wasPressed("up") then self.zone = "close"
        elseif input:wasPressed("down") then self.zone = "box" end
      elseif self.zone == "party" then
        if self.__ascendantFireRedWideOrganizer then
          local col = (self.partyIndex - 1) % 2
          if input:wasPressed("left") then
            if col > 0 then self.partyIndex = self.partyIndex - 1 end
          elseif input:wasPressed("right") then
            if col < 1 then self.partyIndex = self.partyIndex + 1 end
          elseif input:wasPressed("up") then
            self.partyIndex = math.max(1, self.partyIndex - 2)
          elseif input:wasPressed("down") then
            self.partyIndex = math.min(6, self.partyIndex + 2)
          end
        elseif input:wasPressed("up") then
          self.partyIndex = math.max(1, self.partyIndex - 1)
        elseif input:wasPressed("down") then
          self.partyIndex = math.min(6, self.partyIndex + 1)
        elseif input:wasPressed("left") then
          organizerBeginViewTransition(self, "box")
        end
      else
        local col = (self.boxIndex - 1) % 5
        if input:wasPressed("left") then
          self.boxIndex = col > 0 and self.boxIndex - 1 or self.boxIndex
        elseif input:wasPressed("right") then
          self.boxIndex = col < 4 and self.boxIndex + 1 or self.boxIndex
        elseif input:wasPressed("up") then
          if self.boxIndex <= 5 then self.zone = "box_tab"
          else self.boxIndex = self.boxIndex - 5 end
        elseif input:wasPressed("down") then
          self.boxIndex = math.min(20, self.boxIndex + 5)
        end
      end
    end
    function state:draw()
      local card=fullscreenCard(self.game)
      if card and card.drawStorage(self,self.zone=="party",self.boxIndex,self.partyIndex,
          self.carry,self.zone=="box_tab",tr("A:MOVE  B:BACK  SELECT:TEAM/BOX  L/R:BOX",
          "A:BEWEGEN B:ZUR SELECT:TEAM/BOX L/R:BOX")) then return end
      if wide then
        local transition = self.transition
        if not transition then
          if self.zone == "party" then drawWideOrganizerParty(self)
          else drawWideOrganizerBox(self) end
          color(C.white)
          return
        end
        local t = transition.progress
        t = t * t * (3 - 2 * t)
        local boxX, partyX
        if transition.from == "box" then
          boxX, partyX = -FRLG_WIDE_W * t, FRLG_WIDE_W * (1 - t)
        else
          partyX, boxX = FRLG_WIDE_W * t, -FRLG_WIDE_W * (1 - t)
        end
        love.graphics.push()
        love.graphics.translate(boxX, 0)
        drawWideOrganizerBox(self)
        love.graphics.pop()
        love.graphics.push()
        love.graphics.translate(partyX, 0)
        drawWideOrganizerParty(self)
        love.graphics.pop()
        local fromX, fromY = wideOrganizerCursorPoint(self, transition.from)
        local toX, toY = wideOrganizerCursorPoint(self, transition.to)
        drawPixelHand(fromX + (toX - fromX) * t,
          fromY + (toY - fromY) * t, self.game,
          self.carry and self.carry.mon or nil)
        color(C.white)
        return
      end
      drawOnGbaCanvas(function()
        local transition = self.transition
        if not transition then
          if self.zone == "party" then drawOrganizerParty(self)
          else drawOrganizerBox(self) end
          return
        end
        local t = transition.progress
        t = t * t * (3 - 2 * t)
        local boxX, partyX
        if transition.from == "box" then
          boxX, partyX = -240 * t, 240 * (1 - t)
        else
          partyX, boxX = 240 * t, -240 * (1 - t)
        end
        love.graphics.push()
        love.graphics.translate(boxX, 0)
        drawOrganizerBox(self)
        love.graphics.pop()
        love.graphics.push()
        love.graphics.translate(partyX, 0)
        drawOrganizerParty(self)
        love.graphics.pop()
        local fromX, fromY = organizerCursorPoint(self, transition.from)
        local toX, toY = organizerCursorPoint(self, transition.to)
        local handX = fromX + (toX - fromX) * t
        local handY = fromY + (toY - fromY) * t
        drawPixelHand(handX, handY, self.game,
          self.carry and self.carry.mon or nil)
      end)
      color(C.white)
    end
    local updateOrganizer = state.update
    state.update = function(self, dt)
      local result = updateOrganizer(self, dt)
      rememberWideOrganizer(self)
      return result
    end
    return state
  end

  -- Legacy Bank organizer. The archive stays the sole storage authority;
  -- this state only projects its ordered rows onto virtual 20-slot pages.
  -- Five hundred empty pages therefore cost no save space. Page 501 appears
  -- only after slots 1..10000 are occupied, and the same rule keeps extending
  -- the view without an artificial upper bound.
  local function newLegacyBankOrganizer(game, adapter)
    assert(type(adapter) == "table", "Legacy Bank organizer needs an adapter")
    local wide = useWideFireRedLegacyBank(game)
    local remembered = wide and wideMemory(game).legacyBank or nil
    local state = {
      game = game, adapter = adapter,
      zone = remembered and remembered.zone or "bank",
      bankBox = remembered and remembered.bankBox or 1,
      bankIndex = remembered and remembered.bankIndex or 1,
      partyIndex = remembered and remembered.partyIndex or 1,
      rows = {}, slots = {}, slide = 0,
      selected = {},
      isOpaque = true, letterboxWhite = true,
      __ascendantFireRedOrganizer = true,
      __ascendantLegacyBankOrganizer = true,
      __ascendantFireRedWideOrganizer = wide or nil,
      __ascendantWideLegacyBank = wide or nil,
    }
    state.bankIndex = math.max(1, math.min(20, state.bankIndex))
    state.partyIndex = math.max(1, math.min(6, state.partyIndex))
    state.uiSize = wide and fireRedWideUiSize or fireRedOrganizerUiSize
    state.sgbPalettes = wide and fireRedWideTrueColor
      or fireRedOrganizerTrueColor

    function state:refresh()
      local rows, err = self.adapter.rows()
      if type(rows) ~= "table" then
        self.rows = {}
        self.message = tostring(err or tr("BANK UNAVAILABLE", "BANK NICHT VERFÜGBAR"))
        self.messageTime = 2.5
        return false
      end
      self.rows = rows
      self.slots = {}
      local maximum = 500
      for index, row in ipairs(rows) do
        local slot = math.max(1, math.floor(tonumber(row.bankSlot) or index))
        if not self.slots[slot] then self.slots[slot] = row end
        maximum = math.max(maximum,
          math.floor(tonumber(row.bankBoxCount) or 0), math.ceil(slot / 20))
      end
      maximum = math.max(maximum, math.ceil((#rows + 1) / 20))
      self.bankBoxCount = maximum
      self.bankBox = math.max(1, math.min(self.bankBox, maximum))
      self.bankIndex = math.max(1, math.min(20, self.bankIndex or 1))
      return true
    end

    function state:boxCount()
      return self.bankBoxCount or 500
    end

    function state:globalIndex(slot)
      return (self.bankBox - 1) * 20 + (slot or self.bankIndex)
    end

    function state:bankRow(slot)
      return self.slots[self:globalIndex(slot)]
    end

    function state:selectedRows()
      local rows = {}
      for _, row in ipairs(self.rows or {}) do
        if row and row.id and self.selected[row.id] then
          rows[#rows + 1] = row
        end
      end
      return rows
    end

    function state:selectedCount()
      return #self:selectedRows()
    end

    local function bankMessage(self, text)
      self.message = tostring(text or "")
      self.messageTime = 2.4
    end

    local function bankLockFooter(reason)
      local upper = tostring(reason or ""):upper()
      if upper:find("BEYOND KANTO", 1, true)
          or upper:find("JENSEITS VON KANTO", 1, true) then
        return tr("BEYOND KANTO: SEALED", "JOHTO: GESPERRT")
      end
      return tr("WITHDRAWAL LOCKED", "ENTNAHME GESPERRT")
    end

    local function bankMon(self)
      if self.zone == "party" then
        return (self.game.save.party or {})[self.partyIndex]
      end
      local row = self:bankRow()
      return row and row.mon
    end

    local function drawBankHelp(self)
      color(C.cream)
      love.graphics.rectangle("fill", 82, FRLG_HELP_Y, 158, 16)
      color(C.blue3)
      love.graphics.rectangle("line", 82.5, FRLG_HELP_Y + 0.5, 157, 15)
      local row = self.zone ~= "party" and self:bankRow() or nil
      local text = self.message
      if not text and row and row.withdrawBlocked then
        text = bankLockFooter(row.withdrawReason)
      end
      if not text and self.carry then
        local mon = self.carry.mon
        local def = self.game.data.pokemon[mon.species] or {}
        text = tr("MOVE: ", "BEWEGT: ")
          .. (mon.nickname or def.name or mon.species)
      end
      text = text or (self.zone == "party"
        and tr("A:STORE  SELECT:BANK", "A:ABLG  SELECT:BANK")
        or self:selectedCount() > 0
          and tr(("START:MARK  A:ACTIONS %d"):format(self:selectedCount()),
            ("START:MARK. A:AKTION %d"):format(self:selectedCount()))
          or tr("A:TAKE START:MARK", "A:NEHM START:MARK."))
      color(C.ink)
      drawFittedFireRedText(text, 87, FRLG_HELP_Y + 4, 148)
    end

    local function drawBankMons(self)
      for slot = 1, 20 do
        local row = self:bankRow(slot)
        local x, y = fireRedSlotCenter(slot)
        local hidden = self.carry and self.carry.zone == "bank"
          and self.carry.id == (row and row.id)
        if row and row.mon and not hidden then
          if not drawBoxGridWalker(self.game, row.mon, x, y) then
            drawMonImage(self.game, row.mon, x - 10, y - 10, 20, 20)
          end
          if row.withdrawBlocked then
            color(C.red)
            -- Keep the lock badge beside the hand, not under its palm.
            love.graphics.rectangle("fill", x + 8, y - 11, 7, 7)
            color(C.white)
            Font.draw("X", x + 9, y - 10)
          elseif self.selected[row.id] then
            color(C.blue3)
            love.graphics.rectangle("fill", x + 8, y - 11, 7, 7)
            color(C.white)
            Font.draw("+", x + 8, y - 10)
          end
        end
      end
      if not self.transition and self.zone == "bank" then
        local x, y = fireRedSlotCenter(self.bankIndex)
        local row = self:bankRow()
        local handY = row and row.withdrawBlocked and y - 24 or y - 13
        drawPixelHand(x - 8 + (self.slide or 0), handY,
          self.game, self.carry and self.carry.mon)
      elseif not self.transition and self.zone == "bank_tab" then
        drawPixelHand(149, 17, self.game, self.carry and self.carry.mon)
      elseif not self.transition and self.zone == "close" then
        drawPixelHand(163, 2, self.game, self.carry and self.carry.mon)
      end
    end

    local function drawBank(self)
      local mon = bankMon(self)
      drawFireRedBoxShell(self.game, mon, self.slide, self.bankBox)
      drawBankMons(self)
      drawFireRedBoxHeading(self.game, self.bankBox,
        tr("BANK", "BANK"))
      drawFireRedDataText(mon, self.game)
      drawBankHelp(self)
    end

    local function drawBankParty(self)
      drawOrganizerParty(self)
      drawBankHelp(self)
    end

    local function wideBankHelp(self, inParty)
      local row = not inParty and self:bankRow() or nil
      local text = self.message
      if not text and row and row.withdrawBlocked then
        text = bankLockFooter(row.withdrawReason)
      end
      if not text and self.carry then
        local mon = self.carry.mon
        local def = self.game.data.pokemon[mon.species] or {}
        text = tr("MOVE: ", "BEWEGT: ")
          .. (mon.nickname or def.name or mon.species)
      end
      text = text or (inParty
        and tr("A:STORE  SELECT:BANK  B:BACK",
          "A:ABLG  SELECT:BANK  B:ZUR")
        or self:selectedCount() > 0
          and tr(("START:MARK  A:ACTIONS %d"):format(self:selectedCount()),
            ("START:MARK. A:AKTION %d"):format(self:selectedCount()))
          or tr("A:TAKE  START:MARK  SELECT:PARTY",
            "A:NEHM  START:MARK. SELECT:TEAM"))
      drawFireRedWideFooter(text,
        inParty and Strings("%d/6", #(self.game.save.party or {}))
          or Strings("%03d/%03d", self.bankBox, self:boxCount()))
    end

    local function drawWideBank(self)
      local box = {}
      local hiddenSlot
      for slot = 1, 20 do
        local row = self:bankRow(slot)
        box[slot] = row and row.mon or nil
        if self.carry and self.carry.zone == "bank" and row
            and row.id == self.carry.id then hiddenSlot = slot end
      end
      local row = self:bankRow()
      local mon = row and row.mon or nil
      drawFireRedWideBoxBase(self.game, self.bankBox,
        Strings("BANK %03d", self.bankBox), self.slide)
      drawFireRedWideBoxSlots(self.game, box, self.bankIndex, {
        slide = self.slide,
        hiddenSlot = hiddenSlot,
        showCursor = not self.transition and self.zone == "bank",
        carriedMon = self.carry and self.carry.mon,
        decorate = function(slot, _, x, y)
          local slotRow = self:bankRow(slot)
          if slotRow and slotRow.withdrawBlocked then
            color(C.red)
            love.graphics.rectangle("fill", x + 19, y - 17, 12, 12)
            color(C.white)
            Font.draw("X", x + 21, y - 15)
          elseif slotRow and self.selected[slotRow.id] then
            color(C.blue3)
            love.graphics.rectangle("fill", x + 19, y - 17, 12, 12)
            color(C.white)
            Font.draw("+", x + 21, y - 15)
          end
        end,
      })
      drawFireRedWideDetail(self.game, mon,
        row and row.withdrawBlocked and bankLockFooter(row.withdrawReason)
          or Strings(tr("BANK SLOT %05d", "BANK-PLATZ %05d"),
            self:globalIndex()))
      if not self.transition and self.zone == "close" then
        drawPixelHand(419, 8, self.game, self.carry and self.carry.mon)
      elseif not self.transition and self.zone == "bank_tab" then
        drawPixelHand(91, 8, self.game, self.carry and self.carry.mon)
      end
      wideBankHelp(self, false)
    end

    local function drawWideBankParty(self)
      local party = self.game.save.party or {}
      local hidden = self.carry and self.carry.zone == "party"
        and self.carry.index or nil
      drawFireRedWidePartyList(self.game, party, self.partyIndex, hidden,
        self.carry and self.carry.mon, not self.transition)
      wideBankHelp(self, true)
    end

    local function rememberWideBank(self)
      if not self.__ascendantWideLegacyBank then return end
      wideMemory(self.game).legacyBank = {
        zone = self.zone == "party" and "party" or "bank",
        bankBox = self.bankBox,
        bankIndex = self.bankIndex,
        partyIndex = self.partyIndex,
      }
    end

    local function switchBankBox(self, direction)
      local count = self:boxCount()
      self.bankBox = (((self.bankBox - 1 + direction) % count) + 1)
      if not self.__ascendantWideLegacyBank then self.bankIndex = 1 end
      self.slide = direction * 48
    end

    local function beginBankTransition(self, target)
      local from = self.zone == "party" and "party" or "bank"
      if from ~= target then
        self.transition = { from = from, to = target, progress = 0 }
      end
    end

    local function pickOrDrop(self)
      if self.zone == "bank_tab" then self.zone = "party" return end
      if not self.carry then
        if self.zone == "party" then
          local mon = (self.game.save.party or {})[self.partyIndex]
          if not mon then return bankMessage(self,
            tr("EMPTY SLOT", "LEERER PLATZ")) end
          self.carry = { zone = "party", index = self.partyIndex, mon = mon }
        else
          local row = self:bankRow()
          if not row then return bankMessage(self,
            tr("EMPTY SLOT", "LEERER PLATZ")) end
          if row.withdrawBlocked then
            if type(self.adapter.showLocked) == "function" then
              self.adapter.showLocked(row)
            end
            return bankMessage(self, bankLockFooter(row.withdrawReason))
          end
          self.carry = { zone = "bank", id = row.id, mon = row.mon,
            index = self:globalIndex() }
        end
        return
      end

      local carry = self.carry
      local ok, err
      if carry.zone == "bank" and self.zone == "bank" then
        ok, err = self.adapter.move(carry.id, self:globalIndex())
      elseif carry.zone == "bank" and self.zone == "party" then
        ok, err = self.adapter.withdraw(carry.row or { id = carry.id,
          mon = carry.mon })
      elseif carry.zone == "party" and self.zone ~= "party" then
        ok, err = self.adapter.deposit(carry.index, self:globalIndex())
      else
        return bankMessage(self, tr("CHOOSE THE BANK", "BANK AUSWÄHLEN"))
      end
      if not ok then return bankMessage(self, err or
        tr("BANK ACTION FAILED", "BANK-AKTION FEHLGESCHLAGEN")) end
      self.carry = nil
      self:refresh()
      bankMessage(self, tr("BANK UPDATED", "BANK AKTUALISIERT"))
    end

    local function toggleBankSelection(self)
      if self.zone ~= "bank" or self.carry then return false end
      local row = self:bankRow()
      if not row then
        bankMessage(self, tr("EMPTY SLOT", "LEERER PLATZ"))
        return true
      end
      if row.withdrawBlocked then
        if type(self.adapter.showLocked) == "function" then
          self.adapter.showLocked(row)
        end
        bankMessage(self, bankLockFooter(row.withdrawReason))
        return true
      end
      self.selected[row.id] = not self.selected[row.id] or nil
      bankMessage(self, self.selected[row.id]
        and tr("POKéMON MARKED", "POKéMON MARKIERT")
        or tr("MARK REMOVED", "MARKIERUNG ENTFERNT"))
      return true
    end

    local function openSelectedAction(self)
      local rows = self:selectedRows()
      if #rows == 0 or type(self.adapter.selectedAction) ~= "function" then
        return false
      end
      self.adapter.selectedAction(rows, function(completed, cancelled)
        if completed or cancelled then self.selected = {} end
        self.carry = nil
        self:refresh()
        if completed then
          bankMessage(self, tr("PC BOXES UPDATED", "PC-BOXEN AKTUALISIERT"))
        end
      end)
      return true
    end

    function state:update(dt)
      if self.messageTime then
        self.messageTime = self.messageTime - (tonumber(dt) or 0)
        if self.messageTime <= 0 then self.message, self.messageTime = nil, nil end
      end
      if self.slide ~= 0 then
        local factor = math.max(0, 1 - (tonumber(dt) or 0) * 14)
        self.slide = self.slide * factor
        if math.abs(self.slide) < .5 then self.slide = 0 end
      end
      if self.transition then
        local transition = self.transition
        transition.progress = math.min(1,
          transition.progress + (tonumber(dt) or 0) / .20)
        if transition.progress >= 1 then
          self.zone, self.transition = transition.to, nil
        end
        return
      end
      local input = self.game.input
      if input:wasPressed("b") then
        if self.carry then
          self.carry = nil
          bankMessage(self, tr("MOVE CANCELLED", "BEWEGEN ABBRUCH"))
        else self.game.stack:pop() end
        return
      end
      if input:wasPressed("select") then
        beginBankTransition(self,
          self.zone == "party" and "bank" or "party")
        return
      end
      if input:wasPressed("start") then
        if toggleBankSelection(self) then return end
      end
      if input:wasPressed("a") then
        if self.zone == "close" then
          self.carry = nil
          self.game.stack:pop()
        elseif not openSelectedAction(self) then pickOrDrop(self) end
        return
      end
      if self.zone == "close" then
        if input:wasPressed("left") then
          beginBankTransition(self, "party")
        elseif input:wasPressed("down") then self.zone = "bank_tab" end
      elseif self.zone == "bank_tab" then
        if input:wasPressed("left") then switchBankBox(self, -1)
        elseif input:wasPressed("right") then switchBankBox(self, 1)
        elseif input:wasPressed("up") then self.zone = "close"
        elseif input:wasPressed("down") then self.zone = "bank" end
      elseif self.zone == "party" then
        if self.__ascendantWideLegacyBank then
          local col = (self.partyIndex - 1) % 2
          if input:wasPressed("left") then
            if col > 0 then self.partyIndex = self.partyIndex - 1 end
          elseif input:wasPressed("right") then
            if col < 1 then self.partyIndex = self.partyIndex + 1 end
          elseif input:wasPressed("up") then
            self.partyIndex = math.max(1, self.partyIndex - 2)
          elseif input:wasPressed("down") then
            self.partyIndex = math.min(6, self.partyIndex + 2)
          end
        elseif input:wasPressed("up") then
          self.partyIndex = math.max(1, self.partyIndex - 1)
        elseif input:wasPressed("down") then
          self.partyIndex = math.min(6, self.partyIndex + 1)
        elseif input:wasPressed("left") then
          beginBankTransition(self, "bank")
        end
      else
        local col = (self.bankIndex - 1) % 5
        if input:wasPressed("left") then
          self.bankIndex = col > 0 and self.bankIndex - 1 or self.bankIndex
        elseif input:wasPressed("right") then
          self.bankIndex = col < 4 and self.bankIndex + 1 or self.bankIndex
        elseif input:wasPressed("up") then
          if self.bankIndex <= 5 then self.zone = "bank_tab"
          else self.bankIndex = self.bankIndex - 5 end
        elseif input:wasPressed("down") then
          self.bankIndex = math.min(20, self.bankIndex + 5)
        end
      end
    end

    function state:draw()
      if wide then
        local transition = self.transition
        if not transition then
          if self.zone == "party" then drawWideBankParty(self)
          else drawWideBank(self) end
          color(C.white)
          return
        end
        local t = transition.progress
        t = t * t * (3 - 2 * t)
        local bankX, partyX
        if transition.from == "bank" then
          bankX, partyX = -FRLG_WIDE_W * t, FRLG_WIDE_W * (1 - t)
        else
          partyX, bankX = FRLG_WIDE_W * t, -FRLG_WIDE_W * (1 - t)
        end
        love.graphics.push()
        love.graphics.translate(bankX, 0)
        drawWideBank(self)
        love.graphics.pop()
        love.graphics.push()
        love.graphics.translate(partyX, 0)
        drawWideBankParty(self)
        love.graphics.pop()
        local fromX, fromY
        if transition.from == "party" then
          fromX, fromY = wideOrganizerCursorPoint(self, "party")
        else
          local x, y = fireRedWideSlotCenter(self.bankIndex)
          fromX, fromY = x - 9, y - 18
        end
        local toX, toY
        if transition.to == "party" then
          toX, toY = wideOrganizerCursorPoint(self, "party")
        else
          local x, y = fireRedWideSlotCenter(self.bankIndex)
          toX, toY = x - 9, y - 18
        end
        drawPixelHand(fromX + (toX - fromX) * t,
          fromY + (toY - fromY) * t, self.game,
          self.carry and self.carry.mon or nil)
        color(C.white)
        return
      end
      drawOnGbaCanvas(function()
        local transition = self.transition
        if not transition then
          if self.zone == "party" then drawBankParty(self) else drawBank(self) end
          return
        end
        local t = transition.progress
        t = t * t * (3 - 2 * t)
        local bankX, partyX
        if transition.from == "bank" then
          bankX, partyX = -240 * t, 240 * (1 - t)
        else
          partyX, bankX = 240 * t, -240 * (1 - t)
        end
        love.graphics.push()
        love.graphics.translate(bankX, 0)
        drawBank(self)
        love.graphics.pop()
        love.graphics.push()
        love.graphics.translate(partyX, 0)
        drawBankParty(self)
        love.graphics.pop()
      end)
      color(C.white)
    end

    local updateBank = state.update
    state.update = function(self, dt)
      local result = updateBank(self, dt)
      rememberWideBank(self)
      return result
    end

    state:refresh()
    return state
  end

  -- VASC owns the optional ASC BOX drawing/controller.  KASC owns the Legacy
  -- archive and receives only an owner-scoped binding from its local consumer
  -- card.  Discovery, Host-v1 validation, registration and retirement stay
  -- behind that boundary; this module owns only the immutable model/actions.
  -- If the card or its public VASC capability is unavailable, callers retain
  -- the selected FRLG/KASC fallback unchanged.
  local legacySessionSerial = 0

  local function copyArray(items)
    local out = {}
    for index, value in ipairs(items or {}) do out[index] = value end
    return out
  end

  local function legacyPokemonDescriptor(game, mon)
    if type(mon) ~= "table" then return nil end
    local egg = mon.egg == true or mon.isEgg == true or mon.is_egg == true
      or tostring(mon.status or ""):upper() == "EGG"
    if egg then
      return { species="EGG", egg=true, nickname="EGG", level=0,
        art={ kind="pokemon", species="EGG", egg=true,
          variant="vasc_neutral" } }
    end
    local def = game.data and game.data.pokemon
      and game.data.pokemon[mon.species] or {}
    local types = {}
    for _, value in ipairs(type(mon.types) == "table" and mon.types
        or type(def.types) == "table" and def.types or {}) do
      if type(value) == "string" and value ~= "" and #types < 2
          and value ~= types[1] then types[#types + 1] = value end
    end
    local shiny = monIsShiny(mon)
    local maxHp = mon.stats and tonumber(mon.stats.hp) or tonumber(mon.maxHp)
    local item = mon.item or mon.heldItem or mon.held_item
    if type(item) == "table" then item = item.id or item.name end
    local ability = mon.ability or def.ability
    if type(ability) == "table" then ability = ability.id or ability.name end
    local gender = mon.gender
    if type(gender) ~= "string" then gender = nil end
    return {
      species=mon.species, form=mon.form, gender=gender,
      shiny=shiny, egg=false, nickname=mon.nickname,
      level=math.max(0, math.floor(tonumber(mon.level) or 0)),
      hp=mon.hp and math.max(0, math.floor(tonumber(mon.hp) or 0)) or nil,
      maxHp=maxHp and math.max(0, math.floor(maxHp)) or nil,
      status=type(mon.status) == "string" and mon.status or nil,
      ability=(type(ability) == "string" or type(ability) == "number")
        and ability or nil,
      item=(type(item) == "string" or type(item) == "number") and item or nil,
      types=types,
      art={ kind="pokemon", species=mon.species, form=mon.form,
        gender=gender, shiny=shiny, egg=false },
    }
  end

  local LegacyProviderSession = {}
  LegacyProviderSession.__index = LegacyProviderSession

  function LegacyProviderSession.new(binding, game, adapter, screen)
    legacySessionSerial = legacySessionSerial + 1
    local memory = wideMemory(game).providerLegacy or {}
    return setmetatable({
      contract=binding.contract, hostId=binding.host,
      game=game, adapter=adapter, screen=screen,
      id="kasc-legacy-" .. legacySessionSerial, revision=0,
      focusZone=memory.focusZone or "legacy",
      legacyFocusSlot=memory.legacyFocusSlot or 1,
      partyFocusSlot=memory.partyFocusSlot or 1,
      bankBox=memory.bankBox or 1, bindings={}, selected={},
      clearSelection=binding.clearSelection == true,
    }, LegacyProviderSession)
  end

  function LegacyProviderSession:remember()
    wideMemory(self.game).providerLegacy = {
      focusZone=self.focusZone, legacyFocusSlot=self.legacyFocusSlot,
      partyFocusSlot=self.partyFocusSlot, bankBox=self.bankBox,
    }
  end

  function LegacyProviderSession:rows()
    local ok, rows, err = pcall(self.adapter.rows)
    if not ok or type(rows) ~= "table" then return {}, tostring(err or rows) end
    return rows
  end

  function LegacyProviderSession:boxCount(rows)
    local maximum = 500
    for index, row in ipairs(rows or {}) do
      local slot = math.max(1, math.floor(tonumber(row.bankSlot) or index))
      maximum = math.max(maximum,
        math.floor(tonumber(row.bankBoxCount) or 0), math.ceil(slot / 20))
    end
    return math.max(maximum, math.ceil((#(rows or {}) + 1) / 20))
  end

  function LegacyProviderSession:entryId(zone, box, slot)
    return table.concat({ self.id, zone, tostring(box or 0), tostring(slot) }, ":")
  end

  function LegacyProviderSession:bind(zone, box, slot, mon, row, index)
    local id = self:entryId(zone, box, slot)
    self.bindings[id] = { id=id, zone=zone, box=box, slot=slot,
      mon=mon, row=row, index=index }
    return id
  end

  function LegacyProviderSession:buildModel()
    local rows, rowsErr = self:rows()
    local boxCount = self:boxCount(rows)
    self.bankBox = math.max(1, math.min(boxCount, self.bankBox))
    self.legacyFocusSlot = math.max(1, math.min(20, self.legacyFocusSlot))
    self.partyFocusSlot = math.max(1, math.min(6, self.partyFocusSlot))
    self.bindings = {}
    local legacyEntries, partyEntries = {}, {}
    local selectedIds, withdrawable = {}, 0
    for index, row in ipairs(rows) do
      local global = math.max(1, math.floor(tonumber(row.bankSlot) or index))
      local box, slot = math.ceil(global / 20), ((global - 1) % 20) + 1
      local id = self:bind("legacy", box, slot, row.mon, row, index)
      if self.selected[row.id] then selectedIds[#selectedIds + 1] = id end
      if not row.withdrawBlocked then withdrawable = withdrawable + 1 end
      if box == self.bankBox then
        local tags = row.withdrawBlocked and { "sealed" } or {}
        legacyEntries[#legacyEntries + 1] = {
          id=id, zone="legacy", box=box, slot=slot,
          pokemon=legacyPokemonDescriptor(self.game, row.mon),
          enabled=not row.withdrawBlocked,
          selected=self.selected[row.id] == true,
          reason=row.withdrawBlocked and tostring(row.withdrawReason
            or tr("WITHDRAWAL LOCKED", "ENTNAHME GESPERRT")) or nil,
          tags=tags,
        }
      end
    end
    local party = self.game.save.party or {}
    for slot, mon in ipairs(party) do
      partyEntries[#partyEntries + 1] = {
        id=self:bind("party", nil, slot, mon, nil, slot),
        zone="party", slot=slot,
        pokemon=legacyPokemonDescriptor(self.game, mon),
        enabled=true, selected=false,
      }
    end
    local focusSlot = self.focusZone == "party"
      and self.partyFocusSlot or self.legacyFocusSlot
    local focusBox = self.focusZone == "legacy" and self.bankBox or nil
    local focusId = self:entryId(self.focusZone, focusBox, focusSlot)
    local target = self.bindings[focusId]
    local targetRow = target and target.row or nil
    local targetPokemon = target and legacyPokemonDescriptor(
      self.game, target.mon) or nil
    local targetEgg = targetPokemon and targetPokemon.egg == true
    local inLegacy = target and target.zone == "legacy"
    local inParty = target and target.zone == "party"
    local available = function(enabled, reason)
      return { enabled=enabled and true or false, reason=reason }
    end
    local availability = {
      navigate=available(true),
      inspect=available(target ~= nil and not targetEgg,
        targetEgg and "egg_hidden" or target and nil or "empty_slot"),
      dex_entry=available(target ~= nil and not targetEgg,
        targetEgg and "egg_hidden" or target and nil or "empty_slot"),
      withdraw=available(inLegacy and not targetRow.withdrawBlocked
          and #party < 6,
        targetRow and targetRow.withdrawBlocked and "withdrawal_locked"
          or #party >= 6 and "party_full" or target and nil or "empty_slot"),
      deposit=available(inParty and #party > 1,
        #party <= 1 and "last_party_mon" or target and nil or "empty_slot"),
      move=available(target ~= nil
          and (inParty and #party > 1
            or inLegacy and not targetRow.withdrawBlocked),
        targetRow and targetRow.withdrawBlocked and "withdrawal_locked"
          or inParty and #party <= 1 and "last_party_mon"
          or target and nil or "empty_slot"),
      multi_select=available(inLegacy and not targetRow.withdrawBlocked,
        targetRow and targetRow.withdrawBlocked and "withdrawal_locked"
          or target and nil or "empty_slot"),
      cross_box_select=available(true),
      transfer_selected_to_pc=available(#selectedIds > 0,
        #selectedIds == 0 and "selection_empty" or nil),
      transfer_all_to_pc=available(withdrawable > 0,
        withdrawable == 0 and "no_withdrawable_pokemon" or nil),
      cancel=available(true),
    }
    if self.clearSelection then
      availability.clear_selection=available(#selectedIds > 0,
        #selectedIds == 0 and "selection_empty" or nil)
    end
    local locale = german() and "de" or "en"
    local title = tr("LEGACY BANK", "VERMÄCHTNIS-BANK")
    return {
      schema=self.contract.schemas.model,
      apiVersion=self.contract.apiVersion,
      host=self.hostId, hostGeneration=self.contract.hostGeneration,
      surface="legacy_bank", session=self.id, revision=self.revision,
      locale=locale, edition="red", mode=self.focusZone == "party"
        and "browse_party" or "browse_legacy",
      title=title, help=locale == "de"
        and "A: AKTION  SELECT: TEAM/BANK"
        or "A: ACTION  SELECT: PARTY/BANK",
      message=rowsErr and { text=rowsErr, severity="warning" } or nil,
      focus={ zone=self.focusZone, box=focusBox, slot=focusSlot,
        id=target and focusId or nil },
      selection={ kind="multi_cross_box", ids=selectedIds,
        revision=self.revision },
      zones={
        legacy={ label=Strings("BANK %03d", self.bankBox),
          index=self.bankBox, count=#legacyEntries, capacity=20,
          entries=legacyEntries },
        party={ label=tr("PARTY", "TEAM"), count=#partyEntries,
          capacity=6, entries=partyEntries },
      },
      availability=availability,
      surfaceData={ title=title, currentBox=self.bankBox,
        boxCount=boxCount, boxCapacity=20, partyCapacity=6,
        selectedCount=#selectedIds },
    }
  end

  function LegacyProviderSession:result(envelope, status, code, message)
    if status == "applied" then self.revision = self.revision + 1 end
    self:remember()
    local result = {
      schema=self.contract.schemas.actionResult,
      apiVersion=self.contract.apiVersion,
      host=envelope.host, hostGeneration=envelope.hostGeneration,
      surface=envelope.surface, session=envelope.session,
      action=envelope.action, requestRevision=envelope.modelRevision,
      status=status, code=code,
    }
    if status ~= "closed" then result.model = self:buildModel() end
    if message then result.message = { text=tostring(message),
      severity=status == "rejected" and "warning" or "info" } end
    return result
  end

  function LegacyProviderSession:reject(envelope, code, message)
    return self:result(envelope, "rejected", code, message)
  end

  function LegacyProviderSession:locate(target)
    local binding = type(target) == "table" and self.bindings[target.id] or nil
    if not binding or binding.zone ~= target.zone or binding.box ~= target.box
        or binding.slot ~= target.slot then return nil end
    return binding
  end

  -- KASC's Legacy adapter deliberately consumes one row-shaped value for
  -- both archive and party targets.  Party entries have no archive row, so
  -- preserve that contract instead of handing a bare Pokémon to Status/Dex.
  function LegacyProviderSession:adapterRow(target)
    if not target then return nil end
    if target.row then return target.row end
    if not target.mon then return nil end
    return { id=target.id, mon=target.mon, partyIndex=target.index,
      zone=target.zone }
  end

  function LegacyProviderSession:navigate(envelope)
    local direction = envelope.direction
    if direction == "page_next" or direction == "page_prev" then
      self.focusZone = self.focusZone == "party" and "legacy" or "party"
      return self:result(envelope, "applied", "focus_changed")
    end
    if self.focusZone == "party" then
      if direction == "left" then
        self.partyFocusSlot = math.max(1, self.partyFocusSlot - 1)
      elseif direction == "right" then
        self.partyFocusSlot = math.min(6, self.partyFocusSlot + 1)
      elseif direction == "up" then
        self.focusZone = "legacy"
      elseif direction == "down" then
        self.partyFocusSlot = math.min(6, self.partyFocusSlot + 1)
      end
    else
      local slot, columns = self.legacyFocusSlot, 5
      local row, col = math.floor((slot - 1) / columns), (slot - 1) % columns
      if direction == "left" then col = (col - 1) % columns
      elseif direction == "right" then col = (col + 1) % columns
      elseif direction == "up" then row = (row - 1) % 4
      elseif direction == "down" and row == 3 then
        self.focusZone = "party"
      elseif direction == "down" then row = row + 1 end
      if self.focusZone == "legacy" then
        self.legacyFocusSlot = row * columns + col + 1
      end
    end
    return self:result(envelope, "applied", "focus_changed")
  end

  function LegacyProviderSession:inspect(envelope)
    local target = self:locate(envelope.target)
    if not target or not target.mon then return self:reject(
      envelope, "stale_target") end
    local fn = self.adapter.inspect
    if type(fn) ~= "function" then return self:reject(
      envelope, "inspect_unavailable") end
    local ok, why = fn(self:adapterRow(target))
    if ok == false then return self:reject(envelope, "inspect_failed", why) end
    return self:result(envelope, "applied", "summary_opened")
  end

  function LegacyProviderSession:dexEntry(envelope)
    local target = self:locate(envelope.target)
    if not target or not target.mon then return self:reject(
      envelope, "stale_target") end
    local fn = self.adapter.dexEntry
    if type(fn) ~= "function" then return self:reject(
      envelope, "dex_unavailable") end
    local ok, why = fn(self:adapterRow(target))
    if ok == false then return self:reject(envelope, "dex_failed", why) end
    return self:result(envelope, "applied", "dex_opened")
  end

  function LegacyProviderSession:withdraw(envelope)
    local target = self:locate(envelope.target)
    if not target or target.zone ~= "legacy" or not target.row then
      return self:reject(envelope, "stale_target")
    end
    if target.row.withdrawBlocked then return self:reject(
      envelope, "withdrawal_locked", target.row.withdrawReason) end
    local ok, why = self.adapter.withdraw(target.row)
    return ok and self:result(envelope, "applied", "withdrawn", why)
      or self:reject(envelope, "withdraw_failed", why)
  end

  function LegacyProviderSession:deposit(envelope)
    local target = self:locate(envelope.target)
    if not target or target.zone ~= "party" then
      return self:reject(envelope, "stale_target")
    end
    local global = (self.bankBox - 1) * 20 + self.legacyFocusSlot
    local ok, why = self.adapter.deposit(target.index, global)
    return ok and self:result(envelope, "applied", "deposited", why)
      or self:reject(envelope, "deposit_failed", why)
  end

  function LegacyProviderSession:move(envelope)
    local source = self:locate(envelope.target)
    local destination = envelope.destination
    if not source or not source.mon or type(destination) ~= "table" then
      return self:reject(envelope, "stale_target")
    end
    local ok, why
    if source.zone == "legacy" and destination.zone == "legacy" then
      if source.row.withdrawBlocked then return self:reject(
        envelope, "withdrawal_locked", source.row.withdrawReason) end
      ok, why = self.adapter.move(source.row.id,
        (destination.box - 1) * 20 + destination.slot)
    elseif source.zone == "legacy" and destination.zone == "party" then
      if source.row.withdrawBlocked then return self:reject(
        envelope, "withdrawal_locked", source.row.withdrawReason) end
      ok, why = self.adapter.withdraw(source.row)
    elseif source.zone == "party" and destination.zone == "legacy" then
      if #(self.game.save.party or {}) <= 1 then return self:reject(
        envelope, "last_party_mon") end
      ok, why = self.adapter.deposit(source.index,
        (destination.box - 1) * 20 + destination.slot)
    else
      return self:reject(envelope, "destination_invalid")
    end
    return ok and self:result(envelope, "applied", "moved", why)
      or self:reject(envelope, "move_failed", why)
  end

  function LegacyProviderSession:multiSelect(envelope)
    local target = self:locate(envelope.target)
    if not target or target.zone ~= "legacy" or not target.row then
      return self:reject(envelope, "stale_target")
    end
    if target.row.withdrawBlocked then return self:reject(
      envelope, "withdrawal_locked", target.row.withdrawReason) end
    self.selected[target.row.id] = envelope.selected and true or nil
    return self:result(envelope, "applied", "selection_changed")
  end

  function LegacyProviderSession:crossBox(envelope)
    local rows = self:rows()
    local count = self:boxCount(rows)
    if envelope.boxIndex < 1 or envelope.boxIndex > count then
      return self:reject(envelope, "box_invalid")
    end
    self.bankBox = envelope.boxIndex
    return self:result(envelope, "applied", "box_changed")
  end

  function LegacyProviderSession:transferSelected(envelope)
    local rows = self:rows()
    local selected = {}
    for _, row in ipairs(rows) do
      if self.selected[row.id] then selected[#selected + 1] = row end
    end
    if #selected == 0 then return self:reject(
      envelope, "selection_empty") end
    local fn = self.adapter.transferSelected
    if type(fn) ~= "function" then return self:reject(
      envelope, "transfer_unavailable") end
    local ok, why = fn(selected)
    if ok then self:retainExistingSelection() end
    return ok and self:result(envelope, "applied", "transferred", why)
      or self:reject(envelope, "transfer_failed", why)
  end

  function LegacyProviderSession:transferAll(envelope)
    local fn = self.adapter.transferAll
    if type(fn) ~= "function" then return self:reject(
      envelope, "transfer_unavailable") end
    local ok, why = fn()
    if ok then self:retainExistingSelection() end
    return ok and self:result(envelope, "applied", "transferred", why)
      or self:reject(envelope, "transfer_failed", why)
  end

  function LegacyProviderSession:retainExistingSelection()
    local rows = self:rows()
    local remaining = {}
    for _, row in ipairs(rows) do
      if self.selected[row.id] then remaining[row.id] = true end
    end
    self.selected = remaining
  end

  function LegacyProviderSession:clearSelected(envelope)
    if not self.clearSelection then
      return self:reject(envelope, "clear_selection_unavailable")
    end
    if envelope.modelRevision ~= self.revision
        or envelope.selectionRevision ~= self.revision then
      return self:reject(envelope, "stale_selection")
    end
    self.selected = {}
    return self:result(envelope, "applied", "selection_cleared")
  end

  function LegacyProviderSession:cancel(envelope)
    self.screen.closeAfterInput = true
    return self:result(envelope, "closed", "closed")
  end

  function LegacyProviderSession:actions()
    local actions = {
      navigate=function(e) return self:navigate(e) end,
      inspect=function(e) return self:inspect(e) end,
      dex_entry=function(e) return self:dexEntry(e) end,
      withdraw=function(e) return self:withdraw(e) end,
      deposit=function(e) return self:deposit(e) end,
      move=function(e) return self:move(e) end,
      multi_select=function(e) return self:multiSelect(e) end,
      cross_box_select=function(e) return self:crossBox(e) end,
      transfer_selected_to_pc=function(e) return self:transferSelected(e) end,
      transfer_all_to_pc=function(e) return self:transferAll(e) end,
      cancel=function(e) return self:cancel(e) end,
    }
    if self.clearSelection then
      actions.clear_selection=function(e) return self:clearSelected(e) end
    end
    return actions
  end

  local LegacyProviderScreen = {}
  LegacyProviderScreen.__index = LegacyProviderScreen
  LegacyProviderScreen.isOpaque = true

  function LegacyProviderScreen.new(binding, game, adapter)
    local contract = binding.contract
    local self = setmetatable({ binding=binding, game=game,
      adapter=adapter, letterboxWhite=true }, LegacyProviderScreen)
    self.session = LegacyProviderSession.new(binding, game, adapter, self)
    local called, controller, receipt = pcall(binding.begin, binding, {
      surface="legacy_bank", session=self.session.id,
      controllerGeneration=contract.controllerGeneration, atomicLayer=true,
      model=self.session:buildModel(), actions=self.session:actions(),
      events=copyArray(contract.events),
    })
    if not called then return nil, "host-begin-error:" .. tostring(controller) end
    if not controller then return nil, receipt end
    if type(controller) ~= "table"
        or type(controller.update) ~= "function"
        or type(controller.handleInput) ~= "function"
        or type(controller.isActive) ~= "function"
        or type(controller.draw) ~= "function"
        or type(controller.close) ~= "function" then
      if type(controller) == "table"
          and type(controller.close) == "function" then
        pcall(controller.close, controller, "invalid-controller")
      end
      return nil, "host-begin-invalid-controller"
    end
    if type(receipt) ~= "table" or type(receipt.viewport) ~= "table"
        or tonumber(receipt.viewport.width) == nil
        or tonumber(receipt.viewport.height) == nil then
      if type(controller) == "table" and type(controller.close) == "function" then
        pcall(controller.close, controller, "invalid-session-receipt")
      end
      return nil, "host-begin-invalid-receipt"
    end
    self.controller, self.receipt = controller, receipt
    self.viewport = receipt.viewport
    self.__pokemonUiHostV1={ owner=binding.owner,
      surface="legacy_bank" }
    self.__kascVascLegacyBankHost = true
    return self
  end

  function LegacyProviderScreen:uiSize()
    return self.viewport.width, self.viewport.height
  end
  function LegacyProviderScreen:drawsWidescreen() return true end
  function LegacyProviderScreen:wantsFillScale() return false end
  function LegacyProviderScreen:isWideBattleLayout() return false end
  function LegacyProviderScreen:sgbPalettes()
    local width, height = self:uiSize()
    return { { colors=false, x=0, y=0, w=width, h=height } }
  end

  function LegacyProviderScreen:retireToFallback(reason)
    if self.retired then return end
    self.retired = true
    if self.controller then pcall(self.controller.close, self.controller,
      reason or "provider-fallback") end
    if self.game.stack:top() == self then self.game.stack:pop() end
    if type(self.adapter.openFallback) == "function" then
      self.adapter.openFallback(reason)
    end
  end

  function LegacyProviderScreen:queueFallback(reason)
    if not self.retired and not self.fallbackNext then
      self.fallbackNext = reason or "provider-runtime-fallback"
    end
  end

  function LegacyProviderScreen:update(dt)
    if self.retired then return end
    if self.fallbackNext then
      local reason = self.fallbackNext
      self.fallbackNext = nil
      return self:retireToFallback(reason)
    end
    local called, alive = pcall(self.controller.update, self.controller, dt)
    if not called or alive == false then
      self:queueFallback(called and "provider-update-fallback"
        or "provider-update-error")
      return
    end
    local pressed = {}
    for _, key in ipairs({ "up", "down", "left", "right", "a", "b",
        "start", "select" }) do
      if self.game.input:wasPressed(key) then pressed[key] = true end
    end
    if self.game.input:wasPressed("l") then pressed.page_prev = true end
    if self.game.input:wasPressed("r") then pressed.page_next = true end
    if next(pressed) then
      local inputCalled, handled = pcall(
        self.controller.handleInput, self.controller, { pressed=pressed })
      if not inputCalled then
        self:queueFallback("provider-input-error")
        return
      end
      if handled == false then
        local activeCalled, active = pcall(
          self.controller.isActive, self.controller)
        if not activeCalled or active ~= true then
          self:queueFallback(activeCalled and "provider-inactive"
            or "provider-health-error")
        end
      end
    end
    if self.closeAfterInput then
      self.closeAfterInput = nil
      if self.game.stack:top() == self then self.game.stack:pop() end
    end
  end

  function LegacyProviderScreen:draw()
    if self.retired then return end
    local g = love.graphics
    if not (g and g.newCanvas and g.setCanvas and g.getCanvas
        and g.push and g.pop and g.draw) then
      self:queueFallback("provider-draw-unavailable")
      return
    end
    local width, height = self:uiSize()
    if self.layer and type(self.layer.getDimensions) == "function" then
      local lw, lh = self.layer:getDimensions()
      if lw ~= width or lh ~= height then self.layer = nil end
    end
    if not self.layer then
      local ok, layer = pcall(g.newCanvas, width, height, { dpiscale=1 })
      if not ok or not layer then
        self:queueFallback("provider-layer-error")
        return
      end
      self.layer = layer
      if layer.setFilter then layer:setFilter("nearest", "nearest") end
    end
    local old = g.getCanvas()
    g.push("all")
    g.setCanvas(self.layer)
    if type(g.origin) == "function" then g.origin() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setScissor) == "function" then g.setScissor() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    g.clear(0, 0, 0, 0)
    local ok, complete = pcall(self.controller.draw, self.controller)
    g.pop()
    g.setCanvas(old)
    if not ok or complete ~= true then
      self:queueFallback(ok and "provider-draw-incomplete"
        or "provider-draw-error")
      return
    end
    g.push("all")
    if type(g.origin) == "function" then g.origin() end
    if type(g.setShader) == "function" then g.setShader() end
    if type(g.setScissor) == "function" then g.setScissor() end
    if type(g.setBlendMode) == "function" then g.setBlendMode("alpha") end
    g.setColor(1, 1, 1, 1)
    g.draw(self.layer, 0, 0)
    g.pop()
  end
  LegacyProviderScreen.drawWidescreen = LegacyProviderScreen.draw

  local function newVascLegacyBankScreen(game, adapter)
    if type(legacyBankCard) ~= "table"
        or type(legacyBankCard.binding) ~= "function" then
      return nil, "vasc-legacy-bank-card-unavailable"
    end
    local called, binding, why = pcall(
      legacyBankCard.binding, legacyBankCard)
    if not called then
      return nil, "vasc-legacy-bank-card-error:" .. tostring(binding)
    end
    if type(binding) ~= "table" then return nil, why end
    local contract = binding.contract
    if type(contract) ~= "table" or type(contract.schemas) ~= "table"
        or type(binding.resolve) ~= "function"
        or type(binding.begin) ~= "function" then
      return nil, "vasc-legacy-bank-binding-invalid"
    end
    local ok, resolved, resolveWhy = pcall(binding.resolve, binding)
    local ascBoxId = contract.ids and contract.ids.ascBox or "asc_box"
    if not ok or type(resolved) ~= "table"
        or resolved.effective ~= ascBoxId then
      return nil, not ok and "host-resolve-error:" .. tostring(resolved)
        or type(resolved) == "table" and resolved.reason
        or resolveWhy or "asc-box-not-selected"
    end
    return LegacyProviderScreen.new(binding, game, adapter)
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
    local wideParty = self.__ascendantFireRedWideGrid
      and isPartyGrid(self.title)
    local columns = wideParty and 2 or isPartyGrid(self.title) and 1 or 5
    local col = (self.index - 1) % columns
    if input:wasPressed("left") then
      if not wideParty or col > 0 then
        nextIndex = math.max(1, self.index - 1)
      end
    elseif input:wasPressed("right") then
      if not wideParty or col < columns - 1 then
        nextIndex = math.min(count, self.index + 1)
      end
    elseif input:wasPressed("up") then
      nextIndex = math.max(1, self.index - columns)
    elseif input:wasPressed("down") then
      nextIndex = math.min(count, self.index + columns)
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

  local function wideListMemoryKey(title)
    title = tostring(title or "")
    if isPartyGrid(title) then return "party" end
    if title:find("WITHDRAW", 1, true) or title:find("ABHEBEN", 1, true)
        or title:find("NEHMEN", 1, true) then return "withdraw" end
    if title:find("DEPOSIT", 1, true) or title:find("ABLEGEN", 1, true) then
      return "deposit"
    end
    if title:find("RELEASE", 1, true)
        or title:find("FREILASSEN", 1, true) then return "release" end
    return "storage"
  end

  local okList, ListMenu = pcall(require, "src.ui.ListMenu")
  if okList and ListMenu and not ListMenu.__ascendantFireRedStorage then
    ListMenu.__ascendantFireRedStorage = true
    local newList = ListMenu.new
    ListMenu.new = function(game, title, items, opts)
      local list = newList(game, title, items, opts)
      if isChangeBoxList(title) and useWideFireRedPc(game) then
        list.__ascendantFireRedChangeBox = true
        list.rows = 10
        local memory = wideMemory(game)
        local initial = memory.changeBoxIndex
        if not initial then
          for index, item in ipairs(list.items or {}) do
            if tonumber(item.value) == tonumber(game.save.currentBox) then
              initial = index
              break
            end
          end
        end
        if initial and #(list.items or {}) > 0 then
          list.index = math.max(1, math.min(#list.items, initial))
          list.scroll = math.max(0, math.min(
            math.max(0, #list.items - list.rows), list.index - 1))
        end
        list.uiSize = fireRedWideUiSize
        list.sgbPalettes = fireRedWideTrueColor
        local update = list.update
        if type(update) == "function" then
          list.update = function(self, dt)
            local result = update(self, dt)
            wideMemory(self.game).changeBoxIndex = self.index
            return result
          end
        end
        list.draw = function(self)
          return drawFireRedWideChangeBoxList(self, game)
        end
      elseif (not opts or opts.ascendantStorageGrid ~= false)
          and isBoxList(title) and useCustomPc(game) then
        list.title = localizedBoxTitle(title)
        list.__ascendantBoxGrid = true
        -- Engine RELEASE keeps this ListMenu open after removing the current
        -- item, but the surviving values still refer to the old packed-array
        -- positions. Rebase in the same mutation so the visible preview and
        -- the next destructive action can never address different Pokémon.
        local removeCurrent = list.removeCurrent
        if type(removeCurrent) == "function" then
          list.removeCurrent = function(self, ...)
            local result = removeCurrent(self, ...)
            for index, item in ipairs(self.items or {}) do
              if type(item) == "table" then item.value = index end
            end
            return result
          end
        end
        local wideAtOpen = useWideFireRedPc(game)
        if wideAtOpen then
          list.__ascendantFireRedWideGrid = true
          list.__ascendantWideMemoryKey = wideListMemoryKey(title)
          local remembered = wideMemory(game).lists[list.__ascendantWideMemoryKey]
          if remembered and #list.items > 0 then
            list.index = math.max(1, math.min(#list.items, remembered))
          end
        end
        list.uiSize = function()
          if useWideFireRedPc(game) then return fireRedWideUiSize() end
          if useFireRedPc(game) then return fireRedUiSize() end
          return 160, 144
        end
        list.sgbPalettes = function()
          if useWideFireRedPc(game) then return fireRedWideTrueColor() end
          if useFireRedPc(game) then return fireRedTrueColor() end
          return trueColor()
        end
        list.update = function(self, dt)
          local result = gridUpdate(self, dt)
          if self.__ascendantWideMemoryKey then
            wideMemory(self.game).lists[self.__ascendantWideMemoryKey] =
              self.index
          end
          return result
        end
        list.draw = function(self) drawBoxGrid(self, game) end
      elseif isPcItemList(title) and useFireRedPc(game) then
        list.title = localizedPcItemTitle(title)
        list.rows = useWideFireRedPc(game) and 10 or 4
        list.__ascendantFireRedItemPc = true
        list.__ascendantFireRedWideItemPc = useWideFireRedPc(game) or nil
        if list.__ascendantFireRedWideItemPc then
          list.__ascendantWideMemoryKey = "item:" .. tostring(title)
          local remembered = wideMemory(game).lists[
            list.__ascendantWideMemoryKey]
          if remembered and #list.items > 0 then
            list.index = math.max(1, math.min(#list.items, remembered))
            list.scroll = math.max(0, math.min(
              math.max(0, #list.items - list.rows), list.index - 1))
          end
          local update = list.update
          if type(update) == "function" then
            list.update = function(self, dt)
              local result = update(self, dt)
              wideMemory(self.game).lists[self.__ascendantWideMemoryKey] =
                self.index
              return result
            end
          end
        end
        list.uiSize = useWideFireRedPc(game) and fireRedWideUiSize
          or fireRedUiSize
        list.sgbPalettes = useWideFireRedPc(game) and fireRedWideTrueColor
          or fireRedTrueColor
        list.draw = function(self)
          if useWideFireRedPc(game) then
            return drawFireRedWideItemList(self, game)
          end
          return drawFireRedItemList(self, game)
        end
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
      -- VASC Host-v1 may already own this exact Box open when renderer load
      -- order puts it below KASC. Never decorate/wrap that completed screen a
      -- second time: it has no native BoxMenu item table and owns its own
      -- input, colour and viewport transaction.
      if type(menu) == "table" and type(menu.__pokemonUiHostV1) == "table" then
        return menu
      end
      if not useCustomPc(game) then return menu end
      if useFireRedPc(game) then
        menu.__ascendantFireRedBoxRoot = true
        local changeIndex
        for index, item in ipairs(menu.items or {}) do
          local label = tostring(item.label or "")
          if label:find("CHANGE", 1, true) or label:find("WECHSEL", 1, true) then
            changeIndex = index
            item.keepOpen = true
            item.onSelect = function()
              game.stack:push(newOrganizer(game, true))
            end
            break
          end
        end
        table.insert(menu.items, changeIndex or math.max(1, #menu.items), {
          label = tr("MOVE POKéMON", "POKéMON BEWEGEN"),
          keepOpen = true,
          onSelect = function()
            game.stack:push(newOrganizer(game, false))
          end,
        })
      end
      menu.__ascendantBoxSwitchLegend =
        option(game, "fast_box_switch") ~= false and "L/R BOX" or nil
      if useWideFireRedPc(game) then
        menu.__ascendantFireRedWideBoxRoot = true
        -- This renderer paints the complete 512x288 surface.  Treating it as
        -- a transparent Menu left the native 160x144 terminal/overworld in
        -- the render stack and, on an aspect-ratio change, exposed a stale
        -- fragment in the upper letterbox.  The organizer already uses this
        -- exact ownership contract; the root must do so as well.
        menu.isOpaque = true
        menu.letterboxWhite = true
        local remembered = wideMemory(game).pcRootIndex
        if remembered and #(menu.items or {}) > 0 then
          menu.index = math.max(1, math.min(#menu.items, remembered))
        end
      end
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
          if not useFireRedPc(self.game) and self.game.writeSave then
            self.game:writeSave()
          end
          return
        end
        local result = vanillaUpdate(self, dt)
        if self.__ascendantFireRedWideBoxRoot then
          wideMemory(self.game).pcRootIndex = self.index
        end
        return result
      end
      menu.uiSize = function()
        if useWideFireRedPc(game) then return fireRedWideUiSize() end
        if useFireRedPc(game) then return fireRedUiSize() end
        return 160, 144
      end
      menu.sgbPalettes = function()
        if useWideFireRedPc(game) then return fireRedWideTrueColor() end
        if useFireRedPc(game) then return fireRedTrueColor() end
        return trueColor()
      end
      menu.draw = function(self)
        if useWideFireRedPc(game) then
          drawFireRedWidePcMenu(self, game, false)
          return
        elseif useFireRedPc(game) then
          drawOnGbaCanvas(function()
            drawFireRedBoxShell(game, nil)
            local box = Boxes.active(game.save) or {}
            local previewItems = {}
            for slot = 1, 20 do
              if box[slot] then
                previewItems[#previewItems + 1] = { value = slot }
              end
            end
            drawFireRedBoxMons({ items = previewItems, title = "" },
              game, false)
            drawFireRedBoxHeading(game)
            local step = #(self.items or {}) > 5 and 9 or 10
            drawFireRedActionRows(self.items, self.index, actionLabel, 88, step)
          end)
          color(C.white)
          return
        end

        -- Original Kanto Ascendant presentation. This remains selectable and
        -- is also the hard fallback when the FireRed atlas is unavailable.
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
  -- wrapper replaces only its inherited renderer in the explicit FireRed
  -- pockets mode. KASC SKIN and KASC 999 SKIN must retain ascendant_ui's
  -- established blue/cream Bag instead of being painted over here.
  local mode = bagMode()
  if not mod.exports.externalUsefulBag
      and mode == "pockets" then
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
  local function fireRedPcStackActive(game)
    local states = game and game.stack and game.stack.states or {}
    for index = #states, 1, -1 do
      local state = states[index]
      if state and (state.__ascendantBoxGrid
          or state.__ascendantFireRedPcRoot
          or state.__ascendantFireRedBoxRoot
          or state.__ascendantFireRedOrganizer
          or state.__ascendantFireRedPcOverlay
          or state.__ascendantFireRedItemPc
          or state.__ascendantFireRedChangeBox) then
        return true
      end
      if state and state.isOpaque then break end
    end
    local top = game and game.stack and game.stack.top and game.stack:top()
    return top and (top.__ascendantBoxGrid
      or top.__ascendantFireRedBoxRoot
      or top.__ascendantFireRedOrganizer
      or top.__ascendantFireRedItemPc
      or top.__ascendantFireRedChangeBox) or false
  end

  local function fireRedWideLegacyStackActive(game)
    local states = game and game.stack and game.stack.states or {}
    for index = #states, 1, -1 do
      local state = states[index]
      if state and (state.__ascendantFireRedWideLegacyRoot
          or state.__ascendantWideLegacyBank) then
        return true
      end
      if state and state.isOpaque then break end
    end
    local top = game and game.stack and game.stack.top and game.stack:top()
    return top and (top.__ascendantFireRedWideLegacyRoot
      or top.__ascendantWideLegacyBank) or false
  end

  -- Access messages are created while the terminal root is still on the
  -- stack, before BoxMenu/PlayerPC is pushed. They are not organizer overlays:
  -- treating them as such leaves the 2x PC root visible below a second scaled
  -- classic TextBox. Return the nearest actual owner so that one transition
  -- can stay on the normal 160x144 surface without weakening real Box prompts.
  local function fireRedPcOwner(game)
    local states = game and game.stack and game.stack.states or {}
    for index = #states, 1, -1 do
      local state = states[index]
      if state and state.__ascendantFireRedPcRoot then return "terminal" end
      if state and (state.__ascendantBoxGrid
          or state.__ascendantFireRedBoxRoot
          or state.__ascendantFireRedOrganizer
          or state.__ascendantFireRedPcOverlay
          or state.__ascendantFireRedItemPc
          or state.__ascendantFireRedChangeBox) then
        return "storage"
      end
      if state and state.isOpaque then break end
    end
    return nil
  end

  local function isStorageMonSubmenu(items)
    local sawStats, sawBack, sawAction = false, false, false
    for _, item in ipairs(items or {}) do
      local label = tostring(item.label or "")
      sawStats = sawStats or label:find("STAT", 1, true) ~= nil
      sawBack = sawBack or label:find("CANCEL", 1, true) ~= nil
        or label:find("ZUR", 1, true) ~= nil
      sawAction = sawAction or label:find("WITHDRAW", 1, true) ~= nil
        or label:find("DEPOSIT", 1, true) ~= nil
        or label:find("RELEASE", 1, true) ~= nil
        or label:find("NEHM", 1, true) ~= nil
        or label:find("ABLEG", 1, true) ~= nil
        or label:find("FREIL", 1, true) ~= nil
    end
    return sawStats and sawBack and sawAction
  end

  local okMenu, Menu = pcall(require, "src.ui.Menu")
  if okMenu and Menu and not Menu.__ascendantStorageLabels then
    Menu.__ascendantStorageLabels = true
    local newMenu = Menu.new
    Menu.new = function(game, items, opts)
      local legacyWide = useWideFireRedLegacyBank(game)
        and fireRedWideLegacyStackActive(game)
      local storageSubmenu = ((useFireRedPc(game)
        and fireRedPcStackActive(game)) or legacyWide)
        and isStorageMonSubmenu(items)
      if useCustomPc(game) then
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
      end
      local pcRoot = isPcTerminalRoot(items)
      local playerPc = isPlayerPcRoot(items)
      local menu = newMenu(game, items, opts)
      if storageSubmenu then
        menu.__ascendantFireRedPcOverlay = true
        local wide = legacyWide or useWideFireRedPc(game)
        menu.__ascendantFireRedWidePcOverlay = wide or nil
        menu.__ascendantFireRedWideLegacyOverlay = legacyWide or nil
        menu.uiSize = wide and fireRedWideUiSize or fireRedUiSize
        menu.sgbPalettes = wide and fireRedWideTrueColor or fireRedTrueColor
        menu.draw = function(self)
          if wide then
            panel(349, 44, 153,
              math.min(197, 20 + #(self.items or {}) * 28),
              C.cream, C.blue3)
            for index, item in ipairs(self.items or {}) do
              local y = 57 + (index - 1) * 28
              if index == self.index then
                color(C.gold)
                love.graphics.rectangle("fill", 356, y - 4, 139, 18)
              end
              color(C.ink)
              drawFittedFireRedText(actionLabel(item.label), 374, y, 112)
              if index == self.index then Font.drawCode(Theme.cursor, 360, y) end
            end
            color(C.white)
            return
          end
          drawOnGbaCanvas(function()
            local height = 16 + #(self.items or {}) * 20
            panel(124, 53, 112, height, C.cream, C.blue3)
            for index, item in ipairs(self.items or {}) do
              local y = 63 + (index - 1) * 20
              if index == self.index then
                color(C.gold)
                love.graphics.rectangle("fill", 128, y - 3, 104, 15)
              end
              color(C.ink)
              drawFittedFireRedText(actionLabel(item.label), 140, y, 88)
              if index == self.index then Font.drawCode(Theme.cursor, 130, y) end
            end
          end)
          color(C.white)
        end
      elseif useFireRedPc(game) and (pcRoot or playerPc) then
        menu.__ascendantFireRedPcRoot = true
        local wide = useWideFireRedPc(game)
        menu.__ascendantFireRedWidePcRoot = wide or nil
        if wide then
          -- PlayerPC is also a full-surface WIDE owner, not an overlay over
          -- the bedroom/terminal scene.  Holding the paper letterbox here
          -- prevents the previous native frame from surviving in its bars.
          menu.isOpaque = true
          menu.letterboxWhite = true
          local key = playerPc and "playerPcRootIndex" or "terminalRootIndex"
          menu.__ascendantWideRootMemoryKey = key
          local remembered = wideMemory(game)[key]
          if remembered and #(menu.items or {}) > 0 then
            menu.index = math.max(1, math.min(#menu.items, remembered))
          end
          local update = menu.update
          if type(update) == "function" then
            menu.update = function(self, dt)
              local result = update(self, dt)
              wideMemory(self.game)[self.__ascendantWideRootMemoryKey] = self.index
              return result
            end
          end
        end
        menu.uiSize = wide and fireRedWideUiSize or fireRedUiSize
        menu.sgbPalettes = wide and fireRedWideTrueColor or fireRedTrueColor
        menu.draw = function(self)
          if wide then return drawFireRedWidePcMenu(self, game, playerPc) end
          drawFireRedPcMenu(self, game, playerPc)
        end
      end
      return menu
    end
  end

  -- Non-opaque PC prompts sit over the storage list. Without inheriting the
  -- wide surface, the top prompt made Game:draw shrink the canvas to 160x144
  -- while the list below still rendered at 2x, producing the giant cropped
  -- Pokémon seen behind NEHMEN / STATUS / ZURÜCK.
  local okText, TextBox = pcall(require, "src.render.TextBox")
  if okText and TextBox and not TextBox.__ascendantFireRedPcOverlay then
    TextBox.__ascendantFireRedPcOverlay = true
    local newTextBox = TextBox.new
    TextBox.new = function(game, ...)
      local legacyWide = useWideFireRedLegacyBank(game)
        and fireRedWideLegacyStackActive(game)
      local owner = legacyWide and "legacy-wide"
        or useFireRedPc(game) and fireRedPcOwner(game) or nil
      local wide = owner == "storage" or owner == "legacy-wide"
      local textBox = newTextBox(game, ...)
      if owner == "terminal" then
        -- Hide the terminal menu for its short cartridge access message. The
        -- callback then opens the 480x320 Box surface in one clean transition.
        textBox.isOpaque = true
        textBox.letterboxWhite = true
        textBox.__ascendantFireRedPcAccessPrompt = true
      elseif wide then
        textBox.__ascendantFireRedPcOverlay = true
        local widePc = legacyWide or useWideFireRedPc(game)
        textBox.__ascendantFireRedWidePcOverlay = widePc or nil
        textBox.__ascendantFireRedWideLegacyOverlay = legacyWide or nil
        textBox.uiSize = widePc and fireRedWideUiSize or fireRedUiSize
        textBox.sgbPalettes = widePc and fireRedWideTrueColor
          or fireRedTrueColor
        local drawTextBox = textBox.draw
        textBox.draw = function(self)
          if widePc then
            love.graphics.push()
            love.graphics.translate(96, 0)
            love.graphics.scale(2, 2)
            drawTextBox(self)
            love.graphics.pop()
            return
          end
          drawOnGbaCanvas(function()
            love.graphics.push()
            love.graphics.translate(40, 8)
            drawTextBox(self)
            love.graphics.pop()
          end)
        end
      end
      return textBox
    end
  end

  local okChoice, ChoiceBox = pcall(require, "src.ui.ChoiceBox")
  if okChoice and ChoiceBox and not ChoiceBox.__ascendantFireRedPcOverlay then
    ChoiceBox.__ascendantFireRedPcOverlay = true
    local newChoiceBox = ChoiceBox.new
    ChoiceBox.new = function(game, ...)
      local legacyWide = useWideFireRedLegacyBank(game)
        and fireRedWideLegacyStackActive(game)
      local wide = (useFireRedPc(game) and fireRedPcStackActive(game))
        or legacyWide
      local choice = newChoiceBox(game, ...)
      if wide then
        choice.__ascendantFireRedPcOverlay = true
        local widePc = legacyWide or useWideFireRedPc(game)
        choice.__ascendantFireRedWidePcOverlay = widePc or nil
        choice.__ascendantFireRedWideLegacyOverlay = legacyWide or nil
        choice.uiSize = widePc and fireRedWideUiSize or fireRedUiSize
        choice.sgbPalettes = widePc and fireRedWideTrueColor
          or fireRedTrueColor
        local drawChoice = choice.draw
        choice.draw = function(self)
          if widePc then
            love.graphics.push()
            love.graphics.translate(96, 0)
            love.graphics.scale(2, 2)
            drawChoice(self)
            love.graphics.pop()
            return
          end
          drawOnGbaCanvas(function()
            love.graphics.push()
            love.graphics.translate(40, 8)
            drawChoice(self)
            love.graphics.pop()
          end)
        end
      end
      return choice
    end
  end

  local okQuantity, QuantityBox = pcall(require, "src.ui.QuantityBox")
  if okQuantity and QuantityBox
      and not QuantityBox.__ascendantFireRedPcOverlay then
    QuantityBox.__ascendantFireRedPcOverlay = true
    local newQuantityBox = QuantityBox.new
    QuantityBox.new = function(game, ...)
      local legacyWide = useWideFireRedLegacyBank(game)
        and fireRedWideLegacyStackActive(game)
      local storage = (useFireRedPc(game) and fireRedPcStackActive(game))
        or legacyWide
      local quantity = newQuantityBox(game, ...)
      if storage then
        quantity.__ascendantFireRedPcOverlay = true
        local widePc = legacyWide or useWideFireRedPc(game)
        quantity.__ascendantFireRedWidePcOverlay = widePc or nil
        quantity.__ascendantFireRedWideLegacyOverlay = legacyWide or nil
        quantity.uiSize = widePc and fireRedWideUiSize or fireRedUiSize
        quantity.sgbPalettes = widePc and fireRedWideTrueColor
          or fireRedTrueColor
        local drawQuantity = quantity.draw
        quantity.draw = function(self)
          if widePc then
            love.graphics.push()
            love.graphics.translate(96, 0)
            love.graphics.scale(2, 2)
            drawQuantity(self)
            love.graphics.pop()
            return
          end
          drawOnGbaCanvas(function()
            love.graphics.push()
            love.graphics.translate(40, 8)
            drawQuantity(self)
            love.graphics.pop()
          end)
        end
      end
      return quantity
    end
  end

  -- main.lua installs this factory from its mods.loaded callback, so VASC's
  -- public PokemonUi registry is normally settled now.  Activate the local
  -- consumer Card once here to make ASC BOX immediately discoverable before
  -- the first Bank open. Missing/older VASC and defensive registry errors are
  -- fail-open; binding() keeps the lazy retry for unusual hot-load order.
  if type(legacyBankCard) == "table" then
    if type(legacyBankCard.install) == "function" then
      pcall(legacyBankCard.install, legacyBankCard)
    end
    if type(legacyBankCard.activate) == "function" then
      pcall(legacyBankCard.activate, legacyBankCard)
    end
  end

  local function vascLegacyBankConsumerHealth()
    if type(legacyBankCard) ~= "table"
        or type(legacyBankCard.health) ~= "function" then
      return nil, "vasc-legacy-bank-card-unavailable"
    end
    local called, receipt = pcall(legacyBankCard.health, legacyBankCard)
    if not called or type(receipt) ~= "table" then
      return nil, called and "vasc-legacy-bank-health-invalid"
        or "vasc-legacy-bank-health-error:" .. tostring(receipt)
    end
    return receipt
  end

  mod.exports.modernStorageUi = {
    isBoxList = isBoxList,
    genderSymbol = storageGenderSymbol,
    drawBag = drawBag,
    drawBoxGrid = drawBoxGrid,
    drawAscendantBoxGrid = drawAscendantBoxGrid,
    drawFireRedBoxGrid = drawFireRedBoxGrid,
    drawFireRedWideBoxGrid = drawFireRedWideBoxGrid,
    pcInterfaceStyle = pcInterfaceStyle,
    useFireRedPc = useFireRedPc,
    useWideFireRedPc = useWideFireRedPc,
    useFireRedLegacyBank = useFireRedLegacyBank,
    useWideFireRedLegacyBank = useWideFireRedLegacyBank,
    useCustomPc = useCustomPc,
    pcAtlasPath = PC_ATLAS_PATH,
    wallpaperLabel = wallpaperLabel,
    boxGridSourceDex = boxGridSourceDex,
    boxGridWalkerRelative = boxGridWalkerRelative,
    boxGridWalkerAsset = boxGridWalkerAsset,
    newLegacyBankRoot = newLegacyBankRoot,
    newLegacyBankOrganizer = newLegacyBankOrganizer,
    newVascLegacyBankScreen = newVascLegacyBankScreen,
    vascLegacyBankConsumerHealth = vascLegacyBankConsumerHealth,
  }
end
