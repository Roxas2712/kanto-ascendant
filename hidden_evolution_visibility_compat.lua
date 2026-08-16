-- Final-world visibility for the released 0.1.83 renderer.
--
-- That renderer has neither Renderer:queueWorldPostOverlay nor
-- OverworldController:drawAtmosphere.  The three route packages may still
-- attach their ordinary gameplay state, but their presentation callbacks are
-- never reached and a dark-map palette consequently exposes the whole maze.
-- This adapter stays entirely inside the mod:
--   * flat worlds are masked at the end of OverworldState:drawWorld, while
--     the world canvas is still active and before the UI pass;
--   * Tilt masks the already drawn upright canvas, so neither its actors nor
--     the projected ground can leak through outside the aperture;
--   * Voxel/world pipelines are folded through Pipelines.worldPresent, also
--     before the UI composite.
-- Newer renderers never install this adapter.

return function(mod, opts)
  opts = opts or {}
  local V = {
    id = "KA_HEVO_LEGACY_VISIBILITY_V1",
    installed = false,
    presentation = "legacy-mod-world-mask",
  }
  local routes = assert(opts.routes, "legacy HEVO visibility needs route modules")
  local voxelRenderer = opts.voxelRenderer

  local function values(t)
    local out = {}
    for _, value in pairs(type(t) == "table" and t or {}) do
      out[#out + 1] = value
    end
    return out
  end

  local mapKind = {}
  for _, row in ipairs({ { "RED", routes.RED }, { "BLUE", routes.BLUE },
      { "GREEN", routes.GREEN } }) do
    local ids = row[2] and (row[2].IDS or row[2].ids)
    for _, mapId in ipairs(values(ids)) do
      if type(mapId) == "string" then mapKind[mapId] = row[1] end
    end
  end
  V.mapKind = mapKind

  local function activeOverworld(game, candidate)
    if candidate and candidate.map then return candidate end
    local world = mod.world and mod.world.overworld and mod.world:overworld()
    if world and world.map then return world end
    return game and game.overworld
  end

  local function redProfile(game, ow)
    local route = routes.RED
    local mapId=ow and ow.map and ow.map.id
    local profile=route and type(route.floorSightProfile)=="function"
      and route.floorSightProfile(game.save,mapId) or nil
    if profile then ow.kaHevoRedSight=profile end
    profile=profile or ow.kaHevoRedSight
    if not profile and route and type(route.run) == "function"
        and type(route.sightProfile) == "function" then
      local run = route.run(game.save, true)
      profile = route.sightProfile(run and run.sight or 0,
        run and run.completed == true)
      ow.kaHevoRedSight = profile
    end
    if not profile then return nil end
    return {
      kind = "RED", radius = tonumber(profile.radius) or 1.9,
      coreRadius = tonumber(profile.coreRadius) or 0.85,
      coneSlope = tonumber(profile.coneSlope) or 0.34,
      innerOpacity = tonumber(profile.innerOpacity) or 0.32,
      outerOpacity = tonumber(profile.opacity) or 1,
      featherPx = math.max(0.5, math.min(2, tonumber(profile.featherPx) or 2)),
      outerColor = { 0, 0, 0 }, innerColor = { 0, 0, 0 },
    }
  end

  local function blueProfile(game, ow)
    local route = routes.BLUE
    local mapId=ow and ow.map and ow.map.id
    local profile=route and type(route.floorSightProfile)=="function"
      and route.floorSightProfile(game.save,mapId) or nil
    if profile then ow.kaHevoBlueSight=profile end
    profile=profile or ow.kaHevoBlueSight
    if not profile and route and type(route.sightProfile) == "function" then
      local state = type(route.state) == "function" and route.state(false) or nil
      profile = route.sightProfile(state and state.sight or 0)
      ow.kaHevoBlueSight = profile
    end
    if not profile then return nil end
    return {
      kind = "BLUE", radius = tonumber(profile.radius) or 1.75,
      innerOpacity = tonumber(profile.innerOpacity) or 0.68,
      outerOpacity = tonumber(profile.outerOpacity or profile.opacity) or 1,
      featherPx = math.max(0.5, math.min(2, tonumber(profile.featherPx) or 2)),
      outerColor = { 0.003, 0.009, 0.016 },
      innerColor = { 0.003, 0.009, 0.016 },
    }
  end

  local function greenProfile(game,ow)
    local route = routes.GREEN
    if not (route and type(route.progress) == "function") then return nil end
    local mapId=ow and ow.map and ow.map.id
    local floor=type(route.floorSightProfile)=="function"
      and route.floorSightProfile(game.save,mapId) or nil
    local progress = route.progress(game.save) or {}
    local sight = floor and (floor.floorStage or 0)
      or math.max(0, math.min(5, tonumber(progress.sight) or 0))
    local inner = floor and floor.innerOpacity
      or type(route.fogInnerOpacity) == "function"
      and route.fogInnerOpacity(sight) or (0.72 - sight * 0.108)
    local outer = route.FOG_OUTER_COLOR or { 30 / 255, 30 / 255, 30 / 255 }
    return {
      kind = "GREEN", radius = floor and floor.radius or 1 + sight,
      innerOpacity = tonumber(inner) or 0.72, outerOpacity = 1,
      featherPx = math.max(0.5, math.min(2,
        tonumber(route.FOG_EDGE_SCREEN_PIXELS) or 2)),
      outerColor = { outer[1], outer[2], outer[3] },
      innerColor = { 0.07, 0.10, 0.08 }, sight = sight,
    }
  end

  local function profileFor(game, ow)
    local mapId = ow and ow.map and ow.map.id
    local kind = mapKind[mapId]
    if kind == "RED" then return redProfile(game, ow), mapId end
    if kind == "BLUE" then return blueProfile(game, ow), mapId end
    if kind == "GREEN" then return greenProfile(game,ow), mapId end
    return nil, mapId
  end
  V.profileFor = profileFor

  local SHADERS = {
    RED = [[
      extern vec2 sightCenter;
      extern vec2 sightFacing;
      extern number sightRadius;
      extern number sightCoreRadius;
      extern number sightConeSlope;
      extern number sightInnerOpacity;
      extern number sightOpacity;
      extern number sightFeatherPx;
      vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
        vec2 delta=screen-sightCenter;
        vec2 facing=normalize(sightFacing);
        number distanceFromPlayer=length(delta);
        number forward=dot(delta,facing);
        number lateral=abs(dot(delta,vec2(-facing.y,facing.x)));
        number coreSigned=distanceFromPlayer-sightCoreRadius*1.80;
        number coneWidth=sightCoreRadius*0.62
          + max(forward,0.0)*sightConeSlope;
        number coneSigned=max(lateral-coneWidth,
          max(-forward,forward-sightRadius));
        number apertureSigned=min(coreSigned,coneSigned);
        number edge=smoothstep(-min(sightFeatherPx,2.0),0.0,
          apertureSigned);
        number darkness=mix(sightInnerOpacity,sightOpacity,edge);
        return vec4(0.0,0.0,0.0,darkness);
      }
    ]],
    BLUE = [[
      extern vec2 sightCenter;
      extern number sightRadius;
      extern number sightInnerOpacity;
      extern number sightOuterOpacity;
      extern number sightFeatherPx;
      vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
        number edge=smoothstep(sightRadius-sightFeatherPx,sightRadius,
          distance(screen,sightCenter));
        number darkness=mix(sightInnerOpacity,sightOuterOpacity,edge);
        return vec4(0.003,0.009,0.016,darkness);
      }
    ]],
    GREEN = [[
      extern vec2 sightCenter;
      extern number sightRadius;
      extern number sightInnerOpacity;
      extern number sightFeatherPx;
      extern vec3 sightOuterColor;
      extern number sightTime;
      extern number sightMotionAlpha;
      vec4 effect(vec4 color, Image texture, vec2 uv, vec2 screen) {
        number edge=smoothstep(sightRadius-sightFeatherPx,sightRadius,
          distance(screen,sightCenter));
        number bandA=sin(screen.y*0.045
          + sin(screen.x*0.018+sightTime*0.08)*0.9-sightTime*0.24);
        number bandB=sin(screen.x*0.024-screen.y*0.014+sightTime*0.17);
        number haze=smoothstep(0.15,1.0,bandA*0.66+bandB*0.34);
        number inside=min(0.94,sightInnerOpacity+haze*sightMotionAlpha);
        return mix(vec4(0.07,0.10,0.08,inside),
          vec4(sightOuterColor,1.0),edge);
      }
    ]],
  }
  V.shaderSources = SHADERS

  local function direction(ow)
    local dirs = { up = { 0, -1 }, down = { 0, 1 },
      left = { -1, 0 }, right = { 1, 0 } }
    return dirs[ow.player and ow.player.facing] or dirs.down
  end

  local function failClosed(width, height, profile)
    local color = profile and profile.outerColor or { 0, 0, 0 }
    love.graphics.setShader()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setColor(color[1], color[2], color[3], 1)
    love.graphics.rectangle("fill", 0, 0, width, height)
  end

  local function stencilFallback(profile, geometry)
    local cx, cy, cell = geometry.centerX, geometry.centerY, geometry.cellPixels
    local width, height = geometry.width, geometry.height
    local outer, inner = profile.outerColor, profile.innerColor
    love.graphics.setShader()
    love.graphics.stencil(function()
      if profile.kind == "RED" then
        local facing = geometry.facing
        local core = profile.coreRadius * cell * 1.80
        local radius = profile.radius * cell
        local fx, fy = facing[1], facing[2]
        local len = math.sqrt(fx * fx + fy * fy)
        if len <= 0 then fx, fy, len = 0, 1, 1 end
        fx, fy = fx / len, fy / len
        local pxn, pyn = -fy, fx
        local base = profile.coreRadius * cell * 0.62
        local tip = base + radius * profile.coneSlope
        love.graphics.circle("fill", cx, cy, core)
        love.graphics.polygon("fill",
          cx + pxn * base, cy + pyn * base,
          cx + fx * radius + pxn * tip, cy + fy * radius + pyn * tip,
          cx + fx * radius - pxn * tip, cy + fy * radius - pyn * tip,
          cx - pxn * base, cy - pyn * base)
      else
        love.graphics.circle("fill", cx, cy, profile.radius * cell)
      end
    end, "replace", 1)
    love.graphics.setStencilTest("notequal", 1)
    love.graphics.setColor(outer[1], outer[2], outer[3], profile.outerOpacity)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setStencilTest("equal", 1)
    love.graphics.setColor(inner[1], inner[2], inner[3], profile.innerOpacity)
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setStencilTest()
  end

  local shaderCache = {}
  local function drawMask(profile, geometry)
    if not (love and love.graphics and love.graphics.rectangle) then
      return false, "graphics"
    end
    if not (geometry.centerX and geometry.centerY
        and geometry.cellPixels and geometry.cellPixels > 0) then
      failClosed(geometry.width, geometry.height, profile)
      return true, "fail-closed-projection"
    end
    if profile.kind == "BLUE" and geometry.glacier then
      love.graphics.setShader()
      love.graphics.setBlendMode("multiply", "premultiplied")
      love.graphics.setColor(0.34, 0.78, 1, 1)
      love.graphics.rectangle("fill", 0, 0, geometry.width, geometry.height)
      love.graphics.setBlendMode("alpha", "alphamultiply")
    end
    if shaderCache[profile.kind] == nil and love.graphics.newShader then
      local ok, shader = pcall(love.graphics.newShader, SHADERS[profile.kind])
      shaderCache[profile.kind] = ok and shader or false
      if not ok and mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("legacy HEVO %s mask shader unavailable: %s",
          profile.kind, tostring(shader))
      end
    end
    local shader = shaderCache[profile.kind]
    if not shader then
      if love.graphics.stencil and love.graphics.setStencilTest then
        stencilFallback(profile, geometry)
        return true, "stencil"
      end
      failClosed(geometry.width, geometry.height, profile)
      return true, "fail-closed-no-stencil"
    end
    shader:send("sightCenter", { geometry.centerX, geometry.centerY })
    shader:send("sightRadius", profile.radius * geometry.cellPixels)
    shader:send("sightInnerOpacity", profile.innerOpacity)
    shader:send("sightFeatherPx", profile.featherPx)
    if profile.kind == "RED" then
      shader:send("sightFacing", geometry.facing)
      shader:send("sightCoreRadius", profile.coreRadius * geometry.cellPixels)
      shader:send("sightConeSlope", profile.coneSlope)
      shader:send("sightOpacity", profile.outerOpacity)
    elseif profile.kind == "BLUE" then
      shader:send("sightOuterOpacity", profile.outerOpacity)
    else
      local now = love.timer and love.timer.getTime and love.timer.getTime()
        or os.clock()
      shader:send("sightOuterColor", profile.outerColor)
      shader:send("sightTime", now)
      shader:send("sightMotionAlpha", math.max(0.025,
        0.085 - (profile.sight or 0) * 0.011))
    end
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, geometry.width, geometry.height)
    love.graphics.setShader()
    return true, "shader"
  end
  V.drawMask = drawMask

  local function flatGeometry(ow, renderer)
    local dir = direction(ow)
    local width, height = renderer.worldCanvas:getDimensions()
    return {
      width = width, height = height,
      centerX = ow.player.px - ow.camera.x + 8,
      centerY = ow.player.py - ow.camera.y + 12,
      cellPixels = 16, facing = { dir[1], dir[2] },
      projection = "legacy-flat-world-canvas",
      glacier = ow.map and ow.map.id == "KA_HEVO_BLUE_GLACIER_MAZE",
    }
  end

  local function tiltGeometry(ow, renderer, Tilt)
    local dir = direction(ow)
    local vw, vh = renderer:worldViewSize()
    local x = ow.player.px - ow.camera.x + 8
    local y = ow.player.py - ow.camera.y + 12
    local cx, cy = Tilt.groundPoint(x, y, vw, vh)
    local ax, ay = Tilt.groundPoint(x + dir[1] * 16,
      y + dir[2] * 16, vw, vh)
    local dx, dy = ax - cx, ay - cy
    local cell = math.sqrt(dx * dx + dy * dy)
    local M = renderer.UPRIGHT_MARGIN or 0
    local width, height = renderer.uprightCanvas:getDimensions()
    return {
      width = width, height = height, centerX = cx + M, centerY = cy + M,
      cellPixels = cell, facing = { dx, dy }, projection = "legacy-tilt-upright",
      glacier = ow.map and ow.map.id == "KA_HEVO_BLUE_GLACIER_MAZE",
    }
  end

  local function voxelPoint(game, ow, wx, wz)
    local projector = voxelRenderer and voxelRenderer.module(game, "Voxel3D")
    if not (projector and type(projector.project) == "function") then return nil end
    local ground = 0
    local scene = voxelRenderer.module(game, "VoxelScene")
    if scene and type(scene.groundAt) == "function" then
      local cellX, cellY = math.floor(wx / 16), math.floor(wz / 16)
      local ok, value = pcall(scene.groundAt, ow.map, cellX, cellY)
      if ok and tonumber(value) then ground = tonumber(value) end
    end
    local x, y = projector.project(wx, ground, wz)
    if not (x and y) then return nil end
    local aa = voxelRenderer.module(game, "AntiAlias")
    local factor = aa and type(aa.factor) == "function" and aa.factor() or 1
    if not factor or factor <= 0 then factor = 1 end
    return x / factor, y / factor
  end

  local function pipelineGeometry(game, ow, canvas, ctx)
    local dir = direction(ow)
    local wx, wz = ow.player.px + 8, ow.player.py + 16
    local cx, cy = voxelPoint(game, ow, wx, wz)
    local ax, ay = voxelPoint(game, ow, wx + dir[1] * 16, wz + dir[2] * 16)
    local dx, dy, cell
    if cx and cy and ax and ay then
      dx, dy = ax - cx, ay - cy
      cell = math.sqrt(dx * dx + dy * dy)
    end
    local width, height = canvas:getDimensions()
    return {
      width = width, height = height, centerX = cx, centerY = cy,
      cellPixels = cell, facing = { dx or dir[1], dy or dir[2] },
      projection = cx and "legacy-voxel-project" or "fail-closed-projection",
      pipeline = ctx and ctx.pipeline or "voxel",
      glacier = ow.map and ow.map.id == "KA_HEVO_BLUE_GLACIER_MAZE",
    }
  end

  local function drawFor(game, ow, geometry)
    local profile, mapId = profileFor(game, ow)
    if not profile then return false, "outside" end
    love.graphics.push("all")
    local ok, rendered, path = pcall(drawMask, profile, geometry)
    if not ok or not rendered then
      failClosed(geometry.width, geometry.height, profile)
      path = "fail-closed-error"
      if mod.log and type(mod.log.warn) == "function" then
        mod.log:warn("legacy HEVO visibility failed closed: %s", tostring(rendered))
      end
    end
    love.graphics.pop()
    ow.kaHevoLegacyVisibilityRuntime = {
      contract = V.id, mapId = mapId, kind = profile.kind,
      presentation = V.presentation, projection = geometry.projection,
      renderPath = path, radius = profile.radius,
      outerOpaque = profile.outerOpacity >= 1,
      center = { x = geometry.centerX, y = geometry.centerY },
      cellPixels = geometry.cellPixels,
    }
    return true, path
  end
  V.drawFor = drawFor

  function V.install(game)
    if V.installed then return false, "already installed" end
    local OverworldState = opts.overworld
      or require("src.world.OverworldController")
    local Pipelines = opts.pipelines or require("src.render.Pipelines")
    local Tilt = opts.tilt or require("src.render.Tilt")
    local shared = rawget(OverworldState, "_kaHevoLegacyVisibilityManager")
    if shared then
      shared.game, shared.routes, shared.owner = game, routes, V
      V.manager = shared
      V.installed = true
      return true, "manager-refreshed"
    end
    shared = { game = game, routes = routes, owner = V }
    V.manager = shared

    local baseDrawWorld = assert(OverworldState.drawWorld,
      "legacy HEVO visibility needs OverworldState.drawWorld")
    OverworldState.drawWorld = function(ow, ...)
      local result = { baseDrawWorld(ow, ...) }
      local activeGame = shared.game
      local owner = shared.owner
      local profile = activeGame and owner.profileFor(activeGame, ow)
      if profile and love and love.graphics then
        local renderer = activeGame.renderer
        local pipeline = Pipelines.worldPipeline and Pipelines.worldPipeline()
        if not pipeline and renderer and renderer.worldCanvas then
          local target, geometry
          if Tilt.active and Tilt.active() and renderer.uprightActive
              and renderer.uprightCanvas then
            target = renderer.uprightCanvas
            geometry = owner.tiltGeometry(ow, renderer, Tilt)
          else
            target = renderer.worldCanvas
            geometry = owner.flatGeometry(ow, renderer)
          end
          love.graphics.push("all")
          love.graphics.setCanvas(target)
          owner.drawFor(activeGame, ow, geometry)
          love.graphics.pop()
          love.graphics.setCanvas(renderer.worldCanvas)
        end
      end
      return unpack(result)
    end

    local baseWorldPresent = assert(Pipelines.worldPresent,
      "legacy HEVO visibility needs Pipelines.worldPresent")
    Pipelines.worldPresent = function(canvas, ctx)
      canvas = baseWorldPresent(canvas, ctx)
      local activeGame = shared.game
      local owner = shared.owner
      local ow = activeGame and activeOverworld(activeGame,
        ctx and (ctx.state or ctx.overworld))
      local profile = ow and owner.profileFor(activeGame, ow)
      if not (profile and canvas and love and love.graphics) then return canvas end
      local width, height = canvas:getDimensions()
      local output = shared.pipelineCanvas
      if not output or output:getWidth() ~= width or output:getHeight() ~= height then
        if output and output.release then output:release() end
        local dpi = canvas.getDPIScale and canvas:getDPIScale() or 1
        local ok, made = pcall(love.graphics.newCanvas,
          width, height, { dpiscale = dpi })
        if not ok or not made then
          -- Allocation pressure must not turn into either a crash or an
          -- unmasked world.  The pipeline's finished canvas is writable, so
          -- fold the visibility overlay into it in place and return it.
          love.graphics.push("all")
          love.graphics.setCanvas(canvas)
          owner.drawFor(activeGame, ow,
            owner.pipelineGeometry(activeGame, ow, canvas, ctx))
          love.graphics.pop()
          return canvas
        end
        output = made
        if output.setFilter then output:setFilter("linear", "linear") end
        shared.pipelineCanvas = output
      end
      love.graphics.push("all")
      love.graphics.setCanvas(output)
      love.graphics.clear(0, 0, 0, 1)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(canvas, 0, 0)
      owner.drawFor(activeGame, ow,
        owner.pipelineGeometry(activeGame, ow, canvas, ctx))
      love.graphics.pop()
      return output
    end

    rawset(OverworldState, "_kaHevoLegacyVisibilityManager", shared)
    V.installed = true
    return true, V.presentation
  end

  V.flatGeometry = flatGeometry
  V.tiltGeometry = tiltGeometry
  V.pipelineGeometry = pipelineGeometry

  return V
end
