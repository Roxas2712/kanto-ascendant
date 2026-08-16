package.path = "./?.lua;./?/init.lua;" .. package.path
local modPath = os.getenv("KA_HIDDEN_EVOLUTION_MOD")
  or os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end

local calls = {}
love = { graphics = {
  setColor = function(...) calls[#calls + 1] = { "color", ... } end,
  rectangle = function(...) calls[#calls + 1] = { "rectangle", ... } end,
  draw = function(...) calls[#calls + 1] = { "draw", ... } end,
} }

local rawNewCalls = 0
local mod = { ui = { ListMenu = { new = function(game, title, items, opts)
  rawNewCalls = rawNewCalls + 1
  return {
    game = game, title = title, items = items, index = 1, scroll = 0,
    rows = opts.rows or 7, footer = opts.footer, pageJump = opts.pageJump,
    onChoose = opts.onChoose, onCancel = opts.onCancel,
    -- Minimal native-ListMenu B behavior: the KASC question wrapper must
    -- intercept this before it can pop the screen or invoke onCancel.
    update = function(self)
      local input=self.game and self.game.input
      if input and input:wasPressed("b") then
        self.game.stack:pop()
        if self.onCancel then self.onCancel() end
      end
    end,
  }
end } } }

local ui = assert(loadfile(modPath .. "/ascendant_ui.lua"))()(mod, {
  i18n = { text = function(en, de) return de end },
})
local rows = {
  { label = "GAMEPLAY", right = "AN" },
  { label = "BEGLEITER", right = "4" },
  { label = "GRAFIK", right = "CRYSTAL" },
  { label = "INHALTE" },
  { label = "SYSTEM" },
  { label = "EXTRAS" },
  { label = "SCROLL TEST" },
}
local menu = ui.ListMenu.new({}, "KANTO ASCENDANT", rows, {
  pageJump = true,
})
eq(rawNewCalls, 1, "the shared skin delegates construction to ListMenu")
eq(menu.__kantoAscendantLayout, true, "Ascendant list carries its layout marker")
eq(menu.__kantoAscendantStyle, "firered", "the stable FireRed style is selected")
eq(menu.rows, 6, "header and footer leave a stable six-row viewport")
eq(menu.isOpaque, true, "the full-screen skin is opaque")
local palettes = menu:sgbPalettes()
eq(palettes[1].colors, false, "the multi-color layout opts out of SGB shading")

menu:draw()
local fills, lines = 0, 0
for _, call in ipairs(calls) do
  if call[1] == "rectangle" and call[2] == "fill" then fills = fills + 1 end
  if call[1] == "rectangle" and call[2] == "line" then lines = lines + 1 end
end
ok(fills >= 10, "FireRed layout draws header, rail, rows and footer")
ok(lines >= 1, "FireRed content panel has a defined border")

local untouched = ui.ListMenu.new({}, "DIALOGUE", rows, {
  dialogue = true, rows = 4,
})
eq(untouched.__kantoAscendantLayout, nil,
  "semantic shop/dialogue menus keep their engine layout")
eq(untouched.rows, 4, "dialogue row budget remains untouched")

local storage = ui.ListMenu.new({}, "LEGACY BANK", rows, {
  messageBox = true, ascendantLayout = true,
  ascendantStyle = "firered-storage",
})
eq(storage.__kantoAscendantLayout, true,
  "Legacy storage explicitly opts its message-box rows into KASC layout")
eq(storage.__kantoAscendantStyle, "firered-storage",
  "Legacy storage keeps its inspectable KASC style receipt")

local itemStorage = ui.ListMenu.new({}, "LEGACY ITEMS", rows, {
  messageBox = true, ascendantLayout = true,
  ascendantStyle = "firered-bag",
  ascendantBagDescription = function() return "ARCHIVED ITEM" end,
})
eq(itemStorage.__kantoAscendantBag, true,
  "Legacy items use the same dedicated KASC Bag presentation")
eq(itemStorage.ascendantBagDescription(), "ARCHIVED ITEM",
  "Legacy item descriptions survive the shared UI adapter")

local legacyStorage = ui.ListMenu.new({}, "LEGACY BANK", {
  { label = "CHIKORITA", right = "VERSIEGELT", value = "locked" },
  { label = "PIKACHU", right = "L50", value = "ready" },
}, {
  messageBox = true, ascendantLayout = true,
  ascendantStyle = "firered-legacy-storage",
  footer = "A:NEHM SEL:HILFE",
  ascendantStorageDescription = function(row)
    return row.value == "locked"
      and "ARCHIVE DETAIL\nSELECT: HILFE\nARCHIV OHNE LIMIT"
      or "BEREIT"
  end,
})
eq(legacyStorage.__kantoAscendantLegacyStorage, true,
  "Legacy archive has a dedicated modern KASC storage receipt")
eq(legacyStorage.__kantoAscendantStyle, "firered-legacy-storage",
  "Legacy archive exposes its stable inspectable style id")
eq(legacyStorage.rows, 4,
  "Legacy detail pane reserves a four-row selection viewport")
eq(legacyStorage.ascendantStorageDescription(legacyStorage.items[1]),
  "ARCHIVE DETAIL\nSELECT: HILFE\nARCHIV OHNE LIMIT",
  "Legacy selected-row detail survives the shared adapter")
local LegacyFont = require("src.render.Font")
local originalLegacyDraw = LegacyFont.draw
local legacyText = {}
local legacyGlyphReceipts = {}
local function fillAt(x, y)
  local active, fill
  for _, call in ipairs(calls) do
    if call[1] == "color" then
      active = { call[2], call[3], call[4], call[5] }
    elseif call[1] == "rectangle" and call[2] == "fill"
        and x >= call[3] and x < call[3] + call[5]
        and y >= call[4] and y < call[4] + call[6] then
      fill = active
    end
  end
  return fill
end
LegacyFont.draw = function(value, x, y, ...)
  legacyText[#legacyText + 1] = tostring(value)
  legacyGlyphReceipts[#legacyGlyphReceipts + 1] = {
    text = tostring(value), x = x, y = y, background = fillAt(x, y),
  }
  return originalLegacyDraw(value, x, y, ...)
end
calls = {}
legacyStorage:draw()
LegacyFont.draw = originalLegacyDraw
local bitmapDraws, legacyFills, legacyLines = 0, 0, 0
for _, call in ipairs(calls) do
  if call[1] == "draw" then bitmapDraws = bitmapDraws + 1 end
  if call[1] == "rectangle" and call[2] == "fill" then
    legacyFills = legacyFills + 1
  end
  if call[1] == "rectangle" and call[2] == "line" then
    legacyLines = legacyLines + 1
  end
end
eq(bitmapDraws, 0,
  "Legacy archive skin draws no copied engine-owned bitmap pixels")
ok(legacyFills >= 10 and legacyLines >= 2,
  "Legacy archive draws its own KASC header, selection and detail panels")
local legacyTextFlat = table.concat(legacyText, " ")
ok(legacyTextFlat:find("ARCHIVE DETAIL", 1, true)
    and legacyTextFlat:find("ARCHIV OHNE LIMIT", 1, true)
    and legacyTextFlat:find("A:NEHM SEL:HILFE", 1, true),
  "Legacy draw call contract exposes detail, unlimited storage and SELECT help: "
    .. legacyTextFlat)
local function receipt(text)
  for _, row in ipairs(legacyGlyphReceipts) do
    if row.text == text then return row end
  end
end
local function luminance(rgb)
  return rgb and rgb[1] * 0.2126 + rgb[2] * 0.7152 + rgb[3] * 0.0722
end
local titleGlyphs = receipt("LEGACY BANK")
local footerGlyphs = receipt("A:NEHM SEL:HILFE")
ok(titleGlyphs and luminance(titleGlyphs.background) > 0.75,
  "real Font.draw title glyphs sit on a light plaque (tile glyphs are black)")
ok(footerGlyphs and luminance(footerGlyphs.background) > 0.75,
  "real Font.draw footer glyphs sit on a light plaque (tile glyphs are black)")

local optOut = ui.ListMenu.new({}, "EXTERNAL", rows, {
  ascendantLayout = false,
})
eq(optOut.__kantoAscendantLayout, nil, "explicit compatibility opt-out is honored")

local bag = ui.decorateBag({
  title = "ITEMS", items = { { label = "TRANK", right = "x2", value = "POTION" } },
  index = 1, scroll = 0, rows = 7, footer = "¥3000",
}, function() return "Stellt 20 KP wieder her." end)
eq(bag.__kantoAscendantBag, true, "Bag receives the dedicated presentation")
eq(bag.__kantoAscendantStyle, "firered-bag", "Bag uses the FireRed variant")
eq(bag.rows, 4, "description panel leaves a four-row item viewport")
bag:draw()

local pushed, popped = nil, 0
local game = {
  input = { wasPressed = function() return false end },
  stack = {
    push = function(_, state) pushed = state end,
    pop = function() popped = popped + 1 end,
  },
}

local function normalized(value)
  return tostring(value):gsub("[\n\f]+", " "):gsub("%s+", " ")
    :gsub("^ ", ""):gsub(" $", "")
end
local longQuestion = "Which Pokemon evolves after exposure to a Thunder Stone and belongs to the original Kanto Pokedex?"
local paginated, questionPages = ui.paginateQuestionText(longQuestion)
ok(#questionPages > 1, "long question receives real TextBox pages")
for index, page in ipairs(questionPages) do
  ok(#page <= 2, "question page " .. index .. " exceeds two visible lines")
end
eq(normalized(paginated), normalized(longQuestion),
  "question pagination preserves the complete semantic prompt")

local questionStack, questionPressed = {}, nil
local questionGame = { input = { wasPressed = function(_, key)
  return key == questionPressed
end }, stack = {
  push = function(_, state) questionStack[#questionStack + 1] = state end,
  pop = function() return table.remove(questionStack) end,
  top = function() return questionStack[#questionStack] end,
} }
local choices, cancels, timeouts = 0, 0, 0
local questionMenu = assert(ui.openQuestionMenu(questionGame,
  "GROUDON-PRÜFUNG 1/5", longQuestion, {
    { label = "JA", value = true }, { label = "NEIN", value = false },
  }, {
    defaultIndex = 2,
    seconds = 20,
    onChoose = function() choices = choices + 1 end,
    onCancel = function() cancels = cancels + 1 end,
    onTimeout = function() timeouts = timeouts + 1 end,
  }))
eq(questionMenu.index, 2, "HEVO question menu keeps the neutral default cursor")
eq(questionMenu.kascQuestionPrompt, longQuestion,
  "answer window repeats the exact semantic question")
eq(questionMenu.kascQuestionCountdownVisible, true,
  "HEVO question menu shows its challenge timer")
eq(questionMenu.kascQuestionRemaining, 20,
  "HEVO question menu starts from exactly 20 seconds")
eq(questionMenu.kascQuestionStyle, "firered-question",
  "HEVO uses the Kanto Ascendant dark/blue question skin")
eq(questionMenu.__kantoAscendantStyle, "firered-question",
  "HEVO question screen carries the Ascendant skin marker")
eq(questionMenu:sgbPalettes()[1].colors, false,
  "HEVO question screen opts out of SGB shading")
local Font=require("src.render.Font")
local originalFontDraw=Font.draw;local drawnText={}
Font.draw=function(value,...)drawnText[#drawnText+1]=tostring(value)
  return originalFontDraw(value,...)
end
calls={};questionMenu:draw();Font.draw=originalFontDraw
eq(calls[1][1], "color", "HEVO draw starts by setting its paper canvas")
eq(calls[1][2], ui.colors.paper[1], "HEVO question canvas uses Ascendant paper")
local seen={}
for _,call in ipairs(calls) do if call[1]=="color" then
  for name,wanted in pairs(ui.colors) do
    if call[2]==wanted[1] and call[3]==wanted[2]
        and call[4]==wanted[3] then seen[name]=true end
  end
end end
for _,name in ipairs({"blue3","blue2","orange","red","gold","blue","cream"}) do
  ok(seen[name],"HEVO question skin is missing Ascendant color "..name)
end
local sawTimer=false
local sawSelectOnly=false
for _,value in ipairs(drawnText) do if value=="ZEIT 20s" then sawTimer=true end end
for _,value in ipairs(drawnText) do
  if value=="A:WAHL" then sawSelectOnly=true end
  ok(not value:find("B:",1,true),"question footer must not advertise B/Back")
end
ok(sawTimer,"German 20-second timer is not visibly drawn")
ok(sawSelectOnly,"question footer does not advertise the sole A selection action")
questionMenu:update(1);drawnText={};Font.draw=function(value,...)
  drawnText[#drawnText+1]=tostring(value);return originalFontDraw(value,...)
end
questionMenu:draw();Font.draw=originalFontDraw
local sawTick=false
for _,value in ipairs(drawnText) do if value=="ZEIT 19s" then sawTick=true end end
ok(sawTick,"visible German timer did not tick from 20 to 19")
questionPressed="b";questionMenu:update(4);questionPressed=nil
eq(questionStack[#questionStack],questionMenu,
  "B must leave the modal question menu on the stack")
eq(questionMenu.kascQuestionRemaining,15,
  "B must not pause the running question timer")
questionMenu.onCancel()
eq(cancels,0,"B/no-op cancel callback must never reach route code")
eq(choices,0,"B must never be reinterpreted as an answer")
ok(not questionMenu.kascQuestionResolved,
  "B must not resolve the pending question receipt")
questionMenu:update(15)
eq(timeouts,1,"timer did not continue to the normal timeout after B")
ok(questionMenu.kascQuestionResolved and questionStack[#questionStack]==nil,
  "timeout after ignored B did not resolve and close the question menu")
eq(ui.showHelp(game, "SCHWIERIGKEIT",
  "Erhöht Trainerlevel.\nAKTUELL: EXTREM"), true,
  "SELECT help popup can be opened")
ok(pushed and pushed.isOpaque == false, "help popup overlays the option list")
pushed:draw()
game.input.wasPressed = function(_, key) return key == "b" end
pushed:update()
eq(popped, 1, "help popup closes without changing the option")

print(("ascendant UI tests passed: %d assertions"):format(assertions))
