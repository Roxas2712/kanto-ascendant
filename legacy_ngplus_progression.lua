-- C14: Yellow's Oak script assumes that owning two species also means the
-- Pokédex has already been received.  A Legacy Journey may legitimately
-- withdraw a second species before Oak's parcel hand-off, invalidating that
-- vanilla-only invariant and sending every later Oak interaction directly to
-- the Pokédex rating branch.
--
-- Keep the compatibility fix at the story-command boundary.  Legacy Bank
-- transactions, Pokédex ownership and the engine-authored Yellow script stay
-- untouched, so an already affected save can continue without losing data.

return function(mod, opts)
  opts = opts or {}
  local journey = assert(opts.journey,
    "Legacy NG+ progression requires the Legacy Journey owner")
  local gameVersion = opts.gameVersion
    or require("src.core.GameVersion")
  local C = {
    id = "C14-LEGACY-NGPLUS-PROGRESSION",
    owner = "kasc.legacy-ngplus-progression",
  }

  local function currentMap(ctx)
    local overworld = type(ctx) == "table" and ctx.overworld or nil
    local map = type(overworld) == "table" and overworld.map or nil
    if type(map) == "table" and type(map.id) == "string" then
      return map.id
    end
    if type(ctx) == "table" and type(ctx.mapId) == "string" then
      return ctx.mapId
    end
    local source = type(ctx) == "table" and ctx.source or nil
    if type(source) == "table" and type(source.mapId) == "string" then
      return source.mapId
    end
    local save = type(ctx) == "table" and ctx.save or nil
    local player = type(save) == "table" and save.player or nil
    return type(player) == "table" and player.map or nil
  end

  local function yellowEdition()
    if type(gameVersion) ~= "table" then return false end
    if type(gameVersion.isYellow) == "function" then
      local ok, value = pcall(gameVersion.isYellow)
      return ok and value == true
    end
    if type(gameVersion.get) == "function" then
      local ok, value = pcall(gameVersion.get)
      return ok and value == "yellow"
    end
    return false
  end

  local function activeLegacy(save)
    if type(save) ~= "table" or type(journey.isActive) ~= "function" then
      return false
    end
    local ok, value = pcall(journey.isActive, save)
    return ok and value == true
  end

  -- The exact Yellow row is `check_dex_owned 2`, immediately followed by a
  -- jump to `dex_rating`.  Red/Blue already add EVENT_GOT_POKEDEX as a second
  -- guard.  Returning false here gives Yellow the same semantic guard only for
  -- an active Legacy save in Oak's Lab before that durable story flag exists.
  function C.guardsEarlyDexRating(ctx, name, args)
    if name ~= "check_dex_owned" or type(args) ~= "table"
        or tonumber(args[1]) ~= 2 or currentMap(ctx) ~= "OAKS_LAB"
        or not yellowEdition() then return false end
    local save = type(ctx) == "table" and ctx.save or nil
    if type(save) ~= "table"
        or (type(save.flags) == "table"
          and save.flags.EVENT_GOT_POKEDEX == true) then return false end
    return activeLegacy(save)
  end

  function C.dispatch(nextCommand, ctx, name, args)
    if C.guardsEarlyDexRating(ctx, name, args) then
      -- Do not call the engine command: it would restore the invalid
      -- owned-count result. The following jump_if_true now falls through to
      -- the ordinary parcel/Pokédex checks.
      ctx.lastCheck = false
      return nil
    end
    return nextCommand(ctx, name, args)
  end

  assert(mod and mod.hooks and type(mod.hooks.wrap) == "function",
    "Legacy NG+ progression requires the script.command hook")
  mod.hooks:wrap("script.command", function(nextCommand, ctx, name, args)
    return C.dispatch(nextCommand, ctx, name, args)
  end, 120)

  return C
end
