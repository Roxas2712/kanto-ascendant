-- Difficulty policy. The table is the single source of truth for
-- trainer/wild offsets and the Extreme battle-item restriction.

return function(mod, opts)
  opts = opts or {}
  local D = {}
  local Badges = require("src.inventory.Badges")
  local currentGame = mod.game
  D.PRESETS = {
    standard  = { trainer = 0,  wild = 0, items = true,
      trainerEarly = 0, trainerFullAt = 0, wildEarly = 0, wildFullAt = 0 },
    high      = { trainer = 3,  wild = 2, items = true,
      trainerEarly = 1, trainerFullAt = 6, wildEarly = 1, wildFullAt = 4 },
    hard      = { trainer = 5,  wild = 3, items = true,
      trainerEarly = 2, trainerFullAt = 6, wildEarly = 2, wildFullAt = 4 },
    very_hard = { trainer = 8,  wild = 5, items = true,
      trainerEarly = 3, trainerFullAt = 5, wildEarly = 3, wildFullAt = 4 },
    extreme   = { trainer = 10, wild = 7, items = false,
      trainerEarly = 4, trainerFullAt = 6, wildEarly = 4, wildFullAt = 6 },
  }

  local function preset()
    return D.PRESETS[mod.options:get("difficulty")] or D.PRESETS.standard
  end

  local function clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = clone(child) end
    return out
  end

  -- Difficulty used to add its complete late-game offset to every authored
  -- level. That turns the official level-5 Oak-lab opponent into level 13 on
  -- VERY HARD before the player can train. Phase only the numerical bonus in
  -- through ordinary badge progress: no trainer-class, edition, player-name
  -- or save-slot exception is involved, and six badges restore every original
  -- trainer offset (wild offsets finish no later than that).
  local function phased(full, early, fullAt, badges)
    full = math.max(0, math.floor(tonumber(full) or 0))
    early = math.max(0, math.min(full,
      math.floor(tonumber(early) or full)))
    fullAt = math.max(0, math.floor(tonumber(fullAt) or 0))
    if badges == nil or fullAt == 0 or early >= full then return full end
    badges = math.max(0, math.floor(tonumber(badges) or 0))
    if badges >= fullAt then return full end
    return early + math.floor((full - early) * badges / fullAt)
  end

  function D.progressionBonus(kind, badges, name)
    local row = D.PRESETS[name] or preset()
    local full = row[kind] or 0
    return phased(full, row[kind .. "Early"], row[kind .. "FullAt"], badges)
  end

  function D.progressBadges(game)
    game = game or currentGame
    if not (game and game.save) then return nil end
    return math.max(0, math.min(8, Badges.count(game.data, game.save)))
  end

  function D.wildScalingEnabled()
    return mod.options:get("wild_level_scaling") == true
  end

  function D.adjustLevel(level, kind, badges)
    local base = math.max(1, math.floor(tonumber(level) or 1))
    -- The encounter hook runs after native tables, Randomizer mappings and
    -- authored KASC encounter providers have resolved their candidate. OFF
    -- therefore means exactly "keep that resolved level": it does not alter
    -- species, tables, RNG, Nuzlocke state or any trainer-level policy.
    if kind == "wild" and not D.wildScalingEnabled() then return base, 0 end
    local extra = D.progressionBonus(kind, badges)
    local raised = base + extra
    return math.min(100, raised), math.max(0, raised - 100)
  end

  function D.adjustParty(party, badges)
    local out, overflow = clone(party or {}), {}
    for index, row in ipairs(out) do
      row.level, overflow[index] = D.adjustLevel(
        row.level, "trainer", badges)
    end
    return out, overflow
  end

  local function rememberGame(ev)
    currentGame = ev and ev.game or currentGame
  end
  mod.events:on("game.ready", rememberGame, 160)
  mod.events:on("save.loaded", rememberGame, 160)

  local pending = {}
  local function partySignature(party)
    if type(party) ~= "table" or #party < 1 then return nil end
    local out = {}
    for index, mon in ipairs(party) do
      local level = type(mon) == "table" and tonumber(mon.level)
      local species = type(mon) == "table" and mon.species
      if type(species) ~= "string" or not level
          or level ~= math.floor(level) then return nil end
      out[index] = species .. "@" .. tostring(level)
    end
    return table.concat(out, "|")
  end

  mod.hooks:wrap("trainer.party", function(nextParty, oppClass, partyIndex, party)
    local resolved = nextParty(oppClass, partyIndex, party)
    local badges = D.progressBadges()
    local difficultyName = mod.options:get("difficulty") or "standard"
    local adjusted, overflow = D.adjustParty(resolved, badges)
    if #pending >= 8 then table.remove(pending, 1) end
    pending[#pending + 1] = { class = oppClass, party = partyIndex,
      overflow = overflow, authoredParty = clone(resolved),
      adjustedParty = clone(adjusted), badges = badges,
      difficulty = difficultyName, signature = partySignature(adjusted) }
    return adjusted
  end, 150)

  mod.hooks:wrap("encounter.species", function(nextEncounter, enc, ctx)
    local out = nextEncounter(enc, ctx)
    if type(out) ~= "table" then return out end
    out = clone(out)
    out.level = D.adjustLevel(out.level, "wild", D.progressBadges())
    return out
  end, 150)

  -- Excess that would have crossed level 100 feeds the existing
  -- mastery path.  Its capped quality band gives a modest deterministic
  -- improvement, never an instant perfect opponent.
  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    local game = battle and battle.game
    if not (battle and game and battle.kind == "trainer") then return end
    -- Battle constructors need not be pushed immediately and some preview
    -- paths intentionally abandon a constructed battle. Resolve provenance
    -- by the actual class/party/signature instead of consuming an unrelated
    -- FIFO row. The newest exact row wins; older rows for that same trainer
    -- key are stale and are discarded together.
    local row, matchedIndex
    local signature = partySignature(battle.enemyParty)
    for index = #pending, 1, -1 do
      local candidate = pending[index]
      if candidate.class == battle.oppClass
          and candidate.party == battle.partyIndex
          and candidate.signature == signature then
        row, matchedIndex = candidate, index
        break
      end
    end
    if matchedIndex then
      for index = #pending, 1, -1 do
        local candidate = pending[index]
        if index == matchedIndex or (candidate.class == row.class
            and candidate.party == row.party) then
          table.remove(pending, index)
        end
      end
    else
      -- A later hook may have changed the roster after Difficulty resolved
      -- it. Consume only records for this exact trainer key; other pending
      -- constructors remain available and Adaptive safely stays classic.
      for index = #pending, 1, -1 do
        local candidate = pending[index]
        if candidate.class == battle.oppClass
            and candidate.party == battle.partyIndex then
          table.remove(pending, index)
        end
      end
    end
    local excess = 0
    for _, value in ipairs(row and row.overflow or {}) do
      excess = math.max(excess, tonumber(value) or 0)
    end
    battle.ascendantDifficulty = mod.options:get("difficulty") or "standard"
    battle.ascendantDifficultyOverflow = excess
    -- Frozen, read-only provenance for the lower-priority adaptive story
    -- policy. The consumer verifies the entire species/level signature before
    -- changing anything, so a queue mismatch or another trainer hook falls
    -- back to the exact classic battle.
    if row then
      battle.ascendantDifficultyContext = {
        class = row.class, party = row.party,
        authoredParty = clone(row.authoredParty),
        adjustedParty = clone(row.adjustedParty),
        badges = row.badges, difficulty = row.difficulty,
      }
    end
    if excess > 0 and opts.mastery and opts.mastery.apply then
      battle.difficultyMastery = opts.mastery.apply(game, battle, {
        kind = "difficulty", key = "difficulty:" .. battle.ascendantDifficulty,
        progress = 0, masteryWins = 0, difficultyOverflow = excess,
      })
    end
  end, 170)

  -- Read-only diagnostics used by the deterministic abandoned-constructor
  -- regression. Gameplay code never depends on the queue size.
  function D.pendingDifficultyCount(oppClass, partyIndex)
    if oppClass == nil then return #pending end
    local count = 0
    for _, row in ipairs(pending) do
      if row.class == oppClass
          and (partyIndex == nil or row.party == partyIndex) then
        count = count + 1
      end
    end
    return count
  end

  function D.itemsAllowed(battle)
    return not (battle and battle.kind == "trainer" and preset().items == false)
  end

  local BagMenu = require("src.ui.BagMenu")
  if not BagMenu._ascendantDifficultyWrapped then
    local originalNew = BagMenu.new
    BagMenu.new = function(game, bagOpts)
      local list = originalNew(game, bagOpts)
      local originalChoose = list.onChoose
      list.onChoose = function(item, menu)
        local policy = BagMenu._ascendantDifficultyPolicy
        local battle = bagOpts and bagOpts.battle
        if battle and policy and not policy.itemsAllowed(battle) then
          local TextBox = require("src.render.TextBox")
          game.stack:push(TextBox.new(game,
            policy.text("Items cannot be used\nin EXTREME trainer battles.",
              "In EXTREM-Trainerkämpfen\nsind Items gesperrt.")))
          return
        end
        return originalChoose(item, menu)
      end
      return list
    end
    BagMenu._ascendantDifficultyWrapped = true
  end
  BagMenu._ascendantDifficultyPolicy = {
    itemsAllowed = D.itemsAllowed,
    text = function(en, de)
      return opts.i18n and opts.i18n.text(en, de) or en
    end,
  }

  return D
end
