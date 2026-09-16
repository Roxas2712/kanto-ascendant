-- An opposing puff damages; an allied puff heals without striking Substitute.
-- Side membership comes from the battle, never a saved species or a caller flag.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local M={CARD_ID='KASC-67-POLLEN-PUFF',OWNER='kasc.pollen-puff/v1',ID='POLLEN_PUFF',HEAL_ANIM='KA_POLLEN_PUFF_HEAL_67'}
  local effect='KA_POLLEN_PUFF_67';local tr=opts.i18n.text
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  function M.active(b,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
      and move and move.id==M.ID and move.backendMoveOwner==M.OWNER
      and marker and marker.kascPollenPuff67==M.OWNER
  end
  function M.side(b,w)
    if not w or not w.mon then return end
    local found
    for _,side in ipairs(b and b.sides or{})do for _,member in ipairs(side.battlers or{})do
      if member==w then if found and found~=side then return end;found=side end
    end end
    return found
  end
  function M.ally(b,u,t)
    if not u or not t or u==t then return false end
    local us,ts=M.side(b,u),M.side(b,t)
    return us~=nil and us==ts
  end
  local function fail(b,text)
    b:cancelMoveAnim();b:sayNext(text or tr('But, it failed!','Doch es schlug fehl!'))
  end
  function M.perform(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    if not M.active(b,ctx.move)or not M.side(b,u)or not M.side(b,t)or u==t
        or not u.mon or not t.mon or u.mon.hp<=0 or t.mon.hp<=0 then return fail(b)end
    if not M.ally(b,u,t)then return FX.runDamaging(b,ctx,b.data.move_effects[effect])end
    local block=mod.exports.pokemonHealBlock67
    assert(block and type(block.blocked)=='function','Pollen Puff needs the shared Heal Block owner')
    if block.blocked(b,u)or block.blocked(b,t)then
      return fail(b,tr('Heal Block prevents recovery!','Heilblockade verhindert die Heilung!'))
    end
    if t.invulnerable then return fail(b,tr('The attack missed!','Die Attacke ging daneben!'))end
    local protection=assert(mod.exports.pokemonProtection67)
    if protection.blocks(ctx)then return fail(b,protection.notice(ctx,false))end
    -- Kugelsicher stops an allied healing puff as well as an enemy attack.
    -- The shared owner retains Mold Breaker and ability-suppression semantics.
    if assert(mod.exports.pokemonTypeAbsorption67).absorb(b,ctx)then return end
    if not ctx.accuracyRoll()then return fail(b,tr('The attack missed!','Die Attacke ging daneben!'))end
    -- Pollen Puff is ballistic, not a powder or a healing pulse. It ignores
    -- allied Substitute and uses floor(maximum/2), unlike Heal Pulse's ceil.
    if b.moveAnimRow then b.moveAnimRow.anim=M.HEAL_ANIM end
    if t.mon.hp>=t.mon.stats.hp then
      b:sayNext(tr('No HP recovery was needed!','Es war keine KP-Heilung nötig!'));return
    end
    local messages=assert(mod.exports.pokemonHealingMoves67).heal(ctx,t,math.floor(t.mon.stats.hp/2))
    for _,message in ipairs(messages)do b:sayNext(message)end
  end
  local f=assert(opts.facts.move(M.ID,7))
  assert(f.number==676 and f.type=='BUG'and f.category=='special'and f.power==90
    and f.accuracy==100 and f.pp==15 and f.priority==0 and f.target==10,'Pollen Puff source drift')
  assert(not mod.content.moves:get(M.ID),'foreign Pollen Puff owner')
  mod.content.move_effects:register(effect,{kind='full',kascPollenPuff67=M.OWNER,perform=M.perform,
    gate=function(ctx)
      if M.active(ctx.battle,ctx.move)then return true end
      return false,tr('But, it failed!','Doch es schlug fehl!')
    end})
  mod.content.moves:register(M.ID,{id=M.ID,name=tr(f.names.en,f.names.de),type='BUG',category='special',power=90,
    accuracy=100,pp=15,priority=0,target=10,contact=false,effect=effect,originGeneration=7,
    backendMoveNumber=676,backendMoveOwner=M.OWNER,backendLearnsetRevision=30,
    anim=copy(assert(mod.content.moves:get('EGG_BOMB')).anim)})
  for id,source in pairs({[M.ID]='EGG_BOMB',[M.HEAL_ANIM]='RECOVER'})do
    local anim=copy(assert(mod.content.battle_anims:get(source)));anim.source=M.OWNER
    mod.content.battle_anims:register(id,anim)
  end
  -- AI evaluation of an allied puff must not report damage or restore HP.
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if ctx and M.active(ctx.battle,ctx.move)and M.ally(ctx.battle,ctx.user,ctx.target)
        and not(ctx.opts and ctx.opts.typeless)then return 0,{crit=false,typeMult=10}end
    return nextDamage(ctx)
  end,30550)
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if (id~=M.ID and id~=M.HEAL_ANIM)or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local shift=-16;local sprites={}
      for _,s in ipairs(step.sprites or{})do
        if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end
      end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        if mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  Player._kascPollenPuffAnimation67=M
  if not Player._kascPollenPuffAnimationWrapped67 then local start=Player.start
    Player.start=function(self,id,...)
      local result=start(self,id,...);Player._kascPollenPuffAnimation67.position(self,id);return result
    end;Player._kascPollenPuffAnimationWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-damage-shared-healing-protection-and-heal-block',
      providerStatus='opposing-damage-or-allied-half-maximum-healing',buildReceiptId='docs/POLLEN_PUFF_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
