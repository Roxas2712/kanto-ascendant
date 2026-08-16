package.path = "./?.lua;./?/init.lua;" .. package.path
local modPath = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."

local assertions = 0
local function ok(value, message)
  assertions = assertions + 1
  assert(value, message)
end
local function eq(actual, expected, message)
  assertions = assertions + 1
  assert(actual == expected, (message or "values differ") .. ": "
    .. tostring(actual) .. " ~= " .. tostring(expected))
end
local function near(actual, expected, tolerance, message)
  assertions = assertions + 1
  assert(math.abs(actual - expected) <= tolerance,
    (message or "values not near") .. ": " .. actual .. " ~= " .. expected)
end
local function contains(text, fragment, message)
  ok(type(text) == "string" and text:find(fragment, 1, true) ~= nil,
    message)
end

local loot = assert(loadfile(modPath .. "/rematch_loot.lua"))()

local itemIds = {
  "POKE_BALL", "GREAT_BALL", "ULTRA_BALL", "MASTER_BALL", "SAFARI_BALL",
  "POTION", "SUPER_POTION", "HYPER_POTION", "MAX_POTION", "FULL_HEAL",
  "REVIVE", "MAX_REVIVE", "ETHER", "MAX_ETHER", "ELIXER", "MAX_ELIXER",
  "PP_UP", "RARE_CANDY", "HP_UP", "PROTEIN", "IRON", "CALCIUM",
  "CARBOS", "FIRE_STONE", "WATER_STONE", "THUNDER_STONE", "LEAF_STONE",
  "MOON_STONE", "SUN_STONE", "KINGS_ROCK", "METAL_COAT",
  "DRAGON_SCALE", "UPGRADE", "EXP_ALL", "HEVO_TEST_RELIC",
}
local Data = { items = {}, pokemon = {}, balls = {} }
for _, id in ipairs(itemIds) do
  Data.items[id] = { id = id, name = id:gsub("_", " "), price = 100 }
end
Data.pokemon.TEST = { evolutions = {
  { method = "ITEM", item = "SUN_STONE", species = "TEST2" },
  { method = "ITEM", item = "KINGS_ROCK", species = "TEST3" },
  { method = "ITEM", item = "METAL_COAT", species = "TEST4" },
  { method = "ITEM", item = "DRAGON_SCALE", species = "TEST5" },
  { method = "ITEM", item = "UPGRADE", species = "TEST6" },
  { method = "ITEM", item = "HEVO_TEST_RELIC", species = "TEST_HEVO" },
} }

eq(loot.money(1, false), 0, "normal money pool starts with its five-percent zero")
eq(loot.money(500, false), 0, "normal zero band contains exactly 500 rolls")
eq(loot.money(501, false), 100, "normal ¥100 band follows the zero band")
eq(loot.money(9901, false), 2000, "normal top one-percent band pays ¥2000")
eq(loot.money(1, true), 1000, "level-100 money starts at ¥1000")
eq(loot.money(2500, true), 1000, "level-100 ¥1000 band is exactly 25 percent")
eq(loot.money(2501, true), 1500, "level-100 ¥1500 follows at 20 percent")
eq(loot.money(9901, true), 8000, "level-100 top one percent pays ¥8000")
local normalWeight, capWeight = 0, 0
for _, row in ipairs(loot.moneyBands.normal) do normalWeight = normalWeight + row.weight end
for _, row in ipairs(loot.moneyBands.level100) do capWeight = capWeight + row.weight end
eq(normalWeight, 10000, "normal money distribution totals 100 percent")
eq(capWeight, 10000, "level-100 money distribution totals 100 percent")

local normalCatalog, normalNoItem = loot.catalog(Data, "balanced", {})
local capCatalog, capNoItem = loot.catalog(Data, "balanced",
  { level100 = true, masteryWins = 1000 })
near(normalNoItem, 0.35, 0.000001, "balanced normal no-item chance is stable")
near(capNoItem, 0.25, 0.000001,
  "mastered level-100 item chance receives only its capped three-percent lift")
local normalPremium, capPremium = 0, 0
for _, row in ipairs(normalCatalog) do if row.premium then normalPremium = normalPremium + row.chance end end
for _, row in ipairs(capCatalog) do if row.premium then capPremium = capPremium + row.chance end end
ok(capPremium > normalPremium, "level-100 pool improves premium reward odds")

local seen = {}
for roll = 1, loot.ROLL_MAX do
  local reward = loot.select(roll, "balanced", {}, Data)
  if reward then
    ok(reward.item ~= "MASTER_BALL", "Master Ball never enters normal rewards")
    ok(reward.item ~= "SAFARI_BALL", "Safari Ball never enters normal rewards")
    ok(reward.item ~= "HEVO_TEST_RELIC",
      "Hidden-Evolution progression items never enter normal rewards")
    seen[reward.item .. ":" .. reward.qty] = true
  end
end
for _, key in ipairs({
  "POKE_BALL:3", "POKE_BALL:5", "POKE_BALL:10",
  "GREAT_BALL:2", "GREAT_BALL:3", "GREAT_BALL:5",
  "ULTRA_BALL:1", "ULTRA_BALL:2", "ULTRA_BALL:3",
  "POTION:2", "MAX_POTION:1", "MAX_REVIVE:1",
  "ETHER:1", "MAX_ETHER:1", "ELIXER:1", "MAX_ELIXER:1",
  "PP_UP:1", "RARE_CANDY:1", "HP_UP:1", "PROTEIN:1", "IRON:1",
  "CALCIUM:1", "CARBOS:1", "SUN_STONE:1", "KINGS_ROCK:1",
  "METAL_COAT:1", "DRAGON_SCALE:1", "UPGRADE:1",
}) do
  eq(seen[key], true, key .. " is reachable in the supported normal pool")
end

local hits = 0
for roll = 1, 10000 do if loot.specialHit("expShare", roll) then hits = hits + 1 end end
eq(hits, 225, "EXP Share drop rate is exactly 2.25 percent")
hits = 0
for roll = 1, 300 do if loot.specialHit("multiplier2", roll) then hits = hits + 1 end end
eq(hits, 1, "×2 unlock is exactly one in 300")
for _, kind in ipairs({ "multiplier3", "multiplier5" }) do
  hits = 0
  for roll = 1, 250 do if loot.specialHit(kind, roll) then hits = hits + 1 end end
  eq(hits, 1, kind .. " unlock is exactly one in 250")
end
hits = 0
for roll = 1, 50 do
  if loot.specialHit("rematchMaster", roll) then hits = hits + 1 end
end
eq(hits, 1, "post-HOF rematch Master Ball roll is exactly one in 50")

local bucket, hooks, screens, events = {}, {}, {}, {}
local mode = "balanced"
local mod = {
  id = "kanto_ascendant",
  save = {
    get = function(_, key, default)
      local value = bucket[key]
      return value == nil and default or value
    end,
    set = function(_, key, value) bucket[key] = value end,
  },
  options = { get = function(_, key)
    if key == "loot_mode" then return mode end
  end },
  content = {
    items = { register = function(_, id, def) Data.items[id] = def end },
    screens = { register = function(_, id, def) screens[id] = def end },
  },
  hooks = { wrap = function(_, name, fn) hooks[name] = fn end },
  events = { on = function(_, name, fn) events[name] = fn end },
  ui = {
    ListMenu = { new = function(_, title, rows, opts)
      local list = { game = _, title = title, items = rows, index = 1,
        onChoose = opts and opts.onChoose,
        onSelectKey = opts and opts.onSelectKey,
        pageJump = opts and opts.pageJump,
        footer = opts and opts.footer,
        close = function() end }
      function list:update()
        local input = self.game and self.game.input
        if input and self.onSelectKey and input:wasPressed("select") then
          self.onSelectKey(self.items[self.index], self)
        elseif input and self.onChoose and input:wasPressed("a") then
          self.onChoose(self.items[self.index], self)
        end
      end
      return list
    end },
    push = function(game, id, args)
      game.lastScreen = { id = id, args = args }
      return game.lastScreen
    end,
  },
}
local legacyRunActive = true
local rewards = assert(loadfile(modPath .. "/rematch_rewards.lua"))()(mod, {
  loot = loot,
  i18n = { text = function(en) return en end },
  optionSchema = {
    { key = "difficulty", label = "DIFFICULTY", type = "choice",
      default = "standard", choices = {
        { "STANDARD", "standard" }, { "HARD", "hard" },
        { "VERY HARD", "very_hard" },
      } },
    { key = "rare_item_lock", label = "RARE ITEM LOCK", type = "toggle",
      default = true },
    { key = "kanto_151", label = "KANTO 151", type = "choice",
      default = "ascendant", choices = { { "REWARDS", "ascendant" } } },
    { key = "ascendant_rules", label = "RULES", type = "choice",
      default = "rotating", choices = { { "ROTATING", "rotating" } } },
    { key = "trainer_portrait_style", label = "TRAINER PORTRAITS",
      type = "choice", default = "crystal_hd", choices = {
        { "CRYSTAL HD", "crystal_hd" }, { "ORIGINAL", "original" },
      } },
    { key = "rest_min", label = "MIN REST", type = "number", default = 151,
      min = 151, max = 2510, presets = { 151, 302, 604, 1255, 2510 } },
    { key = "rest_max", label = "MAX REST", type = "number", default = 2510,
      min = 151, max = 2510, presets = { 151, 302, 604, 1255, 2510 } },
    { key = "level_gain", label = "LEVEL GAIN", type = "number",
      default = 2, min = 0, max = 20, step = 1 },
    { key = "team_growth", label = "TEAM GROWTH", type = "toggle",
      default = true },
    { key = "loot_mode", label = "LOOT", type = "choice",
      default = "balanced", choices = { { "BALANCED", "balanced" } } },
    { key = "legacy_wanderer_frequency", label = "WANDERER FREQ.",
      type = "choice", default = "normal", choices = {
        { "NEVER", "never" }, { "RARE", "rare" },
        { "NORMAL", "normal" }, { "OFTEN", "often" },
      } },
    { key = "living_world_enabled", label = "VISIBLE WILD POKEMON",
      type = "toggle", default = true },
  },
  legacyWanderers = {
    legacyRunEnabled = function() return legacyRunActive end,
  },
  optionHelp = {
    text = function(key, value) return key .. "=" .. tostring(value) end,
  },
  ascendantUi = {
    showHelp = function(game_, label, help)
      game_.lastHelp = { label = label, help = help }
    end,
  },
})
local stack = { rows = {} }
function stack:push(value) self.rows[#self.rows + 1] = value end
function stack:pop() return table.remove(self.rows) end
function stack:top() return self.rows[#self.rows] end
local game = {
  data = Data,
  save = {
    money = 0, inventory = {}, pcItems = {}, bagOrder = {}, flags = {},
    party = {}, player = { name = "RED" },
  },
  stack = stack,
}
local pressed, emitted, optionWrites
game.input = {
  wasPressed = function(_, key)
    local hit = key == pressed
    if hit then pressed = nil end
    return hit
  end,
}
game.mods = {
  modOptions = {},
  events = { emit = function(_, name, payload)
    emitted = { name = name, payload = payload }
  end },
}
game.writeOptions = function() optionWrites = (optionWrites or 0) + 1 end
Data.balls.MASTER_BALL = { id = "MASTER_BALL" }

local s = rewards.state(game)
eq(s.expShareUnlocked, false, "new saves begin with EXP Share locked")
eq(s.expShareSetting, "off", "new EXP Share setting begins OFF")
eq(s.expMultiplierUnlocked, 0, "new saves begin with multiplier locked")
eq(s.expMultiplierSetting, 0, "new multiplier setting begins OFF")

local text, changed = rewards.unlock(game, 3)
eq(changed, false, "×3 cannot unlock before ×2")
eq(text, nil, "an impossible ×3 state awards no item")
text, changed = rewards.unlock(game, 5)
eq(changed, false, "×5 cannot unlock before ×3")

text, changed = rewards.unlock(game, "expShare")
eq(changed, true, "EXP Share unlock succeeds once")
eq(game.save.inventory.EXP_ALL, 1, "EXP Share acquisition grants its physical item")
eq(rewards.state(game).expShareSetting, "off",
  "EXP Share acquisition never auto-enables assistance")
eq(select(2, rewards.unlock(game, "expShare")), false,
  "EXP Share never drops twice")

text, changed = rewards.unlock(game, 2)
eq(changed, true, "×2 unlock succeeds at the first stage")
eq(game.save.inventory[rewards.MULTIPLIER_ITEM], 1,
  "×2 grants the single EXP Multiplier shortcut item")
eq(rewards.state(game).expMultiplierSetting, 0,
  "×2 acquisition never auto-selects itself")
rewards.setMultiplier(game, 2)
text, changed = rewards.unlock(game, 3)
eq(changed, true, "×3 unlock follows ×2")
eq(rewards.state(game).expMultiplierSetting, 2,
  "×3 retains the player's existing ×2 choice")
text, changed = rewards.unlock(game, 5)
eq(changed, true, "×5 unlock follows ×3")
eq(rewards.state(game).expMultiplierSetting, 2,
  "×5 also retains the player's existing choice")
eq(select(2, rewards.unlock(game, 5)), false, "×5 never drops twice")

-- Item placement is irrelevant: explicit unlock state controls both systems.
game.save.inventory.EXP_ALL = nil
game.save.pcItems.EXP_ALL = 1
game.save.inventory[rewards.MULTIPLIER_ITEM] = nil
game.save.pcItems[rewards.MULTIPLIER_ITEM] = 1
rewards.setExpShare(game, "team")
rewards.setMultiplier(game, 3)
eq(rewards.state(game).expShareSetting, "team",
  "EXP Share remains selectable with its item on the PC")
eq(rewards.state(game).expMultiplierSetting, 3,
  "×3 remains selectable with its item on the PC")

local a, b, c = { hp = 10 }, { hp = 10 }, { hp = 10 }
game.save.party = { a, b, c }
local allocations = {}
hooks["battle.exp_award"](function() error("vanilla award must be replaced") end, {
  battle = { game = game }, alive = { a }, participants = 1,
  applyShare = function(mon, split, announce)
    allocations[#allocations + 1] = { mon = mon, split = split, announce = announce }
  end,
})
eq(#allocations, 3, "TEAM mode awards every healthy party member")
eq(allocations[1].split, 1, "TEAM participant keeps its normal award")
eq(allocations[2].split, 2, "TEAM reserve receives a half award")
eq(allocations[3].split, 2, "every TEAM reserve receives the same half award")
eq(hooks["exp.gain"](function() return 100 end, {}), 300,
  "the final ×3 multiplier is applied once after allocation")

rewards.setExpShare(game, "classic")
allocations = {}
hooks["battle.exp_award"](function() end, {
  battle = { game = game }, alive = { a }, participants = 1,
  applyShare = function(mon, split, announce)
    allocations[#allocations + 1] = { mon = mon, split = split, announce = announce }
  end,
})
eq(#allocations, 4, "CLASSIC reproduces participant plus whole-party passes")
eq(allocations[1].split, 2, "CLASSIC participant first receives its half")
eq(allocations[2].split, 6, "CLASSIC whole-party divisor includes party size")

rewards.setExpShare(game, "off")
allocations = {}
hooks["battle.exp_award"](function() end, {
  battle = { game = game }, alive = { a }, participants = 1,
  applyShare = function(mon, split) allocations[#allocations + 1] = { mon, split } end,
})
eq(#allocations, 1, "OFF ignores the stored EXP Share item")
eq(allocations[1][2], 1, "OFF retains ordinary participant EXP")

-- Dynamic option rows expand but never expose a locked multiplier tier.
local rows = rewards.gameplayRows(game)
eq(#rows, 2, "both unlocked helper settings share one GAMEPLAY page")
local multiplierRow
for _, row in ipairs(rows) do if row.value == "exp_multiplier" then multiplierRow = row end end
ok(multiplierRow ~= nil, "GAMEPLAY contains one EXP Multiplier row")
local gameplayRoot = screens.AscendantGameplayOptions.new(game, {})
eq(#gameplayRoot.items, 5,
  "GAMEPLAY is a compact five-submenu hub")
eq(gameplayRoot.pageJump, false,
  "Ascendant option lists reserve L/R for the highlighted value")
eq(gameplayRoot.footer, "A:OPEN SEL:HELP",
  "submenu hubs advertise A and SELECT without overflowing the footer")
eq(gameplayRoot.items[1].screen, "AscendantCoreOptions",
  "core rules moved into their focused submenu")
eq(gameplayRoot.items[2].screen, "AscendantRematchOptions",
  "rematch tuning moved into its focused submenu")
eq(gameplayRoot.items[3].screen, "AscendantTrainingOptions",
  "EXP assistance moved into its focused submenu")
eq(gameplayRoot.items[4].screen, "AscendantCaptureOptions",
  "capture and storage settings have a focused submenu")
eq(gameplayRoot.items[5].screen, "AscendantControlOptions",
  "controls have a focused submenu")
gameplayRoot.onChoose(gameplayRoot.items[1])
eq(game.lastScreen.id, "AscendantCoreOptions",
  "A opens a selected submenu")

local optionsRoot = screens.AscendantOptionsRoot.new(game)
eq(#optionsRoot.items, 5,
  "root contains no empty SYSTEM submenu")
for _, row in ipairs(optionsRoot.items) do
  ok(row.value ~= "system", "root never exposes a dead SYSTEM row")
end

local core = screens.AscendantCoreOptions.new(game, {})
eq(core.footer, "L/R:CHG SEL:HELP",
  "setting pages visibly reserve Left/Right for values and SELECT for help")
eq(#core.items, 3, "core rules retain difficulty, Kanto 151 and challenge rules")
eq(core.items[1].value, "difficulty", "difficulty is first in CORE RULES")
eq(core.items[2].value, "kanto_151", "Kanto 151 remains in CORE RULES")
eq(core.items[3].value, "ascendant_rules", "challenge rules remain in CORE RULES")
eq(game.mods.modOptions.kanto_ascendant, nil,
  "opening an option page never mutates values")
core.onChoose(core.items[1])
eq(game.mods.modOptions.kanto_ascendant, nil,
  "A does not silently cycle a setting")
pressed = "right"
core:update()
eq(game.mods.modOptions.kanto_ascendant.difficulty, "hard",
  "Right advances only the highlighted setting")
eq(game.save.options.modOptions.kanto_ascendant.difficulty, "hard",
  "Right persists the selected value")
eq(emitted.name, "mod.options_changed",
  "value change emits the standard option event")
eq(emitted.payload.game, game,
  "option event carries the affected game")
pressed = "left"
core:update()
eq(game.mods.modOptions.kanto_ascendant.difficulty, "standard",
  "Left walks the selected setting backward")
pressed = "select"
core:update()
eq(game.lastHelp.label, "DIFFICULTY",
  "SELECT opens help for the highlighted option")
eq(optionWrites, 2,
  "only the two L/R changes write options")

local rematch = screens.AscendantRematchOptions.new(game, {})
eq(#rematch.items, 6,
  "active Legacy NG+ adds its frequency row to rematch tuning")
eq(rematch.items[1].value, "rest_min", "minimum rest is first in REMATCH")
eq(rematch.items[1].schema.presets[1], 151,
  "rematch recovery presets retain the 151-step floor")
eq(rematch.items[1].schema.presets[5], 2510,
  "rematch recovery presets retain the 2510-step ceiling")
eq(rematch.items[6].value, "legacy_wanderer_frequency",
  "Legacy NG+ menu exposes the stable Wanderer frequency option")
eq(#rematch.items[6].schema.choices, 4,
  "Wanderer frequency offers NEVER/RARE/NORMAL/OFTEN")
legacyRunActive = false
local ordinaryRematch = screens.AscendantRematchOptions.new(game, {})
eq(#ordinaryRematch.items, 5,
  "fresh normal campaign hides the Wanderer frequency row in-game")
for _, row in ipairs(ordinaryRematch.items) do
  ok(row.value ~= "legacy_wanderer_frequency",
    "non-NG+ in-game menu contains no inactive Wanderer control")
end
legacyRunActive = true

local contentRoot = screens.AscendantContentOptions.new(game, {})
eq(#contentRoot.items, 5,
  "WORLD exposes five clear feature groups instead of one flat list")
eq(contentRoot.items[1].screen, "AscendantAdventureOptions",
  "Adventure content has its own submenu")
eq(contentRoot.items[2].screen, "AscendantLivingWorldOptions",
  "Living Regions has a discoverable submenu")
eq(contentRoot.items[3].screen, "AscendantJohtoOptions",
  "Johto and Signals have their own submenu")
eq(contentRoot.items[4].screen, "AscendantLegendOptions",
  "legend profiles are one level deeper")
eq(contentRoot.items[5].screen, "AscendantHeritageOptions",
  "heritage event switches are one level deeper")

local visuals = screens.AscendantVisualOptions.new(game, {})
local portraitRow
for _, row in ipairs(visuals.items) do
  if row.value == "trainer_portrait_style" then portraitRow = row end
end
ok(portraitRow ~= nil,
  "trainer portrait style is reachable from the unified VISUALS menu")

local living = screens.AscendantLivingWorldOptions.new(game, {})
eq(#living.items, 3, "Living Regions is split into three focused pages")
eq(living.items[1].screen, "AscendantLivingEncounterOptions",
  "visible encounters are discoverable in Living Regions")
eq(living.items[2].screen, "AscendantLivingBehaviorOptions",
  "Pokémon behavior is discoverable in Living Regions")
eq(living.items[3].screen, "AscendantLivingTownOptions",
  "Johto and towns are discoverable in Living Regions")
local visibleEncounters = screens.AscendantLivingEncounterOptions.new(game, {})
eq(#visibleEncounters.items, 1,
  "fixture visible encounter option remains in its focused category")
eq(visibleEncounters.items[1].value, "living_world_enabled",
  "visible wild Pokémon is first in VISIBLE ENCOUNTERS")

local gameplay = screens.AscendantTrainingOptions.new(game, {
  focus = "exp_multiplier",
})
eq(gameplay.index, 2, "item shortcut focus lands on the multiplier row")
gameplay.onChoose(gameplay.items[2])
eq(rewards.state(game).expMultiplierSetting, 3,
  "A preserves the selected training helper value")
gameplay:ascendantStep(1)
eq(rewards.state(game).expMultiplierSetting, 5,
  "Right cycles only through unlocked OFF/×2/×3/×5 choices")
gameplay:ascendantStep(-1)
eq(rewards.state(game).expMultiplierSetting, 3,
  "Left cycles training helper choices backward")

local startRows = hooks["ui.start_menu.items"](function(_, rows_) return rows_ end,
  game, {})
eq(startRows[1].ascendantMenu, true,
  "OPTIONS is routed into the centralized Ascendant menu")
eq(startRows[1].ascendantOrder, 1,
  "OPTIONS appears first in the Ascendant menu tree")

-- Deterministic reward flow: specials, item, then exact money fallback.
bucket.rematch_rewards = {
  version = 1, expShareUnlocked = true, expShareSetting = "off",
  expMultiplierUnlocked = 5, expMultiplierSetting = 0, pendingItems = {},
}
game.save.inventory, game.save.pcItems, game.save.bagOrder = {}, {}, {}
game.save.money = 0
local holder = {}
local battle = {
  trainer = { name = "BUG CATCHER" },
  enemyParty = { { level = 50 } },
}
local rewardText = rewards.afterWin(game, battle, holder, {
  rewardRolls = { normal = 1, money = 1 },
})
eq(game.save.inventory.POKE_BALL, 3,
  "normal reward flow grants the required Poké Ball ×3 stack")
ok(rewardText:find("POKE BALL", 1, true) ~= nil,
  "normal item reward is announced")

game.save.money = 0
rewardText = rewards.afterWin(game, battle, holder, {
  rewardRolls = { normal = loot.ROLL_MAX, money = 4501 },
})
eq(game.save.money, 500,
  "a failed normal item roll grants the separate normal money fallback")
ok(rewardText:find("500", 1, true) ~= nil, "money fallback is announced")

battle.enemyParty = { { level = 100 }, { level = 100 } }
game.save.money = 0
rewards.afterWin(game, battle, holder, {
  rewardRolls = { normal = loot.ROLL_MAX, money = 1 },
})
eq(game.save.money, 1000,
  "Level-100 no-item reward uses the distinct premium money pool")

mode = "off"
game.save.money = 0
local beforeItems = game.save.inventory.POKE_BALL
rewards.afterWin(game, battle, holder, {
  rewardRolls = { normal = 1, money = 10000 },
})
eq(game.save.money, 0, "REMATCH LOOT OFF disables normal item/money rewards")
eq(game.save.inventory.POKE_BALL, beforeItems,
  "REMATCH LOOT OFF does not add a normal item")
mode = "balanced"

-- A permanently full Bag must not make the save grow once per rematch.
bucket.rematch_rewards.pendingItems = {
  { item = "POKE_BALL", qty = 3, reason = "normal", trainer = "BUG CATCHER" },
  { item = "POKE_BALL", qty = 5, reason = "normal", trainer = "BUG CATCHER" },
  { item = "PP_UP", qty = 1, reason = "normal", trainer = "BUG CATCHER" },
}
local compacted = rewards.state(game)
eq(#compacted.pendingItems, 2,
  "legacy duplicate pending rewards compact into bounded item stacks")
eq(compacted.pendingItems[1].qty, 8,
  "pending reward compaction preserves the complete quantity")

-- Old-save migration is based on the real EXP.ALL/flag state and stays OFF.
bucket.rematch_rewards = nil
game.save.inventory, game.save.pcItems = {}, { EXP_ALL = 1 }
local migrated = rewards.state(game)
eq(migrated.expShareUnlocked, true,
  "an old save with EXP.ALL on the PC migrates to explicit unlock state")
eq(migrated.expShareSetting, "off",
  "old EXP.ALL migration does not silently activate sharing")

-- Wanderer catch-up uses the same unlock controller, but opts into the
-- stronger Bag -> PC -> pending placement contract. Ordinary rematch calls
-- above intentionally keep their historical Bag -> pending behavior.
bucket.rematch_rewards = nil
game.save.inventory, game.save.bagOrder = { POKE_BALL = 1 }, { "POKE_BALL" }
game.save.pcItems, game.save.pcOrder, game.save.flags = {}, {}, {}
Data.constants = Data.constants or {}
Data.constants.bagSize = 1
Data.field = Data.field or {}
Data.field.pcItemCap = 50
local catchup = rewards.catchupStatus(game)
ok(catchup.expShareMissing and catchup.multiplier2Missing,
  "fresh controller exposes both registered catch-up bands")
local catchText, catchChanged, catchPlacement = rewards.unlock(
  game, "expShare", { pcFallback = true, source = "legacy_wanderer" })
ok(catchChanged and catchPlacement == "pc",
  "full Bag sends Wanderer EXP Share catch-up to the PC")
eq(game.save.pcItems.EXP_ALL, 1,
  "PC receives exactly one physical EXP Share item")
contains(catchText, "PC", "catch-up unlock reports its real PC placement")
ok(not rewards.catchupStatus(game).expShareMissing,
  "unlocked/PC-owned EXP Share immediately leaves its catch-up band")
eq(select(2, rewards.unlock(game, "expShare", { pcFallback = true })), false,
  "replayed catch-up cannot duplicate the EXP Share")
eq(game.save.pcItems.EXP_ALL, 1,
  "duplicate catch-up callback leaves the PC stack exact-once")

catchText, catchChanged, catchPlacement = rewards.unlock(
  game, 2, { pcFallback = true, source = "legacy_wanderer" })
ok(catchChanged and catchPlacement == "pc",
  "first ×2 helper also follows the Wanderer PC fallback")
eq(game.save.pcItems[rewards.MULTIPLIER_ITEM], 1,
  "PC receives exactly one physical multiplier shortcut")
eq(rewards.state(game).expMultiplierUnlocked, 2,
  "physical ×2 catch-up and functional controller state commit together")
ok(not rewards.catchupStatus(game).multiplier2Missing,
  "unlocked/PC-owned ×2 helper immediately leaves its catch-up band")
eq(rewards.catchupStatus(game).nextMultiplier, 3,
  "functional ×2 exposes exactly the next ×3 Wanderer catch-up stage")
local physicalMultiplierCount = game.save.pcItems[rewards.MULTIPLIER_ITEM]
catchText, catchChanged, catchPlacement = rewards.unlock(
  game, 3, { pcFallback = true, source = "legacy_wanderer" })
ok(catchChanged and catchPlacement == "owned",
  "×3 commits through the controller as a state-only follow-up")
eq(game.save.pcItems[rewards.MULTIPLIER_ITEM], physicalMultiplierCount,
  "×3 never duplicates the physical multiplier shortcut")
eq(rewards.catchupStatus(game).nextMultiplier, 5,
  "functional ×3 exposes exactly the final ×5 stage")
catchText, catchChanged, catchPlacement = rewards.unlock(
  game, 5, { pcFallback = true, source = "legacy_wanderer" })
ok(catchChanged and catchPlacement == "owned",
  "×5 commits through the same state controller without a new item")
eq(game.save.pcItems[rewards.MULTIPLIER_ITEM], physicalMultiplierCount,
  "×5 also leaves the physical shortcut exact-once")
eq(rewards.catchupStatus(game).nextMultiplier, nil,
  "fully unlocked ×5 removes all multiplier catch-up bands")

bucket.rematch_rewards = nil
game.save.inventory, game.save.bagOrder = { POKE_BALL = 1 }, { "POKE_BALL" }
game.save.pcItems, game.save.pcOrder, game.save.flags =
  { POKE_BALL = 1 }, { "POKE_BALL" }, {}
Data.field.pcItemCap = 1
catchText, catchChanged, catchPlacement = rewards.unlock(
  game, "expShare", { pcFallback = true, source = "legacy_wanderer" })
ok(catchChanged and catchPlacement == "pending",
  "full Bag and PC reserve the Wanderer catch-up safely")
eq(#rewards.state(game).pendingItems, 1,
  "catch-up creates one persistent controller reservation")
ok(not rewards.catchupStatus(game).expShareMissing,
  "pending catch-up is removed from future reward weight")
game.save.inventory, game.save.bagOrder = {}, {}
local pendingText, pendingDelivered = rewards.deliverPending(game)
ok(pendingDelivered and type(pendingText) == "string",
  "making Bag room delivers the reserved catch-up")
eq(game.save.inventory.EXP_ALL, 1,
  "reserved EXP Share is delivered exactly once")
eq(select(2, rewards.deliverPending(game)), false,
  "delivered catch-up reservation cannot be claimed twice")
eq(game.save.inventory.EXP_ALL, 1,
  "second delivery attempt leaves the physical helper exact-once")

bucket.rematch_rewards = nil
game.save.inventory, game.save.pcItems, game.save.flags = {}, {
  [rewards.MULTIPLIER_ITEM] = 1,
}, {}
local repairedCatchup = rewards.catchupStatus(game)
ok(not repairedCatchup.multiplier2Missing,
  "an already-owned multiplier item never re-enters the catch-up band")
eq(rewards.state(game).expMultiplierUnlocked, 2,
  "item-only multiplier saves are repaired to functional ×2 state")

-- MASTER BALL is a separate, live-registered post-HOF rematch roll. It is
-- absent before HOF and while loot is OFF, grants ×1, and uses the same
-- exact-once Bag -> PC -> pending controller transaction.
local function masteredRewardState()
  bucket.rematch_rewards = {
    version = 2, expShareUnlocked = true, expShareSetting = "off",
    expMultiplierUnlocked = 5, expMultiplierSetting = 0,
    pendingItems = {}, masterReceipts = {}, masterReceiptOrder = {},
  }
end

masteredRewardState()
game.save.hallOfFame, game.save.flags = nil, {}
game.save.inventory, game.save.bagOrder = {}, {}
local preHofBattle = {
  trainer = { name = "ACE" }, rematchTrainerKey = "route:ace",
  rematchNumber = 1, enemyParty = { { level = 80 } },
}
rewards.afterWin(game, preHofBattle, {}, { rewardRolls = {
  rematchMaster = 1, normal = loot.ROLL_MAX, money = 1,
} })
eq(game.save.inventory.MASTER_BALL, nil,
  "pre-HOF rematches have zero Master Ball chance")

game.save.hallOfFame = { { trainer = "RIVAL" } }
for roll = 1, 50 do
  local b = {
    trainer = { name = "ACE" }, rematchTrainerKey = "route:ace",
    rematchNumber = roll, enemyParty = { { level = 80 } },
  }
  rewards.afterWin(game, b, {}, { rewardRolls = {
    rematchMaster = roll, normal = loot.ROLL_MAX, money = 1,
  } })
end
eq(game.save.inventory.MASTER_BALL, 1,
  "enumerating all 50 post-HOF rolls yields exactly one Master Ball")

local duplicateBattle = {
  trainer = { name = "ACE" }, rematchTrainerKey = "route:ace",
  rematchNumber = 51, enemyParty = { { level = 80 } },
}
rewards.afterWin(game, duplicateBattle, {}, { rewardRolls = {
  rematchMaster = 1, normal = loot.ROLL_MAX, money = 1,
} })
rewards.afterWin(game, duplicateBattle, {}, { rewardRolls = {
  rematchMaster = 1, normal = loot.ROLL_MAX, money = 1,
} })
eq(game.save.inventory.MASTER_BALL, 2,
  "duplicate victory callback cannot duplicate a rematch Master Ball")

mode = "off"
local beforeOff = game.save.inventory.MASTER_BALL
rewards.afterWin(game, {
  trainer = { name = "ACE" }, rematchTrainerKey = "route:ace",
  rematchNumber = 52, enemyParty = { { level = 80 } },
}, {}, { rewardRolls = { rematchMaster = 1 } })
eq(game.save.inventory.MASTER_BALL, beforeOff,
  "REMATCH LOOT OFF also disables the separate Master Ball roll")
mode = "balanced"

masteredRewardState()
Data.constants.bagSize, Data.field.pcItemCap = 1, 50
game.save.inventory, game.save.bagOrder = { POKE_BALL = 1 }, { "POKE_BALL" }
game.save.pcItems, game.save.pcOrder = {}, {}
local pcMasterBattle = {
  trainer = { name = "ACE" }, rematchTrainerKey = "route:pc-master",
  rematchNumber = 1, enemyParty = { { level = 80 } },
}
local pcMasterText = rewards.afterWin(game, pcMasterBattle, {}, {
  rewardRolls = { rematchMaster = 1 },
})
eq(game.save.pcItems.MASTER_BALL, 1,
  "full Bag sends the ×1 rematch Master Ball to PC storage")
contains(pcMasterText, "PC", "rematch Master Ball announces PC placement")

masteredRewardState()
Data.field.pcItemCap = 1
game.save.inventory, game.save.bagOrder = { POKE_BALL = 1 }, { "POKE_BALL" }
game.save.pcItems, game.save.pcOrder = { GREAT_BALL = 1 }, { "GREAT_BALL" }
local pendingMasterBattle = {
  trainer = { name = "ACE" }, rematchTrainerKey = "route:pending-master",
  rematchNumber = 1, enemyParty = { { level = 80 } },
}
rewards.afterWin(game, pendingMasterBattle, {}, {
  rewardRolls = { rematchMaster = 1 },
})
eq(#rewards.state(game).pendingItems, 1,
  "full Bag and PC create one persistent Master Ball reservation")
eq(rewards.state(game).pendingItems[1].item, "MASTER_BALL",
  "pending rematch transaction keeps the exact rare item")
rewards.afterWin(game, pendingMasterBattle, {}, {
  rewardRolls = { rematchMaster = 1 },
})
eq(#rewards.state(game).pendingItems, 1,
  "replayed pending Master Ball receipt remains exact-once")
game.save.inventory, game.save.bagOrder = {}, {}
local deliveredMasterText, deliveredMaster = rewards.deliverPending(game)
ok(deliveredMaster and type(deliveredMasterText) == "string",
  "reserved rematch Master Ball delivers after Bag space returns")
eq(game.save.inventory.MASTER_BALL, 1,
  "reserved Master Ball arrives exactly once")
eq(select(2, rewards.deliverPending(game)), false,
  "delivered rematch Master Ball cannot be claimed twice")

print(("REMATCH PHASE 8 PASS: %d assertions"):format(assertions))
