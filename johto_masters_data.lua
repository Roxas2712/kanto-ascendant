-- Inspectable level-100 rosters for the Johto Masters trial.  Each trainer
-- owns a twelve-Pokémon pool; the controller selects six in a changing,
-- deterministic order for every new attempt.

local function mon(species, moves, mega)
  return { species = species, level = 100, moves = moves, mega = mega }
end

local function text(en, de)
  return { en = en, de = de }
end

return {
  map = "INDIGO_PLATEAU_LOBBY",
  name = "KANTO_ASCENDANT_JOHTO_MASTERS",
  textId = "MOD_KANTO_ASCENDANT_JOHTO_MASTERS",
  sprite = "SPRITE_COOLTRAINER_M",
  preferred = { { 10, 5 }, { 11, 5 }, { 10, 6 }, { 11, 6 } },
  trainers = {
    {
      key = "silver", name = text("SILVER", "SILVER"),
      class = "OPP_RIVAL3",
      intro = text(
        "SILVER: I discarded\nweakness long ago.\fShow me whether Kanto's\nChampion deserves the\nstories.",
        "SILVER: Schwäche habe\nich längst abgelegt.\fZeig, ob Kantos Champ\ndie Geschichten verdient."),
      win = text("I still have farther\nto climb...",
        "Ich muss noch höher\nsteigen..."),
      pool = {
        mon("TYRANITAR", { "CRUNCH", "ROCK_SLIDE", "EARTHQUAKE", "HYPER_BEAM" }),
        mon("CROBAT", { "WING_ATTACK", "CONFUSE_RAY", "TOXIC", "HYPER_BEAM" }),
        mon("GENGAR", { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "EXPLOSION" }),
        mon("SNEASEL", { "BLIZZARD", "SLASH", "SHADOW_BALL", "AGILITY" }),
        mon("HOUNDOOM", { "CRUNCH", "FIRE_BLAST", "SLUDGE_BOMB", "ROAR" }),
        mon("MAGNETON", { "THUNDERBOLT", "THUNDER_WAVE", "SWIFT", "SCREECH" }),
        mon("ALAKAZAM", { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
        mon("FERALIGATR", { "HYDRO_PUMP", "BLIZZARD", "CRUNCH", "SLASH" }),
        mon("TYPHLOSION", { "FIRE_BLAST", "THUNDERPUNCH", "EARTHQUAKE", "SMOKESCREEN" }),
        mon("MEGANIUM", { "RAZOR_LEAF", "BODY_SLAM", "REFLECT", "SLEEP_POWDER" }),
        mon("STEELIX", { "IRON_TAIL", "EARTHQUAKE", "ROCK_SLIDE", "EXPLOSION" }),
        mon("SCIZOR", { "METAL_CLAW", "SLASH", "SWORDS_DANCE", "HYPER_BEAM" }),
      },
    },
    {
      key = "kris", name = text("KRIS", "KRIS"),
      class = "OPP_COOLTRAINER_F",
      intro = text(
        "KRIS: Power is only the\nfirst question.\fCan your team solve six\nproblems without a Bag?",
        "KRIS: Kraft ist nur die\nerste Frage.\fLöst dein Team sechs\nProbleme ohne Beutel?"),
      win = text("Every answer created\na better question.",
        "Jede Antwort schuf\neine bessere Frage."),
      pool = {
        mon("ESPEON", { "PSYCHIC_M", "RECOVER", "REFLECT", "SWIFT" }),
        mon("UMBREON", { "CRUNCH", "TOXIC", "CONFUSE_RAY", "REST" }),
        mon("BLISSEY", { "BODY_SLAM", "THUNDER_WAVE", "SOFTBOILED", "BLIZZARD" }),
        mon("SKARMORY", { "SKY_ATTACK", "METAL_CLAW", "SAND_ATTACK", "AGILITY" }),
        mon("KINGDRA", { "HYDRO_PUMP", "BLIZZARD", "SMOKESCREEN", "HYPER_BEAM" }),
        mon("MILTANK", { "BODY_SLAM", "EARTHQUAKE", "REST", "THUNDER" }),
        mon("FORRETRESS", { "EXPLOSION", "PIN_MISSILE", "TOXIC", "REFLECT" }),
        mon("SLOWKING", { "PSYCHIC_M", "SURF", "AMNESIA", "REST" }),
        mon("JUMPLUFF", { "SLEEP_POWDER", "GIGA_DRAIN", "LEECH_SEED", "TOXIC" }),
        mon("POLITOED", { "HYDRO_PUMP", "BLIZZARD", "HYPNOSIS", "BODY_SLAM" }),
        mon("AMPHAROS", { "THUNDER", "THUNDER_WAVE", "FIRE_PUNCH", "LIGHT_SCREEN" }),
        mon("HERACROSS", { "PIN_MISSILE", "SUBMISSION", "EARTHQUAKE", "SWORDS_DANCE" }),
      },
    },
    {
      key = "gold", name = text("GOLD", "GOLD"),
      class = "OPP_RIVAL2",
      intro = text(
        "GOLD: Johto followed your\nlegend all the way here.\fNow battle the trainer\nwho followed it farthest!",
        "GOLD: Johto folgte deiner\nLegende bis hierher.\fKämpfe nun gegen den,\nder ihr am weitesten\nfolgte!"),
      win = text("That was a truly\ngolden battle!",
        "Das war ein wahrhaft\ngoldener Kampf!"),
      pool = {
        mon("MEGANIUM", { "RAZOR_LEAF", "SLEEP_POWDER", "REFLECT", "BODY_SLAM" }),
        mon("TYPHLOSION", { "FIRE_BLAST", "THUNDERPUNCH", "EARTHQUAKE", "SMOKESCREEN" }),
        mon("FERALIGATR", { "HYDRO_PUMP", "BLIZZARD", "CRUNCH", "SLASH" }),
        mon("AMPHAROS", { "THUNDER", "THUNDER_WAVE", "FIRE_PUNCH", "LIGHT_SCREEN" }),
        mon("TYRANITAR", { "CRUNCH", "ROCK_SLIDE", "EARTHQUAKE", "HYPER_BEAM" }),
        mon("SCIZOR", { "METAL_CLAW", "SLASH", "SWORDS_DANCE", "HYPER_BEAM" }),
        mon("DONPHAN", { "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM", "DEFENSE_CURL" }),
        mon("PORYGON2", { "TRI_ATTACK", "PSYCHIC_M", "RECOVER", "THUNDER_WAVE" }),
        mon("LUGIA", { "AEROBLAST", "PSYCHIC_M", "HYDRO_PUMP", "RECOVER" }),
        mon("HO_OH", { "SACRED_FIRE", "SKY_ATTACK", "EARTHQUAKE", "RECOVER" }),
        mon("CELEBI", { "PSYCHIC_M", "GIGA_DRAIN", "RECOVER", "THUNDER_WAVE" }),
        mon("RAIKOU", { "THUNDER", "CRUNCH", "REFLECT", "THUNDER_WAVE" }),
      },
    },
  },
}
