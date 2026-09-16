-- Separates certain accuracy from phase/type/effect gates in the Gen-I host.
-- Original Gen-I Swift behavior, AUS, demos and classic links stay native.
return function(mod,opts)
  local facts,species,rules=assert(opts.facts),assert(opts.species),assert(opts.rules)
  local M={CARD_ID='KASC-67-MOVE-ACCURACY',OWNER='kasc.move-accuracy/v1'}
  local owners,cache={},{}
  for id in pairs(facts.data.moves)do
    for _,native in ipairs(species.moveIds(id))do owners[native]=id end
  end
  local function source(id,epoch)
    local key=id..':'..epoch
    if cache[key]==nil then
      local row=facts.move(id,epoch)
      cache[key]=row and row.alwaysHits and row.category~='status' or false
    end
    return cache[key]
  end
  local function profile(battle,user,move)
    if not battle or battle.demo or battle.kind=='link' or not move then return false end
    local game=battle.game
    local effects=game and game.data and game.data.move_effects
    if not effects or not effects.SWIFT_EFFECT
        or effects.SWIFT_EFFECT.kascAccuracyOwner67~=M.OWNER then return false end
    local id=owners[move.id];if not id then return false end
    -- Read the frozen battle receipt; never advance AUTO in a hit check.
    local resolved=battle.kascGenerationRulesReceipt
    if not resolved then
      local bucket=game.save and game.save.modData and game.save.modData[mod.id]
      local state=bucket and bucket[rules.SAVE_KEY]
      if state then resolved={mode=state.activeMode,activeEpoch=state.activeEpoch}end
    end
    if not resolved or resolved.mode=='off' then return false end
    local epoch=tonumber(resolved.activeEpoch) or 1
    local origin=facts.data.moves[id].generation
    if origin>epoch then
      if not (user and rules.ownedGiftBattleCompatible
          and rules.ownedGiftBattleCompatible(game,user.mon,
            game.data.pokemon[user.mon and user.mon.species])) then return false end
      epoch=origin -- explicit owned-gift exception, not a global unlock
    end
    return epoch,id
  end
  function M.isCertain(battle,user,move)
    local epoch,id=profile(battle,user,move)
    return epoch and epoch>=2 and source(id,epoch)==true or false
  end
  function M.isModernOHKO(battle,user,move)
    if not move or move.effect~='OHKO_EFFECT' then return false end
    local epoch=profile(battle,user,move)
    return epoch and epoch>=3 and epoch<=7 or false
  end
  function M.accuracy(nextAccuracy,ctx)
    if ctx and M.isModernOHKO(ctx.battle,ctx.user,ctx.move) then
      local delta=ctx.user.mon.level-ctx.target.mon.level
      if delta<0 then return false end
      -- OHKO ignores ordinary accuracy/evasion stages and modifiers.
      local gen,id=profile(ctx.battle,ctx.user,ctx.move)
      local ice=false;for _,kind in ipairs(ctx.user.curTypes or {})do if kind=='ICE'then ice=true end end
      local base=gen==7 and id=='SHEER_COLD' and not ice and 20 or 30
      return ctx.battle.rng(1,100)<=math.min(100,base+delta)
    end
    if ctx and M.isCertain(ctx.battle,ctx.user,ctx.move) then return true end
    return nextAccuracy(ctx)
  end
  function M.install(registry)
    registry._kascAccuracyOwner67=M
    if registry._kascAccuracyWrapped67 then return end
    local original=assert(registry.runDamaging)
    registry._kascAccuracyWrapped67=true
    registry.runDamaging=function(battle,ctx,record)
      local owner=registry._kascAccuracyOwner67
      if record and record.neverMiss and owner
          and owner.isCertain(battle,ctx.user,ctx.move) then
        -- Gen-I neverMiss bypasses Fly/Dig too. Later eras must keep that
        -- gate and bypass ONLY the accuracy roll through the hook above.
        local selected={};for k,v in pairs(record)do selected[k]=v end
        selected.neverMiss=false
        return original(battle,ctx,selected)
      end
      return original(battle,ctx,record)
    end
  end
  local ohko=assert(mod.content.move_effects:get('OHKO_EFFECT'))
  local originalGate=assert(ohko.gate)
  mod.content.move_effects:patch('OHKO_EFFECT',{gate=function(ctx)
    if not M.isModernOHKO(ctx.battle,ctx.user,ctx.move) then return originalGate(ctx)end
    local gen,id=profile(ctx.battle,ctx.user,ctx.move)
    if gen==7 and id=='SHEER_COLD'then
      for _,kind in ipairs(ctx.target.curTypes or {})do
        if kind=='ICE'then return false,ctx.battle:romText('_DoesntAffectMonText',"It doesn't affect\n%s!",ctx.target.name)end
      end
    end
    if require('src.battle.TypeChart').effectiveness(ctx.move.type,ctx.target.curTypes)==0 then
      return false,ctx.battle:romText('_DoesntAffectMonText',"It doesn't affect\n%s!",ctx.target.name)
    end
    if ctx.user.mon.level<ctx.target.mon.level then
      return false,ctx.battle:romText('_ButItFailedText','But, it failed!')
    end
    return true
  end})
  mod.content.move_effects:patch('SWIFT_EFFECT',{kascAccuracyOwner67=M.OWNER})
  mod.hooks:wrap('battle.accuracy',M.accuracy,-9000)
  M.install(require('src.battle.EffectRegistry'))
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='native-effect-pipeline',
      providerStatus='certain-accuracy-with-phase-gates',
      buildReceiptId='docs/BACKEND_GIFT_MOVESETS_GENERATIONS_20260907.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
