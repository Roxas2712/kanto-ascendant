local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function contains(text, fragment, message)
  ok(type(text) == "string" and text:find(fragment, 1, true), message)
end

local enabled, ring, opponents = true, true, "bosses"
local stones = { VENUSAURITE = true, CHARIZARDITE_Y = true }
local forms = {
  { species = "VENUSAUR", id = "VENUSAUR", stone = "VENUSAURITE", tier = "hof" },
  { species = "CHARIZARD", id = "CHARIZARD_X", stone = "CHARIZARDITE_X", tier = "hof" },
  { species = "CHARIZARD", id = "CHARIZARD_Y", stone = "CHARIZARDITE_Y", tier = "hof" },
  { species = "TYPHLOSION", id = "TYPHLOSION_ASCENDANT", stone = "BASALT_CORE", secret = true },
}
local mega = {
  forms = forms,
  hasRing = function() return ring end,
  hasStone = function(id) return stones[id] == true end,
  tierAvailable = function() return true end,
}
local mod = { options = { get = function(_, key)
  if key == "surprise_trainer_mega" then return enabled end
  if key == "mega_evolution" then return true end
  if key == "mega_opponents" then return opponents end
end } }
local postgame = { hasHallOfFame = function(save)
  return save and save.league == true
end }
local language = "en"
local card = assert(loadfile("surprise_mega_67.lua"))()(mod, {
  mega = mega, postgame = postgame,
  i18n = { text = function(en, de) return language == "de" and de or en end },
})
local game = { save = { league = true } }

-- Find one deterministic 1:10 hit without making the test depend on a magic
-- token chosen by hand.
local token, plan
for index = 1, 100 do
  local candidate = "mega-fixture:" .. index
  local value = card.plan(game, candidate, {
    { species = "VENUSAUR", level = 82 },
    { species = "CHARIZARD", level = 84 },
  }, { lossRelief = 0 })
  if value then token, plan = candidate, value break end
end
ok(token ~= nil, "deterministic ten-percent planner produces a bounded hit")
ok(plan.species == "VENUSAUR" or plan.species == "CHARIZARD",
  "planner chooses only an entitled team member")
if plan.species == "CHARIZARD" then
  eq(plan.form, "CHARIZARD_Y", "planner preserves the exact owned Y entitlement")
end
ok(plan.form ~= "TYPHLOSION_ASCENDANT", "fan forms never enter the official pool")
ok(card.validate(game, plan, {
  { species = plan.species, level = 85, hp = 1 },
}), "stored plan revalidates against live team and entitlement")

local battle = { enemyParty = {
  { species = plan.species, level = 85, hp = 1 },
} }
ok(card.apply(game, battle, { mega = plan }), "valid plan applies to battle")
eq(battle.ascendantEnemyMegaSpecies, plan.species,
  "battle receives exact enemy species target")
eq(battle.ascendantEnemyMegaForm, plan.form,
  "battle receives exact enemy form target")
ok(battle.ascendantSurpriseMega, "battle is marked as Surprise Mega")
contains(card.telegraph(plan), "KEY STONE", "English telegraph is explicit")
language = "de"
contains(card.telegraph(plan), "SCHLÜSSEL-STEIN", "German telegraph is explicit")

local relieved, relievedWhy = card.plan(game, token, {
  { species = "VENUSAUR", level = 90 },
}, { lossRelief = 1 })
eq(relieved, nil, "loss relief suppresses the Mega plan")
eq(relievedWhy, "relief", "loss-relief denial is explicit")
ring = false
local noRing, ringWhy = card.plan(game, token, {
  { species = "VENUSAUR", level = 90 },
}, { lossRelief = 0 })
eq(noRing, nil, "missing Ring suppresses the Mega plan")
eq(ringWhy, "ring", "Ring denial is explicit")
ring, enabled = true, false
local off, offWhy = card.plan(game, token, {
  { species = "VENUSAUR", level = 90 },
}, { lossRelief = 0 })
eq(off, nil, "OFF suppresses the Mega plan")
eq(offWhy, "disabled", "OFF denial is explicit")
enabled, opponents = true, "off"
local globalOff, globalOffWhy = card.plan(game, token, {
  { species = "VENUSAUR", level = 90 },
}, { lossRelief = 0 })
eq(globalOff, nil, "global opponent-Mega OFF remains authoritative")
eq(globalOffWhy, "mega-option", "global opponent-Mega denial is explicit")

print(("surprise Mega card 6.7: %d checks passed"):format(checks))
