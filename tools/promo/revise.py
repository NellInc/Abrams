#!/usr/bin/env python3
"""Finite second-cut promo: authentic logo, four crew and current model pairs."""
import argparse,hashlib,html,json,re,shutil,subprocess,wave
from pathlib import Path
import opentimelineio as otio

ROOT=Path(__file__).resolve().parents[2]
def run(cmd):subprocess.run([str(x) for x in cmd],check=True)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,x):p.write_text(json.dumps(x,indent=2)+'\n')
def put(source,target):
    # V1 media were hardlinked for read-only reuse. Never overwrite a link.
    if target.exists():target.unlink()
    shutil.copy2(source,target)

def make(out,duration,picture_only=False,base_html=ROOT/'artifacts/promo-20260929/motion/index.html'):
    media=out/'motion/media';long=duration==75;k=1 if long else 1/1.12
    # Resolve every input before put()/ffmpeg replace anything in motion/media.
    if not base_html.exists():raise SystemExit(f'Base composition {base_html} is missing; pass --base-html <v1 motion/index.html>.')
    if base_html.resolve()==(out/'motion/index.html').resolve():raise SystemExit('--base-html must be the v1 composition, not this revision output (its v2 CSS would be appended twice).')
    needed=[out/f'colonel-stills/colonel-{mode}.png' for mode in ['genesis','modern']]+[out/f'model-pairs/pair-{index:03}.png' for index in [125,163,161,155,156]]
    if not picture_only:needed+=[media/n for n in ['narration-dry.wav','narration-pronunciation-v2-ah-only-dry.wav','music-suno.wav','smoke.wav','cannon.wav']]
    missing=[str(p) for p in needed if not p.exists()]
    if missing:raise SystemExit('Missing revision inputs: '+', '.join(missing))
    base_styles=re.search(r'<style>(.*?)</style>',base_html.read_text(),re.S).group(1)
    if '.logo-bug{' in base_styles:raise SystemExit(f'{base_html} already carries the v2 styles; pass the v1 composition.')
    crew_start=31.4*k;crew_pause=8 if long else 5.4;extra_pause=4 if long else 0
    model_start=crew_start+crew_pause;model_end=44.1*k+crew_pause+extra_pause-.7*(1 if long else 0)
    checkpoint=56.1 if long else 44.1*k+crew_pause
    exterior=60.1 if long else 48.0*k+crew_pause
    modern_play=66.5 if long else 54.6;closing=duration-3.7
    choices=[('commander','ready' if long else 'hit'),('gunner','on_the_way'),('loader','loaded'),('driver','moving')]
    widths=[3.8,1.4,1.4,1.4] if long else [1.35]*4
    provenance=json.loads((ROOT/'godot/assets/audio/provenance.json').read_text())['voices']
    crews=[];at=crew_start
    for (role,cue),width in zip(choices,widths):
        voice=media/f'voice_{cue}.wav'
        assert sha(voice)==provenance[cue]['sha256']
        with wave.open(str(voice)) as f:length=f.getnframes()/f.getframerate()
        start=at+.05;assert start+length<=at+width+.001
        crews.append({'role':role,'cue':cue,'text':provenance[cue]['performed_text'],'scene_start':at,'scene_end':at+width,'audio_start':start,'audio_end':start+length,'sha256':sha(voice)})
        at+=width
    for mode in ['genesis','modern']:put(out/f'colonel-stills/colonel-{mode}.png',media/f'colonel-{mode}.png')
    for index in [125,163,161,155,156]:
        # Remove research headings, retain both full model viewports.
        run(['ffmpeg','-v','error','-y','-i',out/f'model-pairs/pair-{index:03}.png','-vf','crop=1400:420:0:60','-frames:v','1',media/f'unit-{index}.png'])
    brief=json.loads((ROOT/'tools/promo/brief.json').read_text());brief['duration_seconds']=duration
    brief['revision']='v2';brief['dynamix_pronunciation']='DYE-NAHH-MIX';brief['crew_showcase']=crews
    scenes=[];animation=[];shots=[]
    def v(name,start,end,offset=0,css='game'):
        assert (media/name).exists(),name
        begin_frame=round(start*30);end_frame=round(end*30)
        # Match the section cuts exactly, including their floating-point
        # representation. Decimal rounding can put a source one frame late.
        return f'<video id="v{len(shots)}-{name.replace(".","-")}" class="{css}" src="media/{name}" data-start="{begin_frame/30}" data-duration="{(end_frame-begin_frame)/30}" data-media-start="{offset}" muted playsinline></video>'
    def pic(name,css='game',extra=''):return f'<img class="{css}" src="media/{name}" {extra}>'
    def label(text):return f'<div class="source-label">{html.escape(text)}</div>'
    def logo(css='logo-bug'):return pic('game-logo.png',css)
    def add(sid,start,end,body,kind,inputs,purpose):
        begin=round(start*30)/30;finish=round(end*30)/30
        assert finish>begin
        scenes.append(f'<section id="{sid}" class="shot">{body}</section>')
        animation.append(f"gsap.set('#{sid}',{{autoAlpha:0}});tl.set('#{sid}',{{autoAlpha:1}},{begin});tl.set('#{sid}',{{autoAlpha:0}},{finish});")
        shots.append({'id':sid,'start':begin,'duration':finish-begin,'kind':kind,'inputs':inputs,'purpose':purpose})
    def roster():
        return '<div class="avatar-roster">'+''.join(f'<div>{pic("avatar-"+r+".png","avatar")}<p>{r.upper()}</p></div>' for r in ['commander','gunner','loader','driver'])+'</div>'
    add('crew',0,1.4*k,roster()+'<h1 class="roster-heading">FOUR CREW</h1>','artwork',['avatar-commander.png','avatar-gunner.png','avatar-loader.png','avatar-driver.png'],'All four installed upgraded crew identities, not a colonel standing in for them.')
    add('tank',1.4*k,2.6*k,pic('gunner-upscaled.png')+'<h1 class="opening-word">ONE TANK</h1>','game_capture',['gunner-upscaled.png'],'Authentic gunner station.')
    add('command',2.6*k,3.8*k,v('game-stations.mp4',2.6*k,3.8*k,4.1)+'<h1 class="opening-word">YOUR COMMAND</h1>','game_capture',['game-stations.mp4'],'Original driver station capture.')
    add('reveal',3.8*k,6.8*k,v('veo-opening.mp4',3.8*k,6.8*k,0,'cinema')+'<div class="shade"></div>'+logo('cinema-logo')+'<div class="logo-tag">FAN REMASTER</div>','illustration',['veo-opening.mp4','game-logo.png'],'Existing Veo illustration, now carrying the actual restored game logo.')
    for sid,a,b,name,offset,title in [('heritage',6.8,8.2,'game-original.mp4',1,'DYNAMIX / ORIGINAL PC'),('scan',8.2,9.8,'game-horizon.mp4',1.4,'SCAN THE HORIZON'),('terrain',9.8,10.7,'game-terrain.mp4',3.2,'WORK THE TERRAIN'),('smoke',10.7,14.4,'game-smoke-fire.mp4',.6,'ABRAMS BATTLE TANK / FAN REMASTER')]:
        add(sid,a*k,b*k,v(name,a*k,b*k,offset)+label(title)+logo(),'game_capture',[name],'Original SIM packet recording, using the stated production presentation.')
    body=pic('colonel-modern.png')+pic('colonel-genesis.png',extra='id="before"')+'<div id="compare-edge"></div><h2 class="comparison-heading">A FAMILIAR WORLD, RESTORED</h2>'+label('GENESIS → MODERN')+logo()
    add('restoration',14.4*k,22.2*k,body,'comparison',['colonel-genesis.png','colonel-modern.png'],'The same genuine BRIEF frame in actual Genesis and Modern modes.')
    animation += [f"tl.fromTo('#before',{{clipPath:'inset(0 0% 0 0)'}},{{clipPath:'inset(0 100% 0 0)',duration:{3.6*k},ease:'power2.inOut'}},{16.4*k});",f"tl.fromTo('#compare-edge',{{x:1152}},{{x:0,duration:{3.6*k},ease:'power2.inOut'}},{16.4*k});tl.set('#compare-edge',{{autoAlpha:0}},{20.05*k});"]
    panels=''.join(f'<div class="mode-panel mode-{i}">{pic("colonel-"+mode+".png","style-screen")}<p>{mode.upper()}</p></div>' for i,mode in enumerate(['genesis','modern']))
    add('styles',22.2*k,25.6*k,'<h2 class="style-heading">A CHOICE OF VISUAL STYLES</h2>'+panels+logo(),'comparison',['colonel-genesis.png','colonel-modern.png'],'Both full 4:3 graphics modes, captured from one original source frame.')
    add('hatch',25.6*k,27.1*k,v('game-stations.mp4',25.6*k,27.1*k,2.1)+label('BACK THROUGH THE HATCH')+logo(),'game_capture',['game-stations.mp4'],'Authentic cockpit before introducing its crew.')
    add('avatars',27.1*k,crew_start,roster()+'<h1 class="roster-heading">EVERY STATION, BROUGHT TO LIFE</h1>'+logo(),'artwork',[f'avatar-{r}.png' for r in ['commander','gunner','loader','driver']],'The bring-every-station line shows the four actual upgraded portraits.')
    for crew in crews:
        role=crew['role'];a,b=crew['scene_start'],crew['scene_end']
        body=pic(f'avatar-{role}.png','solo-avatar')+f'<div class="crew-copy"><h1>{role.upper()}</h1><p>{html.escape(crew["text"])}</p></div>'+logo()
        add('bark-'+role,a,b,body,'voice_showcase',[f'avatar-{role}.png',f'voice_{crew["cue"]}.wav'],'Installed role-matched portrait and voice sample. Editorial showcase, not a fabricated original-game event.')
    for n,(index,title) in enumerate([(125,'M1A1 ABRAMS'),(163,'HIND HELICOPTER'),(161,'SAGGER TEAM'),(156,'US BASE COMPOUND')]):
        a=model_start+(model_end-model_start)*n/4;b=model_start+(model_end-model_start)*(n+1)/4
        body=f'<h1 class="model-heading">{title}</h1>'+pic(f'unit-{index}.png','unit-pair')+'<div class="model-side original-side">ORIGINAL PC</div><div class="model-side modern-side">MODERN</div>'+v('engine-link.mp4',a,b,0,'model-link')+'<p class="model-note">Modern graphics (experimental)</p>'+logo()
        add('model-'+str(index),a,b,body,'model_comparison',[f'unit-{index}.png','engine-link.mp4'],'Fresh native original-versus-current model study, including production livery and observed crew head commands; not a gameplay capture.')
    if long:add('field-return',model_end,checkpoint,v('game-horizon.mp4',model_end,checkpoint,2)+label('REMASTER / ORIGINAL SIMULATION')+logo(),'game_capture',['game-horizon.mp4'],'Authentic Upscaled gameplay, retaining the original simulation.')
    split=round((checkpoint+1.3)*30)/30
    cp=v('game-checkpoint-away.mp4',checkpoint,split,.8)+v('game-checkpoint-return.mp4',split,exterior,0)+v('checkpoint-marker.mp4',checkpoint,exterior,0,'checkpoint-marker')+label('SAVE STATES / QUICK LOAD')+logo()
    add('checkpoint',checkpoint,exterior,cp,'game_capture',['game-checkpoint-away.mp4','game-checkpoint-return.mp4','checkpoint-marker.mp4'],'Real isolated save/load from the first promo, retained without invented UI.')
    animation += [f"gsap.set('#v{len(shots)-1}-game-checkpoint-return-mp4',{{autoAlpha:0}});tl.set('#v{len(shots)-1}-game-checkpoint-away-mp4',{{autoAlpha:0}},{split});tl.set('#v{len(shots)-1}-game-checkpoint-return-mp4',{{autoAlpha:1}},{split});"]
    body=v('seedance-exterior.mp4',exterior,modern_play,0,'cinema')+'<div class="shade"></div>'+logo('cinema-logo')+'<div class="logo-tag">FAN REMASTER<br><b>FREE AND OPEN</b><small>Original PC game required</small></div>'
    add('exterior',exterior,modern_play,body,'illustration',['seedance-exterior.mp4','game-logo.png'],'Existing Seedance motion shot with actual game branding and ownership requirement.')
    add('game-return',modern_play,closing,v('game-horizon.mp4',modern_play,closing,0)+label('REMASTER / ORIGINAL SIMULATION')+logo(),'game_capture',['game-horizon.mp4'],'Clean authentic Upscaled gameplay, retaining the original simulation. Modern assets are demonstrated in the matched colonel and unit studies.')
    body=pic('cover.png','cover')+'<div class="end-copy">'+logo('end-logo')+'<h2>FAN REMASTER</h2><p class="free">Free and open</p><p class="requirement">Bring your own original PC game.</p><p class="url">github.com/NellInc/Abrams</p><p class="dedication">Dedicated to the memory of<br>David “Ming” Kenny.</p></div>'
    add('closing',closing,duration,body,'endcard',['cover.png','game-logo.png'],'Actual game logo, project URL, original-PC requirement and memorial.')
    assert all(abs(a['start']+a['duration']-b['start'])<1e-6 for a,b in zip(shots,shots[1:]))
    styles=base_styles
    styles+='''.logo-bug{position:absolute;right:60px;top:48px;width:160px;height:120px;object-fit:contain}.cinema-logo{position:absolute;left:100px;bottom:280px;width:370px;height:277px;object-fit:contain;box-shadow:0 5px 35px #0008}.logo-tag{position:absolute;left:100px;bottom:166px;font:27px Plex;letter-spacing:3px;color:#eee8d7;line-height:1.6}.logo-tag b{font:27px Plex;color:#dfc796}.logo-tag small{display:block;font:26px Barlow;letter-spacing:0}.avatar-roster{position:absolute;left:100px;top:260px;display:flex;gap:45px}.avatar-roster>div{width:395px}.avatar{width:395px;height:395px;object-fit:contain}.avatar-roster p{text-align:center;font:28px Plex;color:#c4ab76;letter-spacing:2px}.roster-heading{position:absolute;left:100px;top:100px;font-size:72px;letter-spacing:3px}.solo-avatar{position:absolute;left:200px;top:160px;width:680px;height:680px;object-fit:contain}.crew-copy{position:absolute;left:1040px;top:335px;width:670px}.crew-copy h1{font-size:82px;letter-spacing:4px;margin:0 0 35px}.crew-copy p{font-size:52px;line-height:1.2;color:#c4ab76}.mode-panel{position:absolute;top:310px;width:640px}.mode-0{left:230px}.mode-1{left:1050px}.mode-panel .style-screen{width:640px;height:480px}.mode-panel p{text-align:center;font:28px Plex;color:#c4ab76}.model-heading{position:absolute;left:100px;top:70px;font-size:70px;letter-spacing:3px;margin:0}.unit-pair{position:absolute;left:100px;top:230px;width:1720px;height:516px;object-fit:contain}.model-side{position:absolute;top:780px;width:860px;text-align:center;font:28px Plex;color:#c4ab76}.original-side{left:100px}.modern-side{left:960px}.model-link{position:absolute;left:100px;top:855px;width:1720px;height:100px;object-fit:contain}.model-note{position:absolute;left:100px;top:190px;margin:0;font:20px Plex;color:#c4ab76}.end-copy{top:85px}.end-logo{width:390px;height:292px;object-fit:contain}.end-copy h2{margin:15px 0 28px}.end-copy .dedication{padding-top:8px}.end-copy p{margin:16px 0}'''
    styles += '#restoration .source-label{left:100px;top:180px;width:240px;line-height:1.5}'
    document='<!doctype html><html><head><meta charset="utf-8"><style>'+styles+'</style><script src="node_modules/gsap/dist/gsap.min.js"></script></head><body>'+f'<main id="main" data-composition-id="main" data-start="0" data-duration="{duration}" data-width="1920" data-height="1080" data-fps="30">'+''.join(scenes)+'</main><script>window.__timelines=window.__timelines||{};const tl=gsap.timeline({paused:true});'+''.join(animation)+f"tl.to('#closing',{{opacity:0,duration:.4}},{duration-.4});window.__timelines.main=tl;"+'</script></body></html>'
    (out/'motion/index.html').write_text(document);brief['shots']=shots;brief['internal_transitions']=[split];write(out/'production-brief.json',brief)
    rt=otio.opentime.RationalTime;tr=otio.opentime.TimeRange;timeline=otio.schema.Timeline(name=brief['title']);track=otio.schema.Track(name='Picture',kind=otio.schema.TrackKind.Video)
    for s in shots:track.append(otio.schema.Clip(name=s['id'],media_reference=otio.schema.ExternalReference(target_url=(out/'visual-edit.mp4').as_uri()),source_range=tr(rt(round(s['start']*30),30),rt(round(s['duration']*30),30)),metadata={'kind':s['kind'],'purpose':s['purpose']}))
    timeline.tracks.append(track);audio=otio.schema.Track(name='Final mix',kind=otio.schema.TrackKind.Audio);audio.append(otio.schema.Clip(name='Narration, crew and Suno',media_reference=otio.schema.ExternalReference(target_url=(media/'final-mix.wav').as_uri()),source_range=tr(rt(0,30),rt(duration*30,30))));timeline.tracks.append(audio);otio.adapters.write_to_file(timeline,str(out/'promo.otio'))
    # Three narration chunks retain their actual input boundaries; crew inserts
    # are separately measured source assets and never overlap the narrator.
    first=crew_start;middle_start=first+crew_pause;middle_end=44.1*k+crew_pause
    segments=[{'speaker':'narrator','start':0,'end':first},*({'speaker':c['role'],'start':c['audio_start'],'end':c['audio_end'],'expected':c['text']} for c in crews),{'speaker':'narrator','start':middle_start,'end':middle_end},{'speaker':'narrator','start':middle_end+extra_pause,'end':54.32*k+crew_pause+extra_pause}]
    write(out/'speech-segments.json',segments)
    if not picture_only:mix(out,duration,k,crew_pause,extra_pause,crews)
    print('REVISION_COMPOSITION_READY',duration,'seconds',len(shots),'shots')

def mix(out,duration,k,pause,extra,crews):
    m=out/'motion/media';fix=m/'narration-pronunciation-v2-ah-only-dry.wav'
    with wave.open(str(fix)) as f:factor=(f.getnframes()/f.getframerate())/3.95
    assert .75<factor<1.3
    tempo=1/k
    parts=f'[0:a]asplit=4[p0][p1][p2][p3];[p0]atrim=end=4,asetpts=PTS-STARTPTS,atempo={tempo}[a];[1:a]atempo={factor},apad,atrim=duration=3.95,asetpts=PTS-STARTPTS,atempo={tempo}[b];[p1]atrim=start=7.95:end=31.4,asetpts=PTS-STARTPTS,atempo={tempo}[c];[p2]atrim=start=31.4:end=44.1,asetpts=PTS-STARTPTS,atempo={tempo}[d];[p3]atrim=start=44.1,asetpts=PTS-STARTPTS,atempo={tempo}[e];anullsrc=r=24000:cl=mono,atrim=duration={pause}[s];'
    if extra:parts+=f'anullsrc=r=24000:cl=mono,atrim=duration={extra}[t];[a][b][c][s][d][t][e]concat=n=7:v=0:a=1[n]'
    else:parts+='[a][b][c][s][d][e]concat=n=6:v=0:a=1[n]'
    narration=m/'narration-edited-v2.wav';run(['ffmpeg','-v','error','-y','-i',m/'narration-dry.wav','-i',fix,'-filter_complex',parts,'-map','[n]','-ar','48000','-ac','2',narration])
    score=m/'music-suno-v2.wav'
    if duration==75:
        # Extend the existing instrumental through an internal score loop, keep
        # its original resolution at the end. No new Suno request or vocals.
        run(['ffmpeg','-v','error','-y','-i',m/'music-suno.wav','-filter_complex','[0:a]asplit=3[a][b][c];[a]atrim=end=36,asetpts=PTS-STARTPTS[x];[b]atrim=start=20:end=35.2,asetpts=PTS-STARTPTS[y];[c]atrim=start=36,asetpts=PTS-STARTPTS[z];[x][y]acrossfade=d=0.1[xy];[xy][z]acrossfade=d=0.1[out]','-map','[out]','-ar','48000','-ac','2',score])
    else:put(m/'music-suno.wav',score)
    inputs=['ffmpeg','-v','error','-y','-i',narration,'-i',score]
    for c in crews:inputs+=['-i',m/f'voice_{c["cue"]}.wav']
    inputs+=['-i',m/'smoke.wav','-i',m/'cannon.wav']
    pause_start=31.4*k
    filters=f'[0:a]highpass=f=70,loudnorm=I=-17:TP=-2:LRA=7,aresample=48000,aformat=channel_layouts=stereo,apad,atrim=duration={duration},asplit[n][side];[1:a]loudnorm=I=-22:TP=-3:LRA=8,aresample=48000,aformat=channel_layouts=stereo,volume=.6,afade=t=in:d=0.7,afade=t=out:st={duration-1.5}:d=1.5[m];[m][side]sidechaincompress=threshold=.025:ratio=5:attack=10:release=220[bed0];[bed0]volume=\'if(between(t,{pause_start},{pause_start+pause}),0.3,1)\':eval=frame[bed];'
    for i,c in enumerate(crews,2):
        delay=round(c['audio_start']*1000);filters+=f'[{i}:a]highpass=f=120,loudnorm=I=-18:TP=-3:LRA=7,aresample=48000,aformat=channel_layouts=stereo,adelay={delay}|{delay}[c{i}];'
    smoke=round((10.7*k+.467)*1000);cannon=round((10.7*k+3.2)*1000)
    filters+=f'[6:a]aresample=48000,aformat=channel_layouts=stereo,volume=.12,adelay={smoke}|{smoke}[smoke];[7:a]aresample=48000,aformat=channel_layouts=stereo,volume=.16,adelay={cannon}|{cannon}[gun];[n][bed][c2][c3][c4][c5][smoke][gun]amix=inputs=8:duration=longest:normalize=0,atrim=duration={duration},loudnorm=I=-16:TP=-1.5:LRA=8,aresample=48000[out]'
    target=m/'final-mix.wav'
    if target.exists():target.unlink()
    run(inputs+['-filter_complex',filters,'-map','[out]','-ac','2','-c:a','pcm_s24le',target])
    write(out/'audio-edit-receipt.json',{'duration':duration,'narration_tempo':tempo,'replacement_sentence':str(fix),'replacement_sha256':sha(fix),'replacement_tempo':factor,'crew_pause':pause,'additional_pause':extra,'crew_showcase':crews,'final_mix_sha256':sha(target),'filters':filters})

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--duration',type=int,choices=[60,75],default=60);p.add_argument('--picture-only',action='store_true');p.add_argument('--base-html',type=Path,default=ROOT/'artifacts/promo-20260929/motion/index.html');a=p.parse_args();make(a.output.resolve(),a.duration,a.picture_only,a.base_html)
