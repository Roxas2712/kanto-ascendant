local G=assert(loadfile('generation_rules.lua'))()({exports={}},{
 evidence={},migration={SAVE_KEY='generation_rules'},moveMemory={},receipts={},
 typeProjection={projectSpecies=function(_,types)return types end,moveType=function(_,t)return t end,moveCategory=function(_,_,c)return c end}})
local game={save={},data={pokemon={},moves={A={originEpoch=1},B={originEpoch=2}}}}
for i=1,100 do game.data.pokemon['P'..i]={types={'NORMAL'},level1Moves={'A','B','MISSING'},learnset={{level=4,move='B'}},tmhm={'A','B'}}end
local raw=G.moveAvailable;local calls={}
G.moveAvailable=function(id,...)calls[id]=(calls[id]or 0)+1;return raw(id,...)end
local function sync(era)
 calls={};assert(G.syncData(game,{activeEpoch=era,extensionsEnabled=false}))
 assert(calls.A==1 and calls.B==1 and calls.MISSING==1,'move eligibility must be once per ID per projection')
end
sync(1);assert(#game.data.pokemon.P1.level1Moves==1 and #game.data.pokemon.P1.learnset==0)
sync(2);assert(#game.data.pokemon.P1.level1Moves==2 and #game.data.pokemon.P1.learnset==1)
game.data.moves.B.originEpoch=1;sync(1);assert(#game.data.pokemon.P1.level1Moves==2,'same-epoch data edit stayed cached')
game.data.moves.B=nil;sync(1);assert(#game.data.pokemon.P1.level1Moves==1,'removed move stayed cached')
game.data.moves.B={originEpoch=1};sync(1);assert(#game.data.pokemon.P1.level1Moves==2,'restored move stayed unavailable')
print('PASS projection cache: once per ID/pass, epoch up/down, same-epoch edits, missing and restored moves')
