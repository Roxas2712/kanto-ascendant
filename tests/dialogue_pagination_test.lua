local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/") or "."
local TextBox = require("src.render.TextBox")

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local registered = {}
local registry = {
  register = function(_, id, value) registered[id] = value end,
  override = function(_, id, value) registered[id] = value end,
}
local mod = { path = root, content = { text = registry } }
local make = assert(loadfile(root .. "/dialogue_pagination.lua"))()
local pagination = make(mod, { TextBox = TextBox })

local function pageIsSafe(page, waits)
  local sinceWait = 0
  for index = 1, #page do
    if index > 1 and waits and waits[index] then sinceWait = 0 end
    sinceWait = sinceWait + 1
    if sinceWait > 2 then return false end
  end
  return true
end

local function assertSafe(label, text)
  local pages = TextBox.paginate(text, 18)
  for pageIndex, page in ipairs(pages) do
    check(pageIsSafe(page, pages.contBefore[pageIndex]),
      label .. " page " .. pageIndex .. " still auto-scrolls")
  end
end

-- Width is measured by the real renderer. Long German and token-expanded
-- lines therefore acquire exactly as many A-gated pages as they need.
local game = {
  save = { player = { name = "BLITZ", rival = "BLAU" } },
  data = { tokens = TextBox.TOKENS },
}
local unsafe = "EICH: {PLAYER}, dieser sehr lange Satz"
  .. "\nist noch nicht vorbei\nund scrollte bisher sofort."
local safe = pagination.gateText(game, unsafe)
assertSafe("dynamic German/token text", safe)
check(safe:find("\f", 1, true) ~= nil,
  "unsafe dialogue gained no explicit page break")

-- Existing cartridge CONT waits remain CONT, while any later ungated third
-- row is split. This is the only deliberate non-formfeed exception.
local continued = pagination.gateText(game,
  "FIRST\nSECOND\vTHIRD\nFOURTH\nFIFTH")
check(continued:find("\v", 1, true) ~= nil,
  "authored CONT wait was not preserved")
assertSafe("CONT-authored text", continued)
local authoredPage = "{PLAYER}\fSECOND\vTHIRD"
local authoredGated = pagination.gateText(game, authoredPage)
check(authoredGated:find("{PLAYER}", 1, true) ~= nil
    and authoredGated:find("\f", 1, true) ~= nil
    and authoredGated:find("\v", 1, true) ~= nil,
  "raw token or authored page/CONT marker was lost")

-- Registry ownership covers text opened later from the engine's map script.
registry:register("TEXT_KA_TEST", "ONE\nTWO\nTHREE")
check(pagination.owned[registered.TEXT_KA_TEST] == true,
  "content registry did not mark KASC dialogue")
local ownedBox = TextBox.new(game, registered.TEXT_KA_TEST)
for index, page in ipairs(ownedBox.pages) do
  check(#page <= 2, "registered text page " .. index .. " auto-scrolls")
end

-- Localized direct strings are tracked independently of the content layer.
local i18n = {
  text = function(en) return en end,
  rest = function(_, en) return en end,
}
pagination.wrapLocalization(i18n)
local localized = i18n.text("ALPHA\nBETA\nGAMMA", "EINS\nZWEI\nDREI")
check(pagination.owned[localized] == true,
  "localized KASC dialogue was not marked")
local localizedBox = TextBox.new(game, localized)
for index, page in ipairs(localizedBox.pages) do
  check(#page <= 2, "localized text page " .. index .. " auto-scrolls")
end

-- A direct KASC call is recognized from the immediate source chunk even if
-- its dynamic result was never registered or returned by i18n. Conversely,
-- unrelated engine text remains byte-identical.
local kascCaller = assert(loadstring(
  "return function(TextBox, game, text) local box = TextBox.new(game, text); return box end",
  "@" .. root .. "/dynamic_dialogue_fixture.lua"))()
local directBox = kascCaller(TextBox, game, "DYNAMIC\nDIRECT\nDIALOGUE")
check(#directBox.pages == 3 and #directBox.pages[1] == 1,
  "direct KASC caller did not receive A-gated pages")
local vanillaCaller = assert(loadstring(
  "return function(TextBox, game, text) local box = TextBox.new(game, text); return box end",
  "@engine/vanilla_dialogue.lua"))()
local vanillaText = "VANILLA\nSCRIPT\nUNCHANGED"
local vanillaBox = vanillaCaller(TextBox, game, vanillaText)
check(#vanillaBox.pages == 1 and #vanillaBox.pages[1] == 3,
  "unowned engine dialogue was changed by the KASC guard")
pagination.hasSourceDebug = false
local sandboxFallback = vanillaCaller(TextBox, game, vanillaText)
check(#sandboxFallback.pages == 1 and #sandboxFallback.pages[1] == 3,
  "no-debug unattributable engine dialogue was not byte-exact")
local correctVanilla = "VANILLA\nCORRECT"
local correctFallback = vanillaCaller(TextBox, game, correctVanilla)
check(#correctFallback.pages == 1 and #correctFallback.pages[1] == 2,
  "no-debug fallback changed an already-correct vanilla page")
pagination.hasSourceDebug = true

-- Engine-authored no-button and already-read redraw modes keep their exact
-- timing contract. They are the two deliberate non-dialogue exceptions.
local auto = TextBox.new(game, registered.TEXT_KA_TEST, nil, { auto = true })
check(#auto.pages == 1 and #auto.pages[1] == 3,
  "deliberate auto command was unexpectedly made interactive")
local instant = TextBox.new(game, registered.TEXT_KA_TEST, nil,
  { instant = true })
check(#instant.pages == 1 and #instant.pages[1] == 3,
  "already-read instant redraw was unexpectedly repaginated")
local stay = TextBox.new(game, registered.TEXT_KA_TEST, nil,
  { stay = {} })
check(#stay.pages == 1 and #stay.pages[1] == 3,
  "engine-owned stay box was unexpectedly made interactive")

-- Reproduce the real 0.1.86+ player sandbox. Its private _G.require is the
-- production ownership boundary: direct and loadstring-nested KASC requires
-- receive the proxy, while the engine and another mod retain the native table.
local Sandbox = require("src.mods.Sandbox")
local sourceHandle = assert(io.open(root .. "/dialogue_pagination.lua", "rb"))
local paginationSource = sourceHandle:read("*a")
sourceHandle:close()
local prodEnv = Sandbox.envFor({
  modId = "kanto_ascendant",
  permissions = { engine_internals = true },
})
local prodChunk = assert(Sandbox.compile(paginationSource,
  "@" .. root .. "/dialogue_pagination.lua", prodEnv))
local prodMake = prodChunk()
local prodRegistered = {}
local prodRegistry = {
  register = function(_, id, value) prodRegistered[id] = value end,
  override = function(_, id, value) prodRegistered[id] = value end,
}
local prod = prodMake({ path = root, content = { text = prodRegistry } },
  { TextBox = TextBox })
check(prod.hasSourceDebug == false,
  "real player sandbox unexpectedly exposed debug")
local scopedTextBox = prodEnv.require("src.render.TextBox")
check(scopedTextBox == prod.TextBox and scopedTextBox ~= TextBox,
  "KASC sandbox require did not return its private TextBox proxy")
check(scopedTextBox.paginate == TextBox.paginate
    and scopedTextBox.substitute == TextBox.substitute
    and scopedTextBox.soundOpts == TextBox.soundOpts
    and scopedTextBox.TOKENS == TextBox.TOKENS
    and scopedTextBox.isTextBox == true,
  "TextBox proxy did not preserve the native public API")

local prodDirect = scopedTextBox.new(game, "DIRECT\nKASC\nPLAYER")
check(#prodDirect.pages == 3 and #prodDirect.pages[1] == 1,
  "direct production KASC dialogue was not A-gated")
check(getmetatable(prodDirect) == TextBox and prodDirect.isTextBox == true,
  "scoped constructor changed native TextBox instance identity")

local nestedChunk = assert(prodEnv.loadstring(
  "return require('src.render.TextBox')",
  "@" .. root .. "/hidden_evolution_red_path.lua"))
check(nestedChunk() == scopedTextBox,
  "nested HEVO loadstring did not inherit scoped KASC require")

-- Exercise hidden_evolution_campaign.lua's actual private load() path, not
-- merely a synthetic nested chunk. The coordinator sentinel is reached only
-- when that child sees the scoped proxy.
local campaignHandle = assert(io.open(root ..
  "/hidden_evolution_campaign.lua", "rb"))
local campaignBody = campaignHandle:read("*a")
campaignHandle:close()
local campaignChunk = assert(prodEnv.loadstring(campaignBody,
  "@" .. root .. "/hidden_evolution_campaign.lua"))
local campaignFactory = campaignChunk()
local hevoMod = {
  path = root,
  read = function(_, file)
    if file == "hidden_evolution_story_coordinator.lua" then
      return "local T=require('src.render.TextBox'); "
        .. "assert(T._kascNativeTextBox, 'raw nested TextBox'); "
        .. "error('KASC_NESTED_HEVO_PROXY')"
    end
    return nil, "unexpected HEVO child " .. tostring(file)
  end,
}
local hevoOk, hevoErr = pcall(campaignFactory, hevoMod, {})
check(hevoOk == false
    and tostring(hevoErr):find("KASC_NESTED_HEVO_PROXY", 1, true) ~= nil,
  "actual HEVO child loader bypassed the scoped TextBox proxy")

local foreignEnv = Sandbox.envFor({
  modId = "foreign_mod",
  permissions = { engine_internals = true },
})
check(foreignEnv.require("src.render.TextBox") == TextBox,
  "KASC proxy leaked into another mod sandbox")
local rawVanilla = TextBox.new(game, vanillaText)
check(#rawVanilla.pages == 1 and #rawVanilla.pages[1] == 3,
  "KASC production controller changed untracked engine text")

prodRegistry:register("TEXT_KA_PRODUCTION", "OWNED\nCONTENT\nLATER")
local rawOwned = TextBox.new(game, prodRegistered.TEXT_KA_PRODUCTION)
check(#rawOwned.pages == 3 and #rawOwned.pages[1] == 1,
  "exact registered KASC content was not gated when opened by the engine")

-- Native token expansion remains exactly once. A handler that deliberately
-- returns token-shaped text must stay literal, matching TextBox's one-pass
-- contract; callbacks and choice/options keep object identity.
local playerCalls, rivalCalls = 0, 0
local tokenGame = {
  save = { player = { name = "BLITZ", rival = "BLAU" } },
  data = { tokens = {
    PLAYER = function() playerCalls = playerCalls + 1 return "{RIVAL}" end,
    RIVAL = function() rivalCalls = rivalCalls + 1 return "BLAU" end,
  } },
}
local done = function() end
local choice = function() end
local optsIdentity = { choice = choice, defaultNo = true }
local tokenBox = scopedTextBox.new(tokenGame,
  "{PLAYER}\nSECOND\nTHIRD", done, optsIdentity)
check(playerCalls == 1 and rivalCalls == 0,
  "KASC pagination expanded a runtime token more than once")
check(tokenBox.pages[1][1] == "{RIVAL}",
  "token-shaped replacement was expanded a second time")
check(tokenBox.onDone == done and tokenBox.choice == choice
    and tokenBox.defaultNo == true,
  "pagination changed callback or choice option identity")

local prodAuto = scopedTextBox.new(game, "ONE\nTWO\nTHREE", nil,
  { auto = true })
local prodInstant = scopedTextBox.new(game, "ONE\nTWO\nTHREE", nil,
  { instant = true })
local prodStay = scopedTextBox.new(game, "ONE\nTWO\nTHREE", nil,
  { stay = {} })
check(#prodAuto.pages[1] == 3 and #prodInstant.pages[1] == 3
    and #prodStay.pages[1] == 3,
  "production proxy changed auto/instant/stay timing")

-- Hot reload rebinds both narrow seams without wrapper nesting or a stale
-- controller. The same sandbox and native TextBox object are retained.
local nativeState = rawget(TextBox, "_kascDialoguePaginationState")
local nativeWrapper = nativeState and nativeState.wrapper
local requireState = rawget(prodEnv, "_kascDialogueRequireState")
local requireWrapper = requireState and requireState.wrapper
local prodReload = prodMake({ path = root, content = { text = prodRegistry } },
  { TextBox = TextBox })
check(rawget(TextBox, "_kascDialoguePaginationState").wrapper == nativeWrapper,
  "hot reload nested the native TextBox seam")
check(rawget(prodEnv, "_kascDialogueRequireState").wrapper == requireWrapper,
  "hot reload nested the sandbox require seam")
check(prodEnv.require("src.render.TextBox") == prodReload.TextBox,
  "hot reload left the sandbox on a stale controller proxy")

-- BattleState is a separate rendering surface. Grand Tour uses this exact
-- CONT-gated string; the real parser must wait before every later authored
-- row instead of scrolling a third row immediately.
local grandTourData = assert(loadfile(root .. "/grand_tour_data.lua"))()
local marina = grandTourData.factory.opponents[2]
check(marina.key == "marina", "Grand Tour MARINA fixture moved")
local battleIntro = prod.gateBattleText(marina.intro.en)
local BattleState = require("src.battle.BattleState")
local battle = setmetatable({}, { __index = BattleState })
battle:startMessage({ text = battleIntro })
local battleWaits = #battle.lines >= 3
for index = 2, #battle.lines do
  battleWaits = battleWaits and battle.lines[index].cont == true
end
check(battleWaits,
  "real BattleState parser can still auto-scroll Grand Tour intro rows")
local grandHandle = assert(io.open(root .. "/grand_tour.lua", "rb"))
local grandSource = grandHandle:read("*a")
grandHandle:close()
check(grandSource:find("dialoguePagination.gateBattleText(intro)", 1, true)
    ~= nil, "Grand Tour does not wire the BattleState pagination seam")

-- Exhaust the module's localized/catalogued source literals. This is not a
-- byte-width approximation: every decoded multiline literal goes through
-- TextBox.paginate and the production guard. legacy_journey is owned and
-- audited by its independent feature test, so it is intentionally excluded.
local files = {}
local pipe = assert(io.popen(("find %q -maxdepth 1 -name '*.lua' -print"):format(root)))
for path in pipe:lines() do
  if not path:match("/legacy_journey%.lua$") then files[#files + 1] = path end
end
pipe:close()
table.sort(files)

local literals, multiline = 0, 0
local function scanStrings(body, visit)
  local index, length = 1, #body
  while index <= length do
    if body:sub(index, index + 3) == "--[[" then
      index = (body:find("]]", index + 4, true) or length - 1) + 2
    elseif body:sub(index, index + 1) == "--" then
      index = (body:find("\n", index + 2, true) or length) + 1
    else
      local quote = body:sub(index, index)
      if quote == '"' or quote == "'" then
        local first, cursor = index, index + 1
        while cursor <= length do
          local char = body:sub(cursor, cursor)
          if char == "\\" then
            cursor = cursor + 2
          elseif char == quote then
            local raw = body:sub(first, cursor)
            local chunk = loadstring("return " .. raw)
            if chunk then
              local ok, value = pcall(chunk)
              if ok and type(value) == "string" then visit(value) end
            end
            index = cursor + 1
            break
          else
            cursor = cursor + 1
          end
        end
        if cursor > length then index = length + 1 end
      else
        index = index + 1
      end
    end
  end
end

for _, path in ipairs(files) do
  local handle = assert(io.open(path, "rb"))
  local body = handle:read("*a")
  handle:close()
  scanStrings(body, function(value)
    literals = literals + 1
    if value:find("\n", 1, true) then
      multiline = multiline + 1
      assertSafe(path, pagination.gateText(game, value))
    end
  end)
end
check(#files >= 100, "source catalogue unexpectedly small")
check(literals >= 5000, "too few source literals were audited")
check(multiline >= 1000, "too few multiline dialogue literals were audited")

local mainHandle = assert(io.open(root .. "/main.lua", "rb"))
local mainSource = mainHandle:read("*a")
mainHandle:close()
check(mainSource:find('loadSibling(mod, "dialogue_pagination.lua")', 1, true)
    ~= nil and mainSource:find("wrapLocalization(i18n)", 1, true) ~= nil,
  "main does not install the production pagination guard before siblings")

print(("PASS dialogue pagination: %d checks, %d files, %d literals, %d multiline")
  :format(checks, #files, literals, multiline))
