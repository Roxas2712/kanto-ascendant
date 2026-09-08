return function(game)
 io.stdout:setvbuf('no')
 assert((os.getenv('POKEPORT_IDENTITY')or''):match('^vasc%-301%-native'))
 local function wait(n)for i=1,n do coroutine.yield()end end
 local function run()
  game:startNewGame({intro=false});wait(20)
  local W=assert(game.mods.exports.kanto_ascendant.legacyWanderers)
  local P=require('src.pokemon.Pokemon');local R=require('src.mods.Runtime')
  game.save.inventory.BOULDERBADGE=1
  game.save.party={P.new(game.data,'PIKACHU',15),P.new(game.data,'PIDGEY',15),P.new(game.data,'RATTATA',15)}
  local function option(value)
   for _,o in ipairs({game.mods,game.options,game.save.options})do
    o.modOptions=o.modOptions or {};o.modOptions.kanto_ascendant=o.modOptions.kanto_ascendant or {};o.modOptions.kanto_ascendant.difficulty=value
   end
   R.emit('mod.options_changed',{game=game,mod='kanto_ascendant',modId='kanto_ascendant',key='difficulty',value=value})
  end
  local seen={}
  local function find(fn)
   if seen[fn]then return end;seen[fn]=true
   for i=1,60 do local k,v=debug.getupvalue(fn,i);if not k then break end
    if k=='startBattle' then return v end
    if type(v)=='function' then local found=find(v);if found then return found end end
   end
  end
  local start=assert(find(W.trySpawn),'startBattle fixture missing')
  local pool=W.liveTrainerPool(game);local archetype
  for _,a in ipairs(pool)do if a.class=='OPP_BUG_CATCHER' then archetype=a end end
  assert(archetype,'bug catcher missing')
  local failed=false
  for _,difficulty in ipairs({'standard','high','hard','very_hard','extreme'})do
   option(difficulty)
   local state={lossRelief=0,rotation={},wins=0}
   local tier=W.challengeTier(game,2,state);assert(tier.targetLevel==17)
   local index=archetype.partyIndexes[1];local team={{species='CATERPIE',level=17,moves={'TACKLE','STRING_SHOT'}},{species='WEEDLE',level=17,moves={'POISON_STING','STRING_SHOT'}}}
   local ow=game.overworld;local active={game=game,ow=ow,mapId=ow.map.id,archetype=archetype,partyIndex=index,team=team,tier=tier,token='qa-wanderer-'..difficulty,expBonusPercent=15}
   W.active=active
   local push=ow.pushBattle;ow.pushBattle=function()return true end
   assert(start(active));ow.pushBattle=push
   local battle=assert(active.battle)
   for _,m in ipairs(battle.enemyParty)do
    print('WANDERER_LEVEL',difficulty,'expected',tier.targetLevel,'actual',m.level)
    if m.level~=tier.targetLevel then failed=true end
   end
   W.active=nil
   local D=game.mods.exports.kanto_ascendant.difficulty
   local adjusted=D.adjustParty({{species='CATERPIE',level=15}},1)
   assert(adjusted[1].level==15+D.progressionBonus('trainer',1,difficulty),'ordinary trainer scaling changed')
   local altered=D.adjustParty({{species='CATERPIE',level=15,kaWandererTargetLevel=14}},1)
   assert(altered[1].level==adjusted[1].level and altered[1].kaWandererTargetLevel==nil,'stale adaptive marker bypassed difficulty')
  end
  local safari=false
  for _,row in ipairs(W.rewardPool(game))do if row.item=='SAFARI_BALL'then safari=true end end
  print('WANDERER_SAFARI',safari)
  assert(not safari,'Safari Ball in reward pool');assert(not failed,'adaptive levels boosted again')
  print('WANDERER_PASS')
 end
 local ok,why=xpcall(run,debug.traceback);print('WANDERER_RESULT',ok,why or '');love.event.quit(ok and 0 or 1)
end
