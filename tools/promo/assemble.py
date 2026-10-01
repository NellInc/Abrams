#!/usr/bin/env python3
"""Mix the approved audio and assemble the actual OTIO picture edit with FFmpeg."""
import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from urllib.parse import urlparse,unquote

def run(cmd):
    subprocess.run([str(x) for x in cmd],check=True)

def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()

def mix(out):
    m=out/'motion/media';fix=m/'narration-name-fix-dry.wav'
    import wave
    with wave.open(str(fix)) as f:duration=f.getnframes()/f.getframerate()
    factor=duration/3.95
    assert .75<factor<1.3,'Replacement sentence would require excessive time stretch'
    # Replace the entire flawed sentence at a silent boundary, retaining all
    # original words outside it. The explicit pause makes room for a crew call.
    filters=f'[0:a]asplit=3[first][mid][last];[first]atrim=end=4,asetpts=PTS-STARTPTS[a];[1:a]atempo={factor},apad,atrim=duration=3.95,asetpts=PTS-STARTPTS[b];[mid]atrim=start=7.95:end=31.4,asetpts=PTS-STARTPTS[c];anullsrc=r=24000:cl=mono,atrim=duration=1.3[s];[last]atrim=start=31.4,asetpts=PTS-STARTPTS[d];[a][b][c][s][d]concat=n=5:v=0:a=1[n]'
    run(['ffmpeg','-v','error','-y','-i',m/'narration-dry.wav','-i',fix,'-filter_complex',filters,'-map','[n]','-ar','48000','-ac','2',m/'narration-edited.wav'])
    # Smoke and cannon timings follow the recorded original event frame.
    filters='''[0:a]highpass=f=70,loudnorm=I=-17:TP=-2:LRA=7,aresample=48000,aformat=channel_layouts=stereo,apad,atrim=duration=60,asplit[n][side];
[1:a]atrim=duration=60,loudnorm=I=-22:TP=-3:LRA=8,aresample=48000,aformat=channel_layouts=stereo,volume=.6,afade=t=in:st=0:d=0.7,afade=t=out:st=58.5:d=1.5[m];
[m][side]sidechaincompress=threshold=.025:ratio=5:attack=10:release=220[bed0];
[bed0]volume='if(between(t,31.9,33.1),0.25,1)':eval=frame[bed];
[2:a]aresample=48000,aformat=channel_layouts=stereo,volume=.12,adelay=11167|11167[smoke];
[3:a]aresample=48000,aformat=channel_layouts=stereo,volume=.16,adelay=13900|13900[gun];
[4:a]highpass=f=250,lowpass=f=4500,aresample=48000,aformat=channel_layouts=stereo,volume=1,adelay=32067|32067[crew];
[n][bed][smoke][gun][crew]amix=inputs=5:duration=longest:normalize=0,atrim=duration=60,loudnorm=I=-16:TP=-1.5:LRA=8,aresample=48000[out]'''
    run(['ffmpeg','-v','error','-y','-i',m/'narration-edited.wav','-i',m/'music-suno.wav','-i',m/'smoke.wav','-i',m/'cannon.wav','-i',m/'voice_loaded.wav','-filter_complex',filters,'-map','[out]','-ac','2','-c:a','pcm_s24le',m/'final-mix.wav'])
    (out/'audio-edit-receipt.json').write_text(json.dumps({'narration_original_sha256':digest(m/'narration-dry.wav'),'replacement_sentence_sha256':digest(fix),'replacement_range':[4,7.95],'replacement_tempo':factor,'pause_inserted_at':31.4,'pause_seconds':1.3,'crew_event':{'source':'recording-showcase/recording.json','shot':'clear-fire','source_frame':184,'edit_start':32.067,'voice_bank_id':'loaded'},'music_sha256':digest(m/'music-suno.wav'),'final_mix_sha256':digest(m/'final-mix.wav'),'mix_filters':filters},indent=2)+'\n')
    print('MIX_COMPLETE',m/'final-mix.wav')

def assemble(out,copy_audio=False):
    import opentimelineio as otio
    timeline=otio.adapters.read_from_file(str(out/'promo.otio'))
    videos=[t for t in timeline.tracks if t.kind==otio.schema.TrackKind.Video]
    audios=[t for t in timeline.tracks if t.kind==otio.schema.TrackKind.Audio]
    assert len(videos)==len(audios)==1
    clips=list(videos[0]);expected=0;source=clips[0].media_reference.target_url
    for c in clips:
        assert c.media_reference.target_url==source,'This finite edit coalesces one composed picture master'
        assert abs(c.source_range.start_time.to_seconds()-expected)<1e-6
        expected+=c.duration().to_seconds()
    duration=json.loads((out/'production-brief.json').read_text())['duration_seconds']
    assert abs(expected-duration)<1e-6 and abs(timeline.duration().to_seconds()-duration)<1e-6
    audio=audios[0][0];assert audio.source_range.start_time.to_seconds()==0 and audio.duration().to_seconds()==duration
    picture=Path(unquote(urlparse(source).path));mix=Path(unquote(urlparse(audio.media_reference.target_url).path))
    target=out/'abrams-promo-clean.mp4'
    if copy_audio:
        codec=subprocess.check_output(['ffprobe','-v','error','-select_streams','a:0','-show_entries','stream=codec_name','-of','default=nw=1:nk=1',str(mix)],text=True).strip()
        assert codec=='aac','Copy-audio requires a verified AAC master'
    encoding=['-c:a','copy'] if copy_audio else ['-c:a','aac','-b:a','256k']
    run(['ffmpeg','-v','error','-y','-i',picture,'-i',mix,'-t',str(expected),'-map','0:v:0','-map','1:a:0','-c:v','copy',*encoding,'-movflags','+faststart',target])
    (out/'assembly-receipt.json').write_text(json.dumps({'timeline':str(out/'promo.otio'),'timeline_sha256':digest(out/'promo.otio'),'picture_sha256':digest(picture),'mix_sha256':digest(mix),'coalesced_contiguous_picture_clips':len(clips),'duration_seconds':expected,'output_sha256':digest(target)},indent=2)+'\n')
    print('ASSEMBLY_COMPLETE',target)

def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['mix','assemble']);p.add_argument('--output',type=Path,required=True);p.add_argument('--copy-audio',action='store_true');a=p.parse_args()
    if a.action=='mix':mix(a.output.resolve())
    else:assemble(a.output.resolve(),a.copy_audio)

if __name__=='__main__':main()
