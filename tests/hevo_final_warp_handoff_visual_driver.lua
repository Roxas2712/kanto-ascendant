-- Bounded real-LÖVE proof for the coloured final stair transaction.
-- Puzzle completion uses each path's public product API; the final stair,
-- shared tablet, cry/blackout, Oak call and retry are ordinary player input.
return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local SaveData = require("src.core.SaveData")
  local Runtime = require("src.mods.Runtime")
  local Pipelines = require("src.render.Pipelines")
  local GBCFX = require("src.render.GBCFX")
  local TextBox = require("src.render.TextBox")
  local character = assert(os.getenv("HEVO_HANDOFF_CHARACTER")):upper()
  local renderer = os.getenv("HEVO_HANDOFF_RENDERER") or "2d"
  local outDir = assert(os.getenv("SHOT_DIR"))
  assert(({RED=true,BLUE=true,GREEN=true})[character])
  assert(renderer=="2d" or renderer=="voxel")
  assert(tostring(os.getenv("POKEPORT_IDENTITY")):find(
    "hevo%-handoff%-"..character:lower().."%-"..renderer))

  local exports=assert(game.mods.exports.kanto_ascendant)
  local campaign=assert(exports.hiddenEvolutionCampaign)
  local modules=assert(campaign.modules or campaign.load())
  local path=assert(modules[character])
  local shared=assert(modules.shared)
  local journey=assert(exports.legacyJourney)
  local adapter=assert(exports.legacyDungeonAdapter)
  local mega=assert(exports.megaEvolution)
  local characters=assert(exports.extendedCharacters)
  local checks, rows=0,{}
  local voxelReceipt,voxelSerial=nil,0
  local function check(label,value)
    if not value then error("FAIL: "..label,2) end
    checks=checks+1; rows[#rows+1]="PASS\t"..label; U.log("PASS",label)
    return value
  end
  local function waitFor(fn,limit)
    for _=1,limit or 1600 do local v=fn();if v then return v end;U.wait(1) end
  end
  local function textOf(box)
    local out={}
    for _,page in ipairs(box and box.pages or {}) do
      for _,line in ipairs(page) do out[#out+1]=line end
    end
    return table.concat(out," ")
  end
  local function waitText(needle)
    return waitFor(function()
      local top=game.stack:top()
      return getmetatable(top)==TextBox and textOf(top):find(needle,1,true)
        and top or nil
    end,1800)
  end
  local function drainText(box)
    for _=1,2000 do
      if game.stack:top()~=box then return true end
      U.tap(game,"a");U.wait(2)
    end
  end
  local function shot(name,worldShot)
    local before=voxelReceipt and voxelReceipt.serial or 0
    if renderer=="voxel" and worldShot~=false then
      check("FULL pipeline live for "..name,Pipelines.worldPipeline()=="voxel")
      check("fresh Voxel frame for "..name,waitFor(function()
        return voxelReceipt and voxelReceipt.serial>before
          and voxelReceipt.mapId==game.overworld.map.id
          and voxelReceipt.canvas
      end,1800))
      local w,h=voxelReceipt.canvas:getDimensions()
      check("nonempty Voxel canvas for "..name,w>0 and h>0)
    end
    check("capture "..name,U.shot(game,outDir.."/"..name..".png"))
  end
  local function clearFieldOverlay()
    for _=1,600 do
      if game.stack:top()==game.overworld then return true end
      U.tap(game,"b");U.wait(2)
    end
  end

  local slot="slothevohandoff"..character:lower()..renderer
  check("isolated slot selected",SaveData.setActiveSlot("red",slot)==slot)
  local save=SaveData.newGame(game:bootConfig())
  save.player.name=character
  save.flags=save.flags or {}
  save.flags.EVENT_BEAT_CHAMPION_RIVAL=true
  save.options=save.options or {};save.options.textSpeed=1;save.options.gbcfx=0
  game.save=save;game:adoptSave(save);Runtime.emit("save.created",{save=save})
  characters.select(character)
  GBCFX.setLevel(0)
  local level=Pipelines.setLevel("voxel",renderer=="voxel" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  check("renderer selected",renderer=="voxel" and level>0 or level==0)
  if renderer=="voxel" then
    local present=Pipelines.worldPresent
    Pipelines.worldPresent=function(canvas,ctx)
      local out=present(canvas,ctx)
      local mapId=ctx and ctx.state and ctx.state.map and ctx.state.map.id
      if out and mapId then
        voxelSerial=voxelSerial+1
        voxelReceipt={serial=voxelSerial,mapId=mapId,canvas=out}
      end
      return out
    end
  end
  check("active character exact",journey.activeCharacter(game.save)==character
    and characters.getPlayerCharacter()==character)
  check("post-League source eligible",journey.archive.isEligible(game.save))
  mega.unlock(game)
  local stone=({RED="BLAZIKENITE",BLUE="SWAMPERTITE",GREEN="SCEPTILITE"})[character]
  local shrine=campaign.CONTRACT.ends[character]
  local endCell=path.END_WARP or campaign.END_WARPS[character]
  if character=="RED" then
    for index=1,5 do
      local name="KA_RED_STATUE_"..index
      local q=assert(path.questionForStatue(game.save,name))
      check("RED statue "..index,path.answerStatue(game.save,name,q.id,q.answer)==true)
    end
    for _,name in ipairs({"A","B","C"}) do
      check("RED weight "..name,path.setBoulder(game.save,name)==true)
    end
    -- Enter only after the public gate is solved.  Entering the shrine
    -- earlier legitimately starts RED's automatic eject transition and
    -- leaves a synthetic test teleport racing that old transition.
    U.teleport(game,shrine,endCell.x,endCell.y+1,"up");U.wait(20)
    check("RED seal finalized",path.complete(game)==true)
  elseif character=="BLUE" then
    for _,name in ipairs({"HALL","ICE_NORTH","ICE_DEEP","DEPTHS_WEST","DEPTHS_EAST"}) do
      local q=assert(path.nextQuestion(name))
      check("BLUE statue "..name,path.answer(name,q.id,q.correct)==true)
    end
    U.teleport(game,shrine,endCell.x,endCell.y+1,"up");U.wait(20)
    local granted=path.claimAll(game)
    check("BLUE seal finalized",type(granted)=="table" and #granted==5)
  else
    for index=1,5 do
      local q=assert(path.questionFor(game.save,index))
      check("GREEN statue "..index,path.answer(game.save,index,q.answer)==true)
    end
    U.teleport(game,shrine,endCell.x,endCell.y+1,"up");U.wait(20)
    check("GREEN seal finalized",path.complete(game)==true)
  end

  check("stone absent before final stair",not adapter.hasSecret(game.save,character)
    and not mega.hasStone(stone))
  U.teleport(game,shrine,endCell.x,endCell.y+1,"up")
  U.wait(35);shot("01_before_final_stair")
  check("location banner closes before final input",clearFieldOverlay())
  check("physical approach is exact",game.overworld.map.id==shrine
    and game.overworld.player.cellX==endCell.x
    and game.overworld.player.cellY==endCell.y+1)
  -- The fixture reached this point through direct product API setup rather
  -- than the title screen, so discard any synthetic helper edge before the
  -- first acceptance input.  A human arrives here with a clean d-pad too.
  game.input:reset()
  local movementDiag={}
  for attempt=1,4 do
    if game.overworld.map.id~=shrine then break end
    -- Direction movement is level-triggered (`isDown`), unlike A/B.  Hold it
    -- across several accelerated driver frames just as a human D-pad press;
    -- a one-frame tap can fall wholly between Speed-8 overworld polls.
    -- Cover more than two complete Speed-8 overworld polls.  Four raw
    -- render frames can land entirely between controller updates on this
    -- large FULL map even though the key is genuinely held.
    -- Go through the same key source bookkeeping as a real keyboard hold.
    -- A raw pressQueue injection can be shadowed by an empty released-source
    -- record and is therefore not an adequate acceptance proof here.
    game.input:keypressed("up")
    -- Release on the first target-map frame.  Keeping UP held after the
    -- transition can immediately walk onto the shared room's return pad and
    -- make a successful out-and-back transition look like no movement.
    for _=1,48 do
      local ow,p=game.overworld,game.overworld.player
      U.wait(1)
      if game.overworld.map.id~=shrine then break end
    end
    game.input:keyreleased("up")
    U.wait(12)
    local ow,p=game.overworld,game.overworld.player
    movementDiag[#movementDiag+1]=table.concat({attempt,ow.map.id,p.cellX,p.cellY,
      p.facing,tostring(p.inputLocked),tostring(p.moving),
      tostring(p.turnTimer),#(ow.scriptMoves or {}),
      tostring(ow.runner and ow.runner:isRunning()),
      tostring(game.stack:top()==ow),tostring(game.input:isDown("up")),
      tostring(game.input:isDown("select"))},":")
  end
  local reached=waitFor(function()
    return game.overworld and game.overworld.map.id==shared.ID
      and game.stack:top()==game.overworld
  end,1800)
  if not reached then
    local ow=game.overworld
    local Collision=require("src.world.Collision")
    local allowed,why=Collision.canMove(ow.map,ow.entities,ow.player,"up")
    local occupants={}
    for _,entity in ipairs(ow.entities or {}) do
      if not entity.passable and ((entity.cellX==endCell.x and entity.cellY==endCell.y)
          or (entity.targetX==endCell.x and entity.targetY==endCell.y)) then
        occupants[#occupants+1]=tostring(entity.id or entity.spawnId
          or entity.followerSpecies or (entity.def and entity.def.name) or entity)
      end
    end
    error(("FAIL: physical final stair reaches shared room; diag=%s walk=%s warp=%s collision=%s/%s occupants=%s top=%s")
      :format(table.concat(movementDiag,"|"),
        tostring(ow.map:isWalkableCell(endCell.x,endCell.y)),
        tostring(ow.map:warpAtCell(endCell.x,endCell.y)~=nil),
        tostring(allowed),tostring(why),table.concat(occupants,","),
        tostring(game.stack:top())))
  end
  check("physical final stair reaches shared room",reached)
  local receipt=assert(shared.handoff(),"missing final-stair handoff receipt")
  check("receipt keeps exact character/source",receipt.character==character
    and receipt.sourceMap==shrine and receipt.seal==true)
  check("final stair grants exact last-chance stone",receipt.stone==stone
    and receipt.stoneStatus=="granted" and adapter.hasSecret(game.save,character)
    and mega.hasStone(stone))
  shot("02_shared_arrival_receipt")
  check("receipt writes before tablet",game:writeSave())
  local loaded=assert(SaveData.load());game:restoreSave(loaded);U.wait(35)
  receipt=assert(shared.handoff())
  check("receipt survives native reload",receipt.character==character
    and receipt.stone==stone and receipt.stoneAnnounced==false)

  U.teleport(game,shared.ID,15,6,"up");U.wait(20);U.tap(game,"a")
  local stoneLabel=({RED="LOHGOCKNIT",BLUE="SUMPEXNIT",
    GREEN="GEWALDRO-NIT"})[character]
  local stoneBox=assert(waitText(stoneLabel),"visible stone acknowledgement missing")
  check("tablet names Stone Case",textOf(stoneBox):find("Stone Case",1,true)
    or textOf(stoneBox):find("Steinkoffer",1,true))
  shot("03_tablet_stone_receipt")
  check("stone receipt closes",drainText(stoneBox))

  local blackout=assert(waitFor(function()
    local top=game.stack:top()
    return top~=game.overworld and top.isOpaque==true and top.lines and top or nil
  end,900),"legendary blackout missing")
  check("blackout names matching legendary",tostring(blackout.text):find(
    ({RED="GROUDON",BLUE="KYOGRE",GREEN="RAYQUAZA"})[character],1,true))
  shot("04_matching_legendary_blackout",false)
  U.tap(game,"a");U.wait(8)
  local oak=assert(waitText("PROF."),"Oak call missing")
  check("Oak call identifies matching seal",textOf(oak):find(
    ({RED="RED",BLUE="BLUE",GREEN="GREEN"})[character],1,true)
    or textOf(oak):find(({RED="ROTE",BLUE="BLAUE",GREEN="GRÜNE"})[character],1,true))
  shot("05_oak_call",false)
  check("Oak call closes",drainText(oak))
  local epilogue=assert(waitFor(function()
    local top=game.stack:top()
    return getmetatable(top)==TextBox and (textOf(top):find("Legacy",1,true)
      or textOf(top):find("Vermächtnis",1,true)) and top or nil
  end,1200),"seal epilogue missing")
  shot("06_seal_epilogue",false)
  check("epilogue closes",drainText(epilogue))
  check("tablet returns to playable field",waitFor(function()
    return game.stack:top()==game.overworld
  end,600))
  receipt=assert(shared.handoff())
  check("door acknowledgement is durable",receipt.acknowledged==true
    and receipt.stoneAnnounced==true and game.save.flags.KA_LEGACY_JOURNEY_OAK_CALLED==true)
  local before=mega.hasStone(stone)
  U.tap(game,"a")
  check("retry skips stone receipt and opens blackout",waitFor(function()
    local top=game.stack:top();return top and top.isOpaque==true and top.lines
  end,900))
  check("retry cannot duplicate stone",before and mega.hasStone(stone))

  os.execute('mkdir -p "'..outDir..'"')
  local result=assert(io.open(outDir.."/driver_result.txt","w"))
  result:write("PASS\ncharacter=",character,"\nrenderer=",renderer,
    "\nchecks=",checks,"\n")
  for _,row in ipairs(rows) do result:write(row,"\n") end
  result:close()
  U.log("HEVO FINAL WARP HANDOFF PASS",character,renderer,checks)
  love.event.quit(0)
end
