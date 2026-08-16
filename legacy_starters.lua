-- KA-INTERNAL: LEGACY-PARTNER-CATALOG-001
--
-- Oak's real Legacy Journey partner scene.  Red/Blue editions keep the
-- familiar three balls, but their physical roles are fixed in NG+:
--   left   = the current hero's Hoenn partner,
--   middle = Oak's graphical lowest-stage/standalone catalogue; a fresh
--            sealed run exposes #001-151 only,
--   right  = the rival's sealed ball (never selectable by the player).
--
-- Normal campaigns always delegate to the exact map-script handler that was
-- installed before this module.  No ordinary Oak starter, Pokédex bit or
-- rival branch is changed outside an active Legacy Journey.

return function(mod, opts)
  opts = opts or {}
  local journey = assert(opts.journey, "legacy partners need legacy journey")
  local hoenn = assert(opts.hoenn, "legacy partners need Hoenn catalogue")
  local johto = assert(opts.johto, "legacy partners need Johto catalogue")
  local i18n = opts.i18n
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  local L = {
    installed = false,
    game = nil,
    mapScripts = nil,
    originalTalk = {},
    originalOnEnter = nil,
    originalOnStep = nil,
  }

  local MAP = "OAKS_LAB"
  local LEFT_TEXT = "TEXT_OAKSLAB_CHARMANDER_POKE_BALL"
  local MIDDLE_TEXT = "TEXT_OAKSLAB_SQUIRTLE_POKE_BALL"
  local RIGHT_TEXT = "TEXT_OAKSLAB_BULBASAUR_POKE_BALL"
  local YELLOW_TEXT = "TEXT_OAKSLAB_EEVEE_POKE_BALL"
  local OAK_TEXT = "TEXT_OAKSLAB_OAK1"
  local LEFT_OBJECT = "OAKSLAB_CHARMANDER_POKE_BALL"
  local MIDDLE_OBJECT = "OAKSLAB_SQUIRTLE_POKE_BALL"
  local RIGHT_OBJECT = "OAKSLAB_BULBASAUR_POKE_BALL"
  local YELLOW_OBJECT = "OAKSLAB_EEVEE_POKE_BALL"
  local PARTNER_MARKER = "_ascendantLegacyJourneyPartner"

  local HERO = {
    RED = { species = "TORCHIC", flag = "EVENT_CHOSE_CHARMANDER" },
    BLUE = { species = "MUDKIP", flag = "EVENT_CHOSE_SQUIRTLE" },
    GREEN = { species = "TREECKO", flag = "EVENT_CHOSE_BULBASAUR" },
  }

  -- Legendary and mythical partners are the capstone reward for completing
  -- all three character-bound Legacy paths.  They deliberately remain part
  -- of the authored #001-251 order (and therefore retain their real Dex and
  -- Crystal preview), but they are not ordinary standalone candidates.  The
  -- only authority for this gate is the validated external archive profile;
  -- save-local copies, encounter flags and possession of the three optional
  -- Hoenn Mega Stones cannot manufacture the reward.
  local LEGACY_ELITE_ORDER = {
    "ARTICUNO", "ZAPDOS", "MOLTRES", "MEWTWO", "MEW",
    "RAIKOU", "ENTEI", "SUICUNE", "LUGIA", "HO_OH", "CELEBI",
  }
  local LEGACY_ELITE_IDS = {}
  for _, id in ipairs(LEGACY_ELITE_ORDER) do LEGACY_ELITE_IDS[id] = true end

  -- A selected capstone partner still starts at level 5, but receives four
  -- deterministic moves drawn only from its effective level-up/TM/HM/tutor
  -- data.
  -- This avoids carrying the high wild-encounter level down to a fresh story
  -- while also avoiding a level-5 legend that cannot deal useful STAB damage
  -- until the late game.  The legality check below is performed against the
  -- live merged registry before the save transaction is staged.
  local LEGACY_ELITE_MOVES = {
    ARTICUNO = { "PECK", "ICE_BEAM", "AGILITY", "MIST" },
    ZAPDOS = { "THUNDERSHOCK", "DRILL_PECK", "THUNDER", "AGILITY" },
    MOLTRES = { "PECK", "FIRE_SPIN", "AGILITY", "SKY_ATTACK" },
    MEWTWO = { "CONFUSION", "SWIFT", "PSYCHIC_M", "RECOVER" },
    MEW = { "POUND", "TRANSFORM", "MEGA_PUNCH", "PSYCHIC_M" },
    RAIKOU = { "THUNDERSHOCK", "BITE", "QUICK_ATTACK", "THUNDER_WAVE" },
    ENTEI = { "EMBER", "BITE", "STOMP", "REFLECT" },
    SUICUNE = { "BUBBLE", "BITE", "AURORA_BEAM", "MIST" },
    LUGIA = { "AEROBLAST", "GUST", "RECOVER", "HYDRO_PUMP" },
    HO_OH = { "SACRED_FIRE", "GUST", "RECOVER", "FIRE_BLAST" },
    CELEBI = { "CONFUSION", "GIGA_DRAIN", "LEECH_SEED", "RECOVER" },
  }
  local LEGACY_ELITE_STAB = {
    ARTICUNO = "ICE_BEAM", ZAPDOS = "THUNDERSHOCK",
    MOLTRES = "FIRE_SPIN", MEWTWO = "CONFUSION", MEW = "PSYCHIC_M",
    RAIKOU = "THUNDERSHOCK", ENTEI = "EMBER", SUICUNE = "BUBBLE",
    LUGIA = "AEROBLAST", HO_OH = "SACRED_FIRE", CELEBI = "CONFUSION",
  }
  local HOENN_LOCKED_TEXT = {
    RED = {
      en = "OAK: This ball awaits\na trainer who bears\nthe RED RIFT SEAL.\fPerhaps in your\nnext life.",
      de = "EICH: Dieser Ball\nwartet auf einen\nTrainer mit rotem\nHöhlensiegel.\fVielleicht erst im\nnächsten Leben.",
    },
    BLUE = {
      en = "OAK: This ball awaits\na trainer who bears\nthe BLUE RIFT\nSEAL.\fPerhaps in your\nnext life.",
      de = "EICH: Dieser Ball\nwartet auf einen\nTrainer mit blauem\nHöhlensiegel.\fVielleicht erst im\nnächsten Leben.",
    },
    GREEN = {
      en = "OAK: This ball awaits\na trainer who bears\nthe GREEN RIFT\nSEAL.\fPerhaps in your\nnext life.",
      de = "EICH: Dieser Ball\nwartet auf einen\nTrainer mit grünem\nHöhlensiegel.\fVielleicht erst im\nnächsten Leben.",
    },
  }

  -- Explicitly curated: weak, early partners with conventional battle growth.
  -- This is filtered through PARTNER_ALLOWLIST below, so it cannot expose a
  -- non-base species which Free Choice rejects.
  local BALANCED_IDS = {
    BULBASAUR = true, CHARMANDER = true, SQUIRTLE = true,
    CATERPIE = true, WEEDLE = true, PIDGEY = true, RATTATA = true,
    SPEAROW = true, PIKACHU = true, NIDORAN_F = true, NIDORAN_M = true,
    ZUBAT = true, ODDISH = true, PARAS = true, DIGLETT = true,
    MEOWTH = true, PSYDUCK = true, MANKEY = true, POLIWAG = true,
    ABRA = true, MACHOP = true, BELLSPROUT = true, GEODUDE = true,
    SLOWPOKE = true, GASTLY = true, CUBONE = true, HORSEA = true,
    GOLDEEN = true, MAGIKARP = true, EEVEE = true,
    CHIKORITA = true, CYNDAQUIL = true, TOTODILE = true,
    SENTRET = true, HOOTHOOT = true, LEDYBA = true, SPINARAK = true,
    CHINCHOU = true, PICHU = true, TOGEPI = true, MAREEP = true,
    MARILL = true, HOPPIP = true, SUNKERN = true, WOOPER = true,
    PINECO = true, SNUBBULL = true, TEDDIURSA = true, SLUGMA = true,
    SWINUB = true, REMORAID = true, HOUNDOUR = true, PHANPY = true,
  }

  -- Never derive the catalogue from registry iteration. Imported forms share
  -- Dex numbers and may use their own id as `def.id`, so a heuristic can put
  -- a Mega/Ascendant form into Oak's #001-251 screen. This authored order is
  -- the source order for the product contract: Free Choice filters this
  -- canonical Kanto/Johto sequence to its lowest stages and standalones.
  local KANTO_ORDER = {
    "BULBASAUR", "IVYSAUR", "VENUSAUR", "CHARMANDER", "CHARMELEON",
    "CHARIZARD", "SQUIRTLE", "WARTORTLE", "BLASTOISE", "CATERPIE",
    "METAPOD", "BUTTERFREE", "WEEDLE", "KAKUNA", "BEEDRILL", "PIDGEY",
    "PIDGEOTTO", "PIDGEOT", "RATTATA", "RATICATE", "SPEAROW", "FEAROW",
    "EKANS", "ARBOK", "PIKACHU", "RAICHU", "SANDSHREW", "SANDSLASH",
    "NIDORAN_F", "NIDORINA", "NIDOQUEEN", "NIDORAN_M", "NIDORINO",
    "NIDOKING", "CLEFAIRY", "CLEFABLE", "VULPIX", "NINETALES",
    "JIGGLYPUFF", "WIGGLYTUFF", "ZUBAT", "GOLBAT", "ODDISH", "GLOOM",
    "VILEPLUME", "PARAS", "PARASECT", "VENONAT", "VENOMOTH", "DIGLETT",
    "DUGTRIO", "MEOWTH", "PERSIAN", "PSYDUCK", "GOLDUCK", "MANKEY",
    "PRIMEAPE", "GROWLITHE", "ARCANINE", "POLIWAG", "POLIWHIRL",
    "POLIWRATH", "ABRA", "KADABRA", "ALAKAZAM", "MACHOP", "MACHOKE",
    "MACHAMP", "BELLSPROUT", "WEEPINBELL", "VICTREEBEL", "TENTACOOL",
    "TENTACRUEL", "GEODUDE", "GRAVELER", "GOLEM", "PONYTA", "RAPIDASH",
    "SLOWPOKE", "SLOWBRO", "MAGNEMITE", "MAGNETON", "FARFETCHD", "DODUO",
    "DODRIO", "SEEL", "DEWGONG", "GRIMER", "MUK", "SHELLDER", "CLOYSTER",
    "GASTLY", "HAUNTER", "GENGAR", "ONIX", "DROWZEE", "HYPNO", "KRABBY",
    "KINGLER", "VOLTORB", "ELECTRODE", "EXEGGCUTE", "EXEGGUTOR", "CUBONE",
    "MAROWAK", "HITMONLEE", "HITMONCHAN", "LICKITUNG", "KOFFING", "WEEZING",
    "RHYHORN", "RHYDON", "CHANSEY", "TANGELA", "KANGASKHAN", "HORSEA",
    "SEADRA", "GOLDEEN", "SEAKING", "STARYU", "STARMIE", "MR_MIME",
    "SCYTHER", "JYNX", "ELECTABUZZ", "MAGMAR", "PINSIR", "TAUROS",
    "MAGIKARP", "GYARADOS", "LAPRAS", "DITTO", "EEVEE", "VAPOREON",
    "JOLTEON", "FLAREON", "PORYGON", "OMANYTE", "OMASTAR", "KABUTO",
    "KABUTOPS", "AERODACTYL", "SNORLAX", "ARTICUNO", "ZAPDOS", "MOLTRES",
    "DRATINI", "DRAGONAIR", "DRAGONITE", "MEWTWO", "MEW",
  }
  local CANONICAL_ORDER = {}
  for _, id in ipairs(KANTO_ORDER) do
    CANONICAL_ORDER[#CANONICAL_ORDER + 1] = id
  end
  for _, id in ipairs(johto.order or {}) do
    CANONICAL_ORDER[#CANONICAL_ORDER + 1] = id
  end
  assert(#CANONICAL_ORDER == 251,
    "Legacy partner catalogue must contain canonical #001-251")

  -- A closed, authored graph is safer than registry-derived evolutions:
  -- imported forms and later-generation branches cannot alter Oak's contract.
  -- A canonical node is selectable iff it has no incoming edge. This makes
  -- PICHU (not PIKACHU) the allowed lowest stage of that family.
  local EVOLUTION_GRAPH = {
    BULBASAUR={"IVYSAUR"}, IVYSAUR={"VENUSAUR"}, CHARMANDER={"CHARMELEON"}, CHARMELEON={"CHARIZARD"}, SQUIRTLE={"WARTORTLE"}, WARTORTLE={"BLASTOISE"},
    CATERPIE={"METAPOD"}, METAPOD={"BUTTERFREE"}, WEEDLE={"KAKUNA"}, KAKUNA={"BEEDRILL"}, PIDGEY={"PIDGEOTTO"}, PIDGEOTTO={"PIDGEOT"}, RATTATA={"RATICATE"}, SPEAROW={"FEAROW"}, EKANS={"ARBOK"},
    PICHU={"PIKACHU"}, PIKACHU={"RAICHU"}, SANDSHREW={"SANDSLASH"}, NIDORAN_F={"NIDORINA"}, NIDORINA={"NIDOQUEEN"}, NIDORAN_M={"NIDORINO"}, NIDORINO={"NIDOKING"}, CLEFFA={"CLEFAIRY"}, CLEFAIRY={"CLEFABLE"}, VULPIX={"NINETALES"}, IGGLYBUFF={"JIGGLYPUFF"}, JIGGLYPUFF={"WIGGLYTUFF"},
    ZUBAT={"GOLBAT"}, GOLBAT={"CROBAT"}, ODDISH={"GLOOM"}, GLOOM={"VILEPLUME","BELLOSSOM"}, PARAS={"PARASECT"}, VENONAT={"VENOMOTH"}, DIGLETT={"DUGTRIO"}, MEOWTH={"PERSIAN"}, PSYDUCK={"GOLDUCK"}, MANKEY={"PRIMEAPE"}, GROWLITHE={"ARCANINE"}, POLIWAG={"POLIWHIRL"}, POLIWHIRL={"POLIWRATH","POLITOED"}, ABRA={"KADABRA"}, KADABRA={"ALAKAZAM"}, MACHOP={"MACHOKE"}, MACHOKE={"MACHAMP"},
    BELLSPROUT={"WEEPINBELL"}, WEEPINBELL={"VICTREEBEL"}, TENTACOOL={"TENTACRUEL"}, GEODUDE={"GRAVELER"}, GRAVELER={"GOLEM"}, PONYTA={"RAPIDASH"}, SLOWPOKE={"SLOWBRO","SLOWKING"}, MAGNEMITE={"MAGNETON"}, DODUO={"DODRIO"}, SEEL={"DEWGONG"}, GRIMER={"MUK"}, SHELLDER={"CLOYSTER"}, GASTLY={"HAUNTER"}, HAUNTER={"GENGAR"}, DROWZEE={"HYPNO"}, KRABBY={"KINGLER"}, VOLTORB={"ELECTRODE"}, EXEGGCUTE={"EXEGGUTOR"}, CUBONE={"MAROWAK"}, KOFFING={"WEEZING"}, RHYHORN={"RHYDON"}, CHANSEY={"BLISSEY"}, HORSEA={"SEADRA"}, SEADRA={"KINGDRA"}, GOLDEEN={"SEAKING"}, STARYU={"STARMIE"}, MAGIKARP={"GYARADOS"},
    ONIX={"STEELIX"}, SCYTHER={"SCIZOR"}, EEVEE={"VAPOREON","JOLTEON","FLAREON","ESPEON","UMBREON"}, PORYGON={"PORYGON2"}, OMANYTE={"OMASTAR"}, KABUTO={"KABUTOPS"}, DRATINI={"DRAGONAIR"}, DRAGONAIR={"DRAGONITE"},
    CHIKORITA={"BAYLEEF"}, BAYLEEF={"MEGANIUM"}, CYNDAQUIL={"QUILAVA"}, QUILAVA={"TYPHLOSION"}, TOTODILE={"CROCONAW"}, CROCONAW={"FERALIGATR"}, SENTRET={"FURRET"}, HOOTHOOT={"NOCTOWL"}, LEDYBA={"LEDIAN"}, SPINARAK={"ARIADOS"}, CHINCHOU={"LANTURN"}, TOGEPI={"TOGETIC"}, NATU={"XATU"}, MAREEP={"FLAAFFY"}, FLAAFFY={"AMPHAROS"}, MARILL={"AZUMARILL"}, HOPPIP={"SKIPLOOM"}, SKIPLOOM={"JUMPLUFF"}, SUNKERN={"SUNFLORA"}, WOOPER={"QUAGSIRE"}, PINECO={"FORRETRESS"}, SNUBBULL={"GRANBULL"}, TEDDIURSA={"URSARING"}, SLUGMA={"MAGCARGO"}, SWINUB={"PILOSWINE"}, REMORAID={"OCTILLERY"}, HOUNDOUR={"HOUNDOOM"}, PHANPY={"DONPHAN"}, TYROGUE={"HITMONLEE","HITMONCHAN","HITMONTOP"}, SMOOCHUM={"JYNX"}, ELEKID={"ELECTABUZZ"}, MAGBY={"MAGMAR"}, LARVITAR={"PUPITAR"}, PUPITAR={"TYRANITAR"},
  }
  -- This one authored allowlist is the authority for both what the carousel
  -- shows and what choose() accepts.  It contains precisely a canonical
  -- #001-251 species when it is a lowest stage or has no evolution line.
  -- In particular PICHU, not PIKACHU, is selectable; DITTO remains valid.
  local EVOLUTION_CHILDREN, PARTNER_ALLOWLIST, PARTNER_ALLOWLIST_ORDER = {}, {}, {}
  for _, children in pairs(EVOLUTION_GRAPH) do
    for _, child in ipairs(children) do EVOLUTION_CHILDREN[child] = true end
  end
  for _, id in ipairs(CANONICAL_ORDER) do
    if not EVOLUTION_CHILDREN[id] then
      PARTNER_ALLOWLIST[id] = true
      PARTNER_ALLOWLIST_ORDER[#PARTNER_ALLOWLIST_ORDER + 1] = id
    end
  end
  local BALANCED_PARTNER_IDS = {}
  for _, id in ipairs(PARTNER_ALLOWLIST_ORDER) do
    if BALANCED_IDS[id] then BALANCED_PARTNER_IDS[id] = true end
  end

  local GROWTH = {
    FAST = { en = "FAST / EASY", de = "SCHNELL / LEICHT" },
    MEDIUM_FAST = { en = "STEADY / EASY", de = "STETIG / LEICHT" },
    MEDIUM_SLOW = { en = "STEADY / NORMAL", de = "STETIG / NORMAL" },
    SLOW = { en = "SLOW / HARD", de = "LANGSAM / SCHWER" },
  }

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  local function beyondActive(save)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(save or L.game)
  end

  local function crystalSpritePath(game, species)
    local crystal = mod.exports and mod.exports.crystalAnimation
    if crystal and type(crystal.staticFrameOne) == "function" then
      local ok, path, trueColor = pcall(crystal.staticFrameOne, {
        species = species,
        data = game and game.data,
        kind = "legacy_partner",
      }, "front", "normal")
      if ok and type(path) == "string" and path ~= "" then
        return path, trueColor == true, "crystal"
      end
    end
    -- legacy_starters is constructed before crystalAnimation is exported.
    -- Normal play opens the catalogue later, but resume/hot-upgrade seams can
    -- ask for rows while that controller is still being rebound.  The pack's
    -- reviewed frame-one files are therefore the deterministic second Crystal
    -- source; never silently replace a canonical partner preview with Oak's
    -- generic sprite merely because controller installation is late.
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    local dex = def and math.floor(tonumber(def.dex) or 0) or 0
    if dex > 0 and type(mod.read) == "function"
        and type(mod.path) == "string" and mod.path ~= "" then
      local relative = ("assets/crystal_animated/front/normal/%d/001.png")
        :format(dex)
      local ok, body = pcall(mod.read, mod, relative)
      if ok and body ~= nil then
        return mod.path .. "/" .. relative, true, "crystal"
      end
    end
    local ok, path, trueColor = pcall(require("src.pokemon.Sprites").path,
      game.data, species, "front", { kind = "oak" })
    if ok and type(path) == "string" and path ~= "" then
      return path, trueColor == true, "fallback"
    end
  end

  local function beyondLockedText()
    return tr(
      "OAK: This non-Kanto\npartner remains safe,\nbut sealed in this run.\fYour partner choice is\nfinal; a later unlock\nwill not reopen it.",
      "EICH: Dieser Nicht-\nKanto-Partner bleibt\nsicher, aber versiegelt.\fDeine Partnerwahl ist\nendgültig; sie wird\nspäter nicht neu geöffnet.")
  end

  if mod.content and mod.content.text then
    mod.content.text:register("_KantoAscendantLegacyReceivedPartner", tr(
      "{RAM} joined your\nLegacy Journey!",
      "{RAM} begleitet deine\nVermächtnis-Reise!"))
    mod.content.text:register("_KantoAscendantLegacyLabLocked", tr(
      "OAK: Not yet!\nFirst choose your partner\vand settle your rival's ball.",
      "EICH: Noch nicht!\nWähle erst deinen Partner\vund kläre den Rivalen-Ball."))
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do
      out[copy(key, seen)] = copy(child, seen)
    end
    return out
  end

  local function state(save)
    local bucket = type(save and save.modData) == "table"
      and save.modData[mod.id]
    return type(bucket) == "table" and bucket.legacy_journey or nil
  end

  local function durableThreePathsComplete()
    if type(journey.profile) ~= "function" then return false end
    local ok, profile = pcall(journey.profile)
    if not ok or type(profile) ~= "table"
        or profile.readOnly == true or profile.futureVersion ~= nil then
      return false
    end
    local completed = profile.completedPaths
    return type(completed) == "table"
      and completed.red == true and completed.blue == true
      and completed.green == true
  end

  local function listHasMove(rows, wanted)
    for _, row in ipairs(type(rows) == "table" and rows or {}) do
      local id = type(row) == "table" and (row.move or row.id) or row
      if id == wanted then return true end
    end
    return false
  end

  local function legalMoveSource(def, move)
    if type(def) ~= "table" or type(move) ~= "string" then return nil end
    if listHasMove(def.level1Moves, move) or listHasMove(def.level1, move) then
      return "level"
    end
    if listHasMove(def.learnset, move) then return "level" end
    if listHasMove(def.tmhm, move) then return "machine" end
    if listHasMove(def.tutorMoves, move) or listHasMove(def.tutors, move) then
      return "tutor"
    end
    return nil
  end

  local function eliteMoveSlots(game, species)
    local plan = LEGACY_ELITE_MOVES[species]
    if not plan then return nil end
    local data = game and game.data
    local def = data and data.pokemon and data.pokemon[species]
    local moves = data and data.moves
    if type(def) ~= "table" or type(moves) ~= "table" then
      return nil, "Legacy move data unavailable for " .. tostring(species)
    end
    local slots, seen = {}, {}
    for _, move in ipairs(plan) do
      local mdef = moves[move]
      if type(mdef) ~= "table" then
        return nil, ("Legacy move %s is unavailable for %s")
          :format(tostring(move), tostring(species))
      end
      if seen[move] or not legalMoveSource(def, move) then
        return nil, ("Legacy move %s is not legal for %s")
          :format(tostring(move), tostring(species))
      end
      local pp = math.max(0, math.floor(tonumber(mdef.pp) or 0))
      if pp == 0 then
        return nil, ("Legacy move %s has no usable PP for %s")
          :format(tostring(move), tostring(species))
      end
      seen[move] = true
      slots[#slots + 1] = { id = move, pp = pp }
    end
    if #slots ~= 4 then
      return nil, "Legacy capstone partner needs exactly four moves"
    end
    local stab = LEGACY_ELITE_STAB[species]
    local stabDef = stab and moves[stab]
    local stabType = tostring(stabDef and stabDef.type or "")
      :upper():gsub("_TYPE$", "")
    local typed = false
    for _, speciesType in ipairs(def.types or {}) do
      if tostring(speciesType):upper():gsub("_TYPE$", "") == stabType then
        typed = true break
      end
    end
    if not (stab and seen[stab] and typed
        and (tonumber(stabDef and stabDef.power) or 0) > 0) then
      return nil, ("Legacy move set for %s lacks damaging STAB")
        :format(tostring(species))
    end
    return slots
  end

  local function partnerDexMax(save)
    local s = state(save)
    local fixed = type(s) == "table" and tonumber(s.partnerDexMax) or nil
    if fixed == 151 or fixed == 251 then return fixed end
    return beyondActive(save) and 251 or 151
  end

  local function active(save)
    return journey.isActive(save) and type(state(save)) == "table"
  end

  local function labContractComplete(s)
    return type(s) == "table" and s.partnerChosen == true
      and s.rivalBallTaken == true and type(s.rivalPartner) == "table"
  end

  local function markLabContract(game, s)
    if not labContractComplete(s) then return false end
    s.introPhase, s.labLocked = "complete", false
    game.save.flags = type(game.save.flags) == "table" and game.save.flags or {}
    game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
    game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB_2 = true
    game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = true
    game.save.flags.EVENT_GOT_STARTER = true
    return true
  end

  local function labExitLocked(save)
    local s = state(save)
    return active(save) and not labContractComplete(s)
  end

  local function character(save)
    local id = journey.activeCharacter and journey.activeCharacter(save)
    id = tostring(id or "RED"):upper()
    return HERO[id] and id or "RED"
  end

  local function heroChoice(save)
    return HERO[character(save)]
  end

  -- The Hoenn gift is a reward for a path completed in an earlier life, not
  -- a free starter for reaching Oak's lab.  The external Legacy archive is
  -- authoritative across Fresh Save/NG+; the run-local copy is only a safe
  -- migration fallback for older archives.
  local function hoennUnlocked(save)
    local key = character(save):lower()
    local profile = journey.profile and journey.profile() or {}
    local completed = type(profile.completedPaths) == "table"
      and profile.completedPaths or nil
    if not completed then
      local s = state(save)
      completed = type(s and s.completedPaths) == "table"
        and s.completedPaths or {}
    end
    return completed[key] == true
  end

  local function canonicalRows(game, mode)
    local rows = {}
    for dex, id in ipairs(CANONICAL_ORDER) do
      local def = game.data.pokemon and game.data.pokemon[id]
      local drawable = false
      if def then
        local path = crystalSpritePath(game, id)
        drawable = type(path) == "string" and path ~= ""
      end
      if PARTNER_ALLOWLIST[id] and def
          and math.floor(tonumber(def.dex) or 0) == dex
          and dex <= partnerDexMax(game.save)
          and drawable
          and (not LEGACY_ELITE_IDS[id] or durableThreePathsComplete())
          and (mode == "free" or BALANCED_PARTNER_IDS[id]) then
        rows[#rows + 1] = { id = id, def = def, dex = dex }
      end
    end
    return rows
  end

  local function typesLabel(def)
    local TypeChart = require("src.battle.TypeChart")
    local types = def.types or {}
    local first = tostring(TypeChart.displayName(types[1]) or "?")
    local second = types[2]
      and tostring(TypeChart.displayName(types[2]) or "") or ""
    if second == first then second = "" end
    return second ~= "" and (first .. " / " .. second) or first
  end

  local function growthLabel(def)
    local row = GROWTH[tostring(def.growthRate or ""):upper()]
    if not row then return tr("SPECIAL / NORMAL", "SPEZIELL / NORMAL") end
    return tr(row.en, row.de)
  end

  local function legacyPrerequisite(game)
    if not active(game.save) then return false, "not a Legacy Journey" end
    local s = state(game.save)
    game.save.flags = type(game.save.flags) == "table" and game.save.flags or {}
    if s.partnerChosen or game.save.flags.EVENT_GOT_STARTER then
      return false, "partner already chosen"
    end
    if not (game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB
        or game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON) then
      return false, "Oak has not opened the choice"
    end
    return true
  end

  local function removeExact(list, wanted)
    for index, value in ipairs(list or {}) do
      if value == wanted then table.remove(list, index) return true end
    end
    return false
  end

  local function snapshotChoice(save, s)
    local flags = save.flags or {}
    local dex = save.pokedex or { seen = {}, owned = {} }
    return {
      partnerMode = s.partnerMode,
      partnerSpecies = s.partnerSpecies,
      partnerChosen = s.partnerChosen,
      partnerBall = s.partnerBall,
      partnerChosenAtCycle = s.partnerChosenAtCycle,
      rivalBallTaken = s.rivalBallTaken,
      rivalPartner = copy(s.rivalPartner),
      introPhase = s.introPhase, labLocked = s.labLocked,
      legacyStarter = save.legacyStarter,
      rivalStarter = save.rivalStarter,
      legacyRivalBall = flags.KA_LEGACY_RIVAL_BALL_TAKEN,
      gotStarter = flags.EVENT_GOT_STARTER,
      followedOak = flags.EVENT_FOLLOWED_OAK_INTO_LAB,
      followedOak2 = flags.EVENT_FOLLOWED_OAK_INTO_LAB_2,
      oakAsked = flags.EVENT_OAK_ASKED_TO_CHOOSE_MON,
      choseCharmander = flags.EVENT_CHOSE_CHARMANDER,
      choseSquirtle = flags.EVENT_CHOSE_SQUIRTLE,
      choseBulbasaur = flags.EVENT_CHOSE_BULBASAUR,
      chosePikachu = flags.EVENT_CHOSE_PIKACHU,
      seen = copy(dex.seen or {}), owned = copy(dex.owned or {}),
    }
  end

  local function restoreChoice(save, s, old, mon)
    removeExact(save.party, mon)
    s.partnerMode, s.partnerSpecies = old.partnerMode, old.partnerSpecies
    s.partnerChosen, s.partnerBall = old.partnerChosen, old.partnerBall
    s.partnerChosenAtCycle = old.partnerChosenAtCycle
    s.rivalBallTaken = old.rivalBallTaken
    s.rivalPartner = copy(old.rivalPartner)
    s.introPhase, s.labLocked = old.introPhase, old.labLocked
    save.legacyStarter = old.legacyStarter
    save.rivalStarter = old.rivalStarter
    save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = old.legacyRivalBall
    save.flags.EVENT_GOT_STARTER = old.gotStarter
    save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = old.followedOak
    save.flags.EVENT_FOLLOWED_OAK_INTO_LAB_2 = old.followedOak2
    save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = old.oakAsked
    save.flags.EVENT_CHOSE_CHARMANDER = old.choseCharmander
    save.flags.EVENT_CHOSE_SQUIRTLE = old.choseSquirtle
    save.flags.EVENT_CHOSE_BULBASAUR = old.choseBulbasaur
    save.flags.EVENT_CHOSE_PIKACHU = old.chosePikachu
    save.pokedex.seen, save.pokedex.owned = old.seen, old.owned
  end

  local function setVanillaBranch(save, source)
    local flags = save.flags
    flags.EVENT_CHOSE_CHARMANDER = nil
    flags.EVENT_CHOSE_SQUIRTLE = nil
    flags.EVENT_CHOSE_BULBASAUR = nil
    flags.EVENT_CHOSE_PIKACHU = nil
    if source == "yellow_pikachu" then
      flags.EVENT_CHOSE_PIKACHU = true
      return
    end
    if source == "yellow_catalog" then return end
    flags[heroChoice(save).flag] = true
  end

  -- The durable game save is authoritative.  Archive synchronization runs
  -- only after that save succeeds and is retried on later save/load events;
  -- a filesystem failure can therefore never make a second partner legal.
  function L.choose(game, species, mode, ball, source)
    local ok, why = legacyPrerequisite(game)
    if not ok then return false, why end
    local def = game.data.pokemon and game.data.pokemon[species]
    local dex = def and math.floor(tonumber(def.dex) or 0) or 0
    if not def then return false, "unknown partner" end
    if dex >= 152 and dex <= 251 and partnerDexMax(game.save) == 151 then
      return false, "beyond-kanto-sealed"
    end
    if LEGACY_ELITE_IDS[species] and not durableThreePathsComplete() then
      return false, "all three durable Legacy paths are required"
    end
    if mode == "hoenn" then
      if dex > 151 and not beyondActive(game.save) then
        return false, "beyond-kanto-sealed"
      end
      if not hoennUnlocked(game.save) then
        return false, "matching rift seal required"
      end
      if species ~= heroChoice(game.save).species then
        return false, "wrong hero Hoenn partner"
      end
    elseif mode == "balanced" then
      if dex < 1 or dex > partnerDexMax(game.save)
          or not BALANCED_PARTNER_IDS[species] then
        return false, "partner is not in Balanced Choice"
      end
    elseif mode == "free" then
      if dex < 1 or dex > partnerDexMax(game.save)
          or not PARTNER_ALLOWLIST[species]
          or CANONICAL_ORDER[dex] ~= species then
        return false, "partner is not a legal base #001-251 species"
      end
    elseif source ~= "yellow_pikachu" then
      return false, "unknown partner mode"
    end

    local Party = require("src.pokemon.Party")
    if #(game.save.party or {}) >= Party.MAX then
      return false, "starter party is full"
    end
    local Pokemon = require("src.pokemon.Pokemon")
    local BattleState = require("src.battle.BattleState")
    local s = state(game.save)
    game.save.pokedex = type(game.save.pokedex) == "table"
      and game.save.pokedex or { seen = {}, owned = {} }
    game.save.pokedex.seen = type(game.save.pokedex.seen) == "table"
      and game.save.pokedex.seen or {}
    game.save.pokedex.owned = type(game.save.pokedex.owned) == "table"
      and game.save.pokedex.owned or {}
    local old = snapshotChoice(game.save, s)
    local mon = Pokemon.new(game.data, species, 5)
    if LEGACY_ELITE_IDS[species] then
      local slots, moveErr = eliteMoveSlots(game, species)
      if not slots then return false, moveErr end
      mon.moves = slots
    end
    BattleState.stampOT(game.save, mon)
    assert(Party.add(game.save.party, mon))
    mon[PARTNER_MARKER] = true
    if source == "yellow_pikachu" then
      local yellowPartner = mod.exports and mod.exports.yellowPartner
      if yellowPartner and yellowPartner.markLegacyPartner then
        yellowPartner.markLegacyPartner(game, mon)
      end
    end
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
    s.partnerMode = mode
    s.partnerSpecies = species
    s.partnerChosen = true
    s.partnerBall = ball
    s.partnerChosenAtCycle = tonumber(s.cycle) or 0
    game.save.legacyStarter = species
    game.save.flags.EVENT_GOT_STARTER = true
    setVanillaBranch(game.save, source)
    if source == "yellow_catalog" or source == "yellow_hoenn"
        or source == "yellow_pikachu" then
      s.rivalBallTaken = true
      game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = true
      game.save.rivalStarter = game.save.rivalStarter or 1
    end

    local rival = opts.rival
    if rival and rival.resolveForJourney then
      local rivalPartner, rivalErr = rival.resolveForJourney(s)
      if not rivalPartner then
        mon[PARTNER_MARKER] = nil
        restoreChoice(game.save, s, old, mon)
        return false, rivalErr or "rival partner resolution failed"
      end
    end
    if not markLabContract(game, s) then
      mon[PARTNER_MARKER] = nil
      restoreChoice(game.save, s, old, mon)
      return false, "rival ball contract is incomplete"
    end

    if game.writeSave and not game:writeSave() then
      mon[PARTNER_MARKER] = nil
      restoreChoice(game.save, s, old, mon)
      return false, "save failed"
    end
    if journey.syncPartner then
      local synced, err = journey.syncPartner(game.save)
      if not synced and mod.log and mod.log.warn then
        mod.log:warn("Legacy partner archive will retry: %s", tostring(err))
      end
    end
    return true, mon
  end

  local function recordExistingPartner(game, species, mode, ball, source,
      persist)
    local s = state(game.save)
    if not (s and active(game.save)) then return false, "not a Legacy Journey" end
    if s.partnerChosen then
      return s.partnerSpecies == species, s.partnerSpecies == species
        and nil or "partner already chosen"
    end
    local found
    for _, mon in ipairs(game.save.party or {}) do
      if mon.species == species then found = mon break end
    end
    if not found then return false, "authored partner was not received" end
    found[PARTNER_MARKER] = true
    local old = {
      partnerMode = s.partnerMode, partnerSpecies = s.partnerSpecies,
      partnerChosen = s.partnerChosen, partnerBall = s.partnerBall,
      partnerChosenAtCycle = s.partnerChosenAtCycle,
      rivalBallTaken = s.rivalBallTaken,
      rivalPartner = copy(s.rivalPartner),
      introPhase = s.introPhase, labLocked = s.labLocked,
      pendingAuthoredPartner = copy(s.pendingAuthoredPartner),
      legacyStarter = game.save.legacyStarter,
      legacyRivalBall = game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN,
      gotStarter = game.save.flags.EVENT_GOT_STARTER,
      followedOak = game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB,
      followedOak2 = game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB_2,
      oakAsked = game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON,
      choseCharmander = game.save.flags.EVENT_CHOSE_CHARMANDER,
      choseSquirtle = game.save.flags.EVENT_CHOSE_SQUIRTLE,
      choseBulbasaur = game.save.flags.EVENT_CHOSE_BULBASAUR,
      chosePikachu = game.save.flags.EVENT_CHOSE_PIKACHU,
    }
    local function rollback()
      found[PARTNER_MARKER] = nil
      s.partnerMode, s.partnerSpecies = old.partnerMode, old.partnerSpecies
      s.partnerChosen, s.partnerBall = old.partnerChosen, old.partnerBall
      s.partnerChosenAtCycle, s.rivalBallTaken =
        old.partnerChosenAtCycle, old.rivalBallTaken
      s.rivalPartner = copy(old.rivalPartner)
      s.introPhase, s.labLocked = old.introPhase, old.labLocked
      s.pendingAuthoredPartner = copy(old.pendingAuthoredPartner)
      game.save.legacyStarter = old.legacyStarter
      game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = old.legacyRivalBall
      game.save.flags.EVENT_GOT_STARTER = old.gotStarter
      game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = old.followedOak
      game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB_2 = old.followedOak2
      game.save.flags.EVENT_OAK_ASKED_TO_CHOOSE_MON = old.oakAsked
      game.save.flags.EVENT_CHOSE_CHARMANDER = old.choseCharmander
      game.save.flags.EVENT_CHOSE_SQUIRTLE = old.choseSquirtle
      game.save.flags.EVENT_CHOSE_BULBASAUR = old.choseBulbasaur
      game.save.flags.EVENT_CHOSE_PIKACHU = old.chosePikachu
    end
    s.partnerMode, s.partnerSpecies = mode, species
    s.partnerChosen, s.partnerBall = true, ball
    s.partnerChosenAtCycle = tonumber(s.cycle) or 0
    s.pendingAuthoredPartner = nil
    if source == "yellow_pikachu" then
      s.rivalBallTaken = true
      game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = true
    end
    game.save.legacyStarter = species
    setVanillaBranch(game.save, source)
    local rival = opts.rival
    if rival and rival.resolveForJourney then
      local rivalPartner, err = rival.resolveForJourney(s)
      if not rivalPartner then
        rollback()
        s.pendingAuthoredPartner = {
          species = species, mode = mode, ball = ball, source = source,
        }
        return false, err
      end
    end
    if not markLabContract(game, s) then
      rollback()
      return false, "rival ball contract is incomplete"
    end
    if persist ~= false and game.writeSave and not game:writeSave() then
      rollback()
      s.pendingAuthoredPartner = {
        species = species, mode = mode, ball = ball, source = source,
      }
      return false, "save failed"
    end
    if persist ~= false and journey.syncPartner then
      journey.syncPartner(game.save)
    end
    return true
  end

  local function recoverAuthoredPartner(game, persist)
    local s = game and state(game.save)
    if not (s and active(game.save)) or s.partnerChosen then return true end
    local pending = type(s.pendingAuthoredPartner) == "table"
      and s.pendingAuthoredPartner or nil
    if not pending then
      local flags = game.save.flags or {}
      local hasPikachu = false
      for _, mon in ipairs(game.save.party or {}) do
        if mon.species == "PIKACHU" then hasPikachu = true break end
      end
      if flags.EVENT_GOT_STARTER and flags.EVENT_CHOSE_PIKACHU and hasPikachu then
        pending = {
          species = "PIKACHU", mode = "yellow", ball = "yellow",
          source = "yellow_pikachu",
        }
      end
    end
    if not pending then return true end
    return recordExistingPartner(game, pending.species, pending.mode,
      pending.ball, pending.source, persist)
  end

  local function pushText(game, text, done, opts2)
    game.stack:push(require("src.render.TextBox").new(game, text, done, opts2))
  end

  local function hint(game, done, text)
    pushText(game, text, done)
  end

  local function stageLegacyRunRules(game, dexMax)
    local run = state(game and game.save)
    local runRules = mod.exports and mod.exports.runRules
    if type(run) ~= "table" or not (runRules
        and type(runRules.seedLegacy) == "function"
        and type(runRules.buildPool) == "function") then
      return nil, "Legacy run-rules authority is unavailable"
    end
    if run.pendingRunRules == nil and run.runRulesLegacyDefault ~= true then
      return nil, "Legacy run-rules snapshot is missing or unverified"
    end
    local bucket = game.save.modData[mod.id]
    local receipt = {
      previousRules = copy(bucket.run_rules),
      previousLocked = run.runRulesLocked,
    }
    local seeded, err, changed = runRules.seedLegacy(game.save,
      run.pendingRunRules, dexMax)
    if not seeded then return nil, err end
    run.runRulesLocked = true
    receipt.changed = changed == true or receipt.previousLocked ~= true
    return receipt
  end

  local function restoreLegacyRunRules(game, receipt)
    if type(receipt) ~= "table" then return end
    local run = state(game and game.save)
    local bucket = game.save.modData[mod.id]
    bucket.run_rules = copy(receipt.previousRules)
    if type(run) == "table" then
      run.runRulesLocked = receipt.previousLocked
    end
  end

  local function rebuildLegacyRunRules(game)
    local runRules = mod.exports and mod.exports.runRules
    if not (runRules and type(runRules.buildPool) == "function") then
      return false, "Legacy run-rules pool rebuilder is unavailable"
    end
    local ok, err = pcall(runRules.buildPool, game)
    if not ok then return false, tostring(err) end
    return true
  end

  -- SaveData 0.1.96 writes main/.bak/.tmp in three steps. A failed final-main
  -- write deliberately leaves the new .tmp as a recovery witness, so merely
  -- rolling the Lua table back would promote the rejected #251 decision on the
  -- next boot. Snapshot the complete triplet before the irreversible choice;
  -- a failed write restores it byte-for-byte before the player can retry.
  local function snapshotLegacySaveFiles(game)
    local okSaveData, SaveData = pcall(require, "src.core.SaveData")
    if not okSaveData or type(SaveData) ~= "table"
        or type(SaveData.saveFilename) ~= "function" then
      return nil, "SaveData persistence API is unavailable"
    end
    local fs
    if type(SaveData.persistenceFs) == "function" then
      local okFs, value = pcall(SaveData.persistenceFs)
      if okFs then fs = value end
    end
    if not (fs and type(fs.getInfo) == "function"
        and type(fs.read) == "function" and type(fs.write) == "function"
        and type(fs.remove) == "function") then
      return nil, "Save filesystem recovery API is unavailable"
    end
    local okName, main = pcall(SaveData.saveFilename,
      game and game.save and game.save.version)
    if not okName or type(main) ~= "string" or main == "" then
      return nil, "Active save filename is unavailable"
    end
    local receipt = { fs = fs, files = {} }
    for _, path in ipairs({ main, main .. ".bak", main .. ".tmp" }) do
      local okInfo, info = pcall(fs.getInfo, path)
      if not okInfo then return nil, tostring(info) end
      local row = { path = path, present = info ~= nil }
      if row.present then
        local okRead, bytes = pcall(fs.read, path)
        if not okRead or type(bytes) ~= "string" then
          return nil, "Could not snapshot " .. path
        end
        row.bytes = bytes
      end
      receipt.files[#receipt.files + 1] = row
    end
    return receipt
  end

  local function restoreLegacySaveFiles(receipt)
    if type(receipt) ~= "table" or type(receipt.fs) ~= "table"
        or type(receipt.files) ~= "table" then
      return false, "Missing save-file rollback receipt"
    end
    local fs = receipt.fs
    local function remove(path)
      local okInfo, info = pcall(fs.getInfo, path)
      if not okInfo then return false end
      if not info then return true end
      local ok, result = pcall(fs.remove, path)
      return ok and result ~= false
    end
    local function write(path, bytes)
      -- Delete first: if restoration itself cannot write, reload must fall
      -- through to the restored witness/backup instead of accepting new bytes.
      if not remove(path) then return false end
      local ok, result = pcall(fs.write, path, bytes)
      return ok and result ~= false
    end
    local bySuffix = {}
    for _, row in ipairs(receipt.files) do
      if row.path:sub(-4) == ".tmp" then bySuffix.tmp = row
      elseif row.path:sub(-4) == ".bak" then bySuffix.bak = row
      else bySuffix.main = row end
    end
    local function restore(row)
      if not row then return false end
      if row.present then return write(row.path, row.bytes) end
      return remove(row.path)
    end

    -- Remove/restore the rejected recovery witness first, then prepare a good
    -- backup before replacing main. This keeps reload on the old state even if
    -- a second main write fails while recovering from a one-shot I/O fault.
    local ok = restore(bySuffix.tmp)
    local backup = bySuffix.bak
    local temporaryBackup = false
    if backup and not backup.present and bySuffix.main and bySuffix.main.present then
      temporaryBackup = write(backup.path, bySuffix.main.bytes)
      ok = temporaryBackup and ok
    else
      ok = restore(backup) and ok
    end
    local mainOk = restore(bySuffix.main)
    ok = mainOk and ok
    if mainOk and temporaryBackup then
      ok = remove(backup.path) and ok
    end

    -- Verify the exact pre-choice bytes, not just API return values.
    for _, row in ipairs(receipt.files) do
      local okInfo, info = pcall(fs.getInfo, row.path)
      if not okInfo or (info ~= nil) ~= row.present then ok = false end
      if row.present and info then
        local okRead, bytes = pcall(fs.read, row.path)
        if not okRead or bytes ~= row.bytes then ok = false end
      end
    end
    return ok, ok and nil or "Save-file rollback verification failed"
  end

  local function rollbackLegacyChoice(game, run, previousMax, ruleReceipt,
      diskReceipt)
    restoreLegacyRunRules(game, ruleReceipt)
    if type(run) == "table" then run.partnerDexMax = previousMax end
    local poolOk, poolErr = rebuildLegacyRunRules(game)
    local diskOk, diskErr = restoreLegacySaveFiles(diskReceipt)
    if poolOk and diskOk then return true end
    return false, diskErr or poolErr or "Legacy choice rollback failed"
  end

  local function saveFailure(game, onBlocked, recovered)
    local reason = recovered and "save_failed" or "rollback_failed"
    hint(game, function()
      if onBlocked then onBlocked(reason) end
    end, recovered and tr(
      "OAK: SAVE FAILED.\nRULES NOT LOCKED.\fNOTHING CHANGED.\nCHOOSE AGAIN.",
      "EICH: SPEICHERN\nFEHLGESCHLAGEN.\fREGELN BLEIBEN OFFEN.\fNICHTS GEÄNDERT.\nWÄHLE ERNEUT.") or tr(
      "SAVE RECOVERY\nDID NOT FINISH.\fDO NOT CONTINUE.\nKEEP YOUR BACKUP.",
      "SAVE-RETTUNG\nNICHT BEENDET.\fJETZT BEENDEN.\nBACKUP BEHALTEN."))
  end

  local function ruleFailure(game, onBlocked, reason)
    hint(game, function()
      if onBlocked then onBlocked(reason or "run_rules") end
    end, tr(
      "OAK: RUN RULES\nWERE NOT LOCKED.\fNOTHING CHANGED.\nCHOOSE AGAIN.",
      "EICH: DIE REGELN\nNICHT GESPERRT.\fNICHTS GEÄNDERT.\nWÄHLE ERNEUT."))
  end

  -- Before Oak shows a single candidate, the player decides whether this new
  -- Legacy cycle should permanently cross the Driftglass boundary. NO is the
  -- safe default and keeps this one final partner choice on #001-151. A later
  -- unlock never reopens Oak's already-consumed partner choice.
  local function ensureLegacyBeyond(game, onReady, onBlocked)
    local run = state(game and game.save)
    local function persistFixedPool(dexMax, johtoActive)
      if type(run) ~= "table" then
        ruleFailure(game, onBlocked, "legacy_state")
        return false
      end
      local previousMax = run.partnerDexMax
      run.partnerDexMax = dexMax
      local receipt, rulesErr = stageLegacyRunRules(game, dexMax)
      if not receipt then
        run.partnerDexMax = previousMax
        ruleFailure(game, onBlocked, rulesErr)
        return false
      end
      local needsWrite = receipt.changed or tonumber(previousMax) ~= dexMax
      if needsWrite then
        local diskReceipt = snapshotLegacySaveFiles(game)
        if not diskReceipt then
          restoreLegacyRunRules(game, receipt)
          run.partnerDexMax = previousMax
          rebuildLegacyRunRules(game)
          ruleFailure(game, onBlocked, "save_guard")
          return false
        end
        local wrote = false
        if type(game.writeSave) == "function" then
          local called, result = pcall(game.writeSave, game)
          wrote = called and result ~= false
        end
        if not wrote then
          local recovered = rollbackLegacyChoice(game, run, previousMax,
            receipt, diskReceipt)
          saveFailure(game, onBlocked, recovered)
          return false
        end
      end
      rebuildLegacyRunRules(game)
      if onReady then onReady(johtoActive == true) end
      return true
    end
    if type(run) == "table" and tonumber(run.partnerDexMax) == 151 then
      return persistFixedPool(151, false)
    end
    if beyondActive(game and game.save) then
      return persistFixedPool(251, true)
    end
    if not (beyondKanto and type(beyondKanto.activate) == "function") then
      if onBlocked then onBlocked("boundary") end
      return false
    end
    local askBoundary
    local function confirmKantoOnly()
      pushText(game, tr(
        "CONTINUE WITHOUT A\nJOHTO PARTNER?\fYES: THIS CHOICE\nSTAYS DEX 001-151.\fDRIFTGLASS MAY\nOPEN JOHTO LATER.\fNO: RETURN TO\nJOHTO DECISION.",
        "OHNE JOHTO-PARTNER\nFORTFAHREN?\fJA: DIESE WAHL\nNUR DEX 001-151.\fDRIFTGLASS ÖFFNET\nJOHTO AUCH SPÄTER.\fNEIN: ZURÜCK ZUR\nJOHTO-FRAGE."), nil, {
          -- A stray A press must return to the first decision instead of
          -- silently consuming the once-only Legacy partner catalogue.
          defaultNo = true,
          choice = function(confirmed)
            if confirmed then
              persistFixedPool(151, false)
            else
              askBoundary()
            end
          end,
        })
    end
    askBoundary = function()
      pushText(game, tr(
        "OAK: OPEN JOHTO\nFOR THIS SAVE?\fTHIS IS PERMANENT.\nCANNOT BE UNDONE.\fYES: PARTNERS USE\nDEX 001-251.\fRANDOMIZER ALSO\nUSES DEX 001-251.\fNO: KEEP THIS ONE\nDEX 001-151 ONLY.\fDRIFTGLASS MAY\nOPEN JOHTO LATER.",
        "EICH: JOHTO ÖFFNEN\nFÜR DIESEN SAVE?\fDAS IST DAUERHAFT.\nNICHT UMKEHRBAR.\fJA: PARTNER NUTZEN\nDEX 001-251.\fRANDOMIZER NUTZT\nAUCH DEX 001-251.\fNEIN: DIESE WAHL\nNUR DEX 001-151.\fDRIFTGLASS ÖFFNET\nJOHTO AUCH SPÄTER."), nil, {
          defaultNo = true,
          choice = function(yes)
            if not yes then
              confirmKantoOnly()
              return
            end
          if type(run) ~= "table" then
            ruleFailure(game, onBlocked, "legacy_state")
            return
          end
          local previousMax = run.partnerDexMax
          run.partnerDexMax = 251
          local receipt, rulesErr = stageLegacyRunRules(game, 251)
          if not receipt then
            run.partnerDexMax = previousMax
            ruleFailure(game, onBlocked, rulesErr)
            return
          end
          local diskReceipt = snapshotLegacySaveFiles(game)
          if not diskReceipt then
            restoreLegacyRunRules(game, receipt)
            run.partnerDexMax = previousMax
            rebuildLegacyRunRules(game)
            ruleFailure(game, onBlocked, "save_guard")
            return
          end
          local changed, reason = beyondKanto.activate(game, {
            decision = "legacy_partner_catalog",
          })
          local activeNow = beyondActive(game and game.save)
          if not activeNow or not (changed or reason == "already-active") then
            local recovered = rollbackLegacyChoice(game, run, previousMax,
              receipt, diskReceipt)
            if reason == "save_failed" then
              saveFailure(game, onBlocked, recovered)
            else
              hint(game, function()
                if onBlocked then
                  onBlocked(recovered and (reason or "activation")
                    or "rollback_failed")
                end
              end, recovered and tr(
                "OAK: JOHTO DEX\nDID NOT OPEN.\fNOTHING CHANGED.\nCHOOSE AGAIN.",
                "EICH: JOHTO-DEX\nBLIEB GESCHLOSSEN.\fNICHTS GEÄNDERT.\nWÄHLE ERNEUT.") or tr(
                "SAVE RECOVERY\nDID NOT FINISH.\fDO NOT CONTINUE.\nKEEP YOUR BACKUP.",
                "SAVE-RETTUNG\nNICHT BEENDET.\fJETZT BEENDEN.\nBACKUP BEHALTEN."))
            end
            return
          end
          rebuildLegacyRunRules(game)
          hint(game, function()
            if onReady then onReady(true) end
          end, tr(
            "BEYOND KANTO IS\nNOW PERMANENT.\fOAK'S PARTNER LIST\nIS DEX 001-251.",
            "JENSEITS VON KANTO\nIST NUN DAUERHAFT.\fEICHS PARTNERLISTE\nIST DEX 001-251."))
          end,
        })
    end
    askBoundary()
    return true
  end

  local Catalog = {}
  Catalog.__index = Catalog
  Catalog.isOpaque = true

  local function loadSprite(game, row)
    if row.spriteLoaded then return end
    row.spriteLoaded = true
    local path, trueColor, source = crystalSpritePath(game, row.id)
    row.spritePath, row.spriteSource = path, source
    if not path or not (love and love.graphics) then return end
    local ok, image = pcall(love.graphics.newImage, path)
    if ok and image then
      if image.setFilter then image:setFilter("nearest", "nearest") end
      row.sprite, row.trueColor = image, trueColor == true
    end
  end

  function Catalog.new(game, controller, config)
    local self = setmetatable({}, Catalog)
    self.game, self.controller = game, controller
    self.mode = config.mode or "balanced"
    self.modeLocked = config.modeLocked == true
    self.ball, self.source = config.ball, config.source or "catalog"
    self.rows = config.rows or canonicalRows(game, self.mode)
    self.index = math.max(1, math.min(#self.rows, config.index or 1))
    self.error = nil
    if self.rows[self.index] then loadSprite(game, self.rows[self.index]) end
    return self
  end

  function Catalog:current()
    return self.rows[self.index]
  end

  function Catalog:toggleMode()
    if self.modeLocked then return false end
    local current = self:current()
    local dex = current and current.dex
    self.mode = self.mode == "balanced" and "free" or "balanced"
    self.rows = canonicalRows(self.game, self.mode)
    self.index = 1
    if dex then
      for index, row in ipairs(self.rows) do
        if row.dex >= dex then self.index = index break end
      end
    end
    if self:current() then loadSprite(self.game, self:current()) end
    return true
  end

  function Catalog:move(delta)
    if #self.rows == 0 then return end
    self.index = ((self.index - 1 + delta) % #self.rows) + 1
    loadSprite(self.game, self:current())
    local ok, Sound = pcall(require, "src.core.Sound")
    if ok then Sound.play(self.game.data, "Press_AB") end
  end

  function Catalog:confirm()
    local row = self:current()
    if not row then return end
    local name = row.def.name or row.id
    local okSound, Sound = pcall(require, "src.core.Sound")
    if okSound then Sound.playCry(self.game.data, row.id) end
    pushText(self.game, tr(
      ("%s?\nChoose as partner?"):format(name),
      ("%s?\nAls Partner wählen"):format(name)), nil, {
        defaultNo = true,
        choice = function(yes)
          if not yes then return end
          pushText(self.game, tr(
            ("FINAL %s?\nCannot be changed."):format(name),
            ("FINAL %s?\nBleibt fest."):format(name)), nil, {
              defaultNo = true,
              choice = function(final)
                if not final then return end
                local ok, err = L.choose(self.game, row.id, self.mode,
                  self.ball, self.source)
                if not ok then
                  self.error = tostring(err)
                  return
                end
                self.game.stack:pop()
                self.controller:onPartnerChosen(row.id, self.ball)
              end,
            })
        end,
      })
  end

  function Catalog:update()
    local input = self.game.input
    if input:wasPressed("left") then self:move(-1)
    elseif input:wasPressed("right") then self:move(1)
    elseif input:wasPressed("up") then self:move(-10)
    elseif input:wasPressed("down") then self:move(10)
    elseif input:wasPressed("select") then self:toggleMode()
    elseif input:wasPressed("a") then self:confirm()
    elseif input:wasPressed("b") then
      self.game.stack:pop()
      self.controller:onCatalogCancelled()
    end
  end

  function Catalog:sgbPalettes(game)
    local P = require("src.render.PaletteFX")
    local row = self:current()
    local base = P.pal(game.data, "BROWNMON")
    if not base then return nil end
    return {
      P.whole(base),
      P.zone(P.monPal(game.data, row and row.id), 1, 4, 8, 11),
    }
  end

  function Catalog:draw()
    local Font = require("src.render.Font")
    local function fitted(value, budget)
      value = tostring(value or "")
      if Font.width(value) <= budget then return value end
      local suffix = "."
      local spans = Font.split(value)
      local fit = Font.spansFitting(spans,
        math.max(0, budget - Font.width(suffix)))
      if fit < 1 then return "" end
      return value:sub(1, spans[fit].to) .. suffix
    end
    local row = self:current()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)
    Font.drawBox(0, 0, 20, 18)
    Font.draw(tr("OAK'S CATALOG", "EICHS KATALOG"), 8, 8)
    local filter = self.mode == "free" and tr("FREE", "FREI")
      or self.mode == "balanced" and tr("BALANCED", "AUSGEWOGEN")
      or tr("HOENN PARTNER", "HOENN-PARTNER")
    Font.draw(fitted(filter, 144), 8, 22)
    if not row then
      Font.draw(tr("NO LEGAL PARTNERS", "KEINE GÜLTIGEN PARTNER"), 8, 56)
      return
    end
    loadSprite(self.game, row)
    if row.sprite then
      local w, h = row.sprite:getDimensions()
      local x, y = 8 + math.floor((56 - w) / 2), 34 + math.max(0, 56 - h)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(row.sprite, x, y)
      if row.trueColor then
        require("src.render.PaletteFX").markTrueColor(x, y, w, h)
      end
    end
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(("No.%03d"):format(row.dex), 72, 36)
    Font.draw(fitted(row.def.name or row.id, 80), 72, 48)
    Font.draw(tr("TYPE", "TYP"), 72, 62)
    local typeText = typesLabel(row.def)
    local typeA, typeB = typeText:match("^(.-) / (.-)$")
    Font.draw(fitted(typeA or typeText, 80), 72, 72)
    if typeB then Font.draw(fitted(typeB, 80), 72, 82) end
    Font.draw(tr("GROWTH", "TEMPO"), 72, 94)
    local growth = growthLabel(row.def)
    local growthA, growthB = growth:match("^(.-) / (.-)$")
    Font.draw(fitted(growthA or growth, 80), 72, 104)
    if growthB then Font.draw(fitted(growthB, 80), 72, 114) end
    Font.draw(("%d/%d"):format(self.index, #self.rows), 8, 98)
    if self.error then
      Font.draw(fitted(self.error, 144), 8, 128)
    else
      Font.draw(self.modeLocked and tr("A OK  B BACK", "A OK  B ZURÜCK")
        or tr("L/R A  SEL MODE B", "L/R A  SEL MODUS B"), 8, 128)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function runOriginal(handler, game, ow, npc, done)
    if type(handler) == "function" then
      return handler(game, ow, npc, done)
    end
    if type(handler) == "table" and ow and ow.runner then
      ow.runner:run(handler, { npc = npc, onDone = done })
      return
    end
    if done then done() end
  end

  local function writePending(game)
    return not game.writeSave or game:writeSave() ~= false
  end

  local function hideBall(game, ow, object)
    local Commands = require("src.script.Commands")
    Commands.hide_object({ save = game.save, game = game, overworld = ow },
      MAP, object)
  end

  local function rivalTakesBall(game, ow, npc, done)
    done = done or function() end
    local s = state(game.save)
    game.save.flags = type(game.save.flags) == "table" and game.save.flags or {}
    if s.rivalBallTaken then
      hideBall(game, ow, RIGHT_OBJECT)
      done()
      return
    end
    local oldTaken = s.rivalBallTaken
    local oldFlag = game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN
    s.rivalBallTaken = true
    game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = true
    if not writePending(game) then
      -- The physical scene is strictly after the durable claim.  A failed
      -- write leaves neither an invisible ball nor a stale claim sentinel;
      -- the next entry/talk is the safe retry.
      s.rivalBallTaken = oldTaken
      game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = oldFlag
      done()
      return false, "save failed"
    end
    local rows = {
      { "emote", 1, "shock" },
      { "move_npc_to", 1, 8, 4 },
      { "face_object", 1, "up" },
      { "show_text", "_OaksLabRivalIllTakeThisOneText" },
      { "hide_object", MAP, RIGHT_OBJECT },
    }
    ow.runner:run(rows, { npc = npc, onDone = done })
    return true
  end

  -- Yellow has exactly one authored table ball. The rival's claim is durable
  -- before it disappears; Oak gives the player's choice directly afterwards.
  local function yellowRivalTakesBall(game, ow, npc, done)
    done = done or function() end
    local s = state(game.save)
    game.save.flags = type(game.save.flags) == "table" and game.save.flags or {}
    if s.rivalBallTaken then
      hideBall(game, ow, YELLOW_OBJECT)
      done()
      return true
    end
    local oldTaken = s.rivalBallTaken
    local oldFlag = game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN
    local oldStarter = game.save.rivalStarter
    s.rivalBallTaken = true
    game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = true
    game.save.rivalStarter = 1
    if not writePending(game) then
      s.rivalBallTaken = oldTaken
      game.save.flags.KA_LEGACY_RIVAL_BALL_TAKEN = oldFlag
      game.save.rivalStarter = oldStarter
      hint(game, done, tr(
        "OAK: The rival's claim\ncould not be saved.\fNothing changed; try again.",
        "EICH: Der Anspruch des\nRivalen ließ sich nicht speichern.\fNichts änderte sich;\nversuche es erneut."))
      return false, "save failed"
    end

    local py = ow and ow.player and ow.player.cellY
    local rows = { { "emote", 1, "shock" } }
    if py == 4 then
      rows[#rows + 1] = { "walk_npc", 1,
        { "down", "right", "right", "right" }, { wait = false } }
      rows[#rows + 1] = { "face_player_dir", "left" }
      rows[#rows + 1] = { "move_player", "right", 2 }
      rows[#rows + 1] = { "wait", 40 }
    else
      rows[#rows + 1] = { "move_npc_to", 1, 7, 4 }
    end
    rows[#rows + 1] = { "face_object", 1, "up" }
    rows[#rows + 1] = { "hide_object", MAP, YELLOW_OBJECT }
    rows[#rows + 1] = { "show_text", "_OaksLabRivalTakesText1" }
    rows[#rows + 1] = { "play_sound", "Get_Key_Item" }
    rows[#rows + 1] = { "show_text", "_OaksLabRivalTakesText2" }
    rows[#rows + 1] = { "show_text", "_OaksLabRivalTakesText3" }
    rows[#rows + 1] = { "show_text", "_OaksLabRivalTakesText4" }
    rows[#rows + 1] = { "show_text", "_OaksLabRivalTakesText5" }
    if py == 4 then
      rows[#rows + 1] = { "walk_npc", "player",
        { "left", "down", "left", "left", "left", "up", "up" } }
    end
    rows[#rows + 1] = { "face_player_dir", "up" }
    rows[#rows + 1] = { "face_object", 3, "down" }
    ow.runner:run(rows, { npc = npc, onDone = done })
    return true
  end

  local function earlyClaimEligible(game)
    local flags = game.save.flags or {}
    local s = state(game.save)
    return active(game.save) and s and not s.rivalBallTaken
      and not s.partnerChosen and not flags.EVENT_GOT_STARTER
      and flags.EVENT_FOLLOWED_OAK_INTO_LAB == true
  end

  local function finishReceived(controller, species, ball)
    local game, ow, npc, done = controller.game, controller.ow,
      controller.npc, controller.done
    local rows = {}
    if controller.yellow and not controller.yellowClaimed then
      rows[#rows + 1] = { "emote", 1, "shock" }
      rows[#rows + 1] = { "move_npc_to", 1, 7, 4 }
      rows[#rows + 1] = { "face_object", 1, "up" }
      rows[#rows + 1] = { "show_text", "_OaksLabRivalIllTakeThisOneText" }
      rows[#rows + 1] = { "hide_object", MAP,
        "OAKSLAB_EEVEE_POKE_BALL" }
    else
      local object = ball == "left" and LEFT_OBJECT or MIDDLE_OBJECT
      hideBall(game, ow, object)
    end
    game.stringBuffer = game.data.pokemon[species].name or species
    rows[#rows + 1] = { "play_sound", "Get_Key_Item" }
    rows[#rows + 1] = { "show_text",
      "_KantoAscendantLegacyReceivedPartner",
      { RAM = game.data.pokemon[species].name or species } }
    ow.runner:run(rows, { npc = npc, onDone = done })
  end

  local function controller(game, ow, npc, done, config)
    local c = { game = game, ow = ow, npc = npc, done = done,
      yellow = config and config.yellow == true,
      yellowClaimed = config and config.yellowClaimed == true }
    function c:onPartnerChosen(species, ball)
      finishReceived(self, species, ball)
    end
    function c:onCatalogCancelled()
      if self.done then self.done() end
    end
    return c
  end

  local function openChoice(game, ow, npc, done, kind)
    local ok = legacyPrerequisite(game)
    if not ok then
      hint(game, done, tr(
        "OAK: These balls are\nalready empty.",
        "EICH: Diese Bälle sind\nbereits leer."))
      return
    end
    ensureLegacyBeyond(game, function()
      rivalTakesBall(game, ow, npc, function()
      local c = controller(game, ow, npc, done)
      if kind == "left" then
        if not beyondActive(game.save) then
          hint(game, done, beyondLockedText())
          return
        end
        if not hoennUnlocked(game.save) then
          local locked = HOENN_LOCKED_TEXT[character(game.save)]
          hint(game, done, tr(locked.en, locked.de))
          return
        end
        local species = heroChoice(game.save).species
        local def = game.data.pokemon[species]
        game.stack:push(Catalog.new(game, c, {
          mode = "hoenn", modeLocked = true, ball = "left",
          rows = { { id = species, def = def, dex = def.dex } },
          source = "hoenn_ball",
        }))
      else
        game.stack:push(Catalog.new(game, c, {
          mode = "balanced", ball = "catalog", source = "catalog",
        }))
      end
      end)
    end, function()
      if done then done() end
    end)
  end

  local function ordinaryHandler(textConst)
    return function(game, ow, npc, done)
      local original = L.originalTalk[textConst]
      if not active(game.save) then
        runOriginal(original, game, ow, npc, done)
        return
      end
      if textConst == RIGHT_TEXT then
        if not state(game.save).rivalBallTaken then
          rivalTakesBall(game, ow, npc, done)
        else
          hint(game, done, tr(
            "OAK: Your rival already\ntook that sealed ball.",
            "EICH: Dein Rivale nahm\nden versiegelten Ball."))
        end
      elseif textConst == LEFT_TEXT then
        openChoice(game, ow, npc, done, "left")
      else
        openChoice(game, ow, npc, done, "catalog")
      end
    end
  end

  local function yellowChoiceMenu(game, ow, npc, done, boundaryReady)
    local s = state(game.save)
    if not (s and s.rivalBallTaken) then return false end
    if s.partnerChosen then
      hint(game, done, tr(
        "OAK: Your partner is\nalready beside you.",
        "EICH: Dein Partner ist\nschon an deiner Seite."))
      return true
    end
    if not boundaryReady and not beyondActive(game.save) then
      ensureLegacyBeyond(game, function()
        yellowChoiceMenu(game, ow, npc, done, true)
      end, function()
        if done then done() end
      end)
      return true
    end
    local ListMenu = mod.ui.KantoListMenu or mod.ui.ListMenu
    local hero = heroChoice(game.save)
    local rows = {
      { label = tr("PIKACHU SPECIAL", "PIKACHU-SPEZIAL"), value = "pikachu" },
      { label = hoennUnlocked(game.save)
          and beyondActive(game.save) and hero.species
          or tr("HOENN [LOCKED]", "HOENN [GESP.]"),
        value = "hoenn" },
      { label = tr("OAK CATALOG", "EICHS KATALOG"), value = "catalog" },
    }
    local menu
    menu = ListMenu.new(game, tr("OAK: YOUR PARTNER", "EICH: DEIN PARTNER"),
      rows, {
        onChoose = function(item)
          if not item then return end
          if item.value == "hoenn" and not hoennUnlocked(game.save) then
            local locked = HOENN_LOCKED_TEXT[character(game.save)]
            hint(game, nil, tr(locked.en, locked.de))
            return
          end
          if item.value == "hoenn" and not beyondActive(game.save) then
            hint(game, nil, beyondLockedText())
            return
          end
          if game.stack:top() == menu then game.stack:pop() end
          local c = controller(game, ow, npc, done,
            { yellow = true, yellowClaimed = true })
          if item.value == "pikachu" then
            local def = game.data.pokemon.PIKACHU
            game.stack:push(Catalog.new(game, c, {
              mode = "yellow", modeLocked = true, ball = "yellow",
              rows = { { id = "PIKACHU", def = def, dex = def.dex } },
              source = "yellow_pikachu",
            }))
          elseif item.value == "hoenn" then
            local def = game.data.pokemon[hero.species]
            game.stack:push(Catalog.new(game, c, {
              mode = "hoenn", modeLocked = true, ball = "yellow_direct",
              rows = { { id = hero.species, def = def, dex = def.dex } },
              source = "yellow_hoenn",
            }))
          else
            game.stack:push(Catalog.new(game, c, {
              mode = "balanced", ball = "catalog", source = "yellow_catalog",
            }))
          end
        end,
        onCancel = done,
      })
    game.stack:push(menu)
    return true
  end

  local function yellowHandler(game, ow, npc, done)
    local original = L.originalTalk[YELLOW_TEXT]
    if not active(game.save) then
      runOriginal(original, game, ow, npc, done)
      return
    end
    local flags = game.save.flags or {}
    if flags.EVENT_GOT_STARTER or not flags.EVENT_OAK_ASKED_TO_CHOOSE_MON then
      runOriginal(original, game, ow, npc, done)
      return
    end
    yellowRivalTakesBall(game, ow, npc, function()
      yellowChoiceMenu(game, ow, npc, done)
    end)
  end

  -- After cancellation or reload the sole ball is gone. Oak remains the
  -- explicit host and reopens the same three-path menu when spoken to.
  local function yellowOakHandler(game, ow, npc, done)
    local s = state(game.save)
    if active(game.save) and s and s.rivalBallTaken and not s.partnerChosen then
      return yellowChoiceMenu(game, ow, npc, done)
    end
    runOriginal(L.originalTalk[OAK_TEXT], game, ow, npc, done)
  end

  local function blockLabExit(game, ow, y)
    if not labExitLocked(game.save) or (tonumber(y) or 0) < 6 then return false end
    ow.runner:run({
      { "show_text", "_KantoAscendantLegacyLabLocked" },
      { "move_player", "up", math.max(1, (tonumber(y) or 6) - 5) },
    })
    return true
  end

  local function runAuthoredLabStep(activeGame, ow, x, y, filterPikachu, ...)
    if not L.originalOnStep then return false end
    local runner = ow and ow.runner
    if not (runner and type(runner.run) == "function") then
      return L.originalOnStep(activeGame, ow, x, y, ...)
    end
    local originalRun = runner.run
    runner.run = function(self, rows, runOpts)
      local presented, rivalReceipt = {}, false
      for _, row in ipairs(rows or {}) do
        local pikachuBeat = filterPikachu and (
          row[1] == "play_cry" and row[2] == "PIKACHU"
          or row[1] == "show_text" and (
            row[2] == "_OaksLabPikachuDislikesPokeballsText1"
            or row[2] == "_OaksLabPikachuDislikesPokeballsText2"))
        if not pikachuBeat then presented[#presented + 1] = row end
        if row[1] == "set_flag"
            and row[2] == "EVENT_BATTLED_RIVAL_IN_OAKS_LAB" then
          rivalReceipt = true
        end
      end
      if rivalReceipt and type(journey.onLabRivalResolved) == "function" then
        local prior = runOpts and runOpts.onDone
        local wrapped = {}
        for key, value in pairs(runOpts or {}) do wrapped[key] = value end
        wrapped.onDone = function(...)
          journey.onLabRivalResolved(activeGame)
          if prior then return prior(...) end
        end
        runOpts = wrapped
      end
      return originalRun(self, presented, runOpts)
    end
    local ok, result = pcall(L.originalOnStep,
      activeGame, ow, x, y, ...)
    runner.run = originalRun
    if not ok then error(result, 0) end
    return result
  end

  function L.refresh(game)
    if not (game and L.mapScripts and L.mapScripts.get) then return false end
    local scripts = L.mapScripts.get(MAP)
    if not (scripts and type(scripts.talk) == "table") then return false end
    local yellow = scripts.talk[YELLOW_TEXT] ~= nil
    if yellow then
      L.originalTalk[YELLOW_TEXT] = L.originalTalk[YELLOW_TEXT]
        or scripts.talk[YELLOW_TEXT]
      L.originalTalk[OAK_TEXT] = L.originalTalk[OAK_TEXT]
        or scripts.talk[OAK_TEXT]
      scripts.talk[YELLOW_TEXT] = yellowHandler
      scripts.talk[OAK_TEXT] = yellowOakHandler
      L.originalOnStep = L.originalOnStep or scripts.onStep
      scripts.onStep = function(activeGame, ow, x, y, ...)
        if blockLabExit(activeGame, ow, y) then return true end
        local s = state(activeGame.save)
        local suppressPikachuBeat = active(activeGame.save) and s
          and s.partnerChosen and s.partnerSpecies ~= "PIKACHU"
          and activeGame.save.flags.EVENT_GOT_STARTER
          and not activeGame.save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB
          and y >= 6
        return runAuthoredLabStep(activeGame, ow, x, y,
          suppressPikachuBeat == true, ...)
      end
    else
      for _, textConst in ipairs({ LEFT_TEXT, MIDDLE_TEXT, RIGHT_TEXT }) do
        L.originalTalk[textConst] = L.originalTalk[textConst]
          or scripts.talk[textConst]
      end
      scripts.talk[LEFT_TEXT] = ordinaryHandler(LEFT_TEXT)
      scripts.talk[MIDDLE_TEXT] = ordinaryHandler(MIDDLE_TEXT)
      scripts.talk[RIGHT_TEXT] = ordinaryHandler(RIGHT_TEXT)

      L.originalOnEnter = L.originalOnEnter or scripts.onEnter
      L.originalOnStep = L.originalOnStep or scripts.onStep
      scripts.onEnter = function(activeGame, ow, ...)
        if L.originalOnEnter then L.originalOnEnter(activeGame, ow, ...) end
        if earlyClaimEligible(activeGame) then
          rivalTakesBall(activeGame, ow, nil, function() end)
        end
      end
      scripts.onStep = function(activeGame, ow, x, y, ...)
        if blockLabExit(activeGame, ow, y) then return true end
        -- A Legacy Fresh Save is already inside Oak's Lab when CharacterSelect
        -- binds the new avatar.  Its first physical step is therefore the
        -- earliest reliable post-selection boundary.  Claim the rival ball
        -- before the vanilla Lab onStep can consume that same cell; doing it
        -- afterwards let an authored trigger skip the rival scene entirely.
        if earlyClaimEligible(activeGame) then
          rivalTakesBall(activeGame, ow, nil, function() end)
          return true
        end
        local handled = runAuthoredLabStep(activeGame, ow, x, y, false, ...)
        if handled then return handled end
        return false
      end
    end

    local s = state(game.save)
    if active(game.save) and s then
      game.save.objectToggles = type(game.save.objectToggles) == "table"
        and game.save.objectToggles or {}
      game.save.objectToggles[MAP] = type(game.save.objectToggles[MAP]) == "table"
        and game.save.objectToggles[MAP] or {}
      if s.rivalBallTaken or s.partnerChosen then
        game.save.objectToggles[MAP][yellow
          and "OAKSLAB_EEVEE_POKE_BALL" or RIGHT_OBJECT] = false
      end
      if s.partnerChosen then
        local own = s.partnerBall == "left" and LEFT_OBJECT or MIDDLE_OBJECT
        if not yellow then game.save.objectToggles[MAP][own] = false end
      end
    end
    return true
  end

  function L.install(game, deps)
    deps = deps or {}
    L.game = game or L.game
    L.mapScripts = deps.mapScripts or L.mapScripts
      or require("data.scripts.init")
    if opts.rival and opts.rival.bindGame then opts.rival.bindGame(L.game) end
    L.installed = L.refresh(L.game)
    return L.installed
  end

  mod.events:on("save.loaded", function(ev)
    if ev and ev.game then
      L.refresh(ev.game)
      recoverAuthoredPartner(ev.game, true)
    end
    if ev and ev.save and journey.syncPartner
        and state(ev.save) and state(ev.save).partnerChosen then
      journey.syncPartner(ev.save)
    end
  end, 4200)
  mod.events:on("save.writing", function(ev)
    local game = L.game
    if game and ev and ev.save == game.save then
      -- Runs inside the engine's one real save transaction: no recursive
      -- write and no archive mirror before the filesystem commit.
      recoverAuthoredPartner(game, false)
    end
  end, 4200)
  mod.events:on("save.created", function()
    if L.game then L.refresh(L.game) end
  end, 4200)
  L.rows = canonicalRows
  L.growthLabel = growthLabel
  L.typesLabel = typesLabel
  L.heroChoice = heroChoice
  L.hoennUnlocked = hoennUnlocked
  L.legendaryUnlocked = durableThreePathsComplete
  L.legendaryIds = copy(LEGACY_ELITE_IDS)
  L.legendaryOrder = copy(LEGACY_ELITE_ORDER)
  L.legendaryMoveSets = copy(LEGACY_ELITE_MOVES)
  L.legendaryEarlyStab = copy(LEGACY_ELITE_STAB)
  L.legalMoveSource = legalMoveSource
  L.legendaryMoveSlots = eliteMoveSlots
  L.balancedIds = copy(BALANCED_PARTNER_IDS)
  L.canonicalOrder = copy(CANONICAL_ORDER)
  L.partnerAllowlist = copy(PARTNER_ALLOWLIST)
  L.partnerAllowlistOrder = copy(PARTNER_ALLOWLIST_ORDER)
  -- Kept as compatibility aliases for callers predating the explicit name.
  L.basePartnerIds = copy(PARTNER_ALLOWLIST)
  L.basePartnerOrder = copy(PARTNER_ALLOWLIST_ORDER)
  L.evolutionGraph = copy(EVOLUTION_GRAPH)
  L.Catalog = Catalog
  L.recoverAuthoredPartner = recoverAuthoredPartner
  L.labExitLocked = labExitLocked
  L.partnerMarker = PARTNER_MARKER
  L.beyondActive = beyondActive
  L.partnerDexMax = partnerDexMax
  L.ensureLegacyBeyond = ensureLegacyBeyond
  L.crystalSpritePath = crystalSpritePath
  L.beyondLockedText = beyondLockedText
  function L.partner(game)
    local save = game and game.save
    local s = save and state(save)
    if not (s and s.partnerChosen) then return nil end
    local exact
    for _, mon in ipairs(save.party or {}) do
      if type(mon) == "table" and mon[PARTNER_MARKER] == true then
        return mon
      end
      if mon.species == s.partnerSpecies then
        if exact then exact = false else exact = mon end
      end
    end
    -- Migration for RC saves created before the durable per-Pokemon marker:
    -- adopt only one unambiguous in-party match. Never guess by party slot.
    if type(exact) == "table" then
      exact[PARTNER_MARKER] = true
      return exact
    end
    return nil
  end
  return L
end
