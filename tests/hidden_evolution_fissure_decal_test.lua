-- Focused entrance-fissure contract. Run under LÖVE from gen1recomp with
-- KA_HIDDEN_EVOLUTION_MOD set to the Authority worktree.
local engine = os.getenv("GEN1RECOMP_ROOT") or "."
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")

local function registry()
  local r = { values = {} }
  function r:get(id) return self.values[id] end
  function r:register(id, value)
    assert(self.values[id] == nil, "duplicate " .. tostring(id))
    self.values[id] = value
    return value
  end
  function r:patch(id, partial)
    local value = self.values[id] or {}
    self.values[id] = value
    for key, incoming in pairs(partial) do
      if type(incoming) == "table" and type(incoming.__append) == "table" then
        value[key] = value[key] or {}
        for _, row in ipairs(incoming.__append) do value[key][#value[key] + 1] = row end
      else
        value[key] = incoming
      end
    end
    return value
  end
  return r
end

local currentMap, activeOw
local activeCharacter = "RED"
local archiveCompleted = {}
local eventHandlers = {}
local mod = {
  id = "kanto_ascendant",
  save = { get = function()
    return activeCharacter and { player_character = activeCharacter } or nil
  end },
  content = {
    maps = registry(), sprites = registry(), text = registry(),
    encounters = registry(), map_scripts = registry(),
    text_pointers = { patch = function() end },
  },
  events = {
    on = function(_, name, callback)
      eventHandlers[name] = eventHandlers[name] or {}
      eventHandlers[name][#eventHandlers[name] + 1] = callback
    end,
  },
}

for _, mapId in ipairs({ "ROUTE_22", "ROUTE_24", "ROUTE_3" }) do
  mod.content.maps:register(mapId, {
    id = mapId, objects = {}, wallDecals = {},
  })
end

local game = {
  data = { maps = mod.content.maps.values },
  save = { flags = {} },
}
mod.world = {
  overworld = function() return activeOw end,
  spawnNpc = function(_, mapId, def)
    assert(mapId == currentMap)
    local map = assert(game.data.maps[mapId])
    local copy = {}
    for key, value in pairs(def) do copy[key] = value end
    copy.index, copy.runtime, copy.owner = 100 + #(map.objects or {}), true, mod.id
    map.objects[#map.objects + 1] = copy
    local id = mapId .. "_obj_" .. tostring(copy.index)
    activeOw.npcs[#activeOw.npcs + 1] = { id = id, def = copy }
    return id
  end,
  removeNpc = function(_, id)
    if not activeOw then return nil, "no overworld" end
    for mapId, map in pairs(game.data.maps) do
      for index = #(map.objects or {}), 1, -1 do
        local object = map.objects[index]
        if object.runtime and object.owner == mod.id
            and mapId .. "_obj_" .. tostring(object.index) == id then
          table.remove(map.objects, index)
        end
      end
    end
    for index = #(activeOw and activeOw.npcs or {}), 1, -1 do
      if activeOw.npcs[index].id == id then table.remove(activeOw.npcs, index) end
    end
    return true
  end,
}

local architecture = assert(loadfile(root .. "/hidden_evolution_architecture.lua"))()(mod, {
  activeCharacter = function() return activeCharacter end,
  journey = { profile = function()
    return { completedPaths = archiveCompleted }
  end },
})
assert(architecture.register())
for _, mapId in ipairs({ "ROUTE_22", "ROUTE_24", "ROUTE_3" }) do
  assert(#(game.data.maps[mapId].wallDecals or {}) == 0,
    mapId .. " registration leaked a pre-save fissure decal")
end
assert(architecture.install(game))
local expected = {
  RED = { map = "ROUTE_22", x = 35, y = 1, elevation = 6, faceOffsetY = 6 },
  BLUE = { map = "ROUTE_24", x = 10, y = 3, elevation = 0 },
  GREEN = { map = "ROUTE_3", x = 41, y = 3, elevation = 0 },
}
local function fissureDecals(mapDef, key)
  local rows = {}
  for _, decal in ipairs(mapDef.wallDecals or {}) do
    if decal.id == "KA_HEVO_WALL_FISSURE_" .. key then
      rows[#rows + 1] = decal
    end
  end
  return rows
end
local function hasForeignDecal(mapDef, mapId)
  for _, decal in ipairs(mapDef.wallDecals or {}) do
    if decal.id == "FOREIGN_DECAL_" .. mapId then return true end
  end
  return false
end
for key, want in pairs(expected) do
  activeCharacter, currentMap = key, want.map
  activeOw = { map = { id = currentMap }, npcs = {} }
  game.save.flags = {}
  local mapDef = assert(game.data.maps[want.map])
  mapDef.wallDecals[#mapDef.wallDecals + 1] = {
    id = "FOREIGN_DECAL_" .. want.map,
    image = "foreign/mod/decal.png", cellX = 1, cellY = 1,
  }

  -- A fresh/pre-Hall save has neither visible art nor a talk object.  Native
  -- wall collision remains the only world actor at the authored cell.
  assert(architecture.refresh(game, want.map) == false,
    key .. " pre-discovery route must stay closed")
  assert(#fissureDecals(mapDef, key) == 0,
    key .. " pre-discovery fissure leaked visible art")
  assert(hasForeignDecal(mapDef, want.map),
    key .. " pre-discovery cleanup removed another mod's decal")
  assert(#(mapDef.objects or {}) == 0,
    key .. " pre-discovery fissure leaked interaction metadata")

  game.save.flags[architecture.flags.discovered .. key] = true
  assert(architecture.refresh(game, want.map),
    key .. " discovered fissure did not reconcile")
  local decals = fissureDecals(mapDef, key)
  assert(#decals == 1, key .. " needs exactly one discovered wall decal")
  local decal = decals[1]
  assert(decal.id == "KA_HEVO_WALL_FISSURE_" .. key)
  assert(decal.image == "assets/generated/hidden_evolution/sealed_fissure.png")
  assert(decal.cellX == want.x and decal.cellY == want.y)
  assert(decal.face == "south" and decal.elevation == want.elevation)
  assert(decal.faceOffsetY == want.faceOffsetY)
  local spawned = assert((mapDef.objects or {})[1], key .. " interaction anchor missing")
  assert(spawned and spawned.renderMode == "none" and spawned.passable == true)
  assert(spawned.sprite == "SPRITE_KA_HEVO_FISSURE_ANCHOR")
  assert(spawned.x == want.x and spawned.y == want.y)
  assert(spawned.text == "TEXT_KA_HEVO_FISSURE_" .. key)
  assert(architecture.refresh(game, want.map), key .. " repeated refresh failed")
  assert(#fissureDecals(mapDef, key) == 1 and #mapDef.objects == 1,
    key .. " repeated refresh duplicated fissure state")
  assert(hasForeignDecal(mapDef, want.map),
    key .. " discovered refresh removed another mod's decal")

  activeCharacter = key == "RED" and "BLUE" or "RED"
  assert(architecture.refresh(game, want.map) == false,
    key .. " foreign character must close route")
  assert(#fissureDecals(mapDef, key) == 0 and #mapDef.objects == 0,
    key .. " foreign character retained fissure art or interaction")
  assert(hasForeignDecal(mapDef, want.map),
    key .. " character cleanup removed another mod's decal")
end

-- A pre-6.5 save has no extended-character record: researcher and entrance
-- must both resolve that exact absence as legacy RED.
activeCharacter, currentMap = nil, expected.RED.map
activeOw = { map = { id = currentMap }, npcs = {} }
game.save = { flags = {
  [architecture.flags.discovered .. "RED"] = true,
} }
assert(architecture.refresh(game, currentMap),
  "legacy RED discovery did not reveal its entrance")
assert(#fissureDecals(game.data.maps[currentMap], "RED") == 1
    and #game.data.maps[currentMap].objects == 1,
  "legacy RED researcher/entrance identity diverged")

-- The merged map catalog survives Continue/New Game.  save.loading must purge
-- the outgoing discovery before save.created reconciles the fresh slot.
activeCharacter, currentMap = "RED", expected.RED.map
activeOw = { map = { id = currentMap }, npcs = {} }
game.save = { flags = { [architecture.flags.discovered .. "RED"] = true } }
assert(architecture.refresh(game, currentMap))
assert(#fissureDecals(game.data.maps[currentMap], "RED") == 1)
-- BLITZ may have completed RED in the account-wide archive. That stale profile
-- must not give a brand-new non-Legacy slot its crack back.
archiveCompleted.red = true
activeOw = nil
eventHandlers["save.loading"][1]({ raw = { flags = {} } })
assert(#fissureDecals(game.data.maps[currentMap], "RED") == 0)
assert(hasForeignDecal(game.data.maps[currentMap], currentMap),
  "slot purge removed another mod's decal")
assert(#game.data.maps[currentMap].objects == 0)
game.save = { flags = {} }
eventHandlers["save.created"][1]({ game = game, save = game.save })
assert(#fissureDecals(game.data.maps[currentMap], "RED") == 0)
assert(hasForeignDecal(game.data.maps[currentMap], currentMap),
  "New Game reconciliation removed another mod's decal")
assert(#game.data.maps[currentMap].objects == 0)
archiveCompleted.red = nil

local anchor = assert(mod.content.sprites:get("SPRITE_KA_HEVO_FISSURE_ANCHOR"))
assert(anchor.image == "assets/generated/hidden_evolution/interaction_anchor.png")
assert(anchor.trueColor == nil, "transparent anchor must not exempt its wall from palette rendering")
assert(not mod.content.sprites:get("SPRITE_KA_HEVO_CHARACTER_FISSURE_HIGH"))

local Schemas = require("src.mods.Schemas")
local schemaOk, schemaWhy = Schemas.check(Schemas.REGISTRIES.maps, "maps", "ROUTE_22", {
  wallDecals = { __append = { {
    id = "KA_HEVO_WALL_FISSURE_RED",
    image = "assets/generated/hidden_evolution/sealed_fissure.png",
    cellX = 35, cellY = 1, face = "south", elevation = 6, faceOffsetY = 6,
  } } },
}, "patch")
assert(schemaOk, schemaWhy)

-- Run the real transform recipe against real LÖVE ImageData and exercise
-- encode + filesystem write, not a table-shaped imitation of an image.
local ImageWriter = require("src.import.ImageWriter")
local written = {}
local ctx = {
  exists = function(rel) return rel == "tilesets/cavern.png" end,
  readImage = function() return ImageWriter.blank(128, 32, 0, 0, 0, 0) end,
  blank = ImageWriter.blank,
  blit = ImageWriter.blit,
  recolor = function(image) return image end,
}
function ctx.writeImage(image, rel)
  assert(image and image.typeOf and image:typeOf("ImageData"), rel .. " is not ImageData")
  written[rel] = image
  local path = "focused-fissure/" .. rel
  assert(love.filesystem.createDirectory(path:match("^(.*)/[^/]+$")))
  local encoded = assert(image:encode("png"))
  local ok, why = love.filesystem.write(path, encoded)
  assert(ok, "could not write " .. path .. ": " .. tostring(why))
end
assert(loadfile(root .. "/shiny_transforms.lua"))()(ctx)

local transparent = assert(written["hidden_evolution/interaction_anchor.png"])
assert(transparent:getWidth() == 16 and transparent:getHeight() == 16)
for y = 0, 15 do for x = 0, 15 do
  local _, _, _, a = transparent:getPixel(x, y)
  assert(a == 0, "interaction anchor contains a visible pixel")
end end

local fissure = assert(written["hidden_evolution/sealed_fissure.png"])
local core = {
  ["7:0"]=true,["8:0"]=true,
  ["6:1"]=true,["7:1"]=true,["8:1"]=true,
  ["3:2"]=true,["4:2"]=true,["5:2"]=true,["6:2"]=true,
  ["7:2"]=true,["8:2"]=true,["9:2"]=true,
  ["3:3"]=true,["4:3"]=true,["6:3"]=true,["7:3"]=true,
  ["8:3"]=true,["9:3"]=true,
  ["5:4"]=true,["6:4"]=true,["7:4"]=true,["8:4"]=true,
  ["9:4"]=true,["10:4"]=true,["11:4"]=true,
  ["6:5"]=true,["7:5"]=true,["11:5"]=true,["12:5"]=true,
  ["5:6"]=true,["6:6"]=true,["7:6"]=true,
  ["4:7"]=true,["5:7"]=true,["6:7"]=true,
}
local rim = {
  ["6:0"]=true,["9:0"]=true,["5:1"]=true,["9:1"]=true,
  ["2:2"]=true,["10:2"]=true,["2:3"]=true,["5:3"]=true,
  ["10:3"]=true,["4:4"]=true,["12:4"]=true,
  ["5:5"]=true,["8:5"]=true,["10:5"]=true,["13:5"]=true,
  ["4:6"]=true,["8:6"]=true,["3:7"]=true,["7:7"]=true,
}
local glint = {
  ["5:0"]=true,["4:1"]=true,["10:1"]=true,["1:2"]=true,
  ["11:2"]=true,["1:3"]=true,["11:3"]=true,["3:4"]=true,
  ["13:4"]=true,["4:5"]=true,["14:5"]=true,["3:6"]=true,
  ["9:6"]=true,["2:7"]=true,["8:7"]=true,
}
local coreCount, rimCount, glintCount, flatVisibleCount = 0, 0, 0, 0
local function close(a, b) return math.abs(a - b) < 1 / 1000 end
for y = 0, 15 do for x = 0, 15 do
  local r, g, b, a = fissure:getPixel(x, y)
  local tag = x .. ":" .. y
  if core[tag] then
    coreCount = coreCount + 1
    if y < 8 then flatVisibleCount = flatVisibleCount + 1 end
    assert(close(r, 8/255) and close(g, 8/255) and close(b, 10/255)
      and close(a, 1), "renderer-safe fissure core changed")
    -- The 2D four-shade shader classifies the already composited canvas.
    -- Keep a crack over the lightest possible wall below its black threshold.
    assert(r * a + (1 - a) <= 0.17, "fissure would remap to a pale shade")
  elseif rim[tag] then
    rimCount = rimCount + 1
    if y < 8 then flatVisibleCount = flatVisibleCount + 1 end
    assert(close(r, 112/255) and close(g, 142/255) and close(b, 148/255)
      and close(a, 1), "contrast rim changed")
  elseif glint[tag] then
    glintCount = glintCount + 1
    if y < 8 then flatVisibleCount = flatVisibleCount + 1 end
    assert(close(r, 218/255) and close(g, 232/255) and close(b, 222/255)
      and close(a, 1), "fissure glint changed")
  else
    assert(a == 0, "unexpected fissure pixel at " .. x .. ":" .. y)
  end
end end
assert(coreCount == 35 and rimCount == 19 and glintCount == 15)
assert(flatVisibleCount == 69,
  "flat wall-face crop must retain the full star fracture")
-- Pixel-shape guard: the visible mark spans most of one wall face, but the
-- canvas corners, entire lower half and the gap between its two lower
-- branches remain transparent.  That rules out both the old vanishing
-- hairline and a rectangular sign/billboard regression.
for _, tag in ipairs({ "0:0", "15:0", "0:7", "15:7", "9:5" }) do
  local x, y = tag:match("^(%d+):(%d+)$")
  local _, _, _, a = fissure:getPixel(tonumber(x), tonumber(y))
  assert(a == 0, "fissure transparency gap closed at " .. tag)
end
for y = 8, 15 do for x = 0, 15 do
  local _, _, _, a = fissure:getPixel(x, y)
  assert(a == 0, "fissure escaped native wall face at " .. x .. ":" .. y)
end end
assert(written["hidden_evolution/sealed_fissure_high.png"] == nil,
  "height must be positional, not a clipped bitmap variant")

-- Flat renderer: the wall-local correction keeps the raised fissure on the
-- visible rock face without moving its authored cell.
local drawCall, quadCall
local fakeImage = { getDimensions = function() return 16, 16 end }
local fakeAssets = {
  image = function() return fakeImage end,
  register = function() end,
}
package.loaded["src.render.Assets"] = fakeAssets
package.loaded["src.world.WallDecals"] = nil
local oldDraw, oldSetColor, oldNewQuad =
  love.graphics.draw, love.graphics.setColor, love.graphics.newQuad
love.graphics.newQuad = function(x, y, w, h, iw, ih)
  quadCall = { x, y, w, h, iw, ih }
  return quadCall
end
love.graphics.draw = function(image, quad, x, y)
  drawCall = { image, quad, x, y }
end
love.graphics.setColor = function() end
local FlatDecals = require("src.world.WallDecals")
FlatDecals.draw({ wallDecals = { {
  image = "crack", cellX = 35, cellY = 1, face = "south", elevation = 6,
  faceOffsetY = 6,
} } }, 500, 0)
love.graphics.draw, love.graphics.setColor, love.graphics.newQuad =
  oldDraw, oldSetColor, oldNewQuad
assert(quadCall and quadCall[1] == 0 and quadCall[2] == 0
  and quadCall[3] == 16 and quadCall[4] == 8
  and quadCall[5] == 16 and quadCall[6] == 16)
assert(drawCall and drawCall[1] == fakeImage and drawCall[2] == quadCall
  and drawCall[3] == 60 and drawCall[4] == 24)

-- Voxel renderer: the same record becomes a south wall plane, never a
-- camera-facing card. Capture the actual mesh vertices and model placement.
local meshBuilt, voxelDraw
local voxel = {
  FACE_SHADE = { [1]=.84, [2]=.72, [5]=.90, [6]=.68 },
  pushQuad = function(indices) for _, i in ipairs({1,2,3,1,3,4}) do indices[#indices+1]=i end end,
  newMesh = function(verts, indices)
    meshBuilt = { verts = verts, indices = indices }
    return meshBuilt
  end,
  glass = function() end, seams = function() end,
  draw = function(mesh, image, model) voxelDraw = { mesh=mesh, image=image, model=model } end,
  endScene = function() return "voxel-canvas" end,
}
local voxelScene = {}
voxelScene.render = function() return voxel.endScene() end
local namespace = { require = function(name)
  if name == "Voxel3D" then return voxel end
  if name == "VoxelScene" then return voxelScene end
  if name == "Mat4" then return { translate = function(x,y,z) return {x,y,z} end } end
  -- Reviewed DRAMALESS_SHAPE 1.6.2-ST.190.1 has no native WallDecals module. The
  -- product must prove its own public-seam adapter rather than silently
  -- borrowing a locally patched renderer tree.
  return nil
end }
local VoxelDecals = assert(loadfile(
  root .. "/dramaless_wall_decals_compat.lua"))()({}, {
    voxelRenderer = { resolve = function()
      return { id = "DRAMALESS_SHAPE", lib = namespace }
    end },
  })
assert(VoxelDecals.install({ mods={ exports={
  DRAMALESS_SHAPE={ version="1.6.2-ST.190.1", lib=namespace },
} } }))
assert(VoxelDecals.mode == "adapter" and VoxelDecals.lastError == nil)
assert(voxelScene.render({ map={ def={ wallDecals = { {
  image = "crack", cellX = 35, cellY = 1, face = "south", elevation = 6,
  faceOffsetY = 6,
} } } }, neighbors={} }) == "voxel-canvas")
assert(voxelDraw and voxelDraw.mesh == meshBuilt and voxelDraw.image == fakeImage)
assert(voxelDraw.model[1] == 560 and voxelDraw.model[2] == 0 and voxelDraw.model[3] == 16)
assert(meshBuilt.verts[1][3] > 16 and meshBuilt.verts[4][2] == 16,
  "decal is not a vertical south-wall plane")
for _, vertex in ipairs(meshBuilt.verts) do
  assert(close(vertex[3], meshBuilt.verts[1][3]),
    "decal quad left the south wall plane")
end
-- Image row 1 is near the top of the vertical quad and row 10 is near its
-- lower half. With the elevated site's face correction, every opaque row is
-- inside the owning 0..16 wall height instead of floating above the crest.
local opaqueWorldLow = 16 - 10 + voxelDraw.model[2]
local opaqueWorldHigh = 16 - 1 + voxelDraw.model[2]
assert(opaqueWorldLow >= 0 and opaqueWorldHigh <= 16,
  "opaque fissure pixels left the vertical wall face")

print("hidden_evolution_fissure_decal_test: PASS")
