return function(game)
 local U=require('tests.drivers.util');local Q={U=U,game=game,root=assert(os.getenv('HABITAT_QA_ROOT'))}
 function Q.tap(b)U.tap(game,b);U.wait(3)end
 function Q.settle()
  for i=1,1200 do
   local t=game.stack:top()
   if t==game.overworld and not game.overworld.transitioning and not game.overworld.player.moving and not(game.overworld.runner and game.overworld.runner:isRunning())then U.wait(3);return end
   if t.isTextBox or t.pages then Q.tap('a')elseif t.items then Q.tap('b')else U.wait(1)end
  end
  error('UI did not return to overworld')
 end
 function Q.choose(match)
  local t=game.stack:top();local n
  for i,v in ipairs(t.submenu and t.subItems or t.items or{})do if match(v)then n=i;break end end
  if not n then for k,v in pairs(t)do if type(v)~='function'and type(v)~='table'then print('MENU_MISSING_FIELD',k,v)end end;for i,v in ipairs(t.items or{})do print('MENU_MISSING_ROW',i,v.label,v.value)end end;assert(n,'menu row missing: '..tostring(t.title))
  for i=1,60 do if (t.submenu and t.subIndex or t.index)==n then Q.tap('a');return end;Q.tap('down')end
  error('menu selection stuck')
 end
 function Q.bag(item)
  Q.settle();Q.tap('start');Q.choose(function(v)return v.label=='ITEM'or v.label=='BAG'or v.label=='BEUTEL'end);U.wait(5)
  for pocket=1,8 do
   local t=game.stack:top();local found=false
   for _,v in ipairs(t.items or{})do if v.value==item then found=true end end
   if found then Q.choose(function(v)return v.value==item end);break end
   Q.tap('right')
  end
  U.wait(8);local t=game.stack:top()
  if t.items then Q.choose(function(v)return v.label=='USE'or v.value=='use'or v.label=='BENUTZEN'end)end
  U.wait(10)
 end
 function Q.shot(n)assert(U.shot(game,Q.root..'/evidence/'..n..'.png'))end
 function Q.field(move)
  Q.settle();Q.tap('start');Q.choose(function(v)return v.label and(v.label:upper():find('MON',1,true))end);Q.tap('a');U.wait(5)
  Q.choose(function(v)return v.label==move or v.value==move end);Q.settle()
 end
 function Q.yes()
  local last
  for i=1,1800 do
   local t=game.stack:top()
   if t==game.overworld and not game.overworld.transitioning and not game.overworld.player.moving and not(game.overworld.runner and game.overworld.runner:isRunning())then U.wait(3);return end
   if t.pages and t~=last then local pages={};for _,p in ipairs(t.pages)do pages[#pages+1]=table.concat(p,' ')end;print('YES_DIALOG',table.concat(pages,' '));last=t end
   if t.labels and t.onChoose then if t.pending~=nil then U.wait(1)elseif t.index~=1 then Q.tap('up')else Q.tap('a')end
   elseif t.isTextBox or t.pages then Q.tap('a')else U.wait(1)end
  end
  error('yes dialogue did not finish')
 end
 function Q.pairClear(map,sx,sy,tx,ty)
  local pairs=(game.data.field.tilePairs or{})[(map:isWaterCell(sx,sy)and not map:isWalkableCell(sx,sy))and'water'or'land']or{}
  local a,b=map:cellTile(sx,sy),map:cellTile(tx,ty)
  for _,v in ipairs(pairs)do if v.tileset==map.def.tileset and(v.a==a and v.b==b or v.b==a and v.a==b)then return false end end
  return true
 end
 function Q.reachable(sx,sy,gx,gy)
  local m=game.overworld.map;local queue={{sx,sy}};local seen={[sx..','..sy]=true};local at=1
  while queue[at]do local p=queue[at];at=at+1;if p[1]==gx and p[2]==gy then return true end
   for _,v in ipairs{{0,1},{0,-1},{1,0},{-1,0}}do local x,y=p[1]+v[1],p[2]+v[2];local key=x..','..y
    if not seen[key]and m:inBounds(x,y)and((x==gx and y==gy)or not m:warpAtCell(x,y))and(m:isWalkableCell(x,y)or m:isWaterCell(x,y))and Q.pairClear(m,p[1],p[2],x,y)and not require('src.world.Collision').occupied(game.overworld.entities,x,y,game.overworld.player)then seen[key]=true;queue[#queue+1]={x,y}end
   end
  end;return false
 end
 function Q.faceObject(x,y)
  local p=game.overworld.player
  for _,v in ipairs{{0,1,'up'},{-1,0,'right'},{1,0,'left'},{0,-1,'down'}}do
   if Q.reachable(p.cellX,p.cellY,x+v[1],y+v[2])then Q.walkTo(x+v[1],y+v[2]);U.hold(game,v[3],1);return end
  end
  error('object has no accessible interaction cell '..x..','..y)
 end
 function Q.walkTo(gx,gy,expectedMap)
  local ow=game.overworld;local mapid=ow.map.id;local blocked={};local retries=0
  while true do
   local p=ow.player;if p.cellX==gx and p.cellY==gy then return true end
   local key=function(x,y)return x..','..y end;local first={x=p.cellX,y=p.cellY};local queue={first};local seen={[key(first.x,first.y)]=true};local finish;local at=1
   while at<=#queue do local q=queue[at];at=at+1;if q.x==gx and q.y==gy then finish=q;break end
    for _,v in ipairs{{'up',0,-1},{'down',0,1},{'left',-1,0},{'right',1,0}}do
     local dir,dx,dy=v[1],v[2],v[3];local x,y=q.x+dx,q.y+dy
     if ow.map.def.tileset=='OVERWORLD'then for _,l in ipairs(game.data.field.ledges or{})do if l.facing==dir and ow.map:cellTile(q.x,q.y)==l.standingTile and ow.map:inBounds(x,y)and ow.map:cellTile(x,y)==l.ledgeTile then x,y=x+dx,y+dy;break end end end
     local k=key(x,y)
     if not seen[k]and not blocked[key(q.x,q.y)..'>'..k]and ow.map:inBounds(x,y)and((x==gx and y==gy)or not ow.map:warpAtCell(x,y))and Q.pairClear(ow.map,q.x,q.y,x,y)and(ow.map:isWalkableCell(x,y)or ow.map:isWaterCell(x,y))and not require('src.world.Collision').occupied(ow.entities,x,y,p)then
      local n={x=x,y=y,dir=dir,prev=q};seen[k]=true;queue[#queue+1]=n
     end
    end
   end
   assert(finish,mapid..' no physical path from '..p.cellX..','..p.cellY..' to '..gx..','..gy)
   local steps={};while finish.prev do table.insert(steps,1,finish);finish=finish.prev end
   for _,q in ipairs(steps)do
    if ow.map:isWaterCell(q.x,q.y)and not ow.map:isWalkableCell(q.x,q.y)and not p.surfing then
     U.hold(game,q.dir,1);Q.field('SURF')
    end
    for frame=1,70 do
     if game.stack:top()~=game.overworld then Q.settle()end
     if game.overworld.map.id~=mapid then assert(game.overworld.map.id==expectedMap,'unexpected transition '..game.overworld.map.id);Q.settle();return true end
     if p.cellX==q.x and p.cellY==q.y and math.abs(p.px-q.x*16)<1.1 and math.abs(p.py-q.y*16)<1.1 then break end
     U.hold(game,q.dir,1)
    end
    for frame=1,80 do if game.overworld.map.id~=mapid then assert(game.overworld.map.id==expectedMap,'unexpected transition '..game.overworld.map.id);Q.settle();return true end;if not p.moving then break end;U.wait(1)end
    if p.cellX~=q.x or p.cellY~=q.y then
     Q.shot('blocked-'..mapid);local top=game.stack:top();print('BLOCKED_STATE',tostring(top==ow),tostring(top.title),tostring(top.isTextBox),tostring(p.surfing),tostring(ow.transitioning));for k,v in pairs(top)do if type(v)=='string'then print('TOP_STRING',k,v)end end;blocked[key(p.cellX,p.cellY)..'>'..key(q.x,q.y)]=true;retries=retries+1;print('BLOCKED',mapid,p.cellX,p.cellY,q.x,q.y);assert(retries<12,'blocked movement');break
    end
   end
  end
 end
 function Q.catch(species,alreadyStarted)
  game.save.inventory.MASTER_BALL=20
  if not alreadyStarted then Q.tap('a')end;local battle
  for i=1,1800 do local t=game.stack:top();if t.enemy and t.enemy.mon and t.phase=='menu'then battle=t;break end;Q.tap('a')end
  assert(battle,'battle menu missing '..species);assert(battle.enemy.mon.species==species,'wrong encounter');Q.shot(species..'-battle');print('PHYSICAL_BATTLE_STARTED',species)
  Q.tap('left');assert(battle.menuIndex==3,'bag navigation');Q.tap('a');U.wait(40)
  for pocket=1,8 do local t=game.stack:top();local found=false;for _,v in ipairs(t.items or{})do if v.value=='MASTER_BALL'then found=true end end
   if found then Q.choose(function(v)return v.value=='MASTER_BALL'end);break end;Q.tap('right')end
  U.wait(10);local t=game.stack:top();if t.items then Q.choose(function(v)return v.label=='USE'or v.value=='use'end)end
  for i=1,3000 do local t=game.stack:top();if t==game.overworld then Q.settle();print('PHYSICAL_BATTLE_FINISHED',species);return end
   if t.def and t.def.id==species and not t.enemy then Q.tap('b')
   elseif t.labels and t.onChoose then local wanted=(game.save.inventory.MASTER_BALL or 0)==20 and 1 or 2;if t.pending~=nil then U.wait(1)elseif t.index~=wanted then Q.tap('down')else Q.tap('a')end else Q.tap('a')end
  end
  error('capture did not finish '..species)
 end
 function Q.searchStarter(row)
  local ow=game.overworld;local pair
  for y=2,ow.map.def.height*2-3 do for x=2,ow.map.def.width*2-3 do
   if not pair and ow.map:isWalkableCell(x,y)and ow.map:isWalkableCell(x+1,y)and Q.pairClear(ow.map,x,y,x+1,y)and not require('src.world.Collision').occupied(ow.entities,x,y,ow.player)and not require('src.world.Collision').occupied(ow.entities,x+1,y,ow.player)and Q.reachable(ow.player.cellX,ow.player.cellY,x,y)then pair={x=x,y=y}end
  end end
  assert(pair,'no habitat search pair');Q.walkTo(pair.x,pair.y)
  Q.K.discoveryCore.state.setSightingPity(row.generation,row.family,150)
  game.save.repelSteps=0;require('src.world.OverworldController').rollEncounter=Q.nativeRoll
  local encountered=false
  for i=1,3000 do
   local top=game.stack:top()
   if top.enemy and top.enemy.mon then encountered=true;break end
   if top~=ow then U.wait(1)else
    local dir=ow.player.cellX==pair.x and 'right' or 'left'
    U.hold(game,dir,1)
    while ow.player.moving and game.stack:top()==ow do U.wait(1)end
   end
  end
  require('src.world.OverworldController').rollEncounter=function()return nil end
  assert(encountered,'no native habitat encounter');Q.catch(row.family,true)
  assert(Q.K.discoveryCore.state.family(row.generation,row.family).caught==true,'starter catch receipt missing')
  print('HABITAT_STARTER_CAPTURE_PASS',row.family,ow.map.id)
 end
 function Q.ngplus(character)
  local K=Q.K;local archive=K.legacyJourney.archive
  assert(archive.beginJourney(game.save,{playerAvatar=character,runRules=assert(K.runRules.legacySnapshot(K.runRules.newLegacyDraft(game.save),game.save))}))
  local fresh=require('src.core.SaveData').newGame(game:bootConfig());assert(archive.seedNewSave(fresh));game.save=fresh;game:adoptSave(fresh);require('src.mods.Runtime').emit('save.created',{save=fresh});assert(game:writeSave()~=false);assert(archive.markRunStarted(fresh));assert(K.extendedCharacters.select(character))
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true
  game.save.inventory.TRACE_FINDER=1
  for _,b in ipairs{'BOULDERBADGE','CASCADEBADGE','THUNDERBADGE','RAINBOWBADGE','SOULBADGE','MARSHBADGE','VOLCANOBADGE','EARTHBADGE'}do game.save.inventory[b]=true end
  local mon=require('src.pokemon.Pokemon').new(game.data,'DRAGONITE',70);mon.moves={{id='SURF',pp=15},{id='STRENGTH',pp=15},{id='FLY',pp=15},{id='CUT',pp=15}};game.save.party={mon}
 end
 function Q.setup()
  io.stdout:setvbuf('no');local OW=require('src.world.OverworldController');OW.checkTrainerSight=function()end;Q.nativeRoll=OW.rollEncounter;OW.rollEncounter=function()return nil end;game:startNewGame{intro=false}
  local raw=game.update;game.update=function(self,dt)return require('src.mods.Runtime').call('core.update',raw,self,dt)end
  Q.K=game.mods.exports.kanto_ascendant;Q.V=game.mods.exports.VOXEL_ASCENDANT
  require('src.mods.ManagerState').new(game):setOption('kanto_ascendant','living_world_enabled',false)
  Q.V.ascendantContent.onboardingShown=true;Q.V.ascendantContent.promptDisabled=true
  game.save.flags.EVENT_FOLLOWED_OAK_INTO_LAB=true;game.save.flags.EVENT_GOT_STARTER=true;game.save.flags.EVENT_BEAT_CHAMPION_RIVAL=true;game.save.hallOfFame={{}}
  game.save.inventory.TRACE_FINDER=1
  for _,b in ipairs{'BOULDERBADGE','CASCADEBADGE','THUNDERBADGE','RAINBOWBADGE','SOULBADGE','MARSHBADGE','VOLCANOBADGE','EARTHBADGE'}do game.save.inventory[b]=true end
  local mon=require('src.pokemon.Pokemon').new(game.data,'DRAGONITE',70);mon.moves={{id='SURF',pp=15},{id='STRENGTH',pp=15},{id='FLY',pp=15},{id='CUT',pp=15}};game.save.party={mon}
 end
 return Q
end
