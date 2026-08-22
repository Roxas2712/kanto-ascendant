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
  -- Keep the host on the public visitor floor.  The old coordinates were
  -- counter/wall cells; findSpawnCell therefore fell back to the first free
  -- cell in the whole map and put him in the staff alcove at (6,1), where he
  -- looked like an ordinary clerk and could be mistaken for missing.
  preferred = {
    { 10, 8 }, { 11, 8 }, { 10, 9 },
  },
  publicArea = { minX = 10, maxX = 11, minY = 8, maxY = 9 },
  trainers = {
    {
      key = "silver", name = text("SILVER", "SILVER"),
      -- Never route a Johto Master through Kanto's Rival renderer.  The
      -- passage controller registers these isolated classes together with
      -- their own portraits and zero-money trainer records.
      class = "KA_JOHTO_SILVER",
      intro = text(
        "SILVER: I overcame my\nweaknesses long ago.\fShow me whether Kanto's\nChampion lives up to\nthat title!",
        "SILVER: Meine Schwächen\nhabe ich überwunden.\fZeig mir, ob Kantos\nChampion seinem Titel\ngerecht wird!"),
      win = text("Not bad... I still\nhave farther to climb.",
        "Nicht schlecht... Ich\nmuss noch stärker werden."),
      pool = {
        mon("TYRANITAR", { "CRUNCH", "ROCK_SLIDE", "EARTHQUAKE", "HYPER_BEAM" }),
        mon("CROBAT", { "WING_ATTACK", "CONFUSE_RAY", "TOXIC", "HYPER_BEAM" }),
        mon("GENGAR", { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "EXPLOSION" }),
        mon("SNEASEL", { "BLIZZARD", "SLASH", "SHADOW_BALL", "AGILITY" }),
        mon("HOUNDOOM", { "CRUNCH", "FIRE_BLAST", "SLUDGE_BOMB", "ROAR" }),
        mon("MAGNETON", { "THUNDERBOLT", "THUNDER_WAVE", "SWIFT", "SCREECH" }),
        mon("ALAKAZAM", { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
        mon("FERALIGATR", { "HYDRO_PUMP", "BLIZZARD", "CRUNCH", "SLASH" }, "FERALIGATR"),
        -- Silver owns the Totodile line exclusively.  ENTEI keeps the hard
        -- Fire slot without borrowing Gold's Cyndaquil line; URSARING is a
        -- second strong, Johto-native physical threat unique to this pool.
        mon("ENTEI", { "SACRED_FIRE", "FIRE_BLAST", "BODY_SLAM", "REFLECT" }),
        mon("URSARING", { "BODY_SLAM", "EARTHQUAKE", "HYPER_BEAM", "REST" }),
        mon("STEELIX", { "IRON_TAIL", "EARTHQUAKE", "ROCK_SLIDE", "EXPLOSION" }),
        mon("SCIZOR", { "METAL_CLAW", "SLASH", "SWORDS_DANCE", "HYPER_BEAM" }),
      },
    },
    {
      key = "kris", name = text("KRIS", "KRIS"),
      class = "KA_JOHTO_KRIS",
      intro = text(
        "KRIS: Power alone is not\nenough.\fCan your team adapt to\nevery switch without\nthe Bag?",
        "KRIS: Stärke allein\nreicht nicht.\fKann dein Team ohne\nBeutel auf jeden Wechsel\nreagieren?"),
      win = text("Your choices passed\nevery test. I still\nhave more to learn.",
        "Deine Entscheidungen\nbestanden jede Prüfung.\fIch habe noch viel\nzu lernen."),
      pool = {
        mon("ESPEON", { "PSYCHIC_M", "RECOVER", "REFLECT", "SWIFT" }),
        mon("UMBREON", { "CRUNCH", "TOXIC", "CONFUSE_RAY", "REST" }),
        mon("BLISSEY", { "BODY_SLAM", "THUNDER_WAVE", "SOFTBOILED", "BLIZZARD" }),
        mon("SKARMORY", { "SKY_ATTACK", "METAL_CLAW", "SAND_ATTACK", "AGILITY" }),
        mon("KINGDRA", { "HYDRO_PUMP", "BLIZZARD", "SMOKESCREEN", "HYPER_BEAM" }),
        mon("MILTANK", { "BODY_SLAM", "EARTHQUAKE", "REST", "THUNDER" }),
        mon("FORRETRESS", { "EXPLOSION", "PIN_MISSILE", "TOXIC", "REFLECT" }),
        mon("SLOWKING", { "PSYCHIC_M", "SURF", "AMNESIA", "REST" }),
        mon("MEGANIUM", { "RAZOR_LEAF", "SLEEP_POWDER", "REFLECT", "BODY_SLAM" }, "MEGANIUM"),
        mon("POLITOED", { "HYDRO_PUMP", "BLIZZARD", "HYPNOSIS", "BODY_SLAM" }),
        mon("AMPHAROS", { "THUNDER", "THUNDER_WAVE", "FIRE_PUNCH", "LIGHT_SCREEN" }),
        mon("HERACROSS", { "PIN_MISSILE", "SUBMISSION", "EARTHQUAKE", "SWORDS_DANCE" }),
      },
    },
    {
      key = "gold", name = text("GOLD", "GOLD"),
      class = "KA_JOHTO_GOLD",
      intro = text(
        "GOLD: Johto followed your\nlegend all the way here.\fNow battle the trainer\nwho followed it farthest!",
        "GOLD: Johto folgte deiner\nLegende bis hierher.\fKämpfe nun gegen den,\nder ihr am weitesten\nfolgte!"),
      win = text("That was a truly\ngolden battle!",
        "Das war ein wahrhaft\ngoldener Kampf!"),
      pool = {
        -- Gold owns only the Cyndaquil line.  These five replacements make all
        -- 36 candidates across Silver/Kris/Gold mutually species-unique, so
        -- the rotating six-member teams can never borrow another Master's
        -- starter or repeat an opponent from the same connected run.
        mon("SUICUNE", { "HYDRO_PUMP", "BLIZZARD", "REST", "BODY_SLAM" }),
        mon("TYPHLOSION", { "FIRE_BLAST", "THUNDERPUNCH", "EARTHQUAKE", "SMOKESCREEN" }, "TYPHLOSION_ASCENDANT"),
        mon("OCTILLERY", { "HYDRO_PUMP", "BLIZZARD", "FIRE_BLAST", "PSYCHIC_M" }),
        mon("HITMONTOP", { "SUBMISSION", "EARTHQUAKE", "ROCK_SLIDE", "AGILITY" }),
        mon("GRANBULL", { "BODY_SLAM", "SHADOW_BALL", "EARTHQUAKE", "THUNDER_WAVE" }),
        mon("PILOSWINE", { "EARTHQUAKE", "BLIZZARD", "ROCK_SLIDE", "BODY_SLAM" }),
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
