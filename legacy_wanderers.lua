-- KA-INTERNAL: LEGACY-WANDERERS-001

return function(mod, opts)
  opts = opts or {}
  local journey = assert(opts.journey, "legacy wanderers need legacy journey")
  local i18n = opts.i18n
  local W = {
    STATE_VERSION = 5,
    MIN_STEPS = 200,
    HARD_MAX_STEPS = 1800,
    MIN_MAP_CHANGES = 2,
    MAX_MAP_CHANGES = 3,
    HARD_MAX_MAP_CHANGES = 4,
    ENCORE_MIN_STEPS = 240,
    ENCORE_MAX_STEPS = 480,
    ENCORE_DENOMINATOR = 10,
    MAX_ENCOUNTERS_PER_MAP = 2,
    LARGE_MAP_AREA = 180,
    MIN_LEVEL_BONUS = 1,
    MAX_LEVEL_BONUS = 3,
    MAX_BATTLE_TEAM = 4,
    MAX_LOSS_RELIEF = 3,
    LOSS_TEAM_REDUCTION_AT = 2,
    MIN_EXP_PERCENT = 15,
    MAX_EXP_PERCENT = 20,
    MASTER_BALL_DENOMINATOR = 32,
    EXP_SHARE_CATCHUP_DENOMINATOR = 4,
    MULTIPLIER2_CATCHUP_DENOMINATOR = 6,
    MULTIPLIER3_CATCHUP_DENOMINATOR = 12,
    MULTIPLIER5_CATCHUP_DENOMINATOR = 24,
    active = nil,
    game = nil,
  }
  W.FREQUENCY_PROFILES = {
    never = { disabled = true },
    rare = {
      minSteps = 600, minMaps = 4, maxMaps = 6,
      hardMaxSteps = 5000, hardMaxMaps = 7,
      encoreHits = 3, encoreDenominator = 100,
    },
    normal = {
      minSteps = 200, minMaps = 2, maxMaps = 3,
      hardMaxSteps = 1800, hardMaxMaps = 4,
      encoreHits = 1, encoreDenominator = 10,
    },
    often = {
      minSteps = 200, minMaps = 1, maxMaps = 2,
      hardMaxSteps = 900, hardMaxMaps = 3,
      encoreHits = 1, encoreDenominator = 5,
    },
  }
  local titleProvider = opts.titles
  local rewardController = opts.rewards
  local recruitmentProvider = opts.recruitment
  local masteryProvider = opts.mastery
  local clockProvider = opts.clock
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary

  local function beyondActive(game)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(game or W.game)
  end

  local function speciesAllowed(game, species)
    local pokemon = game and game.data and game.data.pokemon or {}
    if type(species) ~= "string" or type(pokemon[species]) ~= "table" then
      return false
    end
    if beyondActive(game) then return true end
    local dex
    if type(beyondKanto) == "table"
        and type(beyondKanto.speciesDex) == "function" then
      dex = beyondKanto.speciesDex(game, species)
    else
      dex = tonumber(pokemon[species].dex)
    end
    dex = tonumber(dex)
    return dex ~= nil and dex >= 1 and dex <= 151
  end

  -- Fail closed: only canonical Kanto outdoor routes and city/town surfaces
  -- count. Interiors, caves, Safari maps and all HEVO dungeon ids therefore
  -- remain ineligible even when their tiles happen to look outdoor-like.
  local OUTDOOR_MAPS = {}
  for n = 1, 25 do OUTDOOR_MAPS["ROUTE_" .. n] = true end
  for _, id in ipairs({
    "PALLET_TOWN", "VIRIDIAN_CITY", "PEWTER_CITY", "CERULEAN_CITY",
    "LAVENDER_TOWN", "VERMILION_CITY", "CELADON_CITY", "FUCHSIA_CITY",
    "CINNABAR_ISLAND", "INDIGO_PLATEAU", "SAFFRON_CITY",
  }) do OUTDOOR_MAPS[id] = true end
  W.ELIGIBLE_MAPS = OUTDOOR_MAPS

  W.ARCHETYPES = {
    { class = "OPP_COOLTRAINER_M", sprite = "SPRITE_COOLTRAINER_M" },
    { class = "OPP_COOLTRAINER_F", sprite = "SPRITE_COOLTRAINER_F" },
    { class = "OPP_JR_TRAINER_M", sprite = "SPRITE_COOLTRAINER_M" },
    { class = "OPP_JR_TRAINER_F", sprite = "SPRITE_COOLTRAINER_F" },
    { class = "OPP_SCIENTIST", sprite = "SPRITE_SCIENTIST" },
    { class = "OPP_POKEMANIAC", sprite = "SPRITE_SUPER_NERD" },
    { class = "OPP_SUPER_NERD", sprite = "SPRITE_SUPER_NERD" },
  }
  local DEFAULT_ARCHETYPES = W.ARCHETYPES

  -- Battle portraits and overworld sprites are separate registries.  This
  -- table only claims an exact field representation where one really ships;
  -- every other live trainer remains eligible but is visibly marked as using
  -- the neutral traveler fallback in the runtime descriptor.
  W.FIELD_SPRITES = {
    OPP_YOUNGSTER = "SPRITE_YOUNGSTER",
    OPP_BUG_CATCHER = "SPRITE_YOUNGSTER",
    OPP_LASS = "SPRITE_GIRL",
    OPP_SAILOR = "SPRITE_SAILOR",
    OPP_JR_TRAINER_M = "SPRITE_COOLTRAINER_M",
    OPP_JR_TRAINER_F = "SPRITE_COOLTRAINER_F",
    OPP_POKEMANIAC = "SPRITE_SUPER_NERD",
    OPP_SUPER_NERD = "SPRITE_SUPER_NERD",
    OPP_HIKER = "SPRITE_HIKER",
    OPP_BIKER = "SPRITE_BIKER",
    OPP_BURGLAR = "SPRITE_GAMBLER",
    OPP_ENGINEER = "SPRITE_SCIENTIST",
    OPP_JUGGLER = "SPRITE_GAMBLER",
    OPP_FISHER = "SPRITE_FISHER",
    OPP_SWIMMER = "SPRITE_SWIMMER",
    OPP_CUE_BALL = "SPRITE_BIKER",
    OPP_GAMBLER = "SPRITE_GAMBLER",
    OPP_BEAUTY = "SPRITE_BEAUTY",
    OPP_PSYCHIC_TR = "SPRITE_ROCKER",
    OPP_ROCKER = "SPRITE_ROCKER",
    OPP_JUGGLER_X = "SPRITE_GAMBLER",
    OPP_TAMER = "SPRITE_COOLTRAINER_M",
    OPP_BIRD_KEEPER = "SPRITE_COOLTRAINER_M",
    OPP_BLACKBELT = "SPRITE_HIKER",
    OPP_RIVAL1 = "SPRITE_BLUE",
    OPP_PROF_OAK = "SPRITE_OAK",
    OPP_CHIEF = "SPRITE_GENTLEMAN",
    OPP_SCIENTIST = "SPRITE_SCIENTIST",
    OPP_GIOVANNI = "SPRITE_GIOVANNI",
    OPP_ROCKET = "SPRITE_ROCKET",
    OPP_COOLTRAINER_M = "SPRITE_COOLTRAINER_M",
    OPP_COOLTRAINER_F = "SPRITE_COOLTRAINER_F",
    OPP_GENTLEMAN = "SPRITE_GENTLEMAN",
    OPP_CHANNELER = "SPRITE_CHANNELER",
  }

  local STORY_CLASSES = {
    OPP_PROF_OAK = true,
    OPP_RIVAL1 = true, OPP_RIVAL2 = true, OPP_RIVAL3 = true,
    OPP_BROCK = true, OPP_MISTY = true, OPP_LT_SURGE = true,
    OPP_ERIKA = true, OPP_KOGA = true, OPP_SABRINA = true,
    OPP_BLAINE = true, OPP_GIOVANNI = true,
    OPP_LORELEI = true, OPP_BRUNO = true, OPP_AGATHA = true,
    OPP_LANCE = true, OPP_ROCKET = true, OPP_CHIEF = true,
    OPP_UNUSED_JUGGLER = true,
    -- Dedicated Kanto Ascendant finale classes are live trainer records,
    -- but they are authored story bosses rather than ordinary road trainers.
    KA_JOHTO_SILVER = true, KA_JOHTO_KRIS = true,
    KA_JOHTO_GOLD = true,
  }

  local APRICORN_BALLS = {
    "FAST_BALL", "FRIEND_BALL", "HEAVY_BALL", "LEVEL_BALL",
    "LOVE_BALL", "LURE_BALL", "MOON_BALL",
  }
  W.APRICORN_BALLS = APRICORN_BALLS

  local GEN2_TM_BY_NUMBER = {
    [1] = "DYNAMIC_PUNCH", [2] = "HEADBUTT", [3] = "CURSE",
    [4] = "ROLLOUT", [5] = "ROAR", [6] = "TOXIC",
    [7] = "ZAP_CANNON", [8] = "ROCK_SMASH", [9] = "PSYCH_UP",
    [10] = "HIDDEN_POWER", [11] = "SUNNY_DAY", [12] = "SWEET_SCENT",
    [13] = "SNORE", [14] = "BLIZZARD", [15] = "HYPER_BEAM",
    [16] = "ICY_WIND", [17] = "PROTECT", [18] = "RAIN_DANCE",
    [19] = "GIGA_DRAIN", [20] = "ENDURE", [21] = "FRUSTRATION",
    [22] = "SOLARBEAM", [23] = "IRON_TAIL", [24] = "DRAGONBREATH",
    [25] = "THUNDER", [26] = "EARTHQUAKE", [27] = "RETURN",
    [28] = "DIG", [29] = "PSYCHIC_M", [30] = "SHADOW_BALL",
    [31] = "MUD_SLAP", [32] = "DOUBLE_TEAM", [33] = "ICE_PUNCH",
    [34] = "SWAGGER", [35] = "SLEEP_TALK", [36] = "SLUDGE_BOMB",
    [37] = "SANDSTORM", [38] = "FIRE_BLAST", [39] = "SWIFT",
    [40] = "DEFENSE_CURL", [41] = "THUNDERPUNCH",
    [42] = "DREAM_EATER", [43] = "DETECT", [44] = "REST",
    [45] = "ATTRACT", [46] = "THIEF", [47] = "STEEL_WING",
    [48] = "FIRE_PUNCH", [49] = "FURY_CUTTER", [50] = "NIGHTMARE",
  }

  local GEN3_TM_BY_NUMBER = {
    [1] = "FOCUS_PUNCH", [2] = "DRAGON_CLAW", [3] = "WATER_PULSE",
    [4] = "CALM_MIND", [5] = "ROAR", [6] = "TOXIC", [7] = "HAIL",
    [8] = "BULK_UP", [9] = "BULLET_SEED", [10] = "HIDDEN_POWER",
    [11] = "SUNNY_DAY", [12] = "TAUNT", [13] = "ICE_BEAM",
    [14] = "BLIZZARD", [15] = "HYPER_BEAM", [16] = "LIGHT_SCREEN",
    [17] = "PROTECT", [18] = "RAIN_DANCE", [19] = "GIGA_DRAIN",
    [20] = "SAFEGUARD", [21] = "FRUSTRATION", [22] = "SOLARBEAM",
    [23] = "IRON_TAIL", [24] = "THUNDERBOLT", [25] = "THUNDER",
    [26] = "EARTHQUAKE", [27] = "RETURN", [28] = "DIG",
    [29] = "PSYCHIC_M", [30] = "SHADOW_BALL", [31] = "BRICK_BREAK",
    [32] = "DOUBLE_TEAM", [33] = "REFLECT", [34] = "SHOCK_WAVE",
    [35] = "FLAMETHROWER", [36] = "SLUDGE_BOMB", [37] = "SANDSTORM",
    [38] = "FIRE_BLAST", [39] = "ROCK_TOMB", [40] = "AERIAL_ACE",
    [41] = "TORMENT", [42] = "FACADE", [43] = "SECRET_POWER",
    [44] = "REST", [45] = "ATTRACT", [46] = "THIEF",
    [47] = "STEEL_WING", [48] = "SKILL_SWAP", [49] = "SNATCH",
    [50] = "OVERHEAT",
  }

  local HOENN_SIGNATURE_TMS = {
    FRENZY_PLANT = true, BLAST_BURN = true, HYDRO_CANNON = true,
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function integer(value, default)
    value = math.floor(tonumber(value) or default or 0)
    return math.max(0, value)
  end

  local function clamp(value, low, high)
    value = math.floor(tonumber(value) or low)
    return math.max(low, math.min(high, value))
  end

  local function rawRandom(low, high, purpose)
    local supplied = opts.random
    if type(supplied) == "function" then
      local value = supplied(low, high, purpose)
      if tonumber(value) then return clamp(value, low, high) end
    end
    if love and love.math and type(love.math.random) == "function" then
      return love.math.random(low, high)
    end
    return math.random(low, high)
  end

  local function configuredPercent(value, low, high, purpose)
    if type(value) == "function" then value = value(purpose) end
    if tonumber(value) then return clamp(value, low, high) end
    return rawRandom(low, high, purpose)
  end

  local function normalizeReward(row)
    if type(row) ~= "table" or type(row.item) ~= "string"
        or row.item == "" then return nil end
    return {
      token = type(row.token) == "string" and row.token or nil,
      item = row.item,
      qty = clamp(row.qty or 1, 1, 99),
    }
  end

  local function normalizeFrequency(value)
    return W.FREQUENCY_PROFILES[value] and value or "normal"
  end

  local function savedOption(game, key)
    local bucket = game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket[key] ~= nil then return bucket[key] end
    if mod.options and type(mod.options.get) == "function" then
      return mod.options:get(key)
    end
  end

  function W.frequency(game, s)
    if game and not W.legacyRunEnabled(game) then return "never" end
    local selected = savedOption(game or W.game, "legacy_wanderer_frequency")
    if selected ~= nil then return normalizeFrequency(selected) end
    return normalizeFrequency(s and s.frequency)
  end

  function W.frequencyProfile(game, s)
    return W.FREQUENCY_PROFILES[W.frequency(game, s)]
  end

  local function state()
    local s = mod.save:get("legacy_wanderers")
    if type(s) ~= "table" then s = {} end
    local oldVersion = integer(s.version, 1)
    s.eligibleSteps = integer(s.eligibleSteps or s.validSteps)
    s.wins = integer(s.wins)
    s.losses = integer(s.losses)
    s.lossRelief = clamp(s.lossRelief, 0, W.MAX_LOSS_RELIEF)
    s.streak = integer(s.streak)
    s.marks = integer(s.marks)
    s.nextToken = math.max(1, integer(s.nextToken, 1))
    s.rotation = type(s.rotation) == "table" and s.rotation or {}
    for class, cursor in pairs(s.rotation) do
      if type(class) ~= "string" then
        s.rotation[class] = nil
      else
        s.rotation[class] = integer(cursor)
      end
    end
    s.rewardedTokens = type(s.rewardedTokens) == "table"
      and s.rewardedTokens or {}
    local pending = {}
    local seenPending = {}
    for _, row in ipairs(type(s.pendingRewards) == "table"
        and s.pendingRewards or {}) do
      row = normalizeReward(row)
      local key = row and (row.token or (row.item .. ":" .. row.qty))
      if row and not seenPending[key] then
        seenPending[key] = true
        pending[#pending + 1] = row
      end
    end
    s.pendingRewards = pending
    s.due = s.due == true
    s.frequency = normalizeFrequency(s.frequency)
    s.cadenceMode = s.cadenceMode == "encore" and "encore" or "normal"
    s.cycleSteps = integer(s.cycleSteps)
    s.mapChanges = integer(s.mapChanges)
    s.lastEligibleMap = type(s.lastEligibleMap) == "string"
      and s.lastEligibleMap or nil
    s.lastWinMap = type(s.lastWinMap) == "string" and s.lastWinMap or nil
    s.mapWinCount = clamp(s.mapWinCount or 0, 0,
      W.MAX_ENCOUNTERS_PER_MAP)
    s.forceMapChanges = s.forceMapChanges == true
    if oldVersion < 3 then
      -- Versions 1/2 predate the hybrid map cadence. They cannot preserve a
      -- map-transition target that did not exist, so migrate once to a fresh
      -- bounded normal cycle. Every version-3 field is exact thereafter.
      s.cadenceMode, s.cycleSteps, s.mapChanges = "normal", 0, 0
      s.targetMapChanges = rawRandom(W.MIN_MAP_CHANGES,
        W.MAX_MAP_CHANGES, "maps")
      s.lastEligibleMap, s.encoreMap, s.encoreStepTarget = nil, nil, nil
      s.forceMapChanges = false
    elseif s.cadenceMode == "encore" then
      s.encoreMap = W.isEligibleMap and W.isEligibleMap(s.encoreMap)
        and s.encoreMap or nil
      s.encoreStepTarget = clamp(s.encoreStepTarget,
        W.ENCORE_MIN_STEPS, W.ENCORE_MAX_STEPS)
      if not s.encoreMap then
        s.cadenceMode = "normal"
        s.targetMapChanges = W.MAX_MAP_CHANGES
        s.forceMapChanges = true
      end
    end
    local profile = W.FREQUENCY_PROFILES[s.frequency]
      or W.FREQUENCY_PROFILES.normal
    if oldVersion < 4 then
      -- Existing active NG+ saves migrate to NORMAL. The option value, when
      -- present, is reconciled by syncFrequency on the next real step.
      s.frequency = "normal"
      profile = W.FREQUENCY_PROFILES.normal
    end
    if oldVersion < 5 and type(s.encounter) == "table"
        and not (type(s.encounter.tier) == "table"
          and s.encounter.tier.scalingVersion == 2) then
      -- Version 4 persisted the old mirror-the-whole-party +15-20% roster.
      -- Never make an existing player fight that obsolete over-tuned team
      -- after updating: keep the encounter due, but rebuild it once with the
      -- fair v2 contract and a new exact token.
      s.encounter = nil
      s.due = true
    end
    if s.cadenceMode == "normal" then
      local minimum = s.forceMapChanges and 3 or (profile.minMaps or 2)
      local maximum = math.max(minimum, profile.maxMaps or 3)
      s.targetMapChanges = clamp(s.targetMapChanges, minimum, maximum)
      s.encoreMap, s.encoreStepTarget = nil, nil
    end
    if s.due then
      s.stepsRemaining = 0
    elseif s.cadenceMode == "encore" then
      s.stepsRemaining = math.max(0, s.encoreStepTarget - s.cycleSteps)
    else
      s.stepsRemaining = math.max(0,
        (profile.hardMaxSteps or W.HARD_MAX_STEPS) - s.cycleSteps)
    end
    if type(s.encounter) ~= "table" then s.encounter = nil end
    s.version = W.STATE_VERSION
    -- Drop obsolete probabilistic-cadence fields after the one-way migration.
    s.validSteps, s.sinceCheck, s.cooldown = nil, nil, nil
    mod.save:set("legacy_wanderers", s)
    return s
  end

  local function persist(s)
    if s then mod.save:set("legacy_wanderers", s) end
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function randomIndex(maximum)
    if maximum <= 1 then return 1 end
    return rawRandom(1, maximum, "index")
  end

  local function currentRewardController()
    local controller = rewardController
    if type(controller) == "function" then
      local ok, resolved = pcall(controller)
      controller = ok and resolved or nil
    end
    return type(controller) == "table" and controller or nil
  end

  function W.setRewardController(controller)
    rewardController = controller
    return currentRewardController() ~= nil
  end

  function W.setRecruitmentProvider(provider)
    recruitmentProvider = provider
    return provider ~= nil
  end

  function W.setMasteryProvider(provider)
    masteryProvider = provider
    return provider ~= nil
  end

  function W.setClockProvider(provider)
    clockProvider = provider
    return provider ~= nil
  end

  function W.setBeyondKantoBoundary(boundary)
    assert(boundary == nil or type(boundary) == "table",
      "Beyond-Kanto boundary must be a table")
    beyondKanto = boundary
    return beyondKanto ~= nil
  end

  local function currentProvider(provider)
    if type(provider) ~= "function" then return provider end
    local ok, resolved = pcall(provider)
    return ok and resolved or nil
  end

  function W.isEligibleMap(mapId)
    return OUTDOOR_MAPS[mapId] == true
  end

  function W.isLargeOutdoorMap(game, mapId)
    if not W.isEligibleMap(mapId) then return false end
    local def = game and game.data and game.data.maps
      and game.data.maps[mapId]
    local width, height = tonumber(def and def.width), tonumber(def and def.height)
    if width and height then return width * height >= W.LARGE_MAP_AREA end
    -- Vanilla block dimensions: these four towns and Route 7 are the only
    -- whitelisted 90-block surfaces; every other Kanto outdoor map is >=180.
    return mapId ~= "PALLET_TOWN" and mapId ~= "LAVENDER_TOWN"
      and mapId ~= "CINNABAR_ISLAND" and mapId ~= "INDIGO_PLATEAU"
      and mapId ~= "ROUTE_7"
  end

  function W.scheduleNext(s, config)
    s = s or state()
    config = type(config) == "table" and config
      or { targetMapChanges = config }
    local frequency = normalizeFrequency(config.frequency or s.frequency)
    local profile = W.FREQUENCY_PROFILES[frequency]
    s.frequency = frequency
    s.due = false
    s.cadenceMode = "normal"
    s.cycleSteps, s.mapChanges = 0, 0
    s.forceMapChanges = config.forceMapChanges == true
    local minimum = s.forceMapChanges and 3 or (profile.minMaps or 2)
    local maximum = math.max(minimum, profile.maxMaps or 3)
    s.targetMapChanges = clamp(config.targetMapChanges or rawRandom(
      profile.minMaps or 2, profile.maxMaps or 3, "maps"),
      minimum, maximum)
    s.lastEligibleMap = W.isEligibleMap(config.startMap)
      and config.startMap or nil
    s.encoreMap, s.encoreStepTarget = nil, nil
    s.stepsRemaining = profile.hardMaxSteps or 0
    return s.targetMapChanges
  end

  function W.scheduleEncore(s, mapId, stepTarget)
    if not W.isEligibleMap(mapId) then return false end
    s = s or state()
    s.due = false
    s.cadenceMode = "encore"
    s.cycleSteps, s.mapChanges = 0, 0
    s.forceMapChanges = false
    s.lastEligibleMap, s.encoreMap = mapId, mapId
    s.encoreStepTarget = clamp(stepTarget or rawRandom(
      W.ENCORE_MIN_STEPS, W.ENCORE_MAX_STEPS, "encore_steps"),
      W.ENCORE_MIN_STEPS, W.ENCORE_MAX_STEPS)
    s.stepsRemaining = s.encoreStepTarget
    return s.encoreStepTarget
  end

  local function advanceNormalCadence(s, mapId)
    local profile = W.FREQUENCY_PROFILES[s.frequency]
      or W.FREQUENCY_PROFILES.normal
    if profile.disabled then return false end
    s.cycleSteps = integer(s.cycleSteps) + 1
    if not s.lastEligibleMap then
      s.lastEligibleMap = mapId
    elseif mapId ~= s.lastEligibleMap then
      s.mapChanges = integer(s.mapChanges) + 1
      s.lastEligibleMap = mapId
    end
    s.stepsRemaining = math.max(0,
      profile.hardMaxSteps - s.cycleSteps)
    local minimumMet = s.cycleSteps >= profile.minSteps
    local targetMet = s.mapChanges >= s.targetMapChanges
    local hardCap = not s.forceMapChanges
      and (s.cycleSteps >= profile.hardMaxSteps
        or (minimumMet and s.mapChanges >= profile.hardMaxMaps))
    if minimumMet and targetMet or hardCap then
      s.due, s.stepsRemaining = true, 0
    end
    return s.due
  end

  function W.advanceCadence(s, mapId)
    if not W.isEligibleMap(mapId) then return false end
    local profile = W.FREQUENCY_PROFILES[s.frequency]
      or W.FREQUENCY_PROFILES.normal
    if profile.disabled then return false end
    s.eligibleSteps = integer(s.eligibleSteps) + 1
    if s.due then return true end
    if s.cadenceMode == "encore" then
      if mapId ~= s.encoreMap then
        -- Leaving through an interior and returning to the same outdoor map
        -- never reaches this branch: ineligible maps do not replace the last
        -- outdoor id. A genuinely different outdoor map cancels the encore.
        W.scheduleNext(s, {
          targetMapChanges = 3,
          startMap = s.encoreMap,
          forceMapChanges = true,
        })
        return advanceNormalCadence(s, mapId)
      end
      s.cycleSteps = integer(s.cycleSteps) + 1
      s.stepsRemaining = math.max(0, s.encoreStepTarget - s.cycleSteps)
      if s.cycleSteps >= s.encoreStepTarget then
        s.due, s.stepsRemaining = true, 0
      end
      return s.due
    end
    if not tonumber(s.targetMapChanges) then W.scheduleNext(s) end
    return advanceNormalCadence(s, mapId)
  end

  function W.syncFrequency(game, s)
    s = s or state()
    local selected = W.frequency(game, s)
    if selected == s.frequency then return selected, false end
    s.frequency = selected
    if selected ~= "never" and not s.due and not s.encounter then
      W.scheduleNext(s, { frequency = selected,
        startMap = s.lastEligibleMap })
    end
    persist(s)
    return selected, true
  end

  local function safeCell(ow, x, y, allowPlayer)
    local map = ow and ow.map
    if not (map and map:inBounds(x, y) and map:isWalkableCell(x, y)) then
      return false
    end
    if map.warpAtCell and map:warpAtCell(x, y) then return false end
    if map.signAtCell and map:signAtCell(x, y) then return false end
    if map.isWarpTileCell and map:isWarpTileCell(x, y) then return false end
    if ow.npcAtCell and ow:npcAtCell(x, y) then return false end
    if not allowPlayer and ow.player
        and ow.player.cellX == x and ow.player.cellY == y then return false end
    return true
  end

  local DIRS = {
    { 0, -1, "up" }, { 0, 1, "down" },
    { -1, 0, "left" }, { 1, 0, "right" },
  }

  local function key(x, y) return tostring(x) .. ":" .. tostring(y) end

  function W.findApproach(ow)
    if not (ow and ow.player and ow.map) then return nil end
    local px, py = ow.player.cellX, ow.player.cellY
    local queue, head, seen = {}, 1, {}
    for _, d in ipairs(DIRS) do
      local x, y = px + d[1], py + d[2]
      if safeCell(ow, x, y) then
        local row = { x = x, y = y, path = {} }
        queue[#queue + 1] = row
        seen[key(x, y)] = true
      end
    end
    local candidates = {}
    while head <= #queue do
      local row = queue[head]; head = head + 1
      local steps = #row.path
      local manhattan = math.abs(row.x - px) + math.abs(row.y - py)
      if steps >= 2 and steps <= 4 and manhattan >= 4 and manhattan <= 8 then
        candidates[#candidates + 1] = row
      end
      if steps < 4 then
        for _, d in ipairs(DIRS) do
          local nx, ny = row.x + d[1], row.y + d[2]
          local id = key(nx, ny)
          if not seen[id] and safeCell(ow, nx, ny) then
            seen[id] = true
            local path = copy(row.path)
            table.insert(path, 1, d[3] == "up" and "down"
              or d[3] == "down" and "up"
              or d[3] == "left" and "right" or "left")
            queue[#queue + 1] = { x = nx, y = ny, path = path }
          end
        end
      end
    end
    if #candidates == 0 then return nil end
    return candidates[randomIndex(#candidates)]
  end

  local function averageLevel(party)
    local total = 0
    for _, mon in ipairs(party or {}) do total = total + integer(mon.level, 1) end
    return #party > 0 and total / #party or 1
  end

  function W.progressTier(game)
    local Badges = require("src.inventory.Badges")
    local badges = Badges.count(game.data, game.save)
    local legacy = journey.state(game.save) or {}
    local cycle = math.max(1, integer(legacy.cycle, 1))
    local pact = legacy.pact or "journey"
    local pactBonus = pact == "ascendant" and 5
      or pact == "legacy" and 3 or pact == "trainer" and 1 or 0
    return {
      badges = badges, cycle = cycle, pact = pact,
      targetLevel = math.min(90, 8 + badges * 6 + (cycle - 1) * 2 + pactBonus),
      teamSize = math.min(5, 2 + math.floor(badges / 3)),
    }
  end

  function W.chooseTeam(game, archetype)
    local trainer = game.data.trainers[archetype.class]
    if not (trainer and type(trainer.parties) == "table") then return nil end
    local tier = W.progressTier(game)
    local bestIndex, bestParty, bestDistance
    for index, party in ipairs(trainer.parties) do
      local allowed = {}
      for _, slot in ipairs(type(party) == "table" and party or {}) do
        if type(slot) == "table" and speciesAllowed(game, slot.species) then
          allowed[#allowed + 1] = slot
        end
      end
      if #allowed > 0 then
        local distance = math.abs(averageLevel(allowed) - tier.targetLevel)
        if not bestDistance or distance < bestDistance then
          bestIndex, bestParty, bestDistance = index, allowed, distance
        end
      end
    end
    if not bestParty then return nil end
    local delta = tier.targetLevel - averageLevel(bestParty)
    local team = {}
    for index, slot in ipairs(bestParty) do
      if index > tier.teamSize then break end
      local row = copy(slot)
      row.level = math.max(2, math.min(100,
        math.floor((tonumber(row.level) or tier.targetLevel) + delta + 0.5)))
      team[#team + 1] = row
    end
    return bestIndex, team, tier
  end

  local EXACT_FIELD_SPRITE = {
    OPP_YOUNGSTER = true, OPP_SAILOR = true,
    OPP_JR_TRAINER_M = true, OPP_JR_TRAINER_F = true,
    OPP_POKEMANIAC = true, OPP_SUPER_NERD = true,
    OPP_HIKER = true, OPP_BIKER = true, OPP_FISHER = true,
    OPP_SWIMMER = true, OPP_GAMBLER = true, OPP_BEAUTY = true,
    OPP_ROCKER = true, OPP_SCIENTIST = true,
    OPP_COOLTRAINER_M = true, OPP_COOLTRAINER_F = true,
    OPP_GENTLEMAN = true, OPP_CHANNELER = true,
  }

  function W.isStoryTrainer(class, trainer)
    if type(class) ~= "string" or STORY_CLASSES[class] then return true end
    -- Base ordinary classes use OPP_.  KA_ classes are authored feature
    -- encounters and therefore fail closed unless deliberately admitted by
    -- a future schema instead of silently recycling a finale as a wanderer.
    if class:find("^KA_") then return true end
    if class:find("^OPP_UNUSED") or class:find("RIVAL", 1, true)
        or class:find("ROCKET", 1, true) then return true end
    for _, marker in ipairs({ "_BOSS", "_MASTER", "_LEADER",
      "_CHAMPION", "_ADMIN", "_EXECUTIVE", "_GRUNT", "_PROF",
      "_TEST", "_DEBUG", "_DUMMY", "_PLACEHOLDER" }) do
      if class:find(marker, 1, true) then return true end
    end
    if type(trainer) ~= "table" then return true end
    return trainer.story == true or trainer.boss == true
      or trainer.technical == true or trainer.unused == true
      or trainer.wandererExcluded == true
      or trainer.randomPoolExcluded == true
  end

  local function safePartyIndex(class, index)
    -- This ordinary class has one exceptional authored party: index 1 is
    -- the Karate Master whose victory is a story gate.  Other Blackbelts
    -- remain valid wandering challengers.
    return not (class == "OPP_BLACKBELT" and index == 1)
  end

  local function partyUsable(game, party)
    if type(party) ~= "table" or #party == 0 then return false end
    local pokemon = game and game.data and game.data.pokemon or {}
    for _, slot in ipairs(party) do
      if type(slot) == "table" and type(slot.species) == "string"
          and pokemon[slot.species] and tonumber(slot.level)
          and speciesAllowed(game, slot.species) then
        return true
      end
    end
    return false
  end

  local function partyIndexes(game, class, trainer)
    local indexes = {}
    for index, party in ipairs(trainer and trainer.parties or {}) do
      if safePartyIndex(class, index) and partyUsable(game, party) then
        indexes[#indexes + 1] = index
      end
    end
    return indexes
  end

  function W.fieldSprite(game, class)
    local sprites = game and game.data and game.data.sprites or {}
    local requested = W.FIELD_SPRITES[class]
    if requested and sprites[requested] then
      return requested, EXACT_FIELD_SPRITE[class] == true
    end
    for _, fallback in ipairs({ "SPRITE_COOLTRAINER_M",
      "SPRITE_YOUNGSTER", "SPRITE_RED" }) do
      if sprites[fallback] then return fallback, false end
    end
    local ids = {}
    for id in pairs(sprites) do ids[#ids + 1] = id end
    table.sort(ids)
    return ids[1], false
  end

  function W.liveTrainerPool(game)
    local pool = {}
    local trainers = game and game.data and game.data.trainers or {}
    local classes = {}
    local override = W.ARCHETYPES ~= DEFAULT_ARCHETYPES
    if override then
      for _, row in ipairs(W.ARCHETYPES or {}) do
        if type(row) == "table" and trainers[row.class] then
          classes[#classes + 1] = row.class
        end
      end
    else
      for class in pairs(trainers) do classes[#classes + 1] = class end
    end
    table.sort(classes)
    for _, class in ipairs(classes) do
      local trainer = trainers[class]
      if not W.isStoryTrainer(class, trainer) then
        local indexes = partyIndexes(game, class, trainer)
        local sprite, exact = W.fieldSprite(game, class)
        if override then
          for _, row in ipairs(W.ARCHETYPES) do
            if row.class == class and game.data.sprites[row.sprite] then
              sprite, exact = row.sprite, true
              break
            end
          end
        end
        if #indexes > 0 and sprite then
          pool[#pool + 1] = {
            class = class, sprite = sprite, fieldSpriteExact = exact,
            fieldSpriteFallback = not exact, partyIndexes = indexes,
          }
        end
      end
    end
    return pool
  end

  function W.viableParty(game)
    local viable = {}
    local pokemon = game and game.data and game.data.pokemon or nil
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      local species = type(mon) == "table" and mon.species or nil
      local level = type(mon) == "table" and tonumber(mon.level) or nil
      local hp = type(mon) == "table" and tonumber(mon.hp) or nil
      -- Only monsters that can actually enter the battle form the baseline.
      -- Boxed monsters never reach this list, and a fainted high-level reserve
      -- can no longer make the surprise fight much harder than the usable
      -- party. Older synthetic fixtures without an hp field remain usable.
      if species and level and level >= 1 and mon.isEgg ~= true
          and (hp == nil or hp > 0)
          and (not pokemon or pokemon[species])
          and speciesAllowed(game, species) then
        viable[#viable + 1] = mon
      end
    end
    return viable
  end

  local function strongestMedian(viable)
    local levels = {}
    for _, mon in ipairs(viable or {}) do
      levels[#levels + 1] = clamp(mon.level, 1, 100)
    end
    table.sort(levels, function(a, b) return a > b end)
    while #levels > 3 do table.remove(levels) end
    if #levels == 1 then return levels[1]
    elseif #levels == 2 then
      return math.floor((levels[1] + levels[2]) / 2 + 0.5)
    end
    return levels[2]
  end

  function W.challengeTier(game, bonus, s)
    local viable = W.viableParty(game)
    if #viable == 0 then return nil end
    s = s or state()
    bonus = clamp(bonus or rawRandom(W.MIN_LEVEL_BONUS,
      W.MAX_LEVEL_BONUS, "challenge_level_bonus"),
      W.MIN_LEVEL_BONUS, W.MAX_LEVEL_BONUS)
    local relief = clamp(s.lossRelief, 0, W.MAX_LOSS_RELIEF)
    local effectiveBonus = math.max(0, bonus - relief)
    local baseline = strongestMedian(viable)
    local teamSize = math.min(#viable, W.MAX_BATTLE_TEAM)
    local teamReduction = relief >= W.LOSS_TEAM_REDUCTION_AT
      and teamSize > 1 and 1 or 0
    teamSize = teamSize - teamReduction
    local target = math.min(100, baseline + effectiveBonus)
    local targetLevels = {}
    for index = 1, teamSize do targetLevels[index] = target end
    return {
      scalingVersion = 2,
      baseLevelBonus = bonus,
      effectiveLevelBonus = effectiveBonus,
      lossRelief = relief,
      aiLayers = math.max(0, 3 - relief),
      teamReduction = teamReduction,
      teamSize = teamSize,
      playerAverage = baseline,
      baselineLevel = baseline,
      targetAverage = target,
      targetLevel = target,
      targetLevels = targetLevels,
    }
  end

  local function cleanSourceParty(game, party)
    local out = {}
    local pokemon = game.data and game.data.pokemon or {}
    local moves = game.data and game.data.moves or {}
    for _, slot in ipairs(party or {}) do
      if type(slot) == "table" and pokemon[slot.species]
          and speciesAllowed(game, slot.species) then
        local row = copy(slot)
        if type(row.moves) == "table" then
          local valid = {}
          for _, move in ipairs(row.moves) do
            if moves[move] then valid[#valid + 1] = move end
          end
          row.moves = #valid > 0 and valid or nil
        end
        out[#out + 1] = row
      end
    end
    return out
  end

  function W.growthProgress(game, s, tier)
    s = s or state()
    local Badges = require("src.inventory.Badges")
    local badges = Badges.count(game.data, game.save)
    local legacy = journey.state(game.save) or {}
    local cycle = math.max(1, integer(legacy.cycle, 1))
    local clock = currentProvider(clockProvider)
    if type(clock) == "function" then
      local ok, value = pcall(clock)
      clock = ok and value or 0
    end
    clock = integer(clock)
    local progress = integer(s.wins) + math.max(0, cycle - 1) * 2
      + math.floor(badges / 2) + math.min(8, math.floor(clock / 1800))
    local perfect = tier and tier.targetLevel == 100 and progress >= 10
      and (cycle >= 3 or integer(s.wins) >= 10)
    return {
      progress = progress, badges = badges, cycle = cycle, clock = clock,
      perfect = perfect,
    }
  end

  -- Wanderer-only roster construction.  The authored Legacy path module
  -- continues to call progressTier above, so its fixed fights cannot drift
  -- when this live-party challenger changes.
  function W.teamFor(game, archetype, s, bonus, advance)
    local trainer = game and game.data and game.data.trainers
      and game.data.trainers[archetype and archetype.class]
    if not trainer then return nil end
    local indexes = type(archetype.partyIndexes) == "table"
      and archetype.partyIndexes
      or partyIndexes(game, archetype.class, trainer)
    if #indexes == 0 then return nil end
    s = s or state()
    s.rotation = type(s.rotation) == "table" and s.rotation or {}
    local cursor = integer(s.rotation[archetype.class])
    local position = cursor % #indexes + 1
    local partyIndex = indexes[position]
    local source = cleanSourceParty(game, trainer.parties[partyIndex])
    local tier = W.challengeTier(game, bonus, s)
    if #source == 0 or not tier then return nil end
    local growth = W.growthProgress(game, s, tier)
    local recruitment = currentProvider(recruitmentProvider)
    if recruitment and type(recruitment.expand) == "function" then
      s.recruitment = type(s.recruitment) == "table" and s.recruitment or {}
      local progressState = type(s.recruitment[archetype.class]) == "table"
        and s.recruitment[archetype.class] or {}
      s.recruitment[archetype.class] = progressState
      local boost = math.max(0,
        math.floor(tier.targetLevel - averageLevel(source) + 0.5))
      local expanded, generation = recruitment.expand(game.data, source,
        archetype.class, "legacy-wanderer:" .. archetype.class,
        growth.progress, boost, true, {
          selections = progressState.recruitFamilies,
          recentHistory = progressState.recruitHistory,
          originalStages = progressState.originalStages,
          originalBranches = progressState.originalBranches,
          rematchNumber = growth.progress + 1,
          random = function(lo, hi)
            return rawRandom(lo, hi, "recruitment")
          end,
          deferCommit = true,
        })
      if type(expanded) == "table" and #expanded > 0 then
        local allowed = cleanSourceParty(game, expanded)
        if #allowed > 0 then source = allowed end
      end
      if advance ~= false and generation
          and type(recruitment.commit) == "function" then
        recruitment.commit(progressState, generation, true)
      end
    end
    local team = {}
    for index = 1, tier.teamSize do
      local sourceIndex = (index + cursor - 1) % #source + 1
      local row = copy(source[sourceIndex])
      row.level = tier.targetLevels[index]
      team[#team + 1] = row
    end
    if advance ~= false then s.rotation[archetype.class] = cursor + 1 end
    tier.rotation = cursor
    tier.sourceParty = partyIndex
    tier.growthProgress = growth.progress
    tier.legacyCycle = growth.cycle
    tier.legacyWins = integer(s.wins)
    tier.trainerClock = growth.clock
    -- At level 100 a level reduction alone cannot make the retry easier.
    -- Any active relief therefore also suspends the perfect mastery layer;
    -- the next win removes one relief step and restores pressure gradually.
    tier.perfectMastery = growth.perfect and tier.lossRelief == 0
    tier.pact = (journey.state(game.save) or {}).pact or "journey"
    return partyIndex, team, tier
  end

  function W.setTitleProvider(provider)
    titleProvider = type(provider) == "table" and provider or nil
    return titleProvider ~= nil
  end

  local function teamHasSpecies(team, species)
    if type(species) ~= "string" then return false end
    for _, row in ipairs(team or {}) do
      if row.species == species then return true end
    end
    return false
  end

  local function selectedTitle()
    if not (titleProvider and type(titleProvider.currentTitle) == "function") then
      return nil
    end
    local ok, id, name = pcall(titleProvider.currentTitle)
    if not ok or type(id) ~= "string" then return nil end
    return id, name
  end

  -- A small authored set, deliberately scoped to the wandering challenger
  -- whose class has a reason to recognize the achievement. Unknown titles
  -- and ordinary NPCs keep the neutral road greeting.
  function W.reactionContext(active)
    active = active or W.active or {}
    local game = active.game or W.game
    local archetype = active.archetype or {}
    local class = archetype.class
    local titleId, titleName = selectedTitle()
    local ace = class == "OPP_COOLTRAINER_M"
      or class == "OPP_COOLTRAINER_F"
      or class == "OPP_JR_TRAINER_M"
      or class == "OPP_JR_TRAINER_F"

    if titleId == "factory_architect" and class == "OPP_SCIENTIST" then
      return { kind = "title_factory", titleId = titleId, titleName = titleName }
    elseif titleId == "legacy_path_red" and ace then
      return { kind = "title_red", titleId = titleId, titleName = titleName }
    elseif titleId == "legacy_path_blue" and class == "OPP_SCIENTIST" then
      return { kind = "title_blue", titleId = titleId, titleName = titleName }
    elseif titleId == "legacy_path_green" and class == "OPP_POKEMANIAC" then
      return { kind = "title_green", titleId = titleId, titleName = titleName }
    elseif titleId == "legacy_pass" then
      return { kind = "title_pass", titleId = titleId, titleName = titleName }
    end

    local legacy = game and journey.state(game.save) or nil
    local partner = type(legacy) == "table" and legacy.partnerChosen == true
      and type(legacy.partnerSpecies) == "string" and legacy.partnerSpecies
      or nil
    if partner and teamHasSpecies(active.team, partner) then
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[partner]
      return {
        kind = "partner_match", partner = partner,
        partnerName = def and def.name or partner,
      }
    end

    local variant = archetype.legacyVariant
    if variant == "red_challenge" then
      return { kind = "path_red" }
    elseif variant == "oak_researcher" then
      return { kind = "path_blue" }
    elseif variant == "wild_keeper" then
      return { kind = "path_green" }
    elseif variant == "legacy_keeper" then
      return { kind = "path_complete" }
    end
    return { kind = "fallback" }
  end

  function W.challengeText(active)
    local context = W.reactionContext(active)
    local kind = context.kind
    if kind == "title_factory" then
      return tr(
        "SCIENTIST:\nBATTLE FACTORY ACE!\fNow show me the team\nyou built yourself.",
        "FORSCHER:\nFABRIK-ARCHITEKT!\fJetzt zeig mir dein\neigenes Team.")
    elseif kind == "title_red" then
      return tr(
        "ACE TRAINER:\nKANTO CHALLENGER!\fDefend that title\nin battle.",
        "ASS-TRAINER:\nKANTO-KÄMPFER!\fVerteidige deinen\nTitel im Kampf.")
    elseif kind == "title_blue" then
      return tr(
        "SCIENTIST:\nOAK'S HEIR!\fRead my opening\nmove if you can.",
        "FORSCHER:\nEICHS ERBE!\fLies meinen ersten\nZug voraus.")
    elseif kind == "title_green" then
      return tr(
        "KEEPER:\nTHE GREEN SEAL!\fShow the strength\nof your bond.",
        "HÜTERIN:\nDAS GRÜNE SIEGEL!\fZeig die Stärke\neurer Bindung.")
    elseif kind == "title_pass" then
      return tr(
        "VETERAN:\nTHREE SEALS!\fShow what the journey\nmade of you.",
        "VETERAN:\nDREI SIEGEL!\fZeig, was die Reise\naus dir gemacht hat.")
    elseif kind == "partner_match" then
      return tr(
        "WANDERER:\nI know that bond.\fLet our partners\ntest each other!",
        "WANDERTRAINER:\nIch sehe euren Bund.\fUnsere Partner\ntreten gegeneinander an!")
    elseif kind == "path_red" then
      return tr(
        "WANDERER:\nGROUDON'S TRIAL!\fThis time only the\nbattle decides.",
        "WANDERTRAINER:\nGROUDONS PRÜFUNG!\fDiesmal entscheidet\nnur der Kampf.")
    elseif kind == "path_blue" then
      return tr(
        "SCIENTIST:\nKYOGRE'S TRIAL!\fNow prove your\nbattle plan.",
        "FORSCHER:\nKYOGRES PRÜFUNG!\fBeweise jetzt deinen\nKampfplan.")
    elseif kind == "path_green" then
      return tr(
        "KEEPER:\nRAYQUAZA'S TRIAL!\fShow the bond that\nopened your path.",
        "HÜTERIN:\nRAYQUAZAS PRÜFUNG!\fZeig den Bund, der\ndeinen Pfad öffnete.")
    elseif kind == "path_complete" then
      return tr(
        "VETERAN:\nTHREE PATHS!\fOne honest battle\nremains.",
        "VETERAN:\nDREI PFADE!\fEin ehrlicher Kampf\nbleibt.")
    end
    return tr(
      "WANDERER:\nI sought you out.\fShow me what this\njourney taught you!",
      "WANDERTRAINER:\nIch suchte dich.\fZeig, was du auf der\nReise gelernt hast!")
  end

  function W.availableArchetypes(game)
    local available = {}
    for _, archetype in ipairs(W.ARCHETYPES) do
      if game.data.trainers[archetype.class] then
        available[#available + 1] = archetype
      end
    end
    local legacyProfile = journey.profile and journey.profile() or {}
    local completed = legacyProfile.completedPaths or {}
    if completed.red and game.data.trainers.OPP_COOLTRAINER_M then
      available[#available + 1] = {
        class = "OPP_COOLTRAINER_M", sprite = "SPRITE_COOLTRAINER_M",
        legacyVariant = "red_challenge",
      }
    end
    if completed.blue and game.data.trainers.OPP_SCIENTIST then
      available[#available + 1] = {
        class = "OPP_SCIENTIST", sprite = "SPRITE_SCIENTIST",
        legacyVariant = "oak_researcher",
      }
    end
    if completed.green and game.data.trainers.OPP_POKEMANIAC then
      available[#available + 1] = {
        class = "OPP_POKEMANIAC", sprite = "SPRITE_SUPER_NERD",
        legacyVariant = "wild_keeper",
      }
    end
    if legacyProfile.legacyPass and game.data.trainers.OPP_COOLTRAINER_F then
      available[#available + 1] = {
        class = "OPP_COOLTRAINER_F", sprite = "SPRITE_COOLTRAINER_F",
        legacyVariant = "legacy_keeper",
      }
    end
    return available
  end

  local function contextSafe(game)
    local ow = game and game.overworld
    if not (ow and ow.map and ow.player and game.stack
        and game.stack:top() == ow) then return false end
    if ow.engaging or ow.emote or ow.transitioning or ow.teleportOut then
      return false
    end
    if ow.player.moving or ow.player.inputLocked or ow.player.surfing
        or ow.player.spinning then return false end
    if #(ow.scriptMoves or {}) > 0 then return false end
    if ow.runner and ow.runner.isRunning and ow.runner:isRunning() then
      return false
    end
    return true
  end

  local function itemIsBall(game, id, def)
    if not def then return false end
    local data = game and game.data or {}
    if (type(def.ball) == "string" and (def.ball == id
        or data.balls and data.balls[def.ball]))
        or (data.balls and data.balls[id]) then return true end
    for _, apricorn in ipairs(APRICORN_BALLS) do
      if id == apricorn then return true end
    end
    local ok, effects = pcall(require, "src.inventory.ItemEffects")
    return ok and effects and type(effects.isBall) == "function"
      and effects.isBall(id) == true or false
  end

  function W.registeredBallIds(game)
    local ids = {}
    local kantoBalls = {
      POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true,
      MASTER_BALL = true, SAFARI_BALL = true,
    }
    for id, def in pairs(game and game.data and game.data.items or {}) do
      if itemIsBall(game, id, def)
          and (beyondActive(game) or kantoBalls[id] == true) then
        ids[#ids + 1] = id
      end
    end
    table.sort(ids)
    return ids
  end

  local function speciesLearnsMachine(game, move)
    for _, def in pairs(game and game.data and game.data.pokemon or {}) do
      for _, compatible in ipairs(def.tmhm or {}) do
        if compatible == move then return true end
      end
    end
    return false
  end

  local TM_MOVE_ALIASES = {
    DYNAMICPUNCH = "DYNAMIC_PUNCH",
    DRAGON_BREATH = "DRAGONBREATH",
    THUNDER_PUNCH = "THUNDERPUNCH",
  }

  function W.machineGeneration(def, machine, moveDef)
    local explicit = tonumber(machine and machine.generation)
      or tonumber(def and (def.generation or def.sourceGeneration))
      or tonumber(moveDef and (moveDef.generation
        or moveDef.sourceGeneration))
    if explicit then
      explicit = math.floor(explicit)
      return (explicit == 2 or explicit == 3) and explicit or nil
    end
    local move = machine and machine.move
    local canonical = TM_MOVE_ALIASES[move] or move
    local number = tonumber(machine and machine.number)
    if HOENN_SIGNATURE_TMS[move] and number and number >= 51 then return 3 end
    if number and GEN2_TM_BY_NUMBER[number] == canonical then return 2 end
    if number and GEN3_TM_BY_NUMBER[number] == canonical then return 3 end
    return nil
  end

  local function moveEffective(moveDef)
    if type(moveDef) ~= "table" then return false end
    if moveDef.placeholder == true or moveDef.unsupported == true
        or moveDef.mechanicsBlocked == true or moveDef.disabled == true
        or moveDef.noOp == true or moveDef.implemented == false then
      return false
    end
    return moveDef.effect ~= "UNIMPLEMENTED_EFFECT"
      and moveDef.effect ~= "NO_OP_EFFECT"
  end

  function W.registeredTMs(game)
    local rows = {}
    if not beyondActive(game) then return rows end
    local data = game and game.data or {}
    for id, def in pairs(data.items or {}) do
      local machine = type(def) == "table" and def.machine or nil
      local move = machine and machine.move
      local moveDef = data.moves and data.moves[move]
      local generation = W.machineGeneration(def, machine, moveDef)
      if machine and machine.kind == "TM" and type(move) == "string"
          and moveEffective(moveDef) and generation
          and speciesLearnsMachine(game, move) then
        rows[#rows + 1] = {
          item = id, move = move,
          number = tonumber(machine.number) or 999,
          generation = generation,
        }
      end
    end
    table.sort(rows, function(a, b)
      if a.number == b.number then return a.item < b.item end
      return a.number < b.number
    end)
    return rows
  end

  local function contains(list, value)
    for _, candidate in ipairs(list) do
      if candidate == value then return true end
    end
    return false
  end

  local BALL_STACKS = {
    POKE_BALL = {
      { qty = 3, weight = 6 }, { qty = 5, weight = 4 },
      { qty = 8, weight = 2 },
    },
    GREAT_BALL = {
      { qty = 2, weight = 6 }, { qty = 3, weight = 4 },
      { qty = 5, weight = 2 },
    },
    ULTRA_BALL = {
      { qty = 1, weight = 5 }, { qty = 2, weight = 3 },
      { qty = 3, weight = 1 },
    },
  }

  local function addBallRows(pool, id)
    local apricorn = contains(APRICORN_BALLS, id)
    local rows = BALL_STACKS[id]
    if apricorn then
      rows = { { qty = 1, weight = 4 }, { qty = 2, weight = 1 } }
    elseif not rows then
      rows = { { qty = 1, weight = id == "SAFARI_BALL" and 1 or 2 } }
    end
    for _, spec in ipairs(rows) do
      pool[#pool + 1] = {
        item = id, qty = spec.qty, kind = "ball",
        apricorn = apricorn, weight = spec.weight,
      }
    end
  end

  -- The ordinary pool is deliberately owned by this feature.  It does not
  -- call rematch_loot and therefore cannot inherit that module's exclusions
  -- or progression flags.  MASTER BALL is resolved in a separate rare roll.
  function W.rewardPool(game)
    local pool = {}
    for _, id in ipairs(W.registeredBallIds(game)) do
      if id ~= "MASTER_BALL" then addBallRows(pool, id) end
    end
    for _, machine in ipairs(W.registeredTMs(game)) do
      pool[#pool + 1] = {
        item = machine.item, qty = 1, kind = "tm",
        move = machine.move, generation = machine.generation, weight = 1,
      }
    end
    table.sort(pool, function(a, b)
      if a.kind == b.kind and a.item == b.item then return a.qty < b.qty end
      if a.kind == b.kind then return a.item < b.item end
      return a.kind < b.kind
    end)
    return pool
  end

  function W.rewardPoolTotal(game)
    local total = 0
    for _, row in ipairs(W.rewardPool(game)) do
      total = total + math.max(1, integer(row.weight, 1))
    end
    return total
  end

  function W.masterBallOdds(game)
    local def = game and game.data and game.data.items
      and game.data.items.MASTER_BALL
    if not itemIsBall(game, "MASTER_BALL", def) then return 0, 0 end
    local denominator = clamp(opts.masterBallDenominator
      or W.MASTER_BALL_DENOMINATOR, 2, 1000000)
    return 1, denominator
  end

  function W.catchupStatus(game)
    local controller = currentRewardController()
    if not (controller and type(controller.catchupStatus) == "function") then
      return { expShareMissing = false, multiplier2Missing = false }
    end
    local ok, status = pcall(controller.catchupStatus, game)
    if not ok or type(status) ~= "table" then
      return { expShareMissing = false, multiplier2Missing = false }
    end
    return {
      expShareMissing = status.expShareMissing == true,
      multiplier2Missing = status.multiplier2Missing == true,
      nextMultiplier = tonumber(status.nextMultiplier),
    }
  end

  function W.catchupOdds(kind)
    if kind == "expShare" then
      return 1, W.EXP_SHARE_CATCHUP_DENOMINATOR
    elseif kind == "multiplier2" then
      return 1, W.MULTIPLIER2_CATCHUP_DENOMINATOR
    elseif kind == "multiplier3" then
      return 1, W.MULTIPLIER3_CATCHUP_DENOMINATOR
    elseif kind == "multiplier5" then
      return 1, W.MULTIPLIER5_CATCHUP_DENOMINATOR
    end
    return 0, 0
  end

  function W.selectReward(game, masterRoll, poolRoll, catchupRolls)
    local hits, denominator = W.masterBallOdds(game)
    if hits > 0 then
      masterRoll = clamp(masterRoll or rawRandom(1, denominator, "master"),
        1, denominator)
      if masterRoll <= hits then
        return { item = "MASTER_BALL", qty = 1, kind = "master",
          rare = true, separate = true }
      end
    end
    catchupRolls = type(catchupRolls) == "table" and catchupRolls or {}
    local catchup = W.catchupStatus(game)
    if catchup.expShareMissing then
      local _, denom = W.catchupOdds("expShare")
      local roll = clamp(catchupRolls.expShare or rawRandom(
        1, denom, "catchup_exp_share"), 1, denom)
      if roll == 1 then
        return { item = "EXP_ALL", qty = 1, kind = "catchup",
          unlock = "expShare", separate = true }
      end
    end
    if catchup.multiplier2Missing then
      local _, denom = W.catchupOdds("multiplier2")
      local roll = clamp(catchupRolls.multiplier2 or rawRandom(
        1, denom, "catchup_multiplier2"), 1, denom)
      if roll == 1 then
        return { item = "ASCENDANT_EXP_MULTIPLIER", qty = 1,
          kind = "catchup", unlock = 2, separate = true }
      end
    end
    local nextStage = tonumber(catchup.nextMultiplier)
    if nextStage == 3 or nextStage == 5 then
      local key = "multiplier" .. tostring(nextStage)
      local _, denom = W.catchupOdds(key)
      local roll = clamp(catchupRolls[key] or rawRandom(
        1, denom, "catchup_" .. key), 1, denom)
      if roll == 1 then
        return { item = "ASCENDANT_EXP_MULTIPLIER", qty = 1,
          kind = "catchup", unlock = nextStage, separate = true,
          stateOnly = true }
      end
    end
    local pool = W.rewardPool(game)
    local total = 0
    for _, row in ipairs(pool) do total = total + integer(row.weight, 1) end
    if total <= 0 then return nil end
    poolRoll = clamp(poolRoll or rawRandom(1, total, "reward"), 1, total)
    local cursor = 0
    for _, row in ipairs(pool) do
      cursor = cursor + integer(row.weight, 1)
      if poolRoll <= cursor then return copy(row) end
    end
    return copy(pool[#pool])
  end

  local function pcAdd(game, item, qty)
    local save = game.save
    save.pcItems = type(save.pcItems) == "table" and save.pcItems or {}
    local current = integer(save.pcItems[item])
    if current + qty > 99 then return false end
    if current == 0 then
      local stacks = 0
      for _ in pairs(save.pcItems) do stacks = stacks + 1 end
      local field = game.data and game.data.field or {}
      local capacity = clamp(field.pcItemCap or 50, 1, 10000)
      if stacks >= capacity then return false end
      save.pcOrder = type(save.pcOrder) == "table" and save.pcOrder or {}
      save.pcOrder[#save.pcOrder + 1] = item
    end
    save.pcItems[item] = current + qty
    return true
  end

  local function placeNow(game, reward)
    if not (game and game.save and game.data and reward
        and game.data.items and game.data.items[reward.item]) then
      return nil, "unregistered"
    end
    local qty = clamp(reward.qty or 1, 1, 99)
    game.save.inventory = type(game.save.inventory) == "table"
      and game.save.inventory or {}
    game.save.bagOrder = type(game.save.bagOrder) == "table"
      and game.save.bagOrder or {}
    local ok, Bag = pcall(require, "src.inventory.Bag")
    if ok and Bag and type(Bag.add) == "function"
        and Bag.add(game.save, reward.item, qty, game.data) then
      return "bag"
    end
    if pcAdd(game, reward.item, qty) then return "pc" end
    return nil, "full"
  end

  local function reservePending(s, reward, token)
    for _, row in ipairs(s.pendingRewards) do
      if token and row.token == token then return row, false end
    end
    local row = {
      token = token, item = reward.item,
      qty = clamp(reward.qty or 1, 1, 99),
    }
    s.pendingRewards[#s.pendingRewards + 1] = row
    return row, true
  end

  function W.grantReward(game, s, reward, token)
    s = s or state()
    if not reward or not token then return nil, "invalid" end
    s.rewardedTokens = type(s.rewardedTokens) == "table"
      and s.rewardedTokens or {}
    if s.rewardedTokens[token] then return nil, "duplicate" end
    if reward.kind == "catchup" then
      local controller = currentRewardController()
      if not (controller and type(controller.unlock) == "function") then
        return nil, "catchup_controller_missing"
      end
      local text, changed, placement = controller.unlock(game,
        reward.unlock, { pcFallback = true, source = "legacy_wanderer" })
      if not changed then
        local status = W.catchupStatus(game)
        local stillMissing = reward.unlock == "expShare"
          and status.expShareMissing or reward.unlock == 2
          and status.multiplier2Missing or (reward.unlock == 3
            or reward.unlock == 5) and status.nextMultiplier == reward.unlock
        if stillMissing then return nil, "catchup_unlock_failed" end
        -- A crash or another earned reward may have completed the controller
        -- transaction before this encounter token was recorded. Consume the
        -- token without duplicating the physical item or the unlock state.
        placement = placement or "owned"
      end
      s.rewardedTokens[token] = true
      persist(s)
      return placement or "owned", nil, text
    end
    local placement, reason = placeNow(game, reward)
    if not placement and reason == "full" then
      reservePending(s, reward, token)
      placement = "pending"
    elseif not placement then
      return nil, reason
    end
    s.rewardedTokens[token] = true
    persist(s)
    return placement
  end

  function W.deliverPending(game, s)
    s = s or state()
    local row = s.pendingRewards[1]
    if not row then return nil, false end
    local placement = placeNow(game, row)
    if not placement then return nil, false end
    table.remove(s.pendingRewards, 1)
    persist(s)
    return placement, true, row
  end

  local function itemName(game, item)
    local def = game and game.data and game.data.items
      and game.data.items[item]
    return def and def.name or tostring(item):gsub("_", " ")
  end

  function W.rewardText(game, reward, placement)
    local name = itemName(game, reward.item)
    local stack = clamp(reward.qty or 1, 1, 99) > 1
      and (" ×" .. tostring(clamp(reward.qty, 1, 99))) or ""
    if placement == "bag" then
      return tr("Wanderer reward:\n" .. name .. stack
          .. "!\fIt was put in\nthe BAG.",
        "Wanderpreis:\n" .. name .. stack .. "!\fIm BEUTEL\nverstaut.")
    elseif placement == "pc" then
      return tr("Wanderer reward:\n" .. name .. stack
          .. "!\fThe BAG was full; it\nwent to your PC.",
        "Wanderpreis:\n" .. name .. stack
          .. "!\fBEUTEL voll; im PC\nverstaut.")
    elseif placement == "pending" then
      return tr("Wanderer reward:\n" .. name .. stack
          .. "!\fBAG and PC are full;\nit is reserved safely.",
        "Wanderpreis:\n" .. name .. stack
          .. "!\fBEUTEL und PC voll;\nsicher vorgemerkt.")
    end
    return nil
  end

  local pendingParty
  mod.hooks:wrap("trainer.party", function(nextParty, oppClass, partyIndex, party)
    local pending = pendingParty
    if pending and pending.class == oppClass and pending.index == partyIndex then
      pending.visited = true
      return nextParty(oppClass, partyIndex, copy(pending.team))
    end
    return nextParty(oppClass, partyIndex, party)
  end, 5000)

  mod.hooks:wrap("exp.gain", function(nextGain, ctx)
    local gained = nextGain(ctx)
    local active = W.active
    if not (active and active.battle
        and active.battle.ascendantLegacyWanderer) then return gained end
    return W.applyExpBonus(gained, active.expBonusPercent)
  end, 5000)

  -- Keep the engine's own registered TrainerAI item action, but cap it over
  -- the whole Wanderer battle instead of letting wAICount reset per monster.
  mod.hooks:wrap("battle.enemy_action", function(nextAction, battle)
    if not (battle and battle.ascendantLegacyWanderer) then
      return nextAction(battle)
    end
    local cap = integer(battle.ascendantLegacyHealItemCap)
    if integer(battle.ascendantLegacyHealItemUses) >= cap then
      battle.aiUses = 0
    end
    local action = nextAction(battle)
    if action and action.special == "aiItem" then
      battle.ascendantLegacyHealItemUses = math.min(cap,
        integer(battle.ascendantLegacyHealItemUses) + 1)
    end
    return action
  end, 4800)

  function W.applyExpBonus(gained, percent)
    gained = math.max(1, math.floor(tonumber(gained) or 1))
    percent = clamp(percent or W.MIN_EXP_PERCENT,
      W.MIN_EXP_PERCENT, W.MAX_EXP_PERCENT)
    return math.max(1, math.floor(gained * (100 + percent) / 100 + 0.5))
  end

  local function encounterValid(game, encounter)
    if type(encounter) ~= "table" or type(encounter.token) ~= "string"
        or type(encounter.class) ~= "string"
        or type(encounter.team) ~= "table" or #encounter.team == 0 then
      return false
    end
    local trainer = game and game.data and game.data.trainers
      and game.data.trainers[encounter.class]
    if not (trainer and trainer.parties
        and trainer.parties[encounter.partyIndex]
        and safePartyIndex(encounter.class, encounter.partyIndex)
        and not W.isStoryTrainer(encounter.class, trainer)) then return false end
    if not (game.data.pokemon and game.data.sprites
        and game.data.sprites[encounter.sprite]) then return false end
    for _, slot in ipairs(encounter.team) do
      if not (type(slot) == "table" and game.data.pokemon[slot.species]
          and tonumber(slot.level) and speciesAllowed(game, slot.species)) then
        return false
      end
    end
    return true
  end

  function W.prepareEncounter(game, s)
    s = s or state()
    if encounterValid(game, s.encounter) then return s.encounter, false end
    s.encounter = nil
    local pool = W.liveTrainerPool(game)
    if #pool == 0 then return nil, "no_trainers" end
    local archetype = pool[randomIndex(#pool)]
    local partyIndex, team, tier = W.teamFor(game, archetype, s, nil, true)
    if not team then return nil, "no_team" end
    local expPercent = configuredPercent(opts.expBonusPercent,
      W.MIN_EXP_PERCENT, W.MAX_EXP_PERCENT, "exp")
    local reward = W.selectReward(game)
    local token = "legacy-wanderer:" .. tostring(s.nextToken)
    s.nextToken = s.nextToken + 1
    s.encounter = {
      token = token,
      class = archetype.class,
      sprite = archetype.sprite,
      fieldSpriteExact = archetype.fieldSpriteExact == true,
      fieldSpriteFallback = archetype.fieldSpriteFallback == true,
      partyIndex = partyIndex,
      team = copy(team), tier = copy(tier),
      expBonusPercent = expPercent,
      reward = reward and copy(reward) or nil,
    }
    persist(s)
    return s.encounter, true
  end

  function W.encoreOdds(s)
    local profile = W.FREQUENCY_PROFILES[normalizeFrequency(
      s and s.frequency)] or W.FREQUENCY_PROFILES.normal
    return profile.encoreHits or 0, profile.encoreDenominator or 0
  end

  function W.mapCanHostEncounter(game, s, mapId)
    if not W.isEligibleMap(mapId) then return false end
    s = s or state()
    if s.cadenceMode == "encore" then return mapId == s.encoreMap end
    if s.lastWinMap == mapId then
      if integer(s.mapWinCount) >= W.MAX_ENCOUNTERS_PER_MAP then return false end
    end
    return true
  end

  function W.shouldEncore(game, s, mapId, roll)
    if not W.isEligibleMap(mapId)
        or integer(s and s.mapWinCount) >= W.MAX_ENCOUNTERS_PER_MAP then
      return false
    end
    local hits, denominator = W.encoreOdds(s)
    if hits <= 0 or denominator <= 0 then return false end
    roll = clamp(roll or rawRandom(1, denominator, "encore"),
      1, denominator)
    return roll <= hits
  end

  local function scheduleAfterWin(game, s, encounter)
    local mapId = encounter and encounter.mapId
    if W.isEligibleMap(mapId) then
      if s.lastWinMap == mapId then
        s.mapWinCount = math.min(W.MAX_ENCOUNTERS_PER_MAP,
          integer(s.mapWinCount) + 1)
      else
        s.lastWinMap, s.mapWinCount = mapId, 1
      end
      if s.mapWinCount < W.MAX_ENCOUNTERS_PER_MAP
          and W.shouldEncore(game, s, mapId) then
        W.scheduleEncore(s, mapId)
        return "encore"
      end
      W.scheduleNext(s, {
        targetMapChanges = s.mapWinCount >= W.MAX_ENCOUNTERS_PER_MAP
          and W.MAX_MAP_CHANGES or nil,
        startMap = mapId,
        forceMapChanges = s.mapWinCount >= W.MAX_ENCOUNTERS_PER_MAP,
      })
      return "normal"
    end
    W.scheduleNext(s)
    return "normal"
  end

  function W.lossText(relief)
    relief = clamp(relief, 0, W.MAX_LOSS_RELIEF)
    local nextLine
    if relief >= W.LOSS_TEAM_REDUCTION_AT then
      nextLine = tr("Next team is smaller.", "Nächstes Team ist kleiner.")
    else
      nextLine = tr("Their level edge shrinks.", "Ihr Levelvorteil sinkt.")
    end
    return tr("ROAD TRIAL: LOST.\nNo reward was earned.\f"
        .. "Your money is safe.\nRelief: ",
      "WEGPRÜFUNG: VERLOREN.\nKein Preis erhalten.\f"
        .. "Dein Geld bleibt sicher.\nHilfe: ")
      .. tostring(relief) .. "/" .. tostring(W.MAX_LOSS_RELIEF)
      .. "\f" .. nextLine
  end

  function W.resolveEncounter(game, s, encounter, result)
    s = s or state()
    encounter = encounter or s.encounter
    if not encounter or not s.encounter
        or encounter.token ~= s.encounter.token then
      return nil, "stale"
    end
    if result ~= "win" then
      -- A loss resolves this road encounter. Keeping the same token due made
      -- the trainer respawn immediately after blackout and could trap a weak
      -- party in an involuntary rematch loop. No reward/win/mark is granted;
      -- a completely new encounter is scheduled behind the normal cadence.
      s.losses = integer(s.losses) + 1
      s.lossRelief = math.min(W.MAX_LOSS_RELIEF,
        integer(s.lossRelief) + 1)
      s.streak = 0
      s.encounter = nil
      W.scheduleNext(s, {
        startMap = encounter.mapId,
        targetMapChanges = W.MAX_MAP_CHANGES,
        forceMapChanges = true,
      })
      persist(s)
      return "resolved_loss"
    end
    local placement, rewardReason, specialText
    if encounter.reward then
      placement, rewardReason, specialText = W.grantReward(
        game, s, encounter.reward, encounter.token)
      if not placement and rewardReason ~= "duplicate" then
        -- An invalid live registry must not consume the victory transaction.
        -- Keep the exact encounter due so a repaired registry can retry it.
        s.due, s.stepsRemaining = true, 0
        persist(s)
        return nil, rewardReason
      end
    end
    s.wins, s.streak, s.marks = s.wins + 1, s.streak + 1, s.marks + 1
    -- A recovery win restores the intended edge gradually instead of
    -- snapping a struggling player straight back to maximum difficulty.
    s.lossRelief = math.max(0, integer(s.lossRelief) - 1)
    s.encounter = nil
    scheduleAfterWin(game, s, encounter)
    persist(s)
    return placement or "no_reward", rewardReason, specialText
  end

  local function cleanup(active)
    active = active or W.active
    if not active then return end
    if active.npcId then mod.world:removeNpc(active.npcId) end
    local ow = active.ow
    if ow then
      ow.engaging = false
      if ow.player then ow.player.inputLocked = false end
    end
    W.active = nil
  end

  function W.configureBattle(game, battle, active)
    if not (game and battle and active and active.tier) then return nil end
    battle.ascendantLegacyWanderer = true
    battle.ascendantLegacyTier = active.tier
    battle.ascendantLegacyToken = active.token
    battle.ascendantLegacyExpBonus = active.expBonusPercent
    battle.enemyAIMods = {}
    for layer = 1, integer(active.tier.aiLayers) do
      battle.enemyAIMods[#battle.enemyAIMods + 1] = layer
    end
    battle.ascendantLegacyHealItemCap = active.tier.targetLevel >= 80
      and active.tier.lossRelief == 0 and 1 or 0
    battle.ascendantLegacyHealItemUses = 0
    battle.introText = tr("The road trial\nbegins!",
      "Die Wegprüfung\nbeginnt!")
    battle.endBattleText = tr("Road trial\ncomplete!",
      "Wegprüfung\nbestanden!")
    if battle.trainer then
      local multiplier = active.tier.pact == "ascendant" and 3
        or active.tier.pact == "legacy" and 2.75 or 2.5
      battle.trainer = setmetatable({
        baseMoney = math.max(1, math.floor(
          (tonumber(battle.trainer.baseMoney) or 1) * multiplier + 0.5)),
        -- Sabrina's registered class uses one legal Hyper Potion below 10%
        -- HP. The hook above makes that one use battle-wide, never per mon.
        aiClass = active.tier.targetLevel >= 80 and "OPP_SABRINA"
          or battle.trainer.aiClass,
      }, { __index = battle.trainer })
    end
    local mastery = currentProvider(masteryProvider)
    if mastery and type(mastery.apply) == "function" then
      battle.rematchMasteryReport = mastery.apply(game, battle, {
        kind = "legacy_wanderer", key = active.token,
        progress = active.tier.growthProgress or 0,
        masteryWins = active.tier.legacyWins or 0,
        perfect = active.tier.perfectMastery == true,
      })
      battle.ascendantLegacyPerfectMastery = battle.rematchMasteryReport
        and battle.rematchMasteryReport.perfect == true or false
    elseif battle.aiUsesFor then
      battle.aiUses = battle:aiUsesFor()
    end
    return battle
  end

  local function startBattle(active)
    if W.active ~= active then return cleanup(active) end
    local game, ow = active.game, active.ow
    if not (game and ow and game.overworld == ow and ow.map
        and ow.map.id == active.mapId) then return cleanup(active) end
    local BattleState = require("src.battle.BattleState")
    pendingParty = {
      class = active.archetype.class, index = active.partyIndex,
      team = active.team,
    }
    local battle = BattleState.newTrainer(game, active.archetype.class,
      active.partyIndex)
    pendingParty = nil
    if not battle or battle.dead then return cleanup(active) end
    W.configureBattle(game, battle, active)
    active.battle = battle
    active.moneyBefore = tonumber(game.save.money) or 0
    battle.onFinish = function(result)
      ow:afterBattle(result, battle)
      if result == "lose" then game.save.money = active.moneyBefore end
      if result == "lose" and active.lossText and game.stack then
        game.stack:push(require("src.render.TextBox").new(
          game, active.lossText))
      end
      if result == "win" and active.rewardText and game.stack then
        game.stack:push(require("src.render.TextBox").new(
          game, active.rewardText))
      end
    end
    ow:pushBattle(battle)
  end

  local function walkPath(active, index)
    if W.active ~= active then return cleanup(active) end
    local dir = active.path[index]
    if not dir then return startBattle(active) end
    local handle = mod.world:npc(active.mapId, active.npcId)
    if not handle then return cleanup(active) end
    handle:scriptMove(dir, 1, function() walkPath(active, index + 1) end)
  end

  function W.trySpawn(game)
    if W.active or not contextSafe(game) then return false end
    local ow, mapId = game.overworld, game.overworld.map.id
    if not W.isEligibleMap(mapId) then return false end
    local s = state()
    if W.syncFrequency(game, s) == "never" then return false end
    if not W.mapCanHostEncounter(game, s, mapId) then return false end
    local approach = W.findApproach(ow)
    if not approach then return false end
    local encounter = W.prepareEncounter(game, s)
    if not encounter then return false end
    encounter.mapId = mapId
    persist(s)
    local archetype = {
      class = encounter.class, sprite = encounter.sprite,
      fieldSpriteExact = encounter.fieldSpriteExact,
      fieldSpriteFallback = encounter.fieldSpriteFallback,
    }
    local npcId = mod.world:spawnNpc(mapId, {
      name = "KA_LEGACY_WANDERER",
      sprite = archetype.sprite,
      movement = "STAY", range = "DOWN",
      x = approach.x, y = approach.y,
    })
    if not npcId then return false end
    local handle = mod.world:npc(mapId, npcId)
    if not handle then mod.world:removeNpc(npcId); return false end
    local active = {
      game = game, ow = ow, mapId = mapId, npcId = npcId,
      token = encounter.token,
      archetype = archetype, partyIndex = encounter.partyIndex,
      team = copy(encounter.team), tier = copy(encounter.tier),
      expBonusPercent = encounter.expBonusPercent,
      reward = encounter.reward and copy(encounter.reward) or nil,
      path = approach.path,
    }
    W.active = active
    ow.engaging = true
    ow.player.inputLocked = true
    handle:face(approach.path[1] or "down")
    ow.emote = {
      npc = handle.npc, frames = 45,
      onDone = function()
        if W.active ~= active then return cleanup(active) end
        game.stack:push(require("src.render.TextBox").new(game,
          W.challengeText(active), function() walkPath(active, 1) end))
      end,
    }
    return true
  end

  function W.legacyRunEnabled(game)
    if not (game and game.save and journey.wanderersEnabled(game.save)) then
      return false
    end
    local legacy = journey.state(game.save)
    return type(legacy) == "table"
      and (legacy.runId ~= nil or integer(legacy.cycle) >= 2)
  end

  mod.events:on("game.ready", function(ev) W.game = ev and ev.game end, 1000)
  mod.events:on("save.loaded", function(ev)
    W.game = ev and ev.game or W.game
    W.active = nil
    if W.legacyRunEnabled(W.game) then state() end
  end, 1000)
  mod.events:on("world.stepped", function(ev)
    local game = W.game
    if not W.legacyRunEnabled(game) then return end
    local s = state()
    local frequency = W.syncFrequency(game, s)
    if contextSafe(game) and #s.pendingRewards > 0 then
      local placement, delivered, row = W.deliverPending(game, s)
      if delivered then
        game.stack:push(require("src.render.TextBox").new(game,
          W.rewardText(game, row, placement)))
        return
      end
    end
    if frequency == "never" then return end
    local due = W.advanceCadence(s, ev and ev.mapId)
    persist(s)
    if due then W.trySpawn(game) end
  end, 4500)
  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    local active = W.active
    if not (active and battle and battle == active.battle
        and battle.ascendantLegacyWanderer) then return end
    local s = state()
    local encounter = s.encounter
    if not (encounter and encounter.token == active.token) then
      cleanup(active)
      return
    end
    local placement, _, specialText = W.resolveEncounter(
      active.game, s, encounter, ev.result)
    if ev.result == "win" and placement and placement ~= "no_reward" then
      active.rewardText = specialText or W.rewardText(active.game,
        encounter.reward, placement)
    elseif ev.result ~= "win" and placement == "resolved_loss" then
      active.lossText = W.lossText(s.lossRelief)
    end
    cleanup(active)
  end, 5000)

  mod.hooks:wrap("encounter.species", function(nextEncounter, enc, ctx)
    if W.active then return nil end
    return nextEncounter(enc, ctx)
  end, 5000)

  W.state = state
  W.contextSafe = contextSafe
  W.cleanup = cleanup
  return W
end
