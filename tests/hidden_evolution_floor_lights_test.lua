-- Product contract for the 30 independent HEVO floor lights.
-- Run from gen1recomp with KA_HIDDEN_EVOLUTION_MOD set to this worktree.

local root=assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local factory=assert(loadfile(root.."/hidden_evolution_floor_lights.lua"))()

local checks=0
local function check(value,message) checks=checks+1;assert(value,message) end
local function eq(actual,expected,message)
  checks=checks+1;assert(actual==expected,("%s (got %s, want %s)"):format(
    message,tostring(actual),tostring(expected)))
end

local currentSave
local maps={}
local floorIds={
  "KA_HEVO_RED_UPPER","KA_HEVO_RED_ABYSS","KA_HEVO_RED_LOWER",
  "KA_HEVO_BLUE_FROST_HALL","KA_HEVO_BLUE_GLACIER_MAZE",
  "KA_HEVO_BLUE_TIDAL_DEPTHS","KA_HEVO_GREEN_GROVE","KA_HEVO_GREEN_MIST",
  "KA_HEVO_BLUE_FROST_THRESHOLD","KA_HEVO_GREEN_THRESHOLD",
}
for _,id in ipairs(floorIds) do maps[id]={id=id,objects={},warps={}} end
local scripts,texts,pointers,events={},{},{},{}
local function save(character,cycle)
  return {modData={kanto_ascendant={
    extended_characters={player_character=character},hevo_run={cycle=cycle or 1},
  }},player={map="KA_HEVO_RED_UPPER"}}
end
currentSave=save("RED",1)
local ow={map={id="KA_HEVO_RED_UPPER"}}
local mod={id="kanto_ascendant",
  save={get=function(_,key)
      local bucket=currentSave.modData.kanto_ascendant;return bucket[key]
    end,
    set=function(_,key,value) currentSave.modData.kanto_ascendant[key]=value end},
  world={overworld=function() return ow end},
  events={on=function(_,name,fn,priority)
    events[name]=events[name] or {};events[name][#events[name]+1]={fn=fn,priority=priority}
  end},
  content={
    maps={get=function(_,id)return maps[id]end,patch=function(_,id,partial)
      for key,value in pairs(partial) do maps[id][key]=value end
    end},
    text={register=function(_,id,value) texts[id]=value end},
    text_pointers={patch=function(_,_,value) for id,row in pairs(value)do pointers[id]=row end end},
    map_scripts={register=function(_,id,value) scripts[id]=scripts[id] or {};scripts[id][#scripts[id]+1]=value end},
  },
}
local routes={
  RED={IDS={upper=floorIds[1],abyss=floorIds[2],lower=floorIds[3]},
    run=function() return {sight=5,completed=false} end,
    sightProfile=function() return {radius=99,innerOpacity=0,opacity=0} end},
  BLUE={ids={HALL=floorIds[4],ICE=floorIds[5],DEPTHS=floorIds[6],
      THRESHOLD=floorIds[9]},
    state=function() return {sight=5} end,
    sightProfile=function() return {radius=99,innerOpacity=0,outerOpacity=0} end},
  GREEN={IDS={grove=floorIds[7],mist=floorIds[8],threshold=floorIds[10]},
    progress=function() return {sight=5} end,
    fogInnerOpacity=function() return 0 end,
    FOG_OUTER_COLOR={30/255,30/255,30/255},FOG_EDGE_SCREEN_PIXELS=2},
}
local lights=factory(mod,{routes=routes,
  activeCharacter=function(game)
    local bucket=game and game.save and game.save.modData
      and game.save.modData.kanto_ascendant
    local chars=bucket and bucket.extended_characters
    return chars and chars.player_character
  end,
  showText=function() return true end})

eq(#lights.FLOORS,10,"exactly ten visibility floors own local lights")
local total=0
for _,floor in ipairs(lights.FLOORS) do
  eq(#floor.stones,3,floor.map.." owns exactly three authored light stones")
  total=total+#floor.stones
end
eq(total,30,"ten floors expose exactly 30 light stones")
for _,id in ipairs({"KA_HEVO_TUNNEL_ALL","KA_HEVO_RED_RECOVERY",
    "KA_HEVO_RED_SHRINE","KA_HEVO_BLUE_KYOGRE_SHRINE",
    "KA_HEVO_GREEN_RAYQUAZA_SHRINE","KA_HEVO_SHARED_SEALED_ANTECHAMBER"}) do
  eq(lights.byMap[id],nil,id.." has no floor-light state or object surface")
end

check(lights.register(),"floor lights register")
local exactCoordinates={
  KA_HEVO_RED_UPPER={{16,33},{20,18},{44,12}},
  KA_HEVO_RED_ABYSS={{20,27},{30,19},{30,7}},
  KA_HEVO_RED_LOWER={{16,33},{26,15},{34,9}},
  KA_HEVO_BLUE_FROST_THRESHOLD={{2,22},{18,11},{33,6}},
  KA_HEVO_BLUE_FROST_HALL={{8,23},{16,18},{35,9}},
  KA_HEVO_BLUE_GLACIER_MAZE={{13,33},{9,17},{37,7}},
  KA_HEVO_BLUE_TIDAL_DEPTHS={{6,35},{32,24},{34,6}},
  KA_HEVO_GREEN_THRESHOLD={{2,29},{26,22},{32,5}},
  KA_HEVO_GREEN_GROVE={{18,29},{38,23},{42,11}},
  KA_HEVO_GREEN_MIST={{2,30},{27,26},{56,13}},
}
for mapId,coordinates in pairs(exactCoordinates) do
  local floor=assert(lights.byMap[mapId],mapId.." lost its light row")
  for index,point in ipairs(coordinates) do
    eq(floor.stones[index].x,point[1],mapId.." light "..index.." x drift")
    eq(floor.stones[index].y,point[2],mapId.." light "..index.." y drift")
  end
end
eq(maps.KA_HEVO_RED_UPPER.objects[1].x,16,
  "first RED floor light occupies the optional bottom fault")
eq(maps.KA_HEVO_RED_UPPER.objects[1].y,33,
  "first RED floor light remains off the entrance-to-exit spine")
local seenNames,seenTexts,registered= {},{},0
for _,id in ipairs(floorIds) do
  eq(#maps[id].objects,3,id.." receives exactly three objects")
  eq(#scripts[id],1,id.." receives one composable talk contribution")
  for _,object in ipairs(maps[id].objects) do
    registered=registered+1
    check(not seenNames[object.name],object.name.." is unique");seenNames[object.name]=true
    check(not seenTexts[object.text],object.text.." is unique");seenTexts[object.text]=true
    eq(object.sprite,"SPRITE_KA_EVOLUTION_RELIC",object.name.." is visibly a relic")
    eq(object.passable,false,object.name.." must remain a tangible light stone")
    eq(object.semanticRole,"floor_light",object.name.." is not a quiz statue")
    check(texts[object.text]~=nil and pointers[object.text]~=nil,
      object.name.." has registered text and pointer")
    check(type(scripts[id][1].talk[object.text])=="function",
      object.name.." is interactive")
  end
end
eq(registered,30,"all 30 light objects are registered")

-- A hot refresh from the rejected walk-through build can leave stale
-- passable=true on live NPCs.  Refresh must restore the exact floor lights to
-- tangible collision entities. A visually distinct quiz statue stays solid
-- through its own contract and is not rewritten by the floor-light lookup.
ow.map.id=floorIds[1]
ow.npcs={}
for _,object in ipairs(maps[floorIds[1]].objects) do
  ow.npcs[#ow.npcs+1]={def=object,cellX=object.x,cellY=object.y,passable=true}
end
local solidStatue={def={name="KA_RED_STATUE_1",
  sprite="SPRITE_KA_HEVO_QUIZ_STATUE",semanticRole="quiz_statue"},
  cellX=99,cellY=99}
ow.npcs[#ow.npcs+1]=solidStatue
check(lights.refresh({save=currentSave,overworld=ow},floorIds[1]),
  "runtime floor-light solidity refresh succeeds")
local Collision=require("src.world.Collision")
for index=1,3 do
  eq(ow.npcs[index].passable,false,
    "live floor light "..index.." lost tangible collision")
  eq(Collision.occupied(ow.npcs,ow.npcs[index].cellX,
    ow.npcs[index].cellY,nil),ow.npcs[index],
    "live floor light "..index.." is absent from Collision.occupied")
end
eq(solidStatue.passable,nil,"quiz statue remains solid")

-- A legacy/global five-statue completion is deliberately not a migration
-- signal. Only these three local objects alter this floor's stage.
currentSave.modData.kanto_ascendant.hevo_run.red={sight=5,completed=true}
currentSave.modData.kanto_ascendant.hevo_run.hidden_evolution_blue={sight=5}
currentSave.modData.kanto_ascendant.hevo_run.hidden_evolution_story_campaign={
  green={sight=5}}
eq(lights.stage(currentSave,floorIds[1]),0,
  "old RED quiz sight does not mint local floor light")
eq(lights.stage(currentSave,floorIds[4]),0,
  "old BLUE quiz sight does not mint local floor light")
eq(lights.stage(currentSave,floorIds[7]),0,
  "old GREEN quiz sight does not mint local floor light")
local futureState=save("RED",1)
futureState.modData.kanto_ascendant.hevo_run.floorLights={
  version=99,token="1:RED",character="RED",floors={
    [floorIds[1]]={lit={
      KA_HEVO_FLOOR_LIGHT_RED_UPPER_1=true,
      KA_HEVO_FLOOR_LIGHT_RED_UPPER_2=true,
      KA_HEVO_FLOOR_LIGHT_RED_UPPER_3=true,
    }},
  },
}
eq(lights.stage(futureState,floorIds[1]),0,
  "future floor-light schema fails closed instead of minting full sight")

local upper=lights.byMap[floorIds[1]]
local callbackSave=save("RED",1)
scripts[upper.map][1].talk[upper.stones[1].text]({save=callbackSave},nil,nil)
eq(lights.stage(callbackSave,upper.map),1,
  "text callback remains bound to its own stone even without an NPC wrapper")
eq(lights.stage(callbackSave,floorIds[2]),0,
  "bound callback cannot write a different floor")
local futureOk,futureWhy,futureStage=lights.activate(futureState,upper.map,
  upper.stones[1].name,{save=futureState})
check(futureOk and futureWhy=="lit" and futureStage==1,
  "first real interaction replaces a future schema with one honest light")
local ok,why,stage=lights.activate(currentSave,upper.map,upper.stones[2].name,
  {save=currentSave})
check(ok and why=="lit","any one of the three stones may be first")
eq(stage,1,"first exact-once light produces stage one")
ok,why,stage=lights.activate(currentSave,upper.map,upper.stones[2].name,
  {save=currentSave})
check(not ok and why=="already","repeat activation is idempotent")
eq(stage,1,"repeat activation cannot increment stage")
eq(lights.stage(currentSave,floorIds[2]),0,
  "a RED floor does not inherit another RED floor's light")
for _,index in ipairs({1,3}) do
  ok,why,stage=lights.activate(currentSave,upper.map,upper.stones[index].name,
    {save=currentSave})
  check(ok and why=="lit","remaining RED light activates")
end
eq(stage,3,"three unique stones produce full local stage")

for owner,_ in pairs({RED=true,BLUE=true,GREEN=true}) do
  local previous,byStage
  byStage={}
  for value=0,3 do
    local profile=assert(lights.profile(owner,value))
    byStage[value]=profile
    eq(profile.floorStage,value,owner.." profile exposes exact local stage")
    eq(profile.featherPx,2,owner.." keeps accepted analytic edge width")
    check(profile.innerOpacity>0,owner.." never removes atmospheric tint")
    if previous then check(profile.radius>previous.radius,
      owner.." local visibility grows monotonically") end
    previous=profile
  end
  check(previous.radius>=90 and previous.spatiallyUnbounded,
    owner.." stage three removes the spatial aperture")
  check(byStage[1].radius>=20,
    owner.." first light exposes roughly one third of a real floor")
  check(math.abs(byStage[2].radius/byStage[1].radius-2)<0.01,
    owner.." second light doubles that reach to roughly two thirds")
end

-- Raw save authority wins over helpers and fails closed for foreign/future
-- characters. This also proves one slot cannot illuminate another.
local redSlot=currentSave
local blueSlot=save("BLUE",1)
currentSave=blueSlot;ow.map.id=floorIds[4]
eq(lights.stage(blueSlot,floorIds[4]),0,"second slot starts dark")
local blueFloor=lights.byMap[floorIds[4]]
ok=lights.activate(blueSlot,blueFloor.map,blueFloor.stones[1].name,{save=blueSlot})
check(ok,"matching BLUE slot lights its own floor")
eq(lights.stage(blueSlot,floorIds[4]),1,"BLUE slot retains its local stage")
eq(lights.stage(redSlot,floorIds[1]),3,"returning to RED slot restores RED state")
local denied,reason=lights.activate(blueSlot,upper.map,upper.stones[1].name,
  {save=blueSlot})
check(not denied and reason=="character","BLUE cannot write RED light state")
local greenSlot=save("GREEN",1)
local greenOwnedFloor=lights.byMap[floorIds[7]]
ok,why,stage=lights.activate(greenSlot,greenOwnedFloor.map,
  greenOwnedFloor.stones[3].name,{save=greenSlot})
check(ok and why=="lit","matching GREEN slot lights its own floor")
eq(stage,1,"GREEN owns the same local stage contract")
eq(lights.stage(greenSlot,floorIds[8]),0,
  "GREEN grove light cannot illuminate GREEN mist")
local future=save("FUTURE",1)
eq(lights.character({save=future}),nil,"future raw identity fails closed")
denied,reason=lights.activate(future,upper.map,upper.stones[1].name,{save=future})
check(not denied and reason=="character","future identity cannot activate a light")

-- Reload has no runtime cache; new game/new journey starts a new token while
-- returning to the original slot keeps its exact table.
currentSave=blueSlot
local lifecycleGame={save=blueSlot,overworld=ow}
check(lights.install(lifecycleGame),"lifecycle hooks install")
check(events["save.loading"] and events["save.loaded"] and events["save.created"]
    and events["map.reloaded"],
  "save loading/loaded/created and map reload boundaries are covered")
local _,profile=lights.refresh({save=blueSlot,overworld=ow},floorIds[4])
eq(profile.floorStage,1,"runtime refresh reads persisted BLUE stage")
events["save.loading"][1].fn()
eq(ow.kaHevoBlueSight,nil,"save.loading clears old-slot runtime visibility")
events["save.loaded"][1].fn({mapId=floorIds[4]})
eq(ow.kaHevoBlueSight.floorStage,1,"save.loaded restores current-slot stage")
ow.kaHevoBlueSight=nil
events["map.reloaded"][1].fn({mapId=floorIds[4]})
eq(ow.kaHevoBlueSight.floorStage,1,"map reload restores persisted local stage")
currentSave=greenSlot;lifecycleGame.save=greenSlot;ow.map.id=floorIds[7]
events["save.loading"][1].fn()
events["save.loaded"][1].fn({mapId=floorIds[7]})
eq(ow.kaHevoGreenFloorSight.floorStage,1,
  "save.loaded restores GREEN's independent persisted floor stage")
local fresh=save("BLUE",1);currentSave=fresh
eq(lights.stage(fresh,floorIds[4]),0,"new game starts every floor dark")
lifecycleGame.save=fresh;ow.map.id=floorIds[4]
events["save.created"][1].fn({mapId=floorIds[4]})
eq(ow.kaHevoBlueSight.floorStage,0,
  "save.created/new-game refresh cannot inherit the previous slot")
blueSlot.modData.kanto_ascendant.hevo_run.cycle=2
eq(lights.stage(blueSlot,floorIds[4]),0,"new journey token cannot inherit old light")

-- Both renderer generations consume the exact same local profile.  The old
-- compatibility adapter must not fall back to route-global sight=5.
currentSave=redSlot;ow.map.id=floorIds[1]
local redNew=routes.RED.floorSightProfile(redSlot,floorIds[1])
eq(redNew.floorStage,3,"new RED renderer seam reads local stage three")
currentSave=blueSlot;ow.map.id=floorIds[4]
local blueNew=routes.BLUE.floorSightProfile(blueSlot,floorIds[4])
eq(blueNew.floorStage,0,"new BLUE renderer seam sees journey reset")
local compatFactory=assert(loadfile(root.."/hidden_evolution_visibility_compat.lua"))()
local compat=compatFactory(mod,{routes=routes})
currentSave=redSlot
local legacyProfile=compat.profileFor({save=redSlot},{map={id=floorIds[1]}})
eq(legacyProfile.radius,redNew.radius,
  "0.1.83 RED path uses the same floor-local radius")
eq(legacyProfile.innerOpacity,redNew.innerOpacity,
  "0.1.83 RED path keeps the same atmospheric tint")
currentSave=blueSlot;ow.map.id=floorIds[4]
local blueLegacy=compat.profileFor({save=blueSlot},{map={id=floorIds[4]}})
eq(blueLegacy.radius,blueNew.radius,
  "0.1.83 BLUE path uses the same floor-local radius")
eq(blueLegacy.innerOpacity,blueNew.innerOpacity,
  "0.1.83 BLUE path keeps the same atmospheric tint")
currentSave=greenSlot;ow.map.id=floorIds[7]
local greenNew=routes.GREEN.floorSightProfile(greenSlot,floorIds[7])
local persistedGreenLegacy=compat.profileFor({save=greenSlot},
  {map={id=floorIds[7]}})
eq(persistedGreenLegacy.radius,greenNew.radius,
  "0.1.83 GREEN path uses the same persisted floor-local radius")
eq(persistedGreenLegacy.innerOpacity,greenNew.innerOpacity,
  "0.1.83 GREEN path keeps the same atmospheric tint")
currentSave=fresh
local greenFloor=lights.byMap[floorIds[7]]
fresh.modData.kanto_ascendant.extended_characters.player_character="GREEN"
ow.map.id=greenFloor.map
local greenLegacy=compat.profileFor({save=fresh},{map={id=greenFloor.map}})
eq(greenLegacy.radius,lights.profile("GREEN",0).radius,
  "0.1.83 GREEN path starts from local stage zero")

-- Exercise the production RED/BLUE route methods themselves, rather than
-- proving only the injected seam on test doubles. GREEN's production fog
-- reads the same injected floorSightProfile directly inside fogProfile.
local productionRoutes={
  RED=assert(loadfile(root.."/hidden_evolution_red_path.lua"))()(mod,{}),
  BLUE=assert(loadfile(root.."/hidden_evolution_blue_campaign.lua"))()(mod,{}),
  GREEN=assert(loadfile(root.."/hidden_evolution_green_grove.lua"))()(mod,{}),
}
local productionLights=factory(mod,{routes=productionRoutes,
  activeCharacter=function(game)
    local bucket=game and game.save and game.save.modData
      and game.save.modData.kanto_ascendant
    local chars=bucket and bucket.extended_characters
    return chars and chars.player_character
  end})
currentSave=redSlot
local productionRed=productionRoutes.RED.activeSightProfile(redSlot,
  floorIds[1],5,true)
eq(productionRed.floorStage,3,
  "production RED new-renderer method rejects route-global completed sight")
local productionBlue=productionRoutes.BLUE.activeSightProfile(fresh,
  floorIds[4],5)
eq(productionBlue.floorStage,0,
  "production BLUE new-renderer method rejects route-global sight five")
local productionGreen=productionRoutes.GREEN.floorSightProfile(fresh,
  floorIds[7])
eq(productionGreen.floorStage,0,
  "production GREEN fog seam reads only the local floor-light stage")
check(productionLights.byMap[floorIds[8]]~=nil,
  "production renderer composition retains the original deep-floor definitions")
check(productionLights.byMap[floorIds[9]]~=nil
    and productionLights.byMap[floorIds[10]]~=nil,
  "production renderer composition retains both threshold light floors")

print(("PASS hidden_evolution_floor_lights_test: %d assertions"):format(checks))
