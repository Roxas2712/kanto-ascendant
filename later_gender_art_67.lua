-- Cosmetic artwork only: never register or change a Pokemon species or gender.
return function(mod,opts)
  local C={ready=false,pending={}}
  local data=opts.data or {}
  if not data.schema then return C end
  assert(data.schema=='kasc.later-gender-art/v1')
  local sprites,fronts=opts.sprites,opts.fronts
  if not(sprites and sprites.registerAdditionalArt and sprites.setLaterGenderProvider
      and fronts and fronts.setLaterGenderProvider)then
    C.pending[1]='presentation_unavailable';return C
  end
  local expected={}
  for _,dex in ipairs({449,450,521,592,593})do expected[dex]=true end
  assert(type(data.payload)=='table' and type(data.payload.entries)=='table','missing gender artwork payload')
  local bySpecies={}
  local count=0
  for key,row in pairs(data.art or {})do
    local dex=tonumber(key)
    assert(dex and expected[dex] and row.dex==dex,'unexpected later-generation gender species')
    assert(row.artAlias=='KA_GIFT_LATER_FEMALE_'..dex and row.artSlot==94000+dex)
    assert(not mod.content.pokemon:get(row.artAlias),'cosmetic alias already owned')
    assert(type(row.owners)=='table' and #row.owners>0,'missing gender artwork owners')
    local payloadRow=data.payload.entries[tostring(row.artSlot)]
    assert(type(payloadRow)=='table' and payloadRow.species==row.artAlias,'gender artwork payload mismatch')
    for _,species in ipairs(row.owners)do
      assert(type(species)=='string' and species~='' and not bySpecies[species],'ambiguous or invalid gender artwork owner')
      local def=assert(mod.content.pokemon:get(species),'missing existing gender artwork owner')
      assert(tonumber(def.sourceDex)==dex,'gender owner dex mismatch')
      payloadRow.heightM=def.heightM -- Preserve the existing species' presentation height.
      bySpecies[species]=row
    end
    count=count+1
  end
  assert(count==5,'incomplete later-generation gender selection')
  local payloadCount=0
  for slot in pairs(data.payload.entries)do
    local dex=tonumber(slot) and tonumber(slot)-94000
    assert(dex and expected[dex] and data.art[tostring(dex)],'unexpected gender artwork slot')
    payloadCount=payloadCount+1
  end
  assert(payloadCount==count,'incomplete gender artwork payload')
  local registered,why=sprites.registerAdditionalArt(data.payload)
  if registered~=count then C.pending[1]='art_registration:'..tostring(why);return C end
  function C.artFor(mon,requested)
    local row=C.ready and bySpecies[requested]
    if not row or type(mon)~='table' or mon.species~=requested
        or mon.isEgg or mon.egg or mon.eggSpecies or mon.form or mon.formId
        or mon._ascMegaForm or mon.ascMegaForm or mon.transformed then return nil end
    local def=mod.content.pokemon:get(requested)
    if not def or tonumber(def.sourceDex)~=row.dex or def.form or def.formId
        or def.isMega or def.isGigantamax then return nil end
    if opts.gender.getMonGender(mon,{pokemon={[requested]=def}})=='FEMALE' then return row end
  end
  function C.staticSprite(path,requested,ctx)
    if not ctx or ctx.kind=='battle' or path~=requested then return nil end
    local row=C.artFor(ctx.mon,ctx.species)
    if not row then return nil end
    local def=mod.content.pokemon:get(ctx.species)
    local side=ctx.side=='back' and 'back' or 'front'
    if requested~=(side=='back' and def.spriteBack or def.spriteFront)then return nil end
    local shiny=opts.shiny and opts.shiny.isShiny(ctx.mon)
      and not(mod.options and mod.options:get('shiny_effects')==false)
    return mod.path..'/'..row.paths[side..(shiny and 'Shiny' or '')]
  end
  sprites.setLaterGenderProvider(C.artFor);fronts.setLaterGenderProvider(C.artFor)
  C.ready=true;C.count=count;return C
end
