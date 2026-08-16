-- Focused HEVO 20-second receipt contract. No renderer, app or disk save.
local engine=assert(os.getenv("GEN1RECOMP_DIR"))
local modDir=os.getenv("KA_HIDDEN_EVOLUTION_MOD") or "."
package.path=engine.."/?.lua;"..engine.."/?/init.lua;"..modDir.."/?.lua;"..package.path

local function registry(getter)
  local values={}
  return {values=values,register=function(_,id,value)values[id]=value end,
    patch=function()end,get=getter or function(_,id)return values[id]end}
end
local function makeMod()
  local store={johto_masters={sentinel="unchanged"}};local warps=0
  local mod={id="kanto_ascendant",path=modDir,content={},world={
    warpTo=function()warps=warps+1 end}}
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
  return mod,store,function()return warps end
end
local function makeStack()
  local values={}
  return values,{push=function(_,value)values[#values+1]=value end,
    pop=function()return table.remove(values)end,
    top=function()return values[#values]end}
end

for _,route in ipairs({"RED","BLUE","GREEN"}) do
  local mod,store,warpCount=makeMod();local screens,stack=makeStack();local texts={}
  local function showText(_,message,after,meta)
    texts[#texts+1]={message=message,done=after,meta=meta};return true
  end
  local i18n={text=function(en)return en end}
  local ui=assert(loadfile(modDir.."/ascendant_ui.lua"))()(mod,{i18n=i18n})
  local pressed
  local game={save={hevo_run={character=route}},stack=stack,
    input={wasPressed=function(_,key)return key==pressed end}};local done=0
  local controller,present,currentPending,wasAsked,sight
  if route=="RED" then
    controller=assert(loadfile(modDir.."/hidden_evolution_red_path.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    controller.register()
    local talk=mod.content.map_scripts.values[controller.IDS.upper]
      .talk.TEXT_KA_RED_STATUE_1
    present=function()return talk(game,{map={id=controller.IDS.upper}},
      {def={name="KA_RED_STATUE_1"}},function()done=done+1 end)end
    currentPending=function()return controller.run(game.save,true).pending.KA_RED_STATUE_1 end
    wasAsked=function(id)return controller.run(game.save,true).asked[id]end
    sight=function()return controller.run(game.save,true).sight or 0 end
  elseif route=="BLUE" then
    controller=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    present=function()return controller.ask("HALL",game,function()done=done+1 end)end
    currentPending=function()local row=controller.state().pending.HALL;return row and row.id end
    wasAsked=function(id)return controller.state().asked[id]end
    sight=function()return controller.state().sight end
  else
    store.hevo_run={character="GREEN"};game.save.hevo_run=store.hevo_run
    controller=assert(loadfile(modDir.."/hidden_evolution_green_grove.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    present=function()return controller.presentQuestion(game,{},1,function()done=done+1 end)end
    local function state()return store.hevo_run.hidden_evolution_story_campaign.green end
    currentPending=function()local row=state().pending[1];return row and row.id end
    wasAsked=function(id)return state().asked[id]end
    sight=function()return state().sight end
  end

  assert(present());local first=assert(currentPending())
  texts[1].done();local menu=assert(screens[#screens])
  assert(menu.kascQuestionSeconds==20 and menu.kascQuestionRemaining==20,
    route.." timer did not start at 20")
  menu:update(19.99)
  assert(not menu.kascQuestionResolved and currentPending()==first
      and not wasAsked(first) and done==0,
    route.." consumed or resolved before 20 seconds")
  menu:update(.01)
  assert(menu.kascQuestionResolved and menu.kascQuestionRemaining==0,
    route.." did not resolve at exact 20-second boundary")
  assert(currentPending()==nil and wasAsked(first) and sight()==0,
    route.." timeout was not exactly one normal wrong answer")
  local feedbackCount=#texts+#screens
  menu.onChoose(menu.items[1],menu);menu.onCancel()
  assert(#texts+#screens==feedbackCount and done==0,
    route.." accepted a stale A/B callback after timeout")
  menu:update(100)
  if route=="RED" then
    local feedback=assert(screens[#screens]);table.remove(screens);feedback.onDone()
  else
    assert(texts[2] and texts[2].done);texts[2].done()
  end
  assert(done==1,route.." timeout callback fired more than once")
  local reloadQuestion
  if route=="RED" then
    local reloaded=assert(loadfile(modDir.."/hidden_evolution_red_path.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    reloadQuestion=assert(reloaded.questionForStatue(game.save,"KA_RED_STATUE_1"))
  elseif route=="BLUE" then
    local reloaded=assert(loadfile(modDir.."/hidden_evolution_blue_campaign.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    reloadQuestion=assert(reloaded.nextQuestion("HALL"))
  else
    local reloaded=assert(loadfile(modDir.."/hidden_evolution_green_grove.lua"))()(mod,
      {i18n=i18n,questionUi=ui,showText=showText})
    reloadQuestion=assert(reloaded.questionFor(game.save,1))
  end
  assert(reloadQuestion.id~=first,
    route.." controller reload resurrected the timed-out question")
  texts={};assert(present());local nextId=assert(currentPending())
  assert(nextId==reloadQuestion.id,
    route.." live controller disagrees with reloaded next-question receipt")
  assert(nextId~=first and not wasAsked(nextId),
    route.." next interaction did not select a fresh pending question")
  texts[1].done();local nextMenu=assert(screens[#screens])
  pressed="b";nextMenu:update(5);pressed=nil
  assert(screens[#screens]==nextMenu and not nextMenu.kascQuestionResolved,
    route.." B closed or resolved the fresh question menu")
  assert(nextMenu.kascQuestionRemaining==15 and done==1,
    route.." B paused the timer or dispatched a callback")
  assert(currentPending()==nextId and not wasAsked(nextId),
    route.." B consumed the fresh pending question")
  nextMenu:update(15)
  assert(nextMenu.kascQuestionResolved and currentPending()==nil
      and wasAsked(nextId) and sight()==0,
    route.." timer did not continue from ignored B to one wrong answer")
  if route=="RED" then
    local feedback=assert(screens[#screens]);table.remove(screens);feedback.onDone()
  else
    assert(texts[2] and texts[2].done);texts[2].done()
  end
  assert(done==2,route.." ignored-B timeout did not finish exactly once")
  assert(warpCount()==0 and store.johto_masters.sentinel=="unchanged",
    route.." HEVO timeout touched Johto reset/warp state")
end

-- A selection also resolves the generic receipt before any later update.
do
  local mod=makeMod();local screens,stack=makeStack()
  local ui=assert(loadfile(modDir.."/ascendant_ui.lua"))()(mod,{})
  local chosen,timeouts=0,0
  local menu=assert(ui.openQuestionMenu({stack=stack},"TEST","QUESTION",{
    {label="A",value=1},{label="B",value=2}},
    {seconds=20,onChoose=function()chosen=chosen+1 end,
      onTimeout=function()timeouts=timeouts+1 end}))
  menu.onChoose(menu.items[1],menu);menu:update(100)
  assert(chosen==1 and timeouts==0,"A allowed a later timeout callback")
end
print("hidden_evolution_question_timeout_test: PASS")
