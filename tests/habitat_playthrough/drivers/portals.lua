return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local K=Q.K;local U=Q.U;local P=K.hoennLegendPortals67
 Q.ngplus('RED');game.save.inventory.HOENN_DEX=1;game.save.inventory.HOENN_HONEY=1;game.save.flags.EVENT_GOT_POKEDEX=true
 assert(K.legacyJourney.archive.completeHevoPath(game.save,'RED'))
 for _,s in ipairs(K.hoennDexCompletion67.foundationOrder)do K.hoennDexCompletion67.record(game,s)end
 assert(P.available(game,'RED'))
 U.teleport(game,'KA_HEVO_SHARED_SEALED_ANTECHAMBER',3,20,'up');Q.settle();Q.walkTo(15,6);U.hold(game,'up',1);Q.tap('a');Q.yes()
 assert(game.overworld.map.id==P.rows.RED.map,'Groudon portal did not enter');Q.shot('groudon-entry');local approach;for _,v in ipairs{{0,1,'up'},{-1,0,'right'},{1,0,'left'},{0,-1,'down'}}do if Q.reachable(8,11,8+v[1],4+v[2])then approach=v;break end end;if not approach then for _,dir in ipairs{'up','right','down','left'}do U.hold(game,dir,120);local p=game.overworld.player;print('GROUDON_BLOCKED_INPUT',dir,p.cellX,p.cellY,require('src.world.Collision').canMove(game.overworld.map,game.overworld.entities,p,dir))end;local m=game.overworld.map;for y=0,19 do local line='';for x=0,23 do line=line..(Q.reachable(8,11,x,y)and'R'or m:isWalkableCell(x,y)and'.'or'#')end;print('GRID',y,line)end;for y=4,13 do print('TILE',y,m:cellTile(8,y),m:isWalkableCell(8,y))end end;assert(approach,'Groudon has no reachable interaction cell');Q.walkTo(8+approach[1],4+approach[2]);U.hold(game,approach[3],1);Q.catch('GROUDON');assert(P.caught(game,'RED'))
 Q.walkTo(8,11);Q.walkTo(8,12);Q.tap('a');Q.yes();assert(game.overworld.map.id=='KA_HEVO_SHARED_SEALED_ANTECHAMBER');Q.shot('groudon-returned');print('GROUDON_PORTAL_PHYSICAL_PASS');love.event.quit()
end
