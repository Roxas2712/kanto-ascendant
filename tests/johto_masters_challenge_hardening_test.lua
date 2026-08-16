-- Focused fail-closed contracts for the timed Johto Masters knowledge trial.
-- No LÖVE process, renderer, save file or engine tree is touched.

local engine=assert(os.getenv("GEN1RECOMP_DIR"))
package.path=engine.."/?.lua;"..engine.."/?/init.lua;"..package.path

local function equal(actual,expected,message)
  assert(actual==expected,(message or "values differ")..": expected "
    ..tostring(expected)..", got "..tostring(actual))
end
local function cloneArray(value)
  local out={};for index,item in ipairs(value or {}) do out[index]=item end
  return out
end
local function ids(value)return table.concat(value or {},",")end

local make=assert(loadfile("johto_masters_passages.lua"))()
local layout={width=1,height=1,blocks={1}}
local function tilesetFactory()
  return {
    ids={radio_tower="RADIO",ruins_of_alph="ALPH",tower="TOWER",
      champions_room="CHAMPION",silver_signal_v9="SILVER_V9",
      kris_archive_v9="KRIS_V9"},
    layout=function()return layout end,register=function()end,
  }
end

local saved={
  activeRun=true,runSerial=11,challengeAttempt=0,
  passages={
    silver={status="entered",step=0,puzzle=false},
    kris={status="locked",step=0,puzzle=false},
    gold={status="locked",step=0,puzzle=false},
  },
}
local persisted=0
local baseline={
  state=function()return saved end,
  syncCadence=function()return saved end,
  persist=function()persisted=persisted+1;return true end,
  eligible=function()return true end,
  teamFor=function(key)return {{species=key:upper(),level=100}} end,
  trainerFor=function(key)return {name={en=key:upper(),de=key:upper()}} end,
  megaTargetFor=function(key)return key:upper() end,
  secretFormFor=function()end,
}
local postgame={newForcedBattle=function()
  return {trainer={}}
end}
local currentMap="KA_JOHTO_SILVER_PASSAGE"
local warps={}
local eventHandlers={}
local pushed={}
local pressed
local game={
  save={inventory={POTION=2},money=100,player={name="RED"},party={}},
  data={items={POTION={name="POTION"}}},
  input={wasPressed=function(_,key)return key==pressed end},
  stack={
    push=function(_,screen)pushed[#pushed+1]=screen end,
    pop=function()return table.remove(pushed)end,
    top=function()return pushed[#pushed]end,
  },
}
local mod={
  id="kanto_ascendant",path=".",
  save={get=function()return saved end,set=function()persisted=persisted+1 end},
  world={
    overworld=function()return {map={id=currentMap}} end,
    warpTo=function(_,mapId,x,y,facing)
      warps[#warps+1]={mapId,x,y,facing};currentMap=mapId;return true
    end,
  },
  events={on=function(_,name,callback)eventHandlers[name]=callback end},
}

-- Controlled item modules make a blocked call visibly destructive if the
-- Johto guard ever delegates by mistake.
package.preload["src.ui.BagMenu"]=function()
  return {new=function(menuGame)
    return {
      items={{label="POTION",value="POTION"}},index=1,
      onChoose=function()
        menuGame.save.inventory.POTION=menuGame.save.inventory.POTION-1
      end,
      onSelectKey=function()menuGame.save.bagOrderChanged=true end,
      onStartKey=function()menuGame.save.bagOrderChanged=true end,
    }
  end}
end
package.preload["src.inventory.ItemEffects"]=function()
  return {use=function(_,_,_,target)
    target.hp=target.hp+20;return "consumed",{"USED"}
  end}
end
package.preload["src.render.TextBox"]=function()
  return {new=function(_,text,done)return {text=text,done=done}end}
end

local language="en"
mod.ui={ListMenu={new=function(_,title,items,menuOpts)
  return {title=title,items=items,index=1,update=function()end,
    onChoose=menuOpts.onChoose,onCancel=menuOpts.onCancel}
end}}
local i18n={text=function(en,de)return language=="de" and de or en end}
local questionUi=assert(loadfile("ascendant_ui.lua"))()(mod,{i18n=i18n})
local p=make(mod,{baseline=baseline,postgame=postgame,
  contentEnabled=true,tilesetFactory=tilesetFactory,
  i18n=i18n,questionUi=questionUi})
local Font=require("src.render.Font")
for key,bank in pairs(p.questionBanks) do for _,question in ipairs(bank) do
  for _,answer in ipairs(question.answers) do
    assert(#Font.split(answer.en)*8<=144,key.." EN answer clips: "..answer.en)
    assert(#Font.split(answer.de)*8<=144,key.." DE answer clips: "..answer.de)
  end
end end

-- Fifteen disjoint questions per Master, deterministic for one seed and
-- materially different across seeds.
local globalQuestionIds={}
for _,key in ipairs({"silver","kris","gold"}) do
  local complete=p.quizIdsForSeed(key,1337,99)
  equal(#complete,15,key.." question bank is not large enough")
  local seen={};for _,id in ipairs(complete) do
    assert(not seen[id],key.." bank repeats "..id);seen[id]=true
    assert(not globalQuestionIds[id],"question banks overlap at "..id)
    globalQuestionIds[id]=key
  end
  local a=p.quizIdsForSeed(key,41,3)
  local again=p.quizIdsForSeed(key,41,3)
  local b=p.quizIdsForSeed(key,42,3)
  equal(ids(a),ids(again),key.." seed is not deterministic")
  assert(ids(a)~=ids(b),key.." adjacent seeds produce the same quiz order")
end

-- Save/reload retains IDs, answer order and the already solved stage.
local ok,selected=p.inspect(game,"silver")
assert(ok and #selected==3,"Silver quiz was not initialised")
local first=assert(p.question(game,"silver",1))
local beforeChoices=ids(first.choices)
assert(p.answer(game,"silver",1,first.id,first.correct))
equal(saved.passages.silver.step,1,"first correct stage was not persisted")
local reloaded=make(mod,{baseline=baseline,postgame=postgame,
  contentEnabled=true,tilesetFactory=tilesetFactory,
  i18n=i18n,questionUi=questionUi})
local reloadOk,reloadIds=reloaded.inspect(game,"silver")
assert(reloadOk,"reloaded Silver quiz is locked")
equal(ids(reloadIds),ids(selected),
  "save reload rerolled the selected question IDs")
local second=assert(reloaded.question(game,"silver",2))
assert(second.id==selected[2],"save reload lost the next stage")
local solvedFirst=saved.passages.silver.quizSolved[1]
assert(solvedFirst==true and beforeChoices~="","save reload lost answer progress")

-- Complete all three stations on the reloaded controller.
for station=2,3 do
  local question=assert(reloaded.question(game,"silver",station))
  local right,result,progress=reloaded.answer(
    game,"silver",station,question.id,question.correct)
  assert(right and progress==station,
    "correct answer did not advance exactly one stage")
  equal(result,station==3 and "complete" or "correct",
    "successful stage result")
end
assert(saved.passages.silver.puzzle and saved.passages.silver.step==3,
  "three successful stages did not open the battle portal")

-- A wrong Kris answer erases Silver and every partial quiz, records a stable
-- receipt, and the German failure screen owns the one Indigo warp.
saved.passages.silver.status="cleared"
saved.passages.kris.status="entered"
saved.passages.kris.step=0;saved.passages.kris.puzzle=false
saved.passages.kris.quizIds=nil;saved.passages.kris.quizSolved={}
local krisQuestion=assert(reloaded.question(game,"kris",1))
local wrong=krisQuestion.correct%3+1
local right,reason,progress=reloaded.answer(
  game,"kris",1,krisQuestion.id,wrong)
assert(not right and reason=="wrong" and progress==0,
  "wrong answer did not fail closed")
equal(saved.passages.silver.status,"unlocked","wrong answer kept Silver clear")
equal(saved.passages.kris.status,"locked","wrong answer kept Kris progress")
equal(saved.passages.gold.status,"locked","wrong answer kept Gold progress")
equal(saved.lastChallengeReset.reason,"wrong_answer","wrong reset receipt")
language="de";local warpCount=#warps
reloaded.rejectToIndigo(game,"kris","wrong_answer",true)
local rejection=assert(pushed[#pushed],"failure screen missing")
assert(rejection.text:find("NICHT WÜRDIG",1,true),
  "failure screen lacks NICHT WÜRDIG")
equal(#warps,warpCount,"failure warped before its message was acknowledged")
rejection.done();equal(warps[#warps][1],"INDIGO_PLATEAU_LOBBY",
  "wrong answer did not warp to Indigo Plateau")
reloaded.onMapTransition(game,"KA_JOHTO_KRIS_PASSAGE",
  "INDIGO_PLATEAU_LOBBY") -- consume the explicit-warp suppression receipt
language="en"

-- The complete question is retained on the answer screen.  At 19.99 seconds
-- input remains live; at exactly 20 seconds timeout wins and fires once.
local baseUpdates,timeouts=0,0
local timedMenu={items={{label="A"},{label="B"},{label="C"}},index=1,
  update=function()baseUpdates=baseUpdates+1 end,
  close=function(self)self.closed=true end}
reloaded.armQuizMenu(game,timedMenu,{title="JOHTO TEST 1/3",
  prompt="Which complete Johto question is visible above these answers?",
  onTimeout=function()timeouts=timeouts+1 end})
assert(timedMenu.johtoPromptVisible and timedMenu.johtoCountdownVisible
  and timedMenu.johtoPrompt:find("visible above",1,true),
  "answer menu does not retain the complete question")
equal(timedMenu.kascQuestionStyle,"firered-question",
  "Johto League trial must retain its Ascendant question presentation")
equal(timedMenu.__kantoAscendantStyle,"firered-question",
  "Johto League question screen lost the Ascendant skin marker")
timedMenu:update(19.99)
assert(not timedMenu.johtoResolved and timedMenu.johtoRemaining>0
  and baseUpdates==1 and timeouts==0,
  "19.99 seconds incorrectly timed out")
local exactMenu={items=cloneArray(timedMenu.items),index=1,
  close=function(self)self.closed=true end}
reloaded.armQuizMenu(game,exactMenu,{title="JOHTO TEST 1/3",
  prompt="Exact boundary",onTimeout=function()timeouts=timeouts+1 end})
exactMenu:update(20)
assert(exactMenu.johtoResolved and exactMenu.closed
  and exactMenu.johtoRemaining==0 and timeouts==1,
  "exactly 20 seconds did not time out once")
exactMenu:update(1);equal(timeouts,1,"resolved timer fired twice")

-- B is not a route out of the answer phase. It leaves the menu, Johto state
-- and Indigo position untouched at five seconds; the same live timer then
-- reaches the ordinary timeout/reset/warp path at twenty seconds.
saved.activeRun=true;saved.passages.silver.status="cleared"
saved.passages.kris.status="entered";saved.passages.kris.step=1
saved.passages.kris.puzzle=false;saved.passages.gold.status="locked"
currentMap="KA_JOHTO_KRIS_PASSAGE"
local bResetBefore=saved.challengeResets or 0
local bWarpBefore=#warps
local bPushBefore=#pushed
local bTimeouts=0
local nativeBCancels=0
local bMenu={items=cloneArray(timedMenu.items),index=1,
  update=function(self)
    if game.input:wasPressed("b") then
      nativeBCancels=nativeBCancels+1;self.closed=true
    end
  end,
  close=function(self)self.closed=true end}
reloaded.armQuizMenu(game,bMenu,{title="JOHTO TEST 2/3",
  prompt="B cannot abandon this timed question.",onTimeout=function()
    bTimeouts=bTimeouts+1
    reloaded.rejectToIndigo(game,"kris","timeout",false)
  end})
pressed="b";bMenu:update(5);pressed=nil
assert(not bMenu.closed and not bMenu.johtoResolved
    and bMenu.johtoRemaining==15 and bTimeouts==0 and nativeBCancels==0,
  "B closed, resolved or paused the Johto question")
assert((saved.challengeResets or 0)==bResetBefore and #warps==bWarpBefore
    and #pushed==bPushBefore and saved.passages.kris.step==1,
  "B reset/warped Johto or dispatched its failure callback")
bMenu:update(15)
assert(bMenu.closed and bMenu.johtoResolved and bMenu.johtoRemaining==0
    and bTimeouts==1 and saved.lastChallengeReset.reason=="timeout"
    and (saved.challengeResets or 0)==bResetBefore+1,
  "timer after ignored B did not enter the normal Johto timeout path")
local bRejection=assert(pushed[#pushed],"Johto timeout failure screen missing")
equal(#warps,bWarpBefore,"Johto timeout warped before failure acknowledgement")
bRejection.done()
equal(#warps,bWarpBefore+1,"acknowledged Johto timeout did not warp to Indigo")
reloaded.onMapTransition(game,"KA_JOHTO_KRIS_PASSAGE",
  "INDIGO_PLATEAU_LOBBY")

-- Internal map changes preserve progress. Leaving any challenge map before
-- all three clears resets state only; it never initiates a recursion warp.
saved.activeRun=true;saved.passages.silver.status="cleared"
saved.passages.kris.status="entered";saved.passages.kris.step=2
saved.passages.kris.puzzle=false;saved.passages.gold.status="locked"
local resetCount=saved.challengeResets
local internal=reloaded.onMapTransition(game,
  "KA_JOHTO_KRIS_PASSAGE","KA_JOHTO_GATE_HALL")
assert(not internal and saved.passages.kris.step==2,
  "internal challenge transition erased progress")
warpCount=#warps
local didReset,receipt=reloaded.onMapTransition(game,
  "KA_JOHTO_GATE_HALL","ROUTE_1")
assert(didReset and receipt.reason=="area_exit",
  "external challenge exit did not create an area-exit receipt")
equal(saved.challengeResets,resetCount+1,"exit reset counter")
equal(saved.passages.silver.status,"unlocked","exit kept Silver clear")
equal(saved.passages.kris.step,0,"exit kept partial Kris quiz")
equal(#warps,warpCount,"event-side exit reset recursively warped")

-- Field Bag, direct/Quick-Select ItemEffects and the battle path are all
-- blocked before mutation. An unrelated route remains outside the policy.
currentMap="KA_JOHTO_GATE_HALL"
reloaded.install(game)
local BagMenu=require("src.ui.BagMenu")
local bag=BagMenu.new(game,{})
assert(bag.__johtoTrialItemsBlocked,"field Bag did not receive Johto guard")
local inventoryBefore=game.save.inventory.POTION
bag.onChoose(bag.items[1],bag)
equal(game.save.inventory.POTION,inventoryBefore,
  "blocked field Bag consumed an item")
bag.onSelectKey(bag.items[1],bag);bag.onStartKey(bag.items[1],bag)
assert(not game.save.bagOrderChanged,"blocked field Bag changed item order")
local ItemEffects=require("src.inventory.ItemEffects")
local target={hp=5}
local result,messages,meta=ItemEffects.use(
  game.data,game.save,"POTION",target,nil)
assert(result=="failed" and target.hp==5
  and meta.johtoTrialItemsBlocked and #messages==1,
  "field ItemEffects bypassed the Johto guard")
currentMap="ROUTE_1"
local battle={johtoPassage=true}
result,messages,meta=ItemEffects.use(
  game.data,game.save,"POTION",target,battle)
assert(result=="failed" and target.hp==5 and meta.johtoTrialItemsBlocked,
  "battle ItemEffects bypassed the Johto guard")
assert(reloaded.itemUseBlocked(game,battle)
  and not reloaded.itemUseBlocked(game,nil),
  "field/battle item policy scope drifted")

assert(persisted>0,"challenge state was never persisted")
print("johto_masters_challenge_hardening_test: PASS")
