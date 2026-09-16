-- Charges are a noCopy battle volatile, separate from passable stat stages.
-- Never restore an old stage table: remove only the source-era count through
-- the shared stat owner, retaining unrelated stat edits and ability rules.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Player=require('src.battle.AnimPlayer')
  local M={CARD_ID='KASC-67-STOCKPILE',OWNER='kasc.stockpile/v1'}
  local tr=opts.i18n.text;local aliases,frames={},setmetatable({},{__mode='k'})
  local definitions={STOCKPILE={number=254,parts={'FOCUS_ENERGY','BARRIER'}},
    SPIT_UP={number=255,parts={'EGG_BOMB'}},SWALLOW={number=256,parts={'RECOVER'}}}
  local function copy(v)
    if type(v)~='table'then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  local function pack(...)return{n=select('#',...),...}end
  local function fail()return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function live(w)
    local m=w and w.mon
    return m and type(m.hp)=='number'and m.hp>0 and not w.fainted
      and not(m.isEgg or m.is_egg or m.egg or m.eggSpecies or m.status=='EGG')
  end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function state(b,w)
    local key=w and side(b,w);local list=rows(b);local r=key and list and list[key]
    return r and w.mon and r.species==w.mon.species and r or nil
  end
  function M.epoch(b,w,move)
    local r=b and b.kascGenerationRulesReceipt
    local id=move and(aliases[move.id]or move.id)
    local marker=move and b and b.data and b.data.move_effects and b.data.move_effects[move.effect]
    if getmetatable(b)~=B or b.demo or b.kind=='link'or b.result or not r or r.mode=='off'
        or type(r.activeEpoch)~='number'or r.activeEpoch%1~=0 or r.activeEpoch<1 or r.activeEpoch>7
        or not definitions[id]or move.backendMoveOwner~=M.OWNER
        or not marker or marker.kascStockpile67~=M.OWNER then return end
    if r.activeEpoch<3 and not(live(w)and opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species]))then return end
    return math.max(3,r.activeEpoch)
  end
  function M.layers(b,w)
    local r=state(b,w);return r and r.layers or 0
  end
  function M.power(b,w,move)
    if M.epoch(b,w,move)and live(w)and side(b,w)then return 100*M.layers(b,w)end
  end
  local function append(out,messages)for _,message in ipairs(messages or{})do out[#out+1]=message end end
  function M.release(ctx)
    local b,w=ctx.battle,ctx.user;local r=state(b,w);if not r then return{}end
    rows(b)[side(b,w)]=nil
    local messages={tr('%s released its stored power!','%s gibt seine gespeicherte Kraft frei!'):format(w.name)}
    local gen=M.epoch(b,w,ctx.move)
    if gen and gen>=4 then
      local split=assert(mod.exports.backendSplitSpecial67,'Stockpile needs shared stage owner')
      -- IV-VI always remove layers, even a boost that was capped. VII
      -- remembers successful per-stat boost operations (not raw delta).
      local def,spd=gen>=7 and r.def or r.layers,gen>=7 and r.spd or r.layers
      if def>0 then append(messages,split.changeStage(ctx,w,'defense',-def,false))end
      if spd>0 then append(messages,split.changeStage(ctx,w,'specialDefense',-spd,false))end
    end
    return messages
  end
  function M.cast(ctx)
    local b,w,move=ctx.battle,ctx.user,ctx.move;local gen=M.epoch(b,w,move)
    if not gen or not live(w)or not side(b,w)then return fail()end
    local id=aliases[move.id]or move.id
    if id=='STOCKPILE'then
      local r=state(b,w)
      if r and r.layers>=3 then return fail()end
      if not r then r={species=w.mon.species,layers=0,def=0,spd=0,applied=b.turnCount or 0}
        rows(b,true)[side(b,w)]=r end
      r.layers=r.layers+1
      local messages={tr('%s stockpiled %d!','%s hortet %d!'):format(w.name,r.layers)}
      if gen>=4 then
        local split=assert(mod.exports.backendSplitSpecial67,'Stockpile needs shared stage owner')
        for _,stat in ipairs({'defense','specialDefense'})do
          local before=w.stages and w.stages[stat]or 0
          append(messages,split.changeStage(ctx,w,stat,1,false))
          if (w.stages and w.stages[stat]or 0)~=before then
            local counter=stat=='defense'and'def'or'spd';r[counter]=r[counter]+1
          end
        end
      end
      return messages
    end
    local redirect=mod.exports and mod.exports.pokemonMoveRedirection67
    local borrowed=redirect and redirect.swallowLayers(ctx)
    local count=borrowed or M.layers(b,w)
    if id~='SWALLOW'or count==0 then return fail()end
    local block=assert(mod.exports.pokemonHealBlock67,'Stockpile needs shared Heal Block owner')
    if block.moveBlocked(b,w,move,ctx.target)or block.blocksRecovery(b,w,'move')then return fail()end
    local maximum=w.mon.stats.hp
    local divisor=2^(3-count)
    -- Emerald truncates its integer division. Later source this.modify
    -- uses 12-bit nearest rounding, with exact halves rounded down.
    local amount=gen<=3 and math.max(1,math.floor(maximum/divisor))
      or math.floor((maximum*(4096/divisor)+2047)/4096)
    local messages
    if w.mon.hp>=maximum or amount<=0 then messages=fail()
    else messages=assert(mod.exports.pokemonHealingMoves67).heal(ctx,w,amount)end
    -- Full-HP failure still consumes charges. A pre-action Heal Block does
    -- not enter this branch and retains both charges and stages.
    append(messages,M.release(ctx));return messages
  end
  function M.noUseful(b,u,t,move)
    if not M.epoch(b,u,move)then return false end
    local id=aliases[move.id]or move.id
    if not live(u)or not side(b,u)then return true end
    if id=='STOCKPILE'then return M.layers(b,u)>=3 end
    if M.layers(b,u)==0 then return true end
    if id=='SWALLOW'then return u.mon.hp>=u.mon.stats.hp
      or mod.exports.pokemonHealBlock67.moveBlocked(b,u,move,t)end
    return not live(t)
  end
  function M.gate(ctx)
    if M.epoch(ctx.battle,ctx.user,ctx.move)and live(ctx.user)and live(ctx.target)
        and side(ctx.battle,ctx.user)and M.layers(ctx.battle,ctx.user)>0 then return true end
    return false,tr('But, it failed!','Doch es schlug fehl!')
  end
  function M.project(b,w,move)
    if not move or(aliases[move.id]or move.id)~='SPIT_UP'or move.kascStockpileProjected67==M.OWNER then return move end
    local power=M.power(b,w,move)
    if not power or power<=0 then return move end
    local out=copy(move);out.power=M.epoch(b,w,move)==3 and 100 or power
    out.kascStockpileProjected67=M.OWNER;return out
  end
  function M.damage(nextDamage,ctx)
    if not ctx or ctx.opts and(ctx.opts.typeless or ctx.opts.typelessDamage)then return nextDamage(ctx)end
    if ctx.move and(aliases[ctx.move.id]or ctx.move.id)=='SPIT_UP'
        and M.power(ctx.battle,ctx.user,ctx.move)==0 then
      return 0,{crit=false,typeMult=10,missed=true}
    end
    local move=M.project(ctx.battle,ctx.user,ctx.move)
    local gen=M.epoch(ctx.battle,ctx.user,move)
    if move==ctx.move and gen~=3 then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end;out.move=move
    if gen==3 and(aliases[move.id]or move.id)=='SPIT_UP'and M.layers(ctx.battle,ctx.user)>0 then
      out.opts=copy(ctx.opts or{});out.opts.kascSpitUpGen367=M.layers(ctx.battle,ctx.user)
      out.opts.forceCrit=false
    end
    return nextDamage(out)
  end
  function M.run(original,b,ctx,rec,...)
    if not ctx or(aliases[ctx.move.id]or ctx.move.id)~='SPIT_UP'
        or not M.epoch(b,ctx.user,ctx.move)or not live(ctx.user)or not side(b,ctx.user)
        or not live(ctx.target)then return original(b,ctx,rec,...)end
    local r=state(b,ctx.user)
    if not r then return original(b,ctx,rec,...)end
    local prior=frames[b];frames[b]=true
    ctx.move=M.project(b,ctx.user,ctx.move)
    local out=pack(pcall(original,b,ctx,rec,...));frames[b]=prior
    if not out[1]then error(out[2],0)end
    -- onAfterMove: a legitimate attempt spends its charges on miss,
    -- protection, immunity, or Substitute. Sleep/paralysis before the
    -- native move pipeline never enters this frame.
    if state(b,ctx.user)==r then for _,msg in ipairs(M.release(ctx))do b:sayNext(msg)end end
    return unpack(out,2,out.n)
  end
  function M.clear(ev)
    local b=ev and ev.battle;local list=rows(b);if not list then return end
    if ev.battler then local key=side(b,ev.battler);if key then list[key]=nil end
    else b.field.tokens[M.OWNER]=nil;frames[b]=nil end
  end
  function M.validateCheckpoint(b)
    if frames[b]then return false,'stockpile_move_unsettled'end
    local list=rows(b);if list==nil then return true end
    if type(list)~='table'then return false,'invalid_stockpile_container'end
    for key,r in pairs(list)do
      local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(r)~='table'or r.species~=w.mon.species
          or type(r.layers)~='number'or r.layers%1~=0 or r.layers<1 or r.layers>3
          or type(r.def)~='number'or r.def%1~=0 or r.def<0 or r.def>r.layers
          or type(r.spd)~='number'or r.spd%1~=0 or r.spd<0 or r.spd>r.layers
          or type(r.applied)~='number'or r.applied%1~=0 or r.applied<0 or r.applied>(b.turnCount or 0)then
        return false,'invalid_stockpile_record'
      end
      for field in pairs(r)do if not({species=true,layers=true,def=true,spd=true,applied=true})[field]then
        return false,'unknown_stockpile_record_field'end end
    end
    return true
  end
  for _,id in ipairs({'STOCKPILE','SPIT_UP','SWALLOW'})do
    local d=definitions[id];local f=assert(opts.facts.move(id,3));local old=assert(mod.content.moves:get(id))
    assert(f.number==d.number and f.generation==3 and f.type=='NORMAL'and f.priority==0
      and f.pp==10 and f.target==(id=='SPIT_UP'and 10 or 7)
      and f.category==(id=='SPIT_UP'and'physical'or'status'),'Stockpile source drift '..id)
    local expectedEffect=id=='SPIT_UP'and'NO_ADDITIONAL_EFFECT'or id=='SWALLOW'and'HEAL_EFFECT'
      or'KA_GEN_MOVE_STAT_'..id
    assert(not old.backendMoveOwner and old.effect==expectedEffect,'foreign Stockpile owner '..id)
    local effect='KA_STOCKPILE_67_'..id
    mod.content.move_effects:register(effect,{kind=id=='SPIT_UP'and'full'or'primary',
      accuracyChecked=false,kascStockpile67=M.OWNER,run=id~='SPIT_UP'and M.cast or nil,
      gate=id=='SPIT_UP'and M.gate or nil})
    for _,alias in ipairs(opts.species.moveIds(id))do if mod.content.moves:get(alias)then
      aliases[alias]=id
      mod.content.moves:patch(alias,{effect=effect,backendMoveOwner=M.OWNER,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,
        pp=f.pp,originGeneration=3,backendMoveNumber=d.number,
        power=id=='SPIT_UP'and 1 or 0,target=id=='SPIT_UP'and 10 or 7,contact=false,
        anim=copy(assert(mod.content.moves:get(d.parts[1])).anim)})
    end end
    aliases[id]=id
    local animation={seq={},source=M.OWNER}
    for _,part in ipairs(d.parts)do for _,step in ipairs(assert(mod.content.battle_anims:get(part)).seq)do
      animation.seq[#animation.seq+1]=copy(step)end end
    if mod.content.battle_anims:get(id)then mod.content.battle_anims:patch(id,animation)
    else mod.content.battle_anims:register(id,animation)end
    if opts.catalog then for i=#opts.catalog.unsupportedStatus,1,-1 do
      if opts.catalog.unsupportedStatus[i]==id then table.remove(opts.catalog.unsupportedStatus,i)end
    end end
  end
  function M.position(player,id)
    local row=player.data and player.data.moveAnims and player.data.moveAnims[id]
    if not definitions[id]or not row or row.source~=M.OWNER then return end
    local hud={{0,0,88,30},{72,56,160,94},{0,98,160,144}}
    for _,step in ipairs(player.steps or{})do local sprites={};local shift=-16
      for _,s in ipairs(step.sprites or{})do if s.x>0 and s.x<168 and s.y>0 and s.y<160 then shift=math.max(shift,16-s.y)end end
      for i,s in ipairs(step.sprites or{})do local q=copy(s)
        if q.x>0 and q.x<168 and q.y>0 and q.y<160 then q.y=q.y+shift end
        local x,y=q.x-8,q.y-16
        for _,box in ipairs(hud)do if x<box[3]and x+8>box[1]and y<box[4]and y+8>box[2]then q.x=0;break end end
        sprites[i]=q
      end;step.sprites=sprites
    end
  end
  function M.install()
    FX._kascStockpile67=M;Player._kascStockpile67=M
    if not FX._kascStockpileWrapped67 then local run=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascStockpile67.run(run,...)end;FX._kascStockpileWrapped67=true end
    if not Player._kascStockpileWrapped67 then local start=Player.start
      Player.start=function(self,id,...)local out=pack(start(self,id,...));Player._kascStockpile67.position(self,id);return unpack(out,1,out.n)end
      Player._kascStockpileWrapped67=true
    end
  end
  M.install();mod.hooks:wrap('battle.damage',M.damage,31525)
  -- Native Gen I has no later critical/math owner. Only a validated owned
  -- gift Entfessler reaches this isolated copy of its unchanged native math.
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if ctx.opts and ctx.opts.kascSpitUpGen367 and M.epoch(ctx.battle,ctx.user,ctx.move)==3
        and ctx.battle.kascGenerationRulesReceipt.activeEpoch==1 then
      return assert(opts.damage,'Stockpile requires native math seam').compute(
        ctx.ruleset,ctx.user,ctx.target,ctx.move,ctx.opts)
    end
    return nextDamage(ctx)
  end,-9500)
  -- Baton Pass deliberately copies only stages before this event; this
  -- volatile is noCopy in every era. Do not subtract from recipient stages.
  mod.events:on('battle.battler_switched',M.clear,8000)
  mod.events:on('battle.ended',M.clear,80)
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({
    segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
    active=true,dependencyStatus='native-damage-healing-stages-and-baton-noCopy',providerStatus='three-era-correct-stockpile-moves',
    buildReceiptId='docs/STOCKPILE_67.md',rollbackReceiptId='docs/STOCKPILE_67.md'})end
  return M
end
