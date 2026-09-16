-- KASC-67-POKEMON-EQUIPMENT: first native Gen1-engine held-effect adapter.
-- Gen2 source: HandleLeftovers / HandleHealingItems, pinned in the backend
-- authority. Legacy berries retain their original identities and amounts.
-- Status recovery follows UseHeldStatusHealingItem/UseConfusionHealingItem.
-- Other held effects must not advertise readiness through this owner.
return function(mod,opts)
  local facts=assert(opts.facts)
  local rules=assert(opts.rules)
  local held=assert(opts.held)
  local tr=opts.i18n.text
  local definitions={
    BERRY={en='BERRY',de='BEERE',effect='HELD_BERRY',amount=10},
    GOLD_BERRY={en='GOLD BERRY',de='GOLDBEERE',effect='HELD_BERRY',amount=30},
    LEFTOVERS={en='LEFTOVERS',de='ÜBERRESTE',effect='HELD_LEFTOVERS'},
    PSNCUREBERRY={en='PSNCUREBERRY',de='GIFTBEERE',effect='HELD_HEAL_POISON',status='PSN'},
    PRZCUREBERRY={en='PRZCUREBERRY',de='ANTIPARBEERE',effect='HELD_HEAL_PARALYZE',status='PAR'},
    BURNT_BERRY={en='BURNT BERRY',de='BRANDBEERE',effect='HELD_HEAL_FREEZE',status='FRZ'},
    ICE_BERRY={en='ICE BERRY',de='EISBEERE',effect='HELD_HEAL_BURN',status='BRN'},
    MINT_BERRY={en='MINT BERRY',de='MINZBEERE',effect='HELD_HEAL_SLEEP',status='SLP'},
    BITTER_BERRY={en='BITTER BERRY',de='BITTERBEERE',effect='HELD_HEAL_CONFUSION',confusion=true},
    MIRACLEBERRY={en='MIRACLEBERRY',de='WUNDERBEERE',effect='HELD_HEAL_STATUS',allStatus=true,confusion=true},
    MYSTERYBERRY={en='MYSTERYBERRY',de='RÄTSELBEERE',effect='HELD_RESTORE_PP',pp=true},
  }
  local M={CARD_ID='KASC-67-HELD-HP-EFFECTS',owner='kasc.held-hp-effects/v1'}
  -- Native checkpoints persist field.tokens, not module-local weak tables.
  local function tokens(b)
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    return b.field.tokens
  end
  function M.validateCheckpoint(b)
    local turn=b.field and b.field.tokens and b.field.tokens[M.owner]
    if turn==nil then return true end
    return type(turn)=='number' and turn%1==0 and turn>=1 and turn<=(b.turnCount or 0),
      'invalid_held_recovery_turn'
  end
  local statuses={PSN=true,PAR=true,FRZ=true,BRN=true,SLP=true}
  for id,row in pairs(definitions)do
    local source=assert(facts.item(id,2),'missing pinned Gen2 item '..id)
    assert(source.effect==row.effect,'unexpected pinned held effect '..id)
    if row.amount then assert(source.parameter==row.amount,'unexpected berry heal amount')end
    mod.content.items:register(id,{id=id,name=tr(row.en,row.de),
      names={en=row.en,de=row.de},price=source.cost or 0,
      keyItem=false,tossable=true,needsTarget=false,originGeneration=2,
      kascEquipmentOwner=M.owner,kascConsumableBerry67=id~='LEFTOVERS',
      kascEquipmentRewardEpochs={[2]=true,[3]=true,[4]=true,[5]=true,[6]=true,[7]=true}})
  end
  function M.supportsItem(game,id,epoch)
    local def=game and game.data and game.data.items and game.data.items[id]
    return definitions[id]~=nil and def and def.kascEquipmentOwner==M.owner
      and type(epoch)=='number' and epoch>=2 and epoch<=7 or false
  end
  local function activeEpoch(battle)
    local receipt=battle.kascGenerationRulesReceipt
    if receipt then return receipt.mode=='off' and 1 or tonumber(receipt.activeEpoch) or 1 end
    local game=battle.game
    local bucket=game and game.save and game.save.modData
    local state=bucket and bucket[mod.id] and bucket[mod.id][rules.SAVE_KEY]
    if state and state.activeMode=='off' then return 1 end
    return state and state.activeEpoch or 1
  end
  function M.apply(battle,onlyBattler)
    -- Gen2's native engine owns its own held effects. Never apply a second
    -- residual there or run them after an escape, catch, win, or loss.
    if not battle or battle.result or battle.demo or battle.kind=='link' or not battle.player
        or not battle.player.mon or not battle.enemy or not battle.enemy.mon then return 0 end
    local epoch=activeEpoch(battle)
    local changed=0
    for _,battler in ipairs({battle.player,battle.enemy})do
      local mon=battler.mon
      local id=held(mon,battle,battler)
      local spec=definitions[id]
      local maxHP=tonumber(mon.stats and mon.stats.hp or mon.maxHp or mon.maxHP)
      local hp=tonumber(mon.hp)
      if spec and hp and maxHP and hp>0 and (not onlyBattler or battler==onlyBattler)
          and (id=='LEFTOVERS' or not opts.abilities or not opts.abilities.blocksBerry(battle,battler))
          and M.supportsItem(battle.game,id,epoch) then
        local amount=0
        if hp<maxHP then
          if id=='LEFTOVERS' then amount=math.max(1,math.floor(maxHP/16))
          elseif spec.amount and hp*2<maxHP then amount=spec.amount end
          amount=math.min(amount,maxHP-hp)
        end
        local cured=false
        local block=mod.exports.pokemonHealBlock67
        if block and block.blocksRecovery(battle,battler,'item')then amount=0 end
        local restoredPP=false
        if spec.pp then
          -- HandleMysteryberry checks original party moves in slot order,
          -- not Transform's temporary copied moves. Native Gen2 restores
          -- five PP (one for Sketch), NOT modern Leppa Berry's ten.
          for slot=1,4 do
            local move=mon.moves and mon.moves[slot]
            if not move or not move.id then break end
            if move.pp==0 then
              local originalId=move.id
              for _,restore in ipairs(battle.mimicRestores or {})do
                if restore.battler==battler and restore.entry==move then
                  originalId=restore.id;break
                end
              end
              move.pp=originalId=='SKETCH' and 1 or 5
              restoredPP=true
              break
            end
          end
        end
        if mon.status and (spec.status==mon.status or spec.allStatus and statuses[mon.status]) then
          mon.status=nil
          battler.sleepTurns=nil
          battler.toxicCounter=nil
          if opts.abilities and opts.abilities.onStatusCured then opts.abilities.onStatusCured(battle,battler)end
          cured=true
        end
        if spec.confusion and type(battler.confusedTurns)=='number' and battler.confusedTurns>0 then
          battler.confusedTurns=nil
          cured=true
        end
        if amount>0 then
          mon.hp=hp+amount
        end
        if amount>0 or cured or restoredPP then
          if spec.amount or cured or restoredPP then
            mon.item=nil;mon.heldItem=nil
            if opts.abilities then opts.abilities.onBerry(battle,battler,id)end
          end
          local name=mon.nickname or battler.name or mon.species
          local message=restoredPP and tr('%s restored PP with %s!','%s erhält AP durch %s!')
            or cured and tr('%s recovered with %s!','%s erholt sich durch %s!')
            or tr('%s restored HP with %s!','%s erhält KP durch %s!')
          battle:sayNext(message:format(name,tr(spec.en,spec.de)))
          battle:drainNext()
          changed=changed+1
        end
      end
    end
    return changed
  end
  function M.residual(event)
    local battle=event and event.battle;local turn=event and tonumber(event.turn)
    if not battle or battle.result or battle.demo or battle.kind=='link'
        or not turn or turn<1 or turn%1~=0 or tokens(battle)[M.owner]==turn then return 0 end
    tokens(battle)[M.owner]=turn;return M.apply(battle)
  end
  mod.events:on('battle.turn_ended',M.residual)
  mod.events:on('battle.ended',function(event)
    local b=event and event.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.owner]=nil end
  end)
  return M
end
