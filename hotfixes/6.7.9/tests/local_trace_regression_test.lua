package.path="./?.lua;"..package.path
local State=require("discovery_state")
local A=require("hoenn_acquisition_67_data")
local H=require("hoenn_discovery").create(State,require("encounter_overlay"),A)
local n=0
local function check(v,m) n=n+1;assert(v,m) end
for _,source in ipairs({"CERULEAN_CITY","ROUTE_4","ROUTE_24","ROUTE_25"}) do
  for character,families in pairs(A.characterPacks) do
    local pool=H.introductionPool(State.empty(),families,source)
    check(#pool>0,source..character.." has a local clue")
    for roll=1,#pool do
      local root,r=H.planIntroduction(State.empty(),{mapId=source,eligible=true,
        registeredFamilies=families,chanceRoll=1,familyRoll=roll,token="local:"..roll})
      check(r.introduced,"local introduction succeeds")
      check(r.mapId==r.habitat.map,"new clue names actual authored habitat")
      check(r.mapId~="SEAFOAM_ISLANDS_B2F","Cerulean never sends player to Seafoam")
      check(H.traceMap(root,r.family)==r.mapId,"persistent encounter location matches clue")
      local output,tx=H.planFieldOverlay(root,{native={species="RATTATA",level=16},
        mapId=r.mapId,roll=9851,serial=1,registeredFamilies=families,legacyEnabled=true})
      check(output.species==r.family and tx~=nil,"advertised destination produces a real trace encounter")
    end
  end
end
local empty=State.empty()
local root,r=H.planIntroduction(empty,{mapId="ROUTE_4",eligible=true,
 registeredFamilies={"CORPHISH"},chanceRoll=1,familyRoll=1,token="distant"})
check(not r.introduced and H.introductionPity(root)==0,"no remote fallback or pity mutation")
local old=State.mark(State.empty(),"hoenn","CORPHISH","trace")
old.generations.hoenn.families.CORPHISH.traceMap="ROUTE_4"
local saved,r=H.planIntroduction(old,{mapId="ROUTE_4",eligible=true,
 registeredFamilies={"CORPHISH"},chanceRoll=1,familyRoll=1,token="old"})
check(r.mapId=="ROUTE_4" and H.traceMap(saved,"CORPHISH")=="ROUTE_4","old local trace is preserved")
local handlers={}
local mod={events={on=function(_,name,fn)handlers[name]=fn end}}
for _,lang in ipairs({"en","de"}) do
 local P=assert(loadfile("hoenn_trace_presentation_67.lua"))()(mod,{i18n={text=function(en,de)return lang=="de" and de or en end}})
 local t=P.announcement(nil,{family="CORPHISH",mapId="SEAFOAM_ISLANDS_B2F",habitat=H.primaryHabitat("CORPHISH")})
 check(t:find(lang=="de" and "SEESCHAUMINSELN UG2" or "SEAFOAM ISLANDS B2F",1,true),"exact cave floor named")
 check(not t:lower():find("grass") and not t:lower():find("gras"),"cave clue never says grass")
 local oldText=P.announcement(nil,r)
 check(oldText:find("ROUTE 4",1,true) and not oldText:find("SEAFOAM",1,true),"legacy clue names saved destination")
 check(oldText:find("1-50",1,true),"clue promises bounded encounters")
end
-- Runtime must use the same local pool for RNG bounds and commit, without
-- overriding the chosen destination with the battle map.
local managerRoot=State.empty()
H.registeredFamilies=function()return {"RALTS","CORPHISH"}end
local calls=0
local C=H.attach({events={on=function()end},hooks={wrap=function()end}}, {
 state={root=function()return managerRoot end,replace=function(v)managerRoot=v end},
 fieldAccess={encountersEnabled=function()return true end,introductionFamilies=function(_,f)return f end},
 random=function(low,high,purpose)calls=calls+1;if purpose=="hoenn-family" then check(high==1,"runtime RNG is local") end;return low end,
})
local game={data={encounters={ROUTE_4={grass={rate=25,slots={{species="RATTATA",level=16}}}}}}}
local changed,result=C.handleSurpriseWin({game=game,mapId="ROUTE_4",ascendantLegacyWanderer=true,ascendantLegacyToken="runtime"})
check(changed and result.mapId=="ROUTE_24","runtime clue points to nearby Route 24 rather than trainer tile")
local before=calls
H.registeredFamilies=function()return {"CORPHISH"}end
check(not C.handleSurpriseWin({game=game,mapId="ROUTE_4",ascendantLegacyWanderer=true,ascendantLegacyToken="empty"}),"runtime skips remote-only pool")
check(calls==before,"empty local pool consumes no RNG")
print("LOCAL TRACE PASS: "..n.." checks")
