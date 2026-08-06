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

  local function setting(game)
    local bucket = game and game.save and game.save.options
      and game.save.options.modOptions
      and game.save.options.modOptions[mod.id]
    return (bucket and bucket.catch_destination)
      or mod.options:get("catch_destination")
      or "ask"
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
    if not index then return end
    if #game.save.party >= Party.MAX and #Boxes.active(game.save) >= Boxes.CAPACITY then
      return
    end
    pending[mon] = true
    local mode = setting(game)
    if mode == "party" then return end
    local name = mon.nickname or (game.data.pokemon[mon.species] or {}).name
      or tostring(mon.species)
    if mode == "box" then
      moveToBox(game, mon, index)
      return
    end
    game.stack:push(TextBox.new(game, tr(game,
      ("Where should %s go?\fYES: PARTY  NO: BOX"):format(name),
      ("Wohin soll %s?\fJA: TEAM  NEIN: BOX"):format(name)), function()
      game.stack:push(ChoiceBox.new(game, function(keepParty)
        if not keepParty then moveToBox(game, mon, index) end
      end, { defaultNo = false }))
    end))
  end, 20)
end
