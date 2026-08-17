-- Extended Character Selection.
--
-- Character identity deliberately lives apart from the editable player and
-- rival names.  This phase only establishes the save-safe identities and the
-- New Game choice plus Phase-3/4 visual and rival presentation stay save-local.
-- The existing OPP_RIVAL battle role remains authoritative for starter
-- branches and story flags. Identity-specific party progressions are layered
-- separately by rival_teams.lua so presentation remains save-safe here.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local dialogue = assert(opts.dialogue, "character dialogue data is required")

  local M = {}
  local GameVersion = require("src.core.GameVersion")
  local trainerVoxelPortraits = opts.trainerVoxelPortraits
  local frlgTrainerPack = opts.frlgTrainerPack
  local voxelRenderer = opts.voxelRenderer
  local SAVE_KEY = "extended_characters"
  local DERIVED = "save/mod-derived/" .. tostring(mod.id or "kanto_ascendant")
    .. "/characters/"
  local SELECTION_ORDER = { "GREEN", "BLUE", "RED" }
  local PRE_NAME_PLACEHOLDER = "???"
  -- TrainerCard draws the edition-native 56x56 canvas at (104, 4).  That is
  -- fine for the much smaller opaque area of the original Gen-I portrait,
  -- but KASC's complete Red/Blue/Green figures reach the bottom of their
  -- canvas and consequently paint over the patterned right/bottom frame.
  -- Rows/columns 0 and 7 are the frame itself; this is the exact 6x6-tile
  -- white interior reserved for the player picture.
  local TRAINER_CARD_PROFILE_SAFE_RECT = { x = 104, y = 8, w = 48, h = 48 }
  local TRAINER_CARD_LEADER_FACES =
    "assets/trainer_card/kasc_leader_faces.png"

  local CHARACTERS = {
    RED = {
      id = "RED", canonicalName = "RED", gender = "MALE",
      defaultPlayerName = "RED", defaultRivalName = "BLUE",
      defaultNames = { player = "RED", rival = "BLUE" }, palette = "RED",
      visuals = {
        overworld = { sprite = "SPRITE_RED", status = "final" },
        bike = { sprite = "SPRITE_RED_BIKE", status = "final" },
        surf = { sprite = "SPRITE_SEEL", status = "shared-final" },
        fishing = { id = "red", status = "final" },
        battleBack = {
          path = DERIVED .. "red_back.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/red_back.png",
        },
        front = {
          path = DERIVED .. "red_front.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/red_voxel_front.png",
        },
        trainerCard = {
          path = DERIVED .. "red_front.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/red_voxel_front.png",
        },
        hallOfFame = {
          path = DERIVED .. "red_front.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/red_voxel_front.png",
        },
        credits = {
          path = DERIVED .. "red_front.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/red_voxel_front.png",
        },
        special = {
          path = DERIVED .. "red_front.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/red_voxel_front.png",
        },
        rivalPortrait = {
          path = DERIVED .. "red_front.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/red_voxel_front.png",
        },
      },
    },
    BLUE = {
      id = "BLUE", canonicalName = "BLUE", gender = "MALE",
      defaultPlayerName = "BLUE", defaultRivalName = "GREEN",
      defaultNames = { player = "BLUE", rival = "GREEN" }, palette = "BLUE",
      visuals = {
        overworld = { sprite = "SPRITE_BLUE", status = "final" },
        bike = { sprite = "SPRITE_RED_BIKE", status = "dev-fallback", fallback = "RED_BIKE" },
        surf = { sprite = "SPRITE_SEEL", status = "shared-final" },
        fishing = { id = "red", status = "dev-fallback", fallback = "RED_FISHING" },
        battleBack = { path = "assets/characters/blue_back.png", status = "final" },
        front = {
          path = DERIVED .. "blue_rival.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/blue_front.png",
        },
        trainerCard = {
          path = DERIVED .. "blue_rival.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/blue_front.png",
        },
        hallOfFame = {
          path = DERIVED .. "blue_rival.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/blue_front.png",
        },
        credits = {
          path = DERIVED .. "blue_rival.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/blue_front.png",
        },
        intro = {
          path = DERIVED .. "blue_rival.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/blue_front.png",
        },
        special = {
          path = DERIVED .. "blue_rival.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/blue_front.png",
        },
        rivalPortrait = {
          path = DERIVED .. "blue_rival.png", status = "final",
          fallbackPath = "assets/characters/crystal_chars/blue_front.png",
        },
      },
    },
    GREEN = {
      id = "GREEN", canonicalName = "GREEN", gender = "FEMALE",
      defaultPlayerName = "GREEN", defaultRivalName = "RED",
      defaultNames = { player = "GREEN", rival = "RED" }, palette = "GREEN",
      visuals = {
        overworld = { sprite = "SPRITE_KA_GREEN", status = "final" },
        bike = { sprite = "SPRITE_RED_BIKE", status = "dev-fallback", fallback = "RED_BIKE" },
        surf = { sprite = "SPRITE_SEEL", status = "shared-final" },
        fishing = { id = "red", status = "dev-fallback", fallback = "RED_FISHING" },
        battleBack = { path = "assets/characters/green_back.png", status = "final" },
        front = { path = "assets/characters/green_front.png", status = "final" },
        trainerCard = { path = "assets/characters/green_front.png", status = "final" },
        hallOfFame = { path = "assets/characters/green_front.png", status = "final" },
        credits = { path = "assets/characters/green_front.png", status = "final" },
        intro = { path = "assets/characters/green_front.png", status = "final" },
        special = { path = "assets/characters/green_front.png", status = "final" },
        -- Keep the compact Gen-I portrait for cards/credits, but use Casey's
        -- clean full-colour 64px portrait in the live rival battle slot.
        rivalPortrait = {
          path = "assets/characters/crystal_chars/green_front.png",
          status = "final",
        },
      },
    },
  }

  -- The default complete skin family. Keeping it outside CHARACTERS leaves
  -- the original Ascendant/Gen-I assets byte-for-byte available as the
  -- explicit ASCENDANT CHARS menu alternative, while the resolver can switch
  -- every visual state atomically -- including bike and fishing.
  local CRYSTAL_VISUALS = {}
  local SELECTOR_HD_BOUNDS = {
    RED = { x = 41, y = 6, w = 46, h = 116 },
    GREEN = { x = 37, y = 6, w = 54, h = 116 },
    BLUE = { x = 41, y = 6, w = 46, h = 116 },
  }
  for _, id in ipairs({ "RED", "GREEN", "BLUE" }) do
    local stem = id:lower()
    local root = "assets/characters/crystal_chars/" .. stem
    CRYSTAL_VISUALS[id] = {
      overworld = { sprite = "SPRITE_KA_CRYSTAL_" .. id .. "_WALK", status = "final" },
      bike = { sprite = "SPRITE_KA_CRYSTAL_" .. id .. "_BIKE", status = "final" },
      fishing = { sprite = "SPRITE_KA_CRYSTAL_" .. id .. "_FISH", status = "final" },
      battleBack = { path = root .. "_back.png", status = "final" },
      front = { path = root .. "_front.png", status = "final" },
      voxelFront = { path = root .. "_voxel_front.png", status = "final" },
      selectorHd = {
        path = root .. "_voxel_front_hd.png", status = "final",
        bounds = SELECTOR_HD_BOUNDS[id],
      },
      trainerCard = { path = root .. "_front.png", status = "final" },
      hallOfFame = { path = root .. "_front.png", status = "final" },
      credits = { path = root .. "_front.png", status = "final" },
      intro = { path = root .. "_front.png", status = "final" },
      special = { path = root .. "_front.png", status = "final" },
      rivalPortrait = { path = root .. "_front.png", status = "final" },
    }
  end
  -- Public packages do not ship Nintendo's FRLG Red front. CRYSTAL HD uses
  -- the bundled, independently authored Red standing front for its compact
  -- front-facing surfaces. ORIGINAL remains the edition-native Gen-I image
  -- generated from the user's own ROM below in CHARACTERS. The HD selector,
  -- throw sequence and staged-3D standee remain separate and untouched.
  for _, state in ipairs({
    "front", "trainerCard", "hallOfFame", "credits", "intro", "special",
    "rivalPortrait",
  }) do
    CRYSTAL_VISUALS.RED[state] = {
      path = "assets/characters/crystal_chars/red_voxel_front.png",
      status = "final", trueColor = true,
    }
  end
  local MATRIX = {
    RED = { player_character = "RED", rival_character = "BLUE", third_character = "GREEN" },
    BLUE = { player_character = "BLUE", rival_character = "GREEN", third_character = "RED" },
    GREEN = { player_character = "GREEN", rival_character = "RED", third_character = "BLUE" },
  }

  local LEGACY = {
    version = 1, enabled = false,
    player_character = "RED", rival_character = "BLUE", third_character = "GREEN",
  }

  local activeGame
  local refreshVisuals = function() end

  local function trainerPortraitStyle(game)
    local saved = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
      and game.save.options.modOptions[mod.id].trainer_portrait_style
    local style = saved
    if style == nil and mod.options and type(mod.options.get) == "function" then
      style = mod.options:get("trainer_portrait_style")
    end
    if style == "ascendant" then return "crystal_hd" end
    if style == "frlg" then return "original" end
    if style == "original" or style == "crystal_hd" then return style end
    return "crystal_hd"
  end

  local function whiteUiPalette(game, name)
    local P = require("src.render.PaletteFX")
    local palette = P.pal(game.data, name or "MEWMON")
    if not palette then return nil end
    return { { 255, 255, 255 }, palette[2], palette[3], palette[4] }
  end

  local function whiteUiZones(zones)
    if type(zones) ~= "table" then return zones end
    local result = {}
    for index, zone in ipairs(zones) do
      local copy = {}
      for key, value in pairs(zone) do copy[key] = value end
      if type(zone.colors) == "table" and zone.colors[1] then
        copy.colors = {
          { 255, 255, 255 }, zone.colors[2], zone.colors[3], zone.colors[4],
        }
      end
      result[index] = copy
    end
    return result
  end

  local function copy(value)
    local out = {}
    for key, child in pairs(value) do out[key] = child end
    return out
  end

  local function runtimePath(path)
    if path and path:sub(1, 5) == "save/" then return path end
    return path and (mod.path .. "/" .. path) or nil
  end

  -- AssetTransform normally creates the edition-native Red/Blue pictures
  -- before gameplay starts. A damaged or incomplete imported cache must not
  -- hand a missing save path to a renderer: retain the selected identity and
  -- fail visibly safe to its bundled Crystal sibling. Headless validation has
  -- no filesystem backend, so it keeps the inspectable derived-path contract.
  local function runtimeVisualPath(visual)
    if type(visual) ~= "table" then return nil end
    local path = visual.path
    if type(path) ~= "string" then return nil end
    if path:sub(1, 5) ~= "save/" then return runtimePath(path) end
    local fs = love and love.filesystem
    if not (fs and type(fs.getInfo) == "function") then
      return runtimePath(path)
    end
    local okAssets, Assets = pcall(require, "src.render.Assets")
    if okAssets and Assets and type(Assets.exists) == "function" then
      local ok, exists = pcall(Assets.exists, path)
      if ok and exists == true then return runtimePath(path) end
    end
    return runtimePath(visual.fallbackPath)
  end

  local APPROVED_OAK_INTRO = {
    low = "assets/characters/frlg_trainers/professor_oak_voxel_front_v1.png",
    hd = "assets/characters/frlg_trainers/professor_oak_voxel_front_hd_v1.png",
    version = "v1",
    bounds = { x = 30, y = 7, w = 68, h = 115 },
  }

  local function loadTrueColorImage(path)
    if not (path and love and love.graphics) then return nil end
    local Assets = require("src.render.Assets")
    local ok, value = pcall(love.graphics.newImage, Assets.resolve(path))
    if not (ok and value) then return nil end
    if value.setFilter then value:setFilter("nearest", "nearest") end
    return value
  end

  local function installApprovedOakIntro(speech)
    if not speech then return end
    local low = loadTrueColorImage(runtimePath(APPROVED_OAK_INTRO.low))
    local hd = loadTrueColorImage(runtimePath(APPROVED_OAK_INTRO.hd))
    if low then
      speech.oakPic = low
      speech.oakTrueColor = true
      speech.__kantoAscendantOakApproved = {
        schema = "ka-approved-oak-intro/v1",
        version = APPROVED_OAK_INTRO.version,
        source = APPROVED_OAK_INTRO.low,
      }
    end
    if hd then
      local width, height = hd:getDimensions()
      local bounds = APPROVED_OAK_INTRO.bounds
      speech.__kantoAscendantOakHdPortraits =
        speech.__kantoAscendantOakHdPortraits or {}
      speech.__kantoAscendantOakHdPortraits.oak = {
        image = hd,
        bounds = bounds,
        quad = love.graphics.newQuad(bounds.x, bounds.y, bounds.w, bounds.h,
          width, height),
        character = "OAK",
        sourcePath = APPROVED_OAK_INTRO.hd,
        approvedVersion = APPROVED_OAK_INTRO.version,
      }
    end
  end

  local function normalizedId(id, fallback)
    id = tostring(id or ""):upper()
    return CHARACTERS[id] and id or fallback
  end

  -- Read-only normalization means merely loading an older save never changes
  -- it.  Only an explicit New Game answer writes this feature's record.
  local function resolve(raw)
    raw = type(raw) == "table" and raw or {}
    local state = copy(LEGACY)
    state.version = math.max(1, math.floor(tonumber(raw.version) or 1))
    state.enabled = raw.enabled == true
    state.player_character = normalizedId(raw.player_character, "RED")
    state.rival_character = normalizedId(raw.rival_character, "BLUE")
    state.third_character = normalizedId(raw.third_character, "GREEN")
    return state
  end

  local function text(english, german)
    return i18n and i18n.text(english, german) or english
  end

  local function pair(value)
    return value and text(value[1], value[2]) or nil
  end

  local function displayName(character)
    local row = dialogue.selection[normalizedId(character, "RED")]
    return pair(row and row.label) or M.definition(character).canonicalName
  end

  function M.displayName(character)
    return displayName(character)
  end

  function M.selectionLabel(character)
    -- Identity and the editable player name are separate.  Oak may show the
    -- canonical hero identity to non-name consumers without pre-empting the
    -- naming screen that follows the choice.
    return displayName(character)
  end

  function M.preNamingName()
    -- The selector already knows portrait, pronouns and family relationship,
    -- but its three text rows are player-name slots.  They must stay unknown
    -- through back/re-entry/reload and every failed selection/name write; the
    -- real naming screens are the sole authority that reveal a chosen name.
    return PRE_NAME_PLACEHOLDER
  end

  function M.selectionVisual(character)
    -- New Game happens before a save-specific field style has any useful
    -- meaning.  More importantly, an old persisted ASCENDANT CHARS value must
    -- never downgrade Oak's selector to the compact Gen-I portraits again.
    -- Oak's selector uses the native 128px standing masters.  They are drawn
    -- after the 160x144 canvas has been presented (see render.hud below), so
    -- no 128 -> 64 reduction can throw away faces, clothing or hard outlines.
    -- The 2D battle fronts remain separate FRLG/Casey art.
    local id = normalizedId(character, "RED")
    -- ORIGINAL is an explicit portrait-family choice, unlike the old field
    -- style. Every selectable identity owns a separate compact base pair;
    -- CRYSTAL HD keeps the approved 128px standing selector masters.
    if trainerPortraitStyle(activeGame) == "original" then
      local visual = copy(CHARACTERS[id].visuals.front)
      visual.character, visual.state, visual.style = id, "selectorHd", "original"
      return visual
    end
    return copy(CRYSTAL_VISUALS[id].selectorHd)
  end

  function M.definitions()
    return CHARACTERS
  end

  function M.definition(character)
    return CHARACTERS[normalizedId(character, "RED")]
  end

  function M.getCharacterGender(character)
    return M.definition(character).gender
  end

  function M.characterStyle()
    local ok, style = pcall(mod.options.get, mod.options, "character_sprite_style")
    return ok and style == "crystal" and "crystal" or "ascendant"
  end

  local BATTLE_VISUAL_STATES = {
    battleBack = true, front = true, voxelFront = true, selectorHd = true,
    trainerCard = true, hallOfFame = true, credits = true,
    intro = true, special = true, rivalPortrait = true,
  }
  local ORIGINAL_IDENTITY_FRONT_STATES = {
    front = true, selectorHd = true, trainerCard = true,
    hallOfFame = true, credits = true, intro = true,
    special = true, rivalPortrait = true,
  }

  -- Central visual resolver.  A walking sheet carries its own direction and
  -- frame grid, but callers may still pass both for an inspectable contract.
  function M.resolveVisual(character, state, direction, frame)
    local characterId = normalizedId(character, "RED")
    local style = M.characterStyle()
    local portraitStyle = trainerPortraitStyle(activeGame)
    -- Battle/portrait art follows the explicit trainer family. ORIGINAL is
    -- the edition/base pair for each identity; CRYSTAL HD is the packaged
    -- Crystal family. Field sheets remain governed independently below.
    -- character_sprite_style now only changes small field-state sheets.  This
    -- prevents a legacy option from silently restoring low-resolution Oak,
    -- rival, card or battle art.
    local originalIdentity = portraitStyle == "original"
      and (state == "battleBack" or ORIGINAL_IDENTITY_FRONT_STATES[state])
    local useFrlg = not originalIdentity
      and (BATTLE_VISUAL_STATES[state] or style == "crystal")
    local visual
    if originalIdentity then
      visual = state == "battleBack"
          and CHARACTERS[characterId].visuals.battleBack
        or CHARACTERS[characterId].visuals.front
    else
      visual = useFrlg and CRYSTAL_VISUALS[characterId][state]
        or M.definition(characterId).visuals[state]
    end
    -- Surf remains the shared creature sheet in both modes.
    visual = visual or M.definition(characterId).visuals[state]
    -- Casey's authored package art stays primary. If an incomplete/manual
    -- install omits one of those files, fail visibly safe to Red's matching
    -- native/project surface instead of handing the renderer a missing path.
    local fellBackToRed = false
    if characterId == "GREEN" and type(visual) == "table"
        and type(visual.path) == "string"
        and visual.path:sub(1, 5) ~= "save/"
        and type(mod.read) == "function" then
      local ok, body = pcall(mod.read, mod, visual.path)
      if ok and body == nil and CRYSTAL_VISUALS.RED[state] then
        visual = CRYSTAL_VISUALS.RED[state]
        fellBackToRed = true
      end
    end
    if type(visual) ~= "table" then return nil end
    local resolved = copy(visual)
    resolved.character = characterId
    resolved.fallbackCharacter = fellBackToRed and "RED" or nil
    resolved.style = style
    resolved.portraitStyle = portraitStyle
    resolved.state, resolved.direction, resolved.frame = state, direction, frame
    return resolved
  end

  function M.trainerPortraitStyle(game)
    return trainerPortraitStyle(game or activeGame)
  end

  function M.getCharacterSprite(character, state, direction, frame)
    return M.resolveVisual(character, state, direction, frame)
  end

  -- Inspectable, image-size-aware placement contract for KASC's fixed
  -- Trainer Card identities.  Keeping the source aspect ratio and never
  -- enlarging means a future profile with a different canvas still stays
  -- wholly inside the authored white interior. The card intentionally ignores
  -- character_sprite_style (the small field-sheet option), but follows the
  -- explicit ORIGINAL/CRYSTAL HD trainer-portrait family like every other
  -- front-facing identity surface.
  function M.trainerCardProfileFit(character, sourceW, sourceH)
    local state = M.getState()
    if not state.enabled and GameVersion.get() == "yellow" then return nil end
    sourceW, sourceH = tonumber(sourceW), tonumber(sourceH)
    if not sourceW or not sourceH or sourceW <= 0 or sourceH <= 0 then
      return nil
    end
    local safe = TRAINER_CARD_PROFILE_SAFE_RECT
    local scale = math.min(1, safe.w / sourceW, safe.h / sourceH)
    local width, height = sourceW * scale, sourceH * scale
    local characterId = normalizedId(character, M.getPlayerCharacter())
    return {
      character = characterId,
      x = safe.x + (safe.w - width) / 2,
      y = safe.y + (safe.h - height) / 2,
      scaleX = scale, scaleY = scale,
      width = width, height = height,
      safe = copy(safe),
      sourceWidth = sourceW, sourceHeight = sourceH,
      profile = M.getCharacterSprite(characterId, "trainerCard"),
    }
  end

  function M.getState()
    return resolve(mod.save:get(SAVE_KEY))
  end

  function M.isEnabled()
    return M.getState().enabled
  end

  function M.getPlayerCharacter()
    return M.getState().player_character
  end

  function M.getRivalCharacter()
    return M.getState().rival_character
  end

  function M.getThirdCharacter()
    return M.getState().third_character
  end

  function M.getPlayerGender()
    return M.getCharacterGender(M.getPlayerCharacter())
  end

  function M.getRivalGender()
    return M.getCharacterGender(M.getRivalCharacter())
  end

  function M.getPlayerSprite(state, direction, frame)
    return M.getCharacterSprite(M.getPlayerCharacter(), state, direction, frame)
  end

  function M.getRivalSprite(state, direction, frame)
    return M.getCharacterSprite(M.getRivalCharacter(), state, direction, frame)
  end

  function M.setEnabled(enabled)
    local state = M.getState()
    state.enabled = enabled == true
    mod.save:set(SAVE_KEY, state)
    refreshVisuals(activeGame)
    return state
  end

  function M.select(character)
    character = normalizedId(character, nil)
    assert(character, "unknown extended character")
    local state = copy(MATRIX[character])
    state.version, state.enabled = 1, true
    mod.save:set(SAVE_KEY, state)
    refreshVisuals(activeGame)
    -- A Fresh Legacy Save intentionally begins without a bound path.  Publish
    -- the real Oak-selector choice immediately so consumers do not have to
    -- wait for an unrelated map transition before the selected path exists.
    if activeGame then
      local ok, Runtime = pcall(require, "src.mods.Runtime")
      if ok and Runtime and Runtime.emit then
        Runtime.emit("character.selected", {
          game = activeGame, save = activeGame.save, character = character,
        })
      end
    end
    return state
  end

  local function relationText(state)
    if state.player_character == "BLUE" then
      return text("Ah, my grandson!\fYour journey begins\ntoday.",
        "Ah, mein Enkel!\fDeine Reise beginnt\nheute.")
    elseif state.player_character == "GREEN" then
      return text("Ah, {PLAYER}!\fYour journey begins\ntoday.",
        "Ah, {PLAYER}!\fDeine Reise beginnt\nheute.")
    end
    return nil
  end

  local function rivalText(state)
    return state.enabled and pair(dialogue.introAsk[state.rival_character]) or nil
  end

  local function rivalNamingTitle(state)
    if state.enabled and state.rival_character == "GREEN" then
      return text("HER NAME?", "IHR NAME?")
    end
    return text("HIS NAME?", "SEIN NAME?")
  end

  local function playerNamingTitle(state)
    if state.enabled and state.player_character == "GREEN" then
      return text("HER NAME?", "IHR NAME?")
    end
    return text("YOUR NAME?", "DEIN NAME?")
  end

  -- NamingScreen follows the original game's list layout and normally puts
  -- NEW NAME before the three presets.  The character selector deliberately
  -- hides identities until the player names them, so this mod wants the free
  -- entry at the bottom instead: three suggestions first, then NEW NAME.
  -- Reorder the live Menu after Screens.push has entered NamingScreen.  This
  -- keeps the change inside Kanto Ascendant and works with an unmodified
  -- engine/release build.
  local function pushNaming(speech, opts)
    opts.newNameLast = true -- explicit contract for tests/tooling
    local Screens = require("src.ui.Screens")
    local naming = Screens.push(speech.game, "NamingScreen", opts)
    local stack = speech.game and speech.game.stack
    local menu = stack and stack.top and stack:top()
    if menu and menu ~= naming and type(menu.items) == "table"
        and #menu.items == #(opts.presets or {}) + 1 then
      local freeEntry = table.remove(menu.items, 1)
      table.insert(menu.items, freeEntry)
      menu.index = 1
      if menu.clampScroll then menu:clampScroll() end
    end
    return naming
  end

  local function runPlayerNaming(speech, done, step)
    local state = M.getState()
    local presets
    if state.enabled and state.player_character == "GREEN" then
      presets = { displayName("GREEN"), "CASEY", "JEAN" }
    elseif state.enabled then
      presets = {
        displayName(state.player_character),
        "ASH", "JACK",
      }
    else
      presets = { "RED", "ASH", "JACK" }
    end
    pushNaming(speech, {
      title = playerNamingTitle(state), presets = presets, maxLen = speech.nameLen,
      onDone = function(name)
        speech.game.save.player.name = name
        speech:recordAnswer(step, 1, name, name)
        done()
      end,
    })
  end

  local function updateOakSpeechVisuals(speech)
    if not (speech and speech.game and speech.game.data) then return end
    installApprovedOakIntro(speech)
    local player = M.getPlayerSprite("overworld")
    local playerFront = M.getPlayerSprite("intro")
    local rival = M.getRivalSprite("rivalPortrait")
    local playerHd = M.getPlayerSprite("selectorHd")
    local rivalHd = M.getRivalSprite("selectorHd")
    local sprites = speech.game.data.sprites or {}
    local walk = player and player.sprite and sprites[player.sprite]
    local Assets = require("src.render.Assets")
    local function image(path)
      if not (path and love and love.graphics) then return nil end
      local ok, value = pcall(love.graphics.newImage, Assets.resolve(path))
      return ok and value or nil
    end
    local function hdPortrait(visual)
      if not (visual and visual.path) then return nil end
      local value = image(runtimeVisualPath(visual))
      if not value then return nil end
      if value.setFilter then value:setFilter("nearest", "nearest") end
      local width, height = value:getDimensions()
      local bounds = visual.bounds or { x = 0, y = 0, w = width, h = height }
      return {
        image = value,
        bounds = bounds,
        quad = love.graphics.newQuad(bounds.x, bounds.y, bounds.w, bounds.h,
          width, height),
        character = visual.character,
        sourcePath = visual.path,
      }
    end
    if walk and walk.image then speech.walkSheet = image(walk.image) or speech.walkSheet end
    if playerFront and playerFront.path then
      speech.playerPic = image(runtimeVisualPath(playerFront)) or speech.playerPic
      -- These are authored RGB/transparent PNGs.  OakSpeech otherwise sends
      -- them through the four-colour MEWMON pass a second time, which blows
      -- out faces and shifts skin/hair colours.
      speech.playerTrueColor = speech.playerPic and true or false
    end
    if rival and rival.path then
      speech.rivalPic = image(runtimeVisualPath(rival)) or speech.rivalPic
      speech.rivalTrueColor = speech.rivalPic and true or false
    end
    -- Oak's naming sequence used the compact 64px battle fronts after the
    -- character selector. Keep those as a truthful renderer fallback, but
    -- attach the same approved 128px standing masters used by the selector
    -- for the live post-composite intro portrait. This deliberately does not
    -- alter CharacterSelect itself.
    local oak = speech.__kantoAscendantOakHdPortraits
      and speech.__kantoAscendantOakHdPortraits.oak
    speech.__kantoAscendantOakHdPortraits = {
      oak = oak,
      player = hdPortrait(playerHd),
      rival = hdPortrait(rivalHd),
    }
  end

  -- OakSpeech's built-in trainer shorthand predates true-colour trainer
  -- packs and discards trainer.trueColor.  Preserve that metadata for Oak,
  -- and the explicit metadata above for the selected player/rival.  This is
  -- presentation-only and leaves every picture path untouched.
  do
    local OakSpeech = require("src.ui.OakSpeech")
    if not OakSpeech.__kantoAscendantApprovedOakIntro then
      local originalNew = OakSpeech.new
      OakSpeech.new = function(...)
        local speech = originalNew(...)
        installApprovedOakIntro(speech)
        return speech
      end
      OakSpeech.__kantoAscendantApprovedOakIntro = true
    end
    if not OakSpeech.__kantoAscendantTrueColorPics then
      local originalResolvePic = OakSpeech.resolvePic
      OakSpeech.resolvePic = function(game, desc, speech)
        local image, flip, trueColor = originalResolvePic(game, desc, speech)
        if speech and image then
          if image == speech.playerPic then
            trueColor = speech.playerTrueColor == true
          elseif image == speech.rivalPic then
            trueColor = speech.rivalTrueColor == true
              or (game.data.trainers.OPP_RIVAL1
                and game.data.trainers.OPP_RIVAL1.trueColor == true)
          elseif image == speech.oakPic then
            trueColor = speech.oakTrueColor == true
              or game.data.trainers.OPP_PROF_OAK
              and game.data.trainers.OPP_PROF_OAK.trueColor == true
          end
        end
        return image, flip, trueColor
      end
      OakSpeech.__kantoAscendantTrueColorPics = true
    end
    if not OakSpeech.__kantoAscendantWhitePaper then
      local originalPalettes = OakSpeech.sgbPalettes
      OakSpeech.sgbPalettes = function(speech, game)
        return whiteUiZones(originalPalettes(speech, game))
      end
      OakSpeech.__kantoAscendantWhitePaper = true
    end
    if not OakSpeech.__kantoAscendantHdStandingPics then
      local originalApplyPic = OakSpeech.applyPic
      OakSpeech.applyPic = function(speech, step)
        originalApplyPic(speech, step)
        if not (step and step.pic ~= nil) then return end
        local desc = step.pic
        local role
        if desc == "player" or (type(desc) == "table"
            and desc.type == "player") then
          role = "player"
        elseif desc == "oak" or (type(desc) == "table"
            and desc.type == "trainer" and desc.id == "OPP_PROF_OAK") then
          role = "oak"
        elseif desc == "rival" or (type(desc) == "table"
            and desc.type == "trainer" and desc.id == "OPP_RIVAL1") then
          role = "rival"
        end
        local portraits = speech.__kantoAscendantOakHdPortraits
        speech.__kantoAscendantOakHdRole = portraits and portraits[role]
          and role or nil
      end

      local originalDraw = OakSpeech.draw
      OakSpeech.draw = function(speech)
        local portraits = speech.__kantoAscendantOakHdPortraits
        local role = speech.__kantoAscendantOakHdRole
        local rolePic = role == "player" and speech.playerPic
          or role == "rival" and speech.rivalPic
          or role == "oak" and speech.oakPic or nil
        local hideCompact = role and portraits and portraits[role]
          and speech.pic == rolePic
        local compact = speech.pic
        if hideCompact then speech.pic = nil end
        local ok, err = pcall(originalDraw, speech)
        if hideCompact then speech.pic = compact end
        if not ok then error(err, 0) end
      end
      OakSpeech.__kantoAscendantHdStandingPics = true
    end
  end

  -- The two name-entry screens are part of the same New Game sequence.  Keep
  -- their paper shade identical to Oak and the character selector so the
  -- background cannot jump back to pale magenta between steps.
  do
    local NamingScreen = require("src.ui.NamingScreen")
    if not NamingScreen.__kantoAscendantWhitePaper then
      local originalPalettes = NamingScreen.sgbPalettes
      NamingScreen.sgbPalettes = function(screen, game)
        return whiteUiZones(originalPalettes(screen, game))
      end
      NamingScreen.__kantoAscendantWhitePaper = true
    end
  end

  local CharacterSelect = {}
  CharacterSelect.__index = CharacterSelect
  CharacterSelect.isOpaque = true
  CharacterSelect.__kantoAscendantPreGame = true

  function CharacterSelect.new(game, speech, done)
    local self = setmetatable({}, CharacterSelect)
    self.game, self.speech, self.done = game, speech, done
    self.index, self.portraits, self.portraitQuads,
      self.portraitBounds, self.fallbackPortraits = 1, {}, {}, {}, {}
    local Assets = require("src.render.Assets")
    for _, id in ipairs(SELECTION_ORDER) do
      -- Keep the native HD source for the post-composite selector overlay.
      local visual = M.selectionVisual(id)
      local path = visual and runtimeVisualPath(visual)
      if path then
        local ok, image = pcall(love.graphics.newImage, Assets.resolve(path))
        if ok then
          if image.setFilter then image:setFilter("nearest", "nearest") end
          self.portraits[id] = image
          local bounds = visual.bounds
          if bounds then
            self.portraitBounds[id] = bounds
            self.portraitQuads[id] = love.graphics.newQuad(
              bounds.x, bounds.y, bounds.w, bounds.h,
              image:getWidth(), image:getHeight())
          end
        end
      end
      -- A direct state draw (headless harness / renderer without render.hud)
      -- still has a truthful 64px fallback. The live game never composites
      -- this reduction underneath the HD portrait.
      local fallback = CRYSTAL_VISUALS[id].voxelFront
      local fallbackPath = fallback and runtimePath(fallback.path)
      if fallbackPath then
        local ok, image = pcall(love.graphics.newImage,
          Assets.resolve(fallbackPath))
        if ok then
          if image.setFilter then image:setFilter("nearest", "nearest") end
          self.fallbackPortraits[id] = image
        end
      end
    end
    self.useScreenSpacePortrait = true
    return self
  end

  function CharacterSelect:sgbPalettes(game)
    local P = require("src.render.PaletteFX")
    return { P.zone(whiteUiPalette(game, "MEWMON"), 0, 0, 19, 17) }
  end

  function CharacterSelect:update()
    local input = self.game.input
    if input:wasPressed("up") then
      self.index = self.index > 1 and self.index - 1 or #SELECTION_ORDER
    elseif input:wasPressed("down") then
      self.index = self.index < #SELECTION_ORDER and self.index + 1 or 1
    elseif input:wasPressed("a") then
      require("src.core.Sound").play(self.game.data, "Press_AB")
      M.select(SELECTION_ORDER[self.index])
      refreshVisuals(self.game)
      updateOakSpeechVisuals(self.speech)
      self.game.stack:pop()
      self.done()
    end
  end

  function CharacterSelect:draw()
    local Font = require("src.render.Font")
    local Theme = require("src.ui.Theme")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0, 0, 0, 1)
    Font.draw(text("CHOOSE YOUR HERO", "FIGUR AUSSUCHEN"), 8, 8)
    Font.drawBox(0, 2, 10, 9)
    for row, id in ipairs(SELECTION_ORDER) do
      local y = 24 + (row - 1) * 16
      if row == self.index then Font.drawCode(Theme.cursor, 8, y) end
      -- Portrait and relationship establish immutable identity here.  This
      -- row is still an editable player-name slot, so it remains unknown until
      -- the following naming screen completes successfully.
      Font.draw(M.preNamingName("player", id), 24, y)
    end

    local id = SELECTION_ORDER[self.index]
    local portrait = self.fallbackPortraits[id]
    if portrait and not self.useScreenSpacePortrait then
      -- Compatibility path only; the live selector uses the native 128px
      -- source through render.hud below.
      love.graphics.setColor(1, 1, 1, 1)
      local width, height = portrait:getDimensions()
      local drawX = 96 + math.floor((64 - width) / 2)
      local drawY = 88 - height
      love.graphics.draw(portrait, drawX, drawY)
      require("src.render.PaletteFX").markTrueColor(
        drawX, drawY, width, height)
    end

    Font.drawBox(0, 11, 20, 7)
    love.graphics.setColor(0, 0, 0, 1)
    local relation = pair(dialogue.selection[id].relation)
    local lines = {}
    for line in tostring(relation or ""):gmatch("[^\n]+") do
      lines[#lines + 1] = line
    end
    local startY = #lines > 1 and 104 or 112
    for lineIndex, line in ipairs(lines) do
      local width = #Font.split(line) * 8
      Font.draw(line, math.floor((160 - width) / 2),
        startY + (lineIndex - 1) * 16)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  -- The Game Boy UI canvas is only 160x144. Drawing a 128px model into its
  -- 64px portrait slot necessarily destroys half the authored pixels before
  -- the window is enlarged. Render the model over the completed frame instead:
  -- every source pixel is expanded by a whole number of framebuffer pixels,
  -- preserving the same crisp HD/nearest contract used by Voxel battles.
  local function selectorScreenViewport(viewport)
    if viewport then return viewport, false end
    -- DRAMALESS_SHAPE 1.6.2.ST wraps Renderer:endFrame but does not return the
    -- wrapped function's viewport table. Game still calls render.hud, only
    -- with nil as its second argument. Reconstruct the exact classic UI
    -- viewport instead of dropping the portrait or editing the external mod.
    local Renderer = require("src.render.Renderer")
    local ww, wh = love.graphics.getDimensions()
    local pw, ph = ww, wh
    if love.graphics.getPixelDimensions then
      pw, ph = love.graphics.getPixelDimensions()
    end
    local dpiX = ww > 0 and pw / ww or 1
    local dpiY = wh > 0 and ph / wh or 1
    if dpiX <= 0 then dpiX = 1 end
    if dpiY <= 0 then dpiY = 1 end
    local fit = Renderer.fitScale and Renderer:fitScale()
      or math.max(1, math.floor(math.min(pw / 160, ph / 144)))
    return {
      width = ww, height = wh,
      gameX = math.floor((pw - 160 * fit) / 2) / dpiX,
      gameY = math.floor((ph - 144 * fit) / 2) / dpiY,
      gameWidth = 160 * fit / dpiX,
      gameHeight = 144 * fit / dpiY,
      scale = fit, dpiX = dpiX, dpiY = dpiY,
    }, true
  end

  mod.hooks:wrap("render.hud", function(nextHud, game, viewport)
    nextHud(game, viewport)
    local stack = game and game.stack
    local selector = stack and stack.top and stack:top()
    if getmetatable(selector) ~= CharacterSelect then return end
    local id = SELECTION_ORDER[selector.index]
    local portrait = selector.portraits and selector.portraits[id]
    if not portrait then return end
    local recoveredViewport
    viewport, recoveredViewport = selectorScreenViewport(viewport)

    local dpiX = viewport.dpiX or 1
    local dpiY = viewport.dpiY or 1
    local fit = viewport.scale or 1
    local sourceW, sourceH = portrait:getDimensions()
    local bounds = selector.portraitBounds and selector.portraitBounds[id]
      or { x = 0, y = 0, w = sourceW, h = sourceH }
    local quad = selector.portraitQuads and selector.portraitQuads[id]
    -- The visual half of the selector extends from the list's right edge to
    -- the screen edge and from the title to the relation box. Cropping only
    -- transparent source padding lets the authored model use that full area
    -- at 3x on the standard 5x window, still with no fractional resampling.
    local slotLogicalW, slotLogicalH = 80, 72
    local slotPixelW, slotPixelH = slotLogicalW * fit, slotLogicalH * fit
    local integerZoom = math.max(1,
      math.floor(math.min(slotPixelW / bounds.w, slotPixelH / bounds.h)))
    local scaleX, scaleY = integerZoom / dpiX, integerZoom / dpiY
    local gameScaleX, gameScaleY = fit / dpiX, fit / dpiY
    local slotX = viewport.gameX + 80 * gameScaleX
    local slotY = viewport.gameY + 16 * gameScaleY
    local slotW = slotLogicalW * gameScaleX
    local slotH = slotLogicalH * gameScaleY
    local drawW, drawH = bounds.w * scaleX, bounds.h * scaleY
    local drawX = math.floor(slotX + (slotW - drawW) / 2)
    local drawY = math.floor(slotY + slotH - drawH)

    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor(slotX, slotY, slotW, slotH)
    if quad then
      love.graphics.draw(portrait, quad, drawX, drawY, 0, scaleX, scaleY)
    else
      love.graphics.draw(portrait, drawX, drawY, 0, scaleX, scaleY)
    end
    love.graphics.setScissor()
    selector.__screenSpaceHd = {
      character = id,
      sourceWidth = sourceW,
      sourceHeight = sourceH,
      trimWidth = bounds.w,
      trimHeight = bounds.h,
      integerZoom = integerZoom,
      drawX = drawX,
      drawY = drawY,
      recoveredViewport = recoveredViewport,
    }
  end, 80)

  -- OakSpeech remains a 160x144 state. Draw only its player/rival standing
  -- model after that canvas has been presented, just like the approved
  -- selector, so the native 128px source is never reduced to 64px first.
  -- This is a separate hook on purpose: the frozen CharacterSelect geometry
  -- and behavior above remain byte-for-byte untouched.
  mod.hooks:wrap("render.hud", function(nextHud, game, viewport)
    nextHud(game, viewport)
    local stack = game and game.stack
    local states = stack and stack.states
    if not states then return end
    local speech
    for index = #states, 1, -1 do
      if states[index].__kantoAscendantOakHdPortraits then
        speech = states[index]
        break
      end
    end
    if not speech then return end
    local role = speech.__kantoAscendantOakHdRole
    local portrait = role and speech.__kantoAscendantOakHdPortraits[role]
    if not portrait then return end
    local rolePic = role == "player" and speech.playerPic
      or role == "rival" and speech.rivalPic
      or role == "oak" and speech.oakPic or nil
    -- The closing shrink animation replaces playerPic with dedicated 32/16px
    -- frames without calling applyPic. Do not leave the full standing overlay
    -- visible over those frames.
    if speech.pic ~= rolePic then return end

    -- The portrait belongs only to Oak's speech page. Once CharacterSelect,
    -- NamingScreen or another opaque state is on top, it must not leak over
    -- that screen. A TextBox is the expected one-state overlay while Oak is
    -- speaking.
    local top = stack.top and stack:top() or states[#states]
    local TextBox = require("src.render.TextBox")
    local topMeta = top and getmetatable(top)
    if top ~= speech and not (topMeta and topMeta.isTextBox) then return end

    local recoveredViewport
    viewport, recoveredViewport = selectorScreenViewport(viewport)
    local dpiX, dpiY = viewport.dpiX or 1, viewport.dpiY or 1
    local fit = viewport.scale or 1
    local bounds = portrait.bounds
    local slotLogicalX, slotLogicalY = 40, 4
    local slotLogicalW, slotLogicalH = 80, 88
    local slotPixelW, slotPixelH = slotLogicalW * fit, slotLogicalH * fit
    local integerZoom = math.max(1,
      math.floor(math.min(slotPixelW / bounds.w, slotPixelH / bounds.h)))
    local scaleX, scaleY = integerZoom / dpiX, integerZoom / dpiY
    local gameScaleX, gameScaleY = fit / dpiX, fit / dpiY
    local slotX = viewport.gameX + slotLogicalX * gameScaleX
    local slotY = viewport.gameY + slotLogicalY * gameScaleY
    local slotW = slotLogicalW * gameScaleX
    local slotH = slotLogicalH * gameScaleY
    local drawW, drawH = bounds.w * scaleX, bounds.h * scaleY
    local drawX = math.floor(slotX + (slotW - drawW) / 2)
    local drawY = math.floor(slotY + slotH - drawH)

    love.graphics.setShader()
    love.graphics.setBlendMode("alpha")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setScissor(slotX, slotY, slotW, slotH)
    love.graphics.draw(portrait.image, portrait.quad,
      drawX, drawY, 0, scaleX, scaleY)
    love.graphics.setScissor()
    speech.__kantoAscendantOakHdProof = {
      role = role,
      character = portrait.character,
      sourcePath = portrait.sourcePath,
      sourceWidth = portrait.image:getWidth(),
      sourceHeight = portrait.image:getHeight(),
      integerZoom = integerZoom,
      recoveredViewport = recoveredViewport,
    }
  end, 81)

  -- Oak Speech only runs for New Game. The selector is now the default path:
  -- no opt-in prompt and no hidden vanilla branch.
  local function runSelection(speech, done)
    speech.game.stack:push(CharacterSelect.new(speech.game, speech, done))
  end

  local function runRelation(speech, done)
    local state = M.getState()
    local message = state.enabled and relationText(state) or nil
    if message then speech:sayText(message, done) else done() end
  end

  local function runRivalIntroduction(speech, done)
    local state = M.getState()
    local message = state.enabled and rivalText(state) or nil
    -- The vanilla step carried pic="rival". Converting it to a function step
    -- bypasses OakSpeech:runStep's automatic applyPic, so apply it here or the
    -- preceding player portrait remains visible during the rival introduction.
    speech:applyPic({ pic = "rival" })
    if message then
      speech:sayText(message, done)
    else
      -- Keep the game's active language/text override and vanilla wording.
      speech:say("_IntroduceRivalText", done)
    end
  end

  local function runRivalNaming(speech, done, step)
    local state = M.getState()
    local presets
    if state.enabled and state.rival_character == "GREEN" then
      presets = { displayName("GREEN"), "CASEY", "JEAN" }
    elseif state.enabled and state.rival_character == "RED" then
      -- Red's suggestions belong to Red in both player and rival roles.
      -- Gary/John are Blue's names and must never leak into Green's route.
      presets = { displayName("RED"), "ASH", "JACK" }
    elseif state.enabled then
      presets = {
        displayName(state.rival_character),
        "GARY", "JOHN",
      }
    else
      presets = { "BLUE", "GARY", "JOHN" }
    end
    pushNaming(speech, {
      title = rivalNamingTitle(state), presets = presets, maxLen = speech.nameLen,
      onDone = function(name)
        speech.game.save.player.rival = name
        speech:recordAnswer(step, 1, name, name)
        done()
      end,
    })
  end

  local function runRivalConfirmation(speech, done)
    local state = M.getState()
    local message = state.enabled and pair(dialogue.introConfirm[
      state.rival_character]) or nil
    speech:applyPic({ pic = "rival" })
    if message then speech:sayText(message, done) else done() end
  end

  local RIVAL_CLASSES = { "OPP_RIVAL1", "OPP_RIVAL2", "OPP_RIVAL3" }
  local RIVAL_CLASS_SET = {}
  for _, classId in ipairs(RIVAL_CLASSES) do RIVAL_CLASS_SET[classId] = true end
  local rivalPicBaseline = setmetatable({}, { __mode = "k" })
  local overworldBaseline = setmetatable({}, { __mode = "k" })
  local storyTextBaseline = setmetatable({}, { __mode = "k" })

  local CHARACTER_STORY_KEYS = {
    _RedsHouse1FMomWakeUpText = true,
    _PalletTownRivalsHouseSignText = true,
    _BluesHouseDaisyRivalAtLabText = true,
    _LancesRoomLanceAfterBattleText = true,
  }

  local function voxelActive()
    local ok, Pipelines = pcall(require, "src.render.Pipelines")
    return ok and Pipelines and Pipelines.level("voxel") > 0
  end

  -- DRAMALESS 2.0.2 keeps its card implementation private, but its public
  -- option is still the authoritative pre-battle boundary.  The player back
  -- picture is resolved while BattleState is being constructed, before the
  -- native card host has a session to inspect, so consulting the loader/save
  -- option is both earlier and more exact than treating renderer presence as
  -- proof that a standing card will be shown.
  local function dramalessNativeCardsEnabled(game)
    local loaderValue = game and game.mods and game.mods.modOptions
      and game.mods.modOptions.DRAMALESS_SHAPE
      and game.mods.modOptions.DRAMALESS_SHAPE.voxel_2d_battles
    if type(loaderValue) == "boolean" then return loaderValue end
    local savedValue = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions.DRAMALESS_SHAPE
      and game.save.options.modOptions.DRAMALESS_SHAPE.voxel_2d_battles
    if type(savedValue) == "boolean" then return savedValue end
    -- Exact reviewed 2.0.2 default.  Older/unreviewed packages never reach
    -- this branch because voxelRenderer rejects their receipt first.
    return true
  end

  -- The Voxel world and a staged Voxel battle are two independent choices.
  -- Using the world pipeline alone here made a normal Gen-I battle request a
  -- standing trainer card whenever the player kept the 3D overworld enabled.
  -- Ask the reviewed renderer's own battle boundary instead: OFF, BACK
  -- SPRITES, an unavailable arena, or a failed capability probe must all keep
  -- the edition-appropriate Red/Blue/Green back picture.
  local function voxelBattleUsesStandingTrainer()
    if not voxelActive() or not voxelRenderer then return false end
    local resolved, battleModule, rendererId, reason = pcall(
      voxelRenderer.module, activeGame, "OverworldBattle")
    if not resolved then return false end
    if type(battleModule) == "table" then
      local predicate = battleModule.wantsFront or battleModule.enabled
      if type(predicate) ~= "function" then return false end
      local ok, enabled = pcall(predicate)
      return ok and enabled == true
    end
    -- The exact reviewed DRAMALESS 2.0.2 package deliberately keeps its
    -- owner-scoped battle modules private.  Its option (default ON), rather
    -- than package presence, decides whether the native standing cards own
    -- this battle.
    return rendererId == "DRAMALESS_SHAPE"
      and reason == "renderer-native-owned:DRAMALESS_SHAPE"
      and dramalessNativeCardsEnabled(activeGame)
  end
  for _, id in ipairs({ "RED", "GREEN" }) do
    for key in pairs(dialogue.rival[id] or {}) do
      CHARACTER_STORY_KEYS[key] = true
    end
  end

  -- Preserve the exact translation-mod baseline once, restore it first on
  -- every refresh, then layer only the dialogue belonging to the current
  -- role matrix. Blue therefore keeps the active game's native script while
  -- quiet Red and cheeky Green receive their complete authored voices.
  local function refreshCharacterDialogue(game, state)
    local entries = game and game.data and game.data.text
    if not entries then return end
    local baseline = storyTextBaseline[entries]
    if not baseline then
      baseline = {}
      for key in pairs(CHARACTER_STORY_KEYS) do baseline[key] = entries[key] end
      storyTextBaseline[entries] = baseline
    end
    for key in pairs(CHARACTER_STORY_KEYS) do entries[key] = baseline[key] end
    if not (state and state.enabled) then return end

    for key, variants in pairs(dialogue.rival[state.rival_character] or {}) do
      entries[key] = pair(variants)
    end
    if state.player_character == "GREEN" then
      entries._RedsHouse1FMomWakeUpText = pair(dialogue.motherGreen)
    end
    entries._PalletTownRivalsHouseSignText = pair(dialogue.oakFamilyHouse)
    if state.rival_character == "RED" then
      entries._BluesHouseDaisyRivalAtLabText = pair(dialogue.daisyRedAtLab)
    elseif state.rival_character == "GREEN" then
      entries._LancesRoomLanceAfterBattleText = pair(dialogue.lanceGreen)
    end
  end

  local function installRivalPresentation(game, rival)
    local data = game and game.data
    local portraitState = voxelBattleUsesStandingTrainer()
      and "voxelFront" or "rivalPortrait"
    local portrait = M.getCharacterSprite(rival, portraitState)
    if not (data and data.trainers and portrait) then return end
    for _, classId in ipairs(RIVAL_CLASSES) do
      local trainer = data.trainers[classId]
      if trainer then
        if rivalPicBaseline[trainer] == nil then
          rivalPicBaseline[trainer] = {
            pic = trainer.pic or false,
            trueColor = trainer.trueColor == true,
            character = trainer.ascendantCharacter or false,
          }
        end
        trainer.pic = runtimeVisualPath(portrait) or (rivalPicBaseline[trainer] ~= false
          and rivalPicBaseline[trainer].pic or nil)
        trainer.trueColor = true
        trainer.ascendantCharacter = rival
      end
    end
  end

  local function restoreRivalPresentation(game)
    local data = game and game.data
    if not (data and data.trainers) then return end
    for _, classId in ipairs(RIVAL_CLASSES) do
      local trainer = data.trainers[classId]
      local baseline = trainer and rivalPicBaseline[trainer]
      if baseline ~= nil then
        trainer.pic = baseline.pic ~= false and baseline.pic or nil
        trainer.trueColor = baseline.trueColor or nil
        trainer.ascendantCharacter = baseline.character ~= false
          and baseline.character or nil
        rivalPicBaseline[trainer] = nil
      end
    end
  end

  local function captureOverworldBaseline(overworld, player)
    if not overworld then return nil end
    local baseline = overworldBaseline[overworld]
    if not baseline then
      baseline = { npcs = setmetatable({}, { __mode = "k" }) }
      overworldBaseline[overworld] = baseline
    end
    if player and not baseline.player then
      baseline.player = {
        sprite = player.sprite, bikeSprite = player.bikeSprite,
        surfSprite = player.surfSprite, fishingSprite = player.fishingSprite,
      }
    end
    return baseline
  end

  local function captureNpcBaseline(baseline, npc)
    if baseline and npc and baseline.npcs[npc] == nil then
      baseline.npcs[npc] = npc.sprite or false
    end
  end

  local function restoreOverworldPresentation(overworld)
    local baseline = overworld and overworldBaseline[overworld]
    if not baseline then return end
    local player = overworld.player
    if player and baseline.player then
      player.sprite = baseline.player.sprite
      player.bikeSprite = baseline.player.bikeSprite
      player.surfSprite = baseline.player.surfSprite
      player.fishingSprite = baseline.player.fishingSprite
      player.ascendantCharacter = nil
    end
    for npc, sprite in pairs(baseline.npcs) do
      npc.sprite = sprite ~= false and sprite or nil
      npc.ascendantCharacter = nil
    end
    overworldBaseline[overworld] = nil
  end

  local function replaceOverworldSprite(game, actor, character, visualState, seed)
    local visual = M.getCharacterSprite(character, visualState)
    local spriteId = visual and visual.sprite
    if not (game and game.data and game.data.sprites and actor and spriteId) then return end
    local spriteDef = game.data.sprites[spriteId]
    if not spriteDef then return end
    local SpriteRenderer = require("src.render.SpriteRenderer")
    actor.sprite = SpriteRenderer.new(spriteDef, seed)
    -- Keep the resolved identity inspectable.  Rival story events reuse the
    -- same role under several map object names; this tag proves that the
    -- field actor and its later battle card came from one identity matrix.
    actor.ascendantCharacter = character
  end

  refreshVisuals = function(game)
    if not game then return end
    activeGame = game
    local state = M.getState()
    local overworld = game.overworld
    if not state.enabled then
      restoreOverworldPresentation(overworld)
      restoreRivalPresentation(game)
      refreshCharacterDialogue(game, state)
      return
    end
    local playerCharacter = state.player_character
    local rivalCharacter = state.rival_character
    local player = overworld and overworld.player
    local baseline = captureOverworldBaseline(overworld, player)
    if player then
      replaceOverworldSprite(game, player, playerCharacter, "overworld", "player")
      local bike = M.getCharacterSprite(playerCharacter, "bike")
      local surf = M.getCharacterSprite(playerCharacter, "surf")
      local SpriteRenderer = require("src.render.SpriteRenderer")
      if bike and bike.sprite and game.data.sprites[bike.sprite] then
        player.bikeSprite = SpriteRenderer.new(game.data.sprites[bike.sprite], "player")
      end
      if surf and surf.sprite and game.data.sprites[surf.sprite] then
        player.surfSprite = SpriteRenderer.new(game.data.sprites[surf.sprite], "player")
      end
      local fishing = M.getCharacterSprite(playerCharacter, "fishing")
      if fishing and fishing.sprite and game.data.sprites[fishing.sprite] then
        player.fishingSprite = SpriteRenderer.new(
          game.data.sprites[fishing.sprite], "player")
      else
        player.fishingSprite = baseline and baseline.player
          and baseline.player.fishingSprite or nil
      end
    end
    if overworld and overworld.npcs then
      for _, npc in pairs(overworld.npcs) do
        if npc and npc.def and tostring(npc.def.name):find("RIVAL", 1, true) then
          captureNpcBaseline(baseline, npc)
          replaceOverworldSprite(game, npc, rivalCharacter, "overworld", npc.id)
        end
      end
    end
    -- Party definitions are resolved separately. OPP_RIVAL stages, flags and
    -- starter selection remain role-based engine behavior and stay intact.
    installRivalPresentation(game, rivalCharacter)
    refreshCharacterDialogue(game, state)
  end

  -- All player-facing trainer pictures (battle back, Oak, Trainer Card,
  -- Hall of Fame and credits) resolve through the engine's live seam.
  local FRONT_STATE_BY_KIND = {
    trainer_card = "trainerCard", hall_of_fame = "hallOfFame",
    credits = "credits", intro = "intro", special = "special",
  }

  function M.playerVisualState(ctx)
    if ctx and ctx.side == "back" then
      -- Dramatic Shape presents trainers standing in its Voxel battle scene.
      -- Casey and Blue therefore use their agreed full 56x56 standing art in
      -- the battle-back slot. Their overworld walkers are never touched.
      local player = M.getPlayerCharacter()
      if ctx.kind == "battle" and voxelBattleUsesStandingTrainer() then
        return "voxelFront"
      end
      return "battleBack"
    end
    return FRONT_STATE_BY_KIND[ctx and ctx.kind] or "front"
  end

  mod.hooks:wrap("player.sprite", function(nextSprite, path, ctx)
    path = nextSprite(path, ctx)
    -- The engine has already resolved these two battle backs to the scripted
    -- tutorial actor: Viridian's old man (`demo`) or Yellow's Professor Oak
    -- (`oakDemo`). They are not player-identity surfaces, even though the
    -- shared renderer exposes them through player.sprite. Preserve both the
    -- selected path and its native palette contract verbatim.
    if ctx and (ctx.demo or ctx.oakDemo) then return path end
    local state = M.getState()
    -- Red/Blue saves created before the three-character record existed still
    -- represent the canonical Red protagonist.  Resolve his approved battle
    -- family without manufacturing selection/story state in the save. Yellow
    -- keeps its edition-specific protagonist until the user explicitly makes
    -- an Ascendant character choice.
    if not state.enabled and GameVersion.get() == "yellow" then return path end
    local visualState = M.playerVisualState(ctx)
    local visual = M.getPlayerSprite(visualState)
    if ctx and BATTLE_VISUAL_STATES[visualState] then
      ctx.trueColor = visual and visual.trueColor ~= false or false
    end
    return visual and runtimeVisualPath(visual) or path
  end, 80)

  -- TrainerCard currently exposes the profile through player.sprite but has
  -- no placement hook.  Wrap only its single profile draw call and restore
  -- love.graphics.draw before returning (or rethrowing), leaving every frame,
  -- font, title overlay and third-party renderer draw byte-for-byte native.
  local function installTrainerCardProfileFit()
    local ok, TrainerCard = pcall(require, "src.ui.TrainerCard")
    if not ok or type(TrainerCard) ~= "table"
        or type(TrainerCard.draw) ~= "function" then return false end
    TrainerCard._kantoAscendantProfileFitController = M
    TrainerCard._kantoAscendantLeaderFaceController = M

    -- Keep the stock badge half of the card, but replace the eight unearned
    -- placeholders with the already-approved KASC leader portraits.  The
    -- atlas contains eight exact 16x16 cells in canonical badge order, so no
    -- title, ownership or save logic is changed here.
    if not TrainerCard._kantoAscendantLeaderFacesWrapped
        and type(TrainerCard.new) == "function" then
      TrainerCard._kantoAscendantLeaderFacesWrapped = true
      local originalNew = TrainerCard.new
      TrainerCard.new = function(...)
        local card = originalNew(...)
        local faceController = TrainerCard._kantoAscendantLeaderFaceController
        local faces = faceController and faceController.trainerCardLeaderFaces
          and faceController.trainerCardLeaderFaces() or nil
        if card and faces then card.faces = faces end
        return card
      end
    end

    if TrainerCard._kantoAscendantProfileFitWrapped then return true end
    TrainerCard._kantoAscendantProfileFitWrapped = true
    local originalDraw = TrainerCard.draw
    TrainerCard.draw = function(card)
      local picture = card and card.pic
      local width, height
      if picture and type(picture.getDimensions) == "function" then
        local measured, w, h = pcall(picture.getDimensions, picture)
        if measured then width, height = w, h end
      end
      local controller = TrainerCard._kantoAscendantProfileFitController
      local fit = controller and controller.trainerCardProfileFit
        and controller.trainerCardProfileFit(nil, width, height) or nil
      local graphics = love and love.graphics
      if not fit or not graphics or type(graphics.draw) ~= "function" then
        return originalDraw(card)
      end

      local nativeDraw = graphics.draw
      local profileDrawn = false
      graphics.draw = function(drawable, ...)
        if not profileDrawn and drawable == picture then
          profileDrawn = true
          -- Trainer portraits are pixel art. The stock image may inherit
          -- LÖVE's linear filter, which visibly blurs the 56/64px sources
          -- when they are aspect-fitted into the card's 48px safe area.
          -- Apply nearest filtering only for this one draw and restore the
          -- image's original filter even if a third-party draw hook throws.
          local canFilter = type(drawable.getFilter) == "function"
            and type(drawable.setFilter) == "function"
          local oldMin, oldMag, oldAnisotropy
          if canFilter then
            local measured, minFilter, magFilter, anisotropy =
              pcall(drawable.getFilter, drawable)
            if measured then
              oldMin, oldMag, oldAnisotropy =
                minFilter, magFilter, anisotropy
              local filtered = pcall(drawable.setFilter, drawable,
                "nearest", "nearest")
              if not filtered then canFilter = false end
            else
              canFilter = false
            end
          end
          local drawn, problem = pcall(nativeDraw, drawable,
            fit.x, fit.y, 0, fit.scaleX, fit.scaleY)
          if canFilter then
            pcall(drawable.setFilter, drawable,
              oldMin, oldMag, oldAnisotropy)
          end
          if not drawn then error(problem, 0) end
          return problem
        end
        return nativeDraw(drawable, ...)
      end
      -- Mod sandboxes intentionally do not expose the debug library.  A
      -- plain protected call is sufficient here: its only job is to restore
      -- the engine draw function before forwarding a native card error.
      local drawn, problem = pcall(originalDraw, card)
      graphics.draw = nativeDraw
      if not drawn then error(problem, 0) end
    end
    return true
  end
  M.installTrainerCardProfileFit = installTrainerCardProfileFit

  function M.trainerCardLeaderFaces()
    local image = loadTrueColorImage(runtimePath(TRAINER_CARD_LEADER_FACES))
    if not image or type(image.getDimensions) ~= "function"
        or not (love and love.graphics
          and type(love.graphics.newQuad) == "function") then return nil end
    local width, height = image:getDimensions()
    if width ~= 16 or height ~= 128 then return nil end
    local quads = {}
    for index = 0, 7 do
      quads[index] = love.graphics.newQuad(0, index * 16, 16, 16,
        width, height)
    end
    return {
      img = image,
      quads = quads,
      path = runtimePath(TRAINER_CARD_LEADER_FACES),
      order = { "BROCK", "MISTY", "LT_SURGE", "ERIKA",
        "KOGA", "SABRINA", "BLAINE", "GIOVANNI" },
    }
  end

  installTrainerCardProfileFit()

  local JOHTO_VOXEL_BY_CLASS = {
    KA_JOHTO_SILVER = {
      id = "JOHTO_SILVER",
      path = "assets/johto_masters/battle/silver_voxel_front_hd.png",
      fallback = "assets/johto_masters/battle/silver_voxel_front.png",
    },
    KA_JOHTO_KRIS = {
      id = "JOHTO_KRIS",
      path = "assets/johto_masters/battle/kris_voxel_front_hd.png",
      fallback = "assets/johto_masters/battle/kris_voxel_front.png",
    },
    KA_JOHTO_GOLD = {
      id = "JOHTO_GOLD",
      path = "assets/johto_masters/battle/gold_voxel_front_hd.png",
      fallback = "assets/johto_masters/battle/gold_voxel_front.png",
    },
  }
  -- The Indigo Elite Four previously fell through to DRAMALESS' native
  -- 64px trainerPic card.  In a FULL battle that tiny card is enlarged next
  -- to the player's 128px standee and reads as a broken/wrong sprite.  These
  -- are new Voxel-only siblings; the accepted 2D FRLG pictures remain the
  -- authoritative trainerPic and are never overwritten.
  local INDIGO_VOXEL_BY_CLASS = {
    OPP_LORELEI = {
      id = "INDIGO_LORELEI",
      path = "assets/characters/frlg_trainers/elite_four_lorelei_voxel_front_hd_v3.png",
      fallback = "assets/characters/frlg_trainers/elite_four_lorelei_voxel_front_v3.png",
    },
    OPP_BRUNO = {
      id = "INDIGO_BRUNO",
      path = "assets/characters/frlg_trainers/elite_four_bruno_voxel_front_hd_v3.png",
      fallback = "assets/characters/frlg_trainers/elite_four_bruno_voxel_front_v3.png",
    },
    OPP_AGATHA = {
      id = "INDIGO_AGATHA",
      path = "assets/characters/frlg_trainers/elite_four_agatha_voxel_front_hd_v3.png",
      fallback = "assets/characters/frlg_trainers/elite_four_agatha_voxel_front_v3.png",
    },
    OPP_LANCE = {
      id = "INDIGO_LANCE",
      path = "assets/characters/frlg_trainers/elite_four_lance_voxel_front_hd_v3.png",
      fallback = "assets/characters/frlg_trainers/elite_four_lance_voxel_front_v3.png",
    },
  }

  local function ordinaryVoxelSpec(battle)
    if not (trainerVoxelPortraits
        and type(trainerVoxelPortraits.spec) == "function") then return nil end
    return trainerVoxelPortraits.spec(battle and battle.oppClass)
  end

  local highResTrainerTextures = {}
  local voxelFallbackReceipts, voxelFallbackKeys = {}, {}

  local function recordVoxelFallback(row)
    local key = table.concat({ tostring(row.rendererId),
      tostring(row.rendererVersion), tostring(row.side),
      tostring(row.class), tostring(row.source), tostring(row.reason) }, "|")
    if voxelFallbackKeys[key] then return row end
    voxelFallbackKeys[key] = true
    voxelFallbackReceipts[#voxelFallbackReceipts + 1] = row
    if mod.log and type(mod.log.error) == "function" then
      pcall(mod.log.error, mod.log,
        "approved trainer resolver fallback: %s", key)
    end
    return row
  end

  local function highResVoxelTrainerTexture(side, character, authoredPath,
      fallbackPath, strictApproved)
    if not (love and love.graphics) then return nil, "graphics-unavailable" end
    local key = side .. ":" .. character .. ":" .. tostring(authoredPath or "")
    if highResTrainerTextures[key] then return highResTrainerTextures[key] end
    local stem = character:lower()
    local sourcePath = authoredPath or ("assets/characters/crystal_chars/"
      .. stem .. "_voxel_front_hd.png")
    fallbackPath = fallbackPath or ("assets/characters/crystal_chars/"
      .. stem .. "_voxel_front.png")
    local okImage, image = pcall(love.graphics.newImage, runtimePath(sourcePath))
    if (not okImage or not image) and not strictApproved then
      sourcePath = fallbackPath
      okImage, image = pcall(love.graphics.newImage, runtimePath(sourcePath))
    end
    if not okImage or not image then
      return nil, "approved-source-unavailable:" .. tostring(sourcePath)
    end
    image:setFilter("nearest", "nearest")
    local sourceScale = image:getWidth() >= 128 and 2 or 1
    local okCanvas, canvas = pcall(love.graphics.newCanvas,
      160 * sourceScale, 144 * sourceScale,
      { dpiscale = 1 })
    if not okCanvas or not canvas then return nil, "approved-canvas-unavailable" end
    canvas:setFilter("nearest", "nearest")

    -- Dramatic Shape normally rasterizes the complete 160x144 Game Boy
    -- picture layer into its trainer billboard.  Rendering the dedicated
    -- 128px trainer into a 2x canvas preserves twice the facial information
    -- while keeping the exact same Game Boy anchor and world dimensions.
    local ax, ay = side == "enemy" and 124 or 80,
      side == "enemy" and 56 or 96
    local g = love.graphics
    local previousCanvas = g.getCanvas()
    local previousBlend, previousAlpha = g.getBlendMode()
    local cr, cg, cb, ca = g.getColor()
    g.setCanvas(canvas)
    g.clear(0, 0, 0, 0)
    g.setBlendMode("alpha")
    g.setColor(1, 1, 1, 1)
    local drawX = ax * sourceScale - image:getWidth() / 2
    local drawY = ay * sourceScale - image:getHeight()
    -- Enemy trainers use the original 56px Game Boy foot anchor. A native
    -- 128px HD standing card is taller than the 112px available above that
    -- anchor, so its top used to be drawn at -16 and the head was literally
    -- cut out of the texture. Keep a small top margin and report the adjusted
    -- foot anchor to the 3D billboard; the world cell itself never moves.
    local topMargin = sourceScale * 2
    if drawY < topMargin then drawY = topMargin end
    local effectiveAy = (drawY + image:getHeight()) / sourceScale
    g.draw(image, drawX, drawY)
    if previousCanvas then g.setCanvas(previousCanvas) else g.setCanvas() end
    g.setBlendMode(previousBlend or "alpha", previousAlpha)
    g.setColor(cr, cg, cb, ca)

    local texture = {
      canvas = canvas, ax = ax, ay = effectiveAy,
      trainer = side == "enemy",
      ascendantStandingTrainer = character,
      ascendantHighResTrainer = sourceScale == 2,
      ascendantHighResSource = sourcePath,
      ascendantTrainerSourceScale = sourceScale,
    }
    highResTrainerTextures[key] = texture
    return texture, nil
  end

  -- Inspectable contract used by focused compatibility tests.  A nil result
  -- means "keep DRAMALESS' registered trainerPic card", not "no portrait".
  function M.voxelStandingTrainerCharacter(battle, side)
    -- Catching demonstrations borrow the player-side slot for a scripted
    -- actor. The engine has already resolved Viridian's old man (`demo`) or
    -- Yellow's Professor Oak (`oakDemo`) into playerBackPic; neither is the
    -- selected Red/Blue/Green protagonist.
    if side == "player" and battle and (battle.demo or battle.oakDemo) then
      return nil
    end
    if side == "player" and battle and battle.showPlayerBack then
      local state = M.getState()
      if not state.enabled and GameVersion.get() == "yellow" then return nil end
      return M.getPlayerCharacter()
    end
    if side == "enemy" and battle and battle.showEnemyTrainer
        and RIVAL_CLASS_SET[battle.oppClass] then
      return M.getRivalCharacter()
    end
    return nil
  end

  -- Johto owns three isolated classes and three isolated Voxel cards.  They
  -- never travel through the Kanto rival resolver: doing so was the exact
  -- bug that made Silver, Kris and Gold all render as the selected rival.
  function M.voxelStandingTrainerSpec(battle, side)
    if side ~= "enemy" or not (battle and battle.showEnemyTrainer) then
      return nil
    end
    local spec = JOHTO_VOXEL_BY_CLASS[battle.oppClass]
      or INDIGO_VOXEL_BY_CLASS[battle.oppClass]
      or ordinaryVoxelSpec(battle)
    return spec and copy(spec) or nil
  end

  local function installVoxelStandingTrainer(game)
    local overworldBattle, rendererId, rendererError, rendererReceipt
    if voxelRenderer then
      -- Lua's logical operators collapse a multi-return expression to its
      -- first value.  Calling through `voxelRenderer and ...` installed the
      -- wrapper but silently dropped its id/version/provenance receipt.
      overworldBattle, rendererId, rendererError, rendererReceipt =
        voxelRenderer.module(game, "OverworldBattle")
    end
    if type(overworldBattle) ~= "table" then
      M.voxelResolverStatus = {
        schema = "ka-approved-trainer-resolver/v1",
        installed = false,
        reason = rendererError or "renderer-absent",
      }
      return false
    end
    local battleArtIdentityOnly = rendererId == "BATTLE_ART_VOXEL_FORK"
    local resolverSentinel = {
      schema = "ka-approved-trainer-resolver/v1",
      installed = true,
      delegated = battleArtIdentityOnly or nil,
      identityOverride = battleArtIdentityOnly or nil,
      rendererId = rendererId,
      rendererVersion = rendererReceipt and rendererReceipt.rendererVersion,
      rendererProvenance = rendererReceipt and rendererReceipt.provenance,
      module = "OverworldBattle",
      capability = "sideTexture",
      reason = battleArtIdentityOnly
        and "renderer-owns-stage-kasc-owns-selected-identity" or nil,
    }
    M.voxelResolverStatus = resolverSentinel
    if overworldBattle.__ascendantStandingTrainerMirror then
      overworldBattle.__kantoAscendantApprovedTrainerResolver =
        overworldBattle.__kantoAscendantApprovedTrainerResolver
        or resolverSentinel
      return true
    end
    local originalSideTexture = overworldBattle.sideTexture
    if type(originalSideTexture) ~= "function" then return false end
    overworldBattle.sideTexture = function(battle, side)
      -- FULL/staged renderers bypass `player.sprite` when choosing a trainer
      -- source. Delegate catch-tutorial cards before any selected-identity
      -- substitution or metadata rewrite so Oak/the old man remain exactly
      -- the actor already chosen by the engine.
      if side == "player" and battle and (battle.demo or battle.oakDemo) then
        return originalSideTexture(battle, side)
      end
      local player = M.getPlayerCharacter()
      -- Battle Art calls this source boundary only for its staged renderer.
      -- It may not register the engine's `voxel` world pipeline, so its exact
      -- reviewed receipt is sufficient here.  Other renderers retain their
      -- normal world + battle capability gate.
      local crystalVoxel = battle
        and (voxelActive() or battleArtIdentityOnly)
      local trainerVisible = side == "player" and battle
        and battle.showPlayerBack or side == "enemy" and battle
        and battle.showEnemyTrainer
      -- The HD enemy standee belongs only to Kanto's three actual Rival
      -- classes.  Applying it to every trainer intro silently replaced
      -- dedicated classes (notably KA_JOHTO_SILVER/KRIS/GOLD) with the
      -- selected Kanto rival in DRAMALESS.  Every other trainer must travel
      -- through DRAMALESS' native sideTexture path unless it has a separate
      -- authored class card in JOHTO_VOXEL_BY_CLASS below.
      local character = M.voxelStandingTrainerCharacter(battle, side)
      local fallbackReceipt
      if crystalVoxel and trainerVisible and character then
        local highRes, problem = highResVoxelTrainerTexture(
          side, character, nil, nil, true)
        if highRes then
          highRes.ascendantApprovedTrainerResolver = {
            schema = "ka-approved-trainer-texture/v1",
            role = side == "enemy" and "enemy" or "player",
            identity = character,
            approvedVersion = "CURRENT",
            source = highRes.ascendantHighResSource,
            rendererId = rendererId,
            rendererVersion = resolverSentinel.rendererVersion,
            rendererProvenance = resolverSentinel.rendererProvenance,
          }
          return highRes
        end
        fallbackReceipt = recordVoxelFallback({
          schema = "ka-approved-trainer-fallback/v1",
          rendererId = rendererId,
          rendererVersion = resolverSentinel.rendererVersion,
          side = side, class = "PLAYER:" .. tostring(character),
          source = "assets/characters/crystal_chars/"
            .. character:lower() .. "_voxel_front_hd.png",
          reason = problem,
        })
      end
      -- Battle Art continues to own PLAYER ART/TRAINER ART for every source
      -- except the two explicit KASC-selected role identities above.  Do not
      -- run ordinary, Johto or Indigo replacement rules through this mixed
      -- ownership seam and never add a second standee/HUD layer.
      if battleArtIdentityOnly then
        local texture = originalSideTexture(battle, side)
        if texture and fallbackReceipt then
          texture.ascendantTrainerResolverFallback = fallbackReceipt
        end
        return texture
      end
      local authored = M.voxelStandingTrainerSpec(battle, side)
      -- Red/Blue/Green and Silver/Kris/Gold are identity assets, not a skin;
      -- their approved cards never follow the ordinary trainer option.
      local fixedIdentity = battle and (RIVAL_CLASS_SET[battle.oppClass]
        or JOHTO_VOXEL_BY_CLASS[battle.oppClass])
      local style = trainerPortraitStyle(battle and battle.game or activeGame)
      local useAuthored = fixedIdentity or style == "crystal_hd"
      local pairAvailable = fixedIdentity or not frlgTrainerPack
        or type(frlgTrainerPack.crystalPairAvailable) ~= "function"
        or frlgTrainerPack.crystalPairAvailable(battle.oppClass)
      if crystalVoxel and trainerVisible and authored and useAuthored
          and not pairAvailable then
        fallbackReceipt = recordVoxelFallback({
          schema = "ka-approved-trainer-fallback/v1",
          rendererId = rendererId,
          rendererVersion = resolverSentinel.rendererVersion,
          side = side, class = battle.oppClass,
          source = authored.path, reason = "approved-pair-unavailable",
        })
      end
      if crystalVoxel and trainerVisible and authored and useAuthored
          and pairAvailable then
        local highRes, problem = highResVoxelTrainerTexture(side, authored.id,
          authored.path, authored.fallback, true)
        if highRes then
          highRes.johtoMasterClass = JOHTO_VOXEL_BY_CLASS[battle.oppClass]
            and battle.oppClass or nil
          highRes.johtoMasterVoxel = highRes.johtoMasterClass ~= nil
          highRes.indigoEliteClass = INDIGO_VOXEL_BY_CLASS[battle.oppClass]
            and battle.oppClass or nil
          highRes.kantoTrainerClass = authored.class
          highRes.kantoTrainerPortraitStyle = style
          highRes.ascendantApprovedTrainerResolver = {
            schema = "ka-approved-trainer-texture/v1",
            role = "enemy", class = battle.oppClass,
            approvedVersion = authored.approvedVersion or "CURRENT",
            source = highRes.ascendantHighResSource,
            rendererId = rendererId,
            rendererVersion = resolverSentinel.rendererVersion,
            rendererProvenance = resolverSentinel.rendererProvenance,
          }
          return highRes
        end
        fallbackReceipt = recordVoxelFallback({
          schema = "ka-approved-trainer-fallback/v1",
          rendererId = rendererId,
          rendererVersion = resolverSentinel.rendererVersion,
          side = side, class = battle.oppClass,
          source = authored.path, reason = problem,
        })
      end
      -- ORIGINAL keeps the untouched edition picture. It travels through
      -- the renderer's native card path instead of an HD
      -- standee; nearest filtering is enforced by the original renderer.
      local texture = originalSideTexture(battle, side)
      if texture and fallbackReceipt then
        texture.ascendantTrainerResolverFallback = fallbackReceipt
      end
      if side == "player" and texture and battle and battle.showPlayerBack
          and voxelActive() then
        texture.trainer = false
        texture.ascendantStandingTrainer = player
      end
      return texture
    end
    overworldBattle.__ascendantStandingTrainerMirror = true
    overworldBattle.__ascendantStandingTrainerOriginal = originalSideTexture
    overworldBattle.__kantoAscendantApprovedTrainerResolver = resolverSentinel
    return true
  end

  mod.events:on("game.ready", function(ev)
    local game = ev and ev.game or activeGame
    refreshVisuals(game)
    installVoxelStandingTrainer(game)
  end)
  mod.events:on("save.loaded", function(ev)
    refreshVisuals(ev and ev.game or activeGame)
  end)
  mod.events:on("map.entered", function()
    refreshVisuals(activeGame)
  end)
  mod.events:on("mod.options_changed", function(ev)
    if ev and ev.mod == mod.id and (ev.key == "character_sprite_style"
        or ev.key == "trainer_portrait_style") then
      refreshVisuals(ev.game or activeGame)
    elseif ev and voxelRenderer and voxelRenderer.isRendererId(ev.mod) then
      -- Renderer battle-mode rows can change whether the rival needs a flat
      -- front or a staged standing card without changing the world pipeline.
      refreshVisuals(ev.game or activeGame)
    end
  end)

  -- Several canonical rival scenes (Route 22, Cerulean, Silph, S.S. Anne)
  -- keep their NPC absent until a script executes show_object.  That object
  -- is constructed after map.entered, so refresh once more on the exact
  -- construction edge or the field actor would remain vanilla Blue while
  -- the immediately following battle already showed the selected rival.
  local Commands = require("src.script.Commands")
  if not Commands.__ascendantCharacterShowObjectWrapped then
    local originalShowObject = Commands.show_object
    Commands.show_object = function(ctx, mapId, objName)
      local result = originalShowObject(ctx, mapId, objName)
      local refresh = Commands.__ascendantCharacterRefresh
      if refresh then refresh(ctx and ctx.game) end
      return result
    end
    Commands.__ascendantCharacterShowObjectWrapped = true
  end
  Commands.__ascendantCharacterRefresh = function(game)
    refreshVisuals(game or activeGame)
  end

  -- Dramatic Shape historically exempts player TRAINER cards from its
  -- player-side mirror because the vanilla art is a back view. Casey and
  -- Blue deliberately supply standing FRONT art in Voxel, so mark only those
  -- two textures like the other player-side front cards. This changes the
  -- 3D card transform, never either source PNG.
  mod.events:once("mods.loaded", function(ev)
    installVoxelStandingTrainer(ev and ev.game or activeGame)
  end)

  -- Rival battles are created synchronously from map scripts.  Let the party
  -- hook re-assert presentation on that exact edge as well as on map entry,
  -- so an event can never carry a stale Blue/Red card from a previous save or
  -- character-selection preview.
  function M.refreshVisuals(game)
    return refreshVisuals(game or activeGame)
  end
  M.refreshCharacterDialogue = refreshCharacterDialogue
  M.selectionOrder = SELECTION_ORDER
  M.CharacterSelect = CharacterSelect
  M.rivalBattleRole = "OPP_RIVAL"
  M.voxelFallbackReceipts = voxelFallbackReceipts

  mod.hooks:wrap("intro.oak_speech.build", function(next, steps, speech)
    steps = next(steps, speech)
    mod.ui.insertStepAfter(steps, "world_spiel", {
      id = "extended_character_selection", kind = "fn", run = runSelection,
    })
    mod.ui.insertStepAfter(steps, "name_player", {
      id = "extended_character_relation", kind = "fn", run = runRelation,
    })
    mod.ui.insertStepAfter(steps, "name_rival", {
      id = "extended_rival_confirmation", kind = "fn",
      run = runRivalConfirmation,
    })

    for _, step in ipairs(steps) do
      if step.id == "name_player" then
        step.kind = "fn"
        step.run = function(activeSpeech, done)
          runPlayerNaming(activeSpeech, done, step)
        end
      elseif step.id == "ask_rival_name" then
        step.kind, step.run = "fn", runRivalIntroduction
      elseif step.id == "name_rival" then
        step.kind = "fn"
        step.run = function(activeSpeech, done)
          runRivalNaming(activeSpeech, done, step)
        end
      end
    end
    return steps
  end)

  M.saveKey = SAVE_KEY
  M.legacyState = copy(LEGACY)
  return M
end
