-- KASC-67-BACKEND-GIFT-SPECIES: append-only art registration contract.
-- Pure validation/staging. Never replace an existing renderer's species/slot.
return function(current,payload)
  if type(payload)~='table' or payload.schema~='kasc.backend-gift-art/v1'
      or type(payload.entries)~='table' then return nil,'invalid_schema' end
  local function clone(v)
    if type(v)~='table' then return v end
    local result={};for k,x in pairs(v)do result[k]=clone(x)end;return result
  end
  local function shallow(v)
    local result={};for k,x in pairs(v or {})do result[k]=x end;return result
  end
  local function get(v,dex)return v and (v[dex] or v[tostring(dex)])end
  local function png(path,size)
    if type(path)~='string' or path:sub(1,7)~='assets/'
        or path:find('..',1,true) or path:find('\\',1,true) then return nil end
    local raw=current.read(path)
    if raw==nil and current.optionalImageMetadata then
      local meta=current.optionalImageMetadata(path)
      if meta and meta.width==size and meta.height==size then
        return "sha256:"..meta.sha256
      end
      return nil
    end
    if type(raw)~='string' or raw:sub(1,8)~='\137PNG\r\n\26\n'
        or raw:sub(13,16)~='IHDR' or #raw<24 then return nil end
    local function int(at)
      local a,b,c,d=raw:byte(at,at+3)
      return a*16777216+b*65536+c*256+d
    end
    if int(17)~=size or int(21)~=size then return nil end
    -- Compare content identities consistently if some frames are already present.
    return current.optionalImageHash and ("sha256:"..current.optionalImageHash(raw)) or raw
  end
  local function pose(value,size,requireMotion)
    if type(value)~='table' or type(value.root)~='string'
        or type(value.durations)~='table' or #value.durations<1 then return false end
    local first,moving
    for frame,ms in ipairs(value.durations)do
      if type(ms)~='number' or ms<=0 or ms~=ms or ms==math.huge then return false end
      local bytes=png(value.root..('/%03d.png'):format(frame),size)
      if not bytes then return false end
      if first and bytes~=first then moving=true end
      first=first or bytes
    end
    if #value.durations>1 and not moving then return false end
    if value.animated~=nil and value.animated~=(moving==true) then return false end
    return not requireMotion or moving==true
  end
  local staged={pixel=shallow(current.pixel),native=shallow(current.native),
    voxel=shallow(current.voxel),fallback=shallow(current.fallback),
    guests=shallow(current.guests),species=shallow(current.species),count=0}
  local function occupiedSpecies(species)
    if staged.species[species] then return true end
    for _,map in ipairs({staged.pixel,staged.native,staged.voxel,staged.fallback})do
      for _,row in pairs(map)do if row.species==species then return true end end
    end
    return false
  end
  for key,input in pairs(payload.entries)do
    local dex=tonumber(key)
    if not dex or dex%1~=0 or dex<20000 or dex>99999 then return nil,'protected_slot' end
    if type(input)~='table' or type(input.species)~='string'
        or not input.species:match('^KA_GIFT_[A-Z0-9_]+$') then return nil,'invalid_species' end
    if occupiedSpecies(input.species) then return nil,'species_already_owned' end
    for _,map in ipairs({staged.pixel,staged.native,staged.voxel,staged.fallback,staged.guests})do
      if get(map,dex)~=nil then return nil,'slot_already_owned' end
    end
    local row=clone(input)
    -- Detail-preserving pixel masters opt in explicitly; legacy packages
    -- retain their exact 64px contract. Never infer size from a foreign file.
    local voxelSize=row.voxelSize or 64
    if voxelSize~=64 and voxelSize~=96 then return nil,'invalid_voxel_size' end
    if row.heightM~=nil and (type(row.heightM)~='number' or row.heightM~=row.heightM
        or row.heightM<=0 or row.heightM==math.huge) then
      return nil,'invalid_render_height'
    end
    if type(row.pixel)~='table' or type(row.fallback)~='table' then return nil,'missing_static_sides' end
    for _,side in ipairs({'front','frontShiny','back','backShiny'})do
      if not png(row.pixel[side],side:sub(1,4)=='back' and 48 or 56) then
        return nil,'invalid_static_'..side
      end
    end
    for _,side in ipairs({'front','frontShiny'})do
      if not png(row.fallback[side],voxelSize) then return nil,'invalid_voxel_'..side end
    end
    if row.native then
      if type(row.native)~='table' then return nil,'invalid_native_variants' end
      for _,side in ipairs({'front','frontShiny','back','backShiny'})do
        if row.native[side] and not pose(row.native[side],side:sub(1,4)=='back' and 48 or 56) then
          return nil,'invalid_native_'..side
        end
      end
    end
    if row.voxel then
      if type(row.voxel)~='table' then return nil,'invalid_voxel_variants' end
      if type(row.voxel.variants)~='table' then return nil,'invalid_voxel_variants' end
      for which,value in pairs(row.voxel.variants)do
        if (which~='normal' and which~='shiny') or not pose(value,voxelSize,true) then
          return nil,'invalid_voxel_animation'
        end
      end
    end
    for _,pair in ipairs({{'pixel',row.pixel},{'fallback',row.fallback},
        {'native',row.native},{'voxel',row.voxel}})do
      if pair[2] then
        pair[2].species=row.species
        if pair[1]=='fallback' or pair[1]=='voxel' then
          pair[2].heightM=row.heightM
        end
        staged[pair[1]][tostring(dex)]=pair[2]
      end
    end
    staged.guests[dex]=true;staged.species[row.species]=dex
    staged.count=staged.count+1
  end
  return staged
end
