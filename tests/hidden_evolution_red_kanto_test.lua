-- Focused product contract for the Gen-I RED trial.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD pointing at the RC worktree.
package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local redFile = assert(io.open(root .. "/hidden_evolution_red_path.lua", "rb"))
local redSource = assert(redFile:read("*a"))
redFile:close()
local driverFile = assert(io.open(root .. "/tools/hidden_evolution_red_input_e2e.lua", "rb"))
local driverSource = assert(driverFile:read("*a"))
driverFile:close()
local setupFile = assert(io.open(root .. "/tools/hidden_evolution_red_input_qa_setup.lua", "rb"))
local setupSource = assert(setupFile:read("*a"))
setupFile:close()
local Data = require("src.core.Data")
Data:load()
local RuntimeMap = require("src.world.Map")
local Collision = require("src.world.Collision")
Collision.load(Data)

local function registry(base)
  local r = { values = {}, base = base or {} }
  function r:get(id) return self.values[id] or self.base[id] end
  function r:register(id, value)
    assert(not self.values[id], "duplicate " .. tostring(id))
    self.values[id] = value
    return value
  end
  function r:patch(id, value) self.values[id] = value end
  return r
end

local saved = {}
local darkPatch
local eventHandlers = {}
local mod = {
  path = root,
  save = {
    get = function(_, key) return saved[key] end,
    set = function(_, key, value) saved[key] = value end,
  },
  events = { on = function(_, name, handler) eventHandlers[name] = handler end },
  content = {
    maps = registry(), tilesets = registry(Data.tilesets), sprites = registry(),
    text = registry(), text_pointers = { patch = function() end },
    encounters = registry(), map_scripts = registry(), map_songs = registry(),
    field = { patch = function(_, id, value)
      if id == "darkMaps" then darkPatch = value end
    end },
  },
}

local function copy(value)
  if type(value) ~= "table" then return value end
  local out = {}
  for key, child in pairs(value) do out[copy(key)] = copy(child) end
  return out
end

local finalSecret, persistedAtFinalize
local adapter = {
  finalize = function()
    saved.hevo_run.dungeonLegacy = saved.hevo_run.dungeonLegacy
      or { seals = {}, reentered = {} }
    saved.hevo_run.dungeonLegacy.seals.RED = true
    -- This is the exact durable boundary in the real adapter: its seal is in
    -- the save, while red.complete has not yet set red.completed.
    persistedAtFinalize = copy(saved.hevo_run)
    return true, "granted"
  end,
  claimSecret = function(_, payload) finalSecret = payload return true, "granted" end,
}
local activeCharacter = "RED"
local red = assert(loadfile(root .. "/hidden_evolution_red_path.lua"))()(mod, {
  activeCharacter = function() return activeCharacter end,
  -- Mirrors extendedCharacters' real presentation fallback. A raw FUTURE
  -- record below must still fail closed before this normalized RED is read.
  characters = { getPlayerCharacter = function() return "RED" end },
  legacyDungeonAdapter = adapter,
})
saved.hevo_run={}
local emptyRedRoot=saved.hevo_run
local emptyRedReport=red.completionProgress({})
assert(emptyRedReport.statues==0 and emptyRedReport.boulders.A==false
    and next(emptyRedRoot)==nil and saved.hevo_run==emptyRedRoot,
  "RED completion report created/normalized missing run state")
saved.hevo_run=nil
red.register()

-- Official pre-6.5 saves have no extended-character record and must resolve
-- to RED consistently with Aster, the fissure and the dungeon adapter.  A
-- present BLUE/future-invalid record remains authoritative and fails closed.
activeCharacter = nil
saved.extended_characters = nil
assert(red.activeCharacter({save={}})=="RED" and red.isRed({save={}}),
  "legacy save without a character record did not migrate to RED")
finalSecret=nil
local legacyClaim,legacyWhy=red.claimMega({save={}})
assert(legacyClaim and legacyWhy=="granted"
    and finalSecret and finalSecret.character=="RED"
    and finalSecret.stone=="BLAZIKENITE",
  "legacy RED could not use the per-character final Mega-stone claim")
saved.extended_characters = {player_character="BLUE"}
assert(red.activeCharacter({save={}})=="BLUE" and not red.isRed({save={}}),
  "explicit BLUE identity was overwritten by legacy RED fallback")
saved.extended_characters = {player_character="FUTURE"}
assert(red.activeCharacter({save={}})==nil and not red.isRed({save={}}),
  "invalid present identity did not fail closed")
saved.extended_characters = nil
activeCharacter = "RED"

assert(red.TILESET == "CAVERN", "RED must use the native CAVERN tileset")
assert(not mod.content.tilesets.values.KA_HEVO_RED_BASALT,
  "the rejected private basalt atlas must not be registered")

local ids = {
  red.IDS.upper, red.IDS.abyss, red.IDS.recovery, red.IDS.lower, red.IDS.shrine,
}
local dark = {}
for _, id in ipairs(assert(darkPatch and darkPatch.maps and darkPatch.maps.__append,
    "RED did not append its maps to field.darkMaps")) do dark[id] = true end
for _, id in ipairs(ids) do
  assert(dark[id], id .. " is missing from the native dark-map contract")
  assert(mod.content.map_songs:get(id) == "Music_KA_DeepEvolution",
    id .. " can inherit music from the previously visited map")
end

-- The final RED stair looked valid to the old route BFS because that helper
-- only checked destination walkability.  Native CAVERN also rejects several
-- elevation tile pairs; prove the exact south-to-north player step itself.
do
  local def=assert(red.byId[red.IDS.shrine])
  local map=RuntimeMap.new(def,assert(Data.tilesets.CAVERN))
  local ok,why=Collision.canMove(map,{},
    {cellX=red.END_WARP.x,cellY=red.END_WARP.y+1,surfing=false},"up")
  assert(ok,("RED final stair cannot be entered physically: %s -> %s (%s)")
    :format(tostring(map:cellTile(red.END_WARP.x,red.END_WARP.y+1)),
      tostring(map:cellTile(red.END_WARP.x,red.END_WARP.y)),tostring(why)))
end

local function passable(map, x, y)
  return map:inBounds(x, y)
    and (map:isWalkableCell(x, y) or map:isWaterCell(x, y))
end

local function reaches(map, start, goal)
  local queue, seen, head = { { start.x, start.y } }, {}, 1
  seen[start.x .. ":" .. start.y] = true
  while queue[head] do
    local at = queue[head]; head = head + 1
    if at[1] == goal.x and at[2] == goal.y then return true end
    for _, step in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
      local x, y = at[1] + step[1], at[2] + step[2]
      local key = x .. ":" .. y
      if not seen[key] and passable(map, x, y) then
        seen[key] = true
        queue[#queue + 1] = { x, y }
      end
    end
  end
  return false
end

local DIRS = {
  { "right", 1, 0 }, { "left", -1, 0 },
  { "down", 0, 1 }, { "up", 0, -1 },
}

local function collisionDistances(map, start)
  local queue = { { start.x, start.y } }
  local distance = { [start.x .. ":" .. start.y] = 0 }
  local head = 1
  while queue[head] do
    local at = queue[head]; head = head + 1
    local from = distance[at[1] .. ":" .. at[2]]
    for _, step in ipairs(DIRS) do
      local mover = { cellX=at[1], cellY=at[2], surfing=false }
      local allowed = Collision.canMove(map, {}, mover, step[1])
      local x, y = at[1] + step[2], at[2] + step[3]
      local key = x .. ":" .. y
      if allowed and distance[key] == nil then
        distance[key] = from + 1
        queue[#queue + 1] = { x, y }
      end
    end
  end
  return distance
end

local function adjacentDistance(distance, x, y)
  local best
  for _, step in ipairs(DIRS) do
    local value = distance[(x + step[2]) .. ":" .. (y + step[3])]
    if value ~= nil and (best == nil or value < best) then best = value end
  end
  return best
end

local function qualityMetrics(map, excludeWater)
  local function open(x, y)
    if not (map:inBounds(x, y) and map:isWalkableCell(x, y)) then return false end
    -- LOWER's $32 shore is deliberately both walkable and surf-aware.  Only
    -- the actual $14 lake cells are excluded from its corridor-quality ratio.
    return not (excludeWater and map:cellTile(x, y) == 0x14)
  end
  local cells, narrow, junctions, edges = 0, 0, 0, 0
  local maxHorizontal, maxVertical = 0, 0
  for y=0,map.heightCells-1 do
    local wide = 0
    for x=0,map.widthCells-1 do
      if open(x,y) and open(x,y+1) then
        wide = wide + 1; maxHorizontal = math.max(maxHorizontal, wide)
      else
        wide = 0
      end
      if open(x,y) then
        local north, south = open(x,y-1), open(x,y+1)
        local west, east = open(x-1,y), open(x+1,y)
        local degree = (north and 1 or 0) + (south and 1 or 0)
          + (west and 1 or 0) + (east and 1 or 0)
        cells, edges = cells + 1, edges + degree
        if (not north and not south) or (not west and not east) then
          narrow = narrow + 1
        end
        if degree >= 3 then junctions = junctions + 1 end
      end
    end
  end
  for x=0,map.widthCells-1 do
    local wide = 0
    for y=0,map.heightCells-1 do
      if open(x,y) and open(x+1,y) then
        wide = wide + 1; maxVertical = math.max(maxVertical, wide)
      else
        wide = 0
      end
    end
  end
  return {
    cells=cells, narrow=narrow, narrowRatio=narrow/cells,
    maxWide=math.max(maxHorizontal,maxVertical),
    junctions=junctions, cycles=edges/2-cells+1,
  }
end

for _, id in ipairs(ids) do
  local def = assert(red.byId[id], "missing RED map " .. id)
  assert(def.tileset == "CAVERN" and def.voxelMode == "FULL",
    id .. " is not native Kanto/Voxel FULL")
  assert(def.voxelCells == nil and def.voxelCellRuns == nil,
    id .. " still carries private positional voxel geometry")
  assert(#def.blocks == def.width * def.height, id .. " has a malformed block grid")
  for _, block in ipairs(def.blocks) do
    assert(Data.tilesets.CAVERN.blocks[block + 1],
      id .. " uses a block outside the shipped CAVERN atlas: " .. tostring(block))
  end
  assert(dark[id], id .. " is not a real native dark map")
  local map = RuntimeMap.new(def, assert(Data.tilesets.CAVERN))
  assert(#def.warps >= 2, id .. " needs an entrance and exit")
  for index, warp in ipairs(def.warps) do
    assert(map:inBounds(warp.x, warp.y), id .. " warp " .. index .. " is out of bounds")
    assert(map:isWarpTileCell(warp.x, warp.y),
      id .. " warp " .. index .. " lacks a native CAVERN trigger")
  end
  assert(reaches(map, def.warps[1], def.warps[2]),
    id .. " has no physical entrance-to-exit route (walking/Surf)")
  for _, object in ipairs(def.objects or {}) do
    assert(map:inBounds(object.x, object.y), id .. " object is out of bounds: " .. object.name)
    assert(reaches(map, def.warps[1], object),
      id .. " object is not physically reachable: " .. object.name)
  end
end

local qualityTargets = {
  [red.IDS.upper] = { narrow=0.25, tortuosity=1.20 },
  [red.IDS.abyss] = { narrow=0.25, tortuosity=1.20 },
  [red.IDS.recovery] = { narrow=0.25 },
  [red.IDS.lower] = { narrow=0.15 },
  [red.IDS.shrine] = { narrow=0.25, tortuosity=1.20 },
}
for _, id in ipairs(ids) do
  local def = red.byId[id]
  local map = RuntimeMap.new(def, Data.tilesets.CAVERN)
  local metrics = qualityMetrics(map, id == red.IDS.lower)
  local target = qualityTargets[id]
  assert(metrics.narrowRatio >= target.narrow,
    ("%s is still a broad raster: %.1f%% narrow, need %.1f%%")
      :format(id, metrics.narrowRatio*100, target.narrow*100))
  assert(metrics.maxWide <= 6,
    id .. " has a parallel two-cell corridor longer than a six-cell bay")
  assert(metrics.cycles >= 1 and metrics.junctions >= 2,
    id .. " has no real reconnecting route/decision")
  if id ~= red.IDS.lower then
    local distance = collisionDistances(map, def.warps[1])
    for index, warp in ipairs(def.warps) do
      assert(distance[warp.x .. ":" .. warp.y] ~= nil,
        id .. " warp " .. index .. " is behind a real CAVERN elevation seam")
    end
    for _, object in ipairs(def.objects or {}) do
      assert(adjacentDistance(distance, object.x, object.y) ~= nil,
        id .. " has no collision-valid interaction side for " .. object.name)
    end
    if target.tortuosity then
      local goal = def.warps[2]
      local length = assert(distance[goal.x .. ":" .. goal.y])
      local manhattan = math.abs(goal.x-def.warps[1].x)
        + math.abs(goal.y-def.warps[1].y)
      assert(length/manhattan >= target.tortuosity,
        ("%s route is too direct: %d/%d = %.2f")
          :format(id,length,manhattan,length/manhattan))
    end
  end
  print(("RED_QUALITY %s narrow=%.1f%% maxWide=%d cycles=%d")
    :format(id,metrics.narrowRatio*100,metrics.maxWide,metrics.cycles))
end

local previous
for level=0,5 do
  local profile = red.sightProfile(level,false)
  assert(profile.radius > 0 and profile.opacity >= 0 and profile.opacity <= 1,
    "invalid RED sight profile " .. level)
  if previous then
    assert(profile.radius > previous.radius and profile.opacity <= previous.opacity
        and profile.innerOpacity < previous.innerOpacity,
      "RED sight progression must reveal the map monotonically")
  end
  previous = profile
end
local blind = red.sightProfile(0,false)
local firstSight = red.sightProfile(1,false)
local secondSight = red.sightProfile(2,false)
local solved = red.sightProfile(5,false)
local complete = red.sightProfile(5,true)
assert(blind.radius >= 1.75 and blind.radius <= 2.0 and blind.opacity == 1.0,
  "RED Sight 0 must be an almost-black 1.75-2.0-cell core")
assert(blind.coreRadius > 0 and blind.coreRadius <= 0.9
    and blind.coneSlope > 0 and blind.coneSlope <= 0.38,
  "RED Sight 0 must use a narrow facing-aware tunnel cone")
assert(blind.featherPx > 0 and blind.featherPx <= 2.0,
  "RED Sight 0 mask must limit antialiasing to two screen pixels")
assert(blind.innerOpacity >= 0.25 and blind.innerOpacity <= 0.35
    and blind.innerOpacity < blind.opacity,
  "RED Sight 0 keyhole must remain clearly readable inside its opaque exterior")
for level=0,4 do
  assert(red.sightProfile(level,false).opacity == 1.0,
    "RED incomplete early stage leaks distant statue/item silhouettes: "..level)
end
assert(firstSight.radius - blind.radius <= 1.0 and firstSight.opacity == 1.0,
  "RED first answer reveals too much of the labyrinth")
assert(secondSight.radius - firstSight.radius <= 1.25
    and secondSight.opacity == 1.0,
  "RED second answer reveals too much of the labyrinth")
assert(solved.radius <= 10 and solved.opacity >= 0.85,
  "RED fifth sight stage reveals too much before completion")
assert(solved.innerOpacity <= 0.22,
  "RED statues do not brighten the inner tunnel cone progressively")
assert(complete.radius > solved.radius and complete.opacity < solved.opacity,
  "RED completion exception did not visibly release the darkness")
local shader=assert(red.sightShaderSource,"RED post-composite shader source missing")
for _,token in ipairs({"bayer","checker","fract","floor","step","mod","discard"}) do
  assert(not shader:lower():match("%f[%a]"..token.."%f[%A]"),
    "RED sight mask quantizes/dithers its edge via "..token)
end
assert(shader:find("coreSigned",1,true)
    and shader:find("coneSigned",1,true)
    and shader:find("min(coreSigned,coneSigned)",1,true),
  "RED sight mask lacks the hard analytic core/cone union")
assert(shader:find("smoothstep(-min(sightFeatherPx,2.0),0.0",1,true)
    and redSource:find('shader:send("sightFeatherPx"',1,true),
  "RED sight mask lacks its <=2-screen-pixel antialiasing gate")
assert(shader:find("mix(sightInnerOpacity,sightOpacity,edge)",1,true),
  "RED sight interior is not uniformly dimmed before the black exterior")
assert(redSource:find("if not sight and M.byId[liveMapId] then",1,true)
    and redSource:find("ow.kaHevoRedSight=sight",1,true),
  "a direct/imported RED-floor load can remain permanently bright")
assert(redSource:find('love.graphics.stencil(function()',1,true)
    and redSource:find('love.graphics.circle("fill",cx,cy,core)',1,true)
    and redSource:find('love.graphics.polygon("fill"',1,true)
    and redSource:find('love.graphics.setStencilTest("notequal",1)',1,true),
  "RED shader failure no longer retains a real keyhole aperture")

local expectedWarps = {
  [red.IDS.upper]={{3,33},{45,3},{12,22},{26,18},{36,12}},
  [red.IDS.abyss]={{3,33},{41,5},{10,24},{18,20},{28,14},{38,10}},
  [red.IDS.recovery]={{3,33},{45,5},{11,27},{19,23},{29,17},{37,13}},
  [red.IDS.lower]={{3,33},{39,7}},
  [red.IDS.shrine]={{3,33},{39,5}},
}
local expectedObjects = {
  [red.IDS.upper]={
    KA_RED_BOULDER_A={13,29},KA_RED_BOULDER_B={21,25},KA_RED_BOULDER_C={31,17},
    KA_RED_STATUE_1={3,6},KA_RED_STATUE_2={29,4},
    KA_RED_STRENGTH_TABLET={11,31},KA_RED_FALL_TABLET={25,23},
    KA_RED_RESET_UPPER={5,33},
  },
  [red.IDS.abyss]={KA_RED_STATUE_3={11,4},KA_RED_STATUE_4={27,10},
    KA_RED_EMBER_HINT={37,11},KA_RED_RESET_ABYSS={5,31}},
  [red.IDS.recovery]={KA_RED_BLAZIKENITE_SECRET={33,9},
    KA_RED_SECRET_HINT={27,15},KA_RED_RESET_REFUGE={5,31}},
  [red.IDS.lower]={KA_RED_FALLEN_A={11,25},KA_RED_FALLEN_B={25,19},
    KA_RED_FALLEN_C={37,15},KA_RED_STATUE_5={5,6},
    KA_RED_SURF_TABLET={13,23},KA_RED_RESET_LOWER={5,31}},
  [red.IDS.shrine]={KA_RED_RESEARCH_CACHE={31,13},
    KA_RED_GROUDON_SEAL={35,11},KA_RED_RETREAT_MARK={7,29}},
}
for id, points in pairs(expectedWarps) do
  local def=red.byId[id]
  assert(#def.warps==#points,id.." warp count drifted during the narrow redesign")
  for index,point in ipairs(points) do
    assert(def.warps[index].x==point[1] and def.warps[index].y==point[2],
      id.." warp "..index.." moved during the narrow redesign")
  end
  local found={};for _,object in ipairs(def.objects) do found[object.name]=object end
  for name,point in pairs(expectedObjects[id]) do
    local object=assert(found[name],id.." lost object "..name)
    assert(object.x==point[1] and object.y==point[2],name.." moved during the redesign")
  end
end

-- A statue is not "hidden" merely because its coordinates changed.  Model
-- the exact live collision graph: every unsolved visible object occupies its
-- cell, including the other statues and the three Strength boulders.  Each
-- memory must have one interaction side at the blind end of a long turning
-- branch, remain reachable in product order, and allow a physical retrace to
-- the last main junction.  This catches both camera-visible road signs and
-- the earlier false PASS where a live object sealed the only approach.
local function objectEntities(def, absent)
  local entities={}
  absent=absent or {}
  for _,object in ipairs(def.objects or {}) do
    if not object.hidden and not absent[object.name] then
      entities[#entities+1]={
        cellX=object.x,cellY=object.y,passable=object.passable,
        name=object.name,
      }
    end
  end
  return entities
end

local function liveGraphDistances(map,entities,start,surfing)
  local startKey=start.x..":"..start.y
  local queue={{start.x,start.y}}
  local distance={[startKey]=0}
  local previous={}
  local head=1
  while queue[head] do
    local at=queue[head];head=head+1
    local atKey=at[1]..":"..at[2]
    for _,step in ipairs(DIRS) do
      local mover={cellX=at[1],cellY=at[2],surfing=surfing==true}
      local allowed=Collision.canMove(map,entities,mover,step[1])
      local x,y=at[1]+step[2],at[2]+step[3]
      local nextKey=x..":"..y
      if allowed and distance[nextKey]==nil then
        distance[nextKey]=distance[atKey]+1
        previous[nextKey]=atKey
        queue[#queue+1]={x,y}
      end
    end
  end
  return distance,previous
end

local function liveDegree(map,entities,x,y,surfing)
  local degree=0
  for _,step in ipairs(DIRS) do
    local mover={cellX=x,cellY=y,surfing=surfing==true}
    if Collision.canMove(map,entities,mover,step[1]) then degree=degree+1 end
  end
  return degree
end

local function liveNeighbors(map,entities,x,y,surfing)
  local neighbors={}
  for _,step in ipairs(DIRS) do
    local mover={cellX=x,cellY=y,surfing=surfing==true}
    if Collision.canMove(map,entities,mover,step[1]) then
      neighbors[#neighbors+1]={x=x+step[2],y=y+step[3]}
    end
  end
  return neighbors
end

local function assertHiddenBranch(spec)
  local def=red.byId[spec.map]
  local map=RuntimeMap.new(def,Data.tilesets.CAVERN)
  local entities=objectEntities(def)
  local object
  for _,candidate in ipairs(def.objects) do
    if candidate.name==spec.name then object=candidate;break end
  end
  assert(object,"missing branch statue "..spec.name)

  local access=liveGraphDistances(map,entities,spec.access)
  local sides={}
  for _,step in ipairs(DIRS) do
    local x,y=object.x+step[2],object.y+step[3]
    local value=access[x..":"..y]
    if value~=nil then sides[#sides+1]={x=x,y=y,distance=value} end
  end
  assert(#sides==1,
    spec.name.." is not in a one-sided cul-de-sac (interaction sides="..#sides..")")
  local approach=sides[1]
  assert(liveDegree(map,entities,approach.x,approach.y)==1,
    spec.name.." approach is not the collision-graph dead end")

  -- Trace outward from the degree-one pocket until the collision graph, not
  -- the source route declaration, says we have reached the last junction.
  -- This tolerates a native metatile placing that junction one cell either
  -- side of the authored anchor while still rejecting any early shortcut.
  local path={{x=approach.x,y=approach.y}}
  local previousKey
  local current=path[1]
  local junction
  for _=1,map.widthCells*map.heightCells do
    local degree=liveDegree(map,entities,current.x,current.y)
    if degree>=3 then junction=current;break end
    local nextCells={}
    for _,candidate in ipairs(liveNeighbors(map,entities,current.x,current.y)) do
      local candidateKey=candidate.x..":"..candidate.y
      if candidateKey~=previousKey then nextCells[#nextCells+1]=candidate end
    end
    assert(#nextCells==1,
      spec.name.." branch is not a simple retraceable cul-de-sac at "
        ..current.x..","..current.y)
    previousKey=current.x..":"..current.y
    current=nextCells[1]
    path[#path+1]=current
  end
  assert(junction,spec.name.." branch never reaches a main-route junction")
  local depth=#path-1
  assert(depth>=spec.minimum,
    ("%s branch is only %d steps from its last junction %d,%d; need %d")
      :format(spec.name,depth,junction.x,junction.y,spec.minimum))
  local anchorDelta=math.abs(junction.x-spec.junction.x)
    + math.abs(junction.y-spec.junction.y)
  assert(anchorDelta<=2,
    spec.name.." hidden branch attached to an unintended junction at "
      ..junction.x..","..junction.y)
  local junctionKey=junction.x..":"..junction.y
  assert(access[junctionKey]~=nil,
    spec.name.." junction is not reachable with every unsolved object live")

  local turns,lastDx,lastDy=0
  for index=2,#path do
    local a,b=path[index-1],path[index]
    local dx,dy=b.x-a.x,b.y-a.y
    if lastDx and (dx~=lastDx or dy~=lastDy) then turns=turns+1 end
    lastDx,lastDy=dx,dy
  end
  assert(turns>=4,
    spec.name.." branch has too few turns to hide the statue from the main route")

  local back=liveGraphDistances(map,entities,{x=approach.x,y=approach.y})
  assert(back[junctionKey]~=nil,
    spec.name.." interaction pocket has no live-state physical return")
  print(("RED_BRANCH %s depth=%d turns=%d junction=%d,%d approach=%d,%d")
    :format(spec.name,depth,turns,junction.x,junction.y,approach.x,approach.y))
  return {
    depth=depth,turns=turns,junction={x=junction.x,y=junction.y},
    approach={x=approach.x,y=approach.y},map=spec.map,
  }
end

local branchProofs={
  {map=red.IDS.upper,name="KA_RED_STATUE_1",access={x=3,y=33},
    junction={x=9,y=27},minimum=10},
  {map=red.IDS.upper,name="KA_RED_STATUE_2",access={x=3,y=33},
    junction={x=23,y=19},minimum=10},
  {map=red.IDS.abyss,name="KA_RED_STATUE_3",access={x=3,y=33},
    junction={x=7,y=21},minimum=10},
  {map=red.IDS.abyss,name="KA_RED_STATUE_4",access={x=3,y=33},
    junction={x=35,y=7},minimum=10},
  {map=red.IDS.lower,name="KA_RED_STATUE_5",access={x=31,y=17},
    junction={x=31,y=11},minimum=10},
}
local branchEvidence={}
for _,spec in ipairs(branchProofs) do
  branchEvidence[spec.name]=assertHiddenBranch(spec)
end

-- Same-floor statues must never share a gameplay view.  Check both the
-- authored light radius and the native 160x144 world viewport, then prove
-- that collision distance is long and winding rather than merely Euclidean
-- padding through a wall.
local function assertSeparatedStatues(mapId,first,second)
  local a=assert(branchEvidence[first]);local b=assert(branchEvidence[second])
  local def=red.byId[mapId]
  local objects={}
  for _,object in ipairs(def.objects) do objects[object.name]=object end
  local oa,ob=assert(objects[first]),assert(objects[second])
  local dx,dy=math.abs(oa.x-ob.x),math.abs(oa.y-ob.y)
  local euclidean=math.sqrt(dx*dx+dy*dy)
  local maximumIncompleteSight=red.sightProfile(5,false).radius
  assert(euclidean>maximumIncompleteSight+2,
    first.." and "..second.." can enter the same incomplete sight mask")
  assert(dx>11 or dy>10,
    first.." and "..second.." can share the native gameplay viewport")
  local runtime=RuntimeMap.new(def,Data.tilesets.CAVERN)
  local distance=liveGraphDistances(runtime,objectEntities(def),a.approach)
  local graphDistance=assert(distance[b.approach.x..":"..b.approach.y],
    "same-floor statues are collision-disconnected")
  assert(graphDistance>=40,
    first.." and "..second.." are visually separated but their route is too short")
  print(("RED_STATUE_SEPARATION %s/%s dx=%d dy=%d euclidean=%.1f route=%d")
    :format(first,second,dx,dy,euclidean,graphDistance))
end
assertSeparatedStatues(red.IDS.upper,"KA_RED_STATUE_1","KA_RED_STATUE_2")
assertSeparatedStatues(red.IDS.abyss,"KA_RED_STATUE_3","KA_RED_STATUE_4")

-- Only the five memories may render as the distinct quiz statue. Instructions,
-- resets, hints, the seal and retreat mark are transparent passable map
-- anchors over native CAVERN landmarks; tangible rewards use the native
-- Poke-Ball role.  This prevents any screenshot from reading a tablet as a
-- second statue without adding a glow/outline to the real memories.
local visibleQuizStatues=0
local physicalAnchors={
  KA_RED_STRENGTH_TABLET=true, KA_RED_FALL_TABLET=true,
  KA_RED_SURF_TABLET=true, KA_RED_GROUDON_SEAL=true,
}
for _,id in ipairs(ids) do
  for _,object in ipairs(red.byId[id].objects or {}) do
    local statue=object.name:match("^KA_RED_STATUE_[1-5]$")~=nil
    local visibleQuiz=object.sprite=="SPRITE_KA_HEVO_QUIZ_STATUE"
      and object.renderMode~="none"
    if statue then
      assert(visibleQuiz and object.semanticRole=="quiz_statue"
          and object.passable~=true,
        object.name.." lost its unique blocking statue role")
      visibleQuizStatues=visibleQuizStatues+1
    else
      assert(not visibleQuiz and object.semanticRole~="quiz_statue",
        object.name.." still renders as a second RED statue")
      if object.renderMode=="none" then
        assert(object.sprite=="SPRITE_KA_HEVO_FISSURE_ANCHOR",
          object.name.." does not use the renderer-independent transparent anchor")
        if physicalAnchors[object.name] then
          assert(object.passable==false,
            object.name.." must stop the player in front of its visible native landmark")
        else
          assert(object.passable==true,
            object.name.." is an invisible occupancy blocker")
        end
      end
    end
    assert(type(object.text)=="string" and object.text~="",
      object.name.." can emit a map-label/nil interaction warning")
  end
end
assert(visibleQuizStatues==5,"RED must expose exactly five visible quiz statues")
local recoveryObjects={}
for _,object in ipairs(red.byId[red.IDS.recovery].objects) do
  recoveryObjects[object.name]=object
end
local shrineObjects={}
for _,object in ipairs(red.byId[red.IDS.shrine].objects) do
  shrineObjects[object.name]=object
end
assert(recoveryObjects.KA_RED_BLAZIKENITE_SECRET.sprite=="SPRITE_POKE_BALL",
  "RED Mega secret lacks the native tangible-item role")
assert(shrineObjects.KA_RED_RESEARCH_CACHE.sprite=="SPRITE_POKE_BALL",
  "RED shrine cache lacks the native tangible-item role")

local anchorLandmarks={
  {red.IDS.upper,"KA_RED_STRENGTH_TABLET",5,15,108,"stone dais"},
  {red.IDS.upper,"KA_RED_FALL_TABLET",12,11,57,"recessed ledge"},
  {red.IDS.upper,"KA_RED_RESET_UPPER",2,16,21,"ember reset rune"},
  {red.IDS.abyss,"KA_RED_EMBER_HINT",18,5,21,"ember hint rune"},
  {red.IDS.abyss,"KA_RED_RESET_ABYSS",2,15,21,"ember reset rune"},
  {red.IDS.recovery,"KA_RED_SECRET_HINT",13,7,21,"ember hint rune"},
  {red.IDS.recovery,"KA_RED_RESET_REFUGE",2,15,21,"ember reset rune"},
  {red.IDS.lower,"KA_RED_SURF_TABLET",6,11,118,"native black water"},
  {red.IDS.lower,"KA_RED_RESET_LOWER",2,15,21,"ember reset rune"},
  {red.IDS.shrine,"KA_RED_GROUDON_SEAL",17,5,108,"carved seal dais"},
  {red.IDS.shrine,"KA_RED_RETREAT_MARK",3,14,21,"ember retreat rune"},
}
for _,row in ipairs(anchorLandmarks) do
  assert(red.blockAt(row[1],row[3],row[4])==row[5],
    row[2].." lost its visible native "..row[6])
end

local upper = RuntimeMap.new(red.byId[red.IDS.upper], Data.tilesets.CAVERN)
local upperDef = red.byId[red.IDS.upper]
local upperObjects = {};for _,object in ipairs(upperDef.objects) do
  upperObjects[object.name]=object
end
local function liveUpperDistances(hidden)
  local entities={}
  for _,object in ipairs(upperDef.objects) do
    if not (hidden and hidden[object.name]) then
      entities[#entities+1]={cellX=object.x,cellY=object.y,
        passable=object.passable,name=object.name}
    end
  end
  local start=upperDef.warps[1]
  local queue={{start.x,start.y}}
  local distance={[start.x..":"..start.y]=0}
  local head=1
  while queue[head] do
    local at=queue[head];head=head+1
    local from=distance[at[1]..":"..at[2]]
    for _,step in ipairs(DIRS) do
      local allowed=Collision.canMove(upper,entities,
        {cellX=at[1],cellY=at[2],surfing=false},step[1])
      local x,y=at[1]+step[2],at[2]+step[3];local key=x..":"..y
      if allowed and distance[key]==nil then
        distance[key]=from+1;queue[#queue+1]={x,y}
      end
    end
  end
  return distance
end
local function liveApproach(distance,name)
  local object=assert(upperObjects[name],"missing live-state object "..name)
  return adjacentDistance(distance,object.x,object.y)
end

-- Product order, not an empty-map approximation: both questions are asked
-- before STRENGTH, then A is pushed/reset/re-pushed before B and C.  Every
-- other visible NPC remains a real blocking entity throughout the proof.
local untouched=liveUpperDistances({})
for _,name in ipairs({"KA_RED_STATUE_1","KA_RED_STATUE_2",
    "KA_RED_STRENGTH_TABLET","KA_RED_FALL_TABLET","KA_RED_RESET_UPPER"}) do
  assert(liveApproach(untouched,name)~=nil,
    name.." has no approach with all unsolved UPPER objects visible")
end
assert(untouched["12:29"]~=nil,"RED cannot stand behind boulder A initially")
local afterA=liveUpperDistances({KA_RED_BOULDER_A=true})
assert(afterA["21:26"]~=nil,"RED cannot stand behind boulder B after A")
assert(liveApproach(afterA,"KA_RED_RESET_UPPER")~=nil,
  "RED cannot reach the fair reset after solving A")
local afterAB=liveUpperDistances({KA_RED_BOULDER_A=true,KA_RED_BOULDER_B=true})
assert(afterAB["30:17"]~=nil,"RED cannot stand behind boulder C after A/B")
local afterABC=liveUpperDistances({KA_RED_BOULDER_A=true,KA_RED_BOULDER_B=true,
  KA_RED_BOULDER_C=true})
for index,warp in ipairs(upperDef.warps) do
  assert(afterABC[warp.x..":"..warp.y]~=nil,
    "RED UPPER warp "..index.." is blocked by remaining live NPCs after A/B/C")
end
for _, cell in ipairs({ {19,29}, {21,19}, {37,17} }) do
  assert(upper:warpPadOrHoleAt(cell[1], cell[2]) == "hole",
    "RED Strength socket is not a visible native hole at " .. cell[1] .. "," .. cell[2])
  assert(not upper:warpAtCell(cell[1], cell[2]),
    "RED Strength socket must not drop the player like a traversal chasm")
end
for _, object in ipairs(red.byId[red.IDS.upper].objects) do
  if object.name:match("KA_RED_BOULDER_") then
    assert(object.sprite == "SPRITE_BOULDER" and object.pushable == true,
      object.name .. " is not a native Strength boulder")
  end
end

-- A Strength lane is not safe merely because every destination cell is
-- nominally walkable.  Native CAVERN also has directional elevation-pair
-- collisions; prove the player can follow each rock cell-for-cell until the
-- visible socket instead of leaving a pushed boulder beyond an impassable
-- seam.
local function assertPushLane(sx, sy, dir, steps, label)
  local delta = assert(Collision.DELTA[dir])
  local px, py = sx, sy
  for step=1,steps-1 do
    local mover = { cellX=px, cellY=py, surfing=false }
    local ok, why = Collision.canMove(upper, {}, mover, dir)
    assert(ok, ("%s player cannot follow push step %d (%s)"):format(
      label, step, tostring(why)))
    px, py = px + delta[1], py + delta[2]
  end
  local socketX, socketY = sx + delta[1] * (steps + 1),
                           sy + delta[2] * (steps + 1)
  assert(upper:warpPadOrHoleAt(socketX, socketY) == "hole",
    label .. " does not end in its native visible socket")
end
assertPushLane(12,29,"right",6,"RED boulder A")
assertPushLane(21,26,"up",6,"RED boulder B")
assertPushLane(30,17,"right",6,"RED boulder C")

local cavernWaterAuthority=Data.tilesets.CAVERN.waterTiles
local cavernShoreAuthority=Data.tilesets.CAVERN.shoreTiles
local lower = RuntimeMap.new(red.byId[red.IDS.lower], Data.tilesets.CAVERN)
assert(lower.def.tileset=="CAVERN" and lower.tileset.id=="CAVERN",
  "RED LOWER stopped using the exact native CAVERN authority")
local upperShoreProbe=RuntimeMap.new(red.byId[red.IDS.upper],Data.tilesets.CAVERN)
local rejected, rejectedWhy=red.applyRuntimeShore(upperShoreProbe)
assert(not rejected and rejectedWhy=="map" and not upperShoreProbe.waterTiles[32],
  "RED's local shore authority leaked onto another RED CAVERN floor")
local shoreApplied,shoreWhy=red.applyRuntimeShore(lower)
assert(shoreApplied, "RED LOWER local shore authority failed: "..tostring(shoreWhy))
assert(lower.waterTiles[20] and lower.waterTiles[32],
  "RED LOWER does not retain native water plus its local $20 shore")
assert(Data.tilesets.CAVERN.waterTiles==cavernWaterAuthority
    and Data.tilesets.CAVERN.shoreTiles==cavernShoreAuthority,
  "RED LOWER mutated the global CAVERN tileset")
assert(red.blockAt(red.IDS.lower,8,12)==43,"RED southern one-cell ledge join moved")
for x=9,13 do assert(red.blockAt(red.IDS.lower,x,12)==29,
  "RED southern one-cell ledge segment moved at block "..x) end
assert(red.blockAt(red.IDS.lower,14,12)==60
    and red.blockAt(red.IDS.lower,15,12)==39
    and red.blockAt(red.IDS.lower,15,8)==39
    and red.blockAt(red.IDS.lower,15,7)==60
    and red.blockAt(red.IDS.lower,16,7)==25,
  "RED's proven native CAVERN shore chain drifted")
local function walks(fromX,fromY,toX,toY)
  local q,seen,head={{fromX,fromY}},{[fromX..":"..fromY]=true},1
  while q[head] do
    local at=q[head];head=head+1
    if at[1]==toX and at[2]==toY then return true end
    for _,row in ipairs({{"right",1,0},{"left",-1,0},{"down",0,1},{"up",0,-1}}) do
      local mover={cellX=at[1],cellY=at[2],surfing=false}
      local ok=Collision.canMove(lower,{},mover,row[1])
      local nx,ny=at[1]+row[2],at[2]+row[3];local key=nx..":"..ny
      if ok and not seen[key] then seen[key]=true;q[#q+1]={nx,ny} end
    end
  end
  return false
end
assert(walks(3,33,31,24),"RED lower floor has no real walking route to its Surf shore")
local swimmer={cellX=31,cellY=24,surfing=true}
for y=23,17,-1 do
  local ok,why=Collision.canMove(lower,{},swimmer,"up")
  assert(ok,("RED Surf channel blocks at y=%d (%s)"):format(y,tostring(why)))
  swimmer.cellY=y
end
assert(lower:isWalkableCell(31,17) and lower:isWaterCell(31,17),
  "RED Surf channel does not end on a canonical walkable shore")
assert(walks(31,17,39,7),"RED northern shore has no real walking route to the shrine warp")

-- Release-scale traversal evidence.  Distances below are conservative
-- shortest collision paths after the Strength boulders have been solved;
-- actual play is longer because pushing/resetting, questions and optional
-- recoverable falls add steps.  The mandatory tour preserves statue order
-- and includes LOWER's seven-cell Surf crossing plus the complete SHRINE.
local function distanceBetween(map,entities,from,to,surfing,label)
  local distance=liveGraphDistances(map,entities,from,surfing)
  return assert(distance[to.x..":"..to.y],label.." is collision-disconnected")
end

local maps={}
for _,id in ipairs(ids) do
  maps[id]=RuntimeMap.new(red.byId[id],Data.tilesets.CAVERN)
end
local upperSolvedAbsent={
  KA_RED_BOULDER_A=true,KA_RED_BOULDER_B=true,KA_RED_BOULDER_C=true,
}
local upperEntities=objectEntities(red.byId[red.IDS.upper],upperSolvedAbsent)
local abyssEntities=objectEntities(red.byId[red.IDS.abyss])
local recoveryEntities=objectEntities(red.byId[red.IDS.recovery])
local lowerEntities=objectEntities(red.byId[red.IDS.lower])
local shrineEntities=objectEntities(red.byId[red.IDS.shrine])

local entryExit={
  [red.IDS.upper]=distanceBetween(maps[red.IDS.upper],upperEntities,
    {x=3,y=33},{x=45,y=3},false,"RED UPPER entry-exit"),
  [red.IDS.abyss]=distanceBetween(maps[red.IDS.abyss],abyssEntities,
    {x=3,y=33},{x=41,y=5},false,"RED ABYSS entry-exit"),
  [red.IDS.recovery]=distanceBetween(maps[red.IDS.recovery],recoveryEntities,
    {x=3,y=33},{x=45,y=5},false,"RED RECOVERY entry-exit"),
  [red.IDS.shrine]=distanceBetween(maps[red.IDS.shrine],shrineEntities,
    {x=3,y=33},{x=39,y=5},false,"RED SHRINE entry-exit"),
}
local lowerSouth=distanceBetween(lower,lowerEntities,
  {x=3,y=33},{x=31,y=24},false,"RED LOWER entry-south-shore")
local lowerNorth=distanceBetween(lower,lowerEntities,
  {x=31,y=17},{x=39,y=7},false,"RED LOWER north-shore-exit")
entryExit[red.IDS.lower]=lowerSouth+7+lowerNorth

for _,id in ipairs(ids) do
  local def=red.byId[id]
  assert(def.width==24 and def.height==18
      and maps[id].widthCells==48 and maps[id].heightCells==36,
    id.." no longer has the authored 24x18-block / 48x36-cell scale")
  assert(entryExit[id]>=60,id.." solved entry-exit spine is too short")
  print(("RED_SCALE %s blocks=%dx%d cells=%dx%d entryExit=%d")
    :format(id,def.width,def.height,maps[id].widthCells,
      maps[id].heightCells,entryExit[id]))
end

local s1=branchEvidence.KA_RED_STATUE_1.approach
local s2=branchEvidence.KA_RED_STATUE_2.approach
local s3=branchEvidence.KA_RED_STATUE_3.approach
local s4=branchEvidence.KA_RED_STATUE_4.approach
local s5=branchEvidence.KA_RED_STATUE_5.approach
local upperTour=distanceBetween(maps[red.IDS.upper],upperEntities,
    {x=3,y=33},s1,false,"RED entry-statue1")
  +distanceBetween(maps[red.IDS.upper],upperEntities,
    s1,s2,false,"RED statue1-statue2")
  +distanceBetween(maps[red.IDS.upper],upperEntities,
    s2,{x=45,y=3},false,"RED statue2-upper-exit")
local abyssTour=distanceBetween(maps[red.IDS.abyss],abyssEntities,
    {x=3,y=33},s3,false,"RED abyss-entry-statue3")
  +distanceBetween(maps[red.IDS.abyss],abyssEntities,
    s3,s4,false,"RED statue3-statue4")
  +distanceBetween(maps[red.IDS.abyss],abyssEntities,
    s4,{x=41,y=5},false,"RED statue4-abyss-exit")
local lowerTour=lowerSouth+7
  +distanceBetween(lower,lowerEntities,{x=31,y=17},s5,false,
    "RED north-shore-statue5")
  +distanceBetween(lower,lowerEntities,s5,{x=39,y=7},false,
    "RED statue5-lower-exit")
local shrineTour=entryExit[red.IDS.shrine]
local mandatoryTour=upperTour+abyssTour+lowerTour+shrineTour
assert(mandatoryTour>=500,
  "RED five-statue minimum tour is too small for a release-scale labyrinth")
local statue5Finale=distanceBetween(lower,lowerEntities,s5,{x=39,y=7},false,
    "RED statue5-lower-finale")+shrineTour
assert(statue5Finale>40,
  "RED statue5 does not leave a substantial lower route plus full shrine")
assert(#red.byId[red.IDS.upper].warps-2>=2
    and #red.byId[red.IDS.abyss].warps-2>=2,
  "RED lacks two or more recoverable false fall decisions between memories")
print(("RED_TOUR upper=%d abyss=%d lower=%d shrine=%d mandatory=%d statue5Finale=%d falseFalls=%d")
  :format(upperTour,abyssTour,lowerTour,shrineTour,mandatoryTour,
    statue5Finale,(#red.byId[red.IDS.upper].warps-2)
      +(#red.byId[red.IDS.abyss].warps-2)))

-- Final release traversal is deliberately stronger than a map-definition
-- proof.  Its only fixture placement is the real Route-22 wall approach;
-- after CONTINUE the same driver physically covers every branch in 2D and
-- Voxel.  Guard the high-value itinerary against later QA shortcuts.
assert(setupSource:find('"ROUTE_22", 35, 2, "up"',1,true)
    and setupSource:find("Route-22 fissure",1,true),
  "RED full-run fixture no longer starts at the real Route-22 fissure")
assert(driverSource:find('interact("KA_HEVO_FISSURE_RED")',1,true)
    and driverSource:find('game.overworld.map.id=="KA_HEVO_TUNNEL_ALL"',1,true),
  "RED full-run no longer enters the shared tunnel through the real fissure")
assert(driverSource:find("if before.facing~=choice.face then",1,true)
    and driverSource:find("moved onto its interaction anchor",1,true),
  "RED full-run can step through passable metadata before pressing A")
for _,name in ipairs({"KA_RED_STATUE_1","KA_RED_STATUE_2","KA_RED_STATUE_3",
    "KA_RED_STATUE_4","KA_RED_STATUE_5"}) do
  assert(driverSource:find('statueShot("'..name..'"',1,true),
    "RED full-run lacks a single-statue niche capture for "..name)
end
for index=3,5 do
  assert(driverSource:find("fallToRecovery("..index..",",1,true),
    "RED full-run omits upper recoverable fall warp "..index)
end
assert(driverSource:find("for index=3,6 do",1,true),
  "RED full-run omits one or more Abyss recoverable fall warps")
assert(driverSource:find("b.A==true and b.B==true and b.C==true",1,true),
  "RED full-run lacks the three-Strength-socket state gate")
assert(driverSource:find("lowerAfterStatue5>=40",1,true)
    and driverSource:find("shrineAfterStatue5>=40",1,true),
  "RED full-run does not prove a long post-Statue-5 finale")
assert(driverSource:find("permanentItems.BLAZIKENITE==true",1,true)
    and driverSource:find('reload("KA_HEVO_RED_RECOVERY")',1,true)
    and driverSource:find('reload("ROUTE_22")',1,true),
  "RED full-run lacks its secret/final native save-reload gates")
assert(driverSource:find('shot("17_shared_reentry_after_reload")',1,true)
    and driverSource:find('shot("18_route22_return_after_reentry")',1,true),
  "RED full-run lacks physical completed re-entry and second Route-22 return")
assert(driverSource:find("Pipelines.worldPresent=function",1,true)
    and driverSource:find("receipt.serial>beforeReceipt",1,true)
    and driverSource:find("receipt.mapId==game.overworld.map.id",1,true)
    and driverSource:find('log("voxel-receipt"',1,true),
  "RED Voxel captures lack a fresh same-map DRAMALESS worldPresent receipt")
assert(not driverSource:find(":warpTo",1,true)
    and not driverSource:find("setPosition",1,true),
  "RED full-run contains a direct world-position shortcut")

saved.hevo_run = { red = { sight = 5, boulders = { A=true, B=true, C=true } } }
assert(red.canEnterShrine({}), "completed RED mechanics do not open the shrine")
local redRoot,redState,redBoulders=saved.hevo_run,saved.hevo_run.red,
  saved.hevo_run.red.boulders
redState.floorLights={UPPER=true};redState.hiddenMegaCache=true
local redReport=red.completionProgress({})
assert(redReport.statues==5 and redReport.boulders.A
    and redReport.boulders.B and redReport.boulders.C
    and redReport.floorLights==nil and redReport.hiddenMegaCache==nil
    and saved.hevo_run==redRoot and redRoot.red==redState
    and redState.boulders==redBoulders,
  "RED completion report mutated state or included optional discoveries")
for _,missing in ipairs({"A","B","C"}) do
  redBoulders.A,redBoulders.B,redBoulders.C=true,true,true
  redBoulders[missing]=false
  local report=red.completionProgress({})
  assert(report.boulders[missing]==false,
    "RED report masked missing boulder "..missing)
end
redBoulders.A,redBoulders.B,redBoulders.C=true,true,true

-- WorldAPI reloads the active map after an object visibility change.  Prove
-- that RED's map.entered reconciliation converges instead of recursively
-- toggling the same value forever (the real render driver caught this P0).
local runtimeGame = { save = { modData = { kanto_ascendant = {
  hidden_evolution = { runs = { RED = { sight=0, boulders={} } } },
} }, flags = {} } }
local runtimeUpper = {
  id = red.IDS.upper,
}
local runtimeLower = RuntimeMap.new(red.byId[red.IDS.lower],Data.tilesets.CAVERN)
-- Simulate exact stock 0.1.90 even when this test runs on an engine that
-- already consumes map.def.shoreTiles.
runtimeLower.waterTiles[32]=nil
local activeId, toggles = red.IDS.lower, 0
local runtimeOverworld = {
  map = runtimeLower, player = { cellX=3, cellY=33, facing="up" },
}
mod.world = {
  overworld = function() return runtimeOverworld end,
  toggleObject = function(_, mapId, name, visible)
    toggles = toggles + 1
    assert(toggles < 12, "RED map.entered object reconciliation recursed")
    local save = runtimeGame.save
    save.objectToggles = save.objectToggles or {}
    save.objectToggles[mapId] = save.objectToggles[mapId] or {}
    save.objectToggles[mapId][name] = visible and true or false
    if mapId == activeId then eventHandlers["map.entered"]({ mapId=mapId }) end
    return true
  end,
}
red.install(runtimeGame)
assert(runtimeLower.waterTiles[32],
  "RED hot install did not repair the already-live stock LOWER instance")
assert(eventHandlers["map.entered"], "RED map.entered handler missing")
runtimeOverworld.map=runtimeUpper
activeId=red.IDS.upper
eventHandlers["map.entered"]({ mapId=activeId })
assert(toggles == 6, "RED initial object reconciliation should change six objects once")
assert(runtimeOverworld.kaHevoRedSight.radius == solved.radius
    and runtimeOverworld.kaHevoRedSight.opacity == solved.opacity,
  "RED map entry did not restore the dense fifth-stage profile")
eventHandlers["map.entered"]({ mapId=activeId })
assert(toggles == 6, "RED repeated map.entered must be idempotent")

-- Every stock lifecycle that can replace the live Map instance must restore
-- the same local shore without relying on the newer engine's def override.
local toggleAuthority=mod.world.toggleObject
mod.world.toggleObject=function() return true end
runtimeOverworld.map=runtimeLower
activeId=red.IDS.lower
for _,row in ipairs({
    {"map.entered",{mapId=red.IDS.lower,map=runtimeLower}},
    {"map.reloaded",{mapId=red.IDS.lower,reason="test"}},
    {"save.loaded",{save=runtimeGame.save}},
}) do
  runtimeLower.waterTiles[32]=nil
  assert(eventHandlers[row[1]],"RED lifecycle handler missing: "..row[1])
  eventHandlers[row[1]](row[2])
  assert(runtimeLower.waterTiles[32],
    "RED lifecycle did not restore LOWER shore: "..row[1])
end
mod.world.toggleObject=toggleAuthority
runtimeOverworld.map=runtimeUpper
activeId=red.IDS.upper
assert(red.complete({save={}}), "RED reward finalizes through the adapter")
assert(saved.hevo_run.red.completed==true,
  "RED live completion marker was not set")
saved.hevo_run=persistedAtFinalize
assert(saved.hevo_run.red.completed~=true,
  "RED persistence fixture accidentally captured the post-save marker")
assert(red.run({},true).completed==true,
  "RED final seal cannot recover its last-chance branch after reload")
eventHandlers["map.entered"]({ mapId=activeId })
assert(runtimeOverworld.kaHevoRedSight.radius == complete.radius
    and runtimeOverworld.kaHevoRedSight.opacity == complete.opacity,
  "RED completed-map entry did not restore the release profile")

-- The authored recovery-cache remains the search reward.  If it was missed,
-- the final carved seal provides one last explicit, idempotent claim before
-- the shared black door instead of silently auto-granting on completion.
local oldTextBox=package.loaded["src.render.TextBox"]
local finalMessage,directSealCalls
package.loaded["src.render.TextBox"]={new=function(_,message,done)
  finalMessage=message;return {done=done}
end}
local finalGame={save={},stack={push=function() end}}
red.finalizeEndSeal=function(requestGame)
  assert(requestGame==finalGame,"RED end seal changed game authority")
  directSealCalls=(directSealCalls or 0)+1
  return true,{character="RED",seal=true,stoneStatus="granted"},"granted"
end
mod.content.map_scripts:get(red.IDS.shrine).talk.TEXT_KA_RED_GROUDON(
  finalGame,nil,nil,function() end)
package.loaded["src.render.TextBox"]=oldTextBox
assert(directSealCalls==1,
  "RED visible end seal bypassed the canonical durable-handoff seam")
assert(type(finalMessage)=="string" and finalMessage:find("BLAZIKENITE",1,true),
  "RED final seal does not explain the secured Mega stone")
print("hidden_evolution_red_kanto_test: PASS (5 maps)")
if love and love.event then love.event.quit(0) end
