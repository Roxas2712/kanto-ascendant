return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local U=Q.U;local K=Q.K;local S=K.hoennResearchSanctums67
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
  assert(npc,species..' scientist missing');
  if not Q.reachable(w.x,w.y,npc.x,npc.y+1)then local seed;for _,v in ipairs(m.warps)do if Q.reachable(v.x,v.y,npc.x,npc.y+1)then seed=v;break end end;assert(seed,'no public stair reaches scientist');U.teleport(game,r.sourceMap,seed.x,seed.y,'up');Q.settle();print('PUBLIC_STAIR_START',species,seed.x,seed.y,seed.destMap)end
print('SCIENTIST_PHYSICAL',species,npc.x,npc.y)
  Q.walkTo(npc.x,npc.y+1);U.hold(game,'up',1);Q.tap('a');Q.yes();assert(game.overworld.map.id==r.map,species..' scientist entry failed');Q.shot(species..'-entry')
  Q.walkTo(8,9);U.hold(game,'up',1);Q.tap('a');Q.settle();Q.shot(species..'-inscription')
  if species=='REGICE'then
   local begin=game.save.playTime;while game.save.playTime-begin<121 do U.wait(60)end
   Q.settle() -- seal must open automatically; no second interaction
  elseif species=='REGIROCK'then
   for _,v in ipairs{{10,9},{10,11}}do Q.walkTo(v[1],v[2])end
   U.hold(game,'right',1);Q.tap('a');Q.yes()
  else
   Q.tap('a');Q.yes()
  end
  assert(S.puzzleSolved(game,r),species..' seal did not open');print('REGI_PUZZLE_INPUT_PASS',species)
  Q.walkTo(8,5);U.hold(game,'up',1);Q.shot(species..'-reachable');Q.catch(species);assert(S.eventComplete(game,species),'capture receipt missing')
  -- Walk back to the authored return sign after the real capture.
  Q.walkTo(8,11);Q.walkTo(8,12);Q.tap('a');Q.yes();assert(game.overworld.map.id==r.sourceMap,species..' return failed')
  Q.shot(species..'-returned');print('REGI_PHYSICAL_ROUNDTRIP_PASS',species)
 end
 print('ALL_REGI_PHYSICAL_PASS');love.event.quit()
end
