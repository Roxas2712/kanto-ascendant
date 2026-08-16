-- Reviewed DRAMALESS 1.6.2-ST.190.1 has no lib/WallDecals.lua. Kanto Ascendant's
-- package adapter must bind route fissures to the live depth scene without
-- editing that dependency, while yielding to a future native implementation.

package.path = "./?.lua;./?/init.lua;" .. package.path

local S = require("tests.harness").suite("DRAMALESS wall decal compatibility")
local eq, ok = S.eq, S.check
local modDir = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local registeredInvalidator
local image = { getDimensions = function() return 16, 16 end }
package.loaded["src.render.Assets"] = nil
package.preload["src.render.Assets"] = function()
  return {
    image = function(path)
      eq(path, "gfx/hidden_evolution/sealed_fissure.png",
        "adapter loads only the authored fissure art")
      return image
    end,
    register = function(callback) registeredInvalidator = callback end,
  }
end

local events, draws, sceneEvents = {}, {}, {}
local meshBuilds = 0
local Voxel3D = {
  FACE_SHADE = { 0.9, 0.8, 0.7, 0.6, 0.5, 0.4 },
  pushQuad = function(indices, start)
    eq(start, 0, "wall quad uses its four authored vertices")
    indices[1], indices[2], indices[3] = 1, 2, 3
    indices[4], indices[5], indices[6] = 1, 3, 4
  end,
  newMesh = function(vertices, indices)
    meshBuilds = meshBuilds + 1
    eq(#vertices, 4, "one wall decal builds one quad")
    eq(#indices, 6, "one wall decal builds two triangles")
    return { vertices = vertices }
  end,
  draw = function(mesh, texture, model)
    draws[#draws + 1] = { mesh=mesh, texture=texture, model=model }
    events[#events + 1] = "draw"
  end,
  glass = function(value) sceneEvents[#sceneEvents+1] = "glass:"..tostring(value) end,
  seams = function(value) sceneEvents[#sceneEvents+1] = "seams:"..tostring(value) end,
}
Voxel3D.endScene = function()
  events[#events + 1] = "end"
  return "canvas"
end
local VoxelScene = {}
VoxelScene.render = function(state)
  eq(state.map.id, "ROUTE_24", "adapter wraps the live render state")
  return Voxel3D.endScene()
end
local Mat4 = {
  translate = function(x, y, z) return { x=x, y=y, z=z } end,
}
local lib = { require = function(name)
  if name == "VoxelScene" then return VoxelScene end
  if name == "Voxel3D" then return Voxel3D end
  if name == "Mat4" then return Mat4 end
  return nil
end }
local handles = {}
local owner = {
  exports = {},
  find = function(id) return handles[id] end,
}
local resolver = dofile(modDir .. "/voxel_renderer_compat.lua")(owner)
handles.DRAMALESS_SHAPE = {
  id = "DRAMALESS_SHAPE", version = "1.6.2-ST.190.1",
  exports = { version = "1.6.2-ST.190.1", lib = lib },
}
local compat = dofile(modDir .. "/dramaless_wall_decals_compat.lua")(
  owner, { voxelRenderer = resolver })
ok(compat.install({}), "reviewed .186 adapter installs")
eq(compat.mode, "adapter", "missing native module selects package adapter")
ok(compat.installed, "adapter publishes its installed receipt")
ok(type(registeredInvalidator) == "function",
  "adapter participates in the engine asset invalidation boundary")

local state = {
  map = {
    id="ROUTE_24",
    def={ wallDecals={{
      id="KA_HEVO_WALL_FISSURE_BLUE", cellX=10, cellY=3,
      face="south", image="gfx/hidden_evolution/sealed_fissure.png",
      offsetX=2, elevation=6, faceOffsetY=1,
    }} },
  },
  neighbors = {{
    ox=320, oy=160,
    map={ def={ wallDecals={{
      id="KA_HEVO_WALL_FISSURE_GREEN", cellX=1, cellY=2,
      face="east", image="gfx/hidden_evolution/sealed_fissure.png",
      offsetX=3,
    }} } },
  }},
}
eq(VoxelScene.render(state), "canvas", "wrapped render returns original canvas")
eq(#draws, 2, "live map and connected neighbor decals both render")
eq(events[1], "draw", "wall decal draws before the scene closes")
eq(events[2], "draw", "neighbor wall decal also draws before close")
eq(events[3], "end", "original endScene remains the final operation")
eq(draws[1].model.x, 10*16+2, "BLUE decal stays on its exact wall X")
eq(draws[1].model.y, 5, "screen-down face offset maps to voxel-up Y")
eq(draws[1].model.z, 3*16, "BLUE decal stays on its exact wall Z")
eq(draws[2].model.x, 320+16,
  "connected-map wall decal includes its world X offset")
eq(draws[2].model.z, 160+2*16+3,
  "east wall uses authored along-face offset on world Z")
eq(sceneEvents[1], "glass:false", "decal art bypasses terrain glass mask")
eq(sceneEvents[2], "seams:false", "decal art has no voxel wireframe")
eq(sceneEvents[#sceneEvents-1], "seams:true", "wireframe state is restored")
eq(sceneEvents[#sceneEvents], "glass:true", "glass state is restored")
eq(compat.lastError, nil, "live adapter render has no swallowed failure")
eq(compat.drawCount, 2, "adapter exposes both real depth-scene decal draws")
eq(compat.lastDrawn.id, "KA_HEVO_WALL_FISSURE_GREEN",
  "adapter receipt identifies the last connected wall decal")

draws, events = {}, {}
eq(VoxelScene.render(state), "canvas", "adapter remains stable next frame")
eq(meshBuilds, 2, "mesh cache avoids rebuilding either wall next frame")
registeredInvalidator()
VoxelScene.render(state)
eq(meshBuilds, 4, "asset invalidation rebuilds cached decal meshes")
eq(compat.drawCount, 6, "draw receipt remains monotonic across live frames")

local nativeDraw = function() end
local nativeScene = { render=function() return "native-scene" end }
local nativeVoxel = { endScene=function() return "native-end" end }
local nativeLib = { require=function(name)
  if name == "WallDecals" then return { draw=nativeDraw } end
  if name == "VoxelScene" then return nativeScene end
  if name == "Voxel3D" then return nativeVoxel end
  if name == "Mat4" then return Mat4 end
  return nil
end }
handles = { VOXEL_ASCENDANT = {
  id = "VOXEL_ASCENDANT", version = "0.1.1",
  exports = {
    version = "0.1.1", apiVersion = 1,
    renderer = {
      id = "VOXEL_ASCENDANT", version = "0.1.1",
      pipeline = "voxel", cameraProfile = "orbit-only",
    },
    capabilities = {
      voxelWorld = true, battleCards = { "MAP", "DISCS" },
      wallDecals = 1, diskCache = false, stadium = false, vr = false,
    },
    lib = nativeLib,
  },
} }
local nativeCompat = dofile(modDir .. "/dramaless_wall_decals_compat.lua")(
  owner, { voxelRenderer = resolver })
ok(nativeCompat.install({}),
  "future native renderer remains compatible")
eq(nativeCompat.mode, "native", "native wall implementation always wins")
eq(nativeScene.render(), "native-scene", "native scene is not wrapped")
eq(nativeVoxel.endScene(), "native-end", "native endScene is not wrapped")

handles = {}
local absent = dofile(modDir .. "/dramaless_wall_decals_compat.lua")(
  owner, { voxelRenderer = resolver })
ok(absent.install({}),
  "2D/no-renderer installation remains inert")
eq(absent.mode, "renderer-absent", "absence is an explicit safe status")

-- Exact upstream Battle Art 1.9.0 uses the same adapter through KASC's local
-- allowlist facade. The separately installed renderer remains owner of its
-- assets/options, while 1.8.3 and all other releases stay blocked upstream in
-- the resolver/manifest gate.
local battleEvents = {}
local BattleVoxel = {
  FACE_SHADE = Voxel3D.FACE_SHADE,
  pushQuad = Voxel3D.pushQuad,
  newMesh = Voxel3D.newMesh,
  draw = function() battleEvents[#battleEvents + 1] = "draw" end,
  glass = function() end,
  seams = function() end,
  endScene = function()
    battleEvents[#battleEvents + 1] = "end"
    return "battle-art-canvas"
  end,
}
local BattleScene = {}
BattleScene.render = function(state) return BattleVoxel.endScene(state) end
local battlePlaceholders = {
  AntiAlias = {}, BattleCam = {}, FirstPerson = {}, OverworldBattle = {},
  ShadowMap = {}, SpriteBillboards = {}, TerrainAtlas = {}, VoxelState = {},
}
local battleLib = { require = function(name)
  if name == "WallDecals" then error("Battle Art 1.9.0: module absent") end
  if name == "VoxelScene" then return BattleScene end
  if name == "Voxel3D" then return BattleVoxel end
  if name == "Mat4" then return Mat4 end
  if battlePlaceholders[name] then return battlePlaceholders[name] end
  error("unexpected Battle Art module " .. tostring(name))
end }
battleLib.mod = { id = "BATTLE_ART_VOXEL_FORK", assets = {} }
local battleStage = {
  apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
  ownership = { hud = true, animationProjection = true },
  state = function() return { staged = true } end,
}
local battlePresentation = {
  apiVersion = 1, sourceModId = "BATTLE_ART_VOXEL_FORK",
  suppressHook = "battle.presentation.suppress_native.v1",
}
handles = {
  BATTLE_ART_VOXEL_FORK = {
    id = "BATTLE_ART_VOXEL_FORK", version = "1.9.0",
    github = "absol89/DramaticShapeVoxelMod",
    exports = {
      version = "1.9.0", lib = battleLib,
      battleStage = battleStage,
      battlePresentation = battlePresentation,
    },
  },
}
local battleCompat = dofile(
  modDir .. "/dramaless_wall_decals_compat.lua")(
    owner, { voxelRenderer = resolver })
ok(battleCompat.install({}),
  "Battle Art 1.9.0 wall adapter installs through the local facade")
eq(battleCompat.mode, "adapter",
  "Battle Art without a native WallDecals module selects the generic adapter")
eq(battleCompat.rendererId, "BATTLE_ART_VOXEL_FORK",
  "wall adapter receipt retains Battle Art ownership")
eq(battleLib.mod.id, "BATTLE_ART_VOXEL_FORK",
  "adapter does not mutate Battle Art's asset/options owner")
eq(BattleScene.render(state), "battle-art-canvas",
  "Battle Art wrapped scene returns its original canvas")
eq(#battleEvents, 3,
  "Battle Art draws both live/neighbor decals before scene close")
eq(battleEvents[1], "draw", "Battle Art draws the live fissure in depth")
eq(battleEvents[2], "draw", "Battle Art draws the connected fissure in depth")
eq(battleEvents[3], "end", "Battle Art closes the scene after both fissures")

S.finish()
