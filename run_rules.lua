-- KA-INTERNAL: RUN-RULES-001

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local shinySystem = opts.shinySystem
  local mythicSafety = opts.mythicSafety
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  local R = { game = nil, pool = {}, byId = {}, roots = {}, stages = {},
    pendingWild = {} }
  local RUN_RULES_VERSION = 3
  local LEGACY_SNAPSHOT_VERSION = 1
  local LEGACY_PLAYER_PC_BRIDGE_KEY =
    "__kantoAscendantRunRulesPlayerPC0186"

  local LEGENDARY = {
    ARTICUNO = true, ZAPDOS = true, MOLTRES = true, MEWTWO = true,
    MEW = true, RAIKOU = true, ENTEI = true, SUICUNE = true,
    LUGIA = true, HO_OH = true, CELEBI = true,
  }
  local STARTERS = {
    BULBASAUR = true, CHARMANDER = true, SQUIRTLE = true, PIKACHU = true,
    CHIKORITA = true, CYNDAQUIL = true, TOTODILE = true,
  }
  local PRESETS = { "standard", "gentle", "classic", "ascendant", "chaos" }
  local MODES = { "off", "standard", "shiny_clause", "shinylocke" }
  local ODDS = { 8192, 4096, 1024, 256 }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function boundaryActive(game)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(game or R.game)
  end

  local function clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = clone(child) end
    return out
  end

  local function bucket(save)
    save.modData = type(save.modData) == "table" and save.modData or {}
    save.modData[mod.id] = type(save.modData[mod.id]) == "table"
      and save.modData[mod.id] or {}
    return save.modData[mod.id]
  end

  local function hasProgress(save)
    if type(save.party) == "table" and #save.party > 0 then return true end
    local owned = save.pokedex and save.pokedex.owned
    if type(owned) == "table" then
      for _, value in pairs(owned) do if value then return true end end
    end
    local inventory = save.inventory
    if type(inventory) == "table" then
      for _, badge in ipairs({ "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE",
          "RAINBOWBADGE", "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE",
          "EARTHBADGE" }) do
        if inventory[badge] then return true end
      end
    end
    return false
  end

  local function newSeed(save, salt)
    local name = save and save.player and save.player.name or "RED"
    local value = ((os.time() or 1) + (tonumber(salt) or 0) * 104729)
      % 100000000
    for index = 1, #name do
      value = (value * 131 + name:byte(index) * index) % 100000000
    end
    return math.max(1, value)
  end

  -- Legacy Journey stores a data-only draft in the external archive before
  -- the source save is retired.  Old v6 pending journeys have no such draft;
  -- derive their safe OFF seed from immutable lineage data instead of time so
  -- retries and power-loss recovery always create the same contract.
  local function lineageSeed(save)
    local player = type(save and save.player) == "table" and save.player or {}
    local b = type(save and save.modData) == "table" and save.modData[mod.id]
    local run = type(b) == "table" and b.legacy_journey or nil
    local text = table.concat({
      tostring(type(run) == "table" and run.runId or "legacy-v6"),
      tostring(type(run) == "table" and run.cycle or 0),
      tostring(player.id or 0), tostring(player.name or "PLAYER"),
      tostring(save and save.version or "unknown"),
    }, ":")
    local value = 2166136261 % 100000000
    for index = 1, #text do
      value = (value * 16777619 + text:byte(index) * index) % 100000000
    end
    return math.max(1, math.floor(value))
  end

  local function defaults(save, progressed)
    return {
      version = RUN_RULES_VERSION, configured = false, locked = false,
      -- Imported/pre-6.5 saves get one explicit, default-NO chance to start
      -- the challenge rules from their current point.  Story progress alone
      -- must not silently turn the bedroom controls into a read-only screen.
      legacyProgress = progressed == true,
      preset = "standard", seed = newSeed(save), failed = false,
      randomizer = {
        enabled = false, wild = true, trainers = true, starters = true,
        gifts = false, static = false, items = false, legendary = false,
        balanced = true, consistent = true,
      },
      nuzlocke = {
        mode = "off", dupes = true, blackout = "end", shinyOdds = 4096,
      },
      mappings = { species = {}, items = {} }, areas = {}, deaths = {},
      encounterSerial = 0,
    }
  end

  local function canonicalLegacySnapshot(raw, fallbackSave)
    if raw == nil then
      local safe = defaults(fallbackSave, false)
      safe.seed = lineageSeed(fallbackSave)
      return {
        version = LEGACY_SNAPSHOT_VERSION,
        preset = "standard", seed = safe.seed,
        randomizer = clone(safe.randomizer),
        nuzlocke = clone(safe.nuzlocke),
      }
    end
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
    if math.floor(tonumber(raw.version) or 0) ~= LEGACY_SNAPSHOT_VERSION then
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
    local mode = tostring(sourceNuzlocke.mode or ""):lower()
    local modes = { off = true, standard = true, shiny_clause = true,
      shinylocke = true }
    if not modes[mode] or type(sourceNuzlocke.dupes) ~= "boolean"
        or sourceNuzlocke.blackout ~= "end" then
      return nil, "Legacy Nuzlocke snapshot is invalid"
    end
    local odds = math.floor(tonumber(sourceNuzlocke.shinyOdds) or 0)
    local validOdds = { [8192] = true, [4096] = true,
      [1024] = true, [256] = true }
    if not validOdds[odds] then
      return nil, "Legacy Nuzlocke shiny odds are invalid"
    end
    return {
      version = LEGACY_SNAPSHOT_VERSION,
      preset = preset,
      seed = math.max(1, math.floor(seed)),
      randomizer = randomizer,
      nuzlocke = {
        mode = mode, dupes = sourceNuzlocke.dupes,
        blackout = "end", shinyOdds = odds,
      },
    }
  end

  local function newLegacyDraft(save, raw)
    local snapshot, err
    if raw ~= nil then
      snapshot, err = canonicalLegacySnapshot(raw, save)
      if not snapshot then return nil, err end
    else
      local fresh = defaults(save, false)
      snapshot = {
        version = LEGACY_SNAPSHOT_VERSION,
        preset = fresh.preset, seed = fresh.seed,
        randomizer = clone(fresh.randomizer),
        nuzlocke = clone(fresh.nuzlocke),
      }
    end
    snapshot.locked, snapshot.configured = false, false
    snapshot.mappings = { species = {}, items = {} }
    return snapshot
  end

  local function snapshotFromLegacyDraft(draft, save)
    if type(draft) ~= "table" then
      return nil, "Legacy run-rules draft is missing"
    end
    return canonicalLegacySnapshot({
      version = LEGACY_SNAPSHOT_VERSION,
      preset = draft.preset, seed = draft.seed,
      randomizer = clone(draft.randomizer),
      nuzlocke = clone(draft.nuzlocke),
    }, save)
  end

  local function finalRulesSnapshot(s)
    return {
      preset = s.preset,
      seed = math.max(1, math.floor(tonumber(s.seed) or 1)),
      poolDexMax = tonumber(s.poolDexMax) == 251 and 251 or 151,
      randomizer = clone(s.randomizer),
      nuzlocke = clone(s.nuzlocke),
      mappings = clone(s.mappings or { species = {}, items = {} }),
    }
  end

  local function enforceFinalRules(s)
    local final = type(s.finalRules) == "table" and s.finalRules or nil
    if not (s.locked and final) then return end
    s.preset = final.preset or s.preset
    s.seed = math.max(1, math.floor(tonumber(final.seed) or s.seed or 1))
    s.poolDexMax = tonumber(final.poolDexMax) == 251 and 251 or 151
    s.randomizer = clone(final.randomizer or s.randomizer)
    s.nuzlocke = clone(final.nuzlocke or s.nuzlocke)
    s.mappings = clone(final.mappings or s.mappings)
    s.mappings.species = type(s.mappings.species) == "table"
      and s.mappings.species or {}
    s.mappings.items = type(s.mappings.items) == "table"
      and s.mappings.items or {}
    -- A Nuzlocke blackout is deliberately final.  Older draft builds offered
    -- a CONTINUE switch; the confirmed 6.5 contract has no soft mode.
    s.nuzlocke.blackout = "end"
  end

  local function normalize(save, game)
    local b = bucket(save)
    local s = b.run_rules
    if type(s) ~= "table" then
      s = defaults(save, game and hasProgress(save))
      b.run_rules = s
    end
    local previousVersion = math.floor(tonumber(s.version) or 1)
    -- Older builds could lock a save merely because a wild/trainer encounter
    -- occurred, or because imported progress existed. Neither path showed the
    -- irreversible confirmation. Version 3 repairs exactly those automatic
    -- shapes; an old `player_pc` receipt came from the explicit YES choice and
    -- remains locked.
    local automaticOldLock = s.lockReason == nil
      or s.lockReason == "first_encounter"
      or s.lockReason == "first_trainer"
      or s.lockReason == "started"
    if previousVersion < RUN_RULES_VERSION and s.locked == true
        and automaticOldLock then
      s.locked = false
      s.configured = false
      s.legacyProgress = true
      s.migrationNoticePending = true
      s.lockReason = nil
      s.finalRules = nil
    end
    s.version = RUN_RULES_VERSION
    if s.legacyProgress == nil then
      s.legacyProgress = game and hasProgress(save) or false
    end
    s.randomizer = type(s.randomizer) == "table" and s.randomizer
      or defaults(save, false).randomizer
    s.nuzlocke = type(s.nuzlocke) == "table" and s.nuzlocke
      or defaults(save, false).nuzlocke
    s.mappings = type(s.mappings) == "table" and s.mappings or {}
    s.mappings.species = type(s.mappings.species) == "table"
      and s.mappings.species or {}
    s.mappings.items = type(s.mappings.items) == "table"
      and s.mappings.items or {}
    s.areas = type(s.areas) == "table" and s.areas or {}
    s.deaths = type(s.deaths) == "table" and s.deaths or {}
    s.seed = math.max(1, math.floor(tonumber(s.seed) or newSeed(save)))
    s.encounterSerial = math.max(0,
      math.floor(tonumber(s.encounterSerial) or 0))
    s.nuzlocke.blackout = "end"
    if s.locked and type(s.finalRules) ~= "table" then
      -- One-time migration for genuinely started RC25/RC26 runs.  Their
      -- current saved choices become the immutable per-save contract; no
      -- machine-global state is introduced.
      s.poolDexMax = tonumber(s.poolDexMax) == 251 and 251
        or (boundaryActive(game) and 251 or 151)
      s.finalRules = finalRulesSnapshot(s)
    end
    enforceFinalRules(s)
    return s
  end

  local function saveNow(game)
    if game and game.writeSave then return game:writeSave() end
    return true
  end

  local function retireLegacyPlayerPCBridge()
    local okPC, PlayerPC = pcall(require, "src.ui.PlayerPC")
    if not (okPC and type(PlayerPC) == "table") then return false end
    local prior = rawget(PlayerPC, LEGACY_PLAYER_PC_BRIDGE_KEY)
    if type(prior) ~= "table" then return true end
    -- The old wrapper's restore first marks itself inactive. Even if another
    -- owner wrapped it later and direct restoration is no longer possible,
    -- it can never inject ASC RUN into an ordinary Player PC again.
    if type(prior.restore) == "function" then pcall(prior.restore) end
    prior.active = false
    return true
  end

  local function applyPreset(s, id)
    if s.locked then return false end
    s.preset = id
    local r = s.randomizer
    if id == "standard" then
      r.enabled = false
    else
      r.enabled = true
      r.wild, r.trainers, r.starters = true, true, true
      r.gifts = id ~= "gentle"
      r.static = id ~= "gentle"
      r.items = id == "ascendant" or id == "chaos"
      r.legendary = id == "chaos"
      r.balanced = id ~= "chaos"
      r.consistent = true
    end
    s.mappings = { species = {}, items = {} }
    return true
  end

  local function cycle(list, value)
    for index, candidate in ipairs(list) do
      if candidate == value then return list[index % #list + 1] end
    end
    return list[1]
  end

  local function cycleDirection(list, value, direction)
    local index = 1
    for current, candidate in ipairs(list) do
      if candidate == value then index = current break end
    end
    local step = tonumber(direction) and tonumber(direction) < 0 and -1 or 1
    return list[((index - 1 + step) % #list) + 1]
  end

  local function modeLabel(mode)
    return ({
      off = tr("OFF", "AUS"), standard = tr("STANDARD", "STANDARD"),
      shiny_clause = tr("SHINY CLAUSE", "SHINY-KLAUSEL"),
      shinylocke = tr("SHINYLOCKE", "SHINYLOCKE"),
    })[mode] or tostring(mode)
  end

  local function boolLabel(value)
    return value and tr("ON", "AN") or tr("OFF", "AUS")
  end

  local function lock(game, reason)
    local s = normalize(game.save, game)
    if s.locked then return s end
    s.nuzlocke.blackout = "end"
    s.poolDexMax = boundaryActive(game) and 251 or 151
    s.locked, s.configured, s.lockReason = true, true,
      reason or "explicit_start"
    s.finalRules = finalRulesSnapshot(s)
    saveNow(game)
    return s
  end

  local function legacyContractMatches(s, snapshot, poolDexMax)
    if type(s) ~= "table" or s.locked ~= true
        or s.lockReason ~= "legacy_start"
        or tonumber(s.poolDexMax) ~= poolDexMax
        or tonumber(s.seed) ~= snapshot.seed
        or tostring(s.preset) ~= snapshot.preset then return false end
    for _, key in ipairs({ "enabled", "wild", "trainers", "starters",
        "gifts", "static", "items", "legendary", "balanced",
        "consistent" }) do
      if s.randomizer == nil
          or s.randomizer[key] ~= snapshot.randomizer[key] then return false end
    end
    local coreMatches = type(s.nuzlocke) == "table"
      and s.nuzlocke.mode == snapshot.nuzlocke.mode
      and s.nuzlocke.dupes == snapshot.nuzlocke.dupes
      and s.nuzlocke.blackout == "end"
      and tonumber(s.nuzlocke.shinyOdds) == snapshot.nuzlocke.shinyOdds
    if not coreMatches then return false end
    local function exact(left, right, seen)
      if type(left) ~= type(right) then return false end
      if type(left) ~= "table" then return left == right end
      seen = seen or {}
      if seen[left] == right then return true end
      seen[left] = right
      for key, value in pairs(left) do
        if not exact(value, right[key], seen) then return false end
      end
      for key in pairs(right) do
        if left[key] == nil then return false end
      end
      return true
    end
    local expectedFinal = {
      preset = snapshot.preset, seed = snapshot.seed,
      poolDexMax = poolDexMax,
      randomizer = clone(snapshot.randomizer),
      nuzlocke = clone(snapshot.nuzlocke),
      mappings = { species = {}, items = {} },
    }
    return exact(s.finalRules, expectedFinal)
      and exact(s.mappings, expectedFinal.mappings)
  end

  -- Pure save mutation used only by the fresh Legacy Lab. It performs no
  -- write and never consults the old source save. The caller owns the single
  -- atomic persistence boundary together with the permanent 151/251 choice.
  local function seedLegacy(save, archivedSnapshot, poolDexMax)
    if type(save) ~= "table" then
      return nil, "Legacy run rules need a fresh save"
    end
    poolDexMax = tonumber(poolDexMax) == 251 and 251
      or tonumber(poolDexMax) == 151 and 151 or nil
    if not poolDexMax then
      return nil, "Legacy run rules need a final 151/251 pool"
    end
    local snapshot, err = canonicalLegacySnapshot(archivedSnapshot, save)
    if not snapshot then return nil, err end
    local b = bucket(save)
    if legacyContractMatches(b.run_rules, snapshot, poolDexMax) then
      return b.run_rules, nil, false
    end
    local seeded = defaults(save, false)
    seeded.preset = snapshot.preset
    seeded.seed = snapshot.seed
    seeded.randomizer = clone(snapshot.randomizer)
    seeded.nuzlocke = clone(snapshot.nuzlocke)
    seeded.nuzlocke.blackout = "end"
    seeded.poolDexMax = poolDexMax
    seeded.locked, seeded.configured = true, true
    seeded.lockReason = "legacy_start"
    seeded.legacyProgress = false
    seeded.failed = false
    seeded.mappings = { species = {}, items = {} }
    seeded.areas, seeded.deaths, seeded.encounterSerial = {}, {}, 0
    seeded.finalRules = finalRulesSnapshot(seeded)
    b.run_rules = seeded
    return seeded, nil, true
  end

  local function poolMaxDex(game)
    local save = game and game.save
    local s = save and save.modData and save.modData[mod.id]
      and save.modData[mod.id].run_rules
    if type(s) == "table" and s.locked
        and (tonumber(s.poolDexMax) == 151 or tonumber(s.poolDexMax) == 251) then
      return tonumber(s.poolDexMax)
    end
    return boundaryActive(game) and 251 or 151
  end

  local function buildPool(game)
    R.pool, R.byId, R.roots, R.stages = {}, {}, {}, {}
    local maxDex = poolMaxDex(game)
    local byDex = {}
    for id, def in pairs(game.data.pokemon or {}) do
      local dex = math.floor(tonumber(def.dex) or 0)
      if dex >= 1 and dex <= maxDex and type(def.baseStats) == "table" then
        local current = byDex[dex]
        if not current or id == def.id or id < current.id then
          byDex[dex] = { id = id, def = def }
        end
      end
    end
    for dex = 1, maxDex do
      local row = byDex[dex]
      if row then
        row.bst = 0
        for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
          row.bst = row.bst + (tonumber(row.def.baseStats[key]) or 0)
        end
        R.pool[#R.pool + 1] = row
        R.byId[row.id] = row
      end
    end
    local parent = {}
    for _, row in ipairs(R.pool) do
      for _, evo in ipairs(row.def.evolutions or {}) do
        if R.byId[evo.species] then parent[evo.species] = row.id end
      end
    end
    local function rootAndStage(id)
      local seen, stage = {}, 0
      while parent[id] and not seen[id] do
        seen[id], id, stage = true, parent[id], stage + 1
      end
      return id, stage
    end
    for _, row in ipairs(R.pool) do
      R.roots[row.id], R.stages[row.id] = rootAndStage(row.id)
    end
  end

  local function hash(seed, key)
    local value = math.floor(tonumber(seed) or 1) % 2147483647
    for index = 1, #key do
      value = (value * 48271 + key:byte(index) * (index + 17)) % 2147483647
    end
    return value
  end

  local function speciesCandidates(original, settings)
    local source = R.byId[original]
    if not source then return {} end
    local candidates = {}
    for _, row in ipairs(R.pool) do
      if (settings.legendary or not LEGENDARY[row.id]) then
        local stageOK = not settings.balanced
          or R.stages[row.id] == R.stages[original]
        local bstOK = not settings.balanced
          or math.abs(row.bst - source.bst) <= math.max(40, source.bst * .2)
        if stageOK and bstOK then candidates[#candidates + 1] = row end
      end
    end
    if #candidates == 0 then
      for _, row in ipairs(R.pool) do
        if settings.legendary or not LEGENDARY[row.id] then
          candidates[#candidates + 1] = row
        end
      end
    end
    return candidates
  end

  local function randomSpecies(s, original, category)
    local settings = s.randomizer
    local key = settings.consistent and original or (category .. ":" .. original)
    local mapped = s.mappings.species[key]
    if mapped and R.byId[mapped] then return mapped end
    local sourceAllowed = R.byId[original] ~= nil
    if sourceAllowed and LEGENDARY[original] and not settings.legendary then
      return original
    end
    local candidates = sourceAllowed and speciesCandidates(original, settings) or {}
    if #candidates == 0 then
      -- An inherited or third-party source may sit outside the currently
      -- selected save's boundary. Never pass it through unchanged: choose a
      -- deterministic member of the live, boundary-filtered pool instead.
      for _, row in ipairs(R.pool) do
        if settings.legendary or not LEGENDARY[row.id] then
          candidates[#candidates + 1] = row
        end
      end
    end
    if #candidates == 0 then return nil end
    mapped = candidates[hash(s.seed, "species:" .. key) % #candidates + 1].id
    s.mappings.species[key] = mapped
    if s.locked and type(s.finalRules) == "table" then
      s.finalRules.mappings = type(s.finalRules.mappings) == "table"
        and s.finalRules.mappings or { species = {}, items = {} }
      s.finalRules.mappings.species =
        type(s.finalRules.mappings.species) == "table"
        and s.finalRules.mappings.species or {}
      s.finalRules.mappings.species[key] = mapped
    end
    return mapped
  end

  local function mapId(game)
    local ow = game and game.overworld
    return ow and ow.map and ow.map.def and ow.map.def.id
      or ow and ow.map and ow.map.id or "UNKNOWN"
  end

  local function rememberVisibleWild(encounter, ctx)
    if type(encounter) ~= "table" or not encounter.species then
      return encounter, nil
    end
    local ticket = {
      map = (ctx and ctx.mapId) or mapId(R.game),
      species = encounter.species,
      protected = ctx and (ctx.kaProtected == true
        or ctx.kaEncounterSource ~= nil) or false,
      active = true,
    }
    R.pendingWild[#R.pendingWild + 1] = ticket
    if #R.pendingWild > 16 then
      local expired = table.remove(R.pendingWild, 1)
      if expired then expired.active = false end
    end
    return encounter, ticket
  end

  local function cancelVisibleWild(ticket)
    if type(ticket) ~= "table" or not ticket.active then return false end
    for index, pending in ipairs(R.pendingWild) do
      if pending == ticket then
        table.remove(R.pendingWild, index)
        ticket.active = false
        return true
      end
    end
    ticket.active = false
    return false
  end

  local function mapVisibleWild(encounter, ctx)
    local game = R.game
    if not (game and type(encounter) == "table" and encounter.species) then
      return encounter
    end
    local s = normalize(game.save, game)
    if ctx and (ctx.kaProtected or ctx.kaEncounterSource) then
      return encounter
    end
    if not (s.locked and s.randomizer.enabled and s.randomizer.wild) then
      return encounter
    end
    local out = clone(encounter)
    out.species = randomSpecies(s, encounter.species, "wild")
    return out
  end

  local function resolveVisibleWild(encounter, ctx)
    local out = mapVisibleWild(encounter, ctx)
    return rememberVisibleWild(out, ctx)
  end

  local function protectedBattle(battle)
    if not battle or battle.demo or battle.scriptedEncounter then return true end
    if battle.ascendantMythicProtected then return true end
    return mythicSafety and mythicSafety.classify
      and mythicSafety.classify(battle) ~= nil or false
  end

  local function familyOwned(save, species)
    local root = R.roots[species] or species
    local owned = save.pokedex and save.pokedex.owned or {}
    for id, yes in pairs(owned) do
      if yes and (R.roots[id] or id) == root then return true end
    end
    return false
  end

  local function activeNuzlocke(s)
    return s and s.locked == true and not s.failed
      and s.nuzlocke.mode ~= "off"
  end

  local function activeRandomizer(s, key)
    return s and s.locked == true and s.randomizer.enabled == true
      and (key == nil or s.randomizer[key] == true)
  end

  local function clearDead(save)
    local Pokemon = require("src.pokemon.Pokemon")
    local function revive(mon)
      if mon.ascendantNuzlockeDead then
        mon.ascendantNuzlockeDead = nil
        Pokemon.heal(mon)
      end
    end
    for _, mon in ipairs(save.party or {}) do revive(mon) end
    for _, box in ipairs(save.boxes or {}) do
      for _, mon in ipairs(box) do revive(mon) end
    end
  end

  local function installHealPolicy(game)
    local Pokemon = require("src.pokemon.Pokemon")
    if not Pokemon._ascendantRunRulesWrapped then
      local original = Pokemon.heal
      Pokemon.heal = function(mon)
        original(mon)
        local policy = Pokemon._ascendantRunRulesPolicy
        if mon.ascendantNuzlockeDead and policy and policy() then mon.hp = 0 end
      end
      Pokemon._ascendantRunRulesWrapped = true
    end
    Pokemon._ascendantRunRulesPolicy = function()
      return activeNuzlocke(normalize(game.save, game))
    end
  end

  local function pushMessage(game, text, choice)
    game.stack:push(require("src.render.TextBox").new(game, text, nil,
      choice and { defaultNo = true, choice = choice } or nil))
  end

  local openMain
  local function showRowHelp(game, item)
    if not (item and item.help) then return false end
    pushMessage(game, item.help)
    return true
  end

  -- Native ListMenu reserves Left/Right for optional page jumps and exposes
  -- only A as a generic choose callback.  Rule screens are settings, not
  -- action lists: bind the horizontal directions to the visible value and
  -- leave A for explanations, submenus and the explicit START confirmation.
  local function directionalSettings(game, menu, locked, adjust)
    if type(menu) ~= "table" then return menu end
    menu.pageJump = false
    menu.kascDirectionalSettings = true
    menu.onAdjustKey = function(item, direction)
      if locked() then
        return showRowHelp(game, item)
      end
      return adjust(item, direction < 0 and -1 or 1)
    end
    local baseUpdate = menu.update
    if type(baseUpdate) == "function" then
      menu.update = function(self, dt)
        local input = game and game.input
        if input and type(input.wasPressed) == "function" then
          if input:wasPressed("left") then
            self.onAdjustKey(self.items[self.index], -1)
            return
          elseif input:wasPressed("right") then
            self.onAdjustKey(self.items[self.index], 1)
            return
          end
        end
        return baseUpdate(self, dt)
      end
    end
    return menu
  end

  local function openRandomizer(game, s, persistDraft, onChanged)
    local rows = {
      { label = tr("WILD POKéMON", "WILDE POKéMON"), key = "wild",
        help = tr("Randomizes ordinary wild encounters after START RUN.",
          "Mischt normale Wildbegegnungen erst nach LAUF STARTEN.") },
      { label = tr("TRAINERS", "TRAINER"), key = "trainers",
        help = tr("Randomizes trainer teams. Replacement moves are rebuilt for the new species.",
          "Mischt Trainerteams. Attacken werden passend zur Ersatzart neu aufgebaut.") },
      { label = tr("STARTERS", "STARTER"), key = "starters",
        help = tr("Randomizes Oak's starter gifts. The chosen result is fixed by this run's seed.",
          "Mischt Eichs Starter. Das Ergebnis wird durch den Lauf-Seed festgelegt.") },
      { label = tr("GIFT POKéMON", "GESCHENK-POKéMON"), key = "gifts",
        help = tr("Randomizes ordinary gifted POKéMON. Protected story gifts remain authored.",
          "Mischt normale Geschenk-POKéMON. Geschützte Story-Gaben bleiben unverändert.") },
      { label = tr("STATIC POKéMON", "FESTE POKéMON"), key = "static",
        help = tr("Randomizes ordinary static encounters. Authored protected encounters stay unchanged.",
          "Mischt normale feste Begegnungen. Geschützte Story-Begegnungen bleiben unverändert.") },
      { label = tr("FIELD ITEMS", "FUND-ITEMS"), key = "items",
        help = tr("Randomizes safe field items within their category. Key Items, HMs and Badges never change.",
          "Mischt sichere Fund-Items innerhalb ihrer Kategorie. Basis-Items, VMs und Orden bleiben gleich.") },
      { label = tr("LEGENDARIES", "LEGENDÄRE"), key = "legendary",
        help = tr("Allows Legendary and Mythical species in the random pool. Authored protected shadows still stay fixed.",
          "Erlaubt Legendäre und Mysteriöse im Zufallspool. Geschützte Story-Schatten bleiben dennoch fest.") },
      { label = tr("BALANCED POWER", "AUSGEGLICHEN"), key = "balanced",
        help = tr("Keeps replacements near the original evolution stage and strength.",
          "Hält Ersatzarten nahe an Entwicklungsstufe und Stärke des Originals.") },
      { label = tr("CONSISTENT MAP", "FESTE ZUORDNUNG"), key = "consistent",
        help = tr("The same original species always maps to the same replacement for this seed.",
          "Dieselbe Originalart erhält mit diesem Seed immer dieselbe Ersatzart.") },
    }
    for _, row in ipairs(rows) do row.right = boolLabel(s.randomizer[row.key]) end
    local menu = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("RANDOMIZER RULES", "RANDOMIZER-REGELN"), rows, {
        pageJump = false,
        footer = s.locked and tr("SEL:HELP  LOCKED", "SEL:HILFE GESP.")
          or tr("L/R:CHG SEL:HELP", "L/R:ÄND SEL:HILFE"),
        onSelectKey = function(item) return showRowHelp(game, item) end,
        onChoose = function(item)
          return showRowHelp(game, item)
        end,
      })
    directionalSettings(game, menu, function() return s.locked end,
      function(item)
          s.randomizer[item.key] = not s.randomizer[item.key]
          s.preset = "custom"
          s.mappings = { species = {}, items = {} }
          item.right = boolLabel(s.randomizer[item.key])
          if persistDraft ~= false then saveNow(game) end
          if onChanged then onChanged() end
      end)
    game.stack:push(menu)
  end

  local function openNuzlocke(game, s, persistDraft, onChanged)
    local rows = {
      { label = tr("MODE", "MODUS"), key = "mode", right = modeLabel(s.nuzlocke.mode),
        help = tr(
          "OFF disables the challenge. STANDARD counts every ordinary faint. SHINY CLAUSE exempts a Shiny encounter; SHINYLOCKE permits only Shinies. The choice locks at START RUN.",
          "AUS deaktiviert die Challenge. STANDARD zählt jedes normale K. o. Die SHINY-KLAUSEL schützt eine Shiny-Begegnung; SHINYLOCKE erlaubt nur Shinys. Die Wahl sperrt sich bei LAUF STARTEN.") },
      { label = tr("DUPES CLAUSE", "DUPLIKAT-KLAUSEL"), key = "dupes",
        right = boolLabel(s.nuzlocke.dupes),
        help = tr("Blocks another catch from an evolution family you already own.",
          "Sperrt einen weiteren Fang aus einer bereits besessenen Entwicklungsfamilie.") },
      { label = tr("BLACKOUT", "BLACKOUT"), key = "blackout",
        right = tr("RUN ENDS", "LAUF ENDET"),
        help = tr(
          "Hard rule: an ordinary blackout permanently fails this run. It cannot be changed to CONTINUE.",
          "Harte Regel: Ein normaler Blackout beendet diesen Lauf dauerhaft. WEITERSPIELEN ist nicht wählbar.") },
      { label = tr("SHINY ODDS", "SHINY-CHANCE"), key = "shinyOdds",
        right = "1/" .. tostring(s.nuzlocke.shinyOdds),
        help = tr("Deterministic force-roll odds used only by SHINYLOCKE. The odds and seed lock together.",
          "Deterministische Zusatzchance nur für SHINYLOCKE. Chance und Seed werden gemeinsam gesperrt.") },
    }
    local menu = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("NUZLOCKE RULES", "NUZLOCKE-REGELN"), rows, {
        footer = s.locked and tr("SEL:HELP  LOCKED", "SEL:HILFE GESP.")
          or tr("L/R:CHG SEL:HELP", "L/R:ÄND SEL:HILFE"),
        onSelectKey = function(item) return showRowHelp(game, item) end,
        onChoose = function(item)
          return showRowHelp(game, item)
        end,
      })
    directionalSettings(game, menu, function() return s.locked end,
      function(item, direction)
          if item.key == "mode" then
            s.nuzlocke.mode = cycleDirection(MODES, s.nuzlocke.mode, direction)
            item.right = modeLabel(s.nuzlocke.mode)
          elseif item.key == "dupes" then
            s.nuzlocke.dupes = not s.nuzlocke.dupes
            item.right = boolLabel(s.nuzlocke.dupes)
          elseif item.key == "blackout" then
            -- The hard blackout policy is intentionally explanatory and
            -- cannot be changed even with a horizontal input.
            return showRowHelp(game, item)
          else
            s.nuzlocke.shinyOdds = cycleDirection(ODDS,
              s.nuzlocke.shinyOdds, direction)
            item.right = "1/" .. tostring(s.nuzlocke.shinyOdds)
          end
          s.preset = "custom"
          if persistDraft ~= false then saveNow(game) end
          if onChanged then onChanged() end
      end)
    game.stack:push(menu)
  end

  openMain = function(game)
    local s = normalize(game.save, game)
    local effectivePool = s.locked and s.poolDexMax
      or (boundaryActive(game) and 251 or 151)
    local poolText = ("#001-%03d"):format(effectivePool)
    local rows = {
      { label = tr("PRESET", "VORLAGE"), key = "preset",
        right = tostring(s.preset):upper(),
        help = tr("Cycles complete draft rule sets. Nothing applies until the explicit START RUN confirmation.",
          "Wechselt komplette Regelvorlagen. Vor der ausdrücklichen Bestätigung LAUF STARTEN gilt noch nichts.") },
      { label = tr("RANDOMIZER", "RANDOMIZER"), key = "randomizer",
        right = boolLabel(s.randomizer.enabled),
        help = tr("Deterministic Randomizer master switch. Effective pool: ",
          "Hauptschalter des deterministischen Randomizers. Aktiver Pool: ")
          .. poolText .. tr(". OFF at START RUN means it can never be enabled in this save's run.",
            ". AUS bei LAUF STARTEN bedeutet: In diesem Spielstand-Lauf nie nachträglich aktivierbar.") },
      { label = tr("NUZLOCKE", "NUZLOCKE"), key = "nuzlocke",
        right = modeLabel(s.nuzlocke.mode),
        help = tr("One-time Nuzlocke mode. Ordinary faints count and a blackout ends the run. Authored Mew/Celebi shadow trials do not count and return safely.",
          "Einmaliger Nuzlocke-Modus. Normale K. o. zählen, ein Blackout beendet den Lauf. Geschützte Mew-/Celebi-Schattenprüfungen zählen nicht und bringen dich sicher zurück.") },
      { label = tr("RANDOMIZER RULES", "RANDOMIZER-REGELN"), key = "randomRules",
        help = tr("Opens every Randomizer subrule. All choices and mappings become read-only after START RUN.",
          "Öffnet alle Randomizer-Unterregeln. Nach LAUF STARTEN sind Auswahl und Zuordnungen nur noch lesbar.") },
      { label = tr("NUZLOCKE RULES", "NUZLOCKE-REGELN"), key = "nuzRules",
        help = tr("Opens Nuzlocke clauses and the fixed hard-blackout rule.",
          "Öffnet Nuzlocke-Klauseln und die feste harte Blackout-Regel.") },
      { label = tr("SEED", "SEED"), key = "seed", right = tostring(s.seed),
        help = tr("Creates every deterministic Randomizer mapping. It can be rerolled only before START RUN.",
          "Erzeugt alle deterministischen Randomizer-Zuordnungen. Neu würfeln geht nur vor LAUF STARTEN.") },
      { label = s.locked and tr("RUN ACTIVE", "LAUF AKTIV")
          or tr("START RUN", "LAUF STARTEN"), key = "start",
        help = tr("Shows the final safety confirmation. YES permanently locks these rules for this save and Ascendant run; only a genuinely new Legacy save/run can configure again.",
          "Zeigt die letzte Sicherheitsabfrage. JA sperrt diese Regeln dauerhaft für diesen Spielstand und Ascendant-Lauf; nur ein wirklich neuer Vermächtnis-Spielstand/-Lauf darf neu wählen.") },
    }
    local list
    list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("ASCENDANT RUN", "ASCENDANT-LAUF"), rows, {
        pageJump = false,
        footer = s.locked and tr("SEL:HELP  LOCKED", "SEL:HILFE GESP.")
          or tr("L/R:CHG SEL:HELP", "L/R:ÄND SEL:HILFE"),
        onSelectKey = function(item) return showRowHelp(game, item) end,
        onChoose = function(item)
          if item.key == "randomRules" then return openRandomizer(game, s, true) end
          if item.key == "nuzRules" then return openNuzlocke(game, s, true) end
          if s.locked then
            return pushMessage(game, tr(
              "This run has started.\nIts rules cannot change.",
              "Dieser Lauf läuft.\nRegeln sind gesperrt."))
          end
          if item.key == "start" then
            -- Every explicit page stays within the Gen-I box's two visible
            -- lines in both languages. The final YES/NO therefore cannot hide
            -- a setting below a scrolled line.
            local warning = tr("FINAL RULE CHECK!", "LETZTE REGELPRÜFUNG!")
              .. "\f" .. tr("RANDOMIZER:", "RANDOMIZER:") .. "\n"
              .. boolLabel(s.randomizer.enabled)
              .. "\f" .. tr("NUZLOCKE:", "NUZLOCKE:") .. "\n"
              .. modeLabel(s.nuzlocke.mode)
              .. "\f" .. tr("POKéDEX POOL:", "POKéDEX-POOL:") .. "\n"
              .. poolText
              .. "\fSEED:\n" .. tostring(s.seed) .. "\f"
            if s.legacyProgress then
              warning = warning .. tr(
                "EXISTING SAVE:\nACTIVE FROM NOW.\fPAST CATCHES STAY\nUNCHANGED.\f",
                "ALTER SPIELSTAND:\nAB JETZT AKTIV.\fFRÜHERE FÄNGE\nBLEIBEN ERHALTEN.\f")
            end
            if s.nuzlocke.mode ~= "off" then
              warning = warning .. tr(
                "FAINTS COUNT.\nBLACKOUT ENDS RUN.\fMEW/CELEBI SHADOWS\nARE EXEMPT.\fTHEY RETURN SAFELY.\f",
                "NORMALE K. O.\nZÄHLEN DAUERHAFT.\fBLACKOUT BEENDET\nDEN LAUF.\fMEW/CELEBI-\nSCHATTEN: FREI.\fSIE KEHREN SICHER\nZURÜCK.\f")
            end
            warning = warning .. tr(
              "LOCK RULES\nFOREVER?\fSETTINGS CANNOT\nCHANGE LATER.",
              "REGELN DAUERHAFT\nSPERREN?\fSPÄTER NICHT MEHR\nÄNDERBAR.")
            pushMessage(game, warning,
              function(yes)
                if yes then
                  lock(game, "explicit_start")
                  buildPool(game)
                  s.migrationNoticePending = nil
                  item.label = tr("RUN ACTIVE", "LAUF AKTIV")
                  list.footer = tr("SEL:HELP  LOCKED", "SEL:HILFE GESP.")
                end
              end)
          else
            return showRowHelp(game, item)
          end
        end,
      })
    directionalSettings(game, list, function() return s.locked end,
      function(item, direction)
        if item.key == "preset" then
          applyPreset(s, cycleDirection(PRESETS, s.preset, direction))
          item.right = s.preset:upper()
          rows[2].right = boolLabel(s.randomizer.enabled)
          rows[3].right = modeLabel(s.nuzlocke.mode)
        elseif item.key == "randomizer" then
          s.randomizer.enabled = not s.randomizer.enabled
          s.preset = "custom"
          item.right = boolLabel(s.randomizer.enabled)
          rows[1].right = "CUSTOM"
        elseif item.key == "nuzlocke" then
          s.nuzlocke.mode = cycleDirection(MODES, s.nuzlocke.mode, direction)
          s.preset = "custom"
          item.right = modeLabel(s.nuzlocke.mode)
          rows[1].right = "CUSTOM"
        elseif item.key == "seed" then
          s.seed = newSeed(game.save, s.seed + direction)
          s.mappings = { species = {}, items = {} }
          item.right = tostring(s.seed)
        else
          return showRowHelp(game, item)
        end
        saveNow(game)
      end)
    game.stack:push(list)
  end

  -- Legacy Journey owns the only irreversible confirmation. This screen
  -- edits a detached table, never the source save; CONTINUE merely returns a
  -- validated archive snapshot to Oak's reset flow.
  local function openLegacyDraft(game, draft, onDone)
    local s, draftErr = newLegacyDraft(game and game.save, draft)
    if not s then return nil, draftErr end
    local rows = {
      { label = tr("RANDOMIZER PROFILE", "RANDOMIZER-PROFIL"), key = "preset",
        right = tostring(s.preset):upper(),
        help = tr(
          "Changes only the Randomizer profile. Nuzlocke is a separate rule and never changes with this row.",
          "Ändert nur das Randomizer-Profil. Nuzlocke ist eine eigene Regel und ändert sich hier niemals.") },
      { label = tr("RANDOMIZER", "RANDOMIZER"), key = "randomizer",
        right = boolLabel(s.randomizer.enabled),
        help = tr(
          "Master switch for deterministic species and item mappings. The final 151/251 pool is chosen in Oak's Lab before partner selection.",
          "Hauptschalter für deterministische Arten- und Item-Zuordnungen. Den endgültigen 151/251-Pool wählst du vor der Partnerwahl in Eichs Labor.") },
      { label = tr("NUZLOCKE", "NUZLOCKE"), key = "nuzlocke",
        right = modeLabel(s.nuzlocke.mode),
        help = tr(
          "Independent one-time Nuzlocke mode. Ordinary faints count; protected Mew/Celebi shadow trials remain exempt.",
          "Unabhängiger einmaliger Nuzlocke-Modus. Normale K. o. zählen; geschützte Mew-/Celebi-Schattenprüfungen bleiben ausgenommen.") },
      { label = tr("RANDOMIZER RULES", "RANDOMIZER-REGELN"),
        key = "randomRules",
        help = tr("Opens every Randomizer category and balance rule.",
          "Öffnet alle Randomizer-Kategorien und Balance-Regeln.") },
      { label = tr("NUZLOCKE RULES", "NUZLOCKE-REGELN"), key = "nuzRules",
        help = tr("Opens encounter clauses, shiny odds and the fixed hard-blackout rule.",
          "Öffnet Begegnungsklauseln, Shiny-Chance und die feste harte Blackout-Regel.") },
      { label = tr("SEED", "SEED"), key = "seed", right = tostring(s.seed),
        help = tr(
          "Rerolls the deterministic seed. A failed save or power-loss retry keeps the archived confirmed seed.",
          "Würfelt den deterministischen Seed neu. Nach Speicherfehler oder Stromausfall bleibt der bestätigte Archiv-Seed erhalten.") },
      { label = tr("CONTINUE", "WEITER"), key = "done",
        help = tr(
          "Returns to Oak's review. Nothing is active or locked until the final default-NO Legacy confirmation.",
          "Kehrt zu Eichs Prüfung zurück. Vor der letzten, auf NEIN stehenden Vermächtnis-Bestätigung ist nichts aktiv oder gesperrt.") },
    }
    local list
    local function refresh()
      rows[1].right = tostring(s.preset):upper()
      rows[2].right = boolLabel(s.randomizer.enabled)
      rows[3].right = modeLabel(s.nuzlocke.mode)
      rows[6].right = tostring(s.seed)
    end
    list = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("LEGACY RUN RULES", "VERMÄCHTNIS-REGELN"), rows, {
        pageJump = false,
        footer = tr("L/R:CHG SEL:HELP", "L/R:ÄND SEL:HILFE"),
        onSelectKey = function(item) return showRowHelp(game, item) end,
        onChoose = function(item)
          if item.key == "randomRules" then
            return openRandomizer(game, s, false, refresh)
          elseif item.key == "nuzRules" then
            return openNuzlocke(game, s, false, refresh)
          elseif item.key == "done" then
            local snapshot, err = snapshotFromLegacyDraft(s, game.save)
            if not snapshot then return nil, err end
            if game.stack and game.stack.top and game.stack:top() == list then
              game.stack:pop()
            end
            if onDone then onDone(snapshot) end
            return snapshot
          end
          return showRowHelp(game, item)
        end,
      })
    directionalSettings(game, list, function() return false end,
      function(item, direction)
        if item.key == "preset" then
          applyPreset(s, cycleDirection(PRESETS, s.preset, direction))
        elseif item.key == "randomizer" then
          s.randomizer.enabled = not s.randomizer.enabled
          s.preset = "custom"
          s.mappings = { species = {}, items = {} }
        elseif item.key == "nuzlocke" then
          s.nuzlocke.mode = cycleDirection(MODES, s.nuzlocke.mode, direction)
          s.preset = "custom"
        elseif item.key == "seed" then
          s.seed = newSeed(game.save, s.seed + direction)
          s.mappings = { species = {}, items = {} }
        else
          return showRowHelp(game, item)
        end
        refresh()
      end)
    game.stack:push(list)
    return s
  end

  mod.hooks:wrap("battle.wild", function(nextEncounter, encounter, ctx)
    local game = ctx and ctx.game
    if not (game and encounter and encounter.species) then
      return nextEncounter(encounter, ctx)
    end
    local source = ctx.source
    local scripted = ctx.opts and (ctx.opts.scriptedEncounter
      or ctx.opts.randomizerProtected)
    if (source == "wild" or source == "static") and not scripted then
      local s = normalize(game.save, game)
      local enabled = source == "wild" and s.randomizer.wild
        or source == "static" and s.randomizer.static
      if source == "wild" then
        local currentMap = mapId(game)
        for index, pending in ipairs(R.pendingWild) do
          if (pending.map == currentMap or pending.protected)
              and pending.species == encounter.species then
            table.remove(R.pendingWild, index)
            pending.active = false
            return nextEncounter(encounter, ctx)
          end
        end
      end
      if s.locked and s.randomizer.enabled and enabled then
        local out = clone(encounter)
        out.species = randomSpecies(s, encounter.species, source)
        return nextEncounter(out, ctx)
      end
    end
    return nextEncounter(encounter, ctx)
  end, 100)

  -- Resolve grass/cave encounters before visible-wild providers render them.
  -- battle.wild consumes the marker later so the same candidate is not mapped
  -- twice. Fishing has no encounter.species phase and is handled there only.
  mod.hooks:wrap("encounter.species", function(nextEncounter, encounter, ctx)
    local game = R.game
    local resolved = nextEncounter(encounter, ctx)
    if not (game and type(resolved) == "table" and resolved.species) then
      return resolved
    end
    return resolveVisibleWild(resolved, ctx)
  end, 100)

  mod.hooks:wrap("trainer.party", function(nextParty, class, index, party)
    local game = R.game
    if not game then return nextParty(class, index, party) end
    local s = normalize(game.save, game)
    local resolved = nextParty(class, index, party)
    if not (activeRandomizer(s, "trainers")
        and type(resolved) == "table") then return resolved end
    local out = clone(resolved)
    for slot, row in ipairs(out) do
      row.species = randomSpecies(s, row.species,
        "trainer:" .. tostring(class) .. ":" .. tostring(index) .. ":" .. slot)
      row.moves = nil
    end
    return out
  end, 70)

  mod.events:on("pokemon.before_give", function(gift)
    local game = gift and gift.ctx and gift.ctx.game or R.game
    if not (game and gift and gift.species) then return end
    local s = normalize(game.save, game)
    local starter = STARTERS[gift.species] and mapId(game) == "OAKS_LAB"
    local enabled = starter and s.randomizer.starters or s.randomizer.gifts
    if s.locked and s.randomizer.enabled and enabled then
      gift.species = randomSpecies(s, gift.species,
        starter and "starter" or "gift")
    end
  end, 100)

  local function itemCategory(id)
    id = tostring(id)
    if id:find("BALL", 1, true) then return "ball" end
    if id:find("STONE", 1, true) then return "stone" end
    if id:match("^TM_") then return "tm" end
    return "general"
  end

  local function itemAllowed(game, id)
    local row = game and game.data and game.data.items
      and game.data.items[id]
    if not row then return false end
    if boundaryActive(game) then return true end
    -- Engine 0.1.86 carries an authoritative ROM provenance on every
    -- original Red/Blue item and TM. Mod-added Apricorn, evolution, HEVO and
    -- postgame items have no ROM source and stay outside a sealed run.
    return type(row.source) == "string"
      and row.source:sub(1, 4) == "ROM:"
  end

  local function randomItem(game, s, original)
    local def = game.data.items[original]
    if not def or def.keyItem or def.tossable == false
        or tostring(original):match("^HM_")
        or tostring(original):find("BADGE", 1, true) then return original end
    local key = tostring(original)
    if s.mappings.items[key]
        and itemAllowed(game, s.mappings.items[key]) then
      return s.mappings.items[key]
    end
    local category, candidates = itemCategory(original), {}
    for id, row in pairs(game.data.items or {}) do
      if not row.keyItem and row.tossable ~= false and not tostring(id):match("^HM_")
          and not tostring(id):find("BADGE", 1, true)
          and itemAllowed(game, id)
          and itemCategory(id) == category then candidates[#candidates + 1] = id end
    end
    table.sort(candidates)
    if #candidates == 0 then return original end
    local mapped = candidates[hash(s.seed, "item:" .. key) % #candidates + 1]
    s.mappings.items[key] = mapped
    if s.locked and type(s.finalRules) == "table" then
      s.finalRules.mappings = type(s.finalRules.mappings) == "table"
        and s.finalRules.mappings or { species = {}, items = {} }
      s.finalRules.mappings.items = type(s.finalRules.mappings.items) == "table"
        and s.finalRules.mappings.items or {}
      s.finalRules.mappings.items[key] = mapped
    end
    return mapped
  end

  mod.hooks:wrap("script.command", function(nextCommand, ctx, name, args)
    local game = ctx and ctx.game
    local s = game and normalize(game.save, game)
    if name == "give_item" and activeRandomizer(s, "items")
        and s.randomizer.items and type(args) == "table" then
      args = clone(args)
      args[1] = randomItem(game, s, args[1])
    end
    return nextCommand(ctx, name, args)
  end, 80)

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    local game = battle and battle.game
    if not (game and battle.kind == "wild") or protectedBattle(battle) then return end
    local s = normalize(game.save, game)
    if not activeNuzlocke(s) then return end
    s.encounterSerial = s.encounterSerial + 1
    local mon = battle.enemy and battle.enemy.mon
    if not mon then return end
    if s.nuzlocke.mode == "shinylocke" and shinySystem
        and not shinySystem.isShiny(mon)
        and hash(s.seed, "shiny:" .. s.encounterSerial)
          % math.max(1, s.nuzlocke.shinyOdds) == 0 then
      shinySystem.forceMon(mon, game.data.pokemon[mon.species])
    end
    local shiny = shinySystem and shinySystem.isShiny(mon) or false
    if s.nuzlocke.mode == "shinylocke" and not shiny then
      battle.noCatch = true
      battle.ascendantNuzlockeReason = "shiny_only"
      return
    end
    local shinyClause = s.nuzlocke.mode == "shiny_clause" and shiny
    if not shinyClause and s.nuzlocke.dupes
        and familyOwned(game.save, mon.species) then
      battle.noCatch = true
      battle.ascendantNuzlockeReason = "duplicate"
      return
    end
    local area = mapId(game)
    if not shinyClause and s.areas[area] then
      battle.noCatch = true
      battle.ascendantNuzlockeReason = "area_used"
      return
    end
    if not shinyClause then
      s.areas[area] = { species = mon.species,
        family = R.roots[mon.species] or mon.species }
    end
  end, -200)

  mod.events:on("battle.fainted", function(ev)
    local battle, battler = ev and ev.battle, ev and ev.battler
    local game = battle and battle.game
    if not (game and battler and battler.isPlayer and battler.mon)
        or protectedBattle(battle) then return end
    local s = normalize(game.save, game)
    if not activeNuzlocke(s) then return end
    local mon = battler.mon
    if mon.ascendantNuzlockeDead then return end
    mon.ascendantNuzlockeDead = true
    s.deaths[#s.deaths + 1] = {
      species = mon.species, level = mon.level, area = mapId(game),
    }
    -- A faint is a permanent run event, not a deferred UI preference.  Write
    -- it immediately so a reload cannot resurrect the participant.
    saveNow(game)
  end, -250)

  mod.events:on("world.blacked_out", function(ev)
    local game = R.game
    if not (game and ev and ev.save == game.save) then return end
    local s = normalize(game.save, game)
    if not activeNuzlocke(s) then return end
    if mythicSafety and type(mythicSafety.isProtectedReturn) == "function"
        and mythicSafety.isProtectedReturn(ev.save) then
      -- The authored Mew/Celebi shadow loss still uses the engine's normal
      -- heal/return warp.  Only its challenge accounting is exempt.
      return
    end
    s.failed = true
    clearDead(game.save)
    saveNow(game)
  end, -1000)

  function R.install(game)
    R.game = game
    R.pendingWild = {}
    retireLegacyPlayerPCBridge()
    normalize(game.save, game)
    buildPool(game)
    installHealPolicy(game)
  end

  function R.state(save)
    save = save or (R.game and R.game.save)
    return save and normalize(save, R.game) or nil
  end

  R.applyPreset = applyPreset
  R.newLegacyDraft = newLegacyDraft
  R.legacySnapshot = snapshotFromLegacyDraft
  R.seedLegacy = seedLegacy
  R.openLegacyDraft = openLegacyDraft
  R.legacySnapshotVersion = LEGACY_SNAPSHOT_VERSION
  R.buildPool = buildPool
  R.poolMaxDex = poolMaxDex
  R.itemAllowed = itemAllowed
  R.randomItem = randomItem
  R.randomSpecies = randomSpecies
  R.mapVisibleWild = mapVisibleWild
  R.rememberVisibleWild = rememberVisibleWild
  R.cancelVisibleWild = cancelVisibleWild
  R.resolveVisibleWild = resolveVisibleWild
  R.lock = lock
  R.open = openMain
  R.mapId = mapId

  if beyondKanto and type(beyondKanto.onChanged) == "function" then
    beyondKanto.onChanged(function(_, changedGame)
      local game = changedGame or R.game
      if not (game and game.data) then return end
      R.game = game
      local current = normalize(game.save, game)
      buildPool(game)
      R.pendingWild = {}
      -- Drafts can follow an option-boundary change.  A confirmed run keeps
      -- both its 151/251 pool and every existing deterministic mapping.
      if not current.locked then current.mappings.species = {} end
    end)
  end
  return R
end
