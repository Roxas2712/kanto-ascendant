-- Selected art overrides only known #252+ species. Never mutate fallback tables.
return function(base, selected, surface)
  local result={}
  for dex,row in pairs(base or {})do result[dex]=row end
  for dex,row in pairs((selected or {})[surface] or {})do
    assert(type(row.sourceDex)=='number' and row.sourceDex>251)
    assert(row.species~='GOROCHU' and not row.species:find('MEGA',1,true))
    local old=result[dex]
    assert(not old or old.species==row.species,'Crystal runtime-Dex identity collision')
    local merged={}
    for key,value in pairs(old or {})do merged[key]=value end
    for key,value in pairs(row)do merged[key]=value end
    if surface=='voxel'then
      merged.variants={}
      for variant,value in pairs(old and old.variants or {})do merged.variants[variant]=value end
      for variant,value in pairs(row.variants or {})do merged.variants[variant]=value end
    end
    result[dex]=merged
  end
  return result
end
