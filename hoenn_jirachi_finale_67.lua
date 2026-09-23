-- KASC 6.7 optional Jirachi wish chamber and Hoenn certificate card.

return function(mod,opts)
  opts=opts or{}
  local dex=assert(opts.dex,"Hoenn Dex authority missing")
  local journey=assert(opts.journey,"Legacy journey missing")
  local function tr(en,de)return opts.i18n and opts.i18n.text
    and opts.i18n.text(en,de)or en end
  local J={SAVE_KEY="hoenn_jirachi_finale_67",STATE_VERSION=1,
    MAP="KA_HOENN_WISH_CHAMBER",INDEX=1988,LEVEL=30,
    CAPTAIN_MAP="VERMILION_CITY",CAPTAIN_TEXT="TEXT_VERMILIONCITY_SAILOR1",
    JIRACHI_TEXT="TEXT_KA_HOENN_JIRACHI",RETURN_TEXT="TEXT_KA_HOENN_JIRACHI_RETURN",
    FLAG="KA_LEGEND_CAPTURE_JIRACHI",RETURN={map="VERMILION_CITY",x=19,y=29,facing="down"},
    ENTRY={x=8,y=11,facing="up"},registered=false}
  local activeGame,mapScripts,originalCaptain
  local function copy(v,seen)if type(v)~="table"then return v end;seen=seen or{}
    if seen[v]then return seen[v]end;local o={};seen[v]=o
    for k,c in pairs(v)do o[copy(k,seen)]=copy(c,seen)end;return o end
  local function state()local raw=mod.save:get(J.SAVE_KEY);local s=type(raw)=="table"and copy(raw)or{}
    s.version=J.STATE_VERSION;s.caught=type(s.caught)=="table"and s.caught or nil
    s.certificate=s.certificate==true;mod.save:set(J.SAVE_KEY,s);return s end
  local function persist(s)s.version=J.STATE_VERSION;mod.save:set(J.SAVE_KEY,s);return s end
  local function option(game)local bucket=game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket.hoenn_jirachi_finale~=nil then return bucket.hoenn_jirachi_finale~=false end
    local value=mod.options and mod.options.get and mod.options:get("hoenn_jirachi_finale")
    return value~=false end
  local function persistent(save,create)if type(save)~="table"then return nil end
    if type(save.modData)~="table"then if not create then return nil end;save.modData={}end
    local b=save.modData[mod.id];if type(b)~="table"then if not create then return nil end;b={};save.modData[mod.id]=b end
    if type(b.hevo_persistent)~="table"then if not create then return nil end;b.hevo_persistent={}end
    local p=b.hevo_persistent;if type(p.secretUnlocks)~="table"then if not create then return p end;p.secretUnlocks={}end
    return p end
  local function profileCaught()local ok,p=pcall(journey.profile)
    return ok and type(p)=="table"and type(p.secretUnlocks)=="table"and p.secretUnlocks[J.FLAG]==true end
  function J.caught(game)local p=persistent(game and game.save,false)
    return p and p.secretUnlocks and p.secretUnlocks[J.FLAG]==true or profileCaught()or false end
  function J.available(game)return option(game)and dex.report(game).jirachiDexReady==true end
  local function show(game,text,done,boxOpts)game.stack:push(
    require("src.render.TextBox").new(game,text,done,boxOpts));return true end
  local Certificate={};Certificate.__index=Certificate;Certificate.isOpaque=true
  function Certificate.new(game,done)return setmetatable({game=game,done=done},Certificate)end
  function Certificate:update()local input=self.game.input
    if input and(input:wasPressed("a")or input:wasPressed("b"))then
      self.game.stack:pop();if self.done then self.done()end end end
  function Certificate:draw()local Font=require("src.render.Font");local g=love.graphics
    g.setColor(1,1,1,1);g.rectangle("fill",0,0,160,144);g.setColor(.72,.46,.04,1)
    g.rectangle("line",2.5,2.5,155,139);g.rectangle("line",5.5,5.5,149,133)
    g.setColor(0,0,0,1);Font.draw(tr("HOENN ASCENDANT","HOENN-ASZENDENT"),16,16)
    Font.draw(tr("TRAINER","TRAINER"),16,36);Font.draw(self.game.save.player.name or"RED",80,36)
    -- The voyage unlocks after the 134 non-Jirachi Hoenn species.  The
    -- certificate is shown only after Jirachi itself has been recorded, so
    -- its public completion count is the full National-Dex span #252-386:
    -- 135 species.  Keep the prerequisite count out of the reward screen.
    Font.draw(tr("ALL 135 HOENN","ALLE 135 HOENN-"),16,60)
    Font.draw(tr("SPECIES ARE YOURS","ARTEN GEHÖREN DIR"),16,72)
    Font.draw(tr("WISH FULFILLED","WUNSCH ERFÜLLT"),16,84)
    Font.draw("HOENN 135/135",24,108);Font.draw("KANTO ASCENDANT",32,124)
    g.setColor(1,1,1,1)end
  function J.openCertificate(game,done)game.stack:push(Certificate.new(game,done));return true end
  local function writeSave(game)return not game or type(game.writeSave)~="function"or game:writeSave()end
  local function warp(game,mapId,p)if mod.world and type(mod.world.warpTo)=="function"then
      local ok=mod.world:warpTo(mapId,p.x,p.y,p.facing);if ok then return true end end
    local ow=game and game.overworld;if not(ow and type(ow.startWarpTo)=="function")then return false end
    ow:startWarpTo(mapId,p.x,p.y,p.facing);return true end
  function J.enter(game)if not J.available(game)then return false,"unavailable"end;writeSave(game);if opts.accessReturn then opts.accessReturn.clear(game.save)end;return warp(game,J.MAP,J.ENTRY)end
  function J.leave(game)
    local back=opts.accessReturn and opts.accessReturn.point(game.save,J.MAP)
    local target=back or J.RETURN;local ok=warp(game,target.map,target)
    if ok and back then opts.accessReturn.clear(game.save)end
    return ok
  end
  local function fallback(game,ow,npc,done)if type(originalCaptain)=="function"then return originalCaptain(game,ow,npc,done)end
    if done then done()end;return false end
  function J.captainTalk(game,ow,npc,done)if not J.available(game)then return fallback(game,ow,npc,done)end
    if J.caught(game)then return show(game,tr("CAPTAIN: Your Hoenn certificate is ready.",
      "KAPITÄN: Dein Hoenn-Zertifikat ist bereit."),function()J.openCertificate(game,done)end)end
    return show(game,tr("CAPTAIN: The complete Hoenn record reveals a wish beyond Birth Island.\fSail now?",
      "KAPITÄN: Das vollständige Hoenn-Archiv zeigt einen Wunsch jenseits der Entstehungsinsel.\fJetzt segeln?"),nil,
      {defaultNo=true,choice=function(yes)if yes then J.enter(game)elseif done then done()end end})end
  local function stored(save,mon)for _,m in ipairs(save and save.party or{})do if m==mon then return true end end
    for _,box in ipairs(save and save.boxes or{})do for _,m in ipairs(box)do if m==mon then return true end end end;return false end
  function J.recordCatch(game,mon)if not(game and game.save and stored(game.save,mon))then return false,"not-stored"end
    local p=persistent(game.save,true);if p.secretUnlocks[J.FLAG]==true then return false,"recorded"end
    p.secretUnlocks[J.FLAG]=true;dex.record(game,"JIRACHI");pcall(journey.syncHevoPersistent,game.save)
    local s=state();s.caught={map=J.MAP,level=tonumber(mon.level)or J.LEVEL};s.certificate=true;persist(s);writeSave(game)
    return true,s.caught end
  function J.challenge(game,ow,npc,done)if J.caught(game)then return show(game,tr("The wish has been granted.",
      "Der Wunsch wurde erfüllt."),function()J.openCertificate(game,done)end)end
    local function start()local BattleState=opts.battleState or require("src.battle.BattleState")
      local battle=BattleState.newWild(game,"JIRACHI",J.LEVEL,{encounterSource="jirachi_wish",randomizerProtected=true})
      battle.kaJirachiFinale=true;battle.onFinish=function(result)local captured=false
        if result=="caught"then captured=J.recordCatch(game,battle.enemy and battle.enemy.mon)==true end
        if ow and type(ow.afterBattle)=="function"then ow:afterBattle(result,battle)end
        if captured then J.openCertificate(game,done)elseif done then done()end end
      if ow and type(ow.pushBattle)=="function"then ow:pushBattle(battle)elseif done then done()end end
    return show(game,tr("A millennium wish awakens JIRACHI!","Ein Jahrtausendwunsch erweckt JIRACHI!"),start)end
  local function blocks()local w,h,wall,floor,glint=8,8,125,25,21;local o={};for i=1,w*h do o[i]=wall end
    local function put(x,y,v)o[x+y*w+1]=v end;for y=2,6 do for x=2,5 do put(x,y,floor)end end
    for _,p in ipairs({{3,2},{4,2},{2,3},{5,3},{3,4},{4,4}})do put(p[1],p[2],glint)end;return o end
  function J.register()if J.registered then return false,"already-registered"end;local tilesets=mod.content.tilesets
    if tilesets and type(tilesets.get)=="function"and not tilesets:get("CAVERN")then J.registered,J.skipped=true,"missing-cavern";return true,J.skipped end
    assert(not mod.content.maps:get(J.MAP),"duplicate wish chamber")
    for id,def in mod.content.maps:each()do assert(not(def and def.index==J.INDEX),"duplicate wish index "..tostring(id))end
    mod.content.maps:register(J.MAP,{id=J.MAP,index=J.INDEX,label=tr("WISH CHAMBER","WUNSCHKAMMER"),
      tileset="CAVERN",width=8,height=8,borderBlock=125,blocks=blocks(),warps={},signs={},connections={},outdoor=false,
      voxelMode="FULL",voxelRevision=1,objects={{index=1,name="KA_HOENN_JIRACHI",sprite="SPRITE_FAIRY",x=8,y=4,
        movement="STAY",range="DOWN",text=J.JIRACHI_TEXT,passable=false},{index=2,name="KA_HOENN_JIRACHI_RETURN",
        sprite="SPRITE_SAILOR",x=8,y=13,movement="STAY",range="UP",text=J.RETURN_TEXT,passable=false}}})
    mod.content.encounters:register(J.MAP,{grass={rate=0,slots={}}});if mod.content.map_songs then
      mod.content.map_songs:register(J.MAP,"Music_Dungeon1")end
    mod.content.text:register(J.JIRACHI_TEXT,"A wish is waiting.");mod.content.text:register(J.RETURN_TEXT,"Return to Vermilion?")
    mod.content.text_pointers:patch("???",{[J.JIRACHI_TEXT]={text=J.JIRACHI_TEXT},[J.RETURN_TEXT]={text=J.RETURN_TEXT}})
    mod.content.map_scripts:register(J.MAP,{priority=3420,talk={
      [J.JIRACHI_TEXT]=function(game,ow,npc,done)return J.challenge(game,ow,npc,done)end,
      [J.RETURN_TEXT]=function(game,_,_,done)return show(game,tr("Return through the entrance?","Durch den Eingang zurückkehren?"),nil,
        {defaultNo=true,choice=function(yes)if yes then J.leave(game)elseif done then done()end end})end}})
    if mod.content.screens then mod.content.screens:register("HoennCompletionCertificate",{
      new=function(game,args)return Certificate.new(game,args and args.onDone)end})end
    J.registered=true;return true end
  function J.secureSave(save)local p=save and save.player;if not(type(p)=="table"and p.map==J.MAP)then return false end
    local back=opts.accessReturn and opts.accessReturn.point(save,J.MAP)or J.RETURN
    p.map,p.x,p.y,p.facing=back.map,back.x,back.y,back.facing;p.surfing=false;return true end
  function J.install(game,deps)activeGame=game or activeGame;deps=deps or{};opts.battleState=deps.battleState or opts.battleState
    mapScripts=deps.mapScripts or mapScripts or require("data.scripts.init");local map=mapScripts.get and mapScripts.get(J.CAPTAIN_MAP)
    if map and type(map.talk)=="table"and map.talk[J.CAPTAIN_TEXT]~=J.captainTalk then
      originalCaptain=originalCaptain or map.talk[J.CAPTAIN_TEXT];map.talk[J.CAPTAIN_TEXT]=J.captainTalk end;state();return true end
  if mod.events and type(mod.events.on)=="function"then mod.events:on("save.writing",function(ev)
      J.secureSave(ev and ev.save or activeGame and activeGame.save)end,4240)
    for _,event in ipairs({"save.loaded","game.ready"})do mod.events:on(event,function(ev)local game=ev and ev.game or activeGame
      if game then J.install(game,{mapScripts=mapScripts})end end,4240)end end
  J.Certificate=Certificate;return J
end
