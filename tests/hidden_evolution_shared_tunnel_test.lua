-- Focused contract test for the user-authored three-shaft Kanto approach.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to the Authority root.
package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local Data = require("src.core.Data")
Data:load()

local function registry(base)
  local r = { values = {}, base = base or {} }
  function r:get(id) return self.values[id] or self.base[id] end
  function r:register(id, value)
    assert(not self.values[id], "duplicate " .. tostring(id))
    self.values[id] = value
    return value
  end
  function r:patch(id, partial)
    local value = self.values[id] or self.base[id] or {}
    self.values[id] = value
    for key, incoming in pairs(partial) do
      if type(incoming) == "table" and type(incoming.__append) == "table" then
        value[key] = value[key] or {}
        for _, row in ipairs(incoming.__append) do value[key][#value[key] + 1] = row end
      else
        value[key] = incoming
      end
    end
    return value
  end
  return r
end

local events = {}
local warps = {}
local active = "RED"
local archiveCompleted = {}
local flagSave
local lastText
local lastTextOptions
local mod = {
  id = "kanto_ascendant",
  path = root,
  save = { get = function() return { player_character = active } end },
  events = { on = function(_, id, fn) events[id] = events[id] or {}; events[id][#events[id] + 1] = fn end },
  world = {
    warpTo = function(_, map, x, y, facing)
      warps[#warps + 1] = { map = map, x = x, y = y, facing = facing }
      return true
    end,
    setFlag = function(_, id, value)
      assert(flagSave and flagSave.flags, "test flag save is missing")
      flagSave.flags[id] = value
      return true
    end,
  },
  content = {
    maps = registry(), sprites = registry(), text = registry(), encounters = registry(),
    map_scripts = registry(), map_songs = registry(),
    text_pointers = { patch = function() end },
  },
}

local factory = assert(loadfile(root .. "/hidden_evolution_architecture.lua"))()
local architecture = factory(mod, {
  activeCharacter = function() return active end,
  -- extendedCharacters normalizes unknown/absent raw identity to RED in the
  -- production wiring; Package A must inspect the raw save before this API.
  characters = { getPlayerCharacter = function() return "RED" end },
  showText = function(_, text, _, options)
    lastText, lastTextOptions = text, options
    return true
  end,
  journey = { profile = function()
    return { completedPaths = archiveCompleted }
  end },
})
assert(architecture.register())

local def = assert(mod.content.maps:get("KA_HEVO_TUNNEL_ALL"), "shared tunnel missing")
assert(def.index == 1920 and def.tileset == "CAVERN" and def.width == 27 and def.height == 12)
assert(def.borderBlock == 3, "shared tunnel viewport border must be native solid CAVERN rock")
assert(#def.blocks == 324 and def.layoutHash == "hevo-a-0b71")
assert(def.sourceProjectHash ==
  "35e2176fdbcba08602cd3f327cc8052dea2d39c0e0cdecf819d1ee8a8d09576a")
assert(#def.warps == 6, "three route returns plus three trial entrances required")
assert(mod.content.map_songs:get("KA_HEVO_TUNNEL_ALL") == "Music_KA_DeepEvolution",
  "the shared fissure shaft inherits the previous outdoor map music")
assert(not mod.content.maps:get("KA_HEVO_TUNNEL_RED")
    and not mod.content.maps:get("KA_HEVO_TUNNEL_BLUE")
    and not mod.content.maps:get("KA_HEVO_TUNNEL_GREEN"),
  "per-character duplicate tunnels are forbidden")

package.loaded["src.render.TileRenderer"] = { new = function() return {} end }
local RuntimeMap = require("src.world.Map")
local runtime = RuntimeMap.new(def, assert(Data.tilesets.CAVERN))
for _, warp in ipairs(def.warps) do
  assert(runtime:isWalkableCell(warp.x, warp.y), "warp is not walkable")
  assert(runtime:isWarpTileCell(warp.x, warp.y), "warp lacks native CAVERN trigger")
end

-- BLUE/GREEN must sit in the middle of a real straight Kanto rock face, not
-- on the corner/gap cells that their first visual pass exposed. Validate the
-- source route collision and tile data before any mod patch is involved.
for key, want in pairs({
  BLUE = { map = "ROUTE_24", x = 10, y = 3, minComponent = 180 },
  GREEN = { map = "ROUTE_3", x = 41, y = 3, minComponent = 420 },
}) do
  local site = architecture.sites[key]
  assert(site.map == want.map and site.fissure.x == want.x and site.fissure.y == want.y)
  assert(site.approach.x == want.x and site.approach.y == want.y + 1
      and site.approach.facing == "up")
  local source = assert(Data.maps[want.map])
  local route = RuntimeMap.new(source, assert(Data.tilesets[source.tileset]))
  local width, height = source.width * 2, source.height * 2
  assert(want.x >= 4 and want.x <= width - 5 and want.y >= 1 and want.y < height - 2,
    key .. " fissure is too close to a map edge")
  -- The rear Route-24 cliff ends at a native vertical divider on its right;
  -- validate the complete five-cell straight face that actually surrounds
  -- the opening. GREEN still has the original seven-cell span.
  local spanLeft, spanRight = key == "BLUE" and -3 or -3,
    key == "BLUE" and 1 or 3
  for dx = spanLeft, spanRight do
    local x = want.x + dx
    assert(not route:isWalkableCell(x, want.y), key .. " wall span contains a gap")
    local tile = route:cellTile(x, want.y)
    assert(tile == 0x36 or tile == 0x37, key .. " span is not native rock face")
    assert(route:isWalkableCell(x, want.y + 1), key .. " approach span is not clear")
  end
  for _, object in ipairs(source.objects or {}) do
    assert(not (object.x == want.x and (object.y == want.y or object.y == want.y + 1)),
      key .. " fissure collides with a vanilla object")
  end
  local queue, seen, head = { { want.x, want.y + 1 } },
    { [want.x .. ":" .. (want.y + 1)] = true }, 1
  while queue[head] do
    local at = queue[head]
    head = head + 1
    for _, step in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
      local x, y = at[1] + step[1], at[2] + step[2]
      local tag = x .. ":" .. y
      if not seen[tag] and route:inBounds(x, y) and route:isWalkableCell(x, y) then
        seen[tag] = true
        queue[#queue + 1] = { x, y }
      end
    end
  end
  assert(#queue >= want.minComponent, key .. " approach is not on the main route component")
end

local function componentFrom(start)
  local queue, seen, head = { { x = start.x, y = start.y } },
    { [start.x .. ":" .. start.y] = true }, 1
  while queue[head] do
    local at = queue[head]
    head = head + 1
    for _, step in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
      local x, y = at.x + step[1], at.y + step[2]
      local key = x .. ":" .. y
      if not seen[key] and runtime:inBounds(x, y) and runtime:isWalkableCell(x, y) then
        seen[key] = true
        queue[#queue + 1] = { x = x, y = y }
      end
    end
  end
  return seen, #queue
end

local ownership, branchBounds = {}, {}
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local site, branch = architecture.sites[key], architecture.branches[key]
  assert(site.tunnel == "KA_HEVO_TUNNEL_ALL")
  assert(def.warps[branch.returnSlot] == site.returnWarp)
  assert(def.warps[branch.trialSlot] == site.trialWarp)
  local component, size = componentFrom(branch.entry)
  assert(size == 57, key .. " shaft changed size")
  assert(component[branch.returnPad.x .. ":" .. branch.returnPad.y],
    key .. " cannot reach its route exit")
  assert(component[branch.trialPad.x .. ":" .. branch.trialPad.y],
    key .. " cannot reach its trial entrance")
  local minX, maxX = math.huge, -math.huge
  for cell in pairs(component) do
    assert(not ownership[cell], key .. " crosses into " .. tostring(ownership[cell]))
    ownership[cell] = key
    local x = assert(tonumber(cell:match("^(%-?%d+):")))
    minX, maxX = math.min(minX, x), math.max(maxX, x)
  end
  branchBounds[key] = { minX = minX, maxX = maxX }

  active = key
  local locked = { flags = {}, player = { map = site.map } }
  local before = #warps
  local allowed, why = architecture.entranceAvailable(key, { save=locked })
  assert(not allowed and why == "research",
    key .. " fissure opens without the matching researcher discovery")
  lastText = nil
  assert(architecture.enter(key, { save=locked }))
  assert(#warps == before and lastText and lastText:find("researcher", 1, true),
    key .. " locked fissure must explain the researcher gate without warping")

  local discovered = { flags = {
    [architecture.flags.discovered .. key] = true,
  }, player = { map=site.map } }
  flagSave = discovered
  allowed, why = architecture.entranceAvailable(key, { save=discovered })
  assert(allowed and why == "discovered",
    key .. " matching researcher discovery does not open the fissure")
  lastText, lastTextOptions = nil, nil
  assert(architecture.enter(key, { save=discovered }))
  assert(#warps == before and lastTextOptions
      and lastTextOptions.defaultNo == true
      and type(lastTextOptions.choice) == "function",
    key .. " fissure must ask before warping and default to NO")
  local expectedAir = ({ RED="hot, dry", BLUE="cold, damp",
    GREEN="unusually clear" })[key]
  assert(lastText and lastText:find(expectedAir, 1, true)
      and lastText:find("Enter it?", 1, true),
    key .. " fissure prompt lacks its physical air-current clue")
  lastTextOptions.choice(false)
  assert(#warps == before,
    key .. " default-NO/cancel must leave the player outside")
  lastTextOptions.choice(true)
  assert(discovered.flags[architecture.flags.entered .. key] == true,
    key .. " successful fissure entry does not persist admission")
  local arrival = warps[#warps]
  assert(arrival.map == "KA_HEVO_TUNNEL_ALL"
      and arrival.x == branch.entry.x and arrival.y == branch.entry.y)

  local raw = { player = { map = site.legacyTunnel, x = 1, y = 1,
    facing = "left", surfing = true } }
  local changed, migratedKey = architecture.migrateSaveLocation(raw)
  assert(changed and migratedKey == key and raw.player.map == "KA_HEVO_TUNNEL_ALL")
  assert(raw.player.x == branch.entry.x and raw.player.y == branch.entry.y
      and raw.player.facing == branch.entry.facing and raw.player.surfing == false)
  assert(raw.flags[architecture.flags.entered .. key] == true,
    key .. " legacy-tunnel migration did not retain its rescue receipt")

  local map, x, y = architecture.resolveTunnelWarp("LAST_MAP", 0, 0,
    { warp = site.returnWarp, data = { maps = mod.content.maps.values } })
  assert(map == site.map and x == site.approach.x and y == site.approach.y,
    key .. " route return resolves to the wrong fissure")
end

local inTrialMigration = {
  flags = {}, player = { map="KA_HEVO_GREEN_MIST", x=4, y=4 },
}
local changed, migratedKey = architecture.migrateSaveLocation(inTrialMigration)
assert(changed and migratedKey == "GREEN"
    and inTrialMigration.player.map == "KA_HEVO_GREEN_MIST"
    and inTrialMigration.flags[architecture.flags.entered .. "GREEN"] == true,
  "an older in-trial save did not gain a durable rescue receipt")

-- Every authored end-room pad must resolve to the active character's own
-- route.  A completed run returns to its own shrine; an incomplete/corrupt
-- run is recovered to its isolated tunnel shaft instead of entering a
-- foreign trial and deadlocking.
active = "RED"
local foreignSave = { flags={}, player={map="KA_HEVO_SHARED_SEALED_ANTECHAMBER"},
  modData={kanto_ascendant={extended_characters={player_character="RED"}}} }
local guardedMap, guardedX, guardedY = architecture.resolveCharacterTrialWarp(
  "KA_HEVO_BLUE_KYOGRE_SHRINE", 3, 27, foreignSave)
assert(guardedMap == "KA_HEVO_TUNNEL_ALL"
    and guardedX == architecture.branches.RED.entry.x
    and guardedY == architecture.branches.RED.entry.y,
  "an incomplete RED run can still enter BLUE's shrine")
foreignSave.modData.kanto_ascendant.hevo_run = {
  dungeonLegacy={seals={RED=true}},
}
guardedMap, guardedX, guardedY = architecture.resolveCharacterTrialWarp(
  "KA_HEVO_GREEN_RAYQUAZA_SHRINE", 3, 35, foreignSave)
assert(guardedMap == architecture.shrineReturns.RED.map
    and guardedX == architecture.shrineReturns.RED.x
    and guardedY == architecture.shrineReturns.RED.y,
  "a completed RED run does not return to RED's own shrine")
guardedMap, guardedX, guardedY = architecture.resolveCharacterTrialWarp(
  "KA_HEVO_RED_SHRINE", 9, 9, foreignSave)
assert(guardedMap == "KA_HEVO_RED_SHRINE" and guardedX == 9 and guardedY == 9,
  "the character guard rewrites RED's own shrine")

local trappedForeign = { flags={}, player={
    map="KA_HEVO_BLUE_KYOGRE_SHRINE", x=37, y=3, facing="up", surfing=true,
  }, modData={kanto_ascendant={
    extended_characters={player_character="RED"},
    hevo_run={dungeonLegacy={seals={RED=true}}},
  }} }
changed, migratedKey = architecture.migrateSaveLocation(trappedForeign)
assert(changed and migratedKey == "RED"
    and trappedForeign.player.map == architecture.shrineReturns.RED.map
    and trappedForeign.player.x == architecture.shrineReturns.RED.x
    and trappedForeign.player.y == architecture.shrineReturns.RED.y
    and trappedForeign.player.surfing == false,
  "foreign-shrine save recovery did not return RED to its own shrine")
assert(trappedForeign.flags[architecture.flags.entered .. "RED"] == true,
  "foreign-shrine save recovery lost RED entrance admission")

-- Exhaust the complete 3x3 identity matrix rather than proving isolation
-- only for RED.  Every foreign end-room pad fails to the owner's isolated
-- shaft while incomplete, then to the owner's safe shrine cell once sealed;
-- an own-shrine destination is never rewritten.
local shrineIds={
  RED="KA_HEVO_RED_SHRINE", BLUE="KA_HEVO_BLUE_KYOGRE_SHRINE",
  GREEN="KA_HEVO_GREEN_RAYQUAZA_SHRINE",
}
for _,owner in ipairs({"RED","BLUE","GREEN"}) do
  for _,destinationOwner in ipairs({"RED","BLUE","GREEN"}) do
    local matrixSave={flags={},player={map="KA_HEVO_SHARED_SEALED_ANTECHAMBER"},
      modData={kanto_ascendant={extended_characters={player_character=owner}}}}
    local destination=shrineIds[destinationOwner]
    local map,x,y=architecture.resolveCharacterTrialWarp(
      destination,99,97,matrixSave)
    if destinationOwner==owner then
      assert(map==destination and x==99 and y==97,
        owner.." own shrine destination was rewritten")
    else
      local entry=architecture.branches[owner].entry
      assert(map==architecture.sharedTunnel and x==entry.x and y==entry.y,
        owner.." incomplete run entered foreign "..destinationOwner.." shrine")
      matrixSave.modData.kanto_ascendant.hevo_run={
        dungeonLegacy={seals={[owner]=true}},
      }
      map,x,y=architecture.resolveCharacterTrialWarp(
        destination,99,97,matrixSave)
      local safe=architecture.shrineReturns[owner]
      assert(map==safe.map and x==safe.x and y==safe.y,
        owner.." completed run failed safe recovery from "
          ..destinationOwner.." shrine")
    end
  end
end

-- The route-side fissure has exactly one authority: the canonical discovery
-- flag written by a correct researcher answer. Legacy entered/in-progress/
-- completion receipts can still rescue a save already inside via migration,
-- but none may reopen the exterior and bypass a failed researcher cooldown.
active = "RED"
for _, fixture in ipairs({
    { reason="entered", save={ flags={
      [architecture.flags.entered .. "RED"] = true,
    }, player={map="ROUTE_22"} } },
    { reason="in-progress", save={ flags={},
      player={map="KA_HEVO_RED_RECOVERY"} } },
    { reason="completed-persistent", save={ flags={}, player={map="ROUTE_22"},
      modData={kanto_ascendant={hevo_persistent={meta={RED=true}}}} } },
    { reason="adapter-reentry", save={ flags={}, player={map="ROUTE_22"},
      modData={kanto_ascendant={hevo_run={dungeonLegacy={
        reentered={RED=true}, seals={},
      }}}} } },
  }) do
  local allowed, why = architecture.entranceAvailable("RED",
    { save=fixture.save })
  assert(not allowed and why == "research",
    "legacy receipt bypasses researcher discovery: " .. fixture.reason)
end
archiveCompleted.red = true
local archiveOnly = { flags={}, player={map="ROUTE_22"},
  modData={kanto_ascendant={legacy_journey={version=1, runId="old-red"}}} }
local archiveAllowed, archiveWhy = architecture.entranceAvailable("RED",
  { save=archiveOnly })
assert(not archiveAllowed and archiveWhy == "research",
  "archive completion bypasses the current researcher's riddle")
local freshAgainstStaleArchive = { flags={}, player={map="ROUTE_22"},
  modData={kanto_ascendant={}} }
local freshAllowed, freshWhy = architecture.entranceAvailable("RED",
  { save=freshAgainstStaleArchive })
assert(not freshAllowed and freshWhy == "research",
  "BLITZ archive completion leaked into a fresh non-Legacy New Game")
archiveCompleted.red = nil
local foreignTrial = { flags={}, player={map="KA_HEVO_BLUE_FROST_HALL"} }
local allowed, why = architecture.entranceAvailable("RED", { save=foreignTrial })
assert(not allowed and why == "research",
  "a foreign trial map bypasses RED's discovery gate")
active = "BLUE"
local redDiscovery = { flags={
  [architecture.flags.discovered .. "RED"] = true,
}, player={map="ROUTE_22"} }
allowed, why = architecture.entranceAvailable("RED", { save=redDiscovery })
assert(not allowed and why == "character",
  "wrong character bypasses the fissure gate with another discovery flag")

-- A future identity record must not become RED through the public visual
-- fallback, even when the canonical RED discovery flag is already present.
active = nil
local futureDiscovery = { flags={
  [architecture.flags.discovered .. "RED"] = true,
}, player={map="ROUTE_22"}, modData={kanto_ascendant={
  extended_characters={player_character="FUTURE"},
}} }
allowed, why = architecture.entranceAvailable("RED", { save=futureDiscovery })
assert(not allowed and why == "character",
  "future raw identity normalized to RED at the physical fissure")
active = "RED"

-- A flat Gen-I viewport spans twenty cells.  Even at the inner edge of one
-- shaft, the next walkable shaft must remain more than half a viewport away;
-- only native solid rock may occupy the intervening cells.
for _, pair in ipairs({ { "RED", "BLUE" }, { "BLUE", "GREEN" } }) do
  local left, right = branchBounds[pair[1]], branchBounds[pair[2]]
  local separation = right.minX - left.maxX
  assert(separation >= 12,
    pair[1] .. "/" .. pair[2] .. " shafts can enter the same camera view")
  for x = left.maxX + 1, right.minX - 1 do
    for y = 0, def.height * 2 - 1 do
      assert(not runtime:isWalkableCell(x, y),
        pair[1] .. "/" .. pair[2] .. " rock buffer contains a walkable leak")
    end
  end
end

assert(architecture.install({}))
local loadRaw = { player = { map = "KA_HEVO_TUNNEL_BLUE", x = 0, y = 0 } }
for _, handler in ipairs(events["save.loading"] or {}) do handler({ raw = loadRaw }) end
assert(loadRaw.player.map == "KA_HEVO_TUNNEL_ALL"
    and loadRaw.player.x == architecture.branches.BLUE.entry.x,
  "save.loading does not migrate before map validation")

print("hidden_evolution_shared_tunnel_test: PASS")
