-- Installs the shared FireRed Bag presentation without taking ownership of
-- Bag behaviour.  The engine keeps USE/TOSS and battle use; this wrapper
-- supplies bilingual item help and stable ordering for every Gen-I item list
-- (Bag, Player PC, mart BUY/SELL). The field Bag keeps the original SELECT
-- mark/place gesture and opens help on START; PC and mart lists retain their
-- established storage-specific controls.

return function(mod, opts)
  opts = opts or {}
  local ui = assert(opts.ui, "Ascendant UI required")
  local itemHelp = assert(opts.itemHelp, "item help required")
  local BagMenu = require("src.ui.BagMenu")
  local Bag = require("src.inventory.Bag")

  local function tr(en, de)
    return ui.tr and ui.tr(en, de) or en
  end

  local function syncPcOrder(save)
    local store = save.pcItems or {}
    local order = save.pcOrder
    if type(order) ~= "table" then
      order = {}
      for id in pairs(store) do order[#order + 1] = id end
      table.sort(order)
      save.pcOrder = order
    end
    local seen = {}
    for index = #order, 1, -1 do
      local id = order[index]
      if not store[id] or seen[id] then
        table.remove(order, index)
      else
        seen[id] = true
      end
    end
    local missing = {}
    for id in pairs(store) do
      if not seen[id] then missing[#missing + 1] = id end
    end
    table.sort(missing)
    for _, id in ipairs(missing) do order[#order + 1] = id end
    return order
  end

  local function reorderRows(rows, order)
    local rank = {}
    for index, id in ipairs(order) do rank[id] = index end
    table.sort(rows, function(a, b)
      local ra, rb = rank[a.value], rank[b.value]
      if ra == rb then return tostring(a.value) < tostring(b.value) end
      return (ra or math.huge) < (rb or math.huge)
    end)
  end

  local function swapOrder(order, first, second)
    if not first or not second or first == second then return false end
    local fi, si
    for index, id in ipairs(order) do
      if id == first then fi = index elseif id == second then si = index end
      if fi and si then break end
    end
    if not (fi and si) then return false end
    order[fi], order[si] = order[si], order[fi]
    return true
  end

  local function itemTitle(game, item)
    local def = item and game.data and game.data.items
      and game.data.items[item.value]
    return (item and item.label) or (def and def.name)
      or tostring(item and item.value or "ITEM")
  end

  local function showInfo(game, item, policy)
    if not item then return false end
    return policy.ui.showHelp(game, itemTitle(game, item),
      policy.itemHelp.describe(game, item.value))
  end

  local PC_KINDS = {
    pc_item_withdraw = true,
    pc_item_deposit = true,
    pc_item_toss = true,
  }
  local SHOP_KINDS = { shop_buy = true, shop_sell = true }

  -- Gen1 Recomp 0.1.86 exposes SELECT on ListMenu, but it does not dispatch
  -- START.  Keep the compatibility seam on the individual decorated list so
  -- unrelated menus remain byte-for-byte vanilla.  Returning immediately
  -- after the callback also prevents a future/native START dispatcher from
  -- seeing the same edge twice.
  local function installStartDispatcher(list)
    if list.__kantoAscendantStartDispatcher then return end
    local previousUpdate = list.update
    list.update = function(current, dt)
      local input = current.game and current.game.input
      if current.onStartKey and #current.items > 0
          and input and input.wasPressed
          and input:wasPressed("start") then
        current.onStartKey(current.items[current.index], current)
        return
      end
      return previousUpdate(current, dt)
    end
    list.__kantoAscendantStartDispatcher = true
  end

  local function decoratePcItemList(list, game, policy, stableKind)
    list.kind = stableKind or list.kind
    local order = list.kind == "pc_item_deposit"
      and Bag.order(game.save) or syncPcOrder(game.save)
    reorderRows(list.items, order)
    list.__ascendantItemOrder = order
    list.__ascendantItemHelp = true
    list.controlHint = tr("SELECT: INFO\nSTART: MOVE",
      "SELECT: INFO\nSTART: TAUSCH")

    list.onSelectKey = function(item)
      return showInfo(game, item, policy)
    end

    local function finishMove(l)
      local marked = l.items[l.swapIndex]
      local current = l.items[l.index]
      if marked and current
          and swapOrder(l.__ascendantItemOrder, marked.value, current.value) then
        local Sound = require("src.core.Sound")
        if game.data then Sound.play(game.data, "Swap") end
        reorderRows(l.items, l.__ascendantItemOrder)
      end
      l.swapIndex = nil
    end

    list.onStartKey = function(item, l)
      if not item then return end
      if not l.swapIndex then
        l.swapIndex = l.index
      else
        finishMove(l)
      end
    end
    installStartDispatcher(list)

    local vanillaChoose = list.onChoose
    list.onChoose = function(item, l)
      if l.swapIndex then
        finishMove(l)
        return
      end
      return vanillaChoose and vanillaChoose(item, l)
    end

    -- B first cancels a pending move and keeps the PC list open.  A second B
    -- takes the normal engine path back to the Player PC menu.
    local vanillaUpdate = list.update
    list.update = function(l, dt)
      local input = l.game and l.game.input
      if l.swapIndex and input and input.wasPressed
          and input:wasPressed("b") then
        l.swapIndex = nil
        return
      end
      return vanillaUpdate(l, dt)
    end
  end

  local function decorateShopItemList(list, game, policy, stableKind)
    -- Stock 0.1.86 does not pass a kind for mart lists.  Normalize the two
    -- known titles after construction so help/actions can use one contract
    -- on both the stock and newer ListMenu implementations.
    list.kind = stableKind or list.kind
    list.__ascendantItemHelp = true
    list.onSelectKey = function(item)
      return showInfo(game, item, policy)
    end
  end

  -- v0.1.79 exposes stable list kinds for PlayerPC and ShopMenu.  Keep title
  -- fallbacks for older engine builds so a mismatched local install remains
  -- useful instead of losing SELECT help entirely.
  local ListMenu = require("src.ui.ListMenu")
  if not ListMenu._kantoAscendantItemHelpWrapped then
    local originalListNew = ListMenu.new
    ListMenu.new = function(game, title, items, listOpts)
      local list = originalListNew(game, title, items, listOpts)
      local policy = ListMenu._kantoAscendantItemHelpPolicy
      if not policy then return list end
      local kind = list.kind
      if PC_KINDS[kind]
          or title == "WITHDRAW ITEM" or title == "DEPOSIT ITEM"
          or title == "TOSS ITEM" then
        local stableKind = PC_KINDS[kind] and kind
          or (title == "WITHDRAW ITEM" and "pc_item_withdraw")
          or (title == "DEPOSIT ITEM" and "pc_item_deposit")
          or "pc_item_toss"
        decoratePcItemList(list, game, policy, stableKind)
      elseif SHOP_KINDS[kind]
          or title == "BUY" or title == "SELL" then
        decorateShopItemList(list, game, policy,
          title == "BUY" and "shop_buy" or "shop_sell")
      end
      return list
    end
    ListMenu._kantoAscendantItemHelpWrapped = true
  end
  ListMenu._kantoAscendantItemHelpPolicy = { ui = ui, itemHelp = itemHelp }

  if not BagMenu._kantoAscendantBagWrapped then
    local originalNew = BagMenu.new
    BagMenu.new = function(game, bagOpts)
      local list = originalNew(game, bagOpts)
      local policy = BagMenu._kantoAscendantBagPolicy
      if not policy then return list end
      list.kind = list.kind or "bag"
      list = policy.ui.decorateBag(list, function(item)
        return policy.itemHelp.describe(game, item and item.value)
      end)
      -- Bag owners use this explicit translator for secondary action labels.
      -- Keeping it on the list avoids guessing the active language from
      -- wrapper order or from engine-global state.
      list.__ascendantTr = policy.ui.tr
      -- START is the explicit readable item-info action in Ascendant's Bag.
      -- Useful Bag consumes the same seam after projecting its pockets.
      list.__ascendantShowItemInfo = function(item)
        if not item then return false end
        local title = item.label or (game.data.items[item.value]
          and game.data.items[item.value].name) or tostring(item.value)
        return policy.ui.showHelp(game, title,
          policy.itemHelp.describe(game, item.value))
      end
      -- Preserve the engine's classic SELECT mark/place callback. START owns
      -- help, so the two actions never compete for the same edge.
      local reorder = list.onSelectKey
      list.onSelectKey = function(item, current)
        if reorder then return reorder(item, current) end
      end
      list.onStartKey = function(item, current)
        return list.__ascendantShowItemInfo(item)
      end
      installStartDispatcher(list)

      -- A marked row is a pending transaction. B cancels it without closing;
      -- with no marker the normal ListMenu B path still exits the Bag.
      local previousUpdate = list.update
      list.update = function(current, dt)
        local input = current.game and current.game.input
        if current.swapIndex and input and input.wasPressed
            and input:wasPressed("b") then
          current.swapIndex = nil
          return
        end
        return previousUpdate(current, dt)
      end
      list.__ascendantBagSecondary = "move"
      return list
    end
    BagMenu._kantoAscendantBagWrapped = true
  end

  BagMenu._kantoAscendantBagPolicy = { ui = ui, itemHelp = itemHelp }
  return { installed = true }
end
