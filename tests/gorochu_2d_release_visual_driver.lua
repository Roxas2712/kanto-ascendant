-- Fail-closed, one-battle acceptance for Gorochu's 2D normal, shiny and
-- classic/grayscale presentation.  The host must give this probe a fresh
-- throwaway identity and output directory; no player save is ever mounted.

return function(game)
  assert(os.getenv("KA_GOROCHU_2D_RELEASE_QA") == "1",
    "KA_GOROCHU_2D_RELEASE_QA=1 is required")
  assert(os.getenv("POKEPORT_VERSION") == "red",
    "the focused Gorochu 2D receipt is pinned to Red")
  assert(os.getenv("POKEPORT_SPEED") == "1",
    "POKEPORT_SPEED=1 is required for deterministic frame capture")

  local nonce = assert(os.getenv("KA_GOROCHU_QA_NONCE"),
    "KA_GOROCHU_QA_NONCE is required")
  assert(nonce:match("^[%w][%w_-]+$") and #nonce >= 8 and #nonce <= 48,
    "KA_GOROCHU_QA_NONCE must be an 8-48 character safe unique token")
  local expectedIdentity = "ka65-gorochu-2d-release-" .. nonce
  assert(os.getenv("POKEPORT_IDENTITY") == expectedIdentity,
    "refusing a non-Gorochu or reused player identity")
  assert(love.filesystem.getIdentity() == expectedIdentity,
    "LÖVE mounted a different identity")
  local saveDirectory = tostring(
    love.filesystem.getSaveDirectory()):gsub("\\", "/")
  assert(saveDirectory:find(expectedIdentity, 1, true),
    "throwaway identity does not own its save directory")

  local outputDir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local normalizedOutput = outputDir:gsub("\\", "/"):gsub("/+$", "")
  assert(normalizedOutput:find("/private/tmp/", 1, true) == 1
      or normalizedOutput:find("/tmp/", 1, true) == 1,
    "SHOT_DIR must be a throwaway /private/tmp or /tmp directory")
  assert(normalizedOutput:find("ka-gorochu-2d-release-" .. nonce, 1, true),
    "SHOT_DIR must carry this run's unique Gorochu nonce")

  local expectedModRoot = assert(os.getenv("KA_GOROCHU_MOD_ROOT"),
    "KA_GOROCHU_MOD_ROOT is required")
  local function normalizedPath(path)
    return tostring(path or ""):gsub("\\", "/"):gsub("/+$", "")
  end
  expectedModRoot = normalizedPath(expectedModRoot)
  assert(expectedModRoot:sub(1, 1) == "/",
    "KA_GOROCHU_MOD_ROOT must be absolute")

  local screenshotNames = {
    "01_color_normal_back_shiny_front_a.png",
    "02_color_normal_back_shiny_front_b.png",
    "03_color_shiny_back_normal_front_a.png",
    "04_color_shiny_back_normal_front_b.png",
    "05_classic_grayscale_a.png",
    "06_classic_grayscale_b.png",
  }
  for _, name in ipairs(screenshotNames) do
    local stale = io.open(normalizedOutput .. "/" .. name, "rb")
    assert(stale == nil, "SHOT_DIR is not fresh: " .. name)
    if stale then stale:close() end
  end
  local staleReceipt = io.open(normalizedOutput .. "/driver_result.txt", "rb")
  assert(staleReceipt == nil, "SHOT_DIR already contains driver_result.txt")
  if staleReceipt then staleReceipt:close() end

  local U = dofile(assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL is required"))
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local PaletteFX = require("src.render.PaletteFX")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local SaveData = require("src.core.SaveData")
  local Sprites = require("src.pokemon.Sprites")
  local edition = GameVersion.get()
  assert(edition == "red", "wrong ROM edition mounted")

  -- Disk must be empty before this driver mutates the fresh in-memory boot
  -- save.  A pre-existing save means the host selected a user identity.
  local diskBefore = SaveData.load(edition)
  assert(diskBefore == nil,
    "isolated Gorochu identity already contains a save; choose a new nonce")

  U.wait(20)
  local loader = assert(game.mods, "mod loader missing")
  local handle = assert(loader.mods and loader.mods.kanto_ascendant,
    "Kanto Ascendant handle missing")
  local mountedModRoot = normalizedPath(handle.path)
  local function diskBytes(path)
    local file = assert(io.open(path, "rb"), "cannot read " .. path)
    local body = file:read("*a")
    file:close()
    return body
  end
  local function mountedBytes(relative)
    if mountedModRoot:sub(1, 1) == "/" then
      return diskBytes(mountedModRoot .. "/" .. relative)
    end
    return assert(love.filesystem.read(mountedModRoot .. "/" .. relative),
      "cannot read mounted mod file " .. relative)
  end
  local boundFiles = {
    "manifest.json", "main.lua", "crystal_animation.lua", "gorochu.lua",
    "assets/crystal/gorochu_front.png",
    "assets/crystal/gorochu_front_shiny.png",
    "assets/crystal/gorochu_back.png",
    "assets/crystal/gorochu_back_shiny.png",
  }
  for _, side in ipairs({ "front", "back" }) do
    for _, variant in ipairs({ "normal", "shiny", "grayscale" }) do
      for frame = 1, 6 do
        boundFiles[#boundFiles + 1] =
          ("assets/crystal_animated/%s/%s/1026/%03d.png")
            :format(side, variant, frame)
      end
    end
  end
  for _, relative in ipairs(boundFiles) do
    assert(mountedBytes(relative)
        == diskBytes(expectedModRoot .. "/" .. relative),
      "mounted bytes differ from KA_GOROCHU_MOD_ROOT: " .. relative)
  end
  local ascendant = assert(loader.exports and loader.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local crystal = assert(ascendant.crystalAnimation,
    "Crystal animation controller missing")
  local shinySystem = assert(ascendant.shinySystem,
    "Kanto Ascendant shiny controller missing")
  assert(ascendant.gorochu and ascendant.gorochu.available,
    "Gorochu species unavailable")
  assert(game.data.pokemon and game.data.pokemon.GOROCHU,
    "Gorochu species data missing")

  game.save.options = game.save.options or {}
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  loader.modOptions.kanto_ascendant =
    loader.modOptions.kanto_ascendant or {}
  local function setOption(key, value)
    loader.modOptions.kanto_ascendant[key] = value
    game.save.options.modOptions.kanto_ascendant[key] = value
    if loader.events then
      loader.events:emit("mod.options_changed", {
        mod = "kanto_ascendant", key = key, value = value,
      })
    end
  end

  setOption("pokemon_sprite_style", "crystal")
  setOption("sprite_style_battle", true)
  setOption("crystal_animation", true)
  setOption("legend_art", "crystal")
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  Pipelines.setLevel("voxel", 0)
  Pipelines.syncOptions(game.save.options)
  assert(Pipelines.level("voxel") == 0,
    "focused receipt must use the 2D renderer")

  game.save.player = game.save.player or {}
  game.save.player.name = "GORO QA"
  game.save.player.id = 6504
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.inventory = game.save.inventory or {}
  game.save.boxes = game.save.boxes or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}

  local playerMon = Pokemon.new(game.data, "GOROCHU", 61,
    function() return 9 end)
  BattleState.stampOT(game.save, playerMon)
  playerMon.hp = playerMon.stats.hp
  game.save.party = { playerMon }

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = BattleState.newWild(game, "GOROCHU", 61)
  assert(shinySystem.forceMon(
    battle.enemy.mon, game.data.pokemon.GOROCHU),
    "could not prepare the initial shiny enemy")
  battle.enemy = BattleState.makeBattler(
    game.data, battle.enemy.mon, false, game.save)
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)

  for _ = 1, 900 do
    if battle.phase == "menu" then break end
    if battle.msgWaiting or battle.msgPrompt then
      U.tap(game, "a")
    else
      U.wait(1)
    end
  end
  assert(battle.phase == "menu", "Gorochu battle did not reach its menu")
  assert(game.stack:top() == battle, "Gorochu battle is not visible")
  game.input.pressQueue = {}
  for key in pairs(game.input.state) do game.input.state[key] = false end

  local timing = { 230, 100, 115, 105, 115, 300 }
  local receiptRows = {
    "scope=GOROCHU-2D-NORMAL-SHINY-CLASSIC",
    "identity=" .. expectedIdentity,
    "edition=" .. edition,
    "renderer=2D",
    "mod_root=" .. expectedModRoot,
    "mounted_mod_root=" .. mountedModRoot,
    "bound_files=" .. #boundFiles,
    "battle_count=1",
  }

  local function expectedRelative(side, variant)
    return ("assets/crystal_animated/%s/%s/1026/001.png")
      :format(side, variant)
  end

  -- This is the essential stale-selection repair for the QA lane: every
  -- transition calls the production resolver for the live mon and clears the
  -- old animation table.  The next real BattleState update attaches a fresh
  -- table, which is then read from the battler rather than from an old local.
  local function routeAndReset(battler, side, variant)
    local path, trueColor = Sprites.path(game.data, "GOROCHU", side, {
      mon = battler.mon, kind = "battle",
    })
    local relative = expectedRelative(side, variant)
    assert(type(path) == "string" and path:find(relative, 1, true),
      ("wrong %s/%s route: %s"):format(side, variant, tostring(path)))
    assert(trueColor == true,
      ("wrong trueColor contract for %s/%s"):format(side, variant))
    local selected = assert(crystal.selected[battler.mon],
      "production resolver did not select the live Gorochu")
    assert(selected.variant == variant and selected.side == side,
      "resolver selection metadata drifted")
    battler.__ascendantCrystalAnimation = nil
    return path
  end

  local function assertLiveState(battler, side, variant)
    local state = assert(battler.__ascendantCrystalAnimation,
      ("missing live %s/%s state"):format(side, variant))
    assert(state.dex == 1026 and state.species == "GOROCHU",
      "live state lost Gorochu identity")
    assert(state.side == side and state.variant == variant,
      "live state attached the wrong side or variant")
    assert(state.animated == true and #state.durations == #timing,
      "live state is static or has the wrong cadence length")
    for index, duration in ipairs(timing) do
      assert(state.durations[index] == duration,
        "Gorochu cadence drifted at frame " .. index)
    end
    assert(state.image and battler.sprite == state.image,
      "live animation image is not the battler's displayed sprite")
    local width, height = state.image:getDimensions()
    assert(width >= 16 and width <= 64 and height >= 16 and height <= 64,
      "trimmed Gorochu image escaped the reviewed 64px field")
    local minFilter, magFilter = state.image:getFilter()
    assert(minFilter == "nearest" and magFilter == "nearest",
      "Gorochu image is not using nearest-neighbour filtering")
    return state
  end

  local function reselectStage(playerVariant, enemyVariant)
    routeAndReset(battle.player, "back", playerVariant)
    routeAndReset(battle.enemy, "front", enemyVariant)
    U.wait(2)
    local playerState = assertLiveState(
      battle.player, "back", playerVariant)
    local enemyState = assertLiveState(
      battle.enemy, "front", enemyVariant)
    assert(playerState.frame == 1 and enemyState.frame == 1,
      "reselected Gorochu stage did not begin on frame one")
    assert(BattleState.resolveBattleScale(
      game.data, "back", nil, "GOROCHU") == 1,
      "Gorochu back escaped its native 1x scale")
    return playerState, enemyState
  end

  local function captureStage(id, playerVariant, enemyVariant,
      firstName, secondName)
    local playerState, enemyState = reselectStage(
      playerVariant, enemyVariant)
    local firstPlayerImage, firstEnemyImage =
      playerState.image, enemyState.image
    assert(U.shot(game, normalizedOutput .. "/" .. firstName),
      id .. " frame-A screenshot failed")

    local reachedThird = false
    for _ = 1, 180 do
      U.wait(1)
      -- Reacquire both live fields on every iteration.  Keeping the pointers
      -- from a prior normal/shiny/classic stage caused the rejected TEMP run.
      playerState = assertLiveState(battle.player, "back", playerVariant)
      enemyState = assertLiveState(battle.enemy, "front", enemyVariant)
      if playerState.frame == 3 and enemyState.frame == 3 then
        reachedThird = true
        break
      end
    end
    assert(reachedThird, id .. " did not reach synchronized frame three")
    assert(playerState.image ~= firstPlayerImage
        and enemyState.image ~= firstEnemyImage,
      id .. " changed its counter without changing both live images")
    assert(U.shot(game, normalizedOutput .. "/" .. secondName),
      id .. " frame-B screenshot failed")
    receiptRows[#receiptRows + 1] =
      ("stage=%s player=%s:1->3 enemy=%s:1->3")
        :format(id, playerVariant, enemyVariant)
  end

  captureStage("color-normal-back-shiny-front", "normal", "shiny",
    screenshotNames[1], screenshotNames[2])

  assert(shinySystem.forceMon(
    battle.player.mon, game.data.pokemon.GOROCHU),
    "could not make the player Gorochu shiny")
  battle.enemy.mon.shiny = nil
  battle.enemy.mon.dvs = {
    attack = 9, defense = 9, speed = 9, special = 9, hp = 0,
  }
  assert(shinySystem.isShiny(battle.player.mon),
    "player Gorochu did not become shiny")
  assert(not shinySystem.isShiny(battle.enemy.mon),
    "enemy Gorochu did not become normal")
  captureStage("color-shiny-back-normal-front", "shiny", "normal",
    screenshotNames[3], screenshotNames[4])

  -- Exercise the requested GAME-ORIGINAL sprite presentation while keeping
  -- the neutral full-colour screen pipeline. Switching the whole renderer to
  -- its green CLASSIC filter would hide whether the authored Gorochu card is
  -- actually the requested clean black-and-white artwork.
  setOption("pokemon_sprite_style", "original")
  game.save.options.colors = "redpp"
  PaletteFX.setMode("redpp")
  Pipelines.setLevel("voxel", 0)
  Pipelines.syncOptions(game.save.options)
  assert(PaletteFX.mode == "redpp" and Pipelines.level("voxel") == 0,
    "classic sprite stage escaped its neutral 2D display contract")
  captureStage("classic-grayscale", "grayscale", "grayscale",
    screenshotNames[5], screenshotNames[6])

  -- OverworldController may autosave while the disposable host constructs its
  -- background. That is allowed only inside this fresh QA identity; prove the
  -- resulting record is ours rather than weakening isolation or touching a
  -- player slot. Receipt creation occurs only after this final check.
  local diskAfter = SaveData.load(edition)
  assert(type(diskAfter) == "table"
      and diskAfter.player and diskAfter.player.name == "GORO QA",
    "focused Gorochu QA did not isolate its disposable autosave")
  receiptRows[#receiptRows + 1] = "disk_save_before=absent"
  receiptRows[#receiptRows + 1] = "disk_save_after=disposable-identity-only"
  receiptRows[#receiptRows + 1] = "screenshots=6/6"
  receiptRows[#receiptRows + 1] = "PASS"
  local result = assert(io.open(
    normalizedOutput .. "/driver_result.txt", "wb"),
    "could not create Gorochu 2D receipt")
  result:write(table.concat(receiptRows, "\n"), "\n")
  result:close()
  love.event.quit(0)
end
