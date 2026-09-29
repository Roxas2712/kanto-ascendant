local cfg={townPokemonEnabled=function()return true end,debug=function()return false end}
local modules={config=cfg,encounter_index={mapTypeOf=function()return 'town'end}}
local A=assert(loadfile('vendor/wilds_1_12_2/lib/ambient_pokemon.lua'))({require=function(n)return modules[n]or{}end})
local game={save={},data={encounters={}}}
local function world(id)
 local blocked,warps={},{}
 local map={id=id or 'TEST_CITY',widthCells=24,heightCells=24,def={},blocked=blocked,warps=warps}
 function map:inBounds(x,y)return x>=0 and y>=0 and x<24 and y<24 end
 function map:isWalkableCell(x,y)return self:inBounds(x,y)and not blocked[x..','..y]end
 function map:warpAtCell(x,y)return warps[x..','..y]end
 return {map=map,player={cellX=12,cellY=12},npcs={},entities={}}
end
local function manager(seed)
 local a=A.new({}, {seed=seed})
 function a:_makeNpc(_,ow,s,x,y,b)return {cellX=x,cellY=y,wildsAmbientPokemon=true,ambientSpecies=s,ambientBehavior=b}end
 return a
end
local function signature(a)
 local list={};for n in pairs(a.active)do list[#list+1]=n.ambientSpecies..':'..n.cellX..','..n.cellY..':'..n.ambientBehavior end
 table.sort(list);return table.concat(list,'|')
end
local ow=world();local a=manager(29)
local searches=0;local search=a.findSpawnCell
function a:findSpawnCell(...) searches=searches+1;return search(self,...)end
local n=a:spawnForMap(game,ow);assert(n>=1 and n<=2);local first=signature(a);local count=searches
for i=1,30 do
 a:clearAll(ow);a.activeMapId=nil
 for j=1,i do math.random()end
 assert(a:spawnForMap(game,ow)==n and signature(a)==first,'reentry rerolled plan')
end
assert(searches==count,'cached coordinates searched again')
-- Both density outcomes exist, never >2; neither plan construction nor validation
-- consumes global RNG when an explicit session seed is supplied.
local counts={};local variants={}
for seed=1,100 do
 local w=world();local m=manager(seed)
 math.randomseed(77);local expected=math.random();math.randomseed(77)
 local c=m:spawnForMap(game,w);assert(math.random()==expected,'global RNG consumed')
 assert(c>=1 and c<=2);counts[c]=true;variants[signature(m)]=true
 for actor in pairs(m.active)do assert(A.isSafeSpawnCell(w,w.map,actor.cellX,actor.cellY,actor))end
end
assert(counts[1]and counts[2]);local v=0;for _ in pairs(variants)do v=v+1 end;assert(v>20)
-- Solid corridor, door/stair neighbours, boundary and moving reservations.
local w=world()
for x=0,23 do for y=0,23 do if y~=12 then w.map.blocked[x..','..y]=true end end end
assert(not A.isSafeSpawnCell(w,w.map,8,12),'one-cell corridor blocked')
w=world();assert(A.isSafeSpawnCell(w,w.map,8,8))
w.map.warps['8,7']={};assert(not A.isSafeSpawnCell(w,w.map,8,8));w.map.warps={}; -- methods capture original table
w=world();function w.map:isWarpTileCell(x,y)return x==8 and y==7 end
assert(not A.isSafeSpawnCell(w,w.map,8,8));assert(not A.isSafeSpawnCell(w,w.map,0,8))
w=world();local other={cellX=8,cellY=8,wildsAmbientPokemon=true,moving=true,targetX=9,targetY=8};w.entities={other}
for dx=-1,1 do for dy=-1,1 do assert(not A.isSafeSpawnCell(w,w.map,8+dx,8+dy))end end
assert(not A.isSafeSpawnCell(w,w.map,10,9),'reserved neighbour allowed')
assert(A.isSafeSpawnCell(w,w.map,11,8),'one empty cell should suffice')
-- Changed collision or NPC occupancy repairs the cached site, preserving species.
a:clearAll(ow);a.activeMapId=nil
local plan=a._plans.TEST_CITY;local e=plan.entries[1];local species=e.species
ow.map.blocked[e.x..','..e.y]=true
assert(a:spawnForMap(game,ow)>0);assert(e.species==species and ow.map:isWalkableCell(e.x,e.y))
a:clearAll(ow);a.activeMapId=nil;ow.entities={{cellX=e.x,cellY=e.y}};ow.npcs={}
a:spawnForMap(game,ow);assert(e.x~=ow.entities[1].cellX or e.y~=ow.entities[1].cellY)
-- A temporary occupant must not hide a corridor branch from connectivity.
w=world();w.entities={{cellX=8,cellY=7}}
assert(not A.isSafeSpawnCell(w,w.map,8,8),'occupied branch silently removed')
-- No available safe place means no forced spawn.
w=world();for x=0,23 do for y=0,23 do w.map.blocked[x..','..y]=true end end
assert(manager(2):spawnForMap(game,w)==0)
-- Bound metadata lifetime; new save starts a new session cache.
for i=1,70 do a:clearAll(ow);a.activeMapId=nil;ow=world('CITY_'..i);a:spawnForMap(game,ow)end
local plans=0;for _ in pairs(a._plans)do plans=plans+1 end;assert(plans==64)
game.save={};a:spawnForMap(game,ow);plans=0;for _ in pairs(a._plans)do plans=plans+1 end;assert(plans==1)
print('PASS ambient plans: 1-2 town actors, stable cached reentry, independent RNG, passages/warps/edges, diagonal spacing, reservations, repair, capacity and new save')
