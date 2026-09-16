-- Reviewed per-species artwork, selected before either renderer is built.
-- Existing files remain available for rollback; this module owns no species.
return function(mod, data)
  data=type(data)=='table' and data or {}
  local C={selected={},pending={},entries={}}
  local function copy(v)
    if type(v)~='table' then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  local function png(path,size)
    if type(path)~='string' or not path:match('^assets/sprite_repair_67/')
        or path:find('..',1,true) or path:find('\\',1,true)then return false end
    local raw=mod:read(path)
    if type(raw)~='string' or #raw<24 or raw:sub(1,8)~='\137PNG\r\n\26\n'
        or raw:sub(13,16)~='IHDR'then return false end
    local function uint(at)local a,b,c,d=raw:byte(at,at+3);return a*16777216+b*65536+c*256+d end
    return uint(17)==size and uint(21)==size
  end
  local function pose(row,size)
    if type(row)~='table' or type(row.root)~='string' or type(row.durations)~='table'
        or #row.durations==0 then return false end
    for i,ms in ipairs(row.durations)do
      if type(ms)~='number' or ms<=0 or ms~=ms or ms==math.huge
          or not png(row.root..('/%03d.png'):format(i),size)then return false end
    end
    return true
  end
  for key,row in pairs(data.entries or {})do
    local dex=tonumber(key)
    local base=dex and dex%1==0 and dex>251 and dex<=1025
    local form=dex and dex%1==0 and dex>=10000 and dex<20000 and type(row)=='table'
      and row.catalogKey=='form:'..dex and type(row.nationalDex)=='number'
      and row.nationalDex>251 and row.nationalDex<=1025 and not next(row.legacy or {})
    local ok=(base or form)
      and type(row)=='table' and type(row.pixel)=='table' and type(row.native)=='table'
    if ok then
      for _,side in ipairs({'front','back'})do
        if row.pixel[side] or row.pixel[side..'Shiny']then
          local size=side=='front' and 56 or 48
          ok=ok and png(row.pixel[side],size) and png(row.pixel[side..'Shiny'],size)
            and pose(row.native[side],size) and pose(row.native[side..'Shiny'],size)
        end
      end
      if row.pixel.front then
        local size=row.voxelSize or 64
        ok=ok and (size==64 or size==96) and type(row.fallback)=='table'
          and png(row.fallback.front,size) and png(row.fallback.frontShiny,size)
        if row.voxel then
          ok=ok and type(row.voxel.variants)=='table'
          for _,variant in ipairs({'normal','shiny'})do
            local v=row.voxel.variants and row.voxel.variants[variant]
            ok=ok and pose(v,size) and #v.durations>1
          end
        end
      end
    end
    if ok then C.entries[tostring(dex)]=copy(row);C.selected[#C.selected+1]=dex
    else C.pending[#C.pending+1]={dex=dex,reason='invalid_or_missing_art_pair'}end
  end
  table.sort(C.selected)
  function C.legacy(base,surface)
    local out={};for k,v in pairs(base or {})do out[k]=v end
    for dex,row in pairs(C.entries)do
      local selected=row[surface]
      if selected~=nil then
        for runtime,species in pairs(row.legacy or {})do
          local key=base and base[runtime] and runtime or tonumber(runtime)
          local old=base and base[key]
          local safe=type(species)=='string' and species~='GOROCHU' and not species:find('MEGA',1,true)
            and species~='ZYGARDE_10' and (not old or old.species==species
              and tonumber(old.sourceDex)==tonumber(dex))
          if safe and (old or (surface=='voxel' or surface=='native') and selected)then
            if selected==false then out[key]=nil
            else
              local merged=copy(old or {sourceDex=tonumber(dex),species=species})
              for k,v in pairs(selected)do merged[k]=copy(v)end
              if surface=='voxel' then
                merged.variants=copy(selected.variants)
                for k,v in pairs(merged.variants.normal)do merged[k]=copy(v)end
              end
              out[key]=merged
            end
          end
        end
      end
    end
    return out
  end
  function C.backend(base)
    local out={};for k,v in pairs(base or {})do out[k]=v end
    for dex,row in pairs(C.entries)do
      local key=row.catalogKey or 'dex:'..dex;local old=base[key]
      if old and old.key==key and type(old.paths)=='table'then
        local r=copy(old);r.animations=r.animations or {}
        for _,side in ipairs({'front','frontShiny','back','backShiny'})do
          if row.pixel[side]then r.paths[side]=row.pixel[side];r.animations[side]=copy(row.native[side])end
        end
        if row.pixel.front then
          r.paths.voxelFront=row.fallback.front;r.paths.voxelFrontShiny=row.fallback.frontShiny
          r.voxelSize=row.voxelSize or 64;r.voxelScale=row.fallback.scale
          r.animations.voxel=row.voxel and copy(row.voxel.variants.normal) or nil
          r.animations.voxelShiny=row.voxel and copy(row.voxel.variants.shiny) or nil
        end
        out[key]=r
      end
    end
    return out
  end
  return C
end
