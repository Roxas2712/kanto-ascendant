-- Read-only inventory for the 16 released Hidden Evolution maps.
-- Run from gen1recomp with KA_HEVO_MOD pointing at the packaged/source root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Data = require("src.core.Data")
Data:load()
local root = assert(os.getenv("KA_HEVO_MOD"), "KA_HEVO_MOD required")
local T = require("tests.modkit")
local sdkRoot = root:sub(1, 1) == "/" and "/" or "."
local run = T.sdk.loadMod(root, { data = Data, root = sdkRoot })
assert(#run.errors == 0, table.concat(run.errors, "\n"))

local ids = {
  "KA_HEVO_TUNNEL_ALL",
  "KA_HEVO_RED_UPPER", "KA_HEVO_RED_ABYSS", "KA_HEVO_RED_RECOVERY",
  "KA_HEVO_RED_LOWER", "KA_HEVO_RED_SHRINE",
  "KA_HEVO_BLUE_FROST_THRESHOLD", "KA_HEVO_BLUE_FROST_HALL",
  "KA_HEVO_BLUE_GLACIER_MAZE", "KA_HEVO_BLUE_TIDAL_DEPTHS",
  "KA_HEVO_BLUE_KYOGRE_SHRINE",
  "KA_HEVO_SHARED_SEALED_ANTECHAMBER",
  "KA_HEVO_GREEN_THRESHOLD", "KA_HEVO_GREEN_GROVE",
  "KA_HEVO_GREEN_MIST", "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
}
local RuntimeMap = require("src.world.Map")
local cavernLadderCells = {
  [61]={{1,1}}, [62]={{1,1}}, [97]={{1,0}}, [98]={{1,1}},
  [124]={{1,1}}, [127]={{0,1}},
}

for _, id in ipairs(ids) do
  local map = assert(Data.maps[id], id)
  local ladders, functional, statues, items, visible = 0, 0, 0, 0, 0
  if map.tileset == "CAVERN" then
    local runtime = RuntimeMap.new(map, assert(Data.tilesets.CAVERN))
    for by=0,map.height-1 do for bx=0,map.width-1 do
      local block = map.blocks[by*map.width+bx+1]
      for _, cell in ipairs(cavernLadderCells[block] or {}) do
        local x, y = bx*2+cell[1], by*2+cell[2]
        ladders = ladders + 1
        if runtime:warpAtCell(x,y) then functional = functional + 1 end
      end
    end end
  end
  for _, object in ipairs(map.objects or {}) do
    if object.renderMode ~= "none" then visible = visible + 1 end
    if object.sprite == "SPRITE_KA_HEVO_QUIZ_STATUE"
        and object.semanticRole == "quiz_statue" then
      statues = statues + 1
    elseif object.sprite == "SPRITE_POKE_BALL" then
      items = items + 1
    end
  end
  print(("MAP\t%s\tsong=%s\ttileset=%s\twarps=%d\tobjects=%d\tvisible=%d\tstatues=%d\titems=%d\tladders=%d/%d"):format(
    id, tostring(Data.audio.mapSongs[id]), tostring(map.tileset),
    #(map.warps or {}), #(map.objects or {}), visible, statues, items,
    functional, ladders))
  for _, object in ipairs(map.objects or {}) do
    print(("OBJECT\t%s\t%s\tsprite=%s\tx=%s\ty=%s\ttext=%s\trender=%s"):format(
      id, tostring(object.name), tostring(object.sprite), tostring(object.x),
      tostring(object.y), tostring(object.text), tostring(object.renderMode)))
  end
end

run.release()
