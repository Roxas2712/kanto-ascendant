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
        }
      else
        startItems[#startItems + 1] = item
      end
    end
    table.sort(ascendantItems, function(a, b)
      if a.order == b.order then return a.sourceIndex < b.sourceIndex end
      return a.order < b.order
    end)
    return startItems, ascendantItems
  end

  function A.open(game, rows)
    game.stack:push(mod.ui.ListMenu.new(game, "KANTO ASCENDANT", rows, {
      pageJump = true,
      onCancel = function() mod.ui.push(game, "StartMenu") end,
      onChoose = function(item)
        if item and item.onSelect then item.onSelect() end
      end,
    }))
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    local startItems, ascendantItems = collect(out)
    if #ascendantItems == 0 then return startItems end
    return mod.ui.insertBefore(startItems, tr("SAVE", "SICHERN"), {
      label = "ASCENDANT",
      onSelect = function() A.open(game, ascendantItems) end,
    })
  end, 1000)

  A.collect = collect
  A.title = function() return tr("KANTO ASCENDANT", "KANTO ASCENDANT") end
  return A
end
