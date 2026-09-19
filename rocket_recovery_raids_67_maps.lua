-- Rocket Recovery owns isolated, removable raid instances. Each instance is
-- cloned from the named stock map by the content adapter; the stock map itself
-- is never patched or temporarily mutated.

local M={
  schema="kanto-ascendant-rocket-raid-instances/v3",
  ORDER={"celadon_relay","lavender_relay","cerulean_relay",
    "viridian_command"},
  instancePrefix="KA_ROCKET_",
}

-- `start` and `returnPoint` are walkable cells in the original floor. The
-- clone has no warps or connections: upper floors and ordinary exits are
-- physically absent from the raid contract. Every terminal path uses
-- returnPoint on the untouched stock host.
M.rows={
  {id="celadon_relay",map="KA_ROCKET_SILPH_RELAY_1F",index=1991,
    hostMap="SILPH_CO_1F",entranceMap="SAFFRON_CITY",start={10,16},returnPoint={10,16},
    guards={{13,14},{18,12}},boss={23,10}},
  {id="lavender_relay",map="KA_ROCKET_TOWER_RELAY_1F",index=1992,
    hostMap="POKEMON_TOWER_1F",entranceMap="LAVENDER_TOWN",start={10,16},returnPoint={10,16},
    guards={{5,13},{12,11}},boss={17,9}},
  {id="cerulean_relay",map="KA_ROCKET_CERULEAN_RELAY_1F",index=1993,
    hostMap="CERULEAN_CAVE_1F",entranceMap="CERULEAN_CITY",start={24,16},returnPoint={24,16},
    -- Cerulean Cave 1F is split into pockets joined only through upper
    -- floors. The one-floor clone remains in the real entrance pocket.
    guards={{21,13},{22,10},{25,8}},boss={23,6}},
  {id="viridian_command",map="KA_ROCKET_SILPH_COMMAND_1F",index=1994,
    hostMap="SILPH_CO_1F",entranceMap="SAFFRON_CITY",start={10,16},returnPoint={10,16},
    guards={{13,14},{18,12},{21,10}},boss={25,8}},
}

-- Yellow's Cerulean Cave uses a different floor plan. The Red/Blue route
-- puts two guards in walls and separates every checkpoint from the entry.
-- Land the isolated raid in Yellow's connected central pocket instead;
-- keep the real stock doorway as the return point after leaving the raid.
local hasVersion,GameVersion=pcall(require,"src.core.GameVersion")
if hasVersion and GameVersion.isYellow()then
  local cave=M.rows[3]
  cave.start={15,12}
  cave.guards={{15,10},{17,7},{19,6}}
end

M.byInstance={};M.byMap={};M.byHostMap={}
for _,row in ipairs(M.rows)do
  M.byInstance[row.id]=row
  M.byMap[row.map]=row
  M.byHostMap[row.hostMap]=M.byHostMap[row.hostMap]or{}
  M.byHostMap[row.hostMap][#M.byHostMap[row.hostMap]+1]=row
end

function M.isInstanceMap(mapId)return M.byMap[mapId]~=nil end
function M.isHostMap(mapId)return M.byHostMap[mapId]~=nil end

function M.validate()
  local seenIds,seenMaps,seenIndexes={},{},{}
  for ordinal,id in ipairs(M.ORDER)do
    local row=assert(M.byInstance[id],"missing Rocket instance "..id)
    assert(not seenIds[id],"duplicate Rocket instance")
    assert(type(row.map)=="string"and row.map:find("^"..M.instancePrefix),
      "Rocket raid must own an isolated instance map")
    assert(type(row.hostMap)=="string"and not row.hostMap:find("^KA_ROCKET_"),
      "Rocket raid source must be a stock map")
    assert(not seenMaps[row.map],"duplicate Rocket instance map")
    assert(type(row.index)=="number"and not seenIndexes[row.index],
      "duplicate Rocket map index")
    assert(type(row.start)=="table"and#row.start==2,"missing entry cell")
    assert(type(row.returnPoint)=="table"and#row.returnPoint==2,
      "missing safe stock-map return")
    assert(type(row.boss)=="table"and#row.boss==2,"missing boss cell")
    assert(#row.guards==(ordinal<3 and 2 or 3),
      "fight count must reserve final slot for boss")
    seenIds[id]=true;seenMaps[row.map]=true;seenIndexes[row.index]=true
  end
  return true
end
M.validate()
return M
