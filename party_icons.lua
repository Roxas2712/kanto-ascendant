-- Species-authentic animated party icons for #001-279 and Gorochu.
--
-- PartyMenu decides whether art is mirrored / palette-baked from the type of
-- icons.bySpecies entry.  A pokemon.icon hook alone can only change the path
-- after that decision and therefore still mangles a follower sheet as a
-- native MON/QUADRUPED class.  Registering an {image=...} entry at load time
-- makes the renderer treat the sheet as authored full-width art; the live
-- hook then selects normal vs shiny for the individual Pokémon.

return function(mod, opts)
  opts = opts or {}
  local sprites = assert(opts.sprites, "follower sprite registry required")
  local kanto = assert(opts.kanto, "Kanto species order required")
  local johto = assert(opts.johto, "Johto species order required")
  local extendedRuntime = opts.extendedRuntime
  -- RC builds briefly exposed the same setting under the values
  -- `species/classic`, while the actual renderer has always used
  -- `animated/original`.  Normalize both spellings here so an upgraded save
  -- cannot silently skip every species registration during boot.
  local function normalizeStyle(value)
    if value == "original" or value == "classic" then return "original" end
    return "animated"
  end
  local P = {
    loadedStyle = normalizeStyle(mod.options:get("party_icon_style")),
    registered = 0,
  }

  local function override(species, relative)
    mod.content.icons:override(species, {
      image = mod.path .. "/" .. relative,
      frames = 6,
    })
    P.registered = P.registered + 1
  end

  if P.loadedStyle == "animated" then
    for dex, species in ipairs(kanto) do
      override(species,
        ("assets/followers_kanto/follower_%03d.png"):format(dex))
    end
    for _, species in ipairs(johto) do
      local relative = extendedRuntime
        and extendedRuntime.followerRelative(species, false)
        or ("assets/followers_runtime/normal/follower_%s.png"):format(species)
      override(species, relative)
    end
    override("GOROCHU",
      "assets/followers_runtime/normal/follower_GOROCHU.png")
  end

  mod.hooks:wrap("pokemon.icon", function(nextIcon, path, ctx)
    path = nextIcon(path, ctx)
    if P.loadedStyle ~= "animated" or not (ctx and ctx.mon) then return path end
    -- The registry entry above already selected the authored-art renderer.
    -- Only replace its file here so a shiny uses its own exact sheet.
    return sprites.resolve({ data = ctx.data }, ctx.mon) or path
  end, 800)

  -- PartyMenu's original icon column is deliberately SGB-tinted because the
  -- Game Boy icons are 2bpp objects.  Our authored RGBA sheets need a true-
  -- colour zone or Bulbasaur's teal body is flattened into a black Gen-I
  -- silhouette even though the correct file was selected.
  local PartyMenu = require("src.ui.PartyMenu")
  if not PartyMenu._kantoAscendantIconPaletteWrapped then
    local originalPalettes = PartyMenu.sgbPalettes
    PartyMenu.sgbPalettes = function(menu, game)
      local zones = originalPalettes(menu, game) or {}
      local policy = PartyMenu._kantoAscendantIconPalettePolicy
      if policy and policy.animated then
        local PaletteFX = require("src.render.PaletteFX")
        zones[#zones + 1] = PaletteFX.trueColorZone(1, 0, 2, 11)
      end
      return zones
    end
    PartyMenu._kantoAscendantIconPaletteWrapped = true
  end
  PartyMenu._kantoAscendantIconPalettePolicy = {
    animated = P.loadedStyle == "animated",
  }

  function P.restartRequired()
    return normalizeStyle(mod.options:get("party_icon_style")) ~= P.loadedStyle
  end

  P.normalizeStyle = normalizeStyle

  return P
end
