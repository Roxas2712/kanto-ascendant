-- Kanto Ascendant Mega Evolution.
--
-- Official species use their released Mega Evolution through July 2026.
-- Every official form requires its own Mega Stone. Kanto Ascendant also hides
-- one clearly labelled fan form outside the Stone Case: Ascendant Typhlosion,
-- awakened by the permanent Basalt Core relic.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = opts.postgame
  local animationData = opts.animationData or {}
  local enabled = opts.contentEnabled ~= false
  local yellowPartner = opts.yellowPartner
  local M = { game = nil, enabled = enabled }

  local function form(species, id, stone, label, tier, cost, bonuses, types,
      asset, special)
    special = special or {}
    asset = asset or ("mega_" .. id:lower())
    return {
      species = species, id = id, stone = stone, label = label,
      tier = tier or "hof", cost = cost or 5000,
      bonuses = bonuses, types = types, asset = asset,
      secret = special.secret == true,
      secretHealing = tonumber(special.secretHealing),
      quest = special.quest,
    }
  end

  -- +100 is distributed across the four non-HP Gen-1 stats. Forms whose
  -- later-generation identity relies on split Sp.Atk/Sp.Def or Fairy typing
  -- are adapted to the five-stat Kanto battle model while retaining their
  -- official species/form identity.
  local FORMS = {
    form("VENUSAUR", "VENUSAUR", "VENUSAURITE", "MEGA VENUSAUR", "hof", 5000,
      { attack = 10, defense = 35, speed = 5, special = 50 }),
    form("CHARIZARD", "CHARIZARD_X", "CHARIZARDITE_X", "MEGA CHARIZARD X", "hof", 7500,
      { attack = 45, defense = 25, speed = 10, special = 20 },
      { "FIRE", "DRAGON" }, "mega_charizard_x"),
    form("CHARIZARD", "CHARIZARD_Y", "CHARIZARDITE_Y", "MEGA CHARIZARD Y", "hof", 7500,
      { attack = 15, defense = 10, speed = 15, special = 60 }),
    form("BLASTOISE", "BLASTOISE", "BLASTOISINITE", "MEGA BLASTOISE", "hof", 5000,
      { attack = 15, defense = 30, speed = 5, special = 50 }),
    form("BEEDRILL", "BEEDRILL", "BEEDRILLITE", "MEGA BEEDRILL", "hof", 5000,
      { attack = 60, defense = 0, speed = 40, special = 0 }),
    form("PIDGEOT", "PIDGEOT", "PIDGEOTITE", "MEGA PIDGEOT", "hof", 5000,
      { attack = 10, defense = 10, speed = 30, special = 50 }),
    form("ALAKAZAM", "ALAKAZAM", "ALAKAZITE", "MEGA ALAKAZAM", "hof", 5000,
      { attack = 0, defense = 10, speed = 30, special = 60 }),
    form("SLOWBRO", "SLOWBRO", "SLOWBRONITE", "MEGA SLOWBRO", "hof", 5000,
      { attack = 0, defense = 60, speed = 0, special = 40 }),
    form("GENGAR", "GENGAR", "GENGARITE", "MEGA GENGAR", "hof", 5000,
      { attack = 0, defense = 15, speed = 35, special = 50 }),
    form("KANGASKHAN", "KANGASKHAN", "KANGASKHANITE", "MEGA KANGASKHAN", "hof", 5000,
      { attack = 40, defense = 25, speed = 25, special = 10 }),
    form("PINSIR", "PINSIR", "PINSIRITE", "MEGA PINSIR", "hof", 5000,
      { attack = 50, defense = 30, speed = 20, special = 0 }, { "BUG", "FLYING" }),
    form("GYARADOS", "GYARADOS", "GYARADOSITE", "MEGA GYARADOS", "hof", 5000,
      { attack = 40, defense = 25, speed = 15, special = 20 }, { "WATER", "DARK" }),
    form("AERODACTYL", "AERODACTYL", "AERODACTYLITE", "MEGA AERODACTYL", "hof", 5000,
      { attack = 30, defense = 25, speed = 35, special = 10 }),
    form("MEWTWO", "MEWTWO_X", "MEWTWONITE_X", "MEGA MEWTWO X", "apex", 15000,
      { attack = 60, defense = 20, speed = 10, special = 10 }, { "PSYCHIC", "FIGHTING" }),
    form("MEWTWO", "MEWTWO_Y", "MEWTWONITE_Y", "MEGA MEWTWO Y", "apex", 15000,
      { attack = 0, defense = 0, speed = 40, special = 60 }),
    form("AMPHAROS", "AMPHAROS", "AMPHAROSITE", "MEGA AMPHAROS", "hof", 5000,
      { attack = 0, defense = 20, speed = 0, special = 80 }, { "ELECTRIC", "DRAGON" }),
    form("STEELIX", "STEELIX", "STEELIXITE", "MEGA STEELIX", "hof", 5000,
      { attack = 10, defense = 60, speed = 0, special = 30 }),
    form("SCIZOR", "SCIZOR", "SCIZORITE", "MEGA SCIZOR", "hof", 5000,
      { attack = 40, defense = 30, speed = 10, special = 20 }),
    form("HERACROSS", "HERACROSS", "HERACRONITE", "MEGA HERACROSS", "hof", 5000,
      { attack = 60, defense = 20, speed = 0, special = 20 }),
    form("HOUNDOOM", "HOUNDOOM", "HOUNDOOMINITE", "MEGA HOUNDOOM", "hof", 5000,
      { attack = 20, defense = 0, speed = 30, special = 50 }),
    form("TYRANITAR", "TYRANITAR", "TYRANITARITE", "MEGA TYRANITAR", "hof", 5000,
      { attack = 30, defense = 35, speed = 0, special = 35 }),

    -- Newly discovered Pokémon Legends: Z-A forms within National Dex 1-251.
    form("CLEFABLE", "CLEFABLE", "CLEFABLITE", "MEGA CLEFABLE", "masters", 10000,
      { attack = 0, defense = 20, speed = 20, special = 60 }, { "NORMAL", "FLYING" }),
    form("VICTREEBEL", "VICTREEBEL", "VICTREEBELITE", "MEGA VICTREEBEL", "masters", 10000,
      { attack = 35, defense = 20, speed = 10, special = 35 }),
    form("STARMIE", "STARMIE", "STARMIENITE", "MEGA STARMIE", "masters", 10000,
      { attack = 30, defense = 10, speed = 30, special = 30 }),
    form("DRAGONITE", "DRAGONITE", "DRAGONINITE", "MEGA DRAGONITE", "masters", 10000,
      { attack = 35, defense = 20, speed = 25, special = 20 }),
    form("MEGANIUM", "MEGANIUM", "MEGANIUMITE", "MEGA MEGANIUM", "masters", 10000,
      { attack = 10, defense = 50, speed = 10, special = 30 },
      nil, nil, { quest = "chikorita" }),
    form("FERALIGATR", "FERALIGATR", "FERALIGATRITE", "MEGA FERALIGATR", "masters", 10000,
      { attack = 50, defense = 20, speed = 20, special = 10 },
      { "WATER", "DRAGON" }, nil, { quest = "totodile" }),
    form("SKARMORY", "SKARMORY", "SKARMORITE", "MEGA SKARMORY", "masters", 10000,
      { attack = 25, defense = 45, speed = 25, special = 5 }),

    -- Mega Dimension: two forms, two distinct stones.
    form("RAICHU", "RAICHU_X", "RAICHUNITE_X", "MEGA RAICHU X", "masters", 10000,
      { attack = 40, defense = 35, speed = 15, special = 10 }, nil,
      "mega_raichu_x"),
    form("RAICHU", "RAICHU_Y", "RAICHUNITE_Y", "MEGA RAICHU Y", "masters", 10000,
      { attack = 10, defense = 10, speed = 45, special = 35 }, nil,
      "mega_raichu_y"),

    -- Deliberately not an official Mega Evolution and never shown in the
    -- Mega Stone Case. The post-Gold Basalt Seal event unlocks this permanent
    -- Kanto Ascendant fan form after the complete 251-species Pokédex.
    form("TYPHLOSION", "TYPHLOSION_ASCENDANT", "BASALT_CORE",
      "ASCENDANT TYPHLOSION", "secret", 0,
      { attack = 30, defense = 30, speed = 15, special = 25 },
      { "FIRE", "GROUND" }, "ascendant_typhlosion",
      { secret = true, secretHealing = 0.25 }),
  }

  local FORMS_BY_ID, FORMS_BY_SPECIES, FORM_BY_STONE = {}, {}, {}
  local OFFICIAL_BY_SPECIES = {}
  local OFFICIAL_FORMS, SECRET_FORMS = {}, {}
  local megaBattleScale = { front = 1, back = 1 }
  for _, profile in ipairs(FORMS) do
    FORMS_BY_ID[profile.id] = profile
    FORM_BY_STONE[profile.stone] = profile
    if profile.secret then
      SECRET_FORMS[#SECRET_FORMS + 1] = profile
    else
      OFFICIAL_FORMS[#OFFICIAL_FORMS + 1] = profile
      local officialRows = OFFICIAL_BY_SPECIES[profile.species] or {}
      officialRows[#officialRows + 1] = profile
      OFFICIAL_BY_SPECIES[profile.species] = officialRows
    end
    local rows = FORMS_BY_SPECIES[profile.species] or {}
    rows[#rows + 1] = profile
    FORMS_BY_SPECIES[profile.species] = rows
  end

  local BOSS_CLASSES = {
    OPP_BROCK = true, OPP_MISTY = true, OPP_LT_SURGE = true,
    OPP_ERIKA = true, OPP_KOGA = true, OPP_SABRINA = true,
    OPP_BLAINE = true, OPP_GIOVANNI = true, OPP_LORELEI = true,
    OPP_BRUNO = true, OPP_AGATHA = true, OPP_LANCE = true,
    OPP_RIVAL3 = true, OPP_PROF_OAK = true,
  }
  local JOHTO_MEGA_SPECIES = {
    AMPHAROS = true, STEELIX = true, SCIZOR = true, HERACROSS = true,
    HOUNDOOM = true, TYRANITAR = true, MEGANIUM = true, FERALIGATR = true,
    SKARMORY = true, TYPHLOSION = true,
  }
  local refreshSprite
  local voxelWantsFront = function() return false end

  local function isShiny(mon)
    if type(mon) ~= "table" then return false end
    if mon.shiny == true then return true end
    local ok, Stats = pcall(require, "src.pokemon.Stats")
    return ok and Stats and Stats.isShiny
      and Stats.isShiny(mon.dvs) or false
  end

  local function animationVariant(profile, mon)
    local data = profile and animationData[profile.id]
    if type(data) ~= "table" then return nil end
    local sideAware = type(data.front) == "table"
      or type(data.back) == "table"
    local variants = sideAware and (data.front or data.back) or data
    if isShiny(mon) and type(variants.shiny) == "table" then return "shiny" end
    return type(variants.normal) == "table" and "normal" or nil
  end

  local function crystalMegaArtEnabled(profile)
    if not profile then return false end
    if JOHTO_MEGA_SPECIES[profile.species] then
      return mod.options:get("legend_art") == "crystal"
    end
    return mod.options:get("kanto_crystal_art") ~= false
  end

  local function megaMotionEnabled(profile)
    return crystalMegaArtEnabled(profile)
      and mod.options:get("crystal_animation") ~= false
  end

  local function animationSpec(profile, mon, battler)
    if not megaMotionEnabled(profile) then return nil end
    local data = profile and animationData[profile.id]
    local variant = animationVariant(profile, mon)
    if not (variant and type(data) == "table") then return nil end
    local side = mon and mon._ascMegaAnimationSide
      or (battler and battler.isPlayer and "back" or "front")
    if type(data[side]) == "table"
        and type(data[side][variant]) == "table" then
      return variant, data[side][variant], side
    end
    return variant, data[variant], nil
  end

  local function animationRelativePath(profile, variant, frame, side)
    local branch = side and (side .. "/" .. variant) or variant
    return ("assets/mega_animated_runtime/%s/%s/%03d.png"):format(
      profile.asset, branch, frame or 1)
  end

  local function animationMasterRelativePath(profile, variant, frame, side)
    local branch = side and (side .. "/" .. variant) or variant
    return ("assets/mega_animated/%s/%s/%03d.png"):format(
      profile.asset, branch, frame or 1)
  end

  local function updateMegaBattler(battle, battler, dt)
    local mon = battler and battler.mon
    local profile = mon and FORMS_BY_ID[mon._ascMegaForm]
    local variant, timings, pathSide = animationSpec(profile, mon, battler)
    if not (profile and profile.asset and timings and #timings > 1) then
      if battler then battler.__ascendantMegaAnimation = nil end
      return
    end
    local state = battler.__ascendantMegaAnimation
    if not state or state.form ~= profile.id or state.variant ~= variant
        or state.pathSide ~= pathSide then
      state = {
        form = profile.id, variant = variant, timings = timings,
        pathSide = pathSide, frame = 1, elapsed = 0, image = battler.sprite,
      }
      battler.__ascendantMegaAnimation = state
    elseif state.image and battler.sprite ~= state.image then
      -- A later renderer or another form change now owns this battler.
      battler.__ascendantMegaAnimation = nil
      return
    end
    state.elapsed = state.elapsed + (tonumber(dt) or (1 / 60)) * 1000
    local changed, guard = false, 0
    while state.elapsed >= (state.timings[state.frame] or 100)
        and guard < 50 do
      state.elapsed = state.elapsed - (state.timings[state.frame] or 100)
      state.frame = state.frame + 1
      if state.frame > #state.timings then state.frame = 1 end
      changed, guard = true, guard + 1
    end
    if not changed then return end
    local rel = animationRelativePath(
      profile, variant, state.frame, pathSide)
    if mod:read(rel) then
      -- Rebuild through BattleState's own image loader rather than assigning
      -- a raw love.Image. That preserves source-path, ground-padding and
      -- true-colour metadata for classic scaling, fades and Voxel filling.
      mon._ascMegaAnimationFrame = state.frame
      refreshSprite(battle, battler)
      state.image = battler.sprite
    end
  end

  local function updateMegaAnimations(battle, dt)
    if not battle then return end
    if battle.enemy and not battle.showEnemyTrainer
        and not battle.enemySendingOut then
      updateMegaBattler(battle, battle.enemy, dt)
    end
    if battle.player and not battle.showPlayerBack and not battle.sendingOut then
      updateMegaBattler(battle, battle.player, dt)
    end
  end

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function stoneName(profile)
    if profile and profile.secret then return tr("BASALT CORE", "BASALT-KERN") end
    return profile.stone:gsub("_", " ")
  end

  local function caseLabel(profile)
    local suffix = profile.id:match("_([XY])$")
    return profile.species:gsub("_", "-") .. (suffix and (" " .. suffix) or "")
  end

  local function state(create)
    local s = mod.save:get("mega_evolution")
    if type(s) ~= "table" and create ~= false then
      s = {
        version = 3, ring = false, case = false, stones = {},
        preferences = {}, activations = 0, secretUnlocked = false,
        secretActivations = 0,
      }
      mod.save:set("mega_evolution", s)
    end
    if type(s) == "table" then
      s.version = 3
      s.stones = type(s.stones) == "table" and s.stones or {}
      s.preferences = type(s.preferences) == "table" and s.preferences or {}
      -- 3.1 preview migration: it never granted individual stones, so keep
      -- the Ring but require the new form-specific stones from now on.
      if s.raichuForm and not s.preferences.RAICHU then
        s.preferences.RAICHU = s.raichuForm == "y" and "RAICHU_Y"
          or (s.raichuForm == "x" and "RAICHU_X" or nil)
      end
      s.raichuForm = nil
      s.activations = math.max(0, math.floor(tonumber(s.activations) or 0))
      s.secretUnlocked = s.secretUnlocked == true
      s.secretActivations = math.max(0,
        math.floor(tonumber(s.secretActivations) or 0))
    end
    return s
  end

  local function persist(s)
    if s then mod.save:set("mega_evolution", s) end
  end

  local function optionEnabled()
    return enabled and mod.options:get("mega_evolution") ~= false
  end

  local function masterCount()
    local ps = postgame and postgame.state and postgame.state() or {}
    local count = 0
    for _, won in pairs(ps.masterWins or {}) do
      if won then count = count + 1 end
    end
    return count
  end

  local function tierAvailable(game, tier)
    if not (postgame and postgame.hasHallOfFame(game.save)) then return false end
    if tier == "hof" then return true end
    local ps = postgame.state and postgame.state() or {}
    if tier == "masters" then
      return masterCount() >= 8 or ps.apexChampion or ps.crownChampion
    end
    return ps.apexChampion or ps.crownChampion
  end

  local function ownedProfiles(species, enemy)
    local rows = FORMS_BY_SPECIES[species]
    if not rows then return {} end
    local s, out = state(), {}
    for _, profile in ipairs(rows) do
      if profile.secret then
        if not enemy and s.secretUnlocked then out[#out + 1] = profile end
      elseif enemy or s.stones[profile.stone] then
        out[#out + 1] = profile
      end
    end
    return out
  end

  local function directPartnerMega(mon, enemy)
    return enemy ~= true and yellowPartner
      and type(yellowPartner.megaEligible) == "function"
      and yellowPartner.megaEligible(mon) == true
  end

  local function preferredProfile(mon, enemy)
    local profileSpecies = directPartnerMega(mon, enemy)
      and "RAICHU" or mon.species
    local rows = ownedProfiles(profileSpecies, enemy)
    if #rows == 0 then return nil end
    local preferred = state().preferences[profileSpecies]
    for _, profile in ipairs(rows) do
      if profile.id == preferred then return profile end
    end
    if profileSpecies == "RAICHU" and #rows > 1 then
      local stats = mon.stats or {}
      local id = (stats.attack or 0) >= (stats.special or 0)
        and "RAICHU_X" or "RAICHU_Y"
      for _, profile in ipairs(rows) do
        if profile.id == id then return profile end
      end
    end
    return rows[1]
  end

  local function boostedStats(battler, profile)
    profile = type(profile) == "table" and profile or FORMS_BY_ID[profile]
    if not profile then return battler.curStats end
    local source = battler.curStats or battler.mon.stats or {}
    if profile.species == "RAICHU"
        and directPartnerMega(battler.mon, false)
        and M.game and M.game.data and M.game.data.pokemon
        and M.game.data.pokemon.RAICHU then
      local ok, Stats = pcall(require, "src.pokemon.Stats")
      if ok and Stats and Stats.calc then
        local raichu = Stats.calc(
          M.game.data.pokemon.RAICHU,
          battler.mon.level, battler.mon.dvs, battler.mon.statExp)
        -- Direct resonance replaces Pikachu's offensive/defensive base with
        -- Raichu's before applying the official Mega profile. HP stays on
        -- the real Pikachu instance so transforming cannot heal, damage or
        -- desynchronise its in-battle health bar.
        raichu.hp = source.hp
        source = raichu
      end
    end
    local out = {}
    for key, value in pairs(source) do out[key] = value end
    local level = math.max(1, math.min(100, tonumber(battler.mon.level) or 1))
    for key, baseGain in pairs(profile.bonuses) do
      out[key] = math.min(999,
        math.max(1, (tonumber(source[key]) or 1)
          + math.floor(2 * baseGain * level / 100)))
    end
    return out
  end

  refreshSprite = function(battle, battler)
    local data = battle and (battle.data
      or (battle.game and battle.game.data))
    if not (data and battler and battler.mon) then return false end
    local BattleState = require("src.battle.BattleState")
    local fresh = BattleState.makeBattler(
      data, battler.mon, battler.isPlayer,
      battler.isPlayer and battle.game.save or nil)
    if fresh and fresh.sprite then battler.sprite = fresh.sprite end
    return fresh and fresh.sprite ~= nil
  end

  local function applyNow(battle, battler, side, profile)
    if not (battle and battler and battler.mon and profile) then return end
    battler.mon._ascMegaForm = profile.id
    battler.mon._ascMegaAnimationFrame = nil
    battler._ascMegaForm = profile.id
    battler._ascMegaProfile = profile
    battler.__ascendantMegaAnimation = nil
    battler.curStats = boostedStats(battler, profile)
    if profile.types then battler.curTypes = profile.types end
    if profile.secret and profile.secretHealing then
      local healedKey = side == "player" and "_ascSecretPlayerHealed"
        or "_ascSecretEnemyHealed"
      if not battle[healedKey] then
        local maximum = tonumber(battler.mon.stats and battler.mon.stats.hp)
          or tonumber(battler.mon.hp) or 1
        local amount = math.max(1, math.floor(maximum * profile.secretHealing))
        battler.mon.hp = math.min(maximum,
          math.max(0, tonumber(battler.mon.hp) or 0) + amount)
        battler.shownHP = battler.mon.hp
        battle[healedKey] = true
      end
    end
    refreshSprite(battle, battler)
    if side == "player" then
      battle._ascMegaPlayerMon = battler.mon
      battle._ascMegaPlayerProfile = profile
    else
      battle._ascMegaEnemyMon = battler.mon
      battle._ascMegaEnemyProfile = profile
    end
  end

  local function queueActivation(battle, battler, side, profile)
    local usedKey = side == "player" and "_ascMegaPlayerUsed"
      or "_ascMegaEnemyUsed"
    if battle[usedKey] then return false, "used" end
    battle[usedKey] = true
    local owner = side == "player"
      and (battle.game.save.player and battle.game.save.player.name or "PLAYER")
      or (battle.trainer and battle.trainer.name or "FOE")
    local activation = profile.secret and tr(
      ("%s's BASALT CORE\nsplit with a roar!\fCyan fire sealed\n%s's wounds.\f%s awakened as\nASCENDANT\nTYPHLOSION!"):format(
        owner, battler.name, battler.name),
      ("%ss BASALT-KERN\nbricht mit einem Ruf!\fCyanes Feuer schließt\n%s Wunden.\f%s erwacht als\nASCENDANT-\nTORNUPTO!"):format(
        owner, battler.name, battler.name))
      or tr(
        ("%s's KEY STONE\nresonated with\n%s!\f%s became\n%s!"):format(
          owner, stoneName(profile), battler.name, profile.label),
        ("%ss SCHLÜSSEL-STEIN\nreagiert mit\n%s!\f%s wird zu\n%s!"):format(
          owner, stoneName(profile), battler.name, profile.label))
    battle:say(activation)
    battle:act(function()
      applyNow(battle, battler, side, profile)
      local s = state()
      s.activations = s.activations + 1
      if profile.secret then
        s.secretActivations = s.secretActivations + 1
      end
      persist(s)
    end)
    battle.phase = "messages"
    battle.afterQueue = "menu"
    return true
  end

  local function cleanupBattle(battle)
    for _, mon in ipairs({
      battle and battle._ascMegaPlayerMon,
      battle and battle._ascMegaEnemyMon,
    }) do
      if mon then
        mon._ascMegaForm = nil
        mon._ascMegaAnimationSide = nil
        mon._ascMegaAnimationFrame = nil
      end
    end
    for _, battler in ipairs({
      battle and battle.player,
      battle and battle.enemy,
    }) do
      if battler then battler.__ascendantMegaAnimation = nil end
    end
  end

  local function eligibleOpponent(battle)
    local mode = mod.options:get("mega_opponents") or "bosses"
    if mode == "off" or battle.kind ~= "trainer" then return false end
    if mode == "all" then return true end
    return BOSS_CLASSES[battle.oppClass] == true
      or (battle.enemy and battle.enemy.mon and battle.enemy.mon.level >= 80)
  end

  local function stoneStatus(profile, game)
    if state().stones[profile.stone] then return tr("OWN", "HAT") end
    if profile.quest then return tr("QUEST", "AUFG.") end
    if not tierAvailable(game, profile.tier) then return tr("LOCK", "SPERR") end
    return ("¥%d"):format(profile.cost)
  end

  local function stoneDetails(profile, game)
    local requirement = profile.quest == "chikorita" and tr(
      "Complete CHIKORITA'S\nSTARTER RELIC quest.",
      "Beende ENDIVIES\nSTARTER-RELIKT-Mission.")
      or (profile.quest == "totodile" and tr(
        "Complete TOTODILE'S\nSTARTER RELIC quest.",
        "Beende KARNIMANIS\nSTARTER-RELIKT-Mission.")
      or (profile.tier == "masters"
      and tr("Defeat all eight\nMaster Leaders first.",
             "Besiege erst alle acht\nMaster-Leiter.")
      or (profile.tier == "apex"
        and tr("Defeat the Apex\nChampion first.",
               "Besiege erst den\nApex-Champ.")
        or tr("Available after the\nfirst Hall of Fame.",
              "Nach der ersten\nRuhmeshalle verfügbar."))))
    return ("%s\f%s\f%s"):format(
      profile.label, stoneName(profile), requirement)
  end

  function M.available(game)
    return optionEnabled() and game and postgame
      and postgame.hasHallOfFame(game.save)
  end

  function M.hasRing()
    local s = state(false)
    return s and s.ring == true
  end

  function M.unlock(game)
    local s = state()
    if s.ring then
      return tr("The MEGA RING and\nSTONE CASE are ready.",
                "MEGA-RING und\nSTEIN-KOFFER sind bereit.")
    end
    s.ring, s.case = true, true
    persist(s)
    game.save.inventory = game.save.inventory or {}
    require("src.inventory.Bag").add(game.save, "MEGA_RING", 1, game.data)
    require("src.inventory.Bag").add(game.save, "MEGA_STONE_CASE", 1, game.data)
    return tr(
      "The machine forged a\nMEGA RING!\fIt also registered a\nMEGA STONE CASE.\fForge a matching stone,\nthen press SELECT\nin battle.",
      "Die Maschine erzeugt\neinen MEGA-RING!\fDazu kommt ein\nMEGA-STEIN-KOFFER.\fErzeuge den passenden\nStein und drücke im\nKampf SELECT.")
  end

  function M.stoneMenu(game, done)
    local rows = {}
    for index, profile in ipairs(FORMS) do
      if not profile.secret then
        rows[#rows + 1] = {
          label = caseLabel(profile),
          right = stoneStatus(profile, game),
          value = index,
        }
      end
    end
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("MEGA STONE CASE", "MEGA-STEIN-KOFFER"), rows, {
        pageJump = true,
        onCancel = done,
        onChoose = function(item)
          local profile = FORMS[item.value]
          local s = state()
          if s.stones[profile.stone] then
            game.stack:push(require("src.render.TextBox").new(
              game, stoneDetails(profile, game)))
            return
          end
          if profile.quest then
            game.stack:push(require("src.render.TextBox").new(
              game, stoneDetails(profile, game)))
            return
          end
          if not tierAvailable(game, profile.tier) then
            game.stack:push(require("src.render.TextBox").new(
              game, stoneDetails(profile, game)))
            return
          end
          local prompt = tr(
            ("%s costs ¥%d.\fFORGE THIS STONE?"):format(
              stoneName(profile), profile.cost),
            ("%s kostet ¥%d.\fDIESEN STEIN ERZEUGEN?"):format(
              stoneName(profile), profile.cost))
          game.stack:push(require("src.render.TextBox").new(game, prompt, nil, {
            choice = function(yes)
              if not yes then return end
              if (game.save.money or 0) < profile.cost then
                game.stack:push(require("src.render.TextBox").new(game, tr(
                  "You don't have\nenough money.",
                  "Du hast nicht\ngenug Geld.")))
                return
              end
              game.save.money = game.save.money - profile.cost
              s.stones[profile.stone] = true
              persist(s)
              item.right = tr("OWN", "HAT")
              game.stack:push(require("src.render.TextBox").new(game, tr(
                ("%s was added to\nthe MEGA STONE CASE!"):format(stoneName(profile)),
                ("%s liegt jetzt im\nMEGA-STEIN-KOFFER!"):format(stoneName(profile)))))
            end,
          }))
        end,
      }))
  end

  function M.formMenu(game, done)
    local rows = {}
    for _, species in ipairs({ "CHARIZARD", "MEWTWO", "RAICHU" }) do
      local profiles = FORMS_BY_SPECIES[species]
      local owned = {}
      for _, profile in ipairs(profiles) do
        if state().stones[profile.stone] then owned[#owned + 1] = profile end
      end
      if #owned > 1 then
        local preferred = state().preferences[species] or owned[1].id
        rows[#rows + 1] = {
          label = species, right = preferred:match("_([XY])$") or "X",
          value = species,
        }
      end
    end
    if #rows == 0 then
      game.stack:push(require("src.render.TextBox").new(game, tr(
        "Own both X and Y\nstones for a species\nto choose its form.",
        "Besitze beide X- und\nY-Steine einer Art,\num die Form zu wählen."), done))
      return
    end
    game.stack:push(mod.ui.ListMenu.new(game,
      tr("MEGA FORM", "MEGA-FORM"), rows, {
        onCancel = done,
        onChoose = function(item)
          local species = item.value
          local owned = ownedProfiles(species, false)
          local s = state()
          local current = s.preferences[species]
          local nextProfile = owned[1]
          for index, profile in ipairs(owned) do
            if profile.id == current then
              nextProfile = owned[index % #owned + 1]
              break
            end
          end
          s.preferences[species] = nextProfile.id
          persist(s)
          item.right = nextProfile.id:match("_([XY])$") or "X"
          game.stack:push(require("src.render.TextBox").new(game, tr(
            ("%s will use\n%s."):format(species, nextProfile.label),
            ("%s nutzt\n%s."):format(species, nextProfile.label))))
        end,
      }))
  end

  function M.guide()
    local official = tr(
      "Only official Mega\nspecies are eligible.\fEvery form needs its\nmatching Mega Stone.\fSELECT on the battle\nmenu transforms once\nper side.\fMEGANIUM and FERALIGATR\nstones come from their\nSTARTER RELIC quests.\fOther new Z-A stones\nfollow the Master Leaders;\nMewtwo after Apex.",
      "Nur offizielle Mega-\nArten sind zugelassen.\fJede Form braucht ihren\npassenden Mega-Stein.\fSELECT im Kampfmenü\nverwandelt einmal\npro Seite.\fMEGANIE- und IMPERGATOR-\nSteine stammen aus ihren\nSTARTER-RELIKT-Missionen.\fAndere neue Z-A-Steine\nfolgen den Master-Leitern;\nMewtu nach Apex.")
    if not state().secretUnlocked then return official end
    return official .. tr(
      "\fThe BASALT CORE is a\nseparate Ascendant relic.\fTYPHLOSION becomes\nFIRE/GROUND and mends\n25% HP when awakened.",
      "\fDer BASALT-KERN ist ein\neigenes Ascendant-Relikt.\fTORNUPTO wird\nFEUER/BODEN und heilt\nbeim Erwachen 25% KP.")
  end

  function M.activate(battle, battler, side)
    if not optionEnabled() then return false, "disabled" end
    if not battler or not battler.mon or battler.mon.isEgg then
      return false, "invalid"
    end
    local secretReady = battler.mon.species == "TYPHLOSION"
      and state().secretUnlocked
    if side == "player" and not M.hasRing() and not secretReady then
      return false, "locked"
    end
    if battler.mon.species == "TYPHLOSION" and not secretReady then
      return false, "ineligible"
    end
    local partnerMega = side == "player"
      and directPartnerMega(battler.mon, false)
    if not FORMS_BY_SPECIES[battler.mon.species] and not partnerMega then
      return false, "ineligible"
    end
    -- The Basalt Core remains player-only in the real game. The isolated
    -- screenshot driver may explicitly stage the secret form as an enemy so
    -- release galleries can compare every form from the same front-facing
    -- side; no gameplay path ever sets this private battle flag.
    local qaSecretEnemy = side == "enemy"
      and battle and battle._ascendantQaAllowSecretEnemy == true
      and battler.mon.species == "TYPHLOSION" and secretReady
    local profile = qaSecretEnemy and FORMS_BY_ID.TYPHLOSION_ASCENDANT
      or preferredProfile(battler.mon, side ~= "player")
    if not profile then return false, "stone" end
    return queueActivation(battle, battler, side, profile)
  end

  local function installVoxelCompatibility(game)
    local exports = game and game.mods and game.mods.exports
    local dramatic = exports and exports.DRAMATIC_SHAPE
    if not (dramatic and dramatic.lib and dramatic.lib.require) then return end
    local okBattle, overworldBattle = pcall(
      dramatic.lib.require, "OverworldBattle")
    if not (okBattle and overworldBattle) then return end
    voxelWantsFront = function()
      local ok, value = pcall(overworldBattle.wantsFront)
      return ok and value == true
    end

    -- Dramatic Shape normally captures a 60px battle card into a 160x144
    -- canvas. Reusing that capture here would make the Voxel renderer enlarge
    -- an image that has already been reduced from the approved 96px master.
    -- Mega cards instead get a supersampled side texture: the 96px master is
    -- drawn at 1:1 onto a 230x207 canvas while occupying a 66.8px physical
    -- battle footprint. The world-size math remains unchanged, but the
    -- camera receives all authored pixels instead of a twice-resampled card.
    if not overworldBattle.kantoAscendantMegaAnchorHook then
      local innerSideTexture = overworldBattle.sideTexture
      local voxelCanvases, voxelImages = {}, {}
      -- 230:207 is exactly the GB frame's 160:144 aspect ratio. With the
      -- untouched 96px master inside it, the form occupies 66.8 logical
      -- pixels: a small but visible step above a normal 56px battle pic.
      local VOXEL_SCALE = 1.4375
      local VOXEL_W, VOXEL_H = 230, 207
      local MASTER_CARD = 96

      local function masterPath(profile, mon, side)
        if crystalMegaArtEnabled(profile) then
          local variant = animationVariant(profile, mon)
          local frame = tonumber(mon and mon._ascMegaAnimationFrame)
          if megaMotionEnabled(profile) and frame and variant then
            local animated = animationMasterRelativePath(
              profile, variant, frame, side)
            if mod:read(animated) then return animated, false end
          end
          local suffix = isShiny(mon) and "_shiny" or ""
          local static = ("assets/mega/%s_%s%s.png"):format(
            profile.asset, side, suffix)
          return mod:read(static) and static or nil, false
        end
        local suffix = isShiny(mon) and "_shiny" or ""
        local static = ("assets/mega_gen1_runtime/%s_%s%s.png"):format(
          profile.asset, side, suffix)
        return mod:read(static) and static or nil, true
      end

      local function paletteSignature(palette)
        if type(palette) ~= "table" then return "gray" end
        local parts = {}
        for index = 1, 4 do
          local color = palette[index] or {}
          parts[#parts + 1] = table.concat({
            tostring(color[1] or 0),
            tostring(color[2] or 0),
            tostring(color[3] or 0),
          }, ",")
        end
        return table.concat(parts, ";")
      end

      local function imageFor(relative, palette)
        local key = relative .. "#" .. paletteSignature(palette)
        local image = voxelImages[key]
        if image then return image end
        local loaded
        if palette and love.image and love.image.newImageData then
          local okData, imageData = pcall(
            love.image.newImageData, mod.path .. "/" .. relative)
          if okData and imageData then
            imageData:mapPixel(function(_, _, red, green, blue, alpha)
              if alpha == 0 then return red, green, blue, alpha end
              local color = red > 0.83 and palette[1]
                or red > 0.5 and palette[2]
                or red > 0.17 and palette[3] or palette[4]
              return color[1] / 255, color[2] / 255, color[3] / 255, alpha
            end)
            local okImage, mapped = pcall(love.graphics.newImage, imageData)
            if okImage then loaded = mapped end
          end
        end
        local ok
        if not loaded then
          ok, loaded = pcall(
            love.graphics.newImage, mod.path .. "/" .. relative)
        else
          ok = true
        end
        if not (ok and loaded) then return nil end
        if loaded.setFilter then loaded:setFilter("nearest", "nearest") end
        voxelImages[key] = loaded
        return loaded
      end

      local function canvasFor(side)
        local canvas = voxelCanvases[side]
        if canvas then return canvas end
        local ok, made = pcall(love.graphics.newCanvas,
          VOXEL_W, VOXEL_H, { dpiscale = 1 })
        if not (ok and made) then return nil end
        if made.setFilter then made:setFilter("nearest", "nearest") end
        voxelCanvases[side] = made
        return made
      end

      local function supersampledTexture(texture, battler, profile, side)
        if not (love and love.graphics and texture and battler and profile)
            then return texture end
        -- A staged Voxel fight presents both monsters to the camera. The
        -- player's near-side card is mirrored in world space, not replaced
        -- by its classic rear drawing.
        local artSide = "front"
        local relative, gen1 = masterPath(profile, battler.mon, artSide)
        local palette
        if gen1 then
          local okPalette, PaletteFX = pcall(
            require, "src.render.PaletteFX")
          if okPalette and PaletteFX and PaletteFX.monPal then
            palette = PaletteFX.monPal(
              game.data, battler.mon.species)
          end
        end
        local image = relative and imageFor(relative, palette)
        local canvas = image and canvasFor(side)
        if not canvas then return texture end

        local g = love.graphics
        local previousCanvas = g.getCanvas()
        local previousBlend, previousAlpha = g.getBlendMode()
        local r, green, b, a = g.getColor()
        local ok = pcall(function()
          g.setCanvas(canvas)
          g.clear(0, 0, 0, 0)
          g.setBlendMode("alpha")
          g.setColor(1, 1, 1, 1)
          local width, height = image:getDimensions()
          local drawScale = MASTER_CARD / math.max(width, height)
          local drawWidth, drawHeight =
            width * drawScale, height * drawScale
          local centerX = VOXEL_W / 2
          local baselineY = 96 * VOXEL_SCALE
          g.draw(image, centerX - drawWidth / 2,
            baselineY - drawHeight, 0, drawScale, drawScale)
        end)
        if previousCanvas then g.setCanvas(previousCanvas)
        else g.setCanvas() end
        g.setBlendMode(previousBlend or "alpha", previousAlpha)
        g.setColor(r or 1, green or 1, b or 1, a or 1)
        if not ok then return texture end

        texture.canvas = canvas
        texture.kantoAscendantMegaSupersampled = true
        texture.kantoAscendantMegaSource = relative
        return texture
      end

      overworldBattle.sideTexture = function(battle, side)
        local texture = innerSideTexture(battle, side)
        local battler = battle
          and (side == "enemy" and battle.enemy or battle.player)
        local profile = battler and battler.mon
          and FORMS_BY_ID[battler.mon._ascMegaForm]
        if texture and profile then
          texture = supersampledTexture(texture, battler, profile, side)
          if side == "enemy" then
            texture.ax = (texture.ax or 80) + 8
            texture.ay = (texture.ay or 96) - 8
          end
        end
        return texture
      end
      overworldBattle.kantoAscendantMegaAnchorHook = true
    end
  end

  function M.install(game, deps)
    M.game = game
    state()
    installVoxelCompatibility(game)
    deps = deps or {}
    local BattleState = deps.battleState or require("src.battle.BattleState")
    if BattleState._ascendantMegaWrapped then return end
    BattleState._ascendantMegaWrapped = true

    local vanillaUpdate = BattleState.update
    BattleState.update = function(battle, dt)
      if battle.phase == "menu" and not battle.demo and not battle.safari then
        if battle._ascMegaEnemyPending and not battle._ascMegaEnemyUsed then
          local ok = M.activate(battle, battle.enemy, "enemy")
          if ok then
            battle._ascMegaEnemyPending = nil
            updateMegaAnimations(battle, dt)
            return
          end
        end
        local input = battle.game and battle.game.input
        if input and input:wasPressed("select") then
          local ok, reason = M.activate(battle, battle.player, "player")
          if ok then
            updateMegaAnimations(battle, dt)
            return
          end
          local message
          if reason == "locked" then
            message = tr(
              "The Route 5 machine\nhas not made your\nMEGA RING yet.",
              "Die Route-5-Maschine\nhat deinen MEGA-RING\nnoch nicht erzeugt.")
          elseif reason == "ineligible" then
            message = tr(
              "This species has no\nofficial Mega Evolution.",
              "Diese Art hat keine\noffizielle Mega-Entwicklung.")
          elseif reason == "stone" then
            message = tr(
              "Its matching Mega\nStone is missing from\nthe STONE CASE.",
              "Der passende Mega-Stein\nfehlt im STEIN-KOFFER.")
          end
          if message then
            battle:say(message)
            battle.phase = "messages"
            battle.afterQueue = "menu"
            updateMegaAnimations(battle, dt)
            return
          end
        end
      end
      local result = vanillaUpdate(battle, dt)
      updateMegaAnimations(battle, dt)
      return result
    end

    local vanillaFinish = BattleState.finish
    BattleState.finish = function(battle)
      cleanupBattle(battle)
      return vanillaFinish(battle)
    end
  end

  mod.content.items:register("MEGA_RING", {
    id = "MEGA_RING", name = tr("MEGA RING", "MEGA-RING"),
    price = 0, tossable = false, needsTarget = false,
  })
  mod.content.items:register("MEGA_STONE_CASE", {
    id = "MEGA_STONE_CASE", name = tr("MEGA STONE CASE", "MEGA-STEIN-KOFFER"),
    price = 0, tossable = false, needsTarget = false,
  })
  -- Approved art is retained as 96px master material. Runtime fronts are
  -- crisp 66x60 cards with at most 64x56 visible pixels. Player backs use a
  -- separate 90x84 card with at most 88x80 visible pixels. It intentionally
  -- extends under the player HUD, which is redrawn above active Mega rear art
  -- below. Classic 2D consumes these palette-locked cards; Dramatic Shape
  -- receives the full
  -- master through the supersampled Voxel compatibility path below.
  local function registerBattleScale(id, path, scale)
    mod.content.battle_sprite_scales:register(id, {
      path = path,
      scale = scale,
    })
  end

  for _, profile in ipairs(FORMS) do
    if not profile.secret then
      mod.content.items:register(profile.stone, {
        id = profile.stone, name = stoneName(profile),
        price = 0, tossable = false, needsTarget = false,
      })
    end
    if profile.asset then
      for _, side in ipairs({ "front", "back" }) do
        for _, suffix in ipairs({ "", "_shiny" }) do
          registerBattleScale(
            "KANTO_ASCENDANT_" .. profile.id .. "_"
              .. side:upper() .. (suffix == "" and "" or "_SHINY"),
            mod.path .. "/assets/mega_runtime/" .. profile.asset
              .. "_" .. side .. suffix .. ".png",
            megaBattleScale[side])
          registerBattleScale(
            "KANTO_ASCENDANT_GEN1_" .. profile.id .. "_"
              .. side:upper() .. (suffix == "" and "" or "_SHINY"),
            mod.path .. "/assets/mega_gen1_runtime/" .. profile.asset
              .. "_" .. side .. suffix .. ".png",
            megaBattleScale[side])
        end
        local timingSide = animationData[profile.id]
          and animationData[profile.id][side]
        if type(timingSide) == "table" then
          for _, variant in ipairs({ "normal", "shiny" }) do
            local timings = timingSide[variant]
            if type(timings) == "table" then
              for frame = 1, #timings do
                registerBattleScale(
                  ("KANTO_ASCENDANT_%s_%s_%s_FRAME_%03d"):format(
                    profile.id, side:upper(), variant:upper(), frame),
                  ("%s/assets/mega_animated_runtime/%s/%s/%s/%03d.png"):format(
                    mod.path, profile.asset, side, variant, frame),
                  megaBattleScale[side])
              end
            end
          end
        end
      end
    end
  end

  -- Run outside Crystal Animated Sprites' priority-930 resolver. That mod
  -- intentionally owns ordinary Kanto art without calling lower wrappers;
  -- an active official Mega form must still win after its Crystal result.
  mod.hooks:wrap("pokemon.sprite", function(nextSprite, path, ctx)
    path = nextSprite(path, ctx)
    local profile = ctx and ctx.mon and FORMS_BY_ID[ctx.mon._ascMegaForm]
    if not (profile and profile.asset) then return path end
    local side = ctx.side == "back" and "back" or "front"
    if side == "back" and voxelWantsFront() then side = "front" end
    if ctx.kind == "battle" then
      ctx.mon._ascMegaAnimationSide = side
    end
    local crystalArt = crystalMegaArtEnabled(profile)
    local root = crystalArt and "assets/mega_runtime/"
      or "assets/mega_gen1_runtime/"
    local base = root .. profile.asset .. "_" .. side
    local shiny = isShiny(ctx.mon) and mod:read(base .. "_shiny.png")
    local candidate = base .. (shiny and "_shiny" or "") .. ".png"
    local frame = tonumber(ctx.mon._ascMegaAnimationFrame)
    local variant = animationVariant(profile, ctx.mon)
    if megaMotionEnabled(profile) and frame and variant then
      local animated = animationRelativePath(
        profile, variant, frame, side)
      if mod:read(animated) then candidate = animated end
    elseif not crystalArt then
      ctx.mon._ascMegaAnimationFrame = nil
    end
    if not mod:read(candidate) then return path end
    ctx.trueColor = crystalArt
    return mod.path .. "/" .. candidate
  end, 990)

  local rearOverlayImages = {}

  local function rearOverlayImage(profile, mon, liveImage)
    if liveImage then return liveImage end
    local crystalArt = crystalMegaArtEnabled(profile)
    local variant = crystalArt and animationVariant(profile, mon)
    local frame = tonumber(mon and mon._ascMegaAnimationFrame)
    local relative
    if megaMotionEnabled(profile) and frame and variant then
      relative = animationRelativePath(profile, variant, frame, "back")
      if not mod:read(relative) then relative = nil end
    end
    if not relative then
      local suffix = isShiny(mon) and "_shiny" or ""
      local root = crystalArt and "assets/mega_runtime"
        or "assets/mega_gen1_runtime"
      relative = ("%s/%s_back%s.png"):format(root, profile.asset, suffix)
    end
    local image = rearOverlayImages[relative]
    if image then return image end
    local ok, loaded = pcall(
      love.graphics.newImage, mod.path .. "/" .. relative)
    if not (ok and loaded) then return nil end
    if loaded.setFilter then loaded:setFilter("nearest", "nearest") end
    rearOverlayImages[relative] = loaded
    return loaded
  end

  mod.hooks:wrap("battle.overlay", function(nextOverlay, battle)
    nextOverlay(battle)
    if not (love and love.graphics and battle) then return end
    -- Classic Gen-I grounds rear pics at y=96, which can only make a larger
    -- image grow upward into the enemy HUD. Mega backs instead fill the
    -- normal player arena, then the tile HUD is repainted above the art.
    -- The lower command panel remains an opaque original-game layer.
    local player = battle.player
    local profile = player and player.mon
      and FORMS_BY_ID[player.mon._ascMegaForm]
    local fxHidden = player and type(battle.fxHidden) == "function"
      and battle:fxHidden(player)
    if profile and profile.asset and not voxelWantsFront()
        and not battle.safari and not battle.demo and not battle.sendingOut
        and not fxHidden
        and type(battle.drawHUDs) == "function" then
      local g = love.graphics
      local function paperAt(x, y)
        local colors = type(battle.zoneColorsAt) == "function"
          and battle:zoneColorsAt(x, y)
        local paper = colors and colors[1]
        return paper and {
          paper[1] / 255, paper[2] / 255, paper[3] / 255, 1,
        } or { 1, 1, 1, 1 }
      end
      local function clearTiles(x, y, width, height)
        for py = y, y + height - 1, 8 do
          for px = x, x + width - 1, 8 do
            local paper = paperAt(px + 4, py + 4)
            g.setColor(paper[1], paper[2], paper[3], paper[4])
            g.rectangle("fill", px, py,
              math.min(8, x + width - px),
              math.min(8, y + height - py))
          end
        end
      end

      -- Remove the normally grounded copy, then place the same current
      -- animation frame lower in the arena. The battle command box is an
      -- opaque UI layer in the original games, so no part of the monster may
      -- bleed into its deliberately empty left pane.
      clearTiles(0, 0, 96, 96)
      local image = rearOverlayImage(profile, player.mon, player.sprite)
      if image then
        -- Broad rear poses need individual left anchors so their heads and
        -- shoulders remain readable instead of disappearing under the
        -- player HP HUD. The anchor applies equally to normal, shiny and
        -- animated frames.
        local rearAnchors = {
          AERODACTYL = -15,
          ALAKAZAM = -9,
          AMPHAROS = -4,
          BEEDRILL = -2,
          BLASTOISE = -9,
          CHARIZARD_X = 0,
          CHARIZARD_Y = -5,
          CLEFABLE = -7,
          DRAGONITE = -14,
          FERALIGATR = -16,
          GENGAR = -6,
          GYARADOS = -13,
          HERACROSS = -4,
          HOUNDOOM = -6,
          KANGASKHAN = -11,
          MEGANIUM = -6,
          MEWTWO_X = -1,
          MEWTWO_Y = -2,
          PIDGEOT = -5,
          PINSIR = -11,
          RAICHU_X = -8,
          RAICHU_Y = -15,
          SCIZOR = -7,
          SKARMORY = -5,
          SLOWBRO = -5,
          STARMIE = -1,
          STEELIX = -11,
          TYRANITAR = -10,
          TYPHLOSION_ASCENDANT = -8,
          VENUSAUR = -10,
          VICTREEBEL = 0,
        }
        local rearX = rearAnchors[profile.id] or 0
        g.setColor(1, 1, 1, 1)
        g.setScissor(0, 0, 160, 96)
        g.draw(image, rearX, 40)
        g.setScissor()
      end

      -- Opaque HUD tiles cover the transformed body from its midpoint, and
      -- the lower border/menu sits above the portion entering rows 12+.
      clearTiles(0, 0, 88, 32)
      clearTiles(72, 56, 88, 40)
      battle:drawHUDs((battle.introSlide or 0) * 4)
    end
    local function sparkles(battler, cx, cy)
      if not (battler and battler._ascMegaForm) then return end
      local frame = battle.frame or 0
      local secret = battler._ascMegaForm == "TYPHLOSION_ASCENDANT"
      love.graphics.setColor(0, secret and 0.82 or 0,
        secret and 1 or 0, 1)
      for i = 1, 5 do
        local angle = frame * 0.045 + i * 1.257
        local radius = 18 + ((frame + i * 7) % 9)
        local x = math.floor(cx + math.cos(angle) * radius)
        local y = math.floor(cy + math.sin(angle) * radius * 0.65)
        love.graphics.points(x, y, x - 1, y, x + 1, y, x, y - 1, x, y + 1)
      end
      if secret then
        love.graphics.setColor(1, 0.36, 0, 1)
        love.graphics.points(cx - 13, cy + 4, cx + 11, cy - 7)
      end
    end
    sparkles(battle.player, 38, 66)
    sparkles(battle.enemy, 124, 30)
    love.graphics.setColor(1, 1, 1, 1)
  end, 300)

  mod.hooks:wrap("ui.start_menu.items", function(nextItems, game, items)
    local out = nextItems(game, items)
    if type(out) ~= "table" or not M.hasRing() then return out end
    return mod.ui.insertBefore(out, "SAVE", {
      label = tr("MEGA", "MEGA"),
      ascendantMenu = true,
      ascendantLabel = tr("MEGA STONES", "MEGA-STEINE"),
      ascendantOrder = 70,
      onSelect = function()
        M.stoneMenu(game, function() end)
      end,
    })
  end, 255)

  mod.events:on("battle.started", function(ev)
    local battle = ev and ev.battle
    if not (battle and optionEnabled()) then return end
    if eligibleOpponent(battle) and postgame
        and postgame.hasHallOfFame(battle.game.save) then
      battle._ascMegaEnemyPending = true
    end
  end)

  mod.events:on("battle.battler_switched", function(ev)
    local battle, battler = ev and ev.battle, ev and ev.battler
    if not (battle and battler and battler.mon) then return end
    if battler.isPlayer and battler.mon == battle._ascMegaPlayerMon then
      applyNow(battle, battler, "player", battle._ascMegaPlayerProfile)
    elseif not battler.isPlayer and battler.mon == battle._ascMegaEnemyMon then
      applyNow(battle, battler, "enemy", battle._ascMegaEnemyProfile)
    end
  end)

  mod.events:on("battle.ended", function(ev)
    cleanupBattle(ev and ev.battle)
  end)

  mod.events:on("save.loaded", function()
    state()
  end)

  M.state = state
  M.setYellowPartner = function(controller)
    yellowPartner = controller
  end
  M.hasStone = function(stone)
    local s = state(false)
    return s and s.stones and s.stones[stone] == true or false
  end
  M.grantStone = function(stone)
    local profile = FORM_BY_STONE[stone]
    if not (profile and not profile.secret) then return false end
    local s = state()
    if s.stones[stone] then return false end
    s.stones[stone] = true
    persist(s)
    return true
  end
  M.unlockSecret = function()
    local s = state()
    local fresh = not s.secretUnlocked
    s.secretUnlocked = true
    persist(s)
    return fresh
  end
  M.secretUnlocked = function()
    local s = state(false)
    return s and s.secretUnlocked == true or false
  end
  M.secretProfile = function()
    return FORMS_BY_ID.TYPHLOSION_ASCENDANT
  end
  -- Public Mega catalog remains strictly official; fan forms have an
  -- explicit separate export so UIs and compatibility mods cannot
  -- accidentally present them as released Mega Evolutions.
  M.forms = OFFICIAL_FORMS
  M.secretForms = SECRET_FORMS
  M.formsBySpecies = OFFICIAL_BY_SPECIES
  M.allFormsBySpecies = FORMS_BY_SPECIES
  M.profileFor = preferredProfile
  M.tierAvailable = tierAvailable
  M.boostedStats = boostedStats
  M.stoneName = stoneName
  M.caseLabel = caseLabel
  M.animationData = animationData
  M.updateAnimations = updateMegaAnimations
  return M
end
