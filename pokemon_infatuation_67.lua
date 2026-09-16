-- Battle-local infatuation. Side tokens survive native semantic checkpoints;
-- no gender, status or volatile is written permanently onto the Pokemon.
return function(mod,opts)
  local M={CARD_ID='KASC-67-INFATUATION',OWNER='kasc.infatuation/v1'}
  local Battle=require('src.battle.BattleState')
  local Status=require('src.battle.Status')
  local tr=opts.i18n.text
  local frames=setmetatable({},{__mode='k'})
  local function list(b,create)
    if create then b.field=b.field or {};b.field.tokens=b.field.tokens or {}end
    local tokens=b and b.field and b.field.tokens
    if create and not tokens[M.OWNER] then tokens[M.OWNER]={}end
    return tokens and tokens[M.OWNER]
  end
  local function side(b,who)
    return who==b.player and 'player' or who==b.enemy and 'enemy' or nil
  end
  local function egg(mon)
    return mon.isEgg or mon.egg or mon.eggSpecies or mon.species=='EGG'
  end
  function M.epoch(b)
    local record=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=record and record.kascInfatuation67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  function M.clear(b)
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end
  function M.validateCheckpoint(b)
    local rows=list(b)
    if rows==nil then return true end
    if type(rows)~='table' then return false,'invalid_infatuation_token' end
    for key,row in pairs(rows)do
      if (key~='player' and key~='enemy') or type(row)~='table'
          or (row.source~='player' and row.source~='enemy') or row.source==key then
        return false,'invalid_infatuation_source'
      end
      for field in pairs(row)do if field~='source' then return false,'invalid_infatuation_field' end end
    end
    return true
  end
  function M.state(b,who)
    if not M.epoch(b) then M.clear(b);return end
    local rows=list(b);local key=side(b,who);local row=rows and rows[key]
    if not row then return end
    local source=b[row.source]
    if not source or source.mon.hp<=0 or not who or who.mon.hp<=0 then
      rows[key]=nil;return
    end
    -- Once infatuated, suppressing Cute Charm does not cure the victim.
    -- Only an actually active immunity owner can cure the volatile.
    if opts.abilities.activeAbility(b,who)=='OBLIVIOUS' then rows[key]=nil;return end
    return row
  end
  function M.oppositeGender(b,who,source)
    local gender=opts.gender
    local a,z=gender.getMonGender(who.mon,b.game),gender.getMonGender(source.mon,b.game)
    return a~=gender.GENDERLESS and z~=gender.GENDERLESS and a~=z
  end
  function M.start(b,who,source,reflected)
    if not M.epoch(b) or not side(b,who) or not side(b,source) or who==source
        or who.mon.hp<=0 or source.mon.hp<=0 or egg(who.mon) or egg(source.mon)
        or M.state(b,who) then return false end
    if opts.abilities.activeAbility(b,who)=='OBLIVIOUS'
        or opts.abilities.blocksMentalEffect(b,who,'ATTRACT')then return false end
    if not M.oppositeGender(b,who,source)then return false end
    list(b,true)[side(b,who)]={source=side(b,source)}
    b:sayStatusMsg(who,tr('%s\nfell in love!','%s\nist verliebt!'):format(who.name))
    if not reflected and M.epoch(b)>=4 and opts.held
        and opts.held(who.mon,b,who)=='DESTINY_KNOT'then
      M.start(b,source,who,true)
    end
    return true
  end
  function M.supportsItem(game,id,gen)
    local def=game and game.data and game.data.items and game.data.items[id]
    return id=='DESTINY_KNOT'and gen>=4 and gen<=7 and def
      and def.kascInfatuationItem67==M.OWNER or false
  end
  function M.check(b,who,rng)
    if not M.state(b,who) then return true,{} end
    local messages={tr('%s\nis in love!','%s\nist verliebt!'):format(who.name)}
    if rng(1,2)==1 then
      messages[#messages+1]=tr('Love stops action!','Liebe stoppt Zug!')
      -- Native cancellation owns Bide/rampage/charge/trap reset. It does
      -- not remove the separate infatuation token or the major status.
      b:clearVolatiles(who,true)
      return false,messages
    end
    return true,messages
  end
  function M.beforeMove(original,who,rng,b,...)
    if not M.epoch(b) then M.clear(b);return original(who,rng,b,...)end
    local previous=frames[who];local frame={battle=b,checked=false};frames[who]=frame
    local ok,canMove,msgs,selfHit=pcall(original,who,rng,b,...)
    frames[who]=previous
    if not ok then error(canMove,0)end
    if canMove and not selfHit and not frame.checked then
      local allowed,more=M.check(b,who,rng)
      msgs=msgs or {};for _,message in ipairs(more)do msgs[#msgs+1]=message end
      return allowed,msgs,selfHit
    end
    return canMove,msgs,selfHit
  end
  local par=assert(mod.content.statuses:get('PAR').beforeMove)
  mod.content.statuses:patch('PAR',{beforeMove=function(who,rng,b)
    local frame=frames[who];local gen=M.epoch(b)
    -- Emerald and Gen IV check paralysis before infatuation. The modern
    -- Gen V-VII owner checks infatuation first, after confusion/Disable.
    if frame and frame.battle==b and gen>=5 and not frame.checked then
      frame.checked=true
      local allowed,msgs=M.check(b,who,rng)
      if not allowed then return false,msgs end
      local canMove,more,selfHit=par(who,rng,b)
      for _,message in ipairs(more or {})do msgs[#msgs+1]=message end
      return canMove,msgs,selfHit
    end
    return par(who,rng,b)
  end})
  function M.install()
    Status._kascInfatuation67=M
    if not Status._kascInfatuationWrapped67 then
      local original=Status.beforeMove
      Status.beforeMove=function(...)return Status._kascInfatuation67.beforeMove(original,...)end
      Status._kascInfatuationWrapped67=true
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascInfatuation67=M.OWNER})
  if not mod.content.items:get('DESTINY_KNOT')then
    mod.content.items:register('DESTINY_KNOT',{id='DESTINY_KNOT',name=tr('Destiny Knot','Fatumknoten'),
      names={en='Destiny Knot',de='Fatumknoten'},price=4000,keyItem=false,tossable=true,
      needsTarget=false,originGeneration=4,kascInfatuationItem67=M.OWNER})
  end
  mod.events:on('battle.battler_switched',function(ev)M.clear(ev and ev.battle)end,8000)
  mod.events:on('battle.fainted',function(ev)M.clear(ev and ev.battle)end,8000)
  mod.events:on('battle.ended',function(ev)M.clear(ev and ev.battle)end,8000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-status-and-checkpoint',providerStatus='infatuation',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
