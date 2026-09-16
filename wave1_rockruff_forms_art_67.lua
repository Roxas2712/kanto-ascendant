-- Add missing Crystal motion before registration; never replace Original art.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-ROCKRUFF-FORM-ART',selected={},pending={}}
  local expected={
    [10126]={745,'lycanroc-midnight',2,{500,83}},
    [10151]={744,'rockruff-own-tempo',4,{150,133,133,83}},
    [10152]={745,'lycanroc-dusk',2,{667,83}},
  }
  local plans={}
  for _,pid in ipairs({10126,10151,10152})do
    local check=expected[pid];local key='form:'..pid
    local row=opts.art and opts.art[key]
    local cat=opts.catalog and opts.catalog.entries and opts.catalog.entries[key]
    local picked=opts.selected and opts.selected[key]
    local valid=row and row.key==key and row.paths and row.animations==nil
      and cat and cat.pokeapiId==pid and cat.nationalDex==check[1]
      and cat.identifier==check[2] and cat.isBase==false and not cat.isMega and not cat.isGigantamax
      and picked and picked.key==key and picked.pokeapiId==pid
      and picked.nationalDex==check[1] and picked.identifier==check[2]
      and type(picked.animations)=='table'
    local old='assets/backend_national_catalog_67/battle/'..pid..'/'
    for _,side in ipairs({'front','frontShiny','back','backShiny'})do
      valid=valid and row.paths[side]==old..side..'.png'
    end
    for _,side in ipairs({'front','back','voxel'})do for _,variant in ipairs({'normal','shiny'})do
      local keyside=side..(variant=='shiny' and 'Shiny' or '')
      local pose=valid and picked.animations[keyside]
      local size=side=='back' and 48 or side=='voxel' and 64 or 56
      local count=side=='back' and 1 or check[3]
      local root='assets/wave1_rockruff_forms_67/'..pid..'/'..side..'/'..variant
      valid=valid and type(pose)=='table' and pose.root==root
        and type(pose.durations)=='table' and #pose.durations==count
        and pose.animated==(side~='back') and pose.scale==(side=='voxel' and 1.5 or 1)
      local first,moving
      for i=1,count do
        local bytes=valid and mod:read(root..('/%03d.png'):format(i))
        local ms=valid and pose.durations[i]
        valid=valid and type(ms)=='number' and ms>0 and ms<math.huge
          and ms==(side=='back' and 1000 or check[4][i])
          and type(bytes)=='string' and bytes:sub(1,8)=='\137PNG\r\n\26\n'
          and bytes:sub(13,24)=='IHDR'..string.char(0,0,0,size,0,0,0,size)
        if valid then moving=moving or (first and first~=bytes);first=first or bytes end
      end
      valid=valid and (side=='back' or moving==true)
    end end
    if not valid then C.pending[#C.pending+1]=key else plans[#plans+1]={key=key,row=row,picked=picked}end
  end
  if #C.pending>0 then return C end
  for _,plan in ipairs(plans)do
    local animations={}
    for k,p in pairs(plan.picked.animations)do
      local times={};for i,ms in ipairs(p.durations)do times[i]=ms end
      animations[k]={root=p.root,durations=times,animated=p.animated,scale=p.scale}
    end
    plan.row.animations=animations;C.selected[#C.selected+1]=plan.key
  end
  return C
end
