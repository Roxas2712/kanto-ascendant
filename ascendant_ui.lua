-- Shared FireRed-inspired presentation for every Kanto Ascendant list.
--
-- This is deliberately a view layer: ListMenu keeps ownership of input,
-- callbacks, scrolling and compatibility hooks.  Ascendant only replaces
-- its drawing and row budget so every feature screen speaks one UI language.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local Font = require("src.render.Font")
  local Strings = require("src.core.Strings")
  local Theme = require("src.ui.Theme")
  local PaletteFX = require("src.render.PaletteFX")

  local U = {}
  U.colors = {
    ink = { 0.08, 0.12, 0.19, 1 },
    -- Navy VASC/ORAS shell. The Gen-I bitmap font is black-only, therefore
    -- text remains on cool light plaques instead of the former parchment
    -- fills. No transition frame should flash the old yellow menu palette.
    paper = { 0.025, 0.075, 0.14, 1 },
    paper2 = { 0.82, 0.89, 0.96, 1 },
    cream = { 0.94, 0.97, 1.00, 1 },
    blue = { 0.12, 0.35, 0.65, 1 },
    blue2 = { 0.24, 0.55, 0.82, 1 },
    blue3 = { 0.07, 0.20, 0.40, 1 },
    orange = { 0.90, 0.45, 0.12, 1 },
    gold = { 0.55, 0.80, 1.00, 1 },
    red = { 0.78, 0.20, 0.22, 1 },
    white = { 1, 1, 1, 1 },
  }

  local C = U.colors
  local function color(value)
    love.graphics.setColor(value[1], value[2], value[3], value[4])
  end

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function text(value)
    if type(value) == "string" then return value end
    if value == nil then return "" end
    local ok, resolved = pcall(Strings, value)
    return ok and resolved or tostring(value)
  end

  local function truncate(value, budget)
    value = text(value):gsub("\n.*$", "")
    if Font.width(value) <= budget then return value end
    local spans = Font.split(value)
    local fit = Font.spansFitting(spans, math.max(0, budget - 8))
    if fit < 1 then return "." end
    return value:sub(1, spans[fit].to) .. "."
  end

  local function panel(x, y, w, h, fill, border)
    color(fill)
    love.graphics.rectangle("fill", x, y, w, h)
    color(border or C.blue3)
    love.graphics.rectangle("line", x + .5, y + .5, w - 1, h - 1)
  end

  local function wrapLines(value, budget)
    local lines = {}
    value = text(value)
    for paragraph in (value .. "\n"):gmatch("(.-)\n") do
      if paragraph == "" then
        lines[#lines + 1] = ""
      else
        local remaining = paragraph
        while remaining ~= "" do
          local spans = Font.split(remaining)
          local fit = Font.spansFitting(spans, budget)
          if fit >= #spans then
            lines[#lines + 1] = remaining
            break
          end
          fit = math.max(1, fit)
          local cut = spans[fit].to
          for index = fit, 1, -1 do
            if remaining:sub(spans[index].from, spans[index].to) == " " then
              cut = spans[index].to
              break
            end
          end
          lines[#lines + 1] = remaining:sub(1, cut):gsub("%s+$", "")
          remaining = remaining:sub(cut + 1):gsub("^%s+", "")
        end
      end
    end
    if lines[#lines] == "" then lines[#lines] = nil end
    return lines
  end

  -- Full-screen knowledge-test presentation shared by the Johto League and
  -- Hidden Evolution.  The native ListMenu remains the sole input/callback
  -- owner; this seam only adds the large, repeated question panel and an
  -- optional countdown. HEVO and Johto share the Kanto Ascendant FireRed
  -- question treatment while their controllers retain separate consequences.
  local function questionLines(value, budget, maxLines)
    local lines = wrapLines(value, budget)
    if #lines <= maxLines then return lines end
    local out = {}
    for index = 1, maxLines do out[index] = lines[index] end
    out[maxLines] = out[maxLines]:gsub("[%. ]*$", "") .. "."
    return out
  end

  function U.armQuestionMenu(game, menu, spec)
    assert(type(menu) == "table", "KASC question menu must be an inspectable screen")
    spec = assert(spec, "KASC question menu spec missing")
    local prompt = assert(spec.prompt, "KASC question prompt missing")
    local baseUpdate = menu.update
    local seconds = tonumber(spec.seconds)
    if seconds then seconds = math.max(0, seconds) end
    local legacyJohto = spec.legacyJohto == true
    local cancelDisabled = spec.cancelDisabled == true

    menu.isOpaque = true
    local answerRows = math.max(1, math.min(3, #(menu.items or {})))
    menu.rows = answerRows
    menu.kascQuestionPrompt = prompt
    menu.kascQuestionPromptVisible = true
    menu.kascQuestionCountdownVisible = seconds ~= nil
    menu.kascQuestionSeconds = seconds
    menu.kascQuestionElapsed = 0
    menu.kascQuestionRemaining = seconds
    menu.kascQuestionResolved = false
    menu.kascQuestionCancelDisabled = cancelDisabled
    menu.kascQuestionStyle = "firered-question"
    menu.__kantoAscendantLayout = true
    menu.__kantoAscendantStyle = menu.kascQuestionStyle
    -- The answer phase is not cancellable, so the shared ORAS footer must
    -- never advertise B/BACK even though the native ListMenu still owns the
    -- cursor and A callback underneath this presentation.
    menu.footer = tr("A:SELECT", "A:WAHL")
    local questionPalettes = function()
      return { PaletteFX.trueColorZone(0, 0, 19, 17) }
    end
    local vascReceipt = rawget(menu, "__vascKascMenuSkinBridge")
    local vascQuestion = type(vascReceipt) == "table"
      and vascReceipt.schema == "voxel-ascendant/kasc-menu-skin/v1"
      and type(vascReceipt.fire) == "table"
      and type(vascReceipt.oras) == "table"
    menu.kascQuestionOrasFullscreen = vascQuestion
    if vascQuestion then
      -- VASC installed a live FireRed/ORAS multiplexer around this exact
      -- controller. Keep that wrapper intact: only replace its FireRed draw
      -- slot with the semantic question view. The ORAS slot remains the
      -- responsive 512x288 focus/help composition selected by the player.
      vascReceipt.fire.rows = answerRows
      vascReceipt.fire.style = menu.kascQuestionStyle
      vascReceipt.fire.sgbPalettes = questionPalettes
    else
      menu.sgbPalettes = questionPalettes
    end

    local function syncLegacy(self)
      if not legacyJohto then return end
      self.johtoPrompt = self.kascQuestionPrompt
      self.johtoPromptVisible = self.kascQuestionPromptVisible
      self.johtoCountdownVisible = self.kascQuestionCountdownVisible
      self.johtoSeconds = self.kascQuestionSeconds
      self.johtoElapsed = self.kascQuestionElapsed
      self.johtoRemaining = self.kascQuestionRemaining
      self.johtoResolved = self.kascQuestionResolved or self.johtoResolved == true
    end
    local function resolved(self)
      return self.kascQuestionResolved == true
        or (legacyJohto and self.johtoResolved == true)
    end
    local function setResolved(self)
      self.kascQuestionResolved = true
      if legacyJohto then self.johtoResolved = true end
      syncLegacy(self)
    end
    local function closeCurrent()
      if menu.close then return menu:close() end
      if game and game.stack and game.stack.top
          and game.stack:top() == menu then return game.stack:pop() end
    end
    menu.resolveQuestion = setResolved
    menu.closeQuestion = closeCurrent
    syncLegacy(menu)

    menu.update = function(self, dt)
      if resolved(self) then return end
      if seconds ~= nil then
        self.kascQuestionElapsed = self.kascQuestionElapsed
          + math.max(0, tonumber(dt) or 0)
        self.kascQuestionRemaining = math.max(0,
          seconds - self.kascQuestionElapsed)
        syncLegacy(self)
        -- Timeout wins at the exact boundary, matching the released Johto
        -- trial and preventing a same-frame answer after time has expired.
        if self.kascQuestionElapsed >= seconds then
          setResolved(self)
          closeCurrent()
          return spec.onTimeout and spec.onTimeout()
        end
      end
      -- The answer phase is deliberately modal.  Native ListMenu handles B
      -- by popping itself before onCancel, so consume that input here while
      -- leaving the receipt, cursor and running countdown untouched.
      local input = game and game.input
      if cancelDisabled and input and type(input.wasPressed) == "function"
          and input:wasPressed("b") then
        syncLegacy(self)
        return
      end
      if baseUpdate then
        local result = baseUpdate(self, dt)
        syncLegacy(self)
        return result
      end
    end

    local function drawQuestion(self)
      if not (love and love.graphics) then return end
      local g = love.graphics
      local remaining = math.max(0, math.ceil(self.kascQuestionRemaining or 0))
      local timer = tr(("TIME %02ds"):format(remaining),
        ("ZEIT %02ds"):format(remaining))
      -- Same visual grammar as the released Ascendant root/options screen.
      -- HEVO and, by player request, Johto share this question presentation;
      -- their answer consequences remain owned by their route controllers.
      color(C.paper);g.rectangle("fill", 0, 0, 160, 144)
      color(C.blue3);g.rectangle("fill", 0, 0, 160, 27)
      color(C.blue2);g.rectangle("fill", 0, 25, 160, 3)
      color(C.orange);g.rectangle("fill", 0, 0, 8, 27)
      color(C.red);g.rectangle("fill", 0, 24, 8, 4)
      -- The Gen-I tile font is intrinsically black; setColor cannot tint it.
      -- Light plaques keep title/timer legible without a font shader hack.
      panel(10, 1, 147, 12, C.cream, C.blue2)
      color(C.ink)
      Font.draw(tostring(spec.title or tr("KNOWLEDGE TEST", "WISSENSPRÜFUNG")), 12, 3)
      if self.kascQuestionCountdownVisible then
        local timerWidth=Font.width(timer)
        local timerX=154-timerWidth
        panel(timerX-2, 14, timerWidth+5, 10, C.paper2, C.orange)
        color(C.ink);Font.draw(timer, timerX, 15)
      end
      panel(3, 30, 154, 46, C.cream, C.blue3)
      color(C.ink)
      local promptRows = questionLines(self.kascQuestionPrompt, 144, 4)
      self.kascQuestionPromptLines = promptRows
      if legacyJohto then self.johtoPromptLines = promptRows end
      for index, line in ipairs(promptRows) do
        Font.draw(line, 8, 34 + (index - 1) * 10)
      end
      panel(3, 79, 154, 45, C.cream, C.blue3)
      local count = math.min(3, #(self.items or {}))
      local startY, spacing = count == 2 and 87 or 83,
        count == 2 and 20 or 14
      for index = 1, count do
        local item = self.items[index]
        local y = startY + (index - 1) * spacing
        if self.index == index then
          color(C.gold);g.rectangle("fill", 6, y - 2, 148, 14)
          color(C.orange);g.rectangle("fill", 6, y + 10, 148, 2)
        end
        color(C.ink)
        if self.index == index then Font.drawCode(Theme.cursor, 7, y) end
        local answerRows = questionLines(item.label, 144, 2)
        for lineIndex, line in ipairs(answerRows) do
          Font.draw(line, 15, y + (lineIndex - 1) * 8)
        end
      end
      color(C.blue);g.rectangle("fill", 3, 126, 154, 16)
      panel(4, 128, 152, 13, C.paper2, C.blue3)
      color(C.orange);g.rectangle("fill", 5, 129, 150, 2)
      color(C.ink);Font.draw(tr("A:SELECT", "A:WAHL"), 7, 132)
      g.setColor(1, 1, 1, 1)
    end
    if vascQuestion then
      vascReceipt.fire.draw = drawQuestion
    else
      menu.draw = drawQuestion
    end
    return menu
  end

  local HelpPopup = {}
  HelpPopup.__index = HelpPopup
  HelpPopup.isOpaque = false
  local HELP_LINES_PER_PAGE = 7
  -- KASC-66-BILINGUAL-HELP-PRESENTATION: session-local acknowledgement only.
  -- A new game object (including reload) receives the guide again; no save
  -- bucket or option is written by this presentation owner.
  local guidedHelpSeen = setmetatable({}, { __mode = "k" })

  function HelpPopup.new(game, title, body)
    -- Use nearly the full screen instead of scaling the bitmap font: fractional
    -- scaling drops strokes from the 8x8 glyphs and is visibly less readable.
    local lines = wrapLines(body, 144)
    local pages = {}
    for index, line in ipairs(lines) do
      local page = math.floor((index - 1) / HELP_LINES_PER_PAGE) + 1
      pages[page] = pages[page] or {}
      pages[page][#pages[page] + 1] = line
    end
    return setmetatable({
      game = game, title = title, pages = #pages > 0 and pages or { { "" } },
      page = 1,
    }, HelpPopup)
  end

  function HelpPopup:update()
    local input = self.game.input
    if input:wasPressed("left") or input:wasPressed("up") then
      self.page = math.max(1, self.page - 1)
    elseif input:wasPressed("right") or input:wasPressed("down") then
      self.page = math.min(#self.pages, self.page + 1)
    elseif input:wasPressed("a") or input:wasPressed("b")
        or input:wasPressed("select") then
      self.game.stack:pop()
    end
  end

  function HelpPopup:draw()
    love.graphics.setColor(0, 0, 0, .48)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    panel(2, 3, 156, 138, C.cream, C.blue3)
    color(C.blue3)
    love.graphics.rectangle("fill", 3, 4, 154, 18)
    color(C.orange)
    love.graphics.rectangle("fill", 3, 19, 154, 3)
    color(C.white)
    Font.draw(truncate(self.title, 144), 8, 9)
    color(C.ink)
    for index, line in ipairs(self.pages[self.page]) do
      Font.draw(line, 8, 27 + (index - 1) * 12)
    end
    color(C.blue)
    love.graphics.rectangle("fill", 3, 122, 154, 18)
    color(C.white)
    local footer = #self.pages > 1
      and tr(("L/R PAGE %d/%d  A/B CLOSE"):format(self.page, #self.pages),
        ("L/R SEITE %d/%d A/B ZU"):format(self.page, #self.pages))
      or tr("A/B: CLOSE", "A/B: SCHLIESSEN")
    Font.draw(truncate(footer, 144), 8, 127)
    color(C.white)
  end

  local function controls(menu)
    if menu.footer then return truncate(menu.footer, 146) end
    if menu.pageJump then
      return tr("A:OK L/R:PG B:BK", "A:OK L/R:S B:ZUR")
    end
    return tr("A:SELECT  B:BACK", "A:WAHL  B:ZUR.")
  end

  local function pingPongOffset(time, overflow)
    if not (overflow and overflow > 0) then return 0 end
    local hold, speed = 1.2, 6
    local travel = overflow / speed
    local cycle = 2 * hold + 2 * travel
    local phase = (tonumber(time) or 0) % cycle
    if phase < hold then return 0 end
    phase = phase - hold
    if phase < travel then return -phase * speed end
    phase = phase - travel
    if phase < hold then return -overflow end
    return -overflow + (phase - hold) * speed
  end

  local function focusedHelp(menu)
    local item = menu.items and menu.items[menu.index]
    local provider = menu.ascendantFocusHelp
    if type(provider) == "function" then
      local ok, value = pcall(provider, item, menu)
      if ok and value ~= nil then return text(value):gsub("[\r\n]+", " ") end
    end
    if item and item.help then return text(item.help):gsub("[\r\n]+", " ") end
    return tr("Choose an entry. SELECT opens full help.",
      "Wähle einen Eintrag. SELECT öffnet die ganze Hilfe.")
  end

  local function drawMarquee(value, x, y, budget, time)
    value = tostring(value or "")
    local width = Font.width(value)
    if width <= budget or not love.graphics.setScissor then
      Font.draw(truncate(value, budget), x, y)
      return
    end
    love.graphics.setScissor(x, y - 1, budget, 10)
    Font.draw(value, x + pingPongOffset(time, width - budget), y)
    love.graphics.setScissor()
  end

  -- Guided KASC hubs reserve one permanent line for the focused row's plain-
  -- language explanation. Long text rests at both ends and moves slowly back
  -- and forth; SELECT still opens the complete paginated help.
  local function drawFocusHelp(menu)
    color(C.paper)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    color(C.blue3)
    love.graphics.rectangle("fill", 0, 0, 160, 18)
    color(C.blue2)
    love.graphics.rectangle("fill", 0, 16, 160, 3)
    color(C.orange)
    love.graphics.rectangle("fill", 0, 0, 8, 18)
    color(C.red)
    love.graphics.rectangle("fill", 0, 15, 8, 4)
    panel(9, 2, 148, 14, C.cream, C.orange)
    color(C.ink)
    Font.draw(truncate(menu.title, 144), 12, 5)

    panel(3, 21, 154, 83, C.cream, C.blue3)
    if #(menu.items or {}) == 0 then
      color(C.ink)
      Font.draw(tr("Nothing here.", "Nichts vorhanden."), 16, 58)
    end
    local rows = math.min(menu.rows or 5, 5)
    for row = 1, rows do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 25 + (row - 1) * 16
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 6, y - 2, 148, 14)
        color(C.orange)
        love.graphics.rectangle("fill", 6, y + 10, 148, 2)
      elseif row % 2 == 0 then
        color(C.paper2)
        love.graphics.rectangle("fill", 6, y - 2, 148, 14)
      end
      color(C.ink)
      local right = truncate(item.right, 64)
      local rightX = item.right and (151 - Font.width(right)) or 151
      Font.draw(truncate(item.label, math.max(24, rightX - 22)), 17, y)
      if item.right then Font.draw(right, rightX, y) end
      if index == menu.index then
        Font.drawCode((menu.swapIndex == index or menu.hollowIndex == index)
          and Theme.cursorHollow or Theme.cursor, 8, y)
      elseif menu.swapIndex == index then
        Font.drawCode(Theme.cursorHollow, 8, y)
      end
    end
    if (menu.scroll or 0) > 0 then
      color(C.red); Font.drawCode(Theme.moreArrow, 145, 4)
    end
    if (menu.scroll or 0) + rows < #(menu.items or {}) then
      color(C.red); Font.drawCode(Theme.moreArrow, 145, 96)
    end

    panel(3, 106, 154, 18, C.paper2, C.blue3)
    color(C.blue)
    love.graphics.rectangle("fill", 4, 107, 152, 3)
    color(C.ink)
    local help = focusedHelp(menu)
    menu.ascendantFocusedHelp = help
    drawMarquee(help, 7, 112, 146, menu.ascendantFocusTime)

    color(C.blue)
    love.graphics.rectangle("fill", 3, 127, 154, 14)
    color(C.blue3)
    love.graphics.rectangle("fill", 3, 127, 154, 2)
    panel(5, 129, 150, 12, C.cream, C.orange)
    color(C.ink)
    Font.draw(truncate(controls(menu), 146), 7, 131)
  end

  local function draw(menu)
    color(C.paper)
    love.graphics.rectangle("fill", 0, 0, 160, 144)

    -- FireRed family signature: navy title bar, light-blue lower keyline and
    -- the orange/red Kanto rail.  It mirrors Ascendant's Bag/storage skin.
    color(C.blue3)
    love.graphics.rectangle("fill", 0, 0, 160, 18)
    color(C.blue2)
    love.graphics.rectangle("fill", 0, 16, 160, 3)
    color(C.orange)
    love.graphics.rectangle("fill", 0, 0, 8, 18)
    color(C.red)
    love.graphics.rectangle("fill", 0, 15, 8, 4)
    -- Gen-I tile glyphs are baked black/transparent and ignore setColor.
    -- A real light plaque is therefore required; white text on a dark bar is
    -- only valid for translations using the optional tintable TTF path.
    panel(9, 2, 148, 14, C.cream, C.orange)
    color(C.ink)
    Font.draw(truncate(menu.title, 144), 12, 5)

    panel(3, 21, 154, 103, C.cream, C.blue3)
    if #menu.items == 0 then
      color(C.ink)
      Font.draw(tr("Nothing here.", "Nichts vorhanden."), 16, 64)
    end

    local rows = math.min(menu.rows or 6, 6)
    for row = 1, rows do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 25 + (row - 1) * 16
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 6, y - 2, 148, 14)
        color(C.orange)
        love.graphics.rectangle("fill", 6, y + 10, 148, 2)
      elseif row % 2 == 0 then
        color(C.paper2)
        love.graphics.rectangle("fill", 6, y - 2, 148, 14)
      end

      color(C.ink)
      local right = truncate(item.right, 64)
      local rightX = item.right and (151 - Font.width(right)) or 151
      Font.draw(truncate(item.label, math.max(24, rightX - 22)), 17, y)
      if item.right then Font.draw(right, rightX, y) end
      if index == menu.index then
        Font.drawCode((menu.swapIndex == index or menu.hollowIndex == index)
          and Theme.cursorHollow or Theme.cursor, 8, y)
      elseif menu.swapIndex == index then
        Font.drawCode(Theme.cursorHollow, 8, y)
      end
    end

    if (menu.scroll or 0) > 0 then
      color(C.red)
      Font.drawCode(Theme.moreArrow, 145, 4)
    end
    if (menu.scroll or 0) + rows < #menu.items then
      color(C.red)
      Font.drawCode(Theme.moreArrow, 145, 113)
    end

    color(C.blue)
    love.graphics.rectangle("fill", 3, 127, 154, 14)
    color(C.blue3)
    love.graphics.rectangle("fill", 3, 127, 154, 2)
    panel(5, 129, 150, 12, C.cream, C.orange)
    color(C.ink)
    Font.draw(truncate(controls(menu), 146), 7, 131)
    color(C.ink)
  end

  local function drawBag(menu)
    color(C.paper)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    color(C.blue3)
    love.graphics.rectangle("fill", 0, 0, 160, 18)
    color(C.blue2)
    love.graphics.rectangle("fill", 0, 16, 160, 3)
    color(C.orange)
    love.graphics.rectangle("fill", 0, 0, 8, 18)
    color(C.red)
    love.graphics.rectangle("fill", 0, 15, 8, 4)
    color(C.white)
    -- The engine constructs the flat Bag with the raw title "ITEMS" even
    -- while the edition-matched German translator is active. Actual field
    -- Bags carry kind="bag"; localize only those so Legacy item archives keep
    -- their own authored title when they reuse this presentation.
    local title = menu.kind == "bag" and tr("BAG", "BEUTEL") or menu.title
    Font.draw(truncate(title, 82), 12, 5)
    if menu.footer and tostring(menu.footer):match("^¥") then
      local money = truncate(menu.footer, 58)
      Font.draw(money, 153 - Font.width(money), 5)
    end

    panel(3, 21, 154, 61, C.cream, C.blue3)
    if #menu.items == 0 then
      color(C.ink)
      Font.draw(tr("The BAG is empty.", "Der BEUTEL ist leer."), 14, 47)
    end
    local rows = math.min(menu.rows or 4, 4)
    for row = 1, rows do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 25 + (row - 1) * 14
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 6, y - 2, 148, 13)
        color(C.orange)
        love.graphics.rectangle("fill", 6, y + 9, 148, 2)
      elseif row % 2 == 0 then
        color(C.paper)
        love.graphics.rectangle("fill", 6, y - 2, 148, 13)
      end
      color(C.ink)
      local right = truncate(item.right, 42)
      local rightX = item.right and (151 - Font.width(right)) or 151
      Font.draw(truncate(item.label, math.max(24, rightX - 22)), 17, y)
      if item.right then Font.draw(right, rightX, y) end
      if index == menu.index then
        Font.drawCode((menu.swapIndex == index or menu.hollowIndex == index)
          and Theme.cursorHollow or Theme.cursor, 8, y)
      elseif menu.swapIndex == index then
        Font.drawCode(Theme.cursorHollow, 8, y)
      end
    end

    panel(3, 84, 154, 42, C.paper, C.blue3)
    color(C.blue)
    love.graphics.rectangle("fill", 4, 85, 152, 3)
    color(C.ink)
    local current = menu.items[menu.index]
    local description = current and menu.ascendantBagDescription
      and menu.ascendantBagDescription(current, menu) or tr(
        "Choose an item.", "Wähle ein Item.")
    local lines = wrapLines(description, 142)
    for index = 1, math.min(3, #lines) do
      Font.draw(lines[index], 9, 90 + (index - 1) * 11)
    end

    color(C.blue)
    love.graphics.rectangle("fill", 3, 127, 154, 14)
    color(C.blue3)
    love.graphics.rectangle("fill", 3, 127, 154, 2)
    color(C.white)
    local hint
    if menu.__ascendantBagSecondary == "actions" then
      hint = tr("SEL:I START:ACTION", "SEL:I START:AKTION")
    elseif menu.__ascendantBagSecondary == "sort" then
      hint = tr("SEL:I ST/R3:SORT", "SEL:I ST/R3:ORDN")
    else
      hint = tr("SEL:MOVE START:INFO", "SEL:TAUSCH START:INFO")
    end
    Font.draw(truncate(hint, 146), 7, 131)
    color(C.white)
  end

  -- The Legacy archive is not one of Bill's twelve physical PC boxes: it is
  -- an unbounded, cross-journey ledger.  Give its Pokemon and item lists the
  -- same readable KASC storage language without borrowing any engine-owned
  -- box bitmap.  The upper pane remains a native ListMenu projection while a
  -- mod-drawn detail pane explains the selected row and its safety state.
  local function drawLegacyStorage(menu)
    color(C.paper)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    color(C.blue3)
    love.graphics.rectangle("fill", 0, 0, 160, 18)
    color(C.blue2)
    love.graphics.rectangle("fill", 0, 16, 160, 3)
    color(C.orange)
    love.graphics.rectangle("fill", 0, 0, 8, 18)
    color(C.red)
    love.graphics.rectangle("fill", 0, 15, 8, 4)
    -- Gen-I's tile-font glyphs are baked black; tinting them white does not
    -- recolor the pixels.  Keep the KASC blue rail, but put every tile-font
    -- label on a light authored plaque so the title remains legible.
    color(C.cream)
    love.graphics.rectangle("fill", 9, 2, 148, 14)
    color(C.orange)
    love.graphics.rectangle("line", 9, 2, 148, 14)
    color(C.ink)
    Font.draw(truncate(menu.title, 144), 12, 5)

    panel(3, 21, 154, 62, C.cream, C.blue3)
    if #menu.items == 0 then
      color(C.ink)
      Font.draw(tr("Nothing archived.", "Nichts archiviert."), 14, 47)
    end
    local rows = math.min(menu.rows or 4, 4)
    for row = 1, rows do
      local index = (menu.scroll or 0) + row
      local item = menu.items[index]
      if not item then break end
      local y = 25 + (row - 1) * 14
      if index == menu.index then
        color(C.gold)
        love.graphics.rectangle("fill", 6, y - 2, 148, 13)
        color(C.orange)
        love.graphics.rectangle("fill", 6, y + 9, 148, 2)
      elseif row % 2 == 0 then
        color(C.paper)
        love.graphics.rectangle("fill", 6, y - 2, 148, 13)
      end
      color(C.ink)
      local right = truncate(item.right, 50)
      local rightX = item.right and (151 - Font.width(right)) or 151
      Font.draw(truncate(item.label, math.max(24, rightX - 22)), 17, y)
      if item.right then Font.draw(right, rightX, y) end
      if index == menu.index then
        Font.drawCode(Theme.cursor, 8, y)
      end
    end

    panel(3, 85, 154, 40, C.paper, C.blue3)
    color(C.blue)
    love.graphics.rectangle("fill", 4, 86, 152, 3)
    color(C.ink)
    local current = menu.items[menu.index]
    local description = current and menu.ascendantStorageDescription
      and menu.ascendantStorageDescription(current, menu) or tr(
        "Archive has no capacity limit.",
        "Das Archiv hat kein Kapazitaetslimit.")
    local lines = wrapLines(description, 142)
    for index = 1, math.min(3, #lines) do
      Font.draw(lines[index], 9, 91 + (index - 1) * 10)
    end

    color(C.blue)
    love.graphics.rectangle("fill", 3, 127, 154, 14)
    color(C.blue3)
    love.graphics.rectangle("fill", 3, 127, 154, 2)
    color(C.cream)
    love.graphics.rectangle("fill", 5, 129, 150, 12)
    color(C.orange)
    love.graphics.rectangle("line", 5, 129, 150, 12)
    color(C.ink)
    Font.draw(truncate(controls(menu), 146), 7, 131)
    color(C.white)
  end

  function U.decorate(menu, style)
    if type(menu) ~= "table" or menu.__kantoAscendantLayout then return menu end
    menu.__kantoAscendantLayout = true
    menu.__kantoAscendantStyle = style or "firered"
    menu.rows = math.min(tonumber(menu.rows) or 6, 6)
    menu.isOpaque = true
    menu.sgbPalettes = function()
      return { PaletteFX.trueColorZone(0, 0, 19, 17) }
    end
    menu.draw = draw
    return menu
  end

  function U.decorateFocusHelp(menu, provider)
    if type(menu) ~= "table" then return menu end
    menu.__kantoAscendantLayout = true
    menu.__kantoAscendantStyle = "firered-focus-help"
    menu.__kantoAscendantFocusHelp = true
    menu.rows = math.min(tonumber(menu.rows) or 5, 5)
    menu.isOpaque = true
    menu.ascendantFocusHelp = provider
    menu.ascendantFocusTime = 0
    menu.sgbPalettes = function()
      return { PaletteFX.trueColorZone(0, 0, 19, 17) }
    end
    local baseUpdate = menu.update
    menu.update = function(self, dt)
      local before = self.index
      local result = baseUpdate and baseUpdate(self, dt)
      if self.index ~= before then
        self.ascendantFocusTime = 0
      else
        self.ascendantFocusTime = (self.ascendantFocusTime or 0)
          + math.max(0, tonumber(dt) or 0)
      end
      return result
    end
    menu.draw = drawFocusHelp
    local card = mod.exports and mod.exports.fullscreenUiCard
    -- Five rows belong to the 160x144 fallback, not the fullscreen surface.
    -- Let ORAS use its nine-row budget; its renderer clamps to actual height.
    if card then return card.decorateMenu(menu, provider, 9) end
    return menu
  end

  function U.decorateBag(menu, description)
    if type(menu) ~= "table" then return menu end
    menu.__kantoAscendantLayout = true
    menu.__kantoAscendantStyle = "firered-bag"
    menu.__kantoAscendantBag = true
    menu.rows = 4
    menu.isOpaque = true
    menu.ascendantBagDescription = description
    menu.sgbPalettes = function()
      return { PaletteFX.trueColorZone(0, 0, 19, 17) }
    end
    menu.draw = drawBag
    return menu
  end

  function U.decorateLegacyStorage(menu, description)
    if type(menu) ~= "table" then return menu end
    menu.__kantoAscendantLayout = true
    menu.__kantoAscendantStyle = "firered-legacy-storage"
    menu.__kantoAscendantLegacyStorage = true
    menu.rows = 4
    menu.isOpaque = true
    menu.ascendantStorageDescription = description
    menu.sgbPalettes = function()
      return { PaletteFX.trueColorZone(0, 0, 19, 17) }
    end
    menu.draw = drawLegacyStorage
    return menu
  end

  U.ListMenu = {
    new = function(game, title, items, listOpts)
      listOpts = listOpts or {}
      -- Every ordinary KASC-owned feature list publishes a contextual-help
      -- provider.  VASC's public menu-skin bridge uses this explicit marker
      -- to lift the screen into its responsive ORAS fullscreen presentation,
      -- even when the list is opened by story code rather than from the
      -- ASCENDANT root.  Dialogue boxes, questions, Bag and Legacy storage
      -- retain their dedicated semantic renderers.
      local style = tostring(listOpts.ascendantStyle or "")
      if listOpts.ascendantFocusHelp == nil
          and listOpts.ascendantLayout ~= false
          and not listOpts.dialogue and not listOpts.messageBox
          and (style == "" or style == "firered") then
        listOpts.ascendantFocusHelp = function(item)
          if type(item) ~= "table" then
            return tr("Choose an entry.", "Wähle einen Eintrag.")
          end
          if item.help ~= nil and tostring(item.help) ~= "" then
            return item.help
          end
          local label = tostring(item.label or title or "")
          local right = item.right ~= nil and tostring(item.right) or ""
          return right ~= "" and (label .. "  " .. right) or label
        end
        listOpts.__kascAutoFocusHelp = true
      end
      if listOpts.ascendantFocusHelp then
        listOpts.rows = math.min(tonumber(listOpts.rows) or 5, 5)
      end
      local menu = mod.ui.ListMenu.new(game, title, items, listOpts)
      if listOpts.ascendantFocusHelp then
        return U.decorateFocusHelp(menu, listOpts.ascendantFocusHelp)
      end
      if listOpts.ascendantStyle == "firered-legacy-storage" then
        return U.decorateLegacyStorage(menu,
          listOpts.ascendantStorageDescription)
      end
      if listOpts.ascendantStyle == "firered-bag" then
        return U.decorateBag(menu, listOpts.ascendantBagDescription)
      end
      -- Dialogue/money boxes deliberately retain the engine layout because
      -- their row budget and bottom text box are gameplay semantics. A KASC
      -- feature can explicitly opt a message-box list back into the shared
      -- full-screen skin; the Legacy Bank uses that narrow seam.
      if listOpts.ascendantLayout == false
          or listOpts.dialogue
          or (listOpts.messageBox and listOpts.ascendantLayout ~= true) then
        return menu
      end
      return U.decorate(menu, listOpts.ascendantStyle)
    end,
  }

  function U.openQuestionMenu(game, title, prompt, items, options)
    options = options or {}
    items = items or {}
    if not (game and game.stack and type(game.stack.push) == "function") then
      return false, "stack"
    end
    if #items < 2 or #items > 3 then return false, "answers" end

    local choose, timeout = options.onChoose, options.onTimeout
    local menu, callbackResolved
    local listOptions = {
      ascendantLayout = true,
      ascendantStyle = "firered-question",
      pageJump = false,
      rows = #items,
      -- This explicit provider is also the public VASC bridge contract. In
      -- ORAS FULLSCREEN the choices stay on the left while the complete,
      -- dynamically timed prompt is readable in the right-hand help pane.
      ascendantFocusHelp = function(_, current)
        local body = tostring(prompt)
        if current and current.kascQuestionCountdownVisible then
          local remaining = math.max(0,
            math.ceil(tonumber(current.kascQuestionRemaining) or 0))
          return tr(("TIME %02ds. "):format(remaining),
            ("ZEIT %02ds. "):format(remaining)) .. body
        end
        return body
      end,
    }
    listOptions.onChoose = function(item, current)
      if callbackResolved then return end
      callbackResolved = true
      current = current or menu
      if not (current and type(current.resolveQuestion) == "function") then return end
      current:resolveQuestion()
      if type(current.closeQuestion) == "function" then current:closeQuestion() end
      if choose then return choose(item, current) end
    end
    -- B is intercepted by armQuestionMenu before native ListMenu can pop.
    -- Retain a no-op callback as a fail-closed guard for synthetic callers.
    listOptions.onCancel = function() end
    local ok, result, reason = pcall(function()
      menu = U.ListMenu.new(game, title, items, listOptions)
      if type(menu) ~= "table" then return false, "menu" end
      menu.index = math.max(1, math.min(#items,
        math.floor(tonumber(options.defaultIndex) or 1)))
      U.armQuestionMenu(game, menu, {
        title = title,
        prompt = prompt,
        seconds = options.seconds,
        cancelDisabled = true,
        onTimeout = function()
          if callbackResolved then return end
          callbackResolved = true
          if timeout then return timeout() end
        end,
      })
      game.stack:push(menu)
      return menu
    end)
    if not ok then return false, "question-ui:" .. tostring(result) end
    if result == false then return false, reason end
    return result
  end

  function U.paginateQuestionText(prompt)
    prompt = tostring(prompt or "")
    local TextBox = require("src.render.TextBox")
    local wrapped = TextBox.paginate(prompt)
    local groups = {}
    for _, page in ipairs(wrapped) do
      for first = 1, #page, 2 do
        local lines = { page[first] }
        if page[first + 1] ~= nil then lines[2] = page[first + 1] end
        groups[#groups + 1] = table.concat(lines, "\n")
      end
    end
    local paginated = table.concat(groups, "\f")
    local pages = TextBox.paginate(paginated)
    for _, page in ipairs(pages) do
      assert(#page <= 2, "KASC question text exceeds two visible lines")
    end
    return paginated, pages
  end

  function U.showQuestionText(game, prompt, onDone, showText)
    prompt = tostring(prompt or "")
    local okPagination, paginated = pcall(U.paginateQuestionText, prompt)
    if not okPagination then
      return false, "question-pagination:" .. tostring(paginated)
    end
    if type(showText) == "function" then
      return showText(game, paginated, onDone, {
        semanticPrompt = prompt, questionPages = true,
      })
    end
    if not (game and game.stack and type(game.stack.push) == "function") then
      return false, "stack"
    end
    local ok, screen = pcall(function()
      local TextBox = require("src.render.TextBox")
      local box = TextBox.new(game, paginated, onDone)
      box.kascQuestionSemanticPrompt = prompt
      box.kascQuestionPaginatedText = paginated
      game.stack:push(box)
      return box
    end)
    if not ok then return false, "question-text:" .. tostring(screen) end
    return screen
  end

  function U.showHelp(game, title, body)
    if not (game and game.stack and body and body ~= "") then return false end
    game.stack:push(HelpPopup.new(game, title, body))
    return true
  end

  function U.guidedList(game, spec)
    spec = spec or {}
    local key = assert(spec.key, "guided KASC menu requires a stable key")
    local title = assert(spec.title, "guided KASC menu requires a title")
    local body = assert(spec.help, "guided KASC menu requires bilingual help")
    assert(game and game.stack and type(game.stack.push) == "function",
      "guided KASC menu requires a game stack")

    local rows = {}
    for index, item in ipairs(spec.rows or {}) do rows[index] = item end
    local helpValue = "__kasc_help:" .. tostring(key)
    rows[#rows + 1] = {
      label = tr("HELP", "HILFE"), value = helpValue, help = body,
      __kascFeatureHelp = true,
    }

    local listOpts = {}
    for option, value in pairs(spec.options or {}) do listOpts[option] = value end
    listOpts.ascendantLayout = true
    listOpts.ascendantStyle = spec.style or listOpts.ascendantStyle or "firered"
    listOpts.footer = spec.footer
      or tr("A:SELECT  SEL:HELP", "A:WAHL  SEL:HILFE")
    local originalChoose = spec.onChoose or listOpts.onChoose
    local originalSelect = spec.onSelectKey or listOpts.onSelectKey
    listOpts.onChoose = function(item, menu)
      if item and item.value == helpValue then
        return U.showHelp(game, spec.helpTitle or title, body)
      end
      if originalChoose then return originalChoose(item, menu) end
    end
    listOpts.onSelectKey = function(item, menu)
      local itemHelp = item and item.help
      if itemHelp and itemHelp ~= "" then
        return U.showHelp(game, item.label or spec.helpTitle or title, itemHelp)
      end
      if originalSelect then return originalSelect(item, menu) end
      return U.showHelp(game, spec.helpTitle or title, body)
    end

    local menu = U.ListMenu.new(game, title, rows, listOpts)
    menu.__kascGuidedHelpRow = rows[#rows]
    local baseUpdate = menu.update
    function menu:showFirstGuide()
      local stack = game.stack
      if type(stack.top) == "function" and stack:top() ~= self then
        return false
      end
      local seen = guidedHelpSeen[game]
      if not seen then
        seen = {}
        guidedHelpSeen[game] = seen
      end
      if seen[key] then return false end
      seen[key] = true
      return U.showHelp(game, spec.helpTitle or title, body)
    end
    if type(baseUpdate) == "function" then
      menu.update = function(self, ...)
        if self:showFirstGuide() then return end
        return baseUpdate(self, ...)
      end
    end
    return menu
  end

  function U.pushGuidedList(game, spec)
    local menu = U.guidedList(game, spec)
    game.stack:push(menu)
    menu:showFirstGuide()
    return menu
  end

  U.HelpPopup = HelpPopup

  U.tr = tr
  U.truncate = truncate
  return U
end
