-- Silver, Kris and Gold form Kanto Ascendant's final no-item trial.  The
-- three battles run back-to-back with rotating level-100 rosters.  Gold
-- alone awards one uniformly random shiny from the complete 251 roster
-- after every successful run.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "Johto Masters data missing")
  local postgame = assert(opts.postgame, "postgame controller missing")
  local ascendant = opts.ascendant
  local shinySystem = assert(opts.shinySystem, "shiny controller missing")
  local i18n = opts.i18n
  local J = { game = nil }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    return type(row) == "table" and tr(row.en, row.de) or row
  end

  local function state(create)
    local s = mod.save:get("johto_masters")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 1, attempts = 0, clears = 0, gifts = 0,
        title = false,
      }
      mod.save:set("johto_masters", s)
    end
    if type(s) == "table" then
      s.version = 1
      s.attempts = math.max(0, math.floor(tonumber(s.attempts) or 0))
      s.clears = math.max(0, math.floor(tonumber(s.clears) or 0))
      s.gifts = math.max(0, math.floor(tonumber(s.gifts) or 0))
      s.title = s.title == true
      if type(s.pendingGift) ~= "table" then s.pendingGift = nil end
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("johto_masters", s) end
  end

  local function eligible(game)
    local p = postgame.state(false)
    return postgame.hasHallOfFame(game and game.save)
      and p and p.crownChampion == true
  end

  local function copySlot(slot)
    return {
      species = slot.species, level = 100,
      moves = slot.moves and {
        slot.moves[1], slot.moves[2], slot.moves[3], slot.moves[4],
      } or nil,
    }
  end

  local function trainerFor(key)
    for _, trainer in ipairs(data.trainers) do
      if trainer.key == key then return trainer end
    end
  end

  local function teamFor(key, attempt)
    local trainer = assert(trainerFor(key), "unknown Johto Master " .. tostring(key))
    local pool, out = trainer.pool, {}
    local offset = key == "silver" and 0 or (key == "kris" and 4 or 8)
    local start = (math.max(1, math.floor(tonumber(attempt) or 1))
      + offset - 1) % #pool
    -- Five is coprime with the twelve-slot pools, so all six selections are
    -- unique and consecutive attempts expose a different composition.
    for index = 0, 5 do
      out[#out + 1] = copySlot(pool[((start + index * 5) % #pool) + 1])
    end
    return out
  end

  local function fullRoster(game)
    local byDex = {}
    for id, def in pairs(game and game.data and game.data.pokemon or {}) do
      local dex = tonumber(def.dex)
      if dex and dex >= 1 and dex <= 251 and not byDex[dex] then
        byDex[dex] = id
      end
    end
    local out = {}
    for dex = 1, 251 do
      if byDex[dex] then out[#out + 1] = byDex[dex] end
    end
    return out
  end

  local function randomInt(lo, hi)
    if love and love.math and love.math.random then
      return love.math.random(lo, hi)
    end
    return math.random(lo, hi)
  end

  local function randomSpecies(game, rng)
    local roster = fullRoster(game)
    if #roster == 0 then return nil end
    local index = (rng or randomInt)(1, #roster)
    index = math.max(1, math.min(#roster, math.floor(tonumber(index) or 1)))
    return roster[index]
  end

  local function markOwned(game, species)
    game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
    game.save.pokedex.seen = game.save.pokedex.seen or {}
    game.save.pokedex.owned = game.save.pokedex.owned or {}
    game.save.pokedex.seen[species] = true
    game.save.pokedex.owned[species] = true
  end

  local function buildGift(game, row)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, row.species, row.level or 50)
    shinySystem.forceMon(mon, game.data.pokemon[row.species])
    require("src.battle.BattleState").stampOT(game.save, mon)
    mon.johtoMasterGift = {
      trainer = "GOLD", clear = row.clear, title = "KANTO ASCENDANT",
    }
    return mon
  end

  local function deliverGift(game, s)
    local row = s.pendingGift
    if not row then return nil, true end
    local mon = buildGift(game, row)
    local destination, box
    if require("src.pokemon.Party").add(game.save.party, mon) then
      destination = "party"
    else
      box = require("src.pokemon.Boxes").deposit(game.save, mon)
      if box then destination = "box" end
    end
    if not destination then
      return tr(
        "Your PARTY and every\nBOX are full.\fGOLD will protect the\nshiny until you return.",
        "TEAM und alle BOXEN\nsind voll.\fGOLD bewahrt das Shiny\nbis zu deiner Rückkehr."), false
    end
    markOwned(game, row.species)
    shinySystem.markCaught(mon)
    s.pendingGift = nil
    s.gifts = s.gifts + 1
    persist(s)
    local name = game.data.pokemon[row.species].name
    if destination == "box" then
      return tr(
        ("GOLD: A golden victory\ndeserves something rare!\f%s received a shiny\n%s!\fIt was sent to BOX %d.")
          :format(game.save.player.name, name, box or 1),
        ("GOLD: Ein goldener Sieg\nverdient etwas Seltenes!\f%s erhält ein Shiny\n%s!\fEs ist nun in BOX %d.")
          :format(game.save.player.name, name, box or 1)), true
    end
    return tr(
      ("GOLD: A golden victory\ndeserves something rare!\f%s received a shiny\n%s!")
        :format(game.save.player.name, name),
      ("GOLD: Ein goldener Sieg\nverdient etwas Seltenes!\f%s erhält ein Shiny\n%s!")
        :format(game.save.player.name, name)), true
  end

  local function healParty(game)
    local Pokemon = require("src.pokemon.Pokemon")
    for _, mon in ipairs(game.save.party or {}) do Pokemon.heal(mon) end
  end

  local function awardTitle(s)
    if s.title then return false end
    s.title = true
    if ascendant and ascendant.state then
      local a = ascendant.state()
      a.achievements.johto_master = true
      a.latestAchievement = "johto_master"
      mod.save:set("ascendant", a)
    end
    return true
  end

  local function completeRun(game)
    local s = state()
    s.clears = s.clears + 1
    local first = awardTitle(s)
    s.pendingGift = {
      species = randomSpecies(game), level = 50, clear = s.clears,
    }
    persist(s)
    local reward, delivered = deliverGift(game, s)
    if ascendant and ascendant.evaluateAchievements then
      ascendant.evaluateAchievements(game)
    end
    local title = first and tr(
      "TITLE EARNED:\nKANTO ASCENDANT\fA golden star now\nmarks your TRAINER CARD.",
      "TITEL ERHALTEN:\nKANTO ASCENDANT\fEin goldener Stern ziert\nnun deinen TRAINERPASS.")
      or tr(
        ("JOHTO MASTERS CLEAR %d"):format(s.clears),
        ("JOHTO-MEISTER SIEG %d"):format(s.clears))
    return title .. (reward and "\f" .. reward or ""), delivered
  end

  local function startTrial(ow, npc, game)
    local TextBox = require("src.render.TextBox")
    local s = state()
    s.attempts = s.attempts + 1
    persist(s)
    local attempt, index = s.attempts, 0
    healParty(game)

    local function finish(result)
      npc.frozen = false
      if result ~= "win" then return end
      local message = completeRun(game)
      game.stack:push(TextBox.new(game, message))
    end

    local function nextBattle()
      index = index + 1
      local trainer = data.trainers[index]
      healParty(game)
      local battle = postgame.newForcedBattle(
        game, trainer.class, teamFor(trainer.key, attempt), "johto_master")
      battle.rematch = true
      battle.johtoMaster = trainer.key
      battle.ascendantNoItems = true
      battle.enemyAIMods = { 1, 2, 3 }
      battle.trainer = setmetatable({ name = localized(trainer.name) },
        { __index = battle.trainer })
      battle.introText = localized(trainer.intro)
      battle.endBattleText = localized(trainer.win)
      battle.onFinish = function(result)
        ow:afterBattle(result, battle)
        if result ~= "win" then finish(result); return end
        if index >= #data.trainers then finish("win"); return end
        game.stack:push(TextBox.new(game, tr(
          ("%s was defeated!\fYour team is restored.\fThe next Johto Master\nsteps forward.")
            :format(localized(trainer.name)),
          ("%s wurde besiegt!\fDein Team wird geheilt.\fDer nächste Johto-\nMeister tritt vor.")
            :format(localized(trainer.name))), nextBattle))
      end
      ow:pushBattle(battle)
    end
    nextBattle()
  end

  local function handleTalk(game, ow, npc)
    if not eligible(game) then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "The Johto Masters will\ncome after Kanto's\nCROWN Champion rises.",
        "Die Johto-Meister\nkommen, sobald Kantos\nKRONEN-Champ erwacht.")))
      return
    end
    local s = state()
    npc.frozen = true
    npc:facePlayer(ow.player)
    if s.pendingGift then
      local message, delivered = deliverGift(game, s)
      game.stack:push(require("src.render.TextBox").new(game, message,
        function() npc.frozen = false end))
      if not delivered then return end
      return
    end
    local message = tr(
      "JOHTO MASTERS TRIAL\fSILVER, KRIS and GOLD\nfight in sequence.\fAll teams are LEVEL 100.\nYour team is healed\nbetween rounds.\fThe BAG is sealed.\fChallenge them?",
      "JOHTO-MEISTERPRÜFUNG\fSILVER, KRIS und GOLD\nkämpfen nacheinander.\fAlle Teams sind LEVEL 100.\nDein Team wird zwischen\nden Runden geheilt.\fDer BEUTEL ist gesperrt.\fHerausfordern?")
    game.stack:push(require("src.render.TextBox").new(game, message, nil, {
      choice = function(yes)
        if yes then startTrial(ow, npc, game)
        else npc.frozen = false end
      end,
    }))
  end

  local function runtimeObjectIds(game)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[data.map]
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == data.name then
        out[#out + 1] = data.map .. "_obj_" .. tostring(obj.index)
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
    for _, cell in ipairs(data.preferred or {}) do
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
    local should = mapId == data.map and eligible(game)
    if not should then
      for _, id in ipairs(ids) do mod.world:removeNpc(id) end
      return
    end
    if #ids > 0 then return end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == data.map) then return end
    local x, y = findSpawnCell(ow)
    if not x then return end
    mod.world:spawnNpc(data.map, {
      name = data.name, sprite = data.sprite, movement = "STAY", range = "DOWN",
      text = data.textId, trainerClass = "OPP_RIVAL2", x = x, y = y,
    })
  end

  if mod.content and mod.content.map_scripts then
    mod.content.map_scripts:register(data.map, {
      priority = 2300,
      talk = {
        [data.textId] = function(game, ow, npc)
          handleTalk(game, ow, npc)
        end,
      },
    })
  end

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or J.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then refresh(game, mapId) end
  end)

  mod.events:on("save.loaded", function()
    state()
    local ow = mod.world and mod.world:overworld()
    if J.game then refresh(J.game, ow and ow.map and ow.map.id) end
  end)

  function J.install(game)
    J.game = game
    state()
    local ow = mod.world and mod.world:overworld()
    refresh(game, ow and ow.map and ow.map.id)

    local ok, TrainerCard = pcall(require, "src.ui.TrainerCard")
    if ok and TrainerCard and not TrainerCard._johtoMasterTitleWrapped then
      TrainerCard._johtoMasterTitleWrapped = true
      local draw = TrainerCard.draw
      TrainerCard.draw = function(card)
        draw(card)
        if not J.hasTitle() or not (love and love.graphics) then return end
        local g = love.graphics
        g.setColor(0.82, 0.57, 0.06, 1)
        g.rectangle("line", 1.5, 1.5, 157, 141)
        g.rectangle("fill", 8, 130, 6, 2)
        g.rectangle("fill", 10, 128, 2, 6)
        g.setColor(1, 1, 1, 1)
        g.rectangle("fill", 36, 68, 88, 15)
        g.setColor(0, 0, 0, 1)
        require("src.render.Font").draw("ASCENDANT", 44, 71)
        g.setColor(1, 1, 1, 1)
      end
    end
  end

  function J.hasTitle()
    local s = state(false)
    return s and s.title == true or false
  end

  function J.statusText()
    local s = state()
    return tr("JOHTO MASTERS", "JOHTO-MEISTER")
      .. ("\n%s: %d\n%s: %d"):format(
        tr("CLEARS", "SIEGE"), s.clears,
        tr("GOLD SHINIES", "GOLD-SHINYS"), s.gifts)
      .. ("\f%s: %s"):format(
        tr("TITLE", "TITEL"),
        s.title and "KANTO ASCENDANT" or tr("LOCKED", "GESPERRT"))
  end

  J.state = state
  J.eligible = eligible
  J.teamFor = teamFor
  J.fullRoster = fullRoster
  J.randomSpecies = randomSpecies
  J.completeRun = completeRun
  J.deliverGift = deliverGift
  J.refresh = refresh
  return J
end
