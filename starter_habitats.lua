-- Kanto Ascendant 6.7 compact starter habitats.
--
-- The checked-in V2.3 maps own geometry only.  This adapter converts the
-- twelve reviewed Map Studio maps into real runtime maps, replaces editor-only
-- return objects with save-safe source contracts, publishes ordinary
-- Generation I-III residents, and layers exactly one target starter over an
-- actually-started eligible encounter.  Catching that exact battle is the
-- sole family-unlock transaction.

local Module = {
  CARD_ID = "KASC-66-STARTER-HABITATS",
  OWNER = "kasc.starter-habitats/v1",
  OPTION_KEY = "starter_habitats_enabled",
  MAPS_SHA256 =
    "d4ac5d8ad5710be6e616e5009d65db4eccaeeb0e3403171649bba39b9ce4deca",
  MAP_SOURCE_PROJECT_SHA256 =
    "5b9dfa8f6cf34098759656e88c68f82cddd2a5ca5abc5af7d69adcd74d9ebc9c",
  -- Access V3.1 was reviewed against the earlier source-map extraction.  Its
  -- receipt stays separate from the later, habitat-only editor geometry.
  SOURCE_PROJECT_SHA256 =
    "322e29447f7481a12d71b14fd50cfebf8d5b2220b3c2622f62339ad79b576e31",
  ACCESS_SHA256 =
    "f077f6fccb69821efba7676d98f9f6533c3ff36d5f944abdfa5acfe0c514d000",
  SAVE_KEY = "starter_habitats_runtime",
  SAVE_VERSION = 1,
  ENCOUNTER_PRIORITY = 2600,
  EVENT_PRIORITY = 4100,
  SOURCE = "starter_habitat_67",
  RESIDENT_RATE = 25,
  SLOT_COUNT = 10,
}

local EXPECTED = {
  { 2000, "KA_HABITAT_TURTWIG_PROTOTYPE", "TURTWIG", "PLANT" },
  { 2001, "KA_HABITAT_SNIVY_PROTOTYPE", "SNIVY", "PLANT" },
  { 2002, "KA_HABITAT_CHESPIN_PROTOTYPE", "CHESPIN", "PLANT" },
  { 2003, "KA_HABITAT_ROWLET_PROTOTYPE", "ROWLET", "PLANT" },
  { 2004, "KA_HABITAT_CHIMCHAR_PROTOTYPE", "CHIMCHAR", "FIRE" },
  { 2005, "KA_HABITAT_PIPLUP_PROTOTYPE", "PIPLUP", "WATER" },
  { 2006, "KA_HABITAT_TEPIG_PROTOTYPE", "TEPIG", "FIRE" },
  { 2007, "KA_HABITAT_OSHAWOTT_PROTOTYPE", "OSHAWOTT", "WATER" },
  { 2008, "KA_HABITAT_FENNEKIN_PROTOTYPE", "FENNEKIN", "FIRE" },
  { 2009, "KA_HABITAT_FROAKIE_PROTOTYPE", "FROAKIE", "WATER" },
  { 2010, "KA_HABITAT_LITTEN_PROTOTYPE", "LITTEN", "FIRE" },
  { 2011, "KA_HABITAT_POPPLIO_PROTOTYPE", "POPPLIO", "WATER" },
}

local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end

local function key(value)
  return type(value) == "string" and value:upper() or nil
end

local function currentMapId(game)
  return game and game.overworld and game.overworld.map
      and game.overworld.map.id
    or game and game.save and game.save.player and game.save.player.map
end

local function facingToward(from, target)
  if target.x > from.x then return "right" end
  if target.x < from.x then return "left" end
  if target.y > from.y then return "down" end
  return "up"
end

local COMPACT_SITE_NAMES = {
  en = {
    TURTWIG = "ROOTLIT", SNIVY = "VINEVEIL", CHESPIN = "CHESTNUT",
    ROWLET = "MOONLEAF", CHIMCHAR = "EMBERMIST", PIPLUP = "ROOKERY",
    TEPIG = "CINDER", OSHAWOTT = "SHELLSTEP", FENNEKIN = "MIRAGE",
    FROAKIE = "RAINLEAF", LITTEN = "SOOTPAW", POPPLIO = "CHORUS",
  },
  de = {
    TURTWIG = "WURZELHAIN", SNIVY = "RANKENAU", CHESPIN = "NUSSHAIN",
    ROWLET = "MONDLAUB", CHIMCHAR = "GLUTNEBEL", PIPLUP = "HORST",
    TEPIG = "ASCHEGRUND", OSHAWOTT = "MUSCHELWEG", FENNEKIN = "TRUGBILD",
    FROAKIE = "REGENLAUB", LITTEN = "RUSSPFOTE", POPPLIO = "CHOR",
  },
}

local STARTER_DISPLAY_NAMES = {
  en = {
    TURTWIG = "TURTWIG", SNIVY = "SNIVY", CHESPIN = "CHESPIN",
    ROWLET = "ROWLET", CHIMCHAR = "CHIMCHAR", PIPLUP = "PIPLUP",
    TEPIG = "TEPIG", OSHAWOTT = "OSHAWOTT", FENNEKIN = "FENNEKIN",
    FROAKIE = "FROAKIE", LITTEN = "LITTEN", POPPLIO = "POPPLIO",
  },
  de = {
    TURTWIG = "CHELAST", SNIVY = "SERPIFEU", CHESPIN = "IGAMARO",
    ROWLET = "BAUZ", CHIMCHAR = "PANFLAM", PIPLUP = "PLINFA",
    TEPIG = "FLOINK", OSHAWOTT = "OTTARO", FENNEKIN = "FYNX",
    FROAKIE = "FROXY", LITTEN = "FLAMIAU", POPPLIO = "ROBBALL",
  },
}

local function create(mod, opts)
  opts = opts or {}
  local Json = assert(opts.json,
    "starter habitats require the local JSON decoder")
  local tilesets = assert(opts.tilesets,
    "starter habitats require reviewed tilesets")
  local core = assert(opts.discoveryCore,
    "starter habitats require Discovery Core")
  local State = assert(core.State, "starter habitats require Discovery State")
  local Starters = assert(core.Starters,
    "starter habitats require starter authority")
  local manager = assert(core.state,
    "starter habitats require discovery save adapter")
  assert(type(manager.root) == "function"
      and type(manager.replace) == "function",
    "starter habitat discovery save adapter is invalid")

  local journey = assert(opts.legacyJourney,
    "starter habitats require Legacy Journey authority")
  local device = assert(opts.explorationDevice,
    "starter habitats require entrance receipt authority")
  local speciesAuthority = opts.speciesAuthority
  local spawnSafety = opts.wildsSpawnSafety
  local receiptAuthority = opts.receiptAuthority
  local shinySystem = opts.shinySystem
  local generationRules = opts.generationRules
  local i18n = opts.i18n

  local H = {
    CARD_ID = Module.CARD_ID,
    OWNER = Module.OWNER,
    OPTION_KEY = Module.OPTION_KEY,
    SOURCE = Module.SOURCE,
    SAVE_KEY = Module.SAVE_KEY,
    maps = {}, order = {}, byFamily = {}, accesses = {}, accessByReceipt = {},
    game = nil, installed = false, serial = 0, handoffSerial = 0,
    accessAuthorityBound = false,
    receiptAuthorityBound = false,
  }
  local pendingProposal

  local function enabled()
    if type(opts.enabled) == "function" then
      local ok, value = pcall(opts.enabled)
      return ok and value ~= false
    end
    if mod.options and type(mod.options.get) == "function" then
      local ok, value = pcall(mod.options.get, mod.options, Module.OPTION_KEY)
      return not ok or value ~= false
    end
    return true
  end

  H.enabled = enabled

  if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
    opts.supportLog.registerSegment({
      segmentId = Module.CARD_ID, cardId = Module.CARD_ID, version = "1.0.0",
      schema = "kasc.optional-feature-card/v1", owner = Module.OWNER,
      active = enabled(), dependencyStatus = "local-reviewed",
      providerStatus = enabled() and "runtime-loaded" or "cold-disabled",
      buildReceiptId = "docs/STARTER_HABITATS_CARD_67.md",
      rollbackReceiptId = "select-starter-habitats-off",
    })
  end

  function H.discoveryStatus(family)
    local def = Starters.definition(family)
    if not def then return nil, "unknown-starter-family" end
    return State.status(manager.root(false), def.generation, def.id), copy(def)
  end

  -- Hearing the authored Life-of-a-Rival rumor is the quest transaction that
  -- turns an unknown family into a Trace-Finder target.  This is monotonic and
  -- idempotent, so an already persisted rumor receipt can safely replay after
  -- a crash or on an upgraded save.
  function H.recordRumorTrace(family)
    if not enabled() then return false, "feature-disabled" end
    local def = Starters.definition(family)
    if not def then return false, "unknown-starter-family" end
    local nextRoot, changed, why = State.mark(
      manager.root(true), def.generation, def.id, "trace")
    if why then return false, why end
    if changed then manager.replace(nextRoot) end
    local status = State.status(nextRoot, def.generation, def.id)
    local accepted = status == "trace" or status == "caught"
      or status == "unlocked"
    return accepted, {
      family = def.id, generation = def.generation,
      status = status, changed = changed == true,
    }
  end

  local rawMaps = Json.read(mod, "assets/starter_habitats/maps-v2.3.json")
  assert(rawMaps.schema == "kanto-ascendant.map-studio-merge-payload.v2.3"
      and rawMaps.scope == "EXACTLY_TWELVE_COMPACT_STARTER_HABITAT_MAPS_V2_3"
      and rawMaps.sourceEditorProjectSha256
        == Module.MAP_SOURCE_PROJECT_SHA256
      and rawMaps.previousPayloadSha256
        == "5988cf22d966ba82d096ca885e2c1e1589eae562eba0a504798d8610a2fa1efb"
      and rawMaps.productionMapsModified == true
      and rawMaps.runtimeIntegrationApproved == true
      and rawMaps.fallbackPreserved == true,
    "unexpected starter habitat map payload")
  assert(type(rawMaps.maps) == "table" and #rawMaps.maps == #EXPECTED,
    "starter habitat payload must contain exactly twelve maps")
  table.sort(rawMaps.maps, function(a, b) return a.index < b.index end)

  local rawAccess = Json.read(mod, "assets/starter_habitats/access-v3.1.json")
  assert(rawAccess.schema
      == "kanto-ascendant.starter-habitat-access-contract.v3.1",
    "unexpected starter habitat Access V3.1 payload")
  assert(rawAccess.sourceMapProjectSha256 == Module.SOURCE_PROJECT_SHA256,
    "starter habitat access source hash mismatch")
  assert(rawAccess.sourceAccessV31Sha256
      == "453e35e5adb1233d0fbd72855b4b3f66ee0ab507a0aeda2ba55eab0a54bebd19"
      and rawAccess.accessV2Disposition == "REJECTED_DO_NOT_IMPLEMENT",
    "starter habitat access authority is not canonical V3.1")
  assert(type(rawAccess.accesses) == "table" and #rawAccess.accesses == 16,
    "starter habitat access contract must contain sixteen reviewed choices")

  local function receiptId(access)
    return assert(access.receiptId,
      "starter habitat Access V3.1 receipt id missing")
  end

  for _, access in ipairs(rawAccess.accesses) do
    assert(type(access.targetMap) == "string"
        and type(access.sourceMap) == "string"
        and type(access.sourceMapIndex) == "number"
        and (access.sourceMode == "LAND" or access.sourceMode == "SURF")
        and access.returnMode == "LAND"
        and type(access.approachCell) == "table"
        and type(access.sourceCell) == "table",
      "invalid starter habitat access row")
    access.receiptId = receiptId(access)
    access.facing = facingToward(access.approachCell, access.sourceCell)
    H.accesses[access.targetMap] = H.accesses[access.targetMap] or {}
    assert(not H.accesses[access.targetMap][access.sourceMap],
      "duplicate starter habitat source contract")
    assert(not H.accessByReceipt[access.receiptId],
      "duplicate starter habitat Access V3.1 receipt")
    H.accesses[access.targetMap][access.sourceMap] = access
    H.accessByReceipt[access.receiptId] = access
  end

  local function addReserved(out, seen, cell, reason)
    if type(cell) ~= "table" then return end
    local x, y = tonumber(cell.x), tonumber(cell.y)
    if not x or not y then return end
    x, y = math.floor(x), math.floor(y)
    local id = tostring(x) .. ":" .. tostring(y)
    if seen[id] then return end
    seen[id] = true
    out[#out + 1] = { x = x, y = y, reason = reason }
  end

  local function reservations(source)
    local out, seen = {}, {}
    local habitat = source.starterHabitat
    addReserved(out, seen, habitat.entry, "habitat entry")
    addReserved(out, seen, habitat.exit, "habitat south exit")
    for _, corridor in ipairs(habitat.criticalCorridors or {}) do
      for _, cell in ipairs(corridor.cells or {}) do
        addReserved(out, seen, cell, "critical return corridor")
      end
    end
    local wilds = habitat.wildsReservations or {}
    for _, cell in ipairs(wilds.itemPads or {}) do
      addReserved(out, seen, cell, "reserved habitat item pad")
    end
    for _, cell in ipairs(wilds.npcPads or {}) do
      addReserved(out, seen, cell, "reserved habitat NPC pad")
    end
    local focus = wilds.starterFocusArena or habitat.starterFocusArena
    if type(focus) == "table" then
      for y = focus.y, focus.y + focus.height - 1 do
        for x = focus.x, focus.x + focus.width - 1 do
          addReserved(out, seen, { x = x, y = y },
            "starter focus battle zone")
        end
      end
    end
    return out
  end

  local function registeredPokemon(species)
    local registry = mod.content and mod.content.pokemon
    return registry and type(registry.get) == "function"
      and registry:get(species) ~= nil
  end

  local function residentEncounter(candidates, livePokemon)
    local available = {}
    for _, species in ipairs(candidates) do
      local present = type(livePokemon) == "table"
        and type(livePokemon[species]) == "table"
        or livePokemon == nil and registeredPokemon(species)
      if present then available[#available + 1] = species end
    end
    if #available == 0 then return { rate = 0, slots = {} }, 0 end
    local slots = {}
    for index = 1, Module.SLOT_COUNT do
      slots[index] = {
        species = available[(index - 1) % #available + 1],
        level = 27 + ((index - 1) % 6),
      }
    end
    return { rate = Module.RESIDENT_RATE, slots = slots }, #available
  end

  local function language()
    if i18n and type(i18n.isGerman) == "function" then
      local ok, german = pcall(i18n.isGerman)
      if ok and german then return "de" end
    end
    return "en"
  end

  local function displayLabels(family, fullLabel, requestedLanguage)
    local locale = requestedLanguage or language()
    local sites = COMPACT_SITE_NAMES[locale] or COMPACT_SITE_NAMES.en
    local starters = STARTER_DISPLAY_NAMES[locale] or STARTER_DISPLAY_NAMES.en
    local site = sites[family]
      or type(fullLabel) == "string"
        and fullLabel:match("^[^·]+·%s*([^%s]+)") or "HABITAT"
    local starter = starters[family] or family
    -- Gen-I's map-name banner has an 18-glyph budget. Keep the reviewed full
    -- title as metadata, while the actual banner uses a stable compact name
    -- before and after discovery instead of clipping its final glyphs.
    return "??? " .. site, starter .. " " .. site
  end

  local function mapDefinition(source, row)
    local habitat = source.starterHabitat
    local reserved = reservations(source)
    local overhangs = {}
    for position, block in ipairs(source.overhangBlocks or {}) do
      if tonumber(block) ~= nil then
        overhangs[#overhangs + 1] = {
          x = (position - 1) % source.width,
          y = math.floor((position - 1) / source.width),
          block = block,
        }
      end
    end
    local def = {
      id = source.id, index = source.index, label = row.secretLabel,
      tileset = assert(tilesets.ids[source.theme],
        "unsupported starter habitat theme: " .. tostring(source.theme)),
      palette = habitat.category == "FIRE" and "CAVE" or "OVERWORLD",
      width = source.width, height = source.height,
      borderBlock = source.borderBlock, blocks = copy(source.blocks),
      overhangs = overhangs,
      connections = {}, warps = {}, objects = {}, signs = {},
      outdoor = habitat.category ~= "FIRE",
      region = "KANTO_ASCENDANT_HABITAT",
      generation = source.generation,
      sourceTileset = source.theme,
      theme = source.theme,
      atmosphere = copy(source.atmosphere),
      highGrassPatches = copy(habitat.highGrassPatches or {}),
      starterHabitat = copy(habitat),
      kaStarterHabitatSecretLabel = row.secretLabel,
      kaStarterHabitatRevealedLabel = row.revealedLabel,
      kaStarterHabitatFullLabel = row.fullLabel,
      kaWildsStrictSurface = true,
      kaWildsReservedCells = copy(reserved),
      storyPositions = {
        { x = habitat.entry.x, y = habitat.entry.y,
          reason = "habitat entry", approaches = true },
        { x = habitat.exit.x, y = habitat.exit.y,
          reason = "habitat exit", approaches = true },
      },
      voxelMode = "FULL",
      voxelRevision = source.voxelRevision,
      voxelAuthority = "2D_BLOCKS",
      voxelOwner = "kanto_ascendant",
      voxelEnabled = source.voxelEnabled ~= false,
      voxelSourceHash = source.voxelSourceHash,
      voxelAnalysis = copy(source.voxelAnalysis),
      voxelBattleZoneId = source.voxelBattleZoneId,
      voxelBattleZones = copy(source.voxelBattleZones or {}),
      voxelSemanticOverrides = copy(source.voxelSemanticOverrides or {}),
      voxelSurfaceRuns = copy(source.voxelSurfaceRuns),
      voxelBuildingFootprints = copy(source.voxelBuildingFootprints or {}),
      voxelFlatDecalCells = copy(source.voxelFlatDecalCells or {}),
      voxelFlatDecalProvenance = copy(source.voxelFlatDecalProvenance),
      voxelFlatDecalReport = copy(source.voxelFlatDecalReport),
      voxelSemanticBuildingReport =
        copy(source.voxelSemanticBuildingReport),
      voxelSemanticObjectReport = copy(source.voxelSemanticObjectReport),
      runtimeAuthority = "KASC_6_7_STARTER_HABITAT_V2_3",
      runtimeSourceProjectSha256 = Module.MAP_SOURCE_PROJECT_SHA256,
      runtimeMapPayloadSha256 = Module.MAPS_SHA256,
      kaMaxVisible = habitat.category == "WATER" and 4 or 3,
    }
    return def, reserved
  end

  local indexOwner = {}
  if mod.content and mod.content.maps
      and type(mod.content.maps.each) == "function" then
    for id, def in mod.content.maps:each() do
      if type(def) == "table" and tonumber(def.index) then
        indexOwner[tonumber(def.index)] = id
      end
    end
  end

  for index, source in ipairs(rawMaps.maps) do
    local expected = EXPECTED[index]
    local habitat = assert(source.starterHabitat,
      "starter habitat metadata missing")
    assert(source.index == expected[1] and source.id == expected[2]
        and habitat.starter == expected[3]
        and habitat.category == expected[4],
      "starter habitat identity/order differs from reviewed V2.1 payload")
    assert(not indexOwner[source.index]
        or indexOwner[source.index] == source.id,
      ("starter habitat map index %d already belongs to %s")
        :format(source.index, tostring(indexOwner[source.index])))
    assert(not H.maps[source.id], "duplicate starter habitat map id")
    indexOwner[source.index] = source.id

    local secretLabel, revealedLabel = displayLabels(habitat.starter, source.label)
    local row = {
      id = source.id, index = source.index,
      family = habitat.starter, category = habitat.category,
      generation = assert(Starters.definition(habitat.starter)).generation,
      entry = copy(habitat.entry), exit = copy(habitat.exit),
      candidates = copy(habitat.candidateResidentsGen1To3 or {}),
      secretLabel = secretLabel,
      revealedLabel = revealedLabel,
      fullLabel = source.label,
    }
    local def, reserved = mapDefinition(source, row)
    row.definition, row.reservedCells = def, reserved
    H.maps[row.id], H.byFamily[row.family] = row, row
    H.order[#H.order + 1] = row.id

    assert(not mod.content.maps:get(row.id),
      "starter habitat map id already registered: " .. row.id)
    mod.content.maps:register(row.id, def)
    local grass = residentEncounter(row.candidates)
    local encounter = { grass = grass, kaWildsStrictSurface = true }
    if row.category == "WATER" then encounter.water = copy(grass) end
    mod.content.encounters:register(row.id, encounter)

    mod.content.map_scripts:register(row.id, {
      priority = 2800,
      onStep = function(game, _, x, y)
        if x == row.exit.x and y == row.exit.y then
          return H.leave(game, row.id) == true
        end
        return false
      end,
    })
    if spawnSafety and type(spawnSafety.reserveCells) == "function" then
      spawnSafety.reserveCells(row.id, reserved,
        "KASC 6.7 compact starter habitat")
    end
  end


  -- The authored area subtitle remains useful, but the starter name itself
  -- is a discovery reward.  A rumor/trace/sighting never reveals it: only a
  -- successful catch (or an already-unlocked family) switches the live map
  -- definition to its reviewed full label.
  function H.refreshMapLabels(game)
    game = game or H.game
    local liveMaps = game and game.data and game.data.maps
    local labels = {}
    for _, mapId in ipairs(H.order) do
      local row = H.maps[mapId]
      local status = H.discoveryStatus(row.family)
      local revealed = status == "caught" or status == "unlocked"
      row.secretLabel, row.revealedLabel = displayLabels(
        row.family, row.fullLabel)
      row.definition.kaStarterHabitatSecretLabel = row.secretLabel
      row.definition.kaStarterHabitatRevealedLabel = row.revealedLabel
      local label = revealed and row.revealedLabel or row.secretLabel
      row.definition.label = label
      local registered = mod.content.maps:get(mapId)
      if type(registered) == "table" then registered.label = label end
      if type(liveMaps) == "table" and type(liveMaps[mapId]) == "table" then
        liveMaps[mapId].label = label
      end
      labels[mapId] = label
    end
    return labels
  end

  for _, access in pairs(H.accessByReceipt) do
    local target = assert(H.maps[access.targetMap],
      "Access V3.1 references an unknown starter habitat")
    assert(access.targetMapIndex == target.index
        and access.targetCell.x == target.entry.x
        and access.targetCell.y == target.entry.y,
      "Access V3.1 destination differs from habitat entry")
  end

  -- Content registries do not necessarily expose the base game's Pokémon
  -- while mods are still being constructed. Register a valid empty encounter
  -- table in that minimal environment, then populate only real merged
  -- game.data rows at install/save boundaries. Missing optional residents
  -- make that one habitat inert; they can never abort the whole mod load.
  function H.refreshResidentEncounters(game)
    local pokemon = game and game.data and game.data.pokemon
    local encounters = game and game.data and game.data.encounters
    if type(pokemon) ~= "table" or type(encounters) ~= "table" then
      H.liveResidentMaps = 0
      return {}, 0
    end
    local status, active = {}, 0
    for _, mapId in ipairs(H.order) do
      local row = H.maps[mapId]
      local grass, available = { rate = 0, slots = {} }, 0
      if enabled() then
        grass, available = residentEncounter(row.candidates, pokemon)
      end
      local encounter = encounters[mapId]
      if type(encounter) == "table" then
        encounter.grass = grass
        encounter.water = row.category == "WATER" and copy(grass) or nil
      end
      status[mapId] = available > 0
      if available > 0 then active = active + 1 end
    end
    H.liveResidentMaps = active
    H.lastResidentAvailability = status
    return copy(status), active
  end

  local function samePoint(point, x, y)
    return type(point) == "table"
      and tonumber(point.x) == tonumber(x)
      and tonumber(point.y) == tonumber(y)
  end

  -- Bind the derived return table to hidden_access_reveal.definitions().
  -- The map registry is intentionally independent, but traversal remains
  -- fail-closed until all sixteen receipt/edge/destination/LAND-return rows
  -- exactly match the active Access V3.1 controller.
  function H.bindAccessAuthority(definitions)
    if type(definitions) ~= "table" then
      return false, "invalid-access-authority"
    end
    local matched, seen = 0, {}
    for _, def in ipairs(definitions) do
      local destination = def and def.handoff and def.handoff.destination
      if destination and H.maps[destination.map] then
        local access = H.accessByReceipt[def.id]
        if not access then return false, "unknown-habitat-receipt" end
        local back = def.returnToKanto
        if seen[def.id] then return false, "duplicate-habitat-receipt" end
        if def.mapId ~= access.sourceMap
            or tonumber(def.mapIndex) ~= access.sourceMapIndex
            or def.sourceMode ~= access.sourceMode
            or def.starter ~= access.starter
            or not samePoint(def.warp,
              access.sourceCell.x, access.sourceCell.y)
            or type(back) ~= "table" or back.map ~= access.sourceMap
            or tonumber(back.mapIndex) ~= access.sourceMapIndex
            or back.mode ~= "LAND"
            or not samePoint(back,
              access.approachCell.x, access.approachCell.y)
            or destination.map ~= access.targetMap
            or tonumber(destination.mapIndex) ~= access.targetMapIndex
            or not samePoint(destination,
              access.targetCell.x, access.targetCell.y) then
          return false, "habitat-access-authority-mismatch"
        end
        seen[def.id], matched = true, matched + 1
      end
    end
    if matched ~= #rawAccess.accesses then
      return false, "incomplete-habitat-access-authority"
    end
    H.accessAuthorityBound = true
    return true, matched
  end

  local function normalizeRuntime(raw)
    local out = type(raw) == "table" and copy(raw) or {}
    out.version = Module.SAVE_VERSION
    if type(out.active) ~= "table"
        or not H.maps[out.active.mapId]
        or type(out.active.sourceMap) ~= "string"
        or not H.accesses[out.active.mapId]
        or not H.accesses[out.active.mapId][out.active.sourceMap] then
      out.active = nil
    end
    return out
  end

  local function runtimeState(create)
    local raw = mod.save:get(Module.SAVE_KEY)
    if raw == nil and create == false then return nil end
    local out = normalizeRuntime(raw)
    mod.save:set(Module.SAVE_KEY, out)
    return out
  end

  local function persistRuntime(value)
    local out = normalizeRuntime(value)
    mod.save:set(Module.SAVE_KEY, out)
    return out
  end

  local function starterAccessAllowed(game)
    local ok, active = pcall(journey.isActive, game and game.save)
    if ok and active == true then return true end
    return opts.normalStarterAccess and opts.normalStarterAccess.allowed(game) == true or false
  end

  function H.bindReceiptAuthority(authority)
    local fn = type(authority) == "function" and authority
      or type(authority) == "table" and authority.isOpen
    if type(fn) ~= "function" then
      return false, "invalid-receipt-authority"
    end
    receiptAuthority = function(id)
      local ok, opened = pcall(fn, id)
      if not ok and type(authority) == "table" then
        ok, opened = pcall(fn, authority, id)
      end
      return ok and opened == true
    end
    H.receiptAuthorityBound = true
    return true
  end

  if receiptAuthority ~= nil then
    assert(H.bindReceiptAuthority(receiptAuthority))
  end

  function H.entranceId(mapId, sourceMap)
    local access = H.accesses[mapId] and H.accesses[mapId][sourceMap]
    return access and access.receiptId or nil
  end

  local function entranceOpen(access)
    if not access then return false end
    if H.receiptAuthorityBound then
      return receiptAuthority(access.receiptId) == true
    end
    -- Construction-time compatibility only. install() refuses to activate
    -- until the durable Access V3.1 truth is bound, so a fresh device-local
    -- table can never override a receipt carried into a later NG+ cycle.
    if type(device.isOpen) ~= "function" then return false end
    local ok, opened = pcall(device.isOpen, access.receiptId)
    return ok and opened == true
  end

  function H.available(game, mapId, sourceMap)
    local access = H.accesses[mapId] and H.accesses[mapId][sourceMap]
    return enabled() and H.accessAuthorityBound and access ~= nil
      and starterAccessAllowed(game) and entranceOpen(access)
  end

  -- Explicit pre-warp transaction used by Access V3.1's guarded interaction
  -- fallback. Native runtime edge warps call the same function from the
  -- public player.warped event before map.entered. No source is inferred from
  -- whichever receipt happens to be open.
  function H.prepareHandoff(game, accessId, sourceMap, targetMap)
    if not enabled() then return nil, "feature-disabled" end
    if not H.accessAuthorityBound then
      return nil, "access-authority-unbound"
    end
    if not H.receiptAuthorityBound then
      return nil, "receipt-authority-unbound"
    end
    local access = H.accessByReceipt[accessId]
    if not access or access.sourceMap ~= sourceMap
        or access.targetMap ~= targetMap then
      return nil, "invalid-handoff-contract"
    end
    if not starterAccessAllowed(game) then return nil, "starter-access-required" end
    if not entranceOpen(access) then return nil, "entrance-closed" end
    if currentMapId(game) ~= sourceMap then
      return nil, "source-map-mismatch"
    end
    H.handoffSerial = H.handoffSerial + 1
    local state = runtimeState(true)
    local token = {
      serial = H.handoffSerial,
      accessId = accessId,
      sourceMap = sourceMap,
      targetMap = targetMap,
      previousActive = copy(state.active),
    }
    state.active = {
      mapId = targetMap, sourceMap = sourceMap,
      receiptId = access.receiptId, option = access.option,
      handoffSerial = token.serial,
    }
    persistRuntime(state)
    return token
  end

  function H.rollbackHandoff(game, token, reason)
    if type(token) ~= "table" or token.rolledBack then
      return false, "invalid-handoff-token"
    end
    local state = runtimeState(false)
    local active = state and state.active
    if not active or active.handoffSerial ~= token.serial
        or active.receiptId ~= token.accessId
        or active.mapId ~= token.targetMap
        or active.sourceMap ~= token.sourceMap then
      return false, "stale-handoff-token"
    end
    state.active = copy(token.previousActive)
    persistRuntime(state)
    token.rolledBack = true
    token.rollbackReason = reason or "handoff-warp-failed"
    return true
  end

  function H.acceptNativeEdgeWarp(game, ev)
    local runtimeWarp = ev and ev.warp
    if type(runtimeWarp) ~= "table" or runtimeWarp.runtime ~= true
        or runtimeWarp.owner ~= mod.id
        or type(runtimeWarp.id) ~= "string" then
      return false, "not-owned-runtime-edge-warp"
    end
    local prefix = "kasc67:"
    if runtimeWarp.id:sub(1, #prefix) ~= prefix then
      return false, "not-access-v3-edge-warp"
    end
    local accessId = runtimeWarp.id:sub(#prefix + 1)
    local token, why = H.prepareHandoff(
      game, accessId, ev.fromMap, ev.toMap)
    if not token then return false, why end
    return true, token
  end

  local function warp(game, mapId, position)
    if mod.world and type(mod.world.warpTo) == "function" then
      local ok, reason = mod.world:warpTo(
        mapId, position.x, position.y, position.facing)
      if ok then return true end
      if reason and reason ~= "no overworld" then return nil, reason end
    end
    local ow = game and game.overworld
    if not (ow and type(ow.startWarpTo) == "function") then
      return nil, "no-overworld"
    end
    ow:startWarpTo(mapId, position.x, position.y, position.facing)
    return true
  end

  function H.enter(game, mapId, sourceMap)
    local row = H.maps[mapId]
    if not row then return false, "unknown-habitat" end
    local access = H.accesses[mapId] and H.accesses[mapId][sourceMap]
    if not access then return false, "invalid-return-contract" end
    local token, prepareWhy = H.prepareHandoff(
      game, access.receiptId, sourceMap, mapId)
    if not token then return false, prepareWhy end
    local entered, reason = warp(game, mapId, {
      x = row.entry.x, y = row.entry.y, facing = "up",
    })
    if not entered then
      H.rollbackHandoff(game, token, reason)
      return false, reason
    end
    return true
  end

  local function activeAccess(game, mapId)
    local state = runtimeState(false)
    local active = state and state.active
    if not active or active.mapId ~= mapId then return nil end
    local access = H.accesses[mapId]
      and H.accesses[mapId][active.sourceMap]
    if not access or active.receiptId ~= access.receiptId
        or not starterAccessAllowed(game) or not entranceOpen(access) then return nil end
    return access, state
  end

  function H.leave(game, mapId)
    if currentMapId(game) ~= mapId then return false, "not-in-habitat" end
    local access, state = activeAccess(game, mapId)
    if not access then return false, "missing-return-contract" end
    local left, reason = warp(game, access.sourceMap, {
      x = access.approachCell.x, y = access.approachCell.y,
      facing = access.facing,
    })
    if not left then return false, reason end
    state.active = nil
    persistRuntime(state)
    return true
  end

  local rescueInProgress = false
  local pendingBootValidationMapId
  local function rescue(game, mapId)
    if rescueInProgress then return false end
    local save = game and game.save or {}
    local fallback = save.lastHeal
    local boot = game and game.data and game.data.field
      and game.data.field.boot or {}
    local fallbackMap = fallback and (fallback.map or fallback.id)
      or boot.startMap
    local fallbackX = fallback and fallback.x or boot.startX
    local fallbackY = fallback and fallback.y or boot.startY
    if type(fallbackMap) ~= "string" or fallbackMap == mapId
        or tonumber(fallbackX) == nil or tonumber(fallbackY) == nil then
      return false
    end
    rescueInProgress = true
    local state = runtimeState(true)
    state.active = nil
    persistRuntime(state)
    local ok = warp(game, fallbackMap, {
      x = fallbackX, y = fallbackY,
      facing = fallback.facing or "down",
    })
    rescueInProgress = false
    return ok == true
  end

  local function completeDefinition(def)
    return type(def) == "table" and type(def.id) == "string"
      and tonumber(def.dex) ~= nil and type(def.name) == "string"
      and type(def.types) == "table" and #def.types > 0
      and type(def.baseStats) == "table" and tonumber(def.catchRate) ~= nil
      and type(def.growthRate) == "string"
      and type(def.level1Moves) == "table"
      and type(def.learnset) == "table" and type(def.evolutions) == "table"
      and type(def.tmhm) == "table" and type(def.cry) == "string"
      and type(def.spriteFront) == "string" and def.spriteFront ~= ""
      and type(def.spriteBack) == "string" and def.spriteBack ~= ""
      and def.icon ~= nil and type(def.dexEntry) == "table"
  end

  function H.completeFamilyAvailable(game, familyId)
    local family = Starters.definition(familyId)
    if not family or type(speciesAuthority) ~= "table"
        or type(speciesAuthority.completeFamily) ~= "function" then
      return false
    end
    -- starter_species_67 exposes a plain public function
    -- completeFamily(game, family), not a colon method. Passing the
    -- authority table as an invented receiver shifts both arguments and
    -- makes every fully registered live family fail closed.
    local ok, approved = pcall(
      speciesAuthority.completeFamily, game, family)
    if not ok or approved ~= true then return false end
    local pokemon = game and game.data and game.data.pokemon
    local cries = game and game.data and game.data.audio
      and game.data.audio.cries
    if type(pokemon) ~= "table" or type(cries) ~= "table" then return false end
    for _, species in ipairs(family.members) do
      local def = pokemon[species]
      if not completeDefinition(def) or cries[def.cry] == nil then return false end
      if type(generationRules) == "table"
          and type(generationRules.speciesAvailable) == "function"
          and generationRules.speciesAvailable(game, species, def) ~= true then
        return false
      end
    end
    return true
  end

  function H.bindSpeciesAuthority(authority, game)
    if type(authority) ~= "table"
        or type(authority.completeFamily) ~= "function" then
      return false, "invalid-species-authority"
    end
    speciesAuthority = authority
    H.refreshSpeciesAvailability(game or H.game)
    return true
  end

  -- Deliberately re-evaluates every family against live game.data.  There is
  -- no negative cache: a separately loaded 36-species/asset authority can be
  -- bound once and immediately make all reviewed habitats eligible without a
  -- save reload or reconstructed map registry.
  function H.refreshSpeciesAvailability(game)
    game = game or H.game
    local before = H.lastSpeciesAvailability or {}
    local current, changed, available = {}, false, 0
    for _, mapId in ipairs(H.order) do
      local family = H.maps[mapId].family
      local ready = H.completeFamilyAvailable(game, family)
      current[family] = ready
      if ready then available = available + 1 end
      if before[family] ~= ready then changed = true end
    end
    H.lastSpeciesAvailability = current
    if changed and type(opts.onSpeciesAvailabilityChanged) == "function" then
      pcall(opts.onSpeciesAvailabilityChanged, game, copy(current))
    end
    return copy(current), available, changed
  end

  local function surface(encDef, terrain)
    terrain = type(terrain) == "string" and terrain:lower() or ""
    if terrain == "water" or terrain == "surf" or terrain == "surfing" then
      return encDef and encDef.water
    end
    if terrain == "grass" or terrain == "indoor" or terrain == "cave" then
      return encDef and encDef.grass
    end
  end

  local function nativeInSurface(native, group)
    if type(native) ~= "table" or type(native.species) ~= "string"
        or type(group) ~= "table" or (tonumber(group.rate) or 0) <= 0
        or type(group.slots) ~= "table" then return false end
    for _, slot in ipairs(group.slots) do
      if slot.species == native.species
          and tonumber(slot.level) == tonumber(native.level) then return true end
    end
    return false
  end

  local function random(ctx)
    local source = ctx and ctx.rng or opts.random
      or (love and love.math and love.math.random) or math.random
    local value = math.floor(tonumber(source(1, 10000)) or 10000)
    return math.max(1, math.min(10000, value))
  end

  local function battleFacts(ev)
    local battle = ev and ev.battle or ev
    local mon = battle and battle.enemy and battle.enemy.mon
    return battle, mon, ev and ev.mapId
      or currentMapId(battle and battle.game)
  end

  function H.planProposal(native, encDef, ctx)
    if not enabled() then return native, nil, "feature-disabled" end
    local mapId = ctx and ctx.mapId
    local row = H.maps[mapId]
    if not row then return native, nil, "outside-habitat" end
    local game = ctx and ctx.game or H.game
    if not activeAccess(game, mapId) then
      return nil, nil, "habitat-inactive"
    end
    if ctx and (ctx.kaEncounterSource or ctx.kaProtected)
        or native and (native.kaEncounterSource or native.kaProtected) then
      return native, nil, "protected-encounter"
    end
    if not nativeInSurface(native, surface(encDef, ctx and ctx.terrain)) then
      return native, nil, "not-authored-resident"
    end
    if not H.completeFamilyAvailable(game, row.family) then
      return native, nil, "starter-family-unavailable"
    end

    H.serial = H.serial + 1
    local roll = random(ctx)
    local prismaTrial = shinySystem
      and type(shinySystem.prismaTrialAvailable) == "function"
      and shinySystem.prismaTrialAvailable(row.family) == true
    local nextRoot, result
    if prismaTrial then
      nextRoot = manager.root(true)
      result = {
        family = row.family, sighted = true, prismaTrial = true,
        reason = "prisma-trial",
      }
    else
      nextRoot, result = Starters.plan(
        manager.root(true), row.family, true, roll)
    end
    local output = copy(native)
    if result.sighted then output.species = row.family end
    output.kaProtected = true
    output.kaEncounterSource = Module.SOURCE
    output.kaHabitatFamily = row.family
    output.kaHabitatSerial = H.serial
    local transaction = {
      serial = H.serial, mapId = mapId, family = row.family,
      generation = row.generation, roll = roll,
      outputSpecies = output.species, expectedLevel = tonumber(output.level),
      result = copy(result), nextRoot = nextRoot,
      target = result.sighted == true,
      prismaTrial = prismaTrial == true,
    }
    return output, transaction
  end

  function H.propose(native, encDef, ctx)
    H.cancelPending("superseded-roll")
    local output, transaction = H.planProposal(native, encDef, ctx)
    pendingProposal = transaction
    return output, transaction
  end

  function H.cancelPending(reason)
    local pending = pendingProposal
    pendingProposal = nil
    if not pending then return false end
    pending.cancelled = true
    pending.cancelReason = reason or "cancelled"
    return true
  end

  function H.pending()
    return pendingProposal and copy(pendingProposal) or nil
  end

  function H.commitTransaction(transaction, ev)
    if not enabled() then
      if type(transaction) == "table" then transaction.cancelled = true end
      return false, "feature-disabled"
    end
    if type(transaction) ~= "table" or transaction.cancelled
        or transaction.committed then return false, "invalid-transaction" end
    local battle, mon, mapId = battleFacts(ev)
    local kind = ev and ev.kind or battle and battle.kind
    if kind ~= "wild" or not mon or battle and battle.noCatch == true
        or mapId ~= transaction.mapId
        or mon.species ~= transaction.outputSpecies
        or tonumber(mon.level) ~= transaction.expectedLevel then
      transaction.cancelled = true
      return false, "battle-mismatch"
    end
    if transaction.prismaTrial then
      if not (shinySystem and type(shinySystem.forceMon) == "function") then
        transaction.cancelled = true
        return false, "prisma-shiny-authority-unavailable"
      end
      local game = battle and battle.game or H.game
      local def = game and game.data and game.data.pokemon
        and game.data.pokemon[transaction.family]
      if shinySystem.forceMon(mon, def) ~= true then
        transaction.cancelled = true
        return false, "prisma-shiny-force-failed"
      end
      battle.kaPrismaStarterTrial = transaction.family
    end
    manager.replace(transaction.nextRoot)
    transaction.committed = true
    battle.kaStarterHabitatFamily = transaction.family
    battle.kaStarterHabitatMap = transaction.mapId
    battle.kaStarterHabitatSerial = transaction.serial
    if transaction.target then
      battle.kaStarterHabitatSpecies = transaction.family
    end
    return true, copy(transaction.result)
  end

  function H.commitStarted(ev)
    local transaction = pendingProposal
    pendingProposal = nil
    if not transaction then return false, "none" end
    return H.commitTransaction(transaction, ev)
  end

  local function catchSpecies(ev)
    return ev and (ev.species or ev.mon and ev.mon.species
      or ev.pokemon and ev.pokemon.species)
  end

  function H.completeCatch(ev)
    local battle = ev and ev.battle
    local family = battle and battle.kaStarterHabitatFamily
    local species = key(catchSpecies(ev))
    if not family or battle.kaStarterHabitatCaught
        or species ~= battle.kaStarterHabitatSpecies
        or species ~= family then return false, "not-starter-habitat-catch" end
    if battle.kaPrismaStarterTrial == family then
      if not (shinySystem
          and type(shinySystem.completePrismaTrial) == "function") then
        return false, "prisma-shiny-authority-unavailable"
      end
      local completed, why = shinySystem.completePrismaTrial(
        H.game, family)
      if not completed and why ~= "trial-unavailable" then
        return false, why or "prisma-trial-failed"
      end
      battle.kaStarterHabitatCaught = true
      return true, {
        family = family, caught = true, unlocked = true,
        prismaTrial = true, alreadyCompleted = completed ~= true,
      }
    end
    local nextRoot, result = Starters.recordCatch(manager.root(true), species)
    if not result.caught or not result.unlocked then
      return false, result.reason or "unlock-failed"
    end
    manager.replace(nextRoot)
    battle.kaStarterHabitatCaught = true
    H.refreshMapLabels(H.game)
    if type(journey.syncStarterDiscovery) == "function" and H.game
        and H.game.save then
      local synced, syncWhy = journey.syncStarterDiscovery(
        H.game.save, nextRoot)
      result.legacyCatalogSynced = synced == true
      result.legacyCatalogSyncError = synced == true and nil or syncWhy
    end
    return true, result
  end

  function H.finishBattle(ev)
    local battle = ev and ev.battle
    if not (battle and battle.kaStarterHabitatFamily) then
      return false, "not-starter-habitat-battle"
    end
    if ev.result == "caught" and not battle.kaStarterHabitatCaught then
      return H.completeCatch({
        battle = battle, species = battle.kaStarterHabitatSpecies,
      })
    end
    return true, ev.result or "closed"
  end

  -- Public composition seam for the existing transactional Wilds adapter.
  -- Visible-spawn code attaches the returned transaction to its record and
  -- calls commitTransaction only when that exact body starts a real battle.
  H.wilds = {
    plan = H.planProposal,
    commitStarted = H.commitTransaction,
    cancel = function(transaction, reason)
      if type(transaction) ~= "table" or transaction.committed then return false end
      transaction.cancelled = true
      transaction.cancelReason = reason or "visible-spawn-cancelled"
      return true
    end,
  }

  function H.catalog()
    local out = {}
    for _, id in ipairs(H.order) do
      local row = H.maps[id]
      out[#out + 1] = {
        id = row.id, index = row.index, family = row.family,
        category = row.category, generation = row.generation,
        entry = copy(row.entry), exit = copy(row.exit),
        candidateResidentsGen1To3 = copy(row.candidates),
      }
    end
    return out
  end

  function H.accessCatalog()
    local out = {}
    for _, mapId in ipairs(H.order) do
      local rows = {}
      for _, access in pairs(H.accesses[mapId] or {}) do
        rows[#rows + 1] = copy(access)
      end
      table.sort(rows, function(a, b) return a.option < b.option end)
      for _, access in ipairs(rows) do out[#out + 1] = access end
    end
    return out
  end

  function H.habitatsFor(game, species)
    if not enabled() then return {} end
    local family = Starters.familyForSpecies(species)
    local row = family and H.byFamily[family.id]
    if not row or not H.completeFamilyAvailable(game, family.id) then return {} end
    local status = manager.status and manager.status(family.generation, family.id)
      or State.status(manager.root(false), family.generation, family.id)
    if status == "unseen" then return {} end
    return { { map = row.id, level = 30, source = Module.SOURCE } }
  end

  function H.install(game)
    H.game = game
    if H.installed then return true, "already-installed" end
    if not H.accessAuthorityBound then
      return false, "access-authority-unbound"
    end
    if not H.receiptAuthorityBound then
      return false, "receipt-authority-unbound"
    end
    H.installed = true
    H.refreshResidentEncounters(game)
    H.refreshSpeciesAvailability(game)
    H.refreshMapLabels(game)

    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
        local row = ctx and H.maps[ctx.mapId]
        if not row then return nextRoll(encDef, ctx) end
        ctx.kaProtected = true
        ctx.kaEncounterSource = Module.SOURCE
        local native = nextRoll(encDef, ctx)
        if not native then H.cancelPending("no-native-encounter"); return nil end
        -- Remove only our pre-roll context marker.  The proposal receives an
        -- unowned native row and returns its own narrow protected marker.
        ctx.kaProtected, ctx.kaEncounterSource = nil, nil
        return H.propose(native, encDef, ctx)
      end, Module.ENCOUNTER_PRIORITY)
    end

    if mod.events and type(mod.events.on) == "function" then
      mod.events:on("battle.started", H.commitStarted, Module.EVENT_PRIORITY)
      mod.events:on("world.stepped", function()
        H.cancelPending("next-world-step")
      end, Module.EVENT_PRIORITY)
      mod.events:on("pokemon.caught", H.completeCatch, Module.EVENT_PRIORITY)
      mod.events:on("battle.ended", H.finishBattle, Module.EVENT_PRIORITY)
      mod.events:on("player.warped", function(ev)
        H.acceptNativeEdgeWarp(H.game, ev)
      end, Module.EVENT_PRIORITY)
      mod.events:on("map.entered", function(ev)
        local active = ev and ev.game or H.game
        local mapId = ev and (ev.mapId or ev.map and ev.map.id)
        if H.maps[mapId] and ev and ev.via == "boot" then
          -- Game:restoreSave builds and announces the overworld before it
          -- emits save.loaded.  The playthrough-scoped Legacy archive is
          -- intentionally unavailable during that earlier map event.  Judge
          -- a resumed habitat only after save.loaded has enabled and
          -- reconciled the official storage facade; ordinary runtime warps
          -- remain fail-closed immediately below.
          pendingBootValidationMapId = mapId
          return
        end
        pendingBootValidationMapId = nil
        if H.maps[mapId] and not activeAccess(active, mapId) then
          rescue(active, mapId)
        end
      end, Module.EVENT_PRIORITY)
      mod.events:on("save.loaded", function(ev)
        local mapId = pendingBootValidationMapId
        pendingBootValidationMapId = nil
        if not mapId then return end
        local active = ev and ev.game or H.game
        if currentMapId(active) == mapId
            and not activeAccess(active, mapId) then
          rescue(active, mapId)
        end
      end, Module.EVENT_PRIORITY)
      local function boundary(ev)
        H.game = ev and ev.game or H.game
        H.cancelPending("save-boundary")
        H.refreshResidentEncounters(H.game)
        if not enabled() then
          local mapId = currentMapId(H.game)
          if H.maps[mapId] then rescue(H.game, mapId) end
          return
        end
        runtimeState(true)
        H.refreshSpeciesAvailability(H.game)
        H.refreshMapLabels(H.game)
        if H.game and H.game.save
            and type(journey.syncStarterDiscovery) == "function" then
          journey.syncStarterDiscovery(H.game.save, manager.root(false))
        end
      end
      mod.events:on("save.created", boundary, 900)
      mod.events:on("save.loaded", boundary, 900)
      mod.events:on("game.ready", boundary, 900)
      mod.events:on("mod.options_changed", function(ev)
        if not (ev and ev.mod == mod.id
            and ev.key == Module.OPTION_KEY) then return end
        H.cancelPending("option-changed")
        H.refreshResidentEncounters(H.game)
        if ev.value == false then
          local mapId = currentMapId(H.game)
          if H.maps[mapId] then rescue(H.game, mapId) end
          return
        end
        H.refreshSpeciesAvailability(H.game)
        H.refreshMapLabels(H.game)
      end, 900)
    end
    return true
  end

  function H.runtimeStatus()
    local active = runtimeState(false)
    return {
      installed = H.installed,
      maps = #H.order,
      accesses = #H.accessCatalog(),
      active = active and copy(active.active) or nil,
      pending = H.pending(),
      speciesAvailability = copy(H.lastSpeciesAvailability or {}),
      residentAvailability = copy(H.lastResidentAvailability or {}),
      liveResidentMaps = H.liveResidentMaps or 0,
      accessAuthorityBound = H.accessAuthorityBound,
      receiptAuthorityBound = H.receiptAuthorityBound,
      source = Module.SOURCE,
    }
  end

  H.copy = copy
  return H
end

return create
