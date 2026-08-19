-- Registered Gen-II/III expansion attacks require both a species-legal
-- source and the existing save-scoped extended-move authority.
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local checks = 0
local function check(value, message)
  checks = checks + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  checks = checks + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end

local extended = {
  FIREMON = "OVERHEAT",
  WATERMON = "HYDRO_CANNON",
  GRASSMON = "FRENZY_PLANT",
}
local moves = {
  TACKLE = { id = "TACKLE", type = "NORMAL", power = 35, accuracy = 95, pp = 35 },
  BODY_SLAM = { id = "BODY_SLAM", type = "NORMAL", power = 85, accuracy = 100, pp = 15 },
  EARTHQUAKE = { id = "EARTHQUAKE", type = "GROUND", power = 100, accuracy = 100, pp = 10 },
  FLAMETHROWER = { id = "FLAMETHROWER", type = "FIRE", power = 95, accuracy = 100, pp = 15 },
  SURF = { id = "SURF", type = "WATER", power = 95, accuracy = 100, pp = 15 },
  RAZOR_LEAF = { id = "RAZOR_LEAF", type = "GRASS", power = 55, accuracy = 95, pp = 25 },
  OVERHEAT = { id = "OVERHEAT", type = "FIRE", power = 140, accuracy = 90, pp = 5 },
  HYDRO_CANNON = { id = "HYDRO_CANNON", type = "WATER", power = 150, accuracy = 90, pp = 5 },
  FRENZY_PLANT = { id = "FRENZY_PLANT", type = "GRASS", power = 150, accuracy = 90, pp = 5 },
}
local pokemon = {
  FIREMON = {
    types = { "FIRE" }, baseStats = { hp = 80, attack = 90, defense = 75, speed = 90, special = 110 },
    level1Moves = { "TACKLE", "FLAMETHROWER" }, learnset = {},
    tmhm = { "OVERHEAT", "BODY_SLAM", "EARTHQUAKE" },
  },
  WATERMON = {
    types = { "WATER" }, baseStats = { hp = 85, attack = 85, defense = 90, speed = 75, special = 110 },
    level1Moves = { "TACKLE", "SURF" }, learnset = {},
    tmhm = { "HYDRO_CANNON", "BODY_SLAM", "EARTHQUAKE" },
  },
  GRASSMON = {
    types = { "GRASS" }, baseStats = { hp = 85, attack = 90, defense = 85, speed = 75, special = 110 },
    level1Moves = { "TACKLE", "RAZOR_LEAF" }, learnset = {},
    tmhm = { "FRENZY_PLANT", "BODY_SLAM", "EARTHQUAKE" },
  },
  ILLEGALMON = {
    types = { "NORMAL" }, baseStats = { hp = 80, attack = 90, defense = 80, speed = 80, special = 80 },
    level1Moves = { "TACKLE" }, learnset = {}, tmhm = { "BODY_SLAM" },
  },
}
local game = { data = { moves = moves, pokemon = pokemon } }
local Mastery = assert(loadfile(modPath .. "/rematch_mastery.lua"))().create({
  extendedMoveAllowed = function(_, _, _, context)
    return context.extendedUnlocked == true
  end,
})
local Stats = {}
function Stats.calc(_, level, dvs)
  return {
    hp = 100 + level + (dvs.hp or 0), attack = 80 + level + (dvs.attack or 0),
    defense = 80 + level + (dvs.defense or 0), speed = 80 + level + (dvs.speed or 0),
    special = 80 + level + (dvs.special or 0),
  }
end

local function mon(species, authored)
  local out = {
    species = species, level = 100, hp = 200,
    dvs = { hp = 0, attack = 8, defense = 8, speed = 8, special = 8 },
    statExp = {}, stats = {}, moves = {},
  }
  for _, id in ipairs(authored or { "TACKLE" }) do
    out.moves[#out.moves + 1] = { id = id, pp = moves[id].pp }
  end
  return out
end

local function hasMove(candidate, id)
  for _, move in ipairs(candidate.moves or {}) do
    if move.id == id then return true end
  end
  return false
end

for species, moveId in pairs(extended) do
  local locked = Mastery.legalMoves(game, mon(species), {
    johtoUnlocked = true, extendedUnlocked = false,
  })
  eq(locked[moveId], nil, moveId .. " leaked before extended authority")

  local unlocked = Mastery.legalMoves(game, mon(species), {
    johtoUnlocked = true, extendedUnlocked = true,
  })
  eq(unlocked[moveId], true,
    moveId .. " is not legal after its registered authority unlock")

  local reachable = false
  for index = 1, 48 do
    local candidate = mon(species)
    local battle = { enemyParty = { candidate }, enemy = { mon = candidate } }
    Mastery.apply(game, battle, {
      Stats = Stats, kind = "field", progress = 60, masteryWins = 12,
      johtoUnlocked = true, extendedUnlocked = true,
      variantAuthority = "extended-authority:" .. species .. ":" .. index,
    })
    local legal = Mastery.legalMoves(game, candidate, {
      johtoUnlocked = true, extendedUnlocked = true,
    })
    local damagingTypes, stab, damage = {}, false, 0
    for _, move in ipairs(candidate.moves) do
      check(legal[move.id] == true,
        species .. " selected illegal move " .. tostring(move.id))
      local def = moves[move.id]
      if def.power > 0 then
        damage = damage + 1
        damagingTypes[def.type] = true
        stab = stab or def.type == pokemon[species].types[1]
      end
    end
    local coverage = 0
    for _ in pairs(damagingTypes) do coverage = coverage + 1 end
    check(stab and damage >= 2 and coverage >= 2,
      species .. " authority variant lowered set quality")
    reachable = reachable or hasMove(candidate, moveId)
  end
  check(reachable, moveId .. " is legal but unreachable from variant pools")
end

for _, moveId in ipairs({ "OVERHEAT", "HYDRO_CANNON", "FRENZY_PLANT" }) do
  local illegal = mon("ILLEGALMON", { "TACKLE", moveId })
  local legal = Mastery.legalMoves(game, illegal, {
    johtoUnlocked = true, extendedUnlocked = true,
  })
  eq(legal[moveId], nil,
    "authored " .. moveId .. " fabricated species legality")
  local battle = { enemyParty = { illegal } }
  Mastery.apply(game, battle, {
    Stats = Stats, kind = "field", progress = 60, masteryWins = 12,
    johtoUnlocked = true, extendedUnlocked = true,
    variantAuthority = "illegal-species:" .. moveId,
  })
  check(not hasMove(illegal, moveId),
    "illegal species retained " .. moveId .. " after mastery")
end

print(("REMATCH EXTENDED MOVE AUTHORITY PASS: %d checks"):format(checks))
