-- Gorochu: Raichu's discarded final evolution, restored as an Ascendant
-- guest species. Heart of Thunder is the permanent story key shared by
-- Red, Blue and Yellow; a remote Power Plant condenser turns its charge
-- into the consumable Tear of Thunder that evolves one chosen Raichu.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local runtime = { gameVersion = opts.gameVersion }
  local G = {
    id = "GOROCHU",
    dex = 1026,
    method = "ITEM",
    animationDurations = { 120, 80, 100, 120, 80, 100 },
  }

  local STATE_KEY = "gorochu_quest"
  local HEART = "ASCENDANT_THUNDERHEART"
  local TEAR = "ASCENDANT_THUNDER_TEAR"
  local MARKER = "_ascendantGorochuCandidate"
  local SURGE = "VERMILIONGYM_LT_SURGE"
  local SHRINE = "KANTO_ASCENDANT_THUNDER_CONDENSER"
  local SHRINE_TEXT = "KANTO_ASCENDANT_THUNDER_CONDENSER_TEXT"
  local TRAINER_FALLBACK_MOVES = {
    "THUNDER", "BODY_SLAM", "THUNDER_WAVE", "AGILITY",
  }

  G.heartItemId = HEART
  G.tearItemId = TEAR
  G.marker = MARKER
  G.shrineName = SHRINE

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function isYellow()
    local gv = runtime.gameVersion
    if not gv then
      local ok
      ok, gv = pcall(require, "src.core.GameVersion")
      if not ok then return false end
    end
    return gv and type(gv.isYellow) == "function"
      and gv.isYellow() == true
  end

  local function state(create)
    local s = mod.save:get(STATE_KEY)
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 4,
        offered = false,
        declined = false,
        heartGiven = false,
        tearGenerated = false,
        tearClaims = 0,
        completed = false,
        playerEvolved = false,
      }
      mod.save:set(STATE_KEY, s)
    end
    if type(s) == "table" then
      local previousVersion = math.max(0,
        math.floor(tonumber(s.version) or 0))
      if previousVersion < 4 and s.playerEvolved == nil then
        -- 5.4.0 recorded successful player evolutions as `completed`.
        -- A rare legacy save whose evolution event was missed is inferred
        -- once in migrate() from its owned/party Gorochu.
        s.playerEvolved = s.completed == true
        s._legacyPlayerEvolutionInference = not s.playerEvolved
      else
        s.playerEvolved = s.playerEvolved == true
      end
      s.version = 4
      s.offered = s.offered == true
      s.declined = s.declined == true
      s.heartGiven = s.heartGiven == true
      s.tearGenerated = s.tearGenerated == true
      s.tearClaims = math.max(0,
        math.floor(tonumber(s.tearClaims) or 0))
      s.completed = s.completed == true
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set(STATE_KEY, s) end
  end

  local function eachPokemon(save, fn)
    for index, mon in ipairs(save and save.party or {}) do
      if fn(mon, "party", index) == false then return false end
    end
    for boxIndex, box in ipairs(save and save.boxes or {}) do
      local mons = type(box) == "table" and (box.mons or box) or {}
      for index, mon in ipairs(mons) do
        if fn(mon, "box", index, boxIndex) == false then return false end
      end
    end
    return true
  end

  local function hasSpecies(save, species)
    local found = false
    eachPokemon(save, function(mon)
      if type(mon) == "table" and mon.species == species then
        found = true
        return false
      end
    end)
    return found
  end

  local function markedTarget(save)
    local found
    eachPokemon(save, function(mon)
      if type(mon) == "table" and mon[MARKER] == true then
        found = mon
        return false
      end
    end)
    return found
  end

  local function itemOwned(game, item)
    return game and game.save and game.save.inventory
      and (tonumber(game.save.inventory[item]) or 0) > 0 or false
  end

  local function orderBag(save)
    local ok, Bag = pcall(require, "src.inventory.Bag")
    if ok and Bag and Bag.order then Bag.order(save) end
  end

  local function grantItem(game, item)
    if not (game and game.save) then return false end
    local inventory = game.save.inventory or {}
    game.save.inventory = inventory
    local fresh = (tonumber(inventory[item]) or 0) < 1
    inventory[item] = 1
    orderBag(game.save)
    return fresh
  end

  local function grantHeart(game)
    local fresh = grantItem(game, HEART)
    local s = state()
    s.heartGiven = true
    s.heartGivenAt = s.heartGivenAt or os.time()
    persist(s)
    return fresh
  end

  local function grantTear(game)
    if not (game and game.save) then return false end
    local fresh = grantItem(game, TEAR)
    local s = state()
    s.tearGenerated = true
    if fresh then s.tearClaims = s.tearClaims + 1 end
    s.tearGeneratedAt = os.time()
    persist(s)
    return fresh
  end

  local function copyTrainerSlot(slot)
    local copy = {}
    for key, value in pairs(slot or {}) do
      if type(value) == "table" then
        copy[key] = {}
        for nestedKey, nestedValue in pairs(value) do
          copy[key][nestedKey] = nestedValue
        end
      else
        copy[key] = value
      end
    end
    return copy
  end

  -- Gorochu is a player-led discovery in every edition. Trainers may only
  -- reveal it after this save has actually completed Raichu -> Gorochu.
  -- Owning the Heart/Tear, seeing Gorochu, or declining the quest is not
  -- sufficient.
  function G.trainerUnlocked()
    local s = state(false)
    return s and s.playerEvolved == true or false
  end

  function G.sanitizeTrainerTeam(team)
    if type(team) ~= "table" or G.trainerUnlocked() then return team end
    local out
    for index, slot in ipairs(team) do
      if type(slot) == "table" and slot.species == G.id then
        if not out then
          out = {}
          for previous = 1, index - 1 do out[previous] = team[previous] end
        end
        local replacement = copyTrainerSlot(slot)
        replacement.species = "RAICHU"
        if replacement.moves ~= nil then
          replacement.moves = {}
          for moveIndex, moveId in ipairs(TRAINER_FALLBACK_MOVES) do
            replacement.moves[moveIndex] = moveId
          end
        end
        out[index] = replacement
      elseif out then
        out[index] = slot
      end
    end
    return out or team
  end

  mod.content.items:register(HEART, {
    id = HEART,
    name = tr("THUNDERHEART", "DONNERHERZ"),
    price = 0,
    keyItem = true,
    tossable = false,
    needsTarget = false,
  })

  mod.content.items:register(TEAR, {
    id = TEAR,
    name = tr("THUNDER TEAR", "DONNERTRÄNE"),
    price = 0,
    keyItem = true,
    tossable = false,
    needsTarget = true,
  })

  local raichu = mod.content.pokemon:get("RAICHU")
  G.available = raichu ~= nil

  if raichu then
    local tmhm = {}
    for _, move in ipairs(raichu.tmhm or {}) do
      tmhm[#tmhm + 1] = move
    end

    -- Raichu's two Mega profiles both total 495 in the Gen-I five-stat
    -- model. Gorochu totals 560: 13.13% higher, deliberately inside the
    -- requested 10-15% band, in exchange for being a permanent choice.
    mod.content.pokemon:register(G.id, {
      id = G.id,
      name = "GOROCHU",
      dex = G.dex,
      types = { "ELECTRIC" },
      baseStats = {
        hp = 85, attack = 135, defense = 90, speed = 125, special = 125,
      },
      catchRate = 45,
      baseExp = 255,
      growthRate = raichu.growthRate,
      level1Moves = {
        "THUNDERSHOCK", "BITE", "THUNDER_WAVE", "AGILITY",
      },
      tmhm = tmhm,
      learnset = {
        { level = 50, move = "THUNDERBOLT" },
        { level = 60, move = "BITE" },
        { level = 70, move = "AGILITY" },
        { level = 80, move = "THUNDER" },
      },
      evolutions = {},
      spriteFront = mod.path .. "/assets/crystal/gorochu_front.png",
      spriteBack = mod.path .. "/assets/crystal/gorochu_back.png",
      frontSize = 7,
      battleScaleFront = 1,
      battleScaleBack = 1,
      trueColor = true,
      icon = raichu.icon or "QUADRUPED",
      dexEntry = {
        kind = tr("THUNDER GOD", "DONNERGOTT"),
        heightFt = 4,
        heightIn = 7,
        weight = 103.6,
        heightM = 1.4,
        weightKg = 47.0,
        text = tr(
          "Its horns call storms.\nIts fangs glow before\nthe sky begins to roar.",
          "Seine Hörner rufen\nStürme. Die Fangzähne\nglühen vor dem Donner."),
      },
    })
    mod.content.icons:register(G.id, raichu.icon or "QUADRUPED")

    local evolutions = {}
    for _, row in ipairs(raichu.evolutions or {}) do
      if row.species ~= G.id then
        local copy = {}
        for key, value in pairs(row) do copy[key] = value end
        evolutions[#evolutions + 1] = copy
      end
    end
    evolutions[#evolutions + 1] = {
      method = "ITEM",
      item = TEAR,
      species = G.id,
    }
    mod.content.pokemon:patch("RAICHU", { evolutions = evolutions })
  end

  function G.qualifies(_, mon, trigger)
    return mon and mon.species == "RAICHU"
      and trigger and trigger.kind == "item"
      and trigger.item == TEAR or false
  end

  G.audio = {
    primary = mod.path .. "/assets/audio/gorochu/gorochu_cry.wav",
    fallback = {
      base = "RAICHU",
      pitch = 80,
      length = 176,
    },
  }

  local function sameCry(a, b)
    if type(a) ~= "table" or type(b) ~= "table" then return false end
    return a.file == b.file
      and a.base == b.base
      and a.pitch == b.pitch
      and a.length == b.length
  end

  function G.installAudio(game)
    local data = game and game.data or game
    if not data then return 0, 0 end
    data.audio = data.audio or {}
    data.audio.cries = data.audio.cries or {}
    data.audio._owners = data.audio._owners or {}
    data.audio._owners.cries = data.audio._owners.cries or {}
    local installed, preserved = 0, 0
    local desired = isYellow()
      and { file = G.audio.primary }
      or G.audio.fallback
    local current = data.audio.cries[G.id]
    local owner = data.audio._owners.cries[G.id]
    if current == nil then
      data.audio.cries[G.id] = desired
      data.audio._owners.cries[G.id] = mod.manifest.id
      installed = 1
    elseif owner == mod.manifest.id then
      if sameCry(current, desired) then
        preserved = 1
      else
        -- Scripted QA can select its concrete Red/Blue/Yellow identity after
        -- mods first register. Replace only our own earlier fallback; a cry
        -- supplied by another mod remains authoritative.
        data.audio.cries[G.id] = desired
        installed = 1
      end
    else
      preserved = 1
    end
    local species = data.pokemon and data.pokemon[G.id]
    if species then species.cry = G.id end
    local okSound, Sound = pcall(require, "src.core.Sound")
    if okSound and Sound and type(Sound.invalidate) == "function" then
      Sound.invalidate("cry:" .. G.id)
    end
    return installed, preserved
  end

  local function showText(game, text, done, textOpts)
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not (ok and TextBox and game and game.stack) then
      if done then done() end
      return false
    end
    game.stack:push(TextBox.new(game, text, done, textOpts))
    return true
  end

  local function statusText(game)
    local s = state(false)
    if s and s.completed or hasSpecies(game and game.save, G.id) then
      return tr(
        "GOROCHU RESEARCH\fThe THUNDER TEAR has\nbecome a living storm.\fGOROCHU cannot Mega\nEvolve.",
        "GOROCHU-FORSCHUNG\fDie DONNERTRÄNE wurde\nzum lebenden Sturm.\fGOROCHU kann sich nicht\nmegaentwickeln.")
    end
    if itemOwned(game, TEAR) then
      return tr(
        "GOROCHU RESEARCH\fUse the THUNDER TEAR\non the RAICHU you\nchoose.\fThe evolution is\npermanent.",
        "GOROCHU-FORSCHUNG\fNutze die DONNERTRÄNE\nam gewählten RAICHU.\fDie Entwicklung ist\ndauerhaft.")
    end
    if itemOwned(game, HEART) then
      return tr(
        "GOROCHU RESEARCH\fThe THUNDERHEART\npoints to a remote\ncondenser in the\nPOWER PLANT's east wing.\fIt is far from ZAPDOS.",
        "GOROCHU-FORSCHUNG\fDas DONNERHERZ weist\nzu einem abgelegenen\nKondensator im Ostflügel\ndes KRAFTWERKS.\fWeit entfernt von ZAPDOS.")
    end
    return tr(
      "GOROCHU RESEARCH\fLT.SURGE carries a\ncharge that cannot be\nsold, tossed or traded.",
      "GOROCHU-FORSCHUNG\fMAJOR BOB bewahrt eine\nKraft, die weder verkauft,\nweggeworfen noch getauscht\nwerden kann.")
  end

  local function openHeart(game)
    game = game or G.game
    if not (game and game.save) then return false end
    return showText(game, statusText(game))
  end

  local function runtimeShrineIds(game)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps.POWER_PLANT
    for _, obj in ipairs(map and map.objects or {}) do
      if obj.runtime and obj.owner == mod.id and obj.name == SHRINE then
        out[#out + 1] = "POWER_PLANT_obj_" .. tostring(obj.index)
      end
    end
    return out
  end

  local function freeCell(ow, x, y)
    return ow.map:inBounds(x, y) and ow.map:isWalkableCell(x, y)
      and not ow.map:warpAtCell(x, y) and not ow:npcAtCell(x, y)
      and not (ow.player.cellX == x and ow.player.cellY == y)
  end

  local function shrineCell(ow)
    -- Every preferred cell sits in the remote east wing. If a graphics
    -- wrapper changes collision, scan only cells at least 25 steps from
    -- Zapdos (4,9) and favor the farthest eastern safe corner.
    for _, cell in ipairs({
      { 37, 3 }, { 36, 3 }, { 37, 5 }, { 35, 5 },
      { 38, 7 }, { 36, 7 }, { 34, 7 },
    }) do
      if freeCell(ow, cell[1], cell[2]) then
        return cell[1], cell[2]
      end
    end
    local bestX, bestY, bestScore
    for y = 0, ow.map.heightCells - 1 do
      for x = 0, ow.map.widthCells - 1 do
        local zapdosDistance = math.abs(x - 4) + math.abs(y - 9)
        if x >= 24 and zapdosDistance >= 25 and freeCell(ow, x, y) then
          local score = zapdosDistance * 4 + x - math.abs(y - 6)
          if not bestScore or score > bestScore then
            bestX, bestY, bestScore = x, y, score
          end
        end
      end
    end
    return bestX, bestY
  end

  local function refreshShrine(game, mapId)
    if not (G.available and game and itemOwned(game, HEART)
        and (not mapId or mapId == "POWER_PLANT")) then return false end
    if #runtimeShrineIds(game) > 0 then return true end
    local ow = mod.world and mod.world:overworld()
    if not (ow and ow.map and ow.map.id == "POWER_PLANT") then return false end
    local x, y = shrineCell(ow)
    if not x then
      if mod.log and mod.log.warn then
        mod.log:warn("no remote Power Plant cell for Thunder condenser")
      end
      return false
    end
    mod.world:spawnNpc("POWER_PLANT", {
      name = SHRINE,
      sprite = "SPRITE_POKEDEX",
      movement = "STAY",
      range = "DOWN",
      text = SHRINE_TEXT,
      x = x,
      y = y,
    })
    local s = state()
    s.shrineX, s.shrineY = x, y
    persist(s)
    return true
  end

  local function offerHeart(ow, npc, game)
    local s = state()
    npc.frozen = true
    if npc.facePlayer then npc:facePlayer(ow.player) end
    local done = function() npc.frozen = false end
    s.offered = true
    persist(s)
    return showText(game, tr(
      "LT.SURGE: KID! THIS\nCHARGE ANSWERED YOUR\nTHUNDER BADGE.\fThe THUNDERHEART can\nnever be sold, tossed\nor traded.\fTake it and search the\nPOWER PLANT's far\neast wing?",
      "MAJOR BOB: KIND!\fDIESE KRAFT REAGIERT\nAUF DEINEN DONNERORDEN.\fDas DONNERHERZ kann\nnie verkauft, weggeworfen\noder getauscht werden.\fNimm es und suche im\nfernen Ostflügel des\nKRAFTWERKS?"), nil, {
        choice = function(yes)
          if yes then
            grantHeart(game)
            s.declined = false
            persist(s)
            showText(game, tr(
              "Received the\nTHUNDERHEART!\fA remote condenser can\nform one THUNDER TEAR.\fUse that Tear on the\nRAICHU you choose.",
              "DONNERHERZ erhalten!\fEin ferner Kondensator\nkann eine DONNERTRÄNE\nformen.\fNutze sie am gewählten\nRAICHU."),
              done)
          else
            s.declined = true
            persist(s)
            showText(game, tr(
              "NO PRESSURE, KID!\fI will keep it safe\nuntil you return.",
              "KEIN DRUCK, KIND!\fIch bewahre es sicher\nauf, bis du zurückkommst."),
              done)
          end
        end,
      })
  end

  local function useShrine(ow, npc, game)
    npc.frozen = true
    if npc.facePlayer then npc:facePlayer(ow.player) end
    local done = function() npc.frozen = false end
    if not itemOwned(game, HEART) then
      return showText(game, tr(
        "The silent condenser\nhas a heart-shaped slot.",
        "Der stille Kondensator\nhat eine herzförmige\nVertiefung."), done)
    end
    local s = state()
    if s.completed or hasSpecies(game.save, G.id) then
      return showText(game, tr(
        "The condenser hums.\fIts storm already walks\nbeside you.",
        "Der Kondensator summt.\fSein Sturm geht bereits\nan deiner Seite."), done)
    end
    if itemOwned(game, TEAR) then
      return showText(game, tr(
        "A THUNDER TEAR already\nrests in your BAG.\fUse it on the RAICHU\nyou choose.",
        "Eine DONNERTRÄNE liegt\nbereits im BEUTEL.\fNutze sie am gewählten\nRAICHU."), done)
    end
    return showText(game, tr(
      "The THUNDERHEART fits\nthe ancient slot.\fCondense its charge into\na THUNDER TEAR?",
      "Das DONNERHERZ passt\nin die alte Vertiefung.\fSeine Kraft zu einer\nDONNERTRÄNE verdichten?"),
      nil, {
        choice = function(yes)
          if yes then
            grantTear(game)
            showText(game, tr(
              "The permanent Heart\nreturns to your BAG.\fReceived the\nTHUNDER TEAR!\fChoose a RAICHU\ncarefully.",
              "Das dauerhafte Herz\nkehrt in den BEUTEL zurück.\fDONNERTRÄNE erhalten!\fWähle ein RAICHU\nmit Bedacht."),
              done)
          else
            showText(game, tr(
              "The charge settles.\fThe condenser will wait.",
              "Die Kraft beruhigt sich.\fDer Kondensator wartet."),
              done)
          end
        end,
      })
  end

  function G.handleTalk(ow, npc, game)
    if not (G.available and ow and ow.map and npc and npc.def and game) then
      return false
    end
    if ow.map.id == "POWER_PLANT" and npc.def.name == SHRINE then
      return useShrine(ow, npc, game)
    end
    if ow.map.id ~= "VERMILION_GYM" or npc.def.name ~= SURGE
        or isYellow() or not (game.save.inventory
          and game.save.inventory.THUNDERBADGE) then
      return false
    end
    -- THUNDERHEART is the durable hand-off marker. If it is missing, always
    -- offer it first, even on an upgraded postgame save that already records
    -- Gorochu: this repairs saves whose permanent quest item was lost. Once
    -- it exists, release Surge to the normal Master/Crown rematch chain.
    if itemOwned(game, HEART) then
      return false
    end
    return offerHeart(ow, npc, game)
  end

  local function installItemEffect()
    local ok, ItemEffects = pcall(require, "src.inventory.ItemEffects")
    if not (ok and ItemEffects and type(ItemEffects.use) == "function"
        and type(ItemEffects.needsTarget) == "function") then return false end
    local key = "__ascendantThunderTearItem"
    local current = rawget(ItemEffects, key)
    if current then
      current.controller = G
      return true
    end
    local holder = {
      controller = G,
      use = ItemEffects.use,
      needsTarget = ItemEffects.needsTarget,
    }
    ItemEffects.needsTarget = function(itemId, itemDef)
      if itemId == TEAR then return true end
      return holder.needsTarget(itemId, itemDef)
    end
    ItemEffects.use = function(data, save, itemId, target, battle, ...)
      if itemId ~= TEAR then
        return holder.use(data, save, itemId, target, battle, ...)
      end
      if battle then
        return "failed", { tr(
          "It can't be used\nin battle.",
          "Das geht nicht\nim Kampf.") }
      end
      if not target or target.species ~= "RAICHU" then
        return "failed", { tr(
          "The Tear answers\nonly RAICHU.",
          "Die Träne antwortet\nnur RAICHU.") }
      end
      target[MARKER] = true
      return "consumed", nil, { evolveTo = G.id }
    end
    rawset(ItemEffects, key, holder)
    return true
  end

  function G.migrate(game)
    game = game or G.game
    if not (game and game.save) then return false end
    local s = state()
    local changed = false
    if itemOwned(game, HEART) and not s.heartGiven then
      s.heartGiven = true
      changed = true
    end
    if itemOwned(game, TEAR) and not s.tearGenerated then
      s.tearGenerated = true
      s.tearClaims = math.max(1, s.tearClaims)
      changed = true
    end
    -- Convert the unpublished Storm Bond prototype safely: anyone who
    -- already accepted that research receives the permanent Heart.
    if s.accepted and not itemOwned(game, HEART) then
      grantHeart(game)
      changed = true
    end
    local owned = game.save.pokedex and game.save.pokedex.owned
      and game.save.pokedex.owned.GOROCHU == true
    local hasGorochu = hasSpecies(game.save, G.id)
    if s._legacyPlayerEvolutionInference then
      if owned or hasGorochu then
        s.playerEvolved = true
        s.completed = true
        s.completedAt = s.completedAt or os.time()
      end
      s._legacyPlayerEvolutionInference = nil
      changed = true
    end
    if (owned or hasGorochu) and not s.completed then
      s.completed = true
      s.completedAt = s.completedAt or os.time()
      changed = true
    end
    if changed then persist(s) end
    return changed
  end

  function G.install(game, deps)
    G.game = game
    runtime.gameVersion = deps and deps.gameVersion
      or runtime.gameVersion
    G.installAudio(game)
    installItemEffect()
    G.migrate(game)
    local mapId = game and game.overworld and game.overworld.map
      and game.overworld.map.id
    refreshShrine(game, mapId)
  end

  function G.beginQuest(game, mon)
    if not (game and game.save and mon and mon.species == "RAICHU") then
      return false
    end
    eachPokemon(game.save, function(candidate)
      if type(candidate) == "table" then candidate[MARKER] = nil end
    end)
    mon[MARKER] = true
    grantHeart(game)
    return true
  end

  G.state = state
  G.grantHeart = grantHeart
  G.grantTear = grantTear
  G.heartOwned = function(game)
    return itemOwned(game or G.game, HEART)
  end
  G.tearOwned = function(game)
    return itemOwned(game or G.game, TEAR)
  end
  G.statusText = statusText
  G.openHeart = openHeart
  G.refreshShrine = refreshShrine
  G.target = function(game)
    return markedTarget((game or G.game) and (game or G.game).save)
  end
  G.questReady = function()
    return G.tearOwned()
  end
  G.questStatus = function(game)
    return statusText(game or G.game)
  end
  G.requiredSteps = 0
  G.requiredWins = 0

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    local s = state(false)
    if type(out) ~= "table" or not (itemOwned(game, HEART)
        or itemOwned(game, TEAR) or (s and s.completed)) then return out end
    local right = s and s.completed and "GOROCHU"
      or (itemOwned(game, TEAR)
        and tr("TEAR", "TRÄNE") or tr("PLANT", "WERK"))
    return mod.ui.insertBefore(out, tr("SAVE", "SICHERN"), {
      label = tr("THUNDER PATH", "DONNERPFAD"),
      right = right,
      ascendantMenu = true,
      ascendantLabel = tr("GOROCHU RESEARCH", "GOROCHU-FORSCHUNG"),
      ascendantOrder = 16,
      ascendantKey = "gorochu_quest",
      onSelect = function()
        showText(game, statusText(game))
      end,
    })
  end, 272)

  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or G.game
    local mapId = ev and (ev.mapId or ev.map and ev.map.id)
    if game then refreshShrine(game, mapId) end
  end)

  mod.events:on("save.loaded", function()
    if not G.game then return end
    G.migrate(G.game)
    local mapId = G.game.overworld and G.game.overworld.map
      and G.game.overworld.map.id
    refreshShrine(G.game, mapId)
  end)

  mod.events:on("pokemon.evolved", function(ev)
    if not (ev and ev.mon and ev.toSpecies == G.id) then return end
    local s = state()
    s.completed = true
    s.playerEvolved = true
    s.completedAt = os.time()
    persist(s)
  end)

  -- This outermost post-processing guard also covers Randomizer output and
  -- trainer teams supplied by other compatible gameplay layers. It does not
  -- mutate their tables; it only masks Gorochu until the player has performed
  -- the evolution on this save.
  mod.hooks:wrap("trainer.party",
    function(nextParty, oppClass, partyIndex, party)
      local resolved = nextParty(oppClass, partyIndex, party)
      return G.sanitizeTrainerTeam(resolved)
    end, 100000)

  return G
end
