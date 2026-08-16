-- Keep map-authored wall decals visible in the officially supported renderer
-- pipelines that do not yet provide their own WallDecals module.  This covers
-- DRAMALESS_SHAPE 1.6.2-ST.190.1 and upstream Battle Art 1.9.0/1.9.2.
--
-- The engine owns the flat `src.world.WallDecals` pass, but a drawWorld
-- pipeline replaces that whole pass.  Install this small adapter only when the
-- reviewed renderer's KASC-local module facade reports no native implementation.
-- It draws the same records into the still-open depth scene immediately before
-- `Voxel3D.endScene()`.  No separately installed renderer files, assets,
-- settings or saves are edited, and a future/native implementation always wins.

return function(mod, opts)
  opts = opts or {}
  local C = {
    installed = false,
    mode = "inactive",
    lastError = nil,
    drawCount = 0,
    lastDrawn = nil,
    rendererId = nil,
  }
  local function sharedVoxelResolver(provided)
    if provided then return provided end
    if mod.exports and mod.exports.voxelRendererCompat then
      return mod.exports.voxelRendererCompat
    end
    local chunk
    if type(mod.read) == "function" then
      local body = mod:read("voxel_renderer_compat.lua")
      if type(body) == "string" then
        chunk = loadstring(body, "@voxel_renderer_compat.lua")
      end
    end
    local ok, factory = false, nil
    if chunk then
      ok, factory = pcall(chunk)
    else
      ok, factory = pcall(require, "voxel_renderer_compat")
    end
    local made, resolver = false, nil
    if ok and type(factory) == "function" then
      made, resolver = pcall(factory, mod)
    end
    return made and resolver or nil
  end
  local voxelRenderer = sharedVoxelResolver(opts.voxelRenderer)

  local activeState
  local drawing = false
  local meshes, images = {}, {}

  local function renderer(game)
    if not (voxelRenderer and type(voxelRenderer.resolve) == "function") then
      C.rendererId = nil
      return nil
    end
    local package, id = voxelRenderer.resolve(game)
    C.rendererId = id
    return package and package.lib or nil
  end

  local function nativeWallDecals(lib)
    local ok, value = pcall(lib.require, "WallDecals")
    return ok and type(value) == "table" and type(value.draw) == "function"
  end

  local function build(Voxel3D, Assets, path, face)
    local ok, image = pcall(Assets.image, path)
    if not (ok and image and type(image.getDimensions) == "function") then
      return nil
    end
    local iw, ih = image:getDimensions()
    if not (iw and ih and iw > 0 and ih > 0) then return nil end
    local u0, u1 = 0.02 / iw, (iw - 0.02) / iw
    local v0, v1 = 0.02 / ih, (ih - 0.02) / ih
    local e = 0.04
    local shades = Voxel3D.FACE_SHADE or {}
    local shade = ({
      east = shades[1], west = shades[2],
      south = shades[5], north = shades[6],
    })[face] or 1
    local corners
    if face == "north" then
      corners = { {16,0,-e}, {0,0,-e}, {0,16,-e}, {16,16,-e} }
    elseif face == "east" then
      corners = { {16+e,0,16}, {16+e,0,0}, {16+e,16,0}, {16+e,16,16} }
    elseif face == "west" then
      corners = { {-e,0,0}, {-e,0,16}, {-e,16,16}, {-e,16,0} }
    else
      corners = { {0,0,16+e}, {16,0,16+e},
                  {16,16,16+e}, {0,16,16+e} }
    end
    local vertices = {
      { corners[1][1], corners[1][2], corners[1][3], u0, v1, shade },
      { corners[2][1], corners[2][2], corners[2][3], u1, v1, shade },
      { corners[3][1], corners[3][2], corners[3][3], u1, v0, shade },
      { corners[4][1], corners[4][2], corners[4][3], u0, v0, shade },
    }
    local indices = {}
    Voxel3D.pushQuad(indices, 0)
    return Voxel3D.newMesh(vertices, indices), image
  end

  local function installAdapter(lib)
    local okScene, VoxelScene = pcall(lib.require, "VoxelScene")
    local okVoxel, Voxel3D = pcall(lib.require, "Voxel3D")
    local okMat, Mat4 = pcall(lib.require, "Mat4")
    if not (okScene and type(VoxelScene) == "table"
        and type(VoxelScene.render) == "function"
        and okVoxel and type(Voxel3D) == "table"
        and type(Voxel3D.endScene) == "function"
        and type(Voxel3D.draw) == "function"
        and type(Voxel3D.newMesh) == "function"
        and type(Voxel3D.pushQuad) == "function"
        and okMat and type(Mat4) == "table"
        and type(Mat4.translate) == "function") then
      C.mode = "unsupported"
      return false
    end

    local already = Voxel3D.__kantoAscendantWallDecalsCompat
    if already then
      C.mode = already.mode or "adapter"
      C.installed = true
      return true
    end

    local Assets = require("src.render.Assets")
    local function invalidate()
      meshes, images = {}, {}
    end
    if type(Assets.register) == "function" then Assets.register(invalidate) end

    local function drawable(path, face)
      local key = tostring(path) .. "#" .. tostring(face)
      if meshes[key] == nil then
        local ok, mesh, image = pcall(build,
          Voxel3D, Assets, path, face)
        meshes[key] = ok and mesh or false
        images[key] = ok and image or false
      end
      return meshes[key] or nil, images[key] or nil
    end

    local function drawMap(map, offsetX, offsetZ)
      local def = map and (map.def or map)
      local decals = def and def.wallDecals
      if type(decals) ~= "table" then return end
      if type(Voxel3D.glass) == "function" then Voxel3D.glass(false) end
      if type(Voxel3D.seams) == "function" then Voxel3D.seams(false) end
      for _, decal in ipairs(decals) do
        if decal.image and decal.cellX and decal.cellY then
          local face = decal.face or "south"
          local mesh, image = drawable(decal.image, face)
          if mesh and image then
            local along = tonumber(decal.offsetX) or 0
            local x = (tonumber(offsetX) or 0) + decal.cellX * 16
            local z = (tonumber(offsetZ) or 0) + decal.cellY * 16
            if face == "east" or face == "west" then
              z = z + along
            else
              x = x + along
            end
            -- Map wall art measures faceOffsetY downward, while the voxel
            -- scene's Y axis points up.
            local y = (tonumber(decal.elevation) or 0)
              - (tonumber(decal.faceOffsetY) or 0)
            Voxel3D.draw(mesh, image, Mat4.translate(x, y, z))
            C.drawCount = C.drawCount + 1
            C.lastDrawn = {
              id = decal.id, mapId = def.id or map.id,
              cellX = decal.cellX, cellY = decal.cellY, face = face,
            }
          end
        end
      end
      if type(Voxel3D.seams) == "function" then Voxel3D.seams(true) end
      if type(Voxel3D.glass) == "function" then Voxel3D.glass(true) end
    end

    local function drawState(state)
      if not (state and state.map) then return end
      drawMap(state.map, 0, 0)
      for _, neighbor in ipairs(state.neighbors or {}) do
        drawMap(neighbor.map, neighbor.ox or 0, neighbor.oy or 0)
      end
    end

    local originalRender = VoxelScene.render
    local originalEndScene = Voxel3D.endScene
    VoxelScene.render = function(state, ...)
      local previous = activeState
      activeState = state
      local ok, a, b, c, d = pcall(originalRender, state, ...)
      activeState = previous
      if not ok then error(a, 0) end
      return a, b, c, d
    end
    Voxel3D.endScene = function(...)
      if activeState and not drawing then
        drawing = true
        local ok, why = pcall(drawState, activeState)
        drawing = false
        if not ok then C.lastError = tostring(why) end
      end
      return originalEndScene(...)
    end
    Voxel3D.__kantoAscendantWallDecalsCompat = {
      mode = "adapter", version = 1,
    }
    C.mode = "adapter"
    C.installed = true
    C.invalidate = invalidate
    return true
  end

  function C.install(game)
    local lib = renderer(game)
    if not lib then
      C.mode = "renderer-absent"
      return true
    end
    if nativeWallDecals(lib) then
      C.mode = "native"
      C.installed = true
      return true
    end
    return installAdapter(lib)
  end

  return C
end
