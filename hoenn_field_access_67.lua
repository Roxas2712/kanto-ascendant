-- Kanto Ascendant 6.7: hidden, current-run Hoenn field access.
--
-- The ordinary path is deliberately quiet: after the first badge, a visiting
-- Hoenn girl sometimes stays in Viridian's Nickname House and may give HOENN
-- HONEY.  She never replaces the authored resident or her vanilla dialogue.
-- Oak awards the separate HOENN DEX after twenty owned species.  Both
-- receipts are required for the normal 1% field overlay.  Legacy NG+ family
-- traces remain a separate durable authority and are never inferred from
-- these two current-run items.

return function(mod, opts)
  opts = opts or {}
  local F = {
    SAVE_KEY = "hoenn_field_access_67",
    STATE_VERSION = 2,
    HONEY = "HOENN_HONEY",
    DEX = "HOENN_DEX",
    VISITOR_MAP = "VIRIDIAN_NICKNAME_HOUSE",
    VISITOR_TEXT = "TEXT_KA_HOENN_VISITOR",
    VISITOR_NAME = "KA_HOENN_VISITOR",
    VISITOR_SPRITE = "SPRITE_LITTLE_GIRL",
    -- Four five-minute / 256-step phases form a twenty-minute / 1024-step
    -- routine.  She is home for the first half and away for the second.  The
    -- later of the two save-local clocks wins, so waiting or exploring can
    -- both advance the routine without consulting the host computer clock.
    VISITOR_PHASE_SECONDS = 300,
    VISITOR_PHASE_STEPS = 256,
    VISITOR_PHASE_COUNT = 4,
    VISITOR_HOME_PHASES = 2,
    OAK_MAP = "OAKS_LAB",
    OAK_TEXT = "TEXT_OAKSLAB_OAK1",
    DEX_MILESTONE = 20,
  }

  local BADGES = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }
  local STARTERS = { TREECKO=true, TORCHIC=true, MUDKIP=true }
  local activeGame, mapScripts, runtimeDeps
  local originals = { oak = nil }
  local handlers = {}
  local legacyStarters = opts.legacyStarters
  local legacyProgression = opts.legacyProgression
  local generationRules = opts.generationRules
  local acquisition = opts.acquisition
  local placement = opts.placement
  local VISITOR_CELLS = {
    { 3, 4 }, { 2, 4 }, { 3, 5 }, { 2, 5 },
  }

  local function tr(en, de)
    return opts.i18n and opts.i18n.text and opts.i18n.text(en, de) or en
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do
      out[copy(key, seen)] = copy(child, seen)
    end
    return out
  end

  local function normalize(raw)
    local out = type(raw) == "table" and copy(raw) or {}
    out.version = F.STATE_VERSION
    for _, key in ipairs({
      "honeyEntitled", "honeyPending", "honeyOwned",
      "dexEntitled", "dexPending", "dexOwned",
      "firstHoennCaught", "oakRecallPending", "oakRecallShown",
    }) do
      out[key] = out[key] == true
    end
    for _, key in ipairs({ "visitorAnchorSteps", "visitorAnchorPlayTime" }) do
      local value = tonumber(out[key])
      out[key] = value and math.max(0, math.floor(value)) or nil
    end
    local character = type(out.characterPack) == "string"
      and out.characterPack:upper() or nil
    out.characterPack = ({ RED=true, GREEN=true, BLUE=true })[character]
      and character or nil
    if out.honeyOwned then
      out.honeyEntitled, out.honeyPending = true, false
    end
    if out.dexOwned then out.dexEntitled, out.dexPending = true, false end
    return out
  end

  local function state(create)
    local raw = mod.save:get(F.SAVE_KEY)
    if type(raw) ~= "table" and create == false then return nil end
    local out = normalize(raw)
    mod.save:set(F.SAVE_KEY, out)
    return out
  end

  local function persist(value)
    local out = normalize(value)
    mod.save:set(F.SAVE_KEY, out)
    return out
  end

  local function activeSave(source)
    return source and source.save or source or {}
  end

  function F.isLegacy(game)
    if type(legacyProgression) ~= "table"
        or type(legacyProgression.isActive) ~= "function" then return false end
    local ok, active = pcall(legacyProgression.isActive, activeSave(game))
    return ok and active == true
  end

  function F.currentCharacter(game)
    if type(legacyProgression) == "table"
        and type(legacyProgression.activeCharacter) == "function" then
      local ok, character = pcall(legacyProgression.activeCharacter,
        activeSave(game))
      character = ok and type(character) == "string"
        and character:upper() or nil
      if ({ RED=true, GREEN=true, BLUE=true })[character] then return character end
    end
    local save = activeSave(game)
    local bucket = type(save.modData) == "table" and save.modData[mod.id]
    local characters = type(bucket) == "table"
      and bucket.extended_characters
    local character = type(characters) == "table"
      and type(characters.player_character) == "string"
      and characters.player_character:upper() or nil
    return ({ RED=true, GREEN=true, BLUE=true })[character]
      and character or "RED"
  end

  function F.characterFamilies(game)
    local packs = type(acquisition) == "table" and acquisition.characterPacks
    local rows = type(packs) == "table" and packs[F.currentCharacter(game)]
    return copy(type(rows) == "table" and rows or {})
  end

  local function generationAvailable(game)
    return type(generationRules) ~= "table"
      or type(generationRules.shouldUseEpoch) ~= "function"
      or generationRules.shouldUseEpoch(game, 3, true) == true
  end

  function F.ordinaryAllowed(game, family)
    if not generationAvailable(game) then return false end
    family = type(family) == "string" and family:upper() or nil
    for _, id in ipairs(F.characterFamilies(game)) do
      if id == family then return true end
    end
    return false
  end

  function F.introductionFamilies(game, registered)
    if not F.isLegacy(game) or not generationAvailable(game) then return {} end
    local enabled, out = {}, {}
    for _, family in ipairs(F.characterFamilies(game)) do enabled[family] = true end
    for _, family in ipairs(type(registered) == "table" and registered or {}) do
      if enabled[family] then out[#out + 1] = family end
    end
    return out
  end

  local function inventoryCarries(game, id)
    local save = activeSave(game)
    return (tonumber((save.inventory or {})[id]) or 0) > 0
  end

  local function inventoryOwns(game, id)
    local save = activeSave(game)
    return inventoryCarries(game, id)
      or (tonumber((save.pcItems or {})[id]) or 0) > 0
  end

  local function adopt(game)
    local out = state(true)
    local changed = false
    if inventoryOwns(game, F.HONEY) and not out.honeyOwned then
      out.honeyEntitled, out.honeyPending, out.honeyOwned = true, false, true
      changed = true
    end
    if out.honeyOwned and not F.isLegacy(game) and not out.characterPack then
      out.characterPack = F.currentCharacter(game)
      changed = true
    end
    if inventoryOwns(game, F.DEX) and not out.dexOwned then
      out.dexEntitled, out.dexPending, out.dexOwned = true, false, true
      changed = true
    end
    if changed then out = persist(out) end
    return out
  end

  function F.badgeCount(game)
    local inventory = activeSave(game).inventory or {}
    local count = 0
    for _, id in ipairs(BADGES) do
      if (tonumber(inventory[id]) or 0) > 0 then count = count + 1 end
    end
    return count
  end

  local function clockValue(provider, game, fallback)
    if type(provider) == "function" then
      local ok, value = pcall(provider, game)
      if ok and tonumber(value) then
        return math.max(0, math.floor(tonumber(value)))
      end
    end
    return math.max(0, math.floor(tonumber(fallback) or 0))
  end

  function F.visitorPhase(game)
    game = game or activeGame
    local steps = clockValue(opts.stepClock, game,
      mod.save:get("step_clock"))
    local playTime = clockValue(opts.playTime, game,
      activeSave(game).playTime)
    local anchorSteps, anchorPlayTime = 0, 0
    if F.visitorEligible(game) then
      local out = state(true)
      local changed = false
      if out.visitorAnchorSteps == nil then
        out.visitorAnchorSteps, changed = steps, true
      end
      if out.visitorAnchorPlayTime == nil then
        out.visitorAnchorPlayTime, changed = playTime, true
      end
      if changed then out = persist(out) end
      anchorSteps = out.visitorAnchorSteps or steps
      anchorPlayTime = out.visitorAnchorPlayTime or playTime
    end
    local relativeSteps = math.max(0, steps - anchorSteps)
    local relativePlayTime = math.max(0, playTime - anchorPlayTime)
    local stepPhase = math.floor(relativeSteps / F.VISITOR_PHASE_STEPS)
    local timePhase = math.floor(relativePlayTime / F.VISITOR_PHASE_SECONDS)
    local slot = math.max(stepPhase, timePhase)
    local index = slot % F.VISITOR_PHASE_COUNT
    local names = { "evening", "night", "morning", "day" }
    return {
      index = index,
      name = names[index + 1],
      present = index < F.VISITOR_HOME_PHASES,
      slot = slot,
      steps = steps,
      playTime = playTime,
      relativeSteps = relativeSteps,
      relativePlayTime = relativePlayTime,
    }
  end

  function F.visitorEligible(game)
    game = game or activeGame
    return not F.isLegacy(game) and F.badgeCount(game) >= 1
  end

  function F.visitorScheduled(game)
    return F.visitorEligible(game) and F.visitorPhase(game).present
  end

  function F.ownedCount(game)
    local save = activeSave(game)
    local owned = save.pokedex and save.pokedex.owned or {}
    local count = 0
    for _, value in pairs(owned) do if value then count = count + 1 end end
    return count
  end

  local function coreDexReady(game)
    local save = activeSave(game)
    local flags = save.flags or {}
    return flags.EVENT_GOT_POKEDEX == true or inventoryOwns(game, "POKEDEX")
  end

  function F.hasHoney(game)
    local out = adopt(game)
    return out.honeyOwned == true and inventoryOwns(game, F.HONEY)
  end

  function F.honeyCarried(game)
    local out = adopt(game)
    return out.honeyOwned == true and inventoryCarries(game, F.HONEY)
  end

  function F.hasDex(game)
    local out = adopt(game)
    return out.dexOwned == true and inventoryOwns(game, F.DEX)
  end

  function F.evaluateGirl(game)
    if F.isLegacy(game) then return { reason="legacy-hidden", hidden=true } end
    local out = adopt(game)
    if F.hasHoney(game) then return { reason="owned", owned=true } end
    if out.honeyPending or out.honeyEntitled then
      return { reason="pending", pending=true }
    end
    if F.badgeCount(game) < 1 then return { reason="badge-required" } end
    return { reason="offer", offer=true }
  end

  function F.evaluateOak(game)
    local out = adopt(game)
    if F.hasDex(game) then return { reason="owned", owned=true } end
    if out.dexPending or out.dexEntitled then
      return { reason="pending", pending=true }
    end
    if not coreDexReady(game) then return { reason="pokedex-required" } end
    local owned = F.ownedCount(game)
    if not out.firstHoennCaught and owned < F.DEX_MILESTONE then
      return { reason="owned-species-required", ownedSpecies=owned,
        required=F.DEX_MILESTONE }
    end
    return { reason=out.firstHoennCaught and "first-hoenn-catch" or "dex-ready",
      ready=true, firstHoennCatch=out.firstHoennCaught == true, ownedSpecies=owned,
      required=F.DEX_MILESTONE }
  end

  local function hoennSpecies(game, species)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[species]
    local dex = type(def) == "table"
      and tonumber(def.sourceDex or def.dex) or nil
    return dex ~= nil and dex >= 252 and dex <= 386
  end

  function F.recordHoennCatch(game, species)
    if not hoennSpecies(game, species) then return false, "not-hoenn" end
    local out = state(true)
    if out.firstHoennCaught then return false, "already-recorded" end
    out.firstHoennCaught = true
    if not out.dexOwned then out.oakRecallPending = true end
    persist(out)
    return true, "recorded"
  end

  local function defaultAddItem(game, id)
    game.save.inventory = game.save.inventory or {}
    return require("src.inventory.Bag").add(game.save, id, 1, game.data)
  end

  local function deliver(game, kind, id, deps)
    local out = adopt(game)
    local ownedKey, entitledKey, pendingKey = kind .. "Owned",
      kind .. "Entitled", kind .. "Pending"
    if out[ownedKey] and inventoryOwns(game, id) then
      return { reason="owned", owned=true, awarded=false }
    end
    out[entitledKey] = true
    local addItem = deps and deps.addItem or opts.addItem or defaultAddItem
    if inventoryOwns(game, id) or addItem(game, id) then
      out[ownedKey], out[pendingKey] = true, false
      persist(out)
      return { reason="awarded", awarded=true, pending=false }
    end
    out[ownedKey], out[pendingKey] = false, true
    persist(out)
    return { reason="bag-full", awarded=false, pending=true }
  end

  function F.claimHoney(game, accepted, deps)
    local evaluation = F.evaluateGirl(game)
    if evaluation.owned then return evaluation end
    if evaluation.reason == "badge-required"
        or evaluation.reason == "legacy-hidden" then return evaluation end
    if not evaluation.pending and accepted ~= true then
      return { reason="declined", declined=true }
    end
    local result = deliver(game, "honey", F.HONEY, deps)
    if result.awarded or result.owned then
      local out = state(true)
      if not out.characterPack then
        out.characterPack = F.currentCharacter(game)
        persist(out)
      end
    end
    return result
  end

  function F.claimDex(game, deps)
    local evaluation = F.evaluateOak(game)
    if evaluation.owned then return evaluation end
    if not evaluation.ready and not evaluation.pending then return evaluation end
    return deliver(game, "dex", F.DEX, deps)
  end

  local function option(game, key, fallback)
    local bucket = game and game.mods and game.mods.modOptions
      and game.mods.modOptions[mod.id]
    if bucket and bucket[key] ~= nil then return bucket[key] end
    local value = mod.options and mod.options.get and mod.options:get(key)
    return value == nil and fallback or value
  end

  -- Master boundary for the complete Hoenn field Card. This is deliberately
  -- independent from Honey/Dex and Legacy state: OFF must stop both the
  -- ordinary overlay and new Wanderer trace introductions without deleting
  -- any durable discovery or catch receipt.
  function F.encountersEnabled(game)
    return generationAvailable(game)
      and option(game, "hoenn_encounters", true) ~= false
  end

  function F.normalEnabled(game)
    return F.encountersEnabled(game) and not F.isLegacy(game)
      and F.honeyCarried(game) and F.hasDex(game)
  end

  -- Latios and Latias are the only legendary-class Honey visitors in a
  -- standard campaign. Every authored legendary/mythical quest stays behind
  -- the Legacy boundary.
  function F.legendAccess(game)
    return generationAvailable(game) and not F.isLegacy(game)
      and F.honeyCarried(game) and F.hasDex(game)
  end

  -- Pure counterpart for observation consumers. Inventory adoption changes
  -- bookkeeping only; item possession already entails both ownership flags.
  function F.peekLegendAccess(game)
    local generation=not generationRules or generationRules.peekShouldUseEpoch
      and generationRules.peekShouldUseEpoch(game,3,true)==true
    return generation and not F.isLegacy(game)
      and inventoryCarries(game,F.HONEY) and inventoryOwns(game,F.DEX) or false
  end

  function F.questLegendAccess(game)
    return generationAvailable(game) and F.isLegacy(game) and F.hasDex(game)
  end

  function F.levelMode(game)
    local value = option(game, "hoenn_level_mode", "route")
    return ({ route=true, badges=true, party=true })[value]
      and value or "route"
  end

  function F.setLegacyStarters(provider)
    legacyStarters = provider
    return type(provider) == "table"
      and type(provider.durableCatalogHoenn) == "function"
  end

  function F.setLegacyProgression(provider)
    legacyProgression = provider
    return type(provider) == "table"
      and type(provider.isActive) == "function"
      and type(provider.activeCharacter) == "function"
  end

  function F.setGenerationRules(provider)
    generationRules = provider
    return type(provider) == "table"
      and type(provider.shouldUseEpoch) == "function"
  end

  function F.starterUnlocked(game, species)
    species = type(species) == "string" and species:upper() or nil
    if not STARTERS[species] or type(legacyStarters) ~= "table"
        or type(legacyStarters.durableCatalogHoenn) ~= "function" then
      return false
    end
    local ok, unlocked = pcall(legacyStarters.durableCatalogHoenn,
      activeSave(game), species)
    return ok and unlocked == true
  end

  function F.texts()
    return {
      honeyOffer = tr(
        "I came here from\nHOENN. The POKéMON\nthere are adorable!\fI brought a little\nHOENN HONEY.\nWould you like some?\fWhenever I carried\nit, those sweet\nPOKéMON found me\neverywhere.",
        "Ich komme aus\nHOENN. Die POKéMON\ndort sind zauberhaft!\fIch habe etwas\nHOENN-HONIG dabei.\nMöchtest Du welchen?\fWenn ich ihn bei mir\ntrug, konnte ich mich\nvor den süßen POKéMON\nkaum retten."),
      honeyAward = tr(
        "You received\nHOENN HONEY!\fA warm, sweet scent\nclings to the jar.",
        "Du erhältst\nHOENN-HONIG!\fEin warmer, süßer\nDuft liegt im Glas."),
      honeyPending = tr(
        "I will keep the\nHOENN HONEY safe.\fMake room in your BAG\nand talk to me again.",
        "Ich bewahre den\nHOENN-HONIG auf.\fSchaffe Platz im\nBEUTEL und komm wieder."),
      honeyDecline = tr(
        "All right! If you\nchange your mind,\ncome back any time.",
        "In Ordnung! Wenn\nDu es Dir anders\nüberlegst, komm wieder."),
      honeyReminder = tr(
        "That HOENN HONEY\nhas a gentle scent.\fPerhaps very rare\nPOKéMON will notice it.",
        "Der HOENN-HONIG\nduftet ganz sanft.\fVielleicht bemerken ihn\nsehr seltene POKéMON."),
      dexAward = tr(
        "OAK: You have caught\n20 different species!\fYour field work is\nready to grow.\fTake this HOENN DEX.\nIt can record the rare\nvisitors now stirring\nin Kanto.",
        "EICH: Du hast 20\nverschiedene Arten\ngefangen!\fDeine Feldforschung\nkann nun wachsen.\fNimm diesen HOENN-DEX.\nEr erfasst die seltenen\nGäste, die sich nun\nin Kanto regen."),
      dexAwardFirst = tr(
        "OAK: So the strange\nvisitor was real!\fIts data does not fit\nthe Kanto index.\fTake this HOENN DEX.\nIt will record every\nnew trace you find.",
        "EICH: Der fremde\nBesucher war also echt!\fSeine Daten passen nicht\nin den Kanto-Dex.\fNimm diesen HOENN-DEX.\nEr erfasst jede neue\nSpur, die Du findest."),
      oakRecall = tr(
        "OAK: {PLAYER}, that\nPokémon is not from\nKanto or Johto.\fCome to my LAB.\nI have an extension\nfor your POKéDEX.",
        "EICH: {PLAYER}, dieses\nPokémon stammt weder aus\nKanto noch aus Johto.\fKomm in mein LABOR.\nIch habe eine Erweiterung\nfür Deinen POKéDEX."),
      dexPending = tr(
        "OAK: I will hold the\nHOENN DEX for you.\fMake room in your BAG\nand speak to me again.",
        "EICH: Ich bewahre den\nHOENN-DEX für Dich auf.\fSchaffe Platz im BEUTEL\nund sprich mich erneut an."),
      prismaComplete = tr(
        "OAK: Extraordinary!\fYou have raised every\nshiny species from\nKanto, Johto and Hoenn.\fThis SHINY CERTIFICATE\nis yours.\fThe PRISM OF TWELVE\nnow shines in the twelve\nhidden starter habitats.\fEach habitat holds one\nfinal shiny trial.",
        "EICH: Außergewöhnlich!\fDu besitzt jede\nShiny-Art aus Kanto,\nJohto und Hoenn.\fDieses SHINY-ZERTIFIKAT\ngehört Dir.\fDAS PRISMA DER ZWÖLF\nleuchtet nun in den zwölf\nverborgenen Starter-Habitaten.\fIn jedem wartet eine\nletzte Shiny-Prüfung."),
      ascendantComplete = tr(
        "OAK: Congratulations,\n{PLAYER}!\fYou have completed\neverything KANTO\nASCENDANT holds--\nfor now.\fOur next chapter begins\nat the end of September\nor start of October.\fI look forward to\nyour return.",
        "EICH: Herzlichen\nGlückwunsch, {PLAYER}!\fDu hast KANTO\nASCENDANT vollständig\ngemeistert--\nfürs Erste.\fEnde September oder\nAnfang Oktober geht\nDeine Reise weiter.\fIch freue mich auf\nDeine Rückkehr."),
    }
  end

  local function show(game, text, done, choice)
    local deps = runtimeDeps or {}
    if type(deps.showText) == "function" then
      return deps.showText(game, text, done, choice)
    end
    local TextBox = deps.textBox or require("src.render.TextBox")
    game.stack:push(TextBox.new(game, text, done, choice and {
      defaultNo = true,
      choice = choice,
    } or nil))
    return true
  end

  local function playerName(game)
    return game and game.save and game.save.player
      and game.save.player.name or "PLAYER"
  end

  function F.showOakRecall(game)
    local out = state(false)
    if not (out and out.oakRecallPending and not out.dexOwned) then
      return false, "none"
    end
    local text = F.texts().oakRecall:gsub("{PLAYER}", playerName(game))
    local shown = show(game, text)
    if shown == false then return false, "presentation-unavailable" end
    out.oakRecallPending, out.oakRecallShown = false, true
    persist(out)
    return true, "shown"
  end

  local function runOriginalOak(game, ow, npc, done)
    local original = originals.oak
    if type(original) == "function" then
      return original(game, ow, npc, done)
    end
    if type(original) == "table" and ow and ow.runner then
      return ow.runner:run(original, { npc=npc, onDone=done })
    end
    local text = game and game.data and game.data.resolveText
      and select(1, game.data:resolveText(F.OAK_MAP, F.OAK_TEXT))
    if text then return show(game, text, done) end
    if done then done() end
    return false
  end

  local function faceAndFinish(ow, npc, done)
    if npc then
      npc.frozen = true
      if type(npc.facePlayer) == "function" and ow and ow.player then
        pcall(npc.facePlayer, npc, ow.player)
      end
    end
    return function()
      if npc then npc.frozen = false end
      if done then done() end
    end
  end

  handlers.visitor = function(game, ow, npc, done)
    local finish = faceAndFinish(ow, npc, done)
    local evaluation = F.evaluateGirl(game)
    local text = F.texts()
    if evaluation.reason == "badge-required" then return finish() end
    if evaluation.owned then return show(game, text.honeyReminder, finish) end
    if evaluation.pending then
      local result = F.claimHoney(game, true, runtimeDeps)
      return show(game, result.awarded and text.honeyAward
        or text.honeyPending, finish)
    end
    return show(game, text.honeyOffer, nil, function(yes)
      local result = F.claimHoney(game, yes, runtimeDeps)
      return show(game, result.awarded and text.honeyAward
        or result.pending and text.honeyPending or text.honeyDecline, finish)
    end)
  end

  handlers.oak = function(game, ow, npc, done)
    local evaluation = F.evaluateOak(game)
    if evaluation.ready or evaluation.pending then
      local result = F.claimDex(game, runtimeDeps)
      local text = F.texts()
      return show(game, result.awarded
          and (evaluation.firstHoennCatch and text.dexAwardFirst or text.dexAward)
        or text.dexPending, done)
    end
    local progress = mod.exports and mod.exports.dexProgress
    local shiny = mod.exports and mod.exports.shinySystem
    if shiny and type(shiny.canClaimPrisma) == "function"
        and type(shiny.claimPrisma) == "function" then
      local ready = shiny.canClaimPrisma(game)
      if ready then
        local claimed = shiny.claimPrisma(game)
        if claimed then
          return show(game, F.texts().prismaComplete, function()
            if progress and type(progress.openCertificate) == "function" then
              local opened = progress.openCertificate(
                game, "shiny_386", done)
              if opened then return end
            end
            if done then done() end
          end)
        end
      end
    end
    if progress and type(progress.canClaimAscendant) == "function"
        and type(progress.claimAscendant) == "function" then
      local ready = progress.canClaimAscendant(game)
      if ready then
        local claimed = progress.claimAscendant(game)
        if claimed then
          local player = game and game.save and game.save.player
            and game.save.player.name or "TRAINER"
          local message = F.texts().ascendantComplete:gsub("{PLAYER}", player)
          return show(game, message, function()
            if type(progress.openCertificate) == "function" then
              local opened = progress.openCertificate(game,
                "ascendant_complete", done)
              if opened then return end
            end
            if done then done() end
          end)
        end
      end
    end
    return runOriginalOak(game, ow, npc, done)
  end

  if mod.content and mod.content.map_scripts
      and type(mod.content.map_scripts.register) == "function" then
    mod.content.map_scripts:register(F.VISITOR_MAP, {
      priority = 2460,
      talk = { [F.VISITOR_TEXT] = handlers.visitor },
    })
  end

  local function runtimeObjectIds(game)
    local out = {}
    local map = game and game.data and game.data.maps
      and game.data.maps[F.VISITOR_MAP]
    for _, object in ipairs(map and map.objects or {}) do
      if object.runtime and object.owner == mod.id
          and object.name == F.VISITOR_NAME then
        out[#out + 1] = F.VISITOR_MAP .. "_obj_"
          .. tostring(object.index)
      end
    end
    return out
  end

  local function removeVisitor(game)
    if not (mod.world and type(mod.world.removeNpc) == "function") then
      return false
    end
    local removed = false
    for _, id in ipairs(runtimeObjectIds(game)) do
      pcall(mod.world.removeNpc, mod.world, id)
      removed = true
    end
    return removed
  end

  local function currentMapId(game)
    local ow = mod.world and type(mod.world.overworld) == "function"
      and mod.world:overworld()
    return ow and ow.map and ow.map.id
      or game and game.overworld and game.overworld.map
        and game.overworld.map.id or nil
  end

  function F.refreshVisitor(game, mapId)
    game = game or activeGame
    if not game then return false, "no-game" end
    mapId = mapId or currentMapId(game)
    local should = mapId == F.VISITOR_MAP and F.visitorScheduled(game)
    if not should then
      removeVisitor(game)
      return false, mapId == F.VISITOR_MAP and "away" or "other-map"
    end
    local ids = runtimeObjectIds(game)
    if #ids > 0 then return true, "present" end
    if not (mod.world and type(mod.world.overworld) == "function"
        and type(mod.world.spawnNpc) == "function") then
      return false, "no-world-api"
    end
    local ow = mod.world:overworld()
    if not (ow and ow.map and ow.map.id == F.VISITOR_MAP) then
      return false, "map-not-live"
    end
    local locator = runtimeDeps and runtimeDeps.placement or placement
    if not (locator and type(locator.find) == "function") then
      return false, "no-placement"
    end
    local x, y = locator.find(ow, VISITOR_CELLS)
    if x == nil or y == nil then return false, "no-safe-cell" end
    local ok, id = pcall(mod.world.spawnNpc, mod.world, F.VISITOR_MAP, {
      name = F.VISITOR_NAME,
      sprite = F.VISITOR_SPRITE,
      movement = "STAY",
      range = "DOWN",
      text = F.VISITOR_TEXT,
      x = x,
      y = y,
    })
    return ok and id ~= nil, ok and id ~= nil and "spawned" or "spawn-failed"
  end

  function F.refresh(game)
    activeGame = game or activeGame
    if not (activeGame and mapScripts and type(mapScripts.get) == "function") then
      return false
    end
    local oak = mapScripts.get(F.OAK_MAP)
    if oak and type(oak.talk) == "table" then
      local current = oak.talk[F.OAK_TEXT]
      if current ~= handlers.oak and originals.oak == nil then
        originals.oak = current
      end
      oak.talk[F.OAK_TEXT] = handlers.oak
    end
    return oak ~= nil
  end

  function F.install(game, deps)
    activeGame = game or activeGame
    runtimeDeps = deps or runtimeDeps or {}
    mapScripts = runtimeDeps.mapScripts or mapScripts
      or require("data.scripts.init")
    placement = runtimeDeps.placement or placement
    adopt(activeGame)
    local installed, why = F.refresh(activeGame)
    F.refreshVisitor(activeGame)
    -- A hidden visitor is a valid installed state (most notably every NG+
    -- run). `refresh` reports whether it replaced Oak's handler, not whether
    -- this controller itself installed successfully.
    return true, installed and "active" or why or "visitor-hidden"
  end

  function F.status(game) return copy(adopt(game or activeGame)) end

  if mod.events and type(mod.events.on) == "function" then
    for _, event in ipairs({ "save.loaded", "save.created", "game.ready" }) do
      mod.events:on(event, function(ev)
        local game = ev and ev.game or activeGame
        if game then
          adopt(game)
          if mapScripts then F.refresh(game) end
          F.refreshVisitor(game)
        end
      end, 4100)
    end
    for _, event in ipairs({ "map.entered", "map.reloaded" }) do
      mod.events:on(event, function(ev)
        local game = ev and ev.game or activeGame
        local mapId = ev and (ev.mapId or ev.map and ev.map.id)
        if game then F.refreshVisitor(game, mapId) end
      end, 4100)
    end
    mod.events:on("pokemon.caught", function(ev)
      local game = ev and (ev.game or ev.battle and ev.battle.game)
        or activeGame
      local species = ev and (ev.species or ev.mon and ev.mon.species)
      if game and species then F.recordHoennCatch(game, species) end
    end, 3900)
    mod.events:on("battle.ended", function(ev)
      local game = ev and ev.battle and ev.battle.game or activeGame
      if game then F.showOakRecall(game) end
    end, 3900)
  end

  mod.content.items:register(F.HONEY, {
    id=F.HONEY, name=tr("HOENN HONEY", "HOENN-HONIG"),
    price=0, keyItem=true, tossable=false, needsTarget=false,
    lootExcluded=true, progressionItem=true,
  })
  mod.content.items:register(F.DEX, {
    id=F.DEX, name=tr("HOENN DEX", "HOENN-DEX"),
    price=0, keyItem=true, tossable=false, needsTarget=false,
    lootExcluded=true, progressionItem=true,
  })

  F.badges = copy(BADGES)
  F.visitorCells = copy(VISITOR_CELLS)
  F.runtimeObjectIds = runtimeObjectIds
  return F
end
