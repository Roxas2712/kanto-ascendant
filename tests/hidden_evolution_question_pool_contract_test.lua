-- Cross-route contract for Hidden Evolution question catalogues and their
-- save-bound deterministic selectors. Run from gen1recomp with
-- KA_HIDDEN_EVOLUTION_MOD pointing at the Kanto Ascendant worktree.
package.path = "./?.lua;./?/init.lua;" .. package.path

local root=assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local redFactory=assert(loadfile(root.."/hidden_evolution_red_path.lua"))()
local blueFactory=assert(loadfile(root.."/hidden_evolution_blue_campaign.lua"))()
local greenFactory=assert(loadfile(root.."/hidden_evolution_green_grove.lua"))()

local function context(character,runId,cycle,playthroughId)
  local saved={extended_characters={player_character=character},
    hevo_run={runId=runId,cycle=cycle}}
  local mod={id="kanto_ascendant",path=root,exports={},
    save={
      get=function(_,key)return saved[key] end,
      set=function(_,key,value)saved[key]=value end,
    }}
  local save={meta={playthroughId=playthroughId},flags={},inventory={},party={}}
  return mod,saved,save
end

local function makeRed(runId,cycle,playthroughId,existing)
  local mod,saved,save=context("RED",runId,cycle,playthroughId)
  if existing then saved.hevo_run=existing end
  return redFactory(mod,{activeCharacter=function()return "RED" end}),saved,save,mod
end
local function makeBlue(runId,cycle,playthroughId,existing)
  local mod,saved,save=context("BLUE",runId,cycle,playthroughId)
  if existing then saved.hevo_run=existing end
  local blue=blueFactory(mod,{activeCharacter=function()return "BLUE" end})
  -- Question identity normally sees this through install(game); the runId and
  -- cycle remain sufficient in headless unit tests and are both durable.
  blue.game={save=save}
  return blue,saved,save,mod
end
local function makeGreen(runId,cycle,playthroughId,existing)
  local mod,saved,save=context("GREEN",runId,cycle,playthroughId)
  if existing then saved.hevo_run=existing end
  return greenFactory(mod,{activeCharacter=function()return "GREEN" end}),saved,save,mod
end

local function digest(rows,count,fields)
  local hash,prime=5381,2147483647
  for index=1,count do
    local row=assert(rows[index],"missing digest row "..index)
    local values={}
    for _,field in ipairs(fields) do
      local value=type(field)=="function" and field(row) or row[field]
      values[#values+1]=tostring(value)
    end
    local text=table.concat(values,"|").."\n"
    for i=1,#text do hash=(hash*33+text:byte(i))%prime end
  end
  return hash
end

local red=makeRed("catalogue",1,"catalogue-red")
local blue=makeBlue("catalogue",1,"catalogue-blue")
local green=makeGreen("catalogue",1,"catalogue-green")
assert(red.LEGACY_QUESTION_COUNT==100 and #red.questions==140,
  "RED catalogue is not immutable-100 plus 40")
assert(blue.LEGACY_QUESTION_COUNT==110 and #blue.questions==150,
  "BLUE catalogue is not immutable-110 plus 40")
assert(green.LEGACY_QUESTION_COUNT==120 and #green.questions==160,
  "GREEN catalogue is not immutable-120 plus 40")

-- Digests freeze IDs and answer semantics. GREEN deliberately omits prompt
-- wording because this release corrects "Johto Dex" to "National Dex" while
-- preserving every K/J ID, species, claim and answer.
local digests={
  red=digest(red.questions,100,{"id","en","de","answer"}),
  blue=digest(blue.questions,110,{"id","prompt","answer",
    function(q)return q.canonical[2] end,function(q)return q.canonical[3] end,
    "correct"}),
  green=digest(green.questions,120,{"id","species","region","kind",
    "answer","claimed","offered"}),
}
-- Filled with constants from the accepted 176f21a3 prefix; printing remains
-- useful in a failed CI log without weakening the assertions below.
local expected={red=601840312,blue=857182131,green=683118592}
for key,value in pairs(digests) do
  assert(value==expected[key],("%s legacy digest changed: %d ~= %d")
    :format(key,value,expected[key]))
end

local categories={KANTO=true,JOHTO=true,GENERAL=true,SINNOH=true}
local function catalogueContract(name,rows,legacy,yesNo)
  local seen,counts={},{}
  for category in pairs(categories) do counts[category]={total=0,yes=0,no=0} end
  for index,row in ipairs(rows) do
    assert(type(row.id)=="string" and row.id~="" and not seen[row.id],
      name.." duplicate/missing question ID at "..index)
    seen[row.id]=true
    if index>legacy then
      local count=assert(counts[row.category],name.." bad category "..tostring(row.category))
      count.total=count.total+1
      if yesNo then
        assert(type(row.answer)=="boolean",name.." new question is not Yes/No")
        if row.answer then count.yes=count.yes+1 else count.no=count.no+1 end
      else
        assert(type(row.answer)=="string" and row.answer~="",
          name.." new MC question lacks canonical answer")
      end
    end
  end
  for category,count in pairs(counts) do
    assert(count.total==10,name.." "..category.." needs exactly ten new questions")
    if yesNo then
      assert(count.yes==5 and count.no==5,
        name.." "..category.." is not 5 YES / 5 NO")
    end
  end
end
catalogueContract("RED",red.questions,100,true)
catalogueContract("BLUE",blue.questions,110,false)
catalogueContract("GREEN",green.questions,120,true)
for index=111,#blue.questions do
  local q=blue.questions[index]
  assert(type(q.promptDe)=="string" and q.promptDe~=""
      and type(q.choicesDe)=="table" and #q.choicesDe==3,
    "BLUE new localized MC record is incomplete: "..q.id)
end
for index=121,#green.questions do
  local q=green.questions[index]
  assert(type(q.en)=="string" and q.en~="" and type(q.de)=="string" and q.de~="",
    "GREEN new localized record is incomplete: "..q.id)
end
for index=101,#red.questions do
  local q=red.questions[index]
  assert(type(q.en)=="string" and q.en~="" and type(q.de)=="string" and q.de~="",
    "RED new localized record is incomplete: "..q.id)
end
for index=61,120 do
  assert(green.questions[index].en:find("National Dex",1,true)
      and green.questions[index].de:find("Nationaldex",1,true),
    "GREEN J question still labels a National number as Johto Dex")
end

local function sameSequence(a,b)
  return table.concat(a,"|")==table.concat(b,"|")
end
local function strictlyAlternates(values)
  if #values<4 then return false end
  for index=2,#values do
    if values[index]==values[index-1] then return false end
  end
  return true
end
local function repeatsEvery(values,period)
  if #values<period*3 then return false end
  for index=period+1,#values do
    if values[index]~=values[index-period] then return false end
  end
  return true
end
local function redWrongSequence(runId,cycle,playthroughId,count)
  local path,saved,save=makeRed(runId,cycle,playthroughId)
  local ids,seen,answerOrder,yes,no={},{},{},0,0
  for i=1,count do
    local q=assert(path.questionForStatue(save,"KA_RED_STATUE_1"))
    assert(not seen[q.id],"RED repeated before catalogue exhaustion: "..q.id)
    seen[q.id]=true;ids[#ids+1]=q.id
    answerOrder[#answerOrder+1]=q.answer and "YES" or "NO"
    if q.answer then yes=yes+1 else no=no+1 end
    local ok,why=path.answerStatue(save,"KA_RED_STATUE_1",q.id,not q.answer)
    assert(not ok and why=="wrong","RED wrong answer did not only consume its question")
  end
  assert((saved.hevo_run.red.sight or 0)==0,"RED wrong answer advanced a statue")
  return ids,{yes=yes,no=no,order=answerOrder},path,saved,save
end
local redIds,redBalance=redWrongSequence("red-a",3,"pt-red-a",140)
assert(#redIds==140 and redBalance.yes==70 and redBalance.no==70,
  "RED did not expose a balanced full no-repeat catalogue")
assert(not strictlyAlternates(redBalance.order),
  "RED answer semantics still expose a strict YES/NO alternation")
local redA,redAnswerA=redWrongSequence("red-seed-a",4,"pt-red-a",18)
local redARepeat,redAnswerARepeat=redWrongSequence("red-seed-a",4,"pt-red-a",18)
local redB,redAnswerB=redWrongSequence("red-seed-b",4,"pt-red-b",18)
local redCycle=redWrongSequence("red-seed-a",5,"pt-red-a",18)
assert(sameSequence(redA,redARepeat)
    and sameSequence(redAnswerA.order,redAnswerARepeat.order),
  "RED same seed did not reproduce its question/answer sequence")
assert(not sameSequence(redA,redB) and not sameSequence(redA,redCycle),
  "RED order is not playthrough/cycle-bound")
assert(not sameSequence(redAnswerA.order,redAnswerB.order),
  "RED answer sequence is not playthrough-bound")
do
  local path,saved,save,mod=makeRed("red-reload",6,"pt-red-reload")
  local before=assert(path.questionForStatue(save,"KA_RED_STATUE_1"))
  local reloaded=redFactory(mod,{activeCharacter=function()return "RED" end})
  local after=assert(reloaded.questionForStatue(save,"KA_RED_STATUE_1"))
  assert(before.id==after.id,"RED reload changed its pending question")
  local ok=assert(reloaded.answerStatue(save,"KA_RED_STATUE_1",after.id,after.answer))
  assert(ok and saved.hevo_run.red.statues.KA_RED_STATUE_1,
    "RED correct answer did not persist solved statue")
  local nextQ=assert(reloaded.questionForStatue(save,"KA_RED_STATUE_2"))
  assert(not reloaded.answerStatue(save,"KA_RED_STATUE_2",nextQ.id,not nextQ.answer))
  assert(saved.hevo_run.red.sight==1
      and saved.hevo_run.red.statues.KA_RED_STATUE_1,
    "RED later wrong answer erased a solved statue")
end
do
  local existing={cycle=7,runId="red-old",red={asked={},pending={KA_RED_STATUE_1="KA_RED_Q_001"},sight=0}}
  local path,_,save=makeRed("ignored",7,"pt-red-old",existing)
  assert(path.questionForStatue(save,"KA_RED_STATUE_1").id=="KA_RED_Q_001",
    "RED did not preserve an old pending ID")
end

local function blueWrongSequence(runId,cycle,playthroughId,count)
  local path,saved=makeBlue(runId,cycle,playthroughId)
  local ids,seen,slots,slotOrder={},{},{0,0,0},{}
  for i=1,count do
    local q=assert(path.nextQuestion("HALL"))
    assert(not seen[q.id],"BLUE repeated before catalogue exhaustion: "..q.id)
    seen[q.id]=true;ids[#ids+1]=q.id;slots[q.correct]=slots[q.correct]+1
    slotOrder[#slotOrder+1]=q.correct
    local wrong=q.correct%3+1
    local ok,why=path.answer("HALL",q.id,wrong)
    assert(not ok and why=="mist","BLUE wrong answer did not only consume its question")
  end
  assert((saved.hevo_run.hidden_evolution_blue.sight or 0)==0,
    "BLUE wrong answer advanced a statue")
  return ids,slots,slotOrder
end
local blueIds,blueSlots,blueSlotOrder=blueWrongSequence("blue-a",3,"pt-blue-a",150)
assert(#blueIds==150 and blueSlots[1]==50 and blueSlots[2]==50 and blueSlots[3]==50,
  "BLUE correct slots are not evenly seed-permuted")
assert(not repeatsEvery(blueSlotOrder,3),
  "BLUE answer slots still expose a fixed three-button rotation")
local blueA,_,blueSlotsA=blueWrongSequence("blue-seed-a",4,"pt-blue-a",18)
local blueARepeat,_,blueSlotsARepeat=blueWrongSequence("blue-seed-a",4,"pt-blue-a",18)
local blueB,_,blueSlotsB=blueWrongSequence("blue-seed-b",4,"pt-blue-b",18)
local blueCycle=blueWrongSequence("blue-seed-a",5,"pt-blue-a",18)
assert(sameSequence(blueA,blueARepeat) and sameSequence(blueSlotsA,blueSlotsARepeat),
  "BLUE same seed did not reproduce its question/slot sequence")
assert(not sameSequence(blueA,blueB) and not sameSequence(blueA,blueCycle),
  "BLUE order is not playthrough/cycle-bound")
assert(not sameSequence(blueSlotsA,blueSlotsB),
  "BLUE answer-slot sequence is not playthrough-bound")
do
  local path,saved,_,mod=makeBlue("blue-reload",6,"pt-blue-reload")
  local before=assert(path.nextQuestion("HALL"))
  local reloaded=blueFactory(mod,{activeCharacter=function()return "BLUE" end})
  local after=assert(reloaded.nextQuestion("HALL"))
  assert(before.id==after.id and before.correct==after.correct,
    "BLUE reload changed pending question or answer slot")
  assert(reloaded.answer("HALL",after.id,after.correct))
  local nextQ=assert(reloaded.nextQuestion("ICE_NORTH"))
  local wrong=nextQ.correct%3+1
  assert(not reloaded.answer("ICE_NORTH",nextQ.id,wrong))
  local state=saved.hevo_run.hidden_evolution_blue
  assert(state.sight==1 and state.solved.HALL,
    "BLUE later wrong answer erased a solved statue")
end

local function greenWrongSequence(runId,cycle,playthroughId,count)
  local path,saved,save=makeGreen(runId,cycle,playthroughId)
  local ids,seen,yes,no={}, {},0,0
  local numericFirst,numericSecond,numericOrder=0,0,{}
  for i=1,count do
    local q=assert(path.questionFor(save,1))
    assert(not seen[q.id],"GREEN repeated before catalogue exhaustion: "..q.id)
    seen[q.id]=true;ids[#ids+1]=q.id
    if q.kind=="yesno" then
      if q.answer then yes=yes+1 else no=no+1 end
    elseif q.answerFirst then
      numericFirst=numericFirst+1;numericOrder[#numericOrder+1]="A"
    else
      numericSecond=numericSecond+1;numericOrder[#numericOrder+1]="B"
    end
    local wrong=q.kind=="number" and q.answer+1000 or not q.answer
    local ok,why=path.answer(save,1,wrong)
    assert(not ok and why=="wrong","GREEN wrong answer did not only consume its question")
  end
  local state=saved.hevo_run.hidden_evolution_story_campaign.green
  assert((state.sight or 0)==0,"GREEN wrong answer advanced a statue")
  return ids,{yes=yes,no=no,first=numericFirst,second=numericSecond},numericOrder
end
local greenIds,greenBalance,greenNumericOrder=greenWrongSequence("green-a",3,"pt-green-a",160)
assert(#greenIds==160 and greenBalance.yes==50 and greenBalance.no==50
    and greenBalance.first==30 and greenBalance.second==30,
  ("GREEN answer balance yes=%d no=%d first=%d second=%d")
    :format(greenBalance.yes,greenBalance.no,
      greenBalance.first,greenBalance.second))
assert(not strictlyAlternates(greenNumericOrder),
  "GREEN numeric answers still expose a strict A/B alternation")
local greenA,_,greenSlotsA=greenWrongSequence("green-seed-a",4,"pt-green-a",40)
local greenARepeat,_,greenSlotsARepeat=greenWrongSequence("green-seed-a",4,"pt-green-a",40)
local greenB,_,greenSlotsB=greenWrongSequence("green-seed-b",4,"pt-green-b",40)
local greenCycle=greenWrongSequence("green-seed-a",5,"pt-green-a",40)
assert(sameSequence(greenA,greenARepeat) and sameSequence(greenSlotsA,greenSlotsARepeat),
  "GREEN same seed did not reproduce its question/numeric-slot sequence")
assert(not sameSequence(greenA,greenB) and not sameSequence(greenA,greenCycle),
  "GREEN order is not playthrough/cycle-bound")
assert(not sameSequence(greenSlotsA,greenSlotsB),
  "GREEN numeric answer-slot sequence is not playthrough-bound")
do
  local path,saved,save,mod=makeGreen("green-reload",6,"pt-green-reload")
  local before=assert(path.questionFor(save,1))
  local reloaded=greenFactory(mod,{activeCharacter=function()return "GREEN" end})
  local after=assert(reloaded.questionFor(save,1))
  assert(before.id==after.id and before.answerFirst==after.answerFirst,
    "GREEN reload changed pending question or numeric answer slot")
  assert(reloaded.answer(save,1,after.answer))
  local nextQ=assert(reloaded.questionFor(save,2))
  local wrong=nextQ.kind=="number" and nextQ.answer+1000 or not nextQ.answer
  assert(not reloaded.answer(save,2,wrong))
  local state=saved.hevo_run.hidden_evolution_story_campaign.green
  assert(state.sight==1,"GREEN later wrong answer erased a solved statue")
end

print(("hidden_evolution_question_pool_contract_test: DIGEST red=%d blue=%d green=%d")
  :format(digests.red,digests.blue,digests.green))
print("hidden_evolution_question_pool_contract_test: PASS")
