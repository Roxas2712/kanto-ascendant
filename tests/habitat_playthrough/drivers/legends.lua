return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local K=Q.K;local H=K.hiddenAccessReveal;local U=Q.U
 local profile=os.getenv('LEGEND_PROFILE')or'GREEN';Q.ngplus(profile);game.save.inventory.HOENN_DEX=1;game.save.inventory.HOENN_HONEY=1;game.save.flags.EVENT_GOT_POKEDEX=true
 assert(K.legacyJourney.archive.completeHevoPath(game.save,profile))
 local dex=K.hoennDexCompletion67;for _,species in ipairs(os.getenv('LEGEND_JIRACHI')and dex.order or dex.foundationOrder)do dex.record(game,species)end
 if os.getenv('LEGEND_JIRACHI')then for _,c in ipairs{'RED','BLUE','GREEN'}do assert(K.legacyJourney.archive.completeHevoPath(game.save,c))end;assert(K.legacyJourney.archive.completeFinale(game.save));local receipts=game.save.modData.kanto_ascendant.hevo_persistent.secretUnlocks or{};game.save.modData.kanto_ascendant.hevo_persistent.secretUnlocks=receipts;for _,flag in pairs(dex.portalLegends)do receipts[flag]=true end end
 local J=require('src.link.Json');local f=assert(io.open(Q.root..'/reachability.json'));local reports=J.decode(f:read('*a'));f:close();local paths={};for _,r in ipairs(reports)do if r.edition=='red'then paths[r.accessId]=r end end
 for _,d in ipairs(H.definitions())do if not os.getenv('LEGEND_JIRACHI')and d.eligibility.kind=='profile_legend'and d.eligibility.profile==profile or os.getenv('LEGEND_JIRACHI')and d.eligibility.kind=='jirachi_convergence'then
  local m=game.data.maps[d.handoff.destination.map];print('LEGEND_DESTINATION',d.id,m and m.id or'MISSING')
  assert(m,'missing authored destination '..d.handoff.destination.map)
  local r=assert(paths[d.id]);local p=r.approach[1];U.teleport(game,d.mapId,p.x,p.y,'down');Q.settle()
  local ok,why=H.available(game,d);assert(ok,tostring(why));Q.walkTo(d.reveal.x,d.reveal.y);Q.bag('TRACE_FINDER');Q.settle();assert(K.explorationDevice.isOpen(d.id),'legend reveal failed')
  Q.walkTo(d.warp.x,d.warp.y,d.handoff.destination.map);Q.settle();assert(game.overworld.map.id==m.id);Q.shot(d.id..'-inside');print('LEGEND_WALK_IN_PASS',d.id)
  Q.walkTo(8,5);U.hold(game,'up',1);Q.shot(d.id..'-encounter');local species=d.eligibility.species or 'JIRACHI';if not (d.eligibility.profile and K.hoennLegendPortals67.caught(game,d.eligibility.profile))then Q.catch(species)end
  Q.walkTo(8,11);Q.walkTo(8,12);Q.tap('a');Q.yes();assert(game.overworld.map.id==d.mapId,'legend return failed');Q.walkTo(d.reveal.x,d.reveal.y);print('LEGEND_PHYSICAL_ROUNDTRIP_PASS',d.id)
  for _,v in ipairs(m.warps or{})do print('LEGEND_WARP',v.x,v.y,v.destMap,v.destWarp)end
  for _,v in ipairs(m.signs or{})do print('LEGEND_SIGN',v.x,v.y,v.text)end
  for _,v in ipairs(m.objects or{})do print('LEGEND_OBJECT',v.x,v.y,v.name,v.text)end
 end end
 love.event.quit()
end
