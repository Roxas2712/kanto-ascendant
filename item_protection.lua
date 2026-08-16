-- One shared registry and confirmation gate for irreplaceable items.

return function(mod, opts)
  opts = opts or {}
  local P = { protected = { MASTER_BALL = true } }
  local function tr(en, de)
    return opts.i18n and opts.i18n.text(en, de) or en
  end
  function P.isProtected(id)
    return mod.options:get("rare_item_lock") ~= false and P.protected[id] == true
  end
  function P.confirm(game, id, yes)
    if not P.isProtected(id) then yes(); return false end
    local def = game.data.items and game.data.items[id]
    local name = def and def.name or tostring(id):gsub("_", " ")
    local prompt = require("src.render.TextBox").new(game,
      tr(name .. " really use?", name .. " wirklich benutzen?"))
    game.stack:push(prompt)
    game.stack:push(require("src.ui.ChoiceBox").new(game, function(ok)
      if game.stack:top() == prompt then game.stack:pop() end
      if ok then yes() end
    end, { defaultNo = true }))
    return true
  end
  local BagMenu = require("src.ui.BagMenu")
  if not BagMenu._ascendantRareItemWrapped then
    local originalNew = BagMenu.new
    BagMenu.new = function(game, bagOpts)
      local list = originalNew(game, bagOpts)
      local originalChoose = list.onChoose
      list.onChoose = function(item, menu)
        local policy = BagMenu._ascendantRareItemPolicy
        if item and policy and policy.isProtected(item.value) then
          policy.confirm(game, item.value,
            function() originalChoose(item, menu or list) end)
          return
        end
        return originalChoose(item, menu)
      end
      return list
    end
    BagMenu._ascendantRareItemWrapped = true
  end
  BagMenu._ascendantRareItemPolicy = P
  local ListMenu = require("src.ui.ListMenu")
  if not ListMenu._ascendantRareItemWrapped then
    local originalNew = ListMenu.new
    ListMenu.new = function(game, title, items, listOpts)
      local list = originalNew(game, title, items, listOpts)
      if title == "SELL" or title == "TOSS ITEM" then
        local originalChoose = list.onChoose
        list.onChoose = function(item, menu)
          local policy = ListMenu._ascendantRareItemPolicy
          if item and policy and policy.isProtected(item.value) then
            policy.confirm(game, item.value,
              function() originalChoose(item, menu or list) end)
            return
          end
          return originalChoose(item, menu)
        end
      end
      return list
    end
    ListMenu._ascendantRareItemWrapped = true
  end
  ListMenu._ascendantRareItemPolicy = P
  return P
end
