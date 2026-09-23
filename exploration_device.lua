-- Kanto Ascendant 6.7 exploration-device foundation.
--
-- The TRACE FINDER is awarded only by the ordinary field-rematch win path.
-- It owns one bounded chance roll, a durable pending entitlement for full
-- Bags and persistent entrance-open receipts. Latias/Latios belong to the
-- separate Hoenn Honey + Hoenn Dex contract. Map packages register safe
-- locate/open callbacks later; this
-- module never guesses a warp, edits a map table, or reveals an entrance id.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local E = {
    ITEM = "TRACE_FINDER",
    SAVE_KEY = "exploration_device",
    STATE_VERSION = 1,
    CHANCE_PERCENT = 15,
    HARD_PITY_WIN = 15,
  }

  local entrances, entranceOrder = {}, {}
  local noTargetHint
  local activeGame

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do
      out[copy(key, seen)] = copy(child, seen)
    end
    return out
  end

  local function integer(value, floor)
    value = tonumber(value)
    if not value or value ~= math.floor(value) then return floor end
    return math.max(floor, value)
  end

  local function normalize(raw)
    local out = type(raw) == "table" and copy(raw) or {}
    local changed = type(raw) ~= "table"
    if out.version ~= E.STATE_VERSION then
      out.version = E.STATE_VERSION
      changed = true
    end
    local eligibleWins = integer(out.eligibleWins, 0)
    if out.eligibleWins ~= eligibleWins then
      out.eligibleWins = eligibleWins
      changed = true
    end
    local pity = math.min(E.HARD_PITY_WIN - 1, integer(out.pity, 0))
    if out.pity ~= pity then out.pity, changed = pity, true end
    for _, key in ipairs({
      "entitled", "pending", "owned", "latiasActive", "latiosActive",
    }) do
      local value = out[key] == true
      if out[key] ~= value then out[key], changed = value, true end
    end
    if out.owned then
      if not out.entitled then out.entitled, changed = true, true end
      if out.pending then out.pending, changed = false, true end
    end
    if type(out.opened) ~= "table" then
      out.opened, changed = {}, true
    else
      local cleaned = {}
      for id, receipt in pairs(out.opened) do
        if type(id) == "string" and id ~= "" and receipt then
          cleaned[id] = receipt == true and true or copy(receipt)
        else
          changed = true
        end
      end
      out.opened = cleaned
    end
    return out, changed
  end

  local function state(create)
    local raw = mod.save:get(E.SAVE_KEY)
    if type(raw) ~= "table" and create == false then return nil end
    local out, changed = normalize(raw)
    if changed then mod.save:set(E.SAVE_KEY, out) end
    return out
  end

  local function persist(value)
    local out = normalize(value)
    mod.save:set(E.SAVE_KEY, out)
    return out
  end

  local function owns(game)
    local inventory = game and game.save and game.save.inventory or {}
    return (tonumber(inventory[E.ITEM]) or 0) > 0
  end

  local function activate(s)
    s.entitled = true
    s.pending = false
    s.owned = true
    s.pity = 0
    return persist(s)
  end

  local function adoptInventory(game)
    local s = state(true)
    if owns(game) and not s.owned then
      return activate(s), true
    end
    return s, false
  end

  local function defaultAddItem(game, itemId)
    game.save.inventory = game.save.inventory or {}
    return require("src.inventory.Bag").add(game.save, itemId, 1, game.data)
  end

  local function awardText()
    return tr(
      "REMATCH DISCOVERY!\fYou received the\nTRACE FINDER!\fHidden paths can now\nanswer its signal.",
      "REVANCHEN-FUND!\fDu erhältst den\nSPURENSUCHER!\fVerborgene Pfade\nantworten nun darauf.")
  end

  local function pendingText()
    return tr(
      "A TRACE FINDER is\nreserved for you.\fMake BAG room.\fWin a rematch.",
      "SPURENSUCHER ist\nfür dich bereit.\fSchaffe Platz und\nsiege erneut.")
  end

  local function eligibleFieldRematch(battle)
    return battle and battle.rematch == true
      and type(battle.rematchTrainerKey) == "string"
      and battle.rematchTrainerKey ~= ""
  end

  local function randomInt(deps, low, high)
    local random = deps and deps.random or opts.random
      or (love and love.math and love.math.random) or math.random
    return random(low, high)
  end

  local function tryDelivery(game, s, deps)
    local addItem = deps and deps.addItem or opts.addItem or defaultAddItem
    if owns(game) or addItem(game, E.ITEM) then
      activate(s)
      return awardText(), true
    end
    s.entitled = true
    s.pending = true
    persist(s)
    return pendingText(), false
  end

  function E.afterRematch(game, battle, deps)
    if not eligibleFieldRematch(battle) then
      return nil, { eligible = false, rollsUsed = 0,
        reason = "not-field-rematch" }
    end
    local s = adoptInventory(game)
    if s.owned then
      return nil, { eligible = true, rollsUsed = 0,
        reason = "already-owned" }
    end
    if s.pending or s.entitled then
      local text, received = tryDelivery(game, s, deps)
      return text, {
        eligible = true, rollsUsed = 0, awarded = received,
        pending = not received,
        reason = received and "pending-delivered" or "pending-waiting",
      }
    end

    s.eligibleWins = s.eligibleWins + 1
    local eligibleWin = s.pity + 1
    local guaranteed = eligibleWin >= E.HARD_PITY_WIN
    local roll, natural, rollsUsed
    if guaranteed then
      rollsUsed = 0
      natural = false
    else
      roll = randomInt(deps, 1, 100)
      rollsUsed = 1
      natural = roll <= E.CHANCE_PERCENT
    end
    if not (natural or guaranteed) then
      s.pity = eligibleWin
      persist(s)
      return nil, {
        eligible = true, eligibleWin = eligibleWin,
        roll = roll, rollsUsed = rollsUsed,
        natural = false, guaranteed = false, awarded = false,
      }
    end

    s.pity = 0
    s.entitled = true
    persist(s)
    local text, received = tryDelivery(game, s, deps)
    return text, {
      eligible = true, eligibleWin = eligibleWin,
      roll = roll, rollsUsed = rollsUsed,
      natural = natural, guaranteed = guaranteed,
      awarded = received, pending = not received,
    }
  end

  local CLUES = {
    far = {
      north = { "A faint signal is\nto the north.",
        "Ein leises Signal\nliegt im Norden." },
      east = { "A faint signal is\nto the east.",
        "Ein leises Signal\nliegt im Osten." },
      south = { "A faint signal is\nto the south.",
        "Ein leises Signal\nliegt im Süden." },
      west = { "A faint signal is\nto the west.",
        "Ein leises Signal\nliegt im Westen." },
    },
    warm = {
      north = { "The signal grows.\nIt pulls north.",
        "Das Signal wird\nnordwärts stärker." },
      east = { "The signal grows.\nIt pulls east.",
        "Das Signal wird\nostwärts stärker." },
      south = { "The signal grows.\nIt pulls south.",
        "Das Signal wird\nsüdwärts stärker." },
      west = { "The signal grows.\nIt pulls west.",
        "Das Signal wird\nwestwärts stärker." },
    },
    near = {
      north = { "A clear trail runs\nnorth from here.",
        "Eine klare Spur\nführt nach Norden." },
      east = { "A clear trail runs\neast from here.",
        "Eine klare Spur\nführt nach Osten." },
      south = { "A clear trail runs\nsouth from here.",
        "Eine klare Spur\nführt nach Süden." },
      west = { "A clear trail runs\nwest from here.",
        "Eine klare Spur\nführt nach Westen." },
    },
    close = {
      north = { "The pulse is near.\nKeep north.",
        "Impuls ganz nah.\nGeh nach Norden." },
      east = { "The pulse is near.\nKeep east.",
        "Impuls ganz nah.\nGeh nach Osten." },
      south = { "The pulse is near.\nKeep south.",
        "Impuls ganz nah.\nGeh nach Süden." },
      west = { "The pulse is near.\nKeep west.",
        "Impuls ganz nah.\nGeh nach Westen." },
    },
    immediate = {
      north = { "The hidden barrier\nis just north.",
        "Die Sperre liegt\nknapp im Norden." },
      east = { "The hidden barrier\nis just east.",
        "Die Sperre liegt\nknapp im Osten." },
      south = { "The hidden barrier\nis just south.",
        "Die Sperre liegt\nknapp im Süden." },
      west = { "The hidden barrier\nis just west.",
        "Die Sperre liegt\nknapp im Westen." },
    },
  }

  local function localizedClues()
    local out = {}
    for band, directions in pairs(CLUES) do
      out[band] = {}
      for direction, text in pairs(directions) do
        out[band][direction] = tr(text[1], text[2])
      end
    end
    return out
  end

  function E.clues()
    return localizedClues()
  end

  function E.registerEntrance(def)
    if type(def) ~= "table" or type(def.id) ~= "string" or def.id == "" then
      return false, "invalid-entrance"
    end
    if entrances[def.id] then return false, "already-registered" end
    if type(def.locate) ~= "function" then return false, "locate-required" end
    if def.open ~= nil and type(def.open) ~= "function" then
      return false, "invalid-open-callback"
    end
    entrances[def.id] = def
    entranceOrder[#entranceOrder + 1] = def.id
    return true
  end

  function E.isOpen(id)
    local s = state(false)
    return s and type(s.opened) == "table" and s.opened[id] ~= nil or false
  end

  function E.markOpen(id, receipt)
    if type(id) ~= "string" or id == "" then return false end
    local s = state(true)
    if s.opened[id] ~= nil then return false end
    s.opened[id] = receipt or true
    persist(s)
    return true
  end

  local function finite(value)
    return type(value) == "number" and value == value
      and value ~= math.huge and value ~= -math.huge
  end

  local function targetFor(game)
    local best
    for order, id in ipairs(entranceOrder) do
      local def = entrances[id]
      if def and not E.isOpen(id) then
        local allowed = true
        if type(def.available) == "function" then
          local ok, value = pcall(def.available, game, def)
          allowed = ok and value == true
        end
        if allowed then
          local ok, location = pcall(def.locate, game, def)
          if ok and type(location) == "table"
              and finite(tonumber(location.distance)) then
            local direction = type(location.direction) == "string"
              and location.direction:lower() or nil
            if CLUES.far[direction] then
              local distance = math.max(0, tonumber(location.distance))
              if not best or distance < best.distance
                  or (distance == best.distance and order < best.order) then
                best = { id = id, def = def, location = location,
                  distance = distance, direction = direction, order = order }
              end
            end
          end
        end
      end
    end
    return best
  end

  local function bandFor(distance)
    if distance <= 1 then return "immediate" end
    if distance <= 4 then return "close" end
    if distance <= 12 then return "near" end
    if distance <= 24 then return "warm" end
    return "far"
  end

  local function show(game, text, deps)
    if deps and type(deps.message) == "function" then
      deps.message(game, text)
      return
    end
    local TextBox = deps and deps.textBox or require("src.render.TextBox")
    game.stack:push(TextBox.new(game, text))
  end

  local function openedGuidance(game, def)
    if type(def.openedGuidance) ~= "function" then return nil end
    local ok, text = pcall(def.openedGuidance, game)
    if ok and type(text) == "table" and type(text.en) == "string"
        and type(text.de) == "string" then return tr(text.en, text.de) end
  end

  function E.use(game, deps)
    local s = adoptInventory(game)
    if not s.owned and not owns(game) then
      local text = tr("You don't have the\nTRACE FINDER.",
        "Dir fehlt der\nSPURENSUCHER.")
      show(game, text, deps)
      return text, { used = false, reason = "missing" }
    end
    local target = targetFor(game)
    if not target then
      for _, id in ipairs(entranceOrder) do
        if E.isOpen(id) then
          local hint = openedGuidance(game, entrances[id])
          if hint then
            show(game, hint, deps)
            return hint, { used = true, target = id, reason = "already-open" }
          end
        end
      end
      local text
      if type(noTargetHint) == "function" then
        local ok, hint = pcall(noTargetHint, game)
        if ok and type(hint) == "string" and hint ~= "" then text = hint end
      end
      text = text or tr(
        "TRACE FINDER hums.\nNo path answers.",
        "Der SUCHER summt.\nKein Weg reagiert.")
      show(game, text, deps)
      return text, { used = true, reason = "no-target" }
    end

    if target.location.canOpen == true and type(target.def.open) == "function" then
      local ok, opened, receipt = pcall(target.def.open, game, target.def,
        target.location)
      if ok and opened == true then
        E.markOpen(target.id, receipt or true)
        local text = tr(
          "Signal locked!\fThe hidden path is\nnow open.",
          "Signal rastet ein!\fDer geheime Weg\nist nun offen.")
        local hint = openedGuidance(game, target.def)
        if hint then text = text .. "\f" .. hint end
        show(game, text, deps)
        return text, { used = true, target = target.id, opened = true }
      end
    end

    local clues = localizedClues()
    local band = bandFor(target.distance)
    local text = clues[band][target.direction]
    show(game, text, deps)
    return text, {
      used = true, target = target.id, opened = false,
      band = band, direction = target.direction, distance = target.distance,
    }
  end

  E.open = E.use

  function E.setNoTargetHint(provider)
    if type(provider) ~= "function" then return false, "provider-required" end
    if noTargetHint then return false, "already-bound" end
    noTargetHint = provider
    return true
  end

  function E.status()
    return copy(state(true))
  end

  function E.roamersActivated()
    -- Retained as a compatibility seam for older callers. Device state is no
    -- longer an activation authority for either Hoenn roamer.
    return false
  end

  function E.install(game, deps)
    activeGame = game
    adoptInventory(game)
    local BagMenu = deps and deps.bagMenu or require("src.ui.BagMenu")
    if not BagMenu._ascendantTraceFinderWrapped then
      BagMenu._ascendantTraceFinderWrapped = true
      local originalNew = BagMenu.new
      BagMenu.new = function(menuGame, menuOpts)
        menuOpts = menuOpts or {}
        local list = originalNew(menuGame, menuOpts)
        local originalChoose = list.onChoose
        list.onChoose = function(item, menu)
          local policy = BagMenu._ascendantTraceFinderPolicy
          if policy and item and item.value == policy.ITEM
              and not menuOpts.battle then
            menu:close()
            policy.use(menuGame)
            return
          end
          return originalChoose(item, menu)
        end
        return list
      end
    end
    BagMenu._ascendantTraceFinderPolicy = E
    return true
  end

  mod.content.items:register(E.ITEM, {
    id = E.ITEM,
    name = tr("TRACE FINDER", "SPURENSUCHER"),
    price = 0,
    keyItem = true,
    tossable = false,
    needsTarget = false,
    lootExcluded = true,
    progressionItem = true,
  })

  return E
end
