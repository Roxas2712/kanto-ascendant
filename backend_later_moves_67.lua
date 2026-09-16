-- Individually reviewed later-era moves, not a blanket generic-damage import.
-- Identity/properties come from pinned PokeAPI; effect review additionally
-- uses Showdown 6b4bc34e44cc2541929cc4b8fff96e756ab3f268/data/moves.ts.
return function(mod,opts)
  local facts=assert(opts.facts)
  local M={CARD_ID='KASC-67-LATER-MOVE-EFFECTS',
    OWNER='kasc.later-move-effects/v1',registered={},preserved={},pending={}}
  local reviewed={
    {id='BRUTAL_SWING',number=693,origin=7,type='DARK',power=60,
      accuracy=100,pp=20,animation='COMET_PUNCH',parts={'COMET_PUNCH','NIGHT_SHADE'},
      contact=true,target=9,revision=8},
    {id='CLANGING_SCALES',number=691,origin=7,type='DRAGON',category='special',power=110,
      accuracy=100,pp=5,animation='SCREECH',parts={'SCREECH','DRAGON_RAGE'},
      contact=false,target=11,sound=true,bypassSub=true,selfStat='defense',statId=3,delta=-1,revision=8},
    {id='FIRE_LASH',number=680,origin=7,type='FIRE',power=80,
      accuracy=100,pp=15,animation='FIRE_PUNCH',parts={'VINE_WHIP','FIRE_PUNCH'},
      contact=true,effect='DEFENSE_DOWN_SIDE_EFFECT',stat='defense',statId=3,chance=100,revision=7},
    {id='TROP_KICK',number=688,origin=7,type='GRASS',power=70,
      accuracy=100,pp=15,animation='MEGA_KICK',parts={'RAZOR_LEAF','MEGA_KICK'},
      contact=true,effect='ATTACK_DOWN_SIDE_EFFECT',stat='attack',statId=2,chance=100,revision=7},
    {id='ICE_HAMMER',number=665,origin=7,type='ICE',power=100,
      accuracy=90,pp=10,animation='ICE_PUNCH',parts={'ICE_PUNCH','SLAM'},
      contact=true,punch=true,selfStat='speed',statId=6,delta=-1,revision=7},
    {id='FLEUR_CANNON',number=705,origin=7,type='FAIRY',category='special',power=130,
      accuracy=90,pp=5,animation='RAZOR_LEAF',parts={'RAZOR_LEAF','HYPER_BEAM'},
      contact=false,selfStat='specialAttack',statId=4,delta=-2,revision=7},
    {id='PRISMATIC_LASER',number=711,origin=7,type='PSYCHIC_TYPE',category='special',power=160,
      accuracy=100,pp=10,animation='PSYBEAM',parts={'PSYBEAM','HYPER_BEAM'},
      contact=false,recharge=true,revision=7},
    {id='LIQUIDATION',number=710,origin=7,type='WATER',power=85,
      accuracy=100,pp=10,animation='WATER_GUN',parts={'WATER_GUN','SLAM'},
      contact=true,effect='DEFENSE_DOWN_SIDE_EFFECT',stat='defense',statId=3,chance=20,revision=5},
    {id='LUNGE',number=679,origin=7,type='BUG',power=80,
      accuracy=100,pp=15,animation='LEECH_LIFE',parts={'QUICK_ATTACK','LEECH_LIFE'},
      contact=true,effect='ATTACK_DOWN_SIDE_EFFECT',stat='attack',statId=2,chance=100,revision=5},
    {id='SHADOW_BONE',number=708,origin=7,type='GHOST',power=85,
      accuracy=100,pp=10,animation='BONE_CLUB',parts={'NIGHT_SHADE','BONE_CLUB'},
      contact=false,effect='DEFENSE_DOWN_SIDE_EFFECT',stat='defense',statId=3,chance=20,revision=5},
    {id='ZING_ZAP',number=716,origin=7,type='ELECTRIC',power=80,
      accuracy=100,pp=10,animation='THUNDERSHOCK',parts={'TACKLE','THUNDERSHOCK'},
      contact=true,effect='FLINCH_SIDE_EFFECT2',flinch=30,revision=4},
    {id='FLOATY_FALL',number=731,origin=7,type='FLYING',power=90,
      accuracy=95,pp=15,animation='WING_ATTACK',parts={'QUICK_ATTACK','WING_ATTACK'},
      contact=true,effect='FLINCH_SIDE_EFFECT2',flinch=30,revision=4},
    {id='JUDGMENT',number=449,origin=4,type='NORMAL',category='special',power=100,
      accuracy=100,pp=10,animation='SWIFT',parts={'SWIFT','PSYBEAM'},
      contact=false,revision=2},
    {id='MULTI_ATTACK',number=718,origin=7,type='NORMAL',power=90,
      accuracy=100,pp=10,animation='SLASH',parts={'QUICK_ATTACK','SLASH'},
      contact=true,revision=2},
    {id='REVELATION_DANCE',number=686,origin=7,type='NORMAL',category='special',power=90,
      accuracy=100,pp=15,animation='PETAL_DANCE',parts={'SWORDS_DANCE','SWIFT'},
      contact=false,revision=2},
    {id='SOLAR_BLADE',number=669,origin=7,type='GRASS',power=125,
      accuracy=100,pp=10,animation='SLASH',parts={'RAZOR_LEAF','SLASH'},
      contact=true,slicing=true,effect='CHARGE_EFFECT',revision=2},
    {id='HIGH_HORSEPOWER',number=667,origin=7,type='GROUND',power=95,
      accuracy=95,pp=10,animation='STOMP',contact=true},
    {id='LEAFAGE',number=670,origin=7,type='GRASS',power=40,
      accuracy=100,pp=40,animation='RAZOR_LEAF',contact=false},
    {id='DRAGON_HAMMER',number=692,origin=7,type='DRAGON',power=90,
      accuracy=100,pp=15,animation='SLAM',contact=true},
    {id='BRANCH_POKE',number=785,origin=8,type='GRASS',power=40,
      accuracy=100,pp=40,animation='VINE_WHIP',contact=true},
    {id='SMART_STRIKE',number=684,origin=7,type='STEEL',power=70,
      accuracy=100,pp=10,animation='HORN_ATTACK',contact=true,certain=true,revision=3},
    {id='FALSE_SURRENDER',number=793,origin=8,type='DARK',power=80,
      accuracy=100,pp=10,animation='POUND',parts={'QUICK_ATTACK','POUND'},
      contact=true,certain=true,revision=3},
    {id='KOWTOW_CLEAVE',number=869,origin=9,type='DARK',power=85,
      accuracy=100,pp=10,animation='SLASH',contact=true,certain=true,slicing=true,revision=3},
    {id='ACCELEROCK',number=709,origin=7,type='ROCK',power=40,
      accuracy=100,pp=20,animation='ROCK_THROW',parts={'QUICK_ATTACK','ROCK_THROW'},
      contact=true,priority=1,revision=3},
    {id='JET_PUNCH',number=857,origin=9,type='WATER',power=60,
      accuracy=100,pp=15,animation='MEGA_PUNCH',parts={'WATER_GUN','MEGA_PUNCH'},
      contact=true,priority=1,punch=true,revision=3},
  }
  local function copy(v)
    if type(v)~='table' then return v end
    local out={};for k,x in pairs(v)do out[k]=copy(x)end;return out
  end
  -- Compose existing native art, not foreign browser/GBA animation bytecode.
  -- Full sequences retain their own sound, timing and position restoration.
  -- No move data/effect is borrowed from these visual components.
  local function animationFor(review,anims)
    if not anims then return nil end
    local result={seq={}}
    for _,id in ipairs(review.parts or {review.animation})do
      local part=anims:get(id)
      if not (part and type(part.seq)=='table' and #part.seq>0) then return nil end
      for _,row in ipairs(part.seq)do result.seq[#result.seq+1]=copy(row) end
    end
    return result
  end
  M.animationReview={cardId='KASC-67-MOVE-ANIMATIONS',
    status='native-composition-needs-visual-review',moves={}}
  for _,review in ipairs(reviewed)do
    local row=assert(facts.move(review.id,review.origin))
    assert(row.number==review.number and row.generation==review.origin
      and row.type==review.type and row.category==(review.category or 'physical')
      and row.power==review.power and row.accuracy==review.accuracy
      and row.pp==review.pp and row.priority==(review.priority or 0) and row.target==(review.target or 10)
      and row.alwaysHits==(review.certain==true),
      'reviewed later move/source drift: '..review.id)
    if review.flinch then
      assert(row.meta and row.meta.flinch_chance==review.flinch,
        'reviewed flinch/source drift: '..review.id)
    end
    if review.stat then
      assert(row.meta and row.meta.stat_chance==review.chance and #row.statChanges==1
        and row.statChanges[1][1]==review.statId and row.statChanges[1][2]==-1,
        'reviewed secondary/source drift: '..review.id)
    end
    if review.selfStat then
      assert(row.meta and row.meta.meta_category_id==7 and #row.statChanges==1
        and row.statChanges[1][1]==review.statId and row.statChanges[1][2]==review.delta,
        'reviewed self-drop/source drift: '..review.id)
    end
    if review.recharge then assert(row.effect==81,'reviewed recharge/source drift: '..review.id)end
    local alias=mod.content.moves:get(review.animation)
    local anims=mod.content.battle_anims
    local animation=animationFor(review,anims)
    if mod.content.moves:get(review.id) then
      M.preserved[#M.preserved+1]=review.id
    elseif not alias or not mod.content.move_effects:get(review.effect or 'NO_ADDITIONAL_EFFECT')
        or not animation then
      -- Partial imports/minimal registries must still load the rest of KASC.
      -- Do not offer a move whose damage/animation dependency is absent.
      M.pending[review.id]='missing_native_dependency'
    else
      local effect=review.effect or 'NO_ADDITIONAL_EFFECT'
      if review.stat then
        -- Own the modern move's exact chance even for an authorized gift in
        -- an older profile; never borrow the native Gen-I 10%/byte roll.
        effect='KA_LATER_STAT_67_'..review.id
        mod.content.move_effects:register(effect,{kind='secondary',run=function(ctx)
          local target=ctx.target
          if not target or target.mon.hp<=0 or target.substituteHP or ctx.brokeSub then return {} end
          local ex=mod.exports or {}
          local abilities=ex.pokemonAbilityEffects67
          local chance=abilities and abilities.secondaryChance(ctx,review.chance) or review.chance
          if ctx.rng(1,100)>chance then return {} end
          local split=ex.backendSplitSpecial67
          if split then return split.changeStage(ctx,target,review.stat,-1,true) end
          return ctx.changeStage(target,review.stat,-1,true)
        end})
      elseif review.selfStat or review.recharge then
        effect='KA_LATER_AFTER_HIT_67_'..review.id
        mod.content.move_effects:register(effect,{kind='full',afterDamage=function(ctx)
          -- Reached only after a hit, including a broken Substitute, KO or
          -- Endure at one HP. Not a target secondary: Shield Dust/Sheer Force
          -- must not erase the user's drawback. The native pipeline skips
          -- this callback on misses, immunities and protection.
          if not ctx.user or ctx.user.mon.hp<=0 then return end
          if review.recharge then ctx.user.mustRecharge=true;return end
          local split=mod.exports and mod.exports.backendSplitSpecial67
          local stat=review.selfStat
          -- A Gen-I ruleset has one Special stat; do not create an inert
          -- specialAttack stage which its native damage never reads.
          if stat=='specialAttack'and not(split and split.epoch(ctx.battle))then stat='special'end
          local messages=split and split.changeStage(ctx,ctx.user,stat,review.delta,false)
            or ctx.changeStage(ctx.user,stat,review.delta,false)
          for _,message in ipairs(messages or{})do ctx.battle:sayNext(message)end
        end})
      end
      if not anims:get(review.id) then
        anims:register(review.id,animation)
      end
      mod.content.moves:register(review.id,{
        id=review.id,name=opts.i18n and opts.i18n.text(row.names.en,row.names.de)
          or row.names.en,type=row.type,category=row.category,
        power=row.power,accuracy=row.accuracy,pp=row.pp,
        effect=effect,anim=copy(alias.anim),
        originGeneration=review.origin,contact=review.contact,
        target=row.target,sound=review.sound,kascBypassSub67=review.bypassSub,
        priority=row.priority,punch=review.punch,slicing=review.slicing,
        backendMoveOwner=M.OWNER,backendMoveNumber=row.number,
        backendLearnsetRevision=review.revision or 2,
      })
      M.registered[#M.registered+1]=review.id
      M.animationReview.moves[review.id]={parts=copy(review.parts or {review.animation}),
        status='native-composition-needs-visual-review'}
    end
  end
  M.reviewed=reviewed
  -- Native battles have one active Pokemon on each side: both adjacent
  -- target classes hit the opposing battler, never party reserves. Retain
  -- the real source target metadata; this is not a doubles implementation.
  -- Clanging Scales originated in VII and always bypasses Substitute, even
  -- when a legitimate gift retains it in an earlier manual profile.
  local Effects=require('src.battle.EffectRegistry')
  function M.runDamaging(original,b,ctx,record)
    local move=ctx and ctx.move
    if not(move and move.backendMoveOwner==M.OWNER and move.kascBypassSub67
        and M.animationReview.moves[move.id])then return original(b,ctx,record)end
    local target=ctx.target;local sub=target and target.substituteHP
    if not sub then return original(b,ctx,record)end
    target.substituteHP=nil
    local result={pcall(original,b,ctx,record)}
    -- Restore even when a downstream hook throws. A KO removes its doll.
    if target.mon.hp>0 then target.substituteHP=sub end
    if not result[1]then error(result[2],0)end
    return unpack(result,2)
  end
  Effects._kascLaterMoves67=M
  if not Effects._kascLaterMovesWrapped67 then
    local original=Effects.runDamaging
    Effects.runDamaging=function(...)return Effects._kascLaterMoves67.runDamaging(original,...)end
    Effects._kascLaterMovesWrapped67=true
  end
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,
      active=true,dependencyStatus='pinned-dual-source-reviewed',
      providerStatus=next(M.pending) and 'native-dependencies-pending'
        or 'reviewed-single-target-certain-priority-moves',
      buildReceiptId='docs/BACKEND_GIFT_MOVESETS_GENERATIONS_20260907.md',
      rollbackReceiptId='docs/NEW_RC_CARD_MATRIX_20260907.md'})
  end
  return M
end
