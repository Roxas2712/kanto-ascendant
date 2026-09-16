-- Ability priority belongs to one synchronous native turn-order calculation.
-- Never persist a changed priority in Data.moves or on a saved Pokemon.
return function(mod,opts)
  local M={CARD_ID='KASC-67-PRIORITY-ABILITIES',OWNER='kasc.priority-abilities/v1'}
  local Battle=require('src.battle.BattleState')
  local Effects=require('src.battle.EffectRegistry')
  local activeBattle
  local aliases,healing={},{}
  for id,row in pairs(opts.facts.data.moves)do
    for _,flag in ipairs(row.flags or{})do if flag=='heal'then healing[id]=true end end
    for _,alias in ipairs(opts.species.moveIds(id))do
      aliases[alias]=id
      for _,flag in ipairs(row.flags or{})do if flag=='heal'then healing[alias]=true end end
    end
  end
  local function pack(...)return {n=select('#',...),...}end
  function M.scoped(original,b,...)
    local previous=activeBattle;activeBattle=b
    local out=pack(pcall(original,b,...))
    activeBattle=previous
    if not out[1] then error(out[2],0)end
    return unpack(out,2,out.n)
  end
  local function epoch(b)
    local record=b and b.data and b.data.move_effects and b.data.move_effects.HEAL_EFFECT
    local gen=record and record.kascPriorityOwner67==M.OWNER and opts.status.epoch(b)
    if getmetatable(b)==Battle and not b.result and gen and gen>=3 and gen<=7 then return gen end
  end
  local function adjusted(b,who,move,gen)
    if not move or not who or not who.mon or (who.mon.hp or 0)<=0 then return move end
    local mon=who.mon
    if mon.isEgg or mon.egg or mon.eggSpecies or mon.species=='EGG' then return move end
    local id=opts.abilities.activeAbility(b,who)
    local bonus=0
    if id=='PRANKSTER' and gen>=5 and move.category=='status' then bonus=1
    elseif id=='TRIAGE'and gen==7 and healing[move.id]then bonus=3
    elseif id=='GALE_WINGS' and gen>=6 and move.type=='FLYING'
        and (gen==6 or mon.hp==mon.stats.hp) then bonus=1
    elseif id=='STALL' and gen>=4 then bonus=-0.1 end
    if bonus==0 then return move end
    local copy={};for k,v in pairs(move)do copy[k]=v end
    -- Preserve native fallback priorities for older imported caches too.
    copy.priority=(move.priority or ({QUICK_ATTACK=1,COUNTER=-1})[move.id] or 0)+bonus
    return copy
  end
  function M.order(nextOrder,a,aMove,z,zMove,ctx)
    local b=activeBattle;local gen=epoch(b)
    if gen and a==b.player and z==b.enemy and aMove and zMove then
      aMove,zMove=adjusted(b,a,aMove,gen),adjusted(b,z,zMove,gen)
    end
    return nextOrder(a,aMove,z,zMove,ctx)
  end
  function M.effectivePriority(b,who,move)
    if not move then return 0 end
    local gen=epoch(b)
    local selected=gen and adjusted(b,who,move,gen)or move
    local priority=selected.priority or ({QUICK_ATTACK=1,COUNTER=-1})[move.id]or 0
    local redirect=mod.exports and mod.exports.pokemonMoveRedirection67
    local captured=gen and redirect and redirect.reflectedPrankster(b,who,move)
    if captured~=nil and captured~=false and move.category=='status'then
      priority=(move.priority or 0)+1
    elseif captured==false and gen and move.category=='status'then priority=move.priority or 0 end
    return priority
  end
  function M.blocks(ctx)
    local b,u,t,move=ctx and ctx.battle,ctx and ctx.user,ctx and ctx.target,ctx and ctx.move
    if epoch(b)~=7 or not u or not t or u==t or not u.mon or not t.mon
        or u.mon.hp<=0 or t.mon.hp<=0 or not move then return false end
    local id=aliases[move.id] or move.id
    local row=opts.facts.move(id,7)
    if not row then return false end
    local targeted=row.target==2 or row.target==8 or row.target==9 or row.target==10 or row.target==11
    local redirect=mod.exports and mod.exports.pokemonMoveRedirection67
    local captured=redirect and redirect.reflectedPrankster(b,u,move)
    local priority=M.effectivePriority(b,u,move)
    local terrain=mod.exports and mod.exports.pokemonTerrain67
    if targeted and terrain and terrain.current(b)=='psychic'and terrain.grounded(b,t)
        and priority>0.1 then return true end
    local defender=opts.abilities.activeAbility(b,t)
    if (defender=='DAZZLING'or defender=='QUEENLY_MAJESTY')
        and (targeted or id=='PERISH_SONG'or id=='FLOWER_SHIELD'or id=='ROTOTILLER')
        and priority>0.1 then return true end
    local prankster=captured
    if prankster==nil then prankster=opts.abilities.activeAbility(b,u)=='PRANKSTER'end
    if move.category~='status'or not prankster then return false end
    local dark=false;for _,typ in ipairs(t.curTypes or {})do if typ=='DARK'then dark=true end end
    if not dark then return false end
    if id=='CURSE'then
      for _,typ in ipairs(u.curTypes or {})do if typ=='GHOST'then return true end end
      return false
    end
    -- Selected/random opposing targets and spread-to-foes: NOT self,
    -- Haze's whole field, Perish Song's all-Pokemon or entry hazards.
    return targeted
  end
  local function notice(ctx)
    ctx.battle:cancelMoveAnim()
    local terrain=mod.exports and mod.exports.pokemonTerrain67
    if terrain and terrain.current(ctx.battle)=='psychic'and terrain.grounded(ctx.battle,ctx.target)then
      return opts.i18n.text('Psychic Terrain blocks priority moves!','Das Psychofeld blockt Prioritäts-Attacken!')
    end
    local id=opts.abilities.activeAbility(ctx.battle,ctx.target)
    if id=='DAZZLING'or id=='QUEENLY_MAJESTY'then
      return opts.i18n.text('The ability blocks priority moves!','Die Fähigkeit blockt Prioritäts-Attacken!')
    end
    return opts.i18n.text('The Dark type blocks Prankster!','Der Unlicht-Typ blockt Strolch!')
  end
  local patched={}
  for alias in pairs(aliases)do
    local move=mod.content.moves:get(alias)
    local effect=move and move.effect
    local record=effect and mod.content.move_effects:get(effect)
    if record and not patched[effect] then
      patched[effect]=true
      local patch={}
      if record.callsMove then
        local old=record.callsMove
        patch.callsMove=function(ctx)
          if M.blocks(ctx)then ctx.battle:sayNext(notice(ctx));return nil end
          return old(ctx)
        end
      elseif record.perform then
        local old=record.perform
        patch.perform=function(ctx)
          if M.blocks(ctx)then ctx.battle:sayNext(notice(ctx));return end
          return old(ctx)
        end
      elseif record.kind=='primary' and record.run then
        local old=record.run
        patch.run=function(ctx)
          if M.blocks(ctx)then return {notice(ctx),failed=true}end
          return old(ctx)
        end
      end
      if next(patch)then mod.content.move_effects:patch(effect,patch)end
    end
  end
  mod.hooks:wrap('battle.accuracy',function(nextAccuracy,ctx)
    if M.blocks(ctx)then return true end
    return nextAccuracy(ctx)
  end,23000)
  mod.hooks:wrap('battle.damage',function(nextDamage,ctx)
    if not(ctx.opts and ctx.opts.typeless)and M.blocks(ctx)then return 0,{crit=false,typeMult=0}end
    return nextDamage(ctx)
  end,27500)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascPriorityOwner67=M.OWNER})
  mod.hooks:wrap('battle.turn_order',M.order,0)
  -- Stable dispatch slot: hot reload replaces the owner, not the wrapper.
  Battle._kascPriorityAbilities67=M
  Effects._kascPriorityAbilities67=M
  if not Effects._kascPriorityWrapped67 then
    local run=Effects.runDamaging
    Effects.runDamaging=function(b,ctx,record)
      local owner=Effects._kascPriorityAbilities67
      if not owner.blocks(ctx)then return run(b,ctx,record)end
      b:sayNext(notice(ctx))
    end
    Effects._kascPriorityWrapped67=true
  end
  if not Battle._kascPriorityWrapped67 then
    local original=Battle.resolveTurn
    Battle.resolveTurn=function(...)return Battle._kascPriorityAbilities67.scoped(original,...)end
    Battle._kascPriorityWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-turn-order',providerStatus='ability-priority',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
