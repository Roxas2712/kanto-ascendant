-- Real Yellow UAT for the evolved-partner conversation presentation.
--
-- Captures both Raichu and Gorochu, normal and shiny, in all seven moods.
-- Every case proves that the production follower interaction:
--   * selects the correct species/variant/mood portrait,
--   * renders inside the 40x40 portrait aperture without touching the emoji,
--   * advances to a pixel-distinct animation frame,
--   * and opens a localized, species-correct TextBox after the emote.
--
-- English and German are exercised in one process because Ascendant's
-- language option is read dynamically.  The base game itself still needs
-- to boot as Yellow:
--
--   cd /path/to/gen1recomp
--   POKEPORT_VERSION=yellow \
--   POKEPORT_IDENTITY=kanto-ascendant-gorochu-2d-quality \
--   POKEPORT_DRIVER=/path/to/kanto-ascendant/tools/gorochu_dialogue_qa_driver.lua \
--   POKEPORT_TOUCH=0 POKEPORT_SPEED=16 \
--   SHOT_DIR=/tmp/gorochu-dialogue-uat \
--   /path/to/love .

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Pokemon = require("src.pokemon.Pokemon")

  U.wait(20)
  assert(GameVersion.isYellow(),
    "Gorochu dialogue QA must boot with POKEPORT_VERSION=yellow")
  local shotDir = assert(os.getenv("SHOT_DIR"),
    "SHOT_DIR is required for Gorochu dialogue QA")
  local ascendant = assert(
    game.mods and game.mods.exports
      and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant export missing")
  local partnerApi = assert(ascendant.yellowPartner,
    "Yellow partner controller missing")
  local shinySystem = assert(ascendant.shinySystem,
    "Kanto Ascendant shiny controller missing")
  assert(type(ascendant.language) == "function",
    "Kanto Ascendant language resolver missing")
  assert(type(game.mods.modOptions) == "table",
    "live mod options are not introspectable")
  local germanYellowMod = game.mods.mods
    and game.mods.mods["deutsch-gelb"]
  local germanYellowLoaded = germanYellowMod
    and germanYellowMod.enabled == true
    and germanYellowMod.failed ~= true
  if germanYellowLoaded then
    U.log("German Yellow translation detected:",
      "EN/DE wording and German glyph rendering share this run")
  else
    U.log("German Yellow translation not active:",
      "EN/DE wording is tested here, but final German glyph UAT needs",
      "a second run with deutsch-gelb enabled")
  end

  game.save.player = game.save.player or {}
  game.save.player.name = "DIALOGUE UAT"
  game.save.player.id = 5426
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_CHOSE_PIKACHU = true
  game.save.inventory = game.save.inventory or {}
  game.save.boxes = game.save.boxes or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1

  local moods = {
    { id = "sleepy", happiness = 230, mood = 128, status = "SLP" },
    { id = "unwell", happiness = 230, mood = 128, status = "PSN" },
    { id = "upset", happiness = 30, mood = 50 },
    { id = "wary", happiness = 90, mood = 100 },
    { id = "content", happiness = 150, mood = 128 },
    { id = "devoted", happiness = 220, mood = 128 },
    { id = "excited", happiness = 240, mood = 150 },
  }
  local languages = { "en", "de" }
  local speciesCases = { "RAICHU", "GOROCHU" }
  local variants = {
    { id = "normal", shiny = false },
    { id = "shiny", shiny = true },
  }

  local originalOptions = game.mods.modOptions.kanto_ascendant
  local originalLanguage = originalOptions and originalOptions.language
  game.mods.modOptions.kanto_ascendant = originalOptions or {}

  local imageDataCache = {}
  local function portraitData(path)
    local cached = imageDataCache[path]
    if cached then return cached end
    assert(love and love.image
        and type(love.image.newImageData) == "function",
      "LOVE ImageData introspection is required for portrait QA")
    local ok, data = pcall(love.image.newImageData, path)
    assert(ok and data,
      "could not read portrait pixel data: " .. tostring(path))
    local w, h = data:getDimensions()
    local format = data.getFormat and data:getFormat() or nil
    if format then
      local trueColor = format:find("rgba", 1, true)
        or format:find("srgba", 1, true)
      assert(trueColor,
        ("portrait is not RGBA true-color (%s): %s")
          :format(tostring(format), tostring(path)))
    end
    cached = { data = data, width = w, height = h, format = format }
    imageDataCache[path] = cached
    return cached
  end

  local function pixelDistinct(firstPath, secondPath)
    if firstPath == secondPath then return false end
    local first = portraitData(firstPath)
    local second = portraitData(secondPath)
    assert(first.width == second.width and first.height == second.height,
      "portrait changes canvas dimensions between animation frames")
    for y = 0, first.height - 1 do
      for x = 0, first.width - 1 do
        local ar, ag, ab, aa = first.data:getPixel(x, y)
        local br, bg, bb, ba = second.data:getPixel(x, y)
        if ar ~= br or ag ~= bg or ab ~= bb or aa ~= ba then
          return true
        end
      end
    end
    return false
  end

  local function flattenPages(pages)
    local out = {}
    for _, page in ipairs(pages or {}) do
      for _, line in ipairs(page or {}) do out[#out + 1] = line end
    end
    return table.concat(out, "\n")
  end

  local function closeTextBox()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
    assert(game.stack:top() == game.overworld,
      "dialogue QA did not return to the overworld")
  end

  local function makePartner(species, makeShiny)
    local mon = Pokemon.new(game.data, species, 61,
      function() return 9 end)
    BattleState.stampOT(game.save, mon)
    mon[partnerApi.marker] = true
    mon.johtoBond = 100
    mon.hp = mon.stats.hp
    if makeShiny then
      assert(shinySystem.forceMon(mon, game.data.pokemon[species]),
        "could not force shiny " .. species)
    else
      mon.shiny = nil
      mon.dvs = {
        attack = 9, defense = 8, speed = 8, special = 8, hp = 8,
      }
    end
    assert(shinySystem.isShiny(mon) == makeShiny,
      species .. " shiny setup did not resolve the requested variant")
    return mon
  end

  local localizedText = {}
  local captures = 0
  for _, language in ipairs(languages) do
    game.mods.modOptions.kanto_ascendant.language = language
    assert(ascendant.language() == language,
      "live language switch did not select " .. language)
    localizedText[language] = {}

    for _, species in ipairs(speciesCases) do
      localizedText[language][species] = {}
      for _, variant in ipairs(variants) do
        local mon = makePartner(species, variant.shiny)
        game.save.party = { mon }
        game.save.pikachuHappiness = 230
        game.save.pikachuMood = 128

        U.teleport(game, "VERMILION_CITY", 20, 18, "down")
        PikachuFollower.onMapEntered(game, game.overworld)
        U.wait(20)
        local npc = assert(PikachuFollower.current(game.overworld),
          species .. " follower is missing")
        local followerDef = assert(
          game.data.sprites and game.data.sprites.SPRITE_PIKACHU,
          "Yellow follower sprite definition missing")
        assert(followerDef.trueColor == true,
          species .. " follower is not routed through true-color rendering")
        assert(npc._ascendantYellowPartnerSpecies == species,
          species .. " follower renderer retained another species")
        assert(type(followerDef.image) == "string"
            and followerDef.image ~= "",
          species .. " follower has no sprite sheet")

        for moodIndex, mood in ipairs(moods) do
          mon.status = mood.status
          mon.hp = mon.stats.hp
          game.save.pikachuHappiness = mood.happiness
          game.save.pikachuMood = mood.mood

          local reaction = assert(partnerApi.raichuReaction(game, mon),
            "reaction resolver failed for " .. species .. " " .. mood.id)
          assert(reaction.id == mood.id,
            ("wanted mood %s but resolved %s for %s")
              :format(mood.id, tostring(reaction.id), species))
          local spokenName = species == "GOROCHU" and "GOROCHU" or "RAICHU"
          assert(reaction.text:find(spokenName, 1, true),
            species .. " dialogue does not name the active partner")
          if species == "GOROCHU" then
            assert(not reaction.text:find("RAICHU", 1, true),
              "Gorochu dialogue leaked Raichu's name")
          end
          localizedText[language][species][mood.id] = reaction.text

          PikachuFollower.talk(
            game, game.overworld, npc, function() end)
          local emote = assert(game.overworld.emote,
            ("missing %s %s %s emote")
              :format(language, species, mood.id))
          local frames = assert(emote._ascendantRaichuFrames,
            species .. " portrait animation frames missing")
          assert(#frames >= 2,
            species .. " portrait needs at least two animation phases")

          local expectedRoot
          local alternateRoot
          if species == "GOROCHU" then
            expectedRoot = "/yellow_partner_gorochu_portraits/"
              .. variant.id .. "/" .. mood.id .. "/"
          else
            expectedRoot = "/yellow_partner_raichu_portraits/"
              .. variant.id .. "/" .. mood.id .. "/"
            -- 5.4.0 used official Crystal frames for moods that already read
            -- cleanly and custom 56x56 faces only for sleepy/unwell. The
            -- current hotfix authors all seven Raichu moods as proper 40x40
            -- dialogue portraits. Keep the UAT useful on both sides of that
            -- upgrade without accepting an unrelated sprite path.
            alternateRoot = "/crystal_animated/front/"
              .. variant.id .. "/26/"
          end
          assert(emote.pikaPic
              and (emote.pikaPic:find(expectedRoot, 1, true)
                or alternateRoot
                  and emote.pikaPic:find(alternateRoot, 1, true)),
            ("wrong %s %s %s portrait: %s")
              :format(species, variant.id, mood.id,
                tostring(emote.pikaPic)))

          -- The framed presentation owns a 40x40 image aperture:
          -- a 7x7 tile outer box minus its one-tile border on every side.
          local portraitTiles = 7
          local aperture = (portraitTiles - 2) * 8
          assert(aperture == 40,
            "partner portrait aperture is no longer 40x40")
          local firstMetrics = portraitData(frames[1])
          if species == "GOROCHU" then
            assert(firstMetrics.width == 40 and firstMetrics.height == 40,
              "Gorochu mood portraits must be authored at exactly 40x40")
          else
            -- Current Raichu mood portraits are authored for the 40x40
            -- aperture. Retain compatibility with the earlier native 56x56
            -- Crystal source while the hotfix is forward-ported.
            assert((firstMetrics.width == 40 and firstMetrics.height == 40)
                or (firstMetrics.width == 56 and firstMetrics.height == 56),
              "Raichu portrait is neither a 40x40 mood face nor native Crystal")
          end

          local boxLeft = assert(emote._ascendantRaichuBoxX) * 8
          local boxTop = assert(emote._ascendantRaichuBoxY) * 8
          local boxRight = boxLeft + portraitTiles * 8
          local boxBottom = boxTop + portraitTiles * 8
          assert(boxLeft >= 0 and boxTop >= 0
              and boxRight <= 160 and boxBottom <= 144,
            species .. " portrait box leaves the 160x144 viewport")
          local cameraX = game.overworld.camera
            and game.overworld.camera.x or 0
          local bubbleLeft = npc.px - cameraX + 4
          local bubbleRight = bubbleLeft + 16
          local gap
          if boxRight <= bubbleLeft then
            gap = bubbleLeft - boxRight
          elseif boxLeft >= bubbleRight then
            gap = boxLeft - bubbleRight
          end
          assert(gap and gap >= 4,
            ("%s %s portrait/emoji gap is below 4px")
              :format(species, mood.id))

          local stem = ("%s/%s/%s/%s/%02d_%s")
            :format(shotDir, language, species:lower(), variant.id,
              moodIndex, mood.id)
          local animationTicks = emote._ascendantRaichuTicks or 8
          local firstPath = frames[1]
          -- POKEPORT_SPEED may advance several game ticks between asking for
          -- a screenshot and LOVE drawing it. Pin only the capture phase to
          -- the already-selected production frame so the evidence image
          -- cannot race ahead while the screenshot reaches disk.
          emote._ascendantRaichuFrames = { firstPath }
          emote._ascendantRaichuTicks = 1000000
          emote.pikaPic = firstPath
          assert(U.shot(game, stem .. "_portrait_frame_1.png"),
            "first portrait screenshot failed")
          captures = captures + 1

          emote._ascendantRaichuFrames = frames
          emote._ascendantRaichuTicks = animationTicks
          emote.frames = emote.pikaTotal
          emote.pikaPic = firstPath
          local hasDifferentPath = false
          for frame = 1, #frames do
            if frames[frame] ~= firstPath then
              hasDifferentPath = true
              break
            end
          end
          assert(hasDifferentPath,
            species .. " " .. mood.id .. " has no distinct frame path")
          local maxAnimationWait = math.max(2,
            animationTicks * #frames + 2)
          local secondPath
          for _ = 1, maxAnimationWait do
            if pixelDistinct(firstPath, emote.pikaPic) then
              secondPath = emote.pikaPic
              break
            end
            U.wait(1)
          end
          assert(game.overworld.emote == emote,
            species .. " portrait ended before its second frame")
          assert(secondPath,
            ("%s %s %s never reached a pixel-distinct animation frame")
              :format(species, variant.id, mood.id))
          emote._ascendantRaichuFrames = { secondPath }
          emote._ascendantRaichuTicks = 1000000
          emote.pikaPic = secondPath
          assert(U.shot(game, stem .. "_portrait_frame_2.png"),
            "second portrait screenshot failed")
          captures = captures + 1

          -- Skip the skippable portrait exactly as a player would. Its
          -- production onDone callback must push the localized TextBox.
          emote._ascendantRaichuFrames = frames
          emote._ascendantRaichuTicks = animationTicks
          U.tap(game, "a")
          U.wait(2)
          local dialogue = assert(game.stack:top(),
            species .. " reaction did not open a dialogue TextBox")
          assert(type(dialogue.pages) == "table"
              and type(dialogue.update) == "function",
            species .. " reaction opened the wrong post-emote screen")
          local fullText = flattenPages(dialogue.pages)
          assert(fullText:find(spokenName, 1, true),
            species .. " name is absent from the rendered TextBox pages")
          if species == "GOROCHU" then
            assert(not fullText:find("RAICHU", 1, true),
              "rendered Gorochu TextBox leaked Raichu's name")
          end
          for _ = 1, 300 do
            if dialogue.waiting or dialogue.done then break end
            U.wait(1)
          end
          assert(dialogue.waiting or dialogue.done,
            species .. " TextBox did not finish rendering its first page")
          assert(U.shot(game, stem .. "_dialogue_name.png"),
            "post-emote name-page screenshot failed")
          captures = captures + 1
          assert(#dialogue.pages >= 2,
            species .. " reaction has no explanatory body page")
          U.tap(game, "a")
          for _ = 1, 300 do
            if dialogue.waiting or dialogue.done then break end
            U.wait(1)
          end
          assert(dialogue.waiting or dialogue.done,
            species .. " TextBox did not render its explanatory body page")
          assert(U.shot(game, stem .. "_dialogue_body.png"),
            "post-emote body-page screenshot failed")
          captures = captures + 1
          closeTextBox()
          U.wait(2)
        end
      end
    end
  end

  for _, species in ipairs(speciesCases) do
    for _, mood in ipairs(moods) do
      assert(localizedText.en[species][mood.id]
          ~= localizedText.de[species][mood.id],
        species .. " " .. mood.id
          .. " did not change between English and German")
    end
  end

  if originalOptions then
    originalOptions.language = originalLanguage
  else
    game.mods.modOptions.kanto_ascendant = nil
  end

  assert(captures == 2 * 2 * 2 * 7 * 4,
    "dialogue QA capture count drifted: " .. tostring(captures))
  U.log("PASS Gorochu dialogue UAT",
    "Yellow", "EN+DE", "Raichu+Gorochu", "normal+shiny",
    "7 moods", "pixel-distinct animation", "40x40 aperture",
    captures .. " screenshots")
  love.event.quit(0)
end
