-- Guarded real-LÖVE acceptance for Phase 2's native single follower.
-- Run independently with POKEPORT_VERSION=red, blue and yellow in the
-- dedicated follower-phase2 identity.  It writes only reserved slot 6202.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Evolution = require("src.pokemon.Evolution")
  local Boxes = require("src.pokemon.Boxes")
  local SaveData = require("src.core.SaveData")
  local Follower = require("src.world.PikachuFollower")
  local Map = require("src.world.Map")

  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  assert(identity:find("follower%-phase2"),
    "refusing to write outside follower-phase2 identity")
  assert(GameVersion.get() == version, "wrong ROM cache mounted")
  assert(SaveData.setActiveSlot(version, "slot6202") == "slot6202")

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local native = assert(exports.singleFollower, "native follower export unavailable")
  local yellowPartner = assert(exports.yellowPartner, "Yellow adapter unavailable")
  assert(native.active, "native follower controller was not installed")
  assert(not native.external, "unexpected external follower override")

  game.save.flags = game.save.flags or {}
  -- Keep Pallet's pre-starter Oak escort from taking control of the boundary
  -- walk used below; the follower test supplies its party directly.
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike = false
  game.save.repelSteps = 9999
  game.save.player.name = "PHASE2"

  local species = ({ red = "BULBASAUR", blue = "SQUIRTLE",
                      yellow = "PIKACHU" })[version]
  local evolved = ({ red = "IVYSAUR", blue = "WARTORTLE",
                      yellow = "RAICHU" })[version]
  local expectedDex = ({ red = 2, blue = 8, yellow = 26 })[version]
  local lead = Pokemon.new(game.data, species, 24)
  if version == "yellow" then
    lead[yellowPartner.marker] = true
    game.save.flags.EVENT_GOT_STARTER = true
  end
  game.save.party = { lead }

  local function countFollowers(ow)
    local count
    count = 0
    for _, npc in ipairs(ow and ow.npcs or {}) do
      if npc.pikachuFollower then count = count + 1 end
    end
    return count
  end

  local function current(label)
    local entity = native.entity(game)
    assert(entity, label .. ": follower missing")
    assert(countFollowers(game.overworld) == 1,
      label .. ": expected exactly one follower")
    assert(entity._ascendantNativeFollower == true,
      label .. ": entity is not native-owned")
    return entity
  end

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(20)
  local original = current("initial spawn")
  assert(native.activeMon(game) == lead, "selected object identity is wrong")
  assert(original.followerSpecies == species, "initial species is wrong")

  -- Find an L-shaped walkable corner and walk it in both directions. This
  -- covers movement, turning, backtracking and rapid direction changes using
  -- the real input path rather than direct coordinate edits.
  local dirs = {
    { "up", 0, -1 }, { "down", 0, 1 },
    { "left", -1, 0 }, { "right", 1, 0 },
  }
  local opposite = { up = "down", down = "up", left = "right", right = "left" }
  local sx, sy, first, second
  local map = game.overworld.map
  for y = 2, map.heightCells - 3 do
    for x = 2, map.widthCells - 3 do
      if map:isWalkableCell(x, y) and not game.overworld:npcAtCell(x, y) then
        for _, a in ipairs(dirs) do
          for _, b in ipairs(dirs) do
            if a[2] * b[2] + a[3] * b[3] == 0
                and map:isWalkableCell(x + a[2], y + a[3])
                and map:isWalkableCell(x + a[2] + b[2], y + a[3] + b[3]) then
              sx, sy, first, second = x, y, a[1], b[1]
              break
            end
          end
          if first then break end
        end
      end
      if first then break end
    end
    if first then break end
  end
  assert(first and second, "no walkable L corner found")
  U.teleport(game, "PALLET_TOWN", sx, sy, first)
  U.wait(20)
  original = current("corner reset")

  local function walkOne(dir)
    local p = game.overworld.player
    local bx, by = p.cellX, p.cellY
    for _ = 1, 64 do
      table.insert(game.input.pressQueue, dir)
      game.input.state[dir] = true
      coroutine.yield()
      if p.cellX ~= bx or p.cellY ~= by then break end
    end
    game.input.state[dir] = false
    assert(p.cellX ~= bx or p.cellY ~= by, "input step failed: " .. dir)
    U.wait(20)
    local entity = current("walk " .. dir)
    assert(entity == original, "ordinary movement replaced follower entity")
    local gap = math.abs(entity.cellX - p.cellX) + math.abs(entity.cellY - p.cellY)
    assert(gap == 1, "follower did not settle one cell behind: " .. tostring(gap))
  end

  walkOne(first)
  walkOne(second)
  walkOne(opposite[second])
  walkOne(opposite[first])
  local movement = assert(native.movement(game), "movement history missing")
  assert(#movement.history >= 4, "corner/backtrack history was not recorded")

  -- A real seamless route connection must carry the same instance.
  U.teleport(game, "PALLET_TOWN", 10, 3, "up")
  U.wait(20)
  local ow = game.overworld
  map = ow.map
  local function exitOK(cx)
    for cy = 0, 3 do
      if not map:isWalkableCell(cx, cy) then return false end
      local at = ow:npcAtCell(cx, cy)
      if at and not at.pikachuFollower then return false end
    end
    local keep = ow.player.cellX
    ow.player.cellX = cx
    local dest, tileset, x, y = ow:connectionLanding("up")
    ow.player.cellX = keep
    return dest and dest.id == "ROUTE_1"
      and Map.defPassable(dest, tileset, x, y, false)
  end
  local column
  for x = 0, map.widthCells - 1 do if exitOK(x) then column = x break end end
  assert(column, "no passable Pallet/Route 1 connection column")
  U.teleport(game, "PALLET_TOWN", column, 3, "up")
  U.wait(20)
  local seamEntity = current("before connection")
  for _ = 1, 240 do
    table.insert(game.input.pressQueue, "up")
    game.input.state.up = true
    coroutine.yield()
    if game.overworld.map.id == "ROUTE_1" then break end
  end
  game.input.state.up = false
  assert(game.overworld.map.id == "ROUTE_1", "route connection did not complete")
  U.wait(24)
  assert(current("after connection") == seamEntity,
    "seamless connection replaced the follower")

  -- Evolution updates the same selected individual and swaps its actual art.
  Evolution.apply(game, lead, evolved, "FOLLOWER_PHASE2_E2E")
  U.wait(5)
  local evolvedEntity = current("after evolution")
  assert(native.activeMon(game) == lead, "evolution changed selected identity")
  assert(evolvedEntity.followerSpecies == evolved,
    "evolution did not refresh visible species")
  assert(evolvedEntity.followerSprite:match(
    ("follower_%03d%%.png$"):format(expectedDex)),
    "evolution did not load species-authentic Kanto sheet")
  if version == "yellow" then
    Evolution.apply(game, lead, "GOROCHU", "FOLLOWER_PHASE2_E2E")
    evolved = "GOROCHU"
    U.wait(5)
    evolvedEntity = current("after Gorochu evolution")
    assert(evolvedEntity.followerSpecies == "GOROCHU"
      and evolvedEntity.followerSprite:match("follower_GOROCHU%.png$"),
      "Yellow partner did not render actual Gorochu state")
  end

  -- Reorder/deposit/withdraw/faint transitions. Yellow remains bound to its
  -- marked partner; Red/Blue always follow the current first healthy member.
  local other = Pokemon.new(game.data, "CATERPIE", 12)
  game.save.party = { other, lead }
  U.wait(4)
  if version == "yellow" then
    assert(native.activeMon(game) == lead, "Yellow partner changed on reorder")
  else
    assert(native.activeMon(game) == other, "PARTY mode ignored new slot 1")
    assert(current("after reorder").followerSpecies == "CATERPIE")
  end

  for _, candidate in ipairs(game.save.party) do candidate.hp = 0 end
  U.wait(4)
  assert(native.entity(game) == nil, "all-fainted party did not hide follower")
  lead.hp = math.max(1, lead.stats and lead.stats.hp or 1)
  U.wait(4)
  assert(current("after revive").followerSpecies == evolved,
    "revived valid follower did not return")

  local leadIndex
  for i, candidate in ipairs(game.save.party) do
    if candidate == lead then leadIndex = i break end
  end
  table.remove(game.save.party, assert(leadIndex))
  assert(Boxes.deposit(game.save, lead), "could not deposit follower")
  U.wait(4)
  if version == "yellow" then
    assert(native.entity(game) == nil, "boxed Yellow partner was replaced")
  end
  table.insert(game.save.party, 1, lead)
  local box = game.save.boxes[game.save.currentBox]
  for i, candidate in ipairs(box) do
    if candidate == lead then table.remove(box, i) break end
  end
  U.wait(4)
  assert(current("after withdrawal").followerSpecies == evolved,
    "withdrawn follower did not return")

  -- Real door warp: warp rebuild may respawn, but it must produce one correct
  -- entity inside and one on return with no stale duplicate.
  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(10)
  ow = game.overworld
  local outside = ow.map.id
  local entry
  for _, warp in ipairs(ow.map.def.warps or {}) do
    if warp.destMap and warp.destMap ~= "LAST_MAP" then entry = warp break end
  end
  assert(entry, "Pallet has no interior door warp")
  ow.player.cellX, ow.player.cellY = entry.x, entry.y
  ow:takeWarp(entry)
  for _ = 1, 240 do
    if ow.map.id ~= outside and not ow.transitioning then break end
    coroutine.yield()
  end
  assert(ow.map.id ~= outside, "door warp did not enter interior")
  current("inside door")
  local interior = ow.map.id
  local exit
  for _, warp in ipairs(ow.map.def.warps or {}) do
    if warp.destMap == "LAST_MAP" or warp.destMap == outside then exit = warp break end
  end
  assert(exit, interior .. " has no return warp")
  ow.player.cellX, ow.player.cellY = exit.x, exit.y
  ow:takeWarp(exit)
  for _ = 1, 240 do
    if ow.map.id == outside and not ow.transitioning then break end
    coroutine.yield()
  end
  assert(ow.map.id == outside, "door warp did not return outside")
  current("outside door")

  if version == "yellow" then
    local entity = current("Yellow interaction")
    local beforeHappiness = tonumber(game.save.pikachuHappiness) or 90
    Follower.modifyHappiness(game.save, "USEDTMHM", lead)
    assert((tonumber(game.save.pikachuHappiness) or 0) > beforeHappiness,
      "evolved Yellow partner no longer receives happiness events")

    Follower.setVisible(game.overworld, false)
    local visible = false
    for _, candidate in ipairs(game.overworld.entities or {}) do
      if candidate == entity then visible = true break end
    end
    assert(not visible, "scripted Yellow disappearance did not hide follower")
    Follower.setVisible(game.overworld, true)
    local visibleCount = 0
    for _, candidate in ipairs(game.overworld.entities or {}) do
      if candidate == entity then visibleCount = visibleCount + 1 end
    end
    assert(visibleCount == 1,
      "scripted Yellow reappearance duplicated or lost follower")

    Follower.talk(game, game.overworld, entity, function() end)
    assert(game.overworld.emote,
      "Yellow evolved-partner interaction did not start its story reaction")
    game.overworld.emote = nil

    -- Bill's map script must still take ownership of the same generic entity
    -- for its canonical confused-partner scene, then release it on map exit.
    game.save.flags.EVENT_MET_BILL_2 = nil
    U.teleport(game, "BILLS_HOUSE", 3, 8, "up")
    U.wait(4)
    assert(game.overworld.pikachuBillsScene == true,
      "Bill's House did not start the Yellow partner scene")
    assert(countFollowers(game.overworld) == 1,
      "Bill's House scene duplicated the Yellow follower")
    U.teleport(game, "PALLET_TOWN", 10, 8, "down")
    U.wait(4)
    assert(not game.overworld.pikachuBillsScene,
      "Yellow scripted scene state leaked across maps")
    current("after Bill scene")
  end

  game.save._followerPhase2Probe = {
    version = version, species = lead.species,
    partner = version == "yellow" and lead[yellowPartner.marker] == true,
  }
  assert(game:writeSave(), "native save write failed")
  local loaded = assert(SaveData.load(version), "native save reload failed")
  assert(loaded._followerPhase2Probe
      and loaded._followerPhase2Probe.species == evolved,
    "Phase-2 save probe did not survive reload")
  if version == "yellow" then
    local found
    for _, candidate in ipairs(loaded.party or {}) do
      if candidate[yellowPartner.marker] then found = candidate break end
    end
    assert(found and found.species == evolved,
      "Yellow partner identity/evolution did not survive save reload")
  end

  local shotDir = os.getenv("SHOT_DIR") or "/tmp/follower-phase2"
  assert(U.shot(game, shotDir .. "/" .. version .. "-native-follower.png"),
    "acceptance screenshot failed")
  U.log("FOLLOWER PHASE 2 E2E PASS", version,
    "single entity corner backtrack seam evolution party box warp save")
  love.event.quit(0)
end
