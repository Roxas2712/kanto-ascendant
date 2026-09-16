-- STENCH III--VII keeps its lead encounter-rate effect, never early flinching.
-- Reused by the existing Illuminate encounter.roll adapter; no new RNG/hook.
return function(mod,opts)
  local M={CARD_ID='KASC-67-HISTORICAL-FIELD',OWNER='kasc.historical-field/v1'}
  local illuminate=assert(opts.illuminate)
  assert(illuminate.OWNER=='kasc.illuminate/v1'and type(illuminate.adjust)=='function','historical field requires real Illuminate owner')
  local function epoch(gen)return type(gen)=='number'and gen%1==0 and gen>=3 and gen<=7 end
  function M.supportsFieldAbility(game,id,gen)
    local record=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
    return id=='STENCH'and epoch(gen)and record and record.kascHistoricalField67==M.OWNER
      and record.kascIlluminate67==illuminate.OWNER and record.kascAbilityOwner67=='kasc.ability-effects/v1'
      and type(opts.binding.view)=='function'or false
  end
  -- Only early combat-core readiness belongs here. From V onward the real
  -- Contact owner still supplies the additional damaging-hit flinch effect.
  function M.supportsAbility(game,id,gen)
    return(gen==3 or gen==4)and M.supportsFieldAbility(game,id,gen)or false
  end
  function M.adjust(game,def,ctx)
    -- Native Gen II encounter.roll is after its rate gate: ctx.kind marks
    -- that different host contract. Do not claim an after-gate rate edit.
    if not game or not game.save or type(ctx)~='table'or ctx.kind~=nil
      or(ctx.terrain~='grass'and ctx.terrain~='water'and ctx.terrain~='indoor')
      or type(def)~='table'or type(def.grass)~='table'then return def end
    local rate=def.grass.rate
    if type(rate)~='number'or rate%1~=0 or rate<=0 or rate>=256 then return def end
    local profile=opts.rules.peek(game)
    if not profile or not profile.extensionsEnabled or not M.supportsFieldAbility(game,'STENCH',profile.activeEpoch)then return def end
    local lead=game.save.party and game.save.party[1]
    if type(lead)~='table'or lead.isEgg or lead.egg or lead.is_egg or lead.eggSpecies or lead.species=='EGG'then return def end
    -- Fainted leads still supply this field effect. Inspect the current
    -- save/real stable binding every use; never cache a former slot's mon.
    local ability=opts.binding.view(game,lead,profile.activeEpoch)
    if not ability or ability.active~=true or ability.id~='STENCH'then return def end
    local out,grass={},{}
    for key,v in pairs(def)do out[key]=v end
    for key,v in pairs(def.grass)do grass[key]=v end
    -- Preserve the actual 0..255 native rate comparison and its ONE draw.
    -- Odd half-rates retain their precise scalar; integer draws naturally
    -- quantize this to ceil(rate/2) hit values without invented extra RNG.
    grass.rate=rate/2;out.grass=grass;return out
  end
  function M.describeAbility(id,gen)
    if id~='STENCH'or not epoch(gen)then return end
    local out={en='As the party lead, halves normal step-based wild encounter rate. Works while fainted; not from party reserves or Eggs.',
      de='Als erstes Pokémon halbiert es die Rate normaler wilder Schritt-Begegnungen. Wirkt auch besiegt, nicht aus Reserven oder Eiern.'}
    if gen<=4 then
      out.en=out.en..' In Gen III/IV it has no battle flinch effect.'
      out.de=out.de..' In Gen III/IV kein Zurückschrecken im Kampf.'
    else
      out.en=out.en..' Damaging hits also have a 10% flinch chance unless the move already causes flinching; the target must not have acted.'
      out.de=out.de..' Schadentreffer haben außerdem 10% Zurückschreck-Chance, sofern die Attacke dies nicht schon auslöst; das Ziel darf noch nicht gehandelt haben.'
    end
    return out
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHistoricalField67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='existing-native-illuminate-encounter-rate-adapter',providerStatus='stench-gen3-7-field-with-separate-modern-contact-owner',
      buildReceiptId='docs/HISTORICAL_FIELD_67.md',rollbackReceiptId='docs/HISTORICAL_FIELD_67.md'})
  end
  return M
end
