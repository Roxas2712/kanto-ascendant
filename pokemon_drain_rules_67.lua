-- Shared draining ratios and Liquid Ooze. Native hit/faint sequencing stays
-- in EffectRegistry; no post-hoc HP rollback and no mutation of base stats.
return function(mod,opts)
  local M={CARD_ID='KASC-67-DRAIN-RULES',OWNER='kasc.drain-rules/v1'}
  local B=require('src.battle.BattleState');local Effects=require('src.battle.EffectRegistry')
  local aliases={}
  for id in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end
  end
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascDrainOwner67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.afterDamage(original,ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b)
    local block=mod.exports.pokemonHealBlock67
    if block and block.blocksRecovery(b,u,'drain')then return end
    if not gen then return original(ctx)end
    if u.mon.hp<=0 or (ctx.totalDealt or 0)<=0 then return end
    local id=aliases[ctx.move.id]or ctx.move.id
    local facts=opts.facts.move(id,gen);local ratio=facts and facts.meta and facts.meta.drain
    ratio=ratio and ratio>0 and ratio/100 or 0.5
    local raw=ctx.totalDealt*ratio
    local amount=math.max(1,ctx.kascDrainSub67 and math.ceil(raw)
      or gen<=4 and math.floor(raw)or math.floor(raw+0.5))
    local sap=mod.exports.pokemonStrengthSap67
    if sap then amount=sap.drainAmount(b,u,amount)end
    if opts.abilities.activeAbility(b,t)=='LIQUID_OOZE'and (gen>=5 or id~='DREAM_EATER')then
      if opts.abilities.blocksIndirect(b,u,'ooze')then return end
      -- Indirect Ooze damage bypasses the drainer's own Substitute and must
      -- not feed Bide or Rage. Native damage still queues the HP animation.
      local sub,bide,rage=u.substituteHP,u.bideTurns,u.rageMove
      u.substituteHP,u.bideTurns,u.rageMove=nil,nil,nil
      local ok,err=pcall(b.applyDamage,b,u,amount)
      u.substituteHP,u.bideTurns,u.rageMove=sub,bide,rage
      if not ok then error(err,0)end
      ctx.say(opts.i18n.text('Liquid Ooze hurts the drainer!','Kloakensoße schadet dem Sauger!'))
    else
      u.mon.hp=math.min(u.mon.stats.hp,u.mon.hp+amount)
      ctx.drain();ctx.say(opts.i18n.text('Drained HP!','KP abgesaugt!'))
    end
  end
  local function indirect(ctx,amount)
    local u,b=ctx.user,ctx.battle
    local sub,bide,rage=u.substituteHP,u.bideTurns,u.rageMove
    u.substituteHP,u.bideTurns,u.rageMove=nil,nil,nil
    local ok,err=pcall(b.applyDamage,b,u,math.max(1,amount))
    u.substituteHP,u.bideTurns,u.rageMove=sub,bide,rage
    if not ok then error(err,0)end
  end
  function M.recoil(original,ctx)
    local gen=M.epoch(ctx.battle)
    if not gen then return original(ctx)end
    if ctx.user.mon.hp<=0 or (ctx.totalDealt or 0)<=0 then return end
    local id=aliases[ctx.move.id]or ctx.move.id
    local struggle=id=='STRUGGLE'or ctx.moveInst.struggle
    if not struggle and (opts.abilities.activeAbility(ctx.battle,ctx.user)=='ROCK_HEAD'
        or opts.abilities.blocksIndirect(ctx.battle,ctx.user,'recoil'))then return end
    local raw
    if struggle then
      raw=(gen>=4 and ctx.user.mon.stats.hp or ctx.totalDealt)/4
    else
      local facts=opts.facts.move(id,gen)
      local ratio=facts and facts.meta and facts.meta.drain
      if not ratio or ratio>=0 then return original(ctx)end
      -- Canonical metadata represents the one-third fraction as -33.
      raw=ctx.totalDealt*(ratio==-33 and 1/3 or -ratio/100)
    end
    indirect(ctx,gen<=4 and math.floor(raw)or math.floor(raw+0.5))
    ctx.say(opts.i18n.text('Hit with recoil!','Rückstoß verursacht Schaden!'))
  end
  local recoil=assert(mod.content.move_effects:get('RECOIL_EFFECT').afterDamage)
  mod.content.move_effects:patch('RECOIL_EFFECT',{afterDamage=function(ctx)return M.recoil(recoil,ctx)end})
  local crash=assert(mod.content.move_effects:get('JUMP_KICK_EFFECT').onMiss)
  mod.content.move_effects:patch('JUMP_KICK_EFFECT',{onMiss=function(ctx,reason)
    local gen=M.epoch(ctx.battle)
    if not gen or gen<5 then return crash(ctx,reason)end
    if ctx.user.mon.hp<=0 or opts.abilities.blocksIndirect(ctx.battle,ctx.user,'crash')then return end
    indirect(ctx,math.floor(ctx.user.mon.stats.hp/2))
    ctx.say(opts.i18n.text('Kept going and crashed!','Die Attacke ging daneben!'))
  end})
  for _,id in ipairs({'DRAIN_HP_EFFECT','DREAM_EATER_EFFECT'})do
    local old=assert(mod.content.move_effects:get(id).afterDamage)
    mod.content.move_effects:patch(id,{afterDamage=function(ctx)return M.afterDamage(old,ctx)end})
  end
  Effects._kascDrainRules67=M
  if not Effects._kascDrainWrapped67 then
    local old=Effects.runDamaging
    Effects.runDamaging=function(b,ctx,record)
      ctx.kascDrainSub67=ctx.target and ctx.target.substituteHP~=nil
      return old(b,ctx,record)
    end
    Effects._kascDrainWrapped67=true
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascDrainOwner67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-drain-and-residual',providerStatus='era-drain-ratios-and-ooze',
      buildReceiptId='docs/FINISH_1600_20260910.md',rollbackReceiptId='docs/FINISH_1600_20260910.md'})
  end
  return M
end
