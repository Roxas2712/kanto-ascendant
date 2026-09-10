package.path = "./?.lua;./?/init.lua;" .. package.path

local handlers, values = {}, { hoenn_trace_presentation = true }
local registered
package.preload["src.audio.ChipAsm"] = function()
  return { song = function(spec) return { chip=spec } end }
end
local mod = {
  options={ get=function(_, key) return values[key] end },
  content={ music={
    get=function() return registered end,
    register=function(_, id, value) registered={ id=id, value=value } end,
  }},
  events={ on=function(_, id, fn, priority)
    handlers[id]=handlers[id] or {}
    handlers[id][#handlers[id]+1]={ fn=fn, priority=priority }
  end },
}
local music = assert(loadfile("hoenn_trace_music_67.lua"))()(mod)
assert(music.id == "Music_KA_HoennTrace67" and registered.id == music.id,
  "Hoenn trace music did not register")

local played, pushed
local presentation = assert(loadfile("hoenn_trace_presentation_67.lua"))()(mod, {
  i18n={ text=function(en, de) return de end }, musicId=music.id,
  music={ play=function(_, id, loop, ctx)
    played={ id=id, loop=loop, reason=ctx.reason }
  end },
  textBox={ new=function(_, text) return { text=text } end },
})
local overworld = {}
local game = { data={ pokemon={ TREECKO={ name="GECKARBOR" } } },
  overworld=overworld, stack={
    top=function() return overworld end,
    push=function(_, value) pushed=value end,
  } }
local battle = { kind="trainer", game=game,
  trainer={ name="WANDERER LINA" }, ascendantLegacyWanderer=true,
  ascendantLegacyToken="trace:1", kaHoennIntroductionResult={
    introduced=true, family="TREECKO", mapId="ROUTE_1",
    habitat={map="ROUTE_1",terrain="grass",en="ROUTE 1",de="ROUTE 1"},
  } }
assert(presentation.captureAnnouncement({ battle=battle, result="win" }))
assert(presentation.showPending({ game=game }))
assert(pushed.text:find("WANDERER LINA",1,true)
    and pushed.text:find("GECKARBOR",1,true)
    and pushed.text:find("Such dort im Gras",1,true),
  "bilingual Wanderer announcement is incomplete")
assert(not presentation.showPending({ game=game }),
  "announcement was displayed more than once")

local wild = { kind="wild", game=game, data=game.data,
  kaHoennDiscoveryMode="trace", kaHoennDiscoverySpecies="TREECKO" }
assert(presentation.beginTraceMusic({ battle=wild }))
assert(played.id == music.id and played.loop == true
    and played.reason == "hoenn-trace"
    and wild.kaHoennTraceMusic == music.id,
  "catchable trace did not receive its dedicated battle cue")

values.hoenn_trace_presentation=false
pushed, played = nil, nil
assert(not presentation.captureAnnouncement({ battle=battle, result="win" }))
assert(not presentation.beginTraceMusic({ battle=wild }))
assert(pushed == nil and played == nil,
  "disabled presentation card changed the encounter")
print("hoenn_trace_presentation_67_test: PASS (announcement/music/off)")
