-- Pinned source rows 539/540: scroll choice, not an arbitrary level branch.
-- Both bodies must already exist. No new sprites, forms, encounters or gifts.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-KUBFU',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local methods=mod.content.evolution_methods;local method='KA_WAVE1_KUBFU_SCROLL'
  local routes={{key='dex:892',item='SCROLL_OF_DARKNESS'},
    {key='form:10191',item='SCROLL_OF_WATERS'}}
  local defs,ids={},{}
  for _,row in ipairs({{'dex:891',891},{'dex:892',892},{'form:10191',892,10191}})do
    local key,dex,pid=row[1],row[2],row[3]
    local id=S.byKey[key];local def=id and registry:get(id)
    local expected=pid and 'KA_GIFT_FORM_'..pid or 'KA_GIFT_NAT_'..dex
    if not def or id~=expected or def.backendOwner~=S.OWNER or def.backendKey~=key
        or def.sourceDex~=dex or def.isMega or def.isGigantamax
        or (pid and (def.formId~='BACKEND_'..pid or def.baseSpecies~=S.byKey['dex:'..dex]))
        or (not pid and (def.formId or def.baseSpecies)) then
      C.pending[#C.pending+1]='identity:'..key
    end
    ids[key]=id;defs[key]=def
  end
  if defs['dex:891'] and #(defs['dex:891'].evolutions or {})>0 then
    C.pending[#C.pending+1]='existing_edges' end
  if methods:get(method) then C.pending[#C.pending+1]='method_owned' end
  for _,r in ipairs(routes)do
    if mod.content.items:get(r.item) then C.pending[#C.pending+1]='item_owned:'..r.item end
    if mod.content.item_effects:get(method..'_'..r.item) then
      C.pending[#C.pending+1]='effect_owned:'..r.item end
  end
  if #C.pending>0 then return C end
  local function exact(mon,evo)
    if type(mon)~='table' or mon.species~=ids['dex:891'] or mon.formId or mon.form
        or mon.baseSpecies or mon.isEgg or mon.egg or mon.eggSpecies
        or mon._ascMegaForm or mon.ascMegaForm or type(mon.hp)~='number'
        or not (mon.hp>0 and mon.hp<math.huge) or type(evo)~='table'
        or evo.method~=method or evo.level or evo.move or evo.partySpecies then return end
    for _,r in ipairs(routes)do
      if evo.species==ids[r.key] and evo.item==r.item then return r end
    end
  end
  methods:register(method,{consumesItem=true,
    check=function(_,mon,evo,trigger)
      local r=C.ready and exact(mon,evo)
      return r and trigger and trigger.kind=='item' and trigger.item==r.item or false
    end,
    describe=function(evo)
      return evo.item=='SCROLL_OF_WATERS' and opts.i18n.text('Scroll of Waters','Wasser-Schriftrolle')
        or opts.i18n.text('Scroll of Darkness','Unlicht-Schriftrolle')
    end})
  local edges={}
  for _,r in ipairs(routes)do
    local route=r
    local effect=method..'_'..route.item
    mod.content.item_effects:register(effect,{field=true,battle=false,needsTarget=true,
      use=function(ctx)
        if not ctx.battle and ctx.itemId==route.item and type(ctx.target)=='table'
            and ctx.target.species==ids['dex:891'] then
          local target=require('src.pokemon.Evolution').pendingFor(
            {data=ctx.data,save=ctx.save},ctx.target,{kind='item',item=ctx.itemId})
          if target==ids[route.key] then return 'consumed',nil,{evolveTo=target,evolveVia='ITEM'} end
        end
        return 'failed',{opts.i18n.text("It won't have\nany effect.",'Es hat keine\nWirkung.')}
      end})
    -- Source items have cost 0. 3000 is the explicit KASC optional-shop price,
    -- not a claim about original tower rewards or original currency.
    mod.content.items:register(route.item,{id=route.item,
      name=route.item=='SCROLL_OF_WATERS' and opts.i18n.text('SCROLL OF WATERS','WASSER-SCHRIFTROLLE')
        or opts.i18n.text('SCROLL OF DARKNESS','UNLICHT-SCHRIFTROLLE'),
      price=3000,needsTarget=true,battle=false,effect=effect})
    edges[#edges+1]={method=method,item=route.item,species=ids[route.key]}
  end
  registry:patch(ids['dex:891'],{evolutions=edges})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if C.ready and exact(mon,evo) and archive then
      local valid,_,p=archive.battleCompatibleGift(mon)
      if valid and p and p.backendKey=='dex:891' and p.species==ids['dex:891']
          and not p.formId and not p.baseSpecies and not p.megaFormId
          and not p.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  mod.events:on('pokemon.evolved',function(ev)
    if not ev or (ev.via~='ITEM' and ev.via~=method) or ev.fromSpecies~=ids['dex:891']
        or not ev.mon or ev.mon.species~=ev.toSpecies then return end
    for _,r in ipairs(routes)do if ev.toSpecies==ids[r.key] then
      local def=defs[r.key]
      ev.mon.formId=def.formId;ev.mon.form=def.formId;ev.mon.baseSpecies=def.baseSpecies
      return
    end end
  end,900)
  C.ready=true;C.routes=routes;return C
end
