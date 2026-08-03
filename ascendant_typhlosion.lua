-- Kanto Ascendant's deliberately unofficial secret form.
--
-- Gold's first defeat reveals a silent Basalt Seal in Pokémon Mansion B1F.
-- The seal awakens only for a level-100 Typhlosion carried by a Trainer who
-- owns all 251 species. The resulting Basalt Core is permanent across
-- Ascendant Cycles and never appears in the official Mega Stone Case.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local johtoMasters = assert(opts.johtoMasters, "Johto Masters missing")
  local megaEvolution = assert(opts.megaEvolution, "form controller missing")
  local showMenu = opts.showMenu ~= false
  local A = { game = nil }

  local ALTAR = {
    map = "POKEMON_MANSION_B1F",
    name = "KANTO_ASCENDANT_BASALT_SEAL",
    text = "MOD_KANTO_ASCENDANT_BASALT_SEAL",
    sprite = "SPRITE_BOULDER",
    preferred = { { 8, 8 }, { 9, 8 }, { 8, 9 }, { 10, 8 } },
  }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state(create)
    local s = mod.save:get("ascendant_typhlosion")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 1, clueSeen = false, unlocked = false,
        visits = 0, awakenedAt = nil,
      }
      mod.save:set("ascendant_typhlosion", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.clueSeen = s.clueSeen == true
      s.unlocked = s.unlocked == true or megaEvolution.secretUnlocked()
      s.visits = math.max(0, math.floor(tonumber(s.visits) or 0))
      if s.unlocked then s.clueSeen = true end
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("ascendant_typhlosion", s) end
  end

  local function goldCleared()
    local s = johtoMasters.state(false)
    return s and (tonumber(s.clears) or 0) >= 1 or false
  end

  local function dexIndex(game)
    local byDex = {}
    for species, def in pairs(
        game and game.data and game.data.pokemon or {}) do
      local dex = tonumber(def.dex)
      if dex and dex >= 1 and dex <= 251 and not byDex[dex] then
        byDex[dex] = species
      end
    end
    return byDex
  end

  local function ownedCount(game)
    local owned = game and game.save and game.save.pokedex
      and game.save.pokedex.owned or {}
    local byDex, count = dexIndex(game), 0
    for dex = 1, 251 do
      local species = byDex[dex]
      if species and owned[species] then count = count + 1 end
    end
    return count
  end

  local function typhlosion(game)
    local best
    for _, mon in ipairs(game and game.save and game.save.party or {}) do
      if mon.species == "TYPHLOSION" and not mon.isEgg
          and (not best or (tonumber(mon.level) or 0)
            > (tonumber(best.level) or 0)) then
        best = mon
      end
    end
    return best
  end

  local function ready(game)
    local mon = typhlosion(game)
    return goldCleared() and ownedCount(game) >= 251
      and mon ~= nil and (tonumber(mon.level) or 0) >= 100
  end

  local function statusText(game)
    local s = state()
    if s.unlocked then
      return tr(
        "ASCENDANT\nTYPHLOSION\fBASALT CORE: AWAKE\fSELECT in battle.\nFIRE/GROUND • +100\fMOLTEN RENEWAL\nrestores 25% HP.",
        "ASCENDANT-\nTORNUPTO\fBASALT-KERN: WACH\fSELECT im Kampf.\nFEUER/BODEN • +100\fGLUT-ERNEUERUNG\nheilt 25% KP.")
    end
    local count = ownedCount(game)
    local mon = typhlosion(game)
    local level = mon and math.max(1, math.floor(tonumber(mon.level) or 1))
    return tr(
      ("BASALT SEAL\fPOKéDEX: %d/251\nVOLCANO: %s\fThe final inscription\nwaits below Cinnabar.")
        :format(count, mon and ("LV" .. level) or "MISSING"),
      ("BASALT-SIEGEL\fPOKéDEX: %d/251\nVULKAN: %s\fDie letzte Inschrift\nwartet unter Zinnober.")
        :format(count, mon and ("LV" .. level) or "FEHLT"))
  end

  local function unlock(game)
    local s = state()
    if s.unlocked then return false end
    s.clueSeen = true
    s.unlocked = true
    s.awakenedAt = {
      owned = ownedCount(game),
      goldClears = tonumber(johtoMasters.state().clears) or 0,
    }
    megaEvolution.unlockSecret()
    persist(s)
    return true
  end

  local function talk(game, ow, npc)
    local s = state()
    s.clueSeen = true
    s.visits = s.visits + 1
    persist(s)
    npc.frozen = true
    npc:facePlayer(ow.player)

    local count = ownedCount(game)
    local mon = typhlosion(game)
    local message
    if s.unlocked then
      message = tr(
        "The split BASALT SEAL\nstill radiates heat.\fYour BASALT CORE\nanswers from afar.\fASCENDANT TYPHLOSION\nawakens with SELECT.",
        "Das geborstene\nBASALT-SIEGEL glüht.\fDein BASALT-KERN\nantwortet aus der Ferne.\fASCENDANT-TORNUPTO\nerwacht mit SELECT.")
    elseif count < 251 then
      message = tr(
        ("A ring of 251 marks\nsurrounds black glass.\f%d answer your POKéDEX.\nThe rest remain cold.")
          :format(count),
        ("251 Zeichen umringen\nschwarzes Glas.\f%d antworten deinem\nPOKéDEX. Der Rest\nbleibt kalt.")
          :format(count))
    elseif not mon then
      message = tr(
        "All 251 marks ignite!\fAn inscription appears:\nBRING JOHTO'S VOLCANO.\fA familiar fire must\nstand in your PARTY.",
        "Alle 251 Zeichen glühen!\fEine Inschrift erscheint:\nBRINGE JOHTOS VULKAN.\fEin vertrautes Feuer\nmuss im TEAM stehen.")
    elseif (tonumber(mon.level) or 0) < 100 then
      message = tr(
        ("The seal answers\nTYPHLOSION, then dims.\fONLY AT THE SUMMIT.\nTYPHLOSION is LV%d.")
          :format(math.max(1, math.floor(tonumber(mon.level) or 1))),
        ("Das Siegel antwortet\nTORNUPTO und erlischt.\fNUR AUF DEM GIPFEL.\nTORNUPTO ist LV%d.")
          :format(math.max(1, math.floor(tonumber(mon.level) or 1))))
    else
      unlock(game)
      message = tr(
        "The complete POKéDEX\nresonates with GOLD's\nfinal proof!\fTYPHLOSION roars.\nThe seal splits open!\fYou obtained the\nBASALT CORE!\fA secret fire has\nchosen its ASCENDANT.",
        "Der volle POKéDEX\nreagiert mit GOLDs\nletztem Beweis!\fTORNUPTO brüllt.\nDas Siegel zerbricht!\fDu erhältst den\nBASALT-KERN!\fEin geheimes Feuer hat\nseinen ASCENDANT gewählt.")
    end
    game.stack:push(require("src.render.TextBox").new(game, message,
      function() npc.frozen = false end))
  end

  local function runtimeObjectIds(game)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[ALTAR.map]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == ALTAR.name then
        out[#out + 1] = ALTAR.map .. "_obj_" .. tostring(obj.index)
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
    for _, cell in ipairs(ALTAR.preferred) do
      if free(cell[1], cell[2]) then return cell[1], cell[2] end
    end
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if free(x, y) then return x, y end
      end
    end
  end

  local function refresh(game, mapId)
    if not (mod.world and game) then return end
    local ids = runtimeObjectIds(game)
    local should = mapId == ALTAR.map and goldCleared()
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == ALTAR.map) then return end
    local x, y = findSpawnCell(ow)
    if not x then return end
    mod.world:spawnNpc(ALTAR.map, {
      name = ALTAR.name, sprite = ALTAR.sprite,
      movement = "STAY", range = "DOWN", text = ALTAR.text,
      x = x, y = y,
    })
  end

  if mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register(ALTAR.map, {
      priority = 2450,
      talk = {
        [ALTAR.text] = function(game, ow, npc)
          talk(game, ow, npc)
        end,
      },
    })
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    local s = state()
    if type(out) ~= "table" or not showMenu
        or not (s.clueSeen or s.unlocked) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = s.unlocked and tr("SECRET FORM", "GEHEIMFORM") or "???",
      right = s.unlocked and tr("AWAKE", "WACH") or tr("SEALED", "VERS."),
      ascendantMenu = true,
      ascendantLabel = s.unlocked
        and tr("ASC. TYPHLOSION", "ASC. TORNUPTO") or "???",
      ascendantOrder = 75,
      ascendantKey = "ascendant_typhlosion",
      onSelect = function()
        game.stack:push(require("src.render.TextBox").new(
          game, statusText(game)))
      end,
    })
  end, 270)

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or A.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then refresh(game, mapId) end
  end)

  mod.events:on("save.loaded", function()
    local s = state()
    if s.unlocked and not megaEvolution.secretUnlocked() then
      megaEvolution.unlockSecret()
    end
    local ow = mod.world and mod.world:overworld()
    if A.game then refresh(A.game, ow and ow.map and ow.map.id) end
  end)

  function A.install(game)
    A.game = game
    local s = state()
    if s.unlocked and not megaEvolution.secretUnlocked() then
      megaEvolution.unlockSecret()
    end
    local ow = mod.world and mod.world:overworld()
    refresh(game, ow and ow.map and ow.map.id)
  end

  A.state = state
  A.goldCleared = goldCleared
  A.ownedCount = ownedCount
  A.typhlosion = typhlosion
  A.ready = ready
  A.unlock = unlock
  A.statusText = statusText
  A.talk = talk
  A.refresh = refresh
  A.altar = ALTAR
  return A
end
