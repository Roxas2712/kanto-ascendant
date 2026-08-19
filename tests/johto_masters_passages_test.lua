local engine=assert(os.getenv("GEN1RECOMP_DIR"));package.path=engine.."/?.lua;"..engine.."/?/init.lua;"..package.path
local make=assert(loadfile("johto_masters_passages.lua"))();local makeTilesets=assert(loadfile("johto_masters_tilesets.lua"))();local Data=require("src.core.Data");Data:load();local Map=require("src.world.Map")
local function registry()local t={};return {values=t,register=function(_,id,v)assert(not t[id],"duplicate "..id);t[id]=v end}end
local maps,sprites,trainers,scripts,tilesets=registry(),registry(),registry(),registry(),registry();function tilesets:get(id)return self.values[id] or Data.tilesets[id] end;local saved={clears=7,gifts=3,title=true,pendingGift={species="MEW"},activeRun=false}
local mod={id="kanto_ascendant",path=".",content={maps=maps,sprites=sprites,trainers=trainers,map_scripts=scripts,tilesets=tilesets},save={get=function()return saved end,set=function(_,_,v)saved=v end},world={}};function mod:read(path)local f=assert(io.open(path,"rb"));local raw=f:read("*a");f:close();return raw end
local warped;function mod.world:warpTo(id,x,y,facing)warped={id,x,y,facing};return true end
local eligible=true;local completed=0;local deliveryCalls=0;local authored={silver={name={en="SILVER",de="SILVER"},intro={en="SILVER INTRO",de="SILVER AUFTAKT"},win={en="SILVER LOSS",de="SILVER NIEDERLAGE"}},kris={name={en="KRIS",de="KRIS"},intro={en="KRIS INTRO",de="KRIS AUFTAKT"},win={en="KRIS LOSS",de="KRIS NIEDERLAGE"}},gold={name={en="GOLD",de="GOLD"},intro={en="GOLD INTRO",de="GOLD AUFTAKT"},win={en="GOLD LOSS",de="GOLD NIEDERLAGE"}}};local function resetRun()saved.activeRun=true;for _,key in ipairs({"silver","kris","gold"})do local p=saved.passages and saved.passages[key] or {};saved.passages=saved.passages or {};saved.passages[key]=p;p.status=key=="silver" and "unlocked" or "locked";p.rewarded=false;p.puzzle=false;p.clue=false;p.step=0 end end;local signature={silver="FERALIGATR",kris="MEGANIUM",gold="TYPHLOSION"};local baseline={state=function()return saved end,syncCadence=function()return saved end,eligible=function()return eligible end,beginRun=function()if saved.pendingGift then return false,"gift" end;if saved.activeRun then return true,"resume" end;resetRun();return true,"new" end,trainerFor=function(key)return authored[key] end,teamFor=function(key,attempt)return {{species=signature[key],level=100,moves={"CRUNCH"}}} end,megaTargetFor=function(key)return signature[key] end,secretFormFor=function(key)return key=="gold" and "TYPHLOSION_ASCENDANT" or nil end,completeRun=function()if not saved.activeRun then return "ALREADY",false end;completed=completed+1;saved.activeRun=false;return "GOLD REWARD",true end,deliverGift=function(_,s)deliveryCalls=deliveryCalls+1;s.pendingGift=nil;return "PENDING GIFT",true end}
local lastBattle;local postgame={newForcedBattle=function(_,class,team,tier,context)lastBattle={class=class,team=team,tier=tier,context=context,trainer={}};return lastBattle end}
package.preload["src.render.TextBox"]=function()return {new=function(_,text,done)return {text=text,done=done}end}end
local offMaps,offSprites,offTrainers,offScripts=registry(),registry(),registry(),registry();local offMod={id="kanto_ascendant",path=".",content={maps=offMaps,sprites=offSprites,trainers=offTrainers,map_scripts=offScripts},save=mod.save,world=mod.world};offMod.read=mod.read;local off=make(offMod,{baseline=baseline,postgame=postgame,contentEnabled=false,tilesetFactory=makeTilesets});assert(not off.register() and next(offMaps.values)==nil and next(offSprites.values)==nil and next(offTrainers.values)==nil,"fixture export registers no maps, assets or trainer classes")
local language="en";local i18n={text=function(en,de)return language=="de" and de or en end};local openedMenu
local questionUi=assert(loadfile("ascendant_ui.lua"))()(mod,{i18n=i18n})
local p=make(mod,{baseline=baseline,postgame=postgame,contentEnabled=true,tilesetFactory=makeTilesets,i18n=i18n,questionUi=questionUi,openMenu=function(menuGame,title,rows,menuOpts)openedMenu={game=menuGame,title=title,itemRows=rows,items=rows,index=1,opts=menuOpts,update=function(self)if self.game.input:wasPressed("b") then self.nativeCancelled=true;self.closed=true;if self.opts.onCancel then self.opts.onCancel() end end end,close=function(self)self.closed=true end};return openedMenu end});assert(p.register())
assert(saved.clears==7 and saved.gifts==3 and saved.title and saved.pendingGift.species=="MEW","old reward state survives migration")
local expected={KA_JOHTO_GATE_HALL=1960,KA_JOHTO_SILVER_PASSAGE=1961,KA_JOHTO_SILVER_FINALE=1962,KA_JOHTO_KRIS_PASSAGE=1963,KA_JOHTO_KRIS_FINALE=1964,KA_JOHTO_GOLD_PASSAGE=1965,KA_JOHTO_GOLD_FINALE=1966}
local function reaches(map,sx,sy,tx,ty)local queue,seen={{sx,sy}},{};local head=1;while queue[head] do local p=queue[head];head=head+1;local tag=p[1]..":"..p[2];if not seen[tag] then seen[tag]=true;if p[1]==tx and p[2]==ty then return true end;for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do local x,y=p[1]+d[1],p[2]+d[2];if map:inBounds(x,y) and map:isWalkableCell(x,y) then queue[#queue+1]={x,y} end end end end;return false end
local runtimeById={};for _,spec in pairs(p.MAPS) do runtimeById[spec.id]=spec end
local signatures={};local themed={KA_JOHTO_GATE_HALL="KA_JOHTO_G2_SILVER_SIGNAL_V9",KA_JOHTO_SILVER_PASSAGE="KA_JOHTO_G2_SILVER_SIGNAL_V9",KA_JOHTO_KRIS_PASSAGE="KA_JOHTO_G2_KRIS_ARCHIVE_V9",KA_JOHTO_GOLD_PASSAGE="KA_JOHTO_G2_TOWER"};for id,index in pairs(expected) do local def=assert(maps.values[id]);local runtime=assert(runtimeById[id]);assert(def.index==index and def.voxelMode=="MAP_STUDIO" and def.outdoor==false);assert(#def.blocks==def.width*def.height);if themed[id] then assert(def.tileset==themed[id],id.." must use its Gen-II authority tileset") end;local sig=def.width.."x"..def.height..":"..table.concat(def.blocks,",");assert(not signatures[sig],id.." duplicates a passage layout");signatures[sig]=true;local map=Map.new(def,assert(tilesets.values[def.tileset] or Data.tilesets[def.tileset]));local entryX,entryY=runtime.entryX or 3,runtime.entryY or def.height*2-3;assert(map:isWalkableCell(entryX,entryY),id.." entry collision");local checked=id:find("PASSAGE",1,true) and def.objects or {def.objects[1]};for _,object in ipairs(checked) do local approach,reached=false,false;for _,d in ipairs({{1,0},{-1,0},{0,1},{0,-1}}) do local x,y=object.x+d[1],object.y+d[2];if map:inBounds(x,y) and map:isWalkableCell(x,y) then approach=true;reached=reached or reaches(map,entryX,entryY,x,y) end end;assert(approach,id.." object has no walkable approach: "..object.name);assert(reached,id.." input route missing: "..object.name) end end
assert(sprites.values.SPRITE_KA_JOHTO_SILVER and sprites.values.SPRITE_KA_JOHTO_KRIS and sprites.values.SPRITE_KA_JOHTO_GOLD,"own field sprites")
for _,id in ipairs({"KA_JOHTO_SILVER","KA_JOHTO_KRIS","KA_JOHTO_GOLD"}) do local t=assert(trainers.values[id]);assert(t.baseMoney==0 and t.trueColor and t.pic:find("battle/",1,true),"own no-prize trainer "..id);assert(t.battleTheme=="Music_KA_GSC_RivalBattle",id.." owns the source-bound GSC Rival battle theme")end
assert(trainers.values.KA_JOHTO_GOLD.pic:find("gold_front_color_v1.png",1,true),"Gold uses the new coloured front without overwriting the grayscale source")
local publicData=assert(loadfile("johto_masters_data.lua"))();for _,row in ipairs(publicData.trainers) do assert(row.class=="KA_JOHTO_"..row.key:upper(),"latent Johto trainer data must never alias a Kanto class") end
assert(maps.values.KA_JOHTO_SILVER_FINALE.objects[1].sprite=="SPRITE_KA_JOHTO_SILVER" and maps.values.KA_JOHTO_KRIS_FINALE.objects[1].sprite=="SPRITE_KA_JOHTO_KRIS" and maps.values.KA_JOHTO_GOLD_FINALE.objects[1].sprite=="SPRITE_KA_JOHTO_GOLD","finales use individual overworld identities")
for _,id in ipairs({"KA_JOHTO_SILVER_FINALE","KA_JOHTO_KRIS_FINALE","KA_JOHTO_GOLD_FINALE"}) do local objects=maps.values[id].objects;assert(#objects==1,id.." owns exactly one visible Master object") end
for _,key in ipairs({"SILVER","KRIS","GOLD"}) do
  local id="KA_JOHTO_"..key.."_PASSAGE";local def=maps.values[id]
  assert(#def.objects==1 and def.objects[1].name=="KA_JOHTO_"..key.."_QUIZ_HOST",
    id.." must contain one visible character, not repeated trainer markers")
  local runtime=runtimeById[id]
  local room=Map.new(def,assert(tilesets.values[def.tileset] or Data.tilesets[def.tileset]))
  assert(room:isWalkableCell(def.objects[1].x,def.objects[1].y),id.." quiz host clips into a wall")
  assert(#def.signs==1 and def.signs[1].text=="TEXT_KA_JOHTO_"..key.."_EXIT",
    id.." needs a labelled exit sign")
  assert(room:isWalkableCell(8,runtime.h*2-2) and room:isWalkableCell(9,runtime.h*2-2),
    id.." visible double exit plate is not walkable")
end
local allowedGold={[1]=true,[9]=true,[40]=true,[41]=true}
for _,value in ipairs(maps.values.KA_JOHTO_GOLD_PASSAGE.blocks) do
  assert(allowedGold[value],"Gold compact room leaked a repeated Tin Tower stair block: "..tostring(value))
end
local hall=maps.values.KA_JOHTO_GATE_HALL
assert(#hall.warps==3 and hall.warps[1].destMap=="INDIGO_PLATEAU_LOBBY" and hall.warps[2].destMap=="INDIGO_PLATEAU_LOBBY" and hall.warps[3].destMap=="INDIGO_PLATEAU_LOBBY","Gate Hall has two central exits plus an old-save rescue exit to the real Indigo lobby")
assert(p.MAPS.HALL.entryX==9 and p.MAPS.HALL.entryY==19,"new Hall entries use the compact central chamber")
assert(#hall.objects==3 and hall.objects[1].x==5 and hall.objects[2].x==9
  and hall.objects[3].x==13 and hall.objects[1].y==15
  and hall.objects[2].y==15 and hall.objects[3].y==15,
  "three Johto gates form one visible Silver/Kris/Gold row near the compact entry")
assert(#hall.signs==1 and hall.signs[1].text=="TEXT_KA_JOHTO_HALL_EXIT"
  and hall.signs[1].x==10 and hall.signs[1].y==22,
  "Gate Hall exit must be explicitly labelled beside its glowing plate")
local hallOnStep=assert(scripts.values.KA_JOHTO_GATE_HALL.onStep,
  "Gate Hall needs a real exit step handler on its non-warp floor")
warped=nil
assert(not hallOnStep({},nil,9,20) and warped==nil,
  "Gate Hall exit fires before the visible threshold")
assert(hallOnStep({},nil,9,21) and warped[1]=="INDIGO_PLATEAU_LOBBY"
  and warped[2]==7 and warped[3]==10 and warped[4]=="up",
  "Gate Hall central threshold does not leave for the Indigo lobby")
warped=nil
assert(hallOnStep({},nil,1,p.MAPS.HALL.h*2-3)
  and warped[1]=="INDIGO_PLATEAU_LOBBY",
  "old-save lower-left rescue threshold is not recoverable")
for _,key in ipairs({"SILVER","KRIS","GOLD"}) do
  local id="KA_JOHTO_"..key.."_PASSAGE";local handler=assert(scripts.values[id].onStep)
  warped=nil;assert(not handler({},nil,9,p.MAPS[key.."_PASSAGE"].h*2-3) and warped==nil,
    id.." exits before the glowing threshold")
  assert(handler({},nil,9,p.MAPS[key.."_PASSAGE"].h*2-2)
      and warped[1]=="KA_JOHTO_GATE_HALL" and warped[2]==9 and warped[3]==19,
    id.." visible exit does not return to the Gate Hall")
end
local hostBox;local hostGame={stack={push=function(_,v)hostBox=v end}};local hostNpc={frozen=false,facePlayer=function(self)self.faced=true end};local hostOw={player={}};assert(p.hostTalk(hostGame,hostOw,hostNpc));assert(deliveryCalls==1 and hostBox.text=="PENDING GIFT" and hostNpc.faced,"host recovers a pending exact-once gift before escort");hostBox.done();assert(warped[1]=="KA_JOHTO_GATE_HALL" and not hostNpc.frozen,"successful pending recovery continues through the physical gate");assert(p.hostTalk(hostGame,hostOw,hostNpc));assert(hostBox.text:find("JOHTO HOST:",1,true)
  and hostBox.text:find("SILVER, KRIS, then GOLD",1,true)
  and hostBox.text:find("20 seconds each",1,true)
  and hostBox.text:find("BAG is sealed",1,true)
  and hostBox.text:find("after defeating GOLD",1,true),
  "host does not explain the ordered paths, timing, Bag seal and Gold reward");hostBox.done();assert(warped[1]=="KA_JOHTO_GATE_HALL" and warped[2]==9 and warped[3]==19,"host escort reaches the compact Gate Hall entry")
assert(p.canEnter({},"silver") and not p.canEnter({},"kris") and not p.canEnter({},"gold"),"ordered unlock")
assert(p.enter({},"silver") and warped[1]=="KA_JOHTO_SILVER_PASSAGE","Silver gate warp")
assert(not p.solve({},"silver"),"final seal stays closed until the quiz is solved")
local quizBox;local quizPressed;local quizGame={
  input={wasPressed=function(_,key)return key==quizPressed end},
  stack={push=function(_,value)quizBox=value end}}
local silverQuiz=assert(scripts.values.KA_JOHTO_SILVER_PASSAGE.talk.TEXT_KA_JOHTO_SILVER_QUIZ)
silverQuiz(quizGame);assert(quizBox.text:find("SILVER'S SIGNAL TEST",1,true)
  and quizBox.text:find("20 seconds",1,true)
  and quizBox.text:find("resets all three trials",1,true),
  "Silver quiz does not explain its logic before asking")
quizBox.done();assert(quizBox.text:find("QUESTION 1/3",1,true),"quiz prompt lacks station progress")
quizBox.done();assert(openedMenu.title:find("1/3",1,true) and #openedMenu.itemRows==3,
  "quiz answer menu lacks station/three-choice labels")
assert(openedMenu.johtoPromptVisible and openedMenu.johtoPrompt==quizBox.text:match("\n(.+)$")
  and openedMenu.johtoCountdownVisible and openedMenu.johtoRemaining==20,
  "quiz answer menu must repeat the complete prompt above answers and show 20 seconds")
local quizStep=saved.passages.silver.step;local quizWarp=warped
quizPressed="b";openedMenu:update(5);quizPressed=nil
assert(not openedMenu.johtoResolved and openedMenu.johtoRemaining==15
    and not openedMenu.closed and saved.passages.silver.step==quizStep
    and not openedMenu.nativeCancelled and warped==quizWarp
    and openedMenu.opts.onCancel==nil,
  "B must stay inside the Johto question without reset, warp or cancel callback")
local allQuestionIds={}
local function solveQuiz(key,checkWrong)
  local ok,ids=p.inspect({},key);assert(ok and #ids==3,key.." must select three questions")
  local _,reloadIds=p.inspect({},key);assert(table.concat(ids,",")==table.concat(reloadIds,","),key.." quiz rerolled after reload")
  if checkWrong then
    local failedIds=table.concat(ids,",")
    local question=assert(p.question({},key,1))
    local wrong=question.correct%3+1
    local right,reason,progress,label=p.answer({},key,1,question.id,wrong)
    assert(not right and reason=="wrong" and progress==0 and label==question.correctLabel,
      key.." wrong-answer feedback contract")
    assert(saved.passages.silver.status=="unlocked"
      and saved.passages.kris.status=="locked"
      and saved.passages.gold.status=="locked"
      and saved.passages.silver.step==0
      and saved.passages[key].resets==1
      and saved.lastChallengeReset.reason=="wrong_answer",
      key.." wrong answer did not reset the complete three-trainer run")
    assert(p.enter({},key),key.." retry cannot re-enter its reset passage")
    ok,ids=p.inspect({},key);assert(ok and #ids==3,key.." retry quiz missing")
    assert(table.concat(ids,",")~=failedIds,
      key.." failed attempt reused the memorised question order")
    local _,retryReload=p.inspect({},key)
    assert(table.concat(ids,",")==table.concat(retryReload,","),
      key.." retry quiz is not save/reload stable")
  end
  for _,id in ipairs(ids) do assert(not allQuestionIds[id],"duplicate question in connected run: "..id);allQuestionIds[id]=true end
  for station=1,3 do
    local question=assert(p.question({},key,station))
    assert(question.station==station and question.prompt~="" and #question.choices==3,
      key.." station lacks prompt/three choices")
    if key=="silver" and station==1 then
      local english=question.prompt;language="de";local german=assert(p.question({},key,station));language="en"
      assert(german.id==question.id and german.prompt~=english and german.prompt~="",
        "Silver question does not have stable, meaningful DE/EN wording")
    end
    if station==1 then assert(not p.question({},key,2),key.." unlocked station 2 before station 1") end
    local right,result,progress=p.answer({},key,station,question.id,question.correct)
    assert(right and progress==station and result==(station==3 and "complete" or "correct"),
      key.." correct answer did not unlock exactly one station")
  end
  assert(saved.passages[key].step==3 and saved.passages[key].puzzle,key.." quiz did not open the portal")
end
solveQuiz("silver",true)
assert(p.solve({},"silver") and warped[1]=="KA_JOHTO_SILVER_FINALE","three answers advance to Silver finale")
local game={stack={push=function()end},save={money=123}};local afterCalls=0;local ow={afterBattle=function()afterCalls=afterCalls+1 end,pushBattle=function(_,b)lastBattle=b end};local npc={frozen=false};local started,startReason=p.startBattle(game,ow,npc,"silver");assert(started,"Silver battle failed: "..tostring(startReason).." status="..tostring(saved.passages.silver.status).." step="..tostring(saved.passages.silver.step).." puzzle="..tostring(saved.passages.silver.puzzle).." attempt="..tostring(saved.challengeAttempt).." quizAttempt="..tostring(saved.passages.silver.quizAttempt));assert(lastBattle.class=="KA_JOHTO_SILVER" and lastBattle.johtoPassage and lastBattle.noPrizeMoney and lastBattle.postgameTier==nil and lastBattle.postgameForcedTier==nil,"isolated no-prize Silver context");assert(lastBattle.trainer.id=="KA_JOHTO_SILVER" and lastBattle.trainer.baseMoney==0 and lastBattle.introText=="SILVER INTRO" and lastBattle.endBattleText=="SILVER LOSS" and #lastBattle.enemyAIMods==3,"Silver battle owns its class, phase-correct dialogue, AI and engine-effective zero-money record");lastBattle.onFinish("lose");assert(game.save.money==123 and afterCalls==0,"loss receives no prize or global blackout");assert(saved.passages.silver.status=="entered","loss preserves retry state");assert(p.solve({},"silver"));assert(p.startBattle(game,ow,npc,"silver"));lastBattle.onFinish("win");assert(game.save.money==123 and afterCalls==1,"win receives no prize and finishes normally");assert(saved.passages.silver.status=="cleared" and p.canEnter({},"kris"),"Silver clear unlocks Kris")
for _,key in ipairs({"kris","gold"}) do assert(p.enter({},key));solveQuiz(key,false);assert(p.solve({},key));assert(p.startBattle(game,ow,npc,key));assert(lastBattle.class=="KA_JOHTO_"..key:upper() and lastBattle.noPrizeMoney);assert(lastBattle.ascendantEnemyMegaSpecies==signature[key],key.." owns its Johto starter transformation target");assert(lastBattle.ascendantEnemySecretForm==(key=="gold" and "TYPHLOSION_ASCENDANT" or nil),key.." secret form contract");lastBattle.onFinish("win") end
assert(saved.passages.gold.status=="cleared" and completed==1 and not saved.activeRun,"Gold closes one connected run and rewards it exactly once")
assert(not p.enter({},"gold"),"a completed run cannot re-enter Gold without a new Elite-Four ticket");resetRun();assert(p.canEnter({},"silver") and not p.canEnter({},"kris") and not p.canEnter({},"gold"),"the next farm run resets to Silver rather than resurrecting cleared passages")
local function sameCollision(tileset,a,b)local c=tileset.sourceCellCollision;for i=1,4 do assert(c[a+1][i]==c[b+1][i],"visual metatile altered collision: "..a.."/"..b)end end
for _,pair in ipairs({{1,19},{1,20},{1,39},{9,33},{11,22},{23,15}})do sameCollision(tilesets.values.KA_JOHTO_G2_RADIO_TOWER,pair[1],pair[2])end
for _,pair in ipairs({{3,4},{3,13},{3,51},{10,11},{18,21},{18,29},{19,22},{19,30},{17,32},{27,33},{31,34}})do sameCollision(tilesets.values.KA_JOHTO_G2_RUINS_OF_ALPH,pair[1],pair[2])end
eligible=false;saved.passages.silver.status="locked";assert(not p.canEnter({},"silver"),"host gate despawns/locks without eligibility")
print("johto_masters_passages_test: PASS")
