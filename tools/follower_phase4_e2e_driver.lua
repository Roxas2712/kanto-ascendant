-- Guarded real-LÖVE acceptance for Phase 4's native 1-4 follower chain.
-- Run independently with POKEPORT_VERSION=red, blue and yellow in a
-- dedicated follower-phase4 identity. It writes only reserved slot 6404.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Evolution = require("src.pokemon.Evolution")
  local SaveData = require("src.core.SaveData")
  local Follower = require("src.world.PikachuFollower")
  local Map = require("src.world.Map")

  local version = assert(os.getenv("POKEPORT_VERSION"), "edition required")
  local identity = assert(os.getenv("POKEPORT_IDENTITY"), "identity required")
  U.wait(2)
  assert(identity:find("follower%-phase4"),
    "refusing to write outside follower-phase4 identity")
  assert(GameVersion.get() == version, "wrong ROM cache mounted")
  assert(SaveData.setActiveSlot(version, "slot6404") == "slot6404")

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant exports unavailable")
  local native = assert(exports.singleFollower, "native follower export unavailable")
  local yellowPartner = assert(exports.yellowPartner, "Yellow adapter unavailable")
  assert(native.active and not native.external,
    "native follower chain was not installed")
  assert(native.getCount() == 1, "Phase-4 default is not one follower")

  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB = true
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_GOT_POKEDEX = true
  game.save.onBike = false
  game.save.repelSteps = 9999
  game.save.player.name = "PHASE4"

  local raichu = Pokemon.new(game.data, "RAICHU", 30)
  local espeon = Pokemon.new(game.data, "ESPEON", 30)
  local scizor = Pokemon.new(game.data, "SCIZOR", 30)
  local tyranitar = Pokemon.new(game.data, "TYRANITAR", 30)
  if version == "yellow" then raichu[yellowPartner.marker] = true end
  game.save.party = { raichu, espeon, scizor, tyranitar }

  local expected = { "RAICHU", "ESPEON", "SCIZOR", "TYRANITAR" }

  local function inList(list, wanted)
    for _, value in ipairs(list or {}) do if value == wanted then return true end end
    return false
  end

  local function legacyCount()
    local count = 0
    for _, npc in ipairs(game.overworld and game.overworld.npcs or {}) do
      if npc.pikachuFollower then count = count + 1 end
    end
    return count
  end

  local function assertChain(count, species, label)
    local chain = native.entities(game)
    assert(#chain == count,
      ("%s: expected %d followers, got %d"):format(label, count, #chain))
    assert(count == 0 or legacyCount() == 1,
      label .. ": expected exactly one engine/Yellow story follower")
    local seen = {}
    for index, entity in ipairs(chain) do
      assert(entity.followerSpecies == species[index],
        ("%s: follower %d expected %s, got %s"):format(
          label, index, species[index], tostring(entity.followerSpecies)))
      assert(entity.passable == true, label .. ": follower became blocking")
      assert(not seen[entity.followerMon], label .. ": party member duplicated")
      seen[entity.followerMon] = true
      assert(entity.sprite and entity.sprite.def
          and entity.sprite.def.frames == 6 and entity.sprite.def.walker
          and entity.sprite.def.trueColor,
        label .. ": follower is not a true-colour six-pose walker")
      local width, height = entity.sprite.image:getDimensions()
      assert(width == 16 and height == 96,
        ("%s: follower %d sheet is %dx%d"):format(label, index, width, height))
      if index > 1 then
        assert(not entity.pikachuFollower,
          label .. ": extra follower became a second story follower")
        assert(not inList(game.overworld.npcs, entity),
          label .. ": extra follower leaked into interactive NPCs")
      end
    end
    return chain
  end

  U.teleport(game, "PALLET_TOWN", 10, 8, "down")
  U.wait(12)

  local transitions = {
    { 1, { "RAICHU" } },
    { 2, { "RAICHU", "ESPEON" } },
    { 4, expected },
    { 1, { "RAICHU" } },
    { 3, { "RAICHU", "ESPEON", "SCIZOR" } },
    { 2, { "RAICHU", "ESPEON" } },
    { 1, { "RAICHU" } },
    { 4, expected },
  }
  for _, transition in ipairs(transitions) do
    assert(native.setCount(transition[1], game) == transition[1],
      "count setter rejected " .. transition[1])
    U.wait(2)
    assertChain(transition[1], transition[2],
      "runtime transition to " .. transition[1])
  end

  -- Locate an actual walkable L corner with enough clear cells behind the
  -- chosen facing for the complete chain, then use the real input path.
  local dirs = {
    { "up", 0, -1 }, { "down", 0, 1 },
    { "left", -1, 0 }, { "right", 1, 0 },
  }
  local opposite = { up = "down", down = "up", left = "right", right = "left" }
  local sx, sy, first, second
  local map = game.overworld.map
  for y = 4, map.heightCells - 5 do
    for x = 4, map.widthCells - 5 do
      if map:isWalkableCell(x, y) and not game.overworld:npcAtCell(x, y) then
        for _, a in ipairs(dirs) do
          local clearBehind = true
          for distance = 1, 4 do
            if not map:isWalkableCell(x - a[2] * distance, y - a[3] * distance)
                or game.overworld:npcAtCell(
                  x - a[2] * distance, y - a[3] * distance) then
              clearBehind = false
              break
            end
          end
          if clearBehind and map:isWalkableCell(x + a[2], y + a[3]) then
            for _, b in ipairs(dirs) do
              if a[2] * b[2] + a[3] * b[3] == 0
                  and map:isWalkableCell(x + a[2] + b[2], y + a[3] + b[3]) then
                sx, sy, first, second = x, y, a[1], b[1]
                break
              end
            end
          end
          if first then break end
        end
      end
      if first then break end
    end
    if first then break end
  end
  assert(first and second, "no four-follower L-corner test position found")
  local shotDir = os.getenv("SHOT_DIR") or "/tmp/follower-phase4"

  local function prefix(count, source)
    local result = {}
    for index = 1, count do result[index] = source[index] end
    return result
  end

  local function assertProgressive(count, species, label)
    local chain = assertChain(count, species, label)
    for index = 2, #chain do
      local gap = math.abs(chain[index].cellX - chain[index - 1].cellX)
        + math.abs(chain[index].cellY - chain[index - 1].cellY)
      if gap > 1 then
        local positions = {}
        for chainIndex, member in ipairs(chain) do
          local queue = native.movement(game).queues[chainIndex] or {}
          positions[#positions + 1] = ("#%d=%d,%d>%s,%s m=%s p=%s q=%d"):format(
            chainIndex, member.cellX, member.cellY,
            tostring(member.targetX), tostring(member.targetY),
            tostring(member.moving), tostring(member.progress), #queue)
        end
        local recent = {}
        local history = native.movement(game).chainHistory or {}
        for h = math.max(1, #history - 11), #history do
          local row = history[h]
          recent[#recent + 1] = ("#%d:%d,%d>%d,%d"):format(
            row.index, row.fromX, row.fromY, row.toX, row.toY)
        end
        error(("%s: link %d drifted by %d cells (%s; trail %s)"):format(
          label, index, gap, table.concat(positions, " "),
          table.concat(recent, " ")))
      end
    end
    return chain
  end

  local function walkOne(direction, count, species, instances, label)
    local player = game.overworld.player
    local beforeX, beforeY = player.cellX, player.cellY
    for _ = 1, 64 do
      table.insert(game.input.pressQueue, direction)
      game.input.state[direction] = true
      coroutine.yield()
      if player.cellX ~= beforeX or player.cellY ~= beforeY then break end
    end
    game.input.state[direction] = false
    assert(player.cellX ~= beforeX or player.cellY ~= beforeY,
      "input step failed: " .. direction)
    U.wait(22)
    local chain = assertProgressive(count, species,
      label or ("walk " .. direction .. " with count " .. count))
    for index = 1, count do
      if instances then
        assert(chain[index] == instances[index],
          "ordinary movement replaced follower " .. index)
      end
    end
    local movement = assert(native.movement(game), "movement state missing")
    assert(#movement.history <= 64 and #movement.chainHistory <= 64,
      "movement history is unbounded")
    for _, queue in pairs(movement.queues or {}) do
      assert(#queue <= 64, "predecessor queue is unbounded")
    end
    return chain
  end

  local function routeTransition(count, species)
    U.teleport(game, "PALLET_TOWN", 10, 3, "up")
    U.wait(20)
    local ow = game.overworld
    local routeMap = ow.map
    local function exitOK(cx)
      for cy = 0, 3 do
        if not routeMap:isWalkableCell(cx, cy) then return false end
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
    for x = 0, routeMap.widthCells - 1 do
      if exitOK(x) then column = x break end
    end
    assert(column, "no passable Pallet/Route 1 connection column")
    U.teleport(game, "PALLET_TOWN", column, 3, "up")
    U.wait(20)
    local before = { unpack(assertChain(count, species,
      "before route seam count " .. count)) }
    for _ = 1, 240 do
      table.insert(game.input.pressQueue, "up")
      game.input.state.up = true
      coroutine.yield()
      if game.overworld.map.id == "ROUTE_1" then break end
    end
    game.input.state.up = false
    assert(game.overworld.map.id == "ROUTE_1",
      "route seam did not complete for count " .. count)
    U.wait(24)
    local after = assertProgressive(count, species,
      "after route seam count " .. count)
    for index = 1, count do
      assert(after[index] == before[index],
        ("route seam replaced follower %d at count %d"):format(index, count))
    end
  end

  local function buildingRoundTrip(count, species)
    U.teleport(game, "PALLET_TOWN", 10, 8, "down")
    U.wait(10)
    local ow = game.overworld
    local outside = ow.map.id
    local before = { unpack(assertChain(count, species,
      "before door count " .. count)) }
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
    assert(ow.map.id ~= outside,
      "door warp did not enter interior for count " .. count)
    U.wait(8)
    local inside = assertChain(count, species, "inside door count " .. count)
    for _, stale in ipairs(before) do
      assert(not inList(ow.entities, stale),
        "stale pre-warp follower remained visible")
    end
    if count > 1 then
      assert(inside[1] ~= before[1] and inside[2] ~= before[2],
        "normal warp retained stale chain identities")
    else
      assert(inside[1] ~= before[1], "normal warp retained stale follower identity")
    end

    local interior = ow.map.id
    local exit
    for _, warp in ipairs(ow.map.def.warps or {}) do
      if warp.destMap == "LAST_MAP" or warp.destMap == outside then
        exit = warp
        break
      end
    end
    assert(exit, interior .. " has no return warp")
    ow.player.cellX, ow.player.cellY = exit.x, exit.y
    ow:takeWarp(exit)
    for _ = 1, 240 do
      if ow.map.id == outside and not ow.transitioning then break end
      coroutine.yield()
    end
    assert(ow.map.id == outside,
      "door warp did not return outside for count " .. count)
    U.wait(8)
    assertChain(count, species, "outside door count " .. count)
  end

  local function caveWalk(count, species)
    U.teleport(game, "ROCK_TUNNEL_1F", 15, 5, "down")
    U.wait(16)
    assertChain(count, species, "Rock Tunnel entry count " .. count)
    local cavePlayer = game.overworld.player
    local caveDirection
    for _, direction in ipairs(dirs) do
      if game.overworld.map:isWalkableCell(
          cavePlayer.cellX + direction[2], cavePlayer.cellY + direction[3])
          and not game.overworld:npcAtCell(
            cavePlayer.cellX + direction[2], cavePlayer.cellY + direction[3]) then
        caveDirection = direction[1]
        break
      end
    end
    assert(caveDirection, "Rock Tunnel test cell has no walkable neighbor")
    walkOne(caveDirection, count, species, nil,
      "Rock Tunnel walk count " .. count)
  end

  -- Complete the required movement/transition matrix independently for every
  -- supported count rather than only proving that each count can spawn.
  for count = 1, 4 do
    local species = prefix(count, expected)
    native.setCount(count, game)
    U.teleport(game, "PALLET_TOWN", sx, sy, first)
    U.wait(20)
    local instances = { unpack(assertChain(count, species,
      "corner reset count " .. count)) }
    if count == 4 then
      assert(U.shot(game, shotDir .. "/" .. version .. "-mixed-chain.png"),
        "mixed-chain screenshot failed")
    end
    walkOne(first, count, species, instances)
    walkOne(second, count, species, instances)
    walkOne(opposite[second], count, species, instances)
    walkOne(opposite[first], count, species, instances)
    routeTransition(count, species)
    buildingRoundTrip(count, species)
    caveWalk(count, species)
  end

  -- Current bike policy hides the full chain and recreates it cleanly after
  -- dismount; this must never leave extras behind.
  game.save.onBike = true
  U.wait(4)
  assert(#native.entities(game) == 0, "bike left a follower-chain fragment")
  game.save.onBike = false
  native.refresh(game)
  U.wait(6)
  assertChain(4, expected, "after dismount")

  -- Evolution refreshes the same party identity and real sprite. Removing a
  -- party member or configuring more followers than available makes no dummy.
  Evolution.apply(game, espeon, "UMBREON", "FOLLOWER_PHASE4_E2E")
  U.wait(6)
  local evolved = { "RAICHU", "UMBREON", "SCIZOR", "TYRANITAR" }
  assertChain(4, evolved, "after evolution")
  table.remove(game.save.party, 3)
  U.wait(4)
  assertChain(3, { "RAICHU", "UMBREON", "TYRANITAR" }, "after removal")
  game.save.party = { raichu, espeon }
  U.wait(4)
  assertChain(2, { "RAICHU", "UMBREON" }, "party smaller than count")
  game.save.party = { raichu, espeon, scizor, tyranitar }
  U.wait(4)
  assertChain(4, evolved, "party restored")

  if version == "yellow" then
    assert(native.activeMon(game) == raichu,
      "Yellow marked partner no longer leads the chain")
    Follower.setVisible(game.overworld, false)
    for _, entity in ipairs(native.entities(game)) do
      assert(not inList(game.overworld.entities, entity),
        "Yellow scripted hide left a chain member visible")
    end
    Follower.setVisible(game.overworld, true)
    assertChain(4, evolved, "Yellow scripted show")

    game.save.flags.EVENT_MET_BILL_2 = nil
    U.teleport(game, "BILLS_HOUSE", 3, 8, "up")
    U.wait(6)
    assert(game.overworld.pikachuBillsScene == true,
      "Bill's House did not retain Yellow's special partner scene")
    assert(legacyCount() == 1, "Bill's House duplicated the story follower")
    local visibleExtras = 0
    for _, entity in ipairs(native.entities(game)) do
      if entity._ascendantChainIndex and entity._ascendantChainIndex > 1
          and inList(game.overworld.entities, entity) then
        visibleExtras = visibleExtras + 1
      end
    end
    assert(visibleExtras == 0,
      "Bill's House scene did not hide the non-story chain members")
    U.teleport(game, "PALLET_TOWN", 10, 8, "down")
    U.wait(6)
    assertChain(4, evolved, "after Bill scene")
  end

  game.save._followerPhase4Probe = {
    version = version, count = native.getCount(),
    species = { raichu.species, espeon.species, scizor.species, tyranitar.species },
  }
  assert(game:writeSave(), "Phase-4 save write failed")
  assert(U.shot(game, shotDir .. "/" .. version .. "-final-chain.png"),
    "final-chain screenshot failed")
  U.log("FOLLOWER PHASE 4 E2E PASS", version,
    "counts movement seam door cave bike evolution removal Yellow scripts")
  love.event.quit(0)
end
