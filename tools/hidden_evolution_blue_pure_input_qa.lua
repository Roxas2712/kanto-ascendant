-- BLUE release-candidate physical acceptance journey.
--
-- The prerequisite save is produced by hidden_evolution_blue_pure_qa_setup.
-- This driver starts at the title screen and deliberately never calls
-- U.teleport, world:warpTo, a campaign solve/claim API, or mutates puzzle
-- state.  Every route, field move, boulder, ice slide, fall, object and warp
-- after CONTINUE is reached through ordinary START/A/B/D-pad input.
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local Pipelines = require("src.render.Pipelines")
  local Collision = require("src.world.Collision")
  local shotRoot = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing BLUE release traversal outside the immutable package gate")
  local render = os.getenv("BLUE_QA_RENDER") or "2d"
  assert(render == "2d" or render == "voxel", "BLUE_QA_RENDER must be 2d or voxel")
  local targetedSurf = os.getenv("BLUE_QA_TARGETED_SURF") == "1"
  local targetedSharedVisual = os.getenv("BLUE_QA_TARGETED_SHARED_VISUAL") == "1"
  local tracePath = os.getenv("INPUT_TRACE") or (shotRoot .. "/input_trace.txt")
  local inputTrace = assert(io.open(tracePath, "w"))
  local api, blue
  local rendererReceipts = {}

  local function trace(...)
    local row = { "HEVO BLUE INPUT" }
    for i = 1, select("#", ...) do row[#row + 1] = tostring(select(i, ...)) end
    inputTrace:write(table.concat(row, "\t"), "\n")
    inputTrace:flush()
  end

  local function waitOverworld(limit)
    for _ = 1, limit or 720 do
      if game.overworld and game.stack:top() == game.overworld
          and not game.overworld.transitioning then return true end
      U.wait(1)
    end
    return false
  end

  local function dismiss(limit)
    for _ = 1, limit or 360 do
      if waitOverworld(1) then return true end
      U.tap(game, "a")
      U.wait(3)
    end
    error("dialogue/menu did not settle")
  end
  local ChoiceBox = require("src.ui.ChoiceBox")
  local function acceptFissure()
    for _ = 1, 360 do
      local top = game.stack:top()
      if getmetatable(top) == ChoiceBox then
        U.tap(game, "up") -- default is deliberately NO
        U.wait(3)
        U.tap(game, "a")
        U.wait(8)
        return true
      end
      U.tap(game, "a")
      U.wait(3)
    end
    error("BLUE fissure confirmation did not appear")
  end

  local function settleInput(limit)
    for _ = 1, limit or 900 do
      local ow = game.overworld
      if ow and ow.player and not ow.player.moving
          and (ow.player.turnTimer or 0) == 0
          and #(ow.scriptMoves or {}) == 0
          and not ow.transitioning
          and not (blue and blue._sliding)
          and game.stack:top() == ow then return true end
      U.wait(1)
    end
    local ow = game.overworld
    local p = ow and ow.player
    local top = game.stack:top()
    local info = top and type(top.update) == "function" and debug.getinfo(top.update, "S") or nil
    local keys = {}
    if type(top) == "table" then
      for key in pairs(top) do keys[#keys + 1] = tostring(key) end
      table.sort(keys)
    end
    local page = top and top.pages and top.pages[top.pageIndex or 1]
    if type(page) == "table" then page = table.concat(page, " / ") end
    error(("physical input did not settle: map=%s cell=%s,%s moving=%s turn=%s scripts=%s transitioning=%s sliding=%s topIsOw=%s top=%s source=%s keys=%s page=%s")
      :format(tostring(ow and ow.map and ow.map.id), tostring(p and p.cellX),
        tostring(p and p.cellY), tostring(p and p.moving),
        tostring(p and p.turnTimer), tostring(ow and #(ow.scriptMoves or {})),
        tostring(ow and ow.transitioning), tostring(blue and blue._sliding),
        tostring(ow and top == ow), tostring(top), tostring(info and info.short_src),
        table.concat(keys, ","), tostring(page)))
  end

  local function verifyRenderer()
    if render == "voxel" then
      assert(Pipelines.get("voxel"), "DRAMALESS voxel pipeline is not loaded")
      assert(Pipelines.level("voxel") > 0, "DRAMALESS voxel pipeline is OFF")
      if blue and blue.layouts and blue.layouts[game.overworld.map.id] then
        assert(game.overworld.map.def.voxelMode == "FULL",
          game.overworld.map.id .. " is not using the native FULL voxel profile")
        local projected=game.overworld.kaHevoBlueProjectedSight
        assert(projected and projected.x and projected.y
            and projected.cell and projected.cell>0,
          game.overworld.map.id.." has no real DRAMALESS player projection for darkness")
      end
    else
      assert(Pipelines.level("voxel") == 0, "2D acceptance accidentally enabled voxel")
    end
    if blue and blue.layouts and game.overworld
        and blue.layouts[game.overworld.map.id] then
      assert(blue.hasReadableSurfPresentation(game.overworld.player),
        game.overworld.map.id.." lost the native readable SEEL presentation clone")
      local aperture=game.overworld.kaHevoBlueSightRuntime
      assert(aperture and aperture.featherPx>0 and aperture.featherPx<=2,
        game.overworld.map.id.." has no <=2-screen-pixel darkness feather")
      assert(aperture.pipeline==(render=="voxel"),
        game.overworld.map.id.." recorded the wrong darkness projection mode")
    end
  end

  local function shot(name)
    assert(waitOverworld(), "capture overlay did not settle")
    U.tap(game, "b") -- close a location banner through normal input
    U.wait(render == "voxel" and 90 or 24)
    assert(waitOverworld(), "capture field did not settle")
    verifyRenderer()
    local ow = game.overworld
    if blue and ow and blue.layouts and blue.layouts[ow.map.id]
        and not rendererReceipts[ow.map.id] then
      rendererReceipts[ow.map.id] = true
      local sight = ow.kaHevoBlueSightRuntime or {}
      local projected = ow.kaHevoBlueProjectedSight or {}
      trace("renderer-receipt", ow.map.id, render,
        "voxelMode", ow.map.def.voxelMode,
        "pipelineLevel", Pipelines.level("voxel"),
        "featherPx", sight.featherPx,
        "pipeline", sight.pipeline,
        "projectedCell", projected.cell or "flat")
    end
    local path = shotRoot .. "/" .. render .. "/" .. name .. ".png"
    assert(U.shot(game, path), "capture failed: " .. path)
    return path
  end

  -- A compact map legitimately lets the camera sample beyond its authored
  -- block rectangle.  The runtime must fill those samples with its native
  -- CAVERN border, never block $00's solid-white void.  Restrict this pixel
  -- receipt to shared-tunnel captures in both 2D and Voxel: native white
  -- rock highlights are short, while the regression produced viewport-wide
  -- horizontal runs and an almost completely white lower band.
  local function assertNoBlankViewport(path, label)
    -- SHOT_DIR is an absolute host path.  LÖVE's ImageData filename overload
    -- resolves through the game's virtual filesystem and therefore cannot
    -- reopen it directly; bridge the already-flushed PNG bytes explicitly.
    local file = assert(io.open(path, "rb"), label .. " screenshot cannot be reopened")
    local bytes = assert(file:read("*a"), label .. " screenshot bytes are missing")
    file:close()
    local fileData = love.filesystem.newFileData(bytes, "blue-shared-viewport.png")
    local imageData = assert(love.image.newImageData(fileData),
      label .. " screenshot could not be decoded")
    local width, height = imageData:getDimensions()
    local bandTop = math.floor(height * 0.70)
    local blank, bandPixels, longest = 0, 0, 0
    for y = bandTop, height - 1 do
      local run = 0
      for x = 0, width - 1 do
        local r, g, b, a = imageData:getPixel(x, y)
        local isBlank = a >= 0.985 and r >= 0.985 and g >= 0.985 and b >= 0.985
        bandPixels = bandPixels + 1
        if isBlank then
          blank = blank + 1
          run = run + 1
          if run > longest then longest = run end
        else
          run = 0
        end
      end
    end
    local density = blank / math.max(1, bandPixels)
    trace("shared-viewport-receipt", label, width, height,
      "lowerBlankDensity", ("%.4f"):format(density),
      "longestBlankRun", longest, "borderBlock", game.overworld.map.def.borderBlock)
    -- One native metatile is 160 screen pixels at the acceptance scale; the
    -- stale authored $00 filler therefore appeared as a 160x160 white square
    -- even after the outer border was fixed.  Reject that too, while leaving
    -- ample headroom for short white highlights inside CAVERN rock art.
    assert(longest < math.floor(width * 0.125),
      ("%s exposes a %d-pixel blank viewport run"):format(label, longest))
    assert(density < 0.65,
      ("%s lower viewport is %.1f%% blank white"):format(label, density * 100))
    return true
  end

  local function sharedVisualShot(name, label)
    local ow = assert(game.overworld, label .. " has no overworld")
    assert(ow.map.id == "KA_HEVO_TUNNEL_ALL", label .. " is not in the shared tunnel")
    assert(ow.map.def.tileset == "CAVERN", label .. " lost the native CAVERN tileset")
    assert(ow.map.def.borderBlock == 3,
      label .. " does not use native solid CAVERN $03 beyond its compact bounds")
    assert(ow.map.def.voxelMode == "FULL",
      label .. " lost its native FULL DRAMALESS map profile")
    local path = shot(name)
    assertNoBlankViewport(path, label)
    local pipelineLevel = Pipelines.level("voxel")
    assert((render == "voxel" and pipelineLevel > 0)
        or (render == "2d" and pipelineLevel == 0),
      label .. " was captured through the wrong renderer pipeline")
    trace("shared-runtime-receipt", label, render,
      "tileset", ow.map.def.tileset, "voxelMode", ow.map.def.voxelMode,
      "borderBlock", ow.map.def.borderBlock,
      "pipelineLevel", pipelineLevel)
    return path
  end

  local function overlayShot(name)
    U.wait(render == "voxel" and 60 or 18)
    verifyRenderer()
    local path = shotRoot .. "/" .. render .. "/" .. name .. ".png"
    assert(U.shot(game, path), "overlay capture failed: " .. path)
  end

  -- Captures one physical movement frame without waiting for idle or sending
  -- B.  Used only for the authored pre-fall and on-$22 beats while the ice
  -- controller intentionally owns input.
  local function movementShot(name)
    verifyRenderer()
    local path = shotRoot .. "/" .. render .. "/" .. name .. ".png"
    assert(U.shot(game, path), "movement capture failed: " .. path)
  end

  local DIRS = {
    { dx = 1, dy = 0, name = "right" },
    { dx = -1, dy = 0, name = "left" },
    { dx = 0, dy = 1, name = "down" },
    { dx = 0, dy = -1, name = "up" },
  }
  local BY_DIR = {}
  for _, d in ipairs(DIRS) do BY_DIR[d.name] = d end
  local OPPOSITE = { right = "left", left = "right", down = "up", up = "down" }

  local function occupied(ow, x, y, ignore)
    for _, entity in ipairs(ow.entities or {}) do
      if entity ~= ignore and not entity.passable
          and ((entity.cellX == x and entity.cellY == y)
            or (entity.targetX == x and entity.targetY == y)) then
        return entity
      end
    end
    return nil
  end

  local function puzzleFingerprint()
    local root = game.save.modData and game.save.modData.kanto_ascendant or {}
    local run = root.hevo_run or {}
    local state = run.hidden_evolution_blue or {}
    local solved = {}
    for name, value in pairs(state.solved or {}) do
      if value then solved[#solved + 1] = name end
    end
    local switches = {}
    for name, value in pairs(state.switches or {}) do
      if value then switches[#switches + 1] = name end
    end
    table.sort(solved)
    table.sort(switches)
    return table.concat({ tostring(state.sight or 0), table.concat(solved, ","),
      table.concat(switches, ","), tostring(state.cycle or 0) }, "|")
  end

  local function liveState()
    local ow = assert(game.overworld, "missing overworld")
    local p = assert(ow.player, "missing player")
    return { mapId = ow.map.id, x = p.cellX, y = p.cellY,
      facing = p.facing, surfing = p.surfing == true,
      puzzle = puzzleFingerprint() }
  end

  local function stateKey(s)
    return table.concat({ s.mapId, s.x, s.y, s.facing,
      s.surfing and 1 or 0, s.puzzle }, ":")
  end

  local function warpAt(map, x, y)
    for index, warp in ipairs(map.def.warps or {}) do
      if warp.x == x and warp.y == y then return warp, index end
    end
  end

  -- Native hole art occupies a whole 2x2 CAVERN block even though only one
  -- of its four cells is the actual $22 fall trigger.  Production correctly
  -- keeps sliding across the other three cells.  Build the same surface set
  -- from the campaign's declared hole cells rather than assuming that every
  -- non-$22 corner is a dry brake.
  local function glacierSlideSurface(def, x, y)
    local block = blue.cellBlock(def, x, y)
    if block == 21 then return true end
    for key in pairs(blue.holes or {}) do
      local hx, hy = key:match("^(%d+),(%d+)$")
      if block == blue.cellBlock(def, tonumber(hx), tonumber(hy)) then
        return true
      end
    end
    return false
  end

  -- One edge is exactly one D-pad press.  On Glacier this mirrors the
  -- production one-cell slide callback, including occupancy, native holes,
  -- brakes and terminal route warps.  It does not invoke product code.
  local function simulate(state, dirName)
    local ow = game.overworld
    if state.mapId ~= ow.map.id then return nil end
    if state.facing ~= dirName then
      return { mapId = state.mapId, x = state.x, y = state.y,
        facing = dirName, surfing = state.surfing, puzzle = state.puzzle,
        trigger = "turn" }
    end
    local map, d = ow.map, assert(BY_DIR[dirName])
    local x, y = state.x + d.dx, state.y + d.dy
    -- Native CAVERN also owns elevation/tile-pair barriers.  A plain
    -- isWalkableCell test can therefore plan through a rock lip that the real
    -- D-pad correctly refuses.  Ask the exact engine collision contract for
    -- the first player-controlled cell; only the subsequent scripted ice
    -- cells intentionally use BLUE's own slideTarget contract.
    local plannerEntities = {}
    for _, entity in ipairs(ow.entities or {}) do
      if entity ~= ow.player then plannerEntities[#plannerEntities + 1] = entity end
    end
    local mover = { cellX = state.x, cellY = state.y, surfing = state.surfing }
    if not Collision.canMove(map, plannerEntities, mover, dirName) then return nil end
    local walkable, water = map:isWalkableCell(x, y), map:isWaterCell(x, y)
    if not walkable and not (state.surfing and water) then return nil end
    local surfing = state.surfing and not walkable
    local trigger = "step"

    local function terminalAt(cx, cy)
      local routeWarp = warpAt(map, cx, cy)
      if blue.isHoleCell(map.def, cx, cy) then
        local entry = assert(map.def.warps[1], "Glacier has no reset warp")
        return { mapId = state.mapId, x = entry.x, y = entry.y,
          facing = dirName, surfing = false, puzzle = state.puzzle,
          trigger = "fall", holeX = cx, holeY = cy }
      end
      if routeWarp and map:isWarpTileCell(cx, cy) then
        return { mapId = state.mapId, x = cx, y = cy,
          facing = dirName, surfing = surfing, puzzle = state.puzzle,
          trigger = "route-warp", terminalWarp = true }
      end
    end

    local terminal = terminalAt(x, y)
    if terminal then return terminal end
    if map.id == blue.ids.ICE and glacierSlideSurface(map.def, x, y) then
      trigger = "slide"
      for _ = 1, map.def.width * map.def.height * 4 do
        local nx, ny = x + d.dx, y + d.dy
        if not map:inBounds(nx, ny) or occupied(ow, nx, ny, ow.player) then break end
        local nextWalkable = map:isWalkableCell(nx, ny)
        if not nextWalkable then break end
        x, y = nx, ny
        terminal = terminalAt(x, y)
        if terminal then return terminal end
        if not glacierSlideSurface(map.def, x, y) then break end
      end
    end
    return { mapId = state.mapId, x = x, y = y, facing = dirName,
      surfing = surfing, puzzle = state.puzzle, trigger = trigger }
  end

  local function reconstruct(prev, startKey, finishKey)
    local plan = {}
    while finishKey ~= startKey do
      local row = assert(prev[finishKey], "broken physical route predecessor")
      table.insert(plan, 1, row)
      finishKey = row.from
    end
    return plan
  end

  local function planTo(predicate)
    local start = liveState()
    local first = stateKey(start)
    local queue, head, prev = { start }, 1, { [first] = false }
    while queue[head] do
      local here = queue[head]
      head = head + 1
      if predicate(here) then return reconstruct(prev, first, stateKey(here)) end
      for _, d in ipairs(DIRS) do
        local nextState = simulate(here, d.name)
        if nextState and not nextState.terminalWarp then
          local tag = stateKey(nextState)
          if prev[tag] == nil then
            prev[tag] = { from = stateKey(here), dir = d.name, expected = nextState }
            queue[#queue + 1] = nextState
          end
        end
      end
    end
    error("no productive physical route on " .. tostring(start.mapId))
  end

  local function planToTransition(predicate)
    local start = liveState()
    local first = stateKey(start)
    local queue, head, prev = { start }, 1, { [first] = false }
    while queue[head] do
      local here = queue[head]
      head = head + 1
      for _, d in ipairs(DIRS) do
        local nextState = simulate(here, d.name)
        if nextState and predicate(here, d.name, nextState) then
          local plan = reconstruct(prev, first, stateKey(here))
          plan[#plan + 1] = { from = stateKey(here), dir = d.name, expected = nextState }
          return plan
        end
        if nextState and not nextState.terminalWarp then
          local tag = stateKey(nextState)
          if prev[tag] == nil then
            prev[tag] = { from = stateKey(here), dir = d.name, expected = nextState }
            queue[#queue + 1] = nextState
          end
        end
      end
    end
    error("no productive physical transition on " .. tostring(start.mapId))
  end

  local function execute(plan, label)
    for index, row in ipairs(plan) do
      local before = liveState()
      U.tap(game, row.dir)
      settleInput()
      local after = liveState()
      trace(label, index, row.dir, before.mapId, before.x, before.y,
        before.facing, before.surfing, "=>", after.mapId, after.x, after.y,
        after.facing, after.surfing, row.expected.trigger,
        row.expected.holeX or "-", row.expected.holeY or "-")
      assert(after.mapId == row.expected.mapId
          and after.x == row.expected.x and after.y == row.expected.y
          and after.facing == row.expected.facing
          and after.surfing == row.expected.surfing,
        ("planner/product divergence %s #%d: expected %s %d,%d %s surf=%s; got %s %d,%d %s surf=%s")
          :format(label, index, row.expected.mapId, row.expected.x,
            row.expected.y, row.expected.facing, tostring(row.expected.surfing),
            after.mapId, after.x, after.y, after.facing, tostring(after.surfing)))
    end
  end

  local function physicalPathTo(x, y, label)
    execute(planTo(function(s)
      return s.mapId == game.overworld.map.id and s.x == x and s.y == y
    end), label or ("route:" .. x .. "," .. y))
  end

  local function liveObject(text)
    for _, entity in ipairs(game.overworld.entities or {}) do
      if entity.def and entity.def.text == text then return entity end
    end
    error("live object missing: " .. text .. " on " .. game.overworld.map.id)
  end

  local function liveNamedObject(name)
    for _, entity in ipairs(game.overworld.entities or {}) do
      if entity.def and entity.def.name == name then return entity end
    end
    error("live named object missing: " .. name .. " on " .. game.overworld.map.id)
  end

  local function assertSingleStatueView(name)
    local expected="KA_HEVO_BLUE_STATUE_"..name
    local p=assert(game.overworld.player,"statue view has no player")
    local visible={}
    for _,entity in ipairs(game.overworld.entities or {}) do
      if entity.def and entity.def.sprite=="SPRITE_KA_HEVO_QUIZ_STATUE"
          and entity.def.semanticRole=="quiz_statue"
          and math.abs(entity.cellX-p.cellX)<=11
          and math.abs(entity.cellY-p.cellY)<=9 then
        visible[#visible+1]=entity.def.name
      end
    end
    assert(#visible==1 and visible[1]==expected,
      ("%s view contains %d statue-like objects: %s")
        :format(name,#visible,table.concat(visible,",")))
    trace("single-statue-view",name,game.overworld.map.id,p.cellX,p.cellY,
      visible[1])
  end

  local function interact(text)
    local target = liveObject(text)
    local map, chosen = game.overworld.map, nil
    for _, d in ipairs(DIRS) do
      local x, y = target.cellX + d.dx, target.cellY + d.dy
      if map:inBounds(x, y) and map:isWalkableCell(x, y)
          and not occupied(game.overworld, x, y, game.overworld.player) then
        local ok, plan = pcall(planTo, function(s)
          return s.mapId == map.id and s.x == x and s.y == y
        end)
        if ok then
          chosen = { plan = plan, face = OPPOSITE[d.name], x = x, y = y }
          break
        end
      end
    end
    assert(chosen, "no physical object-adjacent route for " .. text)
    execute(chosen.plan, "object:" .. text)
    if game.overworld.player.facing ~= chosen.face then
      U.tap(game, chosen.face)
      settleInput()
      assert(game.overworld.player.cellX == chosen.x and game.overworld.player.cellY == chosen.y,
        "turn toward object moved the player")
    end
    U.tap(game, "a")
    U.wait(10)
  end

  local function useWarp(number, expectedMap)
    local map = game.overworld.map
    local warp = assert(map.def.warps[number], "missing warp " .. number .. " on " .. map.id)
    local chosen
    for _, d in ipairs(DIRS) do
      local x, y = warp.x + d.dx, warp.y + d.dy
      if map:inBounds(x, y) and map:isWalkableCell(x, y)
          and not occupied(game.overworld, x, y, game.overworld.player) then
        local ok, plan = pcall(planTo, function(s)
          return s.mapId == map.id and s.x == x and s.y == y
        end)
        if ok then chosen = { x = x, y = y, dir = OPPOSITE[d.name], plan = plan }; break end
      end
    end
    assert(chosen, "no physical approach for warp " .. map.id .. "#" .. number)
    execute(chosen.plan, "warp-approach:" .. map.id .. "#" .. number)
    local before = liveState()
    U.tap(game, chosen.dir)
    settleInput()
    local after = liveState()
    if after.mapId == before.mapId and after.x == before.x and after.y == before.y then
      U.tap(game, chosen.dir)
      settleInput()
      after = liveState()
    end
    trace("native-warp", map.id, number, before.x, before.y, chosen.dir,
      "=>", after.mapId, after.x, after.y)
    assert(after.mapId == expectedMap,
      ("physical warp %s#%d reached %s, expected %s")
        :format(map.id, number, after.mapId, expectedMap))
    U.wait(render == "voxel" and 100 or 40)
  end

  local function openFieldMove(action)
    assert(waitOverworld(), action .. " did not begin in the overworld")
    U.tap(game, "start")
    U.wait(12)
    local menu = game.stack:top()
    local row
    for i, item in ipairs(menu and menu.items or {}) do
      if tostring(item.label):upper():find("MON", 1, true) then row = i break end
    end
    assert(row, "START menu has no POKEMON row")
    while menu.index ~= row do U.tap(game, "down"); U.wait(2) end
    U.tap(game, "a")
    U.wait(12)
    local party = game.stack:top()
    assert(party and party.index and party.game == game, "POKEMON did not open PartyMenu")
    U.tap(game, "a")
    U.wait(8)
    local sub
    for i, item in ipairs(party.subItems or {}) do
      local label=tostring(item.label or ""):upper()
      local flashName=tostring(game.data.moves.FLASH.name or "FLASH"):upper()
      -- The resistance row deliberately has no vanilla action id.  Match its
      -- live callback plus the localized FLASH/BLITZ label so this D-pad run
      -- still proves the real UI surface instead of invoking product code.
      local resistedFlash=action=="flash"
        and type(item.onSelect)=="function" and item.action==nil
        and (label==flashName or label:find("FLASH",1,true)
          or label:find("BLITZ",1,true))
      if item.action == action or resistedFlash then sub = i break end
    end
    if not sub then
      local rows={}
      for i,item in ipairs(party.subItems or {}) do
        rows[#rows+1]=(i..":"..tostring(item.label).."/"..tostring(item.action)
          .."/onSelect="..tostring(type(item.onSelect)=="function"))
      end
      error(action:upper().." is not available in the real party submenu: "
        ..table.concat(rows," | "))
    end
    while party.subIndex ~= sub do U.tap(game, "down"); U.wait(2) end
    U.tap(game, "a")
    U.wait(8)
    assert(dismiss(480), action .. " did not close to the overworld")
    settleInput()
    trace("field-move", action, game.overworld.map.id,
      game.overworld.player.cellX, game.overworld.player.cellY,
      "strength", tostring(game.overworld.strengthActive),
      "surfing", tostring(game.overworld.player.surfing),
      "flashLit", tostring(game.save.flashLit))
  end

  local function answer(text, downs, label, wantSight, solvedName, solved)
    interact(text)
    for _ = 1, downs do U.tap(game, "down"); U.wait(2) end
    U.tap(game, "a")
    U.wait(10)
    assert(dismiss(), "question did not return to the overworld")
    local state = assert(blue.state(false), "BLUE state missing after " .. label)
    assert(state.sight == wantSight and (state.solved[solvedName] == true) == solved,
      ("BLUE progression mismatch after %s: sight=%s %s=%s")
        :format(label, tostring(state.sight), solvedName,
          tostring(state.solved[solvedName])))
    trace("question", label, "sight", state.sight, solvedName,
      tostring(state.solved[solvedName]))
  end

  local function pushSwitch(name, preShot, postShot)
    local spec = assert(blue.switches[name], "missing switch " .. name)
    assert(game.overworld.map.id == spec.map, name .. " switch on wrong map")
    openFieldMove("strength")
    assert(game.overworld.strengthActive, "STRENGTH did not activate for " .. name)
    local boulder = liveNamedObject(spec.boulder)
    physicalPathTo(boulder.cellX - 1, boulder.cellY, "boulder-pre:" .. name)
    shot(preShot)
    local pushes = 0
    while boulder.cellX < spec.goal.x do
      physicalPathTo(boulder.cellX - 1, boulder.cellY, "boulder-line:" .. name)
      local p = game.overworld.player
      if p.facing ~= "right" then
        local px, py = p.cellX, p.cellY
        U.tap(game, "right"); settleInput()
        assert(p.cellX == px and p.cellY == py and p.facing == "right",
          name .. " boulder-facing turn was not stationary")
      end
      local beforeX = boulder.cellX
      U.tap(game, "right"); settleInput()
      assert(boulder.cellX == beforeX, name .. " moved on the first (arming) attempt")
      U.tap(game, "right"); settleInput()
      assert(boulder.cellX == beforeX + 1,
        name .. " did not move on the second Strength attempt")
      pushes = pushes + 1
    end
    assert(boulder.cellX == spec.goal.x and boulder.cellY == spec.goal.y,
      name .. " boulder missed its authored rune")
    assert(blue.switchSolved(name), name .. " switch did not persist")
    local gateCellX, gateCellY = spec.gate.bx * 2, spec.gate.by * 2
    assert(game.overworld.map:isWalkableCell(gateCellX, gateCellY),
      name .. " gate did not open in the live RuntimeMap")
    trace("strength-switch", name, "pushes", pushes, "goal",
      boulder.cellX, boulder.cellY, "gate", gateCellX, gateCellY)
    shot(postShot)
  end

  local function exerciseReset(text, name, beforeShot, afterShot)
    interact(text)
    overlayShot(beforeShot)
    assert(dismiss(), name .. " reset dialogue did not settle")
    settleInput()
    assert(game.overworld.player.cellX == 3 and game.overworld.player.cellY == 33,
      name .. " reset did not return to the section entrance")
    trace("reset", name, game.overworld.map.id, 3, 33)
    shot(afterShot)
  end

  local function exerciseHole(index, serial)
    local warp = assert(game.overworld.map.def.warps[index], "missing Glacier hole warp " .. index)
    local plan = planToTransition(function(_, _, nextState)
      return nextState.trigger == "fall"
        and nextState.holeX == warp.x and nextState.holeY == warp.y
    end)
    local final = table.remove(plan)
    execute(plan, "hole-approach:" .. index)
    shot(("13_hole_%02d_%d_%d_approach"):format(serial, warp.x, warp.y))
    if serial == 1 then shot("13a_wrong_slide_line_to_native_hole") end
    local before=liveState()
    local delta=assert(BY_DIR[final.dir],"fall plan has no direction")
    local closeX,closeY=warp.x-delta.dx,warp.y-delta.dy
    local closeCaptured,holeCaptured=false,false
    U.tap(game,final.dir)
    for _=1,720 do
      local ow,p=game.overworld,game.overworld and game.overworld.player
      if ow and ow.map and ow.map.id==blue.ids.ICE and p then
        if not closeCaptured and p.cellX==closeX and p.cellY==closeY then
          movementShot(("13b_hole_%02d_%d_%d_closeup"):format(serial,warp.x,warp.y))
          closeCaptured=true
        end
        if not holeCaptured and p.cellX==warp.x and p.cellY==warp.y then
          movementShot(("13c_hole_%02d_%d_%d_on_native_hole"):format(serial,warp.x,warp.y))
          holeCaptured=true
        end
      end
      if ow and ow.map and ow.map.id==blue.ids.ICE and p
          and p.cellX==3 and p.cellY==33 and not p.moving and not blue._sliding then
        break
      end
      U.wait(1)
    end
    settleInput()
    local after=liveState()
    trace("hole-fall:"..index,1,final.dir,before.mapId,before.x,before.y,
      before.facing,before.surfing,"=>",after.mapId,after.x,after.y,
      after.facing,after.surfing,final.expected.trigger,
      final.expected.holeX or "-",final.expected.holeY or "-")
    assert(closeCaptured,"wrong slide never exposed its native fracture close-up")
    assert(holeCaptured,"native $22 fall had no visible player-on-hole beat")
    assert(game.overworld.map.id == blue.ids.ICE
        and game.overworld.player.cellX == 3 and game.overworld.player.cellY == 33,
      "native Glacier hole did not reset to its section entrance")
    shot(("14_hole_%02d_%d_%d_reset"):format(serial, warp.x, warp.y))
    if serial == 1 then shot("14a_wrong_slide_section_reset") end
  end

  local function nativeReload(expectedMap)
    assert(game:writeSave(), "native BLUE save write failed")
    local loaded, recovered = assert(SaveData.load())
    game:restoreSave(loaded, recovered)
    assert(waitOverworld(900), "native BLUE reload did not return to field control")
    assert(game.overworld.map.id == expectedMap,
      "native BLUE reload map mismatch: " .. game.overworld.map.id)
    verifyRenderer()
    trace("native-save-reload", expectedMap, game.overworld.player.cellX,
      game.overworld.player.cellY)
  end

  local function assertReadableSurf(label,expectedFacing)
    local ow,p=assert(game.overworld),assert(game.overworld.player)
    assert(p.surfing, label.." is not a real SURF phase")
    assert(not expectedFacing or p.facing==expectedFacing,
      label.." has wrong SURF facing: "..tostring(p.facing))
    assert(blue and blue.hasReadableSurfPresentation(p),
      label.." lost BLUE's scoped readable SEEL renderer")
    local presentation=assert(blue.surfPresentationState(p),
      label.." has no BLUE surf presentation state")
    local native=assert(game.data.sprites.SPRITE_SEEL,
      label.." cannot resolve native SPRITE_SEEL")
    local clone=assert(p.surfSprite and p.surfSprite.def,
      label.." has no live surf renderer definition")
    assert(p.surfSprite==presentation.clone and p.surfSprite~=presentation.original,
      label.." is not using the isolated presentation clone")
    assert(clone~=native and clone.trueColor==true,
      label.." was collapsed by the dark-map OBJ palette")
    for key,value in pairs(native) do
      assert(clone[key]==value,
        label.." changed native SEEL field "..tostring(key))
    end
    for key,value in pairs(clone) do
      assert(key=="trueColor" or native[key]==value,
        label.." added non-presentation SEEL field "..tostring(key))
    end
    local posed=p:pose()
    assert(posed==p.surfSprite,
      label.." Player:pose did not select the readable surf renderer")
    trace("surf-presentation",label,ow.map.id,p.cellX,p.cellY,p.facing,
      "native",clone.image,clone.frames,"trueColor",clone.trueColor)
    return true
  end

  -- Title CONTINUE is the beginning of the proof.  A migration report, if
  -- present, is acknowledged by the same A input a player uses.
  U.wait(5)
  U.tap(game, "start")
  U.wait(10)
  U.tap(game, "a")
  for _ = 1, 600 do
    if waitOverworld(1) then break end
    U.tap(game, "a")
    U.wait(3)
  end
  assert(waitOverworld(), "CONTINUE did not reach the overworld")
  api = assert(game.mods.exports.kanto_ascendant, "Kanto Ascendant export missing")
  blue = assert(api.hiddenEvolutionCampaign.modules.BLUE, "BLUE campaign API missing")
  assert(api.extendedCharacters.getPlayerCharacter() == "BLUE", "fixture is not BLUE")
  local variant=tostring(os.getenv("HEVO_QA_VARIANT") or "FRESH"):upper()
  assert(variant=="FRESH" or variant=="ALT","invalid BLUE HEVO_QA_VARIANT")
  if variant=="ALT" then
    local origin=assert(game.save.qaHevoAltOrigin,"BLUE ALT migration receipt missing")
    assert(origin.variant=="ALT" and origin.playerCharacter=="BLUE"
        and origin.sourceSha256==os.getenv("KA_SOURCE_SAVE_SHA256")
        and origin.packageGateReceiptSha256
          ==os.getenv("KA_PACKAGE_GATE_RECEIPT_SHA256"),
      "BLUE ALT migration receipt drifted")
    trace("alt-origin",origin.kind,origin.sourceSha256,origin.renderer)
  end
  assert(not blue.hasReadableSurfPresentation(game.overworld.player),
    "BLUE readable surf presentation leaked onto Route 24")
  verifyRenderer()

  -- Route 24 -> shared BLUE shaft -> Threshold.
  assert(game.overworld.map.id == "ROUTE_24", "fixture did not start on Route 24")
  shot("00_route24_hairline_fissure")
  if render == "voxel" then
    local bridge = assert(api.dramalessWallDecalsCompat,
      "DRAMALESS wall-decal package bridge missing")
    assert(bridge.mode == "native" or bridge.mode == "adapter",
      "Voxel wall decals inactive: " .. tostring(bridge.mode))
    if bridge.mode == "adapter" then
      local receipt = assert(bridge.lastDrawn,
        "BLUE Voxel fissure produced no depth-scene draw receipt")
      assert(bridge.drawCount > 0
          and receipt.id == "KA_HEVO_WALL_FISSURE_BLUE"
          and receipt.mapId == "ROUTE_24" and receipt.cellX == 10
          and receipt.cellY == 3 and bridge.lastError == nil,
        "BLUE Voxel fissure receipt lost its five-cell-deeper wall identity")
    end
    trace("wall-decal-receipt", "BLUE", bridge.mode, bridge.drawCount)
  end
  interact("TEXT_KA_HEVO_FISSURE_BLUE")
  acceptFissure()
  assert(dismiss(), "Route 24 fissure transition did not settle")
  assert(game.overworld.map.id == "KA_HEVO_TUNNEL_ALL", "fissure missed shared tunnel")
  if targetedSharedVisual then
    sharedVisualShot("01_shared_tunnel_blue_branch", "real Route24 fissure entry")
    local ow, player = game.overworld, assert(game.overworld.player)
    local returnPad = assert(ow.map.def.warps[2], "shared BLUE return pad missing")
    assert(returnPad.x == 26 and returnPad.y == 22,
      "shared BLUE lower return pad moved")
    assert(player.cellX == 26 and player.cellY == 21
        and math.abs(player.cellX - returnPad.x) + math.abs(player.cellY - returnPad.y) == 1,
      "real fissure entry no longer supplies the lower-pad camera stand")
    -- This second receipt intentionally samples the old 42 camera framing
    -- without pretending that the dungeon was traversed.  The following
    -- useWarp is still ordinary physical D-pad movement onto the native pad.
    trace("visual-sample", "presentation-only", "lower-return-pad-camera",
      ow.map.id, player.cellX, player.cellY, "pad", returnPad.x, returnPad.y,
      "not-a-traversal-proof")
    sharedVisualShot("42_shared_tunnel_return_pad_visual_sample",
      "presentation-only lower return-pad camera")
    useWarp(2, "ROUTE_24")
    assert(not blue.hasReadableSurfPresentation(game.overworld.player),
      "BLUE readable surf clone leaked onto Route 24 in shared visual smoke")
    shot("43_route24_targeted_shared_return")

    interact("TEXT_KA_HEVO_FISSURE_BLUE")
    acceptFissure()
    assert(dismiss(), "Route 24 targeted re-entry did not settle")
    assert(game.overworld.map.id == "KA_HEVO_TUNNEL_ALL",
      "targeted real fissure re-entry missed shared tunnel")
    sharedVisualShot("44_shared_tunnel_reentry", "real Route24 fissure re-entry")
    trace("PASS", render, "targeted-shared-visual", "real-fissure-entry",
      "presentation-only-lower-pad-camera", "physical-return", "real-fissure-reentry",
      "native-border-03", "no-blank-viewport")
    U.log("HEVO BLUE TARGETED SHARED VISUAL PASS", render,
      "real entry -> lower-pad camera sample -> physical return -> real re-entry")
    inputTrace:close()
    love.event.quit(0)
    return
  end
  sharedVisualShot("01_shared_tunnel_blue_branch", "full journey shared entry")
  useWarp(5, blue.ids.THRESHOLD)
  shot("02_threshold_dense_darkness_sight0")
  shot("02a_threshold_sight0_no_banner")

  -- The real Field Kit still offers FLASH, but the authored trial swallows
  -- it with explicit feedback.  Only the five side-arm statues may expand
  -- BLUE's orientation cone.
  assert(game.overworld.dark == true, "Threshold is not natively dark before FLASH")
  local cone0 = assert(game.overworld.kaHevoBlueSight, "BLUE sight cone missing")
  assert(cone0.radius <= 2 and cone0.outerOpacity >= 0.97
      and cone0.innerOpacity >= 0.60,
    "opening sight cone is not a dim one-to-two-cell Rock-Tunnel view")
  openFieldMove("flash")
  assert(game.save.flashLit ~= true and game.overworld.dark == true,
    "FLASH bypassed the BLUE statue-only visibility trial")
  assert(game.overworld.kaHevoBlueSight and game.overworld.kaHevoBlueSight.radius == cone0.radius,
    "ineffective FLASH still changed the BLUE orientation cone")
  shot("03_threshold_after_ineffective_flash")
  useWarp(2, blue.ids.HALL)

  -- Hall: wrong answer recovery, reset, native Strength chokepoint.
  shot("04_hall_loop_pre_puzzle")
  shot("04a_hall_sight0_rock_tunnel")
  interact("TEXT_KA_HEVO_BLUE_STRENGTH")
  overlayShot("05_hall_strength_instruction")
  assert(dismiss(), "Strength instruction did not settle")
  shot("05a_hall_tablet_player_no_halo_sight0")
  answer("TEXT_KA_HEVO_BLUE_STATUE_HALL", 2, "hall-wrong", 0, "HALL", false)
  assertSingleStatueView("HALL")
  shot("06_hall_after_wrong_answer")
  shot("06a_hall_statue1_before_sight0")
  answer("TEXT_KA_HEVO_BLUE_STATUE_HALL", 1, "hall-recovery", 1, "HALL", true)
  shot("07_hall_sight1")
  shot("07a_hall_statue1_after_sight1")
  assertSingleStatueView("HALL")
  shot("07b_hall_statue_sidearm_only")
  exerciseReset("TEXT_KA_HEVO_BLUE_RESET_HALL", "HALL",
    "08_hall_reset_dialogue", "09_hall_after_reset")
  pushSwitch("HALL", "10_hall_boulder_before", "11_hall_boulder_switch_after")
  useWarp(2, blue.ids.ICE)
  assert(not game.overworld.strengthActive, "STRENGTH leaked across the Hall warp")

  -- Glacier: all six native fall cells, real reset, two memory statues, and
  -- the second independent Strength groove.
  shot("12_glacier_entrance")
  interact("TEXT_KA_HEVO_BLUE_FROST_RUNE")
  overlayShot("12a_glacier_rune_instruction")
  assert(dismiss(), "Glacier rune text did not settle")
  interact("TEXT_KA_HEVO_BLUE_SWAMPERTITE_HINT")
  overlayShot("12b_glacier_surf_secret_hint")
  assert(dismiss(), "Glacier secret hint did not settle")
  shot("12b2_glacier_player_item_no_halo_sight1")
  answer("TEXT_KA_HEVO_BLUE_STATUE_ICE_NORTH", 2,
    "ice-north", 2, "ICE_NORTH", true)
  assertSingleStatueView("ICE_NORTH")
  shot("12c_glacier_sight2")
  shot("12c1_ice_north_sidearm_only")
  answer("TEXT_KA_HEVO_BLUE_STATUE_ICE_DEEP", 0,
    "ice-deep", 3, "ICE_DEEP", true)
  assertSingleStatueView("ICE_DEEP")
  shot("12d_glacier_sight3")
  shot("12d1_ice_deep_sidearm_only")
  shot("12e_glacier_contiguous_ice_field_sight3")
  if os.getenv("BLUE_QA_TARGETED_GLACIER") == "1" then
    -- Quota-light visual gate: still navigates from Route 24, invokes FLASH,
    -- solves the Hall and both Glacier statues, then enters a real wrong ice
    -- line and native hole through ordinary input.  The release proof leaves
    -- this unset and continues through all six holes and the complete return.
    exerciseHole(3,1)
    inputTrace:close()
    U.log("HEVO BLUE TARGETED GLACIER PASS",render,
      "sight0/1 -> native frost field -> wrong slide -> hole reset")
    love.event.quit(0)
    return
  end
  if targetedSurf then
    -- Quota-light SURF gate still proves one genuine wrong line and section
    -- reset before continuing physically to the tidal branch.  The complete
    -- release run leaves this unset and traverses all six native fractures.
    exerciseHole(3,1)
  else
    for index = 3, #game.overworld.map.def.warps do
      exerciseHole(index, index - 2)
    end
  end
  exerciseReset("TEXT_KA_HEVO_BLUE_RESET_ICE", "ICE",
    "15_glacier_reset_dialogue", "16_glacier_after_reset")
  pushSwitch("ICE", "17_glacier_boulder_before", "18_glacier_boulder_switch_after")
  useWarp(2, blue.ids.DEPTHS)
  assert(not game.overworld.strengthActive, "STRENGTH leaked across the Glacier warp")

  -- Depths: the western memory teaches the final floor, then the real
  -- reset/Strength groove opens the eastern ascent and its last memory.
  -- SURF remains an optional branch to the isolated SWAMPERTITE island.
  shot("19_depths_tidal_entrance")
  answer("TEXT_KA_HEVO_BLUE_STATUE_DEPTHS_WEST", 1,
    "depths-west", 4, "DEPTHS_WEST", true)
  assertSingleStatueView("DEPTHS_WEST")
  shot("20_depths_sight4")
  shot("20a_depths_west_sidearm_only")
  exerciseReset("TEXT_KA_HEVO_BLUE_RESET_DEPTHS", "DEPTHS",
    "22_depths_reset_dialogue", "23_depths_after_reset")
  pushSwitch("DEPTHS", "24_depths_boulder_before", "25_depths_boulder_switch_after")
  answer("TEXT_KA_HEVO_BLUE_STATUE_DEPTHS_EAST", 2,
    "depths-east", 5, "DEPTHS_EAST", true)
  assertSingleStatueView("DEPTHS_EAST")
  shot("21_depths_sight5")
  shot("21a_depths_east_sidearm_only")

  -- Known native CAVERN shore lips.  Their $15 water-facing cells avoid the
  -- original engine's forbidden $14-water <-> $05-floor tile pair.
  -- Mainland (17,21) faces south into the winding tidal pocket; the island
  -- is deliberately approached from below at (21,31).
  assert(game.overworld.map:isWalkableCell(17, 21)
      and game.overworld.map:isWaterCell(17, 22),
    "mainland Surf departure has drifted")
  physicalPathTo(17, 21, "surf-mainland-departure")
  if game.overworld.player.facing ~= "down" then
    U.tap(game, "down"); settleInput()
  end
  shot("26_depths_surf_departure")
  openFieldMove("surf")
  assert(game.overworld.player.surfing and game.overworld.player.cellX == 17
      and game.overworld.player.cellY == 22, "real SURF did not mount onto water")
  assertReadableSurf("first-water","down")
  shot("27_depths_real_surf_crossing")
  physicalPathTo(17,27,"surf-mid-down")
  assertReadableSurf("mid-water-down","down")
  shot("27a_depths_surf_mid_down")
  physicalPathTo(19,32,"surf-mid-right")
  assertReadableSurf("mid-water-right","right")
  shot("27b_depths_surf_mid_right")
  physicalPathTo(21, 31, "surf-to-secret-island")
  assert(not game.overworld.player.surfing, "secret island did not dismount SURF")
  shot("28_depths_secret_island")
  interact("TEXT_KA_HEVO_BLUE_SWAMPERTITE")
  overlayShot("29_depths_swampertite_claim")
  assert(dismiss(), "SWAMPERTITE claim did not settle")
  assert(api.legacyDungeonAdapter.hasSecret(game.save, "BLUE"),
    "SWAMPERTITE interaction did not reach the persistent secret ledger")

  assert(game.overworld.map:isWalkableCell(21, 31)
      and game.overworld.map:isWaterCell(21, 32),
    "secret-island Surf return has drifted")
  physicalPathTo(21, 31, "surf-island-departure")
  if game.overworld.player.facing ~= "down" then
    U.tap(game, "down"); settleInput()
  end
  openFieldMove("surf")
  assert(game.overworld.player.surfing and game.overworld.player.cellX == 21
      and game.overworld.player.cellY == 32,
    "real SURF did not leave secret island")
  assertReadableSurf("return-first-water","down")
  physicalPathTo(17,27,"surf-return-mid-up")
  assertReadableSurf("mid-water-up","up")
  shot("30a_depths_surf_mid_up")
  physicalPathTo(17, 21, "surf-return-mainland")
  assert(not game.overworld.player.surfing, "mainland did not dismount SURF")
  shot("30_depths_secret_return_mainland")
  nativeReload(blue.ids.DEPTHS)
  assert(api.legacyDungeonAdapter.hasSecret(game.save, "BLUE"),
    "SWAMPERTITE did not survive native save/reload")
  local reloadedBlue = assert(blue.state(false), "BLUE run vanished on native reload")
  assert(reloadedBlue.sight == 5 and reloadedBlue.solved.DEPTHS_EAST
      and reloadedBlue.switches.DEPTHS,
    "BLUE sight/question/Strength state did not survive native reload")
  local depthsGate = blue.switches.DEPTHS.gate
  assert(game.overworld.map:isWalkableCell(depthsGate.bx * 2, depthsGate.by * 2),
    "solved Depths Strength gate was not restamped after native reload")
  shot("31_depths_after_secret_reload")

  -- Shrine reward -> sealed shared room -> matching BLUE return.
  useWarp(2, blue.ids.SHRINE)
  shot("32_shrine_arrival_pre_reward")
  interact("TEXT_KA_HEVO_BLUE_REWARD")
  overlayShot("33_shrine_reward_dialogue")
  assert(dismiss(), "BLUE reward did not settle")
  local persistent = game.save.modData.kanto_ascendant.hevo_persistent
  assert(persistent and persistent.meta and persistent.meta.BLUE == true,
    "BLUE reward did not reach the persistent Legacy ledger")
  shot("34_shrine_reward_recorded")
  useWarp(2, "KA_HEVO_SHARED_SEALED_ANTECHAMBER")
  assert(not blue.hasReadableSurfPresentation(game.overworld.player),
    "BLUE readable surf clone leaked into the shared sealed room")
  shot("35_shared_sealed_antechamber_blue")
  if targetedSurf then
    trace("PASS",render,"targeted-surf","shore","first-water",
      "mid-down","mid-right","island","mid-up","return","clone-restored")
    U.log("HEVO BLUE TARGETED SURF PASS",render,
      "shore -> readable native SEEL -> three mid-water directions -> island -> return -> exit restore")
    inputTrace:close()
    love.event.quit(0)
    return
  end
  interact("TEXT_KA_HEVO_SHARED_SEALED_DOOR")
  overlayShot("36_shared_door_kyogre_blackout")
  assert(dismiss(), "shared sealed-door blackout did not settle")
  do
    local receipt=assert(api.hiddenEvolutionCampaign.modules.shared.handoff(),
      "BLUE final warp emitted no durable character receipt")
    assert(receipt.character=="BLUE" and receipt.seal==true
        and receipt.sourceMap==blue.ids.SHRINE
        and receipt.stone=="SWAMPERTITE"
        and (receipt.stoneStatus=="granted" or receipt.stoneStatus=="claimed")
        and receipt.acknowledged==true,
      "BLUE final receipt lost shrine/stone/door authority")
    assert(api.megaEvolution.hasStone("SWAMPERTITE"),
      "BLUE final chain did not put SWAMPERTITE in the Stone Case")
    local bucket=assert(game.save.modData.kanto_ascendant)
    local gate=assert(bucket[api.legacyJourney.HEVO_GATE_KEY],
      "BLUE final chain created no Legacy Journey gate")
    assert(gate.character=="BLUE" and gate.ready==true
        and gate.doorAcknowledged==true and gate.oakCalled==true
        and gate.pendingCall~=true
        and game.save.flags[api.legacyJourney.HEVO_READY_FLAG]==true
        and game.save.flags[api.legacyJourney.HEVO_OAK_CALLED_FLAG]==true,
      "BLUE final chain did not complete the one-time Oak call")
    local canBegin,owner=api.legacyJourney.canBegin(game.save)
    assert(canBegin==true and owner=="BLUE",
      "BLUE sealed save did not unlock only BLUE's Legacy Journey")
    trace("end-receipt","BLUE",receipt.sourceMap,receipt.stone,
      receipt.stoneStatus,"oak-called","legacy-ready")
  end
  useWarp(2, blue.ids.SHRINE)
  shot("37_shrine_return_from_shared_room")

  -- Full physical return chain, then one real re-entry through the same
  -- wall fissure and BLUE shaft.  This is the final persistence proof.
  useWarp(1, blue.ids.DEPTHS)
  shot("38_depths_return_route")
  useWarp(1, blue.ids.ICE)
  shot("39_glacier_return_route")
  useWarp(1, blue.ids.HALL)
  shot("40_hall_return_route")
  useWarp(1, blue.ids.THRESHOLD)
  shot("41_threshold_return_route")
  useWarp(1, "KA_HEVO_TUNNEL_ALL")
  sharedVisualShot("42_shared_tunnel_return_pad", "full journey lower return pad")
  useWarp(2, "ROUTE_24")
  assert(not blue.hasReadableSurfPresentation(game.overworld.player),
    "BLUE readable surf clone leaked onto Route 24 after full return")
  shot("43_route24_full_return")

  interact("TEXT_KA_HEVO_FISSURE_BLUE")
  acceptFissure()
  assert(dismiss(), "Route 24 re-entry did not settle")
  assert(game.overworld.map.id == "KA_HEVO_TUNNEL_ALL", "re-entry missed shared tunnel")
  sharedVisualShot("44_shared_tunnel_reentry", "full journey real fissure re-entry")
  useWarp(5, blue.ids.THRESHOLD)
  local finalState = assert(blue.state(false), "BLUE state missing on re-entry")
  assert(finalState.sight == 5 and finalState.solved.HALL
      and finalState.solved.ICE_NORTH and finalState.solved.ICE_DEEP
      and finalState.solved.DEPTHS_WEST and finalState.solved.DEPTHS_EAST
      and finalState.switches.HALL and finalState.switches.ICE
      and finalState.switches.DEPTHS,
    "BLUE puzzle state did not survive full return/re-entry")
  assert(game.overworld.kaHevoBlueSight
      and game.overworld.kaHevoBlueSight.level == 5,
    "final sight profile was not restored on re-entry")
  shot("45_threshold_reentry_persistent_sight5")

  trace("PASS", render, "Route24", "shared-blue", "five-maps",
    "flash", "three-strength", "six-holes", "surf-secret", "reward",
    "shared-door", "full-return", "reentry")
  local result=assert(io.open(shotRoot.."/driver_result.txt","wb"),
    "could not write BLUE full-path package receipt")
  result:write("status=PASS\n")
  result:write("scope=HEVO-FULL-PATH\n")
  result:write("character=BLUE\n")
  result:write("edition=",tostring(os.getenv("POKEPORT_VERSION")),"\n")
  result:write("renderer=",render,"\n")
  result:write("variant=",variant,"\n")
  result:write("stone=SWAMPERTITE\n")
  result:write("native_save_reload=1/1\n")
  result:write("reentry=1/1\n")
  result:write("fail=0\n")
  result:close()
  U.log("HEVO BLUE PACKAGE END RECEIPT",variant,"SWAMPERTITE",
    "oak-called","legacy-ready","native-reload","reentry")
  U.log("HEVO BLUE PURE INPUT PASS", render,
    "Route24 -> BLUE shaft -> five maps -> shared room -> Route24 -> re-entry")
  inputTrace:close()
  love.event.quit(0)
end
