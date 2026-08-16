-- Fighting Dojo prize transaction regression matrix.
--
-- This is intentionally ROM-free: the two engine releases are covered by
-- dojo_prizes_engine_test.lua, while this suite exhausts every failure and
-- retry branch with deterministic injected Commands.

local root = assert(os.getenv("TRAINER_REMATCH_MOD_DIR"),
  "TRAINER_REMATCH_MOD_DIR is required")

local checks = 0
local function ok(value, message)
  checks = checks + 1
  if not value then error("FAIL: " .. message, 2) end
end
local function eq(actual, expected, message)
  ok(actual == expected, message .. " (expected " .. tostring(expected)
    .. ", got " .. tostring(actual) .. ")")
end

local function deepEqual(left, right, seen)
  if type(left) ~= type(right) then return false end
  if type(left) ~= "table" then return left == right end
  seen = seen or {}
  if seen[left] == right then return true end
  seen[left] = right
  for key, value in pairs(left) do
    if not deepEqual(value, right[key], seen) then return false end
  end
  for key in pairs(right) do
    if left[key] == nil then return false end
  end
  return true
end

local function clone(value, seen)
  if type(value) ~= "table" then return value end
  seen = seen or {}
  if seen[value] then return seen[value] end
  local out = {}
  seen[value] = out
  for key, child in pairs(value) do out[clone(key, seen)] = clone(child, seen) end
  return out
end

local function boxes(full)
  local out = {}
  for box = 1, 12 do
    out[box] = {}
    if full then
      for slot = 1, 20 do
        out[box][slot] = { species = "FILLER", serial = box * 100 + slot }
      end
    end
  end
  return out
end

local function stack()
  return {
    states = {},
    push = function(self, value) self.states[#self.states + 1] = value end,
    pop = function(self) return table.remove(self.states) end,
    top = function(self) return self.states[#self.states] end,
  }
end

local function makeCommands()
  local C = {}
  function C.mark_seen(ctx, species)
    ctx.save.pokedex.seen[species] = true
  end
  function C.give_pokemon(ctx, species, level)
    local rules = ctx.save.modData.kanto_ascendant.run_rules
    if rules.randomizer.enabled then
      local key = "gift:" .. species
      rules.mappings.species[key] = "MAPPED_" .. species
      rules.finalRules.mappings.species[key] = "MAPPED_" .. species
      species = "MAPPED_" .. species
    end
    ctx.pendingPokemonName = species
    ctx.game.stringBuffer = species
    local mon = { species = species, level = level }
    if #ctx.save.party < 6 then
      ctx.save.party[#ctx.save.party + 1] = mon
    else
      local deposited
      for index = 1, 12 do
        if #ctx.save.boxes[index] < 20 then
          ctx.save.boxes[index][#ctx.save.boxes[index] + 1] = mon
          deposited = index
          break
        end
      end
      if not deposited then ctx.lastCheck = false return end
      ctx.game.stack:push({ kind = "sent_to_box", box = deposited })
    end
    ctx.save.pokedex.seen[species] = true
    ctx.save.pokedex.owned[species] = true
    ctx.lastCheck = true
  end
  local function toggle(ctx, map, object, visible)
    ctx.save.objectToggles = ctx.save.objectToggles or {}
    ctx.save.objectToggles[map] = ctx.save.objectToggles[map] or {}
    ctx.save.objectToggles[map][object] = visible
    ctx.overworld.visible[object] = visible
  end
  function C.hide_object(ctx, map, object) toggle(ctx, map, object, false) end
  function C.show_object(ctx, map, object) toggle(ctx, map, object, true) end
  return C
end

local TextBox = {
  new = function(_, text, onDone, opts)
    return { kind = "text", text = text, onDone = onDone, opts = opts }
  end,
}
local DexEntryMenu = {
  new = function(_, species, onDone)
    return { kind = "dex", species = species, onDone = onDone }
  end,
}

local function fixture(edition, locale, randomizer, storage, writeMode)
  local i18n = { text = function(en, de) return locale == "de" and de or en end }
  local commands = makeCommands()
  local dojo = assert(loadfile(root .. "/dojo_prizes.lua"))()({
    log = { warn = function() end },
  }, {
    i18n = i18n, commands = commands,
    textBox = TextBox, dexEntryMenu = DexEntryMenu,
  })
  local party = {}
  if storage ~= "party" then
    for index = 1, 6 do party[index] = { species = "FILLER", serial = index } end
  end
  local save = {
    version = edition,
    player = { name = edition:upper(), id = 1234 },
    flags = { EVENT_BEAT_KARATE_MASTER = true },
    party = party,
    boxes = boxes(storage == "full"), currentBox = 1,
    pokedex = { seen = {}, owned = {} },
    objectToggles = {},
    modData = { kanto_ascendant = { run_rules = {
      randomizer = { enabled = randomizer, gifts = randomizer },
      mappings = { species = {}, items = {} },
      finalRules = { mappings = { species = {}, items = {} } },
    } } },
  }
  local game = {
    save = save,
    data = { pokemon = {
      HITMONLEE = { name = "HITMONLEE" },
      HITMONCHAN = { name = "HITMONCHAN" },
      MAPPED_HITMONLEE = { name = "MAPPED LEE" },
      MAPPED_HITMONCHAN = { name = "MAPPED CHAN" },
    }, text = {
      _FightingDojoHitmonleePokeBallText = "LEE?",
      _FightingDojoHitmonchanPokeBallText = "CHAN?",
      _FightingDojoBetterNotGetGreedyText = "GREEDY",
    } },
    stack = stack(), writes = 0,
  }
  function game:writeSave()
    self.writes = self.writes + 1
    if writeMode == "false" and self.writes == 1 then return false end
    if writeMode == "throw" and self.writes == 1 then error("disk full") end
    return true
  end
  local ow = {
    map = { id = "FIGHTING_DOJO" }, player = {},
    visible = {
      FIGHTINGDOJO_HITMONLEE_POKE_BALL = true,
      FIGHTINGDOJO_HITMONCHAN_POKE_BALL = true,
    },
  }
  local npc = {
    def = {
      name = "FIGHTINGDOJO_HITMONLEE_POKE_BALL",
      text = "TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL",
    },
    frozen = false,
    facePlayer = function(self) self.faced = true end,
  }
  return dojo, game, ow, npc
end

local editions = { "red", "blue", "yellow" }
local locales = { "en", "de" }
local randomizers = { false, true }

-- A/YES and ChoiceBox/NO use the same production callback.  Exercise both
-- on all editions/languages/randomizer states before the transaction matrix.
for _, edition in ipairs(editions) do
  for _, locale in ipairs(locales) do
    for _, randomizer in ipairs(randomizers) do
      local label = edition .. "/" .. locale .. "/rnd=" .. tostring(randomizer)
      local dojo, game, ow, npc = fixture(edition, locale, randomizer, "party")
      ok(dojo.handleTalk(ow, npc, game), label .. " canonical ball is handled")
      local dex = game.stack:top()
      eq(dex.kind, "dex", label .. " opens the Pokédex preview")
      eq(type(dex.onDone), "function", label .. " preview keeps its continuation")
      eq(game.save.pokedex.seen.HITMONLEE, true, label .. " preview marks seen")
      game.stack:pop()
      dex.onDone()
      local prompt = game.stack:top()
      eq(type(prompt.opts.choice), "function", label .. " prompt owns ChoiceBox callback")
      game.stack:pop()
      prompt.opts.choice(false)
      eq(#game.save.party, 0, label .. " NO leaves storage unchanged")
      eq(game.save.flags.EVENT_GOT_HITMONLEE, nil, label .. " NO leaves flag clear")
      eq(npc.frozen, false, label .. " NO unfreezes the ball NPC")
    end
  end
end

local storageModes = { "party", "box", "full" }
for _, edition in ipairs(editions) do
  for _, locale in ipairs(locales) do
    for _, randomizer in ipairs(randomizers) do
      for _, storage in ipairs(storageModes) do
        local label = table.concat({ edition, locale,
          "rnd=" .. tostring(randomizer), storage }, "/")
        local dojo, game, ow = fixture(edition, locale, randomizer, storage)
        local row = dojo.BALLS.TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL
        local before = clone(game.save)
        local claimed, reason, name = dojo.claim(game, ow, row)
        if storage == "full" then
          eq(claimed, false, label .. " refuses full PARTY+PC")
          eq(reason, "storage_full", label .. " reports storage-full")
          ok(deepEqual(game.save, before), label .. " full storage rolls save back")
          eq(ow.visible[row.object], true, label .. " full storage keeps ball visible")
          eq(game.writes, 0, label .. " full storage never persists a partial gift")
        else
          eq(claimed, true, label .. " accepts available storage")
          eq(game.save.flags.EVENT_GOT_HITMONLEE, true,
            label .. " commits chosen flag after delivery")
          eq(game.save.flags.EVENT_DEFEATED_FIGHTING_DOJO, true,
            label .. " commits Dojo completion after delivery")
          eq(ow.visible[row.object], false, label .. " hides only chosen ball")
          eq(game.writes, 1, label .. " persists exactly once")
          if randomizer then
            eq(name, "MAPPED LEE", label .. " receipt uses mapped gift name")
            eq(game.save.modData.kanto_ascendant.run_rules
              .mappings.species["gift:HITMONLEE"], "MAPPED_HITMONLEE",
              label .. " commits live Randomizer mapping")
          else
            eq(name, "HITMONLEE", label .. " receipt uses authored gift name")
          end
        end
      end
    end
  end
end

-- writeSave false/throw must restore the complete save and live visibility;
-- a second attempt on that same object then succeeds without duplicate data.
for _, mode in ipairs({ "false", "throw" }) do
  for _, randomizer in ipairs(randomizers) do
    local label = mode .. "/rnd=" .. tostring(randomizer)
    local dojo, game, ow = fixture("yellow", "de", randomizer, "box", mode)
    local row = dojo.BALLS.TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL
    local before = clone(game.save)
    local claimed, reason = dojo.claim(game, ow, row)
    eq(claimed, false, label .. " first persistence attempt fails closed")
    eq(reason, "save_failed", label .. " distinguishes persistence failure")
    ok(deepEqual(game.save, before), label .. " persistence rollback is complete")
    eq(ow.visible[row.object], true, label .. " persistence rollback restores ball")
    eq(#game.stack.states, 0, label .. " persistence rollback removes box UI")
    claimed = dojo.claim(game, ow, row)
    eq(claimed, true, label .. " retry succeeds on the same live game")
    eq(#game.save.boxes[1], 1, label .. " retry deposits exactly one prize")
  end
end

-- Once either prize commits, the other ball remains present but is a strict
-- greedy refusal and can never hand out a second reward.
do
  local dojo, game, ow, npc = fixture("red", "en", true, "party")
  local lee = dojo.BALLS.TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL
  eq(dojo.claim(game, ow, lee), true, "first prize commits for greedy gate")
  npc.def.name = "FIGHTINGDOJO_HITMONCHAN_POKE_BALL"
  npc.def.text = "TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL"
  eq(ow.visible.FIGHTINGDOJO_HITMONCHAN_POKE_BALL, true,
    "unchosen ball remains in the room")
  ok(dojo.handleTalk(ow, npc, game), "remaining ball is handled")
  eq(game.stack:top().text, "GREEDY", "remaining ball shows greedy refusal")
  eq(game.save.flags.EVENT_GOT_HITMONCHAN, nil,
    "remaining ball cannot grant a second prize")
end

-- Exact scoping: unrelated maps and objects must remain on the native script.
do
  local dojo, game, ow, npc = fixture("blue", "en", false, "party")
  ow.map.id = "SAFFRON_CITY"
  eq(dojo.handleTalk(ow, npc, game), false, "other maps remain native")
  ow.map.id = "FIGHTING_DOJO"
  npc.def.name, npc.def.text = "OTHER", "TEXT_OTHER"
  eq(dojo.handleTalk(ow, npc, game), false, "other Dojo objects remain native")
end

print(("DOJO PRIZES PASS: %d checks (R/B/Y, EN/DE, Randomizer OFF/ON)")
  :format(checks))
