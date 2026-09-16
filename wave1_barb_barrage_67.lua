-- Modern Barb Barrage: source #839, not the Legends action-style variant.
return function(mod,opts)
  local M={CARD_ID='KASC-WAVE1-BARB-BARRAGE',OWNER='kasc.barb-barrage/v1',pending={}}
  local id,effect='BARB_BARRAGE','KA_BARB_BARRAGE'
  local row=assert(opts.facts.move(id,9))
  assert(row.number==839 and row.generation==8 and row.type=='POISON'
    and row.category=='physical' and row.power==60 and row.accuracy==100
    and row.pp==10 and row.priority==0 and row.target==10,
    'Barb Barrage source drift')
  -- PokeAPI has no effect metadata for #839. The pinned Showdown move
  -- supplies both the 50% poison chance and the poisoned-target modifier.
  if mod.content.moves:get(id) then M.preserved=true;return M end
  local anims=mod.content.battle_anims
  local anim=anims and anims:get('POISON_STING')
  local reference=mod.content.moves:get('POISON_STING')
  if not anim or not reference or anims:get(id) or mod.content.move_effects:get(effect) then
    M.pending[1]='native_dependency_or_owner';return M
  end
  local function copy(v)
    if type(v)~='table' then return v end
    local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r
  end
  mod.content.move_effects:register(effect,{
    kind='secondary',
    chooseDamage=function(ctx)
      -- Copy this hit's move, never double the shared catalog or final damage.
      local move=copy(ctx.move)
      if ctx.target.mon.status=='PSN' then move.power=move.power*2 end
      return ctx.battle:computeDamage(ctx.user,ctx.target,move,{rng=ctx.rng})
    end,
    run=function(ctx)
      if ctx.target.substituteHP or ctx.brokeSub or ctx.target.mon.hp<=0
          or ctx.target.mon.status then return {} end
      local abilities=mod.exports and mod.exports.pokemonAbilityEffects67
      local chance=abilities and abilities.secondaryChance(ctx,50) or 50
      if ctx.rng(1,100)>chance then return {} end
      return ctx.inflict(ctx.target,'PSN',{
        source=id,moveType='POISON',secondary=true})
    end,
  })
  -- Existing native projectile art preserves engine timing/sound/positions.
  -- A visual approval of this composition is tracked separately.
  anims:register(id,copy(anim))
  mod.content.moves:register(id,{
    id=id,name=opts.i18n.text(row.names.en,row.names.de),type=row.type,
    category=row.category,power=row.power,accuracy=row.accuracy,pp=row.pp,
    priority=0,contact=false,effect=effect,anim=copy(reference.anim),
    originGeneration=8,backendMoveOwner=M.OWNER,backendMoveNumber=839,
    backendLearnsetRevision=4,
  })
  M.registered=true;return M
end
