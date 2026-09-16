-- Read-only bridge between Johto's runtime replacement encounters and the
-- stock Pokédex AREA screen. It deliberately exposes only the exact authored
-- habitat of an already-seen species while that habitat is active for this
-- save's migration current.

return function(mod)
  return function(game, species)
    -- The ordinary side menu is reachable only for a seen species, but keep
    -- this provider spoiler-safe for direct or third-party screen callers.
    local dex = game and game.save and game.save.pokedex or {}
    local seen = type(dex.seen) == "table" and dex.seen or {}
    local owned = type(dex.owned) == "table" and dex.owned or {}
    if seen[species] ~= true and owned[species] ~= true then return {} end

    local exports = mod.exports or {}
    local rows, seenMaps = {}, {}
    local research, signals = exports.johtoResearch, exports.johtoSignals
    local habitat = research and research.habitatFor
      and research.habitatFor(species) or nil
    if type(habitat) == "table" and type(habitat.map) == "string"
        and type(habitat.terrain) == "string"
        and signals and signals.allowsHabitatSpecies then
      local active = signals.allowsHabitatSpecies(species, {
        mapId = habitat.map, terrain = habitat.terrain,
      })
      if active then
        rows[#rows + 1], seenMaps[habitat.map] = habitat, true
      end
    end

    local access = exports.hoennFieldAccess
    local core = exports.discoveryCore
    local hoenn = core and core.Hoenn
    local hasDex = access and type(access.hasDex) == "function"
      and access.hasDex(game) == true
    if hasDex and hoenn and type(hoenn.familyForSpecies) == "function"
        and type(hoenn.primaryHabitat) == "function" then
      local family, class = hoenn.familyForSpecies(species)
      local allowed = family ~= nil
      if allowed and class == "starter" then
        allowed = type(access.starterUnlocked) == "function"
          and access.starterUnlocked(game, family) == true
      end
      local legacy = access and type(access.isLegacy) == "function"
        and access.isLegacy(game) == true
      if allowed and class == "ordinary" and not legacy
          and type(access.ordinaryAllowed) == "function" then
        allowed = access.ordinaryAllowed(game, family) == true
      end
      local row
      if allowed and legacy and class == "ordinary"
          and type(hoenn.traceMap) == "function"
          and core.state and type(core.state.root) == "function" then
        local traceMap = hoenn.traceMap(core.state.root(false), family)
        if traceMap then
          local authored = hoenn.primaryHabitat(family) or {}
          row = { map = traceMap, terrain = authored.terrain or "grass",
            level = authored.level }
        end
      elseif allowed then
        row = hoenn.primaryHabitat(family)
      end
      if type(row) == "table" and type(row.map) == "string"
          and type(row.terrain) == "string" and not seenMaps[row.map] then
        rows[#rows + 1] = {
          map = row.map, terrain = row.terrain, level = tonumber(row.level),
          source = legacy and "hoenn_legacy_trace_67"
            or "hoenn_field_access_67",
          chance = class == "starter" and 0.5 or legacy and 1.5 or 1,
        }
      end
    end
    return rows
  end
end
