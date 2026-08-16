-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to this feature root.
-- This is a non-rendering integration traversal: it registers every new map,
-- validates the real path-specific collision cells, verifies every physical warp target,
-- and proves that no 1902--1913 prototype is imported by the campaign entry.
local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"), "KA_HIDDEN_EVOLUTION_MOD required")
if not _G.love then _G.love = require("tests.love_stub") end
local Data = require("src.core.Data"); Data:load()
local generated = require("data.generated.maps")
local function copy(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}; if seen[value] then return seen[value] end
  local out = {}; seen[value] = out; for k, v in pairs(value) do out[k] = copy(v, seen) end; return out
end
local function registry(base)
  local r = { values = {}, base = base or {} }
  function r:get(id) return self.values[id] or self.base[id] end
  function r:register(id, value) assert(not self.values[id], "duplicate " .. id); self.values[id] = value; return value end
  function r:patch(id, partial)
    local value = copy(self:get(id) or {})
    for field, update in pairs(partial) do
      if type(update) == "table" and update.__append then
        value[field] = value[field] or {}
        for _, row in ipairs(update.__append) do value[field][#value[field] + 1] = copy(row) end
      else value[field] = copy(update) end
    end
    self.values[id] = value
  end
  return r
end
local maps, scripts, tilesets = registry(generated), registry(), registry(Data.tilesets)
local saved = {}
local mod = {
  id = "kanto_ascendant", path = root, exports = {},
  save = { get = function(_, k) return saved[k] end, set = function(_, k, v) saved[k] = v end },
  read = function(_, file)
    local handle, err = io.open(root .. "/" .. file, "rb")
    if not handle then return nil, err end
    local body = handle:read("*a"); handle:close(); return body
  end,
  events = { on = function() end }, content = { maps = maps, sprites = registry(), text = registry(),
    text_pointers = { patch = function() end }, encounters = registry(), map_scripts = scripts,
    map_songs = registry(), field = registry(), music = registry(), tilesets = tilesets },
}
-- Use the real registry definitions even though this map-only harness keeps
-- item/evolution content disabled.  The campaign must never carry a second
-- handwritten species/color matrix.
local packages = assert(loadfile(root .. "/hevo_packages.lua"))()(mod, {
  enabled = false,
})
local campaign = assert(loadfile(root .. "/hidden_evolution_campaign.lua"))()(mod, {
  hevoPackages = packages,
})
assert(campaign.register(), "campaign registers once")
assert(campaign.validateNoPrototypeFallback(), "campaign rejects legacy prototype fallback")
local MapLoader = require("src.world.MapLoader")
-- GREEN's fissure remains on Route 3 before Mt. Moon.  The researcher now
-- gives a deduction rather than a route number/cardinal instruction, so the
-- physical architecture remains the authority for the exact wall cell.
local route3 = MapLoader.load(Data, "ROUTE_3")
local greenSite = assert(campaign.modules.tunnel.sites.GREEN, "GREEN site missing")
assert(greenSite.map == "ROUTE_3",
  "GREEN architecture must retain the native Route 3 wall")
assert(route3:isWalkableCell(greenSite.approach.x, greenSite.approach.y),
  "GREEN Route 3 approach is not walkable")
assert(not route3:isWalkableCell(greenSite.fissure.x, greenSite.fissure.y),
  "GREEN Route 3 fissure must remain embedded in the mountain wall")

local researcherContract = {
  RED = { map="CELADON_CITY", x=38, y=22 },
  BLUE = { map="CINNABAR_ISLAND", x=6, y=11 },
  GREEN = { map="PEWTER_CITY", x=8, y=3 },
}
local professorSprites = {}
local forbiddenDirections = {
  "NORTH", "SOUTH", "EAST", "WEST",
  "NORD", "SUED", "SÜD", "OST",
}
local function containsWord(text, word)
  return tostring(text or ""):upper():match(
    "%f[%a]" .. word .. "%f[%A]") ~= nil
end
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local spec = researcherContract[key]
  local hint = assert(campaign.modules.hints.HINTS[key], key .. " hint missing")
  assert(hint.map == spec.map and hint.x == spec.x and hint.y == spec.y,
    key .. " researcher changed its audited city position")
  assert(type(hint.professor) == "string" and hint.professor:match("^Professor "),
    key .. " is not identified as a field professor")
  assert(not hint.object:find("RESEARCHER", 1, true) and not hint.text:find("RESEARCHER", 1, true),
    key .. " still exposes a generic researcher identity")
  assert(#hint.choices == 3, key .. " researcher does not offer three choices")
  local values, hasCorrect = {}, false
  for _, choice in ipairs(hint.choices) do
    assert(not values[choice.value], key .. " quiz has a duplicate choice")
    values[choice.value] = true
    if choice.value == hint.correct then hasCorrect = true end
  end
  assert(hasCorrect, key .. " quiz correct answer is not one of its choices")
  for language, text in pairs({
      riddleEn=hint.riddle.en, riddleDe=hint.riddle.de,
      questionEn=hint.question.en, questionDe=hint.question.de,
    }) do
    assert(not tostring(text):upper():match("ROUTE%s*%d+"),
      key .. " " .. language .. " leaks a route number")
    for _, direction in ipairs(forbiddenDirections) do
      assert(not containsWord(text, direction),
        key .. " " .. language .. " leaks cardinal direction " .. direction)
    end
  end
  assert(not professorSprites[hint.sprite], key .. " reuses another field professor's sprite")
  professorSprites[hint.sprite] = true
  for _, object in ipairs((maps:get(hint.map) or {}).objects or {}) do
    assert(object.name ~= hint.object,
      key .. " researcher was statically patched before the Hall of Fame")
  end
end

-- Runtime objects are post-Hall-only: every audited city is empty before the
-- canonical Hall authority and gets exactly its one researcher afterwards.
local activeOw
mod.world = {
  overworld = function() return activeOw end,
  spawnNpc = function(_, mapId, def)
    assert(activeOw and activeOw.map.id == mapId,
      "researcher spawned on a non-active map")
    local npc = { def=copy(def), cellX=def.x, cellY=def.y }
    activeOw.npcs[#activeOw.npcs + 1] = npc
    return npc
  end,
  removeNpc = function() return true end,
  setFlag = function() return true end,
}
local spawnGame = { data=Data, save={ flags={}, hallOfFame={} } }
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local hint = campaign.modules.hints.HINTS[key]
  local runtimeMap = MapLoader.load(Data, hint.map)
  activeOw = { map=runtimeMap, npcs={}, player={cellX=0,cellY=0} }
  function activeOw:npcAtCell(x, y)
    for _, npc in ipairs(self.npcs) do
      if npc.cellX == x and npc.cellY == y then return npc end
    end
  end
  spawnGame.save = { flags={}, hallOfFame={} }
  local spawned, why = campaign.modules.hints.refresh(spawnGame, hint.map)
  assert(not spawned and why == "pre-hall" and #activeOw.npcs == 0,
    key .. " researcher exists before the Hall of Fame")
  spawnGame.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  assert(campaign.modules.hints.refresh(spawnGame, hint.map)
      and #activeOw.npcs == 1
      and activeOw.npcs[1].def.name == hint.object
      and activeOw.npcs[1].cellX == hint.x
      and activeOw.npcs[1].cellY == hint.y,
    key .. " researcher does not spawn dynamically post-Hall")
end

-- Drive the real hint provider's callback contract without rendering: wrong
-- answers set no authority and reopen the same three-choice quiz; the exact
-- correct answer sets only the matching canonical discovery flag.
local activeQuizCharacter, shown, menu
local quizHints = assert(loadfile(root .. "/hidden_evolution_story_hints.lua"))()(mod, {
  activeCharacter = function() return activeQuizCharacter end,
  hasHallOfFame = function() return true end,
  showText = function(_, text, done)
    shown = { text=text, done=done }
    return true
  end,
  openMenu = function(_, title, rows, options)
    menu = { title=title, rows=rows, options=options }
    return true
  end,
})
local function choose(menuState, item)
  local candidate = { close=function(self) self.closed=true end }
  menuState.options.onChoose(item, candidate)
  assert(candidate.closed, "researcher quiz did not close its prior menu")
end
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local hint = quizHints.HINTS[key]
  activeQuizCharacter = key
  saved[quizHints.RUN_STATE], shown, menu = nil, nil, nil
  local quizGame = { save={flags={},hallOfFame={{}}} }
  assert(quizHints.talk(key, quizGame), key .. " riddle talk failed")
  assert(shown and shown.text == hint.riddle.en and type(shown.done) == "function",
    key .. " matching researcher does not begin with its riddle")
  shown.done()
  assert(menu and #menu.rows == 3,
    key .. " riddle does not open the required three-choice quiz")
  local wrong
  for _, row in ipairs(menu.rows) do
    if row.value ~= hint.correct then wrong = row break end
  end
  choose(menu, assert(wrong, key .. " quiz has no wrong answer"))
  assert(quizGame.save.flags[quizHints.FLAG_PREFIX .. key] ~= true
      and shown and shown.text == hint.wrong.en,
    key .. " wrong quiz answer set discovery authority")
  shown.done()
  assert(menu and #menu.rows == 3,
    key .. " wrong quiz answer did not retry the same quiz")
  local correct
  for _, row in ipairs(menu.rows) do
    if row.value == hint.correct then correct = row break end
  end
  choose(menu, assert(correct, key .. " quiz lost its correct answer"))
  assert(quizGame.save.flags[quizHints.FLAG_PREFIX .. key] == true
      and shown and shown.text == hint.solved.en,
    key .. " correct quiz answer did not set matching discovery")
  for _, other in ipairs({ "RED", "BLUE", "GREEN" }) do
    if other ~= key then
      assert(quizGame.save.flags[quizHints.FLAG_PREFIX .. other] ~= true,
        key .. " quiz leaked discovery to " .. other)
    end
  end
end
local expected = {
  "KA_HEVO_TUNNEL_ALL",
  "KA_HEVO_RED_UPPER", "KA_HEVO_RED_ABYSS", "KA_HEVO_RED_RECOVERY", "KA_HEVO_RED_LOWER", "KA_HEVO_RED_SHRINE",
  "KA_HEVO_BLUE_FROST_THRESHOLD", "KA_HEVO_BLUE_FROST_HALL", "KA_HEVO_BLUE_GLACIER_MAZE", "KA_HEVO_BLUE_TIDAL_DEPTHS", "KA_HEVO_BLUE_KYOGRE_SHRINE",
  "KA_HEVO_GREEN_THRESHOLD", "KA_HEVO_GREEN_GROVE", "KA_HEVO_GREEN_MIST", "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
  "KA_HEVO_SHARED_SEALED_ANTECHAMBER",
}
local expectedIndex = {
  KA_HEVO_TUNNEL_ALL = 1920,
  KA_HEVO_RED_UPPER = 1930, KA_HEVO_RED_ABYSS = 1931, KA_HEVO_RED_RECOVERY = 1932, KA_HEVO_RED_LOWER = 1933, KA_HEVO_RED_SHRINE = 1934,
  KA_HEVO_BLUE_FROST_THRESHOLD = 1940, KA_HEVO_BLUE_FROST_HALL = 1941, KA_HEVO_BLUE_GLACIER_MAZE = 1942, KA_HEVO_BLUE_TIDAL_DEPTHS = 1943, KA_HEVO_BLUE_KYOGRE_SHRINE = 1944,
  KA_HEVO_SHARED_SEALED_ANTECHAMBER = 1948,
  KA_HEVO_GREEN_THRESHOLD = 1950, KA_HEVO_GREEN_GROVE = 1951, KA_HEVO_GREEN_MIST = 1952, KA_HEVO_GREEN_RAYQUAZA_SHRINE = 1953,
}
local pathTileset = {
  KA_HEVO_GREEN_THRESHOLD = "FOREST", KA_HEVO_GREEN_GROVE = "FOREST",
  KA_HEVO_GREEN_MIST = "FOREST", KA_HEVO_GREEN_RAYQUAZA_SHRINE = "FOREST",
}
package.loaded["src.render.TileRenderer"] = { new = function() return {} end }
local RuntimeMap = require("src.world.Map")
local function canApproach(runtime, x, y)
  for _, d in ipairs({ { 0, 0 }, { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
    local cx, cy = x + d[1], y + d[2]
    if runtime:inBounds(cx, cy) and runtime:isWalkableCell(cx, cy) then return true end
  end
  return false
end
for _, id in ipairs(expected) do
  local def = assert(maps:get(id), "missing campaign map " .. id)
  assert(def.index == expectedIndex[id], id .. " changed its stable map index")
  assert(def.tileset == (pathTileset[id] or "CAVERN") and def.voxelMode == "FULL"
      and def.voxelCells == nil and def.outdoor == false,
    id .. " violates the path terrain/voxel contract")
  local terrain = assert(tilesets:get(def.tileset), id .. " lacks its terrain tileset")
  local runtime = RuntimeMap.new(def, terrain)
  for _, warp in ipairs(def.warps or {}) do
    assert(runtime:isWalkableCell(warp.x, warp.y), id .. " warp sits on a non-walkable cell")
    assert(warp.destMap == "LAST_MAP" or maps:get(warp.destMap), id .. " has unresolved warp target " .. tostring(warp.destMap))
    -- RC65-QA-010: a declared warp on ordinary floor is structurally visible
    -- but cannot be entered with the D-pad. BLUE and its actual tunnel must
    -- use native tile semantics, not a controller-side QA jump.
    assert(runtime:isWarpTileCell(warp.x, warp.y), id .. " warp lacks a native trigger tile")
  end
  for _, object in ipairs(def.objects or {}) do
    assert(canApproach(runtime, object.x, object.y), id .. " talk object is unreachable: " .. object.name)
    if object.text then
      assert(scripts:get(id) and scripts:get(id).talk and scripts:get(id).talk[object.text],
        id .. " has no talk handler for " .. object.name)
    end
  end
end
assert(not tilesets:get("KA_HEVO_G2_ICE_PATH") and not tilesets:get("KA_HEVO_G2_FOREST"),
  "retired Johto tilesets leaked into the Kanto-only campaign")
-- BLUE's authored ridge is made from the shipped CAVERN wall and its ice
-- proxy from a fully walkable native accent.  The focused BLUE suite checks
-- every slide/stop/hole cell; this integration pass keeps the whole route
-- physically connected through the real collision table.
local blueDef = assert(maps:get("KA_HEVO_BLUE_GLACIER_MAZE"))
local cavern = assert(tilesets:get("CAVERN"))
local blueRuntime = RuntimeMap.new(blueDef, cavern)
local function reachable(runtime, from, goal)
  local queue, seen, head = { from }, { [from.x .. ":" .. from.y] = true }, 1
  while queue[head] do
    local at = queue[head]; head = head + 1
    if at.x == goal.x and at.y == goal.y then return true end
    for _, step in ipairs({ {1,0}, {-1,0}, {0,1}, {0,-1} }) do
      local x, y = at.x + step[1], at.y + step[2]
      local key = x .. ":" .. y
      if not seen[key] and runtime:inBounds(x,y) and runtime:isWalkableCell(x,y) then
        seen[key] = true; queue[#queue + 1] = { x=x, y=y }
      end
    end
  end
  return false
end
-- The Glacier exit is deliberately isolated until its native Strength
-- boulder reaches the rune.  Validate both halves of that runtime contract:
-- the unsolved wall cannot be bypassed, and the controller's exact block
-- replacement opens a real collision path to the exit.
assert(not reachable(blueRuntime, blueDef.warps[1], blueDef.warps[2]),
  "BLUE Frost Strength gate can be bypassed before its switch")
local blueSolved = copy(blueDef)
local blueGate = assert(campaign.modules.BLUE.switches.ICE, "BLUE Frost switch contract missing")
blueSolved.blocks[blueGate.gate.by * blueSolved.width + blueGate.gate.bx + 1] = blueGate.gate.open
blueRuntime = RuntimeMap.new(blueSolved, cavern)
assert(reachable(blueRuntime, blueSolved.warps[1], blueSolved.warps[2]),
  "BLUE Frost route has no physical entry-to-exit path after its Strength switch")
for _, id in ipairs(campaign.LEGACY_PROTOTYPES) do assert(not maps.values[id], "campaign registered legacy prototype " .. id) end
assert(not maps:get("KA_HEVO_TUNNEL_RED") and not maps:get("KA_HEVO_TUNNEL_BLUE")
    and not maps:get("KA_HEVO_TUNNEL_GREEN"),
  "legacy per-character tunnel maps must not remain registered")
local tunnel = assert(maps:get("KA_HEVO_TUNNEL_ALL"), "shared tunnel missing")
assert(tunnel.layoutHash == "hevo-a-0b71", "shared tunnel no longer matches the separated three-shaft authority layout")
assert(tunnel.sourceProjectHash == "35e2176fdbcba08602cd3f327cc8052dea2d39c0e0cdecf819d1ee8a8d09576a",
  "shared tunnel lost its user-project provenance")
assert(#tunnel.warps == 6, "shared tunnel needs three exits and three trial entrances")
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local site = campaign.modules.tunnel.sites[key]
  assert(site.tunnel == "KA_HEVO_TUNNEL_ALL", key .. " does not use the shared tunnel")
  assert(tunnel.warps[site.branch.returnSlot] == site.returnWarp,
    key .. " shared-tunnel return slot changed")
  assert(tunnel.warps[site.branch.trialSlot] == site.trialWarp,
    key .. " shared-tunnel trial slot changed")
end
for key, oldMap in pairs(campaign.modules.tunnel.legacyTunnels) do
  local raw = { player = { map = oldMap, x = 1, y = 1, facing = "left", surfing = true } }
  local migrated, who = campaign.modules.tunnel.migrateSaveLocation(raw)
  local entry = campaign.modules.tunnel.branches[key].entry
  assert(migrated and who == key and raw.player.map == "KA_HEVO_TUNNEL_ALL"
      and raw.player.x == entry.x and raw.player.y == entry.y
      and raw.player.facing == entry.facing and raw.player.surfing == false,
    key .. " legacy tunnel save does not migrate before map validation")
end
for _, key in ipairs({ "RED", "BLUE", "GREEN" }) do
  local path, ids = campaign.modules[key], campaign.pathIds(campaign.modules[key])
  assert(maps:get(ids.upper).warps[1].destMap == campaign.CONTRACT.tunnels[key], key .. " start return misses tunnel")
  assert(maps:get(ids.upper).warps[1].destWarp == campaign.modules.tunnel.sites[key].branch.returnSlot,
    key .. " start return selects the wrong shared shaft")
  local slot, found = ({ RED = 1, BLUE = 2, GREEN = 3 })[key], false
  for _, warp in ipairs(maps:get(ids.shrine).warps) do if warp.destMap == campaign.CONTRACT.shared and warp.destWarp == slot then found = true end end
  assert(found, key .. " shrine cannot reach shared end room")
end
-- Mega stones are optional side discoveries, never completion payloads. The
-- adapter owns the one persistent secret ledger; maps only submit a stable
-- secret identity.  Each completion below deliberately happens first, then a
-- later re-entry claim proves the cache/relic remains available until found.
local secretCalls, completions = {}, 0
local secretAdapter = {
  finalize = function(_, payload)
    completions = completions + 1
    return true, { packages = {}, character = payload.character }
  end,
  claimSecret = function(game, request)
    assert(type(request) == "table" and request.character and request.stone and request.secret,
      "secret claim must use the shared request contract")
    game.save.secretClaims = game.save.secretClaims or {}
    if game.save.secretClaims[request.stone] then return false, "claimed" end
    game.save.secretClaims[request.stone] = request.secret
    secretCalls[#secretCalls + 1] = request
    return true, "granted"
  end,
}
local function pathFactory(file, character)
  return assert(loadfile(root .. "/" .. file))()(mod, {
    activeCharacter = function() return character end,
    legacyDungeonAdapter = secretAdapter,
  })
end
local function hasObject(mapId, name)
  for _, object in ipairs(maps:get(mapId).objects or {}) do
    if object.name == name then return true end
  end
  return false
end
local red = pathFactory("hidden_evolution_red_path.lua", "RED")
saved.hevo_run = { red = { sight = 5, boulders = { A = true, B = true, C = true } } }
local redGame = { save = {} }
assert(red.complete(redGame), "RED completion without secret must succeed")
assert(not redGame.save.secretClaims and red.layouts.recovery.objects[1].name == "KA_RED_BLAZIKENITE_SECRET",
  "RED completion must not claim or remove its re-entry secret")
assert(red.claimMega(redGame), "RED later re-entry secret claim must delegate")

saved.hevo_run = { hidden_evolution_blue = { asked = {}, solved = { DEPTHS_EAST = true }, sight = 5 } }
local blue = pathFactory("hidden_evolution_blue_campaign.lua", "BLUE")
local blueGame = { save = {} }
assert(blue.claimAll(blueGame), "BLUE completion without secret must succeed")
assert(not blueGame.save.secretClaims and hasObject("KA_HEVO_BLUE_TIDAL_DEPTHS", "KA_HEVO_BLUE_SWAMPERTITE_CACHE"),
  "BLUE completion must not claim or remove its re-entry secret")
assert(blue.claimSwampertite(blueGame), "BLUE later re-entry secret claim must delegate")

local green = pathFactory("hidden_evolution_green_grove.lua", "GREEN")
saved.hevo_run = { cycle = 0, hidden_evolution_story_campaign = {
  greenToken = "0:GREEN", green = { asked = {}, sight = 5, rootgate = true },
} }
local greenGame = { save = {} }
assert(green.complete(greenGame), "GREEN completion without secret must succeed")
assert(not greenGame.save.secretClaims and hasObject("KA_HEVO_GREEN_MIST", "KA_GREEN_SCEPTILITE_SECRET"),
  "GREEN completion must not claim or remove its re-entry secret")
assert(green.claimMega(greenGame), "GREEN later re-entry secret claim must delegate")
assert(completions == 3 and #secretCalls == 3, "all paths must separate completion from secret claims")
for index, expectedSecret in ipairs({ "KA_RED_BLAZIKENITE_SECRET", "KA_HEVO_BLUE_SWAMPERTITE_CACHE", "KA_GREEN_SCEPTILITE_SECRET" }) do
  assert(secretCalls[index].secret == expectedSecret, "wrong shared secret identity at index " .. index)
end
print("hidden_evolution_campaign_headless_playthrough: PASS (" .. #expected .. " maps)")
