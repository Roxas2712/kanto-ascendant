-- RED-only real LÖVE renderer probe. This is intentionally a render sample,
-- not the input-driven traversal driver used for the final release gate.
return function(game)
  local U=dofile("tests/drivers/util.lua")
  local RuntimeMap=require("src.world.Map")
  local root=assert(os.getenv("SHOT_DIR"),"SHOT_DIR is required")
  local only=os.getenv("KA_HEVO_RED_CAPTURE_MAP")
  local sight=math.max(0,math.min(5,tonumber(os.getenv("KA_HEVO_RED_SIGHT")) or 0))
  local maps=only and {only} or {
    "KA_HEVO_RED_UPPER","KA_HEVO_RED_ABYSS","KA_HEVO_RED_RECOVERY",
    "KA_HEVO_RED_LOWER","KA_HEVO_RED_SHRINE",
  }
  local focus={
    KA_HEVO_RED_UPPER={13,29},KA_HEVO_RED_ABYSS={15,23},
    KA_HEVO_RED_RECOVERY={33,9},KA_HEVO_RED_LOWER={39,13},
    KA_HEVO_RED_SHRINE={35,11},
  }
  game.save.options=game.save.options or {};game.save.options.modOptions=game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant=game.save.options.modOptions.kanto_ascendant or {}
  game.save.options.modOptions.kanto_ascendant.qol_location_banners=false
  local exports=assert(game.mods.exports.kanto_ascendant,"Kanto Ascendant not loaded")
  local red=assert(exports.hiddenEvolutionCampaign.modules.RED,"RED campaign unavailable")
  local run=red.run(game.save,true);run.sight=sight;run.statues=run.statues or {}
  for i=1,sight do run.statues["KA_RED_STATUE_"..i]=true end

  local function spawn(def,wanted)
    local runtime=RuntimeMap.new(def,assert(game.data.tilesets[def.tileset]))
    local best,score
    for y=1,def.height*2-2 do for x=1,def.width*2-2 do
      if runtime:isWalkableCell(x,y) then
        local d=(x-wanted[1])^2+(y-wanted[2])^2
        if not score or d<score then best,score={x,y},d end
      end
    end end
    assert(best,"no walkable RED capture cell");return best[1],best[2]
  end
  local function settle()
    U.wait(24)
    for _=1,4 do if game.stack:top()==game.overworld then break end;U.tap(game,"b");U.wait(10) end
    U.tap(game,"b");U.wait(30)
    assert(game.stack:top()==game.overworld,"RED overlay obscures capture")
  end
  for _,id in ipairs(maps) do
    local def=assert(game.data.maps[id],"missing RED map "..id)
    local x,y=spawn(def,assert(focus[id],"missing RED focus"))
    U.teleport(game,id,x,y,"down");settle()
    assert(U.shot(game,string.format("%s/2d/%s_sight%d.png",root,id:lower(),sight)))
  end
  U.log("RED render sample / NOT TRAVERSAL",root,#maps.." maps","sight="..sight)
  love.event.quit(0)
end
