-- End-to-end Gorochu UAT for a disposable Red, Blue or Yellow profile.
--
-- Example:
--   POKEPORT_DRIVER=/path/to/kanto-ascendant/tools/gorochu_qa_driver.lua \
--   SHOT_DIR=/tmp/kanto-ascendant-gorochu-uat \
--   GOROCHU_QA_VERSION=yellow \
--   love /path/to/gen1recomp
--
-- Red/Blue exercise the permanent Heart -> condenser -> Tear evolution and
-- normal/shiny battle art.
-- Yellow additionally exercises partner identity, follower art, all seven
-- normal/shiny bond expressions, animation and emoji-safe placement.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Evolution = require("src.pokemon.Evolution")
  local GameVersion = require("src.core.GameVersion")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Pipelines = require("src.render.Pipelines")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")
  local Sound = require("src.core.Sound")

  local version = (os.getenv("GOROCHU_QA_VERSION") or "yellow"):lower()
  assert(GameVersion.VERSIONS[version],
    "GOROCHU_QA_VERSION must be red, blue or yellow")
  GameVersion.set(version)
  -- This is the canonical 2D/Crystal quest UAT. Voxel presentation has its
  -- own real-external-mod driver so a persisted 3D option cannot silently
  -- change these comparison screenshots.
  Pipelines.setLevel("voxel", 0)
  Pipelines.syncOptions(game.save.options)
  U.wait(20)
  local ascendant = assert(
    game.mods and game.mods.exports and game.mods.exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local gorochuApi = assert(ascendant.gorochu,
    "Gorochu controller missing")
  assert(gorochuApi.available and game.data.pokemon.GOROCHU,
    "Gorochu species did not register")
  local cryDef = assert(game.data.audio and game.data.audio.cries
    and game.data.audio.cries.GOROCHU, "Gorochu cry was not registered")
  assert(type(cryDef.file) == "string"
      and cryDef.file:find("gorochu_cry.wav", 1, true),
    "Gorochu still uses a Raichu-derived placeholder cry")
  Sound.invalidate("cry:GOROCHU")
  assert(Sound.playCry(game.data, "GOROCHU"),
    "Gorochu's spoken mono cry is not playable")
  local partnerApi = assert(ascendant.yellowPartner,
    "Yellow partner controller missing")
  local shotDir = os.getenv("SHOT_DIR")

  game.save.player = game.save.player or {}
  game.save.player.name = "GORO UAT"
  game.save.player.id = 5400
  game.save.flags = game.save.flags or {}
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_CHOSE_PIKACHU = true
  game.save.inventory = game.save.inventory or {}
  game.save.boxes = game.save.boxes or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.hallOfFame = {}

  local raichu = Pokemon.new(game.data, "RAICHU", 61,
    function() return 9 end)
  BattleState.stampOT(game.save, raichu)
  raichu.moves = { { id = "THUNDER", pp = 10 } }
  raichu.hp = raichu.stats.hp
  if GameVersion.isYellow() then
    raichu[partnerApi.marker] = true
    game.save.pikachuHappiness = 230
    game.save.pikachuMood = 128
  end
  game.save.party = { raichu }
  assert(gorochuApi.beginQuest(game, raichu),
    "Major Bob did not bind the chosen Raichu to the Thunder path")
  assert(game.save.inventory[gorochuApi.heartItemId] == 1,
    "Heart of Thunder was not granted as a permanent story item")

  U.teleport(game, "POWER_PLANT", 10, 10, "down")
  U.wait(20)
  gorochuApi.refreshShrine(game, "POWER_PLANT")
  local condenser
  for _, npc in ipairs(game.overworld.npcs or {}) do
    if npc.def and npc.def.name == gorochuApi.shrineName then
      condenser = npc
      break
    end
  end
  assert(condenser, "remote Power Plant Thunder condenser did not spawn")
  local zapdosDistance =
    math.abs(condenser.cellX - 4) + math.abs(condenser.cellY - 9)
  assert(zapdosDistance >= 25 and condenser.cellX >= 24,
    "Thunder condenser was placed too close to Zapdos or the normal route")
  if shotDir then
    local neighbors = {
      { condenser.cellX, condenser.cellY + 1, "up" },
      { condenser.cellX, condenser.cellY - 1, "down" },
      { condenser.cellX + 1, condenser.cellY, "left" },
      { condenser.cellX - 1, condenser.cellY, "right" },
    }
    local proof
    for _, cell in ipairs(neighbors) do
      if game.overworld.map:inBounds(cell[1], cell[2])
          and game.overworld.map:isWalkableCell(cell[1], cell[2])
          and not game.overworld.map:warpAtCell(cell[1], cell[2]) then
        proof = cell
        break
      end
    end
    assert(proof, "Thunder condenser has no accessible interaction side")
    U.teleport(game, "POWER_PLANT",
      proof[1], proof[2], proof[3])
    U.wait(12)
    assert(U.shot(game, shotDir .. "/thunder_condenser_remote.png"),
      "remote Thunder condenser screenshot failed")
  end
  assert(gorochuApi.grantTear(game),
    "Power Plant condenser did not create the first Thunder Tear")
  assert(game.save.inventory[gorochuApi.tearItemId] == 1,
    "Thunder Tear was not placed in the Bag")
  local target, edge = Evolution.pendingFor(
    game, raichu, { kind = "item", item = gorochuApi.tearItemId })
  assert(target == "GOROCHU"
      and edge and edge.method == "ITEM",
    "Thunder Tear did not resolve Raichu into Gorochu")
  game.save.inventory[gorochuApi.tearItemId] = nil
  assert(Evolution.request(
    game, raichu,
    { kind = "item", item = gorochuApi.tearItemId }) == "GOROCHU",
    "standard evolution movie did not start")
  if shotDir then
    assert(U.shot(game, shotDir .. "/gorochu_evolution_start.png"),
      "Gorochu evolution start screenshot failed")
    U.wait(84)
    assert(U.shot(game, shotDir .. "/gorochu_evolution_flash.png"),
      "Gorochu evolution flash screenshot failed")
  end
  U.wait(230)
  assert(raichu.species == "GOROCHU",
    "Raichu did not permanently evolve into Gorochu")
  if shotDir then
    assert(U.shot(game, shotDir .. "/gorochu_evolution_complete.png"),
      "Gorochu evolution completion screenshot failed")
  end
  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end
  assert(raichu.moves[1] and raichu.moves[1].id == "THUNDER",
    "Gorochu evolution lost Raichu's moves")
  assert(game.save.pokedex.owned.GOROCHU,
    "Gorochu was not recorded as owned")
  if GameVersion.isYellow() then
    assert(raichu[partnerApi.marker]
        and partnerApi.partner(game) == raichu,
      "Gorochu evolution lost Yellow's original partner identity")
  end

  local function spritePath(side, shiny)
    raichu.dvs = shiny and {
      attack = 10, defense = 10, speed = 10, special = 10, hp = 0,
    } or {
      attack = 9, defense = 8, speed = 8, special = 8, hp = 8,
    }
    local def = game.data.pokemon.GOROCHU
    local requested = side == "back" and def.spriteBack or def.spriteFront
    local ctx = {
      species = "GOROCHU", side = side, kind = "battle",
      data = game.data, mon = raichu,
    }
    local path = Runtime.call("pokemon.sprite",
      function(original) return original end, requested, ctx)
    local variant = shiny and "/shiny/" or "/normal/"
    assert(path and path:find(
      "/crystal_animated/" .. side .. variant .. "1026/001.png",
      1, true), "wrong Gorochu " .. side .. " sprite: " .. tostring(path))
    return path
  end

  for _, shiny in ipairs({ false, true }) do
    spritePath("front", shiny)
    spritePath("back", shiny)
  end

  local function closeBattle()
    while game.stack:top() and game.stack:top() ~= game.overworld do
      game.stack:pop()
    end
  end

  if shotDir then
    for _, shiny in ipairs({ false, true }) do
      spritePath("back", shiny)
      U.teleport(game, "ROUTE_1", 5, 5, "down")
      local battle = BattleState.newWild(game, "GOROCHU", 61)
      battle.onFinish = function() end
      game.overworld:pushBattle(battle)
      U.wait(220)
      for _ = 1, 40 do
        if battle.phase == "menu" then break end
        U.tap(game, "a")
        U.wait(6)
      end
      assert(battle.phase == "menu",
        "Gorochu battle did not reach the action menu")
      U.wait(12)
      assert(U.shot(game, ("%s/gorochu_battle_%s.png")
        :format(shotDir, shiny and "shiny" or "normal")),
        "Gorochu battle screenshot failed")
      closeBattle()
    end
  end

  if not GameVersion.isYellow() then
    U.log("PASS Gorochu UAT", GameVersion.get(),
      "Heart", "remote condenser", "Tear evolution",
      "normal/shiny front+back", "save identity")
    love.event.quit(0)
    return
  end

  local moods = {
    { id = "sleepy", happiness = 230, mood = 128, status = "SLP" },
    { id = "unwell", happiness = 230, mood = 128, status = "PSN" },
    { id = "upset", happiness = 30, mood = 50 },
    { id = "wary", happiness = 90, mood = 100 },
    { id = "content", happiness = 150, mood = 128 },
    { id = "devoted", happiness = 220, mood = 128 },
    { id = "excited", happiness = 240, mood = 150 },
  }

  U.teleport(game, "VERMILION_CITY", 20, 18, "down")
  PikachuFollower.onMapEntered(game, game.overworld)
  U.wait(20)
  local npc = assert(PikachuFollower.current(game.overworld),
    "partner Gorochu follower is missing")
  local followerDef = assert(
    game.data.sprites and game.data.sprites.SPRITE_PIKACHU,
    "Yellow follower sprite definition missing")
  assert(followerDef.image and followerDef.image:find(
    "follower_GOROCHU.png", 1, true),
    "Yellow partner did not select Gorochu's follower sheet")

  for _, shiny in ipairs({ false, true }) do
    spritePath("front", shiny)
    for index, test in ipairs(moods) do
      raichu.status = test.status
      raichu.hp = raichu.stats.hp
      game.save.pikachuHappiness = test.happiness
      game.save.pikachuMood = test.mood
      PikachuFollower.talk(game, game.overworld, npc, function() end)
      local emote = assert(game.overworld.emote,
        "missing Gorochu emote for " .. test.id)
      assert(emote.pikaPic:find(
        "/yellow_partner_gorochu_portraits/"
          .. (shiny and "shiny" or "normal")
          .. "/" .. test.id .. "/", 1, true),
        "wrong Gorochu face for " .. test.id)
      local boxLeft = assert(emote._ascendantRaichuBoxX) * 8
      local boxRight = boxLeft + 56
      local cameraX = game.overworld.camera and game.overworld.camera.x or 0
      local bubbleLeft = npc.px - cameraX + 4
      local bubbleRight = bubbleLeft + 16
      assert(boxRight <= bubbleLeft or boxLeft >= bubbleRight,
        "Gorochu portrait overlaps emoji for " .. test.id)
      if shotDir then
        local stem = ("%s/%s_%02d_%s")
          :format(shotDir, shiny and "shiny" or "normal", index, test.id)
        assert(U.shot(game, stem .. "_frame_1.png"),
          "first Gorochu portrait screenshot failed")
        U.wait(math.max(1,
          (emote._ascendantRaichuTicks or 8) * 2 + 1))
        assert(U.shot(game, stem .. "_frame_2.png"),
          "second Gorochu portrait screenshot failed")
      end
      game.overworld.emote = nil
      U.wait(2)
    end
  end

  U.log("PASS Gorochu UAT", GameVersion.get(),
    "Heart/condenser/Tear evolution", "partner identity", "follower",
    "normal/shiny battle art", "14 animated mood states")
  love.event.quit(0)
end
