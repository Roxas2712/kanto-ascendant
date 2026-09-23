return function(game)
 io.stdout:setvbuf('no')
 game:startNewGame{intro=false}
 local content=game.mods.exports.VOXEL_ASCENDANT.ascendantContent;content.onboardingShown=true;content.promptDisabled=true
 local K=game.mods.exports.kanto_ascendant
 local J,P=K.johtoMasters,K.johtoMastersPassages
 J.eligible=function()return true end
 local s=P.state();s.activeRun=true;s.runSerial=1
 P.sync(game)
 local t=love.timer.getTime()
 for _,key in ipairs{'silver','kris','gold'}do
  s.passages[key].status='entered'
  for i=1,3 do
   local a=love.timer.getTime();local serial=s.cadenceSerial
   local q=assert(P.question(game,key,i))
   local mid=love.timer.getTime()
   local readSerial=s.cadenceSerial
   assert(P.question(game,key,i).id==q.id and s.cadenceSerial==readSerial,'read wrote archive')
   assert(P.answer(game,key,i,q.id,q.correct))
   assert(s.cadenceSerial-readSerial==1,'answer must checkpoint exactly once')
   print('QUIZ_TIMING',key,i,mid-a,love.timer.getTime()-mid,'writes',s.cadenceSerial-serial)
  end
 end
 print('QUIZ_TOTAL',love.timer.getTime()-t)
 -- Rejection still resets all three passages and persists exactly once.
 assert(P.resetChallenge(game,'test','silver'))
 local q=assert(P.question(game,'silver',1));local before=s.cadenceSerial
 assert(not P.answer(game,'silver',1,q.id..'-stale',q.correct))
 assert(s.cadenceSerial==before,'stale answer wrote archive')
 local attempt=s.challengeAttempt
 assert(not P.answer(game,'silver',1,q.id,q.correct%3+1))
 assert(s.challengeAttempt==attempt+1 and s.cadenceSerial==before+1)
 assert(s.passages.silver.status=='unlocked' and s.passages.kris.status=='locked' and s.passages.gold.status=='locked')
 local serial=s.cadenceSerial;for i=1,100 do assert(P.canEnter(game,'silver'))end
 assert(s.cadenceSerial==serial,'eligibility check wrote archive')
 print('QUIZ_CHECKPOINT_READ_ONLY_AND_WRONG_ANSWER_PASS')
 love.event.quit()
end
