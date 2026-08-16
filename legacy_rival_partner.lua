-- NG+ partner counterpart for Oak's deliberately delayed rival choice.
--
-- The Oak catalogue owns the three physical balls and the player's choice.
-- This module owns only the resulting rival line and the trainer-party seam:
-- merely claiming the right ball never chooses a species.  Once the player's
-- choice is committed, the counterpart is derived once, stored in the same
-- legacy_journey table, and reused for every later battle and reload.

return function(mod, opts)
  opts = opts or {}
  local GameVersion = opts.GameVersion or require("src.core.GameVersion")
  local R = { game = nil }

  local RIVAL_CLASSES = {
    OPP_RIVAL1 = true, OPP_RIVAL2 = true, OPP_RIVAL3 = true,
  }

  -- Every candidate has a real early/middle/final battle curve and a strong
  -- final form.  Hoenn's three starters are valid counterparts for the fixed
  -- left NG+ ball; no Sinnoh species enter this catalogue.
  local LINES = {
    -- Yellow's one authored ball always contains Eevee. It remains Eevee for
    -- the early curve and reaches its familiar electric final counterpart.
    { lineId = "yellow_eevee", base = "EEVEE", mid = "EEVEE",
      final = "JOLTEON", attacks = { "NORMAL", "ELECTRIC" } },
    { lineId = "kanto_grass", base = "BULBASAUR", mid = "IVYSAUR",
      final = "VENUSAUR", attacks = { "GRASS", "POISON" } },
    { lineId = "kanto_fire", base = "CHARMANDER", mid = "CHARMELEON",
      final = "CHARIZARD", attacks = { "FIRE", "FLYING" } },
    { lineId = "kanto_water", base = "SQUIRTLE", mid = "WARTORTLE",
      final = "BLASTOISE", attacks = { "WATER" } },
    { lineId = "johto_grass", base = "CHIKORITA", mid = "BAYLEEF",
      final = "MEGANIUM", attacks = { "GRASS" } },
    { lineId = "johto_fire", base = "CYNDAQUIL", mid = "QUILAVA",
      final = "TYPHLOSION", attacks = { "FIRE" } },
    { lineId = "johto_water", base = "TOTODILE", mid = "CROCONAW",
      final = "FERALIGATR", attacks = { "WATER" } },
    { lineId = "hoenn_grass", base = "TREECKO", mid = "GROVYLE",
      final = "SCEPTILE", attacks = { "GRASS" } },
    { lineId = "hoenn_fire", base = "TORCHIC", mid = "COMBUSKEN",
      final = "BLAZIKEN", attacks = { "FIRE", "FIGHTING" } },
    { lineId = "hoenn_water", base = "MUDKIP", mid = "MARSHTOMP",
      final = "SWAMPERT", attacks = { "WATER", "GROUND" } },
    { lineId = "ampharos", base = "MAREEP", mid = "FLAAFFY",
      final = "AMPHAROS", attacks = { "ELECTRIC" } },
    { lineId = "machamp", base = "MACHOP", mid = "MACHOKE",
      final = "MACHAMP", attacks = { "FIGHTING" } },
    { lineId = "alakazam", base = "ABRA", mid = "KADABRA",
      final = "ALAKAZAM", attacks = { "PSYCHIC_TYPE" } },
    { lineId = "gengar", base = "GASTLY", mid = "HAUNTER",
      final = "GENGAR", attacks = { "GHOST", "POISON" } },
    -- Generation II has no third Swinub stage.  Reusing PILOSWINE at the
    -- final milestone preserves a legal two-stage family without inventing
    -- Mamoswine (and therefore without introducing Sinnoh).
    { lineId = "piloswine", base = "SWINUB", mid = "PILOSWINE",
      final = "PILOSWINE", attacks = { "ICE", "GROUND" } },
    { lineId = "dragonite", base = "DRATINI", mid = "DRAGONAIR",
      final = "DRAGONITE", attacks = { "DRAGON", "FLYING" } },
    { lineId = "tyranitar", base = "LARVITAR", mid = "PUPITAR",
      final = "TYRANITAR", attacks = { "ROCK", "DARK" } },
  }

  local BY_ID, FAMILY_OF = {}, {}
  for _, line in ipairs(LINES) do
    BY_ID[line.lineId] = line
    FAMILY_OF[line.base] = line.lineId
    FAMILY_OF[line.mid] = line.lineId
    FAMILY_OF[line.final] = line.lineId
  end

  -- Canonical starter triangles take precedence over the general type
  -- scorer.  Thus each authored left-ball choice has the expected rival
  -- counter, while arbitrary catalogue partners still receive a fair one.
  local DIRECT_COUNTER = {
    kanto_grass = "kanto_fire", kanto_fire = "kanto_water",
    kanto_water = "kanto_grass",
    johto_grass = "johto_fire", johto_fire = "johto_water",
    johto_water = "johto_grass",
    hoenn_grass = "hoenn_fire", hoenn_fire = "hoenn_water",
    hoenn_water = "hoenn_grass",
  }

  local FALLBACK_EFFECTIVE = {
    WATER = { FIRE = true, GROUND = true, ROCK = true },
    FIRE = { GRASS = true, ICE = true, BUG = true, STEEL = true },
    GRASS = { WATER = true, GROUND = true, ROCK = true },
    ELECTRIC = { WATER = true, FLYING = true },
    FIGHTING = {
      NORMAL = true, ICE = true, ROCK = true, DARK = true, STEEL = true,
    },
    PSYCHIC_TYPE = { FIGHTING = true, POISON = true },
    GHOST = { GHOST = true, PSYCHIC_TYPE = true },
    DARK = { GHOST = true, PSYCHIC_TYPE = true },
    ICE = { GRASS = true, GROUND = true, FLYING = true, DRAGON = true },
    GROUND = {
      FIRE = true, ELECTRIC = true, POISON = true,
      ROCK = true, STEEL = true,
    },
    ROCK = { FIRE = true, ICE = true, FLYING = true, BUG = true },
    DRAGON = { DRAGON = true },
    FLYING = { GRASS = true, FIGHTING = true, BUG = true },
    POISON = { GRASS = true, BUG = true },
  }

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function normalizedSpecies(value)
    value = tostring(value or ""):upper():gsub("[^A-Z0-9_]", "")
    return value ~= "" and value or nil
  end

  local function pokemonDef(species)
    local data = R.game and R.game.data
    if data and data.pokemon and data.pokemon[species] then
      return data.pokemon[species]
    end
    local registry = mod.content and mod.content.pokemon
    return registry and registry.get and registry:get(species) or nil
  end

  local function lineAvailable(line)
    return pokemonDef(line.base) and pokemonDef(line.mid)
      and pokemonDef(line.final)
  end

  local function stableHash(value)
    local hash = 17
    for index = 1, #value do
      hash = (hash * 33 + value:byte(index)) % 2147483647
    end
    return hash
  end

  local function chartMultiplier(attack, defenders)
    local data = R.game and R.game.data
    local rows = data and data.type_chart and data.type_chart.matchups
    local multiplier = 10
    if type(rows) == "table" then
      for _, defender in ipairs(defenders) do
        local found = 10
        for _, row in ipairs(rows) do
          if row.attacker == attack and row.defender == defender then
            found = tonumber(row.multiplier) or 10
            break
          end
        end
        multiplier = math.floor(multiplier * found / 10)
      end
      return multiplier
    end
    for _, defender in ipairs(defenders) do
      if FALLBACK_EFFECTIVE[attack]
          and FALLBACK_EFFECTIVE[attack][defender] then
        multiplier = multiplier * 2
      end
    end
    return multiplier
  end

  local function scoreLine(line, defenderTypes)
    local best = 10
    for _, attack in ipairs(line.attacks) do
      best = math.max(best, chartMultiplier(attack, defenderTypes))
    end
    return best
  end

  local function storedLine(line, source)
    return {
      version = 1,
      base = line.base,
      mid = line.mid,
      final = line.final,
      lineId = line.lineId,
      sourcePartner = source,
    }
  end

  local function catalogueAllows(species)
    local starters = mod.exports and mod.exports.legacyStarters
    local allowlist = type(starters) == "table"
      and starters.partnerAllowlist or nil
    return type(allowlist) == "table" and allowlist[species] == true
  end

  local function validStored(value, source)
    if type(value) ~= "table" or value.version ~= 1
        or normalizedSpecies(value.sourcePartner) ~= source then
      return false
    end
    local line = BY_ID[value.lineId]
    if not (line ~= nil and value.base == line.base and value.mid == line.mid
        and value.final == line.final) then
      return false
    end
    -- Older 6.5 candidates could store a Hoenn fallback for a free Oak
    -- catalogue choice. Reject that stale binding so resolveForJourney()
    -- deterministically migrates it back into the same legal 129-species
    -- pool. The earned Hoenn ball is outside this allowlist and therefore
    -- keeps its authored Hoenn triangle unchanged.
    return not catalogueAllows(source) or catalogueAllows(line.base)
  end

  function R.bindGame(game)
    R.game = game or R.game
    return R.game
  end

  function R.chooseForSpecies(species)
    species = normalizedSpecies(species)
    if not species then return nil, "missing partner species" end

    local sourceFamily = FAMILY_OF[species]
    local direct = sourceFamily and DIRECT_COUNTER[sourceFamily]
    if direct and lineAvailable(BY_ID[direct]) then
      return storedLine(BY_ID[direct], species)
    end

    local def = pokemonDef(species)
    local defenderTypes = type(def and def.types) == "table"
      and def.types or {}
    local catalogueSource = catalogueAllows(species)
    local best, candidates = -1, {}
    for _, line in ipairs(LINES) do
      if line.lineId ~= sourceFamily and lineAvailable(line)
          and (not catalogueSource or catalogueAllows(line.base)) then
        local score = scoreLine(line, defenderTypes)
        if score > best then
          best, candidates = score, { line }
        elseif score == best then
          candidates[#candidates + 1] = line
        end
      end
    end
    if #candidates == 0 then return nil, "no rival partner line available" end
    local index = (stableHash(species) % #candidates) + 1
    return storedLine(candidates[index], species)
  end

  -- Delayed and idempotent by contract. rightBallClaimed/rivalClaimed alone
  -- deliberately cannot populate rivalPartner.
  function R.resolveForJourney(journey)
    if type(journey) ~= "table" or journey.partnerChosen ~= true then
      return nil, "partner choice pending"
    end
    local source = normalizedSpecies(journey.partnerSpecies)
    if not source then return nil, "partner choice pending" end
    if journey.partnerMode == "yellow"
        and lineAvailable(BY_ID.yellow_eevee) then
      if validStored(journey.rivalPartner, source)
          and journey.rivalPartner.lineId == "yellow_eevee" then
        return journey.rivalPartner
      end
      journey.rivalPartner = storedLine(BY_ID.yellow_eevee, source)
      return journey.rivalPartner
    end
    if validStored(journey.rivalPartner, source) then
      return journey.rivalPartner
    end
    local selected, err = R.chooseForSpecies(source)
    if not selected then return nil, err end
    journey.rivalPartner = selected
    return selected
  end

  local function journeyFromSave(save)
    local bucket = type(save and save.modData) == "table"
      and save.modData[mod.id]
    return type(bucket) == "table" and bucket.legacy_journey or nil
  end

  local function currentJourney()
    local fromGame = journeyFromSave(R.game and R.game.save)
    if fromGame then return fromGame end
    return mod.save and mod.save.get
      and mod.save:get("legacy_journey") or nil
  end

  function R.ensureForSave(save)
    return R.resolveForJourney(journeyFromSave(save))
  end

  function R.current()
    return R.resolveForJourney(currentJourney())
  end

  local function rbStage(oppClass, partyIndex)
    partyIndex = math.max(1, math.floor(tonumber(partyIndex) or 1))
    if oppClass == "OPP_RIVAL1" then return "base" end
    if oppClass == "OPP_RIVAL2" then
      return partyIndex <= 6 and "mid" or "final"
    end
    return "final"
  end

  local YELLOW_PARTNER = {
    EEVEE = true, JOLTEON = true, FLAREON = true, VAPOREON = true,
  }

  local function yellowSlot(party)
    for index, row in ipairs(party or {}) do
      if YELLOW_PARTNER[row.species] then return index, row.species end
    end
    return #party > 0 and #party or nil, nil
  end

  -- Pure replacement API used by focused tests and by the live hook.  It
  -- clones the roster, retains every non-partner row and its level, and drops
  -- a previous species' authored move override from the replaced slot.
  function R.replaceParty(oppClass, partyIndex, party, rivalPartner, yellow,
      stageOverride)
    if not RIVAL_CLASSES[oppClass] or type(party) ~= "table"
        or type(rivalPartner) ~= "table" then
      return party
    end
    local out = copy(party)
    local slot, stage
    if yellow then
      local oldSpecies
      slot, oldSpecies = yellowSlot(out)
      stage = stageOverride or (oldSpecies == "EEVEE" and "base" or "final")
    else
      slot, stage = #out, rbStage(oppClass, partyIndex)
    end
    if not slot or not rivalPartner[stage] then return party end
    out[slot].species = rivalPartner[stage]
    out[slot].moves = nil
    return out
  end

  local function canonicalYellowParty(oppClass, partyIndex, fallback)
    local trainers = R.game and R.game.data and R.game.data.trainers
    local trainer = trainers and trainers[oppClass]
    local party = trainer and trainer.parties and trainer.parties[partyIndex]
    return type(party) == "table" and party or fallback
  end

  local function yellowMilestone(oppClass, partyIndex, fallback)
    local canonical = canonicalYellowParty(oppClass, partyIndex, fallback)
    local _, species = yellowSlot(canonical)
    return species == "EEVEE" and "base" or "final"
  end

  -- In an extended-character Yellow run the older identity roster hook is
  -- authored for Red/Blue's party indices. Restore Yellow's registered team
  -- after that hook but before the trainer randomizer. The randomizer may
  -- still change every ordinary slot; the outer pin below then restores only
  -- the binding rival partner.
  mod.hooks:wrap("trainer.party",
    function(nextParty, oppClass, partyIndex, party)
      if not RIVAL_CLASSES[oppClass] then
        return nextParty(oppClass, partyIndex, party)
      end
      local rivalPartner = R.current()
      local yellow = GameVersion.isYellow and GameVersion.isYellow() == true
      if not rivalPartner or not yellow then
        return nextParty(oppClass, partyIndex, party)
      end
      return nextParty(oppClass, partyIndex,
        canonicalYellowParty(oppClass, partyIndex, party))
    end, 80)

  -- Outermost post-processing is intentional: run_rules' trainer randomizer
  -- sits at priority 70 and may randomize the whole roster. Ordinary slots
  -- keep that rule, while this one story-bound partner slot always survives.
  mod.hooks:wrap("trainer.party",
    function(nextParty, oppClass, partyIndex, party)
      local resolved = nextParty(oppClass, partyIndex, party)
      if not RIVAL_CLASSES[oppClass] then return resolved end
      local rivalPartner = R.current()
      if not rivalPartner then return resolved end
      local yellow = GameVersion.isYellow and GameVersion.isYellow() == true
      local stage = yellow
        and yellowMilestone(oppClass, partyIndex, party) or nil
      return R.replaceParty(
        oppClass, partyIndex, resolved, rivalPartner, yellow, stage)
    end, 1000)

  local function rememberGame(ev)
    R.bindGame(ev and ev.game)
    local journey = journeyFromSave(ev and (ev.save or ev.game and ev.game.save))
    if journey then R.resolveForJourney(journey) end
  end
  mod.events:on("game.ready", rememberGame, 70)
  mod.events:on("save.loaded", rememberGame, 70)

  R.lines = LINES
  R.directCounters = DIRECT_COUNTER
  return R
end
