-- KA-INTERNAL: LEGACY-JOURNEY-001

return function(opts)
  opts = opts or {}

  local SaveSerializer = opts.serializer
    or require("src.core.SaveSerializer")
  local fs = opts.fs
  local persistent = fs ~= nil and type(fs.read) == "function"
    and type(fs.write) == "function" and type(fs.getInfo) == "function"
  if not persistent then
    fs = {
      getInfo = function() return nil end,
      read = function() return nil end,
      write = function()
        return false, "persistent filesystem unavailable"
      end,
      createDirectory = function() return false end,
      remove = function() return false end,
    }
  end

  local edition = tostring(opts.edition or "red"):lower()
  local modId = tostring(opts.modId or "kanto_ascendant")
  local directory = opts.directory or "kanto_ascendant/legacy"
  local filename = directory .. "/" .. edition .. ".lua"
  local backup = filename .. ".bak"
  local witness = filename .. ".tmp"
  local rollback = directory .. "/" .. edition .. "_rollback.lua"
  local VERSION = 7
  local HANDOFF_VERSION = 1
  local STORAGE_BINDING_VERSION = 1
  local FRESH_ORIGIN_VERSION = 1
  local BANK_POLICY_VERSION = 1
  local ITEM_POLICY_VERSION = 1
  local RUN_RULES_SNAPSHOT_VERSION = 1
  local PACTS = {
    journey = true, trainer = true, legacy = true, ascendant = true,
  }
  local BANK_POLICIES = {
    open = true, badges4 = true, league = true, sealed = true,
  }
  local ITEM_POLICIES = { safe = true, empty = true }
  local function pactId(value)
    value = tostring(value or ""):lower()
    return PACTS[value] and value or "journey"
  end
  local function bankPolicyId(value, pact)
    value = tostring(value or ""):lower()
    if BANK_POLICIES[value] then return value end
    -- Old archives predate the independent bank choice.  Preserve their
    -- historically open behaviour; Ascendant's authored recommendation is
    -- the sole safe default for a newly supplied Ascendant pact.
    return pactId(pact) == "ascendant" and "sealed" or "open"
  end
  local function itemPolicyId(value)
    value = tostring(value or ""):lower()
    return ITEM_POLICIES[value] and value or "safe"
  end
  local log = opts.log or { info = function() end, error = function() end }
  local now = opts.now or os.time
  local isBadge = opts.isBadge or function(id)
    return tostring(id or ""):find("BADGE", 1, true) ~= nil
  end
  local registries = {
    pokemon = opts.pokemonRegistry,
    items = opts.itemRegistry,
    moves = opts.moveRegistry,
  }
  local registryValidation = type(registries.pokemon) == "table"
    and type(registries.items) == "table" and type(registries.moves) == "table"
  local requireRegistryValidation = opts.requireRegistryValidation == true
  local editionScoped = opts.editionScoped == true
  local enforceLegacyMigrationGuard = opts.enforceLegacyMigrationGuard == true
  local withdrawalGate = opts.withdrawalGate
  local function registryReady()
    return registryValidation or not requireRegistryValidation
  end

  -- Legacy Locker item policy. Counted supplies and one-use TMs are the only
  -- inventory records that cross a fresh story. Everything whose ownership
  -- is a story receipt (badges, HMs, Field Kit and other key items) must be
  -- earned again in the live journey. Mega access is also re-earned, while
  -- each official Mega Stone crosses as one unique Locker receipt and may be
  -- imported only after this journey opens its Stone Case. Keeping the
  -- categories explicit prevents a newly added non-tossable mod item from
  -- silently becoming a duplicate locker payout.
  local ITEM_POLICY_CATEGORIES = {
    consumable = {
      transferable = true, claimMode = "counted",
      summary = "Counted supplies retain their exact archived quantity.",
    },
    tm = {
      transferable = true, claimMode = "counted",
      summary = "TMs retain their exact archived quantity.",
    },
    badge = {
      transferable = false, claimMode = "current_story",
      summary = "Badges must be earned again in the current journey.",
    },
    hm = {
      transferable = false, claimMode = "current_story",
      summary = "HMs must be earned again in the current journey.",
    },
    field_kit = {
      transferable = false, claimMode = "current_story_once",
      summary = "The Field Kit is granted once by its current-run milestone.",
    },
    mega_access = {
      transferable = false, claimMode = "current_story_once",
      summary = "Mega Ring and Stone Case come from this journey's Mega event.",
    },
    mega_stone = {
      transferable = true, claimMode = "unique_after_mega_access",
      summary = "Mega Stones archive once and claim into an active Stone Case.",
    },
    key_item = {
      transferable = false, claimMode = "current_story_once",
      summary = "Key items must come from their current-run story event.",
    },
    unknown = {
      transferable = false, claimMode = "quarantine",
      summary = "Unregistered items remain quarantined until their mod returns.",
    },
  }

  -- Transfer policy is deliberately ID-driven.  The 0.1.95 item schema has
  -- no mod metadata slot for a Legacy category, and `tossable = false` is
  -- shared by both story receipts and perfectly valid one-use evolution
  -- tools.  These two lists mirror the cart's KeyItemFlags plus Ascendant's
  -- own durable/story receipts.  A newly registered non-tossable item must be
  -- reviewed and added to one side instead of silently becoming a duplicate
  -- story grant.
  local STORY_ITEM_IDS = {
    -- Red/Blue/Yellow KeyItemFlags and unique story receipts.
    TOWN_MAP = true, BICYCLE = true, SURFBOARD = true,
    SAFARI_BALL = true, POKEDEX = true,
    OLD_AMBER = true, DOME_FOSSIL = true, HELIX_FOSSIL = true,
    SECRET_KEY = true, ITEM_2C = true, BIKE_VOUCHER = true,
    CARD_KEY = true, S_S_TICKET = true, GOLD_TEETH = true,
    COIN_CASE = true, OAKS_PARCEL = true, ITEMFINDER = true,
    SILPH_SCOPE = true, POKE_FLUTE = true, LIFT_KEY = true,
    OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true,
    -- EXP ALL is a unique Oak-aide reward even though the cart lets it be
    -- tossed.  Copying it would bypass its current-run Pokédex milestone.
    EXP_ALL = true,
    -- Kanto Ascendant current-run/durable receipts.
    SHINY_CHARM = true,
    ASCENDANT_EXP_MULTIPLIER = true,
    MIGRATION_RECEIVER = true, RESONANCE_SEAL = true,
    ASCENDANT_THUNDERHEART = true, ASCENDANT_THUNDER_TEAR = true,
  }

  -- Hidden-Evolution package tools are consumed by their normal item effect.
  -- They are intentionally non-tossable so players cannot discard progress;
  -- that does not turn them into story keys at the Legacy boundary.
  local COUNTED_NON_TOSSABLE_IDS = {
    PROTECTOR = true, MAGMARIZER = true, RAZOR_FANG = true,
    ELECTIRIZER = true, RAZOR_CLAW = true, DUBIOUS_DISC = true,
    SHINY_STONE = true, DUSK_STONE = true,
  }

  local MEGA_STONE_IDS = {
    VENUSAURITE = true, CHARIZARDITE_X = true, CHARIZARDITE_Y = true,
    BLASTOISINITE = true, BEEDRILLITE = true, PIDGEOTITE = true,
    ALAKAZITE = true, SLOWBRONITE = true, GENGARITE = true,
    KANGASKHANITE = true, PINSIRITE = true, GYARADOSITE = true,
    AERODACTYLITE = true, MEWTWONITE_X = true, MEWTWONITE_Y = true,
    AMPHAROSITE = true, STEELIXITE = true, SCIZORITE = true,
    HERACRONITE = true, HOUNDOOMINITE = true, TYRANITARITE = true,
    BLAZIKENITE = true, SWAMPERTITE = true, SCEPTILITE = true,
    CLEFABLITE = true, VICTREEBELITE = true, STARMIENITE = true,
    DRAGONINITE = true, MEGANIUMITE = true, FERALIGATRITE = true,
    SKARMORITE = true, RAICHUNITE_X = true, RAICHUNITE_Y = true,
  }
  -- The three Hoenn path rewards are visible, permanent souvenirs of a
  -- completed character route.  EMPTY suppresses optional Bag/PC cargo, but
  -- these unique Stone Case receipts still cross the reset when they were
  -- actually earned.  Path/partner eligibility remains keyed exclusively to
  -- `completedPaths`; owning a stone never proves that a path was completed.
  local LEGACY_PATH_MEGA_STONES = {
    BLAZIKENITE = true, SWAMPERTITE = true, SCEPTILITE = true,
  }

  -- Only authored Trainer Card titles may cross a real Legacy Journey reset.
  -- Keeping this allow-list beside the archive boundary prevents a stale mod,
  -- typo or tampered save key from becoming a permanent "phantom" title.
  local achievementTitleIds = {}
  for _, id in ipairs(opts.achievementTitleIds or {
    "rematch_10", "rematch_50", "master_circuit", "apex_champion",
    "beast_tracker", "sky_pair", "leader_confidant", "tournament_champ",
    "crown_champion", "rocket_breaker", "untouchable", "purist",
    "mew_found", "ascendant", "johto_master", "factory_architect",
    "sea_champion",
  }) do
    achievementTitleIds[tostring(id)] = true
  end
  local legacyTitleProgress = {
    legacy_path_red = "red",
    legacy_path_blue = "blue",
    legacy_path_green = "green",
    legacy_pass = "PASS",
  }

  local A = {
    version = VERSION,
    filename = filename,
    rollbackFilename = rollback,
    persistent = persistent == true,
    readOnly = false,
    futureVersion = nil,
    readOnlyReason = nil,
    unavailableReason = persistent and nil
      or "Legacy Journey cannot access the official mod storage API",
  }

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, child in pairs(value) do
      result[copy(key, seen)] = copy(child, seen)
    end
    return result
  end

  -- Only this compact, data-only contract crosses the source/fresh-save
  -- boundary. Runtime mappings, encounter history and deaths are deliberately
  -- absent; the fresh save creates those after its 151/251 pool is final.
  local function canonicalRunRules(raw)
    if raw == nil then return nil end
    if type(raw) ~= "table" then
      return nil, "Legacy run-rules snapshot is not a table"
    end
    local function knownKeys(value, allowed, label)
      for key in pairs(value) do
        if not allowed[key] then
          return false, label .. " has an unknown field: " .. tostring(key)
        end
      end
      return true
    end
    local known, knownErr = knownKeys(raw, {
      version = true, preset = true, seed = true,
      randomizer = true, nuzlocke = true,
    }, "Legacy run-rules snapshot")
    if not known then return nil, knownErr end
    if math.floor(tonumber(raw.version) or 0) ~= RUN_RULES_SNAPSHOT_VERSION then
      return nil, "Legacy run-rules snapshot version is invalid"
    end
    local allowedPresets = {
      standard = true, gentle = true, classic = true,
      ascendant = true, chaos = true, custom = true,
    }
    local preset = tostring(raw.preset or "standard"):lower()
    if not allowedPresets[preset] then
      return nil, "Legacy run-rules snapshot has an unknown profile"
    end
    local seed = tonumber(raw.seed)
    if not seed or seed ~= seed or seed < 1 then
      return nil, "Legacy run-rules snapshot has an invalid seed"
    end
    local sourceRandomizer = raw.randomizer
    local sourceNuzlocke = raw.nuzlocke
    if type(sourceRandomizer) ~= "table" or type(sourceNuzlocke) ~= "table" then
      return nil, "Legacy run-rules snapshot is incomplete"
    end
    known, knownErr = knownKeys(sourceRandomizer, {
      enabled = true, wild = true, trainers = true, starters = true,
      gifts = true, static = true, items = true, legendary = true,
      balanced = true, consistent = true,
    }, "Legacy Randomizer snapshot")
    if not known then return nil, knownErr end
    known, knownErr = knownKeys(sourceNuzlocke, {
      mode = true, dupes = true, blackout = true, shinyOdds = true,
    }, "Legacy Nuzlocke snapshot")
    if not known then return nil, knownErr end
    local randomizer = {}
    for _, key in ipairs({ "enabled", "wild", "trainers", "starters",
        "gifts", "static", "items", "legendary", "balanced",
        "consistent" }) do
      if type(sourceRandomizer[key]) ~= "boolean" then
        return nil, "Legacy Randomizer rule is not boolean: " .. key
      end
      randomizer[key] = sourceRandomizer[key]
    end
    local modes = { off = true, standard = true, shiny_clause = true,
      shinylocke = true }
    local mode = tostring(sourceNuzlocke.mode or ""):lower()
    local odds = math.floor(tonumber(sourceNuzlocke.shinyOdds) or 0)
    local validOdds = { [8192] = true, [4096] = true,
      [1024] = true, [256] = true }
    if not modes[mode] or type(sourceNuzlocke.dupes) ~= "boolean"
        or sourceNuzlocke.blackout ~= "end"
        or not validOdds[odds] then
      return nil, "Legacy Nuzlocke snapshot is invalid"
    end
    return {
      version = RUN_RULES_SNAPSHOT_VERSION,
      preset = preset, seed = math.max(1, math.floor(seed)),
      randomizer = randomizer,
      nuzlocke = {
        mode = mode, dupes = sourceNuzlocke.dupes,
        blackout = "end", shinyOdds = odds,
      },
    }
  end

  -- Explicit helper for internal migration/QA callers which deliberately
  -- choose the safest new-run contract.  beginJourney itself never falls
  -- back to this: every new v7 transaction must still supply a snapshot.
  local function safeRunRulesSnapshot(save)
    local player = type(save and save.player) == "table" and save.player or {}
    local bucket = type(save and save.modData) == "table"
      and save.modData[modId] or nil
    local run = type(bucket) == "table" and bucket.legacy_journey or nil
    local text = table.concat({
      tostring(type(run) == "table" and run.runId or "legacy-v6"),
      tostring(type(run) == "table" and run.cycle or 0),
      tostring(player.id or 0), tostring(player.name or "PLAYER"),
      tostring(save and save.version or "unknown"),
    }, ":")
    local seed = 2166136261 % 100000000
    for index = 1, #text do
      seed = (seed * 16777619 + text:byte(index) * index) % 100000000
    end
    return {
      version = RUN_RULES_SNAPSHOT_VERSION,
      preset = "standard", seed = math.max(1, math.floor(seed)),
      randomizer = {
        enabled = false, wild = true, trainers = true, starters = true,
        gifts = false, static = false, items = false, legendary = false,
        balanced = true, consistent = true,
      },
      nuzlocke = {
        mode = "off", dupes = true, blackout = "end", shinyOdds = 4096,
      },
    }
  end

  -- The receipt digest is deliberately local and data-only: both the
  -- sandboxed runtime and the offline one-time migrator can reproduce it
  -- without reaching an engine-private hashing or filesystem module.
  local function digestText(body)
    local a, b = 2166136261, 16777619
    for index = 1, #body do
      a = (a + body:byte(index) * b) % 4294967296
      b = (b * 33 + body:byte(index)) % 4294967296
    end
    return ("%08x%08x"):format(a, b)
  end

  local function empty()
    return {
      version = VERSION,
      cycle = 0,
      bank = {},
      locker = { items = {}, money = 0 },
      quarantine = { bank = {}, items = {} },
      hallOfLegacy = {},
      appliedTransactions = {},
      completedPaths = { red = false, blue = false, green = false },
      pathSealCycles = { red = nil, blue = nil, green = nil },
      legacyPass = false,
      titles = { unlocked = {}, selectedTitle = nil },
      hevoPersistent = {
        meta = { RED = false, BLUE = false, GREEN = false },
        packageUnlocks = {}, evolutionUnlocks = {}, permanentItems = {},
        firstGrants = {}, pendingItems = {}, dex = {}, questionIds = {},
        secretUnlocks = {},
      },
      -- Johto Masters is a cross-journey campaign record.  Keep the
      -- authoritative controller bucket here, but never copy transient map
      -- positions or battle stacks across a Legacy reset.
      johtoMastersPersistent = {
        clears = 0, gifts = 0, title = false, pendingGift = nil,
        goldenTrainerCardDecor = false,
        cadenceVersion = 0, cadenceSerial = 0,
        connectedClears = 0, journeyClears = 0,
        activeRun = false, runSerial = 0, rewardedRunSerial = 0,
        cadenceOwner = nil, lastHallTicket = nil, runTicket = nil,
        passages = {},
      },
      current = {},
    }
  end

  local function schemaVersion(raw)
    if type(raw) ~= "table" then return VERSION end
    return math.max(1, math.floor(tonumber(raw.version) or 1))
  end

  -- Archive schema history. Each migration is deliberately additive: fields
  -- unknown to this build (including partner-catalogue metadata added in
  -- parallel) remain on the table and therefore survive the upgrade.
  local migrations = {
    [1] = function(a)
      if a.completedPaths == nil then
        a.completedPaths = { red = false, blue = false, green = false }
      end
      if a.pathSealCycles == nil then
        a.pathSealCycles = { red = nil, blue = nil, green = nil }
      end
      if a.legacyPass == nil then a.legacyPass = false end
      a.version = 2
    end,
    [2] = function(a)
      if a.hevoPersistent == nil then
        a.hevoPersistent = {
          meta = { RED = false, BLUE = false, GREEN = false },
          packageUnlocks = {}, evolutionUnlocks = {}, permanentItems = {},
          firstGrants = {}, pendingItems = {}, dex = {}, questionIds = {},
          secretUnlocks = {},
        }
      end
      a.version = 3
    end,
    [3] = function(a)
      if a.titles == nil then
        a.titles = { unlocked = {}, selectedTitle = nil }
      end
      a.version = 4
    end,
    [4] = function(a)
      -- v5 owns the active avatar/path and Oak partner contract. Do not seed
      -- individual partner fields here: a v4 fixture may already contain the
      -- parallel implementation's complete choice and rival line.
      if a.current == nil then a.current = {} end
      a.version = 5
    end,
    [5] = function(a)
      if a.johtoMastersPersistent == nil then
        a.johtoMastersPersistent = {
          clears = 0, gifts = 0, title = false, pendingGift = nil,
          goldenTrainerCardDecor = false, passages = {},
        }
      end
      a.version = 6
    end,
    [6] = function(a)
      -- Existing v6 journeys predate item/rule selection. Their historical
      -- item behaviour is SAFE; nil runRules is intentionally retained so the
      -- fresh save derives deterministic OFF from its immutable runId.
      if type(a.current) == "table" and a.current.itemPolicy == nil then
        a.current.itemPolicy = "safe"
      end
      if type(a.current) == "table" and a.current.runRules == nil
          and (a.current.status == "pending_new_game"
            or a.current.status == "active") then
        a.current.runRulesLegacyDefault = true
      end
      if type(a.transaction) == "table"
          and type(a.transaction.hall) == "table"
          and a.transaction.hall.itemPolicy == nil then
        a.transaction.hall.itemPolicy = "safe"
      end
      if type(a.transaction) == "table"
          and type(a.transaction.hall) == "table"
          and a.transaction.hall.runRules == nil then
        a.transaction.hall.runRulesLegacyDefault = true
      end
      for _, entry in ipairs(type(a.hallOfLegacy) == "table"
          and a.hallOfLegacy or {}) do
        if type(entry) == "table" and entry.itemPolicy == nil then
          entry.itemPolicy = "safe"
        end
      end
      a.version = 7
    end,
  }

  local function normalizeCurrent(a)
    local function normalizeRules(owner, label, requireSnapshot)
      if type(owner) ~= "table" then return true end
      if owner.runRules == nil then
        if requireSnapshot and owner.runRulesLegacyDefault ~= true then
          return nil, label .. " is missing its confirmed run-rules snapshot"
        end
        return true
      end
      local normalized, err = canonicalRunRules(owner.runRules)
      if not normalized then return nil, label .. ": " .. tostring(err) end
      owner.runRules = normalized
      owner.runRulesLegacyDefault = nil
      return true
    end
    a.version = VERSION
    a.cycle = math.max(0, math.floor(tonumber(a.cycle) or 0))
    a.bank = type(a.bank) == "table" and a.bank or {}
    a.locker = type(a.locker) == "table" and a.locker or {}
    a.locker.items = type(a.locker.items) == "table"
      and a.locker.items or {}
    a.locker.money = math.max(0, math.floor(
      tonumber(a.locker.money) or 0))
    a.quarantine = type(a.quarantine) == "table" and a.quarantine or {}
    a.quarantine.bank = type(a.quarantine.bank) == "table"
      and a.quarantine.bank or {}
    a.quarantine.items = type(a.quarantine.items) == "table"
      and a.quarantine.items or {}
    a.hallOfLegacy = type(a.hallOfLegacy) == "table"
      and a.hallOfLegacy or {}
    for _, entry in ipairs(a.hallOfLegacy) do
      if type(entry) == "table" then
        entry.pact = pactId(entry.pact)
        entry.bankPolicy = bankPolicyId(entry.bankPolicy, entry.pact)
        entry.itemPolicy = itemPolicyId(
          entry.itemPolicy or entry.itemTransferPolicy)
        entry.itemTransferPolicy = nil
        entry.itemPolicyVersion = math.max(1, math.floor(
          tonumber(entry.itemPolicyVersion) or ITEM_POLICY_VERSION))
        local rulesOk, rulesErr = normalizeRules(entry,
          "Legacy Hall entry", false)
        if not rulesOk then return nil, rulesErr end
      end
    end
    a.appliedTransactions = type(a.appliedTransactions) == "table"
      and a.appliedTransactions or {}
    a.completedPaths = type(a.completedPaths) == "table"
      and a.completedPaths or {}
    for _, key in ipairs({ "red", "blue", "green" }) do
      a.completedPaths[key] = a.completedPaths[key] == true
    end
    a.pathSealCycles = type(a.pathSealCycles) == "table"
      and a.pathSealCycles or {}
    for _, key in ipairs({ "red", "blue", "green" }) do
      local earned = tonumber(a.pathSealCycles[key])
      if a.completedPaths[key] then
        a.pathSealCycles[key] = math.max(0, math.floor(earned or 0))
      else
        a.pathSealCycles[key] = nil
      end
    end
    a.legacyPass = a.legacyPass == true
    a.titles = type(a.titles) == "table" and a.titles or {}
    local unlockedTitles = {}
    for id, unlocked in pairs(type(a.titles.unlocked) == "table"
        and a.titles.unlocked or {}) do
      if unlocked == true and achievementTitleIds[tostring(id)] then
        unlockedTitles[tostring(id)] = true
      end
    end
    a.titles.unlocked = unlockedTitles
    local selectedTitle = type(a.titles.selectedTitle) == "string"
      and a.titles.selectedTitle or nil
    local legacyProgress = selectedTitle and legacyTitleProgress[selectedTitle]
    local selectedUnlocked = selectedTitle
      and (achievementTitleIds[selectedTitle]
        and unlockedTitles[selectedTitle] == true
        or legacyProgress == "PASS" and a.legacyPass == true
        or legacyProgress and legacyProgress ~= "PASS"
          and a.completedPaths[legacyProgress] == true)
    a.titles.selectedTitle = selectedUnlocked and selectedTitle or nil
    a.hevoPersistent = type(a.hevoPersistent) == "table"
      and a.hevoPersistent or {}
    a.hevoPersistent.meta = type(a.hevoPersistent.meta) == "table"
      and a.hevoPersistent.meta or {}
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      a.hevoPersistent.meta[key] = a.hevoPersistent.meta[key] == true
    end
    for _, key in ipairs({ "packageUnlocks", "evolutionUnlocks",
      "permanentItems", "firstGrants", "pendingItems", "dex",
      "questionIds", "secretUnlocks" }) do
      a.hevoPersistent[key] = type(a.hevoPersistent[key]) == "table"
        and a.hevoPersistent[key] or {}
    end
    -- RC23 preview saves recorded the three optional Mega caches as if path
    -- completion itself had found them.  The explicit secret ledger is now
    -- authoritative; this migration removes only those unverifiable flags
    -- and leaves the cache available for a real character-bound re-entry.
    for character, stone in pairs({ RED = "BLAZIKENITE",
        BLUE = "SWAMPERTITE", GREEN = "SCEPTILITE" }) do
      if a.hevoPersistent.secretUnlocks[character] == true then
        a.hevoPersistent.permanentItems[stone] = true
      else
        a.hevoPersistent.permanentItems[stone] = nil
      end
    end
    a.johtoMastersPersistent = type(a.johtoMastersPersistent) == "table"
      and a.johtoMastersPersistent or {}
    local masters = a.johtoMastersPersistent
    masters.clears = math.max(0, math.floor(tonumber(masters.clears) or 0))
    masters.gifts = math.max(0, math.floor(tonumber(masters.gifts) or 0))
    masters.title = masters.title == true
    masters.goldenTrainerCardDecor = masters.goldenTrainerCardDecor == true
      or masters.title
    masters.pendingGift = type(masters.pendingGift) == "table"
      and masters.pendingGift or nil
    masters.cadenceVersion = math.max(0, math.floor(
      tonumber(masters.cadenceVersion) or 0))
    masters.cadenceSerial = math.max(0, math.floor(
      tonumber(masters.cadenceSerial) or 0))
    masters.connectedClears = math.max(0, math.floor(
      tonumber(masters.connectedClears) or 0))
    masters.journeyClears = math.max(0, math.floor(
      tonumber(masters.journeyClears) or 0))
    masters.activeRun = masters.activeRun == true
    masters.runSerial = math.max(masters.connectedClears, math.floor(
      tonumber(masters.runSerial) or 0))
    masters.rewardedRunSerial = math.max(0, math.min(
      masters.runSerial, math.floor(tonumber(masters.rewardedRunSerial) or 0)))
    masters.cadenceOwner = type(masters.cadenceOwner) == "string"
      and masters.cadenceOwner or nil
    masters.lastHallTicket = tonumber(masters.lastHallTicket)
      and math.max(0, math.floor(masters.lastHallTicket)) or nil
    masters.runTicket = tonumber(masters.runTicket)
      and math.max(0, math.floor(masters.runTicket)) or nil
    masters.passages = type(masters.passages) == "table" and masters.passages or {}
    for _, key in ipairs({ "silver", "kris", "gold" }) do
      local passage = type(masters.passages[key]) == "table"
        and masters.passages[key] or {}
      local legacyStatus = passage.status
      passage.status = ({ locked = true, unlocked = true, entered = true,
        cleared = true })[legacyStatus] and legacyStatus
        or legacyStatus == "rewarded" and "cleared" or "locked"
      passage.rewarded = passage.rewarded == true
        or legacyStatus == "rewarded"
      passage.attempts = math.max(0, math.floor(tonumber(passage.attempts) or 0))
      passage.puzzle = passage.puzzle == true
      passage.clue = passage.clue == true
      passage.step = math.max(0, math.min(3,
        math.floor(tonumber(passage.step) or 0)))
      passage.resets = math.max(0,
        math.floor(tonumber(passage.resets) or 0))
      masters.passages[key] = passage
    end
    a.current = type(a.current) == "table" and a.current or {}
    a.current.pact = pactId(a.current.pact)
    a.current.bankPolicy = bankPolicyId(
      a.current.bankPolicy, a.current.pact)
    a.current.itemPolicy = itemPolicyId(
      a.current.itemPolicy or a.current.itemTransferPolicy)
    a.current.itemTransferPolicy = nil
    local policyVersion = tonumber(a.current.bankPolicyVersion)
    a.current.bankPolicyVersion = policyVersion
      and math.max(1, math.floor(policyVersion)) or nil
    a.current.itemPolicy = itemPolicyId(a.current.itemPolicy)
    a.current.itemPolicyVersion = math.max(1, math.floor(
      tonumber(a.current.itemPolicyVersion) or ITEM_POLICY_VERSION))
    local currentNeedsRules = a.current.status == "pending_new_game"
      or a.current.status == "active"
    local currentRulesOk, currentRulesErr = normalizeRules(a.current,
      "Current Legacy journey", currentNeedsRules)
    if not currentRulesOk then return nil, currentRulesErr end
    -- `bankUnlocked=true` was the unconditional access flag before bank
    -- policies existed.  Keep it byte-compatible on those active runs; new
    -- policy-owned runs never use it to bypass their selected gate.
    a.current.bankUnlocked = a.current.bankUnlocked == true
    local avatar = tostring(a.current.avatar or ""):upper()
    a.current.avatar = ({ RED = true, BLUE = true, GREEN = true })[avatar]
      and avatar or nil
    a.current.avatarQuestStage = math.max(0, math.floor(
      tonumber(a.current.avatarQuestStage) or 0))
    a.current.pathComplete = a.current.pathComplete == true
    a.current.partnerChosen = a.current.partnerChosen == true
    if a.current.partnerChosen then
      a.current.partnerSpecies = type(a.current.partnerSpecies) == "string"
        and a.current.partnerSpecies or nil
      a.current.partnerMode = ({ balanced = true, free = true, hoenn = true,
        yellow = true })[
        tostring(a.current.partnerMode or "")] and a.current.partnerMode or nil
      a.current.partnerBall = ({ left = true, catalog = true, yellow = true })[
        tostring(a.current.partnerBall or "")] and a.current.partnerBall or nil
      a.current.partnerChosenAtCycle = math.max(0, math.floor(tonumber(
        a.current.partnerChosenAtCycle) or a.current.cycle or 0))
      a.current.rivalPartner = type(a.current.rivalPartner) == "table"
        and a.current.rivalPartner or nil
    else
      a.current.partnerSpecies, a.current.partnerMode = nil, nil
      a.current.partnerBall, a.current.partnerChosenAtCycle = nil, nil
      a.current.rivalPartner = nil
    end
    if type(a.transaction) ~= "table" then
      a.transaction = nil
    elseif type(a.transaction.hall) == "table" then
      local hall = a.transaction.hall
      hall.itemPolicy = itemPolicyId(hall.itemPolicy)
      hall.itemPolicyVersion = math.max(1, math.floor(
        tonumber(hall.itemPolicyVersion) or ITEM_POLICY_VERSION))
      local txNeedsRules = a.transaction.state == "prepared"
        or a.transaction.state == "committed"
      local txRulesOk, txRulesErr = normalizeRules(hall,
        "Prepared Legacy transaction", txNeedsRules)
      if not txRulesOk then return nil, txRulesErr end
    end
    return a
  end

  local function normalize(raw)
    if type(raw) ~= "table" then return empty() end
    local version = schemaVersion(raw)
    if version > VERSION then
      return nil, ("legacy archive schema %d is newer than supported schema %d")
        :format(version, VERSION), version
    end
    while version < VERSION do
      local migrate = migrations[version]
      if not migrate then
        return nil, "missing legacy archive migration from schema "
          .. tostring(version), version
      end
      migrate(raw)
      local nextVersion = schemaVersion(raw)
      if nextVersion <= version then
        return nil, "legacy archive migration did not advance schema "
          .. tostring(version), version
      end
      version = nextVersion
    end
    return normalizeCurrent(raw)
  end

  local function normalizedBody(value)
    local normalized, normalizeErr = normalize(copy(value))
    if not normalized then return nil, normalizeErr end
    local ok, body = pcall(SaveSerializer.encode, normalized)
    if not ok then return nil, tostring(body) end
    return body, normalized
  end

  local function sameArchive(left, right)
    local leftBody = normalizedBody(left)
    local rightBody = normalizedBody(right)
    return leftBody ~= nil and rightBody ~= nil and leftBody == rightBody
  end

  function A.archiveDigest(value)
    local body, normalizeErr = normalizedBody(value)
    if not body then return nil, normalizeErr end
    return digestText(body)
  end

  local function markFuture(version, path)
    local reason = ("legacy archive %s uses future schema %d; "
      .. "this build is read-only"):format(tostring(path), version)
    A.readOnly = true
    A.futureVersion = version
    A.readOnlyReason = reason
    log:error(reason)
    return reason
  end

  local function clearFuture()
    A.readOnly = false
    A.futureVersion = nil
    A.readOnlyReason = nil
  end

  local function decode(path)
    if not fs.getInfo(path) then return nil, "missing" end
    local bytes = fs.read(path)
    if not bytes then return nil, "unreadable" end
    local value, err = SaveSerializer.decode(bytes)
    if not value then
      log:error("legacy archive parse failed for " .. path .. ": "
        .. tostring(err))
      return nil, "invalid"
    end
    local sourceVersion = schemaVersion(value)
    if sourceVersion > VERSION then
      return nil, "future", value, sourceVersion
    end
    local migrated, migrateErr = normalize(value)
    if not migrated then
      log:error("legacy archive migration failed for " .. path .. ": "
        .. tostring(migrateErr))
      return nil, "invalid"
    end
    return migrated, nil, nil, sourceVersion
  end

  local function ensureDirectory()
    if fs.createDirectory then fs.createDirectory(directory) end
  end

  local function remove(path)
    if fs.remove and fs.getInfo(path) then fs.remove(path) end
  end

  local function writePath(path, value)
    ensureDirectory()
    local ok, err = fs.write(path, SaveSerializer.encode(value))
    if not ok then
      log:error("legacy archive write failed for " .. path .. ": "
        .. tostring(err))
      return false, err
    end
    return true
  end

  function A.write(archive)
    if A.readOnly then return false, A.readOnlyReason end
    local currentArchive, currentStatus, _, currentVersion = decode(filename)
    if currentStatus == "future" then
      return false, markFuture(currentVersion, filename)
    end
    -- If the primary is absent/corrupt, a future witness or backup may be the
    -- only intact copy. Never create an older primary over that evidence.
    if not currentArchive then
      for _, path in ipairs({ witness, backup }) do
        local _, fallbackStatus, _, fallbackVersion = decode(path)
        if fallbackStatus == "future" then
          return false, markFuture(fallbackVersion, path)
        end
      end
    end
    local normalized, normalizeErr, candidateVersion = normalize(copy(archive))
    if not normalized then
      if candidateVersion and candidateVersion > VERSION then
        return false, markFuture(candidateVersion, "write candidate")
      end
      return false, normalizeErr
    end
    archive = normalized
    ensureDirectory()
    local current = fs.getInfo(filename) and fs.read(filename) or nil
    if current then
      local ok, err = fs.write(backup, current)
      if not ok then return false, err end
    end
    local encoded = SaveSerializer.encode(archive)
    local ok, err = fs.write(witness, encoded)
    if not ok then return false, err end
    remove(filename)
    ok, err = fs.write(filename, encoded)
    if not ok then return false, err end
    local verified = decode(filename)
    if not verified then return false, "archive verification failed" end
    remove(witness)
    return true
  end

  function A.load()
    local archive, status, raw, sourceVersion = decode(filename)
    if status == "future" then
      local reason = markFuture(sourceVersion, filename)
      return copy(raw), reason
    end
    if archive then
      clearFuture()
      if sourceVersion < VERSION then
        local migrated, migrateErr = A.write(archive)
        if migrated then
          log:info(("migrated Vermächtnis archive v%d -> v%d")
            :format(sourceVersion, VERSION))
        else
          log:error("legacy archive migration write failed: "
            .. tostring(migrateErr))
        end
      end
      return archive
    end

    local fallbacks = {}
    for _, path in ipairs({ witness, backup }) do
      archive, status, raw, sourceVersion = decode(path)
      if status == "future" then
        local reason = markFuture(sourceVersion, path)
        return copy(raw), reason
      end
      if archive then
        fallbacks[#fallbacks + 1] = archive
      end
    end
    archive = fallbacks[1]
    if archive then
      clearFuture()
      local recovered, recoverErr = A.write(archive)
      if recovered then
        log:info("recovered Vermächtnis archive")
      else
        log:error("legacy archive recovery write failed: "
          .. tostring(recoverErr))
      end
      return archive
    end
    clearFuture()
    return empty()
  end

  local function mutableArchive()
    local archive, err = A.load()
    if A.readOnly then
      return nil, err or A.readOnlyReason or "legacy archive is read-only"
    end
    return archive
  end

  local function storageHasArchive()
    return fs.getInfo(filename) ~= nil
      or fs.getInfo(witness) ~= nil
      or fs.getInfo(backup) ~= nil
  end

  local function storageHasValidArchive()
    for _, path in ipairs({ filename, witness, backup }) do
      if fs.getInfo(path) then
        local archive, status = decode(path)
        if archive or status == "future" then return true end
      end
    end
    return false
  end

  local function saveBucket(save, create)
    if type(save) ~= "table" then return nil end
    if type(save.modData) ~= "table" then
      if not create then return nil end
      save.modData = {}
    end
    local bucket = save.modData[modId]
    if type(bucket) ~= "table" and create then
      bucket = {}
      save.modData[modId] = bucket
    end
    return type(bucket) == "table" and bucket or nil
  end

  local function storageBindingFrom(save)
    local bucket = saveBucket(save, false)
    local raw = bucket and bucket.legacy_storage_binding
    if raw == nil then return nil, nil, false end
    local stamped = type(save and save.meta) == "table"
      and save.meta.playthroughId
    if type(raw) ~= "table" or raw.version ~= STORAGE_BINDING_VERSION
        or raw.scope ~= "playthrough"
        or type(raw.playthroughId) ~= "string" or raw.playthroughId == ""
        or raw.playthroughId:match("^[%w_-]+$") == nil
        or type(raw.archiveDigest) ~= "string"
        or raw.archiveDigest:match("^[0-9a-f]+$") == nil
        or #raw.archiveDigest ~= 16
        or stamped ~= raw.playthroughId then
      return nil, "Legacy storage binding receipt is corrupt or mismatched", true
    end
    return raw, nil, true
  end

  local function freshOriginFrom(save)
    local bucket = saveBucket(save, false)
    local raw = bucket and bucket.legacy_fresh_origin
    if raw == nil then return nil, nil, false end
    local stamped = type(save and save.meta) == "table"
      and save.meta.playthroughId
    if type(raw) ~= "table" or raw.version ~= FRESH_ORIGIN_VERSION
        or raw.edition ~= tostring(save and save.version or edition) then
      return nil, "Legacy fresh-save origin receipt is corrupt or incomplete", true
    end

    -- Stock 0.1.86 playthrough storage needs its opaque id in both the save
    -- and receipt.  The clientfix's official edition storage deliberately has
    -- no playthrough selector, so a genuine save.new_game receipt may have no
    -- id at all.  A present id is still validated and must match exactly;
    -- edition storage never turns a foreign/stale id into fresh authority.
    local stampedPresent = stamped ~= nil
    if stampedPresent and (type(stamped) ~= "string" or stamped == ""
        or stamped:match("^[%w_-]+$") == nil) then
      return nil, "Legacy fresh-save origin receipt is corrupt or incomplete", true
    end
    local receiptId = raw.playthroughId
    if receiptId ~= nil and (type(receiptId) ~= "string" or receiptId == ""
        or receiptId:match("^[%w_-]+$") == nil) then
      return nil, "Legacy fresh-save origin receipt is corrupt or incomplete", true
    end
    if not stampedPresent and not editionScoped then
      return nil, "Legacy fresh-save origin receipt is corrupt or incomplete", true
    end
    if receiptId == nil and stampedPresent then
      raw.playthroughId = stamped
      receiptId = stamped
    end
    if receiptId ~= stamped then
      return nil, "Legacy fresh-save origin receipt belongs to another playthrough", true
    end
    return raw, nil, true
  end

  local function localRunId(save)
    local bucket = saveBucket(save, false)
    local run = bucket and bucket.legacy_journey
    return type(run) == "table" and type(run.runId) == "string"
      and run.runId ~= "" and run.runId or nil
  end

  local function sourceProofDigest(save)
    local binding = storageBindingFrom(save)
    local fresh = freshOriginFrom(save)
    local playthroughId = type(save and save.meta) == "table"
      and save.meta.playthroughId or nil
    local saveDigest
    if type(playthroughId) ~= "string" or playthroughId == "" then
      -- Edition storage can legitimately import a pre-0.1.86 save that has no
      -- playthrough id. In that one case, bind retry authority to the complete
      -- durable source save instead of falling back to the 16-bit trainer id.
      local saveOk, saveBody = pcall(SaveSerializer.encode, save)
      if not saveOk then return nil, tostring(saveBody) end
      saveDigest = digestText(saveBody)
    end
    local payload = {
      edition = tostring(save and save.version or edition),
      playthroughId = playthroughId,
      playerId = save and save.player and save.player.id or 0,
      runId = localRunId(save),
      bindingDigest = binding and binding.archiveDigest or nil,
      freshOrigin = fresh and fresh.version or nil,
      saveDigest = saveDigest,
    }
    local ok, body = pcall(SaveSerializer.encode, payload)
    if not ok then return nil, tostring(body) end
    return digestText(body)
  end

  function A.markFreshOrigin(save)
    if type(save) ~= "table" then return false, "fresh save is missing" end
    local bucket = saveBucket(save, true)
    if bucket.legacy_storage_binding ~= nil then return false, "already bound" end
    local marker = type(bucket.legacy_fresh_origin) == "table"
      and bucket.legacy_fresh_origin or {
        version = FRESH_ORIGIN_VERSION,
        edition = tostring(save.version or edition),
      }
    bucket.legacy_fresh_origin = marker
    local stamped = type(save.meta) == "table" and save.meta.playthroughId
    if type(stamped) == "string" and stamped ~= "" then
      marker.playthroughId = marker.playthroughId or stamped
      if marker.playthroughId ~= stamped then
        return false, "fresh save identity changed after creation"
      end
    end
    return true
  end

  function A.storageBinding(save)
    local binding, bindingErr, present = storageBindingFrom(save)
    return binding and copy(binding) or nil, bindingErr, present
  end

  function A.stampStorageBinding(save, context)
    if type(context) ~= "table"
        or type(context.playthroughId) ~= "string"
        or context.playthroughId == ""
        or context.playthroughId:match("^[%w_-]+$") == nil then
      return false, "official storage did not provide a playthrough identity"
    end
    local stamped = type(save and save.meta) == "table"
      and save.meta.playthroughId
    if stamped ~= context.playthroughId then
      return false, "save and official storage playthrough identities disagree"
    end
    local archive, loadErr = A.load()
    if not archive or A.readOnly then
      return false, loadErr or A.readOnlyReason or "Legacy archive is unavailable"
    end
    local archiveDigest, digestErr = A.archiveDigest(archive)
    if not archiveDigest then return false, digestErr end
    local bucket = saveBucket(save, true)
    bucket.legacy_fresh_origin = nil
    bucket.legacy_storage_binding = {
      version = STORAGE_BINDING_VERSION,
      scope = "playthrough",
      playthroughId = context.playthroughId,
      archiveDigest = archiveDigest,
    }
    return true
  end

  local function handoffFrom(save)
    local bucket = saveBucket(save, false)
    local handoff = bucket and bucket.legacy_lineage_handoff
    return type(handoff) == "table" and handoff or nil
  end

  local function hasEntries(value)
    return type(value) == "table" and next(value) ~= nil
  end

  local function hasMeaningfulEntries(value)
    if type(value) ~= "table" then return false end
    for _, child in pairs(value) do
      if child == true or type(child) == "string" and child ~= ""
          or type(child) == "number" and child > 0
          or type(child) == "table" and next(child) ~= nil then
        return true
      end
    end
    return false
  end

  -- Pre-sandbox archives may contain the only union of several completed
  -- journeys even when the current progress save predates `legacy_journey`
  -- run ids. Johto Masters and HEVO history are strong witnesses that an old
  -- external archive may exist. Never initialize an empty scoped archive over
  -- that evidence; a verified engine/offline import creates storage first.
  local function hasLegacyHistory(save)
    local bucket = saveBucket(save, false)
    if type(bucket) ~= "table" then return false end
    if type(bucket.legacy_journey) == "table" then return true end
    local masters = bucket.johto_masters
    if type(masters) == "table" then
      for _, key in ipairs({ "clears", "gifts", "connectedClears",
          "journeyClears", "runSerial", "rewardedRunSerial",
          "cadenceSerial" }) do
        if (tonumber(masters[key]) or 0) > 0 then return true end
      end
      for _, key in ipairs({ "title", "goldenTrainerCardDecor",
          "activeRun" }) do
        if masters[key] == true then return true end
      end
      if masters.pendingGift ~= nil or masters.lastHallTicket ~= nil
          or masters.runTicket ~= nil or hasEntries(masters.passages) then
        return true
      end
    end
    local hevo = bucket.hevo_persistent
    if type(hevo) == "table" then
      for _, key in ipairs({ "meta", "packageUnlocks", "evolutionUnlocks",
          "permanentItems", "firstGrants", "pendingItems", "dex",
          "questionIds", "secretUnlocks" }) do
        if hasMeaningfulEntries(hevo[key]) then return true end
      end
    end
    return false
  end

  local function pendingSourceOwned(archive, save)
    local current = type(archive and archive.current) == "table"
      and archive.current or {}
    local tx = type(archive and archive.transaction) == "table"
      and archive.transaction or nil
    if current.status ~= "pending_new_game" or not tx
        or tx.id ~= current.runId or tx.state ~= "committed"
        or type(tx.source) ~= "table" then return false end

    local source = tx.source
    local stamped = type(save and save.meta) == "table"
      and save.meta.playthroughId or nil
    local runId = localRunId(save)
    if tostring(source.edition) ~= tostring(save and save.version or edition)
        or tonumber(source.playerId or 0)
          ~= tonumber(save and save.player and save.player.id or 0) then
      return false
    end

    if source.proofDigest then
      local proof = sourceProofDigest(save)
      local identityMatches = source.playthroughId == stamped
      if enforceLegacyMigrationGuard and not editionScoped then
        identityMatches = type(stamped) == "string" and stamped ~= ""
          and identityMatches
      end
      return identityMatches
        and source.runId == runId
        and proof ~= nil and source.proofDigest == proof
    end

    -- Compatibility for a transaction committed by the immediately previous
    -- build: its full rollback capsule still carries the engine-issued opaque
    -- playthrough id and predecessor run id. Trainer id alone is never enough.
    local rollback = type(archive.lastRollback) == "table"
      and archive.lastRollback or nil
    local rollbackSave = rollback and rollback.transactionId == tx.id
      and rollback.save or nil
    local rollbackStamped = type(rollbackSave and rollbackSave.meta) == "table"
      and rollbackSave.meta.playthroughId
    return type(stamped) == "string" and stamped ~= ""
      and rollbackStamped == stamped
      and localRunId(rollbackSave) == runId
      and tostring(rollbackSave and rollbackSave.version or edition)
        == tostring(save and save.version or edition)
  end

  local function archiveOwnedBySave(archive, save)
    local expectedRunId = localRunId(save)
    local current = type(archive and archive.current) == "table"
      and archive.current or {}
    local actualRunId = type(current.runId) == "string"
      and current.runId ~= "" and current.runId or nil
    if pendingSourceOwned(archive, save) then return true, "pending_retry" end
    if expectedRunId then
      if actualRunId == expectedRunId then return true, "active_run" end
      return false, "Legacy archive belongs to a different active run"
    end
    if actualRunId then
      return false, "Legacy archive contains a run that this save cannot prove"
    end
    return true, "unstarted_archive"
  end

  local function normalizeHandoff(handoff)
    if type(handoff) ~= "table"
        or math.floor(tonumber(handoff.version) or 0) ~= HANDOFF_VERSION then
      return nil, "unsupported Legacy lineage handoff"
    end
    local archive, err, candidateVersion = normalize(copy(handoff.archive))
    if not archive then
      return nil, err or ("invalid Legacy archive schema "
        .. tostring(candidateVersion))
    end
    local current = type(archive.current) == "table" and archive.current or {}
    if type(handoff.runId) ~= "string" or handoff.runId == ""
        or current.runId ~= handoff.runId
        or current.status ~= "pending_new_game"
        or math.floor(tonumber(current.cycle) or -1)
          ~= math.floor(tonumber(handoff.cycle) or -2) then
      return nil, "Legacy lineage handoff does not match its pending run"
    end
    if archive.appliedTransactions[handoff.runId] ~= true then
      return nil, "Legacy lineage transaction was not committed"
    end
    return archive
  end

  local function handoffTargetMatches(existing, incoming)
    if sameArchive(existing, incoming) then return true, "pending" end
    local existingCurrent = type(existing and existing.current) == "table"
      and existing.current or {}
    if existingCurrent.status ~= "active" then return false end

    -- The only legal pre-existing target on an idempotent retry is the exact
    -- result of markRunStarted(): one timestamp is nondeterministic, while all
    -- Bank/JM/HEVO/title/history data must remain byte-semantically identical.
    local expected = copy(incoming)
    expected.current.status = "active"
    expected.current.startedAt = expected.current.startedAt
      or existingCurrent.startedAt
    expected.lastTransaction = copy(expected.transaction)
    expected.transaction = nil
    if sameArchive(existing, expected) then return true, "active" end
    return false
  end

  function A.storageHasArchive()
    return storageHasArchive()
  end

  function A.hasHandoff(save)
    return handoffFrom(save) ~= nil
  end

  function A.lineageStatus(save)
    local binding, bindingErr, bindingPresent = storageBindingFrom(save)
    if bindingPresent and not binding then return false, bindingErr end
    local handoff = handoffFrom(save)
    if handoff then
      local incoming, incomingErr = normalizeHandoff(handoff)
      if not incoming then return false, incomingErr end
      -- A capsule is normally transient and can never reach progress storage.
      -- If a copied/crash-recovered save nevertheless presents one, inspect
      -- its target scope before save.loaded reconciliation is allowed to touch
      -- anything. Only an empty scope or the exact pending/active transform is
      -- part of this lineage.
      local physicalTarget = storageHasArchive()
      local validTarget = storageHasValidArchive()
      if physicalTarget and not validTarget then
        return false, "Legacy handoff target contains only corrupt generations"
      end
      if validTarget then
        local target, targetErr = A.load()
        if not target or not handoffTargetMatches(target, incoming) then
          return false, targetErr
            or "Legacy handoff target belongs to a different lineage"
        end
      end
      return true, "handoff"
    end

    -- Stock playthrough storage allocates an opaque id on first access. An
    -- unstamped old save with Legacy/JM/HEVO history must be rejected before
    -- even probing that scope, otherwise the probe itself could make it look
    -- freshly initialized. Edition storage has no per-save allocation and may
    -- safely perform its engine-owned import while being inspected.
    local stamped = type(save and save.meta) == "table"
      and save.meta.playthroughId
    if enforceLegacyMigrationGuard and not editionScoped
        and (type(stamped) ~= "string" or stamped == "")
        and hasLegacyHistory(save) then
      return false,
        "This save contains pre-sandbox Legacy history but no verified scoped "
          .. "archive. Run the verified offline Legacy migration first."
    end

    -- Presence alone is not authority: Stock 0.1.86 can leave a short-written
    -- main/tmp/bak generation behind.  Treat corrupt-only storage as evidence
    -- of a damaged archive, never as permission to initialize an empty one.
    local physicalArchive = storageHasArchive()
    local validArchive = storageHasValidArchive()
    if bindingPresent and not validArchive then
      return false,
        "This save has a verified Legacy storage binding, but every archive "
          .. "generation is missing or corrupt. Restore or migrate the "
          .. "archive before continuing."
    end

    if physicalArchive and not validArchive then
      return false,
        "Legacy archive storage exists, but every generation is corrupt. "
          .. "Restore a verified archive before continuing."
    end

    if validArchive then
      local stored, storedErr = A.load()
      if not stored then
        return false, storedErr or "Legacy archive cannot be read"
      end
      local owned, ownership = archiveOwnedBySave(stored, save)
      if not owned then return false, ownership end

      -- A syntactically valid but empty playthrough archive is not lineage
      -- authority by itself. Stock 0.1.86 may allocate/write that scope while
      -- inspecting an older stamped save; accepting `unstarted_archive` here
      -- would then let historical JM/HEVO/title progress start a replacement
      -- lineage. A genuine first campaign carries the save.new_game origin
      -- receipt, while an offline migration carries a storage binding.
      -- Edition storage remains engine-owned and deliberately exempt.
      if enforceLegacyMigrationGuard and not editionScoped
          and ownership == "unstarted_archive" and not bindingPresent then
        local fresh, freshErr, freshPresent = freshOriginFrom(save)
        if freshPresent then
          if not fresh then return false, freshErr end
          return true, "verified_first_journey"
        end
        return false, hasLegacyHistory(save)
          and "This save contains Legacy history but no verified scoped "
            .. "archive binding. Run the verified offline Legacy migration "
            .. "first."
          or "This save has no verified fresh origin or Legacy archive "
            .. "binding. Create it through New Game or migrate its archive "
            .. "first."
      end
      return true, bindingPresent and "storage_binding" or ownership
    end

    if localRunId(save) then
      return false,
        "This save expects a Legacy archive that is not present in its "
          .. (editionScoped and "edition storage. "
            or "playthrough storage. ")
          .. (editionScoped and "Use the verified Legacy migration "
            or "Use the verified offline Legacy migration ")
          .. "before continuing."
    end

    local fresh, freshErr, freshPresent = freshOriginFrom(save)
    if freshPresent then
      if not fresh then return false, freshErr end
      return true, "verified_first_journey"
    end

    if enforceLegacyMigrationGuard then
      if hasLegacyHistory(save) then
        return false, editionScoped
          and "This save contains Legacy history but no verified edition "
            .. "archive. Import it before continuing."
          or "This save contains pre-sandbox Legacy history but no verified "
            .. "scoped archive. Run the verified offline Legacy migration first."
      end
      return false,
        "This save has no verified fresh origin or Legacy archive binding. "
          .. "Create it through New Game or migrate its archive first."
    end
    return true, "first_journey"
  end

  -- Copy the already committed source archive into the new opaque
  -- playthrough scope.  A pre-existing different target is never overwritten:
  -- that would join two unrelated lineages merely because a save was copied.
  function A.importHandoff(save)
    local handoff = handoffFrom(save)
    if not handoff then return true, "none" end
    local incoming, incomingErr = normalizeHandoff(handoff)
    if not incoming then return false, incomingErr end

    if storageHasArchive() then
      local existing, existingErr = A.load()
      local matches = existing and handoffTargetMatches(existing, incoming)
      if not matches then
        return false, existingErr
          or "target playthrough contains a non-identical Legacy lineage"
      end
    else
      local written, writeErr = A.write(incoming)
      if not written then return false, writeErr end
    end

    local verified, verifyErr = A.load()
    if not verified or not handoffTargetMatches(verified, incoming) then
      return false, verifyErr
        or "target Legacy lineage full-payload verification failed"
    end
    handoff.targetVerified = true
    return true
  end

  -- The capsule stays attached until both the target archive and its active
  -- run marker were independently read back.  Callers remove it before the
  -- first normal save; if anything earlier fails, the old on-disk save remains
  -- the retry point and the in-memory capsule remains intact.
  function A.finishHandoff(save)
    local handoff = handoffFrom(save)
    if not handoff then return true, "none" end
    if handoff.targetVerified ~= true then
      return false, "target Legacy lineage was not verified"
    end
    local verified, verifyErr = A.load()
    local current = verified and verified.current or {}
    if not verified or current.runId ~= handoff.runId
        or current.status ~= "active" then
      return false, verifyErr or "target Legacy run is not active"
    end
    local bucket = saveBucket(save, false)
    bucket.legacy_lineage_handoff = nil
    return true
  end

  local function boxesFrom(save)
    if type(save.boxes) == "table" then return save.boxes end
    if type(save.box) == "table" then return { save.box } end
    return {}
  end

  local function registryGet(registry, id)
    if type(registry) ~= "table" or type(id) ~= "string" then return nil end
    if registry[id] ~= nil then return registry[id] end
    if type(registry.get) == "function" then
      local ok, value = pcall(registry.get, registry, id)
      if ok then return value end
    end
    return nil
  end

  local function classifyItem(id)
    id = tostring(id or "")
    local category, def, lockReason
    if isBadge(id) then
      category = "badge"
    elseif id == "FIELD_KIT" then
      category = "field_kit"
    elseif id == "MEGA_RING" or id == "MEGA_STONE_CASE" then
      category = "mega_access"
    elseif MEGA_STONE_IDS[id] then
      category = "mega_stone"
    elseif id:find("^HM_") then
      category = "hm"
    elseif STORY_ITEM_IDS[id] then
      category = "key_item"
    elseif registryValidation then
      def = registryGet(registries.items, id)
      if not def then
        category = "unknown"
        lockReason = "unregistered_item"
      elseif type(def.machine) == "table" and def.machine.kind == "HM" then
        category = "hm"
      elseif type(def.machine) == "table" and def.machine.kind == "TM" then
        category = "tm"
      elseif COUNTED_NON_TOSSABLE_IDS[id] then
        category = "consumable"
      elseif def.tossable == false then
        -- Registered but not yet reviewed. Fail closed without pretending it
        -- is a Key Item: a future mod can explicitly add it to either list.
        category = "unknown"
        lockReason = "unclassified_non_tossable"
      else
        category = "consumable"
      end
    else
      -- Compatibility-only archive doubles predate registry binding. The
      -- well-known story identities still fail closed; other ids retain the
      -- old counted-item behavior until production binds the full Data set.
      category = "consumable"
    end
    local base = ITEM_POLICY_CATEGORIES[category]
    return {
      id = id,
      category = category,
      transferable = base.transferable == true,
      claimMode = base.claimMode,
      summary = base.summary,
      lockReason = lockReason,
      legacySouvenir = LEGACY_PATH_MEGA_STONES[id] == true,
      definition = def,
    }
  end

  local function itemReason(id)
    local policy = classifyItem(id)
    if policy.transferable then return nil end
    if policy.category == "unknown" then return "unknown_item" end
    if policy.category == "badge" then return "badge" end
    return "story_item"
  end

  local function monReason(mon)
    if not registryValidation then return nil end
    if type(mon) ~= "table" or not registryGet(registries.pokemon, mon.species) then
      return "unknown_species"
    end
    for _, move in ipairs(type(mon.moves) == "table" and mon.moves or {}) do
      local id = type(move) == "table" and move.id or move
      if type(id) ~= "string" or not registryGet(registries.moves, id) then
        return "unknown_move:" .. tostring(id)
      end
    end
    return nil
  end

  local function quarantineItem(archive, id, count, reason)
    count = math.max(0, math.floor(tonumber(count) or 0))
    if count == 0 or reason == "badge" or reason == "story_item" then return end
    local previous = archive.quarantine.items[id]
    local previousCount = type(previous) == "table" and previous.count
      or tonumber(previous) or 0
    archive.quarantine.items[id] = {
      count = previousCount + count,
      reason = reason or "unknown_item",
    }
  end

  -- Fail closed at every archive payout boundary. Content from a temporarily
  -- removed mod stays byte-complete in quarantine and is restored
  -- automatically once all of its registry IDs exist again. Story items and
  -- HMs deliberately never become transferable across a fresh story.
  local function reconcileRegistry(archive)
    if not registryValidation then return false end
    archive.quarantine = type(archive.quarantine) == "table"
      and archive.quarantine or { bank = {}, items = {} }
    archive.quarantine.bank = type(archive.quarantine.bank) == "table"
      and archive.quarantine.bank or {}
    archive.quarantine.items = type(archive.quarantine.items) == "table"
      and archive.quarantine.items or {}
    local changed, kept, knownIds = false, {}, {}
    for _, row in ipairs(archive.bank or {}) do
      local reason = monReason(row and row.mon)
      if reason then
        local id = type(row) == "table" and row.id
          or ("QUARANTINE:%d"):format(#kept + 1)
        archive.quarantine.bank[id] = {
          row = copy(row), reason = reason,
        }
        changed = true
      else
        kept[#kept + 1] = row
        if type(row) == "table" and row.id then knownIds[row.id] = true end
      end
    end
    archive.bank = kept
    for id, held in pairs(archive.quarantine.bank) do
      local row = type(held) == "table" and held.row or nil
      if row and not monReason(row.mon) then
        if not knownIds[row.id] then
          archive.bank[#archive.bank + 1] = copy(row)
          knownIds[row.id] = true
        end
        archive.quarantine.bank[id] = nil
        changed = true
      end
    end
    for id, count in pairs(archive.locker.items or {}) do
      local policy = classifyItem(id)
      if policy.claimMode == "unique_after_mega_access"
          and tonumber(count) and tonumber(count) > 1 then
        archive.locker.items[id] = 1
        count = 1
        changed = true
      end
      local reason = itemReason(id)
      if reason then
        archive.locker.items[id] = nil
        if reason == "unknown_item" then
          quarantineItem(archive, id, count, reason)
        end
        changed = true
      end
    end
    for id, held in pairs(archive.quarantine.items) do
      local count = type(held) == "table" and held.count or tonumber(held)
      local heldReason = type(held) == "table" and held.reason or "unknown_item"
      local currentReason = itemReason(id)
      if heldReason == "unknown_item" and currentReason == nil and count and count > 0 then
        archive.locker.items[id] = (archive.locker.items[id] or 0) + count
        archive.quarantine.items[id] = nil
        changed = true
      elseif currentReason and currentReason ~= "unknown_item"
          or heldReason == "story_item" or heldReason == "badge" then
        -- Old RC previews could strand story items in either the locker or
        -- quarantine. Drop them: the current journey's authored grant remains
        -- their sole authority.
        archive.quarantine.items[id] = nil
        changed = true
      end
    end
    return changed
  end

  local function daycareBlockers(save)
    local blockers = {}
    local vanilla = type(save) == "table" and save.daycare or nil
    if type(vanilla) == "table" and type(vanilla.mon) == "table" then
      blockers[#blockers + 1] = "a Pokémon is still in the Day-Care"
    end
    local bucket = type(save and save.modData) == "table" and save.modData[modId]
    local plus = type(bucket) == "table" and bucket.daycare_plus or nil
    if type(plus) == "table" then
      local parents = 0
      for _, row in pairs(type(plus.parents) == "table" and plus.parents or {}) do
        if type(row) == "table" and (type(row.mon) == "table" or row.species) then
          parents = parents + 1
        end
      end
      if parents > 0 then
        blockers[#blockers + 1] = ("%d Day-Care Plus parent%s must be collected")
          :format(parents, parents == 1 and "" or "s")
      end
      local reserved = 0
      for _, row in pairs(type(plus.reservedEggs) == "table"
          and plus.reservedEggs or {}) do
        if type(row) == "table" and row.species then reserved = reserved + 1 end
      end
      if reserved > 0 then
        blockers[#blockers + 1] = ("%d reserved Day-Care egg%s must be claimed")
          :format(reserved, reserved == 1 and "" or "s")
      end
    end
    return blockers
  end

  local function sourceId(save, targetCycle)
    local player = type(save.player) == "table" and save.player or {}
    return table.concat({
      tostring(save.version or edition),
      tostring(player.id or 0),
      tostring(targetCycle),
    }, ":")
  end

  local function payloadFrom(save, archive, transferPolicy)
    transferPolicy = itemPolicyId(transferPolicy)
    local mons = {}
    local quarantinedMons = {}
    local function addMon(mon)
      local reason = monReason(mon)
      if reason then
        quarantinedMons[#quarantinedMons + 1] = {
          mon = copy(mon), reason = reason,
        }
      else
        mons[#mons + 1] = copy(mon)
      end
    end
    for _, mon in ipairs(save.party or {}) do
      addMon(mon)
    end
    for _, box in ipairs(boxesFrom(save)) do
      for _, mon in ipairs(box or {}) do addMon(mon) end
    end
    local items = {}
    local function add(store)
      for id, count in pairs(store or {}) do
        count = math.max(0, math.floor(tonumber(count) or 0))
        local reason = itemReason(id)
        if count > 0 and reason == nil then
          items[id] = (items[id] or 0) + count
        elseif count > 0 and archive then
          quarantineItem(archive, id, count, reason)
        end
      end
    end
    if transferPolicy == "safe" then
      add(save.inventory)
      add(save.pcItems)
    end
    local function carryPathMegaStones(store)
      for id in pairs(LEGACY_PATH_MEGA_STONES) do
        local owned = type(store) == "table" and store[id] or nil
        if owned == true or (tonumber(owned) or 0) > 0 then
          items[id] = 1
        end
      end
    end
    -- Mega Stones are not normally Bag counts in Ascendant. Their current-
    -- run source of truth is the Stone Case table. SAFE projects every owned
    -- official stone; EMPTY projects only the three earned Hoenn souvenirs.
    local bucket = type(save.modData) == "table" and save.modData[modId]
    local mega = type(bucket) == "table" and bucket.mega_evolution
    local stones = type(mega) == "table" and mega.stones
    for id, owned in pairs(type(stones) == "table" and stones or {}) do
      if owned == true and MEGA_STONE_IDS[id]
          and (transferPolicy == "safe" or LEGACY_PATH_MEGA_STONES[id]) then
        items[id] = 1
      end
    end
    -- RC and imported saves may still retain a reviewed Stone in Bag/PC or
    -- only in the durable HEVO secret ledger. Accept those exact authored
    -- witnesses for the three souvenirs, still collapsing each to one.
    carryPathMegaStones(save.inventory)
    carryPathMegaStones(save.pcItems)
    local savePersistent = type(bucket) == "table"
      and bucket.hevo_persistent and bucket.hevo_persistent.permanentItems
    carryPathMegaStones(savePersistent)
    local permanent = archive and archive.hevoPersistent
      and archive.hevoPersistent.permanentItems
    carryPathMegaStones(permanent)
    return {
      mons = mons,
      quarantinedMons = quarantinedMons,
      items = items,
      itemPolicy = transferPolicy,
      money = math.max(0, math.floor(tonumber(save.money) or 0)),
    }
  end

  local function currentCharacter(save)
    local bucket = type(save.modData) == "table" and save.modData[modId]
    local chars = type(bucket) == "table" and bucket.extended_characters
    return type(chars) == "table" and chars.player_character or nil
  end

  local function mergeSet(target, source)
    for key, value in pairs(source or {}) do
      if value == true or (type(value) == "number" and value > 0) then
        target[key] = value
      end
    end
  end

  -- Package-3 compatibility seam. Only explicitly permanent HEVO metadata
  -- crosses a Legacy reset; puzzle/statue/run-complete state is intentionally
  -- absent and therefore starts clean in every new journey.
  local function mergeHevoPersistent(archive, save)
    local persistent = archive.hevoPersistent
    local flags = type(save.flags) == "table" and save.flags or {}
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      if flags["HEVO_META_" .. key] == true then persistent.meta[key] = true end
    end
    local bucket = type(save.modData) == "table" and save.modData[modId]
    local source = type(bucket) == "table" and bucket.hevo_persistent
    if type(source) == "table" then
      for _, key in ipairs({ "packageUnlocks", "evolutionUnlocks",
        "permanentItems", "firstGrants", "dex", "questionIds",
        "secretUnlocks" }) do
        mergeSet(persistent[key], source[key])
      end
      -- Pending grants are a queue, not an unlock set: a successful claim
      -- must be able to clear an archived count instead of monotonic-merging
      -- the item back forever.
      persistent.pendingItems = copy(type(source.pendingItems) == "table"
        and source.pendingItems or {})
    end
  end

  -- Preserve the Johto Masters controller exactly at the Legacy boundary.
  -- v3 controller states carry a monotonic cadenceSerial.  That freshness
  -- token matters because a new shiny-farm run intentionally resets Gold,
  -- Kris and Silver from cleared back to locked/unlocked; the old purely
  -- monotonic passage merge would resurrect the previous run and remove the
  -- BLITZ host again.  Lifetime totals remain monotonic, while the newest
  -- cadence snapshot owns the current journey/run checkpoint exactly.
  local function mergeJohtoMastersPersistent(archive, save)
    local target = archive.johtoMastersPersistent
    local bucket = type(save.modData) == "table" and save.modData[modId]
    local source = type(bucket) == "table" and bucket.johto_masters
    if type(source) ~= "table" then return end
    local archivedGiftCount = math.max(0,
      math.floor(tonumber(target.gifts) or 0))
    local liveGiftCount = math.max(0,
      math.floor(tonumber(source.gifts) or 0))
    target.clears = math.max(target.clears or 0,
      math.max(0, math.floor(tonumber(source.clears) or 0)))
    target.gifts = math.max(archivedGiftCount, liveGiftCount)
    target.title = target.title == true or source.title == true
    target.goldenTrainerCardDecor = target.goldenTrainerCardDecor == true
      or source.title == true or source.goldenTrainerCardDecor == true
    target.connectedClears = math.max(
      math.max(0, math.floor(tonumber(target.connectedClears) or 0)),
      math.max(0, math.floor(tonumber(source.connectedClears) or 0)))
    local sourceCadence = math.max(0,
      math.floor(tonumber(source.cadenceVersion) or 0))
    local sourceSerial = math.max(0,
      math.floor(tonumber(source.cadenceSerial) or 0))
    local targetSerial = math.max(0,
      math.floor(tonumber(target.cadenceSerial) or 0))
    local cadenceFresh = sourceCadence >= 1 and sourceSerial >= targetSerial
    if cadenceFresh then
      target.cadenceVersion = sourceCadence
      target.cadenceSerial = sourceSerial
      target.journeyClears = math.max(0,
        math.floor(tonumber(source.journeyClears) or 0))
      target.activeRun = source.activeRun == true
      target.runSerial = math.max(target.connectedClears,
        math.floor(tonumber(source.runSerial) or 0))
      target.rewardedRunSerial = math.max(0, math.min(target.runSerial,
        math.floor(tonumber(source.rewardedRunSerial) or 0)))
      target.cadenceOwner = type(source.cadenceOwner) == "string"
        and source.cadenceOwner or nil
      target.lastHallTicket = tonumber(source.lastHallTicket)
        and math.max(0, math.floor(source.lastHallTicket)) or nil
      target.runTicket = tonumber(source.runTicket)
        and math.max(0, math.floor(source.runTicket)) or nil
    end
    if type(source.pendingGift) == "table" then
      target.pendingGift = copy(source.pendingGift)
    elseif cadenceFresh or liveGiftCount > archivedGiftCount then
      -- A successful exact-once delivery clears the archived pending row;
      -- only the incremented delivery counter may erase it, so an older or
      -- same-generation save can never erase a newer pending transaction.
      target.pendingGift = nil
    end
    target.passages = type(target.passages) == "table" and target.passages or {}
    if cadenceFresh then
      target.passages = copy(type(source.passages) == "table"
        and source.passages or {})
      return
    end
    local rank = { locked = 0, unlocked = 1, entered = 2, cleared = 3 }
    for _, key in ipairs({ "silver", "kris", "gold" }) do
      local live = type(source.passages) == "table" and source.passages[key]
      if type(live) == "table" then
        local saved = type(target.passages[key]) == "table"
          and target.passages[key] or {}
        local liveStatus = live.status == "rewarded" and "cleared"
          or rank[live.status] and live.status or "locked"
        local savedStatus = saved.status == "rewarded" and "cleared"
          or rank[saved.status] and saved.status or "locked"
        saved.status = rank[liveStatus] > rank[savedStatus]
          and liveStatus or savedStatus
        saved.attempts = math.max(0, math.floor(tonumber(saved.attempts) or 0),
          math.floor(tonumber(live.attempts) or 0))
        saved.puzzle = saved.puzzle == true or live.puzzle == true
        saved.rewarded = saved.rewarded == true or live.rewarded == true
          or live.status == "rewarded"
        saved.clue = saved.clue == true or live.clue == true
        saved.step = math.max(0, math.min(3, math.max(
          math.floor(tonumber(saved.step) or 0),
          math.floor(tonumber(live.step) or 0))))
        saved.resets = math.max(0,
          math.floor(tonumber(saved.resets) or 0),
          math.floor(tonumber(live.resets) or 0))
        target.passages[key] = saved
      end
    end
  end

  local function titleUnlocked(archive, id)
    if type(id) ~= "string" then return false end
    if achievementTitleIds[id] then
      return archive.titles.unlocked[id] == true
    end
    local progress = legacyTitleProgress[id]
    if progress == "PASS" then return archive.legacyPass == true end
    return progress ~= nil and archive.completedPaths[progress] == true
  end

  local function mergeTitleState(archive, save)
    local bucket = type(save.modData) == "table" and save.modData[modId]
    local ascendant = type(bucket) == "table" and bucket.ascendant
    local hall = type(bucket) == "table" and bucket.legacy_hall
    local source = type(ascendant) == "table" and ascendant.achievements
    for id, unlocked in pairs(type(source) == "table" and source or {}) do
      id = tostring(id)
      if unlocked == true and achievementTitleIds[id] then
        archive.titles.unlocked[id] = true
      end
    end

    -- The Legacy Gallery is authoritative, while ascendant.selectedTitle is
    -- retained as the migration fallback used by older saves. If either field
    -- contains a real, unlocked title it wins; unknown/locked IDs are never
    -- copied into the durable archive.
    local candidates = {
      { id = type(hall) == "table" and hall.selectedTitle or nil },
      { id = type(ascendant) == "table" and ascendant.selectedTitle or nil },
    }
    local selected
    for _, candidate in ipairs(candidates) do
      local id = candidate.id
      if type(id) == "string" then
        if titleUnlocked(archive, id) then selected = id break end
      end
    end
    if selected then
      archive.titles.selectedTitle = selected
    elseif not titleUnlocked(archive, archive.titles.selectedTitle) then
      archive.titles.selectedTitle = nil
    end
    -- Invalid or stale local IDs are ignored. They must not erase a valid
    -- durable archive selection. There is intentionally no implicit clear:
    -- neither legacy_hall nor ascendant currently exposes an explicit
    -- "no title" action that could be distinguished from missing old data.
  end

  local function seedTitleState(bucket, archive)
    local ascendant = type(bucket.ascendant) == "table"
      and bucket.ascendant or {}
    bucket.ascendant = ascendant
    local unlocked = {}
    for id, value in pairs(type(ascendant.achievements) == "table"
        and ascendant.achievements or {}) do
      if value == true and achievementTitleIds[tostring(id)] then
        unlocked[tostring(id)] = true
      end
    end
    mergeSet(unlocked, archive.titles.unlocked)
    ascendant.achievements = unlocked

    local selected = titleUnlocked(archive, archive.titles.selectedTitle)
      and archive.titles.selectedTitle or nil
    ascendant.selectedTitle = selected
    if not (achievementTitleIds[ascendant.latestAchievement]
        and unlocked[ascendant.latestAchievement] == true) then
      ascendant.latestAchievement = nil
    end

    local hall = type(bucket.legacy_hall) == "table"
      and bucket.legacy_hall or {}
    if math.max(1, math.floor(tonumber(hall.version) or 1)) > 1 then
      -- The new save already carries a Gallery schema from a newer build.
      -- Ascendant's known state was seeded above, but this table is foreign
      -- and must remain byte-for-byte untouched.
      return
    end
    bucket.legacy_hall = hall
    hall.version = 1
    hall.selectedTitle = selected
  end

  local function hallEntry(save, meta, cycle)
    meta = type(meta) == "table" and meta or {}
    local selectedPact = pactId(meta.pact)
    local selectedBankPolicy = bankPolicyId(meta.bankPolicy, selectedPact)
    local selectedItemPolicy = itemPolicyId(meta.itemPolicy)
    local hall = type(save.hallOfFame) == "table" and save.hallOfFame or {}
    local winning = hall[#hall]
    return {
      cycle = cycle,
      edition = tostring(save.version or edition),
      playerName = save.player and save.player.name or nil,
      rivalName = save.player and save.player.rival or nil,
      playerAvatar = meta.playerAvatar or currentCharacter(save),
      starter = meta.starter,
      partnerMode = meta.partnerMode,
      rivalPartner = copy(meta.rivalPartner),
      pact = selectedPact,
      bankPolicy = selectedBankPolicy,
      itemPolicy = selectedItemPolicy,
      itemPolicyVersion = ITEM_POLICY_VERSION,
      runRules = copy(meta.runRules),
      time = copy(save.time or save.playTime),
      championTeam = copy(winning or save.party or {}),
      completedAt = now(),
    }
  end

  local function bankIndex(archive)
    local result = {}
    for index, row in ipairs(archive.bank) do
      if type(row) == "table" and row.id then result[row.id] = index end
    end
    return result
  end

  local function applyPrepared(archive)
    local tx = archive.transaction
    if type(tx) ~= "table" then return archive end
    if archive.appliedTransactions[tx.id] then
      tx.state = "committed"
      return archive
    end

    local byId = bankIndex(archive)
    for index, held in ipairs(tx.payload.quarantinedMons or {}) do
      local id = tx.id .. ":QUARANTINE:" .. index
      archive.quarantine.bank[id] = {
        row = {
          id = id, mon = copy(held.mon), depositedBy = tx.id,
        },
        reason = held.reason or "unknown_species",
      }
    end
    for index, mon in ipairs(tx.payload.mons or {}) do
      local id = mon.__kaLegacyId or (tx.id .. ":MON:" .. index)
      mon.__kaLegacyId = id
      local row = { id = id, mon = copy(mon), depositedBy = tx.id }
      if byId[id] then archive.bank[byId[id]] = row
      else
        archive.bank[#archive.bank + 1] = row
        byId[id] = #archive.bank
      end
    end
    for id, count in pairs(tx.payload.items or {}) do
      local policy = classifyItem(id)
      if policy.claimMode == "unique_after_mega_access" then
        archive.locker.items[id] = 1
      else
        archive.locker.items[id] = (archive.locker.items[id] or 0) + count
      end
    end
    archive.locker.money = archive.locker.money
      + math.max(0, math.floor(tonumber(tx.payload.money) or 0))
    archive.cycle = math.max(archive.cycle, tx.targetCycle)
    archive.hallOfLegacy[#archive.hallOfLegacy + 1] = copy(tx.hall)
    archive.current = {
      cycle = tx.targetCycle,
      runId = tx.id,
      bankUnlocked = false,
      wanderersEnabled = true,
      pact = pactId(tx.hall and tx.hall.pact),
      bankPolicy = bankPolicyId(tx.hall and tx.hall.bankPolicy,
        tx.hall and tx.hall.pact),
      bankPolicyVersion = BANK_POLICY_VERSION,
      itemPolicy = itemPolicyId(tx.hall and tx.hall.itemPolicy),
      itemPolicyVersion = ITEM_POLICY_VERSION,
      runRules = copy(tx.hall and tx.hall.runRules),
      runRulesLegacyDefault = tx.hall
        and tx.hall.runRulesLegacyDefault == true or nil,
      avatar = nil,
      avatarQuestStage = 0,
      pathComplete = false,
      status = "pending_new_game",
    }
    archive.appliedTransactions[tx.id] = true
    tx.state = "committed"
    tx.payload = nil
    return archive
  end

  function A.beginJourney(save, meta)
    assert(type(save) == "table", "legacy journey needs a save")
    -- A volatile substitute would lose the Bank. Refuse before reading or
    -- mutating the save unless an official durable storage adapter is bound.
    if not A.persistent then
      return nil, A.unavailableReason
    end
    local lineageOk, lineageErr = A.lineageStatus(save)
    if not lineageOk then return nil, lineageErr end
    if not registryReady() then
      return nil, "Legacy registry validation is unavailable"
    end
    local blockers = daycareBlockers(save)
    if #blockers > 0 then
      return nil, "Legacy Journey blocked: " .. table.concat(blockers, "; ")
    end
    local archive, loadErr = mutableArchive()
    if not archive then return nil, loadErr end
    if reconcileRegistry(archive) then
      local reconciled, reconcileErr = A.write(archive)
      if not reconciled then return nil, reconcileErr end
    end
    mergeHevoPersistent(archive, save)
    mergeJohtoMastersPersistent(archive, save)
    mergeTitleState(archive, save)
    if archive.transaction and archive.transaction.state == "prepared" then
      archive = applyPrepared(archive)
      local recovered, recoverErr = A.write(archive)
      if not recovered then return nil, recoverErr end
    end

    local playerId = save.player and save.player.id or 0
    local pending = archive.transaction
    if type(pending) == "table" and pending.id == archive.current.runId
        and pendingSourceOwned(archive, save) then
      return copy(archive.current), archive
    end

    local targetCycle = archive.cycle + 1
    local id = sourceId(save, targetCycle)
    if archive.transaction and archive.transaction.id == id
        and archive.appliedTransactions[id] then
      return copy(archive.current), archive
    end

    meta = type(meta) == "table" and copy(meta) or {}
    local selectedRules, rulesErr = canonicalRunRules(meta.runRules)
    if not selectedRules then
      return nil, rulesErr or "Legacy run-rules snapshot is required"
    end
    meta.runRules = selectedRules
    meta.itemPolicy = itemPolicyId(meta.itemPolicy)

    local proofDigest, proofErr = sourceProofDigest(save)
    if not proofDigest then return nil, proofErr end
    local playthroughId = type(save.meta) == "table"
      and save.meta.playthroughId or nil
    if enforceLegacyMigrationGuard and not editionScoped
        and (type(playthroughId) ~= "string"
        or playthroughId == "") then
      return nil, "Legacy source save has no official playthrough identity"
    end
    local tx = {
      id = id,
      state = "prepared",
      source = {
        edition = tostring(save.version or edition),
        playerId = playerId,
        playthroughId = playthroughId,
        runId = localRunId(save),
        proofDigest = proofDigest,
      },
      targetCycle = targetCycle,
      payload = payloadFrom(save, archive, meta.itemPolicy),
      hall = hallEntry(save, meta, targetCycle),
      preparedAt = now(),
    }
    archive.transaction = tx
    archive.lastRollback = { transactionId = id, save = copy(save) }
    local staged, stageErr = A.write(archive)
    if not staged then return nil, stageErr end

    archive = applyPrepared(archive)
    local committed, commitErr = A.write(archive)
    if not committed then return nil, commitErr end
    writePath(rollback, archive.lastRollback)
    return copy(archive.current), archive
  end

  function A.seedNewSave(save)
    if not registryReady() then
      return false, "Legacy registry validation is unavailable"
    end
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    if reconcileRegistry(archive) then
      local reconciled, reconcileErr = A.write(archive)
      if not reconciled then return false, reconcileErr end
    end
    local current = archive.current
    if current.status ~= "pending_new_game" then return false end
    save.modData = type(save.modData) == "table" and save.modData or {}
    local bucket = type(save.modData[modId]) == "table"
      and save.modData[modId] or {}
    save.modData[modId] = bucket
    bucket.legacy_journey = {
      version = VERSION,
      cycle = current.cycle,
      runId = current.runId,
      bankUnlocked = current.bankUnlocked == true,
      wanderersEnabled = true,
      pact = pactId(current.pact),
      bankPolicy = bankPolicyId(current.bankPolicy, current.pact),
      bankPolicyVersion = current.bankPolicyVersion,
      itemPolicy = itemPolicyId(current.itemPolicy),
      itemPolicyVersion = current.itemPolicyVersion,
      pendingRunRules = copy(current.runRules),
      runRulesLegacyDefault = current.runRulesLegacyDefault == true,
      runRulesLocked = false,
      avatar = current.avatar,
      avatarQuestStage = current.avatarQuestStage or 0,
      pathComplete = current.pathComplete == true,
      completedPaths = copy(archive.completedPaths),
      pathSealCycles = copy(archive.pathSealCycles),
      legacyPass = archive.legacyPass == true,
    }
    bucket.hevo_run = {
      version = 1, activeCharacter = current.avatar,
      puzzles = {}, statues = {}, runComplete = false,
      doorQuestConsumed = false,
    }
    bucket.hevo_persistent = copy(archive.hevoPersistent)
    bucket.johto_masters = copy(archive.johtoMastersPersistent)
    seedTitleState(bucket, archive)
    -- Full, data-only bridge between the source and target opaque storage
    -- scopes. It exists only in the fresh in-memory save, is imported and
    -- verified before that save may hit disk, then is removed. The source
    -- archive remains untouched and therefore retryable after any failed or
    -- interrupted target write.
    bucket.legacy_lineage_handoff = {
      version = HANDOFF_VERSION,
      archiveSchema = VERSION,
      runId = current.runId,
      cycle = current.cycle,
      archive = copy(archive),
    }
    save.flags = type(save.flags) == "table" and save.flags or {}
    for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
      if archive.hevoPersistent.meta[key] then
        save.flags["HEVO_META_" .. key] = true
      end
    end
    return true
  end

  function A.markRunStarted(save)
    local bucket = type(save.modData) == "table" and save.modData[modId]
    local state = type(bucket) == "table" and bucket.legacy_journey
    if type(state) ~= "table" or not state.runId then return false end
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    if archive.current.runId ~= state.runId then return false end
    if archive.current.status ~= "active" then
      archive.current.status = "active"
      archive.current.startedAt = archive.current.startedAt or now()
      archive.lastTransaction = archive.transaction
      archive.transaction = nil
      return A.write(archive)
    end
    return true
  end


  local function runState(save)
    local bucket = type(save.modData) == "table" and save.modData[modId]
    return type(bucket) == "table" and bucket.legacy_journey or nil
  end

  local function badgeCount(save)
    local count = 0
    for id, amount in pairs(type(save and save.inventory) == "table"
        and save.inventory or {}) do
      if (tonumber(amount) or 0) > 0 and isBadge(id) then
        count = count + 1
      end
    end
    return count
  end

  -- One source of truth for both the PC presentation and archive operations.
  -- The policy is derived from durable progress, never from party strength.
  -- Older active runs with their historical unconditional flag stay open;
  -- policy-owned runs must satisfy partner + the selected campaign gate.
  function A.bankAccess(save)
    local run = runState(save)
    if type(run) ~= "table" or not run.runId then
      return false, "inactive", nil, nil
    end
    local archive = A.load()
    local current = type(archive.current) == "table" and archive.current or {}
    local ownsCurrent = current.runId == run.runId
    -- The external current-run record is immutable authority for a new-format
    -- journey. A modified live save cannot switch pact or Bank rule mid-run.
    local pact = pactId(ownsCurrent and current.pact or run.pact)
    local policy = bankPolicyId(ownsCurrent and current.bankPolicy
      or run.bankPolicy, pact)
    local policyVersion = tonumber(ownsCurrent and current.bankPolicyVersion
      or run.bankPolicyVersion)
    if not policyVersion and (run.bankUnlocked == true
        or ownsCurrent and current.bankUnlocked == true) then
      return true, "compat", policy, pact
    end
    local partnerChosen = run.partnerChosen == true
      or ownsCurrent and current.partnerChosen == true
    if not partnerChosen then return false, "partner", policy, pact end
    if policy == "open" then return true, "open", policy, pact end
    if policy == "badges4" then
      local badges = badgeCount(save)
      return badges >= 4, badges >= 4 and "badges" or "badges4", policy, pact
    end
    if policy == "league" then
      local champion = A.isEligible(save)
      return champion, champion and "league" or "league_required", policy, pact
    end
    return false, "sealed", policy, pact
  end

  local function requireBankAccess(save)
    local allowed, why = A.bankAccess(save)
    if allowed then return true end
    return false, "Legacy Bank locked: " .. tostring(why)
  end

  local function liveLegacyMons(save)
    local found = {}
    local function scan(list)
      for _, mon in ipairs(list or {}) do
        if type(mon) == "table" and mon.__kaLegacyId then
          found[mon.__kaLegacyId] = mon
        end
      end
    end
    scan(save.party)
    for _, box in ipairs(boxesFrom(save)) do scan(box) end
    return found
  end

  function A.reconcileLeases(save)
    local state = runState(save)
    if type(state) ~= "table" or not state.runId then return false end
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    local live = liveLegacyMons(save)
    local changed = false
    for _, row in ipairs(archive.bank) do
      if type(row) == "table" and row.id then
        local mon = live[row.id]
        if mon then
          if row.lease ~= state.runId then row.lease, changed = state.runId, true end
          row.mon = copy(mon)
        elseif row.lease == state.runId then
          row.lease, changed = nil, true
        end
      end
    end
    if changed then return A.write(archive) end
    return true
  end

  function A.availableMons(save)
    if not registryReady() then
      return {}, "Legacy registry validation is unavailable"
    end
    local allowed, accessErr = requireBankAccess(save)
    if not allowed then return {}, accessErr end
    local snapshot, loadErr = mutableArchive()
    if not snapshot then return {}, loadErr end
    if reconcileRegistry(snapshot) then
      local ok, err = A.write(snapshot)
      if not ok then return {}, err end
    end
    A.reconcileLeases(save)
    snapshot, loadErr = mutableArchive()
    if not snapshot then return {}, loadErr end
    local rows = {}
    for _, row in ipairs(snapshot.bank) do
      if type(row) == "table" and row.id and not row.lease then
        local visible = copy(row)
        if type(withdrawalGate) == "function" then
          local called, allowed, reason = pcall(
            withdrawalGate, save, visible.mon, visible.id)
          if not called or allowed ~= true then
            visible.withdrawBlocked = true
            visible.withdrawReason = called and reason
              or "Legacy Bank withdrawal gate failed"
          end
        end
        rows[#rows + 1] = visible
      end
    end
    return rows
  end

  function A.leaseMon(save, id)
    if not registryReady() then
      return nil, "Legacy registry validation is unavailable"
    end
    local allowed, accessErr = requireBankAccess(save)
    if not allowed then return nil, accessErr end
    local state = runState(save)
    if type(state) ~= "table" or not state.runId then
      return nil, "no active legacy run"
    end
    A.reconcileLeases(save)
    local archive, loadErr = mutableArchive()
    if not archive then return nil, loadErr end
    if reconcileRegistry(archive) then
      local ok, err = A.write(archive)
      if not ok then return nil, err end
    end
    for _, row in ipairs(archive.bank) do
      if row.id == id then
        if row.lease then return nil, "Pokémon is already withdrawn" end
        if type(withdrawalGate) == "function" then
          local called, allowed, reason = pcall(
            withdrawalGate, save, row.mon, row.id)
          if not called or allowed ~= true then
            return nil, called and reason
              or "Legacy Bank withdrawal gate failed"
          end
        end
        row.lease = state.runId
        local ok, err = A.write(archive)
        if not ok then return nil, err end
        return copy(row.mon)
      end
    end
    return nil, "unknown legacy Pokémon"
  end

  function A.releaseLease(save, id)
    local state = runState(save)
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    for _, row in ipairs(archive.bank) do
      if row.id == id and (not state or row.lease == state.runId) then
        row.lease = nil
        return A.write(archive)
      end
    end
    return false, "unknown legacy Pokémon"
  end

  function A.stageDeposit(save, mon)
    if not registryReady() then
      return nil, "Legacy registry validation is unavailable"
    end
    local allowed, accessErr = requireBankAccess(save)
    if not allowed then return nil, accessErr end
    local state = runState(save)
    if type(state) ~= "table" or not state.runId then
      return nil, "no active legacy run"
    end
    if type(mon) ~= "table" or not mon.species then
      return nil, "invalid Pokémon"
    end
    local invalidReason = monReason(mon)
    if invalidReason then
      return nil, "Pokémon is not registered: " .. invalidReason
    end
    local archive, loadErr = mutableArchive()
    if not archive then return nil, loadErr end
    archive.depositSerial = math.max(0, math.floor(
      tonumber(archive.depositSerial) or 0)) + 1
    local id = mon.__kaLegacyId
      or (state.runId .. ":LIVE:" .. archive.depositSerial)
    mon.__kaLegacyId = id
    local byId = bankIndex(archive)
    local row = {
      id = id,
      mon = copy(mon),
      depositedBy = state.runId,
      lease = state.runId,
    }
    if byId[id] then archive.bank[byId[id]] = row
    else archive.bank[#archive.bank + 1] = row end
    local ok, err = A.write(archive)
    if not ok then return nil, err end
    return id
  end

  function A.completeDeposit(save, id)
    local state = runState(save)
    if type(state) ~= "table" or not state.runId then return false end
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    for _, row in ipairs(archive.bank) do
      if row.id == id and row.lease == state.runId then
        row.lease = nil
        return A.write(archive)
      end
    end
    return false, "unknown staged deposit"
  end

  local function checkoutSerial(archive)
    archive.checkoutSerial = math.max(0, math.floor(
      tonumber(archive.checkoutSerial) or 0)) + 1
    return archive.checkoutSerial
  end

  local function megaStateFrom(save)
    local bucket = type(save and save.modData) == "table"
      and save.modData[modId]
    return type(bucket) == "table" and bucket.mega_evolution or nil
  end

  local function megaAccessReady(save)
    local mega = megaStateFrom(save)
    return type(mega) == "table" and (mega.case == true or mega.ring == true)
      or (tonumber(save and save.inventory
        and save.inventory.MEGA_STONE_CASE) or 0) > 0
  end

  local function megaStoneOwned(save, id)
    local mega = megaStateFrom(save)
    return type(mega) == "table" and type(mega.stones) == "table"
      and mega.stones[id] == true
  end

  function A.reconcileCheckout(save)
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    local pending = archive.pendingCheckout
    if type(pending) ~= "table" then return true end
    local state = runState(save)
    if not state or state.runId ~= pending.runId then return true end
    local received = false
    if pending.kind == "item" then
      if pending.claimMode == "unique_after_mega_access" then
        received = megaStoneOwned(save, pending.item)
      elseif type(pending.grant) == "table" then
        -- Counted Locker withdrawals may span the Bag and Player PC.  The
        -- prepared journal binds both exact destinations and both pre-grant
        -- counts, so a save that contains only half of the planned grant can
        -- never consume the archive receipt.
        local bagCount = math.max(0, math.floor(
          tonumber(pending.grant.bag) or 0))
        local pcCount = math.max(0, math.floor(
          tonumber(pending.grant.pc) or 0))
        local beforeBag = math.max(0, math.floor(
          tonumber(pending.beforeBag) or 0))
        local beforePc = math.max(0, math.floor(
          tonumber(pending.beforePc) or 0))
        local bagNow = tonumber(save.inventory
          and save.inventory[pending.item]) or 0
        local pcNow = tonumber(save.pcItems
          and save.pcItems[pending.item]) or 0
        received = bagCount + pcCount == pending.count
          and bagNow >= beforeBag + bagCount
          and pcNow >= beforePc + pcCount
      else
        received = (tonumber(save.inventory and save.inventory[pending.item]) or 0)
          >= pending.before + pending.count
      end
    elseif pending.kind == "money" then
      received = (tonumber(save.money) or 0) >= pending.before + pending.count
    end
    if received then
      if pending.kind == "item" then
        local have = tonumber(archive.locker.items[pending.item]) or 0
        archive.locker.items[pending.item] = math.max(0, have - pending.count)
        if archive.locker.items[pending.item] == 0 then
          archive.locker.items[pending.item] = nil
        end
      else
        archive.locker.money = math.max(0,
          archive.locker.money - pending.count)
      end
    end
    archive.pendingCheckout = nil
    return A.write(archive)
  end

  function A.beginItemCheckout(save, item, count, grant)
    if not registryReady() then
      return nil, "Legacy registry validation is unavailable"
    end
    local allowed, accessErr = requireBankAccess(save)
    if not allowed then return nil, accessErr end
    local state = runState(save)
    if type(state) ~= "table" or not state.runId then
      return nil, "no active legacy run"
    end
    local reconciled, reconcileErr = A.reconcileCheckout(save)
    if not reconciled then return nil, reconcileErr end
    local archive, loadErr = mutableArchive()
    if not archive then return nil, loadErr end
    if reconcileRegistry(archive) then
      local ok, err = A.write(archive)
      if not ok then return nil, err end
    end
    local policy = classifyItem(item)
    local lockedReason = itemReason(item)
    if lockedReason then return nil, "item is not transferable: " .. lockedReason end
    count = math.max(1, math.floor(tonumber(count) or 1))
    if policy.claimMode == "unique_after_mega_access" then
      if not megaAccessReady(save) then
        return nil, "Mega Stone Case is not active in this journey"
      end
      count = 1
      -- Unique Stone receipts never become Bag/PC stacks.
      grant = nil
    elseif grant ~= nil then
      if type(grant) ~= "table" then
        return nil, "invalid item checkout grant plan"
      end
      local bagCount = tonumber(grant.bag)
      local pcCount = tonumber(grant.pc)
      if not bagCount or not pcCount or bagCount < 0 or pcCount < 0
          or bagCount ~= math.floor(bagCount)
          or pcCount ~= math.floor(pcCount)
          or bagCount + pcCount ~= count then
        return nil, "invalid item checkout grant plan"
      end
      grant = { bag = bagCount, pc = pcCount }
    end
    local have = tonumber(archive.locker.items[item]) or 0
    if have < count then return nil, "not enough items in locker" end
    local id = state.runId .. ":CHECKOUT:" .. checkoutSerial(archive)
    local beforeBag = tonumber(save.inventory and save.inventory[item]) or 0
    local beforePc = tonumber(save.pcItems and save.pcItems[item]) or 0
    archive.pendingCheckout = {
      id = id, kind = "item", item = item, count = count,
      -- `before` keeps old in-flight/count-only readers compatible.  New
      -- counted transactions additionally bind the split destination.
      before = beforeBag,
      beforeBag = grant and beforeBag or nil,
      beforePc = grant and beforePc or nil,
      grant = grant and copy(grant) or nil,
      claimMode = policy.claimMode,
      runId = state.runId,
    }
    local ok, err = A.write(archive)
    if not ok then return nil, err end
    return copy(archive.pendingCheckout)
  end

  function A.beginMoneyCheckout(save, count)
    local allowed, accessErr = requireBankAccess(save)
    if not allowed then return nil, accessErr end
    local state = runState(save)
    if type(state) ~= "table" or not state.runId then
      return nil, "no active legacy run"
    end
    A.reconcileCheckout(save)
    local archive, loadErr = mutableArchive()
    if not archive then return nil, loadErr end
    count = math.max(1, math.floor(tonumber(count) or 1))
    if archive.locker.money < count then return nil, "not enough legacy money" end
    local id = state.runId .. ":CHECKOUT:" .. checkoutSerial(archive)
    archive.pendingCheckout = {
      id = id, kind = "money", count = count,
      before = tonumber(save.money) or 0,
      runId = state.runId,
    }
    local ok, err = A.write(archive)
    if not ok then return nil, err end
    return copy(archive.pendingCheckout)
  end

  function A.completeCheckout(save, id)
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    local pending = archive.pendingCheckout
    if type(pending) ~= "table" or pending.id ~= id then
      return false, "unknown checkout"
    end
    return A.reconcileCheckout(save)
  end

  function A.cancelCheckout(id)
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    if type(archive.pendingCheckout) ~= "table"
        or archive.pendingCheckout.id ~= id then return false end
    archive.pendingCheckout = nil
    return A.write(archive)
  end

  function A.locker()
    if not registryReady() then
      return { items = {}, money = 0 }, "Legacy registry validation is unavailable"
    end
    local archive, err = A.load()
    if not A.readOnly and reconcileRegistry(archive) then
      local ok, writeErr = A.write(archive)
      if not ok then err = writeErr end
    end
    return copy(type(archive.locker) == "table" and archive.locker
      or { items = {}, money = 0 }), err
  end

  function A.current()
    local archive, err = A.load()
    return copy(type(archive.current) == "table" and archive.current or {}), err
  end

  local AVATARS = { RED = "red", BLUE = "blue", GREEN = "green" }

  local function activeArchive(save)
    local run = runState(save)
    if type(run) ~= "table" or not run.runId then
      return nil, nil, "no active legacy run"
    end
    local archive, loadErr = mutableArchive()
    if not archive then return nil, nil, loadErr end
    if archive.current.runId ~= run.runId then
      return nil, nil, "legacy run does not own current profile"
    end
    return archive, run
  end

  local function syncRunProfile(run, archive)
    run.version = VERSION
    run.pact = pactId(archive.current.pact)
    run.bankPolicy = bankPolicyId(
      archive.current.bankPolicy, archive.current.pact)
    run.bankPolicyVersion = archive.current.bankPolicyVersion
    run.itemPolicy = itemPolicyId(archive.current.itemPolicy)
    run.itemTransferPolicy = nil
    run.itemPolicyVersion = archive.current.itemPolicyVersion
      or ITEM_POLICY_VERSION
    run.pendingRunRules = copy(archive.current.runRules)
    run.runRulesLegacyDefault = archive.current.runRulesLegacyDefault == true
      and true or nil
    run.archiveStatus = archive.current.status
    if run.bankPolicyVersion then
      run.bankUnlocked = archive.current.bankUnlocked == true
    end
    run.avatar = archive.current.avatar
    run.avatarQuestStage = archive.current.avatarQuestStage or 0
    run.pathComplete = archive.current.pathComplete == true
    run.completedPaths = copy(archive.completedPaths)
    run.pathSealCycles = copy(archive.pathSealCycles)
    run.legacyPass = archive.legacyPass == true
    -- A successfully written game save is the authority for the first
    -- partner commit.  Never erase that local commit merely because the
    -- separate archive filesystem is temporarily unavailable; once mirrored,
    -- the archive can recover the fields into a stale in-memory save.
    if archive.current.partnerChosen or not run.partnerChosen then
      run.partnerChosen = archive.current.partnerChosen == true
      run.partnerSpecies = archive.current.partnerSpecies
      run.partnerMode = archive.current.partnerMode
      run.partnerBall = archive.current.partnerBall
      run.partnerChosenAtCycle = archive.current.partnerChosenAtCycle
      run.rivalPartner = copy(archive.current.rivalPartner)
    end
  end

  local function rivalSignature(row)
    if type(row) ~= "table" then return "" end
    return table.concat({
      tostring(row.version or ""), tostring(row.lineId or ""),
      tostring(row.base or ""), tostring(row.mid or ""),
      tostring(row.final or ""), tostring(row.sourcePartner or ""),
    }, ":")
  end

  -- Mirror the already-durable fresh-save decision into the cross-run
  -- archive. Repeating this call is a no-op; a different second partner for
  -- the same run is rejected, so save/load retries cannot duplicate or swap
  -- Oak's gift.
  function A.syncPartner(save)
    local archive, run, err = activeArchive(save)
    if not archive then return false, err end
    if run.partnerChosen ~= true then return true end
    local species = type(run.partnerSpecies) == "string"
      and run.partnerSpecies or nil
    local mode = tostring(run.partnerMode or "")
    if not species then return false, "Legacy partner has no species" end
    if not ({ balanced = true, free = true, hoenn = true, yellow = true })[mode] then
      return false, "Legacy partner has invalid mode"
    end
    if archive.current.partnerChosen
        and archive.current.partnerSpecies ~= species then
      return false, "Legacy partner is already fixed for this run"
    end
    local changed = archive.current.partnerChosen ~= true
      or archive.current.partnerSpecies ~= species
      or archive.current.partnerMode ~= mode
      or archive.current.partnerBall ~= run.partnerBall
      or archive.current.partnerChosenAtCycle ~= run.partnerChosenAtCycle
      or rivalSignature(archive.current.rivalPartner)
        ~= rivalSignature(run.rivalPartner)
    if not changed then return true end
    archive.current.partnerChosen = true
    archive.current.partnerSpecies = species
    archive.current.partnerMode = mode
    archive.current.partnerBall = run.partnerBall
    archive.current.partnerChosenAtCycle = math.max(0, math.floor(tonumber(
      run.partnerChosenAtCycle) or archive.current.cycle or 0))
    archive.current.rivalPartner = copy(run.rivalPartner)
    return A.write(archive)
  end

  function A.activeCharacter(save)
    local run = runState(save)
    if type(run) ~= "table" or not run.runId then return nil end
    local archive = A.load()
    local current = type(archive.current) == "table" and archive.current or {}
    local avatar = run.avatar or current.avatar
    avatar = tostring(avatar or ""):upper()
    return AVATARS[avatar] and avatar or nil
  end

  function A.runLocal(save)
    local bucket = type(save and save.modData) == "table"
      and save.modData[modId]
    if type(bucket) ~= "table" then return nil end
    bucket.hevo_run = type(bucket.hevo_run) == "table" and bucket.hevo_run or {
      version = 1, activeCharacter = A.activeCharacter(save),
      puzzles = {}, statues = {}, runComplete = false,
      doorQuestConsumed = false,
    }
    return bucket.hevo_run
  end

  function A.hevoPersistent()
    local archive, err = A.load()
    return copy(type(archive.hevoPersistent) == "table"
      and archive.hevoPersistent or {}), err
  end

  -- Synchronize the durable HEVO package bucket without advancing a path or
  -- starting a new journey. Callers stage and save the live game first, then
  -- use this boundary so a fresh save receives exactly the committed grants.
  function A.syncHevoPersistent(save)
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    mergeHevoPersistent(archive, save)
    return A.write(archive)
  end

  -- Called by the Johto controller after its own save succeeds.  Separate
  -- from HEVO so either feature can retain its transaction boundary.
  function A.syncJohtoMastersPersistent(save)
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    mergeJohtoMastersPersistent(archive, save)
    return A.write(archive)
  end

  -- Stock playthrough storage can contain one narrowly identifiable
  -- pre-Journey bootstrap written by this module itself: an original-run
  -- HEVO/JM sync creates the normalized empty v6 archive and adds only data
  -- that is already proven by the same save.  Older identified saves predate
  -- `legacy_storage_binding`, so that harmless bootstrap would otherwise
  -- poison the verified offline migration boundary and make the PC report a
  -- misleading "newer mod" error.
  --
  -- Adoption is deliberately much stricter than normal archive migration.
  -- The official Storage context must name this exact playthrough; the save
  -- may have no run, handoff, fresh-origin or receipt; and every byte-semantic
  -- archive field must equal one of the deterministic original-run snapshots
  -- this module can derive from the same save.  A bank row, Hall entry,
  -- transaction, foreign seal, unknown field or altered counter therefore
  -- remains fail-closed.  Once verified, current persistent progress is
  -- merged, written/read back through the normal archive transaction, and a
  -- digest-bound receipt is stamped into the in-memory save for the caller to
  -- persist before offering the irreversible Journey confirmations.
  local function bootstrapLocalSeals(save)
    local bucket = saveBucket(save, false)
    local hevoRun = type(bucket) == "table" and bucket.hevo_run
    local dungeon = type(hevoRun) == "table" and hevoRun.dungeonLegacy
    local seals = type(dungeon) == "table" and dungeon.seals
    return type(seals) == "table" and seals or {}
  end

  local function canonicalBootstrap(save, actual, includeHevo,
      includeMasters, includeTitles)
    local candidate = empty()
    if includeHevo then mergeHevoPersistent(candidate, save) end
    if includeMasters then mergeJohtoMastersPersistent(candidate, save) end
    if includeTitles then mergeTitleState(candidate, save) end

    local localSeals = bootstrapLocalSeals(save)
    for _, row in ipairs({
      { archive = "red", save = "RED" },
      { archive = "blue", save = "BLUE" },
      { archive = "green", save = "GREEN" },
    }) do
      if actual.completedPaths[row.archive] == true then
        if localSeals[row.save] ~= true
            or tonumber(actual.pathSealCycles[row.archive]) ~= 0 then
          return nil
        end
        candidate.completedPaths[row.archive] = true
        candidate.pathSealCycles[row.archive] = 0
      end
    end
    return normalize(candidate)
  end

  local function exactOriginalRunBootstrap(archive, save)
    if type(archive) ~= "table" then return false end
    local bucket = saveBucket(save, false)
    local characters = type(bucket) == "table"
      and bucket.extended_characters or nil
    local character
    if characters == nil then
      -- Exact absence is the authored pre-6.5 RED migration. A present but
      -- unknown/future identity is never silently converted to RED.
      character = "RED"
    elseif type(characters) == "table" then
      local candidate = tostring(characters.player_character or ""):upper()
      character = ({ RED = true, BLUE = true, GREEN = true })[candidate]
        and candidate or nil
    end
    local key = character and ({ RED = "red", BLUE = "blue",
      GREEN = "green" })[character] or nil
    local localSeals = bootstrapLocalSeals(save)
    -- An empty scope can be created merely by probing old playthrough
    -- storage. It is not lineage authority. Adoption requires the strong
    -- self-write witness produced by finalizing this exact hero's HEVO path.
    if not key or archive.completedPaths[key] ~= true
        or tonumber(archive.pathSealCycles[key]) ~= 0
        or localSeals[character] ~= true then
      return false
    end
    for mask = 0, 7 do
      local candidate = canonicalBootstrap(save, archive,
        mask % 2 == 1,
        math.floor(mask / 2) % 2 == 1,
        math.floor(mask / 4) % 2 == 1)
      if candidate and sameArchive(archive, candidate) then return true end
    end
    return false
  end

  function A.adoptScopedBootstrap(save, context)
    if not (enforceLegacyMigrationGuard and not editionScoped) then
      return false, "Legacy scoped bootstrap adoption is not available"
    end
    if type(save) ~= "table" or type(context) ~= "table" then
      return false, "Legacy scoped bootstrap needs a save and Storage context"
    end
    local stamped = type(save.meta) == "table" and save.meta.playthroughId
    if type(stamped) ~= "string" or stamped == ""
        or stamped:match("^[%w_-]+$") == nil
        or context.playthroughId ~= stamped
        or tostring(context.gameVersion or "")
          ~= tostring(save.version or edition) then
      return false, "Legacy scoped bootstrap Storage identity does not match"
    end

    local binding, bindingErr, bindingPresent = storageBindingFrom(save)
    if bindingPresent then
      return false, bindingErr
        or "Legacy scoped bootstrap save already has a storage receipt"
    end
    local fresh, freshErr, freshPresent = freshOriginFrom(save)
    if freshPresent then
      return false, freshErr
        or "Legacy scoped bootstrap save already has a fresh-origin receipt"
    end
    if handoffFrom(save) or localRunId(save) then
      return false, "Legacy scoped bootstrap save already belongs to a run"
    end
    if not storageHasArchive() then
      return false, "Legacy scoped bootstrap has no verified archive generation"
    end

    -- Inspect only the primary current-schema generation here. Normal A.load
    -- recovery/migration may legitimately rewrite main from bak/tmp; adoption
    -- must not perform even that benign write before it has authenticated the
    -- candidate as this exact save's own bootstrap.
    local archive, status, _, sourceVersion = decode(filename)
    if not archive or status ~= nil or sourceVersion ~= VERSION then
      return false, status == "future"
        and "Legacy scoped bootstrap uses a future archive schema"
        or "Legacy scoped bootstrap needs one current verified primary"
    end
    if not exactOriginalRunBootstrap(archive, save) then
      return false,
        "Legacy scoped archive is not an exact original-run bootstrap"
    end

    -- Complete a possibly interrupted earlier adoption. Each merge is
    -- deterministic/idempotent and remains within the already authenticated
    -- source save; the normal archive writer provides tmp/main/bak readback.
    mergeHevoPersistent(archive, save)
    mergeJohtoMastersPersistent(archive, save)
    mergeTitleState(archive, save)
    local written, writeErr = A.write(archive)
    if not written then return false, writeErr end

    local bound, bindErr = A.stampStorageBinding(save, context)
    if not bound then return false, bindErr end
    local lineageOk, lineageErr = A.lineageStatus(save)
    if not lineageOk then
      local bucket = saveBucket(save, false)
      if bucket then bucket.legacy_storage_binding = nil end
      return false, lineageErr
    end
    return true, "adopted"
  end

  -- Hidden Evolution is reachable in the original run as well as NG+.
  -- Record a character seal without requiring an active Legacy-bank run;
  -- when one exists, mirror the same completion into its current profile.
  function A.completeHevoPath(save, character)
    local key = ({ RED = "red", BLUE = "blue", GREEN = "green" })[
      tostring(character or ""):upper()]
    if not key then return false, "invalid HEVO character" end
    local archive, loadErr = mutableArchive()
    if not archive then return false, loadErr end
    mergeHevoPersistent(archive, save)
    archive.completedPaths[key] = true
    archive.pathSealCycles[key] = archive.pathSealCycles[key]
      or math.max(0, math.floor(tonumber(archive.cycle) or 0))
    local run = runState(save)
    if type(run) == "table" and run.runId == archive.current.runId then
      archive.current.avatar = archive.current.avatar
        or tostring(character):upper()
      archive.current.avatarQuestStage = math.max(5,
        tonumber(archive.current.avatarQuestStage) or 0)
      archive.current.pathComplete = true
    end
    local ok, err = A.write(archive)
    if not ok then return false, err end
    if type(run) == "table" and run.runId == archive.current.runId then
      syncRunProfile(run, archive)
    end
    return true
  end

  function A.hevoDoorQuestReady(save)
    local archive = mutableArchive()
    if not archive then return false end
    local localState = A.runLocal(save)
    if not localState or localState.doorQuestConsumed == true then return false end
    local champion = A.isEligible(save)
    return champion and archive.completedPaths.red
      and archive.completedPaths.blue and archive.completedPaths.green
  end

  function A.consumeHevoDoorQuest(save)
    if not A.hevoDoorQuestReady(save) then return false end
    local localState = A.runLocal(save)
    localState.doorQuestConsumed = true
    save.flags = type(save.flags) == "table" and save.flags or {}
    save.flags.HEVO_DOOR_QUEST_READY = nil
    return true
  end

  function A.setAvatar(save, avatar)
    avatar = tostring(avatar or ""):upper()
    if not AVATARS[avatar] then return false, "invalid legacy avatar" end
    local archive, run, err = activeArchive(save)
    if not archive then return false, err end
    if archive.current.avatar and archive.current.avatar ~= avatar
        and archive.current.avatarQuestStage > 0 then
      return false, "legacy path already started"
    end
    archive.current.avatar = avatar
    local ok, writeErr = A.write(archive)
    if not ok then return false, writeErr end
    syncRunProfile(run, archive)
    local localState = A.runLocal(save)
    if localState then localState.activeCharacter = avatar end
    return true
  end

  function A.advancePath(save, stage, complete)
    local archive, run, err = activeArchive(save)
    if not archive then return false, err end
    local key = AVATARS[archive.current.avatar]
    if not key then return false, "legacy avatar is not selected" end
    stage = math.max(0, math.floor(tonumber(stage) or 0))
    if stage < archive.current.avatarQuestStage then
      return false, "legacy path cannot move backwards"
    end
    archive.current.avatarQuestStage = stage
    if complete then
      archive.current.pathComplete = true
      archive.completedPaths[key] = true
      archive.pathSealCycles[key] = archive.pathSealCycles[key]
        or math.max(0, math.floor(tonumber(archive.current.cycle) or 0))
    end
    mergeHevoPersistent(archive, save)
    local ok, writeErr = A.write(archive)
    if not ok then return false, writeErr end
    syncRunProfile(run, archive)
    return true
  end

  function A.completeFinale(save)
    local archive, run, err = activeArchive(save)
    if not archive then return false, err end
    if not (archive.completedPaths.red and archive.completedPaths.blue
        and archive.completedPaths.green) then
      return false, "all legacy paths are required"
    end
    archive.legacyPass = true
    local ok, writeErr = A.write(archive)
    if not ok then return false, writeErr end
    syncRunProfile(run, archive)
    return true
  end

  function A.syncProfile(save)
    local archive, run = activeArchive(save)
    if not archive then return false end
    syncRunProfile(run, archive)
    return true
  end

  function A.profile()
    local archive = A.load()
    local current = type(archive.current) == "table" and archive.current or {}
    local completedPaths = type(archive.completedPaths) == "table"
      and archive.completedPaths or {}
    local pathSealCycles = type(archive.pathSealCycles) == "table"
      and archive.pathSealCycles or {}
    local titles = type(archive.titles) == "table" and archive.titles or {}
    return {
      cycle = math.max(0, math.floor(tonumber(archive.cycle) or 0)),
      current = copy(current),
      completedPaths = copy(completedPaths),
      pathSealCycles = copy(pathSealCycles),
      legacyPass = archive.legacyPass == true,
      titles = copy(titles),
      readOnly = A.readOnly == true,
      futureVersion = A.futureVersion,
    }
  end

  function A.summary(save, meta)
    local payload = payloadFrom(save, nil, meta and meta.itemPolicy)
    local itemStacks, itemCount = 0, 0
    for _, count in pairs(payload.items) do
      itemStacks, itemCount = itemStacks + 1, itemCount + count
    end
    local lineageOk, lineageErr = A.lineageStatus(save)
    local archive, loadErr = A.load()
    return {
      pokemon = #payload.mons,
      itemStacks = itemStacks,
      items = itemCount,
      itemPolicy = payload.itemPolicy,
      money = payload.money,
      nextCycle = lineageOk and not A.readOnly
        and (math.max(0, math.floor(tonumber(archive.cycle) or 0)) + 1)
        or nil,
      readOnly = A.readOnly == true or not lineageOk,
      blockers = daycareBlockers(save),
    }, lineageErr or loadErr
  end

  function A.isEligible(save)
    if type(save) ~= "table" then return false end
    return (type(save.hallOfFame) == "table" and #save.hallOfFame > 0)
      or (type(save.flags) == "table"
        and save.flags.EVENT_BEAT_CHAMPION_RIVAL == true)
  end

  A.copy = copy
  A.normalize = normalize
  A.pactId = pactId
  A.bankPolicyId = bankPolicyId
  A.bankPolicyVersion = BANK_POLICY_VERSION
  A.classifyItem = function(id)
    local policy = classifyItem(id)
    policy.definition = nil
    return copy(policy)
  end
  A.itemClaimStatus = function(save, id)
    local policy = classifyItem(id)
    if not policy.transferable then
      return false, policy.category, copy(policy)
    end
    if policy.claimMode == "unique_after_mega_access" then
      if not megaAccessReady(save) then
        return false, "mega_access_required", copy(policy)
      end
      return true, megaStoneOwned(save, id) and "already_owned" or "ready",
        copy(policy)
    end
    return true, "ready", copy(policy)
  end
  A.itemPolicyCategories = copy(ITEM_POLICY_CATEGORIES)
  A.hoennRelicStoneIds = copy(LEGACY_PATH_MEGA_STONES)
  A.itemPolicyId = itemPolicyId
  A.itemPolicyVersion = ITEM_POLICY_VERSION
  A.canonicalRunRules = canonicalRunRules
  A.safeRunRulesSnapshot = safeRunRulesSnapshot
  A.runRulesSnapshotVersion = RUN_RULES_SNAPSHOT_VERSION
  function A.bindData(data)
    if type(data) ~= "table" or type(data.pokemon) ~= "table"
        or type(data.items) ~= "table" or type(data.moves) ~= "table" then
      registryValidation = false
      return false, "Legacy registry validation needs Pokémon, item and move data"
    end
    registries.pokemon, registries.items, registries.moves =
      data.pokemon, data.items, data.moves
    registryValidation = true
    return true
  end
  function A.setWithdrawalGate(gate)
    assert(gate == nil or type(gate) == "function",
      "Legacy withdrawal gate must be a function")
    withdrawalGate = gate
    return true
  end
  function A.journeyBlockers(save)
    return copy(daycareBlockers(save))
  end
  function A.quarantine()
    local archive, err = A.load()
    return copy(type(archive.quarantine) == "table" and archive.quarantine
      or { bank = {}, items = {} }), err
  end
  A.isKnownTitle = function(id)
    return achievementTitleIds[tostring(id or "")] == true
      or legacyTitleProgress[tostring(id or "")] ~= nil
  end
  return A
end
