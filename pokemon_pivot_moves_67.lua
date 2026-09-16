-- Genuine self-switch transactions; unlike Baton Pass, copy no volatiles.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer');local A=assert(opts.abilities)
  local M={OWNER='kasc.pivot-moves/v1',CARD_ID='KASC-67-PIVOT-MOVES'}
  local tr=opts.i18n.text
  local defs={U_TURN={number=369,birth=4,type='BUG',category='physical',power=70,contact=true,parts={'QUICK_ATTACK','STRING_SHOT'}},
    VOLT_SWITCH={number=521,birth=5,type='ELECTRIC',category='special',power=70,parts={'THUNDERBOLT'}},
    PARTING_SHOT={number=575,birth=6,type='DARK',category='status',power=0,parts={'GROWL'}}}
  local aliases={};for id in pairs(defs)do for _,a in ipairs(opts.species.moveIds(id))do aliases[a]=id end end
  local frames=setmetatable({},{__mode='k'});local pending=setmetatable({},{__mode='k'})
  local committing=setmetatable({},{__mode='k'})
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function int(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return b and(w==b.player and'player'or w==b.enemy and'enemy')or nil end
  local function party(b,key)return key=='player'and b:playerPartyView()or key=='enemy'and b.enemyParty end
  local function index(b,w)for i,p in ipairs(party(b,side(b,w))or{})do if i<=6 and p==w.mon then return i end end end
  local function live(w)local p=w and w.mon;return p and int(p.hp,1,999999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  function M.epoch(b,u,move)
    local r=b and b.kascGenerationRulesReceipt;local mark=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or not int(r.activeEpoch,1,7)
      or not(r.mode=='auto'or r.mode=='gen'..r.activeEpoch)or not mark or mark.kascPivotMoves67~=M.OWNER then return end
    if not move then return r.activeEpoch end
    local id=aliases[move.id]or move.id;local d=defs[id];local rec=d and b:effectRecord(move.effect)
    if not d or move.backendMoveOwner~=M.OWNER or move.backendMoveNumber~=d.number
      or not rec or rec.kascPivotMoves67~=M.OWNER then return end
    if r.activeEpoch<d.birth and not(live(u)and index(b,u)
      and opts.rules.monMoveAvailable(b.game,u.mon,move.id,r.activeEpoch,true))then return end
    return math.max(d.birth,r.activeEpoch),id
  end
  function M.isPending(w)return pending[w]~=nil end
  function M.candidates(b,w)
    if not M.epoch(b)or not live(w)or not side(b,w)or not index(b,w)or w==b.enemy and b.kind~='trainer'then return{}end
    local baton=assert(mod.exports.pokemonBatonPass67,'Pivot needs real native PartyMenu candidate provider')
    return baton.candidates(b,w)
  end
  local function validPick(b,w,pick)
    if type(pick)~='table'then return false end
    for _,p in ipairs(M.candidates(b,w))do if p.mon==pick.mon and p.index==pick.index then return true end end
    return false
  end
  -- Native healthy reserves and real usable attacks; never copy outgoing
  -- boosts into this evaluation or manufacture a replacement move/roster.
  function M.enemyPick(b,w)
    local foe=w==b.enemy and b.player or b.enemy;local chart=b.data.type_chart and b.data.type_chart.matchups or{}
    local best,score
    for _,pick in ipairs(M.candidates(b,w))do local p=pick.mon;local power=0
      for _,slot in ipairs(p.moves or{})do local m=b.data.moves[slot.id]
        if m and(m.power or 0)>0 and m.category~='status'and not(m.effect or''):find('UNSUPPORTED',1,true)
          and((M.epoch(b)==1 and not w.isPlayer and b.ruleset.enemyUnlimitedPP)or(slot.pp or 0)>0)then
          local mult=1;for _,row in ipairs(chart)do if row.attacker==m.type then
            for _,typ in ipairs(foe.curTypes or{})do if row.defender==typ then mult=mult*row.multiplier/10;break end end
          end end;power=math.max(power,m.power*mult)
        end
      end
      local value=p.hp/math.max(1,p.stats and p.stats.hp or p.hp)*100+math.min(200,power)/2
      if not best or value>score then best,score=pick,value end
    end;return best
  end
  local function authentic(b,w,h)
    local id=h and h.move and(aliases[h.move.id]or h.move.id);local d=id and defs[id]
    local rec=d and b:effectRecord(h.move.effect)
    return h and M.epoch(b)and live(w)and index(b,w)==h.party and side(b,w)==h.side
      and w.mon==h.mon and w.mon.species==h.species and h.turn==(b.turnCount or 0)
      and h.profile==M.epoch(b)and d and h.epoch==math.max(d.birth,h.profile)
      and h.move.backendMoveOwner==M.OWNER and h.move.backendMoveNumber==d.number
      and rec and rec.kascPivotMoves67==M.OWNER and h.proven==true
  end
  function M.authenticatesSwitch(b,w,context)
    local h=committing[b]
    return h and h.context==context and context and context.sourceCard==M.CARD_ID
      and context.voluntary==true and authentic(b,w,h)and h.user==w or false
  end
  function M.authenticatedEpoch(b,w,context)
    return M.authenticatesSwitch(b,w,context)and committing[b].epoch or nil
  end
  function M.commit(b,w,pick)
    local h=pending[w]
    if h and h.committed then return false end
    if not authentic(b,w,h)or not validPick(b,w,pick)then pending[w]=nil;return false end
    local context={voluntary=true,sourceCard=M.CARD_ID};h.context=context;h.user=w;h.committed=true;committing[b]=h
    if h.profile==4 then context.prepare=function(actual,old,fresh)
      assert(actual==b and old==w and fresh.mon==pick.mon and side(b,fresh)==h.side,'Pivot IV raw-history replacement identity')
      -- Native historical switch quirk ONLY in the surrounding IV profile.
      -- This is not TargetMemory/Instruct/learning provenance or a stage.
      fresh.lastMove=old.lastMove
    end end
    local out=pack(pcall(assert(mod.exports.pokemonForcedSwitch67).swap,b,w,pick,context))
    if not out[1]then committing[b]=nil;pending[w]=nil;error(out[2],0)end
    -- Pursuit owns its genuine queued interception/continuation. Keep this
    -- exact context scope until switched/fainted/EOT, not merely F.swap's
    -- synchronous return. A copied sourceCard string is never sufficient.
    if not out[2]or not out[3]then committing[b]=nil;pending[w]=nil end
    return unpack(out,2,out.n)
  end
  function M.choose(b,w,mon,menu)
    local h=pending[w]
    if h and h.committed then return false end
    if not authentic(b,w,h)then pending[w]=nil;if menu then menu:close()end;return false end
    local pick;for _,p in ipairs(M.candidates(b,w))do if p.mon==mon then pick=p;break end end
    if not pick then if menu and menu.refuse then menu:refuse(tr('Choose another healthy Pokemon.','Wähle ein anderes kampffähiges Pokémon.'))end;return false end
    if menu then menu:close()end;b.nextInsert=0;return M.commit(b,w,pick)
  end
  function M.openChoice(b,w)
    b:uiNext(function()return b:buildScreen('PartyMenu',{battle=b,party=b:playerPartyView(),forceSwitch=true,keepOpen=true,
      onSwitch=function(mon,menu)return M.choose(b,w,mon,menu)end,
      onCancel=function()b.nextInsert=0;if pending[w]and pending[w].committed then return end
        if authentic(b,w,pending[w])and#M.candidates(b,w)>0 then M.openChoice(b,w)
        else pending[w]=nil end end})end)
  end
  local function arm(ctx,f)
    local b,w=ctx.battle,ctx.user;local gen=M.epoch(b,w,ctx.move)
    if not gen or not f or f.ctx~=ctx or not f.declared or f.user~=w or f.mon~=w.mon
      or f.party~=index(b,w)or f.turn~=(b.turnCount or 0)or pending[w]or not live(w)or#M.candidates(b,w)==0 then return false end
    if ctx.target.mon.hp<=0 then
      -- The native faint handler settles victory after the hit pipeline.
      -- Do not insert a mandatory switch UI before defeating the last foe.
      local reserve=false
      if b.kind=='trainer'then for _,p in ipairs(party(b,side(b,ctx.target))or{})do
        if p~=ctx.target.mon and live({mon=p})and b.data.pokemon[p.species]then reserve=true;break end
      end end
      if not reserve then return false end
    end
    local h={move=ctx.move,mon=w.mon,species=w.mon.species,party=index(b,w),side=side(b,w),
      turn=b.turnCount or 0,profile=M.epoch(b),epoch=gen,proven=true};pending[w]=h
    b:actNext(function()
      if not authentic(b,w,h)or pending[w]~=h or#M.candidates(b,w)==0 then pending[w]=nil;return end
      if w==b.enemy then local pick=M.enemyPick(b,w);if pick then M.choose(b,w,pick.mon)else pending[w]=nil end
      else M.openChoice(b,w)end
    end);return true
  end
  local function phaseBlocks(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local memory=mod.exports.pokemonTargetMemory67
    return opts.priority.blocks(ctx)or opts.protection.blocks(ctx)
      or t.invulnerable and not(memory and memory.phaseBypass(b,u,t,ctx.move))
  end
  local function attackStat(b)return M.epoch(b)==1 and'special'or'specialAttack'end
  local function canChange(ctx,w,stat)
    if not live(w)then return false end
    local delta=A.stageDelta(ctx.battle,w,-1);local old=w.stages[stat]or 0
    if w.mist and delta<0 or A.blockStatDrop(ctx.battle,w,stat,-1,true)then return false end
    return old~=math.max(-6,math.min(6,old+delta))
  end
  function M.noUseful(b,u,t,move)
    local gen,id=M.epoch(b,u,move);if not gen then return false end
    if not live(u)or not live(t)or not index(b,u)or not index(b,t)or pending[u]then return true end
    if id~='PARTING_SHOT'then return false end
    return A.moveScope(b,u,t,true,function()
      local ctx={battle=b,user=u,target=t,move=move};if phaseBlocks(ctx)then return true end
      local absorb=mod.exports.pokemonTypeAbsorption67;if absorb and absorb.canAbsorb(b,u,t,move)then return true end
      -- VI selfSwitch survives a genuine landed onHit even at capped or
      -- blocked stages; VII requires at least one real successful change.
      return not canChange(ctx,t,'attack')and not canChange(ctx,t,attackStat(b))and(gen>=7 or#M.candidates(b,u)==0)
    end,move)
  end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function stage(ctx,w,stat)
    local original=w.stages;local changed=false
    -- Observe real native stage writes, including the drop BEFORE a
    -- Defiant/Competitive reaction restores it. Copy no stages and emit no
    -- fake boost event. The backing table receives each actual write.
    w.stages=setmetatable({},{__index=original,__newindex=function(_,key,value)
      if key==stat and value~=(original[key]or 0)then changed=true end;original[key]=value
    end})
    local out=pack(pcall(assert(mod.exports.backendSplitSpecial67).changeStage,ctx,w,stat,-1,true));w.stages=original
    if not out[1]then error(out[2],0)end;return out[2],changed
  end
  function M.cast(ctx)
    local b,u,t=ctx.battle,ctx.user,ctx.target;local gen,id=M.epoch(b,u,ctx.move);local f=frames[b]
    if not gen or id~='PARTING_SHOT'or not f or f.ctx~=ctx or not f.declared or f.user~=u
      or not live(u)or not live(t)or u==t or not index(b,u)or not index(b,t)then return fail()end
    return A.moveScope(b,u,t,true,function()
      if phaseBlocks(ctx)then return fail()end
      local absorption=mod.exports.pokemonTypeAbsorption67;if absorption and absorption.absorb(b,ctx)then return{}end
      if not b:accuracyRoll(ctx.move,u,t)then return fail()end
      local raw=t.substituteHP;t.substituteHP=nil
      local out=pack(pcall(function()
        local attack,a=stage(ctx,t,'attack');local special,z=stage(ctx,t,attackStat(b));local armed=false
        if gen<=6 or a or z then f.statusLanded=true;armed=arm(ctx,f)end
        if not(a or z or armed)then return fail(),false end
        -- A capped FIRST stat must not make the native Gen-I text sniffer
        -- cancel a genuinely successful second stat or VI self-switch.
        -- Preserve real guard/stage messages without their primary-failure
        -- marker (the whole onHit transaction did in fact succeed).
        local msgs={armed and tr('%s can switch out!','%s kann ausgewechselt werden!'):format(u.name)
          or tr('The parting words had an effect!','Die abschließenden Worte zeigen Wirkung!')}
        for _,m in ipairs(attack or{})do msgs[#msgs+1]=m end;for _,m in ipairs(special or{})do msgs[#msgs+1]=m end
        return msgs,true
      end));t.substituteHP=raw
      if not out[1]then error(out[2],0)end
      if not out[3]then return fail()end;return out[2]
    end,ctx.move)
  end
  function M.used(ev)local f=ev and frames[ev.battle]
    if f and ev.user==f.user and ev.target==f.target and ev.move.id==f.move.id
      and ev.move.effect==f.move.effect and ev.move.backendMoveOwner==M.OWNER and ev.isCalled==f.called then
      f.move=ev.move;f.declared=true
    end
  end
  function M.context(original,b,u,t,move,slot,called,...)
    local ctx=original(b,u,t,move,slot,called,...);local f=frames[b]
    if f and f.user==u and f.target==t and f.slot==slot and f.called==not not called
      and f.declared and ctx.move and ctx.move.id==f.move.id then f.ctx=ctx end;return ctx
  end
  function M.perform(original,b,u,t,slot,called,...)
    local m=slot and b:moveDef(slot);if not M.epoch(b,u,m)then return original(b,u,t,slot,called,...)end
    local before=frames[b];local f={user=u,target=t,mon=u.mon,party=index(b,u),turn=b.turnCount or 0,
      move=m,slot=slot,called=not not called};frames[b]=f
    local out=pack(pcall(original,b,u,t,slot,called,...));frames[b]=before
    if not out[1]then pending[u]=nil;committing[b]=nil;error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.hit(ev)
    local f=ev and frames[ev.battle];local h=f and f.hit
    if not h or h.consumed or h.user~=ev.user or h.target~=ev.target or h.move~=ev.move
      or h.damage~=ev.damage or not h.direct or h.damage<0 or(ev.typeMult or 0)<=0 or not f.declared then return end
    h.consumed=true;f.positive=true;f.hit=nil
  end
  function M.afterDamage(ctx)
    local f=frames[ctx.battle]
    if f and f.ctx==ctx and f.positive and live(ctx.user)then arm(ctx,f)end
  end
  function M.run(original,b,ctx,record,...)
    local gen,id;if ctx then gen,id=M.epoch(b,ctx.user,ctx.move)end;local f=frames[b]
    if not gen or id=='PARTING_SHOT'or not f or f.ctx~=ctx or not f.declared then return original(b,ctx,record,...)end
    local raw,previous=rawget(b,'applyDamage'),b.applyDamage
    b.applyDamage=function(self,w,amount)
      local survival=mod.exports.pokemonLethalHitSurvival67
      local attempted=survival and survival.incomingHit and survival.incomingHit(self,w)or amount
      local native=f.ctx or ctx
      local direct=w==native.target and native.user==f.user and live(w)and tonumber(attempted)and attempted>0
      local substitute=w.substituteHP~=nil
      local damage=previous(self,w,amount)
      f.hit={user=native.user,target=w,move=native.move,damage=damage,direct=direct,substitute=substitute}
      return damage
    end
    local out=pack(pcall(original,b,ctx,record,...));b.applyDamage=raw
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.clear(ev)
    local b=ev and ev.battle;if not b then return end
    if ev.battler then pending[ev.previous or ev.battler]=nil
      local h=committing[b];if h and(h.user==ev.previous or h.user==ev.battler)then committing[b]=nil end
    else pending[b.player]=nil;pending[b.enemy]=nil;frames[b]=nil;committing[b]=nil end
  end
  function M.validateCheckpoint(b)
    return not frames[b]and not committing[b]and not pending[b.player]and not pending[b.enemy],'unsettled_pivot_move_choice'
  end
  local function source(kind,id)for _,a in ipairs(opts.species.moveIds(id))do local r=mod.content[kind]:get(a);if r then return r end end end
  for id,d in pairs(defs)do local f=assert(opts.facts.move(id,d.birth));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==d.birth and f.type==d.type and f.category==d.category
      and f.power==d.power and f.pp==20 and f.priority==0 and f.accuracy==100 and f.target==10,'Pivot source drift '..id)
    assert(not old.backendMoveOwner and old.effect==(id=='PARTING_SHOT'and'KA_GEN_MOVE_STAT_'..id or'NO_ADDITIONAL_EFFECT'),
      'foreign Pivot owner '..id)
    local effect='KA_PIVOT_67_'..id
    mod.content.move_effects:register(effect,{kind=d.category=='status'and'primary'or'full',accuracyChecked=false,kascPivotMoves67=M.OWNER,
      run=d.category=='status'and M.cast or nil,afterDamage=d.category~='status'and M.afterDamage or nil})
    for _,a in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(a)then mod.content.moves:patch(a,{
      effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,backendLearnsetRevision=old.backendLearnsetRevision or 1,
      power=d.power,type=d.type,category=d.category,pp=20,accuracy=100,priority=0,target=10,contact=d.contact==true,
      originGeneration=d.birth,anim=copy(assert(source('moves',d.parts[1]),'missing Pivot native move').anim)})end end
    local animation={seq={},source=M.OWNER};for _,part in ipairs(d.parts)do
      for _,step in ipairs(assert(source('battle_anims',part),'missing Pivot native animation '..part).seq)do animation.seq[#animation.seq+1]=copy(step)end end
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,animation)else mod.content.battle_anims:register(id,animation)end
    if opts.catalog then for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end end end
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPivotMoves67=M.OWNER})
  function M.position(p,id)
    local row=p.data and p.data.moveAnims and p.data.moveAnims[id];if not defs[id]or not row or row.source~=M.OWNER then return end
    local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
    for _,step in ipairs(p.steps or{})do local out={};local shift=-16
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s);if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        local x,y=q.x-8,q.y-16;for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end;out[i]=q end
      step.sprites=out
    end
  end
  function M.install()
    B._kascPivotMoves67=M;FX._kascPivotMoves67=M;Player._kascPivotMoves67=M
    if not B._kascPivotMovesWrapped67 then local perform=B.performMove
      B.performMove=function(...)return B._kascPivotMoves67.perform(perform,...)end;B._kascPivotMovesWrapped67=true end
    if not FX._kascPivotMovesWrapped67 then local context,run=FX.makeCtx,FX.runDamaging
      FX.makeCtx=function(...)return FX._kascPivotMoves67.context(context,...)end
      FX.runDamaging=function(...)return FX._kascPivotMoves67.run(run,...)end;FX._kascPivotMovesWrapped67=true end
    if not Player._kascPivotMovesWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascPivotMoves67.position(self,id);return unpack(out,1,out.n)end
      Player._kascPivotMovesWrapped67=true end
  end
  -- Confirm the genuine direct hit before contact retaliation applies
  -- indirect damage to the actor and replaces applyDamage's latest view.
  M.install();mod.events:on('battle.move_used',M.used,100200);mod.events:on('battle.damage_dealt',M.hit,30998)
  mod.events:on('battle.battler_switched',M.clear,8003);mod.events:on('battle.fainted',M.clear,8003)
  mod.events:on('battle.turn_ended',M.clear,8003);mod.events:on('battle.ended',M.clear,8003)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-hit-and-stage-write-provenance-party-provider-authenticated-switch',providerStatus='genuine-singles-self-switch',
    buildReceiptId='docs/PIVOT_MOVES_67.md',rollbackReceiptId='docs/PIVOT_MOVES_67.md'})end
  return M
end
