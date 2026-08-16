-- GREEN release acceptance: after title-screen CONTINUE, every transition,
-- question, gate, reset, secret, reward and return uses ordinary player input.
-- The companion setup creates only a fresh GREEN traveler on Route 3.
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local Pipelines = require("src.render.Pipelines")
  local TextBox = require("src.render.TextBox")
  local root = assert(os.getenv("SHOT_DIR"), "SHOT_DIR required")
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing GREEN release traversal outside the immutable package gate")
  local tracePath = os.getenv("INPUT_TRACE") or (root .. "/input_trace.txt")
  local trace = assert(io.open(tracePath, "w"))
  local render = os.getenv("GREEN_QA_RENDER") == "voxel" and "voxel" or "2d"
  local api, green
  local voxelReceipt

  local function log(...)
    local row = { "HEVO GREEN INPUT", render }
    for i=1,select("#",...) do row[#row+1]=tostring(select(i,...)) end
    trace:write(table.concat(row,"\t"),"\n");trace:flush()
  end
  local function waitOverworld(limit)
    for _=1,limit or 720 do
      if game.overworld and game.stack:top()==game.overworld then return true end
      U.wait(1)
    end
    return false
  end
  local function settle()
    local incidental
    for _=1,720 do
      local ow=game.overworld
      local top=game.stack:top()
      local fieldSettled=ow and ow.player and not ow.player.moving
        and (ow.player.turnTimer or 0)==0 and #(ow.scriptMoves or {})==0
      if fieldSettled and top==ow then return end
      -- Long physical labyrinth runs legitimately cross the independent
      -- Johto/Oak step-call cadence.  It is an ordinary TextBox raised after
      -- the committed field step, not a GREEN collision or softlock.  Advance
      -- that passive call with real A input and keep every other unexpected
      -- state (choice, battle, menu, transition) as a hard diagnostic failure.
      if fieldSettled and getmetatable(top)==TextBox then
        if not incidental then
          incidental=true
          log("incidental-textbox",ow.map.id,ow.player.cellX,ow.player.cellY)
        end
        U.tap(game,"a");U.wait(3)
      else
        U.wait(1)
      end
    end
    local ow=game.overworld;local p=ow and ow.player or {}
    local top=game.stack:top()
    local script={}
    for index,mv in ipairs(ow and ow.scriptMoves or {}) do
      local entity=mv.entity or {}
      script[#script+1]=table.concat({index,
        entity.id or entity.followerSpecies or
          (entity.def and entity.def.name) or "entity",
        entity.cellX or "?",entity.cellY or "?",
        entity.moving and "moving" or "idle",mv.remaining or "?"},":")
    end
    error(("GREEN physical input did not settle: map=%s player=%s,%s "..
      "facing=%s moving=%s turn=%s top=%s scripts=%d[%s] runner=%s")
      :format(tostring(ow and ow.map and ow.map.id),tostring(p.cellX),
        tostring(p.cellY),tostring(p.facing),tostring(p.moving),
        tostring(p.turnTimer),top==ow and "overworld" or tostring(top),
        #(ow and ow.scriptMoves or {}),table.concat(script,","),
        tostring(ow and ow.runner and ow.runner:isRunning())))
  end
  local function dismiss()
    for _=1,360 do
      if game.stack:top()==game.overworld then return true end
      U.tap(game,"a");U.wait(3)
    end
    error("GREEN dialogue did not settle")
  end
  local ChoiceBox = require("src.ui.ChoiceBox")
  local function acceptFissure()
    for _=1,360 do
      local top=game.stack:top()
      if getmetatable(top)==ChoiceBox then
        U.tap(game,"up");U.wait(3) -- default is deliberately NO
        U.tap(game,"a");U.wait(8)
        return true
      end
      U.tap(game,"a");U.wait(3)
    end
    error("GREEN fissure confirmation did not appear")
  end
  local function opaqueExteriorPixels(path,evidence)
    assert(evidence and evidence.shaderActive,
      "GREEN capture lacks the live opaque-exterior shader")
    assert(evidence.outerOpaque and evidence.outerAlpha==1,
      "GREEN capture exterior is not fully opaque")
    assert(type(evidence.outerColor)=="table"
        and type(evidence.outerSamples)=="table"
        and #evidence.outerSamples>=8,
      "GREEN capture lacks exterior pixel samples")
    assert(love.image and love.image.newImageData and love.filesystem
        and love.filesystem.newFileData,
      "GREEN capture cannot decode its PNG for pixel validation")
    local file=assert(io.open(path,"rb"));local bytes=file:read("*a");file:close()
    local image=assert(love.image.newImageData(
      love.filesystem.newFileData(bytes,"green_opaque_sample.png")))
    local width,height=image:getWidth(),image:getHeight()
    local frameWidth,frameHeight=assert(evidence.frameWidth),
      assert(evidence.frameHeight)
    local tolerance=evidence.outerTolerance or 2/255
    local expected={}
    for channel=1,3 do
      expected[channel]=math.floor(evidence.outerColor[channel]*255+0.5)/255
    end
    local minima={1,1,1};local maxima={0,0,0}
    local canonical
    for index,point in ipairs(evidence.outerSamples) do
      local x=math.max(0,math.min(width-1,
        math.floor(point.x*width/frameWidth+0.5)))
      local y=math.max(0,math.min(height-1,
        math.floor(point.y*height/frameHeight+0.5)))
      local r,g,b,a=image:getPixel(x,y);local rgba={r,g,b}
      assert(a>=1-1/255,
        ("GREEN exterior sample %d leaked alpha %.5f"):format(index,a))
      for channel=1,3 do
        minima[channel]=math.min(minima[channel],rgba[channel])
        maxima[channel]=math.max(maxima[channel],rgba[channel])
        assert(math.abs(rgba[channel]-expected[channel])<=tolerance,
          ("GREEN exterior sample %d channel %d leaked scene %.5f != %.5f")
            :format(index,channel,rgba[channel],expected[channel]))
      end
      local bytesAtPoint={math.floor(r*255+0.5),math.floor(g*255+0.5),
        math.floor(b*255+0.5),math.floor(a*255+0.5)}
      canonical=canonical or bytesAtPoint
      for channel=1,4 do
        assert(bytesAtPoint[channel]==canonical[channel],
          "GREEN exterior samples are not byte-identical")
      end
    end
    for channel=1,3 do
      assert(maxima[channel]-minima[channel]<=tolerance,
        "GREEN exterior differs between unrelated scene samples")
    end
    assert(canonical[1]==canonical[2] and canonical[2]==canonical[3]
        and canonical[1]>=8 and canonical[1]<=96,
      "GREEN exterior is not a neutral dark gray")
    return #evidence.outerSamples
  end
  local function shot(name)
    assert(waitOverworld(),"field unavailable for screenshot")
    if render=="voxel" then
      voxelReceipt=nil
      if green and green.layouts[game.overworld.map.id] then
        green._voxelFogEvidence=nil
      end
    end
    U.tap(game,"b");U.wait(18)
    assert(game.stack:top()==game.overworld,"field overlay obscures screenshot")
    -- DRAMALESS is asynchronous: a GREEN map is not capture-ready until the
    -- post-present fog hook has actually composited into that map's Voxel
    -- canvas.  Waiting on this render-time receipt prevents a transient flat
    -- 2D fallback from masquerading as Voxel evidence.
    if render=="voxel" then
      local mapId=game.overworld.map.id
      local ready=false
      for _=1,1800 do
        local receipt=voxelReceipt
        if receipt and receipt.mapId==mapId then ready=true;break end
        U.wait(1)
      end
      assert(ready,"DRAMALESS world canvas was not presented: "..mapId)
      assert(voxelReceipt.pipeline=="voxel"
          and voxelReceipt.canvas and voxelReceipt.postWorldPresent,
        "GREEN capture saw a flat/fallback frame instead of DRAMALESS: "..mapId)
      if green and green.layouts[mapId] then
        assert(green.layouts[mapId].voxelMode=="FULL",
          "GREEN Voxel capture is not terrain-derived FULL: "..mapId)
        ready=false
        for _=1,1800 do
          local receipt=green._voxelFogEvidence
          if receipt and receipt.mapId==mapId then
            assert(receipt.projection=="DRAMALESS_UPRIGHT_MIDPOINT"
                and receipt.upright and receipt.upright.wy>receipt.upright.ground,
              "DRAMALESS GREEN fog missed the visible upright midpoint")
            ready=true;break
          end
          U.wait(1)
        end
        assert(ready,"DRAMALESS GREEN fog canvas was not presented: "..mapId)
      end
    end
    local mapId=game.overworld.map.id
    local isGreen=green and green.layouts[mapId]~=nil
    local fogReceipt
    if isGreen then
      fogReceipt=render=="voxel" and green._voxelFogEvidence
        or green._twoDFogEvidence
      assert(fogReceipt and fogReceipt.mapId==mapId and fogReceipt.postComposite,
        "GREEN final fog receipt missing before capture: "..mapId)
      assert(fogReceipt.edgePixels and fogReceipt.edgePixels<=2,
        "GREEN visibility boundary exceeds two screen pixels")
    end
    if render=="voxel" then
      if isGreen then
        assert(fogReceipt.projection=="DRAMALESS_UPRIGHT_MIDPOINT"
            and fogReceipt.upright
            and fogReceipt.upright.wy>fogReceipt.upright.ground,
          "GREEN final fog receipt lost the visible upright midpoint")
      end
      -- A line for every image, including Route 3, the shared tunnel and the
      -- sealed antechamber.  Resetting voxelReceipt at shot() entry means
      -- this can only describe a worldPresent generated after the current
      -- viewpoint settled; a transient 2D fallback cannot borrow an older
      -- receipt.  GREEN rows additionally prove terrain-derived FULL and the
      -- final post-sprite fog projection before the asynchronous PNG request.
    end
    local path=root.."/"..render.."/"..name..".png"
    assert(U.shot(game,path),"capture failed: "..name)
    local opaqueSamples=isGreen and opaqueExteriorPixels(path,fogReceipt) or 0
    if render=="voxel" then
      log("shot-receipt",name,mapId,
        "worldPresent","DRAMALESS","pipeline",voxelReceipt.pipeline,
        "canvas",voxelReceipt.canvas and "present" or "missing",
        "voxelMode",isGreen and green.layouts[mapId].voxelMode or "GENERAL",
        "fogPostComposite",isGreen and tostring(fogReceipt.postComposite) or "n/a",
        "fogProjection",isGreen and tostring(fogReceipt.projection) or "n/a",
        "edgePixels",isGreen and tostring(fogReceipt.edgePixels) or "n/a",
        "fogOuterOpaque",isGreen and tostring(fogReceipt.outerOpaque) or "n/a",
        "fogOuterSamples",isGreen and tostring(opaqueSamples) or "n/a")
    elseif isGreen then
      log("fog-pixel-receipt",name,mapId,"postComposite",true,
        "edgePixels",fogReceipt.edgePixels,"outerOpaque",true,
        "outerSamples",opaqueSamples)
    end
  end

  local dirs={
    {1,0,"right"},{-1,0,"left"},{0,1,"down"},{0,-1,"up"},
  }
  local byDir={};for _,d in ipairs(dirs)do byDir[d[3]]=d end
  local opposite={right="left",left="right",down="up",up="down"}
  local function blocked(x,y)
    for _,npc in ipairs(game.overworld.npcs or {}) do
      -- The real party follower is deliberately passable and trails the
      -- player after every committed step.  Treating its current cell as a
      -- permanent graph wall falsely seals one-cell alcoves after dialogue.
      -- Authored statues/items remain non-passable and therefore stay in the
      -- planner's collision graph exactly as they are in live movement.
      if npc.cellX==x and npc.cellY==y and npc.passable~=true then return true end
    end
    return false
  end
  local function state()
    local ow=assert(game.overworld);local p=assert(ow.player)
    return {map=ow.map.id,x=p.cellX,y=p.cellY,facing=p.facing}
  end
  local function stateKey(s)
    return table.concat({s.map,s.x,s.y,s.facing},":")
  end
  local function warpAt(map,x,y)
    for _,warp in ipairs(map.def.warps or {}) do
      if warp.x==x and warp.y==y then return warp end
    end
  end
  local function simulate(s,dir,allowWarp)
    if s.map~=game.overworld.map.id then return nil end
    if s.facing~=dir then return {map=s.map,x=s.x,y=s.y,facing=dir} end
    local d=byDir[dir];local x,y=s.x+d[1],s.y+d[2]
    local map=game.overworld.map
    if not map:inBounds(x,y) or not map:isWalkableCell(x,y) or blocked(x,y) then
      return nil
    end
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
        local nextState=simulate(here,d[3],false)
        local key=nextState and stateKey(nextState)
        if key and prev[key]==nil then
          prev[key]={from=stateKey(here),dir=d[3],want=nextState}
          queue[#queue+1]=nextState
        end
      end
    end
    assert(finish,("no physical GREEN route to %d,%d on %s"):format(
      x,y,start.map))
    local out={}
    while finish~=first do
      local row=assert(prev[finish]);table.insert(out,1,row);finish=row.from
    end
    return out
  end
  local function execute(plan,label)
    for index,row in ipairs(plan) do
      local before=state();U.tap(game,row.dir);settle();local after=state()
      log(label,index,row.dir,before.map,before.x,before.y,"=>",
        after.map,after.x,after.y)
      assert(after.map==row.want.map and after.x==row.want.x
          and after.y==row.want.y and after.facing==row.want.facing,
        "GREEN planner/product divergence")
    end
  end
  local function go(x,y) execute(planTo(x,y),"walk") end
  local function npc(name)
    for _,candidate in ipairs(game.overworld.npcs or {}) do
      if candidate.def and candidate.def.name==name then return candidate end
    end
    error("live GREEN object missing: "..name.." on "..game.overworld.map.id)
  end
  local function approach(name)
    local object=npc(name);local choice
    for _,d in ipairs(dirs) do
      local x,y=object.cellX+d[1],object.cellY+d[2]
      if game.overworld.map:inBounds(x,y)
          and game.overworld.map:isWalkableCell(x,y) and not blocked(x,y) then
        local ok,plan=pcall(planTo,x,y)
        if ok then choice={plan=plan,face=opposite[d[3]]};break end
      end
    end
    assert(choice,"no physical approach for "..name)
    execute(choice.plan,"object:"..name)
    -- A solid NPC harmlessly absorbs a redundant facing tap, but GREEN's
    -- root/canopy/shortcut roles are intentionally transparent passable
    -- anchors.  If the final path step already faces such an anchor, another
    -- D-pad press walks onto it and the following A targets one cell beyond.
    -- Turn only when needed and prove the one-cell approach was preserved.
    local before=state()
    if before.facing~=choice.face then U.tap(game,choice.face);settle() end
    local after=state()
    assert(after.x==before.x and after.y==before.y and after.facing==choice.face,
      "GREEN object approach moved through its interaction anchor: "..name)
  end
  local function interact(name)
    approach(name);U.tap(game,"a");U.wait(8);log("interact",name)
  end
  local function interactAndDismiss(name)
    interact(name);dismiss();assert(waitOverworld(),name.." did not return control")
  end
  local function physicalWarp(index,expected)
    local map=game.overworld.map
    local warp=assert(map.def.warps[index],"missing warp "..index)
    local pad
    for _,d in ipairs(dirs) do
      local x,y=warp.x+d[1],warp.y+d[2]
      if map:inBounds(x,y) and map:isWalkableCell(x,y) and not blocked(x,y) then
        local ok,plan=pcall(planTo,x,y)
        if ok then pad={plan=plan,dir=opposite[d[3]]};break end
      end
    end
    assert(pad,"no physical approach for warp "..index.." on "..map.id)
    execute(pad.plan,"warp-approach:"..index)
    for press=1,2 do
      local before=state();U.tap(game,pad.dir);settle();local after=state()
      log("native-warp",index,press,pad.dir,before.map,before.x,before.y,
        "=>",after.map,after.x,after.y)
      if after.map~=before.map then break end
    end
    U.wait(30)
    assert(game.overworld.map.id==expected,
      ("warp %s reached %s, expected %s"):format(
        index,game.overworld.map.id,expected))
  end

  local function answerBox()
    for _=1,360 do
      local top=game.stack:top()
      if type(top)=="table" and type(top.labels)=="table"
          and type(top.onChoose)=="function" and top.index then return top end
      U.tap(game,"a");U.wait(3)
    end
    error("GREEN answer box did not appear")
  end
  local function correctIndex(question,box)
    if question.kind=="number" then
      local answer=string.format("%03d",question.answer)
      for index,label in ipairs(box.labels or {}) do
        if tostring(label):find(answer,1,true) then return index end
      end
      error(("GREEN answer %s is absent from the visible choices %s / %s")
        :format(answer,tostring(box.labels and box.labels[1]),
          tostring(box.labels and box.labels[2])))
    end
    return question.answer and 1 or 2
  end
  local function assertSingleStatueContact(name,statue)
    local ow=assert(game.overworld);local player=assert(ow.player)
    local target=npc(name)
    local targetDistance=math.sqrt((target.cellX-player.cellX)^2
      +(target.cellY-player.cellY)^2)
    assert(targetDistance==1,
      name.." was not reached from its one-cell interaction approach")
    local atmospheres=game.data and game.data.field
      and game.data.field.mapAtmospheres
    local profile=atmospheres and atmospheres[ow.map.id]
    assert(profile and profile.effect=="fog",
      "GREEN statue contact lacks its live fog profile")
    local radius=assert(tonumber(profile.visibility))
    for _,reveal in ipairs(profile.revealFlags or {}) do
      if game.save.flags and game.save.flags[reveal.flag] then
        radius=tonumber(reveal.radius) or radius
      end
    end
    local edgeCells=(green.FOG_EDGE_SCREEN_PIXELS or 2)/16
    local visible={}
    for _,candidate in ipairs(ow.npcs or {}) do
      local candidateName=candidate.def and candidate.def.name
      if candidateName and candidateName:find("KA_GREEN_STATUE_",1,true)==1 then
        local dx,dy=candidate.cellX-player.cellX,candidate.cellY-player.cellY
        if math.sqrt(dx*dx+dy*dy)<=radius+edgeCells then
          visible[#visible+1]=candidateName
        end
      end
    end
    assert(#visible==1 and visible[1]==name,
      ("GREEN statue %d contact exposes %d statue-like relics (%s)")
        :format(statue,#visible,table.concat(visible,",")))
    log("single-statue-contact",name,"sight",green.progress(game.save).sight,
      "radius",radius,"visible",visible[1])
  end
  local function answerStatue(name,statue,wantCorrect)
    local before=green.progress(game.save)
    local question=assert(green.questionFor(game.save,statue))
    approach(name);assertSingleStatueContact(name,statue)
    U.tap(game,"a");U.wait(8);log("interact",name)
    local box=answerBox();local wanted=correctIndex(question,box)
    if not wantCorrect then wanted=3-wanted end
    if box.index~=wanted then
      U.tap(game,wanted==1 and "up" or "down");U.wait(10)
    end
    -- Leave a clean fixed-step boundary between the last D-pad edge and A.
    -- Otherwise both queued edges can reach AnswerBox:update together; its
    -- directional branch correctly wins and the following dismiss-A would
    -- confirm the other row.  Default NO needs no artificial cursor detour.
    U.wait(10)
    assert(game.stack:top()==box and box.index==wanted,
      "GREEN D-pad could not select the visible answer")
    U.tap(game,"a");U.wait(8);dismiss()
    local after=green.progress(game.save)
    assert(after.questions==before.questions+1,"GREEN question was not consumed")
    assert(after.sight==before.sight+(wantCorrect and 1 or 0),
      ("GREEN sight result mismatch for %s (%s): wanted index %d, "..
        "labels %s / %s, sight %d => %d"):format(question.id,
        question.kind,wanted,tostring(box.labels[1]),tostring(box.labels[2]),
        before.sight,after.sight))
    if wantCorrect then
      assert(game.save.flags and game.save.flags["KA_HEVO_GREEN_SIGHT_"..statue],
        "GREEN fog reveal flag did not persist")
    end
    log("question",name,question.id,wantCorrect and "correct" or "wrong",
      "sight",after.sight)
    return question.id
  end
  local function reload(expected)
    assert(game:writeSave(),"native GREEN save write failed")
    local loaded,recovered=assert(SaveData.load())
    game:restoreSave(loaded,recovered)
    assert(waitOverworld(900),"native GREEN reload did not settle")
    assert(game.overworld.map.id==expected,"native GREEN reload map mismatch")
    Pipelines.setLevel("voxel",render=="voxel" and 1 or 0)
    Pipelines.syncOptions(game.save.options)
    log("native-save-reload",expected)
  end

  -- Native CONTINUE is the proof boundary. No teleport occurs in this driver.
  U.wait(5);U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,600 do
    if game.overworld and game.stack:top()==game.overworld then break end
    U.tap(game,"a");U.wait(3)
  end
  assert(game.overworld and game.stack:top()==game.overworld,
    "CONTINUE did not reach GREEN field")
  api=assert(game.mods.exports.kanto_ascendant)
  green=assert(api.hiddenEvolutionCampaign.modules.GREEN)
  assert(api.extendedCharacters.getPlayerCharacter()=="GREEN",
    "fixture is not GREEN")
  local variant=tostring(os.getenv("HEVO_QA_VARIANT") or "FRESH"):upper()
  assert(variant=="FRESH" or variant=="ALT","invalid GREEN HEVO_QA_VARIANT")
  if variant=="ALT" then
    local origin=assert(game.save.qaHevoAltOrigin,"GREEN ALT migration receipt missing")
    assert(origin.variant=="ALT" and origin.playerCharacter=="GREEN"
        and origin.sourceSha256==os.getenv("KA_SOURCE_SAVE_SHA256")
        and origin.packageGateReceiptSha256
          ==os.getenv("KA_PACKAGE_GATE_RECEIPT_SHA256"),
      "GREEN ALT migration receipt drifted")
    log("alt-origin",origin.kind,origin.sourceSha256,origin.renderer)
  end
  local liveCutUser=game.overworld:partyKnows("CUT")
  assert(game.save.inventory and game.save.inventory.CASCADEBADGE
      and liveCutUser==game.save.party[1]
      and liveCutUser.moves and liveCutUser.moves[1]
      and liveCutUser.moves[1].id=="CUT",
    "GREEN prerequisite does not use the live vanilla CUT/Cascade path")
  log("fieldmove-eligibility","CUT","vanilla-party",liveCutUser.species,
    "CASCADEBADGE")
  game.save.options=game.save.options or {}
  game.save.options.modOptions=game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant=
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners=false
  Pipelines.setLevel("voxel",render=="voxel" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  assert(render=="voxel" and Pipelines.worldPipeline()=="voxel"
      or render=="2d" and Pipelines.worldPipeline()~="voxel",
    "requested GREEN renderer is not live")
  if render=="voxel" then
    local present=Pipelines.worldPresent
    Pipelines.worldPresent=function(canvas,ctx)
      local out=present(canvas,ctx)
      local mapId=ctx and ctx.state and ctx.state.map and ctx.state.map.id
      if out and mapId then
        voxelReceipt={mapId=mapId,canvas=out,
          pipeline=Pipelines.worldPipeline(),postWorldPresent=true}
      end
      return out
    end
  end

  assert(game.overworld.map.id=="ROUTE_3","fixture did not start on Route 3")
  shot("00_route3_fissure")
  if render=="voxel" then
    local bridge=assert(api.dramalessWallDecalsCompat,
      "DRAMALESS wall-decal package bridge missing")
    assert(bridge.mode=="native" or bridge.mode=="adapter",
      "Voxel wall decals inactive: "..tostring(bridge.mode))
    if bridge.mode=="adapter" then
      local receipt=assert(bridge.lastDrawn,
        "GREEN Voxel fissure produced no depth-scene draw receipt")
      assert(bridge.drawCount>0 and receipt.id=="KA_HEVO_WALL_FISSURE_GREEN"
          and receipt.mapId=="ROUTE_3" and receipt.cellX==41
          and receipt.cellY==3 and bridge.lastError==nil,
        "GREEN Voxel fissure receipt has the wrong wall identity")
    end
    log("wall-decal-receipt","GREEN",bridge.mode,bridge.drawCount)
  end
  interact("KA_HEVO_FISSURE_GREEN")
  acceptFissure()
  assert(waitOverworld() and game.overworld.map.id=="KA_HEVO_TUNNEL_ALL",
    "Route 3 fissure did not reach GREEN's shared shaft")
  shot("01_shared_tunnel_green")
  physicalWarp(6,"KA_HEVO_GREEN_THRESHOLD")
  assert(green.progress(game.save).sight==0,"GREEN did not start fresh")
  shot("02_threshold_initial_fog")
  interactAndDismiss("KA_GREEN_LANDMARK_THRESHOLD")
  shot("03_threshold_landmark")
  physicalWarp(2,"KA_HEVO_GREEN_GROVE")
  shot("04_grove_pre_puzzle")
  interactAndDismiss("KA_GREEN_DECOY_GROVE_SPORE")
  interactAndDismiss("KA_GREEN_DECOY_GROVE_HUSK")
  interactAndDismiss("KA_GREEN_DECOY_GROVE_DEW")
  shot("04b_grove_three_decoy_trails")

  local wrong=answerStatue("KA_GREEN_STATUE_1",1,false)
  shot("05_grove_after_wrong_answer")
  local correct=answerStatue("KA_GREEN_STATUE_1",1,true)
  assert(wrong~=correct,"wrong GREEN answer repeated the same question")
  shot("06_grove_after_statue_1")

  -- Visit the deep mist early so its closed roots teach the two-light rule.
  physicalWarp(2,"KA_HEVO_GREEN_MIST")
  interactAndDismiss("KA_GREEN_INTERNAL_CUT")
  assert(not green.rootgateOpen(game.save),"one light opened the living roots")
  interactAndDismiss("KA_GREEN_DECOY_MIST_SPORE")
  shot("07_mist_root_locked_early")
  physicalWarp(1,"KA_HEVO_GREEN_GROVE")
  interactAndDismiss("KA_GREEN_MOON_POOL")
  shot("08_grove_moon_pool_landmark")
  answerStatue("KA_GREEN_STATUE_2",2,true)
  shot("09_grove_after_statue_2")

  physicalWarp(2,"KA_HEVO_GREEN_MIST")
  shot("10_mist_sight_2_entry")
  answerStatue("KA_GREEN_STATUE_3",3,true)
  shot("11_mist_after_statue_3")
  interactAndDismiss("KA_GREEN_INTERNAL_CUT")
  assert(green.rootgateOpen(game.save),"two lights did not open the living roots")
  shot("12_mist_root_gate_open")
  interactAndDismiss("KA_GREEN_DECOY_MIST_HUSK")
  interactAndDismiss("KA_GREEN_DECOY_MIST_DEW")
  shot("12b_mist_three_decoy_trails")

  interactAndDismiss("KA_GREEN_SECRET_HINT")
  shot("13_mist_secret_hint")
  interactAndDismiss("KA_GREEN_SCEPTILITE_SECRET")
  local persistent=assert(api.hevoPackages.persistent(game.save,false))
  assert(persistent.permanentItems.SCEPTILITE==true,
    "SCEPTILITE was not secured")
  shot("14_mist_sceptilite_claimed")
  reload("KA_HEVO_GREEN_MIST")
  persistent=assert(api.hevoPackages.persistent(game.save,false))
  assert(persistent.permanentItems.SCEPTILITE==true
      and green.rootgateOpen(game.save),
    "GREEN secret/root gate did not survive native reload")
  interactAndDismiss("KA_GREEN_SCEPTILITE_SECRET")
  shot("15_mist_secret_reentry_after_reload")

  interactAndDismiss("KA_GREEN_RESET_MIST")
  assert(game.overworld.map.id=="KA_HEVO_GREEN_MIST"
      and game.overworld.player.cellX==3 and game.overworld.player.cellY==35,
    "GREEN reset did not return to the safe current-floor entry")
  local resetProgress=green.progress(game.save)
  assert(resetProgress.sight==3 and resetProgress.rootgate
      and resetProgress.checkpoint=="KA_HEVO_GREEN_MIST",
    "GREEN reset lost checkpoint or puzzle progress")
  shot("16_mist_after_fair_reset")

  answerStatue("KA_GREEN_STATUE_4",4,true)
  shot("17_mist_after_statue_4")
  interactAndDismiss("KA_GREEN_CANOPY_GATE")
  assert(not green.canopyOpen(game.save),"four lights opened the canopy")
  shot("18_mist_canopy_locked")
  answerStatue("KA_GREEN_STATUE_5",5,true)
  shot("19_mist_after_statue_5_full_reveal")
  interactAndDismiss("KA_GREEN_CANOPY_GATE")
  assert(green.canopyOpen(game.save),"five lights did not open the canopy")
  shot("20_mist_canopy_open")

  physicalWarp(2,"KA_HEVO_GREEN_RAYQUAZA_SHRINE")
  shot("21_shrine_pre_reward")
  interactAndDismiss("KA_GREEN_RESEARCH_CACHE")
  local completed=green.progress(game.save)
  persistent=assert(api.hevoPackages.persistent(game.save,false))
  assert(completed.completed and persistent.meta.GREEN==true,
    "GREEN reward/finalization did not persist")
  shot("22_shrine_post_reward")
  interactAndDismiss("KA_GREEN_RAYQUAZA_SEAL")
  physicalWarp(2,"KA_HEVO_SHARED_SEALED_ANTECHAMBER")
  shot("23_shared_rayquaza_end")
  interactAndDismiss("KA_HEVO_SHARED_SEALED_DOOR")
  do
    local receipt=assert(api.hiddenEvolutionCampaign.modules.shared.handoff(),
      "GREEN final warp emitted no durable character receipt")
    assert(receipt.character=="GREEN" and receipt.seal==true
        and receipt.sourceMap=="KA_HEVO_GREEN_RAYQUAZA_SHRINE"
        and receipt.stone=="SCEPTILITE"
        and (receipt.stoneStatus=="granted" or receipt.stoneStatus=="claimed")
        and receipt.acknowledged==true,
      "GREEN final receipt lost shrine/stone/door authority")
    assert(api.megaEvolution.hasStone("SCEPTILITE"),
      "GREEN final chain did not put SCEPTILITE in the Stone Case")
    local bucket=assert(game.save.modData.kanto_ascendant)
    local gate=assert(bucket[api.legacyJourney.HEVO_GATE_KEY],
      "GREEN final chain created no Legacy Journey gate")
    assert(gate.character=="GREEN" and gate.ready==true
        and gate.doorAcknowledged==true and gate.oakCalled==true
        and gate.pendingCall~=true
        and game.save.flags[api.legacyJourney.HEVO_READY_FLAG]==true
        and game.save.flags[api.legacyJourney.HEVO_OAK_CALLED_FLAG]==true,
      "GREEN final chain did not complete the one-time Oak call")
    local canBegin,owner=api.legacyJourney.canBegin(game.save)
    assert(canBegin==true and owner=="GREEN",
      "GREEN sealed save did not unlock only GREEN's Legacy Journey")
    log("end-receipt","GREEN",receipt.sourceMap,receipt.stone,
      receipt.stoneStatus,"oak-called","legacy-ready")
  end

  physicalWarp(3,"KA_HEVO_GREEN_RAYQUAZA_SHRINE")
  physicalWarp(1,"KA_HEVO_GREEN_MIST")
  physicalWarp(1,"KA_HEVO_GREEN_GROVE")
  physicalWarp(1,"KA_HEVO_GREEN_THRESHOLD")
  physicalWarp(1,"KA_HEVO_TUNNEL_ALL")
  physicalWarp(3,"ROUTE_3")
  shot("24_route3_return")
  reload("ROUTE_3")
  persistent=assert(api.hevoPackages.persistent(game.save,false))
  assert(green.progress(game.save).completed
      and persistent.meta.GREEN and persistent.permanentItems.SCEPTILITE,
    "GREEN completion/secret did not survive final reload")

  interact("KA_HEVO_FISSURE_GREEN")
  acceptFissure()
  assert(waitOverworld() and game.overworld.map.id=="KA_HEVO_TUNNEL_ALL",
    "completed GREEN fissure re-entry failed")
  physicalWarp(6,"KA_HEVO_GREEN_THRESHOLD")
  shot("25_threshold_completed_reentry")
  interact("KA_GREEN_SHORTCUT");dismiss()
  assert(waitOverworld() and game.overworld.map.id=="KA_HEVO_GREEN_RAYQUAZA_SHRINE",
    "completed GREEN shortcut did not reach the shrine")
  shot("26_shrine_shortcut_reentry")

  local result=assert(io.open(root.."/driver_result.txt","wb"),
    "could not write GREEN full-path package receipt")
  result:write("status=PASS\n")
  result:write("scope=HEVO-FULL-PATH\n")
  result:write("character=GREEN\n")
  result:write("edition=",tostring(os.getenv("POKEPORT_VERSION")),"\n")
  result:write("renderer=",render,"\n")
  result:write("variant=",variant,"\n")
  result:write("stone=SCEPTILITE\n")
  result:write("native_save_reload=1/1\n")
  result:write("reentry=1/1\n")
  result:write("fail=0\n")
  result:close()
  U.log("HEVO GREEN PACKAGE END RECEIPT",variant,"SCEPTILITE",
    "oak-called","legacy-ready","native-reload","reentry")
  U.log("HEVO GREEN INPUT PASS",render,
    "Route3/tunnel/four floors/fog/questions/gates/reset/secret/reward/return/re-entry")
  trace:close();love.event.quit(0)
end
