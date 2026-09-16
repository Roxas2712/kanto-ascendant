-- Available default bodies only: Phony Sinistea and Counterfeit Poltchageist.
-- Cosmetic antique/artisan forms have no registered body here. Do not turn
-- their separate source item rows into a second interchangeable recipe.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-TEA',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local method='KA_WAVE1_TEA_ITEM'
  local routes={
    {from=854,to=855,item='CRACKED_POT',price=1600,en='CRACKED POT',de='RISSIGE KANNE'},
    {from=1012,to=1013,item='UNREMARKABLE_TEACUP',price=400,en='UNREMARKABLE TEACUP',de='SIMPLE TEESCHALE'},
  }
  for _,r in ipairs(routes)do
    for _,dex in ipairs({r.from,r.to})do
      local id=S.byKey['dex:'..dex];local def=id and registry:get(id)
      if id~='KA_GIFT_NAT_'..dex or not def or def.backendOwner~=S.OWNER
          or def.backendKey~='dex:'..dex or def.sourceDex~=dex or def.formId
          or def.form or def.baseSpecies or def.isMega or def.isGigantamax then
        C.pending[#C.pending+1]='body:'..dex
      end
    end
    r.parent=S.byKey['dex:'..r.from];r.target=S.byKey['dex:'..r.to]
    local p=r.parent and registry:get(r.parent)
    if p and #(p.evolutions or {})>0 then C.pending[#C.pending+1]='existing_edges:'..r.from end
    if mod.content.items:get(r.item) or mod.content.item_effects:get(method..'_'..r.item) then
      C.pending[#C.pending+1]='item_owner:'..r.item end
  end
  if mod.content.evolution_methods:get(method) then C.pending[#C.pending+1]='method_owned'end
  if #C.pending>0 then return C end
  local function exact(mon,evo)
    if type(mon)~='table' or mon.formId or mon.form or mon.baseSpecies
        or mon.cosmeticForm or mon.cosmeticFormId or mon.authentic or mon.antique
        or mon.isEgg or mon.egg or mon.eggSpecies or mon._ascMegaForm or mon.ascMegaForm
        or type(mon.hp)~='number' or not(mon.hp>0 and mon.hp<math.huge)
        or type(evo)~='table' or evo.method~=method or evo.level or evo.move
        or evo.partySpecies then return end
    for _,r in ipairs(routes)do
      if mon.species==r.parent and evo.species==r.target and evo.item==r.item then return r end
    end
  end
  mod.content.evolution_methods:register(method,{consumesItem=true,
    check=function(_,mon,evo,trigger)
      local r=C.ready and exact(mon,evo)
      return r and trigger and trigger.kind=='item' and trigger.item==r.item or false
    end,
    describe=function(evo)
      for _,r in ipairs(routes)do if evo.item==r.item then return opts.i18n.text(r.en,r.de)end end
    end})
  for _,r in ipairs(routes)do
    local row=r;local effect=method..'_'..r.item
    mod.content.item_effects:register(effect,{field=true,battle=false,needsTarget=true,
      use=function(ctx)
        if not ctx.battle and ctx.itemId==row.item and type(ctx.target)=='table'
            and ctx.target.species==row.parent then
          local target=require('src.pokemon.Evolution').pendingFor(
            {data=ctx.data,save=ctx.save},ctx.target,{kind='item',item=ctx.itemId})
          if target==row.target then return 'consumed',nil,{evolveTo=target,evolveVia='ITEM'}end
        end
        return 'failed',{opts.i18n.text("It won't have\nany effect.",'Es hat keine\nWirkung.')}
      end})
    mod.content.items:register(r.item,{id=r.item,name=opts.i18n.text(r.en,r.de),
      price=r.price,needsTarget=true,battle=false,effect=effect})
    registry:patch(r.parent,{evolutions={{method=method,item=r.item,species=r.target}}})
  end
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local r=C.ready and exact(mon,evo);local archive=mod.exports and mod.exports.eventArchive
    if r and archive then
      local valid,_,p=archive.battleCompatibleGift(mon)
      if valid and p and p.backendKey=='dex:'..r.from and p.species==r.parent
          and not p.formId and not p.baseSpecies and not p.megaFormId
          and not p.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  C.ready=true;C.routes=routes;return C
end
