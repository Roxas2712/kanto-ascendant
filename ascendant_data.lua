-- Kanto Ascendant 2.0 data.  Runtime logic lives in ascendant.lua; this file
-- deliberately contains only inspectable progression, dialogue and rosters.

local function mon(species, level, moves)
  return { species = species, level = level, moves = moves }
end

local function text(en, de)
  return { en = en, de = de }
end

local A = {}

A.ranks = {
  { key = "rookie", threshold = 0, name = text("ROOKIE", "NEULING") },
  { key = "veteran", threshold = 2, name = text("VETERAN", "VETERAN") },
  { key = "expert", threshold = 5, name = text("EXPERT", "EXPERTE") },
  { key = "master", threshold = 10, name = text("MASTER", "MEISTER") },
  { key = "legend", threshold = 20, name = text("LEGEND", "LEGENDE") },
}

A.research = {
  {
    id = "rematch_field", metric = "rematches", target = 5,
    title = text("FIELD STUDY", "FELDSTUDIE"), reward = "NUGGET",
    task = text("Win 5 field\ntrainer rematches.",
      "Gewinne 5 Feld-\ntrainer-Revanchen."),
  },
  {
    id = "rank_experts", metric = "expertTrainers", target = 3,
    title = text("TRAINING THEORY", "TRAININGSLEHRE"), reward = "RARE_CANDY",
    task = text("Raise 3 trainers\nto EXPERT rank.",
      "Bringe 3 Trainer\nauf EXPERTEN-Rang."),
  },
  {
    id = "master_crests", metric = "masterWins", target = 4,
    title = text("LEADER DATA", "LEITER-DATEN"), reward = "PP_UP",
    task = text("Earn 4 MASTER\ncrests.",
      "Erringe 4 MEISTER-\nWappen."),
  },
  {
    id = "legend_signals", metric = "legends", target = 3,
    title = text("LEGEND SIGNALS", "LEGENDEN-SIGNALE"), reward = "MAX_REVIVE",
    task = text("Catch 3 enabled\nlegendary POKéMON.",
      "Fange 3 aktive\nlegendäre POKéMON."),
  },
  {
    id = "leader_quests", metric = "gymQuests", target = 4,
    title = text("LEADER BONDS", "LEITER-BÜNDE"), reward = "RARE_CANDY",
    task = text("Complete 4 Leader\npersonal missions.",
      "Beende 4 persönliche\nLeiter-Missionen."),
  },
  {
    id = "tournament", metric = "tournamentRounds", target = 3,
    title = text("TOURNAMENT DATA", "TURNIER-DATEN"), reward = "PP_UP",
    task = text("Win 3 Ascendant\nFrontier rounds.",
      "Gewinne 3 Runden in\nder Ascendant-Frontier."),
  },
  {
    id = "rocket", metric = "rocketWins", target = 4,
    title = text("ROCKET FILE", "ROCKET-AKTE"), reward = "MASTER_BALL",
    task = text("Defeat all 4 Rocket\nResurgence units.",
      "Besiege alle 4\nRocket-Rückkehrer."),
  },
  {
    id = "crown", metric = "crownChampion", target = 1,
    title = text("CROWN PROOF", "KRONEN-BEWEIS"), reward = "MASTER_BALL",
    task = text("Defeat the CROWN\nChampion.",
      "Besiege den\nKRONEN-Champ."),
  },
}

A.achievements = {
  { id = "rematch_10", title = text("VETERAN HUNTER", "VETERANENJÄGER") },
  { id = "rematch_50", title = text("REMATCH LEGEND", "REVANCHEN-LEGENDE") },
  { id = "master_circuit", title = text("CRESTBEARER", "WAPPENTRÄGER") },
  { id = "apex_champion", title = text("APEX CHAMPION", "APEX-CHAMP") },
  { id = "beast_tracker", title = text("BEAST TRACKER", "BESTIENSPÜRER") },
  { id = "sky_pair", title = text("SKY WITNESS", "HIMMELSZEUGE") },
  { id = "leader_confidant", title = text("KANTO CONFIDANT", "KANTOS VERTRAUTER") },
  { id = "tournament_champ", title = text("GRAND CHAMPION", "GROSSER CHAMP") },
  { id = "crown_champion", title = text("CROWN CHAMPION", "KRONEN-CHAMP") },
  { id = "rocket_breaker", title = text("ROCKET BREAKER", "ROCKET-BRECHER") },
  { id = "untouchable", title = text("UNTOUCHABLE", "UNBERÜHRT") },
  { id = "purist", title = text("KANTO PURIST", "KANTO-PURIST") },
  { id = "mew_found", title = text("MYTH SEEKER", "MYTHENSUCHER") },
  { id = "ascendant", title = text("KANTO ASCENDANT", "KANTO ASCENDANT") },
  { id = "johto_master", title = text(
      "JOHTO MASTER", "JOHTO-MEISTER") },
  { id = "factory_architect", title = text(
      "FACTORY ARCHITECT", "FABRIK-ARCHITEKT") },
  { id = "sea_champion", title = text(
      "SEA CHAMPION", "MEERES-CHAMP") },
}

A.gymQuests = {
  brock = {
    classes = { OPP_HIKER = true, OPP_POKEMANIAC = true }, target = 3,
    reward = "PP_UP",
    intro = text(
      "BROCK: Stones remember\nevery impact.\fRematch 3 HIKER or\nPOKéMANIAC trainers\nand bring me their\ntraining stories.",
      "ROCKO: Steine merken\nsich jeden Aufprall.\fBestreite 3 Revanchen\ngegen WANDERER oder\nPOKéMANIACS."),
    progress = text("The mountain record\nshows %d/3 battles.",
      "Das Bergprotokoll\nzeigt %d/3 Kämpfe."),
    complete = text(
      "BROCK: Solid work.\fYour foundation will\nhold against anything.",
      "ROCKO: Solide Arbeit.\fDein Fundament hält\njedem Gegner stand."),
  },
  misty = {
    classes = { OPP_FISHER = true, OPP_SWIMMER = true, OPP_SAILOR = true },
    target = 3, reward = "MAX_REVIVE",
    intro = text(
      "MISTY: I want battle\ndata from every kind\nof water trainer.\fWin 3 rematches\nagainst FISHER,\nSWIMMER or SAILOR.",
      "MISTY: Ich brauche\nDaten von Wasser-\nTrainern.\fGewinne 3 Revanchen\ngegen ANGLER, SCHWIMMER\noder MATROSEN."),
    progress = text("The current carries\n%d/3 reports.",
      "Die Strömung trägt\n%d/3 Berichte."),
    complete = text(
      "MISTY: Perfect!\fYou can read a battle\nlike moving water.",
      "MISTY: Perfekt!\fDu liest Kämpfe wie\nbewegtes Wasser."),
  },
  surge = {
    classes = { OPP_ENGINEER = true, OPP_ROCKER = true }, target = 3,
    reward = "PP_UP",
    intro = text(
      "SURGE: Kanto's grid is\nspiking again!\fBeat 3 ENGINEER or\nROCKER rematches and\nmeasure the discharge!",
      "MAJOR BOB: Kantos Netz\nschlägt wieder aus!\fBesiege 3 INGENIEURE\noder ROCKER und miss\ndie Entladung!"),
    progress = text("Grid readings:\n%d/3 secured.",
      "Netz-Messungen:\n%d/3 gesichert."),
    complete = text(
      "SURGE: Outstanding!\fYou turned that surge\ninto pure power!",
      "MAJOR BOB: Großartig!\fDu hast die Spannung\nin Kraft verwandelt!"),
  },
  erika = {
    classes = { OPP_BEAUTY = true, OPP_JR_TRAINER_F = true,
      OPP_LASS = true }, target = 3, reward = "RARE_CANDY",
    intro = text(
      "ERIKA: Growth needs\npatient rivals.\fWin 3 rematches with\nLASS, BEAUTY or young\nfemale trainers.",
      "ERIKA: Wachstum braucht\ngeduldige Rivalen.\fGewinne 3 Revanchen\ngegen GIRL, SCHÖNHEIT\noder TRAINERIN."),
    progress = text("The garden journal\nholds %d/3 entries.",
      "Das Gartenbuch enthält\n%d/3 Einträge."),
    complete = text(
      "ERIKA: Every partner\nyou met has bloomed.",
      "ERIKA: Jeder deiner\nPartner ist erblüht."),
  },
  koga = {
    classes = { OPP_JUGGLER = true, OPP_TAMER = true,
      OPP_CHANNELER = true }, target = 3, reward = "MAX_REVIVE",
    intro = text(
      "KOGA: Adaptation is a\nninja's true weapon.\fWin 3 rematches with\nJUGGLER, TAMER or\nCHANNELER.",
      "KOGA: Anpassung ist die\nwahre Ninja-Waffe.\fGewinne 3 Revanchen\ngegen JONGLEUR, DOMPTEUR\noder EXORZISTIN."),
    progress = text("Your field scroll\nrecords %d/3 trials.",
      "Deine Feldrolle zeigt\n%d/3 Prüfungen."),
    complete = text(
      "KOGA: You changed form\nwithout losing focus.",
      "KOGA: Du wechseltest die\nForm ohne Fokusverlust."),
  },
  sabrina = {
    classes = { OPP_PSYCHIC_TR = true, OPP_CHANNELER = true },
    target = 3, reward = "PP_UP",
    intro = text(
      "SABRINA: Three minds\nare calling for you.\fWin 3 PSYCHIC or\nCHANNELER rematches.\nI will listen.",
      "SABRINA: Drei Geister\nrufen nach dir.\fGewinne 3 Revanchen\ngegen PSYCHOs oder\nEXORZISTINNEN."),
    progress = text("I have heard %d/3\nvictory echoes.",
      "Ich hörte %d/3\nSieges-Echos."),
    complete = text(
      "SABRINA: Your intent\narrived before you did.",
      "SABRINA: Deine Absicht\nwar vor dir hier."),
  },
  blaine = {
    classes = { OPP_BURGLAR = true, OPP_SCIENTIST = true },
    target = 3, reward = "RARE_CANDY",
    intro = text(
      "BLAINE: A hot question!\fCan knowledge beat\ninstinct?\fWin 3 BURGLAR or\nSCIENTIST rematches.",
      "PYRO: Eine heiße Frage!\fSchlägt Wissen den\nInstinkt?\fGewinne 3 Revanchen\ngegen DIEBE oder\nWISSENSCHAFTLER."),
    progress = text("The experiment is\n%d/3 complete.",
      "Das Experiment ist\nzu %d/3 beendet."),
    complete = text(
      "BLAINE: Answer: both!\fYour battles proved it!",
      "PYRO: Antwort: beides!\fDeine Kämpfe beweisen es!"),
  },
  giovanni = {
    classes = { OPP_ROCKET = true }, target = 5, reward = "MASTER_BALL",
    intro = text(
      "GIOVANNI: Loyalty is\nproved under pressure.\fDefeat 5 ROCKET\nrematches. Show me\nwhat remains of them.",
      "GIOVANNI: Loyalität\nzeigt sich unter Druck.\fBesiege 5 ROCKETS in\nRevanchen. Zeig mir,\nwas von ihnen bleibt."),
    progress = text("ROCKET losses:\n%d/5 recorded.",
      "ROCKET-Niederlagen:\n%d/5 erfasst."),
    complete = text(
      "GIOVANNI: So none of\nthem surpassed you.\fKeep this. You earned\nmore than their fear.",
      "GIOVANNI: Keiner hat\ndich übertroffen.\fBehalte dies. Du hast\nmehr als ihre Furcht\nverdient."),
  },
}

A.signature = {
  brock = mon("AERODACTYL", 100,
    { "ROCK_SLIDE", "SKY_ATTACK", "FIRE_BLAST", "HYPER_BEAM" }),
  misty = mon("STARMIE", 100,
    { "SURF", "PSYCHIC_M", "THUNDERBOLT", "RECOVER" }),
  surge = mon("JOLTEON", 100,
    { "THUNDERBOLT", "PIN_MISSILE", "DOUBLE_KICK", "AGILITY" }),
  erika = mon("VENUSAUR", 100,
    { "RAZOR_LEAF", "SLEEP_POWDER", "BODY_SLAM", "SWORDS_DANCE" }),
  koga = mon("GENGAR", 100,
    { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "EXPLOSION" }),
  sabrina = mon("ALAKAZAM", 100,
    { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
  blaine = mon("CHARIZARD", 100,
    { "FIRE_BLAST", "SLASH", "EARTHQUAKE", "SWORDS_DANCE" }),
  giovanni = mon("PERSIAN", 100,
    { "SLASH", "BODY_SLAM", "THUNDERBOLT", "BUBBLEBEAM" }),
}

A.tournament = {
  map = "INDIGO_PLATEAU_LOBBY",
  name = "KANTO_ASCENDANT_TOURNAMENT_HOST",
  text = "MOD_KANTO_ASCENDANT_TOURNAMENT",
  sprite = "SPRITE_COOLTRAINER_F",
  preferred = { { 7, 5 }, { 8, 5 }, { 7, 6 } },
  opponents = {
    {
      name = text("ACE MARA", "ASS MARA"), class = "OPP_COOLTRAINER_F",
      team = {
        mon("PERSIAN", 100, { "SLASH", "THUNDERBOLT", "BUBBLEBEAM", "BODY_SLAM" }),
        mon("NINETALES", 100, { "FIRE_BLAST", "CONFUSE_RAY", "BODY_SLAM", "REFLECT" }),
        mon("STARMIE", 100, { "SURF", "PSYCHIC_M", "THUNDERBOLT", "RECOVER" }),
        mon("JOLTEON", 100, { "THUNDERBOLT", "PIN_MISSILE", "AGILITY", "DOUBLE_KICK" }),
        mon("TAUROS", 100, { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" }),
        mon("DRAGONITE", 100, { "BLIZZARD", "THUNDER", "SURF", "HYPER_BEAM" }),
      },
    },
    {
      name = text("ACE ORION", "ASS ORION"), class = "OPP_COOLTRAINER_M",
      team = {
        mon("ALAKAZAM", 100, { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
        mon("CLOYSTER", 100, { "BLIZZARD", "SURF", "CLAMP", "EXPLOSION" }),
        mon("ARCANINE", 100, { "FIRE_BLAST", "BODY_SLAM", "DIG", "AGILITY" }),
        mon("EXEGGUTOR", 100, { "PSYCHIC_M", "SLEEP_POWDER", "MEGA_DRAIN", "EXPLOSION" }),
        mon("RHYDON", 100, { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" }),
        mon("SNORLAX", 100, { "BODY_SLAM", "REST", "EARTHQUAKE", "HYPER_BEAM" }),
      },
    },
    {
      name = text("MYSTIC VALE", "MYSTIKER VALE"), class = "OPP_PSYCHIC_TR",
      team = {
        mon("HYPNO", 100, { "PSYCHIC_M", "HYPNOSIS", "DREAM_EATER", "THUNDER_WAVE" }),
        mon("JYNX", 100, { "BLIZZARD", "PSYCHIC_M", "LOVELY_KISS", "BODY_SLAM" }),
        mon("SLOWBRO", 100, { "SURF", "PSYCHIC_M", "AMNESIA", "REST" }),
        mon("GENGAR", 100, { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "EXPLOSION" }),
        mon("EXEGGUTOR", 100, { "PSYCHIC_M", "MEGA_DRAIN", "SLEEP_POWDER", "EXPLOSION" }),
        mon("ALAKAZAM", 100, { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
      },
    },
    {
      name = text("MASTER RYU", "MEISTER RYU"), class = "OPP_BLACKBELT",
      team = {
        mon("PRIMEAPE", 100, { "SUBMISSION", "ROCK_SLIDE", "BODY_SLAM", "FOCUS_ENERGY" }),
        mon("HITMONLEE", 100, { "HI_JUMP_KICK", "BODY_SLAM", "ROCK_SLIDE", "MEDITATE" }),
        mon("HITMONCHAN", 100, { "SUBMISSION", "THUNDERPUNCH", "ICE_PUNCH", "FIRE_PUNCH" }),
        mon("POLIWRATH", 100, { "SUBMISSION", "SURF", "BLIZZARD", "HYPNOSIS" }),
        mon("GOLEM", 100, { "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM", "EXPLOSION" }),
        mon("MACHAMP", 100, { "SUBMISSION", "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM" }),
      },
    },
    {
      name = text("WARDEN NYX", "WÄCHTER NYX"), class = "OPP_CHANNELER",
      team = {
        mon("GENGAR", 100, { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "DREAM_EATER" }),
        mon("NINETALES", 100, { "FIRE_BLAST", "CONFUSE_RAY", "REFLECT", "BODY_SLAM" }),
        mon("TENTACRUEL", 100, { "SURF", "BLIZZARD", "WRAP", "TOXIC" }),
        mon("VENOMOTH", 100, { "PSYCHIC_M", "SLEEP_POWDER", "MEGA_DRAIN", "DOUBLE_TEAM" }),
        mon("WEEZING", 100, { "SLUDGE", "THUNDERBOLT", "FIRE_BLAST", "EXPLOSION" }),
        mon("GENGAR", 100, { "PSYCHIC_M", "MEGA_DRAIN", "HYPNOSIS", "EXPLOSION" }),
      },
    },
    {
      name = text("CHAMPION ECHO", "CHAMP ECHO"), class = "OPP_RIVAL2",
      team = {
        mon("PIDGEOT", 100, { "SKY_ATTACK", "DOUBLE_EDGE", "MIRROR_MOVE", "AGILITY" }),
        mon("ALAKAZAM", 100, { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
        mon("GYARADOS", 100, { "HYDRO_PUMP", "BLIZZARD", "THUNDERBOLT", "HYPER_BEAM" }),
        mon("ARCANINE", 100, { "FIRE_BLAST", "BODY_SLAM", "DIG", "AGILITY" }),
        mon("VENUSAUR", 100, { "RAZOR_LEAF", "SLEEP_POWDER", "BODY_SLAM", "SWORDS_DANCE" }),
        mon("TAUROS", 100, { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" }),
      },
    },
  },
  rules = {
    {
      id = "standard",
      name = text("OPEN RULES", "OFFENE REGELN"),
      intro = text("Three consecutive\nLEVEL 100 battles.",
        "Drei LEVEL-100-Kämpfe\nin Folge."),
    },
    {
      id = "no_items",
      name = text("NO-ITEM CUP", "OHNE-ITEM-CUP"),
      intro = text("Battle items are\nsealed for all rounds.",
        "Kampfitems sind in\nallen Runden gesperrt."),
    },
    {
      id = "trio",
      name = text("TRIO CUP", "TRIO-CUP"),
      intro = text("Only your first 3\nPOKéMON may compete.",
        "Nur deine ersten 3\nPOKéMON dürfen kämpfen."),
    },
    {
      id = "endurance",
      name = text("ENDURANCE CUP", "AUSDAUER-CUP"),
      intro = text("No healing between\nthree full battles.",
        "Keine Heilung zwischen\ndrei vollen Kämpfen."),
    },
    {
      id = "set",
      name = text("SET-STYLE CUP", "SET-MODUS-CUP"),
      intro = text("No free switch after\nan opponent faints.",
        "Kein freier Wechsel,\nwenn ein Gegner fällt."),
    },
    {
      id = "purist",
      name = text("KANTO PURIST CUP", "KANTO-PURISTEN-CUP"),
      intro = text("Legendary POKéMON are\nsealed for all rounds.",
        "Legendäre POKéMON sind\nfür alle Runden gesperrt."),
    },
  },
}

A.rocket = {
  {
    key = "power", map = "POWER_PLANT",
    name = "KANTO_ASCENDANT_ROCKET_POWER",
    textId = "MOD_KANTO_ASCENDANT_ROCKET_POWER",
    sprite = "SPRITE_ROCKET", class = "OPP_ROCKET",
    preferred = { { 4, 32 }, { 5, 32 }, { 6, 31 } },
    before = text(
      "ROCKET: The legendary\nsurge powered our new\noperation!\fYou are too late to\npull the plug!",
      "ROCKET: Der Legenden-\nImpuls speist unsere\nneue Operation!\fDu ziehst den Stecker\nzu spät!"),
    win = text("The grid rejected us?!",
      "Das Netz stößt uns ab?!"),
    after = text(
      "ROCKET: SILPH already\nhas the next relay.\fYou stopped nothing!",
      "ROCKET: SILPH besitzt\nschon das nächste\nRelais.\fDu hast nichts gestoppt!"),
    team = {
      mon("ELECTRODE", 92, { "THUNDER", "THUNDER_WAVE", "EXPLOSION", "REFLECT" }),
      mon("MAGNETON", 92, { "THUNDERBOLT", "THUNDER_WAVE", "SWIFT", "SCREECH" }),
      mon("RAICHU", 93, { "THUNDERBOLT", "SURF", "BODY_SLAM", "THUNDER_WAVE" }),
      mon("WEEZING", 93, { "SLUDGE", "THUNDERBOLT", "FIRE_BLAST", "EXPLOSION" }),
      mon("JOLTEON", 94, { "THUNDERBOLT", "PIN_MISSILE", "DOUBLE_KICK", "AGILITY" }),
      mon("RHYDON", 94, { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" }),
    },
  },
  {
    key = "silph", map = "SILPH_CO_11F",
    name = "KANTO_ASCENDANT_ROCKET_SILPH",
    textId = "MOD_KANTO_ASCENDANT_ROCKET_SILPH",
    sprite = "SPRITE_ROCKET", class = "OPP_ROCKET",
    preferred = { { 7, 8 }, { 8, 8 }, { 6, 8 } },
    before = text(
      "ROCKET ADMIN: We are\nnot stealing POKéMON.\fWe are mapping the\npower that commands\nthem.",
      "ROCKET-ADMIN: Wir\nstehlen keine POKéMON.\fWir kartieren die\nMacht, die sie lenkt."),
    win = text("The signal is still\nmoving...", "Das Signal bewegt\nsich weiter..."),
    after = text(
      "ADMIN: The dead hear\nfrequencies machines\ncannot.\fOur tower team has\nthe final coordinates.",
      "ADMIN: Die Toten hören\nFrequenzen jenseits\nder Technik.\fUnser Turm-Team hat\ndie letzten Koordinaten."),
    team = {
      mon("PERSIAN", 95, { "SLASH", "BODY_SLAM", "THUNDERBOLT", "BUBBLEBEAM" }),
      mon("HYPNO", 95, { "PSYCHIC_M", "HYPNOSIS", "DREAM_EATER", "THUNDER_WAVE" }),
      mon("MUK", 96, { "SLUDGE", "BODY_SLAM", "MINIMIZE", "EXPLOSION" }),
      mon("CLOYSTER", 96, { "BLIZZARD", "SURF", "CLAMP", "EXPLOSION" }),
      mon("TAUROS", 97, { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" }),
      mon("ALAKAZAM", 97, { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
    },
  },
  {
    key = "tower", map = "POKEMON_TOWER_7F",
    name = "KANTO_ASCENDANT_ROCKET_TOWER",
    textId = "MOD_KANTO_ASCENDANT_ROCKET_TOWER",
    sprite = "SPRITE_ROCKET", class = "OPP_ROCKET",
    preferred = { { 8, 10 }, { 9, 10 }, { 7, 10 } },
    before = text(
      "ROCKET EXECUTIVE: The\nspirits showed us a\nperfect genetic echo.\fGiovanni will make it\nobey.",
      "ROCKET-BOSS: Die\nGeister zeigten uns\nein perfektes Gen-Echo.\fGiovanni wird es\nbeherrschen."),
    win = text("The spirits chose\nyou...", "Die Geister wählten\ndich..."),
    after = text(
      "EXECUTIVE: VIRIDIAN.\fHe has been waiting\nfor the only Trainer\nworth testing it on.",
      "BOSS: VERTANIA.\fEr wartet auf den\neinzigen Trainer, der\ndiesen Test verdient."),
    team = {
      mon("GENGAR", 98, { "PSYCHIC_M", "THUNDERBOLT", "HYPNOSIS", "EXPLOSION" }),
      mon("MAROWAK", 98, { "BONE_CLUB", "EARTHQUAKE", "ROCK_SLIDE", "BODY_SLAM" }),
      mon("NINETALES", 98, { "FIRE_BLAST", "CONFUSE_RAY", "REFLECT", "BODY_SLAM" }),
      mon("TENTACRUEL", 99, { "SURF", "BLIZZARD", "WRAP", "TOXIC" }),
      mon("EXEGGUTOR", 99, { "PSYCHIC_M", "SLEEP_POWDER", "MEGA_DRAIN", "EXPLOSION" }),
      mon("GENGAR", 100, { "PSYCHIC_M", "MEGA_DRAIN", "HYPNOSIS", "DREAM_EATER" }),
    },
  },
  {
    key = "giovanni", map = "VIRIDIAN_GYM",
    existing = "VIRIDIANGYM_GIOVANNI", class = "OPP_GIOVANNI",
    before = text(
      "GIOVANNI: Team Rocket\nwas never about money.\fIt was about control.\fThe legends revealed a\npower even I cannot\nmanufacture.\fShow me whether it\nbelongs to anyone.",
      "GIOVANNI: Team Rocket\nwar nie nur Geld.\fEs ging um Kontrolle.\fDie Legenden zeigten\neine Macht, die selbst\nich nicht erschaffen\nkann.\fZeig, ob sie jemandem\ngehören darf."),
    win = text("So power itself\nrefuses a master...",
      "Selbst die Macht\nverweigert ihren Herrn..."),
    after = text(
      "GIOVANNI: Rocket ends\nhere by my command.\fOak, Fuji and the old\nCinnabar records each\nhold part of the truth.\fFind the origin.",
      "GIOVANNI: Rocket endet\nhier auf meinen Befehl.\fEich, Fuji und die\nalten Zinnober-Akten\nkennen je einen Teil.\fFinde den Ursprung."),
    team = {
      mon("PERSIAN", 100, { "SLASH", "BODY_SLAM", "THUNDERBOLT", "BUBBLEBEAM" }),
      mon("NIDOKING", 100, { "EARTHQUAKE", "THUNDERBOLT", "BLIZZARD", "FIRE_BLAST" }),
      mon("NIDOQUEEN", 100, { "EARTHQUAKE", "THUNDER", "BLIZZARD", "BODY_SLAM" }),
      mon("RHYDON", 100, { "EARTHQUAKE", "ROCK_SLIDE", "THUNDER", "SUBMISSION" }),
      mon("ALAKAZAM", 100, { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" }),
      mon("TAUROS", 100, { "BODY_SLAM", "HYPER_BEAM", "EARTHQUAKE", "BLIZZARD" }),
    },
  },
}

A.mew = {
  map = "ROUTE_24",
  name = "KANTO_ASCENDANT_MEW",
  textId = "MOD_KANTO_ASCENDANT_MEW",
  sprite = "SPRITE_FAIRY",
  preferred = { { 10, 7 }, { 11, 7 }, { 9, 7 } },
  level = 100,
  clues = {
    oak = {
      map = "OAKS_LAB", names = { OAKSLAB_OAK1 = true, OAKSLAB_OAK2 = true },
      text = text(
        "OAK: Every completed\nreport points to one\nmissing origin.\fFUJI once studied a\nsmall creature that\nleft no stable trace.",
        "EICH: Jeder Bericht\nweist auf einen\nfehlenden Ursprung.\fFUJI erforschte einst\nein kleines Wesen ohne\nbeständige Spur."),
    },
    fuji = {
      map = "MR_FUJIS_HOUSE", names = { MRFUJISHOUSE_MR_FUJI = true },
      text = text(
        "FUJI: MEW was never a\nweapon.\fIt followed joy,\ncuriosity and strong\nbonds.\fThe CINNABAR fossil\nroom kept my last\nfield coordinates.",
        "FUJI: MEW war niemals\neine Waffe.\fEs folgte Freude,\nNeugier und starken\nBanden.\fDer Fossilraum auf\nZINNOBER bewahrt meine\nletzten Koordinaten."),
    },
    lab = {
      map = "CINNABAR_LAB_FOSSIL_ROOM",
      names = { CINNABARLABFOSSILROOM_SCIENTIST2 = true },
      text = text(
        "SCIENTIST: This note\nmentions the bridge\nnorth of CERULEAN.\fIt says: Do not hunt.\nStand where adventure\nfirst becomes a choice.",
        "FORSCHER: Diese Notiz\nnennt die Brücke\nnördlich von AZURIA.\fSie sagt: Jage nicht.\nSteh dort, wo Abenteuer\nzur ersten Wahl wird."),
    },
  },
  intro = text(
    "A playful presence\nbrushes every memory\nof your journey.\fThe air sparkles.\fMEW chose to meet you.",
    "Eine verspielte Nähe\nstreift jede Erinnerung\ndeiner Reise.\fDie Luft funkelt.\fMEW hat dich gewählt."),
}

A.newGamePlus = {
  map = "HALL_OF_FAME",
  name = "KANTO_ASCENDANT_STEWARD",
  textId = "MOD_KANTO_ASCENDANT_NEW_GAME_PLUS",
  sprite = "SPRITE_OAK",
  preferred = { { 2, 4 }, { 7, 4 }, { 2, 5 } },
}

A.worldMoments = {
  {
    id = "lugia_calm", map = "VERMILION_CITY", legend = "LUGIA",
    message = text(
      "The harbor falls\nperfectly still.\fFar below, LUGIA's\nsong answers you.",
      "Der Hafen wird völlig\nstill.\fTief unten antwortet\nLUGIAs Lied."),
  },
  {
    id = "hooh_rainbow", map = "LAVENDER_TOWN", legend = "HO_OH",
    message = text(
      "A rainbow circles\nPOKéMON TOWER without\na cloud in the sky.",
      "Ein Regenbogen umkreist\nden POKéMON-TURM bei\nwolkenlosem Himmel."),
  },
  {
    id = "rocket_falls", map = "VIRIDIAN_CITY", rocket = 4,
    message = text(
      "Across Kanto, hidden\nRocket transmitters go\nsilent one by one.",
      "In ganz Kanto verstummen\nversteckte Rocket-Sender\neiner nach dem anderen."),
  },
  {
    id = "mew_laughs", map = "PALLET_TOWN", mew = true,
    message = text(
      "A familiar laugh rides\nthe ocean wind.\fFor once, Kanto feels\ncompletely at peace.",
      "Ein vertrautes Lachen\nreitet auf dem Seewind.\fKanto wirkt endlich\nvollkommen friedlich."),
  },
}

A.world = {
  ["PALLET_TOWN:PALLETTOWN_GIRL"] = {
    rocket = text(
      "Oak says the strange\nsignals are being\ncopied by someone.",
      "Eich sagt, jemand\nkopiert die seltsamen\nSignale."),
    mew = text(
      "Something tiny danced\nacross the bay without\ntouching the water.",
      "Etwas Winziges tanzte\nüber die Bucht, ohne\ndas Wasser zu berühren."),
    complete = text(
      "Even Kanto's rarest\nvisitor followed you\nback home.",
      "Selbst Kantos seltenster\nGast folgte dir nach\nHause."),
  },
  ["VERMILION_CITY:VERMILIONCITY_SAILOR2"] = {
    rocket = text(
      "Unmarked ships carried\nmachines toward the\nPOWER PLANT.",
      "Schiffe ohne Zeichen\nbrachten Maschinen zum\nKRAFTWERK."),
    mew = text(
      "A pink light skipped\nfrom mast to mast.\fNo sailor could catch\nup.",
      "Rosa Licht sprang von\nMast zu Mast.\fKein Matrose kam nach."),
    complete = text(
      "The sea, the sky and\nthat little myth all\nanswer your call.",
      "Meer, Himmel und der\nkleine Mythos folgen\ndeinem Ruf."),
  },
  ["CERULEAN_CITY:CERULEANCITY_SUPER_NERD3"] = {
    rocket = text(
      "The psychic readings\nare being triangulated\nfrom SILPH CO.",
      "Die Psycho-Messungen\nwerden von SILPH CO.\naus geortet."),
    mew = text(
      "The signal is tiny,\nancient and extremely\ncurious.",
      "Das Signal ist winzig,\nuralt und äußerst\nneugierig."),
    complete = text(
      "MEW broke every scale\nand then drew a smile\non my printout.",
      "MEW sprengte jede Skala\nund malte ein Lächeln\nauf meinen Ausdruck."),
  },
  ["FUCHSIA_CITY:FUCHSIACITY_ERIK"] = {
    rocket = text(
      "Rocket scouts tried to\ntrap the beasts.\fThe tracks led them in\ncircles.",
      "Rocket-Späher wollten\ndie Bestien fangen.\fDie Spuren führten sie\nim Kreis."),
    mew = text(
      "Every SAFARI POKéMON\nlooked north at exactly\nthe same moment.",
      "Jedes SAFARI-POKéMON\nblickte im selben\nMoment nach Norden."),
    complete = text(
      "Even MEW left a print.\fIt looks suspiciously\nlike a little hand.",
      "Selbst MEW hinterließ\neine Spur.\fSie sieht wie eine\nkleine Hand aus."),
  },
  ["LAVENDER_TOWN:LAVENDERTOWN_SUPER_NERD"] = {
    rocket = text(
      "Rocket returned to the\ntower with machines\nthat listen to ghosts.",
      "Rocket kehrte mit\nMaschinen zurück, die\nGeister belauschen."),
    mew = text(
      "Fuji says the oldest\nlife leaves the lightest\nfootsteps.",
      "Fuji sagt, das älteste\nLeben hinterlässt die\nleichtesten Schritte."),
    complete = text(
      "The tower bell rang\nonce when MEW accepted\nyou.",
      "Die Turmglocke schlug,\nals MEW dich annahm."),
  },
  ["CINNABAR_ISLAND:CINNABARISLAND_GIRL"] = {
    rocket = text(
      "Someone broke into the\nold laboratory records.\fBLAINE is furious.",
      "Jemand brach in die\nalten Laborakten ein.\fPYRO ist wütend."),
    mew = text(
      "The oldest file points\nback to CERULEAN, not\nthe island.",
      "Die älteste Akte weist\nnach AZURIA, nicht auf\ndie Insel."),
    complete = text(
      "The volcano flashed\npink for one second.\fBLAINE refuses to\nexplain it.",
      "Der Vulkan leuchtete\nkurz rosa.\fPYRO will es nicht\nerklären."),
  },
  ["INDIGO_PLATEAU_LOBBY:INDIGOPLATEAULOBBY_GYM_GUIDE"] = {
    rocket = text(
      "Champion! Rocket agents\nare moving between\nlegendary sites.",
      "Champ! Rocket-Agenten\nziehen zwischen den\nLegendenorten umher."),
    mew = text(
      "The League recognizes\none final research\nsignal north of town.",
      "Die Liga erkennt ein\nletztes Forschungssignal\nnördlich der Stadt."),
    complete = text(
      "Champion, the Grand\nTournament and every\nAscendant title are\nyours to defend.",
      "Champ, das Große Turnier\nund alle Ascendant-Titel\nwarten auf deine\nVerteidigung."),
  },
  ["CELADON_CITY:CELADONCITY_LITTLE_GIRL"] = {
    rocket = text(
      "Men in black uniforms\nare buying every radio\npart in the city.",
      "Männer in schwarzen\nUniformen kaufen jedes\nRadioteil der Stadt."),
    mew = text(
      "A tiny pink POKéMON\nlaughed on the roof.\fNobody believes me.",
      "Ein winziges rosa\nPOKéMON lachte auf dem\nDach.\fNiemand glaubt mir."),
    complete = text(
      "The little pink one\nwaved at me again!\fIt must know you.",
      "Das kleine rosa Wesen\nwinkte mir wieder!\fEs muss dich kennen."),
  },
  ["SAFFRON_CITY:SAFFRONCITY_ROCKET1"] = {
    rocket = text(
      "Rocket orders are\nmoving again.\fThis time even the\nboss sounds afraid.",
      "ROCKET-Befehle laufen\nwieder.\fDiesmal klingt selbst\nder Boss ängstlich."),
    mew = text(
      "No orders. No boss.\fWhatever you found\nended all of it.",
      "Keine Befehle. Kein\nBoss.\fWas immer du fandest,\nhat alles beendet."),
    complete = text(
      "I think I will become\na regular trainer.",
      "Ich werde wohl ein\nganz normaler Trainer."),
  },
  ["ROUTE_24:ROUTE24_COOLTRAINER_M1"] = {
    rocket = text(
      "Strange agents searched\nthe bridge last night.",
      "Seltsame Agenten\ndurchsuchten nachts\ndie Brücke."),
    mew = text(
      "The bridge feels like\nthe start of something\nagain.",
      "Die Brücke fühlt sich\nwieder wie ein Anfang\nan."),
    complete = text(
      "You found what they\ncould not force to\nappear.",
      "Du fandest, was sie\nnicht erzwingen konnten."),
  },
}

return A
