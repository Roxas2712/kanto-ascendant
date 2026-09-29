-- Internal shared entry card: triggered by a confirmed New Game / Continue.
local M={apiVersion=1,id='ascendant.entry'}
local marker='__ascendantEntryCardV1'
local function load(read,path)return assert((loadstring or load)(assert(read(path)),'@AscendantEntry/'..path))()end
local function remove(stack,state)
 for i,s in ipairs(stack.states)do if s==state then table.remove(stack.states,i);return true end end
end
function M.attach(mod,prefix)
 prefix=prefix or ''
 local function read(path)return mod:read(prefix..path)end
 local Scene=load(read,'IntroScene.lua');local Queue=load(read,'PreloadQueue.lua')
 local registrations={};local requirements={};local shared
 local api={}
 function api:begin(kind,proceed)
  assert(shared and shared.begin,'entry card requires game.ready')
  assert(type(proceed)=='function','entry callback required')
  return shared.begin(kind,proceed)
 end
 function api:add(id,step,required)
  if type(id)~='string'or type(step)~='function'then return false end
  id=mod.id..':'..id
  local jobs=shared and shared.jobs or registrations
  if jobs[id]then return false end;jobs[id]=step
  local requiredJobs=shared and shared.requiredJobs or requirements
  if requiredJobs then requiredJobs[id]=required==true end;return true
 end
 function api:status()
  local active=shared and shared.active
  if not active then return {state='idle',ready=true,jobs={}}end
  local result=active.queue:status();result.state=active.closed and 'closed'or 'running'
  result.kind=active.kind;result.owner=shared.owner;result.error=active.error
  result.nativePending=active.nativePending;result.progress=active.progress;result.maxFrameSeconds=active.maxFrameSeconds;return result
 end
 local function install(game)
  shared=game[marker]
  if shared then
   shared.requiredJobs=shared.requiredJobs or{}
   for id,step in pairs(registrations)do shared.jobs[id]=step;shared.requiredJobs[id]=requirements[id]end;registrations={};return
  end
  shared={jobs=registrations,requiredJobs=requirements,owner=mod.id};registrations={};game[marker]=shared
  local entries={}
  local function record(line)
   print(line)
   entries[#entries+1]=tostring(line)
   if #entries>96 then table.remove(entries,1)end
   if mod.cache then pcall(function()mod.cache:write('diagnostics/startup-latest.log',table.concat(entries,'\n')..'\n')end)end
  end
  local native=load(read,'NativePreload.lua')
  shared.jobs['ascendant.entry:native-assets']=native.step
  local function begin(kind,proceed)
   if shared.active and not shared.active.closed then return end
   local ok,scene=pcall(Scene.new,read)
   if not ok then return proceed()end
   local state={isOpaque=false,ascendantStartup=true,phase='in',kind=kind,queue=Queue.new(love.timer.getTime)}
   shared.active=state
   local ids={};for id in pairs(shared.jobs)do ids[#ids+1]=id end;table.sort(ids)
   for _,id in ipairs(ids)do state.queue:add(id,shared.jobs[id],shared.requiredJobs[id])end
   local started,skipAt,finishAt,frameAvailable,entered
   local animationTime=0
   local previous=game.draw;local wrapped
   local function elapsed()return started and love.timer.getTime()-started or 0 end
   local function skip()if elapsed()>.2 and not skipAt then skipAt=love.timer.getTime()end end
   state.progress='Preparing game'
   local lastPhase,lastReport,lastDraw
   local function progress()
    local phase=not entered and 'Preparing game' or 'Preparing world and graphics'
    for _,s in ipairs(game.stack.states)do
     if s.vascContinue then
      if s.stage=='save'then phase='Restoring saved game'
      elseif s.region then
       local r=s.region
       local total=r.phase=='scenery'and #r.order or #r.plan.ids
       local label=r.phase=='plan'and 'Finding nearby areas' or r.phase=='scenery'and 'Preparing nearby buildings' or 'Preparing nearby areas'
       phase=label..' '..tostring(math.min(total,math.max(0,r.index-1)))..' / '..tostring(total)
      end
      break
     end
    end
    if state.reportPending then phase='Save validation needs attention'
    elseif state.queue:ready()and not state.nativePending and entered then phase='Preparation complete' end
    state.progress=phase
    local now=love.timer.getTime()
    if phase~=lastPhase or not lastReport or now-lastReport>=10 then
     record('[Ascendant entry] '..kind..' '..string.format('%.1fs',elapsed())..' '..phase)
     lastPhase=phase;lastReport=now
    end
   end
   function state:alpha()return 1 end
   function state:update(dt)
    if not started then return end
    if frameAvailable then
     frameAvailable=false
     if not entered then
      entered=true;remove(game.stack,self)
      -- Let the engine adopt the selected save/create the new game exactly once.
      -- The card has already been presented; no target scene reaches the screen.
      shared.entering=true
      local success,err=pcall(proceed)
      shared.entering=false
      if not success then self:exit();error(err,0)end
      table.insert(game.stack.states,self)
      pcall(function()require('src.core.Music').duckForFanfare({isPlaying=function()return not self.closed end})end)
     end
     -- VASC's existing continuation owns its region/cache scheduler. Tick only
     -- that preparation state, never hidden gameplay, dialogue or cutscenes.
     remove(game.stack,self)
     local below=game.stack:top()
     self.reportPending=below and below.screenId=='QuarantineReport'
     if below and below.vascContinue and type(below.update)=='function'then
      local success,err=pcall(below.update,below,dt)
      if not success then table.insert(game.stack.states,self);self.error=tostring(err);self:exit();remove(game.stack,self);error(err,0)end
     end
     table.insert(game.stack.states,self)
     self.nativePending=false
     for _,s in ipairs(game.stack.states)do if s.vascContinue and not self.reportPending then self.nativePending=true end end
     self.queue:update(game)
     progress()
     self.prepared=entered and not self.reportPending and self.queue:ready()and not self.nativePending
    end
    local now=love.timer.getTime();local t=animationTime
    if skipAt and scene.sound then scene.sound:setVolume((self.volume or 0)*math.max(0,1-(now-skipAt)/.09))end
    if (self.reportPending or(self.queue:ready()and not self.nativePending))and (skipAt or t>=Scene.duration-.6)then finishAt=finishAt or now end
    -- Required native preparation has no elapsed-time escape: slower devices
    -- keep the logo until the actual destination is ready. Optional jobs own
    -- their bounded failure policy in PreloadQueue.
    if finishAt and now-finishAt>=(skipAt and .1 or .6)then
     if game.stack:top()==self then game.stack:pop()end;return
    end
    if t>.2 and game.input and game.input.wasPressed then
     for _,key in ipairs{'a','b','start'}do if game.input:wasPressed(key)then skip();break end end
    end
   end
   function state:onKeyPressed(key)if key=='return'or key=='space'or key=='escape'or key=='z'or key=='x'then skip()end end
   function state:onGamepadPressed(key)if key=='a'or key=='b'or key=='start'then skip()end end
   function state:draw()love.graphics.clear(0,0,0,1)end
   function state:exit()
    if self.closed then return end
    record('[Ascendant entry] closed '..string.format('%.2fs',elapsed())..' phase='..tostring(self.progress)..' maxFrame='..string.format('%.3fs',self.maxFrameSeconds or 0)..' animation='..string.format('%.2fs',animationTime)..' error='..tostring(self.error))
    scene:release();self.closed=true
    if game.draw==wrapped then game.draw=previous end
   end
   local function drawCard()
    local now=love.timer.getTime()
    if lastDraw then
     local gap=now-lastDraw
     -- Long synchronous engine work must not skip the walk/turn sequence.
     animationTime=animationTime+math.min(.1,math.max(0,gap))
     state.maxFrameSeconds=math.max(state.maxFrameSeconds or 0,gap)
     if gap>.25 and scene.sound then pcall(scene.sound.seek,scene.sound,animationTime,'seconds')end
     if gap>.25 then record('[Ascendant entry] slow frame '..string.format('%.3fs',gap)..' phase='..tostring(state.progress))end
    end
    lastDraw=now
    if not started then
     started=love.timer.getTime()
     local options=game.save and game.save.options or{}
     state.volume=math.max(0,math.min(7,tonumber(options.sfxVol)or 7))/7
     if options.splashMute==true then state.volume=0 end
     pcall(scene.play,scene,state.volume)
    end
    local t=math.min(animationTime,Scene.duration-.6)
    if finishAt then t=Scene.duration-.6+(love.timer.getTime()-finishAt)end
    local success,err=pcall(scene.draw,scene,t,love.graphics.getWidth(),love.graphics.getHeight(),animationTime);frameAvailable=true
    if not success then state.error=tostring(err);game.stack:pop()
    elseif scene.drawStatus then scene:drawStatus(state.progress,elapsed(),finishAt and math.max(0,1-(love.timer.getTime()-finishAt)/.6)or 1)end
   end
   wrapped=function(...)
    if state.closed or game.stack:top()~=state then return previous(...)end
    -- Once native preparation has completed, the intro alone owns the screen.
    -- Do not redraw the invisible world for the remainder of the animation.
    local w,h=love.graphics.getDimensions()
    if entered and state.prepared and state.drawWidth==w and state.drawHeight==h then drawCard();return end
    state.drawWidth=w;state.drawHeight=h
    -- Draw the real world through the native renderer to warm first-use GPU
    -- work. Keep every state and its input ownership; only widen the draw base.
    local changed={};local found=false
    if entered then
     for _,s in ipairs(game.stack.states)do
      if s==game.overworld then found=true
      elseif found and s.isOpaque then changed[#changed+1]={s,rawget(s,'isOpaque')};s.isOpaque=false end
     end
    end
    -- Gen 2 renders the world outside its state stack. Remove only this
    -- cover for drawing so its compositor can warm the actual destination.
    -- Update/input still see the cover, and the intro overwrites this frame.
    local detached=entered and type(game.makeTitleState)~='function'
    if detached then remove(game.stack,state)end
    local result={pcall(previous,...)}
    if detached then table.insert(game.stack.states,state)end
    for _,item in ipairs(changed)do item[1].isOpaque=item[2]end
    if not result[1]then state:exit();remove(game.stack,state);error(result[2],0)end
    drawCard()
    return (unpack or table.unpack)(result,2)
   end
   game.draw=wrapped;game.stack:push(state)
   pcall(function()require('src.core.Music').duckForFanfare({isPlaying=function()return not state.closed end})end)
   return state
  end
  shared.begin=begin
  local function wrapTitle(title)
   if not title or title.__ascendantEntryWrapped then return title end
   title.__ascendantEntryWrapped=true
   for _,spec in ipairs{{'onNewGame','new-game'},{'onContinue','continue'}}do
    local key,kind=spec[1],spec[2];local original=title[key]
    if type(original)=='function'then
     title[key]=function(...)
      local args={...};return begin(kind,function()return original((unpack or table.unpack)(args))end)
     end
    end
   end
   return title
  end
  local make=game.makeTitleState
  if type(make)=='function'then
   game.makeTitleState=function(...)return wrapTitle(make(...))end
  else
   -- Gen 2 main-menu callbacks dispatch to these methods, including custom
   -- menus. Nested Continue(nil) -> New Game must adopt only once.
   for _,spec in ipairs{{'newGame','new-game'},{'continueGame','continue'}}do
    local key,kind=spec[1],spec[2];local original=game[key]
    if type(original)=='function'then
     game[key]=function(...)
      if shared.entering then return original(...)end
      local args={n=select('#',...),...}
      return begin(kind,function()return original((unpack or table.unpack)(args,1,args.n))end)
     end
    end
   end
  end
  for _,s in ipairs(game.stack.states or{})do if s.screenId=='TitleState'then wrapTitle(s)end end
 end
 mod.events:on('game.ready',function(payload)install(payload.game)end)
 return api
end
return M
