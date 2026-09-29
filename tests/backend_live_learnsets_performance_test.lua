local make=assert(loadfile('backend_live_learnsets_67.lua'))()
local moves={};for i=1,80 do moves['M'..i]={}end
local pokemon={A={dex=1},B={dex=2}}
local rows={}
for _,id in ipairs{'A','B'}do
 rows[id]={level1Moves={'M1'},learnset={{level=8,move='M2'}},tmhm={},egg={'M3'},tutor={'M4'},unavailable={}}
 for i=1,90 do rows[id].tmhm[i]='M'..(i%50+1)end
end
local historical={}
for n=1,5 do
 local r={tmhm={},tutor={'M4'},level1Moves={'M5'},learnset={{level=10,move='M6'}}}
 for i=1,90 do r.tmhm[i]='M'..((i+n*7)%80+1)end
 historical[n]=r
end
local game={data={pokemon=pokemon,moves=moves}}
local eggs={};local field={starterFamilies={M79={'A'}},goldTM={move='M80'},tm54Family={'B'}}
local rules={resolve=function()return {activeEpoch=1,extensionsEnabled=true}end,moveAvailable=function(id)return moves[id]~=nil end}
local L=make{rules=rules,eggMoves=eggs,fieldTech=field,catalog={entries={A={originGeneration=1},B={originGeneration=7}}},
 species={bySpecies={A='A',B='B'},projectLearnset=function(key)return rows[key]end,historicalLearnsets=function()return historical end}}
for _,missing in ipairs{false,true,false}do
 if missing then moves.M4=nil;moves.M79=nil else moves.M4={};moves.M79={}end
 local expected={}
 for _,id in ipairs{'A','B'}do
  local list={};for _,row in ipairs(L.rowsFor(game,id,'M',1))do list[#list+1]=row.id end;expected[id]=list
 end
 assert(L.apply(game,1))
 for id,list in pairs(expected)do
  assert(#pokemon[id].tmhm==#list)
  for i,move in ipairs(list)do assert(pokemon[id].tmhm[i]==move,'machine order/filter changed')end
 end
 -- Registry output must never alias the projection caches.
 pokemon.A.level1Moves[1]='changed';pokemon.A.learnset[1].level=99;eggs[1][1]='changed'
 assert(rows.A.level1Moves[1]=='M1' and rows.A.learnset[1].level==8 and rows.A.egg[1]=='M3')
end
-- Authored machines absent from history are added only for their family.
moves.SIGNATURE={};field.starterFamilies.SIGNATURE={'A'}
assert(L.apply(game,1));assert(pokemon.A.tmhm[#pokemon.A.tmhm]=='SIGNATURE')
for _,move in ipairs(pokemon.B.tmhm)do assert(move~='SIGNATURE')end
print('PASS machine projection: rowsFor oracle, duplicates, order, live removals/restoration, cache isolation, authored family extra')
