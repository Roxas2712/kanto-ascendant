-- Native collision proof for every Rocket raid checkpoint and capture.
-- GEN1RECOMP_DIR: released engine; GEN1RECOMP_TEST_DIR: engine test support;
-- ROCKET_DATA_ROOT: directory containing red/blue/yellow/data/generated;
-- TRAINER_REMATCH_MOD_DIR: candidate KASC source.
local engine = assert(os.getenv('GEN1RECOMP_DIR'))
local support = assert(os.getenv('GEN1RECOMP_TEST_DIR'))
local root = assert(os.getenv('TRAINER_REMATCH_MOD_DIR'))
local dataRoot = assert(os.getenv('ROCKET_DATA_ROOT'))
package.path = engine..'/?.lua;'..support..'/?.lua;'..support..'/?/init.lua;'..package.path
love = require('tests.love_stub')
local GameVersion = require('src.core.GameVersion')
local Map = require('src.world.Map')
local Collision = require('src.world.Collision')
local checks, failures = 0, 0
local function check(ok, why)
  checks = checks + 1
  if not ok then failures = failures + 1; print('FAIL '..why) end
  return ok
end
local function clone(v)
  if type(v) ~= 'table' then return v end
  local out = {}; for k,x in pairs(v) do out[k] = clone(x) end; return out
end
local function same(a,b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= 'table' then return a == b end
  for k,v in pairs(a) do if not same(v,b[k]) then return false end end
  for k in pairs(b) do if a[k] == nil then return false end end
  return true
end
local function registry(records)
  return { get=function(_,id) return records[id] end,
    register=function(_,id,value) records[id]=value end,
    each=function() return pairs(records) end,
    patch=function(_,id,value) records[id]=value end }
end
local function actors(def, game)
  local out={}
  for _,obj in ipairs(def.objects) do
    local visible = not obj.hidden
    local toggle = game.save.objectToggles[def.id]
    if toggle and toggle[obj.name] ~= nil then visible = toggle[obj.name] end
    if visible then out[#out+1]={cellX=obj.x,cellY=obj.y,passable=obj.passable,name=obj.name} end
  end
  return out
end
local function approach(map, entities, start, target)
  local q={{start[1],start[2]}}; local seen={[start[2]*map.widthCells+start[1]]=true};local i=1
  while q[i] do
    local p=q[i];i=i+1
    if math.abs(p[1]-target.x)+math.abs(p[2]-target.y)==1 then return p end
    for direction,delta in pairs(Collision.DELTA) do
      if Collision.canMove(map,entities,{cellX=p[1],cellY=p[2],surfing=false},direction) then
        local x,y=p[1]+delta[1],p[2]+delta[2];local k=y*map.widthCells+x
        if not seen[k] then seen[k]=true;q[#q+1]={x,y} end
      end
    end
  end
end
for _,edition in ipairs({'red','blue','yellow'}) do
  GameVersion.set(edition)
  local prefix=dataRoot..'/'..edition..'/data/generated/'
  local native={maps=dofile(prefix..'maps.lua'),tilesets=dofile(prefix..'tilesets.lua'),field=dofile(prefix..'field.lua')}
  Collision.load(native)
  local stock=clone(native.maps)
  local maps=dofile(root..'/rocket_recovery_raids_67_maps.lua')
  local data=dofile(root..'/rocket_recovery_raids_67_data.lua')
  local mod={id='kanto_ascendant',content={},world={},options={get=function()return true end}}
  mod.content.maps=registry(native.maps)
  for _,key in ipairs({'encounters','map_songs','map_scripts','text','text_pointers'}) do mod.content[key]=registry({}) end
  local content=dofile(root..'/rocket_recovery_raids_67_content.lua')(mod,{maps=maps,data=data})
  check(content.register(),edition..' registers real stock clones')
  local objective,warped
  mod.world.warpTo=function(_,map,x,y,facing)warped={map=map,x=x,y=y,facing=facing};return true end
  local runtime=dofile(root..'/rocket_recovery_raids_67_runtime.lua')(mod,{
    maps=maps,data=data,content=content,postgame={},raids={objective=function()return objective end},
  })
  content:bindRuntime(runtime)
  local game={save={objectToggles={}}}
  for ordinal,row in ipairs(maps.rows) do
    local label=edition..'/'..row.id
    local def=content.clones[row.map];local map=Map.new(def,native.tilesets[def.tileset])
    check(same(native.maps[row.hostMap],stock[row.hostMap]),label..' leaves stock source untouched')
    check(same(def.blocks,stock[row.hostMap].blocks),label..' preserves authored geometry')
    check(#def.warps==0 and next(def.connections)==nil,label..' cannot escape through floors')
    check(map:isWalkableCell(unpack(row.start)),label..' has a dry entry')
    local returnMap=Map.new(stock[row.hostMap],native.tilesets[def.tileset])
    check(returnMap:isWalkableCell(unpack(row.returnPoint)),label..' has safe host return')
    local position={unpack(row.start)}
    local fights=data.instances[ordinal].fights
    for fight=1,fights do
      objective={id=row.id,map=row.map,phase='active',fight=fight,instance=ordinal}
      check(runtime.enter(game),label..' enters checkpoint '..fight)
      check(warped.map==row.map and warped.x==row.start[1] and warped.y==row.start[2],label..' uses selected layout entry')
      local entities=actors(def,game)
      check(not Collision.occupied(entities,unpack(row.start)),label..' entry unoccupied')
      local name=('KA_ROCKET_RAID_%s_FIGHT_%02d'):format(row.id:upper(),fight)
      local target
      for _,obj in ipairs(def.objects)do if obj.name==name then target=obj end end
      assert(target,'fight object missing')
      check(map:isWalkableCell(target.x,target.y),label..' fight '..fight..' on walkable cell')
      local adjacent=approach(map,entities,position,target)
      check(adjacent~=nil,label..' fight '..fight..' reachable in sequence without Surf/wall clipping')
      check(approach(map,entities,row.start,target)~=nil,label..' fight '..fight..' reachable on resume')
      if adjacent then position=adjacent end
      for nextFight=fight,fights do
        check(game.save.objectToggles[row.map][('KA_ROCKET_RAID_%s_FIGHT_%02d'):format(row.id:upper(),nextFight)]==true,label..' preserves future guard occupancy')
      end
      for _,entity in ipairs(entities)do
        check(not(entity.name~=name and entity.cellX==target.x and entity.cellY==target.y),label..' target does not overlap another actor')
      end
    end
    for _,capture in ipairs(data.contraband)do
      local targetInstance=capture.mode=='four_cell_encounter'and capture.instances[#capture.instances]or capture.instance
      if targetInstance==row.id then
        objective={id=row.id,map=row.map,phase='capture',capture=capture,instance=ordinal}
        runtime.sync(game,row.map)
        local target
        for _,obj in ipairs(def.objects)do if obj.name=='KA_ROCKET_CAPTURE_'..capture.key:upper()then target=obj end end
        assert(target,'capture object missing')
        local entities=actors(def,game)
        check(approach(map,entities,position,target)~=nil,label..' capture reachable after boss')
        check(approach(map,entities,row.start,target)~=nil,label..' capture reachable on resume')
        for index=1,fights do check(game.save.objectToggles[row.map][('KA_ROCKET_RAID_%s_FIGHT_%02d'):format(row.id:upper(),index)]==false,label..' cleared guards stay hidden')end
      end
    end
    -- Resume/save recovery uses the untouched stock doorway, never the new
    -- isolated cave entry. It must preserve the checkpoint receipt.
    game.save.player={map=row.map,x=position[1],y=position[2],surfing=true}
    local receipt=objective
    check(runtime.secureSave(game.save),label..' repairs stored instance location')
    check(game.save.player.map==row.hostMap and game.save.player.x==row.returnPoint[1]
      and game.save.player.y==row.returnPoint[2] and not game.save.player.surfing,label..' returns safely')
    check(objective==receipt,label..' preserves raid objective during safe return')
  end
end
print(('ROCKET REACHABILITY: %d/%d checks passed; %d failures'):format(checks-failures,checks,failures))
assert(failures==0,'Rocket raid reachability regression')
