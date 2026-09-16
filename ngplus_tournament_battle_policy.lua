-- Final battle-policy boundaries for World Rank tournaments.

return function(opts)
  opts = opts or {}
  local P = {}

  local function tr(en, de)
    if type(opts.text) == "function" then
      local ok, value = pcall(opts.text, en, de)
      if ok and type(value) == "string" then return value end
    end
    return en
  end

  local function blocked(battle)
    return battle and battle.ascendantTournament == true
      and battle.ascendantNoItems == true
  end

  local function blockedText()
    return tr(
      "Tournament law seals every item for both sides. Nothing was consumed.",
      "Das Turniergesetz versiegelt alle Items für beide Seiten. Nichts wurde verbraucht.")
  end

  function P.apply(battle, roster)
    if type(battle) ~= "table" then return nil end
    local policy = roster and roster.policy or {}
    battle.ascendantTournament = true
    battle.ascendantNoItems = true
    battle.ascendantEnemyItems = false
    battle.aiUses = 0
    battle.ascendantNoMega = policy.noMega == true
    battle.ascendantMegaMode = policy.megaMode
    if roster and roster.mega and not battle.ascendantNoMega then
      battle.ascendantEnemyMegaSlot = roster.mega.slot
      battle.ascendantEnemyMegaSpecies = roster.mega.species
      battle.ascendantEnemyMegaStone = roster.mega.stone
      battle.ascendantEnemyMegaForm = roster.mega.form
    end
    return battle
  end

  function P.install(deps)
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    local BagMenu = deps.bagMenu or require("src.ui.BagMenu")
    local ItemEffects = deps.itemEffects or require("src.inventory.ItemEffects")

    if not BattleState._kaWorldRankItemsWrapped then
      local original = BattleState.openItems
      BattleState.openItems = function(battle, ...)
        if blocked(battle) then return nil end
        return original(battle, ...)
      end
      BattleState._kaWorldRankItemsWrapped = true
    end

    if not BagMenu._kaWorldRankItemsWrapped then
      local original = BagMenu.new
      BagMenu.new = function(game, menuOpts)
        menuOpts = menuOpts or {}
        local list = original(game, menuOpts)
        if not blocked(menuOpts.battle) then return list end
        list.ascendantTournamentItemsBlocked = true
        local deny = function()
          if type(opts.notify) == "function" then
            pcall(opts.notify, game, blockedText())
          end
          return false
        end
        list.onChoose, list.onSelectKey, list.onStartKey = deny, deny, deny
        return list
      end
      BagMenu._kaWorldRankItemsWrapped = true
    end

    if not ItemEffects._kaWorldRankItemsWrapped then
      local original = ItemEffects.use
      ItemEffects.use = function(data, save, itemId, target, battle, ...)
        if blocked(battle) then
          return "failed", { blockedText() },
            { ascendantTournamentItemsBlocked = true }
        end
        return original(data, save, itemId, target, battle, ...)
      end
      ItemEffects._kaWorldRankItemsWrapped = true
    end
    return true
  end

  P.blocked = blocked
  P.blockedText = blockedText
  return P
end
