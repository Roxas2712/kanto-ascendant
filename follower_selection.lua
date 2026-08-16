-- Edition-aware selection policy for Ascendant's native follower chain.
--
-- PARTY and CUSTOM both resolve into the same small row format, so movement
-- and rendering never need edition- or menu-specific branches. Yellow's exact
-- marked partner remains the first row and is deduplicated from either mode.

return function(opts)
  opts = opts or {}
  local gameVersion = opts.gameVersion
  local yellowPartner = opts.yellowPartner
  local legacyStarters = opts.legacyStarters
  local config = opts.config
  local S = {}
  local ids = setmetatable({}, { __mode = "k" })
  local nextId = 0

  local function edition()
    local gv = gameVersion
    if not gv then
      local ok
      ok, gv = pcall(require, "src.core.GameVersion")
      if not ok then return nil end
    end
    return gv and gv.get and gv.get() or nil
  end

  function S.healthy(mon)
    return type(mon) == "table" and not mon.isEgg
      and type(mon.species) == "string" and mon.species ~= ""
      and (tonumber(mon.hp) or 0) > 0
  end

  local function inParty(game, wanted)
    for index, mon in ipairs(game and game.save and game.save.party or {}) do
      if mon == wanted then return mon, index end
    end
    return nil
  end

  local function yellowSelection(game)
    local partner = yellowPartner and yellowPartner.partner
      and yellowPartner.partner(game) or nil
    local mon, index = inParty(game, partner)
    if S.healthy(mon) then return mon, index, "yellow_partner" end

    -- Legacy Yellow may deliberately choose Hoenn or Oak's catalogue instead
    -- of the Pikachu-special route. That durable Journey partner uses the
    -- ordinary follower conversation, but must still be the one that follows.
    local legacy = legacyStarters and legacyStarters.partner
      and legacyStarters.partner(game) or nil
    mon, index = inParty(game, legacy)
    if S.healthy(mon) then return mon, index, "yellow_legacy_partner" end

    -- A fresh Yellow save can briefly reach the overworld between Oak's gift
    -- and the marker migration.  Only Pikachu may bridge that tiny window;
    -- using party slot 1 here would rewrite Yellow's partner story.
    local flags = game and game.save and game.save.flags or {}
    if flags.EVENT_GOT_STARTER then
      for i, candidate in ipairs(game.save.party or {}) do
        if candidate.species == "PIKACHU" and S.healthy(candidate) then
          return candidate, i, "yellow_pikachu_fallback"
        end
      end
    end
    return nil
  end

  local function clampedCount(count)
    return math.max(1, math.min(4, math.floor(tonumber(count) or 1)))
  end

  function S.activeMany(game, count)
    count = clampedCount(count)
    local version = edition()
    local rows, seen = {}, {}
    if version == "yellow" then
      local mon, slot, source = yellowSelection(game)
      -- Preserve Yellow semantics: an unavailable special/Journey partner
      -- does not silently promote an unrelated party member into its place.
      if not mon then return rows end
      rows[1] = { mon = mon, slot = slot, source = source }
      seen[mon] = true
    elseif version ~= "red" and version ~= "blue" then
      return rows
    end

    local candidates = {}
    if config and config.mode and config.mode() == "custom"
        and config.customPartyRows then
      candidates = config.customPartyRows(game)
    else
      for index, mon in ipairs(game and game.save and game.save.party or {}) do
        candidates[#candidates + 1] = { mon = mon, slot = index }
      end
    end

    for _, candidate in ipairs(candidates) do
      if #rows >= count then break end
      local mon, index = candidate.mon, candidate.slot
      if S.healthy(mon) and not seen[mon] then
        rows[#rows + 1] = {
          mon = mon, slot = index,
          source = config and config.mode and config.mode() == "custom"
              and (version == "yellow" and "yellow_custom" or "custom")
            or version == "yellow" and "yellow_party"
            or (#rows == 0 and "party_first_healthy" or "party"),
        }
        seen[mon] = true
      end
    end
    return rows
  end

  function S.active(game)
    local row = S.activeMany(game, 1)[1]
    if row then return row.mon, row.slot, row.source end
    return nil
  end

  function S.identity(mon)
    if type(mon) ~= "table" then return nil end
    if config and config.identity then
      local persistent = config.identity(mon, false)
      if persistent then return persistent end
    end
    if not ids[mon] then
      nextId = nextId + 1
      ids[mon] = nextId
    end
    local dvs = type(mon.dvs) == "table" and mon.dvs or {}
    return table.concat({
      tostring(ids[mon]), tostring(mon.otId or -1),
      tostring(dvs.attack or -1), tostring(dvs.defense or -1),
      tostring(dvs.speed or -1), tostring(dvs.special or -1),
    }, ":")
  end

  function S.edition() return edition() end
  return S
end
