-- Show the caught Pokémon on Ascendant's nickname screen.
--
-- The engine faithfully blanks the Gen-I AskName background. That is useful
-- for strict parity, but it leaves the modern capture flow looking broken.
-- Keep the engine-owned prompt and naming logic, then draw the already loaded
-- caught battler in a small upper-left preview area behind the overlay.

return function(mod)
  local ok, BattleState = pcall(require, "src.battle.BattleState")
  if not ok or type(BattleState) ~= "table" then return end

  local function drawPreview(battle)
    if not (battle and battle.blankForAskName
        and battle.enemy and battle.enemy.sprite) then
      return
    end
    local made, image = pcall(battle.picImage, battle, battle.enemy.sprite)
    if not made or not image then return end
    local width, height = image:getDimensions()
    if width < 1 or height < 1 then return end
    local scale = math.min(1, 48 / width, 48 / height)
    local x = 16 + (56 - width * scale) / 2
    local y = 12 + (56 - height * scale) / 2
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(image, x, y, 0, scale, scale)
    require("src.render.PaletteFX").markTrueColor(
      math.floor(x), math.floor(y),
      math.ceil(width * scale), math.ceil(height * scale))
    love.graphics.setColor(1, 1, 1, 1)
  end

  BattleState._ascendantCapturePreview = drawPreview
  if not BattleState.__ascendantCapturePreview then
    BattleState.__ascendantCapturePreview = true
    local originalDraw = BattleState.draw
    BattleState.draw = function(self, ...)
      local result = originalDraw(self, ...)
      local preview = BattleState._ascendantCapturePreview
      if preview then preview(self) end
      return result
    end
  end

  mod.exports.capturePreview = { draw = drawPreview }
end
