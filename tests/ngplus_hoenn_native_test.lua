-- Headless engine integration. Actual bundled Wilds, WorldAPI, script runner,
-- BattleState and Randomizer; only rendering/stack presentation is stubbed.
-- KASC_ENGINE=/path/to/gen1recomp luajit tests/ngplus_hoenn_native_test.lua
local engine=assert(os.getenv('KASC_ENGINE'))
package.path='./?.lua;'..engine..'/?.lua;'..engine..'/?/init.lua;'..package.path
package.loaded['src.core.Logger']={warn=function(message)error(message)end}
local Fixtures=require('tests.modkit').fixtures
local Battle=require('src.battle.BattleState')
local Runner=require('src.script.ScriptRunner')
local World=require('src.world.WorldAPI')
local Commands=require('src.script.Commands')
local Hooks=require('src.mods.Hooks')
local S=require('discovery_state')
local H=require('hoenn_discovery').create(S,require('encounter_overlay'),require('hoenn_acquisition_67_data'))
local config={STATE={AVAILABLE='available',ENCOUNTER_STARTING='starting',IN_BATTLE='battle'}}
local libs={config=config,safari_compat={STATUS={ACTIVE='active'},
  status=function()return'none'end,isSafariMap=function()return false end}}
local Spawn=assert(loadfile('vendor/wilds_1_12_2/lib/spawn_logic.lua'))({require=function(k)return libs[k]or{}end})
local noop=function()end
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
for _,randomized in ipairs({false,true})do
  for _,target in ipairs({'POOCHYENA','LATIAS','LATIOS'})do
    for _,mode in ipairs({'success','reject-after','throw','reload','wrong-map','wrong-level','protected'})do
      local handlers,hooks={},Hooks.new()
      local events={on=function(_,k,fn,p)
        handlers[k]=handlers[k]or{};table.insert(handlers[k],{fn=fn,p=p or 0})
      end}
      function events:emit(k,ev)
        local rows=handlers[k]or{};table.sort(rows,function(a,b)return a.p>b.p end)
        for _,row in ipairs(rows)do row.fn(ev)end
      end
      local data=Fixtures.fresh()
      for _,id in ipairs({'RATTATA','ABRA','POOCHYENA','LATIAS','LATIOS'})do
        local def={};for k,v in pairs(data.pokemon.FIXMON_A)do def[k]=v end
        def.id,def.name=id,id;data.pokemon[id]=def
      end
      data.pokemon.RATTATA.dex=19;data.pokemon.ABRA.dex=63
      data.pokemon.POOCHYENA.dex=261;data.pokemon.LATIAS.dex=380;data.pokemon.LATIOS.dex=381
      data.encounters={ROUTE_1={grass={rate=25,slots={{species='RATTATA',level=5}}}},
        ROUTE_2={grass={rate=25,slots={{species='RATTATA',level=5}}}}}
      local game={version='red',data=data,save={inventory={},party={},pokedex={seen={},owned={}},
        player={name='TEST'},modData={}},overworld={map={id='ROUTE_1'},afterBattle=noop}}
      game.save.party={require('src.pokemon.Pokemon').new(data,'FIXMON_A',40)}
      game.stack={top=function()return game.overworld end,push=noop}
      local saved={}
      local mod={id='kanto_ascendant',hooks=hooks,events=events,ui={},
        content={items={register=noop}},options={get=function()return true end},
        save={get=function(_,k)return saved[k]end,set=function(_,k,v)saved[k]=v end}}
      require('src.mods.Runtime').install(events,hooks)
      local runRules=dofile('run_rules.lua')(mod,{})
      runRules.game=game;runRules.buildPool(game)
      local settings=runRules.state(game.save)
      settings.version=4;settings.seed=2712;settings.locked=true;settings.lockReason='player_pc'
      settings.randomizer.enabled=randomized;settings.randomizer.wild=true
      settings.randomizer.similarStrength=false;settings.randomizer.excludeLegendaries=false
      settings.nuzlocke.mode='off';settings.mappings.species.RATTATA='ABRA'
      settings.mappings.species['wild:RATTATA']='ABRA';settings.finalRules=nil
      runRules.state(game.save)
      local access={encountersEnabled=function()return true end,isLegacy=function()return true end,
        legendAccess=function()return target~='POOCHYENA'end,
        legacyFamilies=function()return{POOCHYENA=true}end}
      local R=dofile('hoenn_roamers_67.lua')(mod,{fieldAccess=access,randomInt=function(low)return low end})
      R.install(game,{battleState=Battle})
      if target~='POOCHYENA'then
        local s=R.state(false)
        s.roamers.LATIAS.map=target=='LATIAS'and'ROUTE_1'or'ROUTE_2'
        s.roamers.LATIOS.map=target=='LATIOS'and'ROUTE_1'or'ROUTE_2'
        s.roamers[target].hp=17;s.roamers[target].status='PARALYSIS';s.roamers[target].dvs={attack=6}
        mod.save:set(R.SAVE_KEY,s)
      end
      local root=S.empty()
      H.registeredFamilies=function()return{'POOCHYENA'}end
      local C=H.attach(mod,{state={root=function()return root end,replace=function(v)root=v end},
        fieldAccess=access,runRules=runRules,roamers=R,BattleState=Battle,random=function(_,high)return high end})
      C.game=game
      local created
      game.stack.push=function(_,battle)created=battle end
      Commands.pushBattle=function(_,battle)created=battle end
      game.overworld.runner=Runner.new(game,game.overworld)
      local world={game=game,overworld=function()return game.overworld end}
      function world:queueScript(rows)
        if mode=='throw'then error('expected queue failure')end
        local ok,why=World.queueScript(self,rows)
        if mode=='reject-after'then return false,'expected rejection'end
        return ok,why
      end
      local logic=setmetatable({mod={world=world,log={info=noop}},spawns={},entities={},
        surfaceInfo={surface='GRASS'},state={markError=noop},_warn=noop,
        _restoreVanillaEncounters=noop,_recountRegions=noop,
        _despawn=function(self,id)self.spawns[id]=nil end},Spawn)
      C.installVisibleWilds(logic,game)
      local record={id=1,mapId='ROUTE_1',species='RATTATA',level=5,state='available',
        kaProtected=mode=='protected' or nil}
      logic.spawns[1]=record
      local factory=Battle.newWild
      local ok,result=pcall(logic._startBattle,logic,record)
      check(Battle.newWild==factory,'factory restored '..mode)
      if mode=='throw'then check(not ok,'queue exception preserved')
      else
        check(ok and created,'real engine constructed battle '..mode..': '..tostring(result))
        if mode=='reload'then events:emit('save.loaded',{game=game})end
        if mode=='wrong-map'then game.overworld.map.id='ROUTE_2' end
        if mode=='wrong-level'then created.enemy.mon.level=99 end
        events:emit('battle.started',{battle=created,kind='wild'})
        local marked=target=='POOCHYENA'and created.kaHoennDiscoveryFamily or created.kaHoennRoamer
        if mode=='success'then
          check(marked==target and created.enemy.mon.species==target,'actual protected encounter '..target)
          if target~='POOCHYENA'then
            check(created.enemy.mon.hp==17 and created.enemy.mon.status=='PARALYSIS','roamer identity survives engine')
          end
          table.insert(game.save.party,created.enemy.mon)
          events:emit('pokemon.caught',{game=game,battle=created,mon=created.enemy.mon,species=target})
          check(target=='POOCHYENA'and S.status(root,'hoenn',target)=='unlocked'
            or target~='POOCHYENA'and R.state(false).caught[target]~=nil,'actual catch commits '..target)
        else check(not marked,'no receipt for '..mode)end
      end
    end
  end
end
print('PASS native NG+ habitat/roamer integration: '..checks..' checks')
