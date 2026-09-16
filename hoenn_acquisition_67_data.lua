-- Kanto Ascendant 6.7: one explicit acquisition owner for every Hoenn root.
--
-- Ordinary families are introduced as spoiler-safe field traces and then use
-- a real random encounter on the authored Kanto habitat.  The three starter
-- roots have distinct early routes and require their matching durable Legacy
-- New Game+ path.  Fossil/research specimens, roamers and static legends stay
-- separate so none can leak into either ordinary random pool.

local function trace(id, members, map, terrain, level, en, de)
  return {
    id = id,
    members = members,
    acquisition = "trace",
    habitat = {
      map = map, terrain = terrain, level = level,
      en = en, de = de,
    },
  }
end

local A = {
  version = 1,
  traceFamilies = {
    trace("POOCHYENA", {"POOCHYENA","MIGHTYENA"},
      "ROUTE_1", "grass", 4, "ROUTE 1", "ROUTE 1"),
    trace("ZIGZAGOON", {"ZIGZAGOON","LINOONE"},
      "ROUTE_1", "grass", 4, "ROUTE 1", "ROUTE 1"),
    trace("TAILLOW", {"TAILLOW","SWELLOW"},
      "ROUTE_3", "grass", 10, "ROUTE 3", "ROUTE 3"),
    trace("SKITTY", {"SKITTY","DELCATTY"},
      "ROUTE_5", "grass", 16, "ROUTE 5", "ROUTE 5"),
    trace("WYNAUT", {"WYNAUT"},
      "ROUTE_5", "grass", 16, "ROUTE 5", "ROUTE 5"),
    trace("AZURILL", {"AZURILL"},
      "ROUTE_6", "grass", 16, "ROUTE 6", "ROUTE 6"),
    trace("SPOINK", {"SPOINK","GRUMPIG"},
      "ROUTE_10", "grass", 24, "ROUTE 10", "ROUTE 10"),
    trace("LOTAD", {"LOTAD","LOMBRE","LUDICOLO"},
      "ROUTE_12", "grass", 24, "ROUTE 12", "ROUTE 12"),
    trace("SURSKIT", {"SURSKIT","MASQUERAIN"},
      "ROUTE_12", "grass", 24, "ROUTE 12", "ROUTE 12"),
    trace("TROPIUS", {"TROPIUS"},
      "ROUTE_14", "grass", 27, "ROUTE 14", "ROUTE 14"),
    trace("ROSELIA", {"ROSELIA"},
      "ROUTE_15", "grass", 27, "ROUTE 15", "ROUTE 15"),
    trace("SEVIPER", {"SEVIPER"},
      "ROUTE_15", "grass", 27, "ROUTE 15", "ROUTE 15"),
    trace("ZANGOOSE", {"ZANGOOSE"},
      "ROUTE_15", "grass", 27, "ROUTE 15", "ROUTE 15"),
    trace("SPINDA", {"SPINDA"},
      "ROUTE_16", "grass", 25, "ROUTE 16", "ROUTE 16"),
    trace("CACNEA", {"CACNEA","CACTURNE"},
      "ROUTE_17", "grass", 28, "ROUTE 17", "ROUTE 17"),
    trace("WINGULL", {"WINGULL","PELIPPER"},
      "ROUTE_21", "grass", 28, "ROUTE 21", "ROUTE 21"),
    trace("ABSOL", {"ABSOL"},
      "ROUTE_22", "grass", 28, "ROUTE 22", "ROUTE 22"),
    trace("RALTS", {"RALTS","KIRLIA","GARDEVOIR"},
      "ROUTE_24", "grass", 16, "ROUTE 24", "ROUTE 24"),
    trace("ILLUMISE", {"ILLUMISE"},
      "ROUTE_24", "grass", 16, "ROUTE 24", "ROUTE 24"),
    trace("VOLBEAT", {"VOLBEAT"},
      "ROUTE_24", "grass", 16, "ROUTE 24", "ROUTE 24"),
    trace("SWABLU", {"SWABLU","ALTARIA"},
      "ROUTE_25", "grass", 17, "ROUTE 25", "ROUTE 25"),
    trace("CASTFORM", {"CASTFORM"},
      "ROUTE_8", "grass", 22, "ROUTE 8", "ROUTE 8"),

    trace("WURMPLE", {"WURMPLE","SILCOON","BEAUTIFLY","CASCOON","DUSTOX"},
      "VIRIDIAN_FOREST", "indoor", 5,
      "VIRIDIAN FOREST", "VERTANIA-WALD"),
    trace("SEEDOT", {"SEEDOT","NUZLEAF","SHIFTRY"},
      "VIRIDIAN_FOREST", "indoor", 5,
      "VIRIDIAN FOREST", "VERTANIA-WALD"),
    trace("SHROOMISH", {"SHROOMISH","BRELOOM"},
      "VIRIDIAN_FOREST", "indoor", 5,
      "VIRIDIAN FOREST", "VERTANIA-WALD"),
    trace("SLAKOTH", {"SLAKOTH","VIGOROTH","SLAKING"},
      "VIRIDIAN_FOREST", "indoor", 5,
      "VIRIDIAN FOREST", "VERTANIA-WALD"),
    trace("KECLEON", {"KECLEON"},
      "VIRIDIAN_FOREST", "indoor", 5,
      "VIRIDIAN FOREST", "VERTANIA-WALD"),

    trace("BALTOY", {"BALTOY","CLAYDOL"},
      "MT_MOON_B2F", "indoor", 12, "MT. MOON B2F", "MONDBERG UG2"),
    trace("LUNATONE", {"LUNATONE"},
      "MT_MOON_B2F", "indoor", 12, "MT. MOON B2F", "MONDBERG UG2"),
    trace("SOLROCK", {"SOLROCK"},
      "MT_MOON_B2F", "indoor", 12, "MT. MOON B2F", "MONDBERG UG2"),
    trace("ANORITH", {"ANORITH","ARMALDO"},
      "MT_MOON_B2F", "indoor", 12, "MT. MOON B2F", "MONDBERG UG2"),
    trace("NINCADA", {"NINCADA","NINJASK"},
      "DIGLETTS_CAVE", "indoor", 20,
      "DIGLETT'S CAVE", "DIGDA-HÖHLE"),
    trace("TRAPINCH", {"TRAPINCH","VIBRAVA","FLYGON"},
      "DIGLETTS_CAVE", "indoor", 20,
      "DIGLETT'S CAVE", "DIGDA-HÖHLE"),
    trace("NOSEPASS", {"NOSEPASS"},
      "ROCK_TUNNEL_B1F", "indoor", 24,
      "ROCK TUNNEL B1F", "FELSTUNNEL UG1"),
    trace("WHISMUR", {"WHISMUR","LOUDRED","EXPLOUD"},
      "ROCK_TUNNEL_1F", "indoor", 24,
      "ROCK TUNNEL 1F", "FELSTUNNEL EG"),

    trace("ELECTRIKE", {"ELECTRIKE","MANECTRIC"},
      "POWER_PLANT", "indoor", 32, "POWER PLANT", "KRAFTWERK"),
    trace("PLUSLE", {"PLUSLE"},
      "POWER_PLANT", "indoor", 32, "POWER PLANT", "KRAFTWERK"),
    trace("MINUN", {"MINUN"},
      "POWER_PLANT", "indoor", 32, "POWER PLANT", "KRAFTWERK"),
    trace("BELDUM", {"BELDUM","METANG","METAGROSS"},
      "POWER_PLANT", "indoor", 32, "POWER PLANT", "KRAFTWERK"),

    trace("NUMEL", {"NUMEL","CAMERUPT"},
      "POKEMON_MANSION_B1F", "indoor", 35,
      "POKEMON MANSION B1F", "POKÉMON-HAUS UG1"),
    trace("TORKOAL", {"TORKOAL"},
      "POKEMON_MANSION_B1F", "indoor", 35,
      "POKEMON MANSION B1F", "POKÉMON-HAUS UG1"),
    trace("GULPIN", {"GULPIN","SWALOT"},
      "POKEMON_MANSION_B1F", "indoor", 35,
      "POKEMON MANSION B1F", "POKÉMON-HAUS UG1"),

    trace("CHIMECHO", {"CHIMECHO"},
      "POKEMON_TOWER_7F", "indoor", 28,
      "POKEMON TOWER 7F", "POKÉMON-TURM 7F"),
    trace("DUSKULL", {"DUSKULL","DUSCLOPS"},
      "POKEMON_TOWER_7F", "indoor", 28,
      "POKEMON TOWER 7F", "POKÉMON-TURM 7F"),
    trace("SHUPPET", {"SHUPPET","BANETTE"},
      "POKEMON_TOWER_7F", "indoor", 28,
      "POKEMON TOWER 7F", "POKÉMON-TURM 7F"),

    trace("BARBOACH", {"BARBOACH","WHISCASH"},
      "SEAFOAM_ISLANDS_B2F", "indoor", 30,
      "SEAFOAM ISLANDS B2F", "SEESCHAUMINSELN UG2"),
    trace("CORPHISH", {"CORPHISH","CRAWDAUNT"},
      "SEAFOAM_ISLANDS_B2F", "indoor", 30,
      "SEAFOAM ISLANDS B2F", "SEESCHAUMINSELN UG2"),
    trace("FEEBAS", {"FEEBAS","MILOTIC"},
      "SEAFOAM_ISLANDS_B2F", "indoor", 30,
      "SEAFOAM ISLANDS B2F", "SEESCHAUMINSELN UG2"),
    trace("LUVDISC", {"LUVDISC"},
      "SEAFOAM_ISLANDS_B2F", "indoor", 30,
      "SEAFOAM ISLANDS B2F", "SEESCHAUMINSELN UG2"),
    trace("SPHEAL", {"SPHEAL","SEALEO","WALREIN"},
      "SEAFOAM_ISLANDS_B2F", "indoor", 30,
      "SEAFOAM ISLANDS B2F", "SEESCHAUMINSELN UG2"),
    trace("WAILMER", {"WAILMER","WAILORD"},
      "SEAFOAM_ISLANDS_B2F", "indoor", 30,
      "SEAFOAM ISLANDS B2F", "SEESCHAUMINSELN UG2"),
    trace("CARVANHA", {"CARVANHA","SHARPEDO"},
      "SEAFOAM_ISLANDS_B4F", "indoor", 34,
      "SEAFOAM ISLANDS B4F", "SEESCHAUMINSELN UG4"),
    trace("CLAMPERL", {"CLAMPERL","HUNTAIL","GOREBYSS"},
      "SEAFOAM_ISLANDS_B4F", "indoor", 34,
      "SEAFOAM ISLANDS B4F", "SEESCHAUMINSELN UG4"),
    trace("RELICANTH", {"RELICANTH"},
      "SEAFOAM_ISLANDS_B4F", "indoor", 34,
      "SEAFOAM ISLANDS B4F", "SEESCHAUMINSELN UG4"),
    trace("LILEEP", {"LILEEP","CRADILY"},
      "SEAFOAM_ISLANDS_B4F", "indoor", 34,
      "SEAFOAM ISLANDS B4F", "SEESCHAUMINSELN UG4"),
    trace("SNORUNT", {"SNORUNT","GLALIE"},
      "SEAFOAM_ISLANDS_B4F", "indoor", 34,
      "SEAFOAM ISLANDS B4F", "SEESCHAUMINSELN UG4"),

    trace("ARON", {"ARON","LAIRON","AGGRON"},
      "VICTORY_ROAD_1F", "indoor", 40,
      "VICTORY ROAD 1F", "SIEGESSTRASSE 1F"),
    trace("MAKUHITA", {"MAKUHITA","HARIYAMA"},
      "VICTORY_ROAD_1F", "indoor", 40,
      "VICTORY ROAD 1F", "SIEGESSTRASSE 1F"),
    trace("MEDITITE", {"MEDITITE","MEDICHAM"},
      "VICTORY_ROAD_2F", "indoor", 42,
      "VICTORY ROAD 2F", "SIEGESSTRASSE 2F"),
    trace("BAGON", {"BAGON","SHELGON","SALAMENCE"},
      "VICTORY_ROAD_3F", "indoor", 45,
      "VICTORY ROAD 3F", "SIEGESSTRASSE 3F"),

    trace("MAWILE", {"MAWILE"},
      "CERULEAN_CAVE_1F", "indoor", 50,
      "CERULEAN CAVE 1F", "AZURIA-HÖHLE 1F"),
    trace("SABLEYE", {"SABLEYE"},
      "CERULEAN_CAVE_1F", "indoor", 50,
      "CERULEAN CAVE 1F", "AZURIA-HÖHLE 1F"),
  },

  -- Separate 0.5% pools.  These routes are deliberately different from the
  -- twelve later-generation starter habitats and from the old prototype
  -- Forest/Mansion/Seafoam placements.  Availability comes only from the
  -- corresponding durable Red/Green/Blue Legacy path.
  starterFamilies = {
    trace("TREECKO", {"TREECKO","GROVYLE","SCEPTILE"},
      "ROUTE_2", "grass", 5, "ROUTE 2", "ROUTE 2"),
    trace("TORCHIC", {"TORCHIC","COMBUSKEN","BLAZIKEN"},
      "ROUTE_3", "grass", 8, "ROUTE 3", "ROUTE 3"),
    trace("MUDKIP", {"MUDKIP","MARSHTOMP","SWAMPERT"},
      "ROUTE_4", "grass", 10, "ROUTE 4", "ROUTE 4"),
  },

  -- Every non-Legendary/non-Mythical Hoenn lineage is a real wild discovery.
  -- Research gifts must not bypass the three-character habitat contract.
  researchRewards = {},

  existingSpecials = {
    { id="LATIAS", owner="hoenn_roamers" },
    { id="LATIOS", owner="hoenn_roamers" },
    { id="KYOGRE", owner="hidden_evolution_legend_rooms" },
    { id="GROUDON", owner="hidden_evolution_legend_rooms" },
    { id="RAYQUAZA", owner="hidden_evolution_legend_rooms" },
    { id="JIRACHI", owner="hidden_evolution_legend_rooms" },
  },

  sanctumLegends = {
    { id="REGIROCK", owner="hoenn_research_sanctums",
      map="KA_HOENN_DESERT_RUINS" },
    { id="REGICE", owner="hoenn_research_sanctums",
      map="KA_HOENN_ISLAND_CAVE" },
    { id="REGISTEEL", owner="hoenn_research_sanctums",
      map="KA_HOENN_ANCIENT_TOMB" },
    { id="DEOXYS", owner="hoenn_research_sanctums",
      map="KA_HOENN_BIRTH_ISLAND" },
  },

  evolutionOnly = {
    { id="SHEDINJA", from="NINCADA", owner="hoenn_species_67.awardShedinja" },
  },
}

-- Ordinary Hoenn families are a fixed three-character contract.  Keep the
-- assignment explicit: inserting or reordering a habitat must never move an
-- already released family into another Legacy lineage pack.
A.characterPacks = {
  RED = {
    "POOCHYENA", "SKITTY", "SPOINK", "TROPIUS", "ZANGOOSE",
    "WINGULL", "ILLUMISE", "WURMPLE", "SLAKOTH", "BALTOY",
    "TRAPINCH", "ELECTRIKE", "NUMEL", "CHIMECHO", "BARBOACH",
    "LUVDISC", "CARVANHA", "SNORUNT", "MEDITITE", "SABLEYE",
    "CASTFORM",
  },
  GREEN = {
    "ZIGZAGOON", "WYNAUT", "LOTAD", "ROSELIA", "SPINDA",
    "ABSOL", "VOLBEAT", "SEEDOT", "KECLEON", "LUNATONE",
    "NOSEPASS", "PLUSLE", "TORKOAL", "DUSKULL", "CORPHISH",
    "SPHEAL", "CLAMPERL", "ARON", "BAGON", "LILEEP", "ANORITH",
  },
  BLUE = {
    "TAILLOW", "AZURILL", "SURSKIT", "SEVIPER", "CACNEA",
    "RALTS", "SWABLU", "SHROOMISH", "SOLROCK", "NINCADA",
    "WHISMUR", "MINUN", "GULPIN", "SHUPPET", "FEEBAS",
    "WAILMER", "RELICANTH", "MAKUHITA", "MAWILE", "BELDUM",
  },
}
A.familyCharacter = {}
for character, families in pairs(A.characterPacks) do
  for _, family in ipairs(families) do A.familyCharacter[family] = character end
end

-- Direct local districts, not a transitive world graph. Exhausting a district
-- must never turn an early-game clue into a trip across Kanto.
A.traceDistricts = {
  {"PALLET_TOWN", "ROUTE_1", "VIRIDIAN_CITY", "ROUTE_2", "ROUTE_22"},
  {"VIRIDIAN_FOREST", "ROUTE_2", "PEWTER_CITY", "ROUTE_3"},
  {"ROUTE_3", "ROUTE_4", "MT_MOON_1F", "MT_MOON_B1F", "MT_MOON_B2F"},
  {"CERULEAN_CITY", "ROUTE_4", "ROUTE_5", "ROUTE_9", "ROUTE_24", "ROUTE_25"},
  {"SAFFRON_CITY", "ROUTE_5", "ROUTE_6", "ROUTE_7", "ROUTE_8"},
  {"VERMILION_CITY", "ROUTE_6", "ROUTE_11", "DIGLETTS_CAVE"},
  {"ROUTE_9", "ROUTE_10", "ROCK_TUNNEL_1F", "ROCK_TUNNEL_B1F", "POWER_PLANT"},
  {"LAVENDER_TOWN", "ROUTE_8", "ROUTE_10", "ROUTE_12",
    "POKEMON_TOWER_3F", "POKEMON_TOWER_4F", "POKEMON_TOWER_5F", "POKEMON_TOWER_6F", "POKEMON_TOWER_7F"},
  {"CELADON_CITY", "ROUTE_7", "ROUTE_16", "ROUTE_17"},
  {"ROUTE_12", "ROUTE_13", "ROUTE_14", "ROUTE_15"},
  {"FUCHSIA_CITY", "ROUTE_15", "ROUTE_18", "ROUTE_19",
    "SAFARI_ZONE_CENTER", "SAFARI_ZONE_EAST", "SAFARI_ZONE_WEST", "SAFARI_ZONE_NORTH"},
  {"ROUTE_17", "ROUTE_18"},
  {"ROUTE_19", "ROUTE_20", "SEAFOAM_ISLANDS_1F", "SEAFOAM_ISLANDS_B1F",
    "SEAFOAM_ISLANDS_B2F", "SEAFOAM_ISLANDS_B3F", "SEAFOAM_ISLANDS_B4F"},
  {"CINNABAR_ISLAND", "ROUTE_20", "ROUTE_21", "POKEMON_MANSION_1F",
    "POKEMON_MANSION_2F", "POKEMON_MANSION_3F", "POKEMON_MANSION_B1F"},
  {"ROUTE_23", "INDIGO_PLATEAU", "VICTORY_ROAD_1F", "VICTORY_ROAD_2F", "VICTORY_ROAD_3F"},
  {"CERULEAN_CAVE_1F", "CERULEAN_CAVE_2F", "CERULEAN_CAVE_B1F"},
}

return A
