-- Singles side hazards. Entry damage precedes entry abilities/forms and is
-- never a direct attack receipt, Substitute hit, Bide input or saved status.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Status=require('src.battle.StatusRegistry');local Effects=require('src.battle.MoveEffects')
  local Player=require('src.battle.AnimPlayer');local Chart=require('src.battle.TypeChart')
  local A=assert(opts.abilities);local tr=opts.i18n.text
  local M={CARD_ID='KASC-67-ENTRY-HAZARDS',OWNER='kasc.entry-hazards/v1'}
  local defs={SPIKES={number=191,gen=2,type='GROUND',pp=20,parts={'PIN_MISSILE','PAY_DAY'}},
    TOXIC_SPIKES={number=390,gen=4,type='POISON',pp=20,parts={'POISON_STING','PIN_MISSILE'}},
    STEALTH_ROCK={number=446,gen=4,type='ROCK',pp=20,parts={'ROCK_THROW','PAY_DAY'}},
    STICKY_WEB={number=564,gen=6,type='BUG',pp=20,parts={'STRING_SHOT','BARRIER'}},
    DEFOG={number=432,gen=4,type='FLYING',pp=15,parts={'GUST','WHIRLWIND'}},
    RAPID_SPIN={number=229,gen=2,type='NORMAL',pp=40,parts={'COMET_PUNCH','GUST'}}}
  local names={'SPIKES','TOXIC_SPIKES','STEALTH_ROCK','STICKY_WEB'}
  local entrySeen=setmetatable({},{__mode='k'});local entryFrames=setmetatable({},{__mode='k'})
  local hitFrames=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function live(w)local m=w and w.mon;return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
    and not(m.egg or m.isEgg or m.eggSpecies or m.is_egg)end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function foe(b,w)return w==b.player and b.enemy or w==b.enemy and b.player or nil end
  local function has(w,typ)for _,v in ipairs(w.curTypes or{})do if v==typ then return true end end;return false end
  local function state(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local e=b and b.data and b.data.move_effects and b.data.move_effects.KA_ENTRY_HAZARD_67_SPIKES
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r and r.mode~='off'
        and type(r.activeEpoch)=='number'and r.activeEpoch%1==0 and r.activeEpoch>=1 and r.activeEpoch<=7
        and e and e.kascEntryHazard67==M.OWNER then return r.activeEpoch end
  end
  function M.moveEpoch(b,u,move)
    local gen=M.epoch(b);local d=move and defs[move.id]
    local e=d and b.data.move_effects[move.effect]
    if not gen or not d or move.backendMoveOwner~=M.OWNER or not e or e.kascEntryHazard67~=M.OWNER then return end
    if gen<d.gen then
      local source=u
      local bounce=mod.exports.pokemonMagicBounce67
      if bounce and bounce.reflectionSource then source=bounce.reflectionSource(b,u,move)or source end
      if not(live(source)and side(b,source)and opts.rules.ownedGiftBattleCompatible
          and opts.rules.ownedGiftBattleCompatible(b.game,source.mon,b.data.pokemon[source.mon.species]))then return end
    end
    return math.max(gen,d.gen)
  end
  function M.sideTarget(b,u,move)
    return M.moveEpoch(b,u,move)and move.id~='DEFOG'and move.id~='RAPID_SPIN'or false
  end
  function M.row(b,w,id)
    local s=state(b);local rows=s and s[side(b,w)];local r=rows and rows[id]
    local gen=M.epoch(b);local d=defs[id]
    if not gen or not d or id=='DEFOG'or id=='RAPID_SPIN'or type(r)~='table'
        or r.profile~=gen or r.epoch~=math.max(gen,d.gen)
        or type(r.applied)~='number'or r.applied%1~=0 or r.applied<0 or r.applied>(b.turnCount or 0)
        or type(r.layers)~='number'or r.layers%1~=0 or r.layers<1
        or r.layers>(id=='SPIKES'and(r.epoch==2 and 1 or 3)or id=='TOXIC_SPIKES'and 2 or 1)
        or r.order~=nil and(type(r.order)~='number'or r.order%1~=0 or r.order<1 or r.order>4294967295)then return end
    return r
  end
  function M.clear(b,w)
    local s=state(b);if not s then return false end
    if w then local key=side(b,w);if key and s[key]then local changed=next(s[key])~=nil;s[key]=nil;return changed end
    else b.field.tokens[M.OWNER]=nil;return true end
    return false
  end
  function M.any(b,w)for _,id in ipairs(names)do if M.row(b,w,id)then return true end end;return false end
  function M.grounded(b,w)
    if not M.epoch(b)or not live(w)then return false end
    local grounding=opts.grounding or mod.exports.pokemonGrounding67
    if grounding and grounding.epoch(b)then return not grounding.airborne(b,w)end
    -- II and licensed early fallback have no modern Grounding owner. Read
    -- actual Flying type only; do not promote abilities/items to a new era.
    return not has(w,'FLYING')
  end
  local function maxLayers(id,gen)return id=='SPIKES'and(gen==2 and 1 or 3)or id=='TOXIC_SPIKES'and 2 or 1 end
  local function append(out,rows)for _,v in ipairs(rows or{})do out[#out+1]=v end end
  local function shields(b,w)
    local screens=mod.exports.pokemonScreens67
    if screens and(screens.active(b,w,'REFLECT')or screens.active(b,w,'LIGHT_SCREEN')or screens.active(b,w,'AURORA_VEIL'))then return true end
    if w.reflect or w.lightScreen or w.mist or w.safeguard then return true end
    local team=mod.exports.pokemonTeamRecovery67
    return team and team.safeguardActive and team.safeguardActive(b,w)or false
  end
  local function safeguarded(b,w)
    local team=mod.exports.pokemonTeamRecovery67
    return w.safeguard or team and team.safeguardActive and team.safeguardActive(b,w)or false
  end
  local function mayDrop(b,w,stat)
    if A.blockStatDrop(b,w,stat,-1,true)or w.mist then return false end
    local delta=A.stageDelta(b,w,-1);local old=w.stages and w.stages[stat]or 0
    return delta<0 and old>-6 or delta>0 and old<6
  end
  function M.noUseful(b,u,t,move)
    local gen=M.moveEpoch(b,u,move);if not gen or not side(b,u)or not side(b,t)or not live(u)or not live(t)or u==t then return false end
    if move.id=='RAPID_SPIN'then return false end -- damage remains useful
    if move.id=='DEFOG'then
      local ctx={battle=b,user=u,target=t,move=move}
      if mod.exports.pokemonProtection67.blocks(ctx)or mod.exports.pokemonPriorityAbilities67.blocks(ctx)or t.invulnerable then return true end
      return not(M.any(b,t)or gen>=6 and M.any(b,u)or shields(b,t)
        or(not t.substituteHP or A.activeAbility(b,u)=='INFILTRATOR')and mayDrop(b,t,'evasion'))
    end
    local row=M.row(b,t,move.id);return row and row.layers>=maxLayers(move.id,gen)or false
  end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function change(b,u,w,move,stat,ignoreSub)
    local ctx={battle=b,user=u,target=w,move=move,rng=b.rng,
      changeStage=function(target,id,delta,fromEnemy)return Effects.changeStage(b,target,id,delta,fromEnemy)end}
    local sub=w.substituteHP;if ignoreSub then w.substituteHP=nil end
    local out=pack(pcall(opts.split.changeStage,ctx,w,stat,-1,true))
    if ignoreSub then w.substituteHP=sub end
    if not out[1]then error(out[2],0)end
    return out[2]or{}
  end
  function M.cast(ctx)
    local b,u,t,move=ctx.battle,ctx.user,ctx.target,ctx.move;local gen=M.moveEpoch(b,u,move)
    if not gen or not live(u)or not live(t)or not side(b,u)or not side(b,t)or u==t then return fail()end
    if move.id=='DEFOG'then
      if mod.exports.pokemonProtection67.blocks(ctx)or mod.exports.pokemonPriorityAbilities67.blocks(ctx)or t.invulnerable then return fail()end
      local out={};local useful=false
      if not t.substituteHP or A.activeAbility(b,u)=='INFILTRATOR'then
        local before=t.stages and t.stages.evasion or 0;append(out,change(b,u,t,move,'evasion',true))
        useful=(t.stages and t.stages.evasion or 0)~=before
      end
      useful=M.clear(b,t)or useful;if gen>=6 then useful=M.clear(b,u)or useful end
      if shields(b,t)then
        local screens=mod.exports.pokemonScreens67;if screens then screens.clear(b,t)else t.reflect=false;t.lightScreen=false end
        t.mist=false;t.safeguard=false
        local team=mod.exports.pokemonTeamRecovery67
        if team and team.clearSafeguard then team.clearSafeguard(b,t)end
        useful=true
      end
      if not useful then return fail()end
      out[#out+1]=tr('Defog cleared the battlefield!','Auflockern räumt das Kampffeld auf!');return out
    end
    local old=M.row(b,t,move.id);local maximum=maxLayers(move.id,gen)
    if old and old.layers>=maximum then return fail()end
    local s=state(b,true);local key=side(b,t);s[key]=s[key]or{}
    s[key][move.id]={layers=old and old.layers+1 or 1,profile=M.epoch(b),epoch=gen,applied=old and old.applied or b.turnCount or 0}
    return{tr('%s covered the opposing side!','%s bedeckt die gegnerische Seite!'):format(move.name)}
  end
  function M.indirect(b,w,amount,id)
    if not live(w)or A.blocksIndirect(b,w,'hazard')then return 0 end
    local sub,bide,rage=w.substituteHP,w.bideTurns,w.rageMove
    w.substituteHP,w.bideTurns,w.rageMove=nil,nil,nil
    local out=pack(pcall(b.applyDamage,b,w,math.max(1,math.floor(amount))))
    w.substituteHP,w.bideTurns,w.rageMove=sub,bide,rage
    if not out[1]then error(out[2],0)end
    if out[2]>0 then b:sayNext(tr('%s was hurt by %s!','%s wird durch %s verletzt!'):format(w.name,b.data.moves[id].name))end
    if w.mon.hp<=0 then b:onFaint(w)end
    return out[2]
  end
  function M.applyEntry(b,w)
    if not M.epoch(b)or not side(b,w)or not live(w)then return 0 end
    local s=state(b);local rows=s and s[side(b,w)];if not rows then return 0 end
    local total=0;entryFrames[b]=true
    local ok,err=pcall(function()
      -- Canonical side-condition insertion order is retained by timestamps;
      -- ties use the writer's stable serial, not pairs/hash order.
      local ordered={};for _,id in ipairs(names)do local row=M.row(b,w,id);if row then ordered[#ordered+1]={id=id,row=row}end end
      table.sort(ordered,function(a,z)if a.row.applied~=z.row.applied then return a.row.applied<z.row.applied end
        return a.row.order<z.row.order end)
      for _,v in ipairs(ordered)do
        if not live(w)then break end
        local id,row=v.id,v.row;local maxHP=w.mon.stats and w.mon.stats.hp
        if id=='STEALTH_ROCK'then
          local mult=Chart.effectiveness('ROCK',w.curTypes);if mult>0 then total=total+M.indirect(b,w,maxHP*mult/80,id)end
        elseif M.grounded(b,w)then
          if id=='SPIKES'then total=total+M.indirect(b,w,maxHP*({[1]=3,[2]=4,[3]=6})[row.layers]/24,id)
          elseif id=='TOXIC_SPIKES'then
            if has(w,'POISON')then
              rows[id]=nil;b:sayNext(tr('%s absorbed the Toxic Spikes!','%s absorbiert die Giftspitzen!'):format(w.name))
            elseif not has(w,'STEEL')and not w.mon.status and not safeguarded(b,w)
                and not(row.epoch==4 and A.activeAbility(b,w)=='MAGIC_GUARD')then
              local enemy=foe(b,w)
              -- A Baton-Passed Substitute is not a shield against side
              -- hazards. Preserve it around the genuine shared status
              -- dispatcher, whose vanilla Poison path otherwise blocks it.
              local sub=w.substituteHP;w.substituteHP=nil
              local out=pack(pcall(Status.inflict,b,w,'PSN',{source='TOXIC_SPIKES',toxic=row.layers>=2,
                kascStatusSource67=enemy,kascEntryHazard67=M.OWNER}))
              w.substituteHP=sub;if not out[1]then error(out[2],0)end
              for _,message in ipairs(out[2]or{})do b:sayNext(message)end
            end
          elseif id=='STICKY_WEB'then
            for _,message in ipairs(change(b,foe(b,w),w,b.data.moves.STICKY_WEB,'speed',true))do b:sayNext(message)end
          end
        end
      end
    end)
    entryFrames[b]=nil;if not ok then error(err,0)end;return total
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not M.epoch(b)then return end
    for _,w in ipairs(ev.battler and{ev.battler}or{b.player,b.enemy})do
      if live(w)and side(b,w)and not entrySeen[w]then entrySeen[w]=true;M.applyEntry(b,w)end
    end
  end
  function M.afterSpin(ctx)
    local b,u=ctx.battle,ctx.user;local f=hitFrames[b]
    if not M.moveEpoch(b,u,ctx.move)or not f or not f.confirmed or not live(u)then return end
    M.clear(b,u);u.leechSeeded=nil
    local traps=mod.exports.backendPartialTrapping67;if traps then traps.clear(b,u)end
    -- II native multi-turn binding is not a modern token. Release only the
    -- incoming trap; do not cancel the user's own unrelated locked move.
    u.boundTurns=nil;local enemy=foe(b,u)
    if enemy and enemy.trappingTurns then
      enemy.trappingTurns=nil;enemy.trapMove=nil;enemy.trapDamage=nil;enemy.trapHitSfx=nil
    end
    b:sayNext(tr('Rapid Spin cleared the hazards!','Turbodreher entfernt die Eintrittsgefahren!'))
  end
  function M.hit(ev)
    local f=ev and hitFrames[ev.battle]
    if f and f.hit and f.hit.user==ev.user and f.hit.target==ev.target and f.hit.move==ev.move
        and f.hit.damage==ev.damage and f.hit.attempt>0 then f.confirmed=true end
  end
  function M.run(original,b,ctx,record)
    if not ctx or ctx.move.id~='RAPID_SPIN'or not M.moveEpoch(b,ctx.user,ctx.move)then return original(b,ctx,record)end
    local prior=hitFrames[b];local f={};hitFrames[b]=f
    local raw,apply=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports.pokemonLethalHitSurvival67
      local attempt=survival and survival.incomingHit and survival.incomingHit(self,w)or amount
      local dealt=apply(self,w,amount)
      if w==ctx.target then f.hit={user=ctx.user,target=w,move=ctx.move,damage=dealt,attempt=attempt}end
      return dealt
    end
    local out=pack(pcall(original,b,ctx,record));b.applyDamage=raw;hitFrames[b]=prior
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.validateCheckpoint(b)
    if entryFrames[b]or hitFrames[b]then return false,'entry_hazard_unsettled'end
    local s=state(b);if s==nil then return true end
    if type(s)~='table'then return false,'invalid_hazard_container'end
    for key,rows in pairs(s)do
      if(key~='player'and key~='enemy')or type(rows)~='table'then return false,'invalid_hazard_side'end
      local orders={}
      for id,row in pairs(rows)do local d=defs[id]
        if not d or id=='DEFOG'or id=='RAPID_SPIN'or type(row)~='table'
            or type(row.profile)~='number'or row.profile%1~=0 or row.profile<1 or row.profile>7
            or row.profile~=M.epoch(b)or row.epoch~=math.max(row.profile,d.gen)
            or type(row.layers)~='number'or row.layers%1~=0 or row.layers<1 or row.layers>maxLayers(id,row.epoch)
            or type(row.applied)~='number'or row.applied%1~=0 or row.applied<0 or row.applied>(b.turnCount or 0)
            or type(row.order)~='number'or row.order%1~=0 or row.order<1 or row.order>4294967295
            or orders[row.order]then return false,'invalid_hazard_state'end
        orders[row.order]=true
        for k in pairs(row)do if k~='layers'and k~='profile'and k~='epoch'and k~='applied'and k~='order'then return false,'unknown_hazard_field'end end
      end
    end
    return true
  end
  for _,id in ipairs({'SPIKES','TOXIC_SPIKES','STEALTH_ROCK','STICKY_WEB','DEFOG','RAPID_SPIN'})do
    local d=defs[id];local f=assert(opts.facts.move(id,d.gen));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.gen and f.pp==d.pp and f.type==d.type and f.priority==0
      and f.category==(id=='RAPID_SPIN'and'physical'or'status'),'hazard move source drift '..id)
    assert(not old.backendMoveOwner,'foreign hazard move owner '..id)
    if id~='RAPID_SPIN'then
      local prior=mod.content.move_effects:get(old.effect)
      local screens=mod.exports.pokemonScreens67
      local knownDefog=id=='DEFOG'and old.effect=='KA_SCREEN_67_DEFOG'
        and screens and screens.OWNER=='kasc.screens/v1'
        and prior and prior.kind=='primary'and type(prior.run)=='function'
      assert(old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..id or knownDefog,'foreign hazard primary '..id)
    end
    local effect='KA_ENTRY_HAZARD_67_'..id
    mod.content.move_effects:register(effect,id=='RAPID_SPIN'and{kind='full',afterDamage=M.afterSpin,kascEntryHazard67=M.OWNER}
      or{kind='primary',accuracyChecked=false,run=M.cast,kascEntryHazard67=M.OWNER})
    local flags={metronome=1};if id=='RAPID_SPIN'then flags.protect=1;flags.mirror=1;flags.contact=1
    else flags.reflectable=1;if id=='DEFOG'then flags.protect=1;flags.mirror=1;flags.bypasssub=1
      elseif id~='STICKY_WEB'then flags.mustpressure=1 end end
    mod.content.moves:patch(id,{effect=effect,power=id=='RAPID_SPIN'and 20 or 0,pp=d.pp,accuracy=100,priority=0,
      type=d.type,category=id=='RAPID_SPIN'and'physical'or'status',target=(id=='DEFOG'or id=='RAPID_SPIN')and 10 or 6,
      flags=flags,kascBypassSub67=id~='RAPID_SPIN',backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
      originGeneration=d.gen,backendLearnsetRevision=old.backendLearnsetRevision or 1})
    local animation={source=M.OWNER,seq={}}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do animation.seq[#animation.seq+1]=copy(step)end end
    mod.content.battle_anims:patch(id,animation)
    for i=#opts.moves.unsupportedStatus,1,-1 do if opts.moves.unsupportedStatus[i]==id then table.remove(opts.moves.unsupportedStatus,i)end end
  end
  -- A side condition's insertion position persists when an existing layer
  -- is restarted. This is independent of source battler/switch/KO identity.
  local cast=M.cast
  M.cast=function(ctx)
    local rows=state(ctx.battle);local key=side(ctx.battle,ctx.target)
    local prior=rows and rows[key]and rows[key][ctx.move.id];local order=prior and prior.order
    if not order then order=1;for _,r in pairs(rows and rows[key]or{})do order=math.max(order,r.order+1)end end
    local messages=cast(ctx);local row=M.row(ctx.battle,ctx.target,ctx.move.id)
    if row then row.order=order end;return messages
  end
  -- Records were registered with the initial closure; explicitly replace
  -- only their owned primary run functions with the ordered writer.
  for _,id in ipairs({'SPIKES','TOXIC_SPIKES','STEALTH_ROCK','STICKY_WEB','DEFOG'})do
    mod.content.move_effects:patch('KA_ENTRY_HAZARD_67_'..id,{run=M.cast})
  end
  function M.position(player,id)
    local anim=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not defs[id]or not anim or anim.source~=M.OWNER then return end
    for _,step in ipairs(player.steps or{})do local sprites={}
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 and mod.exports.pokemonPartnerHits67.inHud(q)then q.x=0 end;sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    FX._kascEntryHazards67=M;Player._kascEntryHazards67=M
    if FX.runDamaging~=FX._kascEntryHazardsRun67 then local original=FX.runDamaging
      local wrapper=function(...)return FX._kascEntryHazards67.run(original,...)end
      FX.runDamaging=wrapper;FX._kascEntryHazardsRun67=wrapper
    end
    if not Player._kascEntryHazardsWrapped67 then local original=Player.start
      Player.start=function(self,id,...)local out=pack(original(self,id,...));Player._kascEntryHazards67.position(self,id);return unpack(out,1,out.n)end
      Player._kascEntryHazardsWrapped67=true
    end
  end
  mod.events:on('battle.started',M.entry,-10039)
  mod.events:on('battle.battler_switched',M.entry,-10039)
  mod.events:on('battle.damage_dealt',M.hit,31003)
  mod.events:on('battle.ended',function(ev)M.clear(ev.battle)end,8000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='real-native-sides-grounding-and-entry-events',providerStatus='singles-hazards-and-cleanup',
    buildReceiptId='docs/ENTRY_HAZARDS_67.md',rollbackReceiptId='docs/ENTRY_HAZARDS_67.md'})end
  return M
end
