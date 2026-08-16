-- RED product acceptance: every transition, interaction, answer, Strength
-- push, Surf step and return is driven through the normal input queue.  The
-- only prepared state is the separate prerequisite slot (RED + two HMs).
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local Pipelines = require("src.render.Pipelines")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local TextBox = require("src.render.TextBox")
  local Collision = require("src.world.Collision")
  local root = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing RED release traversal outside the immutable package gate")
  local tracePath = os.getenv("INPUT_TRACE") or (root .. "/input_trace.txt")
  local trace = assert(io.open(tracePath, "w"))
  local render = os.getenv("RED_QA_RENDER") == "voxel" and "voxel" or "2d"
  local api, red
  local voxelReceipt, voxelReceiptSerial

  local function selectedAnswer(wantCorrect, actual)
    if wantCorrect then return actual end
    return not actual
  end
  -- Lua's common `a and b or c` pseudo-ternary inverts the intended branch
  -- when b is false.  RED deliberately has both TRUE and FALSE facts, so
  -- hold both false-answer cases as a driver self-test before touching play.
  assert(selectedAnswer(true,false)==false,
    "RED driver cannot select a correct FALSE answer")
  assert(selectedAnswer(false,false)==true,
    "RED driver cannot select an incorrect TRUE answer")

  local function log(...)
    local row={"HEVO RED INPUT",render}
    for i=1,select("#",...) do row[#row+1]=tostring(select(i,...)) end
    trace:write(table.concat(row,"\t"),"\n");trace:flush()
  end
  local function waitOverworld(limit)
    for _=1,limit or 600 do
      if game.overworld and game.stack:top()==game.overworld then return true end
      U.wait(1)
    end
    return false
  end
  local function settle()
    for _=1,720 do
      local ow=game.overworld
      if ow and game.stack:top()==ow and ow.player and not ow.player.moving
        and (ow.player.turnTimer or 0)==0 and #(ow.scriptMoves or {})==0 then return end
      -- A field/status message may legally land on the same frame as a
      -- physical step.  A player must acknowledge it before movement can
      -- continue; record and perform that normal A press instead of treating
      -- the modal as a locomotion softlock.  Choice boxes and every other
      -- screen remain hard failures.
      if getmetatable(game.stack:top())==TextBox then
        log("walk-modal","textbox","acknowledged")
        U.tap(game,"a");U.wait(3)
      end
      U.wait(1)
    end
    local ow=game.overworld
    local p=ow and ow.player
    local top=game.stack:top();local topFields={}
    if type(top)=="table" then
      for key,value in pairs(top) do
        if type(value)~="table" and type(value)~="function" and type(value)~="userdata" then
          topFields[#topFields+1]=tostring(key).."="..tostring(value)
        end
      end
      table.sort(topFields)
    end
    log("settle-timeout",ow and ow.map and ow.map.id,p and p.cellX,p and p.cellY,
      "moving",p and p.moving,"locked",p and p.inputLocked,
      "turn",p and p.turnTimer,"scripts",ow and #(ow.scriptMoves or {}),
      "transitioning",ow and ow.transitioning,"top",tostring(top),
      "meta",tostring(type(top)=="table" and getmetatable(top) or nil),
      "fields",table.concat(topFields,","))
    error("RED physical input did not settle")
  end
  local function dismiss()
    for _=1,300 do
      if game.stack:top()==game.overworld then return true end
      assert(getmetatable(game.stack:top())~=ChoiceBox,"unexpected YES/NO while dismissing")
      U.tap(game,"a");U.wait(3)
    end
    error("RED dialogue did not settle")
  end
  local function waitChoice()
    for _=1,300 do
      if getmetatable(game.stack:top())==ChoiceBox then return end
      U.tap(game,"a");U.wait(3)
    end
    error("RED YES/NO choice did not appear")
  end
  local function choose(yes)
    waitChoice()
    if yes then U.tap(game,"up");U.wait(3) end -- questions default safely to NO
    U.tap(game,"a");U.wait(8)
  end
  local function shot(name)
    assert(waitOverworld(),"field unavailable for screenshot")
    local beforeReceipt=voxelReceipt and voxelReceipt.serial or 0
    U.tap(game,"b");U.wait(18)
    assert(game.stack:top()==game.overworld,"field overlay obscures screenshot")
    if render=="voxel" then
      local mapId=game.overworld.map.id
      local ready=false
      for _=1,1800 do
        local receipt=voxelReceipt
        if receipt and receipt.serial>beforeReceipt and receipt.mapId==mapId then
          ready=true;break
        end
        U.wait(1)
      end
      assert(ready,"fresh DRAMALESS world canvas was not presented: "..mapId)
      local receipt=assert(voxelReceipt)
      assert(receipt.serial>beforeReceipt,
        "Voxel capture reused a stale worldPresent frame")
      assert(receipt.mapId==game.overworld.map.id,
        "Voxel capture receipt belongs to a different map")
      local width,height=receipt.canvas:getDimensions()
      assert(width>0 and height>0,"Voxel worldPresent returned an empty canvas")
      log("voxel-receipt",name,"serial",receipt.serial,"map",receipt.mapId,
        "canvas",width,height)
    end
    assert(U.shot(game,root.."/"..render.."/"..name..".png"),"capture failed: "..name)
  end

  local dirs={{1,0,"right"},{-1,0,"left"},{0,1,"down"},{0,-1,"up"}}
  local byDir={};for _,d in ipairs(dirs) do byDir[d[3]]=d end
  local opposite={right="left",left="right",down="up",up="down"}
  local function blocked(x,y)
    for _,n in ipairs(game.overworld.npcs or {}) do
      if n.cellX==x and n.cellY==y then return true end
    end
    return false
  end
  local function state()
    local ow=assert(game.overworld);local p=assert(ow.player)
    return {map=ow.map.id,x=p.cellX,y=p.cellY,facing=p.facing}
  end
  local function stateKey(s) return table.concat({s.map,s.x,s.y,s.facing},":") end
  local function warpAt(map,x,y)
    for _,w in ipairs(map.def.warps or {}) do if w.x==x and w.y==y then return w end end
  end
  local function passable(map,x,y)
    return map:inBounds(x,y) and (map:isWalkableCell(x,y)
      or (game.overworld.player.surfing and map:isWaterCell(x,y)))
  end
  local function simulate(s,dir,allowWarp)
    if s.map~=game.overworld.map.id then return nil end
    if s.facing~=dir then return {map=s.map,x=s.x,y=s.y,facing=dir} end
    local d=byDir[dir];local x,y=s.x+d[1],s.y+d[2];local map=game.overworld.map
    -- Map:isWalkableCell alone is not a movement proof: Gen-I CAVERN has
    -- directional tile-pair/elevation collisions.  Model the exact shipped
    -- Collision.canMove contract so the acceptance driver never invents a
    -- route that a player's D-pad cannot traverse.
    local entities={}
    for _,entity in ipairs(game.overworld.entities or {}) do
      if entity~=game.overworld.player then entities[#entities+1]=entity end
    end
    local mover={cellX=s.x,cellY=s.y,surfing=game.overworld.player.surfing}
    local allowed=Collision.canMove(map,entities,mover,dir)
    if not allowed then return nil end
    if not allowWarp and warpAt(map,x,y) then return nil end
    return {map=s.map,x=x,y=y,facing=dir}
  end
  local function planTo(x,y)
    local start=state();local first=stateKey(start);local queue,head={start},1
    local prev={[first]=false};local finish
    while queue[head] do
      local here=queue[head];head=head+1
      if here.x==x and here.y==y then finish=stateKey(here);break end
      for _,d in ipairs(dirs) do
        local nxt=simulate(here,d[3],false);local key=nxt and stateKey(nxt)
        if key and prev[key]==nil then prev[key]={from=stateKey(here),dir=d[3],want=nxt};queue[#queue+1]=nxt end
      end
    end
    assert(finish,("no physical RED route to %d,%d on %s"):format(x,y,start.map))
    local out={};while finish~=first do local row=assert(prev[finish]);table.insert(out,1,row);finish=row.from end
    return out
  end
  local function execute(plan,label)
    local moved=0
    for i,row in ipairs(plan) do
      local before=state();U.tap(game,row.dir);settle();local after=state()
      log(label,i,row.dir,before.map,before.x,before.y,"=>",after.map,after.x,after.y)
      assert(after.map==row.want.map and after.x==row.want.x and after.y==row.want.y
        and after.facing==row.want.facing,"RED planner/product divergence")
      if after.map~=before.map or after.x~=before.x or after.y~=before.y then
        moved=moved+1
      end
    end
    return moved
  end
  local function go(x,y)
    local plan=planTo(x,y)
    return execute(plan,"walk")
  end
  local function npc(name)
    for _,n in ipairs(game.overworld.npcs or {}) do
      if n.def and n.def.name==name then return n end
    end
    error("live RED object missing: "..name.." on "..game.overworld.map.id)
  end
  local function approach(name)
    local n=npc(name);local choice
    for _,d in ipairs(dirs) do
      local x,y=n.cellX+d[1],n.cellY+d[2]
      if passable(game.overworld.map,x,y) and not blocked(x,y) then
        local ok,plan=pcall(planTo,x,y)
        if ok then choice={plan=plan,face=opposite[d[3]]};break end
      end
    end
    assert(choice,"no physical approach for "..name)
    local moved=execute(choice.plan,"object:"..name)
    -- A blocking statue safely absorbs an extra facing press, but transparent
    -- metadata anchors are intentionally passable.  Pressing the already
    -- active direction again would walk *onto* such an anchor and make the
    -- subsequent A press target the cell beyond it.  Turn only when needed
    -- and prove that this final orientation step changed no world position.
    local before=state()
    if before.facing~=choice.face then
      U.tap(game,choice.face);settle()
      local after=state()
      assert(after.map==before.map and after.x==before.x and after.y==before.y,
        "orienting toward "..name.." moved onto its interaction anchor")
    end
    assert(state().facing==choice.face,"failed to face interaction "..name)
    return choice.face,moved
  end
  local function interact(name)
    approach(name);U.tap(game,"a");U.wait(8);log("interact",name)
  end
  local function physicalWarp(index,expected,approachShot)
    local map=game.overworld.map;local w=assert(map.def.warps[index],"missing warp "..index)
    local pad
    for _,d in ipairs(dirs) do
      local x,y=w.x+d[1],w.y+d[2]
      if passable(map,x,y) and not blocked(x,y) then
        local ok,plan=pcall(planTo,x,y)
        if ok then pad={plan=plan,dir=opposite[d[3]]};break end
      end
    end
    assert(pad,"no physical approach for warp "..index.." on "..map.id)
    execute(pad.plan,"warp-approach:"..index)
    if approachShot then
      local before=state()
      if before.facing~=pad.dir then
        U.tap(game,pad.dir);settle()
        local after=state()
        assert(after.map==before.map and after.x==before.x and after.y==before.y,
          "turning toward warp moved before its approach capture")
      end
      shot(approachShot)
    end
    for press=1,2 do
      local before=state();U.tap(game,pad.dir);settle();local after=state()
      log("native-warp",index,press,pad.dir,before.map,before.x,before.y,"=>",after.map,after.x,after.y)
      if after.map~=before.map then break end
    end
    U.wait(30)
    assert(game.overworld.map.id==expected,("warp %s reached %s, expected %s"):format(index,game.overworld.map.id,expected))
  end
  local function question(name,wantCorrect)
    local beforeSight=red.run(game.save,true).sight or 0
    interact(name);waitChoice()
    local run=red.run(game.save,true);local id=assert(run.pending and run.pending[name],"question was not queued")
    local q;for _,candidate in ipairs(red.questions) do if candidate.id==id then q=candidate;break end end
    assert(q,"queued RED question absent from pool")
    choose(selectedAnswer(wantCorrect,q.answer));dismiss()
    local after=red.run(game.save,true)
    assert(after.asked[id]==true,"answered RED question was not consumed")
    if wantCorrect then assert((after.sight or 0)==beforeSight+1,"correct RED answer did not raise sight")
    else assert((after.sight or 0)==beforeSight,"wrong RED answer changed sight") end
    log("question",name,id,wantCorrect and "correct" or "wrong",q.answer,"sight",after.sight or 0)
    return id
  end
  local function statueShot(name,file,expectedSight)
    local run=red.run(game.save,true)
    assert((run.sight or 0)==expectedSight,
      name.." reached outside the required RED statue order")
    approach(name)
    local ow=assert(game.overworld);local p=assert(ow.player)
    local sight=assert(ow.kaHevoRedSight,"RED sight profile absent at "..name)
    local nearby={}
    for _,candidate in ipairs(ow.npcs or {}) do
      local candidateName=candidate.def and candidate.def.name or ""
      if candidateName:match("^KA_RED_STATUE_[1-5]$") then
        local dx,dy=candidate.cellX-p.cellX,candidate.cellY-p.cellY
        local distance=math.sqrt(dx*dx+dy*dy)
        if distance<=sight.radius then
          nearby[#nearby+1]=candidateName
        end
      end
    end
    table.sort(nearby)
    assert(#nearby==1 and nearby[1]==name,
      name.." niche exposes another statue inside the conservative sight radius: "
        ..table.concat(nearby,","))
    log("single-statue-gate",name,"sight",expectedSight,"radius",sight.radius)
    shot(file)
  end
  local function resetUpper()
    interact("KA_RED_RESET_UPPER");choose(true);assert(waitOverworld(),"reset did not return to field")
    local b=red.run(game.save,true).boulders or {}
    assert(not b.A and not b.B and not b.C,"reset retained a loose boulder result")
    log("reset","upper","confirmed")
  end
  local function push(name,key,x,y,dir)
    go(x,y);U.tap(game,dir);settle();U.tap(game,"a");U.wait(8);dismiss()
    for attempt=1,80 do
      local before=state();U.tap(game,dir);settle();local after=state()
      local done=(red.run(game.save,true).boulders or {})[key]==true
      local rock
      for _,candidate in ipairs(game.overworld.npcs or {}) do
        if candidate.def and candidate.def.name==name then rock=candidate;break end
      end
      log("strength",name,attempt,dir,before.x,before.y,"=>",after.x,after.y,
        "rock",rock and rock.cellX or "hidden",rock and rock.cellY or "hidden",
        "moving",rock and rock.moving or false,"active",game.overworld.strengthActive==true,done)
      if done then return end
    end
    error("Strength push never reached socket: "..name)
  end
  local function surf(fromY,toY,dir)
    local x=31
    go(x,fromY);U.tap(game,dir);settle();U.tap(game,"a");U.wait(8);dismiss();U.wait(24)
    assert(game.overworld.player.surfing,"A-button did not mount SURF")
    for step=1,20 do
      if game.overworld.player.cellY==toY then break end
      local before=state();U.tap(game,dir);settle();local after=state()
      log("surf",step,dir,before.x,before.y,"=>",after.x,after.y)
    end
    assert(game.overworld.player.cellX==x and game.overworld.player.cellY==toY,"physical SURF did not reach dry shelf")
    assert(not game.overworld.player.surfing,"landing did not dismount SURF")
  end
  local function reload(expected)
    assert(game:writeSave(),"native RED save write failed")
    local loaded,recovered=assert(SaveData.load())
    game:restoreSave(loaded,recovered)
    assert(waitOverworld(720),"native RED reload did not settle")
    assert(game.overworld.map.id==expected,"native RED reload map mismatch")
    Pipelines.setLevel("voxel",render=="voxel" and 1 or 0);Pipelines.syncOptions(game.save.options)
    log("native-save-reload",expected)
  end
  local function fallToRecovery(index,label)
    local source=assert(game.overworld and game.overworld.map and game.overworld.map.id)
    assert(source=="KA_HEVO_RED_UPPER" or source=="KA_HEVO_RED_ABYSS",
      "RED fall exercise started outside an authored fall floor")
    physicalWarp(index,"KA_HEVO_RED_RECOVERY",label.."_edge")
    local run=red.run(game.save,true)
    assert(run.recovered==true,"RED fall did not mark the recoverable refuge")
    shot(label.."_recovery")
    log("recoverable-fall",label,"source",source,"warp",index,
      "landing",game.overworld.player.cellX,game.overworld.player.cellY)
  end

  -- Native CONTINUE is the proof boundary. No test teleport occurs below.
  U.wait(5);U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,600 do
    if game.overworld and game.stack:top()==game.overworld then break end
    U.tap(game,"a");U.wait(3)
  end
  assert(game.overworld and game.stack:top()==game.overworld,"CONTINUE did not reach RED field")
  api=assert(game.mods.exports.kanto_ascendant);red=assert(api.hiddenEvolutionCampaign.modules.RED)
  assert(api.extendedCharacters.getPlayerCharacter()=="RED","fixture is not RED")
  local variant=tostring(os.getenv("HEVO_QA_VARIANT") or "FRESH"):upper()
  assert(variant=="FRESH" or variant=="ALT","invalid RED HEVO_QA_VARIANT")
  if variant=="ALT" then
    local origin=assert(game.save.qaHevoAltOrigin,"RED ALT migration receipt missing")
    assert(origin.variant=="ALT" and origin.playerCharacter=="RED"
        and origin.sourceSha256==os.getenv("KA_SOURCE_SAVE_SHA256")
        and origin.packageGateReceiptSha256
          ==os.getenv("KA_PACKAGE_GATE_RECEIPT_SHA256"),
      "RED ALT migration receipt drifted")
    log("alt-origin",origin.kind,origin.sourceSha256,origin.renderer)
  end
  if os.getenv("RED_QA_TARGETED_ONLY")=="1" then
    -- Natural habitat/contact acceptance is a separate release gate.  This
    -- bounded mask run must not be randomly interrupted while walking to the
    -- exact sight0/statue/item cells, so clear only the disposable live Wilds
    -- entities after the real fissure transition has been proven.
    local wilds=game.mods.exports.overworld_wild_spawns
    if wilds and wilds.logic then
      wilds.logic:clearAll()
      wilds.logic.featureActive=function() return false end
    end
    local encounter=game.data.encounters[game.overworld.map.id]
    if encounter then encounter.grass={rate=0,slots={}} end
  end
  Pipelines.setLevel("voxel",render=="voxel" and 1 or 0);Pipelines.syncOptions(game.save.options)
  local livePipeline=Pipelines.worldPipeline()
  assert(render=="voxel" and livePipeline=="voxel"
      or render=="2d" and livePipeline~="voxel",
    "requested world pipeline is not live: "..tostring(livePipeline))
  if render=="voxel" then
    local present=Pipelines.worldPresent
    voxelReceiptSerial=0
    Pipelines.worldPresent=function(canvas,ctx)
      local out=present(canvas,ctx)
      local mapId=ctx and ctx.state and ctx.state.map and ctx.state.map.id
      if out and mapId then
        voxelReceiptSerial=voxelReceiptSerial+1
        voxelReceipt={serial=voxelReceiptSerial,mapId=mapId,canvas=out}
      end
      return out
    end
  end

  assert(game.overworld.map.id=="ROUTE_22",
    "fixture did not start at RED's real Route-22 fissure")
  assert(game.overworld.player.cellX==35 and game.overworld.player.cellY==2,
    "fixture missed RED's exact Route-22 approach cell")
  local fissure=npc("KA_HEVO_FISSURE_RED")
  assert(fissure.cellX==35 and fissure.cellY==1 and fissure.passable==true,
    "RED fissure anchor is not the passable wall-local interaction metadata")
  shot("00_route22_hairline_fissure")
  if render=="voxel" then
    local bridge=assert(api.dramalessWallDecalsCompat,
      "DRAMALESS wall-decal package bridge missing")
    assert(bridge.mode=="native" or bridge.mode=="adapter",
      "Voxel wall decals inactive: "..tostring(bridge.mode))
    if bridge.mode=="adapter" then
      local receipt=assert(bridge.lastDrawn,
        "RED Voxel fissure produced no depth-scene draw receipt")
      assert(bridge.drawCount>0 and receipt.id=="KA_HEVO_WALL_FISSURE_RED"
          and receipt.mapId=="ROUTE_22" and receipt.cellX==35
          and receipt.cellY==1 and bridge.lastError==nil,
        "RED Voxel fissure receipt has the wrong wall identity")
    end
    log("wall-decal-receipt","RED",bridge.mode,bridge.drawCount)
  end
  interact("KA_HEVO_FISSURE_RED")
  -- The product now deliberately asks before crossing the wall (default NO)
  -- after describing the character-specific draft.  Accept it through the
  -- real ChoiceBox instead of assuming the older immediate-warp contract.
  choose(true)
  assert(waitOverworld(720) and game.overworld.map.id=="KA_HEVO_TUNNEL_ALL",
    "Route-22 fissure did not reach RED's shared shaft")
  shot("01_shared_tunnel_red_branch")
  physicalWarp(4,"KA_HEVO_RED_UPPER");shot("02_upper_entry")
  if os.getenv("RED_QA_TARGETED_ONLY")=="1" then
    -- The trial table is published on this map entry after the earlier
    -- Route-22 cleanup.  Disable its classic roll too for the bounded visual
    -- walk; real Lv70 contact battles are accepted by the habitat driver.
    local trialEncounter=game.data.encounters[game.overworld.map.id]
    if trialEncounter then trialEncounter.grass={rate=0,slots={}} end
    -- Stand south and look north for the visual gate. DRAMALESS' default
    -- camera then keeps the statue/tablet behind the player's billboard;
    -- the follower remains a full cell farther south instead of sharing the
    -- same projected horizontal band.
    go(3,7);U.tap(game,"up");settle();shot("01a_sight0_player_statue")
    go(11,32);U.tap(game,"up");settle();shot("01b_sight0_player_field_item")
    question("KA_RED_STATUE_1",true)
    go(3,7);U.tap(game,"up");settle();shot("01c_sight1_player_statue")
    U.log("HEVO RED TARGETED VISUAL PASS",render,"sight0/statue/item/sight1")
    trace:close();love.event.quit(0);return
  end
  statueShot("KA_RED_STATUE_1","03a_statue1_hidden_niche_sight0",0)
  local wrong=question("KA_RED_STATUE_1",false);local correct=question("KA_RED_STATUE_1",true)
  assert(wrong~=correct,"wrong answer repeated the same question")
  assert((red.run(game.save,true).sight or 0)==1,
    "Statue 1 did not establish RED sequence stage 1")
  approach("KA_RED_STATUE_1");shot("03b_statue1_lit_niche_sight1")
  statueShot("KA_RED_STATUE_2","04a_statue2_hidden_niche_sight1",1)
  question("KA_RED_STATUE_2",true)
  assert((red.run(game.save,true).sight or 0)==2,
    "Statue 2 did not establish RED sequence stage 2")
  shot("04b_upper_after_two_statues")

  push("KA_RED_BOULDER_A","A",12,29,"right")
  resetUpper();shot("05a_upper_after_fair_reset")
  push("KA_RED_BOULDER_A","A",12,29,"right");shot("05b_strength_socket_A")
  push("KA_RED_BOULDER_B","B",21,26,"up");shot("05c_strength_socket_B")
  push("KA_RED_BOULDER_C","C",30,17,"right");shot("05d_strength_socket_C")
  do
    local b=red.run(game.save,true).boulders or {}
    assert(b.A==true and b.B==true and b.C==true,
      "three native Strength boulders did not persist in their sockets")
  end

  -- Every optional upper-floor drop is physically entered, lands in the
  -- common refuge and leaves through its matching ladder.  The first two
  -- loops return through Abyss->Upper; the third becomes the intended route
  -- into Recovery and preserves the secret/save checkpoint below.
  fallToRecovery(3,"06a_upper_fall_1")
  physicalWarp(3,"KA_HEVO_RED_ABYSS");physicalWarp(1,"KA_HEVO_RED_UPPER")
  shot("06b_upper_return_after_fall_1")
  fallToRecovery(4,"06c_upper_fall_2")
  physicalWarp(4,"KA_HEVO_RED_ABYSS");physicalWarp(1,"KA_HEVO_RED_UPPER")
  shot("06d_upper_return_after_fall_2")
  fallToRecovery(5,"06e_upper_fall_3")
  interact("KA_RED_SECRET_HINT");dismiss()
  interact("KA_RED_BLAZIKENITE_SECRET");dismiss();shot("07a_recovery_blazikenite_claim")
  reload("KA_HEVO_RED_RECOVERY")
  local persistent=assert(api.hevoPackages.persistent(game.save,false))
  assert(persistent.secretUnlocks.RED==true and persistent.permanentItems.BLAZIKENITE==true,
    "Lohgocknit did not persist through native reload")
  shot("07b_recovery_after_secret_reload")
  physicalWarp(5,"KA_HEVO_RED_ABYSS");shot("08a_abyss_entry")

  -- The four Abyss drops are independent false decisions.  Each one must
  -- visibly land in Recovery and use the matching physical ladder back;
  -- no controller warp or fixture reset is allowed between them.
  for index=3,6 do
    local label=("08_f_abyss_fall_%d"):format(index-2)
    fallToRecovery(index,label)
    physicalWarp(index,"KA_HEVO_RED_ABYSS")
    log("recovery-return",label,"warp",index,"map",game.overworld.map.id)
  end
  statueShot("KA_RED_STATUE_3","09a_statue3_hidden_niche_sight2",2)
  question("KA_RED_STATUE_3",true)
  assert((red.run(game.save,true).sight or 0)==3,
    "Statue 3 did not establish RED sequence stage 3")
  statueShot("KA_RED_STATUE_4","09b_statue4_hidden_niche_sight3",3)
  question("KA_RED_STATUE_4",true)
  assert((red.run(game.save,true).sight or 0)==4,
    "Statue 4 did not establish RED sequence stage 4")
  shot("09c_abyss_after_two_statues")

  physicalWarp(2,"KA_HEVO_RED_LOWER");shot("10a_lower_before_surf")
  surf(24,17,"up")
  statueShot("KA_RED_STATUE_5","10b_statue5_hidden_niche_sight4",4)
  question("KA_RED_STATUE_5",true)
  assert((red.run(game.save,true).sight or 0)==5,
    "Statue 5 did not establish RED sequence stage 5")
  approach("KA_RED_STATUE_5");shot("10c_statue5_lit_niche_sight5")
  assert(red.canEnterShrine(game.save),"five statues + three sockets did not open shrine")

  -- Do not let Statue 5 read like an endpoint: prove the long folded return
  -- out of its cul-de-sac, then another substantial ceremonial spiral in the
  -- Shrine before the reward.  Count actual cell changes, not turn presses.
  local lowerAfterStatue5=go(41,5)
  assert(lowerAfterStatue5>=40,
    "Statue 5 leaves fewer than forty physical cells before LOWER's exit road")
  log("statue5-long-return","lowerCells",lowerAfterStatue5,"to",41,5)
  shot("10d_lower_long_return_after_statue5")
  physicalWarp(2,"KA_HEVO_RED_SHRINE");shot("11a_shrine_entry_after_statue5")
  local shrineAfterStatue5=go(31,14)
  assert(shrineAfterStatue5>=40,
    "Shrine spiral after Statue 5 is shorter than forty physical cells")
  U.tap(game,"up");settle()
  log("statue5-long-finale","lowerCells",lowerAfterStatue5,
    "shrineCells",shrineAfterStatue5,"total",lowerAfterStatue5+shrineAfterStatue5)
  shot("11b_shrine_long_spiral_before_reward")
  interact("KA_RED_RESEARCH_CACHE");dismiss();shot("12a_shrine_after_finalize")
  interact("KA_RED_GROUDON_SEAL");dismiss()
  physicalWarp(2,"KA_HEVO_SHARED_SEALED_ANTECHAMBER");shot("12b_groudon_end_chamber")
  interact("KA_HEVO_SHARED_SEALED_DOOR");dismiss();shot("12c_after_groudon_teaser")
  do
    local receipt=assert(api.hiddenEvolutionCampaign.modules.shared.handoff(),
      "RED final warp emitted no durable character receipt")
    assert(receipt.character=="RED" and receipt.seal==true
        and receipt.sourceMap=="KA_HEVO_RED_SHRINE"
        and receipt.stone=="BLAZIKENITE"
        and (receipt.stoneStatus=="granted" or receipt.stoneStatus=="claimed")
        and receipt.acknowledged==true,
      "RED final receipt lost shrine/stone/door authority")
    assert(api.megaEvolution.hasStone("BLAZIKENITE"),
      "RED final chain did not put BLAZIKENITE in the Stone Case")
    local bucket=assert(game.save.modData.kanto_ascendant)
    local gate=assert(bucket[api.legacyJourney.HEVO_GATE_KEY],
      "RED final chain created no Legacy Journey gate")
    assert(gate.character=="RED" and gate.ready==true
        and gate.doorAcknowledged==true and gate.oakCalled==true
        and gate.pendingCall~=true
        and game.save.flags[api.legacyJourney.HEVO_READY_FLAG]==true
        and game.save.flags[api.legacyJourney.HEVO_OAK_CALLED_FLAG]==true,
      "RED final chain did not complete the one-time Oak call")
    local canBegin,owner=api.legacyJourney.canBegin(game.save)
    assert(canBegin==true and owner=="RED",
      "RED sealed save did not unlock only RED's Legacy Journey")
    log("end-receipt","RED",receipt.sourceMap,receipt.stone,
      receipt.stoneStatus,"oak-called","legacy-ready")
  end
  physicalWarp(1,"KA_HEVO_RED_SHRINE")
  physicalWarp(1,"KA_HEVO_RED_LOWER");surf(17,24,"down")
  physicalWarp(1,"KA_HEVO_RED_ABYSS");physicalWarp(1,"KA_HEVO_RED_UPPER")
  physicalWarp(1,"KA_HEVO_TUNNEL_ALL");physicalWarp(1,"ROUTE_22");shot("13_route22_return")

  -- The exterior return must be a genuinely free landing cell.  Wilds also
  -- rebuilds occupancy here, so a transparent interaction actor or another
  -- runtime NPC on top of the player is a gameplay defect, not harmless log
  -- noise.  Record the exact owner before failing so the product fix remains
  -- actionable if a later entrance edit regresses this contract.
  do
    local p=assert(game.overworld.player)
    local overlaps={}
    for _,candidate in ipairs(game.overworld.npcs or {}) do
      if candidate.cellX==p.cellX and candidate.cellY==p.cellY
          and candidate.passable~=true then
        overlaps[#overlaps+1]=candidate.def and candidate.def.name
          or candidate.id or tostring(candidate)
      end
    end
    log("exterior-return-occupancy",p.cellX,p.cellY,table.concat(overlaps,","))
    assert(#overlaps==0,"RED exterior return overlaps blocking NPC(s): "
      ..table.concat(overlaps,","))
  end

  reload("ROUTE_22")
  local run=red.run(game.save,false);persistent=assert(api.hevoPackages.persistent(game.save,false))
  assert(run and run.completed==true,"RED finalize flag did not survive native save/reload")
  assert(persistent.meta.RED==true,"RED permanent seal did not survive native save/reload")
  assert(persistent.secretUnlocks.RED==true and persistent.permanentItems.BLAZIKENITE==true,
    "RED optional Mega secret did not survive final reload")

  -- Re-entry is part of the release contract, not implied by a correct
  -- return coordinate.  From the natively reloaded Route-22 save, face and
  -- activate the real wall anchor, then use the shared tunnel's physical
  -- return pad again.  No test teleport or controller call is involved.
  interact("KA_HEVO_FISSURE_RED")
  choose(true)
  assert(waitOverworld(720) and game.overworld.map.id=="KA_HEVO_TUNNEL_ALL",
    "completed RED fissure re-entry did not reach the shared tunnel")
  shot("17_shared_reentry_after_reload")
  physicalWarp(1,"ROUTE_22");shot("18_route22_return_after_reentry")
  do
    local p=assert(game.overworld.player)
    assert(p.cellX==35 and p.cellY==2,
      "RED re-entry return missed the exact Route-22 approach")
    for _,candidate in ipairs(game.overworld.npcs or {}) do
      assert(not (candidate.cellX==p.cellX and candidate.cellY==p.cellY
          and candidate.passable~=true),
        "RED re-entry return overlaps blocking NPC "
          ..tostring(candidate.def and candidate.def.name or candidate.id))
    end
  end
  log("completed-reentry","ROUTE_22",35,2)
  local result=assert(io.open(root.."/driver_result.txt","wb"),
    "could not write RED full-path package receipt")
  result:write("status=PASS\n")
  result:write("scope=HEVO-FULL-PATH\n")
  result:write("character=RED\n")
  result:write("edition=",tostring(os.getenv("POKEPORT_VERSION")),"\n")
  result:write("renderer=",render,"\n")
  result:write("variant=",variant,"\n")
  result:write("stone=BLAZIKENITE\n")
  result:write("native_save_reload=1/1\n")
  result:write("reentry=1/1\n")
  result:write("fail=0\n")
  result:close()
  U.log("HEVO RED PACKAGE END RECEIPT",variant,"BLAZIKENITE",
    "oak-called","legacy-ready","native-reload","reentry")
  U.log("HEVO RED INPUT PASS",render,"wrong/reset/fall/recovery/strength/surf/save/secret/finalize/Groudon/return/reentry")
  trace:close();love.event.quit(0)
end
