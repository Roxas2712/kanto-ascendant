local root = os.getenv("KANTO_ASCENDANT_MOD_DIR") or "."
local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message or "check failed")
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ") .. ": expected "
    .. tostring(expected) .. ", got " .. tostring(actual))
end
local function glyphCount(text)
  local count = 0
  for _ in tostring(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    count = count + 1
  end
  return count
end
local function fits(text, message)
  for line in (tostring(text) .. "\n"):gmatch("([^\n]*)\n") do
    for pageLine in (line .. "\f"):gmatch("([^\f]*)\f") do
      check(glyphCount(pageLine) <= 18,
        message .. " exceeds 18 glyphs: " .. pageLine)
    end
  end
end

local language = "en"
local queues = {}
local function queue(purpose, ...)
  queues[purpose] = { ... }
end
local store = {}
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key) return store[key] end,
    set = function(_, key, value) store[key] = value end,
  },
  hooks = { wrap = function() end },
  events = { on = function() end },
  world = {
    spawnNpc = function() return nil end,
    removeNpc = function() return true end,
    npc = function() return nil end,
  },
}
local legacy = { cycle = 2, pact = "legacy", wanderersEnabled = true }
local journey = {
  wanderersEnabled = function() return true end,
  state = function() return legacy end,
  profile = function() return { completedPaths = {} } end,
}
local make = assert(loadfile(root .. "/legacy_wanderers.lua"))()
local wanderers = make(mod, {
  journey = journey,
  i18n = { text = function(en, de) return language == "de" and de or en end },
  titles = { currentTitle = function() return nil end },
  random = function(low, high, purpose)
    local q = queues[purpose] or {}
    local value = table.remove(q, 1)
    queues[purpose] = q
    value = tonumber(value) or low
    return math.max(low, math.min(high, value))
  end,
})
local game = {
  save = {
    player = { name = "ABCDEFG" }, party = {},
    hallOfFame = {}, flags = {},
  },
  data = {
    trainers = { OPP_LASS = { name = "LASS" } },
    pokemon = { PIDGEY = { name = "Pidgey" } },
  },
}
local function active(token)
  return {
    token = token, game = game,
    archetype = { class = "OPP_LASS" },
    team = { { species = "PIDGEY", level = 20 } },
  }
end

queue("dialogue_pick", 1, 2, 3, 4, 5, 6, 7, 8, 9)
local preLeague = {}
for index = 1, 9 do
  local text = wanderers.challengeText(active("pre:" .. index))
  preLeague[text] = true
  check(not text:find("legend", 1, true)
      and not text:find("Legend", 1, true),
    "pre-League greeting cannot claim legendary accomplishments")
  fits(text, "pre-League EN greeting")
end
local preCount = 0
for _ in pairs(preLeague) do preCount = preCount + 1 end
eq(preCount, 9, "pre-League pool retains nine distinct safe greetings")

game.save.hallOfFame = { { champion = true } }
queue("dialogue_pick", 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12)
local postLeague, legendary = {}, false
for index = 1, 12 do
  local text = wanderers.challengeText(active("post:" .. index))
  postLeague[text] = true
  if text:find("legend", 1, true) or text:find("Legend", 1, true) then
    legendary = true
  end
  fits(text, "post-League EN greeting")
end
local postCount = 0
for _ in pairs(postLeague) do postCount = postCount + 1 end
eq(postCount, 12, "post-League pool exposes all twelve greetings")
check(legendary, "post-League pool contains the approved legendary greeting")

for _, result in ipairs({ "win", "loss" }) do
  queue("farewell_" .. result, 1, 2, 3, 4, 5, 6)
  local seen = {}
  for index = 1, 6 do
    local row = active(("farewell:%s:%d"):format(result, index))
    local text = wanderers.farewellText(row, result)
    seen[text] = true
    fits(text, result .. " EN farewell")
  end
  local count = 0
  for _ in pairs(seen) do count = count + 1 end
  eq(count, 6, result .. " pool contains six distinct farewells")
end

language = "de"
queue("dialogue_pick", 1)
fits(wanderers.challengeText(active("de:greeting")), "German greeting")
queue("farewell_win", 3)
local named = wanderers.farewellText(active("de:farewell"), "win")
check(named:find("PIDGEY", 1, true) ~= nil,
  "German farewell can name the Wandertrainer's lead Pokémon")
fits(named, "German farewell")

local cached = wanderers.challengeText(active("cache"))
queue("dialogue_pick", 9)
eq(wanderers.challengeText(active("cache")), cached,
  "one encounter token keeps its exact greeting")

print(("legacy wanderer dialogue 6.5.13: PASS (%d checks)"):format(checks))
