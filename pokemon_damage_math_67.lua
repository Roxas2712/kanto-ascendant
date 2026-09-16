-- KASC-67-DAMAGE-MATH: isolated copy of the native Gen1 calculation.
-- Source: gen1recomp/src/battle/Damage.lua. Zero modifier must remain
-- byte-semantically equivalent in RNG use and returned damage metadata.
-- Only the Gen2 held-type bonus adds a stage before the cap/+2 constant.
-- Gen 1 damage calculation, ported from engine/battle/core.asm
-- (GetDamage / CriticalHitTest / AdjustDamageForMoveType / RandomizeDamage).
--
-- Battlers carry curStats/curTypes (Transform/Conversion can override the
-- species values) plus reflect/lightScreen/focusEnergy volatile flags.
-- Battlers built by makeBattler also carry the merged badgeBoosts rows and
-- statuses records; hand-built battlers fall back to the vanilla tables.

local Logger = require("src.core.Logger")
local Runtime = require("src.mods.Runtime")
local Stats = require("src.pokemon.Stats")
local Status = require("src.battle.Status")
local TypeChart = require("src.battle.TypeChart")

local Damage = {}
Damage.kascLateAbilityPower67 = 'kasc.late-ability-power/v1'
Damage.kascParentalBond67 = 'kasc.parental-bond/v1'
Damage.kascStockpile67 = 'kasc.stockpile/v1'
Damage.kascRandomStrength67 = 'kasc.random-strength/v1'
Damage.kascPartyMultihit67 = 'kasc.party-multihit/v1'
Damage.kascConditionalPower67 = 'kasc.conditional-power/v1'
Damage.kascCalledMoves67 = 'kasc.called-moves/v1'
Damage.kascBodyUtilities67 = 'kasc.body-utilities/v1'
Damage.kascSports67 = 'kasc.sports/v1'

-- Moves with a boosted critical-hit rate (engine/battle/core.asm
-- CriticalHitTest checks these move ids explicitly).  The move-record
-- highCrit field wins; this list covers pre-existing imported caches.
local HIGH_CRIT = {
  KARATE_CHOP = true, RAZOR_LEAF = true, CRABHAMMER = true, SLASH = true,
}

-- ApplyBadgeStatBoosts (engine/battle/core.asm): x9/8 per badge on the
-- named battle stat.  Data.constants.badgeBoosts replaces this via the
-- battler's badgeBoosts field; these rows are the vanilla values.
Damage.BADGE_BOOSTS = {
  { badge = "BOULDERBADGE", stat = "attack", num = 9, den = 8 },
  { badge = "THUNDERBADGE", stat = "defense", num = 9, den = 8 },
  { badge = "SOULBADGE", stat = "speed", num = 9, den = 8 },
  { badge = "VOLCANOBADGE", stat = "special", num = 9, den = 8 },
}

-- the boost a battler's badge set applies to one battle stat, or nil
local function badgeBoost(battler, stat)
  local badges = battler.badges
  if not badges then return nil end
  for _, row in ipairs(battler.badgeBoosts or Damage.BADGE_BOOSTS) do
    if row.stat == stat and badges[row.badge] then return row end
  end
  return nil
end

-- the merged status record for a battler's persistent condition, or nil
local function statusRecord(battler)
  return Status.recordFor(battler.statuses, battler.mon.status)
end

-- Critical chance test, following CriticalHitTest's shift chain exactly
-- (each left shift caps at 255): b = speed/2, then x2 (or /2 with
-- Focus Energy's famous right-shift bug), then x4 for high-crit moves
-- or /2 for normal ones.  Net rates: normal = speed/512, high-crit =
-- speed*4/256 (capped), Focus Energy bug = 1/4 the usual.
-- critUsesBaseSpeed (default true, the Gen 1 rule) reads the species
-- base speed; a ruleset that sets it false uses the current in-battle
-- speed with stages applied.
function Damage.critRoll(ruleset, attacker, moveId, rng, highCrit)
  rng = rng or love.math.random
  local function shl(x) return math.min(255, x * 2) end
  local speed
  if ruleset.critUsesBaseSpeed == false then
    speed = Stats.applyStage(attacker.curStats.speed,
              attacker.stages and attacker.stages.speed or 0)
  else
    speed = attacker.def.baseStats.speed
  end
  local b = math.floor(speed / 2)
  if attacker.focusEnergy then
    if ruleset.focusEnergyBug then
      b = math.floor(b / 2)      -- srl instead of sla
    else
      b = shl(shl(shl(b)))       -- intended: x4 the usual rate
    end
  else
    b = shl(b)
  end
  if highCrit == nil then highCrit = HIGH_CRIT[moveId] end
  if highCrit then
    b = shl(shl(b))
  else
    b = math.floor(b / 2)
  end
  return rng(0, 255) < b
end

-- Accuracy test: rand(0..255) < floor(accuracy * 255 / 100) adjusted by
-- accuracy/evasion stages.  With oneIn256Miss a max-accuracy move still
-- misses on 255.
function Damage.accuracyRoll(ruleset, move, attacker, defender, rng)
  rng = rng or love.math.random
  -- X ACCURACY sets USING_X_ACCURACY: the move simply never misses
  -- (MoveHitTest returns before any accuracy math, 1/256 included)
  if attacker.xAccuracy then return true end
  local acc = math.floor(move.accuracy * 255 / 100)
  -- CalcHitChance scales by the accuracy stage and the evasion stage as
  -- two separate ratio multiplications, clamping each result
  acc = math.min(255, Stats.applyStage(acc,
          attacker.stages and attacker.stages.accuracy or 0))
  acc = math.min(255, Stats.applyStage(acc,
          -(defender.stages and defender.stages.evasion or 0)))
  if not ruleset.oneIn256Miss and move.accuracy >= 100
     and (attacker.stages.accuracy or 0) >= (defender.stages.evasion or 0) then
    return true
  end
  return rng(0, 255) < acc
end

local warnedTypes = {}

-- Gen 1 splits physical from special by TYPE: the move's own category
-- field wins, then the merged type record's, then physical (with one
-- warning per unknown type).
local function categoryOf(move)
  local category = move.category or TypeChart.category(move.type)
  if category == nil then
    if move.type ~= nil and not warnedTypes[move.type] then
      warnedTypes[move.type] = true
      Logger.warn("move type %s has no category; treated as physical",
                  tostring(move.type))
    end
    category = "physical"
  end
  return category
end

function Damage.isSpecial(moveType)
  return TypeChart.category(moveType) == "special"
end

-- Compute damage.  attacker/defender are battler tables.
-- opts: rng, forceCrit, explode (halves defense), typeless (confusion
-- self-hit: no STAB/type/random factor), screens (battler whose
-- Reflect/Light Screen apply when it isn't the defender -- the
-- self-hit reads the opponent's screens).
-- Returns damage, {crit=bool, typeMult=x10}.
function Damage.compute(ruleset, attacker, defender, move, opts)
  opts = opts or {}
  local rng = opts.rng or love.math.random
  local meFirst=opts.kascMeFirst67==6144 and move.kascMeFirst67==Damage.kascCalledMoves67
    and type(opts.kascMeFirstEpoch67)=='number'and opts.kascMeFirstEpoch67%1==0
    and opts.kascMeFirstEpoch67>=4 and opts.kascMeFirstEpoch67<=7 and opts.kascMeFirstEpoch67 or nil
  local charged=opts.kascCharge67==Damage.kascBodyUtilities67 and not(opts.typeless or opts.typelessDamage)
    and move.type=='ELECTRIC'and move.category~='status'and(tonumber(move.power)or 0)>0
  local chargeDamage=charged and opts.kascChargeMode67=='damage'
  local chargePower=charged and opts.kascChargeMode67=='power'
  local sports,sportsEpoch=opts.kascSportsPower67,opts.kascSportsEpoch67
  local validSports=opts.kascSports67==Damage.kascSports67 and not(opts.typeless or opts.typelessDamage)
    and(move.type=='ELECTRIC'or move.type=='FIRE')and type(sports)=='table'
    and type(sportsEpoch)=='number'and sportsEpoch%1==0 and sportsEpoch>=1 and sportsEpoch<=7
    and #sports>=1 and #sports<=(sportsEpoch==5 and 2 or 1)
  if validSports then
    for k,v in pairs(sports)do
      if type(k)~='number'or k%1~=0 or k<1 or k>#sports
        or v~=(sportsEpoch<=4 and 2048 or 1352)then validSports=false;break end
    end
    local formula=tonumber(opts.kascCriticalEpoch67)or 1
    -- An authenticated future attack can use its own later formula while
    -- the active Sport retains the surrounding battle's historical factor.
    validSports=validSports and formula%1==0 and formula>=sportsEpoch and formula<=7
  end
  if not validSports then sports=nil end
  if move.power == 0 or move.category == "status" then
    return 0, { crit = false, typeMult = 10 }
  end

  local stockpile=opts.kascSpitUpGen367
  stockpile=type(stockpile)=='number'and stockpile%1==0 and stockpile>=1 and stockpile<=3
    and move.id=='SPIT_UP'and move.backendMoveOwner==Damage.kascStockpile67 and stockpile or nil
  local crit = opts.forceCrit
  if stockpile then crit=false end
  if crit == nil then
    if Runtime.wantsHook("battle.crit") then
      crit = Runtime.call("battle.crit", function(c)
        return Damage.critRoll(c.ruleset, c.attacker, c.moveId, c.rng, c.highCrit)
      end, { ruleset = ruleset, attacker = attacker, moveId = move.id,
             rng = rng, highCrit = move.highCrit })
    else
      crit = Damage.critRoll(ruleset, attacker, move.id, rng, move.highCrit)
    end
  end

  local special = categoryOf(move) == "special"
  local atkStat = special and "special" or "attack"
  local defStat = special and "special" or "defense"

  -- Explicit later-era option only: all unmarked/native callers retain the
  -- original code below, including the 10,000-case Gen-I parity contract.
  local epoch = tonumber(opts.kascCriticalEpoch67)
  local beat=opts.kascBeatUpBase67
  local function bounded(v,hi)return type(v)=='number'and v%1==0 and v>=1 and v<=hi end
  beat=type(beat)=='table'and epoch and epoch>=1 and epoch<=4
    and move.backendMoveOwner==Damage.kascPartyMultihit67 and move.backendMoveNumber==251
    and bounded(beat.attack,9999)and bounded(beat.defense,9999)and bounded(beat.level,100)and beat or nil
  -- Only the licensed per-use Beat Up view uses its earliest II formula.
  -- The actual battle receipt, global Special split and type pool stay I.
  if beat and epoch==1 then epoch=2 end
  if epoch and epoch >= 2 then
    local aStage = attacker.stages and attacker.stages[atkStat] or 0
    local dStage = defender.stages and defender.stages[defStat] or 0
    local ignoreAll = epoch == 2 and crit and aStage <= dStage
    if ignoreAll then aStage, dStage = 0, 0
    elseif crit and epoch >= 3 then
      aStage, dStage = math.max(0,aStage), math.min(0,dStage)
    end
    local function stat(value, stage)
      if epoch == 2 and stage < 0 then
        return math.floor(value * ({66,50,40,33,28,25})[math.min(6,-stage)] / 100)
      end
      if epoch>=3 then
        -- Native Stats.applyStage caps at 999 for Gen I. Later profiles
        -- must not inherit that cap before/after their ability modifiers.
        stage=math.max(-6,math.min(6,stage))
        return math.max(1,math.floor(stage>=0 and value*(2+stage)/2 or value*2/(2-stage)))
      end
      return Stats.applyStage(value,stage)
    end
    local attackBase=attacker.curStats[atkStat]
    if epoch<=4 and special and opts.kascPlusMinus67 then attackBase=math.floor(attackBase*3/2)end
    -- Platinum modifies the base Sp. Atk before stages; V+ modifies the
    -- resulting staged stat. The distinction matters for odd stat values.
    if epoch==4 and special and opts.kascSolarPower67 then attackBase=math.floor(attackBase*3/2) end
    if epoch==4 and not special and opts.kascFlowerGiftAttack67 then attackBase=math.floor(attackBase*3/2)end
    local atk = stat(attackBase,aStage)
    local defenseBase=defender.curStats[defStat]
    if epoch==4 and special and opts.kascSandSpecialDefense67 then defenseBase=math.floor(defenseBase*3/2) end
    if epoch==4 and special and opts.kascFlowerGiftDefense67 then defenseBase=math.floor(defenseBase*3/2)end
    local dfn = stat(defenseBase,dStage)
    -- Keep the host's separately configured badge contract. Modern critical
    -- hits do not erase that modifier along with unfavorable stat stages.
    if not ignoreAll then
      local ab, db = badgeBoost(attacker,atkStat), badgeBoost(defender,defStat)
      if ab then atk=math.floor(atk*(ab.num or 9)/(ab.den or 8)) end
      if db then dfn=math.floor(dfn*(db.num or 9)/(db.den or 8)) end
    end
    local penalty = statusRecord(attacker)
    local burned = penalty and penalty.statPenalty and penalty.statPenalty.stat == atkStat
      and not attacker.hazeStatReset and not (epoch>=5 and opts.kascGuts67)
    if epoch>=6 and move.id=='FACADE'and move.backendMoveOwner==Damage.kascConditionalPower67
        and move.backendMoveNumber==263 and opts.kascFacadeNoBurn67==true then burned=false end
    local screens=opts.kascScreens67 or defender
    local screened = (special and screens.lightScreen or not special and screens.reflect)
      and not (epoch == 2 and ignoreAll or epoch >= 3 and crit)
    screened=screened or opts.kascAuroraVeil67 and not crit
    if beat then atk,dfn=beat.attack,beat.defense end
    if epoch == 2 then
      if burned and not ignoreAll and not beat then atk = math.floor(atk/2) end
      atk, dfn = math.max(1,math.min(999,atk)), math.max(1,math.min(999,dfn))
      if screened and not beat then dfn = dfn*2 end
      if opts.kascHeldAttack67==8192 and not beat then atk=atk*2 end
      -- Crystal's non-link TruncateHL_BC repeats until BOTH stats fit a byte.
      -- Held boosts happen after the 999 cap, before this shared truncation.
      while atk>255 or dfn>255 do
        atk,dfn=math.max(1,math.floor(atk/4)),math.max(1,math.floor(dfn/4))
      end
      if opts.kascMetalPowder67 and not beat then
        -- Crystal applies this AFTER byte truncation, including the carry
        -- branch which halves attack too. It remains active after Transform.
        dfn=dfn+math.floor(dfn/2)
        if dfn>255 then atk=math.max(1,math.floor(atk/2));dfn=math.floor(dfn/2)end
      end
    end
    if opts.explode and epoch<=4 then dfn=math.max(1,math.floor(dfn/2)) end
    if epoch==3 or epoch==4 then
      if not beat and (opts.kascHeldAttack67==8192 or opts.kascHeldAttack67==6144)then
        atk=math.floor(atk*opts.kascHeldAttack67/4096)
      end
      if not beat and (opts.kascHeldDefense67==8192 or opts.kascHeldDefense67==6144)then
        dfn=math.floor(dfn*opts.kascHeldDefense67/4096)
      end
    elseif epoch>=5 then
      local function modified(value,factors)
        local modifier=4096
        for _,factor in ipairs(factors)do modifier=math.floor((modifier*factor+2048)/4096)end
        return math.max(1,math.floor((value*modifier+2047)/4096))
      end
      if opts.kascHustle67 then atk=math.max(1,math.floor(atk*3/2))end
      atk=modified(atk,{opts.kascThickFat67 and 2048 or 4096,
        (opts.kascAbilityAttack67==2048 or opts.kascAbilityAttack67==6144 or opts.kascAbilityAttack67==8192)and opts.kascAbilityAttack67 or 4096,
        opts.kascFlashFire67 and 6144 or 4096,
        special and opts.kascSolarPower67 and 6144 or 4096,
        special and opts.kascPlusMinus67 and 6144 or 4096,
        not special and opts.kascFlowerGiftAttack67 and 6144 or 4096,
        (opts.kascHeldAttack67==6144 or opts.kascHeldAttack67==8192)and opts.kascHeldAttack67 or 4096})
      dfn=modified(dfn,{(opts.kascAbilityDefense67==6144 or opts.kascAbilityDefense67==8192)and opts.kascAbilityDefense67 or 4096,
        special and opts.kascSandSpecialDefense67 and 6144 or 4096,
        special and opts.kascFlowerGiftDefense67 and 6144 or 4096,
        (opts.kascHeldDefense67==6144 or opts.kascHeldDefense67==8192)and opts.kascHeldDefense67 or 4096})
    end
    local power=move.power
    if opts.kascHeldPowerDouble67 then power=power*2 end
    if epoch>=5 then
      -- Fixed-point chaining: offensive ability, defensive ability, held item.
      -- Round modifier products half up, but resulting base power half down.
      -- Do not round each ability/item independently (e.g. Technician+Charcoal).
      local modifier=4096
      local function chain(value)modifier=math.floor((modifier*value+2048)/4096)end
      if meFirst and meFirst>=5 then chain(6144)end
      if opts.kascOffensivePower67==6144 or opts.kascOffensivePower67==4915
          or opts.kascOffensivePower67==5325 or opts.kascOffensivePower67==5120
          or opts.kascOffensivePower67==3072 then chain(opts.kascOffensivePower67)end
      if opts.kascSandForce67 then chain(5325)end
      if opts.kascConversionPower67==4915 or opts.kascConversionPower67==5325 then chain(opts.kascConversionPower67)end
      if chargePower then chain(8192)end
      if epoch==7 and special then
        for _=1,math.max(0,math.min(5,math.floor(tonumber(opts.kascBatteryCount67)or 0)))do chain(5325)end
      end
      if opts.kascTerrainPower67==6144 or opts.kascTerrainPower67==2048 then chain(opts.kascTerrainPower67)end
      if opts.kascAuraPower67==5448 or opts.kascAuraPower67==3072 then chain(opts.kascAuraPower67)end
      if opts.kascDrySkin67 then chain(5120)end
      if opts.kascHeldTypeBoost67 then chain(4915)end
      -- V's gem override has priority 0; VI/VII gems have priority 14.
      if sports and epoch==5 then for _,factor in ipairs(sports)do chain(factor)end end
      if opts.kascGemPower67==6144 or opts.kascGemPower67==5325 then chain(opts.kascGemPower67)end
      -- Sport priority 1 follows abilities, held boosts, Charge and terrain;
      -- Knock Off's priority-0 move modifier remains after it.
      if sports and epoch>=6 then for _,factor in ipairs(sports)do chain(factor)end end
      if epoch>=6 and opts.kascKnockOffPower67 then chain(6144)end
      power=math.max(1,math.floor((power*modifier+2047)/4096))
    elseif epoch==4 then
      if opts.kascHeldTypeBoost67 and not chargePower then power=math.floor(power*6/5)end
      if opts.kascOffensivePower67==6144 then power=math.floor(power*3/2)end
      if opts.kascOffensivePower67==4915 then power=math.floor(power*6/5)end
      if opts.kascOffensivePower67==5120 then power=math.floor(power*5/4)end
      if opts.kascOffensivePower67==3072 then power=math.floor(power*3/4)end
      if chargePower then power=power*2 end
      if opts.kascDrySkin67 then power=math.floor(power*5/4)end
      if chargePower and opts.kascHeldTypeBoost67 then power=math.floor(power*6/5)end
    end
    if sports and epoch<=4 then power=math.max(1,math.floor(power/2))end
    local d=math.floor(math.floor((math.floor(2*(beat and beat.level or attacker.mon.level)/5)+2)
      * power * math.max(1,atk) / math.max(1,dfn))/50)
    if epoch==2 then
      if crit then d=d*2 end
      d=math.floor(d*(100+(tonumber(opts.kascHeldTypePercent) or 0))/100)
      d=math.max(1,math.min(997,d))+2
      if chargeDamage then d=d*2 end
      if stockpile then d=d*stockpile end
      d=math.floor(d*(opts.kascWeatherFactor67 or 1))
      if meFirst==4 then d=math.floor(d*3/2)end
    else
      if epoch<=4 then
        if burned then d=math.floor(d/2) end
        if screened then d=math.floor(d/2) end
        d=math.floor(d*(opts.kascWeatherFactor67 or 1))
        if opts.kascFlashFire67 then d=math.floor(d*3/2) end
      end
      d=d+2
      if epoch==3 and chargeDamage then d=d*2 end
      -- Emerald's stockpiletobasedamage multiplies the rounded strength-100
      -- base including +2, not the move's strength before division.
      if stockpile then d=d*stockpile end
      if epoch>=6 and (opts.kascParentalBond67==2048 or opts.kascParentalBond67==1024)then
        d=math.floor((d*opts.kascParentalBond67+2047)/4096)
      end
      if epoch>=5 then d=math.floor(d*(opts.kascWeatherFactor67 or 1))end
      if crit then d=math.floor(d*(epoch==4 and opts.kascSniper67 and 3 or epoch>=6 and 1.5 or 2)) end
      if meFirst==4 then d=math.floor(d*3/2)end
      if epoch==4 and opts.kascLifeOrb67 then d=math.floor(d*13/10)end
      if epoch>=4 then d=math.floor(d*rng(85,100)/100)end
    end
    for _,t in ipairs(attacker.curTypes) do
      if t==move.type then d=math.floor(d*(epoch>=4 and opts.kascAdaptability67 and 2 or 1.5));break end
    end
    local mult=TypeChart.effectiveness(move.type,defender.curTypes)
    if mult==0 then return 0,{crit=false,typeMult=0} end
    if epoch==7 and opts.kascDisguise67 then mult=10
    else for _,m in ipairs(TypeChart.rows(move.type,defender.curTypes)) do d=math.floor(d*m/10) end end
    if epoch==2 and d>1 and not opts.kascNoVariance67 and not stockpile then d=math.floor(d*rng(217,255)/255) end
    -- Gen III randomizes after STAB and type effectiveness; Gen IV+
    -- moved that rounding stage before them. Keep the Gen-I path below.
    if epoch==3 and not stockpile then d=math.floor(d*rng(85,100)/100)end
    if epoch<=4 and opts.kascMagnitudeDig67 then d=d*2 end
    local guard=opts.kascDefensiveFinal67
    local defensive=(guard=='FILTER' or guard=='SOLID_ROCK' or guard=='PRISM_ARMOR') and mult>10 and 3072
      or (guard=='MULTISCALE' or guard=='SHADOW_SHIELD') and 2048
      or (opts.kascFluffy67==2048 or opts.kascFluffy67==8192) and opts.kascFluffy67 or nil
    local sniper=epoch>=5 and opts.kascSniper67 and crit
    local friends=epoch>=5 and math.max(0,math.min(5,math.floor(tonumber(opts.kascFriendGuardCount67)or 0)))or 0
    local neuro=epoch==7 and opts.kascNeuroforce67==5120 and mult>10
    if epoch>=5 and (defensive or sniper or opts.kascLifeOrb67 or friends>0 or neuro or opts.kascMagnitudeDig67) then
      if burned then d=math.floor(d/2) end
      -- Gen V/VI combine final modifiers (screens, defensive ability,
      -- Tinted Lens) then round once, with exact halves rounded DOWN.
      local modifier=defensive or 4096
      if sniper then modifier=modifier*3/2 end
      if screened then modifier=modifier/2 end
      if opts.kascTintedLens67 and mult>0 and mult<10 then modifier=modifier*2 end
      for _=1,friends do modifier=math.floor((modifier*3072+2048)/4096)end
      if opts.kascLifeOrb67 then modifier=math.floor((modifier*5324+2048)/4096)end
      if neuro then modifier=math.floor((modifier*5120+2048)/4096)end
      if opts.kascMagnitudeDig67 then modifier=modifier*2 end
      if epoch==5 then d=math.max(1,d) end
      d=math.floor((d*modifier+2047)/4096)
      return math.max(1,d),{crit=crit,typeMult=mult,kascAuroraVeilHandled67=opts.kascAuroraVeil67 or nil}
    end
    if epoch>=5 then
      if burned then d=math.floor(d/2) end
      if screened then d=math.floor(d/2) end
    end
    if epoch==4 and defensive then d=math.floor(d*defensive/4096) end
    if opts.kascTintedLens67 and mult>0 and mult<10 then d=d*2 end
    return math.max(1,d),{crit=crit,typeMult=mult,kascAuroraVeilHandled67=opts.kascAuroraVeil67 or nil}
  end

  local atk, dfn
  if crit and ruleset.critIgnoresStages then
    atk = attacker.curStats[atkStat]
    dfn = defender.curStats[defStat]
  else
    atk = Stats.applyStage(attacker.curStats[atkStat],
                           attacker.stages and attacker.stages[atkStat] or 0)
    dfn = Stats.applyStage(defender.curStats[defStat],
                           defender.stages and defender.stages[defStat] or 0)
    -- badge boosts (x9/8), engine/battle/core.asm ApplyBadgeStatBoosts:
    -- Boulder -> attack, Thunder -> defense, Soul -> speed (TurnOrder),
    -- Volcano -> special
    local atkBoost = badgeBoost(attacker, atkStat)
    if atkBoost then
      atk = math.floor(atk * (atkBoost.num or 9) / (atkBoost.den or 8))
    end
    local defBoost = badgeBoost(defender, defStat)
    if defBoost then
      dfn = math.floor(dfn * (defBoost.num or 9) / (defBoost.den or 8))
    end
    -- burn halves physical attack (applied as part of the stat in Gen 1;
    -- the status record's statPenalty names the stat it cuts).
    -- hazeStatReset suppresses it: Haze (haze.asm ResetStats) copied the
    -- unmodified attack over the burn-halved battle stat, lifting the
    -- penalty until the next stat recompute.
    local record = statusRecord(attacker)
    local penalty = record and record.statPenalty
    if penalty and penalty.stat == atkStat and not attacker.hazeStatReset then
      atk = math.max(1, math.floor(atk / penalty.div))
    end
    -- screens double the effective defense (crits bypass them).  The
    -- confusion self-hit is the quirk case: HandleSelfConfusionDamage
    -- swaps the user's own defense in but leaves the screen check
    -- reading the OPPONENT's battle status, so the typeless path takes
    -- the screen flags from opts.screens (the opponent) and never from
    -- the user itself.
    if not crit then
      local screens = opts.screens
      if screens == nil and not opts.typeless then screens = defender end
      if screens then
        if special and screens.lightScreen then dfn = dfn * 2 end
        if not special and screens.reflect then dfn = dfn * 2 end
      end
    end
  end
  -- GetDamageVars .scaleStats: when either stat no longer fits a byte,
  -- BOTH are quartered (losing low bits), each bumped to at least 1
  if atk > 255 or dfn > 255 then
    atk = math.max(1, math.floor(atk / 4))
    dfn = math.max(1, math.floor(dfn / 4))
  end
  if opts.explode then
    dfn = math.max(1, math.floor(dfn / 2))
  end

  local level = attacker.mon.level
  if crit then level = level * 2 end

  local d = math.floor(math.floor(2 * level / 5) + 2)
  local power=sports and math.max(1,math.floor(move.power/2))or move.power
  d = math.floor(math.floor(d * power * atk / math.max(1, dfn)) / 50)
  local bonus = tonumber(opts.kascHeldTypePercent) or 0
  if bonus ~= 0 and not opts.typeless then d = math.floor(d * (100 + bonus) / 100) end
  d = math.min(d, 997) + 2
  if chargeDamage then d=d*2 end
  if stockpile then d=d*stockpile end
  if meFirst==4 then d=math.floor(d*3/2)end

  local mult = 10
  if not opts.typeless then
    -- STAB
    local stab = false
    for _, t in ipairs(attacker.curTypes) do
      if t == move.type then stab = true break end
    end
    if stab then
      d = math.floor(d * 3 / 2)
    end

    -- type effectiveness: each TypeEffects row is applied to the
    -- running damage separately with its own floor (0.5*0.5 lands on
    -- floor(floor(d/2)/2), not d*0.25)
    mult = TypeChart.effectiveness(move.type, defender.curTypes)
    if mult == 0 then
      return 0, { crit = false, typeMult = 0 }
    end
    for _, m in ipairs(TypeChart.rows(move.type, defender.curTypes)) do
      d = math.floor(d * m / 10)
    end
    if d == 0 then
      -- a 2-3 damage hit at 0.25x floors to zero: the original flags
      -- the move as missed rather than dealing a minimum 1
      return 0, { crit = false, typeMult = mult, missed = true }
    end
  end

  -- random factor; the typeless confusion self-hit skips RandomizeDamage
  -- along with AdjustDamageForMoveType (HandleSelfConfusionDamage calls
  -- CalculateDamage directly), so it is fully deterministic
  if d > 1 and not opts.typeless and not stockpile then
    local r = rng(ruleset.randMin, ruleset.randMax)
    d = math.floor(d * r / 255)
  end
  if opts.kascMagnitudeDig67 then d=d*2 end
  return math.max(d, 1), { crit = crit, typeMult = mult }
end

return Damage
