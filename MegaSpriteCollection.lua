-- Restore approved front animations that were shortened in the 6.7 source.
-- Existing explicit collection preferences remain readable for compatibility.
local M={}
function M.new(mod,data,currentData)
 local self={data=data,frontRepairs={}}
 for id,row in pairs(data.forms)do
  local current=currentData and currentData[id]
  if current and current.front and row.timings.front
   and #(row.timings.front.normal or {})>#(current.front.normal or {})
   and #(row.timings.front.shiny or {})>#(current.front.shiny or {})then
   self.frontRepairs[id]=true
  end
 end
 function self:selected()
  return mod.options:get('mega_sprite_collection')==data.id and data.id or 'current'
 end
 local function info(path)
  local held=mod.info and mod:info(path)
  return held and held.type=='file'
 end
 function self:entry(profile,side)
  if not profile then return nil end
  if self:selected()~=data.id and (not self.frontRepairs[profile.id]or side~='front')then return nil end
  local row=data.forms[profile.id]
  if not row or row.asset~=profile.asset then return nil end
  if not info(data.root..'mega_animated_runtime/'..row.asset..'/front/normal/001.png')then return nil end
  return row
 end
 function self:timings(profile,current)
  local row=self:entry(profile,'front')
  if not row then return current end
  if self:selected()==data.id then return row.timings end
  local result={};for key,value in pairs(current or {})do result[key]=value end
  result.front=row.timings.front
  return result
 end
 function self:path(profile,variant,frame,side,master)
  side=side or 'front';frame=tonumber(frame)or 1
  local row=self:entry(profile,side);if not row then return nil end
  local times=row.timings[side]and row.timings[side][variant]
  if not times or frame<1 or frame%1~=0 or frame>#times then return nil end
  local path=data.root..(master and 'mega_animated/'or 'mega_animated_runtime/')..row.asset..'/'..side..'/'..variant..('/%03d.png'):format(frame)
  return info(path)and path or nil
 end
 function self:select(game,id)
  if id~='current' and id~=data.id then return false,'unknown_collection'end
  local exports=game.mods and game.mods.exports
  local vasc=exports and exports.VOXEL_ASCENDANT
  local content=vasc and vasc.ascendantContent or mod.exports and mod.exports.ascendantContent
  if content and not content:allowSetting('mega_sprite_collection',id,game)then return false,'sprite_download_required'end
  game.save.options=game.save.options or {};local options=game.save.options
  options.modOptions=options.modOptions or {};options.modOptions[mod.id]=options.modOptions[mod.id]or {}
  options.modOptions[mod.id].mega_sprite_collection=id
  if game.mods then
   game.mods.modOptions=game.mods.modOptions or {};game.mods.modOptions[mod.id]=game.mods.modOptions[mod.id]or {}
   game.mods.modOptions[mod.id].mega_sprite_collection=id
  end
  if game.writeOptions then game:writeOptions()end
  return true
 end
 return self
end
return M
