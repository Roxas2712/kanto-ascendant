return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local K=Q.K;local U=Q.U
 Q.ngplus('RED');game.save.inventory.HOENN_DEX=1;game.save.inventory.HOENN_HONEY=1;game.save.flags.EVENT_GOT_POKEDEX=true;game.save.flags.EVENT_BEAT_CHAMPION_RIVAL=true;game.save.hallOfFame={{}}
 -- Prerequisite fixtures; the triangle, encounter and return are played.
 for _,c in ipairs{'RED','BLUE','GREEN'}do assert(K.legacyJourney.archive.completeHevoPath(game.save,c))end
 for _,s in ipairs(K.hoennDexCompletion67.foundationOrder)do K.hoennDexCompletion67.record(game,s)end
 K.hoennEndgameRunEvents67.mark(game,'MOLTRES',{testFixture=true});K.hoennEndgameRunEvents67.mark(game,'REGIROCK',{testFixture=true})
 local receipts=game.save.modData.kanto_ascendant.hevo_persistent.secretUnlocks or{};game.save.modData.kanto_ascendant.hevo_persistent.secretUnlocks=receipts;for _,flag in pairs(K.hoennDexCompletion67.portalLegends)do receipts[flag]=true end;local B=K.hoennBirthIsland67;print('BIRTH_GATES',require('src.link.Json').encode(K.hoennDexCompletion67.report(game)));assert(B.available(game),'Birth Island prerequisites missing')
 U.teleport(game,'CINNABAR_ISLAND',8,8,'down');Q.settle();local npc
 for _,n in ipairs(game.overworld.map.def.objects or{})do if n.name=='KA_HOENN_EXPEDITION_SCIENTIST'then npc=n;break end end
 assert(npc,'expedition scientist missing');Q.walkTo(npc.x,npc.y+1);U.hold(game,'up',1);Q.tap('a');Q.yes();assert(game.overworld.map.id==B.MAP,'expedition entry failed');Q.shot('birth-entry');local p=game.overworld.player;for _,n in ipairs(game.overworld.npcs or{})do if n.cellX==p.cellX and n.cellY==p.cellY then error('Birth Island arrival overlaps '..tostring(n.def and n.def.name))end end
 if not os.getenv('BIRTH_ENTRY_ONLY')then
 for i,p in ipairs(B.trianglePositions)do
  Q.walkTo(p[1],p[2]+1);U.hold(game,'up',1)
  if i<#B.trianglePositions then Q.tap('a');Q.settle();print('TRIANGLE_INPUT_PASS',i)else Q.catch('DEOXYS')end
 end
 assert(B.caught(game),'Deoxys receipt missing')end;Q.walkTo(8,11);Q.walkTo(8,12);Q.tap('a');Q.yes();assert(game.overworld.map.id=='VERMILION_CITY','Birth Island return failed');Q.shot('birth-returned');print('BIRTH_PHYSICAL_ROUNDTRIP_PASS');love.event.quit()
end
