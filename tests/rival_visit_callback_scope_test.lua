-- Execute the public visit dialogue callback, not an extracted function.
local source=assert(arg[1], 'life_of_rival.lua path required')
local make=assert(loadfile(source))()
local cases=0
for _,actor in ipairs({'RED','BLUE','GREEN'})do
 for _,outcome in ipairs({'win','lose','decline','invalid_plan','construction_failure','stale_visit','persistence_failure'})do
  local boxes,battles,events={},{},{}
  local doneCount,writes=0,0
  local visit={token='visit-1',talked={},battleStarted={},battleResolved={}}
  local state={visitReceipts={ROUTE_1=visit},dialogueHistory={},battles=0,wins=0,losses=0,talks=0}
  local npc={id='visit-npc',frozen=false}
  local ow={map={id='ROUTE_1'},pushBattle=function(_,battle)battles[#battles+1]=battle end,
    afterBattle=function()end}
  local party={{species='PIKACHU',level=20,hp=40}}
  local game={save={money=500,party=party},data={trainers={}},stack={push=function(_,box)boxes[#boxes+1]=box end}}
  local mod={id='kanto_ascendant',save={set=function()
    if outcome=='persistence_failure' and writes>0 then error('test write failure')end
    writes=writes+1
  end}}
  local rows={}
  for _,suffix in ipairs({'battle_prompt','battle_decline','battle_win','battle_lose'})do
   rows[#rows+1]={id=actor:lower()..'_'..suffix,actor=actor,en=suffix,de=suffix,category='battle'}
  end
  local life=make(mod,{characters={},postgame={newForcedBattle=function()
      if outcome=='construction_failure' then error('test battle failure')end
      return {trainer={}}
    end},rivalTeams={},teamProgression={},wanderers={},spawnSafety={},
    explorationDevice={},hiddenAccessReveal={},starterHabitats={recordRumorTrace=function()end},
    dialogues=rows,gameVersion={get=function()return'red'end},
    emit=function(name)events[#events+1]=name end,
    textBox=function(_,text,done,opts)return{text=text,done=done,choice=opts and opts.choice}end})
  -- Isolate the visit transaction from progression and unrelated rumor systems.
  life.state=function()return state end
  life.commitDialogue=function()end
  life.reconcileRumorDiscoveries=function()end
  life.progressBattlePlan=function()
    if outcome=='invalid_plan' then return nil end
    return{class='OPP_RIVAL3',team={{species='PIKACHU',level=20}}}
  end
  local entry={actor=actor,npc=npc,npcId=npc.id,row={role='rival',battleOffered=true,
    battlePlan={},dialogue={id='test_dialogue',text='Battle?'}}}
  local active={game=game,ow=ow,mapId='ROUTE_1',token='visit-1',visit=true,entries={entry}}
  life.active=active
  assert(life.handleVisitTalk(game,ow,npc,function()doneCount=doneCount+1 end))
  assert(active.talking and npc.frozen and boxes[1].choice)
  if outcome=='stale_visit' then state.visitReceipts.ROUTE_1={token='different',battleStarted={},battleResolved={}}end
  if love and love.window then
    local w,h=love.graphics.getDimensions()
    love.window.setMode(h,w,{resizable=true,vsync=0})
  end
  -- This exact real callback crashes at public 6.7.1 line 2399.
  boxes[1].choice(outcome~='decline')
  if outcome=='win' or outcome=='lose' then
    assert(#battles==1 and visit.battleStarted[actor] and #events==1)
    local battle=battles[1]
    assert(battle.trainer.baseMoney==0 and battle.ascendantNoBonusReward)
    game.save.money=outcome=='lose' and 250 or 500
    battle.onFinish(outcome)
    assert(not active.talking and not npc.frozen)
    assert(visit.battleResolved[actor] and state.battles==1)
    assert(state.wins==(outcome=='win' and 1 or 0))
    assert(state.losses==(outcome=='lose' and 1 or 0))
    assert(game.save.money==500 and game.save.party==party)
    assert(boxes[#boxes].done);boxes[#boxes].done()
    battle.onFinish(outcome)
    assert(state.battles==1 and doneCount==1,'duplicate completion')
  else
    if outcome=='decline' then assert(boxes[#boxes].done);boxes[#boxes].done()end
    assert(#battles==0 and not active.talking and not npc.frozen and doneCount==1)
  end
  assert(_G.startVisitBattle==nil and _G.releaseVisitTalk==nil,'callback leaked into globals')
  cases=cases+1;print('VISIT_CALLBACK_PASS',actor,outcome)
 end
end
print('PASS',cases,'real visit callback and completion/error paths; no orientation dependency')
