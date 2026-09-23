-- Stable, append-only one-time contract IDs. Never renumber released entries.
local D = { version = 1, total = 120, legendaryEggOdds = 10, contracts = {}, legendaryEggPool = {
  "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO", "MEW",
  "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH", "CELEBI",
  "REGIROCK", "REGICE", "REGISTEEL", "LATIAS", "LATIOS", "KYOGRE", "GROUDON", "RAYQUAZA", "JIRACHI", "DEOXYS",
}, eggPool = {
  "BULBASAUR", "CHARMANDER", "SQUIRTLE", "VULPIX", "GROWLITHE", "LAPRAS",
  "EEVEE", "DRATINI", "CHIKORITA", "CYNDAQUIL", "TOTODILE", "MAREEP",
  "HOUNDOUR", "LARVITAR", "TREECKO", "TORCHIC", "MUDKIP", "RALTS", "ARON", "BAGON",
} }
D.contracts[1] = { id = "HC001", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "PIDGEY" } }
D.contracts[2] = { id = "HC002", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "RATTATA" } }
D.contracts[3] = { id = "HC003", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "SPEAROW" } }
D.contracts[4] = { id = "HC004", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "EKANS" } }
D.contracts[5] = { id = "HC005", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "SANDSHREW" } }
D.contracts[6] = { id = "HC006", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "NIDORAN_F" } }
D.contracts[7] = { id = "HC007", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "NIDORAN_M" } }
D.contracts[8] = { id = "HC008", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "VULPIX" } }
D.contracts[9] = { id = "HC009", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "ZUBAT" } }
D.contracts[10] = { id = "HC010", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "ODDISH" } }
D.contracts[11] = { id = "HC011", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "PARAS" } }
D.contracts[12] = { id = "HC012", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "VENONAT" } }
D.contracts[13] = { id = "HC013", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "DIGLETT" } }
D.contracts[14] = { id = "HC014", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "MEOWTH" } }
D.contracts[15] = { id = "HC015", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "PSYDUCK" } }
D.contracts[16] = { id = "HC016", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "MANKEY" } }
D.contracts[17] = { id = "HC017", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "POLIWAG" } }
D.contracts[18] = { id = "HC018", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "MACHOP" } }
D.contracts[19] = { id = "HC019", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "BELLSPROUT" } }
D.contracts[20] = { id = "HC020", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "TENTACOOL" } }
D.contracts[21] = { id = "HC021", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "GEODUDE" } }
D.contracts[22] = { id = "HC022", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "PONYTA" } }
D.contracts[23] = { id = "HC023", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "SLOWPOKE" } }
D.contracts[24] = { id = "HC024", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "MAGNEMITE" } }
D.contracts[25] = { id = "HC025", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "DODUO" } }
D.contracts[26] = { id = "HC026", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "SEEL" } }
D.contracts[27] = { id = "HC027", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "GRIMER" } }
D.contracts[28] = { id = "HC028", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "SHELLDER" } }
D.contracts[29] = { id = "HC029", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "GASTLY" } }
D.contracts[30] = { id = "HC030", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "DROWZEE" } }
D.contracts[31] = { id = "HC031", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "KRABBY" } }
D.contracts[32] = { id = "HC032", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "VOLTORB" } }
D.contracts[33] = { id = "HC033", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "SENTRET" } }
D.contracts[34] = { id = "HC034", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "HOOTHOOT" } }
D.contracts[35] = { id = "HC035", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "LEDYBA" } }
D.contracts[36] = { id = "HC036", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "SPINARAK" } }
D.contracts[37] = { id = "HC037", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "HOPPIP" } }
D.contracts[38] = { id = "HC038", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "WOOPER" } }
D.contracts[39] = { id = "HC039", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "ZIGZAGOON" } }
D.contracts[40] = { id = "HC040", rank = "bronze", level = 30, moveCount = 1, points = 10, species = { "WURMPLE" } }
D.contracts[41] = { id = "HC041", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "BULBASAUR" } }
D.contracts[42] = { id = "HC042", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "CHARMANDER" } }
D.contracts[43] = { id = "HC043", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "SQUIRTLE" } }
D.contracts[44] = { id = "HC044", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "PIKACHU" } }
D.contracts[45] = { id = "HC045", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "CLEFAIRY" } }
D.contracts[46] = { id = "HC046", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "JIGGLYPUFF" } }
D.contracts[47] = { id = "HC047", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "GROWLITHE" } }
D.contracts[48] = { id = "HC048", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "KADABRA" } }
D.contracts[49] = { id = "HC049", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "FARFETCHD" } }
D.contracts[50] = { id = "HC050", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "ONIX" } }
D.contracts[51] = { id = "HC051", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "EXEGGCUTE" } }
D.contracts[52] = { id = "HC052", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "CUBONE" } }
D.contracts[53] = { id = "HC053", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "KOFFING" } }
D.contracts[54] = { id = "HC054", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "RHYHORN" } }
D.contracts[55] = { id = "HC055", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "HORSEA" } }
D.contracts[56] = { id = "HC056", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "GOLDEEN" } }
D.contracts[57] = { id = "HC057", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "STARYU" } }
D.contracts[58] = { id = "HC058", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "CHINCHOU" } }
D.contracts[59] = { id = "HC059", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "NATU" } }
D.contracts[60] = { id = "HC060", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "MAREEP" } }
D.contracts[61] = { id = "HC061", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "MARILL" } }
D.contracts[62] = { id = "HC062", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "SUNKERN" } }
D.contracts[63] = { id = "HC063", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "YANMA" } }
D.contracts[64] = { id = "HC064", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "MURKROW" } }
D.contracts[65] = { id = "HC065", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "MISDREAVUS" } }
D.contracts[66] = { id = "HC066", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "PINECO" } }
D.contracts[67] = { id = "HC067", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "SNUBBULL" } }
D.contracts[68] = { id = "HC068", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "TEDDIURSA" } }
D.contracts[69] = { id = "HC069", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "SLUGMA" } }
D.contracts[70] = { id = "HC070", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "SWINUB" } }
D.contracts[71] = { id = "HC071", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "REMORAID" } }
D.contracts[72] = { id = "HC072", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "POOCHYENA" } }
D.contracts[73] = { id = "HC073", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "LOTAD" } }
D.contracts[74] = { id = "HC074", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "SEEDOT" } }
D.contracts[75] = { id = "HC075", rank = "silver", level = 40, moveCount = 2, points = 20, species = { "TAILLOW" } }
D.contracts[76] = { id = "HC076", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "LICKITUNG", "PIDGEY" } }
D.contracts[77] = { id = "HC077", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "TANGELA", "SANDSHREW" } }
D.contracts[78] = { id = "HC078", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "SLAKOTH", "PSYDUCK" } }
D.contracts[79] = { id = "HC079", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "MUDKIP", "POLIWAG" } }
D.contracts[80] = { id = "HC080", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "PINSIR", "MACHOP" } }
D.contracts[81] = { id = "HC081", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "TAUROS", "PIDGEY" } }
D.contracts[82] = { id = "HC082", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "TORCHIC", "SANDSHREW" } }
D.contracts[83] = { id = "HC083", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "SHROOMISH", "PSYDUCK" } }
D.contracts[84] = { id = "HC084", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "OMANYTE", "POLIWAG" } }
D.contracts[85] = { id = "HC085", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "KABUTO", "MACHOP" } }
D.contracts[86] = { id = "HC086", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "TREECKO", "PIDGEY" } }
D.contracts[87] = { id = "HC087", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "CHIKORITA", "SANDSHREW" } }
D.contracts[88] = { id = "HC088", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "CYNDAQUIL", "PSYDUCK" } }
D.contracts[89] = { id = "HC089", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "TOTODILE", "POLIWAG" } }
D.contracts[90] = { id = "HC090", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "TOGETIC", "MACHOP" } }
D.contracts[91] = { id = "HC091", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "AIPOM", "PIDGEY" } }
D.contracts[92] = { id = "HC092", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "GIRAFARIG", "SANDSHREW" } }
D.contracts[93] = { id = "HC093", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "GLIGAR", "PSYDUCK" } }
D.contracts[94] = { id = "HC094", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "QWILFISH", "POLIWAG" } }
D.contracts[95] = { id = "HC095", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "SHUCKLE", "MACHOP" } }
D.contracts[96] = { id = "HC096", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "NINCADA", "PIDGEY" } }
D.contracts[97] = { id = "HC097", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "SNEASEL", "SANDSHREW" } }
D.contracts[98] = { id = "HC098", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "MANTINE", "PSYDUCK" } }
D.contracts[99] = { id = "HC099", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "WHISMUR", "POLIWAG" } }
D.contracts[100] = { id = "HC100", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "HOUNDOUR", "MACHOP" } }
D.contracts[101] = { id = "HC101", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "PHANPY", "PIDGEY" } }
D.contracts[102] = { id = "HC102", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "STANTLER", "SANDSHREW" } }
D.contracts[103] = { id = "HC103", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "MILTANK", "PSYDUCK" } }
D.contracts[104] = { id = "HC104", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "MAKUHITA", "POLIWAG" } }
D.contracts[105] = { id = "HC105", rank = "gold", level = 50, moveCount = 3, points = 35, species = { "RALTS", "MACHOP" } }
D.contracts[106] = { id = "HC106", rank = "master", level = 60, moveCount = 3, points = 60, species = { "DRATINI", "PIDGEY", "ODDISH" } }
D.contracts[107] = { id = "HC107", rank = "master", level = 60, moveCount = 3, points = 60, species = { "LAPRAS", "SANDSHREW", "PONYTA" } }
D.contracts[108] = { id = "HC108", rank = "master", level = 60, moveCount = 3, points = 60, species = { "SCYTHER", "PSYDUCK", "GASTLY" } }
D.contracts[109] = { id = "HC109", rank = "master", level = 60, moveCount = 3, points = 60, species = { "EEVEE", "POLIWAG", "KRABBY" } }
D.contracts[110] = { id = "HC110", rank = "master", level = 60, moveCount = 3, points = 60, species = { "KANGASKHAN", "MACHOP", "DROWZEE" } }
D.contracts[111] = { id = "HC111", rank = "master", level = 60, moveCount = 3, points = 60, species = { "HERACROSS", "PIDGEY", "ODDISH" } }
D.contracts[112] = { id = "HC112", rank = "master", level = 60, moveCount = 3, points = 60, species = { "SKARMORY", "SANDSHREW", "PONYTA" } }
D.contracts[113] = { id = "HC113", rank = "master", level = 60, moveCount = 3, points = 60, species = { "LARVITAR", "PSYDUCK", "GASTLY" } }
D.contracts[114] = { id = "HC114", rank = "master", level = 60, moveCount = 3, points = 60, species = { "NOSEPASS", "POLIWAG", "KRABBY" } }
D.contracts[115] = { id = "HC115", rank = "master", level = 60, moveCount = 3, points = 60, species = { "SKITTY", "MACHOP", "DROWZEE" } }
D.contracts[116] = { id = "HC116", rank = "master", level = 60, moveCount = 3, points = 60, species = { "ARON", "PIDGEY", "ODDISH" } }
D.contracts[117] = { id = "HC117", rank = "master", level = 60, moveCount = 3, points = 60, species = { "MEDITITE", "SANDSHREW", "PONYTA" } }
D.contracts[118] = { id = "HC118", rank = "master", level = 60, moveCount = 3, points = 60, species = { "ELECTRIKE", "PSYDUCK", "GASTLY" } }
D.contracts[119] = { id = "HC119", rank = "master", level = 60, moveCount = 3, points = 60, species = { "TRAPINCH", "POLIWAG", "KRABBY" } }
D.contracts[120] = { id = "HC120", rank = "master", level = 60, moveCount = 3, points = 60, species = { "BAGON", "MACHOP", "DROWZEE" } }
return D
