-- Per-attack type callbacks, not a replacement world/type chart.
return function(mod,opts)
  local B=require('src.battle.BattleState');local FX=require('src.battle.EffectRegistry')
  local Chart=require('src.battle.TypeChart')
  local M={CARD_ID='KASC-67-SPECIAL-EFFECTIVENESS',OWNER='kasc.special-effectiveness/v1'}
  local defs={FLYING_PRESS={number=560,type='FIGHTING',category='physical',pp=10,accuracy=95},
    FREEZE_DRY={number=573,type='ICE',category='special',pp=20,accuracy=100}}
  local aliases={};for id in pairs(defs)do for _,key in ipairs(opts.species.moveIds(id))do aliases[key]=id end end
  local frames={}
  local function copy(v)if type(v)~='table'then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end
  local function pack(...)return{n=select('#',...),...}end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function live(w)local p=w and w.mon;return p and integer(p.hp,1,99999)and not w.fainted
    and not(p.egg or p.isEgg or p.is_egg or p.eggSpecies or p.species=='EGG')end
  local function active(b,w)
    if not w or not w.mon then return end
    for _,key in ipairs({'player','enemy'})do local a=b[key]
      if a and a.mon==w.mon then
        local party=key=='player'and b:playerPartyView()or b.enemyParty or{b.enemy.mon}
        for i,p in ipairs(party)do if i<=6 and p==a.mon then return a end end
      end
    end
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt;local h=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    return getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result
      and r and r.mode~='off'and integer(r.activeEpoch,1,7)and h and h.kascSpecialEffectiveness67==M.OWNER
      and r.activeEpoch or nil
  end
  function M.profile(b,u,t,m)
    local gen=M.epoch(b);local id=m and aliases[m.id];local d=id and defs[id]
    local effect=d and b.data.move_effects[m.effect]
    if not gen or not d or not live(u)or not live(t)or u.mon==t.mon or not active(b,u)or not active(b,t)
        or m.backendMoveOwner~=M.OWNER or m.backendMoveNumber~=d.number
        or not effect or effect.kascSpecialEffectiveness67~=M.OWNER then return end
    if gen<6 and not(opts.rules.ownedGiftBattleCompatible(b.game,u.mon,b.data.pokemon[u.mon.species])
        and opts.rules.monMoveAvailable(b.game,u.mon,m.id,gen,true))then return end
    return math.max(6,gen),id
  end
  local function primary(b,kind,defender)
    -- Read the actually installed chart. No mutation/reload/cache replacement;
    -- use the same last matching row as the native effectiveness index.
    local out=10
    for _,row in ipairs(b.data.type_chart.matchups)do
      if row.attacker==kind and row.defender==defender then out=row.multiplier end
    end;return out
  end
  local function stream(b)
    local weather=mod.exports.pokemonPrimalWeather67
    return weather and weather.current and weather.current(b)=='stream'
  end
  function M.multiplier(b,u,t,m,types)
    local gen,id=M.profile(b,u,t,m);if not gen or type(types)~='table'then return end
    local product=10;local seen={}
    for _,kind in ipairs(types)do if not seen[kind]then
      seen[kind]=true
      local factor=id=='FREEZE_DRY'and kind=='WATER'and 20 or primary(b,m.type,kind)
      if id=='FLYING_PRESS'then factor=factor*primary(b,'FLYING',kind)/10 end
      -- The weather callback runs after the move callback and neutralizes
      -- only a positive net Flying component, not another type's weakness.
      if kind=='FLYING'and factor>10 and stream(b)then factor=10 end
      product=product*factor/10
    end end
    return product
  end
  function M.scope(b,u,t,m,fn)
    local gen=M.profile(b,u,t,m)
    -- A foreign nested calculation must suspend an enclosing attack scope.
    frames[#frames+1]=gen and{battle=b,user=u,target=t,move=m}or false
    local out=pack(pcall(fn));frames[#frames]=nil
    if not out[1]then error(out[2],0)end;return unpack(out,2,out.n)
  end
  function M.chart(kind,types)
    local f=frames[#frames]
    if f and kind==f.move.type then return M.multiplier(f.battle,f.user,f.target,f.move,types)end
  end
  function M.inScope(b,m)
    local f=frames[#frames];return f and f.battle==b and f.move==m or false
  end
  function M.project(b,w,m)
    local gen=M.epoch(b);local id=m and aliases[m.id];local d=id and defs[id]
    if not gen or not d or m.backendMoveOwner~=M.OWNER or not active(b,w)then return m end
    if gen<6 and not(opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species])
        and opts.rules.monMoveAvailable(b.game,w.mon,m.id,gen,true))then return m end
    local out=copy(m);out.power=id=='FLYING_PRESS'and(gen>=7 and 100 or 80)or 70
    out.category=d.category
    -- Keep an already-resolved ability/item type. The move's callback is
    -- still Flying addition / Water override after Normalize/Ion Deluge.
    return out
  end
  function M.move(original,b,inst,...)
    local m=original(b,inst,...);if not m or not aliases[m.id]then return m end
    for _,w in ipairs({b.player,b.enemy})do for _,slot in ipairs(w and w.curMoves or{})do
      if slot==inst then return M.project(b,w,m)end
    end end;return m
  end
  function M.prepare(nextDamage,ctx)
    if not ctx or not aliases[ctx.move and ctx.move.id]then return nextDamage(ctx)end
    local out={};for k,v in pairs(ctx)do out[k]=v end
    out.move=M.project(ctx.battle,ctx.user,ctx.move)
    local parent=mod.exports.pokemonParentalBond67
    if parent then parent.projected(ctx.battle,ctx.user,ctx.target,ctx.move,out.move)end
    return nextDamage(out)
  end
  function M.damage(nextDamage,ctx)
    if not ctx then return nextDamage(ctx)end
    return M.scope(ctx.battle,ctx.user,ctx.target,ctx.move,function()return nextDamage(ctx)end)
  end
  function M.run(original,b,ctx,record)
    return M.scope(b,ctx.user,ctx.target,ctx.move,function()return original(b,ctx,record)end)
  end
  function M.validateCheckpoint(b)
    for _,f in ipairs(frames)do if f and f.battle==b then return false,'special_effectiveness_in_flight'end end
    return true
  end
  function M.install()
    Chart._kascSpecialEffectiveness67=M;FX._kascSpecialEffectiveness67=M;B._kascSpecialEffectiveness67=M
    if not Chart._kascSpecialEffectivenessWrapped67 then local rows,effectiveness=Chart.rows,Chart.effectiveness
      Chart.rows=function(kind,types,...)
        local mult=Chart._kascSpecialEffectiveness67.chart(kind,types)
        if mult~=nil then return mult==10 and{}or{mult}end
        return rows(kind,types,...)
      end
      Chart.effectiveness=function(kind,types,...)
        local mult=Chart._kascSpecialEffectiveness67.chart(kind,types)
        if mult~=nil then return mult end
        return effectiveness(kind,types,...)
      end;Chart._kascSpecialEffectivenessWrapped67=true
    end
    if not FX._kascSpecialEffectivenessWrapped67 then local original=FX.runDamaging
      FX.runDamaging=function(...)return FX._kascSpecialEffectiveness67.run(original,...)end
      FX._kascSpecialEffectivenessWrapped67=true
    end
    if not B._kascSpecialEffectivenessWrapped67 then local original=B.moveDef
      B.moveDef=function(...)return B._kascSpecialEffectiveness67.move(original,...)end
      B._kascSpecialEffectivenessWrapped67=true
    end
  end
  for id,d in pairs(defs)do local fact=assert(opts.facts.move(id,7))
    assert(fact.number==d.number and fact.generation==6 and fact.pp==d.pp and fact.accuracy==d.accuracy
      and fact.type==d.type and fact.category==d.category,'special effectiveness source drift '..id)
    for _,key in ipairs(opts.species.moveIds(id))do local old=assert(mod.content.moves:get(key))
      assert(not old.backendMoveOwner,'foreign special effectiveness owner '..key)
      local effect='KA_SPECIAL_EFFECTIVENESS_67_'..key
      local row=copy(assert(mod.content.move_effects:get(old.effect)))
      row.kascSpecialEffectiveness67=M.OWNER;mod.content.move_effects:register(effect,row)
      mod.content.moves:patch(key,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=d.number,
        backendLearnsetRevision=old.backendLearnsetRevision or 1,pp=d.pp,
        flags=copy(assert(opts.facts.data.moves[id]).flags)})
      assert(mod.content.battle_anims:get(key),'existing special effectiveness animation missing '..key)
    end
  end
  assert(opts.facts.move('FLYING_PRESS',6).power==80 and opts.facts.move('FLYING_PRESS',7).power==100)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascSpecialEffectiveness67=M.OWNER})
  mod.hooks:wrap('battle.damage',M.prepare,49000)
  mod.hooks:wrap('battle.damage',M.damage,30000)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-damage-and-scoped-type-callbacks',providerStatus='flying-press-and-freeze-dry',
    buildReceiptId='docs/SPECIAL_EFFECTIVENESS_67.md',rollbackReceiptId='docs/SPECIAL_EFFECTIVENESS_67.md'})end
  return M
end
