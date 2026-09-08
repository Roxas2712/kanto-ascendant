local source=assert(os.getenv('QA_KASC_SOURCE'))
local old=require;local textCalls=0;local selected=0
local BagMenu={new=function()return{onChoose=function()selected=selected+1 end}end}
local ListMenu={new=BagMenu.new}
require=function(name)
 if name=='src.ui.BagMenu' then return BagMenu end
 if name=='src.ui.ListMenu' then return ListMenu end
 if name=='src.render.TextBox' then return {new=function(game,prompt,_,opts)textCalls=textCalls+1;assert(prompt:find('MASTER BALL',1,true));assert(opts.defaultNo);return{prompt=prompt,opts=opts}end} end
 error('unexpected second menu owner '..name)
end
local enabled=true;local policy=assert(loadfile(source..'/item_protection.lua'))()({options={get=function()return enabled end}})
local top;local game={data={items={}},stack={push=function(_,s)top=s end}}
assert(policy.confirm(game,'MASTER_BALL',function()selected=selected+1 end));assert(textCalls==1 and selected==0)
top.opts.choice(false);assert(selected==0,'cancel consumed protected item')
top.opts.choice(true);assert(selected==1)
enabled=false;assert(not policy.confirm(game,'MASTER_BALL',function()selected=selected+1 end));assert(selected==2 and textCalls==1)
require=old;print('Protected item confirmation ownership: ok')
