-- Game speed is a gameplay option.  A speed stored by an older save must not
-- fast-forward the title or the complete New Game / Oak introduction before
-- the player has actually entered the world.

return function()
  local Game = require("src.core.Game")
  local OakSpeech = require("src.ui.OakSpeech")

  OakSpeech.__kantoAscendantPreGame = true

  if Game.__kantoAscendantPreGameSpeed then return true end
  Game.__kantoAscendantPreGameSpeed = true
  local originalLogicSpeed = Game.logicSpeed

  Game.logicSpeed = function(self)
    local stack = self and self.stack
    for _, state in ipairs(stack and stack.states or {}) do
      if state and (state.screenId == "TitleState"
          or state.__kantoAscendantPreGame) then
        return 1
      end
    end
    return originalLogicSpeed(self)
  end
  return true
end
