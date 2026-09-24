local progress,writes,warps={},0,{}
local S=dofile('hoenn_research_sanctums_67.lua')({id='kanto_ascendant',
 world={warpTo=function(_,map,x,y)warps[#warps+1]={map,x,y};return true end}},
 {dex={},geometry={},runEvents={
  progress=function(_,id)return progress[id]end,
  completed=function()return false end,
  setProgress=function(_,id,value)writes=writes+1;progress[id]=value;return true end}})
local game={save={}}
for _,row in ipairs(S.rows)do
 local key='REGI_PUZZLE_'..row.species
 local before=writes
 assert(not S.accessLight(game,row.species));assert(writes==before and progress[key]==nil,'drawing initialized a quest')
 progress[key]={solved=true}
 assert(S.accessLight(game,row.species) and writes==before,'drawing wrote progress')
 -- Completed seals must still have a working walk-through exit.
 assert(S.onStep(game,row,{},8,13));assert(warps[#warps][1]==row.sourceMap)
 assert(progress[key].solved,'leaving cleared a completed seal')
 progress[key]={solved=false,armed=true,cursor=2}
 assert(S.onStep(game,row,{},8,13));assert(not progress[key].armed,'leaving retained an unfinished attempt')
 progress={};assert(not S.accessLight(game,row.species),'next journey retained a light')
end
local eligible=true
local A=dofile('hoenn_endgame_access_67.lua')({id='kanto_ascendant'},
 {regis={available=function()return eligible end,accessLight=function()return false end},
 moltres={ASCENT_MAP='VOLCANO',eventComplete=function()return true end},birth={},placement={},
 postgame={hasHallOfFame=function()return true end}})
game.data={maps={SEAFOAM_ISLANDS_B4F={objects={{runtime=true,owner='kanto_ascendant',
 name='KA_HIDDEN_REGICE_SCIENTIST',x=22,y=2}}}}}
local marks=A.wayfinding(game,'SEAFOAM_ISLANDS_B4F')
assert(#marks==1 and marks[1].x==22 and not marks[1].lit,'marker ignored safe-placement fallback')
eligible=false;assert(#A.wayfinding(game,'SEAFOAM_ISLANDS_B4F')==0,'unavailable quest leaked a marker')
assert(A.researchHint(game)=='','hint leaked an unavailable quest')
print('PASS Regi read-only lights, current-run gates, relocated researcher and completed/unfinished walk-out')
