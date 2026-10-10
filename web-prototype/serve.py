#!/usr/bin/env python3
"""Serve only this local prototype with the isolation headers required by pthreads."""
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


ROOT = Path(__file__).resolve().parent


class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ROOT), **kwargs)

    def translate_path(self, path):
        resolved = Path(super().translate_path(path)).resolve()
        return str(resolved if resolved.is_relative_to(ROOT) else ROOT / "not-found")

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


if __name__ == "__main__":
    print("Abrams local prototype: http://127.0.0.1:4174", flush=True)
    ThreadingHTTPServer(("127.0.0.1", 4174), Handler).serve_forever()
