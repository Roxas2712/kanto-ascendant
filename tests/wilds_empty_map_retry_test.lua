local Config={debug=function()return false end,devMode=function()return false end,STATE={}}
local modules={config=Config}
local V={require=function(n)return modules[n]or{}end}
modules.encounter_pick=assert(loadfile('vendor/wilds_1_12_2/lib/encounter_pick.lua'))(V)
local Logic=assert(loadfile('vendor/wilds_1_12_2/lib/spawn_logic.lua'))(V)
local game={data={encounters={}}};local ow={map={id='CITY'}}
local calls,contacts=0,0
local state={initialized=false,mapId='CITY',unsupportedReason='no supported encounter surface',updateCallbackCount=0}
local l=setmetatable({mod={world={game=game,overworld=function()return ow end}},state=state,activeMapId='CITY',stepsOnMap=0,
 featureActive=function()return true end,initializeForMap=function()calls=calls+1 end,
 _spawnAt=function()contacts=contacts+1 end,_despawnFar=function()end,_wander=function()end},Logic)
local ev={mapId='CITY',x=2,y=3}
for i=1,100 do l:onStepped(ev)end
assert(calls==0 and contacts==100 and l.stepsOnMap==100 and state.updateCallbackCount==100,'empty city repeats init or skips step semantics')
local enc={fishing={slots={{species='MAGIKARP'}},rate=1}};game.data.encounters.CITY=enc
l:onStepped(ev);assert(calls==0,'rod-only table triggered visible spawn init')
enc.grass={rate=0,slots={{species='PIDGEY'}}};l:onStepped(ev);assert(calls==0)
enc.grass.rate=1;l:onStepped(ev);assert(calls==1,'in-place rate activation missed')
enc.grass.slots={};l:onStepped(ev);assert(calls==1)
enc.grass.slots[1]={species='PIDGEY'};l:onStepped(ev);assert(calls==2,'in-place slots activation missed')
enc.grass=nil;enc.water={rate=1,slots={{species='POLIWAG'}}};l:onStepped(ev);assert(calls==3,'water activation missed')
game.data.encounters={};l:onStepped(ev);assert(calls==3)
state.lastError='assets unavailable';l:onStepped(ev);assert(calls==4,'transient failure not retried')
state.lastError=nil;state.unsupportedReason='no eligible encounter tiles';l:onStepped(ev);assert(calls==5,'occupancy retry lost')
state.unsupportedReason='no supported encounter surface';state.mapId='OLD';l:onStepped(ev);assert(calls==6,'old receipt suppressed init')
state.mapId='CITY';game.data=nil;l:onStepped(ev);assert(calls==6)
print('PASS empty-map retry: step semantics, absent/rod/disabled tables, live rate/slot/water activation, table replacement, transient failures and map identity')
