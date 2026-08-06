-- Unified, nested in-game configuration for Kanto Ascendant 6.5.
-- Every setting edits the same persisted mod-options bucket as the launcher.

return function(mod)
  local ROOT_ID = "JohtoAscendantFeatures"
  local SCREEN_IDS = {
    storage = "JohtoAscendantStorageOptions",
    sprites = "JohtoAscendantSpriteOptions",
    qol = "JohtoAscendantQolOptions",
    johto = "JohtoAscendantJohtoOptions",
  }

  local function german()
    return mod.find("deutsch") ~= nil
      or mod.find("deutsch-blau") ~= nil
      or mod.find("deutsch-gelb") ~= nil
      or mod.options:get("language") == "de"
  end

  local function tr(en, de)
    return german() and de or en
  end

  local toggle = { { true, "ON", "AN" }, { false, "OFF", "AUS" } }
  local groups = {
    storage = {
      titleEn = "BAG / STORAGE", titleDe = "BEUTEL / BOXEN",
      rows = {
        { key = "ascendant_useful_bag", en = "ASC. BAG", de = "ASC. BEUTEL",
          values = toggle },
        { key = "modern_storage_ui", en = "FIRERED UI", de = "FIRERED-UI",
          values = toggle },
        { key = "catch_destination", en = "CATCH DEST.", de = "FANGZIEL",
          values = {
            { "ask", "ASK", "FRAGEN" }, { "party", "PARTY", "TEAM" },
            { "box", "BOX", "BOX" }, { "off", "OFF", "AUS" },
          } },
        { key = "box_filter", en = "BOX FILTER", de = "BOX-FILTER",
          values = {
            { "all", "ALL", "ALLE" }, { "kanto", "KANTO", "KANTO" },
            { "johto", "JOHTO", "JOHTO" },
          } },
      },
    },
    sprites = {
      titleEn = "SPRITES 001-251", titleDe = "SPRITES 001-251",
      rows = {
        { key = "pokemon_sprite_style", en = "STYLE", de = "STIL",
          values = {
            { "legacy", "AUTO", "AUTO" },
            { "original", "ORIGINAL", "ORIGINAL" },
            { "crystal", "CRYSTAL", "CRYSTAL" },
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
        { key = "ride_control", en = "RIDE CTRL", de = "REITEN",
          values = {
            { "select", "SELECT", "SELECT" },
            { "classic", "CLASSIC", "KLASSISCH" },
          } },
      },
    },
    johto = {
      titleEn = "JOHTO / SAFETY", titleDe = "JOHTO / SCHUTZ",
      rows = {
        { key = "johto_level_bonus", en = "JOHTO LEVELS",
          de = "JOHTO-LEVEL", values = {
            { "2_8", "+2..+8", "+2..+8" },
            { "2_5", "+2..+5", "+2..+5" },
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
    { group = "johto", en = "JOHTO / SAFETY", de = "JOHTO / SCHUTZ" },
  }
  local rows = {}
  for _, root in ipairs(rootRows) do
    for _, row in ipairs(groups[root.group].rows) do rows[#rows + 1] = row end
  end

  local restartKeys = {
    ascendant_useful_bag = true,
    modern_storage_ui = true,
    ascendant_quick_select = true,
    ascendant_qol = true,
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
      elseif input:wasPressed("right") or input:wasPressed("a") then
        step(self.game, group.rows[self.index], 1)
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
        local entry = row.values[valueIndex(self.game, row)]
        local value = entry[german() and 3 or 2]
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
      Font.draw(tr("A/L/R:CHANGE B:BACK", "L/R:AEND. B:ZUR."), 5, 133)
    end
    return screen
  end

  local function makeRootScreen(game)
    local Font = require("src.render.Font")
    local Theme = require("src.ui.Theme")
    local screen = {
      game = game, index = 1, isOpaque = true,
      __ascendantFeatureRoot = true,
    }
    function screen:sgbPalettes() return trueColor() end
    function screen:update()
      local input = self.game.input
      if input:wasPressed("up") then
        self.index = (self.index - 2) % #rootRows + 1
      elseif input:wasPressed("down") then
        self.index = self.index % #rootRows + 1
      elseif input:wasPressed("right") or input:wasPressed("a") then
        mod.ui.push(self.game, SCREEN_IDS[rootRows[self.index].group])
      elseif input:wasPressed("b") then
        self.game.stack:pop()
      end
    end
    function screen:draw()
      drawFrame(Font, "JOHTO ASCENDANT FT.")
      for index, row in ipairs(rootRows) do
        local y = 24 + (index - 1) * 22
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
      love.graphics.setColor(.18, .52, .82, 1)
      love.graphics.rectangle("fill", 0, 130, 160, 14)
      love.graphics.setColor(1, 1, 1, 1)
      Font.draw(tr("A:OPEN  B:BACK", "A:OEFFNEN B:ZUR."), 5, 133)
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

  mod.hooks:wrap("ui.options.rows", function(next, game, optionRows)
    local out = next(game, optionRows)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "MODS", {
      id = "johto_ascendant_features",
      label = "JOHTO ASCENDANT FT.",
      value = function() return tr("CONFIGURE", "EINSTELLEN") end,
      activate = function(g) mod.ui.push(g, ROOT_ID) end,
    })
  end)

  return {
    id = ROOT_ID,
    spriteId = SCREEN_IDS.sprites,
    rows = rows,
    groups = groups,
  }
end
