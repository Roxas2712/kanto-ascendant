-- Focused runtime proof for the transient Wilds spawn-FX/Voxel lifecycle.
-- One forced Route-22 spawn starts logical-only/DEFERRED, becomes a native
-- DRAMALESS billboard through ordinary ticks, and is captured only after a
-- fresh same-map worldPresent receipt.
return function(game)
  local U=dofile("tests/drivers/util.lua")
  local Pipelines=require("src.render.Pipelines")
  local root=assert(os.getenv("SHOT_DIR"),"SHOT_DIR required")
  local trace=assert(io.open(assert(os.getenv("INPUT_TRACE"),"INPUT_TRACE required"),"w"))
  local function log(...)
    local row={"WILDS VOXEL SPAWNFX"}
    for i=1,select("#",...) do row[#row+1]=tostring(select(i,...)) end
    trace:write(table.concat(row,"\t"),"\n");trace:flush()
  end

  U.wait(5);U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,600 do
    if game.overworld and game.stack:top()==game.overworld then break end
    U.tap(game,"a");U.wait(3)
  end
  assert(game.overworld and game.stack:top()==game.overworld,
    "CONTINUE did not reach Route 22")
  local exports=assert(game.mods and game.mods.exports)
  assert(exports.DRAMALESS_SHAPE,"DRAMALESS Shape required")
  local wilds=assert(exports.overworld_wild_spawns,"bundled Wilds missing")
  assert(wilds.version=="1.12.2","Wilds 1.12.2 required")
  local logic=assert(wilds.logic);local voxel=assert(logic.voxel)
  local Behavior=assert(wilds.lib.require("behavior"))

  game.save.options=game.save.options or {}
  game.save.options.modOptions=game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant=
    game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners=false
  Pipelines.setLevel("voxel",1);Pipelines.syncOptions(game.save.options)
  U.wait(60)
  assert(Pipelines.worldPipeline()=="voxel" and voxel:isVoxelCameraActive(),
    "real DRAMALESS Voxel pipeline is not active")

  local receipt,serial=nil,0
  local present=Pipelines.worldPresent
  Pipelines.worldPresent=function(canvas,ctx)
    local out=present(canvas,ctx)
    local mapId=ctx and ctx.state and ctx.state.map and ctx.state.map.id
    if out and mapId then
      serial=serial+1;receipt={serial=serial,mapId=mapId,canvas=out}
    end
    return out
  end

  U.teleport(game,"ROUTE_22",8,8,"right");U.wait(15);U.tap(game,"b");U.wait(5)
  if logic._clearMap then logic:_clearMap("ROUTE_22") else logic:clearAll() end
  -- Ordinary refill remains disabled for this bounded proof; force=true below
  -- still exercises the real creation, SpawnFx, attach and behavior paths.
  logic.targetSpawnCount=0

  local record,err,entity
  for _,point in ipairs({{10,8},{8,10},{10,10},{6,8},{8,6}}) do
    record,err,entity=logic:trySpawn(game,{
      force=true,x=point[1],y=point[2],species="RATTATA",level=7,
      behavior=Behavior.IDLE_LOOK,
    })
    if record then break end
  end
  assert(record and entity,"fresh Route-22 spawn failed: "..tostring(err))
  assert(entity.spawnFx and entity.spawnFx.done~=true
      and entity.hiddenBody==true and entity.registeredInWorld~=true,
    "fresh spawn skipped its logical-only hidden-body phase")

  local updated=voxel:updateEntity(entity)
  assert(updated==false and entity.voxelDeferred==true,
    "hidden spawn body was not deferred")
  assert(entity.pokemonRenderer=="VOXEL_BODY_DEFERRED"
      and entity.worldSpriteAdapterStatus=="DEFERRED",
    "deferred spawn entered the wrong renderer state")
  assert(entity.voxelDisabled~=true and entity.render2DFallback~=true
      and entity.voxelLastError==nil,
    "deferred spawn entered an emergency/fallback state")
  log("deferred",record.id,record.species,entity.worldRegistration,
    entity.pokemonRenderer,entity.worldSpriteAdapterStatus,
    "registered",entity.registeredInWorld==true)

  local visible=false
  for _=1,600 do
    U.wait(1)
    if entity.spawnFx and entity.spawnFx.bodyShown==true
        and entity.hiddenBody~=true and entity.registeredInWorld==true
        and entity.voxelRegistered==true then visible=true;break end
  end
  assert(visible,"spawn never promoted from logical-only to visible Voxel")
  assert(entity.pokemonRenderer=="NATIVE_SPRITE_RENDERER"
      and entity.worldSpriteAdapterStatus=="NATIVE"
      and entity.worldBillboardReady==true,
    "visible spawn did not promote to a native billboard")
  assert(entity.voxelDeferred~=true and entity.voxelDisabled~=true
      and entity.render2DFallback~=true and entity.voxelLastError==nil,
    "visible spawn retained deferred/emergency flags")
  local poseOk,pose=voxel.probePose(entity)
  assert(poseOk and pose and pose.sprite==entity:getWorldSprite(),
    "visible spawn lacks a real native pose")
  local found=false
  for _,candidate in ipairs(game.overworld.entities or {}) do
    if candidate==entity then found=true;break end
  end
  assert(found,"visible spawn is absent from the live world entity list")

  local before=receipt and receipt.serial or 0
  for _=1,600 do
    U.wait(1)
    if receipt and receipt.serial>before and receipt.mapId=="ROUTE_22" then break end
  end
  assert(receipt and receipt.serial>before and receipt.mapId=="ROUTE_22",
    "no fresh Route-22 DRAMALESS worldPresent receipt")
  local w,h=receipt.canvas:getDimensions()
  assert(w>0 and h>0,"DRAMALESS returned an empty canvas")
  assert(U.shot(game,root.."/route22_spawnfx_native_voxel.png"),"screenshot failed")
  log("native",record.id,record.species,entity.pokemonRenderer,
    entity.worldSpriteAdapterStatus,"pose",poseOk,"receipt",receipt.serial,
    "canvas",w,h,"cell",entity.cellX,entity.cellY)
  trace:close()
  U.log("WILDS VOXEL SPAWNFX PASS: DEFERRED -> NATIVE billboard")
  love.event.quit(0)
end
