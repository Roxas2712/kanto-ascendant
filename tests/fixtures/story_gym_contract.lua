-- ROM-free public-CI contract for the eight first-story Gym parties.
--
-- Complete edition data remains part of the private release matrix.  This
-- fixture deliberately carries only the canonical input rows and the
-- independently audited legality source of each authored Gen-I move.

local function party(rows)
  local out = {}
  for index, row in ipairs(rows) do
    out[index] = { species = row[1], level = row[2] }
  end
  return out
end

local function edition(cores)
  local out = {}
  for class, rows in pairs(cores) do
    local index = class == "OPP_GIOVANNI" and 3 or 1
    local parties = {}
    for slot = 1, index - 1 do
      parties[slot] = { { species = "DITTO", level = 1 } }
    end
    parties[index] = party(rows)
    out[class] = { parties = parties }
  end
  return out
end

local red = {
  OPP_BROCK = { { "GEODUDE", 12 }, { "ONIX", 14 } },
  OPP_MISTY = { { "STARYU", 18 }, { "STARMIE", 21 } },
  OPP_LT_SURGE = {
    { "VOLTORB", 21 }, { "PIKACHU", 18 }, { "RAICHU", 24 },
  },
  OPP_ERIKA = {
    { "VICTREEBEL", 29 }, { "TANGELA", 24 }, { "VILEPLUME", 29 },
  },
  OPP_KOGA = {
    { "KOFFING", 37 }, { "MUK", 39 }, { "KOFFING", 37 },
    { "WEEZING", 43 },
  },
  OPP_SABRINA = {
    { "KADABRA", 38 }, { "MR_MIME", 37 }, { "VENOMOTH", 38 },
    { "ALAKAZAM", 43 },
  },
  OPP_BLAINE = {
    { "GROWLITHE", 42 }, { "PONYTA", 40 }, { "RAPIDASH", 42 },
    { "ARCANINE", 47 },
  },
  OPP_GIOVANNI = {
    { "RHYHORN", 45 }, { "DUGTRIO", 42 }, { "NIDOQUEEN", 44 },
    { "NIDOKING", 45 }, { "RHYDON", 50 },
  },
}

local yellow = {
  OPP_BROCK = { { "GEODUDE", 10 }, { "ONIX", 12 } },
  OPP_MISTY = { { "STARYU", 18 }, { "STARMIE", 21 } },
  OPP_LT_SURGE = { { "RAICHU", 28 } },
  OPP_ERIKA = {
    { "TANGELA", 30 }, { "WEEPINBELL", 32 }, { "GLOOM", 32 },
  },
  OPP_KOGA = {
    { "VENONAT", 44 }, { "VENONAT", 46 }, { "VENONAT", 48 },
    { "VENOMOTH", 50 },
  },
  OPP_SABRINA = {
    { "ABRA", 50 }, { "KADABRA", 50 }, { "ALAKAZAM", 50 },
  },
  OPP_BLAINE = {
    { "NINETALES", 48 }, { "RAPIDASH", 50 }, { "ARCANINE", 54 },
  },
  OPP_GIOVANNI = {
    { "DUGTRIO", 50 }, { "PERSIAN", 53 }, { "NIDOQUEEN", 53 },
    { "NIDOKING", 55 }, { "RHYDON", 55 },
  },
}

return {
  trainers = {
    red = edition(red), blue = edition(red), yellow = edition(yellow),
  },
  moveSources = {
    ABRA = { PSYCHIC_M = "tmhm", REFLECT = "tmhm", SEISMIC_TOSS = "tmhm", THUNDER_WAVE = "tmhm" },
    ALAKAZAM = { PSYCHIC_M = "level", RECOVER = "level", REFLECT = "level", THUNDER_WAVE = "tmhm" },
    ARBOK = { ACID = "retained", BITE = "level", GLARE = "level", WRAP = "level1" },
    ARCANINE = { AGILITY = "retained", BODY_SLAM = "tmhm", DIG = "tmhm", FIRE_BLAST = "tmhm" },
    DUGTRIO = { EARTHQUAKE = "level", ROCK_SLIDE = "tmhm", SAND_ATTACK = "level", SLASH = "level" },
    ELECTABUZZ = { QUICK_ATTACK = "level1", SUBMISSION = "tmhm", THUNDERBOLT = "tmhm", THUNDER_WAVE = "tmhm" },
    EXEGGCUTE = { HYPNOSIS = "level1", LEECH_SEED = "level", PSYCHIC_M = "tmhm", REFLECT = "level" },
    EXEGGUTOR = { HYPNOSIS = "level1", MEGA_DRAIN = "tmhm", PSYCHIC_M = "tmhm", REFLECT = "tmhm" },
    FLAREON = { BITE = "level", BODY_SLAM = "tmhm", FIRE_BLAST = "tmhm", REFLECT = "tmhm" },
    GEODUDE = { BIDE = "tmhm", BODY_SLAM = "tmhm", ROCK_SLIDE = "tmhm", TACKLE = "level1" },
    GLOOM = { ACID = "level", MEGA_DRAIN = "tmhm", SLEEP_POWDER = "level", STUN_SPORE = "level1" },
    GOLBAT = { BITE = "level1", CONFUSE_RAY = "level", TOXIC = "tmhm", WING_ATTACK = "level" },
    GROWLITHE = { AGILITY = "level", FIRE_BLAST = "tmhm", LEER = "level", TAKE_DOWN = "level" },
    HORSEA = { BUBBLEBEAM = "tmhm", ICE_BEAM = "tmhm", SMOKESCREEN = "level", SWIFT = "tmhm" },
    HYPNO = { BODY_SLAM = "tmhm", DREAM_EATER = "tmhm", HYPNOSIS = "level1", PSYCHIC_M = "level" },
    JOLTEON = { BODY_SLAM = "tmhm", QUICK_ATTACK = "level1", THUNDERBOLT = "tmhm", THUNDER_WAVE = "tmhm" },
    JYNX = { BODY_SLAM = "level", ICE_PUNCH = "level", LOVELY_KISS = "level1", PSYCHIC_M = "tmhm" },
    KADABRA = { PSYBEAM = "level", PSYCHIC_M = "level", RECOVER = "level", REFLECT = "level" },
    KOFFING = { SELFDESTRUCT = "tmhm", SLUDGE = "level", SMOKESCREEN = "level", TOXIC = "tmhm" },
    MAGMAR = { CONFUSE_RAY = "level", FIRE_BLAST = "tmhm", PSYCHIC_M = "tmhm", SUBMISSION = "tmhm" },
    MAGNEMITE = { SONICBOOM = "level", SWIFT = "tmhm", THUNDERBOLT = "tmhm", THUNDER_WAVE = "tmhm" },
    MAGNETON = { SONICBOOM = "level1", SWIFT = "tmhm", THUNDERBOLT = "tmhm", THUNDER_WAVE = "tmhm" },
    MR_MIME = { BARRIER = "level1", LIGHT_SCREEN = "level", PSYCHIC_M = "tmhm", THUNDERBOLT = "tmhm" },
    MUK = { BODY_SLAM = "tmhm", MINIMIZE = "level", SLUDGE = "level", TOXIC = "tmhm" },
    NIDOKING = { DOUBLE_KICK = "retained", EARTHQUAKE = "tmhm", THRASH = "level1", THUNDERBOLT = "tmhm" },
    NIDOQUEEN = { BODY_SLAM = "level1", DOUBLE_KICK = "retained", EARTHQUAKE = "tmhm", THUNDER = "tmhm" },
    NINETALES = { CONFUSE_RAY = "retained", FLAMETHROWER = "retained", QUICK_ATTACK = "level1", REFLECT = "tmhm" },
    ONIX = { BIDE = "tmhm", DIG = "tmhm", ROCK_SLIDE = "tmhm", SCREECH = "level1" },
    PARASECT = { LEECH_LIFE = "level1", MEGA_DRAIN = "tmhm", STUN_SPORE = "level1", SWORDS_DANCE = "tmhm" },
    PERSIAN = { BUBBLEBEAM = "tmhm", DOUBLE_TEAM = "tmhm", PAY_DAY = "level", SLASH = "level" },
    PIKACHU = { DOUBLE_TEAM = "tmhm", QUICK_ATTACK = "level", THUNDERBOLT = "tmhm", THUNDER_WAVE = "level" },
    PONYTA = { BODY_SLAM = "tmhm", FIRE_SPIN = "level", STOMP = "level", TAKE_DOWN = "tmhm" },
    PSYDUCK = { BODY_SLAM = "tmhm", DIG = "tmhm", ICE_BEAM = "tmhm", WATER_GUN = "tmhm" },
    RAICHU = { MEGA_KICK = "tmhm", MEGA_PUNCH = "tmhm", THUNDERBOLT = "tmhm", THUNDER_WAVE = "level1" },
    RAPIDASH = { BODY_SLAM = "tmhm", FIRE_BLAST = "tmhm", FIRE_SPIN = "level", TAKE_DOWN = "level" },
    RHYDON = { EARTHQUAKE = "tmhm", FISSURE = "tmhm", ROCK_SLIDE = "tmhm", STOMP = "level1" },
    RHYHORN = { BODY_SLAM = "tmhm", DIG = "tmhm", HORN_ATTACK = "level1", ROCK_SLIDE = "tmhm" },
    SANDSHREW = { DIG = "tmhm", ROCK_SLIDE = "tmhm", SWIFT = "tmhm", SWORDS_DANCE = "tmhm" },
    SANDSLASH = { EARTHQUAKE = "tmhm", SAND_ATTACK = "level1", SLASH = "level", SWORDS_DANCE = "tmhm" },
    STARMIE = { BUBBLEBEAM = "tmhm", PSYCHIC_M = "tmhm", SWIFT = "tmhm", THUNDER_WAVE = "tmhm" },
    STARYU = { BUBBLEBEAM = "tmhm", PSYCHIC_M = "tmhm", SWIFT = "tmhm", THUNDER_WAVE = "tmhm" },
    TANGELA = { BIND = "level", MEGA_DRAIN = "tmhm", SWORDS_DANCE = "tmhm", TOXIC = "tmhm" },
    VENOMOTH = { DOUBLE_TEAM = "tmhm", PSYCHIC_M = "level", SLEEP_POWDER = "retained", TOXIC = "tmhm" },
    VENONAT = { LEECH_LIFE = "level", PSYCHIC_M = "level", SLEEP_POWDER = "level", TOXIC = "tmhm" },
    VICTREEBEL = { MEGA_DRAIN = "tmhm", RAZOR_LEAF = "level1", SLEEP_POWDER = "level1", WRAP = "level" },
    VILEPLUME = { ACID = "level1", MEGA_DRAIN = "tmhm", PETAL_DANCE = "level1", SLEEP_POWDER = "level1" },
    VOLTORB = { SCREECH = "level1", SELFDESTRUCT = "level", SONICBOOM = "level", THUNDER_WAVE = "tmhm" },
    WEEPINBELL = { ACID = "level", MEGA_DRAIN = "tmhm", SLEEP_POWDER = "level", WRAP = "level1" },
    WEEZING = { EXPLOSION = "tmhm", SLUDGE = "level1", SMOKESCREEN = "level", TOXIC = "tmhm" },
  },
}
