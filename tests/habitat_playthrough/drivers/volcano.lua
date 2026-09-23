return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local K=Q.K;local U=Q.U;local V=K.hoennMoltresVolcano67
 game.save.inventory.HOENN_DEX=1;game.save.inventory.HOENN_HONEY=1;game.save.flags.EVENT_GOT_POKEDEX=true
 assert(V.available(game));U.teleport(game,'CINNABAR_ISLAND',8,8,'down');Q.settle();local npc
 for _,n in ipairs(game.overworld.map.def.objects or{})do if n.name=='KA_HOENN_EXPEDITION_SCIENTIST'then npc=n;break end end
 assert(npc);Q.walkTo(npc.x,npc.y+1);U.hold(game,'up',1);Q.tap('a');Q.yes();assert(game.overworld.map.id==V.ENTRY_MAP)
 local function talk(x,y,yes)Q.faceObject(x,y);Q.tap('a');if yes then Q.yes()else Q.settle()end;print('VOLCANO_STEP',x,y,require('src.link.Json').encode(V.puzzleState(game)))end
 talk(5,18)
 for _,p in ipairs{{5,15},{10,11},{14,15}}do talk(p[1],p[2])end
 talk(10,6,true);Q.shot('volcano-base-open');Q.walkTo(10,4,V.ASCENT_MAP);Q.settle();assert(game.overworld.map.id==V.ASCENT_MAP);print('VOLCANO_BASE_INPUT_PASS')
 for _,p in ipairs{{5,16},{10,16},{14,16}}do talk(p[1],p[2])end
 talk(10,13,true);Q.walkTo(10,11);U.hold(game,'up',1);Q.catch('MAGMAR')
 for _,p in ipairs{{5,9},{10,8},{14,9}}do talk(p[1],p[2],true)end
 talk(10,6,true);Q.shot('volcano-ascent-open');Q.walkTo(10,4,V.MAP);Q.settle();assert(game.overworld.map.id==V.MAP);print('VOLCANO_ASCENT_INPUT_PASS')
 talk(8,5,true);assert(V.puzzleSolved(game));Q.walkTo(8,5);U.hold(game,'up',1);Q.catch('MOLTRES');assert(V.eventComplete(game));print('VOLCANO_SUMMIT_INPUT_PASS')
 Q.walkTo(8,15,V.ASCENT_MAP);Q.settle();Q.walkTo(10,19,V.ENTRY_MAP);Q.settle();Q.walkTo(10,17);Q.walkTo(10,18);Q.tap('a');Q.yes();assert(game.overworld.map.id=='CINNABAR_ISLAND');Q.shot('volcano-returned');print('VOLCANO_PHYSICAL_ROUNDTRIP_PASS');love.event.quit()
end
