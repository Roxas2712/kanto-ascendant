-- Pure data for the post-game expansion.  Keeping the rosters separate from
-- the runtime controller makes the progression and every boss team easy to
-- inspect (and lets the headless suite validate them without a running game).

local function mon(species, level, moves)
  return { species = species, level = level, moves = moves }
end

local D = {}

D.species = {
  RAIKOU = {
    name = "RAIKOU", dex = 243, types = { "ELECTRIC" },
    stats = { hp = 90, attack = 85, defense = 75, speed = 115, special = 115 },
    catchRate = 3, baseExp = 216, cryBase = "ZAPDOS", pitch = 112, length = 144,
    level1 = { "BITE", "LEER", "THUNDERSHOCK", "ROAR" },
    learnset = {
      { level = 31, move = "THUNDER_WAVE" }, { level = 41, move = "AGILITY" },
      { level = 51, move = "THUNDER" },
    },
  },
  ENTEI = {
    name = "ENTEI", dex = 244, types = { "FIRE" },
    stats = { hp = 115, attack = 115, defense = 85, speed = 100, special = 90 },
    catchRate = 3, baseExp = 217, cryBase = "ARCANINE", pitch = 96, length = 160,
    level1 = { "BITE", "LEER", "EMBER", "ROAR" },
    learnset = {
      { level = 31, move = "STOMP" }, { level = 41, move = "FIRE_SPIN" },
      { level = 51, move = "FIRE_BLAST" },
    },
  },
  SUICUNE = {
    name = "SUICUNE", dex = 245, types = { "WATER" },
    stats = { hp = 100, attack = 75, defense = 115, speed = 85, special = 115 },
    catchRate = 3, baseExp = 215, cryBase = "LAPRAS", pitch = 144, length = 144,
    level1 = { "BITE", "LEER", "BUBBLEBEAM", "MIST" },
    learnset = {
      { level = 31, move = "AURORA_BEAM" }, { level = 41, move = "REST" },
      { level = 51, move = "HYDRO_PUMP" },
    },
  },
  LUGIA = {
    name = "LUGIA", dex = 249, types = { "PSYCHIC_TYPE", "FLYING" },
    stats = { hp = 106, attack = 90, defense = 130, speed = 110, special = 130 },
    catchRate = 3, baseExp = 220, cryBase = "ARTICUNO", pitch = 128, length = 176,
    level1 = { "GUST", "RECOVER", "HYDRO_PUMP", "AEROBLAST" },
    learnset = {
      { level = 33, move = "LIGHT_SCREEN" }, { level = 44, move = "RECOVER" },
      { level = 55, move = "HYDRO_PUMP" },
    },
  },
  HO_OH = {
    name = "HO-OH", dex = 250, types = { "FIRE", "FLYING" },
    stats = { hp = 106, attack = 130, defense = 90, speed = 90, special = 110 },
    catchRate = 3, baseExp = 220, cryBase = "MOLTRES", pitch = 104, length = 176,
    level1 = { "GUST", "RECOVER", "FIRE_BLAST", "SACRED_FIRE" },
    learnset = {
      { level = 33, move = "MIST" }, { level = 44, move = "RECOVER" },
      { level = 55, move = "FIRE_BLAST" },
    },
  },
  CELEBI = {
    name = "CELEBI", dex = 251, types = { "PSYCHIC_TYPE", "GRASS" },
    stats = { hp = 100, attack = 100, defense = 100, speed = 100, special = 100 },
    catchRate = 3, baseExp = 220, cryBase = "MEW", pitch = 176, length = 112,
    level1 = { "CONFUSION", "LEECH_SEED", "RECOVER", "PSYCHIC_M" },
    learnset = {
      { level = 30, move = "RAZOR_LEAF" }, { level = 40, move = "RECOVER" },
      { level = 50, move = "PSYCHIC_M" },
    },
  },
}

D.gyms = {
  {
    key = "brock", name = "BROCK", class = "OPP_BROCK", map = "PEWTER_GYM",
    master = {
      mon("GOLEM", 76, { "ROCK_SLIDE", "EARTHQUAKE", "BODY_SLAM", "EXPLOSION" }),
      mon("RHYDON", 76, { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" }),
      mon("ONIX", 75, { "ROCK_SLIDE", "EARTHQUAKE", "BIND", "EXPLOSION" }),
      mon("OMASTAR", 77, { "SURF", "BLIZZARD", "BODY_SLAM", "HYDRO_PUMP" }),
      mon("KABUTOPS", 77, { "SLASH", "SURF", "MEGA_DRAIN", "SWORDS_DANCE" }),
      mon("AERODACTYL", 78, { "ROCK_SLIDE", "SKY_ATTACK", "HYPER_BEAM", "FIRE_BLAST" }),
    },
  },
  {
    key = "misty", name = "MISTY", class = "OPP_MISTY", map = "CERULEAN_GYM",
    master = {
      mon("STARMIE", 79, { "SURF", "PSYCHIC_M", "THUNDERBOLT", "RECOVER" }),
      mon("LAPRAS", 78, { "BLIZZARD", "SURF", "THUNDERBOLT", "BODY_SLAM" }),
      mon("CLOYSTER", 78, { "BLIZZARD", "SURF", "EXPLOSION", "CLAMP" }),
      mon("SLOWBRO", 79, { "SURF", "PSYCHIC_M", "AMNESIA", "REST" }),
      mon("VAPOREON", 78, { "SURF", "ICE_BEAM", "ACID_ARMOR", "REST" }),
      mon("GYARADOS", 80, { "HYDRO_PUMP", "BLIZZARD", "THUNDERBOLT", "HYPER_BEAM" }),
    },
  },
  {
    key = "surge", name = "LT.SURGE", class = "OPP_LT_SURGE", map = "VERMILION_GYM",
    master = {
      mon("ELECTRODE", 80, { "THUNDER", "THUNDER_WAVE", "EXPLOSION", "REFLECT" }),
      mon("GOROCHU", 81, { "THUNDER", "BITE", "BODY_SLAM", "THUNDER_WAVE" }),
      mon("MAGNETON", 80, { "THUNDERBOLT", "THUNDER_WAVE", "SWIFT", "SCREECH" }),
      mon("ELECTABUZZ", 81, { "THUNDERBOLT", "PSYCHIC_M", "SUBMISSION", "THUNDER_WAVE" }),
      mon("JOLTEON", 82, { "THUNDERBOLT", "PIN_MISSILE", "DOUBLE_KICK", "AGILITY" }),
      mon("ELECTRODE", 82, { "THUNDER", "LIGHT_SCREEN", "EXPLOSION", "SWIFT" }),
    },
  },
  {
    key = "erika", name = "ERIKA", class = "OPP_ERIKA", map = "CELADON_GYM",
    master = {
      mon("VENUSAUR", 82, { "RAZOR_LEAF", "BODY_SLAM", "SLEEP_POWDER", "SWORDS_DANCE" }),
      mon("VILEPLUME", 82, { "PETAL_DANCE", "MEGA_DRAIN", "SLEEP_POWDER", "TOXIC" }),
      mon("VICTREEBEL", 83, { "RAZOR_LEAF", "WRAP", "SLEEP_POWDER", "HYPER_BEAM" }),
      mon("EXEGGUTOR", 83, { "PSYCHIC_M", "MEGA_DRAIN", "SLEEP_POWDER", "EXPLOSION" }),
      mon("TANGELA", 82, { "MEGA_DRAIN", "SLEEP_POWDER", "GROWTH", "BODY_SLAM" }),
      mon("PARASECT", 84, { "SPORE", "SLASH", "MEGA_DRAIN", "SWORDS_DANCE" }),
    },
  },
  {
    key = "koga", name = "KOGA", class = "OPP_KOGA", map = "FUCHSIA_GYM",
    master = {
      mon("VENOMOTH", 83, { "PSYCHIC_M", "MEGA_DRAIN", "SLEEP_POWDER", "DOUBLE_TEAM" }),
      mon("MUK", 84, { "SLUDGE", "BODY_SLAM", "MINIMIZE", "EXPLOSION" }),
      mon("WEEZING", 84, { "SLUDGE", "THUNDERBOLT", "FIRE_BLAST", "EXPLOSION" }),
      mon("TENTACRUEL", 85, { "SURF", "BLIZZARD", "WRAP", "TOXIC" }),
      mon("NIDOKING", 85, { "EARTHQUAKE", "THUNDERBOLT", "BLIZZARD", "ROCK_SLIDE" }),
      mon("NIDOQUEEN", 85, { "EARTHQUAKE", "THUNDER", "FIRE_BLAST", "BODY_SLAM" }),
    },
  },
  {
    key = "sabrina", name = "SABRINA", class = "OPP_SABRINA", map = "SAFFRON_GYM",
    master = {
      mon("ALAKAZAM", 86, { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
      mon("SLOWBRO", 85, { "PSYCHIC_M", "SURF", "AMNESIA", "REST" }),
      mon("EXEGGUTOR", 85, { "PSYCHIC_M", "MEGA_DRAIN", "SLEEP_POWDER", "EXPLOSION" }),
      mon("JYNX", 85, { "BLIZZARD", "PSYCHIC_M", "LOVELY_KISS", "BODY_SLAM" }),
      mon("MR_MIME", 85, { "PSYCHIC_M", "THUNDERBOLT", "SUBSTITUTE", "MEDITATE" }),
      mon("HYPNO", 86, { "PSYCHIC_M", "HYPNOSIS", "DREAM_EATER", "THUNDER_WAVE" }),
    },
  },
  {
    key = "blaine", name = "BLAINE", class = "OPP_BLAINE", map = "CINNABAR_GYM",
    master = {
      mon("CHARIZARD", 86, { "FIRE_BLAST", "SLASH", "EARTHQUAKE", "SWORDS_DANCE" }),
      mon("ARCANINE", 87, { "FIRE_BLAST", "BODY_SLAM", "DIG", "AGILITY" }),
      mon("NINETALES", 86, { "FIRE_BLAST", "CONFUSE_RAY", "BODY_SLAM", "REFLECT" }),
      mon("RAPIDASH", 87, { "FIRE_BLAST", "BODY_SLAM", "HYPER_BEAM", "AGILITY" }),
      mon("MAGMAR", 87, { "FIRE_BLAST", "PSYCHIC_M", "SUBMISSION", "CONFUSE_RAY" }),
      mon("FLAREON", 88, { "FIRE_BLAST", "BODY_SLAM", "BITE", "REFLECT" }),
    },
  },
  {
    key = "giovanni", name = "GIOVANNI", class = "OPP_GIOVANNI", map = "VIRIDIAN_GYM",
    master = {
      mon("RHYDON", 88, { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" }),
      mon("NIDOKING", 89, { "EARTHQUAKE", "THUNDERBOLT", "BLIZZARD", "FIRE_BLAST" }),
      mon("NIDOQUEEN", 89, { "EARTHQUAKE", "THUNDER", "BLIZZARD", "BODY_SLAM" }),
      mon("DUGTRIO", 88, { "EARTHQUAKE", "ROCK_SLIDE", "SLASH", "SAND_ATTACK" }),
      mon("GOLEM", 89, { "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM", "EXPLOSION" }),
      mon("SANDSLASH", 90, { "EARTHQUAKE", "ROCK_SLIDE", "SLASH", "SWORDS_DANCE" }),
    },
  },
}

D.apex = {
  OPP_LORELEI = {
    mon("DEWGONG", 90, { "BLIZZARD", "SURF", "BODY_SLAM", "REST" }),
    mon("CLOYSTER", 91, { "BLIZZARD", "SURF", "CLAMP", "EXPLOSION" }),
    mon("SLOWBRO", 91, { "PSYCHIC_M", "SURF", "AMNESIA", "REST" }),
    mon("JYNX", 92, { "BLIZZARD", "PSYCHIC_M", "LOVELY_KISS", "BODY_SLAM" }),
    mon("VAPOREON", 92, { "SURF", "ICE_BEAM", "ACID_ARMOR", "REST" }),
    mon("LAPRAS", 93, { "BLIZZARD", "SURF", "THUNDERBOLT", "BODY_SLAM" }),
  },
  OPP_BRUNO = {
    mon("HITMONLEE", 92, { "HI_JUMP_KICK", "BODY_SLAM", "ROCK_SLIDE", "MEDITATE" }),
    mon("HITMONCHAN", 92, { "SUBMISSION", "THUNDERPUNCH", "ICE_PUNCH", "FIRE_PUNCH" }),
    mon("POLIWRATH", 93, { "SUBMISSION", "SURF", "BLIZZARD", "HYPNOSIS" }),
    mon("PRIMEAPE", 93, { "SUBMISSION", "ROCK_SLIDE", "BODY_SLAM", "FOCUS_ENERGY" }),
    mon("GOLEM", 94, { "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM", "EXPLOSION" }),
    mon("MACHAMP", 95, { "SUBMISSION", "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM" }),
  },
  OPP_AGATHA = {
    mon("GENGAR", 94, { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "DREAM_EATER" }),
    mon("ARBOK", 94, { "SLUDGE", "EARTHQUAKE", "ROCK_SLIDE", "GLARE" }),
    mon("WEEZING", 95, { "SLUDGE", "THUNDERBOLT", "FIRE_BLAST", "EXPLOSION" }),
    mon("GOLBAT", 95, { "WING_ATTACK", "CONFUSE_RAY", "TOXIC", "HYPER_BEAM" }),
    mon("HAUNTER", 95, { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "EXPLOSION" }),
    mon("GENGAR", 96, { "PSYCHIC_M", "MEGA_DRAIN", "HYPNOSIS", "EXPLOSION" }),
  },
  OPP_LANCE = {
    mon("GYARADOS", 96, { "HYDRO_PUMP", "BLIZZARD", "THUNDERBOLT", "HYPER_BEAM" }),
    mon("AERODACTYL", 96, { "ROCK_SLIDE", "SKY_ATTACK", "FIRE_BLAST", "HYPER_BEAM" }),
    mon("CHARIZARD", 97, { "FIRE_BLAST", "SLASH", "EARTHQUAKE", "SWORDS_DANCE" }),
    mon("DRAGONAIR", 97, { "BLIZZARD", "THUNDER", "SURF", "THUNDER_WAVE" }),
    mon("DRAGONITE", 98, { "BLIZZARD", "THUNDER", "BODY_SLAM", "HYPER_BEAM" }),
    mon("DRAGONITE", 99, { "BLIZZARD", "THUNDER", "FIRE_BLAST", "HYPER_BEAM" }),
  },
  OPP_RIVAL3 = {
    mon("PIDGEOT", 97, { "SKY_ATTACK", "DOUBLE_EDGE", "MIRROR_MOVE", "AGILITY" }),
    mon("ALAKAZAM", 98, { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
    mon("RHYDON", 98, { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" }),
    mon("EXEGGUTOR", 99, { "PSYCHIC_M", "MEGA_DRAIN", "SLEEP_POWDER", "EXPLOSION" }),
    mon("ARCANINE", 99, { "FIRE_BLAST", "BODY_SLAM", "DIG", "AGILITY" }),
    mon("GYARADOS", 100, { "HYDRO_PUMP", "BLIZZARD", "THUNDERBOLT", "HYPER_BEAM" }),
  },
}

-- One optional, one-time Rival event after the player catches a first legend.
-- His level-100 "hunter" roster covers the major sky, sea and roaming types
-- without using a legendary of its own.
D.huntRival = {
  map = "OAKS_LAB",
  name = "KANTO_ASCENDANT_HUNT_RIVAL",
  text = "MOD_KANTO_ASCENDANT_HUNT_RIVAL",
  sprite = "SPRITE_BLUE",
  class = "OPP_RIVAL3",
  preferred = { { 4, 8 }, { 5, 8 }, { 4, 9 }, { 5, 9 } },
  team = {
    mon("JOLTEON", 100,
      { "THUNDERBOLT", "PIN_MISSILE", "DOUBLE_KICK", "THUNDER_WAVE" }),
    mon("LAPRAS", 100,
      { "BLIZZARD", "SURF", "THUNDERBOLT", "SING" }),
    mon("RHYDON", 100,
      { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" }),
    mon("ALAKAZAM", 100,
      { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
    mon("AERODACTYL", 100,
      { "ROCK_SLIDE", "SKY_ATTACK", "FIRE_BLAST", "HYPER_BEAM" }),
    mon("DRAGONITE", 100,
      { "BLIZZARD", "THUNDER", "SURF", "HYPER_BEAM" }),
  },
}

-- The Crown Circuit uses the same specialist identities, but every slot is
-- level 100 and the unlocked legends finally enter boss rosters.
for _, gym in ipairs(D.gyms) do
  gym.crown = {}
  for _, slot in ipairs(gym.master) do
    gym.crown[#gym.crown + 1] = mon(slot.species, 100, slot.moves)
  end
end
D.gyms[2].crown[6] = mon("SUICUNE", 100,
  { "HYDRO_PUMP", "BLIZZARD", "REST", "BODY_SLAM" })
D.gyms[3].crown[6] = mon("RAIKOU", 100,
  { "THUNDER", "THUNDER_WAVE", "BODY_SLAM", "REFLECT" })
D.gyms[4].crown[6] = mon("CELEBI", 100,
  { "PSYCHIC_M", "RAZOR_LEAF", "RECOVER", "THUNDER_WAVE" })
D.gyms[6].crown[6] = mon("LUGIA", 100,
  { "AEROBLAST", "PSYCHIC_M", "HYDRO_PUMP", "RECOVER" })
D.gyms[7].crown[6] = mon("ENTEI", 100,
  { "SACRED_FIRE", "BODY_SLAM", "REFLECT", "FIRE_BLAST" })

D.crown = {}
for class, team in pairs(D.apex) do
  D.crown[class] = {}
  for _, slot in ipairs(team) do
    D.crown[class][#D.crown[class] + 1] = mon(slot.species, 100, slot.moves)
  end
end
D.crown.OPP_LORELEI[6] = mon("SUICUNE", 100,
  { "HYDRO_PUMP", "BLIZZARD", "REST", "BODY_SLAM" })
D.crown.OPP_LANCE[5] = mon("LUGIA", 100,
  { "AEROBLAST", "PSYCHIC_M", "HYDRO_PUMP", "RECOVER" })
D.crown.OPP_LANCE[6] = mon("HO_OH", 100,
  { "SACRED_FIRE", "SKY_ATTACK", "EARTHQUAKE", "RECOVER" })
D.crown.OPP_RIVAL3 = {
  mon("MEWTWO", 100, { "PSYCHIC_M", "BLIZZARD", "THUNDERBOLT", "RECOVER" }),
  mon("RAIKOU", 100, { "THUNDER", "BODY_SLAM", "REFLECT", "THUNDER_WAVE" }),
  mon("ENTEI", 100, { "SACRED_FIRE", "FIRE_BLAST", "BODY_SLAM", "REFLECT" }),
  mon("SUICUNE", 100, { "HYDRO_PUMP", "BLIZZARD", "REST", "BODY_SLAM" }),
  mon("LUGIA", 100, { "AEROBLAST", "PSYCHIC_M", "HYDRO_PUMP", "RECOVER" }),
  mon("HO_OH", 100, { "SACRED_FIRE", "SKY_ATTACK", "EARTHQUAKE", "RECOVER" }),
}

D.staticLegends = {
  ZAPDOS = {
    map = "POWER_PLANT", text = "TEXT_POWERPLANT_ZAPDOS",
    object = "POWERPLANT_ZAPDOS", flag = "EVENT_BEAT_ZAPDOS",
    level = 80, vanillaLevel = 50,
  },
  ARTICUNO = {
    map = "SEAFOAM_ISLANDS_B4F", text = "TEXT_SEAFOAMISLANDSB4F_ARTICUNO",
    object = "SEAFOAMISLANDSB4F_ARTICUNO", flag = "EVENT_BEAT_ARTICUNO",
    level = 80, vanillaLevel = 50,
  },
  MOLTRES = {
    map = "VICTORY_ROAD_2F", text = "TEXT_VICTORYROAD2F_MOLTRES",
    object = "VICTORYROAD2F_MOLTRES", flag = "EVENT_BEAT_MOLTRES",
    level = 80, vanillaLevel = 50,
  },
  MEWTWO = {
    map = "CERULEAN_CAVE_B1F", text = "TEXT_CERULEANCAVEB1F_MEWTWO",
    object = "CERULEANCAVEB1F_MEWTWO", flag = "EVENT_BEAT_MEWTWO",
    level = 90, vanillaLevel = 70,
  },
}

D.overworldSprites = {
  RAIKOU = "SPRITE_MONSTER",
  ENTEI = "SPRITE_MONSTER",
  SUICUNE = "SPRITE_MONSTER",
  LUGIA = "SPRITE_BIRD",
  HO_OH = "SPRITE_BIRD",
  CELEBI = "SPRITE_FAIRY",
}

D.roamers = {
  RAIKOU = {
    level = 85, sprite = D.overworldSprites.RAIKOU,
    text = "MOD_TRAINER_REMATCH_RAIKOU", name = "TRAINER_REMATCH_RAIKOU",
  },
  ENTEI = {
    level = 85, sprite = D.overworldSprites.ENTEI,
    text = "MOD_TRAINER_REMATCH_ENTEI", name = "TRAINER_REMATCH_ENTEI",
  },
  SUICUNE = {
    level = 85, sprite = D.overworldSprites.SUICUNE,
    text = "MOD_TRAINER_REMATCH_SUICUNE", name = "TRAINER_REMATCH_SUICUNE",
  },
}
D.roamerRoutes = {
  "ROUTE_1", "ROUTE_2", "ROUTE_3", "ROUTE_4", "ROUTE_5", "ROUTE_6",
  "ROUTE_7", "ROUTE_8", "ROUTE_9", "ROUTE_10", "ROUTE_11", "ROUTE_12",
  "ROUTE_13", "ROUTE_14", "ROUTE_15", "ROUTE_16", "ROUTE_17", "ROUTE_18",
  "ROUTE_22", "ROUTE_24", "ROUTE_25",
}

D.spawnedLegends = {
  LUGIA = {
    map = "SEAFOAM_ISLANDS_B4F", text = "MOD_TRAINER_REMATCH_LUGIA",
    name = "TRAINER_REMATCH_LUGIA", level = 95,
    sprite = D.overworldSprites.LUGIA,
    preferred = { { 6, 1 }, { 7, 3 }, { 5, 3 } },
  },
  HO_OH = {
    map = "POKEMON_TOWER_7F", text = "MOD_TRAINER_REMATCH_HO_OH",
    name = "TRAINER_REMATCH_HO_OH", level = 95,
    sprite = D.overworldSprites.HO_OH,
    preferred = { { 10, 3 }, { 9, 4 }, { 11, 4 } },
  },
  CELEBI = {
    map = "VIRIDIAN_FOREST", text = "MOD_TRAINER_REMATCH_CELEBI",
    name = "TRAINER_REMATCH_CELEBI", level = 90,
    sprite = D.overworldSprites.CELEBI,
    preferred = { { 17, 40 }, { 16, 40 }, { 18, 40 } },
  },
}

D.legendOrder = {
  "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO",
  "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH", "CELEBI",
}

return D
