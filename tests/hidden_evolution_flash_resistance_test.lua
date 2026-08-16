-- Focused product proof: FLASH stays selectable in each visibility trial,
-- gives the authored bilingual feedback, and never mutates the map lighting.
package.path = "./?.lua;./?/init.lua;" .. package.path

local root = assert(os.getenv("KA_HIDDEN_EVOLUTION_MOD"),
  "KA_HIDDEN_EVOLUTION_MOD is required")
local oldMap = package.loaded["src.world.Map"]
local oldTextBox = package.loaded["src.render.TextBox"]
package.loaded["src.world.Map"] = {
  isOutside = function() return false end,
}
package.loaded["src.render.TextBox"] = {
  new = function(_, text, done) return { text=text, done=done } end,
}

local function make(language)
  local buckets = {}
  local wrappers = {}
  local mod = {
    save = {
      get = function(_, key) return buckets[key] end,
      set = function(_, key, value) buckets[key] = value end,
    },
    hooks = { wrap = function(_, name, callback)
      wrappers[name] = callback
      return true
    end },
    ui = {},
    content = {
      moves = { register = function() end },
      items = { register = function() end },
      pokemon = { get = function() return nil end, patch = function() end },
    },
  }
  local i18n = { text = language == "de"
    and function(_, de) return de end
    or function(en) return en end }
  local factory = assert(loadfile(root .. "/field_tech.lua"))()
  local field = factory(mod, { i18n=i18n })
  assert(field.registerMapPolicyProvider("hevo_flash_test",
    function(_, moveId, mapId)
      if moveId ~= "FLASH" then return nil end
      if mapId == "RED" or mapId == "BLUE" then
        return { blockFlash=true, flashBlockReason="darkness" }
      end
      if mapId == "GREEN" then
        return { blockFlash=true, flashBlockReason="mist" }
      end
    end))
  field.state().kit = true
  return field, wrappers
end

local function attempt(language, mapId, needle)
  local field = make(language)
  local pushed, closed
  local game = {
    save = { inventory = {
      FIELD_KIT=1, HM_FLASH=1, BOULDERBADGE=1,
    } },
    data = {
      field = { outsideTilesets={} },
      moves = { FLASH={ name=language == "de" and "BLITZ" or "FLASH" } },
    },
    overworld = {
      dark = mapId ~= "GREEN",
      map = { id=mapId, def={ tileset=mapId == "GREEN" and "FOREST" or "CAVERN" } },
    },
    stack = { push = function(_, screen) pushed=screen end },
  }
  local rows=field.fieldRows(game)
  assert(#rows==1 and rows[1].value=="FLASH",
    language.." "..mapId.." hides blocked FLASH instead of explaining it")
  field.useFieldMove(game,"FLASH",{
    close=function() closed=true end,
  })
  assert(closed and pushed and type(pushed.text)=="string",
    language.." "..mapId.." did not close the kit and show feedback")
  assert(pushed.text:find(needle,1,true),
    language.." "..mapId.." uses the wrong resistance text: "..pushed.text)
  assert(game.save.flashLit==nil,
    language.." "..mapId.." illegally persisted vanilla FLASH")
  assert(game.overworld.dark==(mapId~="GREEN"),
    language.." "..mapId.." changed the authored visibility state")
end

attempt("en","RED","darkness")
attempt("en","BLUE","darkness")
attempt("en","GREEN","ancient mist")
attempt("de","RED","Dunkelheit")
attempt("de","BLUE","Dunkelheit")
attempt("de","GREEN","Nebel")

local function partyAttempt(language,mapId,needle)
  local field,wrappers=make(language)
  local pushed,closed
  local game={
    save={inventory={BOULDERBADGE=1}},
    data={moves={FLASH={name=language=="de" and "BLITZ" or "FLASH"}}},
    overworld={dark=mapId~="GREEN",map={id=mapId,def={}}},
    stack={push=function(_,screen)pushed=screen end},
  }
  local original={{label="STATS",action="stats"}}
  if mapId~="GREEN" then original[#original+1]={label="FLASH",action="flash"} end
  local menu={close=function()closed=true end}
  local wrapper=assert(wrappers["ui.party.submenu"],"party FLASH wrapper missing")
  local rows=wrapper(function()return original end,game,original,
    {moves={{id="FLASH"}}},{menu=menu,battle=false,overworld=game.overworld})
  local flash
  for _,row in ipairs(rows)do if row.label==game.data.moves.FLASH.name then flash=row break end end
  assert(flash and flash.action==nil and type(flash.onSelect)=="function",
    language.." "..mapId.." classic party FLASH was not intercepted")
  flash.onSelect(nil,game)
  assert(pushed and pushed.text:find(needle,1,true),
    language.." "..mapId.." classic party FLASH has wrong feedback")
  assert(not game.save.flashLit and game.overworld.dark==(mapId~="GREEN"),
    language.." "..mapId.." classic party FLASH changed visibility")
  assert(type(pushed.done)=="function","classic party feedback lacks close callback")
  pushed.done();assert(closed,"classic party menu did not close after feedback")
end

partyAttempt("en","RED","darkness")
partyAttempt("en","BLUE","darkness")
partyAttempt("en","GREEN","ancient mist")
partyAttempt("de","RED","Dunkelheit")
partyAttempt("de","BLUE","Dunkelheit")
partyAttempt("de","GREEN","Nebel")

package.loaded["src.world.Map"] = oldMap
package.loaded["src.render.TextBox"] = oldTextBox
print("hidden_evolution_flash_resistance_test: PASS (12 bilingual menu attempts)")
