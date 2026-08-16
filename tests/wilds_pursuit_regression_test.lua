-- Focused regression for visible-Wilds pursuit and world lifecycle.
-- Uses the bundled 1.12.2 runtime modules, not copied stand-ins.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local runtime = root .. "/vendor/wilds_1_12_2"
local modules = {}
local V = { path = runtime }

local optionValues = {
  enabled = true,
  random_encounters = false,
  wilds_ai = true,
  enable_aggressive = true,
}
local overworld
local mod = {
  id = "overworld_wild_spawns",
  path = runtime,
  options = { get = function(_, key) return optionValues[key] end },
  log = {
    info = function() end, warn = function() end,
    error = function(_, message) error(message, 0) end,
  },
  find = function() return nil end,
  world = {
    game = { data = {}, save = {} },
    overworld = function() return overworld end,
  },
  assets = { path = function(_, path) return runtime .. "/" .. path end },
}
V.mod = mod
function V.require(name)
  if modules[name] ~= nil then return modules[name] end
  local chunk = assert(loadfile(runtime .. "/lib/" .. name .. ".lua"))
  local value = chunk(V)
  modules[name] = value
  return value
end

local Behavior = V.require("behavior")
local Movement = V.require("movement")
local Occupancy = V.require("cell_occupancy")
local Surface = V.require("surface")
local Config = V.require("config")
local SpawnLogic = V.require("spawn_logic")

local function check(value, message)
  if not value then error("FAIL: " .. message, 2) end
end

local map = {
  id = "PURSUIT_FIELD", widthCells = 9, heightCells = 7,
  inBounds = function(self, x, y)
    return x >= 0 and y >= 0 and x < self.widthCells and y < self.heightCells
  end,
  isWalkableCell = function(self, x, y) return self:inBounds(x, y) end,
  isGrassCell = function(self, x, y) return self:inBounds(x, y) end,
  isWaterCell = function() return false end,
  warpAtCell = function() return nil end,
}
local player = { player = true, cellX = 6, cellY = 3, facing = "left" }
local follower = {
  id = "ascendant_follower_2", cellX = 3, cellY = 3,
  passable = true, _ascendantNativeFollower = true, _ascendantChainIndex = 2,
}
local wild = {
  id = "pursuit_wild", cellX = 2, cellY = 3,
  overworldWildSpawn = true, registeredInWorld = true,
  visibleSprite = true, surface = Surface.GRASS, mod = mod,
}

-- Baseline land weights must actually contain an occasional aggressive roll.
local picked = Behavior.pick("GROWLITHE", Surface.GRASS, {
  enable_idle = true, enable_wander = true,
  enable_aggressive = true, enable_hidden = true,
}, function(arg) return arg and 1 or 0.70 end)
check(picked == Behavior.AGGRESSIVE,
  "the ordinary land picker no longer yields occasional aggressive spawns")

-- Ascendant chain extras are passable to the player, but still obstacles for
-- Wilds path reservations. This is the exact cross-system collision contract.
check(Occupancy.isFollowerEntity(follower),
  "Ascendant follower-chain entity was not recognized as a follower")

Behavior.attach(wild, Behavior.AGGRESSIVE, nil, function(arg)
  return arg and 1 or 0.5
end)
Movement.setFacing(wild, "right")
local occupancy = Occupancy.new()
local entities = { player, follower, wild }
occupancy:rebuild({ player = player, entities = entities, logicEntities = { wild } })
local ctx = {
  map = map, entities = entities, player = player, occupancy = occupancy,
  dt = 0.20, sightRange = 6, waterMonsEnabled = false,
  rng = function(arg) return arg and 1 or 0.5 end,
}

check(Behavior.tick(wild, ctx) == "alert",
  "aggressive visible wild did not detect the aligned player")
occupancy:cancelMove(wild)
wild.movementReservationCancelled = nil
Behavior.markChaseReady(wild)
Behavior.tick(wild, ctx)
check(wild.behaviorState.chasing
    and wild.behaviorState.state == Behavior.STATE.CHASING,
  "alert completion did not enter chase")
check(Movement.isBusy(wild),
  "pursuit failed to plan a route around a follower")
check(not (wild.targetX == follower.cellX and wild.targetY == follower.cellY),
  "pursuit reserved the follower's occupied cell")

local contacted = false
for _ = 1, 40 do
  local event = Behavior.tick(wild, ctx)
  if wild.movementReservationCancelled then
    occupancy:cancelMove(wild)
    wild.movementReservationCancelled = nil
  end
  local overlap = wild.cellX == follower.cellX and wild.cellY == follower.cellY
  check(not overlap, "pursuing wild overlapped the follower")
  if event == "contact" or event == "battle_pending" then
    contacted = true
    break
  end
end
check(contacted, "pursuit did not reach battle contact after routing around follower")
check(math.abs(wild.cellX - player.cellX) + math.abs(wild.cellY - player.cellY) == 1,
  "battle contact was not an adjacent, collision-safe cell")

-- A permanently sealed corridor must deaggro instead of remaining in an
-- immortal chase state behind a passable follower/NPC blocker.
local sealedMap = {
  id = "SEALED_CORRIDOR", widthCells = 9, heightCells = 7,
  inBounds = map.inBounds,
  isWalkableCell = function(self, x, y)
    return self:inBounds(x, y) and y == 3
  end,
  isGrassCell = function(self, x, y) return self:isWalkableCell(x, y) end,
  isWaterCell = function() return false end,
  warpAtCell = function() return nil end,
}
local sealed = {
  id = "sealed_wild", cellX = 2, cellY = 3,
  overworldWildSpawn = true, registeredInWorld = true,
  visibleSprite = true, surface = Surface.GRASS, mod = mod,
}
Behavior.attach(sealed, Behavior.AGGRESSIVE, nil, function(arg)
  return arg and 1 or 0.5
end)
Movement.setFacing(sealed, "right")
local sealedOcc = Occupancy.new()
local sealedEntities = { player, follower, sealed }
sealedOcc:rebuild({ player = player, entities = sealedEntities,
  logicEntities = { sealed } })
local sealedCtx = {
  map = sealedMap, entities = sealedEntities, player = player,
  occupancy = sealedOcc, dt = 0.02, sightRange = 6,
  waterMonsEnabled = false, rng = ctx.rng,
}
check(Behavior.tick(sealed, sealedCtx) == "alert", "sealed wild missed player")
sealedOcc:cancelMove(sealed)
sealed.movementReservationCancelled = nil
Behavior.markChaseReady(sealed)
Behavior.tick(sealed, sealedCtx)
for _ = 1, 140 do
  Behavior.tick(sealed, sealedCtx)
  if sealed.movementReservationCancelled then
    sealedOcc:cancelMove(sealed)
    sealed.movementReservationCancelled = nil
  end
  if not sealed.behaviorState.chasing
      and sealed.behaviorState.state == Behavior.STATE.IDLE then break end
end
check(not sealed.behaviorState.chasing
    and sealed.behaviorState.state == Behavior.STATE.IDLE,
  "permanently blocked wild never deaggroed")

-- Actual SpawnLogic lifecycle: map exit removes entities/emotes/reservations;
-- map reload and save reload re-enter only the current map without stale state.
overworld = { map = map, player = player, entities = {}, npcs = {} }
local render = { isEntityRegistered = function(_, ow, wanted)
  for _, value in ipairs(ow and ow.entities or {}) do
    if value == wanted then return true end
  end
  return false
end }
local logic = SpawnLogic.new(mod, render)
optionValues.enabled = false
check(not logic:shouldSuppressClassicEncounter({ mapId = map.id }),
  "disabling visible Wilds also disabled the classic encounter fallback")
optionValues.enabled = true
check(not logic:shouldSuppressClassicEncounter({ mapId = map.id }),
  "an uninitialized visible pipeline suppressed the classic fallback")
logic.state.mapId = map.id
logic.state.initialized = true
logic.state.pipelineVerified = true
logic.state.fallbackToVanilla = false
check(logic:shouldSuppressClassicEncounter({ mapId = map.id }),
  "active visible Wilds ignored RANDOM ENCOUNTERS OFF")
logic:_restoreVanillaEncounters("focused failure")
check(not logic:shouldSuppressClassicEncounter({ mapId = map.id }),
  "a failed visible pipeline left the authored cave completely empty")
logic.state.mapId = map.id
logic.state.initialized = true
logic.state.pipelineVerified = true
logic.state.fallbackToVanilla = false
optionValues.random_encounters = true
check(not logic:shouldSuppressClassicEncounter({ mapId = map.id }),
  "RANDOM ENCOUNTERS ON remained suppressed")
optionValues.random_encounters = false
local stale = {
  id = "stale_wild", cellX = 4, cellY = 4,
  overworldWildSpawn = true, registeredInWorld = true,
  behaviorState = Behavior.initState(Behavior.AGGRESSIVE),
}
overworld.entities[1] = stale
overworld.emote = { npc = stale, frames = 60 }
logic.activeMapId = map.id
logic.spawns[stale.id] = {
  id = stale.id, mapId = map.id, x = 4, y = 4,
  state = Config.STATE.AVAILABLE, behavior = Behavior.AGGRESSIVE,
}
logic.entities[stale.id] = stale
logic.byMap[map.id] = { stale.id }
logic:rebuildOccupancy(overworld)
logic:onMapExited({ mapId = map.id })
check(logic.entities[stale.id] == nil and logic.spawns[stale.id] == nil,
  "map exit retained a stale visible wild")
check(#overworld.entities == 0 and overworld.emote == nil,
  "map exit retained a wild body or owned alert emote")
local counts = logic.occupancy:counts()
check(counts.occupied == 0 and counts.moveReservations == 0
    and counts.spawnReservations == 0,
  "map exit retained occupancy reservations")

local entered = {}
logic.initializeForMap = function(self, mapId)
  entered[#entered + 1] = mapId
  self.state.initialized = true
  return true
end
logic:onMapEntered({ mapId = map.id, map = map })
logic:onMapReloaded({ mapId = map.id })
logic:onSaveLoaded()
check(#entered == 3 and entered[1] == map.id and entered[2] == map.id
    and entered[3] == map.id,
  "map/reload/save lifecycle did not re-enter exactly the active map")

print("PASS Wilds pursuit: weighted aggro path deaggro collision warp reload save")
