-- Source rows 403/404: Cosmoem -> Solgaleo/Lunala at level 53.
-- Explicit KASC single-edition adaptation: the existing world clock replaces
-- the Sun/Moon edition choice. No new edition, item, Dex unlock or auto gift.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-COSMOEM',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local method='KA_WAVE1_COSMIC_LIGHT'
  local ids,defs={},{}
  for _,dex in ipairs({789,790,791,792})do
    local key='dex:'..dex;local id=S.byKey[key];local def=id and registry:get(id)
    ids[dex],defs[dex]=id,def
    if id~='KA_GIFT_NAT_'..dex or not def or def.backendOwner~=S.OWNER
        or def.backendKey~=key or def.sourceDex~=dex or def.formId or def.form
        or def.baseSpecies or def.isMega or def.isGigantamax then
      C.pending[#C.pending+1]='identity:'..key
    end
  end
  local birth=defs[789] and defs[789].evolutions or {}
  if #birth~=1 or birth[1].method~='KA_BACKEND_LEVEL' or birth[1].level~=43
      or birth[1].species~=ids[790] or birth[1].item then
    C.pending[#C.pending+1]='cosmog_chain'
  end
  if defs[790] and #(defs[790].evolutions or {})~=0 then C.pending[#C.pending+1]='existing_edges'end
  if mod.content.evolution_methods:get(method) then C.pending[#C.pending+1]='method_owned'end
  if type(opts.timeMode)~='function' then C.pending[#C.pending+1]='clock_missing'end
  if #C.pending>0 then return C end
  local phases={[ids[791]]='day',[ids[792]]='night'}
  local function exact(mon,evo)
    return type(mon)=='table' and mon.species==ids[790] and not mon.formId
      and not mon.form and not mon.baseSpecies and not mon.cosmeticForm and not mon.cosmeticFormId
      and not mon._ascMegaForm and not mon.ascMegaForm
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and type(mon.level)=='number' and mon.level==math.floor(mon.level)
      and mon.level>=53 and mon.level<=100
      and type(evo)=='table' and evo.method==method and phases[evo.species]~=nil
      and evo.level==53 and not evo.item and not evo.move and not evo.partySpecies
  end
  mod.content.evolution_methods:register(method,{
    check=function(game,mon,evo,trigger)
      return C.ready and exact(mon,evo) and trigger and trigger.kind=='levelup'
        and opts.timeMode(game)==phases[evo.species] or false
    end,
    describe=function(evo)
      return phases[evo.species]=='day'
        and opts.i18n.text('KASC: level 53 by day','KASC: Level 53 bei Tag')
        or opts.i18n.text('KASC: level 53 at night','KASC: Level 53 bei Nacht')
    end,
  })
  registry:patch(ids[790],{evolutions={
    {method=method,level=53,species=ids[791]},
    {method=method,level=53,species=ids[792]},
  }})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if C.ready and exact(mon,evo) and archive then
      local valid,_,p=archive.battleCompatibleGift(mon)
      if valid and p and not p.formId and not p.baseSpecies
          and not p.megaFormId and not p.gigantamaxFormId then
        for _,dex in ipairs({789,790})do
          if p.backendKey=='dex:'..dex and p.species==ids[dex] then return true end
        end
      end
    end
    return previous and previous(game,mon,evo) or false
  end
  C.ready=true;C.method=method;C.ids=ids;return C
end
