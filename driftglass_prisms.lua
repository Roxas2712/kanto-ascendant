-- Driftglass Prism Grotto.
--
-- Five short, repeatable statue-sequence riddles provide one guaranteed copy
-- of every Johto evolution item.  A sixth repeatable rite raises one Eevee's
-- Johto bond to the existing day/night evolution threshold.  The grotto uses
-- only native CAVERN blocks and object sprites so 2D, Yellow palettes and
-- Dramatic Shape/Voxel can render it without a separate art provider.

local Module = {
  MAP_ID = "KANTO_ASCENDANT_PRISM_GROTTO",
  MAP_INDEX = 1901,
  OUTPOST_MAP_ID = "KANTO_ASCENDANT_DRIFTGLASS",
  PALLET_MAP_ID = "PALLET_TOWN",
  ARRIVAL = { x = 7, y = 12, facing = "up" },
  RETURN = { x = 12, y = 10, facing = "down" },
}

local TEXT = {
  READER = "TEXT_KA_PRISM_READER",
  TABLET = "TEXT_KA_PRISM_TABLET",
  EXIT = "TEXT_KA_PRISM_EXIT",
  SIGN = "TEXT_KA_PRISM_SIGN",
  SUN = "TEXT_KA_PRISM_SUN",
  MOON = "TEXT_KA_PRISM_MOON",
  WAVE = "TEXT_KA_PRISM_WAVE",
  CROWN = "TEXT_KA_PRISM_CROWN",
  DRAGON = "TEXT_KA_PRISM_DRAGON",
  GEAR = "TEXT_KA_PRISM_GEAR",
}

local STATUES = {
  {
    key = "SUN", text = TEXT.SUN, x = 2, y = 8,
    sprite = "SPRITE_KA_PRISM_SUN", asset = "prism_sun.png",
  },
  {
    key = "MOON", text = TEXT.MOON, x = 4, y = 8,
    sprite = "SPRITE_KA_PRISM_MOON", asset = "prism_moon.png",
  },
  {
    key = "WAVE", text = TEXT.WAVE, x = 6, y = 8,
    sprite = "SPRITE_KA_PRISM_WAVE", asset = "prism_wave.png",
  },
  {
    key = "CROWN", text = TEXT.CROWN, x = 9, y = 8,
    sprite = "SPRITE_KA_PRISM_CROWN", asset = "prism_crown.png",
  },
  {
    key = "DRAGON", text = TEXT.DRAGON, x = 11, y = 8,
    sprite = "SPRITE_KA_PRISM_DRAGON", asset = "prism_dragon.png",
  },
  {
    key = "GEAR", text = TEXT.GEAR, x = 13, y = 8,
    sprite = "SPRITE_KA_PRISM_GEAR", asset = "prism_gear.png",
  },
}

local SYMBOL_LABELS = {
  SUN = { "SUN", "SONNE" },
  MOON = { "MOON", "MOND" },
  WAVE = { "WAVE", "WELLE" },
  CROWN = { "CROWN", "KRONE" },
  DRAGON = { "DRAGON", "DRACHE" },
  GEAR = { "GEAR", "ZAHNRAD" },
}

local PUZZLE_ORDER = {
  "sunStone", "kingsRock", "metalCoat", "dragonScale", "upgrade",
  "twilight",
}

local PUZZLES = {
  sunStone = {
    item = "SUN_STONE",
    sequence = { "MOON", "WAVE", "CROWN", "SUN" },
    title = { "SUN PRISM", "SONNENPRISMA" },
    menu = { "SUN PRISM", "SONNENPRISMA" },
    riddle = {
      "INSCRIPTION:\nFrom deep night,\nfollow the tide.\f"
        .. "Pass beneath the\ncrown and greet\nthe first sun.",
      "INSCHRIFT:\nAus tiefster Nacht\nfolge der Flut.\f"
        .. "Unter der Krone\nbegrüße die erste\nSonne.",
    },
  },
  kingsRock = {
    item = "KINGS_ROCK",
    sequence = { "SUN", "CROWN", "WAVE", "CROWN" },
    title = { "CROWN GLASS", "KRONENGLAS" },
    menu = { "CROWN GLASS", "KRONENGLAS" },
    riddle = {
      "INSCRIPTION:\nAt dawn the king\nwears his crown.\f"
        .. "He crosses the sea\nand is crowned\nonce more.",
      "INSCHRIFT:\nIm Morgenlicht\nträgt der König\ndie Krone.\f"
        .. "Er quert das Meer\nund wird erneut\ngekrönt.",
    },
  },
  metalCoat = {
    item = "METAL_COAT",
    sequence = { "GEAR", "DRAGON", "GEAR", "SUN" },
    title = { "IRON ECHO", "EISENECHO" },
    menu = { "IRON ECHO", "EISENECHO" },
    riddle = {
      "INSCRIPTION:\nThe old gear bites\na dragon scale.\f"
        .. "Turn gear again\ntill metal catches\nlight.",
      "INSCHRIFT:\nDas alte Zahnrad\nfasst eine\nDrachenschuppe.\f"
        .. "Dreh es erneut,\nbis Metall\nim Licht glänzt.",
    },
  },
  dragonScale = {
    item = "DRAGON_SCALE",
    sequence = { "WAVE", "DRAGON", "CROWN", "DRAGON" },
    title = { "DRAGON SPIRAL", "DRACHENSPIRALE" },
    menu = { "DRAGON", "DRACHE" },
    riddle = {
      "INSCRIPTION:\nA scale rises from\nthe sea as dragon.\f"
        .. "It circles crown\nand returns to its\ntrue shape.",
      "INSCHRIFT:\nEine Schuppe\nsteigt aus\ndem Meer.\f"
        .. "Als Drache\numkreist sie Krone\nund wird wieder\nDrache.",
    },
  },
  upgrade = {
    item = "UPGRADE",
    sequence = { "WAVE", "GEAR", "SUN" },
    title = { "OLD CIRCUIT", "ALTES SCHALTWERK" },
    menu = { "OLD CIRCUIT", "SCHALTWERK" },
    riddle = {
      "INSCRIPTION:\nThe sea feeds the\nold gear.\f"
        .. "Its final tooth\nturns; sunlight\nwakes the circuit.",
      "INSCHRIFT:\nDas Meer nährt das\nalte Zahnrad.\f"
        .. "Dreht der letzte\nZahn, weckt Sonne\nden Schaltkreis.",
    },
  },
  twilight = {
    sequence = {
      "SUN", "MOON", "SUN", "SUN", "MOON",
      "SUN", "MOON", "SUN", "SUN", "MOON",
    },
    title = { "TWILIGHT MIRROR", "DÄMMERUNGSSPIEGEL" },
    menu = { "TWILIGHT", "DÄMMERUNG" },
    riddle = {
      "INSCRIPTION:\nRepeat this twice:\nDawn. Dusk. Dawn.\f"
        .. "Dawn once more.\nThen dusk.\f"
        .. "Only EEVEE may\ncarry the answer.",
      "INSCHRIFT:\nZweimal dieselbe\nFolge:\f"
        .. "Sonne. Mond.\nSonne. Sonne.\nMond.\f"
        .. "Nur EVOLI darf\ndie Antwort\ntragen.",
    },
  },
}

-- Crystal's legal Generation-II move access for the original 151, narrowed
-- to moves Kanto Ascendant actually implements.  TM and inherited moves are
-- available immediately; genuine level-up moves keep their Crystal level.
-- Species that can carry an inherited move through evolution are included in
-- the same family so an already-evolved partner is not punished.
local RESONANCE_MOVE_ORDER = {
  "CRUNCH", "METAL_CLAW", "IRON_TAIL", "SHADOW_BALL",
  "FLAME_WHEEL", "GIGA_DRAIN", "SLUDGE_BOMB", "POWDER_SNOW",
}

local RESONANCE_RULES = {
  CRUNCH = {
    inherited = {
      "EKANS", "ARBOK", "GROWLITHE", "ARCANINE", "RHYHORN", "RHYDON",
    },
  },
  METAL_CLAW = {
    inherited = { "SANDSHREW", "SANDSLASH" },
  },
  IRON_TAIL = {
    machine = {
      "AERODACTYL", "ARCANINE", "BLASTOISE", "CHANSEY", "CHARIZARD",
      "CHARMANDER", "CHARMELEON", "CLEFABLE", "CLEFAIRY", "CUBONE",
      "DRAGONAIR", "DRAGONITE", "DRATINI", "EEVEE", "ELECTABUZZ",
      "FARFETCHD", "FLAREON", "GOLDUCK", "GROWLITHE", "JOLTEON",
      "KANGASKHAN", "LAPRAS", "LICKITUNG", "MAGMAR", "MANKEY",
      "MAROWAK", "MEOWTH", "MEW", "MEWTWO", "NIDOKING", "NIDOQUEEN",
      "NIDORAN_F", "NIDORAN_M", "NIDORINA", "NIDORINO", "NINETALES",
      "ONIX", "PERSIAN", "PIKACHU", "PONYTA", "PORYGON", "PRIMEAPE",
      "PSYDUCK", "RAICHU", "RAPIDASH", "RATICATE", "RATTATA", "RHYDON",
      "RHYHORN", "SANDSHREW", "SANDSLASH", "SLOWBRO", "SLOWPOKE",
      "SQUIRTLE", "TAUROS", "VAPOREON", "VULPIX", "WARTORTLE",
    },
  },
  SHADOW_BALL = {
    machine = {
      "ABRA", "ALAKAZAM", "CHANSEY", "CLEFABLE", "CLEFAIRY", "DROWZEE",
      "EEVEE", "FLAREON", "GASTLY", "GENGAR", "HAUNTER", "HYPNO",
      "JIGGLYPUFF", "JOLTEON", "JYNX", "KADABRA", "KANGASKHAN",
      "LICKITUNG", "MEOWTH", "MEW", "MEWTWO", "MR_MIME", "NIDOKING",
      "NIDOQUEEN", "PERSIAN", "RATICATE", "RATTATA", "SLOWBRO",
      "SLOWPOKE", "SNORLAX", "VAPOREON", "WIGGLYTUFF",
    },
  },
  FLAME_WHEEL = {
    inherited = { "RATTATA", "RATICATE", "PONYTA", "RAPIDASH" },
    level = { ARCANINE = 1, GROWLITHE = 34 },
  },
  GIGA_DRAIN = {
    machine = {
      "ARBOK", "BEEDRILL", "BELLSPROUT", "BULBASAUR", "BUTTERFREE",
      "EKANS", "EXEGGCUTE", "EXEGGUTOR", "GASTLY", "GENGAR", "GLOOM",
      "GOLBAT", "GRIMER", "HAUNTER", "IVYSAUR", "KABUTO", "KABUTOPS",
      "MEW", "MUK", "ODDISH", "PARAS", "PARASECT", "TANGELA",
      "TENTACOOL", "TENTACRUEL", "VENOMOTH", "VENONAT", "VENUSAUR",
      "VICTREEBEL", "VILEPLUME", "WEEPINBELL", "ZUBAT",
    },
  },
  SLUDGE_BOMB = {
    machine = {
      "ARBOK", "BEEDRILL", "BELLSPROUT", "DIGLETT", "DUGTRIO", "EKANS",
      "EXEGGCUTE", "EXEGGUTOR", "GLOOM", "GRIMER", "KOFFING", "MEW",
      "MUK", "ODDISH", "PARAS", "PARASECT", "TANGELA", "TENTACOOL",
      "TENTACRUEL", "VENOMOTH", "VENONAT", "VICTREEBEL", "VILEPLUME",
      "WEEPINBELL", "WEEZING",
    },
  },
  POWDER_SNOW = {
    level = { ARTICUNO = 1, JYNX = 1 },
  },
}

local RESONANCE_BY_SPECIES = {}
local SOURCE_PRIORITY = { level = 1, inherited = 2, machine = 3 }
local function addResonanceRule(species, move, source, level)
  local speciesRules = RESONANCE_BY_SPECIES[species]
  if not speciesRules then
    speciesRules = {}
    RESONANCE_BY_SPECIES[species] = speciesRules
  end
  local current = speciesRules[move]
  if not current
      or SOURCE_PRIORITY[source] > SOURCE_PRIORITY[current.source] then
    speciesRules[move] = {
      move = move,
      source = source,
      level = source == "level" and math.max(1, level or 1) or nil,
    }
  end
end

for move, rules in pairs(RESONANCE_RULES) do
  for _, source in ipairs({ "inherited", "machine" }) do
    for _, species in ipairs(rules[source] or {}) do
      addResonanceRule(species, move, source)
    end
  end
  for species, level in pairs(rules.level or {}) do
    addResonanceRule(species, move, "level", level)
  end
end

local function packed(rows)
  local width = #rows[1]
  local blocks = {}
  for rowIndex, row in ipairs(rows) do
    assert(#row == width,
      ("Prism Grotto row %d has %d blocks; expected %d")
        :format(rowIndex, #row, width))
    for _, block in ipairs(row) do blocks[#blocks + 1] = block end
  end
  return blocks, width, #rows
end

function Module.create(mod, opts)
  assert(mod and mod.content, "Prism Grotto requires mod.content")
  opts = opts or {}
  local state = assert(opts.state, "Prism Grotto state missing")
  local content = assert(opts.content, "Driftglass content missing")
  local i18n = opts.i18n
  local fieldTech = opts.fieldTech
  local tilesets = mod.content.tilesets
  local catalogAware = type(tilesets) == "table"
    and type(tilesets.get) == "function"
  local mapSupported = content.mapSupported ~= false
    and (not catalogAware or tilesets:get("CAVERN") ~= nil)

  local P = {
    game = nil,
    registered = false,
    installed = false,
    mapSupported = mapSupported,
    MAP_ID = Module.MAP_ID,
    MAP_INDEX = Module.MAP_INDEX,
    OUTPOST_MAP_ID = Module.OUTPOST_MAP_ID,
    ARRIVAL = Module.ARRIVAL,
    RETURN = Module.RETURN,
    TEXT = TEXT,
    puzzles = PUZZLES,
    puzzleOrder = PUZZLE_ORDER,
    statues = STATUES,
    resonanceMoveOrder = RESONANCE_MOVE_ORDER,
    resonanceRules = RESONANCE_BY_SPECIES,
  }

  local function tr(english, german)
    return i18n and i18n.text and i18n.text(english, german) or english
  end

  local function symbolName(key)
    local label = SYMBOL_LABELS[key] or { tostring(key), tostring(key) }
    return tr(label[1], label[2])
  end
  P.symbolName = symbolName

  local function pillarLegend()
    return tr(
      "Left to right:\nSUN MOON WAVE\fCROWN DRAGON GEAR",
      "Von links:\nSONNE MOND WELLE\fKRONE DRACHE RAD")
  end
  P.pillarLegend = pillarLegend

  local function persist()
    if type(state.persist) == "function" then return state.persist() end
  end

  local function prismState()
    local s = state.section("prismGrotto")
    s.version = 1
    s.introduced = s.introduced == true
    s.heard = type(s.heard) == "table" and s.heard or {}
    s.solved = type(s.solved) == "table" and s.solved or {}
    s.pendingRewards = type(s.pendingRewards) == "table"
      and s.pendingRewards or {}
    s.active = PUZZLES[s.active] and s.active or nil
    s.progress = math.max(0, math.floor(tonumber(s.progress) or 0))
    s.twilightCompletions = math.max(
      0, math.floor(tonumber(s.twilightCompletions) or 0))
    return s
  end

  local function earlyState()
    return state.section("earlyJohto")
  end

  local function show(game, text, onDone, boxOpts)
    if type(opts.showText) == "function" then
      return opts.showText(game, text, onDone, boxOpts)
    end
    game.stack:push(require("src.render.TextBox").new(
      game, text, onDone, boxOpts))
    return true
  end

  local function openList(game, title, rows, menuOpts)
    if type(opts.openMenu) == "function" then
      return opts.openMenu(game, title, rows, menuOpts)
    end
    game.stack:push(mod.ui.ListMenu.new(game, title, rows, menuOpts))
    return true
  end

  local function setFrozen(npc, value)
    if npc then npc.frozen = value and true or false end
  end

  local function currentMap(game)
    return game and game.overworld and game.overworld.map
      and game.overworld.map.id
      or game and game.save and game.save.player
      and game.save.player.map
  end

  local function warp(game, mapId, position)
    if mod.world and type(mod.world.warpTo) == "function" then
      local ok, reason = mod.world:warpTo(
        mapId, position.x, position.y, position.facing)
      if ok then return true end
      if reason and reason ~= "no overworld" then return nil, reason end
    end
    local ow = game and game.overworld
    if not (ow and ow.startWarpTo) then return nil, "no overworld" end
    ow:startWarpTo(mapId, position.x, position.y, position.facing)
    return true
  end

  local function itemName(game, item)
    local def = game and game.data and game.data.items
      and game.data.items[item]
    return def and def.name or item:gsub("_", " ")
  end

  local function addItem(game, item)
    if type(opts.addItem) == "function" then
      local ok, result = pcall(opts.addItem, game, item)
      return ok and result == true
    end
    local ok, Bag = pcall(require, "src.inventory.Bag")
    if not ok or type(Bag.add) ~= "function" then return false end
    game.save.inventory = type(game.save.inventory) == "table"
      and game.save.inventory or {}
    return Bag.add(game.save, item, 1, game.data) == true
  end

  local function reserveReward(s, item)
    for _, pending in ipairs(s.pendingRewards) do
      if pending == item then return false end
    end
    s.pendingRewards[#s.pendingRewards + 1] = item
    return true
  end

  local function claimPending(game)
    local s = prismState()
    local kept, names = {}, {}
    for _, item in ipairs(s.pendingRewards) do
      if addItem(game, item) then
        names[#names + 1] = itemName(game, item)
      else
        kept[#kept + 1] = item
      end
    end
    local changed = #kept ~= #s.pendingRewards
    s.pendingRewards = kept
    if changed then persist() end
    if #names > 0 then
      return tr(
        "PRISM READER:\nI kept these safe:\n",
        "PRISMENLESER:\nSicher verwahrt:\n")
        .. table.concat(names, ", ")
    elseif #kept > 0 then
      return tr(
        "PRISM READER:\nYour BAG is full.\f"
          .. "The formed items\nremain safe here.",
        "PRISMENLESER:\nDein BEUTEL ist voll.\f"
          .. "Die geformten Items\nbleiben hier sicher.")
    end
  end

  local function partySpecies(game, species)
    local found = {}
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if mon.species == species then found[#found + 1] = mon end
    end
    return found
  end

  local function eeveeForRite(game)
    local eevee = partySpecies(game, "EEVEE")
    for _, mon in ipairs(eevee) do
      if math.max(0, tonumber(mon.johtoBond) or 0) < 100 then return mon end
    end
    return eevee[1]
  end

  local function partyHint(game)
    local hints = {}
    if #partySpecies(game, "ESPEON") > 0 then
      hints[#hints + 1] = tr(
        "ESPEON warms the\nSUN pillar.",
        "PSIANA wärmt die\nSONNEN-Säule.")
    end
    if #partySpecies(game, "UMBREON") > 0 then
      hints[#hints + 1] = tr(
        "UMBREON shades the\nMOON pillar.",
        "NACHTARA trübt die\nMOND-Säule.")
    end
    return #hints > 0 and ("\f" .. table.concat(hints, "\f")) or ""
  end

  local function monName(game, mon)
    local def = game and game.data and game.data.pokemon
      and mon and game.data.pokemon[mon.species]
    return mon and (mon.nickname or (def and def.name) or mon.species)
      or tr("POKéMON", "POKéMON")
  end

  local function knowsMove(mon, moveId)
    for _, move in ipairs(mon and mon.moves or {}) do
      if move.id == moveId then return true end
    end
    return false
  end

  local function moveName(game, moveId)
    local def = game and game.data and game.data.moves
      and game.data.moves[moveId]
    return def and def.name or moveId:gsub("_", " ")
  end

  function P.resonanceMoves(game, mon)
    if not mon or mon.isEgg then return {}, "egg" end
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    local dex = tonumber(def and def.dex)
    if not dex or dex < 1 or dex > 151 then return {}, "not-kanto" end
    local legal = RESONANCE_BY_SPECIES[mon.species]
    if type(legal) ~= "table" then return {}, "none" end

    local rows, supported, known = {}, 0, 0
    for _, moveId in ipairs(RESONANCE_MOVE_ORDER) do
      local rule = legal[moveId]
      if rule and game.data.moves and game.data.moves[moveId] then
        supported = supported + 1
        if knowsMove(mon, moveId) then
          known = known + 1
        else
          rows[#rows + 1] = {
            id = moveId,
            source = rule.source,
            level = rule.level,
            locked = rule.level ~= nil
              and (tonumber(mon.level) or 1) < rule.level,
          }
        end
      end
    end
    if #rows > 0 then return rows end
    if supported > 0 and known == supported then return {}, "known" end
    return {}, "none"
  end

  local function rememberMove(mon, moveId)
    if fieldTech and type(fieldTech.recordRememberedMove) == "function" then
      fieldTech.recordRememberedMove(mon, moveId)
      return
    end
    mon.rememberedMoves = type(mon.rememberedMoves) == "table"
      and mon.rememberedMoves or {}
    mon.rememberedMoves[moveId] = true
  end

  function P.teachResonanceMove(game, mon, moveId)
    local candidates = P.resonanceMoves(game, mon)
    local candidate
    for _, row in ipairs(candidates) do
      if row.id == moveId then candidate = row break end
    end
    if not candidate then return false, "illegal" end
    if candidate.locked then return false, "level", candidate.level end
    local move = game.data.moves[moveId]
    if not move then return false, "missing" end

    mon.moves = type(mon.moves) == "table" and mon.moves or {}
    if #mon.moves >= 4 then return false, "full" end
    mon.moves[#mon.moves + 1] = { id = moveId, pp = move.pp or 0 }
    rememberMove(mon, moveId)
    return true
  end

  function P.dialogues(game)
    return {
      locked = tr(
        "The glass seam is\nsilent.\f"
          .. "Ask the researcher\nto fix it.",
        "Die Glasfuge ist\nstumm.\f"
          .. "Repariere erst den\nEmpfänger."),
      entrance = tr(
        "A dark split glows\nin the crystal.\f"
          .. "Behind it, a stair\ndescends.\f"
          .. "Enter the\nPRISM GROTTO?",
        "Ein dunkler Riss\nglüht im Kristall.\f"
          .. "Dahinter geht eine\nTreppe hinab.\f"
          .. "In die\nPRISMENGROTTE?"),
      intro = tr(
        "PRISM READER:\nThe tablet names\nthe six signs.\f"
          .. "Choose an\ninscription.\f"
          .. "Its deeper light\nalso awakens Johto\nmoves in Kanto\nPOKéMON.",
        "PRISMENLESER:\nDie Tafel benennt\ndie sechs Zeichen.\f"
          .. "Wähle eine\nInschrift.\f"
          .. "Ihr tieferes Licht\nweckt auch Johto-\nAttacken in Kanto-\nPOKéMON."),
      reader = tr(
        "PRISM READER:\nWhich inscription?\f"
          .. "For moves, touch\nthe tablet\nbehind me.",
        "PRISMENLESER:\nWelche Inschrift?\f"
          .. "Für Attacken\nberühre die Tafel\nhinter mir."),
      tablet = tr(
        "CRYSTAL TABLET:\nSix signs guard\nancient gifts.\f"
          .. "From left:\nSUN MOON WAVE\f"
          .. "CROWN DRAGON GEAR\f"
          .. "Read an\ninscription.\f"
          .. "Touch its signs\nin that order.",
        "KRISTALLTAFEL:\nSechs Zeichen\nhüten alte Gaben.\f"
          .. "Von links:\nSONNE MOND WELLE\f"
          .. "KRONE DRACHE RAD\f"
          .. "Lies eine\nInschrift.\f"
          .. "Berühre danach\ndie Zeichen\nin dieser Folge."),
      tabletResonance = tr(
        "\fCrystal seeks a\nKanto memory.\f"
          .. "Attune a Kanto\nPOKéMON?",
        "\fDer Kristall sucht\neine Kanto-\nErinnerung.\f"
          .. "Ein Kanto-POKéMON\neinstimmen?"),
      noActive = tr(
        "The pillar hums.\f"
          .. "At PRISM READER,\nchoose an\ninscription first.",
        "Die Säule summt.\f"
          .. "Wähle zuerst beim\nPRISMENLESER eine\nInschrift."),
      wrong = tr(
        "A dull crack runs\nthrough the glass.\f"
          .. "The sequence has\nreset.",
        "Ein dumpfer Riss\nläuft durchs Glas.\f"
          .. "Die Folge beginnt\nvon vorn."),
      exit = tr(
        "Return to the\nDRIFTGLASS POST?",
        "Zurück zum\nDRIFTGLAS-POSTEN?"),
      sign = tr(
        "PRISM GROTTO\nSIX VOICES\nONE MEMORY",
        "PRISMENGROTTE\nSECHS STIMMEN\nEINE ERINNERUNG"),
    }
  end

  local function noResonanceText(game, mon, reason)
    local name = monName(game, mon)
    if reason == "egg" then
      return tr(
        "The crystal cannot\nread an EGG yet.",
        "Der Kristall kann\nein EI noch nicht\nlesen.")
    elseif reason == "not-kanto" then
      return tr(
        "The crystal stays\nquiet.\f"
          .. "Only a POKéMON\nfirst recorded in\nKanto will answer.",
        "Der Kristall bleibt\nstill.\f"
          .. "Nur ein zuerst in\nKanto erfasstes\nPOKéMON antwortet.")
    elseif reason == "known" then
      return tr(
        name .. " already knows\nevery Johto move\nthis crystal holds.",
        name .. " kennt bereits\njede Johto-Attacke\ndieses Kristalls.")
    end
    return tr(
      "The crystal finds no\nJohto move for\n" .. name .. ".",
      "Der Kristall findet\nkeine Johto-Attacke\nfür " .. name .. ".")
  end

  local function learnedText(game, mon, moveId)
    return tr(
      ("%s awakened\n%s!"):format(monName(game, mon),
        moveName(game, moveId)),
      ("%s erweckte\n%s!"):format(monName(game, mon),
        moveName(game, moveId)))
  end

  local function sourceLabel(candidate)
    if candidate.source == "machine" then return "TM" end
    if candidate.source == "inherited" then
      return tr("EGG", "EI")
    end
    return ("LV%d"):format(candidate.level or 1)
  end

  function P.openResonanceMoves(game, mon, onDone)
    local candidates, reason = P.resonanceMoves(game, mon)
    if #candidates == 0 then
      return show(game, noResonanceText(game, mon, reason), onDone)
    end
    if #(mon.moves or {}) >= 4 then
      return show(game, tr(
        "Crystal needs an\nopen move slot.\f"
          .. "Use the Route 5\nMOVE DELETER, then\nreturn here.",
        "Kristall braucht\neinen freien Platz.\f"
          .. "Nutze den Attacken-\nVerlerner auf\nRoute 5 und kehre\nzurück."),
        onDone)
    end
    local rows = {}
    for _, candidate in ipairs(candidates) do
      rows[#rows + 1] = {
        label = moveName(game, candidate.id),
        right = sourceLabel(candidate),
        value = candidate,
      }
    end
    return openList(game, tr("JOHTO MEMORY", "JOHTO-ERINNERUNG"), rows, {
      onCancel = onDone,
      onChoose = function(item, menu)
        local candidate = item and item.value
        if not candidate then return end
        if menu and type(menu.close) == "function" then menu:close() end
        if candidate.locked then
          return show(game, tr(
            ("%s is still too\nweak.\fCome back at\nLv. %d.")
              :format(monName(game, mon), candidate.level),
            ("%s ist noch zu\nschwach.\fKomm auf Lv. %d\nzurück.")
              :format(monName(game, mon), candidate.level)), function()
            P.openResonanceMoves(game, mon, onDone)
          end)
        end

        local function finish()
          local learned = P.teachResonanceMove(game, mon, candidate.id)
          if learned then
            return show(game, learnedText(game, mon, candidate.id), onDone)
          end
          return show(game, tr(
            "The resonance\nfaded. Try again.",
            "Die Resonanz ist\nverklungen.\nVersuche es erneut."), onDone)
        end

        return finish()
      end,
    })
  end

  function P.openResonanceParty(game, onDone)
    local partyOpts = {
      pickOnly = true,
      onCancel = onDone,
      onSwitch = function(mon)
        P.openResonanceMoves(game, mon, onDone)
      end,
    }
    if type(opts.openParty) == "function" then
      return opts.openParty(game, partyOpts)
    end
    return require("src.ui.Screens").push(game, "PartyMenu", partyOpts)
  end

  function P.interactTablet(game, onDone)
    P.game = game or P.game
    game = game or P.game
    local dialogue = P.dialogues(game)
    return show(game, dialogue.tablet .. dialogue.tabletResonance, nil, {
      defaultNo = true,
      choice = function(yes)
        if yes then return P.openResonanceParty(game, onDone) end
        if onDone then onDone() end
      end,
    })
  end

  local function puzzleTitle(key)
    local title = PUZZLES[key].title
    return tr(title[1], title[2])
  end

  local function puzzleRiddle(key)
    local riddle = PUZZLES[key].riddle
    return tr(riddle[1], riddle[2])
  end

  local function puzzleMenuLabel(key)
    local label = PUZZLES[key].menu or PUZZLES[key].title
    return tr(label[1], label[2])
  end

  local function readerDetail(s, key)
    if key == "twilight" then
      return tr(
        "Repeatable EEVEE\nbond rite.",
        "Wiederholbares\nEVOLI-Bandritual.")
    end
    if s.solved[key] then
      return tr(
        itemName(P.game, PUZZLES[key].item) .. "\nFOUND",
        itemName(P.game, PUZZLES[key].item) .. "\nGEFUNDEN")
    end
    return s.heard[key] and tr(
      "Riddle heard.\nNot solved.",
      "Rätsel gehört.\nNicht gelöst.")
      or tr("Not yet read.", "Noch unbekannt.")
  end

  function P.archiveRows(game)
    P.game = game or P.game
    local s = prismState()
    local rows = {}
    for _, key in ipairs(PUZZLE_ORDER) do
      local status = key ~= "twilight" and s.solved[key]
          and "OK"
        or (not s.heard[key] and "NEW" or nil)
      rows[#rows + 1] = {
        label = puzzleMenuLabel(key),
        right = status,
        value = key,
        detail = readerDetail(s, key),
      }
    end
    return rows
  end

  local function finishReader(npc, onDone)
    setFrozen(npc, false)
    if onDone then onDone() end
  end

  local function beginPuzzle(game, key, npc, onDone)
    local s = prismState()
    if key == "twilight" and not eeveeForRite(game) then
      return show(game, tr(
        "PRISM READER:\nThe mirror answers\nonly an EEVEE.\f"
          .. "Bring one in your\nparty. Ask again.",
        "PRISMENLESER:\nDer Spiegel\nantwortet nur\neinem EVOLI.\f"
          .. "Bring EVOLI mit.\nDann frag erneut.")
        .. partyHint(game), function()
          P.openArchive(game, npc, onDone)
        end)
    end
    s.active = key
    s.progress = 0
    persist()
    return show(game, tr(
      "PRISM READER:\nThe sequence is\nlistening now.\f"
        .. "Follow the shown\nriddle words.",
      "PRISMENLESER:\nDie Folge lauscht\njetzt.\f"
        .. "Folge den Bildern\nder Inschrift."), function()
      finishReader(npc, onDone)
    end)
  end

  local function selectPuzzle(game, key, menu, npc, onDone)
    local s = prismState()
    s.heard[key] = true
    persist()
    if menu and type(menu.close) == "function" then menu:close() end
    local solved = key ~= "twilight" and s.solved[key] == true
    local prompt = solved and tr(
      "\fThis prism already\nyielded its item.\f"
        .. "Rehearse it again?",
      "\fDieses Prisma gab\nsein Item bereits.\f"
        .. "Folge wiederholen?")
      or tr(
        "\fAttempt this\ninscription?",
        "\fDiese Inschrift\nversuchen?")
    return show(game, puzzleRiddle(key)
      .. (key == "twilight" and partyHint(game) or "")
      .. prompt, nil, {
        defaultNo = true,
        choice = function(yes)
          if yes then return beginPuzzle(game, key, npc, onDone) end
          P.openArchive(game, npc, onDone)
        end,
      })
  end

  function P.openArchive(game, npc, onDone)
    P.game = game or P.game
    game = game or P.game
    setFrozen(npc, true)
    return openList(game, tr("PRISM ARCHIVE", "PRISMENARCHIV"),
      P.archiveRows(game), {
        onCancel = function() finishReader(npc, onDone) end,
        onChoose = function(item, menu)
          if item then
            selectPuzzle(game, item.value, menu, npc, onDone)
          end
        end,
      })
  end

  function P.interactReader(game, npc, onDone)
    P.game = game or P.game
    game = game or P.game
    setFrozen(npc, true)
    local pending = claimPending(game)
    local s = prismState()
    local function open()
      if not s.introduced then
        s.introduced = true
        persist()
        return show(game, P.dialogues(game).intro, function()
          P.openArchive(game, npc, onDone)
        end)
      end
      return show(game, P.dialogues(game).reader, function()
        P.openArchive(game, npc, onDone)
      end)
    end
    if pending then return show(game, pending, open) end
    return open()
  end

  local function rewardMessage(game, s, key)
    local puzzle = PUZZLES[key]
    if key == "twilight" then
      local eevee = eeveeForRite(game)
      if not eevee then
        return tr(
          "The mirror clears,\nbut no EEVEE answers.",
          "Der Spiegel klärt\nsich, doch kein EVOLI\nantwortet.")
      end
      eevee.johtoBond = math.max(
        100, math.max(0, tonumber(eevee.johtoBond) or 0))
      s.twilightCompletions = s.twilightCompletions + 1
      return tr(
        "Mirror wraps EEVEE\nin twilight.\f"
          .. "Its bond is ready.\f"
          .. "Gain one level by\nday for ESPEON,\f"
          .. "or by night for\nUMBREON.",
        "Der Spiegel hüllt\nEVOLI in\nDämmerung.\f"
          .. "Band ist bereit.\f"
          .. "Ein Level bei Tag\nführt zu PSIANA,\f"
          .. "bei Nacht zu\nNACHTARA.")
    end

    if s.solved[key] then
      return tr(
        "The prism repeats a\nclear remembered note.\f"
          .. "Its gift was already\nclaimed.",
        "Das Prisma wiederholt\neinen klaren Ton.\f"
          .. "Seine Gabe wurde\nbereits geborgen.")
    end
    s.solved[key] = true
    local name = itemName(game, puzzle.item)
    if addItem(game, puzzle.item) then
      return tr(
        "The glass opens.\fYou found:\n" .. name,
        "Das Glas öffnet.\fGefunden:\n" .. name)
    end
    reserveReward(s, puzzle.item)
    return tr(
      "The glass forms:\n" .. name .. "\f"
        .. "Your BAG is full.\f"
        .. "The PRISM READER\nwill keep it safe.",
      "Das Glas formt:\n" .. name .. "\f"
        .. "Dein BEUTEL ist voll.\f"
        .. "Der PRISMENLESER\nbewahrt es auf.")
  end

  function P.touchStatue(game, statueKey, onDone)
    P.game = game or P.game
    game = game or P.game
    local s = prismState()
    local puzzle = s.active and PUZZLES[s.active]
    if not puzzle then
      return show(game, tr(
        symbolName(statueKey) .. " PILLAR.\f"
          .. "Choose an\ninscription first.\f"
          .. "The tablet shows\nthe order.",
        symbolName(statueKey) .. "-SÄULE.\f"
          .. "Wähle zuerst eine\nInschrift.\f"
          .. "Die Tafel zeigt\ndie Reihenfolge."), onDone)
    end
    local expected = puzzle.sequence[s.progress + 1]
    if statueKey ~= expected then
      s.progress = 0
      persist()
      return show(game, tr(
        symbolName(statueKey) .. ":\nsounds dull.\f"
          .. "Expected:\n" .. symbolName(expected) .. ".\f"
          .. "The sequence has\nreset.",
        symbolName(statueKey) .. ":\nklingt dumpf.\f"
          .. "Gesucht:\n" .. symbolName(expected) .. ".\f"
          .. "Folge beginnt neu."), onDone)
    end
    s.progress = s.progress + 1
    local step, total = s.progress, #puzzle.sequence
    if step < total then
      persist()
      return show(game, tr(
        ("%s:\nclear note.\n%d/%d")
          :format(symbolName(statueKey), step, total),
        ("%s:\nklarer Ton.\n%d/%d")
          :format(symbolName(statueKey), step, total)), onDone)
    end
    local key = s.active
    s.active = nil
    s.progress = 0
    local message = rewardMessage(game, s, key)
    persist()
    return show(game, message, onDone)
  end

  function P.modeHint(mode)
    if mode == "UNLEASHED" then
      return tr(
        "\fRESEARCHER:\nBefore you leave,\nsee glass seam.\f"
          .. "The PRISM GROTTO\nholds tools early\nmigrants may need.",
        "\fFORSCHER:\nBevor du gehst,\nsieh zur Glasfuge.\f"
          .. "Die PRISMENGROTTE\nbirgt Hilfen für\nfrühe Wanderer.")
    end
    return tr(
      "\fRESEARCHER:\nGlass seam hides\nan extra grotto.\f"
        .. "Old riddles can\nhelp Johto species\nevolve.",
      "\fFORSCHER:\nDie Glasfuge birgt\neine freiwillige\nGrotte.\f"
        .. "Ihre Rätsel helfen\nJohto-Pokémon bei\nder Entwicklung.")
  end

  function P.enter(game, onDone)
    P.game = game or P.game
    game = game or P.game
    if not mapSupported then
      return show(game, tr(
        "The grotto cannot be\nmapped in this game.",
        "Die Grotte kann hier\nnicht kartiert werden."), onDone)
    end
    if earlyState().receiverRepaired ~= true then
      return show(game, P.dialogues(game).locked, onDone)
    end
    return show(game, P.dialogues(game).entrance, nil, {
      defaultNo = true,
      choice = function(yes)
        if yes then warp(game, Module.MAP_ID, Module.ARRIVAL) end
        if onDone then onDone() end
      end,
    })
  end

  function P.leave(game, onDone)
    P.game = game or P.game
    game = game or P.game
    return show(game, P.dialogues(game).exit, nil, {
      defaultNo = true,
      choice = function(yes)
        if yes then
          warp(game, Module.OUTPOST_MAP_ID, Module.RETURN)
        end
        if onDone then onDone() end
      end,
    })
  end

  function P.secureSaveLocation(save)
    local player = save and save.player
    if type(player) ~= "table" or player.map ~= Module.MAP_ID then
      return false
    end
    player.map = Module.PALLET_MAP_ID
    player.x = content.PALLET_RETURN and content.PALLET_RETURN.x or 10
    player.y = content.PALLET_RETURN and content.PALLET_RETURN.y or 12
    player.facing = content.PALLET_RETURN
      and content.PALLET_RETURN.facing or "up"
    player.surfing = false
    save.lastOutdoor = {
      id = Module.PALLET_MAP_ID,
      x = player.x,
      y = player.y,
    }
    return true
  end

  function P.progress()
    local s = prismState()
    local solved = 0
    for _, key in ipairs(PUZZLE_ORDER) do
      if key ~= "twilight" and s.solved[key] then solved = solved + 1 end
    end
    return solved, 5, s.twilightCompletions
  end

  function P.register()
    if P.registered then return false, "already registered" end
    if not mapSupported then
      P.registered = true
      return false, "CAVERN tileset unavailable"
    end

    if mod.content.sprites then
      mod.content.sprites:register("SPRITE_KA_PRISM_TABLET", {
        id = "SPRITE_KA_PRISM_TABLET",
        image = mod.path .. "/assets/prism_grotto/prism_tablet.png",
        frames = 1,
        walker = false,
        trueColor = true,
      })
      for _, statue in ipairs(STATUES) do
        mod.content.sprites:register(statue.sprite, {
          id = statue.sprite,
          image = mod.path .. "/assets/prism_grotto/" .. statue.asset,
          frames = 1,
          walker = false,
          trueColor = true,
        })
      end
    end

    local blocks, width, height = packed({
      { 32,33,33,33,33,33,33,34 },
      { 27, 1, 1, 1, 1, 1, 1,27 },
      { 27, 1, 1, 1, 1, 1, 1,27 },
      { 27, 1, 1, 1, 1, 1, 1,27 },
      { 27, 1, 1, 1, 1, 1, 1,27 },
      { 27, 1, 1, 1, 1, 1, 1,27 },
      { 27, 1, 1, 1, 1, 1, 1,27 },
      { 32,33,33,33,33,33,33,34 },
    })
    local objects = {
      {
        index = 1, name = "PRISM_TABLET",
        movement = "STAY", range = "NONE",
        sprite = "SPRITE_KA_PRISM_TABLET",
        text = TEXT.TABLET, x = 7, y = 3,
      },
      {
        index = 2, name = "PRISM_READER",
        movement = "STAY", range = "UP", sprite = "SPRITE_SCIENTIST",
        text = TEXT.READER, x = 7, y = 4,
      },
    }
    for index, statue in ipairs(STATUES) do
      objects[#objects + 1] = {
        index = index + 2,
        name = "PRISM_" .. statue.key,
        movement = "STAY", range = "NONE", sprite = statue.sprite,
        text = statue.text, x = statue.x, y = statue.y,
      }
    end
    P.mapRecord = {
      id = Module.MAP_ID,
      label = "DriftglassPrismGrotto",
      index = Module.MAP_INDEX,
      tileset = "CAVERN",
      palette = "CAVE",
      borderBlock = 3,
      width = width,
      height = height,
      blocks = blocks,
      warps = {},
      connections = {},
      objects = objects,
      signs = {
        { text = TEXT.EXIT, x = 7, y = 13 },
        { text = TEXT.SIGN, x = 2, y = 2 },
      },
    }
    mod.content.maps:register(Module.MAP_ID, P.mapRecord)
    -- The grotto keeps a distinct, ominous cave identity instead of carrying
    -- the island song through the custom-map transition.
    -- The ROM-free Modkit fixture intentionally has no music catalog. Skip
    -- the optional assignment only there; imported R/B/Y data exposes the
    -- native song and receives the intended cave theme.
    local music = mod.content.music
    if not (music and type(music.get) == "function")
        or music:get("Music_Dungeon1") then
      mod.content.map_songs:register(Module.MAP_ID, "Music_Dungeon1")
    end
    local talk = {
      [TEXT.TABLET] = function(game, _, _, onDone)
        return P.interactTablet(game, onDone)
      end,
      [TEXT.READER] = function(game, _, npc, onDone)
        return P.interactReader(game, npc, onDone)
      end,
      [TEXT.EXIT] = function(game, _, _, onDone)
        return P.leave(game, onDone)
      end,
      [TEXT.SIGN] = function(game, _, _, onDone)
        return show(game, P.dialogues(game).sign, onDone)
      end,
    }
    for _, statue in ipairs(STATUES) do
      local key = statue.key
      talk[statue.text] = function(game, _, _, onDone)
        return P.touchStatue(game, key, onDone)
      end
    end
    mod.content.map_scripts:register(Module.MAP_ID, {
      priority = 2610,
      talk = talk,
    })

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("save.writing", function(ev)
        P.secureSaveLocation(ev and ev.save)
      end, -10010)
    end
    P.registered = true
    return true
  end

  function P.install(game)
    P.game = game or P.game
    if state.install then state.install(P.game) end
    P.installed = P.game ~= nil
    return P.installed
  end

  function P.status()
    local solved, total, twilight = P.progress()
    return {
      registered = P.registered,
      installed = P.installed,
      mapSupported = P.mapSupported,
      mapId = P.MAP_ID,
      currentMap = currentMap(P.game),
      solved = solved,
      total = total,
      twilightCompletions = twilight,
    }
  end

  return P
end

return Module
