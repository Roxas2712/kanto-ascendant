-- Real-LÖVE surface probe for Ascendant #252-279.
-- Resolves and decodes every normal/shiny front, back, party/follower and
-- Wilds/Voxel surface, constructs real BattleState battlers, opens real
-- Summary/Dex screens for the private-ID boundary species, and plays each cry.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local outputDir = os.getenv("RUNTIME_MATRIX_DIR")
    or "/tmp/kanto-ascendant-extended-species-runtime"
  -- #252-279 have no licensed/authoritative ROM-era fallback cards.  The
  -- guest contract therefore keeps their supplied static Crystal card when
  -- the global Crystal toggle is off; this QA profile verifies that choice
  -- explicitly instead of accidentally testing only the default option.
  local crystalEnabled = os.getenv("EXTENDED_SPECIES_CRYSTAL") ~= "0"
  game.mods.modOptions = game.mods.modOptions or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local options = game.mods.modOptions.kanto_ascendant
  options.pokemon_sprite_style = crystalEnabled and "crystal" or "legacy"
  options.dex_sprite_style = crystalEnabled and "crystal" or "original"
  options.kanto_crystal_art = crystalEnabled
  options.legend_art = crystalEnabled and "crystal" or "original"
  options.crystal_animation = crystalEnabled
  U.wait(45)

  local exports = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant, "Ascendant export missing")
  local runtime = assert(exports.extendedSpeciesRuntime,
    "extended species runtime missing")
  local shinySystem = assert(exports.shinySystem,
    "Ascendant shiny runtime missing")
  local matrix = runtime.matrix(game)
  local validation = runtime.validate(matrix)
  assert(validation.ok,
    "live runtime matrix failed: " .. runtime.encodeJson(validation.findings))

  local function writeImage(image, path, label)
    assert(image and image.getDimensions,
      label .. " did not yield a LÖVE Image")
    local width, height = image:getDimensions()
    -- Image:newImageData is not available for every hardware-backed LÖVE
    -- Image.  Draw through an actual canvas first, so this export also proves
    -- the renderer can present the resolved image rather than merely open it.
    local okData, data = pcall(function()
      local graphics = assert(love.graphics, "LÖVE graphics unavailable")
      local canvas = assert(graphics.newCanvas(width, height, { dpiscale = 1 }))
      local previous = graphics.getCanvas()
      graphics.push("all")
      graphics.setCanvas(canvas)
      graphics.clear(0, 0, 0, 0)
      graphics.setColor(1, 1, 1, 1)
      graphics.draw(image, 0, 0)
      graphics.setCanvas(previous)
      graphics.pop()
      local result = canvas:newImageData()
      canvas:release()
      return result
    end)
    assert(okData and data and data.encode,
      label .. " cannot be read back from the LÖVE renderer")
    local okEncode, encoded = pcall(data.encode, data, "png")
    assert(okEncode and encoded and encoded.getString,
      label .. " cannot be PNG-encoded by LÖVE")
    local directory = path:match("^(.*)/[^/]+$")
    if directory then os.execute('mkdir -p "' .. directory .. '"') end
    local out = assert(io.open(path, "wb"), "cannot write " .. path)
    out:write(encoded:getString())
    out:close()
  end

  local function loadImage(path, label, capturePath)
    assert(type(path) == "string" and path ~= "", label .. " has no path")
    local ok, image = pcall(love.graphics.newImage, path)
    assert(ok and image, label .. " cannot decode: " .. tostring(path))
    local w, h = image:getDimensions()
    assert(w > 0 and h > 0, label .. " has invalid dimensions")
    if capturePath then writeImage(image, capturePath, label) end
    return image
  end

  local Pokemon = require("src.pokemon.Pokemon")
  local BattleState = require("src.battle.BattleState")
  local Sound = require("src.core.Sound")
  local wilds = assert(exports.internalWilds and exports.internalWilds.exports,
    "bundled Wilds export missing")
  local animated = assert(wilds.animated, "Wilds animated runtime missing")
  local decoded, voxelCards, cries = 0, 0, 0

  for _, row in ipairs(matrix.rows) do
    local identity = runtime.bySpecies[row.species]
    assert(identity.sourceDex == row.sourceDex)
    for variant, surfaces in pairs(row.surfaces) do
      for _, key in ipairs({
        "battleEnemy", "battlePlayer", "dex", "summary", "box",
        "partyIcon", "follower", "wilds",
      }) do
        local capture = outputDir .. "/frames/" .. row.species:lower()
          .. "_" .. variant .. "_" .. key .. ".png"
        loadImage(surfaces[key].path,
          row.species .. " " .. variant .. " " .. key, capture)
        decoded = decoded + 1
      end
      local card = animated:getVoxelCard(
        row.sourceDex, "idle", "down", 1, variant)
      assert(card and card.status == "READY" and card.image,
        row.species .. " " .. variant
          .. " has no READY real voxel billboard: "
          .. tostring(card and card.status) .. " / "
          .. tostring(card and card.reason))
      local width, height = card.image:getDimensions()
      assert(width > 0 and height > 0,
        row.species .. " " .. variant .. " voxel card has invalid dimensions")
      writeImage(card.image, outputDir .. "/frames/" .. row.species:lower()
        .. "_" .. variant .. "_voxel.png",
        row.species .. " " .. variant .. " voxel")
      voxelCards = voxelCards + 1
    end

    for _, shiny in ipairs({ false, true }) do
      local mon = Pokemon.new(game.data, row.species, 30,
        function() return 8 end)
      if shiny then
        assert(shinySystem.forceMon(mon, game.data.pokemon[row.species]),
          row.species .. " could not enter a real shiny state")
        assert(shinySystem.isShiny(mon),
          row.species .. " shiny state was not retained")
      end
      local enemy = BattleState.makeBattler(game.data, mon, false, game.save)
      local player = BattleState.makeBattler(game.data, mon, true, game.save)
      assert(enemy.sprite and player.sprite,
        row.species .. " " .. (shiny and "shiny" or "normal")
          .. " failed real front/back BattleState construction")
    end

    local cry = Sound.playCry(game.data, row.species)
    assert(cry ~= nil, row.species .. " cry did not create a LÖVE Source")
    pcall(cry.stop, cry)
    cries = cries + 1
  end

  -- These two screens exercise the exact private-ID boundary in real UI
  -- constructors instead of merely checking their files.
  local SummaryMenu = require("src.ui.SummaryMenu")
  local DexEntryMenu = require("src.ui.DexEntryMenu")
  for _, species in ipairs({ "AZURILL", "WYNAUT" }) do
    local mon = Pokemon.new(game.data, species, 30, function() return 8 end)
    local summary = SummaryMenu.new(game, mon)
    local dex = DexEntryMenu.new(game, { species = species, forceOwned = true })
    assert(summary.sprite and dex.sprite,
      species .. " failed real Summary/Dex screen construction")
  end

  os.execute('mkdir -p "' .. outputDir .. '"')
  local reportPath = outputDir .. "/extended_species_runtime_matrix.json"
  local out = assert(io.open(reportPath, "wb"))
  matrix.qaProfile = {
    crystalEnabled = crystalEnabled,
    -- A static guest card remains intentional with the master toggle off;
    -- this is coverage of the setting branch, not a false claim of a Gen-I
    -- alternate art set that does not exist for #252-279.
    guestStaticPolicy = "retain-supplied-static-card",
    decodedSurfaces = decoded,
    readyVoxelCards = voxelCards,
    playableCries = cries,
  }
  out:write(runtime.encodeJson(matrix))
  out:close()
  print(("EXTENDED SPECIES REAL-DRIVER PASS: %d decoded, %d voxel, %d cries; %s")
    :format(decoded, voxelCards, cries, reportPath))
end
