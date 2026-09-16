-- KASC 6.7 physical access layer for Moltres, the Regis and Deoxys.
-- Existing Kanto maps host four runtime scientists; the encounter rooms stay
-- separately removable Cards.  No quest marker or advance hint is emitted.

return function(mod,opts)
  opts=opts or{}
  local regis=assert(opts.regis,"Regi authority missing")
  local moltres=assert(opts.moltres,"Moltres authority missing")
  local birth=assert(opts.birth,"Birth Island authority missing")
  local placement=assert(opts.placement,"placement authority missing")
  local postgame=assert(opts.postgame,"postgame authority missing")
  local function tr(en,de)return opts.i18n and opts.i18n.text
    and opts.i18n.text(en,de)or en end
  local A={CARD_ID="KASC-66-HOENN-ENDGAME-ACCESS",
    OWNER="kasc.hoenn-endgame-access-puzzles/v1",registered=false}
  A.rows={
    {kind="expedition",map="CINNABAR_ISLAND",name="KA_HOENN_EXPEDITION_SCIENTIST",
      text="TEXT_KA_HOENN_EXPEDITION_SCIENTIST",
      preferred={{8,10},{10,10},{17,7},{14,7}}},
    -- Regirock's researcher is deliberately on the approach floor, tucked
    -- against the northern wall.  The summit remains Lavados' room; no NPC is
    -- allowed to stand beside the bird.
    {kind="regi",species="REGIROCK",map=moltres.ASCENT_MAP,
      name="KA_HIDDEN_REGIROCK_SCIENTIST",text="TEXT_KA_HIDDEN_REGIROCK_SCIENTIST",
      -- Revision 5: the north-west pocket is behind a rock rib and reached
      -- by turning off the upper passage. Every fallback stays in that
      -- pocket; never put him beside the bird or back on the main path.
      preferred={{3,3},{3,2},{4,3}}},
    {kind="regi",species="REGISTEEL",map="VICTORY_ROAD_2F",
      name="KA_HIDDEN_REGISTEEL_SCIENTIST",text="TEXT_KA_HIDDEN_REGISTEEL_SCIENTIST",
      preferred={{14,2},{16,2},{18,2},{24,2},{6,2}}},
    {kind="regi",species="REGICE",map="SEAFOAM_ISLANDS_B4F",
      name="KA_HIDDEN_REGICE_SCIENTIST",text="TEXT_KA_HIDDEN_REGICE_SCIENTIST",
      preferred={{14,2},{18,2},{22,2},{24,2},{10,2}}},
  }
  A.byText={};for _,row in ipairs(A.rows)do A.byText[row.text]=row end
  local activeGame,mapScripts

  local function option(game)
    local bucket=game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket.hoenn_endgame_access_puzzles~=nil then
      return bucket.hoenn_endgame_access_puzzles~=false
    end
    local value=mod.options and mod.options.get
      and mod.options:get("hoenn_endgame_access_puzzles")
    return value~=false
  end
  local function currentOverworld(game)
    return mod.world and type(mod.world.overworld)=="function"
      and mod.world:overworld()or game and game.overworld
  end
  local function runtimeIds(game,row)
    local out={};local map=game and game.data and game.data.maps
      and game.data.maps[row.map]
    for _,object in ipairs(map and map.objects or{})do
      if object.runtime and object.owner==mod.id and object.name==row.name then
        out[#out+1]=row.map.."_obj_"..tostring(object.index)
      end
    end
    return out
  end
  local function wanted(game,row)
    if not option(game)or not postgame.hasHallOfFame(game and game.save)then return false end
    if row.kind=="expedition"then return moltres.available(game)end
    if row.species=="REGIROCK"and not moltres.eventComplete(game)then
      return false
    end
    return regis.available(game)
  end
  function A.refresh(game)
    game=game or activeGame;local ow=currentOverworld(game)
    local mapId=ow and ow.map and ow.map.id;if not mapId then return false,"map"end
    for _,row in ipairs(A.rows)do if row.map==mapId then
      local ids=runtimeIds(game,row)
      if not wanted(game,row)then
        for _,id in ipairs(ids)do pcall(mod.world.removeNpc,mod.world,id)end
      elseif #ids==0 then
        local x,y=placement.find(ow,row.preferred)
        if not x then return false,"no-safe-cell:"..row.name end
        local ok,id=pcall(mod.world.spawnNpc,mod.world,row.map,{
          name=row.name,sprite="SPRITE_SCIENTIST",movement="STAY",range="DOWN",
          text=row.text,x=x,y=y,
        })
        if not ok or not id then return false,"spawn:"..row.name end
      end
    end end
    return true
  end

  local function show(game,text,done,boxOpts)
    game.stack:push(require("src.render.TextBox").new(game,text,done,boxOpts));return true
  end
  function A.regiTalk(row,game,ow,npc,done)
    if regis.eventComplete(game,row.species)then
      return show(game,tr("RESEARCHER: The chamber is quiet now.",
        "FORSCHER: Die Kammer ist jetzt still."),done)
    end
    local names={REGIROCK="REGIROCK",REGICE="REGICE",REGISTEEL="REGISTEEL"}
    return show(game,tr(
      "RESEARCHER: This wall sounds hollow. Behind it is a dotted stone seal. Enter?",
      "FORSCHER: Diese Wand klingt hohl. Dahinter liegt ein altes Punktsiegel. Hineingehen?"),nil,
      {defaultNo=true,choice=function(yes)
        if yes then regis.enter(game,names[row.species],ow and ow.player)
        elseif done then done()end
      end})
  end
  function A.expeditionTalk(game,ow,npc,done)
    if not moltres.eventComplete(game)then
      return show(game,tr(
        "RESEARCHER: I am leaving for the volcanic island. Come with me?",
        "FORSCHER: Ich breche zur Vulkaninsel auf. Kommst du mit?"),nil,
        {defaultNo=true,choice=function(yes)
          if yes then moltres.openExpedition(game)elseif done then done()end
        end})
    end
    if not regis.eventComplete(game,"REGIROCK")then
      return show(game,tr(
        "RESEARCHER: I still have equipment on the volcanic island. Return there?",
        "FORSCHER: Auf der Vulkaninsel steht noch meine Ausrüstung. Sollen wir zurückkehren?"),nil,
        {defaultNo=true,choice=function(yes)
          if yes then moltres.openExpedition(game)elseif done then done()end
        end})
    end
    if birth.available(game)and not birth.caught(game)then
      return show(game,tr(
        "RESEARCHER: The signal now points to Birth Island. Ready to depart?",
        "FORSCHER: Das Signal führt jetzt zur Entstehungsinsel. Bist du bereit?"),nil,
        {defaultNo=true,choice=function(yes)
          if yes then birth.enter(game)elseif done then done()end
        end})
    end
    if birth.caught(game)then return show(game,tr(
      "RESEARCHER: This expedition is complete.",
      "FORSCHER: Diese Expedition ist abgeschlossen."),done)end
    return show(game,tr(
      "RESEARCHER: The volcanic readings are complete. I am still checking the other data.",
      "FORSCHER: Die Vulkanmessungen sind abgeschlossen. Die übrigen Daten prüfe ich noch."),done)
  end
  function A.talk(row,game,ow,npc,done)
    if not wanted(game,row)then if done then done()end;return false end
    if row.kind=="expedition"then return A.expeditionTalk(game,ow,npc,done)end
    return A.regiTalk(row,game,ow,npc,done)
  end

  function A.register()
    if A.registered then return false,"already-registered"end
    for _,row in ipairs(A.rows)do
      mod.content.text:register(row.text,row.kind=="expedition"
        and"A scientist is preparing an expedition."
        or"A scientist studies the wall.")
      mod.content.text_pointers:patch("???",{[row.text]={text=row.text}})
    end
    A.registered=true;return true
  end
  function A.install(game,deps)
    activeGame=game or activeGame;deps=deps or{}
    mapScripts=deps.mapScripts or mapScripts or require("data.scripts.init")
    for _,row in ipairs(A.rows)do
      local script=mapScripts.get and mapScripts.get(row.map)
      if script then
        script.talk=type(script.talk)=="table"and script.talk or{}
        script.talk[row.text]=function(g,ow,npc,done)return A.talk(row,g,ow,npc,done)end
      end
    end
    A.refresh(activeGame);return true
  end
  if mod.events and type(mod.events.on)=="function"then
    for _,event in ipairs({"save.loaded","game.ready","map.entered"})do
      mod.events:on(event,function(ev)local game=ev and ev.game or activeGame
        if game then A.install(game,{mapScripts=mapScripts})end end,4245)
    end
  end
  return A
end
