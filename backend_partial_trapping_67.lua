-- Later-era partial trapping, isolated from the host's Gen-I repeat/lock.
-- All HP changes/faints are native field-residual descriptors, not save edits.
return function(mod,opts)
  local M={CARD_ID='KASC-67-PARTIAL-TRAPPING',OWNER='kasc.partial-trapping/v1'}
  local tr=opts.i18n.text
  local shell={id='SHED_SHELL',generation=4,names={en='SHED SHELL',de='WECHSELHÜLLE'},
    flags={'holdable','holdable-passive'}}
  function M.itemMetadata(id)if id=='SHED_SHELL'then return shell end end
  local shellFields={kascEscapeShell67=M.OWNER,kascEquipmentRewardEpochs={[4]=true,[5]=true,[6]=true,[7]=true}}
  if mod.content.items:get('SHED_SHELL')then mod.content.items:patch('SHED_SHELL',shellFields)
  else
    shellFields.id=shell.id;shellFields.name=tr(shell.names.en,shell.names.de);shellFields.names=shell.names
    shellFields.originGeneration=4;shellFields.price=0;shellFields.keyItem=false
    mod.content.items:register('SHED_SHELL',shellFields)
  end
  function M.supportsItem(game,id,gen)
    local def=game and game.data and game.data.items and game.data.items[id]
    local trap=game and game.data and game.data.move_effects and game.data.move_effects.TRAPPING_EFFECT
    return id=='SHED_SHELL'and def and def.kascEscapeShell67==M.OWNER
      and trap and trap.kascPartialTrap67==M.OWNER and gen>=4 and gen<=7 or false
  end
  -- Native semantic checkpoints copy field.tokens. Store only side names
  -- and scalars here, never pointers to battlers or callback closures.
  local function listFor(b,create)
    if not b then return end
    if create then b.field=b.field or {};b.field.tokens=b.field.tokens or {}end
    local tokens=b.field and b.field.tokens
    if not tokens then return end
    if create and not tokens[M.OWNER] then tokens[M.OWNER]={}end
    return tokens[M.OWNER]
  end
  local function side(b,who)
    return who==b.player and 'player' or who==b.enemy and 'enemy' or nil
  end
  local frames={}
  local aliases={}
  for id in pairs(opts.facts.data.moves)do
    for _,alias in ipairs(opts.species.moveIds(id))do aliases[alias]=id end
  end
  local moves={BIND=true,WRAP=true,FIRE_SPIN=true,CLAMP=true,WHIRLPOOL=true,
    SAND_TOMB=true,MAGMA_STORM=true,INFESTATION=true}
  local function enabled(b)
    local row=b and b.data and b.data.move_effects and b.data.move_effects.TRAPPING_EFFECT
    if not row or row.kascPartialTrap67~=M.OWNER then return end
    local e=opts.status.epoch(b)
    return e
  end
  function M.epoch(b)
    local e=enabled(b);return e and e>=2 and e or nil
  end
  local function moveEpoch(ctx)
    if not enabled(ctx.battle) then return end
    return opts.critical.epoch(ctx.battle,ctx.user,ctx.move)
  end
  local function active(b,who)
    return who and who.mon.hp>0 and (who==b.player or who==b.enemy)
  end
  function M.validateCheckpoint(b)
    local list=listFor(b)
    if list==nil then return true end
    if type(list)~='table' then return false,'invalid_partial_trapping_token' end
    for key,row in pairs(list)do
      if (key~='player' and key~='enemy') or type(row)~='table'
          or (row.source~='player' and row.source~='enemy') or row.source==key
          or not moves[aliases[row.move] or row.move] or not b.data.moves[row.move]
          or type(row.epoch)~='number' or row.epoch%1~=0 or row.epoch<2 or row.epoch>9
          or type(row.remaining)~='number' or row.remaining%1~=0
          or row.remaining<1 or row.remaining>6
          or (row.lastTurn~=nil and (type(row.lastTurn)~='number'
            or row.lastTurn%1~=0 or row.lastTurn<0 or row.lastTurn>(b.turnCount or 0)))then
        return false,'invalid_partial_trapping_state'
      end
    end
    return true
  end
  local function state(b,who)
    if not enabled(b) or b.result then return end
    local key=side(b,who);local list=listFor(b);local row=list and list[key]
    if row and (not active(b,who) or not active(b,b[row.source]))then list[key]=nil;return end
    return row
  end
  local function has(who,kind)
    for _,t in ipairs(who.curTypes or {})do if t==kind then return true end end
    return false
  end
  function M.abilityTrap(b,who)
    local gen=M.epoch(b)
    if not gen or gen<3 or gen>7 or b.result or not active(b,who)or not opts.abilities then return false end
    local other=who==b.player and b.enemy or b.player
    if not active(b,other)or gen>=6 and has(who,'GHOST')then return false end
    local id=opts.abilities.activeAbility(b,other)
    if id=='MAGNET_PULL'then return has(who,'STEEL')end
    if id=='SHADOW_TAG'then
      return gen==3 or opts.abilities.activeAbility(b,who)~='SHADOW_TAG'
    end
    if id=='ARENA_TRAP'then
      local ground=opts.grounding and opts.grounding()
      return ground and not ground.airborne(b,who)or false
    end
    return false
  end
  function M.blocked(b,who,forRun)
    local sky=mod.exports.pokemonSkyDrop67
    if sky and sky.involved(b,who)then return true end
    local interruptions=mod.exports.pokemonFieldInterruptions67
    if interruptions and interruptions.blocked(b,who,forRun)then return true end
    local gen=M.epoch(b)
    if not forRun and gen and active(b,who)and opts.held
        and M.supportsItem(b.game,opts.held(who.mon,b,who),gen)
        and opts.abilities.activeAbility(b,who)~='KLUTZ'then return false end
    local row=state(b,who)
    local permanent=mod.exports.pokemonEscapeLock67
    local roots=mod.exports.pokemonRootRecovery67
    return row and not (row.epoch>=6 and has(who,'GHOST')) or M.abilityTrap(b,who)
      or roots and roots.blocked(b,who)
      or permanent and permanent.blocked(b,who,forRun)or false
  end
  function M.clear(b,who)
    local list=listFor(b);local key=side(b,who)
    if list and key and list[key]then list[key]=nil;return true end
    return false
  end
  function M.start(ctx)
    local b,who=ctx.battle,ctx.target
    local epoch=moveEpoch(ctx)
    if not epoch or not active(b,ctx.user) or not active(b,who)
        or who.substituteHP or ctx.brokeSub or state(b,who) then return {}end
    local turns
    if epoch==2 then turns=ctx.rng(0,255)%4+2 -- Crystal TrapTarget byte AND 3
    elseif epoch<=4 then turns=ctx.rng(2,5)
    else turns=ctx.rng(4,5)end
    local list=listFor(b,true)
    list[side(b,who)]={source=side(b,ctx.user),move=ctx.move.id,epoch=epoch,remaining=turns+1}
    return {tr('%s is trapped by %s!','%s wird durch %s festgehalten!'):
      format(who.name or who.mon.species,ctx.move.name or ctx.move.id)}
  end
  function M.rows(b)
    local rows={}
    if not enabled(b) or b.result then return rows end
    for index,who in ipairs({b.player,b.enemy})do
      local row=state(b,who)
      if row and row.lastTurn~=(b.turnCount or 0)then
        row.lastTurn=b.turnCount or 0;row.remaining=row.remaining-1
        if row.remaining<=0 then
          M.clear(b,who)
          b:sayNext(tr('%s was freed!','%s wurde befreit!'):format(who.name or who.mon.species))
        elseif not(opts.abilities and opts.abilities.blocksIndirect(b,who,'trapping'))then
          rows[#rows+1]={side=index==1 and 'player' or 'enemy',
            amount=math.max(1,math.floor(who.mon.stats.hp/(row.epoch>=6 and 8 or 16))),
            message=tr('%s is hurt by %s!','%s erleidet Schaden durch %s!'):
              format(who.name or who.mon.species,b.data.moves[row.move].name or row.move)}
        end
      end
    end
    return rows
  end
  local native=assert(mod.content.move_effects:get('TRAPPING_EFFECT'))
  local before,after=native.beforeAccuracy,native.afterDamage
  mod.content.move_effects:patch('TRAPPING_EFFECT',{kascPartialTrap67=M.OWNER,
    beforeAccuracy=function(ctx)
      if not moveEpoch(ctx) and before then return before(ctx)end
    end,
    afterDamage=function(ctx,...)
      if not moveEpoch(ctx) then if after then return after(ctx,...)end;return end
      for _,message in ipairs(M.start(ctx))do ctx.battle:sayNext(message)end
    end})
  -- Preserve previous compound/status owners on NO_ADDITIONAL_EFFECT.
  local additional=assert(mod.content.move_effects:get('NO_ADDITIONAL_EFFECT')).run
  mod.content.move_effects:patch('NO_ADDITIONAL_EFFECT',{run=function(ctx)
    local id=aliases[ctx.move.id] or ctx.move.id
    if moveEpoch(ctx) then
      if moves[id] then return M.start(ctx)end
    end
    return additional and additional(ctx) or {}
  end})
  for _,id in ipairs(opts.species.moveIds('RAPID_SPIN'))do
    local move=mod.content.moves:get(id)
    if move then
      local original=assert(mod.content.move_effects:get(move.effect))
      local copied={};for k,v in pairs(original)do copied[k]=v end
      copied.afterDamage=function(ctx,...)
        if original.afterDamage then original.afterDamage(ctx,...)end
        if moveEpoch(ctx) and ctx.user.mon.hp>0 and (ctx.totalDealt or 0)>0 then
          M.clear(ctx.battle,ctx.user);ctx.user.leechSeeded=nil
        end
      end
      local effect='KA_PARTIAL_TRAP_SPIN_67_'..id
      mod.content.move_effects:register(effect,copied)
      mod.content.moves:patch(id,{effect=effect})
    end
  end
  local Battle=require('src.battle.BattleState')
  Battle._kascPartialTrapOwner67=M
  if not Battle._kascPartialTrapWrapped67 then
    local field,swap,ai,execute=Battle.applyFieldResiduals,Battle.resolveSwitch,
      Battle.trainerAIAction,Battle.executeAction
    Battle.applyFieldResiduals=function(self,...)
      local owner=Battle._kascPartialTrapOwner67
      return owner.withField(self,field,...)
    end
    Battle.resolveSwitch=function(self,...)
      local owner=Battle._kascPartialTrapOwner67
      if owner.blocked(self,self.player)then
        self.phase='messages';self.afterQueue='menu'
        self:say(owner.refusal(self.player));return
      end
      return swap(self,...)
    end
    Battle.trainerAIAction=function(self,...)
      local action=ai(self,...)
      if action and action.special=='aiSwitch'
          and Battle._kascPartialTrapOwner67.blocked(self,self.enemy)then return nil end
      return action
    end
    Battle.executeAction=function(self,user,target,action,...)
      if action and action.special=='aiSwitch'
          and Battle._kascPartialTrapOwner67.blocked(self,user)then
        -- A preselected stale switch cannot escape the lock either. The
        -- regular trainer-AI path above instead keeps its chosen move.
        self:sayNext(Battle._kascPartialTrapOwner67.refusal(user));return
      end
      return execute(self,user,target,action,...)
    end
    Battle._kascPartialTrapWrapped67=true
  end
  function M.refusal(who)
    return tr('%s cannot escape!','%s kann nicht entkommen!'):format(who.name or who.mon.species)
  end
  function M.withField(b,original,...)
    frames[#frames+1]=b
    local ok,result=pcall(original,b,...)
    frames[#frames]=nil
    if not ok then error(result,0)end
    return result
  end
  mod.hooks:wrap('battle.field_residual',function(nextResidual,ctx)
    local rows=nextResidual(ctx);local out={}
    for _,r in ipairs(type(rows)=='table' and rows or {})do out[#out+1]=r end
    local b=frames[#frames]
    if b then for _,r in ipairs(M.rows(b))do out[#out+1]=r end end
    return out
  end,-9000)
  mod.hooks:wrap('battle.run',function(nextRun,ctx)
    local b=ctx.battle;local gen=b and M.epoch(b)
    if gen and gen>=6 and b.kind=='wild'and active(b,b.player)and has(b.player,'GHOST')then return true end
    if b and M.blocked(b,b.player,true)then return false end
    return nextRun(ctx)
  end,-9000)
  mod.events:on('battle.battler_switched',function(event)
    local list=listFor(event.battle)
    if list then
      local previous=event.previous
      local key=previous and (previous.isPlayer and 'player' or 'enemy')
      for who,row in pairs(list)do
        if who==key or row.source==key then list[who]=nil end
      end
    end
  end)
  mod.events:on('battle.ended',function(event)
    local b=event and event.battle
    if b and b.field and b.field.tokens then b.field.tokens[M.OWNER]=nil end
  end)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-field-residual-chain',
      providerStatus='historical-partial-trapping',
      buildReceiptId='docs/BACKEND_PARTIAL_TRAPPING_67.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
