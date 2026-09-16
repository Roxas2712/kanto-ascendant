-- Trump Card reads actual post-deduction PP; Wring Out/Crush Grip target HP.
-- Per-use move views only: no save edits, PP reservations or live power cache.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-PP-HP-POWER',OWNER='kasc.pp-hp-power/v1'}
  local frames=setmetatable({},{__mode='k'})
  local definitions={TRUMP_CARD={number=376,category='special',always=true,parts={'PAY_DAY','FOCUS_ENERGY'}},
    WRING_OUT={number=378,category='special',parts={'BIND'}},
    CRUSH_GRIP={number=462,category='physical',parts={'BIND','COMET_PUNCH'}}}
  local tr=opts.i18n.text
  local function copy(v)
    if type(v)~='table'then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  local function pack(...)return {n=select('#',...),...}end
  local function live(w)
    local m=w and w.mon
    return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
      and not(m.isEgg or m.egg or m.is_egg or m.eggSpecies)
  end
  local function scope(b)
    local r=b and b.kascGenerationRulesReceipt
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch%1==0 and r.activeEpoch>=1 and r.activeEpoch<=7 then return r.activeEpoch end
  end
  function M.epoch(b,u,move)
    local gen=scope(b);local d=move and definitions[move.id]
    local record=d and b and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    if not gen or not d or move.backendMoveOwner~=M.OWNER or move.kascPpHpPower67~=M.OWNER
        or not record or record.kascPpHpPower67~=M.OWNER then return end
    if gen<4 then
      local valid=live(u)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species])
      if not valid then return end
    end
    return math.max(4,gen)
  end
  local function slot(w,id,preferred)
    for _,s in ipairs(w and w.curMoves or{})do if s==preferred and s.id==id then return s end end
    for _,s in ipairs(w and w.curMoves or{})do if s.id==id then return s end end
  end
  function M.ppPower(pp)
    return pp==0 and 200 or pp==1 and 80 or pp==2 and 60 or pp==3 and 50 or 40
  end
  function M.hpPower(gen,hp,maxHP)
    if type(hp)~='number'or type(maxHP)~='number'or hp<=0 or maxHP<=0 then return end
    hp=math.min(hp,maxHP)
    if gen<=4 then return math.floor(hp*120/maxHP)+1 end
    return math.max(1,math.floor(math.floor((120*(100*math.floor(hp*4096/maxHP))+2047)/4096)/100))
  end
  function M.ppRemaining(b,u,t,move)
    local frame=frames[b]
    if frame and frame.ready and frame.user==u and frame.id==move.id then
      local own=slot(u,frame.sourceId,not frame.called and frame.inst or nil)
      return own and math.max(0,math.floor(tonumber(own.pp)or 0))or nil
    end
    local own=slot(u,move.id);if not own then return end
    local remaining=math.max(0,math.floor(tonumber(own.pp)or 0))
    local actualGen=scope(b);if not actualGen then return end
    local finite=u.isPlayer or not(b.ruleset and b.ruleset.enemyUnlimitedPP)
      or actualGen>=2 and opts.pp and opts.pp.epoch(b)~=nil
    if finite then remaining=math.max(0,remaining-1)end
    -- Forecast only. Native Pressure owns actual extra deduction at move_used.
    if actualGen>=3 and opts.pressure and opts.pressure.epoch(b)and live(t)
        and opts.abilities.activeAbility(b,t)=='PRESSURE'
        and opts.pressure.targetsFoe(b,u,move,actualGen)then remaining=math.max(0,remaining-1)end
    return remaining
  end
  function M.power(b,u,t,move)
    local gen=M.epoch(b,u,move)
    if not gen or not live(u)or not live(t)then return end
    if move.id=='TRUMP_CARD'then return M.ppPower(M.ppRemaining(b,u,t,move))end
    return M.hpPower(gen,t.mon.hp,t.mon.stats and t.mon.stats.hp)
  end
  function M.project(b,u,t,move)
    if not move or move.kascPpHpProjected67==M.OWNER then return move end
    local power=M.power(b,u,t,move);if not power then return move end
    local out=copy(move);out.power=power;out.kascPpHpProjected67=M.OWNER;return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local move=M.project(ctx.battle,ctx.user,ctx.target,ctx.move)
    if move==ctx.move then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.move=move;return nextDamage(out)
  end
  function M.perform(original,b,u,t,inst,called)
    if not scope(b)or not live(u)or not inst then return original(b,u,t,inst,called)end
    local move=b:moveDef(inst);if not move then return original(b,u,t,inst,called)end
    local prior=frames[b];local record=b:effectRecord(move.effect)
    local sourceId=called and prior and prior.user==u and prior.callsMove and prior.id or move.id
    frames[b]={user=u,id=move.id,inst=inst,called=called,sourceId=sourceId,
      callsMove=record and record.callsMove~=nil,ready=false}
    local out=pack(pcall(original,b,u,t,inst,called));frames[b]=prior
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.makeCtx(original,b,u,t,...)
    local ctx=original(b,u,t,...);local frame=frames[b]
    -- Native PP and all move_used listeners (including Pressure) finished.
    if frame and frame.user==u and frame.id==ctx.move.id then frame.ready=true end
    ctx.move=M.project(b,u,t,ctx.move);return ctx
  end
  function M.gate(ctx)
    if not M.epoch(ctx.battle,ctx.user,ctx.move)or not live(ctx.user)or not live(ctx.target)then
      return false,tr('But, it failed!','Doch es schlug fehl!')
    end
    -- Native neverMiss also inherits Gen-I Swift's invulnerability bypass.
    -- Trump Card never misses accuracy but must not gain that Swift quirk.
    if ctx.target.invulnerable then return false,tr('The target is out of reach!','Das Ziel ist außer Reichweite!')end
    return true
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'pp_hp_power_unsettled'end
    return true
  end
  for _,id in ipairs({'TRUMP_CARD','WRING_OUT','CRUSH_GRIP'})do
    local d=definitions[id];local f=assert(opts.facts.move(id,4))
    assert(f.number==d.number and f.generation==4 and f.type=='NORMAL'and f.category==d.category
      and f.power==0 and f.accuracy==100 and (not not f.alwaysHits)==(not not d.always)
      and f.pp==5 and f.priority==0 and f.target==10,'PP/HP power source drift '..id)
    local prior=assert(mod.content.moves:get(id),'PP/HP catalog missing '..id)
    assert(not prior.backendMoveOwner and prior.effect=='NO_ADDITIONAL_EFFECT','foreign PP/HP owner '..id)
    local effect='KA_PP_HP_POWER_67_'..id
    mod.content.move_effects:register(effect,{kind='full',gate=M.gate,neverMiss=d.always or false,kascPpHpPower67=M.OWNER})
    mod.content.moves:patch(id,{effect=effect,power=1,category=d.category,type='NORMAL',pp=5,accuracy=100,
      priority=0,target=10,contact=true,originGeneration=4,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      backendLearnsetRevision=prior.backendLearnsetRevision or 1,kascPpHpPower67=M.OWNER,
      anim=copy(assert(mod.content.moves:get(d.parts[1])).anim)})
    local animation={seq={},source=M.OWNER}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do
      animation.seq[#animation.seq+1]=copy(step)
    end end
    mod.content.battle_anims:patch(id,animation)
  end
  local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
  function M.inHud(s)
    local x,y=s.x-8,s.y-16
    for _,r in ipairs(hud)do if x<r[3]and x+8>r[1]and y<r[4]and y+8>r[2]then return true end end
    return false
  end
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not definitions[id]or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do
      local shift=-16;for _,s in ipairs(step.sprites or{})do
        if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end
      end
      local sprites={};for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift
          if M.inHud(q)then q.x=0 end end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    B._kascPpHpPower67=M;FX._kascPpHpPower67=M;Player._kascPpHpPower67=M
    if not B._kascPpHpPowerWrapped67 then local original=B.performMove
      B.performMove=function(...)return B._kascPpHpPower67.perform(original,...)end;B._kascPpHpPowerWrapped67=true end
    if not FX._kascPpHpPowerWrapped67 then local original=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascPpHpPower67.makeCtx(original,...)end;FX._kascPpHpPowerWrapped67=true end
    if not Player._kascPpHpPowerWrapped67 then local original=Player.start
      Player.start=function(self,id,...)local out=pack(original(self,id,...));Player._kascPpHpPower67.position(self,id);return unpack(out,1,out.n)end
      Player._kascPpHpPowerWrapped67=true end
  end
  mod.hooks:wrap('battle.damage',M.damage,31510)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-post-pp-context-and-detached-power',providerStatus='three-source-correct-pp-target-hp-formulas',
    buildReceiptId='docs/PP_HP_POWER_67.md',rollbackReceiptId='docs/PP_HP_POWER_67.md'})end
  return M
end
