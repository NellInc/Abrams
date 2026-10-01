"""Finite, dependency-free checks for the deployable webpage."""
from __future__ import annotations

import hashlib
import json
import re
import xml.etree.ElementTree as ET
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
        self.briefs = []
        self.videos = []
        self.tracks = []
        self.metas = {}
        self.canonical = None
        self.errors = []

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if "id" in attrs:
            if attrs["id"] in self.ids:
                self.errors.append(f"Duplicate id: {attrs['id']}")
            self.ids.add(attrs["id"])
        if tag == "img" and "alt" not in attrs:
            self.errors.append(f"Missing image alt: {attrs.get('src')}")
        if "data-brief" in attrs:
            self.briefs.append(attrs["data-brief"])
        if tag == "video": self.videos.append(attrs)
        if tag == "track": self.tracks.append(attrs)
        if tag == "meta": self.metas[attrs.get("name", attrs.get("property"))] = attrs.get("content")
        if tag == "link" and attrs.get("rel") == "canonical": self.canonical = attrs.get("href")
        for key in ("href", "src", "poster"):
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
    if set(page.briefs) != {s["slug"] for s in scenarios} or len(page.briefs) != 8:
        errors.append("All eight mission briefs must be in the delivered HTML")
    provenance = json.loads((ROOT / "asset-provenance.json").read_text())
    raster_files = {str(p.relative_to(ROOT)) for p in DIST.rglob("*") if p.suffix in {".webp", ".jpg"}}
    if raster_files != {r["file"] for r in provenance["rasters"]}:
        errors.append("Raster provenance does not cover the served inventory")
    for row in provenance["rasters"] + provenance["media"] + provenance["documents"]:
        asset = ROOT / row["file"]
        if hashlib.sha256(asset.read_bytes()).hexdigest() != row["output_sha256"]:
            errors.append(f"Asset differs from recorded provenance: {asset.name}")
        if asset.suffix == ".webp" and not asset.with_suffix(asset.suffix + ".json").is_file():
            errors.append(f"Missing origin sidecar: {asset.name}")
    permitted = {".html", ".css", ".js", ".json", ".webp", ".jpg", ".ttf", ".txt", ".mp4", ".vtt", ".xml", ".pdf"}
    for path in DIST.rglob("*"):
        if path.is_symlink():
            errors.append(f"Symbolic link in publication artifact: {path.name}")
        elif path.is_file() and path.suffix not in permitted and path.name != "CNAME":
            errors.append(f"Unexpected publication file: {path.name}")
    for forbidden in ("ABRAMS.COM", "SIM.EXE", "<iframe", "<audio"):
        if forbidden.startswith("<") and forbidden in html.lower():
            errors.append(f"Unexpected embedded media: {forbidden}")
        elif (DIST / forbidden).exists():
            errors.append(f"Original game must not be bundled: {forbidden}")
    if len(page.videos) != 1:
        errors.append("Expected one requested project trailer")
    else:
        video = page.videos[0]
        if any(key not in video for key in ("controls", "playsinline")) or "muted" in video or "autoplay" in video or video.get("preload") != "none":
            errors.append("Trailer must use unmuted, user-controlled, non-preloaded playback")
    if len(page.tracks) != 1 or page.tracks[0].get("kind") != "captions" or "default" not in page.tracks[0]:
        errors.append("The trailer needs its default English caption track")
    media_files = {str(p.relative_to(ROOT)) for p in DIST.rglob("*") if p.suffix in {".mp4", ".vtt"}}
    if media_files != {r["file"] for r in provenance["media"]}:
        errors.append("Unexpected media in static publication")
    if (DIST / "CNAME").read_text().strip() != "abramsremastered.com":
        errors.append("CNAME must match the requested domain")
    if "Starts muted" in html or "Download the trailer" in html or "nodownload" in html:
        errors.append("Trailer download controls must remain native to the player")
    documents = {str(p.relative_to(ROOT)) for p in DIST.rglob("*.pdf")}
    if documents != {r["file"] for r in provenance["documents"]} or documents != {"dist/assets/guides/field-guide.pdf"}:
        errors.append("Only the authored field guide may be published as a PDF")
    canonical = "https://abramsremastered.com/"
    if page.canonical != canonical or page.metas.get("og:url") != canonical:
        errors.append("Canonical and sharing URLs must match the published project path")
    for key in ("description", "og:title", "og:description", "og:image", "og:image:alt", "twitter:card", "twitter:image"):
        if not page.metas.get(key): errors.append(f"Missing search/sharing metadata: {key}")
    blocks = re.findall(r'<script type="application/ld\+json">(.*?)</script>', html, re.S)
    if len(blocks) != 1: errors.append("Expected one structured metadata graph")
    else:
        graph = json.loads(blocks[0])["@graph"]
        video_schema = next(r for r in graph if r["@type"] == "VideoObject")
        if video_schema["duration"] != "PT1M" or video_schema["contentUrl"] != canonical + "assets/video/abrams-fan-remaster-trailer.mp4":
            errors.append("Trailer metadata does not match the accepted media")
        if "aggregateRating" in blocks[0] or "review" in blocks[0]: errors.append("Unsubstantiated ratings in metadata")
    sitemap = ET.parse(DIST / "sitemap.xml")
    if sitemap.findtext(".//{http://www.sitemaps.org/schemas/sitemap/0.9}loc") != canonical:
        errors.append("Sitemap URL mismatch")
    if "currently private" in html or "Downloads require repository access" in html:
        errors.append("Private-only copy in the authorized public site")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {len(page.refs)} links/assets, 8 scenarios, {len(provenance["rasters"])} image origins, captioned user-controlled trailer, search metadata; isolated static artifact")


if __name__ == "__main__":
    main()
