-- ROM-free acquisition and data-integrity audit for Kanto Ascendant 5.0.
--
-- The engine's public fixture is deliberately tiny.  seedFixture() expands
-- that fixture with a factual, compact snapshot of Pokemon Red's encounter
-- slots and with schema-correct placeholders for the canonical Kanto roster
-- and for content authorities needed while the complete mod registers.
-- The mod is then loaded normally, so its real patches, Johto registrations
-- and evolution rows are what audit() inspects.

local A = {}

local function words(text)
  local out = {}
  for value in tostring(text):gmatch("%S+") do out[#out + 1] = value end
  return out
end

local KANTO_ORDER = words([[
BULBASAUR IVYSAUR VENUSAUR CHARMANDER CHARMELEON CHARIZARD SQUIRTLE WARTORTLE
BLASTOISE CATERPIE METAPOD BUTTERFREE WEEDLE KAKUNA BEEDRILL PIDGEY
PIDGEOTTO PIDGEOT RATTATA RATICATE SPEAROW FEAROW EKANS ARBOK
PIKACHU RAICHU SANDSHREW SANDSLASH NIDORAN_F NIDORINA NIDOQUEEN NIDORAN_M
NIDORINO NIDOKING CLEFAIRY CLEFABLE VULPIX NINETALES JIGGLYPUFF WIGGLYTUFF
ZUBAT GOLBAT ODDISH GLOOM VILEPLUME PARAS PARASECT VENONAT
VENOMOTH DIGLETT DUGTRIO MEOWTH PERSIAN PSYDUCK GOLDUCK MANKEY
PRIMEAPE GROWLITHE ARCANINE POLIWAG POLIWHIRL POLIWRATH ABRA KADABRA
ALAKAZAM MACHOP MACHOKE MACHAMP BELLSPROUT WEEPINBELL VICTREEBEL TENTACOOL
TENTACRUEL GEODUDE GRAVELER GOLEM PONYTA RAPIDASH SLOWPOKE SLOWBRO
MAGNEMITE MAGNETON FARFETCHD DODUO DODRIO SEEL DEWGONG GRIMER
MUK SHELLDER CLOYSTER GASTLY HAUNTER GENGAR ONIX DROWZEE
HYPNO KRABBY KINGLER VOLTORB ELECTRODE EXEGGCUTE EXEGGUTOR CUBONE
MAROWAK HITMONLEE HITMONCHAN LICKITUNG KOFFING WEEZING RHYHORN RHYDON
CHANSEY TANGELA KANGASKHAN HORSEA SEADRA GOLDEEN SEAKING STARYU
STARMIE MR_MIME SCYTHER JYNX ELECTABUZZ MAGMAR PINSIR TAUROS
MAGIKARP GYARADOS LAPRAS DITTO EEVEE VAPOREON JOLTEON FLAREON
PORYGON OMANYTE OMASTAR KABUTO KABUTOPS AERODACTYL SNORLAX ARTICUNO
ZAPDOS MOLTRES DRATINI DRAGONAIR DRAGONITE MEWTWO MEW
]])

-- Kept independent of johto_data.lua on purpose: a misspelled catalogue ID
-- must not become self-validating merely because both its registration and
-- its consumers repeat the same typo.
local JOHTO_ORDER = words([[
CHIKORITA BAYLEEF MEGANIUM CYNDAQUIL QUILAVA TYPHLOSION TOTODILE CROCONAW
FERALIGATR SENTRET FURRET HOOTHOOT NOCTOWL LEDYBA LEDIAN SPINARAK
ARIADOS CROBAT CHINCHOU LANTURN PICHU CLEFFA IGGLYBUFF TOGEPI
TOGETIC NATU XATU MAREEP FLAAFFY AMPHAROS BELLOSSOM MARILL
AZUMARILL SUDOWOODO POLITOED HOPPIP SKIPLOOM JUMPLUFF AIPOM SUNKERN
SUNFLORA YANMA WOOPER QUAGSIRE ESPEON UMBREON MURKROW SLOWKING
MISDREAVUS UNOWN WOBBUFFET GIRAFARIG PINECO FORRETRESS DUNSPARCE GLIGAR
STEELIX SNUBBULL GRANBULL QWILFISH SCIZOR SHUCKLE HERACROSS SNEASEL
TEDDIURSA URSARING SLUGMA MAGCARGO SWINUB PILOSWINE CORSOLA REMORAID
OCTILLERY DELIBIRD MANTINE SKARMORY HOUNDOUR HOUNDOOM KINGDRA PHANPY
DONPHAN PORYGON2 STANTLER SMEARGLE TYROGUE HITMONTOP SMOOCHUM ELEKID
MAGBY MILTANK BLISSEY RAIKOU ENTEI SUICUNE LARVITAR PUPITAR
TYRANITAR LUGIA HO_OH CELEBI
]])

local NATIONAL_ORDER = {}
for _, id in ipairs(KANTO_ORDER) do NATIONAL_ORDER[#NATIONAL_ORDER + 1] = id end
for _, id in ipairs(JOHTO_ORDER) do NATIONAL_ORDER[#NATIONAL_ORDER + 1] = id end

local KANTO_MOVES = words([[
ABSORB ACID ACID_ARMOR AGILITY AMNESIA AURORA_BEAM BARRAGE BARRIER
BIDE BIND BITE BLIZZARD BODY_SLAM BONEMERANG BONE_CLUB BUBBLE
BUBBLEBEAM CLAMP COMET_PUNCH CONFUSE_RAY CONFUSION CONSTRICT CONVERSION COUNTER
CRABHAMMER CUT DEFENSE_CURL DIG DISABLE DIZZY_PUNCH DOUBLESLAP DOUBLE_EDGE
DOUBLE_KICK DOUBLE_TEAM DRAGON_RAGE DREAM_EATER DRILL_PECK EARTHQUAKE EGG_BOMB EMBER
EXPLOSION FIRE_BLAST FIRE_PUNCH FIRE_SPIN FISSURE FLAMETHROWER FLASH FLY
FOCUS_ENERGY FURY_ATTACK FURY_SWIPES GLARE GROWL GROWTH GUILLOTINE GUST
HARDEN HAZE HEADBUTT HI_JUMP_KICK HORN_ATTACK HORN_DRILL HYDRO_PUMP HYPER_BEAM
HYPER_FANG HYPNOSIS ICE_BEAM ICE_PUNCH JUMP_KICK KARATE_CHOP KINESIS LEECH_LIFE
LEECH_SEED LEER LICK LIGHT_SCREEN LOVELY_KISS LOW_KICK MEDITATE MEGA_DRAIN
MEGA_KICK MEGA_PUNCH METRONOME MIMIC MINIMIZE MIRROR_MOVE MIST NIGHT_SHADE
PAY_DAY PECK PETAL_DANCE PIN_MISSILE POISONPOWDER POISON_GAS POISON_STING POUND
PSYBEAM PSYCHIC_M PSYWAVE QUICK_ATTACK RAGE RAZOR_LEAF RAZOR_WIND RECOVER
REFLECT REST ROAR ROCK_SLIDE ROCK_THROW ROLLING_KICK SAND_ATTACK SCRATCH
SCREECH SEISMIC_TOSS SELFDESTRUCT SHARPEN SING SKULL_BASH SKY_ATTACK SLAM
SLASH SLEEP_POWDER SLUDGE SMOG SMOKESCREEN SOFTBOILED SOLARBEAM SONICBOOM
SPIKE_CANNON SPLASH SPORE STOMP STRENGTH STRING_SHOT STRUGGLE STUN_SPORE
SUBMISSION SUBSTITUTE SUPERSONIC SUPER_FANG SURF SWIFT SWORDS_DANCE TACKLE
TAIL_WHIP TAKE_DOWN TELEPORT THRASH THUNDER THUNDERBOLT THUNDERPUNCH THUNDERSHOCK
THUNDER_WAVE TOXIC TRANSFORM TRI_ATTACK TWINEEDLE VICEGRIP VINE_WHIP WATERFALL
WATER_GUN WHIRLWIND WING_ATTACK WITHDRAW WRAP
]])

-- Exact level/species rows from canonical Pokemon Red's WildDataPointers.
-- Empty encounter headers are intentionally omitted.
local KANTO_WILD_SLOTS = {
  CERULEAN_CAVE_1F = { grass = "46:GOLBAT 46:HYPNO 46:MAGNETON 49:DODRIO 49:VENOMOTH 52:ARBOK 49:KADABRA 52:PARASECT 53:RAICHU 53:DITTO" },
  CERULEAN_CAVE_2F = { grass = "51:DODRIO 51:VENOMOTH 51:KADABRA 52:RHYDON 52:MAROWAK 52:ELECTRODE 56:CHANSEY 54:WIGGLYTUFF 55:DITTO 60:DITTO" },
  CERULEAN_CAVE_B1F = { grass = "55:RHYDON 55:MAROWAK 55:ELECTRODE 64:CHANSEY 64:PARASECT 64:RAICHU 57:ARBOK 65:DITTO 63:DITTO 67:DITTO" },
  DIGLETTS_CAVE = { grass = "18:DIGLETT 19:DIGLETT 17:DIGLETT 20:DIGLETT 16:DIGLETT 15:DIGLETT 21:DIGLETT 22:DIGLETT 29:DUGTRIO 31:DUGTRIO" },
  MT_MOON_1F = { grass = "8:ZUBAT 7:ZUBAT 9:ZUBAT 8:GEODUDE 6:ZUBAT 10:ZUBAT 10:GEODUDE 8:PARAS 11:ZUBAT 8:CLEFAIRY" },
  MT_MOON_B1F = { grass = "8:ZUBAT 7:ZUBAT 7:GEODUDE 8:GEODUDE 9:ZUBAT 10:PARAS 10:ZUBAT 11:ZUBAT 9:CLEFAIRY 9:GEODUDE" },
  MT_MOON_B2F = { grass = "9:ZUBAT 9:GEODUDE 10:ZUBAT 10:GEODUDE 11:ZUBAT 10:PARAS 12:PARAS 10:CLEFAIRY 12:ZUBAT 12:CLEFAIRY" },
  POKEMON_MANSION_1F = { grass = "32:KOFFING 30:KOFFING 34:PONYTA 30:PONYTA 34:GROWLITHE 32:PONYTA 30:GRIMER 28:PONYTA 37:WEEZING 39:MUK" },
  POKEMON_MANSION_2F = { grass = "32:GROWLITHE 34:KOFFING 34:KOFFING 30:PONYTA 30:KOFFING 32:PONYTA 30:GRIMER 28:PONYTA 39:WEEZING 37:MUK" },
  POKEMON_MANSION_3F = { grass = "31:KOFFING 33:GROWLITHE 35:KOFFING 32:PONYTA 34:PONYTA 40:WEEZING 34:GRIMER 38:WEEZING 36:PONYTA 42:MUK" },
  POKEMON_MANSION_B1F = { grass = "33:KOFFING 31:KOFFING 35:GROWLITHE 32:PONYTA 31:KOFFING 40:WEEZING 34:PONYTA 35:GRIMER 42:WEEZING 42:MUK" },
  POKEMON_TOWER_3F = { grass = "20:GASTLY 21:GASTLY 22:GASTLY 23:GASTLY 19:GASTLY 18:GASTLY 24:GASTLY 20:CUBONE 22:CUBONE 25:HAUNTER" },
  POKEMON_TOWER_4F = { grass = "20:GASTLY 21:GASTLY 22:GASTLY 23:GASTLY 19:GASTLY 18:GASTLY 25:HAUNTER 20:CUBONE 22:CUBONE 24:GASTLY" },
  POKEMON_TOWER_5F = { grass = "20:GASTLY 21:GASTLY 22:GASTLY 23:GASTLY 19:GASTLY 18:GASTLY 25:HAUNTER 20:CUBONE 22:CUBONE 24:GASTLY" },
  POKEMON_TOWER_6F = { grass = "21:GASTLY 22:GASTLY 23:GASTLY 24:GASTLY 20:GASTLY 19:GASTLY 26:HAUNTER 22:CUBONE 24:CUBONE 28:HAUNTER" },
  POKEMON_TOWER_7F = { grass = "21:GASTLY 22:GASTLY 23:GASTLY 24:GASTLY 20:GASTLY 28:HAUNTER 22:CUBONE 24:CUBONE 28:HAUNTER 30:HAUNTER" },
  POWER_PLANT = { grass = "21:VOLTORB 21:MAGNEMITE 20:PIKACHU 24:PIKACHU 23:MAGNEMITE 23:VOLTORB 32:MAGNETON 35:MAGNETON 33:ELECTABUZZ 36:ELECTABUZZ" },
  ROCK_TUNNEL_1F = { grass = "16:ZUBAT 17:ZUBAT 17:GEODUDE 15:MACHOP 16:GEODUDE 18:ZUBAT 15:ZUBAT 17:MACHOP 13:ONIX 15:ONIX" },
  ROCK_TUNNEL_B1F = { grass = "16:ZUBAT 17:ZUBAT 17:GEODUDE 15:MACHOP 16:GEODUDE 18:ZUBAT 17:MACHOP 17:ONIX 13:ONIX 18:GEODUDE" },
  ROUTE_1 = { grass = "3:PIDGEY 3:RATTATA 3:RATTATA 2:RATTATA 2:PIDGEY 3:PIDGEY 3:PIDGEY 4:RATTATA 4:PIDGEY 5:PIDGEY" },
  ROUTE_2 = { grass = "3:RATTATA 3:PIDGEY 4:PIDGEY 4:RATTATA 5:PIDGEY 3:WEEDLE 2:RATTATA 5:RATTATA 4:WEEDLE 5:WEEDLE" },
  ROUTE_3 = { grass = "6:PIDGEY 5:SPEAROW 7:PIDGEY 6:SPEAROW 7:SPEAROW 8:PIDGEY 8:SPEAROW 3:JIGGLYPUFF 5:JIGGLYPUFF 7:JIGGLYPUFF" },
  ROUTE_4 = { grass = "10:RATTATA 10:SPEAROW 8:RATTATA 6:EKANS 8:SPEAROW 10:EKANS 12:RATTATA 12:SPEAROW 8:EKANS 12:EKANS" },
  ROUTE_5 = { grass = "13:ODDISH 13:PIDGEY 15:PIDGEY 10:MANKEY 12:MANKEY 15:ODDISH 16:ODDISH 16:PIDGEY 14:MANKEY 16:MANKEY" },
  ROUTE_6 = { grass = "13:ODDISH 13:PIDGEY 15:PIDGEY 10:MANKEY 12:MANKEY 15:ODDISH 16:ODDISH 16:PIDGEY 14:MANKEY 16:MANKEY" },
  ROUTE_7 = { grass = "19:PIDGEY 19:ODDISH 17:MANKEY 22:ODDISH 22:PIDGEY 18:MANKEY 18:GROWLITHE 20:GROWLITHE 19:MANKEY 20:MANKEY" },
  ROUTE_8 = { grass = "18:PIDGEY 18:MANKEY 17:EKANS 16:GROWLITHE 20:PIDGEY 20:MANKEY 19:EKANS 17:GROWLITHE 15:GROWLITHE 18:GROWLITHE" },
  ROUTE_9 = { grass = "16:RATTATA 16:SPEAROW 14:RATTATA 11:EKANS 13:SPEAROW 15:EKANS 17:RATTATA 17:SPEAROW 13:EKANS 17:EKANS" },
  ROUTE_10 = { grass = "16:VOLTORB 16:SPEAROW 14:VOLTORB 11:EKANS 13:SPEAROW 15:EKANS 17:VOLTORB 17:SPEAROW 13:EKANS 17:EKANS" },
  ROUTE_11 = { grass = "14:EKANS 15:SPEAROW 12:EKANS 9:DROWZEE 13:SPEAROW 13:DROWZEE 15:EKANS 17:SPEAROW 11:DROWZEE 15:DROWZEE" },
  ROUTE_12 = { grass = "24:ODDISH 25:PIDGEY 23:PIDGEY 24:VENONAT 22:ODDISH 26:VENONAT 26:ODDISH 27:PIDGEY 28:GLOOM 30:GLOOM" },
  ROUTE_13 = { grass = "24:ODDISH 25:PIDGEY 27:PIDGEY 24:VENONAT 22:ODDISH 26:VENONAT 26:ODDISH 25:DITTO 28:GLOOM 30:GLOOM" },
  ROUTE_14 = { grass = "24:ODDISH 26:PIDGEY 23:DITTO 24:VENONAT 22:ODDISH 26:VENONAT 26:ODDISH 30:GLOOM 28:PIDGEOTTO 30:PIDGEOTTO" },
  ROUTE_15 = { grass = "24:ODDISH 26:DITTO 23:PIDGEY 26:VENONAT 22:ODDISH 28:VENONAT 26:ODDISH 30:GLOOM 28:PIDGEOTTO 30:PIDGEOTTO" },
  ROUTE_16 = { grass = "20:SPEAROW 22:SPEAROW 18:RATTATA 20:DODUO 20:RATTATA 18:DODUO 22:DODUO 22:RATTATA 23:RATICATE 25:RATICATE" },
  ROUTE_17 = { grass = "20:SPEAROW 22:SPEAROW 25:RATICATE 24:DODUO 27:RATICATE 26:DODUO 28:DODUO 29:RATICATE 25:FEAROW 27:FEAROW" },
  ROUTE_18 = { grass = "20:SPEAROW 22:SPEAROW 25:RATICATE 24:DODUO 25:FEAROW 26:DODUO 28:DODUO 29:RATICATE 27:FEAROW 29:FEAROW" },
  ROUTE_19 = { water = "5:TENTACOOL 10:TENTACOOL 15:TENTACOOL 5:TENTACOOL 10:TENTACOOL 15:TENTACOOL 20:TENTACOOL 30:TENTACOOL 35:TENTACOOL 40:TENTACOOL" },
  ROUTE_20 = { water = "5:TENTACOOL 10:TENTACOOL 15:TENTACOOL 5:TENTACOOL 10:TENTACOOL 15:TENTACOOL 20:TENTACOOL 30:TENTACOOL 35:TENTACOOL 40:TENTACOOL" },
  ROUTE_21 = { grass = "21:RATTATA 23:PIDGEY 30:RATICATE 23:RATTATA 21:PIDGEY 30:PIDGEOTTO 32:PIDGEOTTO 28:TANGELA 30:TANGELA 32:TANGELA", water = "5:TENTACOOL 10:TENTACOOL 15:TENTACOOL 5:TENTACOOL 10:TENTACOOL 15:TENTACOOL 20:TENTACOOL 30:TENTACOOL 35:TENTACOOL 40:TENTACOOL" },
  ROUTE_22 = { grass = "3:RATTATA 3:NIDORAN_M 4:RATTATA 4:NIDORAN_M 2:RATTATA 2:NIDORAN_M 3:SPEAROW 5:SPEAROW 3:NIDORAN_F 4:NIDORAN_F" },
  ROUTE_23 = { grass = "26:EKANS 33:DITTO 26:SPEAROW 38:FEAROW 38:DITTO 38:FEAROW 41:ARBOK 43:DITTO 41:FEAROW 43:FEAROW" },
  ROUTE_24 = { grass = "7:WEEDLE 8:KAKUNA 12:PIDGEY 12:ODDISH 13:ODDISH 10:ABRA 14:ODDISH 13:PIDGEY 8:ABRA 12:ABRA" },
  ROUTE_25 = { grass = "8:WEEDLE 9:KAKUNA 13:PIDGEY 12:ODDISH 13:ODDISH 12:ABRA 14:ODDISH 10:ABRA 7:METAPOD 8:CATERPIE" },
  SAFARI_ZONE_CENTER = { grass = "22:NIDORAN_M 25:RHYHORN 22:VENONAT 24:EXEGGCUTE 31:NIDORINO 25:EXEGGCUTE 31:NIDORINA 30:PARASECT 23:SCYTHER 23:CHANSEY" },
  SAFARI_ZONE_EAST = { grass = "24:NIDORAN_M 26:DODUO 22:PARAS 25:EXEGGCUTE 33:NIDORINO 23:EXEGGCUTE 24:NIDORAN_F 25:PARASECT 25:KANGASKHAN 28:SCYTHER" },
  SAFARI_ZONE_NORTH = { grass = "22:NIDORAN_M 26:RHYHORN 23:PARAS 25:EXEGGCUTE 30:NIDORINO 27:EXEGGCUTE 30:NIDORINA 32:VENOMOTH 26:CHANSEY 28:TAUROS" },
  SAFARI_ZONE_WEST = { grass = "25:NIDORAN_M 26:DODUO 23:VENONAT 24:EXEGGCUTE 33:NIDORINO 26:EXEGGCUTE 25:NIDORAN_F 31:VENOMOTH 26:TAUROS 28:KANGASKHAN" },
  SEAFOAM_ISLANDS_1F = { grass = "30:SEEL 30:SLOWPOKE 30:SHELLDER 30:HORSEA 28:HORSEA 21:ZUBAT 29:GOLBAT 28:PSYDUCK 28:SHELLDER 38:GOLDUCK" },
  SEAFOAM_ISLANDS_B1F = { grass = "30:STARYU 30:HORSEA 32:SHELLDER 32:HORSEA 28:SLOWPOKE 30:SEEL 30:SLOWPOKE 28:SEEL 38:DEWGONG 37:SEADRA" },
  SEAFOAM_ISLANDS_B2F = { grass = "30:SEEL 30:SLOWPOKE 32:SEEL 32:SLOWPOKE 28:HORSEA 30:STARYU 30:HORSEA 28:SHELLDER 30:GOLBAT 37:SLOWBRO" },
  SEAFOAM_ISLANDS_B3F = { grass = "31:SLOWPOKE 31:SEEL 33:SLOWPOKE 33:SEEL 29:HORSEA 31:SHELLDER 31:HORSEA 29:SHELLDER 39:SEADRA 37:DEWGONG" },
  SEAFOAM_ISLANDS_B4F = { grass = "31:HORSEA 31:SHELLDER 33:HORSEA 33:SHELLDER 29:SLOWPOKE 31:SEEL 31:SLOWPOKE 29:SEEL 39:SLOWBRO 32:GOLBAT" },
  VICTORY_ROAD_1F = { grass = "24:MACHOP 26:GEODUDE 22:ZUBAT 36:ONIX 39:ONIX 42:ONIX 41:GRAVELER 41:GOLBAT 42:MACHOKE 43:MAROWAK" },
  VICTORY_ROAD_2F = { grass = "22:MACHOP 24:GEODUDE 26:ZUBAT 36:ONIX 39:ONIX 42:ONIX 41:MACHOKE 40:GOLBAT 40:MAROWAK 43:GRAVELER" },
  VICTORY_ROAD_3F = { grass = "24:MACHOP 26:GEODUDE 22:ZUBAT 42:ONIX 40:VENOMOTH 45:ONIX 43:GRAVELER 41:GOLBAT 42:MACHOKE 45:MACHOKE" },
  VIRIDIAN_FOREST = { grass = "4:WEEDLE 5:KAKUNA 3:WEEDLE 5:WEEDLE 4:KAKUNA 6:KAKUNA 4:METAPOD 3:CATERPIE 3:PIKACHU 5:PIKACHU" },
}

local KANTO_EVOLUTIONS = {
  { "BULBASAUR", "IVYSAUR", "LEVEL", 16 }, { "IVYSAUR", "VENUSAUR", "LEVEL", 32 },
  { "CHARMANDER", "CHARMELEON", "LEVEL", 16 }, { "CHARMELEON", "CHARIZARD", "LEVEL", 36 },
  { "SQUIRTLE", "WARTORTLE", "LEVEL", 16 }, { "WARTORTLE", "BLASTOISE", "LEVEL", 36 },
  { "CATERPIE", "METAPOD", "LEVEL", 7 }, { "METAPOD", "BUTTERFREE", "LEVEL", 10 },
  { "WEEDLE", "KAKUNA", "LEVEL", 7 }, { "KAKUNA", "BEEDRILL", "LEVEL", 10 },
  { "PIDGEY", "PIDGEOTTO", "LEVEL", 18 }, { "PIDGEOTTO", "PIDGEOT", "LEVEL", 36 },
  { "RATTATA", "RATICATE", "LEVEL", 20 }, { "SPEAROW", "FEAROW", "LEVEL", 20 },
  { "EKANS", "ARBOK", "LEVEL", 22 }, { "PIKACHU", "RAICHU", "ITEM", "THUNDER_STONE" },
  { "SANDSHREW", "SANDSLASH", "LEVEL", 22 }, { "NIDORAN_F", "NIDORINA", "LEVEL", 16 },
  { "NIDORINA", "NIDOQUEEN", "ITEM", "MOON_STONE" }, { "NIDORAN_M", "NIDORINO", "LEVEL", 16 },
  { "NIDORINO", "NIDOKING", "ITEM", "MOON_STONE" }, { "CLEFAIRY", "CLEFABLE", "ITEM", "MOON_STONE" },
  { "VULPIX", "NINETALES", "ITEM", "FIRE_STONE" }, { "JIGGLYPUFF", "WIGGLYTUFF", "ITEM", "MOON_STONE" },
  { "ZUBAT", "GOLBAT", "LEVEL", 22 }, { "ODDISH", "GLOOM", "LEVEL", 21 },
  { "GLOOM", "VILEPLUME", "ITEM", "LEAF_STONE" }, { "PARAS", "PARASECT", "LEVEL", 24 },
  { "VENONAT", "VENOMOTH", "LEVEL", 31 }, { "DIGLETT", "DUGTRIO", "LEVEL", 26 },
  { "MEOWTH", "PERSIAN", "LEVEL", 28 }, { "PSYDUCK", "GOLDUCK", "LEVEL", 33 },
  { "MANKEY", "PRIMEAPE", "LEVEL", 28 }, { "GROWLITHE", "ARCANINE", "ITEM", "FIRE_STONE" },
  { "POLIWAG", "POLIWHIRL", "LEVEL", 25 }, { "POLIWHIRL", "POLIWRATH", "ITEM", "WATER_STONE" },
  { "ABRA", "KADABRA", "LEVEL", 16 }, { "KADABRA", "ALAKAZAM", "TRADE" },
  { "MACHOP", "MACHOKE", "LEVEL", 28 }, { "MACHOKE", "MACHAMP", "TRADE" },
  { "BELLSPROUT", "WEEPINBELL", "LEVEL", 21 }, { "WEEPINBELL", "VICTREEBEL", "ITEM", "LEAF_STONE" },
  { "TENTACOOL", "TENTACRUEL", "LEVEL", 30 }, { "GEODUDE", "GRAVELER", "LEVEL", 25 },
  { "GRAVELER", "GOLEM", "TRADE" }, { "PONYTA", "RAPIDASH", "LEVEL", 40 },
  { "SLOWPOKE", "SLOWBRO", "LEVEL", 37 }, { "MAGNEMITE", "MAGNETON", "LEVEL", 30 },
  { "DODUO", "DODRIO", "LEVEL", 31 }, { "SEEL", "DEWGONG", "LEVEL", 34 },
  { "GRIMER", "MUK", "LEVEL", 38 }, { "SHELLDER", "CLOYSTER", "ITEM", "WATER_STONE" },
  { "GASTLY", "HAUNTER", "LEVEL", 25 }, { "HAUNTER", "GENGAR", "TRADE" },
  { "DROWZEE", "HYPNO", "LEVEL", 26 }, { "KRABBY", "KINGLER", "LEVEL", 28 },
  { "VOLTORB", "ELECTRODE", "LEVEL", 30 }, { "EXEGGCUTE", "EXEGGUTOR", "ITEM", "LEAF_STONE" },
  { "CUBONE", "MAROWAK", "LEVEL", 28 }, { "KOFFING", "WEEZING", "LEVEL", 35 },
  { "RHYHORN", "RHYDON", "LEVEL", 42 }, { "HORSEA", "SEADRA", "LEVEL", 32 },
  { "GOLDEEN", "SEAKING", "LEVEL", 33 }, { "STARYU", "STARMIE", "ITEM", "WATER_STONE" },
  { "MAGIKARP", "GYARADOS", "LEVEL", 20 },
  { "EEVEE", "VAPOREON", "ITEM", "WATER_STONE" }, { "EEVEE", "JOLTEON", "ITEM", "THUNDER_STONE" },
  { "EEVEE", "FLAREON", "ITEM", "FIRE_STONE" }, { "OMANYTE", "OMASTAR", "LEVEL", 40 },
  { "KABUTO", "KABUTOPS", "LEVEL", 40 }, { "DRATINI", "DRAGONAIR", "LEVEL", 30 },
  { "DRAGONAIR", "DRAGONITE", "LEVEL", 55 },
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[key] = copy(child) end
  return out
end

local function parseSlots(encoded)
  local slots = {}
  for token in encoded:gmatch("%S+") do
    local level, species = token:match("^(%d+):(.+)$")
    slots[#slots + 1] = { level = tonumber(level), species = species }
  end
  return slots
end

local function uniformTileset(id, count, tile)
  local blocks = {}
  for block = 1, count do
    local row = {}
    for cell = 1, 16 do row[cell] = tile end
    blocks[block] = row
  end
  return {
    id = id,
    image = "tests/fixture_data/assets/fix_out.png",
    blocks = blocks,
    walkable = {},
    counterTiles = {}, doorTiles = {}, warpTiles = {}, grassTile = nil,
  }
end

local function contentTilesetFixtures()
  -- Reachability never renders or audits maps, but the normal mod load must
  -- still exercise every registration path.  These deliberately synthetic
  -- authorities match only the native table shapes and collision contracts
  -- that registration checks.  The real-data Workshop/Hidden-Evolution
  -- suites remain authoritative for native block composition and rendering.
  local facility = uniformTileset("FACILITY", 128, 1)
  facility.walkable = { 1, 17 }

  local cavern = uniformTileset("CAVERN", 128, 0)

  local forest = uniformTileset("FOREST", 100, 0)
  forest.walkable = { 1, 58 }
  local collisionIndexes = { 5, 7, 13, 15 }
  local function collision(blockId, cells)
    local row = forest.blocks[blockId + 1]
    for index, tileId in ipairs(cells) do
      row[collisionIndexes[index]] = tileId
    end
  end
  for _, blockId in ipairs({ 27, 46, 47 }) do
    collision(blockId, { 1, 1, 1, 1 })
  end
  for blockId, mask in pairs({
    [77] = 1, [76] = 2, [53] = 3, [73] = 4, [59] = 5, [52] = 7,
    [72] = 8, [55] = 10, [54] = 11, [57] = 12, [56] = 13,
    [58] = 14,
  }) do
    local cells = {}
    for bit = 0, 3 do
      cells[bit + 1] = math.floor(mask / (2 ^ bit)) % 2 == 1 and 1 or 0
    end
    collision(blockId, cells)
  end
  collision(45, { 20, 20, 20, 20 })
  collision(25, { 0, 0, 0, 58 })
  forest.warpTiles = { 58 }

  return {
    FACILITY = facility,
    CAVERN = cavern,
    FOREST = forest,
    GYM = uniformTileset("GYM", 128, 0),
    CEMETERY = uniformTileset("CEMETERY", 128, 0),
  }
end

function A.seedFixture(data)
  assert(type(data) == "table", "fixture data table required")
  data.pokemon = data.pokemon or {}
  data.moves = data.moves or {}
  data.items = data.items or {}
  data.audio = data.audio or {}
  data.audio.songs = data.audio.songs or {}
  data.audio.mapSongs = data.audio.mapSongs or {}
  data.audio.songs.Music_Celadon = data.audio.songs.Music_Celadon
    or { address = 0, bank = 0 }
  data.tilesets = data.tilesets or {}
  for id, fixture in pairs(contentTilesetFixtures()) do
    data.tilesets[id] = data.tilesets[id] or fixture
  end

  -- Keep the fixture-only species available to any preloaded fixture
  -- trainer rows, but move them outside the audited national-dex namespace.
  -- They deliberately use dex 1-3 in Modkit's tiny stock fixture.
  for id, def in pairs(data.pokemon) do
    if tostring(id):match("^FIXMON_") then def.dex = nil end
  end

  local evolutions = {}
  for _, row in ipairs(KANTO_EVOLUTIONS) do
    local edge = { species = row[2], method = row[3] }
    if row[3] == "LEVEL" then edge.level = row[4]
    elseif row[3] == "ITEM" then edge.item = row[4] end
    evolutions[row[1]] = evolutions[row[1]] or {}
    evolutions[row[1]][#evolutions[row[1]] + 1] = edge
  end
  for dex, id in ipairs(KANTO_ORDER) do
    data.pokemon[id] = {
      id = id, index = dex, dex = dex, name = id,
      types = { "NORMAL" },
      baseStats = { hp = 60, attack = 60, defense = 60, speed = 60, special = 60 },
      catchRate = 120, baseExp = 100, growthRate = "MEDIUM_FAST",
      level1Moves = { "TACKLE" }, learnset = {}, tmhm = {},
      evolutions = copy(evolutions[id] or {}),
      spriteFront = "tests/fixture_data/assets/fixmon_a_front.png",
      spriteBack = "tests/fixture_data/assets/fixmon_a_back.png",
      frontSize = 5,
      dexEntry = { kind = "AUDIT", heightFt = 1, heightIn = 0,
        weight = 100, text = "Reachability fixture." },
    }
  end
  for index, id in ipairs(KANTO_MOVES) do
    data.moves[id] = {
      id = id, index = index, name = id, type = "NORMAL", power = 40,
      accuracy = 100, pp = 35, effect = "NO_ADDITIONAL_EFFECT",
    }
  end
  for _, id in ipairs({
    "MOON_STONE", "FIRE_STONE", "WATER_STONE", "THUNDER_STONE",
    "LEAF_STONE",
  }) do
    data.items[id] = data.items[id] or {
      id = id, name = id:gsub("_", " "), price = 0,
    }
  end
  data.encounters = {}
  for mapId, terrains in pairs(KANTO_WILD_SLOTS) do
    local encounter = { source = "ROM-free canonical Red snapshot" }
    for terrain, encoded in pairs(terrains) do
      encounter[terrain] = { rate = 10, slots = parseSlots(encoded) }
    end
    data.encounters[mapId] = encounter
  end
  return data
end

local KANTO_SPECIAL = {
  { "BULBASAUR", "Master Erika reward" },
  { "SQUIRTLE", "Master Misty reward" },
  { "CHARMANDER", "Master Blaine reward" },
  { "OMANYTE", "Helix Fossil revival / Master Brock recovery" },
  { "KABUTO", "Dome Fossil revival / Master Brock recovery" },
  { "AERODACTYL", "Old Amber revival" },
  { "EEVEE", "Route 7 post-League encounter (2%)" },
  { "FARFETCHD", "Vermilion in-game trade" },
  { "MR_MIME", "Route 2 in-game trade" },
  { "JYNX", "Cerulean in-game trade" },
  { "LICKITUNG", "Route 18 in-game trade" },
  { "HITMONLEE", "Fighting Dojo gift choice / Victory Road slot" },
  { "HITMONCHAN", "Fighting Dojo gift choice / Victory Road slot" },
  { "LAPRAS", "Silph Co. gift" },
  { "PORYGON", "Celadon Game Corner prize" },
  { "SNORLAX", "Poké Flute static encounter" },
  { "POLIWAG", "Good Rod encounter table" },
  { "KRABBY", "Super Rod encounter table" },
  { "GOLDEEN", "Good Rod encounter table" },
  { "MAGIKARP", "Old Rod encounter table" },
  { "DRATINI", "Safari Zone Super Rod encounter table" },
}

local KANTO_STONES = {
  MOON_STONE = true, FIRE_STONE = true, WATER_STONE = true,
  THUNDER_STONE = true, LEAF_STONE = true,
}

local function sortedKeys(set)
  local out = {}
  for key in pairs(set or {}) do out[#out + 1] = key end
  table.sort(out)
  return out
end

local function addError(report, text)
  report.errors[#report.errors + 1] = text
end

function A.audit(data, exports, extraData)
  local report = {
    errors = {}, reachable = {}, sources = {}, edges = {},
    wildSlots = 0, habitatRows = 0,
  }
  local johto = assert(exports.johtoData, "johtoData export required")
  local postgame = assert(exports.postgameData, "postgameData export required")

  local byDex, validSpecies = {}, {}
  for dex, id in ipairs(NATIONAL_ORDER) do
    byDex[dex], validSpecies[id] = id, true
    local def = data.pokemon and data.pokemon[id]
    if not def then
      addError(report, ("Dex #%03d canonical species %s is not registered")
        :format(dex, id))
    elseif tonumber(def.dex) ~= dex then
      addError(report, ("Canonical species %s has Dex %s, expected #%03d")
        :format(id, tostring(def.dex), dex))
    end
  end
  local guestSpecies = {}
  local gorochu = exports.gorochu
  if gorochu and gorochu.available then
    local id = gorochu.id or "GOROCHU"
    if data.pokemon and data.pokemon[id] then
      validSpecies[id] = true
      guestSpecies[#guestSpecies + 1] = id
    else
      addError(report, "Registered Gorochu controller has no species data")
    end
  end
  local hevo = exports.hevoSpecies
  if hevo and hevo.enabled then
    for index, id in ipairs(hevo.order or {}) do
      local def = data.pokemon and data.pokemon[id]
      if not def then
        addError(report, "HEVO catalogue species is not registered: " .. id)
      else
        validSpecies[id] = true
        local expectedDex = index + 260
        if tonumber(def.dex) ~= expectedDex then
          addError(report, ("HEVO species %s has Dex %s, expected #%03d")
            :format(id, tostring(def.dex), expectedDex))
        end
      end
    end
  end
  for id, def in pairs(data.pokemon or {}) do
    local dex = tonumber(def.dex)
    if dex and dex >= 1 and dex <= 251 then
      if not validSpecies[id] then
        addError(report, ("Unknown registered species %s occupies Dex #%03d")
          :format(id, dex))
      elseif byDex[dex] ~= id then
        addError(report, ("Dex #%03d belongs to %s, but %s also claims it")
          :format(dex, byDex[dex], id))
      end
    end
  end
  local validMoves = {}
  for id in pairs(data.moves or {}) do validMoves[id] = true end

  local function source(species, label)
    if not validSpecies[species] then
      addError(report, ("Unknown species source %s at %s")
        :format(tostring(species), label))
      return
    end
    report.sources[species] = report.sources[species] or {}
    report.sources[species][#report.sources[species] + 1] = label
  end

  for index, id in ipairs(johto.order or {}) do
    local expected = JOHTO_ORDER[index]
    if id ~= expected then
      addError(report, ("Johto order #%03d is %s, expected %s")
        :format(index + 151, tostring(id), tostring(expected)))
    end
  end
  if #(johto.order or {}) ~= #JOHTO_ORDER then
    addError(report, ("Johto order has %d entries, expected %d")
      :format(#(johto.order or {}), #JOHTO_ORDER))
  end
  for id in pairs(johto.species or {}) do
    if not validSpecies[id] then
      addError(report, "Unknown Johto catalogue species key " .. tostring(id))
    end
  end
  for id in pairs(postgame.species or {}) do
    if not validSpecies[id] then
      addError(report, "Unknown postgame species key " .. tostring(id))
    end
  end
  for index, id in ipairs(postgame.legendOrder or {}) do
    if not validSpecies[id] then
      addError(report, ("Unknown legendOrder species %s at index %d")
        :format(tostring(id), index))
    end
  end

  for mapId, encounter in pairs(data.encounters or {}) do
    for terrain, rows in pairs(encounter) do
      if type(rows) == "table" and type(rows.slots) == "table" then
        for slot, row in ipairs(rows.slots) do
          report.wildSlots = report.wildSlots + 1
          source(row.species, ("wild %s/%s slot %d (Lv%d)")
            :format(mapId, terrain, slot, tonumber(row.level) or 0))
        end
      end
    end
  end
  for _, row in ipairs(KANTO_SPECIAL) do source(row[1], row[2]) end

  for key, row in pairs(johto.starters or {}) do
    source(row.species, "Johto starter trial " .. key)
  end
  for index, row in ipairs(johto.rewards or {}) do
    source(row.species, ("Johto rematch research reward %d (%s track)")
      :format(index, tostring(row.track)))
  end
  for _, row in ipairs(johto.eggs or {}) do
    source(row.species, ("Elm research egg at %d specimens"):format(row.at))
  end
  for _, row in ipairs(johto.partnerMilestones or {}) do
    source(row.species, ("Elm research partner at %d specimens"):format(row.at))
  end
  source(johto.finalReward, "Johto research finale")
  for species, row in pairs(johto.habitats or {}) do
    report.habitatRows = report.habitatRows + 1
    if not validSpecies[species] then
      addError(report, "Unknown Living-Johto habitat species " .. species)
    end
    if type(row.map) ~= "string" or type(row.terrain) ~= "string" then
      addError(report, "Incomplete habitat route for " .. species)
    end
  end

  for species, row in pairs(postgame.staticLegends or {}) do
    source(species, "static legend event at " .. tostring(row.map))
  end
  for species in pairs(postgame.roamers or {}) do
    source(species, "roaming legendary event")
  end
  for species, row in pairs(postgame.spawnedLegends or {}) do
    source(species, "spawned legend event at " .. tostring(row.map))
  end
  for _, profile in ipairs((exports.eventData or {}).profiles or {}) do
    if profile.species == "MEW" then
      source(profile.species, "Kanto Heritage Mew event")
    end
  end

  local incoming = {}
  for from, def in pairs(data.pokemon or {}) do
    if validSpecies[from] then
      for _, evo in ipairs(def.evolutions or {}) do
        local edge = {
          from = from, to = evo.species, method = evo.method,
          item = evo.item, level = evo.level,
        }
        report.edges[#report.edges + 1] = edge
        incoming[edge.to] = incoming[edge.to] or {}
        incoming[edge.to][#incoming[edge.to] + 1] = edge
        if not validSpecies[edge.to] then
          addError(report, ("Unknown evolution target %s from %s")
            :format(tostring(edge.to), from))
        end
      end
    end
  end

  local johtoItems = {}
  for _, row in ipairs(johto.items or {}) do johtoItems[row.id] = true end
  local requiredJohtoItems = {}
  for _, edge in ipairs(report.edges) do
    if edge.method == "ITEM" and johtoItems[edge.item] then
      requiredJohtoItems[edge.item] = true
    end
  end
  local exchangeItems = {}
  local exchange = exports.frontierExchange
  for _, row in ipairs(exchange and exchange.itemPrices or {}) do
    exchangeItems[row.id] = row
  end
  local milestoneItems = {}
  for _, row in ipairs(johto.itemMilestones or {}) do
    milestoneItems[row.item] = math.min(milestoneItems[row.item] or math.huge,
      tonumber(row.at) or math.huge)
  end
  local renewable = copy(KANTO_STONES)
  for item in pairs(requiredJohtoItems) do
    local sold, unlock = exchangeItems[item], milestoneItems[item]
    if not sold then
      addError(report, item .. " is consumed by an evolution but absent from Frontier Exchange")
    elseif not unlock then
      addError(report, item .. " is sold but has no Elm unlock milestone")
    elseif sold.milestone ~= unlock then
      addError(report, ("%s unlock mismatch: Exchange %s, Elm %s")
        :format(item, tostring(sold.milestone), tostring(unlock)))
    else
      renewable[item] = true
    end
  end
  -- Gorochu's Tear is not a shop-renewable Johto item. It has its own
  -- guarded acquisition route: Lt. Surge grants the permanent Heart and
  -- the remote Power Plant condenser generates/reissues a Tear until the
  -- one permanent Gorochu evolution succeeds.
  local availableEvolutionItems = copy(renewable)
  if gorochu and gorochu.available then
    local heart = gorochu.heartItemId
    local tear = gorochu.tearItemId
    if not (heart and data.items and data.items[heart]) then
      addError(report, "Gorochu Heart of Thunder is not registered")
    elseif not (tear and data.items and data.items[tear]) then
      addError(report, "Gorochu Tear of Thunder is not registered")
    else
      availableEvolutionItems[tear] = true
    end
  end

  local queue = {}
  for species, rows in pairs(report.sources) do
    report.reachable[species] = { source = rows[1] }
    queue[#queue + 1] = species
  end
  local head = 1
  while head <= #queue do
    local from = queue[head]
    head = head + 1
    for _, edge in ipairs(report.edges) do
      local allowed = edge.from == from
      if allowed and edge.method == "ITEM" then
        allowed = availableEvolutionItems[edge.item] == true
      end
      if allowed and edge.method == "TRADE" then allowed = false end
      if allowed and validSpecies[edge.to] and not report.reachable[edge.to] then
        local detail = edge.method
        if edge.item then detail = detail .. " " .. edge.item end
        if edge.level then detail = detail .. " Lv" .. edge.level end
        report.reachable[edge.to] = { from = from, via = detail }
        queue[#queue + 1] = edge.to
      end
    end
  end

  for dex = 1, 251 do
    local species = byDex[dex]
    if species and not report.reachable[species] then
      local reasons = {}
      for _, edge in ipairs(incoming[species] or {}) do
        local why
        if edge.method == "ITEM" and not availableEvolutionItems[edge.item] then
          why = "requires non-renewable " .. tostring(edge.item)
        elseif edge.method == "TRADE" then
          why = "still requires trade"
        elseif not report.reachable[edge.from] then
          why = "precursor " .. edge.from .. " is unreachable"
        else
          why = "edge is unavailable"
        end
        reasons[#reasons + 1] = edge.from .. " -> " .. species .. " (" .. why .. ")"
      end
      if #reasons == 0 then reasons[1] = "no direct source and no incoming evolution" end
      addError(report, ("Dex #%03d %s unreachable: %s")
        :format(dex, species, table.concat(reasons, "; ")))
    end
  end

  local function validateData(value, path, parentKey, seen)
    if type(value) ~= "table" then return end
    seen = seen or {}
    if seen[value] then return end
    seen[value] = true
    for key, child in pairs(value) do
      local childPath = path .. "." .. tostring(key)
      if key == "species" and type(child) == "string" then
        if not validSpecies[child] then
          addError(report, "Unknown species ID " .. child .. " at " .. childPath)
        end
      elseif key == "move" and type(child) == "string" then
        if not validMoves[child] then
          addError(report, "Unknown move ID " .. child .. " at " .. childPath)
        end
      elseif (key == "moves" or key == "level1" or key == "level1Moves"
          or key == "tmhm") and type(child) == "table" then
        for index, move in ipairs(child) do
          if type(move) == "string" and not validMoves[move] then
            addError(report, ("Unknown move ID %s at %s[%d]")
              :format(move, childPath, index))
          end
        end
      end
      validateData(child, childPath, key, seen)
    end
  end

  local dataSets = {
    postgame = exports.postgameData,
    johto = exports.johtoData,
    ascendant = exports.ascendantData,
    johto_masters = exports.johtoMastersData,
    events = exports.eventData,
  }
  for name, value in pairs(extraData or {}) do dataSets[name] = value end
  for name, value in pairs(dataSets) do
    if value then validateData(value, name) end
  end

  local reachableCount = 0
  for dex = 1, 251 do
    if byDex[dex] and report.reachable[byDex[dex]] then
      reachableCount = reachableCount + 1
    end
  end
  report.reachableCount = reachableCount
  report.guestReachable = {}
  for _, species in ipairs(guestSpecies) do
    if report.reachable[species] then
      report.guestReachable[#report.guestReachable + 1] = species
    else
      addError(report,
        species .. " guest evolution has no acquisition path")
    end
  end
  report.speciesByDex = byDex
  report.requiredJohtoItems = sortedKeys(requiredJohtoItems)
  report.renewableJohtoItems = {}
  for _, item in ipairs(report.requiredJohtoItems) do
    if renewable[item] then
      report.renewableJohtoItems[#report.renewableJohtoItems + 1] = item
    end
  end
  report.ok = #report.errors == 0
  return report
end

function A.format(report)
  local lines = {
    ("Reachability: %d/251 species"):format(report.reachableCount or 0),
    ("Encounter graph: %d real slots, %d evolution edges, %d Living-Johto habitats")
      :format(report.wildSlots or 0, #(report.edges or {}), report.habitatRows or 0),
    "Guest evolutions reachable: "
      .. (#(report.guestReachable or {}) > 0
        and table.concat(report.guestReachable, ", ") or "none"),
    "Renewable Johto evolution items: "
      .. table.concat(report.renewableJohtoItems or {}, ", "),
  }
  if report.ok then
    lines[#lines + 1] = "Species and move references: valid"
  else
    lines[#lines + 1] = ("FAILURES (%d):"):format(#report.errors)
    for _, err in ipairs(report.errors) do lines[#lines + 1] = " - " .. err end
  end
  return table.concat(lines, "\n")
end

A.kantoOrder = KANTO_ORDER
A.kantoWildSlots = KANTO_WILD_SLOTS
return A
