-- Short renderer gate for GREEN's authored cell geometry and staged fog.
-- This is deliberately not the campaign acceptance run: it stages isolated
-- visual viewpoints, then the separate input_e2e driver proves navigation.
return function(game)
  local U=dofile("tests/drivers/util.lua")
  local Game=require("src.core.Game")
  local Pipelines=require("src.render.Pipelines")
  local root=assert(os.getenv("SHOT_DIR"),"SHOT_DIR required")
  local render=os.getenv("GREEN_QA_RENDER")=="voxel" and "voxel" or "2d"
  local phase=os.getenv("GREEN_QA_PHASE") or "after"
  local s5Only=os.getenv("GREEN_QA_S5_ONLY")=="1"
  local opaqueOnly=os.getenv("GREEN_QA_OPAQUE_ONLY")=="1"
  assert(phase=="before" or phase:match("^after[_%w-]*$"),
    "GREEN_QA_PHASE must be before or an after identity")
  U.wait(5);U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,600 do
    if game.overworld and game.stack:top()==game.overworld then break end
    U.tap(game,"a");U.wait(3)
  end
  assert(game.overworld and game.stack:top()==game.overworld,
    "GREEN visual CONTINUE did not reach the field")
  local api=assert(game.mods.exports.kanto_ascendant)
  local green=assert(api.hiddenEvolutionCampaign.modules.GREEN)
  assert(api.extendedCharacters.getPlayerCharacter()=="GREEN",
    "GREEN visual gate needs the isolated GREEN save")

  game.save.options=game.save.options or {}
  game.save.options.modOptions=game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant=
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners=false
  Pipelines.setLevel("voxel",render=="voxel" and 1 or 0)
  Pipelines.syncOptions(game.save.options)

  local function settle()
    U.wait(render=="voxel" and 180 or 45)
    for _=1,8 do
      if game.stack:top()==game.overworld then break end
      U.tap(game,"b");U.wait(8)
    end
    assert(game.stack:top()==game.overworld,"GREEN visual overlay did not settle")
    if render=="voxel" then
      local ready=false
      for _=1,1800 do
        local evidence=green._voxelFogEvidence
        if evidence and evidence.mapId==game.overworld.map.id then
          assert(evidence.projection=="DRAMALESS_UPRIGHT_MIDPOINT"
              and evidence.upright and evidence.upright.wy>evidence.upright.ground,
            "GREEN fog did not use the visible DRAMALESS upright midpoint")
          ready=true;break
        end
        U.wait(1)
      end
      assert(ready,"DRAMALESS did not produce a worldOverride for GREEN")
    end
    U.wait(24)
  end
  local function opaqueExteriorPixels(path,evidence)
    assert(evidence.shaderActive,
      "GREEN opaque exterior requires the live post-composite shader")
    assert(evidence.outerOpaque and evidence.outerAlpha==1,
      "GREEN exterior receipt is not fully opaque")
    assert(type(evidence.outerColor)=="table"
        and type(evidence.outerSamples)=="table"
        and #evidence.outerSamples>=8,
      "GREEN exterior receipt lacks independent sample points")
    assert(love.image and love.image.newImageData and love.filesystem
        and love.filesystem.newFileData,
      "GREEN pixel gate needs PNG ImageData decoding")
    local file=assert(io.open(path,"rb"));local bytes=file:read("*a");file:close()
    local image=assert(love.image.newImageData(
      love.filesystem.newFileData(bytes,"green_opaque_sample.png")))
    local width,height=image:getWidth(),image:getHeight()
    local frameWidth=assert(evidence.frameWidth)
    local frameHeight=assert(evidence.frameHeight)
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
    return #evidence.outerSamples,
      ("%d,%d,%d"):format(expected[1]*255,expected[2]*255,expected[3]*255)
  end
  local function capture(name,evidence)
    local path=root.."/"..phase.."/"..render.."/"..name..".png"
    assert(U.shot(game,path),"GREEN visual capture failed: "..name)
    local count,rgb=opaqueExteriorPixels(path,evidence)
    U.log("HEVO GREEN OPAQUE PIXEL PASS",name,render,
      "samples="..count,"rgb="..rgb,"alpha=255")
  end
  local function stage(mapId,x,y,name,facing)
    if render=="voxel" then
      Game.renderer:setWorldOverride(nil);green._voxelFogEvidence=nil
    end
    U.teleport(game,mapId,x,y,facing or "down")
    assert(game.overworld and game.overworld.map.id==mapId,
      "GREEN visual teleport failed: "..mapId)
    settle()
    assert(render=="voxel" and Pipelines.worldPipeline()=="voxel"
        or render=="2d" and Pipelines.worldPipeline()~="voxel",
      "GREEN visual renderer is not live")
    if render=="voxel" then
      assert(green.layouts[mapId] and green.layouts[mapId].voxelMode=="FULL",
        "GREEN targeted Voxel capture is not terrain-derived FULL")
    end
    local evidence=render=="voxel" and green._voxelFogEvidence
      or green._twoDFogEvidence
    assert(evidence and evidence.mapId==mapId and evidence.postComposite,
      "GREEN final post-composite fog evidence is missing")
    assert(evidence.edgePixels and evidence.edgePixels<=2,
      "GREEN visibility boundary exceeds two true screen pixels")
    U.log("HEVO GREEN FOG RECEIPT",name,render,evidence.mapId,
      "sight="..tostring(evidence.sight),
      "voxelMode="..(render=="voxel" and green.layouts[mapId].voxelMode
        or "n/a"),
      "edgePixels="..tostring(evidence.edgePixels),
      "postComposite="..tostring(evidence.postComposite),
      "projection="..tostring(evidence.projection))
    capture(name,evidence)
  end
  local function motionShot(name)
    U.wait(210)
    local evidence=render=="voxel" and green._voxelFogEvidence
      or green._twoDFogEvidence
    assert(evidence,"GREEN moving-fog receipt is missing")
    capture(name,evidence)
  end
  local function reachSight(target)
    while green.progress(game.save).sight<target do
      local statue=green.progress(game.save).sight+1
      local question=assert(green.questionFor(game.save,statue))
      assert(green.answer(game.save,statue,question.answer))
    end
  end

  if opaqueOnly then
    stage(green.IDS.grove,20,35,
      "00_grove_sight_0_opaque_exterior","right")
    reachSight(3)
    stage(green.IDS.mist,44,21,
      "01_mist_sight_3_opaque_exterior","right")
    reachSight(5)
    stage(green.IDS.shrine,37,21,
      "02_shrine_sight_5_opaque_exterior","up")
    U.log("HEVO GREEN OPAQUE VISUAL GATE PASS",render,
      "sight0/3/5 exact exterior pixels")
    love.event.quit(0)
    return
  end

  if s5Only then
    reachSight(2);assert(green.openRootgate(game.save,game.overworld))
    reachSight(3)
    stage(green.IDS.mist,21,23,
      "00_mist_root_gate_open_statue_5_hidden","right")
    reachSight(4)
    stage(green.IDS.mist,29,21,
      "01_mist_statue_5_remote_fork_hidden","down")
    stage(green.IDS.mist,37,35,
      "02_contact_statue_5_two_cells","right")
    stage(green.IDS.mist,38,35,
      "03_contact_statue_5_only_relic","right")
    U.log("HEVO GREEN S5 VISUAL GATE PASS",render,
      "root/fork/two-cell/direct + post-composite receipts")
    love.event.quit(0)
    return
  end

  stage(green.IDS.threshold,27,17,"00_threshold_sight_0_one_cell")
  stage(green.IDS.grove,23,23,"01_grove_sight_0_pool_loop")
  -- Statue 1 is eight cells down its own branch at (21,35).  The final two
  -- west approach cells provide an honest one-cell/two-cell comparison
  -- without moving or highlighting the solver.
  stage(green.IDS.grove,20,35,
    "01c_grove_sight_0_direct_statue_dim_silhouette","right")
  stage(green.IDS.grove,19,35,
    "01d_grove_sight_0_two_cells_statue_hidden","right")
  stage(green.IDS.grove,13,35,
    "01e_grove_sight_0_statue_branch_fork_hidden","right")
  stage(green.IDS.mist,29,21,"02_mist_sight_0_root_loop")
  -- The decoy occupies (19,33); capture it from the adjacent open trail so
  -- player and item sprites cannot overlap and fake a marker/halo verdict.
  stage(green.IDS.mist,18,33,
    "02c_mist_sight_0_player_decoy_no_halo","right")
  motionShot("02b_mist_sight_0_wisps_moved")
  reachSight(1)
  stage(green.IDS.grove,19,35,
    "02d_grove_sight_1_two_cells_moderate_reveal","right")
  stage(green.IDS.grove,54,17,
    "02e_contact_statue_2_sight_1_only_relic","right")
  stage(green.IDS.grove,53,17,
    "02f_contact_statue_2_sight_1_two_cells","right")
  reachSight(2);assert(green.openRootgate(game.save,game.overworld))
  stage(green.IDS.mist,6,25,
    "03a_contact_statue_3_sight_2_only_relic","left")
  stage(green.IDS.mist,7,25,
    "03a2_contact_statue_3_sight_2_two_cells","left")
  stage(green.IDS.mist,29,21,"03_mist_sight_2_root_loop")
  reachSight(3)
  -- Exact regression viewpoint from the navigated release run: the living-
  -- root interaction is at (22,23), while the player stands at (21,23).
  -- Statue 5 must not leak through any wall into this sight-3 aperture.
  stage(green.IDS.mist,21,23,
    "03aa_mist_root_gate_open_statue_5_hidden","right")
  stage(green.IDS.mist,44,21,
    "03b_contact_statue_4_sight_3_only_relic","right")
  stage(green.IDS.mist,43,21,
    "03b2_contact_statue_4_sight_3_two_cells","right")
  reachSight(4)
  stage(green.IDS.mist,29,21,
    "04_mist_statue_5_remote_fork_hidden","down")
  stage(green.IDS.mist,38,35,
    "04a_contact_statue_5_sight_4_only_relic","right")
  stage(green.IDS.mist,37,35,
    "04b_contact_statue_5_sight_4_two_cells","right")
  reachSight(5);assert(green.openCanopy(game.save))
  stage(green.IDS.mist,47,13,"05_mist_after_statue_5_long_exit_tail")
  stage(green.IDS.shrine,37,21,"06_shrine_sight_5_cell_maze")
  U.log("HEVO GREEN VISUAL GATE PASS",render,
    "one-cell geometry + staged moving fog")
  love.event.quit(0)
end
