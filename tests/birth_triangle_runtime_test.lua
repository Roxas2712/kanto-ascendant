local root=assert(arg[1]);local data={};local ready=false;local fights=0
local mod={id='kanto_ascendant',save={get=function(_,k)return data[k]end,set=function(_,k,v)data[k]=v end}}
local events=assert(loadfile(root..'/hoenn_endgame_run_events_67.lua'))()(mod)
local stack={}
function stack:push(v)self.last=v end
package.loaded['src.render.TextBox']={new=function(game,text,done,opts)return{text=text,done=done,choice=opts and opts.choice}end}
local battleState={newWild=function(game,species,level,options)
 assert(species=='DEOXYS'and level==30 and options.randomizerProtected)
 fights=fights+1;return{enemy={mon={species=species,level=level}}}
end}
local B=assert(loadfile(root..'/hoenn_birth_island_67.lua'))()(mod,{
 dex={report=function()return{birthIslandReady=ready}end,record=function()end},runEvents=events,battleState=battleState})
local game={save={party={}},stack=stack,writeSave=function()return true end}
B.install(game,{mapScripts={},battleState=battleState})
assert(not B.available(game));ready=true;assert(not B.available(game))
events.mark(game,'MOLTRES',{});assert(not B.available(game),'Regirock gate bypassed')
events.mark(game,'REGIROCK',{});assert(B.available(game))
ready=false;assert(not B.available(game),'Dex gate bypassed');ready=true
local npc={def={name='KA_HOENN_BIRTH_TRIANGLE'},cellX=8,cellY=8,px=128,py=128,moving=true,targetX=9,progress=8}
local ow={npcs={npc},pushBattle=function(_,battle)game.battle=battle end,afterBattle=function()end}
B.syncTriangle(ow)
for step,p in ipairs(B.trianglePositions)do
 assert(npc.cellX==p[1]and npc.cellY==p[2]and npc.px==p[1]*16 and npc.py==p[2]*16,'stale collision/render coordinates')
 assert(not npc.moving and npc.targetX==nil and npc.targetY==nil and npc.progress==0)
 B.triangleTalk(game,ow,npc,function()end)
 if step<#B.trianglePositions then
  assert(events.progress(game,'DEOXYS_TRIANGLE')==step)
 else assert(stack.last.done);stack.last.done()end
end
assert(fights==1 and game.battle.kaBirthIslandDeoxys)
assert(not B.recordCatch(game,game.battle.enemy.mon),'unstored enemy counted as capture')
game.save.party[1]=game.battle.enemy.mon;game.battle.onFinish('caught')
assert(B.caught(game));B.triangleTalk(game,ow,npc);assert(fights==1,'completed encounter started again')
print('PASS Birth Island gates, six real collision/render positions, pending movement reset, battle and capture ownership')
