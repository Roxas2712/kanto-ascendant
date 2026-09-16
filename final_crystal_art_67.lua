-- Final gap closure. No runtime species registration and no old-table mutation.
return function(base,selected,surface)
  local result={}
  for dex,row in pairs(base or {})do result[dex]=row end
  for dex,row in pairs(selected[surface] or {})do
    assert(row.sourceDex>251 and row.species~='GOROCHU' and not row.species:find('MEGA',1,true))
    local old=result[dex]
    assert(not old or old.species==row.species,'Final sprite species mismatch')
    local merged={};for k,v in pairs(old or {})do merged[k]=v end
    for k,v in pairs(row)do
      if surface=='native' and type(v)=='table' and old and old[k] and old[k].animated then
        -- Existing authored poses remain authoritative.
      elseif k~='variants' then merged[k]=v end
    end
    if surface=='voxel' then
      merged.variants={}
      for k,v in pairs(old and old.variants or {})do merged.variants[k]=v end
      for k,v in pairs(row.variants or {})do
        if not merged.variants[k]then merged.variants[k]=v end
      end
      if merged.variants.normal then
        for k,v in pairs(merged.variants.normal)do merged[k]=v end
      end
    end
    result[dex]=merged
  end
  return result
end
