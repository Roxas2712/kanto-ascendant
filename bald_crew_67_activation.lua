-- Count physical world steps after Champion, never menu frames or trainer boosts.
-- Progress belongs to the adopted save slot; Fly is an additional live gate.
return function(mod,opts)
 local M={key='bald_crew_champion_steps_67'}
 local function champion(game)
  local s=game and game.save
  return s and ((type(s.hallOfFame)=='table'and #s.hallOfFame>0)
   or s.flags and s.flags.EVENT_BEAT_CHAMPION_RIVAL==true)or false
 end
 function M.approved()
  local a=opts.data.activation
  return a and a.approved==true and a.kind=='champion_steps_item'
   and a.item=='HM_FLY'and a.steps==134 or false
 end
 function M.steps()
  local n=mod.save:get(M.key,0)
  return type(n)=='number'and n==n and math.max(0,math.min(134,math.floor(n)))or 0
 end
 function M.eligible(game)
  return M.approved()and champion(game)and M.steps()>=134
   and (tonumber(game.save.inventory and game.save.inventory.HM_FLY)or 0)>0
 end
 function M.onStep(ev)
  local game=ev and ev.game or M.game
  if not M.approved()or not champion(game)then return end
  local n=M.steps()
  if n<134 then mod.save:set(M.key,n+1)end
  if M.eligible(game)and opts.changed then opts.changed(game)end
 end
 function M.install(game)
  M.game=game
  if not M.installed then
   mod.events:on('world.stepped',M.onStep)
   M.installed=true
  end
 end
 return M
end
