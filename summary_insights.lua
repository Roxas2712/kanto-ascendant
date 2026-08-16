-- Optional modern status skin plus a third Gen-I potential page.
--
-- Generation I stores four 0..15 DVs (the direct predecessor of IVs), with
-- HP derived from their low bits. Its EV equivalent is per-stat Stat Exp
-- (0..65535). We name both concepts on-screen so players do not mistake the
-- values for the later 31-IV / 252-EV ranges.

return function(mod)
  local ok, SummaryMenu = pcall(require, "src.ui.SummaryMenu")
  if not ok or type(SummaryMenu) ~= "table" then return end

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

  local function valuesMode(game)
    return option(game, "status_values") or "off"
  end

  local function modern(game)
    return option(game, "modern_storage_ui") ~= false
  end

  local C = {
    ink = { .05, .10, .17, 1 },
    navy = { .07, .20, .40, 1 },
    blue = { .20, .53, .82, 1 },
    aqua = { .55, .90, .82, 1 },
    cream = { 1.00, .97, .80, 1 },
    gold = { 1.00, .77, .20, 1 },
    coral = { .94, .48, .35, 1 },
    white = { 1, 1, 1, 1 },
  }

  local function color(c, alpha)
    love.graphics.setColor(c[1], c[2], c[3], alpha or c[4])
  end

  local function panel(x, y, w, h, fill, border)
    color(fill)
    love.graphics.rectangle("fill", x, y, w, h)
    color(border or C.navy)
    love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1)
  end

  local function modernOverlay(game, page)
    if not modern(game) then return end
    -- Never tint engine-owned rows after they have been rendered. The old
    -- translucent fills became light-blue bars across names, HP rows and
    -- other overlays. A border keeps the skin cue without covering content.
    color(page == 1 and C.coral or C.gold, .18)
    love.graphics.rectangle("line", .5, .5, 159, 143)
    require("src.render.PaletteFX").markTrueColor(0, 0, 160, 144)
    love.graphics.setColor(1, 1, 1, 1)
  end

  local STAT_ROWS = {
    { "HP", "hp" },
    { "ATTACK", "attack" },
    { "DEFENSE", "defense" },
    { "SPEED", "speed" },
    { "SPECIAL", "special" },
  }
  local COMPACT_STAT = {
    hp = { "HP", "KP" },
    attack = { "ATK", "ANG" },
    defense = { "DEF", "VER" },
    speed = { "SPD", "INI" },
    special = { "SPC", "SPE" },
  }

  local function drawValues(screen)
    local Font = require("src.render.Font")
    local mode, mon = valuesMode(screen.game), screen.mon
    local dvs, evs = mon.dvs or {}, mon.statExp or {}

    if modern(screen.game) then
      color(C.navy)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      color(C.blue)
      love.graphics.rectangle("fill", 0, 0, 160, 18)
      panel(4, 22, 152, 100, C.cream, C.blue)
      color(C.gold)
      love.graphics.rectangle("fill", 4, 125, 152, 15)
    else
      color(C.white)
      love.graphics.rectangle("fill", 0, 0, 160, 144)
      color(C.ink)
      love.graphics.rectangle("line", .5, .5, 159, 143)
    end

    color(modern(screen.game) and C.white or C.ink)
    Font.draw(tr("VALUES", "WERTE"), 6, 5)
    color(C.ink)
    Font.draw(mon.nickname
      or (screen.game.data.pokemon[mon.species] or {}).name
      or mon.species, 80, 5)
    Font.draw("STAT", 8, 27)
    Font.draw("DV/IV", 56, 27)
    if mode == "full" then Font.draw("EXP/EV", 108, 27) end

    for index, row in ipairs(STAT_ROWS) do
      local y = 42 + (index - 1) * 15
      if index % 2 == 0 and modern(screen.game) then
        color(C.aqua, .28)
        love.graphics.rectangle("fill", 6, y - 3, 148, 14)
      end
      color(C.ink)
      local label = COMPACT_STAT[row[2]]
      Font.draw(tr(label[1], label[2]), 8, y)
      Font.draw(("%2d/15"):format(tonumber(dvs[row[2]]) or 0), 56, y)
      if mode == "full" then
        Font.draw(("%5d"):format(math.max(0,
          math.min(65535, tonumber(evs[row[2]]) or 0))), 112, y)
      end
    end

    color(C.ink)
    Font.draw(tr("DV/IV  STAT EXP/EV",
      "DV/IV  STAT-EP/EV"), 8, 128)
    require("src.render.PaletteFX").markTrueColor(0, 0, 160, 144)
    love.graphics.setColor(1, 1, 1, 1)
  end

  SummaryMenu._ascendantInsightsBridge =
    SummaryMenu._ascendantInsightsBridge or {}
  SummaryMenu._ascendantInsightsBridge.valuesMode = valuesMode
  SummaryMenu._ascendantInsightsBridge.drawValues = drawValues
  SummaryMenu._ascendantInsightsBridge.modernOverlay = modernOverlay

  if not SummaryMenu.__ascendantInsights then
    SummaryMenu.__ascendantInsights = true
    local originalUpdate = SummaryMenu.update
    local originalDraw = SummaryMenu.draw

    SummaryMenu.update = function(self, dt)
      local bridge = SummaryMenu._ascendantInsightsBridge
      if bridge and bridge.valuesMode(self.game) ~= "off" then
        local input = self.game.input
        if input:wasPressed("a") or input:wasPressed("b") then
          if self.page < 3 then self.page = self.page + 1
          else self.game.stack:pop() end
        end
        return
      end
      return originalUpdate(self, dt)
    end

    SummaryMenu.draw = function(self)
      local bridge = SummaryMenu._ascendantInsightsBridge
      if self.page == 3 and bridge
          and bridge.valuesMode(self.game) ~= "off" then
        return bridge.drawValues(self)
      end
      originalDraw(self)
      if bridge then bridge.modernOverlay(self.game, self.page) end
    end
  end

  local okParty, PartyMenu = pcall(require, "src.ui.PartyMenu")
  if okParty and PartyMenu and not PartyMenu.__ascendantModernSkin then
    PartyMenu.__ascendantModernSkin = true
    local originalPartyDraw = PartyMenu.draw
    PartyMenu.draw = function(self)
      originalPartyDraw(self)
      if not modern(self.game) then return end
      color(C.coral, .20)
      love.graphics.rectangle("line", .5, .5, 159, 143)
      require("src.render.PaletteFX").markTrueColor(0, 0, 160, 144)
      love.graphics.setColor(1, 1, 1, 1)
    end
  end

  mod.exports.summaryInsights = {
    valuesMode = valuesMode,
    statRows = STAT_ROWS,
  }
end
