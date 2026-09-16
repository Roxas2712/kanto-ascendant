-- Explicit KASC solo adaptation of trade routes. The two perfume routes
-- still require and consume their held item. Partner trades stay separate.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-LINKING-CORD',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local method,item,effect='KA_WAVE1_LINKING_CORD','LINKING_CORD','KA_WAVE1_LINKING_CORD_EFFECT'
  local routes={
    {sourceRow=265,from=525,to=526,birth=524,birthLevel=25},
    {sourceRow=269,from=533,to=534,birth=532,birthLevel=25},
    {sourceRow=329,from=708,to=709},
    {sourceRow=344,from=710,to=711},
    {sourceRow=554,from=710,to=711,fromForm=10027,toForm=10030},
    {sourceRow=555,from=710,to=711,fromForm=10028,toForm=10031},
    {sourceRow=556,from=710,to=711,fromForm=10029,toForm=10032},
    {sourceRow=327,from=682,to=683,heldItem='SACHET',sourceItem=687,
      heldEn='SACHET',heldDe='DUFTBEUTEL'},
    {sourceRow=350,from=684,to=685,heldItem='WHIPPED_DREAM',sourceItem=686,
      heldEn='WHIPPED DREAM',heldDe='SAHNEHÄUBCHEN'},
  }
  local function identity(dex,pid)
    local key=pid and 'form:'..pid or 'dex:'..dex
    local id=S.byKey[key];local def=id and registry:get(id)
    if not def or id~=(pid and 'KA_GIFT_FORM_'..pid or 'KA_GIFT_NAT_'..dex)
        or def.backendOwner~=S.OWNER or def.backendKey~=key or def.sourceDex~=dex
        or def.isMega or def.isGigantamax or def.form
        or (pid and (def.formId~='BACKEND_'..pid or def.baseSpecies~=S.byKey['dex:'..dex]))
        or (not pid and (def.formId or def.baseSpecies)) then
      C.pending[#C.pending+1]='body:'..key
    end
    return id,def,key
  end
  for _,r in ipairs(routes)do
    r.parent,r.parentDef,r.fromKey=identity(r.from,r.fromForm)
    r.target,r.targetDef,r.toKey=identity(r.to,r.toForm)
    if r.parentDef and #(r.parentDef.evolutions or {})>0 then
      C.pending[#C.pending+1]='existing_edges:'..r.fromKey end
    if r.heldItem and mod.content.items:get(r.heldItem) then
      C.pending[#C.pending+1]='held_item_owned:'..r.heldItem end
    if r.birth then
      local birth,def,key=identity(r.birth)
      r.birthId,r.birthKey=birth,key
      local found=0
      for _,e in ipairs(def and def.evolutions or {})do
        if e.species==r.parent and e.method=='KA_BACKEND_LEVEL' and e.level==r.birthLevel
            and not e.item then found=found+1 end
      end
      if found~=1 then C.pending[#C.pending+1]='birth_chain:'..key end
    end
  end
  if mod.content.evolution_methods:get(method) or mod.content.items:get(item)
      or mod.content.item_effects:get(effect) then C.pending[#C.pending+1]='existing_owner'end
  if #C.pending>0 then return C end
  local function held(mon)
    local equipment=mod.exports and mod.exports.pokemonEquipment67
    return equipment and equipment.heldId(mon)
  end
  local function exact(mon,evo,previewHeld)
    if type(mon)~='table' or mon.isEgg or mon.egg or mon.eggSpecies
        or mon._ascMegaForm or mon.ascMegaForm or mon.cosmeticForm or mon.cosmeticFormId
        or type(mon.hp)~='number' or not(mon.hp>0 and mon.hp<math.huge)
        or type(evo)~='table' or evo.method~=method or evo.item~=item
        or evo.level or evo.move or evo.partySpecies then return end
    for _,r in ipairs(routes)do
      if mon.species==r.parent and evo.species==r.target
          and mon.formId==r.parentDef.formId and mon.baseSpecies==r.parentDef.baseSpecies
          and (not mon.form or mon.form==r.parentDef.formId)
          and (not r.heldItem or previewHeld or held(mon)==r.heldItem) then return r end
    end
  end
  mod.content.evolution_methods:register(method,{consumesItem=true,
    check=function(_,mon,evo,trigger)
      return C.ready and exact(mon,evo)~=nil and trigger and trigger.kind=='item'
        and trigger.item==item or false
    end,
    describe=function()return opts.i18n.text('Linking Cord (solo trade)','Verbindungsschnur (Solo-Tausch)')end})
  for _,r in ipairs(routes)do
    registry:patch(r.parent,{evolutions={{method=method,item=item,species=r.target}}})
    if r.heldItem then
      mod.content.items:register(r.heldItem,{id=r.heldItem,
        name=opts.i18n.text(r.heldEn,r.heldDe),price=2000,battle=false,needsTarget=true})
    end
  end
  mod.content.item_effects:register(effect,{field=true,battle=false,needsTarget=true,
    use=function(ctx)
      if not ctx.battle and ctx.itemId==item and type(ctx.target)=='table' then
        local target=require('src.pokemon.Evolution').pendingFor(
          {data=ctx.data,save=ctx.save},ctx.target,{kind='item',item=item})
        for _,r in ipairs(routes)do
          if ctx.target.species==r.parent and target==r.target then
            return 'consumed',nil,{evolveTo=target,evolveVia='ITEM'}
          end
        end
      end
      return 'failed',{opts.i18n.text("It won't have\nany effect.",'Es hat keine\nWirkung.')}
    end})
  mod.content.items:register(item,{id=item,name=opts.i18n.text('LINKING CORD','VERBINDUNGSSCHNUR'),
    price=8000,needsTarget=true,battle=false,effect=effect})
  local previous=S.giftEvolutionAllowed
  local function entitled(r,mon)
    local archive=mod.exports and mod.exports.eventArchive
    if not archive then return false end
    local valid,_,p=archive.battleCompatibleGift(mon)
    if not valid or not p or p.megaFormId or p.gigantamaxFormId then return false end
    if p.backendKey==r.fromKey and p.species==r.parent
        and p.formId==r.parentDef.formId and p.baseSpecies==r.parentDef.baseSpecies then return true end
    return r.birthId and p.backendKey==r.birthKey and p.species==r.birthId
      and not p.formId and not p.baseSpecies or false
  end
  S.giftEvolutionAllowed=function(game,mon,evo)
    local r=C.ready and exact(mon,evo)
    if r and entitled(r,mon) then return true end
    return previous and previous(game,mon,evo) or false
  end
  mod.events:on('pokemon.evolved',function(ev)
    if not ev or (ev.via~=method and ev.via~='ITEM') or not ev.mon
        or ev.mon.species~=ev.toSpecies then return end
    for _,r in ipairs(routes)do
      if ev.fromSpecies==r.parent and ev.toSpecies==r.target then
        if r.heldItem and held(ev.mon)==r.heldItem then
          ev.mon.item=nil;ev.mon.heldItem=nil
        end
        ev.mon.formId=r.targetDef.formId;ev.mon.form=r.targetDef.formId
        ev.mon.baseSpecies=r.targetDef.baseSpecies;return
      end
    end
  end,900)
  function C.item(id)
    if not C.ready then return end
    for _,r in ipairs(routes)do if r.heldItem==id then
      return {id=id,generation=6,sourceItem=r.sourceItem,
        names={en=r.heldEn,de=r.heldDe},flags={'holdable'}}
    end end
  end
  function C.heldOffer(game,mon)
    if not C.ready then return end
    for _,r in ipairs(routes)do
      if r.heldItem and exact(mon,{method=method,item=item,species=r.target},true)==r
          and entitled(r,mon) then
        for _,member in ipairs(game and game.save and game.save.party or {})do
          if member==mon then return {id=r.heldItem,price=2000,
            name=opts.i18n.text(r.heldEn,r.heldDe),
            help=opts.i18n.text('Give it to this Pokémon, then use a Linking Cord. Both consumed on evolution. No battle bonus.',
              'Diesem Pokémon geben, dann Verbindungsschnur anwenden. Beides wird bei der Entwicklung verbraucht. Kein Kampfbonus.')}end
        end
      end
    end
  end
  C.effectUse=mod.content.item_effects:get(effect).use
  C.ready=true;C.routes=routes;return C
end
