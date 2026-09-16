-- Gear Up acts on the user's active side. Eligibility is an effective
-- Plus/Minus identity, not a party entry or the old Gen-III partner bonus.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-GEAR-UP',OWNER='kasc.gear-up/v1',ID='GEAR_UP'}
  local effect='KA_GEAR_UP_67';local tr=opts.i18n.text
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.epoch(b,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and type(r.activeEpoch)=='number'
        and r.activeEpoch>=1 and r.activeEpoch<=7
        and move and move.id==M.ID and move.backendMoveOwner==M.OWNER
        and marker and marker.kascGearUp67==M.OWNER then return r.activeEpoch end
  end
  function M.targets(b,user,move)
    if not M.epoch(b,move)then return {}end
    local plus=mod.exports.pokemonPlusMinus67
    local ability=mod.exports.pokemonAbilityEffects67
    if not plus or not ability then return {}end
    -- The existing owner enumerates engine-owned sides[].battlers,
    -- rejects eggs/fainted actors and deduplicates Pokemon identities.
    local rows=plus.active(b);local side
    for _,row in ipairs(rows)do if row.battler==user then side=row.side;break end end
    if not side then return {}end
    local targets={}
    for _,row in ipairs(rows)do
      if row.side==side then
        local id=ability.activeAbility(b,row.battler)
        if id=='PLUS'or id=='MINUS'then targets[#targets+1]=row.battler end
      end
    end
    return targets
  end
  local function stats(gen)return {'attack',gen==1 and 'special'or 'specialAttack'}end
  function M.noUseful(b,user,target,move)
    local gen=M.epoch(b,move);if not gen then return false end
    for _,who in ipairs(M.targets(b,user,move))do
      for _,stat in ipairs(stats(gen))do if (who.stages and who.stages[stat]or 0)<6 then return false end end
    end
    return true
  end
  function M.cast(ctx)
    local b,user,move=ctx.battle,ctx.user,ctx.move
    local gen=M.epoch(b,move);if not gen then return failed()end
    local split=mod.exports.backendSplitSpecial67
    if not split then return failed()end
    local messages,changed={},false
    for _,who in ipairs(M.targets(b,user,move))do
      for _,stat in ipairs(stats(gen))do
        local before=who.stages and who.stages[stat]or 0
        local result=split.changeStage(ctx,who,stat,1,false)
        if (who.stages and who.stages[stat]or 0)~=before then
          changed=true
          for _,message in ipairs(result)do messages[#messages+1]=message end
        end
      end
    end
    -- A capped first stat must not turn a successful second stat into the
    -- engine's "Nothing happened" animation-cancellation path.
    return changed and messages or failed()
  end
  local f=assert(opts.facts.move(M.ID,7))
  assert(f.number==674 and f.generation==7 and f.type=='STEEL'and f.category=='status'
    and f.power==0 and f.pp==20 and f.accuracy==100 and f.alwaysHits
    and f.priority==0 and f.target==13,'Gear Up source drift')
  assert(not mod.content.moves:get(M.ID),'foreign Gear Up owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,
    kascGearUp67=M.OWNER,run=M.cast})
  mod.content.moves:register(M.ID,{id=M.ID,name=tr(f.names.en,f.names.de),type='STEEL',category='status',
    power=0,accuracy=100,pp=20,priority=0,target=13,effect=effect,kascBypassSub67=true,
    originGeneration=7,backendMoveNumber=674,backendMoveOwner=M.OWNER,backendLearnsetRevision=29,
    anim=copy(assert(mod.content.moves:get('FOCUS_ENERGY')).anim)})
  -- Native stat-boost animation; its tiles/palettes are existing engine
  -- resources. No Pokemon sprite is generated or substituted here.
  local animation=copy(assert(mod.content.battle_anims:get('FOCUS_ENERGY')))
  animation.source=M.OWNER
  mod.content.battle_anims:register(M.ID,animation)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-active-sides-and-shared-stat-owners',providerStatus='plus-minus-active-side-stat-boost',
      buildReceiptId='docs/GEAR_UP_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
