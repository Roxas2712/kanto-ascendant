-- Kanto Ascendant 6.7: durable Rocket recovery raid progression.
-- Owns gates, immutable instance receipts, loss stacking and reward plans.
-- Map geometry and battle presentation are separate adapters.

return function(mod, opts)
  opts = opts or {}
  local sources = assert(opts.sources, "Rocket source authority missing")
  local generationRules = opts.generationRules
  local data = assert(opts.data, "Rocket raid data missing")
  local captureAvailable = opts.captureAvailable
  local R = { schema="kanto-ascendant-rocket-raids/v1", version=1,
    CARD_ID="KASC-67-ROCKET-RECOVERY-RAIDS",
    OWNER="kasc.rocket.recovery-raids/v1", OPTION_KEY="rocket_raids",
    stateKey="rocket_recovery_raids_67", game=nil, rewards=nil }
  local cooldownSteps=math.max(256,math.floor(tonumber(opts.cooldownSteps) or 2048))
  local function clock()
    if type(opts.clock)=="function" then
      local ok,value=pcall(opts.clock);if ok then return math.max(0,math.floor(tonumber(value)or 0))end
    end
    return math.max(0,math.floor(tonumber(mod.save:get("trainer_step_clock"))or 0))
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for key, child in pairs(value) do out[copy(key, seen)] = copy(child, seen) end
    return out
  end

  local function integer(value, minimum, maximum)
    value = tonumber(value)
    if not value or value ~= math.floor(value) then return nil end
    if minimum and value < minimum then return nil end
    if maximum and value > maximum then return nil end
    return value
  end

  local function flush(game)
    if not (game and type(game.writeSave)=="function") then return true end
    local ok, result = pcall(game.writeSave, game)
    return ok and result ~= false
  end

  local function emptyState()
    return { schema=R.schema,version=R.version,status="idle",incident=0,
      instance=0,fight=0,losses=0,source=nil,scaleReceipt=nil,
      rulesReceipt=nil,rewardPlan=nil,rewardReceipts={},repeatReceipts={},completed={},
      captureReceipts={},cellReceipts={},pendingCaptures={},captureIndex=0,
      captureAttempts={},campaignComplete=false,repeatable=false,readyAt=0 }
  end

  local function state(create)
    local raw = mod.save:get(R.stateKey)
    if type(raw)~="table" or raw.schema~=R.schema or raw.version~=R.version then
      raw=emptyState(); if create~=false then mod.save:set(R.stateKey,raw) end
    end
    raw.rewardReceipts=type(raw.rewardReceipts)=="table" and raw.rewardReceipts or {}
    raw.repeatReceipts=type(raw.repeatReceipts)=="table" and raw.repeatReceipts or {}
    raw.completed=type(raw.completed)=="table" and raw.completed or {}
    raw.captureReceipts=type(raw.captureReceipts)=="table" and raw.captureReceipts or {}
    raw.cellReceipts=type(raw.cellReceipts)=="table" and raw.cellReceipts or {}
    raw.pendingCaptures=type(raw.pendingCaptures)=="table" and raw.pendingCaptures or {}
    raw.captureAttempts=type(raw.captureAttempts)=="table" and raw.captureAttempts or {}
    raw.captureIndex=integer(raw.captureIndex,0) or 0
    return raw
  end

  local function enabled()
    return not (mod.options and type(mod.options.get)=="function"
      and mod.options:get("rocket_raids")==false)
  end

  R.enabled = enabled

  if opts.supportLog and type(opts.supportLog.registerSegment)=="function" then
    opts.supportLog.registerSegment({
      segmentId=R.CARD_ID,cardId=R.CARD_ID,version="1.0.0",
      schema="kasc.optional-feature-card/v1",owner=R.OWNER,
      active=enabled(),dependencyStatus="local-reviewed",
      providerStatus=enabled() and "runtime-loaded" or "cold-disabled",
      buildReceiptId="rocket_recovery_raids_67_data.lua",
      rollbackReceiptId="revert-card-commit",
    })
  end

  local function rules(game)
    if generationRules and type(generationRules.rulesReceipt)=="function" then
      local ok, value=pcall(generationRules.rulesReceipt,game)
      if ok and type(value)=="table" then return value end
    end
    return { schema="kasc-generation-rules-receipt/fallback",
      activeEpoch=1,supportedEpoch=1,unlockedEpoch=1,mode="kasc_67_current",
      dataHash="fallback" }
  end

  local function moveExists(game,id)
    return type(game and game.data and game.data.moves)=="table"
      and type(game.data.moves[id])=="table"
  end

  local function rewardPlan(game, instance, scale, receipt, repeatable)
    local maximum=math.min(integer(receipt.activeEpoch,1,6) or 1,
      integer(receipt.supportedEpoch,1,6) or 1)
    local pool={}
    for _,row in ipairs(data.moveRewards or {}) do
      if row.epoch<=maximum and not data.forbiddenFieldRewards[row.move]
          and moveExists(game,row.move) then pool[#pool+1]=row end
    end
    table.sort(pool,function(a,b)
      if a.epoch~=b.epoch then return a.epoch<b.epoch end
      return a.move<b.move
    end)
    local selected
    if #pool>0 then
      local seed=tostring(scale.rosterHash or "")..":"..tostring(instance)
      local n=0; for i=1,#seed do n=(n+seed:byte(i)*i)%2147483647 end
      selected=copy(pool[(n%#pool)+1])
    end
    local definition=data.instances[instance]
    return { schema="kanto-ascendant-rocket-reward/v1",instance=instance,
      trainerCard=not repeatable and definition and definition.card or nil,
      move=selected and selected.move or nil,
      item=selected and selected.item or nil,
      machineNumber=selected and selected.number or nil,
      moveEpoch=selected and selected.epoch or nil,
      delivery=selected and selected.delivery or nil,
      rulesDataHash=receipt.dataHash,scaleHash=scale.rosterHash,
      special=not repeatable and instance==#data.instances
        and "AFFECTION_RIBBON" or nil,
      repeatable=repeatable==true,
      evolutionCache=repeatable and "ROCKET_EVOLUTION_CACHE" or nil,
      shinyRollDenominator=repeatable and 64 or nil }
  end

  local function includes(values, expected)
    for _,value in ipairs(values or {}) do if value==expected then return true end end
    return false
  end

  local function recordCell(s, instanceId)
    for _,row in ipairs(data.contraband or {}) do
      if row.mode=="four_cell_encounter" and includes(row.instances,instanceId) then
        local receipt=type(s.cellReceipts[row.key])=="table"
          and s.cellReceipts[row.key] or {}
        receipt[instanceId]=true;s.cellReceipts[row.key]=receipt
      end
    end
  end

  local function captureReady(game,s,row,instanceId)
    -- Late-species captures are a separate KASC segment/card. Rocket raids
    -- may advertise their authored hooks but never activate one without an
    -- explicit provider receipt from that future segment.
    if type(captureAvailable) ~= "function" then return false end
    local ok, available = pcall(captureAvailable, game, row)
    if not ok or available ~= true then return false end
    if s.captureReceipts[row.key] then return false end
    if row.instance==instanceId then return true end
    if row.mode~="four_cell_encounter" or not includes(row.instances,instanceId) then
      return false
    end
    local receipt=s.cellReceipts[row.key] or {}
    for _,required in ipairs(row.instances or {}) do
      if receipt[required]~=true then return false end
    end
    return true
  end

  local function queueCaptures(game,s,instanceId)
    local pending={}
    for _,row in ipairs(data.contraband or {}) do
      if captureReady(game,s,row,instanceId) then
        pending[#pending+1]=copy(row)
      end
    end
    s.pendingCaptures=pending;s.captureIndex=#pending>0 and 1 or 0
    return #pending>0
  end

  local function finishIncident(game,s)
    local released,why=sources.release(game,"raid_complete")
    if not released then return false,why end
    s.status="complete";s.rewardPlan=nil;s.pendingCaptures={};s.captureIndex=0
    if not s.repeatable then s.campaignComplete=true end
    s.readyAt=clock()+cooldownSteps
    return true
  end

  local function advanceInstance(game,s)
    if not s.repeatable and s.instance<#data.instances then
      s.instance,s.fight=s.instance+1,1
      s.rewardPlan=rewardPlan(game,s.instance,s.scaleReceipt,s.rulesReceipt,false)
      s.status="active"
      return true
    end
    return finishIncident(game,s)
  end

  function R.offerModel(game)
    local choices=sources.sourceChoices(game)
    local s=state(false)
    local readyAt=integer(s.readyAt,0)or 0
    return { unlocked=sources.unlocked(game),enabled=enabled(),
      defaultChoice="no",sources=choices,requiresConfirmation=true,
      campaignComplete=s.campaignComplete==true,readyAt=readyAt,
      repeatReady=s.campaignComplete==true
        and s.status~="active"and s.status~="capture"and clock()>=readyAt }
  end

  function R.start(game, sourceId)
    if not enabled() then return false,"rocket_raids_disabled" end
    if not sources.unlocked(game) then return false,"eight_badges_required" end
    local s=state()
    if s.status=="active" or s.status=="capture" then
      return false,"raid_already_active"
    end
    if sourceId==nil then sourceId=sources.defaultSource(game) end
    if sourceId==nil then return false,"explicit_fallback_source_required" end
    if s.campaignComplete==true and clock()<(integer(s.readyAt,0)or 0) then
      return false,"repeatable_raid_cooldown"
    end
    local held,hold=sources.begin(game,sourceId,6)
    if not held then return false,hold end
    local scale,scaleErr=sources.scaleReceipt(game)
    if not scale then
      sources.release(game,"scale_failed")
      return false,scaleErr
    end
    local receipt=rules(game)
    s.incident=(integer(s.incident,0) or 0)+1
    s.repeatable=s.campaignComplete==true
    local startInstance=1
    if s.repeatable then startInstance=((s.incident-2)%#data.instances)+1 end
    s.status,s.instance,s.fight,s.losses="active",startInstance,1,0
    s.pendingCaptures={};s.captureIndex=0
    s.source=sourceId;s.scaleReceipt=copy(scale);s.rulesReceipt=copy(receipt)
    s.rewardPlan=rewardPlan(game,startInstance,scale,receipt,s.repeatable)
    mod.save:set(R.stateKey,s)
    if not flush(game) then
      sources.release(game,"start_save_failed")
      mod.save:set(R.stateKey,emptyState())
      return false,"raid_start_save_failed"
    end
    return true,copy(s)
  end

  function R.battlePolicy()
    return { bag=false,items=false,healing=false,pc=false,escape=false,
      teleport=false,reloadReroll=false,whiteoutEndsIncident=false }
  end

  local NO_ADDITIONAL_TARGET={
    eligible_box_pokemon_absent=true,legacy_fallback_unavailable=true,
    party_fallback_unavailable=true,no_usable_party_pokemon=true,
    custody_limit_reached=true,
  }

  function R.onLoss(game)
    local s=state(false)
    if s.status~="active" then return false,"raid_not_active" end
    local stacked,why=sources.stackLoss(game,s.source,1)
    if not stacked and not NO_ADDITIONAL_TARGET[why]then return false,why end
    s.losses=(integer(s.losses,0) or 0)+1
    s.lastLossStacked=stacked==true
    -- The incident's strength receipt is immutable. Recomputing it after
    -- Rocket takes another Pokemon would let repeated losses lower the level
    -- of this exact checkpoint, contradicting the sealed-fight contract.
    mod.save:set(R.stateKey,s)
    if not flush(game) then return false,"raid_loss_save_failed" end
    return true,copy(s)
  end

  function R.onFightWon(game)
    local s=state(false)
    if s.status~="active" then return false,"raid_not_active" end
    local def=data.instances[s.instance]
    if not def then return false,"raid_instance_invalid" end
    if s.fight<def.fights then
      s.fight=s.fight+1
    else
      if not s.repeatable and R.rewards
          and type(R.rewards.awardTrainerCard)=="function" then
        local ok,why=R.rewards.awardTrainerCard(def.card,
          "rocket_raid:"..def.id,game)
        if not ok then return false,why or "trainer_card_award_failed" end
      end
      if R.rewards and type(R.rewards.awardPlan)=="function" then
        local rewardKey=(s.repeatable and "repeat:"..tostring(s.incident)
          or "campaign")..":"..def.id
        local ok,why=R.rewards.awardPlan(game,rewardKey,s.rewardPlan)
        if not ok then return false,why or "raid_reward_delivery_failed" end
      end
      s.completed[def.id]=true
      if s.repeatable then
        -- Repeat runs have their own append-only incident ledger.  Never
        -- overwrite the authored campaign receipt: it owns one-time cards
        -- and special encounter unlocks.
        s.repeatReceipts[tostring(s.incident)]=copy(s.rewardPlan)
      else
        s.rewardReceipts[def.id]=copy(s.rewardPlan)
      end
      recordCell(s,def.id)
      -- A capture that was unavailable because the independent Late Species
      -- Card was OFF must not be lost forever. Once that provider returns,
      -- the next repeat visit to the matching relay can surface every still
      -- unclaimed one-time encounter. Existing capture receipts prevent any
      -- duplicate.
      if queueCaptures(game,s,def.id) then
        -- Rewards are already sealed, but custody remains held until every
        -- authored contraband encounter after this boss is actually caught.
        s.status="capture";s.rewardPlan=nil
      else
        local advanced,why=advanceInstance(game,s)
        if not advanced then return false,why end
      end
    end
    mod.save:set(R.stateKey,s)
    if not flush(game) then return false,"raid_progress_save_failed" end
    return true,copy(s)
  end

  function R.currentCapture()
    local s=state(false)
    if s.status~="capture" then return nil end
    local row=s.pendingCaptures[s.captureIndex]
    if type(row)~="table" then return nil end
    return copy(row)
  end

  function R.resolveCapture(game,result)
    local s=state(false)
    if s.status~="capture" then return false,"raid_capture_not_active" end
    local row=s.pendingCaptures[s.captureIndex]
    if type(row)~="table" then return false,"raid_capture_invalid" end
    s.captureAttempts[row.key]=(integer(s.captureAttempts[row.key],0) or 0)+1
    if result~="caught" then
      if result=="lose" then
        local stacked,why=sources.stackLoss(game,s.source,1)
        if not stacked and not NO_ADDITIONAL_TARGET[why]then return false,why end
        s.losses=(integer(s.losses,0) or 0)+1
        s.lastLossStacked=stacked==true
      end
      mod.save:set(R.stateKey,s)
      if not flush(game) then return false,"raid_capture_retry_save_failed" end
      return true,copy(s)
    end
    s.captureReceipts[row.key]={species=row.species,incident=s.incident,
      instance=data.instances[s.instance] and data.instances[s.instance].id,
      attempts=s.captureAttempts[row.key]}
    s.captureIndex=s.captureIndex+1
    if not s.pendingCaptures[s.captureIndex] then
      s.pendingCaptures={};s.captureIndex=0
      local advanced,why=advanceInstance(game,s)
      if not advanced then return false,why end
    end
    mod.save:set(R.stateKey,s)
    if not flush(game) then return false,"raid_capture_save_failed" end
    return true,copy(s)
  end

  function R.setEnabled(game,value)
    if value~=false then return true end
    local s=state(false)
    -- Release through the source authority even if a process interruption
    -- left custody active before the raid receipt itself became active.
    -- With no custody this is an idempotent no-op.
    local released,releaseWhy=sources.release(game,"option_disabled")
    if not released then return false,releaseWhy end
    if s.status=="active" or s.status=="capture" then
      s.status="disabled_returned";s.rewardPlan=nil
      mod.save:set(R.stateKey,s)
      if not flush(game) then return false,"option_return_save_failed" end
    end
    return true
  end

  function R.prepareNewGamePlus(game)
    local s=state(false)
    local released,releaseWhy=sources.release(game,"new_game_plus")
    if not released then return false,releaseWhy end
    if s.status=="active" or s.status=="capture" then
      s.status="ngplus_returned";s.rewardPlan=nil
      mod.save:set(R.stateKey,s)
      if not flush(game) then return false,"ngplus_return_save_failed" end
    end
    return true
  end

  function R.objective()
    local s=state(false)
    if s.status~="active" and s.status~="capture" then return nil end
    local def=data.instances[s.instance]
    return { id=def.id,map=def.map,hostMap=def.hostMap,location=copy(def.location),
      incident=s.incident,
      instance=s.instance,totalInstances=#data.instances,fight=s.fight,
      totalFights=def.fights,losses=s.losses,source=s.source,
      scaleReceipt=copy(s.scaleReceipt),repeatable=s.repeatable==true,
      phase=s.status,capture=R.currentCapture() }
  end

  function R.status() return copy(state(false)) end
  function R.bindRewards(adapter)
    if type(adapter)~="table" then R.rewards=nil;return false end
    R.rewards=R.rewards or {}
    for key,value in pairs(adapter) do R.rewards[key]=value end
    return R.rewards~=nil
  end
  function R.install(game)
    R.game=game
    -- The option can already be OFF when an interrupted active save is
    -- loaded. The live option-change callback cannot fire retroactively, so
    -- installation itself must finish the promised custody return.
    if not enabled() then return R.setEnabled(game,false) end
    local s=state(false)
    -- The independent Late Species Card can be switched off between a boss
    -- receipt and its pending rescue. Never strand the Rocket campaign on a
    -- species that is no longer registered: defer it, advance normally, and
    -- let a later matching repeat relay surface it after the provider returns.
    if s.status=="capture"then
      local pending=s.pendingCaptures[s.captureIndex]
      if type(pending)=="table"and not captureReady(game,s,pending,s.instance)then
        s.pendingCaptures={};s.captureIndex=0
        local advanced,why=advanceInstance(game,s)
        if not advanced then return false,why end
        mod.save:set(R.stateKey,s)
        if not flush(game)then return false,"capture_defer_save_failed"end
      end
    end
    if s.status~="active"and s.status~="capture"then
      local released,why=sources.release(game,"orphan_recovery")
      if not released then return false,why end
    end
    return true
  end
  if mod.events and type(mod.events.on)=="function" then
    mod.events:on("mod.options_changed",function(ev)
      if not (ev and ev.mod==mod.id and ev.key=="rocket_raids"
          and ev.value==false and R.game) then return end
      local ok,why=R.setEnabled(R.game,false)
      if not ok and mod.log and type(mod.log.warn)=="function" then
        mod.log:warn("Rocket custody return pending: "..tostring(why))
      end
    end)
  end
  R.rewardPlan=rewardPlan
  R.data=data
  return R
end
