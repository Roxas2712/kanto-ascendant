-- Trial-bound wild habitats for the three Hidden Evolution campaigns.
--
-- The fifteen-package registry remains the only authority for which parent
-- species belongs to which character.  Once the rightful traveler has used
-- that color's real wall fissure, every parent needed by that trial can be
-- found from the first floor onward.  Permanent package unlocks deliberately
-- do not gate the habitat: the player is meant to catch and train a candidate
-- on the way to the claim, while final evolutions and Hoenn Journey gifts are
-- never published as wild encounters here.

return function(mod, opts)
  opts = opts or {}
  local packages = assert(opts.packages,
    "HEVO dungeon encounters need the package registry")
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary

  -- These are authored encounter slots, not unordered species pools.  Slot 9
  -- is one of Gen-I's low-probability buckets (11/256) and is deliberately the
  -- sole Gyarados slot for every traveler.  The Beyond layout remains mixed:
  -- its Johto occupants replace ordinary slots without displacing the Kanto
  -- baseline or turning Gyarados into a common encounter.
  local KANTO_WATER_LAYOUTS = {
    RED = {
      "TENTACRUEL", "KINGLER", "TENTACRUEL", "KINGLER", "TENTACRUEL",
      "KINGLER", "TENTACRUEL", "KINGLER", "GYARADOS", "TENTACRUEL",
    },
    BLUE = {
      "DEWGONG", "CLOYSTER", "LAPRAS", "DEWGONG", "CLOYSTER",
      "LAPRAS", "DEWGONG", "CLOYSTER", "GYARADOS", "LAPRAS",
    },
    GREEN = {
      "POLIWHIRL", "GOLDUCK", "SEAKING", "POLIWHIRL", "GOLDUCK",
      "SEAKING", "POLIWHIRL", "GOLDUCK", "GYARADOS", "SEAKING",
    },
  }
  local BEYOND_WATER_LAYOUTS = {
    RED = {
      "QWILFISH", "OCTILLERY", "TENTACRUEL", "QWILFISH", "KINGLER",
      "OCTILLERY", "TENTACRUEL", "QWILFISH", "GYARADOS", "OCTILLERY",
    },
    BLUE = {
      "LANTURN", "MANTINE", "CORSOLA", "DEWGONG", "LANTURN",
      "MANTINE", "CLOYSTER", "CORSOLA", "GYARADOS", "LAPRAS",
    },
    GREEN = {
      "AZUMARILL", "QUAGSIRE", "CORSOLA", "POLIWHIRL", "AZUMARILL",
      "QUAGSIRE", "GOLDUCK", "CORSOLA", "GYARADOS", "SEAKING",
    },
  }

  local E = {
    BASE_LEVEL = 70,
    LEVEL = 70,
    LEVEL_STEP = 5,
    MAX_LEVEL = 100,
    SLOT_COUNT = 10,
    MAX_VISIBLE = 3,
    SOURCE = "hevo_dungeon",
    ENTERED_FLAG_PREFIX = "KA_HEVO_CHARACTER_TUNNEL_ENTERED_",
    RATE = { RED = 15, BLUE = 15, GREEN = 8 },
    WATER_RATE = 5,
    GYARADOS_SLOT = 9,
    -- Native Gen-I encounter bucket widths.  Keeping these on the published
    -- slots lets Visible Wilds preserve the same base odds as classic Surf
    -- instead of treating every authored row as equally common.
    WATER_SLOT_WEIGHTS = { 51, 51, 39, 25, 25, 25, 13, 13, 11, 3 },
    WATER_LAYOUTS = {
      KANTO = KANTO_WATER_LAYOUTS,
      BEYOND = BEYOND_WATER_LAYOUTS,
    },
    -- Compatibility alias for older diagnostics that treated this field as a
    -- pool.  Its rows are now the exact ten-slot Kanto layouts above.
    WATER_SPECIES = KANTO_WATER_LAYOUTS,
    -- OFF uses the same authored maps, scripts and encounter controller.  Only
    -- a non-Kanto package parent is substituted, deterministically, with a
    -- thematically close member of the original 151.  ON restores the exact
    -- authored parent rows without maintaining a second map or script set.
    KANTO_FALLBACK = {
      PILOSWINE = "SANDSLASH", GLIGAR = "SCYTHER",
      SNEASEL = "PERSIAN", PORYGON2 = "PORYGON",
      YANMA = "BUTTERFREE", TOGETIC = "CLEFAIRY",
      AIPOM = "MANKEY", MISDREAVUS = "HAUNTER", MURKROW = "FEAROW",
    },
    WATER_MAPS = {
      RED = { "KA_HEVO_RED_LOWER" },
      BLUE = { "KA_HEVO_BLUE_TIDAL_DEPTHS" },
      GREEN = {
        "KA_HEVO_GREEN_GROVE", "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
      },
    },
    MAPS = {
      RED = {
        "KA_HEVO_RED_UPPER", "KA_HEVO_RED_ABYSS",
        "KA_HEVO_RED_RECOVERY", "KA_HEVO_RED_LOWER",
        "KA_HEVO_RED_SHRINE",
      },
      BLUE = {
        "KA_HEVO_BLUE_FROST_THRESHOLD", "KA_HEVO_BLUE_FROST_HALL",
        "KA_HEVO_BLUE_GLACIER_MAZE", "KA_HEVO_BLUE_TIDAL_DEPTHS",
        "KA_HEVO_BLUE_KYOGRE_SHRINE",
      },
      GREEN = {
        "KA_HEVO_GREEN_THRESHOLD", "KA_HEVO_GREEN_GROVE",
        "KA_HEVO_GREEN_MIST", "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
      },
    },
    game = nil,
  }

  for mode, layouts in pairs(E.WATER_LAYOUTS) do
    for character, slots in pairs(layouts) do
      assert(#slots == E.SLOT_COUNT,
        mode .. " water layout must own ten slots: " .. character)
      local gyarados = 0
      for _, species in ipairs(slots) do
        if species == "GYARADOS" then gyarados = gyarados + 1 end
      end
      assert(gyarados == 1 and slots[E.GYARADOS_SLOT] == "GYARADOS",
        mode .. " water layout must keep one low-probability Gyarados: "
          .. character)
    end
  end
  do
    assert(#E.WATER_SLOT_WEIGHTS == E.SLOT_COUNT,
      "water encounter weights must own ten slots")
    local total = 0
    for _, weight in ipairs(E.WATER_SLOT_WEIGHTS) do
      assert(type(weight) == "number" and weight > 0
          and weight % 1 == 0,
        "water encounter weights must be positive integers")
      total = total + weight
    end
    assert(total == 256
        and E.WATER_SLOT_WEIGHTS[E.GYARADOS_SLOT] == 11,
      "water encounter weights must preserve the Gen-I Gyarados bucket")
  end

  E.mapCharacter = {}
  for character, maps in pairs(E.MAPS) do
    for _, mapId in ipairs(maps) do
      assert(not E.mapCharacter[mapId], "duplicate HEVO encounter map " .. mapId)
      E.mapCharacter[mapId] = character
    end
  end

  E.waterMapCharacter = {}
  for character, maps in pairs(E.WATER_MAPS) do
    for _, mapId in ipairs(maps) do
      assert(E.mapCharacter[mapId] == character,
        "HEVO water map is not owned by " .. character .. ": " .. mapId)
      assert(not E.waterMapCharacter[mapId],
        "duplicate HEVO water map " .. mapId)
      E.waterMapCharacter[mapId] = character
    end
  end

  local function copyEncounter(source)
    local out = {}
    for key, value in pairs(source or {}) do out[key] = value end
    return out
  end

  local function normalizeCharacter(value)
    value = type(value) == "string" and value:upper() or nil
    return value and E.MAPS[value] and value or nil
  end

  local function saveBucket(save)
    local modData = type(save and save.modData) == "table" and save.modData
    return type(modData) == "table" and type(modData[mod.id]) == "table"
      and modData[mod.id] or nil
  end

  local function beyondActive(save, game)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(save or game or E.game)
  end

  local function dexFor(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    return def and tonumber(def.dex) or nil
  end

  -- Water is a new Beyond-Kanto extension, so a missing, malformed or
  -- throwing boundary must stay on the registered #1-151 layout.  This is
  -- intentionally stricter than the legacy land helper above, whose no-
  -- boundary behavior is retained for old standalone fixtures.
  local function beyondWaterActive(save, game)
    if not (beyondKanto and type(beyondKanto.isActive) == "function") then
      return false
    end
    local ok, active = pcall(beyondKanto.isActive,
      save or game or E.game)
    return ok and active == true
  end

  local function registeredInRange(game, species, low, high)
    local dex = dexFor(game, species)
    return dex and dex >= low and dex <= high or false
  end

  -- The active Journey character is authoritative.  The real main.lua path
  -- supplies legacyJourney.activeCharacter; the raw-save fallbacks keep this
  -- module independently testable and migrate ordinary pre-Legacy saves.
  -- An installed authority callback that errors or returns a foreign value
  -- fails closed instead of silently trusting a secondary identity.
  function E.activeCharacter(save, game)
    -- Read the active save first.  Presentation helpers deliberately default
    -- missing/unknown selections to RED, which is useful for rendering but
    -- must never turn a present future/corrupt identity into RED progression.
    -- Only the exact absence of the record is the accepted pre-6.5 RED case.
    local bucket = saveBucket(save)
    local rawState = bucket and bucket.extended_characters
    if rawState ~= nil then
      if type(rawState) ~= "table" then return nil end
      return normalizeCharacter(rawState.player_character)
    end
    local legacyState = save and save.extended_characters
    if legacyState ~= nil then
      if type(legacyState) ~= "table" then return nil end
      return normalizeCharacter(legacyState.player_character)
    end
    if type(opts.activeCharacter) == "function" then
      local ok, value = pcall(opts.activeCharacter, game or { save = save })
      if not ok then return nil end
      if value ~= nil then return normalizeCharacter(value) end
    end
    local characters = opts.characters
    if characters and type(characters.getPlayerCharacter) == "function" then
      local ok, value = pcall(characters.getPlayerCharacter, characters)
      if not ok then return nil end
      if value ~= nil then return normalizeCharacter(value) end
    end
    return type(save) == "table" and "RED" or nil
  end

  -- The active save's Legacy-Journey state is the cycle source of truth.
  -- Archive cycle 1 is the first playable Legacy Journey; ordinary/pre-Legacy
  -- saves have no run state and intentionally share that Lv70 baseline.  The
  -- clamp also makes malformed or pre-versioned cycle values fail safely to
  -- the baseline instead of creating an over-levelled habitat.
  function E.journeyCycle(save, game)
    local raw
    if type(opts.journeyCycle) == "function" then
      local ok, value = pcall(opts.journeyCycle, game or { save = save })
      if not ok then return 1 end
      raw = value
    end
    if raw == nil then
      local bucket = saveBucket(save)
      local state = bucket and bucket.legacy_journey
      raw = type(state) == "table" and state.cycle or nil
    end
    return math.max(1, math.floor(tonumber(raw) or 1))
  end

  function E.levelFor(save, game)
    local cycle = E.journeyCycle(save, game)
    return math.min(E.MAX_LEVEL,
      E.BASE_LEVEL + E.LEVEL_STEP * (cycle - 1))
  end

  -- A successful fissure interaction sets the matching entered flag before
  -- the shared-tunnel warp.  A save already physically inside the matching
  -- trial is the sole compatibility fallback for in-progress/older slots.
  -- Checkpoints, statue count and permanent package unlocks are intentionally
  -- not accepted as substitute admission tokens.
  function E.trialAvailable(save, character, game)
    character = normalizeCharacter(character)
    if not character or E.activeCharacter(save, game) ~= character then
      return false, "character"
    end
    local flags = type(save and save.flags) == "table" and save.flags or nil
    if flags and flags[E.ENTERED_FLAG_PREFIX .. character] == true then
      return true, "entered"
    end
    local player = type(save and save.player) == "table" and save.player or nil
    if player and E.mapCharacter[player.map] == character then
      return true, "in-progress"
    end
    return false, "not-entered"
  end

  -- Rows are derived directly from the authoritative registry.  In
  -- particular the two GREEN dual-target packages naturally contribute two
  -- parents, while no final HEVO species or Hoenn starter is invented here.
  function E.rows(save, character, game)
    character = normalizeCharacter(character)
    local rows, seen = {}, {}
    if not E.trialAvailable(save, character, game) then return rows end
    local extended = beyondActive(save, game)
    for _, package in ipairs(packages.byCharacter[character] or {}) do
      for _, target in ipairs(package.targets or {}) do
        local authored = target.parent
        local dex = dexFor(game, authored)
        local species = authored
        if not extended and not (dex and dex >= 1 and dex <= 151) then
          species = E.KANTO_FALLBACK[authored]
        end
        local fallbackDex = dexFor(game, species)
        if species and (extended or fallbackDex and fallbackDex >= 1
            and fallbackDex <= 151) and not seen[species] then
          seen[species] = true
          rows[#rows + 1] = {
            species = species,
            package = package.id,
            authoredSpecies = authored,
            evolvesTo = extended and target.target or nil,
            kantoFallback = not extended and species ~= authored or nil,
          }
        end
      end
    end
    return rows
  end

  function E.grass(save, character, game)
    local rows = E.rows(save, character, game)
    if #rows == 0 then return { rate = 0, slots = {} } end
    local level = E.levelFor(save, game)
    local slots = {}
    for index = 1, E.SLOT_COUNT do
      local row = rows[(index - 1) % #rows + 1]
      slots[index] = { species = row.species, level = level }
    end
    return { rate = assert(E.RATE[character]), slots = slots }
  end

  function E.waterSpecies(save, character, game)
    character = normalizeCharacter(character)
    local kanto = E.WATER_LAYOUTS.KANTO[character]
    if type(kanto) ~= "table" or #kanto ~= E.SLOT_COUNT then return {} end
    local extended = beyondWaterActive(save, game)
    local authored = extended and E.WATER_LAYOUTS.BEYOND[character] or kanto
    local species = {}
    for index = 1, E.SLOT_COUNT do
      local fallback = kanto[index]
      -- Even the fallback must resolve through the active registry.  A broken
      -- Kanto registry leaves the whole Surf table closed rather than
      -- publishing an unspawnable or foreign identity.
      if not registeredInRange(game, fallback, 1, 151) then return {} end
      local candidate = authored and authored[index] or fallback
      local dex = dexFor(game, candidate)
      if dex and dex >= 1 and dex <= 151 then
        species[index] = candidate
      elseif extended and dex and dex >= 152 and dex <= 251 then
        species[index] = candidate
      else
        -- Missing or out-of-bound Johto data falls back slot-for-slot to the
        -- verified Kanto layout.  Slot 9 therefore remains the sole Gyarados.
        species[index] = fallback
      end
    end
    return species
  end

  function E.water(save, character, game)
    character = normalizeCharacter(character)
    if not E.trialAvailable(save, character, game) then
      return { rate = 0, slots = {} }
    end
    local species = E.waterSpecies(save, character, game)
    if #species ~= E.SLOT_COUNT then return { rate = 0, slots = {} } end
    local level = E.levelFor(save, game)
    local slots = {}
    for index = 1, E.SLOT_COUNT do
      slots[index] = {
        species = species[index],
        level = level,
        weight = E.WATER_SLOT_WEIGHTS[index],
      }
    end
    return { rate = E.WATER_RATE, slots = slots }
  end

  local function isWaterTerrain(terrain)
    terrain = type(terrain) == "string" and terrain:lower() or ""
    return terrain == "water" or terrain == "surf" or terrain == "surfing"
  end

  function E.allowed(save, mapId, encounter, game, terrain)
    local character = E.mapCharacter[mapId]
    if not character or type(encounter) ~= "table"
        or tonumber(encounter.level) ~= E.levelFor(save, game) then return false end
    if isWaterTerrain(terrain) then
      if E.waterMapCharacter[mapId] ~= character then return false end
      if not E.trialAvailable(save, character, game) then return false end
      for _, species in ipairs(E.waterSpecies(save, character, game)) do
        if species == encounter.species then return true end
      end
      return false
    end
    for _, row in ipairs(E.rows(save, character, game)) do
      if row.species == encounter.species then return true end
    end
    return false
  end

  local function wildsRuntime()
    local internal = mod.exports and mod.exports.internalWilds
    local wilds = type(internal) == "table" and (internal.exports or internal)
      or nil
    local logic = type(wilds) == "table" and wilds.logic or nil
    return wilds, logic
  end

  local function currentOverworld(logic)
    local world = logic and logic.mod and logic.mod.world or mod.world
    if not (world and type(world.overworld) == "function") then return nil end
    local ok, ow = pcall(function() return world:overworld() end)
    return ok and ow or nil
  end

  local function surfaceSignature(surface)
    local out = { tostring(surface and surface.rate or 0) }
    for index, slot in ipairs(surface and surface.slots or {}) do
      out[#out + 1] = table.concat({
        tostring(index), tostring(slot.species), tostring(slot.level),
        tostring(slot.weight),
      }, ":")
    end
    return table.concat(out, "|")
  end

  local function encounterSignature(encounter)
    return surfaceSignature(encounter and encounter.grass)
      .. "//" .. surfaceSignature(encounter and encounter.water)
      .. "//" .. tostring(encounter and encounter.kaMaxVisible)
  end

  local function hasPublishedHabitat(encounter)
    local grass = encounter and encounter.grass
    local water = encounter and encounter.water
    return type(grass and grass.slots) == "table" and #grass.slots > 0
      or type(water and water.slots) == "table" and #water.slots > 0
  end

  -- Rebuild only a stale population that belongs to the exact live HEVO map.
  -- During an ordinary map.entered event Wilds still owns the previous map, so
  -- this deliberately returns and lets its normal lower-priority listener do
  -- the first initialization.  The one-time allowUnclaimed path exists solely
  -- for a late/hot install whose map events have already passed.
  function E.refreshVisible(game, onlyMap, changedMaps, allowUnclaimed)
    game = game or E.game
    local _, logic = wildsRuntime()
    if type(logic) ~= "table" or type(logic.onMapEntered) ~= "function" then
      return false, "Wilds map-enter API unavailable"
    end
    local ow = currentOverworld(logic)
    local mapId = ow and ow.map and ow.map.id or nil
    if not mapId or not E.mapCharacter[mapId] then
      return false, "live map is not a HEVO habitat"
    end
    if onlyMap and onlyMap ~= mapId then
      return false, "foreign sync map"
    end
    if logic.activeMapId ~= nil and logic.activeMapId ~= mapId then
      return false, "Wilds still owns a foreign map"
    end
    if logic.activeMapId == nil and not allowUnclaimed then
      return false, "Wilds has not claimed the live map"
    end

    local encounter = game and game.data and game.data.encounters
      and game.data.encounters[mapId] or nil
    local published = hasPublishedHabitat(encounter)
    local visibleCount
    if type(logic.countVisibleOnMap) == "function" then
      local ok, value = pcall(logic.countVisibleOnMap, logic, mapId)
      if ok then visibleCount = tonumber(value) end
    end
    local featureEnabled = true
    if type(logic.featureActive) == "function" then
      local ok, value = pcall(logic.featureActive, logic)
      if not ok then return false, "Wilds feature state unavailable" end
      featureEnabled = value == true
    end
    -- Never turn the user's visible-Wilds option back on.  A disabled runtime
    -- is touched only if it still owns actors that must be cleared.
    if not featureEnabled and not (visibleCount and visibleCount > 0) then
      return false, "visible Wilds disabled"
    end

    local state = type(logic.state) == "table" and logic.state or {}
    local coherent = logic.activeMapId == mapId and state.mapId == mapId
      and state.initialized == true and state.pipelineVerified == true
    local changed = type(changedMaps) == "table"
      and changedMaps[mapId] == true
    local target = (tonumber(state.targetSpawnCount) or 0)
      + (tonumber(logic.targetWaterCount) or 0)
    local staleEmpty = coherent and published and target > 0
      and visibleCount ~= nil and visibleCount == 0
    local staleClosed = not published and visibleCount ~= nil
      and visibleCount > 0
    local invalidPublished = published and not coherent
    if not (changed or staleEmpty or staleClosed or invalidPublished
        or allowUnclaimed and published) then
      return false, "population already coherent"
    end
    if E._refreshingMap then return false, "refresh already active" end

    E._refreshingMap = mapId
    local ok, result = pcall(logic.onMapEntered, logic, {
      mapId = mapId,
      map = ow.map,
      game = game,
      hevoEncounterRefresh = true,
    })
    E._refreshingMap = nil
    if not ok then return false, result end
    return true, result
  end

  -- Data.encounters is shared for the lifetime of the process, while the
  -- authority flags live in the active slot.  Clear all fourteen authored
  -- tables before a slot transition so an outgoing RED/BLUE/GREEN save can
  -- never lend habitats to the incoming save between save.loading and its
  -- first map.entered event.
  function E.clear(game)
    game = game or E.game
    local encounters = game and game.data and game.data.encounters
    if type(encounters) ~= "table" then return false, "game" end
    local changed = 0
    for mapId, character in pairs(E.mapCharacter) do
      local encounter = encounters[mapId] or {}
      encounter.grass = { rate = 0, slots = {} }
      encounter.water = { rate = 0, slots = {} }
      encounter.kaProtected = true
      encounter.kaEncounterSource = E.SOURCE
      encounter.hevoCharacter = character
      encounter.kaMaxVisible = E.MAX_VISIBLE
      encounters[mapId] = encounter
      changed = changed + 1
    end
    return true, changed
  end

  -- game.data is per active runtime/save, so refresh it at every durable save
  -- boundary and map entry.  Locked maps retain a real empty encounter table;
  -- Wilds consequently has no visible-spawn source before valid admission.
  function E.sync(game, onlyMap)
    game = game or E.game
    local encounters = game and game.data and game.data.encounters
    local save = game and game.save
    if type(encounters) ~= "table" or type(save) ~= "table" then
      return false, "game"
    end
    local changed = 0
    local changedMaps = {}
    for mapId, character in pairs(E.mapCharacter) do
      if not onlyMap or onlyMap == mapId then
        local encounter = encounters[mapId] or {}
        local before = encounterSignature(encounter)
        encounter.grass = E.grass(save, character, game)
        local waterCharacter = E.waterMapCharacter[mapId]
        encounter.water = waterCharacter
          and E.water(save, waterCharacter, game)
          or { rate = 0, slots = {} }
        encounter.kaProtected = true
        encounter.kaEncounterSource = E.SOURCE
        encounter.hevoCharacter = character
        -- These trials already contain five authored clue relics and narrow
        -- puzzle corridors.  Respect the player's global Wilds density, but
        -- never let a very-high setting fill a trial with a dozen bodies and
        -- make relics/warps look like duplicate scenery.
        encounter.kaMaxVisible = E.MAX_VISIBLE
        encounters[mapId] = encounter
        changedMaps[mapId] = before ~= encounterSignature(encounter)
        changed = changed + 1
      end
    end
    E._lastSyncChangedMaps = changedMaps
    if E._refreshReady then
      E.refreshVisible(game, onlyMap, changedMaps, false)
    end
    return true, changed
  end

  function E.install(game)
    E.game = game or E.game
    local ok, why = E.sync(E.game)
    if not ok then return false, why end
    if E._installed then return true, "already installed" end
    E._installed = true
    if not E._boundaryListener and beyondKanto
        and type(beyondKanto.onChanged) == "function" then
      E._boundaryListener = beyondKanto.onChanged(function(_, changedGame)
        E.sync(changedGame or E.game)
      end)
    end

    -- Wilds 1.12.x normally merges global Old/Good-Rod entries into every
    -- visible water pool.  That is useful on ordinary routes, but would leak
    -- low-level, non-authored species into these cycle-scaled trials.  Keep
    -- all Wilds placement/presentation and the player's global mode intact;
    -- replace only the one synchronous species pick while a HEVO water spawn
    -- is being built.  Classic Surf already consumes encounter.water directly.
    local wilds, logic = wildsRuntime()
    if type(logic) == "table" and type(logic.trySpawnWater) == "function" then
      logic._kaHevoWaterController = E
      if not logic._kaHevoWaterWrapped then
        local originalTrySpawnWater = logic.trySpawnWater
        local waterSpawn
        if wilds.lib and type(wilds.lib.require) == "function" then
          local okWater, value = pcall(wilds.lib.require, "water_spawn")
          if okWater and type(value) == "table"
              and type(value.pickForZone) == "function" then
            waterSpawn = value
          end
        end
        local basePick = waterSpawn and waterSpawn.pickForZone
        logic.trySpawnWater = function(self, spawnGame, spawnOpts)
          local controller = self._kaHevoWaterController
          local mapId = self.activeMapId
          local character = controller
            and controller.waterMapCharacter[mapId]
          if not character then
            return originalTrySpawnWater(self, spawnGame, spawnOpts)
          end
          local activeGame = spawnGame or controller.game
          local definition = activeGame and activeGame.data
            and activeGame.data.encounters
            and activeGame.data.encounters[mapId]
          local slots = definition and definition.water
            and definition.water.slots or nil
          if type(slots) ~= "table" or #slots == 0 then
            return nil, "HEVO water habitat unavailable"
          end
          -- An external/older Wilds provider without the synchronous picker
          -- seam cannot be filtered safely.  Fail closed for visible water;
          -- the engine's classic Surf table remains fully available.
          if not (waterSpawn and basePick) then
            return nil, "HEVO water picker unavailable"
          end

          local surfTier = waterSpawn.ROD_TIER
            and waterSpawn.ROD_TIER.SURF or 0
          local surfSource = waterSpawn.SOURCE
            and waterSpawn.SOURCE.SURF or "surf"
          local entries = {}
          for _, slot in ipairs(slots) do
            if slot.species and controller.allowed(
                activeGame and activeGame.save, mapId, slot,
                activeGame, "water") then
              entries[#entries + 1] = {
                species = slot.species,
                speciesId = slot.species,
                level = slot.level,
                levelMin = slot.level,
                levelMax = slot.level,
                source = surfSource,
                rodTier = surfTier,
                weight = slot.weight or 1,
              }
            end
          end
          if #entries == 0 then
            return nil, "HEVO water habitat unavailable"
          end

          local currentPick = waterSpawn.pickForZone
          waterSpawn.pickForZone = function(_, zone, pickOpts)
            local pools = { near = entries, mid = entries, deep = entries }
            local themedOpts = {}
            for key, value in pairs(pickOpts or {}) do themedOpts[key] = value end
            themedOpts.fallbackEntries = entries
            return basePick(pools, zone, themedOpts)
          end
          local okSpawn, record, reason, entity = pcall(
            originalTrySpawnWater, self, spawnGame, spawnOpts or {})
          waterSpawn.pickForZone = currentPick
          if not okSpawn then error(record, 0) end
          return record, reason, entity
        end
        logic._kaHevoWaterWrapped = true
        logic._kaHevoOriginalTrySpawnWater = originalTrySpawnWater
      end
    end

    -- Mark the shared encounter context before Early-Johto/Mythic hooks run.
    -- Their transactional adapters preserve this flag; the outer validation
    -- below still fails closed if another module returns a foreign species.
    mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
      local character = ctx and E.mapCharacter[ctx.mapId]
      if not character then return nextRoll(encDef, ctx) end
      ctx.kaProtected = true
      ctx.kaEncounterSource = E.SOURCE
      local rolled = nextRoll(encDef, ctx)
      if not rolled or not E.allowed(E.game and E.game.save, ctx.mapId, rolled,
          E.game, ctx.terrain) then
        return nil
      end
      local out = copyEncounter(rolled)
      out.level = E.levelFor(E.game and E.game.save, E.game)
      out.kaProtected = true
      out.kaEncounterSource = E.SOURCE
      return out
    end, 2000)

    -- These are progression habitats, not randomizer fodder.  Bypass later
    -- species substitution entirely so an enabled randomizer cannot leak a
    -- foreign character's parent or an unavailable extended species.
    mod.hooks:wrap("encounter.species", function(nextEncounter, encounter, ctx)
      local mapId = ctx and ctx.mapId
      if not E.mapCharacter[mapId] then
        return nextEncounter(encounter, ctx)
      end
      if not E.allowed(E.game and E.game.save, mapId, encounter, E.game,
          ctx and ctx.terrain) then
        return nil
      end
      -- Let downstream consumers observe the protected marker (Run Rules
      -- records the exact classic-roll identity for BattleState), but never
      -- accept a species/level substitution on the way back out.
      local downstream = nextEncounter(encounter, ctx)
      if downstream == nil then return nil end
      local out = copyEncounter(encounter)
      out.level = E.levelFor(E.game and E.game.save, E.game)
      out.kaProtected = true
      out.kaEncounterSource = E.SOURCE
      return out
    end, 2000)

    local function resync(ev)
      local active = E.game
      if ev and ev.game then active = ev.game end
      if ev and ev.save and active and active.save ~= ev.save then
        active = { data = active.data, save = ev.save }
      end
      E.sync(active)
    end
    mod.events:on("save.loading", function(ev)
      E.clear(ev and ev.game or E.game)
    end, 2100)
    mod.events:on("save.loaded", resync, 2000)
    mod.events:on("save.created", resync, 2000)
    mod.events:on("save.writing", resync, 2000)
    mod.events:on("map.entered", function(ev)
      local active = ev and ev.game or E.game
      E.sync(active, ev and ev.mapId)
    end, 2000)
    -- All guards, including the synchronous HEVO water picker, now exist.
    -- Repair a current map whose earlier map/save events predated this install;
    -- no ordinary or foreign active map is ever replayed here.
    E._refreshReady = true
    E.refreshVisible(E.game, nil, E._lastSyncChangedMaps, true)
    return true
  end

  return E
end
