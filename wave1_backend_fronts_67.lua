-- Reviewed static fallback selection. Existing motion/rears/voxel/forms stay owned.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-BACKEND-FRONTS',selected={},pending={}}
  -- The old static 412/413 sources depict different cloaks. Their already
  -- selected Neo motion is the reviewed plant-cloak identity, including
  -- shiny. A single pose remains static in Original; no form is unlocked.
  for _,dex in ipairs({412,413,705})do
    local key='dex:'..dex
    local row=opts.art[key]
    local old='assets/backend_national_catalog_67/battle/'..dex..'/'
    local source=dex==705 and 'lazarus-animations' or 'neo-animations'
    local root='assets/backend_national_catalog_67/'..source..'/'..dex..'/front/'
    local picked={front=root..'normal/001.png',frontShiny=root..'shiny/001.png'}
    local valid=row and row.key==key and row.paths and row.animations
    for _,side in ipairs({'front','frontShiny'})do
      local pose=valid and row.animations[side]
      local bytes=valid and mod:read(picked[side])
      valid=valid and row.paths[side]==old..side..'.png'
        and type(pose)=='table' and type(pose.root)=='string'
        and pose.root..'/001.png'==picked[side]
        and type(bytes)=='string' and bytes:sub(1,8)=='\137PNG\r\n\26\n'
        and bytes:sub(13,24)=='IHDR'..string.char(0,0,0,56,0,0,0,56)
    end
    if valid then
      row.paths.front=picked.front;row.paths.frontShiny=picked.frontShiny
      C.selected[#C.selected+1]=key
    else C.pending[#C.pending+1]={key=key,reason='missing_or_changed_source'}end
  end
  return C
end
