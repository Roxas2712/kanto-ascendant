-- Optional non-destructive filters for the Pokédex and PC box lists.
-- Filtering is a view only: save order, ownership and box contents never
-- change.

return function(mod)
  local function setting(key)
    return mod.options:get(key) or "all"
  end

  local function dexAllowed(game, species)
    local mode = setting("pokedex_filter")
    if mode == "all" then return true end
    local dex = game.save.pokedex or {}
    if mode == "owned" then return dex.owned and dex.owned[species] == true end
    return dex.seen and dex.seen[species] == true
  end

  local function install()
    local ok, PokedexMenu = pcall(require, "src.ui.PokedexMenu")
    if ok and PokedexMenu and not PokedexMenu.__ascendantFilter then
      PokedexMenu.__ascendantFilter = true
      local baseNew = PokedexMenu.new
      PokedexMenu.new = function(game, opts)
        local list = baseNew(game, opts)
        local filtered = {}
        for _, item in ipairs(list.items or {}) do
          if setting("pokedex_filter") == "all"
              or (item.value and dexAllowed(game, item.value)) then
            filtered[#filtered + 1] = item
          end
        end
        list.items = filtered
        list.index = math.min(list.index or 1, math.max(1, #filtered))
        return list
      end
    end

    local listOk, ListMenu = pcall(require, "src.ui.ListMenu")
    if not listOk or not ListMenu or ListMenu.__ascendantBoxFilter then return end
    ListMenu.__ascendantBoxFilter = true
    local baseListNew = ListMenu.new
    ListMenu.new = function(game, title, items, opts)
      local list = baseListNew(game, title, items, opts)
      local mode = setting("box_filter")
      local storageList = type(title) == "string"
        and (title:find("WITHDRAW", 1, true)
          or title:find("RELEASE", 1, true)
          or title:find("ABHEBEN", 1, true)
          or title:find("FREILASSEN", 1, true))
      if mode == "all" or not storageList then
        return list
      end
      local box = game.save.boxes and game.save.boxes[game.save.currentBox or 1]
      local filtered = {}
      for _, item in ipairs(list.items or {}) do
        local mon = box and box[item.value]
        local def = mon and game.data.pokemon[mon.species]
        local isJohto = def and tonumber(def.dex) and def.dex > 151
        if (mode == "johto" and isJohto) or (mode == "kanto" and not isJohto) then
          filtered[#filtered + 1] = item
        end
      end
      list.items = filtered
      list.index = math.min(list.index or 1, math.max(1, #filtered))
      return list
    end
  end
  install()
end
