-- Speed Swap exchanges raw battle stats, never saved Pokemon or stages.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-SPEED-SWAP',OWNER='kasc.speed-swap/v1'}
  local id,effect='SPEED_SWAP','KA_SPEED_SWAP_67';local tr=opts.i18n.text
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function failed()return {tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local row=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
        and r and r.mode~='off'and type(r.activeEpoch)=='number'and r.activeEpoch>=1 and r.activeEpoch<=7
        and row and row.kascSpeedSwap67==M.OWNER then return r.activeEpoch end
  end
  local function usable(u,t)
    return u and t and u~=t and u.mon and t.mon and u.mon.hp>0 and t.mon.hp>0 and not t.invulnerable
      and u.curStats and t.curStats and type(u.curStats.speed)=='number'and type(t.curStats.speed)=='number'
  end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target
    if not M.epoch(b)or not usable(u,t)or not ctx.move or ctx.move.id~=id
        or mod.exports.pokemonPriorityAbilities67.blocks(ctx)or mod.exports.pokemonProtection67.blocks(ctx)then return failed()end
    -- makeBattler aliases mon.stats; detach both before assigning. A normal
    -- switch-in therefore recovers each original stat, and checkpoints keep
    -- the battle-local curStats using the engine's existing serialization.
    local a,z=copy(u.curStats),copy(t.curStats)
    a.speed,z.speed=z.speed,a.speed
    u.curStats,t.curStats=a,z
    return {tr('Their Speed stats\nwere swapped!','Ihre Initiative\nwurde getauscht!')}
  end
  function M.noUseful(b,u,t,move)
    if not move or move.id~=id or not M.epoch(b)then return false end
    if not usable(u,t)or u.curStats.speed>=t.curStats.speed then return true end
    local ctx={battle=b,user=u,target=t,move=move}
    return mod.exports.pokemonPriorityAbilities67.blocks(ctx)or mod.exports.pokemonProtection67.blocks(ctx)
  end
  local fact=assert(opts.facts.move(id,7))
  assert(fact.number==683 and fact.type=='PSYCHIC_TYPE'and fact.category=='status'
    and fact.pp==10 and fact.accuracy==100 and fact.alwaysHits and fact.target==10,'Speed Swap source drift')
  assert(not mod.content.moves:get(id),'foreign Speed Swap owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascSpeedSwap67=M.OWNER,run=M.cast})
  mod.content.moves:register(id,{id=id,name=tr(fact.names.en,fact.names.de),type=fact.type,category='status',power=0,
    accuracy=100,pp=10,priority=0,effect=effect,originGeneration=7,backendMoveNumber=683,
    backendMoveOwner=M.OWNER,backendLearnsetRevision=18})
  -- Existing native local-energy emitter, without the spiral emitter's
  -- implicit trailing screen flash or AGILITY/CONFUSION's global palettes.
  local anim={seq={{effect='SE_SHOOT_BALLS_UPWARD',sound='FOCUS_ENERGY'}},source=M.OWNER}
  mod.content.battle_anims:register(id,anim)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',
      version='1.0.0',owner=M.OWNER,active=true,dependencyStatus='native-battle-stats-and-primary-effects',
      providerStatus='battle-local-speed-exchange',buildReceiptId='docs/SPEED_SWAP_67.md',
      rollbackReceiptId='docs/GEN6_WAVE15_SCOPE_20260909.md'})
  end
  return M
end
