#!/usr/bin/env python3
"""Render the finite caption track with Pillow when FFmpeg has no libass."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

def run(args):subprocess.run([str(v) for v in args],check=True)
def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    out=a.output.resolve();review=out/'final-review';frames=review/'caption-images';frames.mkdir(exist_ok=True)
    duration=json.loads((out/'production-brief.json').read_text())['duration_seconds']
    serial=['-threads','1'] if json.loads((out/'production-brief.json').read_text()).get('revision')=='v5' else []
    cues=json.loads((review/'caption-cues.json').read_text())
    font=ImageFont.truetype(str(out/'motion/media/Barlow.ttf'),44)
    blank=frames/'blank.png';Image.new('RGBA',(1920,156)).save(blank)
    concat=[];last=0;bounds=[]
    def item(path,duration):
        if duration>0:concat.extend([f"file '{path}'",f'duration {duration:.6f}'])
    for n,cue in enumerate(cues):
        begin,end=cue['start'],cue['end']
        if 0<last-begin<=.001:begin=last  # older cue files may overlap by float noise
        assert begin>=last and end>begin and end<=duration
        item(blank,begin-last)
        im=Image.new('RGBA',(1920,156));d=ImageDraw.Draw(im);text=cue['text']
        if len(text)>46:
            tokens=text.split();mid=min(range(1,len(tokens)),key=lambda k:abs(len(' '.join(tokens[:k]))-len(' '.join(tokens[k:]))))
            lines=[' '.join(tokens[:mid]),' '.join(tokens[mid:])]
        else:lines=[text]
        top=156-24-50*len(lines)
        for i,line in enumerate(lines):
            width=d.textlength(line,font=font);x=(1920-width)/2;y=top+i*50
            bbox=d.textbbox((x,y),line,font=font,anchor='lt',stroke_width=3)
            assert bbox[0]>=100 and bbox[2]<=1820 and bbox[1]+924>944 and bbox[3]+924<=1058,bbox
            d.text((x,y),line,font=font,anchor='lt',fill='#eee8d7',stroke_width=3,stroke_fill='#090d09')
            bounds.append({'cue':n+1,'start':begin,'end':end,'line':line,'bbox':[bbox[0],bbox[1]+924,bbox[2],bbox[3]+924]})
        image=frames/f'{n:02}.png';im.save(image);item(image,end-begin);last=end
    item(blank,duration-last);concat.append(f"file '{blank}'")
    listing=review/'caption-images.concat';listing.write_text('\n'.join(concat)+'\n')
    layer=review/'caption-layer.mov'
    run(['ffmpeg','-v','error','-y','-f','concat','-safe','0','-i',listing,'-vf','fps=30','-t',duration,'-c:v','qtrle','-pix_fmt','argb',*serial,layer])
    video=out/'abrams-promo.mp4'
    run(['ffmpeg','-v','error','-y',*serial,'-i',out/'abrams-promo-clean.mp4','-i',layer,
         '-filter_complex','[0:v][1:v]overlay=x=0:y=924:format=auto[v]','-map','[v]','-map','0:a:0',
         '-t',duration,'-c:v','libx264','-pix_fmt','yuv420p','-crf','18','-preset','medium',*serial,'-c:a','copy','-movflags','+faststart',video])
    (review/'caption-render-receipt.json').write_text(json.dumps({'renderer':'Pillow RGBA + FFmpeg qtrle overlay; local FFmpeg lacks libass',
        'clean_video_sha256':digest(out/'abrams-promo-clean.mp4'),'video_sha256':digest(video),
        'srt_sha256':digest(review/'abrams-promo.srt'),'vtt_sha256':digest(review/'abrams-promo.vtt'),
        'timing_source':'transcription.json and the source mappings in abrams-promo-words.json','timing_quantization_seconds':1/30,
        'audio_stream':'AAC copied without reencoding','caption_bounds':bounds},indent=2)+'\n')
    print('CAPTIONED_EXPORT_COMPLETE',video)

if __name__=='__main__':main()
