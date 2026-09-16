-- One isolated stock-geometry floor. No ROM tiles or vanilla story scripts
-- are overwritten. Two hidden, save-toggled door guards own event access.
return function(mod,opts)
 local data=assert(opts.data);local I=data.instance
 local C={CARD_ID='KASC-67-BALD-CREW',runtime=nil,registered=false}
 local function copy(x)
  if type(x)~='table'then return x end
  local y={};for k,v in pairs(x)do y[k]=copy(v)end;return y
 end
 -- Seven hosts form a ring on the ORIGINAL walkable entrance floor.
 -- Pandy only appears in its centre after the seventh victory.
 local positions={{8,24},{11,24},{12,26},{11,28},{7,29},{4,28},{4,25},{8,26}}
 C.positions=positions
 local talks,textIds={},{}
 local function textId(key)return 'TEXT_KA_BALD_CREW_'..key:upper()end
 local function dispatch(kind,index)
  return function(game,ow,npc,done)
   if C.runtime then return C.runtime.talk(game,ow,npc,kind,index,done)end
   if done then done()end
  end
 end
 local function object(index,name,sprite,point,key,kind,value)
  local id=textId(key);textIds[id]=true;talks[id]=dispatch(kind,value)
  return{index=index,name=name,sprite=sprite,x=point[1],y=point[2],
   movement='STAY',range='DOWN',text=id,hidden=true,passable=false}
 end
 function C.register()
  if C.registered then return false end
  local host=mod.content.maps:get(I.host)
  if not host then C.skipped='missing_stock_map';return false,C.skipped end
  assert(not mod.content.maps:get(I.map),'Bald Crew instance already registered')
  for id,m in mod.content.maps:each()do assert(m.index~=I.index,'Crew map index occupied by '..id)end
  local clone=copy(host);clone.id=I.map;clone.index=I.index
  clone.label=opts.i18n and opts.i18n.text('THE SHINING DOME','DIE GLANZKUPPEL')or'THE SHINING DOME'
  clone.kaCard=C.CARD_ID;clone.kaOwner='kasc.bald-crew/v1';clone.kaInstance=true
  clone.kaSourceMap=I.host;clone.voxelRevision=(tonumber(host.voxelRevision)or 0)+1
  clone.objects={};clone.warps={};clone.connections={};clone.signs={}
  for index,id in ipairs(data.order)do
   local row=assert(data.opponents[id]);local p=assert(positions[index])
   clone.objects[#clone.objects+1]=object(#clone.objects+1,'KA_BALD_CREW_'..id:upper(),
    row.sprite or 'SPRITE_YOUNGSTER',p,'FIGHT_'..index,'fight',index)
  end
  clone.objects[#clone.objects+1]=object(#clone.objects+1,'KA_BALD_CREW_EXIT',
   'SPRITE_SUPER_NERD',{15,33},'EXIT','exit')
  local seen={}
  for _,warp in ipairs(host.warps or{})do
   local key=warp.x..':'..warp.y
   if not seen[key]then
    seen[key]=true
    clone.objects[#clone.objects+1]=object(#clone.objects+1,'KA_BALD_CREW_SEAL_'..#clone.objects,
     'SPRITE_SUPER_NERD',{warp.x,warp.y},'STAIR_'..#clone.objects,'stairs')
   end
  end
  mod.content.maps:register(I.map,clone)
  mod.content.encounters:register(I.map,{grass={rate=0,slots={}}})
  local song=mod.content.map_songs and mod.content.map_songs:get(I.host)
  if song then mod.content.map_songs:register(I.map,copy(song))end
  local insideTalk={};for k,v in pairs(talks)do insideTalk[k]=v end
  mod.content.map_scripts:register(I.map,{priority=3390,talk=insideTalk,onEnter=function(game)
   if C.runtime then C.runtime.sync(game,I.map)end
  end})
  local outside=assert(mod.content.maps:get(I.entrance),'Crew outside map missing')
  local objects=copy(outside.objects or{})
  local front=object(#objects+1,'KA_BALD_CREW_FRONT','SPRITE_SUPER_NERD',I.frontDoor,'FRONT','front')
  objects[#objects+1]=front
  local rear=object(#objects+1,'KA_BALD_CREW_REAR','SPRITE_SUPER_NERD',I.rearDoor,'REAR','rear')
  objects[#objects+1]=rear
  -- Separate from both warp tiles: a failed/finished trial must never block
  -- the ordinary cave. The existing entrance host handles retry and prizes.
  local restart=object(#objects+1,'KA_BALD_CREW_RESTART','SPRITE_SUPER_NERD',
   I.restartPoint,'RESTART','restart')
  objects[#objects+1]=restart
  mod.content.maps:patch(I.entrance,{objects=objects})
  mod.content.map_scripts:register(I.entrance,{priority=3390,
   talk={[front.text]=talks[front.text],[rear.text]=talks[rear.text],
    [restart.text]=talks[restart.text]},onEnter=function(game)
    if C.runtime then C.runtime.sync(game,I.entrance)end
   end})
  local pointers={}
  for id in pairs(textIds)do
   mod.content.text:register(id,'The Crew is setting up.');pointers[id]={text=id}
  end
  mod.content.text_pointers:patch('???',pointers)
  C.clone=clone;C.registered=true;return true
 end
 function C.bindRuntime(runtime)C.runtime=runtime end
 return C
end
