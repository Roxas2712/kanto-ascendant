-- Optional post-catch destination prompt.  It never changes the capture
-- result; it only moves the newly stored record from the party to the active
-- box after the engine has completed its normal catch bookkeeping.

return function(mod)
  local Boxes = require("src.pokemon.Boxes")
  local ChoiceBox = require("src.ui.ChoiceBox")
  local TextBox = require("src.render.TextBox")
  local Party = require("src.pokemon.Party")

  local pending = setmetatable({}, { __mode = "k" })

  local function tr(game, en, de)
    local german = mod.find("deutsch") or mod.find("deutsch-blau")
      or mod.find("deutsch-gelb")
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    local language = bucket and bucket.language
    if language == nil then language = mod.options:get("language") end
    german = german or language == "de"
    return german and de or en
  end

  local function isInParty(save, mon)
    for i, candidate in ipairs(save.party or {}) do
      if candidate == mon then return i end
    end
    return nil
  end

  local function moveToBox(game, mon, partyIndex)
    local save = game.save
    local box = Boxes.active(save)
    if not box or #box >= Boxes.CAPACITY then return false end
    table.remove(save.party, partyIndex)
    table.insert(box, mon)
    return true
  end

  local function locateInBoxes(save, mon)
    for boxIndex, box in ipairs(Boxes.ensure(save)) do
      for monIndex, candidate in ipairs(box) do
        if candidate == mon then return boxIndex, monIndex end
      end
    end
    return nil
  end

  local function moveBoxCatchToParty(game, mon, partyIndex)
    local boxIndex, monIndex = locateInBoxes(game.save, mon)
    if not boxIndex then return false end
    local box = game.save.boxes[boxIndex]
    if #game.save.party < Party.MAX then
      table.remove(box, monIndex)
      table.insert(game.save.party, mon)
      return true
    end
    local leaving = game.save.party[partyIndex]
    if not leaving then return false end
    box[monIndex] = leaving
    game.save.party[partyIndex] = mon
    return true
  end

  local function choosePartyReplacement(game, caught)
    local rows = {}
    for index, partyMon in ipairs(game.save.party or {}) do
      local def = game.data.pokemon[partyMon.species] or {}
      rows[#rows + 1] = {
        value = index,
        label = partyMon.nickname or def.name or partyMon.species,
        right = ("Lv.%d"):format(partyMon.level or 0),
      }
    end
    game.stack:push(mod.ui.ListMenu.new(game,
      tr(game, "SEND WHICH TO BOX?", "WER SOLL IN DIE BOX?"), rows, {
        onChoose = function(row, list)
          if moveBoxCatchToParty(game, caught, row.value) then
            list:close()
            local def = game.data.pokemon[caught.species] or {}
            local name = caught.nickname or def.name or caught.species
            game.stack:push(TextBox.new(game, tr(game,
              ("%s joined the\nPARTY!"):format(name),
              ("%s ist jetzt\nim TEAM!"):format(name))))
          end
        end,
      }))
  end

  local function keepInParty(game, mon)
    local partyIndex = isInParty(game.save, mon)
    if partyIndex then return true end
    if #game.save.party < Party.MAX then
      return moveBoxCatchToParty(game, mon, 1)
    end
    choosePartyReplacement(game, mon)
    return true
  end

  local function setting(game)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    return (bucket and bucket.catch_destination)
      or mod.options:get("catch_destination")
      or "ask"
  end

  local function option(game, key, fallback)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    local value = bucket and bucket[key]
    if value == nil then value = mod.options:get(key) end
    if value == nil then return fallback end
    return value
  end

  local function announceBox(game, battle, mon)
    if option(game, "catch_box_notice", true) == false then return end
    local boxIndex = locateInBoxes(game.save, mon)
    if not boxIndex then return end
    local def = game.data.pokemon[mon.species] or {}
    local name = mon.nickname or def.name or mon.species
    local notice = TextBox.new(game, tr(game,
      ("%s was sent to\nBOX %d."):format(name, boxIndex),
      ("%s wurde in\nBOX %d übertragen."):format(name, boxIndex)))
    if battle and type(battle.uiNext) == "function" then
      battle:uiNext(function() return notice end)
    else
      game.stack:push(notice)
    end
  end

  mod.events:on("pokemon.caught", function(ev)
    local game, mon = ev and ev.game, ev and ev.mon
    if not game or not mon or pending[mon] then return end
    if setting(game) == "off" then
      return
    end
    -- Gifts, authored rewards and event distributions are not ordinary wild
    -- catches and must retain their existing destination semantics.
    if mon.eventDistribution or mon.gift or (ev.battle and ev.battle.trainer) then
      return
    end
    local index = isInParty(game.save, mon)
    local boxIndex = locateInBoxes(game.save, mon)
    if not index and not boxIndex then return end
    pending[mon] = true
    local mode = setting(game)
    if mode == "party" then
      keepInParty(game, mon)
      return
    end
    local name = mon.nickname or (game.data.pokemon[mon.species] or {}).name
      or tostring(mon.species)
    if mode == "box" then
      if index then moveToBox(game, mon, index) end
      announceBox(game, ev.battle, mon)
      return
    end
    local prompt = TextBox.new(game, tr(game,
      ("Where should %s go?\fYES: PARTY  NO: BOX"):format(name),
      ("Wohin soll %s?\fJA: TEAM  NEIN: BOX"):format(name)), function()
      game.stack:push(ChoiceBox.new(game, function(keepParty)
        if keepParty then
          keepInParty(game, mon)
        elseif index then
          if moveToBox(game, mon, index) then
            announceBox(game, ev.battle, mon)
          end
        else
          announceBox(game, ev.battle, mon)
        end
      end, { defaultNo = false }))
    end)
    if ev.battle and type(ev.battle.uiNext) == "function" then
      ev.battle:uiNext(function() return prompt end)
    else
      game.stack:push(prompt)
    end
  end, 20)
end
