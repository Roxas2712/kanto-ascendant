-- Team status recovery and a timed SIDE condition, not a saved Pokemon buff.
-- Reserve recipients are read from the actual party; no ability slot is bound.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Status=require('src.battle.StatusRegistry');local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-TEAM-RECOVERY',OWNER='kasc.team-recovery/v1'}
  local tr=opts.i18n.text;local A=assert(opts.abilities);local binding=assert(opts.binding)
  local defs={HEAL_BELL={number=215,gen=2,pp=5,type='NORMAL',target=13,anim='RECOVER'},
    -- PETAL_DANCE's host falling-object emitter has invalid motion indices.
    -- Use the already valid inward recovery particles for this OWN clone,
    -- leaving the original Petal Dance data and emitter entirely untouched.
    AROMATHERAPY={number=312,gen=3,pp=5,type='GRASS',target=13,anim='GROWTH'},
    REFRESH={number=287,gen=3,pp=20,type='NORMAL',target=7,anim='RECOVER'},
    SAFEGUARD={number=219,gen=2,pp=25,type='NORMAL',target=4,anim='LIGHT_SCREEN'}}
  local aliases={};local contexts=setmetatable({},{__mode='k'})
  local statuses={SLP=true,PSN=true,PAR=true,BRN=true,FRZ=true}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function id(move)return move and(aliases[move.id]or move.id)end
  local function side(b,w)return b and w and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function party(b,key)return key=='player'and b.game.save.party
    or key=='enemy'and(b.enemyParty or{b.enemy.mon})or{}end
  local function index(b,w)
    local key=side(b,w);for i,mon in ipairs(party(b,key)or{})do if mon==w.mon then return i end end
  end
  local function live(mon)return type(mon)=='table'and type(mon.hp)=='number'and mon.hp>0
    and not(mon.isEgg or mon.is_egg or mon.egg or mon.eggSpecies or mon.status=='EGG')end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt
    local marker=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or type(r)~='table'
        or type(r.activeEpoch)~='number'or r.activeEpoch%1~=0 or r.activeEpoch<1 or r.activeEpoch>7
        or r.mode~='gen'..r.activeEpoch or not marker or marker.kascTeamRecovery67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local d=defs[id(move)];local effect=b.data.move_effects[move.effect]
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
        or not effect or effect.kascTeamRecovery67~=M.OWNER then return end
    if r.activeEpoch<d.gen and not(side(b,u)and live(u.mon)and index(b,u)
        and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(d.gen,r.activeEpoch)
  end
  function M.safeguardActive(b,w)
    local key=side(b,w);local r=rows(b);local v=r and key and r[key];local turn=b and(b.turnCount or 0)
    local gen=M.epoch(b)
    return gen and type(v)=='table'and type(v.applied)=='number'and v.applied%1==0 and v.applied>=0
      and type(v.expires)=='number'and v.expires==v.applied+4 and v.epoch==math.max(2,gen)
      and turn>=v.applied and turn<=v.expires or false
  end
  function M.clearSafeguard(b,w)
    local key=side(b,w);if not key then return false end
    local r=rows(b);local present=r and r[key]~=nil
    if r then r[key]=nil;if not next(r)then b.field.tokens[M.OWNER]=nil end end
    -- false distinguishes a real removal from Infiltrator's scoped nil mask.
    if present then w.safeguard=false end
    return present or false
  end
  local function infiltrates(b,u,t,move)
    return M.epoch(b)and M.epoch(b)>=5 and side(b,u)and side(b,t)and u~=t
      and move and b.data.moves[move.id]and A.activeAbility(b,u)=='INFILTRATOR'or false
  end
  -- Called at the real volatile APPLICATION boundary, not at action preview.
  -- Yawn tests the guard now; eventual sleep has an explicit source exception.
  function M.blocksVolatile(b,t,kind,u,move)
    if kind~='confusion'and kind~='yawn'then return false end
    return M.safeguardActive(b,t)and side(b,u)and index(b,u)and index(b,t)
      and live(t.mon)and u~=t and not infiltrates(b,u,t,move)or false
  end
  function M.blocksStatus(b,t,status,options)
    if not statuses[status]or not M.safeguardActive(b,t)or not index(b,t)or not live(t.mon)then return false end
    local o=options or{};local ctx=contexts[b]
    local u=o.kascStatusSource67
    if not side(b,u)or not index(b,u)then u=nil end
    if not u and ctx and ctx.target==t and ctx.move.id==o.source then u=ctx.user end
    -- Items/self-status/unattributed host effects are not guessed to be foes.
    if not side(b,u)or not index(b,u)or u==t then return false end
    local yawn=b.data.move_effects.KA_DELAYED_YAWN_67
    if o.source=='YAWN'and o.kascDelayedSleep67=='kasc.delayed-sleep/v1'
        and yawn and yawn.kascDelayedSleep67=='kasc.delayed-sleep/v1'then return false end
    local move=b.data.moves[o.source]
    -- Infiltrator bypasses its actual direct move, never an ability, held item
    -- or previously installed hazard which happens to share a move ID.
    local direct=ctx and ctx.user==u and ctx.target==t and ctx.move.id==o.source
    return not(direct and not o.kascEntryHazard67 and infiltrates(b,u,t,move))
  end
  function M.inflict(original,b,t,status,options,...)
    if M.blocksStatus(b,t,status,options)then
      return{tr('%s is protected by Safeguard!','%s wird von Bodyguard geschützt!'):format(t.name)}
    end
    return original(b,t,status,options,...)
  end
  local function scoped(b,ctx,fn,...)
    local prior=contexts[b];contexts[b]=ctx;local out=pack(pcall(fn,...));contexts[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.context(original,b,u,t,...)
    local ctx=original(b,u,t,...);if not M.epoch(b)or not side(b,u)or not side(b,t)then return ctx end
    local inflict=ctx.inflict
    ctx.inflict=function(w,status,options)
      -- Only the facade's genuine synchronous source/target/move is proof.
      local current={user=u,target=w,move=ctx.move}
      return scoped(b,current,inflict,w,status,options)
    end
    return ctx
  end
  local function activeForMon(b,key,mon)
    local w=b[key];return w and w.mon==mon and w or nil
  end
  local function ability(b,key,mon)
    local gen=M.epoch(b);if not gen or gen<3 then return end
    local w=activeForMon(b,key,mon);if w then return A.activeAbility(b,w)end
    -- Pure canonical view only: no plan(), temporary active-only override,
    -- or arbitrary reserve shadow is ever installed into a battle side.
    local v=binding.view(b.game,mon,gen);return v and v.active and v.id or nil
  end
  local function recipients(b,u,move,gen)
    local key=side(b,u);local out={};if not key or not index(b,u)then return out end
    local name=id(move)
    for _,mon in ipairs(name=='REFRESH'and{u.mon}or party(b,key)or{})do
      if live(mon)and statuses[mon.status]and(name~='REFRESH'or mon.status=='PSN'or mon.status=='BRN'or mon.status=='PAR')then
        local w=activeForMon(b,key,mon);local aid=ability(b,key,mon);local skip=false
        if name=='HEAL_BELL'then skip=gen~=2 and gen~=5 and aid=='SOUNDPROOF'
        elseif name=='AROMATHERAPY'and gen>=6 and mon~=u.mon then
          skip=aid=='SAP_SIPPER'or w and w.substituteHP~=nil
        end
        if not skip then out[#out+1]={mon=mon,who=w}end
      end
    end
    return out
  end
  function M.noUseful(b,u,t,move)
    local gen=M.epoch(b,u,move);if not gen then return false end
    if not side(b,u)or not index(b,u)or not live(u.mon)then return true end
    if id(move)=='SAFEGUARD'then return M.safeguardActive(b,u)end
    return #recipients(b,u,move,gen)==0
  end
  local function failed()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  function M.cast(ctx)
    local b,u,move=ctx.battle,ctx.user,ctx.move;local gen=M.epoch(b,u,move)
    if not gen or not side(b,u)or not index(b,u)or not live(u.mon)then return failed()end
    local name=id(move)
    if name=='SAFEGUARD'then
      if M.safeguardActive(b,u)then return failed()end
      local turn=b.turnCount or 0;rows(b,true)[side(b,u)]={applied=turn,expires=turn+4,epoch=gen}
      u.safeguard=true
      return{tr('Your team is protected by Safeguard!','Dein Team wird von Bodyguard geschützt!')}
    end
    local list=recipients(b,u,move,gen)
    -- III-IV and V team cures deliberately succeed even if no status cures;
    -- the VI-VII source returns success=false. Refresh always needs a cure.
    if #list==0 and(name=='REFRESH'or gen>=6)then return failed()end
    local lifecycle=assert(mod.exports.pokemonStatusLifecycle67,'team recovery requires native sleep lifecycle')
    for _,r in ipairs(list)do
      r.mon.status=nil
      local w=r.who or{mon=r.mon}
      w.toxicCounter=nil;lifecycle.clear(w,b)
    end
    return{tr('The team\'s status problems were cured!','Die Statusprobleme des Teams wurden geheilt!')}
  end
  function M.endTurn(ev)
    local b=ev and ev.battle;local r=rows(b);if not r then return end
    for _,key in ipairs({'player','enemy'})do local v=r[key]
      if v and(not M.epoch(b)or(b.turnCount or 0)>=v.expires)then
        M.clearSafeguard(b,b[key])
        if M.epoch(b)then b:sayNext(tr('Safeguard wore off!','Bodyguard ist verschwunden!'))end
      end
    end
  end
  function M.switched(ev)
    local b,w=ev and ev.battle,ev and ev.battler
    if M.epoch(b)and side(b,w)then w.safeguard=M.safeguardActive(b,w)or nil end
  end
  function M.finish(ev)
    local b=ev and ev.battle;if not b then return end
    local r=rows(b);if r then for _,key in ipairs({'player','enemy'})do if r[key]and b[key]then b[key].safeguard=nil end end
      b.field.tokens[M.OWNER]=nil end;contexts[b]=nil
  end
  function M.validateCheckpoint(b)
    if contexts[b]then return false,'unsettled_team_recovery'end
    local r=rows(b);if r==nil then return true end
    local profile=M.epoch(b);if not profile or type(r)~='table'then return false,'inactive_or_invalid_safeguard'end
    for key,v in pairs(r)do
      if(key~='player'and key~='enemy')or not b[key]or type(v)~='table'
          or type(v.applied)~='number'or v.applied%1~=0 or v.applied<0 or v.applied>(b.turnCount or 0)
          or v.expires~=v.applied+4 or(b.turnCount or 0)>v.expires or v.epoch~=math.max(2,profile)then
        return false,'invalid_safeguard_side_or_timeline'
      end
      for k in pairs(v)do if k~='applied'and k~='expires'and k~='epoch'then return false,'unknown_safeguard_field'end end
    end
    return true
  end
  for name,d in pairs(defs)do
    local f=assert(opts.facts.move(name,7));local old=assert(mod.content.moves:get(name),'team recovery catalog missing '..name)
    assert(f.number==d.number and f.generation==d.gen and f.type==d.type and f.category=='status'
      and f.pp==d.pp and f.power==0 and f.accuracy==100 and f.alwaysHits and f.priority==0 and f.target==d.target,
      'team recovery source drift '..name)
    assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..name,'foreign team recovery owner '..name)
    local effect='KA_TEAM_RECOVERY_67_'..name
    mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascTeamRecovery67=M.OWNER,run=M.cast})
    for _,alias in ipairs(opts.species.moveIds(name))do if mod.content.moves:get(alias)then aliases[alias]=name
      mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,originGeneration=d.gen,
        power=0,pp=d.pp,category='status',target=d.target})end end;aliases[name]=name
    local anim=copy(assert(mod.content.battle_anims:get(d.anim),'team recovery native animation missing'))
    anim.source=M.OWNER;mod.content.battle_anims:patch(name,anim)
    for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==name then table.remove(opts.catalog.unsupportedStatus,i)end end
  end
  for _,name in ipairs({'POISON_EFFECT','PARALYZE_EFFECT','SLEEP_EFFECT'})do
    local previous=assert(mod.content.move_effects:get(name).run)
    mod.content.move_effects:patch(name,{run=function(ctx)
      if not M.epoch(ctx.battle)then return previous(ctx)end
      return scoped(ctx.battle,ctx,previous,ctx)
    end})
  end
  function M.position(player,name)
    local anim=player.data and player.data.moveAnims and player.data.moveAnims[name]
    if not defs[name]or not anim or anim.source~=M.OWNER then return end
    local hud=assert(mod.exports.pokemonPartnerHits67,'team recovery needs actual HUD owner')
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and(q.y<16 or hud.inHud(q))then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    Status._kascTeamRecovery67=M;FX._kascTeamRecovery67=M;Player._kascTeamRecovery67=M
    if not Status._kascTeamRecoveryWrapped67 then local original=Status.inflict
      Status.inflict=function(...)return Status._kascTeamRecovery67.inflict(original,...)end
      Status._kascTeamRecoveryWrapped67=true end
    if not FX._kascTeamRecoveryWrapped67 then local original=FX.makeCtx
      FX.makeCtx=function(...)return FX._kascTeamRecovery67.context(original,...)end
      FX._kascTeamRecoveryWrapped67=true end
    if not Player._kascTeamRecoveryWrapped67 then local start=Player.start
      Player.start=function(self,name,...)local out=pack(start(self,name,...));Player._kascTeamRecovery67.position(self,name);return unpack(out,1,out.n)end
      Player._kascTeamRecoveryWrapped67=true end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascTeamRecovery67=M.OWNER})
  mod.events:on('battle.turn_ended',M.endTurn,94)
  mod.events:on('battle.battler_switched',M.switched,6490)
  mod.events:on('battle.ended',M.finish,10100)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='canonical-party-and-status-lifecycle-provenance',
    providerStatus='team-status-cures-and-five-turn-side-safeguard',buildReceiptId='docs/TEAM_RECOVERY_67.md',
    rollbackReceiptId='docs/TEAM_RECOVERY_67.md'})end
  return M
end
