-- Exact-package structural/runtime receipt for the complete HEVO campaign.
-- Run this through POKEPORT_DRIVER after the final .love and installed mod
-- have booted. It reads the merged live registries and exports; no fixture
-- state, puzzle, item, seal or user save is modified.
return function(game)
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing HEVO contract outside the immutable package gate")
  local root = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export is missing from packaged runtime")
  local campaign = assert(api.hiddenEvolutionCampaign,
    "packaged Hidden Evolution campaign is missing")
  local architecture = assert(campaign.modules and campaign.modules.tunnel,
    "packaged character tunnel architecture is missing")
  assert(campaign.encounters and campaign.encounters._installed,
    "packaged HEVO encounter controller never installed")
  assert(game.renderer
      and type(game.renderer.queueWorldPostOverlay) == "function",
    "packaged renderer lacks the mandatory world-post overlay")
  local okDecals, WallDecals = pcall(require, "src.world.WallDecals")
  assert(okDecals and WallDecals and type(WallDecals.draw) == "function",
    "packaged engine lacks wall-local fissure rendering")
  local voxelDecals = assert(api.dramalessWallDecalsCompat,
    "packaged DRAMALESS wall-decal compatibility export is missing")
  assert(voxelDecals.installed == true
      and (voxelDecals.mode == "adapter" or voxelDecals.mode == "native")
      and voxelDecals.lastError == nil,
    "packaged Voxel wall decals are inactive: "
      .. tostring(voxelDecals.mode) .. "/" .. tostring(voxelDecals.lastError))

  local RuntimeMap = require("src.world.Map")
  local mapIds = {
    "KA_HEVO_TUNNEL_ALL",
    "KA_HEVO_RED_UPPER", "KA_HEVO_RED_ABYSS",
    "KA_HEVO_RED_RECOVERY", "KA_HEVO_RED_LOWER",
    "KA_HEVO_RED_SHRINE",
    "KA_HEVO_BLUE_FROST_THRESHOLD", "KA_HEVO_BLUE_FROST_HALL",
    "KA_HEVO_BLUE_GLACIER_MAZE", "KA_HEVO_BLUE_TIDAL_DEPTHS",
    "KA_HEVO_BLUE_KYOGRE_SHRINE",
    "KA_HEVO_GREEN_THRESHOLD", "KA_HEVO_GREEN_GROVE",
    "KA_HEVO_GREEN_MIST", "KA_HEVO_GREEN_RAYQUAZA_SHRINE",
    "KA_HEVO_SHARED_SEALED_ANTECHAMBER",
  }
  local surface = {
    KA_HEVO_TUNNEL_ALL={0,0,0,0,3},
    KA_HEVO_RED_UPPER={8,5,2,0,2},
    KA_HEVO_RED_ABYSS={4,2,2,0,2},
    KA_HEVO_RED_RECOVERY={3,1,0,1,6},
    KA_HEVO_RED_LOWER={6,4,1,0,2},
    KA_HEVO_RED_SHRINE={3,1,0,1,2},
    KA_HEVO_BLUE_FROST_THRESHOLD={0,0,0,0,2},
    KA_HEVO_BLUE_FROST_HALL={4,4,1,2,2},
    KA_HEVO_BLUE_GLACIER_MAZE={6,6,2,3,2},
    KA_HEVO_BLUE_TIDAL_DEPTHS={5,5,2,2,2},
    KA_HEVO_BLUE_KYOGRE_SHRINE={4,4,0,3,2},
    KA_HEVO_GREEN_THRESHOLD={3,2,0,2,0},
    KA_HEVO_GREEN_GROVE={10,10,2,8,0},
    KA_HEVO_GREEN_MIST={11,9,3,6,0},
    KA_HEVO_GREEN_RAYQUAZA_SHRINE={4,4,0,4,0},
    KA_HEVO_SHARED_SEALED_ANTECHAMBER={1,1,0,0,3},
  }
  local cavernLadderCells = {
    [61]={{1,1}}, [62]={{1,1}}, [97]={{1,0}}, [98]={{1,1}},
    [124]={{1,1}}, [127]={{0,1}},
  }
  local ladderCount = 0
  for _, id in ipairs(mapIds) do
    local def = assert(game.data.maps[id], "missing packaged map " .. id)
    local expected = assert(surface[id], "missing package surface row " .. id)
    assert(game.data.audio and game.data.audio.mapSongs
        and game.data.audio.mapSongs[id] == "Music_KA_DeepEvolution",
      id .. " does not own its direct-load/reload dungeon music")
    assert(def.voxelMode == "FULL" and def.voxelCells == nil
        and def.outdoor == false,
      id .. " lost its terrain-derived FULL/indoor contract")
    local visible, statues, items, mapLadders = 0, 0, 0, 0
    for _, object in ipairs(def.objects or {}) do
      if object.renderMode ~= "none" then visible = visible + 1 end
      if object.sprite == "SPRITE_KA_HEVO_QUIZ_STATUE"
          and object.semanticRole == "quiz_statue" then
        statues = statues + 1
      elseif object.sprite == "SPRITE_POKE_BALL" then
        items = items + 1
      end
    end
    assert(#(def.objects or {}) == expected[1]
        and visible == expected[2]
        and statues == expected[3]
        and items == expected[4],
      id .. " packaged object/statue/item inventory drifted")
    if def.tileset == "CAVERN" then
      local runtime = RuntimeMap.new(def, assert(game.data.tilesets.CAVERN))
      for by=0,def.height-1 do for bx=0,def.width-1 do
        local block = def.blocks[by*def.width+bx+1]
        for _, cell in ipairs(cavernLadderCells[block] or {}) do
          local x,y=bx*2+cell[1],by*2+cell[2]
          assert(runtime:warpAtCell(x,y),
            id .. " contains a decorative/nonfunctional ladder at "
              .. x .. "," .. y)
          mapLadders = mapLadders + 1
          ladderCount = ladderCount + 1
        end
      end end
    end
    assert(mapLadders == expected[5],
      id .. " packaged native-ladder inventory drifted")
  end

  local routes = {
    RED={map="ROUTE_22",x=35,y=1},
    BLUE={map="ROUTE_24",x=10,y=3},
    GREEN={map="ROUTE_3",x=41,y=3},
  }
  for character, site in pairs(routes) do
    local decals = assert(game.data.maps[site.map]).wallDecals or {}
    local found = 0
    for _, decal in ipairs(decals) do
      if decal.id == "KA_HEVO_WALL_FISSURE_" .. character then
        found = found + 1
        assert(decal.cellX == site.x and decal.cellY == site.y
            and decal.face == "south"
            and decal.image:find("sealed_fissure.png", 1, true),
          character .. " packaged fissure has the wrong wall placement/art")
      end
    end
    assert(found == 1, character .. " needs exactly one wall fissure")
  end

  local mapsByCharacter = campaign.encounters.MAPS
  local itemObjects = {
    RED={KA_RED_BLAZIKENITE_SECRET=true,KA_RED_RESEARCH_CACHE=true},
    BLUE={KA_HEVO_BLUE_SWAMPERTITE_CACHE=true,KA_HEVO_BLUE_REWARD_CACHE=true},
    GREEN={KA_GREEN_SCEPTILITE_SECRET=true,KA_GREEN_RESEARCH_CACHE=true},
  }
  for _, character in ipairs({"RED","BLUE","GREEN"}) do
    local statues, foreignQuiz, floorLights, items = 0, {}, 0, {}
    local prefix = character == "RED" and "KA_RED_STATUE_"
      or character == "BLUE" and "KA_HEVO_BLUE_STATUE_"
      or "KA_GREEN_STATUE_"
    for _, mapId in ipairs(assert(mapsByCharacter[character])) do
      for _, object in ipairs(assert(game.data.maps[mapId]).objects or {}) do
        local statue = tostring(object.name):find(prefix, 1, true) == 1
        local visibleQuiz = object.sprite == "SPRITE_KA_HEVO_QUIZ_STATUE"
          and object.semanticRole == "quiz_statue"
          and object.renderMode ~= "none"
        if statue then
          statues = statues + 1
          assert(visibleQuiz and object.passable ~= true,
            object.name .. " lost its unique blocking quiz-statue art")
        elseif visibleQuiz then
          foreignQuiz[#foreignQuiz+1] = object.name
        end
        if object.semanticRole == "floor_light" then
          assert(object.sprite == "SPRITE_KA_EVOLUTION_RELIC"
              and object.passable == false,
            object.name .. " lost its solid yellow floor-light contract")
          floorLights = floorLights + 1
        end
        if itemObjects[character][object.name] then
          assert(object.sprite == "SPRITE_POKE_BALL",
            object.name .. " must read as a tangible item, not another relic")
          items[object.name] = true
        end
      end
    end
    assert(statues == 5,
      character .. " exposes " .. statues .. " quiz statues instead of five")
    assert(#foreignQuiz == 0,
      character .. " reuses quiz art on " .. table.concat(foreignQuiz, ","))
    local expectedLights=({RED=9,BLUE=12,GREEN=9})[character]
    assert(floorLights == expectedLights,
      character .. " exposes " .. floorLights .. " floor lights instead of "
        .. expectedLights)
    for name in pairs(itemObjects[character]) do
      assert(items[name], character .. " is missing tangible item " .. name)
    end
  end

  -- Exercise the actual packaged destination guard for all nine identity /
  -- trial combinations. Own destinations are unchanged; every foreign trial
  -- fails closed into that character's isolated shaft, never a wrong shrine.
  local negativeCount = 0
  for _, character in ipairs({"RED","BLUE","GREEN"}) do
    local save = { player={map="PALLET_TOWN"}, modData={kanto_ascendant={
      extended_characters={player_character=character},
    }}, flags={} }
    for owner, maps in pairs(mapsByCharacter) do
      local destination = maps[1]
      local map,x,y = architecture.resolveCharacterTrialWarp(
        destination, 7, 9, save)
      if owner == character then
        assert(map == destination and x == 7 and y == 9,
          character .. " was rejected from its own trial")
      else
        local entry = architecture.branches[character].entry
        assert(map == architecture.sharedTunnel and x == entry.x and y == entry.y,
          character .. " reached foreign " .. owner .. " content")
        negativeCount = negativeCount + 1
      end
    end
  end
  assert(negativeCount == 6, "foreign-shrine negative matrix is incomplete")

  -- Exhaust every packaged trial map, not only each first floor.  A foreign
  -- destination recovers an incomplete character to its isolated shaft and a
  -- completed character to its own safe shrine.  Then exercise load-time
  -- recovery for all twelve foreign-shrine/incomplete-or-complete saves that
  -- previously produced the reported deadlocks.
  local trialMatrix = 0
  local shrineIds = {
    RED="KA_HEVO_RED_SHRINE", BLUE="KA_HEVO_BLUE_KYOGRE_SHRINE",
    GREEN="KA_HEVO_GREEN_RAYQUAZA_SHRINE",
  }
  for _, character in ipairs({"RED","BLUE","GREEN"}) do
    for trialOwner, maps in pairs(mapsByCharacter) do
      for _, destination in ipairs(maps) do
        local save={flags={},player={map=campaign.modules.shared.ID},
          modData={kanto_ascendant={extended_characters={
            player_character=character,
          }}}}
        local map,x,y=architecture.resolveCharacterTrialWarp(
          destination,99,97,save)
        if trialOwner==character then
          assert(map==destination and x==99 and y==97,
            character.." own packaged trial map was rewritten: "..destination)
          trialMatrix=trialMatrix+1
        else
          local entry=architecture.branches[character].entry
          assert(map==architecture.sharedTunnel and x==entry.x and y==entry.y,
            character.." incomplete save entered foreign "..destination)
          trialMatrix=trialMatrix+1
          save.modData.kanto_ascendant.hevo_run={
            dungeonLegacy={seals={[character]=true}},
          }
          map,x,y=architecture.resolveCharacterTrialWarp(
            destination,99,97,save)
          local safe=architecture.shrineReturns[character]
          assert(map==safe.map and x==safe.x and y==safe.y,
            character.." completed save was not recovered from "..destination)
          trialMatrix=trialMatrix+1
        end
      end
    end
  end
  assert(trialMatrix==70, "full packaged trial-isolation matrix is incomplete")

  local shrineRecoveries=0
  for _, character in ipairs({"RED","BLUE","GREEN"}) do
    for destinationOwner,destination in pairs(shrineIds) do
      if destinationOwner~=character then
        for _,completed in ipairs({false,true}) do
          local bucket={extended_characters={player_character=character}}
          if completed then bucket.hevo_run={
            dungeonLegacy={seals={[character]=true}},
          } end
          local save={flags={},player={map=destination,x=37,y=3,
            facing="up",surfing=true},modData={kanto_ascendant=bucket}}
          local changed,key=architecture.migrateSaveLocation(save)
          local target=completed and architecture.shrineReturns[character]
            or architecture.branches[character].entry
          assert(changed and key==character
              and save.player.map==(completed and target.map
                or architecture.sharedTunnel)
              and save.player.x==target.x and save.player.y==target.y
              and save.player.surfing==false
              and save.flags[architecture.flags.entered..character]==true,
            character.." packaged foreign-shrine save recovery failed from "
              ..destinationOwner.." completed="..tostring(completed))
          shrineRecoveries=shrineRecoveries+1
        end
      end
    end
  end
  assert(shrineRecoveries==12,
    "packaged foreign-shrine load-recovery matrix is incomplete")

  local file = assert(io.open(root .. "/hevo_package_contract_receipt.txt", "wb"))
  file:write("HEVO PACKAGE CONTRACT PASS\n")
  file:write("campaign=RED+BLUE+GREEN installed\n")
  file:write("renderer=world-post-overlay+wall-decals\n")
  file:write("voxel_wall_decals=", tostring(voxelDecals.mode), "\n")
  file:write("fissures=RED@ROUTE_22:35,1 BLUE@ROUTE_24:10,3 GREEN@ROUTE_3:41,3\n")
  file:write("statues=5/5/5 tangible_items=2/2/2\n")
  file:write("maps=16 music=16 exact_surface=16\n")
  file:write("functional_ladder_cells=", tostring(ladderCount), "\n")
  file:write("foreign_trial_negatives=", tostring(negativeCount), "/6\n")
  file:write("foreign_trial_matrix=", tostring(trialMatrix), "/70\n")
  file:write("foreign_shrine_save_recovery=", tostring(shrineRecoveries), "/12\n")
  file:close()
  print("HEVO PACKAGE CONTRACT PASS: fissures/statues/items/ladders/foreign-shrines")
  love.event.quit(0)
end
