package.path="./?.lua;"..package.path
local S=require("discovery_state")
local H=require("hoenn_discovery").create(S,require("encounter_overlay"),require("hoenn_acquisition_67_data"))
local n=0
local function check(x,m)n=n+1;assert(x,m)end
local function attempt(source,origin,flags,roll)
 local root=select(1,H.planIntroduction(S.empty(),{eligible=true,mapId="ROUTE_1",registeredFamilies={"POOCHYENA"},chanceRoll=1,familyRoll=1,token="test"}))
 local out,tx=H.planFieldOverlay(root,{native={species="RATTATA",level=3},mapId="ROUTE_1",roll=roll or 1,serial=1,registeredFamilies={"POOCHYENA"}})
 local battle={kind="wild",encounterSource=source,checkpointOrigin=origin,enemy={mon={species=out.species,level=out.level}}}
 for k,v in pairs(flags or {})do battle[k]=v end
 local after,ok,why=H.commitStarted(root,tx,{battle=battle,mapId="ROUTE_1",kind=battle.kind})
 return ok,S.sightingPity(after,"hoenn","POOCHYENA"),why
end
local origin={kind="wild_encounter",map="ROUTE_1"}
local ok,pity=attempt(nil,origin)
check(ok and pity==1,"engine field battle without source counts")
check(attempt("wild",nil),"existing explicit wild source still counts")
for _,case in ipairs({{nil,nil},{nil,{kind="static",map="ROUTE_1"}},{nil,{kind="wild_encounter",map="ROUTE_2"}},{"gift",origin},{"fishing",origin},{"",origin}})do
 local ok,pity=attempt(case[1],case[2]);check(not ok and pity==0,"untrusted or mismatched origin excluded")
end
for _,flag in ipairs({"noCatch","scriptedEncounter","demo","safari","ghost","dead","ascendantMythicProtected"})do
 local ok,pity=attempt(nil,origin,{[flag]=true});check(not ok and pity==0,flag.." protected")
end
check(not attempt(nil,origin,{kind="trainer"}),"trainer excluded")
check(attempt(nil,origin,nil,9851),"trace replacement commits with engine origin")
print("TRACE ENGINE ORIGIN PASS: "..n.." checks")
