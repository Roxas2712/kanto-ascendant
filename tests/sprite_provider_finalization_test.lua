local V={require=function(name)
 if name=='config'then return {debug=function()return false end}end
 return {}
end}
local Providers=assert(loadfile('vendor/wilds_1_12_2/lib/sprite_providers.lua'))(V)
local probes=0
local function provider(fail)
 return {id='gold',isAvailable=function()return true end,resolve=function()end,
 refreshAvailability=function()probes=probes+1;if fail and fail()then error('not ready')end;return false end}
end
local p=setmetatable({providers={}},Providers)
assert(p:register(provider()))
local map={id='CITY'};local game={overworld={map=map}}
p:ensureFinalized(game);assert(probes==1)
for i=1,100 do p:ensureFinalized(game)end
assert(probes==1,'same-map spawn burst rediscovered sources')
p:finalize(game);assert(probes==2,'explicit refresh was cached')
game.overworld.map={id='CITY'};p:ensureFinalized(game);assert(probes==3,'reloaded map used old receipt')
game.overworld.map={id='ROUTE'};p:ensureFinalized(game);assert(probes==4)
local game2={overworld=game.overworld};p:ensureFinalized(game2);assert(probes==5,'new game used old receipt')
p:register(provider());p:ensureFinalized(game2);assert(probes==6,'replacement source not reprobed')
assert(p:unregister('gold'));assert(not p.finalized);p:ensureFinalized(game2);assert(probes==6)
local fail=true;p:register(provider(function()return fail end))
p:ensureFinalized(game2);assert(probes==7 and not p.finalized)
fail=false;p:ensureFinalized(game2);assert(probes==8 and p.finalized,'failed discovery not retried')
p:ensureFinalized(game2);assert(probes==8)
p:ensureFinalized({});p:ensureFinalized({});assert(probes==10,'unknown world was retained')
p:ensureFinalized(nil);p:ensureFinalized(nil);assert(probes==12)
local Render=assert(loadfile('vendor/wilds_1_12_2/lib/spawn_render.lua'))(V)
local wraps,legacy=0,0
local r=setmetatable({spriteProviders=p,installLateMakeEntityWrap=function()wraps=wraps+1 end},Render)
p:finalize(game2);local before=probes
for i=1,50 do r:ensureStyleOwnedMakeEntity(game2)end
assert(wraps==50 and probes==before,'late owner wrapper was skipped or discovery repeated')
r:finalizeSpriteProviders(game2);assert(probes==before+1 and wraps==51)
r.spriteProviders={finalize=function()legacy=legacy+1 end}
r:ensureStyleOwnedMakeEntity(game2);assert(legacy==1 and wraps==52,'compat registry lost finalize')
print('PASS source discovery receipt: maps, reloads, games, registry changes, failures, explicit refresh and per-spawn wrapper preservation')
