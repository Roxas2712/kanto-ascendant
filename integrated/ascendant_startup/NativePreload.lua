-- Warm native Gen-2 introduction/start-area textures into the engine's own
-- override-aware cache. Never construct a shadow World or advance Oak's script.
local M={}
local lastSave,paths,cursor
function M.step(game)
 if not game.oakSpeechData then return true end
 if lastSave~=game.save then
  lastSave=game.save;paths={};cursor=1
  local seen={}
  local function add(path)
   if type(path)=='string'and path:match('^assets/generated/.*%.png$')and not seen[path]then
    seen[path]=true;paths[#paths+1]=path
   end
  end
  for _,key in ipairs{'oakPic','playerPic','girlPic','marillPic','shrink1','shrink2'}do add(game.oakSpeechData[key])end
  local data=game.data or{};local save=game.save or{}
  local spawn=data.gen2Landmarks and data.gen2Landmarks.spawns
  spawn=spawn and spawn[save.spawn or 'SPAWN_HOME']
  local id=save.position and save.position.map or(spawn and spawn.map)
  local map=data.gen2Maps and data.gen2Maps[id]
  local tileset=map and data.gen2Tilesets and data.gen2Tilesets[map.tileset]
  add(tileset and tileset.image)
  for _,key in ipairs{'SPRITE_CHRIS','SPRITE_KRIS'}do
   local sprite=data.gen2Sprites and data.gen2Sprites[key];add(sprite and sprite.image)
  end
 end
 local path=paths[cursor]
 if not path then return true end
 require('src.render.Assets').image(path);cursor=cursor+1
 return cursor>#paths
end
return M
