#!/usr/bin/env python3
"""Produce a local Godot Web Play export plus authored-asset pack."""
from pathlib import Path
import shutil
import subprocess
import re
import tempfile
import fnmatch
import json
from build_remaster_assets import (GODOT_FILES, generated_lock, output_identity,
                                   install_outputs, stage_assets, fingerprint)

ROOT = Path(__file__).resolve().parents[1]
GODOT = ROOT / '.runtime/Godot.app/Contents/MacOS/Godot'
WEB = ROOT / 'web-prototype/.generated/godot'
PRESENTATION_DIRS = ('scripts', 'assets', 'data', 'scenes')
IGNORED_INPUTS = ('.DS_Store', '__pycache__', '*.pyc')


def patch_audio_shutdown(text: str) -> str:
    """Keep Godot 4.7.2 audio alive until pending worklets finish teardown.

    Normal mixing/startup and licence notices remain byte-exact. The pinned
    export must match both reviewed functions; template drift fails closed.
    Working if: pending/rejected/absent worklet cleanup settles, the context
    closes last, and the real browser emits its normal exit callback.
    """
    replacements = [('close_async:function(resolve,reject){const ctx=GodotAudio.ctx;GodotAudio.ctx=null;if(!ctx){resolve();return}if(GodotAudio.interval){clearInterval(GodotAudio.interval);GodotAudio.interval=0}if(GodotAudio.input){GodotAudio.input.disconnect();GodotAudio.input=null}let closed=Promise.resolve();if(GodotAudio.driver){closed=GodotAudio.driver.close()}closed.then(function(){return ctx.close()}).then(function(){ctx.onstatechange=null;resolve()}).catch(function(e){ctx.onstatechange=null;GodotRuntime.error("Error closing AudioContext",e);resolve()})}', 'close_async:function(resolve,reject){const ctx=GodotAudio.ctx;if(!ctx){resolve();return}if(GodotAudio.interval){clearInterval(GodotAudio.interval);GodotAudio.interval=0}if(GodotAudio.input){GodotAudio.input.disconnect();GodotAudio.input=null}function finish(){ctx.onstatechange=null;if(GodotAudio.ctx===ctx){GodotAudio.ctx=null}resolve()}const closed=Promise.resolve().then(function(){if(GodotAudio.driver){return GodotAudio.driver.close()}});closed.catch(function(e){GodotRuntime.error("Error closing audio driver",e)}).then(function(){return ctx.close()}).then(finish).catch(function(e){GodotRuntime.error("Error closing AudioContext",e);finish()})}'), ('close:function(){return new Promise(function(resolve,reject){if(GodotAudioWorklet.promise===null){return}const p=GodotAudioWorklet.promise;p.then(function(){GodotAudioWorklet.worklet.port.postMessage({cmd:"stop",data:null});GodotAudioWorklet.worklet.disconnect();GodotAudioWorklet.worklet.port.onmessage=null;GodotAudioWorklet.worklet=null;GodotAudioWorklet.promise=null;resolve()}).catch(function(err){GodotRuntime.error(err)})})}', 'close:function(){return new Promise(function(resolve,reject){const p=GodotAudioWorklet.promise;function finish(){const node=GodotAudioWorklet.worklet;if(node){node.port.onmessage=null;try{node.port.postMessage({cmd:"stop",data:null})}catch(e){GodotRuntime.error(e)}try{node.disconnect()}catch(e){GodotRuntime.error(e)}}GodotAudioWorklet.worklet=null;GodotAudioWorklet.promise=null;GodotAudioWorklet.ring_buffer=null;resolve()}if(p===null){finish();return}p.then(finish,function(err){GodotRuntime.error(err);finish()})})}')]
    for original, replacement in replacements:
        if text.count(original) != 1:
            raise ValueError('Godot audio loader changed; review the shutdown patch')
        text = text.replace(original, replacement)
    return text


def presentation_snapshot(source):
    """Selected root identities at a checkpoint, not an atomic editor lock."""
    if source.is_symlink() or not source.is_dir():
        raise SystemExit('Missing or linked presentation source directory')
    paths = [source / 'project.godot', source / 'export_presets.cfg']
    for name in PRESENTATION_DIRS:
        directory = source / name
        if directory.is_symlink() or not directory.is_dir():
            raise SystemExit(f'Missing or linked presentation directory: {name}')
        for path in sorted(directory.rglob('*')):
            relative = path.relative_to(source)
            if any(fnmatch.fnmatchcase(part, pattern) for part in relative.parts for pattern in IGNORED_INPUTS):
                continue
            if path.is_symlink(): raise SystemExit(f'Linked presentation input: {relative}')
            if path.is_file(): paths.append(path)
    return {path.relative_to(source).as_posix(): list(fingerprint(path)) for path in paths}


def verify_presentation(source, expected):
    if presentation_snapshot(source) != expected:
        raise SystemExit('Presentation source changed during building; previous build retained')


def stage_export(stage, web):
    web.mkdir(parents=True)
    stage.mkdir()
    # Export from a clean presentation project. The desktop checkout contains
    # original-PC diagnostic snapshots under godot/artifacts; those must never
    # be copied into a browser pack, even as incidental all_resources inputs.
    source = ROOT / 'godot'
    snapshot = presentation_snapshot(source)
    # Verify the raw copied namespace before applying Web-only transforms.
    for name in ('project.godot', 'export_presets.cfg'):
        shutil.copy2(source / name, stage / name)
    for name in PRESENTATION_DIRS:
        shutil.copytree(source / name, stage / name,
                        ignore=shutil.ignore_patterns(*IGNORED_INPUTS))
    copied = presentation_snapshot(stage)
    if set(copied) != set(snapshot) or any(copied[name][-1] != snapshot[name][-1] for name in snapshot):
        raise SystemExit('Staged presentation differs from its source snapshot')
    verify_presentation(source, snapshot)
    (stage.parent / 'export-sources.json').write_text(json.dumps({'schema': 1, 'files': snapshot}, indent=2) + '\n')
    project = (stage / 'project.godot').read_text()
    main_scene = 'run/main_scene="res://scenes/main.tscn"'
    if project.count(main_scene) != 1:
        raise SystemExit('Desktop development main scene changed; review the Web entry point')
    # Exported Web templates start the project MainLoop, not an editor-style
    # `-s` script. Register Play as that loop in staging so the unrelated
    # development range can never become the browser game.
    (stage / 'project.godot').write_text(project.replace(
        main_scene, 'run/main_scene="res://scenes/web_entry.tscn"\n'
                    'run/main_loop_type="AbramsWebPlayLoop"'))
    viewer = stage / 'scripts/pc_bridge_viewer.gd'
    viewer.write_text('class_name AbramsWebPlayLoop\n' + viewer.read_text())
    # The Web template insists on a main-scene resource even with a custom
    # MainLoop. This inert scene is never the development range.
    (stage / 'scenes/web_entry.tscn').write_text(
        '[gd_scene format=3]\n\n[node name="WebEntry" type="Node"]\n')
    preset = (stage / 'export_presets.cfg').read_text()
    preset = preset.replace('../.runtime/godot-web-templates/',
                            str(ROOT / '.runtime/godot-web-templates') + '/')
    (stage / 'export_presets.cfg').write_text(preset)
    result = subprocess.run([str(GODOT), '--headless', '--audio-driver', 'Dummy', '--path', str(stage),
                             '--export-release', 'Abrams Web local', str(web / 'index.html')],
                            capture_output=True, text=True, cwd=ROOT, timeout=300)
    log = result.stdout + '\n' + result.stderr
    (stage.parent / 'export.log').write_text(log)
    if result.returncode or re.search(r'\b(?:SCRIPT ERROR|Parse Error|SHADER ERROR|ERROR:)', log, re.I):
        raise SystemExit(f'Godot Web export failed (exit {result.returncode}):\n{log}')
    verify_presentation(source, snapshot)
    for name in GODOT_FILES:
        path = web / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size == 0:
            raise SystemExit(f'Incomplete Godot Web export: {name}')
    # Generated HTML/PWA files are never installed. Only the reviewed wrapper
    # may launch the original-game Play loop.
    loader = web / 'index.js'
    loader.write_text(patch_audio_shutdown(loader.read_text()))
    return {'godot/' + name: web / name for name in GODOT_FILES}


def main():
    if not GODOT.is_file():
        raise SystemExit('Pinned local Godot 4.7.2 editor is missing')
    generated = WEB.parent
    with generated_lock(generated):
        expected = output_identity(generated, include_godot=True)
        # Unique task-owned staging, never delete another invocation's project.
        with tempfile.TemporaryDirectory(prefix='abrams-web-', dir=ROOT / '.runtime') as temporary:
            workspace = Path(temporary)
            inputs = stage_export(workspace / 'project', workspace / 'export')
            inputs.update(stage_assets(workspace / 'assets'))
            # The original baseline is carried through asset staging; never
            # recapture newer source and call it the candidate's source state.
            receipt = json.loads((workspace / 'export-sources.json').read_text())
            if receipt.get('schema') != 1 or not isinstance(receipt.get('files'), dict):
                raise SystemExit('Missing verified presentation source receipt')
            verify_presentation(ROOT / 'godot', receipt['files'])
            install_outputs(inputs, generated, expected, include_godot=True)
    print('Local Web Play export ready under ignored web-prototype/.generated/')


if __name__ == '__main__':
    main()
