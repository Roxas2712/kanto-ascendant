-- Historical Generation-I distribution profiles and the original Kanto
-- Heritage Cup brackets authored for Kanto Ascendant.  The distribution
-- builds are factual data; all tournament teams and dialogue are original.

local function text(en, de)
  return { en = en, de = de }
end

local function mon(species, level, moves)
  return { species = species, level = level, moves = moves }
end

local E = {}

E.badges = {
  "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
  "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
}

E.profiles = {
  {
    id = "university_magikarp",
    species = "MAGIKARP",
    name = text("UNIVERSITY MAGIKARP", "UNIVERSITÄTS-KARPADOR"),
    short = text("MAGIKARP", "KARPADOR"),
    source = text("University Magikarp distribution",
      "Universitäts-Karpador-Verteilung"),
    level = 15,
    moves = { "SPLASH", "DRAGON_RAGE" },
    badges = 2,
    terrain = "water",
    habitat = "water",
  },
  {
    id = "stamp_fearow",
    species = "FEAROW",
    name = text("POKéMON STAMP FEAROW", "POKéMON-STAMP-IBITAK"),
    short = text("FEAROW", "IBITAK"),
    source = text("Pokémon Stamp Fearow distribution",
      "Pokémon-Stamp-Ibitak-Verteilung"),
    level = 25,
    moves = { "GROWL", "LEER", "FURY_ATTACK", "PAY_DAY" },
    badges = 2,
    terrain = "grass",
    habitat = "route",
  },
  {
    id = "flying_pikachu",
    species = "PIKACHU",
    name = text("FLYING PIKACHU", "FLIEGENDES PIKACHU"),
    short = text("FLY PIKA", "FLUG-PIKA"),
    source = text("Japanese Flying Pikachu distribution",
      "Japanische Flug-Pikachu-Verteilung"),
    level = 5,
    moves = { "THUNDERSHOCK", "GROWL", "FLY" },
    badges = 3,
    requiredBadge = "THUNDERBADGE",
    terrain = "grass",
    habitat = "electric",
  },
  {
    id = "stamp_rapidash",
    species = "RAPIDASH",
    name = text("POKéMON STAMP RAPIDASH", "POKéMON-STAMP-GALLOPA"),
    short = text("RAPIDASH", "GALLOPA"),
    source = text("Pokémon Stamp Rapidash distribution",
      "Pokémon-Stamp-Gallopa-Verteilung"),
    level = 40,
    moves = { "EMBER", "FIRE_SPIN", "STOMP", "PAY_DAY" },
    badges = 4,
    terrain = "grass",
    habitat = "fire",
  },
  {
    id = "surfing_pikachu",
    species = "PIKACHU",
    name = text("SURFING PIKACHU", "SURFENDES PIKACHU"),
    short = text("SURF PIKA", "SURF-PIKA"),
    source = text("Japanese Surfing Pikachu distribution",
      "Japanische Surf-Pikachu-Verteilung"),
    level = 5,
    moves = { "THUNDERSHOCK", "GROWL", "SURF" },
    badges = 5,
    requiredBadge = "SOULBADGE",
    terrain = "grass",
    habitat = "electric",
  },
  {
    id = "distribution_mew",
    species = "MEW",
    name = text("DISTRIBUTION MEW", "EVENT-MEW"),
    short = text("EVENT MEW", "EVENT-MEW"),
    source = text("Nintendo Space World '99 Mew distribution",
      "Nintendo-Space-World-'99-Mew-Verteilung"),
    level = 5,
    moves = { "POUND" },
    badges = 8,
    terrain = "grass",
    habitat = "mew",
    dvs = { attack = 10, defense = 1, speed = 12, special = 5, hp = 5 },
  },
}

E.cups = {
  university_magikarp = {
    map = "CERULEAN_CITY",
    name = "KANTO_HERITAGE_UNIVERSITY_HOST",
    textId = "MOD_KANTO_HERITAGE_UNIVERSITY",
    sprite = "SPRITE_COOLTRAINER_F",
    preferred = { { 25, 17 }, { 24, 17 }, { 26, 17 } },
    title = text("UNIVERSITY CUP", "UNIVERSITÄTS-CUP"),
    intro = text(
      "Three young researchers\nare testing unusual\nWater teams.\fWin their bracket and\nthe historic prize is\nyours.",
      "Drei junge Forscher\nprüfen ungewöhnliche\nWasserteams.\fGewinne ihr Turnier\nund der historische\nPreis gehört dir."),
    opponents = {
      {
        class = "OPP_SWIMMER", name = text("RESEARCHER FINN", "FORSCHER FINN"),
        team = {
          mon("POLIWAG", 18), mon("HORSEA", 18), mon("SHELLDER", 19),
        },
      },
      {
        class = "OPP_FISHER", name = text("SCHOLAR REED", "GELEHRTER REED"),
        team = {
          mon("GOLDEEN", 20), mon("PSYDUCK", 20), mon("TENTACOOL", 21),
        },
      },
      {
        class = "OPP_JR_TRAINER_F", name = text("DEAN MARINA", "DEKANIN MARINA"),
        team = {
          mon("STARYU", 21), mon("POLIWHIRL", 22), mon("WARTORTLE", 23),
        },
      },
    },
  },
  stamp_fearow = {
    map = "CELADON_CITY",
    name = "KANTO_HERITAGE_SKY_HOST",
    textId = "MOD_KANTO_HERITAGE_SKY",
    sprite = "SPRITE_COOLTRAINER_F",
    preferred = { { 29, 20 }, { 28, 20 }, { 30, 20 } },
    title = text("STAMP SKY CUP", "STAMP-HIMMELS-CUP"),
    intro = text(
      "The Stamp Society has\nopened a three-round\nFlying bracket.\fIts first historic\nprize waits at the top.",
      "Der Stamp-Verein hat\nein dreirundiges\nFlugturnier eröffnet.\fSein erster historischer\nPreis wartet oben."),
    opponents = {
      {
        class = "OPP_BIRD_KEEPER", name = text("KEEPER WREN", "WÄRTER WREN"),
        team = {
          mon("SPEAROW", 24), mon("PIDGEOTTO", 25), mon("FARFETCHD", 25),
        },
      },
      {
        class = "OPP_JR_TRAINER_M", name = text("GLIDER JAY", "GLEITER JAY"),
        team = {
          mon("DODUO", 26), mon("BUTTERFREE", 26), mon("GOLBAT", 27),
        },
      },
      {
        class = "OPP_BIRD_KEEPER", name = text("CAPTAIN SKYE", "KAPITÄN SKYE"),
        team = {
          mon("FEAROW", 28), mon("SCYTHER", 28), mon("PIDGEOT", 30),
        },
      },
    },
  },
  flying_pikachu = {
    map = "VERMILION_CITY",
    name = "KANTO_HERITAGE_BALLOON_HOST",
    textId = "MOD_KANTO_HERITAGE_BALLOON",
    sprite = "SPRITE_COOLTRAINER_F",
    preferred = { { 18, 18 }, { 17, 18 }, { 19, 18 } },
    title = text("BALLOON CUP", "BALLON-CUP"),
    intro = text(
      "Vermilion's Balloon Cup\ncelebrates an impossible\nPikachu flight.\fClear three Electric\ncrews to claim it.",
      "Oranias Ballon-Cup\nfeiert einen unmöglichen\nPikachu-Flug.\fBesiege drei Elektro-\nTeams und hole es dir."),
    opponents = {
      {
        class = "OPP_ENGINEER", name = text("ENGINEER VOLT", "INGENIEUR VOLT"),
        team = {
          mon("VOLTORB", 28), mon("MAGNEMITE", 29), mon("PIKACHU", 29),
        },
      },
      {
        class = "OPP_ROCKER", name = text("ROCKER AMP", "ROCKER AMP"),
        team = {
          mon("ELECTABUZZ", 30), mon("RAICHU", 31), mon("MAGNETON", 31),
        },
      },
      {
        class = "OPP_JR_TRAINER_M", name = text("PILOT SPARK", "PILOT SPARK"),
        team = {
          mon("JOLTEON", 32), mon("ELECTRODE", 33), mon("RAICHU", 34),
        },
      },
    },
  },
  stamp_rapidash = {
    map = "CELADON_CITY",
    name = "KANTO_HERITAGE_FIRE_HOST",
    textId = "MOD_KANTO_HERITAGE_FIRE",
    sprite = "SPRITE_COOLTRAINER_F",
    preferred = { { 32, 20 }, { 31, 20 }, { 33, 20 } },
    title = text("STAMP FIRE CUP", "STAMP-FEUER-CUP"),
    intro = text(
      "The second Stamp bracket\nburns across three\nFire specialists.\fIts champion receives\na storied Rapidash.",
      "Das zweite Stamp-Turnier\nbrennt durch drei\nFeuer-Spezialisten.\fDer Champ erhält ein\nberühmtes Gallopa."),
    opponents = {
      {
        class = "OPP_BURGLAR", name = text("EMBER ROOK", "GLUT ROOK"),
        team = {
          mon("VULPIX", 38), mon("GROWLITHE", 39), mon("PONYTA", 39),
        },
      },
      {
        class = "OPP_TAMER", name = text("TAMER CINDER", "BÄNDIGER CINDER"),
        team = {
          mon("NINETALES", 40), mon("RAPIDASH", 41), mon("FLAREON", 41),
        },
      },
      {
        class = "OPP_COOLTRAINER_M", name = text("MASTER PYRE", "MEISTER PYRE"),
        team = {
          mon("CHARMELEON", 42), mon("MAGMAR", 43), mon("ARCANINE", 44),
        },
      },
    },
  },
  surfing_pikachu = {
    map = "FUCHSIA_CITY",
    name = "KANTO_HERITAGE_WAVE_HOST",
    textId = "MOD_KANTO_HERITAGE_WAVE",
    sprite = "SPRITE_COOLTRAINER_F",
    preferred = { { 20, 15 }, { 19, 15 }, { 21, 15 } },
    title = text("WAVE CUP", "WELLEN-CUP"),
    intro = text(
      "The Wave Cup remembers\nthe Pikachu that crossed\nthe sea.\fSurvive three Water\nteams to meet its heir.",
      "Der Wellen-Cup erinnert\nan das Pikachu, das das\nMeer überquerte.\fÜberstehe drei Wasser-\nTeams für seinen Erben."),
    opponents = {
      {
        class = "OPP_SWIMMER", name = text("DIVER CORAL", "TAUCHER CORAL"),
        team = {
          mon("SEADRA", 45), mon("DEWGONG", 45), mon("CLOYSTER", 46),
        },
      },
      {
        class = "OPP_FISHER", name = text("ANGLER TIDE", "ANGLER TIDE"),
        team = {
          mon("GOLDUCK", 47), mon("POLIWRATH", 47), mon("TENTACRUEL", 48),
        },
      },
      {
        class = "OPP_COOLTRAINER_F", name = text("CHAMPION MARIS", "CHAMP MARIS"),
        team = {
          mon("BLASTOISE", 49), mon("LAPRAS", 49), mon("STARMIE", 50),
        },
      },
    },
  },
}

E.catchupOrder = {
  "university_magikarp", "stamp_fearow", "flying_pikachu",
  "stamp_rapidash", "surfing_pikachu",
}

return E
