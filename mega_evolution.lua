-- Kanto Ascendant Mega Evolution.
--
-- Only species with an officially released Mega Evolution through July 2026
-- are eligible. Every form requires its own Mega Stone. Because Gen 1 has no
-- held-item slot and only 20 Bag slots, stones live in a dedicated Stone Case
-- and resonate automatically with the active eligible Pokémon.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local postgame = opts.postgame
  local animationData = opts.animationData or {}
  local enabled = opts.contentEnabled ~= false
  local M = { game = nil, enabled = enabled }

  local function form(species, id, stone, label, tier, cost, bonuses, types, asset)
    return {
      species = species, id = id, stone = stone, label = label,
      tier = tier or "hof", cost = cost or 5000,
      bonuses = bonuses, types = types, asset = asset,
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
      { attack = 10, defense = 50, speed = 10, special = 30 }),
    form("FERALIGATR", "FERALIGATR", "FERALIGATRITE", "MEGA FERALIGATR", "masters", 10000,
      { attack = 50, defense = 20, speed = 20, special = 10 }, { "WATER", "DRAGON" }),
    form("SKARMORY", "SKARMORY", "SKARMORITE", "MEGA SKARMORY", "masters", 10000,
      { attack = 25, defense = 45, speed = 25, special = 5 }),

    -- Mega Dimension: two forms, two distinct stones.
    form("RAICHU", "RAICHU_X", "RAICHUNITE_X", "MEGA RAICHU X", "masters", 10000,
      { attack = 40, defense = 35, speed = 15, special = 10 }, nil,
      "mega_raichu_x"),
    form("RAICHU", "RAICHU_Y", "RAICHUNITE_Y", "MEGA RAICHU Y", "masters", 10000,
      { attack = 10, defense = 10, speed = 45, special = 35 }, nil,
      "mega_raichu_y"),
  }

  local FORMS_BY_ID, FORMS_BY_SPECIES, FORM_BY_STONE = {}, {}, {}
  for _, profile in ipairs(FORMS) do
    FORMS_BY_ID[profile.id] = profile
    FORM_BY_STONE[profile.stone] = profile
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
  local animationImages = {}

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
    if isShiny(mon) and type(data.shiny) == "table" then return "shiny" end
    return type(data.normal) == "table" and "normal" or nil
  end

  local function animationPath(profile, variant, frame)
    return ("%s/assets/mega_animated/%s/%s/%03d.png"):format(
      mod.path, profile.asset, variant, frame or 1)
  end

  local function loadAnimationImage(path)
    if animationImages[path] then return animationImages[path] end
    if not (love and love.graphics and love.graphics.newImage) then return nil end
    local ok, image = pcall(love.graphics.newImage, path)
    if not (ok and image) then return nil end
    if image.setFilter then image:setFilter("nearest", "nearest") end
    animationImages[path] = image
    return image
  end

  local function updateMegaBattler(battler, dt)
    local mon = battler and battler.mon
    local profile = mon and FORMS_BY_ID[mon._ascMegaForm]
    local variant = profile and animationVariant(profile, mon)
    local timings = variant and animationData[profile.id][variant]
    if not (profile and profile.asset and timings and #timings > 1) then
      if battler then battler.__ascendantMegaAnimation = nil end
      return
    end
    local state = battler.__ascendantMegaAnimation
    if not state or state.form ~= profile.id or state.variant ~= variant then
      state = {
        form = profile.id, variant = variant, timings = timings,
        frame = 1, elapsed = 0, image = battler.sprite,
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
    local image = loadAnimationImage(
      animationPath(profile, variant, state.frame))
    if image then
      battler.sprite = image
      state.image = image
    end
  end

  local function updateMegaAnimations(battle, dt)
    if not battle then return end
    if battle.enemy and not battle.showEnemyTrainer
        and not battle.enemySendingOut then
      updateMegaBattler(battle.enemy, dt)
    end
    if battle.player and not battle.showPlayerBack and not battle.sendingOut then
      updateMegaBattler(battle.player, dt)
    end
  end

  local function tr(en, de)
    return i18n and i18n.text(en, de) or en
  end

  local function stoneName(profile)
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
        version = 2, ring = false, case = false, stones = {},
        preferences = {}, activations = 0,
      }
      mod.save:set("mega_evolution", s)
    end
    if type(s) == "table" then
      s.version = 2
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
    if enemy then return rows end
    local stones, out = state().stones, {}
    for _, profile in ipairs(rows) do
      if stones[profile.stone] then out[#out + 1] = profile end
    end
    return out
  end

  local function preferredProfile(mon, enemy)
    local rows = ownedProfiles(mon.species, enemy)
    if #rows == 0 then return nil end
    local preferred = state().preferences[mon.species]
    for _, profile in ipairs(rows) do
      if profile.id == preferred then return profile end
    end
    if mon.species == "RAICHU" and #rows > 1 then
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

  local function refreshSprite(battle, battler)
    local BattleState = require("src.battle.BattleState")
    local fresh = BattleState.makeBattler(
      battle.data, battler.mon, battler.isPlayer,
      battler.isPlayer and battle.game.save or nil)
    if fresh and fresh.sprite then battler.sprite = fresh.sprite end
  end

  local function applyNow(battle, battler, side, profile)
    if not (battle and battler and battler.mon and profile) then return end
    battler.mon._ascMegaForm = profile.id
    battler._ascMegaForm = profile.id
    battler._ascMegaProfile = profile
    battler.__ascendantMegaAnimation = nil
    battler.curStats = boostedStats(battler, profile)
    if profile.types then battler.curTypes = profile.types end
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
    battle:say(tr(
      ("%s's KEY STONE\nresonated with\n%s!\f%s became\n%s!"):format(
        owner, stoneName(profile), battler.name, profile.label),
      ("%ss SCHLÜSSEL-STEIN\nreagiert mit\n%s!\f%s wird zu\n%s!"):format(
        owner, stoneName(profile), battler.name, profile.label)))
    battle:act(function()
      applyNow(battle, battler, side, profile)
      local s = state()
      s.activations = s.activations + 1
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
      if mon then mon._ascMegaForm = nil end
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
    if not tierAvailable(game, profile.tier) then return tr("LOCK", "SPERR") end
    return ("¥%d"):format(profile.cost)
  end

  local function stoneDetails(profile, game)
    local requirement = profile.tier == "masters"
      and tr("Defeat all eight\nMaster Leaders first.",
             "Besiege erst alle acht\nMaster-Leiter.")
      or (profile.tier == "apex"
        and tr("Defeat the Apex\nChampion first.",
               "Besiege erst den\nApex-Champ.")
        or tr("Available after the\nfirst Hall of Fame.",
              "Nach der ersten\nRuhmeshalle verfügbar."))
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
      rows[#rows + 1] = {
        label = caseLabel(profile),
        right = stoneStatus(profile, game),
        value = index,
      }
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
    return tr(
      "Only official Mega\nspecies are eligible.\fEvery form needs its\nmatching Mega Stone.\fSELECT on the battle\nmenu transforms once\nper side.\fNew Z-A stones unlock\nafter all Master Leaders;\nMewtwo after Apex.",
      "Nur offizielle Mega-\nArten sind zugelassen.\fJede Form braucht ihren\npassenden Mega-Stein.\fSELECT im Kampfmenü\nverwandelt einmal\npro Seite.\fNeue Z-A-Steine folgen\nnach allen Master-Leitern;\nMewtu nach Apex.")
  end

  function M.activate(battle, battler, side)
    if not optionEnabled() then return false, "disabled" end
    if side == "player" and not M.hasRing() then return false, "locked" end
    if not battler or not battler.mon or battler.mon.isEgg then
      return false, "invalid"
    end
    if not FORMS_BY_SPECIES[battler.mon.species] then
      return false, "ineligible"
    end
    local profile = preferredProfile(battler.mon, side ~= "player")
    if not profile then return false, "stone" end
    return queueActivation(battle, battler, side, profile)
  end

  function M.install(game, deps)
    M.game = game
    state()
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
  for _, profile in ipairs(FORMS) do
    mod.content.items:register(profile.stone, {
      id = profile.stone, name = stoneName(profile),
      price = 0, tossable = false, needsTarget = false,
    })
    if profile.asset then
      mod.content.battle_sprite_scales:register(
        "KANTO_ASCENDANT_" .. profile.id .. "_BACK", {
          path = mod.path .. "/assets/mega/" .. profile.asset .. "_back.png",
          scale = 1,
        })
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
    local base = "assets/mega/" .. profile.asset .. "_" .. side
    local shiny = isShiny(ctx.mon) and mod:read(base .. "_shiny.png")
    local candidate = base .. (shiny and "_shiny" or "") .. ".png"
    if not mod:read(candidate) then return path end
    ctx.trueColor = animationData[profile.id] ~= nil
    return mod.path .. "/" .. candidate
  end, 990)

  mod.hooks:wrap("battle.overlay", function(nextOverlay, battle)
    nextOverlay(battle)
    if not (love and love.graphics and battle) then return end
    local function sparkles(battler, cx, cy)
      if not (battler and battler._ascMegaForm) then return end
      local frame = battle.frame or 0
      love.graphics.setColor(0, 0, 0, 1)
      for i = 1, 5 do
        local angle = frame * 0.045 + i * 1.257
        local radius = 18 + ((frame + i * 7) % 9)
        local x = math.floor(cx + math.cos(angle) * radius)
        local y = math.floor(cy + math.sin(angle) * radius * 0.65)
        love.graphics.points(x, y, x - 1, y, x + 1, y, x, y - 1, x, y + 1)
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
  M.forms = FORMS
  M.formsBySpecies = FORMS_BY_SPECIES
  M.profileFor = preferredProfile
  M.tierAvailable = tierAvailable
  M.boostedStats = boostedStats
  M.stoneName = stoneName
  M.caseLabel = caseLabel
  M.animationData = animationData
  M.updateAnimations = updateMegaAnimations
  return M
end
