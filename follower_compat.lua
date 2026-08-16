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
    PICHU = "PIKACHU", GOROCHU = "RAICHU", CLEFFA = "CLEFAIRY",
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

  local function followerApi(game)
    for _, id in ipairs({ "FOLLOWERS_EX", "PokePCFollowers_VoxelMerge" }) do
      local ok, handle = false, nil
      if mod and type(mod.find) == "function" then
        ok, handle = pcall(function() return mod.find(id) end)
      end
      local api = ok and type(handle) == "table" and handle.exports or nil
      if type(api) == "table" and type(api.activeMon) == "function" then
        return api
      end
    end
  end

  local function selectedFollower(game, species)
    local api = followerApi(game)
    if api then
      local ok, mon = pcall(api.activeMon, game)
      if ok and mon and (not species or mon.species == species) then
        return mon
      end
    end
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if (not species or mon.species == species)
          and not mon.isEgg and (mon.hp or 0) > 0 then
        return mon
      end
    end
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

  -- Followers EX and visual wrappers can sit above PokéPC Followers' update
  -- function. Search the closure chain instead of assuming configureSpriteDef
  -- is a direct upvalue of the outermost wrapper.
  local function nestedUpvalue(fn, wanted, visited, depth)
    if type(fn) ~= "function" or not (debug and debug.getupvalue) then
      return nil
    end
    visited = visited or {}
    depth = depth or 0
    if visited[fn] or depth > 8 then return nil end
    visited[fn] = true

    local index = 1
    while true do
      local name, value = debug.getupvalue(fn, index)
      if not name then return nil end
      if name == wanted then return index, value, fn end
      if type(value) == "function" then
        local foundIndex, foundValue, owner =
          nestedUpvalue(value, wanted, visited, depth + 1)
        if foundIndex then return foundIndex, foundValue, owner end
      end
      index = index + 1
    end
  end

  function C.setShinySystem(controller)
    shinySystem = controller
  end

  local STATE_KEY = "__kantoAscendantFollowerCompat"
  local RENDERER_STATE_KEY = "__kantoAscendantFollowerRendererCompat"
  local YELLOW_STARTER_STATE_KEY = "__kantoAscendantYellowStarterCompat"
  local YELLOW_OAK_PIKACHU_ENCOUNTER = "yellow_oak_pikachu"

  -- PokéPC Followers 1.3.0 includes a separate Yellow-to-Charmander story
  -- conversion: its BattleState.newWild wrapper changes every level-5
  -- Pikachu into Charmander. That is unrelated to follower support. New
  -- engines carry an explicit scene marker through every vararg-preserving
  -- wrapper; the narrow Pallet/pre-starter check is retained only for older
  -- engines and packages that predate that marker.
  function C.isYellowOakPikachuRequest(game, species, level, requestOpts)
    if type(requestOpts) == "table"
        and requestOpts.scriptedEncounter
          == YELLOW_OAK_PIKACHU_ENCOUNTER then
      return true
    end
    if tonumber(level) ~= 5
        or (species ~= "PIKACHU" and species ~= "CHARMANDER") then
      return false
    end
    local save = game and game.save
    local flags = save and save.flags or {}
    if flags.EVENT_GOT_STARTER
        or flags.EVENT_FOLLOWED_OAK_INTO_LAB then
      return false
    end
    local ow = game and game.overworld
    local mapId = ow and ow.map and ow.map.id
      or save and save.player and save.player.map
    local player = ow and ow.player
    local x = player and player.cellX
      or save and save.player and save.player.x
    local y = player and player.cellY
      or save and save.player and save.player.y
    return mapId == "PALLET_TOWN" and y == 0 and (x == 10 or x == 11)
  end

  function C.repairYellowOakPikachuBattle(game, battle, BattleState)
    if type(battle) ~= "table" then return false end
    battle.scriptedEncounter = YELLOW_OAK_PIKACHU_ENCOUNTER
    if type(battle.repairYellowOakPikachuDemo) == "function" then
      return battle:repairYellowOakPikachuDemo()
    end

    local mon = battle.enemy and battle.enemy.mon
    if not (mon and mon.species == "PIKACHU" and mon.level == 5) then
      local okPokemon, Pokemon = pcall(require, "src.pokemon.Pokemon")
      local makeBattler = BattleState and BattleState.makeBattler
      if not (okPokemon and Pokemon and type(Pokemon.new) == "function"
          and type(makeBattler) == "function"
          and game and game.data) then
        return false
      end
      mon = Pokemon.new(game.data, "PIKACHU", 5)
      battle.enemy = makeBattler(game.data, mon, false)
      local okStrings, Strings = pcall(require, "src.core.Strings")
      if okStrings and type(Strings) == "table"
          and getmetatable(Strings) and getmetatable(Strings).__call then
        battle.introText = Strings(
          "Wild %s\nappeared!", battle.enemy.name)
      end
    end
    local seen = game and game.save and game.save.pokedex
      and game.save.pokedex.seen
    if seen then seen.PIKACHU = true end
    return battle.enemy and battle.enemy.mon
      and battle.enemy.mon.species == "PIKACHU"
      and battle.enemy.mon.level == 5
  end

  local function installYellowStarterGuard()
    local okVersion, GameVersion = pcall(require, "src.core.GameVersion")
    if not (okVersion and GameVersion and GameVersion.isYellow
        and GameVersion.isYellow()) then return false end
    local okBattle, BattleState = pcall(require, "src.battle.BattleState")
    if not (okBattle and BattleState
        and type(BattleState.newWild) == "function") then return false end

    local previous = rawget(BattleState, YELLOW_STARTER_STATE_KEY)
    if previous and BattleState.newWild == previous.wrapper then return true end
    if previous and type(previous.restore) == "function" then
      pcall(previous.restore)
    end

    local wrapped = BattleState.newWild
    local guard
    guard = function(game, species, level, ...)
      local requestOpts = select(1, ...)
      local oakDemo = C.isYellowOakPikachuRequest(
        game, species, level, requestOpts)
      local seen = game and game.save and game.save.pokedex
        and game.save.pokedex.seen
      local charmanderWasSeen = seen and seen.CHARMANDER
      local battle = wrapped(game, species, level, ...)
      if oakDemo
          and C.repairYellowOakPikachuBattle(game, battle, BattleState) then
        if seen and not charmanderWasSeen then seen.CHARMANDER = nil end
      end
      return battle
    end
    local state = {
      original = wrapped,
      wrapper = guard,
    }
    state.restore = function()
      if BattleState.newWild == guard then BattleState.newWild = wrapped end
      if rawget(BattleState, YELLOW_STARTER_STATE_KEY) == state then
        rawset(BattleState, YELLOW_STARTER_STATE_KEY, nil)
      end
    end
    BattleState.newWild = guard
    rawset(BattleState, YELLOW_STARTER_STATE_KEY, state)
    if mod.log and mod.log.info then
      mod.log:info(
        "Yellow compatibility: Oak's marked Pikachu demo is protected")
    end
    return true
  end

  local function pathExists(path)
    if type(path) ~= "string" or path == "" then return false end
    local prefix = tostring(mod.path or "") .. "/"
    if path:sub(1, #prefix) == prefix and type(mod.read) == "function" then
      local ok, found = pcall(mod.read, mod, path:sub(#prefix + 1))
      return ok and found ~= nil
    end
    -- External follower APIs own their paths. Ask the engine-owned resolver
    -- rather than dereferencing the sandbox-denied love.filesystem facade or
    -- assuming a stale Followers-EX/PokePC path still exists.
    local okAssets, Assets = pcall(require, "src.render.Assets")
    if not (okAssets and Assets and type(Assets.exists) == "function") then
      return false
    end
    local ok, found = pcall(Assets.exists, path)
    return ok and found == true
  end

  local function resolvedFollowerPath(game, mon, originalAssetPath)
    if type(mon) ~= "table" or type(mon.species) ~= "string" then return nil end
    local localPath = C.localPath(mon.species, mon)
    if pathExists(localPath) then return localPath end

    local api = followerApi(game)
    local assetPath = originalAssetPath
      or (api and type(api.assetPath) == "function" and api.assetPath)
    if type(assetPath) ~= "function" then return nil end

    local proxy = C.proxySpecies(mon.species, game and game.data)
    local ok, path = pcall(assetPath, proxy)
    if ok and pathExists(path) then return path end
    ok, path = pcall(assetPath, "CHARMANDER")
    if ok and pathExists(path) then return path end
    return nil
  end

  C.resolvedPath = resolvedFollowerPath

  -- Android and some release sandboxes do not expose debug.getupvalue, so
  -- closure patching cannot be the only compatibility path. Every follower
  -- implementation eventually constructs SPRITE_PIKACHU through this
  -- renderer. Correct the sheet at that last safe point before a missing
  -- follower_<JOHTO>.png path can reach love.graphics.newImage and crash.
  local function installRendererGuard(game)
    if not followerApi(game) then return false end
    local ok, SpriteRenderer = pcall(require, "src.render.SpriteRenderer")
    if not ok or type(SpriteRenderer) ~= "table"
        or type(SpriteRenderer.new) ~= "function" then
      return false
    end

    local previous = rawget(SpriteRenderer, RENDERER_STATE_KEY)
    if previous and previous.game == game
        and SpriteRenderer.new == previous.wrapper then
      return true
    end
    if previous and type(previous.restore) == "function" then
      pcall(previous.restore)
    end

    local originalNew = SpriteRenderer.new
    local wrapper
    wrapper = function(def, seed)
      local followerDef = type(def) == "table"
        and (def.id == "SPRITE_PIKACHU"
          or def == (game and game.data and game.data.sprites
            and game.data.sprites.SPRITE_PIKACHU))
      if followerDef then
        local mon = selectedFollower(game)
        local path = resolvedFollowerPath(game, mon)
        if path then
          def.image = path
          def.frames = 6
          def.walker = true
          def.trueColor = true
        end
      end
      return originalNew(def, seed)
    end

    local state = { game = game, original = originalNew, wrapper = wrapper }
    state.restore = function()
      if SpriteRenderer.new == wrapper then SpriteRenderer.new = originalNew end
      if rawget(SpriteRenderer, RENDERER_STATE_KEY) == state then
        rawset(SpriteRenderer, RENDERER_STATE_KEY, nil)
      end
    end
    SpriteRenderer.new = wrapper
    rawset(SpriteRenderer, RENDERER_STATE_KEY, state)
    return true
  end

  local function refreshVisibleFollower(game, PikachuFollower, replacement)
    local mon = selectedFollower(game)
    local def = game and game.data and game.data.sprites
      and game.data.sprites.SPRITE_PIKACHU
    if not (mon and def) then return false end

    def.image = replacement(mon.species)
    def.frames = 6
    def.walker = true
    def.trueColor = true

    local ow = game.overworld
    local npc = ow and PikachuFollower.current
      and PikachuFollower.current(ow)
    if not npc then return true end
    local okRenderer, SpriteRenderer =
      pcall(require, "src.render.SpriteRenderer")
    if not (okRenderer and SpriteRenderer
        and type(SpriteRenderer.new) == "function") then
      return false
    end
    npc.sprite = SpriteRenderer.new(def, npc.id)
    npc._pokepcFollowerSpecies = mon.species
    return true
  end

  function C.install(game)
    local yellowStarterGuarded = installYellowStarterGuard()
    local guarded = installRendererGuard(game)
    if not (debug and debug.getupvalue and debug.setupvalue) then
      return guarded or yellowStarterGuarded
    end
    local ok, PikachuFollower = pcall(require, "src.world.PikachuFollower")
    if not ok or type(PikachuFollower) ~= "table" then
      return guarded or yellowStarterGuarded
    end

    local _, configureSpriteDef =
      nestedUpvalue(PikachuFollower.update, "configureSpriteDef")
    if type(configureSpriteDef) ~= "function" then
      -- The compatible follower mod is optional. Vanilla and unrelated
      -- follower implementations do not expose this seam.
      return guarded or yellowStarterGuarded
    end
    local assetIndex, originalAssetPath =
      upvalue(configureSpriteDef, "assetPath")
    if not assetIndex or type(originalAssetPath) ~= "function" then
      return guarded or yellowStarterGuarded
    end

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
      local mon = selectedFollower(game, species) or { species = species }
      return resolvedFollowerPath(game, mon, originalAssetPath)
        or originalAssetPath("CHARMANDER")
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
    refreshVisibleFollower(game, PikachuFollower, replacement)
    if mod.log and mod.log.info then
      mod.log:info(
        "Johto follower art enabled with species sheets and safe Kanto fallback")
    end
    return true
  end

  function C.restore()
    local restored = false
    local okBattle, BattleState = pcall(require, "src.battle.BattleState")
    local starterState = okBattle
      and rawget(BattleState, YELLOW_STARTER_STATE_KEY)
    if starterState and type(starterState.restore) == "function" then
      starterState.restore()
      restored = true
    end
    local ok, PikachuFollower = pcall(require, "src.world.PikachuFollower")
    local state = ok and rawget(PikachuFollower, STATE_KEY)
    if state and type(state.restore) == "function" then
      state.restore()
      restored = true
    end
    local okRenderer, SpriteRenderer =
      pcall(require, "src.render.SpriteRenderer")
    local rendererState = okRenderer
      and rawget(SpriteRenderer, RENDERER_STATE_KEY)
    if rendererState and type(rendererState.restore) == "function" then
      rendererState.restore()
      restored = true
    end
    return restored
  end

  C.familyProxy = FAMILY_PROXY
  C.typeProxy = TYPE_PROXY
  return C
end
