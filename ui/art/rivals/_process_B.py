import sys
sys.path.insert(0, 'C:/Users/aroki/AppData/Roaming/Python/Python312/site-packages')
from PIL import Image, ImageDraw, ImageFont
import numpy as np
import json
from pathlib import Path
root=Path(__file__).parent
jobs=json.loads((root/'_generation_B.json').read_text())
for j in jobs:
    im=Image.open(j['source']).convert('RGB')
    size=(j['width'],j['height'])
    if not j['alpha']:
        im=im.resize(size,Image.Resampling.LANCZOS)
    else:
        a=np.asarray(im).astype(float)
        r,g,b=a[:,:,0],a[:,:,1],a[:,:,2]
        # Neutral foreground over chroma green: derive coverage from green excess.
        alpha=np.clip(1-(g-(r+b)/2)/255,0,1)
        alpha=np.clip((alpha-.15)/.83,0,1)
        white=j['name'].startswith(('row_','hk_','kit_'))
        if white:
            rgb=np.full(a.shape,255,dtype=np.uint8)
        else:
            value=np.clip((r+b)/2/np.maximum(alpha,.001),0,255)
            if j['name'].startswith('shop_tag'):
                value=58+147*np.clip((value-65)/130,0,1)
            else:
                value=np.where(value>220,255,np.where(value<35,17,value))
                if 'dpad' in j['name']:
                    value=128+127*np.clip((value-150)/70,0,1)
            rgb=np.repeat(value[:,:,None],3,axis=2).astype('uint8')
        rgba=np.dstack((rgb,(alpha*255).astype('uint8')))
        im=Image.fromarray(rgba)
        bbox=im.getchannel('A').point(lambda x:255 if x>128 else 0).getbbox()
        if j['name'].startswith('shop_tag'):
            im=im.crop(bbox).resize(size,Image.Resampling.LANCZOS)
        elif j['name']!='kit_locked_sparkles.png':
            im=im.crop(bbox)
            im.thumbnail((round(size[0]*.84),round(size[1]*.84)),Image.Resampling.LANCZOS)
            canvas=Image.new('RGBA',size,(255,255,255,0))
            canvas.paste(im,((size[0]-im.width)//2,(size[1]-im.height)//2))
            im=canvas
        else:
            im=im.resize(size,Image.Resampling.LANCZOS)
        if white:
            aa=im.getchannel('A')
            im=Image.new('RGBA',size,'white');im.putalpha(aa)
    im.save(root/'_upload'/j['name'])
# Contact sheet: every icon at 128 and 32 pixels, large illustrations scaled.
w,h=1320,1760
sheet=Image.new('RGB',(w,h),'#16171B')
draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',16)
small=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',13)
big=[j for j in jobs if not j['alpha']]
icons=[j for j in jobs if j['alpha']]
for i,j in enumerate(big):
    x=20+(i%3)*440;y=20+(i//3)*280
    draw.rectangle((x-5,y-5,x+415,y+260),outline='#363840')
    im=Image.open(root/'_upload'/j['name']);im.thumbnail((408,224),Image.Resampling.LANCZOS)
    sheet.paste(im,(x+(408-im.width)//2,y))
    draw.text((x,y+232),j['name'],font=font,fill='white')
for i,j in enumerate(icons):
    x=20+(i%5)*260;y=590+(i//5)*190
    draw.rectangle((x-5,y-5,x+245,y+177),outline='#363840')
    im=Image.open(root/'_upload'/j['name']).convert('RGBA')
    for s,ox,oy in [(128,12,5),(32,180,53)]:
        thumb=im.copy();thumb.thumbnail((s,s),Image.Resampling.LANCZOS)
        sheet.paste(thumb,(x+ox,y+oy),thumb)
    draw.text((x+10,y+135),'128 px',font=small,fill='#A9ABB5')
    draw.text((x+175,y+98),'32 px',font=small,fill='#A9ABB5')
    draw.text((x,y+155),j['name'],font=small,fill='white')
sheet.save(root/'_contact_B.png')
for j in jobs:
    im=Image.open(root/'_upload'/j['name'])
    assert im.size==(j['width'],j['height'])
    if j['alpha']:
        assert im.mode=='RGBA' and im.getchannel('A').getextrema()==(0,255)
        if j['name'].startswith(('row_','hk_','kit_')):
            arr=np.asarray(im)
            assert (arr[:,:,:3][arr[:,:,3]>0]==255).all()
    else: assert im.mode=='RGB'
    print(j['name'], im.size, im.mode)
print('_contact_B.png',sheet.size)
