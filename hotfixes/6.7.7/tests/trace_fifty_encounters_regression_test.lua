package.path="./?.lua;"..package.path
local State=require("discovery_state")
local A=require("hoenn_acquisition_67_data")
local H=require("hoenn_discovery").create(State,require("encounter_overlay"),A)
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local groups={}
for _,row in ipairs(A.traceFamilies)do
 local map=row.habitat.map;groups[map]=groups[map]or{};table.insert(groups[map],row.id)
end
local function introduce(families,map)
 local root=State.empty()
 for _,family in ipairs(families)do
  local r;root,r=H.planIntroduction(root,{eligible=true,mapId=map,registeredFamilies={family},chanceRoll=1,familyRoll=1,token=family})
  check(r.introduced and r.mapId==map,"clue unlocks named location")
 end
 return root
end
local function step(root,families,map,roll,serial)
 local out,tx=H.planFieldOverlay(root,{native={species="RATTATA",level=30},mapId=map,roll=roll,serial=serial,registeredFamilies=families})
 check(tx~=nil,"eligible wild encounter has transaction")
 local changed
 root,changed=H.commitStarted(root,tx,{kind="wild",encounterSource="wild",species=out.species,level=out.level,mapId=map})
 check(changed,"real encounter commits exactly once")
 if tx.family then
  root=select(1,H.closePending(root,{family=tx.family,species=out.species,mapId=map,serial=serial}))
 end
 return root,tx.family,out.species
end
-- Every authored habitat, including several simultaneous clues; worst-case
-- random misses must still show each exact promised Pokemon by encounter 50.
for map,families in pairs(groups)do
 local root=introduce(families,map);local seen={}
 for i=1,50 do
  local family,species;root,family,species=step(root,families,map,1,i)
  if family then seen[family]=i;check(species==family,"guarantee shows named base Pokemon")end
  if i==25 then root=State.normalize(root)end
 end
 for _,family in ipairs(families)do check(seen[family]and seen[family]<=50,family.." appears within 50 even with competing clues/reload")end
end
local root=introduce({"POOCHYENA"},"ROUTE_1")
local first,family,species=step(root,{"POOCHYENA"},"ROUTE_1",9851,1)
check(family=="POOCHYENA" and species=="POOCHYENA","first encounter may already hit")
local output,tx=H.planFieldOverlay(root,{native={species="RATTATA",level=40},mapId="ROUTE_1",roll=9851,serial=2,registeredFamilies={"POOCHYENA"},game={data={pokemon={POOCHYENA={evolutions={{species="MIGHTYENA",level=18}}},MIGHTYENA={}}}}})
check(output.species=="POOCHYENA","natural evolved-slot roll cannot replace advertised Pokemon")
-- Use the state authority rather than depending on private field spelling.
root=State.setSightingPity(root,"hoenn","POOCHYENA",199)
local old,oldFamily=step(root,{"POOCHYENA"},"ROUTE_1",1,3)
check(oldFamily=="POOCHYENA","old save beyond new limit receives next encounter")
local caught=State.unlock(State.mark(State.empty(),"hoenn","POOCHYENA","caught"),"hoenn","POOCHYENA")
local _,r=H.planIntroduction(caught,{mapId="ROUTE_1",eligible=true,registeredFamilies={"POOCHYENA"},chanceRoll=1,familyRoll=1,token="caught"})
check(not r.introduced,"caught species does not receive a false fresh guarantee")
-- The same local rule applies across every district and character pack.
for _,district in ipairs(A.traceDistricts)do
 for _,source in ipairs(district)do
  local permitted={[source]=true}
  for _,d in ipairs(A.traceDistricts)do
   local member=false;for _,m in ipairs(d)do if m==source then member=true end end
   if member then for _,m in ipairs(d)do permitted[m]=true end end
  end
  for _,families in pairs(A.characterPacks)do
   for _,family in ipairs(H.introductionPool(State.empty(),families,source))do
    check(permitted[H.primaryHabitat(family).map],"all districts and character packs remain local")
   end
  end
 end
end
print("TRACE 1-50 PASS: "..checks.." checks across all 62 ordinary families")
