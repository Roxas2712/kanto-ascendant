-- Bilingual ASCENDANT gateway and editor for the save-local Story Level Cap.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local ascendantUi = opts.ascendantUi
  local controller = assert(opts.controller,
    "story level cap menu requires its controller")
  local M = {}
  local SCREEN_ID = "AscendantStoryLevelCap"
  local MODE_ORDER = { "off", "story", "custom" }
  local GUIDE = table.concat({
    "The Story Level Cap follows the current story milestone. STORY uses the intended cap; CUSTOM lets you tune the current or next milestone; OFF disables it.",
    "Use Left/Right to change a focused value. RESET only removes your saved overrides. Battle and future-version locks are read-only safety boundaries.",
    "Der Story-Level-Cap folgt dem aktuellen Fortschritt. STORY nutzt das vorgesehene Limit; EIGEN ändert den aktuellen oder nächsten Abschnitt; AUS deaktiviert es.",
    "Mit Links/Rechts änderst du den markierten Wert. ZURÜCKSETZEN entfernt nur eigene Vorgaben. Kampf- und Zukunftssperren bleiben schreibgeschützt.",
  }, "\f")

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function german()
    return i18n and type(i18n.isGerman) == "function"
      and i18n.isGerman() or false
  end

  local function summary(game)
    local value = controller.summary(game)
    if german() then
      if value == "CAP: OFF" then return "CAP: AUS" end
      if value == "CAP: NONE" then return "CAP: KEIN ZIEL" end
    end
    return value
  end

  local function modeLabel(value)
    if value == "off" then return tr("OFF", "AUS") end
    if value == "custom" then return tr("CUSTOM", "EIGEN") end
    return "STORY"
  end

  local function stageRight(stage)
    if not stage then return "--" end
    return ("%s LV%d"):format(stage.label, stage.level)
  end

  local function resolved(stage)
    return stage and controller.levelForStage(stage) or nil
  end

  function M.rows(game)
    local current = controller.currentStage(game)
    local upcoming = controller.upcomingStage(game)
    local locked = not controller.canEdit()
    return {
      { label = summary(game), key = "summary",
        right = locked and tr("LOCKED", "GESP.") or nil,
        help = tr("Shows the effective cap for the current milestone.",
          "Zeigt das wirksame Limit des aktuellen Abschnitts.") },
      { label = tr("MODE", "MODUS"), key = "mode",
        right = modeLabel(controller.mode()),
        help = tr("STORY follows progression; CUSTOM allows overrides; OFF disables the cap.",
          "STORY folgt dem Fortschritt; EIGEN erlaubt Vorgaben; AUS deaktiviert das Limit.") },
      { label = tr("CURRENT", "AKTUELL"), key = "current",
        stage = current, right = stageRight(resolved(current)),
        help = tr("Current story milestone and its effective level.",
          "Aktueller Story-Abschnitt und sein wirksames Level.") },
      { label = tr("UPCOMING", "NÄCHSTE"), key = "upcoming",
        stage = upcoming, right = stageRight(resolved(upcoming)),
        help = tr("Next known milestone; editable only in CUSTOM mode.",
          "Nächster bekannter Abschnitt; nur im Modus EIGEN änderbar.") },
      { label = tr("RESET CURRENT", "AKTUELL ZURÜCK"),
        key = "reset_current", stage = current,
        help = tr("Remove only the current milestone override.",
          "Entfernt nur die Vorgabe des aktuellen Abschnitts.") },
      { label = tr("RESET ALL", "ALLE ZURÜCKSETZEN"), key = "reset_all",
        help = tr("Remove every custom cap override; story progress is untouched.",
          "Entfernt alle eigenen Limits; der Story-Fortschritt bleibt erhalten.") },
      { label = tr("BACK", "ZURÜCK"), key = "back",
        help = tr("Return without changing another value.",
          "Zurück, ohne einen weiteren Wert zu ändern.") },
    }
  end

  function M.adjust(game, item, direction)
    if not (item and controller.canEdit()) then return false end
    direction = direction < 0 and -1 or 1
    if item.key == "mode" then
      local current = controller.mode()
      local index = 1
      for i, value in ipairs(MODE_ORDER) do
        if value == current then index = i break end
      end
      index = (index - 1 + direction) % #MODE_ORDER + 1
      return controller.setMode(MODE_ORDER[index])
    end
    if (item.key ~= "current" and item.key ~= "upcoming")
        or controller.mode() ~= "custom" or not item.stage then
      return false
    end
    local stage = resolved(item.stage)
    if not stage then return false end
    local level = math.max(1, math.min(100, stage.level + direction))
    return controller.setOverride(item.stage.id, level)
  end

  function M.activate(game, item)
    if not item then return false end
    if item.key == "mode" or item.key == "current"
        or item.key == "upcoming" then
      return M.adjust(game, item, 1)
    end
    if not controller.canEdit() then return false end
    if item.key == "reset_current" then
      local stage = item.stage or controller.currentStage(game)
      return stage and controller.resetOverride(stage.id) or false
    end
    if item.key == "reset_all" then return controller.resetAll() end
    return false
  end

  local function closeTop(game, menu)
    local stack = game and game.stack
    if stack and type(stack.top) == "function" and stack:top() == menu
        and type(stack.pop) == "function" then
      stack:pop()
    elseif menu and type(menu.close) == "function" then
      menu:close()
    end
  end

  local function refresh(game, menu)
    local index = math.max(1, tonumber(menu.index) or 1)
    menu.items = M.rows(game)
    if menu.__kascGuidedHelpRow then
      menu.items[#menu.items + 1] = menu.__kascGuidedHelpRow
    end
    menu.index = math.min(index, #menu.items)
  end

  function M.new(game)
    local ListMenu = mod.ui.KantoListMenu or mod.ui.ListMenu
    local menu
    local title = tr("STORY LEVEL CAP", "STORY-LEVEL-CAP")
    local menuOpts = {
        pageJump = false,
        footer = tr("L/R:CHANGE A:SELECT B:BACK",
          "L/R:ÄNDERN A:WAHL B:ZURÜCK"),
        onCancel = function() closeTop(game, menu) end,
        onChoose = function(item)
          if item and item.key == "back" then
            closeTop(game, menu)
            return
          end
          M.activate(game, item)
          refresh(game, menu)
        end,
      }
    if ascendantUi and type(ascendantUi.guidedList) == "function" then
      menu = ascendantUi.guidedList(game, {
        key = "story-level-cap", title = title,
        helpTitle = tr("LEVEL CAP HELP", "LEVEL-CAP-HILFE"),
        help = GUIDE, rows = M.rows(game), options = menuOpts,
        footer = tr("L/R:CHANGE A:SELECT SEL:HELP",
          "L/R:ÄNDERN A:WAHL SEL:HILFE"),
      })
    else
      menu = ListMenu.new(game, title, M.rows(game), menuOpts)
    end
    local baseUpdate = menu.update
    if type(baseUpdate) == "function" then
      menu.update = function(self, dt)
        local input = game and game.input
        if input and type(input.wasPressed) == "function" then
          if input:wasPressed("left") then
            M.adjust(game, self.items[self.index], -1)
            refresh(game, self)
            return
          elseif input:wasPressed("right") then
            M.adjust(game, self.items[self.index], 1)
            refresh(game, self)
            return
          end
        end
        return baseUpdate(self, dt)
      end
    end
    return menu
  end

  function M.open(game)
    local menu = M.new(game)
    game.stack:push(menu)
    return menu
  end

  if mod.content and mod.content.screens
      and type(mod.content.screens.register) == "function" then
    mod.content.screens:register(SCREEN_ID, {
      new = function(game) return M.new(game) end,
    })
  end

  M.summary = summary
  M.SCREEN_ID = SCREEN_ID
  return M
end
