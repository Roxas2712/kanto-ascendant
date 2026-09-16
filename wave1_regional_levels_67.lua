-- Regional-body evolution graph: never borrow a normal body's level route.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-REGIONAL-LEVELS',ready=false,pending={}}
  local data,species=assert(opts.data),assert(opts.species)
  assert(data.schema=='kasc.wave1-regional-levels/v1')
  local registry,methods=mod.content.pokemon,mod.content.evolution_methods
  local method='KA_WAVE1_REGIONAL_LEVEL'
  local expected={
    [451]={10161,863,52,863,28},[455]={10168,866,122,866,42},
    [456]={10173,864,222,864,38},[538]={10174,10175,263,264,20},
    [457]={10175,862,264,862,35,'night'},[529]={10238,10239,570,571,30},
    [505]={10253,980,194,980,20},
  }
  local function owned(key,dex)
    local id=species.byKey[key];local def=id and registry:get(id)
    local pid=key:match('^form:(%d+)$')
    local wanted=pid and 'KA_GIFT_FORM_'..pid or 'KA_GIFT_NAT_'..dex
    if not def or id~=wanted or def.backendOwner~=species.OWNER
        or def.backendKey~=key or def.sourceDex~=dex or def.isMega or def.isGigantamax then return end
    if pid then
      local base=species.byKey['dex:'..dex]
      if not base or not registry:get(base) or def.formId~='BACKEND_'..pid
          or def.baseSpecies~=base then return end
    elseif def.form or def.formId then return end
    return id,def
  end
  local families,plans,seen={},{},{}
  for _,row in ipairs(data.edges)do
    local check=expected[row.sourceRow]
    assert(check and not seen[row.sourceRow] and row.fromKey=='form:'..check[1]
      and row.toKey==(check[2]>10000 and 'form:' or 'dex:')..check[2]
      and row.fromDex==check[3] and row.toDex==check[4] and row.level==check[5]
      and row.timeOfDay==check[6])
    seen[row.sourceRow]=true
    local parent,pdef=owned(row.fromKey,row.fromDex)
    local target,tdef=owned(row.toKey,row.toDex)
    if not parent or not target or #(pdef.evolutions or {})~=0 then
      C.pending[#C.pending+1]='identity_or_existing_evolution:'..row.fromKey
    else
      local rule={method=method,species=target,level=row.level}
      families[parent]={source=row,target=target,rule=rule,def=pdef,targetDef=tdef}
      plans[#plans+1]={parent=parent,rule=rule}
    end
  end
  assert(#data.edges==7)
  for rid in pairs(expected)do assert(seen[rid])end
  if methods:get(method) then C.pending[#C.pending+1]='method_owned' end
  if type(opts.timeMode)~='function' then C.pending[#C.pending+1]='time_provider_missing' end
  if #C.pending>0 then return C end
  local function healthy(mon)
    return type(mon)=='table' and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and type(mon.hp)=='number' and mon.hp>0 and mon.hp<math.huge
      and not mon._ascMegaForm and not mon.ascMegaForm
  end
  local function exact(mon,evo)
    local family=mon and families[mon.species]
    if not family or type(evo)~='table' or evo.method~=method
        or evo.species~=family.target or evo.level~=family.source.level
        or evo.item or evo.move or evo.partySpecies then return end
    if mon.formId~=family.def.formId or mon.baseSpecies~=family.def.baseSpecies
        or (mon.form and mon.form~=mon.formId) then return end
    return family
  end
  methods:register(method,{
    check=function(game,mon,evo,trigger)
      local family=C.ready and healthy(mon) and exact(mon,evo)
      local level=mon and mon.level
      return family and trigger and trigger.kind=='levelup'
        and type(level)=='number' and level==math.floor(level)
        and level>=family.source.level and level<=100
        and (not family.source.timeOfDay or opts.timeMode(game)==family.source.timeOfDay) or false
    end,
    describe=function(evo)return opts.i18n.text('Level ','Level ')..evo.level
      ..(evo.species==species.byKey['dex:862'] and opts.i18n.text(' at night',' bei Nacht') or '')end,
  })
  for _,plan in ipairs(plans)do registry:patch(plan.parent,{evolutions={plan.rule}})end
  local previous=species.giftEvolutionAllowed
  species.giftEvolutionAllowed=function(game,mon,evo)
    if C.ready and healthy(mon) and exact(mon,evo) then
      local archive=mod.exports and mod.exports.eventArchive
      local valid,_,profile
      if archive then valid,_,profile=archive.battleCompatibleGift(mon)end
      local origin=profile and species.byKey[profile.backendKey]
      local start=origin and families[origin]
      if valid and start and profile.species==origin
          and profile.formId==start.def.formId and profile.baseSpecies==start.def.baseSpecies
          and not profile.megaFormId and not profile.gigantamaxFormId then
        local visited={}
        while origin and not visited[origin] do
          if origin==mon.species then return true end
          visited[origin]=true;origin=families[origin] and families[origin].target
        end
      end
    end
    return previous and previous(game,mon,evo) or false
  end
  mod.events:on('pokemon.evolved',function(ev)
    local family=ev and families[ev.fromSpecies]
    if not family or ev.via~=method or not ev.mon or ev.toSpecies~=family.target
        or ev.mon.species~=family.target then return end
    local def=family.targetDef
    ev.mon.formId=def.formId;ev.mon.form=def.formId;ev.mon.baseSpecies=def.baseSpecies
  end,900)
  C.ready=true;C.families=families
  return C
end
