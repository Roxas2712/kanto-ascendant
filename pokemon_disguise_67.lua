-- Gen VII Disguise blocks damage, not contact or secondary effects.
-- Busted state belongs to a battle party slot, never a saved species.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-DISGUISE',OWNER='kasc.disguise/v1'}
  local forms,identity=opts.forms,opts.identity
  local pairsByKey={['dex:778']='form:10143',['form:10144']='form:10145'}
  local frames=setmetatable({},{__mode='k'})
  local function pack(...)return{n=select('#',...),...}end
  for base,busted in pairs(pairsByKey)do forms.registerExternalPair(base,busted,'DISGUISE',7)end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{records={}}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function party(b,lane)
    if lane=='player'then return b.game and b.game.save and b.game.save.party end
    return b.enemyParty or{b.enemy and b.enemy.mon}
  end
  local function slot(b,w)
    local lane=w==b.player and'player'or w==b.enemy and'enemy'
    if lane then for i,mon in ipairs(party(b,lane)or{})do
      if mon==w.mon and i<=6 then return lane..':'..i end
    end end
  end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.result and r and r.kascDisguise67==M.OWNER
      and opts.status.epoch(b)==7 and 7 or nil
  end
  function M.busted(b,w)
    local s=state(b);local k=slot(b,w);local r=s and k and s.records[k]
    return r and r.species==w.mon.species or false
  end
  function M.ready(b,w)
    local key=w and w.mon and opts.species.bySpecies[w.mon.species]
    return M.epoch(b)and pairsByKey[key]and w.mon.hp>0 and slot(b,w)
      and not identity.transformed(w)and not w._ascMegaProfile
      and not w.mon._ascMegaForm and not w.mon.ascMegaForm
      and not M.busted(b,w)and opts.abilities.activeAbility(b,w)=='DISGUISE'
  end
  function M.absorb(b,w,amount,move)
    local f=frames[b]
    if not f or f.target~=w or not move or type(amount)~='number'or amount<=0
        or w.substituteHP~=nil and move.id~='CONFUSED' or not M.ready(b,w)then return false end
    local key=opts.species.bySpecies[w.mon.species]
    state(b,true).records[slot(b,w)]={species=w.mon.species}
    f.blocked=true;f.lastTarget=w;b.lastDamage=0
    b:sayNext(opts.i18n.text('Its disguise served as a decoy!','Sein Kostüm fängt den Treffer ab!'))
    forms.change(b,w,pairsByKey[key],7,true)
    b:sayNext(opts.i18n.text('Its disguise was busted!','Sein Kostüm ist zerbrochen!'))
    return true
  end
  function M.blockedHit(b,w)
    local f=frames[b];return f and f.lastTarget==w or false
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.target or ctx.target.substituteHP~=nil
        or not M.ready(ctx.battle,ctx.target)or ctx.move.category=='status'
        or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local adjusted={};for k,v in pairs(ctx)do adjusted[k]=v end
    adjusted.opts={};for k,v in pairs(ctx.opts or{})do adjusted.opts[k]=v end
    -- A costume hit is neither critical nor super/not-very effective.
    -- Preserve type immunity, and never change the original move/target.
    adjusted.opts.forceCrit=false;adjusted.opts.kascDisguise67=true
    return nextDamage(adjusted)
  end
  local function secondary(b,ctx,record)
    local old=ctx.target.mon.status
    local msgs=record.run(ctx)or{}
    local status=ctx.target.mon.status
    if status~=old then
      if status=='PSN'then
        local row=b:animNext(ctx.user.isPlayer and'ENEMY_HUD_SHAKE_ANIM'or'SHAKE_SCREEN_ANIM',ctx.user.isPlayer)
        row.animDelayed=true;row.hit={animType=ctx.user.isPlayer and 6 or 3}
      elseif ctx.user.isPlayer and(status=='BRN'or status=='FRZ'or status=='PAR')then
        b:animNext('ENEMY_HUD_SHAKE_ANIM',true).animDelayed=true
      end
    end
    for _,msg in ipairs(msgs)do b:sayNext(msg)end
  end
  function M.run(b,ctx,record,fn)
    if not M.epoch(b)then return fn(record)end
    local prior=frames[b];local f={target=ctx.target};frames[b]=f
    -- This seam is inside the modern multihit owner, once per strike.
    local out=pack(pcall(function()
      local result=pack(fn(record))
      if f.blocked and ctx.totalDealt==0 and ctx.target.mon.hp>0
          and record and record.run and record.kind~='primary'then secondary(b,ctx,record)end
      return unpack(result,1,result.n)
    end))
    frames[b]=prior
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local function start(w)
      if not w or not w.mon or w.mon.hp<=0 or identity.transformed(w)then return end
      local key=opts.species.bySpecies[w.mon.species]
      if pairsByKey[key]and not forms.currentKey(b,w)then
        forms.change(b,w,M.busted(b,w)and pairsByKey[key]or key,7,true)
      end
    end
    if ev.battler then start(ev.battler)else start(b.player);start(b.enemy)end
  end
  function M.faint(ev)
    local b,w=ev and ev.battle,ev and ev.battler
    if not b or not w then return end
    local s,k=state(b),slot(b,w);if s and k then s.records[k]=nil end
    if pairsByKey[opts.species.bySpecies[w.mon.species]]then forms.detach(b,w)end
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'disguise_hit_unsettled'end
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or type(s.records)~='table'then return false,'invalid_disguise_state'end
    for k in pairs(s)do if k~='records'then return false,'unknown_disguise_field'end end
    for k,r in pairs(s.records)do
      local lane,index;if type(k)=='string'then lane,index=k:match('^(%a+):([1-6])$')end
      local mons=(lane=='player'or lane=='enemy')and party(b,lane)
      local mon=mons and mons[tonumber(index)]
      if not mon or type(r)~='table'or r.species~=mon.species
          or not pairsByKey[opts.species.bySpecies[mon.species]]then return false,'invalid_disguise_identity'end
      for field in pairs(r)do if field~='species'then return false,'unknown_disguise_record_field'end end
    end
    for _,w in ipairs({b.player,b.enemy})do
      if w.mon.hp>0 and not identity.transformed(w)then
        local key=opts.species.bySpecies[w.mon.species]
        if pairsByKey[key]then
          local current=forms.currentKey(b,w)
          if M.busted(b,w)and current~=pairsByKey[key]
              or current==pairsByKey[key]and not M.busted(b,w)then
            return false,'disguise_form_record_mismatch'
          end
        end
      end
    end
    return true
  end
  function M.interrupt(original,b,w,t,...)
    if not M.epoch(b)then return original(b,w,t,...)end
    local prior=frames[b];frames[b]={target=w}
    local raw,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,who,amount)
      if who==w and M.absorb(self,who,amount,{id='CONFUSED'})then return 0 end
      if who==w and pairsByKey[opts.species.bySpecies[w.mon.species]]then
        -- Confusion hurts the Pokémon, not the Substitute in front of it.
        local sub=who.substituteHP;who.substituteHP=nil
        local out=pack(pcall(previous,self,who,amount));who.substituteHP=sub
        if not out[1]then error(out[2],0)end
        return unpack(out,2,out.n)
      end
      return previous(self,who,amount)
    end
    local out=pack(pcall(original,b,w,t,...))
    b.applyDamage=raw;frames[b]=prior
    if not out[1]then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  B._kascDisguise67=M
  if not B._kascDisguiseWrapped67 then
    local old=B.statusInterrupt
    B.statusInterrupt=function(...)return B._kascDisguise67.interrupt(old,...)end
    B._kascDisguiseWrapped67=true
  end
  mod.events:on('battle.started',M.entry,-10042)
  mod.events:on('battle.battler_switched',M.entry,-10042)
  mod.events:on('battle.fainted',M.faint,-20001)
  mod.events:on('battle.ended',function(ev)
    local b=ev and ev.battle;if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end,-20001)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascDisguise67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,21900)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-hit-form-and-party-checkpoint',providerStatus='gen7-costume',
      buildReceiptId='docs/DISGUISE_67.md',rollbackReceiptId='docs/DISGUISE_67.md'})
  end
  return M
end
