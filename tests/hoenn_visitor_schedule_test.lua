-- KASC_ENGINE=/path/to/gen1recomp luajit tests/hoenn_visitor_schedule_test.lua
local engine=assert(os.getenv('KASC_ENGINE'))
package.path='./?.lua;'..engine..'/?.lua;'..package.path
local Hooks=require('src.mods.Hooks')
local checks=0
local function check(v,m)checks=checks+1;assert(v,m)end
local function fixture()
  local f={legacy=false,events={},sprites={},saved={}}
  local resident={index=1,name='RESIDENT',sprite='SPRITE_LITTLE_GIRL'}
  local game={save={inventory={},playTime=2400,party={},modData={}},
    data={maps={VIRIDIAN_NICKNAME_HOUSE={objects={resident}}}},
    overworld={map={id='PEWTER_GYM'},player={moving=false}}}
  local top=game.overworld
  game.stack={top=function()return top end}
  f.top=function(v)top=v end
  local hooks=Hooks.new()
  local mod={id='kanto_ascendant',path='.',hooks=hooks,
    save={get=function(_,k)return f.saved[k]end,set=function(_,k,v)f.saved[k]=v end},
    content={items={register=function()end},sprites={register=function(_,id,row)f.sprites[id]=row end}},
    events={on=function(_,event,fn)f.events[event]=fn end},world={}}
  function mod.world:overworld()return game.overworld end
  function mod.world:spawnNpc(map,row)
    row.index=2;row.owner=mod.id;row.runtime=true
    local objects=game.data.maps[map].objects
    objects[#objects+1]=row
    return map..'_obj_2'
  end
  function mod.world:removeNpc(id)
    local rows=game.data.maps.VIRIDIAN_NICKNAME_HOUSE.objects
    for i=#rows,1,-1 do
      if rows[i].runtime and id=='VIRIDIAN_NICKNAME_HOUSE_obj_'..rows[i].index then table.remove(rows,i)end
    end
  end
  local F=dofile('hoenn_field_access_67.lua')(mod,{
    legacyProgression={isActive=function()return f.legacy end},
    placement={find=function()return 3,4 end}})
  f.F,f.game,f.mod=F,game,mod
  function f.tick()hooks:call('core.update',function()end,game,1)end
  function f.enter(map)game.overworld.map.id=map;f.events['map.entered']({game=game,mapId=map})end
  function f.count()return #game.data.maps.VIRIDIAN_NICKNAME_HOUSE.objects-1 end
  function f.untouched()check(game.data.maps.VIRIDIAN_NICKNAME_HOUSE.objects[1]==resident,'resident unchanged')end
  return f
end
local f=fixture();local F,game=f.F,f.game
check(not F.visitorScheduled(game),'hidden before first badge')
f.tick();check(f.saved[F.SAVE_KEY]==nil,'no schedule seeded before badge')
game.save.inventory.BOULDERBADGE=1
f.tick()
check(f.saved[F.SAVE_KEY].visitorAnchorPlayTime==2400,'clock starts on badge outside house')
game.save.playTime=2700
f.enter(F.VISITOR_MAP)
check(f.count()==0,'first house visit does not force appearance')
game.save.playTime=3600
f.enter(F.VISITOR_MAP)
check(f.count()==1,'returns at next cycle')
f.enter(F.VISITOR_MAP);check(f.count()==1,'no duplicate visitor')
local sprite=f.sprites[F.VISITOR_SPRITE]
check(sprite and sprite.frames==6 and sprite.walker and sprite.image:find('hoenn_visitor_walk.png',1,true),'dedicated six-frame asset')
check(game.data.maps[F.VISITOR_MAP].objects[2].sprite==F.VISITOR_SPRITE,'own model assigned to live NPC')
-- Remain inside while clocks advance; never disappear during conversation.
game.save.playTime=3900;f.top({});f.tick();check(f.count()==1,'dialogue defers departure')
f.top(game.overworld);game.overworld.player.moving=true;f.tick();check(f.count()==1,'movement defers departure')
game.overworld.player.moving=false;game.overworld.transitioning=true;f.tick();check(f.count()==1,'transition defers departure')
game.overworld.transitioning=false;game.overworld.runner={isRunning=function()return true end}
f.tick();check(f.count()==1,'script defers departure')
game.overworld.runner=nil;f.tick();check(f.count()==0,'leaves after dialogue without reentering house')
f.untouched()
-- Step clock can advance the visit without waiting in real time.
game.save.playTime=2400;f.saved.step_clock=1024;f.tick();check(f.count()==1,'steps start next visit')
f.saved.step_clock=1280;f.tick();check(f.count()==0,'steps end visit')
f.saved.step_clock=0
local home=0
for slot=0,39 do game.save.playTime=2400+slot*300;if F.visitorScheduled(game)then home=home+1 end end
check(home==10,'one quarter of routine is home')
-- Old saves: retain Honey/Dex/pack/clock and unrelated gameplay; missing
-- anchors use elapsed saved play rather than reset on each load.
f=fixture();F,game=f.F,f.game
game.save.inventory={BOULDERBADGE=1,HOENN_HONEY=1,HOENN_DEX=1}
game.save.playTime=900
f.saved[F.SAVE_KEY]={version=2,honeyOwned=true,dexOwned=true,characterPack='RED',futureReceipt='keep'}
f.saved.bank={sealed=true};f.events['save.loaded']({game=game})
f.enter(F.VISITOR_MAP)
check(f.count()==0,'old save missing anchor not forced home on load')
check(f.saved[F.SAVE_KEY].honeyOwned and f.saved[F.SAVE_KEY].dexOwned and f.saved[F.SAVE_KEY].characterPack=='RED','old access receipts preserved')
check(f.saved[F.SAVE_KEY].futureReceipt=='keep' and f.saved.bank.sealed,'other save fields preserved')
local anchor=f.saved[F.SAVE_KEY].visitorAnchorPlayTime
f.events['save.loaded']({game=game});check(f.saved[F.SAVE_KEY].visitorAnchorPlayTime==anchor,'reload preserves clock')
game.save.playTime=1200;f.tick();check(f.count()==1,'old save visitor returns')
f.legacy=true;f.tick();check(f.count()==0,'visitor remains hidden in NG+')
f.untouched()
print('PASS Hoenn visitor schedule and save upgrade: '..checks..' checks')
