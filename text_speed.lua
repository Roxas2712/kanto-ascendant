-- Keeps the vanilla text-speed setting available while allowing 6.5 to
-- provide a single optional preset in the Ascendant options.

return function(mod)
  local function apply(game)
    if not game or not game.save or not game.save.options then return end
    local value = mod.options:get("text_speed")
    if value == "fast" then
      game.save.options.textSpeed = 1
    elseif value == "normal" then
      game.save.options.textSpeed = 3
    elseif value == "slow" then
      game.save.options.textSpeed = 5
    end
  end

  mod.events:on("game.ready", function(ev) apply(ev and ev.game) end)
  mod.events:on("save.loaded", function(ev) apply(ev and ev.game) end)
  mod.events:on("mod.options_changed", function(ev) apply(ev and ev.game) end)
end
