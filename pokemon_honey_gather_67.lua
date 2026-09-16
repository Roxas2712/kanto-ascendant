-- KASC-67-HONEY-GATHER. A field ability reads the saved party, not a
-- temporary Transform/Mummy/Trace battle ability. Native afterBattle owns
-- the subsequent save, just as it owns captured Pokemon and spent items.
return function(mod,opts)
  local Battle=require('src.battle.BattleState')
  local M={CARD_ID='KASC-67-HONEY-GATHER',OWNER='kasc.honey-gather/v1'}
  local finished=setmetatable({},{__mode='k'})
  local honey={id='HONEY',names={en='Honey',de='Honig'},generation=4,
    cost=900,flags={'holdable'}}
  function M.itemMetadata(id)
    if id~='HONEY'then return end
    return {id=id,names={en=honey.names.en,de=honey.names.de},generation=4,
      cost=honey.cost,flags={'holdable'},noHeldEffect=true}
  end
  function M.chance(level)
    if type(level)~='number'or level%1~=0 or level<1 then return 0 end
    return 5*(math.min(9,math.floor((level-1)/10))+1)
  end
  function M.finish(ev)
    local b=ev and ev.battle
    if getmetatable(b)~=Battle or finished[b] or ev.skipped or b.demo
        or (b.kind~='wild'and b.kind~='trainer') or b.result~='win'
        or ev.result~='win' or not b.game or not b.game.save then return 0 end
    local gen=opts.status.epoch(b)
    if not gen or gen<4 or gen>7 or not b.data.items.HONEY then return 0 end
    -- Seal before RNG or callbacks: the same battle-end notification must
    -- never reroll an empty-handed member or award another item after Take.
    finished[b]=true
    local found,seen=0,{}
    for index,mon in ipairs(b.game.save.party or{})do
      if index>6 then break end
      if type(mon)=='table'and not seen[mon]then
        seen[mon]=true
        local held,err=opts.held(mon)
        local ability=opts.binding.view(b.game,mon,gen)
        local chance=M.chance(mon.level)
        if not mon.isEgg and not mon.egg and not mon.eggSpecies and mon.species~='EGG'
            and not held and not err and chance>0
            and ability.active and ability.id=='HONEY_GATHER'
            and b.rng(0,99)<chance then
          -- Fainted and non-participating members remain eligible. Do not
          -- change their binding, wild-item receipt, HP, bag or quest flags.
          mon.item='HONEY';mon.heldItem='HONEY';found=found+1
        end
      end
    end
    return found
  end
  if not mod.content.items:get('HONEY')then
    mod.content.items:register('HONEY',{id='HONEY',
      name=opts.i18n.text(honey.names.en,honey.names.de),names=honey.names,
      price=honey.cost,keyItem=false,tossable=true,needsTarget=false,
      originGeneration=4,kascEquipmentCatalog=true})
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHoneyGather67=M.OWNER})
  -- After item-loan restoration, before deferred generation-mode changes
  -- and native overworld saving. No message is queued on the closed battle UI.
  mod.events:on('battle.ended',M.finish,-9000)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-party-equipment-and-generation-receipt',
      providerStatus='honey-gather-iv-vii',buildReceiptId='docs/HONEY_GATHER_67.md',
      rollbackReceiptId='docs/HONEY_GATHER_67.md'})
  end
  return M
end
