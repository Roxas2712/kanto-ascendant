-- Kanto Ascendant 6.0: optional early Johto migration.
--
-- This module deliberately owns no map, menu or travel UI.  It exposes the
-- story/state operations used by the Pallet and Driftglass controllers and
-- wraps only the final native encounter result at a deliberately low
-- priority.  Existing authored encounters, events and postgame roamers are
-- therefore free to replace its candidate.
--
-- A replacement roll is transactional.  Rare-species pity is changed only
-- when battle.started confirms that the exact candidate actually reached a
-- wild battle.  Repel, an outer hook, a scripted battle or another roll
-- cancels the pending transaction without advancing or resetting pity.

return function(mod, opts)
  opts = opts or {}

  local i18n = opts.i18n
  local stateBackend = assert(opts.state, "Johto Signals state missing")
  local content = opts.content or {}
  local johto = opts.johtoData or content.johtoData or content.johto
    or (content.habitats and content) or {}
  local stepRandom = opts.random or math.random

  local J = {
    game = nil,
    ENCOUNTER_PRIORITY = -30,
  }

  local MODES = {
    KANTO_FIRST = "KANTO_FIRST",
    WANDERWAVES = "WANDERWAVES",
    UNLEASHED = "UNLEASHED",
  }

  local MODE_ALIASES = {
    KANTO_FIRST = MODES.KANTO_FIRST,
    KANTO = MODES.KANTO_FIRST,
    kanto = MODES.KANTO_FIRST,
    kanto_first = MODES.KANTO_FIRST,
    WANDERWAVES = MODES.WANDERWAVES,
    WANDERWELLEN = MODES.WANDERWAVES,
    waves = MODES.WANDERWAVES,
    wanderwaves = MODES.WANDERWAVES,
    UNLEASHED = MODES.UNLEASHED,
    JOHTO_UNLEASHED = MODES.UNLEASHED,
    unleashed = MODES.UNLEASHED,
  }

  local START_POLICIES = {
    quest = "quest",
    kanto = MODES.KANTO_FIRST,
    KANTO_FIRST = MODES.KANTO_FIRST,
    waves = MODES.WANDERWAVES,
    WANDERWAVES = MODES.WANDERWAVES,
    unleashed = MODES.UNLEASHED,
    JOHTO_UNLEASHED = MODES.UNLEASHED,
    UNLEASHED = MODES.UNLEASHED,
  }

  local BADGES = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }

  -- Trace sites and actual habitats are intentionally distinct for the first
  -- two species: the receiver discovers a migration path, then the player
  -- follows its environmental clue.  Names remain hidden until the real Dex
  -- has recorded a sighting.
  local SPECIAL = {
    CHIKORITA = {
      trace = "forest",
      traceMap = "VIRIDIAN_FOREST",
      habitatMap = "ROUTE_24",
      terrain = "grass",
      level = 18,
      traceEn = "deep Viridian\nForest",
      traceDe = "tiefen Vertania-\nWald",
      habitatEn = "a riverside meadow\nnorth of Cerulean",
      habitatDe = "eine Flusswiese\nnördlich Azurias",
    },
    TOTODILE = {
      trace = "coast",
      traceMap = "ROUTE_6",
      habitatMap = "SEAFOAM_ISLANDS_B2F",
      terrain = "indoor",
      level = 22,
      traceEn = "a damp route south\nof Cerulean",
      traceDe = "eine feuchte Route\nsüdlich von Azuria",
      habitatEn = "cold Seafoam cave",
      habitatDe = "kalte Seeschaum-\nhöhlen",
    },
    CYNDAQUIL = {
      trace = "ember",
      traceMap = "POKEMON_MANSION_B1F",
      habitatMap = "POKEMON_MANSION_B1F",
      terrain = "indoor",
      level = 22,
      traceEn = "warm stone below\nthe island ruins",
      traceDe = "warmen Stein unter\nder Inselruine",
      habitatEn = "warm stone beneath\nthe island ruins",
      habitatDe = "warmer Stein unter\nder Inselruine",
    },
    LARVITAR = {
      trace = "stone",
      traceMap = "VICTORY_ROAD_3F",
      habitatMap = "VICTORY_ROAD_3F",
      terrain = "indoor",
      level = 45,
      traceEn = "Victory Road's\ndeepest level",
      traceDe = "tiefste Ebene der\nSiegesstraße",
      habitatEn = "Victory Road's\ndeepest level",
      habitatDe = "tiefste Ebene der\nSiegesstraße",
    },
  }

  local TRACE_ORDER = {
    "CHIKORITA", "TOTODILE", "CYNDAQUIL", "LARVITAR",
  }

  -- Wanderwaves expose curated, badge-aware slices.  Unleashed uses every
  -- ordinary base species for which Kanto Ascendant has an authored habitat.
  -- All lists are base species only by construction.
  local WAVES = {
    {
      minBadges = 0,
      species = {
        "SENTRET", "HOOTHOOT", "LEDYBA", "SPINARAK",
        "HOPPIP", "MAREEP", "WOOPER", "MARILL",
      },
    },
    {
      minBadges = 3,
      species = {
        "NATU", "PINECO", "AIPOM", "SUNKERN",
        "YANMA", "DUNSPARCE", "SNUBBULL", "MURKROW",
      },
    },
    {
      minBadges = 5,
      species = {
        "CHINCHOU", "QWILFISH", "REMORAID", "CORSOLA",
        "SHUCKLE", "GLIGAR", "SNEASEL", "TEDDIURSA",
      },
    },
    {
      minBadges = 7,
      species = {
        "HERACROSS", "HOUNDOUR", "PHANPY", "STANTLER", "MILTANK",
        "SKARMORY", "SWINUB", "SLUGMA", "MANTINE", "SMEARGLE",
      },
    },
  }

  local UNLEASHED_BASES = {
    "SENTRET", "HOOTHOOT", "LEDYBA", "SPINARAK", "CHINCHOU", "NATU",
    "MAREEP", "MARILL", "SUDOWOODO", "HOPPIP", "AIPOM", "SUNKERN",
    "YANMA", "WOOPER", "MURKROW", "MISDREAVUS", "UNOWN", "WOBBUFFET",
    "GIRAFARIG", "PINECO", "DUNSPARCE", "GLIGAR", "SNUBBULL",
    "QWILFISH", "SHUCKLE", "HERACROSS", "SNEASEL", "TEDDIURSA",
    "SLUGMA", "SWINUB", "CORSOLA", "REMORAID", "DELIBIRD", "MANTINE",
    "SKARMORY", "HOUNDOUR", "PHANPY", "STANTLER", "SMEARGLE", "MILTANK",
  }

  local ORDINARY_ALLOWED = {}
  for _, species in ipairs(UNLEASHED_BASES) do
    ORDINARY_ALLOWED[species] = true
  end

  local EXCLUDED = {
    -- Special bases require their own independently found trace.
    CHIKORITA = true, CYNDAQUIL = true, TOTODILE = true, LARVITAR = true,
    -- Their evolutions never replace an encounter.
    BAYLEEF = true, MEGANIUM = true,
    QUILAVA = true, TYPHLOSION = true,
    CROCONAW = true, FERALIGATR = true,
    PUPITAR = true, TYRANITAR = true,
    -- Legendary and mythical species never belong to an ordinary wave.
    RAIKOU = true, ENTEI = true, SUICUNE = true,
    LUGIA = true, HO_OH = true, CELEBI = true, MEW = true,
  }

  local runtime = {
    pendingCandidate = nil,
    capsuleOfferPending = false,
    capsuleDeclinedMapStay = false,
    lastEnteredMap = nil,
    onboardingPending = nil,
    candidateSerial = 0,
  }

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  local function integer(value, minimum, maximum)
    value = math.floor(tonumber(value) or 0)
    if minimum and value < minimum then value = minimum end
    if maximum and value > maximum then value = maximum end
    return value
  end

  local function normalizeMode(mode)
    return MODE_ALIASES[mode] or MODES.KANTO_FIRST
  end

  local function normalizeStartPolicy(policy)
    return START_POLICIES[policy] or "quest"
  end

  local fallbackSection
  local cachedSection
  local function backendSection()
    if type(cachedSection) == "table" then return cachedSection end
    local section
    if type(stateBackend.section) == "function" then
      local ok, value = pcall(stateBackend.section, "earlyJohto")
      if not ok then
        ok, value = pcall(stateBackend.section, stateBackend, "earlyJohto")
      end
      if ok then section = value end
    end
    if type(section) ~= "table" and type(stateBackend.earlyJohto) == "table" then
      section = stateBackend.earlyJohto
    end
    if type(section) ~= "table" and type(stateBackend.root) == "function" then
      local ok, root = pcall(stateBackend.root)
      if not ok then ok, root = pcall(stateBackend.root, stateBackend) end
      if ok and type(root) == "table" then
        root.earlyJohto = type(root.earlyJohto) == "table"
          and root.earlyJohto or {}
        section = root.earlyJohto
      end
    end
    if type(section) ~= "table" then
      fallbackSection = fallbackSection or {}
      section = fallbackSection
    end
    cachedSection = section
    return section
  end

  local function normalizeState(s)
    s.version = 1
    s.mode = normalizeMode(s.mode)
    s.modeChosen = s.modeChosen == true
    s.receiverRepaired = s.receiverRepaired == true or s.repaired == true
    s.repaired = nil
    s.questStarted = s.questStarted == true
    s.capsuleFound = s.capsuleFound == true
    s.capsuleAvailable = s.capsuleAvailable == true
    s.pokedexSteps = integer(s.pokedexSteps, 0)
    s.palletVisits = integer(s.palletVisits, 0)
    local target = tonumber(s.capsuleTarget)
    s.capsuleTarget = target and integer(target, 128, 768) or nil
    s.waveIndex = integer(s.waveIndex, 0, #WAVES)
    s.waveSteps = integer(s.waveSteps, 0)
    s.strongSignal = s.strongSignal == true
    s.traces = type(s.traces) == "table" and s.traces or {}
    s.rarePity = type(s.rarePity) == "table" and s.rarePity or {}
    for _, species in ipairs(TRACE_ORDER) do
      local trace = SPECIAL[species].trace
      s.traces[trace] = s.traces[trace] == true
      s.rarePity[species] = integer(s.rarePity[species], 0)
    end
    s.onboardingComplete = s.onboardingComplete == true
    s.startPolicy = normalizeStartPolicy(s.startPolicy)
    return s
  end

  local function state()
    return normalizeState(backendSection())
  end

  local function persist()
    if type(stateBackend.persist) == "function" then
      local ok = pcall(stateBackend.persist)
      if not ok then pcall(stateBackend.persist, stateBackend) end
    end
  end

  local function activeGame(game)
    return game or J.game
  end

  local function hasStarter(game)
    game = activeGame(game)
    return game and game.save and type(game.save.party) == "table"
      and #game.save.party > 0
  end

  local function hasDex(game)
    game = activeGame(game)
    return game and game.save and game.save.flags
      and not not game.save.flags.EVENT_GOT_POKEDEX
  end

  local function mapIdOf(value, game)
    if type(value) == "string" then return value end
    if type(value) == "table" then
      if type(value.mapId) == "string" then return value.mapId end
      if type(value.map) == "table" and type(value.map.id) == "string" then
        return value.map.id
      end
    end
    game = activeGame(game)
    return game and game.overworld and game.overworld.map
      and game.overworld.map.id or nil
  end

  local function badgeCount(game)
    game = activeGame(game)
    local inventory = game and game.save and game.save.inventory or {}
    local count = 0
    for _, badge in ipairs(BADGES) do
      if inventory[badge] then count = count + 1 end
    end
    return count
  end

  local function dexSeen(game, species)
    game = activeGame(game)
    return game and game.save and game.save.pokedex
      and game.save.pokedex.seen
      and game.save.pokedex.seen[species] == true or false
  end

  local function speciesName(game, species)
    if not dexSeen(game, species) then return "???" end
    local definition = activeGame(game) and activeGame(game).data
      and activeGame(game).data.pokemon
      and activeGame(game).data.pokemon[species]
    local english = definition and definition.name or species
    local german = johto.germanNames and johto.germanNames[species] or english
    return tr(english, german)
  end

  local function modeName(mode)
    mode = normalizeMode(mode)
    if mode == MODES.WANDERWAVES then
      return tr("WANDERWAVES", "WANDERWELLEN")
    end
    if mode == MODES.UNLEASHED then
      return tr("JOHTO UNLEASHED", "JOHTO ENTFESSELT")
    end
    return tr("KANTO FIRST", "KANTO ZUERST")
  end

  local function requestedStartPolicy()
    local policy = opts.startPolicy
    if type(policy) == "function" then policy = policy() end
    if policy == nil and mod.options and type(mod.options.get) == "function" then
      policy = mod.options:get("johto_signals_start")
        or mod.options:get("johto_signals_current")
        or mod.options:get("johto_current_start")
    end
    return normalizeStartPolicy(policy)
  end

  local function signalsEnabled()
    local enabled = opts.enabled
    if type(enabled) == "function" then enabled = enabled() end
    if enabled == nil and mod.options and type(mod.options.get) == "function" then
      enabled = mod.options:get("johto_signals_enable")
    end
    return enabled ~= false
  end

  -- Mythic Signals deliberately shares the field receiver, but its campaign
  -- remains usable when the player disables only early Johto encounters.
  -- In that configuration the capsule/boat/researcher story still runs while
  -- resolveCandidate() below continues to use signalsEnabled() and therefore
  -- cannot inject a single Johto species.
  local function questInfrastructureEnabled()
    if signalsEnabled() then return true end
    local enabled
    if mod.options and type(mod.options.get) == "function" then
      enabled = mod.options:get("mythic_signals")
      if enabled == nil then enabled = mod.options:get("mythic_resonance") end
    end
    return enabled ~= false and enabled ~= "off"
  end

  local function chooseWave(s, game, rng)
    rng = rng or stepRandom
    local available = {}
    local badges = badgeCount(game)
    for index, wave in ipairs(WAVES) do
      if badges >= wave.minBadges then
        available[#available + 1] = index
      end
    end
    if #available == 0 then available[1] = 1 end
    local previous = s.waveIndex
    local index
    if #available == 1 then
      index = available[1]
    else
      index = available[rng(1, #available)]
      if index == previous then
        local at = 1
        for candidateIndex, value in ipairs(available) do
          if value == index then at = candidateIndex break end
        end
        index = available[(at % #available) + 1]
      end
    end
    s.waveIndex = index
    s.waveSteps = rng(384, 768)
    s.strongSignal = rng(1, 4) == 1
    return index
  end

  local function ensureWave(s, game)
    if s.waveIndex <= 0 or s.waveSteps <= 0 then
      chooseWave(s, game, stepRandom)
      return true
    end
    return false
  end

  local function capsuleReady(s)
    s = s or state()
    return s.capsuleFound or s.capsuleAvailable
      or s.palletVisits >= 5
      or (s.capsuleTarget ~= nil and s.pokedexSteps >= s.capsuleTarget)
  end

  local function capsuleText(key)
    if key == "offer" then
      return tr(
        "Something glints\nsouth of PALLET.\f"
          .. "A dark-glass pod\nrests in the wood.\f"
          .. "INSPECT IT?",
        "Etwas glitzert\nsüdlich von\nALABASTIA.\f"
          .. "Eine Glaskapsel\nliegt im Holz.\f"
          .. "UNTERSUCHEN?")
    elseif key == "found" then
      return tr(
        "Foreign pollen and\nstar-shaped sand.\f"
          .. "Inside: a damaged\nJOHTO sender.\f"
          .. "Ask the boatman at\nPALLET's pier.\f"
          .. "The DRIFTGLASS lab\nmay know its path.",
        "Fremder Pollen und\nSternensand.\f"
          .. "Darin liegt ein\ndefekter JOHTO-\nSender.\f"
          .. "Frag den Bootsmann\nam ALABASTIA-Steg.\f"
          .. "Auf DRIFTGLAS\nkennt man den Weg.")
    end
    return tr(
      "You leave it\nuntouched for now.\f"
        .. "Return later to\ninspect it.",
      "Du lässt sie\nvorerst liegen.\f"
        .. "Komm später zurück\nund prüfe sie.")
  end

  local function queueCapsuleOffer(game)
    local s = state()
    if s.capsuleFound or not capsuleReady(s) then return false end
    s.capsuleAvailable = true
    if runtime.capsuleDeclinedMapStay then return false end
    if runtime.capsuleOfferPending then return true end
    runtime.capsuleOfferPending = true
    if type(opts.onCapsuleReady) == "function" then
      opts.onCapsuleReady(activeGame(game), capsuleText("offer"), function(yes)
        return J.inspectCapsule(yes, game)
      end)
    end
    return true
  end

  local function receiverCallback(game, source)
    if type(opts.onReceiverRepaired) == "function" then
      opts.onReceiverRepaired(activeGame(game), source, J)
    end
  end

  local function onboardingText(policy)
    local mode = modeName(policy)
    return tr(
      "JOHTO SIGNALS can\nstart with a quest\nor right away.\f"
        .. "Set the receiver\nright now?\f"
        .. "START WITH\n" .. mode .. "?",
      "JOHTO-SIGNALE\nstarten per Quest\noder direkt.\f"
        .. "Empfänger sofort\nabstimmen?\f"
        .. "START MIT\n" .. mode .. "?")
  end

  local function maybeRequestOnboarding(game)
    game = activeGame(game)
    local s = state()
    local policy = requestedStartPolicy()
    if not signalsEnabled() or policy == "quest"
        or s.onboardingComplete or s.receiverRepaired
        or not hasStarter(game) then
      runtime.onboardingPending = nil
      return false
    end
    if runtime.onboardingPending
        and runtime.onboardingPending.policy == policy then
      return true
    end
    runtime.onboardingPending = {
      policy = policy,
      text = onboardingText(policy),
    }
    if type(opts.onOnboardingRequired) == "function" then
      opts.onOnboardingRequired(game, policy,
        runtime.onboardingPending.text, function(accepted)
          return J.completeOnboarding(accepted, policy, game)
        end)
    end
    return true
  end

  function J.completeOnboarding(accepted, policy, game)
    game = activeGame(game)
    local s = state()
    if s.onboardingComplete then
      runtime.onboardingPending = nil
      return false, "already-complete"
    end
    if not runtime.onboardingPending then
      maybeRequestOnboarding(game)
    end
    if not runtime.onboardingPending or not hasStarter(game) then
      return false, "onboarding-not-pending"
    end
    policy = normalizeStartPolicy(policy
      or runtime.onboardingPending and runtime.onboardingPending.policy)
    if policy ~= runtime.onboardingPending.policy then
      return false, "policy-mismatch"
    end
    if policy == "quest" then accepted = false end
    s.onboardingComplete = true
    runtime.onboardingPending = nil
    if not accepted then
      s.startPolicy = "quest"
      persist()
      return true, "field-quest", tr(
        "The field quest\nstays active.",
        "Die Feldquest\nbleibt aktiv.")
    end
    s.startPolicy = policy
    s.capsuleFound = true
    s.capsuleAvailable = true
    s.questStarted = true
    s.receiverRepaired = true
    s.mode = normalizeMode(policy)
    s.modeChosen = true
    if s.mode == MODES.WANDERWAVES then ensureWave(s, game) end
    persist()
    receiverCallback(game, "onboarding")
    return true, "configured", tr(
      "Receiver ready.\nCurrent:\n" .. modeName(s.mode) .. ".",
      "Empfänger bereit.\nStrom:\n" .. modeName(s.mode) .. ".")
  end

  function J.inspectCapsule(accepted, game)
    local s = state()
    if s.capsuleFound then
      runtime.capsuleOfferPending = false
      return false, "already-found", capsuleText("found")
    end
    if not capsuleReady(s) then
      return false, "not-ready", tr(
        "No foreign capsule\nhas reached shore.",
        "Keine Glaskapsel\nliegt am Strand.")
    end
    runtime.capsuleOfferPending = false
    if accepted ~= true then
      runtime.capsuleDeclinedMapStay = true
      return false, "declined", capsuleText("declined")
    end
    runtime.capsuleDeclinedMapStay = false
    s.capsuleAvailable = true
    s.capsuleFound = true
    s.questStarted = true
    persist()
    if type(opts.onCapsuleFound) == "function" then
      opts.onCapsuleFound(activeGame(game), J)
    end
    return true, "found", capsuleText("found")
  end

  function J.onResearcherRepair(game)
    local s = state()
    if not s.capsuleFound then
      return false, "capsule-missing", tr(
        "RESEARCHER: I need\nthe source capsule\nto tune the relay.",
        "FORSCHER: Ich\nbrauche die Kapsel\nfür das Relais.")
    end
    if s.receiverRepaired then
      return false, "already-repaired", tr(
        "RESEARCHER: The\nmigration relay is\nstable.",
        "FORSCHER: Das\nMigrationsrelais\nläuft stabil.")
    end
    s.receiverRepaired = true
    s.mode = MODES.KANTO_FIRST
    s.modeChosen = false
    s.startPolicy = "quest"
    persist()
    receiverCallback(game, "researcher")
    return true, "repaired", tr(
      "RESEARCHER: Signal\nrestored.\f"
        .. "Nothing crosses\nuntil you choose\na current.\f"
        .. "KANTO FIRST\nseals the current.\f"
        .. "WANDERWAVES\n2 PCT / 4 PCT.\f"
        .. "JOHTO UNLEASHED\nabout 10 PCT.",
      "FORSCHER: Signal\nrepariert.\f"
        .. "Nichts wandert\nohne deine Wahl.\f"
        .. "KANTO ZUERST\nversiegelt.\f"
        .. "WANDERWELLEN\n2 PROZ / 4 PROZ.\f"
        .. "JOHTO ENTFESSELT\netwa 10 PROZ.")
  end

  function J.setMode(game, mode)
    if type(game) == "string" and mode == nil then
      mode, game = game, nil
    end
    local s = state()
    local normalized = MODE_ALIASES[mode]
    if not normalized then
      return false, "invalid-mode", tr(
        "Receiver rejects\nthat frequency.",
        "Empfänger lehnt\ndiese Frequenz ab.")
    end
    if not s.receiverRepaired then
      return false, "receiver-locked", tr(
        "Repair the damaged\nreceiver first.",
        "Repariere zuerst\nden Empfänger.")
    end
    s.mode = normalized
    s.modeChosen = true
    if normalized == MODES.WANDERWAVES then ensureWave(s, game) end
    persist()
    local detail
    if normalized == MODES.WANDERWAVES then
      detail = tr(
        "Matching habitats\ncarry 2 PCT.\nStrong: 4 PCT.",
        "Passende Habitate\ntragen 2 PROZ.\nStark: 4 PROZ.")
    elseif normalized == MODES.UNLEASHED then
      detail = tr(
        "Matching habitats\nhold about 10 PCT.",
        "Passende Habitate\netwa 10 PROZ.")
    else
      detail = tr(
        "Kanto encounters\nremain unchanged.",
        "Kanto-Begegnungen\nbleiben gleich.")
    end
    return true, "mode-set", tr(
      "Current set:\n", "Strom gesetzt:\n") .. modeName(normalized)
      .. ".\f" .. detail
  end

  local function traceRowForMap(mapId)
    for _, species in ipairs(TRACE_ORDER) do
      local row = SPECIAL[species]
      if row.traceMap == mapId then return species, row end
    end
    return nil
  end

  local function traceProgress(s)
    local count = 0
    for _, species in ipairs(TRACE_ORDER) do
      if s.traces[SPECIAL[species].trace] then count = count + 1 end
    end
    return count
  end

  function J.scanTrace(game, mapValue)
    if type(game) == "string" and mapValue == nil then
      mapValue, game = game, nil
    end
    local s = state()
    if not s.receiverRepaired then
      return false, "receiver-locked", tr(
        "Damaged receiver:\nonly static.",
        "Empfänger defekt:\nnur Rauschen.")
    end
    local mapId = mapIdOf(mapValue, game)
    local species, row = traceRowForMap(mapId)
    if not row then
      for _, id in ipairs(TRACE_ORDER) do
        local missing = SPECIAL[id]
        if not s.traces[missing.trace] then
          return false, "weak-echo", tr(
            "Weak primal echo.\fIt points toward:\n"
              .. missing.traceEn .. ".",
            "Schwaches Ur-Echo.\fEs weist auf:\n"
              .. missing.traceDe .. ".")
        end
      end
      return false, "all-recorded", tr(
        "All four traces\nare synchronized.",
        "Alle vier Urspuren\nsind synchron.")
    end
    if s.traces[row.trace] then
      return false, "already-recorded", tr(
        "Trace already\nrecorded:\n",
        "Urspur schon\nerfasst:\n")
        .. speciesName(game, species) .. "."
    end
    s.traces[row.trace] = true
    persist()
    return true, "trace-recorded", tr(
      "A primal pattern\nanswers the relay!\f"
        .. "Signature:\n" .. speciesName(game, species) .. "\f"
        .. "Its path leads to:\n" .. row.habitatEn .. ".",
      "Ein Urmuster\nantwortet!\f"
        .. "Signatur:\n" .. speciesName(game, species) .. "\f"
        .. "Seine Spur führt:\n" .. row.habitatDe .. "."),
      species
  end

  function J.objective(game)
    game = activeGame(game)
    local s = state()
    if not signalsEnabled() then
      return tr(
        "Johto Signals: OFF\nKanto stays normal",
        "JOHTO: AUS\nKanto unverändert")
    end
    if not hasStarter(game) then
      return tr(
        "Choose your first\nPOKéMON with OAK.",
        "Wähle dein erstes\nPOKéMON bei EICH.")
    end
    if not hasDex(game) and not s.capsuleFound then
      return tr(
        "Finish OAK's task.\nGet the POKéDEX.",
        "Hilf PROF.EICH.\nHol den POKéDEX.")
    end
    if not s.capsuleFound then
      if capsuleReady(s) then
        return tr(
          "Inspect the glint\nsouth of PALLET.",
          "Prüfe das Glitzern\nan ALABASTIAS\nSüdküste.")
      end
      return tr(
        "No foreign signal.\nContinue through\nKanto.",
        "Noch kein Signal.\nReise durch Kanto.")
    end
    if not s.receiverRepaired then
      return tr(
        "Ask the boatman at\nPALLET's pier.\f"
          .. "Sail to DRIFTGLASS\nwith the sender.",
        "Frag den Bootsmann\nam ALABASTIA-Steg.\f"
          .. "Fahre mit Sender\nnach DRIFTGLAS.")
    end
    if not s.modeChosen then
      return tr(
        "Ask the Driftglass\nresearcher to set\nthe current.",
        "Bitte den Forscher\nauf DRIFTGLAS, den\nStrom zu wählen.")
    end
    if s.mode == MODES.KANTO_FIRST then
      return tr(
        "KANTO FIRST\nis active.\f"
          .. "Change the current\nfor Johto signals.",
        "KANTO ZUERST\nist aktiv.\f"
          .. "Wähle einen Strom\nfür Johto-Signale.")
    end
    for _, species in ipairs(TRACE_ORDER) do
      local row = SPECIAL[species]
      if not s.traces[row.trace] then
        return tr(
          "A primal echo\npoints toward:\f" .. row.traceEn .. ".",
          "Ein Ur-Echo\nweist auf:\f" .. row.traceDe .. ".")
          .. tr(
            "\fASCENDANT / WORLD\fJOHTO SIGNALS /\nSCAN CURRENT AREA",
            "\fASCENDANT / WELT\fJOHTO-SIGNALE /\nGEBIET SCANNEN")
      end
    end
    return tr(
      "All four traces\nare synchronized.\nFollow readings.",
      "Alle vier Urspuren\nsind synchron.\nFolge den Daten.")
  end

  function J.status(game)
    game = activeGame(game)
    local s = state()
    local stage
    if not signalsEnabled() then
      stage = tr("DISABLED", "AUSGESCHALTET")
    elseif not s.capsuleFound then
      stage = capsuleReady(s)
        and tr("SHORE SIGNAL", "KÜSTENSIGNAL")
        or tr("NO SIGNAL", "KEIN SIGNAL")
    elseif not s.receiverRepaired then
      stage = tr("RECEIVER DAMAGED", "EMPFÄNGER DEFEKT")
    elseif not s.modeChosen then
      stage = tr("AWAITING CHOICE", "WAHL AUSSTEHEND")
    else
      stage = modeName(s.mode)
    end

    local strength = tr("SEALED", "VERSIEGELT")
    local odds = tr("Kanto unchanged", "Kanto unverändert")
    if s.receiverRepaired and s.mode == MODES.WANDERWAVES then
      strength = s.strongSignal and tr("STRONG", "STARK")
        or tr("NORMAL", "NORMAL")
      odds = s.strongSignal and tr("4 PCT", "4 PROZ")
        or tr("2 PCT", "2 PROZ")
    elseif s.receiverRepaired and s.mode == MODES.UNLEASHED then
      strength = tr("OPEN", "OFFEN")
      odds = tr("10 PCT", "10 PROZ")
    end

    local traces = {}
    for _, species in ipairs(TRACE_ORDER) do
      local row = SPECIAL[species]
      if s.traces[row.trace] then
        traces[#traces + 1] = speciesName(game, species)
      end
    end
    if #traces == 0 then traces[1] = "---" end

    return tr(
      "JOHTO SIGNALS\nStatus:\n" .. stage
        .. "\fSignal:\n" .. strength .. "\nRate:\n" .. odds
        .. "\fPrimal traces: " .. traceProgress(s) .. "/4\n"
        .. table.concat(traces, "\n")
        .. "\fNEXT\n" .. J.objective(game),
      "JOHTO-SIGNALE\nStatus:\n" .. stage
        .. "\fSignal:\n" .. strength .. "\nNormalrate:\n" .. odds
        .. "\fUrspuren: " .. traceProgress(s) .. "/4\n"
        .. table.concat(traces, "\n")
        .. "\fNÄCHSTES ZIEL\n" .. J.objective(game))
  end

  local function terrainMatches(expected, actual)
    return expected == actual
  end

  local function habitatFor(species)
    local authored = johto.habitats and johto.habitats[species]
    if authored then return authored end
    local special = SPECIAL[species]
    if special then
      return {
        map = special.habitatMap,
        terrain = special.terrain,
        level = special.level,
      }
    end
    return nil
  end

  local function matchesHabitat(species, ctx)
    local habitat = habitatFor(species)
    return habitat and ctx and habitat.map == ctx.mapId
      and terrainMatches(habitat.terrain, ctx.terrain)
  end

  local function ordinaryCandidates(ctx, snapshot)
    local s = snapshot or state()
    local pool = {}
    local source = {}
    if s.mode == MODES.WANDERWAVES then
      local wave = WAVES[s.waveIndex]
      source = wave and wave.species or {}
    elseif s.mode == MODES.UNLEASHED then
      source = UNLEASHED_BASES
    end
    for _, species in ipairs(source) do
      if ORDINARY_ALLOWED[species] and not EXCLUDED[species]
          and matchesHabitat(species, ctx) then
        pool[#pool + 1] = species
      end
    end
    table.sort(pool)
    return pool
  end

  local function rareCandidates(ctx, snapshot)
    local s = snapshot or state()
    local pool = {}
    for _, species in ipairs(TRACE_ORDER) do
      local row = SPECIAL[species]
      if s.traces[row.trace] and matchesHabitat(species, ctx) then
        pool[#pool + 1] = species
      end
    end
    return pool
  end

  local function cloneEncounter(native, species)
    local out = {}
    for key, value in pairs(native) do out[key] = value end
    local habitat = habitatFor(species)
    out.species = species
    out.level = habitat and habitat.level or native.level
    -- Mythic Signals and any later outer encounter hook must preserve a
    -- committed 256th/512th primal-trace result.
    out.kaProtected = true
    out.kaEncounterSource = "johto_signals"
    return out
  end

  local function ordinaryChance(s)
    if s.mode == MODES.UNLEASHED then return 10 end
    if s.mode == MODES.WANDERWAVES then
      return s.strongSignal and 4 or 2
    end
    return 0
  end

  -- Pure with respect to save and module runtime.  It consumes only the
  -- supplied RNG and returns a transaction description for later commit.
  local function resolveCandidate(native, ctx, snapshot)
    local s = snapshot or state()
    if not (signalsEnabled() and native and ctx and type(ctx.rng) == "function"
        and s.receiverRepaired and s.modeChosen
        and s.mode ~= MODES.KANTO_FIRST) then
      return native, nil
    end

    local result = native
    local rarePool = rareCandidates(ctx, s)
    local rareSpecies
    if #rarePool == 1 then
      rareSpecies = rarePool[1]
    elseif #rarePool > 1 then
      rareSpecies = rarePool[ctx.rng(1, #rarePool)]
    end

    local transaction = {
      expectedSpecies = native.species,
      expectedLevel = native.level,
      rareSpecies = rareSpecies,
      rareHit = false,
    }

    if rareSpecies then
      local denominator = s.mode == MODES.UNLEASHED and 256 or 512
      local current = integer(s.rarePity[rareSpecies], 0)
      local nextCount = current + 1
      local hit = nextCount >= denominator
        or ctx.rng(1, denominator) == 1
      transaction.rareBasePity = current
      transaction.rareNextPity = nextCount
      transaction.rareDenominator = denominator
      transaction.rareHit = hit
      if hit then result = cloneEncounter(native, rareSpecies) end
    end

    if not transaction.rareHit then
      local candidates = ordinaryCandidates(ctx, s)
      local chance = ordinaryChance(s)
      if #candidates > 0 and chance > 0
          and ctx.rng(1, 100) <= chance then
        local species = candidates[ctx.rng(1, #candidates)]
        result = cloneEncounter(native, species)
      end
    end

    transaction.expectedSpecies = result.species
    transaction.expectedLevel = result.level
    return result, transaction
  end

  function J.cancelCandidate(reason)
    local pending = runtime.pendingCandidate
    runtime.pendingCandidate = nil
    if pending then pending.cancelReason = reason or "cancelled" end
    return pending ~= nil, pending
  end

  function J.rollReplacement(native, ctx)
    -- A previous roll that never produced battle.started was suppressed by
    -- Repel or replaced outside this module.
    J.cancelCandidate("superseded-roll")
    local result, transaction = resolveCandidate(native, ctx)
    if transaction then
      runtime.candidateSerial = runtime.candidateSerial + 1
      transaction.serial = runtime.candidateSerial
      runtime.pendingCandidate = transaction
    end
    return result
  end

  -- Wilds-style compatibility can prepare several visible overworld spawns
  -- before one of them is touched.  It therefore receives an independent
  -- transaction instead of using the single encounter.roll pending slot.
  function J.rollWildsReplacement(native, ctx)
    local result, transaction = resolveCandidate(native, ctx)
    if transaction then
      runtime.candidateSerial = runtime.candidateSerial + 1
      transaction.serial = runtime.candidateSerial
      transaction.wilds = true
    end
    return result, transaction
  end

  local function candidateSpecies(value)
    if type(value) == "string" then return value end
    if type(value) ~= "table" then return nil end
    if type(value.species) == "string" then return value.species end
    if type(value.expectedSpecies) == "string" then
      return value.expectedSpecies
    end
    local battle = value.battle or value
    if battle.enemy and battle.enemy.mon then
      return battle.enemy.mon.species
    end
    if battle.enemy and type(battle.enemy.species) == "string" then
      return battle.enemy.species
    end
    return nil
  end

  local function candidateLevel(value)
    if type(value) ~= "table" then return nil end
    if type(value.level) == "number" then return value.level end
    if type(value.expectedLevel) == "number" then return value.expectedLevel end
    local battle = value.battle or value
    if battle.enemy and battle.enemy.mon
        and type(battle.enemy.mon.level) == "number" then
      return battle.enemy.mon.level
    end
    if battle.enemy and type(battle.enemy.level) == "number" then
      return battle.enemy.level
    end
    return nil
  end

  local function commitTransaction(pending, value)
    if not pending then return false, "none" end
    if pending.committed then return false, "already-committed" end
    if pending.cancelled then return false, "cancelled" end
    local species = candidateSpecies(value)
    if species ~= pending.expectedSpecies then
      pending.cancelled = true
      pending.cancelReason = "battle-mismatch"
      return false, "mismatch"
    end
    local level = candidateLevel(value)
    if pending.expectedLevel ~= nil and level ~= pending.expectedLevel then
      pending.cancelled = true
      pending.cancelReason = "battle-level-mismatch"
      return false, "level-mismatch"
    end
    pending.committed = true
    if pending.rareSpecies then
      local s = state()
      local current = integer(s.rarePity[pending.rareSpecies], 0)
      if pending.rareHit then
        s.rarePity[pending.rareSpecies] = 0
      else
        s.rarePity[pending.rareSpecies] = math.max(
          current, pending.rareBasePity or 0) + 1
      end
      persist()
    end
    return true, pending
  end

  function J.commitCandidate(value)
    local pending = runtime.pendingCandidate
    if not pending then return false, "none" end
    runtime.pendingCandidate = nil
    return commitTransaction(pending, value)
  end

  function J.commitWildsSpawn(transaction, value)
    return commitTransaction(transaction, value)
  end

  function J.cancelWildsSpawn(transaction, reason)
    if not transaction or transaction.committed or transaction.cancelled then
      return false
    end
    transaction.cancelled = true
    transaction.cancelReason = reason or "spawn-cancelled"
    return true
  end

  local function onStep(game, ev)
    game = activeGame(game or ev and ev.game)
    if game then J.game = game end
    J.cancelCandidate("next-world-step")
    if not questInfrastructureEnabled() then
      runtime.onboardingPending = nil
      return
    end
    maybeRequestOnboarding(game)
    local s = state()
    local changed = false
    if hasStarter(game) and hasDex(game) and not s.capsuleFound then
      if not s.capsuleTarget then
        s.capsuleTarget = stepRandom(128, 768)
        changed = true
      end
      s.pokedexSteps = s.pokedexSteps + 1
      changed = true
      if capsuleReady(s) and not s.capsuleAvailable then
        s.capsuleAvailable = true
        changed = true
      end
      if s.capsuleAvailable and mapIdOf(ev, game) == "PALLET_TOWN" then
        queueCapsuleOffer(game)
      end
    end
    if signalsEnabled() and s.receiverRepaired and s.modeChosen
        and s.mode == MODES.WANDERWAVES then
      if ensureWave(s, game) then changed = true end
      s.waveSteps = math.max(0, s.waveSteps - 1)
      changed = true
      if s.waveSteps == 0 then chooseWave(s, game, stepRandom) end
    end
    if changed then persist() end
  end

  local function onMapEntered(ev)
    local game = activeGame(ev and ev.game)
    if game then J.game = game end
    local mapId = mapIdOf(ev, game)
    if mapId == "PALLET_TOWN" and runtime.lastEnteredMap ~= "PALLET_TOWN" then
      runtime.capsuleDeclinedMapStay = false
    elseif mapId ~= "PALLET_TOWN" then
      runtime.capsuleDeclinedMapStay = false
    end
    runtime.lastEnteredMap = mapId
    if mapId ~= "PALLET_TOWN" then
      runtime.capsuleOfferPending = false
    end
    if not questInfrastructureEnabled() then
      runtime.onboardingPending = nil
      return
    end
    maybeRequestOnboarding(game)
    local s = state()
    if mapId == "PALLET_TOWN" and hasStarter(game) and hasDex(game)
        and not s.capsuleFound then
      s.palletVisits = s.palletVisits + 1
      if s.palletVisits >= 5 then s.capsuleAvailable = true end
      persist()
      if capsuleReady(s) then queueCapsuleOffer(game) end
    end
  end

  local function onBattleStarted(ev)
    local battle = ev and ev.battle
    local kind = ev and ev.kind or battle and battle.kind
    if kind == "trainer" or kind == "link" then
      J.cancelCandidate("non-wild-battle")
      return
    end
    J.commitCandidate(ev or battle)
  end

  function J.install(game)
    J.game = game or J.game
    -- save.loaded may point the same controller at a different slot.
    cachedSection = nil
    runtime.pendingCandidate = nil
    runtime.capsuleOfferPending = false
    runtime.capsuleDeclinedMapStay = false
    runtime.lastEnteredMap = nil
    runtime.onboardingPending = nil
    local s = state()
    local changed = false
    if s.receiverRepaired and s.modeChosen
        and s.mode == MODES.WANDERWAVES then
      changed = ensureWave(s, J.game)
    end
    if changed then persist() end
    maybeRequestOnboarding(J.game)
    return s
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
      local native = nextRoll(encDef, ctx)
      return J.rollReplacement(native, ctx)
    end, J.ENCOUNTER_PRIORITY)
  end

  if mod.events and type(mod.events.on) == "function" then
    mod.events:on("world.stepped", function(ev)
      onStep(ev and ev.game, ev)
    end, -30)
    mod.events:on("map.entered", onMapEntered, -30)
    mod.events:on("battle.started", onBattleStarted, -30)
    -- Reset the cached save section before presentation/content listeners
    -- inspect travel permission for the newly loaded slot.
    mod.events:on("save.loaded", function(ev)
      J.install(ev and ev.game)
    end, 300)
    mod.events:on("game.ready", function(ev)
      J.install(ev and ev.game)
    end, 300)
    mod.events:on("mod.options_changed", function(ev)
      if ev and (ev.key == "johto_signals_start"
          or ev.key == "johto_signals_current"
          or ev.key == "johto_signals_enable") then
        runtime.onboardingPending = nil
        maybeRequestOnboarding(J.game)
      end
    end, -30)
  end

  J.state = state
  J.persist = persist
  J.modes = MODES
  J.waves = WAVES
  J.special = SPECIAL
  J.excluded = EXCLUDED
  J.ordinaryAllowed = ORDINARY_ALLOWED
  J.ordinaryCandidates = ordinaryCandidates
  J.rareCandidates = rareCandidates
  J.resolveCandidate = resolveCandidate
  J.enabled = signalsEnabled
  J.questEnabled = questInfrastructureEnabled
  J.hasStarter = function(game) return hasStarter(activeGame(game)) end
  J.hasPokedex = function(game) return hasDex(activeGame(game)) end
  J.capsuleReady = function() return capsuleReady(state()) end
  J.requestedStartPolicy = requestedStartPolicy
  J.maybeRequestOnboarding = maybeRequestOnboarding
  J.onboardingText = onboardingText
  J.capsuleText = capsuleText
  J.onStep = onStep
  J.onMapEntered = onMapEntered
  J.pendingCandidate = function() return runtime.pendingCandidate end
  J.runtimeStatus = function()
    return {
      capsuleOfferPending = runtime.capsuleOfferPending,
      capsuleDeclinedMapStay = runtime.capsuleDeclinedMapStay,
      onboardingPending = runtime.onboardingPending,
      pendingCandidate = runtime.pendingCandidate,
    }
  end

  return J
end
