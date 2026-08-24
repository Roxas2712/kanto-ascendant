-- Unified, nested in-game configuration for Kanto Ascendant 6.5.
-- Every setting edits the same persisted mod-options bucket as the launcher.

return function(mod, opts)
  opts = opts or {}
  local optionHelp = opts.optionHelp
  local i18n = assert(opts.i18n, "ascendant_features requires i18n")
  local ROOT_ID = "JohtoAscendantFeatures"
  local SCREEN_IDS = {
    storage = "JohtoAscendantStorageOptions",
    sprites = "JohtoAscendantSpriteOptions",
    qol = "JohtoAscendantQolOptions",
    quick = "JohtoAscendantQuickOptions",
    display = "JohtoAscendantDisplayOptions",
    johto = "JohtoAscendantJohtoOptions",
  }

  local function german()
    return i18n.isGerman()
  end

  local function tr(en, de)
    return i18n.text(en, de)
  end

  local toggle = { { true, "ON", "AN" }, { false, "OFF", "AUS" } }
  local groups = {
    storage = {
      titleEn = "BAG / STORAGE", titleDe = "BEUTEL / BOXEN",
      rows = {
        { key = "ascendant_useful_bag", en = "ASCENDANT BAG",
          de = "ASCENDANT-BEUTEL", values = toggle },
        { key = "ascendant_bag_mode", en = "BAG MODE", de = "BEUTEL",
          values = {
            { "off", "OFF / EXTERNAL", "AUS / EXTERN" },
            { "standard", "GAME DEFAULT", "SPIELSTANDARD" },
            { "skin", "KASC SKIN", "KASC-SKIN" },
            { "expanded", "KASC 999 SKIN", "KASC-999-SKIN" },
            { "pockets", "FIRERED 999 POCKETS", "FIRERED-999-FÄCHER" },
          } },
        { key = "pc_interface_style", en = "PC INTERFACE",
          de = "PC-OBERFLÄCHE", values = {
            { "firered", "FIRERED / LEAFGREEN", "FIRERED / LEAFGREEN" },
            { "ascendant", "KANTO ASCENDANT", "KANTO ASCENDANT" },
            { "default", "GAME DEFAULT", "SPIELSTANDARD" },
          } },
        { key = "legacy_bank_interface_style", en = "LEGACY BANK UI",
          de = "VERMÄCHTNIS-BANK", values = {
            { "follow_pc", "FOLLOW PC", "PC FOLGEN" },
            { "firered", "FIRERED / LEAFGREEN", "FIRERED / LEAFGREEN" },
            { "ascendant", "KANTO ASCENDANT", "KANTO ASCENDANT" },
          } },
        { key = "catch_destination", en = "CATCH DEST.", de = "FANGZIEL",
          values = {
            { "ask", "ASK", "FRAGEN" }, { "party", "PARTY", "TEAM" },
            { "box", "BOX", "BOX" }, { "off", "OFF", "AUS" },
          } },
        { key = "catch_box_notice", en = "BOX NOTICE",
          de = "BOX-HINWEIS", values = toggle },
        { key = "box_filter", en = "BOX FILTER", de = "BOX-FILTER",
          values = {
            { "all", "ALL", "ALLE" }, { "kanto", "KANTO", "KANTO" },
            { "johto", "JOHTO", "JOHTO" },
          } },
        { key = "box_grid_icon_style", en = "BOX ICONS",
          de = "BOX-ICONS", values = {
            { "current", "CURRENT", "AKTUELL" },
            { "hgss_walker", "HGSS WALKERS", "HGSS-BEGLEITER" },
          } },
        { key = "fast_box_switch", en = "FAST BOX SWITCH",
          de = "BOX-SCHNELLWECHSEL", values = toggle },
      },
    },
    sprites = {
      titleEn = "SPRITES 001-251", titleDe = "SPRITES 001-251",
      rows = {
        { key = "pokemon_sprite_style", en = "STYLE", de = "STIL",
          values = {
            { "legacy", "AUTO", "AUTO" },
            { "original", "ORIGINAL", "ORIGINAL" },
            { "crystal", "CRYSTAL 2D", "CRYSTAL 2D" },
          } },
        { key = "sprite_style_battle", en = "BATTLE", de = "KAMPF",
          values = toggle },
        { key = "sprite_style_summary", en = "PARTY / STATUS",
          de = "TEAM / STATUS", values = toggle },
        { key = "sprite_style_dex", en = "POKéDEX", de = "POKéDEX",
          values = toggle },
        { key = "sprite_style_box", en = "BOXES", de = "BOXEN",
          values = toggle },
        { key = "sprite_style_scenes", en = "OTHER SCENES",
          de = "ANDERE SZENEN", values = toggle },
        { key = "party_icon_style", en = "PARTY ICONS",
          de = "TEAM-ICONS", values = {
            { "animated", "ANIMATED SPECIES", "ANIMIERTE ARTEN" },
            { "original", "ORIGINAL GEN I", "ORIGINAL GEN I" },
          } },
        { key = "crystal_animation", en = "BATTLE ANIM.",
          de = "KAMPF-ANIM.", values = toggle },
      },
    },
    qol = {
      titleEn = "QUALITY OF LIFE", titleDe = "KOMFORT",
      rows = {
        { key = "ascendant_quick_select", en = "QUICK SELECT",
          de = "SCHNELLWAHL", values = toggle },
        { key = "ascendant_qol", en = "QOL BUNDLE", de = "QOL-PAKET",
          values = toggle },
        { key = "qol_exp_bar", en = "BATTLE EXP BAR",
          de = "KAMPF-EP-LEISTE", values = {
            { "off", "OFF", "AUS" }, { "black", "BLACK", "SCHWARZ" },
            { "blue", "BLUE", "BLAU" },
          } },
        { key = "qol_caught_indicator", en = "CAUGHT ICON",
          de = "GEFANGEN-ICON", values = {
            { "off", "OFF", "AUS" }, { "grey", "GREY", "GRAU" },
            { "red", "RED", "ROT" },
          } },
        { key = "qol_easy_interactions", en = "EASY INTERACT.",
          de = "EINFACHE AKTIONEN", values = toggle },
        { key = "qol_location_banners", en = "AREA BANNER",
          de = "GEBIETSANZEIGE", values = {
            { false, "OFF", "AUS" }, { 1, "1 SEC.", "1 SEK." },
            { 2, "2 SEC.", "2 SEK." }, { 3, "3 SEC.", "3 SEK." },
          } },
        { key = "pokedex_filter", en = "DEX FILTER", de = "DEX-FILTER",
          values = {
            { "all", "ALL", "ALLE" }, { "seen", "SEEN", "GESEHEN" },
            { "owned", "OWNED", "BESITZT" },
          } },
        { key = "text_speed", en = "TEXT SPEED", de = "TEXTTEMPO",
          values = {
            { "engine", "ENGINE", "ENGINE" }, { "fast", "FAST", "SCHNELL" },
            { "normal", "NORMAL", "NORMAL" }, { "slow", "SLOW", "LANGSAM" },
          } },
      },
    },
    quick = {
      titleEn = "QUICK SELECT", titleDe = "SCHNELLWAHL",
      rows = {
        { key = "ascendant_quick_select", en = "QUICK SELECT",
          de = "SCHNELLWAHL", values = toggle },
        { key = "quick_select_tap", en = "DEFAULT FAVORITE",
          de = "START-FAVORIT", values = {
            { "bicycle", "BICYCLE", "FAHRRAD" },
            { "field_kit", "FIELD KIT", "FELD-KIT" },
            { "none", "NOTHING", "NICHTS" },
          } },
        { key = "quick_select_registration", en = "BAG FAVORITE",
          de = "BEUTEL-FAVORIT", values = toggle },
        { key = "quick_select_empty_notice", en = "EMPTY NOTICE",
          de = "LEER-HINWEIS", values = toggle },
        { key = "ride_control", en = "LEGACY BIKE KEY",
          de = "ALTE RAD-TASTE",
          values = {
            { "select", "SELECT", "SELECT" },
            { "classic", "BAG ONLY", "NUR BEUTEL" },
          } },
      },
    },
    display = {
      titleEn = "DISPLAY / SKINS", titleDe = "ANZEIGE / SKINS",
      rows = {
        { key = "modern_storage_ui", en = "MENU SKINS",
          de = "MENÜ-SKINS", values = toggle },
        { key = "character_sprite_style", en = "FIELD CHARACTERS",
          de = "FELD-FIGUREN", values = {
            { "ascendant", "ASCENDANT FIELD", "ASCENDANT-FELD" },
            { "crystal", "KASC FIELD", "KASC-FELD" },
          } },
        { key = "trainer_portrait_style", en = "TRAINER PORTRAITS",
          de = "TRAINER-PORTRÄTS", values = {
            { "crystal_hd", "CRYSTAL HD", "CRYSTAL HD" },
            { "original", "ORIGINAL", "ORIGINAL" },
          } },
        { key = "status_values", en = "STATUS VALUES",
          de = "STATUSWERTE", values = {
            { "off", "OFF", "AUS" },
            { "dv", "DV / IV", "DV / IV" },
            { "full", "DV/IV AND EV", "DV/IV UND EV" },
          } },
        { key = "modern_ball_skins", en = "MODERN BALLS",
          de = "MODERNE BÄLLE", values = toggle },
      },
    },
    johto = {
      titleEn = "JOHTO / SAFETY", titleDe = "JOHTO / SCHUTZ",
      rows = {
        { key = "johto_level_bonus", en = "JOHTO LEVELS",
          de = "JOHTO-LEVEL", values = {
            { "2_8", "PLUS 2 TO 8", "PLUS 2 BIS 8" },
            { "2_5", "PLUS 2 TO 5", "PLUS 2 BIS 5" },
          } },
        { key = "shiny_protection", en = "SHINY RELEASE LOCK",
          de = "SHINY-SCHUTZ", values = toggle },
      },
    },
  }
  local rootRows = {
    { group = "storage", en = "BAG / STORAGE", de = "BEUTEL / BOXEN" },
    { group = "sprites", en = "POKéMON SPRITES", de = "POKéMON-SPRITES" },
    { group = "qol", en = "QUALITY OF LIFE", de = "KOMFORT" },
    { group = "quick", en = "QUICK SELECT", de = "SCHNELLWAHL" },
    { group = "display", en = "DISPLAY / SKINS", de = "ANZEIGE / SKINS" },
    { group = "johto", en = "JOHTO / SAFETY", de = "JOHTO / SCHUTZ" },
    { info = "run_rules", en = "RUN RULES INFO", de = "LAUFREGELN-INFO" },
  }
  local rows = {}
  for _, root in ipairs(rootRows) do
    if root.group then
      for _, row in ipairs(groups[root.group].rows) do rows[#rows + 1] = row end
    end
  end

  local restartKeys = {
    ascendant_useful_bag = true,
    ascendant_bag_mode = true,
    modern_storage_ui = true,
  }
  local bagBundleRows = { ascendant_bag_mode = true }
  local qolBundleRows = {
    qol_exp_bar = true,
    qol_caught_indicator = true,
    qol_easy_interactions = true,
    qol_location_banners = true,
  }

  local function current(game, key)
    local saved = game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    local value = saved and saved[key]
    if value == nil then value = mod.options:get(key) end
    return value
  end

  local function write(game, key, value)
    game.save.options = game.save.options or {}
    game.save.options.modOptions = game.save.options.modOptions or {}
    game.save.options.modOptions[mod.id] =
      game.save.options.modOptions[mod.id] or {}
    game.save.options.modOptions[mod.id][key] = value
    if game.mods then
      game.mods.modOptions = game.mods.modOptions or {}
      game.mods.modOptions[mod.id] = game.mods.modOptions[mod.id] or {}
      game.mods.modOptions[mod.id][key] = value
    end
    if game.writeOptions then game:writeOptions() end
    if game.mods and game.mods.events then
      game.mods.events:emit("mod.options_changed", {
        game = game, mod = mod.id, key = key, value = value,
      })
    end
    if restartKeys[key] then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "This UI change takes\neffect after restart.",
        "Diese UI-Aenderung gilt\nnach einem Neustart.")))
    end
  end

  local function valueIndex(game, row)
    local value = current(game, row.key)
    for index, candidate in ipairs(row.values) do
      if candidate[1] == value then return index end
    end
    return 1
  end

  local function step(game, row, direction)
    local index = valueIndex(game, row)
    index = ((index - 1 + direction) % #row.values) + 1
    write(game, row.key, row.values[index][1])
  end

  local function valueLabel(game, row)
    local entry = row.values[valueIndex(game, row)]
    return entry[german() and 3 or 2]
  end

  local function isPaused(game, row)
    if qolBundleRows[row.key] == true
        and current(game, "ascendant_qol") == false then return true end
    return bagBundleRows[row.key] == true
      and current(game, "ascendant_useful_bag") == false
  end

  local function displayedValue(game, row)
    if isPaused(game, row) then
      return tr("PAUSED", "PAUSIERT")
    end
    return valueLabel(game, row)
  end

  local function openOptionHelp(game, row)
    local value = valueLabel(game, row)
    if isPaused(game, row) then
      value = tr("PAUSED; SAVED: ", "PAUSIERT; GESPEICHERT: ") .. value
    end
    local text
    if optionHelp and type(optionHelp.text) == "function" then
      text = optionHelp.text(row.key, value)
    else
      text = tr("CURRENT: ", "AKTUELL: ") .. value
    end
    game.stack:push(require("src.render.TextBox").new(game, text))
  end

  local function drawFrame(Font, title)
    love.graphics.setColor(.06, .18, .36, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(.18, .52, .82, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 18)
    love.graphics.setColor(1, 1, 1, 1)
    Font.draw(title, 5, 5)
  end

  local function truncate(Font, text, budget)
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

  local function runRulesInfo(game)
    return tr(
      "Randomizer and Nuzlocke\nare configured through\nASC RUN at Oak's Lab\nKASC terminal.",
      "Randomizer und Nuzlocke\nstellst du über ASC-LAUF\nam KASC-Terminal in\nEichs Labor ein.")
  end

  local rootHelp = {
    storage = {
      "Configure the Bag, catch destination and Pokemon storage.",
      "Beutel, Fangziel und Pokemon-Lagerung einstellen.",
    },
    sprites = {
      "Choose Pokemon artwork and where it is used.",
      "Pokemon-Grafik und ihre Einsatzorte waehlen.",
    },
    qol = {
      "Configure convenience helpers, filters and text speed.",
      "Komforthilfen, Filter und Texttempo einstellen.",
    },
    quick = {
      "Configure SELECT shortcuts and bicycle controls.",
      "SELECT-Kuerzel und Fahrradsteuerung einstellen.",
    },
    display = {
      "Choose menu skins and character presentation.",
      "Menue-Skins und Figurenanzeige waehlen.",
    },
    johto = {
      "Configure Johto encounter levels and Shiny protection.",
      "Johto-Level und Shiny-Schutz einstellen.",
    },
  }

  local function openRootHelp(game, row)
    local text
    if row.info == "run_rules" then
      text = runRulesInfo(game)
    else
      local help = rootHelp[row.group]
      text = tr(help[1], help[2])
    end
    game.stack:push(require("src.render.TextBox").new(game, text))
  end

  local function makeSettingsScreen(game, groupKey)
    local Font = require("src.render.Font")
    local Theme = require("src.ui.Theme")
    local group, visible = groups[groupKey], 6
    local screen = {
      game = game, index = 1, scroll = 0, isOpaque = true,
      __ascendantFeatureGroup = groupKey,
    }
    function screen:sgbPalettes() return trueColor() end
    function screen:update()
      local input = self.game.input
      if input:wasPressed("up") then
        self.index = (self.index - 2) % #group.rows + 1
      elseif input:wasPressed("down") then
        self.index = self.index % #group.rows + 1
      elseif input:wasPressed("left") then
        step(self.game, group.rows[self.index], -1)
      elseif input:wasPressed("right") then
        step(self.game, group.rows[self.index], 1)
      elseif input:wasPressed("select") then
        openOptionHelp(self.game, group.rows[self.index])
      elseif input:wasPressed("b") then
        self.game.stack:pop()
      end
      if self.index <= self.scroll then
        self.scroll = self.index - 1
      elseif self.index > self.scroll + visible then
        self.scroll = self.index - visible
      end
    end
    function screen:draw()
      drawFrame(Font, tr(group.titleEn, group.titleDe))
      for slot = 1, visible do
        local index = self.scroll + slot
        local row = group.rows[index]
        if not row then break end
        local y = 20 + (slot - 1) * 18
        love.graphics.setColor(index == self.index
          and .98 or .94, index == self.index and .72 or .91,
          index == self.index and .18 or .76, 1)
        love.graphics.rectangle("fill", 3, y, 154, 16)
        love.graphics.setColor(.06, .12, .20, 1)
        local value = displayedValue(self.game, row)
        local valueX = 153 - Font.width(value)
        Font.draw(truncate(Font, german() and row.de or row.en,
          math.max(24, valueX - 18)), 14, y + 4)
        Font.draw(value, valueX, y + 4)
        if index == self.index then
          Font.drawCode(Theme.cursor, 5, y + 4)
        end
      end
      if self.scroll > 0 then Font.drawCode(Theme.moreArrow, 145, 3) end
      if self.scroll + visible < #group.rows then
        Font.drawCode(Theme.moreArrow, 145, 128)
      end
      love.graphics.setColor(.18, .52, .82, 1)
      love.graphics.rectangle("fill", 0, 130, 160, 14)
      love.graphics.setColor(1, 1, 1, 1)
      Font.draw(tr("L/R:CHG SEL:HELP",
        "L/R:AEND SEL:HILFE"), 5, 133)
    end
    return screen
  end

  local function makeRootScreen(game)
    local Font = require("src.render.Font")
    local Theme = require("src.ui.Theme")
    local screen = {
      game = game, index = 1, scroll = 0, isOpaque = true,
      __ascendantFeatureRoot = true,
    }
    function screen:sgbPalettes() return trueColor() end
    function screen:update()
      local input = self.game.input
      if input:wasPressed("up") then
        self.index = (self.index - 2) % #rootRows + 1
      elseif input:wasPressed("down") then
        self.index = self.index % #rootRows + 1
      elseif input:wasPressed("a") then
        local row = rootRows[self.index]
        if row.info == "run_rules" then
          openRootHelp(self.game, row)
        else
          mod.ui.push(self.game, SCREEN_IDS[row.group])
        end
      elseif input:wasPressed("select") then
        openRootHelp(self.game, rootRows[self.index])
      elseif input:wasPressed("b") then
        self.game.stack:pop()
      end
      if self.index <= self.scroll then
        self.scroll = self.index - 1
      elseif self.index > self.scroll + 5 then
        self.scroll = self.index - 5
      end
    end
    function screen:draw()
      drawFrame(Font, tr("ASCENDANT OPTIONS", "ASCENDANT-OPTIONEN"))
      for slot = 1, 5 do
        local index = self.scroll + slot
        local row = rootRows[index]
        if not row then break end
        local y = 20 + (slot - 1) * 21
        love.graphics.setColor(index == self.index
          and .98 or .94, index == self.index and .72 or .91,
          index == self.index and .18 or .76, 1)
        love.graphics.rectangle("fill", 3, y, 154, 19)
        love.graphics.setColor(.06, .12, .20, 1)
        Font.draw(german() and row.de or row.en, 14, y + 5)
        Font.drawCode(Theme.cursor, 145, y + 5)
        if index == self.index then
          Font.drawCode(Theme.cursor, 5, y + 5)
        end
      end
      if self.scroll > 0 then Font.drawCode(Theme.moreArrow, 145, 3) end
      if self.scroll + 5 < #rootRows then
        Font.drawCode(Theme.moreArrow, 145, 119)
      end
      love.graphics.setColor(.18, .52, .82, 1)
      love.graphics.rectangle("fill", 0, 130, 160, 14)
      love.graphics.setColor(1, 1, 1, 1)
      Font.draw(tr("A:OPEN SEL:HELP",
        "A:AUF SEL:HILFE"), 5, 133)
    end
    return screen
  end

  mod.content.screens:register(ROOT_ID, { new = makeRootScreen })
  for groupKey, screenId in pairs(SCREEN_IDS) do
    local key = groupKey
    mod.content.screens:register(screenId, {
      new = function(game) return makeSettingsScreen(game, key) end,
    })
  end
  mod.exports.ascendantFeaturesScreen = ROOT_ID
  mod.exports.ascendantSpriteScreen = SCREEN_IDS.sprites

  return {
    id = ROOT_ID,
    spriteId = SCREEN_IDS.sprites,
    rows = rows,
    groups = groups,
    runRulesInfo = runRulesInfo,
  }
end
