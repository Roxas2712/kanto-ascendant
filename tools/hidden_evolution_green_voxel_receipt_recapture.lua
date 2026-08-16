-- Renderer-only supplement for the four non-GREEN frames in the completed
-- physical D-pad run.  Navigation provenance remains input_voxel.tsv; these
-- staged viewpoints replace transient warm-up fallbacks only after a real
-- DRAMALESS worldPresent receipt for the requested map.
return function(game)
  local U=dofile("tests/drivers/util.lua")
  local Game=require("src.core.Game")
  local Pipelines=require("src.render.Pipelines")
  local root=assert(os.getenv("SHOT_DIR"),"SHOT_DIR required")
  U.wait(5);U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,600 do
    if game.overworld and game.stack:top()==game.overworld then break end
    U.tap(game,"a");U.wait(3)
  end
  assert(game.overworld and game.stack:top()==game.overworld)
  local api=assert(game.mods.exports.kanto_ascendant)
  local green=assert(api.hiddenEvolutionCampaign.modules.GREEN)
  game.save.options=game.save.options or {}
  game.save.options.modOptions=game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant=
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners=false
  Pipelines.setLevel("voxel",1);Pipelines.syncOptions(game.save.options)
  assert(Pipelines.worldPipeline()=="voxel","DRAMALESS pipeline is not live")

  local receipt
  local present=Pipelines.worldPresent
  Pipelines.worldPresent=function(canvas,ctx)
    local out=present(canvas,ctx)
    local mapId=ctx and ctx.state and ctx.state.map and ctx.state.map.id
    if out and mapId then receipt={mapId=mapId,canvas=out} end
    return out
  end
  local function capture(mapId,x,y,facing,name,keepStart)
    receipt=nil;Game.renderer:setWorldOverride(nil)
    if green.layouts[mapId] then green._voxelFogEvidence=nil end
    if not keepStart then U.teleport(game,mapId,x,y,facing) end
    assert(game.overworld and game.overworld.map.id==mapId,
      "staged receipt map mismatch: "..mapId)
    local ready=false
    for _=1,1800 do
      if receipt and receipt.mapId==mapId then ready=true;break end
      U.wait(1)
    end
    assert(ready,"no DRAMALESS worldPresent receipt for "..mapId)
    if green.layouts[mapId] then
      ready=false
      for _=1,1800 do
        local fogReceipt=green._voxelFogEvidence
        if fogReceipt and fogReceipt.mapId==mapId then ready=true;break end
        U.wait(1)
      end
      assert(ready,"no DRAMALESS GREEN fog receipt for "..mapId)
    end
    U.wait(24)
    assert(U.shot(game,root.."/voxel/"..name..".png"),
      "receipt capture failed: "..name)
  end

  if os.getenv("GREEN_RECEIPT_COMPLETED")=="1" then
    assert(green.progress(game.save).completed,
      "completed receipt fixture has not finished GREEN")
    capture(green.IDS.threshold,3,37,"up","25_threshold_completed_reentry")
    capture(green.IDS.shrine,3,35,"up","26_shrine_shortcut_reentry")
    U.log("HEVO GREEN COMPLETED VOXEL RECEIPT RECAPTURE PASS",
      "completed threshold/shrine 25/26 are genuine DRAMALESS fog frames")
  else
    assert(game.overworld.map.id=="ROUTE_3","fresh receipt fixture is not Route 3")
    capture("ROUTE_3",41,4,"up","00_route3_fissure",true)
    capture("KA_HEVO_TUNNEL_ALL",26,21,"up","01_shared_tunnel_green")
    capture("KA_HEVO_SHARED_SEALED_ANTECHAMBER",27,21,"up",
      "23_shared_rayquaza_end")
    capture("ROUTE_3",41,4,"down","24_route3_return")
    U.log("HEVO GREEN VOXEL RECEIPT RECAPTURE PASS",
      "Route3/shared 00/01/23/24 are genuine DRAMALESS frames")
  end
  love.event.quit(0)
end
