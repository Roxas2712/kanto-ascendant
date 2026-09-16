-- Exact Wuffels family: ordinary day/night and separate Own Tempo dusk body.
-- Pinned Pokemon evolution rows 386/387/460; no edition or species unlock.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-ROCKRUFF',ready=false,pending={}}
  local S=assert(opts.species);local registry=mod.content.pokemon
  local methods=mod.content.evolution_methods;local method='KA_WAVE1_ROCKRUFF_TIME'
  local ids,defs={},{}
  for _,entry in ipairs({{'dex:744',744},{'dex:745',745},{'form:10126',745},
      {'form:10151',744},{'form:10152',745}})do
    local key,dex=entry[1],entry[2];local pid=key:match('^form:(%d+)$')
    local id=S.byKey[key];local def=id and registry:get(id)
    local valid=def and id==(pid and 'KA_GIFT_FORM_'..pid or 'KA_GIFT_NAT_'..dex)
      and def.backendOwner==S.OWNER and def.backendKey==key and def.sourceDex==dex
      and not def.isMega and not def.isGigantamax
    if valid and pid then
      valid=def.formId=='BACKEND_'..pid and def.baseSpecies==S.byKey['dex:'..dex]
        and def.baseSpecies~=nil and registry:get(def.baseSpecies)~=nil
    elseif valid then valid=not def.formId and not def.form end
    if not valid then C.pending[#C.pending+1]='identity:'..key end
    ids[key]=id;defs[key]=def
  end
  for _,key in ipairs({'dex:744','form:10151'})do
    if defs[key] and #(defs[key].evolutions or {})~=0 then C.pending[#C.pending+1]='existing_edges:'..key end
  end
  if methods:get(method) then C.pending[#C.pending+1]='method_owned' end
  if type(opts.timeMode)~='function' or type(opts.isDusk)~='function' then C.pending[#C.pending+1]='clock_missing' end
  if #C.pending>0 then return C end
  local routes={
    {from='dex:744',to='dex:745',phase='day'},
    {from='dex:744',to='form:10126',phase='night'},
    {from='form:10151',to='form:10152',phase='dusk'},
  }
  local function healthy(mon)
    return type(mon)=='table' and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and not mon._ascMegaForm and not mon.ascMegaForm
  end
  local function exact(mon,evo)
    if not healthy(mon) or type(evo)~='table' or evo.method~=method or evo.level~=25
        or evo.item or evo.move or evo.partySpecies then return end
    for _,r in ipairs(routes)do
      local def=defs[r.from]
      if mon.species==ids[r.from] and evo.species==ids[r.to]
          and mon.formId==def.formId and mon.baseSpecies==def.baseSpecies
          and (not mon.form or mon.form==def.formId) then return r end
    end
  end
  methods:register(method,{
    check=function(game,mon,evo,trigger)
      local r=C.ready and exact(mon,evo);local level=mon and mon.level
      if not r or not trigger or trigger.kind~='levelup' or type(level)~='number'
          or level~=math.floor(level) or level<25 or level>100 then return false end
      if r.phase=='dusk' then return opts.isDusk(game)==true end
      return opts.timeMode(game)==r.phase
    end,
    describe=function(evo)
      if evo.species==ids['form:10152'] then
        return opts.i18n.text('Level 25+, AUTO time 17:00-17:59 (Own Tempo form)',
          'Level 25+, AUTO-Zeit 17:00-17:59 (Tempomacher-Form)')
      end
      return evo.species==ids['form:10126'] and opts.i18n.text('Level 25+ at night','Level 25+ bei Nacht')
        or opts.i18n.text('Level 25+ by day','Level 25+ am Tag')
    end,
  })
  local graph={}
  for _,r in ipairs(routes)do
    local id=ids[r.from];graph[id]=graph[id] or {}
    graph[id][#graph[id]+1]={method=method,species=ids[r.to],level=25}
  end
  for id,edges in pairs(graph)do registry:patch(id,{evolutions=edges})end
  local previous=S.giftEvolutionAllowed
  S.giftEvolutionAllowed=function(game,mon,evo)
    local r=C.ready and exact(mon,evo)
    local archive=mod.exports and mod.exports.eventArchive
    if r and archive then
      local valid,_,p=archive.battleCompatibleGift(mon);local def=defs[r.from]
      if valid and p and p.backendKey==r.from and p.species==ids[r.from]
          and p.formId==def.formId and p.baseSpecies==def.baseSpecies
          and not p.megaFormId and not p.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  mod.events:on('pokemon.evolved',function(ev)
    if not ev or ev.via~=method or not ev.mon or ev.mon.species~=ev.toSpecies then return end
    for _,r in ipairs(routes)do
      if ev.fromSpecies==ids[r.from] and ev.toSpecies==ids[r.to] then
        local def=defs[r.to]
        ev.mon.formId=def.formId;ev.mon.form=def.formId;ev.mon.baseSpecies=def.baseSpecies
        return
      end
    end
  end,900)
  C.ready=true;C.routes=routes
  return C
end
