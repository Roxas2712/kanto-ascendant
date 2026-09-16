-- Held-item projectiles use a detached per-use view, never saved power/type.
-- Preparing a real move consumes its item BEFORE Protect/accuracy/immunity.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer');local Status=require('src.battle.StatusRegistry')
  local M={CARD_ID='KASC-67-HELD-PROJECTILES',OWNER='kasc.held-projectiles/v1'}
  local frames=setmetatable({},{__mode='k'});local A=assert(opts.abilities);local tr=opts.i18n.text
  local data=assert(opts.data);assert(data.schema=='kasc.held-projectiles-source/v1'
    and data.commit=='6b4bc34e44cc2541929cc4b8fff96e756ab3f268','projectile source drift')
  local defs={NATURAL_GIFT={number=363,pp=15,type='NORMAL',parts={'PAY_DAY','LEECH_SEED'}},
    FLING={number=374,pp=10,type='DARK',parts={'PAY_DAY','COMET_PUNCH'}}}
  local berries={ORAN_BERRY={hp=10},SITRUS_BERRY={quarter=true},
    CHERI_BERRY={status='PAR'},CHESTO_BERRY={status='SLP'},PECHA_BERRY={status='PSN'},
    RAWST_BERRY={status='BRN'},ASPEAR_BERRY={status='FRZ'},PERSIM_BERRY={confusion=true},
    LUM_BERRY={all=true,confusion=true},LEPPA_BERRY={pp=10},LIECHI_BERRY={stat='attack'},
    GANLON_BERRY={stat='defense'},SALAC_BERRY={stat='speed'},PETAYA_BERRY={stat='specialAttack'},
    APICOT_BERRY={stat='specialDefense'}}
  local scalarStats={'attack','defense','speed','special','specialAttack','specialDefense','accuracy','evasion'}
  local major={PSN=true,BRN=true,FRZ=true,SLP=true,PAR=true}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function shallow(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function normal(id)return type(id)=='string'and id:lower():gsub('[^a-z0-9]','')or nil end
  local function live(w)local m=w and w.mon;return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
    and not(m.isEgg or m.egg or m.is_egg or m.eggSpecies)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local d=move and defs[move.id]
    local record=d and b and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or type(r.activeEpoch)~='number'or r.activeEpoch%1~=0 or r.activeEpoch<1 or r.activeEpoch>7
        or not d or move.backendMoveOwner~=M.OWNER or move.kascHeldProjectile67~=M.OWNER
        or not record or record.kascHeldProjectile67~=M.OWNER then return end
    if r.activeEpoch<4 and not(live(u)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species]))then return end
    return math.max(4,r.activeEpoch)
  end
  function M.itemMetadata(id,gen)
    local meta=opts.facts.item(id,gen)
    if meta then return meta end
    -- New carried identities keep their existing, explicit metadata owner.
    for _,name in ipairs({'pokemonChoiceItems67','pokemonContactAbilities67','pokemonLifeOrb67',
        'pokemonGems67','pokemonHeldStats67','pokemonGrounding67','backendPartialTrapping67',
        'pokemonHoneyGather67','pokemonPickup67','pokemonTypeItems67','pokemonLateTransformations67',
        'pokemonSafetyGoggles67'})do
      local owner=mod.exports and mod.exports[name]
      if owner and owner.itemMetadata then meta=owner.itemMetadata(id);if meta then return meta end end
    end
  end
  local function ready(game,id,gen)
    if opts.supportsItem then return opts.supportsItem(game,id,gen)==true end
    for _,name in ipairs({'pokemonEquipmentEffects67','pokemonModernBerries67','pokemonEquipmentTypeBoost67',
        'pokemonHeldStats67','pokemonTypeItems67','pokemonChoiceItems67','pokemonContactAbilities67',
        'pokemonLifeOrb67','pokemonGems67','backendCriticalRules67','pokemonLethalHitSurvival67',
        'pokemonSmokeBall67','pokemonWeather67','pokemonGrounding67','backendPartialTrapping67',
        'pokemonInfatuation67','pokemonScreens67','pokemonStrengthSap67','pokemonLateTransformations67',
        'pokemonSafetyGoggles67'})do
      local owner=mod.exports and mod.exports[name]
      if owner and owner.supportsItem and owner.supportsItem(game,id,gen)then return true end
    end
    return false
  end
  function M.spec(b,u,move)
    local gen=M.epoch(b,u,move);if not gen or not live(u)then return end
    local held,err=opts.held(u.mon);if err or not held then return end
    local source=data.bySourceId[normal(held)];local native=b.data.items[held]
    local meta=M.itemMetadata(held,gen)
    -- King's Rock already has its real evolution/holdable identity. This
    -- Card owns its pinned Fling callback only, not the separate passive
    -- 10% flinch effect or general equipment-effect readiness.
    local projectileReady=move.id=='FLING'and held=='KINGS_ROCK'and source
      and source.fling and source.fling.volatileStatus=='flinch'
    if not source or not native or not meta or meta.generation~=source.generation or source.generation>gen
        or native.keyItem or native.tossable==false or native.kascNoTake67
        or not(projectileReady or ready(b.game,held,gen))then return end
    local holdable=meta.effect~=nil
    for _,flag in ipairs(meta.flags or{})do if flag=='holdable'or flag=='holdable-passive'or flag=='holdable-active'then holdable=true end end
    if not holdable then return end
    -- Legacy Crystal berry identities are not renamed into modern berries.
    -- Their unsupported cross-era Eat metadata must not manufacture effects.
    if source.berry and source.generation<3 then return end
    local effects=opts.heldEffect or mod.exports and mod.exports.pokemonHeldEffect67
    if effects and effects.blocksMove(b,u,move.id)then return end
    if opts.itemSuppressed and opts.itemSuppressed(b,u,held,move.id,gen)then return end
    local selected
    if move.id=='NATURAL_GIFT'then
      selected=gen<=5 and source.naturalGift45 or source.naturalGift67
    else
      local transfer=opts.transfer or mod.exports and mod.exports.pokemonItemTransfer67
      if source.noTake or transfer and transfer.epoch(b)and transfer.bound(b,u,held)then return end
      -- Gen IV's native TakeItem special case prohibits Arceus from
      -- Flinging ANY item, not only Plates or active Multitype. A licensed
      -- gift in profiles I-III uses this move's actual IV fallback; the
      -- ordinary transfer owner's earlier battle epoch must not bypass it.
      local ex=mod.exports or{};local species=ex.backendGiftSpecies67
      local key=species and species.bySpecies[u.mon.species]
      local catalog=ex.backendNationalCatalog67
      local identity=key and catalog and catalog.entries[key]
      if gen==4 and identity and identity.nationalDex==493 then return end
      selected=gen==4 and source.fling4 or source.fling
      if source.berry and not berries[held]then return end
      if selected and selected.effect and held~='WHITE_HERB'then return end
    end
    if not selected or type(selected.power)~='number'or selected.power<=0 then return end
    return{item=held,gen=gen,power=selected.power,type=move.id=='FLING'and'DARK'
      or(selected.type=='Psychic'and'PSYCHIC_TYPE'or selected.type:upper()),berry=source.berry,
      status=selected.status,volatileStatus=selected.volatileStatus,effect=selected.effect}
  end
  local function current(b,u,move)
    local f=frames[b]
    if f and f.user==u and f.id==move.id and f.prepared then return f.spec end
    return M.spec(b,u,move)
  end
  function M.project(b,u,move)
    if not move or not defs[move.id]or move.kascHeldProjectileProjected67==M.OWNER then return move end
    local spec=current(b,u,move);if not spec then return move end
    local out=copy(move);out.power=spec.power;out.type=spec.type;out.kascHeldProjectileProjected67=M.OWNER
    return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not ctx.move or ctx.opts and ctx.opts.typeless or not defs[ctx.move.id]
        or not M.epoch(ctx.battle,ctx.user,ctx.move)then return nextDamage(ctx)end
    if not current(ctx.battle,ctx.user,ctx.move)then return 0,{crit=false,typeMult=10,missed=true}end
    local out=shallow(ctx);out.move=M.project(ctx.battle,ctx.user,ctx.move);return nextDamage(out)
  end
  function M.noUseful(b,u,t,move)
    return M.epoch(b,u,move)~=nil and not M.spec(b,u,move)or false
  end
  function M.gate(ctx)
    if not M.epoch(ctx.battle,ctx.user,ctx.move)or not live(ctx.user)or not live(ctx.target)
        or not current(ctx.battle,ctx.user,ctx.move)then return false,tr('But, it failed!','Doch es schlug fehl!')end
    return true
  end
  local function recoveryBlocked(b,w,cause)
    local block=mod.exports and mod.exports.pokemonHealBlock67
    return block and block.blocksRecovery(b,w,cause)or false
  end
  function M.forcedBerry(ctx,spec)
    local b,w=ctx.battle,ctx.target;local row=berries[spec.item]
    if not row or not live(w)then return false end
    local maxHP=w.mon.stats and w.mon.stats.hp
    if(row.hp or row.quarter)and maxHP and not recoveryBlocked(b,w,'item')then
      w.mon.hp=math.min(maxHP,w.mon.hp+(row.hp or math.max(1,math.floor(maxHP/4))))
    end
    if w.mon.status and(row.status==w.mon.status or row.all and major[w.mon.status])then
      w.mon.status=nil;w.sleepTurns=nil;w.toxicCounter=nil;w.nightmare=nil;A.onStatusCured(b,w)
    end
    if row.confusion then w.confusedTurns=nil end
    if row.stat then
      local split=opts.split or mod.exports and mod.exports.backendSplitSpecial67
      if not split then return false end
      for _,message in ipairs(split.changeStage(ctx,w,row.stat,1,false))do b:sayNext(message)end
    end
    if row.pp then
      local chosen,fallback
      for _,slot in ipairs(w.curMoves or{})do
        local def=b.data.moves[slot.id]
        local maxPP=def and def.pp and def.pp+math.min(3,math.max(0,slot.ppUps or 0))*math.floor(def.pp/5)
        if slot.pp==0 then chosen=slot;break end
        if not fallback and maxPP and slot.pp<maxPP then fallback=slot end
      end
      chosen=chosen or fallback
      if chosen then
        local original=chosen.id
        for _,restore in ipairs(b.mimicRestores or{})do if restore.battler==w and restore.entry==chosen then original=restore.id;break end end
        local def=b.data.moves[original]
        if def and (def.pp or 0)>0 then chosen.pp=math.min(def.pp+math.min(3,math.max(0,chosen.ppUps or 0))*math.floor(def.pp/5),chosen.pp+row.pp)end
      end
    end
    -- Forced Eat is not consumption of the recipient's own held item.
    -- No second Harvest/Pickup/Recycle/Unburden/Symbiosis receipt is created.
    if A.activeAbility(b,w)=='CHEEK_POUCH'and maxHP and not recoveryBlocked(b,w,'ability')then
      w.mon.hp=math.min(maxHP,w.mon.hp+math.max(1,math.floor(maxHP/3)))
      b:sayNext(tr('Cheek Pouch restores HP!','Backentaschen heilen KP!'))
    end
    b:drainNext();return true
  end
  function M.afterDamage(ctx)
    local f=frames[ctx.battle];local hit=f and f.hit;local spec=f and f.spec
    if not f or not spec or not f.prepared or f.applied or f.id~='FLING'or not hit or not hit.confirmed
        or hit.substitute or not live(ctx.target)then return end
    f.applied=true;local b,w=ctx.battle,ctx.target
    if spec.berry then M.forcedBerry(ctx,spec);return end
    if spec.item=='WHITE_HERB'then
      for _,stat in ipairs(scalarStats)do if(w.stages[stat]or 0)<0 then w.stages[stat]=0 end end
      return
    end
    if not spec.status and not spec.volatileStatus then return end
    -- Canonical item status/flinch are secondary effects: Shield Dust and
    -- Inner Focus/order guards apply. The berry/Herb Eat branch is primary.
    local chance=A.secondaryChance(ctx,100)
    if chance<=0 then return end
    if spec.volatileStatus=='flinch'then
      if not(b._kascFlinchActed67 and b._kascFlinchActed67[w])and not A.blocksFlinch(b,w)
          and b.rng(1,100)<=chance then w.flinched=true end
    elseif b.rng(1,100)<=chance then
      local id=spec.status=='tox'and'PSN'or({par='PAR',brn='BRN',psn='PSN'})[spec.status]
      if id then for _,message in ipairs(Status.inflict(b,w,id,{secondary=true,toxic=spec.status=='tox',
          moveType=ctx.move.type,source=ctx.move.id}))do b:sayNext(message)end end
    end
  end
  function M.hit(ev)
    local f=ev and frames[ev.battle];local h=f and f.hit
    if h and not h.confirmed and h.user==ev.user and h.target==ev.target and h.move==ev.move
        and h.damage==ev.damage and h.direct then h.confirmed=true end
  end
  function M.run(original,b,ctx,record)
    if not ctx or not M.epoch(b,ctx.user,ctx.move)then return original(b,ctx,record)end
    local prior=frames[b];local f={user=ctx.user,id=ctx.move.id,spec=M.spec(b,ctx.user,ctx.move),prepared=true}
    frames[b]=f
    if not f.spec or not live(ctx.target)or not side(b,ctx.user)or not side(b,ctx.target)or ctx.user==ctx.target then
      b:cancelMoveAnim();b:sayNext(tr('But, it failed!','Doch es schlug fehl!'));frames[b]=prior;return
    end
    -- All native action/status/AP checks have completed before this surface.
    -- Clear both possession aliases atomically, then run genuine consumption.
    ctx.user.mon.item=nil;ctx.user.mon.heldItem=nil
    local ok,err=pcall(A.onItemLost,b,ctx.user,f.spec.item)
    if not ok then frames[b]=prior;error(err,0)end
    ctx=shallow(ctx);ctx.move=M.project(b,ctx.user,ctx.move)
    local raw,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports and mod.exports.pokemonLethalHitSurvival67
      local attempt=survival and survival.incomingHit and survival.incomingHit(self,w)or amount
      local direct=w==ctx.target and live(w)and type(attempt)=='number'and attempt>0
      local sub=direct and w.substituteHP~=nil;local dealt=previous(self,w,amount)
      if w==ctx.target then f.hit={user=ctx.user,target=w,move=ctx.move,damage=dealt,direct=direct,substitute=sub}end
      return dealt
    end
    local out=pack(pcall(original,b,ctx,record));b.applyDamage=raw;frames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.makeCtx(original,b,u,t,...)
    local ctx=original(b,u,t,...);ctx.move=M.project(b,u,ctx.move);return ctx
  end
  function M.validateCheckpoint(b)if frames[b]then return false,'held_projectile_unsettled'end;return true end
  for _,id in ipairs({'NATURAL_GIFT','FLING'})do
    local d=defs[id];local fact=assert(opts.facts.move(id,4));local old=assert(mod.content.moves:get(id))
    assert(fact.number==d.number and fact.generation==4 and fact.type==d.type and fact.category=='physical'
      and fact.power==0 and fact.pp==d.pp and fact.accuracy==100 and fact.priority==0,'projectile move source drift '..id)
    assert(not old.backendMoveOwner,'foreign projectile owner '..id)
    local effect='KA_HELD_PROJECTILE_67_'..id
    mod.content.move_effects:register(effect,{kind='full',gate=M.gate,afterDamage=M.afterDamage,kascHeldProjectile67=M.OWNER})
    local flags={protect=1,mirror=1,metronome=1};if id=='FLING'then flags.noparentalbond=1 end
    mod.content.moves:patch(id,{effect=effect,power=1,type=d.type,category='physical',pp=d.pp,accuracy=100,
      contact=false,priority=0,target=10,flags=flags,originGeneration=4,backendMoveOwner=M.OWNER,
      backendMoveNumber=d.number,backendLearnsetRevision=old.backendLearnsetRevision or 1,kascHeldProjectile67=M.OWNER,
      anim=copy(assert(mod.content.moves:get(d.parts[1])).anim)})
    local animation={seq={},source=M.OWNER}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=copy(step)end end
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
    if not defs[id]or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=math.max(16,q.y-16)
          if M.inHud(q)then q.x=0 end
        end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    FX._kascHeldProjectiles67=M;Player._kascHeldProjectiles67=M
    if not FX._kascHeldProjectileRunWrapped67 then local run=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascHeldProjectiles67.run(run,...)end;FX._kascHeldProjectileRunWrapped67=true end
    if not FX._kascHeldProjectileCtxWrapped67 then local make=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascHeldProjectiles67.makeCtx(make,...)end;FX._kascHeldProjectileCtxWrapped67=true end
    if not Player._kascHeldProjectilesWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascHeldProjectiles67.position(self,id);return unpack(out,1,out.n)end
      Player._kascHeldProjectilesWrapped67=true end
  end
  mod.hooks:wrap('battle.damage',M.damage,31511)
  mod.events:on('battle.damage_dealt',M.hit,31001)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-pre-hit-consumption-and-actual-body-receipts',providerStatus='source-item-power-type-and-supported-forced-eat',
    buildReceiptId='docs/HELD_PROJECTILES_67.md',rollbackReceiptId='docs/HELD_PROJECTILES_67.md'})end
  return M
end
