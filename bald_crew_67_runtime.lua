-- Presentation/world adapter. Uses the native battle stack and a separate
-- durable campaign owner. No global trainer/warp/party replacement.
return function(mod,opts)
 local D,S,C=assert(opts.data),assert(opts.state),assert(opts.content)
 local text=assert(opts.dialogue);local I=D.instance
 local R={game=nil,installed=false}
 local function tr(row)
  return opts.i18n and opts.i18n.text and opts.i18n.text(row.en,row.de)or row.en
 end
 local function show(game,row,done,choice)
  if opts.show then return opts.show(game,tr(row),done,choice)end
  local T=require('src.render.TextBox')
  game.stack:push(T.new(game,tr(row),done,choice and{defaultNo=true,choice=choice}or nil))
  return true
 end
 local function errorText(reason)
  return{en='The trial could not continue.\nNo checkpoint was skipped.\f'..tostring(reason),
   de='Die Prüfung kann nicht weitergehen.\nKein Kontrollpunkt wurde übersprungen.\f'..tostring(reason)}
 end
 local function live(game)return game and game.overworld and game.overworld.map and game.overworld.map.id end
 function R.ownsCave()
  local s=S.status()
  return s and(s.phase=='ready'or s.phase=='active'or s.phase=='battle')or false
 end
 local function recoverParty(game)
  -- Trial defeat deliberately avoids vanilla blackout (money + heal-point
  -- warp), but must retain its healthy-party guarantee. Do this before the
  -- checkpoint save so reloading cannot restore an unusable all-fainted team.
  -- On a failed save keep the live party healthy; the unresolved fight token
  -- still prevents progression and is recovered as a loss on retry/reload.
  local P=require('src.pokemon.Pokemon')
  for _,mon in ipairs(game.save.party or{})do P.heal(mon)end
 end
 local function visible(game,map,name,on)
  local save=game.save;save.objectToggles=save.objectToggles or{}
  save.objectToggles[map]=save.objectToggles[map]or{}
  local changed=save.objectToggles[map][name]~=(on==true)
  save.objectToggles[map][name]=on==true
  return changed
 end
 function R.returnOutside(game,rear)
  local p=rear and I.rearReturnPoint or I.returnPoint
  R.returning=true
  local ok,why=mod.world:warpTo(I.entrance,p[1],p[2],'down')
  if not ok then R.returning=false end
  return ok,why
 end
 function R.secureSave(save)
  local p=save and save.player
  if p and p.map==I.map then
   p.map=I.entrance;p.x=I.returnPoint[1];p.y=I.returnPoint[2];p.facing='down';p.surfing=false
   return true
  end
  return false
 end
 function R.sync(game,map)
  game=game or R.game;map=map or live(game)
  if not game then return false end
  local s=S.status();if not s then return false end
  local changed=false
  if map==I.entrance then
   local on=R.ownsCave()
   changed=visible(game,map,'KA_BALD_CREW_FRONT',on)or changed
   changed=visible(game,map,'KA_BALD_CREW_REAR',on)or changed
   changed=visible(game,map,'KA_BALD_CREW_RESTART',
    s.phase=='paused'or s.phase=='reward'or s.phase=='complete')or changed
  elseif map==I.map then
   for _,o in ipairs(C.clone and C.clone.objects or{})do
    local on=true
    if o.name=='KA_BALD_CREW_PANDY'then on=s.next==#D.order end
    changed=visible(game,map,o.name,on)or changed
   end
  end
  local ow=game.overworld
  if changed and not R.syncing and ow and ow.reloadMap and live(game)==map then
   R.syncing=true;ow:reloadMap(map,'bald-crew-visibility');R.syncing=false
  end
  return true,changed
 end
 function R.enter(game)
  if opts.invited and not opts.invited()then return false,'invitation_pending'end
  if not opts.eligible or not opts.eligible(game)then return false,'prerequisite'end
  local ok,reason=S.unlock(game);if not ok then return false,reason end
  ok,reason=S.enter(game);if not ok then return false,reason end
  return mod.world:warpTo(I.map,I.entry[1],I.entry[2],'up')
 end
 local function refresh(game,ow)
  R.sync(game,I.map)
 end
 local function fight(game,ow,npc,index,done)
  local s,why=S.status();if not s then return show(game,errorText(why),done)end
  local id=D.order[index]
  if index<s.next then return show(game,text.defeatedBy[id]or text.defeated,done)end
  if index~=s.next then
   local row=text.waiting[id];local required=D.opponents[D.order[s.next]]
   if row and required then return show(game,{en=row.en:format(required.displayName),de=row.de:format(required.displayName)},done)end
   return show(game,text.future,done)
  end
  if s.phase~='active'then return show(game,errorText('fight_pending'),done)end
  local opponent=D.opponents[D.order[index]]
  if not opts.newBattle then return show(game,errorText('battle_adapter_missing'),done)end
  -- The native factory validates and assembles the authored team before the
  -- durable fight token is reserved. Failed validation cannot advance state.
  local battle,reason,rollback,arm=opts.newBattle(game,opponent,index)
  if not battle then return show(game,errorText(reason),done)end
  local ok,sealed=S.beginFight(game,index)
  if not ok then if rollback then rollback()end;return show(game,errorText(sealed),done)end
  battle.kaBaldCrew=true;battle.kaBaldCrewToken=sealed.battle.token
  if arm then
   local armed,why=arm(sealed.battle.token)
   if not armed then
    S.finishFight(game,sealed.battle.token,'abort')
    if rollback then rollback()end
    return show(game,errorText(why),function()R.returnOutside(game);if done then done()end end)
   end
  end
  battle.ascendantNoItems=true;battle.noPrizeMoney=true;battle.enemyAIMods={1,2,3}
  local finished=false
  battle.onFinish=function(result)
   -- A delayed/native callback may be delivered twice. Neither afterBattle
   -- nor its dialog/warp may run again for an already consumed callback.
   if finished then return false end
   finished=true
   if npc then npc.frozen=false end
   local won=result=='win'
   if won and opponent.secretFinalBoss and(not battle.kaCrewCheatUsed or battle.kaCrewPhase~=2)then
    won=false -- Never grant a one-phase victory if another mod bypassed the finale.
   end
   if not won then recoverParty(game)end
   local committed,state=S.finishFight(game,sealed.battle.token,won and'win'or'lose')
   -- Defeat is a trial withdrawal, never vanilla money-halving/blackout.
   ow:afterBattle(won and'win'or'run',battle)
   if not committed then
    return show(game,errorText(state),function()R.returnOutside(game);if done then done()end end)
   end
   local personal=(won and text.defeatedBy or text.victorious)[opponent.id]
   local function joined(row)
    return personal and{en=personal.en..'\f'..row.en,de=personal.de..'\f'..row.de}or row
   end
   if won and state.phase=='reward'then
    return show(game,joined(text.reward),function()R.returnOutside(game);if done then done()end end)
   elseif won then
    local extra=index==3 and text.halfTime or index==7 and text.reveal
    return show(game,extra and joined(extra)or personal or text.defeated,function()
     refresh(game,ow);if done then done()end
    end)
   end
   return show(game,joined(opponent.secretFinalBoss and text.finalLoss or text.loss),function()
    R.returnOutside(game);if done then done()end
   end)
  end
  if npc then npc.frozen=true;if npc.facePlayer then npc:facePlayer(ow.player)end end
  ow:pushBattle(battle);return true
 end
 function R.talk(game,ow,npc,kind,index,done)
  if kind=='stairs'then return show(game,text.stairs,done)end
  if kind=='rear'then return show(game,S.isSealed()and text.sealed or text.rear,done)end
  if kind=='front'or kind=='restart'then
   if S.rewardPending()then
    if opts.claimReward then return opts.claimReward(game,done)end
    return show(game,errorText('reward_adapter_missing'),done)
   end
   if S.isSealed()then return show(game,text.sealed,done)end
   local s=S.status()
   local row=text.front
   if s and s.phase=='paused'then
    local nextName=D.opponents[D.order[s.next]].displayName
    row={en=text.restart.en:format(nextName),de=text.restart.de:format(nextName)}
   end
   return show(game,row,done,function(yes)
    if yes then local ok,why=R.enter(game);if not ok then return show(game,errorText(why),done)end end
    if done then done()end
   end)
  end
  if kind=='exit'then
   return show(game,text.exit,done,function(yes)
    if yes then local ok,why=S.withdraw(game)
     if ok then R.returnOutside(game)else return show(game,errorText(why),done)end
    end
    if done then done()end
   end)
  end
  if kind=='fight'then
   local s=S.status()
   if not s or s.phase~='active'or index~=s.next then return fight(game,ow,npc,index,done)end
   local line=assert(text.trainers[D.order[index]])
   if D.order[index]=='omega_dias'and mod.save then
    local c=mod.save:get('extended_characters',{})
    local hero=type(c)=='table'and tostring(c.player_character or'RED'):upper()or'RED'
    local variant=text.callOmega[hero]or text.callOmega.RED
    line={en=variant.en..'\f'..line.en,de=variant.de..'\f'..line.de}
   end
   return show(game,line,function()fight(game,ow,npc,index,done)end)
  end
  if done then done()end
 end
 function R.onMapEntered(ev)
  local game=ev and ev.game or R.game;if not game then return end
  local s=S.status();if not s then return end
  local map=ev and ev.mapId or live(game)
  local returning=R.returning and map==I.entrance;R.returning=false
  if map==I.map then
   if not S.canEnterInstance()then return R.returnOutside(game)end
   return R.sync(game,map)
  end
  if not returning and ev and ev.fromMapId==I.map and s.phase=='active'then
   local ok,why=S.withdraw(game)
   if not ok then
    -- A failed reset must not leave a free healing detour outside while the
    -- saved checkpoint still records the middle of a three-fight block.
    mod.world:warpTo(I.map,I.entry[1],I.entry[2],'up')
    show(game,errorText(why));return false,why
   end
   s=S.status()
  end
  if R.ownsCave()and I.sealedStockMaps[map]then
   -- Only a live invitation/run owns the cave; fail, withdrawal and victory
   -- release every original floor and both Route4 entrances immediately.
   return R.returnOutside(game,map~=I.host)
  end
  if map==I.entrance and s.phase=='locked'and opts.eligible and opts.eligible(game)
    and(not opts.invited or opts.invited())then S.unlock(game)end
  R.sync(game,map)
 end
 function R.install(game)
  R.game=game;C.bindRuntime(R)
  local previous=S.status();local recovering=previous and previous.phase=='battle'
  if recovering then recoverParty(game)end
  local ok,why=S.recover(game);if not ok then return false,why end
  if not R.installed then
   -- Keep the ORIGINAL Route4 sign. Only its event-time text changes.
   if not opts.show then
    local OW=require('src.world.OverworldController');local mapText=OW.showMapText
    OW.showMapText=function(ow,key,npc,done)
     local s=S.status()
     if R.game and R.game.overworld==ow and live(R.game)==I.entrance
       and key=='TEXT_ROUTE4_MT_MOON_SIGN'and s
       and R.ownsCave()then
      return show(R.game,text.sign,done)
     end
     return mapText(ow,key,npc,done)
    end
   end
   if mod.events then mod.events:on('map.entered',R.onMapEntered)end
   if mod.hooks then
    mod.hooks:wrap('battle.run',function(nextRun,ctx)
     if ctx and ctx.battle and ctx.battle.kaBaldCrew then return false end
     return nextRun(ctx)
    end,942)
    mod.hooks:wrap('item.use',function(nextUse,game,battle,...)
     if live(game)==I.map and S.canEnterInstance()then
      show(game,text.noItems);return false
     end
     return nextUse(game,battle,...)
    end,942)
    mod.hooks:wrap('ui.party.submenu',function(nextItems,game,items,mon,ctx)
     local rows=nextItems(game,items,mon,ctx)
     if live(game)~=I.map or not S.canEnterInstance()or ctx and ctx.battle then return rows end
     -- Field Softboiled would heal between consecutive fights. Battle
     -- healing moves and held-item effects remain entirely untouched.
     local out={}
     for _,row in ipairs(rows or{})do
      if row.action~='softboiled'and row.action~='milk_drink'then out[#out+1]=row end
     end
     return out
    end,942)
   end
   R.installed=true
  end
  if recovering and live(game)==I.map then return R.returnOutside(game)end
  R.onMapEntered({game=game,mapId=live(game),via='boot'})
  return true
 end
 return R
end
