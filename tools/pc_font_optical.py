"""Optical shaping for the original fixed-cell Abrams faces.

Authored centre lines replace the first pass's locally simplified pixel stairs.
Related letters share bowls, shoulders, stroke weights and square terminals.
All geometry remains in the original cell; unsupported symbols keep the trace.
"""
from math import hypot


def area(poly):
    return sum(a[0]*b[1]-b[0]*a[1] for a,b in zip(poly,poly[1:]+poly[:1]))/2


def rect(x,y,w,h):
    return [(x,y),(x+w,y),(x+w,y+h),(x,y+h)]


def clip(poly,axis,bound,less):
    out=[]
    if not poly:return out
    a=poly[-1];ain=(a[axis]<=bound if less else a[axis]>=bound)
    for b in poly:
        bin_=(b[axis]<=bound if less else b[axis]>=bound)
        if bin_!=ain:
            t=(bound-a[axis])/(b[axis]-a[axis])
            out.append(tuple(a[k]+t*(b[k]-a[k]) for k in range(2)))
        if bin_:out.append(b)
        a,ain=b,bin_
    return out


def bounds(poly,box):
    x,y,w,h=box
    for axis,bound,less in [(0,x,False),(0,x+w,True),(1,y,False),(1,y+h,True)]:poly=clip(poly,axis,bound,less)
    return poly


def cut(polys,box):
    # Four non-overlapping half-plane regions outside a rectangular stencil slit.
    x,y,w,h=box;out=[]
    for p in polys:
        out += [clip(p,0,x,True),clip(p,0,x+w,False)]
        middle=clip(clip(p,0,x,False),0,x+w,True)
        out += [clip(middle,1,y,True),clip(middle,1,y+h,False)]
    return [p for p in out if len(p)>2 and abs(area(p))>1e-6]


def stroke(points,weight=(1,1),closed=False):
    # Miter joins in the face's contrast space. Widths are perpendicular to
    # the centre line, avoiding the thin diagonals produced by pixel bevels.
    wx,wy=weight
    p=[]
    for x,y in points:
        value=(x/wx,y/wy)
        if not p or value!=p[-1]:p.append(value)
    n=len(p)
    if n<2:return []
    def side(sign):
        out=[]
        for i,(x,y) in enumerate(p):
            prev=p[(i-1)%n] if closed or i else p[0]
            nxt=p[(i+1)%n] if closed or i<n-1 else p[-1]
            a=(x-prev[0],y-prev[1]);b=(nxt[0]-x,nxt[1]-y)
            if hypot(*a)==0:a=b
            if hypot(*b)==0:b=a
            a=(a[0]/hypot(*a),a[1]/hypot(*a));b=(b[0]/hypot(*b),b[1]/hypot(*b))
            na=(-a[1],a[0]);nb=(-b[1],b[0]);den=1+a[0]*b[0]+a[1]*b[1]
            if den<1e-5:raise ValueError('reversed stroke')
            dx,dy=(na[0]+nb[0])/den*sign/2,(na[1]+nb[1])/den*sign/2
            # Limit an acute apex to two nominal half-widths; bounds below
            # supply flat cap/baseline terminals rather than needle points.
            length=hypot(dx,dy)
            if length>2:dx,dy=dx*2/length,dy*2/length
            out.append(((x+dx)*wx,(y+dy)*wy))
        return out
    left,right=side(1),side(-1)
    if closed:
        outer,inner=(left,right) if abs(area(left))>abs(area(right)) else (right,left)
        return [outer if area(outer)>0 else outer[::-1],inner if area(inner)<0 else inner[::-1]]
    poly=left+right[::-1]
    return [poly if area(poly)>0 else poly[::-1]]


def shape(font,code,name):
    char=chr(code);bits=font['glyphs'][code-font['first']];w=font['width'];h=font['height']
    if not any(bits) or not char.isascii() or not char.isalnum():return None
    points=[(i%w,i//w) for i,b in enumerate(bits) if b]
    x0,y0=min(x for x,y in points),min(y for x,y in points)
    x1,y1=max(x for x,y in points)+1,max(y for x,y in points)+1
    bold=name in ['8X8.FNT','STENCIL.FNT'];stencil=name=='STENCIL.FNT'
    weight=(2.0,1.0) if bold else (1.0,1.0)
    wx,wy=weight;left=x0+wx/2;right=x1-wx/2;top=y0+wy/2;bottom=y1-wy/2
    # Original slab stems sit one cell in from their left cap/foot serifs.
    serif=bold and char in 'BDEFHKLPR'
    if serif or (bold and char in 'bhkr'):left=x0+1+wx/2
    if name=='8X8.FNT' and char in 'adug':right-=1
    if char in 'IEFTL' or (char.islower() and char in 'filt'):
        return None # Already rectilinear: retain distinctive source serifs.
    mid=(top+bottom)/2;cx=(left+right)/2
    bevel=min(0.75,(right-left)/3,(bottom-top)/3)
    out=[]
    def line(p,closed=False,weights=weight):out.extend(stroke(p,weights,closed))
    def bowl(l,r,t,b,c=bevel):
        c=min(c,(r-l)/3,(b-t)/3)
        return [(l+c,t),(r-c,t),(r,t+c),(r,b-c),(r-c,b),(l+c,b),(l,b-c),(l,t+c)]
    def cap_curve(t,b):
        c=min(bevel,(b-t)/3)
        return [(left,t),(right-c,t),(right,t+c),(right,b-c),(right-c,b),(left,b)]
    # Uppercase designs retain the source's flat-top A, low technical M,
    # broad monospaced bowls and military slab/stencil construction.
    if char in 'O0':
        line(bowl(left,right,top,bottom),True)
        if char=='0' and name=='8X8.FNT':line([(left,bottom),(right,top)],weights=(1,1))
    elif char=='D':line(cap_curve(top,bottom),True)
    elif char=='A':
        if bold:
            line([(left,bottom),(cx,top),(right,bottom)])
            line([(left+(right-left)*0.2,mid+0.5),(right-(right-left)*0.2,mid+0.5)])
        else:
            line([(left,bottom),(left,top+bevel),(left+bevel,top),(right-bevel,top),(right,top+bevel),(right,bottom)])
            line([(left,mid),(right,mid)])
    elif char in 'CG':
        line([(right,top+bevel+0.5),(right,top+bevel),(right-bevel,top),(left+bevel,top),(left,top+bevel),(left,bottom-bevel),(left+bevel,bottom),(right-bevel,bottom),(right,bottom-bevel),(right,bottom-bevel-0.5)])
        if char=='G':line([(right,bottom-bevel),(right,mid+0.5),(cx,mid+0.5)])
    elif char in 'BPR':
        line([(left,bottom),(left,top)])
        line(cap_curve(top,mid))
        if char=='B':line(cap_curve(mid,bottom))
        if char=='R':line([(cx,mid),(right,bottom)])
    elif char=='H':
        line([(left,top),(left,bottom)]);line([(right,top),(right,bottom)]);line([(left,mid),(right,mid)])
    elif char=='J':line([(right,top),(right,bottom-bevel),(right-bevel,bottom),(left+bevel,bottom),(left,bottom-bevel)])
    elif char=='K':
        line([(left,top),(left,bottom)]);line([(right,top),(left,mid),(right,bottom)])
    elif char=='M':line([(left,bottom),(left,top),(cx,mid+bevel),(right,top),(right,bottom)])
    elif char=='N':line([(left,bottom),(left,top),(right,bottom),(right,top)])
    elif char=='Q':
        line(bowl(left,right,top,bottom),True);line([(cx,mid),(right,bottom)])
    elif char in 'S235689':
        # Figures and S use common square-ended, bevelled bowls, with no
        # narrow triangular notches at their spine/crossbar joins.
        c=min(bevel,(bottom-top)/4)
        if char=='S':line([(right,top),(left+c,top),(left,top+c),(left,mid-c),(left+c,mid),(right-c,mid),(right,mid+c),(right,bottom-c),(right-c,bottom),(left,bottom)])
        elif char=='2':line([(left,top),(right-c,top),(right,top+c),(right,mid-c),(right-c,mid),(left+c,mid),(left,mid+c),(left,bottom),(right,bottom)])
        elif char=='3':
            line([(left,top),(right-c,top),(right,top+c),(right,mid-c),(right-c,mid),(cx,mid)])
            line([(right-c,mid),(right,mid+c),(right,bottom-c),(right-c,bottom),(left,bottom)])
        elif char=='5':line([(right,top),(left,top),(left,mid),(right-c,mid),(right,mid+c),(right,bottom-c),(right-c,bottom),(left,bottom)])
        elif char=='6':
            line([(right,top),(left+c,top),(left,top+c),(left,bottom-c),(left+c,bottom),(right-c,bottom),(right,bottom-c),(right,mid+c),(right-c,mid),(left,mid)])
        elif char=='8':
            line(bowl(left,right,top,mid,c),True);line(bowl(left,right,mid,bottom,c),True)
        elif char=='9':
            line(bowl(left,right,top,mid,c),True);line([(right,mid),(right,bottom-c),(right-c,bottom),(left,bottom)])
    elif char=='U':line([(left,top),(left,bottom-bevel),(left+bevel,bottom),(right-bevel,bottom),(right,bottom-bevel),(right,top)])
    elif char=='V':line([(left,top),(cx,bottom),(right,top)])
    elif char=='W':line([(left,top),(left,bottom),(cx,mid+bevel),(right,bottom),(right,top)])
    elif char=='X':line([(left,top),(right,bottom)]);line([(right,top),(left,bottom)])
    elif char=='Y':
        if name=='8X6.FNT':line([(left,top),(left,mid-bevel),(left+bevel,mid),(right-bevel,mid),(right,mid-bevel),(right,top)])
        else:line([(left,top),(cx,mid),(right,top)])
        line([(cx,mid),(cx,bottom)])
    elif char=='Z':line([(left,top),(right,top),(left,bottom),(right,bottom)])
    elif char=='4':
        line([(left,top),(left,mid),(right,mid)] if name=='8X6.FNT' else [(right,top),(left,mid+bevel),(right,mid+bevel)])
        line([(right,top),(right,bottom)])
    elif char=='7':
        if name=='8X6.FNT':return None
        line([(left,top),(right,top),(cx,bottom)])
    elif char=='1':return None
    elif char.islower():
        # Keep the original lowercase x-height and ascender/descender allocation.
        cap_y=2 if h==8 else 1
        xt=max(top,cap_y+wy/2) if char in "bdhk" else top
        base=bottom-2 if char in "gpqy" else bottom
        centre=(xt+base)/2;c=min(bevel,(base-xt)/3)
        if char in 'abdgopq':
            l,r=left,right
            if char=='a':
                line([(l,xt),(r-c,xt),(r,xt+c),(r,base)]);line([(r,centre),(l+c,centre),(l,centre+c),(l,base-c),(l+c,base),(r,base)])
            else:
                line(bowl(l,r,xt,base,c),True)
                if char=='b':line([(l,top),(l,base)])
                if char=='d':line([(r,top),(r,base)])
                if char in 'gpq':
                    side=l if char=='p' else r
                    line([(side,xt),(side,bottom)])
                    if char=='g':line([(r,bottom),(l,bottom)])
        elif char in 'ce':
            line([(right,xt),(left+c,xt),(left,xt+c),(left,base-c),(left+c,base),(right,base)])
            if char=='e':line([(left,centre),(right,centre),(right,xt+c),(right-c,xt)])
        elif char in 'hmnru':
            if char=='u':line([(left,xt),(left,base-c),(left+c,base),(right,base),(right,xt)])
            else:
                line([(left,top if char=='h' else xt),(left,base)])
                line([(left,xt+c),(left+c,xt),(right-c,xt),(right,xt+c),(right,base if char!='r' else centre)])
                if char=='m':line([(cx,xt+c),(cx,base)])
        elif char=='s':line([(right,xt),(left+c,xt),(left,xt+c),(left,centre-c),(left+c,centre),(right-c,centre),(right,centre+c),(right,base-c),(right-c,base),(left,base)])
        elif char=='v':line([(left,xt),(cx,base),(right,xt)])
        elif char=='w':line([(left,xt),(left,base),(cx,centre),(right,base),(right,xt)])
        elif char=='y':line([(left,xt),(left,base-c),(left+c,base),(right,base),(right,xt)]);line([(right,base),(right,bottom),(left,bottom)])
        elif char=='k':line([(left,top),(left,base)]);line([(right,xt),(left,centre),(right,base)])
        elif char=='x':line([(left,xt),(right,base)]);line([(right,xt),(left,base)])
        elif char=='z':line([(left,xt),(right,xt),(left,base),(right,base)])
        elif char=='j':return None
        else:return None
    else:return None
    # Slab serifs use one shared thickness and are kept square-ended.
    if serif:
        out += [rect(x0,y0,3,1),rect(x0,y1-1,3,1)]
    if bold and char in 'bhk':out += [rect(x0,y0,3,1),rect(x0,y1-1,3,1)]
    if bold and char=='r':out.append(rect(x0,y1-1,4,1))
    if name=='8X8.FNT' and char=='d':out.append(rect(x1-4,y0,3,1))
    if name=='8X8.FNT' and char in 'adu':out.append(rect(x1-3,y1-1,3,1))
    if bold and char=='Y':out.append(rect(cx-1.5,y1-1,3,1))
    if stencil:
        # Deliberate regular-width stencil bridges in the original regions.
        gap=0.75
        if char in 'BDOPR0':
            for y in [y0,y1-1] if char in 'BDO0' else [y0,mid-0.5]:out=cut(out,(3.125,y,gap,1))
        elif char in 'CGS6':
            for y in [y0,y1-1]:out=cut(out,(2.125,y,gap,1))
    out=[bounds(p,(x0,y0,x1-x0,y1-y0)) for p in out]
    # Quantize once to the exact native TTF design grid; metadata and binary
    # therefore carry the same points rather than divergent float versions.
    scale=1536/h
    normalized=[]
    for polygon in out:
        points=[]
        for x,y in polygon:
            point=(round(x*scale)/scale,round(y*scale)/scale)
            if not points or point!=points[-1]:points.append(point)
        if points and points[0]==points[-1]:points.pop()
        if len(points)>2 and abs(area(points))>1e-6:normalized.append(points)
    return normalized
