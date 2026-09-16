-- KASC's stats inset in the existing native/ORAS SummaryMenu. No new menu,
-- navigation override, renderer source modification or saved stat rewrite.
return function(mod,opts)
  local Summary=require('src.ui.SummaryMenu')
  local Font=require('src.render.Font')
  local M={CARD_ID='KASC-67-SUMMARY-STATS',OWNER='kasc.summary-stats/v1'}
  local unpacked=table.unpack or unpack
  local function pack(...)return {n=select('#',...),...}end
  local colors={paper={1,252/255,236/255},ink={5/255,24/255,61/255},
    blue={202/255,238/255,251/255},bar={104/255,177/255,218/255},
    white={1,1,1},green={45/255,184/255,69/255},orange={1,145/255,22/255}}
  local order={'hp','attack','defense','speed','specialAttack','specialDefense'}
  local labels={en={'HP','ATK','DEF','SPD','SP.ATK','SP.DEF'},
    de={'KP','ANG','VER','INI','SP.ANG','SP.VER'}}
  local shader
  local function color(c)love.graphics.setColor(c[1],c[2],c[3],1)end
  local function text(value,x,y,c)
    local g=love.graphics
    if shader==nil then
      local ok,v=pcall(g.newShader,[[extern vec4 tone;
        vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc) {
          return vec4(tone.rgb, Texel(tex, tc).a * tone.a);
        }]])
      shader=ok and v or false
    end
    if shader then shader:send('tone',{c[1],c[2],c[3],1});g.setShader(shader);color(colors.white)
    else color(c)end
    Font.draw(tostring(value),math.floor(x),math.floor(y));g.setShader()
  end
  local function right(value,x,y,c)return text(value,x-Font.width(tostring(value)),y,c)end
  local function fill(c,x,y,w,h)color(c);love.graphics.rectangle('fill',x,y,w,h)end
  local function bar(x,y,w,ratio,c)
    fill(colors.blue,x,y,w,6)
    fill(c,x,y,math.floor(w*math.max(0,math.min(1,ratio))),6)
  end
  function M.model(screen)
    local stats,epoch=opts.split.preview(screen.game,screen.mon)
    if not stats then return nil end
    local lang=screen.__vascOrasLanguage or screen.language
    if lang~='de'and lang~='en'then lang=opts.i18n.isGerman()and'de'or'en'end
    local mon=screen.mon;local dvs,exp=mon.dvs or{},mon.statExp or{}
    local genetics=mod.exports.daycare and mod.exports.daycare.breedingIVs
    local ivs=epoch>=3 and genetics and genetics.ivs(screen.game,mon)
    local hpDV=dvs.hp or (dvs.attack or 0)%2*8+(dvs.defense or 0)%2*4
      +(dvs.speed or 0)%2*2+(dvs.special or 0)%2
    local rows={}
    for i,key in ipairs(order)do
      local trained=(key=='specialAttack'or key=='specialDefense')and'special'or key
      rows[i]={key=key,label=labels[lang][i],value=tonumber(stats[key])or 0,
        dv=ivs and ivs[key]or key=='hp'and hpDV or dvs[trained]or 0,
        maxDV=ivs and 31 or 15,exp=exp[trained]or 0}
    end
    return {rows=rows,epoch=epoch,language=lang,hp=mon.hp or 0,geneticsLabel=ivs and'IV'or'DV'}
  end
  function M.layout(screen)
    if screen.__vascOrasSummaryDecorated then
      local w,h=screen:uiSize()
      if w==512 and h==288 then return 'oras' end
      return nil -- do not paint into an unknown future skin geometry
    end
    if screen.uiSize then local w,h=screen:uiSize();if w~=160 or h~=144 then return nil end end
    return 'native'
  end
  function M.paint(screen,model,layout)
    local page=tonumber(screen.page)or 1
    if page~=1 and page~=3 then return end
    if layout=='oras'then
      -- Only the values inset, inside the existing ORAS shell and header.
      fill(colors.paper,215,89,266,147)
      if page==3 then
        fill(colors.ink,216,67,264,20)
        text('STAT',225,73,colors.white);text(model.geneticsLabel,296,73,colors.white)
        right(model.language=='de'and'STAT-EP'or'STAT-EXP',470,73,colors.white)
      end
      local max=1
      for i=2,#model.rows do max=math.max(max,model.rows[i].value)end
      for i,row in ipairs(model.rows)do
        local y=92+(i-1)*24
        if i%2==0 then fill(colors.blue,216,y-2,264,23)end
        fill(colors.bar,219,y+2,4,18);text(row.label,231,y+6,colors.ink)
        if page==1 then
          local ratio=row.key=='hp'and model.hp/math.max(1,row.value)or row.value/max
          bar(293,y+9,113,ratio,row.key=='hp'and colors.green or colors.bar)
          right(row.key=='hp'and('%d/%d'):format(model.hp,row.value)or row.value,470,y+6,colors.ink)
        else
          text(('%d/%d'):format(row.dv,row.maxDV),292,y+6,colors.ink)
          right(row.exp,470,y+2,colors.ink);bar(362,y+15,108,row.exp/65535,colors.orange)
        end
      end
    elseif layout=='native'and page==1 then
      fill(colors.white,8,72,64,64)
      for i=2,#model.rows do
        local row=model.rows[i];local y=74+(i-2)*12
        local label=i==5 and'SP.A'or i==6 and'SP.D'or row.label
        text(label,8,y,colors.ink);right(row.value,72,y,colors.ink)
      end
    elseif layout=='native'and page==3 then
      local bridge=Summary._ascendantInsightsBridge
      if not bridge or bridge.valuesMode(screen.game)=='off'then return end
      fill(colors.paper,6,37,148,85)
      for i,row in ipairs(model.rows)do
        local y=40+(i-1)*13
        local label=i==5 and'SP.A'or i==6 and'SP.D'or row.label
        text(label,8,y,colors.ink);text(('%2d/%d'):format(row.dv,row.maxDV),56,y,colors.ink)
        if bridge.valuesMode(screen.game)=='full'then right(row.exp,152,y,colors.ink)end
      end
    end
  end
  function M.render(screen,wide,w,h)
    local model=M.model(screen);local layout=model and M.layout(screen)
    if not layout or layout=='native'and(screen.closing or(screen.whiteHold or 0)>0)then return end
    local g=love.graphics;g.push('all')
    local ok,err=pcall(function()
      g.setShader()
      if wide and layout=='oras'and tonumber(w)and tonumber(h)and w>0 and h>0 then
        local scale=math.min(w/512,h/288)
        g.origin();g.translate(math.floor((w-512*scale)/2),math.floor((h-288*scale)/2));g.scale(scale,scale)
      end
      M.paint(screen,model,layout)
    end)
    g.pop();if not ok then error(err,0)end
  end
  function M.decorate(screen)
    if getmetatable(screen)~=Summary or screen.__kascSummaryStats67 then return end
    screen.__kascSummaryStats67=M.OWNER
    for _,name in ipairs({'draw','drawWidescreen'})do
      local original=screen[name]
      if type(original)=='function'then screen[name]=function(self,...)
        local result=pack(original(self,...))
        local owner=Summary._kascSummaryStats67
        if owner then owner.render(self,name=='drawWidescreen',...)end
        return unpacked(result,1,result.n)
      end end
    end
  end
  Summary._kascSummaryStats67=M
  mod.events:on('screen.pushed',function(ev)if ev and ev.state then M.decorate(ev.state)end end,-20010)
  if opts.supportLog and opts.supportLog.registerSegment then
    opts.supportLog.registerSegment({segmentId=M.CARD_ID,cardId=M.CARD_ID,
      schema='kasc.optional-feature-card/v1',version='1.0.0',owner=M.OWNER,active=true,
      dependencyStatus='split-special-native-summary',providerStatus='native-and-oras-stats-inset',
      buildReceiptId='docs/SUMMARY_STATS_67.md',rollbackReceiptId='docs/SUMMARY_STATS_67.md'})
  end
  return M
end
