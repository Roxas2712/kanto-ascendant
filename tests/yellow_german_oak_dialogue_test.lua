-- Narrow regression contract for the 6.5.7 Yellow Oak's Lab German fix.
-- This deliberately pins the adjacent English text so a localization-only
-- hotfix cannot silently broaden into the later character-dialogue rewrite.

local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/") or "."
local dialogue = assert(loadfile(root .. "/character_dialogue.lua"))()
local row = assert(dialogue.rival.GREEN._OaksLabRivalTakesText1)

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local expectedEnglish = "{RIVAL}: {PLAYER},\nI picked this one!\f...Wait. Was this yours?"
local expectedGerman = "{RIVAL}: Ich nehme\ndieses POKéMON!\fMoment, {PLAYER}!\nWar das für dich?"
local rejectedGerman = "{RIVAL}: {PLAYER},\nich nahm dieses!\f...Moment. War das deins?"

check(row[1] == expectedEnglish,
  "the 6.5.7 German-only fix changed the English Oak's Lab line")
check(row[2] == expectedGerman,
  "the Yellow Oak's Lab German line is not the approved grammatical text")
check(row[2] ~= rejectedGerman,
  "the ungrammatical public 6.5.6 German line is still present")

local function tokenSignature(text)
  local tokens = {}
  for token in text:gmatch("%b{}") do tokens[#tokens + 1] = token end
  table.sort(tokens)
  return table.concat(tokens, ",")
end

check(tokenSignature(row[1]) == tokenSignature(row[2]),
  "the correction changed runtime placeholder coverage")

local pages = {}
for page in (row[2] .. "\f"):gmatch("(.-)\f") do
  pages[#pages + 1] = page
end
check(#pages == 2, "the approved authored page break was not preserved")
for index, page in ipairs(pages) do
  local lines = {}
  for line in (page .. "\n"):gmatch("(.-)\n") do
    lines[#lines + 1] = line
  end
  check(#lines == 2,
    "German page " .. index .. " does not use exactly two visible rows")
  for lineIndex, line in ipairs(lines) do
    check(#line <= 18,
      ("German page %d row %d exceeds the 18-character authored limit")
        :format(index, lineIndex))
  end
end

io.stdout:write(("yellow_german_oak_dialogue_test: %d checks passed\n")
  :format(checks))
