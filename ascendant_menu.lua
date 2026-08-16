-- One tidy gateway for Kanto Ascendant's Start-menu utilities.
--
-- Feature modules still decide whether their own row is currently unlocked.
-- They mark that row with ascendantMenu/ascendantOrder; this final high-
-- priority wrapper collects only those marked rows, leaving vanilla and
-- other mods' Start-menu entries untouched.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local A = {}

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state()
    local s = mod.save:get("ascendant_menu")
    if type(s) ~= "table" then
      s = { version = 1, initialized = false, known = {}, fresh = {} }
      mod.save:set("ascendant_menu", s)
    end
    s.version = 1
    s.initialized = s.initialized == true
    s.known = type(s.known) == "table" and s.known or {}
    s.fresh = type(s.fresh) == "table" and s.fresh or {}
    return s
  end

  local function itemKey(item)
    return tostring(item.ascendantKey
      or ("order:" .. tostring(tonumber(item.ascendantOrder) or 999)))
  end

  local function collect(items)
    local startItems, ascendantItems = {}, {}
    for index, item in ipairs(items or {}) do
      if type(item) == "table" and item.ascendantMenu then
        ascendantItems[#ascendantItems + 1] = {
          label = item.ascendantLabel or item.label,
          right = item.right,
          onSelect = item.onSelect,
          order = tonumber(item.ascendantOrder) or 999,
          sourceIndex = index,
          ascendantKey = itemKey(item),
          ascendantFresh = item.ascendantFresh == true,
        }
      else
        startItems[#startItems + 1] = item
      end
    end
    local hasOptions = false
    for _, item in ipairs(ascendantItems) do
      if item.ascendantKey == "options" then
        hasOptions = true
        break
      end
    end
    if mod.exports.ascendantFeaturesScreen and not hasOptions then
      ascendantItems[#ascendantItems + 1] = {
        label = tr("OPTIONS", "OPTIONEN"),
        onSelect = function()
          mod.ui.push(mod.world.game, mod.exports.ascendantFeaturesScreen)
        end,
        order = 1,
        sourceIndex = #items + 1,
        ascendantKey = "options",
      }
    end
    table.sort(ascendantItems, function(a, b)
      if a.order == b.order then return a.sourceIndex < b.sourceIndex end
      return a.order < b.order
    end)

    local s = state()
    local anyNew = false
    for _, item in ipairs(ascendantItems) do
      local key = item.ascendantKey
      if s.initialized and not s.known[key] then s.fresh[key] = true end
      s.known[key] = true
      if s.fresh[key] then
        item.right = tr("NEW", "NEU")
        anyNew = true
      elseif item.ascendantFresh then
        item.right = tr("NEW", "NEU")
        anyNew = true
      end
    end
    s.initialized = true
    mod.save:set("ascendant_menu", s)
    return startItems, ascendantItems, anyNew
  end

  function A.open(game, rows)
    game.stack:push((mod.ui.KantoListMenu or mod.ui.ListMenu).new(game, "KANTO ASCENDANT", rows, {
      pageJump = true,
      onCancel = function() mod.ui.push(game, "StartMenu") end,
      onChoose = function(item)
        if item then
          local s = state()
          if item.ascendantKey and s.fresh[item.ascendantKey] then
            s.fresh[item.ascendantKey] = nil
            mod.save:set("ascendant_menu", s)
          end
          if item.onSelect then item.onSelect() end
        end
      end,
    }))
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    local startItems, ascendantItems, anyNew = collect(out)
    if #ascendantItems == 0 then return startItems end
    return mod.ui.insertBefore(startItems, tr("SAVE", "SICHERN"), {
      label = "ASCENDANT",
      right = anyNew and tr("NEW", "NEU") or nil,
      onSelect = function() A.open(game, ascendantItems) end,
    })
  end, 1000)

  A.collect = collect
  A.state = state
  A.title = function() return tr("KANTO ASCENDANT", "KANTO ASCENDANT") end
  return A
end
