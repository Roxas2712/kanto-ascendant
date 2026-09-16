-- Held-item effects are not item possession. Explicit battle context avoids
-- removing inventory, losing Acrobatics/Trick semantics or changing saves.
return function(mod,opts)
  local M={CARD_ID='KASC-67-HELD-EFFECT',OWNER='kasc.held-effect/v1'}
  local B=require('src.battle.BattleState');local A=opts.abilities
  -- These training items retain their battle Speed penalty under Klutz.
  -- Primal form orbs are also unaffected; form activation remains its owner.
  local exempt={MACHO_BRACE=true,POWER_ANKLET=true,POWER_BAND=true,POWER_BELT=true,
    POWER_BRACER=true,POWER_LENS=true,POWER_WEIGHT=true,BLUE_ORB=true,RED_ORB=true}
  function M.epoch(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=row and row.kascHeldEffect67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==B and not b.result and gen and gen>=4 and gen<=7 then return gen end
  end
  function M.suppressed(b,w,id)
    return id and not exempt[id]and M.epoch(b)~=nil and w and w.mon
      and A.activeAbility(b,w)=='KLUTZ'or false
  end
  function M.held(mon,b,w)
    local id,err=opts.held(mon)
    if err or not id or not b then return id,err end
    -- Preview battlers may be detached. Use the real side for copied or
    -- overridden ability identity, not the preview's original birth slot.
    w=b.player and b.player.mon==mon and b.player or b.enemy and b.enemy.mon==mon and b.enemy or w
    local future=mod.exports and mod.exports.pokemonFutureStrikes67
    if future and w and w.mon==mon and future.sourceInactive(b,w)then return false end
    if w and w.mon==mon and M.suppressed(b,w,id)then return false end
    return id,err
  end
  function M.itemSuppressed(game,mon,ability,id,gen)
    return id and not exempt[id]and ability and ability.active and ability.id=='KLUTZ'
      and A.supportsAbility(game,'KLUTZ',gen)or false
  end
  function M.blocksMove(b,w,id)
    local gen=M.epoch(b)
    return gen and A.activeAbility(b,w)=='KLUTZ'
      and (id=='NATURAL_GIFT'or id=='FLING'and gen>=5)or false
  end
  -- Preserve each existing effect. This adds only Klutz's application gate,
  -- not a claim that the catalogue's other Fling/Natural Gift logic is complete.
  for _,id in ipairs({'FLING','NATURAL_GIFT'})do
    for _,alias in ipairs(opts.species.moveIds(id))do
      local move=mod.content.moves:get(alias)
      local old=move and mod.content.move_effects:get(move.effect)
      if old and not move.backendMoveOwner then
        local effect={};for k,v in pairs(old)do effect[k]=v end
        effect.gate=function(ctx)
          if M.blocksMove(ctx.battle,ctx.user,id)then
            return false,opts.i18n.text('Klutz prevents using the held item!',
              'Tollpatsch verhindert den Einsatz des getragenen Items!')
          end
          if old.gate then return old.gate(ctx)end
          return true
        end
        local name='KA_HELD_GATE_'..alias
        mod.content.move_effects:register(name,effect)
        mod.content.moves:patch(alias,{effect=name})
      end
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHeldEffect67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='explicit-native-item-effect-consumers',providerStatus='klutz-no-possession-mutation',
      buildReceiptId='docs/KLUTZ_67.md',rollbackReceiptId='docs/KLUTZ_67.md'})
  end
  return M
end
