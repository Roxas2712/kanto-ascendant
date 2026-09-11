local make=assert(loadfile('backend_gift_species_67.lua'))()
local entries,defs={},{}
for d=1,448 do
 local id=d==447 and 'RIOLU' or d==448 and 'LUCARIO' or 'D'..d
 entries['dex:'..d]={identifier=id,isBase=true};defs[id]={dex=d,backendOwner='kasc.backend.gift-species/v1'}
end
local registry={each=function()return pairs(defs)end,get=function(_,id)return defs[id]end,
 patch=function(_,id,p)for k,v in pairs(p)do defs[id][k]=v end end}
local events={}
local function emit(id,ev)for _,fn in ipairs(events[id] or {})do fn(ev)end end
local function fresh()return {save={party={{species='RIOLU',hp=10,johtoBond=0}}}}end
local a,b=fresh(),fresh()
local mod={game=a,content={pokemon=registry,moves={get=function()end},
 constants={get=function()return 151 end},evolution_methods={get=function()return {check=function()end}end,register=function()end}},
 events={on=function(_,id,fn)events[id]=events[id]or{};table.insert(events[id],fn)end}}
make(mod,{catalog={maximumNationalDex=448,entries=entries},facts={},art={}})
local n=0
local function check(x,m)n=n+1;assert(x,m)end
local function step(count,ev)for i=1,count do emit('world.stepped',ev or {mapId='ROUTE_1',x=8,y=6})end end
emit('game.ready',{game=a});step(63)
check(a.save.party[1].johtoBond==0,'no premature gain');step(1)
check(a.save.party[1].johtoBond==1,'native payload without game raises friendship')
step(64,{game=b});check(b.save.party[1].johtoBond==1 and a.save.party[1].johtoBond==1,'explicit game wins')
emit('game.ready',{game=b});step(64);check(b.save.party[1].johtoBond==2,'ready switches active game')
local mon=b.save.party[1];mon.isEgg=true;step(64);check(mon.johtoBond==2,'eggs excluded');mon.isEgg=nil
mon.hp=0;step(64);check(mon.johtoBond==2,'fainted excluded');mon.hp=10
mon.species='D1';step(64);check(mon.johtoBond==2,'other species unchanged');mon.species='RIOLU'
mon.johtoBond=255;step(64);check(mon.johtoBond==255,'capped at 255')
b.save=fresh().save;emit('save.loaded',{save=b.save});step(64);check(b.save.party[1].johtoBond==1,'reads current party after reload')
print('RIOLU NATIVE STEP PASS: '..n..' checks')
