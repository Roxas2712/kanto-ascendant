-- Localized correction of a sheet mapping, never a sex/form data swap.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-MEOWSTIC-FRONT',selected={},pending={}}
  local picked=opts.selected
  local row=opts.art['dex:678']
  local old='assets/backend_national_catalog_67/battle/678/'
  local names={front='front.png',frontShiny='frontShiny.png',voxelFront='voxel-front.png',
    voxelFrontShiny='voxel-frontShiny.png',icon='icon-normal.png',iconShiny='icon-shiny.png',
    back='back.png',backShiny='backShiny.png'}
  local valid=row and row.key=='dex:678' and row.paths and not row.animations
    and picked and picked.key=='dex:678' and picked.paths
  for side,name in pairs(names)do
    local path=valid and picked.paths[side]
    local bytes=type(path)=='string' and mod:read(path)
    local base=side:gsub('Shiny$','')
    local size=base=='icon' and 16 or base=='voxelFront' and 64 or base=='back' and 48 or 56
    local expected='assets/wave1_meowstic_front_67/'..base..'-'
      ..(side:find('Shiny',1,true) and 'shiny' or 'normal')..'.png'
    valid=valid and row.paths[side]==old..name and path==expected
      and type(bytes)=='string' and bytes:sub(1,8)=='\137PNG\r\n\26\n'
      and bytes:sub(13,24)=='IHDR'..string.char(0,0,0,size,0,0,0,size)
  end
  if not valid then C.pending[1]='missing_or_changed_male_source';return C end
  for side in pairs(names)do row.paths[side]=picked.paths[side]end
  C.selected[1]='dex:678'
  return C
end
