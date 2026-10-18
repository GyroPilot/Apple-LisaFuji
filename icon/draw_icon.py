"""LisaFuji icon, draft A: a snow-capped mountain with radio waves above it.
Drawn on the left half and mirrored, so it is exactly symmetrical."""
from PIL import Image
import math
W,H=48,32
px=[[0]*W for _ in range(H)]
def dot(x,y):
    if 0<=x<W and 0<=y<H:
        px[y][x]=1; px[y][W-1-x]=1
# left edge of the mountain for each row (concave, like Fuji)
xl={12:21,13:20,14:19,15:19,16:18,17:17,18:16,19:15,20:14,21:13,22:12,23:10,24:9,25:7,26:6,27:4,28:3,29:1}
prev=None
for y in range(12,30):
    x=xl[y]
    dot(x,y)
    if prev is not None:
        for k in range(x+1,prev): dot(k,y)       # join steps wider than one pixel
    prev=x
for x in range(21,24): dot(x,12)                 # flat summit
for x in range(1,24): dot(x,30)                  # ground
# snow line: zig-zag; everything below it inside the outline is solid
def snow(x): return 19+abs(((x-18)%6)-3)-1        # 18..21, period 6
for y in range(13,30):
    for x in range(xl[y]+1,24):
        if y>=snow(x)+0 and y>=18: dot(x,y)
# radio waves: three arcs over the summit
cx,cy=23.5,11.3
for r in (4,7,10):
    for a in range(228,271):
        t=math.radians(a)
        x=cx+r*math.cos(t); y=cy+r*math.sin(t)
        dot(int(math.floor(x)),int(round(y)))
im=Image.new('L',(W,H),255)
for y in range(H):
    for x in range(W):
        if px[y][x]: im.putpixel((x,y),0)
im.save('lfj_icon_A.png')
im.resize((W*8,H*8),Image.NEAREST).save('lfj_icon_A_preview.png')
for y in range(H): print(''.join('#' if v else '.' for v in px[y]))
