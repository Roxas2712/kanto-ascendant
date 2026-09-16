-- KASC-67-BACKEND-MEGA-FORMS: reuse protected owners, append missing controllers.
return function(opts)
  local mega,catalog,species=assert(opts.mega),assert(opts.catalog),assert(opts.species)
  local metadata,art=assert(opts.metadata),assert(opts.art)
  local C={CARD_ID='KASC-67-BACKEND-MEGA-FORMS',byKey={},registered={},reused={},pending={}}
  local existing={};for _,profile in ipairs(mega.forms)do existing[profile.id]=profile end
  local function copy(value)
    if type(value)~='table' then return value end
    local out={};for k,v in pairs(value)do out[k]=copy(v)end;return out
  end
  local keys={};for key in pairs(metadata.entries)do keys[#keys+1]=key end;table.sort(keys)
  local plans={}
  for _,key in ipairs(keys)do
    local row,meta=catalog.entries[key],metadata.entries[key]
    local original=existing[meta.existingProfileId]
    if original then
      C.byKey[key]=original;C.reused[#C.reused+1]=original.id
    else
      local baseId=species.byKey[meta.baseKey]
      local image=art[key];local p=image and image.paths
      if not baseId then C.pending[key]='missing_base_owner'
      elseif not (p and p.front and p.back and p.frontShiny and p.backShiny
          and p.voxelFront and p.voxelFrontShiny) then C.pending[key]='missing_art'
      else
        local base=assert(catalog.entries[meta.baseKey]);local s,b=row.baseStats,base.baseStats
        local names=species.displayNames and species.displayNames(key,row) or row.formNames or row.names
        local label=opts.i18n and opts.i18n.text(names.en,names.de) or names.en
        local types={};for _,kind in ipairs(row.types)do
          types[#types+1]=kind=='PSYCHIC' and 'PSYCHIC_TYPE' or kind
        end
        local profile={id='BACKEND_MEGA_'..row.pokeapiId,species=baseId,
          backendKey=key,baseKey=meta.baseKey,stone=meta.stone,stoneLabel=meta.stoneLabel,
          requiredMove=meta.requiredMove,
          label=label,caseLabel=label,tier='masters',cost=10000,
          bonuses={attack=s.atk-b.atk,defense=s.def-b.def,speed=s.spe-b.spe,special=s.spa-b.spa},
          specialDefenseBonus=s.spd-b.spd,modernBaseStats=copy(s),types=types,
          asset='backend_mega_'..row.pokeapiId,backendArt=copy(image),staticOnly=not image.animations}
        plans[#plans+1]=profile;C.byKey[key]=profile;C.registered[#C.registered+1]=profile.id
      end
    end
  end
  assert(mega.registerAdditionalProfiles(plans)==#plans,'backend Mega registration incomplete')
  local abilityKeys={}
  for key,profile in pairs(C.byKey)do abilityKeys[profile.id]={key=key,species=profile.species}end
  function C.abilityKey(mon)
    local row=mon and abilityKeys[mon._ascMegaForm]
    return row and row.species==mon.species and row.key or nil
  end
  return C
end
