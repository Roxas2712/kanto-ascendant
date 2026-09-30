"""Convert the Gen-1 reference-guided six poses to native 16x96 OBJ format.
Only exterior white is transparent; enclosed light face/bandana pixels remain
opaque. Use area sampling, three hardware shades, and stable foot anchors.
"""
from pathlib import Path
from collections import deque
from PIL import Image
root=Path(__file__).resolve().parent
source=Image.open(root/'gen1_master_v2.png').convert('RGBA')
cw,ch=source.width//3,source.height//2
assert source.width%3==0 and source.height%2==0
sheet=Image.new('RGBA',(16,96),(255,255,255,0))
for frame in range(6):
 x,y=(frame%3)*cw,(frame//3)*ch
 tile=source.crop((x,y,x+cw,y+ch)); px=tile.load()
 # Exterior flood removes only background, retaining white enclosed by ink.
 seen=set();q=deque([(x,0) for x in range(cw)]+[(x,ch-1)for x in range(cw)]+[(0,y)for y in range(ch)]+[(cw-1,y)for y in range(ch)])
 while q:
  a,b=q.popleft()
  if (a,b)in seen or not(0<=a<cw and 0<=b<ch):continue
  seen.add((a,b));r,g,blue,alpha=px[a,b]
  if alpha<128 or min(r,g,blue)>220:
   px[a,b]=(255,255,255,0)
   q.extend(((a-1,b),(a+1,b),(a,b-1),(a,b+1)))
 bounds=tile.getbbox();assert bounds
 tile=tile.crop(bounds).resize((14,16),Image.Resampling.BOX)
 data=[]
 for r,g,b,a in tile.getdata():
  shade=0 if r<75 else 85 if r<150 else 170
  data.append((shade,shade,shade,255)if a>=128 else(255,255,255,0))
 tile.putdata(data);sheet.paste(tile,(1,frame*16))
target=root.parents[2]/'characters/hoenn_visitor_walk.png';sheet.save(target);print(target)
