-- Actual direct-hit reactions, not damage previews. Weak Armor uses the
-- active move category; the other reactions use independent contact flags.
-- Scopes retain pre-hit Substitute state; a broken substitute never counts
-- as contact with its owner. No scope/callback is stored in a save.
return function(mod,opts)
  local A,F=assert(opts.abilities),assert(opts.facts)
  local Effects=require('src.battle.EffectRegistry')
  local Battle=require('src.battle.BattleState')
  local Status=require('src.battle.StatusRegistry')
  local M={CARD_ID='KASC-67-CONTACT-ABILITIES',OWNER='kasc.contact-abilities/v1'}
  function M.itemMetadata(id)
    if id=='ROCKY_HELMET'then return {id=id,generation=5,
      names={en='ROCKY HELMET',de='BEULENHELM'},flags={'holdable','holdable-passive'}}end
  end
  do
    local fields={kascContactItemOwner67=M.OWNER,kascEquipmentRewardEpochs={[5]=true,[6]=true,[7]=true}}
    if mod.content.items:get('ROCKY_HELMET')then mod.content.items:patch('ROCKY_HELMET',fields)
    else
      fields.id='ROCKY_HELMET';fields.name=opts.i18n.text('ROCKY HELMET','BEULENHELM')
      fields.names={en='ROCKY HELMET',de='BEULENHELM'}
      fields.price=(F.item('ROCKY_HELMET',5)or{}).cost or 0
      fields.keyItem=false;fields.field=false;fields.battle=false
      mod.content.items:register('ROCKY_HELMET',fields)
    end
  end
  function M.supportsItem(game,id,gen)
    local d=game and game.data;local item=d and d.items and d.items[id]
    local marker=d and d.move_effects and d.move_effects.HEAL_EFFECT
    return id=='ROCKY_HELMET'and item and item.kascContactItemOwner67==M.OWNER
      and marker and marker.kascContactOwner67==M.OWNER
      and type(gen)=='number'and gen%1==0 and gen>=5 and gen<=7 or false
  end
  local statuses={STATIC='PAR',FLAME_BODY='BRN',POISON_POINT='PSN'}
  local gen7={STATIC=true,FLAME_BODY=true,POISON_POINT=true,EFFECT_SPORE=true,
    STAMINA=true,WEAK_ARMOR=true,ROUGH_SKIN=true,IRON_BARBS=true,CUTE_CHARM=true,
    JUSTIFIED=true,RATTLED=true,ANGER_POINT=true,AFTERMATH=true,DAMP=true,
    MOXIE=true,BEAST_BOOST=true,POISON_TOUCH=true,GOOEY=true,TANGLING_HAIR=true,WATER_COMPACTION=true,
    INNARDS_OUT=true,COLOR_CHANGE=true,STENCH=true,BERSERK=true,CURSED_BODY=true,MUMMY=true}
  local damageAbilities={ROUGH_SKIN={en='Rough Skin',de='Rauhaut',generation=3},
    IRON_BARBS={en='Iron Barbs',de='Eisenstachel',generation=5},
    AFTERMATH={en='Aftermath',de='Finalschlag',generation=4}}
  local aliases,contact={},{}
  for id,row in pairs(F.data.moves)do
    local makesContact=false
    for _,flag in ipairs(row.flags or {})do if flag=='contact' then makesContact=true end end
    contact[id]=makesContact
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end
  end
  local gen3={ANCIENT_POWER=true,OVERHEAT=true,BIDE=true,
    COVET=false,FAKE_OUT=false,FEINT_ATTACK=false,FAINT_ATTACK=false}
  local scopes=setmetatable({},{__mode='k'})
  local moveScopes=setmetatable({},{__mode='k'})
  local knockoutAwarded=setmetatable({},{__mode='k'})
  local function epoch(b)
    local receipt=b and b.kascGenerationRulesReceipt
    if receipt then return receipt.mode~='off' and tonumber(receipt.activeEpoch) or nil end
    return opts.status.epoch(b)
  end
  function M.supports(game,id,gen)
    local record=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
    local supported=statuses[id]~=nil or id=='EFFECT_SPORE' or id=='STAMINA'
      or id=='DAMP' or id=='COLOR_CHANGE' or id=='INNARDS_OUT'and gen==7 or id=='ANGER_POINT' and gen>=4
      or id=='STENCH'and gen>=5 or id=='BERSERK'and gen==7
      or id=='MUMMY'and gen>=5
      or id=='CURSED_BODY'and gen>=5 and opts.disable~=nil
      or (id=='JUSTIFIED' or id=='RATTLED') and gen>=5
      or (id=='MOXIE' or id=='POISON_TOUCH') and gen>=5 or id=='BEAST_BOOST' and gen==7
      or id=='GOOEY'and gen>=6 or (id=='TANGLING_HAIR'or id=='WATER_COMPACTION')and gen==7
      or id=='WEAK_ARMOR' and gen>=5
      or id=='CUTE_CHARM' and record and record.kascInfatuation67=='kasc.infatuation/v1'
      or damageAbilities[id] and gen>=damageAbilities[id].generation
    return supported and record and record.kascContactOwner67==M.OWNER
      and gen>=3 and (gen<=6 or gen==7 and gen7[id]) or false
  end
  function M.contactDamage(b,user,id,gen)
    if A.blocksIndirect(b,user,'contact')then return 0 end
    local divisor=id=='AFTERMATH' and 4 or id=='ROUGH_SKIN' and gen==3 and 16 or 8
    local amount=math.max(1,math.floor(user.mon.stats.hp/divisor))
    local names=damageAbilities[id]
    local tr=opts.i18n.text
    b:sayNext(tr('%s!\nContact damage.','%s!\nKontaktschaden.'):format(tr(names.en,names.de)))
    return M.indirectDamage(b,user,amount)
  end
  function M.indirectDamage(b,user,amount)
    -- Indirect retaliation reaches the native HP-bar queue, but does not
    -- strike a Substitute, feed Bide, or build Rage. The direct-hit survival
    -- scope only guards the attacked target, never this attacking user.
    local sub,bide,rage=user.substituteHP,user.bideTurns,user.rageMove
    user.substituteHP,user.bideTurns,user.rageMove=nil,nil,nil
    local ok,dealt=pcall(b.applyDamage,b,user,amount)
    user.substituteHP,user.bideTurns,user.rageMove=sub,bide,rage
    if not ok then error(dealt,0)end
    -- The ordinary pipeline owns fainting after the strike. Its Bide
    -- sibling lacks an attacker-faint check; scope adds only that case.
    return dealt
  end
  function M.colorChange(b,target,move)
    local typ=move and move.type
    if target.mon.hp<=0 or not typ or typ=='???'or move.category=='status'then return end
    for _,t in ipairs(target.curTypes or{})do if t==typ then return end end
    -- Only the battler changes; no mutation of the saved species/party types.
    target.curTypes={typ}
    b:sayNext(opts.i18n.text('Color Change!','Farbwechsel!'))
  end
  function M.berserk(b,whole)
    local target=whole.target
    local maxHP=target.mon.stats and target.mon.stats.hp
    if epoch(b)~=7 or target.mon.hp<=0 or not maxHP
        or A.activeAbility(b,target)~='BERSERK'
        or A.sheerForce(b,whole.user,whole.move)
        or (whole.realDamage or 0)<=0 or target.mon.hp*2>maxHP
        or (target.mon.hp+whole.realDamage)*2<=maxHP then return end
    b:sayNext(opts.i18n.text('Berserk!','Wutausbruch!'))
    local ctx={battle=b,user=target,target=target,changeStage=function(w,s,d,f)
      return require('src.battle.MoveEffects').changeStage(b,w,s,d,f)end}
    for _,msg in ipairs(opts.split.changeStage(ctx,target,'specialAttack',1,false))do b:sayNext(msg)end
  end
  function M.makesContact(move,gen,b,user)
    if not move then return false end
    if b and user and A.activeAbility(b,user)=='LONG_REACH'then return false end
    local id=aliases[move.id] or move.id
    if gen==3 and gen3[id]~=nil then return gen3[id] end
    if contact[id]~=nil then return contact[id] end
    return move.contact==true
  end
  local function native(b)
    local gen=epoch(b)
    return getmetatable(b)==Battle and not b.demo and b.kind~='link' and not b.result
      and gen and gen>=3 and gen<=7 and b.player and b.enemy
  end
  function M.damp(b)
    if not native(b)then return false end
    for _,who in ipairs({b.player,b.enemy})do
      if who.mon and who.mon.hp>0 and A.activeAbility(b,who)=='DAMP'then return true end
    end
    return false
  end
  function M.blocksExplosion(b,move)
    local id=move and (aliases[move.id] or move.id)
    return (id=='SELFDESTRUCT' or id=='SELF_DESTRUCT' or id=='EXPLOSION' or id=='MIND_BLOWN')
      and M.damp(b) or false
  end
  function M.sporeStatus(b,user,gen)
    -- The Gen-VI powder type immunity applies before the ability roll.
    -- Type changes in battle count; the species' original type does not.
    if gen>=6 then
      if A.activeAbility(b,user)=='OVERCOAT'then return end
      for _,id in ipairs(user.curTypes or {})do if id=='GRASS' then return end end
    end
    if gen<=4 then
      if b.rng(1,10)>(gen==3 and 1 or 3) then return end
      return ({'SLP','PAR','PSN'})[b.rng(1,3)]
    end
    local roll=b.rng(1,100)
    if roll<=11 then return 'SLP'
    elseif roll<=21 then return 'PAR'
    elseif roll<=30 then return 'PSN' end
  end
  function M.react(b,hit)
    if not hit or hit.consumed then return end
    hit.consumed=true
    local user,target=hit.user,hit.target
    if not native(b) then return end
    local gen=epoch(b)
    local future=mod.exports and mod.exports.pokemonFutureStrikes67
    if gen>=5 and hit.allowed and (hit.damage>0 or hit.disguise) and user.mon.hp>0 and target.mon.hp>0
        and A.activeAbility(b,user)=='STENCH'
        and not(future and future.striking(b,user,target,hit.move))
        and not (b._kascFlinchActed67 and b._kascFlinchActed67[target])
        and not A.blocksFlinch(b,target)and A.activeAbility(b,target)~='SHIELD_DUST'then
      local facts=F.move(aliases[hit.move.id]or hit.move.id,gen)
      local chance=facts and facts.meta and facts.meta.flinch_chance or 0
      -- Never add a second chance to a move which already causes flinching.
      if chance<=0 and b.rng(1,100)<=10 then target.flinched=true end
    end
    if hit.allowed and (hit.damage>0 or hit.disguise) and user.mon.hp>0 and target.mon.hp>0
        and A.activeAbility(b,user)=='POISON_TOUCH' and M.makesContact(hit.move,gen,b,user)
        and A.activeAbility(b,target)~='SHIELD_DUST' and b.rng(1,100)<=30 then
      for _,msg in ipairs(Status.inflict(b,target,'PSN',{source='POISON_TOUCH',kascStatusSource67=user}))do
        b:sayStatusMsg(target,msg)
      end
    end
    local id=A.activeAbility(b,target)
    if not hit.allowed and not (id=='ANGER_POINT' and gen==4 and hit.hitSub)then return end
    if gen==3 and hit.damage<=0 then return end
    if not M.supports(b.game,id,gen) then return end
    if id=='DAMP'or id=='BERSERK'then return end
    if id=='MUMMY'then
      if hit.damage>0 and user.mon.hp>0 and M.makesContact(hit.move,gen,b,user)
          and A.overrideAbility(b,user,'MUMMY')then
        b:sayNext(opts.i18n.text('Mummy!\nThe attacker gained Mummy!','Mumie!\nDer Angreifer erhält Mumie!'))
      end
      return
    end
    if id=='CURSED_BODY'then
      if hit.damage<=0 or user.mon.hp<=0 or user.disabledSlot or hit.move.id=='STRUGGLE'
          or hit.move.id=='FUTURE_SIGHT' or hit.move.id=='DOOM_DESIRE'then return end
      if b.rng(1,100)<=30 and opts.disable.start(b,user,hit.move.id,true)then
        b:sayNext(opts.i18n.text('Cursed Body!\nThe move was disabled!','Tastfluch!\nDie Attacke wurde blockiert!'))
      end
      return
    end
    if id=='INNARDS_OUT'then
      if target.mon.hp>0 or hit.damage<=0 or user.mon.hp<=0
          or A.blocksIndirect(b,user,'innards_out')then return end
      b:sayNext(opts.i18n.text('Innards Out!','Magenkrempler!'))
      -- Native damage is capped at the HP lost on this specific hit, not
      -- the nominal move damage or all earlier hits of a multihit attack.
      local dealt=M.indirectDamage(b,user,hit.damage)
      hit.retaliationFainted=user.mon.hp<=0
      return dealt
    end
    if id=='COLOR_CHANGE'then
      if gen<=4 and hit.damage>0 then M.colorChange(b,target,hit.move)end
      return
    end
    if id=='WATER_COMPACTION'then
      if target.mon.hp<=0 or hit.damage<=0 or hit.move.type~='WATER'then return end
      b:sayNext(opts.i18n.text('Water Compaction!','Verklumpen!'))
      for _,msg in ipairs(require('src.battle.MoveEffects').changeStage(b,target,'defense',2,false))do b:sayNext(msg)end
      return
    end
    if id=='JUSTIFIED' or id=='RATTLED' or id=='ANGER_POINT'then
      if target.mon.hp<=0 or hit.damage<=0 then return end
      local typ=hit.move and hit.move.type
      local stat,delta
      if id=='JUSTIFIED' and typ=='DARK'then stat,delta='attack',1
      elseif id=='RATTLED' and (typ=='DARK' or typ=='BUG' or typ=='GHOST')then stat,delta='speed',1
      elseif id=='ANGER_POINT' and hit.crit then stat,delta='attack',6-(target.stages.attack or 0)end
      if not stat or delta<=0 then return end
      b:sayNext(opts.i18n.text(id=='JUSTIFIED' and 'Justified!' or id=='RATTLED' and 'Rattled!' or 'Anger Point!',
        id=='JUSTIFIED' and 'Redlichkeit!' or id=='RATTLED' and 'Hasenfuß!' or 'Kurzschluss!'))
      for _,msg in ipairs(require('src.battle.MoveEffects').changeStage(b,target,stat,delta,false))do b:sayNext(msg)end
      return
    end
    if id=='STAMINA' then
      -- Later-species ability under KASC's existing generation fallback.
      -- Any actual damaging hit counts, not just physical/contact attacks.
      if target.mon.hp<=0 or hit.damage<=0 then return end
      if (target.stages.defense or 0)>=6 then return end
      b:sayNext(opts.i18n.text('Stamina!','Zähigkeit!'))
      for _,msg in ipairs(require('src.battle.MoveEffects').changeStage(b,target,'defense',1,false))do
        b:sayNext(msg)
      end
      return
    end
    if id=='WEAK_ARMOR' then
      local category=hit.move and (hit.move.category
        or require('src.battle.TypeChart').category(hit.move.type))
      if target.mon.hp<=0 or hit.damage<=0 or category~='physical' then return end
      -- Gen V/VI: Defense -1, Speed +1; VII: Defense -1, Speed +2.
      -- Self-inflicted stage changes bypass Mist and use independent caps.
      local changes=require('src.battle.MoveEffects')
      b:sayNext(opts.i18n.text('Weak Armor!','Bruchrüstung!'))
      for _,row in ipairs({{'defense',-1},{'speed',gen>=7 and 2 or 1}})do
        for _,msg in ipairs(changes.changeStage(b,target,row[1],row[2],false))do
          b:sayNext(msg)
        end
      end
      return
    end
    if user.mon.hp<=0 or not M.makesContact(hit.move,gen,b,user) then return end
    if id=='GOOEY'or id=='TANGLING_HAIR'then
      b:sayNext(opts.i18n.text(id=='GOOEY'and 'Gooey!'or 'Tangling Hair!',id=='GOOEY'and 'Viskosität!'or 'Lockenkopf!'))
      local sub=user.substituteHP;user.substituteHP=nil
      local ok,msgs=pcall(require('src.battle.MoveEffects').changeStage,b,user,'speed',-1,true)
      user.substituteHP=sub;if not ok then error(msgs,0)end
      for _,msg in ipairs(msgs)do b:sayNext(msg)end
      return
    end
    if id=='EFFECT_SPORE' and gen==4 and hit.damage<=0 then return end
    if id=='CUTE_CHARM' then
      if target.mon.hp<=0 or gen<=4 and hit.damage<=0 then return end
      local success=gen==3 and b.rng(1,3)==1 or gen~=3 and b.rng(1,100)<=30
      if success then return opts.infatuation.start(b,user,target)end
      return
    end
    if damageAbilities[id] then
      if id=='AFTERMATH' and (target.mon.hp>0 or M.damp(b))then return end
      local dealt=M.contactDamage(b,user,id,gen)
      hit.retaliationFainted=user.mon.hp<=0
      return dealt
    end
    -- The struck holder may have just fainted: these effects still react.
    local status
    if id=='EFFECT_SPORE' then
      status=M.sporeStatus(b,user,gen)
    else
      local success=gen==3 and b.rng(1,3)==1 or gen~=3 and b.rng(1,100)<=30
      if success then status=statuses[id]end
    end
    if not status then return end
    -- Ability retaliation bypasses the attacker's own Substitute. The
    -- native poison registry has an unconditional sub gate; mask it only
    -- for this synchronous call, restoring even if an adapter throws.
    local sub=user.substituteHP
    user.substituteHP=nil
    local ok,msgs=pcall(Status.inflict,b,user,status,{source=id,kascStatusSource67=target})
    user.substituteHP=sub
    if not ok then error(msgs,0)end
    for _,msg in ipairs(msgs)do b:sayStatusMsg(user,msg)end
  end
  -- Item retaliation follows the target's contact ability, before native
  -- fainting and move-owned Knock Off. A KO'd holder still has its helmet.
  -- Reuse the actual per-hit receipt: previews and broken Substitutes do
  -- not count, and a multihit move can trigger once for each real strike.
  local reactAbility=M.react
  function M.react(b,hit)
    if not hit or hit.consumed then return end
    local result=reactAbility(b,hit)
    if not native(b)or not hit.allowed or hit.damage<=0 and not hit.disguise then return result end
    local u,t=hit.user,hit.target;local gen=epoch(b)
    local id,err=opts.held(t.mon,b,t)
    if err or u.mon.hp<=0 or not M.supportsItem(b.game,id,gen)
        or not M.makesContact(hit.move,gen,b,u)or A.blocksIndirect(b,u,'contact')then return result end
    b:sayNext(opts.i18n.text('Rocky Helmet!\nContact damage.','Beulenhelm!\nKontaktschaden.'))
    M.indirectDamage(b,u,math.max(1,math.floor(u.mon.stats.hp/6)))
    hit.retaliationFainted=u.mon.hp<=0
    return result
  end
  function M.scope(b,user,target,move,immediate,fn,multihit)
    if not native(b) or not user or not target or user==target then return fn()end
    local prior=scopes[b]
    local scope={user=user,target=target,move=move,multihit=multihit};scopes[b]=scope
    local rawDamage,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,who,amount)
      local hitSub=who==target and target.mon.hp>0 and target.substituteHP~=nil
      local eligible=who==target and target.mon.hp>0 and target.substituteHP==nil
        and type(amount)=='number' and amount>0
      local damage=previous(self,who,amount)
      if who==target then
        scope.hit={user=user,target=target,move=move,damage=damage,allowed=eligible,hitSub=hitSub}
        local disguise=mod.exports and mod.exports.pokemonDisguise67
        scope.hit.disguise=disguise and disguise.blockedHit(b,target)or false
        if eligible and damage>0 then
          scope.landed=true;scope.realDamage=(scope.realDamage or 0)+damage
        end
        local whole=moveScopes[b]
        if whole and whole.user==user and whole.target==target and eligible and damage>0 then
          whole.realDamage=(whole.realDamage or 0)+damage
        end
        if immediate then M.react(b,scope.hit)end
      end
      return damage
    end
    local function pack(...)return {n=select('#',...),...}end
    local result=pack(pcall(fn))
    b.applyDamage=rawDamage;scopes[b]=prior
    if not result[1] then error(result[2],0)end
    -- V+ Color Change occurs once, after the move's secondary effects.
    -- Sheer Force suppresses this after-secondary reaction; III/IV changed
    -- type between hits and are handled in react above instead.
    if scope.landed and epoch(b)>=5 then
      local whole=moveScopes[b]
      if whole and whole.user==user and whole.target==target then
        whole.landed=true;whole.move=move
      elseif immediate and A.activeAbility(b,target)=='COLOR_CHANGE'then
        M.colorChange(b,target,move)
      elseif immediate then
        M.berserk(b,scope)
      end
    end
    -- Award only a direct move KO, after recoil/retaliation. Neither an AI
    -- preview nor a residual/status KO passes through this hit receipt.
    if scope.hit and scope.hit.allowed and scope.hit.damage>0 and target.mon.hp<=0
        and user.mon.hp>0 and not knockoutAwarded[target]then
      local id=A.activeAbility(b,user)
      if id=='MOXIE' or id=='BEAST_BOOST'then
        knockoutAwarded[target]=true
        local stat='attack'
        if id=='BEAST_BOOST'then
          local best=-1
          for _,key in ipairs({'attack','defense','specialAttack','specialDefense','speed'})do
            local value=tonumber(user.curStats[key] or user.mon.stats[key]
              or (key=='specialAttack' or key=='specialDefense') and user.curStats.special)or 0
            if value>best then best,stat=value,key end
          end
        end
        b:sayNext(opts.i18n.text(id=='MOXIE' and 'Moxie!' or 'Beast Boost!',
          id=='MOXIE' and 'Hochmut!' or 'Bestien-Boost!'))
        local ctx={battle=b,user=user,target=user,changeStage=function(w,s,d,f)
          return require('src.battle.MoveEffects').changeStage(b,w,s,d,f)end}
        for _,msg in ipairs(opts.split.changeStage(ctx,user,stat,1,false))do b:sayNext(msg)end
      end
    end
    if immediate and scope.hit and scope.hit.retaliationFainted then b:onFaint(user)end
    return unpack(result,2,result.n)
  end
  mod.events:on('battle.damage_dealt',function(ev)
    local scope=ev and scopes[ev.battle]
    if scope and ev.user==scope.user and ev.target==scope.target and ev.move==scope.move
        and scope.hit and ev.damage==scope.hit.damage then
      scope.hit.crit=ev.crit;M.react(ev.battle,scope.hit)
      -- Healing berries may intervene between hits. Single-hit Berserk
      -- precedes its healing berry, which the normal action-end owner handles.
      -- This runs after higher-priority attack-damage provenance listeners.
      if scope.multihit and scope.hit.allowed and scope.hit.damage>0
          and epoch(ev.battle)==7 and A.activeAbility(ev.battle,ev.target)=='BERSERK' then
        local berries=opts.berries and opts.berries()
        if berries then berries.apply(ev.battle,true,ev.target,true)end
      end
    end
  end,0)
  function M.perform(original,b,user,target,...)
    if not native(b)or not user or not target or user==target then return original(b,user,target,...)end
    local prior=moveScopes[b];local whole={user=user,target=target};moveScopes[b]=whole
    local function pack(...)return {n=select('#',...),...}end
    local result=pack(pcall(original,b,user,target,...));moveScopes[b]=prior
    if not result[1]then error(result[2],0)end
    if whole.landed and A.activeAbility(b,target)=='COLOR_CHANGE'
        and not A.sheerForce(b,user,whole.move)then M.colorChange(b,target,whole.move)end
    if whole.landed then M.berserk(b,whole)end
    return unpack(result,2,result.n)
  end
  function M.install()
    Effects._kascContactOwner67=M;Battle._kascContactOwner67=M
    if not Battle._kascContactMoveWrapped67 then
      local original=Battle.performMove
      Battle.performMove=function(b,user,target,...)
        return Battle._kascContactOwner67.perform(original,b,user,target,...)
      end
      Battle._kascContactMoveWrapped67=true
    end
    if not Effects._kascContactWrapped67 then
      local original=Effects.runDamaging
      Effects.runDamaging=function(b,ctx,record)
        if Effects._kascContactOwner67.blocksExplosion(b,ctx.move)then
          b:cancelMoveAnim();b:sayNext(opts.i18n.text('Damp prevents the explosion!','Feuchtigkeit verhindert die Explosion!'))
          return
        end
        if A.sheerForce(b,ctx.user,ctx.move) and record and record.kind~='primary'then
          local selected={};for k,v in pairs(record)do selected[k]=v end
          selected.run=nil;record=selected
        end
        return Effects._kascContactOwner67.scope(b,ctx.user,ctx.target,ctx.move,false,
          function()return original(b,ctx,record)end,
          record and record.hitCount~=nil or ctx.move.multiHit~=nil)
      end
      Effects._kascContactWrapped67=true
    end
    if not Battle._kascContactWrapped67 then
      local original=Battle.continueBide
      Battle.continueBide=function(b,user,target)
        return Battle._kascContactOwner67.scope(b,user,target,b.data.moves.BIDE,true,
          function()return original(b,user,target)end)
      end
      Battle._kascContactWrapped67=true
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascContactOwner67=M.OWNER})
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if ctx and not (ctx.opts and ctx.opts.typeless) and M.blocksExplosion(ctx.battle,ctx.move)then
      return 0,{crit=false,typeMult=0}
    end
    return nextDamage(ctx)
  end,24000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-hit-pipeline',providerStatus='contact-status-reactions',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
