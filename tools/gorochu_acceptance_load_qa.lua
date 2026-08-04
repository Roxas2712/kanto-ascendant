-- Loads every generated Gorochu acceptance slot through production
-- SaveData/Game.restoreSave, verifies the restored quest/partner state and
-- performs real Voxel battles plus all seven Yellow follower reactions.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local GameVersion = require("src.core.GameVersion")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Pipelines = require("src.render.Pipelines")
  local SaveData = require("src.core.SaveData")
  local Stats = require("src.pokemon.Stats")

  U.wait(24)

  local version = (os.getenv("GOROCHU_SAVE_VERSION")
    or GameVersion.get() or ""):lower()
  assert(GameVersion.get() == version,
    "POKEPORT_VERSION and GOROCHU_SAVE_VERSION must match")
  local isYellow = version == "yellow"
  local shotDir = os.getenv("SHOT_DIR")
    or ("/tmp/gorochu-acceptance-" .. version)

  local exports = assert(game.mods and game.mods.exports,
    "mod exports unavailable")
  local ascendant = assert(exports.trainer_rematch,
    "Kanto Ascendant is not loaded")
  local gorochu = assert(ascendant.gorochu,
    "Gorochu controller unavailable")
  local partner = assert(ascendant.yellowPartner,
    "Yellow partner controller unavailable")
  local dramatic = assert(exports.DRAMATIC_SHAPE,
    "Dramatic Shape is not loaded")
  local followers = assert(exports.PokePCFollowers_VoxelMerge,
    "PokéPC Followers Voxel Merge is not loaded")
  assert(followers.supported,
    "PokéPC Followers does not support this edition")
  local overworldBattle = assert(
    dramatic.lib and dramatic.lib.require("OverworldBattle"),
    "Dramatic Shape battle renderer unavailable")

  local rows
  if isYellow then
    rows = {
      { id = "slot1", species = "PIKACHU", map = "VERMILION_GYM" },
      { id = "slot2", species = "PIKACHU", map = "VERMILION_GYM" },
      { id = "slot3", species = "PIKACHU", map = "VERMILION_CITY" },
      { id = "slot4", species = "PIKACHU", map = "VERMILION_CITY",
        heart = true, awakened = true },
      { id = "slot5", species = "RAICHU", map = "POWER_PLANT",
        heart = true, condenser = true },
      { id = "slot6", species = "RAICHU", map = "VERMILION_CITY",
        heart = true, tear = true },
      { id = "slot7", species = "GOROCHU", map = "ROUTE_1",
        completed = true, battle = "normal" },
      { id = "slot8", species = "GOROCHU", map = "ROUTE_1",
        completed = true, battle = "shiny" },
      { id = "slot9", species = "GOROCHU", map = "VERMILION_CITY",
        completed = true, mood = "sleepy" },
      { id = "slot10", species = "GOROCHU", map = "VERMILION_CITY",
        completed = true, mood = "unwell" },
      { id = "slot11", species = "GOROCHU", map = "VERMILION_CITY",
        completed = true, mood = "upset" },
      { id = "slot12", species = "GOROCHU", map = "VERMILION_CITY",
        completed = true, mood = "wary" },
      { id = "slot13", species = "GOROCHU", map = "VERMILION_CITY",
        completed = true, mood = "content" },
      { id = "slot14", species = "GOROCHU", map = "VERMILION_CITY",
        completed = true, mood = "devoted" },
      { id = "slot15", species = "GOROCHU", map = "VERMILION_CITY",
        completed = true, mood = "excited" },
    }
  else
    rows = {
      { id = "slot1", species = "RAICHU", map = "VERMILION_GYM" },
      { id = "slot2", species = "RAICHU", map = "POWER_PLANT",
        heart = true, condenser = true },
      { id = "slot3", species = "RAICHU", map = "VERMILION_CITY",
        heart = true, tear = true },
      { id = "slot4", species = "GOROCHU", map = "ROUTE_1",
        completed = true, battle = "normal" },
      { id = "slot5", species = "GOROCHU", map = "ROUTE_1",
        completed = true, battle = "shiny" },
    }
  end

  local function loadSlot(row)
    assert(SaveData.setActiveSlot(version, row.id) == row.id)
    local loaded, recovered = SaveData.load(version)
    assert(loaded and not recovered,
      row.id .. " did not load from its primary save")
    game:restoreSave(loaded, recovered)
    U.wait(36)
    assert(SaveData.emptyReport(game.saveReport),
      row.id .. " produced a quarantine/load report")
    assert(game.overworld and game.overworld.map
        and game.overworld.map.id == row.map,
      row.id .. " restored the wrong map")
    local lead = assert(game.save.party and game.save.party[1],
      row.id .. " restored without a lead")
    assert(lead.species == row.species,
      row.id .. " restored " .. tostring(lead.species)
        .. " instead of " .. row.species)
    assert(Pipelines.level("voxel") == 1,
      row.id .. " did not restore the Voxel pipeline")
    if row.heart then
      assert(game.save.inventory[gorochu.heartItemId] == 1,
        row.id .. " lost the permanent Thunderheart")
    end
    if row.map == "VERMILION_GYM" then
      assert(game.save.flags.EVENT_2ND_LOCK_OPENED == true,
        row.id .. " restored with Major Bob's gate closed")
    end
    if row.tear then
      assert(game.save.inventory[gorochu.tearItemId] == 1,
        row.id .. " lost the Thunder Tear")
    end
    if row.completed then
      assert(gorochu.state().completed,
        row.id .. " lost Gorochu completion state")
      assert(game.save.inventory[gorochu.heartItemId] == 1,
        row.id .. " lost the permanent Thunderheart after completion")
      assert(not game.save.inventory[gorochu.tearItemId],
        row.id .. " retained the consumed Thunder Tear")
      assert(game.save.pokedex.owned.GOROCHU,
        row.id .. " lost Gorochu Pokédex ownership")
      assert(#lead.moves == 4 and lead.hp == lead.stats.hp,
        row.id .. " Gorochu is not battle-ready")
    end
    if isYellow then
      assert(partner.partner(game) == lead
          and lead[partner.marker] == true,
        row.id .. " lost Yellow's original partner identity")
    end
    if row.awakened then
      assert(partner.isAwakened(lead),
        row.id .. " lost Thunderheart Awakening")
      local expected = Stats.calc(game.data.pokemon.RAICHU,
        lead.level, lead.dvs, lead.statExp)
      for _, stat in ipairs(Stats.ORDER) do
        assert(lead.stats[stat] == expected[stat],
          row.id .. " lost awakened " .. stat)
      end
      local choices = partner._choiceRows(lead)
      assert(#choices == 2 and choices[1].value == "evolve"
          and choices[2].value == "later",
        row.id .. " restored the consumed Stay choice")
    end
    if row.battle == "shiny" then
      assert(Stats.isShiny(lead.dvs),
        row.id .. " restored a non-shiny Gorochu")
    elseif row.battle == "normal" then
      assert(not Stats.isShiny(lead.dvs),
        row.id .. " restored a shiny Gorochu in the normal slot")
    end
    return lead
  end

  local function verifyCondenser(row)
    local found
    for _, npc in ipairs(game.overworld.npcs or {}) do
      if npc.def and npc.def.name == gorochu.shrineName then
        found = npc
        break
      end
    end
    assert(found, row.id .. " did not restore the Power Plant condenser")
    assert(found.cellX >= 24
        and math.abs(found.cellX - 4) + math.abs(found.cellY - 9) >= 25,
      row.id .. " placed the condenser too close to Zapdos")
  end

  local function closeBattle()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  local function verifyBattle(row, lead)
    Pipelines.setLevel("voxel", 1)
    Pipelines.syncOptions(game.save.options)
    overworldBattle.setting:setIndex(1, game)
    overworldBattle.backSetting:setIndex(1, game)
    assert(overworldBattle.enabled() and not overworldBattle.backPinned(),
      row.id .. " did not activate camera-facing Voxel battles")

    local battle = BattleState.newWild(game, "PIDGEY", 5)
    battle.onFinish = function() end
    game.overworld:pushBattle(battle)
    U.wait(190)
    for _ = 1, 50 do
      if battle.phase == "menu" then break end
      U.tap(game, "a")
      U.wait(8)
    end
    assert(battle.phase == "menu",
      row.id .. " battle did not reach the action menu")
    U.wait(45)

    local animation = assert(
      battle.player.__ascendantCrystalAnimation,
      row.id .. " did not attach Gorochu's Voxel animation")
    assert(animation.dex == 1026 and animation.side == "front"
        and animation.variant == row.battle,
      row.id .. " selected the wrong animated Voxel variant")
    local textures = assert(overworldBattle.textures(battle),
      row.id .. " did not build Dramatic Shape textures")
    local width, height = textures.player.canvas:getDimensions()
    assert(width == 160 and height == 144,
      row.id .. " built a malformed Gorochu billboard")

    local initialFrame = animation.frame
    for _ = 1, 240 do
      U.wait(1)
      if animation.frame ~= initialFrame then break end
    end
    assert(animation.frame ~= initialFrame,
      row.id .. " Gorochu animation remained static")
    assert(U.shot(game,
      ("%s/%s_%s_voxel_battle.png")
        :format(shotDir, version, row.battle)),
      row.id .. " battle screenshot failed")
    assert(lead == game.save.party[1],
      row.id .. " battle replaced the saved Gorochu")
    closeBattle()
  end

  local function verifyMood(row, lead)
    PikachuFollower.onMapEntered(game, game.overworld)
    U.wait(60)
    local npc = assert(PikachuFollower.current(game.overworld),
      row.id .. " did not restore the Gorochu follower")
    local reaction = partner.raichuReaction(game, lead)
    assert(reaction.id == row.mood,
      row.id .. " selected " .. tostring(reaction.id)
        .. " instead of " .. row.mood)
    assert(reaction.voice == nil,
      row.id .. " selected a Raichu voice instead of Gorochu's cry")
    assert(reaction.text:find("GOROCHU", 1, true),
      row.id .. " still names Raichu in the bond dialogue")
    local files = assert(partner._portraitFrames(lead, reaction),
      row.id .. " has no Gorochu portrait loop")
    assert(#files > 1,
      row.id .. " portrait does not animate")
    for _, path in ipairs(files) do
      assert(love.filesystem.getInfo(path),
        row.id .. " missing portrait frame " .. tostring(path))
      local ok, image = pcall(love.graphics.newImage, path)
      assert(ok and image,
        row.id .. " has an unreadable portrait frame")
    end

    PikachuFollower.talk(game, game.overworld, npc, function() end)
    local emote = assert(game.overworld.emote,
      row.id .. " did not open the framed expression")
    assert(emote.pikaPic and emote.pikaPic:find(
      "/yellow_partner_gorochu_portraits/"
        .. (Stats.isShiny(lead.dvs) and "shiny" or "normal")
        .. "/" .. row.mood .. "/", 1, true),
      row.id .. " displayed the wrong framed expression")
    assert(emote._ascendantRaichuFrames
        and #emote._ascendantRaichuFrames > 1,
      row.id .. " framed expression is not animated")
    U.wait(24)
    assert(U.shot(game,
      ("%s/yellow_face_%s.png"):format(shotDir, row.mood)),
      row.id .. " expression screenshot failed")
  end

  for _, row in ipairs(rows) do
    local lead = loadSlot(row)
    if row.condenser then verifyCondenser(row) end
    if row.battle then verifyBattle(row, lead) end
    if row.mood then verifyMood(row, lead) end
  end

  SaveData.setActiveSlot(version, "slot1")
  U.log("PASS loaded Gorochu acceptance suite",
    version, #rows,
    "production restore", "Voxel battles",
    isYellow and "seven live partner expressions" or "edition quest")
  love.event.quit(0)
end
