-- Exact-0.1.86 item-effect ABI receipt. Stock dispatches one context table;
-- Kanto Ascendant's registered handlers normalize that shape while retaining
-- compatibility with newer positional/callStyle dispatchers.
package.path = "./?.lua;./?/init.lua;" .. package.path

local Data = require("src.core.Data")
local Schemas = require("src.mods.Schemas")
local ItemEffects = require("src.inventory.ItemEffects")
if not (Data.items and Data.items.POTION) then Data:load() end
Data.item_effects = Data.item_effects or {}

local schemaOk, why = Schemas.check(Schemas.REGISTRIES.item_effects,
  "item_effects", "KA_TEST_CONTEXT", {
    use = function() end, battle = true, field = true,
  }, "register")
assert(schemaOk, why)

local save = { inventory = { KA_TEST_ITEM = 3 } }
local target, battle, overworld = {}, {}, {}
local seen
Data.items.KA_TEST_ITEM = {
  id = "KA_TEST_ITEM", name = "ABI TEST", effect = "KA_TEST_CONTEXT",
}
Data.item_effects.KA_TEST_CONTEXT = {
  battle = true, field = true,
  use = function(context)
    seen = context
    return "used", { "CONTEXT ABI PASS" }, { receipt = true }
  end,
}
local result, messages, extra = ItemEffects.use(Data, save, "KA_TEST_ITEM",
  target, battle, 4, overworld)
assert(result == "used" and messages[1] == "CONTEXT ABI PASS"
  and extra.receipt == true)
assert(seen.data == Data and seen.save == save and seen.itemId == "KA_TEST_ITEM"
  and seen.target == target and seen.battle == battle and seen.moveIndex == 4
  and seen.overworld == overworld)
assert(save.inventory.KA_TEST_ITEM == 3,
  "dispatch must not consume inventory before the Bag commits success")

print("item effect context-table engine test: PASS")
