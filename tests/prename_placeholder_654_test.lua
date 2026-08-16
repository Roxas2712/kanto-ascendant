-- Bug 7 / 6.5.4: the hosted Oak character prologue knows identity,
-- portrait, pronouns and relationship before naming, but no player/rival
-- name slot may pre-empt the canonical naming screen.  This ROM-free draw
-- receipt exercises the exact CharacterSelect draw seam used by engine
-- 0.1.96 for Red, Blue and Yellow in English and German.

local engineDir = os.getenv("KA_ENGINE_DIR")
package.path = (engineDir and (engineDir .. "/?.lua;"
  .. engineDir .. "/?/init.lua;") or "")
  .. "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Font = require("src.render.Font")
local GameVersion = require("src.core.GameVersion")
local EngineVersion = require("src.core.Version")

local expectedEngine = os.getenv("KA_EXPECT_ENGINE")
if expectedEngine then
  T.eq(EngineVersion.engine, expectedEngine,
    "draw receipt uses the requested exact engine payload")
end

local modPath = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")
local makeCharacters = assert(loadfile(
  modPath .. "/extended_characters.lua"))()
local dialogue = assert(loadfile(modPath .. "/character_dialogue.lua"))()

local function insertStepAfter(steps, anchorId, step)
  local anchor
  for index, row in ipairs(steps) do
    if row.id == anchorId then anchor = index break end
  end
  table.insert(steps, anchor and (anchor + 1) or (#steps + 1), step)
  return steps
end

local function stubMod(opts)
  opts = opts or {}
  local saved = opts.saved or {}
  local hooks = {}
  local mod = {
    id = "kanto_ascendant",
    path = modPath,
    read = function() return nil end,
    save = {
      get = function(_, key) return saved[key] end,
      set = function(_, key, value)
        if opts.failSet then error("injected mod.save write failure") end
        saved[key] = value
      end,
    },
    options = { get = function() return "crystal" end },
    hooks = { wrap = function(_, name, callback)
      hooks[name] = hooks[name] or {}
      hooks[name][#hooks[name] + 1] = callback
    end },
    events = { on = function() end, once = function() end },
    ui = { insertStepAfter = insertStepAfter },
    log = { error = function() end },
  }
  return mod, hooks, saved
end

local oldVersion = GameVersion.get()
local oldDraw, oldDrawBox, oldDrawCode = Font.draw, Font.drawBox, Font.drawCode
local draws = {}
Font.draw = function(value, x, y)
  draws[#draws + 1] = { value = tostring(value), x = x, y = y }
end
Font.drawBox = function() end
Font.drawCode = function() end

local expectedIdentity = {
  en = { GREEN = "GREEN", BLUE = "BLUE", RED = "RED" },
  de = { GREEN = "GRÜN", BLUE = "BLAU", RED = "ROT" },
}
local expectedRelation = {
  en = {
    GREEN = "MY GRANDDAUGHTER", BLUE = "MY GRANDSON",
    RED = "A BOY FROM\nPALLET TOWN",
  },
  de = {
    GREEN = "MEINE ENKELIN", BLUE = "MEIN ENKEL",
    RED = "EIN JUNGE AUS\nALABASTIA",
  },
}

local receipts = 0
for _, edition in ipairs({ "red", "blue", "yellow" }) do
  GameVersion.set(edition)
  for _, locale in ipairs({ "en", "de" }) do
    local characters = makeCharacters(stubMod(), {
      dialogue = dialogue,
      i18n = {
        text = function(en, de) return locale == "de" and de or en end,
      },
    })
    for _, identity in ipairs(characters.selectionOrder) do
      T.eq(characters.selectionLabel(identity),
        expectedIdentity[locale][identity],
        edition .. "/" .. locale .. " retains known " .. identity
          .. " identity outside the editable name slot")
    end

    for selectedIndex, selectedIdentity in ipairs(characters.selectionOrder) do
      draws = {}
      local selector = setmetatable({
        index = selectedIndex,
        fallbackPortraits = {},
        useScreenSpacePortrait = false,
      }, characters.CharacterSelect)
      selector:draw()

      local slots, relationLines = {}, {}
      for _, draw in ipairs(draws) do
        if draw.x == 24 and (draw.y == 24 or draw.y == 40 or draw.y == 56) then
          slots[#slots + 1] = draw.value
        elseif draw.y == 104 or draw.y == 112 or draw.y == 120 then
          relationLines[#relationLines + 1] = draw.value
        end
      end
      T.eq(table.concat(slots, ","), "???,???,???",
        edition .. "/" .. locale .. "/" .. selectedIdentity
          .. " draws exactly three pre-name placeholders")
      T.eq(table.concat(relationLines, "\n"),
        expectedRelation[locale][selectedIdentity],
        edition .. "/" .. locale .. "/" .. selectedIdentity
          .. " may retain relationship copy while names stay hidden")
      receipts = receipts + 1
      io.stdout:write(("DRAW_RECEIPT engine=%s edition=%s locale=%s "
        .. "identity=%s player_slots=%s relation=known\n")
        :format(EngineVersion.engine, edition, locale, selectedIdentity,
          table.concat(slots, "|")))
    end
  end
end

-- The placeholder is state-independent by design. Prove the lifecycle edges
-- which previously allowed a provisional/default name to leak back in.
local lifecycleMod, lifecycleHooks = stubMod()
local lifecycleCharacters = makeCharacters(lifecycleMod, {
  dialogue = dialogue,
  i18n = { text = function(en) return en end },
})
for _, identity in ipairs(lifecycleCharacters.selectionOrder) do
  T.eq(lifecycleCharacters.preNamingName("player", identity), "???",
    identity .. " player slot is unknown before canonical naming")
  T.eq(lifecycleCharacters.preNamingName("rival", identity), "???",
    identity .. " rival slot is unknown before canonical naming")
end

local function drawnSlots(characters, input, player)
  draws = {}
  local selector = setmetatable({
    game = {
      input = input or { wasPressed = function() return false end },
      save = { player = player or {} },
    },
    index = 1, fallbackPortraits = {}, useScreenSpacePortrait = false,
  }, characters.CharacterSelect)
  selector:draw()
  local slots = {}
  for _, draw in ipairs(draws) do
    if draw.x == 24 and (draw.y == 24 or draw.y == 40 or draw.y == 56) then
      slots[#slots + 1] = draw.value
    end
  end
  return table.concat(slots, ","), selector
end

local beforeSlots, cancelSelector = drawnSlots(lifecycleCharacters)
T.eq(beforeSlots, "???,???,???", "first entry remains fully unknown")
cancelSelector.game.input = {
  wasPressed = function(_, key) return key == "b" end,
}
cancelSelector:update()
local afterBack = drawnSlots(lifecycleCharacters)
T.eq(afterBack, "???,???,???",
  "back/cancel and re-entry cannot reveal a provisional name")

local failedMod = stubMod({ failSet = true })
local failedCharacters = makeCharacters(failedMod, {
  dialogue = dialogue,
  i18n = { text = function(en) return en end },
})
local selectionOk = pcall(failedCharacters.select, "GREEN")
T.eq(selectionOk, false, "injected identity write fails closed")
T.eq(drawnSlots(failedCharacters), "???,???,???",
  "failed identity write leaves every re-entered name slot unknown")

local introHook = assert(lifecycleHooks["intro.oak_speech.build"]
  and lifecycleHooks["intro.oak_speech.build"][1],
  "Oak intro hook was not registered")
local steps = introHook(function(rows) return rows end, {
  { id = "world_spiel", kind = "say" },
  { id = "name_player", kind = "name" },
  { id = "ask_rival_name", kind = "say" },
  { id = "name_rival", kind = "name" },
}, {})
local byId = {}
for _, step in ipairs(steps) do byId[step.id] = step end

local Screens = require("src.ui.Screens")
local originalPush, pushed = Screens.push, nil
Screens.push = function(_, id, opts) pushed = { id = id, opts = opts } end
local failedNameAnswers, failedNameDone = 0, 0
local rejectingPlayer = setmetatable({}, {
  __newindex = function() error("injected canonical name write failure") end,
})
byId.name_player.run({
  game = { save = { player = rejectingPlayer } }, nameLen = 7,
  recordAnswer = function() failedNameAnswers = failedNameAnswers + 1 end,
}, function() failedNameDone = failedNameDone + 1 end)
local nameWriteOk = pcall(pushed.opts.onDone, "LEAF")
T.eq(nameWriteOk, false, "injected canonical player-name write fails")
T.eq(failedNameAnswers, 0,
  "failed canonical name write records no successful answer")
T.eq(failedNameDone, 0,
  "failed canonical name write never advances to a named page")
T.eq(drawnSlots(lifecycleCharacters), "???,???,???",
  "canonical name write failure stays unknown on re-entry")

-- A new module instance models a reload. Existing canonical save names are
-- neither cleared nor rewritten, while the pre-name screen remains unknown.
local existingPlayer = { name = "VETERAN", rival = "CHAMP" }
local reloadMod = stubMod({ saved = {
  extended_characters = {
    version = 1, enabled = true, player_character = "BLUE",
    rival_character = "GREEN", third_character = "RED",
  },
} })
local reloadCharacters = makeCharacters(reloadMod, {
  dialogue = dialogue,
  i18n = { text = function(en) return en end },
})
T.eq(drawnSlots(reloadCharacters, nil, existingPlayer), "???,???,???",
  "reload before a new naming confirmation remains unknown")
T.eq(existingPlayer.name, "VETERAN",
  "existing canonically named player save remains unchanged")
T.eq(existingPlayer.rival, "CHAMP",
  "existing canonically named rival save remains unchanged")

-- Successful callbacks are still the only reveal authority. They write and
-- advance once, and the next authored confirmation resolves that exact name
-- once rather than a selector identity/default.
lifecycleCharacters.select("BLUE")
local answerCount, doneCount = 0, 0
local namedSpeech = {
  game = { save = { player = {} } }, nameLen = 7,
  recordAnswer = function() answerCount = answerCount + 1 end,
}
byId.name_player.run(namedSpeech, function() doneCount = doneCount + 1 end)
pushed.opts.onDone("LEAF")
T.eq(namedSpeech.game.save.player.name, "LEAF",
  "successful player naming writes the selected name")
T.eq(answerCount, 1, "successful player naming records exactly once")
T.eq(doneCount, 1, "successful player naming advances exactly once")

byId.name_rival.run(namedSpeech, function() doneCount = doneCount + 1 end)
pushed.opts.onDone("IVY")
local confirmation, confirmationDone = nil, 0
byId.extended_rival_confirmation.run({
  game = namedSpeech.game,
  applyPic = function() end,
  sayText = function(_, line, done)
    confirmation = line:gsub("{RIVAL}", namedSpeech.game.save.player.rival)
    done()
  end,
}, function() confirmationDone = confirmationDone + 1 end)
local _, rivalNameCount = confirmation:gsub("IVY", "IVY")
T.eq(namedSpeech.game.save.player.rival, "IVY",
  "successful rival naming writes the selected name")
T.eq(answerCount, 2,
  "player and rival confirmations each record exactly once")
T.eq(doneCount, 2,
  "player and rival confirmations each advance exactly once")
T.eq(rivalNameCount, 1,
  "subsequent Oak confirmation resolves the selected rival name once")
T.eq(confirmationDone, 1,
  "subsequent named confirmation page completes exactly once")
Screens.push = originalPush

Font.draw, Font.drawBox, Font.drawCode = oldDraw, oldDrawBox, oldDrawCode
GameVersion.set(oldVersion)

T.eq(receipts, 18,
  "draw receipt covers R/B/Y x EN/DE x RED/GREEN/BLUE")
T.finish("prename_placeholder_654_test")
