-- Step-driven post-game events.  They use the existing global step clock,
-- so they work without a real-time clock and remain deterministic in saves.

local EVENTS = {
  {
    id = "training_rush",
    en = "TRAINING RUSH", de = "TRAININGSRAUSCH",
    bodyEn = "Trainer recovery and\nsilent growth advance\ntwice per step.",
    bodyDe = "Trainer-Erholung und\nstilles Wachstum laufen\ndoppelt pro Schritt.",
  },
  {
    id = "johto_migration",
    en = "JOHTO MIGRATION", de = "JOHTO-WANDERUNG",
    bodyEn = "Rare Johto species\nmigrate onto one Kanto\nroute.",
    bodyDe = "Seltene Johto-Arten\nwandern auf eine\nKanto-Route.",
  },
  {
    id = "golden_wind",
    en = "GOLDEN WIND", de = "GOLDENER WIND",
    bodyEn = "Every wild encounter\nreceives two extra\nshiny rolls.",
    bodyDe = "Jede wilde Begegnung\nerhält zwei weitere\nShiny-Würfe.",
  },
  {
    id = "frontier_festival",
    en = "FRONTIER FESTIVAL", de = "FRONTIER-FEST",
    bodyEn = "Ascendant Frontier\nvictories award double\nFrontier Points.",
    bodyDe = "Ascendant-Frontier-\nSiege geben doppelte\nFrontier-Punkte.",
  },
}

local MIGRATIONS = {
  { map = "ROUTE_2", species = "STANTLER" },
  { map = "ROUTE_4", species = "PHANPY" },
  { map = "ROUTE_8", species = "HOUNDOUR" },
  { map = "ROUTE_12", species = "MARILL" },
  { map = "ROUTE_15", species = "YANMA" },
  { map = "ROUTE_22", species = "LARVITAR" },
}

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = opts.postgame
  local johtoResearch = opts.johtoResearch
  local beyondKanto = opts.beyondKanto or opts.johtoBoundary
  -- The shared WORLD hub can own presentation while this controller keeps
  -- driving its existing events. Omitted means enabled for 5.3 compatibility.
  local showMenu = opts.showMenu ~= false
  local W = { game = nil }

  local function boundaryActive(game)
    return not beyondKanto or type(beyondKanto.isActive) ~= "function"
      or beyondKanto.isActive(game or W.game)
  end

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state(create)
    local s = mod.save:get("world_events")
    if type(s) ~= "table" and create ~= false then
      s = { version = 1, index = 0, nextAt = 0 }
      mod.save:set("world_events", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.index = math.max(0, math.floor(tonumber(s.index) or 0))
      s.nextAt = math.max(0, math.floor(tonumber(s.nextAt) or 0))
      if type(s.active) == "table" then
        s.active.steps = math.max(0,
          math.floor(tonumber(s.active.steps) or 0))
        if s.active.steps == 0 then s.active = nil end
      end
      -- NG+ may carry an old event bucket into a freshly sealed save. Keep
      -- every Kanto event, but discard the one active Johto spawn before it
      -- can be announced, displayed or consulted by encounter.roll.
      if s.active and s.active.id == "johto_migration"
          and not boundaryActive(W.game) then
        s.active = nil
      end
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("world_events", s) end
  end

  local function rowFor(id)
    for _, row in ipairs(EVENTS) do if row.id == id then return row end end
  end

  local function active(id)
    local s = state(false)
    return s and s.active and s.active.id == id
      and s.active.steps > 0 or false
  end

  local function displayActive(game, s)
    local current = s and s.active
    if not current then
      return tr(
        ("The world is calm.\fNext event in %d\nsteps."):format(
          math.max(0, s.nextAt - (tonumber(mod.save:get("step_clock", 0)) or 0))),
        ("Die Welt ist ruhig.\fNächstes Ereignis in\n%d Schritten."):format(
          math.max(0, s.nextAt - (tonumber(mod.save:get("step_clock", 0)) or 0))))
    end
    local row = rowFor(current.id)
    local text = tr(row.en, row.de) .. "\n" .. tr(row.bodyEn, row.bodyDe)
      .. ("\f%s: %d"):format(tr("STEPS LEFT", "SCHRITTE ÜBRIG"),
        current.steps)
    if current.id == "johto_migration" then
      local def = game and game.data and game.data.pokemon[current.species]
      text = text .. ("\f%s\n%s"):format(
        def and def.name or current.species,
        tostring(current.map):gsub("_", " "))
    end
    return text
  end

  local function announce(game, s)
    if not (game and game.stack and s.active and not s.active.announced) then
      return
    end
    s.active.announced = true
    persist(s)
    game.stack:push(require("src.render.TextBox").new(game,
      tr("KANTO WORLD EVENT", "KANTO-WELTEREIGNIS")
      .. "\f" .. displayActive(game, s)))
  end

  local function johtoFinaleComplete()
    if not johtoResearch then return false end
    local research = johtoResearch.state(false)
    return research and research.finalReward and true or false
  end

  local function migrationAvailable(row)
    if not boundaryActive(W.game) then return false end
    return row.species ~= "LARVITAR" or johtoFinaleComplete()
  end

  local function migrationFor(cycle)
    local available = {}
    for _, row in ipairs(MIGRATIONS) do
      if migrationAvailable(row) then available[#available + 1] = row end
    end
    if #available == 0 then return nil end
    return available[((cycle - 1) % #available) + 1]
  end

  local function startEvent(game, s, clock)
    local row
    repeat
      s.index = s.index + 1
      row = EVENTS[((s.index - 1) % #EVENTS) + 1]
    until row.id ~= "johto_migration" or boundaryActive(game)
    s.active = { id = row.id, steps = 2048, announced = false }
    if row.id == "johto_migration" then
      local cycle = math.floor((s.index - 1) / #EVENTS) + 1
      local migration = migrationFor(cycle)
      if migration then
        s.active.map, s.active.species = migration.map, migration.species
      else
        s.active = nil
      end
    end
    s.nextAt = clock + 4096
    persist(s)
    announce(game, s)
  end

  function W.onStep(game, clock)
    W.game = game or W.game
    if not (W.game and postgame and postgame.hasHallOfFame(W.game.save)) then
      return
    end
    local s = state()
    clock = math.max(0, math.floor(tonumber(clock) or 0))
    if s.nextAt == 0 then s.nextAt = clock + 1024 end
    if s.active then
      s.active.steps = s.active.steps - 1
      if s.active.steps <= 0 then s.active = nil end
      persist(s)
    elseif clock >= s.nextAt then
      startEvent(W.game, s, clock)
    end
  end

  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    local out = nextRoll(encDef, ctx)
    local s = state(false)
    local event = s and s.active
    if not (out and event and event.id == "johto_migration"
        and boundaryActive(ctx and ctx.game)
        and event.steps > 0 and ctx and ctx.mapId == event.map) then
      return out
    end
    if ctx.rng(1, 5) == 1 then
      return { species = event.species, level = out.level }
    end
    return out
  end, 170)

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if not showMenu then return out end
    if type(out) ~= "table" or not (postgame
        and postgame.hasHallOfFame(game.save)) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("WORLD", "WELT"),
      ascendantMenu = true,
      ascendantLabel = tr("WORLD STATUS", "WELT-STATUS"),
      ascendantOrder = 20,
      onSelect = function()
        game.stack:push(require("src.render.TextBox").new(game,
          displayActive(game, state())))
      end,
    })
  end, 240)

  mod.events:on("map.entered", function(ev)
    if ev and ev.game then W.game = ev.game end
    if W.game then announce(W.game, state()) end
  end)

  function W.install(game)
    W.game = game
    local s = state()
    if s.nextAt == 0 then
      s.nextAt = math.max(0,
        math.floor(tonumber(mod.save:get("step_clock", 0)) or 0)) + 1024
      persist(s)
    end
  end

  if beyondKanto and type(beyondKanto.onChanged) == "function" then
    beyondKanto.onChanged(function(activeNow, game)
      W.game = game or W.game
      if activeNow then return end
      local s = state(false)
      if s and s.active and s.active.id == "johto_migration" then
        s.active = nil
        persist(s)
      end
    end)
  end

  W.state = state
  W.active = active
  W.migrationAvailable = migrationAvailable
  W.trainingStepBonus = function() return active("training_rush") and 1 or 0 end
  W.shinyBonusRolls = function() return active("golden_wind") and 2 or 0 end
  W.frontierMultiplier = function()
    return active("frontier_festival") and 2 or 1
  end
  W.statusText = function(game) return displayActive(game or W.game, state()) end
  W.events = EVENTS
  W.migrations = MIGRATIONS
  return W
end
