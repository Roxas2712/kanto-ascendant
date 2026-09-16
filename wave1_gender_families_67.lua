-- Exact base-level families with cosmetic/permanent gender-dependent bodies.
-- No new Pokemon IDs, no unrelated forms, and no legacy DV rewrites.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-GENDER-FAMILIES',ready=false,pending={}}
  local data=assert(opts.data);assert(data.schema=='kasc.wave1-gender-families/v1')
  local species,gender=assert(opts.species),assert(opts.gender)
  local registry,methods=mod.content.pokemon,mod.content.evolution_methods
  local method='KA_WAVE1_GENDER_LEVEL'
  local families,targets,plans={},{},{}
  local expected={
    [667]={668,35,356,'dex:668','dex:668'},
    [677]={678,25,360,'dex:678','form:10025'},
    [915]={916,18,474,'dex:916','form:10254'},
  }
  local function owned(key,dex)
    local id=species.byKey[key]
    local def=id and registry:get(id)
    local form=key:match('^form:(%d+)$')
    local expectedId=form and ('KA_GIFT_FORM_'..form) or ('KA_GIFT_NAT_'..dex)
    if not def or def.backendOwner~=species.OWNER or def.backendKey~=key
        or id~=expectedId or def.sourceDex~=dex
        or def.isMega or def.isGigantamax then return nil end
    return id,def
  end
  local seen={}
  for _,row in ipairs(data.families)do
    local check=expected[row.parent]
    assert(check and not seen[row.parent] and row.target==check[1] and row.level==check[2]
      and row.sourceRow==check[3] and row.maleKey==check[4] and row.femaleKey==check[5])
    seen[row.parent]=true
    local parent,pdef=owned('dex:'..row.parent,row.parent)
    local male,mdef=owned(row.maleKey,row.target)
    local female,fdef=owned(row.femaleKey,row.target)
    if not parent or not male or not female or pdef.formId or pdef.form
        or mdef.formId or mdef.form
        or #(pdef.evolutions or {})~=0
        or (female~=male and (fdef.baseSpecies~=male or fdef.formId~='BACKEND_'..row.femaleKey:sub(6))) then
      C.pending[#C.pending+1]='family_identity:'..row.parent
    else
      local rules={{method=method,species=male,level=row.level}}
      if female~=male then rules[#rules+1]={method=method,species=female,level=row.level}end
      families[parent]={source=row,male=male,female=female,rules=rules}
      targets[male]=true;targets[female]=true
      plans[#plans+1]={parent=parent,rules=rules}
    end
  end
  assert(seen[667] and seen[677] and seen[915] and #data.families==3)
  local sprites,fronts=opts.sprites,opts.fronts
  if methods:get(method) then C.pending[#C.pending+1]='method_owned' end
  if not sprites or not sprites.registerAdditionalArt or not sprites.setGenderFormProvider
      or not fronts or not fronts.setGenderFormProvider then C.pending[#C.pending+1]='presentation_unavailable' end
  if #C.pending>0 then return C end
  local art=assert(data.pyroarFemale)
  assert(art.pokemonId==668 and art.sourceFormId==10551 and art.artSlot==90551
    and art.artAlias=='KA_GIFT_PYROAR_FEMALE_ART' and not registry:get(art.artAlias))
  local count,why=sprites.registerAdditionalArt(data.payload)
  if count~=1 then C.pending[1]='art_registration:'..tostring(why);return C end
  local function healthy(mon)
    local hp=mon and mon.hp
    return type(mon)=='table' and not mon.isEgg and not mon.egg and not mon.eggSpecies
      and type(hp)=='number' and hp>0 and hp~=math.huge
  end
  local function exact(mon,evo)
    local family=mon and families[mon.species]
    if not family or type(evo)~='table' or evo.method~=method
        or evo.level~=family.source.level or evo.item or evo.move or evo.partySpecies then return nil end
    for _,row in ipairs(family.rules)do if evo.species==row.species then return family end end
  end
  methods:register(method,{
    check=function(game,mon,evo,trigger)
      local family=C.ready and exact(mon,evo)
      local level=mon and mon.level
      if not family or not healthy(mon) or not trigger or trigger.kind~='levelup'
          or type(level)~='number' or level~=math.floor(level)
          or level<family.source.level or level>100 then return false end
      local sex=gender.getMonGender(mon,game)
      return (sex=='MALE' and family.male==evo.species)
        or (sex=='FEMALE' and family.female==evo.species) or false
    end,
    describe=function(evo)return opts.i18n.text('Level ','Level ')..evo.level
      ..opts.i18n.text('; form follows gender','; Form nach Geschlecht')end,
  })
  for _,plan in ipairs(plans)do registry:patch(plan.parent,{evolutions=plan.rules})end
  local previous=species.giftEvolutionAllowed
  species.giftEvolutionAllowed=function(game,mon,evo)
    local family=C.ready and healthy(mon) and exact(mon,evo)
    if family then
      local archive=mod.exports and mod.exports.eventArchive
      local valid,_,profile
      if archive then valid,_,profile=archive.battleCompatibleGift(mon)end
      if valid and profile and profile.species==mon.species
          and profile.backendKey=='dex:'..family.source.parent
          and not profile.formId and not profile.megaFormId and not profile.gigantamaxFormId then return true end
    end
    return previous and previous(game,mon,evo) or false
  end
  local pyroar=species.byKey['dex:668']
  local litleo=species.byKey['dex:667']
  function C.artFor(mon,requested)
    if not C.ready or type(mon)~='table' or requested~=pyroar
        or mon.isEgg or mon.egg or mon.eggSpecies
        or (mon.species~=pyroar and mon.species~=litleo)
        or mon.form or mon.formId or mon._ascMegaForm or mon.ascMegaForm then return nil end
    local def=registry:get(mon.species)
    if gender.getMonGender(mon,{pokemon={[mon.species]=def}})=='FEMALE' then return art end
  end
  sprites.setGenderFormProvider(C.artFor);fronts.setGenderFormProvider(C.artFor)
  function C.staticSprite(path,requested,ctx)
    if not ctx or ctx.kind=='battle' or path~=requested then return nil end
    local selected=C.artFor(ctx.mon,ctx.species)
    if not selected then return nil end
    local def=registry:get(ctx.species)
    local side=ctx.side=='back' and 'back' or 'front'
    if requested~=(side=='back' and def.spriteBack or def.spriteFront)then return nil end
    local shiny=mod.exports and mod.exports.shinySystem
    local useShiny=shiny and shiny.isShiny(ctx.mon)
      and not (mod.options and mod.options:get('shiny_effects')==false)
    return mod.path..'/'..art.paths[side..(useShiny and 'Shiny' or '')]
  end
  mod.events:on('pokemon.evolved',function(ev)
    if not ev or ev.via~=method or not ev.mon or not families[ev.fromSpecies]
        or ev.mon.species~=ev.toSpecies or not targets[ev.toSpecies] then return end
    local family=families[ev.fromSpecies]
    if ev.toSpecies~=family.male and ev.toSpecies~=family.female then return end
    local def=registry:get(ev.toSpecies)
    ev.mon.formId=def.formId;ev.mon.form=def.formId;ev.mon.baseSpecies=def.baseSpecies
  end,900)
  C.ready=true
  return C
end
