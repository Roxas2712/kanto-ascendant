-- KASC_ENGINE=/path/to/engine KASC_NATIVE_DATA=/path/to/data/generated luajit tests/blaine_volcano_route_test.lua
local engine=assert(os.getenv('KASC_ENGINE'))
local dataRoot=assert(os.getenv('KASC_NATIVE_DATA'))
package.path=engine..'/?.lua;./?.lua;'..package.path
local Map=require('src.world.Map')
local Hooks=require('src.mods.Hooks')
local maps=dofile(dataRoot..'/maps.lua')
local tiles=dofile(dataRoot..'/tilesets.lua')
local sounds={}
package.loaded['src.core.Sound']={play=function(_,id)sounds[#sounds+1]=id end}
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function copy(v)if type(v)~='table'then return v end;local t={};for k,x in pairs(v)do t[k]=copy(x)end;return t end
local native=copy(maps.CINNABAR_GYM)
local content={}
local tables={maps=maps,tilesets=tiles,map_scripts={},encounters={},map_songs={}}
for name,rows in pairs(tables)do
  content[name]={get=function(_,id)return rows[id]end,
    each=function()return pairs(rows)end,
    register=function(_,id,row)assert(not rows[id],'duplicate '..id);rows[id]=row end,
    patch=function(_,id,p)for k,v in pairs(p)do rows[id][k]=v end end}
end
local moves={};local mod={path='.',content=content,world={warpTo=function(_,...)moves[#moves+1]={...};return true end}}
local skin=dofile('hoenn_endgame_tilesets_67.lua')(mod,{json={}})
tiles[skin.VOLCANO_ID]=skin.volcanoDefinition(tiles.CAVERN)
local R=dofile('blaine_volcano_route.lua')(mod,{volcanoTileset=skin.VOLCANO_ID})
check(R.register(),'register')
check(not R.register(),'registration is idempotent')
check(#maps.CINNABAR_GYM.objects==#native.objects-1,'only leader removed')
for i,o in ipairs(maps.CINNABAR_GYM.objects)do
  check(o.index==native.objects[i+1].index and o.name==native.objects[i+1].name,'quiz trainer index preserved')
end
for i,b in ipairs(maps.CINNABAR_GYM.blocks)do
  check(b==(i==12 and 111 or native.blocks[i]),'native quiz geometry preserved '..i)
end
for _,w in ipairs(maps.CINNABAR_GYM.warps)do check(w.destMap=='CINNABAR_ISLAND' and w.destWarp==2,'gym exit stays in town after outside foothills')end
local function runtime(id)return Map.new(maps[id],tiles[maps[id].tileset])end
local function walkable(id,x,y)local m=runtime(id);return m:inBounds(x,y)and m:isWalkableCell(x,y)end
local function reachable(id,sx,sy,tx,ty)
  local m=runtime(id);local q={{sx,sy}};local seen={[sx..','..sy]=true};local at=1
  while q[at]do local p=q[at];at=at+1;if p[1]==tx and p[2]==ty then return true end
    for _,v in ipairs{{1,0},{-1,0},{0,1},{0,-1}}do
      local x,y=p[1]+v[1],p[2]+v[2];local k=x..','..y
      if not seen[k]and m:inBounds(x,y)and m:isWalkableCell(x,y)then seen[k]=true;q[#q+1]={x,y}end
    end
  end
  return false
end
for id,links in pairs(R.links)do
  for _,p in ipairs(links)do
    check(walkable(id,p.x,p.y),'walk-on trigger '..id..' '..p.x..','..p.y)
    check(walkable(p.map,p.toX,p.toY),'safe landing '..p.map)
    for _,back in ipairs(R.links[p.map])do
      check(back.x~=p.toX or back.y~=p.toY,'no arrival bounce '..p.map)
      if id~=R.GYM then check(reachable(p.map,p.toX,p.toY,back.x,back.y),'reciprocal route reachable '..p.map)end
    end
    local before=#sounds
    check(R.onStep({}, {map={id=id}},p.x,p.y),'physical step warp')
    check(#sounds==before+1 and sounds[#sounds]==(p.map==R.FOOT and 'Go_Outside'or'Go_Inside'),'one transition sound')
    check(moves[#moves][1]==p.map and moves[#moves][2]==p.toX,'correct destination')
  end
end
check(reachable(R.TUNNEL,44,8,5,4),'right-to-left tunnel then north')
check(reachable(R.FOOT,15,19,15,12),'foothill entrance reachable')
check(reachable(R.CHAMBER,24,28,25,13),'leader approachable from bridge')
local chamber=maps[R.CHAMBER];local cm=runtime(R.CHAMBER)
check(chamber.width==24 and chamber.height==18,'48x36 cell envelope')
for y=10,21 do for x=16,33 do check(cm:isWalkableCell(x,y),'clear arena floor '..x..','..y)end end
for y=0,cm.heightCells-1 do for x=0,cm.widthCells-1 do
  if chamber.blocks[math.floor(y/2)*chamber.width+math.floor(x/2)+1]==128 then
    check(not cm:isWalkableCell(x,y) and not cm:isWaterCell(x,y),'lava cannot be walked or surfed')
  end
end end
check(chamber.kaArenaGeometry.version==2,'compact court contract')
check(not cm:isWalkableCell(15,16)and not cm:isWalkableCell(34,16)and not cm:isWalkableCell(25,9)and not cm:isWalkableCell(20,22),'lava surrounds all four court sides')
local npc={def=chamber.objects[1],id=R.CHAMBER..'_obj_1'}
check(npc.def.name==native.objects[1].name and npc.def.trainerClass=='OPP_BLAINE' and npc.def.trainerParty==1,'native leader identity/party')
local headers=dofile(dataRoot..'/trainer_headers.lua')
check(headers[chamber.label]==headers[native.label],'native battle header preserved')
check(R.trainerKey({map={id=R.CHAMBER}},npc)=='CINNABAR_GYM_obj_1','old rematch record identity')
check(R.canonicalMap(R.CHAMBER)==R.GYM and R.canonicalMap('PEWTER_GYM')=='PEWTER_GYM','narrow gym alias')

-- Exercise the real difficulty hook at both locations, plus an unrelated map.
local events={};local values={difficulty='hard'}
local dm={hooks=Hooks.new(),events={on=function(_,id,fn)events[id]=fn end},options={get=function(_,id)return values[id]end}}
local D=dofile('story_gym_difficulty.lua')(dm,{canonicalGymMap=R.canonicalMap,
  gameVersion={get=function()return 'red'end,isYellow=function()return false end}})
local trainers=dofile(dataRoot..'/trainers.lua')
local original=copy(trainers.OPP_BLAINE.parties[1])
for _,id in ipairs{R.GYM,R.CHAMBER,'ROUTE_1'}do
  local game={save={flags={},inventory={}},overworld={map={id=id}}}
  events['game.ready']({game=game})
  local out=dm.hooks:call('trainer.party',function(_,_,p)return p end,'OPP_BLAINE',1,copy(original))
  if id=='ROUTE_1'then check(#out==#original and not out[1].moves,'unrelated trainer context unaffected')
  else
    check(out[1].moves and #out>=#original,'story difficulty retained '..id)
    local battle={kind='trainer',game=game,oppClass='OPP_BLAINE',partyIndex=1,enemyParty=copy(out)}
    events['battle.started']({battle=battle})
    check(battle.ascendantStoryGym and battle.ascendantStoryGymDifficulty=='hard','battle policy follows actual map '..id)
    check(battle.ascendantStoryGymHealCap==1,'healing budget preserved '..id)
  end
end
check(tables.map_songs[R.CHAMBER]=='Music_Gym'and tables.map_songs[R.TUNNEL]=='Music_Gym','Gym music inside arena and connecting corridor')
check(tables.map_songs[R.FOOT]=='Music_Dungeon1','volcanic approach keeps dungeon music')
check(#maps[R.GYM].kaBlaineStairs.points==1 and #maps[R.TUNNEL].kaBlaineStairs.points==2 and #maps[R.FOOT].kaBlaineStairs.points==1,'all four scripted stair pins')
local played=#sounds
mod.world.warpTo=function()return nil,'blocked'end
check(not R.onStep({}, {map={id=R.GYM}},3,2)and #sounds==played,'failed warp does not play sound')
local outPath=os.getenv('BLAINE_MAP_EXPORT')
if outPath then
  local f=assert(io.open(outPath,'w'));f:write(require('src.link.Json').encode({maps=R.maps,gym=maps.CINNABAR_GYM,tilesets=tiles,links=R.links}));f:close()
end
print('PASS Blaine volcano route: '..checks..' checks')
