-- Lightweight FireRed-inspired storage chrome for 6.5.
-- The engine still owns all transfer/release behavior; this only adds a
-- palette-safe header and box occupancy readout around the existing menu.

return function(mod)
  local installed = false
  local function install()
    if installed or mod.options:get("modern_storage_ui") == false then return end
    installed = true

    local ok, BoxMenu = pcall(require, "src.ui.BoxMenu")
    if not ok or type(BoxMenu) ~= "table" or type(BoxMenu.new) ~= "function"
        or BoxMenu.__ascendantModernStorage then return end

    local Font = require("src.render.Font")
    local Boxes = require("src.pokemon.Boxes")
    local Strings = require("src.core.Strings")
    local baseNew = BoxMenu.new

    BoxMenu.new = function(game, ...)
      local menu = baseNew(game, ...)
      local baseDraw = menu.draw
      function menu:draw()
        baseDraw(self)
        local save = game.save
        local box = Boxes.active(save)
        local current = save.currentBox or 1
        local count = box and #box or 0

        -- FireRed-style blue header, kept inside the native 160x144 canvas.
        love.graphics.setColor(0.18, 0.34, 0.62, 1)
        love.graphics.rectangle("fill", 8, 8, 144, 16)
        love.graphics.setColor(1, 1, 1, 1)
        Font.draw(Strings("POKéMON STORAGE"), 16, 12)
        Font.draw(Strings("BOX %02d", current), 112, 12)

        love.graphics.setColor(0.78, 0.88, 0.95, 1)
        love.graphics.rectangle("fill", 112, 120, 40, 12)
        love.graphics.setColor(0, 0, 0, 1)
        Font.draw(Strings("%02d/20", count), 120, 122)
        love.graphics.setColor(1, 1, 1, 1)
      end
      return menu
    end
    BoxMenu.__ascendantModernStorage = true

    -- The same chrome is used for the integrated Useful Bag.  An external
    -- useful_bag owns its own screen and is intentionally left untouched.
    if not mod.exports.externalUsefulBag then
      local bagOk, BagMenu = pcall(require, "src.ui.BagMenu")
      if bagOk and type(BagMenu) == "table" and type(BagMenu.new) == "function"
          and not BagMenu.__ascendantModernStorage then
        local bagNew = BagMenu.new
        BagMenu.new = function(game, ...)
          local menu = bagNew(game, ...)
          local baseDraw = menu.draw
          function menu:draw()
            baseDraw(self)
            local count = 0
            for _, amount in pairs(game.save.inventory or {}) do
              if tonumber(amount) and amount > 0 then count = count + 1 end
            end
            love.graphics.setColor(0.18, 0.34, 0.62, 1)
            love.graphics.rectangle("fill", 8, 8, 144, 16)
            love.graphics.setColor(1, 1, 1, 1)
            Font.draw(Strings("BAG"), 16, 12)
            Font.draw(Strings("%03d/999", count), 104, 12)
            love.graphics.setColor(1, 1, 1, 1)
          end
          return menu
        end
        BagMenu.__ascendantModernStorage = true
      end
    end
  end
  install()
end
