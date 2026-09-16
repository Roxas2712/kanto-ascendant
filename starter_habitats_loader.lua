-- Construction-time composition for KASC 6.7 compact starter habitats.
--
-- Keep this in a sibling chunk: main.lua is close to LuaJIT's 200-local
-- ceiling, while all map/tileset/encounter registrations must still happen
-- before the engine freezes content. Runtime authorities are late-bound in a
-- deliberate order so the earlier Signals adapter never captures nil.

return function(mod, opts)
  opts = opts or {}
  local loadSibling = assert(opts.loadSibling,
    "starter habitat loader needs main.lua's sibling loader")
  local journey = assert(opts.legacyJourney,
    "starter habitat loader needs Legacy Journey")
  local signals = assert(opts.signalsWilds,
    "starter habitat loader needs Signals Wilds")

  local Json = loadSibling(mod, "starter_habitat_json.lua")
  local tilesets = loadSibling(mod, "starter_habitat_tilesets.lua")(mod, {
    json = Json,
  })
  local habitats = loadSibling(mod, "starter_habitats.lua")(mod, {
    json = Json,
    tilesets = tilesets,
    discoveryCore = assert(opts.discoveryCore,
      "starter habitat loader needs Discovery Core"),
    legacyJourney = journey,
    explorationDevice = assert(opts.explorationDevice,
      "starter habitat loader needs the TRACE FINDER"),
    speciesAuthority = opts.speciesAuthority,
    wildsSpawnSafety = assert(opts.wildsSpawnSafety,
      "starter habitat loader needs Wilds reservations"),
    shinySystem = opts.shinySystem,
    generationRules = opts.generationRules,
    i18n = opts.i18n,
    supportLog = opts.supportLog,
    onSpeciesAvailabilityChanged = opts.onSpeciesAvailabilityChanged,
  })

  -- Public exports are assigned before any optional authority binding. The
  -- twelve maps therefore register independently from Gen4-7 assets, while
  -- encounters remain fail-closed until the later authority is complete.
  mod.exports.starterHabitatTilesets = tilesets
  mod.exports.starterHabitats = habitats
  habitats.loaderBindings = {
    content = true, access = false, receipt = false,
    species = opts.speciesAuthority ~= nil, speciesBacklink = false,
    signals = false,
  }

  local access = opts.hiddenAccessReveal
  if access ~= nil then
    assert(type(access) == "table" and type(access.definitions) == "function",
      "starter habitat loader received invalid Access V3.1 authority")
    assert(habitats.bindAccessAuthority(access.definitions()))
    habitats.loaderBindings.access = true
  end

  -- Device-local receipts reset with a playthrough. Only the Legacy archive
  -- is authoritative here, so an entrance discovered in cycle 1 stays usable
  -- in cycle 2 even when the fresh TRACE FINDER table is empty.
  if type(journey.hiddenAccessIsOpen) == "function" then
    assert(habitats.bindReceiptAuthority(function(id)
      return journey.hiddenAccessIsOpen(id)
    end))
    habitats.loaderBindings.receipt = true
  end

  if opts.speciesAuthority ~= nil then
    assert(habitats.bindSpeciesAuthority(opts.speciesAuthority))
    habitats.loaderBindings.species = true
    if type(opts.speciesAuthority.bindHabitat) == "function" then
      assert(opts.speciesAuthority.bindHabitat(habitats))
    else
      assert(type(opts.speciesAuthority.bind) == "function",
        "starter species authority has no habitat late-bind seam")
      assert(opts.speciesAuthority.bind({ habitat = habitats }))
    end
    habitats.loaderBindings.speciesBacklink = true
  end

  assert(signals.bindStarterHabitats(habitats))
  habitats.loaderBindings.signals = true
  return habitats
end
