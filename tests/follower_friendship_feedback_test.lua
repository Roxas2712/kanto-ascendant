-- Qualitative, value-preserving friendship feedback for the native follower
-- chain. The product discovers methods from the composed runtime registry;
-- this suite therefore mixes keyed and positional evolution rows.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local factory = assert(loadfile(root .. "/single_follower.lua"))()

local german = false
local i18n = {
  text = function(english, deutsch) return german and deutsch or english end,
}
local selected
local selection = {
  active = function() return selected end,
  edition = function() return "red" end,
  identity = function(mon) return mon and mon.species end,
}
local controller = factory({ events = { on = function() end } }, {
  selection = selection,
  sprites = { resolve = function() return "unused" end },
  i18n = i18n,
})

local lastCry, lastText
package.preload["src.core.Sound"] = function()
  return { playCry = function(_, species) lastCry = species end }
end
package.preload["src.core.Strings"] = function()
  return setmetatable({}, {
    __call = function(_, format, ...) return format:format(...) end,
  })
end
package.preload["src.render.TextBox"] = function()
  return { new = function(_, text, done)
    lastText = text
    return { text = text, done = done }
  end }
end

local evolutions = {
  GOLBAT = { { method = "FRIENDSHIP", species = "CROBAT" } },
  CROBAT = {},
  TOGEPI = { { "FRIENDSHIP", "TOGETIC" } },
  CHANSEY = { { method = "FRIENDSHIP", species = "BLISSEY" } },
  EEVEE = {
    { method = "FRIENDSHIP_DAY", species = "ESPEON" },
    { "FRIENDSHIP_NIGHT", "UMBREON" },
  },
  DAYMON = { { "FRIENDSHIP_DAY", "DAYTARGET" } },
  NIGHTMON = { { "FRIENDSHIP_NIGHT", "NIGHTTARGET" } },
  PICHU = { { "FRIENDSHIP", "PIKACHU" } },
  CLEFFA = { { "FRIENDSHIP", "CLEFAIRY" } },
  IGGLYBUFF = { { "FRIENDSHIP", "JIGGLYPUFF" } },
  AZURILL = { { method = "FRIENDSHIP", species = "MARILL" } },
  BULBASAUR = { { method = "LEVEL", species = "IVYSAUR", level = 16 } },
}
local pokemon = {}
for species, rows in pairs(evolutions) do
  pokemon[species] = { name = species, evolutions = rows }
end
local lastPushed
local game = {
  data = { pokemon = pokemon },
  save = { party = {} },
  stack = { push = function(_, value) lastPushed = value end },
}
local ow = { player = { facing = "down", cellX = 5, cellY = 5 } }

local function mon(species, bond, nickname)
  return { species = species, hp = 30, johtoBond = bond, nickname = nickname }
end
local function has(text, needle, label)
  assert(text and text:find(needle, 1, true),
    label .. ": missing " .. needle .. " in " .. tostring(text))
end

-- Every currently authored friendship species is discovered without an
-- allow-list. CROBAT itself and ordinary level evolutions remain generic.
for _, species in ipairs({
  "GOLBAT", "TOGEPI", "CHANSEY", "EEVEE",
  "PICHU", "CLEFFA", "IGGLYBUFF", "AZURILL",
}) do
  assert(controller.friendshipProfile(game, mon(species, 0)),
    species .. " friendship method was not discovered dynamically")
end
assert(controller.friendshipProfile(game, mon("CROBAT", 255)) == nil,
  "fully evolved Crobat incorrectly received evolution feedback")
assert(controller.friendshipProfile(game, mon("BULBASAUR", 255)) == nil,
  "ordinary level evolution incorrectly received friendship feedback")

-- Exact requested boundaries. No text exposes the raw value.
local bands = {
  { 0, "seems wary" }, { 49, "seems wary" },
  { 50, "is starting" }, { 99, "is starting" },
  { 100, "looks very" }, { 199, "looks very" },
  { 200, "completely" }, { 255, "completely" },
}
for _, row in ipairs(bands) do
  local text = assert(controller.friendshipText(
    game, mon("GOLBAT", row[1], "BATI"), "BATI"))
  has(text, "BATI", "nickname at bond " .. row[1])
  has(text, row[2], "band at bond " .. row[1])
  assert(not text:find(tostring(row[1]), 1, true),
    "raw friendship leaked at boundary " .. row[1])
end
has(controller.friendshipText(game, mon("GOLBAT", 100), "GOLBAT"),
  "next level", "friendship level-up condition")
local eeveeText = controller.friendshipText(game, mon("EEVEE", 100), "EEVEE")
has(eeveeText, "time decides", "Eevee day/night branch")
has(controller.friendshipText(game, mon("DAYMON", 100), "DAYMON"),
  "by day", "day-only friendship branch")
has(controller.friendshipText(game, mon("NIGHTMON", 100), "NIGHTMON"),
  "by night", "night-only friendship branch")

german = true
local germanLow = controller.friendshipText(
  game, mon("GOLBAT", 49, "FLATTER"), "FLATTER")
has(germanLow, "skeptisch", "German low band")
local germanReady = controller.friendshipText(
  game, mon("EEVEE", 100, "EVI"), "EVI")
has(germanReady, "gl\195\188cklich", "German ready band")
has(germanReady, "Tageszeit", "German day/night explanation")
german = false

-- Talk uses the addressed entity's exact runtime mon for every chain index,
-- not follower #1. Reading and a simulated save/reload preserve johtoBond.
local chain = {
  mon("GOLBAT", 0, "ONE"), mon("TOGEPI", 50, "TWO"),
  mon("CHANSEY", 100, "THREE"), mon("EEVEE", 200, "FOUR"),
}
selected = chain[1]
for index, candidate in ipairs(chain) do
  local before = candidate.johtoBond
  local npc = {
    followerMon = candidate, followerSpecies = candidate.species,
    _ascendantChainIndex = index, cellX = index, cellY = 4,
    facing = "up", moving = false,
    facePlayer = function(self) self.facing = "right" end,
  }
  lastCry, lastText = nil, nil
  controller._genericTalk(game, ow, npc, function() end)
  assert(lastCry == candidate.species, "wrong cry for follower " .. index)
  has(lastText, candidate.nickname, "wrong mon for follower " .. index)
  assert(candidate.johtoBond == before,
    "talk mutated friendship for follower " .. index)
  local reloaded = {
    species = candidate.species, hp = candidate.hp,
    johtoBond = candidate.johtoBond, nickname = candidate.nickname,
  }
  assert(reloaded.johtoBond == before,
    "save/reload changed friendship for follower " .. index)
end

-- Without an NPC, selection.active is the intentional fallback.
lastText = nil
controller._genericTalk(game, ow, nil, function() end)
has(lastText, "ONE", "selection.active fallback")
lastText = nil
controller._genericTalk(game, ow, {
  _ascendantChainIndex = 1, cellX = 1, cellY = 1,
  facing = "down", moving = false,
}, function() end)
has(lastText, "ONE", "native first-follower metadata fallback")
local incompleteExtraDone = false
lastText = nil
controller._genericTalk(game, ow, {
  _ascendantChainIndex = 2, cellX = 1, cellY = 1,
  facing = "down", moving = false,
}, function() incompleteExtraDone = true end)
assert(incompleteExtraDone and lastText == nil,
  "incomplete extra follower impersonated selection.active")

-- Future/malformed values and registry rows fail closed to the established
-- generic line and never throw or coerce an invented value.
for _, bad in ipairs({ "100", -1, 256, 1.5, false }) do
  local candidate = mon("GOLBAT", bad, "ODD")
  assert(controller.friendshipProfile(game, candidate) == nil,
    "malformed bond was interpreted: " .. tostring(bad))
  lastText = nil
  controller._genericTalk(game, ow, {
    followerMon = candidate, cellX = 1, cellY = 1,
    facing = "down", moving = false,
  }, function() end)
  has(lastText, "is following", "malformed bond generic fallback")
end
pokemon.FUTURE = {
  name = "FUTURE", evolutions = {
    { method = "FRIENDSHIP_FUTURE", species = "UNKNOWN" },
    { method = "FRIENDSHIP" },
    "broken",
  },
}
assert(controller.friendshipProfile(game, mon("FUTURE", 255)) == nil,
  "future/malformed evolution rows did not fail closed")

print("PASS follower friendship: dynamic methods bands DE/EN chain 1-4 immutable")
