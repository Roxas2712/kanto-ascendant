-- Focused diagnostic for the native GREEN AnswerBox after a save reload.
-- Uses a staged viewpoint only to isolate the real D-pad/answer callback.
return function(game)
  local U=dofile("tests/drivers/util.lua")
  U.wait(5);U.tap(game,"start");U.wait(10);U.tap(game,"a")
  for _=1,600 do
    if game.overworld and game.stack:top()==game.overworld then break end
    U.tap(game,"a");U.wait(3)
  end
  assert(game.overworld and game.stack:top()==game.overworld)
  local api=assert(game.mods.exports.kanto_ascendant)
  local green=assert(api.hiddenEvolutionCampaign.modules.GREEN)
  assert(green.progress(game.save).sight==3,"diagnostic save must start at sight 3")
  local called
  local answer=green.answer
  green.answer=function(save,statue,value)
    local q=assert(green.questionFor(save,statue))
    local ok,reason,consumed=answer(save,statue,value)
    called={id=q.id,expected=q.answer,value=value,ok=ok,reason=reason,
      consumed=consumed and consumed.id}
    return ok,reason,consumed
  end
  U.teleport(game,green.IDS.mist,38,21,"right")
  U.wait(30);U.tap(game,"a");U.wait(8)
  local box
  for _=1,360 do
    local top=game.stack:top()
    if type(top)=="table" and type(top.labels)=="table"
        and type(top.onChoose)=="function" and top.index then box=top;break end
    U.tap(game,"a");U.wait(3)
  end
  assert(box,"answer box missing")
  local chosenIndex
  local choose=box.onChoose
  box.onChoose=function(index) chosenIndex=index;return choose(index) end
  local update=box.update
  box.update=function(self,...)
    local input=self.game.input
    if input:wasPressed("up") or input:wasPressed("down")
        or input:wasPressed("a") then
      U.log("GREEN ANSWER EDGE","before",self.index,"up",
        tostring(input:wasPressed("up")),"down",
        tostring(input:wasPressed("down")),"a",
        tostring(input:wasPressed("a")))
    end
    local out=update(self,...)
    U.log("GREEN ANSWER EDGE","after",self.index)
    return out
  end
  local q=assert(green.questionFor(game.save,4))
  local wanted=q.answer and 1 or 2
  if box.index~=wanted then
    U.tap(game,wanted==1 and "up" or "down");U.wait(10)
  end
  U.wait(10)
  assert(game.stack:top()==box and box.index==wanted,"cursor mismatch")
  U.tap(game,"a");U.wait(12)
  assert(called,"answer callback was not called")
  U.log("GREEN ANSWER QA",called.id,tostring(called.expected),
    tostring(called.value),tostring(called.ok),called.reason,
    "chosen",tostring(chosenIndex),"sight",green.progress(game.save).sight)
  assert(called.id==q.id and called.value==q.answer and called.ok,
    "visible answer and callback value diverged")
  assert(green.progress(game.save).sight==4,"correct reload answer did not reveal sight 4")
  love.event.quit(0)
end
