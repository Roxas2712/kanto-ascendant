local root = os.getenv("TRAINER_REMATCH_MOD_DIR") or "."
local function factory(name) return assert(loadfile(root .. "/" .. name))() end
local de = { text = function(_, german) return german end }
local en = { text = function(english) return english end }

local optionHelp = factory("option_help.lua")(de)
local team = optionHelp.text("party_icon_style", "ANIMIERTE ARTEN")
assert(team:find("#001%-251") and team:find("Neustart"),
  "team icon help must state coverage and restart")
assert(optionHelp.text("difficulty", "EXTREM"):find("Items")
    and optionHelp.text("difficulty", "EXTREM"):find("Orden"),
  "difficulty help must explain badge phase-in and the Extreme item rule")
assert(optionHelp.text("wild_level_scaling", "AUS"):find("festgelegte Wildlevel")
    and optionHelp.text("wild_level_scaling", "AN"):find("Randomizer"),
  "Wild-level help must explain OFF authority and isolated ON scope")
assert(optionHelp.text("adaptive_trainer_levels", "AUS"):find("AUS = KLASSISCH", 1, true)
    and optionHelp.text("adaptive_trainer_levels", "AUTO"):find("Teamdurchschnitt")
    and optionHelp.text("adaptive_trainer_levels", "+4"):find("Box%-Pokémon"),
  "adaptive help must explain classic fallback, party mean and exclusions")
assert(optionHelp.text("legend_lugia", "AN"):find("Lugia"),
  "dynamic legendary help missing")
assert(optionHelp.text("event_flying_pikachu", "AN"):find("Flying Pikachu"),
  "dynamic event help missing")
local detailed = {
  "adaptive_trainer_levels", "wild_level_scaling",
  "pokemon_sprite_style", "character_sprite_style", "trainer_portrait_style",
  "sprite_style_battle",
  "sprite_style_summary", "sprite_style_dex", "sprite_style_box",
  "sprite_style_scenes", "living_world_enabled", "living_world_density",
  "living_world_random_encounters", "living_world_water",
  "living_world_caves", "living_world_grass", "living_world_silhouettes",
  "living_world_idle", "living_world_wander", "living_world_chase",
  "living_world_hidden", "living_world_towns", "johto_level_bonus",
  "ascendant_useful_bag", "ascendant_bag_mode",
  "ascendant_quick_select", "ascendant_qol",
  "qol_exp_bar", "qol_caught_indicator", "qol_easy_interactions",
  "qol_location_banners", "modern_storage_ui", "catch_destination",
  "pokedex_filter", "box_filter", "text_speed", "ride_control",
  "quick_select_tap", "quick_select_registration",
  "quick_select_empty_notice", "catch_box_notice", "status_values",
  "modern_ball_skins", "fast_box_switch",
}
for _, key in ipairs(detailed) do
  local help = optionHelp.text(key, "TEST")
  assert(not help:find("Steuert diese Kanto%-Ascendant%-Funktion"),
    key .. " still uses the generic SELECT help")
  assert(#help > 55, key .. " SELECT help is not an explanation")
end
assert(optionHelp.restartRequired("ascendant_useful_bag")
    and optionHelp.restartRequired("ascendant_bag_mode")
    and optionHelp.restartRequired("modern_storage_ui"),
  "load-time Bag and storage owners must disclose their restart requirement")
assert(not optionHelp.restartRequired("ascendant_quick_select")
    and not optionHelp.restartRequired("ascendant_qol"),
  "live Quick Select and QoL masters must not claim a restart is required")
assert(optionHelp.text("living_world_enabled", "AN"):find("Berührung"),
  "Living Regions help does not explain visible contact battles")
assert(optionHelp.text("living_world_enabled", "AUS"):find("klassische Schrittkämpfe")
    and optionHelp.text("living_world_enabled", "AUS"):find("ZUFALLSKÄMPFE AUS"),
  "Wild Pokémon OFF must explain its classic-step fallback")
assert(optionHelp.text("living_world_random_encounters", "AUS"):find("nur Kontaktkämpfe"),
  "Random Battles OFF must explain visible-only play")
assert(optionHelp.text("living_world_random_encounters", "AN"):find("standardmäßig AN")
    and optionHelp.text("living_world_random_encounters", "AUS"):find("Wahl bleibt gespeichert"),
  "Random Battles help must explain the new default without erasing explicit OFF")

local itemHelp = factory("item_help.lua")(de)
local game = { data = { items = {
  POTION = { id = "POTION" },
  HM_CUT = { id = "HM_CUT", machine = { kind = "HM", move = "CUT" } },
  UNKNOWN_KEY = { id = "UNKNOWN_KEY", keyItem = true },
}, moves = { CUT = { name = "ZERSCHNEIDER" } } } }
assert(itemHelp.describe(game, "POTION"):find("20 KP"),
  "Potion description missing")
assert(itemHelp.describe(game, "HM_CUT"):find("ZERSCHNEIDER")
  and itemHelp.describe(game, "HM_CUT"):find("wiederverwendbar"),
  "HM description missing move and reuse rule")
assert(itemHelp.describe(game, "FIELD_KIT"):find("VMs im Feld"),
  "Field Kit description missing")
assert(itemHelp.describe(game, "UNKNOWN_KEY"):find("wichtiges Item"),
  "unknown key-item fallback is blank or misleading")

-- Wrapper contract: preserve USE, reduce the viewport, attach the permanent
-- provider and expose the same prose through the explicit SELECT-info path.
local reorderCalls = 0
local original = { marker = "engine-list", items = {
  { value = "POTION", label = "TRANK", right = "x2" },
}, rows = 7, onChoose = function() end,
  onSelectKey = function() reorderCalls = reorderCalls + 1 end }
package.loaded["src.ui.BagMenu"] = {
  new = function() return original end,
}
-- ascendant_bag also owns the shared PC/shop item-help seam.  This focused
-- unit keeps those engine modules minimal; the real v0.1.79 integration lives
-- in item_select_help_engine_test.lua.
package.loaded["src.inventory.Bag"] = {
  order = function(save) return save and save.bagOrder or {} end,
}
package.loaded["src.ui.ListMenu"] = {
  new = function(_, title, items, opts)
    return { title = title, kind = opts and opts.kind or title,
      items = items or {}, update = function() end }
  end,
}
local decorated
local shown
local ui = {
  decorateBag = function(list, provider)
    decorated = list; list.rows = 4; list.provider = provider; return list
  end,
  showHelp = function(_, title, body)
    shown = { title = title, body = body }
    return true
  end,
}
local mod = {}
local installed = factory("ascendant_bag.lua")(mod, {
  ui = ui, itemHelp = itemHelp,
})
local list = require("src.ui.BagMenu").new(game, {})
assert(installed.installed and list == original and decorated == original,
  "Bag wrapper replaced engine behaviour instead of decorating it")
assert(type(list.onChoose) == "function" and type(list.onSelectKey) == "function",
  "Bag USE or SELECT callback was lost")
assert(list.rows == 4 and list.provider(list.items[1]):find("20 KP"),
  "Bag description panel provider not connected")
list.onSelectKey(list.items[1], list)
assert(reorderCalls == 1 and shown == nil,
  "Bag SELECT must keep the classic mark/place reorder action")
assert(type(list.onStartKey) == "function",
  "Bag START item-help callback is missing")
list.onStartKey(list.items[1], list)
assert(shown.title == "TRANK" and shown.body:find("20 KP"),
  "START item-info action is not connected to the bilingual description")

print("PASS help and Bag: bilingual option help, SELECT move, START info")
