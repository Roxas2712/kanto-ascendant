-- Phase-4 headless contract for the native 1-6 predecessor trail.

local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local function factory(name) return assert(loadfile(root .. "/" .. name))() end

local edition = "red"
local gameVersion = {
  get = function() return edition end,
  isYellow = function() return edition == "yellow" end,
}
package.preload["src.core.GameVersion"] = function() return gameVersion end
local partner
local yellowPartner = { partner = function() return partner end }
local selection = factory("follower_selection.lua")({
  gameVersion = gameVersion, yellowPartner = yellowPartner,
})

local function mon(species, hp)
  return { species = species, hp = hp or 30, dvs = {} }
end

local raichu, espeon, scizor, tyranitar, lapras, charizard =
  mon("RAICHU"), mon("ESPEON"), mon("SCIZOR"), mon("TYRANITAR"),
  mon("LAPRAS"), mon("CHARIZARD")
local game = {
  save = {
    party = { raichu, espeon, scizor, tyranitar, lapras, charizard },
    flags = {},
  },
  data = { pokemon = {}, sprites = { SPRITE_PIKACHU = {
    id = "SPRITE_PIKACHU", image = "sheet", frames = 6,
    walker = true, trueColor = true,
  } } },
  mods = { exports = {} },
}
for _, candidate in ipairs(game.save.party) do
  game.data.pokemon[candidate.species] = { name = candidate.species }
end

local selected = selection.activeMany(game, 6)
assert(#selected == 6 and selected[1].mon == raichu
  and selected[6].mon == charizard, "Red PARTY order is not stable")
raichu.hp = 0
selected = selection.activeMany(game, 6)
assert(#selected == 5 and selected[1].mon == espeon,
  "unhealthy party members must be skipped without duplication")
raichu.hp = 30

edition = "yellow"
partner = scizor
selected = selection.activeMany(game, 6)
assert(#selected == 6 and selected[1].mon == scizor,
  "Yellow partner must lead the chain")
local partnerCount = 0
for _, row in ipairs(selected) do if row.mon == partner then partnerCount = partnerCount + 1 end end
assert(partnerCount == 1, "Yellow partner was duplicated")
partner = nil
assert(#selection.activeMany(game, 6) == 0,
  "Yellow must not promote an unrelated party member over a missing partner")
edition, partner = "red", nil

-- Minimal engine-shaped transport. The controller patches this exact
-- `shouldSpawn` upvalue, keeps the first follower in ow.npcs and manages
-- followers 2-6 as passable draw-only entities.
local function npcNew(_, mapId, def)
  local npc = {
    id = mapId .. "_obj_" .. def.index, def = def,
    cellX = def.x, cellY = def.y, px = def.x * 16, py = def.y * 16,
    facing = "down", moving = false, progress = 0, passable = false,
  }
  function npc:update()
    if not self.moving then return end
    self.progress = self.progress + 1
    local frames = self.stepFrames or 16
    if self.progress >= frames then
      self.cellX, self.cellY = self.targetX, self.targetY
      self.px, self.py = self.cellX * 16, self.cellY * 16
      self.targetX, self.targetY = nil, nil
      self.moving, self.hopStep, self.progress = false, nil, 0
    end
  end
  function npc:facePlayer(player)
    self.facing = player.cellX > self.cellX and "right"
      or player.cellX < self.cellX and "left"
      or player.cellY > self.cellY and "down" or "up"
  end
  return npc
end

package.preload["src.world.NPC"] = function() return { new = npcNew } end
package.preload["src.render.SpriteRenderer"] = function()
  return { new = function(def, id) return { def = def, id = id, image = def.image } end }
end

local current
local forceFollowerOverlap = false
local failNativeUpdate = false
local shouldSpawn = function(activeGame, ow)
  local save = activeGame and activeGame.save or {}
  if not gameVersion.isYellow() or save.pikachuInBall == true
      or save.onBike or ow.player.surfing then return false end
  if not (save.flags and save.flags.EVENT_GOT_STARTER) then return false end
  if save.pikachuInBall == nil
      and not save.flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB then return false end
  for _, candidate in ipairs(save.party or {}) do
    if candidate.species == "PIKACHU" and (candidate.hp or 0) > 0 then return true end
  end
  return false
end
local Follower = {}
local function removeValue(list, wanted)
  for i, value in ipairs(list or {}) do
    if value == wanted then table.remove(list, i) return end
  end
end
function Follower.current() return current end
function Follower.onMapEntered(activeGame, ow, opts)
  if os.getenv("KA_TEST_SANDBOX_0186") == "1" then
    -- Engine updates may add future scene caches. The eligibility proxy must
    -- keep every such write local instead of changing the live game/save.
    activeGame._sandboxTransportWrite = true
    activeGame.save._sandboxTransportWrite = true
  end
  if current then
    removeValue(ow.npcs, current)
    removeValue(ow.entities, current)
  end
  if not shouldSpawn(activeGame, ow) then current = nil return end
  current = opts and opts.keepPikachu or npcNew(activeGame.data, ow.map.id, {
    index = 15, x = ow.player.cellX,
    y = forceFollowerOverlap and ow.player.cellY or ow.player.cellY + 1,
  })
  current.pikachuFollower, current.passable = true, true
  ow.npcs[#ow.npcs + 1], ow.entities[#ow.entities + 1] = current, current
  ow._phase4Trail = { x = ow.player.cellX, y = ow.player.cellY }
end
function Follower.update(activeGame, ow)
  if failNativeUpdate then error("sandbox transport probe", 0) end
  if not current then
    if shouldSpawn(activeGame, ow) then Follower.onMapEntered(activeGame, ow) end
    return
  end
  if not shouldSpawn(activeGame, ow) then
    removeValue(ow.npcs, current)
    removeValue(ow.entities, current)
    current = nil
    return
  end
  local p, trail = ow.player, ow._phase4Trail
  local x, y = p.targetX or p.cellX, p.targetY or p.cellY
  if not current.moving and (x ~= trail.x or y ~= trail.y) then
    current.targetX, current.targetY = trail.x, trail.y
    current.facing = current.targetX > current.cellX and "right"
      or current.targetX < current.cellX and "left"
      or current.targetY > current.cellY and "down" or "up"
    current.moving, current.progress, current.stepFrames = true, 0, 16
    trail.x, trail.y = x, y
  elseif not current.moving then
    -- Reproduce PikachuFollower's Yellow-only idle transport: an in-place
    -- spin plus a pixel offset. Generic followers must neutralize both.
    current.idle = { kind = "spin", frames = 31 }
    current.facing = current.facing == "down" and "left" or "down"
    current.px = current.cellX * 16 + 3
  end
end
function Follower.rebase(ow, dx, dy)
  if current then
    current.cellX, current.cellY = current.cellX + dx, current.cellY + dy
    current.px, current.py = current.px + dx * 16, current.py + dy * 16
    if current.targetX then current.targetX = current.targetX + dx end
    if current.targetY then current.targetY = current.targetY + dy end
  end
  local t = ow._phase4Trail
  if t then t.x, t.y = t.x + dx, t.y + dy end
end
function Follower.setVisible(ow, visible)
  removeValue(ow.entities, current)
  if visible and current then ow.entities[#ow.entities + 1] = current end
end
local originalTalkCalls = 0
function Follower.talk(_, _, _, done)
  originalTalkCalls = originalTalkCalls + 1
  if done then done() end
end
package.preload["src.world.PikachuFollower"] = function() return Follower end
local interactionCalls, worldInteractions = 0, {}
local Overworld = {}
local function cellMatch(npc, x, y)
  return (npc.cellX == x and npc.cellY == y)
    or (npc.targetX == x and npc.targetY == y)
end
function Overworld.interact(self)
  interactionCalls = interactionCalls + 1
  local x, y = self.player:facingCell()
  for _, npc in ipairs(self.npcs or {}) do
    if cellMatch(npc, x, y) then
      if npc.pikachuFollower then Follower.talk(game, self, npc) end
      return "native"
    end
  end
  return "native"
end
local baseOverworldInteract = Overworld.interact
package.preload["src.world.OverworldController"] = function() return Overworld end
package.preload["src.mods.Runtime"] = function()
  return { emit = function(name, payload)
    worldInteractions[#worldInteractions + 1] = { name = name, payload = payload }
  end }
end
local genericTalkCry, genericTalkText
local genericTalkPushes = 0
package.preload["src.core.Sound"] = function()
  return { playCry = function(_, species) genericTalkCry = species end }
end
package.preload["src.core.Strings"] = function()
  return setmetatable({}, { __call = function(_, fmt, ...) return fmt:format(...) end })
end
package.preload["src.render.TextBox"] = function()
  return { new = function(_, text, done)
    genericTalkPushes = genericTalkPushes + 1
    genericTalkText = text
    return { text = text, done = done }
  end }
end

local blockedCells = {}
local map = {
  id = "PHASE4_MAP",
  inBounds = function(_, x, y) return x > -100 and y > -100 end,
  isWalkableCell = function(_, x, y) return not blockedCells[x .. ":" .. y] end,
  warpAtCell = function() return nil end,
}
game.overworld = {
  map = map,
  player = { cellX = 10, cellY = 10, px = 160, py = 160, facing = "down" },
  npcs = {}, entities = {},
}
function game.overworld.player:facingCell()
  local dx = self.facing == "left" and -1 or self.facing == "right" and 1 or 0
  local dy = self.facing == "up" and -1 or self.facing == "down" and 1 or 0
  return self.cellX + dx, self.cellY + dy
end
game.stack = { push = function(_, value) game.lastPushed = value end }
game.overworld.entities[1] = game.overworld.player

local sharedDef = game.data.sprites.SPRITE_PIKACHU
local sprites = {
  spriteId = "SPRITE_PIKACHU",
  resolve = function(_, candidate) return candidate and "sheet_" .. candidate.species end,
  configure = function(_, candidate)
    if not candidate then return nil end
    sharedDef.image = "sheet_" .. candidate.species
    return sharedDef, sharedDef.image
  end,
  invalidate = function() end,
}
local callbacks = {}
local controllerMod = {
  events = { on = function(_, name, callback) callbacks[name] = callback end },
  log = { info = function() end, error = function(_, message) error(message) end },
}
local savedDebug = debug
if os.getenv("KA_TEST_SANDBOX_0186") == "1" then _G.debug = nil end
local controller = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = sprites, yellowPartner = yellowPartner,
})
assert(controller.install(game), "Phase-4 controller did not install")

if os.getenv("KA_TEST_SANDBOX_0186") == "1" then
  assert(game._sandboxTransportWrite == nil
      and game.save._sandboxTransportWrite == nil,
    "sandbox follower eligibility proxy leaked a native write")
  local entryWrapper = Follower.onMapEntered
  local isYellow = gameVersion.isYellow
  failNativeUpdate = true
  local ok, message = pcall(Follower.update, game, game.overworld)
  failNativeUpdate = false
  assert(not ok and tostring(message):find("sandbox transport probe", 1, true),
    "sandbox transport error did not propagate")
  assert(gameVersion.isYellow == isYellow,
    "sandbox transport did not restore GameVersion.isYellow after error")
  assert(Follower.onMapEntered == entryWrapper,
    "sandbox transport did not restore map-entry callback after error")
end

local redIdle = controller.entities(game)[1]
local redFacing = redIdle.facing
Follower.update(game, game.overworld)
assert(redIdle.facing == redFacing and redIdle.idle == nil,
  "generic Red follower inherited the Pikachu spin idle")
assert(redIdle.px == redIdle.cellX * 16 and redIdle.py == redIdle.cellY * 16,
  "generic Red follower retained a Pikachu idle pixel offset")

-- A warp may land in a one-row cliff approach: the native first-follower
-- transport then cannot use the cell directly behind the player and used to
-- overlap the player as ROUTE_22_obj_99.  Ascendant must choose the first
-- free lateral cell, not leave a duplicate Wilds occupancy owner.
forceFollowerOverlap = true
blockedCells["10:9"], blockedCells["10:11"] = true, true
game.overworld.player.facing = "up"
Follower.onMapEntered(game, game.overworld, {})
local repaired = controller.entities(game)[1]
assert(repaired.cellX == 9 and repaired.cellY == 10,
  "blocked-behind warp did not place follower on deterministic free side")
assert(not (repaired.cellX == game.overworld.player.cellX
    and repaired.cellY == game.overworld.player.cellY),
  "blocked-behind warp retained player/follower occupancy conflict")
assert(repaired.px == repaired.cellX * 16 and repaired.py == repaired.cellY * 16
    and not repaired.moving and repaired.targetX == nil and repaired.targetY == nil,
  "repaired warp follower retained stale movement state")
forceFollowerOverlap = false
blockedCells["10:9"], blockedCells["10:11"] = nil, nil

local function frame()
  for _, npc in ipairs(game.overworld.npcs) do npc:update() end
  Follower.update(game, game.overworld)
end

local function assertChain(expected, label)
  local chain = controller.entities(game)
  assert(#chain == #expected, label .. ": wrong chain count " .. #chain)
  local seen = {}
  for i, species in ipairs(expected) do
    assert(chain[i].followerSpecies == species,
      ("%s: index %d expected %s, got %s"):format(
        label, i, species, tostring(chain[i].followerSpecies)))
    assert(not seen[chain[i].followerMon], label .. ": duplicate party object")
    seen[chain[i].followerMon] = true
    assert(chain[i].passable, label .. ": follower became blocking")
    if i > 1 then
      assert(not chain[i].pikachuFollower,
        label .. ": extra follower became a second Yellow story entity")
      assert(not (function()
        for _, npc in ipairs(game.overworld.npcs) do if npc == chain[i] then return true end end
      end)(), label .. ": extra follower leaked into interactive NPCs")
    end
  end
  return chain
end

local transitions = {
  { 1, { "RAICHU" } },
  { 2, { "RAICHU", "ESPEON" } },
  { 6, { "RAICHU", "ESPEON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD" } },
  { 1, { "RAICHU" } },
  { 3, { "RAICHU", "ESPEON", "SCIZOR" } },
  { 5, { "RAICHU", "ESPEON", "SCIZOR", "TYRANITAR", "LAPRAS" } },
  { 1, { "RAICHU" } },
  { 6, { "RAICHU", "ESPEON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD" } },
}
for _, row in ipairs(transitions) do
  controller.setCount(row[1], game)
  assertChain(row[2], "runtime count " .. row[1])
end

-- Real A-button production seam: extras stay out of ow.npcs, but the
-- versioned Overworld.interact wrapper resolves the exact visible follower
-- on the directly faced cell before delegating every non-match to native.
local interactionChain = controller.entities(game)
local extra = interactionChain[2]
local oldExtra = {
  cellX = extra.cellX, cellY = extra.cellY, px = extra.px, py = extra.py,
  targetX = extra.targetX, targetY = extra.targetY,
  species = espeon.species, nickname = espeon.nickname,
  bond = espeon.johtoBond,
}
espeon.species, espeon.nickname, espeon.johtoBond = "TOGEPI", "TWO", 100
game.data.pokemon.TOGEPI = {
  name = "TOGEPI",
  evolutions = { { method = "FRIENDSHIP", species = "TOGETIC" } },
}
controller.refresh(game)
extra = controller.entities(game)[2]
game.overworld.player.facing = "right"
extra.cellX, extra.cellY = game.overworld.player.cellX + 1,
  game.overworld.player.cellY
extra.px, extra.py = extra.cellX * 16, extra.cellY * 16
extra.targetX, extra.targetY, extra.moving = nil, nil, false
local interactionsBefore = interactionCalls
local bondBefore = espeon.johtoBond
genericTalkCry, genericTalkText = nil, nil
Overworld.interact(game.overworld)
assert(interactionCalls == interactionsBefore,
  "extra follower A press incorrectly delegated to native interact")
assert(genericTalkCry == "TOGEPI" and genericTalkText
    and genericTalkText:find("TWO", 1, true)
    and genericTalkText:find("looks very", 1, true),
  "real A path did not address follower #2's exact friendship mon")
assert(espeon.johtoBond == bondBefore,
  "real A path mutated follower #2 friendship")
local emitted = worldInteractions[#worldInteractions]
assert(emitted and emitted.name == "world.interacted"
    and emitted.payload.kind == "npc" and emitted.payload.target == extra,
  "extra follower A path omitted native world.interacted semantics")

-- A real map/native NPC on the same faced cell remains authoritative.
local blocker = { cellX = extra.cellX, cellY = extra.cellY, def = {} }
game.overworld.npcs[#game.overworld.npcs + 1] = blocker
genericTalkCry, genericTalkText = nil, nil
Overworld.interact(game.overworld)
assert(interactionCalls == interactionsBefore + 1
    and genericTalkText == nil,
  "extra follower stole A from a native NPC")
table.remove(game.overworld.npcs, #game.overworld.npcs)

espeon.species, espeon.nickname, espeon.johtoBond =
  oldExtra.species, oldExtra.nickname, oldExtra.bond
controller.refresh(game)
extra = controller.entities(game)[2]
extra.cellX, extra.cellY, extra.px, extra.py =
  oldExtra.cellX, oldExtra.cellY, oldExtra.px, oldExtra.py
extra.targetX, extra.targetY = oldExtra.targetX, oldExtra.targetY

-- Every chain index resolves through the real installed Overworld/Follower
-- wrappers to its own party object. #1 deliberately delegates to native;
-- #2-6 deliberately do not.
local mapped = {
  { mon = raichu, species = "GOLBAT", nickname = "A-ONE", bond = 0,
    phrase = "seems wary", target = "CROBAT", method = "FRIENDSHIP" },
  { mon = espeon, species = "TOGEPI", nickname = "A-TWO", bond = 50,
    phrase = "is starting", target = "TOGETIC", method = "FRIENDSHIP" },
  { mon = scizor, species = "CHANSEY", nickname = "A-THREE", bond = 100,
    phrase = "looks very", target = "BLISSEY", method = "FRIENDSHIP" },
  { mon = tyranitar, species = "EEVEE", nickname = "A-FOUR", bond = 200,
    phrase = "completely", target = "ESPEON", method = "FRIENDSHIP_DAY" },
  { mon = lapras, species = "PICHU", nickname = "A-FIVE", bond = 50,
    phrase = "is starting", target = "PIKACHU", method = "FRIENDSHIP" },
  { mon = charizard, species = "IGGLYBUFF", nickname = "A-SIX", bond = 200,
    phrase = "completely", target = "JIGGLYPUFF", method = "FRIENDSHIP" },
}
local mappedOld = {}
for index, row in ipairs(mapped) do
  mappedOld[index] = {
    species = row.mon.species, nickname = row.mon.nickname,
    bond = row.mon.johtoBond,
  }
  row.mon.species, row.mon.nickname, row.mon.johtoBond =
    row.species, row.nickname, row.bond
  game.data.pokemon[row.species] = game.data.pokemon[row.species] or {
    name = row.species,
    evolutions = { { method = row.method, species = row.target } },
  }
end
controller.refresh(game)
local mappedChain = controller.entities(game)
local mappedPositions = {}
for index, npc in ipairs(mappedChain) do
  mappedPositions[index] = {
    cellX = npc.cellX, cellY = npc.cellY, px = npc.px, py = npc.py,
    targetX = npc.targetX, targetY = npc.targetY, moving = npc.moving,
  }
end
for wanted, row in ipairs(mapped) do
  for index, npc in ipairs(mappedChain) do
    npc.cellX, npc.cellY = game.overworld.player.cellX + 5 + index,
      game.overworld.player.cellY + 5
    npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
    npc.targetX, npc.targetY, npc.moving = nil, nil, false
  end
  local target = mappedChain[wanted]
  target.cellX, target.cellY = game.overworld.player.cellX + 1,
    game.overworld.player.cellY
  target.px, target.py = target.cellX * 16, target.cellY * 16
  game.overworld.player.facing = "right"
  local nativeBefore = interactionCalls
  local before = row.mon.johtoBond
  genericTalkCry, genericTalkText = nil, nil
  Overworld.interact(game.overworld)
  assert(genericTalkCry == row.species and genericTalkText
      and genericTalkText:find(row.nickname, 1, true)
      and genericTalkText:find(row.phrase, 1, true),
    "real A path mapped the wrong Pokemon at follower " .. wanted)
  assert(interactionCalls == nativeBefore + (wanted == 1 and 1 or 0),
    "wrong native delegation count at follower " .. wanted)
  assert(row.mon.johtoBond == before,
    "real A path mutated friendship at follower " .. wanted)
end
for index, row in ipairs(mapped) do
  row.mon.species, row.mon.nickname, row.mon.johtoBond =
    mappedOld[index].species, mappedOld[index].nickname, mappedOld[index].bond
end
controller.refresh(game)
mappedChain = controller.entities(game)
for index, npc in ipairs(mappedChain) do
  local old = mappedPositions[index]
  npc.cellX, npc.cellY, npc.px, npc.py = old.cellX, old.cellY, old.px, old.py
  npc.targetX, npc.targetY, npc.moving =
    old.targetX, old.targetY, old.moving
end

-- Straight steps, corners, a reversal and U-turns. Every link must stay on
-- predecessor-vacated cells while all queues/history stay bounded.
local dirs = {
  { 1, 0, "right" }, { 0, -1, "up" }, { -1, 0, "left" },
  { 1, 0, "right" }, { 0, 1, "down" }, { 0, -1, "up" },
}
for repeatIndex = 1, 12 do
  for _, d in ipairs(dirs) do
    local p = game.overworld.player
    p.facing, p.targetX, p.targetY = d[3], p.cellX + d[1], p.cellY + d[2]
    frame()
    p.cellX, p.cellY = p.targetX, p.targetY
    p.px, p.py = p.cellX * 16, p.cellY * 16
    p.targetX, p.targetY = nil, nil
    for _ = 1, 20 do frame() end
  end
end
local fullParty = {
  "RAICHU", "ESPEON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD",
}
local chain = assertChain(fullParty,
  "mixed movement")
local movement = assert(controller.movement(game), "movement state missing")
assert(#movement.history <= 64 and #movement.chainHistory <= 64,
  "movement history grew without a bound")
for _, queue in pairs(movement.queues) do
  assert(#queue <= 64, "predecessor queue grew without a bound")
end
for i = 2, #chain do
  local gap = math.abs(chain[i].cellX - chain[i - 1].cellX)
    + math.abs(chain[i].cellY - chain[i - 1].cellY)
  assert(gap <= 1, "progressive chain drift at follower " .. i .. ": " .. gap)
end

-- Evolution refreshes art on the same object; removing a member destroys the
-- unused identity instead of leaving a stale entity.
local oldSecond = chain[2]
espeon.species = "UMBREON"
game.data.pokemon.UMBREON = { name = "UMBREON" }
controller.refresh(game)
chain = assertChain({
  "RAICHU", "UMBREON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD",
}, "evolution")
assert(chain[2] == oldSecond and chain[2].followerSprite == "sheet_UMBREON",
  "evolution replaced identity or retained stale art")
table.remove(game.save.party, 3) -- Scizor
controller.refresh(game)
chain = assertChain({
  "RAICHU", "UMBREON", "TYRANITAR", "LAPRAS", "CHARIZARD",
}, "party removal")

-- Configured count may exceed valid party size without dummies/duplicates.
game.save.party = { raichu, espeon }
controller.setCount(6, game)
assertChain({ "RAICHU", "UMBREON" }, "short party")
game.save.party = { raichu, espeon, scizor, tyranitar, lapras, charizard }
controller.refresh(game)
chain = assertChain({
  "RAICHU", "UMBREON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD",
}, "party restore")

-- Seam keeps the same instances and rebases every queued coordinate. A warp
-- reconstructs clean entities in the same species order.
local beforeSeam = { unpack(chain) }
-- Simulate a link whose last old-map landing frame is interrupted by the
-- connection swap. Seam reconstruction must close that permanent hole.
chain[3].cellY = chain[3].cellY + 2
chain[3].py = chain[3].cellY * 16
Follower.onMapEntered(game, game.overworld, { keepPikachu = chain[1] })
Follower.rebase(game.overworld, 20, 7)
chain = assertChain({
  "RAICHU", "UMBREON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD",
}, "seam")
for i = 1, 6 do assert(chain[i] == beforeSeam[i], "seam replaced follower " .. i) end
for i = 2, 6 do
  local gap = math.abs(chain[i].cellX - chain[i - 1].cellX)
    + math.abs(chain[i].cellY - chain[i - 1].cellY)
  assert(gap <= 1, "seam reconstruction retained a stretched link " .. i)
end
local old = { unpack(chain) }
Follower.onMapEntered(game, game.overworld, {})
chain = assertChain({
  "RAICHU", "UMBREON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD",
}, "warp")
assert(chain[1] ~= old[1] and chain[2] ~= old[2], "warp retained stale entities")
for _, stale in ipairs(old) do
  assert(not (function()
    for _, entity in ipairs(game.overworld.entities) do if entity == stale then return true end end
  end)(), "stale pre-warp entity remained in draw list")
end

Follower.setVisible(game.overworld, false)
for _, follower in ipairs(chain) do
  assert(not (function()
    for _, entity in ipairs(game.overworld.entities) do if entity == follower then return true end end
  end)(), "hidden chain member remained visible")
end
Follower.setVisible(game.overworld, true)
assertChain({
  "RAICHU", "UMBREON", "SCIZOR", "TYRANITAR", "LAPRAS", "CHARIZARD",
}, "show restore")

-- A mod hot reload installs a fresh controller before the old instance is
-- explicitly restored. The versioned state must remove the first wrapper
-- rather than chaining it, then the replacement must restore all engine
-- surfaces and both state keys to their original values.
local firstInteractWrapper = Overworld.interact
local replacementController = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = sprites, yellowPartner = yellowPartner,
})
assert(replacementController.install(game),
  "direct install-over-install replacement failed")
assert(not controller.active and Overworld.interact ~= firstInteractWrapper,
  "hot reload retained the old controller or interaction wrapper")
replacementController.setCount(6, game)
local replacementChain = replacementController.entities(game)
for index, npc in ipairs(replacementChain) do
  npc.cellX, npc.cellY = game.overworld.player.cellX + 5 + index,
    game.overworld.player.cellY + 5
  npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
  npc.targetX, npc.targetY, npc.moving = nil, nil, false
end
local replacementExtra = assert(replacementChain[2],
  "hot reload did not rebuild follower #2")
replacementExtra.cellX, replacementExtra.cellY =
  game.overworld.player.cellX + 1, game.overworld.player.cellY
replacementExtra.px, replacementExtra.py = replacementExtra.cellX * 16,
  replacementExtra.cellY * 16
game.overworld.player.facing = "right"
local hotNativeBefore, hotEventsBefore, hotPushesBefore =
  interactionCalls, #worldInteractions, genericTalkPushes
genericTalkCry, genericTalkText = nil, nil
Overworld.interact(game.overworld)
assert(interactionCalls == hotNativeBefore
    and #worldInteractions == hotEventsBefore + 1
    and genericTalkPushes == hotPushesBefore + 1
    and genericTalkCry == replacementExtra.followerSpecies,
  "hot reload produced a chained/missing interaction")
replacementController.restore()
assert(Overworld.interact == baseOverworldInteract
    and rawget(Overworld, "__kantoAscendantFollowerInteraction") == nil
    and rawget(Follower, "__kantoAscendantNativeSingleFollower") == nil,
  "hot reload restore retained an interaction/follower state wrapper")

-- Yellow uses exactly one marked partner as follower #1; extras never enter
-- the legacy interactive follower slot. Only Pikachu/Raichu/Gorochu in that
-- exact partner slot owns Yellow's authored mood/portrait conversation.
edition, partner = "yellow", scizor
scizor.hp = 30
game.save.party = { raichu, espeon, scizor, tyranitar, lapras, charizard }
game.overworld.npcs, game.overworld.entities = {}, { game.overworld.player }
current = nil
local yellowController = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = sprites, yellowPartner = yellowPartner,
})
assert(yellowController.install(game), "Yellow chain controller did not install")
yellowController.setCount(6, game)
chain = yellowController.entities(game)
assert(#chain == 6 and chain[1].followerMon == scizor,
  "Yellow partner did not lead six-follower chain")
partnerCount = 0
for _, npc in ipairs(chain) do if npc.followerMon == scizor then partnerCount = partnerCount + 1 end end
assert(partnerCount == 1, "Yellow partner duplicated in live chain")
local legacyCount = 0
for _, npc in ipairs(game.overworld.npcs) do if npc.pikachuFollower then legacyCount = legacyCount + 1 end end
assert(legacyCount == 1, "Yellow created multiple legacy story followers")
local yellowNonPikaFacing = chain[1].facing
Follower.update(game, game.overworld)
assert(chain[1].facing == yellowNonPikaFacing and chain[1].idle == nil,
  "Yellow non-Pikachu partner inherited the classic spin idle")
genericTalkCry, genericTalkText = nil, nil
Follower.talk(game, game.overworld, chain[1], function() end)
assert(originalTalkCalls == 0,
  "Yellow non-Pikachu partner inherited Pikachu's special talk")
assert(genericTalkCry == "SCIZOR"
    and genericTalkText and genericTalkText:find("SCIZOR", 1, true),
  "Yellow non-Pikachu partner lost species-aware generic talk")
partner = raichu
game.save.party = { raichu, espeon, scizor, tyranitar, lapras, charizard }
raichu.johtoBond = 137
for _, evolved in ipairs({ "RAICHU", "GOROCHU" }) do
  raichu.species = evolved
  game.data.pokemon[evolved] = { name = evolved }
  yellowController.refresh(game)
  local evolvedFollower = yellowController.entities(game)[1]
  local specialBefore = originalTalkCalls
  genericTalkCry, genericTalkText = nil, nil
  Follower.talk(game, game.overworld, evolvedFollower, function() end)
  assert(evolvedFollower.followerSpecies == evolved
      and evolvedFollower.followerSprite == "sheet_" .. evolved,
    evolved .. " evolution retained stale Yellow follower art")
  assert(originalTalkCalls == specialBefore + 1
      and genericTalkCry == nil and genericTalkText == nil,
    evolved .. " exact Yellow partner lost its special portrait talk")
  assert(raichu.johtoBond == 137,
    evolved .. " portrait talk reset friendship data")
end
raichu.hp = 0
assert(#selection.activeMany(game, 6) == 0,
  "fainted evolved Yellow partner was replaced by a generic follower")
raichu.hp = 30
game.save.party = { espeon, scizor, tyranitar, lapras, charizard }
assert(#selection.activeMany(game, 6) == 0,
  "boxed evolved Yellow partner was replaced by a generic follower")
game.save.party = { raichu, espeon, scizor, tyranitar, lapras, charizard }
assert(#selection.activeMany(game, 6) == 6
    and selection.activeMany(game, 6)[1].mon == raichu
    and raichu.johtoBond == 137,
  "withdrawing evolved Yellow partner lost identity/friendship")
raichu.species = "RAICHU"
partner = scizor
scizor.species, scizor.johtoBond = "TOGEPI", 100
game.data.pokemon.TOGEPI = {
  name = "TOGEPI",
  evolutions = { { method = "FRIENDSHIP", species = "TOGETIC" } },
}
yellowController.refresh(game)
local yellowFriendshipFollower = yellowController.entities(game)[1]
local friendshipBefore = originalTalkCalls
genericTalkCry, genericTalkText = nil, nil
Follower.talk(game, game.overworld, yellowFriendshipFollower, function() end)
assert(originalTalkCalls == friendshipBefore and genericTalkCry == "TOGEPI"
    and genericTalkText and genericTalkText:find("looks very", 1, true),
  "Yellow non-Pikachu friendship follower lost qualitative feedback")
yellowController.restore()

-- Discord regression: a Raichu elsewhere in Yellow's party must neither
-- impersonate the selected non-Pikachu partner nor create a second copy of
-- that partner.  The exact reported shape was RAICHU + BLASTOISE.
local blastoise = mon("BLASTOISE")
game.data.pokemon.BLASTOISE = { name = "BLASTOISE" }
game.save.party, partner = { raichu, blastoise }, blastoise
game.overworld.npcs, game.overworld.entities = {}, { game.overworld.player }
current = nil
local raichuIsolation = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = sprites, yellowPartner = yellowPartner,
})
assert(raichuIsolation.install(game),
  "Yellow Raichu-isolation controller did not install")
raichuIsolation.setCount(1, game)
local isolated = raichuIsolation.entities(game)
assert(#isolated == 1 and isolated[1].followerMon == blastoise
    and isolated[1].followerSpecies == "BLASTOISE",
  "party Raichu replaced or duplicated the selected Blastoise follower")
genericTalkCry, genericTalkText = nil, nil
Follower.talk(game, game.overworld, isolated[1], function() end)
assert(genericTalkCry == "BLASTOISE"
    and genericTalkText and genericTalkText:find("BLASTOISE", 1, true)
    and not genericTalkText:find("RAICHU", 1, true),
  "party Raichu leaked into Blastoise follower text/cry")
local isolatedLegacyCount = 0
for _, npc in ipairs(game.overworld.npcs) do
  if npc.pikachuFollower then isolatedLegacyCount = isolatedLegacyCount + 1 end
end
assert(isolatedLegacyCount == 1,
  "Raichu plus Blastoise created two legacy follower entities")
raichuIsolation.restore()

-- Species alone never grants Yellow's authored face/mood path. A temporary
-- unmarked Pikachu fallback remains an ordinary generic follower until the
-- partner identity controller has stamped the actual Oak partner.
local strayPikachu = mon("PIKACHU")
game.save.party, partner = { strayPikachu }, nil
game.save.flags.EVENT_GOT_STARTER = true
game.overworld.npcs, game.overworld.entities = {}, { game.overworld.player }
current = nil
local strayController = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = sprites, yellowPartner = yellowPartner,
})
assert(strayController.install(game),
  "Yellow stray-Pikachu controller did not install")
local stray = assert(strayController.entities(game)[1],
  "Yellow stray Pikachu did not enter the generic fallback")
local straySpecialBefore = originalTalkCalls
genericTalkCry, genericTalkText = nil, nil
Follower.talk(game, game.overworld, stray, function() end)
assert(originalTalkCalls == straySpecialBefore
    and genericTalkCry == "PIKACHU" and genericTalkText
    and genericTalkText:find("is now\nfollowing you!", 1, true),
  "unmarked Pikachu gained the authored Yellow partner conversation")
strayController.restore()
game.save.flags.EVENT_GOT_STARTER = nil

-- Exact Yellow Pikachu keeps the authored Yellow personality poses.
local pikachu = mon("PIKACHU")
game.data.pokemon.PIKACHU = { name = "PIKACHU" }
local yellowTogepi = mon("TOGEPI")
yellowTogepi.nickname, yellowTogepi.johtoBond = "Y-TWO", 200
game.save.party, partner = { pikachu, yellowTogepi }, pikachu
game.overworld.npcs, game.overworld.entities = {}, { game.overworld.player }
current = nil
local classicController = factory("single_follower.lua")(controllerMod, {
  selection = selection, sprites = sprites, yellowPartner = yellowPartner,
})
assert(classicController.install(game), "classic Yellow controller did not install")
classicController.setCount(2, game)
local classic = classicController.entities(game)[1]
local yellowExtra = classicController.entities(game)[2]
Follower.update(game, game.overworld)
assert(classic.idle and classic.idle.kind == "spin",
  "exact Yellow Pikachu lost its classic personality idle")
assert(classic.px ~= classic.cellX * 16,
  "exact Yellow Pikachu idle offset was incorrectly suppressed")
local yellowOriginalBefore = originalTalkCalls
local yellowNativeBefore = interactionCalls
game.overworld.player.facing = "right"
yellowExtra.cellX, yellowExtra.cellY = game.overworld.player.cellX + 1,
  game.overworld.player.cellY
yellowExtra.px, yellowExtra.py = yellowExtra.cellX * 16, yellowExtra.cellY * 16
yellowExtra.targetX, yellowExtra.targetY, yellowExtra.moving = nil, nil, false
genericTalkCry, genericTalkText = nil, nil
Overworld.interact(game.overworld)
assert(interactionCalls == yellowNativeBefore
    and originalTalkCalls == yellowOriginalBefore
    and genericTalkCry == "TOGEPI" and genericTalkText
    and genericTalkText:find("Y-TWO", 1, true)
    and genericTalkText:find("completely", 1, true),
  "Yellow's real A path did not reach friendship follower #2")
assert(yellowTogepi.johtoBond == 200,
  "Yellow extra interaction mutated friendship")

-- Facing native Pikachu delegates into the original mood handler; the extra
-- seam never intercepts or appends a second dialogue.
classic.cellX, classic.cellY = game.overworld.player.cellX - 1,
  game.overworld.player.cellY
classic.px, classic.py = classic.cellX * 16, classic.cellY * 16
classic.targetX, classic.targetY, classic.moving = nil, nil, false
game.overworld.player.facing = "left"
genericTalkCry, genericTalkText = nil, nil
Overworld.interact(game.overworld)
assert(interactionCalls == yellowNativeBefore + 1
    and originalTalkCalls == yellowOriginalBefore + 1
    and genericTalkText == nil,
  "exact Yellow Pikachu lost its untouched native A-talk path")
classicController.restore()
assert(Overworld.interact == baseOverworldInteract
    and rawget(Overworld, "__kantoAscendantFollowerInteraction") == nil,
  "interaction wrapper did not clean up on restore")

_G.debug = savedDebug

print("PASS follower Phase-4: counts 1-6 predecessor chain mixed species transitions Yellow talk dedupe"
  .. (os.getenv("KA_TEST_SANDBOX_0186") == "1" and " sandbox-0.1.86" or ""))
