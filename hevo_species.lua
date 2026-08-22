-- KA-INTERNAL: HEVO-COMPAT-001
--
-- Narrow Package-3 content seam: seventeen Sinnoh evolutions of existing
-- Kanto/Johto families plus Azurill and Wynaut.  They occupy Ascendant's
-- private #261-279 slots; this does not enable a Sinnoh Pokédex or any other
-- Generation-IV species.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local data = assert(opts.data, "HEVO species data required")
  local packages = assert(opts.packages, "HEVO package registry required")
  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end
  local H = {
    order = {
      "AMBIPOM", "MISMAGIUS", "HONCHKROW", "WEAVILE", "MAGNEZONE",
      "LICKILICKY", "RHYPERIOR", "TANGROWTH", "ELECTIVIRE", "MAGMORTAR",
      "TOGEKISS", "YANMEGA", "LEAFEON", "GLACEON", "GLISCOR",
      "MAMOSWINE", "PORYGON_Z", "AZURILL", "WYNAUT",
    },
    source = data._meta,
    audit = { activeRows = 0, skippedRows = {}, species = {} },
    moveNames = {
      ROLLOUT = tr("ROLLOUT", "WALZER"),
      ANCIENTPOWER = tr("ANCIENTPOWER", "ANTIK-KRAFT"),
      DOUBLE_HIT = tr("DOUBLE HIT", "DOPPELSCHLAG"),
      LEAF_BLADE = tr("LEAF BLADE", "LAUBKLINGE"),
    },
  }

  -- The tiny SDK fixture intentionally contains no Kanto/Johto catalogue.
  -- Match postgame_species' feature gate so strict validation can exercise a
  -- minimal engine without creating dangling DARK/STEEL or parent refs.
  if opts.enabled == false then
    H.enabled = false
    function H.install() return false end
    if mod.exports then mod.exports.hevoSpeciesAudit = H.audit end
    return H
  end
  H.enabled = true

  local function levels(...)
    local flat, out = { ... }, {}
    for index = 1, #flat, 2 do
      out[#out + 1] = { level = flat[index], move = flat[index + 1] }
    end
    return out
  end

  -- Authored Gen1-Recomp projection.  The generated source beside this file
  -- remains the stat/size provenance, while these schedules deliberately use
  -- only moves whose battle mechanics exist in the merged engine.  Keeping
  -- this separate also prevents a future HGSS data refresh from restoring
  -- attractive-looking but inert move ids.
  local catalogue = {
    AMBIPOM = {
      kindEn = "LONG TAIL", kindDe = "LANGSCHWEIF",
      textEn = "Its two tails work like hands, letting it swing and gather fruit without stopping.",
      textDe = "Seine zwei Schweife greifen wie Hände, sodass es schwingend Früchte sammelt.",
      level1 = { "SCRATCH", "TAIL_WHIP", "SAND_ATTACK", "SWIFT" },
      learnset = levels(4, "SAND_ATTACK", 18, "FURY_SWIPES",
        22, "SWIFT", 25, "SCREECH", 29, "AGILITY", 32, "DOUBLE_HIT"),
      tmhm = { "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE", "PAY_DAY",
        "COUNTER", "THUNDERBOLT", "THUNDER", "DIG", "MIMIC",
        "DOUBLE_TEAM", "SWIFT", "REST", "THUNDER_WAVE", "SUBSTITUTE",
        "CUT", "STRENGTH" },
    },
    MISMAGIUS = {
      kindEn = "MAGICAL", kindDe = "MAGISCH",
      textEn = "Its chants can cause nightmares or fill listeners with sudden happiness.",
      textDe = "Seine Gesänge lösen Albträume aus oder erfüllen Zuhörer plötzlich mit Freude.",
      level1 = { "GROWL", "PSYWAVE", "CONFUSE_RAY", "SHADOW_BALL" },
      learnset = levels(15, "CONFUSE_RAY", 25, "PSYBEAM",
        35, "SHADOW_BALL", 45, "PSYCHIC_M"),
      tmhm = { "TOXIC", "PSYCHIC_M", "TELEPORT", "MIMIC",
        "DOUBLE_TEAM", "REFLECT", "BIDE", "METRONOME", "DREAM_EATER",
        "REST", "THUNDER_WAVE", "PSYWAVE", "SUBSTITUTE", "FLASH" },
    },
    HONCHKROW = {
      kindEn = "BIG BOSS", kindDe = "ANFÜHRER",
      textEn = "At dusk it summons Murkrow, then directs the flock with one deep cry.",
      textDe = "In der Dämmerung ruft es Kramurx und lenkt den Schwarm mit einem tiefen Ruf.",
      level1 = { "PECK", "HAZE", "WING_ATTACK", "FAINT_ATTACK" },
      learnset = levels(25, "SWIFT", 35, "DRILL_PECK",
        45, "FAINT_ATTACK", 55, "SKY_ATTACK"),
      tmhm = { "TOXIC", "TAKE_DOWN", "DOUBLE_EDGE", "HYPER_BEAM",
        "MIMIC", "DOUBLE_TEAM", "BIDE", "SWIFT", "REST", "SKY_ATTACK",
        "SUBSTITUTE", "FLY" },
    },
    WEAVILE = {
      kindEn = "SHARP CLAW", kindDe = "SCHARFKLAUE",
      textEn = "A pack leaves coded claw marks in ice before surrounding its prey.",
      textDe = "Ein Rudel ritzt Zeichen ins Eis, bevor es seine Beute gemeinsam einkreist.",
      level1 = { "SCRATCH", "LEER", "QUICK_ATTACK", "FAINT_ATTACK" },
      learnset = levels(10, "SCREECH", 21, "FURY_SWIPES",
        28, "POWDER_SNOW", 35, "SLASH", 42, "METAL_CLAW",
        49, "SWORDS_DANCE"),
      tmhm = { "SWORDS_DANCE", "TOXIC", "BODY_SLAM", "TAKE_DOWN",
        "DOUBLE_EDGE", "SUBMISSION", "COUNTER", "SEISMIC_TOSS", "DIG",
        "MIMIC", "DOUBLE_TEAM", "BIDE", "SWIFT", "REST", "ROCK_SLIDE",
        "SUBSTITUTE", "CUT", "STRENGTH" },
    },
    MAGNEZONE = {
      kindEn = "MAGNET AREA", kindDe = "MAGNETGEBIET",
      textEn = "Powerful magnetism lets it hover and track targets across vast distances.",
      textDe = "Starker Magnetismus lässt es schweben und Ziele über große Distanz verfolgen.",
      level1 = { "TACKLE", "THUNDERSHOCK", "SUPERSONIC", "THUNDER_WAVE" },
      learnset = levels(14, "SONICBOOM", 22, "SPARK", 30, "SWIFT",
        34, "SCREECH", 43, "THUNDERBOLT", 54, "THUNDER"),
      tmhm = { "TOXIC", "TAKE_DOWN", "DOUBLE_EDGE", "HYPER_BEAM",
        "THUNDERBOLT", "THUNDER", "TELEPORT", "MIMIC", "DOUBLE_TEAM",
        "REFLECT", "BIDE", "SELFDESTRUCT", "SWIFT", "REST",
        "THUNDER_WAVE", "EXPLOSION", "SUBSTITUTE", "FLASH" },
    },
    LICKILICKY = {
      kindEn = "LICKING", kindDe = "SCHLECKER",
      textEn = "Its long tongue coats anything it touches in numbing, sticky saliva.",
      textDe = "Seine lange Zunge überzieht Berührtes mit klebrigem, betäubendem Speichel.",
      level1 = { "LICK", "SUPERSONIC", "DEFENSE_CURL", "STOMP" },
      learnset = levels(17, "WRAP", 29, "SLAM", 33, "ROLLOUT",
        41, "BODY_SLAM", 45, "SCREECH"),
      tmhm = { "MEGA_PUNCH", "MEGA_KICK", "TOXIC", "BODY_SLAM",
        "TAKE_DOWN", "DOUBLE_EDGE", "HYPER_BEAM", "SUBMISSION", "COUNTER",
        "SEISMIC_TOSS", "EARTHQUAKE", "FISSURE", "DIG", "MIMIC",
        "DOUBLE_TEAM", "BIDE", "FIRE_BLAST", "REST", "ROCK_SLIDE",
        "SUBSTITUTE", "SURF", "STRENGTH" },
    },
    RHYPERIOR = {
      kindEn = "DRILL", kindDe = "BOHRER",
      textEn = "It launches stones from its palms and shatters boulders with one charge.",
      textDe = "Es schießt Steine aus den Händen und zertrümmert Felsen mit einem Ansturm.",
      level1 = { "HORN_ATTACK", "TAIL_WHIP", "STOMP", "FURY_ATTACK" },
      learnset = levels(25, "ROCK_SLIDE", 33, "TAKE_DOWN",
        37, "HORN_DRILL", 49, "EARTHQUAKE", 57, "MEGAHORN"),
      tmhm = { "MEGA_PUNCH", "MEGA_KICK", "TOXIC", "HORN_DRILL",
        "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE", "HYPER_BEAM", "SUBMISSION",
        "COUNTER", "SEISMIC_TOSS", "THUNDERBOLT", "THUNDER", "EARTHQUAKE",
        "FISSURE", "DIG", "MIMIC", "DOUBLE_TEAM", "BIDE", "FIRE_BLAST",
        "REST", "ROCK_SLIDE", "SUBSTITUTE", "SURF", "STRENGTH" },
    },
    TANGROWTH = {
      kindEn = "VINE", kindDe = "RANKE",
      textEn = "Its vines regrow so quickly that losing them never slows its movement.",
      textDe = "Seine Ranken wachsen so rasch nach, dass ihr Verlust es niemals aufhält.",
      level1 = { "CONSTRICT", "SLEEP_POWDER", "ABSORB", "GROWTH" },
      learnset = levels(15, "POISONPOWDER", 19, "VINE_WHIP", 22, "BIND",
        26, "MEGA_DRAIN", 29, "STUN_SPORE", 33, "ANCIENTPOWER",
        43, "SLAM", 54, "SOLARBEAM"),
      tmhm = { "SWORDS_DANCE", "TOXIC", "BODY_SLAM", "TAKE_DOWN",
        "DOUBLE_EDGE", "MEGA_DRAIN", "SOLARBEAM", "EARTHQUAKE", "MIMIC",
        "DOUBLE_TEAM", "REFLECT", "BIDE", "REST", "SUBSTITUTE", "CUT" },
    },
    ELECTIVIRE = {
      kindEn = "THUNDERBOLT", kindDe = "DONNERKEIL",
      textEn = "The tips of its tails discharge enough current to power a large building.",
      textDe = "Seine Schweifspitzen liefern genug Strom, um ein großes Gebäude zu versorgen.",
      level1 = { "FIRE_PUNCH", "QUICK_ATTACK", "LEER", "THUNDERSHOCK" },
      learnset = levels(10, "LOW_KICK", 16, "SWIFT", 25, "LIGHT_SCREEN",
        28, "THUNDER_PUNCH", 43, "THUNDERBOLT", 52, "SCREECH", 58, "THUNDER"),
      tmhm = { "MEGA_PUNCH", "MEGA_KICK", "TOXIC", "BODY_SLAM",
        "TAKE_DOWN", "DOUBLE_EDGE", "HYPER_BEAM", "SUBMISSION", "COUNTER",
        "SEISMIC_TOSS", "THUNDERBOLT", "THUNDER", "PSYCHIC_M", "MIMIC",
        "DOUBLE_TEAM", "REFLECT", "BIDE", "SWIFT", "REST", "THUNDER_WAVE",
        "SUBSTITUTE", "STRENGTH", "FLASH" },
    },
    MAGMORTAR = {
      kindEn = "BLAST", kindDe = "EXPLOSION",
      textEn = "Its arm cannons fire searing blasts, but it avoids using them near allies.",
      textDe = "Seine Armkanonen feuern Glutstöße, doch nahe Verbündeter setzt es sie nicht ein.",
      level1 = { "SMOG", "LEER", "EMBER", "SMOKESCREEN" },
      learnset = levels(16, "FAINT_ATTACK", 19, "FIRE_SPIN",
        25, "CONFUSE_RAY", 28, "FIRE_PUNCH", 43, "FLAMETHROWER",
        52, "SUNNY_DAY", 58, "FIRE_BLAST", 67, "HYPER_BEAM"),
      tmhm = { "MEGA_PUNCH", "MEGA_KICK", "TOXIC", "BODY_SLAM",
        "TAKE_DOWN", "DOUBLE_EDGE", "HYPER_BEAM", "SUBMISSION", "COUNTER",
        "SEISMIC_TOSS", "PSYCHIC_M", "MIMIC", "DOUBLE_TEAM", "BIDE",
        "FIRE_BLAST", "REST", "SUBSTITUTE", "STRENGTH" },
    },
    TOGEKISS = {
      kindEn = "JUBILEE", kindDe = "JUBEL",
      textEn = "It appears where people live peacefully and shares blessings of goodwill.",
      textDe = "Es erscheint an friedlichen Orten und schenkt den Menschen seinen Segen.",
      level1 = { "PECK", "GROWL", "METRONOME", "SWEET_KISS" },
      learnset = levels(10, "DOUBLESLAP", 20, "EXTREMESPEED",
        30, "REFLECT", 40, "SKY_ATTACK"),
      tmhm = { "TOXIC", "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE",
        "HYPER_BEAM", "PSYCHIC_M", "TELEPORT", "MIMIC", "DOUBLE_TEAM",
        "REFLECT", "BIDE", "METRONOME", "FIRE_BLAST", "SWIFT", "REST",
        "THUNDER_WAVE", "PSYWAVE", "SKY_ATTACK", "SUBSTITUTE", "FLY",
        "FLASH" },
    },
    YANMEGA = {
      kindEn = "OGRE DARNER", kindDe = "RIESENLIBELLE",
      textEn = "Its wingbeats create shock waves strong enough to rattle trees and houses.",
      textDe = "Seine Flügelschläge erzeugen Druckwellen, die Bäume und Häuser erschüttern.",
      level1 = { "TACKLE", "QUICK_ATTACK", "DOUBLE_TEAM", "WING_ATTACK" },
      learnset = levels(14, "SONICBOOM", 22, "SUPERSONIC",
        33, "ANCIENTPOWER", 43, "SLASH", 46, "SCREECH", 54, "SWIFT"),
      tmhm = { "SWORDS_DANCE", "TOXIC", "TAKE_DOWN", "DOUBLE_EDGE",
        "HYPER_BEAM", "SOLARBEAM", "PSYCHIC_M", "MIMIC", "DOUBLE_TEAM",
        "BIDE", "SWIFT", "REST", "SUBSTITUTE", "FLY" },
    },
    LEAFEON = {
      kindEn = "VERDANT", kindDe = "FRISCHGRÜN",
      textEn = "Its cells resemble plants, so sunlight and clean air become its energy.",
      textDe = "Seine Zellen ähneln Pflanzen und gewinnen Kraft aus Sonne und reiner Luft.",
      level1 = { "TAIL_WHIP", "TACKLE", "SAND_ATTACK", "RAZOR_LEAF" },
      learnset = levels(22, "QUICK_ATTACK", 29, "SYNTHESIS",
        36, "MEGA_DRAIN", 43, "GIGA_DRAIN", 64, "SUNNY_DAY",
        71, "LEAF_BLADE", 78, "SWORDS_DANCE"),
      tmhm = { "SWORDS_DANCE", "TOXIC", "BODY_SLAM", "TAKE_DOWN",
        "DOUBLE_EDGE", "HYPER_BEAM", "MEGA_DRAIN", "SOLARBEAM", "DIG",
        "MIMIC", "DOUBLE_TEAM", "REFLECT", "BIDE", "SWIFT", "REST",
        "SUBSTITUTE", "CUT", "STRENGTH", "FLASH" },
    },
    GLACEON = {
      kindEn = "FRESH SNOW", kindDe = "NEUSCHNEE",
      textEn = "It chills its fur into sharp needles and lowers the air to freezing.",
      textDe = "Es kühlt sein Fell zu spitzen Nadeln und senkt die Luft bis zum Gefrierpunkt.",
      level1 = { "TAIL_WHIP", "TACKLE", "SAND_ATTACK", "POWDER_SNOW" },
      learnset = levels(22, "QUICK_ATTACK", 29, "BITE", 36, "ICE_BEAM",
        43, "MIST", 57, "BLIZZARD", 64, "BARRIER"),
      tmhm = { "TOXIC", "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE",
        "ICE_BEAM", "BLIZZARD", "HYPER_BEAM", "MIMIC", "DOUBLE_TEAM",
        "REFLECT", "BIDE", "SWIFT", "REST", "SUBSTITUTE" },
    },
    GLISCOR = {
      kindEn = "FANG SCORP", kindDe = "FANGSKORPION",
      textEn = "It rides faint winds without a sound, striking once before gliding away.",
      textDe = "Lautlos gleitet es auf schwachem Wind, schlägt einmal zu und verschwindet.",
      level1 = { "SAND_ATTACK", "HARDEN", "QUICK_ATTACK", "WING_ATTACK" },
      learnset = levels(23, "FAINT_ATTACK", 27, "SCREECH",
        34, "SWORDS_DANCE", 38, "SLASH", 45, "GUILLOTINE",
        52, "EARTHQUAKE"),
      tmhm = { "SWORDS_DANCE", "TOXIC", "BODY_SLAM", "TAKE_DOWN",
        "DOUBLE_EDGE", "HYPER_BEAM", "EARTHQUAKE", "FISSURE", "DIG",
        "MIMIC", "DOUBLE_TEAM", "BIDE", "REST", "ROCK_SLIDE",
        "SUBSTITUTE", "CUT", "STRENGTH" },
    },
    MAMOSWINE = {
      kindEn = "TWIN TUSK", kindDe = "DOPPELSTOßZAHN",
      textEn = "Its ice-covered tusks have endured since the age of frozen earth.",
      textDe = "Seine eisbedeckten Stoßzähne bestehen seit dem Zeitalter gefrorener Erde.",
      level1 = { "ANCIENTPOWER", "PECK", "POWDER_SNOW", "MUD_SLAP" },
      learnset = levels(25, "TAKE_DOWN", 33, "DOUBLE_HIT",
        40, "EARTHQUAKE", 48, "MIST", 56, "BLIZZARD"),
      tmhm = { "TOXIC", "BODY_SLAM", "TAKE_DOWN", "DOUBLE_EDGE",
        "ICE_BEAM", "BLIZZARD", "HYPER_BEAM", "EARTHQUAKE", "FISSURE",
        "MIMIC", "DOUBLE_TEAM", "BIDE", "REST", "ROCK_SLIDE",
        "SUBSTITUTE", "STRENGTH" },
    },
    PORYGON_Z = {
      kindEn = "VIRTUAL", kindDe = "VIRTUELL",
      textEn = "An experimental update made its movements erratic in ordinary space.",
      textDe = "Ein experimentelles Update machte seine Bewegungen im normalen Raum sprunghaft.",
      level1 = { "TACKLE", "CONVERSION", "PSYBEAM", "AGILITY" },
      learnset = levels(18, "RECOVER", 29, "THUNDER_WAVE",
        40, "PSYCHIC_M", 51, "TRI_ATTACK", 56, "THUNDERBOLT",
        67, "HYPER_BEAM"),
      tmhm = { "TOXIC", "TAKE_DOWN", "DOUBLE_EDGE", "ICE_BEAM",
        "BLIZZARD", "HYPER_BEAM", "THUNDERBOLT", "THUNDER", "PSYCHIC_M",
        "TELEPORT", "MIMIC", "DOUBLE_TEAM", "REFLECT", "BIDE", "PSYWAVE",
        "REST", "THUNDER_WAVE", "TRI_ATTACK", "SUBSTITUTE", "FLASH" },
    },
    AZURILL = {
      kindEn = "POLKA DOT", kindDe = "PUNKT",
      textEn = "Its elastic tail stores nutrients and lets it bounce safely across water.",
      textDe = "Sein elastischer Schweif speichert Nahrung und lässt es sicher übers Wasser hüpfen.",
      level1 = { "SPLASH", "CHARM", "TAIL_WHIP", "BUBBLE" },
      learnset = levels(7, "TAIL_WHIP", 10, "BUBBLE",
        15, "SLAM", 18, "WATER_GUN"),
      tmhm = { "TOXIC", "BODY_SLAM", "BUBBLEBEAM", "WATER_GUN",
        "ICE_BEAM", "BLIZZARD", "MIMIC", "DOUBLE_TEAM", "BIDE", "REST",
        "SUBSTITUTE", "SURF" },
    },
    WYNAUT = {
      kindEn = "BRIGHT", kindDe = "FROHSINN",
      textEn = "It travels in groups and pushes through hardship with a constantly cheerful face.",
      textDe = "Es reist in Gruppen und begegnet jeder Mühe mit einem stets fröhlichen Gesicht.",
      level1 = { "SPLASH", "CHARM", "COUNTER" },
      learnset = levels(15, "COUNTER"),
      tmhm = { "COUNTER" },
    },
  }
  H.catalogue = catalogue

  -- One registry owns the 15-package/17-target evolution contract.  Keep
  -- this derived table only as a small inspection seam for existing tests
  -- and downstream UI; no per-species relic can become an authority again.
  local parentEvolutions = {}
  for _, evolution in ipairs(packages.evolutionRows()) do
    parentEvolutions[evolution.target] = {
      parent = evolution.parent, item = evolution.item,
      method = evolution.method, package = evolution.package.id,
    }
  end
  H.parentEvolutions = parentEvolutions

  -- Rows which still require mechanics that Gen1 Recomp does not expose are
  -- omitted rather than installed as misleading plain-damage placeholders.
  -- Rollout, AncientPower and Double Hit are implemented below and therefore
  -- deliberately absent from this list.
  local mechanicsBlocked = {
    MIRROR_COAT = true, SAFEGUARD = true, DESTINY_BOND = true,
  }
  H.mechanicsBlocked = mechanicsBlocked

  local iconForType = {
    GRASS = "GRASS", WATER = "WATER", FLYING = "BIRD", BUG = "BUG",
    NORMAL = "MON", GHOST = "MON", DARK = "MON", ICE = "QUADRUPED",
    ELECTRIC = "BALL", GROUND = "QUADRUPED", FIRE = "MON",
    PSYCHIC_TYPE = "FAIRY",
  }

  local function moveAvailable(move)
    return not mechanicsBlocked[move] and mod.content.moves:get(move) ~= nil
  end

  local function projectedMoves(species, row)
    local authored = catalogue[species] or {}
    local audit = { active = 0, skipped = {}, activeMachines = 0,
      skippedMachines = {} }
    local level1, seen = {}, {}
    for _, move in ipairs(authored.level1 or row.level1Moves or {}) do
      if moveAvailable(move) then
        if not seen[move] then
          level1[#level1 + 1] = move
          seen[move] = true
          audit.active = audit.active + 1
        end
      else
        audit.skipped[#audit.skipped + 1] = { level = 1, move = move }
      end
    end
    local learnset = {}
    for _, entry in ipairs(authored.learnset or row.learnset or {}) do
      if moveAvailable(entry.move) then
        learnset[#learnset + 1] = {
          level = entry.level, move = entry.move,
        }
        audit.active = audit.active + 1
      else
        audit.skipped[#audit.skipped + 1] = {
          level = entry.level, move = entry.move,
        }
      end
    end
    local tmhm = {}
    for _, move in ipairs(authored.tmhm or {}) do
      if moveAvailable(move) then
        tmhm[#tmhm + 1] = move
        audit.activeMachines = audit.activeMachines + 1
      else
        audit.skippedMachines[#audit.skippedMachines + 1] = move
      end
    end
    H.audit.species[species] = audit
    H.audit.activeRows = H.audit.activeRows + audit.active
    for _, skipped in ipairs(audit.skipped) do
      H.audit.skippedRows[#H.audit.skippedRows + 1] = {
        species = species, level = skipped.level, move = skipped.move,
      }
    end
    return level1, learnset, tmhm
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function glyphLength(text)
    local count = 0
    text = tostring(text or "")
    for index = 1, #text do
      local byte = text:byte(index)
      if byte < 128 or byte >= 192 then count = count + 1 end
    end
    return count
  end

  local function wrapDexText(text, width)
    width = math.max(1, math.floor(tonumber(width) or 18))
    text = tostring(text or ""):gsub("[\n\v\f]+", " ")
      :gsub("%s+", " "):match("^%s*(.-)%s*$")
    local lines, line = {}, ""
    for word in text:gmatch("%S+") do
      local candidate = line == "" and word or (line .. " " .. word)
      if line ~= "" and glyphLength(candidate) > width then
        lines[#lines + 1], line = line, word
      else
        line = candidate
      end
    end
    if line ~= "" then lines[#lines + 1] = line end
    return table.concat(lines, "\n")
  end
  H.wrapDexText = wrapDexText

  local function upsert(registry, id, row)
    if registry:get(id) then registry:patch(id, row)
    else registry:register(id, row) end
  end

  local function clearRollout(user, preserveLandedTurn)
    if not user then return end
    local locked = user.thrashMove
    if locked and locked.id == "ROLLOUT" then
      user.thrashTurns, user.thrashMove, user.thrashAnnounced = nil, nil, nil
    end
    user.kaHevoRollout = nil
    if not preserveLandedTurn then user.kaHevoRolloutLandedTurn = nil end
  end

  local function onRolloutLanded(ev)
    local user, move = ev and ev.user, ev and ev.move
    local damage = tonumber(ev and (ev.damage or ev.totalDealt)) or 0
    if not (user and move and move.id == "ROLLOUT") or damage <= 0 then
      return {}
    end
    local state = user.kaHevoRollout or { step = 1 }
    local turn = ev.battle and ev.battle.turnCount or ev.turn or 0
    -- battle.damage_dealt fires before the ordinary secondary callback.
    -- Keep this idempotent so the latter remains an executable fallback,
    -- while a KO still advances the sequence even though the engine skips
    -- post-damage secondary effects after the target faints.
    if user.kaHevoRolloutLandedTurn == turn then return {} end
    user.kaHevoRolloutLandedTurn = turn
    state.landedTurn = turn
    if state.step >= 5 then
      clearRollout(user, true)
    else
      state.step = state.step + 1
      state.moveInst = state.moveInst or ev.moveInst
        or { id = "ROLLOUT", pp = 0 }
      user.kaHevoRollout = state
      -- Reuse the engine's proven menu lock and PP-continuation path.  The
      -- custom effect owns the counter, so the fifth hit ends without the
      -- Thrash confusion side effect.
      user.thrashTurns = 1
      user.thrashMove = state.moveInst
      user.thrashAnnounced = true
    end
    return {}
  end

  local rolloutEffect = {
    kind = "secondary",
    run = function(ctx)
      return onRolloutLanded({
        battle = ctx.battle, user = ctx.user, move = ctx.move,
        moveInst = ctx.moveInst, totalDealt = ctx.totalDealt,
      })
    end,
  }
  local ancientPowerEffect = {
    kind = "secondary",
    run = function(ctx)
      if ctx.rng(0, 9) ~= 0 then return {} end
      local messages = {}
      for _, stat in ipairs({ "attack", "defense", "speed", "special" }) do
        for _, message in ipairs(ctx.changeStage(ctx.user, stat, 1, false)) do
          messages[#messages + 1] = message
        end
      end
      return messages
    end,
  }
  if mod.content.move_effects then
    upsert(mod.content.move_effects, "ROLLOUT_EFFECT", rolloutEffect)
    upsert(mod.content.move_effects, "ANCIENTPOWER_EFFECT", ancientPowerEffect)
  end
  upsert(mod.content.moves, "ROLLOUT", {
    id = "ROLLOUT", name = H.moveNames.ROLLOUT, type = "ROCK", power = 30,
    accuracy = 90, pp = 20, category = "physical",
    effect = "ROLLOUT_EFFECT",
  })
  upsert(mod.content.moves, "ANCIENTPOWER", {
    id = "ANCIENTPOWER", name = H.moveNames.ANCIENTPOWER,
    type = "ROCK", power = 60,
    accuracy = 100, pp = 5, category = "physical",
    effect = "ANCIENTPOWER_EFFECT",
  })
  upsert(mod.content.moves, "DOUBLE_HIT", {
    id = "DOUBLE_HIT", name = H.moveNames.DOUBLE_HIT,
    type = "NORMAL", power = 35,
    accuracy = 90, pp = 10, category = "physical",
    effect = "ATTACK_TWICE_EFFECT", multiHit = 2,
  })
  upsert(mod.content.moves, "LEAF_BLADE", {
    id = "LEAF_BLADE", name = H.moveNames.LEAF_BLADE,
    type = "GRASS", power = 90,
    accuracy = 100, pp = 15, category = "special",
    effect = "NO_ADDITIONAL_EFFECT", highCrit = true,
  })
  H.moveIds = {
    rollout = "ROLLOUT", ancientPower = "ANCIENTPOWER",
    doubleHit = "DOUBLE_HIT", leafBlade = "LEAF_BLADE",
  }
  H.moveEffectIds = {
    rollout = "ROLLOUT_EFFECT", ancientPower = "ANCIENTPOWER_EFFECT",
    doubleHit = "ATTACK_TWICE_EFFECT",
  }

  local function rolloutPower(user)
    local state = user and user.kaHevoRollout
    local step = math.max(1, math.min(5,
      math.floor(tonumber(state and state.step) or 1)))
    local multiplier = 2 ^ (step - 1)
    if user and user.kaHevoDefenseCurl then multiplier = multiplier * 2 end
    return 30 * multiplier
  end

  local function leafeonUsesPhysicalLeafBlade(user)
    return user and user.mon and user.mon.species == "LEAFEON"
  end

  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("battle.damage", function(nextDamage, ctx)
      local moveId = ctx and ctx.move and ctx.move.id
      local physicalLeafBlade = moveId == "LEAF_BLADE"
        and leafeonUsesPhysicalLeafBlade(ctx.user)
      if moveId ~= "ROLLOUT" and not physicalLeafBlade then
        return nextDamage(ctx)
      end
      local move = {}
      for key, value in pairs(ctx.move) do move[key] = value end
      if moveId == "ROLLOUT" then
        move.power = rolloutPower(ctx.user)
      else
        move.category = "physical"
      end
      local adjusted = {}
      for key, value in pairs(ctx) do adjusted[key] = value end
      adjusted.move = move
      return nextDamage(adjusted)
    end, 820)
  end

  local function onMoveUsed(ev)
    local user, move = ev and ev.user, ev and ev.move
    if not (user and move and move.id) then return end
    if move.id == "DEFENSE_CURL" then
      clearRollout(user)
      user.kaHevoDefenseCurl = true
    elseif move.id == "ROLLOUT" then
      user.kaHevoRollout = user.kaHevoRollout or { step = 1 }
    else
      clearRollout(user)
    end
  end

  local function onTurnEnded(ev)
    local battle = ev and ev.battle
    local turn = battle and battle.turnCount or ev and ev.turn
    for _, user in ipairs(battle and { battle.player, battle.enemy } or {}) do
      local state = user and user.kaHevoRollout
      if state and state.landedTurn ~= turn then clearRollout(user) end
    end
  end

  local function onBattlerSwitched(ev)
    clearRollout(ev and ev.previous)
  end

  H.rollout = {
    clear = clearRollout, power = rolloutPower,
    onMoveUsed = onMoveUsed, onTurnEnded = onTurnEnded,
    onDamageDealt = onRolloutLanded,
    onBattlerSwitched = onBattlerSwitched,
  }
  H.leafBlade = { isPhysicalUser = leafeonUsesPhysicalLeafBlade }
  if mod.events and mod.events.on then
    mod.events:on("battle.move_used", onMoveUsed)
    mod.events:on("battle.damage_dealt", onRolloutLanded)
    mod.events:on("battle.turn_ended", onTurnEnded)
    mod.events:on("battle.battler_switched", onBattlerSwitched)
  end

  -- Cries are registered before Pokémon rows so strict reference validation
  -- sees a complete content graph during merge.
  for _, species in ipairs(H.order) do
    local row = assert(data[species], "missing HEVO species " .. species)
    mod.content.cries:register(species, {
      file = mod.path .. "/assets/audio/hevo_19_cries/"
        .. tostring(row.dex) .. ".ogg",
    })
  end

  for _, species in ipairs(H.order) do
    local row = data[species]
    local authored = assert(catalogue[species],
      "missing authored HEVO catalogue row " .. species)
    local level1, learnset, tmhm = projectedMoves(species, row)
    local evolutions = {}
    if species == "AZURILL" then
      evolutions[1] = { method = "FRIENDSHIP", species = "MARILL" }
    elseif species == "WYNAUT" then
      evolutions[1] = { method = "LEVEL", level = 15, species = "WOBBUFFET" }
    end
    local textId = "_KantoAscendantHevoDex" .. species
    mod.content.text:register(textId, wrapDexText(
      tr(authored.textEn, authored.textDe)))
    local inches = math.floor(row.heightM * 39.3700787 + 0.5)
    mod.content.pokemon:register(species, {
      id = species, name = tr(row.name, row.de), dex = row.dex,
      types = copy(row.types), baseStats = copy(row.stats),
      catchRate = row.catchRate, baseExp = row.baseExp,
      growthRate = row.growthRate,
      level1Moves = level1, learnset = learnset, evolutions = evolutions,
      tmhm = tmhm, cry = species,
      spriteFront = mod.path .. "/assets/hevo_19/front/"
        .. tostring(row.dex) .. ".png",
      spriteBack = mod.path .. "/assets/hevo_19/back/"
        .. tostring(row.dex) .. ".png",
      frontSize = 7, trueColor = true,
      battleScaleFront = 1, battleScaleBack = 1,
      icon = iconForType[row.types[1]] or "MON",
      dexEntry = {
        kind = tr(authored.kindEn, authored.kindDe), text = textId,
        heightFt = math.floor(inches / 12), heightIn = inches % 12,
        weight = math.floor(row.weightKg * 22.0462262 + 0.5),
        heightM = row.heightM, weightKg = row.weightKg,
      },
    })
    mod.content.icons:register(species,
      iconForType[row.types[1]] or "MON")
  end

  -- Preserve every existing branch and append only registry-authored HEVO
  -- methods.  Item, field and move-knowledge methods therefore share the
  -- same package gate used by Bag/Route 5/Day-Care.
  for target, evolution in pairs(parentEvolutions) do
    local parent = mod.content.pokemon:get(evolution.parent)
    if parent then
      local evolutions = copy(parent.evolutions or {})
      local duplicate = false
      for _, current in ipairs(evolutions) do
        if current.species == target then duplicate = true break end
      end
      if not duplicate then
        local branch = { method = evolution.method, species = target }
        if evolution.item then branch.item = evolution.item end
        evolutions[#evolutions + 1] = branch
        mod.content.pokemon:patch(evolution.parent, {
          evolutions = evolutions,
        })
      end
    end
  end

  mod.content.constants:patch("dexSize", 279)
  mod.content.constants:patch("dexDigits", 3)

  function H.install(game)
    local live = game and game.data
    if not live then return false end
    live.audio = live.audio or {}
    live.audio.cries = live.audio.cries or {}
    live.audio._owners = live.audio._owners or {}
    live.audio._owners.cries = live.audio._owners.cries or {}
    for _, species in ipairs(H.order) do
      local row = data[species]
      if live.audio.cries[species] == nil then
        live.audio.cries[species] = {
          file = mod.path .. "/assets/audio/hevo_19_cries/"
            .. tostring(row.dex) .. ".ogg",
        }
        live.audio._owners.cries[species] = mod.id
      end
      if live.pokemon[species] then live.pokemon[species].cry = species end
    end
    return true
  end

  if mod.exports then mod.exports.hevoSpeciesAudit = H.audit end
  return H
end
