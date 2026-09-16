-- Familienbande owns two strikes inside ONE native move execution. Each
-- strike enters the ordinary FX/damage/contact pipeline; never call another
-- executeAction/performMove (PP, status checks and action costs are not hits).
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local FX=require('src.battle.EffectRegistry')
  local A=assert(opts.abilities)
  local M={CARD_ID='KASC-67-PARENTAL-BOND',OWNER='kasc.parental-bond/v1'}
  local frames=setmetatable({},{__mode='k'})
  local aliases,traits={},{}
  -- Pinned Showdown data/abilities.ts + data/moves.ts, commit
  -- 6b4bc34e44cc2541929cc4b8fff96e756ab3f268. The source exclusion flag is
  -- independent of category/power, including sentinel-powered fixed damage.
  local excluded={ENDEAVOR=true,EXPLOSION=true,FINAL_GAMBIT=true,FLING=true,
    ICE_BALL=true,ROLLOUT=true,SELF_DESTRUCT=true,DRAGON_DARTS=true,DYNAMAX_CANNON=true}
  local charged={BOUNCE=true,DIG=true,DIVE=true,FLY=true,FREEZE_SHOCK=true,
    GEOMANCY=true,ICE_BURN=true,PHANTOM_FORCE=true,RAZOR_WIND=true,SHADOW_FORCE=true,
    SKULL_BASH=true,SKY_ATTACK=true,SKY_DROP=true,SOLAR_BEAM=true,SOLAR_BLADE=true,
    METEOR_BEAM=true,ELECTRO_SHOT=true}
  -- Top-level move.self is performed once, unlike secondary.self (e.g.
  -- Power-Up Punch/Flame Charge). Native recharge/lock flags are idempotent;
  -- the listed real stat changes must not be repeated on strike two.
  local onceSelf={CLOSE_COMBAT=true,DRACO_METEOR=true,DRAGON_ASCENT=true,
    FLEUR_CANNON=true,HAMMER_ARM=true,HYPERSPACE_FURY=true,ICE_HAMMER=true,
    LEAF_STORM=true,OVERHEAT=true,PSYCHO_BOOST=true,SUPERPOWER=true,V_CREATE=true,
    ARMOR_CANNON=true,HEADLONG_RUSH=true,MAKE_IT_RAIN=true,SPIN_OUT=true}
  -- The fact catalog already uses native compact spelling for some ROM
  -- moves (SELFDESTRUCT / SOLARBEAM), not only the underscore source IDs.
  -- Bind both spellings to the exact source policy identity. This changes
  -- neither a registered move nor its effect/animation, and deliberately
  -- does not infer policies for an unknown name or a foreign dispatch.
  local sourceIdentity={FUTURESIGHT='FUTURE_SIGHT',DOOMDESIRE='DOOM_DESIRE'}
  for _,policy in ipairs({excluded,charged,onceSelf})do
    for id in pairs(policy)do sourceIdentity[id:gsub('_','')]=id end
  end
  local specialNumbers={}
  for n=622,658 do specialNumbers[n]=true end
  for n=695,703 do specialNumbers[n]=true end
  for n=723,728 do specialNumbers[n]=true end
  for n=757,774 do specialNumbers[n]=true end
  specialNumbers[743]=true;specialNumbers[1000]=true
  local function copy(v)local r={};for k,x in pairs(v or{})do r[k]=x end;return r end
  local function pack(...)return {n=select('#',...),...}end
  local function flagged(move,name)
    local flags=move.flags or{}
    if flags[name]then return true end
    for _,flag in ipairs(flags)do if flag==name then return true end end
    return false
  end
  for id,row in pairs(assert(opts.facts).data.moves)do
    local selfEffect=row.meta and row.meta.meta_category_id==7
    -- The imported source has both historic source spellings in circulation.
    selfEffect=selfEffect or row.metaCategory==7
    if not selfEffect and row.meta then selfEffect=row.meta.category==7 end
    local natives=copy(assert(opts.species).moveIds(id))
    -- Native ROM names also omit underscores (SELFDESTRUCT, RAZORWIND,
    -- SKULLBASH). Resolve an existing spelling, never invent a new move or
    -- change its animation; source exclusion flags must cover saved slots.
    local compact=id:gsub('_','')
    if compact~=id and mod.content.moves:get(compact)then natives[#natives+1]=compact end
    for _,native in ipairs(natives)do
      aliases[native]=sourceIdentity[id:gsub('_','')]or id
      traits[native]={row=row,selfEffect=selfEffect}
    end
  end
  local function valid(w)
    local p=w and w.mon
    return p and type(p.hp)=='number'and p.hp>0 and not p.isEgg and not p.egg
      and not p.is_egg and not p.eggSpecies
  end
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=r and r.kascParentalBond67==M.OWNER and opts.status.epoch(b)
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and gen and gen>=6 and gen<=7 and gen or nil
  end
  function M.supports(game,id,gen)
    local r=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
    return id=='PARENTAL_BOND'and type(gen)=='number'and gen%1==0 and gen>=6 and gen<=7
      and r and r.kascParentalBond67==M.OWNER or false
  end
  function M.profile(b,ctx,record)
    local gen=M.epoch(b);local u,t,move=ctx and ctx.user,ctx and ctx.target,ctx and ctx.move
    if not gen or not valid(u)or not valid(t)or u==t or u~=b.player and u~=b.enemy
        or t~=b.player and t~=b.enemy or not move or move.category=='status'
        or not record or record.kind=='primary'or record.perform
        or A.activeAbility(b,u)~='PARENTAL_BOND'then return end
    local id=aliases[move.id]or move.id;local tr=traits[move.id]
    local body=mod.exports and mod.exports.pokemonBodyCounter67
    -- An outer Counter owner can supply its private native dispatch. Ask
    -- that authentic owner rather than treating an unknown alias as native
    -- Gen-I Counter (whose global damage register is not a II+ receipt).
    if move.backendMoveNumber==68 and body and body.active(b,move,u)then
      id='COUNTER';tr=traits.COUNTER
    end
    local row=tr and tr.row
    local meta=row and row.meta
    if excluded[id]or charged[id]or id=='FUTURE_SIGHT'or id=='DOOM_DESIRE'
        or move.multiHit or move.multihit or record.hitCount or record.charge
        or meta and (tonumber(meta.min_hits)or 0)>1
        or flagged(move,'noparentalbond')or flagged(move,'charge')or flagged(move,'futuremove')
        or specialNumbers[row and row.number or move.backendMoveNumber]
        or move.spreadHit or move.isZ or move.isMax then return end
    -- This host owns one actual opponent. A nominal spread move such as
    -- Earthquake DOES receive two strikes in singles; an actual spreadHit
    -- receipt does not. Do not advertise doubles support by inventing targets.
    return gen,id,tr
  end
  function M.projected(b,u,t,prior,view)
    local f=frames[b]
    -- Only a real per-hit frame can carry its own detached move view across
    -- an upstream genetic/called/effectiveness projection. No public marker
    -- or forecast opts can manufacture a second Parent hit.
    if not f or u~=f.user or t~=f.target or not prior or not view
        or not(prior==f.move or f.views[prior])or prior.id~=view.id
        or prior.effect~=view.effect or prior.backendMoveOwner~=view.backendMoveOwner
        or prior.backendMoveNumber~=view.backendMoveNumber then return end
    f.views[view]=true
  end
  function M.damage(nextDamage,ctx)
    local f=ctx and frames[ctx.battle]
    if not f or f.hit~=2 or ctx.user~=f.user or ctx.target~=f.target
        or not(ctx.move==f.move or f.views[ctx.move])
        or ctx.opts and ctx.opts.typeless then return nextDamage(ctx)end
    local adjusted=copy(ctx);adjusted.opts=copy(ctx.opts)
    -- The math owner applies this after baseDamage +2, BEFORE weather /
    -- crit / variance / STAB / effectiveness. Fixed chooseDamage bypasses it.
    adjusted.opts.kascParentalBond67=f.gen==6 and 2048 or 1024
    return nextDamage(adjusted)
  end
  function M.validateCheckpoint(b)
    return frames[b]==nil,'unsettled_parental_bond_hit'
  end
  function M.run(original,b,ctx,record)
    -- Reentry is another effect inside an existing strike, not another bond.
    if frames[b]then return original(b,ctx,record)end
    local gen,id,tr=M.profile(b,ctx,record)
    if not gen then return original(b,ctx,record)end
    local f={gen=gen,user=ctx.user,target=ctx.target,move=ctx.move,hit=1,
      views=setmetatable({},{__mode='k'})}
    frames[b]=f
    local rawAccuracy,accuracy=rawget(b,'accuracyRoll'),b.accuracyRoll
    local rawFaint,faint=rawget(b,'onFaint'),b.onFaint
    local priorAnim=b.moveAnimRow
    local pending,seen={},{}
    local startedAsleep=ctx.user.mon.status=='SLP'
    local accuracyUsed=false
    b.accuracyRoll=function(self,move,u,t)
      if move~=ctx.move or u~=ctx.user or t~=ctx.target then return accuracy(self,move,u,t)end
      if accuracyUsed then return true end
      accuracyUsed=true;return accuracy(self,move,u,t)
    end
    b.onFaint=function(self,w)
      if w~=ctx.user and w~=ctx.target then return faint(self,w)end
      if not seen[w]then seen[w]=true;pending[#pending+1]=w end
    end
    local total,landed,broke=0,0,false
    local recoil=id=='STRUGGLE'or ctx.moveInst and ctx.moveInst.struggle
      or tr and tr.row.meta and (tonumber(tr.row.meta.drain)or 0)<0
    local recoilEffect=recoil and(record.afterDamage or b.data.move_effects.RECOIL_EFFECT
      and b.data.move_effects.RECOIL_EFFECT.afterDamage)
    local selfEffect=tr and tr.selfEffect
    local function execute()
      for hit=1,2 do
        if not valid(ctx.user)or not valid(ctx.target)or b.result then break end
        if hit>1 and ctx.user.mon.status=='SLP'and not(id=='SNORE'or startedAsleep and ctx.isCalled)then break end
        f.hit=hit
        local selected=copy(record);selected.hitCount=function()return 1 end
        -- A no-op also intercepts the native Struggle fallback, even when
        -- the original plain-damage record has no afterDamage callback.
        if recoilEffect then selected.afterDamage=function()end end
        if hit>1 then
          selected.beforeAccuracy=nil
          b.moveAnimRow=b:animNext(ctx.move.id,ctx.user.isPlayer)
        end
        local hadSub=ctx.target.substituteHP~=nil
        local ranSelf=false
        if record.run then
          selected.run=function(single)
            if selfEffect then
              if ctx.user.mon.hp<=0 or hit>1 and onceSelf[id]then return{}end
              ranSelf=true
            elseif hadSub or hit==1 and id=='SECRET_POWER'then return{}end
            return record.run(single)
          end
        end
        local single=FX.makeCtx(b,ctx.user,ctx.target,ctx.move,ctx.moveInst,ctx.isCalled)
        single.kascParentalBond67={owner=M.OWNER,hit=hit,totalHits=2}
        local body=mod.exports and mod.exports.pokemonBodyCounter67
        if id=='COUNTER'and ctx.move.backendMoveNumber==68 and body
            and body.active(b,ctx.move,ctx.user)then
          -- FX's captured snapshot can precede the current Body wrapper.
          -- Each child therefore gets a fresh actual-owner dispatch and its
          -- original per-side incoming receipt, even after child one has
          -- restored its own canonical ID before genuine hit events. This
          -- remains ONE action/PP/status gauntlet, with native per-hit FX.
          body.run(original,b,single,selected)
        else original(b,single,selected)end
        -- Native miss, effect gate, immunity or protection never supplies a
        -- totalDealt. Zero ACTUAL damage (Disguise / False Swipe / Endure)
        -- still signifies a real strike and can be followed by strike two.
        if single.totalDealt==nil then break end
        landed=landed+1;total=total+single.totalDealt
        broke=broke or single.brokeSub
        ctx.rawDamage,ctx.hitSfx=single.rawDamage,single.hitSfx
        -- Gen-I native FX suppresses all secondary runs on KO/zero damage.
        -- Real self changes must still resolve on a landed hit, including a
        -- Substitute or KO, using the SAME existing stage/effect owner.
        if selfEffect and record.run and not ranSelf and ctx.user.mon.hp>0
            and not(hit>1 and onceSelf[id])then
          for _,msg in ipairs(selected.run(single)or{})do b:sayNext(msg)end
        end
        if hit<2 and ctx.user.mon.hp>0 and ctx.target.mon.hp>0 then
          -- Gen VI/VII update/consumption occurs between strikes, not after
          -- a second whole action. Do not invoke passive residual items.
          local berries=opts.berries or mod.exports and mod.exports.pokemonModernBerries67
          if berries then berries.apply(b,true,ctx.target);berries.apply(b,true,ctx.user)end
          local forms=mod.exports and mod.exports.pokemonHPForms67
          if forms then forms.watch(b)end
        end
      end
      ctx.hits,ctx.totalDealt,ctx.brokeSub=landed,total,broke
      if recoilEffect and landed>0 and ctx.user.mon.hp>0 then recoilEffect(ctx,total)end
      if landed>1 then
        b:sayNext(b:romText(ctx.user.isPlayer and '_MultiHitText'or'_HitXTimesText',
          ctx.user.isPlayer and 'Hit the enemy\n%d times!'or'Hit %d times!',landed))
      end
      if ctx.user.mon.hp<=0 and not seen[ctx.user]then
        seen[ctx.user]=true;pending[#pending+1]=ctx.user
      end
    end
    local out=pack(pcall(execute))
    b.accuracyRoll=rawAccuracy;b.onFaint=rawFaint;b.moveAnimRow=priorAnim;frames[b]=nil
    if not out[1]then error(out[2],0)end
    -- Native faint/EXP/finish queues follow the completed whole move. A
    -- faint on first contact stops the second strike, without another action.
    for _,w in ipairs(pending)do faint(b,w)end
    return unpack(out,2,out.n)
  end
  function M.install()
    FX._kascParentalBond67=M
    if FX._kascParentalBondWrapped67 then return end
    local original=FX.runDamaging
    FX.runDamaging=function(b,ctx,record)return FX._kascParentalBond67.run(original,b,ctx,record)end
    FX._kascParentalBondWrapped67=true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascParentalBond67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.damage,47000)
  -- Install after the existing single-strike wrappers/ordinary multihit Card.
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-per-strike-damage-contact-and-consumption-owners',
      providerStatus='gen6-7-native-parental-bond-single-opponent',
      buildReceiptId='docs/PARENTAL_BOND_67.md',rollbackReceiptId='docs/PARENTAL_BOND_67.md'})
  end
  return M
end
