-- Kanto Ascendant 6.6 selected segment: permanent Alola Gift Code forms.
--
-- Regional forms use collision-free runtime species/dex identities. Their
-- National-Dex origin remains inspectable through sourceDex/baseSpecies, but
-- neither Kanto's ordinary species row nor its animation slot is patched.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "Alola form data required")
  local i18n = opts.i18n
  local A = {
    order = {}, bySpecies = {}, byRuntimeDex = {}, partyIcons = {},
    animationDexOrder = {}, source = data._meta,
    enabled = opts.enabled ~= false,
    audit = { registered = 0, giftProfiles = 0 },
  }
  local bound = {
    shinySystem = opts.shinySystem,
    crystalAnimation = opts.crystalAnimation,
  }

  -- Alolan Ninetales needs its real secondary type. The Gen-I registry has no
  -- FAIRY row, so this content owner supplies only the canonical type and
  -- matchup records required by the selected form; it does not enable a
  -- broader generation-rules profile or add Fairy moves.
  if A.enabled and mod.content and mod.content.type_chart then
    local chart = mod.content.type_chart
    -- Hoenn and the later-starter catalogue may already have installed the
    -- shared Fairy authority earlier in this same content-registration pass.
    -- Preserve that row (and any existing matchup rows) so card load order is
    -- irrelevant and the registry never receives a duplicate identity.
    if not chart:get("FAIRY") then
      chart:register("FAIRY", {
        name = "FAIRY", category = "special",
      })
    end
    for _, row in ipairs({
        { "FAIRY", "FIGHTING", 20 }, { "FAIRY", "DRAGON", 20 },
        { "FAIRY", "DARK", 20 }, { "FAIRY", "FIRE", 5 },
        { "FAIRY", "POISON", 5 }, { "FAIRY", "STEEL", 5 },
        { "FIGHTING", "FAIRY", 5 }, { "POISON", "FAIRY", 20 },
        { "BUG", "FAIRY", 5 }, { "DRAGON", "FAIRY", 0 },
        { "DARK", "FAIRY", 5 }, { "STEEL", "FAIRY", 20 },
      }) do
      local id = row[1] .. ">" .. row[2]
      if not chart:get(id) then
        chart:register(id, { multiplier = row[3] })
      end
    end
  end

  local function tr(en, de)
    return i18n and i18n.text and i18n.text(en, de) or en
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  -- Registration needs a known sprite declaration, not installed optional bytes.
  -- Unknown/missing non-image assets still fail. Actual readers stay unchanged.
  local function declaredOptional(relative)
    local optional = mod.exports and mod.exports.optionalPokemonAssets
    return optional and optional.allowPending(relative) == true or false
  end

  local function readable(relative)
    return type(mod.read) ~= "function" or type(mod:read(relative)) == "string"
  end

  local function shiny(mon)
    if bound.shinySystem and type(bound.shinySystem.isShiny) == "function" then
      local ok, value = pcall(bound.shinySystem.isShiny, mon)
      if ok then return value == true end
    end
    return type(mon) == "table" and mon.shiny == true
  end

  local function dexText(row)
    return tr(
      "A regional form from\nAlola. This one was\nreceived as a gift.",
      "Eine Regionalform aus\nAlola. Sie wurde als\nGeschenk erhalten.")
  end

  for _, species in ipairs(data.order or {}) do
    local row = assert(data.species[species], "missing Alola row " .. species)
    for _, key in ipairs({ "front", "frontShiny", "back", "backShiny",
        "icon", "iconShiny", "follower", "followerShiny" }) do
      assert(readable(row.assets[key]) or declaredOptional(row.assets[key]), species .. " missing Alola asset " .. key)
    end
    A.order[#A.order + 1] = species
    A.animationDexOrder[#A.animationDexOrder + 1] = row.runtimeDex
    A.bySpecies[species], A.byRuntimeDex[row.runtimeDex] = row, species
    A.partyIcons[species] = {
      normal = row.assets.icon, shiny = row.assets.iconShiny, frames = 2,
    }
    if A.enabled then
      local base = assert(mod.content.pokemon:get(row.baseSpecies),
        "missing Alola base species " .. tostring(row.baseSpecies))
      local textId = "_KantoAscendantAlola66Dex" .. species
      mod.content.text:register(textId, dexText(row))
      local icon = { image = mod.path .. "/" .. row.assets.icon, frames = 2 }
      mod.content.icons:register(species, icon)
      local inches = math.floor(row.heightM * 39.3700787 + 0.5)
      mod.content.pokemon:register(species, {
        id = species, name = tr(row.names.en, row.names.de),
        dex = row.runtimeDex, sourceDex = row.sourceDex,
        baseSpecies = row.baseSpecies, formId = "ALOLA",
        regionalForm = "ALOLA", originGeneration = 7, giftOnly = true,
        types = copy(row.types), baseStats = copy(row.baseStats),
        catchRate = base.catchRate, baseExp = row.baseExp,
        growthRate = base.growthRate,
        -- Gift forms inherit only the safe R/B/Y acquisition vocabulary from
        -- their ordinary species. Regional evolution rules are not fabricated.
        level1Moves = copy(base.level1Moves or {}),
        learnset = copy(base.learnset or {}), tmhm = copy(base.tmhm or {}),
        evolutions = {}, cry = base.cry or row.baseSpecies,
        spriteFront = mod.path .. "/" .. row.assets.front,
        spriteBack = mod.path .. "/" .. row.assets.back,
        frontSize = 7, trueColor = true,
        battleScaleFront = 1, battleScaleBack = 1,
        icon = icon,
        dexEntry = {
          kind = tr("REGIONAL FORM", "REGIONALFORM"), text = textId,
          heightFt = math.floor(inches / 12), heightIn = inches % 12,
          weight = math.floor(row.weightKg * 22.0462262 + 0.5),
          heightM = row.heightM, weightKg = row.weightKg,
        },
      })
      A.audit.registered = A.audit.registered + 1
    end
  end

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
      ctx = ctx or {}
      local resolved = nextSprite(path, ctx)
      local row = A.bySpecies[ctx.species or ctx.mon and ctx.mon.species]
      if not row then return resolved end
      local animationRoot = mod.path .. "/assets/crystal_animated/"
      local static2DRoot = mod.path .. "/assets/non_crystal_pixel_2d_67/"
      if ctx.kind == "battle" and bound.crystalAnimation
          and type(resolved) == "string"
          and resolved:sub(1, #animationRoot) == animationRoot then
        return resolved
      end
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #static2DRoot) == static2DRoot then
        return resolved
      end
      local side = ctx.side == "back" and "back" or "front"
      local key = side .. (shiny(ctx.mon) and "Shiny" or "")
      ctx.trueColor = true
      return mod.path .. "/" .. row.assets[key]
    end, 910)
    mod.hooks:wrap("pokemon.icon", function(nextIcon, path, ctx)
      ctx = ctx or {}
      local resolved = nextIcon(path, ctx)
      local row = A.bySpecies[ctx.species or ctx.mon and ctx.mon.species]
      if not row then return resolved end
      local relative = shiny(ctx.mon) and row.assets.iconShiny or row.assets.icon
      return mod.path .. "/" .. relative
    end, 910)
  end

  function A.animationDexes(seed)
    local out = copy(seed or {})
    for _, dex in ipairs(A.animationDexOrder) do out[dex] = true end
    return out
  end

  function A.giftProfiles()
    local profiles = {}
    for _, species in ipairs(A.order) do
      local row, gift = A.bySpecies[species], A.bySpecies[species].gift
      profiles[#profiles + 1] = {
        id = gift.id, species = species,
        name = { en = row.names.en .. " GIFT", de = row.names.de .. "-GESCHENK" },
        short = copy(row.names),
        source = {
          en = "Kanto Ascendant Alola regional-form Gift Code",
          de = "Kanto-Ascendant-Geschenkcode für eine Alola-Regionalform",
        },
        level = gift.level, moves = copy(gift.moves),
        giftCode = true, giftCodeOnly = true,
        formId = "ALOLA", baseSpecies = row.baseSpecies,
        originGeneration = 7,
        spriteAuthority = "registered-regional-form-species",
        moveAuthority = "merged-rby-runtime",
        assetAuthority = {
          family = "alola_forms_67", dex = row.sourceDex,
          runtimeDex = row.runtimeDex,
          front = row.assets.front, back = row.assets.back,
          icon = row.assets.icon, follower = row.assets.follower,
        },
        editions = { "red", "blue", "yellow" }, badges = 0,
        terrain = "gift", habitat = "regional_form_gift",
      }
    end
    A.audit.giftProfiles = #profiles
    return profiles
  end

  function A.bind(services)
    services = services or {}
    if services.shinySystem then bound.shinySystem = services.shinySystem end
    if services.crystalAnimation then
      bound.crystalAnimation = services.crystalAnimation
    end
    if A.enabled and services.followerSprites
        and services.followerSprites.register then
      for _, species in ipairs(A.order) do
        local row = A.bySpecies[species]
        services.followerSprites.register(species, {
          normalRelative = row.assets.follower,
          shinyRelative = row.assets.followerShiny,
          frames = 6, width = 16, height = 96,
          walker = true, trueColor = true,
          source = "Showdown gen5ani Alola fixed-canvas projection",
        })
      end
    end
    return A
  end

  function A.install(game)
    if not A.enabled then return false, "disabled" end
    if not (game and game.data and game.data.pokemon) then
      return false, "game data"
    end
    for _, species in ipairs(A.order) do
      local row, live = A.bySpecies[species], game.data.pokemon[species]
      if live then
        live.name = tr(row.names.en, row.names.de)
        if game.data.text then
          game.data.text["_KantoAscendantAlola66Dex" .. species] = dexText(row)
        end
      end
    end
    return true
  end

  A.data = data
  return A
end
