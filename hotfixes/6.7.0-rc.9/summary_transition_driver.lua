return function(game)
 io.stdout:setvbuf('no')
 assert((os.getenv('POKEPORT_IDENTITY') or ''):match('^vasc%-301%-native'))
 local root=assert(os.getenv('SUMMARY_QA_ROOT'))
 local function wait(n) for _=1,n do coroutine.yield() end end
 local function press(k)
  game.input:sourcePress(k,'summary-qa');wait(1);game.input:sourceRelease(k,'summary-qa');wait(4)
 end
 local function shot(name)
  local done=false
  love.graphics.captureScreenshot(function(p)
   local d=p:encode('png');local f=assert(io.open(root..'/'..name..'.png','wb'));f:write(d:getString());f:close();d:release();p:release();done=true
  end)
  for _=1,200 do if done then return end;wait(1)end;error('screenshot timeout')
 end
 local function option(mod,key,value)
  for _,o in ipairs({game.mods,game.save.options})do o.modOptions=o.modOptions or {};o.modOptions[mod]=o.modOptions[mod] or {};o.modOptions[mod][key]=value end
  require('src.mods.Runtime').emit('mod.options_changed',{game=game,mod=mod,modId=mod,key=key,value=value})
 end
 local ok,err=xpcall(function()
  love.window.setMode(1062,480,{resizable=true,vsync=0})
  game:startNewGame({intro=false});wait(20)
  local P=require('src.pokemon.Pokemon');local Screens=require('src.ui.Screens')
  game.save.party={P.new(game.data,'MEWTWO',100),P.new(game.data,'PIKACHU',40)}
  game.save.party[1].nickname='Prometheus';game.save.options.textSpeed=1
  local paired=game.mods.exports.kanto_ascendant~=nil
  assert(paired==(os.getenv('EXPECT_KASC')=='1'),'unexpected KASC')
  local kinds={'game_default','oras_glass','asc_box'}
  if not game.mods.exports.VOXEL_ASCENDANT then kinds={'game_default'} end
  for _,style in ipairs(kinds)do
   option('VOXEL_ASCENDANT','pokemonUiPartyMenu',style)
   for _,values in ipairs(paired and {'dv','full','off'} or {'off'})do
    option('kanto_ascendant','status_values',values)
    local party=Screens.push(game,'PartyMenu');wait(15)
    local Sound=require('src.core.Sound');local cry=Sound.playCry;local cries=0
    Sound.playCry=function(...)cries=cries+1;return cry(...)end
    local summary=Screens.push(game,'SummaryMenu',game.save.party[1]);local initial=summary.whiteHold
    if initial and initial>0 then
     local wasPressed=game.input.wasPressed;game.input.wasPressed=function(_,key)return key=='a'end
     summary:update(1/60);game.input.wasPressed=wasPressed
     assert(summary.page==1,'input bypassed entry transition')
    end
    wait(100)
    Sound.playCry=cry;assert(cries==1,'expected exactly one opening cry, got '..cries)
    print('SUMMARY_STATE',style,values,'initial',initial,'remaining',summary.whiteHold,'page',summary.page)
    shot(style..'-'..values..'-stats')
    assert((summary.whiteHold or 0)<=0,'white transition stuck: '..tostring(summary.whiteHold))
    assert(summary.page==1,'page advanced without input')
    press('a');assert(summary.page==2,'moves missing');shot(style..'-'..values..'-moves')
    if paired and values~='off' then press('a');assert(summary.page==3,'values missing');shot(style..'-'..values..'-values') end
    press('b');wait(20);assert(game.stack:top()==party,'summary did not return to party')
    -- Reopening and rotations must not restore the white overlay.
    summary=Screens.push(game,'SummaryMenu',game.save.party[2]);wait(30)
    love.window.setMode(600,1000,{resizable=true,vsync=0});wait(10)
    assert((summary.whiteHold or 0)<=0,'reopen white transition stuck');shot(style..'-'..values..'-portrait')
    love.window.setMode(1062,480,{resizable=true,vsync=0});wait(10)
    game.stack:pop();assert(game.stack:top()==party);game.stack:pop();wait(10)
    print('SUMMARY_CASE_PASS',style,values)
   end
  end
  print('SUMMARY_ALL_PASS')
 end,debug.traceback)
 print('SUMMARY_RESULT',ok,err or '');love.event.quit(ok and 0 or 1)
end
