-- A hidden legendary entrance returns to the exact route that was used.
-- Store only an authored entrance id; never trust persisted warp coordinates.
return function(mod)
  local R = { key = 'hidden_access_legend_return', definitions = {} }
  local function bucket(save)
    save.modData = save.modData or {}
    save.modData[mod.id] = save.modData[mod.id] or {}
    return save.modData[mod.id]
  end
  function R.bind(definitions)
    for _, def in ipairs(definitions) do
      if def.eligibility.kind ~= 'starter' then R.definitions[def.id] = def end
    end
  end
  function R.prepare(game, def)
    if not R.definitions[def.id] then return true end
    local data = bucket(game.save)
    local token = { owner = 'legend-access', previous = data[R.key] }
    data[R.key] = def.id
    return token
  end
  function R.rollback(game, token)
    if type(token) ~= 'table' or token.owner ~= 'legend-access' then return false end
    bucket(game.save)[R.key] = token.previous
    return true
  end
  function R.point(save, mapId)
    local data = save and save.modData and save.modData[mod.id]
    local def = data and R.definitions[data[R.key]]
    if not def or def.handoff.destination.map ~= mapId then return nil end
    return def.returnToKanto
  end
  function R.clear(save)
    local data = save and save.modData and save.modData[mod.id]
    if data then data[R.key] = nil end
  end
  return R
end
