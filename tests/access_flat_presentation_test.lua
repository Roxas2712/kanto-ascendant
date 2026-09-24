local now,depth,rects,draws=0,0,0,0
local noop=function()end
love={timer={getTime=function()return now end},graphics={
 push=function()depth=depth+1 end,pop=function()depth=depth-1 end,
 setShader=noop,setColor=noop,translate=noop,rotate=noop,
 rectangle=function()rects=rects+1 end}}
local unlocked=false
local game={save={}}
local map={id='TEST',inBounds=function()return true end,isWaterCell=function(_,x)return x==19 end}
local ow={map=map}
local OW={drawShipAnim=function()draws=draws+1 end}
package.loaded['src.world.OverworldController']=OW
local mod={exports={hiddenAccessReveal={wayfinding=function()
 return unlocked and{{kind='entrance',x=19,y=51,facing='east',lit=true}}or{}
end}}}
local M=dofile('world_access_presentation.lua')(mod)
M.install(game);M.install(game)
OW.drawShipAnim(ow,100,200);assert(rects==0 and draws==1 and depth==0,'closed entry leaked or hook stacked')
unlocked=true;now=.3;OW.drawShipAnim(ow,100,200)
assert(rects==8 and draws==2 and depth==0,'2D water must show two pixel buoys')
mod.exports.starterHabitats={maps={TEST={exit={x=8,y=13}}}}
now=.6;local before=rects;OW.drawShipAnim(ow,100,200)
assert(rects>before+8 and depth==0,'2D habitat EXIT lettering missing')
unlocked=false;mod.exports.starterHabitats=nil;game.save={}
before=rects;OW.drawShipAnim(ow,100,200);assert(rects==before,'new save retained markers')
print('PASS native 2D buoys/EXIT without VASC, hook idempotence, hidden gates and graphics stack')
