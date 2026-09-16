-- Gen VII's battle-long bond forms. Canonical species/ability/graphics stay
-- saved unchanged; only the native HP maximum is temporarily extended.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local FX=require('src.battle.EffectRegistry')
  local Stats=require('src.pokemon.Stats')
  local M={CARD_ID='KASC-67-BOND-FORMS',OWNER='kasc.bond-forms/v1'}
  local forms,identity=assert(opts.forms),assert(opts.identity)
  local targets={['form:10116']='form:10117',
    ['form:10118']='form:10120',['form:10119']='form:10120'}
  local power={['form:10118']=true,['form:10119']=true}
  local expected={['form:10116']='BATTLE_BOND',
    ['form:10118']='POWER_CONSTRUCT',['form:10119']='POWER_CONSTRUCT'}
  local frames=setmetatable({},{__mode='k'})
  local function copy(t)local out={};for k,v in pairs(t or{})do out[k]=v end;return out end
  local function pack(...)return{n=select('#',...),...}end
  assert(type(forms.registerExternalSet)=='function','Bond forms: HP form-set owner not ready')
  assert(forms.registerExternalPair('form:10116','form:10117','BATTLE_BOND',7))
  assert(forms.registerExternalSet({'form:10118','form:10119'},'form:10120','POWER_CONSTRUCT',7))
  local bridge=Stats._kascBondFormsBridge67
  if not bridge then
    bridge={byDvs=setmetatable({},{__mode='k'})};Stats._kascBondFormsBridge67=bridge
  end
  local function state(b,create)
    if create then
      b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{records={}}
    end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function party(b,lane)
    if lane=='player'then return b.game and b.game.save and b.game.save.party end
    return b.enemyParty or{b.enemy and b.enemy.mon}
  end
  local function lane(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function slot(b,w)
    local side=w and lane(b,w)
    if side then for i,mon in ipairs(party(b,side)or{})do
      if mon==w.mon and i<=6 then return side..':'..i end
    end end
  end
  local function monFor(b,id)
    local side,index;if type(id)=='string'then side,index=id:match('^(%a+):([1-6])$')end
    if side~='player'and side~='enemy'then return end
    return (party(b,side)or{})[tonumber(index)]
  end
  local function record(b,w)
    local s,k=state(b),slot(b,w);local r=s and k and s.records[k]
    return r and w.mon.species==r.species and r or nil
  end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.result and r and r.kascBondForms67==M.OWNER
      and opts.status.epoch(b)==7 and 7 or nil
  end
  local function special(base,mon)
    local dv=mon.dvs and mon.dvs.special or 0
    local exp=mon.statExp and mon.statExp.special or 0
    local ev=math.floor(math.min(255,math.ceil(math.sqrt(math.max(0,exp))))/4)
    return math.floor(((base+dv)*2+ev)*(mon.level or 1)/100)+5
  end
  local function projected(b,mon,key)
    local base=assert(opts.facts.baseStats(key,7),'Bond form stats unavailable')
    local ex=mod.exports or{};local iv=ex.daycare and ex.daycare.breedingIVs
    local modern=iv and iv.stats(b.game,mon,7,base)
    if modern then return modern end
    local out=Stats.calc({baseStats={hp=base.hp,attack=base.atk,defense=base.def,
      speed=base.spe,special=base.spa}},mon.level,mon.dvs,mon.statExp)
    out.specialAttack=special(base.spa,mon);out.specialDefense=special(base.spd,mon)
    return out
  end
  local function bind(b,mon,r)
    if type(mon.dvs)=='table'then
      bridge.byDvs[mon.dvs]=setmetatable({battle=b,mon=mon},{__mode='v'})
    end
  end
  local function applyStats(b,w,r)
    local stats=projected(b,w.mon,r.form);local current=copy(w.curStats)
    for _,key in ipairs({'attack','defense','speed','special','specialAttack','specialDefense'})do
      current[key]=stats[key]
    end
    current.hp=r.formHP;w.curStats=current
  end
  local function eligible(b,w,key)
    return M.epoch(b)and key and targets[key]and w and w.mon and w.mon.hp>0 and slot(b,w)
      and not identity.transformed(w)and not w._ascMegaProfile
      and not w.mon._ascMegaForm and not w.mon.ascMegaForm
      and opts.abilities.activeAbility(b,w)==expected[key]
  end
  function M.changed(b,w)
    local r=w and record(b,w);return r and r.form or nil
  end
  function M.savedBase(b,mon)
    -- Shared IV reconstruction must not clamp the temporary native maximum
    -- before checkpoint continuation. Keep saved non-HP base stats canonical.
    local s=M.epoch(b)and state(b)
    for id,r in pairs(s and s.records or{})do
      if monFor(b,id)==mon and mon.species==r.species and power[r.source]then
        local base=copy(assert(opts.facts.baseStats(r.source,7)))
        base.hp=assert(opts.facts.baseStats(r.form,7)).hp
        return base
      end
    end
  end
  local function activate(b,w,key)
    if not eligible(b,w,key)or record(b,w)then return false end
    local source,target=projected(b,w.mon,key),projected(b,w.mon,targets[key])
    local r={species=w.mon.species,source=key,form=targets[key],
      baseHP=source.hp,formHP=target.hp,turn=b.turnCount or 0}
    state(b,true).records[slot(b,w)]=r
    if power[key]then
      -- Pokemon.updateMaxHp: keep HP lost, not a percentage, and never
      -- revive a fainted holder. This is a form change, not a healing move.
      local lost=math.max(0,w.mon.stats.hp-w.mon.hp)
      w.mon.stats=copy(w.mon.stats);w.mon.stats.hp=r.formHP
      w.mon.hp=math.max(1,r.formHP-lost)
    end
    bind(b,w.mon,r)
    forms.change(b,w,r.form,7,true);applyStats(b,w,r)
    b:sayNext(opts.i18n.text(power[key]and'Power Construct!\nIts form changed!'
      or'Battle Bond!\nIts form changed!',power[key]and'Scharwandel!\nSeine Form verändert sich!'
      or'Freundschaftsakt!\nSeine Form verändert sich!'))
    return true
  end
  function M.residual(ev)
    local b,turn=ev and ev.battle,ev and ev.turn
    if not M.epoch(b)or type(turn)~='number'or turn%1~=0 or turn<1 then return end
    local s=state(b,true);if s.lastTurn==turn then return end;s.lastTurn=turn
    for _,w in ipairs({b.player,b.enemy})do
      local key=opts.species.bySpecies[w.mon.species]
      if power[key]and w.mon.hp>0 and w.mon.hp*2<=w.mon.stats.hp then activate(b,w,key)end
    end
  end
  local function anotherFoe(b,w,target)
    local mons=w==b.player and party(b,'enemy')or b:playerPartyView()
    for _,mon in ipairs(mons or{})do if mon~=target.mon and (tonumber(mon.hp)or 0)>0 then return true end end
    return false
  end
  function M.afterKnockout(b,w,t,move,receipt)
    if not receipt or not receipt.direct or not move or move.category=='status'
        or not w or not t or lane(b,w)==nil or lane(b,t)==nil or lane(b,w)==lane(b,t)
        or t.mon.hp>0 or w.mon.hp<=0 or not anotherFoe(b,w,t)then return false end
    local key=opts.species.bySpecies[w.mon.species]
    return key=='form:10116'and activate(b,w,key)or false
  end
  function M.shuriken(b,w,move)
    return M.epoch(b)and move and move.id=='WATER_SHURIKEN'and w and w.mon
      and w.mon.hp>0 and lane(b,w)and not identity.transformed(w)
      and M.changed(b,w)=='form:10117'and forms.currentKey(b,w)=='form:10117'
      and opts.abilities.activeAbility(b,w)=='BATTLE_BOND'or false
  end
  function M.shurikenProfile(b,ctx)
    if ctx and M.shuriken(b,ctx.user,ctx.move)then return{min=3,max=3,generation=7},7 end
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not M.shuriken(ctx.battle,ctx.user,ctx.move)
        or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage or ctx.opts.typelessMove)then return nextDamage(ctx)end
    local adjusted=copy(ctx);adjusted.move=copy(ctx.move);adjusted.move.power=20
    return nextDamage(adjusted)
  end
  function M.context(original,b,w,t,move,...)
    -- Ordinary multihit owns one accuracy receipt by ctx.move identity.
    -- Reuse this already detached per-use view for later strike contexts,
    -- rather than cloning again and accidentally bypassing its hit counter.
    if M.shuriken(b,w,move)and move.kascBondShurikenProjection67~=M.OWNER then
      move=copy(move);move.power=20;move.kascBondShurikenProjection67=M.OWNER
    end
    return original(b,w,t,move,...)
  end
  function M.run(original,b,ctx,rec,...)
    if not M.epoch(b)or not ctx or not ctx.user or not ctx.target then return original(b,ctx,rec,...)end
    local prior=frames[b];local f={user=ctx.user,target=ctx.target,move=ctx.move,
      livingTarget=ctx.target.mon and ctx.target.mon.hp>0};frames[b]=f
    local out=pack(pcall(original,b,ctx,rec,...));frames[b]=prior
    if not out[1]then error(out[2],0)end
    M.afterKnockout(b,f.user,f.target,f.move,{direct=f.direct==true})
    return unpack(out,2,out.n)
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    local function start(w)
      if not w or not w.mon or identity.transformed(w)then return end
      local r=record(b,w)
      if r then
        bind(b,w.mon,r)
        if power[r.source]then w.mon.stats=copy(w.mon.stats);w.mon.stats.hp=r.formHP end
        forms.change(b,w,r.form,7,true);applyStats(b,w,r)
      end
    end
    if ev.battler then start(ev.battler)else start(b.player);start(b.enemy)end
  end
  function M.resume(b)
    -- Rebind presentation/HP, never repeat the gain or KO trigger. The
    -- receipt is frozen in the native checkpoint, including benched slots.
    local s=state(b);if not s then return end
    for id,r in pairs(s.records)do local mon=monFor(b,id)
      if mon and mon.species==r.species then
        bind(b,mon,r)
        if power[r.source]then mon.stats=copy(mon.stats);mon.stats.hp=r.formHP end
      end
    end
    M.entry({battle=b})
  end
  local function registered(d,dvs,exp,explicit)
    if bridge.owner~=M then return end
    local link=type(dvs)=='table'and bridge.byDvs[dvs]
    local b,mon=link and link.battle,link and link.mon
    if not b or not mon or not M.epoch(b)or mon.dvs~=dvs or explicit and explicit~=mon
        or not explicit and exp~=nil and exp~=mon.statExp or d~=b.data.pokemon[mon.species]then return end
    local s=state(b)
    for id,r in pairs(s and s.records or{})do
      if monFor(b,id)==mon and r.species==mon.species and power[r.source]then return b,mon,r end
    end
  end
  function M.nativeCalc(original,d,level,dvs,exp,mon)
    local b,bound,r=registered(d,dvs,exp,mon)
    if not b then return original end
    local view=copy(bound);view.level=level;view.statExp=exp or{}
    local out=copy(original);out.hp=projected(b,view,r.form).hp
    return out -- pure; deferred native EXP calculations must not mutate tokens
  end
  function M.nativeEnsure(d,mon,hp)
    if not mon then return end
    local b,bound,r=registered(d,mon.dvs,mon.statExp,mon)
    if bound~=mon then return end
    r.baseHP=projected(b,mon,r.source).hp;r.formHP=projected(b,mon,r.form).hp
    mon.stats=copy(mon.stats);mon.stats.hp=r.formHP
    mon.hp=math.max(0,math.min(hp or mon.hp,mon.stats.hp))
  end
  function M.levelUp(ev)
    local mon=ev and ev.mon;local link=mon and bridge.byDvs[mon.dvs]
    local b=link and link.mon==mon and link.battle
    if not b or not M.epoch(b)then return end
    local s=state(b)
    for id,r in pairs(s and s.records or{})do if monFor(b,id)==mon and r.species==mon.species then
      r.baseHP=projected(b,mon,r.source).hp;r.formHP=projected(b,mon,r.form).hp
      for _,w in ipairs({b.player,b.enemy})do
        if w.mon==mon and not identity.transformed(w)then applyStats(b,w,r)end
      end
    end end
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'bond_move_unsettled'end
    local s=state(b);if s==nil then return true end
    if type(s)~='table'or type(s.records)~='table'then return false,'invalid_bond_state'end
    for k in pairs(s)do if k~='records'and k~='lastTurn'then return false,'unknown_bond_field'end end
    if s.lastTurn~=nil and(type(s.lastTurn)~='number'or s.lastTurn%1~=0 or s.lastTurn<1
        or s.lastTurn>(b.turnCount or 0))then return false,'invalid_bond_turn'end
    for id,r in pairs(s.records)do
      local mon=monFor(b,id)
      local binding=mod.exports and mod.exports.pokemonAbilityBinding67
      local ability=mon and binding and binding.view(b.game,mon,7).id
      if type(r)~='table'or not mon or r.species~=mon.species
          or opts.species.bySpecies[mon.species]~=r.source or targets[r.source]~=r.form
          or ability~=expected[r.source]
          or type(r.turn)~='number'or r.turn%1~=0 or r.turn<0 or r.turn>(b.turnCount or 0)
          or r.baseHP~=projected(b,mon,r.source).hp or r.formHP~=projected(b,mon,r.form).hp
          or power[r.source]and mon.stats.hp~=r.formHP then
        return false,'invalid_bond_identity'
      end
      for k in pairs(r)do
        if not({species=true,source=true,form=true,baseHP=true,formHP=true,turn=true})[k]then return false,'unknown_bond_record_field'end
      end
    end
    for _,w in ipairs({b.player,b.enemy})do if not identity.transformed(w)then
      local r=record(b,w);local current=forms.currentKey(b,w)
      if r and current~=r.form or not r and(current=='form:10117'or current=='form:10120')then
        return false,'bond_form_record_mismatch'
      end
    end end
    return true
  end
  function M.clear(b)
    local s=state(b);if not s then return end
    for id,r in pairs(s.records)do local mon=monFor(b,id)
      if mon and mon.species==r.species then
        if power[r.source]then
          local hp=mon.hp;local lost=math.max(0,r.formHP-hp)
          local maximum=projected(b,mon,r.source).hp
          mon.stats=copy(mon.stats);mon.stats.hp=maximum
          mon.hp=hp<=0 and 0 or math.max(1,maximum-lost)
        end
        if type(mon.dvs)=='table'then bridge.byDvs[mon.dvs]=nil end
        for _,w in ipairs({b.player,b.enemy})do if w.mon==mon then
          if not identity.transformed(w)then
            local source=projected(b,mon,r.source);local current=copy(w.curStats)
            for _,key in ipairs({'hp','attack','defense','speed','special','specialAttack','specialDefense'})do current[key]=source[key]end
            w.curStats=current
          end
          forms.detach(b,w)
        end end
      end
    end
    b.field.tokens[M.OWNER]=nil;frames[b]=nil
  end
  bridge.owner=M
  if not bridge.installed then
    local calc,ensure=Stats.calc,Stats.ensure
    Stats.calc=function(d,level,dvs,exp,mon,...)
      local out=calc(d,level,dvs,exp,mon,...)
      return bridge.owner.nativeCalc(out,d,level,dvs,exp,mon)
    end
    Stats.ensure=function(d,mon,...)
      local hp=mon and mon.hp;local out=ensure(d,mon,...)
      bridge.owner.nativeEnsure(d,mon,hp);return out
    end
    bridge.installed=true
  end
  B._kascBondForms67=M;FX._kascBondForms67=M
  if not FX._kascBondWrapped67 then
    local make,run=FX.makeCtx,FX.runDamaging
    FX.makeCtx=function(...)return FX._kascBondForms67.context(make,...)end
    FX.runDamaging=function(...)return FX._kascBondForms67.run(run,...)end
    FX._kascBondWrapped67=true
  end
  mod.events:on('battle.damage_dealt',function(ev)
    local f=ev and frames[ev.battle]
    if f and f.user==ev.user and f.target==ev.target and f.move==ev.move
        and f.livingTarget and type(ev.damage)=='number'and ev.damage>0 and ev.target.mon.hp<=0 then f.direct=true end
  end,-30000)
  mod.events:on('battle.started',M.entry,-10044)
  mod.events:on('battle.battler_switched',M.entry,-10044)
  mod.events:on('battle.turn_ended',M.residual,-20002)
  mod.events:on('pokemon.level_up',M.levelUp,-20002)
  mod.events:on('battle.ended',function(ev)if ev and ev.battle then M.clear(ev.battle)end end,20001)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascBondForms67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,22300)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-battle-form-party-and-multihit',providerStatus='gen7-battle-long-bonds',
      buildReceiptId='docs/BOND_FORMS_67.md',rollbackReceiptId='docs/BOND_FORMS_67.md'})
  end
  return M
end
