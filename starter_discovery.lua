-- Kanto Ascendant 6.7 Discovery Core: Generation IV-VII starter sightings.
--
-- Phase 1 deliberately receives habitat eligibility and the 1..10000 roll
-- from its caller.  It owns no map table and performs no random draw.  That
-- keeps classic encounters and visible Wilds on the same deterministic seam.

local Module = {
  SIGHTING_ROLL_MAX = 10000,
  SIGHTING_HIT_MAX = 200,
  HARD_SIGHTING_ENCOUNTER = 151,
}

local CATALOG = {
  { id = "TURTWIG", generation = "gen4",
    members = { "TURTWIG", "GROTLE", "TORTERRA" }, theme = "forest" },
  { id = "CHIMCHAR", generation = "gen4",
    members = { "CHIMCHAR", "MONFERNO", "INFERNAPE" }, theme = "warm" },
  { id = "PIPLUP", generation = "gen4",
    members = { "PIPLUP", "PRINPLUP", "EMPOLEON" }, theme = "water" },
  { id = "SNIVY", generation = "gen5",
    members = { "SNIVY", "SERVINE", "SERPERIOR" }, theme = "forest" },
  { id = "TEPIG", generation = "gen5",
    members = { "TEPIG", "PIGNITE", "EMBOAR" }, theme = "warm" },
  { id = "OSHAWOTT", generation = "gen5",
    members = { "OSHAWOTT", "DEWOTT", "SAMUROTT" }, theme = "water" },
  { id = "CHESPIN", generation = "gen6",
    members = { "CHESPIN", "QUILLADIN", "CHESNAUGHT" }, theme = "forest" },
  { id = "FENNEKIN", generation = "gen6",
    members = { "FENNEKIN", "BRAIXEN", "DELPHOX" }, theme = "warm" },
  { id = "FROAKIE", generation = "gen6",
    members = { "FROAKIE", "FROGADIER", "GRENINJA" }, theme = "water" },
  { id = "ROWLET", generation = "gen7",
    members = { "ROWLET", "DARTRIX", "DECIDUEYE" }, theme = "forest" },
  { id = "LITTEN", generation = "gen7",
    members = { "LITTEN", "TORRACAT", "INCINEROAR" }, theme = "warm" },
  { id = "POPPLIO", generation = "gen7",
    members = { "POPPLIO", "BRIONNE", "PRIMARINA" }, theme = "water" },
}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do
    out[copy(key, seen)] = copy(child, seen)
  end
  return out
end

local function integerRoll(value)
  return type(value) == "number" and value == math.floor(value)
    and value >= 1 and value <= Module.SIGHTING_ROLL_MAX
end

function Module.create(State)
  assert(State and type(State.normalize) == "function"
      and type(State.mark) == "function"
      and type(State.unlock) == "function",
    "Starter Discovery requires Discovery State")

  local S = {
    SIGHTING_ROLL_MAX = Module.SIGHTING_ROLL_MAX,
    SIGHTING_HIT_MAX = Module.SIGHTING_HIT_MAX,
    HARD_SIGHTING_ENCOUNTER = Module.HARD_SIGHTING_ENCOUNTER,
    order = {},
    families = {},
  }
  local speciesToFamily = {}

  for _, source in ipairs(CATALOG) do
    local def = copy(source)
    S.order[#S.order + 1] = def.id
    S.families[def.id] = def
    for _, species in ipairs(def.members) do
      assert(not speciesToFamily[species],
        "duplicate starter species: " .. tostring(species))
      speciesToFamily[species] = def.id
    end
  end

  function S.familyForSpecies(species)
    local familyId = type(species) == "string"
      and speciesToFamily[species:upper()] or nil
    local def = familyId and S.families[familyId] or nil
    return def and copy(def) or nil
  end

  function S.definition(family)
    local familyId = type(family) == "string" and family:upper() or nil
    local def = familyId and S.families[familyId] or nil
    return def and copy(def) or nil
  end

  function S.plan(state, family, eligible, roll)
    local familyId = type(family) == "string" and family:upper() or nil
    local def = familyId and S.families[familyId] or nil
    local out = State.normalize(state)
    if not def then
      return out, {
        eligible = false, rollsUsed = 0, sighted = false,
        reason = "unknown-starter-family",
      }
    end
    if eligible ~= true then
      return out, {
        family = familyId, generation = def.generation,
        eligible = false, rollsUsed = 0, sighted = false,
        reason = "ineligible-habitat",
      }
    end
    if not integerRoll(roll) then
      return out, {
        family = familyId, generation = def.generation,
        eligible = true, rollsUsed = 0, sighted = false,
        reason = "roll-out-of-range",
      }
    end

    local encounter = State.sightingPity(out, def.generation, familyId) + 1
    local natural = roll <= Module.SIGHTING_HIT_MAX
    local guaranteed = not natural
      and encounter >= Module.HARD_SIGHTING_ENCOUNTER
    local sighted = natural or guaranteed
    if sighted then
      out = State.mark(out, def.generation, familyId, "sighted")
      out = State.setSightingPity(out, def.generation, familyId, 0)
    else
      out = State.setSightingPity(out, def.generation, familyId, encounter)
    end
    return out, {
      family = familyId,
      generation = def.generation,
      eligible = true,
      eligibleEncounter = encounter,
      roll = roll,
      rollsUsed = 1,
      sighted = sighted,
      natural = natural,
      guaranteed = guaranteed,
    }
  end

  function S.recordCatch(state, species)
    local def = S.familyForSpecies(species)
    local out = State.normalize(state)
    if not def then
      return out, {
        caught = false, unlocked = false,
        reason = "unknown-starter-family",
      }
    end
    out = State.mark(out, def.generation, def.id, "caught")
    local unlocked
    out, unlocked = State.unlock(out, def.generation, def.id)
    return out, {
      family = def.id,
      generation = def.generation,
      species = type(species) == "string" and species:upper() or species,
      caught = true,
      unlocked = unlocked == true
        or State.status(out, def.generation, def.id) == "unlocked",
    }
  end

  S.copy = copy
  return S
end

Module.catalog = function() return copy(CATALOG) end
return Module
