-- Post-RC2 NG+ World Rank tournament data.
-- Runtime authority lives in ngplus_tournament.lua; this file stays static so
-- the eleven formats and the complete EN/DE copy can be reviewed without engine
-- execution.

local function text(en, de) return { en = en, de = de } end

local function format(id, en, de, types, classes, rules)
  rules = rules or {}
  local championCandidates = rules.championCandidates
    or (rules.champion and { rules.champion }) or {}
  return {
    id = id,
    name = text(en, de),
    ruleText = rules.ruleText,
    allowedTypes = types,
    rewardTypes = rules.rewardTypes or types,
    johtoOnly = rules.johtoOnly == true,
    -- Global tournament law: neither side may use or carry battle items.
    noItems = rules.noItems ~= false,
    noMega = rules.noMega == true,
    megaMode = rules.noMega == true and "forbidden" or "authority_only",
    opponentClasses = classes,
    champion = rules.champion,
    championCandidates = championCandidates,
    minimumAuthorizedOpponents = rules.minimumAuthorizedOpponents or 5,
    moveRecipeId = id,
  }
end

local D = {
  version = 1,
  initialRank = 50,
  championRank = 1,
  timing = {
    invitationMin = 1792,
    invitationMax = 2208,
    rotate = 500,
    hint2 = 750,
    rotations = { 500, 1000, 1500 },
    expire = 1750,
    reentryMin = 1000,
    reentryMax = 3000,
  },
}

-- Gen1Recomp keeps the original constant name PSYCHIC_TYPE to avoid a Lua
-- symbol collision. Tournament/reward copy uses the player-facing PSYCHIC
-- vocabulary, so every consumer must cross this one normalization seam.
function D.normalizeType(value)
  if type(value) ~= "string" then return nil end
  value = value:upper()
  if value == "PSYCHIC_TYPE" then return "PSYCHIC" end
  return value
end

D.formats = {
  format("verdant", "VERDANT LEAGUE", "GRÜNE LIGA", { "GRASS" },
    { "OPP_ERIKA", "OPP_BEAUTY", "OPP_LASS", "OPP_JR_TRAINER_F",
      "OPP_COOLTRAINER_F", "OPP_POKEMANIAC" }, {
      ruleText = text("Every team member must have the GRASS type.",
        "Jedes Teammitglied muss den Typ PFLANZE haben."),
      champion = "OPP_ERIKA",
    }),
  format("dynamo", "DYNAMO LEAGUE", "DYNAMO-LIGA", { "ELECTRIC" },
    { "OPP_LT_SURGE", "OPP_ENGINEER", "OPP_ROCKER", "OPP_SCIENTIST",
      "OPP_GAMBLER", "OPP_COOLTRAINER_M" }, {
      ruleText = text("Every team member must have the ELECTRIC type.",
        "Jedes Teammitglied muss den Typ ELEKTRO haben."),
      champion = "OPP_LT_SURGE",
    }),
  format("dragon", "DRAGON CROWN", "DRACHENKRONE", { "DRAGON" },
    { "OPP_LANCE", "OPP_TAMER", "OPP_POKEMANIAC", "OPP_COOLTRAINER_M",
      "OPP_COOLTRAINER_F", "OPP_GENTLEMAN" }, {
      ruleText = text("Every member must have DRAGON. Mega Evolution is forbidden.",
        "Jedes Mitglied braucht DRACHE. Mega-Entwicklung ist verboten."),
      noMega = true, champion = "OPP_LANCE",
    }),
  format("inferno", "INFERNO CUP", "INFERNO-CUP", { "FIRE" },
    { "OPP_BLAINE", "OPP_BURGLAR", "OPP_TAMER", "OPP_SCIENTIST",
      "OPP_COOLTRAINER_M", "OPP_GAMBLER" }, {
      ruleText = text("Every team member must have the FIRE type.",
        "Jedes Teammitglied muss den Typ FEUER haben."),
      champion = "OPP_BLAINE",
    }),
  format("tidal_frost", "TIDAL FROST", "FLUT-FROST", { "WATER", "ICE" },
    { "OPP_MISTY", "OPP_LORELEI", "OPP_FISHER", "OPP_SWIMMER",
      "OPP_SAILOR", "OPP_COOLTRAINER_F" }, {
      ruleText = text("Every member must have WATER or ICE.",
        "Jedes Mitglied braucht WASSER oder EIS."),
      champion = "OPP_LORELEI",
    }),
  format("bedrock", "BEDROCK LEAGUE", "GRUNDGESTEIN-LIGA",
    { "ROCK", "GROUND" },
    { "OPP_BROCK", "OPP_GIOVANNI", "OPP_HIKER", "OPP_POKEMANIAC",
      "OPP_CUE_BALL", "OPP_COOLTRAINER_M" }, {
      ruleText = text("Every member must have ROCK or GROUND.",
        "Jedes Mitglied braucht GESTEIN oder BODEN."),
      champion = "OPP_GIOVANNI",
    }),
  format("mind_shadow", "MIND & SHADOW", "GEIST & SCHATTEN",
    { "PSYCHIC", "GHOST" },
    { "OPP_SABRINA", "OPP_AGATHA", "OPP_PSYCHIC_TR", "OPP_CHANNELER",
      "OPP_JUGGLER", "OPP_SUPER_NERD" }, {
      ruleText = text("Every member must have PSYCHIC or GHOST.",
        "Jedes Mitglied braucht PSYCHO oder GEIST."),
      champion = "OPP_SABRINA",
    }),
  format("valor", "VALOR CUP", "MUT-CUP", { "FIGHTING", "NORMAL" },
    { "OPP_BRUNO", "OPP_BLACKBELT", "OPP_CUE_BALL", "OPP_YOUNGSTER",
      "OPP_GENTLEMAN", "OPP_JR_TRAINER_M" }, {
      ruleText = text("Every member must have FIGHTING or NORMAL.",
        "Jedes Mitglied braucht KAMPF oder NORMAL."),
      champion = "OPP_BRUNO",
    }),
  format("wing_venom", "WING & VENOM", "FLÜGEL & GIFT",
    { "BUG", "POISON", "FLYING" },
    { "OPP_KOGA", "OPP_BUG_CATCHER", "OPP_BIRD_KEEPER", "OPP_BIKER",
      "OPP_JR_TRAINER_F", "OPP_TAMER" }, {
      ruleText = text("Every member must have BUG, POISON or FLYING.",
        "Jedes Mitglied braucht KÄFER, GIFT oder FLUG."),
      champion = "OPP_KOGA",
    }),
  format("gold", "GOLD CHALLENGE", "GOLD-PRÜFUNG", { "DARK", "STEEL" },
    { "KA_JOHTO_SILVER", "KA_JOHTO_KRIS", "KA_JOHTO_GOLD", "OPP_COOLTRAINER_M",
      "OPP_COOLTRAINER_F", "OPP_PROF_OAK" }, {
      rewardTypes = { "DARK", "STEEL" }, johtoOnly = true,
      noItems = true, noMega = true, champion = "KA_JOHTO_GOLD",
      ruleText = text(
        "Use only registered Johto species or Pokémon with DARK or STEEL. No items or Mega Evolution.",
        "Setze nur registrierte Johto-Arten oder Pokémon vom Typ UNLICHT oder STAHL ein. Keine Items, keine Mega-Entwicklung."),
    }),
  format("sinnoh", "SINNOH CUP", "SINNOH-CUP",
    { "NORMAL", "FIGHTING", "FLYING", "POISON", "GROUND", "ROCK", "BUG",
      "GHOST", "STEEL", "FIRE", "WATER", "GRASS", "ELECTRIC", "PSYCHIC",
      "ICE", "DRAGON", "DARK" },
    { "OPP_CYNTHIA_KA", "OPP_ASH_KA", "OPP_COOLTRAINER_F",
      "OPP_COOLTRAINER_M", "OPP_PSYCHIC_TR", "OPP_TAMER",
      "OPP_SCIENTIST", "OPP_GENTLEMAN", "OPP_PROF_OAK" }, {
      ruleText = text(
        "Use one to six registered Gen I-III Pokémon. Mega Evolution is allowed only after full clearance.",
        "Setze ein bis sechs registrierte Pokémon der Gen. I-III ein. Mega-Entwicklung ist nur nach vollständiger Freigabe erlaubt."),
      -- Cynthia and Ash remain exact optional identities. Missing asset/team
      -- authority removes only that exact row; Professor Oak is an authored,
      -- independently named champion candidate rather than a disguised
      -- replacement for either fan-project character.
      champion = "OPP_CYNTHIA_KA",
      championCandidates = {
        "OPP_CYNTHIA_KA", "OPP_ASH_KA", "OPP_PROF_OAK",
      },
    }),
}

D.byId = {}
for _, row in ipairs(D.formats) do D.byId[row.id] = row end

-- Exact people must never inherit a tournament title or a random generic
-- trainer name. Generic classes are intentionally absent: the controller may
-- still pair their localized class label with its sealed personal-name row.
D.trainerDisplayNames = {
  OPP_BROCK = text("BROCK", "ROCKO"),
  OPP_MISTY = text("MISTY", "MISTY"),
  OPP_LT_SURGE = text("LT. SURGE", "MAJOR BOB"),
  OPP_ERIKA = text("ERIKA", "ERIKA"),
  OPP_KOGA = text("KOGA", "KOGA"),
  OPP_SABRINA = text("SABRINA", "SABRINA"),
  OPP_BLAINE = text("BLAINE", "PYRO"),
  OPP_GIOVANNI = text("GIOVANNI", "GIOVANNI"),
  OPP_LORELEI = text("LORELEI", "LORELEI"),
  OPP_BRUNO = text("BRUNO", "BRUNO"),
  OPP_AGATHA = text("AGATHA", "AGATHE"),
  OPP_LANCE = text("LANCE", "SIEGFRIED"),
  OPP_PROF_OAK = text("PROF. OAK", "PROF. EICH"),
  KA_JOHTO_SILVER = text("SILVER", "SILBER"),
  KA_JOHTO_KRIS = text("KRIS", "KRIS"),
  KA_JOHTO_GOLD = text("GOLD", "GOLD"),
  OPP_CYNTHIA_KA = text("CYNTHIA", "CYNTHIA"),
  OPP_ASH_KA = text("ASH", "ASH"),
}

function D.trainerDisplayName(classId, language)
  local row = D.trainerDisplayNames[classId]
  if type(row) ~= "table" then return nil, "trainer-name" end
  return row[language == "de" and "de" or "en"]
end

-- Every selectable class owns explicit player-facing class copy. Named people
-- reuse their exact localized identity; generic classes receive a localized
-- class label that the controller may combine with a sealed personal name.
-- Internal suffixes such as OPP_, _TR, _F, _M and _KA must never reach text.
D.trainerClassLabels = {
  OPP_AGATHA = D.trainerDisplayNames.OPP_AGATHA,
  OPP_ASH_KA = D.trainerDisplayNames.OPP_ASH_KA,
  OPP_BEAUTY = text("BEAUTY", "SCHÖNHEIT"),
  OPP_BIKER = text("BIKER", "BIKER"),
  OPP_BIRD_KEEPER = text("BIRD KEEPER", "VOGELWÄRTER"),
  OPP_BLACKBELT = text("BLACKBELT", "KARATEKA"),
  OPP_BLAINE = D.trainerDisplayNames.OPP_BLAINE,
  OPP_BROCK = D.trainerDisplayNames.OPP_BROCK,
  OPP_BRUNO = D.trainerDisplayNames.OPP_BRUNO,
  OPP_BUG_CATCHER = text("BUG CATCHER", "KÄFERSAMMLER"),
  OPP_BURGLAR = text("BURGLAR", "EINBRECHER"),
  OPP_CHANNELER = text("CHANNELER", "EXORZISTIN"),
  OPP_COOLTRAINER_F = text("ACE TRAINER", "ASS-TRAINERIN"),
  OPP_COOLTRAINER_M = text("ACE TRAINER", "ASS-TRAINER"),
  OPP_CUE_BALL = text("CUE BALL", "ROWDY"),
  OPP_CYNTHIA_KA = D.trainerDisplayNames.OPP_CYNTHIA_KA,
  OPP_ENGINEER = text("ENGINEER", "INGENIEUR"),
  OPP_ERIKA = D.trainerDisplayNames.OPP_ERIKA,
  OPP_FISHER = text("ANGLER", "ANGLER"),
  OPP_GAMBLER = text("GAMBLER", "SPIELER"),
  OPP_GENTLEMAN = text("GENTLEMAN", "GENTLEMAN"),
  OPP_GIOVANNI = D.trainerDisplayNames.OPP_GIOVANNI,
  OPP_HIKER = text("HIKER", "WANDERER"),
  OPP_JR_TRAINER_F = text("JR. TRAINER", "TRAINERIN"),
  OPP_JR_TRAINER_M = text("JR. TRAINER", "TRAINER"),
  OPP_JUGGLER = text("JUGGLER", "JONGLEUR"),
  OPP_KOGA = D.trainerDisplayNames.OPP_KOGA,
  OPP_LANCE = D.trainerDisplayNames.OPP_LANCE,
  OPP_LASS = text("LASS", "GÖRE"),
  OPP_LORELEI = D.trainerDisplayNames.OPP_LORELEI,
  OPP_LT_SURGE = D.trainerDisplayNames.OPP_LT_SURGE,
  OPP_MISTY = D.trainerDisplayNames.OPP_MISTY,
  OPP_POKEMANIAC = text("POKÉMANIAC", "POKÉMANIAC"),
  OPP_PROF_OAK = D.trainerDisplayNames.OPP_PROF_OAK,
  OPP_PSYCHIC_TR = text("PSYCHIC", "PSYCHO"),
  OPP_ROCKER = text("ROCKER", "ROCKER"),
  OPP_SABRINA = D.trainerDisplayNames.OPP_SABRINA,
  OPP_SAILOR = text("SAILOR", "MATROSE"),
  OPP_SCIENTIST = text("SCIENTIST", "FORSCHER"),
  OPP_SUPER_NERD = text("SUPER NERD", "STREBER"),
  OPP_SWIMMER = text("SWIMMER", "SCHWIMMER"),
  OPP_TAMER = text("TAMER", "DOMPTEUR"),
  OPP_YOUNGSTER = text("YOUNGSTER", "KNIRPS"),
  KA_JOHTO_GOLD = D.trainerDisplayNames.KA_JOHTO_GOLD,
  KA_JOHTO_KRIS = D.trainerDisplayNames.KA_JOHTO_KRIS,
  KA_JOHTO_SILVER = D.trainerDisplayNames.KA_JOHTO_SILVER,
}

function D.trainerClassLabel(classId, language)
  local row = D.trainerClassLabels[classId]
  if type(row) ~= "table" then return nil, "trainer-class-label" end
  return row[language == "de" and "de" or "en"]
end

-- Every tournament owns an explicit priority recipe. The roster builder still
-- intersects these candidates with the live move registry and the selected
-- species' level/TM authority; this catalogue can never make a move legal by
-- itself. A registered legal species move fills any remaining slot.
D.moveRecipes = {
  verdant = { id = "verdant", priorities = {
    "RAZOR_LEAF", "MEGA_DRAIN", "SLEEP_POWDER", "STUN_SPORE",
    "LEECH_SEED", "SOLARBEAM", "BODY_SLAM", "TOXIC",
  } },
  dynamo = { id = "dynamo", priorities = {
    "THUNDERBOLT", "THUNDER_WAVE", "THUNDER", "QUICK_ATTACK",
    "SWIFT", "BODY_SLAM", "DOUBLE_TEAM", "REFLECT",
  } },
  dragon = { id = "dragon", priorities = {
    "DRAGON_RAGE", "HYPER_BEAM", "ICE_BEAM", "THUNDERBOLT",
    "FIRE_BLAST", "BODY_SLAM", "AGILITY", "REFLECT",
  } },
  inferno = { id = "inferno", priorities = {
    "FIRE_BLAST", "FLAMETHROWER", "FIRE_SPIN", "BODY_SLAM",
    "DIG", "CONFUSE_RAY", "REFLECT", "TOXIC",
  } },
  tidal_frost = { id = "tidal_frost", priorities = {
    "SURF", "ICE_BEAM", "BLIZZARD", "BUBBLEBEAM",
    "BODY_SLAM", "PSYCHIC_M", "CONFUSE_RAY", "REST",
  } },
  bedrock = { id = "bedrock", priorities = {
    "EARTHQUAKE", "ROCK_SLIDE", "DIG", "BODY_SLAM",
    "FISSURE", "BIDE", "SAND_ATTACK", "TOXIC",
  } },
  mind_shadow = { id = "mind_shadow", priorities = {
    "PSYCHIC_M", "NIGHT_SHADE", "HYPNOSIS", "DREAM_EATER",
    "CONFUSE_RAY", "THUNDERBOLT", "REFLECT", "TOXIC",
  } },
  valor = { id = "valor", priorities = {
    "SUBMISSION", "BODY_SLAM", "DOUBLE_EDGE", "SEISMIC_TOSS",
    "ROCK_SLIDE", "EARTHQUAKE", "REFLECT", "REST",
  } },
  wing_venom = { id = "wing_venom", priorities = {
    "WING_ATTACK", "FLY", "TOXIC", "SLUDGE",
    "LEECH_LIFE", "SLEEP_POWDER", "DOUBLE_TEAM", "SWIFT",
  } },
  gold = { id = "gold", priorities = {
    "CRUNCH", "IRON_TAIL", "METAL_CLAW", "EARTHQUAKE",
    "THUNDERBOLT", "ICE_BEAM", "BODY_SLAM", "REFLECT",
  } },
  sinnoh = { id = "sinnoh", priorities = {
    "EARTHQUAKE", "PSYCHIC_M", "THUNDERBOLT", "ICE_BEAM",
    "FIRE_BLAST", "ROCK_SLIDE", "BODY_SLAM", "REFLECT",
  } },
}
for _, row in ipairs(D.formats) do
  assert(D.moveRecipes[row.moveRecipeId],
    "missing World Rank move recipe " .. tostring(row.moveRecipeId))
end

-- Authored overworld presentation candidates. The authority adapter must
-- still prove that the named sprite is registered in the live edition/mod
-- registry before returning `registered = true`. Gen-I deliberately reuses
-- several field silhouettes; this table records that real choice instead of
-- letting runtime silently collapse every opponent into COOLTRAINER_M.
D.trainerOverworldSprites = {
  OPP_AGATHA = "SPRITE_AGATHA",
  OPP_BEAUTY = "SPRITE_BEAUTY",
  OPP_BIKER = "SPRITE_BIKER",
  OPP_BIRD_KEEPER = "SPRITE_COOLTRAINER_M",
  OPP_BLACKBELT = "SPRITE_BRUNO",
  OPP_BLAINE = "SPRITE_BALDING_GUY",
  OPP_BROCK = "SPRITE_HIKER",
  OPP_BRUNO = "SPRITE_BRUNO",
  OPP_BUG_CATCHER = "SPRITE_YOUNGSTER",
  OPP_BURGLAR = "SPRITE_MIDDLE_AGED_MAN",
  OPP_CHANNELER = "SPRITE_CHANNELER",
  OPP_COOLTRAINER_F = "SPRITE_COOLTRAINER_F",
  OPP_COOLTRAINER_M = "SPRITE_COOLTRAINER_M",
  OPP_CUE_BALL = "SPRITE_BIKER",
  OPP_ENGINEER = "SPRITE_SCIENTIST",
  OPP_ERIKA = "SPRITE_BEAUTY",
  OPP_FISHER = "SPRITE_FISHER",
  OPP_GAMBLER = "SPRITE_GAMBLER",
  OPP_GENTLEMAN = "SPRITE_GENTLEMAN",
  OPP_GIOVANNI = "SPRITE_GIOVANNI",
  OPP_HIKER = "SPRITE_HIKER",
  OPP_JR_TRAINER_F = "SPRITE_BRUNETTE_GIRL",
  OPP_JR_TRAINER_M = "SPRITE_YOUNGSTER",
  OPP_JUGGLER = "SPRITE_GAMEBOY_KID",
  OPP_KOGA = "SPRITE_KOGA",
  OPP_LANCE = "SPRITE_LANCE",
  OPP_LASS = "SPRITE_LITTLE_GIRL",
  OPP_LORELEI = "SPRITE_LORELEI",
  OPP_LT_SURGE = "SPRITE_ROCKER",
  OPP_MISTY = "SPRITE_COOLTRAINER_F",
  OPP_POKEMANIAC = "SPRITE_GAMEBOY_KID",
  OPP_PROF_OAK = "SPRITE_OAK",
  OPP_PSYCHIC_TR = "SPRITE_ROCKER",
  OPP_ROCKER = "SPRITE_ROCKER",
  OPP_SABRINA = "SPRITE_COOLTRAINER_F",
  OPP_SAILOR = "SPRITE_SAILOR",
  OPP_SCIENTIST = "SPRITE_SCIENTIST",
  OPP_SUPER_NERD = "SPRITE_SUPER_NERD",
  OPP_SWIMMER = "SPRITE_SWIMMER",
  OPP_TAMER = "SPRITE_COOLTRAINER_M",
  OPP_YOUNGSTER = "SPRITE_YOUNGSTER",
  KA_JOHTO_SILVER = "SPRITE_KA_JOHTO_SILVER",
  KA_JOHTO_KRIS = "SPRITE_KA_JOHTO_KRIS",
  KA_JOHTO_GOLD = "SPRITE_KA_JOHTO_GOLD",
}

D.globalRule = text(
  "ITEMS ARE FORBIDDEN FOR BOTH SIDES IN EVERY WORLD RANK BATTLE.",
  "ITEMS SIND IN JEDEM WELTRANG-KAMPF FÜR BEIDE SEITEN VERBOTEN.")

local championAwards = {
  verdant = { "VERDANT SOVEREIGN", "GRÜNER SOUVERÄN" },
  dynamo = { "DYNAMO SOVEREIGN", "DYNAMO-SOUVERÄN" },
  dragon = { "DRAGON CROWN", "DRACHENKRONE" },
  inferno = { "INFERNO SOVEREIGN", "INFERNO-SOUVERÄN" },
  tidal_frost = { "TIDAL SOVEREIGN", "FLUT-SOUVERÄN" },
  bedrock = { "BEDROCK SOVEREIGN", "FELS-SOUVERÄN" },
  mind_shadow = { "SHADOW MIND", "SCHATTENGEIST" },
  valor = { "VALOR SOVEREIGN", "MUT-SOUVERÄN" },
  wing_venom = { "VENOM WING", "GIFTFLÜGEL" },
  gold = { "GOLD STANDARD", "GOLDSTANDARD" },
  sinnoh = { "SINNOH SUMMIT", "SINNOH-GIPFEL" },
}
for _, row in ipairs(D.formats) do
  local names = championAwards[row.id]
  row.championTitle = {
    id = "world_rank_" .. row.id,
    name = text(names[1], names[2]),
  }
  row.championCardId = "world_rank_" .. row.id
end

D.rewards = {
  championCash = 10000,
  goldChampionCash = 5000,
  championBallItem = "ULTRA_BALL",
  championBallCount = 10,
  goldShinyJackpotPercent = 20,
  goldShinyJackpotLifetimeMaximum = 1,
  shinyLedger = {
    archiveSchema = 8,
    scope = "verified_legacy_lineage",
    generations = { 1, 2, 3 },
    dexMinimum = 1,
    dexMaximum = 386,
    resetOnlyAfterComplete = true,
  },
}

D.opponentNames = {
  text("BOB", "BOB"), text("MARA", "MARA"),
  text("FINN", "FINN"), text("NORA", "NORA"),
  text("REED", "REED"), text("TESS", "TESS"),
  text("VOLT", "VOLT"), text("CORAL", "CORAL"),
  text("ARI", "ARI"), text("CYRA", "CYRA"),
}

-- Cells are bounded authored candidates. runtime_npc_placement.findWide owns
-- the final geometry/occupancy decision and may reject every one.
D.locations = {
  { id = "pewter", mapId = "PEWTER_CITY",
    label = text("Pewter City museum square", "Marmoria City, Museumsplatz"),
    cells = { { 8, 3 }, { 7, 3 }, { 8, 4 }, { 7, 4 }, { 6, 3 } } },
  { id = "cerulean", mapId = "CERULEAN_CITY",
    label = text("Cerulean City north bank", "Azuria City, Nordufer"),
    cells = { { 14, 12 }, { 15, 12 }, { 13, 12 } } },
  { id = "vermilion", mapId = "VERMILION_CITY",
    label = text("Vermilion City harbor", "Orania City, Hafen"),
    cells = { { 24, 14 }, { 23, 14 }, { 25, 14 } } },
  { id = "celadon", mapId = "CELADON_CITY",
    label = text("Celadon City promenade", "Prismania City, Promenade"),
    -- The Sky Cup host owns 16,12 / 16,11 / 17,12. Its permanent
    -- footprint must never occupy every World Rank candidate as well.
    cells = { { 20, 12 }, { 22, 12 }, { 24, 12 } } },
  { id = "fuchsia", mapId = "FUCHSIA_CITY",
    label = text("Fuchsia City south pond", "Fuchsania City, Südteich"),
    cells = { { 12, 20 }, { 13, 20 }, { 11, 20 } } },
}

local function placeholderSignature(value)
  local names = {}
  for name in tostring(value):gmatch("%%([A-Z][A-Z0-9_]*)%%") do
    names[#names + 1] = name
  end
  table.sort(names)
  return table.concat(names, ",")
end

local function dialogue(context, state, authority, enPages, dePages)
  assert(type(enPages) == "table" and #enPages > 0,
    "World Rank dialogue needs EN pages")
  assert(type(dePages) == "table" and #dePages == #enPages,
    "World Rank dialogue page parity")
  for index = 1, #enPages do
    assert(type(enPages[index]) == "string" and enPages[index] ~= ""
        and type(dePages[index]) == "string" and dePages[index] ~= "",
      "World Rank dialogue page text")
    assert(not enPages[index]:find("\f", 1, true)
        and not dePages[index]:find("\f", 1, true),
      "World Rank dialogue page owns an embedded formfeed")
    assert(placeholderSignature(enPages[index])
        == placeholderSignature(dePages[index]),
      "World Rank dialogue placeholder parity at " .. state .. "/" .. index)
  end
  return {
    context = context,
    state = state,
    authority = authority,
    pages = { en = enPages, de = dePages },
    en = table.concat(enPages, "\f"),
    de = table.concat(dePages, "\f"),
  }
end

D.dialogueOrder = {
  "oakInvite", "registrationOpen", "registrationConfirmed",
  "registrationLocked", "formatCoolingDown", "formatAuthorityUnavailable",
  "opponentIntro", "ruleViolation", "opponentAuthorityMissing",
  "hint1", "hint2", "victory", "defeat", "eliminated", "expired",
  "championIntro", "champion", "rewardSummary", "goldNoJackpot",
  "goldJackpot", "rewardPending", "rewardDelivered",
}

-- Canonical lifecycle decision. `bound` rows already have a consumer in the
-- controller/runtime seam. `bind_required` rows remain authored product copy
-- and must be wired by the named consumer. `fallback_alias` rows are the one
-- canonical generic fallback for a runtime kind; they are not separate events.
-- No lifecycle row is silently dead or removed from the review catalogue.
D.dialogueLifecycleDisposition = {
  oakInvite = { status = "bound", consumer = "pendingPresentation" },
  registrationOpen = { status = "bind_required", consumer = "trainerCard.open" },
  registrationConfirmed = {
    status = "bind_required", consumer = "trainerCard.registrationConfirmed",
  },
  registrationLocked = {
    status = "bind_required", consumer = "trainerCard.registrationLocked",
  },
  formatCoolingDown = {
    status = "bind_required", consumer = "trainerCard.formatCoolingDown",
  },
  formatAuthorityUnavailable = {
    status = "bind_required", consumer = "trainerCard.formatUnavailable",
  },
  opponentIntro = { status = "fallback_alias", consumer = "intro" },
  ruleViolation = { status = "bound", consumer = "entryRejection" },
  opponentAuthorityMissing = {
    status = "bind_required", consumer = "opponentAuthorityMissing",
  },
  hint1 = { status = "bound", consumer = "pendingPresentation" },
  hint2 = { status = "bound", consumer = "pendingPresentation" },
  victory = { status = "fallback_alias", consumer = "playerWin" },
  defeat = { status = "fallback_alias", consumer = "playerLoss" },
  eliminated = { status = "bind_required", consumer = "attemptEliminated" },
  expired = { status = "bound", consumer = "timeoutNotice" },
  championIntro = { status = "bound", consumer = "championIntro" },
  champion = { status = "bind_required", consumer = "championDefeated" },
  rewardSummary = { status = "bind_required", consumer = "reward.summary" },
  goldNoJackpot = { status = "bind_required", consumer = "reward.goldNoJackpot" },
  goldJackpot = { status = "bind_required", consumer = "reward.goldJackpot" },
  rewardPending = { status = "bind_required", consumer = "reward.pending" },
  rewardDelivered = { status = "bind_required", consumer = "reward.delivered" },
}
for _, id in ipairs(D.dialogueOrder) do
  assert(D.dialogueLifecycleDisposition[id],
    "missing World Rank lifecycle disposition " .. tostring(id))
end

D.dialogue = {
  oakInvite = dialogue("oak_call", "invitation", "league_ticket", {
    "OAK: Your NG+ League win\nshook up the World Rank.",
    "Eleven circuits now send\nchallengers across Kanto.",
    "Choose one on your Card.\nNo items. Follow my calls.",
  }, {
    "EICH: Dein NG+-Ligasieg\nveränderte den Weltrang.",
    "Elf Turniere schicken nun\nGegner durch ganz Kanto.",
    "Wähle eins auf der Karte.\nKeine Items. Folge den Rufen.",
  }),
  registrationOpen = dialogue("trainer_card", "registration_open",
    "format_rule", {
      "OAK: %TOURNAMENT% is open.\nIts rule is simple:",
      "%RULE%",
      "Register, and I will name\nyour first meeting place.",
    }, {
      "EICH: %TOURNAMENT% ist offen.\nDie Regel ist einfach:",
      "%RULE%",
      "Melde dich an. Dann nenne\nich den ersten Treffpunkt.",
    }),
  registrationConfirmed = dialogue("oak_call", "registration_confirmed",
    "sealed_assignment", {
      "OAK: You entered\n%TOURNAMENT% at rank %RANK%.",
      "%OPPONENT% is waiting at\n%LOCATION%.",
      "Bring your registered team.\nThe no-item seal is active.",
    }, {
      "EICH: Du startest in\n%TOURNAMENT% auf Rang %RANK%.",
      "%OPPONENT% wartet bei\n%LOCATION%.",
      "Bring dein registriertes Team.\nDas Item-Verbot ist aktiv.",
    }),
  registrationLocked = dialogue("trainer_card", "registration_locked",
    "single_active_attempt", {
      "OAK: Finish %TOURNAMENT%\nbefore choosing another tournament.",
    }, {
      "EICH: Beende %TOURNAMENT%,\nbevor du ein anderes Turnier wählst.",
    }),
  formatCoolingDown = dialogue("trainer_card", "format_cooldown",
    "sealed_return_step", {
      "%TOURNAMENT% is rebuilding\nits field. Return in %STEPS% steps.",
    }, {
      "%TOURNAMENT% ordnet das Feld.\nKehre in %STEPS% Schritten zurück.",
    }),
  formatAuthorityUnavailable = dialogue("trainer_card",
    "format_authority_unavailable", "trainer_asset_prefilter", {
      "OAK: %TOURNAMENT% cannot open.\nIt needs five cleared opponents, including an approved champion.",
      "A required clearance is missing.\nI will not assign a substitute.",
    }, {
      "EICH: %TOURNAMENT% bleibt zu.\nEs braucht fünf freigegebene Gegner, darunter ein bestätigter Champion.",
      "Eine nötige Freigabe fehlt.\nIch setze keinen Ersatz ein.",
    }),
  opponentIntro = dialogue("opponent_talk", "intro_fallback",
    "authorized_trainer", {
      "%OPPONENT%: You stand at rank %RANK%.",
      "Show me how far you can climb.\nWe fight without items.",
    }, {
      "%OPPONENT%: Du stehst auf Rang %RANK%.",
      "Zeig mir, wie weit du kommst.\nWir kämpfen ohne Items.",
    }),
  ruleViolation = dialogue("opponent_talk", "entry_rejected",
    "team_validator_reason", {
      "OAK: Registration stopped.\n%CONDITION%",
      "The circuit rule remains:\n%RULE%",
      "Nothing changed.\nAdjust your team or return later.",
    }, {
      "EICH: Anmeldung gestoppt.\n%CONDITION%",
      "Die Turnierregel bleibt:\n%RULE%",
      "Nichts hat sich geändert.\nPasse dein Team an oder kehre später zurück.",
    }),
  opponentAuthorityMissing = dialogue("opponent_talk",
    "opponent_authority_missing", "trainer_asset_prefilter", {
      "OAK: %OPPONENT% is not cleared\nfor a battle today.",
      "I will keep that exact name\nsealed, not send an impostor.",
    }, {
      "EICH: %OPPONENT% ist heute\nnicht für den Kampf freigegeben.",
      "Der echte Name bleibt gesperrt.\nIch schicke keinen Doppelgänger.",
    }),
  hint1 = dialogue("oak_call", "first_hint", "live_assignment", {
    "OAK: The field shifted.\nYou now stand at rank %RANK%.",
    "%OPPONENT% waits at %LOCATION%.\nYour Card marks the same place.",
  }, {
    "EICH: Das Feld zog weiter.\nDu stehst nun auf Rang %RANK%.",
    "%OPPONENT% wartet bei %LOCATION%.\nDeine Karte zeigt denselben Ort.",
  }),
  hint2 = dialogue("oak_call", "continuing_hint", "live_assignment", {
    "OAK: The field is still moving.\n%OPPONENT% is at %LOCATION% now.",
    "Check your Card for later moves.\nThis attempt will close on its own.",
  }, {
    "EICH: Das Feld zieht noch weiter.\n%OPPONENT% ist jetzt bei %LOCATION%.",
    "Spätere Wechsel stehen auf der Karte.\nDer Versuch endet von selbst.",
  }),
  victory = dialogue("battle_result", "player_win_fallback",
    "resolved_encounter", {
      "%OPPONENT%: You saw the opening.",
      "You move up to rank %RANK%.\nI'll rejoin behind you. See you.",
  }, {
      "%OPPONENT%: Du sahst die Lücke.",
      "Du steigst auf Rang %RANK%.\nIch ordne mich hinter dir ein. Bis dann.",
  }),
  defeat = dialogue("battle_result", "player_loss_fallback",
    "resolved_encounter", {
      "%OPPONENT%: The field answered.",
      "You fall to rank %RANK%.\nI keep my place. See you.",
  }, {
      "%OPPONENT%: Das Feld entschied.",
      "Du fällst auf Rang %RANK% zurück.\nIch halte meinen Platz. Bis dann.",
  }),
  eliminated = dialogue("oak_call", "attempt_eliminated",
    "resolved_encounter", {
      "OAK: %TOURNAMENT% has moved\nbeyond rank %RANK% for this run.",
      "The circuit will rebuild.\nChoose another open story now.",
  }, {
      "EICH: %TOURNAMENT% zog für\ndiesen Lauf über Rang %RANK% hinaus.",
      "Das Turnier baut neu auf.\nWähle nun ein anderes Kapitel.",
  }),
  expired = dialogue("oak_call", "attempt_expired", "sealed_timeout", {
      "OAK: The final call passed.\nThe open field was claimed.",
      "Your last place was rank %RANK%.\nThis circuit will return later.",
  }, {
      "EICH: Der letzte Ruf verstrich.\nDas freie Feld wurde vergeben.",
      "Dein letzter Platz war Rang %RANK%.\nDieses Turnier kehrt später zurück.",
  }),
  championIntro = dialogue("opponent_talk", "champion_intro",
    "authorized_champion", {
      "%CHAMPION%: Every road in\n%TOURNAMENT% ends here.",
      "Rank 1 belongs to the team\nthat wins this battle.",
  }, {
      "%CHAMPION%: Jeder Weg in\n%TOURNAMENT% endet hier.",
      "Rang 1 gehört dem Team,\ndas diesen Kampf gewinnt.",
  }),
  champion = dialogue("battle_result", "champion_defeated",
    "resolved_championship", {
      "%CHAMPION%: Rank 1 is yours.\nYour team brought you here.",
  }, {
      "%CHAMPION%: Rang 1 gehört dir.\nDein Team hat dich hierhergebracht.",
  }),
  rewardSummary = dialogue("oak_call", "champion_reward",
    "durable_reward_receipt", {
      "OAK: The circuit sealed\n%CASH% and %BALL_COUNT% %BALL%.",
      "Your new title and Card\ncome with that same prize.",
    }, {
      "EICH: Das Turnier versiegelte\n%CASH% und %BALL_COUNT% %BALL%.",
      "Dein neuer Titel und die Karte\ngehören zu demselben Preis.",
  }),
  goldNoJackpot = dialogue("oak_call", "gold_without_jackpot",
    "gold_lifetime_ledger", {
      "OAK: GOLD paid its sure prize.\nNo rare seal opened this time.",
      "There is no second draw.\nThe result is in the Legacy Archive.",
    }, {
      "EICH: GOLD zahlte den Festpreis.\nDiesmal brach kein seltenes Siegel.",
      "Es gibt keine zweite Ziehung.\nDas Ergebnis steht im Legacy-Archiv.",
  }),
  goldJackpot = dialogue("oak_call", "gold_jackpot",
    "gold_lifetime_ledger", {
      "OAK: GOLD's single rare seal\nchose %SPECIES% for this lineage.",
      "Once delivered, that jackpot\ncan never open here again.",
  }, {
      "EICH: GOLDs seltenes Siegel\nwählte %SPECIES% für diese Linie.",
      "Nach der Übergabe öffnet sich\ndieser Jackpot nie wieder.",
  }),
  rewardPending = dialogue("oak_call", "reward_storage_full",
    "durable_pending_receipt", {
      "OAK: Your sealed %SPECIES% is safe.\nParty and Boxes are full.",
      "Make one space, then return.\nThe choice cannot change.",
  }, {
      "EICH: Dein %SPECIES%-Siegel ist sicher.\nTeam und Boxen sind voll.",
      "Schaffe einen Platz und kehre zurück.\nDie Auswahl bleibt unverändert.",
  }),
  rewardDelivered = dialogue("oak_call", "reward_delivered",
    "physical_reward_receipt", {
      "OAK: The seal is open.\n%SPECIES% entered your Legacy Archive.",
      "The prize is recorded.\nIt cannot appear again yet.",
    }, {
      "EICH: Das Siegel ist offen.\n%SPECIES% steht nun im Legacy-Archiv.",
      "Der Preis ist vermerkt.\nEr kann vorerst nicht erneut erscheinen.",
  }),
}

D.entryConditionOrder = {
  "size", "member", "item", "species", "type", "move",
  "trainer-authority", "move-authority", "level-authority",
}
D.entryConditions = {
  size = dialogue("entry_validation", "reason_size", "party_shape", {
    "Bring one to six conscious Pokémon.",
  }, {
    "Bring ein bis sechs kampffähige Pokémon.",
  }),
  member = dialogue("entry_validation", "reason_member", "party_shape", {
    "Remove Eggs, empty slots, and fainted members.",
  }, {
    "Entferne Eier, leere Plätze und besiegte Mitglieder.",
  }),
  item = dialogue("entry_validation", "reason_item", "held_item_scan", {
    "Remove every held item from your team.",
  }, {
    "Entferne alle getragenen Items aus deinem Team.",
  }),
  species = dialogue("entry_validation", "reason_species",
    "live_species_registry", {
      "Every member must be a registered Gen I-III species.",
  }, {
      "Jedes Mitglied muss eine registrierte Gen-I-III-Art sein.",
  }),
  type = dialogue("entry_validation", "reason_type", "format_type_rule", {
    "At least one Pokémon has none of this tournament's allowed types.",
  }, {
    "Mindestens ein Pokémon hat keinen der erlaubten Turniertypen.",
  }),
  move = dialogue("entry_validation", "reason_move", "live_move_registry", {
    "At least one move is unavailable in this game setup.",
  }, {
    "Mindestens eine Attacke ist in dieser Spielkonfiguration nicht verfügbar.",
  }),
  ["trainer-authority"] = dialogue("entry_validation",
    "reason_trainer_authority", "trainer_asset_prefilter", {
      "This opponent is not fully available in this game setup.",
  }, {
      "Dieser Gegner ist in dieser Spielkonfiguration nicht vollständig verfügbar.",
  }),
  ["move-authority"] = dialogue("entry_validation",
    "reason_move_authority", "species_move_sources", {
      "No legal move set is available for this opponent.",
  }, {
      "Für diesen Gegner ist kein legales Attackenset verfügbar.",
  }),
  ["level-authority"] = dialogue("entry_validation",
    "reason_level_authority", "sealed_level_plan", {
      "No complete level plan is available for this opponent.",
  }, {
      "Für diesen Gegner ist kein vollständiger Levelplan verfügbar.",
  }),
}

local function renderDialogueRow(row, language, values)
  if type(row) ~= "table" then return nil, "dialogue" end
  language = language == "de" and "de" or "en"
  values = type(values) == "table" and values or {}
  local missing
  local rendered = row[language]:gsub("%%([A-Z][A-Z0-9_]*)%%",
    function(name)
      local value = values[name]
      if value == nil then missing = missing or name; return "%" .. name .. "%" end
      value = tostring(value):gsub("[\r\n\f\v]", " ")
      return value
    end)
  if missing then return nil, "placeholder:" .. missing end
  return rendered
end

function D.renderDialogue(id, language, values)
  return renderDialogueRow(D.dialogue[id], language, values)
end

function D.renderEntryRejection(reason, language, values)
  local condition = D.entryConditions[reason]
  if not condition then return nil, "condition:" .. tostring(reason) end
  language = language == "de" and "de" or "en"
  local conditionText, conditionReason = renderDialogueRow(
    condition, language, {})
  if not conditionText then return nil, conditionReason end
  local replacements = {}
  for key, value in pairs(type(values) == "table" and values or {}) do
    replacements[key] = value
  end
  replacements.CONDITION = conditionText
  return renderDialogueRow(D.dialogue.ruleViolation, language, replacements)
end

-- Persona copy is deliberately class-bound. Runtime names such as ANGLER BOB
-- still receive the Fisher voice, while named leaders and the two optional
-- fan-project guests retain their own identities. Every entry supplies all
-- three interaction states in both languages; no generic Cooltrainer is ever
-- presented as Cynthia or Ash.
local opponentVoiceCopy = {
  OPP_AGATHA = {
    "Heh heh. The old spirits came to watch.",
    "Hehehe. Die alten Geister sehen heute zu.",
    "Even the spirits applaud your courage.",
    "Selbst die Geister zollen deinem Mut Beifall.",
    "The dead heard your doubt before I did.",
    "Die Toten hörten deinen Zweifel vor mir.",
  },
  OPP_ASH_KA = {
    "Every region taught me to meet the next challenge.",
    "Jede Region lehrte mich, die nächste Prüfung anzunehmen.",
    "That battle felt like the start of a new journey.",
    "Dieser Kampf fühlte sich wie der Beginn einer neuen Reise an.",
    "We learn, we train, and we meet again.",
    "Wir lernen, trainieren und treffen uns wieder.",
  },
  OPP_BEAUTY = {
    "Style is timing, not decoration.",
    "Stil ist gutes Timing, keine Dekoration.",
    "That was a stylish finish.",
    "Das war ein stilvoller Abschluss.",
    "A rushed entrance ruins the whole performance.",
    "Ein hektischer Auftritt verdirbt die ganze Vorstellung.",
  },
  OPP_BIKER = {
    "This road belongs to whoever can hold it.",
    "Diese Straße gehört dem, der sie halten kann.",
    "You took the lane clean. Respect.",
    "Du hieltest die Spur sauber. Respekt.",
    "The road shook you loose this time.",
    "Die Straße warf dich diesmal ab.",
  },
  OPP_BIRD_KEEPER = {
    "Read the wind before choosing your course.",
    "Lies den Wind, bevor du deinen Kurs wählst.",
    "You found the current before my flock.",
    "Du fandest die Strömung vor meinem Schwarm.",
    "My flock kept control of the skies.",
    "Mein Schwarm behielt die Lufthoheit.",
  },
  OPP_BLACKBELT = {
    "One breath. One stance. No excuses.",
    "Ein Atemzug. Fester Stand. Keine Ausreden.",
    "Your discipline broke my guard.",
    "Deine Disziplin brach meine Deckung.",
    "Power without balance falls first.",
    "Kraft ohne Gleichgewicht fällt zuerst.",
  },
  OPP_BLAINE = {
    "A cold answer cannot solve my burning quiz.",
    "Eine kalte Antwort löst mein brennendes Rätsel nicht.",
    "Correct! Your team found the hottest answer.",
    "Richtig! Dein Team fand die heißeste Antwort.",
    "Wrong answer. Train before the next question.",
    "Falsche Antwort. Trainiere vor der nächsten Frage.",
  },
  OPP_BROCK = {
    "A firm foundation reveals every weak plan.",
    "Ein festes Fundament offenbart jede Schwäche im Plan.",
    "Your resolve weathered the whole mountain.",
    "Deine Entschlossenheit trotzte dem ganzen Berg.",
    "The first crack decided the climb.",
    "Der erste Riss entschied den Aufstieg.",
  },
  OPP_BRUNO = {
    "Hoo hah! Strength begins with an honest heart.",
    "Hah! Stärke beginnt mit einem ehrlichen Herzen.",
    "Hoo hah! Your training speaks clearly.",
    "Hah! Dein Training spricht deutlich.",
    "Muscle follows spirit. Yours wavered today.",
    "Muskeln folgen dem Geist. Deiner schwankte heute.",
  },
  OPP_BUG_CATCHER = {
    "Small wings can turn a whole battle.",
    "Kleine Flügel können einen ganzen Kampf wenden.",
    "You spotted every hidden pattern.",
    "Du erkanntest jedes verborgene Muster.",
    "My swarm found the gap in your net.",
    "Mein Schwarm fand die Lücke in deinem Netz.",
  },
  OPP_BURGLAR = {
    "Guard every opening. I only need one.",
    "Bewache jede Lücke. Mir genügt eine.",
    "You locked every door I tested.",
    "Du hast jede geprüfte Tür verriegelt.",
    "I slipped through before you saw the key turn.",
    "Ich schlüpfte durch, bevor du den Schlüssel sahst.",
  },
  OPP_CHANNELER = {
    "The tower whispers which choice carries weight.",
    "Der Turm flüstert, welche Wahl Gewicht trägt.",
    "The quiet voices welcome your courage.",
    "Die stillen Stimmen begrüßen deinen Mut.",
    "A restless echo followed your final command.",
    "Ein ruheloses Echo folgte deinem letzten Befehl.",
  },
  OPP_COOLTRAINER_F = {
    "Preparation makes a hard battle look effortless.",
    "Vorbereitung lässt harte Kämpfe mühelos wirken.",
    "Good decisions, clean finish. Well earned.",
    "Gute Entscheidungen, sauberer Abschluss. Verdient.",
    "Talent needs a plan when the field turns.",
    "Talent braucht einen Plan, wenn das Feld kippt.",
  },
  OPP_COOLTRAINER_M = {
    "A prepared team gives every turn an answer.",
    "Ein vorbereitetes Team hat auf jeden Zug eine Antwort.",
    "You kept an answer for every turn.",
    "Du hattest für jeden Zug eine Antwort.",
    "Your last answer arrived one turn too late.",
    "Deine letzte Antwort kam einen Zug zu spät.",
  },
  OPP_CUE_BALL = {
    "Hold your ground when the field hits back.",
    "Bleib stehen, wenn das Feld zurückschlägt.",
    "Tough enough. You never gave me room.",
    "Hart genug. Du gabst mir keinen Raum.",
    "You flinched, and I broke straight through.",
    "Du bist zurückgezuckt, und ich bin einfach durchgebrochen.",
  },
  OPP_CYNTHIA_KA = {
    "A true bond makes every choice carry weight.",
    "Ein echtes Band verleiht jeder Wahl Gewicht.",
    "Your bonds turned every choice into one answer.",
    "Eure Bindung machte aus jeder Wahl eine Antwort.",
    "Knowledge matters only when trust can carry it.",
    "Wissen zählt nur, wenn Vertrauen es tragen kann.",
  },
  OPP_ENGINEER = {
    "Every circuit has a load it cannot hide.",
    "Jeder Stromkreis hat eine Last, die er nicht verbergen kann.",
    "Your timing closed the circuit perfectly.",
    "Dein Timing schloss den Stromkreis perfekt.",
    "One loose connection cost your whole system.",
    "Eine lose Verbindung kostete dein ganzes System.",
  },
  OPP_ERIKA = {
    "My garden tests patience before power.",
    "Mein Garten prüft Geduld vor Stärke.",
    "Your patience bloomed at the right moment.",
    "Deine Geduld blühte im richtigen Moment.",
    "Strong roots still bend when care is rushed.",
    "Auch starke Wurzeln knicken bei hastiger Pflege.",
  },
  OPP_FISHER = {
    "Read the current. The strongest pull comes quietly.",
    "Lies die Strömung. Der stärkste Sog kommt leise.",
    "You waited, then set the hook cleanly.",
    "Du wartetest und setztest den Haken sauber.",
    "You pulled too soon and lost the deep current.",
    "Du zogst zu früh und verlorst die tiefe Strömung.",
  },
  OPP_GAMBLER = {
    "Good odds favor trainers who count every possibility.",
    "Gute Chancen hat, wer jede Möglichkeit mitzählt.",
    "You made the brave play, not the blind one.",
    "Du spieltest mutig, nicht blind.",
    "You bet the whole field on a single turn.",
    "Du setztest das ganze Feld auf einen Zug.",
  },
  OPP_GENTLEMAN = {
    "Courtesy ends where a careless command begins.",
    "Höflichkeit endet, wo ein sorgloser Befehl beginnt.",
    "A composed victory. You have my respect.",
    "Ein gefasster Sieg. Du hast meinen Respekt.",
    "Composure, my friend. The field noticed its loss.",
    "Haltung, mein Freund. Das Feld bemerkte ihr Fehlen.",
  },
  OPP_GIOVANNI = {
    "Control the field, and every choice pays tribute.",
    "Beherrsche das Feld, und jede Wahl zahlt Tribut.",
    "You took control without wasting a command.",
    "Du übernahmst die Kontrolle ohne einen Befehl zu vergeuden.",
    "Power gathers around the trainer who plans ahead.",
    "Macht sammelt sich beim Trainer, der vorausplant.",
  },
  KA_JOHTO_GOLD = {
    "Johto's long road ends where courage begins.",
    "Johtos langer Weg endet, wo Mut beginnt.",
    "You carried Kanto and Johto in the same stride.",
    "Du trugst Kanto und Johto im selben Schritt.",
    "A bright start still needs a steady finish.",
    "Auch ein heller Start braucht ein ruhiges Ende.",
  },
  OPP_HIKER = {
    "The steep path shows what a team can really carry.",
    "Der steile Pfad zeigt, was ein Team wirklich tragen kann.",
    "You climbed without leaving anyone behind.",
    "Du stiegst auf, ohne jemanden zurückzulassen.",
    "The slope punished every hurried step.",
    "Der Hang bestrafte jeden hastigen Schritt.",
  },
  OPP_JR_TRAINER_F = {
    "I mapped this route and every turn on it.",
    "Ich kartierte diesen Weg und jeden Zug darauf.",
    "You found a better route through my plan.",
    "Du fandest einen besseren Weg durch meinen Plan.",
    "Preparation wins before the first command.",
    "Vorbereitung siegt vor dem ersten Befehl.",
  },
  OPP_JR_TRAINER_M = {
    "Camp taught me to use every tool but an item.",
    "Im Camp lernte ich, jedes Mittel außer Items zu nutzen.",
    "You packed exactly the right answers.",
    "Du hattest genau die richtigen Antworten dabei.",
    "Your plan ran out before the trail did.",
    "Dein Plan endete vor dem Pfad.",
  },
  OPP_JUGGLER = {
    "Track every threat, or one will vanish from sight.",
    "Behalte jede Gefahr im Blick, sonst verschwindet eine.",
    "You never dropped the pattern.",
    "Du verlorst das Muster kein einziges Mal.",
    "One missed beat sent the whole pattern falling.",
    "Ein verpasster Takt brachte das ganze Muster zu Fall.",
  },
  OPP_KOGA = {
    "A visible threat is rarely the one that decides.",
    "Eine sichtbare Gefahr entscheidet nur selten.",
    "You read the shadow behind every feint.",
    "Du erkanntest den Schatten hinter jeder Finte.",
    "The first poison was doubt, not venom.",
    "Das erste Gift war Zweifel, nicht Toxin.",
  },
  KA_JOHTO_KRIS = {
    "A careful record turns discovery into strength.",
    "Eine genaue Chronik macht Entdeckungen zu Stärke.",
    "Your team wrote a result worth keeping.",
    "Dein Team schrieb ein Ergebnis, das bleibt.",
    "The notes were right; the final choice was not.",
    "Die Notizen stimmten, die letzte Wahl nicht.",
  },
  OPP_LANCE = {
    "A dragon obeys conviction, never reputation.",
    "Ein Drache folgt Überzeugung, niemals dem Ruf.",
    "Your conviction stood taller than my dragons.",
    "Deine Überzeugung überragte meine Drachen.",
    "A wavering command cannot guide a dragon.",
    "Ein schwankender Befehl führt keinen Drachen.",
  },
  OPP_LASS = {
    "Do not mistake a bright smile for a soft match.",
    "Verwechsle ein strahlendes Lächeln nicht mit einem leichten Kampf.",
    "Fine, that was sharper than it looked.",
    "Gut, das war schärfer, als es aussah.",
    "You judged the cover and missed the story.",
    "Du sahst nur den Umschlag und verpasstest die Geschichte.",
  },
  OPP_LORELEI = {
    "Cold reason keeps every choice perfectly clear.",
    "Kühle Vernunft hält jede Wahl vollkommen klar.",
    "You stayed clear-minded through the deepest cold.",
    "Du bliebst selbst in tiefster Kälte klar.",
    "One clouded choice let the cold close in.",
    "Eine getrübte Wahl ließ die Kälte herein.",
  },
  OPP_LT_SURGE = {
    "A battle needs voltage and a grounded plan.",
    "Ein Kampf braucht Spannung und einen geerdeten Plan.",
    "You took the shock and kept marching, soldier.",
    "Du nahmst den Schlag und marschiertest weiter, Soldat.",
    "No grounding. One surge ended your formation.",
    "Keine Erdung. Ein Stoß beendete deine Formation.",
  },
  OPP_MISTY = {
    "Flow past any plan that tries to hold you.",
    "Umgehe jeden Plan, der dich festhalten will.",
    "You changed course without losing speed.",
    "Du wechseltest den Kurs, ohne Tempo zu verlieren.",
    "You fought the current instead of reading it.",
    "Du bekämpftest die Strömung, statt sie zu lesen.",
  },
  OPP_POKEMANIAC = {
    "I know every strange strength in this team.",
    "Ich kenne jede seltsame Stärke dieses Teams.",
    "You found a detail even I overlooked.",
    "Du fandest ein Detail, das selbst ich übersah.",
    "Enthusiasm is data only after careful study.",
    "Begeisterung wird erst durch Prüfung zu Wissen.",
  },
  OPP_PROF_OAK = {
    "A well-trained team brings the Pokédex to life.",
    "Ein gut trainiertes Team erweckt den Pokédex zum Leben.",
    "Excellent! Your bonds proved the better theory.",
    "Ausgezeichnet! Eure Bindung bestätigte die bessere Theorie.",
    "Research continues. Bring me a stronger conclusion.",
    "Die Forschung geht weiter. Bring mir ein stärkeres Ergebnis.",
  },
  OPP_PSYCHIC_TR = {
    "Possibility is loudest just before a choice.",
    "Möglichkeiten sind kurz vor einer Wahl am lautesten.",
    "You chose the future I could not hold.",
    "Du wähltest die Zukunft, die ich nicht halten konnte.",
    "I saw that ending when your focus broke.",
    "Ich sah dieses Ende, als dein Fokus brach.",
  },
  OPP_ROCKER = {
    "Keep the rhythm when the whole field gets loud.",
    "Halte den Rhythmus, wenn das ganze Feld laut wird.",
    "You owned the final beat.",
    "Der letzte Takt gehörte dir.",
    "You lost the beat, and the battle with it.",
    "Du verlorst den Takt und damit den Kampf.",
  },
  OPP_SABRINA = {
    "Foresight matters only if courage follows it.",
    "Voraussicht zählt nur, wenn Mut ihr folgt.",
    "You changed the future with a fearless choice.",
    "Du hast die Zukunft mit einer furchtlosen Wahl verändert.",
    "You saw the danger and still let fear choose.",
    "Du sahst die Gefahr und ließest trotzdem die Angst entscheiden.",
  },
  OPP_SAILOR = {
    "A steady crew survives the roughest turn.",
    "Eine eingespielte Mannschaft übersteht die härteste Wende.",
    "Your whole crew held the deck.",
    "Deine ganze Mannschaft hielt das Deck.",
    "One unclear order sent the deck rolling.",
    "Ein unklarer Befehl brachte das Deck ins Wanken.",
  },
  OPP_SCIENTIST = {
    "A claim means nothing until the battle repeats it.",
    "Eine Behauptung zählt erst, wenn der Kampf sie bestätigt.",
    "Result confirmed. Your method works.",
    "Ergebnis bestätigt. Deine Methode bewährt sich.",
    "The hypothesis failed at the decisive turn.",
    "Die Hypothese scheiterte im entscheidenden Zug.",
  },
  KA_JOHTO_SILVER = {
    "I stopped chasing strength that stands alone.",
    "Ich jage keiner Stärke mehr nach, die allein steht.",
    "Your team proved why trust is not weakness.",
    "Dein Team bewies, warum Vertrauen keine Schwäche ist.",
    "Wanting victory is not the same as earning it.",
    "Sieg zu wollen heißt nicht, ihn zu verdienen.",
  },
  OPP_SUPER_NERD = {
    "Every odd interaction is part of the solution.",
    "Jede seltsame Wechselwirkung gehört zur Lösung.",
    "You solved the field before I finished explaining it.",
    "Du löstest das Feld, bevor ich mit meiner Erklärung fertig war.",
    "You ignored one variable, and it multiplied.",
    "Du übersahst eine Variable, und sie vervielfachte sich.",
  },
  OPP_SWIMMER = {
    "Commit to the stroke when the water pushes back.",
    "Zieh den Schwimmzug durch, wenn das Wasser drückt.",
    "You touched the wall a breath ahead.",
    "Du schlugst einen Atemzug früher an.",
    "You spent your strength before the final length.",
    "Du verbrauchtest deine Kraft vor der letzten Bahn.",
  },
  OPP_TAMER = {
    "Trust guides power that force can never tame.",
    "Vertrauen lenkt Kraft, die sich mit Zwang nie bändigen lässt.",
    "Your team answered without fear.",
    "Dein Team antwortete ohne Angst.",
    "A loud command cannot replace a trusted one.",
    "Ein lauter Befehl ersetzt keinen, dem dein Team vertraut.",
  },
  OPP_YOUNGSTER = {
    "I trained this team on every road I could reach.",
    "Ich trainierte dieses Team auf jedem erreichbaren Weg.",
    "Whoa! You found a road I never saw.",
    "Wow! Du fandest einen Weg, den ich nie sah.",
    "I am not done. The next road starts now.",
    "Ich bin nicht fertig. Der nächste Weg beginnt jetzt.",
  },
}

D.opponentDialogue = {}
for classId, copy in pairs(opponentVoiceCopy) do
  local authority = "trainer:" .. classId
  D.opponentDialogue[classId] = {
    intro = dialogue("opponent_talk", "intro", authority, {
      "%OPPONENT%: " .. copy[1],
      "You stand at rank %RANK%.\nShow me how far you can climb.",
    }, {
      "%OPPONENT%: " .. copy[2],
      "Du stehst auf Rang %RANK%.\nZeig mir, wie weit du kommst.",
    }),
    playerWin = dialogue("battle_result", "player_win", authority, {
      "%OPPONENT%: " .. copy[3],
      "You move up to rank %RANK%.\nI'll rejoin behind you. See you.",
    }, {
      "%OPPONENT%: " .. copy[4],
      "Du steigst auf Rang %RANK%.\nIch ordne mich hinter dir ein. Bis dann.",
    }),
    playerLoss = dialogue("battle_result", "player_loss", authority, {
      "%OPPONENT%: " .. copy[5],
      "You fall to rank %RANK%.\nI keep my place. See you.",
    }, {
      "%OPPONENT%: " .. copy[6],
      "Du fällst auf Rang %RANK% zurück.\nIch halte meinen Platz. Bis dann.",
    }),
  }
end

function D.renderOpponentDialogue(classId, state, language, values)
  local voice = D.opponentDialogue[classId]
  return renderDialogueRow(voice and voice[state], language, values)
end

-- Review-only layout model. Runtime TextBox code remains authoritative, but the
-- ledger expands every placeholder with the longest current catalogue value
-- (plus explicit 12-character external item/species bounds) and records how
-- many two-line, 18-character Gen-I pages that copy can require.
D.dialogueReviewLayout = {
  lineWidth = 18,
  linesPerPage = 2,
  externalPlaceholderCharacters = { BALL = 12, SPECIES = 12 },
}

local function utf8Length(value)
  value = tostring(value or "")
  local length = 0
  for index = 1, #value do
    local byte = value:byte(index)
    if byte < 128 or byte >= 192 then length = length + 1 end
  end
  return length
end

local function longer(current, candidate)
  candidate = tostring(candidate or "")
  if utf8Length(candidate) > utf8Length(current) then return candidate end
  return current
end

function D.dialogueReviewWorstCaseValues(language)
  language = language == "de" and "de" or "en"
  local tournament, rule, location, condition, personal = "", "", "", "", ""
  for _, row in ipairs(D.formats) do
    tournament = longer(tournament, row.name[language])
    rule = longer(rule, row.ruleText[language])
  end
  for _, row in ipairs(D.locations) do
    location = longer(location, row.label[language])
  end
  for _, row in pairs(D.entryConditions) do
    condition = longer(condition, row[language])
  end
  for _, row in ipairs(D.opponentNames) do
    personal = longer(personal, row[language])
  end
  local opponent = ""
  for classId in pairs(D.opponentDialogue) do
    local exact = D.trainerDisplayNames[classId]
    local label = D.trainerClassLabels[classId]
    local display = exact and exact[language]
      or (label and (label[language] .. " " .. personal)) or ""
    opponent = longer(opponent, display)
  end
  local external = D.dialogueReviewLayout.externalPlaceholderCharacters
  return {
    TOURNAMENT = tournament,
    RULE = rule,
    RANK = tostring(D.initialRank),
    OPPONENT = opponent,
    CHAMPION = opponent,
    LOCATION = location,
    STEPS = tostring(D.timing.reentryMax),
    CONDITION = condition,
    CASH = tostring(math.max(D.rewards.championCash,
      D.rewards.goldChampionCash)),
    BALL_COUNT = tostring(D.rewards.championBallCount),
    BALL = string.rep("W", external.BALL),
    SPECIES = string.rep("W", external.SPECIES),
  }
end

local function expandReviewPage(page, values)
  return (page:gsub("%%([A-Z][A-Z0-9_]*)%%", function(name)
    local value = assert(values[name], "missing review placeholder " .. name)
    return tostring(value):gsub("[\r\n\f\v]", " ")
  end))
end

local function wrappedLineCount(line, width)
  if line == "" then return 1 end
  local count, used, found = 1, 0, false
  for word in line:gmatch("%S+") do
    found = true
    local length = utf8Length(word)
    if used == 0 and length <= width then
      used = length
    elseif used > 0 and used + 1 + length <= width then
      used = used + 1 + length
    else
      if used > 0 then count, used = count + 1, 0 end
      local segments = math.max(1, math.ceil(length / width))
      count = count + segments - 1
      used = length - (segments - 1) * width
    end
  end
  return found and count or 1
end

function D.dialogueReviewMetrics(row, language)
  if type(row) ~= "table" or type(row.pages) ~= "table" then
    return nil, "dialogue"
  end
  language = language == "de" and "de" or "en"
  local values = D.dialogueReviewWorstCaseValues(language)
  local pages, maxLine = 0, 0
  for _, authoredPage in ipairs(row.pages[language]) do
    local expanded = expandReviewPage(authoredPage, values)
    local wrappedLines = 0
    for line in (expanded .. "\n"):gmatch("(.-)\n") do
      maxLine = math.max(maxLine, utf8Length(line))
      wrappedLines = wrappedLines + wrappedLineCount(
        line, D.dialogueReviewLayout.lineWidth)
    end
    pages = pages + math.max(1, math.ceil(
      wrappedLines / D.dialogueReviewLayout.linesPerPage))
  end
  return { pages = pages, maxExpandedLine = maxLine }
end

function D.dialogueReviewRows()
  local rows = {}
  local function add(id, row)
    local enMetrics = assert(D.dialogueReviewMetrics(row, "en"))
    local deMetrics = assert(D.dialogueReviewMetrics(row, "de"))
    local decision = D.dialogueLifecycleDisposition[id]
    rows[#rows + 1] = {
      id = id,
      context = row.context,
      state = row.state,
      authority = row.authority,
      en = row.en,
      de = row.de,
      pageCount = #row.pages.en,
      placeholders = placeholderSignature(row.en),
      worstCasePagesEn = enMetrics.pages,
      worstCasePagesDe = deMetrics.pages,
      maxExpandedLineEn = enMetrics.maxExpandedLine,
      maxExpandedLineDe = deMetrics.maxExpandedLine,
      runtimeStatus = decision and decision.status or "catalogue",
      runtimeConsumer = decision and decision.consumer or row.authority,
    }
  end
  for _, id in ipairs(D.dialogueOrder) do add(id, D.dialogue[id]) end
  for _, reason in ipairs(D.entryConditionOrder) do
    add("entryCondition." .. reason, D.entryConditions[reason])
  end
  local identities = {}
  for classId in pairs(D.trainerDisplayNames) do
    identities[#identities + 1] = classId
  end
  table.sort(identities)
  for _, classId in ipairs(identities) do
    local names = D.trainerDisplayNames[classId]
    add("trainerName." .. classId,
      dialogue("trainer_identity", "display_name", "trainer:" .. classId,
        { names.en }, { names.de }))
  end
  local classes = {}
  for classId in pairs(D.opponentDialogue) do classes[#classes + 1] = classId end
  table.sort(classes)
  for _, classId in ipairs(classes) do
    local voice = D.opponentDialogue[classId]
    for _, state in ipairs({ "intro", "playerWin", "playerLoss" }) do
      add(classId .. "." .. state, voice[state])
    end
  end
  return rows
end

-- Starter prizes remain unavailable until the live save proves discovery.
D.starterFamilies = {
  { "BULBASAUR", "IVYSAUR", "VENUSAUR" },
  { "CHARMANDER", "CHARMELEON", "CHARIZARD" },
  { "SQUIRTLE", "WARTORTLE", "BLASTOISE" },
  { "CHIKORITA", "BAYLEEF", "MEGANIUM" },
  { "CYNDAQUIL", "QUILAVA", "TYPHLOSION" },
  { "TOTODILE", "CROCONAW", "FERALIGATR" },
  { "TREECKO", "GROVYLE", "SCEPTILE" },
  { "TORCHIC", "COMBUSKEN", "BLAZIKEN" },
  { "MUDKIP", "MARSHTOMP", "SWAMPERT" },
}

return D
