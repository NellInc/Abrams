"""Once-only loader bark after original reload completion AND visible READY.

Six emulated frames is a presentation freshness limit, never a gameplay timer.
A later station return cannot turn an old completion into a new announcement.
"""
MAX_DELAY_FRAMES = 6


class ReadinessBark:
    def __init__(self):
        self.pending = None

    def advance(self, frame, events, presentation, status):
        for event in events:
            if event['kind'] == 'reload_complete':
                barrier = event.get('text_sequence')
                self.pending = (frame,event) if isinstance(barrier,int) and barrier>=0 else None
            elif event['kind'] == 'sound' and event.get('sample') == 'cannon':
                self.pending = None  # A new accepted shot supersedes the old load.
        if not status.get('active'):
            self.pending = None
        if self.pending is None: return []
        completed,event = self.pending
        if frame-completed > MAX_DELAY_FRAMES:
            self.pending = None
            return []
        for run in presentation.get('text_runs',[]):
            if (run.get('kind') != 'weapon_status' or run.get('text') != 'READY ' or
                    run.get('return_ip') != 0x55DF or run.get('source_pointer') != 0x0ACA or
                    run.get('draw_sequence',0) <= event['text_sequence']): continue
            self.pending = None
            return [event | {'kind':'readiness_visible','sample':None,'voice':'loaded',
                'enabled':bool(event['enabled'] and status.get('enabled')),
                'completion_frame':completed,'text_return_ip':run['return_ip'],
                'text_pointer':run['source_pointer'],'text_draw_sequence':run['draw_sequence'],
                'text_pixel_sha256':run['pixel_sha256']}]
        return []
