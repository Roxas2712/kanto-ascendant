return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local U=Q.U;local K=Q.K;local H=K.hiddenAccessReveal
 if os.getenv('HABITAT_NGPLUS')then Q.ngplus('GREEN')end
 local J=require('src.link.Json');local f=assert(io.open(Q.root..'/reachability.json'));local reports=J.decode(f:read('*a'));f:close();local paths={};for _,r in ipairs(reports)do if r.edition=='red'then paths[r.accessId]=r end end
 -- Fixture: completed story, HMs and rival clues. The complete physical
 -- route uses normal menu input and movement, with no scripted warp/leave.
 game.save.repelSteps=999999
 local caught={};local count=0;local only=os.getenv('HABITAT_ONLY');local resume=os.getenv('HABITAT_FROM');local active=not resume
 for _,d in ipairs(H.definitions())do if d.mapId==resume then active=true end;if active and d.eligibility.kind=='starter'and(not only or only==d.mapId)then
  K.discoveryCore.state.record(d.eligibility.generation,d.eligibility.family,'trace')
  local r=assert(paths[d.id]);local start=r.approach[1];U.teleport(game,d.mapId,start.x,start.y,'down');Q.settle()
  print('BEGIN_PHYSICAL',d.id,start.x,start.y)
  Q.walkTo(d.reveal.x,d.reveal.y);Q.bag('TRACE_FINDER');Q.settle();assert(K.explorationDevice.isOpen(d.id),'UI reveal failed '..d.id)
  Q.walkTo(d.handoff.interactFrom.x,d.handoff.interactFrom.y,d.handoff.destination.map)
  Q.shot(d.id..'-opened')
  Q.walkTo(d.warp.x,d.warp.y,d.handoff.destination.map);U.wait(100);Q.settle()
  assert(game.overworld.map.id==d.handoff.destination.map,'walk-in failed '..d.id)
  Q.shot(d.id..'-inside');local row=assert(K.starterHabitats.maps[game.overworld.map.id]);print('INSIDE',d.id,row.exit.x,row.exit.y)
  if os.getenv('HABITAT_CATCH')and not caught[row.family]then Q.searchStarter(row);caught[row.family]=true end
  Q.walkTo(row.exit.x,row.exit.y,d.mapId);U.wait(100);Q.settle();assert(game.overworld.map.id==d.mapId,'walk-out failed '..d.id)
  Q.walkTo(d.reveal.x,d.reveal.y);Q.shot(d.id..'-returned');count=count+1;print('PHYSICAL_STARTER_ROUNDTRIP_PASS',d.id)
 end end
 assert(count>0,'no habitat cases selected');if not only and not resume then assert(count==16,'incomplete entrance matrix');if os.getenv('HABITAT_CATCH')then local total=0;for _ in pairs(caught)do total=total+1 end;assert(total==12,'incomplete starter capture matrix');print('HABITAT_UNIQUE_CAPTURE_TOTAL',total)end end
 print('PHYSICAL_STARTER_TOTAL',count);love.event.quit()
end
