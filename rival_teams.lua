-- Identity-specific rival progressions for the extended character matrix.
--
-- Blue deliberately keeps every original Gen-I roster.  Green grows a team
-- around her established manga/game identity while retaining the starter
-- counter chosen by Oak's Lab.  Red gradually assembles the party used for
-- the Mt. Silver battle in Pokemon Gold/Crystal; his Champion roster is the
-- canonical Crystal team, including its authored moves.

return function(mod, characters)
  local R = {}
  local RIVAL_CLASSES = {
    OPP_RIVAL1 = true, OPP_RIVAL2 = true, OPP_RIVAL3 = true,
  }

  local STARTERS = {
    [1] = { base = "SQUIRTLE", mid = "WARTORTLE", final = "BLASTOISE" },
    [2] = { base = "BULBASAUR", mid = "IVYSAUR", final = "VENUSAUR" },
    [3] = { base = "CHARMANDER", mid = "CHARMELEON", final = "CHARIZARD" },
  }

  local function mon(species, level, moves)
    local out = { species = species, level = level }
    if moves then out.moves = moves end
    return out
  end

  local function branchFor(partyIndex)
    return ((math.max(1, tonumber(partyIndex) or 1) - 1) % 3) + 1
  end

  -- Red/Blue store each story step as a block of three starter branches.
  -- Yellow instead stores one fixed S.S. Anne party followed by three
  -- Eevee-outcome variants for each later RIVAL2 encounter. Treating those
  -- indices as Red/Blue branches changes the starter and holds later fights
  -- at the previous story tier.
  local function progressionFor(oppClass, partyIndex, isYellow)
    local index = math.max(1, tonumber(partyIndex) or 1)
    if not isYellow then
      return branchFor(index), math.floor((index - 1) / 3) + 1
    end
    if oppClass == "OPP_RIVAL1" then return 1, index end
    if oppClass == "OPP_RIVAL2" then
      local stage = index == 1 and 1 or math.floor((index - 2) / 3) + 2
      return 1, stage
    end
    return 1, 1
  end

  local function starter(branch, form, level)
    return mon(STARTERS[branch][form], level)
  end

  local function otherFinalStarters(branch, level)
    local out = {}
    for index = 1, 3 do
      if index ~= branch then out[#out + 1] = starter(index, "final", level) end
    end
    return out
  end

  local RED_FINAL = {
    mon("PIKACHU", 81, { "CHARM", "QUICK_ATTACK", "THUNDERBOLT", "THUNDER" }),
    mon("ESPEON", 73, { "MUD_SLAP", "REFLECT", "SWIFT", "PSYCHIC_M" }),
    mon("SNORLAX", 75, { "AMNESIA", "SNORE", "REST", "BODY_SLAM" }),
    mon("VENUSAUR", 77, { "SUNNY_DAY", "GIGA_DRAIN", "SYNTHESIS", "SOLARBEAM" }),
    mon("CHARIZARD", 77, { "FLAMETHROWER", "WING_ATTACK", "SLASH", "FIRE_SPIN" }),
    mon("BLASTOISE", 77, { "RAIN_DANCE", "SURF", "BLIZZARD", "WHIRLPOOL" }),
  }

  local function redTeam(oppClass, partyIndex, original, isYellow)
    local branch, stage = progressionFor(oppClass, partyIndex, isYellow)
    if oppClass == "OPP_RIVAL1" then
      if stage == 1 then return original end
      if stage == 2 then
        return { mon("PIKACHU", 9), starter(branch, "base", 8) }
      end
      return {
        mon("PIKACHU", 18), mon("EEVEE", 15), mon("RATTATA", 15),
        starter(branch, "mid", 17),
      }
    elseif oppClass == "OPP_RIVAL2" then
      if stage == 1 then
        return {
          mon("PIKACHU", 19), mon("RATICATE", 16), mon("EEVEE", 18),
          starter(branch, "mid", 20),
        }
      elseif stage == 2 then
        return {
          mon("PIKACHU", 25), mon("EEVEE", 23), mon("SNORLAX", 22),
          starter(branch, "mid", 25),
        }
      elseif stage == 3 then
        return {
          mon("PIKACHU", 37), mon("ESPEON", 35), mon("SNORLAX", 38),
          starter(branch, "final", 40),
        }
      end
      local team = {
        mon("PIKACHU", 47), mon("ESPEON", 45), mon("SNORLAX", 47),
      }
      for _, row in ipairs(otherFinalStarters(branch, 45)) do
        team[#team + 1] = row
      end
      team[#team + 1] = starter(branch, "final", 53)
      return team
    end
    return RED_FINAL
  end

  local function greenTeam(oppClass, partyIndex, original, isYellow)
    local branch, stage = progressionFor(oppClass, partyIndex, isYellow)
    if oppClass == "OPP_RIVAL1" then
      if stage == 1 then return original end
      if stage == 2 then
        return { mon("JIGGLYPUFF", 9), starter(branch, "base", 8) }
      end
      return {
        mon("JIGGLYPUFF", 18), mon("CLEFAIRY", 15),
        mon("NIDORAN_F", 15), starter(branch, "mid", 17),
      }
    elseif oppClass == "OPP_RIVAL2" then
      if stage == 1 then
        return {
          mon("JIGGLYPUFF", 19), mon("NIDORINA", 16),
          mon("CLEFAIRY", 18), starter(branch, "mid", 20),
        }
      elseif stage == 2 then
        return {
          mon("WIGGLYTUFF", 25), mon("NIDORINA", 23),
          mon("CLEFAIRY", 22), mon("DITTO", 20),
          starter(branch, "mid", 25),
        }
      elseif stage == 3 then
        return {
          mon("WIGGLYTUFF", 37), mon("NIDOQUEEN", 38),
          mon("CLEFABLE", 35), mon("DITTO", 35),
          starter(branch, "final", 40),
        }
      end
      return {
        mon("WIGGLYTUFF", 47), mon("NIDOQUEEN", 45),
        mon("CLEFABLE", 45), mon("GRANBULL", 47), mon("DITTO", 50),
        starter(branch, "final", 53),
      }
    end
    return {
      mon("WIGGLYTUFF", 61), mon("NIDOQUEEN", 59),
      mon("CLEFABLE", 61), mon("GRANBULL", 61), mon("DITTO", 63),
      starter(branch, "final", 65),
    }
  end

  function R.resolve(rival, oppClass, partyIndex, original, isYellow)
    if not RIVAL_CLASSES[oppClass] then return original end
    rival = tostring(rival or "BLUE"):upper()
    if rival == "RED" then
      return redTeam(oppClass, partyIndex, original, isYellow)
    end
    if rival == "GREEN" then
      return greenTeam(oppClass, partyIndex, original, isYellow)
    end
    return original
  end

  function R.team(oppClass, partyIndex, original)
    local state = characters and characters.getState and characters.getState()
    if not (state and state.enabled) then return original end
    local isYellow = require("src.core.GameVersion").isYellow()
    return R.resolve(state.rival_character, oppClass, partyIndex, original,
      isYellow)
  end

  function R.restoreTowerMusic(ev)
    local battle = ev and ev.battle
    if not battle or ev.result ~= "win"
        or battle.oppClass ~= "OPP_RIVAL2" then return false end
    local game = battle.game
    local overworld = game and game.overworld
    local mapId = overworld and overworld.map and overworld.map.id
      or (game and game.save and game.save.player and game.save.player.map)
    if mapId ~= "POKEMON_TOWER_2F" then return false end
    local player = overworld and overworld.player
    require("src.core.Music").playMap(game.data, mapId,
      game.save and game.save.onBike, player and player.surfing)
    return true
  end

  R.redFinal = RED_FINAL
  R.starters = STARTERS

  mod.hooks:wrap("trainer.party",
    function(nextParty, oppClass, partyIndex, party)
      if RIVAL_CLASSES[oppClass] and characters
          and characters.refreshVisuals then
        characters.refreshVisuals()
      end
      return nextParty(oppClass, partyIndex,
        R.team(oppClass, partyIndex, party))
    end, 90)

  mod.events:on("battle.ended", R.restoreTowerMusic)

  return R
end
