-- Strict Johto Masters acceptance driver.  Unlike the render sampler it has
-- no U.teleport calls and never mutates passage status or invokes P.enter,
-- P.inspect, P.choose, P.solve or P.startBattle.  Its harness must boot the
-- dedicated qualifying save directly at INDIGO_PLATEAU_LOBBY.  BLITZ and
-- native-Fresh prerequisites are built by the same package setup and from this
-- point execute this exact input path.  It is
-- intentionally not a fixture-builder: using a real saved position keeps
-- the Host spawn and map-enter lifecycle in the proof.
local function run(game)
  local U=dofile(os.getenv("KA_TEST_UTIL")
    or (os.getenv("GEN1RECOMP_DIR") or ".").."/tests/drivers/util.lua")
  local SaveData=require("src.core.SaveData")
  local shotDir=os.getenv("SHOT_DIR")
  local renderer=tostring(os.getenv("QA_RENDERER")
    or (os.getenv("JOHTO_QA_VOXEL")=="1" and "FULL" or "2D")):upper()
  assert(renderer=="2D" or renderer=="FULL",
    "QA_RENDERER must be 2D or FULL")
  local variant=tostring(assert(os.getenv("JOHTO_QA_VARIANT"),
    "JOHTO_QA_VARIANT required")):upper()
  assert(variant=="BLITZ" or variant=="FRESH",
    "JOHTO_QA_VARIANT must be BLITZ or FRESH")
  local expectedIdentity=("ka65-final-johto-connected-%s-%s")
    :format(variant:lower(),renderer:lower())
  assert(os.getenv("POKEPORT_IDENTITY")==expectedIdentity,
    "connected Johto driver rejects a non-orchestrated identity")
  local voxelMode=renderer=="FULL"
  local Pipelines=voxelMode and require("src.render.Pipelines") or nil
  local Runtime=require("src.mods.Runtime")
  local ChipAudio=require("src.core.ChipAudio")
  local TypeChart=require("src.battle.TypeChart")
  local Strings=require("src.core.Strings")
  local TextBox=require("src.render.TextBox")
  local musicEvents={}
  local musicOwner="ka_johto_connected_package_"..renderer:lower()
  local function receiptSha(name)
    local value=tostring(os.getenv(name) or "")
    return #value==64 and value:match("^[0-9a-f]+$") and value or nil
  end
  assert(os.getenv("KA_PACKAGE_GATE")=="1",
    "connected Johto acceptance must run from the immutable package gate")
  for _,name in ipairs({"KA_ENGINE_PAYLOAD_SHA256",
      "KA_AUTHORITY_PACKAGE_SHA256","KA_DEUTSCH_PACKAGE_SHA256",
      "KA_PACKAGE_GATE_RECEIPT_SHA256","KA_SOURCE_SAVE_SHA256"}) do
    assert(receiptSha(name),name.." package receipt is missing")
  end
  if voxelMode then
    assert(receiptSha("KA_DRAMALESS_PACKAGE_SHA256"),
      "FULL Johto run has no DRAMALESS package receipt")
  end
  Runtime.events:on("music.started",function(payload)
    musicEvents[#musicEvents+1]=payload
  end,nil,musicOwner)
  local function awaitMusic(song,reason,label,startAt)
    for _=1,420 do
      for index=math.max(1,startAt or 1),#musicEvents do
        local row=musicEvents[index]
        if row.song==song and (not reason or row.reason==reason) then
          for _=1,300 do
            if not ChipAudio.awaitingFirstBuffer() then break end
            U.wait(1)
          end
          assert(not ChipAudio.awaitingFirstBuffer(),
            label.." never received its first audio buffer")
          return row,index
        end
      end
      U.wait(1)
    end
    error(label.." missing music event "..song.."/"..tostring(reason))
  end
  local function shot(name)
    if not shotDir then return end
    local top=game.stack:top()
    local mt=top and getmetatable(top)
    -- Exact-copy receipts intentionally keep the production TextBox open.
    -- It is a transparent overlay on the live field, so it still belongs to
    -- the overworld renderer/pipeline boundary; classifying every non-base
    -- stack state as BattleState made both FULL host-copy captures fail even
    -- when the real Indigo host and text were present.
    local fieldFrame=top==game.overworld
      or (mt and mt.__index==TextBox)
    if voxelMode and fieldFrame then
      local pipeline=Pipelines.worldPipeline()
      assert(Pipelines.level("voxel")==1 and pipeline=="voxel",
        "DRAMALESS voxel pipeline is not active for "..name)
      local current=game.overworld and game.overworld.map
      if current and current.id:find("^KA_JOHTO_") then
        assert(current.def.voxelMode=="MAP_STUDIO",
          "Johto map did not retain MAP_STUDIO voxel mode for "..name)
      else
        assert(current and current.id=="INDIGO_PLATEAU_LOBBY",
          "unexpected native overworld FULL capture for "..name)
      end
    elseif voxelMode then
      -- Battle frames are BattleState evidence, not overworld-pipeline
      -- receipts.  The first set owns the dedicated Johto passage marker;
      -- the cadence continuation owns one of the five physical League
      -- classes reached through their native rooms.
      local battle=top
      local league={OPP_LORELEI=true,OPP_BRUNO=true,OPP_AGATHA=true,
        OPP_LANCE=true,OPP_RIVAL3=true}
      assert(battle and (battle.johtoPassage==true
          or league[battle.oppClass]==true),
        "non-overworld FULL capture is not a Johto/League battle: "..name)
    end
    U.wait(12)
    local folder=voxelMode and "full" or "2d"
    assert(U.shot(game,shotDir.."/"..folder.."/"..name..".png"),
      (voxelMode and "Voxel" or "2D").." capture failed: "..name)
  end
  local function assertVisibleCapture(name)
    if not shotDir then return end
    local path=shotDir.."/"..(voxelMode and "full" or "2d").."/"..name..".png"
    -- The renderer writes absolute QA paths outside LÖVE's virtual
    -- filesystem.  Its post-run host-side validator reads those PNGs and
    -- applies the histogram rejection; here we still make capture failure
    -- fatal rather than pretending that a filename is visual evidence.
    local file=assert(io.open(path,"rb"),"capture missing: "..name)
    file:close()
  end
  -- Boot the isolated prerequisite save through the ordinary title-screen
  -- CONTINUE flow.  This is deliberately before the Indigo-host boundary;
  -- no world position is assigned by this driver.
  -- One START opens the title menu and one A confirms CONTINUE.  Do not send
  -- speculative additional A presses: after a fast native load those can
  -- already reach the Indigo host and falsely turn the fixture into a Hall
  -- start before the actual input proof begins.
  U.wait(5);U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,480 do
    if game.overworld and game.stack:top()==game.overworld then break end
    -- A native load can show a validation/migration report before field
    -- control.  Acknowledge it exactly as a player would; do not alter the
    -- reported save or dismiss it by stack manipulation.
    U.tap(game,"a");U.wait(3)
  end
  local api=assert(game.mods.exports.kanto_ascendant)
  local P=assert(api.johtoMastersPassages)
  local masters=assert(api.johtoMasters)
  -- save.loaded restores the map before all map-enter listeners finish
  -- rebuilding dynamic hosts; wait for that ordinary lifecycle rather than
  -- spawning or refreshing anything from QA.
  U.wait(36)
  local top=game.stack:top();local mt=getmetatable(top);local kind=mt and mt.__index
  U.log("JOHTO PURE POSTBOOT",tostring(top and top.screenId),tostring(top==game.overworld),tostring(top and top.isOpaque),kind==require("src.render.TextBox") and "TextBox" or kind==require("src.ui.ChoiceBox") and "ChoiceBox" or kind==require("src.world.OverworldController") and "Overworld" or "other",tostring(top and top.pageIndex),tostring(top and top.lineIndex),tostring(top and top.charIndex),tostring(top and top.waiting))
  assert(game.stack:top()==game.overworld,"title/transition did not settle onto the overworld")
  assert(game.overworld and game.overworld.map.id=="INDIGO_PLATEAU_LOBBY",
    "pure QA requires an eligible fixture booted at INDIGO_PLATEAU_LOBBY")
  local initial=assert(P.state(false),"fixture has no Johto state")
  local origin=assert(game.save.qaJohtoConnectedOrigin,
    "connected Johto save lost its package origin receipt")
  assert(origin.version==1 and origin.variant==variant
      and origin.sourceSha256==os.getenv("KA_SOURCE_SAVE_SHA256")
      and origin.packageGateReceiptSha256
        ==os.getenv("KA_PACKAGE_GATE_RECEIPT_SHA256"),
    "connected Johto package origin is not pinned to this cell")
  local expectedKind=variant=="FRESH" and "native-save-new-game"
    or "immutable-blitz-migration"
  assert(origin.kind==expectedKind,
    "connected Johto setup variant and save origin disagree")
  assert(masters.hostAvailable(game),
    "qualifying "..variant.." save lost its Johto host")
  assert(initial.connectedClears==0 and initial.journeyClears==0
      and initial.activeRun~=true,
    variant.." prerequisite was mistaken for connected arena progress")
  assert(not P.canEnter(game,"silver"),
    "Silver opened before the host committed the connected run")
  local initialGifts=tonumber(initial.gifts) or 0
  local initialConnected=tonumber(initial.connectedClears) or 0
  local initialHall=#(game.save.hallOfFame or {})
  assert(initialHall>0,
    "connected Johto prerequisite has no Hall-of-Fame eligibility")
  U.log(("JOHTO CONNECTED PHYSICAL START variant=%s renderer=%s hall=%d")
    :format(variant,renderer,initialHall))
  if voxelMode then
    assert(game.mods.exports.DRAMALESS_SHAPE,
      "JOHTO_QA_VOXEL requires the real DRAMALESS_SHAPE mod")
    assert(Pipelines.setLevel("voxel",1)==1,
      "could not enable the real voxel pipeline")
    Pipelines.syncOptions(game.save.options or {})
    U.wait(90)
  end
  local function dismiss()
    for _=1,180 do
      if game.stack:top()==game.overworld then return end
      U.tap(game,"a");U.wait(3)
    end
    error("dialogue did not return to the overworld")
  end

  -- The host and every subsequent marker are selected from the live NPC list;
  -- their text constants are the contract.  All walking and A presses run
  -- through OverworldController:interact; this driver never calls talkTo.
  local function npc(text)
    for _,n in ipairs(game.overworld.npcs or {}) do if n.def and n.def.text==text then return n end end
  end
  local hostText=assert(api.johtoMastersData).textId
  local function hostCounts()
    local definitions,live=0,0
    local map=game.data.maps[assert(api.johtoMastersData).map]
    for _,object in ipairs(map and map.objects or {}) do
      if object.text==hostText then definitions=definitions+1 end
    end
    for _,actor in ipairs(game.overworld.npcs or {}) do
      if actor.def and actor.def.text==hostText then live=live+1 end
    end
    return definitions,live
  end

  local dirs={{1,0,"right"},{-1,0,"left"},{0,1,"down"},{0,-1,"up"}}
  local function walkOne(direction)
    local p=game.overworld.player;local x,y=p.cellX,p.cellY
    -- A one-frame physical press is closer to the actual joypad cadence than
    -- holding a synthetic state through a whole walk animation.  The first
    -- press can legitimately only turn RED, so retry it once before failing.
    for _=1,2 do
      U.tap(game,direction)
      for _=1,24 do
        U.wait(1)
        if p.cellX~=x or p.cellY~=y then break end
      end
      if p.cellX~=x or p.cellY~=y then break end
    end
    assert(p.cellX~=x or p.cellY~=y,("input step failed: %s at %d,%d facing=%s locked=%s moving=%s map=%s"):format(direction,x,y,tostring(p.facing),tostring(p.inputLocked),tostring(p.moving),tostring(game.overworld.map.id)))
    U.wait(3)
  end

  local function walkToObject(object,positionOnly)
    assert(object,"required host/marker NPC missing")
    local ow,map,p=game.overworld,game.overworld.map,game.overworld.player
    local function occupied(x,y)
      local blocker=ow:npcAtCell(x,y)
      -- Match the production Collision contract: followers and transparent
      -- interaction anchors are present in the draw/NPC list but explicitly
      -- never block movement. Treating them as walls can invent a false
      -- post-reload softlock in a narrow passage.
      return blocker and blocker.passable~=true
    end
    U.log("JOHTO PURE TARGET",object.def.text,object.cellX,object.cellY,"from",p.cellX,p.cellY)
    U.log("JOHTO PURE LEFT",map:isWalkableCell(p.cellX-1,p.cellY),ow:npcAtCell(p.cellX-1,p.cellY) and "npc" or "free",#(ow.entities or {}))
    local target={}
    for _,d in ipairs(dirs) do
      local x,y=object.cellX+d[1],object.cellY+d[2]
      if map:isWalkableCell(x,y) then
        target[x..":"..y]=({right="left",left="right",down="up",up="down"})[d[3]]
      end
    end
    local start=p.cellX..":"..p.cellY;local queue={{p.cellX,p.cellY}};local head=1
    local previous,finish={},nil
    while queue[head] and not finish do
      local point=queue[head];head=head+1;local tag=point[1]..":"..point[2]
      if target[tag] then finish=tag;break end
      for _,d in ipairs(dirs) do
        local x,y=point[1]+d[1],point[2]+d[2];local nextTag=x..":"..y
        if not previous[nextTag] and map:isWalkableCell(x,y) and not occupied(x,y) then
          previous[nextTag]={tag,d[3]};queue[#queue+1]={x,y}
        end
      end
    end
    assert(finish,"no input route to "..tostring(object.def.text))
    local face=assert(target[finish]);local steps={}
    while finish~=start do local step=assert(previous[finish]);steps[#steps+1]=step[2];finish=step[1] end
    for i=#steps,1,-1 do walkOne(steps[i]) end
    -- A blocked physical step turns the player to the target.  It does not
    -- move the player and is therefore safe even when the route ended beside
    -- the NPC from a different direction.
    game.input.state[face]=true;coroutine.yield();game.input.state[face]=false;U.wait(3)
    local fx,fy=p:facingCell()
    assert(fx==object.cellX and fy==object.cellY,"input walk did not face target")
    if not positionOnly then U.tap(game,"a");U.wait(8) end
  end

  -- Coordinate traversal is used only for real warp cells and Lance's
  -- production onStep trigger.  Like walkToObject it plans over the live
  -- collision map, then executes every cell through joypad input.
  local function walkToCell(targetX,targetY,label)
    local ow,map,p=game.overworld,game.overworld.map,game.overworld.player
    local function occupied(x,y)
      local blocker=ow:npcAtCell(x,y)
      return blocker and blocker.passable~=true
    end
    local start=p.cellX..":"..p.cellY
    local finish=targetX..":"..targetY
    local queue,head={{p.cellX,p.cellY}},1
    local previous={[start]=false}
    while queue[head] and previous[finish]==nil do
      local point=queue[head];head=head+1
      local tag=point[1]..":"..point[2]
      for _,d in ipairs(dirs) do
        local x,y=point[1]+d[1],point[2]+d[2]
        local nextTag=x..":"..y
        if previous[nextTag]==nil and map:isWalkableCell(x,y)
            and (nextTag==finish or not occupied(x,y)) then
          previous[nextTag]={tag,d[3]};queue[#queue+1]={x,y}
        end
      end
    end
    assert(previous[finish]~=nil or finish==start,
      "no input route to "..tostring(label).." at "..finish)
    local steps={}
    while finish~=start do
      local step=assert(previous[finish])
      steps[#steps+1]=step[2];finish=step[1]
    end
    for i=#steps,1,-1 do
      -- A destination can start a warp/battle on the final physical step.
      -- No further step may be issued once the overworld loses input focus.
      walkOne(steps[i])
      if game.stack:top()~=game.overworld then break end
    end
  end

  local function awaitMap(mapId,label)
    for _=1,600 do
      if game.overworld and game.stack:top()==game.overworld
          and game.overworld.map.id==mapId then return end
      U.tap(game,"a");U.wait(2)
    end
    error(label.." did not reach "..mapId)
  end
  local function awaitOverworldIdle(label)
    for _=1,1800 do
      local ow=game.overworld
      local player=ow and ow.player
      local runner=ow and ow.runner
      if ow and game.stack:top()==ow and player and not player.moving
          and not player.inputLocked and #(ow.scriptMoves or {})==0
          and not (runner and runner.isRunning and runner:isRunning()) then
        return
      end
      U.wait(1)
    end
    error(label.." did not return ordinary field input")
  end

  local function frameMaster(id,name)
    local master=assert(npc(id))
    walkToObject(master,true)
    local player=game.overworld.player;local fx,fy=player:facingCell()
    assert(fx==master.cellX and fy==master.cellY and game.overworld:npcAtCell(fx,fy)==master,
      "finale capture is not facing its live master: "..id)
    assert(master.def.sprite or master.def.object or master.sprite,
      "finale master has no individual overworld sprite: "..id)
    shot(name);assertVisibleCapture(name)
    U.tap(game,"a");U.wait(24)
  end

  local definitions,liveHosts=hostCounts()
  assert(definitions==1 and liveHosts==1,
    variant.." host did not spawn exactly once: "..definitions..":"..liveHosts)
  shot("00_initial_host")
  game.overworld:reloadMap(assert(api.johtoMastersData).map,
    "johto-connected-package-reload")
  U.wait(90)
  definitions,liveHosts=hostCounts()
  assert(definitions==1 and liveHosts==1,
    "host reload reconciliation duplicated or lost the actor: "
      ..definitions..":"..liveHosts)
  shot("00b_initial_host_reloaded")
  walkToObject(assert(npc(hostText)))
  local hostBox=game.stack:top()
  local expectedHost={
    ["The Johto Masters' host awaits you. SILVER, KRIS and GOLD challenge you in three arenas. He leads you to the Gate Hall now - SILVER waits first."]=true,
    ["Der Gastgeber der Johto-Meister erwartet dich. SILVER, KRIS und GOLD fordern dich in drei Arenen heraus. Er führt dich jetzt zur Torhalle - SILVER wartet zuerst."]=true,
  }
  assert(hostBox and expectedHost[hostBox.text],
    "host did not expose the approved exact connected-arena text: "
      ..tostring(hostBox and hostBox.text))
  shot("00c_host_exact_text")
  dismiss()
  assert(game.overworld.map.id==P.MAPS.HALL.id,"host did not hand off to Gate Hall")
  local _,mapEventIndex=awaitMusic("Music_KA_GSC_IndigoPlateau","map",
    "Gate Hall Johto theme")
  assert(P.state(false).activeRun==true and P.canEnter(game,"silver")
      and not P.canEnter(game,"kris") and not P.canEnter(game,"gold"),
    "host did not commit a Silver-only connected run")
  shot("00_gate_hall")

  -- Hall routing uses the exact same physical object interaction.  Silver is
  -- the only initially available gate, so this also proves the player did not
  -- reach a later passage through a manually set status.
  walkToObject(assert(npc("TEXT_KA_JOHTO_GATE_SILVER")))
  dismiss()
  assert(game.overworld.map.id==P.MAPS.SILVER_PASSAGE.id,
    "Silver gate did not reach its passage through the map event")
  shot("01_silver_arrival")

  local function marker(id,name)
    walkToObject(assert(npc(id)))
    dismiss()
    if name then shot(name) end
  end
  -- A wrong physical choice must reset the sequence, then the correct three
  -- in-map marker interactions reach the finale.  No controller status is
  -- read or written here; every result is observed from the live map.
  marker("TEXT_KA_JOHTO_SILVER_LANDMARK","01_silver_landmark")
  marker("TEXT_KA_JOHTO_SILVER_DECISION_2","01_silver_wrong_reset")
  marker("TEXT_KA_JOHTO_SILVER_DECISION_1","01_silver_decision_1")
  marker("TEXT_KA_JOHTO_SILVER_DECISION_2","01_silver_decision_2")

  -- This is the native save/load path at the specified mid-sequence point,
  -- not a table copy.  restoreSave recreates the overworld and its NPCs, so
  -- subsequent lookups also prove the marker objects survive the reload.
  assert(game:writeSave(),"native save write failed after Silver step 2")
  local loaded,recovered=assert(SaveData.load())
  game:restoreSave(loaded,recovered)
  U.wait(36)
  assert(game.overworld and game.overworld.map.id==P.MAPS.SILVER_PASSAGE.id,
    "native reload did not return to Silver passage")
  marker("TEXT_KA_JOHTO_SILVER_DECISION_3","01_silver_decision_3")
  marker("TEXT_KA_JOHTO_SILVER_FINAL_GATE")
  assert(game.overworld.map.id==P.MAPS.SILVER_FINALE.id,
    "Silver final gate did not reach its finale through the map event")
  -- The next A press opens Silver's real isolated battle intro.  Both the
  -- loss and win below are earned through ordinary battle-menu input; this
  -- driver never injects a result, reward or passage clear.
  frameMaster("TEXT_KA_JOHTO_SILVER_MASTER","01_silver_finale_npc")
  assert(game.stack:top()~=game.overworld,"Silver master did not open battle intro")
  local function assertJohtoBattle(key)
    local top=game.stack:top()
    -- pushBattle intentionally keeps the BattleTransition overlay on top
    -- for a few frames.  Observe the real controller only after that native
    -- transition has completed; do not advance it with a synthetic action.
    for _=1,120 do
      if top and top.johtoPassage==true then break end
      U.wait(1);top=game.stack:top()
    end
    local expected="KA_JOHTO_"..key:upper()
    assert(top and top.johtoPassage==true and top.ascendantNoItems==true
      and top.noPrizeMoney==true and top.postgameTier==nil
      and top.postgameForcedTier==nil,
      key.." battle leaked a generic postgame context or allowed items/prize money")
    assert(top.trainer and top.trainer.class==expected,
      key.." battle did not use its dedicated trainer class")
    local _,eventIndex=awaitMusic("Music_KA_GSC_RivalBattle","battle",
      key.." Rival battle theme",mapEventIndex+1)
    mapEventIndex=eventIndex
    return tonumber(game.save.money) or 0
  end
  local function captureBattleIntro(key,name)
    local top=game.stack:top()
    -- Require the actual trainer-intro presentation, not merely the native
    -- BattleTransition or a blank first BattleState frame.  The dialog
    -- predicate guarantees that the trainer name/text has started drawing.
    for _=1,480 do
      if top and top.johtoPassage and top.showEnemyTrainer
        and (top.introSlide or 1)<=0 and top.phase=="messages"
        and (top.total or 0)>0 and (top.charIndex or 0)>=math.min(10,top.total) then break end
      U.wait(1);top=game.stack:top()
    end
    assert(top and top.johtoPassage and top.showEnemyTrainer
      and (top.introSlide or 1)<=0 and top.phase=="messages"
      and (top.total or 0)>0 and (top.charIndex or 0)>=math.min(10,top.total),
      key.." trainer intro never became visibly drawable")
    assert(top.trainer and top.trainer.name and top.trainer.class=="KA_JOHTO_"..key:upper(),
      key.." trainer portrait/name does not belong to the dedicated master")
    shot(name);assertVisibleCapture(name)
  end
  local silverLossMoney=assertJohtoBattle("silver")
  captureBattleIntro("silver","01_silver_battle_intro_loss")

  local function strongestMoveSlot(top)
    local best,bestScore=2,-1
    local defender=top.enemy and top.enemy.curTypes or {}
    for index,move in ipairs(top.player and top.player.curMoves or {}) do
      -- Slot one is deliberately non-damaging on every fixture member and
      -- reserved for the natural-loss pass.  Wins choose among actual attacks
      -- from the currently active Pokémon without injecting damage/results.
      if index>1 and (tonumber(move.pp) or 0)>0 then
        local def=game.data.moves[move.id]
        local power=def and tonumber(def.power) or 0
        local effectiveness=def and def.type
          and TypeChart.effectiveness(def.type,defender) or 0
        local score=power*effectiveness
        if score>bestScore then best,bestScore=index,score end
      end
    end
    assert(bestScore>0,"no damaging move can hit the current opponent")
    return best
  end
  local function chooseMove(top,wanted)
    wanted=wanted=="best" and strongestMoveSlot(top) or wanted
    if top.moveIndex==wanted then U.tap(game,"a");return end
    if top:wideLayout() then
      local row=math.floor((top.moveIndex-1)/2)
      local wantedRow=math.floor((wanted-1)/2)
      local col=(top.moveIndex-1)%2
      local wantedCol=(wanted-1)%2
      U.tap(game,row~=wantedRow and "down"
        or col~=wantedCol and "right" or "a")
    else
      U.tap(game,"down")
    end
  end
  local function driveBattleStep(top,moveMode)
    if top and top.forceSwitch then
      -- A forced replacement is also a native battle-menu interaction.
      -- Pick the first living party member by joypad navigation; never
      -- mutate party HP/order or inject a replacement callback.
      local wanted=1
      for i,mon in ipairs(game.save.party or {}) do if mon.hp>0 then wanted=i;break end end
      if top.index<wanted then U.tap(game,"down")
      elseif top.index>wanted then U.tap(game,"up")
      else U.tap(game,"a") end
    elseif top and top.phase=="menu" then U.tap(game,"a")
    elseif top and top.phase=="moveSelect" then chooseMove(top,moveMode)
    else U.tap(game,"a") end
  end
  local function battle(moveMode, destination)
    -- The isolated six-versus-six Master rosters legitimately take longer
    -- than a regular trainer battle at fast-forward.  This only expands the
    -- wall-clock watchdog; every selection remains a physical menu input.
    for tick=1,18000 do
      if game.stack:top()==game.overworld and game.overworld.map.id==destination then return end
      local top=game.stack:top()
      if tick%300==0 then U.log("JOHTO PURE BATTLE",tick,tostring(top and top.phase),tostring(top and top.result),tostring(top and top.msgWaiting),tostring(top and top.afterQueue),top and top.player and top.player.mon and top.player.mon.hp or "menu") end
      driveBattleStep(top,moveMode)
      U.wait(2)
    end
    error("battle did not resolve to "..destination)
  end
  -- The six real non-damaging selections begin at 1 HP and lose naturally.
  -- Passage-local production retry handling heals and returns to the Hall.
  battle(1,P.MAPS.HALL.id)
  assert(game.overworld.map.id==P.MAPS.HALL.id,"loss did not return to Gate Hall")
  local _,restoredIndex=awaitMusic("Music_KA_GSC_IndigoPlateau",nil,
    "Silver loss map-theme restore",mapEventIndex+1)
  mapEventIndex=restoredIndex
  assert((tonumber(game.save.money) or 0)==silverLossMoney,"Silver loss changed money")
  assert(P.state(false).passages.silver.status=="entered","Silver loss must preserve retry state")
  shot("01_silver_loss_return")
  walkToObject(assert(npc("TEXT_KA_JOHTO_GATE_SILVER")));dismiss()
  assert(game.overworld.map.id==P.MAPS.SILVER_PASSAGE.id,"Silver retry gate failed")
  marker("TEXT_KA_JOHTO_SILVER_FINAL_GATE")
  assert(game.overworld.map.id==P.MAPS.SILVER_FINALE.id,"Silver retry finale failed")
  frameMaster("TEXT_KA_JOHTO_SILVER_MASTER","01_silver_finale_npc")
  local silverWinMoney=assertJohtoBattle("silver")
  captureBattleIntro("silver","01_silver_battle_intro_win")
  battle("best",P.MAPS.HALL.id)
  assert(game.overworld.map.id==P.MAPS.HALL.id,"Silver win did not return to Gate Hall")
  local _,silverWinRestore=awaitMusic("Music_KA_GSC_IndigoPlateau",nil,
    "Silver win map-theme restore",mapEventIndex+1)
  mapEventIndex=silverWinRestore
  assert((tonumber(game.save.money) or 0)==silverWinMoney,"Silver win paid prize money")
  shot("01_silver_win_return")
  U.log("JOHTO MASTERS PURE QA SILVER LOSS/RETRY/WIN/RETURN PASS")

  local function reloadPassage(id)
    assert(game:writeSave(),"native save write failed in "..id)
    local loaded,recovered=assert(SaveData.load())
    game:restoreSave(loaded,recovered);U.wait(36)
    assert(game.overworld and game.overworld.map.id==id,
      "native reload did not retain "..id)
  end
  local function finishRoute(key)
    local u=key:upper()
    local prefix=(key=="kris" and "02" or "03").."_"..key
    walkToObject(assert(npc("TEXT_KA_JOHTO_GATE_"..u)));dismiss()
    assert(game.overworld.map.id==P.MAPS[u.."_PASSAGE"].id,key.." gate failed")
    shot(prefix.."_arrival")
    marker("TEXT_KA_JOHTO_"..u.."_LANDMARK",prefix.."_landmark")
    marker("TEXT_KA_JOHTO_"..u.."_DECISION_1",prefix.."_decision_1")
    marker("TEXT_KA_JOHTO_"..u.."_DECISION_2",prefix.."_decision_2")
    reloadPassage(P.MAPS[u.."_PASSAGE"].id)
    marker("TEXT_KA_JOHTO_"..u.."_DECISION_3",prefix.."_decision_3")
    marker("TEXT_KA_JOHTO_"..u.."_FINAL_GATE")
    assert(game.overworld.map.id==P.MAPS[u.."_FINALE"].id,key.." final gate failed")
    frameMaster("TEXT_KA_JOHTO_"..u.."_MASTER",prefix.."_finale_npc")
    local lossMoney=assertJohtoBattle(key)
    captureBattleIntro(key,prefix.."_battle_intro_loss")
    -- First attempt deliberately selects the legal non-damaging BARRIER move
    -- through the native menu.  A real loss must retain the puzzle state and
    -- use production's Gate Hall retry warp; no status is manufactured here.
    battle(1,P.MAPS.HALL.id)
    assert(game.overworld.map.id==P.MAPS.HALL.id,key.." loss did not return to Gate Hall")
    local _,restoredIndex=awaitMusic("Music_KA_GSC_IndigoPlateau",nil,
      key.." loss map-theme restore",mapEventIndex+1)
    mapEventIndex=restoredIndex
    assert((tonumber(game.save.money) or 0)==lossMoney,key.." loss changed money")
    assert(P.state(false).passages[key].status=="entered",key.." loss must preserve retry state")
    shot(prefix.."_loss_return")
    walkToObject(assert(npc("TEXT_KA_JOHTO_GATE_"..u)));dismiss()
    assert(game.overworld.map.id==P.MAPS[u.."_PASSAGE"].id,key.." retry gate failed")
    marker("TEXT_KA_JOHTO_"..u.."_FINAL_GATE")
    assert(game.overworld.map.id==P.MAPS[u.."_FINALE"].id,key.." retry finale failed")
    frameMaster("TEXT_KA_JOHTO_"..u.."_MASTER",prefix.."_finale_npc_retry")
    local winMoney=assertJohtoBattle(key)
    captureBattleIntro(key,prefix.."_battle_intro_win")
    battle("best",P.MAPS.HALL.id)
    assert(game.overworld.map.id==P.MAPS.HALL.id,key.." win did not return to Gate Hall")
    local _,winRestore=awaitMusic("Music_KA_GSC_IndigoPlateau",nil,
      key.." win map-theme restore",mapEventIndex+1)
    mapEventIndex=winRestore
    assert((tonumber(game.save.money) or 0)==winMoney,key.." win paid prize money")
    shot(prefix.."_win_return")
    U.log("JOHTO MASTERS PURE QA "..u.." SAVE/RELOAD/WIN/RETURN PASS")
  end
  finishRoute("kris")
  finishRoute("gold")
  -- This is an ordinary post-victory save, followed by a fresh load of the
  -- isolated slot.  It observes the durable one-time Gold prize without
  -- invoking a passage API or manufacturing a reward/state transition.
  assert(game:writeSave(),"native save write failed after Gold reward")
  local rewarded=assert(SaveData.load())
  local ledger=assert(rewarded.modData and rewarded.modData.kanto_ascendant
    and rewarded.modData.kanto_ascendant.johto_masters)
  assert(ledger.gifts==initialGifts+1
      and ledger.connectedClears==initialConnected+1
      and ledger.journeyClears==1 and ledger.activeRun==false
      and ledger.lastHallTicket==initialHall
      and ledger.passages and ledger.passages.gold
    and ledger.passages.gold.rewarded==true,
    "Gold reward did not persist exactly once")
  U.log("JOHTO MASTERS PURE QA GOLD REWARD PERSISTENCE PASS")
  assert(not masters.hostAvailable(game),
    "Gold clear left the host available without another Elite-Four receipt")
  -- The Gold return lands in Gate Hall.  There is no host here and no gate may
  -- begin another run.  A separate post-first-clear setup/receipt continues
  -- from a physical League re-clear before this driver is run a second time.
  assert(not P.canEnter(game,"silver") and not P.canEnter(game,"kris")
      and not P.canEnter(game,"gold"),
    "completed run left an arena gate replayable without an E4 re-clear")

  -- Leave the custom Hall through its authored bottom warp, then traverse the
  -- complete native League.  This is the cadence receipt the second shiny
  -- farm run depends on: appending a Hall row directly would prove nothing.
  walkToCell(1,P.MAPS.HALL.h*2-3,"Gate Hall return warp")
  awaitMap("INDIGO_PLATEAU","Gate Hall return")
  awaitOverworldIdle("Gate Hall outdoor return")
  walkToCell(9,5,"Indigo lobby return door")
  awaitMap("INDIGO_PLATEAU_LOBBY","Gate Hall lobby return")
  awaitOverworldIdle("Gate Hall lobby return")
  for _,flag in ipairs({
    "EVENT_BEAT_LORELEIS_ROOM_TRAINER_0",
    "EVENT_BEAT_BRUNOS_ROOM_TRAINER_0",
    "EVENT_BEAT_AGATHAS_ROOM_TRAINER_0",
    "EVENT_BEAT_LANCES_ROOM_TRAINER_0",
    "EVENT_BEAT_LANCE",
    "EVENT_BEAT_CHAMPION_RIVAL_THIS_RUN",
  }) do
    assert(not game.save.flags[flag],
      "Indigo lobby did not reset prior League flag "..flag)
  end
  for _,key in ipairs({
    "LORELEIS_ROOM_obj_1", "BRUNOS_ROOM_obj_1",
    "AGATHAS_ROOM_obj_1", "LANCES_ROOM_obj_1",
  }) do
    assert(not game.save.defeatedTrainers[key],
      "Indigo lobby did not re-arm League trainer "..key)
  end
  assert(#(game.save.hallOfFame or {})==initialHall,
    "returning from Gate Hall manufactured a League cadence receipt")
  definitions,liveHosts=hostCounts()
  assert(definitions==0 and liveHosts==0 and not masters.hostAvailable(game),
    "host appeared before a physical Elite-Four re-clear")
  walkToCell(8,0,"Lorelei entrance warp")
  awaitMap("LORELEIS_ROOM","League entrance")
  awaitOverworldIdle("Lorelei entrance walk")

  local function awaitLeagueBattle(class,label)
    for _=1,900 do
      local top=game.stack:top()
      if top and top.oppClass==class then
        assert(top.kind=="trainer",label.." did not create a trainer battle")
        return top
      end
      U.tap(game,"a");U.wait(2)
    end
    error(label.." battle did not start")
  end
  local function leagueTrainer(mapId,textId,class,flag,screen)
    assert(game.overworld.map.id==mapId,"wrong League room before "..class)
    walkToObject(assert(npc(textId)))
    awaitLeagueBattle(class,class)
    shot(screen);assertVisibleCapture(screen)
    battle("best",mapId)
    assert(game.save.flags[flag]==true,class.." victory flag missing")
  end
  local function leagueExit(x,nextMap,label,scriptedBattleEntry)
    walkToCell(x,0,label.." exit warp")
    awaitMap(nextMap,label.." exit")
    if not scriptedBattleEntry then
      awaitOverworldIdle(label.." next-room entrance walk")
    end
  end

  leagueTrainer("LORELEIS_ROOM","TEXT_LORELEISROOM_LORELEI",
    "OPP_LORELEI","EVENT_BEAT_LORELEIS_ROOM_TRAINER_0","04_lorelei_reclear")
  leagueExit(4,"BRUNOS_ROOM","Lorelei")
  leagueTrainer("BRUNOS_ROOM","TEXT_BRUNOSROOM_BRUNO",
    "OPP_BRUNO","EVENT_BEAT_BRUNOS_ROOM_TRAINER_0","04_bruno_reclear")
  leagueExit(4,"AGATHAS_ROOM","Bruno")
  leagueTrainer("AGATHAS_ROOM","TEXT_AGATHASROOM_AGATHA",
    "OPP_AGATHA","EVENT_BEAT_AGATHAS_ROOM_TRAINER_0","04_agatha_reclear")
  leagueExit(4,"LANCES_ROOM","Agatha")

  -- Lance is a coordinate-trigger battle, not a talk-script trainer.  The
  -- map's production auto-walk settles at (6,11), then the physical route to
  -- his north trigger starts the real OPP_LANCE encounter.
  awaitOverworldIdle("Lance entrance walk")
  walkToCell(5,1,"Lance battle trigger")
  awaitLeagueBattle("OPP_LANCE","Lance")
  shot("04_lance_reclear");assertVisibleCapture("04_lance_reclear")
  battle("best","LANCES_ROOM")
  assert(game.save.flags.EVENT_BEAT_LANCE==true,"Lance victory flag missing")
  leagueExit(5,"CHAMPIONS_ROOM","Lance",true)

  -- ChampionsRoom.onEnter owns the forced walk, Rival3 battle, Oak scene,
  -- Hall induction, credits save and soft reset.  Drive every visible menu
  -- by input until the real title screen returns; the Hall row must grow by
  -- exactly one before that reset can be accepted.
  awaitLeagueBattle("OPP_RIVAL3","Champion")
  shot("04_champion_reclear");assertVisibleCapture("04_champion_reclear")
  local titleReached=false
  for _=1,30000 do
    local top=game.stack:top()
    if top and top.screenId=="TitleState"
        and #(game.save.hallOfFame or {})==initialHall+1 then
      titleReached=true;break
    end
    driveBattleStep(top,"best")
    U.wait(2)
  end
  assert(titleReached,"Champion re-clear did not record one Hall row and return to title")
  assert(#(game.save.hallOfFame or {})==initialHall+1,
    "Elite-Four re-clear did not produce exactly one cadence receipt")

  -- CONTINUE is still selected through the title UI.  The Hall reset lands
  -- outdoors in Pallet; the legal Dragonite FLY field move then returns to
  -- Indigo without a QA teleport or save-position rewrite.
  U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,600 do
    if game.overworld and game.stack:top()==game.overworld then break end
    U.tap(game,"a");U.wait(3)
  end
  assert(game.overworld and game.stack:top()==game.overworld
      and game.overworld.map.id=="PALLET_TOWN",
    "post-credits CONTINUE did not land outdoors in Pallet")
  assert(masters.hostAvailable(game),
    "physical Elite-Four re-clear did not unlock the next Johto run")

  U.tap(game,"start");U.wait(5)
  local startMenu=assert(game.stack:top())
  local pokemonLabel=Strings("POKéMON")
  for _=1,#(startMenu.items or {})+1 do
    if startMenu.items[startMenu.index]
        and startMenu.items[startMenu.index].label==pokemonLabel then break end
    U.tap(game,"down");U.wait(2)
  end
  assert(startMenu.items[startMenu.index]
      and startMenu.items[startMenu.index].label==pokemonLabel,
    "could not select POKEMON through the Start menu")
  U.tap(game,"a");U.wait(5)
  local partyMenu=assert(game.stack:top())
  while partyMenu.index<6 do U.tap(game,"down");U.wait(2) end
  U.tap(game,"a");U.wait(5)
  local flyIndex
  for index,row in ipairs(partyMenu.subItems or {}) do
    if row.action=="fly" then flyIndex=index break end
  end
  assert(flyIndex,"legal Dragonite FLY action missing in Pallet")
  while partyMenu.subIndex~=flyIndex do U.tap(game,"down");U.wait(2) end
  U.tap(game,"a");U.wait(5)
  local townMap=assert(game.stack:top())
  local indigoIndex
  for index,mapId in ipairs(townMap.flyMapIds or {}) do
    if mapId=="INDIGO_PLATEAU" then indigoIndex=index break end
  end
  assert(indigoIndex,"visited Indigo fly destination missing")
  while townMap.sel~=indigoIndex do U.tap(game,"down");U.wait(2) end
  U.tap(game,"a")
  awaitMap("INDIGO_PLATEAU","physical Fly to Indigo")
  awaitOverworldIdle("physical Fly arrival at Indigo")
  walkToCell(9,5,"Indigo Plateau lobby door")
  awaitMap("INDIGO_PLATEAU_LOBBY","Indigo lobby door")
  awaitOverworldIdle("Indigo lobby door arrival")
  U.wait(36)
  definitions,liveHosts=hostCounts()
  assert(definitions==1 and liveHosts==1 and masters.hostAvailable(game),
    "one physical Hall receipt did not restore exactly one Johto host")
  shot("05_host_after_e4_reclear")
  game.overworld:reloadMap(assert(api.johtoMastersData).map,
    "johto-connected-post-reclear-reload")
  U.wait(90)
  definitions,liveHosts=hostCounts()
  assert(definitions==1 and liveHosts==1,
    "post-reclear reload duplicated or lost the Johto host")
  walkToObject(assert(npc(hostText)))
  hostBox=game.stack:top()
  assert(hostBox and expectedHost[hostBox.text],
    "post-reclear host lost the approved connected-arena text")
  shot("05_host_after_e4_exact_text")
  dismiss()
  assert(game.overworld.map.id==P.MAPS.HALL.id,
    "post-reclear host did not start the next Gate Hall run")
  local nextRun=P.state(false)
  assert(nextRun.activeRun==true and nextRun.runTicket==initialHall+1
      and nextRun.lastHallTicket==initialHall+1
      and nextRun.connectedClears==initialConnected+1
      and nextRun.gifts==initialGifts+1
      and P.canEnter(game,"silver") and not P.canEnter(game,"kris")
      and not P.canEnter(game,"gold"),
    "one Elite-Four receipt did not unlock exactly one fresh Silver-first run")
  U.log("JOHTO MASTERS PURE QA E4 RECLEAR/CADENCE/HOST PASS")
  U.log(("JOHTO CONNECTED PHYSICAL PASS variant=%s renderer=%s "
      .."host_to_silver_kris_gold=PASS loss_retry_reload_music=PASS "
      .."e4_reclear_host_respawn=PASS")
    :format(variant,renderer))
  Runtime.events:removeOwner(musicOwner)
  love.event.quit(0)
end

-- LÖVE normally prints coroutine failures only to the launching terminal.
-- A detached macOS app can lose that terminal after a long acceptance run,
-- which leaves partial screenshots but no actionable failure location.  The
-- optional result file makes the QA outcome durable without changing any
-- gameplay state or swallowing the original error.
return function(game)
  local worker = coroutine.create(run)
  local resultPath = os.getenv("JOHTO_QA_RESULT")
  local function writeResult(value)
    if not resultPath then return end
    local file = assert(io.open(resultPath, "wb"))
    file:write(value)
    file:close()
  end
  while coroutine.status(worker) ~= "dead" do
    local ok, err = coroutine.resume(worker, game)
    if not ok then
      local trace = debug.traceback(worker, tostring(err))
      writeResult("FAIL\n" .. trace .. "\n")
      error(err)
    end
    if coroutine.status(worker) ~= "dead" then coroutine.yield() end
  end
  local variant=tostring(os.getenv("JOHTO_QA_VARIANT") or "MISSING"):upper()
  local renderer=tostring(os.getenv("QA_RENDERER") or "MISSING"):upper()
  writeResult(("PASS\nvariant=%s\nrenderer=%s\n"
      .."host_to_silver_kris_gold=PASS\n"
      .."loss_retry_reload_music=PASS\n"
      .."e4_reclear_host_respawn=PASS\n")
    :format(variant,renderer))
end
