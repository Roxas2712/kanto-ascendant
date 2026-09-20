local root=assert(arg[1])
local V=assert(loadfile(root..'/hidden_evolution_visibility_compat.lua'))()({}, {routes={}})
local g=love.graphics
local image=love.image.newImageData(1,1);image:setPixel(0,0,.5,.5,.5,1)
local depth=g.newImage(image);image:release()
local canvas=g.newCanvas(64,64,{dpiscale=1})
local geometry={width=64,height=64,centerX=0,centerY=0,cellPixels=16,facing={1,0},sceneDepth=depth,
 inverseVP={32,0,0,0, 0,0,32,0, 0,32,0,0, 0,0,0,1}}
for _,kind in ipairs({'RED','BLUE','GREEN'})do
 local profile={kind=kind,radius=1,coreRadius=.4,coneSlope=.34,
  innerOpacity=.5,outerOpacity=1,featherPx=.2,outerColor={.12,.12,.12},sight=0}
 local function render(r,b)
  g.push('all');g.setCanvas(canvas);g.clear(r,0,b,1)
  local ok,path=V.drawMask(profile,geometry);assert(ok and path=='shader',path)
  g.setCanvas();g.pop();return canvas:newImageData()
 end
 local red,blue=render(1,0),render(0,1)
 for _,p in ipairs({{2,2},{61,2},{2,61},{61,61}})do
  local ar,ag,ab=red:getPixel(p[1],p[2]);local br,bg,bb=blue:getPixel(p[1],p[2])
  assert(math.abs(ar-br)+math.abs(ag-bg)+math.abs(ab-bb)<.015,kind..' leaks world outside radius')
 end
 local ar,ag,ab=red:getPixel(32,32);local br,bg,bb=blue:getPixel(32,32)
 assert(math.abs(ar-br)+math.abs(ab-bb)>.15,kind..' hides nearby world')
 red:release();blue:release();print('PASS_WORLD_MASK_GPU',kind)
end
canvas:release();depth:release()
