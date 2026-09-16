-- Pinned source row 466: only Hisuian Sneasel, held Razor Claw, daytime
-- level-up. Preserve ordinary Sneasel's existing HEVO item adaptation.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-SNEASLER',ready=false,pending={}}
  local S=assert(opts.species);local reg=mod.content.pokemon
  local method='KA_WAVE1_SNEASLER_DAY';local item='RAZOR_CLAW'
  local from,to=S.byKey['form:10235'],S.byKey['dex:903']
  local parent,target=from and reg:get(from),to and reg:get(to)
  if from~='KA_GIFT_FORM_10235' or not parent or parent.backendOwner~=S.OWNER
      or parent.backendKey~='form:10235' or parent.sourceDex~=215
      or parent.formId~='BACKEND_10235' or not S.byKey['dex:215']
      or not reg:get(S.byKey['dex:215']) or parent.baseSpecies~=S.byKey['dex:215']
      or parent.isMega or parent.isGigantamax or parent.form then
    C.pending[#C.pending+1]='parent_identity'
  end
  if to~='KA_GIFT_NAT_903' or not target or target.backendOwner~=S.OWNER
      or target.backendKey~='dex:903' or target.sourceDex~=903 or target.formId
      or target.baseSpecies or target.form or target.isMega or target.isGigantamax then
    C.pending[#C.pending+1]='target_identity'
  end
  if parent and #(parent.evolutions or {})>0 then C.pending[#C.pending+1]='existing_edges'end
  local claw=mod.content.items:get(item)
  if not claw or claw.effect~='KA_HEVO_PACKAGE_ITEM' or claw.price~=0
      or claw.needsTarget~=true then C.pending[#C.pending+1]='item_owner'end
  if mod.content.evolution_methods:get(method) then C.pending[#C.pending+1]='method_owner'end
  if type(opts.timeMode)~='function' then C.pending[#C.pending+1]='clock_owner'end
  if #C.pending>0 then return C end
  local function healthy(mon)
    return type(mon)=='table' and mon.species==from
      and mon.formId==parent.formId and mon.baseSpecies==parent.baseSpecies
      and (not mon.form or mon.form==parent.formId)
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and not mon._ascMegaForm and not mon.ascMegaForm
      and not mon.cosmeticForm and not mon.cosmeticFormId
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
  end
  local function exact(mon,evo)
    return healthy(mon) and type(evo)=='table' and evo.method==method
      and evo.species==to and not evo.item and not evo.level
      and not evo.move and not evo.partySpecies
  end
  local function entitled(mon)
    local archive=mod.exports and mod.exports.eventArchive
    if not archive or not healthy(mon) then return false end
    local valid,_,p=archive.battleCompatibleGift(mon)
    return valid and p and p.backendKey=='form:10235' and p.species==from
      and p.formId==parent.formId and p.baseSpecies==parent.baseSpecies
      and not p.megaFormId and not p.gigantamaxFormId or false
  end
  local function held(mon)
    local eq=mod.exports and mod.exports.pokemonEquipment67
    return eq and eq.heldId(mon)
  end
  mod.content.evolution_methods:register(method,{
    check=function(game,mon,evo,trigger)
      return C.ready and exact(mon,evo) and trigger and trigger.kind=='levelup'
        and held(mon)==item and opts.timeMode(game)=='day' or false
    end,
    describe=function()return opts.i18n.text('Level up by day holding a Razor Claw',
      'Tagsüber mit getragener Scharfklaue aufleveln')end,
  })
  reg:patch(from,{evolutions={{method=method,species=to}}})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    if C.ready and exact(mon,evo) and entitled(mon) then return true end
    return previous and previous(game,mon,evo) or false
  end
  -- A canceled film emits no evolution event and must not spend the held unit.
  -- Never remove another unit from the Bag or reassign the immutable birth key.
  mod.events:on('pokemon.evolved',function(ev)
    if ev and ev.via==method and ev.fromSpecies==from and ev.toSpecies==to
        and ev.mon and ev.mon.species==to then
      if held(ev.mon)==item then ev.mon.item=nil;ev.mon.heldItem=nil end
      ev.mon.formId=nil;ev.mon.form=nil;ev.mon.baseSpecies=nil
    end
  end,900)
  function C.item(id)
    if C.ready and id==item then return {id=id,generation=4,sourceItem=303,
      names={en='RAZOR CLAW',de='SCHARFKLAUE'},flags={'holdable'}}end
  end
  function C.offer(game,mon)
    if not C.ready or not entitled(mon) then return end
    for _,member in ipairs(game and game.save and game.save.party or {})do
      if member==mon then return {id=item,price=5000,
        name=opts.i18n.text('RAZOR CLAW','SCHARFKLAUE'),
        help=opts.i18n.text('Give it through Equipment. Hisuian Sneasel evolves on a daytime level-up. Consumed only after evolution.',
          'Über Ausrüstung tragen lassen. Hisui-Sniebel entwickelt sich beim Levelaufstieg am Tag. Verbrauch erst nach Entwicklung.')}end
    end
  end
  C.ready=true;return C
end
