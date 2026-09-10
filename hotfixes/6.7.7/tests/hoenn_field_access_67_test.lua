package.path = "./?.lua;./?/init.lua;" .. package.path

local function harness(language)
  local saved = {}
  local optionValues = {
    hoenn_encounters = true,
    hoenn_level_mode = "route",
  }
  local items = {}
  local clocks = { steps = 0, playTime = 0 }
  local progression = { active = false, character = "RED" }
  local scripts = {}
  local events = {}
  local mod = {
    id = "kanto_ascendant",
    exports = {},
    save = {
      get = function(_, key) return saved[key] end,
      set = function(_, key, value) saved[key] = value end,
    },
    options = {
      get = function(_, key) return optionValues[key] end,
    },
    content = {
      items = {
        register = function(_, id, def) items[id] = def end,
      },
      map_scripts = {
        register = function(_, mapId, def)
          scripts[mapId] = scripts[mapId] or {}
          scripts[mapId][#scripts[mapId] + 1] = def
        end,
      },
    },
    events = { on = function(_, name, fn, priority)
      events[name] = events[name] or {}
      events[name][#events[name] + 1] = { fn=fn, priority=priority or 0 }
    end },
  }
  local i18n = {
    text = function(en, de) return language == "de" and de or en end,
  }
  local legacy = {
    durableCatalogHoenn = function(save, species)
      return save and save.legacyHoenn and save.legacyHoenn[species] == true
    end,
  }
  local access = require("hoenn_field_access_67")(mod, {
    i18n = i18n,
    acquisition = require("hoenn_acquisition_67_data"),
    legacyStarters = legacy,
    legacyProgression = {
      isActive = function() return progression.active end,
      activeCharacter = function() return progression.character end,
    },
    stepClock = function() return clocks.steps end,
    playTime = function() return clocks.playTime end,
  })
  return access, saved, optionValues, items, clocks, scripts, mod, progression,
    events
end

local assertions = 0
local function check(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  check(actual == expected, (message or "values differ") .. " (got "
    .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
end

local function game(owned, badges)
  local inventory = {}
  local badgeIds = {
    "BOULDERBADGE", "CASCADEBADGE", "THUNDERBADGE", "RAINBOWBADGE",
    "SOULBADGE", "MARSHBADGE", "VOLCANOBADGE", "EARTHBADGE",
  }
  for index = 1, badges or 0 do inventory[badgeIds[index]] = 1 end
  local dexOwned = {}
  for index = 1, owned or 0 do dexOwned["SPECIES_" .. index] = true end
  return {
    save = {
      inventory = inventory,
      flags = { EVENT_GOT_POKEDEX = true },
      pokedex = { owned = dexOwned, seen = {} },
      party = {}, boxes = {}, pcItems = {},
    },
  }
end

do
  local access, _, _, items, clocks, scripts = harness("en")
  check(items.HOENN_HONEY and items.HOENN_HONEY.keyItem,
    "Hoenn Honey is a registered key item")
  check(items.HOENN_DEX and items.HOENN_DEX.keyItem,
    "Hoenn Dex is a registered key item")
  local visitorScript = scripts.VIRIDIAN_NICKNAME_HOUSE
    and scripts.VIRIDIAN_NICKNAME_HOUSE[1]
  check(visitorScript and visitorScript.talk
      and visitorScript.talk.TEXT_KA_HOENN_VISITOR,
    "the Hoenn visitor owns a separate interaction key")
  check(not visitorScript.talk.TEXT_VIRIDIANNICKNAMEHOUSE_LITTLE_GIRL,
    "the authored Viridian resident and her vanilla dialogue stay untouched")

  local fresh = game(20, 0)
  eq(access.evaluateGirl(fresh).reason, "badge-required",
    "the Hoenn visitor is unavailable before the first badge")
  eq(access.evaluateOak(fresh).reason, "dex-ready",
    "Oak's 20-species milestone is independent of badge count")

  local eligible = game(19, 1)
  check(access.visitorScheduled(eligible),
    "the visitor is home during the opening evening phase")
  clocks.steps = 512
  check(not access.visitorScheduled(eligible),
    "the visitor is away during the later daytime phase")
  clocks.steps = 1024
  check(access.visitorScheduled(eligible),
    "the visitor returns on the next deterministic routine cycle")
  clocks.steps = 0
  clocks.playTime = 600
  check(not access.visitorScheduled(eligible),
    "ten minutes of save-local play time can advance the same routine")
  clocks.playTime = 1200
  check(access.visitorScheduled(eligible),
    "the twenty-minute play-time cycle returns her reliably")
  clocks.playTime = 0
  local offer = access.evaluateGirl(eligible)
  check(offer.offer == true and offer.reason == "offer",
    "one badge reveals the hidden Honey offer")
  local declined = access.claimHoney(eligible, false)
  check(declined.declined == true and not access.hasHoney(eligible),
    "declining does not consume the one-time Honey offer")

  local added = {}
  local received = access.claimHoney(eligible, true, {
    addItem = function(_, id)
      added[#added + 1] = id
      eligible.save.inventory[id] = 1
      return true
    end,
  })
  check(received.awarded == true and added[1] == "HOENN_HONEY",
    "accepting awards exactly one Hoenn Honey")
  check(access.hasHoney(eligible), "Honey ownership is durable")
  eq(access.evaluateGirl(eligible).reason, "owned",
    "the girl changes to a reminder after delivery")

  eq(access.evaluateOak(eligible).reason, "owned-species-required",
    "nineteen owned species cannot unlock the Hoenn Dex")
  check(not access.normalEnabled(eligible),
    "Honey alone never activates the normal Hoenn overlay")
end

do
  local access, saved, _, _, _, _, _, _, events = harness("de")
  local source = game(1, 0)
  source.data = { maps = {}, pokemon = {
    TREECKO = { dex = 252, sourceDex = 252, name = "GECKARBOR" },
    RATTATA = { dex = 19, name = "RATTFRATZ" },
  } }
  source.save.player = { name = "MAARTEN" }
  local shown = {}
  access.install(source, {
    mapScripts = { get = function() return nil end },
    showText = function(_, text)
      shown[#shown + 1] = text
      return true
    end,
  })
  for _, row in ipairs(events["pokemon.caught"] or {}) do
    row.fn({ game=source, species="RATTATA" })
  end
  check(saved.hoenn_field_access_67.firstHoennCaught ~= true,
    "a Kanto catch cannot arm Oak's Hoenn recall")
  for _, row in ipairs(events["pokemon.caught"] or {}) do
    row.fn({ game=source, species="TREECKO" })
  end
  check(saved.hoenn_field_access_67.firstHoennCaught
      and saved.hoenn_field_access_67.oakRecallPending,
    "the first real Hoenn catch durably arms Oak's recall")
  eq(access.evaluateOak(source).reason, "first-hoenn-catch",
    "the first Hoenn catch unlocks Oak's integrated Dex branch")
  for _, row in ipairs(events["battle.ended"] or {}) do
    row.fn({ battle={ game=source } })
  end
  check(#shown == 1 and shown[1]:find("MAARTEN", 1, true)
      and shown[1]:find("LABOR", 1, true),
    "Oak's German recall names the player and points to the Lab")
  check(saved.hoenn_field_access_67.oakRecallShown
      and not saved.hoenn_field_access_67.oakRecallPending,
    "the displayed recall is exact-once and save-stable")
  for _, row in ipairs(events["battle.ended"] or {}) do
    row.fn({ battle={ game=source } })
  end
  eq(#shown, 1, "reload-safe battle closure cannot duplicate Oak's recall")
  local delivered = access.claimDex(source, {
    addItem = function(g, id) g.save.inventory[id] = 1 return true end,
  })
  check(delivered.awarded and access.hasDex(source),
    "Oak delivers the Hoenn Dex after the first Hoenn catch")
end

do
  local access, _, _, _, _, _, _, progression = harness("en")
  local legacy = game(40, 1)
  legacy.save.inventory.HOENN_HONEY = 1
  legacy.save.inventory.HOENN_DEX = 1
  progression.active, progression.character = true, "GREEN"
  check(not access.visitorEligible(legacy)
      and not access.visitorScheduled(legacy),
    "the Hoenn visitor does not exist anywhere in Legacy NG+")
  eq(access.evaluateGirl(legacy).reason, "legacy-hidden",
    "Legacy NG+ cannot claim or interact with the Honey visitor")
  eq(access.claimHoney(legacy, true).reason, "legacy-hidden",
    "Legacy NG+ cannot reacquire Honey through the hidden visitor")
  check(not access.normalEnabled(legacy),
    "Legacy NG+ never reuses standard-game Hoenn habitats")
  check(not access.legendAccess(legacy) and access.questLegendAccess(legacy),
    "only Legacy quests, not Honey roamers, own NG+ legendary access")
  local families = access.characterFamilies(legacy)
  eq(#families, 21, "Green receives exactly Green's fixed ordinary third")
  check(access.ordinaryAllowed(legacy, "ZIGZAGOON")
      and not access.ordinaryAllowed(legacy, "POOCHYENA"),
    "the same character always resolves the same fixed family pack")
  local introductions = access.introductionFamilies(legacy,
    { "POOCHYENA", "ZIGZAGOON", "TAILLOW", "WYNAUT" })
  eq(table.concat(introductions, ","), "ZIGZAGOON,WYNAUT",
    "Wanderers can introduce only the active NG+ character pack")
  progression.active = false
  check(access.visitorEligible(legacy) and access.normalEnabled(legacy),
    "the same save data uses Honey habitats only outside Legacy NG+")
  check(access.legendAccess(legacy) and not access.questLegendAccess(legacy),
    "standard Honey access exposes only the Latios/Latias roamer seam")
end

do
  local access, saved, _, _, clocks = harness("en")
  local oldSave = game(47, 1)
  clocks.steps, clocks.playTime = 9876, 5432
  check(saved.hoenn_field_access_67 == nil,
    "an upgraded old save starts without any 6.7 visitor record")
  check(access.visitorScheduled(oldSave),
    "an old save with the Boulder Badge gets a guaranteed first visit")
  local anchored = assert(saved.hoenn_field_access_67)
  eq(anchored.visitorAnchorSteps, 9876,
    "the retroactive visit anchors to the old save's current step clock")
  eq(anchored.visitorAnchorPlayTime, 5432,
    "the retroactive visit anchors to the old save's current play time")
  clocks.steps = clocks.steps + 512
  check(not access.visitorScheduled(oldSave),
    "the normal routine starts only after the guaranteed retroactive visit")
end

do
  local access = harness("en")
  local fullBag = game(20, 1)
  local waiting = access.claimHoney(fullBag, true, {
    addItem = function() return false end,
  })
  check(waiting.pending == true and not access.hasHoney(fullBag),
    "a full Bag reserves Honey without inventing ownership")
  eq(access.evaluateGirl(fullBag).reason, "pending",
    "the next talk retries a pending Honey delivery")
  local delivered = access.claimHoney(fullBag, true, {
    addItem = function(g, id) g.save.inventory[id] = 1 return true end,
  })
  check(delivered.awarded == true and access.hasHoney(fullBag),
    "pending Honey is delivered once Bag space exists")

  local dexWaiting = access.claimDex(fullBag, {
    addItem = function() return false end,
  })
  check(dexWaiting.pending == true and not access.hasDex(fullBag),
    "a full Bag reserves the Hoenn Dex safely")
  eq(access.evaluateOak(fullBag).reason, "pending",
    "Oak retries the reserved Hoenn Dex")
  local dexDelivered = access.claimDex(fullBag, {
    addItem = function(g, id) g.save.inventory[id] = 1 return true end,
  })
  check(dexDelivered.awarded == true and access.hasDex(fullBag),
    "Oak delivers the reserved Dex exactly once")
  check(access.normalEnabled(fullBag),
    "Honey plus Dex activates normal Hoenn encounters")
  check(access.legendAccess(fullBag),
    "the Hoenn Dex starts the hidden legendary distribution")

  local again = access.claimDex(fullBag, {
    addItem = function() error("must not duplicate") end,
  })
  eq(again.reason, "owned", "Oak cannot duplicate the Hoenn Dex")

  fullBag.save.inventory.HOENN_HONEY = nil
  fullBag.save.pcItems.HOENN_HONEY = 1
  check(access.hasHoney(fullBag),
    "Honey stored in the PC remains durable player property")
  check(not access.honeyCarried(fullBag)
      and not access.normalEnabled(fullBag),
    "PC-stored Honey produces exactly zero Hoenn field encounters")
  fullBag.save.pcItems.HOENN_HONEY = nil
  fullBag.save.inventory.HOENN_HONEY = 1
  check(access.honeyCarried(fullBag) and access.normalEnabled(fullBag),
    "withdrawing Honey immediately restores its field effect")
end

do
  local access, _, options = harness("en")
  local unlocked = game(20, 1)
  unlocked.save.inventory.HOENN_HONEY = 1
  unlocked.save.inventory.HOENN_DEX = 1
  options.hoenn_encounters = false
  check(not access.encountersEnabled(unlocked),
    "the Hoenn Encounter Card master switch is OFF")
  check(not access.normalEnabled(unlocked),
    "the post-Dex encounter toggle genuinely disables the overlay")
  options.hoenn_encounters = true
  check(access.encountersEnabled(unlocked),
    "the Hoenn Encounter Card master switch restores the runtime boundary")
  eq(access.levelMode(unlocked), "route",
    "route levels are the safe default")
  options.hoenn_level_mode = "badges"
  eq(access.levelMode(unlocked), "badges",
    "badge-scaled levels are exposed after the Dex")
  options.hoenn_level_mode = "party"
  eq(access.levelMode(unlocked), "party",
    "party-relative levels are exposed after the Dex")

  check(not access.starterUnlocked(unlocked, "TREECKO"),
    "normal Honey/Dex access never unlocks a Hoenn starter")
  unlocked.save.legacyHoenn = { TREECKO = true }
  check(access.starterUnlocked(unlocked, "TREECKO"),
    "Treecko requires the durable Legacy NG+ catalogue receipt")
  check(not access.starterUnlocked(unlocked, "TORCHIC"),
    "each Hoenn starter family is gated independently")
end

do
  local english = harness("en")
  local german = harness("de")
  local en = english.texts()
  local de = german.texts()
  check(en.honeyOffer:find("HOENN HONEY", 1, true) ~= nil,
    "English girl dialogue names Hoenn Honey")
  check(en.honeyOffer:find("adorable", 1, true) ~= nil,
    "English dialogue preserves the girl's affectionate voice")
  check(de.honeyOffer:find("HOENN-HONIG", 1, true) ~= nil,
    "German girl dialogue names Hoenn-Honig")
  check(de.honeyOffer:find("zauberhaft", 1, true) ~= nil,
    "German dialogue is idiomatic rather than literal")
  check(en.dexAward:find("20", 1, true) ~= nil
      and de.dexAward:find("20", 1, true) ~= nil,
    "Oak explains the exact twenty-species milestone bilingually")

  local helpEn = require("item_help")({ text=function(a) return a end })
  local helpDe = require("item_help")({ text=function(_, b) return b end })
  local helpGame = { save={ inventory={HOENN_HONEY=1}, pcItems={} },
    data={items={HOENN_HONEY={keyItem=true}}} }
  check(helpEn.describe(helpGame, "HOENN_HONEY"):find(
      "find the scent magical", 1, true) ~= nil,
    "carried English Honey help explains the magical scent")
  check(helpDe.describe(helpGame, "HOENN_HONEY"):find(
      "Führe ihn mit Dir", 1, true) ~= nil,
    "carried German Honey help tells the player to keep it with them")
  helpGame.save.inventory.HOENN_HONEY = nil
  helpGame.save.pcItems.HOENN_HONEY = 1
  check(helpEn.describe(helpGame, "HOENN_HONEY"):find(
      "cannot attract", 1, true) ~= nil,
    "stored English Honey help states that the effect is inactive")
  check(helpDe.describe(helpGame, "HOENN_HONEY"):find(
      "Im PC", 1, true) ~= nil,
    "stored German Honey help states that the effect is inactive")
end

do
  local access, _, _, _, _, _, mod = harness("de")
  local originalCalls, claimed, opened, completed = 0, 0, nil, false
  local shown = {}
  local ready = true
  mod.exports.dexProgress = {
    canClaimAscendant = function() return ready end,
    claimAscendant = function() claimed = claimed + 1 return true end,
    openCertificate = function(_, id, done)
      opened = id
      if done then done() end
      return true
    end,
  }
  local oak = { talk = {
    TEXT_OAKSLAB_OAK1 = function(_, _, _, done)
      originalCalls = originalCalls + 1
      if done then done() end
    end,
  } }
  local runtimeScripts = {
    get = function(mapId) return mapId == "OAKS_LAB" and oak or nil end,
  }
  local source = game(20, 1)
  source.save.player = { name = "MAARTEN" }
  source.save.inventory.HOENN_DEX = 1
  access.install(source, {
    mapScripts = runtimeScripts,
    showText = function(_, text, done)
      shown[#shown + 1] = text
      if done then done() end
      return true
    end,
  })
  oak.talk.TEXT_OAKSLAB_OAK1(source, nil, nil,
    function() completed = true end)
  eq(claimed, 1, "Oak claims the final KASC award exactly once")
  eq(opened, "ascendant_complete",
    "Oak opens the distinct KASC completion certificate")
  check(completed and originalCalls == 0,
    "the one-time KASC award completes without leaking vanilla Oak text")
  check(shown[1]:find("MAARTEN", 1, true)
      and shown[1]:find("Ende September", 1, true)
      and shown[1]:find("Anfang Oktober", 1, true),
    "German Oak finale names the player and the announced continuation window")
  ready = false
  oak.talk.TEXT_OAKSLAB_OAK1(source, nil, nil, function() end)
  eq(originalCalls, 1,
    "later Oak talks return to the complete existing dialogue chain")
end

do
  local access, _, _, _, _, _, mod = harness("en")
  local claimed, opened, originalCalls = 0, nil, 0
  mod.exports.shinySystem = {
    canClaimPrisma = function() return true end,
    claimPrisma = function() claimed = claimed + 1 return true end,
  }
  mod.exports.dexProgress = {
    canClaimAscendant = function() return false end,
    openCertificate = function(_, id, done)
      opened = id
      if done then done() end
      return true
    end,
  }
  local oak = { talk = { TEXT_OAKSLAB_OAK1 = function()
    originalCalls = originalCalls + 1
  end } }
  local shown = {}
  local source = game(20, 1)
  source.save.inventory.HOENN_DEX = 1
  access.install(source, {
    mapScripts = { get = function() return oak end },
    showText = function(_, text, done)
      shown[#shown + 1] = text
      if done then done() end
      return true
    end,
  })
  oak.talk.TEXT_OAKSLAB_OAK1(source, nil, nil, function() end)
  eq(claimed, 1, "Oak starts the Prism quest exactly once")
  eq(opened, "shiny_386", "Oak opens the dedicated Shiny certificate")
  check(originalCalls == 0 and shown[1]:find("PRISM OF TWELVE", 1, true),
    "the bilingual Oak seam owns the complete Shiny handoff")
end

-- Exercise the installed map-event seam as well as entitlement helpers.
-- This is a world-API fixture, not a claim of native visual approval.
do
  local access, _, _, _, clocks, _, mod, progression, events = harness("en")
  local source = game(0, 0)
  local resident = { name="VANILLA_RESIDENT", index=1 }
  local map = { id=access.VISITOR_MAP, objects={resident} }
  local ow = { map=map }
  source.data = { maps={[map.id]=map} }
  source.overworld = ow
  local spawned, removed = 0, 0
  mod.world = {
    overworld=function() return ow end,
    spawnNpc=function(_, mapId, def)
      eq(mapId, access.VISITOR_MAP, "visitor spawns in the actual house")
      eq(def.text, access.VISITOR_TEXT, "spawn links the visitor talk handler")
      spawned=spawned+1
      def.runtime, def.owner, def.index = true, mod.id, spawned+1
      map.objects[#map.objects+1]=def
      return mapId.."_obj_"..def.index
    end,
    removeNpc=function(_, id)
      for index=#map.objects,1,-1 do
        local row=map.objects[index]
        if id==map.id.."_obj_"..row.index then
          table.remove(map.objects,index)
          removed=removed+1
        end
      end
    end,
  }
  access.install(source, {
    mapScripts={get=function() return nil end},
    placement={find=function() return 3,4 end},
  })
  eq(spawned, 0, "install before a badge does not spawn the visitor")
  source.save.inventory.BOULDERBADGE=1
  local function enter()
    for _, listener in ipairs(events["map.entered"]) do
      listener.fn({game=source,mapId=map.id})
    end
  end
  enter()
  eq(spawned, 1, "entering after the badge creates the visitor")
  enter()
  eq(spawned, 1, "repeated map events cannot duplicate the visitor")
  clocks.steps=512
  enter()
  eq(removed, 1, "away phase removes only the runtime visitor")
  eq(map.objects[1], resident, "authored resident survives visitor removal")
  clocks.steps=1024
  enter()
  eq(spawned, 2, "the visitor returns in the next cycle")
  progression.active=true
  enter()
  eq(#map.objects, 1, "Legacy removes the ordinary visitor")
  eq(map.objects[1], resident, "Legacy leaves the resident intact")
end

print(("HOENN FIELD ACCESS 6.7 PASS: %d assertions"):format(assertions))
