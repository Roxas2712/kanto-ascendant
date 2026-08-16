-- Full-runtime registry contract for HEVO quiz statues versus floor lights.
-- Run from an exact gen1recomp authority with KA_HIDDEN_EVOLUTION_MOD set.
package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = require("src.core.Data")
Data:load()

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local modName = root:gsub("/+$", ""):match("[^/]+$")
local modPrefix = "mods/" .. modName
local FsIo = require("tests.fs_io")
local disk, memory = FsIo.new("/"), {}
local function mapped(path)
  if path == modPrefix then return root end
  if path:sub(1, #modPrefix + 1) == modPrefix .. "/" then
    return root .. path:sub(#modPrefix + 1)
  end
end
local function memoryItems(path)
  local prefix, seen, out = path .. "/", {}, {}
  for key in pairs(memory) do
    if key:sub(1, #prefix) == prefix then
      local child = key:sub(#prefix + 1):match("^[^/]+")
      if child and not seen[child] then
        seen[child], out[#out + 1] = true, child
      end
    end
  end
  table.sort(out)
  return out
end
local testFs = {
  read=function(path)
    local real=mapped(path); return real and disk.read(real) or memory[path]
  end,
  write=function(path,body)
    assert(not mapped(path), "quiz-statue test tried to write mod source")
    memory[path]=body; return true
  end,
  remove=function(path)
    assert(not mapped(path), "quiz-statue test tried to remove mod source")
    memory[path]=nil; return true
  end,
  createDirectory=function() return true end,
  load=function(path)
    local real=mapped(path)
    if real then return disk.load(real) end
    local body=memory[path]
    if not body then return nil,"no file: "..tostring(path) end
    return (loadstring or load)(body,path)
  end,
  getInfo=function(path)
    if path=="mods" then return {type="directory"} end
    local real=mapped(path)
    if real then return disk.getInfo(real) end
    if memory[path]~=nil then return {type="file"} end
    return #memoryItems(path)>0 and {type="directory"} or nil
  end,
  getDirectoryItems=function(path)
    if path=="mods" then return {modName} end
    local real=mapped(path)
    return real and disk.getDirectoryItems(real) or memoryItems(path)
  end,
}
local run = T.sdk.loadMod(root, { data = Data, fs = testFs })
T.eq(#run.errors, 0, "Kanto Ascendant loads for the quiz-statue contract")

local QUIZ = "SPRITE_KA_HEVO_QUIZ_STATUE"
local LIGHT = "SPRITE_KA_EVOLUTION_RELIC"
local expected = {
  KA_RED_STATUE_1={"KA_HEVO_RED_UPPER",3,6,"RED"},
  KA_RED_STATUE_2={"KA_HEVO_RED_UPPER",29,4,"RED"},
  KA_RED_STATUE_3={"KA_HEVO_RED_ABYSS",11,4,"RED"},
  KA_RED_STATUE_4={"KA_HEVO_RED_ABYSS",27,10,"RED"},
  KA_RED_STATUE_5={"KA_HEVO_RED_LOWER",5,6,"RED"},
  KA_HEVO_BLUE_STATUE_HALL={"KA_HEVO_BLUE_FROST_HALL",25,22,"BLUE"},
  KA_HEVO_BLUE_STATUE_ICE_NORTH={"KA_HEVO_BLUE_GLACIER_MAZE",11,5,"BLUE"},
  KA_HEVO_BLUE_STATUE_ICE_DEEP={"KA_HEVO_BLUE_GLACIER_MAZE",37,31,"BLUE"},
  KA_HEVO_BLUE_STATUE_DEPTHS_WEST={"KA_HEVO_BLUE_TIDAL_DEPTHS",3,19,"BLUE"},
  KA_HEVO_BLUE_STATUE_DEPTHS_EAST={"KA_HEVO_BLUE_TIDAL_DEPTHS",47,9,"BLUE"},
  KA_GREEN_STATUE_1={"KA_HEVO_GREEN_GROVE",21,35,"GREEN"},
  KA_GREEN_STATUE_2={"KA_HEVO_GREEN_GROVE",55,17,"GREEN"},
  KA_GREEN_STATUE_3={"KA_HEVO_GREEN_MIST",5,25,"GREEN"},
  KA_GREEN_STATUE_4={"KA_HEVO_GREEN_MIST",45,21,"GREEN"},
  KA_GREEN_STATUE_5={"KA_HEVO_GREEN_MIST",39,35,"GREEN"},
}

local quizCount, lightCount = 0, 0
local heroCount = { RED=0, BLUE=0, GREEN=0 }
local seen = {}
for mapId, map in pairs(Data.maps) do
  for _, object in ipairs(type(map.objects)=="table" and map.objects or {}) do
    local row = expected[object.name]
    if row then
      T.eq(mapId, row[1], object.name .. " map remains stable")
      T.eq(object.x, row[2], object.name .. " x remains stable")
      T.eq(object.y, row[3], object.name .. " y remains stable")
      T.eq(object.sprite, QUIZ, object.name .. " uses the quiz statue")
      T.eq(object.semanticRole, "quiz_statue",
        object.name .. " owns only the quiz role")
      T.check(object.passable ~= true, object.name .. " remains solid")
      T.check(not seen[object.name], object.name .. " is registered once")
      seen[object.name] = true
      quizCount = quizCount + 1
      heroCount[row[4]] = heroCount[row[4]] + 1
    elseif object.semanticRole == "quiz_statue" or object.sprite == QUIZ then
      error(("unexpected quiz-statue owner %s on %s"):format(
        tostring(object.name), tostring(mapId)))
    end

    if object.semanticRole == "floor_light" then
      T.eq(object.sprite, LIGHT, object.name .. " remains a yellow light relic")
      T.eq(object.passable, false, object.name .. " remains a solid light")
      T.check(expected[object.name] == nil,
        object.name .. " cannot be both a quiz statue and floor light")
      lightCount = lightCount + 1
    elseif object.sprite == LIGHT then
      error(("relic sprite leaked outside floor lights: %s on %s"):format(
        tostring(object.name), tostring(mapId)))
    end
  end
end

for name in pairs(expected) do
  T.check(seen[name], name .. " exists in the live registry")
end
T.eq(quizCount, 15, "exactly fifteen quiz statues use the new sprite")
T.eq(heroCount.RED, 5, "RED owns five quiz statues")
T.eq(heroCount.BLUE, 5, "BLUE owns five quiz statues")
T.eq(heroCount.GREEN, 5, "GREEN owns five quiz statues")
T.eq(lightCount, 30, "exactly thirty floor lights keep the yellow relic")

local sprite = assert(Data.sprites[QUIZ], "quiz sprite is registered")
T.eq(sprite.image, "assets/generated/hidden_evolution/quiz_statue.png",
  "quiz sprite resolves only through the local derived cache")
T.eq(sprite.frames, 1, "quiz statue is one static frame")
T.eq(sprite.walker, false, "quiz statue never walks or turns")
T.eq(sprite.trueColor, true, "quiz statue preserves its derived grey palette")

T.finish("hidden_evolution_quiz_statue_contract_test")
