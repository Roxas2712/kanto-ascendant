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
    local research = exports.johtoResearch
    local signals = exports.johtoSignals
    local habitat = research and research.habitatFor
      and research.habitatFor(species) or nil
    if type(habitat) ~= "table" or type(habitat.map) ~= "string"
        or type(habitat.terrain) ~= "string"
        or not (signals and signals.allowsHabitatSpecies) then
      return {}
    end
    local active = signals.allowsHabitatSpecies(species, {
      mapId = habitat.map,
      terrain = habitat.terrain,
    })
    return active and { habitat } or {}
  end
end
