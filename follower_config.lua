-- Persistent follower selection and the compact party-menu editor.
--
-- CUSTOM order stores small string ids on the Pokemon save tables.  Those
-- ids survive evolution, party reordering and box transfers, while the
-- runtime controller continues to receive ordinary party rows.  No Lua
-- object address or NPC reference ever enters the save.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local gameVersion = opts.gameVersion
  local yellowPartner = opts.yellowPartner
  local legacyStarters = opts.legacyStarters
  local textBox = opts.textBox
  local C = { game = nil, controller = nil }
  local STATE_KEY = "follower_config"
  local MON_KEY = "_ascendantFollowerId"
  local VERSION = 1
  local MAX_FOLLOWERS = 6

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function clampCount(value)
    return math.max(1, math.min(MAX_FOLLOWERS,
      math.floor(tonumber(value) or 1)))
  end

  local function normalizeMode(value)
    return value == "custom" and "custom" or "party"
  end

  local function normalizePresentation(value)
    return value == "yellow_center" and "yellow_center" or "ascendant_box"
  end

  local function normalizeState(s)
    if type(s) ~= "table" then s = {} end
    s.version = VERSION
    -- Options are process-global, while follower configuration belongs to a
    -- save slot. An old Blue/Yellow slot must not inherit Count=4 merely
    -- because Red changed the central option earlier in the same identity.
    s.count = clampCount(s.count ~= nil and s.count or 1)
    s.mode = normalizeMode(s.mode ~= nil and s.mode or "party")
    s.presentation = normalizePresentation(
      s.presentation ~= nil and s.presentation or "ascendant_box")
    s.custom = type(s.custom) == "table" and s.custom or {}
    local clean, seen = {}, {}
    for _, id in ipairs(s.custom) do
      if type(id) == "string" and id ~= "" and not seen[id] then
        clean[#clean + 1], seen[id] = id, true
      end
    end
    s.custom = clean
    s.nextId = math.max(0, math.floor(tonumber(s.nextId) or 0))
    return s
  end

  local function state(create)
    local s = mod.save:get(STATE_KEY)
    if type(s) ~= "table" and create ~= false then
      s = normalizeState({})
      mod.save:set(STATE_KEY, s)
    elseif type(s) == "table" then
      s = normalizeState(s)
      mod.save:set(STATE_KEY, s)
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set(STATE_KEY, normalizeState(s)) end
  end

  local function allPokemon(save, fn)
    for _, mon in ipairs(save and save.party or {}) do fn(mon) end
    for _, box in ipairs(save and save.boxes or {}) do
      local mons = type(box) == "table" and (box.mons or box) or {}
      for _, mon in ipairs(mons) do fn(mon) end
    end
  end

  local function allocatedIds(save, except)
    local used = {}
    allPokemon(save, function(mon)
      if mon ~= except and type(mon) == "table"
          and type(mon[MON_KEY]) == "string" and mon[MON_KEY] ~= "" then
        used[mon[MON_KEY]] = true
      end
    end)
    return used
  end

  local function repairIdentities(save)
    local s, seen = state(), {}
    allPokemon(save, function(mon)
      local id = type(mon) == "table" and mon[MON_KEY] or nil
      if type(id) == "string" and id ~= "" then
        local numeric = tonumber(id:match("^KA%-F%-(%d+)$"))
        if numeric then s.nextId = math.max(s.nextId, numeric) end
        if seen[id] then
          -- A copied/imported Pokemon must not alias the original CUSTOM
          -- entry. Leave the first save occurrence attached to the stored
          -- priority and allocate a fresh id lazily if the copy is selected.
          mon[MON_KEY] = nil
        else
          seen[id] = true
        end
      end
    end)
    persist(s)
  end

  function C.identity(mon, create)
    if type(mon) ~= "table" then return nil end
    local current = mon[MON_KEY]
    if type(current) == "string" and current ~= "" then return current end
    if create == false then return nil end
    local s, save = state(), C.game and C.game.save
    local used = allocatedIds(save, mon)
    repeat
      s.nextId = s.nextId + 1
      current = ("KA-F-%08d"):format(s.nextId)
    until not used[current]
    mon[MON_KEY] = current
    persist(s)
    return current
  end

  local function customIndex(mon, s)
    local id = C.identity(mon, false)
    if not id then return nil end
    for index, value in ipairs((s or state()).custom) do
      if value == id then return index end
    end
    return nil
  end

  local function yellowLead(game)
    if not C.isYellow() then return nil end
    local lead = yellowPartner and yellowPartner.partner
      and yellowPartner.partner(game) or nil
    if lead then return lead end
    return legacyStarters and legacyStarters.partner
      and legacyStarters.partner(game) or nil
  end

  local function customPosition(mon, s)
    local id = C.identity(mon, false)
    if not id then return nil end
    local lead = yellowLead(C.game)
    local leadId = lead and C.identity(lead, false) or nil
    local position = C.isYellow() and 1 or 0
    for _, value in ipairs((s or state()).custom) do
      if not leadId or value ~= leadId then position = position + 1 end
      if value == id then return math.max(1, position) end
    end
    return nil
  end

  local function syncOneOption(key, value)
    local game = C.game
    local loader = game and game.mods
    if loader then
      loader.modOptions = loader.modOptions or {}
      loader.modOptions[mod.id] = loader.modOptions[mod.id] or {}
      loader.modOptions[mod.id][key] = value
    end
    local options = game and game.save and game.save.options
    if options then
      options.modOptions = options.modOptions or {}
      options.modOptions[mod.id] = options.modOptions[mod.id] or {}
      options.modOptions[mod.id][key] = value
    end
  end

  local function syncOptions(s)
    syncOneOption("follower_count", s.count)
    syncOneOption("follower_order", s.mode)
    if C.isYellow() then
      syncOneOption("yellow_partner_presentation", s.presentation)
    end
  end

  local function refresh()
    if C.controller and C.controller.applyConfig then
      C.controller.applyConfig(C.game)
    elseif C.controller and C.controller.refresh then
      C.controller.refresh(C.game)
    end
  end

  function C.isYellow()
    local gv = gameVersion
    if not gv then
      local ok
      ok, gv = pcall(require, "src.core.GameVersion")
      if not ok then return false end
    end
    return gv and gv.isYellow and gv.isYellow() == true
  end

  function C.count() return state().count end
  function C.mode() return state().mode end
  function C.presentation() return state().presentation end
  function C.customIds()
    local copy = {}
    for i, id in ipairs(state().custom) do copy[i] = id end
    return copy
  end

  function C.setCount(value)
    local s = state()
    s.count = clampCount(value)
    persist(s)
    syncOneOption("follower_count", s.count)
    refresh()
    return s.count
  end

  function C.setMode(value)
    local s = state()
    s.mode = normalizeMode(value)
    persist(s)
    syncOneOption("follower_order", s.mode)
    refresh()
    return s.mode
  end

  function C.setPresentation(value)
    local s = state()
    s.presentation = normalizePresentation(value)
    persist(s)
    if C.isYellow() then
      syncOneOption("yellow_partner_presentation", s.presentation)
    end
    return s.presentation
  end

  function C.add(mon)
    if type(mon) ~= "table" then return false end
    local s = state()
    if customIndex(mon, s) then return false end
    local id = C.identity(mon, true)
    -- identity() persists nextId and normalizes the shared state table; take
    -- its current custom array after that call instead of appending through
    -- a pre-normalization table reference.
    s = state()
    s.custom[#s.custom + 1] = id
    -- ADD FOLLOWER is an action, not merely an order-list editor. Grow the
    -- save-local visible count just enough to expose the new entry. Yellow's
    -- authored partner owns slot 1, so its first extra needs Count=2.
    local position = customPosition(mon, s)
    if position and position <= MAX_FOLLOWERS and s.count < position then
      s.count = position
      syncOneOption("follower_count", s.count)
    end
    persist(s)
    refresh()
    return true, position
  end

  function C.show(mon)
    local s = state()
    local position = customPosition(mon, s)
    if not position or position > MAX_FOLLOWERS or s.count >= position then
      return false, position
    end
    s.count = position
    persist(s)
    syncOneOption("follower_count", s.count)
    refresh()
    return true, position
  end

  function C.remove(mon)
    local s, index = state(), customIndex(mon)
    if not index then return false end
    table.remove(s.custom, index)
    persist(s)
    refresh()
    return true
  end

  function C.move(mon, delta)
    local s, index = state(), customIndex(mon)
    if not index then return false end
    local target = math.max(1, math.min(#s.custom, index + delta))
    if target == index then return false end
    local id = table.remove(s.custom, index)
    table.insert(s.custom, target, id)
    persist(s)
    refresh()
    return true
  end

  function C.customPartyRows(game)
    game = game or C.game
    local byId = {}
    for slot, mon in ipairs(game and game.save and game.save.party or {}) do
      local id = C.identity(mon, false)
      if id and not byId[id] then byId[id] = { mon = mon, slot = slot } end
    end
    local rows = {}
    for _, id in ipairs(state().custom) do
      local row = byId[id]
      if row then rows[#rows + 1] = row end
    end
    return rows
  end

  local function closeList(list)
    if list and list.close then list:close() end
  end

  local function inParty(game, wanted)
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if mon == wanted then return true end
    end
    return false
  end

  local function monName(game, mon)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon and mon.species]
    return tostring(mon and (mon.nickname or (def and def.name) or mon.species)
      or tr("POKEMON", "POKEMON"))
  end

  local function resultText(game, mon, position)
    local name = monName(game, mon)
    local following = tr(
      name .. " is now\nfollowing you!",
      name .. " folgt dir\njetzt!")
    if (tonumber(mon and mon.hp) or 0) <= 0 then
      return tr(name .. " was added.\fIt must be healthy\nto follow you.",
        name .. " wurde gewählt.\fEs muss fit sein,\num dir zu folgen.")
    end
    if not position or position > MAX_FOLLOWERS then
      return tr(name .. " was saved.\fOnly first 6\nfollowers appear.",
        name .. " wurde gespeichert.\fNur die ersten 6\nBegleiter erscheinen.")
    end
    if C.isYellow() then
      local lead = yellowLead(game)
      if not (lead and inParty(game, lead) and (tonumber(lead.hp) or 0) > 0) then
        return following .. tr(
          ("\fIt stays FOLLOWER #%d.\fUntil your partner returns,\nit leads the chain.")
            :format(position),
          ("\fEs bleibt BEGLEITER #%d.\fBis dein Partner zurück ist,\nführt es die Reihe an.")
            :format(position))
      end
    end
    if C.isYellow() and position > 1 then
      return following .. tr(
        ("\fIt is FOLLOWER #%d.\fYour partner stays\nFOLLOWER #1.")
          :format(position),
        ("\fEs ist BEGLEITER #%d.\fDein Partner bleibt\nBEGLEITER #1.")
          :format(position))
    end
    return following
  end

  local function showResult(game, text)
    local TextBox = textBox
    if not TextBox then
      local ok
      ok, TextBox = pcall(require, "src.render.TextBox")
      if not ok then return false end
    end
    if not (game and game.stack and TextBox and TextBox.new) then return false end
    game.stack:push(TextBox.new(game, text))
    return true
  end

  local function openEditor(game, mon)
    local s, index = state(), customIndex(mon)
    local rows = {}
    if s.mode ~= "custom" then
      rows[#rows + 1] = {
        label = tr("CUSTOM ADD", "CUSTOM HINZU"), value = "custom_add",
      }
    elseif not index then
      rows[#rows + 1] = {
        label = tr("ADD FOLLOWER", "BEGLEITER HINZU"), value = "add",
      }
    else
      local position = customPosition(mon, s)
      if position and position <= MAX_FOLLOWERS and s.count < position then
        rows[#rows + 1] = {
          label = tr("SHOW FOLLOWER", "BEGLEITER ZEIGEN"), value = "show",
        }
      end
      rows[#rows + 1] = {
        label = tr("MOVE UP", "NACH OBEN"), value = "up",
      }
      rows[#rows + 1] = {
        label = tr("MOVE DOWN", "NACH UNTEN"), value = "down",
      }
      rows[#rows + 1] = {
        label = tr("REMOVE", "ENTFERNEN"), value = "remove",
      }
    end
    game.stack:push((mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("FOLLOWER ORDER", "BEGLEITER-FOLGE"), rows, {
        onChoose = function(item, list)
          local changed, position
          if item.value == "custom_add" then
            C.setMode("custom")
            changed, position = C.add(mon)
          elseif item.value == "add" then
            changed, position = C.add(mon)
          elseif item.value == "show" then
            changed, position = C.show(mon)
          elseif item.value == "up" then C.move(mon, -1)
          elseif item.value == "down" then C.move(mon, 1)
          elseif item.value == "remove" then C.remove(mon) end
          closeList(list)
          if changed then showResult(game, resultText(game, mon, position)) end
        end,
      }))
  end

  function C.install(game, controller)
    C.game, C.controller = game, controller or C.controller
    repairIdentities(game and game.save)
    local s = state()
    syncOptions(s)
    refresh()
    return true
  end

  if mod.hooks and mod.hooks.wrap then
    mod.hooks:wrap("ui.party.submenu", function(nextItems, game, items, mon, ctx)
      local out = nextItems(game, items, mon, ctx)
      if type(out) ~= "table" or (ctx and ctx.battle) or (mon and mon.isEgg) then
        return out
      end
      out[#out + 1] = {
        label = tr("FOLLOWER", "BEGLEITER"),
        onSelect = function(selected, activeGame)
          openEditor(activeGame or game, selected or mon)
        end,
      }
      return out
    end, 240)
  end

  if mod.events and mod.events.on then
    mod.events:on("mod.options_changed", function(ev)
      if not (ev and ev.mod == mod.id) then return end
      if ev.key == "follower_count" then C.setCount(ev.value)
      elseif ev.key == "follower_order" then C.setMode(ev.value)
      elseif ev.key == "yellow_partner_presentation" then
        C.setPresentation(ev.value)
      end
    end, 220)
    mod.events:on("save.loaded", function(ev)
      if ev and ev.game then C.game = ev.game end
      repairIdentities(C.game and C.game.save)
      local s = state()
      syncOptions(s)
      refresh()
    end, 220)
  end

  C.stateKey = STATE_KEY
  C.monKey = MON_KEY
  C.version = VERSION
  C._state = state
  C._openEditor = openEditor
  return C
end
