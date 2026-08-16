-- SELECT bicycle shortcut.  It consumes the remappable logical SELECT
-- action only while the actual overworld is on top, so menu SELECT remains
-- available to every existing screen.

return function(mod, opts)
  opts = opts or {}
  local B = {}
  local function tr(en, de)
    return opts.i18n and opts.i18n.text(en, de) or en
  end
  local function hasBike(game)
    return ((game.save.inventory or {}).BICYCLE or 0) > 0
      or ((game.save.pcItems or {}).BICYCLE or 0) > 0
  end
  local function allowed(game)
    local ow = game.overworld
    if not (ow and ow.map and ow.map.def) then return false end
    local rules = game.data.field.bikeRiding or {
      tilesets = { "OVERWORLD", "FOREST", "UNDERGROUND", "SHIP_PORT", "CAVERN" },
      maps = { "ROUTE_23", "INDIGO_PLATEAU" },
    }
    for _, id in ipairs(rules.maps or {}) do if ow.map.id == id then return true end end
    for _, id in ipairs(rules.tilesets or {}) do
      if ow.map.def.tileset == id then return true end
    end
    return false
  end
  function B.toggle(game)
    if not hasBike(game) then return false, "missing" end
    if game.save.forcedBike then return false, "forced" end
    if not game.save.onBike and not allowed(game) then return false, "blocked" end
    game.save.onBike = not game.save.onBike
    local Music = require("src.core.Music")
    Music.playMap(game.data, game.overworld.map.id, game.save.onBike)
    return true, game.save.onBike and "on" or "off"
  end
  mod.hooks:wrap("input.step", function(nextStep, game, dt)
    local queue = game and game.input and game.input.pressQueue
    local top = game and game.stack and game.stack:top()
    if queue and top and top == game.overworld then
      for index = #queue, 1, -1 do
        if queue[index] == "select" then
          table.remove(queue, index)
          local changed, reason = B.toggle(game)
          local message
          if changed then
            message = game.save.onBike and tr("Got on the BICYCLE!", "Aufs FAHRRAD gestiegen!")
              or tr("Got off the BICYCLE.", "Vom FAHRRAD abgestiegen.")
          elseif reason == "forced" then
            message = tr("You can't get off here.", "Hier kannst du nicht absteigen.")
          elseif reason == "blocked" then
            message = tr("No cycling allowed here.", "Radfahren ist hier verboten.")
          end
          if message then
            game.stack:push(require("src.render.TextBox").new(game, message))
          end
          break
        end
      end
    end
    return nextStep(game, dt)
  end, 120)
  return B
end
