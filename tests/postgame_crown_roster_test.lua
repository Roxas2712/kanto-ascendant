-- Crown League roster identity: each battle is a curated six, and the
-- Champion's Johto legends are not duplicated one room earlier.
local D = assert(loadfile("postgame_data.lua"))()

local classes = {
  "OPP_LORELEI", "OPP_BRUNO", "OPP_AGATHA", "OPP_LANCE", "OPP_RIVAL3",
}
for _, tier in ipairs({ "apex", "crown" }) do
  for _, class in ipairs(classes) do
    local team = assert(D[tier][class], class .. " " .. tier .. " team missing")
    assert(#team == 6, class .. " " .. tier .. " team is not six Pokémon")
    local seen = {}
    for _, mon in ipairs(team) do
      assert(not seen[mon.species],
        class .. " " .. tier .. " repeats " .. mon.species)
      seen[mon.species] = true
    end
  end
end

assert(D.crown.OPP_LORELEI[6].species == "ARTICUNO",
  "Lorelei still duplicates the Champion's Suicune")
assert(D.crown.OPP_AGATHA[6].species == "MISMAGIUS",
  "Agatha's second Gengar was not replaced by Mismagius")
assert(D.crown.OPP_LANCE[5].species == "KINGDRA"
    and D.crown.OPP_LANCE[6].species == "DRAGONITE",
  "Lance still duplicates the Champion's Lugia/Ho-Oh")
local expectedMegas = {
  OPP_LORELEI = { apex = "SLOWBRO", crown = "SLOWBRO" },
  OPP_BRUNO = { apex = "AERODACTYL", crown = "AERODACTYL" },
  OPP_AGATHA = { apex = "GENGAR", crown = "GENGAR" },
  OPP_LANCE = { apex = "DRAGONITE", crown = "DRAGONITE" },
  OPP_RIVAL3 = { apex = "GYARADOS", crown = "MEWTWO" },
}
local distinct = { apex = {}, crown = {} }
for class, tiers in pairs(expectedMegas) do
  for tier, species in pairs(tiers) do
    assert(D.eliteMega[class][tier] == species,
      class .. " " .. tier .. " has the wrong reserved Mega")
    local found = 0
    for _, mon in ipairs(D[tier][class]) do
      if mon.species == species then found = found + 1 end
    end
    assert(found == 1,
      class .. " " .. tier .. " does not have exactly one reserved Mega carrier")
    assert(not distinct[tier][species],
      "two " .. tier .. " opponents share a Mega carrier")
    distinct[tier][species] = class
  end
end
assert(D.apex.OPP_BRUNO[5].species == "AERODACTYL",
  "Bruno does not own Aerodactyl")
assert(D.apex.OPP_LANCE[2].species == "TYRANITAR"
    and D.apex.OPP_LANCE[5].species == "KINGDRA",
  "Lance still duplicates Bruno's Aerodactyl or his own Dragonite")
assert(D.apex.OPP_AGATHA[6].species == "MISMAGIUS",
  "Apex Agatha still fields a duplicate Gengar")
assert(D.eliteMegaFallback.OPP_RIVAL3.crown == "ALAKAZAM",
  "Mewtwo-off Crown fallback lost its one legal Mega carrier")

local legendary = {
  ARTICUNO=true, ZAPDOS=true, MOLTRES=true, MEWTWO=true, MEW=true,
  RAIKOU=true, ENTEI=true, SUICUNE=true, LUGIA=true, HO_OH=true,
  CELEBI=true,
}
local leagueLegends = {}
for _, class in ipairs(classes) do
  for _, mon in ipairs(D.crown[class]) do
    if legendary[mon.species] then
      assert(not leagueLegends[mon.species],
        class .. " duplicates " .. mon.species .. " from "
          .. tostring(leagueLegends[mon.species]))
      leagueLegends[mon.species] = class
    end
  end
end

-- Link the roster declaration to both live controllers.  This focused host
-- deliberately supplies only ModKit-shaped services: it proves that every
-- reserved species has a real production Mega profile, that the Mewtwo OFF
-- option resolves through the public postgame path, and that the same trainer
-- hook leaves Blue's ordinary pre-Hall-of-Fame story party untouched.
local function registry()
  local values = {}
  return {
    register = function(_, key, value) values[key] = value end,
    patch = function() end,
    get = function(_, key) return values[key] end,
  }
end
local saved, options, hooks = {}, {}, {}
local mod = {
  id = "kanto_ascendant", path = ".", exports = {},
  save = {
    get = function(_, key, fallback)
      local value = saved[key]
      return value == nil and fallback or value
    end,
    set = function(_, key, value) saved[key] = value end,
  },
  options = { get = function(_, key) return options[key] end },
  content = {
    maps = registry(), map_scripts = registry(), items = registry(),
    battle_sprite_scales = registry(),
  },
  hooks = {
    wrap = function(_, name, callback) hooks[name] = callback end,
  },
  events = { on = function() end },
  world = { overworld = function() return nil end },
  log = { warn = function() end },
}
function mod:read(relative)
  local handle = io.open(relative, "rb")
  if not handle then return nil end
  local body = handle:read("*a")
  handle:close()
  return body
end

D.dialogue = assert(loadfile("postgame_dialogue.lua"))()
local postgame = assert(loadfile("postgame.lua"))()(mod, D, {
  contentEnabled = true,
})
local mega = assert(loadfile("mega_evolution.lua"))()(mod, {
  contentEnabled = true, postgame = postgame, animationData = {},
})
for class, tiers in pairs(expectedMegas) do
  for tier, species in pairs(tiers) do
    local profiles = mega.formsBySpecies[species]
    assert(type(profiles) == "table" and #profiles > 0,
      class .. " " .. tier .. " reserves non-viable Mega " .. species)
  end
end
assert(mega.formsBySpecies.ALAKAZAM
    and #mega.formsBySpecies.ALAKAZAM > 0,
  "Crown Blue's Mewtwo-off fallback is not Mega-viable")

local defaultCrown = postgame.enabledTeam(D.crown.OPP_RIVAL3)
assert(postgame.eliteMegaTarget("OPP_RIVAL3", "crown", defaultCrown)
    == "MEWTWO",
  "default Crown Blue no longer reserves Mewtwo")
options.legend_mewtwo = "off"
local noMewtwoCrown = postgame.enabledTeam(D.crown.OPP_RIVAL3)
assert(noMewtwoCrown[1].species == "ALAKAZAM",
  "Mewtwo OFF does not install the configured Alakazam replacement")
assert(postgame.eliteMegaTarget(
    "OPP_RIVAL3", "crown", noMewtwoCrown) == "ALAKAZAM",
  "Mewtwo OFF does not retain one viable Crown Mega carrier")
assert(D.crown.OPP_RIVAL3[1].species == "MEWTWO",
  "option filtering mutated the canonical Crown roster")
options.legend_mewtwo = nil

local storyBlue = {
  { species = "BLASTOISE", level = 65 },
  { species = "ALAKAZAM", level = 59 },
  { species = "PIDGEOT", level = 61 },
}
postgame.game = {
  save = { flags = {}, hallOfFame = {} },
}
local resolvedStory = assert(hooks["trainer.party"])(
  function(_, _, party) return party end,
  "OPP_RIVAL3", 1, storyBlue)
assert(resolvedStory == storyBlue,
  "postgame hook replaced standard story Blue before the Hall of Fame")
for index, expected in ipairs(storyBlue) do
  assert(resolvedStory[index].species == expected.species
      and resolvedStory[index].level == expected.level,
    "standard story Blue slot " .. index .. " was altered")
end

local ascendantData = assert(loadfile("ascendant_data.lua"))()
local ascendant = assert(loadfile("ascendant.lua"))()(mod, D, {
  data = ascendantData, postgame = postgame,
  placement = { findWideRandom = function() end },
})
local function speciesCount(team, species)
  local count = 0
  for _, mon in ipairs(team or {}) do
    if mon.species == species then count = count + 1 end
  end
  return count
end
local function uniqueTeam(team)
  local seen = {}
  for _, mon in ipairs(team or {}) do
    if seen[mon.species] then return false end
    seen[mon.species] = true
  end
  return #team == 6
end
local adaptivePokemon = {}
for _, species in ipairs({
    "TYRANITAR", "SCIZOR", "KINGDRA", "AMPHAROS", "ESPEON", "HOUNDOOM",
}) do
  adaptivePokemon[species] = { types = { "NORMAL" } }
end
local adaptiveGame = {
  data = { pokemon = adaptivePokemon },
  save = { party = {} },
}
local ascendantState = ascendant.state()
ascendantState.cycle = 0
for variant = 0, 5 do
  local dynamicCrownLegends = {}
  for _, class in ipairs(classes) do
    for _, tier in ipairs({ "apex", "crown" }) do
      ascendantState.bossBattles[
        "elite:" .. class .. ":" .. tier] = variant
      local selected = ascendant.selectBossTeam(D[tier][class], {
        kind = "elite", key = class, tier = tier,
      }, adaptiveGame)
      assert(uniqueTeam(selected),
        ("adaptive %s %s variant %d repeats a species")
          :format(tier, class, variant))
      local carrier = expectedMegas[class][tier]
      assert(speciesCount(selected, carrier) == 1,
        ("adaptive %s %s variant %d lost Mega %s")
          :format(tier, class, variant, carrier))
      if tier == "crown" then
        for _, mon in ipairs(selected) do
          if legendary[mon.species] then
            assert(not dynamicCrownLegends[mon.species],
              ("adaptive Crown variant %d repeats League legend %s")
                :format(variant, mon.species))
            dynamicCrownLegends[mon.species] = class
          end
        end
      end
    end
  end
end

options.legend_mewtwo = "off"
noMewtwoCrown = postgame.enabledTeam(D.crown.OPP_RIVAL3)
for dominant, expectedCounter in pairs({
    FIGHTING = "ALAKAZAM", WATER = "JOLTEON", ICE = "ARCANINE",
}) do
  local fixture = "PLAYER_" .. dominant
  adaptivePokemon[fixture] = { types = { dominant } }
  adaptiveGame.save.party = { { species = fixture } }
  local fallbackBlue = ascendant.selectBossTeam(noMewtwoCrown, {
    kind = "elite", key = "OPP_RIVAL3", tier = "crown",
  }, adaptiveGame)
  assert(uniqueTeam(fallbackBlue),
    "Mewtwo-off " .. dominant .. " adaptation repeats a species")
  assert(speciesCount(fallbackBlue, "ALAKAZAM") == 1,
    "Mewtwo-off " .. dominant .. " adaptation lost its Mega fallback")
  assert(speciesCount(fallbackBlue, expectedCounter) == 1,
    "Mewtwo-off " .. dominant .. " adaptation lost its counter")
  for _, species in ipairs({ "RAIKOU", "ENTEI", "LUGIA", "HO_OH" }) do
    assert(speciesCount(fallbackBlue, species) == 1,
      "Mewtwo-off " .. dominant .. " adaptation lost " .. species)
  end
end
options.legend_mewtwo = nil

print("postgame_crown_roster_test: PASS")
