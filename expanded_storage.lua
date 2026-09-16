-- Additional native boxes; preserve the engine's existing serialization and
-- every occupied slot. Capacity per box remains unchanged.
return function(mod, generation)
  local Boxes = require("src.pokemon.Boxes")
  local nativeEnsure = Boxes.kascNativeEnsure or Boxes.ensure
  Boxes.kascNativeEnsure = nativeEnsure
  local Gen2, Save2
  if generation == 2 then
    Gen2 = require("src.core.gen2.Boxes")
    Save2 = require("src.core.gen2.Save")
  end
  local function grow(save)
    local count = math.max(60, Boxes.COUNT or 0)
    for index in pairs(save and save.boxes or {}) do
      if type(index) == "number" and index > count and index % 1 == 0 then count = index end
    end
    Boxes.COUNT = count
    if Gen2 then Gen2.NUM_BOXES, Save2.NUM_BOXES = count, count end
    return count
  end
  grow()
  function Boxes.ensure(save)
    local count = grow(save)
    local boxes = nativeEnsure(save)
    for index = 1, count do
      if boxes[index] == nil then boxes[index] = {} end
    end
    return boxes
  end
  local function onSave(event)
    local save = event and (event.save or event.game and event.game.save)
    if save then Boxes.ensure(save) end
  end
  for _, name in ipairs({"save.loaded", "save.created", "save.writing"}) do
    mod.events:on(name, onSave, 10)
  end
  return { count=function() return Boxes.COUNT end, ensure=Boxes.ensure }
end
