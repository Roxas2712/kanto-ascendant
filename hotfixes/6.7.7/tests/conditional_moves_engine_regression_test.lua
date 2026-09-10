local root=assert(os.getenv('TRACE_FIX_ROOT'))
local engine=assert(os.getenv('GEN1RECOMP_DIR'))
package.path=engine..'/?.lua;'..engine..'/?/init.lua;'..(assert(os.getenv('GEN1RECOMP_TEST_DIR'), 'Set GEN1RECOMP_TEST_DIR to the engine source checkout')..'/?.lua;'..os.getenv('GEN1RECOMP_TEST_DIR')..'/?/init.lua;./?/init.lua;')..package.path
local T=require('tests.modkit');local Data=T.fixtures.fresh()
local function registry(rows)
 rows=rows or {};return {rows=rows,get=function(_,id)return rows[id]end,
 register=function(_,id,row)assert(not rows[id],id);rows[id]=row end}
end
Data.moves.TACKLE={id='TACKLE',name='Tackle',type='NORMAL',power=35,accuracy=95,pp=35,effect='NO_ADDITIONAL_EFFECT'}
Data.moves.GROWL={id='GROWL',name='Growl',type='NORMAL',power=0,accuracy=100,pp=40,effect='ATTACK_DOWN1_EFFECT'}
local effects=registry();require('src.battle.MoveEffects').registerInto(effects)
Data.move_effects=effects.rows
local events={listeners={}}
function events:on(name,fn)self.listeners[name]=self.listeners[name]or{};table.insert(self.listeners[name],fn)end
function events:emit(name,ev)for _,fn in ipairs(self.listeners[name]or{})do fn(ev)end end
local hooks=require('src.mods.Hooks').new()
require('src.mods.Runtime').install(events,hooks)
local mod={content={moves=registry(Data.moves),move_effects=effects,battle_anims=registry(Data.battle_anims)},events=events,hooks=hooks}
local C=dofile(root..'/generation_move_catalog_67.lua')(mod,{data=dofile(root..'/generation_move_catalog_67_data.lua')})
local Battle=require('src.battle.BattleState');local Pokemon=require('src.pokemon.Pokemon')
require('src.battle.TypeChart').load(Data)
local function fresh(side)
 local a=Pokemon.new(Data,'FIXMON_A',40);local b=Pokemon.new(Data,'FIXMON_A',40);a.hp=1000;b.hp=1000
 local battle=setmetatable({game={data=Data,save={party={}}},data=Data,kind='trainer',queue={},
 player=Battle.makeBattler(Data,a,true),enemy=Battle.makeBattler(Data,b,false),
 ruleset={oneIn256Miss=false,enemyUnlimitedPP=false,hyperBeamSkipRechargeOnKO=true},draws=0},Battle)
 battle.rng=function(lo,hi)battle.draws=battle.draws+1;return lo end
 battle.computeDamage=function()return 20,{crit=false,typeMult=10}end
 battle.accuracyRoll=function()return true end
 battle.onFaint=function(_,who)who.fainted=true end
 battle.animationsOn=function()return false end
 return battle,side=='enemy'and battle.enemy or battle.player,side=='enemy'and battle.player or battle.enemy
end
local n=0;local function check(v,m)n=n+1;assert(v,m)end
local function turn(b,u,t,ours,theirs)
 events:emit('battle.turn_started',{battle=b,playerAction=u==b.player and ours or theirs,enemyAction=u==b.enemy and ours or theirs})
end
for _,side in ipairs({'player','enemy'})do
 local b,u,t=fresh(side);local focus={id='FOCUS_PUNCH',pp=20};local attack={id='TACKLE',pp=20}
 turn(b,u,t,focus,attack);b:performMove(t,u,attack)
 local hp,draws=t.mon.hp,b.draws;b:performMove(u,t,focus)
 check(t.mon.hp==hp,'Focus Punch cannot damage after losing focus')
 check(focus.pp==20 and b.draws==draws,'lost focus costs neither PP nor damage RNG')
 for _,kind in ipairs({'status','substitute','broken-substitute','miss'})do
  b,u,t=fresh(side);focus={id='FOCUS_PUNCH',pp=20};attack={id=kind=='status'and'GROWL'or'TACKLE',pp=20}
  if kind=='substitute'then u.substituteHP=100 elseif kind=='broken-substitute'then u.substituteHP=1 end
  turn(b,u,t,focus,attack)
  if kind=='miss'then b.accuracyRoll=function()return false end end
  b:performMove(t,u,attack);b.accuracyRoll=function()return true end
  hp=t.mon.hp;b:performMove(u,t,focus)
  check(t.mon.hp<hp and focus.pp==19,'Focus Punch remains usable after '..kind)
 end
 b,u,t=fresh(side);focus={id='FOCUS_PUNCH',pp=20};turn(b,u,t,focus,{id='GROWL',pp=20})
 u.mon.hp=u.mon.hp-10;hp=t.mon.hp;b:performMove(u,t,focus)
 check(t.mon.hp<hp,'residual HP loss does not interrupt Focus Punch')
 for _,kind in ipairs({'attack','status','recharge','item','already-moved','no-turn'})do
  b,u,t=fresh(side);local punch={id='SUCKER_PUNCH',pp=5}
  local action=kind=='status'and{id='GROWL',pp=20}or kind=='recharge'and{special='recharge'}or kind=='item'and{special='aiItem'}or{id='TACKLE',pp=20}
  if kind~='no-turn'then turn(b,u,t,punch,action)end
  if kind=='recharge'then t.mustRecharge=true end
  if kind=='already-moved'then b:executeAction(t,u,action)end
  hp=t.mon.hp;b:performMove(u,t,punch)
  check((t.mon.hp<hp)==(kind=='attack'),'Sucker Punch condition: '..kind)
  check(punch.pp==4,'Sucker Punch attempts consume PP even on failure')
 end
 for _,rechargeId in ipairs({'GIGA_IMPACT','BLAST_BURN','HYDRO_CANNON','FRENZY_PLANT','ROCK_WRECKER','ROAR_OF_TIME'})do
 for _,kind in ipairs({'hit','ko','substitute','miss','immune'})do
  b,u,t=fresh(side)
  if kind=='ko'then t.mon.hp=1 elseif kind=='substitute'then t.substituteHP=1
  elseif kind=='miss'then b.accuracyRoll=function()return false end
  elseif kind=='immune'then b.computeDamage=function()return 0,{crit=false,typeMult=0}end end
  local move={id=rechargeId,pp=5};turn(b,u,t,move,{id='TACKLE',pp=20});b:performMove(u,t,move)
  local should=kind~='miss'and kind~='immune'
  check((u.mustRecharge==true)==should,rechargeId..' recharge after '..kind)
  if should then
   check(b:menuLockedAction(u).special=='recharge','native next-turn menu enforces recharge')
   if t.mon.hp>0 then
    hp=t.mon.hp;b:executeAction(u,t,{special='recharge'})
    check(not u.mustRecharge and t.mon.hp==hp,'recharge consumes exactly one action')
   end
  end
 end
 end
 for _,id in ipairs({'FREEZE_SHOCK','ICE_BURN'})do
  b,u,t=fresh(side);local move={id=id,pp=5};hp=t.mon.hp
  turn(b,u,t,move,{id='TACKLE',pp=20});b:performMove(u,t,move)
  check(t.mon.hp==hp and u.charging==move and move.pp==4,id..' first turn charges')
  check(not u.invulnerable,id..' charge does not hide the user')
  b:performMove(u,t,move)
  check(t.mon.hp<hp and not u.charging and move.pp==4,id..' second turn releases without extra PP')
 end
 b,u,t=fresh(side);turn(b,u,t,{id='FOCUS_PUNCH',pp=20},{id='TACKLE',pp=20})
 b:performMove(t,u,{id='TACKLE',pp=20});events:emit('battle.turn_ended',{battle=b})
 check(b._kaConditionalMoves67==nil,'turn-end clears transient tracking')
end
local Order=require('src.battle.TurnOrder');local b,u,t=fresh('player')
check(not Order.firstMover(u,Data.moves.FOCUS_PUNCH,t,Data.moves.TACKLE,function()return 0 end),'Focus Punch keeps -3 priority')
check(Order.firstMover(u,Data.moves.SUCKER_PUNCH,t,Data.moves.TACKLE,function()return 1 end),'Sucker Punch keeps +1 priority')
-- Drive real turn ordering and executeAction, not just manually constructed
-- contexts, for both user sides. Only UI queue draining is headless.
for _,side in ipairs({'player','enemy'})do
 for _,case in ipairs({{'FOCUS_PUNCH','TACKLE',false},{'FOCUS_PUNCH','GROWL',true},
   {'SUCKER_PUNCH','TACKLE',true},{'SUCKER_PUNCH','GROWL',false}})do
  local b,u,t=fresh(side);local ours={id=case[1],pp=20};local theirs={id=case[2],pp=20}
  local pa=side=='player'and ours or theirs;local ea=side=='enemy'and ours or theirs
  b.enemyAction=function()return ea end;b.actions={}
  b.act=function(self,fn)table.insert(self.actions,fn)end
  b.endOfTurn=function(self)events:emit('battle.turn_ended',{battle=self})end
  local hp=t.mon.hp;b:resolveTurn(pa)
  for _,fn in ipairs(b.actions)do fn()end
  check((t.mon.hp<hp)==case[3],case[1]..' real resolveTurn vs '..case[2]..' on '..side)
 end
end
print('CONDITIONAL MOVES ENGINE PASS: '..n..' checks, both sides, native performMove/effects/recharge')
