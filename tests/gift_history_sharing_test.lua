local factory=assert(loadfile('backend_gift_profiles_67.lua'))()
local rows={['dex:1']={nationalDex=1,originGeneration=1,names={en='One',de='Eins'}},
 ['dex:2']={nationalDex=2,originGeneration=3,names={en='Two',de='Zwei'}}}
local projections=0
local species={byKey={['dex:1']='ONE'},pending={['dex:2']='unimplemented'},
 moveRevision=function(id)return ({OLD=1,NEW=2,LATE=34,LEVEL=1,FUTURE=35})[id]end,
 projectLearnset=function(key,epoch)
  projections=projections+1
  if key=='dex:2'then return nil,'missing' end
  return{generation=epoch,versionGroup=epoch*10,level1Moves={'OLD','NEW','OLD','LATE','FUTURE'},
   learnset={{level=15,move='LEVEL'},{level=20,move='LATE'}}}
 end}
local p=factory{species=species,catalog={maximumNationalDex=2,entries=rows}}
assert(projections==14,'projected the same species/era repeatedly')
assert(#p.profiles==6 and p.pending['dex:2']=='missing')
local function moves(actual,expected)
 assert(#actual==#expected)
 for i,v in ipairs(expected)do assert(actual[i]==v)end
end
for i,profile in ipairs(p.profiles)do
 for epoch=1,7 do
  for revision=1,34 do
   local build=profile.generationMoveRevisions[revision][epoch]
   local expected={}
   if i<=3 then
    expected={'OLD'}
    if revision>=2 then expected[#expected+1]='NEW'end
    if revision==34 then expected[#expected+1]='LATE'end
    if i==1 then expected[#expected+1]='LEVEL'end
   end
   moves(build.moves,expected)
   assert(build.sourceEpoch==(i<=3 and epoch or math.max(3,epoch)))
   assert(build.versionGroup==(i<=3 and epoch*10 or 0))
  end
  assert(profile.generationMoves[epoch]==profile.generationMoveRevisions[34][epoch])
 end
 assert(profile.moves==profile.generationMoves[6].moves)
 assert(profile.generationMoveRevisions[2]==profile.generationMoveRevisions[33])
end
assert(p.profiles[2].generationMoves==p.profiles[3].generationMoves)
assert(p.profiles[2].generationMoveRevisions[1]==p.profiles[3].generationMoveRevisions[1])
assert(p.profiles[1].generationMoves~=p.profiles[2].generationMoves)
assert(p.profiles[2].name~=p.profiles[3].name and p.profiles[3].guaranteedShiny)
assert(p.profiles[1].generationMoveRevisions[35]==nil)
species.moveRevision=nil
local legacy=factory{species=species,catalog={maximumNationalDex=2,entries=rows}}
moves(legacy.profiles[1].generationMoveRevisions[1][1].moves,{'NEW','LATE','FUTURE','LEVEL'})
assert(legacy.profiles[1].generationMoveRevisions[1]==legacy.profiles[1].generationMoveRevisions[34])
print('PASS immutable gift histories: revisions, era metadata, level/egg distinction, pending and sharing')
