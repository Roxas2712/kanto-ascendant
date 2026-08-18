-- Yellow's extracted Mt. Moon B2F trainer-header table omits object 1, the
-- Super Nerd guarding the fossils. Engine 0.1.96/0.1.98 therefore falls back
-- to its generic Youngster/shorts line and also loses the victory, after-talk
-- and event keys. Restore only that exact missing Yellow data row; Red/Blue
-- already contain it and every changed/foreign map shape fails closed.

return function(opts)
  opts = opts or {}
  local gameVersion = opts.gameVersion
  local M = {}

  local HEADER = {
    after = "_MtMoonB2FSuperNerdTheresAPokemonLabText",
    battle = "_MtMoonB2FSuperNerdTheyreBothMineText",
    event = "EVENT_BEAT_MT_MOON_3_SUPER_NERD",
    won = "_MtMoonB2fSuperNerdEachTakeOneText",
  }

  local function edition()
    if gameVersion and type(gameVersion.get) == "function" then
      return gameVersion.get()
    end
    return nil
  end

  local function objectAt(map, index)
    for _, object in ipairs(map and map.objects or {}) do
      if object.index == index then return object end
    end
    return nil
  end

  local function exactYellowShape(data)
    local map = data.maps and data.maps.MT_MOON_B2F
    if not map or map.label ~= "MtMoonB2F" then return nil end
    local nerd = objectAt(map, 1)
    local jessie = objectAt(map, 2)
    local james = objectAt(map, 6)
    local dome = objectAt(map, 7)
    local helix = objectAt(map, 8)
    if not nerd or nerd.name ~= "MTMOONB2F_SUPER_NERD"
        or nerd.text ~= "TEXT_MTMOONB2F_SUPER_NERD"
        or nerd.trainerClass ~= "OPP_SUPER_NERD"
        or nerd.trainerParty ~= 2 or nerd.x ~= 12 or nerd.y ~= 8
        or not jessie or jessie.name ~= "MTMOONB2F_JESSIE"
        or not james or james.name ~= "MTMOONB2F_JAMES"
        or not dome or dome.name ~= "MTMOONB2F_DOME_FOSSIL"
        or dome.x ~= 12 or dome.y ~= 6
        or not helix or helix.name ~= "MTMOONB2F_HELIX_FOSSIL"
        or helix.x ~= 13 or helix.y ~= 6 then
      return nil
    end
    return map
  end

  function M.install(game)
    if edition() ~= "yellow" then return false, "edition" end
    local data = game and game.data
    if type(data) ~= "table" or not exactYellowShape(data) then
      return false, "shape"
    end
    local headers = data.trainer_headers
      and data.trainer_headers.MtMoonB2F
    if type(headers) ~= "table" then return false, "shape" end
    -- A newer engine or another authoritative content layer already repaired
    -- the row. Never overwrite it, even if its implementation differs.
    if headers[1] ~= nil then return false, "present" end
    for _, key in ipairs({ HEADER.after, HEADER.battle, HEADER.won }) do
      if type(data.text) ~= "table" or type(data.text[key]) ~= "string" then
        return false, "text"
      end
    end
    headers[1] = {
      after = HEADER.after,
      battle = HEADER.battle,
      event = HEADER.event,
      won = HEADER.won,
    }
    return true, "repaired"
  end

  M.header = HEADER
  return M
end
