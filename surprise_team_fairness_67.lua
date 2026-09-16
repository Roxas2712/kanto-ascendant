-- Optional Surprise Trainer legality/BST closeout.
--
-- This card never inspects player types and therefore cannot manufacture a
-- hard counter. It uses only species strength, evolution ancestry and the
-- active cumulative move-source authority.

return function(mod, opts)
  opts = opts or {}
  local learnsets = opts.learnsets
  local rules = opts.generationRules
  local F = { MIN_UPPER_BST = 425, BST_MARGIN = 150 }

  local function enabled()
    return not (mod.options and type(mod.options.get) == "function"
      and mod.options:get("surprise_team_fairness") == false)
  end

  local function stats(def)
    return type(def) == "table" and (def.stats or def.baseStats) or nil
  end

  function F.bst(def)
    local row = stats(def)
    if type(row) ~= "table" then return nil end
    local total = 0
    for _, key in ipairs({ "hp", "attack", "defense", "speed", "special" }) do
      local value = tonumber(row[key])
      if not value then return nil end
      total = total + value
    end
    return total
  end

  local function speciesAllowed(game, species, def)
    if not rules or type(rules.speciesAvailable) ~= "function" then return true end
    local ok, allowed = pcall(rules.speciesAvailable, game, species, def)
    return ok and allowed == true
  end

  local function viablePlayerBsts(game)
    local out = {}
    local pokemon = game and game.data and game.data.pokemon or {}
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      local value = type(mon) == "table" and mon.isEgg ~= true
        and (tonumber(mon.hp) == nil or tonumber(mon.hp) > 0)
        and F.bst(pokemon[mon.species]) or nil
      if value then out[#out + 1] = value end
    end
    table.sort(out, function(a, b) return a > b end)
    while #out > 3 do table.remove(out) end
    return out
  end

  local function average(values)
    local total = 0
    for _, value in ipairs(values or {}) do total = total + value end
    return #values > 0 and total / #values or nil
  end

  local function evolutionTarget(row)
    return type(row) == "table" and (row.species or row[2]) or nil
  end

  local function parentsFor(pokemon)
    local parents = {}
    for species, def in pairs(pokemon or {}) do
      for _, evolution in ipairs(type(def.evolutions) == "table"
          and def.evolutions or {}) do
        local target = evolutionTarget(evolution)
        if target and pokemon[target] then
          parents[target] = parents[target] or {}
          parents[target][#parents[target] + 1] = species
        end
      end
    end
    for _, rows in pairs(parents) do table.sort(rows) end
    return parents
  end

  local function fairAncestor(game, species, upper, parents)
    local pokemon = game.data.pokemon
    local queue, seen, best = { species }, {}, nil
    local cursor = 1
    while cursor <= #queue do
      local candidate = queue[cursor]
      cursor = cursor + 1
      if not seen[candidate] then
        seen[candidate] = true
        local def, value = pokemon[candidate], F.bst(pokemon[candidate])
        if def and value and value <= upper and speciesAllowed(game, candidate, def)
            and (not best or value > best.bst
              or value == best.bst and candidate < best.species) then
          best = { species = candidate, bst = value }
        end
        for _, parent in ipairs(parents[candidate] or {}) do
          queue[#queue + 1] = parent
        end
      end
    end
    return best
  end

  local function moveId(value)
    return type(value) == "table" and (value.move or value.id) or value
  end

  local function legalMoves(game, species, level)
    local def = game.data.pokemon[species]
    local moves = game.data.moves or {}
    local rows, seen = {}, {}
    local function add(id, source, sourceLevel)
      id = moveId(id)
      if type(id) ~= "string" or not moves[id] or seen[id] then return end
      seen[id] = true
      rows[#rows + 1] = {
        id = id, source = source, level = tonumber(sourceLevel) or 0,
        power = tonumber(moves[id].power) or 0,
      }
    end
    for _, id in ipairs(type(def.level1Moves) == "table" and def.level1Moves or {}) do
      add(id, "level", 1)
    end
    for _, row in ipairs(type(def.learnset) == "table" and def.learnset or {}) do
      if (tonumber(row.level) or 1) <= level then add(row.move, "level", row.level) end
    end
    for _, id in ipairs(type(def.tmhm) == "table" and def.tmhm or {}) do
      add(id, "machine", 0)
    end
    if learnsets and type(learnsets.rowsFor) == "function" then
      local ok, extra = pcall(learnsets.rowsFor, game, species)
      if ok and type(extra) == "table" then
        for _, row in ipairs(extra) do
          if row.method ~= "L" or (tonumber(row.level) or 1) <= level then
            add(row.id, row.method == "T" and "tutor"
              or row.method == "M" and "machine" or "level", row.level)
          end
        end
      end
    end
    table.sort(rows, function(a, b)
      local ad, bd = a.power > 0 and 1 or 0, b.power > 0 and 1 or 0
      if ad ~= bd then return ad > bd end
      if a.power ~= b.power then return a.power > b.power end
      if a.level ~= b.level then return a.level > b.level end
      return a.id < b.id
    end)
    return rows, seen
  end

  local function normalizeMoves(game, mon)
    local rows, legal = legalMoves(game, mon.species,
      math.max(1, math.floor(tonumber(mon.level) or 1)))
    if #rows == 0 then return nil, "no-legal-move" end
    local selected, used = {}, {}
    for _, id in ipairs(type(mon.moves) == "table" and mon.moves or {}) do
      if legal[id] and not used[id] and #selected < 4 then
        used[id], selected[#selected + 1] = true, id
      end
    end
    for _, row in ipairs(rows) do
      if #selected >= 4 then break end
      if not used[row.id] then used[row.id], selected[#selected + 1] = true, row.id end
    end
    local damaging = false
    local function damage(id)
      local def=game.data.moves[id]
      return def and ((tonumber(def.power) or 0)>0
        or def.effect=='SPECIAL_DAMAGE_EFFECT' or def.effect=='SUPER_FANG_EFFECT'
        or def.effect=='OHKO_EFFECT')
    end
    for _, id in ipairs(selected) do
      if damage(id) then damaging = true break end
    end
    if not damaging then
      for _,row in ipairs(rows)do
        if damage(row.id) then
          selected[math.min(4,#selected+1)]=row.id;damaging=true;break
        end
      end
    end
    if not damaging then return nil, "no-damaging-move" end
    mon.moves = selected
    return true
  end

  function F.enforce(game, team)
    if not enabled() then return team, { enabled = false, reason = "disabled" } end
    if not (game and game.data and game.data.pokemon and game.data.moves) then
      return nil, { reason = "data" }
    end
    local playerBsts = viablePlayerBsts(game)
    local playerAverage = average(playerBsts)
    if not playerAverage then return nil, { reason = "player-bst" } end
    local upper = math.max(F.MIN_UPPER_BST,
      math.floor(playerAverage + F.BST_MARGIN + 0.5))
    local parents = parentsFor(game.data.pokemon)
    local out, report = {}, {
      enabled = true, playerBst = playerAverage, upperBst = upper,
      adjusted = {}, moveSources = { level = true, machine = true, tutor = true },
    }
    local before, after = {}, {}
    for index, source in ipairs(type(team) == "table" and team or {}) do
      local mon = {}
      for key, value in pairs(source) do mon[key] = value end
      local originalBst = F.bst(game.data.pokemon[mon.species])
      if not originalBst then return nil, { reason = "enemy-bst", index = index } end
      before[#before + 1] = originalBst
      if originalBst > upper then
        local replacement = fairAncestor(game, mon.species, upper, parents)
        if not replacement then
          return nil, { reason = "bst-window", index = index,
            species = mon.species, bst = originalBst, upperBst = upper }
        end
        report.adjusted[#report.adjusted + 1] = {
          index = index, from = mon.species, to = replacement.species,
          fromBst = originalBst, toBst = replacement.bst,
        }
        mon.species, mon.moves = replacement.species, nil
      end
      local ok, why = normalizeMoves(game, mon)
      if not ok then return nil, { reason = why, index = index } end
      after[#after + 1] = assert(F.bst(game.data.pokemon[mon.species]))
      out[#out + 1] = mon
    end
    report.enemyBstBefore = average(before)
    report.enemyBstAfter = average(after)
    return out, report
  end

  F.enabled = enabled
  F.legalMoves = legalMoves
  return F
end
