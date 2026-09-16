-- Strength Sap uses the target's staged, otherwise unmodified Attack.
-- Big Root is shared with drain/seed owners; no Pokemon art or UI owner.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Stats=require('src.pokemon.Stats')
  local M={CARD_ID='KASC-67-STRENGTH-SAP',OWNER='kasc.strength-sap/v1'}
  local tr=opts.i18n.text;local id,effect='STRENGTH_SAP','KA_STRENGTH_SAP_67'
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt;local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and marker and marker.kascStrengthSap67==M.OWNER then return r.activeEpoch end
  end
  function M.supportsItem(game,item,gen)
    local d=game and game.data and game.data.items and game.data.items[item]
    return item=='BIG_ROOT'and d and d.kascStrengthSap67==M.OWNER and type(gen)=='number'and gen>=4 and gen<=7 or false
  end
  function M.drainAmount(b,w,amount)
    local gen=M.epoch(b);local equipment=mod.exports.pokemonEquipment67
    if gen and gen>=4 and M.supportsItem(b.game,'BIG_ROOT',gen)
        and equipment.battleHeldId(w.mon,b,w)=='BIG_ROOT'then
      return math.max(1,math.floor((amount*5324+2047)/4096))
    end
    return amount
  end
  function M.attack(w,gen)
    local value=w.curStats.attack;local stage=math.max(-6,math.min(6,(w.stages or{}).attack or 0))
    if gen==1 then return Stats.applyStage(value,stage)end
    if gen==2 and stage<0 then return math.max(1,math.floor(value*({66,50,40,33,28,25})[-stage]/100))end
    return math.max(1,math.floor(stage>=0 and value*(2+stage)/2 or value*2/(2-stage)))
  end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b)
    if not gen or not u or not t or u==t or u.mon.hp<=0 or t.mon.hp<=0 or t.invulnerable or t.substituteHP
        or ((t.stages or{}).attack or 0)<=-6 then return failed()end
    local A=mod.exports.pokemonAbilityEffects67
    local block=mod.exports.pokemonHealBlock67
    if block and block.moveBlocked(b,u,ctx.move,t)then return failed()end
    if mod.exports.pokemonPriorityAbilities67.blocks(ctx)then return failed()end
    local amount=M.drainAmount(b,u,M.attack(t,gen));local before=(t.stages or{}).attack or 0
    local messages=mod.exports.backendSplitSpecial67.changeStage(ctx,t,'attack',-1,true)or{}
    local lowered=((t.stages or{}).attack or 0)~=before
    local health={};local oldHP=u.mon.hp
    if gen>=3 and A.activeAbility(b,t)=='LIQUID_OOZE'then
      if not A.blocksIndirect(b,u,'ooze')then
        -- Ooze is indirect: it cannot damage the user's decoy or charge Bide.
        local sub,bide,rage=u.substituteHP,u.bideTurns,u.rageMove
        u.substituteHP,u.bideTurns,u.rageMove=nil,nil,nil
        local ok,err=pcall(b.applyDamage,b,u,amount)
        u.substituteHP,u.bideTurns,u.rageMove=sub,bide,rage
        if not ok then error(err,0)end
        health={tr('Liquid Ooze hurts the drainer!','Kloakensoße schadet dem Sauger!')}
        if u.mon.hp<=0 then b:onFaint(u)end
      end
    elseif u.mon.hp<u.mon.stats.hp and not(block and block.blocksRecovery(b,u,'move'))then
      u.mon.hp=math.min(u.mon.stats.hp,u.mon.hp+amount);ctx.drain()
      health={tr('%s regained HP!','%s hat KP zurückerhalten!'):format(u.name)}
    end
    -- A blocked stat drop must not cancel the successful healing animation.
    if not lowered and u.mon.hp~=oldHP then
      for _,m in ipairs(messages)do health[#health+1]=m end;return health
    end
    for _,m in ipairs(health)do messages[#messages+1]=m end
    if not lowered and u.mon.hp==oldHP then messages.failed=true end
    if #messages==0 then return failed()end
    return messages
  end
  function M.noUseful(b,u,t,move)
    local gen=M.epoch(b)
    if not gen or not move or move.id~=id then return false end
    local A=mod.exports.pokemonAbilityEffects67
    return A.moveScope(b,u,t,true,function()
      if not u or not t or u.mon.hp<=0 or t.mon.hp<=0 or t.substituteHP or t.invulnerable
          or ((t.stages or{}).attack or 0)<=-6 then return true end
      local ctx={battle=b,user=u,target=t,move=move}
      if mod.exports.pokemonPriorityAbilities67.blocks(ctx)or mod.exports.pokemonProtection67.blocks(ctx)
          or mod.exports.pokemonTypeAbsorption67.canAbsorb(b,u,t,move)
          or A.activeAbility(b,t)=='MAGIC_BOUNCE'and gen>=5 then return true end
      local ooze=gen>=3 and A.activeAbility(b,t)=='LIQUID_OOZE'
      if ooze and not A.blocksIndirect(b,u,'ooze')then return true end
      local drop=A.stageDelta(b,t,-1)<0 and not t.mist and not A.blockStatDrop(b,t,'attack',-1,true)
      return not drop and (ooze or u.mon.hp>=u.mon.stats.hp)
    end,move)
  end
  local fact=assert(opts.facts.move(id,7))
  assert(fact.number==668 and fact.type=='GRASS'and fact.category=='status'and fact.pp==10
    and fact.accuracy==100 and not fact.alwaysHits and fact.target==10,'Strength Sap source drift')
  assert(not mod.content.moves:get(id),'foreign Strength Sap owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=true,kascStrengthSap67=M.OWNER,run=M.cast})
  mod.content.moves:register(id,{id=id,name=tr(fact.names.en,fact.names.de),type='GRASS',category='status',power=0,
    accuracy=100,pp=10,priority=0,effect=effect,originGeneration=7,backendMoveNumber=668,
    backendMoveOwner=M.OWNER,backendLearnsetRevision=15})
  local anim={seq={}}
  for _,part in ipairs({'ABSORB','GROWL'})do
    for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(step)end
  end
  mod.content.battle_anims:register(id,anim)
  local root=mod.content.items:get('BIG_ROOT')
  local patch={id='BIG_ROOT',name=root and root.name or tr('BIG ROOT','GROSSWURZEL'),originGeneration=4,
    keyItem=false,tossable=true,needsTarget=false,price=root and root.price or 4000,kascStrengthSap67=M.OWNER,
    kascEquipmentRewardEpochs={[4]=true,[5]=true,[6]=true,[7]=true}}
  if root then mod.content.items:patch('BIG_ROOT',patch)else mod.content.items:register('BIG_ROOT',patch)end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-stages-drain-and-equipment',
      providerStatus='staged-attack-heal-and-root',buildReceiptId='docs/STRENGTH_SAP_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
