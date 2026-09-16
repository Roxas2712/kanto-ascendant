-- Add KASC retained-file inventory to the shared session without a second
-- cache or false receipts, including an older installed VASC session.
local M={}
function M.attach(session,mod,nativeInfo)
  if session.kascBundledInventory then return session.kascBundledInventory end
  local function load(name)return assert((loadstring or _G.load)(assert(mod:read('lib/'..name..'.lua')),'@'..name))()end
  local Json=load('ContentJson')
  local function encode(job)
    assert(job.packageIds[1]:match('^[a-z0-9_.-]+$'))
    return '{"schema":"ascendant-legacy-delete-v1","owner":"kasc","packageIds":["'..job.packageIds[1]..'"],"catalogSha256":"'..job.catalogSha256..'"}'
  end
  local original={read=function(_,path)return mod:read(path)end,
    info=function(_,path)return assert(nativeInfo,'missing native asset inventory')(mod,path)end}
  local inventory=load('SpriteBundledInventory').new{mod=original,pin=load('SpriteBundledManifestIndex'),decode=Json.decode,
    sha=function(raw)return love.data.encode('string','hex',love.data.hash('sha256',raw))end,
    now=love.timer.getTime,cache=session.cache,encode=encode,changed=function()session.epoch=session.epoch+1 end}
  session.kascBundledInventory=inventory
  local store,catalog=session.store,session.catalog
  function store:localStatus(id)return inventory:status(id)end
  local installed=catalog.installed
  function catalog:installed(id,s)
    if installed(self,id,s)then return true end
    local state=inventory:status(id);return state and state.complete==true or false
  end
  local mounted=store.packageMounted
  function store:packageMounted(id)
    if mounted(self,id)then return true end
    local state=inventory:status(id);return state and state.complete==true or false
  end
  local style=store.styleMounted
  function store:styleMounted(id)
    if style(self,id)then return true end
    local row=catalog.styles[id];if not row or row.kind~='download'then return false end
    if row.activationPolicy=='any-package'then
      for _,key in ipairs(row.packages)do if self:packageMounted(key)then return true end end
      return false
    end
    for _,key in ipairs(row.packages)do if not self:packageMounted(key)then return false end end
    return #row.packages>0
  end
  for _,p in ipairs(catalog.data.packages)do inventory:status(p.id)end
  local update=session.update
  function session:update(...)
    inventory:advance(128)
    return update(self,...)
  end
  local available=session.hasAvailableDownloads
  function session:hasAvailableDownloads()
    if inventory:checking()then return false end
    return available(self)
  end
  local menu=session.menu
  function session:menu(game,guided,de,rom)
    menu(self,game,guided,de,rom) -- preserve owner setup/import integration
    self.model=load('SpriteDownloadMenuModel').new(catalog,store,{language=de and 'de' or 'en',
      importIds=self.mod.id=='kanto_ascendant' and {} or {['stadium2-local']=true},
      hasPartial=function(id)return self.cache:info('sprite-content/pending/'..id)~=nil or self.cache:info('sprite-content/archive-pending/'..id)~=nil end})
    return load('SpriteContentMenu').new(mod,game,guided,de,self)
  end
  return inventory
end
return M
