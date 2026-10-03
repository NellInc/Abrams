#!/usr/bin/env python3
"""Build the local animatic, HTML composition and editable OTIO shot timeline."""
import argparse
import hashlib
import html
import json
import shutil
import subprocess
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
BRIEF = ROOT / "tools/promo/brief.json"
INK = "#141915"
IVORY = "#eee8d7"
GOLD = "#c4ab76"


def run(*args):
    subprocess.run([str(x) for x in args], check=True)


def font(size):
    return ImageFont.truetype(str(ROOT / "godot/assets/fonts/BarlowCondensed-SemiBold.ttf"), size)


def wrapped(draw, text, pos, size, width, fill=IVORY):
    f = font(size)
    words, lines, line = text.split(), [], ""
    for word in words:
        candidate = (line + " " + word).strip()
        if draw.textlength(candidate, font=f) > width and line:
            lines.append(line)
            line = word
        else:
            line = candidate
    lines.append(line)
    for n, line in enumerate(lines):
        draw.text((pos[0], pos[1] + n * size * 1.15), line, font=f, fill=fill)


def card(shot, destination):
    im = Image.new("RGB", (1920, 1080), INK)
    d = ImageDraw.Draw(im)
    d.line([(100, 85), (1820, 85)], fill=GOLD, width=2)
    d.text((100, 40), "ABRAMS BATTLE TANK  /  FAN REMASTER", font=font(26), fill=GOLD)
    d.text((100, 1005), "ANIMATIC  /  Source screens and illustrative placeholders", font=font(24), fill=GOLD)
    source = Image.open(ROOT / shot["image"]).convert("RGB")
    if shot["kind"] in ("endcard", "illustration"):
        source = ImageOps.contain(source, (510, 795))
        im.paste(source, (180 + (510-source.width)//2, 140+(795-source.height)//2))
        wrapped(d, shot["heading"], (820, 240), 105, 940)
        wrapped(d, shot["subheading"], (820, 500), 46, 940, GOLD)
        if shot["kind"] == "endcard":
            d.text((820, 630), "github.com/NellInc/Abrams", font=font(40), fill=IVORY)
            wrapped(d, "Free fan remaster. Original PC game required.", (820, 715), 32, 900)
            wrapped(d, 'Dedicated to the memory of David “Ming” Kenny.', (820, 815), 32, 900, GOLD)
    else:
        source = ImageOps.contain(source, (1120, 840))
        im.paste(source, (700+(1120-source.width)//2, 125+(840-source.height)//2))
        wrapped(d, shot["heading"], (100, 300), 76, 515)
        wrapped(d, shot["subheading"], (100, 570), 35, 500, GOLD)
        if "/scenario-frames" in shot["image"]:
            d.text((100, 850), "Modern graphics: experimental", font=font(28), fill=GOLD)
    im.save(destination)


def prepare(brief, out):
    media = out / "motion/media"
    media.mkdir(parents=True, exist_ok=True)
    receipts = []
    for shot in brief["shots"]:
        for field in ("image", "before_image", "second_image"):
            if field not in shot:
                continue
            source = ROOT / shot[field]
            target = media / (shot["id"] + "-" + field + source.suffix)
            shutil.copyfile(source, target)
            shot[field+"_local"] = "media/" + target.name
            receipts.append({"shot": shot["id"], "role": field, "source": str(source),
                             "sha256": hashlib.sha256(source.read_bytes()).hexdigest()})
    shutil.copyfile(ROOT / "godot/assets/fonts/BarlowCondensed-SemiBold.ttf", media / "Barlow.ttf")
    shutil.copyfile(ROOT / "godot/assets/fonts/IBMPlexMono-Regular.ttf", media / "Plex.ttf")
    (out / "source-receipts.json").write_text(json.dumps(receipts, indent=2)+"\n")
    return brief


def make_html(brief, out, final):
    if final:
        return make_production_html(brief,out)
    elements, animations = [], []
    for shot in brief["shots"]:
        sid, start, duration = shot["id"], shot["start"], shot["duration"]
        heading, subtitle = html.escape(shot["heading"]), html.escape(shot["subheading"])
        source = shot["image_local"]
        # Final mode returned above; this is the animatic composition only.
        if shot["kind"] in ("illustration", "endcard"):
            extra = ''
            if sid == "closing":
                extra = '<div class="closing-details"><p class="url">github.com/NellInc/Abrams</p><p>Free fan remaster. Original PC game required.</p><p class="dedication">Dedicated to the memory of<br>David “Ming” Kenny.</p></div>'
                if (out / 'motion/media/closing-underline.mp4').exists():
                    extra = '<video class="mc-underline" src="media/closing-underline.mp4" data-start="52" data-duration="8" muted playsinline></video>'+extra
            body = f'<img class="cover" src="{source}"><div class="cover-copy"><h1>{heading}</h1><p>{subtitle}</p>{extra}</div>'
        else:
            content = f'<img class="screen" src="{source}">'
            if "before_image_local" in shot:
                content += f'<img id="before" class="screen" src="{shot["before_image_local"]}">'
                if (out / 'motion/media/comparison-divider.webm').exists():
                    content += f'<video class="manim-divider" src="media/comparison-divider.webm" data-start="{start}" data-duration="{duration}" muted playsinline></video>'
                else:
                    content += '<div id="divider"></div>'
                    animations += [f"tl.fromTo('#divider',{{x:1120}},{{x:0,duration:3.6,ease:'power2.inOut'}},{start+2});"]
                animations += [f"tl.fromTo('#before',{{clipPath:'inset(0 0% 0 0)'}},{{clipPath:'inset(0 100% 0 0)',duration:3.6,ease:'power2.inOut'}},{start+2});"]
            if "second_image_local" in shot:
                content += f'<img id="station-two" class="screen" src="{shot["second_image_local"]}">'
                animations += [f"tl.set('#station-two',{{autoAlpha:0}},0);tl.to('#station-two',{{autoAlpha:1,duration:.6}},{start+4.8});"]
            note = '<p class="experimental">Modern graphics: experimental</p>' if "/scenario-frames" in shot["image"] else ''
            body = f'<div class="left-copy"><h2>{heading}</h2><p>{subtitle}</p>{note}</div><div class="screen-frame">{content}</div>'
        label = '<div class="animatic-label">ANIMATIC / Illustrative placeholders</div>'
        elements.append(f'<section id="{sid}" class="shot">{body}{label}</section>')
        animations += [f"gsap.set('#{sid}',{{autoAlpha:0}});tl.set('#{sid}',{{autoAlpha:1}},{start});",
                       f"tl.fromTo('#{sid} h1,#{sid} h2',{{y:22,opacity:0}},{{y:0,opacity:1,duration:.8,ease:'power2.out'}},{start+.15});"]
        if sid != "closing":
            animations += [f"tl.set('#{sid}',{{autoAlpha:0}},{start+duration});"]
    document = '''<!doctype html><html><head><meta charset="utf-8"><title>Abrams promo</title>
<style>
@font-face{font-family:Barlow;src:url('media/Barlow.ttf')}@font-face{font-family:Plex;src:url('media/Plex.ttf')}
*{box-sizing:border-box}body{margin:0;background:#141915;color:#eee8d7;font-family:Barlow}#main{position:relative;width:1920px;height:1080px;overflow:hidden;background:#141915}
.shot{position:absolute;inset:0;visibility:hidden;overflow:hidden}.masthead{position:absolute;left:100px;top:40px;font-size:25px;color:#c4ab76;z-index:10;letter-spacing:3px}.rule{position:absolute;left:100px;right:100px;top:85px;height:2px;background:#c4ab76;opacity:.45;z-index:10}
.left-copy{position:absolute;left:100px;top:265px;width:510px}.left-copy h2{font-size:78px;line-height:1.06;font-weight:600;margin:0 0 40px}.left-copy p{font-size:34px;line-height:1.4;color:#c4ab76}.experimental{margin-top:55px;font-size:27px!important;color:#c4ab76!important}
.screen-frame{position:absolute;left:700px;top:125px;width:1120px;height:840px;overflow:hidden;background:#080d09;border:1px solid #59614f}.screen,.manim-divider{position:absolute;inset:0;width:100%;height:100%;object-fit:contain}#divider{position:absolute;top:0;bottom:0;width:3px;background:#eee8d7}.mc-underline{width:900px;height:80px;display:block;margin-top:-30px;margin-bottom:-30px}
.cover{position:absolute;left:205px;top:145px;width:465px;height:790px;object-fit:contain}.cover-copy{position:absolute;left:820px;top:235px;width:965px}.cover-copy h1{font-size:109px;line-height:.98;margin:0 0 28px;font-weight:600;letter-spacing:2px}.cover-copy>p{font-size:43px;color:#c4ab76;letter-spacing:3px}.closing-details{margin-top:44px}.closing-details p{font-size:31px;line-height:1.35;margin:26px 0}.closing-details .url{font-size:40px}.dedication{color:#c4ab76}
.cinema{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}.shade{position:absolute;inset:0;background:linear-gradient(0deg,rgba(12,17,12,.94),transparent 60%)}.hero-copy{position:absolute;left:100px;bottom:165px}.hero-copy h1{font-size:115px;letter-spacing:7px;margin:0;line-height:.98}.hero-copy p{font-size:38px;letter-spacing:5px;color:#e9d4a3}
.animatic-label{position:absolute;left:100px;bottom:36px;font:20px Plex;color:#c4ab76}
</style><script src="node_modules/gsap/dist/gsap.min.js"></script></head><body>
<main id="main" data-composition-id="main" data-start="0" data-duration="60" data-width="1920" data-height="1080">'''+''.join(elements)+'''<div class="masthead">ABRAMS BATTLE TANK / FAN REMASTER</div><div class="rule"></div></main><script>
window.__timelines=window.__timelines||{};const tl=gsap.timeline({paused:true});
'''+"\n".join(animations)+'''
tl.to('#main',{opacity:0,duration:.7},59.3);window.__timelines.main=tl;
</script></body></html>'''
    destination = out / "motion" / "index.html"
    destination.write_text(document)
    return destination


def make_production_html(brief,out):
    """Narration-conformed HTML edit, captured screens retain their full 4:3 frame."""
    media=out/'motion/media'
    sources={
        'cover':'branding/abrams-cover-remastered.png',
        'colonel-ega':'docs/images/colonel-ega.png',
        'colonel-genesis':'docs/images/colonel-genesis.png',
        'colonel-upscaled':'docs/images/colonel-upscaled.png',
        'gunner-upscaled':'docs/images/gunner-upscaled.png',
    }
    for name,path in sources.items(): shutil.copyfile(ROOT/path,media/(name+'.png'))
    for name in ['cannon','smoke','voice_loaded']:
        shutil.copyfile(ROOT/f'godot/assets/audio/{name}.wav',media/(name+'.wav'))
    scenes=[];animations=[];receipts=[]
    def vid(name,start,end,media_start=0,css='game',extra=''):
        assert (media/name).exists(),name
        stable_id='' if 'id=' in extra else f'id="{Path(name).stem}-{round(start*10)}"'
        return f'<video {stable_id} class="{css}" src="media/{name}" data-start="{start}" data-duration="{round(end-start,4)}" data-media-start="{media_start}" muted playsinline {extra}></video>'
    def img(name,css='game',extra=''):
        return f'<img class="{css}" src="media/{name}.png" {extra}>'
    def label(text,side=''):
        return f'<div class="source-label {side}">{html.escape(text)}</div>'
    def scene(sid,start,end,body,kind,inputs,purpose):
        scenes.append(f'<section id="{sid}" class="shot">{body}</section>')
        animations.append(f"gsap.set('#{sid}',{{autoAlpha:0}});tl.set('#{sid}',{{autoAlpha:1}},{start});tl.set('#{sid}',{{autoAlpha:0}},{end});")
        receipts.append({'id':sid,'start':start,'duration':end-start,'heading':sid,'subheading':'','image':'branding/abrams-cover-remastered.png','kind':kind,'purpose':purpose,'inputs':inputs})
    scene('crew',0,1.4,img('colonel-upscaled')+'<h1 class="opening-word">FOUR CREW</h1>','game_capture',['colonel-upscaled.png'],'Authentic restored briefing portrait on the opening command.')
    scene('tank',1.4,2.6,img('gunner-upscaled')+'<h1 class="opening-word">ONE TANK</h1>','game_capture',['gunner-upscaled.png'],'Full authentic gunner station.')
    scene('command',2.6,3.8,vid('game-stations.mp4',2.6,3.8,4.1)+'<h1 class="opening-word">YOUR COMMAND</h1>','game_capture',['game-stations.mp4'],'Recorded driver station, actual original SIM packet rendering.')
    scene('reveal',3.8,6.8,vid('veo-opening.mp4',3.8,6.8,0,'cinema')+'<div class="shade"></div><div class="hero"><h1>ABRAMS</h1><p>BATTLE TANK</p><span>FAN REMASTER</span></div>','illustration',['veo-opening.mp4'],'Cover-guided illustrative tank reveal, Veo 3.1.')
    scene('heritage',6.8,8.2,vid('game-original.mp4',6.8,8.2,1)+label('DYNAMIX / ORIGINAL PC'),'game_capture',['game-original.mp4'],'Real source packets shown using the EGA presentation.')
    scene('scan',8.2,9.8,vid('game-horizon.mp4',8.2,9.8,1.4)+label('SCAN THE HORIZON'),'game_capture',['game-horizon.mp4'],'Original turret movement captured and rendered through production viewer.')
    scene('terrain',9.8,10.7,vid('game-terrain.mp4',9.8,10.7,3.2)+label('WORK THE TERRAIN'),'game_capture',['game-terrain.mp4'],'Real driving through original terrain, verified position change.')
    scene('smoke',10.7,14.4,vid('game-smoke-fire.mp4',10.7,14.4,.6)+label('ABRAMS BATTLE TANK / FAN REMASTER'),'game_capture',['game-smoke-fire.mp4'],'Original smoke at source frame 32 and cannon event at frame 114.')
    comparison=img('colonel-upscaled')+img('colonel-ega',extra='id="before"')+'<div id="compare-edge"></div><h2 class="comparison-heading">A FAMILIAR WORLD, RESTORED</h2>'+label('ORIGINAL PC EGA → UPSCALED ARTWORK')
    scene('restoration',14.4,22.2,comparison,'comparison',['colonel-ega.png','colonel-upscaled.png'],'Matched briefing frames, restoration reveal without fabricated menu content.')
    animations.extend(["tl.fromTo('#before',{clipPath:'inset(0 0% 0 0)'},{clipPath:'inset(0 100% 0 0)',duration:3.6,ease:'power2.inOut'},16.4);","tl.fromTo('#compare-edge',{x:1152},{x:0,duration:3.6,ease:'power2.inOut'},16.4);tl.set('#compare-edge',{autoAlpha:0},20.05);"])
    panels=''.join(f'<div class="style-panel style-{i}">{img("colonel-"+mode,"style-screen")}<p>{name}</p></div>' for i,(mode,name) in enumerate([('ega','EGA'),('genesis','GENESIS'),('upscaled','UPSCALED')]))
    scene('styles',22.2,25.6,'<h2 class="style-heading">A CHOICE OF VISUAL STYLES</h2>'+panels,'comparison',['colonel-ega.png','colonel-genesis.png','colonel-upscaled.png'],'Complete matched 4:3 displays in all three established graphics modes.')
    scene('stations',25.6,31.0,vid('game-stations.mp4',25.6,31.0,0)+label('BACK THROUGH THE HATCH'),'game_capture',['game-stations.mp4'],'Recorded commander, cupola, driver and gunner views.')
    def paired(start,end,original,remaster,offset=0,link=False):
        body='<h2 class="tandem-heading">THE ORIGINAL CALLS THE SHOTS</h2>'
        body+=vid(original,start,end,offset,'paired original')+vid(remaster,start,end,offset,'paired remaster')
        body+='<div class="pair-label original-label">ORIGINAL PC SIMULATION</div><div class="pair-label remaster-label">REMASTERED PRESENTATION</div>'
        if link: body+=vid('engine-link.mp4',start,end,0,'engine-link')
        return body
    scene('loader',31.0,32.6,vid('game-clear-fire.mp4',31.0,32.6,5.0667)+label('EXPRESSIVE CREW / ORIGINAL RELOAD EVENT'),'game_capture',['game-clear-fire.mp4','voice_loaded.wav'],'Source-matched original reload event and authentic crew readiness call.')
    scene('original-sim',32.6,38.6,paired(32.6,38.6,'game-original-clear-fire.mp4','game-clear-fire.mp4',.4),'game_capture',['game-original-clear-fire.mp4','game-clear-fire.mp4'],'Same original SIM packets in paired EGA and remastered presentation.')
    scene('engine-link',38.6,43.2,paired(38.6,43.2,'game-original.mp4','game-horizon.mp4',.2,True),'diagram',['game-original.mp4','game-horizon.mp4','engine-link.mp4'],'Manim arrow connects source simulation and Godot presentation over a matched recording.')
    scene('combat-return',43.2,45.5,vid('game-clear-fire.mp4',43.2,45.5,4.5)+label('ORIGINAL SIMULATION / NEW SOUND AND CREW'),'game_capture',['game-clear-fire.mp4'],'Captured original firing and reload presentation following the engine explanation.')
    cp=vid('game-checkpoint-away.mp4',45.5,46.8,.8,extra='id="cp-away"')+vid('game-checkpoint-return.mp4',46.8,49.4,0,extra='id="cp-return"')+vid('checkpoint-marker.mp4',45.5,49.4,0,'checkpoint-marker')+label('SAVE STATES / QUICK LOAD')
    scene('checkpoint',45.5,49.4,cp,'game_capture',['game-checkpoint-away.mp4','game-checkpoint-return.mp4','checkpoint-marker.mp4'],'Real isolated slot 1 restore; held frame matches the saved frame audit; restored RAM sha256 verified by the original host. Motion Canvas marker is an editorial annotation.')
    animations.extend(["gsap.set('#cp-return',{autoAlpha:0});tl.set('#cp-away',{autoAlpha:0},46.8);tl.set('#cp-return',{autoAlpha:1},46.8);"])
    cta=vid('seedance-exterior.mp4',49.4,55.8,0,'cinema')+'<div class="shade"></div><div class="hero cta"><h1>ABRAMS BATTLE TANK</h1><p>FAN REMASTER</p><span>FREE AND OPEN</span><small>Original PC game required</small></div>'
    scene('exterior',49.4,55.8,cta,'illustration',['seedance-exterior.mp4'],'Reference-guided illustrated moving tank, Seedance 2.5, followed by the required original-game condition.')
    endcard=img('cover','cover')+'<div class="end-copy"><h1>ABRAMS<br>BATTLE TANK</h1><h2>FAN REMASTER</h2><p class="free">Free and open</p><p class="requirement">Bring your own original PC game.</p><p class="url">github.com/NellInc/Abrams</p><p class="dedication">Dedicated to the memory of<br>David “Ming” Kenny.</p></div>'
    scene('closing',55.8,60,endcard,'endcard',['cover.png'],'Project URL, original-game requirement and David Ming Kenny dedication, readable final hold.')
    brief['shots']=receipts
    for s in receipts:
        for name in s['inputs']:
            path=media/name
            assert path.exists(),path
    document='''<!doctype html><html><head><meta charset="utf-8"><title>Abrams Battle Tank Promo</title>
<style>
@font-face{font-family:Barlow;src:url('media/Barlow.ttf')}@font-face{font-family:Plex;src:url('media/Plex.ttf')}
*{box-sizing:border-box}body{margin:0;background:#141915;color:#eee8d7;font-family:Barlow}#main{position:relative;width:1920px;height:1080px;overflow:hidden;background:#141915}.shot{position:absolute;inset:0;visibility:hidden;overflow:hidden}
.game{position:absolute;left:384px;top:80px;width:1152px;height:864px;object-fit:contain;background:#080d09}.source-label{position:absolute;left:384px;top:35px;font:22px Plex;color:#c4ab76;letter-spacing:1px}.opening-word{position:absolute;left:0;right:0;top:325px;text-align:center;font-size:140px;letter-spacing:5px;text-shadow:0 3px 30px #000;margin:0;background:linear-gradient(90deg,transparent,rgba(0,0,0,.73),transparent);padding:30px 0}
.cinema{position:absolute;inset:0;width:100%;height:100%;object-fit:cover}.shade{position:absolute;inset:0;background:linear-gradient(0deg,rgba(8,12,8,.95),transparent 69%)}.hero{position:absolute;left:100px;bottom:190px}.hero h1{font-size:142px;line-height:.95;letter-spacing:5px;margin:0 0 12px}.hero p{font-size:66px;letter-spacing:6px;margin:0 0 20px}.hero span{font:28px Plex;color:#dfc796;letter-spacing:4px}.hero small{display:block;font-size:30px;margin-top:16px;color:#eee8d7}.cta h1{font-size:92px}.cta p{font-size:42px}.cta{bottom:180px}
#compare-edge{position:absolute;left:384px;top:80px;height:864px;width:3px;background:#eee8d7}.comparison-heading{position:absolute;left:100px;right:100px;top:5px;text-align:center;font-size:42px;letter-spacing:2px;margin:0;padding:10px 0;background:#141915;z-index:3}#restoration .source-label{top:953px;font-size:20px}.style-heading{position:absolute;top:210px;left:100px;font-size:60px;margin:0;letter-spacing:2px}.style-panel{position:absolute;top:345px;width:520px;height:470px}.style-0{left:100px}.style-1{left:700px}.style-2{left:1300px}.style-screen{width:520px;height:390px;object-fit:contain}.style-panel p{font:27px Plex;text-align:center;color:#c4ab76;letter-spacing:3px;margin-top:28px}
.tandem-heading{position:absolute;left:100px;right:100px;top:82px;text-align:center;font-size:62px;letter-spacing:2px;margin:0}.paired{position:absolute;top:205px;width:780px;height:585px;object-fit:contain}.original{left:100px}.remaster{left:1040px}.pair-label{position:absolute;top:823px;width:780px;text-align:center;font:23px Plex;color:#c4ab76;letter-spacing:1px}.original-label{left:100px}.remaster-label{left:1040px}.engine-link{position:absolute;left:100px;top:858px;width:1720px;height:130px;object-fit:contain}.checkpoint-marker{position:absolute;left:40px;top:875px;width:320px;height:56px;object-fit:contain}
.cover{position:absolute;left:185px;top:105px;width:520px;height:790px;object-fit:contain}.end-copy{position:absolute;left:850px;top:130px;width:950px}.end-copy h1{font-size:112px;line-height:.96;letter-spacing:2px;margin:0 0 20px}.end-copy h2{font:32px Plex;color:#c4ab76;letter-spacing:5px;margin:0 0 45px}.end-copy p{margin:20px 0;line-height:1.25}.free{font-size:48px}.requirement{font-size:35px}.url{font:29px Plex;color:#eee8d7}.dedication{font-size:31px;color:#c4ab76;padding-top:28px}
</style><script src="node_modules/gsap/dist/gsap.min.js"></script></head><body><main id="main" data-composition-id="main" data-start="0" data-duration="60" data-width="1920" data-height="1080" data-fps="30">'''+''.join(scenes)+'''</main><script>window.__timelines=window.__timelines||{};const tl=gsap.timeline({paused:true});'''+''.join(animations)+'''tl.to('#closing',{opacity:0,duration:.4},59.6);window.__timelines.main=tl;</script></body></html>'''
    destination=out/'motion/index.html';destination.write_text(document)
    (out/'editorial-inputs.json').write_text(json.dumps(receipts,indent=2)+'\n')
    return destination


def timeline(brief, out, final):
    import opentimelineio as otio
    rt = otio.opentime.RationalTime
    tr = otio.opentime.TimeRange
    tl = otio.schema.Timeline(name=brief["title"])
    track = otio.schema.Track(name="Picture", kind=otio.schema.TrackKind.Video)
    for shot in brief["shots"]:
        source=out/'visual-edit.mp4' if final else out/'animatic-frames'/(shot['id']+'.png')
        if not final and not source.exists():source=ROOT/shot['image']
        duration=rt(round(shot['duration']*brief['fps']),brief['fps'])
        available=rt(1800,brief['fps']) if final else duration
        offset=round(shot['start']*brief['fps']) if final else 0
        clip=otio.schema.Clip(name=shot['id'],media_reference=otio.schema.ExternalReference(
            target_url=source.resolve().as_uri(),available_range=tr(rt(0,brief['fps']),available)),
            source_range=tr(rt(offset,brief['fps']),duration),metadata={'kind':shot['kind'],'purpose':shot['purpose'],'raw_inputs':shot.get('inputs',[])})
        track.append(clip)
    tl.tracks.append(track)
    mix = out / "motion/media/final-mix.wav"
    if final and mix.exists():
        audio = otio.schema.Track(name="Narration and music", kind=otio.schema.TrackKind.Audio)
        audio.append(otio.schema.Clip(name="Final mix", media_reference=otio.schema.ExternalReference(target_url=mix.resolve().as_uri()),source_range=tr(rt(0,30),rt(1800,30))))
        tl.tracks.append(audio)
    destination = out / ("promo.otio" if final else "animatic.otio")
    otio.adapters.write_to_file(tl,str(destination))
    assert tl.duration().to_seconds() == 60


def main():
    p=argparse.ArgumentParser();p.add_argument('--output',type=Path,required=True);p.add_argument('--final',action='store_true');p.add_argument('--animatic',action='store_true');args=p.parse_args()
    out=args.output.resolve();out.mkdir(parents=True,exist_ok=True)
    brief=prepare(json.loads(BRIEF.read_text()),out)
    frames=out/'animatic-frames';frames.mkdir(exist_ok=True)
    for shot in brief['shots']:card(shot,frames/(shot['id']+'.png'))
    # --final swaps brief['shots'] for production receipts; the animatic keeps its cards.
    animatic_shots=list(brief['shots'])
    destination=make_html(brief,out,args.final)
    timeline(brief,out,args.final)
    (out/'production-brief.json').write_text(json.dumps(brief,indent=2)+'\n')
    if args.animatic:
        lines=[]
        for shot in animatic_shots:lines += [f"file '{frames / (shot['id']+'.png')}'",f"duration {shot['duration']}"]
        lines.append(f"file '{frames / (animatic_shots[-1]['id']+'.png')}'")
        (out/'animatic-concat.txt').write_text('\n'.join(lines)+'\n')
        run('ffmpeg','-hide_banner','-loglevel','error','-y','-f','concat','-safe','0','-i',out/'animatic-concat.txt','-t','60','-vf','scale=1280:720,fps=12','-c:v','libx264','-preset','fast','-crf','22','-pix_fmt','yuv420p','-movflags','+faststart',out/'abrams-animatic.mp4')
    print(json.dumps({'composition':str(destination),'timeline_seconds':60,'mode':'final' if args.final else 'animatic'}))


if __name__=='__main__':main()
