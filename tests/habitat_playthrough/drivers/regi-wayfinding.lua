return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local U=Q.U;local K=Q.K;local S=K.hoennResearchSanctums67
 require('src.render.Pipelines').setLevel('voxel',4)
 game.save.inventory.HOENN_DEX=1;game.save.inventory.HOENN_HONEY=1;game.save.flags.EVENT_GOT_POKEDEX=true
 -- Fixture: cleared Kanto water/rock puzzles and Moltres event; no Regi seal
 -- or chamber-entry receipt is pre-completed.
 K.hoennEndgameRunEvents67.mark(game,'MOLTRES',{testFixture=true})
 for _,e in ipairs{'EVENT_SEAFOAM1_BOULDER1_DOWN_HOLE','EVENT_SEAFOAM1_BOULDER2_DOWN_HOLE','EVENT_SEAFOAM2_BOULDER1_DOWN_HOLE','EVENT_SEAFOAM2_BOULDER2_DOWN_HOLE','EVENT_SEAFOAM3_BOULDER1_DOWN_HOLE','EVENT_SEAFOAM3_BOULDER2_DOWN_HOLE','EVENT_SEAFOAM4_BOULDER1_DOWN_HOLE','EVENT_SEAFOAM4_BOULDER2_DOWN_HOLE','EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH1','EVENT_VICTORY_ROAD_2_BOULDER_ON_SWITCH2'}do game.save.flags[e]=true end
 assert(S.available(game))
 for _,species in ipairs{'REGISTEEL','REGIROCK','REGICE'}do
  local r=S.bySpecies[species];local m=game.data.maps[r.sourceMap];local w=m.warps[1] or{x=10,y=18}
  U.teleport(game,r.sourceMap,w.x,w.y,'down');Q.settle();U.wait(30)
  local npc;for _,n in ipairs(game.overworld.map.def.objects or{})do if n.name=='KA_HIDDEN_'..species..'_SCIENTIST'then npc=n;break end end
  assert(npc,species..' scientist missing');assert(not S.accessLight(game,species),'unexpected solved fixture');
  if not Q.reachable(w.x,w.y,npc.x,npc.y+1)then local seed;for _,v in ipairs(m.warps)do if Q.reachable(v.x,v.y,npc.x,npc.y+1)then seed=v;break end end;assert(seed,'no public stair reaches scientist');U.teleport(game,r.sourceMap,seed.x,seed.y,'up');Q.settle();print('PUBLIC_STAIR_START',species,seed.x,seed.y,seed.destMap)end
print('SCIENTIST_PHYSICAL',species,npc.x,npc.y)
  Q.walkTo(npc.x,npc.y+1);U.wait(90);Q.shot(species..'-source-unlit');U.hold(game,'up',1);Q.tap('a');Q.yes();assert(game.overworld.map.id==r.map,species..' scientist entry failed');U.wait(90);Q.shot(species..'-entry')
  -- Leave the unsolved chamber by walking; then use a solved-state fixture
  -- solely to verify the exterior lamp state (no claim of replaying puzzles).
  Q.walkTo(8,11);Q.walkTo(8,13,r.sourceMap);Q.settle();assert(game.overworld.map.id==r.sourceMap,species..' return failed')
  Q.shot(species..'-returned');local progress=K.hoennEndgameRunEvents67;progress.setProgress(game,'REGI_PUZZLE_'..species,{solved=true});U.wait(20);assert(S.accessLight(game,species));Q.shot(species..'-solved-lights');print('REGI_PHYSICAL_ROUNDTRIP_PASS',species)
 end
 print('ALL_REGI_ACCESS_ROUNDTRIPS_PASS_WITH_SOLVED_LIGHT_FIXTURE');love.event.quit()
end
