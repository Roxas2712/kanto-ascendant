-- Per-floor light stones for the ten authored Hidden-Evolution visibility
-- floors: RED's upper floor plus BLUE/GREEN's thresholds and the deeper
-- character-specific trials.
--
-- The five character-specific quiz statues remain the puzzle/gate authority.
-- These stones are a separate, save-local presentation contract: every real
-- visibility floor owns three independently activatable lights, while recovery
-- and shrine maps own none.  No route-global quiz progress is ever
-- migrated into this state; an old save therefore starts each floor at stage 0.

return function(mod, opts)
  opts = opts or {}
  local L = { registered = false, installed = false, version = 1 }
  local routes = assert(opts.routes, "HEVO floor lights need route modules")

  -- Coordinates are authored solid relic cells.  All 30 sit on native dry
  -- floor, outside warp/object cells and at the blind end of an optional side
  -- branch.  Activating one therefore asks the player to leave the shortest
  -- entry-to-exit route and retrace a readable spur; none is a free roadside
  -- switch.  The player talks from a neighboring cell because the stone is
  -- deliberately tangible and must never become a walk-through decoration.
  local rows = {
    { owner="RED", key="upper", map="KA_HEVO_RED_UPPER",
      stones={{16,33},{20,18},{44,12}} },
    { owner="RED", key="abyss", map="KA_HEVO_RED_ABYSS",
      stones={{20,27},{30,19},{30,7}} },
    { owner="RED", key="lower", map="KA_HEVO_RED_LOWER",
      stones={{16,33},{26,15},{34,9}} },
    { owner="BLUE", key="threshold", map="KA_HEVO_BLUE_FROST_THRESHOLD",
      stones={{2,22},{18,11},{33,6}} },
    { owner="BLUE", key="hall", map="KA_HEVO_BLUE_FROST_HALL",
      stones={{8,23},{16,18},{35,9}} },
    { owner="BLUE", key="ice", map="KA_HEVO_BLUE_GLACIER_MAZE",
      stones={{13,33},{9,17},{37,7}} },
    { owner="BLUE", key="depths", map="KA_HEVO_BLUE_TIDAL_DEPTHS",
      stones={{6,35},{32,24},{34,6}} },
    { owner="GREEN", key="threshold", map="KA_HEVO_GREEN_THRESHOLD",
      stones={{2,29},{26,22},{32,5}} },
    { owner="GREEN", key="grove", map="KA_HEVO_GREEN_GROVE",
      stones={{18,29},{38,23},{42,11}} },
    { owner="GREEN", key="mist", map="KA_HEVO_GREEN_MIST",
      stones={{2,30},{27,26},{56,13}} },
  }
  L.FLOORS, L.byMap, L.byObject, L.byText = rows, {}, {}, {}
  for _, floor in ipairs(rows) do
    L.byMap[floor.map] = floor
    for index, point in ipairs(floor.stones) do
      local suffix=(floor.owner.."_"..floor.key.."_"..index):upper()
      local stone={owner=floor.owner,map=floor.map,index=index,
        x=point[1],y=point[2],name="KA_HEVO_FLOOR_LIGHT_"..suffix,
        text="TEXT_KA_HEVO_FLOOR_LIGHT_"..suffix}
      floor.stones[index]=stone
      L.byObject[stone.name],L.byText[stone.text]=stone,stone
    end
  end

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  local function resolved(value)
    if value == nil then return nil, false end
    value=type(value)=="string" and value:upper() or nil
    return value and ({RED=true,BLUE=true,GREEN=true})[value] and value or nil,true
  end

  -- A present raw slot record is authoritative, including malformed/future
  -- identities.  Public helpers are consulted only when that raw record is
  -- genuinely absent; legacy pre-6.5 saves then retain their canonical RED.
  function L.character(game)
    local save=type(game and game.save)=="table" and game.save or nil
    local modData=save and type(save.modData)=="table" and save.modData
    local identity,present
    if modData then
      local rawBucket=modData[mod.id]
      if rawBucket~=nil and type(rawBucket)~="table" then return nil end
      local bucket=type(rawBucket)=="table" and rawBucket or nil
      identity=bucket and bucket.extended_characters or nil
      present=identity~=nil
    elseif mod.save and type(mod.save.get)=="function" then
      identity=mod.save:get("extended_characters")
      present=identity~=nil
    end
    if present then
      if type(identity)~="table" then return nil end
      local value,authoritative=resolved(identity.player_character)
      if authoritative then return value end
      return nil
    end
    if type(opts.activeCharacter)=="function" then
      local value,authoritative=resolved(opts.activeCharacter(game))
      if authoritative then return value end
    end
    if opts.characters and type(opts.characters.getPlayerCharacter)=="function" then
      local value,authoritative=resolved(opts.characters.getPlayerCharacter())
      if authoritative then return value end
    end
    return save and "RED" or nil
  end

  local function rawBucket(save, create)
    if type(save)~="table" then return nil,"save" end
    if type(save.modData)=="table" then
      local bucket=save.modData[mod.id]
      if bucket~=nil and type(bucket)~="table" then return nil,"bucket" end
      if not bucket and create then bucket={};save.modData[mod.id]=bucket end
      return bucket,"raw"
    end
    return nil,"fallback"
  end

  local function runFor(save, create)
    local bucket,source=rawBucket(save,create)
    if source=="bucket" or source=="save" then return nil,source end
    if source=="raw" then
      if not bucket then return nil,"missing" end
      local run=bucket.hevo_run
      if type(run)~="table" and create then run={};bucket.hevo_run=run end
      return type(run)=="table" and run or nil,"raw"
    end
    if mod.save and type(mod.save.get)=="function" then
      local run=mod.save:get("hevo_run")
      if type(run)~="table" and create then run={};mod.save:set("hevo_run",run) end
      return type(run)=="table" and run or nil,"api"
    end
    local run=save.hevo_run
    if type(run)~="table" and create then run={};save.hevo_run=run end
    return type(run)=="table" and run or nil,"direct"
  end

  local function persistFallback(run, source)
    if source=="api" and mod.save and type(mod.save.set)=="function" then
      mod.save:set("hevo_run",run)
    end
  end

  function L.state(save, create, game)
    local character=L.character(game or {save=save})
    if not character then return nil,"character" end
    local run,source=runFor(save,create)
    if not run then return nil,source end
    local state=run.floorLights
    if type(state)=="table" and tonumber(state.version)~=L.version then
      -- There is no pre-v1 floor-light format to migrate.  A malformed or
      -- future record is not evidence for visibility and therefore reads as
      -- stage zero; the next genuine activation starts a clean v1 record.
      if create==false then return nil,"version" end
      state=nil
    end
    local token=tostring(run.cycle or run.id or run.runId or 0)..":"..character
    if type(state)~="table" and create~=false then
      state={version=L.version,token=token,character=character,floors={}}
      run.floorLights=state
    end
    if type(state)~="table" then return nil,"missing" end
    if state.token~=token or state.character~=character then
      if create==false then return nil,"token" end
      -- This is the only reset path: a new journey/identity starts dark.
      state={version=L.version,token=token,character=character,floors={}}
      run.floorLights=state
    end
    state.version=L.version
    state.floors=type(state.floors)=="table" and state.floors or {}
    persistFallback(run,source)
    return state,source
  end

  local function floorState(save,mapId,create,game)
    local floor=L.byMap[mapId]
    if not floor then return nil,"map" end
    local state,source=L.state(save,create,game)
    if not state then return nil,source end
    if state.character~=floor.owner then return nil,"character" end
    local current=state.floors[mapId]
    if type(current)~="table" and create~=false then
      current={lit={}};state.floors[mapId]=current
    end
    if type(current)~="table" then return nil,"missing" end
    current.lit=type(current.lit)=="table" and current.lit or {}
    return current,source
  end

  local function countLit(current,floor)
    local count=0
    for _,stone in ipairs(floor.stones) do
      if current and current.lit and current.lit[stone.name]==true then count=count+1 end
    end
    return count
  end

  function L.stage(save,mapId,game)
    local floor=L.byMap[mapId]
    if not floor then return nil,"map" end
    local current,why=floorState(save,mapId,false,game)
    if not current then return 0,why end
    return countLit(current,floor),"ok"
  end

  function L.activate(save,mapId,objectName,game)
    local floor,stone=L.byMap[mapId],L.byObject[objectName]
    if not (floor and stone and stone.map==mapId) then return false,"stone" end
    if L.character(game or {save=save})~=floor.owner then return false,"character" end
    local current,source=floorState(save,mapId,true,game)
    if not current then return false,source end
    if current.lit[objectName]==true then return false,"already",countLit(current,floor) end
    current.lit[objectName]=true
    local run=runFor(save,false)
    if run then persistFallback(run,source) end
    return true,"lit",countLit(current,floor)
  end

  -- Stages 1/2 reveal roughly one/two thirds of a challenge floor's useful
  -- screen-space reach.  Stage 3 removes the spatial aperture (96 cells is
  -- larger than every authored floor diagonal) but keeps an atmospheric inner
  -- veil.  The accepted black/frost/fog colour treatments remain unchanged.
  local PROFILES={
    RED={
      [0]={radius=1.9,coreRadius=0.85,coneSlope=0.34,innerOpacity=0.32,opacity=1.0,featherPx=2.0},
      [1]={radius=20.0,coreRadius=1.00,coneSlope=0.46,innerOpacity=0.24,opacity=1.0,featherPx=2.0},
      [2]={radius=40.0,coreRadius=1.20,coneSlope=0.64,innerOpacity=0.18,opacity=1.0,featherPx=2.0},
      [3]={radius=96.0,coreRadius=96.0,coneSlope=1.00,innerOpacity=0.12,opacity=0.12,featherPx=2.0},
    },
    BLUE={
      [0]={radius=1.75,innerOpacity=0.68,outerOpacity=1.0,opacity=1.0,featherPx=2.0},
      [1]={radius=22.0,innerOpacity=0.58,outerOpacity=1.0,opacity=1.0,featherPx=2.0},
      [2]={radius=44.0,innerOpacity=0.50,outerOpacity=1.0,opacity=1.0,featherPx=2.0},
      [3]={radius=96.0,innerOpacity=0.42,outerOpacity=0.42,opacity=0.42,featherPx=2.0},
    },
    GREEN={
      [0]={radius=1.0,innerOpacity=0.72,opacity=1.0,featherPx=2.0},
      [1]={radius=24.0,innerOpacity=0.58,opacity=1.0,featherPx=2.0},
      [2]={radius=48.0,innerOpacity=0.42,opacity=1.0,featherPx=2.0},
      [3]={radius=96.0,innerOpacity=0.26,opacity=1.0,featherPx=2.0},
    },
  }
  function L.profile(owner,stage)
    owner=type(owner)=="string" and owner:upper() or nil
    stage=math.max(0,math.min(3,math.floor(tonumber(stage) or 0)))
    local source=PROFILES[owner] and PROFILES[owner][stage]
    if not source then return nil,"owner" end
    local out={floorStage=stage,spatiallyUnbounded=stage==3}
    for key,value in pairs(source) do out[key]=value end
    return out
  end
  function L.profileFor(save,mapId,game)
    local floor=L.byMap[mapId]
    if not floor then return nil,"map" end
    local stage,why=L.stage(save,mapId,game)
    -- Invalid/mismatched identity fails closed to stage zero, never to a
    -- route-global late-game radius.
    return L.profile(floor.owner,stage or 0),why
  end

  -- Route renderers and the 0.1.83 compatibility layer consume these same
  -- methods.  No profile is supplied on approach/recovery/shrine maps, where
  -- the established character renderer remains authoritative.
  if routes.RED then routes.RED.floorSightProfile=function(save,mapId)
    return L.profileFor(save,mapId)
  end end
  if routes.BLUE then routes.BLUE.floorSightProfile=function(save,mapId)
    return L.profileFor(save,mapId)
  end end
  if routes.GREEN then routes.GREEN.floorSightProfile=function(save,mapId)
    return L.profileFor(save,mapId)
  end end

  local function routeLayout(mapId)
    for _,key in ipairs({"RED","BLUE","GREEN"}) do
      local route=routes[key]
      if route then
        if route.byId and route.byId[mapId] then return route.byId[mapId] end
        if route.layouts and route.layouts[mapId] then return route.layouts[mapId] end
        if route.layouts then
          for _,def in pairs(route.layouts) do if def and def.id==mapId then return def end end
        end
      end
    end
  end

  function L.register()
    if L.registered then return false,"already registered" end
    local talks={}
    for textId,stone in pairs(L.byText) do
      local boundStone=stone
      mod.content.text:register(textId,tr(
        "A dormant floor light waits for this trial.",
        "Ein dunkler Etagen-Lichtstein wartet auf diese Prüfung."))
      talks[textId]=function(game,ow,npc,done)
        local objectName=npc and npc.def and npc.def.name or boundStone.name
        local spec=L.byObject[objectName] or boundStone
        local ok,why,stage=L.activate(game and game.save,spec.map,spec.name,game)
        L.refresh(game,spec.map)
        local message
        if ok and stage==1 then
          message=tr("The first floor light wakes. About one third of this floor opens.",
            "Der erste Etagen-Lichtstein erwacht. Etwa ein Drittel dieser Etage wird sichtbar.")
        elseif ok and stage==2 then
          message=tr("The second floor light wakes. About two thirds of this floor open.",
            "Der zweite Etagen-Lichtstein erwacht. Etwa zwei Drittel dieser Etage werden sichtbar.")
        elseif ok and stage==3 then
          message=tr("All three floor lights shine. The spatial veil lifts; the cavern stays dim.",
            "Alle drei Etagen-Lichtsteine leuchten. Die räumliche Schwärze weicht; die Höhle bleibt düster.")
        elseif why=="already" then
          message=tr("This floor light is already awake.",
            "Dieser Etagen-Lichtstein leuchtet bereits.")
        else
          message=tr("The floor light does not answer this character.",
            "Der Etagen-Lichtstein antwortet diesem Charakter nicht.")
        end
        if type(opts.showText)=="function" then return opts.showText(game,message,done) end
        if game and game.stack then
          game.stack:push(require("src.render.TextBox").new(game,message,done));return true
        end
        if done then done() end
        return ok,why
      end
    end
    local pointers={};for textId in pairs(L.byText) do pointers[textId]={text=textId} end
    mod.content.text_pointers:patch("???",pointers)

    for _,floor in ipairs(rows) do
      local def=assert(mod.content.maps:get(floor.map),floor.map.." missing before floor-light patch")
      local objects={};local maxIndex=0;local occupied={}
      for _,object in ipairs(def.objects or {}) do
        objects[#objects+1]=object;maxIndex=math.max(maxIndex,tonumber(object.index) or 0)
        occupied[(object.x or -1)..","..(object.y or -1)]=object.name
      end
      for _,warp in ipairs(def.warps or {}) do
        assert(not occupied[warp.x..","..warp.y],floor.map.." already overlaps object/warp")
      end
      for _,stone in ipairs(floor.stones) do
        assert(not occupied[stone.x..","..stone.y],stone.name.." overlaps "..tostring(occupied[stone.x..","..stone.y]))
        for _,warp in ipairs(def.warps or {}) do
          assert(not (warp.x==stone.x and warp.y==stone.y),stone.name.." overlaps warp")
        end
        maxIndex=maxIndex+1
        objects[#objects+1]={index=maxIndex,name=stone.name,
          sprite="SPRITE_KA_EVOLUTION_RELIC",x=stone.x,y=stone.y,
          movement="STAY",range="NONE",text=stone.text,passable=false,
          semanticRole="floor_light"}
      end
      mod.content.maps:patch(floor.map,{objects=objects})
      local patched=mod.content.maps:get(floor.map)
      local layout=routeLayout(floor.map)
      if layout then layout.objects=patched.objects end
      mod.content.map_scripts:register(floor.map,{priority=3100,talk=talks})
    end
    L.registered=true
    return true
  end

  local function currentMap(game,mapId)
    if mapId then return mapId end
    local ow=mod.world and mod.world.overworld and mod.world:overworld()
    return ow and ow.map and ow.map.id
      or game and game.save and game.save.player and game.save.player.map
  end
  function L.clearRuntime(game)
    local ow=mod.world and mod.world.overworld and mod.world:overworld()
      or game and game.overworld
    if ow then
      ow.kaHevoRedSight=nil;ow.kaHevoBlueSight=nil
      ow.kaHevoGreenFloorSight=nil
    end
    return true
  end
  function L.refresh(game,mapId)
    local ow=mod.world and mod.world.overworld and mod.world:overworld()
      or game and game.overworld
    mapId=currentMap(game,mapId)
    local floor=L.byMap[mapId]
    if not (ow and floor) then return false,"map" end
    -- A hot mod refresh can retain an NPC instance previously marked passable
    -- by the rejected walk-through contract.  Reassert the intended tangible
    -- state only for our exact three floor lights; quiz statues and all other
    -- map objects retain their own collision authority.
    for _,npc in ipairs(ow.npcs or {}) do
      local def=npc and npc.def
      local stone=def and L.byObject[def.name]
      if stone and stone.map==mapId and def.semanticRole=="floor_light" then
        npc.passable=false
      end
    end
    local profile=L.profileFor(game and game.save,mapId,game)
    if floor.owner=="RED" then
      ow.kaHevoRedSight=profile;ow.visionRadius=profile.radius
    elseif floor.owner=="BLUE" then
      ow.kaHevoBlueSight=profile
    else
      ow.kaHevoGreenFloorSight=profile
    end
    return true,profile
  end
  function L.install(game)
    if L.installed then return false,"already installed" end
    L.installed=true
    local function refresh(ev) return L.refresh(game,ev and ev.mapId) end
    -- Lower priority runs after all three route listeners, making the local
    -- stage the final presentation owner without modifying puzzle state.
    mod.events:on("map.entered",refresh,-500)
    mod.events:on("map.reloaded",refresh,-500)
    mod.events:on("save.loaded",refresh,-500)
    mod.events:on("save.created",refresh,-500)
    mod.events:on("save.loading",function() L.clearRuntime(game) end,3000)
    L.refresh(game)
    return true
  end
  return L
end
