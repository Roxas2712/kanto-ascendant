-- Exact-engine/data regression. Run once for each unpacked official engine
-- root (0.1.96 and 0.1.98). The trainer cache directory must contain the
-- player's real imported red/blue/yellow data.

local engineRoot = os.getenv("KA_ENGINE_ROOT")
local cacheRoot = os.getenv("KA_ENGINE_CACHE_ROOT")
local modRoot = os.getenv("TRAINER_REMATCH_MOD_DIR")
if not (engineRoot and cacheRoot and modRoot) then
  print("DIFFICULTY EARLY CURVE ENGINE SKIP: roots not set")
  return
end

local Version = assert(loadfile(engineRoot .. "/src/core/Version.lua"))()
local expectedEngine = assert(os.getenv("KA_EXPECT_ENGINE"),
  "KA_EXPECT_ENGINE is required")
assert(Version.engine == expectedEngine,
  "wrong exact engine: " .. tostring(Version.engine))

package.preload["src.inventory.Badges"] = function()
  return assert(loadfile(engineRoot .. "/src/inventory/Badges.lua"))()
end
package.preload["src.ui.BagMenu"] = function()
  return { new = function() return { onChoose = function() end } end }
end

-- Exercise the historical curve explicitly; the new schema default is OFF.
local values = { difficulty = "standard", wild_level_scaling = true }
local hooks, events = {}, {}
local mod = {
  options = { get = function(_, key) return values[key] end },
  hooks = { wrap = function(_, key, fn) hooks[key] = fn end },
  events = { on = function(_, key, fn) events[key] = fn end },
}
local difficulty = assert(loadfile(modRoot .. "/difficulty.lua"))()(mod, {
  i18n = { text = function(en) return en end },
})

local badgeIds = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}
local function gameAt(badges)
  local inventory = {}
  for index = 1, badges do inventory[badgeIds[index]] = true end
  return { data = {}, save = { inventory = inventory } }
end
local function signature(party)
  local out = {}
  for _, mon in ipairs(party or {}) do
    out[#out + 1] = tostring(mon.species) .. "@" .. tostring(mon.level)
  end
  return table.concat(out, ",")
end

local tiers = {
  { "standard", 0 }, { "high", 1 }, { "hard", 2 },
  { "very_hard", 3 }, { "extreme", 4 },
}
local authored = {
  red = { lab = "SQUIRTLE@5", route = "PIDGEY@9,SQUIRTLE@8",
    brock = "GEODUDE@12,ONIX@14", routeIndex = 4 },
  blue = { lab = "SQUIRTLE@5", route = "PIDGEY@9,SQUIRTLE@8",
    brock = "GEODUDE@12,ONIX@14", routeIndex = 4 },
  yellow = { lab = "EEVEE@5", route = "SPEAROW@9,EEVEE@8",
    brock = "GEODUDE@10,ONIX@12", routeIndex = 2 },
}

for _, edition in ipairs({ "red", "blue", "yellow" }) do
  local path = cacheRoot .. "/" .. edition .. "/data/generated/trainers.lua"
  local trainers = assert(loadfile(path), path)()
  local encounterPath = cacheRoot .. "/" .. edition
    .. "/data/generated/encounters.lua"
  local encounters = assert(loadfile(encounterPath), encounterPath)()
  local expected = authored[edition]
  assert(signature(trainers.OPP_RIVAL1.parties[1]) == expected.lab,
    edition .. " authored Lab party changed")
  assert(signature(trainers.OPP_RIVAL1.parties[expected.routeIndex]) == expected.route,
    edition .. " authored Route 22 party changed")
  assert(signature(trainers.OPP_BROCK.parties[1]) == expected.brock,
    edition .. " authored Brock party changed")

  -- Direct released-code proof: the old flat VERY HARD rule turns every
  -- official level-5 Lab opponent into level 13 before any other gameplay
  -- layer. The reported level 14 therefore includes one additional external
  -- level, but the unsafe flat curve is independently reproduced here.
  assert(trainers.OPP_RIVAL1.parties[1][1].level + 8 == 13,
    edition .. " released flat +8 reproduction changed")

  events["game.ready"]({ game = gameAt(0) })
  local previous = 4
  local routeOne = assert(encounters.ROUTE_1.grass.slots[1],
    edition .. " Route 1 encounter")
  local previousWild = routeOne.level - 1
  for _, row in ipairs(tiers) do
    values.difficulty = row[1]
    local source = trainers.OPP_RIVAL1.parties[1]
    local adjusted = hooks["trainer.party"](
      function(_, _, party) return party end, "OPP_RIVAL1", 1, source)
    assert(adjusted[1].level == 5 + row[2],
      ("%s/%s Lab expected L%d, got %s"):format(
        edition, row[1], 5 + row[2], signature(adjusted)))
    assert(adjusted[1].level > previous,
      edition .. " fresh tiers are not strictly ordered")
    assert(source[1].level == 5,
      edition .. " authored party was mutated")
    previous = adjusted[1].level

    local encounter = hooks["encounter.species"](
      function(candidate) return candidate end,
      { species = routeOne.species, level = routeOne.level },
      { mapId = "ROUTE_1", terrain = "grass" })
    assert(encounter.level == routeOne.level + row[2],
      ("%s/%s Route 1 expected L%d, got L%d"):format(
        edition, row[1], routeOne.level + row[2], encounter.level))
    assert(encounter.level > previousWild,
      edition .. " fresh wild tiers are not strictly ordered")
    previousWild = encounter.level
  end

  -- Full offsets return through ordinary campaign progress, without any
  -- edition/class/name exception.
  events["game.ready"]({ game = gameAt(8) })
  values.difficulty = "very_hard"
  local late = hooks["trainer.party"](function(_, _, party) return party end,
    "OPP_RIVAL1", 1, trainers.OPP_RIVAL1.parties[1])
  assert(late[1].level == 13, edition .. " late full offset not restored")
  local lateWild = hooks["encounter.species"](
    function(candidate) return candidate end,
    { species = routeOne.species, level = routeOne.level },
    { mapId = "ROUTE_1", terrain = "grass" })
  assert(lateWild.level == routeOne.level + 5,
    edition .. " late full wild offset not restored")
end

events["game.ready"]({ game = gameAt(8) })
values.difficulty = "extreme"
local capped, overflow = difficulty.adjustLevel(98, "trainer", 8)
assert(capped == 100 and overflow == 8,
  expectedEngine .. " level-100/mastery overflow changed")
assert(difficulty.itemsAllowed({ kind = "trainer" }) == false,
  expectedEngine .. " Extreme item rule changed")

print(("DIFFICULTY EARLY CURVE ENGINE PASS: engine=%s editions=R/B/Y tiers=5")
  :format(expectedEngine))
