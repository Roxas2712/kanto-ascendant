-- Exact correction of three misidentified/mixed-colour base art rows.
-- Atomic family staging: no form registration or protected sprite replacement.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-RED-FLOWER-ART',selected={},pending={}}
  local staged={}
  for _,dex in ipairs({669,670,671})do
    local key='dex:'..dex
    local row,selection=opts.art[key],opts.selected[tostring(dex)]
    local valid=row and row.key==key and row.paths and row.animations==nil
      and selection and selection.key==key and selection.paths and selection.animations
    local paths,animations={},{}
    for _,side in ipairs({'front','back','voxel'})do
      for _,variant in ipairs({'normal','shiny'})do
        local suffix=variant=='shiny' and 'Shiny' or ''
        local name=side..suffix
        local pathKey=side=='voxel' and 'voxelFront'..suffix or name
        local oldName=side=='voxel' and 'voxel-front'..suffix or name
        local picked=valid and selection.animations[name]
        local root='assets/wave1_red_flowers_67/'..dex..'/'..side..'/'..variant
        valid=valid and row.paths[pathKey]=='assets/backend_national_catalog_67/battle/'..dex..'/'..oldName..'.png'
          and type(picked)=='table' and picked.root==root
          and type(picked.durations)=='table' and #picked.durations>0
          and picked.scale==(side=='voxel' and 1.5 or 1)
          and picked.animated==(side~='back') and selection.paths[pathKey]==root..'/001.png'
        local first,moving,times=nil,false,{}
        if valid then
          local size=side=='back' and 48 or side=='voxel' and 64 or 56
          for i,ms in ipairs(picked.durations)do
            local raw=mod:read(('%s/%03d.png'):format(root,i))
            valid=valid and type(ms)=='number' and ms==ms and ms>0 and ms<math.huge
              and type(raw)=='string' and raw:sub(1,8)=='\137PNG\r\n\26\n'
              and raw:sub(13,24)=='IHDR'..string.char(0,0,0,size,0,0,0,size)
            if not valid then break end
            if first and first~=raw then moving=true end
            first=first or raw;times[i]=ms
          end
          valid=valid and (side=='back' and #times==1 or side~='back' and moving)
        end
        if valid then
          paths[pathKey]=root..'/001.png'
          animations[name]={root=root,durations=times,scale=picked.scale,animated=picked.animated}
        end
      end
    end
    if not valid then C.pending[1]={key=key,reason='missing_or_changed_red_flower_source'};return C end
    staged[#staged+1]={row=row,paths=paths,animations=animations,key=key}
  end
  for _,entry in ipairs(staged)do
    for side,path in pairs(entry.paths)do entry.row.paths[side]=path end
    entry.row.animations=entry.animations
    C.selected[#C.selected+1]=entry.key
  end
  return C
end
