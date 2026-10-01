#!/usr/bin/env python3
"""Explicit, one-shot paid media calls. Secrets stay in the requesting process."""
import argparse
import base64
import fcntl
import hashlib
import json
import mimetypes
import subprocess
import time
import wave
from pathlib import Path
from urllib.parse import urlparse

import requests

ROOT = Path(__file__).resolve().parents[2]
BASE = "https://openrouter.ai/api/v1"


def secret(service, account=None):
    cmd = ["security", "find-generic-password", "-s", service]
    if account:
        cmd += ["-a", account]
    result = subprocess.run(cmd+["-w"], capture_output=True)
    if result.returncode:
        raise RuntimeError(f"Keychain credential unavailable for {service}")
    return result.stdout.decode().strip()


def data_url(path):
    return "data:" + (mimetypes.guess_type(path)[0] or "image/png") + ";base64," + base64.b64encode(Path(path).read_bytes()).decode()


def request(method, path, **kwargs):
    # Never forward credentials to a media-download host or redirect.
    response = requests.request(method, BASE+path, headers={"Authorization":"Bearer "+secret("openrouter")}, timeout=600, allow_redirects=False, **kwargs)
    if response.status_code not in (200, 201, 202):
        raise RuntimeError(f"OpenRouter {method} {path}: HTTP {response.status_code}: {response.text[:1000]}. No automatic paid retry.")
    return response


def budget(out, action, reserve):
    with (out/'paid-ledger.lock').open('a') as lock:
        fcntl.flock(lock,fcntl.LOCK_EX)
        return reserve_budget(out,action,reserve)


def reserve_budget(out, action, reserve):
    state_path = out / 'production-state.json'
    if state_path.exists() and json.loads(state_path.read_text()).get('script_status') != 'approved':
        raise RuntimeError('Third-party generation is on hold until Nell approves the narration script')
    auth = json.loads((out / "authorization.json").read_text())
    if not auth.get("paid_generation_approved"):
        raise RuntimeError("Paid generation has not been authorized")
    ledger_path = out / "paid-ledger.json"
    ledger = json.loads(ledger_path.read_text()) if ledger_path.exists() else []
    if any(item["action"] == action for item in ledger):
        raise RuntimeError("This action already has a ledger reservation. Inspect its receipt before any deliberate retry.")
    committed=sum(item.get('actual_cost_usd',item['reserved_usd']) if item.get('state')=='completed' else item['reserved_usd'] for item in ledger)
    if committed+reserve > auth["budget_usd"]:
        raise RuntimeError("Conservative reservation exceeds the approved production budget")
    ledger.append({"action":action,"reserved_usd":reserve,"state":"submitted_or_uncertain"})
    ledger_path.write_text(json.dumps(ledger,indent=2)+"\n")


def receipt(out, action, metadata, media=None):
    if media:
        metadata["media_sha256"] = hashlib.sha256(media.read_bytes()).hexdigest()
        metadata["media_path"] = str(media)
    (out / (action+"-receipt.json")).write_text(json.dumps(metadata,indent=2)+"\n")


def download(url, target):
    if urlparse(url).scheme != "https":
        raise RuntimeError("Media download requires HTTPS")
    r=requests.get(url,timeout=180)
    r.raise_for_status()
    target.write_bytes(r.content)


def image(brief, out):
    budget(out,"keyframe",1.5)
    prompt = "Create a 16:9 cinematic promotional illustration for Abrams Battle Tank Fan Remaster, grounded in the supplied restored game cover. Preserve this same olive-drab early M1 Abrams tank, angular turret, single main gun, dark running gear and the established painterly realism. Tank in three-quarter front view, moving across a European training landscape at late afternoon, restrained dust, red-gold light breaking through cloud. Keep the tank fully inside the frame and keep room for an editorial title in the lower left. No text, no logos, no UI, no giant explosions, no extra barrels, no later-generation reactive armour. This is an illustrated promo sequence, not a gameplay screenshot. Reference image is identity and art-direction guidance."
    j=request("POST","/images",json={"model":brief['image_model'],"prompt":prompt,"aspect_ratio":"16:9","quality":"medium","n":1,"input_references":[{"type":"image_url","image_url":{"url":data_url(ROOT/'branding/abrams-cover-remastered.png')}}]}).json()
    target=out/'motion/media/tank-keyframe.png'
    target.write_bytes(base64.b64decode(j['data'][0]['b64_json']))
    receipt(out,'keyframe',{'model':brief['image_model'],'prompt':prompt,'usage':j.get('usage'),'created':j.get('created')},target)
    print('KEYFRAME_COMPLETE',target)


def speech(brief,out,action='narration'):
    budget(out,action,1 if action=='narration' else .3)
    payload={'model':brief['speech_model'],'input':brief['narration'],'voice':brief['voice'],'response_format':'pcm','provider':{'only':['google-ai-studio'],'allow_fallbacks':False,'options':{'google-ai-studio':{'speech_metadata':{'style':brief['narration_direction']}}}}}
    r=request('POST','/audio/speech',json=payload)
    raw=out/'motion/media'/(action+'-response.pcm');raw.write_bytes(r.content)
    content_type=r.headers.get('content-type','')
    if 'audio/pcm' not in content_type or 'rate=24000' not in content_type or 'channels=1' not in content_type or len(r.content)%2:
        receipt(out,action,{'request':payload,'content_type':content_type,'generation_id':r.headers.get('x-generation-id'),'status':'decode_contract_unverified'},raw)
        raise RuntimeError('Unexpected PCM contract; raw response retained. Inspect without resubmitting.')
    target=out/'motion/media'/(action+'-dry.wav')
    with wave.open(str(target),'wb') as wav:
        wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(24000);wav.writeframes(r.content)
    receipt(out,action,{'request':payload,'content_type':content_type,'generation_id':r.headers.get('x-generation-id'),'pcm_contract':'signed 16-bit little-endian mono 24000 Hz','raw_sha256':hashlib.sha256(r.content).hexdigest()},target)
    print('NARRATION_COMPLETE',target)


def video(brief,out,action):
    model=brief['atmosphere_model'] if action=='veo-opening' else brief['motion_model']
    budget(out,action,1.6 if action=='veo-opening' else 4)
    direction = ('A slow restrained dolly toward the tank, painterly red-gold clouds shifting gently, almost still commemorative opening. The tank rolls forward very slowly; atmospheric dust stays subtle.' if action=='veo-opening' else 'Smooth low side-tracking camera as the olive-drab early M1 Abrams tank moves steadily forward. Treads roll coherently, hull gently responds to the ground, a restrained dust wake trails behind. Preserve the tank proportions and single gun throughout.')
    prompt=direction+' Match the first-frame illustration and tank identity exactly. Cinematic documentary promo illustration for a retro simulation remaster, warm late-afternoon light, European terrain. No text, no UI, no added weaponry, no explosions, no cuts. This footage is an illustrative exterior sequence and must not resemble fabricated game footage.'
    payload={'model':model,'prompt':prompt,'duration':8,'aspect_ratio':'16:9','resolution':'720p','generate_audio':False,'frame_images':[{'type':'image_url','image_url':{'url':data_url(out/'motion/media/tank-keyframe.png')},'frame_type':'first_frame'}]}
    j=request('POST','/videos',json=payload).json()
    receipt(out,action,{'model':model,'prompt':prompt,'job_id':j.get('id'),'status':j.get('status'),'usage':j.get('usage')})
    if not j.get('id'):
        raise RuntimeError('Submission returned no recoverable job ID. Stop without retry.')
    deadline=time.monotonic()+1800
    while j.get('status') not in ('completed','succeeded','failed','cancelled','canceled'):
        if time.monotonic()>deadline:
            raise RuntimeError('Job remains unresolved after thirty minutes; its ID is retained for recovery.')
        time.sleep(30)
        j=request('GET','/videos/'+j['id']).json()
        receipt(out,action,{'model':model,'prompt':prompt,'job_id':j.get('id'),'status':j.get('status'),'usage':j.get('usage')})
    if j.get('status') not in ('completed','succeeded'):
        raise RuntimeError('Video generation ended with '+str(j.get('status')))
    target=out/'motion/media'/(action+'.mp4')
    response=request('GET','/videos/'+j['id']+'/content?index=0')
    if response.headers.get('content-type','').startswith('video/'):
        target.write_bytes(response.content)
    else:
        raise RuntimeError('Completed job content was not video; recover the retained ID without resubmitting.')
    receipt(out,action,{'model':model,'prompt':prompt,'job_id':j.get('id'),'status':j.get('status'),'usage':j.get('usage')},target)
    print('VIDEO_COMPLETE',action,target)


def music(brief,out):
    if brief.get('music_provider') != 'elevenlabs':
        raise RuntimeError('Suno is selected for the score. The ElevenLabs adapter is disabled; use approved Suno access after script approval.')
    # Separate ElevenLabs credential, not the OpenRouter bearer token.
    key=secret('elevenlabs','api-key')
    budget(out,'elevenlabs-music',2)
    r=requests.post('https://api.elevenlabs.io/v1/music',headers={'xi-api-key':key},json={'prompt':brief['music_direction'],'music_length_ms':60000,'model_id':'music_v2_5','force_instrumental':True},timeout=600,allow_redirects=False)
    if r.status_code!=200:
        raise RuntimeError(f'ElevenLabs music HTTP {r.status_code}. No automatic paid retry.')
    target=out/'motion/media/music-elevenlabs.mp3';target.write_bytes(r.content)
    receipt(out,'elevenlabs-music',{'provider':'ElevenLabs','model':'music_v2_5','direction':brief['music_direction'],'song_id':r.headers.get('song-id')},target)
    print('MUSIC_COMPLETE',target)


def main():
    p=argparse.ArgumentParser();p.add_argument('action',choices=['keyframe','narration','narration-name-fix','narration-pronunciation-v2','narration-pronunciation-v2-phonetic','veo-opening','seedance-exterior','music']);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    out=args.output.resolve();brief=json.loads((ROOT/'tools/promo/brief.json').read_text())
    if args.action=='keyframe':image(brief,out)
    elif args.action=='narration':speech(brief,out)
    elif args.action=='narration-name-fix':
        brief['narration']='Abrams Battle Tank by Dynamix was a revolution in its time.'
        brief['narration_direction']='Same firm, clear, energetic Orus military-command promo delivery, mid-low warm register, steady brisk rhythm, approximately 180 words per minute. Important pronunciation: Dynamix is DYE-nuh-micks, ending with the short i vowel in mix and kicks. Never pronounce it Dynamax or macks. Read only the supplied sentence, no acting directions. This is an assured enthusiastic historical reference to the PC game.'
        speech(brief,out,args.action)
    elif args.action in ['narration-pronunciation-v2','narration-pronunciation-v2-phonetic']:
        brief['narration']='Abrams Battle Tank by Dynamix was a revolution in its time.' if args.action=='narration-pronunciation-v2' else 'Abrams Battle Tank by Dye-Nahh-Mix was a revolution in its time.'
        brief['narration_direction']='Same firm, clear, energetic Orus military-command promo delivery, mid-low warm register, steady brisk rhythm, approximately 180 words per minute. Nell specifies this pronunciation of the studio name: DYE-NAHH-MIX. First syllable DYE rhymes with eye. Middle syllable NAHH has the broad ah vowel of father, deliberately audible, not the weak uh sound. Final MIX has the short i vowel of mix and kicks, never max. Say the three syllables naturally as one name, DYE-NAHH-MIX. Read only the supplied sentence, no directions or phonetic spelling aloud.'
        speech(brief,out,args.action)
    elif args.action=='music':music(brief,out)
    else:video(brief,out,args.action)


if __name__=='__main__':main()
