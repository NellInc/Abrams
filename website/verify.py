"""Finite, dependency-free checks for the deployable webpage."""
from __future__ import annotations

import hashlib
import json
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"


class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.ids = set()
        self.refs = []
        self.scenarios = []
        self.errors = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            if attrs["id"] in self.ids:
                self.errors.append(f"Duplicate id: {attrs['id']}")
            self.ids.add(attrs["id"])
        if tag == "img" and "alt" not in attrs:
            self.errors.append(f"Missing image alt: {attrs.get('src')}")
        for key in ("href", "src"):
            if key in attrs:
                self.refs.append(attrs[key])
        if "data-scenario" in attrs:
            self.scenarios.append(attrs["data-scenario"])


def main():
    page = Page()
    html = (DIST / "index.html").read_text()
    page.feed(html)
    errors = page.errors
    for ref in page.refs:
        url = urlsplit(ref)
        if url.scheme or url.netloc:
            if url.scheme != "https":
                errors.append(f"Unexpected external scheme: {ref}")
            continue
        if url.path:
            path = (DIST / unquote(url.path)).resolve()
            if not path.is_relative_to(DIST) or not path.is_file():
                errors.append(f"Missing or out-of-bound asset: {ref}")
        elif url.fragment and url.fragment not in page.ids:
            errors.append(f"Missing section: {ref}")
    scenarios = json.loads((DIST / "scenarios.json").read_text())
    if len(scenarios) != 8 or {s["slug"] for s in scenarios} != set(page.scenarios):
        errors.append("Scenario inventory differs from all eight displayed missions")
    for scenario in scenarios:
        if not (DIST / f"assets/maps/manual-map-{scenario['slug']}.webp").is_file():
            errors.append(f"Missing scenario map: {scenario['slug']}")
    for row in json.loads((ROOT / "asset-provenance.json").read_text())["rasters"]:
        asset = ROOT / row["file"]
        if hashlib.sha256(asset.read_bytes()).hexdigest() != row["output_sha256"]:
            errors.append(f"Asset differs from recorded provenance: {asset.name}")
        if not asset.with_suffix(asset.suffix + ".json").is_file():
            errors.append(f"Missing origin sidecar: {asset.name}")
    permitted = {".html", ".css", ".js", ".json", ".webp", ".ttf", ".txt"}
    for path in DIST.rglob("*"):
        if path.is_symlink():
            errors.append(f"Symbolic link in publication artifact: {path.name}")
        elif path.is_file() and path.suffix not in permitted:
            errors.append(f"Unexpected publication file: {path.name}")
    for forbidden in ("ABRAMS.COM", "SIM.EXE", "<iframe", "<audio", "<video"):
        if forbidden.startswith("<") and forbidden in html.lower():
            errors.append(f"Unexpected embedded media: {forbidden}")
        elif (DIST / forbidden).exists():
            errors.append(f"Original game must not be bundled: {forbidden}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {len(page.refs)} links/assets, 8 scenarios, 16 image origins; isolated static artifact")


if __name__ == "__main__":
    main()
