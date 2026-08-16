-- KA-INTERNAL: LEGACY-PATHS-001

return function(mod, opts)
  opts = opts or {}
  local journey = assert(opts.journey, "legacy paths need legacy journey")
  local wanderers = assert(opts.wanderers, "legacy paths need wanderer scaling")
  local data = assert(opts.data, "legacy paths need path data")
  local finaleController = opts.finale
  local i18n = opts.i18n
  local P = { game = nil, spawned = nil }

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function localized(row)
    return tr(row and row.en or "", row and row.de or "")
  end

  local function copy(value)
    if type(value) ~= "table" then return value end
    local out = {}
    for key, child in pairs(value) do out[key] = copy(child) end
    return out
  end

  local function active(save)
    local state = journey.state(save)
    return type(state) == "table" and state.runId ~= nil and state or nil
  end

  local function selectedAvatar(save)
    local state = active(save)
    if not state then return nil end
    if data.paths[state.avatar] then return state.avatar end
    local bucket = type(save.modData) == "table" and save.modData[mod.id]
    local chars = type(bucket) == "table" and bucket.extended_characters
    local candidate = type(chars) == "table" and chars.enabled == true
      and tostring(chars.player_character or ""):upper() or nil
    return data.paths[candidate] and candidate or nil
  end

  function P.syncAvatar(save)
    local state = active(save)
    if not state then return false end
    local avatar = selectedAvatar(save)
    if not avatar or state.avatar == avatar then return false end
    return journey.setAvatar(save, avatar)
  end

  local function badges(game)
    return require("src.inventory.Badges").count(game.data, game.save)
  end

  local function profile()
    local result = journey.profile()
    result.completedPaths = type(result.completedPaths) == "table"
      and result.completedPaths or { red = false, blue = false, green = false }
    return result
  end

  local function allPathsComplete(p)
    p = p or profile()
    return p.completedPaths.red and p.completedPaths.blue
      and p.completedPaths.green
  end

  function P.current(save)
    local state = active(save)
    if not state then return nil end
    local avatar = selectedAvatar(save)
    local path = data.paths[avatar]
    if not path then return { state = state, avatar = nil } end
    local stage = math.max(0, math.floor(
      tonumber(state.avatarQuestStage) or 0))
    return {
      state = state,
      avatar = avatar,
      path = path,
      stage = stage,
      next = path.stages[stage + 1],
      complete = state.pathComplete == true,
    }
  end

  function P.stageUnlocked(game, def)
    return def ~= nil and badges(game) >= math.max(0,
      math.floor(tonumber(def.badges) or 0))
  end

  function P.objective(game)
    game = game or P.game
    if not (game and active(game.save)) then return nil end
    local p = profile()
    if allPathsComplete(p) and not p.legacyPass then
      return {
        id = "legacy_finale",
        title = tr("KANTO'S LEGACY", "KANTOS VERMÄCHTNIS"),
        location = tr("OAK'S LAB", "EICHS LABOR"),
        current = 0, target = 1,
        detail = tr("Show Oak the three seals\nand face the final trial.",
          "Zeige Eich die drei\nSiegel und bestehe die\nletzte Prüfung."),
      }
    end
    local current = P.current(game.save)
    if not current then return nil end
    if not current.avatar then
      return {
        id = "legacy_avatar",
        title = tr("CHOOSE A LEGACY PATH", "WÄHLE EINEN VERMÄCHTNISWEG"),
        location = tr("OAK'S INTRO", "EICHS EINFÜHRUNG"),
        current = 0, target = 1,
        detail = tr("Choose RED, BLUE or GREEN\nto bind this journey's path.",
          "Wähle ROT, BLAU oder\nGRÜN für den Weg dieser\nReise."),
      }
    end
    if current.complete or not current.next then return nil end
    local unlocked = P.stageUnlocked(game, current.next)
    return {
      id = "legacy_path:" .. current.path.key .. ":" .. tostring(current.stage + 1),
      title = localized(current.path.title),
      location = unlocked and current.next.map:gsub("_", " ")
        or tr("KANTO GYMS", "KANTO-ARENEN"),
      current = math.min(badges(game), current.next.badges),
      target = current.next.badges,
      detail = unlocked and tr(
        "Find the marked path\nencounter at this location.",
        "Finde die markierte\nWegbegegnung an diesem Ort.")
        or tr(("Earn %d badges to reveal\nthe next path station.")
          :format(current.next.badges),
          ("Erringe %d Orden für die\nnächste Wegstation.")
          :format(current.next.badges)),
    }
  end

  local TITLE_KEYS = {
    legacy_path_red = "RED",
    legacy_path_blue = "BLUE",
    legacy_path_green = "GREEN",
    legacy_pass = "PASS",
  }

  function P.titleUnlocked(id)
    local key = TITLE_KEYS[id]
    local p = profile()
    if key == "PASS" then return p.legacyPass == true end
    local path = key and data.paths[key]
    return path and p.completedPaths[path.key] == true or false
  end

  function P.titleName(id)
    local key = TITLE_KEYS[id]
    if key == "PASS" then return tr("LEGACY KEEPER", "VERMÄCHTNIS-HÜTER") end
    local path = key and data.paths[key]
    return path and localized(path.reward) or nil
  end

  function P.titleRows(selected)
    local rows = {}
    for _, id in ipairs({ "legacy_path_red", "legacy_path_blue",
      "legacy_path_green", "legacy_pass" }) do
      if P.titleUnlocked(id) then
        rows[#rows + 1] = {
          label = P.titleName(id),
          right = selected == id and tr("ACTIVE", "AKTIV") or "",
          value = id,
        }
      end
    end
    return rows
  end

  local function safeContext(game)
    local ow = game and game.overworld
    if not (ow and ow.map and game.stack and game.stack:top() == ow) then
      return false
    end
    if ow.engaging or ow.emote or ow.transitioning or ow.teleportOut
        or #(ow.scriptMoves or {}) > 0 then return false end
    if ow.runner and ow.runner.isRunning and ow.runner:isRunning() then
      return false
    end
    return true
  end

  local function safeCell(ow, x, y)
    local map = ow.map
    return map:inBounds(x, y) and map:isWalkableCell(x, y)
      and not (map.warpAtCell and map:warpAtCell(x, y))
      and not (map.signAtCell and map:signAtCell(x, y))
      and not (map.isWarpTileCell and map:isWarpTileCell(x, y))
      and not ow:npcAtCell(x, y)
      and not (ow.player.cellX == x and ow.player.cellY == y)
  end

  function P.findSpawnCell(ow)
    if not (ow and ow.map and ow.player) then return nil end
    for distance = 2, 6 do
      for dx = -distance, distance do
        local dy = distance - math.abs(dx)
        for _, sign in ipairs(dy == 0 and { 1 } or { -1, 1 }) do
          local x, y = ow.player.cellX + dx, ow.player.cellY + dy * sign
          if safeCell(ow, x, y) then return x, y end
        end
      end
    end
    return nil
  end

  local function removeSpawn()
    if P.spawned and P.spawned.id then mod.world:removeNpc(P.spawned.id) end
    P.spawned = nil
  end

  local function dueStage(game, mapId)
    local current = P.current(game.save)
    if not (current and current.avatar and current.next
        and not current.complete and current.next.map == mapId
        and P.stageUnlocked(game, current.next)) then return nil end
    return current, current.next
  end

  local function finaleDue(game, mapId)
    if mapId ~= data.finale.map or not active(game.save) then return false end
    local p = profile()
    return allPathsComplete(p)
  end

  function P.refresh(game, mapId)
    game = game or P.game
    if not game then return false end
    P.syncAvatar(game.save)
    mapId = mapId or (game.overworld and game.overworld.map
      and game.overworld.map.id)
    local current, def = dueStage(game, mapId)
    local finale = finaleDue(game, mapId)
    if not (current or finale) or not safeContext(game) then
      if P.spawned and P.spawned.map ~= mapId then removeSpawn() end
      return false
    end
    local kind = finale and "finale" or current.avatar .. ":" .. tostring(current.stage + 1)
    if P.spawned and P.spawned.map == mapId and P.spawned.kind == kind then
      return true
    end
    removeSpawn()
    local ow = game.overworld
    local x, y = P.findSpawnCell(ow)
    if not x then return false end
    local row = finale and data.finale or def
    local id = mod.world:spawnNpc(mapId, {
      name = "KA_LEGACY_PATH_" .. kind:gsub(":", "_"),
      sprite = row.sprite, movement = "STAY", range = "DOWN",
      text = row.text, x = x, y = y,
    })
    if not id then return false end
    P.spawned = { id = id, map = mapId, kind = kind }
    return true
  end

  local pendingParty
  mod.hooks:wrap("trainer.party", function(nextParty, class, index, party)
    if pendingParty and pendingParty.class == class
        and pendingParty.index == index then
      return nextParty(class, index, copy(pendingParty.team))
    end
    return nextParty(class, index, party)
  end, 5200)

  local function classAndIndex(game, requested)
    local trainer = game.data.trainers[requested]
    if trainer and trainer.parties and trainer.parties[1] then return requested, 1 end
    for _, fallback in ipairs({ "OPP_COOLTRAINER_M", "OPP_COOLTRAINER_F",
      "OPP_SCIENTIST", "OPP_POKEMANIAC" }) do
      trainer = game.data.trainers[fallback]
      if trainer and trainer.parties and trainer.parties[1] then return fallback, 1 end
    end
  end

  function P.scaledTeam(game, species, stage)
    local tier = wanderers.progressTier(game)
    local level = math.min(100, tier.targetLevel + math.max(1,
      math.floor(tonumber(stage) or 1)) * 2)
    local count = math.min(#species, math.max(3,
      math.min(6, tier.teamSize + math.floor((stage or 1) / 2))))
    local team = {}
    for index = 1, count do
      team[index] = { species = species[index], level = level + ((index - 1) % 3) }
    end
    return team, tier
  end

  local function startBattle(game, ow, npc, class, species, stage, onFinish)
    local actualClass, partyIndex = classAndIndex(game, class)
    if not actualClass then npc.frozen = false return false end
    local team, tier = P.scaledTeam(game, species, stage)
    pendingParty = { class = actualClass, index = partyIndex, team = team }
    local battle = require("src.battle.BattleState").newTrainer(
      game, actualClass, partyIndex)
    pendingParty = nil
    battle.ascendantLegacyPath = true
    battle.ascendantLegacyTier = tier
    battle.introText = tr("A Legacy path keeper\nwants to fight!",
      "Ein Vermächtnis-Hüter\nfordert dich heraus!")
    battle.onFinish = function(result)
      ow:afterBattle(result, battle)
      onFinish(result)
    end
    ow:pushBattle(battle)
    return true
  end

  local function rewardItem(game, def)
    if not def.item or not game.data.items[def.item] then return false end
    return require("src.inventory.Bag").add(game.save, def.item, 1, game.data)
  end

  local function handleStage(game, ow, npc, current, def)
    npc.frozen = true
    npc:facePlayer(ow.player)
    game.stack:push(require("src.render.TextBox").new(game,
      localized(def.intro), function()
        startBattle(game, ow, npc, def.class, def.team, current.stage + 1,
          function(result)
            if result ~= "win" then npc.frozen = false return end
            local nextStage = current.stage + 1
            local completed = nextStage >= #current.path.stages
            local saved, err = journey.advancePath(game.save, nextStage, completed)
            if not saved then
              mod.log:error("legacy path write failed: " .. tostring(err))
              npc.frozen = false
              return
            end
            rewardItem(game, def)
            removeSpawn()
            game.stack:push(require("src.render.TextBox").new(game,
              localized(def.win)))
          end)
      end))
  end

  local function finaleBattle(game, ow, npc, index)
    local row = data.finale.teams[index]
    if not row then
      local saved, err = journey.completeFinale(game.save)
      if not saved then
        mod.log:error("legacy finale write failed: " .. tostring(err))
        npc.frozen = false
        return
      end
      removeSpawn()
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "OAK: Strength, knowledge\nand care are one legacy.\fThe permanent LEGACY\nPASS is now yours.",
        "EICH: Stärke, Wissen und\nFürsorge sind ein Erbe.\fDer dauerhafte\nVERMÄCHTNIS-PASS gehört dir.")))
      return
    end
    startBattle(game, ow, npc, row.class, row.team, 5 + index,
      function(result)
        if result ~= "win" then npc.frozen = false return end
        game.stack:push(require("src.render.TextBox").new(game, tr(
          index == 1 and "The seal of strength\nanswers." or index == 2
            and "The seal of knowledge\nanswers."
            or "The seal of care\nanswers.",
          index == 1 and "Das Siegel der Stärke\nantwortet." or index == 2
            and "Das Siegel des Wissens\nantwortet."
            or "Das Siegel der Fürsorge\nantwortet."),
          function() finaleBattle(game, ow, npc, index + 1) end))
      end)
  end

  local function handleFinale(game, ow, npc)
    if finaleController and finaleController.start then
      return finaleController.start(game, ow, npc)
    end
    npc.frozen = true
    npc:facePlayer(ow.player)
    game.stack:push(require("src.render.TextBox").new(game, tr(
      "OAK: You have walked all\nthree Legacy paths.\fStrength. Knowledge. Care.\nShow how they belong together!",
      "EICH: Du bist alle drei\nVermächtniswege gegangen.\fStärke. Wissen. Fürsorge.\nZeig, dass sie zusammengehören!"),
      function() finaleBattle(game, ow, npc, 1) end))
  end

  if mod.content and mod.content.map_scripts then
    for avatar, path in pairs(data.paths) do
      for index, def in ipairs(path.stages) do
        mod.content.map_scripts:register(def.map, {
          priority = 2700,
          talk = {
            [def.text] = function(game, ow, npc)
              local current = P.current(game.save)
              if not (current and current.avatar == avatar
                  and current.stage + 1 == index
                  and P.stageUnlocked(game, def)) then
                npc.frozen = false
                return
              end
              handleStage(game, ow, npc, current, def)
            end,
          },
        })
      end
    end
    mod.content.map_scripts:register(data.finale.map, {
      priority = 2700,
      talk = { [data.finale.text] = handleFinale },
    })
  end

  mod.events:on("game.ready", function(ev)
    P.game = ev and ev.game
    if P.game then P.syncAvatar(P.game.save) end
  end, 1200)
  mod.events:on("save.loaded", function(ev)
    P.game = ev and ev.game or P.game
    removeSpawn()
    if P.game then P.syncAvatar(P.game.save) end
  end, 1200)
  mod.events:on("character.selected", function(ev)
    local game = ev and ev.game or P.game
    local save = ev and ev.save or (game and game.save)
    if save then P.syncAvatar(save) end
  end, 1200)
  mod.events:on("map.entered", function(ev)
    local game = ev and ev.game or P.game
    if game then P.refresh(game, ev and ev.mapId) end
  end, 1200)
  mod.events:on("world.stepped", function(ev)
    if P.game and not P.spawned then P.refresh(P.game, ev and ev.mapId) end
  end, 1200)

  P.profile = profile
  P.allPathsComplete = allPathsComplete
  function P.setFinale(controller) finaleController = controller end
  P.data = data
  return P
end
