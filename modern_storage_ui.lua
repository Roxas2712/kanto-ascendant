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
    local selected = option(game, "pc_interface_style") or "firered"
    if selected == "default" then return "default" end
    if selected == "ascendant" then return "ascendant" end
    -- A damaged/missing atlas must never leave a half-rendered terminal.
    return pcAtlas() and "firered" or "ascendant"
  end

  local function useFireRedPc(game)
    return pcInterfaceStyle(game) == "firered"
  end

  local function useFireRedLegacyBank(game)
    if option(game, "modern_storage_ui") == false then return false end
    local selected = option(game, "legacy_bank_interface_style")
      or "follow_pc"
    if selected == "ascendant" then return false end
    if selected == "firered" then return pcAtlas() ~= nil end
    return useFireRedPc(game)
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

  local function drawBoxGrid(menu, game)
    if useFireRedPc(game) then
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

  local function organizerSwitchBox(state, direction)
    local count = Boxes.COUNT or #Boxes.ensure(state.game.save)
    state.game.save.currentBox =
      (((state.game.save.currentBox or 1) - 1 + direction) % count) + 1
    state.boxIndex = 1
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

    if carry.zone == targetZone and source == target then
      if targetIndex <= #target then
        target[sourceIndex], target[targetIndex] =
          target[targetIndex], target[sourceIndex]
      elseif targetIndex == #target + 1 then
        local mon = table.remove(target, sourceIndex)
        table.insert(target, mon)
      end
    elseif target[targetIndex] then
      local other = target[targetIndex]
      source[sourceIndex], target[targetIndex] = other, carry.mon
      if targetZone == "party" then ensurePartyStats(state.game, carry.mon) end
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
      table.insert(target, math.min(targetIndex, #target + 1), mon)
      if targetZone == "party" then ensurePartyStats(state.game, mon) end
      if carry.zone == "party" then depositedFollower(state.game, mon) end
    end
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
    local state = {
      game = game, zone = startOnTab and "box_tab" or "box",
      boxIndex = 1, partyIndex = 1, slide = 0,
      isOpaque = true, letterboxWhite = true,
      __ascendantFireRedOrganizer = true,
    }
    state.uiSize = fireRedOrganizerUiSize
    state.sgbPalettes = fireRedOrganizerTrueColor
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
        if input:wasPressed("up") then
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
    return state
  end

  -- Legacy Bank organizer. The archive stays the sole storage authority;
  -- this state only projects its ordered rows onto virtual 20-slot pages.
  -- Five hundred empty pages therefore cost no save space. Page 501 appears
  -- only after slots 1..10000 are occupied, and the same rule keeps extending
  -- the view without an artificial upper bound.
  local function newLegacyBankOrganizer(game, adapter)
    assert(type(adapter) == "table", "Legacy Bank organizer needs an adapter")
    local state = {
      game = game, adapter = adapter, zone = "bank", bankBox = 1,
      bankIndex = 1, partyIndex = 1, rows = {}, slots = {}, slide = 0,
      isOpaque = true, letterboxWhite = true,
      __ascendantFireRedOrganizer = true,
      __ascendantLegacyBankOrganizer = true,
    }
    state.uiSize = fireRedOrganizerUiSize
    state.sgbPalettes = fireRedOrganizerTrueColor

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
        or tr("A:TAKE  SELECT:PARTY", "A:NEHM  SELECT:TEAM"))
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

    local function switchBankBox(self, direction)
      local count = self:boxCount()
      self.bankBox = (((self.bankBox - 1 + direction) % count) + 1)
      self.bankIndex = 1
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
      if input:wasPressed("a") then
        if self.zone == "close" then
          self.carry = nil
          self.game.stack:pop()
        else pickOrDrop(self) end
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
        if input:wasPressed("up") then
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

    state:refresh()
    return state
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
    local columns = isPartyGrid(self.title) and 1 or 5
    if input:wasPressed("left") then
      nextIndex = math.max(1, self.index - 1)
    elseif input:wasPressed("right") then
      nextIndex = math.min(count, self.index + 1)
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

  local okList, ListMenu = pcall(require, "src.ui.ListMenu")
  if okList and ListMenu and not ListMenu.__ascendantFireRedStorage then
    ListMenu.__ascendantFireRedStorage = true
    local newList = ListMenu.new
    ListMenu.new = function(game, title, items, opts)
      local list = newList(game, title, items, opts)
      if (not opts or opts.ascendantStorageGrid ~= false)
          and isBoxList(title) and useCustomPc(game) then
        list.title = localizedBoxTitle(title)
        list.__ascendantBoxGrid = true
        list.uiSize = function()
          if useFireRedPc(game) then return fireRedUiSize() end
          return 160, 144
        end
        list.sgbPalettes = function()
          if useFireRedPc(game) then return fireRedTrueColor() end
          return trueColor()
        end
        list.update = gridUpdate
        list.draw = function(self) drawBoxGrid(self, game) end
      elseif isPcItemList(title) and useFireRedPc(game) then
        list.title = localizedPcItemTitle(title)
        list.rows = 4
        list.__ascendantFireRedItemPc = true
        list.sgbPalettes = trueColor
        list.draw = function(self) drawFireRedItemList(self, game) end
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
        return vanillaUpdate(self, dt)
      end
      menu.uiSize = function()
        if useFireRedPc(game) then return fireRedUiSize() end
        return 160, 144
      end
      menu.sgbPalettes = function()
        if useFireRedPc(game) then return fireRedTrueColor() end
        return trueColor()
      end
      menu.draw = function(self)
        if useFireRedPc(game) then
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
          or state.__ascendantFireRedPcOverlay) then
        return true
      end
      if state and state.isOpaque then break end
    end
    local top = game and game.stack and game.stack.top and game.stack:top()
    return top and (top.__ascendantBoxGrid
      or top.__ascendantFireRedBoxRoot
      or top.__ascendantFireRedOrganizer) or false
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
          or state.__ascendantFireRedPcOverlay) then
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
      local storageSubmenu = useFireRedPc(game)
        and fireRedPcStackActive(game) and isStorageMonSubmenu(items)
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
        menu.uiSize = fireRedUiSize
        menu.sgbPalettes = fireRedTrueColor
        menu.draw = function(self)
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
        menu.uiSize = fireRedUiSize
        menu.sgbPalettes = fireRedTrueColor
        menu.draw = function(self)
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
      local owner = useFireRedPc(game) and fireRedPcOwner(game) or nil
      local wide = owner == "storage"
      local textBox = newTextBox(game, ...)
      if owner == "terminal" then
        -- Hide the terminal menu for its short cartridge access message. The
        -- callback then opens the 480x320 Box surface in one clean transition.
        textBox.isOpaque = true
        textBox.letterboxWhite = true
        textBox.__ascendantFireRedPcAccessPrompt = true
      elseif wide then
        textBox.__ascendantFireRedPcOverlay = true
        textBox.uiSize = fireRedUiSize
        textBox.sgbPalettes = fireRedTrueColor
        local drawTextBox = textBox.draw
        textBox.draw = function(self)
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
      local wide = useFireRedPc(game) and fireRedPcStackActive(game)
      local choice = newChoiceBox(game, ...)
      if wide then
        choice.__ascendantFireRedPcOverlay = true
        choice.uiSize = fireRedUiSize
        choice.sgbPalettes = fireRedTrueColor
        local drawChoice = choice.draw
        choice.draw = function(self)
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

  mod.exports.modernStorageUi = {
    isBoxList = isBoxList,
    genderSymbol = storageGenderSymbol,
    drawBag = drawBag,
    drawBoxGrid = drawBoxGrid,
    drawAscendantBoxGrid = drawAscendantBoxGrid,
    drawFireRedBoxGrid = drawFireRedBoxGrid,
    pcInterfaceStyle = pcInterfaceStyle,
    useFireRedPc = useFireRedPc,
    useFireRedLegacyBank = useFireRedLegacyBank,
    useCustomPc = useCustomPc,
    pcAtlasPath = PC_ATLAS_PATH,
    wallpaperLabel = wallpaperLabel,
    boxGridSourceDex = boxGridSourceDex,
    boxGridWalkerRelative = boxGridWalkerRelative,
    boxGridWalkerAsset = boxGridWalkerAsset,
    newLegacyBankOrganizer = newLegacyBankOrganizer,
  }
end
