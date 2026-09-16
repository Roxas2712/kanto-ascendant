-- Status, action order and actual body-HP provenance are separate contracts.
-- Foul Play borrows only stored offense/stages, never the target's identity.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer');local Damage=assert(opts.damage)
  local M={CARD_ID='KASC-67-CONDITIONAL-POWER',OWNER='kasc.conditional-power/v1'}
  local aliases={};local frames=setmetatable({},{__mode='k'})
  local defs={FACADE={number=263,gen=3,type='NORMAL',power=70,pp=20,part='DOUBLE_EDGE'},
    FOUL_PLAY={number=492,gen=5,type='DARK',power=95,pp=15,part='BITE'},
    PAYBACK={number=371,gen=4,type='DARK',power=50,pp=10,part='BITE'},
    REVENGE={number=279,gen=3,type='FIGHTING',power=60,pp=10,priority=-4,part='COUNTER'},
    AVALANCHE={number=419,gen=4,type='ICE',power=60,pp=10,priority=-4,part='ICE_PUNCH'},
    ASSURANCE={number=372,gen=4,type='DARK',power=60,pp=10,part='BITE'},
    RETALIATE={number=514,gen=5,type='NORMAL',power=70,pp=5,part='DOUBLE_EDGE'}}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function id(move)return move and(aliases[move.id]or move.id)end
  local function side(b,w)
    return b and w and w.mon and(w.mon==b.player.mon and'player'or w.mon==b.enemy.mon and'enemy'or nil)
  end
  local function party(b,key)
    if key=='player'then return b.game and b.game.save and b.game.save.party end
    if key=='enemy'then return b.enemyParty or b.enemy and b.enemy.mon and{b.enemy.mon}end
  end
  local function index(b,w)
    local key=side(b,w);for i,m in ipairs(party(b,key)or{})do if m==w.mon then return i end end
  end
  local function live(w)
    local m=w and w.mon;return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
      and not(m.isEgg or m.is_egg or m.egg or m.eggSpecies or m.status=='EGG')
  end
  function M.epoch(b,w,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or type(r.activeEpoch)~='number'or r.activeEpoch%1~=0 or r.activeEpoch<1 or r.activeEpoch>7
        or not marker or marker.kascConditionalPower67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local d=defs[id(move)];local record=b.data.move_effects[move.effect]
    if not d or move.backendMoveOwner~=M.OWNER or not record or record.kascConditionalPower67~=M.OWNER then return end
    if r.activeEpoch<d.gen and not(live(w)and opts.rules.monMoveAvailable
        and opts.rules.monMoveAvailable(b.game,w.mon,move.id,r.activeEpoch,true))then return end
    return math.max(d.gen,r.activeEpoch)
  end
  local function state(b,create)
    if create then
      b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{turn=b.turnCount or 0,acted={},switched={},hurt={},attacked={},fainted={}}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function current(b)
    local r=state(b);return r and r.turn==(b.turnCount or 0)and r
  end
  function M.power(b,u,t,move)
    local gen=M.epoch(b,u,move);if not gen or not live(u)or not live(t)or u.mon==t.mon
        or not side(b,u)or not side(b,t)then return end
    local name=id(move);local d=defs[name];local power=name=='ASSURANCE'and(gen<=5 and 50 or 60)or d.power
    local r=current(b);local us,ts=side(b,u),side(b,t)
    if name=='FACADE'then
      local status=u.mon.status
      if status and status~='SLP'and status~='slp'and u.statuses and u.statuses[status]then power=power*2 end
    elseif name=='PAYBACK'then
      if r and r.acted[ts]and not(gen>=5 and r.switched[ts])then power=power*2 end
    elseif name=='REVENGE'or name=='AVALANCHE'then
      local hit=r and r.attacked[us]
      if hit and hit.index==index(b,u)and hit.sources[tostring(index(b,t))]then power=power*2 end
    elseif name=='ASSURANCE'then
      local hurt=r and r.hurt[ts];if hurt and hurt.index==index(b,t)then power=power*2 end
    elseif name=='RETALIATE'then
      if r and r.fainted[us]==(b.turnCount or 0)-1 then power=power*2 end
    end
    return power
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local power=M.power(b,u,t,move)
    if not power then return nextDamage(ctx)end
    local out=shallow(ctx);out.move=copy(move);out.move.id=id(move);out.move.power=power
    -- These moves retain their source-era category for a legitimate later
    -- gift, while actual conversion owners may subsequently change its type.
    out.move.category=assert(opts.facts.move(id(move),M.epoch(b,u,move))).category
    out.opts=copy(ctx.opts or{})
    local f=frames[b]
    if not(f and f.user.mon==u.mon and f.target.mon==t.mon and id(f.move)==id(move))then
      out.opts.forceCrit=false;out.opts.rng=function(_,hi)return hi end
    end
    if id(move)=='FACADE'and M.epoch(b,u,move)>=6 then
      assert(Damage.kascConditionalPower67==M.OWNER,'Facade requires shared era-specific burn API')
      out.opts.kascFacadeNoBurn67=true
    end
    return nextDamage(out)
  end
  function M.offense(nextDamage,ctx)
    if not ctx or id(ctx.move)~='FOUL_PLAY'or not M.epoch(ctx.battle,ctx.user,ctx.move)
        or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    local u,t=ctx.user,ctx.target;if not live(u)or not live(t)or not u.curStats or not t.curStats then return nextDamage(ctx)end
    local out=shallow(ctx);out.user=shallow(u);out.user.curStats=copy(u.curStats);out.user.stages=copy(u.stages or{})
    local stat=ctx.move.category=='special'and'special'or'attack'
    out.user.curStats[stat]=t.curStats[stat];out.user.stages[stat]=t.stages and t.stages[stat]or 0
    -- User level, type, ability, item, status and native identity are intact.
    -- The following actual Ability/Held owners modify THIS borrowed offense.
    return nextDamage(out)
  end
  function M.begin(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local old=state(b);local first=(b.turnCount or 0)==1 and old and old.turn==0
    local r=state(b,true);r.turn=b.turnCount or 0;r.acted={};r.switched={};r.attacked={}
    if not first then r.hurt={}end
    for key,turn in pairs(r.fainted)do if turn<r.turn-1 then r.fainted[key]=nil end end
    for _,key in ipairs({'player','enemy'})do
      -- External item/switch/run turns were consumed before the host emits
      -- their special turn. Pending recharge/charge/Bide actions have NOT
      -- acted yet; executeAction records their real attempt later.
      local a=ev[key..'Action'];local special=a and a.special
      if special=='item'or special=='switch'or special=='run'then r.acted[key]=true end
    end
  end
  function M.hit(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local body=assert(mod.exports.pokemonBodyCounter67,'conditional power needs native body-hit owner')
    assert(type(body.nativeHit)=='function','conditional power needs pure nativeHit provenance API')
    local hit=body.nativeHit(b,ev)
    if not hit or not hit.direct or hit.substitute or hit.damage<=0 or hit.user.mon==hit.target.mon then return end
    local target,source=side(b,hit.target),side(b,hit.user)
    local ti,si=index(b,hit.target),index(b,hit.user)
    if not target or not source or target==source or not ti or not si then return end
    local r=state(b,true);local row=r.attacked[target]
    if not row or row.index~=ti then row={index=ti,sources={}};r.attacked[target]=row end
    row.sources[tostring(si)]=true
  end
  function M.hurt(original,b,w,amount,...)
    local before=w and w.mon and w.mon.hp;local out=pack(original(b,w,amount,...))
    local gen=M.epoch(b);if not gen then return unpack(out,1,out.n)end
    local key,slot=side(b,w),index(b,w)
    local f=frames[b];local directStruggle=f and f.user.mon==w.mon
      and(id(f.move)=='STRUGGLE'or f.moveInst and f.moveInst.struggle)and gen>=4
    if key and slot and type(before)=='number'and w.mon.hp<before and not directStruggle then
      state(b,true).hurt[key]={index=slot}
    end
    return unpack(out,1,out.n)
  end
  function M.action(original,b,u,t,a,...)
    if M.epoch(b)and live(u)and live(t)and side(b,u)and a then state(b,true).acted[side(b,u)]=true end
    return original(b,u,t,a,...)
  end
  function M.switch(ev)
    local b=ev and ev.battle;local w=ev and ev.battler;local key=M.epoch(b)and side(b,w)
    if not key or not ev.previous then return end
    local r=state(b,true);r.acted[key]=true;r.switched[key]=true;r.hurt[key]=nil;r.attacked[key]=nil
  end
  function M.faint(ev)
    local b,w=ev and ev.battle,ev and ev.battler
    local key=M.epoch(b)and side(b,w)
    if key and index(b,w)and w.mon.hp==0 and w.faintQueued==true then state(b,true).fainted[key]=b.turnCount or 0 end
  end
  function M.run(original,b,ctx,record)
    if not M.epoch(b)then return original(b,ctx,record)end
    local prior=frames[b];frames[b]=ctx;local out=pack(pcall(original,b,ctx,record));frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'conditional_power_unsettled'end
    local r=state(b);if r==nil then return true end
    local function integer(v,lo,hi)return type(v)=='number'and v%1==0 and v>=lo and v<=hi end
    if type(r)~='table'or not integer(r.turn,0,b.turnCount or 0)or r.turn~=(b.turnCount or 0)then return false,'invalid_conditional_turn'end
    local fields={turn=true,acted=true,switched=true,hurt=true,attacked=true,fainted=true}
    for key in pairs(r)do if not fields[key]then return false,'unknown_conditional_field'end end
    for _,name in ipairs({'acted','switched','hurt','attacked','fainted'})do
      if type(r[name])~='table'then return false,'invalid_conditional_container'end
      for key,row in pairs(r[name])do
        if key~='player'and key~='enemy'then return false,'invalid_conditional_side'end
        if name=='acted'or name=='switched'then if row~=true then return false,'invalid_conditional_action'end
        elseif name=='fainted'then if not integer(row,0,r.turn)then return false,'invalid_conditional_faint'end
        else
          if type(row)~='table'or not integer(row.index,1,#(party(b,key)or{}))then return false,'invalid_conditional_identity'end
          for k in pairs(row)do if k~='index'and not(name=='attacked'and k=='sources')then return false,'unknown_conditional_hit_field'end end
          if name=='attacked'then
            if type(row.sources)~='table'then return false,'invalid_conditional_sources'end
            local other=key=='player'and'enemy'or'player'
            for slot,value in pairs(row.sources)do
              if type(slot)~='string'or tostring(tonumber(slot))~=slot or not integer(tonumber(slot),1,#(party(b,other)or{}))
                  or value~=true then return false,'invalid_conditional_source_identity'end
            end
          end
        end
      end
    end
    return true
  end
  for _,name in ipairs({'FACADE','FOUL_PLAY','PAYBACK','REVENGE','AVALANCHE','ASSURANCE','RETALIATE'})do
    local d=defs[name];local fact=assert(opts.facts.move(name,math.max(6,d.gen)));local old=assert(mod.content.moves:get(name))
    assert(fact.number==d.number and fact.generation==d.gen and fact.type==d.type and fact.category=='physical'
      and fact.power==d.power and fact.pp==d.pp and fact.accuracy==100 and fact.priority==(d.priority or 0),
      'conditional power source drift '..name)
    assert(not old.backendMoveOwner and old.effect=='NO_ADDITIONAL_EFFECT','foreign conditional power owner '..name)
    local effect='KA_CONDITIONAL_POWER_67_'..name
    mod.content.move_effects:register(effect,{kind='full',kascConditionalPower67=M.OWNER,
      gate=function(ctx)
        local b=ctx.battle
        if(ctx.user==b.player or ctx.user==b.enemy)and(ctx.target==b.player or ctx.target==b.enemy)
            and M.epoch(b,ctx.user,ctx.move)and M.power(b,ctx.user,ctx.target,ctx.move)then return true end
        return false,opts.i18n.text('But, it failed!','Doch es schlug fehl!')
      end})
    for _,alias in ipairs(opts.species.moveIds(name))do if mod.content.moves:get(alias)then
      aliases[alias]=name;mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,originGeneration=d.gen,backendMoveNumber=d.number,
        power=d.power,pp=d.pp,accuracy=100,target=10,contact=true,priority=d.priority or 0,
        anim=copy(assert(mod.content.moves:get(d.part)).anim)})
    end end;aliases[name]=name
    local anim=copy(assert(mod.content.battle_anims:get(d.part)));anim.source=M.OWNER
    if mod.content.battle_anims:get(name)then mod.content.battle_anims:patch(name,anim)
    else mod.content.battle_anims:register(name,anim)end
  end
  function M.position(player,name)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[name]
    if not defs[name]or not row or row.source~=M.OWNER then return end
    local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
    for _,step in ipairs(player.steps or{})do local sprites={};local shift=-16
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        local x,y=q.x-8,q.y-16
        for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    B._kascConditionalPower67=M;FX._kascConditionalPower67=M;Player._kascConditionalPower67=M
    if not B._kascConditionalPowerWrapped67 then
      local damage,action=B.applyDamage,B.executeAction
      B.applyDamage=function(...)return B._kascConditionalPower67.hurt(damage,...)end
      B.executeAction=function(...)return B._kascConditionalPower67.action(action,...)end
      B._kascConditionalPowerWrapped67=true
    end
    if not FX._kascConditionalPowerWrapped67 then local run=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascConditionalPower67.run(run,...)end;FX._kascConditionalPowerWrapped67=true end
    if not Player._kascConditionalPowerWrapped67 then local start=Player.start
      Player.start=function(self,name,...)local out=pack(start(self,name,...));Player._kascConditionalPower67.position(self,name);return unpack(out,1,out.n)end
      Player._kascConditionalPowerWrapped67=true
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascConditionalPower67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,31540);mod.hooks:wrap('battle.damage',M.offense,-6900)
  mod.events:on('battle.turn_started',M.begin,7000);mod.events:on('battle.damage_dealt',M.hit,1100)
  mod.events:on('battle.battler_switched',M.switch,8000);mod.events:on('battle.fainted',M.faint,8000)
  mod.events:on('battle.ended',function(ev)if ev and ev.battle then frames[ev.battle]=nil
    if state(ev.battle)then ev.battle.field.tokens[M.OWNER]=nil end end end,8000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='native-body-hit-action-and-body-hp-provenance',providerStatus='era-correct-conditional-power-and-user-owned-foul-play',
    buildReceiptId='docs/CONDITIONAL_POWER_67.md',rollbackReceiptId='docs/CONDITIONAL_POWER_67.md'})end
  return M
end
