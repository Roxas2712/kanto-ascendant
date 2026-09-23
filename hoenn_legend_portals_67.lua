-- KASC 6.7 optional character-locked Hoenn legend portal card.
--
-- Extends the existing black HEVO door only after the 130-species foundation
-- is complete. RED/Groudon, BLUE/Kyogre and GREEN/Rayquaza remain separate;
-- capture receipts are monotonic Legacy-lineage evidence for Birth Island.

return function(mod,opts)
  opts=opts or{}
  local dex=assert(opts.dex,"Hoenn Dex authority missing")
  local journey=assert(opts.journey,"Legacy journey missing")
  local geometry=assert(opts.geometry,"Hoenn exploration geometry missing")
  local skyTileset=opts.skyTileset or"KA_HOENN_SKY_67"
  local function tr(en,de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en,de)or en
  end
  local P={registered=false,bound=false,LEVEL=70}
  P.rows={
    RED={character="RED",species="GROUDON",flag="KA_LEGEND_CAPTURE_GROUDON",
      map="KA_HEVO_GROUDON_CHAMBER",index=1984,label={en="GROUDON CHAMBER",de="GROUDON-KAMMER"},
      text="TEXT_KA_HEVO_GROUDON_CAPTURE",returnX=3},
    BLUE={character="BLUE",species="KYOGRE",flag="KA_LEGEND_CAPTURE_KYOGRE",
      map="KA_HEVO_KYOGRE_CHAMBER",index=1985,label={en="KYOGRE CHAMBER",de="KYOGRE-KAMMER"},
      text="TEXT_KA_HEVO_KYOGRE_CAPTURE",returnX=15},
    GREEN={character="GREEN",species="RAYQUAZA",flag="KA_LEGEND_CAPTURE_RAYQUAZA",
      map="KA_HEVO_RAYQUAZA_CHAMBER",index=1986,label={en="RAYQUAZA CHAMBER",de="RAYQUAZA-KAMMER"},
      text="TEXT_KA_HEVO_RAYQUAZA_CAPTURE",returnX=27},
  }
  P.byMap={};for _,row in pairs(P.rows)do P.byMap[row.map]=row end
  local activeGame,shared,originalDoor
  local function option(game)
    local bucket=game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket.hoenn_legend_portals~=nil then
      return bucket.hoenn_legend_portals~=false
    end
    local value=mod.options and mod.options.get
      and mod.options:get("hoenn_legend_portals")
    return value~=false
  end
  local function persistent(save,create)
    if type(save)~="table"then return nil end
    if type(save.modData)~="table"then if not create then return nil end;save.modData={}end
    local bucket=save.modData[mod.id]
    if type(bucket)~="table"then if not create then return nil end;bucket={};save.modData[mod.id]=bucket end
    if type(bucket.hevo_persistent)~="table"then
      if not create then return nil end;bucket.hevo_persistent={}
    end
    local p=bucket.hevo_persistent
    if type(p.secretUnlocks)~="table"then
      if not create then return p end;p.secretUnlocks={}
    end
    return p
  end
  local function profileReceipts()
    local ok,value=pcall(journey.profile)
    return ok and type(value)=="table"and value.secretUnlocks or{}
  end
  function P.caught(game,row)
    row=type(row)=="table"and row or P.rows[row]
    if not row then return false end
    local p=persistent(game and game.save,false)
    return p and p.secretUnlocks and p.secretUnlocks[row.flag]==true
      or profileReceipts()[row.flag]==true or false
  end
  local function currentCharacter(game)
    local value=shared and type(shared.character)=="function"and shared.character(game)
    value=type(value)=="string"and value:upper()or nil
    return P.rows[value]and value or nil
  end
  local function sealValid(game,character)
    if type(journey.currentHevoSeal)~="function"then return false end
    local ok,sealed,owner=pcall(journey.currentHevoSeal,game and game.save,character)
    return ok and sealed==true and owner==character
  end
  function P.available(game,character)
    character=character or currentCharacter(game)
    return option(game)and P.rows[character]~=nil and sealValid(game,character)
      and dex.report(game).portalReady==true
  end
  local function stored(save,mon)
    for _,candidate in ipairs(save and save.party or{})do if candidate==mon then return true end end
    for _,box in ipairs(save and save.boxes or{})do
      for _,candidate in ipairs(box)do if candidate==mon then return true end end
    end
    return false
  end
  function P.recordCatch(game,row,mon)
    row=type(row)=="table"and row or P.rows[row]
    if not(row and game and game.save and stored(game.save,mon))then
      return false,"not-stored"
    end
    local p=persistent(game.save,true)
    if p.secretUnlocks[row.flag]==true then return false,"recorded"end
    p.secretUnlocks[row.flag]=true
    dex.record(game,row.species)
    local ok,result=pcall(journey.syncHevoPersistent,game.save)
    if type(game.writeSave)=="function"then game:writeSave()end
    return true,ok and result~=false and"recorded"or"local-only"
  end
  local function show(game,text,done,boxOpts)
    game.stack:push(require("src.render.TextBox").new(game,text,done,boxOpts));return true
  end
  local function warp(game,mapId,x,y,facing)
    if mod.world and type(mod.world.warpTo)=="function"then
      local ok=mod.world:warpTo(mapId,x,y,facing);if ok then return true end
    end
    local ow=game and game.overworld
    if not(ow and type(ow.startWarpTo)=="function")then return false end
    ow:startWarpTo(mapId,x,y,facing);return true
  end
  function P.enter(game,row)
    if not P.available(game,row.character)then return false,"unavailable"end
    if type(game.writeSave)=="function"and game:writeSave()==false then
      return false,"save"
    end
    if opts.accessReturn then opts.accessReturn.clear(game.save) end
    return warp(game,row.map,8,11,"up")
  end
  function P.leave(game,row)
    local back = opts.accessReturn and opts.accessReturn.point(game.save, row.map)
    if back then
      local ok = warp(game, back.map, back.x, back.y, back.facing)
      if ok then opts.accessReturn.clear(game.save) end
      return ok
    end
    return warp(game,shared.ID,row.returnX,20,"down")
  end
  function P.doorInteraction(game,ow,npc,done)
    game=game or activeGame
    local character=currentCharacter(game)
    if not(character and P.available(game,character))then
      return originalDoor(game,ow,npc,done)
    end
    local row=P.rows[character]
    if P.caught(game,row)then
      return show(game,tr(
        row.species.."'s captured seal shines across every Legacy Journey.",
        "Das Fangsiegel von "..row.species.." leuchtet durch jede Vermächtnis-Reise."),done)
    end
    return show(game,tr(
      "The complete Hoenn foundation opens "..row.species.."'s portal.\fSave and enter now?",
      "Das Hoenn-Fundament öffnet das Portal zu "..row.species..".\fJetzt speichern und eintreten?"),nil,{
        defaultNo=true,choice=function(yes)
          if yes then
            local ok=P.enter(game,row)
            if not ok then show(game,tr("The save or portal failed. You remain here.",
              "Speichern oder Portal fehlgeschlagen. Du bleibst hier."),done)end
          elseif done then done()end
        end})
  end
  function P.challenge(game,ow,npc,done,row)
    if P.caught(game,row)then return show(game,tr("The capture seal is complete.",
      "Das Fangsiegel ist vollständig."),done)end
    local function start()
      local BattleState=opts.battleState or require("src.battle.BattleState")
      local battle=BattleState.newWild(game,row.species,P.LEVEL,{
        encounterSource="hoenn_legend_portal",randomizerProtected=true})
      battle.kaHoennLegendPortal=row.character
      battle.onFinish=function(result)
        if result=="caught"then P.recordCatch(game,row,battle.enemy and battle.enemy.mon)end
        if ow and type(ow.afterBattle)=="function"then ow:afterBattle(result,battle)end
        if done then done()end
      end
      if ow and type(ow.pushBattle)=="function"then ow:pushBattle(battle)
      elseif done then done()end
    end
    return show(game,tr(row.species.." answers your "..row.character.." seal!",
      row.species.." antwortet deinem "..row.character.."EN Siegel!"),start)
  end
  function P.bindShared(module)
    if P.bound then return false,"already-bound"end
    shared=assert(module,"shared HEVO room missing")
    originalDoor=assert(shared.doorInteraction,"shared door handler missing")
    shared.doorInteraction=P.doorInteraction
    P.bound=true;return true
  end
  function P.register()
    if P.registered then return false,"already-registered"end
    assert(P.bound,"portal card must bind the shared door before registration")
    local tilesets=mod.content.tilesets
    if tilesets and type(tilesets.get)=="function"and not tilesets:get("CAVERN")then
      P.registered,P.skipped=true,"missing-cavern";return true,P.skipped
    end
    local indexes={};for id,def in mod.content.maps:each()do
      if def and def.index then indexes[def.index]=id end
    end
    for _,key in ipairs({"RED","BLUE","GREEN"})do
      local row=P.rows[key]
      assert(not mod.content.maps:get(row.map),"duplicate legend chamber "..row.map)
      assert(not indexes[row.index],"duplicate legend chamber index "..row.index)
      indexes[row.index]=row.map
      local returnText=row.text.."_RETURN"
      local isSky=row.character=="GREEN"
      -- Keep the chamber's scripted encounter/receipt owner, but show the
      -- actual legendary instead of the shared SPRITE_MONSTER placeholder.
      -- These three small native sheets are bundled with the room so the
      -- display does not depend on an optional follower download.
      local sprite="SPRITE_KA_HEVO_LEGEND_"..row.species
      mod.content.sprites:register(sprite,{id=sprite,
        image=mod.path.."/assets/hoenn_legend_rooms/"..row.species:lower()..".png",
        frames=6,walker=true,trueColor=true,pokemonSpecies=row.species,
        voxelChamberImage=mod.path..'/assets/hoenn_legend_rooms/'..row.species:lower()..'_front.png'})
      local source=assert(geometry.map(row.map),"missing legend exploration map")
      assert(source.index==row.index,"legend map index changed")
      local chamberBlocks={};for i,block in ipairs(source.blocks)do chamberBlocks[i]=block end
      if row.character=="RED"then
        -- CAVERN block 1 uses elevation tile 0x20. The two blocks under
        -- the arrival point form an island: native tile-pair collision
        -- forbids every step onto the surrounding 0x05 floor. Continue
        -- the ordinary cave floor through the landing to the encounter.
        chamberBlocks[4+4*source.width+1]=25
        chamberBlocks[4+5*source.width+1]=25
      end
      mod.content.maps:register(row.map,{id=row.map,index=row.index,
        label=tr(row.label.en,row.label.de),tileset=isSky and skyTileset or"CAVERN",
        width=source.width,height=source.height,borderBlock=isSky and 0 or 125,
        blocks=chamberBlocks,warps={},
        signs={{name="KA_HEVO_"..row.species.."_RETURN",x=8,y=13,text=returnText}},
        connections={},
        outdoor=isSky,
        -- The air atlas already contains the authored sky platform.  Treating
        -- its tile IDs as generic FULL geometry invents forest walls around
        -- Rayquaza; MAP_STUDIO keeps that additive visual map flat and airy.
        voxelMode=isSky and"MAP_STUDIO"or"FULL",
        voxelRevision=source.voxelRevision+(row.character=="RED"and 1 or 0),voxelAuthority="2D_BLOCKS",
        kaExplorationRevisionSha256=geometry.EXPLORATION_REVISION_SHA256,objects={
          {index=1,name="KA_HEVO_"..row.species,sprite=sprite,x=8,y=4,
            movement="STAY",range="DOWN",text=row.text,passable=false}}})
      mod.content.encounters:register(row.map,{grass={rate=0,slots={}}})
      if mod.content.map_songs then mod.content.map_songs:register(row.map,"Music_Dungeon1")end
      mod.content.text:register(row.text,row.species.." is waiting.")
      mod.content.text:register(returnText,"Return through the black portal?")
      mod.content.text_pointers:patch("???",{[row.text]={text=row.text},
        [returnText]={text=returnText}})
      mod.content.map_scripts:register(row.map,{priority=3400,talk={
        [row.text]=function(game,ow,npc,done)return P.challenge(game,ow,npc,done,row)end,
        [returnText]=function(game,_,_,done)
          return show(game,tr("Return through the entrance?",
            "Durch den Eingang zurückkehren?"),nil,{defaultNo=true,
              choice=function(yes)if yes then P.leave(game,row)elseif done then done()end end})
        end}})
    end
    P.registered=true;return true
  end
  function P.secureSave(save)
    local player=save and save.player;local row=player and P.byMap[player.map]
    if not row then return false end
    local back = opts.accessReturn and opts.accessReturn.point(save, row.map)
    if back then player.map,player.x,player.y,player.facing=back.map,back.x,back.y,back.facing
    else player.map,player.x,player.y,player.facing=shared.ID,row.returnX,20,"down" end
    player.surfing=false;return true
  end
  function P.install(game,deps)
    activeGame=game or activeGame;deps=deps or{}
    opts.battleState=deps.battleState or opts.battleState
    return true
  end
  if mod.events and type(mod.events.on)=="function"then
    mod.events:on("save.writing",function(ev)
      P.secureSave(ev and ev.save or activeGame and activeGame.save)
    end,4220)
  end
  return P
end
