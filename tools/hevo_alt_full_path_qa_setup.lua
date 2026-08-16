-- Package-only immutable ALT-save prerequisite for the three complete HEVO
-- traversal drivers.  The source is the exact read-only BLITZ save copied by
-- the final same-hash orchestrator.  Loading it through Game:restoreSave is
-- the migration proof; this setup changes only the documented character,
-- field-move, discovery and start-position prerequisites required to exercise
-- the already-authored physical RED/BLUE/GREEN input drivers.
return function(game)
  local utilPath = assert(os.getenv("KA_TEST_UTIL"),
    "KA_TEST_UTIL packaged harness path required")
  local U = dofile(utilPath)
  local SaveData = require("src.core.SaveData")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Bag = require("src.inventory.Bag")

  local edition = tostring(assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION required")):lower()
  local renderer = tostring(assert(os.getenv("QA_RENDERER"),
    "QA_RENDERER required")):upper()
  local identity = assert(os.getenv("POKEPORT_IDENTITY"),
    "isolated POKEPORT_IDENTITY required")
  assert(renderer == "2D" or renderer == "FULL",
    "QA_RENDERER must be 2D or FULL")
  local characterByEdition = { red = "RED", blue = "BLUE", yellow = "GREEN" }
  local character = assert(characterByEdition[edition],
    "HEVO ALT setup requires Red, Blue or Yellow")
  local expectedIdentity = ("ka65-final-hevo-%s-alt-%s")
    :format(character:lower(), renderer:lower())
  assert(identity == expectedIdentity,
    "refusing non-orchestrated HEVO ALT identity " .. tostring(identity))
  assert(GameVersion.get() == edition, "HEVO ALT edition mismatch")
  assert(os.getenv("KA_PACKAGE_GATE") == "1",
    "refusing HEVO ALT setup outside the immutable package gate")

  local harnessRoot = assert(os.getenv("GEN1RECOMP_DIR"),
    "GEN1RECOMP_DIR package harness required")
  local source = assert(os.getenv("KA_SOURCE_SAVE"),
    "KA_SOURCE_SAVE required")
  local sourceSha = assert(os.getenv("KA_SOURCE_SAVE_SHA256"),
    "KA_SOURCE_SAVE_SHA256 required")
  local gateSha = assert(os.getenv("KA_PACKAGE_GATE_RECEIPT_SHA256"),
    "KA_PACKAGE_GATE_RECEIPT_SHA256 required")
  local expectedSource = harnessRoot
    .. "/immutable_inputs/source_snapshot/slot7_original_readonly.lua"

  local function validSha(value)
    return type(value) == "string" and #value == 64
      and value:match("^[0-9a-f]+$") ~= nil
  end
  local function fileSha256(path)
    local file = assert(io.open(path, "rb"),
      "immutable HEVO source cannot be opened")
    local body = file:read("*a")
    file:close()
    local digest = love.data.hash("sha256", body)
    if type(digest) == "userdata" and digest.getString then
      digest = digest:getString()
    end
    return love.data.encode("string", "hex", digest):lower()
  end

  assert(source == expectedSource,
    "refusing HEVO ALT source outside materialized immutable inputs")
  assert(not source:find("Application Support/pokemon-love2d/saves", 1, true),
    "refusing the player's live save directory")
  assert(validSha(sourceSha) and validSha(gateSha),
    "HEVO ALT source/package receipt SHA is malformed")
  assert(fileSha256(source) == sourceSha,
    "orchestrator-pinned HEVO ALT source SHA drifted")
  for _, path in ipairs({ harnessRoot, utilPath, source }) do
    assert(path:sub(1, 1) == "/"
        and not path:find(".worktrees", 1, true)
        and not path:find("/Documents/Recompile/", 1, true),
      "source/worktree path is not package evidence: " .. path)
  end
  local installed = assert(game.mods and game.mods.mods
      and game.mods.mods.kanto_ascendant,
    "installed Authority package missing during HEVO ALT setup")
  local installedPath = tostring(installed.path or "")
  assert(installedPath ~= ""
      and not installedPath:find(".worktrees", 1, true)
      and not installedPath:find("/Documents/Recompile/", 1, true)
      and not installedPath:find("/tests/", 1, true)
      and not installedPath:find("/tools/", 1, true),
    "source/worktree path is not installed-package evidence: "
      .. installedPath)

  local loaded = assert(loadfile(source))()
  assert(type(loaded) == "table" and loaded.version == "red"
      and loaded.player and loaded.player.name == "BLITZ"
      and loaded.flags and loaded.flags.EVENT_BEAT_CHAMPION_RIVAL == true
      and loaded.modData and loaded.modData.kanto_ascendant,
    "immutable BLITZ source lost its migration shape")
  local sourceBucket = loaded.modData.kanto_ascendant
  assert(type(sourceBucket.hevo_run) == "table"
      and type(sourceBucket.hevo_persistent) == "table",
    "immutable BLITZ source lost its pre-final HEVO buckets")

  loaded.version = edition
  loaded.player.name = character == "GREEN" and "CASEY" or character
  local rivals = {
    RED = { rival = "BLUE", third = "GREEN" },
    BLUE = { rival = "GREEN", third = "RED" },
    GREEN = { rival = "RED", third = "BLUE" },
  }
  loaded.player.rival = rivals[character].rival
  loaded.flags = loaded.flags or {}
  loaded.flags.EVENT_GOT_STARTER = true
  loaded.flags.EVENT_GOT_POKEDEX = true
  loaded.flags.EVENT_BEAT_CHAMPION_RIVAL = true
  loaded.repelSteps = 9999
  loaded.options = SaveData.loadOptions()
  loaded.options.textSpeed = 1
  loaded.options.pipelines = loaded.options.pipelines or {}
  loaded.options.pipelines.voxel = renderer == "FULL" and 1 or 0
  loaded.options.tilt = 0
  loaded.options.modOptions = loaded.options.modOptions or {}
  loaded.options.modOptions.kanto_ascendant = {
    ascendant_qol = true,
    qol_easy_interactions = true,
    qol_location_banners = false,
    living_world_enabled = false,
    enable_aggressive = false,
    living_world_random_encounters = false,
  }
  loaded.meta = SaveData.buildMeta(assert(game.modStatus and game.modStatus.loaded,
    "active HEVO ALT package closure missing"), loaded.meta)

  local slot
  if character == "RED" then
    slot = "slothevo65redinput"
    loaded.player.map, loaded.player.x, loaded.player.y, loaded.player.facing =
      "ROUTE_22", 35, 2, "up"
    loaded.lastHeal = { map = "VIRIDIAN_CITY", x = 19, y = 17 }
    loaded.lastOutdoor = { id = "ROUTE_22", x = 35, y = 2 }
    loaded.flags.KA_HEVO_FISSURE_DISCOVERED_RED = true
    local mon = Pokemon.new(game.data, "BLASTOISE", 55)
    mon.moves = {
      { id = "SURF", pp = 15 }, { id = "STRENGTH", pp = 15 },
      { id = "BITE", pp = 25 }, { id = "HYDRO_PUMP", pp = 5 },
    }
    loaded.party = { mon }
    loaded.inventory = loaded.inventory or {}
    loaded.inventory.SOULBADGE, loaded.inventory.RAINBOWBADGE = 1, 1
  elseif character == "BLUE" then
    slot = "slothevo65bluepure"
    loaded.player.map, loaded.player.x, loaded.player.y, loaded.player.facing =
      "ROUTE_24", 10, 4, "up"
    loaded.lastHeal = { map = "CERULEAN_CITY", x = 24, y = 2 }
    loaded.lastOutdoor = { id = "ROUTE_24", x = 10, y = 4 }
    loaded.flags.EVENT_BEAT_MISTY = true
    loaded.flags.KA_HEVO_FISSURE_DISCOVERED_BLUE = true
    local mon = Pokemon.new(game.data, "MEW", 30)
    mon.nickname = "LOTSE"
    mon.moves = {
      { id = "FLASH", pp = 15 }, { id = "STRENGTH", pp = 15 },
      { id = "SURF", pp = 15 },
    }
    loaded.party = { mon }
    loaded.inventory = loaded.inventory or {}
    loaded.inventory.BOULDERBADGE = true
    loaded.inventory.RAINBOWBADGE = true
    loaded.inventory.SOULBADGE = true
    sourceBucket.johto_signals = sourceBucket.johto_signals or {}
    sourceBucket.johto_signals.earlyJohto = {
      version = 2, oakCallShown = true, oakReminderShown = true,
      pokedexSteps = 0,
    }
  else
    slot = "slothevo65greenrelease"
    loaded.player.map, loaded.player.x, loaded.player.y, loaded.player.facing =
      "ROUTE_3", 41, 4, "up"
    loaded.lastHeal = { map = "PEWTER_CITY", x = 35, y = 17 }
    loaded.lastOutdoor = { id = "ROUTE_3", x = 41, y = 4 }
    loaded.flags.EVENT_BEAT_BROCK = true
    loaded.flags.EVENT_BEAT_MISTY = true
    loaded.flags.EVENT_GOT_HM01 = true
    loaded.flags.KA_HEVO_FISSURE_DISCOVERED_GREEN = true
    local mon = Pokemon.new(game.data, "BULBASAUR", 20)
    mon.moves = {
      { id = "CUT", pp = assert(game.data.moves.CUT).pp },
      { id = "TACKLE", pp = assert(game.data.moves.TACKLE).pp },
    }
    loaded.party = { mon }
    assert(Bag.add(loaded, "CASCADEBADGE", 1, game.data),
      "could not add GREEN's legal Cascade Badge")
    assert(Bag.add(loaded, "HM_CUT", 1, game.data),
      "could not add GREEN's narratively legal HM01")
  end

  assert(SaveData.setActiveSlot(edition, slot) == slot,
    "could not reserve the native HEVO ALT slot")
  game:restoreSave(loaded, false)
  U.wait(24)
  local api = assert(game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "HEVO ALT setup cannot reach installed Authority exports")
  local characters = assert(api.extendedCharacters,
    "HEVO ALT setup cannot select an extended character")
  local selected = characters.select(character)
  characters.refreshVisuals(game)
  assert(selected.player_character == character
      and selected.rival_character == rivals[character].rival
      and selected.third_character == rivals[character].third,
    "HEVO ALT setup selected the wrong character matrix")
  local bucket = assert(game.save.modData.kanto_ascendant)
  bucket.onboarding = type(bucket.onboarding) == "table"
      and bucket.onboarding or {}
  bucket.onboarding.shown = true
  game.save.qaHevoAltOrigin = {
    version = 1,
    variant = "ALT",
    kind = edition == "red" and "immutable-blitz-save"
      or "immutable-blitz-cross-edition-clone",
    sourceSha256 = sourceSha,
    packageGateReceiptSha256 = gateSha,
    playerCharacter = character,
    renderer = renderer,
  }
  assert(game:writeSave(),
    "could not persist HEVO ALT prerequisite through native SAVE")
  local verified = assert(SaveData.load(edition),
    "could not reload HEVO ALT prerequisite")
  local origin = assert(verified.qaHevoAltOrigin,
    "HEVO ALT prerequisite lost its immutable origin receipt")
  assert(origin.sourceSha256 == sourceSha
      and origin.packageGateReceiptSha256 == gateSha
      and origin.playerCharacter == character
      and origin.renderer == renderer,
    "HEVO ALT prerequisite changed its immutable origin receipt")
  local verifiedBucket = assert(verified.modData.kanto_ascendant)
  assert(type(verifiedBucket.hevo_run) == "table"
      and type(verifiedBucket.hevo_persistent) == "table",
    "real restore did not retain/migrate the historical HEVO buckets")

  U.log(("HEVO ALT PACKAGE SETUP PASS edition=%s character=%s renderer=%s source=%s")
    :format(edition, character, renderer, sourceSha))
  love.event.quit(0)
end
