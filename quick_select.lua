-- Quick Select: one touch/controller-safe favorite tool for the overworld.
--
-- Tap SELECT to use the assigned favorite. Hold SELECT to open the Field Kit;
-- A uses its highlighted tool and SELECT assigns it as the new favorite. The
-- old directional slot data remains readable for save compatibility, while
-- the integrated Bag exposes one explicit R3 registration action and keeps
-- classic SELECT mark/place ordering.
--
-- Item activation deliberately drives BagMenu's real USE path instead of
-- duplicating ItemEffects. That keeps target pickers, consumption, fishing,
-- Escape Rope, and mod-owned items in one place. In particular, Kanto
-- Ascendant's FIELD KIT wrapper sees the same selection it sees in the Bag
-- and opens its normal field-tech menu.

return function(mod, opts)
  opts = opts or {}
  local i18n = assert(opts.i18n, "quick_select requires i18n")
  local BagMenu = require("src.ui.BagMenu")
  local Menu = require("src.ui.Menu")
  local Q = {}
  local HOLD_SECONDS = 0.35
  local FAVORITE_VERSION = 1

  local DIRECTIONS = { "up", "down", "left", "right" }
  local DIRECTION_LABELS = {
    up = { en = "UP", de = "OBEN" },
    down = { en = "DOWN", de = "UNTEN" },
    left = { en = "LEFT", de = "LINKS" },
    right = { en = "RIGHT", de = "RECHTS" },
  }

  local function isGerman()
    return i18n.isGerman()
  end

  local function tr(en, de)
    return i18n.text(en, de)
  end

  local function option(game, key)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    local value = bucket and bucket[key]
    if value == nil then value = mod.options:get(key) end
    return value
  end

  local function enabled(game)
    return option(game, "ascendant_quick_select") ~= false
  end

  local function slots(create)
    local value = mod.save:get("slots")
    if type(value) ~= "table" and create ~= false then
      value = {}
      mod.save:set("slots", value)
    end
    return type(value) == "table" and value or nil
  end

  local function itemName(game, id)
    local def = game and game.data and game.data.items
      and game.data.items[id]
    return def and def.name or id or "----"
  end

  local function message(game, text, done)
    game.stack:push(mod.ui.TextBox.new(game, text, done))
  end

  local function favoriteTool(game, create)
    local value = mod.save:get("favorite_tool")
    local version = tonumber(mod.save:get("favorite_tool_version")) or 0
    if version < FAVORITE_VERSION and create ~= false then
      -- Preserve the old tap preference exactly once. New profiles therefore
      -- retain the familiar bicycle tap, FIELD KIT users retain their menu
      -- shortcut until they assign a module, and CLASSIC/NONE stays empty.
      local tap = option(game, "quick_select_tap") or "bicycle"
      if option(game, "ride_control") == "classic" or tap == "none" then
        value = false
      elseif tap == "field_kit" then
        value = "FIELD_KIT"
      else
        value = "ITEM:BICYCLE"
      end
      mod.save:set("favorite_tool", value)
      mod.save:set("favorite_tool_version", FAVORITE_VERSION)
    end
    return type(value) == "string" and value or nil
  end

  local function setFavorite(toolId)
    if type(toolId) ~= "string" or toolId == "" then return false end
    mod.save:set("favorite_tool", toolId)
    mod.save:set("favorite_tool_version", FAVORITE_VERSION)
    return true
  end

  local function assign(direction, itemId)
    if not DIRECTION_LABELS[direction] or type(itemId) ~= "string" then
      return false
    end
    local value = slots()
    value[direction] = itemId
    mod.save:set("slots", value)
    return true
  end

  local function clear(direction)
    local value = slots(false)
    if not value or not DIRECTION_LABELS[direction] then return false end
    value[direction] = nil
    mod.save:set("slots", value)
    return true
  end

  -- Invoke exactly what choosing USE in the Bag would invoke. A temporary
  -- Bag list is enough: all close operations are identity-safe, while every
  -- screen/message produced by using the item is pushed onto the live stack.
  local function useBagItem(game, id)
    local inventory = game and game.save and game.save.inventory or {}
    if type(id) ~= "string" or (inventory[id] or 0) <= 0 then
      if id == "BICYCLE" then
        message(game, tr(
          "You don't have a\nBICYCLE.",
          "Du hast kein\nFAHRRAD."))
      else
        message(game, tr(
          "Registered item is\nnot in the BAG.",
          "Registriertes Item\nfehlt im BEUTEL."))
      end
      return false, "missing"
    end

    local list = BagMenu.new(game, {})
    local row
    for _, candidate in ipairs(list.items or {}) do
      if candidate.value == id or candidate.id == id
          or candidate.itemId == id then
        row = candidate
        break
      end
    end
    -- Some UI/graphics mods expose only their currently visible Bag rows or
    -- use a different row key. Inventory ownership was already confirmed,
    -- so hand a compatibility descriptor to the same onChoose handler rather
    -- than rejecting a perfectly usable item before that handler sees it.
    row = row or {
      value = id, id = id, itemId = id,
      label = itemName(game, id),
      right = "x" .. tostring(inventory[id]),
    }
    if type(list.onChoose) ~= "function" then
      message(game, tr(
        "That registered item\ncannot be used now.",
        "Dieses registrierte\nItem ist jetzt nicht nutzbar."))
      return false, "no_handler"
    end

    local depth = #(game.stack.states or {})
    list.onChoose(row, list)

    -- Vanilla BagMenu opens USE/TOSS. Pop only that exact menu and run USE;
    -- a mod-owned item may instead have opened its own screen directly.
    local top = game.stack:top()
    if #(game.stack.states or {}) == depth + 1
        and getmetatable(top) == Menu
        and type(top.items) == "table"
        and #top.items == 2
        and top.items[1] and type(top.items[1].onSelect) == "function" then
      game.stack:pop()
      top.items[1].onSelect()
    end
    return true
  end

  local function toolLabel(game, toolId)
    local moveId = type(toolId) == "string"
      and toolId:match("^FIELD:(.+)$") or nil
    if moveId then
      local move = game and game.data and game.data.moves
        and game.data.moves[moveId]
      return move and move.name or moveId
    end
    local itemId = type(toolId) == "string"
      and toolId:match("^ITEM:(.+)$") or nil
    if itemId then return itemName(game, itemId) end
    if toolId == "FIELD_KIT" then return tr("FIELD KIT", "FELD-KIT") end
    return itemName(game, toolId)
  end

  local function openFieldKit(game)
    local inventory = game and game.save and game.save.inventory or {}
    if (tonumber(inventory.FIELD_KIT) or 0) <= 0 then
      message(game, tr(
        "You don't have the\nFIELD KIT yet.",
        "Du hast das FELD-KIT\nnoch nicht."))
      return false, "missing"
    end
    local fieldTech = mod.exports and mod.exports.fieldTech
    if fieldTech and type(fieldTech.open) == "function" then
      fieldTech.open(game)
      return true
    end
    return useBagItem(game, "FIELD_KIT")
  end

  local function activateTool(game, toolId)
    if toolId == "FIELD_KIT" then return openFieldKit(game) end
    local moveId = type(toolId) == "string"
      and toolId:match("^FIELD:(.+)$") or nil
    if moveId then
      local fieldTech = mod.exports and mod.exports.fieldTech
      if fieldTech and type(fieldTech.activate) == "function" then
        return fieldTech.activate(game, moveId)
      end
      message(game, tr(
        "That FIELD KIT module\ncannot be used now.",
        "Dieses FELD-KIT-Modul\nist jetzt nicht nutzbar."))
      return false, "no_field_tech"
    end
    local itemId = type(toolId) == "string"
      and toolId:match("^ITEM:(.+)$") or toolId
    return useBagItem(game, itemId)
  end

  local function activateFavorite(game)
    local toolId = favoriteTool(game, true)
    if not toolId then
      if option(game, "quick_select_empty_notice") ~= false then
        message(game, tr(
          "No favorite tool is\nassigned.\fHold SELECT and choose\none in the FIELD KIT.",
          "Kein Lieblingswerkzeug\nist festgelegt.\fHalte SELECT und wähle\neins im FELD-KIT."))
      end
      return false, "empty"
    end
    return activateTool(game, toolId)
  end

  local function registrationRows(game, selectedId, includeMove)
    local rows = {}
    local saved = slots(false) or {}
    for _, direction in ipairs(DIRECTIONS) do
      rows[#rows + 1] = {
        label = DIRECTION_LABELS[direction][isGerman() and "de" or "en"],
        right = itemName(game, saved[direction]),
        value = direction,
      }
    end
    if includeMove then
      rows[#rows + 1] = {
        label = tr("MOVE ITEM", "ITEM VERSCH."),
        value = "move",
      }
    end
    rows[#rows + 1] = {
      label = tr("CLEAR SLOT", "PLATZ LEEREN"),
      value = "clear",
    }
    return rows
  end

  local function openRegistration(game, item, list, originalSelect, opts)
    if not item or type(item.value) ~= "string" then return end
    opts = opts or {}
    local selectedId = item.value
    local rows = registrationRows(game, selectedId,
      opts.includeMove ~= false and type(originalSelect) == "function")
    local picker
    picker = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("QUICK SELECT", "SCHNELLWAHL"),
      rows, {
        onChoose = function(choice, menu)
          if choice.value == "move" then
            menu:close()
            if originalSelect then originalSelect(item, list) end
            return
          end
          if choice.value == "clear" then
            local clearRows = {}
            local saved = slots(false) or {}
            for _, direction in ipairs(DIRECTIONS) do
              clearRows[#clearRows + 1] = {
                label = DIRECTION_LABELS[direction][isGerman() and "de" or "en"],
                right = itemName(game, saved[direction]),
                value = direction,
              }
            end
            game.stack:push((mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
              tr("CLEAR WHICH?", "WELCHEN LEEREN?"), clearRows, {
                onChoose = function(slot, clearMenu)
                  clear(slot.value)
                  clearMenu:close()
                  menu:close()
                  message(game, tr("Shortcut cleared.", "Schnellwahl gelöscht."))
                end,
              }))
            return
          end
          assign(choice.value, selectedId)
          menu:close()
          message(game, tr(
            ("Registered %s.\nSELECT/%s"):format(
              itemName(game, selectedId), DIRECTION_LABELS[choice.value].en),
            ("%s registriert.\nSELECT/%s"):format(
              itemName(game, selectedId), DIRECTION_LABELS[choice.value].de)))
        end,
      })
    game.stack:push(picker)
  end

  -- Keep one process-wide wrapper across hot reloads, but refresh the bridge
  -- to this load's API closures so it never retains an obsolete mod object.
  BagMenu._quickSelectBridge = BagMenu._quickSelectBridge or {}
  BagMenu._quickSelectBridge.openRegistration = openRegistration
  BagMenu._quickSelectBridge.canRegister = function(game)
    return enabled(game)
      and option(game, "quick_select_registration") ~= false
  end
  if not BagMenu._quickSelectWrapped then
    BagMenu._quickSelectWrapped = true
    local originalNew = BagMenu.new
    BagMenu.new = function(game, opts)
      local list = originalNew(game, opts)
      if opts and opts.battle then return list end
      local originalSelect = list.onSelectKey
      -- Explicit integration seam for Ascendant's optional R3 action menu. It
      -- intentionally metadata/callback based instead of relying on wrapper
      -- capture order: SELECT remains the Bag's mark/place key, while the Bag
      -- owner can offer favorite assignment as one named action.
      list.__ascendantCanQuickSelectRegister = function()
        local bridge = BagMenu._quickSelectBridge
        return bridge and bridge.canRegister
          and bridge.canRegister(game) or false
      end
      list.__ascendantOpenQuickSelectRegister = function(item, liveList)
        if not (item and type(item.value) == "string"
            and list.__ascendantCanQuickSelectRegister()) then
          return false
        end
        setFavorite("ITEM:" .. item.value)
        message(game, tr(
          ("%s is your favorite.\nTap SELECT to use it."):format(
            itemName(game, item.value)),
          ("%s ist dein Favorit.\nSELECT nutzt es."):format(
            itemName(game, item.value))))
        return true
      end
      -- Never replace the Bag's SELECT callback. The Bag is the sole owner of
      -- mark/place ordering; favorite registration uses the named R3 action.
      list.onSelectKey = originalSelect
      return list
    end
  end

  local armed = false
  local holdSeconds = 0
  local suppressUntilRelease = false

  local function queued(input, button)
    for _, value in ipairs(input.pressQueue or {}) do
      if value == button then return true end
    end
    return false
  end

  local function consumeQueued(input, buttons)
    local drop = {}
    for _, button in ipairs(buttons) do drop[button] = true end
    local kept = {}
    for _, button in ipairs(input.pressQueue or {}) do
      if not drop[button] then kept[#kept + 1] = button end
    end
    input.pressQueue = kept
  end

  local function freeRoam(game)
    local ow = game and game.overworld
    local player = ow and ow.player
    if not ow or not player or not game.stack
        or game.stack:top() ~= ow or game.linkSession
        or (game.linkNet and not game.linkNet.closed)
        or player.moving or player.inputLocked
        or ow.transitioning or ow.engaging or ow.emote
        or ow.teleportOut or ow.flyAnim or ow.healAnim or ow.pikaHop
        or ow.cutAnim or ow.dustAnim or ow.fishPose
        or player.spinning or player.fishing
        or #(ow.scriptMoves or {}) > 0 then
      return false
    end
    if ow.runner and ow.runner.isRunning and ow.runner:isRunning() then
      return false
    end
    return true
  end

  mod.hooks:wrap("input.step", function(nextFn, game, dt)
    -- Let sibling tool/input wrappers enqueue their edges first. This hook
    -- still runs before Input:step promotes anything to gameplay.
    nextFn(game, dt)
    local input = game and game.input
    if not input then return end

    local selectDown = input.state and input.state.select == true
    if not enabled(game) then
      armed, holdSeconds, suppressUntilRelease = false, 0, false
      return
    end
    if suppressUntilRelease then
      consumeQueued(input, { "select" })
      if not selectDown then suppressUntilRelease = false end
      return
    end
    if not freeRoam(game) then
      if not selectDown then armed, holdSeconds = false, 0 end
      return
    end

    local selectPressed = queued(input, "select")
    if selectPressed then
      if not armed then
        armed = true
        holdSeconds = 0
      end
      consumeQueued(input, { "select" })
    end
    if not armed then return end

    if selectDown then
      holdSeconds = holdSeconds + math.max(0, tonumber(dt) or 0)
      if holdSeconds >= HOLD_SECONDS then
        armed, holdSeconds, suppressUntilRelease = false, 0, true
        consumeQueued(input, { "select" })
        openFieldKit(game)
      end
      return
    end

    -- A touch tap may be pressed and released between fixed steps. Its queued
    -- edge arrives with selectDown=false and takes this same one-shot path.
    armed, holdSeconds = false, 0
    consumeQueued(input, { "select" })
    activateFavorite(game)
  end, 500)

  mod.exports.assign = assign
  mod.exports.clear = clear
  mod.exports.slots = function()
    local out = {}
    for direction, id in pairs(slots(false) or {}) do out[direction] = id end
    return out
  end
  mod.exports.activate = function(game, shortcut)
    if not enabled(game) then return false, "disabled" end
    if shortcut == "select" then return activateFavorite(game) end
    local id = (slots(false) or {})[shortcut]
    if not id then return false, "empty" end
    return useBagItem(game, id)
  end
  Q.assign = assign
  Q.clear = clear
  Q.slots = mod.exports.slots
  Q.setFavorite = setFavorite
  Q.favorite = function(game) return favoriteTool(game, true) end
  Q.toolLabel = toolLabel
  Q.activateTool = activateTool
  Q.activateFavorite = activateFavorite
  Q.openFieldKit = openFieldKit
  Q.holdSeconds = HOLD_SECONDS
  return Q
end
