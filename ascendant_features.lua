-- Unified in-game configuration surface for Kanto Ascendant 6.5 features.
-- The manifest options remain the source of truth; this screen edits the same
-- save/options bucket and therefore stays compatible with the mod manager.

return function(mod)
  local SCREEN_ID = "JohtoAscendantFeatures"

  local function german()
    return mod.find("deutsch") ~= nil
      or mod.find("deutsch-blau") ~= nil
      or mod.find("deutsch-gelb") ~= nil
      or mod.options:get("language") == "de"
  end

  local function tr(en, de)
    return german() and de or en
  end

  local rows = {
    { key = "ascendant_useful_bag", en = "ASC. BAG", de = "ASC. BEUTEL",
      values = { { true, "ON", "AN" }, { false, "OFF", "AUS" } } },
    { key = "modern_storage_ui", en = "FIRERED UI", de = "FIRERED-UI",
      values = { { true, "ON", "AN" }, { false, "OFF", "AUS" } } },
    { key = "ascendant_quick_select", en = "QUICK SELECT", de = "SCHNELLWAHL",
      values = { { true, "ON", "AN" }, { false, "OFF", "AUS" } } },
    { key = "ascendant_qol", en = "QOL BUNDLE", de = "QOL-PAKET",
      values = { { true, "ON", "AN" }, { false, "OFF", "AUS" } } },
    { key = "catch_destination", en = "CATCH DESTINATION", de = "FANGZIEL",
      values = {
        { "ask", "ASK", "FRAGEN" }, { "party", "PARTY", "TEAM" },
        { "box", "BOX", "BOX" }, { "off", "OFF", "AUS" },
      } },
    { key = "pokedex_filter", en = "DEX FILTER", de = "DEX-FILTER",
      values = {
        { "all", "ALL", "ALLE" }, { "seen", "SEEN", "GESEHEN" },
        { "owned", "OWNED", "BESITZT" },
      } },
    { key = "box_filter", en = "BOX FILTER", de = "BOX-FILTER",
      values = {
        { "all", "ALL", "ALLE" }, { "kanto", "KANTO", "KANTO" },
        { "johto", "JOHTO", "JOHTO" },
      } },
    { key = "text_speed", en = "TEXT SPEED", de = "TEXTTEMPO",
      values = {
        { "engine", "ENGINE", "ENGINE" }, { "fast", "FAST", "SCHNELL" },
        { "normal", "NORMAL", "NORMAL" }, { "slow", "SLOW", "LANGSAM" },
      } },
    { key = "ride_control", en = "RIDE CTRL", de = "REITEN",
      values = {
        { "select", "SELECT", "SELECT" }, { "classic", "CLASSIC", "KLASSISCH" },
      } },
    { key = "dex_sprite_style", en = "DEX SPRITES", de = "DEX-SPRITES",
      values = {
        { "original", "ORIGINAL", "ORIGINAL" },
        { "crystal", "CRYSTAL", "CRYSTAL" },
      } },
    { key = "kanto_crystal_art", en = "KANTO CRYSTAL", de = "KANTO-CRYSTAL",
      values = { { true, "ON", "AN" }, { false, "OFF", "AUS" } } },
    { key = "crystal_animation", en = "CRYSTAL ANIM.", de = "CRYSTAL-ANIM.",
      values = { { true, "ON", "AN" }, { false, "OFF", "AUS" } } },
    { key = "johto_level_bonus", en = "JOHTO LEVELS", de = "JOHTO-LEVEL",
      values = {
        { "2_8", "+2..+8", "+2..+8" }, { "2_5", "+2..+5", "+2..+5" },
      } },
    { key = "shiny_protection", en = "SHINY RELEASE LOCK", de = "SHINY-SCHUTZ",
      values = { { true, "ON", "AN" }, { false, "OFF", "AUS" } } },
  }
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
        "Diese UI-Änderung gilt\nnach einem Neustart.")))
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

  local function makeScreen(game)
    local Font = require("src.render.Font")
    local Theme = require("src.ui.Theme")
    local visible = 6
    local screen = {
      game = game, index = 1, scroll = 0, isOpaque = true,
    }

    local function truncate(text, budget)
      text = tostring(text or "")
      if Font.width(text) <= budget then return text end
      local spans = Font.split(text)
      local fit = Font.spansFitting(spans, math.max(0, budget - 8))
      if fit < 1 then return "." end
      return text:sub(1, spans[fit].to) .. "."
    end

    function screen:sgbPalettes()
      local PaletteFX = require("src.render.PaletteFX")
      return { PaletteFX.trueColorZone(0, 0, 19, 17) }
    end

    function screen:update()
      local input = self.game.input
      if input:wasPressed("up") then
        self.index = (self.index - 2) % #rows + 1
      elseif input:wasPressed("down") then
        self.index = self.index % #rows + 1
      elseif input:wasPressed("left") then
        step(self.game, rows[self.index], -1)
      elseif input:wasPressed("right") or input:wasPressed("a") then
        step(self.game, rows[self.index], 1)
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
      love.graphics.setColor(.06, .18, .36, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      love.graphics.setColor(.18, .52, .82, 1)
      love.graphics.rectangle("fill", 0, 0, 160, 18)
      love.graphics.setColor(1, 1, 1, 1)
      Font.draw("JOHTO ASCENDANT FT.", 5, 5)

      for slot = 1, visible do
        local index = self.scroll + slot
        local row = rows[index]
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
        Font.draw(truncate(german() and row.de or row.en,
          math.max(24, valueX - 18)), 14, y + 4)
        Font.draw(value, valueX, y + 4)
        if index == self.index then
          Font.drawCode(Theme.cursor, 5, y + 4)
        end
      end
      if self.scroll > 0 then Font.drawCode(Theme.moreArrow, 145, 3) end
      if self.scroll + visible < #rows then
        Font.drawCode(Theme.moreArrow, 145, 128)
      end
      love.graphics.setColor(.18, .52, .82, 1)
      love.graphics.rectangle("fill", 0, 130, 160, 14)
      love.graphics.setColor(1, 1, 1, 1)
      Font.draw(tr("A/L/R:CHANGE B:BACK", "A/L/R:ÄNDERN B:ZUR."), 5, 133)
    end
    return screen
  end

  mod.content.screens:register(SCREEN_ID, { new = makeScreen })
  mod.exports.ascendantFeaturesScreen = SCREEN_ID

  mod.hooks:wrap("ui.options.rows", function(next, game, optionRows)
    local out = next(game, optionRows)
    if type(out) ~= "table" then return out end
    return mod.ui.insertBefore(out, "MODS", {
      id = "johto_ascendant_features",
      label = "JOHTO ASCENDANT FT.",
      value = function() return tr("CONFIGURE", "EINSTELLEN") end,
      activate = function(g) mod.ui.push(g, SCREEN_ID) end,
    })
  end)

  return { id = SCREEN_ID, rows = rows }
end
