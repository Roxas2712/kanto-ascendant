-- Exact Pokémon Yellow SpecialTrainerMoves reconstruction for the eight
-- first-story Gym parties.  A caller supplies cloned trainer.party rows;
-- this module never registers hooks and never touches Red/Blue data.

local Y = {}

Y.moves = {
  OPP_BROCK = {
    { "TACKLE" }, { "TACKLE", "SCREECH", "BIND", "BIDE" },
  },
  OPP_MISTY = {
    { "TACKLE", "WATER_GUN" },
    { "TACKLE", "WATER_GUN", "HARDEN", "BUBBLEBEAM" },
  },
  OPP_LT_SURGE = {
    { "THUNDERBOLT", "MEGA_PUNCH", "MEGA_KICK", "GROWL" },
  },
  OPP_ERIKA = {
    { "CONSTRICT", "BIND", "MEGA_DRAIN", "VINE_WHIP" },
    { "RAZOR_LEAF", "SLEEP_POWDER", "STUN_SPORE", "ACID" },
    { "PETAL_DANCE", "STUN_SPORE", "SLEEP_POWDER", "ACID" },
  },
  OPP_KOGA = {
    { "TOXIC", "TACKLE", "SLEEP_POWDER", "PSYCHIC_M" },
    { "TOXIC", "PSYBEAM", "SUPERSONIC", "PSYCHIC_M" },
    { "TOXIC", "DOUBLE_EDGE", "SLEEP_POWDER", "PSYCHIC_M" },
    { "LEECH_LIFE", "DOUBLE_TEAM", "PSYCHIC_M", "TOXIC" },
  },
  OPP_SABRINA = {
    { "FLASH" },
    { "KINESIS", "RECOVER", "PSYCHIC_M", "PSYWAVE" },
    { "PSYWAVE", "RECOVER", "PSYCHIC_M", "REFLECT" },
  },
  OPP_BLAINE = {
    { "FLAMETHROWER", "TAIL_WHIP", "QUICK_ATTACK", "CONFUSE_RAY" },
    { "STOMP", "GROWL", "FIRE_SPIN", "TAKE_DOWN" },
    { "FLAMETHROWER", "FIRE_BLAST", "REFLECT", "TAKE_DOWN" },
  },
  OPP_GIOVANNI = {
    { "DIG", "SAND_ATTACK", "FISSURE", "EARTHQUAKE" },
    { "SCREECH", "DOUBLE_TEAM", "FURY_SWIPES", "SLASH" },
    { "EARTHQUAKE", "TAIL_WHIP", "THUNDER", "DOUBLE_KICK" },
    { "EARTHQUAKE", "LEER", "THUNDER", "DOUBLE_KICK" },
    { "ROCK_SLIDE", "FURY_ATTACK", "HORN_DRILL", "EARTHQUAKE" },
  },
}

local function copyList(rows)
  local out = {}
  for index, value in ipairs(rows or {}) do out[index] = value end
  return out
end

function Y.apply(class, party)
  local exact = Y.moves[class]
  if type(exact) ~= "table" or type(party) ~= "table" or #party ~= #exact then
    return party, false
  end
  for index, moves in ipairs(exact) do party[index].moves = copyList(moves) end
  return party, true
end

return Y
