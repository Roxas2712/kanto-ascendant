-- Prefer VASC's single session; own the same protocol/cache when KASC runs alone.
local M={}
function M.new(mod,archive,i18n)
 local self={}
 local nativeInfo=mod.info -- before downloaded-asset resolvers wrap the facade
 local function load(name)return assert((loadstring or _G.load)(assert(mod:read('lib/'..name..'.lua'))))()end
 local function standalone()
  if self.ownsSession then return self.session end
  if type(mod.read)~='function' or not mod.cache then return nil end
  local Compat=load('ContentCompat');local Shared=load('AscendantSharedCache')
  local session=load('AscendantContentSession').new(mod,{owner='kasc',compatPath='lib/ContentCompat.lua',
   cache=Shared.new(assert(Compat.fs())),cacheId=Shared.ID,catalogModule='SpriteCatalogData',
   downloadScreenId='KascSpriteDownloads',offerScreenId='KascSpriteOffer',includeHd=false,importIds={}})
  self.ownsSession=true;return session
 end
 function self:bind(game)
  local exports=game and game.mods and game.mods.exports
  local vasc=exports and exports.VOXEL_ASCENDANT
  local session=vasc and vasc.ascendantContent or self.session or standalone()
  if not session or type(session.rewardContent)~='function'then self.gate=nil;return false end
  if type(mod.read)=='function' and type(mod.info)=='function' and session.store and session.catalog and session.cache then
   load('SpriteBundledSession').attach(session,mod,nativeInfo)
  end
  if type(mod.read)=='function' and type(session.update)=='function'
    and session.catalog and session.catalog.data then
   load('SpriteStartupOffer').attach(session)
  end
  local gate=session:rewardContent(mod,archive,game)
  self.session=session;mod.exports.ascendantContent=session
  if self.gate~=gate then
   self.gate=gate
   -- Sprite visibility belongs to the graphics menu, independent of codes.
   -- Module initialization precedes mounting, so refresh presence once now.
   local crystal=mod.exports and mod.exports.crystalAnimation
   if crystal and crystal.refreshDownloadedAssets then crystal.refreshDownloadedAssets()end
  end
  return true
 end
 local function german()
  return i18n and i18n.isGerman and i18n.isGerman()==true or false
 end
 if mod.content and mod.content.screens then
  local function guided(m,g,spec)
   local card=mod.exports and mod.exports.fullscreenUiCard
   if card then return card.guidedList(g,spec)end
   return load('KascContentMenu').new(m,g,spec)
  end
  mod.content.screens:register('KascSpriteDownloads',{new=function(game)
   assert(self:bind(game));return self.session:menu(game,guided,german())
  end})
  mod.content.screens:register('KascSpriteOffer',{new=function(game)
   assert(self:bind(game));return self.session:offer(game,guided,german())
  end})
 end
 function self:hasAsset(path)return self.gate and self.gate:hasAsset(path)or false end
 function self:ensure(id,validated)
  if not self.gate then return false,'sprite_session_unavailable'end
  return self.gate:ensure(id,validated)
 end
 -- game.ready runs before the title/world's first draw; use its public Game.
 if mod.events and mod.events.on then mod.events:on('game.ready',function(ev)
  if ev and ev.game then self:bind(ev.game)end
 end,100)end
 -- Retry if another content provider only becomes available after game.ready.
 if mod.hooks and mod.hooks.wrap then mod.hooks:wrap('core.update',function(nextUpdate,game,dt)
  if not self.gate then self:bind(game)end
  if self.ownsSession and self.session then self.session:update(game,dt)end
  return nextUpdate(game,dt)
 end,40)end
 return self
end
return M
