-- Only invoked by the player's LOG EXPORT action. Fixed export names.
local body,result=...
require('love.filesystem')
require('love.system')
require('love.thread')
local ok,code=pcall(function()
  assert(type(body)=='string' and #body<=66000 and body:match('^KASC HD download log v1\n'),'invalid log')
  local name='KASC-HD-DOWNLOAD-LOG.txt'
  assert(love.filesystem.createDirectory('exports'))
  assert(love.filesystem.write('exports/'..name,body))
  local platform=love.system.getOS()
  if (platform=='Android' or platform=='iOS') and type(love.system.createFile)=='function'then
    -- Same staging contract as the engine's save-file export picker.
    assert(love.filesystem.write('pending_export.sav',body))
    if love.system.createFile(name,love.filesystem.getSaveDirectory())then return 'picker_opened'end
  end
  local dir=love.filesystem.getSaveDirectory()..'/exports'
  dir=dir:gsub('\\','/'):gsub('([^%w%-%._~/:])',function(c)return ('%%%02X'):format(c:byte())end)
  local url=(dir:sub(1,1)=='/' and 'file://' or 'file:///')..dir
  if love.system.openURL(url)then return 'folder_opened'end
  return 'export_saved'
end)
result:push({status=ok and 'ok' or 'error',message=ok and code or 'export_failed'})
