-- Run only in an isolated QA engine/profile, with this KASC worktree installed.
return function(game)
  local U=require('tests.drivers.util')
  local Q=dofile(assert(os.getenv('BLAINE_KASC_ROOT'))..'/tests/habitat_playthrough/drivers/common.lua')(game)
  Q.setup()
  Q.V.setupCard.suspended=true
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL=nil;game.save.hallOfFame={}
  love.audio.setVolume(0);love.window.hasFocus=function()return true end
  love.window.isVisible=function()return true end
  local out=assert(os.getenv('BLAINE_QA_OUTPUT'))
  Q.shot=function(name)assert(U.shot(game,out..'/'..name..'.png'))end
  local K=assert(game.mods.exports.kanto_ascendant,'KASC not loaded')
  local R=assert(K.blaineVolcanoRoute,'Blaine route missing')
  assert(R.registered and game.data.maps[R.CHAMBER],'route not registered')
  local Pokemon=require('src.pokemon.Pokemon')
  game.save.party={Pokemon.new(game.data,'BLASTOISE',65)}
  game.save.flags.EVENT_BEAT_BLAINE=nil
  game.save.inventory.VOLCANOBADGE=nil
  game.save.inventory.HOENN_HONEY=nil
  game.save.inventory.HOENN_DEX=nil
  game.save.defeatedTrainers={}
  -- The player's old save may already stand in the final quiz room.
  U.teleport(game,R.GYM,3,3,'up');Q.settle();Q.shot('01-gym-descent')
  Q.walkTo(3,2,R.TUNNEL);Q.settle();assert(game.overworld.map.id==R.TUNNEL)
  assert(game.overworld.player.cellX==44,'arrival must be at right end')
  Q.shot('02-tunnel-right');Q.walkTo(6,8);Q.shot('03-tunnel-left')
  Q.walkTo(5,4,R.FOOT);Q.settle();assert(game.overworld.map.id==R.FOOT)
  Q.shot('04-volcano-foot');Q.walkTo(15,12,R.CHAMBER);Q.settle()
  assert(game.overworld.map.id==R.CHAMBER);Q.shot('05-platform-entry')
  assert(game:writeSave(),'write fixture inside new chamber')
  local loaded=assert(require('src.core.SaveData').load('red'))
  game:restoreSave(loaded)
  U.teleport(game,R.CHAMBER,24,28,'up');Q.settle()
  assert(not game.save.inventory.VOLCANOBADGE and game.save.party[1].species=='BLASTOISE','in-progress save retained')
  Q.walkTo(17,20);Q.walkTo(17,11);Q.walkTo(32,11);Q.walkTo(32,20)
  Q.walkTo(25,13);U.hold(game,'up',1);Q.shot('06-blaine-platform')
  local npc
  for _,n in ipairs(game.overworld.npcs)do if n.def.name=='CINNABARGYM_BLAINE'then npc=n end end
  assert(npc and not game.overworld:trainerDefeated(npc))
  Q.tap('a')
  local battle
  for i=1,1500 do
    local top=game.stack:top()
    if top.enemy and top.enemy.mon then battle=top;break end
    Q.tap('a')
  end
  assert(battle and battle.oppClass=='OPP_BLAINE' and battle.partyIndex==1,'native story battle')
  Q.shot('07-blaine-battle')
  -- Fixture-complete the native battle callback; this checks rewards, not AI.
  game.stack:pop();battle.onFinish('win');Q.settle()
  assert(game.save.flags.EVENT_BEAT_BLAINE and game.save.inventory.VOLCANOBADGE,'badge/flag')
  assert(game.save.inventory.TM_FIRE_BLAST and game.save.inventory.TM_FIRE_BLAST>0,'Fire Blast TM')
  assert(game.overworld:trainerDefeated(npc),'defeated at new map')
  local tm=game.save.inventory.TM_FIRE_BLAST
  Q.tap('a');Q.settle();assert(game.save.inventory.TM_FIRE_BLAST==tm,'no duplicate reward')
  game.save.flags.EVENT_BEAT_CHAMPION_RIVAL=true
  assert(K.postgame.handleTalk(game.overworld,npc,game),'Master/Crown leader recognised at new location')
  while game.stack:top()~=game.overworld do game.stack:pop()end
  npc.frozen=false;game.save.flags.EVENT_BEAT_CHAMPION_RIVAL=nil
  Q.walkTo(24,29,R.FOOT);Q.settle();Q.walkTo(15,20,R.TUNNEL);Q.settle()
  Q.walkTo(45,8,R.GYM);Q.settle();assert(game.overworld.map.id==R.GYM)
  -- Open the fixture's quiz gates to test the town exit after lastMap changed.
  for i=0,5 do game.save.flags['EVENT_CINNABAR_GYM_GATE'..i..'_UNLOCKED']=true end
  U.teleport(game,R.GYM,3,3,'down');Q.settle()
  Q.walkTo(16,17,'CINNABAR_ISLAND');Q.settle()
  assert(game.overworld.map.id=='CINNABAR_ISLAND','gym exit loops to town')
  Q.shot('08-town-return')
  print('BLAINE_NATIVE_ROUNDTRIP_REWARDS_PASS')
  love.event.quit()
end
