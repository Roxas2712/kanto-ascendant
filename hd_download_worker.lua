-- Source-only one-shot worker. No idle loop survives game shutdown.
local url,seconds,result=...
require('love.filesystem')
require('love.system')
require('love.thread')
local ok,body,err=pcall(function()
  local origin,path
  if type(url)=='string'then origin,path=url:match('^(https://[^/]+)(/.*)$')end
  assert(origin=='https://vasc-downloads.ascendant-content.workers.dev'
    or origin=='https://vasc-content.maarten-paus.chatgpt.site','unapproved HD origin')
  assert(path and not path:find('[%s?#]'),'invalid HD route')
  local Host=assert(love.filesystem.load('src/core/HostShell.lua'))()
  local popen=Host.popen
  function Host.popen(command,mode,options)
    if love.system.getOS()=='Windows' and mode=='r' then mode='rb'end
    return popen(command,mode,options)
  end
  return Host.httpGet(url,'gen1recomp-mod/VOXEL_ASCENDANT',nil,seconds)
end)
if not ok then err=body;body=nil end
if type(body)=='string' and #body>4*1024*1024 then body=nil;err='Response exceeds content limit'end
result:push(body and {status='ok',body=body} or {status='error',err=tostring(err or 'Network unavailable')})
