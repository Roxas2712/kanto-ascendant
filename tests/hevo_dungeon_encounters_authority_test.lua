-- Real main.lua/Data load for the trial-entry-bound, cycle-scaled habitats.
-- Run from gen1recomp with KA_HEVO_MOD pointing at the Authority worktree.

package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()
local root = assert(os.getenv("KA_HEVO_MOD"), "KA_HEVO_MOD required")
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."
local run = T.sdk.loadMod(root, { data = Data, root = sdkRoot })
T.eq(#run.errors, 0, "Authority main.lua loads the HEVO habitat runtime")

local exports = assert(run.loader.exports.kanto_ascendant)
local packages = assert(exports.hevoPackages,
  "real main.lua exports the authoritative package registry")
local campaign = assert(exports.hiddenEvolutionCampaign,
  "real main.lua exports the Hidden Evolution campaign")
local encounters = assert(campaign.encounters,
  "real main.lua attaches the cycle-scaled encounter controller")
local MapLoader = require("src.world.MapLoader")
local Encounter = require("src.world.Encounter")
Encounter.load(Data)
local wildsRender = assert(exports.internalWilds
    and exports.internalWilds.exports and exports.internalWilds.exports.render,
  "real main.lua exposes the bundled visible-Wilds renderer")
local wildsLogic = assert(exports.internalWilds.exports.logic,
  "real main.lua exposes the bundled visible-Wilds encounter policy")
T.eq(encounters.BASE_LEVEL, 70,
  "real runtime keeps the requested exact first-cycle level")
T.eq(encounters.LEVEL_STEP, 5,
  "real runtime adds exactly five levels per later Legacy cycle")
T.eq(encounters.MAX_LEVEL, 100,
  "real runtime caps later Legacy habitats at level 100")

local copied = false
for _, file in ipairs(campaign.COPY_SET or {}) do
  if file == "hevo_dungeon_encounters.lua" then copied = true break end
end
T.check(copied, "release handoff inventory includes the habitat runtime")

local function save(character, options)
  options = options or {}
  local flags = options.flags or {}
  if options.entered and character then
    flags[encounters.ENTERED_FLAG_PREFIX .. character] = true
  end
  local bucket = {
    hevo_persistent = { packageUnlocks = options.unlocks or {} },
    -- This authority suite validates the complete authored HEVO habitat.
    -- Sealed #1-151 substitutions are covered by the dedicated
    -- beyond_kanto_hevo_gate_test instead.
    beyond_kanto = {
      version = 1, active = true, irreversible = true,
      decision = "test_fixture",
    },
  }
  if character then
    bucket.extended_characters = { player_character = character }
  end
  if options.cycle ~= nil then
    bucket.legacy_journey = { cycle=options.cycle, runId="authority-cycle" }
  end
  return {
    flags = flags, inventory = {}, party = {}, boxes = {},
    player = options.map and { map=options.map } or {},
    pokedex = { seen = {}, owned = {} },
    modData = { kanto_ascendant = bucket },
  }
end
local function unlocksFor(character)
  local out = {}
  for _, package in ipairs(packages.byCharacter[character]) do
    out[package.id] = true
  end
  return out
end
local function setOfSlots(mapId, expectedLevel, kind)
  local out = {}
  kind = kind or "grass"
  local tableDef = assert(Data.encounters[mapId][kind])
  for _, slot in ipairs(tableDef.slots) do
    T.eq(slot.level, expectedLevel or encounters.BASE_LEVEL,
      mapId .. " " .. kind .. " has only the exact active-cycle level")
    T.check(Data.pokemon[slot.species] ~= nil,
      mapId .. " resolves " .. slot.species .. " through real Data")
    out[slot.species] = true
  end
  return out
end

for _, row in ipairs({
    { cycle=nil, level=70 }, { cycle=0, level=70 },
    { cycle=1, level=70 }, { cycle=2, level=75 },
    { cycle=6, level=95 }, { cycle=7, level=100 },
    { cycle=12, level=100 },
  }) do
  local scaled = save("RED", { entered=true, cycle=row.cycle })
  encounters.sync({ data=Data, save=scaled })
  T.eq(encounters.levelFor(scaled), row.level,
    "real cycle source maps cycle " .. tostring(row.cycle)
      .. " to exact Level " .. row.level)
  setOfSlots(encounters.MAPS.RED[1], row.level)
end
local function expectedParents(character)
  local out = {}
  for _, package in ipairs(packages.byCharacter[character]) do
    for _, target in ipairs(package.targets) do
      T.check(Data.pokemon[target.parent] ~= nil,
        target.parent .. " parent exists in real merged Data")
      T.check(Data.pokemon[target.target] ~= nil,
        target.target .. " evolution exists in real merged Data")
      local asset = wildsRender.registrationInfo[target.parent]
      T.check(asset and asset.status ~= "FALLBACK_REGISTERED"
          and asset.kind == "native_runtime_sheet" and asset.walker == true,
        target.parent .. " registers a real six-frame Wilds sheet, not a fallback")
      out[target.parent] = true
    end
  end
  return out
end
local function count(value)
  local n = 0; for _ in pairs(value or {}) do n = n + 1 end; return n
end
local function expectedWater(character)
  local out = {}
  for _, species in ipairs(
      encounters.WATER_LAYOUTS.BEYOND[character] or {}) do
    local pokemon = assert(Data.pokemon[species], species .. " missing")
    local waterType = false
    for _, typeId in ipairs(pokemon.types or {}) do
      if typeId == "WATER" then waterType = true break end
    end
    T.check(waterType,
      species .. " is a real Water type in merged game data")
    local waterRegistry = assert(wildsRender.waterSpriteRegistry,
      "bundled Wilds water registry missing")
    T.check(waterRegistry:hasKind(pokemon.dex, "swimming", "normal")
        or waterRegistry:hasKind(pokemon.dex, "levitates", "normal"),
      species .. " has a real visible-water runtime sheet")
    out[species] = true
  end
  return out
end

T.eq(count(encounters.waterMapCharacter), 4,
  "real runtime publishes water only on the four authored Surf floors")
T.eq(encounters.waterMapCharacter.KA_HEVO_TUNNEL_ALL, nil,
  "the shared tunnel owns no water encounter authority")
T.eq(encounters.waterMapCharacter.KA_HEVO_SHARED_SEALED_ANTECHAMBER, nil,
  "the shared antechamber owns no water encounter authority")
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  for _, mapId in ipairs(encounters.MAPS[character]) do
    local map = MapLoader.load(Data, mapId)
    local waterCells = 0
    for y = 0, map.heightCells - 1 do
      for x = 0, map.widthCells - 1 do
        if map:isWaterCell(x, y) then waterCells = waterCells + 1 end
      end
    end
    T.eq(waterCells > 0, encounters.waterMapCharacter[mapId] == character,
      mapId .. " water contract exactly matches its real map cells")
  end
end

local locked = save()
T.check(encounters.sync({ data = Data, save = locked }),
  "real Data accepts a locked habitat refresh")
for mapId in pairs(encounters.mapCharacter) do
  T.eq(Data.encounters[mapId].grass.rate, 0,
    mapId .. " remains absent before its trial entry")
  T.eq(#Data.encounters[mapId].grass.slots, 0,
    mapId .. " has no pre-entry visible-Wilds source")
  T.eq(Data.encounters[mapId].water.rate, 0,
    mapId .. " has no pre-entry Surf rate")
  T.eq(#Data.encounters[mapId].water.slots, 0,
    mapId .. " has no pre-entry visible-water source")
end

local packageOnly = save("RED", { unlocks=unlocksFor("RED") })
encounters.sync({ data=Data, save=packageOnly })
T.eq(Data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "real package completion cannot replace fissure admission")

local legacyRed = save(nil, { flags = {
  [encounters.ENTERED_FLAG_PREFIX .. "RED"] = true,
} })
encounters.sync({ data=Data, save=legacyRed })
T.check(Data.encounters.KA_HEVO_RED_UPPER.grass.rate > 0,
  "real pre-6.5 RED admission keeps its trial habitat")
local futureIdentity = save(nil, { flags = {
  [encounters.ENTERED_FLAG_PREFIX .. "RED"] = true,
} })
futureIdentity.modData.kanto_ascendant.extended_characters = {
  player_character = "YELLOW",
}
encounters.sync({ data=Data, save=futureIdentity })
T.eq(Data.encounters.KA_HEVO_RED_UPPER.grass.rate, 0,
  "real present future identity cannot inherit legacy RED admission")

for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local activeSave = save(character, { entered=true })
  encounters.sync({ data = Data, save = activeSave })
  local expected = expectedParents(character)
  local swimmers = expectedWater(character)
  local actual = setOfSlots(encounters.MAPS[character][1])
  T.eq(count(actual), count(expected),
    character .. " real runtime has the registry-derived parent count")
  for species in pairs(expected) do
    T.check(actual[species],
      character .. " real runtime includes parent " .. species)
  end
  for other, maps in pairs(encounters.MAPS) do
    if other ~= character then
      T.eq(Data.encounters[maps[1]].grass.rate, 0,
        character .. " admission does not open " .. other)
    end
  end
  local classic = assert(Encounter.roll(
    Data.encounters[encounters.MAPS[character][1]],
    function(low) return low end),
    character .. " classic step encounter did not roll")
  T.eq(classic.level, encounters.levelFor(activeSave),
    character .. " classic step encounter uses the same cycle-scaled level")
  T.check(expected[classic.species],
    character .. " classic step encounter stays inside its parent pool")
  for _, mapId in ipairs(encounters.MAPS[character]) do
    local water = Data.encounters[mapId].water
    if encounters.waterMapCharacter[mapId] then
      T.eq(water.rate, encounters.WATER_RATE,
        mapId .. " real Surf table uses its dedicated rate")
      T.eq(#water.slots, encounters.SLOT_COUNT,
        mapId .. " real Surf table owns ten slots")
      local gyarados = 0
      for _, slot in ipairs(water.slots) do
        if slot.species == "GYARADOS" then gyarados = gyarados + 1 end
      end
      T.eq(gyarados, 1,
        mapId .. " real Surf table owns one Gyarados slot")
      T.eq(water.slots[encounters.GYARADOS_SLOT].species, "GYARADOS",
        mapId .. " keeps Gyarados in the low-probability Gen-I bucket")
      local actualWater = setOfSlots(mapId,
        encounters.levelFor(activeSave), "water")
      T.eq(count(actualWater), count(swimmers),
        mapId .. " real Surf table has the thematic species count")
      for species in pairs(swimmers) do
        T.check(actualWater[species],
          mapId .. " real Surf table includes " .. species)
        T.check(not expected[species],
          mapId .. " water pool is disjoint from the ground/cave pool")
      end
      local classicWater = assert(Encounter.roll({ grass = water },
        function(low) return low end),
        mapId .. " classic Surf encounter did not roll")
      T.check(swimmers[classicWater.species],
        mapId .. " classic Surf stays inside its thematic water pool")
      T.eq(classicWater.level, encounters.levelFor(activeSave),
        mapId .. " classic Surf uses the cycle-scaled level")
      T.check(encounters.allowed(activeSave, mapId, classicWater,
          { data=Data, save=activeSave }, "water"),
        mapId .. " accepts its water roll in water terrain")
      T.check(not encounters.allowed(activeSave, mapId,
          Data.encounters[mapId].grass.slots[1], nil, "water"),
        mapId .. " rejects its ground/cave parent on water")
      T.check(not encounters.allowed(activeSave, mapId,
          classicWater, nil, "indoor"),
        mapId .. " rejects its water species on cave ground")
    else
      T.eq(water.rate, 0, mapId .. " has no synthetic Surf rate")
      T.eq(#water.slots, 0, mapId .. " has no synthetic Surf slots")
    end
  end
  if character == "GREEN" then
    for _, mapId in ipairs(encounters.MAPS.GREEN) do
      local map = MapLoader.load(Data, mapId)
      local grassCells = 0
      for y = 0, map.heightCells - 1 do
        for x = 0, map.widthCells - 1 do
          if map:isGrassCell(x, y) then grassCells = grassCells + 1 end
        end
      end
      T.check(grassCells > 0,
        mapId .. " has real FOREST encounter cells for classic and Visible Wilds")
    end
  end
  T.eq(next(activeSave.pokedex.seen), nil,
    character .. " table publication does not grant seen")
  T.eq(next(activeSave.pokedex.owned), nil,
    character .. " table publication does not grant owned")
end

-- Player choice remains authoritative inside HEVO too.  Exercise the actual
-- installed encounter.roll wrapper, not Encounter.roll in isolation:
--   Wilds OFF                    -> classic fallback
--   Wilds ON + Random OFF        -> visible contact encounters only
--   Wilds ON + Random ON         -> visible and classic encounters together
local optionBucket = run.loader.modOptions.kanto_ascendant or {}
run.loader.modOptions.kanto_ascendant = optionBucket
local choiceMap = encounters.MAPS.RED[1]
local choiceSave = save("RED", { entered=true, cycle=1 })
encounters.sync({ data=Data, save=choiceSave })
local choiceDef = assert(Data.encounters[choiceMap])
local function wrappedClassicRoll()
  local nativeCalls = 0
  local result = run.loader.hooks:call("encounter.roll", function(def)
    nativeCalls = nativeCalls + 1
    return Encounter.roll(def, function(low) return low end)
  end, choiceDef, { mapId=choiceMap })
  return result, nativeCalls
end

optionBucket.living_world_enabled = false
optionBucket.living_world_random_encounters = false
local classicOnly, classicOnlyCalls = wrappedClassicRoll()
T.check(classicOnly ~= nil,
  "HEVO Wild Pokemon OFF restores the classic step encounter fallback")
T.eq(classicOnlyCalls, 1,
  "HEVO Wild Pokemon OFF reaches the native encounter picker once")
T.eq(classicOnly.level, 70,
  "HEVO classic fallback keeps the cycle-scaled Level-70 baseline")

optionBucket.living_world_enabled = true
optionBucket.living_world_random_encounters = false
wildsLogic.state.mapId = choiceMap
wildsLogic.state.initialized = true
wildsLogic.state.pipelineVerified = true
wildsLogic.state.fallbackToVanilla = false
local visibleOnly, visibleOnlyCalls = wrappedClassicRoll()
T.eq(visibleOnly, nil,
  "HEVO Wild Pokemon ON plus Random Battles OFF is visible-only")
T.eq(visibleOnlyCalls, 0,
  "HEVO visible-only mode never reaches the native encounter picker")

optionBucket.living_world_random_encounters = true
local both, bothCalls = wrappedClassicRoll()
T.check(both ~= nil,
  "HEVO Wild Pokemon and Random Battles ON keeps both encounter systems")
T.eq(bothCalls, 1,
  "HEVO combined mode reaches the native encounter picker once")
T.eq(both.level, 70,
  "HEVO combined mode keeps the same cycle-scaled encounter level")

-- The same global visible/classic choice applies on Surf cells; HEVO does
-- not create a second per-dungeon option or silently reuse the land table.
local waterChoiceMap = encounters.WATER_MAPS.RED[1]
local waterChoiceDef = {
  grass = assert(Data.encounters[waterChoiceMap].water),
}
local function wrappedClassicWaterRoll()
  local nativeCalls = 0
  local result = run.loader.hooks:call("encounter.roll", function(def)
    nativeCalls = nativeCalls + 1
    return Encounter.roll(def, function(low) return low end)
  end, waterChoiceDef, { mapId=waterChoiceMap, terrain="water" })
  return result, nativeCalls
end

optionBucket.living_world_enabled = false
optionBucket.living_world_random_encounters = false
local classicWaterOnly, classicWaterCalls = wrappedClassicWaterRoll()
T.check(classicWaterOnly ~= nil,
  "global classic fallback keeps HEVO Surf encounters")
T.eq(classicWaterCalls, 1,
  "global classic fallback reaches the native Surf picker once")
T.check(expectedWater("RED")[classicWaterOnly.species],
  "global classic fallback selects the RED water pool, not land")

optionBucket.living_world_enabled = true
optionBucket.living_world_random_encounters = false
wildsLogic.state.mapId = waterChoiceMap
wildsLogic.state.initialized = true
wildsLogic.state.pipelineVerified = true
wildsLogic.state.fallbackToVanilla = false
local visibleWaterOnly, visibleWaterCalls = wrappedClassicWaterRoll()
T.eq(visibleWaterOnly, nil,
  "global visible-only mode suppresses HEVO classic Surf rolls")
T.eq(visibleWaterCalls, 0,
  "global visible-only mode never reaches the native Surf picker")

optionBucket.living_world_random_encounters = true
local bothWater, bothWaterCalls = wrappedClassicWaterRoll()
T.check(bothWater ~= nil,
  "global combined mode keeps visible and classic HEVO water encounters")
T.eq(bothWaterCalls, 1,
  "global combined mode reaches the native Surf picker once")
T.check(expectedWater("RED")[bothWater.species],
  "global combined mode keeps the RED water pool")
optionBucket.living_world_enabled = nil
optionBucket.living_world_random_encounters = nil

-- The handoff includes three loadable QA save entrypoints.  Validate their
-- exact cells and entire published find route against real map collision;
-- GREEN's route must actually reach native tall grass while RED/BLUE use the
-- visible-Wilds reachable-cave surface.
local demos = assert(loadfile(root
  .. "/tools/hevo_dungeon_encounter_demo_manifest.lua"))()
T.eq(demos.GBCFX, 0,
  "all HEVO encounter demo saves require the GBCFX renderer OFF")
T.eq(demos.BASE_CYCLE, 1,
  "visual manifest identifies the first playable cycle without off-by-one")
T.eq(demos.BASE_LEVEL, encounters.BASE_LEVEL,
  "visual manifest retains the accepted Level-70 baseline")
T.eq(demos.LEVEL_STEP, encounters.LEVEL_STEP,
  "visual manifest documents the five-level Legacy step")
T.eq(demos.MAX_LEVEL, encounters.MAX_LEVEL,
  "visual manifest documents the Level-100 cap")
for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  local demo = assert(demos[character], character .. " demo missing")
  T.eq(demo.cycle, demos.BASE_CYCLE,
    character .. " accepted visual remains a cycle-1 receipt")
  T.eq(demo.expectedLevel, demos.BASE_LEVEL,
    character .. " accepted visual remains a Level-70 receipt")
  T.eq(demo.map, encounters.MAPS[character][1],
    character .. " demo begins on the first trial floor")
  local map = MapLoader.load(Data, demo.map)
  T.check(map:isWalkableCell(demo.start.x, demo.start.y),
    character .. " demo start is walkable")
  local previous = demo.start
  local grassOnRoute = 0
  for index, cell in ipairs(demo.routeCells) do
    local x, y = cell[1], cell[2]
    T.check(map:isWalkableCell(x, y),
      character .. " demo route cell " .. index .. " is walkable")
    T.eq(math.abs(x-previous.x)+math.abs(y-previous.y), 1,
      character .. " demo route cell " .. index .. " is contiguous")
    if map:isGrassCell(x, y) then grassOnRoute = grassOnRoute + 1 end
    previous = { x=x, y=y }
  end
  if character == "GREEN" then
    T.check(grassOnRoute > 0,
      "GREEN demo route reaches native visible-Wilds grass")
  else
    T.eq(grassOnRoute, 0,
      character .. " demo correctly uses reachable cave cells")
  end
  local demoSave = save(character, { entered=true })
  T.eq(encounters.levelFor(demoSave), demo.expectedLevel,
    character .. " visual fixture resolves the documented baseline")
  encounters.sync({ data=Data, save=demoSave })
  T.eq(#Data.encounters[demo.map].grass.slots, encounters.SLOT_COUNT,
    character .. " demo publishes ten exact trial-entry slots")
end

-- Real install order: the campaign attaches its water guard to the already
-- constructed bundled Wilds logic without modifying the engine or vendor.
local installGame = {
  data = Data,
  save = save("RED", { entered=true }),
  stack = {},
  renderer = { queueWorldPostOverlay = function() return true end },
}
local installOk = campaign.install(installGame)
T.check(installOk,
  "real campaign install accepts the bundled Wilds water seam")
T.eq(wildsLogic._kaHevoWaterWrapped, true,
  "real bundled Wilds receives the HEVO-only water-pool guard")

-- Reproduce the real ordering that made an admitted cave look empty: Wilds
-- sees map.entered while that save's HEVO table is still closed, then the
-- durable save/admission sync publishes it.  The controller must re-enter the
-- exact live map and create an actor through the bundled SpawnLogic/Entity
-- path.  A fake logic counter would not exercise sprite construction, world
-- registration, cave reachability or the stale-active-map repair.
local runtimeWorld = assert(wildsLogic.mod and wildsLogic.mod.world,
  "bundled Wilds exposes its engine WorldAPI")
local runtimeGame = assert(runtimeWorld.game,
  "bundled Wilds WorldAPI retains the live engine game")
optionBucket.living_world_enabled = true
optionBucket.living_world_random_encounters = true
optionBucket.living_world_hidden = false
optionBucket.living_world_chase = false

for _, character in ipairs({ "RED", "BLUE", "GREEN" }) do
  wildsLogic:clearAll()
  local demo = assert(demos[character])
  local mapId = demo.map
  local map = MapLoader.load(Data, mapId)
  local player = {
    player = true,
    cellX = demo.start.x, cellY = demo.start.y,
    px = demo.start.x * 16, py = demo.start.y * 16,
    facing = "down",
  }
  local overworld = {
    isOverworld = true,
    map = map,
    player = player,
    entities = {},
    npcs = {},
  }
  runtimeGame.data = Data
  runtimeGame.overworld = overworld

  local beforeAdmission = save(character)
  installGame.save = beforeAdmission
  runtimeGame.save = beforeAdmission
  encounters.sync(installGame)
  wildsLogic:onMapEntered({ mapId=mapId, map=map })
  T.eq(wildsLogic:countVisibleOnMap(mapId), 0,
    character .. " real Wilds stays empty before exact trial admission")

  local admitted = save(character, { entered=true })
  installGame.save = admitted
  runtimeGame.save = admitted
  encounters.sync(installGame)
  T.check(wildsLogic.state.initialized
      and wildsLogic.state.pipelineVerified,
    character .. " admission repairs the real bundled Wilds pipeline")
  T.check(wildsLogic:countVisibleOnMap(mapId) > 0,
    character .. " admission creates a real bundled-Wilds population")

  local actor
  for _, entity in pairs(wildsLogic.entities or {}) do
    if entity.mapId == mapId and entity.overworldWildSpawn then
      actor = entity
      break
    end
  end
  T.check(actor ~= nil,
    character .. " admitted map owns a bundled SpawnLogic actor")
  T.check(actor.visibleSprite == true and actor.sprite ~= nil,
    character .. " bundled actor owns a visible SpriteRenderer")
  if not actor.registeredInWorld and wildsLogic.behaviorTick then
    -- Grass actors enter through the real 100-ms spawn-pop phase.  Advance
    -- one ordinary bundled behavior frame so the body joins ow.entities.
    wildsLogic.behaviorTick._lastT = -1000000
    wildsLogic.behaviorTick:step({})
  end
  T.check(actor.registeredInWorld == true
      and wildsRender:isEntityRegistered(overworld, actor),
    character .. " bundled actor is registered in the live overworld")
  T.eq(actor.level, encounters.BASE_LEVEL,
    character .. " bundled actor keeps the cycle-1 Level-70 baseline")

  local expected = expectedParents(character)
  T.check(expected[actor.species],
    character .. " bundled actor comes from its authored parent pool")

  -- HYBRID means the actor remains present while an ordinary step roll still
  -- reaches the engine picker.  Explicit true/true options are not rewritten
  -- by the admission refresh.
  local nativeCalls = 0
  local classic = run.loader.hooks:call("encounter.roll", function(def)
    nativeCalls = nativeCalls + 1
    return Encounter.roll(def, function(low) return low end)
  end, Data.encounters[mapId], { mapId=mapId })
  T.check(classic ~= nil,
    character .. " HYBRID keeps a classic encounter beside visible actors")
  T.eq(nativeCalls, 1,
    character .. " HYBRID reaches the classic picker exactly once")
  T.check(wildsLogic:countVisibleOnMap(mapId) > 0,
    character .. " classic HYBRID roll does not erase visible actors")
  T.eq(optionBucket.living_world_enabled, true,
    character .. " refresh preserves explicit visible-Wilds ON")
  T.eq(optionBucket.living_world_random_encounters, true,
    character .. " refresh preserves explicit Random Battles ON")
end

wildsLogic:clearAll()
runtimeGame.overworld = nil
optionBucket.living_world_enabled = nil
optionBucket.living_world_random_encounters = nil
optionBucket.living_world_hidden = nil
optionBucket.living_world_chase = nil

run.release()
T.finish("hevo_dungeon_encounters_authority_test")
