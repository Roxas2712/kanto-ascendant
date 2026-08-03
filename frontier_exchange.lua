-- Ascendant Frontier Exchange.
--
-- This module never edits the Ascendant save table directly. The Frontier
-- controller must expose a tiny wallet API:
--   getFrontierPoints() -> non-negative integer
--   spendFrontierPoints(amount) -> true on success, false when insufficient
--
-- Exact ascendant.lua integration (next to the other E.* exports):
--   E.getFrontierPoints = function()
--     return state().frontierPoints
--   end
--   E.spendFrontierPoints = function(amount)
--     amount = math.floor(tonumber(amount) or 0)
--     if amount < 1 then return false end
--     local s = state()
--     if s.frontierPoints < amount then return false end
--     s.frontierPoints = s.frontierPoints - amount
--     persist(s)
--     return true
--   end
--
-- main.lua then constructs this controller after Ascendant and Johto
-- Research exist, passes those controllers plus fieldTech, calls
-- daycare.setFrontierExchange(exchange), and exports/installs the result.
--
-- Keeping that ownership boundary makes purchases atomic and lets every
-- points award remain inside ascendant.lua.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local wallet = opts.wallet or opts.ascendant
  local research = opts.johtoResearch
  local fieldTech = opts.fieldTech
  local postgame = opts.postgame
  local X = {
    game = nil,
    walletRequirements = {
      "getFrontierPoints() -> integer",
      "spendFrontierPoints(amount) -> boolean",
    },
  }

  local EVOLUTION_ITEMS = {
    { id = "SUN_STONE", price = 6, milestone = 3 },
    { id = "KINGS_ROCK", price = 8, milestone = 7 },
    { id = "METAL_COAT", price = 8, milestone = 11 },
    { id = "DRAGON_SCALE", price = 10, milestone = 15 },
    { id = "UPGRADE", price = 10, milestone = 19 },
  }
  local TM_PRICE = 3

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state(create)
    local s = mod.save:get("frontier_exchange")
    if type(s) ~= "table" and create ~= false then
      s = { version = 1, purchases = {}, pointsSpent = 0 }
      mod.save:set("frontier_exchange", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.purchases = type(s.purchases) == "table" and s.purchases or {}
      s.pointsSpent = math.max(0,
        math.floor(tonumber(s.pointsSpent) or 0))
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("frontier_exchange", s) end
  end

  local function walletReady()
    return type(wallet) == "table"
      and type(wallet.getFrontierPoints) == "function"
      and type(wallet.spendFrontierPoints) == "function"
  end

  local function getPoints()
    if not walletReady() then return nil, "wallet_api_missing" end
    local points = tonumber(wallet.getFrontierPoints())
    if not points then return nil, "wallet_api_invalid" end
    return math.max(0, math.floor(points))
  end

  local function hasHallOfFame(save)
    return save and ((type(save.hallOfFame) == "table"
      and #save.hallOfFame > 0)
      or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) or false
  end

  local function available(game)
    if not walletReady() then return false end
    local points = getPoints() or 0
    if postgame and type(postgame.state) == "function" then
      local s = postgame.state(false)
      if type(s) == "table" then
        -- Frontier access follows the authored Crown unlock. Retained points
        -- also keep old/NG+ saves from losing the Exchange entry.
        return s.crownChampion == true or points > 0
      end
    end
    return points > 0 or hasHallOfFame(game and game.save)
  end

  local function spendPoints(amount)
    if not walletReady() then return false, "wallet_api_missing" end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return true end
    return wallet.spendFrontierPoints(amount) == true
  end

  local function researchItemUnlocked(itemId)
    if type(opts.researchItemUnlocked) == "function" then
      return opts.researchItemUnlocked(itemId) == true
    end
    if research and type(research.itemUnlocked) == "function" then
      return research.itemUnlocked(itemId) == true
    end
    local s = research and type(research.state) == "function"
      and research.state(false) or nil
    for key, claimed in pairs(s and s.itemsClaimed or {}) do
      if claimed and (key == itemId
          or tostring(key):sub(-#itemId - 1) == ":" .. itemId) then
        return true
      end
    end
    return false
  end

  local function itemName(game, itemId)
    local item = game and game.data and game.data.items
      and game.data.items[itemId]
    return item and item.name or itemId:gsub("_", " ")
  end

  local function archivedSet(game)
    local set = {}
    if fieldTech and type(fieldTech.archivedTMs) == "function" then
      for _, row in ipairs(fieldTech.archivedTMs(game) or {}) do
        set[row.id] = row
      end
    end
    return set
  end

  local function transaction(game, itemId, price, purchaseKey)
    local points, walletError = getPoints()
    if not points then return false, walletError end
    if points < price then return false, "points" end
    game.save.inventory = game.save.inventory or {}
    local Bag = require("src.inventory.Bag")
    if not Bag.add(game.save, itemId, 1, game.data) then
      return false, "bag"
    end
    -- Add first so a full BAG can never consume points. If the wallet
    -- rejects the debit, roll the item back immediately.
    if not spendPoints(price) then
      Bag.remove(game.save, itemId, 1)
      return false, "points"
    end
    local s = state()
    purchaseKey = purchaseKey or itemId
    s.purchases[purchaseKey] =
      math.max(0, math.floor(tonumber(s.purchases[purchaseKey]) or 0)) + 1
    s.pointsSpent = s.pointsSpent + price
    persist(s)
    return true
  end

  local function resultText(game, ok, reason, itemId, price)
    if ok then
      local points = getPoints()
      return tr(
        ("Exchange complete!\fYou received %s.\f%d FRONTIER POINTS\nremain."):format(
          itemName(game, itemId), points or 0),
        ("Tausch abgeschlossen!\fDu erhältst %s.\f%d FRONTIER-PUNKTE\nbleiben."):format(
          itemName(game, itemId), points or 0))
    end
    if reason == "locked" then
      return tr(
        "ELM has not released\nthat research item yet.",
        "LIND hat dieses\nForschungsitem noch\nnicht freigegeben.")
    elseif reason == "unarchived" then
      return tr(
        "That TM has not entered\nyour archive yet.",
        "Diese TM ist noch nicht\nin deinem Archiv.")
    elseif reason == "bag" then
      return tr(
        "The BAG cannot hold\nthat item.",
        "Der BEUTEL kann dieses\nItem nicht aufnehmen.")
    elseif reason == "wallet_api_missing"
        or reason == "wallet_api_invalid" then
      return tr(
        "The Frontier wallet is\nnot connected yet.",
        "Die Frontier-Börse ist\nnoch nicht verbunden.")
    end
    return tr(
      ("You need %d FRONTIER\nPOINTS for that."):format(price or 0),
      ("Dafür brauchst du %d\nFRONTIER-PUNKTE."):format(price or 0))
  end

  function X.catalog(game)
    local rows = {}
    for _, def in ipairs(EVOLUTION_ITEMS) do
      rows[#rows + 1] = {
        id = def.id,
        price = def.price,
        milestone = def.milestone,
        unlocked = researchItemUnlocked(def.id),
        available = game and game.data and game.data.items
          and game.data.items[def.id] ~= nil,
      }
    end
    return rows
  end

  function X.tmCatalog(game)
    local rows = {}
    for _, row in pairs(archivedSet(game)) do
      rows[#rows + 1] = {
        id = row.id, number = row.number, price = TM_PRICE, unlocked = true,
      }
    end
    table.sort(rows, function(a, b)
      if a.number == b.number then return a.id < b.id end
      return a.number < b.number
    end)
    return rows
  end

  function X.buyEvolutionItem(game, itemId)
    local selected
    for _, row in ipairs(EVOLUTION_ITEMS) do
      if row.id == itemId then selected = row break end
    end
    if not selected or not researchItemUnlocked(itemId) then
      return false, resultText(game, false, "locked", itemId,
        selected and selected.price)
    end
    local ok, reason = transaction(
      game, itemId, selected.price, "ITEM:" .. itemId)
    return ok, resultText(game, ok, reason, itemId, selected.price)
  end

  function X.buyArchivedTM(game, itemId)
    if not archivedSet(game)[itemId] then
      return false, resultText(
        game, false, "unarchived", itemId, TM_PRICE)
    end
    local ok, reason = transaction(
      game, itemId, TM_PRICE, "TM:" .. itemId)
    return ok, resultText(game, ok, reason, itemId, TM_PRICE)
  end

  function X.statusText()
    local points, reason = getPoints()
    if not points then
      return resultText(nil, false, reason)
    end
    return tr(
      ("FRONTIER EXCHANGE\nPoints: %d\fResearch items renew\nafter ELM releases them."):format(points),
      ("FRONTIER-TAUSCH\nPunkte: %d\fForschungsitems werden\nnach LINDs Freigabe erneuert."):format(points))
  end

  local function show(game, text, done)
    game.stack:push(require("src.render.TextBox").new(game, text, done))
  end

  local function evolutionMenu(game)
    local rows = {}
    for _, entry in ipairs(X.catalog(game)) do
      if entry.available then
        rows[#rows + 1] = {
          label = itemName(game, entry.id),
          right = entry.unlocked and (tostring(entry.price) .. "P") or "---",
          value = entry,
        }
      end
    end
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("RESEARCH ITEMS", "FORSCHUNGSITEMS"), rows, {
        onChoose = function(item)
          local ok, text = X.buyEvolutionItem(game, item.value.id)
          show(game, text)
        end,
      }))
  end

  local function tmMenu(game)
    local rows = {}
    for _, entry in ipairs(X.tmCatalog(game)) do
      rows[#rows + 1] = {
        label = itemName(game, entry.id),
        right = tostring(entry.price) .. "P",
        value = entry.id,
      }
    end
    if #rows == 0 then
      show(game, tr(
        "Earn a TM from the\narchive before selecting\nrenewable copies.",
        "Verdiene zuerst eine TM\nim Archiv, bevor du\nKopien auswählst."))
      return
    end
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("TM LIBRARY", "TM-BIBLIOTHEK"), rows, {
        pageJump = true,
        onChoose = function(item)
          local ok, text = X.buyArchivedTM(game, item.value)
          show(game, text)
        end,
      }))
  end

  function X.open(game, done)
    X.game = game
    local rows = {
      {
        label = tr("RESEARCH ITEMS", "FORSCHUNGSITEMS"),
        value = "items",
      },
      { label = tr("TM LIBRARY", "TM-BIBLIOTHEK"), value = "tms" },
      { label = tr("STATUS", "STATUS"), value = "status" },
      { label = tr("CANCEL", "ZURÜCK"), value = "cancel" },
    }
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("FRONTIER EXCHANGE", "FRONTIER-TAUSCH"), rows, {
        onCancel = done,
        onChoose = function(item, menu)
          if item.value == "items" then
            evolutionMenu(game)
          elseif item.value == "tms" then
            tmMenu(game)
          elseif item.value == "status" then
            show(game, X.statusText())
          else
            menu:close()
            if done then done() end
          end
        end,
      }))
  end

  function X.install(game)
    X.game = game
    state()
  end

  mod.hooks:wrap("ui.start_menu.items",
    function(nextItems, game, items)
      local out = nextItems(game, items)
      if type(out) ~= "table" or not available(game) then return out end
      return mod.ui.insertBefore(out, "SAVE", {
        label = tr("FRONTIER", "FRONTIER"),
        ascendantMenu = true,
        ascendantLabel = tr("FRONTIER EXCHANGE", "FRONTIER-TAUSCH"),
        ascendantOrder = 75,
        onSelect = function() X.open(game, function() end) end,
      })
    end, 258)

  X.state = state
  X.walletReady = walletReady
  X.available = available
  X.getPoints = getPoints
  X.spendPoints = spendPoints
  X.researchItemUnlocked = researchItemUnlocked
  X.itemPrices = EVOLUTION_ITEMS
  X.tmPrice = TM_PRICE
  return X
end
