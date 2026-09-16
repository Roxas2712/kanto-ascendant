-- KASC-67-ABILITY-EFFECTS. Native Gen1-engine adapter; no Gen2 double owner.
-- Effects in this table are implemented, not inferred from catalog presence.
return function(mod,opts)
  local A=assert(opts.abilities)
  local rules=assert(opts.rules)
  local tr=opts.i18n.text
  local immunity={IMMUNITY='PSN',LIMBER='PAR',INSOMNIA='SLP',VITAL_SPIRIT='SLP',
    WATER_VEIL='BRN',MAGMA_ARMOR='FRZ',WATER_BUBBLE='BRN',SWEET_VEIL='SLP'}
  local supported={NATURAL_CURE=true,SPEED_BOOST=true,SHED_SKIN=true,INNER_FOCUS=true,OWN_TEMPO=true}
  supported.BATTLE_ARMOR=true;supported.SHELL_ARMOR=true
  supported.RUN_AWAY=true
  supported.STEADFAST=true
  supported.SERENE_GRACE=true
  supported.SHIELD_DUST=true
  supported.INTIMIDATE=true
  supported.CLEAR_BODY=true;supported.WHITE_SMOKE=true
  supported.HYPER_CUTTER=true;supported.BIG_PECKS=true
  supported.KEEN_EYE=true;supported.TANGLED_FEET=true
  local pinch={OVERGROW='GRASS',BLAZE='FIRE',TORRENT='WATER',SWARM='BUG'}
  for id in pairs(pinch)do supported[id]=true end
  for _,id in ipairs({'HUGE_POWER','PURE_POWER','GUTS','THICK_FAT','MARVEL_SCALE',
      'HUSTLE','COMPOUND_EYES','TECHNICIAN','TOXIC_BOOST','FLARE_BOOST'})do supported[id]=true end
  for id in pairs(immunity)do supported[id]=true end
  -- Reviewed unchanged VII effects. This is not a blanket generation unlock:
  -- changed effects (e.g. Gale Wings) still require their own era adapter.
  -- In particular Inner Focus/Own Tempo do NOT block Intimidate before VIII.
  local gen7Core={IMMUNITY=true,LIMBER=true,INSOMNIA=true,VITAL_SPIRIT=true,
    WATER_VEIL=true,MAGMA_ARMOR=true,INNER_FOCUS=true,OWN_TEMPO=true,
    STEADFAST=true,BATTLE_ARMOR=true,SHELL_ARMOR=true,RUN_AWAY=true,
    CLEAR_BODY=true,WHITE_SMOKE=true,HYPER_CUTTER=true,BIG_PECKS=true,
    KEEN_EYE=true,INTIMIDATE=true,TANGLED_FEET=true,HUSTLE=true,
    COMPOUND_EYES=true,REGENERATOR=true,NATURAL_CURE=true,SPEED_BOOST=true,
    SHED_SKIN=true,SERENE_GRACE=true,SHIELD_DUST=true}
  local gen7Power={TECHNICIAN=true,TOXIC_BOOST=true,FLARE_BOOST=true}
  local gen7Contact={STATIC=true,FLAME_BODY=true,POISON_POINT=true,EFFECT_SPORE=true,
    STAMINA=true,WEAK_ARMOR=true,ROUGH_SKIN=true,IRON_BARBS=true,CUTE_CHARM=true,
    JUSTIFIED=true,RATTLED=true,ANGER_POINT=true,AFTERMATH=true,DAMP=true,
    MOXIE=true,BEAST_BOOST=true,POISON_TOUCH=true,WATER_COMPACTION=true,GOOEY=true,TANGLING_HAIR=true,
    INNARDS_OUT=true,COLOR_CHANGE=true,STENCH=true,BERSERK=true,CURSED_BODY=true,MUMMY=true}
  local gen7FinalDamage={ADAPTABILITY=true,SNIPER=true,TINTED_LENS=true,
    FILTER=true,SOLID_ROCK=true,MULTISCALE=true}
  local statModifiers={HUGE_POWER=true,PURE_POWER=true,GUTS=true,HUSTLE=true,
    THICK_FAT=true,MARVEL_SCALE=true,OVERGROW=true,BLAZE=true,TORRENT=true,SWARM=true}
  local traits={IRON_FIST={gen=4,flag='punch',modifier=4915},
    TRACE={gen=3},FLOWER_VEIL={gen=6},SLOW_START={gen=4},TRUANT={gen=3},BAD_DREAMS={gen=4},SOUL_HEART={gen=7},CORROSION={gen=7},
    GRASS_PELT={gen=6,terrain=true},ELECTRIC_SURGE={gen=7,terrain=true},GRASSY_SURGE={gen=7,terrain=true},
    MISTY_SURGE={gen=7,terrain=true},PSYCHIC_SURGE={gen=7,terrain=true},
    MEGA_LAUNCHER={gen=6,flag='pulse',modifier=6144},STRONG_JAW={gen=6,flag='bite',modifier=6144},
    TOUGH_CLAWS={gen=6,flag='contact',modifier=5325},
    STEELWORKER={gen=7},FUR_COAT={gen=6},RECKLESS={gen=4,flag='recoil',modifier=4915},
    DEFEATIST={gen=5},RIVALRY={gen=4},UNAWARE={gen=4},
    SHEER_FORCE={gen=5,flag='sheer',modifier=5325},
    FLUFFY={gen=7},WATER_BUBBLE={gen=7},PRISM_ARMOR={gen=7},SHADOW_SHIELD={gen=7},
    NO_GUARD={gen=4},WONDER_SKIN={gen=5},SWEET_VEIL={gen=6},LONG_REACH={gen=7},
    DARK_AURA={gen=6},FAIRY_AURA={gen=6},AURA_BREAK={gen=6},MOODY={gen=5},INFILTRATOR={gen=5},
    HEATPROOF={gen=4},VICTORY_STAR={gen=5},MERCILESS={gen=7},FULL_METAL_BODY={gen=7},SCRAPPY={gen=4},
    PROTEAN={gen=6,conversion=true},ANALYTIC={gen=5},STAKEOUT={gen=7},MAGIC_GUARD={gen=4},NORMALIZE={gen=4,conversion=true},PIXILATE={gen=6,conversion=true},AERILATE={gen=6,conversion=true},
    REFRIGERATE={gen=6,conversion=true},GALVANIZE={gen=7,conversion=true},LIQUID_VOICE={gen=7,conversion=true}}
  local moveTraits={}
  if opts.facts and opts.species then
    for id,row in pairs(opts.facts.data.moves)do
      local flags={};for _,key in ipairs(row.flags or {})do flags[key]=true end
      flags.target=row.target
      flags.recoil=id~='STRUGGLE' and ((row.meta and row.meta.drain or 0)<0
        or id=='JUMP_KICK' or id=='HIGH_JUMP_KICK' or id=='HI_JUMP_KICK')
      local meta=row.meta or {};local positive=false
      for _,change in ipairs(row.statChanges or {})do if change[2]>0 then positive=true end end
      flags.sheer=(meta.ailment_chance or 0)>0 or (meta.flinch_chance or 0)>0
        or (meta.stat_chance or 0)>0 and (meta.meta_category_id~=7 or positive)
        -- PokeAPI's ailment/stat buckets omit these source-confirmed
        -- guaranteed trapping/burn-curing secondaries; all qualify for Sheer Force.
        or id=='ANCHOR_SHOT'or id=='SPIRIT_SHACKLE'or id=='SPARKLING_ARIA'
      -- Sappy Seed is a primary on-hit effect; Gen-VII Zippy Zap has no
      -- secondary (the current catalog's evasion boost belongs to VIII+).
      if id=='SAPPY_SEED'or id=='ZIPPY_ZAP'then flags.sheer=false end
      for _,alias in ipairs(opts.species.moveIds(id))do moveTraits[alias]=flags end
      moveTraits[id]=flags
    end
  end
  local M={CARD_ID='KASC-67-ABILITY-EFFECTS',owner='kasc.ability-effects/v1'}
  local moveFrames=setmetatable({},{__mode='k'})
  local breakers={MOLD_BREAKER=4,TERAVOLT=5,TURBOBLAZE=5}
  -- Pinned simulator breakable flags, restricted to abilities which exist
  -- by VII. Retaliation, Pressure, Prism Armor and Shadow Shield are NOT
  -- in this set. Their effects survive Mold Breaker.
  local breakable={}
  for id in ('AROMA_VEIL AURA_BREAK BATTLE_ARMOR BIG_PECKS BULLETPROOF CLEAR_BODY CONTRARY DAMP DAZZLING DISGUISE DRY_SKIN FILTER FLASH_FIRE FLOWER_GIFT FLOWER_VEIL FLUFFY FRIEND_GUARD FUR_COAT GRASS_PELT HEATPROOF HEAVY_METAL HYPER_CUTTER IMMUNITY INNER_FOCUS INSOMNIA KEEN_EYE LEAF_GUARD LEVITATE LIGHT_METAL LIGHTNING_ROD LIMBER MAGIC_BOUNCE MAGMA_ARMOR MARVEL_SCALE MOTOR_DRIVE MULTISCALE OBLIVIOUS OVERCOAT OWN_TEMPO QUEENLY_MAJESTY SAND_VEIL SAP_SIPPER SHELL_ARMOR SHIELD_DUST SIMPLE SNOW_CLOAK SOLID_ROCK SOUNDPROOF STICKY_HOLD STORM_DRAIN STURDY SUCTION_CUPS SWEET_VEIL TANGLED_FEET TELEPATHY THICK_FAT UNAWARE VITAL_SPIRIT VOLT_ABSORB WATER_ABSORB WATER_BUBBLE WATER_VEIL WHITE_SMOKE WONDER_GUARD WONDER_SKIN'):gmatch('%S+')do breakable[id]=true end
  local entries=setmetatable({},{__mode='k'})
  local pendingSignals=setmetatable({},{__mode='k'})
  local entrySignals={FRISK=true,DOWNLOAD=true,ANTICIPATION=true,FOREWARN=true}
  -- A native switch replaces the battler, not its saved party Pokemon.
  -- Guard the outgoing object so replayed notifications cannot heal twice.
  -- No temporal token is needed: the switch and HP write are synchronous.
  local departed=setmetatable({},{__mode='k'})
  -- The outgoing battler may still be inspected by withdrawal callbacks.
  -- Current sides use serialized tokens; only detached old objects use this
  -- weak map. Re-entering with a new battler always gets its original slot.
  local departedAbilities=setmetatable({},{__mode='k'})
  local overrideNames={MUMMY={en='Mummy',de='Mumie'}}
  for _,row in pairs(opts.facts and opts.facts.data.abilities or{})do
    if row.generation<=7 then overrideNames[row.id]=row.names end
  end
  local traceExcluded={TRACE=true,FORECAST=true,FLOWER_GIFT=true,ILLUSION=true,
    IMPOSTER=true,MULTITYPE=true,ZEN_MODE=true,STANCE_CHANGE=true,POWER_CONSTRUCT=true,
    BATTLE_BOND=true,DISGUISE=true,SCHOOLING=true,COMATOSE=true,SHIELDS_DOWN=true,
    RKS_SYSTEM=true,RECEIVER=true,POWER_OF_ALCHEMY=true}
  local mummyProtected={MULTITYPE=true,STANCE_CHANGE=true,BATTLE_BOND=true,
    COMATOSE=true,DISGUISE=true,POWER_CONSTRUCT=true,RKS_SYSTEM=true,
    SCHOOLING=true,SHIELDS_DOWN=true}
  -- The weak map only deduplicates entry callbacks for live battler objects.
  -- Temporal state used after resume belongs to native checkpoint tokens.
  local function state(b)
    b.field=b.field or {};b.field.tokens=b.field.tokens or {}
    b.field.tokens[M.owner]=b.field.tokens[M.owner] or {entered={}}
    return b.field.tokens[M.owner]
  end
  local function side(b,who)
    return who==b.player and 'player' or who==b.enemy and 'enemy' or nil
  end
  function M.validateCheckpoint(b)
    local row=b.field and b.field.tokens and b.field.tokens[M.owner]
    if row==nil then return true end
    local function turn(value)
      return type(value)=='number' and value%1==0 and value>=0 and value<=(b.turnCount or 0)
    end
    if type(row)~='table' or type(row.entered)~='table'
        or row.lastTurn~=nil and (not turn(row.lastTurn) or row.lastTurn<1)then
      return false,'invalid_ability_timeline'
    end
    for key,value in pairs(row.entered)do
      if (key~='player' and key~='enemy') or not turn(value)then return false,'invalid_ability_entry_turn' end
    end
    if row.unburden~=nil then
      if type(row.unburden)~='table'then return false,'invalid_unburden_token'end
      for key,value in pairs(row.unburden)do
        if (key~='player'and key~='enemy')or value~=true then return false,'invalid_unburden_side'end
      end
    end
    if row.overrides~=nil then
      if type(row.overrides)~='table'then return false,'invalid_ability_overrides'end
      for key,id in pairs(row.overrides)do
        if (key~='player'and key~='enemy')or type(id)~='string' or not overrideNames[id]
            or not M.supportsAbility(b.game,id,tonumber(b.kascGenerationRulesReceipt and b.kascGenerationRulesReceipt.activeEpoch)or 7)then
          return false,'invalid_ability_override'
        end
      end
    end
    for _,key in ipairs({'acted','switched','traceStopped'})do
      if row[key]~=nil then
        if type(row[key])~='table'then return false,'invalid_ability_action_timeline'end
        for lane,value in pairs(row[key])do
          if (lane~='player'and lane~='enemy')or value~=true then return false,'invalid_ability_action_side'end
        end
      end
    end
    for _,key in ipairs({'slowStart','truant'})do
      if row[key]~=nil then
        if type(row[key])~='table'then return false,'invalid_ability_round_state'end
        for lane,value in pairs(row[key])do
          if lane~='player'and lane~='enemy'then return false,'invalid_ability_round_side'end
          if key=='truant' and type(value)~='boolean'
              or key=='slowStart' and not(type(value)=='number' and value%1==0 and value>=0 and value<=5)then
            return false,'invalid_ability_round_counter'
          end
        end
      end
    end
    return true
  end
  local function epoch(game,b)
    local receipt=b and b.kascGenerationRulesReceipt
    if receipt then return receipt.mode=='off' and 1 or tonumber(receipt.activeEpoch) or 1 end
    local bucket=game and game.save and game.save.modData
    local st=bucket and bucket[mod.id] and bucket[mod.id][rules.SAVE_KEY]
    if st and st.activeMode=='off' then return 1 end
    return st and st.activeEpoch or 1
  end
  function M.supportsAbility(game,id,gen)
    local ex=mod.exports or{}
    if id=='STENCH'and(gen==3 or gen==4)then
      return ex.pokemonHistoricalField67 and ex.pokemonHistoricalField67.supportsAbility(game,id,gen)or false
    end
    if id=='LIGHTNING_ROD'and(gen==3 or gen==4)or id=='STORM_DRAIN'and gen==4 then
      -- Historical doubles redirection is a genuine singles no-op, not
      -- modern absorption. canAbsorb remains strictly GenV+ for these IDs.
      local h=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
      return h and h.kascAbilityOwner67==M.owner and h.kascTypeAbsorption67=='kasc.type-absorption/v1'or false
    end
    if id=='SURGE_SURFER'or id=='NEUROFORCE'then
      return ex.pokemonLateAbilityPower67 and ex.pokemonLateAbilityPower67.supportsAbility(game,id,gen)or false
    end
    if id=='PRIMORDIAL_SEA'or id=='DESOLATE_LAND'or id=='DELTA_STREAM'then
      return ex.pokemonPrimalWeather67 and ex.pokemonPrimalWeather67.supportsAbility(game,id,gen)or false
    end
    if id=='PARENTAL_BOND'then
      return ex.pokemonParentalBond67 and ex.pokemonParentalBond67.supports(game,id,gen)or false
    end
    if id=='BATTLE_BOND'or id=='POWER_CONSTRUCT'then
      local h=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
      return gen==7 and ex.pokemonBondForms67~=nil and h
        and h.kascAbilityOwner67==M.owner and h.kascBondForms67=='kasc.bond-forms/v1'
        and h.kascHPForms67=='kasc.hp-forms/v1'or false
    end
    if traits[id] and gen<traits[id].gen then return false end
    local record=game and game.data and game.data.move_effects and game.data.move_effects.HEAL_EFFECT
    local survival=game and game.data and game.data.move_effects and game.data.move_effects.OHKO_EFFECT
    local critical=game and game.data and game.data.move_effects and game.data.move_effects.FOCUS_ENERGY_EFFECT
    local recoil=game and game.data and game.data.move_effects and game.data.move_effects.RECOIL_EFFECT
    local rockHead=id=='ROCK_HEAD' and recoil and recoil.kascRockHead67==M.owner
    local berryEffect=(id=='GLUTTONY' and gen>=4 or id=='CHEEK_POUCH' and gen>=6)
      and record and record.kascBerryAbility67==M.owner
      or id=='HARVEST' and gen>=5 and record and record.kascHarvest67=='kasc.consumed-items/v1'
    local oblivious=id=='OBLIVIOUS' and record and record.kascInfatuation67=='kasc.infatuation/v1'
      and (gen<6 or record.kascMoveRestrictions67=='kasc.move-restrictions/v1')
    local imposter=id=='IMPOSTER'and gen>=5 and record and record.kascImposter67=='kasc.imposter/v1'
    local klutz=id=='KLUTZ'and gen>=4 and record and record.kascHeldEffect67=='kasc.held-effect/v1'
    local bounce=id=='MAGIC_BOUNCE'and gen>=5 and record and record.kascMagicBounce67=='kasc.magic-bounce/v1'
    local dancer=id=='DANCER'and gen==7 and record and record.kascDancer67=='kasc.dancer/v1'
    local stance=id=='STANCE_CHANGE'and gen>=6 and record and record.kascStanceChange67=='kasc.stance-change/v1'
    local disguise=id=='DISGUISE'and gen==7 and record and record.kascDisguise67=='kasc.disguise/v1'
    local flower=id=='FLOWER_GIFT'and gen>=4 and record and record.kascFlowerGift67=='kasc.flower-gift/v1'
    local plusMinus=(id=='PLUS'or id=='MINUS')and gen>=3 and gen<=7 and record
      and record.kascPlusMinus67=='kasc.plus-minus/v1'and critical
      and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
    local allyDamage=(id=='BATTERY'and gen==7 or(id=='FRIEND_GUARD'or id=='TELEPATHY')and gen>=5 and gen<=7)
      and record and record.kascAllyDamage67=='kasc.ally-damage/v1'and critical
      and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
    local healer=id=='HEALER'and gen>=5 and gen<=7 and record
      and record.kascHealer67=='kasc.healer/v1'
      and record.kascWeatherOwner67=='kasc.battle-weather/v1'
      and record.kascStatusLifecycle67=='kasc.status-lifecycle/v1'
    local receiver=(id=='RECEIVER'or id=='POWER_OF_ALCHEMY')and gen==7 and record
      and record.kascReceiver67=='kasc.receiver/v1'
    local symbiosis=id=='SYMBIOSIS'and gen>=6 and gen<=7 and record
      and record.kascSymbiosis67=='kasc.symbiosis/v1'
      and record.kascItemTransfer67=='kasc.item-transfer/v1'
      and record.kascHarvest67=='kasc.consumed-items/v1'
    local honey=id=='HONEY_GATHER'and gen>=4 and record and record.kascHoneyGather67=='kasc.honey-gather/v1'
    local illuminate=id=='ILLUMINATE'and gen>=3 and record and record.kascIlluminate67=='kasc.illuminate/v1'
    local illusion=id=='ILLUSION'and gen>=5 and record and record.kascIllusion67=='kasc.illusion/v1'
    local typeItem=(id=='MULTITYPE'and gen>=4 or id=='RKS_SYSTEM'and gen==7)
      and record and record.kascTypeItems67=='kasc.type-items/v1'
      and record.kascHPForms67=='kasc.hp-forms/v1'
    local pickup=id=='PICKUP'and gen>=3 and record and record.kascPickup67=='kasc.pickup/v1'
      and record.kascHarvest67=='kasc.consumed-items/v1'
      and record.kascItemTransfer67=='kasc.item-transfer/v1'
    local hpForm=(id=='ZEN_MODE'and gen>=5 or (id=='SCHOOLING'or id=='SHIELDS_DOWN')and gen==7)
      and record and record.kascHPForms67=='kasc.hp-forms/v1'
    local comatose=id=='COMATOSE'and gen==7 and record
      and record.kascComatose67=='kasc.comatose/v1'
      and record.kascStatusLifecycle67=='kasc.status-lifecycle/v1'
      and record.kascVariablePower67=='kasc.variable-power/v1'
      and record.kascDrainOwner67=='kasc.drain-rules/v1'
      and game.data.move_effects.KA_SLEEP_SNORE_67
      and game.data.move_effects.KA_SLEEP_SNORE_67.kascSleepMoves67=='kasc.sleep-moves/v1'
      and game.data.move_effects.KA_SLEEP_TALK_67
      and game.data.move_effects.KA_SLEEP_TALK_67.kascSleepMoves67=='kasc.sleep-moves/v1'
    local suction=id=='SUCTION_CUPS'and gen>=3 and record and record.kascForcedSwitch67=='kasc.forced-switch/v1'
    local emergency=(id=='WIMP_OUT'or id=='EMERGENCY_EXIT')and gen==7 and record
      and record.kascEmergencyExit67=='kasc.emergency-exit/v1'
      and record.kascForcedSwitch67=='kasc.forced-switch/v1'
      and record.kascBerryAbility67==M.owner
    local aroma=id=='AROMA_VEIL' and gen>=6 and record
      and record.kascInfatuation67=='kasc.infatuation/v1'
      and record.kascMoveRestrictions67=='kasc.move-restrictions/v1'
      and game.data.move_effects.DISABLE_EFFECT
      and game.data.move_effects.DISABLE_EFFECT.kascDisable67=='kasc.disable/v1'
    local ooze=id=='LIQUID_OOZE' and record and record.kascDrainOwner67=='kasc.drain-rules/v1'
      and record.kascPoisonHealOwner67=='kasc.poison-heal-residual/v1'
    local unburden=id=='UNBURDEN' and gen>=4 and opts.held and record
      and record.kascBerryAbility67==M.owner and record.kascWeatherOwner67=='kasc.battle-weather/v1'
      and survival and survival.kascSurvivalOwner67=='kasc.lethal-hit-survival/v1'
    local weight=(id=='HEAVY_METAL'or id=='LIGHT_METAL')and gen>=5 and record
      and record.kascVariablePower67=='kasc.variable-power/v1'
    local levitate=id=='LEVITATE'and record and record.kascGrounding67=='kasc.grounding/v1'
    local trapping=(id=='ARENA_TRAP'or id=='MAGNET_PULL'or id=='SHADOW_TAG')and record
      and record.kascGrounding67=='kasc.grounding/v1'
      and game.data.move_effects.TRAPPING_EFFECT and game.data.move_effects.TRAPPING_EFFECT.kascPartialTrap67=='kasc.partial-trapping/v1'
    local breaker=breakers[id] and gen>=breakers[id] and record and record.kascAbilityBypass67==M.owner
    local unnerve=id=='UNNERVE' and gen>=5 and record and record.kascUnnerve67==M.owner
    local stageEffect=opts.split and (id=='SIMPLE' and gen>=4
      or (id=='CONTRARY' or id=='DEFIANT') and gen>=5 or id=='COMPETITIVE' and gen>=6)
    local entryEffect=entrySignals[id] and gen>=4 and opts.split~=nil and type(opts.held)=='function'
    local multi=game and game.data and game.data.move_effects and game.data.move_effects.ATTACK_TWICE_EFFECT
    local skillLink=id=='SKILL_LINK' and gen>=4 and multi and multi.kascMultihitOwner67=='kasc.multihit/v1'
    local earlyBird=id=='EARLY_BIRD' and record
      and record.kascStatusLifecycle67=='kasc.status-lifecycle/v1'
    local weatherReady=(id=='DROUGHT' or id=='DRIZZLE' or id=='SAND_STREAM' or id=='AIR_LOCK' or id=='CLOUD_NINE'
          or id=='QUICK_FEET' and gen>=4
          or id=='SAND_VEIL' or id=='SNOW_CLOAK' and gen>=4
          or id=='LEAF_GUARD' and gen>=4
          or id=='SWIFT_SWIM' or id=='CHLOROPHYLL' or id=='SAND_RUSH' and gen>=5
          or id=='SAND_FORCE' and gen>=5 and critical
            and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
          or id=='SLUSH_RUSH' and gen==7
          or id=='RAIN_DISH' or id=='ICE_BODY' and gen>=4
          or (id=='SOLAR_POWER' or id=='DRY_SKIN' and record
            and record.kascTypeAbsorption67=='kasc.type-absorption/v1') and gen>=4
            and critical and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
          or id=='HYDRATION' and gen>=4 and record
            and record.kascStatusLifecycle67=='kasc.status-lifecycle/v1'
          or id=='SNOW_WARNING' and gen>=4
          or id=='OVERCOAT' and gen>=5 and record
            and record.kascTypeAbsorption67=='kasc.type-absorption/v1') and record
        and record.kascWeatherOwner67=='kasc.battle-weather/v1'
    local synchronize=id=='SYNCHRONIZE' and record and record.kascSynchronize67=='kasc.synchronize/v1'
    local pressure=id=='PRESSURE' and record and record.kascPressure67=='kasc.pressure/v1'
      and record.kascPPOwner67=='kasc.era-pp/v1'
    local absorption=(id=='SOUNDPROOF' or id=='BULLETPROOF' and gen>=6 or id=='MOTOR_DRIVE' and gen>=4
      or (id=='LIGHTNING_ROD' or id=='STORM_DRAIN' or id=='SAP_SIPPER') and gen>=5)
      and record and record.kascTypeAbsorption67=='kasc.type-absorption/v1'
    local trait=traits[id] and gen>=traits[id].gen and opts.facts and opts.species
      and (not traits[id].terrain or record and record.kascTerrain67=='kasc.terrain/v1')
      and (id~='MEGA_LAUNCHER'or record and record.kascHealingMoves67=='kasc.healing-moves/v1')
      and (not traits[id].conversion or record and record.kascMoveConversion67=='kasc.move-conversion/v1')
      and (id~='MOODY' or opts.split~=nil)
      and (id~='CORROSION'or record and record.kascSynchronize67=='kasc.synchronize/v1')
      and (id~='RIVALRY' or opts.gender~=nil)
      and (id~='SHEER_FORCE' or record and record.kascContactOwner67=='kasc.contact-abilities/v1')
      and critical and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
    local forecast=id=='FORECAST' and record and record.kascForecastOwner67=='kasc.castform-weather/v1'
    local itemTransfer=(id=='STICKY_HOLD' or id=='PICKPOCKET'and gen>=5 or id=='MAGICIAN'and gen>=6)
      and record and record.kascItemTransfer67=='kasc.item-transfer/v1'
    local ready=symbiosis or receiver or healer or allyDamage or plusMinus or typeItem or illusion or illuminate or pickup or honey or flower or disguise or stance or hpForm or dancer or bounce or klutz or comatose or emergency or suction or imposter or aroma or itemTransfer or forecast or trapping or levitate or weight or unburden or ooze or oblivious or berryEffect or breaker or skillLink or entryEffect or stageEffect or rockHead or unnerve or absorption or trait or earlyBird or weatherReady or synchronize or pressure or supported[id]==true or id=='REGENERATOR' and gen>=5
      or (id=='WATER_ABSORB' or id=='VOLT_ABSORB') and record
        and record.kascTypeAbsorption67=='kasc.type-absorption/v1'
      or id=='POISON_HEAL' and gen>=4 and record
      and record.kascPoisonHealOwner67=='kasc.poison-heal-residual/v1'
      or id=='WONDER_GUARD' and record and record.kascWonderGuard67=='kasc.wonder-guard/v1'
      or id=='FLASH_FIRE' and record and record.kascFlashFire67=='kasc.flash-fire/v1'
        and critical and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
      or id=='STURDY' and survival
      and survival.kascSurvivalOwner67=='kasc.lethal-hit-survival/v1'
      or (id=='PRANKSTER' and gen>=5 or id=='GALE_WINGS' and gen>=6 or id=='STALL' and gen>=4
        or (id=='DAZZLING'or id=='QUEENLY_MAJESTY'or id=='TRIAGE')and gen==7)
        and record and record.kascPriorityOwner67=='kasc.priority-abilities/v1'
      or (id=='SUPER_LUCK' or id=='TINTED_LENS') and critical
        and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
      or ((id=='FILTER' or id=='SOLID_ROCK' or id=='ADAPTABILITY' or id=='SNIPER') and gen>=4 or id=='MULTISCALE' and gen>=5)
        and critical and critical.kascCriticalOwner67=='kasc.critical-rules/v1'
      or (id=='STATIC' or id=='FLAME_BODY' or id=='POISON_POINT' or id=='ROUGH_SKIN' or id=='EFFECT_SPORE' or id=='STAMINA'
          or id=='DAMP' or id=='COLOR_CHANGE' or id=='INNARDS_OUT'and gen==7
          or id=='STENCH'and gen>=5 or id=='BERSERK'and gen==7
          or id=='MUMMY'and gen>=5
          or id=='CURSED_BODY'and gen>=5 and game.data.move_effects.DISABLE_EFFECT
            and game.data.move_effects.DISABLE_EFFECT.kascDisable67=='kasc.disable/v1'
          or (id=='AFTERMATH' or id=='ANGER_POINT') and gen>=4
          or (id=='JUSTIFIED' or id=='RATTLED') and gen>=5
          or (id=='MOXIE' or id=='POISON_TOUCH') and gen>=5 or id=='BEAST_BOOST' and gen==7
          or id=='GOOEY'and gen>=6 or (id=='TANGLING_HAIR'or id=='WATER_COMPACTION')and gen==7
          or id=='CUTE_CHARM' and record and record.kascInfatuation67=='kasc.infatuation/v1'
          or (id=='IRON_BARBS' or id=='WEAK_ARMOR') and gen>=5) and record
        and record.kascContactOwner67=='kasc.contact-abilities/v1'
    return record and record.kascAbilityOwner67==M.owner and ready
      and (gen<5 or not statModifiers[id] or critical
        and critical.kascCriticalOwner67=='kasc.critical-rules/v1')
      and gen>=3 and (gen<=6 or gen==7 and (symbiosis or receiver or healer or allyDamage or plusMinus or typeItem or illusion or illuminate or pickup or honey or flower or disguise or stance or hpForm or dancer or bounce or klutz or comatose or emergency or suction or imposter or aroma or itemTransfer or forecast or trapping or levitate or weight or unburden or ooze or oblivious or berryEffect or breaker or skillLink or entryEffect or stageEffect or rockHead or unnerve or absorption or trait or earlyBird or weatherReady or synchronize or pressure or id=='POISON_HEAL'
        or id=='WATER_ABSORB' or id=='VOLT_ABSORB' or id=='FLASH_FIRE'
        or id=='STURDY' or id=='WONDER_GUARD' or gen7Core[id] or gen7Contact[id]
        or (id=='PRANKSTER' or id=='GALE_WINGS' or id=='STALL'or id=='DAZZLING'or id=='QUEENLY_MAJESTY'or id=='TRIAGE') and record.kascPriorityOwner67=='kasc.priority-abilities/v1'
        or (gen7Power[id] or statModifiers[id] or gen7FinalDamage[id] or id=='SUPER_LUCK') and critical
          and critical.kascCriticalOwner67=='kasc.critical-rules/v1')) or false
  end
  local function native(b)
    return b and not b.demo and b.kind~='link' and b.player and b.player.mon
      and b.enemy and b.enemy.mon and epoch(b.game,b)>=3
  end
  local function effectiveView(b,who)
    if not native(b)or not who or not who.mon then return end
    local gen=epoch(b.game,b)
    local v=A.view(b.game,who.mon,gen)
    local key=opts.temporaryAbilityKey and opts.temporaryAbilityKey(b,who)
    if key then
      local slots=opts.facts.abilitySlots(key,gen,false)
      local slot=slots and slots[1]
      if slot then v={id=slot.id,names=slot.names,temporary=true,
        active=M.supportsAbility(b.game,slot.id,gen)}end
    end
    local identity=mod.exports and mod.exports.pokemonBattleIdentity67
    if identity and identity.copiedAbility then
      local copied,present=identity.copiedAbility(b,who)
      if present then
        v={id=copied,names=overrideNames[copied],temporary=true,
          active=copied~=false and M.supportsAbility(b.game,copied,gen)}
      end
    end
    local control=mod.exports and mod.exports.pokemonAbilityControl67
    if control then
      local acquired,present=control.project(b,who)
      if present then
        v={id=acquired,names=overrideNames[acquired],temporary=true,
          active=M.supportsAbility(b.game,acquired,gen)}
      end
    end
    local key=who.mon==b.player.mon and 'player' or who.mon==b.enemy.mon and 'enemy'
    local row=b.field and b.field.tokens and b.field.tokens[M.owner]
    local override=key and row and row.overrides and row.overrides[key]
      or not key and departedAbilities[who.mon]
    if override and M.supportsAbility(b.game,override,gen)then
      v={id=override,names=overrideNames[override],active=true,temporary=true}
    end
    return v
  end
  -- Transform copies the actual ability identity, not suppression or an
  -- unsupported ability's unrelated original slot. Effects still use activeAbility.
  function M.abilityIdentity(b,who)
    local v=effectiveView(b,who);return v and v.id or false
  end
  function M.validCopiedAbility(id)return id==false or type(id)=='string'and overrideNames[id]~=nil end
  local function ability(b,who)
    if not who then return nil end
    local future=mod.exports and mod.exports.pokemonFutureStrikes67
    if future and future.sourceInactive(b,who)then return nil end
    local v=effectiveView(b,who)
    if not v then return end
    local unsuppressible=v.id=='DISGUISE'or v.id=='COMATOSE'or v.id=='SCHOOLING'or v.id=='SHIELDS_DOWN'or v.id=='STANCE_CHANGE'
      or v.id=='POWER_CONSTRUCT'or v.id=='BATTLE_BOND'
      or v.id=='MULTITYPE'or v.id=='RKS_SYSTEM'
      or v.id=='ZEN_MODE'and epoch(b.game,b)>=7
    if who.abilitySuppressed and not unsuppressible then return end
    local control=mod.exports and mod.exports.pokemonAbilityControl67
    if control and control.suppressed(b,who,v.id)then return end
    if v.active then
      local frame=moveFrames[b]
      if frame and frame.bypass and frame.enabled and frame.target and who.mon==frame.target.mon and breakable[v.id]then return end
      return v.id,v
    end
  end
  -- Consumers must use the bound, era-validated slot, never mon.ability alone.
  M.activeAbility=ability
  -- Virtual sleep never writes the saved major status or a sleep counter.
  function M.isAsleep(b,who)
    return who and who.mon and (who.mon.status=='SLP' or ability(b,who)=='COMATOSE')or false
  end
  function M.onStatusCured(b,who)
    local sleep=mod.exports and mod.exports.pokemonComatose67
    if b and sleep and not M.isAsleep(b,who)then sleep.clearNightmare(b,who)end
  end
  -- Shared application boundary, including secondary ability triggers.
  -- This is not a cure: gaining/re-enabling Aroma Veil keeps old volatiles.
  -- Encore/Torment/Heal Block owners can use this same gate when available.
  local mentalEffects={ATTRACT=true,DISABLE=true,ENCORE=true,HEAL_BLOCK=true,TAUNT=true,TORMENT=true}
  function M.blocksMentalEffect(b,who,effect)
    return mentalEffects[effect]==true and ability(b,who)=='AROMA_VEIL'
  end
  function M.overrideAbility(b,who,id,reason)
    if not native(b)or b.result or not who or not who.mon or who.mon.hp<=0
        or not overrideNames[id]or not M.supportsAbility(b.game,id,epoch(b.game,b))then return false end
    local key=side(b,who);if not key then return false end
    local current=ability(b,who)
    if reason=='trace'then
      local gen=epoch(b.game,b)
      if current~='TRACE' or gen>=4 and traceExcluded[id]and not(id=='FLOWER_GIFT'and gen==4)then return false end
    elseif reason=='receiver'then
      local receiver=mod.exports and mod.exports.pokemonReceiver67
      if epoch(b.game,b)~=7 or(current~='RECEIVER'and current~='POWER_OF_ALCHEMY')
          or not receiver or not receiver.canCopy(id)then return false end
    elseif id~='MUMMY'then return false end
    -- Protected identities must remain protected even before their own
    -- special-form implementation is available in the current build.
    local raw=A.view(b.game,who.mon,epoch(b.game,b)).id
    local effective=current or raw
    if effective==id or mummyProtected[effective]
        or effective=='ZEN_MODE'and epoch(b.game,b)>=7 then return false end
    local row=state(b);row.overrides=row.overrides or {};row.overrides[key]=id
    return true
  end
  function M.switchOverride(ev)
    local b,w,old=ev.battle,ev.battler,ev.previous
    if not b or not w or not old or not old.mon or old.mon==w.mon then return end
    local row=b.field and b.field.tokens and b.field.tokens[M.owner];local key=side(b,w)
    departedAbilities[old.mon]=key and row and row.overrides and row.overrides[key]or nil
    if key and row and row.overrides then
      row.overrides[key]=nil
    end
    if key and row and row.traceStopped then row.traceStopped[key]=nil end
  end
  function M.clearActions(ev)
    local b=ev and ev.battle;if not native(b)then return end
    local r=state(b);r.acted={};r.switched={}
    if ev.playerAction and ev.playerAction.special then r.acted.player=true end
  end
  function M.markAction(b,w)
    if not native(b)or b.result or not w or w.mon.hp<=0 then return end
    local key=side(b,w);if not key then return end
    local r=state(b);r.acted=r.acted or{};r.acted[key]=true
  end
  function M.markSwitch(ev)
    local b,w=ev.battle,ev.battler;if not native(b)or not ev.previous then return end
    local key=side(b,w);if not key then return end
    local r=state(b);r.switched=r.switched or{};r.switched[key]=true
    M.markAction(b,w)
  end
  function M.blocksIndirect(b,who,cause)
    -- IV Ooze/crash were move damage, not the later indirect effect source.
    return who and who.mon and who.mon.hp>0 and ability(b,who)=='MAGIC_GUARD'
      and not(epoch(b.game,b)==4 and (cause=='ooze'or cause=='crash'))or false
  end
  local function pack(...)return {n=select('#',...),...}end
  function M.moveScope(b,user,target,enabled,fn,move)
    local future=mod.exports and mod.exports.pokemonFutureStrikes67
    if future and future.striking(b,user,target,move)then return fn()end
    local id=ability(b,user)
    if not target or user==target or not user or not user.mon or user.mon.hp<=0 then return fn()end
    local ng=id=='NO_GUARD' or target.mon and target.mon.hp>0 and ability(b,target)=='NO_GUARD'
    local mt=move and (moveTraits[move.id]or{}).target
    local infiltrate=id=='INFILTRATOR' and move and (move.category~='status'
      or mt==2 or mt==8 or mt==9 or mt==10 or mt==11)
    local scrappy=id=='SCRAPPY'and move and (move.type=='NORMAL'or move.type=='FIGHTING')
      and move.category~='status'
    local moves=mod.exports and mod.exports.pokemonAbilityBypassMoves67
    local moveBypass=moves and moves.bypasses(b,move)or false
    if not breakers[id] and not moveBypass and not ng and not infiltrate and not scrappy then return fn()end
    local previous=moveFrames[b];local invulnerable=target.invulnerable
    local frame={user=user,target=target,enabled=enabled,bypass=breakers[id]~=nil or moveBypass,noGuard=ng}
    if scrappy then
      frame.originalTypes=target.curTypes;frame.types={}
      for _,typ in ipairs(target.curTypes or{})do if typ~='GHOST'then frame.types[#frame.types+1]=typ end end
    end
    if infiltrate then
      frame.protection={}
      for _,key in ipairs({'reflect','lightScreen','mist','safeguard'})do
        if target[key]~=nil then frame.protection[key]=target[key]end
      end
      if epoch(b.game,b)>=6 and target.substituteHP~=nil then frame.protection.substituteHP=target.substituteHP end
    end
    moveFrames[b]=frame
    if enabled then M.enableMoveFrame(b,user,target)end
    local result=pack(pcall(fn));moveFrames[b]=previous
    if ng and target.invulnerable==false then target.invulnerable=invulnerable end
    if frame.types and target.curTypes==frame.types then target.curTypes=frame.originalTypes end
    for key,value in pairs(frame.protection or{})do
      if target[key]==nil then target[key]=value end
    end
    if not result[1]then error(result[2],0)end
    return unpack(result,2,result.n)
  end
  function M.sheerForce(b,who,move)
    return who and who.mon and who.mon.hp>0 and ability(b,who)=='SHEER_FORCE'
      and move and (moveTraits[move.id]or{}).sheer or false
  end
  function M.blocksBerry(b,who)
    local foe=b and (who==b.player and b.enemy or who==b.enemy and b.player)
    return foe and foe.mon and foe.mon.hp>0 and ability(b,foe)=='UNNERVE' or false
  end
  function M.onItemLost(b,who,consumed,deferDonation)
    local harvest=mod.exports and mod.exports.pokemonHarvest67
    if harvest then harvest.remember(b,who,consumed)end
    if who and who.mon and who.mon.hp>0 and ability(b,who)=='UNBURDEN' and not opts.held(who.mon)then
      local key=side(b,who)
      if key then local row=state(b);row.unburden=row.unburden or {};row.unburden[key]=true end
    end
    if not deferDonation then M.afterItemConsumed(b,who,consumed)end
  end
  function M.afterItemConsumed(b,who,id)
    local symbiosis=mod.exports and mod.exports.pokemonSymbiosis67
    if symbiosis then symbiosis.afterConsumption(b,who,id)end
  end
  function M.clearItemLoss(b,who)
    local row=b and b.field and b.field.tokens and b.field.tokens[M.owner]
    if row and row.unburden then local key=side(b,who);if key then row.unburden[key]=nil end end
  end
  function M.syncItemLoss(ev)
    local b=ev and ev.battle;if not native(b)then return end
    for _,w in ipairs({b.player,b.enemy})do if ability(b,w)~='UNBURDEN'then M.clearItemLoss(b,w)end end
  end
  function M.speedFactor(b,who)
    local row=b and b.field and b.field.tokens and b.field.tokens[M.owner]
    local key=who and side(b,who)
    if row and row.unburden and row.unburden[key] and who.mon.hp>0
        and ability(b,who)=='UNBURDEN' and not opts.held(who.mon)then return 2 end
    if M.slowStartActive(b,who)then return 0.5 end
    return 1
  end
  function M.slowStartActive(b,who)
    if not who or not who.mon or who.mon.hp<=0 or ability(b,who)~='SLOW_START'then return false end
    local row=b.field and b.field.tokens and b.field.tokens[M.owner]
    -- Damage owners may use detached battler views, preserving mon identity.
    local key=who.mon==b.player.mon and 'player' or who.mon==b.enemy.mon and 'enemy'
    local left=row and row.slowStart and row.slowStart[key]
    return left==nil or left>0
  end
  function M.onBerry(b,who,id)
    M.onItemLost(b,who,id,true)
    if who and who.mon and who.mon.hp>0 and ability(b,who)=='CHEEK_POUCH'
        and not(mod.exports.pokemonHealBlock67 and mod.exports.pokemonHealBlock67.blocksRecovery(b,who,'ability'))then
      who.mon.hp=math.min(who.mon.stats.hp,who.mon.hp+math.max(1,math.floor(who.mon.stats.hp/3)))
      b:sayNext(tr('Cheek Pouch restores HP!','Backentaschen heilen KP!'));b:drainNext(who,who.mon.hp)
    end
    M.afterItemConsumed(b,who,id)
  end
  -- Only secondary-effect owners call this. Never adjust the shared RNG:
  -- accuracy, criticals, damage, durations and primary moves are independent.
  function M.secondaryChance(ctx,chance,selfTarget)
    if ctx and M.sheerForce(ctx.battle,ctx.user,ctx.move)then return 0 end
    local target=ctx and ctx.target
    if not selfTarget and target and ctx.user~=target and target.mon
        and (tonumber(target.mon.hp) or 0)>0
        and ability(ctx.battle,target)=='SHIELD_DUST' then return 0 end
    local user=ctx and ctx.user
    if user and user.mon and (tonumber(user.mon.hp) or 0)>0
        and ability(ctx.battle,user)=='SERENE_GRACE' then
      return math.min(100,chance*2)
    end
    return chance
  end
  local function message(b,who,id)
    local v=A.view(b.game,who.mon,epoch(b.game,b));local names=overrideNames[id] or v.names or {}
    local name=tr(names.en or id,names.de or id)
    return tr('%s: %s!','%s: %s!'):format(who.name or who.mon.species,name)
  end
  local function say(b,who,id)
    if b.sayNext then b:sayNext(message(b,who,id));b:drainNext()end
  end
  -- Native singles have one active Pokemon on each side. Flower Veil can
  -- protect its holder after a Grass type change; never the opposing side.
  function M.flowerVeil(b,who)
    if ability(b,who)~='FLOWER_VEIL'then return false end
    for _,kind in ipairs(who.curTypes or{})do if kind=='GRASS'then return true end end
    return false
  end
  function M.blockStatDrop(b,who,stat,delta,fromEnemy)
    if not fromEnemy or delta>=0 or not who or not who.mon
        or (tonumber(who.mon.hp) or 0)<=0 then return nil end
    local id=ability(b,who)
    if id=='CLEAR_BODY' or id=='WHITE_SMOKE' or id=='FULL_METAL_BODY'
        or id=='HYPER_CUTTER' and stat=='attack'
        or id=='BIG_PECKS' and stat=='defense'
        or id=='KEEN_EYE' and stat=='accuracy'
        or id=='FLOWER_VEIL' and M.flowerVeil(b,who) then
      return {message(b,who,id),failed=true}
    end
  end
  function M.stageDelta(b,who,delta)
    if not who or not who.mon or who.mon.hp<=0 then return delta end
    local id=ability(b,who)
    if id=='CONTRARY'then return -delta end
    if id=='SIMPLE' and epoch(b.game,b)>=5 then return delta*2 end
    return delta
  end
  function M.afterStage(b,who,stat,before,fromEnemy)
    if not fromEnemy or not who.mon or who.mon.hp<=0 or (who.stages[stat]or 0)>=before then return {}end
    local id=ability(b,who)
    if id~='DEFIANT' and id~='COMPETITIVE'then return {}end
    local effects=require('src.battle.MoveEffects')
    local ctx={battle=b,changeStage=function(w,s,d,f)return effects.changeStage(b,w,s,d,f)end}
    local messages={message(b,who,id)}
    for _,m in ipairs(opts.split.changeStage(ctx,who,id=='DEFIANT' and 'attack' or 'specialAttack',2,false))do
      messages[#messages+1]=m
    end
    return messages
  end
  function M.installStageAdapter(effects)
    effects._kascAbilityStageOwner67=M
    if effects._kascAbilityStageWrapped67 then return end
    local original=assert(effects.changeStage)
    effects.changeStage=function(b,who,stat,delta,fromEnemy)
      local owner=effects._kascAbilityStageOwner67
      if fromEnemy and who.substituteHP then return original(b,who,stat,delta,fromEnemy)end
      delta=owner and owner.stageDelta(b,who,delta)or delta
      local blocked=owner and owner.blockStatDrop(b,who,stat,delta,fromEnemy)
      if blocked then return blocked end
      local before=who.stages[stat]or 0
      local messages=original(b,who,stat,delta,fromEnemy and delta<0)
      if owner then for _,m in ipairs(owner.afterStage(b,who,stat,before,fromEnemy))do messages[#messages+1]=m end end
      return messages
    end
    effects._kascAbilityStageWrapped67=true
  end
  local function cure(who,b)
    who.mon.status=nil;who.sleepTurns=nil;who.toxicCounter=nil;who.nightmare=nil
    M.onStatusCured(b,who)
  end
  function M.blockStatus(b,who,status,options)
    local terrain=mod.exports and mod.exports.pokemonTerrain67
    if terrain and terrain.blocksStatus(b,who,status)then return {tr('The terrain prevents the status!','Das Feld verhindert die Statusveränderung!')}end
    local id=ability(b,who)
    local forms=mod.exports and mod.exports.pokemonHPForms67
    if forms and forms.blocksStatus(b,who)and ({SLP=true,PSN=true,BRN=true,PAR=true,FRZ=true})[status]then
      return {message(b,who,'SHIELDS_DOWN')}
    end
    if id=='COMATOSE'and ({SLP=true,PSN=true,BRN=true,PAR=true,FRZ=true})[status]then
      return {message(b,who,id)}
    end
    if id and immunity[id]==status then return {message(b,who,id)}end
    local source=options and options.kascStatusSource67
    if ({SLP=true,PSN=true,BRN=true,PAR=true,FRZ=true})[status]
        and M.flowerVeil(b,who)
        and (options and options.kascYawnApplication67
          or source and source~=who and options.source~='YAWN')then
      return {message(b,who,'FLOWER_VEIL')}
    end
  end
  function M.blocksFlinch(b,who)
    return ability(b,who)=='INNER_FOCUS'
  end
  -- Felsenfest reacts to actually losing the action, not to setting the
  -- secondary-effect flag. A failed roll, substitute, or an already-acted
  -- target must never receive a speed boost.
  function M.onFlinched(b,who)
    if ability(b,who)~='STEADFAST' or (tonumber(who.mon.hp) or 0)<=0 then return false end
    who.stages=who.stages or {}
    if (who.stages.speed or 0)>=6 then return false end
    who.stages.speed=(who.stages.speed or 0)+1
    who.hazeStatReset=nil
    return message(b,who,'STEADFAST')
  end
  function M.installActionAdapter(status)
    status._kascAbilityActionOwner67=M
    if status._kascAbilityActionWrapped67 then return end
    local beforeMove=assert(status.beforeMove)
    status.beforeMove=function(who,rng,b,...)
      local owner=status._kascAbilityActionOwner67
      local loaf=owner and owner.beforeTruant(b,who)
      if loaf then return false,loaf end
      local flinch=who.flinched and not who.skipMove
      local canMove,messages,selfHit=beforeMove(who,rng,b,...)
      if flinch and not who.flinched and canMove==false and not selfHit then
        local owner=status._kascAbilityActionOwner67
        local notice=owner and owner.onFlinched(b,who)
        if notice then messages=messages or {};messages[#messages+1]=notice end
      end
      return canMove,messages,selfHit
    end
    status._kascAbilityActionWrapped67=true
  end
  function M.beforeTruant(b,who)
    if not native(b)or not who or not who.mon or who.mon.hp<=0 or who.skipMove
        or ability(b,who)~='TRUANT'then return end
    local key=side(b,who);if not key then return end
    local row=state(b);row.truant=row.truant or{}
    local loaf=row.truant[key]==true
    -- III/IV alternate by completed round, V+ by BeforeMove attempts.
    -- The existing status lifecycle runs sleep/freeze before this adapter.
    if epoch(b.game,b)>=5 then row.truant[key]=not loaf end
    if loaf then
      who.flinched=false
      return {message(b,who,'TRUANT'),tr('It is loafing around!','Es faulenzt!')}
    end
  end
  function M.blocksCritical(b,who)
    local id=ability(b,who)
    return id=='BATTLE_ARMOR' or id=='SHELL_ARMOR'
  end
  function M.criticalStageBonus(b,who)
    return who and who.mon and (tonumber(who.mon.hp) or 0)>0
      and ability(b,who)=='SUPER_LUCK' and 1 or 0
  end
  function M.blockConfusion(b,who)
    local terrain=mod.exports and mod.exports.pokemonTerrain67
    if terrain and terrain.blocksConfusion(b,who)then return {tr('Misty Terrain prevents confusion!','Das Nebelfeld verhindert Verwirrung!')}end
    if ability(b,who)=='OWN_TEMPO' then return {message(b,who,'OWN_TEMPO')}end
  end
  function M.cureConfusion(b,who)
    if who and who.confusedTurns and ability(b,who)=='OWN_TEMPO' then
      who.confusedTurns=nil;say(b,who,'OWN_TEMPO');return true
    end
    return false
  end
  function M.onDeparted(event)
    local b=event and event.battle
    local previous=event and event.previous
    local incoming=event and event.battler
    if not native(b) or b.result or not previous or not previous.mon
        or not incoming or not incoming.mon or not side(b,incoming)
        or side(b,previous) or previous.mon==incoming.mon
        or previous.isPlayer~=incoming.isPlayer or departed[previous] then return 0 end
    departed[previous]=true
    if ability(b,previous)~='REGENERATOR' then return 0 end
    local mon=previous.mon
    local hp,max=tonumber(mon.hp),mon.stats and tonumber(mon.stats.hp)
    if not hp or not max or hp<=0 or hp>=max then return 0 end
    local amount=math.min(max-hp,math.max(1,math.floor(max/3)))
    mon.hp=hp+amount
    -- Regenerator restores the withdrawn party member silently. It does not
    -- cure status, emit a hit/heal-item event, or heal on battle completion.
    return amount
  end
  function M.tryTrace(b,who)
    local key=side(b,who)
    if not key or who.mon.hp<=0 or ability(b,who)~='TRACE'then return false end
    local timeline=state(b)
    if timeline.traceStopped and timeline.traceStopped[key]then return false end
    local other=who==b.player and b.enemy or b.player
    if not other or other.mon.hp<=0 then return false end
    local id=ability(b,other)
    if not id then
      if not A.view(b.game,other.mon,epoch(b.game,b)).id then
        timeline.traceStopped=timeline.traceStopped or {};timeline.traceStopped[key]=true
      end
      return false
    end
    if not M.overrideAbility(b,who,id,'trace')then return false end
    timeline.slowStart=timeline.slowStart or {};timeline.truant=timeline.truant or{}
    timeline.slowStart[key]=id=='SLOW_START'and 5 or nil
    timeline.truant[key]=id=='TRUANT'and epoch(b.game,b)==3 and (timeline.entered[key]or 0)>0 or nil
    if who.mon.status and immunity[id]==who.mon.status then cure(who,b)end
    M.cureConfusion(b,who)
    say(b,who,'TRACE');say(b,who,id)
    return true
  end
  function M.entryEffects(b,entered)
    for _,who in ipairs(entered)do
      if entrySignals[ability(b,who)]then pendingSignals[who]=true end
      if epoch(b.game,b)>=4 and ability(b,who)=='PRESSURE' and (tonumber(who.mon.hp) or 0)>0 then
        say(b,who,'PRESSURE')
      end
      if ability(b,who)=='INTIMIDATE' and (tonumber(who.mon.hp) or 0)>0 then
        local target=who==b.player and b.enemy or b.player
        if target and (tonumber(target.mon.hp) or 0)>0 and not target.substituteHP then
          say(b,who,'INTIMIDATE')
          local messages=require('src.battle.MoveEffects').changeStage(b,target,'attack',-1,true)
          if b.sayNext then
            for _,text in ipairs(messages)do b:sayNext(text)end
            b:drainNext()
          end
        end
      end
    end
  end
  function M.updateTrace(ev)
    local b=ev and ev.battle
    if not native(b)or b.result or epoch(b.game,b)<4 then return end
    for _,who in ipairs({b.player,b.enemy})do
      if M.tryTrace(b,who)then
        M.entryEffects(b,{who});M.signals({battle=b,battler=who})
        local weather=mod.exports and mod.exports.pokemonWeather67
        if weather then weather.abilityChanged(b,who)end
        local terrain=mod.exports and mod.exports.pokemonTerrain67
        if terrain then terrain.abilityChanged(b,who)end
      end
    end
  end
  -- Only the ability-control Card's synchronous private proof can prepare
  -- both swapped identities before either gained-ability Start callback.
  M.kascAbilityControl67='kasc.ability-control/v1'
  function M.prepareAbilityControl67(b,who)
    local control=mod.exports and mod.exports.pokemonAbilityControl67
    if not native(b)or b.result or not side(b,who)or not control
        or not select(3,control.pendingChange(b,who))then return false end
    local timeline=state(b)
    if timeline.overrides then timeline.overrides[side(b,who)]=nil end
    return true
  end
  function M.transformedAbilityChanged(b,who,keepOverride)
    if not native(b)or b.result or not side(b,who)then return end
    local control=mod.exports and mod.exports.pokemonAbilityControl67
    local noStart,ownedKeep,present=false,false,false
    if control then noStart,ownedKeep,present=control.pendingChange(b,who)end
    if present then keepOverride=ownedKeep end
    local key=side(b,who);local timeline=state(b)
    if timeline.overrides and not keepOverride then timeline.overrides[key]=nil end
    if timeline.traceStopped then timeline.traceStopped[key]=nil end
    M.clearItemLoss(b,who)
    local id=ability(b,who)
    timeline.slowStart=timeline.slowStart or{};timeline.truant=timeline.truant or{}
    timeline.slowStart[key]=id=='SLOW_START'and 5 or nil
    timeline.truant[key]=id=='TRUANT'and epoch(b.game,b)==3 and (timeline.entered[key]or 0)>0 or nil
    if id and id~='SWEET_VEIL'and who.mon.status and immunity[id]==who.mon.status then cure(who,b);say(b,who,id)end
    M.cureConfusion(b,who)
    if noStart then
      -- Suppression ends an existing primal weather immediately, but must
      -- not replay gained Start. III copies/swaps do not start weather.
      local weather=mod.exports and mod.exports.pokemonWeather67
      if ownedKeep and weather then weather.abilityChanged(b,who)end
      return
    end
    M.tryTrace(b,who)
    M.entryEffects(b,{who});M.signals({battle=b,battler=who})
    local weather=mod.exports and mod.exports.pokemonWeather67
    if weather then weather.abilityChanged(b,who)end
    local terrain=mod.exports and mod.exports.pokemonTerrain67
    if terrain then terrain.abilityChanged(b,who)end
  end
  -- Opening presentation (Illusion) needs the same stable slot before the
  -- native introduction is queued, without running entry effects early.
  function M.bindEntry(b,who)
    if not native(b)or not who or not who.mon then return end
    local mon=who.mon
    if not mon._kascAbility67 and (not who.isPlayer or mon._kascEquipmentHandle)
        and A.key(b.game,mon)then
      local seed=mon._kascEquipmentHandle
      if not seed then seed='encounter:'..mon.species..':'..tostring(b.rng(0,65535))end
      local plan=A.plan(b.game,mon,seed,epoch(b.game,b))
      if plan then for k,v in pairs(plan)do mon[k]=v end end
    end
  end
  function M.entry(event,defer)
    local b=event and event.battle;if not native(b) or b.result then return end
    M.onDeparted(event)
    if event.previous and ability(b,event.previous)=='NATURAL_CURE' then cure(event.previous,b)end
    local rows=event.battler and {event.battler} or {b.player,b.enemy}
    local entered={}
    for _,who in ipairs(rows)do
      if not entries[who]then
        entries[who]=tonumber(b.turnCount) or 0
        entered[#entered+1]=who
        local key=side(b,who)
        if key then state(b).entered[key]=entries[who];M.clearItemLoss(b,who)end
        M.bindEntry(b,who)
        local mon=who.mon
        local id=ability(b,who)
        if key then
          local timeline=state(b)
          timeline.slowStart=timeline.slowStart or{};timeline.truant=timeline.truant or{}
          timeline.slowStart[key]=id=='SLOW_START'and 5 or nil
          if id=='TRUANT'then
            timeline.truant[key]=epoch(b.game,b)==3 and entries[who]>0
          else timeline.truant[key]=nil end
        end
        if id and id~='SWEET_VEIL' and mon.status and immunity[id]==mon.status then cure(who,b);say(b,who,id)end
      end
      M.cureConfusion(b,who)
    end
    -- Bind both opening battlers before Trace or entry effects inspect them.
    if defer then return entered end
    for _,who in ipairs(entered)do M.tryTrace(b,who)end
    M.entryEffects(b,entered)
  end
  local pendingEntries=setmetatable({},{__mode='k'})
  local competingEntry={IMPOSTER=true,TRACE=true,INTIMIDATE=true,PRESSURE=true,
    DRIZZLE=true,DROUGHT=true,SAND_STREAM=true,SNOW_WARNING=true,
    PRIMORDIAL_SEA=true,DESOLATE_LAND=true,DELTA_STREAM=true,
    ELECTRIC_SURGE=true,GRASSY_SURGE=true,MISTY_SURGE=true,PSYCHIC_SURGE=true}
  function M.stageEntry(ev)
    local entered=M.entry(ev,true)
    if entered and #entered>0 then pendingEntries[ev.battle]=entered end
  end
  function M.flushEntry(ev)
    local b=ev and ev.battle;local list=b and pendingEntries[b]
    if not list then return end
    pendingEntries[b]=nil
    if not native(b)or b.result then return end
    local weather=mod.exports.pokemonWeather67;local terrain=mod.exports.pokemonTerrain67
    local function speed(w)return weather and weather.speed(b,w)or require('src.battle.TurnOrder').effectiveSpeed(w)end
    if #list==2 then
      local a,z=speed(list[1]),speed(list[2])
      local x,y=ability(b,list[1]),ability(b,list[2])
      local competing=(competingEntry[x]or entrySignals[x])and(competingEntry[y]or entrySignals[y])
      if a<z or a==z and competing and b.rng(0,1)==1 then list[1],list[2]=list[2],list[1]end
    end
    for _,who in ipairs(list)do
      if who.mon.hp>0 then
        M.tryTrace(b,who)
        local imposter=mod.exports.pokemonImposter67
        local transformed=imposter and imposter.tryEntry(b,who)
        if not transformed then
          M.entryEffects(b,{who});M.signals({battle=b,battler=who})
          if weather then weather.entry({battle=b,battler=who})end
          if terrain then terrain.entry({battle=b,battler=who})end
        end
      end
    end
  end
  function M.signals(event)
    local b=event and event.battle;if not native(b) or b.result then return end
    for _,who in ipairs(event.battler and {event.battler}or {b.player,b.enemy})do
      if pendingSignals[who]then
        pendingSignals[who]=nil
        local foe=who==b.player and b.enemy or b.player
        local id=ability(b,who);local gen=epoch(b.game,b)
        if who.mon.hp>0 and foe and foe.mon.hp>0 and entrySignals[id]then
          if id=='FRISK'then
            local item=opts.held(foe.mon);local def=item and b.data.items[item]
            if def then
              say(b,who,id);b:sayNext(tr('The foe holds %s!','Der Gegner trägt %s!'):format(def.name or item))
            end
          elseif id=='DOWNLOAD'then
            opts.split.prepare(b,foe)
            if gen~=4 or not foe.substituteHP then
              local stats=require('src.pokemon.Stats')
              local defense=stats.applyStage(foe.curStats.defense,foe.stages.defense or 0)
              local special=stats.applyStage(foe.curStats.specialDefense,foe.stages.specialDefense or 0)
              local ctx={battle=b,changeStage=function(w,s,d,f)
                return require('src.battle.MoveEffects').changeStage(b,w,s,d,f)end}
              say(b,who,id)
              for _,m in ipairs(opts.split.changeStage(ctx,who,defense>=special and 'specialAttack' or 'attack',1,false))do b:sayNext(m)end
            end
          else
            local selected,best={},1
            for _,slot in ipairs(foe.curMoves or foe.mon.moves or {})do
              local move=b:moveDef(slot)
              if move and move.category~='status'then
                local mult=require('src.battle.TypeChart').effectiveness(move.type,who.curTypes)
                if id=='ANTICIPATION' and (mult>10 or mult>0 and move.effect=='OHKO_EFFECT')then
                  selected={move};break
                elseif id=='FOREWARN'then
                  local power=move.power or 0
                  if move.effect=='OHKO_EFFECT'then power=gen==4 and 160 or 150
                  elseif move.id=='COUNTER' or move.id=='MIRROR_COAT' or move.id=='METAL_BURST'then power=120
                  elseif power==0 or power==1 then power=80 end
                  if power>best then selected={move};best=power
                  elseif power==best then selected[#selected+1]=move end
                end
              end
            end
            if #selected>0 then
              say(b,who,id)
              if id=='FOREWARN'then
                local move=selected[#selected==1 and 1 or b.rng(1,#selected)]
                b:sayNext(tr('Watch out for %s!','Vorsicht vor %s!'):format(move.name or move.id))
              else b:sayNext(tr('It sensed a dangerous move!','Es spürt eine gefährliche Attacke!'))end
            end
          end
        end
      end
    end
  end
  function M.residual(event)
    local b=event and event.battle;local turn=event and tonumber(event.turn)
    if not native(b) or b.result or not turn or turn<1 or turn%1~=0 then return 0 end
    local timeline=state(b)
    if timeline.lastTurn==turn then return 0 end
    timeline.lastTurn=turn;local n=0
    for _,who in ipairs({b.player,b.enemy})do
      local id=ability(b,who)
      if (tonumber(who.mon.hp) or 0)>0 then
        local key=side(b,who);local gen=epoch(b.game,b)
        if id=='SLOW_START'and timeline.slowStart and (timeline.slowStart[key]or 0)>0
            and (timeline.entered[key]or 0)<turn then
          timeline.slowStart[key]=timeline.slowStart[key]-1
          if timeline.slowStart[key]==0 then say(b,who,id);n=n+1 end
        end
        if id=='TRUANT'and gen<=4 then
          timeline.truant=timeline.truant or{}
          if gen==3 or timeline.truant[key] or (timeline.entered[key]or 0)<turn then
            timeline.truant[key]=not timeline.truant[key]
          end
        end
        if id=='BAD_DREAMS'then
          local target=who==b.player and b.enemy or b.player
          if target and target.mon.hp>0 and M.isAsleep(b,target)
              and not M.blocksIndirect(b,target,'bad_dreams')then
            local sub,bide,rage=target.substituteHP,target.bideTurns,target.rageMove
            target.substituteHP,target.bideTurns,target.rageMove=nil,nil,nil
            say(b,who,id)
            local ok,err=pcall(b.applyDamage,b,target,math.max(1,math.floor(target.mon.stats.hp/8)))
            target.substituteHP,target.bideTurns,target.rageMove=sub,bide,rage
            if not ok then error(err,0)end
            if target.mon.hp<=0 then b:onFaint(target)end
            n=n+1
          end
        end
        if id=='SPEED_BOOST' and (timeline.entered[side(b,who)] or 0)<turn and (who.stages.speed or 0)<6 then
          who.stages.speed=(who.stages.speed or 0)+1;who.hazeStatReset=nil
          say(b,who,id);n=n+1
        elseif id=='SHED_SKIN' and who.mon.status and b.rng(0,99)<33 then
          cure(who,b);say(b,who,id);n=n+1
        elseif id=='MOODY'then
          -- V–VII includes accuracy/evasion. VIII's smaller pool must not
          -- leak backward. Select distinct stats before applying changes.
          local stats={'attack','defense','specialAttack','specialDefense','speed','accuracy','evasion'}
          local up,down={},{}
          for _,s in ipairs(stats)do if (who.stages[s]or 0)<6 then up[#up+1]=s end end
          local raised=#up>0 and up[b.rng(1,#up)]or nil
          for _,s in ipairs(stats)do if s~=raised and (who.stages[s]or 0)>-6 then down[#down+1]=s end end
          local lowered=#down>0 and down[b.rng(1,#down)]or nil
          local ctx={battle=b,changeStage=function(w,s,d,f)
            return require('src.battle.MoveEffects').changeStage(b,w,s,d,f)end}
          if raised or lowered then say(b,who,id);n=n+1 end
          for _,v in ipairs({{raised,2},{lowered,-1}})do if v[1]then
            for _,msg in ipairs(opts.split.changeStage(ctx,who,v[1],v[2],false))do b:sayNext(msg)end
          end end
        end
      end
    end
    return n
  end
  function M.onFainted(event)
    local b,fallen=event and event.battle,event and event.battler
    if not native(b)or b.result or not fallen or not fallen.mon or fallen.mon.hp>0 then return end
    for _,who in ipairs({b.player,b.enemy})do
      if who~=fallen and who.mon.hp>0 and ability(b,who)=='SOUL_HEART'then
        local ctx={battle=b,changeStage=function(w,s,d,f)
          return require('src.battle.MoveEffects').changeStage(b,w,s,d,f)end}
        say(b,who,'SOUL_HEART')
        for _,line in ipairs(opts.split.changeStage(ctx,who,'specialAttack',1,false))do b:sayNext(line)end
      end
    end
  end
  function M.finish(event)
    local b=event and event.battle
    if native(b) then
      for _,who in ipairs({b.player,b.enemy})do
        if ability(b,who)=='NATURAL_CURE' then cure(who,b)end
      end
    end
    if b and b.field and b.field.tokens then b.field.tokens[M.owner]=nil end
  end
  local function copy(v)local r={};for k,x in pairs(v or {})do r[k]=x end;return r end
  local function simpleView(b,who)
    if not who or not who.mon or who.mon.hp<=0 or epoch(b.game,b)~=4 or ability(b,who)~='SIMPLE'then return who end
    local view=copy(who);view.stages={}
    for k,v in pairs(who.stages or {})do view.stages[k]=math.max(-6,math.min(6,v*2))end
    return view
  end
  local function statBattler(who,stat,num,den)
    local r=copy(who);r.curStats=copy(who.curStats)
    r.curStats[stat]=math.max(1,math.floor(r.curStats[stat]*num/den))
    return r
  end
  function M.damage(nextDamage,ctx)
    local b=ctx and ctx.battle
    if not native(b) or not ctx.user or not ctx.target or not ctx.move
        or ctx.opts and ctx.opts.typeless or (tonumber(ctx.move.power) or 0)<=0
        or ctx.move.category=='status' then return nextDamage(ctx)end
    local user,target=ability(b,ctx.user),ability(b,ctx.target)
    -- A calculator/AI preview may still reference the fainted battler.
    -- Do not give it an offensive or defensive ability stat modifier.
    if (tonumber(ctx.user.mon.hp)or 0)<=0 then user=nil end
    if (tonumber(ctx.target.mon.hp)or 0)<=0 then target=nil end
    if not user and not target then return nextDamage(ctx)end
    local adjusted=copy(ctx)
    adjusted.user=simpleView(b,ctx.user);adjusted.target=simpleView(b,ctx.target)
    local function ignoreStages(who,keys)
      local v=copy(who);v.stages=copy(who.stages)
      for _,key in ipairs(keys)do v.stages[key]=0 end
      return v
    end
    if user=='UNAWARE'then adjusted.target=ignoreStages(adjusted.target,{'defense','specialDefense','special'})end
    if target=='UNAWARE'then adjusted.user=ignoreStages(adjusted.user,{'attack','defense','specialAttack','special'})end
    local modern=epoch(b.game,b)>=5
    local function flag(key,value)
      adjusted.opts=copy(adjusted.opts);adjusted.opts[key]=value
    end
    local terrain=mod.exports and mod.exports.pokemonTerrain67
    if target=='GRASS_PELT'and ctx.move.category=='physical'and terrain and terrain.current(b)=='grassy'then
      flag('kascAbilityDefense67',6144)
    end
    local aura=ctx.move.type=='DARK' and 'DARK_AURA' or ctx.move.type=='FAIRY' and 'FAIRY_AURA'
    if aura and ctx.user~=ctx.target and (user==aura or target==aura)then
      -- One field aura, even if both battlers carry it; it also boosts the
      -- opposing user's move. Aura Break reverses rather than removes it.
      flag('kascAuraPower67',(user=='AURA_BREAK' or target=='AURA_BREAK')and 3072 or 5448)
    end
    local category=ctx.move.category or require('src.battle.TypeChart').category(ctx.move.type)
    local stat=category=='special' and 'special' or 'attack'
    local function power(num,den)
      if epoch(b.game,b)>=4 then
        adjusted.opts=copy(adjusted.opts)
        adjusted.opts.kascOffensivePower67=math.floor(4096*num/den)
      else
        adjusted.move=copy(adjusted.move);adjusted.move.power=math.floor(adjusted.move.power*num/den)
      end
    end
    if user and pinch[user]==ctx.move.type and (tonumber(ctx.user.mon.hp) or 0)>0
        and ctx.user.mon.hp*3<=ctx.user.mon.stats.hp then
      if epoch(b.game,b)<=4 then power(3,2)
      else flag('kascAbilityAttack67',6144)end
    elseif user=='TECHNICIAN' and ctx.move.power<=60 then power(3,2)
    elseif (tonumber(ctx.user.mon.hp) or 0)>0 and
        (user=='TOXIC_BOOST' and stat=='attack' and ctx.user.mon.status=='PSN'
          or user=='FLARE_BOOST' and stat=='special' and ctx.user.mon.status=='BRN')then
      power(3,2)
    elseif stat=='attack' and (user=='HUGE_POWER' or user=='PURE_POWER')then
      if modern then flag('kascAbilityAttack67',8192)
      else adjusted.user=statBattler(adjusted.user,stat,2,1)end
    elseif stat=='attack' and (user=='HUSTLE' or user=='GUTS' and ctx.user.mon.status)then
      if modern then
        -- Hustle is applied independently; Guts chains with other modifiers.
        flag(user=='HUSTLE' and 'kascHustle67' or 'kascAbilityAttack67',user=='HUSTLE' or 6144)
        if user=='GUTS' then flag('kascGuts67',true)end
      else
        adjusted.user=statBattler(adjusted.user,stat,3,2)
        if user=='GUTS' then adjusted.user.hazeStatReset=true end -- no burn penalty
      end
    end
    local trait=user and traits[user]
    local timeline=b.field and b.field.tokens and b.field.tokens[M.owner]
    -- Earlier damage owners may pass detached battler views. Their saved
    -- Pokemon identity still points at the active side.
    local enemySide=ctx.target.mon==b.player.mon and 'player'or ctx.target.mon==b.enemy.mon and 'enemy'or nil
    if user=='ANALYTIC'and timeline and timeline.acted and timeline.acted[enemySide]then
      flag('kascOffensivePower67',5325)
    elseif user=='STAKEOUT'and timeline and timeline.switched and timeline.switched[enemySide]then
      flag('kascAbilityAttack67',8192)
    elseif trait and trait.flag and (moveTraits[ctx.move.id]or{})[trait.flag]then
      flag('kascOffensivePower67',trait.modifier)
    elseif user=='STEELWORKER' and ctx.move.type=='STEEL' then
      flag('kascAbilityAttack67',6144)
    elseif user=='DEFEATIST' and ctx.user.mon.hp*2<=ctx.user.mon.stats.hp then
      flag('kascAbilityAttack67',2048)
    elseif user=='SLOW_START' and stat=='attack' and M.slowStartActive(b,ctx.user)then
      if modern then flag('kascAbilityAttack67',2048)
      else adjusted.user=statBattler(adjusted.user,'attack',1,2)end
    elseif user=='RIVALRY'then
      local gender=opts.gender
      local a,z=gender.getMonGender(ctx.user.mon,b.game),gender.getMonGender(ctx.target.mon,b.game)
      if a~=gender.GENDERLESS and z~=gender.GENDERLESS then flag('kascOffensivePower67',a==z and 5120 or 3072)end
    elseif user=='WATER_BUBBLE' and ctx.move.type=='WATER'then flag('kascAbilityAttack67',8192)
    end
    if (target=='THICK_FAT' and (ctx.move.type=='FIRE' or ctx.move.type=='ICE'))
        or target=='HEATPROOF'and ctx.move.type=='FIRE'
        or target=='WATER_BUBBLE' and ctx.move.type=='FIRE'then
      if modern then flag('kascThickFat67',true)
      else adjusted.user=statBattler(adjusted.user,stat,1,2)end
    elseif target=='MARVEL_SCALE' and ctx.target.mon.status and stat=='attack' then
      if modern then flag('kascAbilityDefense67',6144)
      else adjusted.target=statBattler(adjusted.target,'defense',3,2)end
    elseif target=='FUR_COAT' and stat=='attack' then
      flag('kascAbilityDefense67',8192)
    end
    if user=='TINTED_LENS' and (tonumber(ctx.user.mon.hp) or 0)>0 then
      -- The damage owner applies this after type resistance, but before
      -- the minimum-one clamp. Doubling its already-clamped result would
      -- incorrectly turn some one-damage hits into two-damage hits.
      adjusted.opts=copy(adjusted.opts);adjusted.opts.kascTintedLens67=true
    end
    if (user=='ADAPTABILITY' or user=='SNIPER') and (tonumber(ctx.user.mon.hp) or 0)>0 then
      adjusted.opts=copy(adjusted.opts)
      adjusted.opts.kascAdaptability67=user=='ADAPTABILITY'
      adjusted.opts.kascSniper67=user=='SNIPER'
    end
    if (tonumber(ctx.target.mon.hp) or 0)>0 and
        (target=='FILTER' or target=='SOLID_ROCK' or target=='PRISM_ARMOR'
          or (target=='MULTISCALE' or target=='SHADOW_SHIELD') and ctx.target.mon.hp==ctx.target.mon.stats.hp) then
      -- The final damage owner combines modern modifiers before rounding.
      -- Read current HP on EVERY strike; do not cache Multiscale per move.
      adjusted.opts=copy(adjusted.opts);adjusted.opts.kascDefensiveFinal67=target
    end
    if target=='FLUFFY'then
      local mod=ctx.move.type=='FIRE' and 8192 or 4096
      if user~='LONG_REACH' and (moveTraits[ctx.move.id]or{}).contact then mod=mod/2 end
      if mod~=4096 then flag('kascFluffy67',mod)end
    end
    return nextDamage(adjusted)
  end
  function M.accuracy(nextAccuracy,ctx)
    if not ctx or not native(ctx.battle) or not ctx.move then return nextAccuracy(ctx)end
    if ctx.user and ctx.user.mon.hp>0 and ability(ctx.battle,ctx.user)=='NO_GUARD'
        or ctx.target and ctx.target.mon.hp>0 and ability(ctx.battle,ctx.target)=='NO_GUARD'then return true end
    if ctx.move.effect=='OHKO_EFFECT' then return nextAccuracy(ctx)end
    local id=ability(ctx.battle,ctx.user)
    local category=ctx.move.category or require('src.battle.TypeChart').category(ctx.move.type)
    local num=id=='COMPOUND_EYES' and 130 or id=='VICTORY_STAR'and 110 or id=='HUSTLE' and category=='physical' and 80
    local ignoreEvasion=(id=='UNAWARE' or id=='KEEN_EYE' and epoch(ctx.battle.game,ctx.battle)>=6)
      and ctx.user and ctx.user.mon and (tonumber(ctx.user.mon.hp) or 0)>0
      and ctx.target and ctx.target.stages and (ctx.target.stages.evasion or 0)~=0
    local tangled=ctx.target and ctx.target.mon and (tonumber(ctx.target.mon.hp) or 0)>0
      and (tonumber(ctx.target.confusedTurns) or 0)>0
      and ability(ctx.battle,ctx.target)=='TANGLED_FEET'
    local ignoreAccuracy=ctx.target and ctx.target.mon and ctx.target.mon.hp>0
      and ability(ctx.battle,ctx.target)=='UNAWARE'
    local wonderSkin=ctx.move.category=='status' and type(ctx.move.accuracy)=='number'
      and ctx.target and ctx.target.mon.hp>0 and ability(ctx.battle,ctx.target)=='WONDER_SKIN'
    local simpleUser,simpleTarget=simpleView(ctx.battle,ctx.user),simpleView(ctx.battle,ctx.target)
    if not num and not ignoreEvasion and not ignoreAccuracy and not tangled and not wonderSkin and simpleUser==ctx.user and simpleTarget==ctx.target then return nextAccuracy(ctx)end
    local adjusted=copy(ctx)
    adjusted.user=simpleUser;adjusted.target=simpleTarget
    if ignoreAccuracy then
      adjusted.user=copy(adjusted.user);adjusted.user.stages=copy(adjusted.user.stages);adjusted.user.stages.accuracy=0
    end
    if ignoreEvasion then
      -- Ignore only for this roll; never clear the foe's actual stages.
      -- Gen3-5 Keen Eye protects accuracy but has no evasion bypass.
      adjusted.target=copy(ctx.target);adjusted.target.stages=copy(ctx.target.stages)
      adjusted.target.stages.evasion=0
    end
    if type(ctx.move.accuracy)=='number' and (num or tangled or wonderSkin) then
      adjusted.move=copy(ctx.move)
      adjusted.move.accuracy=math.floor((wonderSkin and 50 or ctx.move.accuracy)*(num or 100)/(tangled and 200 or 100))
    end
    return nextAccuracy(adjusted)
  end
  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap('battle.damage',M.damage,-7000)
    mod.hooks:wrap('battle.accuracy',M.accuracy,-7000)
    mod.hooks:wrap('battle.run',function(nextRun,ctx)
      local b=ctx and ctx.battle
      if b and b.kind=='wild' and ability(b,b.player)=='RUN_AWAY' then return true end
      return nextRun(ctx)
    end,-7000)
  end
  function M.installStatusAdapter(registry)
    -- Update the owner on hot reload, retaining one native wrapper only.
    registry._kascAbilityOwner67=M
    if registry._kascAbilityWrapped67 then return end
    local original=registry.inflict
    registry.inflict=function(b,target,status,options,...)
      local owner=registry._kascAbilityOwner67
      local messages=owner and owner.blockStatus(b,target,status,options)
      if messages then return messages end
      return original(b,target,status,options,...)
    end
    registry._kascAbilityWrapped67=true
  end
  M.installStatusAdapter(require('src.battle.StatusRegistry'))
  M.installActionAdapter(require('src.battle.Status'))
  M.installStageAdapter(require('src.battle.MoveEffects'))
  -- Announcement/move-used callbacks run before the effect context exists.
  -- They must see real abilities: a temporary bypass must not clear a foe's
  -- already primed Flash Fire token or other persistent ability state.
  local Battle=require('src.battle.BattleState')
  local Registry=require('src.battle.EffectRegistry')
  Battle._kascAbilityBypass67=M;Registry._kascAbilityBypass67=M
  if not Battle._kascAbilityActionWrapped67 then
    local execute=Battle.executeAction
    Battle.executeAction=function(b,u,...)
      Battle._kascAbilityBypass67.markAction(b,u);return execute(b,u,...)
    end
    Battle._kascAbilityActionWrapped67=true
  end
  function M.enableMoveFrame(b,user,target)
    local frame=moveFrames[b]
    if frame and frame.user==user and frame.target==target then
      frame.enabled=true;if frame.noGuard then target.invulnerable=false end
      if frame.types then target.curTypes=frame.types end
      for key in pairs(frame.protection or{})do target[key]=nil end
    end
  end
  -- Friend Guard belongs to a third active battler, not the hit target.
  -- Expose only the scoped bypass decision, never the mutable move frame.
  function M.moveBypassesAbility(b,id)
    local frame=moveFrames[b]
    return breakable[id]and frame and frame.enabled and frame.bypass or false
  end
  if not Battle._kascAbilityBypassWrapped67 then
    local original=Battle.performMove
    Battle.performMove=function(b,user,target,move,called)
      return Battle._kascAbilityBypass67.moveScope(b,user,target,false,function()
        return original(b,user,target,move,called)end,b:moveDef(move))
    end
    local makeCtx=Registry.makeCtx
    Registry.makeCtx=function(b,user,target,...)
      local ctx=makeCtx(b,user,target,...)
      Registry._kascAbilityBypass67.enableMoveFrame(b,user,target)
      return ctx
    end
    Battle._kascAbilityBypassWrapped67=true
  end
  for _,hook in ipairs({'battle.damage','battle.accuracy'})do
    mod.hooks:wrap(hook,function(nextFn,ctx)
      return M.moveScope(ctx.battle,ctx.user,ctx.target,true,function()return nextFn(ctx)end,ctx.move)
    end,30000)
  end
  function M.installMoveAdapter(registry)
    local heal=registry:get('HEAL_EFFECT')
    if not heal or type(heal.run)~='function' then return false end
    local original=heal.run
    registry:patch('HEAL_EFFECT',{kascAbilityOwner67=M.owner,kascAbilityBypass67=M.owner,run=function(ctx)
      if ctx.move.id=='REST' then
        local blocked=M.blockStatus(ctx.battle,ctx.user,'SLP')
        if blocked then return blocked end
      end
      return original(ctx)
    end})
    return true
  end
  if mod.content and mod.content.move_effects then
    assert(M.installMoveAdapter(mod.content.move_effects),'native Rest effect unavailable')
    local recoil=mod.content.move_effects:get('RECOIL_EFFECT')
    if recoil and recoil.afterDamage then
      local original=recoil.afterDamage
      mod.content.move_effects:patch('RECOIL_EFFECT',{kascRockHead67=M.owner,afterDamage=function(ctx)
        if ctx.user.mon.hp>0 and (ability(ctx.battle,ctx.user)=='ROCK_HEAD'or M.blocksIndirect(ctx.battle,ctx.user,'recoil'))
            and not ctx.moveInst.struggle and ctx.move.id~='STRUGGLE'then return end
        return original(ctx)
      end})
    end
    local jump=mod.content.move_effects:get('JUMP_KICK_EFFECT')
    if jump and jump.onMiss then
      local old=jump.onMiss
      mod.content.move_effects:patch('JUMP_KICK_EFFECT',{onMiss=function(ctx,...)
        if M.blocksIndirect(ctx.battle,ctx.user,'crash')then return end
        return old(ctx,...)
      end})
    end
    local par=mod.content.statuses:get('PAR');local before=par and par.beforeMove
    if before then mod.content.statuses:patch('PAR',{beforeMove=function(w,rng,b)
      if b and epoch(b.game,b)==4 and ability(b,w)=='MAGIC_GUARD'then return true,{}end
      return before(w,rng,b)
    end})end
  end
  mod.events:on('battle.started',M.stageEntry,7000)
  mod.events:on('battle.started',M.flushEntry,-10050)
  mod.events:on('battle.battler_switched',M.switchOverride,40000)
  mod.events:on('battle.battler_switched',M.markSwitch,7100)
  mod.events:on('battle.turn_started',M.clearActions,9100)
  mod.events:on('battle.turn_ended',M.clearActions,-12000)
  mod.events:on('battle.battler_switched',M.stageEntry,7000)
  mod.events:on('battle.battler_switched',M.flushEntry,-10050)
  mod.events:on('battle.battler_switched',M.updateTrace,-10070)
  mod.events:on('battle.turn_started',M.updateTrace,7000)
  mod.events:on('battle.damage_dealt',M.updateTrace,-500)
  -- After trainer scaling and split-stat preparation, within the same
  -- synchronous entry event. Checkpoint resume never replays these events.
  mod.events:on('battle.started',M.signals,-11000)
  mod.events:on('battle.battler_switched',M.signals,-11000)
  mod.events:on('battle.turn_ended',M.residual,100)
  mod.events:on('battle.fainted',M.onFainted,100)
  mod.events:on('battle.turn_started',M.syncItemLoss,9000)
  mod.events:on('battle.move_used',M.syncItemLoss,9000)
  mod.events:on('battle.ended',M.finish,100)
  return M
end
