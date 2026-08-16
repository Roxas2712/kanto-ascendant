-- Package-runnable Authority/LÖVE proof for the post-game League contract.
--
-- Every row constructs a real BattleState trainer battle and lets the
-- production battle.started listeners finalize its roster and arm automatic
-- Mega Evolution. Non-lead Mega carriers are then switched in through the
-- same BattleState.makeBattler + battle.battler_switched runtime seam used by
-- an ordinary enemy switch. That switch is intentionally staged (and is
-- recorded as such in driver_result.txt); the automatic Mega activation that
-- follows is not called manually.

return function(game)
  local U = dofile(os.getenv("KA_TEST_UTIL") or "tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")
  local Pipelines = require("src.render.Pipelines")
  local dir = assert(os.getenv("SHOT_DIR"), "SHOT_DIR is required")
  local api = assert(game.mods and game.mods.exports
    and game.mods.exports.kanto_ascendant,
    "Kanto Ascendant did not load from the candidate package")
  local postgame = assert(api.postgame, "postgame export missing")
  local data = assert(api.postgameData, "postgame data export missing")
  local ascendant = assert(api.ascendant, "ascendant export missing")
  local mega = assert(api.megaEvolution, "Mega export missing")
  local GameVersion = require("src.core.GameVersion")
  local expectedEdition = assert(os.getenv("POKEPORT_VERSION"),
    "POKEPORT_VERSION is required"):lower()
  local edition = GameVersion.get()
  assert(edition == expectedEdition,
    "live edition does not match POKEPORT_VERSION")
  local mode = (os.getenv("QA_RENDER_MODE") or "2d"):lower()
  assert(mode == "2d" or mode == "full",
    "QA_RENDER_MODE must be 2d or full")

  local pass, fail = 0, 0
  local report = {
    "scope=RC65-LEAGUE-UNIQUE-MEGAS",
    "authority=Authority-main/LÖVE/package",
    "edition=" .. edition,
    "renderer=" .. mode,
    "progression_setup=STAGED_POSTGAME_SAVE_STATE",
    "battle_construction=REAL_BATTLESTATE_TRAINER",
    "staged_switch=BattleState.makeBattler+battle.battler_switched",
    "manual_mega_activation=false",
  }
  local voxelResolver = assert(api.voxelRendererCompat,
    "shared Voxel renderer resolver export missing")

  local function check(label, value)
    value = value and true or false
    if value then pass = pass + 1 else fail = fail + 1 end
    report[#report + 1] = (value and "PASS\t" or "FAIL\t") .. label
    U.log(value and "PASS" or "FAIL", label)
    return value
  end

  local function finish()
    report[#report + 1] = "pass=" .. pass
    report[#report + 1] = "fail=" .. fail
    os.execute('mkdir -p "' .. dir .. '" 2>/dev/null')
    local handle = assert(io.open(dir .. "/driver_result.txt", "wb"))
    handle:write(table.concat(report, "\n"), "\n")
    handle:close()
    U.log(("LEAGUE UNIQUE MEGAS RESULT renderer=%s pass=%d fail=%d")
      :format(mode, pass, fail))
    love.event.quit(fail == 0 and 0 or 1)
  end

  local function clearStack()
    while game.stack:top() do game.stack:pop() end
  end

  local function waitFor(predicate, frames)
    for _ = 1, frames or 1200 do
      if predicate() then return true end
      U.wait(1)
    end
    return false
  end

  local function advanceBattleUntil(battle, predicate, frames)
    return waitFor(function()
      if predicate() then return true end
      if battle.msgWaiting or battle.msgPrompt then
        U.tap(game, "a")
      else
        U.wait(1)
      end
      return false
    end, frames or 1400)
  end

  local function roster(team)
    local out = {}
    for _, mon in ipairs(team or {}) do out[#out + 1] = mon.species end
    return table.concat(out, ",")
  end

  local function hasExactlyOne(team, species)
    local count = 0
    for _, mon in ipairs(team or {}) do
      if mon.species == species then count = count + 1 end
    end
    return count == 1
  end

  local function distinctTeam(team)
    local seen = {}
    for _, mon in ipairs(team or {}) do
      if seen[mon.species] then return false end
      seen[mon.species] = true
    end
    return #team == 6
  end

  local function setupProgress(tier)
    local state = postgame.state()
    state.masterWins = state.masterWins or {}
    state.crownWins = state.crownWins or {}
    state.eliteApexWins = {}
    state.eliteCrownWins = {}
    state.apexChampion = tier == "crown" and true or nil
    state.crownChampion = nil
    state.catches = state.catches or {}
    for _, gym in ipairs(data.gyms) do
      state.masterWins[gym.key] = true
      state.crownWins[gym.key] = tier == "crown" and true or nil
    end
    if tier == "crown" then
      state.catches.LUGIA = true
      state.catches.HO_OH = true
    end
    local adaptive = ascendant.state()
    adaptive.cycle = 0
    adaptive.bossBattles = {}
    adaptive.gymQuests = adaptive.gymQuests or {}
    game.save.flags = game.save.flags or {}
    game.save.flags.EVENT_BEAT_CHAMPION_RIVAL = true
    game.save.hallOfFame = { {} }
  end

  local function stageSwitch(battle, species)
    local index
    for slot, mon in ipairs(battle.enemyParty or {}) do
      if mon.species == species then index = slot break end
    end
    if not index then return false end
    local previous = battle.enemy
    battle.enemyIndex = index
    battle.enemy = BattleState.makeBattler(
      game.data, battle.enemyParty[index], false, game.save)
    if battle.syncSides then battle:syncSides() end
    Runtime.emit("battle.battler_switched", {
      battle = battle,
      side = battle.sides and battle.sides[2],
      battler = battle.enemy,
      previous = previous,
      ascendantQaStagedSwitch = true,
    })
    return true
  end

  game.save.options = game.save.options or {}
  game.save.options.textSpeed = 1
  game.save.options.modOptions = game.save.options.modOptions or {}
  game.save.options.modOptions.kanto_ascendant =
    game.save.options.modOptions.kanto_ascendant or {}
  game.mods.modOptions.kanto_ascendant =
    game.mods.modOptions.kanto_ascendant or {}
  local packageOptions = {
    mega_evolution = true, mega_opponents = "bosses",
    legend_articuno = "apex", legend_mewtwo = "apex",
    legend_raikou = true, legend_entei = true, legend_suicune = true,
    legend_lugia = true, legend_ho_oh = true,
  }
  for key, value in pairs(packageOptions) do
    game.mods.modOptions.kanto_ascendant[key] = value
    game.save.options.modOptions.kanto_ascendant[key] = value
  end
  report[#report + 1] = "league_legend_options=CANONICAL_DEFAULTS_STAGED"
  local overworldBattle, rendererId
  if mode == "full" then
    local reason
    overworldBattle, rendererId, reason = voxelResolver.module(
      game, "OverworldBattle")
    assert(overworldBattle,
      "FULL run has no supported renderer closure: " .. tostring(reason))
    assert(overworldBattle.setting and overworldBattle.setting.setIndex,
      "FULL renderer lacks its public setting seam")
    overworldBattle.setting:setIndex(1, game)
    if overworldBattle.backSetting and overworldBattle.backSetting.setIndex then
      overworldBattle.backSetting:setIndex(1, game)
    end
    report[#report + 1] = "renderer_id=" .. tostring(rendererId)
  else
    local resolved = voxelResolver.resolve(game)
    if resolved then
      local module = voxelResolver.module(game, "OverworldBattle")
      if module and module.setting and module.setting.setIndex then
        module.setting:setIndex(5, game)
      end
    end
    report[#report + 1] = "renderer_id=classic-2d"
  end
  Pipelines.setLevel("voxel", mode == "full" and 1 or 0)
  Pipelines.syncOptions(game.save.options)
  U.wait(8)
  check("requested renderer pipeline is active",
    mode == "full" and Pipelines.level("voxel") > 0
      and Pipelines.worldPipeline() == "voxel"
      or mode == "2d" and Pipelines.level("voxel") == 0)

  local player = Pokemon.new(game.data, "MEWTWO", 100)
  player.hp = player.stats.hp
  game.save.party = { player }
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }

  local crownRows = {
    { class = "OPP_LORELEI", tag = "lorelei", mega = "SLOWBRO",
      required = "ARTICUNO" },
    { class = "OPP_BRUNO", tag = "bruno", mega = "AERODACTYL",
      required = "AERODACTYL" },
    { class = "OPP_AGATHA", tag = "agatha", mega = "GENGAR",
      required = "MISMAGIUS" },
    { class = "OPP_LANCE", tag = "lance", mega = "DRAGONITE",
      required = "TYRANITAR", forbidden = "AERODACTYL" },
    { class = "OPP_RIVAL3", tag = "blue", mega = "MEWTWO",
      required = "MEWTWO" },
  }
  local crownLegends = {}
  local crownMegaCarriers = {}
  local legendary = {
    ARTICUNO=true, ZAPDOS=true, MOLTRES=true, MEWTWO=true, MEW=true,
    RAIKOU=true, ENTEI=true, SUICUNE=true, LUGIA=true, HO_OH=true,
    CELEBI=true,
  }

  setupProgress("crown")
  for index, row in ipairs(crownRows) do
    U.teleport(game, "ROUTE_1", 5, 5, "down")
    local battle = BattleState.newTrainer(game, row.class, 1)
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)

    check(row.tag .. " real trainer intro appears", waitFor(function()
      return game.stack:top() == battle and battle.showEnemyTrainer
    end, 900))
    check(row.tag .. " intro capture", U.shot(game,
      ("%s/%02d_crown_%s_intro_%s.png")
        :format(dir, index, row.tag, mode)))

    check(row.tag .. " live Crown party is finalized",
      advanceBattleUntil(battle, function()
        return battle.phase == "menu" and not battle.showEnemyTrainer
      end, 1600))
    report[#report + 1] = row.class .. "_roster=" .. roster(battle.enemyParty)
    check(row.tag .. " battle is tagged Crown",
      battle.postgameTier == "crown"
        and battle.ascendantForcedSource == "elite")
    check(row.tag .. " live roster has six distinct species",
      distinctTeam(battle.enemyParty))
    check(row.tag .. " reserves its exact unique Mega carrier",
      battle.ascendantEnemyMegaSpecies == row.mega
        and hasExactlyOne(battle.enemyParty, row.mega))
    check(row.tag .. " does not share another opponent's Mega species",
      not crownMegaCarriers[row.mega])
    crownMegaCarriers[row.mega] = row.class
    check(row.tag .. " keeps required roster identity " .. row.required,
      hasExactlyOne(battle.enemyParty, row.required))
    if row.forbidden then
      check(row.tag .. " excludes reassigned species " .. row.forbidden,
        not hasExactlyOne(battle.enemyParty, row.forbidden))
    end
    check(row.tag .. " automatic Mega is armed",
      battle._ascMegaEnemyPending == true
        or battle._ascMegaEnemyUsed == true)
    for _, mon in ipairs(battle.enemyParty) do
      if legendary[mon.species] then
        check(row.tag .. " does not repeat League legend " .. mon.species,
          not crownLegends[mon.species])
        crownLegends[mon.species] = row.class
      end
    end

    if battle.enemy.mon.species ~= row.mega then
      report[#report + 1] = row.class
        .. "_mega_entry=STAGED_SWITCH_AFTER_REAL_ROSTER_ASSERTION"
      check(row.tag .. " staged switch reaches reserved carrier",
        stageSwitch(battle, row.mega)
          and battle.enemy.mon.species == row.mega)
    else
      report[#report + 1] = row.class .. "_mega_entry=NATURAL_LEAD"
    end

    check(row.tag .. " production update automatically Mega Evolves carrier",
      advanceBattleUntil(battle, function()
        return battle.enemy.mon._ascMegaForm ~= nil
          and battle.enemy._ascMegaForm ~= nil
          and battle._ascMegaEnemyUsed == true
      end, 900))
    local profile = assert(mega.profileFor(battle.enemy.mon, true),
      row.class .. " has no legal enemy Mega profile")
    check(row.tag .. " live Mega form matches carrier profile",
      battle.enemy.mon._ascMegaForm == profile.id)
    check(row.tag .. " Mega field capture", U.shot(game,
      ("%s/%02d_crown_%s_mega_%s.png")
        :format(dir, index, row.tag, mode)))
    clearStack()
    U.wait(3)
  end

  -- Blue's ordinary post-game/Apex run deliberately owns Mega Gyarados;
  -- Crown Blue changes only his distinct carrier to Mewtwo.
  setupProgress("apex")
  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local blue = BattleState.newTrainer(game, "OPP_RIVAL3", 1)
  blue.onFinish = function() end
  game.overworld:pushBattle(blue)
  check("Apex Blue reaches live menu", advanceBattleUntil(blue, function()
    return blue.phase == "menu" and not blue.showEnemyTrainer
  end, 1600))
  report[#report + 1] = "OPP_RIVAL3_apex_roster=" .. roster(blue.enemyParty)
  check("Apex Blue has six distinct species", distinctTeam(blue.enemyParty))
  check("Apex Blue reserves exactly one Mega Gyarados",
    blue.postgameTier == "apex"
      and blue.ascendantEnemyMegaSpecies == "GYARADOS"
      and hasExactlyOne(blue.enemyParty, "GYARADOS"))
  report[#report + 1] =
    "OPP_RIVAL3_apex_mega_entry=STAGED_SWITCH_AFTER_REAL_ROSTER_ASSERTION"
  check("Apex Blue staged switch reaches Gyarados",
    stageSwitch(blue, "GYARADOS"))
  check("Apex Blue automatically Mega Evolves Gyarados",
    advanceBattleUntil(blue, function()
      return blue.enemy.mon.species == "GYARADOS"
        and blue.enemy.mon._ascMegaForm == "GYARADOS"
        and blue._ascMegaEnemyUsed == true
    end, 900))
  check("Apex Blue Mega Gyarados capture", U.shot(game,
    dir .. "/06_apex_blue_mega_gyarados_" .. mode .. ".png"))

  finish()
end
