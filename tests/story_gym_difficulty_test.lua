-- Story Gym difficulty contract regression.
-- Run with TRAINER_REMATCH_MOD_DIR=/abs/mod and either a complete
-- KA_ENGINE_CACHE_ROOT or the ROM-free KA_STORY_GYM_FIXTURE contract.

package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local function clone(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = clone(child) end
  return out
end

local edition = "red"
local GameVersion = { get = function() return edition end }
local values = { difficulty = "standard" }
local hooks, events = {}, {}
local mod = {
  options = { get = function(_, key) return values[key] end },
  hooks = { wrap = function(_, key, fn, priority)
    hooks[key] = { fn = fn, priority = priority }
  end },
  events = { on = function(_, key, fn, priority)
    events[key] = events[key] or {}
    events[key][#events[key] + 1] = { fn = fn, priority = priority }
  end },
}

local story = assert(loadfile(root .. "/story_gym_difficulty.lua"))()(mod, {
  gameVersion = GameVersion,
  usefulLayerId = "KA_REMATCH_USEFUL_MOVE",
  yellowFidelity = assert(loadfile(root .. "/yellow_gym_move_fidelity.lua"))(),
})

local expectedSpecies = {
  red = {
    OPP_BROCK = {
      standard = "GEODUDE,ONIX", high = "GEODUDE,ONIX",
      hard = "GEODUDE,SANDSHREW,ONIX",
      very_hard = "GEODUDE,SANDSHREW,RHYHORN,ONIX",
      extreme = "GEODUDE,SANDSHREW,RHYHORN,ONIX",
    },
    OPP_MISTY = {
      standard = "STARYU,STARMIE", high = "STARYU,STARMIE",
      hard = "STARYU,PSYDUCK,STARMIE",
      very_hard = "STARYU,PSYDUCK,HORSEA,STARMIE",
      extreme = "STARYU,PSYDUCK,HORSEA,STARMIE",
    },
    OPP_LT_SURGE = {
      standard = "VOLTORB,PIKACHU,RAICHU", high = "VOLTORB,PIKACHU,RAICHU",
      hard = "VOLTORB,PIKACHU,MAGNEMITE,RAICHU",
      very_hard = "VOLTORB,PIKACHU,MAGNEMITE,ELECTABUZZ,RAICHU",
      extreme = "VOLTORB,PIKACHU,MAGNEMITE,ELECTABUZZ,RAICHU",
    },
    OPP_ERIKA = {
      standard = "VICTREEBEL,TANGELA,VILEPLUME",
      high = "VICTREEBEL,TANGELA,VILEPLUME",
      hard = "VICTREEBEL,TANGELA,PARASECT,VILEPLUME",
      very_hard = "VICTREEBEL,TANGELA,PARASECT,EXEGGCUTE,VILEPLUME",
      extreme = "VICTREEBEL,TANGELA,PARASECT,EXEGGUTOR,VILEPLUME",
    },
    OPP_KOGA = {
      standard = "KOFFING,MUK,KOFFING,WEEZING",
      high = "KOFFING,MUK,KOFFING,WEEZING",
      hard = "KOFFING,MUK,KOFFING,ARBOK,WEEZING",
      very_hard = "KOFFING,MUK,KOFFING,ARBOK,GOLBAT,WEEZING",
      extreme = "KOFFING,MUK,KOFFING,ARBOK,GOLBAT,WEEZING",
    },
    OPP_SABRINA = {
      standard = "KADABRA,MR_MIME,VENOMOTH,ALAKAZAM",
      high = "KADABRA,MR_MIME,VENOMOTH,ALAKAZAM",
      hard = "KADABRA,MR_MIME,VENOMOTH,HYPNO,ALAKAZAM",
      very_hard = "KADABRA,MR_MIME,VENOMOTH,HYPNO,JYNX,ALAKAZAM",
      extreme = "KADABRA,MR_MIME,VENOMOTH,HYPNO,JYNX,ALAKAZAM",
    },
    OPP_BLAINE = {
      standard = "GROWLITHE,PONYTA,RAPIDASH,ARCANINE",
      high = "GROWLITHE,PONYTA,RAPIDASH,ARCANINE",
      hard = "GROWLITHE,PONYTA,RAPIDASH,NINETALES,ARCANINE",
      very_hard = "GROWLITHE,PONYTA,RAPIDASH,NINETALES,MAGMAR,ARCANINE",
      extreme = "GROWLITHE,PONYTA,RAPIDASH,NINETALES,MAGMAR,ARCANINE",
    },
    OPP_GIOVANNI = {
      standard = "RHYHORN,DUGTRIO,NIDOQUEEN,NIDOKING,RHYDON",
      high = "RHYHORN,DUGTRIO,NIDOQUEEN,NIDOKING,RHYDON",
      hard = "RHYHORN,DUGTRIO,NIDOQUEEN,NIDOKING,SANDSLASH,RHYDON",
      very_hard = "RHYHORN,DUGTRIO,NIDOQUEEN,NIDOKING,SANDSLASH,RHYDON",
      extreme = "RHYHORN,DUGTRIO,NIDOQUEEN,NIDOKING,SANDSLASH,RHYDON",
    },
  },
  yellow = {
    OPP_BROCK = {
      standard = "GEODUDE,ONIX", high = "GEODUDE,ONIX",
      hard = "GEODUDE,SANDSHREW,ONIX",
      very_hard = "GEODUDE,SANDSHREW,RHYHORN,ONIX",
      extreme = "GEODUDE,SANDSHREW,RHYHORN,ONIX",
    },
    OPP_MISTY = {
      standard = "STARYU,STARMIE", high = "STARYU,STARMIE",
      hard = "STARYU,PSYDUCK,STARMIE",
      very_hard = "STARYU,PSYDUCK,HORSEA,STARMIE",
      extreme = "STARYU,PSYDUCK,HORSEA,STARMIE",
    },
    OPP_LT_SURGE = {
      standard = "RAICHU", high = "RAICHU", hard = "VOLTORB,RAICHU",
      very_hard = "VOLTORB,MAGNEMITE,RAICHU",
      extreme = "VOLTORB,MAGNETON,ELECTABUZZ,JOLTEON,RAICHU",
    },
    OPP_ERIKA = {
      standard = "TANGELA,WEEPINBELL,GLOOM", high = "TANGELA,WEEPINBELL,GLOOM",
      hard = "TANGELA,WEEPINBELL,PARASECT,GLOOM",
      very_hard = "TANGELA,WEEPINBELL,PARASECT,EXEGGCUTE,GLOOM",
      extreme = "TANGELA,WEEPINBELL,PARASECT,EXEGGUTOR,GLOOM",
    },
    OPP_KOGA = {
      standard = "VENONAT,VENONAT,VENONAT,VENOMOTH",
      high = "VENONAT,VENONAT,VENONAT,VENOMOTH",
      hard = "VENONAT,VENONAT,VENONAT,ARBOK,VENOMOTH",
      very_hard = "VENONAT,VENONAT,VENONAT,ARBOK,GOLBAT,VENOMOTH",
      extreme = "VENONAT,VENONAT,VENONAT,ARBOK,GOLBAT,VENOMOTH",
    },
    OPP_SABRINA = {
      standard = "ABRA,KADABRA,ALAKAZAM", high = "ABRA,KADABRA,ALAKAZAM",
      hard = "ABRA,KADABRA,MR_MIME,ALAKAZAM",
      very_hard = "ABRA,KADABRA,MR_MIME,HYPNO,ALAKAZAM",
      extreme = "ABRA,KADABRA,MR_MIME,HYPNO,JYNX,ALAKAZAM",
    },
    OPP_BLAINE = {
      standard = "NINETALES,RAPIDASH,ARCANINE",
      high = "NINETALES,RAPIDASH,ARCANINE",
      hard = "NINETALES,RAPIDASH,GROWLITHE,ARCANINE",
      very_hard = "NINETALES,RAPIDASH,GROWLITHE,MAGMAR,ARCANINE",
      extreme = "NINETALES,RAPIDASH,GROWLITHE,MAGMAR,FLAREON,ARCANINE",
    },
    OPP_GIOVANNI = {
      standard = "DUGTRIO,PERSIAN,NIDOQUEEN,NIDOKING,RHYDON",
      high = "DUGTRIO,PERSIAN,NIDOQUEEN,NIDOKING,RHYDON",
      hard = "DUGTRIO,PERSIAN,NIDOQUEEN,NIDOKING,SANDSLASH,RHYDON",
      very_hard = "DUGTRIO,PERSIAN,NIDOQUEEN,NIDOKING,SANDSLASH,RHYDON",
      extreme = "DUGTRIO,PERSIAN,NIDOQUEEN,NIDOKING,SANDSLASH,RHYDON",
    },
  },
}

local maps = {
  OPP_BROCK = "PEWTER_GYM", OPP_MISTY = "CERULEAN_GYM",
  OPP_LT_SURGE = "VERMILION_GYM", OPP_ERIKA = "CELADON_GYM",
  OPP_KOGA = "FUCHSIA_GYM", OPP_SABRINA = "SAFFRON_GYM",
  OPP_BLAINE = "CINNABAR_GYM", OPP_GIOVANNI = "VIRIDIAN_GYM",
}
local badges = {
  OPP_BROCK = "BOULDERBADGE", OPP_MISTY = "CASCADEBADGE",
  OPP_LT_SURGE = "THUNDERBADGE", OPP_ERIKA = "RAINBOWBADGE",
  OPP_KOGA = "SOULBADGE", OPP_SABRINA = "MARSHBADGE",
  OPP_BLAINE = "VOLCANOBADGE", OPP_GIOVANNI = "EARTHBADGE",
}

local cache = os.getenv("KA_ENGINE_CACHE_ROOT")
local fixture = os.getenv("KA_STORY_GYM_FIXTURE")
assert(cache or fixture,
  "KA_ENGINE_CACHE_ROOT or KA_STORY_GYM_FIXTURE is required")
local source
if cache then
  source = {
    red = assert(loadfile(cache .. "/red/data/generated/trainers.lua"))(),
    blue = assert(loadfile(cache .. "/blue/data/generated/trainers.lua"))(),
    yellow = assert(loadfile(cache .. "/yellow/data/generated/trainers.lua"))(),
  }
else
  source = assert(assert(loadfile(fixture))().trainers,
    "story Gym fixture is missing trainer rows")
end

local function partyIndex(class) return class == "OPP_GIOVANNI" and 3 or 1 end
local function species(party)
  local out = {}
  for _, row in ipairs(party) do out[#out + 1] = row.species end
  return table.concat(out, ",")
end
local function moves(row) return table.concat(row.moves or {}, ",") end
local function emit(name, ev)
  for _, row in ipairs(events[name] or {}) do row.fn(ev) end
end
local function gameFor(class)
  return {
    data = {},
    save = { inventory = {}, flags = {}, hallOfFame = {} },
    overworld = { map = { id = maps[class] } },
  }
end
local function resolve(class, tier, version, game, nextFn)
  edition, values.difficulty = version, tier
  game = game or gameFor(class)
  emit("game.ready", { game = game })
  local original = source[version][class].parties[partyIndex(class)]
  return hooks["trainer.party"].fn(nextFn or function(_, _, rows) return rows end,
    class, partyIndex(class), original), original, game
end

assert(hooks["trainer.party"].priority == 110,
  "story roster hook must run below difficulty(150), above randomizer(70)")

for _, version in ipairs({ "red", "blue" }) do
  local official = source[version].OPP_BROCK.parties[1]
  local downstream
  local untouched = resolve("OPP_BROCK", "standard", version, nil,
    function(_, _, rows)
      downstream = rows
      return rows
    end)
  assert(downstream == official and untouched == official,
    "STANDARD " .. version .. " did not pass the exact official table through")
end

for _, version in ipairs({ "red", "blue", "yellow" }) do
  local family = version == "yellow" and "yellow" or "red"
  for class, tiers in pairs(expectedSpecies[family]) do
    for _, tier in ipairs({ "standard", "high", "hard", "very_hard", "extreme" }) do
      local before = clone(source[version][class].parties[partyIndex(class)])
      local out, original = resolve(class, tier, version)
      assert(species(out) == tiers[tier],
        version .. "/" .. class .. "/" .. tier .. " roster: " .. species(out))
      assert(species(original) == species(before), "authored source party mutated")
      for index, row in ipairs(original) do
        assert(row.level == before[index].level and row.moves == before[index].moves,
          "authored source row mutated")
      end
      if tier == "standard" then
        assert(#out == #original, "STANDARD changed team size")
      elseif tier == "high" then
        assert(#out == #original, "HIGH changed team size")
        for _, row in ipairs(out) do
          assert(#row.moves >= 2 and #row.moves <= 3, "HIGH requires 2-3 moves")
        end
      elseif tier == "hard" then
        for _, row in ipairs(out) do assert(#row.moves == 3, "HARD requires 3 moves") end
      else
        for _, row in ipairs(out) do assert(#row.moves == 4, tier .. " requires 4 moves") end
      end
    end
  end
end

-- The Yellow STANDARD repair must be exact and limited to the eight first
-- story Gym parties. These representative rows cover every broken table form.
local yBrock = resolve("OPP_BROCK", "standard", "yellow")
assert(moves(yBrock[2]) == "TACKLE,SCREECH,BIND,BIDE", "Yellow Brock fidelity")
local ySurge = resolve("OPP_LT_SURGE", "standard", "yellow")
assert(moves(ySurge[1]) == "THUNDERBOLT,MEGA_PUNCH,MEGA_KICK,GROWL",
  "Yellow Surge fidelity")
local yKoga = resolve("OPP_KOGA", "standard", "yellow")
assert(moves(yKoga[4]) == "LEECH_LIFE,DOUBLE_TEAM,PSYCHIC_M,TOXIC",
  "Yellow Koga fidelity")
local yGiovanni = resolve("OPP_GIOVANNI", "standard", "yellow")
assert(moves(yGiovanni[5]) == "ROCK_SLIDE,FURY_ATTACK,HORN_DRILL,EARTHQUAKE",
  "Yellow Giovanni fidelity")

-- Invalid context and completed leaders always fall through byte-for-byte.
local badGame = gameFor("OPP_BROCK")
badGame.overworld.map.id = "ROUTE_1"
local bad = resolve("OPP_BROCK", "extreme", "red", badGame)
assert(species(bad) == "GEODUDE,ONIX", "wrong map leaked story roster")
local doneGame = gameFor("OPP_BROCK")
doneGame.save.inventory[badges.OPP_BROCK] = true
local done = resolve("OPP_BROCK", "extreme", "red", doneGame)
assert(species(done) == "GEODUDE,ONIX", "earned badge leaked story roster")
local hofGame = gameFor("OPP_BROCK")
hofGame.save.hallOfFame[1] = { champion = true }
local hof = resolve("OPP_BROCK", "extreme", "red", hofGame)
assert(species(hof) == "GEODUDE,ONIX", "postgame leaked story roster")
values.difficulty = "corrupt_value"
edition = "red"
emit("game.ready", { game = gameFor("OPP_BROCK") })
local invalidTier = hooks["trainer.party"].fn(function(_, _, rows) return rows end,
  "OPP_BROCK", 1, source.red.OPP_BROCK.parties[1])
assert(species(invalidTier) == "GEODUDE,ONIX", "invalid tier did not fall back")

-- Roster construction is pre-randomizer: downstream sees and maps every
-- authored slot, rather than KASC replacing the mapped result afterward.
local seenByNext
local mapped = resolve("OPP_BROCK", "hard", "red", nil,
  function(_, _, rows)
    seenByNext = species(rows)
    local out = clone(rows)
    for _, row in ipairs(out) do row.species = "DITTO" end
    return out
  end)
assert(seenByNext == "GEODUDE,SANDSHREW,ONIX", "randomizer missed added slot")
assert(species(mapped) == "DITTO,DITTO,DITTO", "post-randomizer result overwritten")

-- Battle policy is attached only when a roster transaction matched.
local hardParty = resolve("OPP_MISTY", "hard", "red")
local battle = {
  kind = "trainer", oppClass = "OPP_MISTY", partyIndex = 1,
  game = gameFor("OPP_MISTY"), enemyParty = hardParty,
  enemy = { mon = { hp = 10, stats = { hp = 100 } } },
  enemyAIMods = {}, aiUses = 9,
}
emit("battle.started", { battle = battle })
assert(battle.ascendantStoryGym == true, "story Gym marker missing")
assert(battle.ascendantStoryGymDifficulty == "hard", "HARD battle policy missing")
assert(battle.ascendantStoryPreserveAuthoredMoves == true,
  "adaptive composition must preserve authored Gym moves")
assert(table.concat(battle.enemyAIMods, ",") == "1,3", "HARD AI layers")
assert(battle.ascendantStoryGymHealCap == 1, "HARD heal budget")
local action = hooks["battle.enemy_action"].fn(function() return { id = "TACKLE" } end,
  battle)
assert(action.special == "aiItem" and action.item == "SUPER_POTION",
  "HARD deterministic leader heal")
local second = hooks["battle.enemy_action"].fn(function() return { id = "TACKLE" } end,
  battle)
assert(second.id == "TACKLE" and battle.aiUses == 0,
  "HARD heal budget is battle-wide and native duplicate heal is suppressed")

local extremeParty = resolve("OPP_KOGA", "extreme", "yellow")
local extremeBattle = {
  kind = "trainer", oppClass = "OPP_KOGA", partyIndex = 1,
  game = gameFor("OPP_KOGA"), enemyParty = extremeParty,
  enemy = { mon = { hp = 100, stats = { hp = 100 } } }, enemyAIMods = {},
}
emit("battle.started", { battle = extremeBattle })
assert(table.concat(extremeBattle.enemyAIMods, ",") ==
    "1,2,3,KA_REMATCH_USEFUL_MOVE", "VH/Extreme useful AI layers")
assert(extremeBattle.ascendantStoryGymHealCap == 2, "Extreme heal budget")

assert(story.authored.OPP_BROCK.aceLevel.red == 14,
  "future adaptive seam exposes authored ace")
assert(story.authored.OPP_GIOVANNI.ceiling == 72,
  "future adaptive seam exposes bounded story ceiling")
assert(story.authored.OPP_BROCK.teamCap.extreme == 4,
  "future adaptive seam exposes tier team cap")

-- An abandoned/interleaved constructor cannot donate its policy to a later
-- same-class/index/map battle whose resolved party differs.
local staleParty = resolve("OPP_BROCK", "hard", "red")
local staleBattle = {
  kind = "trainer", oppClass = "OPP_BROCK", partyIndex = 1,
  game = gameFor("OPP_BROCK"), enemyParty = clone(staleParty), enemyAIMods = {},
}
staleBattle.enemyParty[1].species = "DITTO"
emit("battle.started", { battle = staleBattle })
assert(staleBattle.ascendantStoryGym == nil,
  "stale pending policy attached to a different resolved party")

print("story_gym_difficulty_test: PASS")
