#!/usr/bin/env python3
"""Create five authored isolated SFX for qualified original dispatcher requests.

No semantic event name or exact historic timbre is claimed. Samples are entirely
new synthesis, no game recordings, ROM samples, speech or remote service.
"""
from pathlib import Path
import hashlib,json,math,random,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
from tools.build_audio import RATE,pcm
REQUESTS={7:(0.9,'descending rough pulse'),9:(0.5,'short percussive report'),10:(1.25,'low percussive report'),15:(0.7,'alternating attention pulse'),16:(0.16,'double control click')}

def samples(request):
    seconds,_=REQUESTS[request];rng=random.Random(1988+request);result=[];low=0.0
    for i in range(round(seconds*RATE)):
        t=i/RATE;noise=rng.uniform(-1,1);low+=0.035*(noise-low)
        if request==7:
            x=0.20*math.sin(2*math.pi*(460*t-130*t*t))*math.exp(-t*2.5)*(0.65+0.35*math.sin(2*math.pi*18*t))
        elif request in (9,10):
            decay=10 if request==9 else 4
            x=0.5*low*math.exp(-t*decay)+0.12*noise*math.exp(-t*45)+0.16*math.sin(2*math.pi*75*t)*math.exp(-t*decay)
        elif request==15:
            phase=t%0.3
            x=0.16*math.sin(2*math.pi*(660 if t<0.3 else 880)*t)*min(1,phase/0.015,max(0,(0.23-phase)/0.02)) if phase<0.23 else 0
        else:
            age=t if t<0.075 else t-0.075
            x=(0.1*noise+0.06*math.sin(2*math.pi*2300*age))*math.exp(-age*100)
        result.append(x)
    return result

def main():
    output=ROOT/'godot/assets/audio';receipt={'scope':__doc__,'builder_sha256':hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),'samples':{}}
    for request,(_,description) in REQUESTS.items():
        path=output/f'pc_request_{request:02}.wav'
        if path.exists():raise FileExistsError('Refusing to overwrite existing request sample')
        pcm(path,samples(request));receipt['samples'][path.stem]={'request':request,'description':description,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source':'Original mathematical synthesis'}
    (output/'pc_request_provenance.json').write_text(json.dumps(receipt,indent=2)+'\n')
if __name__=='__main__':main()
