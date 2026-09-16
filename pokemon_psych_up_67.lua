-- Psych Up assigns battle stages directly: this is not a sequence of
-- raises/drops and must not trigger Contrary, Simple or stat-drop abilities.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-PSYCH-UP',OWNER='kasc.psych-up/v1',ID='PSYCH_UP'}
  local effect='KA_PSYCH_UP_67';local tr=opts.i18n.text
  local stageKeys={'attack','defense','speed','special','specialAttack','specialDefense','accuracy','evasion'}
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function side(b,w)return b and(w==b.player and 'player'or w==b.enemy and 'enemy')or nil end
  function M.epoch(b,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch%1==0
        and r.activeEpoch>=1 and r.activeEpoch<=7 and marker and marker.kascPsychUp67==M.OWNER
        and move and move.id==M.ID and move.backendMoveOwner==M.OWNER then return r.activeEpoch end
  end
  local function usable(b,u,t)
    return side(b,u)and side(b,t)and u~=t and u.mon and t.mon and u.mon.hp>0 and t.mon.hp>0
  end
  local function blocked(ctx)
    local priority=mod.exports and mod.exports.pokemonPriorityAbilities67
    -- It bypasses Substitute, Protect and a semi-invulnerable target;
    -- VII's Prankster/Dark rule is still an independent targeting gate.
    return priority and priority.blocks(ctx)or false
  end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen=M.epoch(b,ctx.move)
    if not gen or not usable(b,u,t)or blocked(ctx)then return failed()end
    local stages={}
    for _,key in ipairs(stageKeys)do if t.stages and t.stages[key]~=nil then stages[key]=t.stages[key]end end
    u.stages=stages;u.hazeStatReset=nil
    -- II--V's inherited Gen-V onHit copies only boosts; existing critical
    -- volatiles stay unchanged. VI copies/removes Focus Energy. VII also
    -- copies/removes Laser Focus, using its own duration/checkpoint owner.
    if gen>=6 then u.focusEnergy=t.focusEnergy and true or nil end
    if gen>=7 then
      local laser=mod.exports and mod.exports.pokemonLaserFocus67
      if laser then laser.copyFrom(b,u,t)end
    end
    return {tr('%s copied the\nstat changes!','%s kopiert die\nStatusveränderungen!'):format(u.name or u.mon.species)}
  end
  function M.noUseful(b,u,t,move)
    local gen=M.epoch(b,move);if not gen then return false end
    if not usable(b,u,t)or blocked({battle=b,user=u,target=t,move=move})then return true end
    for _,key in ipairs(stageKeys)do
      local relevant=gen==1 and key~='specialAttack'and key~='specialDefense'or gen>=2 and key~='special'
      if relevant and (t.stages and t.stages[key]or 0)>(u.stages and u.stages[key]or 0)then return false end
    end
    if gen>=6 and t.focusEnergy and not u.focusEnergy then return false end
    local laser=mod.exports and mod.exports.pokemonLaserFocus67
    if gen>=7 and laser and laser.active(b,t)and not laser.active(b,u)then return false end
    return true
  end
  local fact=assert(opts.facts.move(M.ID,7))
  assert(fact.number==244 and fact.generation==2 and fact.type=='NORMAL'and fact.category=='status'
    and fact.power==0 and fact.pp==10 and fact.accuracy==100 and fact.alwaysHits
    and fact.priority==0 and fact.target==10,'Psych Up source drift')
  local prior=assert(mod.content.moves:get(M.ID),'Psych Up catalog missing')
  assert(not prior.backendMoveOwner and prior.effect=='KA_GEN_MOVE_UNSUPPORTED_'..M.ID,'foreign Psych Up owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascPsychUp67=M.OWNER,run=M.cast})
  mod.content.moves:patch(M.ID,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=244,
    backendLearnsetRevision=prior.backendLearnsetRevision or 1,originGeneration=2,
    power=0,pp=10,accuracy=100,priority=0,category='status',target=10,kascBypassSub67=true})
  -- Native local energy emitter already used by Speed Swap. Its existing
  -- tiles/palettes need no new Pokemon artwork or global screen flash.
  mod.content.battle_anims:patch(M.ID,{seq={{effect='SE_SHOOT_BALLS_UPWARD',sound='FOCUS_ENERGY'}},source=M.OWNER})
  for i=#assert(opts.moves.unsupportedStatus),1,-1 do
    if opts.moves.unsupportedStatus[i]==M.ID then table.remove(opts.moves.unsupportedStatus,i)end
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-battle-stages-and-critical-volatile-owners',providerStatus='direct-generation-correct-stage-copy',
      buildReceiptId='docs/PSYCH_UP_67.md',rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
