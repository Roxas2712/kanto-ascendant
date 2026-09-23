return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local K=Q.K;local L=K.lifeOfRival;local U=Q.U
 if os.getenv('HABITAT_NGPLUS')then Q.ngplus('GREEN')end
 U.teleport(game,'CELADON_CITY',29,24,'down');Q.settle();L.cleanup()
 -- Fixture: introductions already completed; deterministic ordinary visit.
 -- No rumor or discovery receipt is injected. Both talks use player input.
 K.explorationDevice.use(game,{message=function()end}) -- inventory adoption only
 local s=L.state(true);s.thirdIntroductions={RED=true,BLUE=true,GREEN=true};s.knownActors={RED=true,BLUE=true,GREEN=true};s.pending=nil;s.visitMap=nil;s.visitReceipts={}
 print('RIVAL_GATES',L.eligible(game),L.mapEligible(game,'CELADON_CITY'),L.introRequired(s,game));local visit=assert(L.prepareVisit(game,s,'CELADON_CITY',{presence=1,actor=1,battle={RED=100,BLUE=100,GREEN=100}}),'prepare visit failed');local cell=L.findSpawnCell(game,game.overworld);print('SPAWN_DEBUG',cell and cell.x,cell and cell.y,visit.mode,#visit.actors);for _,r in ipairs(visit.actors)do local v=K.extendedCharacters.getCharacterSprite(r.actor,'overworld');print('SPRITE_DEBUG',r.actor,type(v),v and v.sprite)end;local spawned,why=L.spawnVisit(game,s,visit);assert(spawned,'spawn visit failed '..tostring(why))
 local e=assert(L.active.entries[1]);local n=e.npc.npc or e.npc;n.frozen=true
 print('RIVAL_SPAWN',e.actor,n.cellX,n.cellY,e.cell.x,e.cell.y)
 local x,y=n.cellX or e.cell.x,n.cellY or e.cell.y
 local approach;for _,v in ipairs{{-1,0,'right'},{0,1,'up'},{1,0,'left'},{0,-1,'down'}}do if Q.reachable(game.overworld.player.cellX,game.overworld.player.cellY,x+v[1],y+v[2])then approach=v;break end end;assert(approach);Q.walkTo(x+approach[1],y+approach[2]);U.hold(game,approach[3],1);Q.tap('a');Q.shot('rival-first');Q.settle()
 Q.tap('a');Q.shot('rival-hint');Q.settle()
 local after=L.state(true);local found
 for species in pairs(after.rumorsHeard)do found=species;print('RIVAL_HINT_RECORDED',species)end
 assert(found,'rival follow-up did not record hint')
 local contract
 for _,d in ipairs(K.hiddenAccessReveal.definitions())do if d.starter==found then contract=d;break end end
 assert(contract,'hint has no entrance');assert(K.discoveryCore.state.status(contract.eligibility.generation,contract.eligibility.family)=='trace')
 assert(K.hiddenAccessReveal.available(game,contract));print('RIVAL_INPUT_HINT_PASS',os.getenv('HABITAT_NGPLUS')and'NGPLUS'or'NORMAL',found)
 love.event.quit()
end
