-- KASC-67-MODERN-BERRIES. Separate identities; never rename Gen2 berries.
return function(mod,opts)
  local M={CARD_ID='KASC-67-MODERN-BERRIES',owner='kasc.modern-berry-effects/v1'}
  local spec={ORAN_BERRY={hp=10},SITRUS_BERRY={hp=30},
    CHERI_BERRY={status='PAR'},CHESTO_BERRY={status='SLP'},
    PECHA_BERRY={status='PSN'},RAWST_BERRY={status='BRN'},
    ASPEAR_BERRY={status='FRZ'},PERSIM_BERRY={confusion=true},
    LUM_BERRY={all=true,confusion=true},LEPPA_BERRY={pp=10}}
  if opts.split then
    for id,stat in pairs({LIECHI_BERRY='attack',GANLON_BERRY='defense',SALAC_BERRY='speed',
        PETAYA_BERRY='specialAttack',APICOT_BERRY='specialDefense'})do spec[id]={stat=stat}end
  end
  local major={PSN=true,BRN=true,FRZ=true,SLP=true,PAR=true}
  local function tokens(b)
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    return b.field.tokens
  end
  function M.validateCheckpoint(b)
    local turn=b.field and b.field.tokens and b.field.tokens[M.owner]
    if turn==nil then return true end
    return type(turn)=='number' and turn%1==0 and turn>=1 and turn<=(b.turnCount or 0),
      'invalid_modern_berry_turn'
  end
  for id,row in pairs(spec)do
    local source=assert(opts.facts.item(id,3),'missing berry '..id)
    row.names=source.names or {en=id,de=id}
    mod.content.items:register(id,{id=id,name=opts.i18n.text(row.names.en,row.names.de),
      names=row.names,originGeneration=3,keyItem=false,tossable=true,kascConsumableBerry67=true,
      price=source.cost or 0,kascModernBerryOwner=M.owner,
      kascEquipmentRewardEpochs={[3]=true,[4]=true,[5]=true,[6]=true,[7]=true}})
  end
  function M.supportsItem(game,id,epoch)
    local def=game and game.data and game.data.items and game.data.items[id]
    return spec[id]~=nil and def and def.kascModernBerryOwner==M.owner
      and type(epoch)=='number' and epoch>=3 and epoch<=7 or false
  end
  local function epoch(b)
    local receipt=b and b.kascGenerationRulesReceipt
    if receipt then return receipt.mode=='off' and 1 or tonumber(receipt.activeEpoch) or 1 end
    local md=b and b.game and b.game.save and b.game.save.modData
    local state=md and md[mod.id] and md[mod.id][opts.rules.SAVE_KEY]
    if state and state.activeMode=='off' then return 1 end
    return state and state.activeEpoch or 1
  end
  function M.apply(b,afterAction,onlyBattler,hpOnly)
    if not b or b.result or b.demo or b.kind=='link' or not b.player
        or not b.player.mon or not b.enemy or not b.enemy.mon then return 0 end
    local gen=epoch(b);local changed=0
    for _,who in ipairs({b.player,b.enemy})do
      local mon=who.mon;local id=opts.held(mon,b,who);local row=spec[id]
      if row and (not onlyBattler or onlyBattler==who) and (not hpOnly or row.hp)
          and (mon.hp or 0)>0 and M.supportsItem(b.game,id,gen)
          and (not opts.abilities or not opts.abilities.blocksBerry(b,who)) then
        local consumed=false
        local maxHP=mon.stats and mon.stats.hp
        local ability=opts.abilities and opts.abilities.activeAbility(b,who)
        local oldStage=row.stat and (who.stages[row.stat]or 0)
        local delta=row.stat and opts.abilities and opts.abilities.stageDelta(b,who,1)or 1
        if row.stat and maxHP and (not afterAction or gen>=4)
            and mon.hp*(ability=='GLUTTONY' and 2 or 4)<=maxHP
            and math.max(-6,math.min(6,oldStage+delta))~=oldStage then
          local ctx={battle=b,user=who,target=who,changeStage=function(w,s,d,f)
            return require('src.battle.MoveEffects').changeStage(b,w,s,d,f)end}
          for _,message in ipairs(opts.split.changeStage(ctx,who,row.stat,1,false))do b:sayNext(message)end
          consumed=true
        end
        -- Emerald's HP/AP berries run at normal residual, status berries
        -- also at move end. Gen4+ HP recovery also checks after actions.
        if row.hp and maxHP and (not afterAction or gen>=4)
            and mon.hp<maxHP and mon.hp*2<=maxHP
            and not(mod.exports.pokemonHealBlock67 and mod.exports.pokemonHealBlock67.blocksRecovery(b,who,'item'))then
          local heal=id=='SITRUS_BERRY' and gen>=4
            and math.max(1,math.floor(maxHP/4)) or row.hp
          mon.hp=math.min(maxHP,mon.hp+heal);consumed=true
        end
        if row.pp and not afterAction then
          for _,slot in ipairs(mon.moves or {})do
            if slot.pp==0 then
              local originalId=slot.id
              for _,restore in ipairs(b.mimicRestores or {})do
                if restore.battler==who and restore.entry==slot then originalId=restore.id;break end
              end
              local def=b.data and b.data.moves and b.data.moves[originalId]
              if def and (def.pp or 0)>0 then
                local maxPP=def.pp+math.min(3,math.max(0,slot.ppUps or 0))*math.floor(def.pp/5)
                slot.pp=math.min(row.pp,maxPP);consumed=true
              end
              break
            end
          end
        end
        if mon.status and (row.status==mon.status or row.all and major[mon.status]) then
          mon.status=nil;who.sleepTurns=nil;who.toxicCounter=nil;who.nightmare=nil
          if opts.abilities then opts.abilities.onStatusCured(b,who)end
          consumed=true
        end
        if row.confusion and (who.confusedTurns or 0)>0 then
          who.confusedTurns=nil;consumed=true
        end
        if consumed then
          mon.item=nil;mon.heldItem=nil;changed=changed+1
          if opts.abilities then opts.abilities.onBerry(b,who,id)end
          local name=mon.nickname or who.name or mon.species
          b:sayNext(opts.i18n.text(row.stat and '%s uses %s!' or '%s recovered with %s!',
            row.stat and '%s nutzt %s!' or '%s erholt sich durch %s!')
            :format(name,opts.i18n.text(row.names.en,row.names.de)))
          b:drainNext()
        end
      end
    end
    return changed
  end
  function M.residual(event)
    local b=event and event.battle;local turn=event and event.turn
    if not b or b.result or b.demo or b.kind=='link' or not b.player
        or not b.player.mon or not b.enemy or not b.enemy.mon
        or type(turn)~='number' or turn<1 or turn%1~=0
        or tokens(b)[M.owner]==turn then return 0 end
    tokens(b)[M.owner]=turn;return M.apply(b,false)
  end
  function M.install(Battle)
    Battle._kascModernBerryOwner67=M
    if Battle._kascModernBerryWrapped67 then return end
    Battle._kascModernBerryWrapped67=true
    local old=Battle.executeAction
    Battle.executeAction=function(b,...)
      local result=old(b,...)
      -- Append after the move's queued effects, before the next action.
      -- Nested move/hit actions insert ahead of this checkpoint naturally.
      b:actNext(function()
        local owner=Battle._kascModernBerryOwner67
        if owner then owner.apply(b,true) end
      end)
      return result
    end
  end
  mod.events:on('battle.turn_ended',M.residual)
  mod.events:on('battle.ended',function(event)
    local b=event and event.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.owner]=nil end
  end)
  M.install(opts.battleState or require('src.battle.BattleState'))
  if opts.abilities then mod.content.move_effects:patch('HEAL_EFFECT',{
    kascUnnerve67=opts.abilities.owner,kascBerryAbility67=opts.split and opts.abilities.owner or nil})end
  return M
end
