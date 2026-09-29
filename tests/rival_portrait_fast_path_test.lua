local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function loader(path)
 local s=read(path);local a=assert(s:find('  local function installRivalPresentation',1,true));local b=assert(s:find('  local function restoreRivalPresentation',a,true))
 return assert((loadstring or load)('return function(M,runtimeVisualPath,voxelBattleUsesStandingTrainer,rivalPicBaseline,RIVAL_CLASSES)\n'..s:sub(a,b-1)..'\nreturn installRivalPresentation end'))()
end
local current=loader('extended_characters.lua')
local reference=loader(assert(os.getenv('QA_CHARACTER_REFERENCE')))
local function run(factory,portrait,standing,enabled)
 local calls=0;local baseline={};local data={trainers={RIVAL1={pic='original',trueColor=false},RIVAL2={pic='other',ascendantCharacter='OLD'}}}
 local fn=factory({getCharacterSprite=function(_,state)return state=='voxelFront'and standing or portrait end},function(v)return v and v.path end,
  function()calls=calls+1;return enabled end,baseline,{'RIVAL1','RIVAL2','RIVAL3'})
 fn({data=data},'BLUE');fn({data=data},'BLUE')
 local out={};for _,id in ipairs{'RIVAL1','RIVAL2'}do local t=data.trainers[id];local b=baseline[t]
  out[#out+1]=table.concat({tostring(t.pic),tostring(t.trueColor),tostring(t.ascendantCharacter),tostring(b.pic),tostring(b.trueColor),tostring(b.character)},':')end
 return table.concat(out,'|'),calls
end
for _,enabled in ipairs{false,true}do
 for _,paths in ipairs{{'same','same'},{'normal','standing'}}do
  local p,s={path=paths[1]},{path=paths[2]}
  local a,ca=run(current,p,s,enabled);local b,cb=run(reference,p,s,enabled)
  assert(a==b,'portrait/baseline changed')
  assert(cb==2 and ca==(paths[1]==paths[2]and 0 or 2),'wrong staging boundary')
 end
end
print('PASS rival portrait: identical pictures avoid arena work; distinct pictures preserve staging decision; trainer identity/color and restoration baseline unchanged')
