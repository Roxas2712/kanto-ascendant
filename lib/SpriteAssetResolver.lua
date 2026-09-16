-- Resolve only catalog-verified mounted data. Mod scripts stay on the original loader.
local M={}
function M.install(mod,store,cache,fs,graphics,imageApi,Assets,owner)
  owner=owner or 'vasc'
  assert(owner=='vasc' or owner=='kasc')
  local before={read=mod.read,info=mod.info,image=mod.image};local textures,placeholders={},{};local active=true;local restoreAssets
  local function known(path)
    return active and type(path)=='string' and store.files[owner..':'..path]~=nil
  end
  local function read(path)
    local key,err=store:materialize(owner,path)
    if not key then return nil,err end
    return cache:read(key)
  end
  local function pixels(path)
    local raw=assert(read(path),'verified sprite unavailable')
    local data=fs.newFileData(raw,'verified-sprite.png')
    local ok,result=pcall(imageApi.newImageData,data)
    if data.release then data:release()end
    assert(ok,result);return result
  end
  local function image(path)
    if not textures[path] then
      local data=pixels(path);local ok,result=pcall(graphics.newImage,data)
      if data.release then data:release()end
      assert(ok,result);textures[path]=result
    end
    return textures[path]
  end
  local function missing(path)
    local optional=mod.exports and mod.exports.optionalPokemonAssets
    if not active or known(path)or not optional or type(optional.metadata)~='function'then return nil end
    local meta=optional.metadata(path)
    if not meta or before.info and before.info(mod,path)then return nil end
    return meta
  end
  local function placeholderPixels(meta)
    -- Presentation only: preserve the declared sheet dimensions for crop/UV
    -- readers. No PNG bytes, file info or installed marker are fabricated.
    local w,h=meta.width,meta.height
    local data=imageApi.newImageData(w,h)
    local scale=math.max(1,math.floor(math.min(w/15,h/11)))
    local ox,oy=math.floor((w-15*scale)/2),math.floor((h-11*scale)/2)
    local function dot(x,y)
      for dy=0,scale-1 do for dx=0,scale-1 do
        local px,py=ox+x*scale+dx,oy+y*scale+dy
        if px>=0 and py>=0 and px<w and py<h then data:setPixel(px,py,.35,.65,1,1)end
      end end
    end
    -- Original tiny DLC lettering with a download arrow, not a species image.
    local glyphs={'110','101','101','101','110','100','100','100','100','111','111','100','100','100','111'}
    for letter=0,2 do for y=0,4 do
      local row=glyphs[letter*5+y+1]
      for x=0,2 do if row:sub(x+1,x+1)=='1'then dot(2+letter*4+x,y)end end
    end end
    for y=6,9 do dot(7,y)end
    for x=0,2 do dot(5+x,8+x);dot(9-x,8+x)end
    return data
  end
  local function placeholder(meta)
    local key=meta.width..'x'..meta.height
    if not placeholders[key]then
      local data=placeholderPixels(meta);local ok,result=pcall(graphics.newImage,data)
      if data.release then data:release()end
      assert(ok,result);placeholders[key]=result
    end
    return placeholders[key]
  end
  function mod:read(path)if known(path)then return read(path)end;return before.read(self,path)end
  function mod:info(path)
    local f=active and store.files[owner..':'..tostring(path)]
    if f then return {type='file',size=f.bytes}end
    return before.info and before.info(self,path)
  end
  function mod:image(path,...)
    if known(path) then return image(path)end
    local meta=missing(path);if meta then return placeholder(meta)end
    return before.image(self,path,...)
  end
  if Assets then
    local priorImage,priorData=Assets.image,Assets.imageData
    local prefix=mod.path:gsub('/$','')..'/'
    local function relative(path)
      if type(path)=='string' and path:sub(1,#prefix)==prefix then return path:sub(#prefix+1)end
    end
    local wrappedImage=function(path,...)
      local rel=relative(path)
      if rel then if known(rel)then return image(rel)end;local meta=missing(rel);if meta then return placeholder(meta)end end
      return priorImage(path,...)
    end
    local wrappedData=function(path,...)
      local rel=relative(path)
      if rel then if known(rel)then return pixels(rel)end;local meta=missing(rel);if meta then return placeholderPixels(meta)end end
      return priorData(path,...)
    end
    Assets.image,Assets.imageData=wrappedImage,wrappedData
    restoreAssets=function()
      if Assets.image==wrappedImage then Assets.image=priorImage end
      if Assets.imageData==wrappedData then Assets.imageData=priorData end
    end
  end
  local function close()
    if not active then return end;active=false
    for _,texture in pairs(textures)do if texture.release then pcall(texture.release,texture)end end
    for _,texture in pairs(placeholders)do if texture.release then pcall(texture.release,texture)end end
    textures={};placeholders={};if restoreAssets then restoreAssets()end
  end
  if Assets and Assets.register then Assets.register{invalidate=function()textures={}end,release=close}end
  return {read=read,installed=function(path)return known(path)end,close=close}
end
return M
