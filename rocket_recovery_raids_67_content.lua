-- Registers isolated Rocket raid maps by cloning exact stock-map geometry.
-- Stock maps, their objects, scripts, warps and encounter tables are never
-- patched. A Card rollback can therefore remove every raid map cleanly.

return function(mod,opts)
  opts=opts or{}
  local maps=assert(opts.maps,"Rocket raid maps missing")
  local data=assert(opts.data,"Rocket raid data missing")
  local C={registered=false,runtime=nil,textIds={},objectNames={},clones={}}
  local function copy(value,seen)
    if type(value)~="table"then return value end
    seen=seen or{};if seen[value]then return seen[value]end
    local out={};seen[value]=out
    for k,v in pairs(value)do out[copy(k,seen)]=copy(v,seen)end
    return out
  end
  local function textId(instance,kind,index)
    local id=("TEXT_KA_ROCKET_RAID_%s_%s%s"):format(
      instance.id:upper(),kind,index and"_"..tostring(index)or"")
    C.textIds[id]=true;return id
  end
  local function object(index,name,sprite,x,y,text)
    C.objectNames[name]=true
    return{index=index,name=name,sprite=sprite,x=x,y=y,movement="STAY",
      range="NONE",text=text,passable=false,hidden=true}
  end
  local function instanceById(instanceId)
    for _,row in ipairs(data.instances or{})do if row.id==instanceId then return row end end
  end
  local function capturesForInstance(instanceId)
    local out={}
    for _,row in ipairs(data.contraband or{})do
      local target=row.instance
      if row.mode=="four_cell_encounter"then target=row.instances and row.instances[#row.instances]end
      if target==instanceId then out[#out+1]=row end
    end
    return out
  end
  local function dispatch(kind,index)
    return function(game,ow,npc,done)
      if not(C.runtime and type(C.runtime.talk)=="function")then
        if done then done()end;return false,"runtime_unbound"
      end
      return C.runtime.talk(game,ow,npc,kind,index,done)
    end
  end
  local function cloneDefinition(host,row,objects)
    local clone=copy(host)
    clone.id=row.map;clone.index=row.index;clone.label="ROCKET RAID"
    clone.objects=objects;clone.warps={};clone.connections={};clone.signs={}
    clone.kaCard="KASC-67-ROCKET-RECOVERY-RAIDS"
    clone.kaOwner="kasc.rocket.recovery-raids/v1"
    clone.kaSourceMap=row.hostMap;clone.kaInstance=true
    clone.voxelRevision=math.max(tonumber(host.voxelRevision)or 0,1)+1
    return clone
  end
  function C.register()
    if C.registered then return false,"already_registered"end
    maps.validate()
    local available,hostCount=0,0
    for hostMap in pairs(maps.byHostMap)do
      hostCount=hostCount+1
      if mod.content.maps:get(hostMap)then available=available+1 end
    end
    -- ROM-free SDK fixtures intentionally have no stock catalog.
    if available==0 then C.registered=true;C.skipped="missing_stock_maps";return true,C.skipped end
    assert(available==hostCount,"Rocket stock host map set is incomplete")
    local reserved={}
    for _,row in ipairs(maps.rows)do
      assert(not mod.content.maps:get(row.map),"duplicate Rocket instance "..row.map)
      assert(not reserved[row.index],"duplicate Rocket instance index")
      reserved[row.index]=true
    end
    for id,definition in mod.content.maps:each()do
      assert(not(definition and reserved[definition.index]),
        "Rocket instance index already owned by "..tostring(id))
    end
    for _,row in ipairs(maps.rows)do
      local host=assert(mod.content.maps:get(row.hostMap),
        "Rocket stock host unavailable: "..row.hostMap)
      local instance=assert(instanceById(row.id),"Rocket instance missing")
      assert(instance.map==row.map and instance.hostMap==row.hostMap,
        "Rocket data/map contract drift: "..row.id)
      local objects,talks={},{}
      for index,point in ipairs(row.guards or{})do
        local id=textId(instance,"FIGHT",index)
        local name=("KA_ROCKET_RAID_%s_FIGHT_%02d"):format(instance.id:upper(),index)
        objects[#objects+1]=object(#objects+1,name,"SPRITE_ROCKET",point[1],point[2],id)
        talks[id]=dispatch("fight",index)
      end
      local bossIndex=instance.fights
      local bossId=textId(instance,"FIGHT",bossIndex)
      local bossName=("KA_ROCKET_RAID_%s_FIGHT_%02d"):format(instance.id:upper(),bossIndex)
      objects[#objects+1]=object(#objects+1,bossName,
        instance.lead=="GIOVANNI"and"SPRITE_GIOVANNI"or"SPRITE_ROCKET",
        row.boss[1],row.boss[2],bossId)
      talks[bossId]=dispatch("fight",bossIndex)
      for _,capture in ipairs(capturesForInstance(instance.id))do
        local id=textId(instance,"CAPTURE",capture.key:upper())
        local name="KA_ROCKET_CAPTURE_"..capture.key:upper()
        objects[#objects+1]=object(#objects+1,name,"SPRITE_POKE_BALL",
          row.boss[1],row.boss[2],id)
        talks[id]=dispatch("capture",capture.key)
      end
      local clone=cloneDefinition(host,row,objects)
      -- Occupy real doorway/stair cells, without editing stock geometry or
      -- adding functional floor warps. These guards explain the sealed exits.
      local blockedCells={}
      for _,warp in ipairs(host.warps or{})do
        local x,y=tonumber(warp.x),tonumber(warp.y)
        local key=x and y and (x..":"..y)
        if key and not blockedCells[key]then
          blockedCells[key]=true
          local id=textId(instance,"BLOCKED",#objects+1)
          local guard=object(#objects+1,
            "KA_ROCKET_BLOCK_"..instance.id:upper().."_"..(#objects+1),
            "SPRITE_ROCKET",x,y,id)
          guard.hidden=false
          objects[#objects+1]=guard
          talks[id]=dispatch("blocked")
        end
      end
      mod.content.maps:register(row.map,clone);C.clones[row.map]=clone
      if mod.content.encounters then mod.content.encounters:register(row.map,{grass={rate=0,slots={}}})end
      if mod.content.map_songs then
        local song=mod.content.map_songs:get(row.hostMap)
        if song then mod.content.map_songs:register(row.map,copy(song))end
      end
      mod.content.map_scripts:register(row.map,{priority=3370,talk=talks,
        onEnter=function(game)
          if C.runtime and type(C.runtime.sync)=="function"then return C.runtime.sync(game,row.map)end
        end})
    end
    for id in pairs(C.textIds)do mod.content.text:register(id,"Team Rocket blocks the way.")end
    local pointers={};for id in pairs(C.textIds)do pointers[id]={text=id}end
    mod.content.text_pointers:patch("???",pointers)
    C.registered=true;return true
  end
  function C.bindRuntime(selfOrRuntime,maybeRuntime)
    C.runtime=maybeRuntime or selfOrRuntime;return C.runtime~=nil
  end
  C.maps=maps;return C
end
