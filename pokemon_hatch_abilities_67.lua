-- Field-only hatch assistance. The Day-Care owns progress and hatching;
-- this card only resolves a bounded, non-stacking rate for the next step.
return function(mod,opts)
  local M={CARD_ID='KASC-67-HATCH-ABILITIES',OWNER='kasc.hatch-abilities/v1'}
  function M.stepRate(game)
    local marker=game and game.data and game.data.move_effects
      and game.data.move_effects.HEAL_EFFECT
    if not marker or marker.kascHatchAbilityOwner67~=M.OWNER
        or not game.save or game.demo then return 1 end
    local profile=opts.rules.resolve(game)
    local epoch=profile and tonumber(profile.activeEpoch)
    if not profile or not profile.extensionsEnabled or not epoch
        or epoch<3 or epoch>6 then return 1 end
    -- Field abilities are not battle volatile state: HP and an earlier
    -- battle's suppression do not disable an otherwise valid party holder.
    -- Never roll/bind a new slot or search PC/Day-Care/vault residents here.
    for _,mon in ipairs(game.save.party or {})do
      local view=opts.abilities.view(game,mon,epoch)
      if view.active and (view.id=='FLAME_BODY' or view.id=='MAGMA_ARMOR')then
        return 2
      end
    end
    return 1
  end
  mod.content.move_effects:patch('HEAL_EFFECT',{kascHatchAbilityOwner67=M.OWNER})
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='ability-binding-and-daycare-step-owner',
      providerStatus='gen3-6-party-hatch-assistance',
      buildReceiptId='docs/WAVE_W_ABILITIES_20260908.md',
      rollbackReceiptId='docs/WAVE_W_ABILITIES_20260908.md'})
  end
  return M
end
