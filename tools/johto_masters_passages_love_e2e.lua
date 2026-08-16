-- Renderer-backed Johto Masters map sample. It uses the live mod loader,
-- WorldAPI warps and native SaveData slot, not fixture tables. This driver
-- deliberately teleports between authored capture points and manually marks
-- clears after the checkpoint-save probe; it is NOT a complete traversal,
-- battle, loss/retry or reward proof.
--
-- POKEPORT_VERSION=red POKEPORT_IDENTITY=ka-johto-masters-uat \
-- POKEPORT_ONLY_MOD=kanto_ascendant POKEPORT_TEST_MOD=kanto_ascendant \
-- POKEPORT_DRIVER=/absolute/path/to/johto_masters_passages_love_e2e.lua \
-- POKEPORT_TOUCH=0 POKEPORT_SPEED=8 SHOT_DIR=/tmp/ka-johto-masters love .
return function(game)
  local U = dofile((os.getenv("GEN1RECOMP_DIR") or ".").."/tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local shotDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")

  local function settle(wanted)
    -- Let the native location banner finish before a visual review capture.
    -- Capturing the first frame made otherwise complete labels look clipped
    -- and concealed the lower-room architecture behind the notification.
    U.wait(360)
    assert(game.overworld and game.overworld.map.id == wanted,
      "world did not reach " .. wanted)
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  local function shot(name, wanted)
    settle(wanted)
    local objectRows = {}
    for _, object in ipairs(game.overworld.map.def.objects or {}) do
      objectRows[#objectRows + 1] = table.concat({
        tostring(object.name), tostring(object.x), tostring(object.y),
      }, "@")
    end
    U.log("JOHTO MAP OBJECTS", wanted, table.concat(objectRows, ","),
      "live-npcs=" .. tostring(#(game.overworld.npcs or {})))
    for _, npc in ipairs(game.overworld.npcs or {}) do
      assert(npc.wildsAmbientPokemon ~= true,
        "Wilds ambient Pokemon leaked into authored Johto map " .. wanted)
    end
    -- The native map-name card is a confirm-dismissable overlay rather than
    -- a timed stack entry.  Dismiss it so the four visual-review frames show
    -- the actual lower room instead of a UI panel.
    U.tap(game, "a")
    U.wait(12)
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    assert(U.shot(game, shotDir .. "/2d/" .. name .. ".png"),
      "2D capture failed: " .. name)
  end

  -- Actual directional input, not a controller position assignment.  The
  -- map's collision grid plans the route and every committed player cell is
  -- checked after the corresponding key press.
  local function walkToObject(game, object)
    local map, player = game.overworld.map, game.overworld.player
    local targets = {}
    for _, d in ipairs({{1,0,"left"},{-1,0,"right"},{0,1,"up"},{0,-1,"down"}}) do
      local x,y=object.x+d[1],object.y+d[2]
      if map:isWalkableCell(x,y) then targets[x..":"..y]=true end
    end
    local startX,startY=player.cellX,player.cellY;local queue={{startX,startY}};local head=1
    local previous,finish={},nil
    while queue[head] and not finish do
      local point=queue[head];head=head+1;local key=point[1]..":"..point[2]
      if targets[key] then finish=key;break end
      for _,d in ipairs({{1,0,"right"},{-1,0,"left"},{0,1,"down"},{0,-1,"up"}}) do
        local x,y=point[1]+d[1],point[2]+d[2];local nextKey=x..":"..y
        if not previous[nextKey] and map:isWalkableCell(x,y) and not game.overworld:npcAtCell(x,y) then previous[nextKey]={key,d[3]};queue[#queue+1]={x,y} end
      end
    end
    assert(finish,"no input route to "..object.name)
    local steps={};while finish~=startX..":"..startY do local node=assert(previous[finish]);steps[#steps+1]=node[2];finish=node[1] end
    for index=#steps,1,-1 do
      local beforeX,beforeY=player.cellX,player.cellY;U.tap(game,steps[index]);for _=1,24 do U.wait(1);if player.cellX~=beforeX or player.cellY~=beforeY then break end end
      -- A first directional tap may only turn the avatar; issue the same
      -- physical input once more before declaring the collision path broken.
      if player.cellX==beforeX and player.cellY==beforeY then U.tap(game,steps[index]);for _=1,24 do U.wait(1);if player.cellX~=beforeX or player.cellY~=beforeY then break end end end
      assert(player.cellX~=beforeX or player.cellY~=beforeY,"input step did not commit: "..steps[index])
    end
    local face=player.cellX<object.x and "right" or player.cellX>object.x and "left" or player.cellY<object.y and "down" or "up"
    U.tap(game,face);U.wait(4)
    -- The synthetic key queue can lose the A edge immediately after a long
    -- scripted walk.  Exercise the same live OverworldState dispatcher as a
    -- fallback (not the passage controller) so this regression diagnoses the
    -- map/object/talk/transition path rather than input timing.
    while game.stack:top() and game.stack:top()~=game.overworld do U.tap(game,"a");U.wait(4) end
    local npc=game.overworld:npcAtCell(object.x,object.y)
    if not npc then error("no NPC at map object "..object.name.." ("..object.x..","..object.y..")") end
    local MapScripts=require("data.scripts.init")
    U.log("JOHTO DISPATCH",game.overworld.map.id,object.index,object.text,npc.def.text,MapScripts.talkScript(game.overworld.map.id,npc.def.text) and "registered" or "missing")
    game.overworld:talkTo(npc);U.wait(12)
    while game.stack:top() and game.stack:top()~=game.overworld do U.tap(game,"a");U.wait(4) end
  end

  U.wait(30)
  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local masters = assert(api.johtoMasters, "Johto Masters baseline export missing")
  local passages = assert(api.johtoMastersPassages,
    "Johto Masters passages export missing")
  local onboarding = assert(api.onboarding,
    "postgame onboarding controller missing")
  assert(passages.contentEnabled, "production content registration is disabled")
  for _, def in pairs(passages.MAPS) do
    assert(game.data.maps[def.id], "live map not registered: " .. def.id)
  end

  -- Dedicated isolated slot: only this evidence run mutates its save.
  assert(SaveData.setActiveSlot(os.getenv("POKEPORT_VERSION") or "red",
    "slotjohto65e2e") == "slotjohto65e2e")
  game.save.hallOfFame = game.save.hallOfFame or { {} }
  if #game.save.hallOfFame == 0 then game.save.hallOfFame[1] = {} end
  game.save.modData = game.save.modData or {}
  game.save.modData.kanto_ascendant = game.save.modData.kanto_ascendant or {}
  game.mods.modSave = game.save.modData
  game.save.modData.kanto_ascendant.postgame = {
    crownChampion = true, masterWins = {}, crownWins = {},
  }
  game.save.modData.kanto_ascendant.johto_masters = {
    version = 2, clears = 0, gifts = 0, title = false,
    passages = {
      silver = { status = "locked", attempts = 0, puzzle = false },
      kris = { status = "locked", attempts = 0, puzzle = false },
      gold = { status = "locked", attempts = 0, puzzle = false },
    },
  }
  onboarding.state().shown = true
  passages.install(game)

  -- P0 fallback-review sampler: maps only, no controller call, movement,
  -- status mutation or battle.  It exists to inspect the compact Hall, all
  -- three quiz rooms and all three locked finale authorities separately from
  -- the input proof.
  if os.getenv("JOHTO_FINALS_ONLY") == "1" then
    local silverFinale, krisFinale, goldFinale = passages.MAPS.SILVER_FINALE,
      passages.MAPS.KRIS_FINALE, passages.MAPS.GOLD_FINALE
    local views = {
      { "00_gate_hall", passages.MAPS.HALL.id,
        passages.MAPS.HALL.entryX, passages.MAPS.HALL.entryY, "up" },
      { "01_silver_passage", passages.MAPS.SILVER_PASSAGE.id,
        passages.MAPS.SILVER_PASSAGE.entryX, passages.MAPS.SILVER_PASSAGE.entryY, "up" },
      { "02_kris_passage", passages.MAPS.KRIS_PASSAGE.id,
        passages.MAPS.KRIS_PASSAGE.entryX, passages.MAPS.KRIS_PASSAGE.entryY, "up" },
      { "03_gold_passage", passages.MAPS.GOLD_PASSAGE.id,
        passages.MAPS.GOLD_PASSAGE.entryX, passages.MAPS.GOLD_PASSAGE.entryY, "up" },
      { "04_silver_finale", silverFinale.id, silverFinale.entryX, silverFinale.entryY, "up" },
      { "05_kris_finale", krisFinale.id, krisFinale.entryX, krisFinale.entryY, "up" },
      { "06_gold_finale", goldFinale.id, goldFinale.entryX, goldFinale.entryY, "up" },
    }
    for index, view in ipairs(views) do
      U.teleport(game, view[2], view[3], view[4], view[5] or "down")
      shot(view[1], view[2])
      if index == 1 then
        for y = 19, game.overworld.map.heightCells - 1 do
          U.log("JOHTO HALL EXIT CELL", 9, y,
            "tile=" .. tostring(game.overworld.map:cellTile(9, y)),
            "warp=" .. tostring(game.overworld.map:warpAtCell(9, y) ~= nil),
            "warpTile=" .. tostring(game.overworld.map:isWarpTileCell(9, y)),
            "door=" .. tostring(game.overworld.map:isDoorTileCell(9, y)))
        end
        for _ = 1, 8 do
          local beforeX, beforeY = game.overworld.player.cellX,
            game.overworld.player.cellY
          U.tap(game, "down")
          U.wait(24)
          U.log("JOHTO HALL EXIT STEP", beforeX, beforeY, "->",
            game.overworld.player.cellX, game.overworld.player.cellY,
            game.overworld.map.id)
          if game.overworld
              and game.overworld.map.id ~= passages.MAPS.HALL.id then break end
        end
        assert(game.overworld
          and game.overworld.map.id == "INDIGO_PLATEAU_LOBBY",
          "compact Gate Hall central exit did not return to Indigo lobby")
      end
    end
    U.log("JOHTO MASTERS 7-MAP MATERIAL SAMPLE / NOT TRAVERSAL", shotDir)
    love.event.quit(0)
    return
  end

  -- v9 visual review is deliberately a four-frame renderer sampler only.
  -- It does not enter a passage, alter its status, invoke the controller, or
  -- claim navigation/battle coverage; the pure input driver remains the sole
  -- traversal evidence.  This mode keeps visual iteration from accidentally
  -- being reported as a full acceptance run.
  if os.getenv("JOHTO_PROTOTYPE_ONLY") == "1" then
    local views = {
      { "01_silver_arrival", passages.MAPS.SILVER_PASSAGE.id, 3, 51 },
      { "01_silver_decision", passages.MAPS.SILVER_PASSAGE.id, 3, 33 },
      { "02_kris_arrival", passages.MAPS.KRIS_PASSAGE.id, 3, 51 },
      { "02_kris_decision", passages.MAPS.KRIS_PASSAGE.id, 3, 33 },
    }
    for _, view in ipairs(views) do
      U.teleport(game, view[2], view[3], view[4], "down")
      shot(view[1], view[2])
    end
    U.log("JOHTO MASTERS FOUR-FRAME RENDER SAMPLE / NOT TRAVERSAL", shotDir)
    love.event.quit(0)
    return
  end

  -- Lobby host callback proves the old host now hands off to the Gate Hall.
  U.teleport(game, "INDIGO_PLATEAU_LOBBY", 9, 7, "down")
  passages.hostTalk(game, game.overworld, { frozen = false })
  U.wait(20)
  while game.stack:top() and game.stack:top() ~= game.overworld do
    U.tap(game, "a"); U.wait(6)
  end
  shot("00_gate_hall", passages.MAPS.HALL.id)

  local route = {
    { key = "silver", passage = "SILVER_PASSAGE", finale = "SILVER_FINALE" },
    { key = "kris", passage = "KRIS_PASSAGE", finale = "KRIS_FINALE" },
    { key = "gold", passage = "GOLD_PASSAGE", finale = "GOLD_FINALE" },
  }
  for index, row in ipairs(route) do
    assert(passages.enter(game, row.key), "could not enter " .. row.key)
    local passageDef = passages.MAPS[row.passage]
    shot(("%02d_%s_arrival"):format(index, row.key), passageDef.id)
    -- Contact-sheet views deliberately sample the three authored rooms. They
    -- prove the renderer sees the full composition; they do not claim a
    -- walking proof (the later navigation driver must provide that evidence).
    local room = passageDef.h * 2 / 3
    U.teleport(game, passageDef.id, 3, math.floor(room * 2 - 3), "down")
    shot(("%02d_%s_decision"):format(index, row.key), passageDef.id)
    U.teleport(game, passageDef.id, 3, math.floor(room - 3), "down")
    shot(("%02d_%s_gate"):format(index, row.key), passageDef.id)
    -- Re-enter at the actual gate landing and activate all five map objects
    -- with keyboard input: landmark, three decisions, final gate.
    assert(passages.enter(game, row.key), "could not re-enter " .. row.key)
    for objectIndex=1,5 do
      walkToObject(game, assert(game.overworld.map.def.objects[objectIndex], "passage object missing"))
      local progress=passages.state(false).passages[row.key]
      if objectIndex==1 then assert(progress.clue,"landmark callback did not run")
      elseif objectIndex<5 then assert(progress.step==objectIndex-1,"decision callback did not run: "..objectIndex) end
    end
    settle(passages.MAPS[row.finale].id)
    shot(("%02d_%s_finale"):format(index, row.key),
      passages.MAPS[row.finale].id)

    -- This is a real SaveData write/reload at every entered puzzle/finale
    -- checkpoint; battle resolution itself stays in the separately audited
    -- deterministic runtime test so this capture driver never fakes a win.
    assert(game:writeSave(), "native save write failed at " .. row.key)
    local loaded, recovered = assert(SaveData.load())
    game:restoreSave(loaded, recovered)
    assert(passages.state(false).passages[row.key].puzzle == true,
      "puzzle state disappeared after native reload: " .. row.key)

    -- Capture traversal needs to progress to the next gate without claiming
    -- a rendered battle win.  The controller's loss/retry branch is covered
    -- by tests/johto_masters_passages_test.lua, not presented as LÖVE proof.
    local state = passages.state()
    state.passages[row.key].status = "cleared"
    state.passages[row.key].puzzle = false
    game.mods.modSave.kanto_ascendant.johto_masters = state
    passages.sync(game)
    assert(passages.enterHall(game), "could not return to Gate Hall")
    shot(("%02d_%s_return"):format(index, row.key), passages.MAPS.HALL.id)
  end

  -- Voxel is an optional, separate renderer.  When DRAMALESS is loaded this
  -- records the same seven registered maps through its real pipeline; when
  -- it is absent the driver deliberately produces no pretend Voxel image.
  if game.mods.exports.DRAMALESS_SHAPE then
    local Pipelines = require("src.render.Pipelines")
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options or {})
    U.wait(90)
    local silverFinale, krisFinale, goldFinale = passages.MAPS.SILVER_FINALE,
      passages.MAPS.KRIS_FINALE, passages.MAPS.GOLD_FINALE
    local voxelMaps = {
      { "00_gate_hall", passages.MAPS.HALL.id, 3, 25 },
      { "01_silver_passage", passages.MAPS.SILVER_PASSAGE.id, 3, 15 },
      { "01_silver_finale", silverFinale.id, silverFinale.entryX, silverFinale.entryY, "up" },
      { "02_kris_passage", passages.MAPS.KRIS_PASSAGE.id, 3, 25 },
      { "02_kris_finale", krisFinale.id, krisFinale.entryX, krisFinale.entryY, "up" },
      { "03_gold_passage", passages.MAPS.GOLD_PASSAGE.id, 3, 15 },
      { "03_gold_finale", goldFinale.id, goldFinale.entryX, goldFinale.entryY, "up" },
    }
    for _, row in ipairs(voxelMaps) do
      U.teleport(game, row[2], row[3], row[4], row[5] or "down")
      settle(row[2])
      assert(U.shot(game, shotDir .. "/voxel/" .. row[1] .. ".png"),
        "Voxel capture failed: " .. row[1])
    end
    Pipelines.setLevel("voxel", 0)
  else
    U.log("JOHTO MASTERS VOXEL SKIPPED: DRAMALESS_SHAPE not loaded")
  end

  U.log("JOHTO MASTERS LÖVE RENDER SAMPLE / NOT TRAVERSAL", shotDir)
  love.event.quit(0)
end
