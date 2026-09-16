-- Krafttrick changes raw battle stats, not boosts, saved stats or art.
return function(mod,opts)
  local B=require('src.battle.BattleState');local Stats=require('src.pokemon.Stats')
  local M={CARD_ID='KASC-67-POWER-TRICK',OWNER='kasc.power-trick/v1',ID='POWER_TRICK'}
  local effect='KA_POWER_TRICK_67';local tr=opts.i18n.text
  local passes=setmetatable({},{__mode='k'})
  local function copy(t)local out={};for k,v in pairs(t or{})do out[k]=v end;return out end
  local function integer(v,a,z)return type(v)=='number'and v%1==0 and v>=a and v<=z end
  local function side(b,w)return w==b.player and'player'or w==b.enemy and'enemy'or nil end
  local function live(w)
    local p=w and w.mon
    return p and integer(p.hp,1,99999)and not w.fainted
      and not(p.isEgg or p.egg or p.is_egg or p.eggSpecies or p.species=='EGG')
  end
  local function rows(b,create)
    if create then b.field=b.field or{};b.field.tokens=b.field.tokens or{}
      b.field.tokens[M.OWNER]=b.field.tokens[M.OWNER]or{}end
    return b and b.field and b.field.tokens and b.field.tokens[M.OWNER]
  end
  local function partyIndex(b,w,lane)
    lane=lane or side(b,w);if not lane then return end
    local party=lane=='player'and b:playerPartyView()or b.enemyParty or{b.enemy and b.enemy.mon}
    for i,p in ipairs(party or{})do if i<=6 and p==w.mon then return i end end
  end
  function M.epoch(b)
    local r=b and b.kascGenerationRulesReceipt
    local e=b and b.data and b.data.move_effects and b.data.move_effects[effect]
    if getmetatable(b)==B and not b.demo and b.kind~='link'and not b.result and r
        and r.mode~='off'and integer(r.activeEpoch,1,7)and e and e.kascPowerTrick67==M.OWNER then return r.activeEpoch end
  end
  function M.record(b,w)
    local r=rows(b);local key=side(b,w);local row=key and r and r[key]
    local epoch=M.epoch(b)
    return epoch and live(w)and row and row.species==w.mon.species
      and row.party==partyIndex(b,w,key)and row.epoch==epoch and row or nil
  end
  function M.profile(b,w,move)
    local epoch=M.epoch(b)
    if not epoch or not live(w)or not side(b,w)or not partyIndex(b,w)
        or not move or move.id~=M.ID or move.backendMoveOwner~=M.OWNER or move.effect~=effect then return end
    if epoch<4 and not(opts.rules.ownedGiftBattleCompatible
        and opts.rules.ownedGiftBattleCompatible(b.game,w.mon,b.data.pokemon[w.mon.species]))then return end
    return epoch
  end
  function M.plan(b,w,move)
    if not M.profile(b,w,move)or not w.curStats or not integer(w.curStats.attack,1,9999)
        or not integer(w.curStats.defense,1,9999)or passes[b]then return end
    return{attack=w.curStats.defense,defense=w.curStats.attack,remove=M.record(b,w)~=nil,
      changed=w.curStats.attack~=w.curStats.defense}
  end
  local function swap(w)
    if not w.curStats or not integer(w.curStats.attack,1,9999)or not integer(w.curStats.defense,1,9999)then return false end
    local stats=copy(w.curStats);stats.attack,stats.defense=stats.defense,stats.attack
    w.curStats=stats;return true
  end
  function M.cast(ctx)
    local b,w=ctx.battle,ctx.user;local p=M.plan(b,w,ctx.move)
    if not p then return{tr('But, it failed!','Doch es schlug fehl!'),failed=true}end
    assert(swap(w));local key=side(b,w);local r=rows(b,true)
    if p.remove then r[key]=nil else r[key]={species=w.mon.species,party=partyIndex(b,w),
      epoch=M.epoch(b),applied=b.turnCount or 0}end
    -- Equal raw stats still start/end the real passable volatile. No stat
    -- event: Contrary, Simple, Defiant and stages are not involved.
    return{tr(p.remove and'%s ended Power Trick!'or'%s switched Attack and Defense!',
      p.remove and'%s beendet Krafttrick!'or'%s tauscht Angriff und Verteidigung!'):format(w.name)}
  end
  function M.noUseful(b,w,t,move)
    if not M.profile(b,w,move)then return false end
    local p=M.plan(b,w,move);if not p or not p.changed then return true end
    local physical=false
    for _,slot in ipairs(w.curMoves or{})do local m=b:moveDef(slot)
      if m and(slot.pp or 0)>0 and m.category~='status'and(m.power or 0)>0 then
        local category=m.category
        if M.epoch(b)<=3 then local typ=b.data.type_chart.types[m.type];category=typ and typ.category or category end
        if category=='physical'then physical=true;break end
      end
    end
    return physical and p.attack<=w.curStats.attack or not physical and p.defense<=w.curStats.defense
  end
  function M.transfer(b,old,fresh)
    local key=side(b,fresh);local r=rows(b);local row=key and r and r[key]
    if not M.epoch(b)or not key or b[key]~=fresh or not live(old)or not live(fresh)
        or old.isPlayer~=fresh.isPlayer or not row or row.species~=old.mon.species
        or row.party~=partyIndex(b,old,key)or row.epoch~=M.epoch(b)or not partyIndex(b,fresh)then return false end
    passes[b]={previous=old,battler=fresh,key=key};return true
  end
  function M.switched(ev)
    local b,w=ev and ev.battle,ev and ev.battler;local r=rows(b);local key=b and w and side(b,w)
    local f=b and passes[b];if not r or not key then if b then passes[b]=nil end;return end
    if M.epoch(b)and f and f.previous==ev.previous and f.battler==w and f.key==key
        and ev.sourceCard=='KASC-67-BATON-PASS'and live(w)and swap(w)then
      r[key]={species=w.mon.species,party=partyIndex(b,w),epoch=M.epoch(b),applied=b.turnCount or 0}
    else r[key]=nil end
    passes[b]=nil
  end
  -- Actual forme changes overwrite raw stats while the volatile persists.
  -- The existing Mega owner uses authored gains atop raw current stats,
  -- so its private applyNow must call this before calculating those gains.
  function M.beforeMega(b,w)
    if not M.record(b,w)or not w.curStats or opts.identity and opts.identity.transformed(w)then return false end
    local key=opts.species.bySpecies[w.mon.species]
    local gen=M.epoch(b);local base=key and opts.facts.baseStats(key,gen)
    local genetics=mod.exports.daycare and mod.exports.daycare.breedingIVs
    local stats=base and genetics and genetics.stats(b.game,w.mon,gen,base)
    if not stats then
      local def=base and{baseStats={hp=base.hp,attack=base.atk,defense=base.def,speed=base.spe,special=base.spa}}
        or assert(b.data.pokemon[w.mon.species])
      stats=Stats.calc(def,w.mon.level,w.mon.dvs,w.mon.statExp)
    end
    if not integer(stats.attack,1,9999)or not integer(stats.defense,1,9999)then return false end
    local out=copy(w.curStats);out.attack,out.defense=stats.attack,stats.defense;w.curStats=out
    return true
  end
  function M.validateCheckpoint(b)
    if passes[b]then return false,'power_trick_pass_unsettled'end
    local r=rows(b);if r==nil then return true end
    if type(r)~='table'then return false,'invalid_power_trick_container'end
    for key,row in pairs(r)do local w=(key=='player'or key=='enemy')and b[key]
      if not w or type(row)~='table'or not M.record(b,w)or not integer(row.applied,0,b.turnCount or 0)
          or not w.curStats or not integer(w.curStats.attack,1,9999)or not integer(w.curStats.defense,1,9999)
          or w.curStats==w.mon.stats then return false,'invalid_power_trick_record'end
      for field in pairs(row)do if field~='species'and field~='party'and field~='epoch'and field~='applied'then return false,'unknown_power_trick_field'end end
    end
    return true
  end
  function M.move(original,b,inst,...)
    local move=original(b,inst,...)
    if not M.epoch(b)or not move or move.id~=M.ID or move.backendMoveOwner~=M.OWNER then return move end
    local out=copy(move);out.flags=copy(move.flags);out.flags.snatch=M.epoch(b)>=5 and 1 or nil
    return out
  end
  function M.install()
    B._kascPowerTrick67=M
    if not B._kascPowerTrickWrapped67 then local move=B.moveDef
      B.moveDef=function(...)return B._kascPowerTrick67.move(move,...)end
      B._kascPowerTrickWrapped67=true end
  end
  local f=assert(opts.facts.move(M.ID,4));local old=assert(mod.content.moves:get(M.ID))
  assert(f.number==379 and f.generation==4 and f.category=='status'and f.power==0 and f.pp==10
    and f.alwaysHits and f.target==7 and f.priority==0 and f.type=='PSYCHIC_TYPE','Power Trick source drift')
  assert(not old.backendMoveOwner and old.effect=='KA_GEN_MOVE_UNSUPPORTED_'..M.ID,'foreign Power Trick owner')
  mod.content.move_effects:register(effect,{kind='primary',accuracyChecked=false,kascPowerTrick67=M.OWNER,run=M.cast})
  mod.content.moves:patch(M.ID,{effect=effect,backendMoveOwner=M.OWNER,backendMoveNumber=379,
    backendLearnsetRevision=old.backendLearnsetRevision or 1,power=0,accuracy=100,pp=10,
    category='status',target=7,priority=0,flags={snatch=1}})
  -- Existing proper animation only; no Pokémon/image/asset edits.
  assert(mod.content.battle_anims:get(M.ID),'missing existing Power Trick animation')
  for i=#opts.catalog.unsupportedStatus,1,-1 do if opts.catalog.unsupportedStatus[i]==M.ID then table.remove(opts.catalog.unsupportedStatus,i)end end
  mod.events:on('battle.battler_switched',M.switched,9700)
  mod.events:on('battle.fainted',function(ev)
    local b,w=ev.battle,ev.battler;local r=rows(b);local key=w and side(b,w)
    if getmetatable(b)==B and w and w.mon and w.mon.hp==0 and w.faintQueued==true then
      if r and key then r[key]=nil end;passes[b]=nil
    end
  end,9700)
  mod.events:on('battle.ended',function(ev)local r=rows(ev.battle);if r then ev.battle.field.tokens[M.OWNER]=nil end;passes[ev.battle]=nil end,9700)
  M.install()
  if opts.supportLog and opts.supportLog.registerSegment then opts.supportLog.registerSegment({segmentId=M.CARD_ID,
    cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
    dependencyStatus='native-raw-stats-and-prepare-before-entry-baton-pass',providerStatus='power-trick-raw-stat-toggle-passable-volatile',
    buildReceiptId='docs/POWER_TRICK_67.md',rollbackReceiptId='docs/POWER_TRICK_67.md'})end
  return M
end
