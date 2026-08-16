-- Fighting Dojo prize safety for engine 0.1.96/0.1.98.
--
-- The base script records the prize flags before it knows whether the gift
-- fits in PARTY/PC storage, and it never checks Commands.give_pokemon's
-- lastCheck result.  Keep the authored Pokédex preview and YES/NO flow, but
-- make the actual withdrawal one fail-closed save transaction.  This module
-- deliberately recognizes only the two canonical Dojo object/text ids.

return function(mod, opts)
  opts = opts or {}
  local i18n = opts.i18n
  local D = {}

  local MAP_ID = "FIGHTING_DOJO"
  local BALLS = {
    TEXT_FIGHTINGDOJO_HITMONLEE_POKE_BALL = {
      species = "HITMONLEE",
      object = "FIGHTINGDOJO_HITMONLEE_POKE_BALL",
      ask = "_FightingDojoHitmonleePokeBallText",
    },
    TEXT_FIGHTINGDOJO_HITMONCHAN_POKE_BALL = {
      species = "HITMONCHAN",
      object = "FIGHTINGDOJO_HITMONCHAN_POKE_BALL",
      ask = "_FightingDojoHitmonchanPokeBallText",
    },
  }
  local BY_OBJECT = {}
  for textId, row in pairs(BALLS) do
    row.text = textId
    BY_OBJECT[row.object] = row
  end

  local function tr(english, german)
    return i18n and i18n.text(english, german) or english
  end

  local function copy(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}
    seen[value] = out
    for key, child in pairs(value) do
      out[copy(key, seen)] = copy(child, seen)
    end
    return out
  end

  -- Restore rather than replace the live save.  Loader.modSave and several
  -- controllers retain references into save.modData; preserving every
  -- existing table identity makes Randomizer mappings roll back in both the
  -- serialized save and its live authority object.
  local function restoreInto(target, snapshot, seen)
    if type(target) ~= "table" or type(snapshot) ~= "table" then return end
    seen = seen or {}
    if seen[snapshot] then return end
    seen[snapshot] = target
    for key in pairs(target) do
      if snapshot[key] == nil then target[key] = nil end
    end
    for key, value in pairs(snapshot) do
      if type(value) == "table" then
        local linked = seen[value]
        if linked then
          target[key] = linked
        else
          if type(target[key]) ~= "table" then target[key] = {} end
          restoreInto(target[key], value, seen)
        end
      else
        target[key] = value
      end
    end
  end

  local function commands()
    return opts.commands or require("src.script.Commands")
  end

  local function dexEntryMenu()
    return opts.dexEntryMenu or require("src.ui.DexEntryMenu")
  end

  local function textBox()
    return opts.textBox or require("src.render.TextBox")
  end

  local function push(game, text, onDone, boxOpts)
    game.stack:push(textBox().new(game, text, onDone, boxOpts))
  end

  local function stackDepth(game)
    local states = game and game.stack and game.stack.states
    return type(states) == "table" and #states or nil
  end

  local function unwind(game, depth)
    if depth == nil or not (game and game.stack and game.stack.states
        and type(game.stack.pop) == "function") then return end
    while #game.stack.states > depth do game.stack:pop() end
  end

  local function resyncBall(Commands, ctx, object, visible)
    if visible == false then
      Commands.hide_object(ctx, MAP_ID, object)
    else
      Commands.show_object(ctx, MAP_ID, object)
    end
  end

  local function restoreWorld(game, ctx, before, depth)
    restoreInto(game.save, before.save)
    game.stringBuffer = before.stringBuffer
    game.boxMonNicks = before.boxMonNicks
    game.boxNumString = before.boxNumString
    unwind(game, depth)

    -- Commands.hide_object mutates both save.objectToggles and the current
    -- NPC/entity lists.  Reconcile those lists after restoring the save, then
    -- restore the exact tri-state toggle snapshot (nil/true/false).
    local Commands = commands()
    local mapBefore = before.save.objectToggles
      and before.save.objectToggles[MAP_ID] or nil
    for _, row in pairs(BALLS) do
      local visible = mapBefore == nil or mapBefore[row.object] ~= false
      local ok = pcall(resyncBall, Commands, ctx, row.object, visible)
      if not ok and mod and mod.log then
        mod.log:warn("Fighting Dojo object rollback failed for %s", row.object)
      end
    end
    restoreInto(game.save, before.save)
  end

  local function failureText(reason)
    if reason == "storage_full" then
      return tr(
        "Your PARTY and all\nPC BOXES are full!\fThe Dojo prize was\nnot taken.",
        "TEAM und alle\nPC-BOXEN sind voll!\fDer Dojo-Preis wurde\nnicht genommen.")
    end
    return tr(
      "The save failed.\fThe Dojo prize was\nnot taken.\nPlease try again.",
      "Speichern fehlgeschlagen.\fDer Dojo-Preis wurde\nnicht genommen.\nBitte erneut versuchen.")
  end

  -- Exposed for deterministic fault-injection tests.  No flag or object is
  -- committed until Commands.give_pokemon succeeded; a failed persistence
  -- attempt restores the entire live save, including Randomizer mappings.
  function D.claim(game, ow, row)
    if not (game and game.save and row and row.species and row.object) then
      return false, "invalid"
    end
    local Commands = commands()
    local ctx = { save = game.save, game = game, overworld = ow }
    local depth = stackDepth(game)
    local before = {
      save = copy(game.save),
      stringBuffer = game.stringBuffer,
      boxMonNicks = game.boxMonNicks,
      boxNumString = game.boxNumString,
    }

    local ok, err = pcall(function()
      Commands.give_pokemon(ctx, row.species, 30)
      if ctx.lastCheck ~= true then error("storage_full", 0) end
      game.save.flags = game.save.flags or {}
      game.save.flags["EVENT_GOT_" .. row.species] = true
      game.save.flags.EVENT_DEFEATED_FIGHTING_DOJO = true
      Commands.hide_object(ctx, MAP_ID, row.object)
    end)
    if not ok then
      local reason = tostring(err) == "storage_full"
        and "storage_full" or "mutation_failed"
      restoreWorld(game, ctx, before, depth)
      return false, reason
    end

    local called, wrote = false, false
    if type(game.writeSave) == "function" then
      called, wrote = pcall(game.writeSave, game)
    end
    if not called or wrote == false then
      restoreWorld(game, ctx, before, depth)
      return false, "save_failed"
    end

    local actual = ctx.pendingPokemonName or game.stringBuffer or row.species
    ctx.pendingPokemonName = nil
    local def = game.data and game.data.pokemon
      and game.data.pokemon[actual] or nil
    return true, actual, def and def.name or tostring(actual)
  end

  local function rowFor(ow, npc)
    if not (ow and ow.map and ow.map.id == MAP_ID and npc and npc.def) then
      return nil
    end
    return BALLS[npc.def.text] or BY_OBJECT[npc.def.name]
  end

  function D.handleTalk(ow, npc, game)
    local row = rowFor(ow, npc)
    if not row then return false end

    local save = game and game.save
    local flags = save and save.flags or {}
    npc.frozen = true
    if npc.facePlayer and ow.player then npc:facePlayer(ow.player) end
    local done = function() npc.frozen = false end
    local texts = game.data and game.data.text or {}

    if flags.EVENT_GOT_HITMONLEE or flags.EVENT_GOT_HITMONCHAN then
      push(game, texts._FightingDojoBetterNotGetGreedyText
        or tr("Better not get\ngreedy...", "Sei nicht so\ngierig..."), done)
      return true
    end
    if not flags.EVENT_BEAT_KARATE_MASTER then
      push(game, tr(
        "You'll have to\nbeat the master\nfirst!",
        "Besiege zuerst\nden Meister!"), done)
      return true
    end

    local Commands = commands()
    Commands.mark_seen({ save = save, game = game, overworld = ow }, row.species)
    game.stack:push(dexEntryMenu().new(game, row.species, function()
      local question = texts[row.ask] or ("You want\n" .. row.species .. "?")
      push(game, question, nil, { choice = function(yes)
        if not yes then done() return end
        local claimed, reason, actualName = D.claim(game, ow, row)
        if not claimed then
          push(game, failureText(reason), done)
          return
        end
        local player = save.player and save.player.name or "PLAYER"
        push(game, tr("%s got\n%s!", "%s erhält\n%s!")
          :format(player, actualName), done)
      end })
    end))
    return true
  end

  D.MAP_ID = MAP_ID
  D.BALLS = BALLS
  D.copy = copy
  D.restoreInto = restoreInto
  return D
end
