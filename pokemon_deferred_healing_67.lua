-- Slot-local wishes. Genuine native self-faint/replacement owns sacrifice;
-- a recovery can never revive a party member or alter battle stat bases.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-DEFERRED-HEALING',OWNER='kasc.deferred-healing/v1'}
  local defs={WISH={number=273,gen=3,type='NORMAL'},
    HEALING_WISH={number=361,gen=4,type='PSYCHIC_TYPE'},LUNAR_DANCE={number=461,gen=4,type='PSYCHIC_TYPE'}}
  local aliases={};local arming,immediate=setmetatable({},{__mode='k'}),setmetatable({},{__mode='k'})
  local nativeFaint,nativeSelfKO,nativeMenu=B.onFaint,B.selfDestruct,B.openReplacementMenu
  local tr=opts.i18n.text
  local function clone(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=clone(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function living(w)local p=w and w.mon;return p and integer(p.hp,1,99999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function party(b,key)return key=='player'and b:playerPartyView()or b.enemyParty or{b.enemy and b.enemy.mon}end
  local function index(b,key,p)for i,mon in ipairs(party(b,key)or{})do if i<=6 and mon==p then return i end end end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
      and integer(r.activeEpoch,1,7)and h and h.kascDeferredHealing67==M.OWNER and r.activeEpoch or nil
  end
  function M.profile(b,w,m)
    local epoch=M.epoch(b);local id=m and aliases[m.id];local d=id and defs[id]
    local e=d and b.data.move_effects[m.effect];local key=b and side(b,w)
    if not epoch or not d or not living(w)or not key or not index(b,key,w.mon)
        or m.backendMoveOwner~=M.OWNER or m.backendMoveNumber~=d.number
        or not e or e.kascDeferredHealing67~=M.OWNER then return end
    if epoch<d.gen and not(opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species]))then return end
    return math.max(epoch,d.gen),id
  end
  function M.candidates(b,w)
    local key=b and side(b,w);local out={};if not key then return out end
    for i,p in ipairs(party(b,key)or{})do
      if i<=6 and p~=w.mon and living({mon=p})and b.data.pokemon[p.species]then out[#out+1]={mon=p,index=i}end
    end;return out
  end
  local function valid(b,key,id,row)
    local gen=M.epoch(b);local d=defs[id];local turn=b.turnCount or 0
    if not gen or not d or type(row)~='table'or row.profile~=gen or row.epoch~=math.max(gen,d.gen)
        or aliases[row.native]~=id or not integer(row.applied,0,turn)
        or not integer(row.sourceIndex,1,6)or not integer(row.sourceMaximum,1,99999)
        or not integer(row.lastTurn,row.applied-1,turn)or row.due~=row.applied+(id=='WISH'and 1 or row.epoch==4 and 0 or 1)
        or turn>row.due then return false end
    local donor=(party(b,key)or{})[row.sourceIndex]
    if not donor or donor.species~=row.sourceSpecies or not b.data.moves[row.native]
        or b.data.moves[row.native].backendMoveOwner~=M.OWNER then return false end
    if id=='WISH'then return row.proof==nil end
    return row.proof==true and donor.hp==0
  end
  function M.record(b,w,id)
    local s=rows(b);local key=b and side(b,w);local lane=type(s)=='table'and key and s[key]
    local row=type(lane)=='table'and lane[id]
    return valid(b,key,id,row)and row or nil
  end
  local function heal(b,w,amount)
    if not living(w)or not integer(w.mon.stats and w.mon.stats.hp,1,99999)then return 0 end
    local hp=math.min(w.mon.stats.hp,w.mon.hp+math.max(0,math.floor(amount)))
    local changed=hp-w.mon.hp;if changed<=0 then return 0 end
    w.mon.hp=hp;b:drainNext(w,hp);return changed
  end
  local function fullRecovery(b,w,dance)
    if not living(w)or not integer(w.mon.stats and w.mon.stats.hp,1,99999)then return false end
    heal(b,w,w.mon.stats.hp);w.mon.status=nil;w.toxicCounter=nil
    opts.lifecycle.clear(w,b)
    if dance then
      -- Genuine native maximum PP with its actual PP-Up bonus, including
      -- party-backed slots. New entrants are not Transform projections.
      for i,slot in ipairs(w.curMoves or{})do if i<=4 then local m=b:moveDef(slot)
        if m and integer(m.pp,1,99)then
          local ups=integer(slot.ppUps or 0,0,3)and(slot.ppUps or 0)or 0
          slot.pp=m.pp+ups*math.floor(m.pp/5)
        end
      end end
    end
    return true
  end
  function M.fainted(ev)
    local b,w=ev and ev.battle,ev and ev.battler;local f=b and arming[b]
    if f and w==f.user and side(b,w)==f.side and w.mon.hp==0 and w.faintQueued
        and(rows(b)[f.side]or{})[f.id]==f.row then f.row.proof=true end
  end
  local function relocateNativeFaint(b,key,beforeCount,beforeTail)
    -- The unmodified0257 onFaint ends by appending its native faint-handler
    -- action. Move ONLY that just-created terminal row behind its own faint
    -- animation/text, before remaining actions; no round/action is copied.
    local row=b.queue[#b.queue]
    assert(b.onFaint==nativeFaint and row and type(row.fn)=='function'and not row.ui and not row.text
      and(not beforeCount or #b.queue>beforeCount and row~=beforeTail),
      'IV sacrifice needs exact native terminal faint-handler row')
    local original=row.fn
    row.fn=function()
      -- Native enemy replacement appends its own EXP/send-out rows. Keep
      -- those genuine newly-produced rows ahead of the already scheduled
      -- opposing action. Reorder identity-identical queue rows, never copy
      -- a faint, a switch, an action, or an extra round.
      local pending={};for _,old in ipairs(b.queue)do pending[old]=true end
      local kind=b.kind
      -- IV self-sacrifice forces a replacement, not the native wild-faint
      -- "use next Pokemon?/run" dialogue. Only that exact handler call gets
      -- its native trainer branch; the battle remains wild afterwards.
      if key=='player'and kind=='wild'then b.kind='trainer'end
      local result=pack(pcall(original));b.kind=kind
      if not result[1]then error(result[2],0)end
      local fresh,old={},{}
      for _,queued in ipairs(b.queue)do
        local list=pending[queued]and old or fresh;list[#list+1]=queued
      end
      for i=#b.queue,1,-1 do b.queue[i]=nil end
      for _,queued in ipairs(fresh)do b.queue[#b.queue+1]=queued end
      for _,queued in ipairs(old)do b.queue[#b.queue+1]=queued end
      b.nextInsert=#fresh
    end
    table.remove(b.queue,#b.queue);b.nextInsert=(b.nextInsert or 0)+1
    table.insert(b.queue,b.nextInsert,row)
  end
  local openIV
  function M.menu(original,b,forceNext,...)
    local pending=M.record(b,b.player,'HEALING_WISH')or M.record(b,b.player,'LUNAR_DANCE')
    if not pending or not b.player or b.player.mon.hp~=0 then return original(b,...)end
    local raw=rawget(b,'ui');local schedule=b.ui
    b.ui=function(self,factory)
      local guarded=function()
        local menu=factory();local choose,cancel=menu.onSwitch,menu.onCancel
        menu.onSwitch=function(p,ui)
          local allowed=false
          for _,pick in ipairs(M.candidates(self,self.player))do if p==pick.mon then allowed=true;break end end
          if not allowed then
            if ui and ui.refuse then ui:refuse(tr('Choose a healthy Pokemon, not an Egg.',
              'Wähle ein kampffähiges Pokémon, kein Ei.'))end
            return
          end
          return choose(p,ui)
        end
        if forceNext then menu.onCancel=function()
          if cancel then cancel()end
          self.nextInsert=0
          if immediate[self]and M.epoch(self)and self.player.mon.hp==0 then openIV(self)end
        end end
        return menu
      end
      -- Native uiNext returns nil. An and/or expression would therefore
      -- enqueue both branches and reopen a stale replacement menu.
      if forceNext then return self:uiNext(guarded)end
      return schedule(self,guarded)
    end
    local result=pack(pcall(original,b,...));b.ui=raw
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  openIV=function(b)
    b:actNext(function()
      local f=immediate[b]
      if not f or not M.epoch(b)or not b[f.side]or b[f.side].mon.hp>0 then return end
      if f.side~='player'or #M.candidates(b,b.player)==0 then immediate[b]=nil;return end
      M.menu(nativeMenu,b,true)
    end)
  end
  function M.cast(ctx)
    local b,w,m=ctx.battle,ctx.user,ctx.move;local gen,id=M.profile(b,w,m)
    local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
    if not gen or arming[b]or immediate[b]or(rows(b)and not M.validateCheckpoint(b))then return failed()end
    local maximum=w.mon.stats and w.mon.stats.hp;if not integer(maximum,1,99999)then return failed()end
    if id~='WISH'and(#M.candidates(b,w)==0 or b.onFaint~=nativeFaint or b.selfDestruct~=nativeSelfKO)then return failed()end
    if M.record(b,w,id)then return failed()end
    local key=side(b,w);local s=rows(b,true);s[key]=s[key]or{}
    local turn=b.turnCount or 0;local row={native=m.id,profile=M.epoch(b),epoch=gen,applied=turn,
      due=turn+(id=='WISH'and 1 or gen==4 and 0 or 1),sourceIndex=index(b,key,w.mon),
      sourceSpecies=w.mon.species,sourceMaximum=maximum,lastTurn=turn-1}
    s[key][id]=row
    if id=='WISH'then return{tr('%s made a wish!','%s spricht einen Wunsch aus!'):format(w.name)}end
    arming[b]={side=key,user=w,id=id,row=row}
    local beforeCount,beforeTail=#b.queue,b.queue[#b.queue]
    local out=pack(pcall(nativeSelfKO,b,w));arming[b]=nil
    if not out[1]then s[key][id]=nil;error(out[2],0)end
    assert(row.proof==true and w.mon.hp==0 and w.faintQueued,'sacrifice needs genuine native faint proof')
    if gen==4 then
      immediate[b]={side=key};relocateNativeFaint(b,key,beforeCount,beforeTail)
      if key=='player'then openIV(b)else immediate[b]=nil end
    end
    return{tr('%s sacrificed itself!','%s opfert sich selbst!'):format(w.name)}
  end
  function M.entry(ev,afterHazards)
    local b,w=ev and ev.battle,ev and ev.battler;local key=b and w and side(b,w)
    if not M.epoch(b)or not key or not ev.previous then return end
    local s=rows(b);local lane=type(s)=='table'and s[key];if type(lane)~='table'then return end
    local rescheduled=false
    for _,id in ipairs({'HEALING_WISH','LUNAR_DANCE'})do local row=lane[id]
      if row and valid(b,key,id,row)and(row.epoch==4)==afterHazards then
        if living(w)and fullRecovery(b,w,id=='LUNAR_DANCE')then
          lane[id]=nil;immediate[b]=nil
          if row.epoch==4 then w.lastMove=row.native end
          b:sayNext(tr('%s restored the incoming Pokemon!','%s heilt das eingewechselte Pokémon!')
            :format(b.data.moves[row.native].name))
        elseif row.epoch==4 and w.mon.hp==0 and w.faintQueued and not rescheduled then
          -- IV hazards can KO the intended receiver; the real next living
          -- receiver gets the wish. Never heal/revive this defeated entry.
          rescheduled=true;immediate[b]={side=key};relocateNativeFaint(b,key)
          if key=='player'then openIV(b)else immediate[b]=nil end
        end
      end
    end
  end
  function M.beforeStatus(b)
    if not M.epoch(b)or not M.validateCheckpoint(b)then return 0 end
    local s=rows(b);local changed=0;if not s then return changed end
    local turn=b.turnCount or 0
    for _,key in ipairs({'player','enemy'})do local lane=s[key];local w=b[key];local row=lane and lane.WISH
      if row and row.lastTurn~=turn then
        row.lastTurn=turn
        if turn>=row.due then
          lane.WISH=nil
          local block=mod.exports and mod.exports.pokemonHealBlock67
          if living(w)and not(block and block.blocksRecovery(b,w,'wish'))then
            local maximum=row.epoch<=4 and w.mon.stats and w.mon.stats.hp or row.sourceMaximum
            if integer(maximum,1,99999)and heal(b,w,math.max(1,maximum/2))>0 then
              b:sayNext(tr('The wish restored %s!','Der Wunsch heilt %s!'):format(w.name));changed=changed+1
            end
          end
        end
      end
    end
    return changed
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;if not M.epoch(b)or arming[b]or immediate[b]then return end
    local s=rows(b);if type(s)~='table'then return end
    local turn=b.turnCount or 0
    for _,key in ipairs({'player','enemy'})do local lane=s[key]
      if type(lane)=='table'then for _,id in ipairs({'HEALING_WISH','LUNAR_DANCE'})do local row=lane[id]
        if row and valid(b,key,id,row)then row.lastTurn=turn;if turn>=row.due then lane[id]=nil end end
      end end
    end
  end
  function M.noUseful(b,w,t,m)
    local gen,id=M.profile(b,w,m);if not gen then return false end
    if M.record(b,w,id)then return true end
    if id=='WISH'then return w.mon.hp>=w.mon.stats.hp end
    if w.mon.hp*2>w.mon.stats.hp then return true end
    for _,pick in ipairs(M.candidates(b,w))do local p=pick.mon
      if p.hp<p.stats.hp or p.status then return false end
      if id=='LUNAR_DANCE'then for _,slot in ipairs(p.moves or{})do local d=b.data.moves[slot.id]
        if d and slot.pp<d.pp+(slot.ppUps or 0)*math.floor(d.pp/5)then return false end
      end end
    end;return true
  end
  function M.validateCheckpoint(b)
    if arming[b]or immediate[b]then return false,'unsettled_sacrifice'end
    local s=rows(b);if s==nil then return true end
    if type(s)~='table'or not M.epoch(b)then return false,'invalid_deferred_healing_container'end
    for key,lane in pairs(s)do
      if(key~='player'and key~='enemy')or type(lane)~='table'then return false,'invalid_healing_slot'end
      for id,row in pairs(lane)do
        if not valid(b,key,id,row)then return false,'invalid_healing_timeline'end
        for field in pairs(row)do if field~='native'and field~='profile'and field~='epoch'and field~='applied'
            and field~='due'and field~='sourceIndex'and field~='sourceSpecies'and field~='sourceMaximum'
            and field~='lastTurn'and field~='proof'then return false,'unknown_healing_field'end end
      end
    end;return true
  end
  for id,d in pairs(defs)do local f=assert(opts.facts.move(id,d.gen))
    assert(f.number==d.number and f.generation==d.gen and f.category=='status'and f.power==0
      and f.alwaysHits and f.target==7 and f.pp==10 and f.type==d.type,'deferred healing source drift '..id)
    for _,alias in ipairs(opts.species.moveIds(id))do local old=assert(mod.content.moves:get(alias))
      assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..alias,'foreign healing owner '..alias)
      aliases[alias]=id;local effect='KA_DEFERRED_HEALING_67_'..alias
      mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,
        kascDeferredHealing67=M.OWNER,run=M.cast})
      mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=old.backendLearnsetRevision or 1})
      local animation={seq={},source=M.OWNER}
      for _,part in ipairs(id=='WISH'and{'FOCUS_ENERGY','RECOVER'}or id=='HEALING_WISH'
        and{'FOCUS_ENERGY','LIGHT_SCREEN'}or{'LIGHT_SCREEN','RECOVER'})do
        for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=clone(step)end
      end
      if mod.content.battle_anims:get(alias)then mod.content.battle_anims:patch(alias,animation)
      else mod.content.battle_anims:register(alias,animation)end
      for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==alias then table.remove(opts.catalog.unsupportedStatus,i)end end
    end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascDeferredHealing67=M.OWNER})
  mod.events:on('battle.fainted',M.fainted,30001)
  mod.events:on('battle.battler_switched',function(ev)M.entry(ev,false)end,-10038.5)
  mod.events:on('battle.battler_switched',function(ev)M.entry(ev,true)end,-10039.5)
  mod.events:on('battle.turn_ended',M.endTurn,-20001)
  mod.events:on('battle.ended',function(ev)
    local b=ev.battle;arming[b]=nil;immediate[b]=nil
    if rows(b)then b.field.tokens[M.OWNER]=nil end
  end,10000)
  function M.move(original,b,inst,...)
    local m=original(b,inst,...);local id=m and aliases[m.id];local d=id and defs[id]
    if not d or m.backendMoveOwner~=M.OWNER or not M.epoch(b)then return m end
    local out=clone(m);out.flags=clone(m.flags or{})
    out.flags.snatch=math.max(M.epoch(b),d.gen)>=5 and 1 or nil
    return out
  end
  function M.position(player,id)
    local animation=player.data and player.data.moveAnims and player.data.moveAnims[id]
    local hud=mod.exports and mod.exports.pokemonPartnerHits67
    if not aliases[id]or not animation or animation.source~=M.OWNER or not(hud and hud.inHud)then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,sprite in ipairs(step.sprites or{})do local q=clone(sprite)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and hud.inHud(q)then q.x=0 end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    B._kascDeferredHealing67=M
    Player._kascDeferredHealing67=M
    if not Player._kascDeferredHealingWrapped67 then local start=Player.start
      Player.start=function(self,id,...)
        local out=pack(start(self,id,...));Player._kascDeferredHealing67.position(self,id);return unpack(out,1,out.n)
      end
      Player._kascDeferredHealingWrapped67=true
    end
    if not B._kascDeferredHealingWrapped67 then local move=B.moveDef
      local menu=B.openReplacementMenu
      B.moveDef=function(...)return B._kascDeferredHealing67.move(move,...)end
      B.openReplacementMenu=function(b,...)return B._kascDeferredHealing67.menu(menu,b,false,...)end
      B._kascDeferredHealingWrapped67=true
    end
  end
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-self-faint-party-replacement-and-before-status-slot-timeline',
    providerStatus='gen3-7-wish-gen4-7-healing-wish-lunar-dance',
    buildReceiptId='docs/DEFERRED_HEALING_67.md',rollbackReceiptId='docs/DEFERRED_HEALING_67.md'})end
  return M
end
