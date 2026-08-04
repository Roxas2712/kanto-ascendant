-- Real Red/Blue/Yellow smoke test for Yellow's optional Thunderheart path.
-- Yellow also captures the direct Mega-Raichu resonance and evolved Raichu
-- follower/bond presentation. Red and Blue prove the story item cannot leak.

return function(game)
  local U = dofile("tests/drivers/util.lua")
  local BattleState = require("src.battle.BattleState")
  local Evolution = require("src.pokemon.Evolution")
  local GameVersion = require("src.core.GameVersion")
  local Pokemon = require("src.pokemon.Pokemon")
  local Runtime = require("src.mods.Runtime")

  U.wait(20)
  local ascendant = assert(
    game.mods and game.mods.exports and game.mods.exports.trainer_rematch,
    "Kanto Ascendant export missing")
  local partnerApi = assert(ascendant.yellowPartner,
    "Yellow partner controller missing")
  local mega = assert(ascendant.megaEvolution,
    "Mega controller missing")
  local itemId = partnerApi.itemId
  local itemDef = assert(game.data.items[itemId],
    "THUNDERHEART item definition missing")
  assert(itemDef.keyItem and itemDef.tossable == false and itemDef.price == 0,
    "THUNDERHEART is not a permanent unsellable key item")

  game.save.player = game.save.player or {}
  game.save.player.name = game.save.player.name or "YELLOW"
  game.save.player.id = game.save.player.id or 25
  game.save.flags = game.save.flags or {}
  game.save.inventory = game.save.inventory or {}
  game.save.bagOrder = game.save.bagOrder or {}
  game.save.pokedex = game.save.pokedex or { seen = {}, owned = {} }
  game.save.pokedex.seen = game.save.pokedex.seen or {}
  game.save.pokedex.owned = game.save.pokedex.owned or {}
  game.save.boxes = game.save.boxes or {}
  game.save.options = game.save.options or {}

  local pikachu = Pokemon.new(game.data, "PIKACHU", 50,
    function() return 10 end)
  BattleState.stampOT(game.save, pikachu)
  pikachu[partnerApi.marker] = true
  game.save.party = { pikachu }
  game.save.flags.EVENT_GOT_STARTER = true
  game.save.flags.EVENT_CHOSE_PIKACHU = true
  game.save.inventory.THUNDERBADGE = true

  local bucket = game.save.modData and game.save.modData.trainer_rematch
  if bucket then bucket.yellow_partner = nil end

  if not GameVersion.isYellow() then
    partnerApi.migrate(game)
    assert(not game.save.inventory[itemId],
      "Yellow's story item leaked into " .. GameVersion.get())
    assert(not partnerApi.megaEligible(pikachu),
      "partner-only Mega bridge leaked into " .. GameVersion.get())
    U.log("PASS yellow-partner isolation", GameVersion.get())
    return
  end

  partnerApi.migrate(game)
  assert(game.save.inventory[itemId] == 1,
    "old Yellow save did not receive THUNDERHEART")
  assert(partnerApi.partner(game) == pikachu,
    "old Yellow partner identity was not retained")

  local quest = partnerApi.state()
  assert(quest.legacy and partnerApi.questReady(),
    "old Yellow save did not receive ready legacy quest state")
  local ItemEffects = require("src.inventory.ItemEffects")
  assert(not ItemEffects.needsTarget(itemId, itemDef),
    "THUNDERHEART unexpectedly requests an arbitrary party target")
  local beforeHeartScreen = game.stack:top()
  local useResult, useMessages = ItemEffects.use(
    game.data, game.save, itemId, nil, nil)
  assert(useResult == "failed" and useMessages == nil,
    "THUNDERHEART did not enter its custom partner-choice flow")
  assert(game.stack:top() ~= beforeHeartScreen,
    "THUNDERHEART did not open its bond dialogue")
  game.stack:pop()
  assert(game.save.inventory[itemId] == 1,
    "opening THUNDERHEART consumed the permanent item")

  -- A marked unevolved partner uses the Raichunite profile directly; its
  -- underlying species stays Pikachu before, during and after the battle.
  local megaState = mega.state()
  megaState.ring = true
  megaState.preferences.RAICHU = "RAICHU_X"
  mega.grantStone("RAICHUNITE_X")
  local direct = assert(mega.profileFor(pikachu, false),
    "partner Pikachu did not resolve a Raichunite")
  assert(direct.id == "RAICHU_X",
    "partner Pikachu resolved the wrong Raichunite profile")

  U.teleport(game, "ROUTE_1", 5, 5, "down")
  local battle = BattleState.newWild(game, "PIDGEY", 8)
  battle.onFinish = function() end
  game.overworld:pushBattle(battle)
  U.wait(220)
  for _ = 1, 40 do
    if battle.phase == "menu" then break end
    U.tap(game, "a")
    U.wait(6)
  end
  assert(battle.phase == "menu",
    "direct partner Mega battle did not reach the action menu")
  U.tap(game, "select")
  for _ = 1, 40 do
    if pikachu._ascMegaForm then break end
    U.tap(game, "a")
    U.wait(5)
  end
  assert(pikachu.species == "PIKACHU",
    "direct Mega resonance permanently changed Pikachu's species")
  assert(pikachu._ascMegaForm == "RAICHU_X",
    "partner Pikachu did not enter Mega Raichu X")

  local shotDir = os.getenv("SHOT_DIR")
  if shotDir then
    assert(U.shot(game, shotDir .. "/partner_pikachu_mega_raichu_x.png"),
      "direct Mega Raichu screenshot failed")
  end

  Runtime.emit("battle.ended", { battle = battle, result = "run" })
  assert(pikachu.species == "PIKACHU" and not pikachu._ascMegaForm,
    "direct Mega Raichu did not return to partner Pikachu")
  while game.stack:top() and game.stack:top() ~= game.overworld do
    game.stack:pop()
  end

  -- The same table evolves, so the identity marker and Yellow happiness are
  -- not reset. The follower bridge must now accept Raichu as the companion.
  game.save.pikachuHappiness = 230
  Evolution.apply(game, pikachu, "RAICHU", "THUNDERHEART")
  assert(pikachu[partnerApi.marker] and pikachu.species == "RAICHU",
    "Thunderheart evolution lost the partner identity")
  assert(game.save.inventory[itemId] == 1,
    "Thunderheart evolution consumed the permanent item")

  U.teleport(game, "ROUTE_22", 8, 8, "down")
  U.wait(40)
  U.hold(game, "right", 20)
  U.wait(20)
  local follower = require("src.world.PikachuFollower")
  local npc = assert(follower.current(game.overworld),
    "evolved partner Raichu did not continue following")
  local activeFollower
  for _, api in pairs(game.mods.exports or {}) do
    if type(api) == "table" and type(api.activeMon) == "function" then
      local ok, mon = pcall(api.activeMon, game)
      if ok and mon then activeFollower = mon break end
    end
  end
  if activeFollower then
    assert(activeFollower == pikachu,
      "all-species follower mod selected a different Pokémon after evolution")
  end
  if shotDir then
    assert(U.shot(game, shotDir .. "/partner_raichu_following.png"),
      "partner Raichu overworld screenshot failed")
  end

  follower.talk(game, game.overworld, npc, function() end)
  local raichuEmote = game.overworld.emote
  assert(raichuEmote and raichuEmote.pikaPic,
    "Raichu did not receive its partner bond presentation")
  assert(raichuEmote.pikaPic:find(
    "assets/crystal_animated/front/", 1, true),
    "happy partner Raichu did not retain its original Crystal portrait")
  assert(type(raichuEmote._ascendantRaichuFrames) == "table"
      and #raichuEmote._ascendantRaichuFrames > 1,
    "Raichu bond portrait did not receive a multi-frame animation")
  local boxLeft = assert(raichuEmote._ascendantRaichuBoxX,
    "Raichu portrait did not select an emoji-safe screen side") * 8
  local boxRight = boxLeft + 56
  local cameraX = game.overworld.camera and game.overworld.camera.x or 0
  local bubbleLeft = npc.px - cameraX + 4
  local bubbleRight = bubbleLeft + 16
  assert(boxRight <= bubbleLeft or boxLeft >= bubbleRight,
    "Raichu portrait overlaps its emotion bubble")
  local firstPortrait = raichuEmote.pikaPic
  if shotDir then
    assert(U.shot(game,
      shotDir .. "/partner_raichu_follower_bond_frame_1.png"),
      "partner Raichu first portrait-frame screenshot failed")
  end
  local frameTicks = assert(raichuEmote._ascendantRaichuTicks,
    "Raichu portrait timing is missing")
  -- Land several poses into the loop so the evidence pair proves a full
  -- body/arm change rather than only Crystal's subtle one-pixel in-between.
  U.wait(frameTicks * 3 + 1)
  assert(game.overworld.emote
      and game.overworld.emote.pikaPic ~= firstPortrait,
    "Raichu bond portrait stayed on the first frame")
  if shotDir then
    assert(U.shot(game,
      shotDir .. "/partner_raichu_follower_bond_frame_2.png"),
      "partner Raichu second portrait-frame screenshot failed")
  end

  U.log("PASS yellow-partner", GameVersion.get(),
    "legacy item", "direct Mega Raichu X", "Raichu follower bond")
end
