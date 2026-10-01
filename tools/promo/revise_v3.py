#!/usr/bin/env python3
"""Third promo edit: fixed Modern captures, natural narration and swept barks."""
import argparse,html,json,re,wave
from pathlib import Path
import opentimelineio as otio
from v3_audio import sha,write

ROOT=Path(__file__).resolve().parents[2]
def duration(p):
    with wave.open(str(p)) as w:return w.getnframes()/w.getframerate()
def frame(t):return round(t*30)/30

def make(out):
    media=out/'motion/media';b=json.loads((out/'approved-script.json').read_text())
    v5=b.get('revision')=='v5';v4=b.get('revision') in ['v4','v5']
    files=b.get('narration_files',[f'narration-v3-part-{i}-dry.wav' for i in range(3)])
    crews=json.loads((out/'crew-sources.json').read_text());starts=[22,24+14/30,25+23/30,26+29/30] if v4 else [23,25.7,27.2,28.7];ends=starts[1:]+[29] if v4 else [25.7,27.2,28.7,30.7]
    if v5:starts=b['crew_scene_starts'];ends=starts[1:]+[b['crew_scene_end']]
    entrance=.2 if v4 else .3
    segments=[{'speaker':'narrator','start':0,'end':duration(media/files[0]),'file':files[0],'expected':b['narration_chunks'][0]}]
    for c,a,z in zip(crews,starts,ends):
        onset=a if v5 else a+entrance
        c.update(scene_start=a,scene_end=z,audio_start=onset,audio_end=onset+duration(media/f'voice_{c["cue"]}.wav'))
        assert c['audio_end']<=z
        segments.append({'speaker':c['role'],'start':c['audio_start'],'end':c['audio_end'],'file':f'voice_{c["cue"]}.wav','expected':c['text'],'source_sha256':c['source_sha256']})
    for i,start in ([(1,29),(2,40.2)] if v4 else [(1,31),(2,42.2)]):
        name=files[i];segments.append({'speaker':'narrator','start':start,'end':start+duration(media/name),'file':name,'expected':b['narration_chunks'][i]})
    if v5:segments=b['speech_segments']
    assert all(a['end']<=z['start'] for a,z in zip(segments,segments[1:]))
    shots=[];sections=[];animations=[];motion_samples=[]
    def pic(name,css='game',extra=''):return f'<img class="{css}" src="media/{name}" {extra}>'
    def label(text):return '<div class="source-label">'+html.escape(text)+'</div>'
    def logo(css='logo-bug'):
        if v4 and css=='cinema-logo':
            return '<div class="cinema-logo box-logo">'+pic('cover.png','box-logo-source')+'</div>'
        return pic('game-logo.png',css)
    def video(name,start,end,offset=0,css='game'):
        a,z=frame(start),frame(end)
        return f'<video id="v{len(shots)}-{name.replace(".","-")}" class="{css}" src="media/{name}" data-start="{a}" data-duration="{z-a}" data-media-start="{offset}" muted playsinline></video>'
    def add(sid,a,z,body,kind,inputs,purpose):
        a,z=frame(a),frame(z);assert z>a
        sections.append(f'<section id="{sid}" class="shot">{body}</section>')
        animations.append(f"gsap.set('#{sid}',{{autoAlpha:0}});tl.set('#{sid}',{{autoAlpha:1}},{a});tl.set('#{sid}',{{autoAlpha:0}},{z});")
        shots.append({'id':sid,'start':a,'duration':z-a,'kind':kind,'inputs':inputs,'purpose':purpose})
    def roster():
        return '<div class="avatar-roster">'+''.join(f'<div class="roster-{r}">{pic("avatar-"+r+".png","avatar")}<p>{r.upper()}</p></div>' for r in ['commander','gunner','loader','driver'])+'</div>'
    def game(sid,a,z,name,offset,title):
        add(sid,a,z,video(name,a,z,offset)+label(title)+logo(),'game_capture',[name], 'Actual mode-locked Modern Play capture, paired original simulation; complete 4:3. No source fallback or graphics changes.')
    add('four-crew',0,31/30 if v5 else 1,roster()+'<h1 class="roster-heading">FOUR CREW</h1>','artwork',[f'avatar-{c["role"]}.png' for c in crews],'Four installed upgraded crew identities.')
    reveal=31/30 if v5 else (3 if v4 else 3.1)
    if not v5:game('your-command',1,reveal,'modern-horizon.mp4',0,'ONE TANK. YOUR COMMAND.')
    add('logo-reveal',reveal,5.2,video('veo-opening.mp4',reveal,5.2,0,'cinema')+'<div class="shade"></div>'+logo('cinema-logo')+'<div class="logo-tag">FAN REMASTER</div>','illustration',['veo-opening.mp4','cover.png' if v4 else 'game-logo.png'],'Reused reference-guided Veo exterior with approved logo.')
    add('original-once',5.2,6.7,video('game-original.mp4',5.2,6.7,1)+label('DYNAMIX / ORIGINAL PC')+logo(),'game_capture',['game-original.mp4'],'The only original-game footage insert. Historic PC display, 1.5 seconds.')
    if v4:
        body=video('modern-horizon.mp4',6.7,9.3,1)+video('game-original.mp4',6.7,7.4,2.5,'game back-before')+'<div id="back-edge"></div>'+label('NOW, IT’S BACK!')+logo()
        add('now-back',6.7,9.3,body,'game_capture',['modern-horizon.mp4','game-original.mp4'],'One continuous original insert wipes directly into Modern at the return line.')
        animations += ["tl.fromTo('.back-before',{clipPath:'inset(0 0% 0 0)'},{clipPath:'inset(0 100% 0 0)',duration:.7,ease:'power2.inOut'},6.7);","tl.fromTo('#back-edge',{x:1152},{x:0,duration:.7,ease:'power2.inOut'},6.7);tl.set('#back-edge',{autoAlpha:0},7.4);tl.set('.back-before',{autoAlpha:0},7.4);"]
        motion_samples += [6.7,6.9,7.05,7.2,7.4]
    else:game('now-back',6.7,9.3,'modern-horizon.mp4',1,'NOW, IT’S BACK!')
    game('terrain',9.3,10.4,'modern-terrain.mp4',1.3,'WORK THE TERRAIN')
    game('combat',10.4,13.2 if v5 else 12.5,'modern-close-combat.mp4' if v5 else 'modern-fire.mp4',0 if v5 else 1.4,'HOLD YOUR CREW TOGETHER')
    body=pic('colonel-modern.png')+pic('colonel-genesis.png',extra='id="before"')+'<div id="compare-edge"></div><h2 class="comparison-heading">A FAMILIAR WORLD, RESTORED</h2>'+label('GENESIS → MODERN')+logo()
    add('restoration',13.2 if v5 else 12.5,19.5 if v5 else (18 if v4 else 17.9),body,'comparison',['colonel-genesis.png','colonel-modern.png'],'Matched Genesis-to-Modern BRIEF portrait; no mode-changing gameplay.')
    animations += ["tl.fromTo('#before',{clipPath:'inset(0 0% 0 0)'},{clipPath:'inset(0 100% 0 0)',duration:2.3,ease:'power2.inOut'},13.1);","tl.fromTo('#compare-edge',{x:1152},{x:0,duration:2.3,ease:'power2.inOut'},13.1);tl.set('#compare-edge',{autoAlpha:0},15.4);"]
    if v5:animations[-2:]=[x.replace('13.1','14.6').replace('15.4','16.9') for x in animations[-2:]]
    if not v4:game('hatch',17.9,19.3,'modern-terrain.mp4',2.5,'BACK THROUGH THE HATCH')
    add('avatars',19.5 if v5 else (18 if v4 else 19.3),starts[0] if v5 else (22 if v4 else 23),roster()+'<h1 class="roster-heading">EVERY STATION, BROUGHT TO LIFE</h1>'+logo(),'artwork',[f'avatar-{c["role"]}.png' for c in crews],'All four actual upgraded avatars throughout station-life narration.')
    for n,c in enumerate(crews):
        a,z=c['scene_start'],c['scene_end'];role=c['role'];sid='bark-'+role
        body=pic(f'avatar-{role}.png','solo-avatar')+f'<div class="crew-copy"><h1>{role.upper()}</h1><p>{html.escape(c["text"])}</p></div>'+logo()
        add(sid,a,z,body,'voice_showcase',[f'avatar-{role}.png',f'voice_{c["cue"]}.wav'],'Installed role-matched portrait and authentic bark. Portrait sweeps in, settles at voice onset, then sweeps out.')
        sign=-1 if n%2==0 else 1
        animations += [f"tl.fromTo('#{sid} .solo-avatar',{{x:{sign*1100},rotation:{sign*6},opacity:0}},{{x:0,rotation:0,opacity:1,duration:{entrance},ease:'power3.out'}},{a});",f"tl.fromTo('#{sid} .crew-copy',{{x:{-sign*170},opacity:0}},{{x:0,opacity:1,duration:{.18 if v4 else .25},ease:'power2.out'}},{a+.08 if v4 else a+.12});",f"tl.to('#{sid} .solo-avatar',{{x:{-sign*1100},opacity:0,duration:.12,ease:'power2.in'}},{z-.12});"]
        motion_samples += [a,a+.1,a+.2,a+.3,(a+z)/2,z-.1]
    if not v4:game('crew-return',30.7,31,'modern-fire.mp4',3.7,'ORIGINAL SIMULATION / MODERN PRESENTATION')
    for n,(index,title) in enumerate([(125,'M1A1 ABRAMS'),(163,'HIND HELICOPTER'),(161,'SAGGER TEAM'),(156,'US BASE COMPOUND')]):
        base=b['model_start'] if v5 else 29
        a=(base+11.2*n/4) if v4 else (31+10.8*n/4);z=(base+11.2*(n+1)/4) if v4 else (31+10.8*(n+1)/4)
        body=f'<h1 class="model-heading">{title}</h1>'+pic(f'unit-{index}.png','unit-pair')+'<div class="model-side original-side">ORIGINAL PC</div><div class="model-side modern-side">MODERN</div>'+video('engine-link.mp4',a,z,0,'model-link')+'<p class="model-note">Modern graphics (experimental)</p>'+logo()
        add('model-'+str(index),a,z,body,'model_comparison',[f'unit-{index}.png','engine-link.mp4'],'Original/current actual model studies, preserving requested side-by-side unit comparisons.')
    if not v4:game('modern-return',41.8,42.2,'modern-terrain.mp4',4,'ORIGINAL SIMULATION / MODERN PRESENTATION')
    cp_start,cp_cut,cp_end=(40.2,42,44.6) if v4 else (42.2,44,46.6)
    if v5:shift=b['model_start']-29;cp_start+=shift;cp_cut+=shift;cp_end+=shift
    cp=video('modern-checkpoint-away.mp4',cp_start,cp_cut,0)+video('modern-checkpoint-return.mp4',cp_cut,cp_end,0)+video('checkpoint-marker.mp4',cp_start,cp_end,0,'checkpoint-marker')+label('SAVE STATES / QUICK LOAD')+logo()
    add('checkpoint',cp_start,cp_end,cp,'game_capture',['modern-checkpoint-away.mp4','modern-checkpoint-return.mp4','checkpoint-marker.mp4'],'Real isolated checkpoint save/load, now rendered entirely in Modern.')
    animations += [f"gsap.set('#v18-modern-checkpoint-return-mp4',{{autoAlpha:0}});tl.set('#v18-modern-checkpoint-away-mp4',{{autoAlpha:0}},{cp_cut});tl.set('#v18-modern-checkpoint-return-mp4',{{autoAlpha:1}},{cp_cut});"]
    # Pin these selectors to actual generated element IDs, rather than trusting
    # an editorial count that changes when a shot is inserted.
    cp_index=next(i for i,s in enumerate(shots) if s['id']=='checkpoint')
    animations[-1]=animations[-1].replace('#v18-',f'#v{cp_index}-')
    exterior=47.8 if v4 else 48
    if v5:exterior=frame(cp_start+b['free_open_pause_cut']+1)
    fast=video('modern-terrain.mp4',cp_end,exterior,0)+label('FAST-FORWARD')+'<div class="speed-options"><span>2×</span><span>4×</span><span>8×</span></div>'+logo()
    add('fast-forward',cp_end,exterior,fast,'game_capture',['modern-terrain.mp4'],'Actual supported acceleration choices, editorial typography. Background remains normal-speed Modern gameplay; no fake interaction.')
    animations += [f"tl.fromTo('#fast-forward .speed-options span',{{y:50,opacity:0}},{{y:0,opacity:1,duration:.2,stagger:.12,ease:'power2.out'}},{cp_end});"]
    body=video('seedance-exterior.mp4',exterior,54,0,'cinema')+'<div class="shade"></div>'+logo('cinema-logo')+('<div class="logo-tag">FAN REMASTER</div>' if v5 else '<div class="logo-tag">FAN REMASTER<br><b>FREE AND OPEN</b><small>Original PC game required</small></div>')
    add('exterior',exterior,54,body,'illustration',['seedance-exterior.mp4','cover.png' if v4 else 'game-logo.png'],'Reused reference-locked moving tank illustration, no new generative footage.')
    body=pic('cover.png','cover')+'<div class="end-copy">'+('' if v4 else logo('end-logo'))+'<h2>FAN REMASTER</h2><p class="credit">Fan Remastered by Nell Watson</p><p class="free">Free and open</p><p class="requirement">Bring your own original PC game.</p><p class="url">github.com/NellInc/Abrams</p><p class="dedication">Dedicated to the memory of<br>David “Ming” Kenny.</p></div>'
    add('closing',54,60,body,'endcard',['cover.png'] if v4 else ['cover.png','game-logo.png'],'Six-second endcard with one cover logo, Nell Watson credit, game requirement, URL and memorial.')
    assert len(shots)==(20 if v5 else (21 if v4 else 24))
    assert all(abs(a['start']+a['duration']-z['start'])<1e-7 for a,z in zip(shots,shots[1:]))
    styles=re.search(r'<style>(.*?)</style>',(ROOT/'artifacts/promo-20260930-v2/motion/index.html').read_text(),re.S).group(1)
    styles+='''.end-copy{top:55px}.end-logo{height:270px}.end-copy h2{margin:10px 0 20px}.end-copy p{margin:13px 0}.end-copy .credit{font:35px Barlow;color:#c4ab76;margin:18px 0 25px}.end-copy .dedication{font-size:29px}.crew-copy h1{font-size:75px}.crew-copy p{font-size:47px}.speed-options{position:absolute;left:95px;top:210px;display:flex;gap:35px;font:60px Plex;color:#eee8d7}.speed-options span{padding:15px 28px;background:#141915e8;border:2px solid #c4ab76}.source-label{max-width:360px}'''
    styles+='.speed-options{left:100px;top:250px;flex-direction:column;gap:15px;font-size:45px}.speed-options span{padding:12px 22px}'
    if v4:
        styles+='''#back-edge{position:absolute;left:384px;top:80px;height:864px;width:3px;background:#eee8d7}.box-logo{width:430px;height:270px;overflow:hidden;border:0;box-shadow:0 5px 35px #0008}.box-logo-source{position:absolute;left:-143px;top:-32px;width:690px;height:auto;max-width:none}.end-copy{top:245px}.end-copy .credit{font-size:42px;margin:22px 0 30px}'''
    if v5:styles+='.logo-tag{left:100px;top:815px;bottom:auto;width:430px;text-align:center;font-size:26px;line-height:1.2;letter-spacing:4px}'
    doc='<!doctype html><html><head><meta charset="utf-8"><style>'+styles+'</style><script src="node_modules/gsap/dist/gsap.min.js"></script></head><body><main id="main" data-composition-id="main" data-start="0" data-duration="60" data-width="1920" data-height="1080" data-fps="30">'+''.join(sections)+'</main><script>window.__timelines=window.__timelines||{};const tl=gsap.timeline({paused:true});'+''.join(animations)+"tl.to('#closing',{opacity:0,duration:.4},59.6);window.__timelines.main=tl;</script></body></html>"
    (out/'motion/index.html').write_text(doc)
    b.update(shots=shots,crew_showcase=crews,speech_segments=segments,internal_transitions=[cp_cut,14.6 if v5 else 13.1,16.9 if v5 else 15.4,*motion_samples],revision='v5' if v5 else ('v4' if v4 else 'v3'),original_gameplay_shots=1,modern_mode_locked=True,smoke_footage=False,spoken_studio_name='Dynamics',source_evidence={'fast_forward':'README.md:38 and godot/scripts/pc_play_menu.gd:46; original-frame delivery2/4/8, audio muted at accelerated speed.'})
    write(out/'production-brief.json',b);write(out/'speech-segments.json',segments)
    rt=otio.opentime.RationalTime;tr=otio.opentime.TimeRange;t=otio.schema.Timeline(name=b['title']);p=otio.schema.Track(name='Picture',kind=otio.schema.TrackKind.Video)
    for s in shots:p.append(otio.schema.Clip(name=s['id'],media_reference=otio.schema.ExternalReference(target_url=(out/'visual-edit.mp4').as_uri()),source_range=tr(rt(round(s['start']*30),30),rt(round(s['duration']*30),30)),metadata={'kind':s['kind'],'purpose':s['purpose']}))
    t.tracks.append(p);a=otio.schema.Track(name='Final mix',kind=otio.schema.TrackKind.Audio);a.append(otio.schema.Clip(name='Fresh narration, installed crew, Suno',media_reference=otio.schema.ExternalReference(target_url=(media/'final-mix.m4a').as_uri()),source_range=tr(rt(0,30),rt(1800,30))));t.tracks.append(a);otio.adapters.write_to_file(t,str(out/'promo.otio'))
    print('V3_COMPOSITION_READY',len(shots),'shots',segments[-1]['end'],'last-source-end')

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);a=p.parse_args();make(a.output.resolve())
