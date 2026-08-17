-- Rival identity contract for 6.5.5.
-- Blue remains the loaded cartridge/translation voice. Red and Green own
-- complete bilingual overlays for every supported story and post-game scene.

local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/") or "."
local dialogue = assert(loadfile(root .. "/character_dialogue.lua"))()
local postgameDialogue = assert(loadfile(root .. "/postgame_dialogue.lua"))()

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local storyKeys = {
  "_OaksLabRivalFedUpWithWaitingText",
  "_OaksLabRivalGrampsIsntAroundText",
  "_OaksLabRivalGrampsText",
  "_OaksLabRivalWhatAboutMeText",
  "_OaksLabRivalWhatDidYouCallMeForText",
  "_OaksLabRivalGoAheadAndChooseText",
  "_OaksLabRivalIllGetABetterPokemonThanYou",
  "_OaksLabRivalIllTakeThisOneText",
  "_OaksLabRivalReceivedMonText",
  "_OaksLabRivalTakesText1",
  "_OaksLabRivalTakesText2",
  "_OaksLabRivalTakesText3",
  "_OaksLabRivalTakesText4",
  "_OaksLabRivalTakesText5",
  "_OaksLabRivalIllTakeYouOnText",
  "_OaksLabRivalLeaveItAllToMeText",
  "_OaksLabRivalSmellYouLaterText",
  "_OaksLabRivalMyPokemonHasGrownStrongerText",
  "_OaksLabRivalMyPokemonLooksStrongerText",
  "_OaksLabRivalIPickedTheWrongPokemonText",
  "_OaksLabRivalAmIGreatOrWhatText",
  "_Rival1WinText",
  "_CeruleanCityRivalPreBattleText",
  "_CeruleanCityRivalDefeatedText",
  "_CeruleanCityRivalIWentToBillsText",
  "_PokemonTower2FRivalWhatBringsYouHereText",
  "_PokemonTower2FRivalDefeatedText",
  "_PokemonTower2FRivalVictoryText",
  "_Route22RivalBeforeBattleText1",
  "_Route22Rival1VictoryText",
  "_Route22RivalBeforeBattleText2",
  "_Route22Rival2VictoryText",
  "_SSAnne2FRivalText",
  "_SSAnne2FRivalDefeatedText",
  "_SSAnne2FRivalCutMasterText",
  "_SilphCo7FRivalText",
  "_SilphCo7FRivalWaitedHereText",
  "_SilphCo7FRivalDefeatedText",
  "_SilphCo7FRivalVictoryText",
  "_ChampionsRoomRivalIntroText",
  "_RivalDefeatedText",
  "_RivalVictoryText",
}

local function placeholders(value)
  local found = {}
  for token in tostring(value):gmatch("{([A-Z_]+)}") do
    found[token] = (found[token] or 0) + 1
  end
  local out = {}
  for token, count in pairs(found) do
    out[#out + 1] = token .. ":" .. count
  end
  table.sort(out)
  return table.concat(out, ",")
end

local storyKeySet = {}
for _, key in ipairs(storyKeys) do storyKeySet[key] = true end
check(#storyKeys == 42, "story contract no longer contains 42 keys")
check(dialogue.rival.BLUE == nil,
  "Blue gained an overlay instead of preserving native R/B/Y dialogue")
for _, identity in ipairs({ "RED", "GREEN" }) do
  local rows, count = assert(dialogue.rival[identity]), 0
  for key in pairs(rows) do
    count = count + 1
    check(storyKeySet[key], identity .. " has an unsupported story key " .. key)
  end
  check(count == #storyKeys, identity .. " does not own exactly 42 story keys")
  for _, key in ipairs(storyKeys) do
    local pair = rows[key]
    check(type(pair) == "table" and type(pair[1]) == "string"
        and pair[1] ~= "" and type(pair[2]) == "string" and pair[2] ~= "",
      identity .. " " .. key .. " is not complete in EN+DE")
    check(placeholders(pair[1]) == placeholders(pair[2]),
      identity .. " " .. key .. " loses a placeholder in translation")
  end
end

check(dialogue.rival.RED._OaksLabRivalGoAheadAndChooseText[1]
    :find("Good for you", 1, true) ~= nil,
  "Red's polite starter-choice voice regressed")
check(dialogue.rival.RED._PokemonTower2FRivalWhatBringsYouHereText[1]
    :find("respects", 1, true) ~= nil,
  "Red's thoughtful Tower voice regressed")
check(dialogue.rival.GREEN._OaksLabRivalGoAheadAndChooseText[1]
    :find("Probably", 1, true) ~= nil,
  "Green's scattered starter-choice voice regressed")
check(dialogue.rival.GREEN._OaksLabRivalIllTakeYouOnText[1]
    :find("research", 1, true) ~= nil,
  "Green's playful first-battle voice regressed")
check(dialogue.introAsk.RED[1]:find("listens", 1, true) ~= nil,
  "Oak no longer introduces Red's quiet identity")
check(dialogue.introAsk.GREEN[1]:find("plans", 1, true) ~= nil,
  "Oak no longer introduces Green's scattered identity")

local blueHuntBefore = "{RIVAL}: So the rumors\nwere true!\fYou already found a\nlegend.\fDo not think you will\nclaim the rest alone.\fI built a team to\ntrack powers like\nthese.\fBeat me, and I will\nshare my readings.\fLegend Hunter battle.\nAccept?"
check(postgameDialogue.huntRival.before.en == blueHuntBefore,
  "Blue's native post-game baseline was rewritten")

local function validatePostgame(identity)
  local hunt = assert(postgameDialogue.huntRival[identity])
  for _, key in ipairs({ "before", "decline", "win", "after" }) do
    check(type(hunt[key]) == "table" and type(hunt[key].en) == "string"
        and type(hunt[key].de) == "string",
      identity .. " Legend Hunt " .. key .. " is not bilingual")
    check(placeholders(hunt[key].en) == placeholders(hunt[key].de),
      identity .. " Legend Hunt " .. key .. " loses a placeholder")
  end
  local elite = assert(postgameDialogue.elite.OPP_RIVAL3[identity])
  for _, key in ipairs({ "before", "win", "after" }) do
    check(type(elite.apex[key].en) == "string"
        and type(elite.apex[key].de) == "string",
      identity .. " APEX " .. key .. " is not bilingual")
    check(placeholders(elite.apex[key].en)
        == placeholders(elite.apex[key].de),
      identity .. " APEX " .. key .. " loses a placeholder")
  end
  for _, key in ipairs({ "before", "beforeNoLegend", "win", "after" }) do
    check(type(elite.crown[key].en) == "string"
        and type(elite.crown[key].de) == "string",
      identity .. " CROWN " .. key .. " is not bilingual")
    check(placeholders(elite.crown[key].en)
        == placeholders(elite.crown[key].de),
      identity .. " CROWN " .. key .. " loses a placeholder")
  end
end
validatePostgame("RED")
validatePostgame("GREEN")

-- The two runtime selectors are tested independently from story edition.
-- This protects Red/Blue/Yellow because all three editions share this
-- identity resolver rather than carrying separate rewritten dialogue copies.
local activeIdentity, german = "BLUE", false
local function translate(en, de) return german and de or en end
local events = assert(loadfile(root .. "/postgame_events.lua"))()(
  { dialogue = postgameDialogue, legendOrder = {} }, {
    tr = translate,
    localized = function(row) return row and translate(row.en, row.de) end,
    legendSetting = function() return "off" end,
    legendaryAvailable = function() return false end,
    caught = function() return false end,
    phaseFor = function() return "story" end,
    rivalIdentity = function() return activeIdentity end,
  })
check(events.huntRivalDialogue("before") == blueHuntBefore,
  "Blue Legend Hunt did not retain the root baseline")
activeIdentity = "RED"
check(events.huntRivalDialogue("before"):find("stay calm", 1, true) ~= nil,
  "Red Legend Hunt did not resolve at runtime")
activeIdentity, german = "GREEN", true
check(events.huntRivalDialogue("before"):find("Notizen", 1, true) ~= nil,
  "Green Legend Hunt did not resolve in German")

local function registry()
  return { register = function() end, patch = function() end,
    get = function() return nil end }
end
local mod = {
  id = "kanto_ascendant", path = root, exports = {},
  save = { get = function(_, _, fallback) return fallback end,
    set = function() end },
  options = { get = function() return nil end },
  content = { maps = registry(), map_scripts = registry(),
    items = registry(), battle_sprite_scales = registry() },
  hooks = { wrap = function() end }, events = { on = function() end },
  world = { overworld = function() return nil end },
  log = { warn = function() end },
}
function mod:read(relative)
  local handle = io.open(root .. "/" .. relative, "rb")
  if not handle then return nil end
  local body = handle:read("*a")
  handle:close()
  return body
end
local postgameData = assert(loadfile(root .. "/postgame_data.lua"))()
postgameData.dialogue = postgameDialogue
activeIdentity, german = "BLUE", false
local postgame = assert(loadfile(root .. "/postgame.lua"))()(mod, postgameData, {
  contentEnabled = false,
  i18n = { text = translate },
  rivalIdentity = function() return activeIdentity end,
})
check(postgame.eliteDialogue("OPP_RIVAL3", "apex", "before")
    :find("Took you long", 1, true) ~= nil,
  "Blue APEX dialogue did not retain the root baseline")
activeIdentity = "RED"
check(postgame.eliteDialogue("OPP_RIVAL3", "apex", "before")
    :find("patience", 1, true) ~= nil,
  "Red APEX dialogue did not resolve at runtime")
activeIdentity, german = "GREEN", true
check(postgame.eliteDialogue("OPP_RIVAL3", "crown", "before")
    :find("Krone", 1, true) ~= nil,
  "Green CROWN dialogue did not resolve in German")

-- Run every authored row through the production pagination guard. Runtime
-- tokens stay raw and no page may retain a third auto-scrolling row.
local TextBox = require("src.render.TextBox")
local makePagination = assert(loadfile(root .. "/dialogue_pagination.lua"))()
local pagination = makePagination({ path = root, content = { text = registry() } },
  { TextBox = TextBox })
local function safe(label, value)
  local gated = pagination.gateText({}, value)
  local pages = TextBox.paginate(gated, 18)
  for index, page in ipairs(pages) do
    check(#page <= 2, label .. " page " .. index .. " still auto-scrolls")
  end
end
for _, identity in ipairs({ "RED", "GREEN" }) do
  for _, key in ipairs(storyKeys) do
    for language = 1, 2 do
      safe(identity .. " " .. key .. " " .. language,
        dialogue.rival[identity][key][language])
    end
  end
  for _, key in ipairs({ "before", "decline", "win", "after" }) do
    safe(identity .. " hunt " .. key .. " EN",
      postgameDialogue.huntRival[identity][key].en)
    safe(identity .. " hunt " .. key .. " DE",
      postgameDialogue.huntRival[identity][key].de)
  end
  for _, tier in ipairs({ "apex", "crown" }) do
    for key, pair in pairs(postgameDialogue.elite.OPP_RIVAL3[identity][tier]) do
      safe(identity .. " " .. tier .. " " .. key .. " EN", pair.en)
      safe(identity .. " " .. tier .. " " .. key .. " DE", pair.de)
    end
  end
end

print(("rival personality dialogue tests passed (%d checks)"):format(checks))
