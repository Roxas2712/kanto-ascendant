-- Selectable titles and a save-driven trophy gallery for Kanto Ascendant 5.0.
--
-- The curator appears beside Game Freak's certificate room after the Hall of
-- Fame.  The same gallery is available through the tidy Ascendant submenu.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = opts.postgame
  local ascendant = opts.ascendant
  local ascendantData = opts.ascendantData or {}
  local johtoMasters = opts.johtoMasters
  local legacyPaths = opts.legacyPaths
  local legacyJourney = opts.legacyJourney
  local L = { game = nil, grandTour = opts.grandTour }
  local HALL_VERSION = 1

  local CURATOR = {
    map = "CELADON_MANSION_3F",
    name = "KANTO_ASCENDANT_LEGACY_CURATOR",
    text = "MOD_KANTO_ASCENDANT_LEGACY_CURATOR",
    sprite = "SPRITE_GENTLEMAN",
    preferred = { { 7, 3 }, { 8, 3 }, { 7, 4 }, { 6, 3 } },
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    if type(row) ~= "table" then return row end
    return tr(row.en or row.de or "", row.de or row.en or "")
  end

  local function clippedGlyphs(text, maximum)
    local glyphs = {}
    for glyph in tostring(text or ""):gmatch(
        "[%z\1-\127\194-\244][\128-\191]*") do
      if #glyphs >= maximum then break end
      glyphs[#glyphs + 1] = glyph
    end
    return table.concat(glyphs), #glyphs
  end

  local function pactCardText(save)
    if not (legacyJourney and legacyJourney.isActive
        and legacyJourney.isActive(save)) then return nil end
    local run = legacyJourney.state and legacyJourney.state(save)
    if type(run) ~= "table" then return nil end
    local pact = legacyJourney.currentPact
      and legacyJourney.currentPact(save) or run.pact
    pact = tostring(pact or "journey"):lower()
    local names = {
      journey = { en = "PACT:JOURNEY", de = "PAKT:REISE" },
      trainer = { en = "PACT:TRAINER", de = "PAKT:TRAINER" },
      legacy = { en = "PACT:LEGACY", de = "PAKT:VERM." },
      ascendant = { en = "PACT:ASCEND.", de = "PAKT:ASCEND." },
    }
    local row = names[pact] or names.journey
    return tr(row.en, row.de)
  end

  local function state(create)
    local s = mod.save:get("legacy_hall")
    if type(s) ~= "table" and create ~= false then
      s = { version = HALL_VERSION }
      mod.save:set("legacy_hall", s)
    end
    if type(s) == "table" then
      local version = math.max(1, math.floor(tonumber(s.version) or 1))
      if version > HALL_VERSION then
        -- A newer mod owns this state. Keep its complete table byte-for-byte
        -- and expose only the ascendant fallback until a compatible build is
        -- installed; old code must never downgrade or partially rewrite it.
        L.readOnly = true
        L.futureVersion = version
        return nil
      end
      L.readOnly, L.futureVersion = false, nil
      s.version = HALL_VERSION
      if type(s.selectedTitle) ~= "string" then s.selectedTitle = nil end
      s.visits = math.max(0, math.floor(tonumber(s.visits) or 0))
    else
      L.readOnly, L.futureVersion = false, nil
    end
    return s
  end

  local function persist(s)
    if s and not L.readOnly then mod.save:set("legacy_hall", s) end
  end

  local function achievementState()
    local s = ascendant and ascendant.state and ascendant.state(false)
    return s and s.achievements or {}
  end

  local function achievementDef(id)
    for _, row in ipairs(ascendantData.achievements or {}) do
      if row.id == id then return row end
    end
  end

  local function titleName(id)
    if legacyPaths and legacyPaths.titleName then
      local name = legacyPaths.titleName(id)
      if name then return name end
    end
    local row = achievementDef(id)
    return row and localized(row.title) or nil
  end

  local function knownTitle(id)
    return type(id) == "string" and titleName(id) ~= nil
  end

  local function unlocked(id)
    if not knownTitle(id) then return false end
    if legacyPaths and legacyPaths.titleUnlocked
        and legacyPaths.titleUnlocked(id) then return true end
    return achievementDef(id) ~= nil and achievementState()[id] == true
  end

  local function currentTitle()
    local s = state()
    local a = ascendant and ascendant.state and ascendant.state(false)
    if s and s.selectedTitle and not unlocked(s.selectedTitle) then
      s.selectedTitle = nil
      persist(s)
    end
    if a and a.selectedTitle and not unlocked(a.selectedTitle) then
      a.selectedTitle = nil
      mod.save:set("ascendant", a)
    end
    if s and not s.selectedTitle and a
        and type(a.selectedTitle) == "string" then
      s.selectedTitle = a.selectedTitle
      persist(s)
    end
    if s and s.selectedTitle and unlocked(s.selectedTitle) then
      return s.selectedTitle, titleName(s.selectedTitle)
    end
    if a and a.selectedTitle and unlocked(a.selectedTitle) then
      return a.selectedTitle, titleName(a.selectedTitle)
    end
    if a and a.latestAchievement and unlocked(a.latestAchievement) then
      return a.latestAchievement, titleName(a.latestAchievement)
    end
    return nil, tr("CHAMPION", "CHAMP")
  end

  local function selectTitle(id)
    if not knownTitle(id) or not unlocked(id) then return false end
    local s = state()
    if not s then return false end
    s.selectedTitle = id
    persist(s)
    local a = ascendant and ascendant.state and ascendant.state(false)
    if a then
      a.selectedTitle = id
      mod.save:set("ascendant", a)
    end
    return true
  end

  local function ownedCount(save, maximum)
    local count = 0
    local owned = save and save.pokedex and save.pokedex.owned or {}
    local game = L.game
    if not (game and game.data and game.data.pokemon) then return 0 end
    local byDex = {}
    for species, def in pairs(game.data.pokemon) do
      local dex = tonumber(def.dex)
      if dex and dex >= 1 and dex <= maximum and not byDex[dex] then
        byDex[dex] = species
      end
    end
    for dex = 1, maximum do
      if byDex[dex] and owned[byDex[dex]] then count = count + 1 end
    end
    return count
  end

  local function trophyRows(game)
    local a = ascendant and ascendant.state and ascendant.state(false) or {}
    local p = postgame and postgame.state and postgame.state(false) or {}
    local achievements = a.achievements or {}
    local masters = johtoMasters and johtoMasters.state
      and johtoMasters.state(false) or {}
    local tour = L.grandTour and L.grandTour.state
      and L.grandTour.state(false) or {}
    local legacy = legacyPaths and legacyPaths.profile
      and legacyPaths.profile() or {}
    local completedPaths = legacy.completedPaths or {}
    local rows = {
      {
        id = "kanto_150", label = tr("KANTO CERTIFICATE", "KANTO-ZERTIFIKAT"),
        value = ownedCount(game.save, 150), target = 150,
      },
      {
        id = "kanto_151", label = tr("MYTH CERTIFICATE", "MYTHEN-ZERTIFIKAT"),
        value = ownedCount(game.save, 151), target = 151,
      },
      {
        id = "national_250", label = tr("NATIONAL CERT.", "NATIONAL-ZERT."),
        value = ownedCount(game.save, 250), target = 250,
      },
      {
        id = "complete_251", label = tr("COMPLETE CERT.", "KOMPLETT-ZERT."),
        value = ownedCount(game.save, 251), target = 251,
      },
      {
        id = "master", label = tr("MASTER CIRCUIT", "MEISTER-ZIRKEL"),
        done = achievements.master_circuit == true,
      },
      {
        id = "apex", label = tr("APEX CHAMPION", "APEX-CHAMP"),
        done = p.apexChampion == true,
      },
      {
        id = "crown", label = tr("CROWN CHAMPION", "KRONEN-CHAMP"),
        done = p.crownChampion == true,
      },
      {
        id = "rocket", label = tr("ROCKET BREAKER", "ROCKET-BRECHER"),
        done = achievements.rocket_breaker == true,
      },
      {
        id = "mew", label = tr("MYTH SEEKER", "MYTHENSUCHER"),
        done = achievements.mew_found == true,
      },
      {
        id = "frontier", label = tr("FRONTIER CHAMPION", "FRONTIER-CHAMP"),
        value = a.tournament and a.tournament.wins or 0, target = 1,
      },
      {
        id = "johto", label = tr("JOHTO MASTER", "JOHTO-MEISTER"),
        value = masters.clears or 0, target = 1,
      },
      {
        id = "factory", label = tr("FACTORY ARCHITECT", "FABRIK-ARCHITEKT"),
        value = tour.factory and tour.factory.wins or 0, target = 1,
      },
      {
        id = "cruise", label = tr("SEA CHAMPION", "MEERES-CHAMP"),
        value = tour.cruise and tour.cruise.clears or 0, target = 1,
      },
      {
        id = "legacy_red", label = tr("RED PATH SEAL", "ROTES PFADSIEGEL"),
        done = completedPaths.red == true,
      },
      {
        id = "legacy_blue", label = tr("BLUE PATH SEAL", "BLAUES PFADSIEGEL"),
        done = completedPaths.blue == true,
      },
      {
        id = "legacy_green", label = tr("GREEN PATH SEAL", "GRUENES PFADSIEGEL"),
        done = completedPaths.green == true,
      },
      {
        id = "legacy_pass", label = tr("LEGACY PASS", "VERMAECHTNIS-PASS"),
        done = legacy.legacyPass == true,
      },
    }
    for _, row in ipairs(rows) do
      if row.done == nil then
        row.done = math.max(0, tonumber(row.value) or 0)
          >= math.max(1, tonumber(row.target) or 1)
      end
      row.realLabel = row.label
      if row.done then
        row.right = tr("DISPLAYED", "AUSGEST.")
      else
        -- A covered display should not reveal the name or requirement of a
        -- future trophy. Discovery happens when the challenge is completed.
        row.label = "???"
        row.right = "???"
      end
    end
    return rows
  end

  local function trophyText(row)
    if row.done then
      return row.label .. "\f" .. tr(
        "This trophy is now on\ndisplay in Kanto's\nLegacy Gallery.",
        "Diese Trophäe steht nun\nin Kantos Vermächtnis-\nGalerie.")
    end
    return row.label .. "\f" .. tr(
      "The display remains\ncovered until its\nchallenge is complete.",
      "Die Vitrine bleibt\nverhüllt, bis die\nPrüfung bestanden ist.")
  end

  local function titleRows()
    local selected = currentTitle()
    local rows = {}
    for _, row in ipairs(ascendantData.achievements or {}) do
      if unlocked(row.id) then
        rows[#rows + 1] = {
          label = localized(row.title),
          right = selected == row.id and tr("ACTIVE", "AKTIV") or "",
          value = row.id,
        }
      end
    end
    if legacyPaths and legacyPaths.titleRows then
      for _, entry in ipairs(legacyPaths.titleRows(selected)) do
        rows[#rows + 1] = entry
      end
    end
    if #rows == 0 then
      rows[1] = {
        label = tr("NO TITLES EARNED", "NOCH KEIN TITEL"),
        value = false,
      }
    end
    return rows
  end

  if mod.content and mod.content.screens then
    mod.content.screens:register("AscendantTitles", {
      new = function(game)
        return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game, tr("SELECT TITLE", "TITEL WÄHLEN"),
          titleRows(), {
            pageJump = true,
            onChoose = function(item, menu)
              if not item.value then return end
              selectTitle(item.value)
              menu:close()
              game.stack:push(require("src.render.TextBox").new(game,
                tr("ACTIVE TITLE:\n", "AKTIVER TITEL:\n")
                  .. titleName(item.value)))
            end,
          })
      end,
    })

    mod.content.screens:register("AscendantTrophies", {
      new = function(game)
        local rows = trophyRows(game)
        local items = {}
        for index, row in ipairs(rows) do
          items[index] = {
            label = row.label, right = row.right, value = row,
          }
        end
        return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
          tr("LEGACY GALLERY", "VERMÄCHTNIS-GALERIE"), items, {
            pageJump = true,
            onChoose = function(item)
              game.stack:push(require("src.render.TextBox").new(game,
                trophyText(item.value)))
            end,
          })
      end,
    })
  end

  local function open(game)
    local _, title = currentTitle()
    local workshop = mod.exports and mod.exports.ngplusLegacyWorkshop
    local rows = {
        {
          label = tr("SELECT TITLE", "TITEL WÄHLEN"),
          right = title, value = "titles",
        },
        {
          label = tr("LEGACY GALLERY", "VERMÄCHTNIS-GALERIE"),
          value = "trophies",
        },
      }
    if workshop and workshop.ANCHOR
        and workshop.ANCHOR.status == "CONNECTED" then
      rows[#rows + 1] = {
        label = tr("LEGACY WORKSHOP", "VERMÄCHTNISWERKSTATT"),
        right = tostring(workshop.sealCount and workshop.sealCount(game.save)
          or 0) .. "/3",
        value = "workshop",
      }
    end
    local menu
    menu = (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
      tr("TITLES / TROPHIES", "TITEL / TROPHÄEN"), rows, {
        onChoose = function(item)
          if item.value == "titles" then
            mod.ui.push(game, "AscendantTitles")
          elseif item.value == "trophies" then
            mod.ui.push(game, "AscendantTrophies")
          elseif item.value == "workshop" then
            if menu and type(menu.close) == "function" then menu:close() end
            local ok, why = workshop.enter(game)
            if not ok then
              game.stack:push(require("src.render.TextBox").new(game,
                tr("The workshop route is unavailable.",
                  "Der Weg zur Werkstatt ist nicht verfügbar.")
                  .. "\n" .. tostring(why or "unknown")))
            end
          end
        end,
      })
    game.stack:push(menu)
  end

  function L.open(game) return open(game) end

  local function runtimeObjectIds(game)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[CURATOR.map]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == CURATOR.name then
        out[#out + 1] = CURATOR.map .. "_obj_" .. tostring(obj.index)
      end
    end
    return out
  end

  local function findSpawnCell(ow)
    local function free(x, y)
      return ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
        and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
        and not (ow.player.cellX == x and ow.player.cellY == y)
    end
    for _, cell in ipairs(CURATOR.preferred) do
      if free(cell[1], cell[2]) then return cell[1], cell[2] end
    end
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if free(x, y) then return x, y end
      end
    end
  end

  local function refresh(game, mapId)
    if not (game and mod.world) then return end
    local should = mapId == CURATOR.map and postgame
      and postgame.hasHallOfFame(game.save)
    local ids = runtimeObjectIds(game)
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == CURATOR.map) then return end
    local x, y = findSpawnCell(ow)
    if not x then return end
    mod.world:spawnNpc(CURATOR.map, {
      name = CURATOR.name, sprite = CURATOR.sprite,
      movement = "STAY", range = "DOWN", text = CURATOR.text,
      x = x, y = y,
    })
  end

  if mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register(CURATOR.map, {
      priority = 2550,
      talk = {
        [CURATOR.text] = function(game, ow, npc)
          local s = state()
          if s then
            s.visits = s.visits + 1
            persist(s)
          end
          npc.frozen = true
          npc:facePlayer(ow.player)
          game.stack:push(require("src.render.TextBox").new(game, tr(
            "CURATOR: Every great\njourney leaves a mark.\fChoose the title Kanto\nwill remember, or view\nyour trophy displays.",
            "KURATOR: Jede große\nReise hinterlässt Spuren.\fWähle deinen Titel oder\nsieh deine Trophäen an."),
            function()
              npc.frozen = false
              open(game)
            end))
        end,
      },
    })
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" or not (postgame
        and postgame.hasHallOfFame(game.save)) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("LEGACY", "VERMÄCHTNIS"),
      ascendantMenu = true,
      ascendantLabel = tr("TITLES / TROPHIES", "TITEL / TROPHÄEN"),
      ascendantOrder = 80,
      onSelect = function() open(game) end,
    })
  end, 240)

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or L.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then refresh(game, mapId) end
  end)

  mod.events:on("save.loaded", function()
    state()
    local ow = mod.world and mod.world:overworld()
    if L.game then refresh(L.game, ow and ow.map and ow.map.id) end
  end)

  function L.install(game)
    L.game = game
    state()
    local ow = mod.world and mod.world:overworld()
    refresh(game, ow and ow.map and ow.map.id)

    local ok, TrainerCard = pcall(require, "src.ui.TrainerCard")
    if ok and TrainerCard and not TrainerCard._ascendantSelectableTitleWrapped then
      TrainerCard._ascendantSelectableTitleWrapped = true
      local draw = TrainerCard.draw
      TrainerCard.draw = function(card)
        draw(card)
        local _, title = currentTitle()
        if not (love and love.graphics) then return end
        local g = love.graphics
        -- The badge banner has room for 18 actual glyphs. Count UTF-8
        -- characters rather than bytes so titles such as VETERANENJÄGER are
        -- neither shortened early nor centred as if Ä occupied two tiles.
        local Font = require("src.render.Font")
        if title then
          local shown, glyphCount = clippedGlyphs(title:upper(), 18)
          g.setColor(1, 1, 1, 1)
          g.rectangle("fill", 8, 68, 144, 15)
          g.setColor(0, 0, 0, 1)
          local width = glyphCount * 8
          Font.draw(shown, math.max(8, 80 - math.floor(width / 2)), 71)
        end
        local pact = pactCardText(card.game and card.game.save)
        if pact then
          -- A compact top-border label leaves NAME/MONEY/TIME, portrait and
          -- the independent selected-title banner untouched.
          g.setColor(1, 1, 1, 1)
          g.rectangle("fill", 8, 3, 96, 9)
          g.setColor(0, 0, 0, 1)
          Font.draw(pact, 8, 4)
        end
        g.setColor(1, 1, 1, 1)
      end
    end
  end

  function L.setGrandTour(controller)
    L.grandTour = controller
  end

  L.state = state
  L.currentTitle = currentTitle
  L.selectTitle = selectTitle
  L.titleRows = titleRows
  L.trophyRows = trophyRows
  L.pactCardText = pactCardText
  L.refresh = refresh
  L.hallVersion = HALL_VERSION
  return L
end
