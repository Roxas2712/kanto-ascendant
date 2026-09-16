-- KASC-67-GENERATION-MACHINES
--
-- One stable inventory item per TM move.  The item keeps the number from its
-- first mainline appearance, while availability grows cumulatively with the
-- active generation profile.  Existing native/feature-owned TMs remain owner.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "generation machine data missing")
  local rules = assert(opts.generationRules, "generation rules missing")
  assert(data._meta and data._meta.machineCount == 141,
    "generation machine authority cardinality drift")

  local M = {
    data = data, byItem = {}, byMove = {},
    audit = { registered = 0, preserved = 0, missingMove = 0 },
  }

  local function itemEpoch(game, id, def)
    local row = M.byItem[id]
    if not row then return tonumber(def and def.originEpoch) or 1 end
    local explicit = tonumber(def and (def.originEpoch
      or def.originGeneration))
    if explicit then return math.max(1, math.floor(explicit)) end
    if row.preserved then
      -- Native Gen-I machines and older feature Cards keep their earlier
      -- provenance. A preserved later move still resolves to its true move
      -- epoch (for example Iron Tail -> Gen II).
      return math.min(row.originEpoch,
        rules.moveEpoch(row.move, game and game.data))
    end
    return row.originEpoch
  end

  for _, source in ipairs(data.machines or {}) do
    local row = {
      item = source.item, move = source.move,
      originEpoch = source.originEpoch, number = source.number,
    }
    M.byItem[row.item], M.byMove[row.move] = row, row
    local move = mod.content.moves:get(row.move)
    if not move then
      M.audit.missingMove = M.audit.missingMove + 1
    else
      local existing = mod.content.items:get(row.item)
      if existing then
        row.preserved = true
        M.audit.preserved = M.audit.preserved + 1
      else
        mod.content.items:register(row.item, {
          id = row.item,
          name = ("TM%d-%02d"):format(row.originEpoch, row.number),
          price = 3000, tossable = true, needsTarget = true,
          machine = { kind = "TM", move = row.move, number = row.number },
          originEpoch = row.originEpoch, generationMachine = true,
        })
        M.audit.registered = M.audit.registered + 1
      end
    end
  end

  function M.epochFor(game, id, def)
    return itemEpoch(game, id, def)
  end

  function M.available(game, id, def)
    local resolved = rules.resolve(game)
    local epoch = resolved and resolved.activeEpoch or 1
    return itemEpoch(game, id, def) <= epoch
  end

  function M.rows(game)
    local out = {}
    for _, source in ipairs(data.machines or {}) do
      local def = game and game.data and game.data.items
        and game.data.items[source.item]
      if def and M.available(game, source.item, def) then
        out[#out + 1] = {
          id = source.item, move = source.move,
          number = source.number,
          originEpoch = itemEpoch(game, source.item, def),
        }
      end
    end
    return out
  end

  return M
end
