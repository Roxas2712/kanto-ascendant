-- KASC-67-GENERATION-MOVE-CATALOG
-- Complete identity/epoch registration for moves #166-621 (Gen II-VI).
-- The Gen-I engine already supplies animation and effect primitives; this
-- adapter maps every later move to the strongest supported primitive and
-- fails closed for unique status mechanics which have no honest projection.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "generation move catalog data missing")
  assert(data._meta and data._meta.count == 456,
    "generation move catalog cardinality drift")
  local C = {
    order={}, byId=data.byId, registered={}, preserved={},
    unsupportedStatus={}, animations={}, audit={byGeneration={},effects={}},
  }
  function C.setStatResolver(resolve,changeStage)
    C.statResolver=resolve;C.changeStage=changeStage
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end
  local function effectExists(id)
    return mod.content.move_effects:get(id) ~= nil
  end
  local function effect(id)
    return effectExists(id) and id or "NO_ADDITIONAL_EFFECT"
  end
  local function chanceEffect(row, variants)
    local chance = tonumber(row.ailmentChance) or 0
    if chance >= 30 and variants[2] then return effect(variants[2]) end
    return effect(variants[1])
  end

  local SIDE_AILMENT = {
    [1]={"PARALYZE_SIDE_EFFECT1","PARALYZE_SIDE_EFFECT2"},
    [3]={"FREEZE_SIDE_EFFECT1"}, [4]={"BURN_SIDE_EFFECT1","BURN_SIDE_EFFECT2"},
    [5]={"POISON_SIDE_EFFECT1","POISON_SIDE_EFFECT2"},
    [6]={"CONFUSION_SIDE_EFFECT"},
  }
  local PRIMARY_AILMENT = {
    [1]="PARALYZE_EFFECT", [2]="SLEEP_EFFECT", [5]="POISON_EFFECT",
    [6]="CONFUSION_EFFECT",
  }
  local TYPE_ANIMATION = {
    NORMAL="TACKLE",FIGHTING="KARATE_CHOP",FLYING="GUST",POISON="ACID",
    GROUND="EARTHQUAKE",ROCK="ROCK_THROW",BUG="PIN_MISSILE",
    GHOST="NIGHT_SHADE",STEEL="HARDEN",FIRE="EMBER",WATER="WATER_GUN",
    GRASS="VINE_WHIP",ELECTRIC="THUNDER_SHOCK",PSYCHIC_TYPE="CONFUSION",
    ICE="ICE_BEAM",DRAGON="DRAGON_RAGE",DARK="BITE",FAIRY="SWIFT",
  }
  local SEMI_INVULNERABLE = {
    BOUNCE="FLY", DIVE="DIG", SHADOW_FORCE="FLY",
    SKY_DROP="FLY", PHANTOM_FORCE="FLY",
  }

  local function normalizedChanges(row)
    local merged = {}
    for _,change in ipairs(row.changes or {}) do
      local stat, delta = change.stat, tonumber(change.change) or 0
      if stat and delta ~= 0 then
        local previous = merged[stat]
        if not previous or math.abs(delta) > math.abs(previous) then
          merged[stat] = delta
        end
      end
    end
    local out={}
    for _,stat in ipairs({"attack","defense","speed","special","accuracy","evasion"}) do
      if merged[stat] then out[#out+1]={stat=stat,change=merged[stat]} end
    end
    return out
  end

  local function animationAlias(row, effectKind)
    local airborne=SEMI_INVULNERABLE[row.id]
    if airborne then return airborne end
    if effectKind=="healing" then return "RECOVER" end
    if effectKind=="stat-primary" then
      local changes=normalizedChanges(row)
      for _,change in ipairs(changes) do
        if change.change>0 then
          return ({attack="SWORDS_DANCE",defense="HARDEN",speed="AGILITY",
            special="AMNESIA",evasion="DOUBLE_TEAM"})[change.stat]
            or "SWORDS_DANCE"
        end
      end
    end
    return TYPE_ANIMATION[row.type] or "TACKLE"
  end

  local function registerAnimation(id, alias)
    local animations=mod.content.battle_anims
    if not (animations and type(animations.get)=="function"
        and type(animations.register)=="function") then return end
    if animations:get(id) then return end
    local source=animations:get(alias)
    if not source then return end
    animations:register(id, copy(source))
    C.animations[#C.animations+1]=id
  end

  local function registerStatEffect(row, damaging)
    local id="KA_GEN_MOVE_STAT_"..row.id
    if effectExists(id) then return id end
    local changes=normalizedChanges(row)
    mod.content.move_effects:register(id, {
      kind=damaging and "secondary" or "primary",
      accuracyChecked=not damaging and row.target~=7 or nil,
      run=function(ctx)
        if damaging and row.statChance>0
            and ctx.rng(1,100)>row.statChance then return {} end
        local messages={}
        local resolved=C.statResolver and C.statResolver(ctx,row) or changes
        for _,change in ipairs(resolved) do
          -- Source category 7 is damage plus a change to the USER, even
          -- when that change is negative (Close Combat/Superpower). Primary
          -- moves use their explicit target; Swagger's positive change is
          -- not a self-buff. Sign alone cannot determine who is affected.
          local selfTarget=damaging and row.metaCategory==7
            or not damaging and row.target==7
          local target=selfTarget and ctx.user or ctx.target
          local changeStage=C.changeStage and function(who,stat,delta,fromEnemy)
            return C.changeStage(ctx,who,stat,delta,fromEnemy)
          end or ctx.changeStage
          for _,message in ipairs(changeStage(target,change.stat,
              change.change,target~=ctx.user and change.change<0)) do
            messages[#messages+1]=message
          end
        end
        return messages
      end,
    })
    return id
  end

  local function registerPrimaryAilment(row)
    local stock=PRIMARY_AILMENT[row.ailment]
    if stock and effectExists(stock) then return stock end
    if row.ailment~=3 and row.ailment~=4 then return nil end
    local id="KA_GEN_MOVE_AILMENT_"..row.id
    mod.content.move_effects:register(id, {
      kind="primary",accuracyChecked=true,
      run=function(ctx)
        local failed={tr("But, it failed!","Doch es schlug fehl!")}
        if ctx.target.mon.status or ctx.target.mon.hp<=0
            or ctx.target.substituteHP or not ctx.inflict then return failed end
        -- The native registry owns immunity, ability hooks, stat penalties,
        -- localized text and status events. Never assign the save byte here.
        local messages=ctx.inflict(ctx.target,row.ailment==3 and "FRZ" or "BRN",{
          moveType=ctx.move and ctx.move.type or row.type,
          source=ctx.move and ctx.move.id or row.id,
        })
        return #messages>0 and messages or failed
      end,
    })
    return id
  end

  local function registerUnsupported(row)
    local id="KA_GEN_MOVE_UNSUPPORTED_"..row.id
    mod.content.move_effects:register(id, {
      kind="primary",accuracyChecked=false,
      run=function()
        return {tr("This move cannot be\nused in this ruleset.",
          "Diese Attacke ist in\ndiesen Regeln gesperrt.")}
      end,
    })
    C.unsupportedStatus[#C.unsupportedStatus+1]=row.id
    return id
  end

  -- Gen-II Foresight is a volatile mark on the current battler. The native
  -- switch path creates a fresh battler, so this never changes saved types.
  local identifiedKey="_kascForesightIdentified"
  local function shallow(value)
    local out={};for k,v in pairs(value or {})do out[k]=v end;return out
  end
  local function registerForesight()
    local id="KA_GEN_MOVE_FORESIGHT"
    mod.content.move_effects:register(id, {
      kind="primary",accuracyChecked=true,
      run=function(ctx)
        local target=ctx.target
        if target[identifiedKey] or target.invulnerable or target.mon.hp<=0 then
          return {tr("But, it failed!","Doch es schlug fehl!")}
        end
        target[identifiedKey]=true
        return {tr("%s identified\n%s!","%s identifiziert\n%s!"):format(
          ctx.displayName(ctx.user),ctx.displayName(target))}
      end,
    })
    mod.hooks:wrap("battle.accuracy",function(nextAccuracy,ctx)
      if not (ctx and ctx.target and ctx.target[identifiedKey]) then return nextAccuracy(ctx)end
      local acc=ctx.user.stages and ctx.user.stages.accuracy or 0
      local eva=ctx.target.stages and ctx.target.stages.evasion or 0
      if eva<acc then return nextAccuracy(ctx)end
      -- Crystal's identification rule ignores disadvantageous accuracy/evasion
      -- stage comparisons; base accuracy, misses and other hooks still apply.
      local adjusted=shallow(ctx)
      adjusted.user=shallow(ctx.user);adjusted.user.stages=shallow(ctx.user.stages)
      adjusted.target=shallow(ctx.target);adjusted.target.stages=shallow(ctx.target.stages)
      adjusted.user.stages.accuracy=0;adjusted.target.stages.evasion=0
      return nextAccuracy(adjusted)
    end,22000)
    mod.hooks:wrap("battle.damage",function(nextDamage,ctx)
      if not (ctx and ctx.target and ctx.target[identifiedKey] and ctx.move
          and (ctx.move.type=="NORMAL" or ctx.move.type=="FIGHTING")) then return nextDamage(ctx)end
      local adjusted=shallow(ctx);adjusted.target=shallow(ctx.target)
      adjusted.target.curTypes={}
      for _,t in ipairs(ctx.target.curTypes or {})do
        if t~="GHOST" then adjusted.target.curTypes[#adjusted.target.curTypes+1]=t end
      end
      return nextDamage(adjusted)
    end,22000)
    return id
  end

  -- Conditions are owned by the move, not by the trainer or selected era.
  -- Later moves must never become free generic damage in a Gen-I host.
  local conditionalIds = {
    FOCUS_PUNCH="KA_GEN_FOCUS_PUNCH", SUCKER_PUNCH="KA_GEN_SUCKER_PUNCH",
    GIGA_IMPACT="KA_GEN_GIGA_IMPACT",
  }
  local function battleState(battle)
    return battle and battle._kaConditionalMoves67
  end
  local function focusLost(battle,user)
    local state=battleState(battle)
    return state and state.hit[user] == true or false
  end
  local function focusMessage(user)
    return tr("Lost focus! The attack failed.","Die Konzentration ist weg! Power-Punch scheitert.")
  end
  local function suckerAllowed(ctx)
    local state=battleState(ctx.battle)
    local action=state and state.actions[ctx.target]
    local move=action and action.id and ctx.data.moves[action.id]
    return state and not state.moved[ctx.target] and not ctx.target.mustRecharge
      and action and not action.special and move
      and (move.category=="physical" or move.category=="special"
        or move.category~="status" and (tonumber(move.power)or 0)>0) or false
  end
  local records={
    FOCUS_PUNCH={kind="full",gate=function(ctx)
      return not focusLost(ctx.battle,ctx.user),focusMessage(ctx.user)
    end},
    SUCKER_PUNCH={kind="full",gate=function(ctx)
      return suckerAllowed(ctx),tr("But, it failed!","Doch es schlug fehl!")
    end},
    GIGA_IMPACT={kind="full",afterDamage=function(ctx,dealt)
      -- Unlike the original Hyper Beam, this later move recharges even
      -- after a knockout or breaking a Substitute. Misses never enter here.
      if (tonumber(dealt)or 0)>0 then ctx.user.mustRecharge=true end
    end},
  }
  -- The same recharge contract covers every imported Hyper-Beam-style
  -- move (#81), not just Giga Impact. Native Gen-I Hyper Beam is untouched.
  for id,row in pairs(data.byId)do
    if row.effect==81 then
      conditionalIds[id]="KA_GEN_RECHARGE_"..id
      records[id]=records.GIGA_IMPACT
    end
  end
  for move,id in pairs(conditionalIds)do
    if not effectExists(id)then mod.content.move_effects:register(id,records[move])end
  end
  function C.conditionalTurn(ev)
    local battle=ev and ev.battle
    if not battle then return end
    local actions={}
    if battle.player then actions[battle.player]=ev.playerAction end
    if battle.enemy then actions[battle.enemy]=ev.enemyAction end
    battle._kaConditionalMoves67={actions=actions,moved={},hit={}}
    for battler,action in pairs(actions)do
      if action and action.id=="FOCUS_PUNCH" and type(battle.say)=="function" then
        battle:say(tr("Focusing for Focus Punch...","Konzentriert sich auf Power-Punch..."))
      end
    end
  end
  function C.conditionalMoveUsed(ev)
    local state=ev and battleState(ev.battle)
    if not state then return end
    state.moved[ev.user]=true
    state.damageTarget,state.damageMove=ev.target,ev.move
    state.beforeHP=ev.target and ev.target.mon and ev.target.mon.hp
  end
  function C.conditionalDamage(ev)
    local state=ev and battleState(ev.battle)
    if not state or not ev.target or ev.user==ev.target then return end
    -- Compare real HP, not damage credited to a Substitute. This also
    -- excludes recoil, weather, poison and other non-attack HP changes.
    if state.damageTarget==ev.target and state.damageMove==ev.move
        and (tonumber(ev.damage)or 0)>0 and state.beforeHP
        and ev.target.mon.hp<state.beforeHP then state.hit[ev.target]=true end
    if state.damageTarget==ev.target then state.beforeHP=ev.target.mon.hp end
  end
  function C.clearConditional(ev)
    if ev and ev.battle then ev.battle._kaConditionalMoves67=nil end
  end
  function C.installConditional(Battle)
    Battle._kaConditionalOwner67=C
    if Battle._kaConditionalWrapped67 then return end
    Battle._kaConditionalWrapped67=true
    local execute=assert(Battle.executeAction)
    Battle.executeAction=function(battle,user,target,action)
      local state=battleState(battle)
      if state then state.moved[user]=true end
      return execute(battle,user,target,action)
    end
    local perform=assert(Battle.performMove)
    Battle.performMove=function(battle,user,target,inst,called)
      local move=inst and battle.data and battle.data.moves[inst.id]
      if move and move.effect==conditionalIds.FOCUS_PUNCH and focusLost(battle,user) then
        -- Stop before the native PP deduction and used-move announcement.
        -- A lost-focus failure consumes neither PP nor damage RNG.
        battle:sayNext(focusMessage(user))
        return
      end
      return perform(battle,user,target,inst,called)
    end
  end
  if mod.events and type(mod.events.on)=="function" then
    mod.events:on("battle.turn_started",C.conditionalTurn,5000)
    mod.events:on("battle.move_used",C.conditionalMoveUsed,5000)
    mod.events:on("battle.damage_dealt",C.conditionalDamage,5000)
    mod.events:on("battle.turn_ended",C.clearConditional,-5000)
    mod.events:on("battle.ended",C.clearConditional,-5000)
    mod.events:on("battle.battler_switched",C.clearConditional,5000)
    C.installConditional(require("src.battle.BattleState"))
  end

  local function chooseEffect(row)
    if conditionalIds[row.id] then return conditionalIds[row.id],"conditional-damage" end
    local damaging=row.category~="status"
    if not damaging then
      if row.id=="FORESIGHT" then return registerForesight(),"identification" end
      if row.healing>0 then return effect("HEAL_EFFECT"),"healing" end
      if #(row.changes or {})>0 then
        return registerStatEffect(row,false),"stat-primary"
      end
      local ailment=registerPrimaryAilment(row)
      if ailment then return ailment,"ailment-primary" end
      return registerUnsupported(row),"unsupported-status"
    end
    if row.id=="FREEZE_SHOCK" or row.id=="ICE_BURN" then
      local id="KA_GEN_CHARGE_"..row.id
      if not effectExists(id)then
        local side=SIDE_AILMENT[row.ailment]
        local selected=side and chanceEffect(row,side) or "NO_ADDITIONAL_EFFECT"
        local record=copy(mod.content.move_effects:get(selected) or {})
        record.charge={anim="XSTATITEM_ANIM",enemyAnim="XSTATITEM_DUPLICATE_ANIM"}
        mod.content.move_effects:register(id,record)
      end
      return id,"charge-with-secondary"
    end
    if SEMI_INVULNERABLE[row.id] then
      return effect("FLY_EFFECT"),"semi-invulnerable"
    end
    if row.minHits>0 then
      if row.minHits==2 and row.maxHits==2 then
        return effect("ATTACK_TWICE_EFFECT"),"double-hit"
      end
      return effect("TWO_TO_FIVE_ATTACKS_EFFECT"),"multi-hit"
    end
    if row.metaCategory==9 then return effect("OHKO_EFFECT"),"ohko" end
    if row.drain>0 then return effect("DRAIN_HP_EFFECT"),"drain" end
    if row.drain<0 then return effect("RECOIL_EFFECT"),"recoil" end
    if #(row.changes or {})>0 and row.statChance>0 then
      return registerStatEffect(row,true),"stat-secondary"
    end
    local side=SIDE_AILMENT[row.ailment]
    if side and row.ailmentChance>0 then
      return chanceEffect(row,side),"ailment-secondary"
    end
    if row.flinchChance>0 then
      return effect(row.flinchChance>=30 and "FLINCH_SIDE_EFFECT2"
        or "FLINCH_SIDE_EFFECT1"),"flinch"
    end
    return effect("NO_ADDITIONAL_EFFECT"),"plain-damage"
  end

  for _,id in ipairs(data.order) do
    local row=assert(data.byId[id],"missing move row "..tostring(id))
    C.order[#C.order+1]=id
    C.audit.byGeneration[row.generation]=(C.audit.byGeneration[row.generation]or 0)+1
    if mod.content.moves:get(id) then
      C.preserved[#C.preserved+1]=id
    else
      local selected,kind=chooseEffect(row)
      local alias=animationAlias(row,kind)
      local sourceMove=mod.content.moves:get(alias)
      registerAnimation(id,alias)
      C.audit.effects[kind]=(C.audit.effects[kind]or 0)+1
      mod.content.moves:register(id, {
        id=id,name=tr(row.name.en,row.name.de),type=row.type,
        power=row.category=="status" and 0 or math.max(1,row.power),
        accuracy=row.accuracy,pp=row.pp,
        category=row.category,priority=row.priority~=0 and row.priority or nil,
        highCrit=row.critRate>0 and true or nil,effect=selected,
        -- The engine queues animations by the used move id. Each catalog
        -- identity therefore owns a cloned battle-animation row, while this
        -- field carries the matching Gen-I sound metadata.
        anim=sourceMove and copy(sourceMove.anim) or nil,
        multiHit=row.minHits>0 and row.minHits==row.maxHits and row.minHits
          or row.minHits>0 and {2,2,2,3,3,3,4,5} or nil,
      })
      C.registered[#C.registered+1]=id
    end
  end

  function C.origin(id)
    local row=type(id)=="string" and data.byId[id] or nil
    return row and row.generation or nil
  end
  function C.available(id,epoch)
    local origin=C.origin(id)
    return origin~=nil and origin<=math.max(1,tonumber(epoch)or 1)
  end
  function C.status()
    return {total=#C.order,registered=#C.registered,preserved=#C.preserved,
      unsupportedStatus=#C.unsupportedStatus,animations=#C.animations}
  end
  C.data=data
  return C
end
