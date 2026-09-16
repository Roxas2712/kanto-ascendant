-- Kanto Heritage events: faithful Generation-I distribution builds,
-- five badge-gated cups, an optional roaming hunt, and a permanent archive.

return function(mod, opts)
  opts = opts or {}
  local data = assert(opts.data, "event archive data missing")
  local postgame = assert(opts.postgame, "postgame controller missing")
  local placement = assert(opts.placement, "runtime NPC placement missing")
  local i18n = opts.i18n
  local C = { game = nil, ascendant = nil }
  local pendingRoamer
  local activeCup
  local profiles = {}
  local refreshCupHosts
  local receiptCopy

  -- This receipt is deliberately attached to the owned Pokemon rather than
  -- its species definition.  A distributed Pokemon may therefore use the
  -- active battle projection without making the same later-generation
  -- species legal for wild encounters, AI teams or reward pools.
  local BATTLE_COMPAT_SCHEMA = "kasc/event-gift-battle-compat/v1"
  local BATTLE_COMPAT_OWNER = "kasc.events.event-archive/v1"

  local function externalHudOwned(battle)
    local qualityOfLife = type(mod.exports) == "table"
      and mod.exports.qualityOfLife or nil
    local battleOverlays = type(qualityOfLife) == "table"
      and qualityOfLife.battle or nil
    if type(battleOverlays) ~= "table"
        or type(battleOverlays.externalHudOwned) ~= "function" then
      return false
    end
    local ok, owned = pcall(
      battleOverlays.externalHudOwned, battleOverlays, battle)
    return ok and owned == true
  end

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
    if profile.giftCodeOnly == true then return false end
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

  local function stampBattleCompatibility(mon, profile)
    if not (type(mon) == "table" and type(profile) == "table") then
      return false
    end
    mon.eventDistribution = type(mon.eventDistribution) == "table"
      and mon.eventDistribution or {}
    mon.eventDistribution.battleCompatibility = {
      version = 1,
      schema = BATTLE_COMPAT_SCHEMA,
      owner = BATTLE_COMPAT_OWNER,
      profileId = profile.id,
      originalSpecies = profile.species,
      projection = "active-generation",
    }
    return true
  end

  local function profileForGame(game, profile)
    if type(profile)=='string' then profile=profiles[profile] end
    if profile and profile.megaSourceKey and not profile.megaAvailable then
      return nil,'mega_controller_unavailable'
    end
    if profile and profile.gigantamaxSourceKey and not profile.gigantamaxAvailable then
      return nil,'gigantamax_factor_unavailable'
    end
    if not profile or not profile.generationMoves then return profile end
    local epoch=type(opts.generationEpoch)=='function' and opts.generationEpoch(game) or 1
    epoch=math.max(1,math.min(7,math.floor(tonumber(epoch) or 1)))
    local build=profile.generationMoves[epoch]
    if not build or #build.moves==0 then return nil,'generation_moves_missing' end
    local resolved={};for k,v in pairs(profile)do resolved[k]=v end
    resolved.moves={};for i,id in ipairs(build.moves)do resolved.moves[i]=id end
    resolved.distributionEpoch=epoch
    resolved.learnsetGeneration=build.sourceEpoch
    resolved.learnsetVersionGroup=build.versionGroup
    return resolved
  end

  local function stampProfile(game, mon, profile, origin)
    if not (game and mon and profile) then return mon end
    profile=assert(profileForGame(game,profile))
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
    mon.stats = Stats.calc(
      species, profile.level, mon.dvs, mon.statExp, mon)
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
    if profile.guaranteedShiny then
      mon.eventDistribution.guaranteedShiny=true
    end
    if profile.generationMoves then
      mon.backendKey=profile.backendKey
      mon.eventDistribution.backendKey=profile.backendKey
      mon.eventDistribution.distributionEpoch=profile.distributionEpoch
      mon.eventDistribution.learnsetGeneration=profile.learnsetGeneration
      mon.eventDistribution.learnsetVersionGroup=profile.learnsetVersionGroup
      mon.eventDistribution.generationMoveSchema=profile.generationMoveSchema
      mon.eventDistribution.generationMoveRevision=profile.generationMoveRevision
    end
    mon.eventDistribution.identityRevision=profile.identityRevision
    stampBattleCompatibility(mon, profile)
    if profile.megaFormId then
      -- A gift records a preferred transformation, not permanent Mega stats,
      -- typing, ability or equipment. Activation still checks the controller.
      mon._kascGiftMega67={schema='kasc.gift-mega/v1',formId=profile.megaFormId,
        baseSpecies=profile.species,sourceKey=profile.megaSourceKey}
      mon.eventDistribution.megaFormId=profile.megaFormId
      mon.eventDistribution.megaSourceKey=profile.megaSourceKey
    end
    if profile.formId then
      mon.formId = profile.formId
      mon.form = profile.formId
      mon.baseSpecies = profile.baseSpecies
      mon.originGeneration = profile.originGeneration
      mon.eventDistribution.formId = profile.formId
      mon.eventDistribution.baseSpecies = profile.baseSpecies
      mon.eventDistribution.originGeneration = profile.originGeneration
    end
    if profile.gigantamaxFormId then
      mon._kascGigantamax67={schema='kasc.gigantamax-factor/v1',
        formId=profile.gigantamaxFormId,baseSpecies=profile.species,
        sourceKey=profile.gigantamaxSourceKey}
      mon.eventDistribution.gigantamaxFormId=profile.gigantamaxFormId
      mon.eventDistribution.gigantamaxSourceKey=profile.gigantamaxSourceKey
    end
    return mon
  end

  local function makeGift(game, profile, origin)
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(game.data, profile.species, profile.level)
    stampProfile(game, mon, profile, origin)
    require("src.battle.BattleState").stampOT(game.save, mon)
    return mon
  end

  receiptCopy = function(receipt)
    if type(receipt) ~= "table" or receipt.version ~= 1
        or type(receipt.digest) ~= "string" or #receipt.digest ~= 64
        or receipt.digest:match("^[0-9a-f]+$") == nil then return nil end
    local function identifier(value)
      return type(value) == "string" and #value >= 1 and #value <= 96
        and value:match("^[a-z0-9][a-z0-9_.-]*$") ~= nil
    end
    if not identifier(receipt.campaignId) or not identifier(receipt.eventId)
        or not identifier(receipt.profileId)
        or type(receipt.buildId) ~= "string" or #receipt.buildId < 1
        or #receipt.buildId > 128 then return nil end
    return {
      version = 1, digest = receipt.digest,
      campaignId = receipt.campaignId, buildId = receipt.buildId,
      eventId = receipt.eventId, profileId = receipt.profileId,
    }
  end


  local function sameMoves(actual, expected)
    if type(actual) ~= "table" or type(expected) ~= "table"
        or #actual ~= #expected then return false end
    for index, id in ipairs(expected) do
      if actual[index] ~= id then return false end
    end
    return true
  end

  -- Validate against this archive's registered profile catalogue.  Merely
  -- sharing a species with a gift is never sufficient, and code-only rows
  -- additionally require the persisted digest receipt.  The compatibility
  -- marker survives save/reload and evolution; the immutable distribution
  -- fields also admit legitimate pre-marker saves so they can be upgraded.
  local function battleCompatibleGift(mon)
    if type(mon) ~= "table" then return false, "mon" end
    local info = mon.eventDistribution
    if type(info) ~= "table" or type(info.id) ~= "string" then
      return false, "provenance"
    end
    local profile = profiles[info.id]
    if type(profile) ~= "table" then return false, "profile" end
    if profile.identityRevisions then
      local revision=info.identityRevision
      if revision==nil then revision=1 end
      local identity=profile.identityRevisions[revision]
      if not identity then return false,'identity_revision' end
      local resolved={};for k,v in pairs(profile)do resolved[k]=v end
      resolved.species=identity.species;resolved.baseSpecies=identity.baseSpecies
      profile=resolved
    elseif info.identityRevision~=nil then return false,'identity_revision' end
    local expectedMoves=profile.moves or {}
    if profile.generationMoves then
      local builds=profile.generationMoves
      if profile.generationMoveRevisions then
        -- Unversioned saved receipts predate the first move expansion.
        -- Unknown revisions never become permission to trust arbitrary moves.
        builds=profile.generationMoveRevisions[info.generationMoveRevision or 1]
      elseif info.generationMoveRevision~=nil then return false,'generation_revision' end
      local build=builds and builds[info.distributionEpoch]
      if not build or #build.moves==0 or info.backendKey~=profile.backendKey
          or info.generationMoveSchema~=profile.generationMoveSchema
          or info.learnsetGeneration~=build.sourceEpoch
          or info.learnsetVersionGroup~=build.versionGroup then
        return false,'generation_distribution'
      end
      expectedMoves=build.moves
    end
    if tonumber(info.originalLevel) ~= tonumber(profile.level)
        or not sameMoves(info.originalMoves, expectedMoves) then
      return false, "distribution"
    end
    if profile.guaranteedShiny and (info.guaranteedShiny~=true
        or not require('src.pokemon.Stats').isShiny(mon.dvs)) then
      return false,'shiny_distribution'
    end
    if profile.formId then
      if info.formId ~= profile.formId
          or info.baseSpecies ~= profile.baseSpecies
          or tonumber(info.originGeneration)
            ~= tonumber(profile.originGeneration) then
        return false, "form"
      end
    end
    if profile.megaFormId then
      local mega=mon._kascGiftMega67
      if info.megaFormId~=profile.megaFormId or info.megaSourceKey~=profile.megaSourceKey
          or type(mega)~='table' or mega.schema~='kasc.gift-mega/v1'
          or mega.formId~=profile.megaFormId or mega.sourceKey~=profile.megaSourceKey
          or mega.baseSpecies~=profile.species then return false,'mega_distribution' end
    end
    if profile.gigantamaxFormId then
      local factor=mon._kascGigantamax67
      if info.gigantamaxFormId~=profile.gigantamaxFormId
          or info.gigantamaxSourceKey~=profile.gigantamaxSourceKey
          or type(factor)~='table' or factor.schema~='kasc.gigantamax-factor/v1'
          or factor.formId~=profile.gigantamaxFormId or factor.sourceKey~=profile.gigantamaxSourceKey
          or factor.baseSpecies~=profile.species then return false,'gigantamax_distribution' end
    end
    if profile.giftCodeOnly == true then
      local receipt = receiptCopy(info.giftCode)
      if not receipt or receipt.profileId ~= profile.id then
        return false, "receipt"
      end
    elseif info.giftCode ~= nil then
      local receipt = receiptCopy(info.giftCode)
      if not receipt or receipt.profileId ~= profile.id then
        return false, "receipt"
      end
    end

    local marker = info.battleCompatibility
    if marker ~= nil then
      if type(marker) ~= "table" or marker.version ~= 1
          or marker.schema ~= BATTLE_COMPAT_SCHEMA
          or marker.owner ~= BATTLE_COMPAT_OWNER
          or marker.profileId ~= profile.id
          or marker.originalSpecies ~= profile.species
          or marker.projection ~= "active-generation" then
        return false, "compatibility_receipt"
      end
    end
    return true, marker and "receipt" or "legacy_distribution", profile
  end

  local function ensureBattleCompatibility(mon)
    local compatible, reason, profile = battleCompatibleGift(mon)
    if not compatible then return false, reason end
    if not mon.eventDistribution.battleCompatibility then
      stampBattleCompatibility(mon, profile)
      return true, "migrated"
    end
    return true, "existing"
  end

  local function migrateBattleCompatibility(game)
    local root = game and game.save
    if type(root) ~= "table" then return 0 end
    local seen, migrated = {}, 0
    local function walk(value)
      if type(value) ~= "table" or seen[value] then return end
      seen[value] = true
      if type(value.species) ~= "nil"
          and type(value.eventDistribution) == "table" then
        local before = value.eventDistribution.battleCompatibility
        local ok = ensureBattleCompatibility(value)
        if ok and before == nil then migrated = migrated + 1 end
      end
      for _, child in pairs(value) do walk(child) end
    end
    walk(root)
    return migrated
  end

  local function storeGift(game, profile, origin, receipt, deliveryOpts)
    local resolved,reason=profileForGame(game,profile)
    if not resolved then return nil,reason or 'profile' end
    profile=resolved
    -- The code UI preflights assets too, but direct archive callers must not
    -- crash or consume a gift when a diagnostic/pending form has no owner.
    if not (game and game.data and game.data.pokemon
        and game.data.pokemon[profile.species]) then return nil,'species_unavailable' end
    local mon = makeGift(game, profile, origin)
    if receipt then
      receipt = receiptCopy(receipt)
      if not receipt then return nil, "receipt" end
      -- Only the public digest receipt is persisted. The entered plaintext is
      -- never attached to a Pokemon, save, archive, log or provenance file.
      mon.eventDistribution.giftCode = receipt
      if type(opts.prepareGiftGender)=='function' then
        local ok,reason=opts.prepareGiftGender(game,mon,receipt)
        if not ok then return nil,reason or 'gift_gender_binding' end
      end
    end
    if profile.deliveryKind == 'egg' then
      -- Gift-only exception: this does not add the species to breeding pools.
      mon.isEgg, mon.eggSpecies, mon.nickname = true, profile.species, 'EGG'
      mon.eggTotalSteps = math.max(1, math.floor(tonumber(profile.eggSteps) or 5120))
      mon.eggStepsRemaining = mon.eggTotalSteps
      mon.eggOrigin = origin or 'KASC NATIONAL GIFT'
      mon.hp, mon.status = 0, nil
      mon.eventDistribution.deliveryKind = 'egg'
      if type(opts.prepareGiftEgg)=='function' then
        local ok, reason = opts.prepareGiftEgg(game,mon,profile,receipt)
        if not ok then return nil, reason or 'egg_binding' end
      end
    end
    local boxOnly = type(deliveryOpts) == "table"
      and deliveryOpts.boxOnly == true
    if not boxOnly then
      local Party = require("src.pokemon.Party")
      if Party.add(game.save.party, mon) then return mon, "party" end
    end
    local box = require("src.pokemon.Boxes").deposit(game.save, mon)
    if box then return mon, "box", box end
    return nil, "full"
  end

  local function nextGiftBox(game)
    if not (game and game.save) then return nil end
    local Boxes = require("src.pokemon.Boxes")
    local boxes = Boxes.ensure(game.save)
    for offset = 0, Boxes.COUNT - 1 do
      local index = ((game.save.currentBox - 1 + offset) % Boxes.COUNT) + 1
      if #boxes[index] < Boxes.CAPACITY then return index end
    end
    return nil
  end

  local function findGiftReceipt(game, digest)
    if type(digest) ~= "string" or not (game and game.save) then return nil end
    for _, mon in ipairs(game.save.party or {}) do
      local info = mon and mon.eventDistribution
      local receipt = info and info.giftCode
      if receipt and receipt.digest == digest then return mon, "party" end
    end
    for boxIndex, box in ipairs(game.save.boxes or {}) do
      for _, mon in ipairs(box) do
        local info = mon and mon.eventDistribution
        local receipt = info and info.giftCode
        if receipt and receipt.digest == digest then
          return mon, "box", boxIndex
        end
      end
    end
  end

  local function markOwned(game, profile)
    if profile.deliveryKind == 'egg' then return end
    if game.save.pokedex then
      game.save.pokedex.seen[profile.species] = true
      game.save.pokedex.owned[profile.species] = true
    end
  end

  local function deliverGift(game, profileId, origin, receipt, deliveryOpts)
    local profile = profiles[profileId]
    if not (game and game.save and profile) then return nil, "profile" end
    local clean = receiptCopy(receipt)
    if not clean or clean.profileId ~= profileId then return nil, "receipt" end
    local existing, destination, box = findGiftReceipt(game, clean.digest)
    if existing then
      ensureBattleCompatibility(existing)
      return existing, destination, box
    end
    local mon
    mon, destination, box = storeGift(game, profile, origin, clean, deliveryOpts)
    if not mon then return nil, destination or "full" end
    markOwned(game, profile)
    return mon, destination, box
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
    if profile.giftCodeOnly == true then return tr("CODE", "CODE") end
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
    if not s.claimed[profile.id] and profileEnabled(profile)
        and unlocked(profile, game) and profile.id ~= "distribution_mew" then
      if eventMode() == "festival" then
        local cup = data.cups[profile.id]
        if cup and cup.map then
          local place = cup.map:gsub("_", " ")
          pages[#pages + 1] = tr(
            "READY means unlocked.\nFind the Cup host in\n" .. place .. ".",
            "BEREIT heißt freigeschaltet.\nFinde den Cup-Gastgeber in\n"
              .. place .. ".")
        end
      elseif eventMode() == "roaming" then
        local habitat = tostring(profile.habitat or "route"):upper()
        pages[#pages + 1] = tr(
          "READY means unlocked.\nSearch suitable " .. habitat
            .. " habitats.\nThe target can move\nbetween maps.",
          "BEREIT heißt freigeschaltet.\nSuche passende " .. habitat
            .. "-Gebiete.\nDas Ziel kann zwischen\nKarten wechseln.")
      end
    end
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
        return (mod.ui.KantoListMenu or mod.ui.ListMenu).new(game, tr("EVENT ARCHIVE", "EVENT-ARCHIV"),
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
    local x, y = placement.findWideRandom(ow, cup.preferred)
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
    if mod.options:get("event_rosette") == false or not love
        or externalHudOwned(battle) then return end
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
    migrateBattleCompatibility(game)
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
    migrateBattleCompatibility(C.game)
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
  C.persist = persist
  C.profile = function(id) return profiles[id] end
  C.profileForGame = profileForGame
  C.registerGiftProfiles = function(rows)
    local added = 0
    for _, profile in ipairs(type(rows) == "table" and rows or {}) do
      assert(type(profile) == "table" and type(profile.id) == "string",
        "invalid additive Gift Code profile")
      assert(profile.giftCodeOnly == true,
        "additive profile must remain outside rotating events")
      assert(profiles[profile.id] == nil,
        "duplicate additive Gift Code profile " .. profile.id)
      profiles[profile.id] = profile
      added = added + 1
    end
    return added
  end
  C.profileEnabled = profileEnabled
  C.unlocked = unlocked
  C.badgeCount = badgeCount
  C.details = details
  C.give = give
  C.claimPending = claimPending
  C.stampProfile = stampProfile
  C.battleCompatibleGift = battleCompatibleGift
  function C.giftEggHatchAllowed(mon)
    local valid, _, profile = battleCompatibleGift(mon)
    return valid == true and profile.deliveryKind == 'egg'
      and mon.isEgg == true and mon.eggSpecies == profile.species
      and mon.species == profile.species
      and mon.eventDistribution.deliveryKind == 'egg'
  end
  C.ensureBattleCompatibility = ensureBattleCompatibility
  C.migrateBattleCompatibility = migrateBattleCompatibility
  C.BATTLE_COMPAT_SCHEMA = BATTLE_COMPAT_SCHEMA
  C.BATTLE_COMPAT_OWNER = BATTLE_COMPAT_OWNER
  C.deliverGift = deliverGift
  C.nextGiftBox = nextGiftBox
  C.findGiftReceipt = findGiftReceipt
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
