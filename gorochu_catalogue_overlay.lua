-- Current Gorochu artwork for the fixed 56x56 Pokédex/status slot.
--
-- The catalogue owner supplies the same 56px Crystal-primary frame to the
-- native screen and the final HUD pass. Keeping both paths on one authority
-- prevents the legacy 96px illustration and v1.5's 64px scene frame from
-- becoming simultaneous layers in SummaryMenu or DexEntryMenu.

return function(mod, opts)
  opts = opts or {}
  local species = opts.species or "GOROCHU"
  local shinySystem = opts.shinySystem
  local visuals = opts.visuals or mod.exports and mod.exports.gorochuVisuals
  local images = {}
  local registered = false
  local O = {}

  local function isShiny(mon)
    if shinySystem and shinySystem.isShiny then
      return shinySystem.isShiny(mon)
    end
    return mon and mon.shiny == true or false
  end

  local function wantsVoxel(kind)
    return (kind == "dex" or kind == "summary")
      and mod.options:get("dex_sprite_style") ~= "crystal"
  end

  local function sourceFor(mon)
    if not (visuals and type(visuals.cataloguePath) == "function") then
      return nil
    end
    local ok, relative = pcall(visuals.cataloguePath, mon)
    return ok and relative or nil
  end

  function O.cataloguePath(ctx)
    if not (ctx and ctx.species == species and wantsVoxel(ctx.kind)) then
      return nil
    end
    local relative = sourceFor(ctx.mon)
    return relative and mod:read(relative) and relative or nil
  end
  -- Retain the former exported name for third-party callers; it now resolves
  -- visible current art rather than a transparent placeholder.
  O.placeholderPath = O.cataloguePath

  local function stateInfo(game)
    local state = game and game.stack and game.stack.top
      and game.stack:top() or nil
    if not state then return nil end
    if state.screenId == "DexEntryMenu"
        and state.def and state.def.id == species
        and wantsVoxel("dex") then
      return "dex", nil
    end
    if state.screenId == "SummaryMenu"
        and state.mon and state.mon.species == species
        and wantsVoxel("summary") then
      return "summary", state.mon
    end
    return nil
  end

  local function imageFor(mon)
    local variant = isShiny(mon) and "shiny" or "normal"
    if images[variant] ~= nil then return images[variant] or nil end
    local relative = sourceFor(mon)
    if not (relative and mod:read(relative) and love and love.graphics
        and love.graphics.newImage) then
      images[variant] = false
      return nil
    end
    local ok, image = pcall(love.graphics.newImage,
      mod.path .. "/" .. relative)
    if not (ok and image) then
      images[variant] = false
      return nil
    end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    images[variant] = image
    return image
  end

  function O.draw(game, viewport)
    local kind, mon = stateInfo(game)
    if not kind or type(viewport) ~= "table" then return false end
    local image = imageFor(mon)
    if not (image and image.getDimensions and love.graphics.draw) then
      return false
    end
    local width, height = image:getDimensions()
    if not (width and height and width > 0 and height > 0) then return false end

    local gameX, gameY = viewport.gameX or 0, viewport.gameY or 0
    local scaleX = (viewport.gameWidth or 160) / 160
    local scaleY = (viewport.gameHeight or 144) / 144
    local slot = 56
    local x, y = 8, kind == "dex" and 4 or 0
    local drawScaleX = slot * scaleX / width
    local drawScaleY = slot * scaleY / height

    love.graphics.setColor(1, 1, 1, 1)
    if kind == "summary" then
      -- The Gen-I status screen intentionally mirrors the front sprite.
      love.graphics.draw(image,
        gameX + (x + slot) * scaleX,
        gameY + y * scaleY,
        0, -drawScaleX, drawScaleY)
    else
      love.graphics.draw(image,
        gameX + x * scaleX,
        gameY + y * scaleY,
        0, drawScaleX, drawScaleY)
    end
    love.graphics.setColor(1, 1, 1, 1)
    return true
  end

  function O.register()
    if registered then return true end
    mod.hooks:wrap("render.hud", function(nextDraw, game, viewport)
      nextDraw(game, viewport)
      O.draw(game, viewport)
    end, 900)
    registered = true
    return true
  end

  function O.invalidate()
    images = {}
  end

  O.sourceFor = sourceFor
  return O
end
