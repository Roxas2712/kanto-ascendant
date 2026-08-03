-- Compatibility bridge for all-species follower mods that only ship the
-- original 151 overworld sheets. Kanto Ascendant adds the complete Johto
-- Pokédex, so a Johto lead must never make such a mod request a missing
-- follower_<SPECIES>.png and crash the renderer.
--
-- Prefer the bundled, species-accurate Gen-2-style sheet. Only when an
-- individual source asset is damaged or missing does the bridge redirect to
-- a related Kanto Pokémon. The real name, cry, stats and party selection
-- never change.

return function(mod, opts)
  opts = opts or {}
  local spriteAssets = opts.spriteAssets
  local shinySystem = opts.shinySystem
  local C = {}

  local FAMILY_PROXY = {
    CHIKORITA = "BULBASAUR", BAYLEEF = "IVYSAUR", MEGANIUM = "VENUSAUR",
    CYNDAQUIL = "CHARMANDER", QUILAVA = "CHARMELEON",
    TYPHLOSION = "CHARIZARD",
    TOTODILE = "SQUIRTLE", CROCONAW = "WARTORTLE",
    FERALIGATR = "BLASTOISE",
    SENTRET = "RATTATA", FURRET = "RATICATE",
    HOOTHOOT = "SPEAROW", NOCTOWL = "FEAROW",
    LEDYBA = "CATERPIE", LEDIAN = "BUTTERFREE",
    SPINARAK = "WEEDLE", ARIADOS = "BEEDRILL", CROBAT = "GOLBAT",
    CHINCHOU = "GOLDEEN", LANTURN = "SEAKING",
    PICHU = "PIKACHU", CLEFFA = "CLEFAIRY",
    IGGLYBUFF = "JIGGLYPUFF", TOGEPI = "CLEFAIRY", TOGETIC = "CLEFABLE",
    NATU = "DODUO", XATU = "DODRIO",
    MAREEP = "PIKACHU", FLAAFFY = "RAICHU", AMPHAROS = "ELECTABUZZ",
    BELLOSSOM = "ODDISH", MARILL = "SQUIRTLE", AZUMARILL = "WARTORTLE",
    SUDOWOODO = "EXEGGUTOR", POLITOED = "POLIWRATH",
    HOPPIP = "ODDISH", SKIPLOOM = "GLOOM", JUMPLUFF = "VILEPLUME",
    AIPOM = "MANKEY", SUNKERN = "ODDISH", SUNFLORA = "VILEPLUME",
    YANMA = "BUTTERFREE", WOOPER = "SQUIRTLE", QUAGSIRE = "BLASTOISE",
    ESPEON = "EEVEE", UMBREON = "EEVEE", MURKROW = "PIDGEY",
    SLOWKING = "SLOWBRO", MISDREAVUS = "GASTLY", UNOWN = "MAGNEMITE",
    WOBBUFFET = "MR_MIME", GIRAFARIG = "PONYTA",
    PINECO = "SHELLDER", FORRETRESS = "CLOYSTER",
    DUNSPARCE = "EKANS", GLIGAR = "ZUBAT", STEELIX = "ONIX",
    SNUBBULL = "GROWLITHE", GRANBULL = "ARCANINE",
    QWILFISH = "GOLDEEN", SCIZOR = "SCYTHER",
    SHUCKLE = "PARAS", HERACROSS = "PINSIR", SNEASEL = "MEOWTH",
    TEDDIURSA = "CUBONE", URSARING = "KANGASKHAN",
    SLUGMA = "GRIMER", MAGCARGO = "MUK",
    SWINUB = "NIDORAN_M", PILOSWINE = "RHYDON",
    CORSOLA = "STARYU", REMORAID = "GOLDEEN", OCTILLERY = "TENTACRUEL",
    DELIBIRD = "FARFETCHD", MANTINE = "LAPRAS", SKARMORY = "FEAROW",
    HOUNDOUR = "GROWLITHE", HOUNDOOM = "ARCANINE",
    KINGDRA = "SEADRA", PHANPY = "CUBONE", DONPHAN = "RHYDON",
    PORYGON2 = "PORYGON", STANTLER = "TAUROS", SMEARGLE = "MEOWTH",
    TYROGUE = "MACHOP", HITMONTOP = "HITMONLEE",
    SMOOCHUM = "JYNX", ELEKID = "ELECTABUZZ", MAGBY = "MAGMAR",
    MILTANK = "TAUROS", BLISSEY = "CHANSEY",
    RAIKOU = "ARCANINE", ENTEI = "ARCANINE", SUICUNE = "PERSIAN",
    LARVITAR = "CUBONE", PUPITAR = "GRAVELER", TYRANITAR = "RHYDON",
    LUGIA = "ARTICUNO", HO_OH = "MOLTRES", CELEBI = "MEW",
  }

  local TYPE_PROXY = {
    NORMAL = "RATTATA", FIRE = "CHARMANDER", WATER = "SQUIRTLE",
    ELECTRIC = "PIKACHU", GRASS = "BULBASAUR", ICE = "SEEL",
    FIGHTING = "MACHOP", POISON = "EKANS", GROUND = "SANDSHREW",
    FLYING = "PIDGEY", PSYCHIC = "ABRA", PSYCHIC_TYPE = "ABRA",
    BUG = "CATERPIE", ROCK = "GEODUDE", GHOST = "GASTLY",
    DRAGON = "DRATINI", DARK = "MEOWTH", STEEL = "MAGNEMITE",
    FAIRY = "CLEFAIRY",
  }

  local function firstType(def)
    if type(def) ~= "table" then return nil end
    local types = def.types
    if type(types) == "table" then
      return types[1] or types.primary
    end
    return def.type1
  end

  function C.proxySpecies(species, data)
    if type(species) ~= "string" or species == "" then return "CHARMANDER" end
    local proxy = FAMILY_PROXY[species]
    if proxy then return proxy end
    local def = data and data.pokemon and data.pokemon[species]
    local dex = def and tonumber(def.dex)
    if dex and dex <= 151 then return species end
    return TYPE_PROXY[firstType(def)] or "CHARMANDER"
  end

  function C.localPath(species, mon)
    if not (spriteAssets and spriteAssets.follower) then return nil end
    local shiny = shinySystem and shinySystem.isShiny
      and shinySystem.isShiny(mon) or false
    return spriteAssets.follower(species, shiny)
  end

  local function selectedFollower(game, species)
    local exports = game and game.mods and game.mods.exports
    if type(exports) == "table" then
      for _, api in pairs(exports) do
        if type(api) == "table" and type(api.activeMon) == "function" then
          local ok, mon = pcall(api.activeMon, game)
          if ok and mon and mon.species == species then return mon end
        end
      end
    end
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if mon.species == species and not mon.isEgg and (mon.hp or 0) > 0 then
        return mon
      end
    end
  end

  function C.setShinySystem(controller)
    shinySystem = controller
  end

  local function upvalue(fn, wanted)
    if type(fn) ~= "function" or not (debug and debug.getupvalue) then
      return nil
    end
    local index = 1
    while true do
      local name, value = debug.getupvalue(fn, index)
      if not name then return nil end
      if name == wanted then return index, value end
      index = index + 1
    end
  end

  local STATE_KEY = "__kantoAscendantFollowerCompat"

  function C.install(game)
    if not (debug and debug.getupvalue and debug.setupvalue) then return false end
    local ok, PikachuFollower = pcall(require, "src.world.PikachuFollower")
    if not ok or type(PikachuFollower) ~= "table" then return false end

    local _, configureSpriteDef =
      upvalue(PikachuFollower.update, "configureSpriteDef")
    if type(configureSpriteDef) ~= "function" then
      -- The compatible follower mod is optional. Vanilla and unrelated
      -- follower implementations do not expose this seam.
      return false
    end
    local assetIndex, originalAssetPath =
      upvalue(configureSpriteDef, "assetPath")
    if not assetIndex or type(originalAssetPath) ~= "function" then return false end

    local previous = rawget(PikachuFollower, STATE_KEY)
    if previous and previous.configure == configureSpriteDef
        and previous.replacement == originalAssetPath then
      return true
    end
    if previous and type(previous.restore) == "function" then
      pcall(previous.restore)
    end

    local replacement
    replacement = function(species)
      local localPath = C.localPath(species,
        selectedFollower(game, species))
      if localPath then return localPath end
      local proxy = C.proxySpecies(species, game and game.data)
      local path = originalAssetPath(proxy)
      local fs = love and love.filesystem
      if fs and fs.getInfo and not fs.getInfo(path) then
        path = originalAssetPath("CHARMANDER")
      end
      return path
    end
    debug.setupvalue(configureSpriteDef, assetIndex, replacement)

    local state = {
      configure = configureSpriteDef,
      index = assetIndex,
      original = originalAssetPath,
      replacement = replacement,
    }
    state.restore = function()
      local _, current = upvalue(configureSpriteDef, "assetPath")
      if current == replacement then
        debug.setupvalue(configureSpriteDef, assetIndex, originalAssetPath)
      end
      if rawget(PikachuFollower, STATE_KEY) == state then
        rawset(PikachuFollower, STATE_KEY, nil)
      end
    end
    rawset(PikachuFollower, STATE_KEY, state)
    if mod.log and mod.log.info then
      mod.log:info(
        "Johto follower art enabled with species sheets and safe Kanto fallback")
    end
    return true
  end

  C.familyProxy = FAMILY_PROXY
  C.typeProxy = TYPE_PROXY
  return C
end
