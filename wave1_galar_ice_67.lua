-- Pinned evolution row 458: Galar Darumaka -> Galar standard Darmanitan.
-- No entitlement to ordinary or temporary Zen bodies; reuse the existing stone.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-GALAR-ICE',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local methods=mod.content.evolution_methods;local method='KA_WAVE1_GALAR_ICE'
  local defs,ids={},{}
  for _,row in ipairs({{10176,554},{10177,555}})do
    local pid,dex=row[1],row[2];local key='form:'..pid
    local id=S.byKey[key];local def=id and registry:get(id)
    local base=S.byKey['dex:'..dex]
    if not def or id~='KA_GIFT_FORM_'..pid or def.backendOwner~=S.OWNER
        or def.backendKey~=key or def.sourceDex~=dex or def.formId~='BACKEND_'..pid
        or not base or not registry:get(base) or def.baseSpecies~=base
        or def.isMega or def.isGigantamax then C.pending[#C.pending+1]='identity:'..key end
    ids[pid]=id;defs[pid]=def
  end
  if defs[10176] and #(defs[10176].evolutions or {})>0 then
    C.pending[#C.pending+1]='existing_edges' end
  local item=mod.content.items:get('ICE_STONE')
  if not item or item.price~=3000 or item.needsTarget~=true or item.battle~=false then
    C.pending[#C.pending+1]='stone_unavailable' end
  local effect='KA_WAVE1_GALAR_ICE_EFFECT'
  local oldEffect=item and item.effect=='KA_BACKEND_EVOLUTION_ICE_STONE'
    and mod.content.item_effects:get(item.effect)
  if not oldEffect or type(oldEffect.use)~='function' then
    C.pending[#C.pending+1]='stone_effect_unavailable' end
  if mod.content.item_effects:get(effect) then C.pending[#C.pending+1]='effect_owned' end
  if methods:get(method) then C.pending[#C.pending+1]='method_owned' end
  if #C.pending>0 then return C end
  local function exact(mon,evo)
    return type(mon)=='table' and mon.species==ids[10176]
      and mon.formId==defs[10176].formId and mon.baseSpecies==defs[10176].baseSpecies
      and (not mon.form or mon.form==mon.formId)
      and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and not mon._ascMegaForm and not mon.ascMegaForm
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and type(evo)=='table' and evo.method==method and evo.item=='ICE_STONE'
      and evo.species==ids[10177] and not evo.level and not evo.move and not evo.partySpecies
  end
  methods:register(method,{
    check=function(_,mon,evo,trigger)
      return C.ready and exact(mon,evo) and trigger and trigger.kind=='item'
        and trigger.item=='ICE_STONE' or false
    end,
    describe=function()return opts.i18n.text('Ice Stone (Galar form)','Eisstein (Galar-Form)')end,
    consumesItem=true,
  })
  registry:patch(ids[10176],{evolutions={{method=method,item='ICE_STONE',species=ids[10177]}}})
  mod.content.item_effects:register(effect,{field=true,battle=false,needsTarget=true,
    use=function(ctx)
      if ctx.target and ctx.target.species==ids[10176] then
        if not ctx.battle and ctx.itemId=='ICE_STONE' then
          local game={data=ctx.data,save=ctx.save,overworld=ctx.overworld}
          local target=require('src.pokemon.Evolution').pendingFor(game,ctx.target,
            {kind='item',item=ctx.itemId})
          if target==ids[10177] then
            -- Native ITEM films cannot be canceled after BagMenu spends a stone.
            return 'consumed',nil,{evolveTo=target,evolveVia='ITEM'}
          end
        end
        return 'failed',{opts.i18n.text("It won't have\nany effect.",'Es hat keine\nWirkung.')}
      end
      return oldEffect.use(ctx)
    end})
  mod.content.items:patch('ICE_STONE',{effect=effect})
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if C.ready and exact(mon,evo) and archive then
      local valid,_,p=archive.battleCompatibleGift(mon)
      if valid and p and p.backendKey=='form:10176' and p.species==ids[10176]
          and p.formId==defs[10176].formId and p.baseSpecies==defs[10176].baseSpecies
          and not p.megaFormId and not p.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  mod.events:on('pokemon.evolved',function(ev)
    if ev and (ev.via==method or ev.via=='ITEM') and ev.fromSpecies==ids[10176] and ev.toSpecies==ids[10177]
        and ev.mon and ev.mon.species==ids[10177] then
      ev.mon.formId=defs[10177].formId;ev.mon.form=defs[10177].formId
      ev.mon.baseSpecies=defs[10177].baseSpecies
    end
  end,900)
  C.ready=true;return C
end
