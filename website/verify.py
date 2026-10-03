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
        self.text = []
        self.downloads = []
        self.skip = 0

    def handle_data(self, data):
        if not self.skip:
            self.text.append(data)
            if self.downloads and self.downloads[-1][2]:
                self.downloads[-1][1].append(data)

    def handle_endtag(self, tag):
        if tag in ("script", "style"):
            self.skip -= 1
        elif tag == "a" and self.downloads:
            self.downloads[-1][2] = False

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag in ("script", "style"):
            self.skip += 1
        if tag == "a" and "download-button" in attrs.get("class", "").split():
            self.downloads.append([attrs.get("href", ""), [], True])
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
        for candidate in attrs.get("srcset", "").split(","):
            if candidate.strip():
                self.refs.append(candidate.split()[0])
        if "data-scenario" in attrs:
            self.scenarios.append(attrs["data-scenario"])

    def visible_text(self):
        return re.sub(r"\s+", " ", " ".join(self.text))


def dist_file(url):
    """Map a site URL or root-relative path (query and fragment ignored) to its dist file."""
    path = unquote(urlsplit(url).path).lstrip("/")
    if not path or path.endswith("/"):
        path += "index.html"
    return (DIST / path).resolve()


def token_matches(url):
    """A ?v= cache token must be the first 12 hex digits of the referenced file's SHA-256."""
    file = dist_file(url.removeprefix("https://abramsremastered.com"))
    token = dict(part.split("=", 1) for part in urlsplit(url).query.split("&") if "=" in part).get("v")
    return file.is_file() and token == hashlib.sha256(file.read_bytes()).hexdigest()[:12]


def id_references(node):
    if isinstance(node, dict):
        if set(node) == {"@id"}:
            yield node["@id"]
        for value in node.values():
            yield from id_references(value)
    elif isinstance(node, list):
        for value in node:
            yield from id_references(value)


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
    raster_files = {str(p.relative_to(ROOT)) for p in DIST.rglob("*") if p.suffix in {".webp", ".jpg", ".png"}}
    if raster_files != {r["file"] for r in provenance["rasters"]}:
        errors.append("Raster provenance does not cover the served inventory")
    for row in provenance["rasters"] + provenance["media"] + provenance["documents"]:
        asset = ROOT / row["file"]
        if hashlib.sha256(asset.read_bytes()).hexdigest() != row["output_sha256"]:
            errors.append(f"Asset differs from recorded provenance: {asset.name}")
        if asset.suffix == ".webp" and not asset.with_suffix(asset.suffix + ".json").is_file():
            errors.append(f"Missing origin sidecar: {asset.name}")
    permitted = {".html", ".css", ".js", ".json", ".webp", ".jpg", ".png", ".svg", ".ttf", ".woff2", ".txt", ".mp4", ".vtt", ".xml", ".pdf"}
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
    if len(page.tracks) != 1 or page.tracks[0].get("kind") != "captions":
        errors.append("The trailer needs its English caption track")
    else:
        movie = next(r for r in provenance["media"] if r["file"].endswith(".mp4"))
        expected_default = not movie.get("captions_burned_in", False)
        if ("default" in page.tracks[0]) != expected_default:
            errors.append("Native caption default must avoid duplicating captions already in the movie")
    media_files = {str(p.relative_to(ROOT)) for p in DIST.rglob("*") if p.suffix in {".mp4", ".vtt"}}
    if media_files != {r["file"] for r in provenance["media"]}:
        errors.append("Unexpected media in static publication")
    if (DIST / "CNAME").read_text().strip() != "abramsremastered.com":
        errors.append("CNAME must match the requested domain")
    if "Starts muted" in html or "Download the trailer" in html or "nodownload" in html:
        errors.append("Trailer download controls must remain native to the player")
    documents = {str(p.relative_to(ROOT)) for p in DIST.rglob("*.pdf")}
    expected_documents = {"dist/assets/guides/field-guide.pdf", "dist/assets/guides/keyboard-controls.pdf"}
    if documents != {r["file"] for r in provenance["documents"]} or documents != expected_documents:
        errors.append("Only the two authored player-reference PDFs may be published")
    reference_block = re.search(r'<div class="reference-downloads".*?</div>', html, re.S)
    if not reference_block:
        errors.append("Missing prominent player-reference download buttons")
    else:
        references = Page()
        references.feed(reference_block[0])
        expected_links = {"assets/guides/field-guide.pdf", "assets/guides/keyboard-controls.pdf"}
        if len(references.refs) != 2 or {urlsplit(r).path for r in references.refs} != expected_links or reference_block[0].count('download=') != 2:
            errors.append("Reference buttons must download the two authored PDFs")
    for favicon in ('href="favicon.svg"', 'href="favicon-32.png"', 'href="apple-touch-icon.png"'):
        if favicon not in html:
            errors.append("Missing star favicon format: " + favicon)
    star = ET.parse(DIST / "favicon.svg").getroot()
    if not star.findall("{http://www.w3.org/2000/svg}circle") or not star.findall("{http://www.w3.org/2000/svg}path"):
        errors.append("Favicon must retain the black disc and white star")
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
        movie = next(r for r in provenance["media"] if r["file"].endswith(".mp4"))
        expected_url = canonical + "assets/video/abrams-fan-remaster-trailer.mp4?v=" + movie["output_sha256"][:12]
        if video_schema["duration"] != f"PT{movie['duration_seconds']:g}S" or video_schema["contentUrl"] != expected_url:
            errors.append("Trailer metadata does not match the accepted media")
        if "aggregateRating" in blocks[0] or "review" in blocks[0]: errors.append("Unsubstantiated ratings in metadata")
        node_ids = {node.get("@id") for node in graph}
        for reference in id_references(graph):
            if reference not in node_ids:
                errors.append(f"Structured metadata references a missing node: {reference}")
    sitemap = ET.parse(DIST / "sitemap.xml")
    sm, smv, smi = "{http://www.sitemaps.org/schemas/sitemap/0.9}", "{http://www.google.com/schemas/sitemap-video/1.1}", "{http://www.google.com/schemas/sitemap-image/1.1}"
    if sitemap.findtext(f".//{sm}loc") != canonical:
        errors.append("Sitemap URL mismatch")
    for loc in [e.text for e in sitemap.iter(f"{sm}loc")] + [e.text for e in sitemap.iter(f"{smi}loc")]:
        if urlsplit(loc).netloc == "abramsremastered.com" and not dist_file(loc).is_file():
            errors.append(f"Sitemap lists a missing file: {loc}")
    if len(blocks) == 1:
        sitemap_video = {key: sitemap.findtext(f".//{smv}{key}") for key in ("thumbnail_loc", "content_loc", "publication_date", "description")}
        if sitemap_video != {"thumbnail_loc": video_schema["thumbnailUrl"][0], "content_loc": video_schema["contentUrl"],
                             "publication_date": video_schema["uploadDate"][:10], "description": video_schema["description"]}:
            errors.append("Sitemap video entry differs from the structured trailer metadata")
        posters = [page.videos[0].get("poster", "") if page.videos else "", page.metas.get("og:image", ""), page.metas.get("twitter:image", ""),
                   video_schema["thumbnailUrl"][0], sitemap_video["thumbnail_loc"] or ""]
        for poster in posters:
            if not token_matches(poster):
                errors.append(f"Poster cache token must be the poster file's own hash: {poster}")
    for name, text in (("index.html", html), ("PRODUCT.md", (ROOT / "PRODUCT.md").read_text())):
        if any(private in text for private in ("currently private", "Downloads require repository access", "requires repository access", "GitHub is private")):
            errors.append(f"Private-only copy in the authorized public site: {name}")
    visible = page.visible_text()
    for commitment in ("Original game by Dynamix", "Published by Electronic Arts", "Fan Remastered by Nell Watson", "Dedicated to the memory of",
                       "David “Ming” Kenny", "original PC game", "optional", "neither"):
        if commitment not in visible:
            errors.append(f"Brand commitment missing from visible text: {commitment}")
    if not re.search(r'<img[^>]*\ssrc="[^"]*abrams-cover-remastered', html):
        errors.append("The remastered box art must stay on the page")
    for href, text, _ in page.downloads:
        release = re.search(r"releases/download/v0\.1\.0-alpha\.(\d+)", href)
        if release and f"alpha {release[1]}" not in re.sub(r"\s+", " ", " ".join(text)):
            errors.append(f"Download label must name its alpha: {href}")
    if any("macOS" in href and "v0.1.0-alpha.2/" in href for href, _, _ in page.downloads):
        errors.append("The macOS download must be the notarized alpha.4 build, not alpha.2")
    # The notarized alpha.4 Mac app has Tab fast forward, in-app guides and Gatekeeper approval.
    for stale in ("the macOS alpha uses the Session menu", "Windows and Linux builds also open them in the app", "not yet notarized"):
        if stale in visible:
            errors.append(f"Stale alpha.2 macOS qualifier still shown: {stale}")
    robots = DIST / "robots.txt"
    if not robots.is_file() or "Sitemap: https://abramsremastered.com/sitemap.xml" not in robots.read_text():
        errors.append("robots.txt must point at the sitemap")
    missing = DIST / "404.html"
    if not missing.is_file():
        errors.append("Missing branded 404 page")
    else:
        not_found = Page()
        not_found.feed(missing.read_text())
        errors += [f"404.html: {error}" for error in not_found.errors]
        if "noindex" not in (not_found.metas.get("robots") or "") or not_found.canonical:
            errors.append("404.html must be noindex without a canonical URL")
        for ref in not_found.refs:
            url = urlsplit(ref)
            if url.scheme or url.netloc:
                if url.scheme != "https":
                    errors.append(f"404.html: unexpected external scheme: {ref}")
            elif not url.path.startswith("/"):
                errors.append(f"404.html must use root-absolute URLs: {ref}")
            elif not dist_file(ref).is_relative_to(DIST) or not dist_file(ref).is_file():
                errors.append(f"404.html: missing asset: {ref}")
            elif url.fragment and url.fragment not in page.ids:
                errors.append(f"404.html: missing section: {ref}")
    llms = DIST / "llms.txt"
    if not llms.is_file():
        errors.append("Missing llms.txt")
    else:
        facts = llms.read_text()
        for fact in ("Fan Remastered by Nell Watson", "Dynamix", "Electronic Arts", "Ming"):
            if fact not in facts:
                errors.append(f"llms.txt omits: {fact}")
        if "not included" not in facts and "neither" not in facts:
            errors.append("llms.txt must say the original games are not included")
        for fragment in re.findall(r"https://abramsremastered\.com/#([\w-]+)", facts):
            if fragment not in page.ids:
                errors.append(f"llms.txt links a missing section: #{fragment}")
    if errors:
        raise SystemExit("\n".join(errors))
    print(f"PASS: {len(page.refs)} links/assets incl. srcset variants, 8 scenarios, {len(provenance['rasters'])} image origins, captioned user-controlled trailer, search metadata, robots, branded 404, llms.txt and brand guard; isolated static artifact")


if __name__ == "__main__":
    main()
