-- Useful Bag: 999-capacity bag with auto-sorted pockets.
--
-- The bag is split into six pockets -- ITEMS, MEDICINE, POKé BALLS,
-- TMs / HMs, BATTLE ITEMS and KEY ITEMS -- that the player cycles with
-- LEFT / RIGHT (wrapping at the ends).  TAB (keyboard) or R3 / right stick
-- click (controller) still opens the SORT BY NAME / SORT BY COUNT prompt,
-- and Up on the first item / Down on the last item wraps around.
--
-- The in-battle bag is battle-aware: it opens on the BATTLE ITEMS pocket
-- (or the first non-empty usable pocket) and its L/R cycling skips TMs /
-- HMs and KEY ITEMS, whose items ItemEffects refuses mid-battle.
--
-- THE HIDDEN BAG: the engine's item logic (key-item flags, scripted
-- CheckItem/TakeItem/GiveItem, the CARD_KEY door, HM gates) reads the flat
-- save.inventory + Bag.order, never a menu selection.  So this mod keeps a
-- canonical "hidden bag" -- the full, unfiltered item order -- and every
-- pocket is only a *projection* of it.  Nothing is moved out of
-- save.inventory into pocket storage, so key items keep working no matter
-- which pocket the player closed the bag on: deposit a key item in the PC
-- and it leaves the hidden bag (and the KEY ITEMS pocket) because
-- Bag.remove wrote the real inventory; use a potion and the hidden count
-- matches the MEDICINE pocket because both read the same save.inventory.
--
-- The capacity half is two one-line registry patches: the bag limit
-- (Data.constants.bagSize; Bag.capacity consults it) and the PC storage
-- cap (Data.field.pcItemCap; PlayerPC.pcFull consults it).
--
-- The pocket half rides the ui.screens registry: a registered "BagMenu"
-- wins over the builtin require fallback (src/ui/Screens.lua), so both
-- openers -- the start menu and the battle bag -- get the pocketed list.
-- The factory builds the vanilla bag (all its USE/TOSS/quantity/learn
-- flows stay engine-owned) and then decorates the returned ListMenu:
-- L/R pocket switching, pocket-safe SELECT reordering (pocket rows map
-- back onto the hidden bagOrder), a self-healing projection that re-applies
-- the pocket whenever an engine rebuild (e.g. after a toss) resets the rows
-- to the full bag, and the TAB/R3 sort prompt.  Input is wrapped at
-- game.ready so TAB (normally SELECT / swap-item) and R3 (unbound) reach
-- the bag; shift keys still do the vanilla SELECT item-swap.  The same
-- game.ready wrap catches the PC's WITHDRAW / DEPOSIT / TOSS lists where
-- they are built and restores the vanilla SELECT item-swap there too
-- (save.pcOrder for the storage lists, save.bagOrder for the deposit
-- list).
--
-- Both the bag pockets and the PC lists label machine items with their
-- full name ("TM14 BLIZZARD"); the "TM14 " part stays pinned and only the
-- move name scrolls as the horizontal ticker (the MoveRelearn pacing the
-- other option-row mods use) when it is too wide for the row window.

local Bag = require("src.inventory.Bag")

local SORT_MODE_LABELS = { "SORT BY NAME", "SORT BY COUNT" }

-- ------------------------------------------------ pure layer

local POCKETS = {
  { id = "items",    label = "ITEMS" },
  { id = "medicine", label = "MEDICINE" },
  { id = "balls",    label = "POKé BALLS" },
  { id = "tms",      label = "TMs / HMs" },
  { id = "battle",   label = "BATTLE ITEMS" },
  { id = "key",      label = "KEY ITEMS" },
}

local POCKET_INDEX = {}
for i, p in ipairs(POCKETS) do POCKET_INDEX[p.id] = i end

-- a battle bag skips the pockets whose items are unusable mid-battle:
-- TMs/HMs and KEY ITEMS are refused by ItemEffects ("isn't the time to
-- use that"), so they would only waste L/R presses.  When the bag opens
-- in battle it lands on the first non-empty pocket in BATTLE_START_PRIORITY.
local BATTLE_UNUSABLE = { tms = true, key = true }
local BATTLE_START_PRIORITY = { "battle", "balls", "medicine", "items" }

-- fallback sets: the real ROM import flags key items via KeyItemFlags
-- (def.keyItem) and TMs/HMs via def.machine, so these only classify
-- fixture/mod-added items that carry no such flag.  They mirror the same
-- sets the engine hardcodes (ItemEffects.BALLS, item_effects.asm).
--
-- KEY_ITEMS is the game's own KeyItemFlags table (ROM symbols; identical
-- in pret/pokered and pret/pokeyellow data/items/key_items.asm) -- the
-- same bytes the engine's RomExtractor reads to stamp def.keyItem.  In
-- the real data def.keyItem is authoritative; this set mirrors it so
-- fixture/mod items with no flag classify the same way.  The eight badges
-- are flagged too but never appear in the bag (Bag.isBadge excludes them).
-- Note ESCAPE_ROPE and EXP_ALL are NOT key items per the game.
local KEY_ITEMS = {
  TOWN_MAP = true, BICYCLE = true, SURFBOARD = true, SAFARI_BALL = true,
  POKEDEX = true,
  BOULDERBADGE = true, CASCADEBADGE = true, THUNDERBADGE = true,
  RAINBOWBADGE = true, SOULBADGE = true, MARSHBADGE = true,
  VOLCANOBADGE = true, EARTHBADGE = true,
  OLD_AMBER = true, DOME_FOSSIL = true, HELIX_FOSSIL = true,
  SECRET_KEY = true, ITEM_2C = true, BIKE_VOUCHER = true,
  CARD_KEY = true,
  S_S_TICKET = true, GOLD_TEETH = true, COIN_CASE = true, OAKS_PARCEL = true,
  ITEMFINDER = true, SILPH_SCOPE = true, POKE_FLUTE = true, LIFT_KEY = true,
  OLD_ROD = true, GOOD_ROD = true, SUPER_ROD = true,
}

local MEDICINE = {
  POTION = true, SUPER_POTION = true, HYPER_POTION = true, MAX_POTION = true,
  FRESH_WATER = true, SODA_POP = true, LEMONADE = true,
  ANTIDOTE = true, BURN_HEAL = true, ICE_HEAL = true, AWAKENING = true,
  PARLYZ_HEAL = true, FULL_HEAL = true, FULL_RESTORE = true,
  REVIVE = true, MAX_REVIVE = true, RARE_CANDY = true,
  HP_UP = true, PROTEIN = true, IRON = true, CARBOS = true, CALCIUM = true,
  ETHER = true, MAX_ETHER = true, ELIXER = true, MAX_ELIXER = true, PP_UP = true,
}

local BATTLE_ITEMS = {
  X_ATTACK = true, X_DEFEND = true, X_SPEED = true, X_SPECIAL = true,
  X_ACCURACY = true, DIRE_HIT = true, GUARD_SPEC = true, POKE_DOLL = true,
}

local BALLS = {
  POKE_BALL = true, GREAT_BALL = true, ULTRA_BALL = true,
  MASTER_BALL = true, SAFARI_BALL = true,
}

local function isMachine(id, def)
  if def and def.machine then return true end
  local head = id:sub(1, 2)
  return head == "TM" or head == "HM"
end

-- Which pocket an item id lives in.  Key items win (a key item is never
-- also a TM or ball), then TMs/HMs, balls, medicine, battle items, and
-- everything else falls into the generic ITEMS pocket.
local function classify(data, id)
  local def = data.items and data.items[id]
  if (def and def.keyItem) or KEY_ITEMS[id] then return "key" end
  if isMachine(id, def) then return "tms" end
  if (def and def.ball) or BALLS[id] then return "balls" end
  if MEDICINE[id] then return "medicine" end
  if BATTLE_ITEMS[id] then return "battle" end
  return "items"
end

-- The ids in `order` (an array of item ids, e.g. Bag.order(save)) that
-- belong to a pocket.  Keeps the incoming order, so pockets follow the
-- bag's current sort (acquisition order, or the TAB/R3 name/count sort).
local function pocketItems(order, data, pocketId)
  local out = {}
  for _, id in ipairs(order) do
    if classify(data, id) == pocketId then table.insert(out, id) end
  end
  return out
end

-- THE HIDDEN BAG: the canonical flat bag, acquisition-ordered, always
-- complete.  Pockets are projections of this; engine logic reads it via
-- save.inventory.  Bag.order maintains it incrementally, so PC deposits,
-- uses and tosses all land here first.
local function hiddenOrder(save)
  return Bag.order(save)
end

-- The id of the pocket `dir` steps away from `from` (a POCKETS index),
-- wrapping around at both ends.  dir = -1 is LEFT, +1 is RIGHT.
local function adjacentPocket(from, dir)
  local n = #POCKETS
  return ((from - 1 + dir) % n) + 1
end

-- Move a pocketed list to the neighbouring pocket (wraps).  In a battle
-- bag (`list.__battle` set) the unusable pockets are skipped, so L/R
-- cycles only through the battle-usable ones.  Mutates the ListMenu in
-- place: clears any pending SELECT-swap and re-projects its rows from the
-- hidden bag.  `list.__project` is installed by decorate().
local function switchPocket(list, dir)
  list.swapIndex = nil
  local battle = list.__battle
  local i = list.__pocketIndex
  repeat
    i = adjacentPocket(i, dir)
  until (not battle or not BATTLE_UNUSABLE[POCKETS[i].id])
    or i == list.__pocketIndex -- safety: never spin forever
  list.__pocketIndex = i
  list.__project()
  list.index = 1
end

-- Pure: the sorted id list for `mode` ("name" | "count") over the hidden
-- bag.  The name sort compares item names with an id tiebreak (stable);
-- the count sort puts the biggest stacks first, id tiebreak.  Returns a
-- fresh list -- the save's bagOrder is left untouched.
local function computeOrder(save, data, mode)
  local order = {}
  for _, id in ipairs(hiddenOrder(save)) do table.insert(order, id) end
  local inv = save.inventory
  if mode == "count" then
    table.sort(order, function(a, b)
      local ca, cb = inv[a] or 0, inv[b] or 0
      if ca == cb then return a < b end
      return ca > cb
    end)
  else -- "name"
    table.sort(order, function(a, b)
      local da, db = data.items[a], data.items[b]
      local na, nb = (da and da.name) or a, (db and db.name) or b
      if na == nb then return a < b end
      return na < nb
    end)
  end
  return order
end

-- Applies a sort to the live hidden bag: Bag.order returns save.bagOrder
-- itself, so sorting it in place is the whole write.
local function applySort(save, data, mode)
  local order = hiddenOrder(save)
  if mode == "count" then
    local inv = save.inventory
    table.sort(order, function(a, b)
      local ca, cb = inv[a] or 0, inv[b] or 0
      if ca == cb then return a < b end
      return ca > cb
    end)
  else
    table.sort(order, function(a, b)
      local da, db = data.items[a], data.items[b]
      local na, nb = (da and da.name) or a, (db and db.name) or b
      if na == nb then return a < b end
      return na < nb
    end)
  end
end

-- The PC storage's acquisition order (like Bag.order): the ids of
-- save.pcItems in display order, persisted in save.pcOrder (GenSave
-- encodes/decodes it alongside pcItems).  Rebuilt sorted once for saves
-- from before the order existed, then maintained incrementally, pruning
-- stale ids (a toss or a withdraw that emptied a stack) and appending new
-- deposits at the end.
local function pcOrder(save)
  local order = save.pcOrder
  if not order then
    order = {}
    for id in pairs(save.pcItems or {}) do table.insert(order, id) end
    table.sort(order)
    save.pcOrder = order
  end
  local seen = {}
  for i = #order, 1, -1 do
    local id = order[i]
    if not save.pcItems[id] or seen[id] then
      table.remove(order, i)
    else
      seen[id] = true
    end
  end
  for id in pairs(save.pcItems or {}) do
    if not seen[id] then table.insert(order, id) end
  end
  return order
end

-- Swap two ids inside an order list (save.pcOrder / save.bagOrder); the
-- SELECT item-swap of the PC lists lands here, writing the real order the
-- engine and GenSave read.  No-op when either id is missing from the list.
local function swapOrder(order, a, b)
  if a == b then return end
  local ia, ib
  for k, id in ipairs(order) do
    if id == a then ia = k elseif id == b then ib = k end
    if ia and ib then break end
  end
  if ia and ib then order[ia], order[ib] = order[ib], order[ia] end
end

-- Re-sort a ListMenu's rows ({ value = item id, ... }) to follow `order`.
-- The rows are the current list's ids (never the hidden bag's full set),
-- so the rank lookup drives the sort; unknown ids sink to the end, id
-- tiebreak keeps it deterministic.
local function reorderItems(items, order)
  local rank = {}
  for i, id in ipairs(order) do rank[id] = i end
  table.sort(items, function(a, b)
    local ra, rb = rank[a.value], rank[b.value]
    if ra == rb then return a.value < b.value end
    return (ra or math.huge) < (rb or math.huge)
  end)
end

-- Ticker pacing (the MoveRelearn name ticker): hold at each end so the
-- player can read the whole name, scroll at 16px/s (half a second per
-- glyph).  The same pacing the other option-row mods use.
local TICKER_HOLD = 1.6
local TICKER_SPEED = 16

-- Pure (mod.exports.tickerOffset for headless tests): horizontal offset
-- for an overflowing label at time t (seconds).  Cycle: hold at 0, scroll
-- out to -overflow, hold, scroll back to 0.  Labels that fit (overflow <=
-- 0) are static.
local function tickerOffset(t, overflow)
  if not (overflow and overflow > 0) then return 0 end
  local scroll = overflow / TICKER_SPEED
  local cycle = 2 * TICKER_HOLD + 2 * scroll
  local p = t % cycle
  if p < TICKER_HOLD then return 0 end
  p = p - TICKER_HOLD
  if p < scroll then return -p * TICKER_SPEED end
  p = p - scroll
  if p < TICKER_HOLD then return -overflow end
  p = p - TICKER_HOLD
  return -overflow + p * TICKER_SPEED
end

-- A list-row label for an item id: the plain name, or the full machine
-- name ("TM14 BLIZZARD") when the item is a TM/HM (def.machine) -- the
-- bag and PC otherwise show only "TM14".  Returns (label, prefixW, prefix,
-- move) where prefix is the "TM14 " part that stays pinned and move is the
-- scrollable name.
local function labelForItem(data, id)
  local def = data.items and data.items[id]
  local name = def and def.name or id
  if def and def.machine then
    local moveId = def.machine.move
    local move = moveId and data.moves and data.moves[moveId]
    local moveName = (move and move.name) or moveId or ""
    local prefix = name .. " "
    local Font = require("src.render.Font")
    return name .. " " .. moveName, Font.width(prefix), prefix, moveName
  end
  return name, 0, nil, nil
end

-- Ticker geometry for a list row: nil when the label fits the window
-- between the label start (16px) and the count value (right-aligned at
-- 152 - width(right), one glyph of gap).  The GB font is a flat 8px per
-- glyph, so the window is (128 - width(right))px.  For a machine row the
-- scrollable part is the move name only: it starts after the pinned
-- prefix (prefixW) and the overflow is the whole label's overflow (the
-- suffix's own overflow is the same number).
local function tickerFor(label, right, prefixW)
  local Font = require("src.render.Font")
  local window = 128 - Font.width(right or "")
  local w = Font.width(label)
  if w <= window then return nil end
  local prefix = prefixW or 0
  return { x = 16 + prefix, w = window - prefix, overflow = w - window }
end

-- ------------------------------------------------ runtime layer

-- TAB/R3 opens a SORT BY NAME / SORT BY COUNT prompt over the bag; both
-- options rewrite the hidden bag's order and re-project the current
-- pocket.  Defined before decorate() because the bag's update closure
-- calls it (Lua binds locals lexically at definition time).
local function openSortPrompt(list, game, session)
  session.sortOpen = true
  local Menu = require("src.ui.Menu")
  game.stack:push(Menu.new(game, {
    { label = SORT_MODE_LABELS[1], onSelect = function()
        session.sortOpen = false
        applySort(game.save, game.data, "name")
        require("src.core.Sound").play(game.data, "Swap")
        list.__project()
      end },
    { label = SORT_MODE_LABELS[2], onSelect = function()
        session.sortOpen = false
        applySort(game.save, game.data, "count")
        require("src.core.Sound").play(game.data, "Swap")
        list.__project()
      end },
  }, { tx = 10, ty = 10, onCancel = function() session.sortOpen = false end }))
end

-- Full TM/HM labels ("TM15 HYPER BEAM") can be wider than a list row's
-- label window, which the vanilla ListMenu.draw leaves unclipped (the text
-- bleeds over the count or the box edge).  Decorate the list with the
-- horizontal name ticker (the MoveRelearn pacing from the other mods):
-- rows whose label overflows get a scissored, time-driven scroll; rows
-- that fit draw exactly as before.  A machine row pins its "TM14 " prefix
-- and scrolls only the move name; every other row scrolls as a whole.
-- Geometry recomputes on every draw so rebuilds (pocket switches, tosses,
-- count changes) stay correct.  A stale blank from an interrupted draw is
-- restored first so a later frame never redraws a permanently-empty label.
local function decorateTickers(list)
  local vanillaUpdate = list.update
  list.update = function(self, dt)
    for _, it in ipairs(self.items) do
      if it.ticker then it.tick = (it.tick or 0) + (dt or 0) end
    end
    return vanillaUpdate(self, dt)
  end

  local vanillaDraw = list.draw
  list.draw = function(self, ...)
    for _, it in ipairs(self.items) do
      if it._label then
        it.label = it._label
        it._label = nil
      end
    end
    local Font = require("src.render.Font")
    local ticked = {}
    for i, it in ipairs(self.items) do
      local ticker = tickerFor(it.label, it.right, it.prefixW)
      it.ticker = ticker
      if ticker then
        it._label = it.label
        it.label = "" -- blanked for the vanilla pass
        ticked[#ticked + 1] = { item = it, index = i, prefix = it.prefix }
      end
    end
    vanillaDraw(self, ...)
    local g = love and love.graphics
    for _, e in ipairs(ticked) do
      local it = e.item
      it.label = it._label
      it._label = nil
      if g and g.setScissor then
        local slot = e.index - (self.scroll or 0)
        if slot >= 1 and slot <= (self.rows or 7) then
          local y = 8 + slot * 16
          -- the TM/number part stays pinned at the row start
          if e.prefix then Font.draw(e.prefix, 16, y) end
          g.setScissor(it.ticker.x, y, it.ticker.w, 8)
          -- scroll only the move name -- never the label again, or the
          -- pinned "TM14 " would duplicate it
          Font.draw(it.move or it.label,
                    it.ticker.x + tickerOffset(it.tick or 0, it.ticker.overflow), y)
          g.setScissor()
        end
      end
    end
  end
end

-- Decorate a vanilla bag ListMenu with pockets, L/R navigation, a
-- pocket-safe SELECT reorder and the sort/wrap behavior.  `session` is the
-- shared bag-session state (one bag open at a time) that the game.ready
-- Input wraps write their TAB/R3 edges into.  `opts` is the bag's open
-- opts: a truthy `opts.battle` (BattleState) marks a battle bag, which
-- opens on BATTLE ITEMS and skips the unusable pockets when cycling.
local function decorate(list, game, session, opts)
  -- pocket view starts on ITEMS
  list.__pocketIndex = 1
  list.wrap = true -- Up on the first / Down on the last item wraps
  list.__battle = opts and opts.battle or nil -- battle bags cycle tighter

  -- Re-project the visible pocket from the hidden bag, preserving the
  -- currently selected item when it is still in this pocket.
  local function project()
    local pocket = POCKETS[list.__pocketIndex]
    local order = hiddenOrder(game.save)
    local curId = list.items[list.index] and list.items[list.index].value
    local items, ids = {}, {}
    for _, id in ipairs(order) do
      if classify(game.data, id) == pocket.id then
        table.insert(ids, id)
        local label, prefixW, prefix, move = labelForItem(game.data, id)
        table.insert(items, {
          value = id,
          label = label,
          prefix = prefix,
          prefixW = prefixW,
          move = move,
          right = "x" .. (game.save.inventory[id] or 0),
        })
      end
    end
    list.items, list.__pocketIds = items, ids
    list.title = pocket.label
    if curId then
      for i, id in ipairs(ids) do
        if id == curId then list.index = i break end
      end
    end
    list.index = math.max(1, math.min(list.index, #items))
  end
  list.__project = project

  -- Swap two pocket rows by translating them back onto the hidden bag's
  -- acquisition order (the engine's onSelectKey swaps `order[l.index]`
  -- directly, which only works because its rows are the full bag).
  local function swapRows(i, j)
    local a, b = list.__pocketIds[i], list.__pocketIds[j]
    if not a or not b then return end
    local order = hiddenOrder(game.save)
    local ia, ib
    for k, id in ipairs(order) do
      if id == a then ia = k elseif id == b then ib = k end
      if ia and ib then break end
    end
    if ia and ib then order[ia], order[ib] = order[ib], order[ia] end
  end

  local vanillaSelect = list.onSelectKey
  list.onSelectKey = function(item, l)
    if not item then return end
    if not l.swapIndex then
      l.swapIndex = l.index
      return
    end
    swapRows(l.swapIndex, l.index)
    l.swapIndex = nil
    require("src.core.Sound").play(game.data, "Swap")
    project()
  end

  local vanillaChoose = list.onChoose
  list.onChoose = function(item, l)
    if l.swapIndex then -- A also completes a pending swap
      swapRows(l.swapIndex, l.index)
      l.swapIndex = nil
      require("src.core.Sound").play(game.data, "Swap")
      project()
      return
    end
    return vanillaChoose(item, l)
  end

  local vanillaUpdate = list.update
  list.update = function(self, dt)
    -- L/R cycle the pockets (wraps); the vanilla list ignores L/R unless
    -- pageJump is on, so these presses are ours to claim
    local input = self.game and self.game.input
    if input and input.wasPressed then
      local left = input:wasPressed("left")
      local right = input:wasPressed("right")
      if left or right then
        switchPocket(self, left and -1 or 1)
        require("src.core.Sound").play(game.data, "Press_AB")
      end
    end
    -- the TAB/R3 sort edge waits for the bag's own update (a stale edge
    -- from a press while another screen was on top is dropped)
    if session.wantSort and session.active == self and not session.sortOpen
       and self.game.stack:top() == self then
      session.wantSort = false
      self.swapIndex = nil -- a pending SELECT-swap would go stale
      openSortPrompt(self, game, session)
    end
    -- self-heal: engine-side rebuilds (the TOSS confirm) reset the rows to
    -- the full hidden bag; re-project when the rows no longer match the
    -- current pocket so the pocket never silently widens
    local matches = #self.items == #self.__pocketIds
    if matches then
      for i = 1, #self.items do
        if self.items[i].value ~= self.__pocketIds[i] then
          matches = false
          break
        end
      end
    end
    if not matches then self.__project() end
    return vanillaUpdate(self, dt)
  end

  local vanillaClose = list.close
  list.close = function(self, ...)
    if session.active == self then session.active = nil end
    return vanillaClose(self, ...)
  end

  -- full TM/HM labels scroll when they overflow their row window
  decorateTickers(list)

  session.active = list
  session.wantSort = false -- presses before the bag opened do not carry over
  -- a battle bag opens on the BATTLE ITEMS pocket (falling back to the
  -- first non-empty usable pocket), not the generic ITEMS; cycling skips
  -- TMs / HMs and KEY ITEMS via switchPocket
  if list.__battle then
    for _, pid in ipairs(BATTLE_START_PRIORITY) do
      list.__pocketIndex = POCKET_INDEX[pid]
      project()
      if #list.items > 0 then break end
    end
  else
    project()
  end
  return list
end

-- The PC's three item lists are plain engine ListMenus (PlayerPC.lua) that
-- never pass onSelectKey, so the vanilla SELECT item-swap (DisplayListMenuID
-- watches PAD_SELECT -> HandleItemListSwapping) is missing there.  Decorate
-- the WITHDRAW / DEPOSIT / TOSS lists with it: SELECT marks a row (hollow
-- cursor), a second SELECT -- or A -- swaps it with the cursor row.
-- Withdraw and Toss reorder the PC storage (save.pcOrder); Deposit reorders
-- the bag (save.bagOrder) because that list shows the bag, matching the
-- original.  The list opens in the stored order (not the engine's
-- alphabetical sort) so a reorder persists visibly across reopening.
local PC_LISTS = { ["WITHDRAW ITEM"] = true, ["DEPOSIT ITEM"] = true, ["TOSS ITEM"] = true }

local function decoratePcList(list, game)
  local order = list.title == "DEPOSIT ITEM"
    and Bag.order(game.save)   -- the deposit list shows the bag
    or pcOrder(game.save)      -- withdraw / toss show the PC storage
  list.__order = order
  reorderItems(list.items, order)

  -- the engine's buildItems labels machine items with just "TM14"; show
  -- the full "TM14 BLIZZARD" like the bag (prefix stays pinned when the
  -- move name ticks)
  for _, it in ipairs(list.items) do
    local label, prefixW, prefix, move = labelForItem(game.data, it.value)
    it.label, it.prefix, it.prefixW, it.move = label, prefix, prefixW, move
  end
  -- and let labels that overflow their row window scroll as a ticker
  decorateTickers(list)

  list.onSelectKey = function(item, l)
    if not item then return end
    if not l.swapIndex then
      l.swapIndex = l.index
      return
    end
    swapOrder(l.__order, l.items[l.swapIndex].value, l.items[l.index].value)
    l.swapIndex = nil
    require("src.core.Sound").play(game.data, "Swap")
    reorderItems(l.items, l.__order)
  end

  local vanillaChoose = list.onChoose
  list.onChoose = function(item, l)
    if l.swapIndex then -- A also completes a pending swap
      swapOrder(l.__order, l.items[l.swapIndex].value, l.items[l.index].value)
      l.swapIndex = nil
      require("src.core.Sound").play(game.data, "Swap")
      reorderItems(l.items, l.__order)
      return
    end
    return vanillaChoose(item, l)
  end
end

-- ------------------------------------------------ entry chunk

return function(mod)
  mod.content.constants:patch("bagSize", 999)
  mod.content.field:patch("pcItemCap", 999)

  -- one bag at a time; the game.ready Input wraps write TAB/R3 here
  local session = { active = nil, wantSort = false, sortOpen = false }

  -- A registered BagMenu wins over the builtin require fallback, so the
  -- start menu and the in-battle bag both get the pocketed list.  The
  -- factory still builds the vanilla bag (item-use flows stay engine
  -- owned) and then decorates it.
  mod.content.screens:register("BagMenu", {
    new = function(game, opts)
      local VanillaBagMenu = require("src.ui.BagMenu")
      return decorate(VanillaBagMenu.new(game, opts), game, session, opts)
    end,
  })

  mod.events:on("game.ready", function(ev)
    local game = ev.game
    local Input = require("src.core.Input")

    -- hot reload re-runs entry chunks: wrap each module once
    if Input.__usefulBag then return end
    Input.__usefulBag = true

    local vanillaKey = Input.keypressed
    Input.keypressed = function(self, key)
      -- TAB is bound to SELECT; while the bag is open it means "sort"
      -- instead, and the press is swallowed so it cannot also swap
      if key == "tab" and session.active and not session.sortOpen then
        session.wantSort = true
        return
      end
      return vanillaKey(self, key)
    end

    local vanillaPad = Input.gamepadpressed
    Input.gamepadpressed = function(self, joystick, button)
      if button == "rightstick" and session.active and not session.sortOpen then
        session.wantSort = true
        return
      end
      return vanillaPad(self, joystick, button)
    end

    -- the PC's three item lists never got the vanilla SELECT-swap; catch
    -- them where they are built (PlayerPC.lua) and decorate them
    local ListMenu = require("src.ui.ListMenu")
    if not ListMenu.__usefulBag then
      ListMenu.__usefulBag = true
      local vanillaNew = ListMenu.new
      ListMenu.new = function(game, title, items, opts)
        local list = vanillaNew(game, title, items, opts)
        if PC_LISTS[list.title] then decoratePcList(list, game) end
        return list
      end
    end
  end)

  mod.exports = {
    POCKETS = POCKETS,
    classify = classify,
    pocketItems = pocketItems,
    hiddenOrder = hiddenOrder,
    adjacentPocket = adjacentPocket,
    switchPocket = switchPocket,
    computeOrder = computeOrder,
    applySort = applySort,
    pcOrder = pcOrder,
    swapOrder = swapOrder,
    reorderItems = reorderItems,
    tickerOffset = tickerOffset,
    labelForItem = labelForItem,
    tickerFor = tickerFor,
  }
end
