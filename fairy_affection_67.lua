local function optionalImage(mod,path)
  local optional=mod.exports and mod.exports.optionalPokemonAssets
  return optional and optional.allowPending(path)==true or false
end
-- KASC-67-FAIRY-AFFECTION
-- Functional Rocket reward and reversible Gen-VI Eevee evolution boundary.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "fairy affection data missing")
  local row = assert(data.species and data.species.SYLVEON,
    "Sylveon definition missing")
  local rules = assert(opts.generationRules, "generation rules missing")
  local F = {
    ITEM = "AFFECTION_RIBBON", SPECIES = "SYLVEON", DEX = 700,
    CARD_ID = "KASC-67-FAIRY-AFFECTION",
    OWNER = "kasc.species.fairy-affection/v1",
    OPTION_KEY = "fairy_affection_67",
    order = { "SYLVEON" }, partyIcons = {}, installed = false,
    enabled = opts.enabled ~= false,
  }
  local bound = {
    shinySystem = opts.shinySystem,
    crystalAnimation = opts.crystalAnimation,
  }

  local function registerSegment(reason)
    if opts.supportLog and type(opts.supportLog.registerSegment) == "function" then
      opts.supportLog.registerSegment({
        segmentId=F.CARD_ID, cardId=F.CARD_ID, version="1.0.0",
        schema="kasc.optional-feature-card/v1", owner=F.OWNER,
        active=F.enabled, dependencyStatus=reason or "local-reviewed",
        providerStatus=F.enabled and "runtime-loaded" or "cold-disabled",
        buildReceiptId="docs/FAIRY_AFFECTION_67.md",
        rollbackReceiptId="select-fairy-evolution-off",
      })
    end
  end

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end
  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}; for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end
  local function readable(relative)
    return type(relative) == "string"
      and (type(mod.read) ~= "function" or type(mod:read(relative)) == "string")
  end
  local function shiny(mon)
    if bound.shinySystem and type(bound.shinySystem.isShiny) == "function" then
      local ok, value = pcall(bound.shinySystem.isShiny, mon)
      if ok then return value == true end
    end
    return type(mon) == "table" and mon.shiny == true
  end
  local function allowed(dataArg, save)
    local game = { data = dataArg, save = save }
    local definition = dataArg and dataArg.pokemon and dataArg.pokemon.SYLVEON
      or row
    return rules.speciesAvailable(game, "SYLVEON", definition) == true
  end
  local function healthyNonEgg(mon)
    local hp = type(mon) == "table" and tonumber(mon.hp)
    return hp and hp > 0 and hp < math.huge
      and not mon.isEgg and not mon.eggSpecies and not mon.egg or false
  end
  local function normalizeItemArgs(dataArg, save, itemId, target, battle)
    if save == nil and itemId == nil and type(dataArg) == "table"
        and dataArg.data ~= nil and dataArg.itemId ~= nil then
      local ctx = dataArg
      return ctx.data, ctx.save, ctx.itemId, ctx.target, ctx.battle
    end
    return dataArg, save, itemId, target, battle
  end

  if not F.enabled then
    F.order = {}
    F.disabledReason = "option-disabled"
    function F.bind() return true, F.disabledReason end
    function F.install() return true, F.disabledReason end
    registerSegment("option-disabled")
    return F
  end

  for _, asset in pairs(row.assets) do
    assert(readable(asset) or optionalImage(mod,asset), "Sylveon asset missing: " .. tostring(asset))
  end
  local moves = {}
  for _, id in ipairs(row.level1Moves) do
    if mod.content.moves:get(id) then moves[#moves + 1] = id end
  end
  local parent = mod.content.pokemon:get(row.parent)
  if #moves == 0 or not parent then
    F.enabled = false
    F.disabledReason = #moves == 0 and "safe-move-unavailable"
      or "eevee-unavailable"
    F.order = {}
    function F.bind() return true, F.disabledReason end
    function F.install() return true, F.disabledReason end
    registerSegment(F.disabledReason)
    return F
  end
  F.enabled = true
  registerSegment("local-reviewed")

  local effect = "KA_FAIRY_AFFECTION_67_EVOLUTION"
  mod.content.item_effects:register(effect, {
    field=true, battle=false, needsTarget=true, callStyle="legacyArgs",
    use=function(dataArg, save, itemId, target, battle)
      dataArg, save, itemId, target, battle = normalizeItemArgs(
        dataArg, save, itemId, target, battle)
      if battle or itemId ~= F.ITEM or type(target) ~= "table"
          or target.species ~= row.parent then
        return "failed", { tr("It won't have\nany effect.",
          "Es hat keine\nWirkung.") }
      end
      if not allowed(dataArg, save) then
        return "failed", { tr("GEN VI rules are\nnot active.",
          "GEN-VI-Regeln sind\nnicht aktiv.") }
      end
      local pending = healthyNonEgg(target)
        and require("src.pokemon.Evolution").pendingFor(
          { data=dataArg, save=save }, target, { kind="item", item=itemId })
      if pending ~= F.SPECIES then
        return "failed", { tr("It won't have\nany effect.",
          "Es hat keine\nWirkung.") }
      end
      return "consumed", nil, {
        evolveTo=F.SPECIES, evolveVia="ITEM",
        fairyAffectionItem=F.ITEM,
      }
    end,
  })
  mod.content.items:register(F.ITEM, {
    id=F.ITEM, name=tr("AFFECTION RIBBON", "ZUNEIGUNGSBAND"),
    price=0, tossable=true, needsTarget=true, effect=effect,
    rocketRaidReward=true, originEpoch=6,
  })
  mod.content.cries:register(F.SPECIES, {
    file=mod.path .. "/" .. row.assets.cry,
  })
  local textId = "_KantoAscendantFairyAffection67DexSylveon"
  mod.content.text:register(textId, tr(
    "It calms fights by sending waves of kindness through its ribbons.",
    "Mit seinen Bändern sendet es Wellen der Güte aus und beendet Streit."))
  local icon = { image=mod.path .. "/" .. row.assets.icon, frames=2 }
  mod.content.icons:register(F.SPECIES, icon)
  local inches = math.floor(row.heightM * 39.3700787 + 0.5)
  mod.content.pokemon:register(F.SPECIES, {
    id=F.SPECIES, name=tr(row.names.en, row.names.de),
    dex=row.dex, sourceDex=row.sourceDex, originGeneration=6,
    types=copy(row.types), baseStats=copy(row.baseStats),
    catchRate=parent.catchRate or 45, baseExp=row.baseExp,
    growthRate=parent.growthRate or "MEDIUM_FAST",
    level1Moves=moves, learnset={}, tmhm=copy(parent.tmhm or {}),
    evolutions={}, cry=F.SPECIES,
    spriteFront=mod.path .. "/" .. row.assets.front,
    spriteBack=mod.path .. "/" .. row.assets.back,
    frontSize=7, trueColor=true, battleScaleFront=1, battleScaleBack=1,
    icon=icon, certificateExcluded=true,
    dexEntry={kind=tr("Intertwining", "Bindung"), text=textId,
      heightFt=math.floor(inches/12), heightIn=inches%12,
      weight=math.floor(row.weightKg*22.0462262+0.5),
      heightM=row.heightM, weightKg=row.weightKg},
  })
  local evolutions, duplicate = copy(parent.evolutions or {}), false
  for _, evo in ipairs(evolutions) do
    if evo.species == F.SPECIES then duplicate = true break end
  end
  if not duplicate then
    evolutions[#evolutions + 1] = {
      method="ITEM", item=F.ITEM, species=F.SPECIES,
    }
    mod.content.pokemon:patch(row.parent, { evolutions=evolutions })
  end
  F.partyIcons[F.SPECIES] = {
    normal=row.assets.icon, shiny=row.assets.iconShiny, frames=2,
  }

  if mod.hooks and type(mod.hooks.wrap) == "function" then
    mod.hooks:wrap("evolution.check", function(nextCheck, game, mon, evo, trigger)
      if type(mon) == "table" and mon.species == row.parent
          and type(evo) == "table" and evo.species == F.SPECIES
          and evo.method == "ITEM" and evo.item == F.ITEM
          and (not healthyNonEgg(mon) or not allowed(game.data, game.save)) then
        return false
      end
      return nextCheck(game, mon, evo, trigger)
    end, 9450)
    mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
      ctx = ctx or {}; local resolved = nextSprite(path, ctx)
      if (ctx.species or ctx.mon and ctx.mon.species) ~= F.SPECIES then
        return resolved
      end
      local animationRoot = mod.path .. "/assets/crystal_animated/"
      local static2DRoot = mod.path .. "/assets/non_crystal_pixel_2d_67/"
      local selected2DRoot = mod.path .. "/assets/neo_crystal_2d_67/"
      if ctx.kind == "battle" and type(resolved) == "string"
          and resolved:sub(1, #selected2DRoot) == selected2DRoot then
        return resolved
      end
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
      return mod.path .. "/" .. row.assets[
        side .. (shiny(ctx.mon) and "Shiny" or "")]
    end, 915)
    mod.hooks:wrap("pokemon.icon", function(nextIcon, path, ctx)
      ctx = ctx or {}; local resolved = nextIcon(path, ctx)
      if (ctx.species or ctx.mon and ctx.mon.species) ~= F.SPECIES then
        return resolved
      end
      return mod.path .. "/" .. row.assets[
        shiny(ctx.mon) and "iconShiny" or "icon"]
    end, 915)
  end

  function F.bind(services)
    services = services or {}
    if services.shinySystem then bound.shinySystem = services.shinySystem end
    if services.crystalAnimation then
      bound.crystalAnimation = services.crystalAnimation
    end
    if services.followerSprites
        and type(services.followerSprites.register) == "function" then
      services.followerSprites.register(F.SPECIES, {
        normalRelative=row.assets.follower,
        shinyRelative=row.assets.followerShiny,
        frames=6, width=16, height=96, walker=true, trueColor=true,
        source="Showdown fixed-canvas fairy-affection projection",
      })
    end
    return true
  end

  function F.install(game)
    if not (game and game.data and game.data.pokemon
        and game.data.pokemon[F.SPECIES]) then return false, "game-data" end
    game.data.pokemon[F.SPECIES].name = tr(row.names.en, row.names.de)
    F.installed = true
    return true
  end

  F.data = data
  return F
end
