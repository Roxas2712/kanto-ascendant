-- KASC 6.7 current-playthrough authority for Hoenn endgame encounters.
--
-- Dex, Legacy and profile receipts deliberately live elsewhere and survive
-- NG+.  This bucket belongs to one concrete playthrough only: it closes an
-- encounter after that run completed it and is cleared at save.new_game.

return function(mod)
  local E = {
    KEY = "kaHoennEndgameRunEvents67",
    VERSION = 1,
    IDS = {
      MOLTRES=true, REGIROCK=true, REGICE=true, REGISTEEL=true,
      DEOXYS=true,
    },
  }

  local function saveOf(value)
    if type(value) ~= "table" then return nil end
    return value.save or value
  end

  function E.state(value, create)
    local save = saveOf(value)
    if not save then return nil end
    local state = save[E.KEY]
    if type(state) ~= "table" then
      if not create then return nil end
      state = { version=E.VERSION, completed={}, progress={} }
      save[E.KEY] = state
    end
    state.version = E.VERSION
    state.completed = type(state.completed) == "table"
      and state.completed or {}
    state.progress = type(state.progress) == "table" and state.progress or {}
    for id, receipt in pairs(state.completed) do
      if not E.IDS[id] or type(receipt) ~= "table" then
        state.completed[id] = nil
      end
    end
    return state
  end

  function E.progress(value, id, default)
    local state = E.state(value, false)
    if not state or state.progress[id] == nil then return default end
    return state.progress[id]
  end

  function E.setProgress(value, id, progress)
    local state = E.state(value, true)
    if not state then return false, "save" end
    state.progress[id] = progress
    return true
  end

  function E.completed(value, id)
    id = type(id) == "string" and id:upper() or nil
    local state = id and E.state(value, false)
    return state ~= nil and type(state.completed[id]) == "table"
  end

  function E.mark(value, id, receipt)
    id = type(id) == "string" and id:upper() or nil
    if not (id and E.IDS[id]) then return false, "unknown-event" end
    local state = E.state(value, true)
    if not state then return false, "save" end
    if state.completed[id] then return false, "recorded" end
    receipt = type(receipt) == "table" and receipt or {}
    state.completed[id] = {
      map = receipt.map,
      level = tonumber(receipt.level),
      result = "completed",
      battleResult = receipt.battleResult,
      captured = receipt.captured == true,
    }
    return true, state.completed[id]
  end

  function E.reset(value)
    local save = saveOf(value)
    if not save then return false, "save" end
    save[E.KEY] = { version=E.VERSION, completed={}, progress={} }
    return true
  end

  function E.deoxysReady(value)
    return E.completed(value, "MOLTRES")
      and E.completed(value, "REGIROCK")
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("save.new_game", function(nextNewGame, save)
      local fresh = nextNewGame(save)
      E.reset(fresh)
      return fresh
    end, 4240)
  end

  return E
end
