-- Small host-side checks for the 6.5-only option plumbing.  Engine-backed
-- renderer checks remain in the Modkit/launcher QA stages.

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  if not value then error("FAIL: " .. message, 2) end
end

local function read(path)
  local file = assert(io.open(path, "r"))
  local body = file:read("*a")
  file:close()
  return body
end

local main = read("main.lua")
local manifest = read("manifest.json")
local featureHub = read("ascendant_features.lua")
local gorochu = read("gorochu.lua")
local mainKeys = {
  "wild_level_scaling",
  "johto_level_bonus", "ascendant_useful_bag", "ascendant_quick_select",
  "ascendant_qol", "modern_storage_ui", "pc_interface_style", "catch_destination",
  "pokedex_filter", "box_filter", "text_speed", "ride_control",
  "pokemon_sprite_style", "sprite_style_battle", "sprite_style_summary",
  "sprite_style_dex", "sprite_style_box", "sprite_style_scenes",
  "ascendant_bag_mode", "party_icon_style", "catch_box_notice",
  "quick_select_tap", "quick_select_registration",
  "quick_select_empty_notice", "status_values", "modern_ball_skins",
  "fast_box_switch", "qol_exp_bar", "qol_caught_indicator",
  "qol_easy_interactions", "qol_location_banners",
}
for _, key in ipairs(mainKeys) do
  ok(main:find('key = "' .. key .. '"', 1, true) ~= nil,
    "main options expose " .. key)
end
for _, key in ipairs({
  "johto_level_bonus", "ascendant_useful_bag",
  "ascendant_quick_select", "ascendant_qol",
  "modern_storage_ui", "pc_interface_style", "catch_destination", "pokedex_filter", "box_filter",
  "text_speed", "ride_control", "pokemon_sprite_style",
  "sprite_style_battle", "sprite_style_summary", "sprite_style_dex",
  "sprite_style_box", "sprite_style_scenes", "ascendant_bag_mode",
  "party_icon_style", "catch_box_notice", "quick_select_tap",
  "quick_select_registration", "quick_select_empty_notice", "status_values",
  "modern_ball_skins", "fast_box_switch", "qol_exp_bar",
  "qol_caught_indicator", "qol_easy_interactions",
  "qol_location_banners",
}) do
  ok(featureHub:find('key = "' .. key .. '"', 1, true) ~= nil,
    "Ascendant Options exposes " .. key)
end
ok(main:find('key = "language"', 1, true) == nil,
  "language follows the installed game translation instead of a private toggle")
ok(manifest:find('"version": "6.5.16"', 1, true) ~= nil,
  "release manifest reports 6.5.16")
ok(manifest:find('"id": "kanto_ascendant"', 1, true) ~= nil,
  "manifest uses Kanto Ascendant's own canonical id")
ok(manifest:find('"trainer_rematch"', 1, true) ~= nil,
  "manifest refuses the standalone trainer_rematch id")
ok(featureHub:find('drawFrame(Font, tr("ASCENDANT OPTIONS"', 1, true) ~= nil,
  "nested screen is branded for Kanto Ascendant")
ok(read("ascendant_menu.lua"):find('tr("OPTIONS", "OPTIONEN")', 1, true)
    ~= nil, "Ascendant Start-menu tree owns the Options entry")
ok(gorochu:find('tr("GOROCHU RESEARCH", "GOROCHU-APP")', 1, true)
    ~= nil, "German Ascendant tree uses the compact Gorochu app label")
ok(gorochu:find("GOROCHU-FORSCHUNG", 1, true) == nil,
  "oversized German Gorochu label is absent")
ok(featureHub:find('de = "REITEN"', 1, true) == nil,
  "the bicycle shortcut is no longer mislabeled as REITEN")
ok(read("qol_feature_caught_indicator.lua"):find(
    '"save/mod-derived/" .. mod.id .. "/ui/ball.png"', 1, true) ~= nil,
  "integrated caught icon reads Kanto Ascendant's own derived cache")

do
  local written, blitted
  local transform = assert(loadfile("shiny_transforms.lua"))()
  transform({
    exists = function(path) return path == "battle/balls.png" end,
    readImage = function(path)
      ok(path == "battle/balls.png", "caught icon uses imported ball art")
      return { source = true }
    end,
    blank = function(w, h)
      ok(w == 8 and h == 8, "caught icon derives an 8x8 tile")
      return { target = true }
    end,
    blit = function(target, source, dx, dy, sx, sy, w, h)
      blitted = target.target and source.source and dx == 0 and dy == 0
        and sx == 0 and sy == 0 and w == 8 and h == 8
    end,
    writeImage = function(_, path) written = path end,
    recolor = function() error("unexpected shiny recolor") end,
  })
  ok(blitted, "caught icon copies the first imported party-ball tile")
  ok(written == "ui/ball.png",
    "Kanto Ascendant's transform writes the integrated caught icon")
end

local function pngDimensions(path)
  local file = assert(io.open(path, "rb"))
  local header = file:read(24)
  file:close()
  ok(header and #header == 24 and header:sub(2, 4) == "PNG",
    path .. " is a PNG")
  local function u32(offset)
    local a, b, c, d = header:byte(offset, offset + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
  end
  return u32(17), u32(21)
end

for dex = 1, 251 do
  local path = ("assets/crystal_menu_icons/%03d.png"):format(dex)
  local width, height = pngDimensions(path)
  ok(width == 16 and height == 96,
    ("party icon #%03d has the 16x96 animated layout"):format(dex))
end

local kinds = assert(loadfile("german_dex_kinds.lua"))()
local kindCount = 0
for _ in pairs(kinds) do kindCount = kindCount + 1 end
ok(kindCount == 151, "all 151 German Kanto categories are restored")
ok(kinds.GROWLITHE == "WELPEN",
  "FUKANO is no longer assigned SEEHUND")

local handlers, speedValue = {}, "fast"
local mod = {
  options = { get = function() return speedValue end },
  events = { on = function(_, name, fn) handlers[name] = fn end },
}
local install = assert(loadfile("text_speed.lua"))()
install(mod)
local game = { save = { options = {} } }
handlers["game.ready"]({ game = game })
ok(game.save.options.textSpeed == 1, "FAST preset maps to one-frame text speed")
speedValue = "slow"
handlers["mod.options_changed"]({})
ok(game.save.options.textSpeed == 5,
  "options-changed reapplies text speed through the remembered game")

print(("6.5 QOL PLUMBING PASS: %d assertions"):format(assertions))

-- Catch destination: a full party catch starts in a box. Choosing PARTY must
-- offer a party replacement and swap without cloning or losing either mon.
do
  local shortCatch = { species = "RATTATA", level = 3 }
  local shortParty = {
    { species = "BULBASAUR", level = 5 },
    { species = "PIKACHU", level = 5 },
    shortCatch,
  }
  local caught = { species = "RATTATA", level = 4 }
  local oldParty = { species = "PIDGEY", level = 7 }
  local party = {
    { species = "BULBASAUR", level = 10 }, oldParty,
    { species = "CHARMANDER", level = 10 },
    { species = "SQUIRTLE", level = 10 },
    { species = "PIKACHU", level = 10 },
    { species = "CATERPIE", level = 10 },
  }
  local boxes = { { caught } }
  for i = 2, 12 do boxes[i] = {} end
  package.loaded["src.pokemon.Boxes"] = {
    CAPACITY = 20,
    ensure = function() return boxes end,
    active = function() return boxes[1] end,
    deposit = function(_, mon)
      for boxIndex, box in ipairs(boxes) do
        if #box < 20 then
          table.insert(box, mon)
          return boxIndex
        end
      end
      return nil
    end,
  }
  package.loaded["src.pokemon.Party"] = { MAX = 6 }
  package.loaded["src.ui.ChoiceBox"] = {
    new = function(_, onChoose) return { onChoose = onChoose } end,
  }
  package.loaded["src.render.TextBox"] = {
    new = function(_, text, onDone, opts)
      return {
        text = text, onDone = onDone,
        choice = opts and opts.choice,
      }
    end,
  }

  local catchHandlers, pushed, queued = {}, {}, nil
  local game2 = {
    data = { pokemon = {
      RATTATA = { name = "RATTATA" }, PIDGEY = { name = "PIDGEY" },
    } },
    save = {
      party = party, boxes = boxes, currentBox = 1,
      options = { modOptions = { kanto_ascendant = {
        catch_destination = "ask",
      } } },
    },
  }
  game2.stack = {
    push = function(_, value) pushed[#pushed + 1] = value end,
  }
  local catchMod = {
    id = "kanto_ascendant",
    find = function() return nil end,
    options = { get = function(_, key)
      return key == "catch_destination" and "ask" or nil
    end },
    events = { on = function(_, name, fn) catchHandlers[name] = fn end },
    ui = { ListMenu = { new = function(_, _, items, opts)
      return {
        items = items, onChoose = opts.onChoose,
        close = function(self) self.closed = true end,
      }
    end } },
  }
  assert(loadfile("catch_destination.lua"))()(catchMod, {
    i18n = {
      isGerman = function() return false end,
      text = function(en) return en end,
    },
  })
  local shortQueued
  catchHandlers["pokemon.caught"]({
    game = {
      data = game2.data,
      save = {
        party = shortParty, boxes = boxes, currentBox = 1,
        options = game2.save.options,
      },
    },
    mon = shortCatch, destination = "party",
    battle = { uiNext = function(_, factory) shortQueued = factory end },
  })
  local shortCopies = 0
  for _, mon in ipairs(shortParty) do
    if mon == shortCatch then shortCopies = shortCopies + 1 end
  end
  ok(#shortParty == 3 and shortCopies == 1
      and type(shortQueued) == "function",
    "ASK mode prompts even when the caught Pokémon initially fits in party")

  catchHandlers["pokemon.caught"]({
    game = game2, mon = caught,
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  ok(type(queued) == "function",
    "catch prompt is queued after the battle capture messages")
  local prompt = queued()
  prompt.choice(true)
  local replacement = pushed[#pushed]
  replacement.onChoose({ value = 2 }, replacement)
  ok(game2.save.party[2] == caught,
    "choosing PARTY replaces the selected full-party member")
  ok(boxes[1][1] == oldParty,
    "the replaced party member occupies the caught mon's box slot")

  local caught2 = { species = "RATTATA", level = 5 }
  table.insert(game2.save.party, caught2)
  game2.save.options.modOptions.kanto_ascendant.catch_destination = "box"
  game2.save.options.modOptions.kanto_ascendant.catch_box_notice = true
  queued = nil
  catchHandlers["pokemon.caught"]({
    game = game2, mon = caught2,
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  ok(type(queued) == "function",
    "direct BOX mode queues a transfer announcement")
  ok(queued().text:find("BOX 1", 1, true) ~= nil,
    "direct BOX announcement identifies the destination box")

  -- A full active box overflows atomically into the next free box.
  local caught3 = { species = "RATTATA", level = 6 }
  local partyBefore = #game2.save.party
  table.insert(game2.save.party, caught3)
  boxes[1] = {}
  for i = 1, 20 do boxes[1][i] = { species = "PIDGEY", level = i } end
  boxes[2] = {}
  queued = nil
  catchHandlers["pokemon.caught"]({
    game = game2, mon = caught3, destination = "party",
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  ok(#game2.save.party == partyBefore,
    "BOX mode removes the just-caught party member exactly once")
  ok(boxes[2][1] == caught3,
    "a full current box transfers the catch into the next free box")
  ok(queued and queued().text:find("BOX 2", 1, true),
    "overflow transfer announces its actual destination box")

  -- A catch that the engine already boxed keeps its single canonical
  -- transfer dialog instead of receiving a duplicate Ascendant notice.
  local caught4 = { species = "RATTATA", level = 7 }
  table.insert(boxes[2], caught4)
  queued = nil
  catchHandlers["pokemon.caught"]({
    game = game2, mon = caught4, destination = "box",
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  ok(queued == nil,
    "an engine-boxed catch does not queue a duplicate transfer dialog")

  local caughtMissing = { species = "RATTATA", level = 7 }
  catchHandlers["pokemon.caught"]({
    game = game2, mon = caughtMissing, destination = "box",
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  local recoveredBox = false
  for _, box in ipairs(boxes) do
    for _, candidate in ipairs(box) do
      if candidate == caughtMissing then recoveredBox = true end
    end
  end
  ok(recoveredBox,
    "a missing engine box insertion is completed exactly once when room exists")

  -- If every normal destination is full, the exact caught record enters
  -- SaveData's persisted quarantine instead of disappearing.
  for boxIndex = 1, 12 do
    boxes[boxIndex] = {}
    for slot = 1, 20 do
      boxes[boxIndex][slot] = {
        species = "PIDGEY", level = slot, box = boxIndex,
      }
    end
  end
  game2.save.boxes = boxes
  game2.save.options.modOptions.kanto_ascendant.catch_destination = "off"
  local caught5 = {
    species = "RATTATA", level = 8, item = "MOON_STONE",
    dvs = { attack = 15, defense = 14, speed = 13, special = 12 },
    moves = { { id = "TACKLE", pp = 31 } },
  }
  queued = nil
  catchHandlers["pokemon.caught"]({
    game = game2, mon = caught5, destination = "box",
    battle = { uiNext = function(_, factory) queued = factory end },
  })
  ok(game2.save.orphaned.mons[1] == caught5,
    "all-boxes-full capture preserves the exact Pokémon record")
  ok(queued and queued().text:find("PC RESERVE", 1, true),
    "all-boxes-full capture explains the safe reserve")
end

print(("6.5 QOL FUNCTIONAL PASS: %d assertions"):format(assertions))

-- The modern capture skin must replace the four OAM tiles with one ball and
-- remember the selected type across toss/shake and consecutive attempts.
do
  local engine = os.getenv("GEN1RECOMP_ROOT")
  assert(engine and engine ~= "",
    "GEN1RECOMP_ROOT must point at the gen1recomp checkout")
  package.path = engine .. "/?.lua;" .. engine .. "/?/init.lua;" .. package.path
  package.loaded["src.battle.AnimPlayer"] = nil
  local AnimPlayer = require("src.battle.AnimPlayer")
  local passthroughDraws = 0
  AnimPlayer.drawSprites = function()
    passthroughDraws = passthroughDraws + 1
  end
  local ballMod = {
    id = "kanto_ascendant",
    world = { game = { save = { options = { modOptions = {
      kanto_ascendant = { modern_ball_skins = true },
    } } } } },
    options = { get = function() return true end },
    exports = {},
  }
  assert(loadfile("modern_ball_skins.lua"))()(ballMod)
  -- This contract exercises Kanto Ascendant's bridge against the engine's
  -- real AnimPlayer, but it must not require ROM-derived generated data in
  -- public CI. Keep the focused animation input in the test tree instead.
  local data = assert(loadfile(
    "tests/fixtures/modern_ball_skins_battle_anims.lua"))()
  local player = AnimPlayer.new(data)
  local draws, ids = 0, {}
  AnimPlayer._ascendantBallBridge.draw = function(id)
    draws = draws + 1
    ids[#ids + 1] = id
  end

  local tossByBall = {
    POKE_BALL = "TOSS_ANIM",
    GREAT_BALL = "GREATTOSS_ANIM",
    ULTRA_BALL = "ULTRATOSS_ANIM",
    MASTER_BALL = "ULTRATOSS_ANIM",
    SAFARI_BALL = "ULTRATOSS_ANIM",
  }
  for _, ball in ipairs({
    "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL", "SAFARI_BALL",
  }) do
    player:start(tossByBall[ball], true, {
      ball = ball,
      ballFlicker = ball == "ULTRA_BALL" or ball == "MASTER_BALL",
    })
    ok(#player.steps[1].sprites == 4,
      ball .. " toss begins as one four-tile ball")
    player:drawSprites(player.steps[1].sprites)
    ok(ids[#ids] == ball,
      ball .. " keeps its own modern skin on the toss arc")
  end
  ok(draws == 5, "all five capture balls render exactly once per frame")

  player:start("SHAKE_ANIM", true, { shakes = 3 })
  local shakeSprites
  for _, step in ipairs(player.steps) do
    if #step.sprites > 0 then shakeSprites = step.sprites break end
  end
  player:drawSprites(assert(shakeSprites))
  ok(draws == 6 and ids[6] == "SAFARI_BALL",
    "shake keeps the most recently thrown Safari Ball skin")

  player:start("GREATTOSS_ANIM", true, { ball = "GREAT_BALL" })
  player:drawSprites(player.steps[1].sprites)
  ok(draws == 7 and ids[7] == "GREAT_BALL",
    "a consecutive catch replaces stale ball state with Great Ball")

  player:start("POOF_ANIM", true)
  player:drawSprites(player.steps[1] and player.steps[1].sprites or {})
  player:start("POOF_ANIM", false)
  player:drawSprites(player.steps[1] and player.steps[1].sprites or {})
  ok(passthroughDraws == 2 and draws == 7,
    "player and opponent send-out animations keep the engine renderer")

  player:start("HIDEPIC_ANIM", true)
  player:drawSprites(player.steps[1] and player.steps[1].sprites or {})
  ok(passthroughDraws == 3 and draws == 7,
    "recall/hide animation keeps the engine renderer")

  player:start("BLOCKBALL_ANIM", true)
  player:drawSprites(player.steps[1] and player.steps[1].sprites or {})
  ok(passthroughDraws == 3 and draws == 8 and ids[8] == "GREAT_BALL",
    "trainer-blocked throw keeps the selected modern ball skin")
  ok(ballMod.exports.modernBallSkins.animations.BLOCKBALL_ANIM == true,
    "trainer-block animation is part of the modern ball renderer")
end

print(("6.5 BALL/ICON REGRESSION PASS: %d assertions"):format(assertions))
