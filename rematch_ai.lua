-- Rematch-only AI guard for moves whose effect is guaranteed to fail.
--
-- Gen-I Layer 3 deliberately type-scores even zero-power moves. REST is a
-- Psychic move, so Expert trainers can otherwise prefer it forever against a
-- Poison/Fighting target while already at full HP. Keep the stock engine
-- untouched and append one KASC scoring layer only to KASC rematches.

local LAYER_ID = "KA_REMATCH_USEFUL_MOVE"
local USELESS_PENALTY = 100

local MAJOR_STATUS = {
  EFFECT_01 = true,
  SLEEP_EFFECT = true,
  POISON_EFFECT = true,
  PARALYZE_EFFECT = true,
}

local SELF_STAGE = {
  ATTACK_UP1_EFFECT = "attack", ATTACK_UP2_EFFECT = "attack",
  DEFENSE_UP1_EFFECT = "defense", DEFENSE_UP2_EFFECT = "defense",
  SPEED_UP1_EFFECT = "speed", SPEED_UP2_EFFECT = "speed",
  SPECIAL_UP1_EFFECT = "special", SPECIAL_UP2_EFFECT = "special",
  ACCURACY_UP1_EFFECT = "accuracy", ACCURACY_UP2_EFFECT = "accuracy",
  EVASION_UP1_EFFECT = "evasion", EVASION_UP2_EFFECT = "evasion",
}

local TARGET_STAGE = {
  ATTACK_DOWN1_EFFECT = "attack", ATTACK_DOWN2_EFFECT = "attack",
  DEFENSE_DOWN1_EFFECT = "defense", DEFENSE_DOWN2_EFFECT = "defense",
  SPEED_DOWN1_EFFECT = "speed", SPEED_DOWN2_EFFECT = "speed",
  SPECIAL_DOWN1_EFFECT = "special", SPECIAL_DOWN2_EFFECT = "special",
  ACCURACY_DOWN1_EFFECT = "accuracy", ACCURACY_DOWN2_EFFECT = "accuracy",
  EVASION_DOWN1_EFFECT = "evasion", EVASION_DOWN2_EFFECT = "evasion",
}

local function hasType(battler, wanted)
  for _, kind in ipairs(battler and battler.curTypes or {}) do
    if kind == wanted then return true end
  end
  return false
end

local function noUsefulEffect(view, def)
  if not (view and def and view.user and view.target) then return false end
  local user, target = view.user, view.target
  local mon = user.mon or {}
  local targetMon = target.mon or {}
  local effect = def.effect

  -- REST, RECOVER and SOFTBOILED all share HEAL_EFFECT. At full HP the
  -- engine returns "But, it failed!" before REST can clear another status.
  if effect == "HEAL_EFFECT" then
    local maxHP = mon.stats and tonumber(mon.stats.hp)
    if maxHP and tonumber(mon.hp) and mon.hp >= maxHP then return true end
    -- Sleep normally prevents move execution before selection. This explicit
    -- guard also covers integrations that ask the AI before resolving sleep.
    if def.id == "REST" and mon.status == "SLP" then return true end
  end

  if MAJOR_STATUS[effect] and targetMon.status then return true end
  if effect == "POISON_EFFECT" and target.substituteHP then return true end
  if effect == "CONFUSION_EFFECT"
      and (target.confusedTurns or target.substituteHP) then return true end
  if effect == "LEECH_SEED_EFFECT"
      and (target.leechSeeded or hasType(target, "GRASS")) then return true end

  if effect == "LIGHT_SCREEN_EFFECT" and user.lightScreen then return true end
  if effect == "REFLECT_EFFECT" and user.reflect then return true end
  if effect == "MIST_EFFECT" and user.mist then return true end
  if effect == "FOCUS_ENERGY_EFFECT" and user.focusEnergy then return true end

  local selfStat = SELF_STAGE[effect]
  if selfStat and ((user.stages and user.stages[selfStat]) or 0) >= 6 then
    return true
  end
  local targetStat = TARGET_STAGE[effect]
  if targetStat and (target.substituteHP or target.mist
      or ((target.stages and target.stages[targetStat]) or 0) <= -6) then
    return true
  end

  return false
end

return function(mod)
  local A = {
    layerId = LAYER_ID,
    noUsefulEffect = noUsefulEffect,
  }

  local layer = {
    kind = "layer",
    score = function(view, def, score)
      if noUsefulEffect(view, def) then
        return (tonumber(score) or 10) + USELESS_PENALTY
      end
      return score
    end,
  }
  mod.content.ai_classes:register(LAYER_ID, layer)
  A.layer = layer

  function A.attach(battle)
    if not (battle and battle.rematch == true) then return false end
    local mods = {}
    local present = false
    for _, id in ipairs(battle.enemyAIMods or {}) do
      mods[#mods + 1] = id
      if id == LAYER_ID then present = true end
    end
    if not present then mods[#mods + 1] = LAYER_ID end
    battle.enemyAIMods = mods
    battle.rematchUsefulAI = true
    return true
  end

  return A
end
