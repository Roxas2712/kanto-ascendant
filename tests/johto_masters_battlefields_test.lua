local engine = assert(os.getenv("GEN1RECOMP_DIR"), "GEN1RECOMP_DIR required")
package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path

local Data = require("src.core.Data")
local Map = require("src.world.Map")
Data:load()

local makePassages = assert(loadfile("johto_masters_passages.lua"))()
local makeTilesets = assert(loadfile("johto_masters_tilesets.lua"))()

local function registry()
  local values = {}
  return {
    values = values,
    register = function(_, id, value)
      assert(not values[id], "duplicate registration: " .. id)
      values[id] = value
    end,
  }
end

local maps, sprites, trainers, scripts, tilesets =
  registry(), registry(), registry(), registry(), registry()
function tilesets:get(id) return self.values[id] or Data.tilesets[id] end

local state = { activeRun = true, runSerial = 0, challengeAttempt = 0, passages = {
  silver = { status = "entered", clue = true, step = 3, puzzle = true,
    quizVersion = 3, quizRunSerial = 0, quizAttempt = 0,
    quizSolved = { true, true, true } },
  kris = { status = "entered", clue = true, step = 3, puzzle = true,
    quizVersion = 3, quizRunSerial = 0, quizAttempt = 0,
    quizSolved = { true, true, true } },
  gold = { status = "entered", clue = true, step = 3, puzzle = true,
    quizVersion = 3, quizRunSerial = 0, quizAttempt = 0,
    quizSolved = { true, true, true } },
} }
local baseline = {
  state = function() return state end,
  syncCadence = function() return state end,
  eligible = function() return true end,
  teamFor = function() return { { species = "TYRANITAR", level = 100 } } end,
  trainerFor = function(key) return { name = key:upper() } end,
  completeRun = function() return "done" end,
}
local postgame = {
  newForcedBattle = function()
    return { trainer = {} }
  end,
}

local warped
local mod = {
  path = ".",
  content = {
    maps = maps, sprites = sprites, trainers = trainers,
    map_scripts = scripts, tilesets = tilesets,
  },
  save = {
    get = function() return state end,
    set = function(_, _, nextState) state = nextState end,
  },
  world = {
    warpTo = function(_, id, x, y, facing)
      warped = { id = id, x = x, y = y, facing = facing }
      return true
    end,
  },
}
function mod:read(path)
  local file = assert(io.open(path, "rb"))
  local raw = file:read("*a")
  file:close()
  return raw
end

local passages = makePassages(mod, {
  baseline = baseline,
  postgame = postgame,
  contentEnabled = true,
  tilesetFactory = makeTilesets,
})
assert(passages.register())

local expected = {
  silver = {
    id = "KA_JOHTO_SILVER_FINALE", source = "BRUNOS_ROOM",
    field = "SILVER_FINALE", palette = "CAVE",
    sprite = "SPRITE_KA_JOHTO_SILVER",
  },
  kris = {
    id = "KA_JOHTO_KRIS_FINALE", source = "AGATHAS_ROOM",
    field = "KRIS_FINALE", palette = "GRAYMON",
    sprite = "SPRITE_KA_JOHTO_KRIS",
  },
  gold = {
    id = "KA_JOHTO_GOLD_FINALE", source = "CHAMPIONS_ROOM",
    field = "GOLD_FINALE", palette = "INDIGO",
    sprite = "SPRITE_KA_JOHTO_GOLD",
  },
}

local directions = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
local function routeToMaster(map, entryX, entryY, master)
  local queue, seen = { { entryX, entryY } }, {}
  local head, count = 1, 0
  while queue[head] do
    local point = queue[head]
    head = head + 1
    local tag = point[1] .. ":" .. point[2]
    if not seen[tag] then
      seen[tag] = true
      count = count + 1
      if math.abs(point[1] - master.x) + math.abs(point[2] - master.y) == 1 then
        return true, count
      end
      for _, delta in ipairs(directions) do
        local x, y = point[1] + delta[1], point[2] + delta[2]
        local nextTag = x .. ":" .. y
        if not seen[nextTag] and map:inBounds(x, y)
          and map:isWalkableCell(x, y)
          and not (x == master.x and y == master.y) then
          queue[#queue + 1] = { x, y }
        end
      end
    end
  end
  return false, count
end

local signatures = {}
for key, row in pairs(expected) do
  local authority = assert(Data.maps[row.source], "missing Indigo authority " .. row.source)
  local spec = assert(passages.MAPS[row.field])
  local def = assert(maps.values[row.id])
  assert(spec.arenaRole == "johto_master_battlefield")
  assert(spec.arenaSource == row.source)
  assert(def.width == authority.width and def.height == authority.height,
    row.id .. " is not the authority battlefield size")
  assert(def.tileset == authority.tileset and def.borderBlock == authority.borderBlock,
    row.id .. " is not using the authority tileset/border contract")
  assert(def.palette == row.palette and def.voxelMode == "MAP_STUDIO"
    and def.outdoor == false, row.id .. " renderer contract")
  assert(#def.blocks == #authority.blocks)
  for index, value in ipairs(authority.blocks) do
    assert(def.blocks[index] == value,
      ("%s differs from %s at block %d"):format(row.id, row.source, index))
  end
  local signature = def.tileset .. ":" .. def.width .. "x" .. def.height
    .. ":" .. table.concat(def.blocks, ",")
  assert(not signatures[signature], row.id .. " duplicates another Johto arena")
  signatures[signature] = row.id

  local map = Map.new(def, assert(Data.tilesets[def.tileset]))
  assert(map:inBounds(spec.entryX, spec.entryY)
    and map:isWalkableCell(spec.entryX, spec.entryY), row.id .. " entry is blocked")
  assert(spec.entryFacing == "up" and spec.bossY < spec.entryY
    and math.abs(spec.bossX - spec.entryX) <= 1,
    row.id .. " lacks the directed entrance-to-podium composition")
  assert(#def.warps == 2, row.id .. " needs the Indigo double return threshold")
  for index, warp in ipairs(def.warps) do
    assert(warp.x == spec.entryX + index - 1 and warp.y == def.height * 2 - 1,
      row.id .. " return warp is not aligned below entry")
    assert(warp.destMap == "LAST_MAP" and warp.destWarp == 1,
      row.id .. " return warp changed passage semantics")
    -- Elite Four edge thresholds are coordinate warps on ordinary native
    -- floor, not door/warp-pad tiles.  Preserve that exact collision rule.
    assert(map:isWalkableCell(warp.x, warp.y), row.id .. " return threshold is blocked")
  end

  assert(#def.objects == 1, row.id .. " must contain exactly one Master actor")
  local master = assert(def.objects[1])
  local authorityMaster = assert(authority.objects[1])
  assert(master.x == spec.bossX and master.y == spec.bossY,
    row.id .. " Master is not on the configured trainer focus")
  assert(master.y > authorityMaster.y,
    row.id .. " Master was not lowered from the native room position")
  assert(master.sprite == row.sprite and master.range == "DOWN",
    row.id .. " Master identity/facing contract")
  assert(map:inBounds(master.x, master.y), row.id .. " Master is outside arena")
  local reachable, cells = routeToMaster(map, spec.entryX, spec.entryY, master)
  assert(reachable and cells >= 2, row.id .. " has no collision-valid approach to its Master")

  assert(passages.solve({}, key), row.id .. " solved passage did not enter arena")
  assert(warped.id == row.id and warped.x == spec.entryX and warped.y == spec.entryY
    and warped.facing == "up", row.id .. " runtime entry ignored arena threshold")
end

print("johto_masters_battlefields_test: PASS")
