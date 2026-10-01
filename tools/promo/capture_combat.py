#!/usr/bin/env python3
"""Finite ordinary-input original-PC enemy approach and magnified sight capture."""
import argparse,hashlib,json,math,subprocess,sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser();ap.add_argument('--output',type=Path,required=True);a=ap.parse_args()
    out=a.output.resolve();out.mkdir(exist_ok=False);source=ROOT/'artifacts/pc-source-boot-01/mission-entry/reference.state'
    source_pins={str(p):sha(p) for p in [source,ROOT/'.runtime/pc-core/abrams-trace.dylib',ROOT/'tools/pc_bridge_host.py']}
    route=[];counter=0
    with (out/'host.log').open('w') as log:
        host=subprocess.Popen([sys.executable,str(ROOT/'tools/pc_bridge_host.py'),'--backend','trace','--state',str(source),'--saves',str(out/'saves'),'--frame-audit'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=log,text=True)
        def read():
            line=host.stdout.readline()
            if not line:raise RuntimeError('Original core ended; retained host.log')
            d=json.loads(line);assert d['type']!='error',d.get('message');return d
        current=read();assert current['program']['name']=='SIM'
        def step(keys=()):
            nonlocal counter,current
            counter+=1;assert counter<=900,'Finite source input bound exceeded'
            host.stdin.write(json.dumps({'op':'step','id':counter,'frames':2,'keys':list(keys)})+'\n');host.stdin.flush();current=read();assert current['id']==counter
            s=current['state'];route.append({'packet':counter,'keys':list(keys),'heading':s['heading_degrees'],'bearing':s['bearing_degrees'],'position':s['world_position_raw']});return current
        def enemy():
            s=current['state'];pos=s['world_position_raw'];objects=[x for x in s['world']['dynamic'] if 115<=x['shape_index']<=122]
            assert objects,'No source enemy armour remains allocated'
            item=min(objects,key=lambda x:sum((x['world_position_raw'][i]-pos[i])**2 for i in [0,1]));delta=[item['world_position_raw'][i]-pos[i] for i in [0,1]]
            return item,math.degrees(math.atan2(delta[0],-delta[1]))%360,math.hypot(*delta)
        def aim(field,bound=100):
            for _ in range(bound):
                _,desired,_=enemy();delta=(desired-current['state'][field]+180)%360-180
                if abs(delta)<1.8:return
                step(['right' if delta>0 else 'left'])
            raise RuntimeError('Finite ordinary steering did not converge')
        frames=[]
        try:
            step(['f4']);step();aim('heading_degrees')
            for _ in range(420):
                if enemy()[2]<2600:break
                step(['up'])
            # Prior source captures show kp5 leaves speed66 unchanged. Use
            # ordinary reverse input to brake, and verify actual source speed.
            for _ in range(60):
                speed=current['state']['speed_raw']
                if abs(speed)<=1:break
                step(['down' if speed>0 else 'up'])
            assert abs(current['state']['speed_raw'])<=1,'Ordinary braking did not converge'
            step();step(['f1']);step();aim('bearing_degrees')
            for _ in range(2):step(['z']);step();step()
            path=out/'close-enemy.jsonl'
            with path.open('w') as f:
                for n in range(90):
                    packet=step();packet['promo_keys']=[];f.write(json.dumps(packet,separators=(',',':'))+'\n')
                    drawn=[];draw=packet['presentation']['draw_pass'];assert isinstance(draw,dict) and packet['state']['station']=='gunner'
                    for obj in draw['objects']:
                        if not 115<=obj['shape_index']<=122:continue
                        pts=[q for poly in obj.get('polygons',[]) for q in poly.get('pixels',[])]
                        if not pts:continue
                        x=[v[0] for v in pts];y=[v[1] for v in pts];clip=draw['camera']['clip'];width=max(0,min(max(x),clip[2])-max(min(x),clip[0]));height=max(0,min(max(y),clip[3])-max(min(y),clip[1]))
                        drawn.append({'shape':obj['shape_index'],'pointer':obj['pointer'],'visible_bbox':[width,height]})
                    frames.append({'index':n,'sequence':packet['sequence'],'enemy_draws':drawn,'focal_pixels':draw['camera']['focal_pixels']})
            assert all(x['enemy_draws'] for x in frames),'Actual enemy not drawn throughout final clip'
            assert max(y['visible_bbox'][0] for x in frames for y in x['enemy_draws'])>=35,'Enemy remains too small for requested close shot'
        finally:
            if host.poll() is None:host.stdin.write('{"op":"quit"}\n');host.stdin.flush()
            code=host.wait();assert code==0,code
            (out/'route-readback.json').write_text(json.dumps(route,indent=2)+'\n')
            (out/'last-source-packet.json').write_text(json.dumps(current,separators=(',',':'))+'\n')
        for p,h in source_pins.items():assert sha(Path(p))==h
        receipt={'source_pins':source_pins,'route':route,'frames':frames,'packet_sha256':sha(path),'scope':'Original PC SIM, ordinary station/steering/throttle/stop/1x3x10x magnification keys only. No synthetic packets, state edits or fabricated game graphics. Genuine enemy armour optical close view. Damage voice is an editorial use of the installed warning bank, not proof of this recorded event.'}
        (out/'recording-receipt.json').write_text(json.dumps(receipt,indent=2)+'\n')
        roster=[{'name':'modern-close-combat','packets':str(path),'sha256':sha(path),'begin':0,'end':90,'station':'gunner'}]
        (out.parent/'close-capture-roster.json').write_text(json.dumps(roster,indent=2)+'\n');print('ORIGINAL_CLOSE_ENEMY_COMPLETE',counter,len(frames))
if __name__=='__main__':main()
