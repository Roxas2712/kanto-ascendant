local path=assert(arg[1])
local f=assert(io.open(path,'rb'));local text=f:read('*a');f:close()
local mapping=assert(text:match('local ASCENDANT_OPTION = (%b{})'))
local first=assert(text:find('  local function handleOptionsChanged(payload)',1,true))
local last=assert(text:find('  proxy.events:on("mod.options_changed", handleOptionsChanged)',first,true))
local writes, callbacks, hooks=0,0,0
local stored={}
local proxy={id='overworld_wild_spawns'}
local mod={id='kanto_ascendant'}
local expectedKey,expectedValue
local logic={onOptionsChanged=function(_,payload)
  if payload.mod~='overworld_wild_spawns' then return end
  assert(payload.key==expectedKey,'wrong native key')
  assert(stored[expectedKey]==expectedValue,'callback read stale saved value')
  callbacks=callbacks+1
end}
local env={pairs=pairs,mod=mod,proxy=proxy,logic=logic,
  ambient={onOptionsChanged=function()end},game=function()return 'game' end,
  safe=function(_,fn,...)return fn(...)end,
  syncFeatureState=function()hooks=hooks+1 end,
  Config={setOption=function(owner,key,value,source,opts)
    assert(owner==proxy and source==mod.id and opts.game=='game')
    writes=writes+1;stored[key]=value
  end}}
local chunk=assert(loadstring('local ASCENDANT_OPTION='..mapping..'\n'..text:sub(first,last-1)..'\nreturn handleOptionsChanged,ASCENDANT_OPTION'))
setfenv(chunk,env)
local handle,keys=chunk()
local n=0
for key,ownerKey in pairs(keys)do
  for _,value in ipairs({false,true,'normal','very_high'})do
    n=n+1;expectedKey,expectedValue=key,value
    local payload={mod=mod.id,key=ownerKey,value=value}
    handle(payload)
    assert(payload.mod==mod.id and payload.key==ownerKey,'mutated engine event')
    assert(callbacks==n and writes==n,'owner setting never reached native controller')
  end
end
assert(hooks==4,'master toggle hook state not synchronized')
handle({mod=mod.id,key='unrelated',value=true})
assert(callbacks==n and writes==n,'unrelated option touched wilds')
print('PASS embedded Wilds: '..n..' translated option changes, storage before callback, payload isolation and master hooks')
