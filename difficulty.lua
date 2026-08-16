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

  function D.adjustLevel(level, kind, badges)
    local base = math.max(1, math.floor(tonumber(level) or 1))
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
  mod.hooks:wrap("trainer.party", function(nextParty, oppClass, partyIndex, party)
    local resolved = nextParty(oppClass, partyIndex, party)
    local adjusted, overflow = D.adjustParty(resolved, D.progressBadges())
    if #pending >= 8 then table.remove(pending, 1) end
    pending[#pending + 1] = { class = oppClass, party = partyIndex,
      overflow = overflow }
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
    local row = table.remove(pending, 1)
    local excess = 0
    for _, value in ipairs(row and row.overflow or {}) do
      excess = math.max(excess, tonumber(value) or 0)
    end
    battle.ascendantDifficulty = mod.options:get("difficulty") or "standard"
    battle.ascendantDifficultyOverflow = excess
    if excess > 0 and opts.mastery and opts.mastery.apply then
      battle.difficultyMastery = opts.mastery.apply(game, battle, {
        kind = "difficulty", key = "difficulty:" .. battle.ascendantDifficulty,
        progress = 0, masteryWins = 0, difficultyOverflow = excess,
      })
    end
  end, 170)

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
