-- Fill only the three missing authored shiny lanes of this exact base row.
return function(mod,opts)
  local C={CARD_ID='KASC-WAVE1-VESPIQUEN-SHINY',selected={},pending={}}
  local row=opts.art['dex:416']
  local source='assets/neo_crystal_2d_67/authored/pokewilds/416/'
  local target='assets/wave1_vespiquen_shiny_67/'
  local valid=row and row.key=='dex:416' and type(row.animations)=='table'
  for _,side in ipairs({'front','back','voxel'})do
    local normal=valid and row.animations[side]
    local shiny=opts.selected[side..'Shiny']
    valid=valid and type(normal)=='table' and normal.root==source..side..'/normal'
      and type(normal.durations)=='table' and #normal.durations>0
      and row.animations[side..'Shiny']==nil and type(shiny)=='table'
      and shiny.root==target..side..'/shiny' and shiny.scale==normal.scale
      and type(shiny.durations)=='table' and #shiny.durations==#normal.durations
      and shiny.animated==normal.animated
    if valid then
      local size=side=='back' and 48 or side=='voxel' and 64 or 56
      for i,time in ipairs(normal.durations)do
        local raw=mod:read(('%s/%03d.png'):format(shiny.root,i))
        valid=valid and shiny.durations[i]==time and type(raw)=='string'
          and raw:sub(1,8)=='\137PNG\r\n\26\n'
          and raw:sub(13,24)=='IHDR'..string.char(0,0,0,size,0,0,0,size)
      end
    end
  end
  if valid then
    for _,side in ipairs({'frontShiny','backShiny','voxelShiny'})do
      local p=opts.selected[side];local durations={}
      for i,t in ipairs(p.durations)do durations[i]=t end
      row.animations[side]={root=p.root,durations=durations,animated=p.animated,scale=p.scale}
    end
    C.selected[1]='dex:416'
  else C.pending[1]={key='dex:416',reason='missing_or_changed_source'} end
  return C
end
