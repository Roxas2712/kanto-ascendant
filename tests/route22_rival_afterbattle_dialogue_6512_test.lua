-- Route 22 has two distinct post-victory text phases: the immediate defeat
-- line and the farewell before the rival walks away.  Identity overlays must
-- own both phases; otherwise Red/Green fall back to Blue's cartridge voice.

local source = debug.getinfo(1, "S").source:sub(2)
local root = source:match("^(.*)/tests/") or "."
local dialogue = assert(loadfile(root .. "/character_dialogue.lua"))()

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end

local keys = {
  "_Route22Rival1DefeatedText",
  "_Route22RivalAfterBattleText1",
  "_Route22Rival2DefeatedText",
  "_Route22RivalAfterBattleText2",
}

local function placeholders(value)
  local found = {}
  for token in tostring(value):gmatch("%b{}") do found[#found + 1] = token end
  table.sort(found)
  return table.concat(found, ",")
end

local function safe(label, value)
  check(type(value) == "string" and value ~= "", label .. " is empty")
  for page in (value .. "\f"):gmatch("(.-)\f") do
    local rows = 1
    for _ in page:gmatch("\n") do rows = rows + 1 end
    check(rows <= 2, label .. " exceeds the two-row textbox contract")
  end
end

for _, identity in ipairs({ "RED", "GREEN" }) do
  local rows = assert(dialogue.rival[identity])
  for _, key in ipairs(keys) do
    local pair = rows[key]
    check(type(pair) == "table", identity .. " does not own " .. key)
    safe(identity .. " " .. key .. " EN", pair[1])
    safe(identity .. " " .. key .. " DE", pair[2])
    check(placeholders(pair[1]) == placeholders(pair[2]),
      identity .. " " .. key .. " changes placeholders between EN and DE")
  end
end

check(dialogue.rival.RED._Route22RivalAfterBattleText1[1]
    ~= dialogue.rival.GREEN._Route22RivalAfterBattleText1[1],
  "Red and Green share a generic first Route 22 farewell")
check(dialogue.rival.RED._Route22RivalAfterBattleText2[1]
    ~= dialogue.rival.GREEN._Route22RivalAfterBattleText2[1],
  "Red and Green share a generic late Route 22 farewell")

print(("Route 22 rival after-battle dialogue 6.5.12: PASS (%d checks)")
  :format(checks))
