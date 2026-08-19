-- Kanto Ascendant's self-contained Generation-II shiny system.
--
-- Shininess is stored in the Pokémon's four Gen-I DVs, exactly as Crystal
-- interprets traded R/B/Y Pokémon. The save data therefore remains useful
-- even if this mod, its visual effects, or an optional indicator mod are
-- changed later.

local SHINY_ATTACK = {
  [2] = true, [3] = true, [6] = true, [7] = true,
  [10] = true, [11] = true, [14] = true, [15] = true,
}

local OUTBREAKS = {
  { map = "ROUTE_1", species = "SENTRET" },
  { map = "ROUTE_2", species = "SPINARAK" },
  { map = "ROUTE_4", species = "PHANPY" },
  { map = "ROUTE_6", species = "MAREEP" },
  { map = "ROUTE_8", species = "HOUNDOUR" },
  { map = "ROUTE_12", species = "MARILL" },
  { map = "ROUTE_15", species = "YANMA" },
  { map = "ROUTE_21", species = "CORSOLA" },
  { map = "ROUTE_22", species = "DUNSPARCE" },
  { map = "ROUTE_24", species = "NATU" },
}

local EVENT_MAP = "SEAFOAM_ISLANDS_B4F"
local EVENT_SPECIES = "GYARADOS"
local EVENT_LEVEL = 50
local EVENT_STREAK = 25

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = opts.postgame
  local S = { game = nil, odds = 8192 }
  local pendingForce
  local worldEvents
  local johtoResearch
  local battleEffects = setmetatable({}, { __mode = "k" })
  local chimeData
  local chimeSources = {}
  local derived = {}
  -- Kept split because this is only a recognizer for the transform output,
  -- never a runtime read of the player's imported cache.
  local SOURCE_PREFIX = "assets/" .. "generated/"

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function state(create)
    local s = mod.save:get("shiny_system")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 1, seen = {}, caught = {}, rematchStreak = 0,
        bestStreak = 0, totalRematchWins = 0, outbreakIndex = 0,
        encounters = {}, caughtCounts = {}, awards = {},
      }
      mod.save:set("shiny_system", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.seen = type(s.seen) == "table" and s.seen or {}
      s.caught = type(s.caught) == "table" and s.caught or {}
      s.encounters = type(s.encounters) == "table" and s.encounters or {}
      s.caughtCounts = type(s.caughtCounts) == "table"
        and s.caughtCounts or {}
      s.awards = type(s.awards) == "table" and s.awards or {}
      s.rematchStreak = math.max(0,
        math.floor(tonumber(s.rematchStreak) or 0))
      s.bestStreak = math.max(s.rematchStreak,
        math.floor(tonumber(s.bestStreak) or 0))
      s.totalRematchWins = math.max(0,
        math.floor(tonumber(s.totalRematchWins) or 0))
      s.outbreakIndex = math.max(0,
        math.floor(tonumber(s.outbreakIndex) or 0))
      if type(s.outbreak) == "table" then
        s.outbreak.steps = math.max(0,
          math.floor(tonumber(s.outbreak.steps) or 0))
        if s.outbreak.steps == 0 then s.outbreak = nil end
      end
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("shiny_system", s) end
  end

  function S.isShiny(mon)
    if type(mon) ~= "table" then return false end
    if mon.shiny == true then return true end
    local dvs = mon.dvs
    if type(dvs) ~= "table" then return false end
    local ok, Stats = pcall(require, "src.pokemon.Stats")
    if ok and Stats and Stats.isShiny then return Stats.isShiny(dvs) end
    return dvs.defense == 10 and dvs.speed == 10 and dvs.special == 10
      and SHINY_ATTACK[dvs.attack] == true
  end

  function S.forceMon(mon, def)
    if type(mon) ~= "table" then return false end
    local oldMax = mon.stats and mon.stats.hp or math.max(1, mon.hp or 1)
    local oldHP = math.max(0, tonumber(mon.hp) or oldMax)
    mon.shiny = nil
    mon.dvs = {
      attack = 10, defense = 10, speed = 10, special = 10, hp = 0,
    }
    if def and def.baseStats then
      local ok, Stats = pcall(require, "src.pokemon.Stats")
      if ok and Stats and Stats.calc then
        mon.stats = Stats.calc(
          def, mon.level or 1, mon.dvs, mon.statExp, mon)
        mon.hp = math.max(1, math.min(mon.stats.hp,
          math.floor(oldHP / math.max(1, oldMax) * mon.stats.hp + 0.5)))
      end
    end
    return true
  end

  local function externalApi()
    local ok, handle = false, nil
    if mod and type(mod.find) == "function" then
      ok, handle = pcall(function() return mod.find("shiny_indicators") end)
    end
    local api = ok and type(handle) == "table" and handle.exports or nil
    return type(api) == "table" and api or nil
  end

  local function crystalVisualsActive(mon)
    local loaded = false
    if mod and type(mod.find) == "function" then
      local ok, handle = pcall(function()
        return mod.find("crystal_animated_sprites_with_shiny_visuals")
      end)
      loaded = ok and type(handle) == "table"
        and type(handle.exports) == "table"
    end
    if not (loaded and mon and mon.species) then return false end
    local def = S.game and S.game.data and S.game.data.pokemon
      and S.game.data.pokemon[mon.species]
    return def and (tonumber(def.dex) or 9999) <= 151 or false
  end

  function S.externalActive(mon)
    -- shiny_indicators owns every species. Crystal Animated Sprites currently
    -- owns only Kanto, so Ascendant keeps its Johto sparkle/summary behavior.
    return externalApi() ~= nil or crystalVisualsActive(mon)
  end

  local function huntingMode()
    return mod.options:get("shiny_hunts") or "ascendant"
  end

  local function eventEnabled()
    return huntingMode() == "ascendant"
      and mod.options:get("shiny_event") ~= false
  end

  local function ownedCount(game)
    local n = 0
    local owned = game and game.save and game.save.pokedex
      and game.save.pokedex.owned or {}
    for id, def in pairs(game and game.data and game.data.pokemon or {}) do
      if (tonumber(def.dex) or 9999) <= 251 and owned[id] then n = n + 1 end
    end
    return n
  end

  local function unlockCharm(game)
    local s = state()
    if s.charm or ownedCount(game) < 251 then return false end
    s.charm = true
    s.pendingCharm = true
    game.save.inventory = game.save.inventory or {}
    local ok, Bag = pcall(require, "src.inventory.Bag")
    if ok and Bag and Bag.add then
      if not Bag.add(game.save, "SHINY_CHARM", 1, game.data) then
        -- Key-item rewards must not disappear because the ordinary item
        -- pocket happened to be full at the instant #251 was registered.
        game.save.inventory.SHINY_CHARM = 1
      end
    else
      game.save.inventory.SHINY_CHARM = 1
    end
    persist(s)
    return true
  end

  function S.hasCharm()
    local s = state(false)
    return s and s.charm == true or false
  end

  local function mark(bucket, mon)
    if not S.isShiny(mon) or not mon.species then return false end
    local s = state()
    s[bucket][mon.species] = true
    if bucket == "caught" then s.seen[mon.species] = true end
    persist(s)
    return true
  end

  function S.markSeen(mon) return mark("seen", mon) end
  function S.markCaught(mon)
    local changed = mark("caught", mon)
    if S.game then unlockCharm(S.game) end
    return changed
  end
  function S.shinySeen(species)
    local s = state(false)
    return s and s.seen[species] == true or false
  end
  function S.shinyCaught(species)
    local s = state(false)
    return s and s.caught[species] == true or false
  end

  local function scanSave(game)
    local function scan(mon)
      if S.isShiny(mon) and mon.species then
        local s = state()
        s.seen[mon.species], s.caught[mon.species] = true, true
      end
    end
    for _, mon in ipairs(game.save.party or {}) do scan(mon) end
    for _, box in ipairs(game.save.boxes or {}) do
      for _, mon in ipairs(box) do scan(mon) end
    end
    if game.save.box then
      for _, mon in ipairs(game.save.box) do scan(mon) end
    end
    local daycare = mod.save:get("daycare_plus")
    for _, row in ipairs(type(daycare) == "table" and daycare.parents or {}) do
      scan(row and row.mon)
    end
    persist(state())
    unlockCharm(game)
  end

  local function extraRolls(s)
    if huntingMode() ~= "ascendant" then return 0 end
    local rolls = s.charm and 2 or 0
    local streak = s.rematchStreak
    if streak >= 50 then rolls = rolls + 7
    elseif streak >= 25 then rolls = rolls + 3
    elseif streak >= 10 then rolls = rolls + 1 end
    if worldEvents and worldEvents.shinyBonusRolls then
      rolls = rolls + math.max(0,
        math.floor(tonumber(worldEvents.shinyBonusRolls()) or 0))
    end
    return rolls
  end

  local function rollBonus(ctx, count)
    for _ = 1, count do
      if ctx.rng(1, S.odds) == 1 then return true end
    end
    return false
  end

  local function currentOutbreak(s, mapId)
    return s.outbreak and s.outbreak.steps > 0
      and s.outbreak.map == mapId and s.outbreak or nil
  end

  local function outbreaksUnlocked(game)
    if not (game and postgame and postgame.hasHallOfFame(game.save)
        and johtoResearch) then
      return false
    end
    local research = johtoResearch.state(false)
    return research and johtoResearch.allStarters(research) or false
  end

  local function startOutbreak(s)
    s.outbreakIndex = s.outbreakIndex + 1
    local row = OUTBREAKS[((s.outbreakIndex - 1) % #OUTBREAKS) + 1]
    s.outbreak = {
      map = row.map, species = row.species, steps = 2048, announced = false,
    }
    return s.outbreak
  end

  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    local out = nextRoll(encDef, ctx)
    pendingForce = nil
    if not (out and S.game and ctx) then return out end
    local s = state()
    local outbreak = huntingMode() == "ascendant"
      and outbreaksUnlocked(S.game)
      and currentOutbreak(s, ctx.mapId) or nil
    if outbreak and ctx.rng(1, 4) == 1 then
      out = { species = outbreak.species, level = out.level }
    end
    if eventEnabled() and s.redGyaradosUnlocked
        and not s.redGyaradosCaught and ctx.mapId == EVENT_MAP then
      out = { species = EVENT_SPECIES, level = EVENT_LEVEL }
      pendingForce = { species = EVENT_SPECIES, event = true }
      return out
    end
    local rolls = extraRolls(s)
    if outbreak then rolls = rolls + 15 end
    if rollBonus(ctx, rolls) then
      pendingForce = { species = out.species }
    end
    return out
  end, 180)

  -- Called from the high-priority sprite preflight before any visual wrapper
  -- selects a bitmap. This timing makes a boosted encounter genuinely shiny
  -- from its first visible frame, including with non-delegating Crystal art.
  function S.prepareSprite(ctx)
    if not (pendingForce and ctx and ctx.mon and ctx.side == "front"
        and ctx.kind == "battle" and ctx.species == pendingForce.species) then
      return false
    end
    local def = ctx.data and ctx.data.pokemon
      and ctx.data.pokemon[ctx.species]
    local event = pendingForce.event
    S.forceMon(ctx.mon, def)
    pendingForce = nil
    if event then ctx.mon.ascendantShinyEvent = true end
    return true
  end

  local function derivedShinyPath(path)
    if type(path) ~= "string" then return nil end
    local rel = path:sub(1, #SOURCE_PREFIX) == SOURCE_PREFIX
      and path:sub(#SOURCE_PREFIX + 1) or nil
    if not rel then return nil end
    local candidate = "save/mod-derived/" .. mod.id .. "/shiny/" .. rel
    if derived[candidate] == nil then
      -- love.image is allowed in the 0.1.86 sandbox and gives us a stronger
      -- probe than a filesystem stat: missing *and corrupt* transform output
      -- both fail closed to the original sprite. Do not infer existence from
      -- a source path; AssetTransform can legitimately skip a failed decode.
      local exists = false
      local okAssets, Assets = pcall(require, "src.render.Assets")
      if okAssets and Assets and type(Assets.exists) == "function" then
        local ok, value = pcall(Assets.exists, candidate)
        exists = ok and value == true
      end
      local readable, image = false, nil
      if exists and love and love.image and love.image.newImageData then
        readable, image = pcall(love.image.newImageData, candidate)
      end
      derived[candidate] = exists and readable and image ~= nil or false
    end
    return derived[candidate] and candidate or nil
  end

  function S.spritePath(path, ctx)
    if S.externalActive(ctx and ctx.mon)
        or mod.options:get("shiny_effects") == false
        or not (ctx and S.isShiny(ctx.mon)) then return path end
    local candidate = derivedShinyPath(path)
    if candidate then ctx.trueColor = true; return candidate end
    return path
  end

  local function makeChime()
    if chimeData ~= nil then return chimeData or nil end
    chimeData = false
    if not (love and love.sound and love.sound.newSoundData) then return nil end
    local ok, data = pcall(function()
      local rate, duration = 22050, 0.30
      local sound = love.sound.newSoundData(
        math.floor(rate * duration), rate, 16, 1)
      for i = 0, sound:getSampleCount() - 1 do
        local t = i / rate
        local frequency = t < 0.12 and 1318.51 or 1760.00
        local phase = (t * frequency) % 1
        local envelope = math.max(0, 1 - t / duration)
        sound:setSample(i,
          (phase < 0.5 and 1 or -1) * 0.16 * envelope)
      end
      return sound
    end)
    if ok and data then chimeData = data end
    return chimeData or nil
  end

  local function playChime(mon)
    if S.externalActive(mon) or mod.options:get("shiny_effects") == false
        or not (love and love.audio and love.audio.newSource) then return end
    local data = makeChime()
    if not data then return end
    local ok, source = pcall(love.audio.newSource, data)
    if ok and source then source:play(); chimeSources[#chimeSources + 1] = source end
  end

  local function reapChimes()
    for i = #chimeSources, 1, -1 do
      local ok, playing = pcall(chimeSources[i].isPlaying, chimeSources[i])
      if not ok or not playing then table.remove(chimeSources, i) end
    end
  end

  local STATUS_ICON = {
    ".#......", "###.....", ".#....#.", ".....###",
    "......#.", "...#....", "..###...", "...#....",
  }

  local function drawIcon(x, y, gold)
    local g = love.graphics
    g.setColor(gold and 1 or 0, gold and 0.82 or 0,
      gold and 0.08 or 0, 1)
    for row, pixels in ipairs(STATUS_ICON) do
      for column = 1, 8 do
        if pixels:sub(column, column) == "#" then
          g.rectangle("fill", x + column - 1, y + row - 1, 1, 1)
        end
      end
    end
  end

  local function visible(battle, side)
    if (battle.introSlide or 0) > 0 then return false end
    if side == "enemy" then
      return not battle.showEnemyTrainer and not battle.enemySendingOut
    end
    return not battle.showPlayerBack and not battle.sendingOut
  end

  local function markerPosition(battle, side)
    if battle.wideLayout and battle:wideLayout() then
      return side == "enemy" and 132 or 170, side == "enemy" and 6 or 62
    end
    return side == "enemy" and 90 or 58, side == "enemy" and 6 or 62
  end

  mod.hooks:wrap("battle.overlay", function(nextOverlay, battle)
    nextOverlay(battle)
    if mod.options:get("shiny_effects") == false
        or not (battle and love and love.graphics) then return end
    local effects = battleEffects[battle]
    if not effects then
      effects = { announced = setmetatable({}, { __mode = "k" }), age = {} }
      battleEffects[battle] = effects
    end
    for _, side in ipairs({ "enemy", "player" }) do
      local battler = battle[side]
      if battler and not S.externalActive(battler.mon)
          and S.isShiny(battler.mon) and visible(battle, side) then
        if not effects.announced[battler] then
          effects.announced[battler] = true
          effects.age[battler] = battle.frame or 0
          playChime(battler.mon)
        end
        local x, y = markerPosition(battle, side)
        drawIcon(x, y, true)
        local age = (battle.frame or 0) - (effects.age[battler] or 0)
        if age < 48 then
          local radius = 10 + age * 0.5
          for n = 0, 3 do
            local angle = n * math.pi / 2 + age * 0.08
            drawIcon(x + math.floor(math.cos(angle) * radius),
              y + math.floor(math.sin(angle) * radius), true)
          end
        end
      end
    end
    love.graphics.setColor(1, 1, 1, 1)
    reapChimes()
  end, 80)

  local function showPending(game)
    local s = state()
    local text
    if s.pendingCharm then
      s.pendingCharm = nil
      text = tr(
        "OAK: Magnificent!\fAll 251 POKéMON are\nrecorded!\fTake the SHINY\nCHARM. It grants two\nextra shiny rolls.",
        "EICH: Grossartig!\fAlle 251 POKéMON\nsind erfasst!\fNimm den GLANZ-\nPIN. Er gewährt zwei\nweitere Shiny-Würfe.")
    elseif outbreaksUnlocked(game)
        and s.outbreak and not s.outbreak.announced then
      s.outbreak.announced = true
      local name = game.data.pokemon[s.outbreak.species]
      text = tr(
        ("OAK: A swarm of %s\nwas sighted on %s!\fShiny odds are much\nhigher for 2048 steps.")
          :format(name and name.name or s.outbreak.species,
            s.outbreak.map:gsub("_", " ")),
        ("EICH: Ein Schwarm %s\nwurde auf %s gesichtet!\fFür 2048 Schritte ist\ndie Shiny-Chance dort\nstark erhöht.")
          :format(name and name.name or s.outbreak.species,
            s.outbreak.map:gsub("_", " ")))
    elseif s.redGyaradosUnlocked and not s.redGyaradosAnnounced
        and not s.redGyaradosCaught then
      s.redGyaradosAnnounced = true
      text = tr(
        "OAK: An unusual red\nGYARADOS was sighted\ndeep in SEAFOAM!\fIt will keep returning\nuntil it is caught.",
        "EICH: Tief in den\nSEESCHAUMINSELN wurde\nein rotes GARADOS\ngesichtet!\fEs kehrt zurück, bis\ndu es fängst.")
    end
    persist(s)
    if text and game.stack then
      game.stack:push(require("src.render.TextBox").new(game, text))
    end
  end

  function S.afterRematch(game, battle)
    local s = state()
    s.rematchStreak = s.rematchStreak + 1
    s.bestStreak = math.max(s.bestStreak, s.rematchStreak)
    s.totalRematchWins = s.totalRematchWins + 1
    local pages = {}
    if huntingMode() == "ascendant" and outbreaksUnlocked(game)
        and s.rematchStreak % 10 == 0 then
      local outbreak = startOutbreak(s)
      local def = game.data.pokemon[outbreak.species]
      pages[#pages + 1] = tr(
        ("OAK called: A %s swarm\nis active on %s!")
          :format(def and def.name or outbreak.species,
            outbreak.map:gsub("_", " ")),
        ("EICH ruft an: Ein %s-\nSchwarm ist auf %s!")
          :format(def and def.name or outbreak.species,
            outbreak.map:gsub("_", " ")))
      outbreak.announced = true
    end
    if eventEnabled() and not s.redGyaradosUnlocked
        and s.rematchStreak >= EVENT_STREAK
        and (not postgame or postgame.hasHallOfFame(game.save)) then
      s.redGyaradosUnlocked = true
      pages[#pages + 1] = tr(
        "OAK: Your streak stirred\nsomething in SEAFOAM.\fA red GYARADOS has\nappeared in the depths!",
        "EICH: Deine Serie hat\netwas in den Inseln\ngeweckt.\fEin rotes GARADOS ist\nin der Tiefe erschienen!")
    end
    persist(s)
    return #pages > 0 and table.concat(pages, "\f") or nil
  end

  function S.onHatched(game, mon)
    if S.isShiny(mon) then S.markCaught(mon) end
    unlockCharm(game)
  end

  if mod.content and mod.content.items then
    mod.content.items:register("SHINY_CHARM", {
      id = "SHINY_CHARM", name = tr("SHINY CHARM", "GLANZ-PIN"),
      price = 0, tossable = false, needsTarget = false,
    })
  end

  if mod.content and mod.content.screens then
    mod.content.screens:register("AscendantShinyDex", {
      new = function(game)
        local rows, totalCaught, totalSeen = {}, 0, 0
        local species = {}
        local pokedex = game.save and game.save.pokedex or {}
        local known = pokedex.seen or {}
        local owned = pokedex.owned or {}
        for id, def in pairs(game.data.pokemon or {}) do
          if (tonumber(def.dex) or 9999) <= 251
              or (id == "GOROCHU" and (known[id] or owned[id])) then
            species[#species + 1] = { id = id, def = def }
          end
        end
        table.sort(species, function(a, b)
          return (a.def.dex or 9999) < (b.def.dex or 9999)
        end)
        for _, row in ipairs(species) do
          local caught, seen = S.shinyCaught(row.id), S.shinySeen(row.id)
          if caught then totalCaught = totalCaught + 1 end
          if seen then totalSeen = totalSeen + 1 end
          rows[#rows + 1] = {
            label = seen and ("%03d %s"):format(row.def.dex, row.def.name)
              or ("%03d -----"):format(row.def.dex),
            ball = caught or nil,
            value = seen and row.id or nil,
          }
        end
        return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game,
          tr(("SHINY DEX %d/%d"):format(totalCaught, totalSeen),
             ("SHINY-DEX %d/%d"):format(totalCaught, totalSeen)),
          rows, {
            footer = tr(
              ("SEEN %d  OWNED %d"):format(totalSeen, totalCaught),
              ("GESEHEN %d  GEF. %d"):format(totalSeen, totalCaught)),
            pageJump = true,
            onChoose = function(item)
              if not item.value then return end
              local s = state()
              local status = s.caught[item.value]
                and tr("SHINY CAUGHT", "SHINY GEFANGEN")
                or (s.seen[item.value]
                  and tr("SHINY SEEN", "SHINY GESEHEN")
                  or tr("NO SHINY RECORD", "KEIN SHINY-EINTRAG"))
              status = status .. ("\f%s: %d\n%s: %d"):format(
                tr("ENCOUNTERS", "BEGEGNUNGEN"),
                math.max(0, tonumber(s.encounters[item.value]) or 0),
                tr("SHINY CAUGHT", "SHINYS GEFANGEN"),
                math.max(0, tonumber(s.caughtCounts[item.value]) or 0))
              game.stack:push(require("src.render.TextBox").new(game, status))
            end,
          })
      end,
    })
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" or (postgame
        and not postgame.hasHallOfFame(game.save)) then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("SHINY", "SHINY"),
      ascendantMenu = true,
      ascendantLabel = tr("SHINY DEX", "SHINY-DEX"),
      ascendantOrder = 40,
      onSelect = function() mod.ui.push(game, "AscendantShinyDex") end,
    })
  end, 250)

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not battle then return end
    if battle.kind == "wild" and battle.enemy and battle.enemy.mon
        and battle.enemy.mon.species then
      local s = state()
      local species = battle.enemy.mon.species
      s.encounters[species] = math.max(0,
        math.floor(tonumber(s.encounters[species]) or 0)) + 1
      persist(s)
    end
    if battle.enemy and S.isShiny(battle.enemy.mon) then
      S.markSeen(battle.enemy.mon)
      if battle.enemy.mon.ascendantShinyEvent then
        battle.ascendantShinyEvent = true
      end
    end
  end)

  mod.events:on("pokemon.caught", function(ev)
    if ev and ev.mon then
      local shiny = S.isShiny(ev.mon)
      S.markCaught(ev.mon)
      if shiny and ev.mon.species then
        local s = state()
        s.caughtCounts[ev.mon.species] = math.max(0,
          math.floor(tonumber(s.caughtCounts[ev.mon.species]) or 0)) + 1
        local unique = 0
        for _, caught in pairs(s.caught) do if caught then unique = unique + 1 end end
        if unique >= 10 then s.awards.spark = true end
        if unique >= 50 then s.awards.radiance = true end
        if unique >= 251 then s.awards.prismatic = true end
        persist(s)
      end
      if ev.mon.ascendantShinyEvent then
        local s = state()
        s.redGyaradosCaught = true
        persist(s)
      end
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if battle then battleEffects[battle] = nil end
    if battle and battle.rematchTrainerClass and ev.result ~= "win" then
      local s = state()
      s.rematchStreak = 0
      persist(s)
    end
    reapChimes()
  end)

  mod.events:on("world.stepped", function()
    if not S.game then return end
    local s = state()
    if s.outbreak and not outbreaksUnlocked(S.game) then
      -- Remove swarms created by older versions before their research gate.
      s.outbreak = nil
      persist(s)
    end
    if s.outbreak then
      s.outbreak.steps = s.outbreak.steps - 1
      if s.outbreak.steps <= 0 then s.outbreak = nil end
      persist(s)
    end
    if (tonumber(mod.save:get("step_clock", 0)) or 0) % 64 == 0 then
      unlockCharm(S.game)
      showPending(S.game)
    end
  end)

  mod.events:on("map.entered", function(ev)
    if ev and ev.game then S.game = ev.game end
    if S.game then showPending(S.game) end
  end)

  mod.events:on("save.loaded", function()
    state()
    if S.game then scanSave(S.game) end
  end)

  mod.events:on("assets.transformed", function(ev)
    if ev and ev.modId == mod.id then derived = {} end
  end)

  function S.install(game)
    S.game = game
    state()
    scanSave(game)
    local ok, SummaryMenu = pcall(require, "src.ui.SummaryMenu")
    if not S.externalActive() and ok and type(SummaryMenu) == "table"
        and not SummaryMenu._kantoAscendantShinyIconWrapped then
      local draw = SummaryMenu.draw
      SummaryMenu.draw = function(screen, ...)
        draw(screen, ...)
        if mod.options:get("shiny_effects") ~= false
            and S.isShiny(screen.mon) and love and love.graphics then
          drawIcon(152, 0, false)
          love.graphics.setColor(1, 1, 1, 1)
        end
      end
      SummaryMenu._kantoAscendantShinyIconWrapped = true
    end

    local boxOk, BoxMenu = pcall(require, "src.ui.BoxMenu")
    if boxOk and BoxMenu and not BoxMenu._ascendantShinyReleaseWrapped then
      BoxMenu._ascendantShinyReleaseWrapped = true
      local newBoxMenu = BoxMenu.new
      BoxMenu.new = function(boxGame)
        local menu = newBoxMenu(boxGame)
        local releaseItem = menu and menu.items and menu.items[3]
        if not releaseItem then return menu end
        releaseItem.onSelect = function()
          local Boxes = require("src.pokemon.Boxes")
          local box = Boxes.active(boxGame.save)
          local TextBox = require("src.render.TextBox")
          if #box == 0 then
            boxGame.stack:push(TextBox.new(boxGame,
              tr("There are no POKéMON\nin this BOX.",
                 "In dieser BOX sind\nkeine POKéMON.")))
            return
          end
          local rows = {}
          for index, mon in ipairs(box) do
            local def = boxGame.data.pokemon[mon.species]
            rows[#rows + 1] = {
              label = ("%s :L%d"):format(
                mon.nickname or (def and def.name) or mon.species,
                mon.level or 0),
              value = index,
            }
          end
          boxGame.stack:push((mod.ui.KantoListMenu or mod.ui.ListMenu).new(boxGame,
            tr("RELEASE POKéMON", "POKéMON FREILASSEN"), rows, {
              -- This is a vertical safety list, not Modern Storage's 5x4
              -- transfer grid. Keep native ListMenu input/scroll ownership.
              ascendantStorageGrid = false,
              onChoose = function(item, list)
                local mon = box[list.index]
                if not mon then return end
                local def = boxGame.data.pokemon[mon.species]
                local name = mon.nickname or (def and def.name) or mon.species
                if mod.options:get("shiny_protection") ~= false
                    and S.isShiny(mon) then
                  boxGame.stack:push(TextBox.new(boxGame, tr(
                    ("%s is shiny and\nprotected from release.\fDisable SHINY RELEASE\nLOCK in mod options\nonly if intentional.")
                      :format(name),
                    ("%s ist ein Shiny und\nvor Freilassen geschützt.\fDeaktiviere SHINY-SCHUTZ\nnur ganz bewusst.")
                      :format(name))))
                  return
                end
                boxGame.stack:push(TextBox.new(boxGame, tr(
                  ("Once released,\n%s is gone forever.\nOK?"):format(name),
                  ("%s wird endgültig\nfreigelassen. OK?"):format(name)),
                  function()
                    boxGame.stack:push(require("src.ui.ChoiceBox").new(
                      boxGame, function(yes)
                        if not yes then return end
                        table.remove(box, list.index)
                        pcall(require("src.core.Sound").playCry,
                          boxGame.data, mon.species)
                        boxGame.stack:push(TextBox.new(boxGame, tr(
                          ("%s was released."):format(name),
                          ("%s wurde freigelassen."):format(name))))
                        list:removeCurrent()
                      end, { defaultNo = true, noSound = true }))
                  end))
              end,
            }))
        end
        return menu
      end
    end
  end

  S.state = state
  S.outbreaks = OUTBREAKS
  S.eventMap = EVENT_MAP
  S.eventSpecies = EVENT_SPECIES
  S.eventStreak = EVENT_STREAK
  S.extraRolls = function() return extraRolls(state()) end
  S.setWorldEvents = function(controller) worldEvents = controller end
  S.setJohtoResearch = function(controller) johtoResearch = controller end
  S.outbreaksUnlocked = function(game) return outbreaksUnlocked(game or S.game) end
  S.unlockCharm = unlockCharm
  S.scanSave = scanSave
  S.statusIcon = STATUS_ICON
  return S
end
