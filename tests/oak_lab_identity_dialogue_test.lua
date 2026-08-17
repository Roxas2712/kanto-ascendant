-- Oak Lab identity contract for the 6.5.6 kinship hotfix.
--
-- Blue is Professor Oak's only grandchild in Kanto Ascendant. Red and Green
-- must retain their authored voices through every classic and Yellow starter
-- branch without inheriting Blue's Gramps/Opa, sister or cousin references.

local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/") or "."
local dialogue = assert(loadfile(root .. "/character_dialogue.lua"))()

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local classicFlow = {
  "_OaksLabRivalGoAheadAndChooseText",
  "_OaksLabRivalIllTakeThisOneText",
  "_OaksLabRivalReceivedMonText",
  "_OaksLabRivalMyPokemonLooksStrongerText",
  "_OaksLabRivalIllTakeYouOnText",
  "_OaksLabRivalIPickedTheWrongPokemonText", -- player wins
  "_Rival1WinText",                         -- player loses
  "_OaksLabRivalSmellYouLaterText",
  "_OaksLabRivalGrampsText",
  "_OaksLabRivalWhatDidYouCallMeForText",
  "_OaksLabRivalLeaveItAllToMeText",
}

local yellowFlow = {
  "_OaksLabRivalGrampsIsntAroundText",
  "_OaksLabRivalIllGetABetterPokemonThanYou",
  "_OaksLabRivalTakesText1",
  "_OaksLabRivalTakesText2",
  "_OaksLabRivalTakesText3",
  "_OaksLabRivalTakesText4",
  "_OaksLabRivalTakesText5",
  "_OaksLabRivalMyPokemonLooksStrongerText",
  "_OaksLabRivalIllTakeYouOnText",
  "_OaksLabRivalIPickedTheWrongPokemonText", -- player wins
  "_Rival1WinText",                         -- player loses
  "_OaksLabRivalSmellYouLaterText",
  "_OaksLabRivalGrampsText",
  "_OaksLabRivalMyPokemonHasGrownStrongerText",
  "_OaksLabRivalLeaveItAllToMeText",
}

local allOakKeys = {
  "_OaksLabRivalAmIGreatOrWhatText",
  "_OaksLabRivalFedUpWithWaitingText",
  "_OaksLabRivalGoAheadAndChooseText",
  "_OaksLabRivalGrampsIsntAroundText",
  "_OaksLabRivalGrampsText",
  "_OaksLabRivalIPickedTheWrongPokemonText",
  "_OaksLabRivalIllGetABetterPokemonThanYou",
  "_OaksLabRivalIllTakeThisOneText",
  "_OaksLabRivalIllTakeYouOnText",
  "_OaksLabRivalLeaveItAllToMeText",
  "_OaksLabRivalMyPokemonHasGrownStrongerText",
  "_OaksLabRivalMyPokemonLooksStrongerText",
  "_OaksLabRivalReceivedMonText",
  "_OaksLabRivalSmellYouLaterText",
  "_OaksLabRivalTakesText1",
  "_OaksLabRivalTakesText2",
  "_OaksLabRivalTakesText3",
  "_OaksLabRivalTakesText4",
  "_OaksLabRivalTakesText5",
  "_OaksLabRivalWhatAboutMeText",
  "_OaksLabRivalWhatDidYouCallMeForText",
}

local function tokens(value)
  local found = {}
  for token in tostring(value):gmatch("%b{}") do found[#found + 1] = token end
  table.sort(found)
  return table.concat(found, ",")
end

local function pageBreaks(value)
  local _, count = tostring(value):gsub("\f", "")
  return count
end

local forbidden = {
  "grandpa", "grandfather", "grandson", "granddaughter", "grandchild",
  "cousin", "opa", "großvater", "grossvater", "enkel", "enkelin",
  "sister", "schwester",
}

local function hasForbiddenKinship(value)
  local lower = tostring(value):lower()
  for _, word in ipairs(forbidden) do
    if lower:find("%f[%a]" .. word .. "%f[%A]") then return word end
  end
end

check(dialogue.rival.BLUE == nil,
  "Blue gained an overlay instead of retaining the native grandson voice")
check(dialogue.selection.BLUE.relation[1] == "MY GRANDSON",
  "Blue lost his canonical Oak-grandson relationship")
check(dialogue.introAsk.BLUE[1]:find("grand-\nson", 1, true) ~= nil,
  "Oak no longer introduces Blue as his grandson")

for _, identity in ipairs({ "RED", "GREEN" }) do
  local rows = assert(dialogue.rival[identity])
  for _, key in ipairs(allOakKeys) do
    local pair = rows[key]
    check(type(pair) == "table" and type(pair[1]) == "string"
        and pair[1] ~= "" and type(pair[2]) == "string" and pair[2] ~= "",
      identity .. " does not own bilingual Oak Lab key " .. key)
    check(tokens(pair[1]) == tokens(pair[2]),
      identity .. " changes placeholders between EN/DE for " .. key)
    check(pageBreaks(pair[1]) == pageBreaks(pair[2]),
      identity .. " changes pagination between EN/DE for " .. key)
    check(not hasForbiddenKinship(pair[1]),
      identity .. " inherits family wording in EN " .. key)
    check(not hasForbiddenKinship(pair[2]),
      identity .. " inherits family wording in DE " .. key)
  end

  for _, flow in ipairs({ classicFlow, yellowFlow }) do
    for step, key in ipairs(flow) do
      check(rows[key] ~= nil,
        identity .. " ordered Oak Lab flow loses step " .. step .. " " .. key)
    end
  end

  check(not hasForbiddenKinship(dialogue.selection[identity].relation[1]),
    identity .. " selector invents an Oak family relationship")
  check(not hasForbiddenKinship(dialogue.selection[identity].relation[2]),
    identity .. " German selector invents an Oak family relationship")
  check(not hasForbiddenKinship(dialogue.introAsk[identity][1]),
    identity .. " intro invents an Oak family relationship")
  check(not hasForbiddenKinship(dialogue.introAsk[identity][2]),
    identity .. " German intro invents an Oak family relationship")
end

check(dialogue.rival.RED._OaksLabRivalTakesText4[1]
    :find("asked", 1, true) ~= nil,
  "Red does not calmly acknowledge taking the intended ball")
check(dialogue.rival.GREEN._OaksLabRivalTakesText1[1]
    :find("Was this yours", 1, true) ~= nil,
  "Green does not realize she picked the intended ball")
check(not dialogue.rival.RED._OaksLabRivalTakesText2[1]
    :find("snatched", 1, true),
  "Red still implausibly snatches the intended ball")

-- Resolve both ordered editions for all three rival identities. Blue must
-- return the untouched engine baseline while Red/Green resolve every authored
-- step. This mirrors the runtime restore-then-overlay contract.
local baseline = setmetatable({}, {
  __index = function(_, key) return "BLUE_NATIVE:" .. tostring(key) end,
})
local function resolve(identity, key)
  local overlay = dialogue.rival[identity]
  return overlay and overlay[key] and overlay[key][1] or baseline[key]
end
for _, identity in ipairs({ "BLUE", "RED", "GREEN" }) do
  for _, flow in ipairs({ classicFlow, yellowFlow }) do
    for step, key in ipairs(flow) do
      local value = resolve(identity, key)
      check(type(value) == "string" and value ~= "",
        identity .. " cannot resolve ordered Oak Lab step " .. step .. " " .. key)
      if identity == "BLUE" then
        check(value == "BLUE_NATIVE:" .. key,
          "Blue ordered Oak Lab step was rewritten: " .. key)
      else
        check(value ~= "BLUE_NATIVE:" .. key,
          identity .. " ordered Oak Lab step leaked Blue: " .. key)
      end
    end
  end
end

io.stdout:write(("oak_lab_identity_dialogue_test: %d checks passed\n")
  :format(checks))
