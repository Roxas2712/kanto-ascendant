-- KASC-owned HD transport and diagnostic integration for public VASC.
-- Uses declared compute/network permissions; no game executable is modified.
return function(mod,Log)
  local Net=require('src.mods.Net')
  local Version=require('src.core.Version')
  local platform=love.system.getOS()
  local now=function()return love.timer.getTime()end
  local diag=Log.new({cache=mod.cache,version=mod.version,engineVersion=Version.engine,platform=platform,now=now})
  local self={diagnostics=diag,active=true,version='6.7.4'}
  local Screens=require('src.ui.Screens')
  local jobs,workers,attached={},{},{}
  local source=assert(mod:read('hd_download_worker.lua'))
  if Net._kascHdSupport then Net._kascHdSupport.close()end
  local original={get=Net.get,poll=Net.poll,release=Net.release,cancel=Net.cancel,releaseAll=Net.releaseAll}
  local wrappers={}
  local originalBuild=Screens.build
  local buildWrapper
  local exportJob
  local function route(url)
    if type(url)~='string'then return end
    local origin,path=url:match('^(https://[^/]+)(/.*)$')
    local host=origin=='https://vasc-downloads.ascendant-content.workers.dev' and 'primary'
      or origin=='https://vasc-content.maarten-paus.chatgpt.site' and 'fallback'
    if not host then return end
    if path=='/catalog.json'then return host,'catalog'end
    local digest=path:match('^/manifests/([0-9a-f]+)%.json$')
    if digest and #digest==64 then return host,'manifest'end
    digest=path:match('^/blobs/sha256/([0-9a-f]+)$')
    if digest and #digest==64 then return host,'chunk'end
    digest=path:match('^/downloads/start/([0-9a-f]+)$')
    if digest and #digest==64 then return host,'start'end
    digest=path:match('^/downloads/complete/([0-9a-f]+)$')
    if digest and #digest==48 then return host,'complete'end
  end
  local function event(name,fields)pcall(diag.event,diag,name,fields)end
  local function failEvent(reason)
    local fields=Log.error(reason);event('failed',fields)
  end
  local function collect()
    local count=0
    for job in pairs(workers)do
      local response=job.channel:pop()
      local running=job.thread:isRunning()
      if not response and not running and job.state.status=='pending'then
        response={status='error',err=job.thread:getError() or 'Network polling failed'}
      end
      if response and job.state.status=='pending'then
        job.state=response
        if job.step=='export'then self.exportStatus=response.message or 'export_failed'end
        local fields=response.status=='ok' and {} or Log.error(response.err)
        fields.source=job.source;fields.step=job.step;fields.status=response.status
        fields.received_bytes=type(response.body)=='string' and #response.body or 0
        fields.elapsed_ms=math.floor(math.max(0,now()-job.started)*1000)
        event('response',fields)
      end
      if running then count=count+1 else workers[job]=nil end
    end
    return count
  end
  local function owns(loader,id,handle)
    local job=jobs[handle]
    return job and job.loader==loader and job.modId==id and job or nil
  end
  wrappers.get=function(loader,id,url,opts)
    local host,step=route(url)
    if not self.active or id~='VOXEL_ASCENDANT' or not host then return original.get(loader,id,url,opts)end
    self.attach()
    opts=type(opts)=='table' and opts or {}
    if collect()>=4 then return nil,'HD download workers busy; try again'end
    local seconds=math.min(30,math.max(1,tonumber(opts.maxSeconds) or 30))
    if not diag.active then diag:begin('download','kasc-binary-worker')end
    local channel=love.thread.newChannel()
    local job={loader=loader,modId=id,channel=channel,state={status='pending'},source=host,step=step,started=now()}
    local ok,why=pcall(function()
      job.thread=love.thread.newThread(source)
      job.thread:start(url,seconds,channel)
    end)
    if not ok then failEvent(why);return nil,tostring(why)end
    local handle={};jobs[handle]=job;workers[job]=true
    event('request',{source=host,step=step})
    return handle
  end
  wrappers.poll=function(loader,id,handle)
    local job=owns(loader,id,handle)
    if not job then return original.poll(loader,id,handle)end
    collect();local state=job.state
    return {status=state.status,body=state.body,err=state.err}
  end
  wrappers.cancel=function(loader,id,handle)
    local job=owns(loader,id,handle)
    if not job then return original.cancel(loader,id,handle)end
    job.state={status='cancelled'};event('cancelled',{source=job.source,step=job.step});return true
  end
  wrappers.release=function(loader,id,handle)
    if not owns(loader,id,handle)then return original.release(loader,id,handle)end
    jobs[handle]=nil;collect();return true
  end
  function self.export()
    if not self.active then return false end
    if exportJob and exportJob.thread:isRunning()then return false end
    local ok,body=pcall(mod.cache.read,mod.cache,Log.PATH)
    if not ok or type(body)~='string' or #body>32768 or not body:match('^KASC HD download log v1\n')then
      self.exportStatus='no_log';return false
    end
    local previousOk,previous=pcall(mod.cache.read,mod.cache,Log.PREVIOUS)
    if previousOk and type(previous)=='string' and #previous<=32768 and previous:match('^KASC HD download log v1\n')then
      body=body..'\n--- PREVIOUS ATTEMPT / VORHERIGER VERSUCH ---\n'..previous
    end
    local channel=love.thread.newChannel()
    local job={channel=channel,state={status='pending'},source='local',step='export',started=now()}
    local started=pcall(function()
      job.thread=love.thread.newThread(assert(mod:read('hd_download_export.lua')))
      job.thread:start(body,channel)
    end)
    if not started then self.exportStatus='export_failed';return false end
    exportJob=job;workers[job]=true;self.exportStatus='exporting';return true
  end
  buildWrapper=function(game,id,...)
    local menu=originalBuild(game,id,...)
    if not self.active or id~='VascPokemonHdDownloads' or type(menu)~='table' or type(menu.items)~='table'then return menu end
    local de=menu.items[1] and menu.items[1].label=='DOWNLOAD-STATUS'
    local row={label=de and 'DOWNLOADLOG EXPORTIEREN' or 'EXPORT DOWNLOAD LOG',action='kasc_hd_export'}
    local function addRow()
      local exists=false
      for _,item in ipairs(menu.items)do if item==row then exists=true end end
      if not exists then table.insert(menu.items,math.min(4,#menu.items+1),row)end
      row.right=diag.saved and (de and 'BEREIT' or 'READY') or '--'
      row.help='KASC-HD-DOWNLOAD-LOG.txt\n\n'..(de
        and 'A exportiert das Downloadlog mit dem vorherigen Versuch. Am Handy Speicherort waehlen; am PC oeffnet sich der Exportordner.'
        or 'A exports the download log including the previous attempt. Choose a location on mobile; the export folder opens on desktop.')
      local status=self.exportStatus
      if status=='no_log'then row.help=de and 'Noch kein Log. Zuerst einen HD-Download versuchen.' or 'No log yet. Try an HD download first.'
      elseif status=='export_failed' or diag.failed then row.help=de and 'Log konnte nicht gespeichert oder exportiert werden.' or 'Could not save or export the log.'
      elseif status=='picker_opened'then row.right=de and 'SPEICHERN' or 'SAVE'
      elseif status=='folder_opened' or status=='export_saved'then row.right=de and 'EXPORTIERT' or 'EXPORTED'
      elseif status=='exporting'then row.right='...'end
    end
    local update,choose=menu.update,menu.onChoose
    menu.update=function(owner,...)
      local a,b;if update then a,b=update(owner,...)end;collect();addRow();return a,b
    end
    menu.onChoose=function(item,...)
      if item==row then self.export();addRow();return end
      if choose then return choose(item,...)end
    end
    addRow();return menu
  end
  Screens.build=buildWrapper
  function self.attach()
    if not self.active then return end
    local vasc=mod:find('VOXEL_ASCENDANT')
    local api=vasc and vasc.exports and vasc.exports.pokemonHdContent
    local d=api and api.downloader and api.downloader()
    if not d or attached[d]then return end
    local old={check=d.check,start=d.start,update=d.update,cancel=d.cancel}
    if type(old.check)~='function' or type(old.start)~='function' or type(old.update)~='function' or type(old.cancel)~='function'then return end
    attached[d]=old;d.kascDownloadLog=diag
    local function begin(action)
      self.exportStatus=nil
      diag:begin(action,'kasc-binary-worker')
      if d.status=='error' or d.status=='cancelled'then
        d.usingFallback=nil;if d.warnings then d.warnings.fallback_used=nil end
      end
    end
    local function outcome(previous)
      if d.status=='error' and previous~='error'then failEvent(d.message)
      elseif d.status=='ready' and previous~='ready'then event('complete',{done_bytes=d.doneBytes})end
    end
    old.checkWrapper=function(owner,...)
      if not owner:busy()then begin('check')end
      local before=owner.status;local a,b=old.check(owner,...);outcome(before);return a,b
    end
    old.startWrapper=function(owner,generation,packageId,consent)
      if consent==true and not owner:busy()then begin('download')end
      local before=owner.status;local a,b=old.start(owner,generation,packageId,consent);outcome(before);return a,b
    end
    old.updateWrapper=function(owner,...)
      local before=owner.status;local a,b=old.update(owner,...);outcome(before);return a,b
    end
    old.cancelWrapper=function(owner,...)
      if owner:busy()then event('cancelled',{done_bytes=owner.doneBytes})end
      return old.cancel(owner,...)
    end
    d.check,d.start,d.update,d.cancel=old.checkWrapper,old.startWrapper,old.updateWrapper,old.cancelWrapper
  end
  function self.close()
    if not self.active then return end
    self.active=false
    for _,job in pairs(jobs)do job.state={status='cancelled'}end
    for job in pairs(workers)do job.state={status='cancelled'}end
    jobs={}
    for d,old in pairs(attached)do
      for _,key in ipairs({'check','start','update','cancel'})do
        if d[key]==old[key..'Wrapper']then d[key]=old[key]end
      end
      d.kascDownloadLog=nil
    end
    attached={}
    if Screens.build==buildWrapper then Screens.build=originalBuild end
    for key,fn in pairs(wrappers)do if Net[key]==fn then Net[key]=original[key]end end
    if Net._kascHdSupport==self then Net._kascHdSupport=nil end
  end
  wrappers.releaseAll=function(loader,id)
    for handle,job in pairs(jobs)do
      if job.loader==loader and job.modId==id then job.state={status='cancelled'};jobs[handle]=nil end
    end
    if id==mod.id then self.close()end
    return original.releaseAll(loader,id)
  end
  for key,fn in pairs(wrappers)do Net[key]=fn end
  Net._kascHdSupport=self
  require('src.core.SessionLifecycle').registerProcessShutdown(function()
    self.close()
    for job in pairs(workers)do pcall(job.thread.wait,job.thread)end
    workers={}
  end)
  mod.events:on('game.ready',self.attach,100)
  mod.hooks:wrap('core.update',function(nextFn,...)
    if next(workers)then collect()end
    return nextFn(...)
  end)
  return self
end
