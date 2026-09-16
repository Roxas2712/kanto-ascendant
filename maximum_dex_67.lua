-- Discovery-only frontend Card. Never resize the runtime species registry:
-- private ABI slots are not National Dex numbers. Eggs are not evidence.
return function(opts)
  local catalog=assert(opts.catalog)
  local species=assert(opts.species)
  local M={CARD_ID='KASC-WAVE1-MAXIMUM-DEX',maximum=assert(catalog.maximumNationalDex)}
  M.generations={}
  for n=1,M.maximum do
    local key=assert(catalog.base[tostring(n)])
    local generation=assert(catalog.entries[key].originGeneration)
    M.generations[generation]=M.generations[generation] or {}
    local group=M.generations[generation];group[#group+1]=n
  end
  function M.number(id,def)
    -- Preserve the established custom entry without counting it as a
    -- canonical base species or colliding with national #279 Pelipper.
    if id=='GOROCHU' and def and def.dex==1026 then return 1026 end
    local key=species.bySpecies[id]
    local row=key and catalog.entries[key]
    if row then return row.nationalDex end
    local n=tonumber(def and def.sourceDex)
      or tonumber(def and def.dex)
    if def and def.sourceDex==nil and n and n>=252 and n<=279 then return nil end
    return n and n>=1 and n<=M.maximum and n or nil
  end
  function M.report(game,generation)
    local data=game and game.data and game.data.pokemon or {}
    local dex=game and game.save and game.save.pokedex or {}
    local owned=type(dex.owned)=='table' and dex.owned or {}
    local count,missing,unavailable,required=0,{},{},0
    local group=generation and M.generations[generation]
    local members={}
    if group then for _,n in ipairs(group)do members[n]=true end end
    for n=1,M.maximum do
      if not generation or members[n] then
      required=required+1
      local key=catalog.base[tostring(n)]
      local id=key and species.byKey[key]
      -- Fail closed on an incomplete registry; do not shrink the target.
      if not id or not data[id] then unavailable[#unavailable+1]=n end
      if id and data[id] and owned[id]==true then count=count+1
      else missing[#missing+1]=n end
      end
    end
    return {required=required,owned=count,missing=missing,generation=generation,
      unavailable=unavailable,complete=required>0 and #missing==0 and #unavailable==0}
  end
  function M.discovered(game,included)
    local out={}
    local dex=game.save.pokedex or {}
    local seen,owned=dex.seen or {},dex.owned or {}
    for id,def in pairs(game.data.pokemon or {})do
      local n=M.number(id,def)
      if not included[id] and n and (seen[id]==true or owned[id]==true) then
        out[#out+1]={species=id,definition=def,number=n}
      end
    end
    table.sort(out,function(a,b)
      if a.number~=b.number then return a.number<b.number end
      return a.species<b.species
    end)
    return out
  end
  -- Project only the page's copy. Saves, species IDs and battle art retain
  -- their private runtime identities, including persistent regional forms.
  function M.entryDefinition(id,def)
    local n=M.number(id,def)
    if not n then return def end
    local key=species.bySpecies[id]
    local row=key and catalog.entries[key]
    if n==def.dex and (def.dexEntry or not row)then return def end
    local out={};for k,v in pairs(def)do out[k]=v end
    out.dex=n
    if not def.dexEntry and row then
      -- Verified measurements only. Missing authored category/prose stays
      -- explicitly unknown; do not invent flavour text from a sprite.
      local inches=math.floor(row.heightM/0.0254+0.5)
      out.dexEntry={heightFt=math.floor(inches/12),heightIn=inches%12,
        heightM=row.heightM,weightKg=row.weightKg,weight=math.floor(row.weightKg*22.046226+0.5)}
    end
    return out
  end
  return M
end
