-- Run with LuaJIT from the mod root. Native input coverage lives in the
-- private gameplay evidence; these assertions cover refusal/rollback paths.
local makeH=dofile('hidden_access_reveal.lua')
local R=dofile('hidden_access_return.lua')({id='kanto_ascendant'})
local flags,blocks,current,warps,gate,warpOK={}, {}, {},0,true,true
local device={isOpen=function(id)return flags[id]==true end,markOpen=function(id)flags[id]=true;return true end,registerEntrance=function()return true end}
local hooks={};local mod={content={map_scripts={register=function(_,map,hook)hooks[map]=hook end}}}
local h=makeH(mod,device,{allowSaveLocalReceipts=true,isNewGamePlus=function()return true end,prerequisite=function()return gate end,
 adapter={current=function()return current end,snapshot=function(_,d)return{mapId=d.mapId,mapIndex=d.mapIndex,edition='red',blocks=blocks,handoffClear=true}end,
 replaceBlock=function(_,p)blocks[(p.bx..':'..p.by)]=p.to;return true end,
 validateReturn=function()return true end,validateDestination=function()return true end,
 sound=function()return true end,warpTo=function()warps=warps+1;return warpOK end},
 prepareHandoff=function(game,d)return R.prepare(game,d)end,rollbackHandoff=function(game,_,token)R.rollback(game,token)end})
assert(h.register());assert(h.registerInteractions());R.bind(h.definitions())
local game={save={}}
for _,d in ipairs(h.definitions())do
 blocks={};for _,p in ipairs(d.patches)do blocks[(p.bx..':'..p.by)]=p.fromByEdition.red end
 current={mapId=d.mapId,x=d.warp.x,y=d.warp.y};assert(not h.step(game,d.mapId,current.x,current.y),'closed entry')
 current.x,current.y=d.reveal.x,d.reveal.y;assert(h.open(game,d))
 assert(not h.step(game,d.mapId,d.warp.x,d.warp.y),'stale step event')
 current.x,current.y=d.warp.x,d.warp.y
 if d.eligibility.kind~='starter'then gate=false;assert(not h.step(game,d.mapId,current.x,current.y),'live seal bypass');gate=true end
 warpOK=false;assert(not h.step(game,d.mapId,current.x,current.y));assert(not R.point(game.save,d.handoff.destination.map),'failed warp retained return')
 warpOK=true;assert(h.step(game,d.mapId,current.x,current.y),'walk-on transition')
 if d.eligibility.kind~='starter'then
  local p=assert(R.point(game.save,d.handoff.destination.map));assert(p.map==d.mapId and p.x==d.returnToKanto.x);assert(not R.point(game.save,'OTHER_MAP'));R.clear(game.save)
 end
 assert(hooks[d.mapId].onStep,'onStep absent')
 print('GUARDED_WALK_PASS',d.id)
end
local forged={modData={kanto_ascendant={hidden_access_legend_return='not-an-entrance'}}};assert(not R.point(forged,'KA_HOENN_WISH_CHAMBER'))
print('ALL_HIDDEN_ACCESS_GUARDS_PASS',warps)

-- Post-open directions remain usable on Route 14, without reopening a gate.
local memory={};local e=dofile('exploration_device.lua')({content={items={register=function()end}},save={get=function(_,k)return memory[k]end,set=function(_,k,v)memory[k]=v end}})
local map='ROUTE_14';local opened=false
assert(e.registerEntrance{id='shore',locate=function()return{distance=0,direction='south',canOpen=true}end,open=function()opened=true;return true end,
 openedGuidance=function()if opened and map=='ROUTE_14'then return{en='Follow the shore east using SURF.',de='Folge mit SURFER dem Ufer nach Osten.'}end end})
local text,meta=e.use({save={inventory={TRACE_FINDER=1}}},{message=function()end});assert(meta.opened and text:find('SURF',1,true))
text,meta=e.use({save={inventory={TRACE_FINDER=1}}},{message=function()end});assert(meta.reason=='already-open' and text:find('east',1,true))
map='OTHER';text,meta=e.use({save={inventory={TRACE_FINDER=1}}},{message=function()end});assert(meta.reason=='no-target')
print('OPENED_SHORE_GUIDANCE_PASS')
