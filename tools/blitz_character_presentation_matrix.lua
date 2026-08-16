-- Package-only renderer acceptance for Kanto Ascendant's six fixed trainer
-- identities.  This module is shared by the historical BLITZ forensic and
-- the L02 Battle-Art package matrix.  It may freely mutate the disposable
-- in-memory QA save; it never opens a normal save.

return function(ctx)
  local game = assert(ctx.game)
  local U = assert(ctx.U)
  local check = assert(ctx.check)
  local info = assert(ctx.info)
  local root = assert(ctx.outDir) .. "/character_matrix"
  local renderer = ctx.renderer or "both"
  assert(renderer == "2d" or renderer == "full" or renderer == "both",
    "character presentation renderer must be 2d/full/both")
  local ascendant = assert(ctx.ascendant)
  local characters = assert(ascendant.extendedCharacters)
  local pack = assert(ascendant.frlgTrainerPack)
  local passages = assert(ascendant.johtoMastersPassages)
  local Runtime = require("src.mods.Runtime")
  local Sprites = require("src.pokemon.Sprites")
  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local TrainerCard = require("src.ui.TrainerCard")
  local HallOfFame = require("src.ui.HallOfFame")
  local Credits = require("src.ui.Credits")
  local TitleState = require("src.ui.TitleState")
  local Pipelines = require("src.render.Pipelines")
  local voxelResolver = assert(ascendant.voxelRendererCompat,
    "shared Voxel-renderer resolver missing")
  local rendererExport, rendererId, rendererReason =
    voxelResolver.resolve(game)
  assert(rendererExport,
    "reviewed Voxel renderer missing: " .. tostring(rendererReason))
  local overworldBattle, moduleId, moduleReason =
    voxelResolver.module(game, "OverworldBattle")
  assert(overworldBattle and moduleId == rendererId,
    "reviewed OverworldBattle seam missing: " .. tostring(moduleReason))
  local battleArt
  if rendererId == "BATTLE_ART_VOXEL_FORK" then
    local battleArtId, battleArtReason
    battleArt, battleArtId, battleArtReason =
      voxelResolver.module(game, "BattleArt")
    assert(battleArt and battleArtId == rendererId,
      "reviewed Battle Art module missing: " .. tostring(battleArtReason))
    assert(rendererExport.version == "1.8.3",
      "Battle Art must be the reviewed 1.8.3 package")
  end
  local authority = assert(game.mods.mods.kanto_ascendant)
  local STACK_CLEAR_BUDGET = 128

  local function clearStack()
    for _ = 1, STACK_CLEAR_BUDGET do
      if not game.stack:top() then return true end
      game.stack:pop()
    end
    assert(game.stack:top() == nil, "character matrix stack clear exceeded budget")
    return true
  end

  local function endsWith(path, suffix)
    return type(path) == "string" and path:sub(-#suffix) == suffix
  end

  local function dimensions(image)
    if not (image and image.getDimensions) then return nil, nil end
    local ok, width, height = pcall(image.getDimensions, image)
    if not ok then return nil, nil end
    return width, height
  end

  local function imageData(imageOrPath)
    if imageOrPath == nil then return nil end
    if type(imageOrPath) == "string" then
      local path = imageOrPath
      if path:sub(1, 1) ~= "/" and path:sub(1, 5) ~= "save/"
          and not path:find("^mods/") then
        path = authority.path .. "/" .. path
      end
      local ok, value = pcall(love.image.newImageData, path)
      return ok and value or nil
    end
    local method = imageOrPath.newImageData
    if type(method) ~= "function" then return nil end
    local ok, value = pcall(method, imageOrPath)
    return ok and value or nil
  end

  local function imageStats(imageOrPath)
    local data = imageData(imageOrPath)
    if not data then return nil end
    local width, height = data:getDimensions()
    local opaque, minimum, maximum = 0, math.huge, -math.huge
    local colors = {}
    local weighted = 0
    for y = 0, height - 1 do
      for x = 0, width - 1 do
        local red, green, blue, alpha = data:getPixel(x, y)
        if alpha > 0.02 then
          opaque = opaque + 1
          local light = red + green + blue
          minimum, maximum = math.min(minimum, light), math.max(maximum, light)
          local key = math.floor(red * 31 + .5) * 1024
            + math.floor(green * 31 + .5) * 32
            + math.floor(blue * 31 + .5)
          colors[key] = true
          weighted = (weighted + key * (x + 3) * (y + 5)) % 2147483647
        end
      end
    end
    local colorCount = 0
    for _ in pairs(colors) do colorCount = colorCount + 1 end
    return {
      width = width, height = height, opaque = opaque, colors = colorCount,
      range = opaque > 0 and maximum - minimum or 0,
      signature = table.concat({ width, height, opaque, colorCount, weighted }, ":"),
    }
  end

  local function healthy(label, imageOrPath, minOpaque, minColors)
    local stats = imageStats(imageOrPath)
    check(label, stats and stats.opaque >= (minOpaque or 100)
      and stats.colors >= (minColors or 4) and stats.range >= .25,
      stats and table.concat({ stats.width .. "x" .. stats.height,
        "opaque=" .. stats.opaque, "colors=" .. stats.colors,
        "range=" .. string.format("%.3f", stats.range) }, ";") or "unreadable")
    return stats
  end

  local options = game.mods.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant = options
  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant = options

  local function emitOption(key, value)
    options[key] = value
    game.save.options.modOptions.kanto_ascendant[key] = value
    Runtime.emit("mod.options_changed", {
      game = game, mod = "kanto_ascendant", key = key, value = value,
    })
  end

  local function trainerStyle(style)
    emitOption("trainer_portrait_style", style)
    pack.refresh(game)
    check("ordinary trainer mode live: " .. style,
      pack.selectedStyle(game) == style, pack.selectedStyle(game))
  end

  local function set2d()
    Pipelines.setLevel("voxel", 0)
    Pipelines.syncOptions(game.save.options)
    if overworldBattle.setting then
      -- Both reviewed renderers use index 1 for ON.  Battle Art uses index 2
      -- for its explicit OFF comparison; historical DRAMALESS used index 5.
      overworldBattle.setting:setIndex(
        rendererId == "BATTLE_ART_VOXEL_FORK" and 2 or 5, game)
    end
    check("native 2D renderer active", Pipelines.level("voxel") == 0,
      Pipelines.levelLabel("voxel"))
  end

  local function setFull()
    -- Cross the non-FULL rung so either reviewed renderer applies its actual
    -- FULL preset before the final package receipt is sampled.
    Pipelines.setLevel("voxel", 2)
    U.wait(2)
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    if overworldBattle.setting then overworldBattle.setting:setIndex(1, game) end
    if overworldBattle.backSetting then
      overworldBattle.backSetting:setIndex(1, game)
    end
    if battleArt and battleArt.setting then
      battleArt.setting:setIndex(2, game) -- authored animated Pokemon set
    end
    check("FULL Voxel renderer active",
      Pipelines.level("voxel") == 1
        and Pipelines.levelLabel("voxel") == "FULL",
      Pipelines.levelLabel("voxel"))
  end

  local function waitIntro(battle)
    for _ = 1, 900 do
      if game.stack:top() == battle and battle.showPlayerBack
          and battle.showEnemyTrainer and (battle.introSlide or 1) <= 0 then
        return true
      end
      U.wait(1)
    end
    return false
  end

  local function pushBattle(classId, party)
    game.save.party = { Pokemon.new(game.data, "BULBASAUR", 70) }
    local battle = BattleState.newTrainer(game, classId, party or 1)
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    check(classId .. " reaches the real trainer intro", waitIntro(battle),
      battle.phase)
    return battle
  end

  emitOption("character_sprite_style", "crystal")
  check("fixed hero field family is Crystal",
    characters.characterStyle() == "crystal", characters.characterStyle())

  local heroes = {
    { id = "RED", rival = "BLUE", tag = "red" },
    { id = "BLUE", rival = "GREEN", tag = "blue" },
    { id = "GREEN", rival = "RED", tag = "green" },
  }
  local modes = { "original", "frlg", "crystal_hd" }

  -- Oak's selector is an actual 128px screen-space renderer.  Instantiate it
  -- under every ordinary-trainer mode, then capture all three live choices.
  local selectorSignatures = {}
  for _, mode in ipairs(modes) do
    trainerStyle(mode)
    clearStack()
    local selector = characters.CharacterSelect.new(game, {}, function() end)
    game.stack:push(selector)
    for index, id in ipairs(characters.selectionOrder) do
      selector.index = index
      local visual = characters.selectionVisual(id)
      local portrait = selector.portraits[id]
      local width, height = dimensions(portrait)
      local expected = ("assets/characters/crystal_chars/%s_voxel_front_hd.png")
        :format(id:lower())
      local stats = imageStats(portrait)
      check(("%s selector fixed under %s"):format(id, mode),
        visual and visual.path == expected and width == 128 and height == 128
          and stats ~= nil,
        tostring(visual and visual.path) .. ":" .. tostring(width)
          .. "x" .. tostring(height))
      selectorSignatures[id] = selectorSignatures[id] or stats.signature
      check(("%s selector pixels invariant under %s"):format(id, mode),
        stats and selectorSignatures[id] == stats.signature, stats and stats.signature)
      if mode == "crystal_hd" then
        check(id .. " live selector screenshot",
          U.shot(game, ("%s/selector_%s.png"):format(root, id:lower())))
        local proof = selector.__screenSpaceHd
        check(id .. " selector uses integer 128px screen-space render",
          proof and proof.character == id and proof.sourceWidth == 128
            and proof.sourceHeight == 128 and proof.integerZoom >= 1
            and proof.integerZoom == math.floor(proof.integerZoom),
          proof and proof.integerZoom)
      end
    end
  end
  clearStack()

  -- The title's Green/Blue/Red movie is also fixed identity art.  Construct
  -- the real wrapped title under all three ordinary-trainer modes and compare
  -- decoded pixel receipts rather than trusting filenames alone.
  local titleSignatures = {}
  for _, mode in ipairs(modes) do
    trainerStyle(mode)
    local title = TitleState.new(game, { onNewGame = function() end })
    local seen = {}
    for index, entry in ipairs(title.kaTitleTrainers or {}) do
      local expectedId = ({ "GREEN", "BLUE", "RED" })[index]
      local stats = imageStats(entry.image)
      seen[entry.id] = stats and stats.signature
      titleSignatures[entry.id] = titleSignatures[entry.id]
        or (stats and stats.signature)
      check(("%s title identity fixed under %s"):format(expectedId, mode),
        entry.id == expectedId and stats ~= nil
          and titleSignatures[entry.id] == stats.signature,
        tostring(entry.id) .. ":" .. tostring(stats and stats.signature))
    end
    check("title carries three distinct fixed identities under " .. mode,
      seen.GREEN and seen.BLUE and seen.RED
        and seen.GREEN ~= seen.BLUE and seen.GREEN ~= seen.RED
        and seen.BLUE ~= seen.RED,
      table.concat({ tostring(seen.GREEN), tostring(seen.BLUE),
        tostring(seen.RED) }, "/"))
  end

  -- Runtime resolvers and live field actors must stay fixed under every
  -- ordinary-trainer mode.  Credits is recorded honestly: Gen-I Credits has
  -- no trainer-portrait scene, although the shared resolver is ready.
  for _, mode in ipairs(modes) do
    trainerStyle(mode)
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    for _, row in ipairs(heroes) do
      characters.select(row.id)
      characters.refreshVisuals(game)
      local player = game.overworld.player
      local walk = characters.getPlayerSprite("overworld")
      local bike = characters.getPlayerSprite("bike")
      local fish = characters.getPlayerSprite("fishing")
      check(("%s live walker fixed under %s"):format(row.id, mode),
        player.ascendantCharacter == row.id and walk and walk.sprite
          and player.sprite.def == game.data.sprites[walk.sprite],
        player.ascendantCharacter)
      check(("%s live bike fixed under %s"):format(row.id, mode),
        bike and bike.sprite and player.bikeSprite.def == game.data.sprites[bike.sprite],
        bike and bike.sprite)
      check(("%s live fishing fixed under %s"):format(row.id, mode),
        fish and fish.sprite
          and player.fishingSprite.def == game.data.sprites[fish.sprite],
        fish and fish.sprite)
      for kind, state in pairs({ trainer_card = "trainerCard",
          hall_of_fame = "hallOfFame", credits = "credits" }) do
        local visual = assert(characters.getPlayerSprite(state))
        local path, trueColor = Sprites.playerPath(game.data, "front", { kind = kind })
        check(("%s %s resolver fixed under %s"):format(row.id, kind, mode),
          endsWith(path, visual.path) and trueColor == true,
          tostring(path) .. ":" .. tostring(trueColor))
      end
      local back = assert(characters.getPlayerSprite("battleBack"))
      local backPath, backTrue = Sprites.playerPath(game.data, "back", {
        kind = "battle", side = "back",
      })
      check(("%s 2D back resolver fixed under %s"):format(row.id, mode),
        endsWith(backPath, back.path) and backTrue == true,
        tostring(backPath))
      local rival = game.data.trainers.OPP_RIVAL1
      local expectedRival = assert(characters.getRivalSprite("rivalPortrait"))
      check(("%s fixed rival front under %s"):format(row.rival, mode),
        rival.ascendantCharacter == row.rival
          and endsWith(rival.pic, expectedRival.path) and rival.trueColor == true,
        tostring(rival.pic))
    end
  end

  -- Live 2D field, Trainer Card, Hall of Fame, battle backs, rival fronts and
  -- all five throw poses for each Kanto hero.
  if renderer ~= "full" then
    trainerStyle("crystal_hd")
    set2d()
    for _, row in ipairs(heroes) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    characters.select(row.id)
    characters.refreshVisuals(game)
    game.save.player.name = row.id
    local player = game.overworld.player
    check(row.id .. " walking screenshot",
      U.shot(game, ("%s/%s_walk.png"):format(root, row.tag)))
    player.onBike, player.facing, player.animClock = true, "left", 0
    U.wait(4)
    check(row.id .. " bicycle screenshot",
      U.shot(game, ("%s/%s_bike.png"):format(root, row.tag)))
    player.onBike, player.fishing = false, true
    game.overworld.fishing = { facing = "left" }
    U.wait(4)
    check(row.id .. " fishing screenshot",
      U.shot(game, ("%s/%s_fishing.png"):format(root, row.tag)))
    player.fishing, game.overworld.fishing = nil, nil

    clearStack()
    local card = TrainerCard.new(game, {})
    game.stack:push(card)
    local cardWidth, cardHeight = dimensions(card.pic)
    check(row.id .. " live Trainer Card is fixed true-colour 64px",
      card.pic and card.picTrueColor == true
        and cardWidth == 64 and cardHeight == 64,
      tostring(cardWidth) .. "x" .. tostring(cardHeight))
    check(row.id .. " Trainer Card screenshot",
      U.shot(game, ("%s/%s_trainer_card.png"):format(root, row.tag)))
    clearStack()

    U.teleport(game, "ROUTE_1", 5, 5, "down")
    characters.select(row.id)
    characters.refreshVisuals(game)
    local battle = pushBattle("OPP_RIVAL1", 1)
    local backWidth, backHeight = dimensions(battle.playerBackPic)
    local frontWidth, frontHeight = dimensions(battle.trainerPic)
    local expectedBack = ("assets/characters/crystal_chars/%s_back.png")
      :format(row.tag)
    local expectedFront = ("assets/characters/crystal_chars/%s_front.png")
      :format(row.rival:lower())
    check(row.id .. " live 2D battle back is its fixed 64px source",
      backWidth == 64 and backHeight == 64
        and endsWith(battle.playerBackScalePath, expectedBack),
      tostring(battle.playerBackScalePath))
    check(row.rival .. " live 2D rival front is its fixed 64px source",
      frontWidth == 64 and frontHeight == 64
        and endsWith(game.data.trainers.OPP_RIVAL1.pic, expectedFront),
      tostring(game.data.trainers.OPP_RIVAL1.pic))
    check(row.id .. " 2D battle intro screenshot",
      U.shot(game, ("%s/%s_2d_battle.png"):format(root, row.tag)))
    local throws, captured, count = battle.playerBackThrowPics or {}, {}, 0
    check(row.id .. " owns five live 2D throw poses", #throws == 5, #throws)
    for tick = 1, 1400 do
      for index, frame in ipairs(throws) do
        if battle.playerBackPic == frame and not captured[index] then
          captured[index] = U.shot(game,
            ("%s/%s_throw_%d.png"):format(root, row.tag, index))
          if captured[index] then count = count + 1 end
        end
      end
      if count == 5 then break end
      if tick % 4 == 0 then U.tap(game, "a") else U.wait(1) end
    end
    check(row.id .. " renders all five live 2D throw poses", count == 5, count)
    clearStack()

    game.save.party = { Pokemon.new(game.data, "PIKACHU", 70) }
    local hall = HallOfFame.new(game, function() end)
    game.stack:push(hall)
    hall.index, hall.phase, hall.scrollX, hall.timer = 2, "player_stats", 96, 120
    U.wait(4)
    local expectedHall = assert(characters.getPlayerSprite("hallOfFame"))
    local hallPath, hallTrue = Sprites.playerPath(game.data, "front", {
      kind = "hall_of_fame",
    })
    check(row.id .. " live Hall of Fame follows fixed identity",
      hall.playerPic and hall.playerTrueColor == true and hallTrue == true
        and endsWith(hallPath, expectedHall.path), tostring(hallPath))
    check(row.id .. " Hall of Fame screenshot",
      U.shot(game, ("%s/%s_hall_of_fame.png"):format(root, row.tag)))
    clearStack()

    local creditsPath, creditsTrue = Sprites.playerPath(game.data, "front", {
      kind = "credits",
    })
    local credits = Credits.new(game, function() end)
    check(row.id .. " credits resolver remains fixed and true-colour",
      endsWith(creditsPath,
        characters.getPlayerSprite("credits").path) and creditsTrue == true,
      tostring(creditsPath))
    info(row.id .. " Gen-I credits trainer surface",
      credits.playerPic == nil
        and "not used: Gen-I Credits renders staff/Pokemon only; resolver retained"
        or "unexpected player portrait surface")
    end
  end

  -- FULL uses the 64px identity card as the registered fallback and the
  -- native 128px authored master in the reviewed renderer's trainer billboard.
  if renderer ~= "2d" then
    setFull()
    for _, mode in ipairs(modes) do
    trainerStyle(mode)
    for _, row in ipairs(heroes) do
      characters.select(row.id)
      characters.refreshVisuals(game)
      local fake = { game = game, oppClass = "OPP_RIVAL1",
        showPlayerBack = true, showEnemyTrainer = true }
      local playerTexture = overworldBattle.sideTexture(fake, "player")
      local rivalTexture = overworldBattle.sideTexture(fake, "enemy")
      local player64 = characters.getPlayerSprite("voxelFront").path
      local rival64 = characters.getRivalSprite("voxelFront").path
      local player128 = ("assets/characters/crystal_chars/%s_voxel_front_hd.png")
        :format(row.tag)
      local rival128 = ("assets/characters/crystal_chars/%s_voxel_front_hd.png")
        :format(row.rival:lower())
      local lowP, lowR = imageStats(player64), imageStats(rival64)
      local highP, highR = imageStats(player128), imageStats(rival128)
      check(("%s FULL 64/128 fixed under %s"):format(row.id, mode),
        lowP and lowP.width == 64 and lowP.height == 64
          and highP and highP.width == 128 and highP.height == 128
          and playerTexture.ascendantHighResSource == player128
          and playerTexture.ascendantStandingTrainer == row.id,
        playerTexture and playerTexture.ascendantHighResSource)
      check(("%s rival FULL 64/128 fixed under %s"):format(row.rival, mode),
        lowR and lowR.width == 64 and lowR.height == 64
          and highR and highR.width == 128 and highR.height == 128
          and rivalTexture.ascendantHighResSource == rival128
          and rivalTexture.ascendantStandingTrainer == row.rival,
        rivalTexture and rivalTexture.ascendantHighResSource)
    end
    end
    trainerStyle("crystal_hd")
    for _, row in ipairs(heroes) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    characters.select(row.id)
    characters.refreshVisuals(game)
    local battle = pushBattle("OPP_RIVAL1", 1)
    local playerTexture = overworldBattle.sideTexture(battle, "player")
    local rivalTexture = overworldBattle.sideTexture(battle, "enemy")
    local pw, ph = dimensions(playerTexture and playerTexture.canvas)
    local rw, rh = dimensions(rivalTexture and rivalTexture.canvas)
    check(row.id .. " live FULL billboard preserves 128px master",
      playerTexture and playerTexture.ascendantHighResTrainer == true
        and pw == 320 and ph == 288, tostring(pw) .. "x" .. tostring(ph))
    check(row.rival .. " live FULL rival preserves 128px master",
      rivalTexture and rivalTexture.ascendantHighResTrainer == true
        and rw == 320 and rh == 288, tostring(rw) .. "x" .. tostring(rh))
    check(row.id .. " FULL battle screenshot",
      U.shot(game, ("%s/%s_full_battle.png"):format(root, row.tag)))
    clearStack()
    end
  end

  -- The global ORIGINAL/FRLG/CRYSTAL HD switch belongs only to ordinary
  -- trainers.  Brock is sampled through both native 2D and FULL; decoded
  -- picture/canvas statistics prove each result has contrast and is not a
  -- white/palette-washed placeholder.
  for _, mode in ipairs(modes) do
    trainerStyle(mode)
    if renderer ~= "full" then
      set2d()
      U.teleport(game, "PEWTER_GYM", 4, 10, "up")
      local battle = pushBattle("OPP_BROCK", 1)
      local trainer = game.data.trainers.OPP_BROCK
      check("ordinary Brock carries 2D mode " .. mode,
        trainer.ascendantTrainerPortraitStyle == mode,
        trainer.ascendantTrainerPortraitStyle)
      healthy("ordinary Brock 2D is palette-safe/non-washed: " .. mode,
        battle.trainerPic, 100, 3)
      check("ordinary Brock 2D screenshot: " .. mode,
        U.shot(game, ("%s/ordinary_%s_2d.png"):format(root, mode)))
      clearStack()
    end

    if renderer ~= "2d" then
      setFull()
      U.teleport(game, "PEWTER_GYM", 4, 10, "up")
      local battle = pushBattle("OPP_BROCK", 1)
      local texture = overworldBattle.sideTexture(battle, "enemy")
      if mode == "crystal_hd" then
        check("ordinary Brock FULL uses approved Crystal HD source",
          texture and texture.ascendantHighResTrainer == true
            and texture.kantoTrainerPortraitStyle == "crystal_hd"
            and texture.kantoTrainerClass == "OPP_BROCK",
          texture and texture.ascendantHighResSource)
      else
        check("ordinary Brock FULL keeps native " .. mode .. " card",
          texture and texture.ascendantHighResTrainer ~= true,
          texture and texture.ascendantHighResSource)
      end
      healthy("ordinary Brock FULL is palette-safe/non-washed: " .. mode,
        texture and texture.canvas, 100, 3)
      check("ordinary Brock FULL screenshot: " .. mode,
        U.shot(game, ("%s/ordinary_%s_full.png"):format(root, mode)))
      clearStack()
    end
  end

  local johto = {
    { key = "silver", class = "KA_JOHTO_SILVER", field = "SILVER_FINALE",
      sprite = "SPRITE_KA_JOHTO_SILVER", front = "silver_front.png",
      voxel = "silver_voxel_front.png", hd = "silver_voxel_front_hd.png" },
    { key = "kris", class = "KA_JOHTO_KRIS", field = "KRIS_FINALE",
      sprite = "SPRITE_KA_JOHTO_KRIS", front = "kris_front.png",
      voxel = "kris_voxel_front.png", hd = "kris_voxel_front_hd.png" },
    { key = "gold", class = "KA_JOHTO_GOLD", field = "GOLD_FINALE",
      sprite = "SPRITE_KA_JOHTO_GOLD", front = "gold_front_color_v1.png",
      voxel = "gold_voxel_front.png", hd = "gold_voxel_front_hd.png" },
  }

  -- Cross all three ordinary modes through the Johto-specific runtime seam.
  -- These identities are enemy-only and may never resolve as Red/Blue/Green.
  if renderer ~= "2d" then setFull() end
  for _, mode in ipairs(modes) do
    trainerStyle(mode)
    for _, row in ipairs(johto) do
      local trainer = game.data.trainers[row.class]
      local expectedFront = "assets/johto_masters/battle/" .. row.front
      check(("%s 2D front fixed under %s"):format(row.class, mode),
        trainer and trainer.trueColor == true
          and endsWith(trainer.pic, expectedFront)
          and trainer.ascendantCharacter == nil,
        trainer and trainer.pic)
      if renderer ~= "2d" then
        local fake = { game = game, oppClass = row.class,
          showEnemyTrainer = true, showPlayerBack = true }
        local spec = characters.voxelStandingTrainerSpec(fake, "enemy")
        local texture = overworldBattle.sideTexture(fake, "enemy")
        local expected64 = "assets/johto_masters/battle/" .. row.voxel
        local expected128 = "assets/johto_masters/battle/" .. row.hd
        local low, high = imageStats(expected64), imageStats(expected128)
        check(("%s FULL 64/128 fixed under %s"):format(row.class, mode),
          spec and spec.fallback == expected64 and spec.path == expected128
            and low and low.width == 64 and low.height == 64
            and high and high.width == 128 and high.height == 128
            and texture and texture.johtoMasterClass == row.class
            and texture.johtoMasterVoxel == true
            and texture.ascendantHighResSource == expected128,
          texture and texture.ascendantHighResSource)
        check(("%s never aliases Kanto rival under %s"):format(row.class, mode),
          characters.voxelStandingTrainerCharacter(fake, "enemy") == nil
            and texture and texture.ascendantStandingTrainer
              == row.class:gsub("KA_", "")
            and texture.ascendantStandingTrainer ~= "RED"
            and texture.ascendantStandingTrainer ~= "BLUE"
            and texture.ascendantStandingTrainer ~= "GREEN",
          texture and texture.ascendantStandingTrainer)
      end
    end
  end

  trainerStyle("crystal_hd")
  for _, row in ipairs(johto) do
    local map = assert(passages.MAPS[row.field])
    U.teleport(game, map.id, map.entryX, map.entryY, "up")
    U.wait(30)
    local master, visibleMasters = nil, 0
    for _, npc in ipairs(game.overworld.npcs or {}) do
      local def = npc.def or {}
      local masterText = "TEXT_KA_JOHTO_" .. row.key:upper() .. "_MASTER"
      local sealText = "TEXT_KA_JOHTO_" .. row.key:upper() .. "_SEAL"
      if (def.text == masterText or def.text == sealText)
          and def.renderMode ~= "none" then
        visibleMasters = visibleMasters + 1
      end
      if def.text == masterText then
        master = npc
      end
    end
    local spriteDef = game.data.sprites[row.sprite]
    check(row.class .. " live arena walker is unique",
      visibleMasters == 1 and master and master.def.sprite == row.sprite
        and master.sprite and master.sprite.def == spriteDef
        and endsWith(spriteDef.image,
          "assets/johto_masters/field/" .. row.key .. "_walk.png"),
      tostring(master and master.def.sprite) .. ":visible=" .. visibleMasters)
    check(row.class .. " arena walker screenshot",
      U.shot(game, ("%s/johto_%s_arena.png"):format(root, row.key)))

    if renderer ~= "full" then
      set2d()
      local battle = pushBattle(row.class, 1)
      local expectedFront = "assets/johto_masters/battle/" .. row.front
      local width, height = dimensions(battle.trainerPic)
      check(row.class .. " live 2D arena front is exact 64px source",
        width == 64 and height == 64
          and endsWith(game.data.trainers[row.class].pic, expectedFront)
          and game.data.trainers[row.class].trueColor == true,
        tostring(game.data.trainers[row.class].pic))
      local stats = healthy(row.class .. " live 2D front is non-washed",
        battle.trainerPic, 250, 4)
      if row.key == "gold" then
        check("Gold live 2D front is the coloured authored asset",
          endsWith(game.data.trainers[row.class].pic,
            "gold_front_color_v1.png") and stats and stats.colors >= 8,
          stats and stats.colors)
      elseif row.key == "kris" then
        check("Kris live 2D front is the exact authored Kris asset",
          endsWith(game.data.trainers[row.class].pic, "kris_front.png"),
          game.data.trainers[row.class].pic)
      end
      check(row.class .. " 2D arena battle screenshot",
        U.shot(game, ("%s/johto_%s_2d.png"):format(root, row.key)))
      clearStack()
    end

    if renderer ~= "2d" then
      setFull()
      U.teleport(game, map.id, map.entryX, map.entryY, "up")
      local battle = pushBattle(row.class, 1)
      local texture = overworldBattle.sideTexture(battle, "enemy")
      local tw, th = dimensions(texture and texture.canvas)
      local expected128 = "assets/johto_masters/battle/" .. row.hd
      check(row.class .. " live FULL arena uses exact 128px master",
        texture and texture.johtoMasterClass == row.class
          and texture.johtoMasterVoxel == true
          and texture.ascendantHighResSource == expected128
          and texture.ascendantHighResTrainer == true
          and tw == 320 and th == 288,
        tostring(texture and texture.ascendantHighResSource))
      if row.key == "kris" then
        check("Kris live FULL source is authored Kris, never a rival alias",
          texture.ascendantHighResSource
            == "assets/johto_masters/battle/kris_voxel_front_hd.png"
            and texture.ascendantStandingTrainer == "JOHTO_KRIS",
          texture.ascendantStandingTrainer)
      end
      check(row.class .. " FULL arena battle screenshot",
        U.shot(game, ("%s/johto_%s_full.png"):format(root, row.key)))
      clearStack()
    end
    info(row.class .. " unsupported player surfaces",
      "enemy-only Johto Master: no player back, throw, Trainer Card, HOF or credits required")
  end

  return true
end
