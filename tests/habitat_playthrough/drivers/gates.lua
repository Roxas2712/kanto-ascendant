return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local K=Q.K;local H=K.hiddenAccessReveal
 for _,d in ipairs(H.definitions())do if d.eligibility.kind~='starter'then assert(not H.available(game,d),'normal game bypass '..d.id)end end
 print('NORMAL_LEGEND_GATES_PASS')
 Q.ngplus('GREEN');game.save.inventory.HOENN_DEX=1;game.save.flags.EVENT_GOT_POKEDEX=true
 local target;for _,d in ipairs(H.definitions())do if d.id=='ROCK_TUNNEL_1F_SKY_PILLAR_ACCESS'then target=d end end;assert(target)
 assert(not H.available(game,target),'missing seal accepted');assert(K.legacyJourney.archive.completeHevoPath(game.save,'GREEN'))
 -- Previous collection is deliberately absent from this fresh-run fixture.
 local before=K.hoennDexCompletion67.report(game)
 if not before.portalReady then assert(not H.available(game,target),'missing collection accepted');print('MISSING_COLLECTION_GATE_PASS')end
 for _,s in ipairs(K.hoennDexCompletion67.foundationOrder)do K.hoennDexCompletion67.record(game,s)end
 game.save.inventory.HOENN_HONEY=1;Q.U.wait(2);local allowed,why=H.available(game,target);assert(allowed,'complete legend prerequisites refused: '..tostring(why))
 local manager=require('src.mods.ManagerState').new(game);manager:setOption('kanto_ascendant','hoenn_legend_portals',false);assert(not H.available(game,target),'disabled portal accepted');manager:setOption('kanto_ascendant','hoenn_legend_portals',true)
 for _,d in ipairs(H.definitions())do if d.eligibility.kind=='jirachi_convergence'then assert(not H.available(game,d),'incomplete finale accepted')end end
 print('NGPLUS_LIVE_LEGEND_GATES_PASS');love.event.quit()
end
