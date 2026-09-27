-- Run from the mod root: KASC_ENGINE=/path/to/engine luajit tests/randomizer_progress_test.lua .
local root=assert(arg[1]);package.path=root..'/?.lua;'..assert(os.getenv('KASC_ENGINE'))..'/?.lua;'..package.path
package.loaded['src.core.Logger']={warn=function(...) error('hook error '..tostring(select(1,...))) end}
local Hooks=require('src.mods.Hooks')
local checks,failures=0,0
local function check(v,msg) checks=checks+1;if not v then failures=failures+1;print('FAIL '..msg)end end
local function load(name)return assert(loadfile(root..'/'..name..'.lua'))()end
local function maxrng(a,b)return b end
local function fixture(map,randomized)
 local hooks=Hooks.new();local handlers={};local events={on=function(_,key,fn,priority)handlers[key]=handlers[key]or{};table.insert(handlers[key],{fn=fn,p=priority or 0})end}
 local saved={}
 local mod={id='kanto_ascendant',hooks=hooks,events=events,options={get=function()return true end},save={get=function(_,k)return saved[k]end,set=function(_,k,v)saved[k]=v end},ui={},content={items={register=function()end}}}
 local game={version='red',data={pokemon={},items={},moves={},encounters={}},save={player={name='RED'},flags={EVENT_GOT_POKEDEX=true},party={{species='RATTATA',level=20}},inventory={},pokedex={owned={},seen={}},modData={}},overworld={map={id=map,def={id=map}}}}
 for id,dex in pairs({RATTATA=19,ABRA=63,MEW=151,CELEBI=251,CHIKORITA=152,ARON=304}) do game.data.pokemon[id]={id=id,name=id,dex=dex,baseStats={hp=40,attack=40,defense=40,speed=40,special=40},evolutions={},learnset={},level1Moves={}}end
 local rules=load('run_rules')(mod,{});rules.game=game;rules.buildPool(game)
 local s=rules.state(game.save);s.version=4;s.seed=2712;s.locked=true;s.lockReason='player_pc';s.randomizer.enabled=randomized;s.randomizer.wild=true;s.randomizer.similarStrength=false;s.randomizer.excludeLegendaries=false;s.nuzlocke.mode='off';s.mappings.species.RATTATA='ABRA';s.mappings.species['wild:RATTATA']='ABRA';s.finalRules=nil
 rules.state(game.save)
 local ctx={mapId=map,terrain='grass',rng=maxrng,game=game}
 local def={grass={rate=25,slots={{species='RATTATA',level=5}}}};game.data.encounters[map]=def
 local f={mod=mod,game=game,rules=rules,hooks=hooks,ctx=ctx,def=def}
 function f.emit(key,ev)local hs=handlers[key]or{};table.sort(hs,function(a,b)return a.p>b.p end);for _,r in ipairs(hs)do r.fn(ev)end end
 function f.resolve(out)return hooks:call('encounter.species',function(row)return row end,out,ctx)end
 function f.battle(out)
  out=hooks:call('battle.wild',function(row)return row end,out,{game=game,source='wild',opts={}})
  return {game=game,kind='wild',encounterSource='wild',checkpointOrigin={kind='wild_encounter',map=map},enemy={mon={species=out.species,level=out.level,hp=30,stats={hp=30}}}}
 end
 return f
end
local function mythic(f,state)
 local m=load('mythic_signals')(f.mod,{state={section=function()return state end,persist=function()end}});m.game=f.game;return m
end
for _,randomized in ipairs({false,true})do
 local f=fixture('ROUTE_1',randomized);local s={echoRolls=3,echoes=0,completed={}};local m=mythic(f,s)
 for i=1,50 do
  local original={species='RATTATA',level=5};local out=f.rules.mapVisibleWild(original,f.ctx)
  local result,tx=m.rollReplacement(out,f.def,f.ctx,f.game,nil,original)
  if tx then m.commitWildsSpawn(tx,result.species,result.level)end
 end
 check(s.echoRolls==53,'visible Mythic 50 battles randomized='..tostring(randomized))
 local out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,f.def,f.ctx)
 out=f.resolve(out);f.emit('battle.started',{battle=f.battle(out)})
 check(s.echoRolls==54,'classic Mythic randomized='..tostring(randomized))
end
-- Three Mythic counters, cancellation, duplicate and incorrect battle identity.
for _,kind in ipairs({'echo','true','retry'})do
 local f=fixture('ROUTE_1',true);local s={echoRolls=3,echoes=0,completed={}}
 if kind~='echo'then s.sealed=true;s.echoes=3;s.trueRolls=7 end
 if kind=='retry'then s.bound={species='MEW',level=35,retryRolls=2}end
 local m=mythic(f,s);local orig={species='RATTATA',level=5};local mapped=f.rules.mapVisibleWild(orig,f.ctx)
 local before=kind=='echo'and s.echoRolls or kind=='true'and s.trueRolls or s.bound.retryRolls
 local out,tx=m.rollReplacement(mapped,f.def,f.ctx,f.game,nil,orig)
 check(tx~=nil,kind..' random candidate gets proposal')
 if tx then
  local value=function()return kind=='echo'and s.echoRolls or kind=='true'and s.trueRolls or s.bound.retryRolls end
  check(value()==before,kind..' spawn alone does not count')
  check(m.commitWildsSpawn(tx,out.species,out.level)==true,kind..' exact start commits')
  check(value()==before+1,kind..' increments once')
  check(m.commitWildsSpawn(tx,out.species,out.level)==false,kind..' duplicate rejected')
  out,tx=m.rollReplacement(mapped,f.def,f.ctx,f.game,nil,orig);m.cancel(tx);check(m.commitWildsSpawn(tx,out.species,out.level)==false,kind..' despawn rejected')
  out,tx=m.rollReplacement(mapped,f.def,f.ctx,f.game,nil,orig);check(m.commitWildsSpawn(tx,'CELEBI',99)==false,kind..' unrelated battle rejected')
 end
end
-- Authored hits must survive Randomizer and receive their battle ticket.
for _,source in ipairs({'mythic_signals','johto_signals','hoenn_discovery','hoenn_roamer','starter_habitat_67','hevo'})do
 local f=fixture('ROUTE_1',true);local out={species='RATTATA',level=5,kaProtected=true,kaEncounterSource=source}
 local resolved=f.resolve(out);check(resolved.species=='RATTATA',source..' protected output preserved')
 check(f.battle(resolved).enemy.mon.species=='RATTATA',source..' protected battle preserved')
end
-- Actual classic Johto controller + actual Randomizer.
for _,randomized in ipairs({false,true})do
 local f=fixture('ROUTE_24',randomized)
 local s={receiverRepaired=true,modeChosen=true,mode='WANDERWAVES',traces={forest=true},rarePity={CHIKORITA=3},waveIndex=1}
 local j=load('johto_signals')(f.mod,{state={section=function()return s end,persist=function()end},johtoData={habitats={CHIKORITA={map='ROUTE_24',terrain='grass',level=18}}},encounterLevels=load('johto_encounter_levels')})
 j.game=f.game
 local out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,f.def,f.ctx)
 out=f.resolve(out);f.emit('battle.started',{battle=f.battle(out)})
 check(s.rarePity.CHIKORITA==4,'classic Johto trace increments randomized='..tostring(randomized))
end
-- Hoenn traced-family counters with actual Randomizer, both modes.
for _,randomized in ipairs({false,true})do
 local f=fixture('ROUTE_1',randomized);local S=load('discovery_state');local H=load('hoenn_discovery').create(S,load('encounter_overlay'))
 local state=S.empty();state=select(1,H.planIntroduction(state,{eligible=true,mapId='ROUTE_1',registeredFamilies={'TREECKO'},chanceRoll=1,familyRoll=1,token='fixture'}))
 H.registeredFamilies=function()return{'TREECKO'}end
 local C=H.attach(f.mod,{state={root=function()return state end,replace=function(v)state=v end},runRules=f.rules,fieldAccess={encountersEnabled=function()return true end}});C.game=f.game
 local ctx={mapId='ROUTE_1',terrain='grass',rng=function()return 1 end,game=f.game}
 local out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,f.def,ctx)
 out=f.resolve(out);f.emit('battle.started',{battle=f.battle(out)})
 check(S.sightingPity(state,'hoenn','TREECKO')==1,'classic Hoenn pity increments randomized='..tostring(randomized))
 local mapped=f.rules.mapVisibleWild({species='RATTATA',level=5},f.ctx)
 local output,tx=C.proposeVisible(f.game,{mapId='ROUTE_1',species=mapped.species,level=5})
 check(tx~=nil,'visible Hoenn proposal randomized='..tostring(randomized))
end

-- All three Mythic guarantees survive the full classic Randomizer chain.
for _,kind in ipairs({'echo','true','retry'})do
 local f=fixture('ROUTE_1',true);local s={echoRolls=511,echoes=0,completed={}}
 if kind~='echo'then s.sealed=true;s.echoes=3;s.trueRolls=8191 end
 if kind=='retry'then s.bound={species='MEW',level=35,retryRolls=31}end
 local m=mythic(f,s)
 local out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,f.def,f.ctx)
 out=f.resolve(out);local b=f.battle(out);f.emit('battle.started',{battle=b})
 check(b.kaMythicSignal==out.species and (out.species=='MEW'or out.species=='CELEBI'),kind..' guarantee keeps exact mythic')
 check(kind=='echo'and b.noCatch==true or kind~='echo'and b.kaMythicTrue~=nil,kind..' battle protection/catchability')
end
-- Every primal Johto trace: advance one miss and honor its existing guarantee.
for _,row in ipairs({{'CHIKORITA','forest','ROUTE_24','grass'},{'TOTODILE','coast','SEAFOAM_ISLANDS_B2F','indoor'},{'CYNDAQUIL','ember','POKEMON_MANSION_B1F','indoor'},{'LARVITAR','stone','VICTORY_ROAD_3F','indoor'}})do
 local id,trace,map,terrain=unpack(row);local f=fixture(map,true);f.ctx.terrain=terrain
 local state={receiverRepaired=true,modeChosen=true,mode='WANDERWAVES',traces={[trace]=true},rarePity={[id]=510},waveIndex=1}
 local j=load('johto_signals')(f.mod,{state={section=function()return state end,persist=function()end},johtoData={habitats={[id]={map=map,terrain=terrain,level=18}}},encounterLevels=load('johto_encounter_levels')});j.game=f.game
 for i=1,2 do
  local out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,f.def,f.ctx)
  out=f.resolve(out);f.emit('battle.started',{battle=f.battle(out)})
  if i==1 then check(state.rarePity[id]==511,id..' randomized miss counts')else check(out.species==id and state.rarePity[id]==0,id..' guaranteed trace remains authored')end
 end
end
-- Classic Hoenn guarantee and introduction remain available in randomized NG+ rules.
do
 local f=fixture('ROUTE_1',true);local S=load('discovery_state');local H=load('hoenn_discovery').create(S,load('encounter_overlay'))
 local state=S.empty();H.registeredFamilies=function()return{'TREECKO'}end
 local C=H.attach(f.mod,{state={root=function()return state end,replace=function(v)state=v end},runRules=f.rules,random=maxrng,fieldAccess={encountersEnabled=function()return true end,introductionFamilies=function()return{'TREECKO'}end}});C.game=f.game
 for i=1,8 do
  C.handleSurpriseWin({game=f.game,kind='trainer',ascendantLegacyWanderer=true,ascendantLegacyToken='win-'..i})
 end
 check(H.traceMap(state,'TREECKO')=='ROUTE_1','Hoenn introduction guaranteed after 8 eligible wins with Randomizer')
 local ctx={mapId='ROUTE_1',terrain='grass',rng=function()return 1 end,game=f.game};local hit
 for i=1,50 do
  local out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,f.def,ctx)
  out=f.resolve(out);local b=f.battle(out);f.emit('battle.started',{battle=b})
  if b.kaHoennDiscoveryFamily then hit=i;check(out.species=='TREECKO','Hoenn target survives mapping');C.completeCatch({battle=b,species='TREECKO'});break end
 end
 check(hit~=nil and hit<=50,'classic randomized Hoenn guarantee within 50')
 check(S.status(state,'hoenn','TREECKO')=='unlocked','classic Hoenn catch unlocks family')
end
-- Actual-species statistics remain independent of native encounter identity.
do
 local f=fixture('ROUTE_1',true);local shiny=load('shiny_system')(f.mod,{})
 local out=f.resolve({species='RATTATA',level=5});local b=f.battle(out)
 f.emit('battle.started',{battle=b});check(shiny.state().encounters.ABRA==1,'Shiny Dex encounter total uses randomized species')
 b.enemy.mon.dvs={attack=2,defense=10,speed=10,special=10,hp=0}
 f.emit('pokemon.caught',{battle=b,mon=b.enemy.mon,species='ABRA',game=f.game})
 check(shiny.state().caughtCounts.ABRA==1,'Shiny Dex capture total uses randomized species')
end


-- Repel/despawn and unrelated outer replacements must not earn progress.
for _,mode in ipairs({'suppressed','foreign'})do
 local f=fixture('ROUTE_1',true);local state={echoRolls=3,echoes=0,completed={}};local m=mythic(f,state)
 local out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,f.def,f.ctx)
 out=f.resolve(out)
 if mode=='suppressed'then m.cancelPending()else out.species='CELEBI'end
 f.emit('battle.started',{battle=f.battle(out)})
 check(state.echoRolls==3,'cancelled or mismatched classic battle does not count: '..mode)
end
-- Step timers and Trace Finder's rematch counter do not depend on mapping.
for _,randomized in ipairs({false,true})do
 local f=fixture('ROUTE_1',randomized)
 local W=load('world_events')(f.mod,{postgame={hasHallOfFame=function()return true end}})
 f.mod.save:set('world_events',{index=1,nextAt=9999,active={id='training_rush',steps=20,announced=true}})
 W.onStep(f.game,100);check(f.mod.save:get('world_events').active.steps==19,'world event step countdown randomized='..tostring(randomized))
 local E=load('exploration_device')(f.mod,{random=maxrng,addItem=function(g,id)g.save.inventory[id]=1;return true end})
 local result
 for i=1,E.HARD_PITY_WIN do local _,r=E.afterRematch(f.game,{rematch=true,rematchTrainerKey='ROUTE_1:1'});result=r end
 check(result and result.awarded==true,'Trace Finder guarantee randomized='..tostring(randomized))
end

print('CHECKS '..checks..' FAILURES '..failures);if failures>0 then os.exit(1)end
