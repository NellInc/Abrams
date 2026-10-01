#!/usr/bin/env python3
"""Finite v3 native-clip conversion, sampled-pose animatic and AAC binding."""
import argparse,json,re,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
from v3_audio import sha,write,run,audio_hash

def encode(out):
    roster=json.loads((out/'capture-roster.json').read_text());receipt=json.loads((out/'modern-capture/modern-capture-receipt.json').read_text())
    assert receipt['roster_sha256']==sha(out/'capture-roster.json')
    assert len(receipt['clips'])==len(roster)==5
    results=[]
    for clip,proof in zip(roster,receipt['clips']):
        assert clip['name']==proof['name'] and proof['source_sha256']==clip['sha256']
        assert len(proof['frames'])==clip['end']-clip['begin']
        assert all(x['mode']=='modern' and x['modern_enabled'] and x['modern_active'] and x['world_enabled'] for x in proof['frames'])
        frames=out/'modern-capture'/clip['name'];images=sorted(frames.glob('frame_*.png'));assert len(images)==len(proof['frames'])
        target=out/'motion/media'/(clip['name']+'.mp4');assert not target.exists()
        run(['ffmpeg','-v','error','-y','-framerate','30','-i',frames/'frame_%05d.png','-frames:v',len(images),'-c:v','libx264','-threads','1','-crf','18','-preset','fast','-g','30','-keyint_min','30','-pix_fmt','yuv420p','-movflags','+faststart',target])
        results.append({'clip':clip['name'],'source_sha256':clip['sha256'],'frames':len(images),'fps':30,'video_sha256':sha(target),'mode':'modern','all_world_pairing_asserted':True,'all_production_modern_active_asserted':True})
    write(out/'modern-encode-receipt.json',results);print('FIVE_MODERN_CLIPS_ENCODED',sum(x['frames'] for x in results))

def animatic(out):
    brief=json.loads((out/'production-brief.json').read_text());folder=out/'animatic-snapshots';candidates=[]
    for p in folder.glob('frame-*-at-*s.png'):
        t=float(re.search(r'at-([0-9.]+)s\.png',p.name)[1]);candidates.append((t,p))
    def image_at(t):
        found=sorted(candidates,key=lambda x:abs(x[0]-t));assert found and abs(found[0][0]-t)<=1/60+.0011,t
        return found[0]
    listing=[];entries=[]
    def hold(t,d):
        assert d>0;selected,im=image_at(t);listing.extend([f"file '{im}'",f'duration {d:.8f}']);entries.append({'sample_time':round(selected*30)/30,'requested_midpoint_or_pose_time':t,'hold':d,'path':str(im),'sha256':sha(im)})
    for shot in brief['shots']:
        a,d=shot['start'],shot['duration'];z=a+d
        if shot['kind']=='voice_showcase':
            for dt in [0,.1,.2,.3]:hold(a+dt,.1)
            hold(a+d/2,d-.5);hold(z-.1,.1)
        else:hold(a+d/2,d)
    assert abs(sum(e['hold'] for e in entries)-60)<1e-6
    listing.append(f"file '{entries[-1]['path']}'");path=out/'animatic.concat';path.write_text('\n'.join(listing)+'\n')
    run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',path,'-i',out/'motion/media/final-mix.m4a','-vf','scale=960:540,fps=30','-t','60','-map','0:v:0','-map','1:a:0','-c:v','libx264','-threads','1','-crf','25','-preset','fast','-pix_fmt','yuv420p','-c:a','copy',out/'abrams-v3-animatic.mp4'])
    write(out/'animatic-receipt.json',{'scope':'Low-cost sampled-pose animatic of actual HTML: still shot midpoints and portrait entrance/exit samples, actual final AAC speech/music. Not final motion playback.','entries':entries,'source_audio_sha256':sha(out/'motion/media/final-mix.m4a'),'animatic_sha256':sha(out/'abrams-v3-animatic.mp4')})
    # Paginate every snapshot so none disappears in a huge resized contact sheet.
    pages=out/'animatic-review-pages';pages.mkdir(exist_ok=True)
    for page in range((len(candidates)+11)//12):
        sheet=Image.new('RGB',(1440,900),'#141915');draw=ImageDraw.Draw(sheet)
        for n,(t,p) in enumerate(sorted(candidates)[page*12:(page+1)*12]):
            x=n%3*480;y=n//3*225;im=ImageOps.contain(Image.open(p).convert('RGB'),(480,200));sheet.paste(im,(x,y));draw.text((x+10,y+203),f'{t:.3f}s',fill='white')
        sheet.save(pages/f'page-{page:02}.jpg',quality=94)
    print('V3_ANIMATIC_READY',len(entries),'sample holds',len(candidates),'snapshots')

def bind(out):
    master=out/'motion/media/final-mix.m4a';video=out/'abrams-promo-clean.mp4';transcript=json.loads((out/'final-review/transcription.json').read_text());pcm=audio_hash(video)
    assert audio_hash(master)==pcm==transcript['audio_pcm_sha256'],'Encoded audio differs from actual caption source'
    write(out/'audio-picture-binding.json',{'master_sha256':sha(master),'clean_video_sha256':sha(video),'actual_decoded_pcm_sha256':pcm,'aac_copied_without_reencoding':True,'caption_asr_source_sha256':transcript['source_sha256'],'asr_source_matches_final_audio':True});print('FINAL_AUDIO_CAPTION_BINDING_PASS')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('action',choices=['encode','animatic','bind']);p.add_argument('--output',type=Path,required=True);a=p.parse_args();globals()[a.action](a.output.resolve())
