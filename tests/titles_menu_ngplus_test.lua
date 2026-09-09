local root = os.getenv("KASC_SOURCE") or "."
local makeHall = assert(loadfile(root .. "/legacy_hall.lua"))()
local count = 0
for _, lang in ipairs({"en", "de"}) do
  for _, ngplus in ipairs({true, false}) do
    for _, champion in ipairs({false, true}) do
      local hooks, screens, data = {}, {}, {}
      local game = {save = {ngplus = ngplus, champion = champion}}
      game.stack = {push = function(_, menu) game.menu = menu end}
      local mod = {
        exports = {},
        save = {get = function(_, k) return data[k] end,
          set = function(_, k, v) data[k] = v end},
        hooks = {wrap = function(_, k, fn) hooks[k] = fn end},
        events = {on = function() end},
        content = {screens = {register = function(_, k, v) screens[k] = v end}},
        ui = {
          ListMenu = {new = function(_, title, rows, options)
            return {title = title, rows = rows, options = options}
          end},
          insertBefore = function(rows, _, item) table.insert(rows, 1, item) return rows end,
          push = function(g, screen) g.stack:push(screens[screen].new(g)) end,
        },
      }
      makeHall(mod, {
        i18n = {text = function(en, de) return lang == "de" and de or en end},
        postgame = {hasHallOfFame = function(save) return save.champion end},
        legacyJourney = {isActive = function(save) return save.ngplus end},
      })
      local hook = hooks["ui.start_menu.items"]
      local rows = hook(function(_, items) return items end, game, {{label = "SAVE"}})
      assert((#rows == 2) == (ngplus or champion),
        "NG+ title menu must be available before Hall of Fame: " .. lang)
      assert(hook(function() return nil end, game, {}) == nil)
      if ngplus or champion then
        assert(rows[1].ascendantOrder == 80 and rows[1].ascendantMenu)
        rows[1].onSelect()
        assert(game.menu.rows[1].value == "titles")
        game.menu.options.onChoose(game.menu.rows[1])
        assert(game.menu.title == (lang == "de" and "TITEL WÄHLEN" or "SELECT TITLE"))
        assert(game.menu.rows[1].value == false, "empty NG+ titles remain accessible without granting titles")
      end
      count = count + 1
    end
  end
end
print("title-menu NG+ regression: " .. count .. " scenarios passed")
