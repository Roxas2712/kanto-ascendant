-- Stable additive distribution identities; the selected era is recorded at
-- delivery, never inferred later from the player's current settings or Dex.
return function(opts)
  local species=assert(opts.species)
  local catalog=assert(opts.catalog)
  local P={OWNER='kasc.backend.gift-profiles/v1',profiles={},pending={},moveRevision=34}
  local function recent(source,level,revision)
    local result={}
    local function add(id)
      if species.moveRevision and species.moveRevision(id)>revision then return end
      for _,known in ipairs(result)do if known==id then return end end
      result[#result+1]=id
      if #result>4 then table.remove(result,1)end
    end
    for _,id in ipairs(source.level1Moves)do add(id)end
    for _,row in ipairs(source.learnset)do if row.level<=level then add(row.move)end end
    return result
  end
  local keys={}
  for dex=1,catalog.maximumNationalDex do keys[#keys+1]='dex:'..dex end
  local forms={}
  for key,form in pairs(species.forms or {})do
    if form.kind=='persistent' then forms[#forms+1]=key end
  end
  table.sort(forms)
  for _,key in ipairs(forms)do keys[#keys+1]=key end
  local megaKeys={}
  for key in pairs(opts.megaMetadata and opts.megaMetadata.entries or {})do
    megaKeys[#megaKeys+1]=key
  end
  table.sort(megaKeys)
  for _,key in ipairs(megaKeys)do keys[#keys+1]=key end
  local gmaxKeys={}
  for key in pairs(opts.gigantamaxMetadata and opts.gigantamaxMetadata.entries or {})do
    gmaxKeys[#gmaxKeys+1]=key
  end
  table.sort(gmaxKeys)
  for _,key in ipairs(gmaxKeys)do keys[#keys+1]=key end
  for _,key in ipairs(keys)do
    local row=assert(catalog.entries[key]);local dex=row.nationalDex
    local gmaxMeta=opts.gigantamaxMetadata and opts.gigantamaxMetadata.entries[key]
    local megaMeta=opts.megaMetadata and opts.megaMetadata.entries[key]
    local meta=megaMeta or gmaxMeta
    local mega=megaMeta and opts.mega and opts.mega.byKey[key]
    local gmax=gmaxMeta and opts.gigantamax and opts.gigantamax.byKey[key]
    local ownerKey=meta and meta.baseKey or key
    local owner=assert(catalog.entries[ownerKey])
    local form=species.forms and species.forms[ownerKey]
    local names=species.displayNames and species.displayNames(key,row) or row.formNames or row.names
    local id=species.byKey[ownerKey] or (form and 'KA_GIFT_FORM_'..owner.pokeapiId or 'KA_GIFT_NAT_'..dex)
    if not species.byKey[ownerKey] then
      P.pending[key]=species.pending[ownerKey] or form and form.status or 'missing_species'
    elseif megaMeta and not mega then
      P.pending[key]=opts.mega and opts.mega.pending[key] or 'missing_mega_controller'
    elseif gmaxMeta and not gmax then
      P.pending[key]=opts.gigantamax and opts.gigantamax.pending[key] or 'missing_gigantamax_factor'
    end
    for _,kind in ipairs({'base','egg','shiny_egg'}) do
      local isEgg=kind~='base'
      local suffix=isEgg and '_'..kind or ''
      local profileId=gmaxMeta and ('backend_gmax%s_%d'):format(suffix,row.pokeapiId)
        or megaMeta and ('backend_mega%s_%d'):format(suffix,row.pokeapiId)
        or form and ('backend_form%s_%d'):format(suffix,row.pokeapiId)
        or ('backend_%s_%04d'):format(kind,dex)
      local profile={id=profileId,species=id,level=isEgg and 1 or 15,
        name={en=names.en,de=names.de},short={en=names.en,de=names.de},
        source={en='KASC National Gift Catalogue',de='KASC-National-Geschenkkatalog'},
        giftCode=true,giftCodeOnly=true,backendKey=ownerKey,originGeneration=owner.originGeneration,
        editions={'red','blue','yellow'},badges=0,terrain='grass',habitat='backend_gift',
        generationMoves={},generationMoveSchema='kasc.gift-generation-moves/v1',
        generationMoveRevision=P.moveRevision,generationMoveRevisions={}}
      for revision=1,P.moveRevision do profile.generationMoveRevisions[revision]={}end
      if form then
        profile.formId=form.formId or 'BACKEND_'..owner.pokeapiId
        profile.baseSpecies=form.baseSpecies or species.byKey['dex:'..dex]
      end
      if dex==718 and not meta then
        -- Before the base/form correction #718 gifts used the legacy 10%
        -- species; persistent-form receipts also named it as their base.
        -- Freeze that identity separately from moves. Never transform an
        -- existing gift/egg or silently replace its original receipt.
        profile.identityRevision=2
        profile.identityRevisions={
          [1]={species=form and id or 'ZYGARDE_10',
            baseSpecies=form and 'ZYGARDE_10' or nil},
          [2]={species=id,baseSpecies=profile.baseSpecies}}
      end
      if megaMeta then
        profile.megaSourceKey=key
        profile.megaFormId=mega and mega.id or 'BACKEND_MEGA_'..row.pokeapiId
        profile.megaAvailable=mega~=nil
      end
      if gmaxMeta then
        profile.gigantamaxSourceKey=key
        profile.gigantamaxFormId=gmax and gmax.id or 'BACKEND_GMAX_'..row.pokeapiId
        profile.gigantamaxAvailable=gmax~=nil
      end
      if isEgg then
        profile.deliveryKind='egg'
        profile.eggSteps=math.max(1,tonumber(owner.hatchCycles) or 20)*256
        profile.name={en=names.en..' Egg',de=names.de..'-Ei'}
      end
      if kind=='shiny_egg' then
        -- Gen-I/II native shiny recognition uses DVs, not a presentation flag.
        -- All-even low bits also imply an HP DV of zero. Delivery calculates
        -- actual stats from these values; replay/hatching never roll again.
        profile.guaranteedShiny=true
        profile.dvs={attack=10,defense=10,speed=10,special=10,hp=0}
        profile.name={en='Shiny '..names.en..' Egg',de='Shiny-'..names.de..'-Ei'}
      end
      for epoch=1,7 do
        local learned,reason=species.projectLearnset(ownerKey,epoch)
        local moves=learned and recent(learned,profile.level,profile.generationMoveRevision)
        if not moves or #moves==0 then
          P.pending[key]=reason or 'no_native_level_moves'
        end
        profile.generationMoves[epoch]={moves=moves or {},
          sourceEpoch=learned and learned.generation or math.max(epoch,owner.originGeneration),
          versionGroup=learned and learned.versionGroup or 0}
        -- Freeze historical birth selections: adding a newly implemented
        -- move must not revoke existing receipts or silently refill/reteach.
        for revision=1,P.moveRevision do
          profile.generationMoveRevisions[revision][epoch]={
            moves=learned and recent(learned,profile.level,revision) or {},
            sourceEpoch=profile.generationMoves[epoch].sourceEpoch,
            versionGroup=profile.generationMoves[epoch].versionGroup}
        end
      end
      -- Keep identities in partial diagnostic engines as well. Redemption's
      -- existing species/art/move preflight rejects only that unavailable
      -- distribution, without invalidating every unrelated legacy code.
      profile.moves=profile.generationMoves[6].moves
      P.profiles[#P.profiles+1]=profile
    end
  end
  return P
end
