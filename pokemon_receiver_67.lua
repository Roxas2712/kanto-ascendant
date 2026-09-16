-- Receiver / Power of Alchemy: battle-only inheritance, never a saved slot.
return function(mod,opts)
  local B=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-RECEIVER',OWNER='kasc.receiver/v1'}
  -- Pinned Gen-VII noreceiver flags, not the different Trace exclusions.
  local excluded={BATTLE_BOND=true,COMATOSE=true,DISGUISE=true,FLOWER_GIFT=true,
    FORECAST=true,ILLUSION=true,IMPOSTER=true,MULTITYPE=true,POWER_CONSTRUCT=true,
    POWER_OF_ALCHEMY=true,RECEIVER=true,RKS_SYSTEM=true,SCHOOLING=true,
    SHIELDS_DOWN=true,STANCE_CHANGE=true,TRACE=true,WONDER_GUARD=true,ZEN_MODE=true}
  function M.epoch(b)
    local r=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.result and r and r.kascReceiver67==M.OWNER
      and opts.status.epoch(b)==7 and 7 or nil
  end
  function M.canCopy(id)return type(id)=='string'and id~='NO_ABILITY'and not excluded[id]end
  local function position(b,w)
    for index,side in ipairs(b.sides or{})do
      for _,active in ipairs(side.battlers or{})do
        if active==w and w.isPlayer==(index==1)then return index end
      end
    end
  end
  function M.receive(b,who,fallen)
    if not M.epoch(b)or not who or not fallen or who==fallen or not who.mon or not fallen.mon
        or who.mon.hp<=0 or fallen.mon.hp~=0 or who.fainted
        or who.mon.isEgg or who.mon.egg or who.mon.is_egg or who.mon.eggSpecies
        or fallen.mon.isEgg or fallen.mon.egg or fallen.mon.is_egg or fallen.mon.eggSpecies then return false end
    local lane=position(b,who)
    if not lane or lane~=position(b,fallen)then return false end
    local ability=opts.abilities.activeAbility(b,who)
    if ability~='RECEIVER'and ability~='POWER_OF_ALCHEMY'then return false end
    -- A fainted/suppressed donor still has its actual (possibly copied)
    -- identity. The receiving holder, by contrast, must be active.
    local id=opts.abilities.abilityIdentity(b,fallen)
    if not M.canCopy(id)or not opts.abilities.overrideAbility(b,who,id,'receiver')then return false end
    b:sayNext(opts.i18n.text(ability=='RECEIVER'and'Receiver!'or'Power of Alchemy!',
      ability=='RECEIVER'and'Receiver!'or'Chemiekraft!'))
    opts.abilities.transformedAbilityChanged(b,who,true)
    return true
  end
  function M.fainted(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    -- The native host has these two addressable battlers. Do not promote
    -- reserves or the rival scene's visual Pokemon into combatants.
    for _,who in ipairs({b.player,b.enemy})do M.receive(b,who,ev.battler)end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascReceiver67=M.OWNER})
  mod.events:on('battle.fainted',M.fainted,20000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-faint-ability-override-checkpoint',providerStatus='receiver-vii',
      buildReceiptId='docs/RECEIVER_67.md',rollbackReceiptId='docs/RECEIVER_67.md'})
  end
  return M
end
