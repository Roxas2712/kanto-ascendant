-- Engine 0.1.96's Pokédex AREA screen walks every value stored directly on
-- an encounter definition as if it were a grass/water group with `.slots`.
-- Ascendant's authored trial maps also carry scalar runtime metadata on that
-- table (kaProtected, kaEncounterSource, hevoCharacter, kaMaxVisible), so the
-- stock reader raises before it can display even an ordinary Kanto nest.
--
-- Keep the canonical encounter registry untouched.  Only while the AREA
-- constructor performs its read-only scan, lend it a shallow projection that
-- contains valid slot groups and valid slot rows.  The original registry is
-- restored on both success and error, and every non-AREA Town Map path remains
-- byte-for-byte under the engine's own constructor.

local function copySlotGroups(encounters)
  if type(encounters) ~= "table" then return encounters end

  local projected = {}
  for mapId, encounter in pairs(encounters) do
    local groups = {}
    if type(encounter) == "table" then
      for kind, group in pairs(encounter) do
        if type(group) == "table" and type(group.slots) == "table" then
          local groupCopy = {}
          for key, value in pairs(group) do
            if key ~= "slots" then groupCopy[key] = value end
          end
          groupCopy.slots = {}
          for _, slot in ipairs(group.slots) do
            if type(slot) == "table" then
              groupCopy.slots[#groupCopy.slots + 1] = slot
            end
          end
          groups[kind] = groupCopy
        end
      end
    end
    projected[mapId] = groups
  end
  return projected
end

local function pack(...)
  return { n = select("#", ...), ... }
end

return function(deps)
  deps = deps or {}
  local TownMap = deps.townMap or require("src.ui.TownMap")
  if type(TownMap) ~= "table" or type(TownMap.new) ~= "function" then
    return false, "TownMap unavailable"
  end
  if TownMap.__ascendantSafeAreaReader then
    return true, "already installed"
  end

  local baseNew = TownMap.new
  TownMap.new = function(game, opts)
    if type(opts) ~= "table" or not opts.nestSpecies
        or type(game) ~= "table" or type(game.data) ~= "table" then
      return baseNew(game, opts)
    end

    local original = game.data.encounters
    game.data.encounters = copySlotGroups(original)
    local result = pack(pcall(baseNew, game, opts))
    game.data.encounters = original
    if not result[1] then error(result[2], 0) end
    return unpack(result, 2, result.n)
  end

  TownMap.__ascendantSafeAreaReader = true
  TownMap.__ascendantAreaBaseNew = baseNew
  return true
end
