-- Existing permanent Alola bodies only. No assets or cross-region routes.
return function(mod,opts)
  local C={CARD_ID='KASC-67-ALOLA-EVOLUTIONS',ready=false,pending={},routes={}}
  local A,S,R=assert(opts.alola),assert(opts.species),assert(opts.rules)
  local registry,methods=mod.content.pokemon,mod.content.evolution_methods
  local defs={};local method='KA_ALOLA_EVOLUTION_67'
  local sources={
    {'RATTATA_ALOLA','RATICATE_ALOLA','level',20,'night',sourceRow=461},
    {'SANDSHREW_ALOLA','SANDSLASH_ALOLA','item','ICE_STONE',sourceRow=448},
    {'VULPIX_ALOLA','NINETALES_ALOLA','item','ICE_STONE',sourceRow=449},
    {'DIGLETT_ALOLA','DUGTRIO_ALOLA','level',26,sourceRow=518},
    {'MEOWTH_ALOLA','PERSIAN_ALOLA','friendship',220,sourceRow=450},
    {'GEODUDE_ALOLA','GRAVELER_ALOLA','level',25,sourceRow=519},
    {'GRAVELER_ALOLA','GOLEM_ALOLA','trade',sourceRow=520},
    {'GRIMER_ALOLA','MUK_ALOLA','level',38,sourceRow=521},
  }
  -- Authoritative registrar identities must already exist. Validate the
  -- whole batch before adding any row; never overwrite another graph.
  for _,id in ipairs(A.order or {})do
    local row=A.bySpecies[id];local def=registry:get(id)
    if not row or not def or def.formId~='ALOLA' or def.regionalForm~='ALOLA'
        or def.baseSpecies~=row.baseSpecies or def.sourceDex~=row.sourceDex
        or def.originGeneration~=7 or def.isMega or def.isGigantamax
        or #(def.evolutions or {})~=0 then
      C.pending[#C.pending+1]='regional_identity_or_graph:'..id
    end
    defs[id]=def
  end
  if #(A.order or {})~=18 then C.pending[#C.pending+1]='regional_catalogue_size' end
  if methods:get(method) then C.pending[#C.pending+1]='method_owned' end
  if type(opts.timeMode)~='function' then C.pending[#C.pending+1]='clock_missing' end
  if not opts.friendship or type(opts.friendship.walkFriendshipEligible)~='function' then
    C.pending[#C.pending+1]='walking_bond_owner_missing'
  end
  local oldEffects={}
  for _,id in ipairs({'ICE_STONE','LINKING_CORD'})do
    local item=mod.content.items:get(id)
    local effect=item and mod.content.item_effects:get(item.effect)
    if not item or item.needsTarget~=true or item.battle~=false
        or not effect or type(effect.use)~='function' then
      C.pending[#C.pending+1]='item_owner_missing:'..id
    else oldEffects[id]={id=item.effect,use=effect.use} end
  end
  for _,source in ipairs(sources)do
    if not defs[source[1]] or not defs[source[2]] then
      C.pending[#C.pending+1]='family_missing:'..source[1] end
  end
  if #C.pending>0 then return C end
  local function healthy(mon)
    return type(mon)=='table' and getmetatable(mon)==nil
      and defs[mon.species] and mon.formId=='ALOLA'
      and mon.baseSpecies==defs[mon.species].baseSpecies
      and (not mon.form or mon.form=='ALOLA')
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and not mon._ascMegaForm and not mon.ascMegaForm
      and not mon.cosmeticForm and not mon.cosmeticFormId
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and type(mon.level)=='number' and mon.level==math.floor(mon.level)
      and mon.level>=1 and mon.level<=100
  end
  local function activeOwned(game,mon)
    if not game or not game.data or not game.save or game.demo or game.isDemo
        or game.titleDemo or game.demoMode or not healthy(mon) then return false end
    local resolved=R.peek(game)
    if not resolved or resolved.extensionsEnabled~=true then return false end
    for _,member in ipairs(game.save.party or {})do if member==mon then return true end end
    return false
  end
  local families={}
  for _,source in ipairs(sources)do
    local kind=source[3]
    local row={method=method,species=source[2],
      level=kind=='level' and source[4] or nil,
      item=kind=='item' and source[4] or nil}
    local family={from=source[1],to=source[2],kind=kind,rule=row,
      threshold=kind=='friendship' and source[4] or nil,
      timeOfDay=source[5],sourceRow=source.sourceRow}
    families[family.from]=family;C.routes[#C.routes+1]=family
    if kind=='trade' then
      -- Explicit existing KASC solo-trade adaptation, not a second native
      -- link implementation. Real native trade triggers retain their rule.
      family.soloRule={method=method,species=family.to,item='LINKING_CORD'}
    end
  end
  local function exact(mon,evo)
    local family=healthy(mon) and families[mon.species]
    if not family or type(evo)~='table' or evo.method~=method
        or evo.species~=family.to or evo.move or evo.partySpecies then return end
    local rule=evo.item=='LINKING_CORD' and family.soloRule or family.rule
    if rule and evo.level==rule.level and evo.item==rule.item then return family,rule end
  end
  local function entitled(mon)
    local archive=mod.exports and mod.exports.eventArchive
    if not archive then return false end
    local valid,_,profile=archive.battleCompatibleGift(mon)
    local origin=valid and profile and profile.species
    if not origin or not defs[origin] or profile.formId~='ALOLA'
        or profile.baseSpecies~=defs[origin].baseSpecies or profile.originGeneration~=7
        or profile.megaFormId or profile.gigantamaxFormId then return false end
    local visited={}
    while origin and not visited[origin]do
      if origin==mon.species then return true end
      visited[origin]=true;origin=families[origin] and families[origin].to
    end
    return false
  end
  function C.giftEvolutionAllowed(game,mon,evo)
    return C.ready and activeOwned(game,mon) and exact(mon,evo)~=nil and entitled(mon) or false
  end
  methods:register(method,{consumesItem=true,
    check=function(game,mon,evo,trigger)
      local family,rule=exact(mon,evo)
      if not family or not trigger or not C.giftEvolutionAllowed(game,mon,evo) then return false end
      if rule.item then return trigger.kind=='item' and trigger.item==rule.item end
      if family.kind=='trade' then return trigger.kind=='trade' end
      if trigger.kind~='levelup' then return false end
      if family.kind=='level' then
        return mon.level>=rule.level and (not family.timeOfDay
          or opts.timeMode(game)==family.timeOfDay)
      end
      local bond=mon.johtoBond or 0
      return type(bond)=='number' and bond==math.floor(bond)
        and bond>=family.threshold and bond<=255
    end,
    describe=function(evo,data)
      for _,family in ipairs(C.routes)do if family.to==evo.species then
        if evo.item then return (data and data.items[evo.item] or {}).name or evo.item end
        local text=opts.i18n.text
        if family.kind=='friendship' then return text('High friendship (220), then level up',
          'Hohe Freundschaft (220), dann aufleveln')end
        if family.kind=='trade' then return text('Trade (or Linking Cord solo)',
          'Tausch (oder Verbindungsschnur solo)')end
        return text('Level ','Level ')..evo.level..(family.timeOfDay
          and text(' at night',' bei Nacht') or '')
      end end
    end})
  for _,family in ipairs(C.routes)do
    registry:patch(family.from,{evolutions=family.soloRule
      and {family.rule,family.soloRule} or {family.rule}})
  end
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    return C.giftEvolutionAllowed(game,mon,evo)
      or previous and previous(game,mon,evo) or false
  end
  for id,previousEffect in pairs(oldEffects)do
    -- Preserve the original item's/effect's identity and targeting metadata;
    -- shops and paired-link consumers deliberately verify those contracts.
    local itemId,oldUse,effectId=id,previousEffect.use,previousEffect.id
    mod.content.item_effects:patch(effectId,{
      use=function(ctx)
        local family=ctx.target and families[ctx.target.species]
        local rule=family and (itemId=='LINKING_CORD' and family.soloRule or family.rule)
        if rule and rule.item==itemId then
          if not ctx.battle and ctx.itemId==itemId then
            local target=require('src.pokemon.Evolution').pendingFor(
              {data=ctx.data,save=ctx.save,overworld=ctx.overworld},ctx.target,
              {kind='item',item=itemId})
            if target==family.to then return 'consumed',nil,{evolveTo=target,evolveVia='ITEM'}end
          end
          return 'failed',{opts.i18n.text("It won't have\nany effect.",'Es hat keine\nWirkung.')}
        end
        return oldUse(ctx)
      end})
  end
  mod.events:on('pokemon.evolved',function(ev)
    local family=ev and families[ev.fromSpecies]
    if not family or not ev.mon or ev.mon.species~=family.to or ev.toSpecies~=family.to
        or (ev.via~=method and ev.via~='ITEM' and ev.via~='TRADE') then return end
    ev.mon.formId='ALOLA';ev.mon.form='ALOLA';ev.mon.baseSpecies=defs[family.to].baseSpecies
  end,900)
  -- Extend the existing reserve cadence, not a second world-step listener.
  local previousWalking=opts.friendship.walkFriendshipEligible
  opts.friendship.walkFriendshipEligible=function(mon)
    return C.ready and healthy(mon) and mon.species=='MEOWTH_ALOLA'
      or previousWalking(mon) or false
  end
  function C.offers(game,mon)
    local out={};local family=mon and families[mon.species]
    if not family or not activeOwned(game,mon) or not entitled(mon) then return out end
    local rule=family.soloRule or family.rule
    if rule.item and require('src.pokemon.Evolution').pendingFor(game,mon,
        {kind='item',item=rule.item})==family.to then
      local item=game.data.items[rule.item]
      out[1]={id=rule.item,price=item.price,name=item.name,
        help=opts.i18n.text('Use on this Alola Pokémon outside battle. One item is consumed after evolution.',
          'Außerhalb des Kampfes auf dieses Alola-Pokémon anwenden. Ein Item wird bei der Entwicklung verbraucht.')}
    end
    return out
  end
  C.method=method;C.definitions=defs;C.families=families;C.ready=true
  return C
end
