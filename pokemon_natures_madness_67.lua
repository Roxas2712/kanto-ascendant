-- Fixed current-HP damage, not a Fairy base-power approximation.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-NATURES-MADNESS',OWNER='kasc.natures-madness/v1'}
  local id,effect='NATURES_MADNESS','KA_NATURES_MADNESS_67'
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  function M.active(b,move)
    local r=b and b.kascGenerationRulesReceipt
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and move and move.id==id and move.backendMoveOwner==M.OWNER
  end
  function M.choose(ctx)
    if not M.active(ctx.battle,ctx.move)then return nil,opts.i18n.text('But, it failed!','Doch es schlug fehl!')end
    -- Substitute receives damage based on the actual Pokemon's current HP.
    -- The native hit pipeline still owns accuracy, decoys, Faint and reactions.
    return math.max(1,math.floor(ctx.target.mon.hp/2)),{crit=false,typeMult=10}
  end
  local fact=assert(opts.facts.move(id,7))
  assert(fact.number==717 and fact.type=='FAIRY'and fact.category=='special'
    and fact.power==0 and fact.accuracy==90 and fact.pp==10 and fact.priority==0
    and fact.target==10,'Nature\'s Madness source drift')
  assert(not mod.content.moves:get(id),'foreign Nature\'s Madness owner')
  mod.content.move_effects:register(effect,{kind='full',chooseDamage=M.choose})
  mod.content.moves:register(id,{id=id,name=opts.i18n.text(fact.names.en,fact.names.de),
    type='FAIRY',category='special',power=1,accuracy=90,pp=10,priority=0,contact=false,
    effect=effect,originGeneration=7,backendMoveNumber=717,backendMoveOwner=M.OWNER,
    backendLearnsetRevision=16,kascFixedDamage67=true,
    anim=copy(assert(mod.content.moves:get('SUPER_FANG')).anim)})
  -- Like native Super Fang, 1 is a damaging-pipeline sentinel, not base power.
  -- BattleAPI hides power when chooseDamage exists; previews use the same HP rule.
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if M.active(ctx.battle,ctx.move)and not(ctx.opts and ctx.opts.typeless)then return M.choose(ctx)end
    return nextDamage(ctx)
  end,12000)
  local anim={seq={}}
  for _,part in ipairs({'FLASH','SUPER_FANG'})do
    for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do anim.seq[#anim.seq+1]=copy(step)end
  end
  anim.source=M.OWNER
  mod.content.battle_anims:register(id,anim)
  -- The native Flash star reaches the lower HUD at its original anchor.
  -- Translate only this composed move's visible OAM tiles, never Pokemon,
  -- shared source blocks, screen effects, timing, or other move animations.
  local Player=require('src.battle.AnimPlayer')
  function M.position(player,moveId)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[moveId]
    if moveId~=id or not row or row.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do
      local sprites={}
      for i,s in ipairs(step.sprites or{})do
        local shifted=copy(s)
        if s.x>0 and s.x<168 and s.y>=16 and s.y<144 then shifted.y=s.y-16 end
        sprites[i]=shifted
      end
      step.sprites=sprites
    end
  end
  Player._kascNaturesMadness67=M
  if not Player._kascNaturesMadnessWrapped67 then
    local start=Player.start
    Player.start=function(self,moveId,...)
      local result=start(self,moveId,...)
      Player._kascNaturesMadness67.position(self,moveId)
      return result
    end
    Player._kascNaturesMadnessWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-fixed-damage-pipeline',
      providerStatus='current-hp-half',buildReceiptId='docs/NATURES_MADNESS_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
