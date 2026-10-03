"""Optical shaping for the original fixed-cell Abrams faces.

Capital centre lines retain the approved regular stroke construction. Lowercase
uses source-constrained staircase chords, preserving each original skeleton.
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


def stroke(points,weight=(1,1),closed=False,caps=(0,0)):
    # Miter joins in the face's contrast space. Widths are perpendicular to
    # the centre line, avoiding the thin diagonals produced by pixel bevels.
    wx,wy=weight
    p=[]
    for x,y in points:
        value=(x/wx,y/wy)
        if not p or value!=p[-1]:p.append(value)
    n=len(p)
    if n<2:return []
    # Extend only exposed outer terminals. The final source-cell clip supplies
    # level cap/baseline cuts without scaling the glyph or thickening its bars.
    if not closed:
        for index,near,amount in [(0,1,caps[0]),(n-1,n-2,caps[1])]:
            if not amount:continue
            x,y=p[index];dx,dy=x-p[near][0],y-p[near][1];length=hypot(dx,dy)
            p[index]=(x+amount*dx/length,y+amount*dy/length)
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


def normalize(polys,box,height):
    """Clip once, then put the catalog and TrueType on the same design grid."""
    scale=1536/height;result=[]
    for polygon in polys:
        points=[]
        for x,y in bounds(polygon,box):
            point=(round(x*scale)/scale,round(y*scale)/scale)
            if not points or point!=points[-1]:points.append(point)
        if points and points[0]==points[-1]:points.pop()
        if len(points)>2 and abs(area(points))>1e-6:result.append(points)
    return result


def source_classification(p,polys):
    x,y=p;winding=0;distance=1e6
    for poly in polys:
        for a,b in zip(poly,poly[1:]+poly[:1]):
            dx,dy=b[0]-a[0],b[1]-a[1];dd=dx*dx+dy*dy
            if not dd:continue
            t=max(0,min(1,((x-a[0])*dx+(y-a[1])*dy)/dd))
            distance=min(distance,hypot(x-a[0]-t*dx,y-a[1]-t*dy))
            if (a[1]>y)!=(b[1]>y) and x<a[0]+(y-a[1])*dx/dy:winding+=1 if b[1]>a[1] else -1
    return winding!=0,distance

def lowercase(font,code,name,original):
    """Straighten source stairs without replacing the original letter skeleton.

    Every original ink/blank centre retains its classification. Ink centres keep
    at least 0.4 source units of clearance, so a touching diagonal cannot collapse
    into a hairline. Source stems, serif islands, stencil gaps and bounds remain
    authoritative; each accepted chord reduces the finite vertex inventory.
    """
    bits=font['glyphs'][code-font['first']];w,h=font['width'],font['height']
    points=[(i%w,i//w) for i,b in enumerate(bits) if b];box=(min(x for x,y in points),min(y for x,y in points),max(x for x,y in points)+1-min(x for x,y in points),max(y for x,y in points)+1-min(y for x,y in points))
    original_bounds=(box[0],box[1],box[0]+box[2],box[1]+box[3]);polys=[[tuple(p) for p in poly] for poly in original]
    def valid(ps):
        pts=[p for poly in ps for p in poly]
        if (min(p[0] for p in pts),min(p[1] for p in pts),max(p[0] for p in pts),max(p[1] for p in pts))!=original_bounds:return False
        for i,b in enumerate(bits):
            ink,distance=source_classification((i%w+.5,i//w+.5),ps)
            if ink!=bool(b) or distance<(.40 if b else .06):return False
        return True
    # Stairs have alternating perpendicular unit edges. Slide the straight
    # replacement to a source-verified side of the pixel-centre boundary; its
    # endpoints stay on the adjacent original long edges, preserving terminals.
    for pi in range(len(polys)):
        changed=True
        while changed:
            changed=False;p=polys[pi];n=len(p)
            for start in range(n):
                rotated=p[start:]+p[:start]
                def delta(j):return (rotated[(j+1)%n][0]-rotated[j][0],rotated[(j+1)%n][1]-rotated[j][1])
                a,b=delta(0),delta(1)
                if sum(map(abs,a))!=1 or sum(map(abs,b))!=1 or a[0]*b[0]+a[1]*b[1]!=0:continue
                count=2
                while count<n-2 and delta(count)==(a if count%2==0 else b):count+=1
                # A complete island must never collapse to a chord.
                if n-count<3:continue
                begin,end=rotated[0],rotated[count];dx,dy=end[0]-begin[0],end[1]-begin[1]
                if not dx or not dy:continue
                prev=rotated[-1];nxt=rotated[count+1]
                if prev[0]!=begin[0] and prev[1]!=begin[1]:continue
                if nxt[0]!=end[0] and nxt[1]!=end[1]:continue
                for shift in (.125,-.125,.25,-.25,.5,-.5,.625,-.625):
                    # Line dx*(y-y0)-dy*(x-x0) = shift*(abs(dx)+abs(dy)).
                    k=shift*(abs(dx)+abs(dy))
                    new_begin=(begin[0],begin[1]+k/dx) if prev[0]==begin[0] else (begin[0]-k/dy,begin[1])
                    new_end=(end[0],end[1]+k/dx) if nxt[0]==end[0] else (end[0]-k/dy,end[1])
                    if any(not (min(v[axis],q[axis])<=s[axis]<=max(v[axis],q[axis])) for v,q,s,axis in [(prev,begin,new_begin,1 if prev[0]==begin[0] else 0),(end,nxt,new_end,1 if nxt[0]==end[0] else 0)]):continue
                    candidate=polys.copy();candidate[pi]=[new_begin,new_end]+rotated[count+1:]
                    if abs(area(candidate[pi]))<1e-6 or area(candidate[pi])*area(p)<=0:continue
                    if valid(candidate):polys=candidate;changed=True;break
                if changed:break
    return normalize(polys,box,h)



def shape(font,code,name,source_contours=None):
    char=chr(code);bits=font['glyphs'][code-font['first']];w=font['width'];h=font['height']
    if not any(bits) or not char.isascii() or not char.isalnum():return None
    points=[(i%w,i//w) for i,b in enumerate(bits) if b]
    x0,y0=min(x for x,y in points),min(y for x,y in points)
    x1,y1=max(x for x,y in points)+1,max(y for x,y in points)+1
    if char.islower():
        if source_contours is None:raise ValueError('lowercase requires original contour topology')
        return lowercase(font,code,name,source_contours)
    bold=name in ['8X8.FNT','STENCIL.FNT'];stencil=name=='STENCIL.FNT'
    weight=(2.0,1.0) if bold else (1.0,1.0)
    wx,wy=weight;left=x0+wx/2;right=x1-wx/2;top=y0+wy/2;bottom=y1-wy/2
    # Original slab stems sit one cell in from their left cap/foot serifs.
    serif=bold and char in 'BDEFHKLPR'
    if serif or (bold and char in 'bhkr'):left=x0+1+wx/2
    if name=='8X8.FNT' and char in 'adug':right-=1
    if char in 'IEFTL':
        return None # Already rectilinear: retain distinctive source serifs.
    mid=(top+bottom)/2;cx=(left+right)/2
    bevel=min(0.75,(right-left)/3,(bottom-top)/3)
    out=[]
    def line(p,closed=False,weights=weight):
        caps=[]
        for q,near in [(p[0],p[1]),(p[-1],p[-2])]:
            amount=0
            if (char.isupper() or char.isdigit()) and q[1] in (y0,top,bottom,y1) and q[1]!=near[1]:
                dx,dy=(q[0]-near[0])/weights[0],(q[1]-near[1])/weights[1]
                length=hypot(dx,dy)
                target=y0 if q[1] in (y0,top) else y1
                # Even the inset corner of a diagonal terminal must reach the
                # cap/baseline before clipping; extending by a fixed distance
                # leaves steep diagonals with a slanted, prematurely cut foot.
                amount=(abs(target-q[1])/weights[1]*length+abs(dx)/2)/abs(dy)+1e-5
            caps.append(amount)
        out.extend(stroke(p,weights,closed,caps))
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
        # Aim R's leg at its actual baseline centre, so clipping does not shave
        # away the foot's width after extending the formerly slanted terminal.
        if char=='R':line([(cx,mid),(right,y1)])
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
    else:return None
    # Slab serifs use one shared thickness and are kept square-ended.
    if serif:
        out += [rect(x0,y0,3,1),rect(x0,y1-1,3,1)]
    if bold and char=='Y':out.append(rect(cx-1.5,y1-1,3,1))
    if stencil:
        # Deliberate regular-width stencil bridges in the original regions.
        gap=0.75
        if char=='R':
            # The original R has a continuous channel between its slab stem
            # and bowl/leg. Short cuts left a near-touching knee and stray nib.
            out=cut(out,(3.0,y0,0.875,y1-y0))
        elif char in 'BDOP0':
            for y in [y0,y1-1] if char in 'BDO0' else [y0,mid-0.5]:out=cut(out,(3.125,y,gap,1))
        elif char in 'CGS6':
            for y in [y0,y1-1]:out=cut(out,(2.125,y,gap,1))
    return normalize(out,(x0,y0,x1-x0,y1-y0),h)
