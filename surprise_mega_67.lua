-- Optional Surprise Trainer Mega planner.
--
-- It never grants a form. A candidate is legal only when the current save
-- already owns Ring plus exact official Stone entitlement. Plans are stable
-- by encounter token and are revalidated immediately before battle.

return function(mod, opts)
  opts = opts or {}
  local mega = assert(opts.mega, "Surprise Mega card needs Mega authority")
  local postgame = opts.postgame
  local i18n = opts.i18n
  local M = { ODDS = 10, MIN_LEVEL = 80 }

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  local function hash(value)
    local n = 5381
    value = tostring(value or "")
    for i = 1, #value do n = (n * 33 + value:byte(i)) % 2147483647 end
    return n
  end

  local function enabled()
    return not (mod.options and type(mod.options.get) == "function"
      and mod.options:get("surprise_trainer_mega") == false)
  end

  local function megaModesEnabled()
    if not (mod.options and type(mod.options.get) == "function") then
      return true
    end
    return mod.options:get("mega_evolution") ~= false
      and mod.options:get("mega_opponents") ~= "off"
  end

  local function leagueReady(game)
    if postgame and type(postgame.hasHallOfFame) == "function" then
      return postgame.hasHallOfFame(game and game.save) == true
    end
    local save = game and game.save or {}
    return type(save.hallOfFame) == "table" and #save.hallOfFame > 0
  end

  local function entitlement(game, species, wantedForm)
    if not (enabled() and megaModesEnabled() and leagueReady(game) and mega.hasRing
        and mega.hasRing(game)) then return nil end
    for _, profile in ipairs(type(mega.forms) == "table" and mega.forms or {}) do
      if profile.species == species and profile.secret ~= true
          and (not wantedForm or profile.id == wantedForm)
          and type(profile.stone) == "string"
          and mega.hasStone and mega.hasStone(profile.stone, game)
          and (not mega.tierAvailable
            or mega.tierAvailable(game, profile.tier) == true) then
        return profile
      end
    end
  end

  function M.plan(game, token, team, tier)
    if not enabled() then return nil, "disabled" end
    if not megaModesEnabled() then return nil, "mega-option" end
    if not leagueReady(game) then return nil, "pre-league" end
    if not (mega.hasRing and mega.hasRing(game)) then return nil, "ring" end
    if type(tier) == "table" and tonumber(tier.lossRelief or 0) > 0 then
      return nil, "relief"
    end
    if hash(token .. ":mega-roll") % M.ODDS ~= 0 then return nil, "roll" end
    local candidates = {}
    for index, mon in ipairs(type(team) == "table" and team or {}) do
      if (tonumber(mon.level) or 0) >= M.MIN_LEVEL then
        for _, profile in ipairs(type(mega.forms) == "table" and mega.forms or {}) do
          if profile.species == mon.species and profile.secret ~= true
              and entitlement(game, mon.species, profile.id) then
            candidates[#candidates + 1] = { index = index, profile = profile }
          end
        end
      end
    end
    if #candidates == 0 then return nil, "no-entitled-candidate" end
    local selected = candidates[hash(token .. ":mega-pick") % #candidates + 1]
    return {
      version = 1, species = selected.profile.species,
      form = selected.profile.id, stone = selected.profile.stone,
      slot = selected.index,
    }
  end

  function M.validate(game, plan, team)
    if type(plan) ~= "table" or plan.version ~= 1
        or type(plan.species) ~= "string" or type(plan.form) ~= "string"
        or type(plan.stone) ~= "string" then return false, "plan" end
    local profile = entitlement(game, plan.species, plan.form)
    if not profile or profile.stone ~= plan.stone then return false, "entitlement" end
    local found = false
    for _, mon in ipairs(type(team) == "table" and team or {}) do
      if mon.species == plan.species and (tonumber(mon.level) or 0) >= M.MIN_LEVEL
          and (tonumber(mon.hp) or 1) > 0 then found = true break end
    end
    return found, found and nil or "team"
  end

  function M.apply(game, battle, active)
    local plan = active and active.mega
    local valid, why = M.validate(game, plan,
      battle and battle.enemyParty or active and active.team)
    if not valid then return false, why end
    battle.ascendantEnemyMegaSpecies = plan.species
    battle.ascendantEnemyMegaForm = plan.form
    battle.ascendantSurpriseMega = true
    return true
  end

  function M.telegraph(plan)
    if type(plan) ~= "table" then return nil end
    return tr(
      "WANDERER:\nMy KEY STONE is ready.\fIf " .. tostring(plan.species)
        .. " enters battle, expect its Mega Evolution!",
      "WANDERTRAINER:\nMein SCHLÜSSEL-STEIN ist bereit.\fWenn "
        .. tostring(plan.species)
        .. " kämpft, rechne mit seiner Mega-Entwicklung!")
  end

  M.enabled = enabled
  M.entitlement = entitlement
  return M
end
