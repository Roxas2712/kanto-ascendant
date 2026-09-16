-- KASC-67-ILLUMINATE. Change the native rate, not the number of rolls or
-- the encounter pool. Repel, encounter suppression and authored replacements
-- remain owned by the existing overworld pipeline.
return function(mod,opts)
  local M={CARD_ID='KASC-67-ILLUMINATE',OWNER='kasc.illuminate/v1'}
  local activeGame
  function M.install(game)activeGame=game end
  function M.adjust(game,def,ctx)
    -- Gen-II's identically named hook is already PAST its rate gate. Do not
    -- pretend changing its table here implements a Gen-II field effect.
    if not game or not game.save or not ctx or ctx.kind
        or (ctx.terrain~='grass'and ctx.terrain~='water'and ctx.terrain~='indoor')
        or type(def)~='table'or type(def.grass)~='table'then return def end
    local rate=def.grass.rate
    if type(rate)~='number'or rate%1~=0 or rate<=0 or rate>=256 then return def end
    local lead=(game.save.party or{})[1]
    if type(lead)~='table'or lead.isEgg or lead.egg or lead.eggSpecies
        or lead.species=='EGG'then return def end
    local profile=opts.rules.peek(game)
    if not profile or not profile.extensionsEnabled or profile.activeEpoch<3
        or profile.activeEpoch>7 then return def end
    local view=opts.binding.view(game,lead,profile.activeEpoch)
    if not view.active or view.id~='ILLUMINATE'then
      local historical=mod.exports.pokemonHistoricalField67
      return historical and historical.adjust(game,def,ctx)or def
    end
    local out,grass={},{}
    for k,v in pairs(def)do out[k]=v end
    for k,v in pairs(def.grass)do grass[k]=v end
    grass.rate=math.min(256,rate*2);out.grass=grass
    return out
  end
  -- Innermost KASC rate adapter: outer scene owners may still suppress the
  -- roll or replace the actual result; no extra RNG draw or global data edit.
  mod.hooks:wrap('encounter.roll',function(nextRoll,def,ctx)
    return nextRoll(M.adjust(activeGame,def,ctx),ctx)
  end,-10000)
  mod.content.move_effects:patch('HEAL_EFFECT',{kascIlluminate67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='native-encounter-roll-and-saved-ability',
      providerStatus='illuminate-iii-vii-on-gen1-host',
      buildReceiptId='docs/ILLUMINATE_67.md',rollbackReceiptId='docs/ILLUMINATE_67.md'})
  end
  return M
end
