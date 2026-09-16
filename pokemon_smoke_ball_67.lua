-- KASC-67-SMOKE-BALL. Native KASC wild-run adapter; no Gen2-engine owner.
-- A held item is not a consumable Poke Doll and cannot end trainer/raid locks.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-SMOKE-BALL',owner='kasc.smoke-ball/v1'}
  local source=assert(opts.facts.item('SMOKE_BALL',2))
  assert(source.effect=='HELD_ESCAPE')
  local epochs={[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true}
  local existing=mod.content.items:get('SMOKE_BALL')
  if not existing then
    mod.content.items:register('SMOKE_BALL',{id='SMOKE_BALL',
      name=opts.i18n.text('SMOKE BALL','RAUCHBALL'),
      names={en='SMOKE BALL',de='RAUCHBALL'},price=source.cost or 200,
      originGeneration=2,keyItem=false,tossable=true,needsTarget=false})
  end
  mod.content.items:patch('SMOKE_BALL',{kascSmokeBallOwner67=M.owner,
    kascEquipmentRewardEpochs=epochs})
  if existing and existing.kascEquipmentCatalog then
    mod.content.items:patch('SMOKE_BALL',{
      name=opts.i18n.text('SMOKE BALL','RAUCHBALL'),
      names={en='SMOKE BALL',de='RAUCHBALL'}})
  end
  function M.supportsItem(game,id,epoch)
    local def=game and game.data and game.data.items and game.data.items[id]
    return id=='SMOKE_BALL' and def and def.kascSmokeBallOwner67==M.owner
      and epochs[epoch]==true or false
  end
  local function epoch(b)
    local receipt=b.kascGenerationRulesReceipt
    if receipt then return receipt.mode=='off' and 1 or receipt.activeEpoch end
    local bucket=b.game and b.game.save and b.game.save.modData
    local state=bucket and bucket[mod.id] and bucket[mod.id][opts.rules.SAVE_KEY]
    return state and state.activeMode~='off' and state.activeEpoch or 1
  end
  function M.run(nextRun,ctx)
    local b=ctx and ctx.battle
    if getmetatable(b)~=Battle or b.demo or b.kind~='wild' or b.result
        or b.kaRocketNoEscape or b.kaMythicEcho
        or not b.player or not b.player.mon then return nextRun(ctx)end
    local gen=epoch(b);local mon=b.player.mon
    if not M.supportsItem(b.game,opts.held(mon,b,b.player),gen) then return nextRun(ctx)end
    -- Gen V removed the guaranteed escape with a fainted holder.
    if gen>=5 and (tonumber(mon.hp) or 0)<=0 then return nextRun(ctx)end
    local trapping=opts.trapping()
    if gen==2 and trapping and trapping.blocked(b,b.player) then return nextRun(ctx)end
    return true
  end
  -- Story/raid restrictions (positive priorities) remain outside this link.
  -- Gen3+ item escape precedes the partial-trap restriction (-9000).
  mod.hooks:wrap('battle.run',M.run,-6500)
  return M
end
