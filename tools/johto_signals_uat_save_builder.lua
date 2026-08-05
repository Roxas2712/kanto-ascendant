-- Creates isolated, native-format Kanto Ascendant 6.0 Signals UAT saves.
--
-- This is a POKEPORT_DRIVER, not a standalone Lua script.  It intentionally
-- refuses to run unless the engine uses the dedicated LOVE identity below,
-- and it refuses portable mode because portable.txt would redirect writes
-- away from that identity.
--
-- Run once for each game version from the gen1recomp root:
--
--   POKEPORT_IDENTITY=kanto-ascendant-signals-uat \
--   POKEPORT_VERSION=red \
--   POKEPORT_DRIVER=/absolute/path/to/johto_signals_uat_save_builder.lua \
--   /absolute/path/to/gen1recomp/.tools/love-11.5-macos/love.app/Contents/MacOS/love .
--
-- Optional original source-save copies with recorded provenance
-- (semicolon-separated paths):
--
--   KA_SIGNALS_UPGRADE_RED_SAVE=/absolute/path/to/one/save.lua
--   KA_SIGNALS_UPGRADE_RED_SAVES=/path/to/1.x.lua;/path/to/5.3.lua
--
-- BLUE and YELLOW use the corresponding environment-variable names.  The
-- source file is read only.  No fabricated "old-version" save is generated.

local REQUESTED_IDENTITY = os.getenv("KA_SIGNALS_UAT_IDENTITY")
  or "kanto-ascendant-signals-uat"
local ALLOWED_IDENTITIES = {
  ["kanto-ascendant-signals-uat"] = true,
  ["kanto-ascendant-signals-voxel-uat"] = true,
}
assert(ALLOWED_IDENTITIES[REQUESTED_IDENTITY],
  "REFUSING TO WRITE: unsupported Signals UAT identity")
local IDENTITY = REQUESTED_IDENTITY
local MOD_ID = "trainer_rematch"
local MOD_VERSION = "6.0.4"
local MANIFEST_SCHEMA = 1

local FORBIDDEN_MAP_WORDS = {
  "ORANGE",
  "STARFALL",
}

local BADGES = {
  { item = "BOULDERBADGE", flag = "EVENT_BEAT_BROCK" },
  { item = "CASCADEBADGE", flag = "EVENT_BEAT_MISTY" },
  { item = "THUNDERBADGE", flag = "EVENT_BEAT_LT_SURGE" },
  { item = "RAINBOWBADGE", flag = "EVENT_BEAT_ERIKA" },
  { item = "SOULBADGE", flag = "EVENT_BEAT_KOGA" },
  { item = "MARSHBADGE", flag = "EVENT_BEAT_SABRINA" },
  { item = "VOLCANOBADGE", flag = "EVENT_BEAT_BLAINE" },
  { item = "EARTHBADGE", flag = "EVENT_BEAT_GIOVANNI" },
}

local function merge(base, changes)
  local out = {}
  for key, value in pairs(base or {}) do out[key] = value end
  for key, value in pairs(changes or {}) do out[key] = value end
  return out
end

local function splitPaths(value)
  local out = {}
  if type(value) ~= "string" then return out end
  for path in value:gmatch("[^;]+") do
    path = path:match("^%s*(.-)%s*$")
    if path ~= "" then out[#out + 1] = path end
  end
  return out
end

local function mapIsForbidden(mapId)
  local upper = tostring(mapId or ""):upper()
  for _, word in ipairs(FORBIDDEN_MAP_WORDS) do
    if upper:find(word, 1, true) then return true, word end
  end
  return false
end

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local Bag = require("src.inventory.Bag")
  local BattleState = require("src.battle.BattleState")
  local Boxes = require("src.pokemon.Boxes")
  local GameVersion = require("src.core.GameVersion")
  local Map = require("src.world.Map")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")

  U.wait(20)

  assert(love and love.filesystem,
    "Johto Signals UAT builder requires the live LOVE engine")
  assert(love.filesystem.getIdentity() == IDENTITY,
    ("REFUSING TO WRITE: LOVE identity is %q, expected %q")
      :format(tostring(love.filesystem.getIdentity()), IDENTITY))
  assert(os.getenv("POKEPORT_IDENTITY") == IDENTITY,
    "REFUSING TO WRITE: POKEPORT_IDENTITY must be explicitly set")
  assert(SaveData.portableBaseDir() == nil,
    "REFUSING TO WRITE: portable.txt redirects saves outside UAT identity")

  local version = GameVersion.get()
  assert(version == "red" or version == "blue" or version == "yellow",
    "unsupported POKEPORT_VERSION: " .. tostring(version))
  assert(os.getenv("POKEPORT_VERSION") == version,
    "POKEPORT_VERSION must explicitly match the live engine version")

  local exports = assert(
    game.mods and game.mods.exports and game.mods.exports[MOD_ID],
    "Kanto Ascendant must be enabled before building UAT saves")
  local loadedAscendant = game.mods.mods and game.mods.mods[MOD_ID]
  assert(loadedAscendant and loadedAscendant.manifest
      and loadedAscendant.manifest.version == MOD_VERSION,
    ("UAT builder requires exact Kanto Ascendant %s, found %s")
      :format(MOD_VERSION,
        tostring(loadedAscendant and loadedAscendant.manifest
          and loadedAscendant.manifest.version)))
  for id, loaded in pairs(game.mods.mods or {}) do
    local active = loaded and loaded.state == "loaded"
    if active and id ~= MOD_ID then
      error("Signals UAT requires every other mod disabled: " .. tostring(id))
    end
  end
  assert(exports.johtoSignalsState and exports.johtoSignals
      and exports.mythicSignals and exports.signalsHub
      and exports.driftglassPrisms,
    "enabled Kanto Ascendant build does not expose the 6.0 Signals APIs")
  local signalsContent = assert(exports.johtoSignalsContent,
    "6.0 Driftglass content export is missing")
  local prisms = exports.driftglassPrisms
  assert(signalsContent.MAP_ID == "KANTO_ASCENDANT_DRIFTGLASS",
    "unexpected Signals hub map: " .. tostring(signalsContent.MAP_ID))
  assert(prisms.MAP_ID == "KANTO_ASCENDANT_PRISM_GROTTO",
    "unexpected Prism Grotto map: " .. tostring(prisms.MAP_ID))

  local function copy(value)
    if type(value) ~= "table" then return value end
    return assert(SaveData.decode(SaveData.encode(value)))
  end

  local function assertAllowedMap(mapId)
    local forbidden, word = mapIsForbidden(mapId)
    assert(not forbidden,
      ("frozen experimental map rejected (%s): %s")
        :format(tostring(word), tostring(mapId)))
    return assert(game.data.maps[mapId],
      "map is not present in merged game data: " .. tostring(mapId))
  end

  local function blockedCell(map, x, y)
    if map.warpAt[y * map.widthCells + x] then return true end
    if map.signAt[y * map.widthCells + x] then return true end
    for _, object in ipairs(map.def.objects or {}) do
      if tonumber(object.x) == x and tonumber(object.y) == y then
        return true
      end
    end
    return false
  end

  local function safeCell(mapId, terrain, preferred)
    local def = assertAllowedMap(mapId)
    local tileset = assert(game.data.tilesets[def.tileset],
      ("map %s has unknown tileset %s")
        :format(mapId, tostring(def.tileset)))
    local map = Map.new(def, tileset)

    local function valid(x, y)
      if not map:inBounds(x, y) or not map:isWalkableCell(x, y) then
        return false
      end
      if terrain == "grass" and not map:isGrassCell(x, y) then
        return false
      end
      return not blockedCell(map, x, y)
    end

    if preferred and valid(preferred.x, preferred.y) then
      return {
        map = mapId,
        x = preferred.x,
        y = preferred.y,
        facing = preferred.facing or "down",
        terrain = terrain,
      }
    end

    local candidates = {}
    for y = 1, map.heightCells - 2 do
      for x = 1, map.widthCells - 2 do
        if valid(x, y) then
          local distance = preferred
            and math.abs(x - preferred.x) + math.abs(y - preferred.y) or 0
          candidates[#candidates + 1] = { x = x, y = y, distance = distance }
        end
      end
    end
    table.sort(candidates, function(left, right)
      if left.distance ~= right.distance then
        return left.distance < right.distance
      end
      if left.y ~= right.y then return left.y < right.y end
      return left.x < right.x
    end)
    local cell = assert(candidates[1],
      ("no safe %s UAT cell on %s"):format(terrain or "walkable", mapId))
    return {
      map = mapId,
      x = cell.x,
      y = cell.y,
      facing = preferred and preferred.facing or "down",
      terrain = terrain,
    }
  end

  local pallet = safeCell(
    "PALLET_TOWN", "walkable",
    merge({ x = 10, y = 12, facing = "up" },
      signalsContent.PALLET_RETURN))
  local driftglass = safeCell(
    signalsContent.MAP_ID, "walkable",
    merge({ x = 8, y = 12, facing = "up" },
      signalsContent.ARRIVAL))
  local prismEntrance = safeCell(
    signalsContent.MAP_ID, "walkable",
    merge({ x = 11, y = 9, facing = "right" },
      signalsContent.PRISM_ENTRANCE
        and signalsContent.PRISM_ENTRANCE.approach))
  local cells = {
    pallet = pallet,
    driftglass = driftglass,
    prismEntrance = prismEntrance,
    route1 = safeCell("ROUTE_1", "grass"),
    route24 = safeCell("ROUTE_24", "grass"),
    viridianForest = safeCell("VIRIDIAN_FOREST", "walkable"),
    route6 = safeCell("ROUTE_6", "walkable"),
    seafoamB2F = safeCell("SEAFOAM_ISLANDS_B2F", "indoor",
      { x = 19, y = 7, facing = "down" }),
    mansionB1F = safeCell("POKEMON_MANSION_B1F", "indoor",
      { x = 23, y = 22, facing = "down" }),
    victoryRoad3F = safeCell("VICTORY_ROAD_3F", "indoor",
      { x = 23, y = 7, facing = "down" }),
    celadon = safeCell("CELADON_CITY", "walkable"),
  }

  local function starterForVersion()
    if version == "yellow" then return "PIKACHU" end
    if version == "blue" then return "SQUIRTLE" end
    return "BULBASAUR"
  end

  local function starterChoiceFlag(species)
    if species == "PIKACHU" then return "EVENT_CHOSE_PIKACHU" end
    if species == "SQUIRTLE" then return "EVENT_CHOSE_SQUIRTLE" end
    if species == "CHARMANDER" then return "EVENT_CHOSE_CHARMANDER" end
    return "EVENT_CHOSE_BULBASAUR"
  end

  local function makeMon(save, species, level)
    local mon = Pokemon.new(game.data, species, level, function() return 10 end)
    BattleState.stampOT(save, mon)
    mon.hp = mon.stats.hp
    return mon
  end

  local function applyBadges(save, count)
    count = math.max(0, math.min(#BADGES, math.floor(count or 0)))
    for index, badge in ipairs(BADGES) do
      if index <= count then
        save.inventory[badge.item] = 1
        save.flags[badge.flag] = true
      else
        save.inventory[badge.item] = nil
        save.flags[badge.flag] = nil
      end
    end
  end

  local function earlyState(fields)
    local out = {
      version = 1,
      mode = "KANTO_FIRST",
      modeChosen = false,
      receiverRepaired = false,
      questStarted = false,
      capsuleFound = false,
      capsuleAvailable = false,
      pokedexSteps = 0,
      palletVisits = 0,
      capsuleTarget = 128,
      waveIndex = 0,
      waveSteps = 0,
      strongSignal = false,
      traces = {
        forest = false,
        coast = false,
        ember = false,
        stone = false,
      },
      rarePity = {
        CHIKORITA = 0,
        TOTODILE = 0,
        CYNDAQUIL = 0,
        LARVITAR = 0,
      },
      onboardingComplete = false,
      startPolicy = "quest",
    }
    fields = fields or {}
    local traceChanges = fields.traces
    local pityChanges = fields.rarePity
    for key, value in pairs(fields) do
      if key ~= "traces" and key ~= "rarePity" then
        out[key] = copy(value)
      end
    end
    out.traces = merge(out.traces, traceChanges)
    out.rarePity = merge(out.rarePity, pityChanges)
    return out
  end

  local function repairedState(fields)
    return earlyState(merge({
      mode = "KANTO_FIRST",
      modeChosen = true,
      receiverRepaired = true,
      questStarted = true,
      capsuleFound = true,
      capsuleAvailable = true,
      pokedexSteps = 128,
      onboardingComplete = true,
      startPolicy = "quest",
    }, fields))
  end

  local function resonanceState(fields)
    local out = {
      version = 2,
      echoes = 0,
      echoRolls = 0,
      trueRolls = 0,
      sealed = false,
      completed = {},
      bound = nil,
    }
    for key, value in pairs(fields or {}) do out[key] = copy(value) end
    return out
  end

  local function setLocation(save, location)
    local def = assertAllowedMap(location.map)
    save.player.map = location.map
    save.player.x = location.x
    save.player.y = location.y
    save.player.facing = location.facing or "down"
    save.player.surfing = false
    save.lastHeal = {
      map = pallet.map,
      x = pallet.x,
      y = pallet.y,
    }
    if Map.isOutdoor(def) then
      save.lastOutdoor = {
        id = location.map,
        x = location.x,
        y = location.y,
      }
    else
      save.lastOutdoor = {
        id = pallet.map,
        x = pallet.x,
        y = pallet.y,
      }
    end
    save.visited = save.visited or {}
    save.visited[location.map] = true
    save.visited.PALLET_TOWN = true
  end

  local function baseSave(spec)
    local save = SaveData.newGame(game.data.field.boot)
    local starter = starterForVersion()
    save.version = version
    save.player = save.player or {}
    save.player.name = "SIGNAL"
    save.player.rival = "RIVAL"
    save.player.id = 6000
    save.flags = {
      EVENT_GOT_STARTER = true,
      EVENT_GOT_POKEDEX = true,
    }
    save.flags[starterChoiceFlag(starter)] = true
    if version == "yellow" then
      save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true
    end
    save.inventory = {
      POKE_BALL = 30,
      GREAT_BALL = 20,
      ULTRA_BALL = 20,
      MASTER_BALL = 1,
      FULL_RESTORE = 20,
      MAX_REPEL = 20,
      ESCAPE_ROPE = 10,
    }
    save.bagOrder = nil
    save.pcItems = { POTION = 1 }
    save.party = {
      makeMon(save, starter, 50),
      makeMon(save, "PARASECT", 45),
    }
    save.box = nil
    save.boxes = nil
    Boxes.ensure(save)
    save.money = 999999
    save.playTime = 60 * 60
    save.defeatedTrainers = {}
    save.objectToggles = {}
    save.pokedex = { seen = {}, owned = {} }
    for _, mon in ipairs(save.party) do
      save.pokedex.seen[mon.species] = true
      save.pokedex.owned[mon.species] = true
    end
    save.repelSteps = 0
    save.modData = {
      [MOD_ID] = {
        johto_signals = {
          version = 2,
          earlyJohto = earlyState(spec.early),
          resonance = resonanceState(spec.resonance),
          prismGrotto = copy(spec.prismGrotto or {}),
        },
      },
    }
    save.meta = SaveData.buildMeta({
      { id = MOD_ID, version = MOD_VERSION, api = 2 },
    })
    applyBadges(save, spec.badges or 0)
    if spec.receiver then
      assert(game.data.items.MIGRATION_RECEIVER,
        "MIGRATION_RECEIVER is missing from merged item data")
      save.inventory.MIGRATION_RECEIVER = 1
    end
    if spec.hallOfFame then
      save.hallOfFame = {
        {
          copy(save.party[1]),
          copy(save.party[2]),
        },
      }
    end
    setLocation(save, spec.location)
    Bag.order(save)
    return save
  end

  local function fillBag(save)
    local capacity = Bag.capacity(game.data)
    local ids = {}
    for id in pairs(game.data.items or {}) do
      if not Bag.isBadge(id)
          and id ~= "RESONANCE_SEAL"
          and id ~= "NO_ITEM" then
        ids[#ids + 1] = id
      end
    end
    table.sort(ids)
    for _, id in ipairs(ids) do
      if Bag.slots(save) >= capacity then break end
      if save.inventory[id] == nil then save.inventory[id] = 1 end
    end
    Bag.order(save)
    assert(Bag.slots(save) == capacity,
      ("could not build full BAG: %d/%d slots")
        :format(Bag.slots(save), capacity))
    assert(save.inventory.RESONANCE_SEAL == nil,
      "full-BAG checkpoint must not start with RESONANCE_SEAL")
  end

  local function addOwnedBoxMon(save, species, level)
    local mon = makeMon(save, species, level)
    assert(Boxes.deposit(save, mon), "all UAT boxes are unexpectedly full")
    save.pokedex.seen[species] = true
    save.pokedex.owned[species] = true
    return mon
  end

  local function validateGenerated(row)
    local probe = copy(row.save)
    local report = SaveData.validate(probe, game.data)
    assert(SaveData.emptyReport(report),
      ("generated checkpoint %s references invalid content"):format(row.id))
    local forbidden = mapIsForbidden(row.save.player and row.save.player.map)
    assert(not forbidden, "generated checkpoint uses a frozen map")
    assert(row.save.version == version, "generated save version mismatch")
    assert(row.save.modData and row.save.modData[MOD_ID]
        and row.save.modData[MOD_ID].johto_signals,
      "generated checkpoint is missing the production Signals save bucket")
  end

  local specs = {
    {
      id = "slot6001",
      label = "S01 PALLET 127 OF 128",
      location = cells.pallet,
      early = {
        capsuleTarget = 128,
        pokedexSteps = 127,
      },
      action = "Walk one step in Pallet; inspect, decline, then re-enter.",
    },
    {
      id = "slot6002",
      label = "S02 CAPSULE READY",
      location = cells.pallet,
      early = {
        capsuleTarget = 128,
        pokedexSteps = 128,
        capsuleAvailable = true,
      },
      action = "Accept the capsule and use Pallet's Driftglass boat.",
    },
    {
      id = "slot6003",
      label = "S03 DRIFTGLASS REPAIR",
      location = cells.driftglass,
      early = {
        capsuleTarget = 128,
        pokedexSteps = 128,
        capsuleAvailable = true,
        capsuleFound = true,
        questStarted = true,
      },
      action = "Save/restart at Pallet, sail back, repair, test both boats.",
    },
    {
      id = "slot6004",
      label = "S04 KANTO FIRST",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState(),
      action = "Fight native encounters; verify no Johto replacement.",
    },
    {
      id = "slot6005",
      label = "S05 WAVES NORMAL",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "WANDERWAVES",
        waveIndex = 2,
        waveSteps = 500,
        strongSignal = false,
      }),
      action = "Sample normal Wanderwaves and verify 2 percent.",
    },
    {
      id = "slot6006",
      label = "S06 WAVES STRONG",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "WANDERWAVES",
        waveIndex = 2,
        waveSteps = 500,
        strongSignal = true,
      }),
      action = "Sample strong Wanderwaves and verify 4 percent.",
    },
    {
      id = "slot6007",
      label = "S07 JOHTO UNLEASHED",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "UNLEASHED",
      }),
      action = "Sample several native habitats and verify 10 percent.",
    },
    {
      id = "slot6008",
      label = "S08 TRACE FOREST",
      location = cells.viridianForest,
      badges = 4,
      receiver = true,
      early = repairedState({ mode = "WANDERWAVES" }),
      action = "ASCENDANT / WORLD / JOHTO SIGNALS / SCAN CURRENT AREA.",
    },
    {
      id = "slot6009",
      label = "S09 TRACE COAST",
      location = cells.route6,
      badges = 4,
      receiver = true,
      early = repairedState({ mode = "WANDERWAVES" }),
      action = "Scan Route 6 and verify only the coast trace unlocks.",
    },
    {
      id = "slot6010",
      label = "S10 TRACE EMBER",
      location = cells.mansionB1F,
      badges = 4,
      receiver = true,
      early = repairedState({ mode = "UNLEASHED" }),
      action = "Scan Mansion B1F and verify only the ember trace unlocks.",
    },
    {
      id = "slot6011",
      label = "S11 TRACE STONE",
      location = cells.victoryRoad3F,
      badges = 8,
      receiver = true,
      early = repairedState({ mode = "UNLEASHED" }),
      action = "Scan Victory Road 3F and verify only the stone trace unlocks.",
    },
    {
      id = "slot6012",
      label = "S12 CHIKORITA PITY 511",
      location = cells.route24,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "WANDERWAVES",
        traces = { forest = true },
        rarePity = { CHIKORITA = 511 },
      }),
      action = "Start the 512th eligible Route 24 grass battle.",
    },
    {
      id = "slot6013",
      label = "S13 TOTODILE PITY 511",
      location = cells.seafoamB2F,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "WANDERWAVES",
        traces = { coast = true },
        rarePity = { TOTODILE = 511 },
      }),
      action = "Start the 512th eligible Seafoam B2F battle.",
    },
    {
      id = "slot6014",
      label = "S14 CYNDAQUIL PITY 255",
      location = cells.mansionB1F,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "UNLEASHED",
        traces = { ember = true },
        rarePity = { CYNDAQUIL = 255 },
      }),
      action = "Start the 256th eligible Mansion B1F battle.",
    },
    {
      id = "slot6015",
      label = "S15 LARVITAR PITY 255",
      location = cells.victoryRoad3F,
      badges = 8,
      receiver = true,
      early = repairedState({
        mode = "UNLEASHED",
        traces = { stone = true },
        rarePity = { LARVITAR = 255 },
      }),
      action = "Start the 256th eligible Victory Road 3F battle.",
    },
    {
      id = "slot6016",
      label = "S16 ECHO PITY 511",
      location = cells.route1,
      badges = 3,
      receiver = true,
      early = repairedState(),
      resonance = {
        echoes = 0,
        echoRolls = 511,
      },
      action = "Trigger echo; test 1 HP floor, status immunity, Master Ball rejection and RUN lock.",
    },
    {
      id = "slot6017",
      label = "S17 THREE ECHO THREE BADGE",
      location = cells.driftglass,
      badges = 3,
      receiver = true,
      early = repairedState(),
      resonance = {
        echoes = 3,
      },
      action = "Ask researcher for seal; verify fourth-badge refusal.",
    },
    {
      id = "slot6018",
      label = "S18 SEAL FULL BAG",
      location = cells.driftglass,
      badges = 4,
      receiver = true,
      early = repairedState(),
      resonance = {
        echoes = 3,
      },
      fullBag = true,
      action = "Ask researcher for seal; verify atomic key-item grant.",
    },
    {
      id = "slot6019",
      label = "S19 TRUE PITY 8191",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState(),
      resonance = {
        echoes = 3,
        sealed = true,
        trueRolls = 8191,
      },
      action = "Start next eligible native grass battle.",
    },
    {
      id = "slot6020",
      label = "S20 BOUND MEW RETRY 31",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState(),
      resonance = {
        echoes = 3,
        sealed = true,
        bound = {
          species = "MEW",
          level = 60,
          retryRolls = 31,
          dvs = {
            attack = 10,
            defense = 10,
            speed = 10,
            special = 10,
            hp = 0,
          },
          hp = 17,
          status = "PAR",
        },
      },
      action = "Trigger guaranteed bound Mew; verify preserved HP/status.",
    },
    {
      id = "slot6021",
      label = "S21 BOUND CELEBI RETRY 31",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState(),
      resonance = {
        echoes = 3,
        sealed = true,
        bound = {
          species = "CELEBI",
          level = 60,
          retryRolls = 31,
          dvs = {
            attack = 11,
            defense = 11,
            speed = 11,
            special = 11,
            hp = 15,
          },
          hp = 23,
          status = "SLP",
        },
      },
      action = "Trigger guaranteed bound Celebi; verify preserved HP/status.",
    },
    {
      id = "slot6022",
      label = "S22 MOD OFF ON",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "WANDERWAVES",
        traces = { forest = true },
        rarePity = { CHIKORITA = 211 },
      }),
      resonance = {
        echoes = 2,
        echoRolls = 777,
      },
      ownedBoxSpecies = "CHIKORITA",
      action = "Save; disable mod; load/save; re-enable; verify restoration.",
    },
    {
      id = "slot6023",
      label = "S23 LIND EARLY OWNED",
      location = cells.celadon,
      badges = 8,
      receiver = true,
      hallOfFame = true,
      early = repairedState({
        mode = "WANDERWAVES",
        traces = { forest = true },
      }),
      ownedBoxSpecies = "CHIKORITA",
      lind = true,
      action = "Complete Verdant starter trial; verify no duplicate gift.",
    },
    {
      id = "slot6024",
      label = "S24 DRIFTGLASS MOD OFF",
      location = cells.driftglass,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "WANDERWAVES",
        traces = { forest = true },
        rarePity = { CHIKORITA = 212 },
      }),
      resonance = {
        echoes = 2,
        echoRolls = 778,
      },
      ownedBoxSpecies = "CHIKORITA",
      action = "Save here; disable mod; load/save; re-enable at Pallet.",
    },
    {
      id = "slot6025",
      label = "S25 PRISM GROTTO",
      location = cells.prismEntrance,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "UNLEASHED",
      }),
      prismGrotto = {
        version = 1,
        introduced = false,
        heard = {},
        solved = {},
        pendingRewards = {},
      },
      resonanceParty = {
        { species = "GENGAR", level = 50 },
        { species = "GROWLITHE", level = 33 },
      },
      fullMoveParty = {
        index = 2,
        moves = { "CUT", "STUN_SPORE", "LEECH_LIFE", "SPORE" },
      },
      inventory = { RARE_CANDY = 5 },
      action = "Test six inscriptions, level gates and Route 5 move-slot handoff.",
    },
    {
      id = "slot6026",
      label = "S26 REMEMBER YES",
      location = cells.pallet,
      early = {
        onboardingComplete = false,
        startPolicy = "quest",
      },
      action = "Accept direct Johto start; quit fully; reload this slot.",
    },
    {
      id = "slot6027",
      label = "S27 REMEMBER NO",
      location = cells.pallet,
      early = {
        onboardingComplete = false,
        startPolicy = "quest",
      },
      action = "Decline direct Johto start; quit fully; reload this slot.",
    },
    {
      id = "slot6028",
      label = "S28 JOHTO DEX AUDIO",
      location = cells.route1,
      badges = 4,
      receiver = true,
      early = repairedState({
        mode = "UNLEASHED",
      }),
      allJohtoDex = true,
      audioParty = {
        "CHIKORITA",
        "TOTODILE",
        "NATU",
        "CELEBI",
      },
      action = "Browse #152-251; verify authentic sprites, data and distinct cries.",
    },
  }

  local rows = {}
  local manifestRows = {}
  for _, spec in ipairs(specs) do
    local save = baseSave(spec)
    for itemId, count in pairs(spec.inventory or {}) do
      assert(game.data.items[itemId],
        "UAT inventory references missing item " .. itemId)
      save.inventory[itemId] = count
    end
    if spec.fullBag then fillBag(save) end
    if spec.ownedBoxSpecies then
      addOwnedBoxMon(save, spec.ownedBoxSpecies, 18)
    end
    if spec.allJohtoDex then
      for _, species in ipairs(exports.johtoData.order) do
        save.pokedex.seen[species] = true
        save.pokedex.owned[species] = true
      end
    end
    if spec.audioParty then
      for _, species in ipairs(spec.audioParty) do
        assert(#save.party < 6, "Johto audio UAT party exceeds six Pokémon")
        local mon = makeMon(save, species, 30)
        save.party[#save.party + 1] = mon
        save.pokedex.seen[species] = true
        save.pokedex.owned[species] = true
      end
    end
    if spec.resonanceParty then
      for _, row in ipairs(spec.resonanceParty) do
        assert(#save.party < 6,
          "Prism resonance UAT party exceeds six Pokémon")
        local mon = makeMon(save, row.species, row.level)
        save.party[#save.party + 1] = mon
        save.pokedex.seen[row.species] = true
        save.pokedex.owned[row.species] = true
      end
    end
    if spec.fullMoveParty then
      local row = spec.fullMoveParty
      local mon = assert(save.party[row.index],
        "Prism full-moveset UAT party index is missing")
      mon.moves = {}
      for _, moveId in ipairs(row.moves) do
        local move = assert(game.data.moves[moveId],
          "Prism full-moveset UAT references missing move " .. moveId)
        mon.moves[#mon.moves + 1] = { id = moveId, pp = move.pp or 0 }
      end
      assert(#mon.moves == 4,
        "Prism full-moveset UAT must seed exactly four moves")
    end
    if spec.lind then
      save.modData[MOD_ID].johto_research = {
        version = 2,
        starters = {},
        rewards = {},
        trackWins = {},
        eggsQueued = {},
        eggsHatched = {},
        itemsClaimed = {},
        eggQueue = {},
        pendingMons = {},
        pendingItems = {},
        compensations = {},
      }
    end
    Bag.order(save)
    local row = {
      id = spec.id,
      label = spec.label,
      save = save,
      action = spec.action,
      kind = "generated",
    }
    validateGenerated(row)
    rows[#rows + 1] = row
  end

  local sourceEnv = "KA_SIGNALS_UPGRADE_" .. version:upper() .. "_SAVE"
  local sourcesEnv = sourceEnv .. "S"
  local sourcePaths = {}
  local seenPaths = {}
  local function addSource(path)
    if path and path ~= "" and not seenPaths[path] then
      seenPaths[path] = true
      sourcePaths[#sourcePaths + 1] = path
    end
  end
  addSource(os.getenv(sourceEnv))
  for _, path in ipairs(splitPaths(os.getenv(sourcesEnv))) do addSource(path) end

  local function readUpgrade(path, index)
    assert(path:sub(1, 1) == "/",
      "upgrade source path must be absolute: " .. path)
    local handle = assert(io.open(path, "rb"),
      "cannot read upgrade source: " .. path)
    local body = handle:read("*a")
    handle:close()
    local save = assert(SaveData.decode(body),
      "upgrade source is not a native decoded save: " .. path)
    local sourceVersion = save.version or "red"
    assert(sourceVersion == version,
      ("upgrade source %s belongs to %s, builder is %s")
        :format(path, sourceVersion, version))
    local mapId = save.player and save.player.map
    assert(type(mapId) == "string" and game.data.maps[mapId],
      "upgrade source has no currently valid start map: " .. tostring(mapId))
    local forbidden, word = mapIsForbidden(mapId)
    assert(not forbidden,
      ("upgrade source starts on frozen %s map %s; move it in 5.3 first")
        :format(tostring(word), tostring(mapId)))
    local storedVersion = "UNKNOWN"
    for _, modRow in ipairs(save.meta and save.meta.mods or {}) do
      if modRow.id == MOD_ID then
        storedVersion = tostring(modRow.version or "UNKNOWN")
        break
      end
    end
    local id = ("slot%d"):format(6089 + index)
    local label = ("S%02d UPGRADE %s"):format(89 + index, storedVersion)
    return {
      id = id,
      label = label,
      save = save,
      action = "Load/save/restart, then disable and re-enable the mod.",
      kind = "upgrade-copy",
      source = path,
      sourceBytes = #body,
      storedModVersion = storedVersion,
    }
  end

  for index, path in ipairs(sourcePaths) do
    assert(index <= 10, "at most ten exact upgrade sources are supported")
    rows[#rows + 1] = readUpgrade(path, index)
  end

  for _, row in ipairs(rows) do
    assert(SaveData.setActiveSlot(version, row.id) == row.id)
    local ok, err = SaveData.writeSlot(version, row.id, row.save)
    assert(ok, ("failed writing %s: %s"):format(row.id, tostring(err)))
    local renamed, renameErr = SaveData.renameSlot(
      version, row.id, row.label)
    assert(renamed,
      ("failed naming %s: %s"):format(row.id, tostring(renameErr)))

    local path = assert(SaveData.slotDiskPath(version, row.id))
    local handle = assert(io.open(path, "rb"))
    local decoded = assert(SaveData.decode(handle:read("*a")))
    handle:close()
    assert((decoded.version or "red") == version,
      "round-trip save version mismatch for " .. row.id)
    assert(decoded.player and decoded.player.map,
      "round-trip save has no player location for " .. row.id)

    manifestRows[#manifestRows + 1] = {
      id = row.id,
      label = row.label,
      kind = row.kind,
      map = decoded.player.map,
      x = decoded.player.x,
      y = decoded.player.y,
      action = row.action,
      source = row.source,
      sourceBytes = row.sourceBytes,
      storedModVersion = row.storedModVersion,
    }
  end

  local activeSlot = os.getenv("KA_SIGNALS_UAT_ACTIVE_SLOT")
    or "slot6001"
  local validActive = false
  for _, row in ipairs(rows) do
    if row.id == activeSlot then validActive = true break end
  end
  assert(validActive, "unknown KA_SIGNALS_UAT_ACTIVE_SLOT: " .. activeSlot)
  assert(SaveData.setActiveSlot(version, activeSlot) == activeSlot)

  local options = SaveData.loadOptions()
  options.mods = options.mods or {}
  options.mods[MOD_ID] = true
  options.modOptions = options.modOptions or {}
  options.modOptions[MOD_ID] = options.modOptions[MOD_ID] or {}
  options.modOptions[MOD_ID].language = "en"
  options.modOptions[MOD_ID].johto_signals_enable = true
  -- The two onboarding persistence checkpoints deliberately need the direct
  -- start question. Every other generated row is already marked complete and
  -- therefore remains unaffected by this global option.
  options.modOptions[MOD_ID].johto_signals_start = "waves"
  options.modOptions[MOD_ID].dex_sprite_style = "crystal"
  options.modOptions[MOD_ID].crystal_animation = true
  options.modOptions[MOD_ID].mythic_signals = true
  assert(SaveData.saveOptions(options), "failed saving isolated UAT options")

  local manifest = {
    schema = MANIFEST_SCHEMA,
    identity = IDENTITY,
    gameVersion = version,
    mod = {
      id = MOD_ID,
      version = MOD_VERSION,
    },
    language = {
      storage = "global option, not per-save",
      initial = "en",
      required = { "en", "de" },
    },
    upgrade = {
      seeded = #sourcePaths,
      singularEnv = sourceEnv,
      listEnv = sourcesEnv,
    },
    cells = cells,
    rows = manifestRows,
  }
  assert(love.filesystem.createDirectory("uat"))
  local manifestPath = "uat/johto_signals_" .. version .. "_manifest.lua"
  local written, manifestErr = love.filesystem.write(
    manifestPath, SaveData.encode(manifest))
  assert(written,
    "failed writing UAT manifest: " .. tostring(manifestErr))

  U.log(("PASS built %d %s Signals UAT slots in %s")
    :format(#rows, version, love.filesystem.getSaveDirectory()))
  U.log("Manifest:", love.filesystem.getSaveDirectory() .. "/" .. manifestPath)
  if #sourcePaths == 0 then
    U.log("NOTE: no original upgrade source save was seeded;",
      sourceEnv, "and", sourcesEnv, "were unset")
  end
  love.event.quit(0)
end
