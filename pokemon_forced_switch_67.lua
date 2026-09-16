-- Later-generation phazing on the native single-battle/party lifecycle.
-- Never use resolveSwitch: it grants a free enemy action and a second turn.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Runtime=require('src.mods.Runtime')
  local M={CARD_ID='KASC-67-FORCED-SWITCH',OWNER='kasc.forced-switch/v1'}
  local tr=opts.i18n.text;local A=opts.abilities
  local moves={ROAR=2,WHIRLWIND=2,DRAGON_TAIL=5,CIRCLE_THROW=5}
  local aliases={};for id in pairs(moves)do for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end end
  local pending=setmetatable({},{__mode='k'})
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=marker and marker.kascForcedSwitch67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.demo and not b.result and b.kind~='link'and gen and gen>=2 and gen<=7 then return gen end
  end
  function M.candidates(b,w)
    local list=w==b.player and b:playerPartyView()or w==b.enemy and b.enemyParty or{}
    local out={}
    for index,mon in ipairs(list or{})do
      if mon~=w.mon and type(mon.hp)=='number'and mon.hp>0 and not mon.isEgg and not mon.eggSpecies
          and not mon.egg and b.data.pokemon[mon.species]then out[#out+1]={mon=mon,index=index}end
    end
    return out
  end
  function M.blocker(b,w,id)
    local sky=mod.exports.pokemonSkyDrop67
    local lift=sky and sky.switchBlock(b,w)
    if lift then return lift end
    local ability=A.activeAbility(b,w)
    if ability=='SUCTION_CUPS'then return tr('Suction Cups prevents the switch!','Saugnapf verhindert den Wechsel!')end
    if id=='ROAR'and ability=='SOUNDPROOF'then return tr('Soundproof blocks Roar!','Lärmschutz blockt Brüller!')end
    local roots=mod.exports.pokemonRootRecovery67
    if w.ingrain or roots and roots.rooted(b,w)then return tr('The roots prevent switching!','Die Wurzeln verhindern den Wechsel!')end
  end
  -- Crystal checks levels only for wild escapes; Emerald/Platinum also
  -- check trainer targets. Later profiles only reject higher-level wilds.
  function M.levelAllows(b,u,t,gen)
    local ul,tl=u.mon.level,t.mon.level
    if gen==2 then return b.kind~='wild'or ul>=tl or b.rng(0,ul+tl-1)>=math.floor(tl/4)end
    if gen<=4 then return ul>=tl or math.floor(b.rng(0,255)*(ul+tl)/256)+1>math.floor(tl/4)end
    return b.kind~='wild'or ul>=tl
  end
  function M.skipsAction(b,w)
    local r=state(b);local key=b and w and side(b,w)
    local baton=mod.exports.pokemonBatonPass67
    local pivot=mod.exports.pokemonPivotMoves67
    return (M.epoch(b)or baton and baton.epoch(b)or pivot and pivot.epoch(b))and r and key and r[key]==(b.turnCount or 0)or false
  end
  local function clearNativeTrap(w)
    for _,k in ipairs({'trappingTurns','trapMove','trapDamage','trapHitSfx','boundTurns'})do w[k]=nil end
  end
  function M.isPending(w)return pending[w]==true end
  function M.swap(b,w,pick,context)
    local key=side(b,w)
    local sky=mod.exports.pokemonSkyDrop67
    if sky and sky.switchBlock(b,w)then return false end
    local interruptions=mod.exports.pokemonFieldInterruptions67
    if interruptions and interruptions.blocksSwitch(b,w,context)then return false end
    local pursuit=mod.exports.pokemonPursuit67
    if pursuit and pursuit.defer(b,w,pick,context,function()return M.swap(b,w,pick,context)end)then return true,true end
    local baton=mod.exports.pokemonBatonPass67
    local pass=context and context.sourceCard=='KASC-67-BATON-PASS'and baton and baton.epoch(b)
    local retreat=pursuit and pursuit.replacementAllowed(b,w,pick,context)
    local pivot=mod.exports.pokemonPivotMoves67
    local ownedPivot=pivot and pivot.authenticatedEpoch(b,w,context)
    if not(M.epoch(b)or pass or retreat or ownedPivot)or not key or w.mon.hp<=0 or pick.mon.hp<=0 then return false end
    local present=false;for _,candidate in ipairs(M.candidates(b,w))do
      if candidate.mon==pick.mon and candidate.index==pick.index then present=true;break end
    end
    if not present then return false end
    -- Settle both sides' HP berries before a new entry ability (e.g. Unnerve)
    -- can change whether a berry is usable. III still uses its residual rule.
    opts.berries.apply(b,true,nil,true)
    b:restoreMimicked(w)
    local fresh=B.makeBattler(b.data,pick.mon,key=='player',key=='player'and b.game.save or nil)
    b[key]=fresh
    if context and context.prepare then context.prepare(b,w,fresh)end
    if key=='enemy'then
      b.enemyIndex=pick.index;b.lastSwitchInEnemyHP=fresh.mon.hp;b.participants={}
      local dex=b.game.save.pokedex;if dex and dex.seen then dex.seen[fresh.mon.species]=true end
    else b.menuIndex=1;b.moveIndex=1;b.playerMoveListIndex=1 end
    clearNativeTrap(key=='player'and b.enemy or b.player)
    state(b,true)[key]=b.turnCount or 0
    b:syncSides();b:markParticipant()
    Runtime.emit('battle.battler_switched',{battle=b,game=b.game,battler=fresh,previous=w,
      side=b.sides[key=='player'and 1 or 2],forced=not(context and context.voluntary),sourceCard=context and context.sourceCard or M.CARD_ID})
    local text=context and context.voluntary and tr('%s entered the battle!','%s wurde eingewechselt!')
      or tr('%s was dragged out!','%s wurde herausgezogen!')
    b:sayNext(text:format(fresh.name))
    if key=='player'then b.sendingOut=true;b:queueSendOutAnim(false)
    else
      b.enemySendingOut=true
      b:actNext(function()
        b.enemySendingOut=false;b:startGrowIn(b.enemy);b:queueEnemySendOutCry(false)
      end)
    end
    return true
  end
  function M.force(ctx,damaging)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b)
    local id=aliases[ctx.move.id]or ctx.move.id
    if not gen or gen<(moves[id]or 99)or not side(b,u)or not side(b,t)
        or u==t or u.mon.hp<=0 or t.mon.hp<=0 or pending[t]then return false end
    if damaging and ((t.substituteHP or 0)>0 or ctx.brokeSub or (ctx.totalDealt or 0)<=0)then return false end
    local block=M.blocker(b,t,id)
    if block then b:sayNext(block);return false end
    if gen==2 and b.kind=='trainer'and not(b._kascFlinchActed67 and b._kascFlinchActed67[t])then return false end
    local choices=b.kind=='trainer'and M.candidates(b,t)or{}
    if b.kind=='trainer'and #choices==0 then return false end
    if not M.levelAllows(b,u,t,gen)then return false end
    if b.kind=='wild'then
      -- These encounters own their completion/reward path. Forced fleeing
      -- must not bypass the same explicit locks used by the Run command.
      if b.kaRocketNoEscape or b.kaMythicEcho then return false end
      b:sayNext(tr('The wild battle ended!','Der wilde Kampf wurde beendet!'))
      b.result='run';b.afterQueue='finish';return true
    end
    if b.kind~='trainer'then return false end
    local pick=choices[#choices==1 and 1 or b.rng(1,#choices)]
    pending[t]=true
    b:actNext(function()
      pending[t]=nil
      if side(b,u)and u.mon.hp>0 then M.swap(b,t,pick)end
    end)
    return true
  end
  local native=assert(mod.content.move_effects:get('SWITCH_AND_TELEPORT_EFFECT')).perform
  mod.content.move_effects:patch('SWITCH_AND_TELEPORT_EFFECT',{kascForcedSwitch67=M.OWNER,perform=function(ctx)
    local b=ctx.battle;local gen=M.epoch(b);local id=aliases[ctx.move.id]or ctx.move.id
    if not gen or(id~='ROAR'and id~='WHIRLWIND')then return native(ctx)end
    local guard=opts.protection.active(b,ctx.target)
    local blocked=gen<=5 and guard and guard~='ENDURE'
    if opts.priority.blocks(ctx)or blocked or ctx.target.invulnerable
        or gen<=5 and not ctx.accuracyRoll()then
      b:cancelMoveAnim();b:sayNext(tr('But, it failed!','Doch es schlug fehl!'));return
    end
    if not M.force(ctx,false)then b:cancelMoveAnim();b:sayNext(tr('But, it failed!','Doch es schlug fehl!'))end
  end})
  local function copy(v)if type(v)~='table'then return v end;local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out end
  for _,id in ipairs({'DRAGON_TAIL','CIRCLE_THROW'})do
    local fact=assert(opts.facts.move(id,5))
    assert(fact.power==60 and fact.accuracy==90 and fact.priority==-6 and fact.category=='physical')
    local effect='KA_FORCED_SWITCH_67_'..id
    mod.content.move_effects:register(effect,{kind='secondary',run=function()return{}end,
      afterDamage=function(ctx)M.force(ctx,true)end})
    local animation=copy(assert(mod.content.battle_anims:get(id=='DRAGON_TAIL'and'SLAM'or'SEISMIC_TOSS')))
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,animation)
    else mod.content.battle_anims:register(id,animation)end
    if not mod.content.moves:get(id)then
      mod.content.moves:register(id,{id=id,name=tr(fact.names.en,fact.names.de),type=fact.type,
        category=fact.category,power=fact.power,accuracy=fact.accuracy,pp=fact.pp,priority=fact.priority,
        effect=effect,contact=true,originGeneration=5,backendMoveOwner=M.OWNER,
        backendMoveNumber=fact.number,backendLearnsetRevision=4,
        anim=copy(assert(mod.content.moves:get('SLAM')).anim)})
    end
    for _,alias in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(alias)then
      mod.content.moves:patch(alias,{effect=effect,contact=true,backendLearnsetRevision=4})
    end end
  end
  function M.validateCheckpoint(b)
    local r=state(b);if not r then return true end
    if type(r)~='table'then return false,'invalid_forced_switch_state'end
    for key,turn in pairs(r)do
      if(key~='player'and key~='enemy')or type(turn)~='number'or turn%1~=0 or turn<0 or turn>(b.turnCount or 0)then
        return false,'invalid_forced_switch_turn'
      end
    end
    return true
  end
  B._kascForcedSwitch67=M
  if not B._kascForcedSwitchWrapped67 then
    local execute=B.executeAction
    B.executeAction=function(b,w,...)
      if B._kascForcedSwitch67.skipsAction(b,w)then return end
      return execute(b,w,...)
    end
    B._kascForcedSwitchWrapped67=true
  end
  local function clear(ev)if state(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end
  mod.events:on('battle.turn_started',clear,10000)
  mod.events:on('battle.ended',clear,80)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascForcedSwitch67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-party-switch-and-events',
      providerStatus='phazing-and-suction-cups',buildReceiptId='docs/FORCED_SWITCH_67.md',
      rollbackReceiptId='docs/FORCED_SWITCH_67.md'})
  end
  return M
end
