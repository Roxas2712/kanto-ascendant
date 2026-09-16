-- Source evolution row 515: Hisui Qwilfish, level-up knowing Barb Barrage.
-- This is the source's modern known-move route, not a Strong Style counter.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-OVERQWIL',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local methods=mod.content.evolution_methods;local method='KA_WAVE1_OVERQWIL_KNOWLEDGE'
  local parent=S.byKey['form:10234'];local target=S.byKey['dex:904']
  local base=S.byKey['dex:211'];local p=parent and registry:get(parent);local t=target and registry:get(target)
  if not p or parent~='KA_GIFT_FORM_10234' or p.backendOwner~=S.OWNER
      or p.backendKey~='form:10234' or p.sourceDex~=211 or p.formId~='BACKEND_10234'
      or base~='QWILFISH' or not registry:get(base) or p.baseSpecies~=base
      or p.isMega or p.isGigantamax then C.pending[#C.pending+1]='parent_identity' end
  if not t or target~='KA_GIFT_NAT_904' or t.backendOwner~=S.OWNER
      or t.backendKey~='dex:904' or t.sourceDex~=904 or t.formId or t.form
      or t.baseSpecies or t.isMega or t.isGigantamax then C.pending[#C.pending+1]='target_identity' end
  if p and #(p.evolutions or {})>0 then C.pending[#C.pending+1]='existing_edges' end
  local move=type(S.moveId)=='function' and S.moveId('BARB_BARRAGE')
  if not move or not mod.content.moves:get(move) then C.pending[#C.pending+1]='move_unavailable' end
  if methods:get(method) then C.pending[#C.pending+1]='method_owned' end
  if #C.pending>0 then return C end
  local function exact(mon,evo)
    return type(mon)=='table' and mon.species==parent and mon.formId==p.formId
      and mon.baseSpecies==p.baseSpecies and (not mon.form or mon.form==p.formId)
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and not mon._ascMegaForm and not mon.ascMegaForm
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and type(evo)=='table' and evo.species==target and evo.method==method
      and not evo.level and not evo.item and not evo.move and not evo.partySpecies
  end
  methods:register(method,{
    check=function(_,mon,evo,trigger)
      if not (C.ready and exact(mon,evo) and trigger and trigger.kind=='levelup'
          and type(mon.level)=='number' and mon.level==math.floor(mon.level)
          and mon.level>=1 and mon.level<=100) then return false end
      for _,known in ipairs(type(mon.moves)=='table' and mon.moves or {})do
        if type(known)=='table' and known.id==move then return true end
      end
      return false
    end,
    describe=function()return opts.i18n.text('Level up knowing Barb Barrage',
      'Levelaufstieg mit Giftstachelregen')end,
  })
  registry:patch(parent,{evolutions={{method=method,species=target}}})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if C.ready and exact(mon,evo) and archive then
      local valid,_,profile=archive.battleCompatibleGift(mon)
      if valid and profile and profile.backendKey=='form:10234' and profile.species==parent
          and profile.formId==p.formId and profile.baseSpecies==p.baseSpecies
          and not profile.megaFormId and not profile.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  mod.events:on('pokemon.evolved',function(ev)
    if ev and ev.via==method and ev.fromSpecies==parent and ev.toSpecies==target
        and ev.mon and ev.mon.species==target then
      ev.mon.formId=nil;ev.mon.form=nil;ev.mon.baseSpecies=nil
    end
  end,900)
  C.ready=true;C.move=move;return C
end
