-- Complete Generation-II species catalogue and the progression data used by
-- Elm's Kanto research programme.  Stats use the Gen1 Recomp five-stat model:
-- the two later Special stats are averaged into one value.

local J = {}

-- dex, id, display name, types, HP/Atk/Def/Spd/Special, catch, base exp,
-- growth rate, unused height fields, weight in hectograms.
local rows = {
  { 152, "CHIKORITA", "CHIKORITA", { "GRASS" }, { 45, 49, 65, 45, 57 }, 45, 64, "MEDIUM_SLOW", 0, 4, 64 },
  { 153, "BAYLEEF", "BAYLEEF", { "GRASS" }, { 60, 62, 80, 60, 72 }, 45, 142, "MEDIUM_SLOW", 0, 5, 158 },
  { 154, "MEGANIUM", "MEGANIUM", { "GRASS" }, { 80, 82, 100, 80, 92 }, 45, 236, "MEDIUM_SLOW", 0, 7, 1005 },
  { 155, "CYNDAQUIL", "CYNDAQUIL", { "FIRE" }, { 39, 52, 43, 65, 55 }, 45, 62, "MEDIUM_SLOW", 0, 2, 79 },
  { 156, "QUILAVA", "QUILAVA", { "FIRE" }, { 58, 64, 58, 80, 72 }, 45, 142, "MEDIUM_SLOW", 0, 4, 190 },
  { 157, "TYPHLOSION", "TYPHLOSION", { "FIRE" }, { 78, 84, 78, 100, 97 }, 45, 240, "MEDIUM_SLOW", 0, 7, 795 },
  { 158, "TOTODILE", "TOTODILE", { "WATER" }, { 50, 65, 64, 43, 46 }, 45, 63, "MEDIUM_SLOW", 0, 2, 95 },
  { 159, "CROCONAW", "CROCONAW", { "WATER" }, { 65, 80, 80, 58, 61 }, 45, 142, "MEDIUM_SLOW", 0, 4, 250 },
  { 160, "FERALIGATR", "FERALIGATR", { "WATER" }, { 85, 105, 100, 78, 81 }, 45, 239, "MEDIUM_SLOW", 0, 9, 888 },
  { 161, "SENTRET", "SENTRET", { "NORMAL" }, { 35, 46, 34, 20, 40 }, 255, 43, "MEDIUM_FAST", 0, 3, 60 },
  { 162, "FURRET", "FURRET", { "NORMAL" }, { 85, 76, 64, 90, 50 }, 90, 145, "MEDIUM_FAST", 0, 7, 325 },
  { 163, "HOOTHOOT", "HOOTHOOT", { "NORMAL", "FLYING" }, { 60, 30, 30, 50, 46 }, 255, 52, "MEDIUM_FAST", 0, 3, 212 },
  { 164, "NOCTOWL", "NOCTOWL", { "NORMAL", "FLYING" }, { 100, 50, 50, 70, 91 }, 90, 158, "MEDIUM_FAST", 0, 6, 408 },
  { 165, "LEDYBA", "LEDYBA", { "BUG", "FLYING" }, { 40, 20, 30, 55, 60 }, 255, 53, "FAST", 0, 4, 108 },
  { 166, "LEDIAN", "LEDIAN", { "BUG", "FLYING" }, { 55, 35, 50, 85, 82 }, 90, 137, "FAST", 0, 6, 356 },
  { 167, "SPINARAK", "SPINARAK", { "BUG", "POISON" }, { 40, 60, 40, 30, 40 }, 255, 50, "FAST", 0, 2, 85 },
  { 168, "ARIADOS", "ARIADOS", { "BUG", "POISON" }, { 70, 90, 70, 40, 65 }, 90, 140, "FAST", 0, 4, 335 },
  { 169, "CROBAT", "CROBAT", { "POISON", "FLYING" }, { 85, 90, 80, 130, 75 }, 90, 241, "MEDIUM_FAST", 0, 7, 750 },
  { 170, "CHINCHOU", "CHINCHOU", { "WATER", "ELECTRIC" }, { 75, 38, 38, 67, 56 }, 190, 66, "SLOW", 0, 2, 120 },
  { 171, "LANTURN", "LANTURN", { "WATER", "ELECTRIC" }, { 125, 58, 58, 67, 76 }, 75, 161, "SLOW", 0, 5, 225 },
  { 172, "PICHU", "PICHU", { "ELECTRIC" }, { 20, 40, 15, 60, 35 }, 190, 41, "MEDIUM_FAST", 0, 1, 20 },
  { 173, "CLEFFA", "CLEFFA", { "NORMAL" }, { 50, 25, 28, 15, 50 }, 150, 44, "FAST", 0, 1, 30 },
  { 174, "IGGLYBUFF", "IGGLYBUFF", { "NORMAL" }, { 90, 30, 15, 15, 30 }, 170, 42, "FAST", 0, 1, 10 },
  { 175, "TOGEPI", "TOGEPI", { "NORMAL" }, { 35, 20, 65, 20, 52 }, 190, 49, "FAST", 0, 1, 15 },
  { 176, "TOGETIC", "TOGETIC", { "NORMAL", "FLYING" }, { 55, 40, 85, 40, 92 }, 75, 142, "FAST", 0, 2, 32 },
  { 177, "NATU", "NATU", { "PSYCHIC_TYPE", "FLYING" }, { 40, 50, 45, 70, 58 }, 190, 64, "MEDIUM_FAST", 0, 1, 20 },
  { 178, "XATU", "XATU", { "PSYCHIC_TYPE", "FLYING" }, { 65, 75, 70, 95, 82 }, 75, 165, "MEDIUM_FAST", 0, 6, 150 },
  { 179, "MAREEP", "MAREEP", { "ELECTRIC" }, { 55, 40, 40, 35, 55 }, 235, 56, "MEDIUM_SLOW", 0, 2, 78 },
  { 180, "FLAAFFY", "FLAAFFY", { "ELECTRIC" }, { 70, 55, 55, 45, 70 }, 120, 128, "MEDIUM_SLOW", 0, 3, 133 },
  { 181, "AMPHAROS", "AMPHAROS", { "ELECTRIC" }, { 90, 75, 85, 55, 102 }, 45, 230, "MEDIUM_SLOW", 0, 6, 615 },
  { 182, "BELLOSSOM", "BELLOSSOM", { "GRASS" }, { 75, 80, 95, 50, 95 }, 45, 221, "MEDIUM_SLOW", 0, 2, 58 },
  { 183, "MARILL", "MARILL", { "WATER" }, { 70, 20, 50, 40, 35 }, 190, 88, "FAST", 0, 2, 85 },
  { 184, "AZUMARILL", "AZUMARILL", { "WATER" }, { 100, 50, 80, 50, 70 }, 75, 189, "FAST", 0, 3, 285 },
  { 185, "SUDOWOODO", "SUDOWOODO", { "ROCK" }, { 70, 100, 115, 30, 48 }, 65, 144, "MEDIUM_FAST", 0, 5, 380 },
  { 186, "POLITOED", "POLITOED", { "WATER" }, { 90, 75, 75, 70, 95 }, 45, 225, "MEDIUM_SLOW", 0, 4, 339 },
  { 187, "HOPPIP", "HOPPIP", { "GRASS", "FLYING" }, { 35, 35, 40, 50, 45 }, 255, 50, "MEDIUM_SLOW", 0, 2, 5 },
  { 188, "SKIPLOOM", "SKIPLOOM", { "GRASS", "FLYING" }, { 55, 45, 50, 80, 55 }, 120, 119, "MEDIUM_SLOW", 0, 2, 10 },
  { 189, "JUMPLUFF", "JUMPLUFF", { "GRASS", "FLYING" }, { 75, 55, 70, 110, 75 }, 45, 207, "MEDIUM_SLOW", 0, 3, 30 },
  { 190, "AIPOM", "AIPOM", { "NORMAL" }, { 55, 70, 55, 85, 48 }, 45, 72, "FAST", 0, 3, 115 },
  { 191, "SUNKERN", "SUNKERN", { "GRASS" }, { 30, 30, 30, 30, 30 }, 235, 36, "MEDIUM_SLOW", 0, 1, 18 },
  { 192, "SUNFLORA", "SUNFLORA", { "GRASS" }, { 75, 75, 55, 30, 95 }, 120, 149, "MEDIUM_SLOW", 0, 3, 85 },
  { 193, "YANMA", "YANMA", { "BUG", "FLYING" }, { 65, 65, 45, 95, 60 }, 75, 78, "MEDIUM_FAST", 0, 5, 380 },
  { 194, "WOOPER", "WOOPER", { "WATER", "GROUND" }, { 55, 45, 45, 15, 25 }, 255, 42, "MEDIUM_FAST", 0, 2, 85 },
  { 195, "QUAGSIRE", "QUAGSIRE", { "WATER", "GROUND" }, { 95, 85, 85, 35, 65 }, 90, 151, "MEDIUM_FAST", 0, 6, 750 },
  { 196, "ESPEON", "ESPEON", { "PSYCHIC_TYPE" }, { 65, 65, 60, 110, 112 }, 45, 184, "MEDIUM_FAST", 0, 4, 265 },
  { 197, "UMBREON", "UMBREON", { "DARK" }, { 95, 65, 110, 65, 95 }, 45, 184, "MEDIUM_FAST", 0, 4, 270 },
  { 198, "MURKROW", "MURKROW", { "DARK", "FLYING" }, { 60, 85, 42, 91, 64 }, 30, 81, "MEDIUM_SLOW", 0, 2, 21 },
  { 199, "SLOWKING", "SLOWKING", { "WATER", "PSYCHIC_TYPE" }, { 95, 75, 80, 30, 105 }, 70, 172, "MEDIUM_FAST", 0, 8, 795 },
  { 200, "MISDREAVUS", "MISDREAVUS", { "GHOST" }, { 60, 60, 60, 85, 85 }, 45, 87, "FAST", 0, 3, 10 },
  { 201, "UNOWN", "UNOWN", { "PSYCHIC_TYPE" }, { 48, 72, 48, 48, 60 }, 225, 118, "MEDIUM_FAST", 0, 2, 50 },
  { 202, "WOBBUFFET", "WOBBUFFET", { "PSYCHIC_TYPE" }, { 190, 33, 58, 33, 46 }, 45, 142, "MEDIUM_FAST", 0, 5, 285 },
  { 203, "GIRAFARIG", "GIRAFARIG", { "NORMAL", "PSYCHIC_TYPE" }, { 70, 80, 65, 85, 78 }, 60, 159, "MEDIUM_FAST", 0, 6, 415 },
  { 204, "PINECO", "PINECO", { "BUG" }, { 50, 65, 90, 15, 35 }, 190, 58, "MEDIUM_FAST", 0, 2, 72 },
  { 205, "FORRETRESS", "FORRETRESS", { "BUG", "STEEL" }, { 75, 90, 140, 40, 60 }, 75, 163, "MEDIUM_FAST", 0, 5, 1258 },
  { 206, "DUNSPARCE", "DUNSPARCE", { "NORMAL" }, { 100, 70, 70, 45, 65 }, 190, 145, "MEDIUM_FAST", 0, 6, 140 },
  { 207, "GLIGAR", "GLIGAR", { "GROUND", "FLYING" }, { 65, 75, 105, 85, 50 }, 60, 86, "MEDIUM_SLOW", 0, 4, 648 },
  { 208, "STEELIX", "STEELIX", { "STEEL", "GROUND" }, { 75, 85, 200, 30, 60 }, 25, 179, "MEDIUM_FAST", 3, 0, 4000 },
  { 209, "SNUBBULL", "SNUBBULL", { "NORMAL" }, { 60, 80, 50, 30, 40 }, 190, 60, "FAST", 0, 2, 78 },
  { 210, "GRANBULL", "GRANBULL", { "NORMAL" }, { 90, 120, 75, 45, 60 }, 75, 158, "FAST", 0, 6, 487 },
  { 211, "QWILFISH", "QWILFISH", { "WATER", "POISON" }, { 65, 95, 85, 85, 55 }, 45, 88, "MEDIUM_FAST", 0, 2, 39 },
  { 212, "SCIZOR", "SCIZOR", { "BUG", "STEEL" }, { 70, 130, 100, 65, 68 }, 25, 175, "MEDIUM_FAST", 0, 7, 1180 },
  { 213, "SHUCKLE", "SHUCKLE", { "BUG", "ROCK" }, { 20, 10, 230, 5, 120 }, 190, 177, "MEDIUM_SLOW", 0, 2, 205 },
  { 214, "HERACROSS", "HERACROSS", { "BUG", "FIGHTING" }, { 80, 125, 75, 85, 68 }, 45, 175, "SLOW", 0, 6, 540 },
  { 215, "SNEASEL", "SNEASEL", { "DARK", "ICE" }, { 55, 95, 55, 115, 55 }, 60, 86, "MEDIUM_SLOW", 0, 4, 280 },
  { 216, "TEDDIURSA", "TEDDIURSA", { "NORMAL" }, { 60, 80, 50, 40, 50 }, 120, 66, "MEDIUM_FAST", 0, 2, 88 },
  { 217, "URSARING", "URSARING", { "NORMAL" }, { 90, 130, 75, 55, 75 }, 60, 175, "MEDIUM_FAST", 0, 7, 1258 },
  { 218, "SLUGMA", "SLUGMA", { "FIRE" }, { 40, 40, 40, 20, 55 }, 190, 50, "MEDIUM_FAST", 0, 3, 350 },
  { 219, "MAGCARGO", "MAGCARGO", { "FIRE", "ROCK" }, { 60, 50, 120, 30, 85 }, 75, 151, "MEDIUM_FAST", 0, 3, 550 },
  { 220, "SWINUB", "SWINUB", { "ICE", "GROUND" }, { 50, 50, 40, 50, 30 }, 225, 50, "SLOW", 0, 2, 65 },
  { 221, "PILOSWINE", "PILOSWINE", { "ICE", "GROUND" }, { 100, 100, 80, 50, 60 }, 75, 158, "SLOW", 0, 4, 558 },
  { 222, "CORSOLA", "CORSOLA", { "WATER", "ROCK" }, { 65, 55, 95, 35, 80 }, 60, 144, "FAST", 0, 2, 50 },
  { 223, "REMORAID", "REMORAID", { "WATER" }, { 35, 65, 35, 65, 50 }, 190, 60, "MEDIUM_FAST", 0, 2, 120 },
  { 224, "OCTILLERY", "OCTILLERY", { "WATER" }, { 75, 105, 75, 45, 90 }, 75, 168, "MEDIUM_FAST", 0, 4, 285 },
  { 225, "DELIBIRD", "DELIBIRD", { "ICE", "FLYING" }, { 45, 55, 45, 75, 55 }, 45, 116, "FAST", 0, 4, 160 },
  { 226, "MANTINE", "MANTINE", { "WATER", "FLYING" }, { 85, 40, 70, 70, 110 }, 25, 170, "SLOW", 0, 8, 2200 },
  { 227, "SKARMORY", "SKARMORY", { "STEEL", "FLYING" }, { 65, 80, 140, 70, 55 }, 25, 163, "SLOW", 0, 7, 505 },
  { 228, "HOUNDOUR", "HOUNDOUR", { "DARK", "FIRE" }, { 45, 60, 30, 65, 65 }, 120, 66, "SLOW", 0, 2, 108 },
  { 229, "HOUNDOOM", "HOUNDOOM", { "DARK", "FIRE" }, { 75, 90, 50, 95, 95 }, 45, 175, "SLOW", 0, 6, 350 },
  { 230, "KINGDRA", "KINGDRA", { "WATER", "DRAGON" }, { 75, 95, 95, 85, 95 }, 45, 243, "MEDIUM_FAST", 0, 7, 1520 },
  { 231, "PHANPY", "PHANPY", { "GROUND" }, { 90, 60, 60, 40, 40 }, 120, 66, "MEDIUM_FAST", 0, 2, 335 },
  { 232, "DONPHAN", "DONPHAN", { "GROUND" }, { 90, 120, 120, 50, 60 }, 60, 175, "MEDIUM_FAST", 0, 4, 1200 },
  { 233, "PORYGON2", "PORYGON2", { "NORMAL" }, { 85, 80, 90, 60, 100 }, 45, 180, "MEDIUM_FAST", 0, 2, 325 },
  { 234, "STANTLER", "STANTLER", { "NORMAL" }, { 73, 95, 62, 85, 75 }, 45, 163, "SLOW", 0, 6, 712 },
  { 235, "SMEARGLE", "SMEARGLE", { "NORMAL" }, { 55, 20, 35, 75, 32 }, 45, 88, "FAST", 0, 5, 580 },
  { 236, "TYROGUE", "TYROGUE", { "FIGHTING" }, { 35, 35, 35, 35, 35 }, 75, 42, "MEDIUM_FAST", 0, 3, 210 },
  { 237, "HITMONTOP", "HITMONTOP", { "FIGHTING" }, { 50, 95, 95, 70, 72 }, 45, 159, "MEDIUM_FAST", 0, 6, 480 },
  { 238, "SMOOCHUM", "SMOOCHUM", { "ICE", "PSYCHIC_TYPE" }, { 45, 30, 15, 65, 75 }, 45, 61, "MEDIUM_FAST", 0, 2, 60 },
  { 239, "ELEKID", "ELEKID", { "ELECTRIC" }, { 45, 63, 37, 95, 60 }, 45, 72, "MEDIUM_FAST", 0, 2, 235 },
  { 240, "MAGBY", "MAGBY", { "FIRE" }, { 45, 75, 37, 83, 62 }, 45, 73, "MEDIUM_FAST", 0, 3, 214 },
  { 241, "MILTANK", "MILTANK", { "NORMAL" }, { 95, 80, 105, 100, 55 }, 45, 172, "SLOW", 0, 5, 755 },
  { 242, "BLISSEY", "BLISSEY", { "NORMAL" }, { 255, 10, 10, 55, 105 }, 30, 255, "FAST", 0, 6, 468 },
  { 243, "RAIKOU", "RAIKOU", { "ELECTRIC" }, { 90, 85, 75, 115, 108 }, 3, 255, "SLOW", 0, 7, 1780 },
  { 244, "ENTEI", "ENTEI", { "FIRE" }, { 115, 115, 85, 100, 82 }, 3, 255, "SLOW", 0, 8, 1980 },
  { 245, "SUICUNE", "SUICUNE", { "WATER" }, { 100, 75, 115, 85, 102 }, 3, 255, "SLOW", 0, 8, 1870 },
  { 246, "LARVITAR", "LARVITAR", { "ROCK", "GROUND" }, { 50, 64, 50, 41, 48 }, 45, 60, "SLOW", 0, 2, 720 },
  { 247, "PUPITAR", "PUPITAR", { "ROCK", "GROUND" }, { 70, 84, 70, 51, 68 }, 45, 144, "SLOW", 0, 5, 1520 },
  { 248, "TYRANITAR", "TYRANITAR", { "ROCK", "DARK" }, { 100, 134, 110, 61, 98 }, 45, 255, "SLOW", 0, 8, 2020 },
  { 249, "LUGIA", "LUGIA", { "PSYCHIC_TYPE", "FLYING" }, { 106, 90, 130, 110, 122 }, 3, 255, "SLOW", 1, 8, 2160 },
  { 250, "HO_OH", "HO-OH", { "FIRE", "FLYING" }, { 106, 130, 90, 90, 132 }, 3, 255, "SLOW", 1, 3, 1990 },
  { 251, "CELEBI", "CELEBI", { "PSYCHIC_TYPE", "GRASS" }, { 100, 100, 100, 100, 100 }, 45, 255, "MEDIUM_SLOW", 0, 2, 50 },
}

J.species = {}
J.order = {}
for _, row in ipairs(rows) do
  local stat = row[5]
  local def = {
    dex = row[1], id = row[2], name = row[3], types = row[4],
    stats = {
      hp = stat[1], attack = stat[2], defense = stat[3],
      speed = stat[4], special = stat[5],
    },
    catchRate = row[6], baseExp = row[7], growthRate = row[8],
    weightKg = row[11] / 10,
  }
  J.species[def.id] = def
  J.order[#J.order + 1] = def.id
end

-- The six added legends intentionally reuse Gen 1's animated party-menu
-- silhouettes. Their battle art remains species-specific.
J.partyIcons = {
  RAIKOU = "QUADRUPED", ENTEI = "QUADRUPED", SUICUNE = "QUADRUPED",
  LUGIA = "BIRD", HO_OH = "BIRD", CELEBI = "FAIRY",
}

J.germanNames = {
  CHIKORITA = "ENDIVIE", BAYLEEF = "LORBLATT", MEGANIUM = "MEGANIE",
  CYNDAQUIL = "FEURIGEL", QUILAVA = "IGELAVAR", TYPHLOSION = "TORNUPTO",
  TOTODILE = "KARNIMANI", CROCONAW = "TYRACROC", FERALIGATR = "IMPERGATOR",
  SENTRET = "WIESOR", FURRET = "WIESENIOR", NOCTOWL = "NOCTUH",
  SPINARAK = "WEBARAK", CROBAT = "IKSBAT", CHINCHOU = "LAMPI",
  CLEFFA = "PII", IGGLYBUFF = "FLUFFELUFF", MAREEP = "VOLTILAMM",
  FLAAFFY = "WAATY", BELLOSSOM = "BLUBELLA", SUDOWOODO = "MOGELBAUM",
  POLITOED = "QUAXO", HOPPIP = "HOPPSPROSS", SKIPLOOM = "HUBELUPF",
  JUMPLUFF = "PAPUNGHA", AIPOM = "GRIFFEL", SUNKERN = "SONNKERN",
  SUNFLORA = "SONNFLORA", WOOPER = "FELINO", QUAGSIRE = "MORLORD",
  ESPEON = "PSIANA", UMBREON = "NACHTARA", MURKROW = "KRAMURX",
  SLOWKING = "LASCHOKING", MISDREAVUS = "TRAUNFUGIL", UNOWN = "ICOGNITO",
  WOBBUFFET = "WOINGENAU", PINECO = "TANNZA", FORRETRESS = "FORSTELLKA",
  DUNSPARCE = "DUMMISEL", GLIGAR = "SKORGLA", STEELIX = "STAHLOS",
  QWILFISH = "BALDORFISH", SCIZOR = "SCHEROX", SHUCKLE = "POTTROTT",
  HERACROSS = "SKARABORN", SNEASEL = "SNIEBEL", SLUGMA = "SCHNECKMAG",
  SWINUB = "QUIEKEL", PILOSWINE = "KEIFEL", CORSOLA = "CORASONN",
  DELIBIRD = "BOTOGEL", MANTINE = "MANTAX", SKARMORY = "PANZAERON",
  HOUNDOUR = "HUNDUSTER", HOUNDOOM = "HUNDEMON", KINGDRA = "SEEDRAKING",
  STANTLER = "DAMHIRPLEX", SMEARGLE = "FARBEAGLE", TYROGUE = "RABAUZ",
  HITMONTOP = "KAPOERA", SMOOCHUM = "KUSSILLA", BLISSEY = "HEITEIRA",
  TYRANITAR = "DESPOTAR",
}

-- Species presentation data.  These are deliberately original, compact
-- field-guide descriptions rather than the former one-size-fits-all
-- "JOHTO RESEARCH" placeholder.  Heights and weights follow the Generation-II
-- Pokédex; weights are already carried by the stat rows above.
local dexRows = {
  { .9, "LEAF", "LAUB", "Its head leaf tests\nthe air for warmth\nand fresh water.", "Sein Kopfblatt prüft\ndie Luft auf Wärme\nund frisches Wasser." },
  { 1.2, "HERB", "KRÄUTER", "The scent around its\nneck makes tired\ntravelers feel alert.", "Der Duft an seinem\nHals macht müde\nWanderer wieder wach." },
  { 1.8, "HERB", "KRÄUTER", "Its petals release a\nsoothing aroma over\nwide grasslands.", "Seine Blüten tragen\neinen sanften Duft\nweit übers Grasland." },
  { .5, "FIRE MOUSE", "FEUERMAUS", "It curls into a ball\nwhile the flames on\nits back flare up.", "Es rollt sich ein,\nwährend die Flammen\nam Rücken aufflammen." },
  { .9, "VOLCANO", "VULKAN", "Hot gas and fire run\nalong its back when\nit becomes excited.", "Bei Aufregung ziehen\nFeuer und Hitze über\nseinen Rücken." },
  { 1.7, "VOLCANO", "VULKAN", "Its blazing fur can\ncreate shimmering\nwaves of hot air.", "Sein Flammenfell lässt\ndie Luft vor Hitze\nflimmern." },
  { .6, "BIG JAW", "GROSSMAUL", "It bites anything to\nlearn whether it can\nbe eaten.", "Es beißt in alles, um\nzu prüfen, ob es\nessbar ist." },
  { 1.1, "BIG JAW", "GROSSMAUL", "Even with its jaws\nclamped shut, its\nteeth remain visible.", "Selbst bei geschlossenem\nMaul bleiben seine\nZähne sichtbar." },
  { 2.3, "BIG JAW", "GROSSMAUL", "Its powerful jaws can\ncrush rock, but it is\nawkward on dry land.", "Sein Kiefer zerbricht\nFels, doch an Land\nbewegt es sich schwer." },
  { .8, "SCOUT", "SPÄHER", "It stands on its tail\nto watch far beyond\ntall grass.", "Auf dem Schweif späht\nes weit über hohes\nGras hinweg." },
  { 1.8, "LONG BODY", "LANGKÖRPER", "Its slim body slips\nthrough narrow gaps\nwhile hunting.", "Sein schlanker Körper\ngleitet bei der Jagd\ndurch enge Spalten." },
  { .7, "OWL", "EULE", "It measures time with\na steady rhythm and\nrarely loses balance.", "Es misst die Zeit im\nsteten Takt und verliert\nselten das Gleichgewicht." },
  { 1.6, "OWL", "EULE", "Soft wings let it fly\nwithout warning prey\nin the darkness.", "Mit weichen Flügeln\nnähert es sich Beute\nlautlos im Dunkeln." },
  { 1.0, "FIVE STAR", "FÜNFSTERN", "At dusk, groups follow\nthe stars while searching\nfor safe trees.", "In der Dämmerung folgen\nGruppen den Sternen\nzu sicheren Bäumen." },
  { 1.4, "FIVE STAR", "FÜNFSTERN", "The pattern on its back\nis said to mirror a\nsmall night sky.", "Das Muster am Rücken\ngleicht einem kleinen\nNachthimmel." },
  { .5, "STRING SPIT", "FADENWURF", "It lays nearly invisible\nthreads across forest\npaths at night.", "Nachts spannt es fast\nunsichtbare Fäden über\nWaldwege." },
  { 1.1, "LONG LEG", "LANGBEIN", "It marks territory with\nstrong silk and waits\nmotionless nearby.", "Es markiert sein Revier\nmit fester Seide und\nwartet reglos daneben." },
  { 1.8, "BAT", "FLEDERMAUS", "Four wings carry it\nquickly through even\nthe tightest caves.", "Vier Flügel tragen es\nschnell durch selbst\nenge Höhlen." },
  { .5, "ANGLER", "ANGLER", "Its antenna lights the\nseafloor and draws\ncurious prey closer.", "Seine Antenne erhellt\nden Meeresgrund und\nlockt neugierige Beute." },
  { 1.2, "LIGHT", "LICHT", "The glow from its fins\ncan be seen through\nvery deep water.", "Das Leuchten seiner\nFlossen sieht man noch\nin großer Tiefe." },
  { .3, "TINY MOUSE", "KLEINMAUS", "It stores little sparks\nin its cheeks but leaks\nthem when startled.", "Es speichert kleine\nFunken, verliert sie\naber bei Schreck." },
  { .3, "STAR SHAPE", "STERNFORM", "Starlight seems to make\nit playful and full\nof energy.", "Sternenlicht macht es\nverspielt und voller\nEnergie." },
  { .3, "BALLOON", "BALLON", "Its soft body carries a\nfaintly sweet scent.", "Sein weicher Körper\nverströmt einen leicht\nsüßen Duft." },
  { .3, "SPIKE BALL", "STACHELBALL", "Good feelings collect\ninside its shell and\nbecome gentle energy.", "Gute Gefühle sammeln\nsich in seiner Schale\nals sanfte Energie." },
  { .6, "HAPPINESS", "FREUDE", "It shares its happiness\nwith people it has\nlearned to trust.", "Mit vertrauten Menschen\nteilt es sein eigenes\nGlücksgefühl." },
  { .2, "TINY BIRD", "KLEINVOGEL", "It cannot fly far, so it\nhops onto branches to\nstudy its surroundings.", "Da es kaum fliegt,\nhüpft es auf Äste und\nbeobachtet die Umgebung." },
  { 1.5, "MYSTIC", "MYSTIK", "It stands facing the sun\nand watches events far\nbeyond the horizon.", "Es blickt zur Sonne und\nbeobachtet Geschehen\nweit hinterm Horizont." },
  { .6, "WOOL", "WOLLE", "Its fleece stores static\nuntil its tail begins\nto shine.", "Seine Wolle speichert\nStrom, bis der Schweif\nzu leuchten beginnt." },
  { .8, "WOOL", "WOLLE", "Its rubbery skin keeps\nthe charge beneath its\nwool from escaping.", "Gummiartige Haut hält\ndie Ladung unter seiner\nWolle fest." },
  { 1.4, "LIGHT", "LICHT", "The orb on its tail is\na beacon visible from\nvery far away.", "Die Kugel am Schweif\nist ein weithin sichtbares\nLeuchtfeuer." },
  { .4, "FLOWER", "BLUME", "It spins its petals in\na dance when warm rain\nreaches the soil.", "Bei warmem Regen tanzt\nes drehend über den\nBoden." },
  { .4, "AQUA MOUSE", "AQUAMAUS", "Its oil-filled tail acts\nlike a float in fast\nwater.", "Sein ölreicher Schweif\ndient in schneller\nStrömung als Schwimmer." },
  { .8, "AQUA RABBIT", "AQUAHASE", "Its long ears can hear\nmovement beneath the\nwater surface.", "Seine langen Ohren hören\nBewegungen unter der\nWasseroberfläche." },
  { 1.2, "IMITATION", "IMITATION", "It freezes when seen and\npretends to be a dry,\ntwisted tree.", "Wird es entdeckt, erstarrt\nes wie ein trockener,\nverdrehter Baum." },
  { 1.1, "FROG", "FROSCH", "Its clear call gathers\nothers beside quiet\nponds after rain.", "Sein klarer Ruf versammelt\nArtgenossen nach Regen\nan stillen Teichen." },
  { .4, "COTTONWEED", "WATTEKRAUT", "A light breeze can carry\nit over fences and\nentire fields.", "Schon leichter Wind trägt\nes über Zäune und\nganze Felder." },
  { .6, "COTTONWEED", "WATTEKRAUT", "The flower on its head\nopens as the weather\ngrows warmer.", "Mit wärmerem Wetter\nöffnet sich die Blüte\nauf seinem Kopf." },
  { .8, "COTTONWEED", "WATTEKRAUT", "It rides seasonal winds\nand scatters cottony\nspores across the land.", "Es reitet auf Winden und\nverteilt watteartige\nSporen im Land." },
  { .8, "LONG TAIL", "LANGSCHWEIF", "Its clever tail works\nlike a hand when it\nclimbs or gathers fruit.", "Sein kluger Schweif dient\nbeim Klettern und Sammeln\nwie eine Hand." },
  { .3, "SEED", "SAMEN", "It saves nutrients in\nits tiny body until the\nsun grows strong.", "Es sammelt Nährstoffe,\nbis die Sonne kräftig\ngenug scheint." },
  { .8, "SUN", "SONNE", "It turns its face with\nthe sun and becomes\nstill after dusk.", "Es folgt mit dem Gesicht\nder Sonne und ruht nach\nEinbruch der Nacht." },
  { 1.2, "CLEAR WING", "KLARFLÜGEL", "Its large eyes notice\nmovement in nearly\nevery direction.", "Seine großen Augen sehen\nBewegungen aus beinahe\njeder Richtung." },
  { .4, "WATER FISH", "WASSERFISCH", "It stays cool by coating\nits skin with a thin\nlayer of water.", "Eine dünne Wasserschicht\nhält seine Haut stets\nangenehm kühl." },
  { 1.4, "WATER FISH", "WASSERFISCH", "It bumps boats without\nmalice while drifting\nthrough muddy water.", "Ohne böse Absicht stößt\nes beim Treiben an Boote\nin trübem Wasser." },
  { .9, "SUN", "SONNE", "Its fine fur senses tiny\nchanges in the air and\npredicts an attack.", "Sein feines Fell spürt\nkleinste Luftzüge und\nahnt Angriffe voraus." },
  { 1.0, "MOONLIGHT", "MONDLICHT", "The rings on its body\nshine faintly beneath\na full moon.", "Bei Vollmond leuchten\ndie Ringe an seinem\nKörper schwach." },
  { .5, "DARKNESS", "DUNKELHEIT", "It collects glittering\nobjects and hides them\nbefore sunrise.", "Es sammelt funkelnde\nDinge und versteckt sie\nvor Sonnenaufgang." },
  { 2.0, "ROYAL", "KÖNIG", "A calm mind lets it solve\nproblems while its tail\nsearches the water.", "Mit ruhigem Geist löst\nes Probleme, während der\nSchweif im Wasser sucht." },
  { .7, "SCREECH", "KREISCHER", "Its eerie cry makes even\nbold travelers stop in\nsilent caves.", "Sein unheimlicher Ruf\nlässt selbst Mutige in\nstillen Höhlen halten." },
  { .5, "SYMBOL", "SYMBOL", "Each one resembles a\nmark from an unknown,\nancient alphabet.", "Jedes gleicht einem\nZeichen aus einer\nunbekannten alten Schrift." },
  { 1.3, "PATIENT", "GEDULD", "It endures attacks in\nsilence before releasing\nstored force at once.", "Es erträgt Angriffe still\nund entlädt die Kraft\nauf einmal." },
  { 1.5, "LONG NECK", "LANGHALS", "The small head on its\ntail reacts to threats\nbehind it.", "Der kleine Kopf am\nSchweif reagiert auf\nGefahren von hinten." },
  { .6, "BAGWORM", "SACKTRÄGER", "It hangs from a branch\nand builds its shell\nfrom nearby material.", "Es hängt an Ästen und\nbaut die Hülle aus dem\nMaterial der Umgebung." },
  { 1.2, "BAGWORM", "SACKTRÄGER", "Its layered shell is\nhard enough to survive\na violent impact.", "Seine geschichtete Hülle\nhält selbst heftigen\nStößen stand." },
  { 1.5, "LAND SNAKE", "LANDSCHLANGE", "It escapes through a\ntunnel made with the\ndrill on its tail.", "Mit dem Bohrer am Schweif\ngraben, entkommt es durch\neinen Tunnel." },
  { 1.1, "FLYSCORPION", "FLUGSKORPION", "It rides rising air and\nclings to rock faces\nwith hooked claws.", "Es gleitet auf Aufwind\nund hakt sich mit Krallen\nin Felswände." },
  { 9.2, "IRON SNAKE", "EISENSCHLANGE", "Years underground press\nits body into metal\nharder than stone.", "Jahre unter der Erde\npressen seinen Körper zu\nhärterem Metall als Fels." },
  { .6, "FAIRY", "FEE", "Its fierce expression\nhides a shy and easily\nstartled nature.", "Hinter seinem wilden\nBlick steckt ein scheues,\nschreckhaftes Wesen." },
  { 1.4, "FAIRY", "FEE", "Its heavy jaws frighten\nfoes, though it often\navoids real fights.", "Sein schwerer Kiefer\nschreckt Feinde ab, doch\nes meidet echte Kämpfe." },
  { .5, "BALLOON", "BALLON", "It swallows water and\ninflates before firing\npoisonous spines.", "Es schluckt Wasser, bläht\nsich auf und verschießt\nGiftstacheln." },
  { 1.8, "PINCER", "KNEIFER", "Its claws are hard as\nsteel and marked with\nfalse eye patterns.", "Seine stahlharten Scheren\ntragen Muster wie\nfalsche Augen." },
  { .6, "MOLD", "SCHIMMEL", "Berries stored in its\nshell slowly turn into\na sharp, rich juice.", "Beeren in seiner Schale\nwerden langsam zu einem\nkräftigen Saft." },
  { 1.5, "SINGLE HORN", "EINHORN", "It uses its horn to lift\nand throw opponents far\nheavier than itself.", "Mit dem Horn hebt und\nwirft es viel schwerere\nGegner." },
  { .9, "SHARP CLAW", "SCHARFKLAUE", "Its hooked claws let it\nscale ice while hiding\nunder moonless skies.", "Mit Hakenkrallen erklimmt\nes Eis und verbirgt sich\nin mondloser Nacht." },
  { .6, "LITTLE BEAR", "KLEINBÄR", "Its paws are often sticky\nfrom searching trees for\nsweet food.", "Vom Suchen nach Süßem\nsind seine Pfoten oft\nklebrig." },
  { 1.8, "HIBERNATOR", "WINTERSCHLÄFER", "It marks every food-rich\ntree before the long\nwinter begins.", "Vor dem langen Winter\nmerkt es sich jeden Baum\nmit reicher Nahrung." },
  { .7, "LAVA", "LAVA", "Its body cools and grows\nbrittle whenever it\nstops moving.", "Hält es an, kühlt sein\nKörper ab und wird\nspröde." },
  { .8, "LIVE COAL", "GLUT", "Its shell forms when\nmagma cools rapidly\naround its back.", "Sein Panzer entsteht,\nwenn Magma am Rücken\nrasch abkühlt." },
  { .4, "PIG", "SCHWEIN", "It follows scents through\nsnow with its sensitive\nround nose.", "Mit der empfindlichen\nNase folgt es Gerüchen\ndurch Schnee." },
  { 1.1, "SWINE", "SCHWEIN", "Thick hair covers its\neyes but protects it\nfrom bitter cold.", "Dichtes Haar bedeckt die\nAugen und schützt es vor\nbitterer Kälte." },
  { .6, "CORAL", "KORALLE", "Clean, warm seas make the\nbranches on its back\ngrow brightly.", "In sauberem, warmem Meer\nwachsen die Äste auf\nseinem Rücken kräftig." },
  { .6, "JET", "DÜSEN", "It fires precise streams\nof water at insects high\nabove the surface.", "Es schießt präzise\nWasserstrahlen auf Insekten\nüber der Oberfläche." },
  { .9, "JET", "DÜSEN", "Its flexible arms strike\nfrom many angles without\nwarning.", "Seine beweglichen Arme\nschlagen überraschend aus\nvielen Winkeln zu." },
  { .9, "DELIVERY", "LIEFERUNG", "It carries food in its\ntail to aid travelers\nlost in the snow.", "Im Schweif trägt es Futter\nfür Verirrte im Schnee." },
  { 2.1, "KITE", "ROCHEN", "It glides through the sea\nas smoothly as a bird\nthrough open air.", "Es gleitet durchs Meer\nwie ein Vogel durch die\nfreie Luft." },
  { 1.7, "ARMOR BIRD", "PANZERVOGEL", "Its hollow metal feathers\nare both light and\nrazor sharp.", "Seine hohlen Metallfedern\nsind leicht und zugleich\nmesserscharf." },
  { .6, "DARK", "DUNKEL", "Its cry at dawn signals\nthe boundaries of its\npack's territory.", "Sein Ruf im Morgengrauen\nmarkiert das Revier des\nRudels." },
  { 1.4, "DARK", "DUNKEL", "A pack follows the one\nwhose horns curve most\nproudly.", "Das Rudel folgt jenem mit\nden stolzesten gebogenen\nHörnern." },
  { 1.8, "DRAGON", "DRACHE", "It stores energy in the\nspiral fins along its\nback.", "In den spiralförmigen\nFlossen am Rücken\nspeichert es Energie." },
  { .5, "LONG NOSE", "LANGNASE", "It digs shallow pits with\nits nose and showers\nitself with dust.", "Mit der Nase gräbt es\nMulden und bewirft sich\nmit Staub." },
  { 1.1, "ARMOR", "PANZER", "It curls into a wheel and\ncharges across rough\nground at high speed.", "Zum Rad eingerollt rast\nes schnell über rauen\nBoden." },
  { .6, "VIRTUAL", "VIRTUELL", "An improved program lets\nit study patterns that\nwere once unpredictable.", "Ein verbessertes Programm\nlässt es zuvor chaotische\nMuster verstehen." },
  { 1.4, "BIG HORN", "GROSSHORN", "Its antlers bend vision\nand make nearby objects\nseem strangely distant.", "Sein Geweih verzerrt die\nSicht und lässt Dinge\nseltsam fern wirken." },
  { 1.2, "PAINTER", "MALER", "Each individual leaves a\nunique mark using paint\nfrom its tail.", "Jedes hinterlässt mit der\nFarbe am Schweif ein\neigenes Zeichen." },
  { .7, "SCUFFLE", "RABAUZ", "It challenges strong\nopponents to learn how\nthey move.", "Es fordert starke Gegner,\num ihre Bewegungen zu\nstudieren." },
  { 1.4, "HANDSTAND", "KOPFSTAND", "It spins on its horn and\nkicks in every direction\nat once.", "Auf dem Horn kreiselnd\ntritt es in alle\nRichtungen zugleich." },
  { .4, "KISS", "KUSS", "It explores unfamiliar\nobjects by touching them\nwith its lips.", "Unbekannte Dinge erkundet\nes, indem es sie mit den\nLippen berührt." },
  { .6, "ELECTRIC", "ELEKTRO", "It swings its arms to\ncharge itself before a\nquick strike.", "Vor schnellen Schlägen\nlädt es sich durch\nArmkreisen auf." },
  { .7, "LIVE COAL", "GLUT", "Its body heat rises when\nit breathes deeply and\nsteadily.", "Bei tiefem, ruhigem Atem\nsteigt die Hitze in\nseinem Körper." },
  { 1.2, "MILK COW", "MILCHKUH", "Its nourishing milk is\nricher when it lives on\nhealthy pasture.", "Auf gesunder Weide wird\nseine nahrhafte Milch\nbesonders reichhaltig." },
  { 1.5, "HAPPINESS", "FREUDE", "It senses sadness and\nhurries over to share\nan egg full of joy.", "Es spürt Trauer und eilt\nmit einem Ei voller\nFreude herbei." },
  { 1.9, "THUNDER", "DONNER", "Storm clouds gather above\nthe plains where its\nroar can be heard.", "Über Ebenen, in denen sein\nRuf erklingt, sammeln\nsich Gewitterwolken." },
  { 2.1, "VOLCANO", "VULKAN", "Every powerful roar sends\nwaves of heat rolling\nacross the ground.", "Jeder kräftige Ruf schickt\nHitzewellen über den\nBoden." },
  { 2.0, "AURORA", "AURORA", "It runs across water and\nleaves polluted springs\nclear behind it.", "Es läuft über Wasser und\nhinterlässt verschmutzte\nQuellen wieder klar." },
  { .6, "ROCK SKIN", "FELSHAUT", "It eats soil and grows\nstrong beneath mountains\nfar from sunlight.", "Fern vom Licht frisst es\nErde und wächst unter\nBergen heran." },
  { 1.2, "HARD SHELL", "HARTSCHALE", "Its shell is hard bedrock,\nbut compressed power\nmoves within it.", "Seine Schale ist wie Fels,\ndoch darin bewegt sich\nverdichtete Kraft." },
  { 2.0, "ARMOR", "PANZER", "A single step can shift\nthe ground when it leaves\nits mountain nest.", "Schon ein Schritt bewegt\nden Boden, wenn es sein\nBergnest verlässt." },
  { 5.2, "DIVING", "TAUCHER", "It rests in deep trenches\nso its immense power does\nnot stir the sea.", "Es ruht in tiefen Gräben,\ndamit seine Kraft das\nMeer nicht aufwühlt." },
  { 3.8, "RAINBOW", "REGENBOGEN", "Its radiant wings scatter\nseven colors through the\nmorning mist.", "Seine strahlenden Flügel\nwerfen sieben Farben in\nden Morgennebel." },
  { .6, "TIME TRAVEL", "ZEITREISE", "Where it appears,\nforests flourish\nacross time.", "Wo es erscheint,\ngedeihen Waelder\nueber alle Zeiten." },
}

assert(#dexRows == #J.order, "Johto Pokédex metadata is incomplete")
for index, id in ipairs(J.order) do
  local row = dexRows[index]
  J.species[id].dexEntry = {
    heightM = row[1], kindEn = row[2], kindDe = row[3],
    textEn = row[4], textDe = row[5],
  }
end

-- Crystal-shaped level-up plans using only moves implemented by Gen1 Recomp
-- or registered by postgame_species.lua.  When Crystal used a mechanic that
-- the engine does not implement (for example Baton Pass or Rain Dance), the
-- nearest useful first/second-generation move fills that slot.
local TM = {
  core = { "TOXIC", "MIMIC", "DOUBLE_TEAM", "BIDE", "REST", "SUBSTITUTE" },
  normal = { "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE", "RAGE", "SWIFT",
    "SKULL_BASH" },
  grass = { "MEGA_DRAIN", "SOLARBEAM", "REFLECT", "CUT", "FLASH" },
  fire = { "FIRE_BLAST", "RAGE", "REFLECT" },
  water = { "BUBBLEBEAM", "WATER_GUN", "ICE_BEAM", "BLIZZARD", "SURF" },
  electric = { "THUNDERBOLT", "THUNDER", "THUNDER_WAVE", "FLASH",
    "LIGHT_SCREEN" },
  flying = { "RAZOR_WIND", "WHIRLWIND", "FLY", "SKY_ATTACK" },
  bug = { "MEGA_DRAIN", "RAGE", "REFLECT", "CUT" },
  poison = { "MEGA_DRAIN", "SLUDGE_BOMB" },
  ground = { "EARTHQUAKE", "FISSURE", "DIG", "ROCK_SLIDE", "STRENGTH" },
  rock = { "EARTHQUAKE", "FISSURE", "ROCK_SLIDE", "STRENGTH",
    "SELFDESTRUCT", "EXPLOSION" },
  psychic = { "PSYCHIC_M", "TELEPORT", "REFLECT", "DREAM_EATER",
    "PSYWAVE" },
  ghost = { "PSYCHIC_M", "DREAM_EATER", "PSYWAVE", "SHADOW_BALL" },
  ice = { "ICE_BEAM", "BLIZZARD" },
  fighting = { "MEGA_PUNCH", "MEGA_KICK", "SUBMISSION", "COUNTER",
    "SEISMIC_TOSS", "STRENGTH" },
  dark = { "RAGE", "SHADOW_BALL" },
  steel = { "CUT", "STRENGTH", "IRON_TAIL", "METAL_CLAW" },
  dragon = { "DRAGON_RAGE", "HYPER_BEAM", "SURF" },
}

local function tmList(tags, extras)
  local out, seen = {}, {}
  local function add(id)
    if not seen[id] then seen[id], out[#out + 1] = true, id end
  end
  for _, id in ipairs(TM.core) do add(id) end
  for tag in tostring(tags):gmatch("[^,]+") do
    for _, id in ipairs(TM[tag] or {}) do add(id) end
  end
  for _, id in ipairs(extras or {}) do add(id) end
  return out
end

local function profile(ids, level1, moves, tags, extras)
  local learnset = {}
  for index = 1, #moves, 2 do
    learnset[#learnset + 1] = { level = moves[index], move = moves[index + 1] }
  end
  for _, id in ipairs(ids) do
    local def = assert(J.species[id], "unknown Johto species " .. id)
    def.level1 = {}
    for _, move in ipairs(level1) do def.level1[#def.level1 + 1] = move end
    def.learnset = {}
    for _, row in ipairs(learnset) do
      def.learnset[#def.learnset + 1] = { level = row.level, move = row.move }
    end
    def.tmhm = tmList(tags, extras)
  end
end

profile({ "CHIKORITA", "BAYLEEF", "MEGANIUM" }, { "TACKLE", "GROWL" },
  { 8, "RAZOR_LEAF", 12, "REFLECT", 15, "POISONPOWDER",
    22, "BODY_SLAM", 29, "LIGHT_SCREEN", 36, "SOLARBEAM" }, "grass,normal")
profile({ "CYNDAQUIL", "QUILAVA", "TYPHLOSION" }, { "TACKLE", "LEER" },
  { 6, "SMOKESCREEN", 12, "EMBER", 19, "QUICK_ATTACK",
    27, "FLAME_WHEEL", 36, "SWIFT", 46, "FLAMETHROWER" }, "fire,normal",
  { "DIG", "EARTHQUAKE" })
profile({ "TOTODILE", "CROCONAW", "FERALIGATR" }, { "SCRATCH", "LEER" },
  { 7, "RAGE", 13, "WATER_GUN", 20, "BITE", 27, "LEER",
    35, "SLASH", 43, "HYDRO_PUMP" }, "water,normal", { "CUT", "STRENGTH" })
profile({ "SENTRET", "FURRET" }, { "TACKLE", "DEFENSE_CURL" },
  { 7, "QUICK_ATTACK", 12, "FURY_SWIPES", 19, "SLAM",
    28, "REST", 36, "HYPER_BEAM" }, "normal", { "CUT", "SURF", "DIG" })
profile({ "HOOTHOOT", "NOCTOWL" }, { "TACKLE", "GROWL" },
  { 6, "PECK", 11, "HYPNOSIS", 16, "REFLECT", 25, "CONFUSION",
    34, "TAKE_DOWN" }, "normal,flying,psychic", { "FLASH" })
profile({ "LEDYBA", "LEDIAN" }, { "TACKLE", "SUPERSONIC" },
  { 8, "COMET_PUNCH", 15, "LIGHT_SCREEN", 22, "REFLECT",
    29, "AGILITY", 36, "DOUBLE_EDGE" }, "bug,flying", { "SWIFT" })
profile({ "SPINARAK", "ARIADOS" }, { "POISON_STING", "STRING_SHOT" },
  { 6, "LEER", 11, "CONSTRICT", 17, "NIGHT_SHADE",
    23, "LEECH_LIFE", 30, "FURY_SWIPES", 37, "PSYCHIC_M" }, "bug,poison")
profile({ "CROBAT" }, { "SCREECH", "LEECH_LIFE" },
  { 6, "SUPERSONIC", 12, "BITE", 19, "CONFUSE_RAY",
    30, "WING_ATTACK", 42, "HAZE" }, "poison,flying,dark", { "HYPER_BEAM" })
profile({ "CHINCHOU", "LANTURN" }, { "BUBBLE", "THUNDER_WAVE" },
  { 5, "SUPERSONIC", 13, "WATER_GUN", 21, "SPARK",
    29, "CONFUSE_RAY", 37, "HYDRO_PUMP" }, "water,electric")
profile({ "PICHU" }, { "THUNDERSHOCK", "GROWL" },
  { 6, "TAIL_WHIP", 8, "THUNDER_WAVE", 11, "CONFUSE_RAY" },
  "electric,normal", { "SURF" })
profile({ "CLEFFA" }, { "POUND", "GROWL" },
  { 4, "MIMIC", 8, "SING", 13, "DOUBLESLAP", 17, "METRONOME" },
  "normal,psychic", { "THUNDER_WAVE" })
profile({ "IGGLYBUFF" }, { "SING", "POUND" },
  { 4, "DEFENSE_CURL", 9, "DOUBLESLAP", 14, "BODY_SLAM" }, "normal",
  { "THUNDER_WAVE" })
profile({ "TOGEPI", "TOGETIC" }, { "GROWL", "TAIL_WHIP" },
  { 7, "METRONOME", 14, "CONFUSE_RAY", 25, "DOUBLE_EDGE",
    38, "REFLECT" }, "normal,flying,psychic", { "FLY" })
profile({ "NATU", "XATU" }, { "PECK", "LEER" },
  { 10, "NIGHT_SHADE", 20, "TELEPORT", 30, "CONFUSE_RAY",
    40, "PSYCHIC_M" }, "psychic,flying", { "FLASH" })
profile({ "MAREEP", "FLAAFFY", "AMPHAROS" }, { "TACKLE", "GROWL" },
  { 9, "THUNDERSHOCK", 16, "THUNDER_WAVE", 23, "STUN_SPORE",
    30, "LIGHT_SCREEN", 37, "THUNDER" }, "electric,normal", { "FIRE_PUNCH" })
profile({ "BELLOSSOM" }, { "ABSORB", "STUN_SPORE" },
  { 13, "MEGA_DRAIN", 25, "PETAL_DANCE", 40, "SOLARBEAM" }, "grass")
profile({ "MARILL", "AZUMARILL" }, { "TACKLE", "DEFENSE_CURL" },
  { 6, "TAIL_WHIP", 10, "WATER_GUN", 15, "ROCK_THROW",
    21, "BUBBLEBEAM", 28, "DOUBLE_EDGE" }, "water,normal", { "STRENGTH" })
profile({ "SUDOWOODO" }, { "ROCK_THROW", "MIMIC" },
  { 10, "LOW_KICK", 19, "ROCK_SLIDE", 28, "SLAM",
    37, "EARTHQUAKE" }, "rock,fighting", { "DIG" })
profile({ "POLITOED" }, { "WATER_GUN", "HYPNOSIS" },
  { 12, "DOUBLESLAP", 25, "BODY_SLAM", 38, "HYDRO_PUMP" },
  "water,normal,psychic")
profile({ "HOPPIP", "SKIPLOOM", "JUMPLUFF" }, { "SPLASH", "MEGA_DRAIN" },
  { 5, "TAIL_WHIP", 10, "TACKLE", 13, "POISONPOWDER",
    17, "STUN_SPORE", 21, "SLEEP_POWDER" }, "grass,flying")
profile({ "AIPOM" }, { "SCRATCH", "TAIL_WHIP" },
  { 6, "SAND_ATTACK", 12, "AGILITY", 19, "FURY_SWIPES",
    27, "SWIFT", 36, "SCREECH" }, "normal", { "CUT", "THUNDERBOLT" })
profile({ "SUNKERN", "SUNFLORA" }, { "ABSORB", "GROWTH" },
  { 10, "MEGA_DRAIN", 19, "RAZOR_LEAF", 28, "PETAL_DANCE",
    37, "SOLARBEAM" }, "grass")
profile({ "YANMA" }, { "TACKLE", "QUICK_ATTACK" },
  { 7, "DOUBLE_TEAM", 13, "SONICBOOM", 19, "SUPERSONIC",
    25, "WING_ATTACK", 37, "HYPER_BEAM" }, "bug,flying,normal")
profile({ "WOOPER", "QUAGSIRE" }, { "WATER_GUN", "TAIL_WHIP" },
  { 11, "SLAM", 21, "AMNESIA", 31, "EARTHQUAKE",
    41, "MIST", 51, "HAZE" }, "water,ground", { "ICE_PUNCH" })
-- Espeon is a Gen-II evolution, so its own Crystal level-up schedule is the
-- authority here.  Keep unsupported Crystal moves out of the registry rather
-- than shifting the remaining moves to earlier levels: SAND_ATTACK belongs at
-- 8, SWIFT at 30, PSYBEAM at 36 and PSYCHIC at 47.  The Route 5 Move Reminder
-- consumes this same learnset and therefore also repairs already-levelled
-- Espeon without routing PSYBEAM through Johto Move Resonance.
profile({ "ESPEON" }, { "TACKLE", "TAIL_WHIP" },
  { 8, "SAND_ATTACK", 16, "CONFUSION", 23, "QUICK_ATTACK",
    30, "SWIFT", 36, "PSYBEAM", 47, "PSYCHIC_M" },
  "psychic,normal")
profile({ "UMBREON" }, { "TACKLE", "TAIL_WHIP", "SAND_ATTACK" },
  { 8, "BITE", 16, "CONFUSE_RAY", 23, "QUICK_ATTACK",
    30, "SCREECH", 42, "SHADOW_BALL" }, "dark,normal", { "PSYCHIC_M" })
profile({ "MURKROW" }, { "PECK", "NIGHT_SHADE" },
  { 11, "QUICK_ATTACK", 22, "HAZE", 33, "WING_ATTACK",
    44, "SHADOW_BALL" }, "dark,flying", { "DREAM_EATER" })
profile({ "SLOWKING" }, { "CONFUSION", "DISABLE" },
  { 15, "HEADBUTT", 22, "WATER_GUN", 29, "AMNESIA",
    36, "PSYCHIC_M" }, "water,psychic,normal", { "FIRE_BLAST" })
profile({ "MISDREAVUS" }, { "GROWL", "PSYWAVE" },
  { 6, "DISABLE", 12, "CONFUSE_RAY", 19, "BIND",
    27, "PSYCHIC_M", 36, "SHADOW_BALL" }, "ghost,psychic")
profile({ "UNOWN" }, { "PSYCHIC_M" }, {}, "psychic")
profile({ "WOBBUFFET" }, { "COUNTER", "BIDE" }, {}, "psychic", { "REFLECT" })
profile({ "GIRAFARIG" }, { "TACKLE", "GROWL" },
  { 7, "CONFUSION", 13, "STOMP", 20, "AGILITY",
    30, "PSYBEAM", 41, "CRUNCH" }, "normal,psychic,dark", { "THUNDERBOLT" })
profile({ "PINECO", "FORRETRESS" }, { "TACKLE", "BIDE" },
  { 8, "SELFDESTRUCT", 15, "TAKE_DOWN", 22, "HARDEN",
    29, "EXPLOSION" }, "bug,steel,rock")
profile({ "DUNSPARCE" }, { "RAGE", "DEFENSE_CURL" },
  { 9, "HYPNOSIS", 17, "GLARE", 25, "SCREECH",
    33, "TAKE_DOWN" }, "normal,ground", { "THUNDER", "FIRE_BLAST" })
profile({ "GLIGAR" }, { "POISON_STING", "SAND_ATTACK" },
  { 6, "HARDEN", 13, "QUICK_ATTACK", 20, "SLASH",
    28, "SCREECH" }, "ground,flying,poison", { "CUT" })
profile({ "STEELIX" }, { "TACKLE", "SCREECH" },
  { 10, "BIND", 19, "ROCK_THROW", 28, "HARDEN",
    37, "RAGE", 46, "SLAM" }, "steel,ground,rock", { "DRAGON_RAGE" })
profile({ "SNUBBULL", "GRANBULL" }, { "TACKLE", "LEER" },
  { 7, "TAIL_WHIP", 13, "BITE", 19, "RAGE",
    25, "TAKE_DOWN", 34, "CRUNCH" }, "normal,dark", { "SHADOW_BALL" })
profile({ "QWILFISH" }, { "TACKLE", "POISON_STING" },
  { 9, "HARDEN", 17, "WATER_GUN", 25, "PIN_MISSILE",
    33, "TAKE_DOWN" }, "water,poison", { "EXPLOSION" })
profile({ "SCIZOR" }, { "QUICK_ATTACK", "LEER" },
  { 6, "FOCUS_ENERGY", 12, "METAL_CLAW", 18, "AGILITY",
    26, "SLASH", 36, "SWORDS_DANCE" }, "bug,steel", { "HYPER_BEAM" })
profile({ "SHUCKLE" }, { "CONSTRICT", "WITHDRAW" },
  { 9, "BIDE", 23, "REST", 37, "ROCK_SLIDE" }, "bug,rock")
profile({ "HERACROSS" }, { "TACKLE", "LEER" },
  { 6, "HORN_ATTACK", 12, "FURY_ATTACK", 19, "COUNTER",
    27, "TAKE_DOWN", 36, "PIN_MISSILE" }, "bug,fighting", { "EARTHQUAKE" })
profile({ "SNEASEL" }, { "SCRATCH", "LEER" },
  { 9, "QUICK_ATTACK", 17, "SCREECH", 25, "BITE",
    33, "SLASH", 41, "BLIZZARD" }, "dark,ice,normal", { "CUT" })
profile({ "TEDDIURSA", "URSARING" }, { "SCRATCH", "LEER" },
  { 8, "LICK", 15, "FURY_SWIPES", 22, "REST",
    29, "SLASH", 36, "THRASH" }, "normal,fighting", { "CUT", "EARTHQUAKE" })
profile({ "SLUGMA", "MAGCARGO" }, { "SMOG", "EMBER" },
  { 8, "ROCK_THROW", 15, "HARDEN", 23, "FLAME_WHEEL",
    32, "FLAMETHROWER" }, "fire,rock")
profile({ "SWINUB", "PILOSWINE" }, { "TACKLE", "POWDER_SNOW" },
  { 10, "BIDE", 19, "TAKE_DOWN", 28, "MIST",
    37, "BLIZZARD" }, "ice,ground,normal")
profile({ "CORSOLA" }, { "TACKLE", "HARDEN" },
  { 7, "BUBBLE", 13, "RECOVER", 19, "SPIKE_CANNON",
    31, "ROCK_SLIDE" }, "water,rock", { "PSYCHIC_M" })
profile({ "REMORAID", "OCTILLERY" }, { "WATER_GUN", "FOCUS_ENERGY" },
  { 11, "PSYBEAM", 22, "AURORA_BEAM", 33, "BUBBLEBEAM",
    44, "HYPER_BEAM" }, "water,normal", { "FLAMETHROWER" })
profile({ "DELIBIRD" }, { "PAY_DAY" },
  { 15, "PECK", 25, "ICE_BEAM", 35, "FLY" }, "ice,flying,normal")
profile({ "MANTINE" }, { "TACKLE", "BUBBLE" },
  { 10, "SUPERSONIC", 18, "WING_ATTACK", 27, "TAKE_DOWN",
    36, "HYDRO_PUMP" }, "water,flying", { "CONFUSE_RAY" })
profile({ "SKARMORY" }, { "LEER", "PECK" },
  { 10, "SAND_ATTACK", 19, "SWIFT", 28, "AGILITY",
    37, "METAL_CLAW" }, "steel,flying", { "CUT" })
profile({ "HOUNDOUR", "HOUNDOOM" }, { "LEER", "EMBER" },
  { 7, "ROAR", 13, "SMOG", 20, "BITE", 27, "CRUNCH",
    35, "FLAMETHROWER" }, "dark,fire,normal", { "SOLARBEAM" })
profile({ "KINGDRA" }, { "BUBBLE", "SMOKESCREEN" },
  { 8, "LEER", 15, "WATER_GUN", 22, "DRAGON_RAGE",
    29, "AGILITY", 40, "HYDRO_PUMP" }, "water,dragon", { "ICE_BEAM" })
profile({ "PHANPY", "DONPHAN" }, { "TACKLE", "GROWL" },
  { 9, "DEFENSE_CURL", 17, "BIDE", 25, "TAKE_DOWN",
    33, "ROCK_THROW", 41, "EARTHQUAKE" }, "ground,normal", { "ROAR" })
profile({ "PORYGON2" }, { "CONVERSION", "TACKLE" },
  { 9, "SHARPEN", 18, "PSYBEAM", 27, "RECOVER",
    36, "AGILITY", 45, "TRI_ATTACK" }, "normal,psychic,electric",
  { "ICE_BEAM" })
profile({ "STANTLER" }, { "TACKLE", "LEER" },
  { 8, "HYPNOSIS", 15, "STOMP", 23, "SAND_ATTACK",
    31, "TAKE_DOWN" }, "normal,psychic", { "EARTHQUAKE" })
profile({ "SMEARGLE" }, { "MIMIC" },
  { 11, "MIMIC", 21, "MIMIC", 31, "MIMIC", 41, "MIMIC" }, "", {})
profile({ "TYROGUE" }, { "TACKLE" },
  { 8, "FOCUS_ENERGY", 15, "RAGE" }, "fighting,normal")
profile({ "HITMONTOP" }, { "ROLLING_KICK", "FOCUS_ENERGY" },
  { 7, "QUICK_ATTACK", 13, "COUNTER", 19, "AGILITY",
    25, "DOUBLE_KICK" }, "fighting,normal")
profile({ "SMOOCHUM" }, { "POUND", "LICK" },
  { 9, "LOVELY_KISS", 18, "POWDER_SNOW", 27, "CONFUSION" },
  "ice,psychic", { "METRONOME" })
profile({ "ELEKID" }, { "QUICK_ATTACK", "LEER" },
  { 9, "THUNDERSHOCK", 17, "THUNDERPUNCH", 25, "LIGHT_SCREEN" },
  "electric,fighting,normal")
profile({ "MAGBY" }, { "EMBER", "LEER" },
  { 9, "SMOG", 17, "FIRE_PUNCH", 25, "SMOKESCREEN" },
  "fire,fighting,normal")
profile({ "MILTANK" }, { "TACKLE", "GROWL" },
  { 8, "DEFENSE_CURL", 15, "STOMP", 22, "SOFTBOILED",
    30, "BODY_SLAM" }, "normal,ground", { "THUNDERBOLT" })
profile({ "BLISSEY" }, { "POUND", "GROWL" },
  { 8, "TAIL_WHIP", 15, "SOFTBOILED", 22, "DOUBLESLAP",
    30, "LIGHT_SCREEN" }, "normal,psychic", { "THUNDERBOLT", "ICE_BEAM" })
profile({ "RAIKOU" }, { "BITE", "LEER", "THUNDERSHOCK", "ROAR" },
  { 21, "QUICK_ATTACK", 31, "SPARK", 41, "REFLECT",
    51, "CRUNCH", 61, "THUNDER" }, "electric,dark,normal",
  { "CUT", "ROCK_SLIDE" })
profile({ "ENTEI" }, { "BITE", "LEER", "EMBER", "ROAR" },
  { 21, "FIRE_SPIN", 31, "STOMP", 41, "FLAMETHROWER",
    51, "SACRED_FIRE" }, "fire,dark,normal", { "SOLARBEAM" })
profile({ "SUICUNE" }, { "BITE", "LEER", "BUBBLE", "MIST" },
  { 21, "GUST", 31, "AURORA_BEAM", 41, "REST",
    51, "HYDRO_PUMP" }, "water,ice,normal", { "PSYCHIC_M" })
profile({ "LARVITAR", "PUPITAR", "TYRANITAR" }, { "BITE", "LEER" },
  { 8, "SAND_ATTACK", 15, "SCREECH", 22, "ROCK_SLIDE",
    29, "THRASH", 36, "EARTHQUAKE", 50, "HYPER_BEAM" },
  "rock,ground,dark,normal", { "SURF", "FIRE_BLAST", "THUNDER" })
profile({ "LUGIA" }, { "AEROBLAST", "GUST", "RECOVER", "HYDRO_PUMP" },
  { 33, "REFLECT", 44, "SWIFT", 55, "PSYCHIC_M" },
  "psychic,flying,water,dragon", { "THUNDER", "EARTHQUAKE" })
profile({ "HO_OH" }, { "SACRED_FIRE", "GUST", "RECOVER", "FIRE_BLAST" },
  { 33, "MIST", 44, "SWIFT", 55, "SKY_ATTACK" },
  "fire,flying,psychic", { "EARTHQUAKE", "SOLARBEAM", "THUNDER" })
profile({ "CELEBI" }, { "LEECH_SEED", "CONFUSION", "RECOVER" },
  { 10, "GIGA_DRAIN", 20, "RAZOR_LEAF", 30, "PSYCHIC_M",
    40, "RECOVER" }, "grass,psychic", { "ROCK_SLIDE" })

J.evolutions = {
  CHIKORITA = { { "LEVEL", "BAYLEEF", 16 } },
  BAYLEEF = { { "LEVEL", "MEGANIUM", 32 } },
  CYNDAQUIL = { { "LEVEL", "QUILAVA", 14 } },
  QUILAVA = { { "LEVEL", "TYPHLOSION", 36 } },
  TOTODILE = { { "LEVEL", "CROCONAW", 18 } },
  CROCONAW = { { "LEVEL", "FERALIGATR", 30 } },
  SENTRET = { { "LEVEL", "FURRET", 15 } },
  HOOTHOOT = { { "LEVEL", "NOCTOWL", 20 } },
  LEDYBA = { { "LEVEL", "LEDIAN", 18 } },
  SPINARAK = { { "LEVEL", "ARIADOS", 22 } },
  CHINCHOU = { { "LEVEL", "LANTURN", 27 } },
  PICHU = { { "FRIENDSHIP", "PIKACHU" } },
  CLEFFA = { { "FRIENDSHIP", "CLEFAIRY" } },
  IGGLYBUFF = { { "FRIENDSHIP", "JIGGLYPUFF" } },
  TOGEPI = { { "FRIENDSHIP", "TOGETIC" } },
  NATU = { { "LEVEL", "XATU", 25 } },
  MAREEP = { { "LEVEL", "FLAAFFY", 15 } },
  FLAAFFY = { { "LEVEL", "AMPHAROS", 30 } },
  MARILL = { { "LEVEL", "AZUMARILL", 18 } },
  HOPPIP = { { "LEVEL", "SKIPLOOM", 18 } },
  SKIPLOOM = { { "LEVEL", "JUMPLUFF", 27 } },
  SUNKERN = { { "ITEM", "SUNFLORA", "SUN_STONE" } },
  WOOPER = { { "LEVEL", "QUAGSIRE", 20 } },
  PINECO = { { "LEVEL", "FORRETRESS", 31 } },
  SNUBBULL = { { "LEVEL", "GRANBULL", 23 } },
  TEDDIURSA = { { "LEVEL", "URSARING", 30 } },
  SLUGMA = { { "LEVEL", "MAGCARGO", 38 } },
  SWINUB = { { "LEVEL", "PILOSWINE", 33 } },
  REMORAID = { { "LEVEL", "OCTILLERY", 25 } },
  HOUNDOUR = { { "LEVEL", "HOUNDOOM", 24 } },
  PHANPY = { { "LEVEL", "DONPHAN", 25 } },
  TYROGUE = {
    { "TYROGUE_ATTACK", "HITMONLEE", 20 },
    { "TYROGUE_DEFENSE", "HITMONCHAN", 20 },
    { "TYROGUE_BALANCE", "HITMONTOP", 20 },
  },
  SMOOCHUM = { { "LEVEL", "JYNX", 30 } },
  ELEKID = { { "LEVEL", "ELECTABUZZ", 30 } },
  MAGBY = { { "LEVEL", "MAGMAR", 30 } },
  LARVITAR = { { "LEVEL", "PUPITAR", 30 } },
  PUPITAR = { { "LEVEL", "TYRANITAR", 55 } },
}

-- Branches added to Kanto species.  Item rows are handled at Elm's machine,
-- while friendship rows naturally trigger on level-up.
J.kantoEvolutions = {
  GOLBAT = { { "FRIENDSHIP", "CROBAT" } },
  GLOOM = { { "ITEM", "BELLOSSOM", "SUN_STONE" } },
  POLIWHIRL = { { "ITEM", "POLITOED", "KINGS_ROCK" } },
  EEVEE = {
    { "FRIENDSHIP_DAY", "ESPEON" },
    { "FRIENDSHIP_NIGHT", "UMBREON" },
  },
  SLOWPOKE = { { "ITEM", "SLOWKING", "KINGS_ROCK" } },
  ONIX = { { "ITEM", "STEELIX", "METAL_COAT" } },
  SCYTHER = { { "ITEM", "SCIZOR", "METAL_COAT" } },
  SEADRA = { { "ITEM", "KINGDRA", "DRAGON_SCALE" } },
  PORYGON = { { "ITEM", "PORYGON2", "UPGRADE" } },
  CHANSEY = { { "FRIENDSHIP", "BLISSEY" } },
}

J.items = {
  { id = "SUN_STONE", name = "SUN STONE", de = "SONNENSTEIN" },
  { id = "METAL_COAT", name = "METAL COAT", de = "METALLMANTEL" },
  { id = "KINGS_ROCK", name = "KING'S ROCK", de = "KING-STEIN" },
  { id = "DRAGON_SCALE", name = "DRAGON SCALE", de = "DRACHENHAUT" },
  { id = "UPGRADE", name = "UP-GRADE", de = "UP-GRADE" },
}

J.starters = {
  chikorita = {
    species = "CHIKORITA", map = "CELADON_CITY", name = "VERDANT_GUIDE",
    textId = "KANTO_ASCENDANT_JOHTO_CHIKORITA", sprite = "SPRITE_COOLTRAINER_F",
    preferred = { { 16, 22 }, { 17, 22 }, { 15, 22 } },
    title = { en = "VERDANT TRIAL", de = "PFLANZEN-PRÜFUNG" },
    intro = {
      en = "ERIKA entrusted me\nwith a Johto seed.\fWin three battles and\nCHIKORITA may join you.",
      de = "ERIKA gab mir einen\nSamen aus Johto.\fGewinne drei Kämpfe,\ndann folgt CHIKORITA.",
    },
    opponents = {
      { class = "OPP_BEAUTY", name = "IRIS", team = {
        { species = "TANGELA", level = 58 }, { species = "VILEPLUME", level = 59 },
        { species = "VICTREEBEL", level = 60 },
      } },
      { class = "OPP_COOLTRAINER_F", name = "FERN", team = {
        { species = "EXEGGUTOR", level = 62 }, { species = "VENUSAUR", level = 63 },
        { species = "PARASECT", level = 61 },
      } },
      { class = "OPP_ERIKA", name = "ERIKA", team = {
        { species = "BELLOSSOM", level = 65 }, { species = "JUMPLUFF", level = 65 },
        { species = "MEGANIUM", level = 67 },
      } },
    },
  },
  cyndaquil = {
    species = "CYNDAQUIL", map = "CINNABAR_ISLAND", name = "EMBER_GUIDE",
    textId = "KANTO_ASCENDANT_JOHTO_CYNDAQUIL", sprite = "SPRITE_SCIENTIST",
    preferred = { { 7, 12 }, { 8, 12 }, { 10, 12 } },
    title = { en = "EMBER TRIAL", de = "FEUER-PRÜFUNG" },
    intro = {
      en = "BLAINE found a warm\negg from Johto.\fSurvive three rounds\nto earn CYNDAQUIL.",
      de = "PYRO fand ein warmes\nEi aus Johto.\fBestehe drei Runden\nfür FEURIGEL.",
    },
    opponents = {
      { class = "OPP_BURGLAR", name = "ASH", team = {
        { species = "NINETALES", level = 58 }, { species = "RAPIDASH", level = 59 },
        { species = "MAGMAR", level = 60 },
      } },
      { class = "OPP_SCIENTIST", name = "CINDER", team = {
        { species = "ARCANINE", level = 62 }, { species = "FLAREON", level = 62 },
        { species = "CHARIZARD", level = 63 },
      } },
      { class = "OPP_BLAINE", name = "BLAINE", team = {
        { species = "MAGCARGO", level = 65 }, { species = "HOUNDOOM", level = 65 },
        { species = "TYPHLOSION", level = 67 },
      } },
    },
  },
  totodile = {
    species = "TOTODILE", map = "CERULEAN_CITY", name = "TORRENT_GUIDE",
    textId = "KANTO_ASCENDANT_JOHTO_TOTODILE", sprite = "SPRITE_SWIMMER",
    preferred = { { 16, 20 }, { 17, 20 }, { 15, 20 } },
    title = { en = "TORRENT TRIAL", de = "WASSER-PRÜFUNG" },
    intro = {
      en = "MISTY is guarding a\nwild Johto hatchling.\fClear three waves and\nTOTODILE is yours.",
      de = "MISTY hütet ein wildes\nJunges aus Johto.\fBezwinge drei Wellen\nfür KARNIMANI.",
    },
    opponents = {
      { class = "OPP_SWIMMER", name = "BROOK", team = {
        { species = "GOLDUCK", level = 58 }, { species = "STARMIE", level = 59 },
        { species = "VAPOREON", level = 60 },
      } },
      { class = "OPP_FISHER", name = "DELTA", team = {
        { species = "LAPRAS", level = 62 }, { species = "TENTACRUEL", level = 62 },
        { species = "GYARADOS", level = 63 },
      } },
      { class = "OPP_MISTY", name = "MISTY", team = {
        { species = "LANTURN", level = 65 }, { species = "KINGDRA", level = 65 },
        { species = "FERALIGATR", level = 67 },
      } },
    },
  },
}
J.starterOrder = { "chikorita", "cyndaquil", "totodile" }

local rewardIds = {
  "SENTRET", "HOOTHOOT", "LEDYBA", "SPINARAK", "CHINCHOU", "NATU",
  "MAREEP", "MARILL", "SUDOWOODO", "HOPPIP", "AIPOM", "SUNKERN", "YANMA",
  "WOOPER", "MURKROW", "MISDREAVUS", "UNOWN", "WOBBUFFET", "GIRAFARIG",
  "PINECO", "DUNSPARCE", "GLIGAR", "SNUBBULL", "QWILFISH", "SHUCKLE",
  "HERACROSS", "SNEASEL", "TEDDIURSA", "SLUGMA", "SWINUB", "CORSOLA",
  "REMORAID", "DELIBIRD", "MANTINE", "SKARMORY", "HOUNDOUR", "PHANPY",
  "STANTLER", "SMEARGLE", "MILTANK",
}

local trackForType = {
  BUG = "bug", WATER = "water", FLYING = "sky", ELECTRIC = "tech",
  PSYCHIC_TYPE = "mystic", GHOST = "mystic", ROCK = "stone",
  GROUND = "stone", DARK = "night", FIRE = "night", ICE = "water",
  GRASS = "nature", NORMAL = "nature", FIGHTING = "stone", STEEL = "tech",
}
J.rewards = {}
for _, id in ipairs(rewardIds) do
  local def = J.species[id]
  J.rewards[#J.rewards + 1] = {
    species = id, track = trackForType[def.types[1]] or "nature",
  }
end

J.classTracks = {
  OPP_BUG_CATCHER = "bug", OPP_BIRD_KEEPER = "sky",
  OPP_SWIMMER = "water", OPP_FISHER = "water", OPP_SAILOR = "water",
  OPP_HIKER = "stone", OPP_BLACKBELT = "stone", OPP_TAMER = "stone",
  OPP_PSYCHIC_TR = "mystic", OPP_CHANNELER = "mystic",
  OPP_JUGGLER = "mystic", OPP_UNUSED_JUGGLER = "mystic",
  OPP_SCIENTIST = "tech", OPP_ENGINEER = "tech", OPP_SUPER_NERD = "tech",
  OPP_ROCKER = "tech", OPP_BIKER = "night", OPP_BURGLAR = "night",
  OPP_ROCKET = "night", OPP_GAMBLER = "night", OPP_CUE_BALL = "night",
  OPP_LASS = "nature", OPP_BEAUTY = "nature", OPP_POKEMANIAC = "nature",
  OPP_JR_TRAINER_M = "nature", OPP_JR_TRAINER_F = "nature",
  OPP_COOLTRAINER_M = "nature", OPP_COOLTRAINER_F = "nature",
  OPP_YOUNGSTER = "nature", OPP_GENTLEMAN = "nature",
}

J.eggs = {
  { species = "PICHU", at = 4, steps = 256 },
  { species = "CLEFFA", at = 8, steps = 320 },
  { species = "IGGLYBUFF", at = 12, steps = 320 },
  { species = "TOGEPI", at = 16, steps = 384 },
  { species = "TYROGUE", at = 20, steps = 384 },
  { species = "SMOOCHUM", at = 25, steps = 448 },
  { species = "ELEKID", at = 30, steps = 448 },
  { species = "MAGBY", at = 35, steps = 448 },
}

J.itemMilestones = {
  { at = 3, item = "SUN_STONE" },
  { at = 7, item = "KINGS_ROCK" },
  { at = 11, item = "METAL_COAT" },
  { at = 15, item = "DRAGON_SCALE" },
  { at = 19, item = "UPGRADE" },
  { at = 24, item = "METAL_COAT" },
  { at = 29, item = "KINGS_ROCK" },
  { at = 34, item = "SUN_STONE" },
}

-- Version exclusives and one-off Kanto gifts must not make a Johto evolution
-- impossible.  Elm supplies research partners at fixed specimen milestones;
-- the two Eevee are deliberate so both time branches can coexist.
J.partnerMilestones = {
  { at = 2, species = "GLOOM" },
  { at = 5, species = "POLIWHIRL" },
  { at = 9, species = "EEVEE" },
  { at = 13, species = "SLOWPOKE" },
  { at = 17, species = "ONIX" },
  { at = 21, species = "SCYTHER" },
  { at = 25, species = "SEADRA" },
  { at = 28, species = "PORYGON" },
  { at = 32, species = "EEVEE" },
  { at = 36, species = "GOLBAT" },
  { at = 39, species = "CHANSEY" },
}

J.finalReward = "LARVITAR"

-- Living-Johto habitats.  A row does not alter the encounter table by itself:
-- johto_research.lua only considers it after the corresponding specimen,
-- starter trial or finale has been recorded.  This preserves the deterministic
-- gift as a safety net, while making further copies and shiny hunts part of
-- ordinary exploration.  A two-percent replacement keeps Kanto's native
-- encounter identity intact.
J.habitats = {
  CHIKORITA = { map = "ROUTE_24", terrain = "grass", level = 18, chance = 2,
    unlock = "starter", key = "chikorita" },
  CYNDAQUIL = { map = "POKEMON_MANSION_B1F", terrain = "indoor", level = 22,
    chance = 2, unlock = "starter", key = "cyndaquil" },
  TOTODILE = { map = "SEAFOAM_ISLANDS_B2F", terrain = "indoor", level = 22,
    chance = 2, unlock = "starter", key = "totodile" },
  SENTRET = { map = "ROUTE_1", terrain = "grass", level = 12, chance = 2 },
  HOOTHOOT = { map = "ROUTE_2", terrain = "grass", level = 14, chance = 2 },
  LEDYBA = { map = "VIRIDIAN_FOREST", terrain = "grass", level = 14, chance = 2 },
  SPINARAK = { map = "VIRIDIAN_FOREST", terrain = "grass", level = 15, chance = 2 },
  CHINCHOU = { map = "ROUTE_20", terrain = "water", level = 25, chance = 2 },
  NATU = { map = "ROUTE_22", terrain = "grass", level = 18, chance = 2 },
  MAREEP = { map = "ROUTE_8", terrain = "grass", level = 20, chance = 2 },
  MARILL = { map = "ROUTE_6", terrain = "grass", level = 18, chance = 2 },
  SUDOWOODO = { map = "ROUTE_10", terrain = "grass", level = 24, chance = 2 },
  HOPPIP = { map = "ROUTE_5", terrain = "grass", level = 16, chance = 2 },
  AIPOM = { map = "ROUTE_16", terrain = "grass", level = 24, chance = 2 },
  SUNKERN = { map = "ROUTE_24", terrain = "grass", level = 17, chance = 2 },
  YANMA = { map = "SAFARI_ZONE_CENTER", terrain = "grass", level = 25, chance = 2 },
  WOOPER = { map = "ROUTE_19", terrain = "water", level = 22, chance = 2 },
  MURKROW = { map = "ROUTE_7", terrain = "grass", level = 22, chance = 2 },
  MISDREAVUS = { map = "POKEMON_TOWER_7F", terrain = "indoor", level = 28,
    chance = 2 },
  UNOWN = { map = "MT_MOON_B2F", terrain = "indoor", level = 18, chance = 2 },
  WOBBUFFET = { map = "CERULEAN_CAVE_1F", terrain = "indoor", level = 48,
    chance = 2 },
  GIRAFARIG = { map = "ROUTE_18", terrain = "grass", level = 28, chance = 2 },
  PINECO = { map = "VIRIDIAN_FOREST", terrain = "grass", level = 16, chance = 2 },
  DUNSPARCE = { map = "DIGLETTS_CAVE", terrain = "indoor", level = 22, chance = 2 },
  GLIGAR = { map = "VICTORY_ROAD_1F", terrain = "indoor", level = 38, chance = 2 },
  SNUBBULL = { map = "ROUTE_8", terrain = "grass", level = 21, chance = 2 },
  QWILFISH = { map = "ROUTE_21", terrain = "water", level = 28, chance = 2 },
  SHUCKLE = { map = "MT_MOON_B2F", terrain = "indoor", level = 20, chance = 2 },
  HERACROSS = { map = "ROUTE_15", terrain = "grass", level = 27, chance = 2 },
  SNEASEL = { map = "SEAFOAM_ISLANDS_B4F", terrain = "indoor", level = 32,
    chance = 2 },
  TEDDIURSA = { map = "ROUTE_10", terrain = "grass", level = 24, chance = 2 },
  SLUGMA = { map = "POKEMON_MANSION_B1F", terrain = "indoor", level = 30,
    chance = 2 },
  SWINUB = { map = "SEAFOAM_ISLANDS_B2F", terrain = "indoor", level = 30,
    chance = 2 },
  CORSOLA = { map = "ROUTE_19", terrain = "water", level = 27, chance = 2 },
  REMORAID = { map = "ROUTE_21", terrain = "water", level = 24, chance = 2 },
  DELIBIRD = { map = "SEAFOAM_ISLANDS_B4F", terrain = "indoor", level = 31,
    chance = 2 },
  MANTINE = { map = "ROUTE_20", terrain = "water", level = 30, chance = 2 },
  SKARMORY = { map = "VICTORY_ROAD_2F", terrain = "indoor", level = 40,
    chance = 2 },
  HOUNDOUR = { map = "ROUTE_7", terrain = "grass", level = 23, chance = 2 },
  PHANPY = { map = "ROUTE_11", terrain = "grass", level = 22, chance = 2 },
  STANTLER = { map = "SAFARI_ZONE_EAST", terrain = "grass", level = 27, chance = 2 },
  SMEARGLE = { map = "ROUTE_16", terrain = "grass", level = 25, chance = 2 },
  MILTANK = { map = "SAFARI_ZONE_CENTER", terrain = "grass", level = 28, chance = 2 },
  LARVITAR = { map = "VICTORY_ROAD_3F", terrain = "indoor", level = 45,
    chance = 2, unlock = "final" },
}

-- Resolve every member of a researched family to the base specimen whose
-- progression flag controls it.  Nothing here writes to the Pokédex: knowing
-- that Elm has opened a habitat is distinct from seeing the Pokémon in battle.
J.researchBase = {}
local function recordFamily(base)
  local function visit(id)
    if J.researchBase[id] then return end
    J.researchBase[id] = base
    for _, row in ipairs(J.evolutions[id] or {}) do visit(row[2]) end
  end
  visit(base)
end
for _, key in ipairs(J.starterOrder) do recordFamily(J.starters[key].species) end
for _, row in ipairs(J.rewards) do recordFamily(row.species) end
for _, row in ipairs(J.eggs) do recordFamily(row.species) end
recordFamily(J.finalReward)

J.aide = {
  map = "OAKS_LAB", name = "ELMS_AIDE",
  textId = "KANTO_ASCENDANT_JOHTO_AIDE", sprite = "SPRITE_SCIENTIST",
  preferred = { { 7, 9 }, { 6, 9 }, { 3, 9 } },
}

return J
