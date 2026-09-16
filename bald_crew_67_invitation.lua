-- A deferred native call: never steal input from a fight, warp, menu or script.
return function(mod,opts)
 local M={key='bald_crew_invitation_67'}
 function M.seen()return mod.save:get(M.key,false)==true end
 local function hero()
  local s=mod.save:get('extended_characters',{})
  return type(s)=='table'and tostring(s.player_character or 'RED'):upper()or'RED'
 end
 local function tr(row)return opts.i18n and opts.i18n.text(row.en,row.de)or row.en end
 function M.poll(game)
  local ow=game and game.overworld;local s=opts.state.status()
  if M.busy or M.seen()or not s or (s.phase~='locked'and s.phase~='ready')
    or not opts.eligible(game)or not ow or not game.stack or game.stack:top()~=ow
    or ow.transitioning or ow.flyAnim or ow.flyArrive or ow.teleportOut
    or ow.holeFall or ow.holeArrive or ow.spinArrive
    or not ow.player or ow.player.moving or ow.player.inputLocked
    or ow.runner and ow.runner:isRunning()or ow.scriptMoves and #ow.scriptMoves>0 then return false end
  local save=game.save;M.busy=true
  local d=opts.dialogue;local lines={tr(d.callOpening),tr(d.callOmega[hero()]or d.callOmega.RED)}
  for _,id in ipairs({'chibi_gaming','tav','ya_dad','ag64','james','fabelle_moon'})do
   lines[#lines+1]=tr(d.call[id])
  end
  lines[#lines+1]=tr(d.callClosing)
  local finished=false
  local function done()
   if finished then return end;finished=true;M.busy=false
   if game.save~=save then return end
   mod.save:set(M.key,true)
   local current=opts.state.status()
   local ok=opts.state.unlock(game) -- Saves the invitation with the ready state.
   if ok and current and current.phase~='locked'and game.writeSave then
    local called,result=pcall(game.writeSave,game);ok=called and result~=false
   end
   if not ok then mod.save:set(M.key,false);return end
   opts.runtime.sync(game)
  end
  local ok,why=pcall(function()
   if opts.show then return opts.show(game,table.concat(lines,'\f'),done)end
   local TextBox=require('src.render.TextBox')
   game.stack:push(TextBox.new(game,table.concat(lines,'\f'),done));return true
  end)
  if not ok or why==false then M.busy=false;return false end
  return true
 end
 function M.install(game)
  M.game=game;M.busy=false
  if M.installed then return end
  local OW=require('src.world.OverworldController');local update=OW.update
  OW.update=function(ow,...)
   local result=update(ow,...)
   if M.game and M.game.overworld==ow then M.poll(M.game)end
   return result
  end
  M.installed=true
 end
 return M
end
