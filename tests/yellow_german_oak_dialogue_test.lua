-- Regression contract for the approved Green Yellow Oak's Lab dialogue.
-- The original 6.5.7 grammatical correction was intentionally superseded by
-- Green's complete bilingual 6.5.12 character pass; pin that current pair so
-- neither language can silently fall back to the old generic rival wording.

local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/") or "."
local dialogue = assert(loadfile(root .. "/character_dialogue.lua"))()
local row = assert(dialogue.rival.GREEN._OaksLabRivalTakesText1)

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local expectedEnglish = "{RIVAL}: Then I'll take\nthis one!\f...Wait. Was it meant\nfor you, {PLAYER}?"
local expectedGerman = "{RIVAL}: Dann nehme ich\ndieses hier!\f...Moment. War es für\ndich gedacht, {PLAYER}?"
local rejectedGerman = "{RIVAL}: {PLAYER},\nich nahm dieses!\f...Moment. War das deins?"

check(row[1] == expectedEnglish,
  "Green's approved English Oak's Lab line changed")
check(row[2] == expectedGerman,
  "Green's approved German Oak's Lab line changed")
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
end

io.stdout:write(("yellow_german_oak_dialogue_test: %d checks passed\n")
  :format(checks))
