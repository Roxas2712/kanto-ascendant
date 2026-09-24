return function(game)
 local Q=dofile(os.getenv('HABITAT_QA_ROOT')..'/drivers/common.lua')(game);Q.setup();local K=Q.K;local U=Q.U;local H=K.hiddenAccessReveal
 local function find(fn,name,seen)
 if type(fn)~='function'then return end;seen=seen or{};if seen[fn]then return end;seen[fn]=true
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;if k==name then return v end end
 for i=1,200 do local k,v=debug.getupvalue(fn,i);if not k then break end;local x=find(v,name,seen);if x then return x end end
 end
 local V=assert(find(Q.V.lib.require('VoxelScene').render,'V'))
 require('src.render.Pipelines').setLevel('voxel',7);V.require('FirstPerson').yaw=math.pi;V.require('FirstPerson').pitch=.45
 local hold=U.hold;U.hold=function(g,b,n) V.require('FirstPerson').yaw=math.pi;return hold(g,b,n) end
 local shot=Q.shot;Q.shot=function(name) require('src.render.Pipelines').setLevel('voxel',0);U.wait(30);shot(name..'-2d');require('src.render.Pipelines').setLevel('voxel',4);U.wait(90);shot(name);require('src.render.Pipelines').setLevel('voxel',7);U.wait(60) end
 local d;for _,v in ipairs(H.definitions())do if v.id=='ROUTE14_SURF_HIDDEN_HABITAT'then d=v end end;assert(d)
 K.discoveryCore.state.record(d.eligibility.generation,d.eligibility.family,'trace')
 U.teleport(game,'ROUTE_14',12,48,'down');Q.settle();Q.walkTo(12,49);Q.bag('TRACE_FINDER')
 local function guidance()
  local t=game.stack:top();local pages={};for _,page in ipairs(t.pages or{})do pages[#pages+1]=table.concat(page,' ')end
  local text=table.concat(pages,' ');assert(text:find('SURF',1,true)and text:lower():find('east',1,true),'shore guidance missing');print('ROUTE14_NATIVE_GUIDANCE',text);Q.settle()
 end
 guidance();Q.shot("route14-marked-open");Q.walkTo(d.warp.x,d.warp.y,d.handoff.destination.map);Q.settle();assert(game.overworld.map.id==d.handoff.destination.map)
 assert(game:writeSave()~=false);local loaded=assert(require('src.core.SaveData').load('red'));assert(loaded.player.map==d.handoff.destination.map,'habitat save location changed');game:restoreSave(loaded,false,{freshBoot=true});Q.settle()
 assert(game.overworld.map.id==d.handoff.destination.map,'habitat resume failed');local row=K.starterHabitats.maps[d.handoff.destination.map];Q.shot("habitat-marked-exit");print("EXIT_TARGET",row.exit.x,row.exit.y);Q.walkTo(row.exit.x,row.exit.y,d.mapId);Q.settle();assert(game.overworld.map.id=='ROUTE_14');Q.bag('TRACE_FINDER');guidance();Q.walkTo(d.warp.x,d.warp.y,d.handoff.destination.map);Q.settle();assert(game.overworld.map.id==d.handoff.destination.map)
 local row=K.starterHabitats.maps[d.handoff.destination.map];Q.walkTo(row.exit.x-1,row.exit.y);U.hold(game,'right',1);Q.tap('a');Q.settle();assert(game.overworld.map.id==d.mapId,'adjacent A return failed');Q.shot('route14-reload-returned');print('ROUTE14_NATIVE_RELOAD_PASS');love.event.quit()
end
