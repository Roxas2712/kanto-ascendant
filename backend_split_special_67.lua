-- Separate battle-only Special stats on the Gen-I host. No save conversion.
return function(mod,opts)
  local facts,species,rules=assert(opts.facts),assert(opts.species),assert(opts.rules)
  local M={CARD_ID='KASC-67-SPLIT-SPECIAL',OWNER='kasc.split-special/v1'}
  local function copy(t)local r={};for k,v in pairs(t or {})do r[k]=v end;return r end
  local function tr(en,de)return opts.i18n and opts.i18n.text(en,de) or en end
  local function secondaryChance(ctx,chance,selfTarget)
    local ability=opts.abilities and opts.abilities()
    return ability and ability.secondaryChance and ability.secondaryChance(ctx,chance,selfTarget) or chance
  end
  local owners={}
  for id in pairs(facts.data.moves)do
    for _,native in ipairs(species.moveIds(id))do owners[native]=id end
  end
  function M.epoch(b)
    if not b or b.demo or b.kind=='link' then return nil end
    local game=b.game
    -- Marker is on the actual native effect owner, removed by mod unload.
    local marker=game and game.data and game.data.move_effects and game.data.move_effects.SPECIAL_UP2_EFFECT
    if not marker or marker.kascSplitSpecial67~=M.OWNER then return nil end
    local resolved=b.kascGenerationRulesReceipt
    if not resolved then
      local bucket=game.save and game.save.modData and game.save.modData[mod.id]
      local state=bucket and bucket[rules.SAVE_KEY]
      if state then resolved={mode=state.activeMode,activeEpoch=state.activeEpoch}end
    end
    if not resolved or resolved.mode=='off' or (tonumber(resolved.activeEpoch) or 1)<2 then return nil end
    return resolved.activeEpoch
  end
  local function calc(base,mon)
    -- Preserve cartridge DV/stat-exp training; do not invent IVs, EVs or
    -- natures in an existing Gen-I save. Gen2 uses the same Special DV/exp.
    local dv=mon.dvs and mon.dvs.special or 0
    local exp=mon.statExp and mon.statExp.special or 0
    local ev=math.floor(math.min(255,math.ceil(math.sqrt(math.max(0,exp))))/4)
    return math.floor(((base+dv)*2+ev)*(mon.level or 1)/100)+5
  end
  function M.prepare(b,who)
    local epoch=M.epoch(b)
    if not epoch or not who or not who.mon or not who.curStats then return false end
    if who.curStats.specialAttack and who.curStats.specialDefense then return true end
    local profile=who._ascMegaProfile
    local id=profile and profile.species or who.mon.species
    local key=species.bySpecies[id]
    if not key then
      -- Custom owners (notably Gorochu) have no canonical source identity.
      -- Retain their authored Special value on both sides, while allowing
      -- the same independent stages; never substitute a catalog Pokemon.
      if type(who.curStats.special)~='number' then return false end
      local stats=copy(who.curStats)
      stats.specialAttack=stats.special;stats.specialDefense=stats.special
      who.curStats=stats
      return true
    end
    local base=facts.baseStats(key,epoch);if not base then return false end
    local stats=copy(who.curStats)
    stats.specialAttack=calc(base.spa,who.mon)
    stats.specialDefense=calc(base.spd,who.mon)
    if profile then
      local gain=profile.bonuses and profile.bonuses.special or 0
      local level=who.mon.level or 1
      stats.specialAttack=math.min(999,stats.specialAttack+math.floor(2*gain*level/100))
      stats.specialDefense=math.min(999,stats.specialDefense+
        math.floor(2*(profile.specialDefenseBonus or gain)*level/100))
    end
    who.curStats=stats -- native makeBattler aliases mon.stats; never mutate it
    return true
  end
  function M.entry(ev)
    local b=ev and ev.battle;if not b then return end
    local genetics=mod.exports.daycare and mod.exports.daycare.breedingIVs
    local receipt=b.kascGenerationRulesReceipt
    local epoch=receipt and(receipt.mode=='off'and 1 or receipt.activeEpoch)
    local function bind(who)
      if not who or not who.mon then return end
      local identity=mod.exports.pokemonBattleIdentity67
      if who._ascMegaProfile or identity and identity.transformed(who)then return end
      if genetics and genetics.apply(b.game,who.mon,epoch)then
        who.curStats=copy(who.mon.stats)
        who.shownHP=math.max(0,math.min(who.shownHP or who.mon.hp,who.mon.stats.hp))
      end
    end
    if ev.battler then bind(ev.battler)else bind(b.player);bind(b.enemy)end
    if ev.battler then M.prepare(b,ev.battler)
    else M.prepare(b,b.player);M.prepare(b,b.enemy)end
  end
  -- Read-only status projection. A live battle's frozen profile and active
  -- form take precedence; reserves/outside battle use the same calculator.
  -- Never resolve/migrate a save or write derived values into mon.stats.
  function M.preview(game,mon)
    if not game or not mon or mon.isEgg or mon.egg or mon.is_egg or mon.eggSpecies
        or mon.species=='EGG'or mon.species=='POKEMON_EGG'or mon.status=='EGG'then return nil end
    local battle,active
    local B=require('src.battle.BattleState')
    local states=game.stack and game.stack.states or{}
    for i=#states,1,-1 do
      local candidate=states[i]
      if getmetatable(candidate)==B and candidate.game==game and not candidate.result then
        battle=candidate
        for _,w in ipairs({candidate.player,candidate.enemy})do
          if w and w.mon==mon then active=w;break end
        end
        break
      end
    end
    if not battle then
      local receipt=rules.peek(game)
      battle={game=game,kascGenerationRulesReceipt=receipt}
    end
    local epoch=M.epoch(battle);if not epoch or epoch>7 then return nil end
    local source=active and active.curStats or mon.stats
    if not source then
      local def=game.data and game.data.pokemon[mon.species];if not def then return nil end
      local projected=copy(mon);projected.dvs=copy(mon.dvs);projected.statExp=copy(mon.statExp)
      require('src.pokemon.Stats').ensure(def,projected);source=projected.stats
    end
    local stats=copy(source)
    if not active then
      local genetics=mod.exports.daycare and mod.exports.daycare.breedingIVs
      local projected=genetics and genetics.stats(game,mon,epoch,genetics.base(game,mon,epoch))
      if projected then stats=projected end
    end
    local who={mon=mon,curStats=stats,_ascMegaProfile=active and active._ascMegaProfile}
    if not M.prepare(battle,who)then return nil end
    return who.curStats,epoch
  end
  function M.damage(nextDamage,ctx)
    if not ctx or not M.epoch(ctx.battle) then return nextDamage(ctx)end
    M.prepare(ctx.battle,ctx.user);M.prepare(ctx.battle,ctx.target)
    local function side(who,key)
      if not who or not who.curStats or not who.curStats[key] then return who end
      local view=copy(who);view.curStats=copy(who.curStats);view.stages=copy(who.stages)
      view.curStats.special=who.curStats[key]
      view.stages.special=who.stages and who.stages[key] or 0
      return view
    end
    local adjusted=copy(ctx)
    adjusted.user=side(ctx.user,'specialAttack')
    adjusted.target=side(ctx.target,'specialDefense')
    return nextDamage(adjusted)
  end
  local statNames={[1]='hp',[2]='attack',[3]='defense',[4]='specialAttack',
    [5]='specialDefense',[6]='speed',[7]='accuracy',[8]='evasion'}
  function M.changes(ctx,row)
    local epoch=M.epoch(ctx.battle);if not epoch then return nil end
    local source=facts.data.moves[owners[row.id] or row.id]
    if not source then return nil end
    local out={}
    for _,change in ipairs(facts.statChanges(source.id,epoch) or {})do
      out[#out+1]={stat=assert(statNames[change[1]]),change=change[2]}
    end
    return out
  end
  function M.changeStage(ctx,who,stat,delta,fromEnemy)
    if fromEnemy and ctx.brokeSub and M.epoch(ctx.battle) then return {}end
    local abilities=opts.abilities and opts.abilities()
    local blocked=abilities and abilities.blockStatDrop
      and abilities.blockStatDrop(ctx.battle,who,stat,delta,fromEnemy)
    if blocked then return blocked end
    if (stat~='specialAttack' and stat~='specialDefense') or not M.epoch(ctx.battle) then
      return ctx.changeStage(who,stat,delta,fromEnemy)
    end
    delta=abilities and abilities.stageDelta and abilities.stageDelta(ctx.battle,who,delta)or delta
    if fromEnemy and (who.substituteHP or who.mist and delta<0 or ctx.brokeSub) then
      return {tr('But, it failed!','Es ist fehlgeschlagen!')}
    end
    who.stages=who.stages or {}
    local old=who.stages[stat] or 0
    local value=math.max(-6,math.min(6,old+delta))
    if value==old then return {tr('Nothing happened!','Nichts geschieht!')}end
    who.stages[stat]=value;who.hazeStatReset=nil
    local label=stat=='specialAttack' and tr('SP. ATK','SP.-ANG.') or tr('SP. DEF','SP.-VERT.')
    local messages={tr("%s's %s\n%s!",'%ss %s\n%s!'):format(who.name or who.mon.species,label,
      delta>0 and tr('rose','steigt') or tr('fell','sinkt'))}
    if abilities and abilities.afterStage then
      for _,m in ipairs(abilities.afterStage(ctx.battle,who,stat,old,fromEnemy))do messages[#messages+1]=m end
    end
    return messages
  end
  -- These earlier KASC definitions predate the full move catalog and were
  -- preserved as plain damage (Mud-Slap even carried a primary-only effect).
  -- Give the named, source-verified secondary effects their own records;
  -- never patch the shared NO_ADDITIONAL_EFFECT for unrelated attacks.
  M.secondaryRepairs={}
  for _,sourceId in ipairs({'CRUNCH','METAL_CLAW','IRON_TAIL','SHADOW_BALL',
      'MUD_SLAP','ANCIENT_POWER'})do
    local source=assert(facts.data.moves[sourceId])
    for _,native in ipairs(species.moveIds(sourceId))do
      local move=mod.content.moves:get(native)
      local original=assert(mod.content.move_effects:get(move.effect))
      local record=copy(original)
      record.kind='secondary'
      record.run=function(ctx)
        if not M.epoch(ctx.battle) then
          -- A primary-only old record was never dispatched after damage.
          return original.kind~='primary' and original.run and original.run(ctx) or {}
        end
        local selfTarget=source.meta.meta_category_id==7
        local who=selfTarget and ctx.user or ctx.target
        if not selfTarget and (who.substituteHP or ctx.brokeSub) then return {}end
        if ctx.rng(1,100)>secondaryChance(ctx,source.meta.stat_chance,selfTarget) then return {}end
        local messages={}
        for _,change in ipairs(M.changes(ctx,{id=sourceId}))do
          for _,message in ipairs(M.changeStage(ctx,who,change.stat,change.change,
              not selfTarget and change.change<0))do messages[#messages+1]=message end
        end
        return messages
      end
      local id='KA_STAT_SECONDARY_67_'..native
      mod.content.move_effects:register(id,record)
      mod.content.moves:patch(native,{effect=id})
      M.secondaryRepairs[#M.secondaryRepairs+1]=native
    end
  end
  -- Native Gen-I effect closures capture a local changeStage,
  -- so patch their records, not a global function that they never call.
  for _,id in ipairs({'SPECIAL_UP1_EFFECT','SPECIAL_UP2_EFFECT','SPECIAL_DOWN_SIDE_EFFECT',
      'ATTACK_UP1_EFFECT','ATTACK_UP2_EFFECT','DEFENSE_UP1_EFFECT','DEFENSE_UP2_EFFECT',
      'SPEED_UP2_EFFECT','EVASION_UP1_EFFECT',
      'DEFENSE_DOWN_SIDE_EFFECT','ATTACK_DOWN_SIDE_EFFECT','SPEED_DOWN_SIDE_EFFECT',
      'ATTACK_DOWN1_EFFECT','DEFENSE_DOWN1_EFFECT','DEFENSE_DOWN2_EFFECT',
      'SPEED_DOWN1_EFFECT','ACCURACY_DOWN1_EFFECT'})do
    local original=assert(mod.content.move_effects:get(id)).run
    mod.content.move_effects:patch(id,{kascSplitSpecial67=M.OWNER,run=function(ctx)
      if not M.epoch(ctx.battle) then return original(ctx)end
      local source=facts.data.moves[owners[ctx.move.id] or ctx.move.id]
      if not source or #source.statChanges==0 then return original(ctx)end
      local secondary=id:find('_DOWN_SIDE_EFFECT',1,true)~=nil
      local primaryDrop=id:find('_DOWN1_EFFECT',1,true)~=nil or id=='DEFENSE_DOWN2_EFFECT'
      local chance=source.meta and source.meta.stat_chance or 0
      if secondary and ctx.rng(1,100)>secondaryChance(ctx,chance) then return {}end
      local who=(secondary or primaryDrop) and ctx.target or ctx.user
      local messages={}
      for _,change in ipairs(M.changes(ctx,ctx.move))do
        local result=M.changeStage(ctx,who,change.stat,change.change,
          (secondary or primaryDrop) and change.change<0)
        if result.failed then messages.failed=true end
        for _,message in ipairs(result)do messages[#messages+1]=message end
      end
      return messages
    end})
  end
  -- The imported host hard-codes the Gen-I enemy 25% failure BEFORE a
  -- primary record's run callback. Own this narrow stage via perform so
  -- modern profiles do not retain that extra failure roll. Native/off/link
  -- callers keep it, along with accuracy, phase and animation semantics.
  local function failed(messages)
    if not messages or #messages==0 or messages.failed then return true end
    local text=require('src.render.TextBox').strip(messages[1]):gsub('%s+$','')
    return text=='But, it failed!' or text=='Nothing happened!'
      or text:find("didn't affect",1,true) or text:find('is unaffected',1,true)
      or text:find('protected by MIST',1,true) or text:lower():find('already asleep',1,true)
  end
  for _,id in ipairs({'ATTACK_DOWN1_EFFECT','DEFENSE_DOWN1_EFFECT','DEFENSE_DOWN2_EFFECT',
      'SPEED_DOWN1_EFFECT','ACCURACY_DOWN1_EFFECT'})do
    local record=assert(mod.content.move_effects:get(id))
    local run=assert(record.run)
    mod.content.move_effects:patch(id,{perform=function(ctx)
      local b=ctx.battle
      local function miss()
        b:cancelMoveAnim()
        b:sayNext(b:romText('_AttackMissedText',"%s's\nattack missed!",ctx.displayName(ctx.user)))
      end
      if not M.epoch(b) and not ctx.user.isPlayer and b.kind~='link' and ctx.rng(0,255)<64 then
        miss();return
      end
      if record.accuracyChecked and (ctx.target.invulnerable or not ctx.accuracyRoll())then
        miss();return
      end
      local messages=run(ctx)
      if failed(messages)then b:cancelMoveAnim()
      elseif b.moveAnimRow then b.moveAnimRow.hit={animType=ctx.user.isPlayer and 6 or 3}end
      for _,text in ipairs(messages)do b:sayNext(text)end
      b:drainNext()
    end})
  end
  local transform=assert(mod.content.move_effects:get('TRANSFORM_EFFECT')).run
  mod.content.move_effects:patch('TRANSFORM_EFFECT',{run=function(ctx)
    local enabled=M.prepare(ctx.battle,ctx.target)
    local atk=enabled and ctx.target.curStats.specialAttack
    local def=enabled and ctx.target.curStats.specialDefense
    local result=transform(ctx)
    if enabled then
      ctx.user.curStats.specialAttack=atk;ctx.user.curStats.specialDefense=def
    end
    return result
  end})
  local haze=assert(mod.content.move_effects:get('HAZE_EFFECT')).run
  mod.content.move_effects:patch('HAZE_EFFECT',{run=function(ctx)
    local epoch=M.epoch(ctx.battle)
    if not epoch then return haze(ctx)end
    for _,who in ipairs({ctx.user,ctx.target})do
      -- Later Haze resets stages, not status, screens, Disable, confusion,
      -- Toxic's counter, seed, Substitute, or the Pokemon's original stats.
      -- Do not run the Gen-I reset first and try to reconstruct those fields.
      who.stages={}
      if epoch==4 then who.focusEnergy=nil end
      -- No Gen-I Haze status-penalty bypass or accumulated badge glitch.
      who.hazeStatReset=nil;who.badgeExtraBoosts=nil
    end
    return {tr('All stat changes\nwere eliminated!','Alle Statusstufen\nwurden aufgehoben!')}
  end})
  -- Execute before all ability/item modifiers: they must receive the correct
  -- attacking/defending Special value, and their later changes must survive.
  mod.hooks:wrap('battle.damage',M.damage,20000)
  -- Initial trainer levels can be adjusted at battle.started (-100).
  -- Copy battle stats only after those owners finish modifying mon.stats.
  mod.events:on('battle.started',M.entry,-10000)
  mod.events:on('battle.battler_switched',M.entry,9800)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-gen1-battle',providerStatus='battle-only-split-special',
      buildReceiptId='docs/BACKEND_GIFT_MOVESETS_GENERATIONS_20260907.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
