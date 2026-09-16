-- Dragon Cheer targets an adjacent ALLY, never the caster or opponent.
-- The native KASC host is singles-only: no valid ally means ordinary failure.
-- Register the genuine move for learning/evolution, not a Focus Energy alias.
return function(mod,opts)
  local M={CARD_ID='KASC-WAVE1-DRAGON-CHEER',OWNER='kasc.dragon-cheer-singles/v1'}
  local id='DRAGON_CHEER'
  local row=assert(opts.facts.move(id,9))
  assert(row.number==913 and row.generation==9 and row.type=='DRAGON'
    and row.category=='status' and row.power==0 and row.pp==15 and row.target==15
    and row.priority==0,'Dragon Cheer source drift')
  if mod.content.moves:get(id) then M.preserved=true;return M end
  local anim=mod.content.battle_anims:get('FOCUS_ENERGY')
  local reference=mod.content.moves:get('FOCUS_ENERGY')
  assert(anim and reference,'Dragon Cheer native animation dependency missing')
  local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  mod.content.battle_anims:register(id,copy(anim))
  mod.content.move_effects:register('KA_DRAGON_CHEER_SINGLES',{
    kind='primary',accuracyChecked=false,
    run=function(ctx)
      -- Fails before a success animation. No ally targeting exists in this
      -- host; in particular do not buff the enemy passed as ctx.target.
      return {ctx.battle:romText('_ButItFailedText','But, it failed!')}
    end,
  })
  mod.content.moves:register(id,{
    id=id,name=opts.i18n.text(row.names.en,row.names.de),type=row.type,
    category=row.category,power=0,pp=row.pp,accuracy=100,priority=0,
    effect='KA_DRAGON_CHEER_SINGLES',anim=copy(reference.anim),
    originGeneration=9,backendMoveOwner=M.OWNER,backendMoveNumber=913,
    backendLearnsetRevision=4,
  })
  M.registered=true;return M
end
