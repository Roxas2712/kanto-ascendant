-- KASC 6.7 optional Birth Island / Deoxys card.
-- The shared Cinnabar expedition scientist owns physical travel.  Availability
-- additionally requires Moltres and Regirock completion in this playthrough;
-- persistent Dex receipts alone deliberately cannot satisfy that gate.

return function(mod,opts)
  opts=opts or{}
  local dex=assert(opts.dex,"Hoenn Dex authority missing")
  local runEvents=opts.runEvents
  local function tr(en,de)return opts.i18n and opts.i18n.text
    and opts.i18n.text(en,de)or en end
  local B={SAVE_KEY="hoenn_birth_island_67",STATE_VERSION=1,
    MAP="KA_HOENN_BIRTH_ISLAND",INDEX=1987,LEVEL=30,
    CAPTAIN_MAP="VERMILION_CITY",CAPTAIN_TEXT="TEXT_VERMILIONCITY_SAILOR2",
    TRIANGLE_TEXT="TEXT_KA_HOENN_BIRTH_TRIANGLE",
    RETURN_TEXT="TEXT_KA_HOENN_BIRTH_RETURN",
    RETURN={map="VERMILION_CITY",x=25,y=26,facing="down"},
    ENTRY={x=8,y=13,facing="up"},registered=false}
  B.trianglePositions={{8,8},{5,6},{11,6},{6,3},{10,3},{8,4}}
  local activeGame,mapScripts,originalCaptain
  local function copy(v,seen)if type(v)~="table"then return v end;seen=seen or{}
    if seen[v]then return seen[v]end;local o={};seen[v]=o
    for k,c in pairs(v)do o[copy(k,seen)]=copy(c,seen)end;return o end
  local function state()
    local raw=mod.save:get(B.SAVE_KEY);local s=type(raw)=="table"and copy(raw)or{}
    s.version=B.STATE_VERSION;s.triangle=math.max(0,math.min(#B.trianglePositions-1,
      math.floor(tonumber(s.triangle)or 0)))
    s.caught=type(s.caught)=="table"and s.caught or nil
    mod.save:set(B.SAVE_KEY,s);return s
  end
  local function persist(s)s.version=B.STATE_VERSION;mod.save:set(B.SAVE_KEY,s);return s end
  local function option(game)local bucket=game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket.hoenn_birth_island~=nil then return bucket.hoenn_birth_island~=false end
    local value=mod.options and mod.options.get and mod.options:get("hoenn_birth_island")
    return value~=false end
  function B.caught(game)
    if runEvents and type(runEvents.completed)=="function"then
      return runEvents.completed(game,"DEOXYS")
    end
    local save=game and game.save;local events=save and save.kaHoennEndgameRunEvents67
    return type(events)=="table"and type(events.completed)=="table"
      and type(events.completed.DEOXYS)=="table"or false
  end
  function B.volcanoEventsComplete(game)
    if runEvents and type(runEvents.deoxysReady)=="function"then
      return runEvents.deoxysReady(game)
    end
    local save=game and game.save;local events=save and save.kaHoennEndgameRunEvents67
    local completed=type(events)=="table"and events.completed or nil
    return type(completed)=="table"and type(completed.MOLTRES)=="table"
      and type(completed.REGIROCK)=="table"or false
  end
  local function triangleStep(game)
    if runEvents and type(runEvents.progress)=="function"then
      return math.max(0,math.min(#B.trianglePositions-1,
        math.floor(tonumber(runEvents.progress(game,"DEOXYS_TRIANGLE",0))or 0)))
    end
    local save=game and game.save;local events=save and save.kaHoennEndgameRunEvents67
    local progress=type(events)=="table"and events.progress or nil
    return math.max(0,math.min(#B.trianglePositions-1,
      math.floor(tonumber(type(progress)=="table"and progress.DEOXYS_TRIANGLE or 0)or 0)))
  end
  local function setTriangleStep(game,step)
    if runEvents and type(runEvents.setProgress)=="function"then
      return runEvents.setProgress(game,"DEOXYS_TRIANGLE",step)
    end
    game.save.kaHoennEndgameRunEvents67=game.save.kaHoennEndgameRunEvents67
      or{version=1,completed={},progress={}}
    local events=game.save.kaHoennEndgameRunEvents67
    events.progress=type(events.progress)=="table"and events.progress or{}
    events.progress.DEOXYS_TRIANGLE=step;return true
  end
  function B.available(game)return option(game)
    and dex.report(game).birthIslandReady==true
    and B.volcanoEventsComplete(game)end
  local function show(game,text,done,boxOpts)game.stack:push(
    require("src.render.TextBox").new(game,text,done,boxOpts));return true end
  local function writeSave(game)return not game or type(game.writeSave)~="function"or game:writeSave()end
  local function warp(game,mapId,p)if mod.world and type(mod.world.warpTo)=="function"then
      local ok=mod.world:warpTo(mapId,p.x,p.y,p.facing);if ok then return true end end
    local ow=game and game.overworld;if not(ow and type(ow.startWarpTo)=="function")then return false end
    ow:startWarpTo(mapId,p.x,p.y,p.facing);return true end
  function B.enter(game)if not B.available(game)then return false,"unavailable"end
    writeSave(game);return warp(game,B.MAP,B.ENTRY)end
  function B.leave(game)return warp(game,B.RETURN.map,B.RETURN)end
  local function fallback(game,ow,npc,done)if type(originalCaptain)=="function"then
      return originalCaptain(game,ow,npc,done)end;if done then done()end;return false end
  function B.captainTalk(game,ow,npc,done)
    if not B.available(game)then return fallback(game,ow,npc,done)end
    if B.caught(game)then return show(game,tr(
      "CAPTAIN: The secret Birth Island voyage is complete.",
      "KAPITÄN: Die geheime Reise zur Entstehungsinsel ist abgeschlossen."),done)end
    return show(game,tr(
      "CAPTAIN: Three ancient capture seals reveal an island outside every chart.\fSail there now?",
      "KAPITÄN: Drei uralte Fangsiegel zeigen eine Insel auf keiner Karte.\fJetzt dorthin segeln?"),nil,
      {defaultNo=true,choice=function(yes)if yes then B.enter(game)elseif done then done()end end})
  end
  local function findTriangle(ow)
    for _,npc in ipairs(ow and ow.npcs or{})do
      if npc.def and npc.def.name=="KA_HOENN_BIRTH_TRIANGLE"then return npc end
    end
  end
  function B.syncTriangle(ow)
    local npc=findTriangle(ow);if not npc then return false end
    local p=B.trianglePositions[triangleStep(activeGame)+1];npc.x,npc.y=p[1],p[2];return true
  end
  local function stored(save,mon)for _,m in ipairs(save and save.party or{})do if m==mon then return true end end
    for _,box in ipairs(save and save.boxes or{})do for _,m in ipairs(box)do if m==mon then return true end end end
    return false end
  function B.recordCatch(game,mon)if not(game and game.save and stored(game.save,mon))then
      return false,"not-stored"end;local s=state()
    local receipt={map=B.MAP,level=tonumber(mon.level)or B.LEVEL}
    local marked,why
    if runEvents and type(runEvents.mark)=="function"then
      marked,why=runEvents.mark(game,"DEOXYS",receipt)
    else
      game.save.kaHoennEndgameRunEvents67=
        game.save.kaHoennEndgameRunEvents67 or{version=1,completed={}}
      local completed=game.save.kaHoennEndgameRunEvents67.completed
      if completed.DEOXYS then marked,why=false,"recorded"
      else completed.DEOXYS=receipt;marked=true end
    end
    if not marked and why~="recorded"then return false,why end
    if not s.caught then s.caught=receipt;persist(s);dex.record(game,"DEOXYS")end
    writeSave(game);return marked,receipt end
  function B.startBattle(game,ow,done)
    local BattleState=opts.battleState or require("src.battle.BattleState")
    local battle=BattleState.newWild(game,"DEOXYS",B.LEVEL,{
      encounterSource="birth_island",randomizerProtected=true})
    battle.kaBirthIslandDeoxys=true
    battle.onFinish=function(result)if result=="caught"then
        B.recordCatch(game,battle.enemy and battle.enemy.mon)end
      if ow and type(ow.afterBattle)=="function"then ow:afterBattle(result,battle)end
      if done then done()end end
    if ow and type(ow.pushBattle)=="function"then ow:pushBattle(battle)return true end
    if done then done()end;return false end
  function B.triangleTalk(game,ow,npc,done)
    if not B.available(game)then return show(game,tr("The signal is dormant.",
      "Das Signal ruht."),done)end
    if B.caught(game)then return show(game,tr("The triangle is still.","Das Dreieck ruht."),done)end
    local step=triangleStep(game)
    if step<#B.trianglePositions-1 then
      setTriangleStep(game,step+1);activeGame=game;B.syncTriangle(ow);writeSave(game)
      return show(game,tr("The black triangle shifts closer to the center.",
        "Das schwarze Dreieck rückt näher zur Mitte."),done)
    end
    return show(game,tr("The triangle flashes. DEOXYS descends!",
      "Das Dreieck blitzt. DEOXYS erscheint!"),function()B.startBattle(game,ow,done)end)
  end
  local function blocks()local w,h,wall,floor,glint=8,8,125,25,21;local o={}
    for i=1,w*h do o[i]=wall end;local function put(x,y,v)o[x+y*w+1]=v end
    for y=1,6 do for x=1,6 do put(x,y,floor)end end
    for _,p in ipairs({{3,1},{4,1},{2,2},{5,2},{1,3},{6,3},{3,4},{4,4}})do put(p[1],p[2],glint)end
    return o end
  function B.register()if B.registered then return false,"already-registered"end
    local tilesets=mod.content.tilesets;if tilesets and type(tilesets.get)=="function"
      and not tilesets:get("CAVERN")then B.registered,B.skipped=true,"missing-cavern";return true,B.skipped end
    assert(not mod.content.maps:get(B.MAP),"duplicate Birth Island")
    for id,def in mod.content.maps:each()do assert(not(def and def.index==B.INDEX),
      "duplicate Birth Island index "..tostring(id))end
    mod.content.maps:register(B.MAP,{id=B.MAP,index=B.INDEX,label="BIRTH ISLAND",
      tileset="CAVERN",width=8,height=8,borderBlock=125,blocks=blocks(),warps={},signs={},
      connections={},outdoor=false,voxelMode="FULL",voxelRevision=1,objects={
        {index=1,name="KA_HOENN_BIRTH_TRIANGLE",sprite="SPRITE_POKE_BALL",x=8,y=8,
          movement="STAY",range="NONE",text=B.TRIANGLE_TEXT,passable=false},
        {index=2,name="KA_HOENN_BIRTH_RETURN",sprite="SPRITE_SAILOR",x=8,y=13,
          movement="STAY",range="UP",text=B.RETURN_TEXT,passable=false}}})
    mod.content.encounters:register(B.MAP,{grass={rate=0,slots={}}})
    if mod.content.map_songs then mod.content.map_songs:register(B.MAP,"Music_Dungeon1")end
    mod.content.text:register(B.TRIANGLE_TEXT,"A black triangle hums.")
    mod.content.text:register(B.RETURN_TEXT,"Return to Vermilion?")
    mod.content.text_pointers:patch("???",{[B.TRIANGLE_TEXT]={text=B.TRIANGLE_TEXT},
      [B.RETURN_TEXT]={text=B.RETURN_TEXT}})
    mod.content.map_scripts:register(B.MAP,{priority=3410,
      onEnter=function(game,ow)activeGame=game;B.syncTriangle(ow)end,talk={
      [B.TRIANGLE_TEXT]=function(game,ow,npc,done)return B.triangleTalk(game,ow,npc,done)end,
      [B.RETURN_TEXT]=function(game,_,_,done)return show(game,tr("Return to VERMILION CITY?",
        "Zurück nach ORANIA CITY?"),nil,{defaultNo=true,choice=function(yes)
          if yes then B.leave(game)elseif done then done()end end})end}})
    B.registered=true;return true end
  function B.secureSave(save)local p=save and save.player;if not(type(p)=="table"and p.map==B.MAP)then return false end
    p.map,p.x,p.y,p.facing=B.RETURN.map,B.RETURN.x,B.RETURN.y,B.RETURN.facing;p.surfing=false;return true end
  function B.install(game,deps)activeGame=game or activeGame;deps=deps or{};opts.battleState=deps.battleState or opts.battleState
    mapScripts=deps.mapScripts or mapScripts or require("data.scripts.init")
    state();return true end
  if mod.events and type(mod.events.on)=="function"then
    mod.events:on("save.writing",function(ev)B.secureSave(ev and ev.save or activeGame and activeGame.save)end,4230)
    for _,event in ipairs({"save.loaded","game.ready"})do mod.events:on(event,function(ev)
      local game=ev and ev.game or activeGame;if game then B.install(game,{mapScripts=mapScripts})end end,4230)end
  end
  return B
end
