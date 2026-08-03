-- Kanto Heritage events: faithful Generation-I distribution builds,
-- five badge-gated cups, an optional roaming hunt, and a permanent archive.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "event archive data missing")
  local postgame = assert(opts.postgame, "postgame controller missing")
  local i18n = opts.i18n
  local C = { game = nil, ascendant = nil }
  local pendingRoamer
  local activeCup
  local profiles = {}
  local refreshCupHosts

  for _, profile in ipairs(data.profiles) do
    profiles[profile.id] = profile
  end

  local function tr(english, german)
    if i18n and i18n.text then return i18n.text(english, german) end
    return english
  end

  local function localized(row)
    if type(row) ~= "table" then return row end
    if i18n and i18n.isGerman and i18n.isGerman() then
      return row.de or row.en
    end
    return row.en or row.de
  end

  local function state(create)
    local s = mod.save:get("event_archive")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 1, claimed = {}, cups = {}, roamers = {},
        visits = {}, pending = nil,
      }
      mod.save:set("event_archive", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.claimed = type(s.claimed) == "table" and s.claimed or {}
      s.cups = type(s.cups) == "table" and s.cups or {}
      s.roamers = type(s.roamers) == "table" and s.roamers or {}
      s.visits = type(s.visits) == "table" and s.visits or {}
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("event_archive", s) end
  end

  local function eventMode()
    return mod.options:get("event_mode") or "festival"
  end

  local function mewProfile()
    return mod.options:get("mew_profile") or "ascendant"
  end

  local function optionKey(id)
    return "event_" .. id
  end

  local function profileEnabled(profile)
    if not profile then return false end
    if profile.id == "distribution_mew" then
      return mod.options:get("legend_mew") ~= false
    end
    return eventMode() ~= "off" and mod.options:get(optionKey(profile.id)) ~= false
  end

  local function badgeCount(save)
    local inventory = save and save.inventory or {}
    local count = 0
    for _, badge in ipairs(data.badges) do
      if inventory[badge] then count = count + 1 end
    end
    return count
  end

  local function unlocked(profile, game)
    if not (profile and game and game.save) then return false end
    if badgeCount(game.save) < (profile.badges or 0) then return false end
    return not profile.requiredBadge
      or (game.save.inventory and game.save.inventory[profile.requiredBadge])
  end

  local function moveNames(game, profile)
    local out = {}
    for _, id in ipairs(profile.moves or {}) do
      local def = game and game.data and game.data.moves
        and game.data.moves[id]
      out[#out + 1] = def and def.name or id:gsub("_", " ")
    end
    return table.concat(out, "/")
  end

  local function stampProfile(game, mon, profile, origin)
    if not (game and mon and profile) then return mon end
    local Pokemon = require("src.pokemon.Pokemon")
    local Stats = require("src.pokemon.Stats")
    local Growth = require("src.pokemon.Growth")
    local species = assert(game.data.pokemon[profile.species],
      "unknown event species " .. tostring(profile.species))
    mon.species = profile.species
    mon.level = profile.level
    if profile.dvs then
      mon.dvs = {}
      for key, value in pairs(profile.dvs) do mon.dvs[key] = value end
    end
    mon.statExp = mon.statExp
      or { hp = 0, attack = 0, defense = 0, speed = 0, special = 0 }
    mon.stats = Stats.calc(species, profile.level, mon.dvs, mon.statExp)
    mon.hp = math.max(1, math.min(mon.stats.hp, tonumber(mon.hp) or mon.stats.hp))
    mon.exp = Growth.expForLevel(species.growthRate, profile.level,
      game.data.growth_rates)
    mon.catchRate = species.catchRate
    mon.moves = {}
    for _, moveId in ipairs(profile.moves or {}) do
      local move = assert(game.data.moves[moveId],
        "unknown event move " .. tostring(moveId))
      mon.moves[#mon.moves + 1] = { id = moveId, pp = move.pp or 0 }
    end
    mon.eventDistribution = {
      id = profile.id,
      name = localized(profile.name),
      source = localized(profile.source),
      originalLevel = profile.level,
      originalMoves = profile.moves,
      origin = origin or "KANTO HERITAGE",
    }
    return mon
  end

  local function makeGift(game, profile, origin)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, profile.species, profile.level)
    stampProfile(game, mon, profile, origin)
    require("src.battle.BattleState").stampOT(game.save, mon)
    return mon
  end

  local function storeGift(game, profile, origin)
    local mon = makeGift(game, profile, origin)
    local Party = require("src.pokemon.Party")
    if Party.add(game.save.party, mon) then return mon, "party" end
    local box = require("src.pokemon.Boxes").deposit(game.save, mon)
    if box then return mon, "box", box end
    return nil
  end

  local function markOwned(game, profile)
    if game.save.pokedex then
      game.save.pokedex.seen[profile.species] = true
      game.save.pokedex.owned[profile.species] = true
    end
  end

  local function giftMessage(game, profile, destination, box)
    local player = game.save.player and game.save.player.name or "PLAYER"
    local name = localized(profile.name)
    if destination == "box" then
      return tr(
        ("%s received\n%s!\fIt was sent to\nBOX %d."):format(
          player, name, box or 1),
        ("%s erhält\n%s!\fEs wurde in BOX %d\ngesendet."):format(
          player, name, box or 1))
    end
    return tr(
      ("%s received\n%s!\fIts historic build\nwas archived."):format(
        player, name),
      ("%s erhält\n%s!\fSein historisches Set\nwurde archiviert."):format(
        player, name))
  end

  local function give(game, id, origin)
    local profile = profiles[id]
    local s = state()
    if not (profile and profileEnabled(profile)) then return nil, "disabled" end
    if s.claimed[id] then return nil, "claimed" end
    if s.pending and s.pending.id ~= id then
      return tr(
        "Claim your reserved\nprize in EVENTS before\nreceiving another.",
        "Hole erst deinen\nreservierten Preis unter\nEVENTS ab."), "pending"
    end
    local mon, destination, box = storeGift(game, profile, origin)
    if not mon then
      s.pending = { id = id, origin = origin or "KANTO HERITAGE" }
      persist(s)
      return tr(
        "Every PARTY and PC\nslot is full.\fYour event prize is\nreserved in EVENTS.",
        "TEAM und PC sind\nvoll.\fDein Event-Preis ist\nunter EVENTS reserviert."), "full"
    end
    markOwned(game, profile)
    s.claimed[id] = {
      origin = origin or "KANTO HERITAGE",
      cycle = C.ascendant and C.ascendant.cycle and C.ascendant.cycle() or 0,
    }
    if s.pending and s.pending.id == id then s.pending = nil end
    persist(s)
    return giftMessage(game, profile, destination, box), destination
  end

  local function claimPending(game)
    local s = state()
    if not (s.pending and s.pending.id) then
      return tr("No reserved event\nprize is waiting.",
        "Kein reservierter\nEvent-Preis wartet."), false
    end
    local message, result = give(game, s.pending.id, s.pending.origin)
    return message, result ~= "full" and result ~= "disabled"
  end

  local function archiveStatus(game, profile)
    local s = state()
    if s.claimed[profile.id] then return tr("OWNED", "ERHALTEN") end
    if s.pending and s.pending.id == profile.id then return tr("CLAIM", "ABHOLEN") end
    if not profileEnabled(profile) then return tr("OFF", "AUS") end
    if profile.id == "distribution_mew" then
      return mewProfile() == "historical"
        and tr("FINALE", "FINALE") or tr("APEX", "APEX")
    end
    return unlocked(profile, game) and tr("READY", "BEREIT")
      or ((profile.badges or 0) .. tr(" BADGES", " ORDEN"))
  end

  local function details(game, profile)
    local s = state()
    local status = archiveStatus(game, profile)
    local origin = s.claimed[profile.id] and s.claimed[profile.id].origin
    local pages = {
      localized(profile.name),
      ("LV.%d\n%s"):format(profile.level, moveNames(game, profile)),
      localized(profile.source),
      tr("STATUS: ", "STATUS: ") .. status,
    }
    if origin then pages[#pages + 1] = tr("OBTAINED AT:\n", "ERHALTEN BEI:\n") .. origin end
    return table.concat(pages, "\f")
  end

  if mod.content and mod.content.screens then
    mod.content.screens:register("KantoEventArchive", {
      new = function(game)
        local rows = {}
        for _, profile in ipairs(data.profiles) do
          rows[#rows + 1] = {
            label = localized(profile.short),
            right = archiveStatus(game, profile),
            value = profile.id,
          }
        end
        return mod.ui.ListMenu.new(game, tr("EVENT ARCHIVE", "EVENT-ARCHIV"),
          rows, {
            pageJump = true,
            onChoose = function(item)
              local TextBox = require("src.render.TextBox")
              local s = state()
              if s.pending and s.pending.id == item.value then
                local message = claimPending(game)
                local ow = mod.world and mod.world:overworld()
                refreshCupHosts(game, ow and ow.map and ow.map.id)
                game.stack:push(TextBox.new(game, message))
              else
                game.stack:push(TextBox.new(game,
                  details(game, profiles[item.value])))
              end
            end,
          })
      end,
    })
  end

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    if eventMode() == "off" and mod.options:get("legend_mew") == false then
      return out
    end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("EVENTS", "EVENTS"),
      ascendantMenu = true,
      ascendantLabel = tr("EVENT ARCHIVE", "EVENT-ARCHIV"),
      ascendantOrder = 50,
      onSelect = function() mod.ui.push(game, "KantoEventArchive") end,
    })
  end, 250)

  mod.hooks:wrap("ui.party.submenu", function(nextItems, game, items, mon, ctx)
    local out = nextItems(game, items, mon, ctx)
    if type(out) ~= "table" or not (mon and mon.eventDistribution) then return out end
    out[#out + 1] = {
      label = tr("EVENT INFO", "EVENT-INFO"),
      onSelect = function()
        local info = mon.eventDistribution
        local profile = profiles[info.id]
        local message = profile and details(game, profile)
          or ((info.name or mon.species) .. "\f" .. (info.source or "EVENT"))
        game.stack:push(require("src.render.TextBox").new(game, message))
      end,
    }
    return out
  end, 250)

  local function runtimeObjectIds(game, mapId, name)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[mapId]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == name then
        out[#out + 1] = mapId .. "_obj_" .. tostring(obj.index)
      end
    end
    return out
  end

  local function findSpawnCell(ow, preferred)
    local function free(x, y)
      return ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
        and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
        and not (ow.player.cellX == x and ow.player.cellY == y)
    end
    for _, cell in ipairs(preferred or {}) do
      if free(cell[1], cell[2]) then return cell[1], cell[2] end
    end
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        if free(x, y) then return x, y end
      end
    end
  end

  local function ensureCupHost(game, profile)
    local cup = data.cups[profile.id]
    if not cup then return end
    local ids = runtimeObjectIds(game, cup.map, cup.name)
    local s = state()
    local should = eventMode() == "festival" and profileEnabled(profile)
      and (not s.claimed[profile.id] or (s.pending and s.pending.id == profile.id))
      and unlocked(profile, game)
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == cup.map) then return end
    local x, y = findSpawnCell(ow, cup.preferred)
    if not x then
      mod.log:warn("no free Heritage Cup host cell on %s", cup.map)
      return
    end
    mod.world:spawnNpc(cup.map, {
      name = cup.name, sprite = cup.sprite, movement = "STAY", range = "DOWN",
      text = cup.textId, x = x, y = y,
    })
  end

  refreshCupHosts = function(game, mapId)
    for _, profile in ipairs(data.profiles) do
      local cup = data.cups[profile.id]
      if cup and (not mapId or cup.map == mapId) then ensureCupHost(game, profile) end
    end
  end

  local function healParty(game)
    for _, mon in ipairs(game.save.party or {}) do
      require("src.pokemon.Pokemon").heal(mon)
    end
  end

  local function nameTrainer(battle, name)
    if battle and battle.trainer then
      battle.trainer = setmetatable({ name = name }, { __index = battle.trainer })
    end
  end

  local function startCupRound(game, ow, npc, profile, round)
    local cup = data.cups[profile.id]
    local foe = cup.opponents[round]
    local battle = postgame.newForcedBattle(game, foe.class, foe.team, "heritage")
    battle.rematch = true
    battle.ascendantHeritage = profile.id
    battle.heritageRound = round
    nameTrainer(battle, localized(foe.name))
    battle.onFinish = function(result)
      ow:afterBattle(result, battle)
      if result ~= "win" then
        activeCup = nil
        npc.frozen = false
        game.stack:push(require("src.render.TextBox").new(game, tr(
          "The bracket ends here.\nYour place is saved;\ntry again anytime.",
          "Das Turnier endet hier.\nVersuche es jederzeit\nerneut.")))
        return
      end
      if round < #cup.opponents then
        healParty(game)
        game.stack:push(require("src.render.TextBox").new(game, tr(
          ("ROUND %d WON!\nYour team was healed.\fNext challenger!"):format(round),
          ("RUNDE %d GEWONNEN!\nDein Team ist geheilt.\fNächster Herausforderer!"):format(round)
        ), function()
          startCupRound(game, ow, npc, profile, round + 1)
        end))
        return
      end
      activeCup = nil
      local s = state()
      s.cups[profile.id] = true
      persist(s)
      local message = give(game, profile.id, localized(cup.title))
      npc.frozen = false
      game.stack:push(require("src.render.TextBox").new(game,
        tr("HERITAGE CUP WON!\f", "HERITAGE-CUP GEWONNEN!\f") .. message))
      refreshCupHosts(game, cup.map)
    end
    ow:pushBattle(battle)
  end

  local function handleCup(game, ow, npc, id)
    local profile = profiles[id]
    local cup = data.cups[id]
    if not (profile and cup) then return false end
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    local s = state()
    if s.pending and s.pending.id == id then
      local message = claimPending(game)
      refreshCupHosts(game, cup.map)
      game.stack:push(require("src.render.TextBox").new(game, message, done))
      return true
    end
    if s.pending then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "A different event\nprize is reserved.\fClaim it in EVENTS\nbefore entering.",
        "Ein anderer Event-Preis\nist reserviert.\fHole ihn vor dem\nTurnier unter EVENTS ab."), done))
      return true
    end
    if s.claimed[id] then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "Your victory is already\nrecorded in EVENTS.",
        "Dein Sieg steht bereits\nunter EVENTS."), done))
      return true
    end
    if activeCup then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "Another bracket is\nalready active.",
        "Ein anderes Turnier\nläuft bereits."), done))
      return true
    end
    game.stack:push(require("src.render.TextBox").new(game,
      localized(cup.intro) .. "\f" .. tr("ENTER THE CUP?", "AM CUP TEILNEHMEN?"),
      nil, {
        choice = function(yes)
          if not yes then done() return end
          activeCup = id
          healParty(game)
          startCupRound(game, ow, npc, profile, 1)
        end,
      }))
    return true
  end

  if mod.content and mod.content.map_scripts then
    for id, cup in pairs(data.cups) do
      local eventId, row = id, cup
      mod.content.map_scripts:register(row.map, {
        priority = 1250,
        talk = {
          [row.textId] = function(game, ow, npc)
            handleCup(game, ow, npc, eventId)
          end,
        },
      })
    end
  end

  local routeMaps = {
    "ROUTE_1", "ROUTE_2", "ROUTE_3", "ROUTE_4", "ROUTE_5", "ROUTE_6",
    "ROUTE_7", "ROUTE_8", "ROUTE_9", "ROUTE_10", "ROUTE_11", "ROUTE_12",
    "ROUTE_13", "ROUTE_14", "ROUTE_15", "ROUTE_16", "ROUTE_17", "ROUTE_18",
    "ROUTE_19", "ROUTE_20", "ROUTE_21", "ROUTE_22", "ROUTE_23", "ROUTE_24",
    "ROUTE_25",
  }
  local waterMaps = {
    "ROUTE_19", "ROUTE_20", "ROUTE_21", "SEAFOAM_ISLANDS_1F",
    "SEAFOAM_ISLANDS_B1F", "SEAFOAM_ISLANDS_B2F",
    "SEAFOAM_ISLANDS_B3F", "SEAFOAM_ISLANDS_B4F",
  }
  local electricMaps = {
    "ROUTE_9", "ROUTE_10", "ROUTE_11", "ROUTE_16",
    "VIRIDIAN_FOREST", "POWER_PLANT",
  }
  local fireMaps = {
    "ROUTE_7", "ROUTE_8", "ROUTE_16", "ROUTE_17", "ROUTE_18",
    "POKEMON_MANSION_1F", "POKEMON_MANSION_2F",
    "POKEMON_MANSION_3F", "POKEMON_MANSION_B1F",
  }
  local habitats = {
    water = waterMaps, route = routeMaps, electric = electricMaps, fire = fireMaps,
  }

  local function randomInt(lo, hi)
    if love and love.math and love.math.random then return love.math.random(lo, hi) end
    return math.random(lo, hi)
  end

  local function chooseMap(profile, avoid)
    local pool = habitats[profile.habitat] or routeMaps
    if #pool == 1 then return pool[1] end
    local map
    for _ = 1, 8 do
      map = pool[randomInt(1, #pool)]
      if map ~= avoid then return map end
    end
    return map
  end

  local function initRoamers(game)
    if eventMode() ~= "roaming" then return end
    local s = state()
    for _, id in ipairs(data.catchupOrder) do
      local profile = profiles[id]
      if profileEnabled(profile) and not s.claimed[id] and not s.roamers[id] then
        s.roamers[id] = {
          map = chooseMap(profile), dvs = nil,
          hp = nil, status = nil, recovery = 0, lastVisit = nil,
        }
      end
    end
    persist(s)
  end

  local function relocate(id, avoid)
    local s = state()
    local roamer = s.roamers[id]
    local profile = profiles[id]
    if roamer and profile then
      roamer.map = chooseMap(profile, avoid)
      persist(s)
    end
  end

  mod.hooks:wrap("encounter.roll", function(nextRoll, encDef, ctx)
    local normal = nextRoll(encDef, ctx)
    if eventMode() ~= "roaming" or not C.game then return normal end
    initRoamers(C.game)
    local s = state()
    for _, id in ipairs(data.catchupOrder) do
      local profile = profiles[id]
      local roamer = s.roamers[id]
      if roamer and roamer.recovery <= 0 and roamer.map == ctx.mapId
          and profileEnabled(profile) and unlocked(profile, C.game)
          and (profile.terrain == nil or profile.terrain == ctx.terrain)
          and ctx.rng(1, 256) <= 75 then
        pendingRoamer = id
        return { species = profile.species, level = profile.level }
      end
    end
    return normal
  end, 300)

  mod.hooks:wrap("battle.enemy_action", function(nextAction, battle)
    if battle and battle.eventRoamer
        and mod.options:get("event_flee") ~= false
        and not battle.eventRoamerFled then
      battle.eventRoamerFled = true
      return { special = "ascendantEventFlee" }
    end
    return nextAction(battle)
  end, 300)

  mod.hooks:wrap("battle.overlay", function(nextDraw, battle)
    nextDraw(battle)
    if mod.options:get("event_rosette") == false or not love then return end
    local function rosette(x, y)
      love.graphics.setColor(0, 0, 0, 1)
      love.graphics.rectangle("fill", x + 2, y, 3, 7)
      love.graphics.rectangle("fill", x, y + 2, 7, 3)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.rectangle("fill", x + 2, y + 2, 3, 3)
    end
    if battle.enemy and battle.enemy.mon
        and battle.enemy.mon.eventDistribution then rosette(72, 8) end
    if battle.player and battle.player.mon
        and battle.player.mon.eventDistribution then
      local wide = battle.game and battle.game.save.options
        and battle.game.save.options.battleLayout == "wide"
      rosette(wide and 272 or 144, wide and 64 or 72)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end, 300)

  local function applyHistoricalMew(battle)
    local profile = profiles.distribution_mew
    if not (battle and battle.game and battle.enemy and battle.enemy.mon) then return end
    stampProfile(battle.game, battle.enemy.mon, profile, "ROUTE 24 MYTHIC FINALE")
    battle.eventDistribution = profile.id
    battle.eventHistoricalMew = true
    battle.enemy.shownHP = battle.enemy.mon.hp
    if battle.enemyParty then battle.enemyParty[1] = battle.enemy.mon end
  end

  local function awardNext(game, origin)
    if eventMode() ~= "festival" then return nil end
    local s = state()
    if s.pending then return nil end
    for _, id in ipairs(data.catchupOrder) do
      local profile = profiles[id]
      if profileEnabled(profile) and unlocked(profile, game)
          and not s.claimed[id] then
        return give(game, id, origin or "GRAND TOURNAMENT")
      end
    end
    return nil
  end

  local function install(game, deps)
    C.game = game
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    if not BattleState._kantoEventFleeWrapped then
      BattleState._kantoEventFleeWrapped = true
      local original = BattleState.executeAction
      BattleState.executeAction = function(self, user, target, action)
        if action and action.special == "ascendantEventFlee" then
          if self.result then return end
          self:sayNext(tr(
            ("%s vanished into\nthe wild!"):format(self.enemy.name),
            ("%s flieht in\ndie Wildnis!"):format(self.enemy.name)))
          self.result = "run"
          self.afterQueue = "finish"
          return
        end
        return original(self, user, target, action)
      end
    end
    initRoamers(game)
    refreshCupHosts(game)
  end

  mod.events:on("game.ready", function(ev)
    C.game = ev and ev.game or C.game
    if C.game then
      initRoamers(C.game)
      refreshCupHosts(C.game)
    end
  end)

  mod.events:on("save.loaded", function()
    state()
  end)

  mod.events:on("mod.options_changed", function(ev)
    if not (ev and ev.mod == mod.id and C.game) then return end
    initRoamers(C.game)
    local ow = mod.world and mod.world:overworld()
    refreshCupHosts(C.game, ow and ow.map and ow.map.id)
  end)

  mod.events:on("map.entered", function(ev)
    if not C.game then return end
    local mapId = ev and ev.mapId
    initRoamers(C.game)
    refreshCupHosts(C.game, mapId)
    if eventMode() ~= "roaming" then return end
    local s = state()
    for _, id in ipairs(data.catchupOrder) do
      local roamer = s.roamers[id]
      if roamer then
        if roamer.recovery > 0 and roamer.lastVisit ~= mapId then
          roamer.recovery = roamer.recovery - 1
          roamer.lastVisit = mapId
          if roamer.recovery <= 0 then roamer.hp, roamer.status = nil, nil end
        elseif roamer.recovery <= 0 and randomInt(1, 4) == 1 then
          relocate(id, mapId)
        end
      end
    end
    persist(s)
  end)

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not (battle and pendingRoamer and battle.kind == "wild"
        and battle.enemy and battle.enemy.mon) then return end
    local id = pendingRoamer
    pendingRoamer = nil
    local profile = profiles[id]
    if battle.enemy.mon.species ~= profile.species then return end
    local roamer = state().roamers[id]
    if roamer and roamer.dvs then
      battle.enemy.mon.dvs = {}
      for key, value in pairs(roamer.dvs) do
        battle.enemy.mon.dvs[key] = value
      end
    end
    stampProfile(battle.game, battle.enemy.mon, profile, "KANTO ROAMING EVENT")
    if roamer then
      if not roamer.dvs then
        roamer.dvs = {}
        for key, value in pairs(battle.enemy.mon.dvs or {}) do
          roamer.dvs[key] = value
        end
        persist(state())
      end
      battle.enemy.mon.hp = roamer.hp
        and math.max(1, math.min(battle.enemy.mon.stats.hp, roamer.hp))
        or battle.enemy.mon.stats.hp
      battle.enemy.mon.status = roamer.status
    end
    battle.enemy.shownHP = battle.enemy.mon.hp
    battle.eventRoamer = id
    battle.eventDistribution = id
  end)

  mod.events:on("battle.ended", function(ev)
    local battle = ev and ev.battle
    if not (battle and battle.eventRoamer) then return end
    local s = state()
    local id = battle.eventRoamer
    local roamer = s.roamers[id]
    if (ev.result == "caught" and battle.eventArchiveStored)
        or s.claimed[id] then
      s.roamers[id] = nil
    elseif roamer and battle.enemy and battle.enemy.mon then
      if battle.enemy.mon.hp <= 0 or ev.result == "win" then
        roamer.hp, roamer.status = nil, nil
        roamer.recovery = 3
        roamer.lastVisit = C.game and C.game.overworld
          and C.game.overworld.map and C.game.overworld.map.id
      else
        roamer.hp = battle.enemy.mon.hp
        roamer.status = battle.enemy.mon.status
        roamer.recovery = 0
      end
      roamer.map = chooseMap(profiles[id], roamer.map)
    end
    persist(s)
  end)

  mod.events:on("pokemon.caught", function(ev)
    local mon = ev and ev.mon
    local info = mon and mon.eventDistribution
    if not (info and profiles[info.id]) then return end
    local save = ev.game and ev.game.save
    local stored = false
    for _, partyMon in ipairs(save and save.party or {}) do
      if partyMon == mon then stored = true break end
    end
    if not stored then
      for _, box in ipairs(save and save.boxes or {}) do
        for _, boxMon in ipairs(box) do
          if boxMon == mon then stored = true break end
        end
        if stored then break end
      end
    end
    if ev.battle then ev.battle.eventArchiveStored = stored end
    if not stored then return end
    local s = state()
    s.claimed[info.id] = s.claimed[info.id] or {
      origin = info.origin or "KANTO EVENT",
      cycle = C.ascendant and C.ascendant.cycle and C.ascendant.cycle() or 0,
    }
    s.roamers[info.id] = nil
    persist(s)
  end)

  function C.setAscendant(ascendant) C.ascendant = ascendant end
  C.state = state
  C.profile = function(id) return profiles[id] end
  C.profileEnabled = profileEnabled
  C.unlocked = unlocked
  C.badgeCount = badgeCount
  C.give = give
  C.claimPending = claimPending
  C.stampProfile = stampProfile
  C.applyHistoricalMew = applyHistoricalMew
  C.awardNext = awardNext
  C.eventMode = eventMode
  C.mewProfile = mewProfile
  C.install = install
  C.handleCup = handleCup
  C.initRoamers = initRoamers
  C.relocate = relocate
  return C
end
