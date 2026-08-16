-- Character- and trial-entry-bound HEVO habitat contract.
-- Run from gen1recomp with KA_HEVO_MOD pointing at the Authority worktree.

package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HEVO_MOD"), "KA_HEVO_MOD required")
local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  check(actual == expected, message .. " (got " .. tostring(actual)
    .. ", expected " .. tostring(expected) .. ")")
end
local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}; if seen[value] then return seen[value] end
  local out = {}; seen[value] = out
  for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
  return out
end
local function count(value)
  local n = 0; for _ in pairs(value or {}) do n = n + 1 end; return n
end

local hooks = { rows = {} }
function hooks:wrap(name, fn, priority)
  self.rows[name] = { fn = fn, priority = priority }
  return function() end
end
local events = { rows = {} }
function events:on(name, fn, priority)
  self.rows[name] = { fn = fn, priority = priority }
  return function() end
end

-- A narrow Wilds seam proves that HEVO replaces the normal Surf+rod merged
-- pick without changing placement or global visible/classic mode handling.
-- The unguarded fake always leaks a ground species at the wrong level.
local fakeWaterSpawn = {
  ROD_TIER = { SURF = 0 }, SOURCE = { SURF = "surf" },
}
function fakeWaterSpawn.pickForZone(zonePools, zone, opts)
  local key = tostring(zone or "near"):lower()
  local list = zonePools and zonePools[key] or nil
  fakeWaterSpawn.lastEntries = list
  local row = type(list) == "table" and list[1]
    or opts and opts.fallbackEntries and opts.fallbackEntries[1]
  if not row then return nil end
  return {
    species = row.species, speciesId = row.species,
    level = row.levelMin or row.level or 1,
    levelMin = row.levelMin, levelMax = row.levelMax,
    source = row.source, rodTier = row.rodTier,
    encounterSource = "SURF", zone = zone,
  }
end
local fakeWildsLogic = { activeMapId = nil }
function fakeWildsLogic:trySpawnWater()
  local leaked = {
    species = "RHYDON", level = 3, levelMin = 3, levelMax = 3,
    source = "old_rod", rodTier = 1,
  }
  return fakeWaterSpawn.pickForZone({
    near = { leaked }, mid = { leaked }, deep = { leaked },
  }, "NEAR", { fallbackEntries = { leaked } })
end
local mod = {
  id = "kanto_ascendant", exports = {
    internalWilds = { exports = {
      logic = fakeWildsLogic,
      lib = { require = function(name)
        if name == "water_spawn" then return fakeWaterSpawn end
      end },
    } },
  }, hooks = hooks, events = events,
}
local packages = assert(loadfile(root .. "/hevo_packages.lua"))()(mod, {
  enabled = false,
})
local encounters = assert(loadfile(root .. "/hevo_dungeon_encounters.lua"))()(mod, {
  packages = packages,
})

local TEST_POKEMON = {
  GOLDUCK={dex=55}, POLIWHIRL={dex=61}, TENTACRUEL={dex=73},
  DEWGONG={dex=87}, CLOYSTER={dex=91}, KINGLER={dex=99},
  SEAKING={dex=119}, GYARADOS={dex=130}, LAPRAS={dex=131},
  LANTURN={dex=171}, AZUMARILL={dex=184}, QUAGSIRE={dex=195},
  QWILFISH={dex=211}, CORSOLA={dex=222}, OCTILLERY={dex=224},
  MANTINE={dex=226},
}

eq(#packages.order, 15, "test uses the real fifteen-package registry")
eq(packages.audit.registeredTargets, 17,
  "test uses the real seventeen-target registry")
eq(encounters.BASE_LEVEL, 70, "first-cycle habitat baseline is exactly level 70")
eq(encounters.LEVEL, 70, "legacy LEVEL alias remains the level-70 baseline")
eq(encounters.LEVEL_STEP, 5, "each additional Legacy cycle adds five levels")
eq(encounters.MAX_LEVEL, 100, "Legacy habitat scaling caps at level 100")
eq(count(encounters.mapCharacter), 14,
  "only fourteen character-specific maps own habitats")
eq(count(encounters.waterMapCharacter), 4,
  "only the four real Surf floors own water habitats")
eq(encounters.mapCharacter.KA_HEVO_TUNNEL_ALL, nil,
  "the shared tunnel cannot leak one character's habitat")
eq(encounters.mapCharacter.KA_HEVO_SHARED_SEALED_ANTECHAMBER, nil,
  "the shared end room has no character habitat")
eq(encounters.waterMapCharacter.KA_HEVO_TUNNEL_ALL, nil,
  "the shared tunnel cannot receive a water habitat")
eq(encounters.waterMapCharacter.KA_HEVO_SHARED_SEALED_ANTECHAMBER, nil,
  "the shared end room cannot receive a water habitat")

local function save(character, options)
  options = options or {}
  local flags = copy(options.flags or {})
  if options.entered and character then
    flags[encounters.ENTERED_FLAG_PREFIX .. character] = true
  end
  local bucket = {
    hevo_persistent = { packageUnlocks = copy(options.unlocks or {}) },
  }
  if character then
    bucket.extended_characters = { player_character = character }
  end
  if options.hevoRun then bucket.hevo_run = copy(options.hevoRun) end
  if options.cycle ~= nil then
    bucket.legacy_journey = { cycle = options.cycle, runId = "cycle-fixture" }
  end
  return {
    flags = flags, inventory = {}, party = {}, boxes = {},
    player = options.map and { map = options.map } or {},
    pokedex = { seen = {}, owned = {} },
    modData = { kanto_ascendant = bucket },
  }
end
local function game(activeSave)
  return {
    save = activeSave,
    data = { encounters = {}, pokemon = copy(TEST_POKEMON) },
  }
end
local function unlocksFor(character)
  local out = {}
  for _, package in ipairs(packages.byCharacter[character]) do
    out[package.id] = true
  end
  return out
end
local function expectedParents(character)
  local out = {}
  for _, package in ipairs(packages.byCharacter[character]) do
    for _, target in ipairs(package.targets) do out[target.parent] = true end
  end
  return out
end
local function expectedWater(character)
  local out = {}
  for _, species in ipairs(
      encounters.WATER_LAYOUTS.KANTO[character] or {}) do
    out[species] = true
  end
  return out
end
local function slotSpecies(grass, expectedLevel)
  local out = {}
  for _, slot in ipairs(grass.slots or {}) do
    eq(slot.level, expectedLevel or encounters.BASE_LEVEL,
      "every populated encounter slot uses its active cycle level")
    out[slot.species] = true
  end
  return out
end

eq(encounters.levelFor(save("RED")), 70,
  "ordinary pre-Legacy saves use the cycle-1 baseline")
eq(encounters.levelFor(save("RED", { cycle=0 })), 70,
  "legacy archive cycle zero cannot underflow below the baseline")
eq(encounters.levelFor(save("RED", { cycle=1 })), 70,
  "first playable Legacy cycle has no off-by-one level increase")
eq(encounters.levelFor(save("RED", { cycle=2 })), 75,
  "second Legacy cycle receives exactly one five-level step")
eq(encounters.levelFor(save("RED", { cycle=6 })), 95,
  "sixth Legacy cycle receives five steps")
eq(encounters.levelFor(save("RED", { cycle=7 })), 100,
  "seventh Legacy cycle reaches the exact cap")
eq(encounters.levelFor(save("RED", { cycle=99 })), 100,
  "later Legacy cycles remain capped at level 100")
eq(encounters.levelFor(save("RED", { cycle="bad" })), 70,
  "malformed Legacy cycle data fails safely to the baseline")
local function sameSet(actual, expected, message)
  eq(count(actual), count(expected), message .. " count")
  for id in pairs(expected) do check(actual[id], message .. " includes " .. id) end
end

local locked = game(save())
check(encounters.sync(locked), "locked save synchronizes")
for mapId in pairs(encounters.mapCharacter) do
  local def = locked.data.encounters[mapId]
  eq(def.grass.rate, 0, mapId .. " has no pre-entry encounter rate")
  eq(#def.grass.slots, 0, mapId .. " has no pre-entry visible source")
  eq(def.water.rate, 0, mapId .. " has no pre-entry Surf rate")
  eq(#def.water.slots, 0, mapId .. " has no pre-entry water source")
  check(def.kaProtected and def.kaEncounterSource == "hevo_dungeon",
    mapId .. " carries the protected runtime marker")
  eq(def.kaMaxVisible, encounters.MAX_VISIBLE,
    mapId .. " carries the trial-specific visible-spawn cap")
end

-- Package completion, checkpoint/statue scratch data, identity and admission
-- are four different concerns.  Only matching identity plus the real fissure
-- entry (or a save physically inside that same trial) publishes habitats.
local packageOnly = game(save("RED", {
  unlocks = unlocksFor("RED"),
  hevoRun = { red = { checkpoint="KA_HEVO_RED_SHRINE", sight=5,
    completed=true } },
}))
encounters.sync(packageOnly)
eq(packageOnly.data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "package/checkpoint/statue completion cannot substitute for trial entry")
local identityOnly = game(save("RED")); encounters.sync(identityOnly)
eq(identityOnly.data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "matching identity without trial admission fails closed")
check(not encounters.allowed(identityOnly.save, "KA_HEVO_RED_LOWER",
    { species="GYARADOS", level=70 }, identityOnly, "water"),
  "matching identity without trial admission cannot authorize a water roll")
local discoveryOnly = game(save("RED", { flags = {
  KA_HEVO_FISSURE_DISCOVERED_RED = true,
} })); encounters.sync(discoveryOnly)
eq(discoveryOnly.data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "researcher discovery opens only the entrance, never the habitat itself")
local legacyRed = game(save(nil, { flags = {
  [encounters.ENTERED_FLAG_PREFIX .. "RED"] = true,
} })); encounters.sync(legacyRed)
check(legacyRed.data.encounters.KA_HEVO_RED_UPPER.grass.rate > 0,
  "pre-6.5 RED admission without a character record keeps its habitat")
local futureIdentity = save(nil, { flags = {
  [encounters.ENTERED_FLAG_PREFIX .. "RED"] = true,
} })
futureIdentity.modData.kanto_ascendant.extended_characters = {
  player_character = "YELLOW",
}
local futureGame = game(futureIdentity); encounters.sync(futureGame)
eq(futureGame.data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "present future identity cannot inherit the legacy RED habitat")
local wrongIdentity = game(save("BLUE", { flags = {
  [encounters.ENTERED_FLAG_PREFIX .. "RED"] = true,
} })); encounters.sync(wrongIdentity)
eq(wrongIdentity.data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "a foreign active character cannot consume RED admission")
local stringFlag = game(save("RED", { flags = {
  [encounters.ENTERED_FLAG_PREFIX .. "RED"] = "true",
} })); encounters.sync(stringFlag)
eq(stringFlag.data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "non-boolean admission data fails closed")

for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local active = game(save(character, { entered=true }))
  check(encounters.sync(active), character .. " admitted trial synchronizes")
  local expected = expectedParents(character)
  local expectedSwimmers = expectedWater(character)
  for _, mapId in ipairs(encounters.MAPS[character]) do
    local grass = active.data.encounters[mapId].grass
    eq(#grass.slots, 10, mapId .. " owns ten encounter slots")
    sameSet(slotSpecies(grass), expected,
      mapId .. " derives parents from its character registry")
    eq(grass.rate, encounters.RATE[character],
      mapId .. " uses its Gen-I terrain rate")
    eq(active.data.encounters[mapId].kaMaxVisible, 3,
      mapId .. " never lets high Wilds density obscure its puzzle relics")
    local water = active.data.encounters[mapId].water
    if encounters.waterMapCharacter[mapId] then
      eq(#water.slots, encounters.SLOT_COUNT,
        mapId .. " owns ten separate Surf slots")
      eq(water.rate, encounters.WATER_RATE,
        mapId .. " uses the dedicated Surf rate")
      local gyarados = 0
      local totalWeight = 0
      for index, slot in ipairs(water.slots) do
        eq(slot.weight, encounters.WATER_SLOT_WEIGHTS[index],
          mapId .. " preserves Gen-I Surf bucket " .. index)
        totalWeight = totalWeight + slot.weight
        if slot.species == "GYARADOS" then gyarados = gyarados + 1 end
      end
      eq(totalWeight, 256,
        mapId .. " visible Surf weights sum to the native 256 bucket")
      eq(gyarados, 1,
        mapId .. " owns exactly one low-probability Gyarados slot")
      eq(water.slots[encounters.GYARADOS_SLOT].species, "GYARADOS",
        mapId .. " keeps Gyarados in the authored low-probability bucket")
      sameSet(slotSpecies(water), expectedSwimmers,
        mapId .. " uses only its thematic Water-type pool")
      for species in pairs(expected) do
        check(not slotSpecies(water)[species],
          mapId .. " never leaks ground parent " .. species .. " into Surf")
      end
    else
      eq(water.rate, 0, mapId .. " has no authored water surface")
      eq(#water.slots, 0, mapId .. " has no synthetic Surf pool")
    end
  end
  for _, package in ipairs(packages.byCharacter[character]) do
    for _, target in ipairs(package.targets) do
      for _, mapId in ipairs(encounters.MAPS[character]) do
        check(not slotSpecies(active.data.encounters[mapId].grass)[target.target],
          mapId .. " does not bypass " .. package.id .. " with final " .. target.target)
      end
    end
  end
  eq(count(active.save.modData.kanto_ascendant.hevo_persistent.packageUnlocks),
    0, character .. " habitat needs no completed package")
  for other, maps in pairs(encounters.MAPS) do
    if other ~= character then
      eq(active.data.encounters[maps[1]].grass.rate, 0,
        character .. " admission cannot open " .. other)
    end
  end
end

-- Slot transitions clear the process-global Data tables before the incoming
-- save is authorized.  Fresh New Game stays empty; a later BLUE load rebuilds
-- BLUE alone and cannot retain the outgoing RED habitat.
local outgoing = game(save("RED", { entered=true }))
encounters.sync(outgoing)
check(outgoing.data.encounters.KA_HEVO_RED_UPPER.grass.rate > 0,
  "outgoing RED fixture begins with its admitted habitat")
encounters.install(outgoing)
events.rows["save.loading"].fn({ game=outgoing, save=outgoing.save })
for mapId in pairs(encounters.mapCharacter) do
  eq(outgoing.data.encounters[mapId].grass.rate, 0,
    mapId .. " is empty during save.loading")
  eq(outgoing.data.encounters[mapId].water.rate, 0,
    mapId .. " water is empty during save.loading")
end
local fresh = { data=outgoing.data, save=save(nil) }
events.rows["save.created"].fn({ game=fresh, save=fresh.save })
for mapId in pairs(encounters.mapCharacter) do
  eq(fresh.data.encounters[mapId].grass.rate, 0,
    mapId .. " remains empty in a fresh New Game")
  eq(fresh.data.encounters[mapId].water.rate, 0,
    mapId .. " water remains empty in a fresh New Game")
end
local incomingBlue = { data=outgoing.data,
  save=save("BLUE", { entered=true }) }
events.rows["save.loaded"].fn({ game=incomingBlue, save=incomingBlue.save })
check(incomingBlue.data.encounters.KA_HEVO_BLUE_FROST_THRESHOLD.grass.rate > 0,
  "incoming BLUE save rebuilds its admitted habitat")
check(incomingBlue.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.water.rate > 0,
  "incoming BLUE save rebuilds its admitted water habitat")
for _, mapId in ipairs(encounters.MAPS.RED) do
  eq(incomingBlue.data.encounters[mapId].grass.rate, 0,
    mapId .. " does not survive the RED to BLUE slot transition")
  eq(incomingBlue.data.encounters[mapId].water.rate, 0,
    mapId .. " water does not survive the RED to BLUE slot transition")
end

local greenDual = game(save("GREEN", { entered=true }))
encounters.sync(greenDual)
local greenSpecies = slotSpecies(
  greenDual.data.encounters.KA_HEVO_GREEN_MIST.grass)
check(greenSpecies.TANGELA and greenSpecies.YANMA,
  "GREEN admission includes both parents from its dual-target package")

for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local inProgress = game(save(character, {
    map = encounters.MAPS[character][1],
  }))
  encounters.sync(inProgress)
  sameSet(slotSpecies(inProgress.data.encounters[
      encounters.MAPS[character][1]].grass), expectedParents(character),
    character .. " in-progress save inside its trial migrates safely")
end

-- Hoenn starters remain the existing earned Legacy gifts, never repeatable
-- cave wildlife.  This keeps the completed-path starter entitlement intact.
local forbiddenHoenn = {
  TREECKO=true, GROVYLE=true, SCEPTILE=true,
  TORCHIC=true, COMBUSKEN=true, BLAZIKEN=true,
  MUDKIP=true, MARSHTOMP=true, SWAMPERT=true,
}
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local active = game(save(character, { entered=true }))
  encounters.sync(active)
  for _, mapId in ipairs(encounters.MAPS[character]) do
    for _, slot in ipairs(active.data.encounters[mapId].grass.slots) do
      check(not forbiddenHoenn[slot.species],
        mapId .. " does not turn earned Hoenn starters into wild catches")
    end
  end
end

-- Historical flags may coexist across Journeys, but only the active traveler
-- owns a live habitat.  Re-entering with that traveler remains repeatable.
local later = save("BLUE", { entered=true, cycle=3, flags = {
  [encounters.ENTERED_FLAG_PREFIX .. "RED"] = true,
} })
local reloaded = game(later); encounters.sync(reloaded)
eq(reloaded.data.encounters.KA_HEVO_RED_LOWER.grass.rate, 0,
  "later BLUE journey does not reactivate historical RED admission")
sameSet(slotSpecies(reloaded.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.grass, 80),
  expectedParents("BLUE"), "reloaded BLUE journey restores its habitat")
sameSet(slotSpecies(reloaded.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.water, 80),
  expectedWater("BLUE"), "reloaded BLUE journey restores its water habitat")
eq(reloaded.data.encounters.KA_HEVO_GREEN_MIST.grass.rate, 0,
  "reloaded RED-to-BLUE journey cannot pre-open GREEN")
eq(count(later.modData.kanto_ascendant.hevo_persistent.packageUnlocks), 0,
  "encounter synchronization never manufactures package unlocks")

-- A full party and full boxes remain entirely on the engine's ordinary wild
-- capture/catch-destination path.  Merely publishing habitats grants, sees or
-- owns nothing and cannot overwrite a destination record.
local storageSave = save("GREEN", { entered=true })
for i = 1, 6 do storageSave.party[i] = { species = "RATTATA", marker = i } end
for box = 1, 12 do
  storageSave.boxes[box] = {}
  for i = 1, 20 do
    storageSave.boxes[box][i] = { species = "PIDGEY", marker = box * 100 + i }
  end
end
storageSave.pokedex.seen.PIKACHU = true
storageSave.pokedex.owned.PIKACHU = true
local partyRef, boxesRef, dexRef = storageSave.party, storageSave.boxes,
  storageSave.pokedex
encounters.sync(game(storageSave))
eq(storageSave.party, partyRef, "habitat sync cannot touch a full party")
eq(storageSave.boxes, boxesRef, "habitat sync cannot touch full boxes")
eq(storageSave.pokedex, dexRef, "habitat sync cannot replace Pokédex state")
eq(count(storageSave.pokedex.seen), 1,
  "publishing an encounter never marks a species seen")
eq(count(storageSave.pokedex.owned), 1,
  "publishing an encounter never marks a species owned")

-- Runtime hook protection: exact valid candidates survive, foreign Johto or
-- another color is suppressed, and the species randomizer is never invoked.
local redTrial = game(save("RED", { entered=true, cycle=4 }))
encounters.install(redTrial)
eq(hooks.rows["encounter.roll"].priority, 2000,
  "HEVO roll validation runs outside ordinary replacement hooks")
eq(hooks.rows["encounter.species"].priority, 2000,
  "HEVO species protection runs outside the randomizer")
local rollCtx = { mapId = "KA_HEVO_RED_UPPER", rng = function() return 0 end }
local valid = hooks.rows["encounter.roll"].fn(function()
  return { species = "RHYDON", level = 85 }
end, redTrial.data.encounters.KA_HEVO_RED_UPPER, rollCtx)
check(valid and valid.species == "RHYDON" and valid.level == 85
    and valid.kaProtected and rollCtx.kaProtected,
  "valid RED roll remains exact and marks the shared context protected")
local leaked = hooks.rows["encounter.roll"].fn(function()
  return { species = "TANGELA", level = 85 }
end, redTrial.data.encounters.KA_HEVO_RED_UPPER,
  { mapId = "KA_HEVO_RED_UPPER" })
eq(leaked, nil, "foreign replacement cannot leak into a RED habitat")
local waterCtx = { mapId = "KA_HEVO_RED_LOWER", terrain = "water" }
local validWater = hooks.rows["encounter.roll"].fn(function()
  return { species = "GYARADOS", level = 85 }
end, { grass = redTrial.data.encounters.KA_HEVO_RED_LOWER.water }, waterCtx)
check(validWater and validWater.species == "GYARADOS"
    and validWater.level == 85 and validWater.kaProtected,
  "classic Surf keeps the authored RED swimmer and cycle level")
local groundOnWater = hooks.rows["encounter.roll"].fn(function()
  return { species = "RHYDON", level = 85 }
end, { grass = redTrial.data.encounters.KA_HEVO_RED_LOWER.water },
  { mapId = "KA_HEVO_RED_LOWER", terrain = "water" })
eq(groundOnWater, nil, "classic Surf rejects the ground/cave parent pool")
local waterOnLand = hooks.rows["encounter.roll"].fn(function()
  return { species = "GYARADOS", level = 85 }
end, redTrial.data.encounters.KA_HEVO_RED_LOWER,
  { mapId = "KA_HEVO_RED_LOWER", terrain = "indoor" })
eq(waterOnLand, nil, "land/cave rolls reject the separate water pool")
local randomizerCalls = 0
local protected = hooks.rows["encounter.species"].fn(function()
  randomizerCalls = randomizerCalls + 1
  return { species = "MURKROW", level = 12 }
end, { species = "RHYDON", level = 85 },
  { mapId = "KA_HEVO_RED_UPPER" })
eq(randomizerCalls, 1,
  "protected marker reaches downstream run-rule bookkeeping once")
eq(protected.species, "RHYDON", "randomizer-on keeps the authored parent")
eq(protected.level, 85, "randomizer-on keeps the exact cycle-scaled level")
local ordinaryCalls = 0
hooks.rows["encounter.species"].fn(function(row)
  ordinaryCalls = ordinaryCalls + 1; return row
end, { species = "RATTATA", level = 3 }, { mapId = "ROUTE_1" })
eq(ordinaryCalls, 1, "ordinary Kanto encounters remain in the hook chain")

-- Visible Wilds normally merges global rod pools into water.  The HEVO guard
-- must replace that one pick for every traveler while leaving ordinary maps
-- untouched and failing closed when the active save has no trial admission.
for _, row in ipairs({
    { "RED", "KA_HEVO_RED_LOWER", 1, 70 },
    { "BLUE", "KA_HEVO_BLUE_TIDAL_DEPTHS", 3, 80 },
    { "GREEN", "KA_HEVO_GREEN_GROVE", 7, 100 },
    { "GREEN", "KA_HEVO_GREEN_RAYQUAZA_SHRINE", 2, 75 },
  }) do
  local character, mapId, cycle, expectedLevel =
    row[1], row[2], row[3], row[4]
  local active = game(save(character, { entered=true, cycle=cycle }))
  encounters.sync(active)
  fakeWildsLogic.activeMapId = mapId
  local record = fakeWildsLogic:trySpawnWater(active, {})
  check(record and expectedWater(character)[record.species],
    mapId .. " visible water spawn stays in the thematic pool")
  eq(record.level, expectedLevel,
    mapId .. " visible water spawn keeps the cycle-scaled level")
  check(not expectedParents(character)[record.species],
    mapId .. " visible water spawn never uses the ground/cave pool")
  local visibleWeight, visibleGyarados = 0, nil
  for _, entry in ipairs(fakeWaterSpawn.lastEntries or {}) do
    visibleWeight = visibleWeight + assert(entry.weight)
    if entry.species == "GYARADOS" then visibleGyarados = entry.weight end
  end
  eq(visibleWeight, 256,
    mapId .. " passes native Surf weights into Visible Wilds")
  eq(visibleGyarados, 11,
    mapId .. " keeps visible Gyarados in the 11/256 base bucket")
end
local poisonedWater = game(save("RED", { entered=true }))
encounters.sync(poisonedWater)
local poisonedSlots =
  poisonedWater.data.encounters.KA_HEVO_RED_LOWER.water.slots
table.insert(poisonedSlots, 1, { species="RHYDON", level=70 })
table.insert(poisonedSlots, 2, { species="MAGIKARP", level=5 })
fakeWildsLogic.activeMapId = "KA_HEVO_RED_LOWER"
local filteredWater = fakeWildsLogic:trySpawnWater(poisonedWater, {})
check(filteredWater and expectedWater("RED")[filteredWater.species],
  "visible water filters both ground-table and generic low-level rod leakage")
poisonedWater.data.encounters.KA_HEVO_RED_LOWER.water.slots = {
  { species="RHYDON", level=70 }, { species="MAGIKARP", level=5 },
}
local fullyForeignWater = fakeWildsLogic:trySpawnWater(poisonedWater, {})
eq(fullyForeignWater, nil,
  "visible water fails closed when every published slot is foreign")
fakeWildsLogic.activeMapId = "KA_HEVO_RED_LOWER"
local noAdmission = fakeWildsLogic:trySpawnWater(locked, {})
eq(noAdmission, nil,
  "visible water fails closed when the active save has no trial admission")
fakeWildsLogic.activeMapId = "ROUTE_1"
local ordinaryWater = fakeWildsLogic:trySpawnWater(game(save()), {})
eq(ordinaryWater.species, "RHYDON",
  "the HEVO water guard leaves ordinary Wilds maps untouched")

for _, name in ipairs({ "save.loaded", "save.writing", "map.entered" }) do
  check(events.rows[name] and events.rows[name].priority == 2000,
    name .. " refreshes habitats before visible Wilds initializes")
end
local afterWrite = save("BLUE", { entered=true, cycle=6,
  unlocks={ protector=true, electirizer=true } })
redTrial.save = afterWrite
events.rows["save.writing"].fn({ save = afterWrite })
sameSet(slotSpecies(redTrial.data.encounters.KA_HEVO_BLUE_FROST_HALL.grass, 95),
  expectedParents("BLUE"),
  "durable save write restores the admitted BLUE trial, not package subset")
sameSet(slotSpecies(
    redTrial.data.encounters.KA_HEVO_BLUE_TIDAL_DEPTHS.water, 95),
  expectedWater("BLUE"),
  "durable save write restores BLUE's cycle-scaled water habitat")
eq(redTrial.data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "save write closes the no-longer-active RED habitat")
eq(redTrial.data.encounters.KA_HEVO_RED_LOWER.water.rate, 0,
  "save write closes the no-longer-active RED water habitat")

-- A synchronized table and the live Wilds population must not drift apart.
-- Rebuild only the exact live HEVO map: never replay a foreign active map,
-- never override Wilds OFF, and do not churn an already coherent population.
local liveMap = { id = "KA_HEVO_RED_UPPER" }
local visibleOptions = { enabled = true, random = true }
local refreshGame
local refreshLogic = {
  activeMapId = liveMap.id,
  visible = 0,
  refreshCalls = 0,
  targetWaterCount = 0,
  state = {
    mapId = liveMap.id, initialized = true, pipelineVerified = true,
    targetSpawnCount = 3,
  },
  mod = { world = {
    overworld = function() return { map = liveMap } end,
  } },
}
function refreshLogic:featureActive()
  return visibleOptions.enabled
end
function refreshLogic:countVisibleOnMap(mapId)
  if mapId ~= self.activeMapId then return 0 end
  return self.visible
end
function refreshLogic:onMapEntered(ev)
  eq(ev.mapId, liveMap.id,
    "population repair receives only the exact live map")
  check(encounters.mapCharacter[ev.mapId] ~= nil,
    "population repair never enters an ordinary/foreign map")
  self.refreshCalls = self.refreshCalls + 1
  self.activeMapId = ev.mapId
  local def = refreshGame.data.encounters[ev.mapId]
  local published = def and def.grass and #def.grass.slots > 0
  self.visible = published and 1 or 0
  self.state = {
    mapId = ev.mapId,
    initialized = published,
    pipelineVerified = published,
    targetSpawnCount = published and 3 or 0,
  }
  return published
end
mod.exports.internalWilds.exports.logic = refreshLogic

refreshGame = game(save("RED", { entered=true }))
encounters.sync(refreshGame, liveMap.id)
eq(refreshLogic.refreshCalls, 1,
  "admission sync repairs an empty live HEVO population")
eq(refreshLogic.visible, 1,
  "admission sync leaves at least one live visible actor")
encounters.sync(refreshGame, liveMap.id)
eq(refreshLogic.refreshCalls, 1,
  "coherent live HEVO population is not cleared or duplicated")
refreshLogic.visible = 0
encounters.sync(refreshGame, liveMap.id)
eq(refreshLogic.refreshCalls, 2,
  "zero actors below a positive target is repaired on the next sync")

visibleOptions.enabled = false
refreshLogic.visible = 0
refreshGame.save = save("BLUE", { entered=true })
encounters.sync(refreshGame, liveMap.id)
eq(refreshLogic.refreshCalls, 2,
  "Wilds OFF remains authoritative even when admission changes")
check(visibleOptions.enabled == false and visibleOptions.random == true,
  "population repair never rewrites visible/random encounter choices")
visibleOptions.enabled = true
refreshGame.save = save("RED", { entered=true })
encounters.sync(refreshGame, liveMap.id)
eq(refreshLogic.refreshCalls, 3,
  "re-enabled Wilds repairs the now-admitted live habitat")

refreshLogic.activeMapId = "ROUTE_1"
refreshLogic.state = {
  mapId = "ROUTE_1", initialized = true, pipelineVerified = true,
  targetSpawnCount = 3,
}
refreshGame.save = save("BLUE", { entered=true })
local beforeForeign = refreshLogic.refreshCalls
encounters.sync(refreshGame, liveMap.id)
eq(refreshLogic.refreshCalls, beforeForeign,
  "sync never clears a foreign Wilds active map during map handoff")

refreshLogic.activeMapId = liveMap.id
refreshLogic.state = {
  mapId = liveMap.id, initialized = true, pipelineVerified = true,
  targetSpawnCount = 3,
}
refreshLogic.visible = 1
liveMap.id = "ROUTE_1"
refreshGame.save = save("RED", { entered=true })
encounters.sync(refreshGame, "KA_HEVO_RED_UPPER")
eq(refreshLogic.refreshCalls, beforeForeign,
  "sync never replays a HEVO map that is not the exact live map")

liveMap.id = "KA_HEVO_RED_UPPER"
refreshLogic.activeMapId = liveMap.id
refreshLogic.state = {
  mapId = liveMap.id, initialized = true, pipelineVerified = true,
  targetSpawnCount = 3,
}
refreshLogic.visible = 1
refreshGame.save = save("BLUE", { entered=true })
encounters.sync(refreshGame, liveMap.id)
eq(refreshLogic.refreshCalls, beforeForeign + 1,
  "closing live admission clears its stale visible population")
eq(refreshLogic.visible, 0,
  "closed live admission retains no visible HEVO actors")

refreshGame.save = save("RED", { entered=true })
refreshLogic.activeMapId = nil
refreshLogic.state = {}
refreshLogic.visible = 0
encounters.sync(refreshGame, liveMap.id)
local beforeUnclaimed = refreshLogic.refreshCalls
check(encounters.refreshVisible(refreshGame, liveMap.id,
    encounters._lastSyncChangedMaps, true),
  "late install may claim and initialize the exact live HEVO map once")
eq(refreshLogic.refreshCalls, beforeUnclaimed + 1,
  "late-install recovery creates the missing live population")

print(("HEVO DUNGEON ENCOUNTERS PASS: %d assertions"):format(assertions))
