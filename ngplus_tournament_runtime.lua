-- Safe field/battle bridge for the NG+ World Rank controller. Durable state
-- stays in ngplus_tournament.lua; this file owns only process-local actors,
-- presentation and battle receipts.

return function(mod, opts)
  opts = opts or {}
  local R = { live = nil, battles = {}, pending = false, settlement = nil,
    departure = nil, waitForWorldStep = false, presentationEpoch = 0 }
  local tournament = assert(opts.tournament, "tournament required")
  local rosters = assert(opts.rosters, "roster builder required")
  local placement = assert(opts.placement, "bounded placement required")
  local postgame = assert(opts.postgame, "postgame battle authority required")
  local policy = assert(opts.policy, "battle policy required")
  local TEXT_ID = "TEXT_KA_WORLD_RANK_OPPONENT"

  local function call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, first, second = pcall(fn, ...)
    if not ok then return nil end
    return first, second
  end

  local function tr(en, de)
    local i18n = opts.i18n
    if i18n and type(i18n.text) == "function" then
      local value = call(i18n.text, en, de)
      if type(value) == "string" then return value end
    end
    return en
  end

  local function enabled()
    if type(opts.enabled) == "function" then
      local value = call(opts.enabled)
      return value ~= false
    end
    if type(tournament.enabled) == "function" then
      return call(tournament.enabled) ~= false
    end
    return true
  end

  local function pushText(game, text, done)
    if type(opts.showText) == "function" then
      return call(opts.showText, game, text, done) == true
    end
    if not (game and game.stack) then return false end
    local ok, TextBox = pcall(require, "src.render.TextBox")
    if not (ok and TextBox and type(TextBox.new) == "function") then
      return false
    end
    local made, box = pcall(TextBox.new, game, text, done)
    if not made or not box then return false end
    local pushed, accepted = pcall(game.stack.push, game.stack, box)
    return pushed and accepted ~= false
  end

  function R.presentText(game, text, done, receipt)
    if type(receipt) ~= "table" or type(receipt.id) ~= "string"
        or type(receipt.owner) ~= "string" then
      return pushText(game, text, done)
    end
    if R.calling then return false end
    local state = call(tournament.state, game)
    if not (type(state) == "table" and state.owner == receipt.owner) then
      return false
    end
    local session = {
      id = receipt.id, owner = receipt.owner, save = game and game.save,
      epoch = R.presentationEpoch,
    }
    R.calling = session
    local completed = false
    local function finish()
      if completed then return end
      completed = true
      if R.calling ~= session or session.epoch ~= R.presentationEpoch then
        return
      end
      R.calling = nil
      local current = game and game.save == session.save
        and call(tournament.state, game) or nil
      if type(current) == "table" and current.owner == session.owner then
        call(tournament.ackPresentation, game, session.id)
      end
      if type(done) == "function" then pcall(done) end
      R.pending = true
    end
    local shown = pushText(game, text, finish)
    if not shown and R.calling == session then R.calling = nil end
    return shown
  end

  local function showCall(game, text, done)
    if type(opts.showCall) == "function" then
      return call(opts.showCall, game, text, done) == true
    end
    local hub = mod.exports and mod.exports.signalsHub
    if hub and type(hub.showOakCall) == "function" then
      return call(hub.showOakCall, game, text, done) == true
    end
    return pushText(game, text, done)
  end

  local function linkActive(game)
    return game and (game.linkSession ~= nil and game.linkSession ~= false
      or type(game.linkNet) == "table" and game.linkNet.closed ~= true) or false
  end

  local function removeLive(expected)
    local live = expected or R.live
    if not live then return true end
    if R.live ~= live then return live.npcId == nil end
    if live.npcId and mod.world and type(mod.world.removeNpc) == "function" then
      local ok, removed, reason = pcall(
        mod.world.removeNpc, mod.world, live.npcId)
      local alreadyGone = ok and removed == nil and type(reason) == "string"
        and reason:find("no runtime object", 1, true) ~= nil
      if not (ok and (removed == true or alreadyGone)) then
        live.removalPending = true
        R.pending = true
        return false
      end
      live.npcId = nil
    elseif live.npcId then
      live.removalPending = true
      R.pending = true
      return false
    end
    live.removalPending = nil
    R.live = nil
    return true
  end

  local function invalidatePresentation()
    R.presentationEpoch = R.presentationEpoch + 1
    R.calling = nil
  end

  local function retireDeparture(departure, waitForStep)
    departure = departure or R.departure
    if not departure or R.departure ~= departure then return true end
    if not removeLive(departure.live) then
      departure.removalPending = true
      return false
    end
    departure.removalPending = nil
    R.departure = nil
    if waitForStep then R.waitForWorldStep = true end
    return true
  end

  local function clearRuntime()
    invalidatePresentation()
    local departure = R.departure
    if departure then departure.cancelled = true end
    if removeLive(departure and departure.live or nil) then
      R.departure = nil
    elseif departure then
      departure.removalPending = true
    end
    for battle in pairs(R.battles) do R.battles[battle] = nil end
    R.settlement = nil
    R.launching = nil
    R.pending = false
    R.waitForWorldStep = false
  end

  local function writeGameSave(game)
    if not (game and type(game.writeSave) == "function") then return false end
    local ok, result = pcall(game.writeSave, game)
    return ok and result ~= false
  end

  local function persistSettlement()
    local settlement = R.settlement
    if not settlement then return true end
    local receipt, resolution = settlement.receipt, settlement.resolution
    if not (receipt and receipt.game and receipt.game.save == receipt.save) then
      R.battles[settlement.battle] = nil
      R.settlement = nil
      return false
    end
    -- mod.save:set only updates the live save table. Commit the resolved token,
    -- notices and reward queue to disk before any farewell can acknowledge the
    -- battle. A failed writer keeps this process-local settlement sealed for a
    -- later safe-field retry; a cold reload then correctly returns to the last
    -- pre-battle disk snapshot instead of losing a purported championship.
    if not writeGameSave(receipt.game) then
      R.pending = true
      return false
    end
    R.battles[settlement.battle] = nil
    R.settlement = nil
    local live = R.live
    if live and live.token == receipt.token and live.owner == receipt.owner
        and live.save == receipt.save
        and type(resolution.departureNoticeId) == "string" then
      R.departure = {
        noticeId = resolution.departureNoticeId,
        token = receipt.token,
        owner = receipt.owner,
        save = receipt.save,
        live = live,
      }
      R.waitForWorldStep = false
    else
      removeLive(live)
    end
    R.pending = true
    return true
  end

  local function currentOverworld(game)
    if game and type(game.overworld) == "table" then return game.overworld end
    return mod.world and type(mod.world.overworld) == "function"
      and call(mod.world.overworld, mod.world) or nil
  end

  local function fieldReady(game)
    local ow = currentOverworld(game)
    local player = ow and ow.player
    if not (game and game.stack and type(game.stack.top) == "function"
        and ow and type(player) == "table") or linkActive(game) then
      return false
    end
    if call(game.stack.top, game.stack) ~= ow
        or player.moving or player.inputLocked
        or ow.transitioning or ow.engaging or ow.emote
        or ow.teleportOut or ow.flyAnim or ow.healAnim or ow.pikaHop
        or ow.cutAnim or ow.dustAnim or ow.fishPose
        or player.spinning or player.fishing
        or #(ow.scriptMoves or {}) > 0 then return false end
    if ow.runner and type(ow.runner.isRunning) == "function"
        and call(ow.runner.isRunning, ow.runner) ~= false then return false end
    return true
  end

  local function opponentProof(classId, game)
    if type(classId) ~= "string" or classId == "" then return nil end
    if type(rosters.trainerProof) ~= "function" then return nil end
    local proof = call(rosters.trainerProof, game or R.game, classId)
    return type(proof) == "table" and proof or nil
  end

  local function locationFor(model)
    if type(model.locationId) ~= "string" or model.locationId == "" then
      return nil
    end
    for _, row in ipairs(opts.data.locations or {}) do
      if row.id == model.locationId and row.mapId == model.mapId then
        return row
      end
    end
  end

  function R.refresh(game)
    game = game or R.game
    if not enabled() then removeLive(); return false end
    if not fieldReady(game) then return false end
    if R.departure or R.waitForWorldStep then return false end
    local model = call(tournament.worldRankModel, game)
    local proof = type(model) == "table"
      and opponentProof(model.opponentClass, game) or nil
    local sprite = proof and proof.overworldSprite
      and proof.overworldSprite.id or nil
    if not (type(model) == "table" and model.eligible == true
        and model.active == true and type(model.encounterToken) == "string"
        and type(model.spawnAuthority) == "string"
        and type(sprite) == "string" and sprite ~= "") then
      removeLive(); return false
    end
    if R.live and (R.live.token ~= model.encounterToken
        or R.live.owner ~= model.owner
        or R.live.spawnAuthority ~= model.spawnAuthority
        or R.live.sprite ~= sprite) then removeLive() end
    if R.live then return true end
    local ow = currentOverworld(game)
    if not (ow and ow.map and ow.map.id == model.mapId) then return false end
    local location = locationFor(model)
    if not location then return false end
    local x, y = placement.findWide(ow, location and location.cells or {})
    if not x then return false end
    local name = "KA_WORLD_RANK_" .. tostring(tournament.hash(
      model.spawnAuthority))
    local ok, npcId = pcall(mod.world.spawnNpc, mod.world, model.mapId, {
      name = name,
      sprite = sprite,
      movement = "STAY", range = "DOWN", text = TEXT_ID,
      trainerClass = model.opponentClass, x = x, y = y,
      locationId = model.locationId,
      spawnAuthority = model.spawnAuthority,
    })
    if not ok or not npcId then return false end
    R.live = { token = model.encounterToken, owner = model.owner,
      spawnAuthority = model.spawnAuthority, locationId = model.locationId,
      npcId = npcId, mapId = model.mapId, name = name, sprite = sprite,
      opponent = model.opponent, opponentClass = model.opponentClass,
      save = game.save }
    return true
  end

  local function encounter(game)
    local model = call(tournament.worldRankModel, game)
    if not (type(model) == "table" and model.eligible == true
        and model.active == true and R.live and R.live.save == game.save
        and R.live.owner == model.owner
        and R.live.token == model.encounterToken
        and R.live.spawnAuthority == model.spawnAuthority) then
      return nil
    end
    local proof = opponentProof(model.opponentClass, game)
    if not (type(proof) == "table" and proof.overworldSprite
        and proof.overworldSprite.id == R.live.sprite) then
      return nil, nil, "trainer-authority", model
    end
    return model, {
      formatId = model.formatId, rank = model.rank,
      token = model.encounterToken,
      opponent = { class = model.opponentClass, name = model.opponent },
    }
  end

  local function languageFor(game)
    if type(opts.language) == "function" then
      local value = call(opts.language, game)
      if value == "de" then return "de" end
    end
    local exported = mod.exports and mod.exports.language
    return type(exported) == "function" and call(exported) == "de"
      and "de" or "en"
  end

  local function dialogueValues(model)
    return {
      TOURNAMENT = model.tournament,
      RULE = model.rule,
      RANK = model.rank,
      OPPONENT = model.opponent,
      CHAMPION = model.opponent,
      LOCATION = model.location,
    }
  end

  local function rejectionText(game, model, reason)
    if type(opts.data.renderEntryRejection) == "function" then
      local text = call(opts.data.renderEntryRejection, reason,
        languageFor(game), dialogueValues(model))
      if type(text) == "string" and text ~= "" then return text end
    end
    return tr(
      "ENTRY DENIED. The complete team or opponent authority is incomplete. Nothing was recorded.",
      "TEILNAHME ABGELEHNT. Team oder Gegner-Authority ist unvollständig. Nichts wurde gespeichert.")
  end

  local function introText(game, model)
    local values = dialogueValues(model)
    if model.rank <= 2 and type(opts.data.renderDialogue) == "function" then
      local text = call(opts.data.renderDialogue, "championIntro",
        languageFor(game), values)
      if type(text) == "string" and text ~= "" then return text end
    end
    if type(opts.data.renderOpponentDialogue) == "function" then
      local text = call(opts.data.renderOpponentDialogue,
        model.opponentClass, "intro", languageFor(game), values)
      if type(text) == "string" and text ~= "" then return text end
    end
    if type(opts.data.renderDialogue) == "function" then
      local text = call(opts.data.renderDialogue, "opponentIntro",
        languageFor(game), values)
      if type(text) == "string" and text ~= "" then return text end
    end
    return tr(
      model.opponent .. ": Show me the whole team. We fight without items.",
      model.opponent .. ": Zeig mir das ganze Team. Wir kämpfen ohne Items.")
  end

  local function authorityMissingText(game, model)
    local values = { OPPONENT = model and model.opponent
      or R.live and R.live.opponent or "TRAINER" }
    if type(opts.data.renderDialogue) == "function" then
      local text = call(opts.data.renderDialogue, "opponentAuthorityMissing",
        languageFor(game), values)
      if type(text) == "string" and text ~= "" then return text end
    end
    return tr(
      "OAK: This exact opponent is not cleared for battle today.",
      "EICH: Dieser Gegner ist heute nicht für den Kampf freigegeben.")
  end

  local function liveTalkMatches(game, ow, npc)
    return npc and npc.def and R.live and R.live.save == game.save
      and npc.def.name == R.live.name
      and npc.def.locationId == R.live.locationId
      and npc.def.spawnAuthority == R.live.spawnAuthority
      and ow == currentOverworld(game) and ow.map
      and ow.map.id == R.live.mapId
  end

  function R.handleTalk(game, ow, npc, done)
    if not enabled() then return false end
    if not fieldReady(game) or R.launching then return false end
    if not liveTalkMatches(game, ow, npc) then return false end
    local model, row, encounterReason, sealedModel = encounter(game)
    if encounterReason == "trainer-authority" then
      pushText(game, authorityMissingText(game, sealedModel), done)
      return true
    end
    if not model then return false end
    local legal, legalReason = call(tournament.validateTeam,
      game, model.formatId)
    if legal ~= true then
      pushText(game, rejectionText(game, model, legalReason), done)
      return true
    end
    local roster, rosterReason = call(rosters.build, game, row,
      game.save and game.save.party or {})
    if type(roster) ~= "table" then
      if rosterReason == "trainer-authority"
          or rosterReason == "format-authority" then
        pushText(game, authorityMissingText(game, model), done)
        return true
      end
      pushText(game, rejectionText(game, model,
        rosterReason or "trainer-authority"), done)
      return true
    end
    R.launching = row.token
    local function launch()
      if R.launching ~= row.token then return end
      R.launching = nil
      local current = encounter(game)
      if not (current and current.encounterToken == row.token) then
        if done then pcall(done) end
        return
      end
      -- The engine constructor marks enemy species as seen before pushBattle.
      -- Keep that otherwise-correct behavior only after the encounter was
      -- actually accepted by the stack; a constructor/policy/push failure is
      -- not a battle and must leave no discovery side effect behind.
      local seen = game.save and game.save.pokedex
        and game.save.pokedex.seen
      local seenSnapshot = {}
      if type(seen) == "table" then
        for species, value in pairs(seen) do seenSnapshot[species] = value end
      end
      local function rollbackConstructor()
        if type(seen) ~= "table" then return end
        for species in pairs(seen) do seen[species] = nil end
        for species, value in pairs(seenSnapshot) do seen[species] = value end
      end
      local ok, battle = pcall(postgame.newForcedBattle, game, roster.class,
        roster.team, nil, { kind = "world_rank", token = row.token,
          source = "world_rank", suppressRewards = true })
      local policyOk, policyResult = false, nil
      if ok and type(battle) == "table" and not battle.dead then
        policyOk, policyResult = pcall(policy.apply, battle, roster)
      end
      if not (ok and type(battle) == "table" and not battle.dead)
          or not policyOk or policyResult == false then
        rollbackConstructor()
        if done then pcall(done) end
        return
      end
      battle.worldRankToken = row.token
      battle.worldRankFormat = row.formatId
      battle.trainer = setmetatable({ name = model.opponent },
        { __index = type(battle.trainer) == "table" and battle.trainer or {} })
      R.battles[battle] = { token = row.token, owner = model.owner,
        game = game, save = game.save, spawnAuthority = model.spawnAuthority }
      local priorFinish = battle.onFinish
      local finishCalled = false
      battle.onFinish = function(result)
        if finishCalled then return end
        finishCalled = true
        if type(priorFinish) == "function" then pcall(priorFinish, result) end
        if ow and type(ow.afterBattle) == "function" then
          pcall(ow.afterBattle, ow, result, battle)
        end
        if done then pcall(done) end
        R.pending = true
      end
      local pushed, accepted = false, nil
      if ow and type(ow.pushBattle) == "function" then
        pushed, accepted = pcall(ow.pushBattle, ow, battle)
      end
      if not pushed or accepted == false then
        rollbackConstructor()
        R.battles[battle] = nil
        battle.onFinish = priorFinish
        if done then pcall(done) end
      end
    end
    if not pushText(game, introText(game, model), launch) then
      R.launching = nil
      if done then pcall(done) end
      return false
    end
    return true
  end

  local function present(game)
    if not enabled() then return false end
    if R.calling then return false end
    local receipt = call(tournament.pendingPresentation, game)
    if type(receipt) ~= "table" then return false end
    local text = call(tournament.presentationText, game, receipt)
    if type(text) ~= "string" or text == "" then return false end
    local session = {
      id = receipt.id, owner = receipt.owner, save = game and game.save,
      epoch = R.presentationEpoch,
    }
    R.calling = session
    local completed = false
    local function done()
      if completed then return end
      completed = true
      if R.calling ~= session or session.epoch ~= R.presentationEpoch then
        return
      end
      R.calling = nil
      local state = game and game.save == session.save
        and call(tournament.state, game) or nil
      if type(state) == "table" and state.owner == session.owner then
        call(tournament.ackPresentation, game, session.id)
      end
      local departure = R.departure
      if departure and departure.noticeId == session.id
          and departure.owner == session.owner
          and departure.save == session.save then
        retireDeparture(departure, true)
      end
      R.pending = true
    end
    local dialogue = opts.data.dialogue and opts.data.dialogue[receipt.kind]
    local context = type(dialogue) == "table" and dialogue.context or nil
    local fieldText = receipt.kind == "playerWin"
      or receipt.kind == "playerLoss"
      or context == "battle_result"
      or context == "opponent_talk"
    local shown
    if fieldText then
      shown = pushText(game, text, done)
    else
      shown = showCall(game, text, done)
    end
    if not shown then
      if R.calling == session then R.calling = nil end
      local departure = R.departure
      if departure and departure.noticeId == receipt.id
          and departure.owner == receipt.owner
          and departure.save == (game and game.save) then
        retireDeparture(departure, true)
      end
      -- Keep the durable receipt unacknowledged. A later real field edge may
      -- present it again, but this pump must not attempt the same push twice.
      return true
    end
    return true
  end

  local function adapterForRewards()
    if type(opts.rewardAdapter) == "function" then
      local adapter = call(opts.rewardAdapter)
      return type(adapter) == "table" and adapter or nil
    end
    return type(opts.rewardAdapter) == "table" and opts.rewardAdapter or nil
  end

  local function pendingRewards(game)
    local rows = call(tournament.pendingRewards, game)
    return type(rows) == "table" and rows or {}
  end

  local function rewardGone(game, id)
    for _, row in ipairs(pendingRewards(game)) do
      if row.id == id then return false end
    end
    return true
  end

  local function recordRewardLifecycle(game, descriptor, outcome)
    if type(outcome) ~= "table" then return false end
    local receipt = type(outcome.receipt) == "table" and outcome.receipt or {}
    descriptor = type(descriptor) == "table" and descriptor or {}
    local id = receipt.id or descriptor.id
    local formatId = receipt.formatId or descriptor.formatId
      or outcome.formatId
    local species = receipt.species or outcome.speciesLabel or outcome.species
    local status = outcome.status
    if type(id) ~= "string" or id == "" then return false end
    local recorded = false
    if formatId == "gold" and (status == "full" or status == "delivered") then
      local jackpot = receipt.goldJackpot
      if jackpot == nil and status == "delivered" then
        jackpot = type(species) == "string" and species ~= ""
      end
      if jackpot == true and type(species) == "string" and species ~= "" then
        recorded = call(tournament.recordLifecycle, game, "goldJackpot", id,
          { SPECIES = species }) == true or recorded
      elseif jackpot == false and status == "delivered" then
        recorded = call(tournament.recordLifecycle, game, "goldNoJackpot", id,
          {}) == true or recorded
      end
    end
    if status == "full" and type(species) == "string" and species ~= "" then
      recorded = call(tournament.recordLifecycle, game, "rewardPending", id,
        { SPECIES = species }) == true or recorded
    elseif status == "delivered" and type(species) == "string"
        and species ~= "" then
      recorded = call(tournament.recordLifecycle, game, "rewardDelivered", id,
        { SPECIES = species }) == true or recorded
    end
    return recorded
  end

  local function syncRewardLifecycle(game)
    local adapter = adapterForRewards()
    if not (adapter and type(adapter.status) == "function") then return false end
    local descriptor = pendingRewards(game)[1]
    local status = call(adapter.status, game, descriptor)
    if type(status) ~= "table" then return false end
    if not descriptor and type(tournament.lastRewardClaim) == "function" then
      descriptor = call(tournament.lastRewardClaim, game)
    end
    return recordRewardLifecycle(game, descriptor, status)
  end

  local function reconcileReward(game)
    local descriptor = pendingRewards(game)[1]
    local adapter = adapterForRewards()
    if not (descriptor and adapter and type(adapter.reconcile) == "function") then
      return false
    end
    if type(adapter.status) == "function" then
      local status = call(adapter.status, game, descriptor)
      if type(status) == "table" then
        recordRewardLifecycle(game, descriptor, status)
        if status.ready == false then return false end
      end
    end
    local result, grants = call(adapter.reconcile, game, descriptor)
    recordRewardLifecycle(game, descriptor, result)
    if rewardGone(game, descriptor.id) then return true end
    if type(result) == "table" and result.committed == true then
      grants = result
    elseif result == true then
      grants = type(grants) == "table" and grants or {
        committed = true,
        title = descriptor.titleId ~= nil,
        card = descriptor.cardId ~= nil,
      }
    else
      return false
    end
    return call(tournament.markRewardClaimed, game, descriptor.id, grants)
      == true
  end

  function R.pump(game)
    game = game or R.game
    if not enabled() then clearRuntime(); return false end
    if R.pending ~= true then return false end
    if not fieldReady(game) then return false end
    if R.settlement and not persistSettlement() then return false end
    R.pending = false
    local departure = R.departure
    if departure and departure.removalPending then
      if not retireDeparture(departure, true) then return false end
    end
    if R.waitForWorldStep then return false end
    syncRewardLifecycle(game)
    if present(game) then return true end
    reconcileReward(game)
    syncRewardLifecycle(game)
    if present(game) then return true end
    return R.refresh(game)
  end

  function R.battleCount()
    local count = 0
    for _ in pairs(R.battles) do count = count + 1 end
    return count
  end

  -- Content registries freeze before game.install. Register authored talk
  -- seams while main.lua is still loading; runtime state is resolved later.
  for _, location in ipairs(opts.data.locations or {}) do
    mod.content.map_scripts:register(location.mapId, {
      priority = 2875,
      talk = { [TEXT_ID] = function(liveGame, ow, npc, done)
        return R.handleTalk(liveGame, ow, npc, done)
      end },
    })
  end

  function R.install(game)
    R.game = game
    -- Installation and every later lifecycle edge schedule exactly one safe
    -- field reconciliation. Consecutive idle input frames stay presentation-
    -- free until another event or asynchronous completion dirties the runtime.
    R.pending = true
    if R._installed then return true end
    R._installed = true
    mod.events:on("world.stepped", function(event)
      R.game = event and event.game or R.game
      R.waitForWorldStep = false
      R.pending = true
    end, -50)
    mod.events:on("battle.ended", function(event)
      local battle = event and event.battle
      local receipt = battle and R.battles[battle]
      if not receipt then return end
      local result = event.result == "win" and "win"
        or (event.result == "lose" or event.result == "loss") and "loss"
        or nil
      if not result or receipt.game.save ~= receipt.save then return end
      local state = call(tournament.state, receipt.game)
      if not (type(state) == "table" and state.owner == receipt.owner) then
        return
      end
      local ok, resolution = pcall(tournament.resolve, receipt.game,
        receipt.token, result)
      if not ok or type(resolution) ~= "table" then return end
      R.settlement = {
        battle = battle, receipt = receipt, resolution = resolution,
      }
      persistSettlement()
    end, 50)
    mod.events:on("save.loading", function()
      clearRuntime()
      R.game = nil
    end, 4000)
    mod.events:on("save.created", function(event)
      clearRuntime()
      R.game = event and event.game or R.game
      R.pending = true
    end, 4000)
    mod.events:on("save.loaded", function(event)
      clearRuntime()
      R.game = event and event.game or R.game
      R.pending = true
    end, 4000)
    mod.events:on("link.connected", function() clearRuntime() end, 4000)
    local function mapHandoff(event)
      R.game = event and event.game or R.game
      local departure = R.departure
      if departure then
        departure.cancelled = true
        invalidatePresentation()
        retireDeparture(departure, true)
      end
      R.pending = true
    end
    mod.events:on("map.entered", mapHandoff)
    mod.events:on("map.reloaded", mapHandoff)
    mod.events:on("mod.options_changed", function(event)
      if not (event and event.mod == mod.id
          and event.key == "grand_tournament") then return end
      if event.value == false then clearRuntime()
      else R.pending = true end
    end, 4000)
    if mod.hooks and type(mod.hooks.wrap) == "function" then
      mod.hooks:wrap("battle.enemy_action", function(nextAction, battle)
        if not (battle and battle.ascendantTournament == true
            and battle.ascendantNoItems == true) then
          return nextAction(battle)
        end
        -- wAICount resets for every incoming enemy. Seal it on every action
        -- boundary, then reject even a custom brain that still emits aiItem.
        battle.aiUses = 0
        local action = nextAction(battle)
        if type(action) ~= "table" or action.special ~= "aiItem" then
          return action
        end
        local ok, TrainerAI = pcall(require, "src.battle.TrainerAI")
        if ok and TrainerAI and type(TrainerAI.chooseMove) == "function"
            and battle.enemy and battle.rng then
          return TrainerAI.chooseMove(battle.enemy, battle.rng, battle)
        end
        return nil
      end, 6000)
      mod.hooks:wrap("input.step", function(nextStep, active, dt)
        nextStep(active, dt)
        R.pump(active or R.game)
      end, 5000)
    end
    return true
  end

  return R
end
