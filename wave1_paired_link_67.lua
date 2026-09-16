-- KASC solo counterpart trade: one Cord per Pokémon, two native movies.
-- A successful first evolution binds the exact second party member. Merely
-- owning an Accelgor/Escavalier never substitutes for the original partner.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-PAIRED-LINK',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local method,item,effect='KA_WAVE1_PAIRED_LINK','LINKING_CORD','KA_WAVE1_LINKING_CORD_EFFECT'
  local field,key='_kascPairedLink67','paired_link_67'
  local routes={{from=588,to=589,other=616,otherTo=617,sourceRow=297},
    {from=616,to=617,other=588,otherTo=589,sourceRow=312}}
  local ids,defs={},{}
  for _,dex in ipairs({588,589,616,617})do
    local id=S.byKey['dex:'..dex];local def=id and registry:get(id)
    ids[dex],defs[dex]=id,def
    if id~='KA_GIFT_NAT_'..dex or not def or def.backendKey~='dex:'..dex
        or def.backendOwner~=S.OWNER or def.sourceDex~=dex or def.form or def.formId
        or def.baseSpecies or def.isMega or def.isGigantamax then
      C.pending[#C.pending+1]='identity:'..dex
    end
  end
  for _,r in ipairs(routes)do
    r.parent,r.target,r.partner,r.partnerTarget=ids[r.from],ids[r.to],ids[r.other],ids[r.otherTo]
    if defs[r.from] and #(defs[r.from].evolutions or {})~=0 then
      C.pending[#C.pending+1]='existing_edges:'..r.from
    end
  end
  local oldEffect=mod.content.item_effects:get(effect)
  local cord=mod.content.items:get(item)
  if not opts.cord or not opts.cord.ready or not oldEffect or type(oldEffect.use)~='function'
      or oldEffect.use~=opts.cord.effectUse
      or not cord or cord.effect~=effect or cord.price~=8000 then C.pending[#C.pending+1]='cord_owner' end
  if mod.content.evolution_methods:get(method)then C.pending[#C.pending+1]='method_owner'end
  if type(opts.digest)~='function'then C.pending[#C.pending+1]='digest_missing'end
  if #C.pending>0 then return C end
  local function body(mon,id)
    return type(mon)=='table' and mon.species==id and not mon.isEgg and not mon.egg
      and not mon.eggSpecies and not mon.form and not mon.formId and not mon.baseSpecies
      and not mon.cosmeticForm and not mon.cosmeticFormId and not mon._ascMegaForm
      and not mon.ascMegaForm and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and not (mon.item and mon.heldItem and mon.item~=mon.heldItem)
      and mon.item~='EVERSTONE' and mon.heldItem~='EVERSTONE'
  end
  local function inParty(game,mon)
    for _,member in ipairs(game and game.save and game.save.party or {})do
      if member==mon then return true end
    end
    return false
  end
  local function record(row,r,stage)
    return type(row)=='table' and row.version==1 and row.stage==stage
      and type(row.token)=='string' and #row.token==64
      and row.from==r.parent and row.to==r.target
      and row.other==r.partner and row.otherTo==r.partnerTarget
  end
  local function serial(game)
    local data=game and game.save and game.save.modData
    if data~=nil and type(data)~='table'then return end
    local owner=type(data)=='table' and data[mod.id]
    if owner~=nil and type(owner)~='table'then return end
    local state=type(owner)=='table' and owner[key]
    if state==nil then return 1 end
    if type(state)~='table' or state.version~=1 or type(state.serial)~='number'
        or state.serial<0 or state.serial~=math.floor(state.serial) or state.serial>=9007199254740990 then return end
    return state.serial+1
  end
  function C.partner(game,mon,r)
    if not C.ready or not body(mon,r.parent) or not inParty(game,mon)then return end
    local receipt=mon[field]
    if receipt~=nil and not record(receipt,r,'waiting')then return end
    for _,mate in ipairs(game.save.party)do if mate~=mon then
      if receipt and body(mate,r.partnerTarget) then
        local reverse={parent=r.partner,target=r.partnerTarget,partner=r.parent,partnerTarget=r.target}
        if record(mate[field],reverse,'evolved') and mate[field].token==receipt.token then return mate,true end
      end
    end end
    -- If an old partner was released/transferred, a new original pair can
    -- still start a legitimate trade. Never strand the unevolved Pokémon.
    for _,mate in ipairs(game.save.party)do
      if mate~=mon and mate[field]==nil and body(mate,r.partner) and serial(game)then return mate,false end
    end
  end
  local function route(mon,evo)
    if type(evo)~='table' or evo.method~=method or evo.item~=item or evo.level
        or evo.move or evo.partySpecies then return end
    for _,r in ipairs(routes)do if body(mon,r.parent) and evo.species==r.target then return r end end
  end
  local function check(game,mon,evo,trigger)
    local r=route(mon,evo)
    return C.ready and r and trigger and trigger.kind=='item' and trigger.item==item
      and C.partner(game,mon,r)~=nil or false
  end
  mod.content.evolution_methods:register(method,{consumesItem=true,check=check,
    describe=function()return opts.i18n.text('Cord with its paired trade partner in the party',
      'Schnur mit zugehörigem Tauschpartner im Team')end})
  for _,r in ipairs(routes)do registry:patch(r.parent,{evolutions={{method=method,item=item,species=r.target}}})end
  local previousGift=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local r=route(mon,evo);local archive=mod.exports and mod.exports.eventArchive
    if r and archive and C.partner(game,mon,r)then
      local valid,_,p=archive.battleCompatibleGift(mon)
      if valid and p and p.backendKey=='dex:'..r.from and p.species==r.parent
          and not p.formId and not p.baseSpecies and not p.megaFormId and not p.gigantamaxFormId then return true end
    end
    return previousGift and previousGift(game,mon,evo) or false
  end
  local previousUse=oldEffect.use
  mod.content.item_effects:patch(effect,{use=function(ctx)
    if not ctx.battle and ctx.itemId==item and type(ctx.target)=='table' then
      local game={data=ctx.data,save=ctx.save}
      local target,evo=require('src.pokemon.Evolution').pendingFor(game,ctx.target,{kind='item',item=item})
      if route(ctx.target,evo) and target then return 'consumed',nil,{evolveTo=target,evolveVia='ITEM'}end
    end
    return previousUse(ctx)
  end})
  function C.offer(game,mon)
    if not C.ready or not inParty(game,mon)then return end
    for _,r in ipairs(routes)do if body(mon,r.parent)
        and require('src.pokemon.Evolution').pendingFor(game,mon,{kind='item',item=item})==r.target then
      return {id=item,price=8000,name=opts.i18n.text('LINKING CORD','VERBINDUNGSSCHNUR'),
        help=opts.i18n.text('Karrablast + Shelmet in party. Use 1 Cord each. Keep paired partner until both evolve. No Everstone.',
          'Laukaps + Schnuthelm im Team. Je 1 Schnur. Partner bis zu beiden Entwicklungen behalten. Kein Ewigstein.')}
    end end
  end
  -- Native pokemon.evolved omits game; this scoped adapter obtains the real
  -- party before applying, then stores the pair only after a successful movie.
  -- Previews and cancelled/non-item evolutions create no receipt or counter.
  local Evolution=require('src.pokemon.Evolution')
  function C.before(game,mon,target,via)
    if via~='ITEM' and via~=method then return end
    if not(game and game.data and game.data.evolution_methods
        and game.data.evolution_methods[method] and game.data.evolution_methods[method].check==check)then return end
    if require('src.pokemon.Evolution').pendingFor(game,mon,{kind='item',item=item})~=target then return end
    for _,r in ipairs(routes)do if target==r.target then
      local mate,finishing=C.partner(game,mon,r)
      if mate then return {game=game,mon=mon,mate=mate,r=r,finishing=finishing,serial=not finishing and serial(game)}end
    end end
  end
  function C.after(plan)
    if not plan or plan.mon.species~=plan.r.target or not inParty(plan.game,plan.mon)
        or not inParty(plan.game,plan.mate)then return end
    if plan.finishing then plan.mon[field]=nil;plan.mate[field]=nil;return end
    local save,r=plan.game.save,plan.r
    local player=save.player or {};local meta=save.meta or {}
    local token=opts.digest(table.concat({'kasc.paired-link/v1',tostring(player.id),tostring(player.name),
      tostring(meta.playthroughId),tostring(plan.serial)},':'))
    local data=save.modData or {};save.modData=data
    data[mod.id]=data[mod.id] or {};data[mod.id][key]={version=1,serial=plan.serial}
    plan.mon[field]={version=1,token=token,stage='evolved',from=r.parent,to=r.target,other=r.partner,otherTo=r.partnerTarget}
    plan.mate[field]={version=1,token=token,stage='waiting',from=r.partner,to=r.partnerTarget,other=r.parent,otherTo=r.target}
  end
  Evolution._kascPairedLinkOwner67=C
  if not Evolution._kascPairedLinkWrapped67 then
    local apply=Evolution.apply
    Evolution.apply=function(game,mon,target,via)
      local owner=Evolution._kascPairedLinkOwner67
      local plan=owner and owner.before(game,mon,target,via)
      local result=apply(game,mon,target,via)
      if plan then owner.after(plan)end
      return result
    end
    Evolution._kascPairedLinkWrapped67=true
  end
  C.ready=true;C.routes=routes;C.method=method;C.field=field;return C
end
