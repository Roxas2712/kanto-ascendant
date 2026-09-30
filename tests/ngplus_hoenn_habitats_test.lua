-- KASC_ENGINE=/path/to/gen1recomp luajit tests/ngplus_hoenn_habitats_test.lua
local engine = assert(os.getenv('KASC_ENGINE'))
package.path = './?.lua;' .. engine .. '/?.lua;' .. package.path
package.loaded['src.core.Logger'] = {warn=function(message) error(message) end}
local Hooks = require('src.mods.Hooks')
local A = dofile('hoenn_acquisition_67_data.lua')
local S = dofile('discovery_state.lua')
local H = dofile('hoenn_discovery.lua').create(S, dofile('encounter_overlay.lua'), A)
local checks = 0
local function check(value, message) checks=checks+1; assert(value, message) end
local function copy(value)
  if type(value)~='table' then return value end
  local out={} for k,v in pairs(value) do out[k]=copy(v) end return out
end
local function equal(a,b)
  if type(a)~=type(b)then return false end
  if type(a)~='table'then return a==b end
  for k,v in pairs(a)do if not equal(v,b[k])then return false end end
  for k in pairs(b)do if a[k]==nil then return false end end
  return true
end
local function fixture()
  local f={profile={},options={},legacy=true,epoch=3,reads=0}
  local hooks, handlers = Hooks.new(), {}
  local game={save={inventory={HOENN_DEX=1},party={},boxes={},pokedex={owned={}},
    modData={kanto_ascendant={legacy_journey={cycle=2}}}},
    data={pokemon={RATTATA={dex=19}},encounters={}},overworld={map={id='ROUTE_1'}}}
  f.game=game
  local mod={id='kanto_ascendant',hooks=hooks,content={items={register=function()end}},
    options={get=function(_,key)return f.options[key]end},
    events={on=function(_,key,fn,priority)
      handlers[key]=handlers[key]or{};table.insert(handlers[key],{fn=fn,p=priority or 0})
    end},save={get=function(_,key)return game.save.modData.kanto_ascendant[key]end,
      set=function(_,key,value)game.save.modData.kanto_ascendant[key]=value end}}
  local rules={shouldUseEpoch=function(_,epoch)return f.epoch>=epoch end,
    peekShouldUseEpoch=function(_,epoch)return f.epoch>=epoch end,
    speciesAvailable=function()return f.epoch>=3 end}
  f.mod,f.hooks,f.rules=mod,hooks,rules
  f.access=dofile('hoenn_field_access_67.lua')(mod,{acquisition=A,generationRules=rules,
    legacyProgression={isActive=function()return f.legacy end,
      activeCharacter=function()return f.character or 'BLUE'end,
      profile=function()f.reads=f.reads+1;return f.profile end}})
  function f.emit(key,ev)
    local rows=handlers[key]or{};table.sort(rows,function(a,b)return a.p>b.p end)
    for _,row in ipairs(rows)do row.fn(ev)end
  end
  function f.map(id)
    game.overworld.map.id=id
    game.data.encounters[id]={grass={rate=25,slots={{species='RATTATA',level=5}}}}
  end
  f.map('ROUTE_1');f.map('ROUTE_2');f.map('ROUTE_1')
  return f
end

-- Every prior character unlocks its entire ordinary pack, regardless of the
-- current character or whether any of those species were previously caught.
for _,previous in ipairs({'RED','BLUE','GREEN'})do
  for _,current in ipairs({'RED','BLUE','GREEN'})do
    local f=fixture();f.character=current
    f.profile={completedPaths={[previous:lower()]=true},pathSealCycles={[previous:lower()]=1}}
    local allowed=f.access.legacyFamilies(f.game)
    for family,owner in pairs(A.familyCharacter)do
      check((allowed[family]==true)==(owner==previous),'pack '..previous..' -> '..current..'/'..family)
    end
    check(not allowed.KYOGRE and not allowed.LATIAS,'quest species excluded')
    for _,id in ipairs(f.access.introductionFamilies(f.game,H.order))do
      check(not allowed[id],'inherited family does not consume a new Wanderer clue')
    end
    f.access.legacyFamilies(f.game);check(f.reads==1,'archive cached per save')
  end
end
do
  local f=fixture();f.profile={completedPaths={red=true},pathSealCycles={red=2}}
  check(not next(f.access.legacyFamilies(f.game)),'current-run completion waits for later journey')
  f.game.save.modData.kanto_ascendant.legacy_journey.cycle=3
  check(f.access.legacyFamilies(f.game).POOCHYENA,'next journey unlocks missed red family')
  f.legacy=false;check(not next(f.access.legacyFamilies(f.game)),'normal campaign unchanged')
end
do
  local f=fixture();f.profile={hoennDexOwned={GARDEVOIR=true},hoennCharacterPacks={RED=true}}
  local allowed=f.access.legacyFamilies(f.game)
  check(allowed.RALTS and allowed.POOCHYENA and not allowed.SEEDOT,'old archive migration')
  f.game.save.pokedex.owned.SWAMPERT=true
  check(f.access.legacyFamilies(f.game).MUDKIP,'caught evolution restores starter base')
  f.game.save.party={{species='AGGRON'}}
  check(f.access.legacyFamilies(f.game).ARON,'party recovery')
  f.game.save.party={{species='BAGON',isEgg=true,eggSpecies='BAGON'}}
  check(not f.access.legacyFamilies(f.game).BAGON,'eggs do not counterfeit catches')
  f.epoch=2;check(not next(f.access.legacyFamilies(f.game)),'generation gate')
  f.epoch=3;f.options.hoenn_encounters=false
  check(not next(f.access.legacyFamilies(f.game)),'card off')
end

-- Enumerate the entire probability space for every authored habitat. No
-- history or catch is invented, including in habitats with six families.
local eligible={} for _,id in ipairs(H.order)do eligible[id]=true end
local maps={} for _,id in ipairs(H.order)do maps[H.primaryHabitat(id).map]=true end
local root=S.empty()
for map in pairs(maps)do
  local nativeMaps=dofile(engine..'/data/generated/encounters.lua')
  check(nativeMaps[map] and nativeMaps[map].grass and nativeMaps[map].grass.rate>0,
    'authored habitat has real native encounters '..map)
  local hits=0;local roots={}
  for _,row in ipairs(H.legacyHabitats(root,map,H.order,eligible))do roots[row.species]=true end
  for roll=1,10000 do
    local out,tx=H.planFieldOverlay(root,{native={species='RATTATA',level=5},
      mapId=map,registeredFamilies=H.order,legacyEnabled=true,legacyFamilies=eligible,roll=roll})
    if tx then hits=hits+1;check(roots[out.species] and tx.mode=='legacy','base-form habitat '..map)end
  end
  check(hits==100,'exact 1% total '..map)
end
check(next(root.generations)==nil,'rolling does not grant sightings/catches')
do
  local f=fixture();local allowed={WURMPLE=true,SEEDOT=true,SLAKOTH=true,KECLEON=true}
  local seen={}
  local pool=H.legacyHabitats(root,'VIRIDIAN_FOREST',H.order,allowed)
  for index=1,#pool do
    local out=H.planFieldOverlay(root,{native={species='RATTATA',level=50},mapId='VIRIDIAN_FOREST',
      registeredFamilies=H.order,legacyEnabled=true,legacyFamilies=allowed,roll=10000,familyRoll=index})
    seen[out.species]=true
  end
  for id in pairs(allowed)do check(seen[id],'uniform selector reaches '..id)end
  local traced=select(1,S.mark(root,'hoenn','SHROOMISH','trace'))
  traced.generations.hoenn.families.SHROOMISH.traceMap='VIRIDIAN_FOREST'
  local counts={legacy=0,trace=0}
  for roll=1,10000 do
    local _,tx=H.planFieldOverlay(traced,{native={species='RATTATA',level=5},mapId='VIRIDIAN_FOREST',
      registeredFamilies=H.order,legacyEnabled=true,legacyFamilies=allowed,roll=roll})
    if tx and tx.family then counts[tx.mode]=counts[tx.mode]+1 end
  end
  check(counts.legacy==100 and counts.trace==150,'rare pool and active clues have separate bounded buckets')
end

-- Hot upgrade of an in-progress save, including a 49/50 clue belonging to
-- an earlier character pack. Preserve its guarantee and every unrelated
-- quest/bank/rules/party field; loading must not claim a catch for the player.
do
  local f=fixture();local bucket=f.game.save.modData.kanto_ascendant
  bucket.legacy_journey={cycle=3,avatar='BLUE',bankPolicy='sealed',pathComplete=false,
    completedPaths={red=true},pathSealCycles={red=0},partnerChosen=true}
  bucket.hevo_run={puzzles={ice=2},statues={blue=3},runComplete=false}
  bucket.hevo_persistent={secretUnlocks={KA_LEGEND_CAPTURE_GROUDON=true},hoennDexOwned={MILOTIC=true}}
  bucket.run_rules={seed=2712,locked=true,nuzlocke={mode='off'}}
  f.game.save.party={{species='SWAMPERT',level=52,hp=71,dvs={attack=11},nickname='PARTNER'}}
  local before=copy(f.game.save)
  local allowed=f.access.legacyFamilies(f.game)
  check(allowed.POOCHYENA and allowed.FEEBAS and allowed.MUDKIP,'existing NG+ derives catchup immediately')
  check(equal(before,f.game.save),'eligibility leaves ongoing gameplay byte-structure intact')
  local live=select(1,S.mark(S.empty(),'hoenn','POOCHYENA','trace'))
  live.generations.hoenn.families.POOCHYENA.traceMap='ROUTE_1'
  live=S.setSightingPity(live,'hoenn','POOCHYENA',49)
  live.generations.hoenn.futureMetadata={keep=true}
  local old=copy(live)
  local out,tx=H.planFieldOverlay(live,{native={species='RATTATA',level=5},mapId='ROUTE_1',
    registeredFamilies=H.order,legacyEnabled=true,legacyFamilies=allowed,roll=1})
  check(out.species=='POOCHYENA' and tx.guaranteed and tx.mode=='trace','old 49/50 trace still guarantees encounter')
  check(equal(old,live),'proposal preserves old counters and future fields')
  local battle={game=f.game,kind='wild',encounterSource='wild',enemy={mon={species=out.species,level=out.level}}}
  local committed,ok=H.commitStarted(live,tx,{battle=battle,mapId='ROUTE_1'})
  check(ok and S.sightingPity(committed,'hoenn','POOCHYENA')==0,'only actual battle updates clue')
  local caught=H.completeCatch(committed,{family=tx.family,species=out.species,mapId='ROUTE_1',serial=tx.serial})
  check(#H.legacyHabitats(caught,'ROUTE_1',H.order,allowed)==1,'completed old clue moves to 1% repeat pool')
  check(caught.generations.hoenn.futureMetadata.keep,'future metadata preserved')
  f.profile={completedPaths={green=true},pathSealCycles={green=0}}
  f.game.save=copy(f.game.save) -- serialized save reloaded into a new object
  f.emit('save.loaded',{game=f.game})
  check(f.access.legacyFamilies(f.game).SEEDOT,'reload invalidates previous archive cache')
  check(equal(before.modData.kanto_ascendant.hevo_run,f.game.save.modData.kanto_ascendant.hevo_run),
    'reload preserves unfinished dungeon')
  check(f.game.save.modData.kanto_ascendant.legacy_journey.bankPolicy=='sealed','reload preserves bank lock')
end

-- Production controller/hook chain: cancellation, exact battle matching,
-- real catch receipt and visible contact all use the same inherited pool.
H.registeredFamilies=function()return H.order end -- registry completeness is outside this fixture
do
  local f=fixture();f.profile={completedPaths={red=true},pathSealCycles={red=0}}
  local state=S.empty()
  local C=H.attach(f.mod,{state={root=function()return state end,replace=function(v)state=v end},
    fieldAccess=f.access,generationRules=f.rules,random=function(_,max)return max end})
  C.game=f.game
  local ctx={game=f.game,mapId='ROUTE_1',terrain='grass',rng=function(_,max)return max end}
  local enc=f.game.data.encounters.ROUTE_1
  f.game.data.pokemon.POOCHYENA={dex=261}
  local function roll()
    return f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,enc,ctx)
  end
  local out=roll();check(out.species=='POOCHYENA','classic inherited encounter')
  check(S.status(state,'hoenn','POOCHYENA')=='unseen','proposal remains unseen')
  local battle={game=f.game,kind='wild',checkpointOrigin={kind='wild_encounter',map='ROUTE_1'},
    enemy={mon={species=out.species,level=out.level}}}
  f.emit('world.stepped',{});f.emit('battle.started',{battle=battle})
  check(not battle.kaHoennDiscoveryFamily,'cancelled proposal rejected')
  out=roll();f.emit('battle.started',{battle=battle})
  check(battle.kaHoennDiscoveryMode=='legacy','actual battle owns receipt')
  f.emit('pokemon.caught',{game=f.game,battle=battle,species=out.species})
  check(S.status(state,'hoenn','POOCHYENA')=='unlocked','catch commits family')
  check(H.traceMap(state,'POOCHYENA')=='ROUTE_1','catch retains habitat for later migration')
  local visible,tx=C.proposeVisible(f.game,{mapId='ROUTE_1',species='RATTATA',level=5})
  check(visible.species=='POOCHYENA' and tx.mode=='legacy','visible inherited encounter')
  check(not C.proposeVisible(f.game,{mapId='ROUTE_1',species='RATTATA',level=5,kaProtected=true}),'protected visible excluded')
  f.options.hoenn_encounters=false
  check(roll().species=='RATTATA','disabled classic layer')
end

-- Actual normal/NG+ activation: NG+ has no Honey visitor and must not depend
-- on that unavailable item. Normal games still require both items.
do
  local f=fixture()
  check(f.access.legendAccess(f.game) and f.access.peekLegendAccess(f.game),'NG+ Dex-only roamers')
  f.legacy=false;check(not f.access.legendAccess(f.game),'normal game still needs Honey')
  f.game.save.inventory.HOENN_HONEY=1;check(f.access.legendAccess(f.game),'normal Honey + Dex')
  f.options.hoenn_encounters=false
  check(not f.access.legendAccess(f.game) and not f.access.peekLegendAccess(f.game),'master switch stops roamers')
  f.options.hoenn_encounters=true;f.legacy=true;f.epoch=2
  check(not f.access.legendAccess(f.game),'roamer generation gate')
  f.epoch=3;f.game.save.inventory.HOENN_DEX=nil
  check(not f.access.legendAccess(f.game),'NG+ still needs Dex')
end
for _,visible in ipairs({false,true})do
  local f=fixture()
  local R=dofile('hoenn_roamers_67.lua')(f.mod,{fieldAccess=f.access,randomInt=function(low)return low end})
  R.install(f.game,{battleState={executeAction=function()end}})
  local s=R.state(false);check(s.roamers.LATIAS and s.roamers.LATIOS,'both NG+ roamers initialize')
  local map=s.roamers.LATIAS.map;f.map(map)
  local row=s.roamers.LATIAS;row.hp=12;row.status='PARALYSIS';row.dvs={attack=7}
  f.mod.save:set(R.SAVE_KEY,s)
  local out,token
  local record={mapId=map,species='RATTATA',level=5}
  local ctx={game=f.game,mapId=map,terrain='grass',rng=function(low)return low end}
  if visible then
    out,token=R.proposeVisible(f.game,record,{surface='GRASS'})
    check(not R.proposeVisible(f.game,record,{surface='WATER'}),'no water roamer')
  else
    out=f.hooks:call('encounter.roll',function()return{species='RATTATA',level=5}end,{},ctx)
  end
  check(out.species=='LATIAS' and out.level==40,'roamer proposal')
  local mon={species=out.species,level=out.level,hp=100,stats={hp=100}}
  local battle={game=f.game,kind='wild',encounterSource='wild',
    checkpointOrigin={kind='wild_encounter',map=map},enemy={mon=mon}}
  if visible then R.bindVisible(battle,token) end
  f.emit('battle.started',{battle=battle})
  check(battle.kaHoennRoamer=='LATIAS' and mon.hp==12 and mon.status=='PARALYSIS'
    and mon.dvs.attack==7,'persistent identity restored at actual start')
  mon.hp=0;f.emit('battle.ended',{battle=battle,result='win'})
  check(R.state(false).roamers.LATIAS.recovery==3,'KO recoverable')
  for _,id in ipairs({'ROUTE_2','ROUTE_1','ROUTE_2'})do f.emit('map.entered',{mapId=id})end
  check(R.state(false).roamers.LATIAS.recovery==0,'three map changes restore')
end
print('PASS NG+ Hoenn habitat and roamer checks: '..checks)
