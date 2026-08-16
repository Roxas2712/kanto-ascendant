-- Focused two-stage presentation contract. No app, renderer or disk save.
local engine=assert(os.getenv("GEN1RECOMP_DIR"))
local modDir=os.getenv("KA_HIDDEN_EVOLUTION_MOD") or "."
package.path=engine.."/?.lua;"..engine.."/?/init.lua;"..modDir.."/?.lua;"..package.path

local Data=require("src.core.Data");Data:load()
local Font=require("src.render.Font");Font.load(Data)
for _,title in ipairs({"GROUDON-TEST 1/5","KYOGRE-TEST 1/5",
    "RAYQUAZA-TEST 1/5"}) do
  assert(Font.width(title)<=144,"question title clips: "..title)
end

local function registry(getter)
  local values={}
  return {values=values,register=function(_,id,value)values[id]=value end,
    patch=function()end,get=getter or function(_,id)return values[id]end}
end
local function makeMod()
  local store={}
  local mod={id="kanto_ascendant",path=modDir,content={},world={}}
  mod.save={get=function(_,key)return store[key]end,
    set=function(_,key,value)store[key]=value end}
  mod.content.tilesets=registry(function(_,id)return id=="CAVERN" and {} or nil end)
  for _,name in ipairs({"text","text_pointers","maps","map_songs",
      "encounters","map_scripts","field"}) do mod.content[name]=registry() end
  mod.ui={ListMenu={new=function(game,title,items,options)
    return {game=game,title=title,items=items,index=1,rows=options.rows,
      onChoose=options.onChoose,onCancel=options.onCancel,update=function(self)
        local input=self.game and self.game.input
        if input and input:wasPressed("b") then
          self.game.stack:pop()
          if self.onCancel then self.onCancel() end
        end
      end}
  end}}
  return mod,store
end
local function stack()
  local screens={}
  return screens,{push=function(_,value)screens[#screens+1]=value end,
    pop=function()return table.remove(screens)end,
    top=function()return screens[#screens]end}
end
local function norm(value)
  return tostring(value):gsub("[\n\f]+"," "):gsub("%s+"," ")
    :gsub("^ ",""):gsub(" $","")
end

-- Every expanded catalogue prompt must survive glyph wrapping in EN and DE,
-- with no TextBox page ever showing more than two lines.
do
  local mod=makeMod()
  local ui=assert(loadfile(modDir.."/ascendant_ui.lua"))()(mod,{})
  local red=assert(loadfile(modDir.."/hidden_evolution_red_path.lua"))()(mod,{})
  local blue=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,{})
  local green=assert(loadfile(modDir.."/hidden_evolution_green_grove.lua"))()(mod,{})
  assert(#red.questions==140 and #blue.questions==150 and #green.questions==160,
    "expanded HEVO catalogues must total 450 questions")
  local checked=0
  local function verify(prompt)
    local paginated,pages=ui.paginateQuestionText(prompt)
    assert(norm(paginated)==norm(prompt),"pagination changed semantic prompt: "..prompt)
    for _,page in ipairs(pages) do assert(#page<=2,"question page exceeds two lines") end
    checked=checked+1
  end
  for _,q in ipairs(red.questions) do verify(q.en);verify(q.de) end
  for _,q in ipairs(blue.questions) do verify(q.prompt);verify(q.promptDe or q.prompt) end
  for _,q in ipairs(green.questions) do verify(q.en);verify(q.de) end
  assert(checked==900,"both languages of all 450 prompts must be checked")
end

-- A displayed receipt is authoritative. Losing or replacing pending state
-- fails closed before either controller can consume the catalogue entry.
do
  local mod,store=makeMod()
  local blue=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,{})
  local q=assert(blue.nextQuestion("HALL"))
  blue.state().pending.HALL=nil
  local before=blue.state().questionCursor
  local accepted,reason=blue.answer("HALL",q.id,q.correct)
  assert(not accepted and reason=="pending" and blue.state().questionCursor==before,
    "BLUE missing pending receipt consumed a stale displayed question")

  store.hevo_run={character="GREEN"}
  local save={hevo_run=store.hevo_run}
  local green=assert(loadfile(modDir.."/hidden_evolution_green_grove.lua"))()(mod,{})
  local shown=assert(green.questionFor(save,1))
  local state=store.hevo_run.hidden_evolution_story_campaign.green
  local replacement
  for _,candidate in ipairs(green.questions) do
    if candidate.id~=shown.id then replacement=candidate.id;break end
  end
  state.pending[1]={id=replacement,answerFirst=true}
  local cursor=state.questionCursor
  local ok,why=green.answer(save,1,shown.answer,shown.id)
  assert(not ok and why=="stale" and state.questionCursor==cursor
      and not state.asked[shown.id],
    "GREEN stale question receipt consumed the displayed question")
end

-- Construction/push failures after phase one are closed receipts: the NPC is
-- released exactly once and the pending question is still available.
do
  local mod=makeMod();local done=0
  local brokenUi={
    showQuestionText=function(_,_,after)after();return true end,
    openQuestionMenu=function()return false,"broken" end,
  }
  local blue=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,
    {questionUi=brokenUi,showText=function()error("unexpected feedback")end})
  assert(blue.ask("HALL",{save={}},function()done=done+1 end))
  local state=blue.state();local pending=assert(state.pending.HALL).id
  assert(done==1 and not state.asked[pending],
    "broken question menu consumed pending or left NPC frozen")
end

local function exercise(language,route)
  local mod,store=makeMod()
  local texts={}
  local function showText(_,message,done,meta)
    texts[#texts+1]={message=message,done=done,meta=meta};return true
  end
  local i18n={text=function(en,de)return language=="de" and de or en end}
  local ui=assert(loadfile(modDir.."/ascendant_ui.lua"))()(mod,{i18n=i18n})
  local screens,gameStack=stack();local pressed
  local game={save={hevo_run={character=route}},stack=gameStack,
    input={wasPressed=function(_,key)return key==pressed end}}
  local done=0
  local controller,pending,present,currentPending
  if route=="RED" then
    controller=assert(loadfile(modDir.."/hidden_evolution_red_path.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    controller.register()
    local script=assert(mod.content.map_scripts.values[controller.IDS.upper])
    local talk=assert(script.talk.TEXT_KA_RED_STATUE_1)
    present=function()return talk(game,{map={id=controller.IDS.upper}},
      {def={name="KA_RED_STATUE_1"}},function()done=done+1 end)end
    currentPending=function()return controller.run(game.save,true).pending.KA_RED_STATUE_1 end
  elseif route=="BLUE" then
    controller=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    present=function()return controller.ask("HALL",game,function()done=done+1 end)end
    currentPending=function()
      local row=controller.state().pending.HALL;return row and row.id
    end
  else
    store.hevo_run={character="GREEN"};game.save.hevo_run=store.hevo_run
    controller=assert(loadfile(modDir.."/hidden_evolution_green_grove.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    present=function()return controller.presentQuestion(game,{},1,function()done=done+1 end)end
    currentPending=function()
      local row=store.hevo_run.hidden_evolution_story_campaign.green.pending[1]
      return row and row.id
    end
  end
  assert(present())
  pending=assert(currentPending())
  assert(#texts==1 and texts[1].meta and texts[1].meta.questionPages,
    route.." phase one must be an ordinary paginated TextBox question")
  local semantic=assert(texts[1].meta.semanticPrompt)
  assert(not semantic:find("\nA ",1,true) and not semantic:find("\nB ",1,true),
    route.." phase one leaked answer labels")
  texts[1].done()
  local menu=assert(screens[#screens],route.." answer menu missing")
  assert(menu.kascQuestionPrompt==semantic,route.." menu did not repeat exact question")
  assert(menu.kascQuestionCountdownVisible==true and menu.kascQuestionRemaining==20,
    route.." does not show the full 20-second HEVO timer")
  assert(menu.kascQuestionStyle=="firered-question"
      and menu.__kantoAscendantStyle=="firered-question"
      and menu:sgbPalettes()[1].colors==false,
    route.." does not use the Kanto Ascendant question skin")
  assert(#menu.items==(route=="BLUE" and 3 or 2),route.." answer row count")
  assert(menu.index==(route=="BLUE" and 1 or 2),route.." default cursor")
  local expectedTitle=route=="RED" and "GROUDON" or route=="BLUE" and "KYOGRE" or "RAYQUAZA"
  assert(menu.title:find(expectedTitle,1,true),route.." route title missing")
  if language=="de" then
    if route=="RED" then
      assert(menu.items[1].label=="JA" and menu.items[2].label=="NEIN",
        "RED German answer rows are not localized")
      local q;for _,candidate in ipairs(controller.questions) do
        if candidate.id==pending then q=candidate;break end end
      assert(q and semantic==q.de,"RED German question is not localized")
    elseif route=="BLUE" then
      local q=assert(controller.nextQuestion("HALL"))
      assert(semantic==(q.promptDe or q.prompt),"BLUE German question is not localized")
      local expected=q.choicesDe or q.choices
      for index,label in ipairs(expected) do
        assert(menu.items[index].label==label,"BLUE German answer row mismatch")
      end
    else
      local q=assert(controller.questionFor(game.save,1))
      assert(semantic==q.de,"GREEN German question is not localized")
      if q.kind=="yesno" then
        assert(menu.items[1].label=="JA" and menu.items[2].label=="NEIN",
          "GREEN German answer rows are not localized")
      else
        assert(menu.items[1].label:match("^A %d%d%d$")
          and menu.items[2].label:match("^B %d%d%d$"),
          "GREEN numeric answer rows lost their fixed localized form")
      end
    end
  end
  -- Phase two is modal: B is ignored, leaves the exact pending receipt open,
  -- and does not pause the 20-second countdown.
  pressed="b";menu:update(5);pressed=nil
  assert(screens[#screens]==menu and not menu.kascQuestionResolved,
    route.." B closed or resolved the question menu")
  assert(menu.kascQuestionRemaining==15 and done==0,
    route.." B paused the timer or released the NPC")
  assert(currentPending()==pending,
    route.." B consumed or rerolled the pending question")

  -- A still maps the selected row to the route answer exactly once.
  local correctIndex
  if route=="RED" then
    for _,q in ipairs(controller.questions) do if q.id==pending then
      correctIndex=q.answer and 1 or 2;break end end
  elseif route=="BLUE" then
    correctIndex=assert(controller.state().pending.HALL).correct
  else
    local q=assert(controller.questionFor(game.save,1))
    correctIndex=q.kind=="number" and (q.answerFirst and 1 or 2)
      or (q.answer and 1 or 2)
  end
  assert(correctIndex and menu.items[correctIndex],route.." correct row missing")
  menu.onChoose(menu.items[correctIndex],menu)
  if route=="RED" then
    local feedback=assert(screens[#screens],"RED answer feedback missing")
    table.remove(screens);feedback.onDone()
  else
    assert(texts[2] and texts[2].done,route.." answer feedback missing")
    texts[2].done()
  end
  assert(done==1,route.." answer flow did not finish exactly once")
  assert(currentPending()==nil,route.." accepted answer left pending receipt")
end

for _,language in ipairs({"en","de"}) do
  for _,route in ipairs({"RED","BLUE","GREEN"}) do exercise(language,route) end
end

-- The exact 20-second boundary is a wrong response routed through the same
-- existing answer callback. It consumes only that question, grants no sight,
-- shows normal wrong feedback, and releases the NPC once acknowledged.
for _,route in ipairs({"RED","BLUE","GREEN"}) do
  local mod,store=makeMod();local texts={};local screens,gameStack=stack()
  local function showText(_,message,after,meta)
    texts[#texts+1]={message=message,done=after,meta=meta};return true
  end
  local i18n={text=function(en)return en end}
  local ui=assert(loadfile(modDir.."/ascendant_ui.lua"))()(mod,{i18n=i18n})
  local game={save={hevo_run={character=route}},stack=gameStack};local done=0
  local controller,pending,sight
  if route=="RED" then
    controller=assert(loadfile(modDir.."/hidden_evolution_red_path.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    controller.register()
    local talk=mod.content.map_scripts.values[controller.IDS.upper]
      .talk.TEXT_KA_RED_STATUE_1
    assert(talk(game,{map={id=controller.IDS.upper}},
      {def={name="KA_RED_STATUE_1"}},function()done=done+1 end))
    pending=controller.run(game.save,true).pending.KA_RED_STATUE_1
    sight=function()return controller.run(game.save,true).sight or 0 end
  elseif route=="BLUE" then
    controller=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    assert(controller.ask("HALL",game,function()done=done+1 end))
    pending=controller.state().pending.HALL.id
    sight=function()return controller.state().sight end
  else
    store.hevo_run={character="GREEN"};game.save.hevo_run=store.hevo_run
    controller=assert(loadfile(modDir.."/hidden_evolution_green_grove.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    assert(controller.presentQuestion(game,{},1,function()done=done+1 end))
    local state=store.hevo_run.hidden_evolution_story_campaign.green
    pending=state.pending[1].id;sight=function()return state.sight end
  end
  texts[1].done();local menu=assert(screens[#screens])
  menu:update(19.99)
  assert(menu.kascQuestionRemaining>0 and done==0,
    route.." timed out before the exact boundary")
  assert((route=="RED" and controller.run(game.save,true).pending.KA_RED_STATUE_1
      or route=="BLUE" and controller.state().pending.HALL.id
      or store.hevo_run.hidden_evolution_story_campaign.green.pending[1].id)==pending,
    route.." consumed pending before timeout")
  menu:update(.01)
  assert(menu.kascQuestionResolved and menu.kascQuestionRemaining==0,
    route.." did not resolve at exactly 20 seconds")
  assert(sight()==0,route.." timeout incorrectly granted sight")
  local current
  if route=="RED" then current=controller.run(game.save,true).pending.KA_RED_STATUE_1
  elseif route=="BLUE" then current=controller.state().pending.HALL
  else current=store.hevo_run.hidden_evolution_story_campaign.green.pending[1] end
  assert(current==nil,route.." timeout did not consume the question")
  if route=="RED" then
    local feedback=assert(screens[#screens],"RED timeout feedback missing")
    table.remove(screens);feedback.onDone()
  else
    assert(texts[2] and texts[2].done,route.." timeout feedback missing")
    texts[2].done()
  end
  assert(done==1,route.." timeout path did not finish exactly once")
  menu:update(1);assert(done==1,route.." timeout fired twice")
end

-- The menu receipt accepts only one of its integer row indices. In
-- particular, GREEN's numeric questions keep both offered numbers out of
-- phase one and a fractional synthetic row cannot consume either route.
for _,route in ipairs({"BLUE","GREEN"}) do
  local mod,store=makeMod();local texts={};local screens,gameStack=stack()
  local function showText(_,message,done,meta)
    texts[#texts+1]={message=message,done=done,meta=meta};return true
  end
  local i18n={text=function(en)return en end}
  local ui=assert(loadfile(modDir.."/ascendant_ui.lua"))()(mod,{i18n=i18n})
  local game={save={hevo_run={character=route}},stack=gameStack};local done=0
  local controller,pending
  if route=="BLUE" then
    controller=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    assert(controller.ask("HALL",game,function()done=done+1 end))
    pending=controller.state().pending.HALL.id
  else
    store.hevo_run={character="GREEN"};game.save.hevo_run=store.hevo_run
    controller=assert(loadfile(modDir.."/hidden_evolution_green_grove.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    controller.questionFor(game.save,1)
    local state=store.hevo_run.hidden_evolution_story_campaign.green
    local numeric
    for _,q in ipairs(controller.questions) do if q.kind=="number" then numeric=q;break end end
    state.pending[1]={id=assert(numeric).id,answerFirst=true};pending=numeric.id
    assert(controller.presentQuestion(game,{},1,function()done=done+1 end))
    assert(texts[1].meta.semanticPrompt==numeric.en,
      "GREEN numeric phase one changed the question")
    assert(not texts[1].meta.semanticPrompt:find(string.format("%03d",numeric.answer),1,true),
      "GREEN numeric phase one leaked an answer value")
  end
  texts[1].done();local menu=assert(screens[#screens])
  menu.onChoose({label="INVALID",value=1.5},menu)
  assert(done==1,route.." fractional row did not finish once")
  local current=route=="BLUE" and controller.state().pending.HALL.id
    or store.hevo_run.hidden_evolution_story_campaign.green.pending[1].id
  assert(current==pending,route.." fractional row consumed pending question")
end
print("hidden_evolution_question_presentation_test: PASS")
