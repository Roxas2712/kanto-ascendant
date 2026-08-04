-- Yellow's one true partner, carried safely across its optional evolution.
--
-- Fresh saves stamp the exact Pikachu created by Oak's lab gift. Upgraded
-- saves adopt a unique self-owned Pikachu/Raichu/Gorochu automatically and ask once
-- when several candidates make the old data ambiguous. The marker lives on
-- the Pokémon table, so boxing, trading within the save and Evolution.apply
-- preserve the identity without relying on species or party position.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local spriteAssets = opts.spriteAssets
  local shinySystem = opts.shinySystem
  local gorochu = opts.gorochu
  local Y = { game = nil }

  local ITEM = "ASCENDANT_THUNDERHEART"
  local STATE_KEY = "yellow_partner"
  local MARKER = "_ascendantYellowPartner"
  local AWAKENING_MARKER = "_ascendantThunderheartAwakened"
  local REQUIRED_STEPS = 251
  local REQUIRED_WINS = 3
  local SURGE = "VERMILIONGYM_LT_SURGE"

  local runtime = {
    gameVersion = opts.gameVersion,
    baseFollowerImage = nil,
    baseFollowerFrames = nil,
    baseFollowerWalker = nil,
    baseFollowerTrueColor = nil,
    portraitImages = {},
  }
  local pendingEvolutionHP = setmetatable({}, { __mode = "k" })

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function isEvolvedPartnerSpecies(species)
    return species == "RAICHU" or species == "GOROCHU"
  end

  local function isYellow()
    local gv = runtime.gameVersion
    if not gv then
      local ok
      ok, gv = pcall(require, "src.core.GameVersion")
      if not ok then return false end
    end
    return gv and type(gv.isYellow) == "function" and gv.isYellow() == true
  end

  local function state(create)
    local s = mod.save:get(STATE_KEY)
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 2,
        initialized = false,
        offered = false,
        accepted = false,
        declined = false,
        legacy = false,
        steps = 0,
        wins = 0,
        heartGiven = false,
      }
      mod.save:set(STATE_KEY, s)
    end
    if type(s) == "table" then
      s.version = 2
      s.initialized = s.initialized == true
      s.offered = s.offered == true
      s.accepted = s.accepted == true
      s.declined = s.declined == true
      s.legacy = s.legacy == true
      s.steps = math.max(0, math.floor(tonumber(s.steps) or 0))
      s.wins = math.max(0, math.floor(tonumber(s.wins) or 0))
      s.heartGiven = s.heartGiven == true
      if s.choice ~= "stay" and s.choice ~= "evolved" then
        s.choice = nil
      end
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

  local function markedPartner(save)
    local found
    eachPokemon(save, function(mon)
      if type(mon) == "table" and mon[MARKER] == true then
        found = mon
        return false
      end
    end)
    return found
  end

  local function selfOwned(save, mon)
    local player = save and save.player or {}
    return type(mon) == "table"
      and mon.ot == player.name and mon.otId == player.id
  end

  local function candidates(save)
    local out = {}
    eachPokemon(save, function(mon, where, index, boxIndex)
      if type(mon) == "table" and not mon.isEgg
          and (mon.species == "PIKACHU"
            or isEvolvedPartnerSpecies(mon.species))
          and selfOwned(save, mon) then
        out[#out + 1] = {
          mon = mon, where = where, index = index, box = boxIndex,
        }
      end
    end)
    return out
  end

  local function stamp(mon)
    if type(mon) ~= "table" then return false end
    mon[MARKER] = true
    return true
  end

  local function isAwakenedPartner(mon)
    return type(mon) == "table"
      and mon[MARKER] == true
      and mon[AWAKENING_MARKER] == true
      and mon.species == "PIKACHU"
  end

  -- Released engines before the per-Pokémon stats hook do not forward `mon`
  -- to Stats.calc. Keep a mod-owned compatibility index by the concrete DV
  -- and stat-exp tables instead: every recalculation of an existing Pokémon
  -- passes those identity-bearing tables, even on the frozen engine API.
  --
  -- The wrapper is process-global because Stats is a shared engine module,
  -- but its resolver is replaced on a mod reload and remains inert unless
  -- the current Yellow save owns the exact marked, awakened Pikachu. On a
  -- newer engine we still pass `mon` to the original calculator; substituting
  -- Raichu before its hook runs is idempotent, so the Gen-I formula executes
  -- once and the boost can never stack.
  local STATS_COMPAT_KEY = "__kantoAscendantYellowPartnerStatsCompat"
  local statsCompat

  local function installStatsCompatibility()
    local Stats = require("src.pokemon.Stats")
    local compat = rawget(Stats, STATS_COMPAT_KEY)
    if type(compat) ~= "table" or type(compat.originalCalc) ~= "function" then
      compat = {
        originalCalc = Stats.calc,
        byDvs = setmetatable({}, { __mode = "kv" }),
        byStatExp = setmetatable({}, { __mode = "kv" }),
      }
      compat.wrapper = function(speciesDef, level, dvs, statExp, mon)
        local concrete = type(mon) == "table" and mon
          or compat.byDvs[dvs] or compat.byStatExp[statExp]
        local resolved = speciesDef
        if type(compat.resolve) == "function" then
          local candidate = compat.resolve(speciesDef, concrete)
          if type(candidate) == "table"
              and type(candidate.baseStats) == "table" then
            resolved = candidate
          end
        end
        return compat.originalCalc(
          resolved, level, dvs, statExp, mon)
      end
      rawset(Stats, STATS_COMPAT_KEY, compat)
      Stats.calc = compat.wrapper
    end
    if type(Stats.ensure) == "function"
        and type(compat.originalEnsure) ~= "function" then
      compat.originalEnsure = Stats.ensure
      compat.ensureWrapper = function(speciesDef, mon)
        if type(mon) == "table" then
          if type(mon.dvs) == "table" then compat.byDvs[mon.dvs] = mon end
          if type(mon.statExp) == "table" then
            compat.byStatExp[mon.statExp] = mon
          end
        end
        return compat.originalEnsure(speciesDef, mon)
      end
      Stats.ensure = compat.ensureWrapper
    end

    compat.resolve = function(speciesDef, mon)
      if not (isYellow() and isAwakenedPartner(mon)) then return nil end
      local pokemon = Y.game and Y.game.data and Y.game.data.pokemon
      if not (pokemon and speciesDef == pokemon.PIKACHU) then return nil end
      return pokemon.RAICHU
    end
    statsCompat = compat
    return compat
  end

  local function trackStatsIdentity(mon)
    if type(mon) ~= "table" then return false end
    local compat = statsCompat or installStatsCompatibility()
    if type(mon.dvs) == "table" then compat.byDvs[mon.dvs] = mon end
    if type(mon.statExp) == "table" then
      compat.byStatExp[mon.statExp] = mon
    end
    return true
  end

  installStatsCompatibility()

  -- Newer engines reach this hook with the concrete Pokémon. It remains the
  -- preferred path there; the compatibility wrapper above covers the same
  -- rule on older engines without requiring an engine update.
  mod.hooks:wrap("pokemon.stats.def",
    function(nextDef, speciesDef, mon)
      local resolved = nextDef(speciesDef, mon)
      if not (isYellow() and isAwakenedPartner(mon)) then return resolved end
      local game = Y.game
      local raichu = game and game.data and game.data.pokemon
        and game.data.pokemon.RAICHU
      return raichu or resolved
    end, 300)

  local function recalculateAwakened(game, mon)
    if not (game and game.data and isAwakenedPartner(mon)) then return false end
    local pikachu = game.data.pokemon and game.data.pokemon.PIKACHU
    if not pikachu then return false end
    trackStatsIdentity(mon)
    local oldMax = math.max(1,
      tonumber(mon.stats and mon.stats.hp) or tonumber(mon.hp) or 1)
    local oldHP = math.max(0,
      math.min(oldMax, tonumber(mon.hp) or oldMax))
    local damage = oldMax - oldHP
    local Stats = require("src.pokemon.Stats")
    local fresh = Stats.calc(
      pikachu, mon.level or 1, mon.dvs or {}, mon.statExp, mon)
    mon.stats = fresh
    if oldHP <= 0 then
      mon.hp = 0
    else
      mon.hp = math.max(1, math.min(fresh.hp, fresh.hp - damage))
    end
    return true
  end

  local function awakenPartner(game, mon)
    if not (game and game.save and isYellow()
        and type(mon) == "table" and mon[MARKER] == true
        and mon.species == "PIKACHU"
        and mon[AWAKENING_MARKER] ~= true) then return false end
    mon[AWAKENING_MARKER] = true
    trackStatsIdentity(mon)
    local s = state()
    s.choice = "stay"
    s.awakenedAt = s.awakenedAt or os.time()
    persist(s)
    return recalculateAwakened(game, mon)
  end

  local function adoptUnique(save)
    local partner = markedPartner(save)
    if partner then return partner, false end
    local rows = candidates(save)
    if #rows == 1 then
      stamp(rows[1].mon)
      return rows[1].mon, true
    end
    return nil, false, rows
  end

  local function partnerInParty(game, needHealthy)
    local partner = markedPartner(game and game.save)
    if not partner then return nil end
    for _, mon in ipairs(game.save.party or {}) do
      if mon == partner and (not needHealthy or (mon.hp or 0) > 0) then
        return mon
      end
    end
    return nil
  end

  -- Yellow has a small set of NPC lines that explicitly mean the player's
  -- original partner, not a generic Pikachu in the world. Keep those lines
  -- accurate after the tracked partner becomes Raichu or Gorochu while
  -- leaving Pokédex entries, fans' own Pikachu and pre-starter dialogue
  -- untouched.
  local PARTNER_TEXT_KEYS = {
    "_CeladonMansion1Text6",
    "_CeladonMansion1Text8",
    "_CeladonMansion1Text10",
    "_CeladonMansion1Text11",
    "_CeladonMansion1Text12",
    "_Museum2FPikachuText1",
    "_Museum2FPikachuText2",
    "_PewterGymGuyText",
    "_SummerBeachHouseSurfinDudeText1",
  }
  local TEXTBOX_COMPAT_KEY = "__kantoAscendantYellowPartnerTextCompat"

  local function adaptPartnerText(game, text)
    if type(text) ~= "string" then return text end
    local partner = partnerInParty(game, false)
    if not (partner and isEvolvedPartnerSpecies(partner.species)) then
      return text
    end
    local dataText = game and game.data and game.data.text or {}
    for _, key in ipairs(PARTNER_TEXT_KEYS) do
      if dataText[key] == text then
        return (text:gsub("PIKACHU", partner.species))
      end
    end
    return text
  end

  local function installPartnerTextCompatibility()
    local TextBox = require("src.render.TextBox")
    local compat = rawget(TextBox, TEXTBOX_COMPAT_KEY)
    if type(compat) ~= "table" or TextBox.new ~= compat.wrapper then
      local original = TextBox.new
      compat = {}
      compat.wrapper = function(game, text, ...)
        return original(game, adaptPartnerText(game, text), ...)
      end
      TextBox.new = compat.wrapper
      rawset(TextBox, TEXTBOX_COMPAT_KEY, compat)
    end
    return true
  end

  local function questReady(s)
    s = s or state(false)
    return s and (s.legacy
      or (s.accepted and s.steps >= REQUIRED_STEPS
        and s.wins >= REQUIRED_WINS)) or false
  end

  local function grantHeart(game)
    if not (game and game.save) then return false end
    local save = game.save
    save.inventory = save.inventory or {}
    local fresh = not save.inventory[ITEM]
    -- Gorochu owns the editions-wide permanent item. Keep this fallback for
    -- ROM-free unit fixtures that instantiate Yellow's controller alone.
    if gorochu and gorochu.grantHeart then
      gorochu.grantHeart(game)
    else
      save.inventory[ITEM] = 1
      local ok, Bag = pcall(require, "src.inventory.Bag")
      if ok and Bag and Bag.order then Bag.order(save) end
    end
    local s = state()
    s.heartGiven = true
    s.heartGivenAt = s.heartGivenAt or os.time()
    persist(s)
    return fresh
  end

  local function isOldYellowSave(game)
    local save = game and game.save
    return isYellow() and save and save.flags
      and save.flags.EVENT_GOT_STARTER == true
  end

  function Y.migrate(game)
    game = game or Y.game
    if not (game and game.save and isYellow()) then return false end
    local raw = mod.save:get(STATE_KEY)
    local firstSeen = type(raw) ~= "table"
    local s = state()
    local changed = false
    if game.save.flags and game.save.flags.EVENT_GOT_STARTER then
      local _, adopted = adoptUnique(game.save)
      changed = adopted or changed
    end
    if firstSeen and isOldYellowSave(game) then
      s.offered = true
      s.accepted = true
      s.legacy = true
      s.steps = REQUIRED_STEPS
      s.wins = REQUIRED_WINS
      grantHeart(game)
      changed = true
    elseif game.save.inventory
        and (game.save.inventory[ITEM] or 0) > 0 then
      s.heartGiven = true
    end
    local partner = markedPartner(game.save)
    if partner then trackStatsIdentity(partner) end
    if partner and isEvolvedPartnerSpecies(partner.species) then
      s.choice = "evolved"
    elseif partner and isAwakenedPartner(partner) then
      s.choice = "stay"
      changed = recalculateAwakened(game, partner) or changed
    elseif s.choice == "stay" then
      -- 5.4.0 used this value for an unannounced cosmetic "stay" choice.
      -- It is not consent to the new one-time Awakening; only the marker on
      -- the actual partner Pokémon can claim that gift.
      s.choice = nil
      changed = true
    end
    s.initialized = true
    persist(s)
    return changed
  end

  local function nameOf(game, mon)
    local def = game and game.data and game.data.pokemon
      and game.data.pokemon[mon.species]
    return mon.nickname or (def and def.name) or mon.species
  end

  local function bondText(game, mon)
    local name = nameOf(game, mon)
    local happiness = math.max(0,
      math.min(255, tonumber(game.save.pikachuHappiness) or 90))
    if mon.species == "GOROCHU" then
      if happiness < 100 then
        return tr(
          ("%s lowers its horns\nbeside you.\fThe storm is fierce,\nbut your old bond\nstill guides it."):format(name),
          ("%s senkt neben dir\ndie Hörner.\fDer Sturm ist wild,\ndoch euer altes Band\nführt es weiter."):format(name))
      elseif happiness < 200 then
        return tr(
          ("%s touches a horn\nto the THUNDERHEART.\fA deep rumble answers,\nwarm and familiar."):format(name),
          ("%s berührt das\nDONNERHERZ mit einem Horn.\fTiefer Donner antwortet,\nwarm und vertraut."):format(name))
      end
      return tr(
        ("%s raises its horns.\fThunder rolls above,\nbut the strongest spark\nis still your bond."):format(name),
        ("%s hebt seine Hörner.\fDonner rollt über euch,\ndoch der stärkste Funke\nbleibt euer Band."):format(name))
    end
    if mon.species == "RAICHU" then
      if happiness < 100 then
        return tr(
          ("%s studies the\nTHUNDERHEART.\fIt stays close,\nstill learning its\nnew strength."):format(name),
          ("%s betrachtet das\nDONNERHERZ.\fEs bleibt nah und\nlernt seine neue\nKraft kennen."):format(name))
      elseif happiness < 200 then
        return tr(
          ("%s touches the\nTHUNDERHEART.\fSoft sparks answer.\nYour old bond is\nstill there."):format(name),
          ("%s berührt das\nDONNERHERZ.\fSanfte Funken antworten.\nEuer altes Band\nist noch da."):format(name))
      end
      return tr(
        ("%s presses its tail\nto the THUNDERHEART.\fThe same bond shines\nstronger than ever."):format(name),
        ("%s legt seinen Schweif\nans DONNERHERZ.\fEuer altes Band\nleuchtet stärker\nals je zuvor."):format(name))
    end
    if happiness < 100 then
      return tr(
        ("%s watches the\nTHUNDERHEART carefully.\fThere is no hurry.\nThe choice is its own."):format(name),
        ("%s mustert das\nDONNERHERZ vorsichtig.\fEs gibt keine Eile.\nDie Wahl gehört ihm."):format(name))
    elseif happiness < 200 then
      return tr(
        ("%s nudges the\nTHUNDERHEART.\fIts sparks answer\nyour steady bond."):format(name),
        ("%s stupst das\nDONNERHERZ an.\fSeine Funken antworten\nauf euer festes Band."):format(name))
    end
    return tr(
      ("%s holds the\nTHUNDERHEART with you.\fWhatever form it takes,\nit chooses your side."):format(name),
      ("%s hält mit dir das\nDONNERHERZ.\fWelche Form es auch\nwählt: Es bleibt bei dir."):format(name))
  end

  local function showText(game, text, done, textOpts)
    game.stack:push(require("src.render.TextBox").new(
      game, text, done, textOpts))
  end

  local function refreshFollower(game)
    local ok, follower = pcall(require, "src.world.PikachuFollower")
    local ow = game and game.overworld
    if ok and follower and ow and follower.onMapEntered then
      follower.onMapEntered(game, ow)
    end
  end

  local function evolvePartner(game, mon)
    local s = state()
    s.evolutionChosenAt = os.time()
    persist(s)
    local oldMax = math.max(1,
      tonumber(mon.stats and mon.stats.hp) or tonumber(mon.hp) or 1)
    local oldHP = math.max(0,
      math.min(oldMax, tonumber(mon.hp) or oldMax))
    pendingEvolutionHP[mon] = {
      hp = oldHP,
      damage = oldMax - oldHP,
    }
    require("src.pokemon.Evolution").evolve(
      game, mon, "RAICHU", function()
        refreshFollower(game)
        if mon.species == "RAICHU" then
          showText(game, tr(
            "The THUNDERHEART\nstill rests in your BAG.\fRAICHU's bond and\nmemories remain intact.",
            "Das DONNERHERZ bleibt\nin deinem BEUTEL.\fRAICHUs Band und\nErinnerungen bleiben."),
            function() end)
        end
      end, "ITEM")
  end

  local openHeart

  local function choiceRows(mon)
    local rows = {
      { label = tr("EVOLVE TO RAICHU", "ZU RAICHU"), value = "evolve" },
    }
    if not isAwakenedPartner(mon) then
      rows[#rows + 1] = {
        label = tr("STAY PIKACHU", "PIKACHU BLEIBEN"),
        value = "stay",
      }
    end
    rows[#rows + 1] = {
      label = tr("NOT YET", "NOCH NICHT"),
      value = "later",
    }
    return rows
  end

  local choiceMenu

  local function waitingText(game)
    showText(game, tr(
      "The THUNDERHEART\ncools gently.\fIt will wait in your\nBAG until both of\nyou are ready.",
      "Das DONNERHERZ\nkühlt sanft ab.\fEs wartet in deinem\nBEUTEL, bis ihr\nbeide bereit seid."))
  end

  local function confirmChoice(game, mon, value)
    if value == "evolve" then
      local awakened = isAwakenedPartner(mon)
      local text
      if awakened then
        text = tr(
          "PIKACHU has already\nawakened RAICHU's\nstrength.\fEvolution will change\nits form, but its stats\nwill not increase again.\fRAICHU learns no new\nmoves by leveling up.\fEvolution cannot be\nreversed.\fEvolve PIKACHU?",
          "PIKACHU besitzt bereits\nRAICHUs Stärke.\fDie Entwicklung ändert\nseine Form, erhöht seine\nWerte aber nicht erneut.\fRAICHU lernt keine\nweiteren Attacken durch\nLevelaufstieg.\fDie Entwicklung kann\nnicht rückgängig gemacht\nwerden.\fPIKACHU entwickeln?")
      else
        text = tr(
          "PIKACHU will evolve\ninto RAICHU and grow\nstronger.\fRAICHU learns no new\nmoves by leveling up.\fEvolution cannot be\nreversed.\fEvolve PIKACHU?",
          "PIKACHU entwickelt sich\nzu RAICHU und wird\nstärker.\fRAICHU lernt keine\nweiteren Attacken durch\nLevelaufstieg.\fDie Entwicklung kann\nnicht rückgängig gemacht\nwerden.\fPIKACHU entwickeln?")
      end
      showText(game, text, nil, {
        choice = function(yes)
          if yes then
            evolvePartner(game, mon)
          else
            choiceMenu(game, mon)
          end
        end,
      })
      return
    end

    if value == "stay" then
      showText(game, tr(
        "PIKACHU can awaken\nstrength equal to\nRAICHU while keeping\nits current form.\fThis gift works only\nonce. STAY PIKACHU\nwill disappear, but\nevolution remains\npossible.\fEvolving later will\nchange its form without\nanother stat\nincrease.\fAwaken PIKACHU?",
        "PIKACHU kann RAICHUs\nStärke erwecken und\nseine Form behalten.\fDiese Gabe wirkt nur\neinmal. PIKACHU BLEIBEN\nverschwindet danach,\naber die Entwicklung\nbleibt möglich.\fEine spätere Entwicklung\nändert nur die Form und\nerhöht die Werte nicht\nerneut.\fKraft erwecken?"),
        nil, {
          choice = function(yes)
            if not yes then
              choiceMenu(game, mon)
              return
            end
            if not awakenPartner(game, mon) then
              choiceMenu(game, mon)
              return
            end
            showText(game, tr(
              "PIKACHU presses the\nTHUNDERHEART close.\fIts hidden potential\nhas fully awakened!\fPIKACHU now possesses\nstrength equal to\nRAICHU.",
              "PIKACHU drückt das\nDONNERHERZ an sich.\fSein verborgenes\nPotenzial ist vollständig\nerwacht!\fPIKACHU besitzt nun\nRAICHUs Stärke."))
          end,
        })
      return
    end

    showText(game, tr(
      "Leave the THUNDERHEART\nunused for now?\fYou can return to this\nchoice at any time.",
      "Das DONNERHERZ vorerst\nnicht verwenden?\fDu kannst jederzeit zu\ndieser Wahl zurückkehren."),
      nil, {
        choice = function(yes)
          if yes then
            waitingText(game)
          else
            choiceMenu(game, mon)
          end
        end,
      })
  end

  choiceMenu = function(game, mon)
    local rows = choiceRows(mon)
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("PARTNER'S CHOICE", "WAHL DES PARTNERS"), rows, {
        onCancel = function() end,
        onChoose = function(item, menu)
          menu:close()
          confirmChoice(game, mon, item.value)
        end,
      }))
  end

  local function chooseLegacyPartner(game, rows)
    local menuRows = {}
    for index, row in ipairs(rows) do
      local location = row.where == "party"
        and tr("PARTY", "TEAM")
        or tr("BOX " .. tostring(row.box), "BOX " .. tostring(row.box))
      menuRows[#menuRows + 1] = {
        label = nameOf(game, row.mon),
        right = location,
        value = index,
      }
    end
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("YOUR PARTNER", "DEIN PARTNER"), menuRows, {
        onCancel = function() end,
        onChoose = function(item, menu)
          menu:close()
          for _, candidate in ipairs(rows) do
            candidate.mon[MARKER] = nil
          end
          stamp(rows[item.value].mon)
          showText(game, tr(
            "The THUNDERHEART\nrecognizes your original\nYellow partner.",
            "Das DONNERHERZ\nerkennt deinen ersten\nGelb-Partner."),
            function() openHeart(game) end)
        end,
      }))
  end

  openHeart = function(game)
    game = game or Y.game
    if not (game and game.save) then return false end
    local mon = markedPartner(game.save)
    if not mon then
      local rows = candidates(game.save)
      if #rows > 1 then
        chooseLegacyPartner(game, rows)
        return true
      elseif #rows == 1 then
        stamp(rows[1].mon)
        mon = rows[1].mon
      end
    end
    if not mon then
      showText(game, tr(
        "The THUNDERHEART\ncannot sense Yellow's\noriginal partner.",
        "Das DONNERHERZ spürt\ndeinen ersten\nGelb-Partner nicht."))
      return true
    end
    if not partnerInParty(game, false) then
      showText(game, tr(
        "The THUNDERHEART\nresponds from afar.\fPut your original\npartner in the PARTY.",
        "Das DONNERHERZ\nantwortet aus der Ferne.\fNimm deinen ersten\nPartner ins TEAM."))
      return true
    end
    if isEvolvedPartnerSpecies(mon.species) then
      local text = bondText(game, mon)
      if gorochu and gorochu.statusText then
        text = text .. "\f" .. gorochu.statusText(game)
      end
      showText(game, text)
      return true
    end
    local s = state()
    if not questReady(s) and not s.heartGiven then
      showText(game, tr(
        "The THUNDERHEART is\nstill dormant.",
        "Das DONNERHERZ\nschläft noch."))
      return true
    end
    showText(game, bondText(game, mon), function()
      choiceMenu(game, mon)
    end)
    return true
  end

  local function questStatus(s)
    return tr(
      ("HEART OF THUNDER\fWalk together: %d/%d\nTrainer wins: %d/%d")
        :format(math.min(s.steps, REQUIRED_STEPS), REQUIRED_STEPS,
          math.min(s.wins, REQUIRED_WINS), REQUIRED_WINS),
      ("HERZ DES DONNERS\fGemeinsame Schritte:\n%d/%d\nTrainer-Siege: %d/%d")
        :format(math.min(s.steps, REQUIRED_STEPS), REQUIRED_STEPS,
          math.min(s.wins, REQUIRED_WINS), REQUIRED_WINS))
  end

  local function offerQuest(ow, npc, game)
    local s = state()
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    s.offered = true
    persist(s)
    showText(game, tr(
      "LT.SURGE studies your\npartner's sparks.\fKID! PIKACHU IS\nHOLDING A RARE CHARGE.\fWalk 251 steps and\nwin 3 trainer battles\ntogether.\fHelp it choose its\nown path?",
      "LT.SURGE prüft die\nFunken deines Partners.\fKIND! IN PIKACHU\nSTECKT SELTENE KRAFT.\fGeht 251 Schritte und\ngewinnt 3 Trainerkämpfe\nzusammen.\fHilfst du ihm, seinen\neigenen Weg zu wählen?"), nil, {
        choice = function(yes)
          if yes then
            s.accepted = true
            s.declined = false
            s.acceptedAt = os.time()
            persist(s)
            showText(game, tr(
              "HEART OF THUNDER\nhas begun.\fReturn when your bond\nhas carried the charge.",
              "HERZ DES DONNERS\nhat begonnen.\fKehrt zurück, wenn euer\nBand die Kraft trägt."),
              done)
          else
            s.declined = true
            s.accepted = false
            persist(s)
            showText(game, tr(
              "NO PRESSURE, KID!\fPIKACHU'S CHOICE\nSTAYS ITS OWN.\fA later Mega Stone\nmay answer that spark\nin another way.",
              "KEIN DRUCK, KIND!\fPIKACHUS WAHL\nBLEIBT SEINE EIGENE.\fEin späterer Mega-Stein\nkann anders auf die\nFunken antworten."),
              done)
          end
        end,
      })
    return true
  end

  function Y.handleTalk(ow, npc, game)
    if not (isYellow() and ow and npc and npc.def and game
        and ow.map and ow.map.id == "VERMILION_GYM"
        and npc.def.name == SURGE
        and game.save.inventory and game.save.inventory.THUNDERBADGE) then
      return false
    end
    Y.migrate(game)
    local s = state()
    if not s.offered then return offerQuest(ow, npc, game) end
    if not s.accepted or s.heartGiven then return false end
    npc.frozen = true
    npc:facePlayer(ow.player)
    local done = function() npc.frozen = false end
    if not questReady(s) then
      showText(game, questStatus(s), done)
      return true
    end
    grantHeart(game)
    showText(game, tr(
      "YOU TWO DID IT!\fThat charge became a\nTHUNDERHEART.\fIt can never break,\nbe sold or leave your\nBAG.\fUse it when your\npartner is ready.",
      "IHR HABT ES GESCHAFFT!\fDie Kraft wurde zum\nDONNERHERZ.\fEs kann nie zerbrechen,\nverkauft oder weggeworfen\nwerden.\fNutze es, wenn dein\nPartner bereit ist."),
      done)
    return true
  end

  local function installGiftMarker()
    local ok, Commands = pcall(require, "src.script.Commands")
    if not (ok and Commands and type(Commands.give_pokemon) == "function") then
      return false
    end
    local key = "__ascendantYellowPartnerGift"
    local current = rawget(Commands, key)
    if current then
      current.controller = Y
      return true
    end
    local original = Commands.give_pokemon
    local holder = { controller = Y, original = original }
    holder.wrapper = function(ctx, species, level, skipNickname)
      local save = ctx and ctx.save
      local mapId = ctx and ctx.overworld and ctx.overworld.map
        and ctx.overworld.map.id
      local exactGift = holder.controller and isYellow()
        and species == "PIKACHU" and tonumber(level) == 5
        and skipNickname == true and mapId == "OAKS_LAB"
        and save and not (save.flags and save.flags.EVENT_GOT_STARTER)
      local before = {}
      if exactGift then eachPokemon(save, function(mon) before[mon] = true end) end
      local result = original(ctx, species, level, skipNickname)
      if exactGift then
        eachPokemon(save, function(mon)
          if not before[mon] and mon.species == "PIKACHU" then
            stamp(mon)
            return false
          end
        end)
      end
      return result
    end
    Commands.give_pokemon = holder.wrapper
    rawset(Commands, key, holder)
    return true
  end

  local function installItemEffect()
    local ok, ItemEffects = pcall(require, "src.inventory.ItemEffects")
    if not (ok and ItemEffects and type(ItemEffects.use) == "function") then
      return false
    end
    local key = "__ascendantYellowPartnerItem"
    local current = rawget(ItemEffects, key)
    if current then
      current.controller = Y
      return true
    end
    local original = ItemEffects.use
    local holder = { controller = Y, original = original }
    holder.wrapper = function(data, save, itemId, target, battle, ...)
      if itemId ~= ITEM then
        return original(data, save, itemId, target, battle, ...)
      end
      if battle then
        return "failed", { tr(
          "It can't be used\nin battle.",
          "Das geht nicht\nim Kampf.") }
      end
      if not isYellow() then
        local controller = holder.controller
        if gorochu and gorochu.openHeart and controller
            and controller.game and controller.game.save == save then
          gorochu.openHeart(controller.game)
          return "failed", nil
        end
        return "failed", { tr(
          "It points toward the\nPOWER PLANT.",
          "Es weist zum\nKRAFTWERK.") }
      end
      local controller = holder.controller
      if controller and controller.game and controller.game.save == save then
        controller.openHeart(controller.game)
        return "failed", nil
      end
      return "failed", { tr(
        "The THUNDERHEART is\nquiet.",
        "Das DONNERHERZ\nbleibt still.") }
    end
    ItemEffects.use = holder.wrapper
    rawset(ItemEffects, key, holder)
    return true
  end

  local function externalFollowerMon(game)
    local exports = game and game.mods and game.mods.exports
    if type(exports) ~= "table" then return nil, false end
    for _, api in pairs(exports) do
      if api ~= Y and type(api) == "table"
          and type(api.activeMon) == "function" then
        local ok, mon = pcall(api.activeMon, game)
        if ok then return mon, true end
      end
    end
    return nil, false
  end

  local function partnerIsActive(game, mon)
    local active, external = externalFollowerMon(game)
    if external then return active == mon, true end
    return true, false
  end

  local function followerPath(mon)
    if not (spriteAssets and spriteAssets.iconFollower) then return nil end
    local shiny = shinySystem and shinySystem.isShiny
      and shinySystem.isShiny(mon) or false
    if mon and mon.species == "GOROCHU" and spriteAssets.follower then
      local path = spriteAssets.follower("GOROCHU", shiny)
      if path then return path end
    end
    local variant = shiny and "shiny" or "normal"
    local dex = mon and mon.species == "GOROCHU" and 1026 or 26
    local cacheSpecies = mon and mon.species == "GOROCHU"
      and "gorochu" or "raichu"
    return spriteAssets.iconFollower(
      ("assets/crystal_animated/front/%s/%d/001.png"):format(variant, dex),
      "yellow_partner_" .. cacheSpecies .. "_" .. variant)
  end

  local RAICHU_VOICE_PATHS = {
    sleepy = "assets/audio/partner_raichu/raichu_sleepy.wav",
    unwell = "assets/audio/partner_raichu/raichu_unwell.wav",
    upset = "assets/audio/partner_raichu/raichu_upset.wav",
    wary = "assets/audio/partner_raichu/raichu_wary.wav",
    content = "assets/audio/partner_raichu/raichu_content.wav",
    devoted = "assets/audio/partner_raichu/raichu_devoted.wav",
    excited = "assets/audio/partner_raichu/raichu_excited.wav",
  }
  local RAICHU_VOICES = {}
  for id in pairs(RAICHU_VOICE_PATHS) do
    RAICHU_VOICES[id] = "ASCENDANT_RAICHU_VOICE_" .. id:upper()
  end

  -- Partner Raichu has the same seven deliberately authored expressions as
  -- Gorochu. The numbered frames animate one face; they never borrow battle
  -- poses or pretend that a different cadence is a different emotion.
  local RAICHU_PORTRAITS = {
    sleepy = {
      sequence = { 1, 1, 2, 1 }, ticks = 18, hold = 90,
    },
    unwell = {
      sequence = { 1, 2, 1, 3 }, ticks = 14, hold = 72,
    },
    upset = {
      sequence = { 1, 3, 1, 2 }, ticks = 11, hold = 110,
    },
    wary = {
      sequence = { 1, 2, 3, 1 }, ticks = 14, hold = 72,
    },
    content = {
      sequence = { 1, 2, 1, 3 }, ticks = 12, hold = 96,
    },
    devoted = {
      sequence = { 1, 2, 3, 2 }, ticks = 13, hold = 104,
    },
    excited = {
      sequence = { 1, 2, 3, 1, 3, 2 }, ticks = 8, hold = 200,
    },
  }

  local GOROCHU_PORTRAITS = {
    -- Gorochu owns seven purpose-built facial expressions. The numbered
    -- frames below only animate each expression; they never substitute a
    -- different mood or alter the creature's regular battle art.
    sleepy = { sequence = { 1, 2, 1, 3 }, ticks = 18, hold = 90 },
    unwell = { sequence = { 1, 2, 1, 3 }, ticks = 14, hold = 72 },
    upset = { sequence = { 1, 3, 1, 2 }, ticks = 11, hold = 110 },
    wary = { sequence = { 1, 2, 1, 3 }, ticks = 14, hold = 72 },
    content = { sequence = { 1, 2, 1, 3 }, ticks = 12, hold = 96 },
    devoted = { sequence = { 1, 2, 1, 3 }, ticks = 13, hold = 104 },
    excited = { sequence = { 1, 2, 3, 1, 3, 2 }, ticks = 8, hold = 200 },
  }

  local function partnerSpeech(text, mon)
    if not (mon and mon.species == "GOROCHU") then return text end
    return tostring(text)
      :gsub("RAI%-RAICHU", "GORO%-GOROCHU")
      :gsub("RAICHU", "GOROCHU")
  end

  local function decorateReaction(row, mon)
    row.text = partnerSpeech(row.text, mon)
    if mon and mon.species == "GOROCHU" then
      row.voice = nil
      row.portrait = GOROCHU_PORTRAITS[row.id]
    else
      row.voice = RAICHU_VOICES[row.id]
      row.portrait = RAICHU_PORTRAITS[row.id]
    end
    return row
  end

  local function raichuReaction(game, mon)
    local save = game and game.save or {}
    local happiness = math.max(0,
      math.min(255, tonumber(save.pikachuHappiness) or 90))
    local mood = math.max(0,
      math.min(255, tonumber(save.pikachuMood) or 128))

    if mon and mon.status == "SLP" then
      return decorateReaction({
        id = "sleepy",
        bubble = "ZZZ_BUBBLE",
        text = tr(
          "RAICHU... zzz...\fIts tail curls\naround your feet as\nit dozes beside you.",
          "RAICHU... zzz...\fSein Schweif liegt\num deine Füße,\nwährend es neben dir\ndöst."),
      }, mon)
    end
    if mon and ((tonumber(mon.hp) or 0) <= 0 or mon.status) then
      return decorateReaction({
        id = "unwell",
        bubble = "SKULL_BUBBLE",
        text = tr(
          "RAICHU...\fIts ears droop.\fIts sparks feel weak.\nIt needs some care.",
          "RAICHU...\fSeine Ohren hängen.\fDie Funken sind schwach.\nEs braucht etwas Pflege."),
      }, mon)
    end
    if happiness < 50 or mood < 80 then
      return decorateReaction({
        id = "upset",
        bubble = "BOLT_BUBBLE",
        turnAway = true,
        text = tr(
          "RAICHU...\fIt looks away.\fTiny sparks crackle\nsharply.\fIt may need a little\nspace for now.",
          "RAICHU...\fEs schaut weg.\fKleine Funken\nknistern scharf.\fVielleicht braucht es\netwas Abstand."),
      }, mon)
    end
    if happiness < 100 or mood < 120 then
      return decorateReaction({
        id = "wary",
        bubble = "QUESTION_BUBBLE",
        text = tr(
          "RAICHU?\fIt watches you,\nthen carefully steps\na little closer.",
          "RAICHU?\fEs beobachtet dich\nund kommt dann ganz\nvorsichtig näher."),
      }, mon)
    end
    if happiness >= 240 and mood >= 140 then
      return decorateReaction({
        id = "excited",
        bubble = "EXCLAMATION_BUBBLE",
        text = tr(
          "RAI-RAICHU!\fIt races around you,\ncheeks flashing with\nbright, playful sparks!",
          "RAI-RAICHU!\fEs flitzt um dich.\fSeine Wangen sprühen\nverspielte Funken!"),
      }, mon)
    end
    if happiness >= 200 then
      return decorateReaction({
        id = "devoted",
        bubble = "HEART_BUBBLE",
        text = tr(
          "RAICHU!\fIt presses its head\nto yours.\fYour bond feels\nstronger than ever.",
          "RAICHU!\fEs drückt seinen Kopf\nan deinen.\fEuer Band ist stärker\nals je zuvor."),
      }, mon)
    end
    return decorateReaction({
      id = "content",
      bubble = "SMILE_BUBBLE",
      text = tr(
        "RAICHU!\fIts tail brushes\nyour hand.\fA calm, happy spark\njumps between you.",
        "RAICHU!\fSein Schweif streift\ndeine Hand.\fEin ruhiger Funke\nspringt zwischen euch."),
    }, mon)
  end

  local function emotionBubble(game, name)
    local sheet = game and game.data and game.data.field
      and game.data.field.emotionBubbles
    for index, row in ipairs(sheet and sheet.bubbles or {}) do
      if row.name == name then return index end
    end
    return nil
  end

  local function portraitFrames(mon, reaction)
    local portrait = reaction and reaction.portrait
    if not portrait then return nil end
    local shiny = shinySystem and shinySystem.isShiny
      and shinySystem.isShiny(mon) or false
    local variant = shiny and "shiny" or "normal"
    local out = {}
    for _, frame in ipairs(portrait.sequence or {}) do
      if mon and mon.species == "GOROCHU" then
        out[#out + 1] = (
          "%s/assets/yellow_partner_gorochu_portraits/%s/%s/%03d.png")
          :format(mod.path, variant, reaction.id, frame)
      else
        out[#out + 1] = (
          "%s/assets/yellow_partner_raichu_portraits/%s/%s/%03d.png")
          :format(mod.path, variant, reaction.id, frame)
      end
    end
    return out
  end

  local function portraitImage(path)
    if not (path and love and love.graphics and love.graphics.newImage) then
      return nil
    end
    local cached = runtime.portraitImages[path]
    if cached ~= nil then return cached or nil end
    local ok, image = pcall(love.graphics.newImage, path)
    runtime.portraitImages[path] = ok and image or false
    return ok and image or nil
  end

  local function portraitBoxX(ow, npc)
    local cameraX = ow and ow.camera and tonumber(ow.camera.x) or 0
    local worldX = npc and tonumber(npc.px)
      or (npc and tonumber(npc.cellX) or 0) * 16
    local bubbleCenter = worldX - cameraX + 9
    -- A 7x7 box occupies 56 UI pixels. With the follower around the
    -- screen center, x=1 ends at 64 and x=12 starts at 96, leaving the
    -- 16px emotion bubble completely clear in either direction.
    return bubbleCenter <= 80 and 12 or 1
  end

  local function advanceRaichuPortrait(ow)
    local emote = ow and ow.emote
    local frames = emote and emote._ascendantRaichuFrames
    if not (frames and #frames > 0) then return end
    local elapsed = math.max(0,
      (emote.pikaTotal or emote.frames or 0) - (emote.frames or 0))
    local ticks = math.max(1,
      math.floor(tonumber(emote._ascendantRaichuTicks) or 8))
    local index = math.floor(elapsed / ticks) % #frames + 1
    local path = frames[index]
    if emote.pikaPic == path then return end
    emote.pikaPic = path
    local image = portraitImage(path)
    if image then
      ow.pikaPicPath = path
      ow.pikaPicImg = image
    end
  end

  local function drawRaichuPortrait(ow)
    local emote = ow and ow.emote
    if not (emote and emote._ascendantRaichuPortrait
        and emote.pikaPic) then return end
    local boxX = tonumber(emote._ascendantRaichuBoxX) or 1
    local boxY = tonumber(emote._ascendantRaichuBoxY) or 1
    require("src.render.Font").drawBox(boxX, boxY, 7, 7)
    local image = portraitImage(emote.pikaPic)
    if not image then return end
    love.graphics.setColor(1, 1, 1, 1)
    local w, h = image:getDimensions()
    local imageX = (boxX + 1) * 8
    local imageY = (boxY + 1) * 8
    -- These are intentionally colored dialogue portraits. Exempt only the
    -- 40x40 inner picture from the overworld shade-remap; otherwise the
    -- Pikachu SGB palette washes Gorochu red and Raichu orange into the same
    -- pale sepia block and makes the custom mimic box look malformed.
    local okPalette, PaletteFX = pcall(require, "src.render.PaletteFX")
    if okPalette and PaletteFX and PaletteFX.markTrueColor then
      PaletteFX.markTrueColor(imageX, imageY, 40, 40)
    end
    love.graphics.draw(image,
      math.floor(imageX + (40 - w) / 2),
      math.floor(imageY + (40 - h) / 2))
  end

  local function installPortraitAnimator()
    local ok, OverworldState = pcall(
      require, "src.world.OverworldController")
    if not (ok and OverworldState
        and type(OverworldState.update) == "function") then return false end
    local key = "__ascendantRaichuPortraitAnimator"
    local holder = rawget(OverworldState, key)
    if holder then
      holder.controller = Y
      return true
    end
    holder = {
      controller = Y,
      original = OverworldState.update,
    }
    OverworldState.update = function(ow, dt)
      local controller = holder.controller
      if controller and controller._advanceRaichuPortrait then
        controller._advanceRaichuPortrait(ow)
      end
      return holder.original(ow, dt)
    end
    rawset(OverworldState, key, holder)
    return true
  end

  local function installPortraitRenderer()
    local ok, OverworldState = pcall(
      require, "src.world.OverworldController")
    if not (ok and OverworldState
        and type(OverworldState.drawUI) == "function"
        and type(OverworldState.sgbPalettes) == "function") then
      return false
    end

    local drawKey = "__ascendantRaichuPortraitRenderer"
    local drawHolder = rawget(OverworldState, drawKey)
    if drawHolder then
      drawHolder.controller = Y
    else
      drawHolder = {
        controller = Y,
        original = OverworldState.drawUI,
      }
      OverworldState.drawUI = function(ow, ...)
        local emote = ow and ow.emote
        if not (emote and emote._ascendantRaichuPortrait) then
          return drawHolder.original(ow, ...)
        end
        -- Suppress only the engine's fixed center portrait. Every other UI
        -- overlay still draws normally, then Ascendant places Raichu in the
        -- free corner selected opposite its emotion bubble.
        local pic = emote.pikaPic
        emote.pikaPic = nil
        local packed = { pcall(drawHolder.original, ow, ...) }
        emote.pikaPic = pic
        if not packed[1] then error(packed[2], 2) end
        local controller = drawHolder.controller
        if controller and controller._drawRaichuPortrait then
          controller._drawRaichuPortrait(ow)
        end
        return unpack(packed, 2)
      end
      rawset(OverworldState, drawKey, drawHolder)
    end

    local paletteKey = "__ascendantRaichuPortraitPalette"
    local paletteHolder = rawget(OverworldState, paletteKey)
    if paletteHolder then
      paletteHolder.controller = Y
      return true
    end
    paletteHolder = {
      controller = Y,
      original = OverworldState.sgbPalettes,
    }
    OverworldState.sgbPalettes = function(ow, ...)
      local zones = paletteHolder.original(ow, ...)
      local emote = ow and ow.emote
      if not (emote and emote._ascendantRaichuPortrait
          and type(zones) == "table") then return zones end
      local x = (tonumber(emote._ascendantRaichuBoxX) or 1) + 1
      local y = (tonumber(emote._ascendantRaichuBoxY) or 1) + 1
      -- Move the engine's 40x40 Pikachu portrait palette zone with the
      -- custom frame so Raichu keeps its intended Yellow colors.
      for _, zone in ipairs(zones) do
        if type(zone) == "table" and zone.x == 56 and zone.y == 48
            and zone.w == 40 and zone.h == 40 then
          zone.x, zone.y = x * 8, y * 8
        end
      end
      return zones
    end
    rawset(OverworldState, paletteKey, paletteHolder)
    return true
  end

  local function configureRaichuFollower(game, mon)
    local def = game and game.data and game.data.sprites
      and game.data.sprites.SPRITE_PIKACHU
    if not def then return false end
    local path = followerPath(mon)
    if not path then return false end
    local changed = def.image ~= path or def.frames ~= 6
      or def.walker ~= true or def.trueColor ~= true
    def.image = path
    def.frames = 6
    def.walker = true
    def.trueColor = true
    local okFollower, follower = pcall(require, "src.world.PikachuFollower")
    local npc = okFollower and game.overworld and follower.current
      and follower.current(game.overworld)
    local okRenderer, Renderer = pcall(require, "src.render.SpriteRenderer")
    local species = mon and mon.species or "RAICHU"
    if npc and okRenderer and Renderer and Renderer.new
        and (changed
          or npc._ascendantYellowPartnerSpecies ~= species) then
      npc.sprite = Renderer.new(def, npc.id)
      npc._ascendantYellowPartnerSpecies = species
    end
    return true
  end

  local function restoreVanillaFollower(game)
    local def = game and game.data and game.data.sprites
      and game.data.sprites.SPRITE_PIKACHU
    if not def or runtime.baseFollowerImage == nil then return end
    local changed = def.image ~= runtime.baseFollowerImage
      or def.frames ~= runtime.baseFollowerFrames
      or def.walker ~= runtime.baseFollowerWalker
      or def.trueColor ~= runtime.baseFollowerTrueColor
    if not changed then return end
    def.image = runtime.baseFollowerImage
    def.frames = runtime.baseFollowerFrames
    def.walker = runtime.baseFollowerWalker
    def.trueColor = runtime.baseFollowerTrueColor
    local okFollower, follower = pcall(require, "src.world.PikachuFollower")
    local npc = okFollower and game.overworld and follower.current
      and follower.current(game.overworld)
    local okRenderer, Renderer = pcall(require, "src.render.SpriteRenderer")
    if npc and okRenderer and Renderer and Renderer.new then
      npc.sprite = Renderer.new(def, npc.id)
      npc._ascendantYellowPartnerSpecies = nil
    end
  end

  local function withSpawnAlias(game, callback)
    local _, external = externalFollowerMon(game)
    if external then return callback() end
    local mon = partnerInParty(game, true)
    if not (mon and isEvolvedPartnerSpecies(mon.species)) then
      restoreVanillaFollower(game)
      return callback()
    end
    configureRaichuFollower(game, mon)
    local species = mon.species
    mon.species = "PIKACHU"
    local packed = { pcall(callback) }
    mon.species = species
    if not packed[1] then error(packed[2], 2) end
    return unpack(packed, 2)
  end

  local function raichuFollowerTalk(game, ow, npc, done, mon)
    if npc.moving then
      npc.cellX, npc.cellY = npc.targetX or npc.cellX, npc.targetY or npc.cellY
      npc.targetX, npc.targetY = nil, nil
      npc.moving = false
      npc.progress = 0
      npc.hopStep = nil
    end
    if npc.facePlayer then npc:facePlayer(ow.player) end
    local opposite = { up = "down", down = "up", left = "right", right = "left" }
    ow.player.facing = opposite[npc.facing] or ow.player.facing
    local reaction = raichuReaction(game, mon)
    local okSound, Sound = pcall(require, "src.core.Sound")
    if okSound and Sound then
      local spoken = reaction.voice and Sound.play
        and Sound.play(game.data, reaction.voice)
      if not spoken and Sound.playCry then
        Sound.playCry(game.data, mon.species)
      end
    end
    if reaction.turnAway then
      npc.facing = ow.player.facing
    end
    local bubble = emotionBubble(game, reaction.bubble)
    local frames = portraitFrames(mon, reaction)
    local pic = frames and frames[1] or nil
    local portrait = reaction.portrait or {}
    ow.emote = {
      npc = npc, frames = portrait.hold or 120,
      bubble = bubble or false, pikaPic = pic,
      pikaTotal = portrait.hold or 120, skippable = true,
      _ascendantRaichuPortrait = true,
      _ascendantRaichuFrames = frames,
      _ascendantRaichuTicks = portrait.ticks,
      _ascendantRaichuBoxX = portraitBoxX(ow, npc),
      _ascendantRaichuBoxY = 1,
      onDone = function()
        showText(game, reaction.text, done)
      end,
    }
    advanceRaichuPortrait(ow)
  end

  local function installFollowerBridge(game)
    local ok, follower = pcall(require, "src.world.PikachuFollower")
    if not (ok and follower) then return false end
    local def = game.data and game.data.sprites
      and game.data.sprites.SPRITE_PIKACHU
    if def and runtime.baseFollowerImage == nil then
      runtime.baseFollowerImage = def.image
      runtime.baseFollowerFrames = def.frames
      runtime.baseFollowerWalker = def.walker
      runtime.baseFollowerTrueColor = def.trueColor
    end
    local key = "__ascendantYellowPartnerFollower"
    local holder = rawget(follower, key)
    if holder then
      holder.controller = Y
      return true
    end
    holder = {
      controller = Y,
      starterInParty = follower.starterInParty,
      modifyHappiness = follower.modifyHappiness,
      onMapEntered = follower.onMapEntered,
      update = follower.update,
      talk = follower.talk,
    }
    follower.starterInParty = function(save, needHealthy)
      local original = holder.starterInParty(save, needHealthy)
      if original then return original end
      local gameNow = holder.controller and holder.controller.game
      if gameNow and gameNow.save == save then
        return partnerInParty(gameNow, needHealthy)
      end
    end
    follower.modifyHappiness = function(save, reason, mon)
      local gameNow = holder.controller and holder.controller.game
      local partner = gameNow and gameNow.save == save
        and markedPartner(save) or nil
      if partner and mon == partner
          and isEvolvedPartnerSpecies(partner.species) then
        local species = partner.species
        partner.species = "PIKACHU"
        local packed = { pcall(holder.modifyHappiness, save, reason, partner) }
        partner.species = species
        if not packed[1] then error(packed[2], 2) end
        return unpack(packed, 2)
      end
      return holder.modifyHappiness(save, reason, mon)
    end
    follower.onMapEntered = function(gameNow, ow, ...)
      local args = { ... }
      return withSpawnAlias(gameNow, function()
        return holder.onMapEntered(gameNow, ow, unpack(args))
      end)
    end
    follower.update = function(gameNow, ow, ...)
      local args = { ... }
      return withSpawnAlias(gameNow, function()
        return holder.update(gameNow, ow, unpack(args))
      end)
    end
    follower.talk = function(gameNow, ow, npc, done)
      local mon = markedPartner(gameNow and gameNow.save)
      local active = mon and isEvolvedPartnerSpecies(mon.species)
        and partnerIsActive(gameNow, mon)
      if active and npc and npc.pikachuFollower then
        return raichuFollowerTalk(gameNow, ow, npc, done, mon)
      end
      return holder.talk(gameNow, ow, npc, done)
    end
    rawset(follower, key, holder)
    return true
  end

  function Y.install(game, deps)
    Y.game = game
    deps = deps or {}
    runtime.gameVersion = deps.gameVersion or runtime.gameVersion
    installGiftMarker()
    installItemEffect()
    installFollowerBridge(game)
    installPortraitAnimator()
    installPortraitRenderer()
    installPartnerTextCompatibility()
    Y.migrate(game)
  end

  function Y.isPartner(mon)
    return type(mon) == "table" and mon[MARKER] == true
  end

  function Y.partner(game)
    return markedPartner((game or Y.game) and (game or Y.game).save)
  end

  function Y.heartOwned(game)
    game = game or Y.game
    return game and game.save and game.save.inventory
      and (game.save.inventory[ITEM] or 0) > 0 or false
  end

  -- A partner that remains Pikachu can answer either Raichunite directly.
  -- The Mega Ring and matching stone remain enforced by mega_evolution.lua;
  -- this predicate only proves the story identity and the chosen base form.
  function Y.megaEligible(mon)
    return isYellow() and Y.isPartner(mon) and mon.species == "PIKACHU"
  end

  function Y.isAwakened(mon)
    return isAwakenedPartner(mon)
  end

  function Y.awaken(game, mon)
    return awakenPartner(game or Y.game, mon)
  end

  function Y.recalculateAwakened(game, mon)
    return recalculateAwakened(game or Y.game, mon)
  end

  function Y.openHeart(game)
    return openHeart(game)
  end

  function Y.state(create)
    return state(create)
  end

  function Y.questReady()
    return questReady(state(false))
  end

  function Y.grantHeart(game)
    return grantHeart(game or Y.game)
  end

  function Y.raichuReaction(game, mon)
    return raichuReaction(game or Y.game, mon)
  end

  Y._advanceRaichuPortrait = advanceRaichuPortrait
  Y._drawRaichuPortrait = drawRaichuPortrait
  Y._portraitBoxX = portraitBoxX
  Y._portraitFrames = portraitFrames
  Y._adaptPartnerText = adaptPartnerText
  Y._choiceRows = choiceRows
  Y._confirmChoice = confirmChoice
  Y._evolvePartner = evolvePartner

  Y.itemId = ITEM
  Y.marker = MARKER
  Y.awakeningMarker = AWAKENING_MARKER
  Y.requiredSteps = REQUIRED_STEPS
  Y.requiredWins = REQUIRED_WINS

  for id, path in pairs(RAICHU_VOICE_PATHS) do
    mod.content.sfx:register(RAICHU_VOICES[id], {
      file = mod.path .. "/" .. path,
    })
  end

  local function ascendantMenuRow(game)
    local s = state(false)
    if not isYellow() or not s or not (s.accepted or s.heartGiven) then
      return nil
    end
    local mon = markedPartner(game and game.save)
    local right
    if mon and isEvolvedPartnerSpecies(mon.species) then
      -- GOROCHU RESEARCH directly below already names the evolved form.
      -- Leaving this side blank also keeps the permanent Heart from looking
      -- like it has an item quantity beside it.
      right = nil
    elseif mon and isAwakenedPartner(mon) then
      right = tr("AWAKE", "ERWACHT")
    elseif s.heartGiven or questReady(s) then
      right = tr("READY", "BEREIT")
    else
      -- The old "0/3" trainer-win summary collided with the long heading,
      -- visually reading as "HEART OF THUNDER x3". Exact step/win progress
      -- remains on the detail page opened by this row.
      right = tr("ACTIVE", "AKTIV")
    end
    return {
      label = tr("PARTNER", "PARTNER"),
      right = right,
      ascendantMenu = true,
      ascendantLabel = tr("THUNDERHEART", "DONNERHERZ"),
      ascendantOrder = 15,
      ascendantKey = "yellow_partner",
      onSelect = function()
        local text
        if not s.heartGiven then
          text = questStatus(s)
          if questReady(s) then
            text = text .. tr(
              "\fRETURN TO LT.SURGE\nVERMILION GYM",
              "\fZURÜCK ZU LT.SURGE\nORANIA-ARENA")
          end
        elseif mon then
          text = bondText(game, mon) .. tr(
            "\fUse THUNDERHEART\nfrom the BAG whenever\nyou want to revisit\nthe choice.",
            "\fNutze DONNERHERZ im\nBEUTEL, um die Wahl\njederzeit neu zu öffnen.")
        else
          text = tr(
            "THUNDERHEART cannot\nsense the original\npartner.\fUse it from the BAG\nto identify the partner.",
            "DONNERHERZ spürt den\nersten Partner nicht.\fNutze es im BEUTEL,\num ihn auszuwählen.")
        end
        showText(game, text)
      end,
    }
  end

  -- Kept as a narrow QA seam so the compact heading and its status can be
  -- regression-tested without depending on ListMenu's renderer.
  Y._ascendantMenuRow = ascendantMenuRow

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" then return out end
    local row = ascendantMenuRow(game)
    if not row then return out end
    return mod.ui.insertBefore(out, tr("SAVE", "SICHERN"), row)
  end, 271)

  mod.events:on("world.stepped", function()
    local game = Y.game
    local s = state(false)
    if not (game and s and s.accepted and not s.heartGiven
        and not questReady(s) and partnerInParty(game, true)) then return end
    if s.steps < REQUIRED_STEPS then
      s.steps = s.steps + 1
      persist(s)
    end
  end)

  mod.events:on("battle.ended", function(ev)
    local game = ev and ev.battle and ev.battle.game or Y.game
    local battle = ev and ev.battle
    local s = state(false)
    if not (game and battle and s and s.accepted and not s.heartGiven
        and ev.result == "win" and partnerInParty(game, false)) then return end
    local trainer = battle.kind == "trainer" or battle.trainer ~= nil
      or battle.oppClass ~= nil or battle.rematchTrainerClass ~= nil
      or battle.johtoTrial ~= nil or battle.postgameTier ~= nil
    if trainer and s.wins < REQUIRED_WINS then
      s.wins = s.wins + 1
      persist(s)
    end
  end)

  mod.events:on("save.loaded", function(ev)
    Y.migrate(Y.game)
  end)

  mod.events:on("pokemon.evolved", function(ev)
    if ev and Y.isPartner(ev.mon)
        and isEvolvedPartnerSpecies(ev.toSpecies) then
      local prior = pendingEvolutionHP[ev.mon]
      if prior then
        local newMax = math.max(1,
          tonumber(ev.mon.stats and ev.mon.stats.hp)
            or tonumber(ev.mon.hp) or 1)
        if prior.hp <= 0 then
          ev.mon.hp = 0
        else
          ev.mon.hp = math.max(1,
            math.min(newMax, newMax - prior.damage))
        end
        pendingEvolutionHP[ev.mon] = nil
      end
      local s = state()
      s.choice = "evolved"
      persist(s)
    end
  end)

  return Y
end
