-- Inspect retained mod files through the supported read-only asset API.
-- Presence is never represented as a verified DLC receipt. Physical deletion
-- requires the closed-game desktop helper; the sandbox never removes assets.
local M={REQUEST='sprite-content/bundled-removal-request-v1.json'}
function M.new(d)
  local raw=assert(d.mod:read(d.pin.path),'missing bundled inventory index')
  assert(d.sha(raw)==d.pin.sha256,'bundled inventory index changed')
  local index=d.decode(raw);assert(index.schema=='ascendant.bundled-manifest-index/v1' and index.owner=='kasc')
  local pins={};for _,p in ipairs(index.packages)do pins[p.id]=p end
  local self={states={},queue={},cursor=1,indexSha256=d.pin.sha256}
  local function safe(path)
    return type(path)=='string' and not path:find('..',1,true) and not path:find('//',1,true)
      and path:match('^[%w_./-]+$') and path:sub(1,1)~='/'
      and not path:match('^assets/characters/') and not path:match('^assets/ui/')
      and not path:match('^assets/title_trainers_67/') and not path:match('^assets/journeys_balls/')
      and (path:match('^assets/') or path:match('^vendor/wilds_1_12_2/assets/'))
      and (path:match('%.png$') or path:match('%.gif$') or path:match('%.webp$') or path:match('%.jpg$'))
  end
  function self:status(id)
    if not pins[id] then return nil end
    if not self.states[id] then
      self.states[id]={id=id,present=0,total=0,checked=0,checking=true,complete=false}
      self.queue[#self.queue+1]=id
    end
    return self.states[id]
  end
  function self:checking()return self.cursor<=#self.queue end
  function self:prioritize(id)
    local state=self:status(id);if not state or not state.checking then return end
    for i=self.cursor,#self.queue do if self.queue[i]==id then
      self.queue[i],self.queue[self.cursor]=self.queue[self.cursor],self.queue[i];return
    end end
  end
  function self:advance(limit)
    local deadline=d.now and d.now()+0.004
    for _=1,limit or 128 do
      local id=self.queue[self.cursor];if not id then return end
      local state=self.states[id]
      if not state.files then
        local pin=pins[id];local data=assert(d.mod:read('assets/sprite-package-manifests/'..pin.manifestSha256..'.json'))
        assert(#data==pin.manifestBytes and d.sha(data)==pin.manifestSha256,'bundled manifest changed')
        local manifest=d.decode(data);assert(manifest.id==id)
        state.files={}
        for _,file in ipairs(manifest.files)do if file.owner=='kasc' then
          assert(safe(file.logicalPath),'non-Pokemon inventory path')
          state.files[#state.files+1]=file.logicalPath
        end end
        state.total=#state.files
      end
      local path=state.files[state.checked+1]
      if path then
        local ok,info=pcall(d.mod.info,d.mod,path)
        if not ok then state.failed=true end
        if ok and info and info.type=='file' and (info.size==nil or info.size>0) then state.present=state.present+1 end
        state.checked=state.checked+1
      end
      if state.checked>=state.total then
        state.checking=false;state.complete=not state.failed and state.total>0 and state.present==state.total
        state.partial=state.present>0 and not state.complete
        state.files=nil;self.cursor=self.cursor+1
        if d.changed then d.changed()end
      end
      if deadline and d.now()>=deadline then return end
    end
  end
  function self:pending()
    local data=d.cache:read(M.REQUEST);if type(data)~='string' then return nil end
    local ok,job=pcall(d.decode,data)
    if ok and type(job)=='table' and job.schema=='ascendant-legacy-delete-v1'
      and job.owner=='kasc' and job.catalogSha256==self.indexSha256 and type(job.packageIds)=='table' then return job end
    return nil,'invalid_bundled_removal_request'
  end
  function self:request(id,consent)
    if consent~=true then return false,'confirmation_required' end
    local state=self:status(id)
    if not state or state.checking then return false,'bundled_inventory_checking' end
    if state.failed then return false,'inventory_incomplete' end
    if state.present==0 then return false,'not_installed' end
    local old,err=self:pending();if err then return false,err end
    if old and old.packageIds[1]~=id then
      local previous=self:status(old.packageIds[1])
      if not previous or previous.checking or previous.present>0 then return false,'bundled_removal_pending' end
    end
    local data=d.encode({schema='ascendant-legacy-delete-v1',owner='kasc',packageIds={id},catalogSha256=self.indexSha256})
    if d.cache:write(M.REQUEST,data)~=true or d.cache:read(M.REQUEST)~=data then return false,'queue_write_failed' end
    return true,'bundled_removal_pending'
  end
  function self:cancel(id)
    local job,err=self:pending();if err then return false,err end
    if not job or job.packageIds[1]~=id then return false,'not_installed' end
    if d.cache:remove(M.REQUEST)~=true or d.cache:read(M.REQUEST)~=nil then return false,'queue_remove_failed' end
    return true,'bundled_removal_cancelled'
  end
  return self
end
return M
