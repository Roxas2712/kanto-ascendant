-- Regression for the Wilds/DRAMALESS spawn lifecycle. A body deliberately
-- hidden by SpawnFx must be deferred without an emergency warning; once the
-- body becomes visible on the next update it must register normally. A real
-- missing sprite remains a loud failure.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local runtime = root .. "/vendor/wilds_1_12_2"
local modules = {}
local warnings = {}

local config = {
  debug = function() return false end,
  waterDisplayMode = function() return "swimming_sprites" end,
}
local diagnostics = {
  ensure = function(entity)
    entity.renderDiagnostics = entity.renderDiagnostics or {}
    return entity.renderDiagnostics
  end,
  honestDepthActive = function() return false end,
  strictEnabled = function() return false end,
  statusLines = function() return {} end,
}
local movement = {
  syncLegacyFields = function() end,
  walkPhase = function() return 0 end,
}
local waterDisplay = {
  needsWaterShadowPresentation = function() return false end,
  isSilhouettes = function() return false end,
  isHiddenSilhouettes = function() return false end,
}
local waterShadow = {
  MODE = { NONE="none", FLAT_WORLD="flat_world", UPRIGHT_FALLBACK="upright_fallback" },
  installDrawHook = function() end,
}

local V = {}
local mod = {
  id = "overworld_wild_spawns",
  log = {
    info = function() end,
    warn = function(_, fmt, ...)
      warnings[#warnings + 1] = select("#", ...) > 0
        and string.format(fmt, ...) or tostring(fmt)
    end,
    error = function(_, fmt, ...) error(string.format(fmt, ...), 0) end,
  },
  find = function() return nil end,
}
V.mod = mod
function V.require(name)
  if name == "config" then return config end
  if name == "tile" then return { CELL=16 } end
  if name == "render_diagnostics" then return diagnostics end
  if name == "movement" then return movement end
  if name == "water_display" then return waterDisplay end
  if name == "water_shadow_renderer" then return waterShadow end
  if modules[name] ~= nil then return modules[name] end
  local value = assert(loadfile(runtime .. "/lib/" .. name .. ".lua"))(V)
  modules[name] = value
  return value
end

local VoxelAdapter = V.require("voxel_adapter")
local SpawnFx = V.require("spawn_fx")
local adapter = VoxelAdapter.new(mod)
adapter.isVoxelCameraActive = function() return true end

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local sprite = {
  def = { image="fixture.png", frames=6, walker=true },
  resolveImage = function() return true end,
}
local poseCalls = 0
local worldSpriteCalls = 0
local entity = {
  id = "spawn_fx_wild", overworldWildSpawn = true,
  hiddenEncounter = false, visibleSprite = true,
  sprite = sprite, nativeSpriteRenderer = true,
  px = 32, py = 48, cellX = 2, cellY = 3, facing = "down",
  render = {
    bindWorldBillboard = function(_, target)
      target.pokemonRenderer = VoxelAdapter.POKEMON_NATIVE
      target.worldBillboardReady = true
      target.worldSpriteAdapterStatus = "NATIVE"
    end,
  },
}
function entity:getWorldSprite()
  worldSpriteCalls = worldSpriteCalls + 1
  if not SpawnFx.bodyVisible(self) then return nil end
  return self.sprite
end
function entity:pose()
  poseCalls = poseCalls + 1
  if not SpawnFx.bodyVisible(self) then
    return nil, self.px, self.py, self.facing, 0, false
  end
  return self:getWorldSprite(), self.px, self.py, self.facing, 0, false
end

SpawnFx.begin(entity, SpawnFx.KIND.GRASS)
check(entity.hiddenBody == true and entity.spawnFx.bodyShown == false,
  "fixture did not enter the real SpawnFx hidden-body phase")

local safe, reason, disposition = VoxelAdapter.isPoseSafe(entity)
check(not safe and disposition == "deferred",
  "spawn-FX-hidden body was not classified as deferred")
check(reason == "body hidden by active spawn FX",
  "deferred reason does not identify the spawn lifecycle")
check(worldSpriteCalls == 1 and poseCalls == 0,
  "isPoseSafe fell through to entity.sprite or called pose while hidden")

local updated = adapter:updateEntity(entity)
check(updated == false and entity.voxelDeferred == true,
  "hidden spawn body was not held in a deferred adapter state")
check(#warnings == 0, "transient hidden body emitted an emergency warning")
check(entity.voxelDisabled ~= true and entity.render2DFallback ~= true,
  "transient hidden body was incorrectly disabled/fallback-rendered")
check(entity.pokemonRenderer == VoxelAdapter.POKEMON_DEFERRED
    and entity.worldSpriteAdapterStatus == "DEFERRED",
  "transient hidden body was not excluded from the billboard pass")
check(poseCalls == 0, "adapter probed pose during the hidden spawn frame")

-- SpawnFx exposes the body after its presentation phase. The next ordinary
-- behavior tick calls updateEntity again and must promote the same entity.
check(SpawnFx.updateEntity(entity, 0.11, {}) == "spawn_visible",
  "real SpawnFx did not expose the body on schedule")
updated = adapter:updateEntity(entity)
check(updated == true, "visible next tick did not register normally")
check(entity.voxelRegistered == true and entity.voxelDeferred ~= true,
  "visible body retained its deferred registration state")
check(entity.pokemonRenderer == VoxelAdapter.POKEMON_NATIVE
    and entity.worldBillboardReady == true,
  "visible body did not regain the native world billboard")
check(entity.voxelDisabled == false and entity.render2DFallback == false,
  "visible body retained emergency flags")
check(#warnings == 0, "successful promotion emitted a warning")

local missing = {
  id = "genuinely_missing_wild", overworldWildSpawn = true,
  hiddenEncounter = false, visibleSprite = true, hiddenBody = false,
  nativeSpriteRenderer = true,
  px = 64, py = 80, cellX = 4, cellY = 5, facing = "left",
  getWorldSprite = function() return nil end,
  pose = function(self) return nil, self.px, self.py, self.facing, 0, false end,
  render = entity.render,
}
updated = adapter:updateEntity(missing)
check(updated == false, "genuinely missing sprite was accepted")
check(#warnings == 1 and warnings[1]:find("spatial overlay emergency",1,true),
  "genuinely missing sprite did not fail loudly")
check(missing.voxelDisabled == true and missing.render2DFallback == true,
  "genuinely missing sprite did not enter the emergency path")
check(missing.pokemonRenderer == VoxelAdapter.POKEMON_OVERLAY_EMERGENCY
    and missing.worldSpriteAdapterStatus == "EMERGENCY",
  "genuinely missing sprite lost the explicit emergency status")

print(("wilds_voxel_spawn_fx_deferred_test: PASS (%d assertions)"):format(assertions))
