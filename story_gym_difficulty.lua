-- First-story Gym difficulty packages.
--
-- This module deliberately owns only the eight canonical, pre-Hall-of-Fame
-- Gym battles.  It constructs authored rows before downstream Randomizer
-- hooks, while difficulty.lua remains the single owner of numerical level
-- bonuses and EXTREME's player-item lock.

return function(mod, opts)
  opts = opts or {}
  local S = {}
  local gameVersion = opts.gameVersion
  local yellowFidelity = opts.yellowFidelity
  local johtoUnlocked = opts.johtoUnlocked
  local resonanceRules = opts.resonanceRules
  local usefulLayerId = opts.usefulLayerId or "KA_REMATCH_USEFUL_MOVE"
  local currentGame

  local TIERS = {
    standard = { moveCount = 0, ai = nil, healCap = 0 },
    high = { moveCount = 3, ai = nil, healCap = 0 },
    hard = { moveCount = 3, ai = { 1, 3 }, healCap = 1, threshold = 25 },
    very_hard = {
      moveCount = 4, ai = { 1, 2, 3, usefulLayerId }, healCap = 2,
      threshold = 33,
    },
    extreme = {
      moveCount = 4, ai = { 1, 2, 3, usefulLayerId }, healCap = 2,
      threshold = 40,
    },
  }

  local MOVES = {
    GEODUDE = { "ROCK_SLIDE", "BODY_SLAM", "TACKLE", "BIDE" },
    ONIX = { "ROCK_SLIDE", "DIG", "SCREECH", "BIDE" },
    SANDSHREW = { "DIG", "ROCK_SLIDE", "SWIFT", "SWORDS_DANCE" },
    RHYHORN = { "ROCK_SLIDE", "DIG", "BODY_SLAM", "HORN_ATTACK" },
    STARYU = { "BUBBLEBEAM", "SWIFT", "THUNDER_WAVE", "PSYCHIC_M" },
    STARMIE = { "BUBBLEBEAM", "PSYCHIC_M", "THUNDER_WAVE", "SWIFT" },
    PSYDUCK = { "WATER_GUN", "BODY_SLAM", "DIG", "ICE_BEAM" },
    HORSEA = { "BUBBLEBEAM", "SMOKESCREEN", "ICE_BEAM", "SWIFT" },
    VOLTORB = { "SONICBOOM", "THUNDER_WAVE", "SCREECH", "SELFDESTRUCT" },
    PIKACHU = { "THUNDERBOLT", "THUNDER_WAVE", "QUICK_ATTACK", "DOUBLE_TEAM" },
    RAICHU = { "THUNDERBOLT", "MEGA_PUNCH", "MEGA_KICK", "THUNDER_WAVE" },
    MAGNEMITE = { "THUNDERBOLT", "THUNDER_WAVE", "SONICBOOM", "SWIFT" },
    MAGNETON = { "THUNDERBOLT", "THUNDER_WAVE", "SONICBOOM", "SWIFT" },
    ELECTABUZZ = { "THUNDERBOLT", "THUNDER_WAVE", "SUBMISSION", "QUICK_ATTACK" },
    JOLTEON = { "THUNDERBOLT", "THUNDER_WAVE", "BODY_SLAM", "QUICK_ATTACK" },
    VICTREEBEL = { "RAZOR_LEAF", "WRAP", "SLEEP_POWDER", "MEGA_DRAIN" },
    TANGELA = { "MEGA_DRAIN", "BIND", "TOXIC", "SWORDS_DANCE" },
    VILEPLUME = { "MEGA_DRAIN", "PETAL_DANCE", "SLEEP_POWDER", "ACID" },
    WEEPINBELL = { "MEGA_DRAIN", "WRAP", "SLEEP_POWDER", "ACID" },
    GLOOM = { "MEGA_DRAIN", "SLEEP_POWDER", "STUN_SPORE", "ACID" },
    PARASECT = { "MEGA_DRAIN", "STUN_SPORE", "LEECH_LIFE", "SWORDS_DANCE" },
    EXEGGCUTE = { "PSYCHIC_M", "LEECH_SEED", "HYPNOSIS", "REFLECT" },
    EXEGGUTOR = { "PSYCHIC_M", "MEGA_DRAIN", "HYPNOSIS", "REFLECT" },
    KOFFING = { "SLUDGE", "SMOKESCREEN", "TOXIC", "SELFDESTRUCT" },
    MUK = { "SLUDGE", "MINIMIZE", "BODY_SLAM", "TOXIC" },
    WEEZING = { "SLUDGE", "SMOKESCREEN", "TOXIC", "EXPLOSION" },
    VENONAT = { "PSYCHIC_M", "SLEEP_POWDER", "TOXIC", "LEECH_LIFE" },
    VENOMOTH = { "PSYCHIC_M", "SLEEP_POWDER", "TOXIC", "DOUBLE_TEAM" },
    ARBOK = { "ACID", "GLARE", "BITE", "WRAP" },
    GOLBAT = { "WING_ATTACK", "CONFUSE_RAY", "TOXIC", "BITE" },
    ABRA = { "PSYCHIC_M", "REFLECT", "THUNDER_WAVE", "SEISMIC_TOSS" },
    KADABRA = { "PSYCHIC_M", "RECOVER", "REFLECT", "PSYBEAM" },
    MR_MIME = { "PSYCHIC_M", "BARRIER", "LIGHT_SCREEN", "THUNDERBOLT" },
    ALAKAZAM = { "PSYCHIC_M", "RECOVER", "REFLECT", "THUNDER_WAVE" },
    HYPNO = { "PSYCHIC_M", "HYPNOSIS", "DREAM_EATER", "BODY_SLAM" },
    JYNX = { "PSYCHIC_M", "ICE_PUNCH", "LOVELY_KISS", "BODY_SLAM" },
    GROWLITHE = { "FIRE_BLAST", "TAKE_DOWN", "AGILITY", "LEER" },
    PONYTA = { "FIRE_SPIN", "STOMP", "TAKE_DOWN", "BODY_SLAM" },
    RAPIDASH = { "FIRE_BLAST", "FIRE_SPIN", "TAKE_DOWN", "BODY_SLAM" },
    ARCANINE = { "FIRE_BLAST", "BODY_SLAM", "DIG", "AGILITY" },
    NINETALES = { "FLAMETHROWER", "CONFUSE_RAY", "QUICK_ATTACK", "REFLECT" },
    MAGMAR = { "FIRE_BLAST", "PSYCHIC_M", "CONFUSE_RAY", "SUBMISSION" },
    FLAREON = { "FIRE_BLAST", "BITE", "BODY_SLAM", "REFLECT" },
    DUGTRIO = { "EARTHQUAKE", "SLASH", "SAND_ATTACK", "ROCK_SLIDE" },
    PERSIAN = { "SLASH", "PAY_DAY", "DOUBLE_TEAM", "BUBBLEBEAM" },
    NIDOQUEEN = { "EARTHQUAKE", "BODY_SLAM", "THUNDER", "DOUBLE_KICK" },
    NIDOKING = { "EARTHQUAKE", "THRASH", "THUNDERBOLT", "DOUBLE_KICK" },
    RHYDON = { "EARTHQUAKE", "ROCK_SLIDE", "STOMP", "FISSURE" },
    SANDSLASH = { "EARTHQUAKE", "SLASH", "SAND_ATTACK", "SWORDS_DANCE" },
  }

  local LEADERS = {
    OPP_BROCK = {
      map = "PEWTER_GYM", badge = "BOULDERBADGE", party = 1, ceiling = 25,
      core = {
        red = { { "GEODUDE", 12 }, { "ONIX", 14 } },
        yellow = { { "GEODUDE", 10 }, { "ONIX", 12 } },
      },
      additions = {
        hard = { "SANDSHREW" },
        very_hard = { "SANDSHREW", "RHYHORN" },
        extreme = { "SANDSHREW", "RHYHORN" },
      },
    },
    OPP_MISTY = {
      map = "CERULEAN_GYM", badge = "CASCADEBADGE", party = 1, ceiling = 32,
      core = { red = { { "STARYU", 18 }, { "STARMIE", 21 } },
        yellow = { { "STARYU", 18 }, { "STARMIE", 21 } } },
      additions = { hard = { "PSYDUCK" },
        very_hard = { "PSYDUCK", "HORSEA" },
        extreme = { "PSYDUCK", "HORSEA" } },
    },
    OPP_LT_SURGE = {
      map = "VERMILION_GYM", badge = "THUNDERBADGE", party = 1, ceiling = 40,
      core = {
        red = { { "VOLTORB", 21 }, { "PIKACHU", 18 }, { "RAICHU", 24 } },
        yellow = { { "RAICHU", 28 } },
      },
      additions = {
        red = { hard = { "MAGNEMITE" },
          very_hard = { "MAGNEMITE", "ELECTABUZZ" },
          extreme = { "MAGNEMITE", "ELECTABUZZ" } },
        yellow = { hard = { "VOLTORB" },
          very_hard = { "VOLTORB", "MAGNEMITE" },
          extreme = { "VOLTORB", "MAGNETON", "ELECTABUZZ", "JOLTEON" } },
      },
    },
    OPP_ERIKA = {
      map = "CELADON_GYM", badge = "RAINBOWBADGE", party = 1, ceiling = 48,
      core = {
        red = { { "VICTREEBEL", 29 }, { "TANGELA", 24 }, { "VILEPLUME", 29 } },
        yellow = { { "TANGELA", 30 }, { "WEEPINBELL", 32 }, { "GLOOM", 32 } },
      },
      additions = { hard = { "PARASECT" },
        very_hard = { "PARASECT", "EXEGGCUTE" },
        extreme = { "PARASECT", "EXEGGUTOR" } },
    },
    OPP_KOGA = {
      map = "FUCHSIA_GYM", badge = "SOULBADGE", party = 1, ceiling = 60,
      core = {
        red = { { "KOFFING", 37 }, { "MUK", 39 }, { "KOFFING", 37 },
          { "WEEZING", 43 } },
        yellow = { { "VENONAT", 44 }, { "VENONAT", 46 }, { "VENONAT", 48 },
          { "VENOMOTH", 50 } },
      },
      additions = { hard = { "ARBOK" },
        very_hard = { "ARBOK", "GOLBAT" }, extreme = { "ARBOK", "GOLBAT" } },
    },
    OPP_SABRINA = {
      map = "SAFFRON_GYM", badge = "MARSHBADGE", party = 1, ceiling = 65,
      core = {
        red = { { "KADABRA", 38 }, { "MR_MIME", 37 }, { "VENOMOTH", 38 },
          { "ALAKAZAM", 43 } },
        yellow = { { "ABRA", 50 }, { "KADABRA", 50 }, { "ALAKAZAM", 50 } },
      },
      additions = {
        red = { hard = { "HYPNO" }, very_hard = { "HYPNO", "JYNX" },
          extreme = { "HYPNO", "JYNX" } },
        yellow = { hard = { "MR_MIME" },
          very_hard = { "MR_MIME", "HYPNO" },
          extreme = { "MR_MIME", "HYPNO", "JYNX" } },
      },
    },
    OPP_BLAINE = {
      map = "CINNABAR_GYM", badge = "VOLCANOBADGE", party = 1, ceiling = 70,
      core = {
        red = { { "GROWLITHE", 42 }, { "PONYTA", 40 }, { "RAPIDASH", 42 },
          { "ARCANINE", 47 } },
        yellow = { { "NINETALES", 48 }, { "RAPIDASH", 50 },
          { "ARCANINE", 54 } },
      },
      additions = {
        red = { hard = { "NINETALES" },
          very_hard = { "NINETALES", "MAGMAR" },
          extreme = { "NINETALES", "MAGMAR" } },
        yellow = { hard = { "GROWLITHE" },
          very_hard = { "GROWLITHE", "MAGMAR" },
          extreme = { "GROWLITHE", "MAGMAR", "FLAREON" } },
      },
    },
    OPP_GIOVANNI = {
      map = "VIRIDIAN_GYM", badge = "EARTHBADGE", party = 3, ceiling = 72,
      core = {
        red = { { "RHYHORN", 45 }, { "DUGTRIO", 42 }, { "NIDOQUEEN", 44 },
          { "NIDOKING", 45 }, { "RHYDON", 50 } },
        yellow = { { "DUGTRIO", 50 }, { "PERSIAN", 53 }, { "NIDOQUEEN", 53 },
          { "NIDOKING", 55 }, { "RHYDON", 55 } },
      },
      additions = { hard = { "SANDSLASH" }, very_hard = { "SANDSLASH" },
        extreme = { "SANDSLASH" } },
    },
  }

  local function clone(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = clone(child) end
    return out
  end

  local function family(version)
    if version == "yellow" then return "yellow" end
    if version == "red" or version == "blue" then return "red" end
    return nil
  end

  local function activeEdition()
    local ok, version = pcall(function()
      return gameVersion and gameVersion.get and gameVersion.get()
    end)
    return ok and version or nil
  end

  local function tierName()
    local value = mod.options and mod.options.get
      and mod.options:get("difficulty") or "standard"
    return TIERS[value] and value or "standard"
  end

  local function hallOfFame(save)
    return save and ((type(save.hallOfFame) == "table" and #save.hallOfFame > 0)
      or (save.flags and save.flags.EVENT_BEAT_CHAMPION_RIVAL)) or false
  end

  local function coreFor(def, version)
    local key = family(version)
    return key and def.core[key] or nil
  end

  local function exactCore(party, core)
    if type(party) ~= "table" or type(core) ~= "table" or #party ~= #core then
      return false
    end
    for index, expected in ipairs(core) do
      local row = party[index]
      if type(row) ~= "table" or row.species ~= expected[1]
          or tonumber(row.level) ~= expected[2] or row.moves ~= nil then
        return false
      end
    end
    return true
  end

  local function contextFor(game, class, partyIndex, party, version)
    local def = LEADERS[class]
    local core = def and coreFor(def, version)
    if not (def and core and game and game.save and game.overworld
        and game.overworld.map and game.overworld.map.id == def.map
        and tonumber(partyIndex) == def.party and not hallOfFame(game.save)
        and not (game.save.inventory and game.save.inventory[def.badge])
        and exactCore(party, core)) then
      return nil
    end
    return def, core
  end

  local function battleContextValid(game, def)
    return def and game and game.save and game.overworld
      and game.overworld.map and game.overworld.map.id == def.map
      and not hallOfFame(game.save)
      and not (game.save.inventory and game.save.inventory[def.badge]) or false
  end

  local ADDITION_LEVEL_OFFSETS = {
    [1] = { -2 }, [2] = { -3, -1 }, [3] = { -4, -2, -1 },
    [4] = { -5, -3, -2, -1 },
  }

  -- Optional Crystal-era move polish for the original 151. The authoritative
  -- resonance catalogue already encodes machine/inherited/pre-evolution and
  -- minimum-level legality. We replace at most the final curated slot and
  -- fail closed unless boundary, rule and live move definition all agree.
  local JOHTO_PREFERRED = {
    ONIX = { "IRON_TAIL" }, SANDSHREW = { "METAL_CLAW", "IRON_TAIL" },
    SANDSLASH = { "METAL_CLAW", "IRON_TAIL" },
    RHYHORN = { "CRUNCH", "IRON_TAIL" }, RHYDON = { "CRUNCH", "IRON_TAIL" },
    PSYDUCK = { "IRON_TAIL" }, PIKACHU = { "IRON_TAIL" },
    RAICHU = { "IRON_TAIL" }, ELECTABUZZ = { "IRON_TAIL" },
    JOLTEON = { "IRON_TAIL", "SHADOW_BALL" },
    VICTREEBEL = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    TANGELA = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    VILEPLUME = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    WEEPINBELL = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    GLOOM = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    PARASECT = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    EXEGGCUTE = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    EXEGGUTOR = { "GIGA_DRAIN", "SLUDGE_BOMB" },
    KOFFING = { "SLUDGE_BOMB" }, MUK = { "SLUDGE_BOMB", "GIGA_DRAIN" },
    WEEZING = { "SLUDGE_BOMB" }, VENONAT = { "SLUDGE_BOMB", "GIGA_DRAIN" },
    VENOMOTH = { "SLUDGE_BOMB", "GIGA_DRAIN" },
    ARBOK = { "SLUDGE_BOMB", "GIGA_DRAIN", "CRUNCH" },
    GOLBAT = { "GIGA_DRAIN" },
    ABRA = { "SHADOW_BALL" }, KADABRA = { "SHADOW_BALL" },
    MR_MIME = { "SHADOW_BALL" }, ALAKAZAM = { "SHADOW_BALL" },
    HYPNO = { "SHADOW_BALL" }, JYNX = { "POWDER_SNOW", "SHADOW_BALL" },
    GROWLITHE = { "FLAME_WHEEL", "IRON_TAIL", "CRUNCH" },
    PONYTA = { "FLAME_WHEEL", "IRON_TAIL" },
    RAPIDASH = { "FLAME_WHEEL", "IRON_TAIL" },
    ARCANINE = { "FLAME_WHEEL", "IRON_TAIL", "CRUNCH" },
    NINETALES = { "IRON_TAIL" }, MAGMAR = { "IRON_TAIL" },
    FLAREON = { "IRON_TAIL", "SHADOW_BALL" },
    DUGTRIO = { "SLUDGE_BOMB" }, PERSIAN = { "SHADOW_BALL", "IRON_TAIL" },
    NIDOQUEEN = { "SHADOW_BALL", "IRON_TAIL" },
    NIDOKING = { "SHADOW_BALL", "IRON_TAIL" },
  }

  local function additionsFor(def, version, tier)
    local rows = def.additions or {}
    local scoped = rows[family(version)]
    return clone((scoped and scoped[tier]) or rows[tier] or {})
  end

  local function johtoActive()
    if type(johtoUnlocked) ~= "function" then return false end
    local ok, active = pcall(johtoUnlocked)
    return ok and active == true
  end

  local function legalJohtoMove(species, level)
    if not johtoActive() or type(resonanceRules) ~= "table" then return nil end
    local rules = resonanceRules[species]
    local moves = currentGame and currentGame.data and currentGame.data.moves
    if type(rules) ~= "table" or type(moves) ~= "table" then return nil end
    for _, move in ipairs(JOHTO_PREFERRED[species] or {}) do
      local rule = rules[move]
      if type(rule) == "table" and rule.move == move and moves[move]
          and (rule.level == nil or tonumber(level) >= tonumber(rule.level)) then
        return move
      end
    end
    return nil
  end

  local function selectedMoves(species, count, level, tier)
    local source = assert(MOVES[species], "missing Gym move template: " .. species)
    local out = {}
    for index = 1, math.min(count, #source) do out[index] = source[index] end
    if tier ~= "standard" then
      local move = legalJohtoMove(species, level)
      if move and #out > 0 then out[#out] = move end
    end
    return out
  end

  local function buildParty(party, def, version, tier)
    local out = clone(party)
    if tier == "standard" then
      if version ~= "yellow" then return out end
      if yellowFidelity and type(yellowFidelity.apply) == "function" then
        return yellowFidelity.apply(def.class, out)
      end
      -- Missing fidelity support is an invalid integration context. Preserve
      -- the official rows instead of guessing at a second embedded table.
      return out
    end

    local moveCount = TIERS[tier].moveCount
    for _, row in ipairs(out) do
      row.moves = selectedMoves(row.species, moveCount, row.level, tier)
    end
    if tier == "high" then return out end

    local additions = additionsFor(def, version, tier)
    local offsets = ADDITION_LEVEL_OFFSETS[#additions] or {}
    local ace = out[#out]
    table.remove(out, #out)
    for index, species in ipairs(additions) do
      out[#out + 1] = {
        species = species,
        level = math.max(1, ace.level + (offsets[index] or -1)),
        moves = selectedMoves(species, moveCount,
          math.max(1, ace.level + (offsets[index] or -1)), tier),
      }
    end
    out[#out + 1] = ace
    return out
  end

  -- Publish immutable authored data for the later adaptive-level module. It
  -- can target these ace/floor/cap values without guessing at roster shape;
  -- this module itself never reads party/player level.
  S.authored = {}
  for class, def in pairs(LEADERS) do
    def.class = class
    local teamCap = {}
    for tier in pairs(TIERS) do
      local largest = 0
      for _, version in ipairs({ "red", "yellow" }) do
        largest = math.max(largest,
          #def.core[family(version)] + #additionsFor(def, version, tier))
      end
      teamCap[tier] = largest
    end
    S.authored[class] = {
      map = def.map, badge = def.badge, party = def.party,
      ceiling = def.ceiling,
      aceLevel = {
        red = def.core.red[#def.core.red][2],
        blue = def.core.red[#def.core.red][2],
        yellow = def.core.yellow[#def.core.yellow][2],
      },
      floors = {
        red = clone(def.core.red), blue = clone(def.core.red),
        yellow = clone(def.core.yellow),
      },
      teamCap = teamCap,
    }
  end
  S.tiers = clone(TIERS)
  S.moveTemplates = clone(MOVES)
  S.johtoPreferred = clone(JOHTO_PREFERRED)

  function S.plan(version, tier, class, party)
    local def = LEADERS[class]
    tier = TIERS[tier] and tier or "standard"
    if not (def and coreFor(def, version)
        and exactCore(party, coreFor(def, version))) then
      return clone(party), nil
    end
    return buildParty(party, def, version, tier), S.authored[class]
  end

  local pending = {}
  local function rememberGame(ev)
    currentGame = ev and ev.game or currentGame
  end
  mod.events:on("game.ready", rememberGame, 160)
  mod.events:on("save.loaded", rememberGame, 160)

  -- Lower than difficulty.lua (150): difficulty receives the final
  -- downstream result and raises every slot. Higher than Randomizer's
  -- established trainer hook (70): Randomizer maps the complete authored
  -- roster, including added slots.
  mod.hooks:wrap("trainer.party", function(nextParty, class, partyIndex, party)
    local version = activeEdition()
    local def = contextFor(currentGame, class, partyIndex, party, version)
    if not def then return nextParty(class, partyIndex, party) end
    local tier = tierName()
    if tier == "standard" and version ~= "yellow" then
      return nextParty(class, partyIndex, party)
    end
    local authored = buildParty(party, def, version, tier)
    local resolved = nextParty(class, partyIndex, authored)
    if type(resolved) == "table" and #resolved > 0 and #resolved <= 6 then
      for index = #pending, 1, -1 do
        local old = pending[index]
        if old.class == class and tonumber(old.party) == tonumber(partyIndex)
            and old.map == def.map then
          table.remove(pending, index)
        end
      end
      if #pending >= 16 then table.remove(pending, 1) end
      pending[#pending + 1] = {
        class = class, party = partyIndex, tier = tier, version = version,
        map = def.map, authoredParty = clone(authored),
        resolvedParty = clone(resolved),
      }
    end
    return resolved
  end, 110)

  local HEAL_ITEM = {
    hard = {
      OPP_BROCK = "POTION", OPP_MISTY = "SUPER_POTION",
      OPP_LT_SURGE = "SUPER_POTION", OPP_ERIKA = "SUPER_POTION",
      OPP_KOGA = "HYPER_POTION", OPP_SABRINA = "HYPER_POTION",
      OPP_BLAINE = "HYPER_POTION", OPP_GIOVANNI = "HYPER_POTION",
    },
    very_hard = {
      OPP_BROCK = "SUPER_POTION", OPP_MISTY = "SUPER_POTION",
      OPP_LT_SURGE = "SUPER_POTION", OPP_ERIKA = "SUPER_POTION",
      OPP_KOGA = "HYPER_POTION", OPP_SABRINA = "HYPER_POTION",
      OPP_BLAINE = "HYPER_POTION", OPP_GIOVANNI = "HYPER_POTION",
    },
    extreme = {
      OPP_BROCK = "SUPER_POTION", OPP_MISTY = "SUPER_POTION",
      OPP_LT_SURGE = "SUPER_POTION", OPP_ERIKA = "HYPER_POTION",
      OPP_KOGA = "HYPER_POTION", OPP_SABRINA = "HYPER_POTION",
      OPP_BLAINE = "HYPER_POTION", OPP_GIOVANNI = "HYPER_POTION",
    },
  }

  local function healCap(class, tier)
    if tier == "very_hard" and (class == "OPP_BROCK" or class == "OPP_MISTY")
        then return 1 end
    if tier == "extreme" and class == "OPP_BROCK" then return 1 end
    return TIERS[tier].healCap or 0
  end

  local function takePending(battle)
    local map = battle and battle.game and battle.game.overworld
      and battle.game.overworld.map and battle.game.overworld.map.id
    for index, row in ipairs(pending) do
      if row.class == battle.oppClass
          and tonumber(row.party) == tonumber(battle.partyIndex)
          and row.map == map then
        table.remove(pending, index)
        return row
      end
    end
    return nil
  end

  local function moveId(move)
    return type(move) == "table" and move.id or move
  end

  -- A constructor can be abandoned or another mod can replace its output
  -- after our trainer.party link returns. Never attach Gym policy to a later
  -- battle merely because class/index/map happen to match a stale queue row.
  -- difficulty.lua may add one uniform numerical bonus, so levels compare by
  -- delta; species, slot order and explicit moves must still match exactly.
  local function matchesResolvedParty(actual, expected)
    if type(actual) ~= "table" or type(expected) ~= "table"
        or #actual ~= #expected or #actual == 0 then return false end
    local levelDelta
    for index, row in ipairs(expected) do
      local mon = actual[index]
      if type(mon) ~= "table" or mon.species ~= row.species then return false end
      local actualLevel, expectedLevel = tonumber(mon.level), tonumber(row.level)
      if not (actualLevel and expectedLevel) then return false end
      local delta = actualLevel - expectedLevel
      if delta < 0 or delta > 10 then return false end
      if levelDelta == nil then levelDelta = delta
      elseif delta ~= levelDelta then return false end
      if row.moves ~= nil then
        if type(mon.moves) ~= "table" or #mon.moves ~= #row.moves then
          return false
        end
        for moveIndex, expectedMove in ipairs(row.moves) do
          if moveId(mon.moves[moveIndex]) ~= expectedMove then return false end
        end
      end
    end
    return true
  end

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not (battle and battle.kind == "trainer" and not battle.rematch
        and not battle.ascendantForcedBattle) then return end
    local row = takePending(battle)
    if not row then return end
    local def = LEADERS[row.class]
    if not battleContextValid(battle.game, def)
        or not matchesResolvedParty(battle.enemyParty, row.resolvedParty) then
      return
    end
    battle.ascendantStoryGym = true
    battle.ascendantStoryGymDifficulty = row.tier
    battle.ascendantStoryGymClass = row.class
    battle.ascendantStoryLevelCeiling = def.ceiling
    -- Adaptive level composition runs later on battle.started. It may alter
    -- levels within the published ceiling, but must retain these legal,
    -- authored move sets (including the gated Johto overlay).
    battle.ascendantStoryPreserveAuthoredMoves = true
    battle.ascendantStoryGymAuthored = S.authored[row.class]
    battle.ascendantStoryGymAuthoredParty = clone(row.authoredParty)
    battle.ascendantStoryGymResolvedParty = clone(row.resolvedParty)
    battle.ascendantStoryGymAdjustedParty = battle.enemyParty
    local policy = TIERS[row.tier]
    if policy.ai then battle.enemyAIMods = clone(policy.ai) end
    battle.ascendantStoryGymHealCap = healCap(row.class, row.tier)
    battle.ascendantStoryGymHealUses = 0
    battle.ascendantStoryGymHealThreshold = policy.threshold or 0
    battle.ascendantStoryGymHealItem = HEAL_ITEM[row.tier]
      and HEAL_ITEM[row.tier][row.class] or nil
  end, 180)

  mod.hooks:wrap("battle.enemy_action", function(nextAction, battle)
    local cap = tonumber(battle and battle.ascendantStoryGymHealCap) or 0
    if cap <= 0 then return nextAction(battle) end
    -- Hard+ owns one battle-wide HP-item budget. Suppress the stock class
    -- counter, which otherwise resets for each newly sent-out Pokémon.
    battle.aiUses = 0
    if type(battle.lockedAction) == "function"
        and battle:lockedAction(battle.enemy) then
      return nextAction(battle)
    end
    local mon = battle.enemy and battle.enemy.mon
    local maxHP = mon and mon.stats and tonumber(mon.stats.hp)
    local hp = mon and tonumber(mon.hp)
    local used = tonumber(battle.ascendantStoryGymHealUses) or 0
    local threshold = tonumber(battle.ascendantStoryGymHealThreshold) or 0
    if hp and maxHP and maxHP > 0 and used < cap
        and hp * 100 < maxHP * threshold then
      battle.ascendantStoryGymHealUses = used + 1
      return { special = "aiItem", item = battle.ascendantStoryGymHealItem }
    end
    return nextAction(battle)
  end, 4700)

  return S
end
