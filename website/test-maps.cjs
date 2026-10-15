"use strict";
// Fail closed: if an awaited promise never settles, Node drains its event loop and
// exits; only a run that reaches the final PASS line may exit 0.
process.exitCode = 1;
let settled = false;
process.on("exit", () => { if (!settled) console.error("FAIL: map test did not complete (an awaited promise never settled)"); });
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const source = fs.readFileSync(path.join(__dirname, "dist/app.js"), "utf8");
// The fixture mirrors the delivered page: mission slugs and names come from the
// real picker links, and graphics names from the real comparison radio labels.
const page = fs.readFileSync(path.join(__dirname, "dist/index.html"), "utf8");
const scenarios = [...page.matchAll(/<a href="([^"]+)" data-scenario="([^"]+)"[^>]*>([^<]+)<\/a>/g)].map(([, href, slug, name]) => ({href, slug, name}));
assert.equal(scenarios.length, 8, "the page lists eight mission links");
const modeLabels = Object.fromEntries([...page.matchAll(/<label for="mode-(\w+)">([^<]+)<\/label>/g)].map(([, mode, label]) => [mode, label]));
assert.deepEqual(Object.keys(modeLabels), ["ega", "genesis", "upscaled"]);
const initialDescription = page.match(/<p id="mode-description">([^<]+)<\/p>/)[1].replace(/&nbsp;/g, " ");
const deferred = () => {
  let resolve, reject;
  const promise = new Promise((yes, no) => { resolve = yes; reject = no; });
  return {promise, resolve, reject};
};
const flush = () => new Promise(resolve => setImmediate(resolve));
// globals: extra vm globals (IntersectionObserver, navigator, matchMedia, history, location).
function fixture(globals = {}) {
  const nodes = new Map();
  const element = (props = {}) => {
    const classes = new Set(props.classes || []);
    return {
      attrs: new Map(), handlers: new Map(), scrolled: [], ...props,
      classList: {
        contains: name => classes.has(name),
        replace(from, to) { if (!classes.delete(from)) return false; classes.add(to); return true; }
      },
      setAttribute(name, value) { this.attrs.set(name, value); },
      removeAttribute(name) { this.attrs.delete(name); },
      addEventListener(name, callback) { this.handlers.set(name, callback); },
      scrollIntoView(options) { this.scrolled.push(options); },
      replaceWith(next) { assert.equal(nodes.get("#scenario-image"), this); nodes.set("#scenario-image", next); }
    };
  };
  for (const id of ["comparison-image", "comparison-status", "comparison-panel", "comparison-caption", "mode-description", "map-panel", "map-status", "map-full", "map-open-link", "map-caption", "trailer-caption", "scenarios"])
    nodes.set(`#${id}`, element());
  nodes.set(".scenario-picker", element());
  const trailerSource = element();
  nodes.set("#trailer-player", element({source: trailerSource, querySelector: selector => selector === "source:last-of-type" ? trailerSource : null}));
  nodes.set("#scenario-image", element({id:"scenario-image", width:1254, height:1254,
    src:`https://example.test/assets/maps/manual-map-${scenarios[0].slug}.webp`, alt:"Initial mission map"}));
  nodes.get("#comparison-image").src = "assets/images/colonel-upscaled.webp";
  nodes.get("#comparison-caption").textContent = modeLabels.upscaled;
  // One radio group: checking a radio unchecks the others, as in a browser.
  let checkedMode = "upscaled";
  const radios = Object.keys(modeLabels).map(value => element({value}));
  radios.forEach(radio => {
    Object.defineProperty(radio, "checked", {get: () => checkedMode === radio.value, set: on => {
      if (on) checkedMode = radio.value; else if (checkedMode === radio.value) checkedMode = null;
    }});
    nodes.set(`#mode-${radio.value}`, radio);
  });
  // Whitespace around the link text, as in formatted markup; the script trims it.
  const links = scenarios.map(s => element({dataset:{scenario:s.slug}, textContent:`\n  ${s.name}  `, href:`https://example.test/${s.href}`}));
  const briefs = scenarios.map(s => element({dataset:{brief:s.slug}, hidden:s.slug !== scenarios[0].slug}));
  const downloads = ["macos", "windows", "linux"].map(platform => element({dataset:{platform}, classes:["button", "button-outline", "download-button"]}));
  const loads = [];
  const fetches = [];
  const Image = function() {
    const image = element({completion:deferred()});
    image.decode = () => { loads.push(image); return image.completion.promise; };
    return image;
  };
  const selectors = {"[data-scenario]": links, "[data-brief]": briefs, ".download-button[data-platform]": downloads, 'input[name="graphics"]': radios};
  const document = {
    querySelector: selector => nodes.get(selector),
    querySelectorAll: selector => selectors[selector] || []
  };
  vm.runInNewContext(source, {Image, document, fetch:url => { fetches.push(url); return new Promise(() => {}); }, ...globals});
  const enable = flush;
  // A real radio is checked before its change event fires.
  const choose = value => {
    const radio = radios.find(item => item.value === value);
    radio.checked = true;
    return radio.handlers.get("change")();
  };
  const click = (index, extra = {}) => {
    let prevented = false;
    const promise = links[index].handlers.get("click")({preventDefault(){prevented = true;}, ...extra});
    return {promise, get prevented() { return prevented; }};
  };
  return {nodes, links, briefs, downloads, radios, loads, fetches, enable, click, choose};
}
function observerStub() {
  const observers = [];
  class IntersectionObserver {
    constructor(callback, options) { Object.assign(this, {callback, options, targets:[], disconnected:false}); observers.push(this); }
    observe(target) { this.targets.push(target); }
    disconnect() { this.disconnected = true; }
  }
  return {IntersectionObserver, observers};
}
const platforms = f => f.downloads.map(b => b.classList.contains("button-primary") ? "primary" : "outline");
(async () => {
  {
    // Maps wait for the scenarios section to approach, then warm the initial map first.
    const {IntersectionObserver, observers} = observerStub();
    const f = fixture({IntersectionObserver});
    assert.equal(f.loads.length, 0, "no map downloads before the scenarios section approaches");
    assert.equal(observers.length, 1);
    assert.equal(observers[0].options.rootMargin, "1500px 0px");
    assert.deepEqual(observers[0].targets, [f.nodes.get("#scenarios")]);
    observers[0].callback([{isIntersecting:false}]);
    assert.equal(f.loads.length, 0, "a non-intersecting entry does not warm the maps");
    observers[0].callback([{isIntersecting:true}]);
    assert.equal(observers[0].disconnected, true);
    assert.equal(f.loads.length, 8, "all eight maps warm once the section approaches");
    assert.equal(f.loads[0].src, f.nodes.get("#scenario-image").src, "the initial map warms first");
    f.nodes.get(".scenario-picker").handlers.get("pointerenter")();
    f.nodes.get(".scenario-picker").handlers.get("focusin")();
    assert.equal(f.loads.length, 8, "warming runs once");
    assert.equal(new Set(f.loads.map(i => i.src)).size, 8);
    assert.ok(f.loads.every(i => i.decoding === "async" && i.fetchPriority === "low"));
    f.loads.forEach(i => i.completion.resolve());
    await f.enable();
    assert.equal(f.nodes.get("#scenario-image"), f.loads[0], "the initial map also uses its decoded node");
    assert.equal(f.loads[0].alt, "Initial mission map");
    for (let index = 0; index < 8; index++) {
      const {promise, prevented} = f.click(index);
      await promise;
      assert.equal(prevented, true);
      assert.equal(f.nodes.get("#scenario-image"), f.loads[index], "reuse the already decoded node");
      assert.equal(f.loads[index].id, "scenario-image");
      assert.equal(f.loads[index].width, 1254);
      assert.equal(f.loads[index].height, 1254);
      assert.equal(f.nodes.get("#map-caption").textContent, scenarios[index].name);
      assert.equal(f.nodes.get("#map-full").href, f.links[index].href);
      assert.equal(f.nodes.get("#map-panel").attrs.get("aria-busy"), "false");
      assert.equal(f.nodes.get("#map-status").attrs.has("data-tone"), false, "success stays a quiet announcement");
      assert.equal(f.links.filter(l => l.attrs.has("aria-current")).length, 1);
      assert.deepEqual(f.briefs.filter(b => !b.hidden).map(b => b.dataset.brief), [scenarios[index].slug]);
    }
    await f.click(0).promise;
    await f.click(0).promise;
    assert.equal(f.loads.length, 8, "repeat selections never download or decode again");
    const modified = f.click(1, {ctrlKey:true});
    await modified.promise;
    assert.equal(modified.prevented, false, "preserve modified-click full-size links");
  }
  {
    // Without IntersectionObserver, every map warms immediately (the previous behaviour).
    const f = fixture();
    assert.equal(f.loads.length, 8, "fallback warms all maps before scenario metadata resolves");
    await f.enable();
    const old = f.click(1), recent = f.click(2);
    f.loads[2].completion.resolve();
    await recent.promise;
    f.loads[1].completion.resolve();
    await old.promise;
    assert.equal(f.nodes.get("#map-caption").textContent, scenarios[2].name, "late preload cannot overwrite the latest selection");
    assert.equal(f.loads.length, 8, "selection during preload reuses its pending promise");
  }
  {
    const f = fixture();
    f.loads[3].completion.reject(new Error("temporary map failure"));
    await flush();
    await f.enable();
    const retry = f.click(3);
    assert.equal(f.loads.length, 9, "a failed warm-up can retry on selection");
    f.loads[8].completion.reject(new Error("still unavailable"));
    await retry.promise;
    assert.match(f.nodes.get("#map-status").textContent, /could not load/);
    assert.equal(f.nodes.get("#map-status").attrs.get("data-tone"), "error", "failures stay visible");
    assert.equal(f.nodes.get("#map-panel").attrs.get("aria-busy"), "false");
    const recovered = f.click(3);
    f.loads[9].completion.resolve();
    await recovered.promise;
    assert.equal(f.nodes.get("#map-caption").textContent, scenarios[3].name);
    assert.equal(f.nodes.get("#map-status").attrs.has("data-tone"), false, "a successful retry clears the error tone");
  }
  {
    const f = fixture();
    // Map switching reads the page itself: no scenario metadata request, handlers at once.
    assert.equal(f.loads.length, 8);
    assert.ok(f.links.every(link => link.handlers.has("click")), "every mission link switches maps without a metadata fetch");
    await flush();
    assert.deepEqual(f.fetches, [], "the page makes no scenario metadata request");
    f.loads[5].completion.resolve();
    await f.click(5).promise;
    assert.equal(f.nodes.get("#map-caption").textContent, scenarios[5].name, "the trimmed link text names the mission");
    assert.equal(f.nodes.get("#map-full").attrs.get("aria-label"), `Open full-size restored map of ${scenarios[5].name}`);
  }
  {
    // Save-Data: never warm; a selection loads exactly its own map.
    const {IntersectionObserver, observers} = observerStub();
    const f = fixture({IntersectionObserver, navigator:{connection:{saveData:true}, userAgent:"", platform:""}});
    assert.equal(f.loads.length, 0);
    assert.equal(observers.length, 0, "Save-Data visitors are not observed for warming");
    await f.enable();
    const selection = f.click(2);
    assert.equal(f.loads.length, 1, "a selection loads exactly one map");
    f.loads[0].completion.resolve();
    await selection.promise;
    assert.equal(f.nodes.get("#map-caption").textContent, scenarios[2].name);
  }
  {
    // Shareable missions and mobile map feedback.
    const replaced = [], queries = [];
    const history = {replaceState: (state, title, url) => replaced.push(url)};
    const matchMedia = query => { queries.push(query); return {matches: query === "(max-width: 800px)"}; };
    const f = fixture({history, matchMedia, location:{hash:`#scenario-${scenarios[6].slug}`}});
    f.loads.forEach(i => i.completion.resolve());
    await f.enable();
    await flush();
    assert.equal(f.nodes.get("#map-caption").textContent, scenarios[6].name, "a #scenario- link opens that mission");
    assert.equal(f.links[6].attrs.get("aria-current"), "true");
    assert.equal(f.nodes.get("#scenarios").scrolled.length, 1, "a shared mission link scrolls to the scenarios");
    assert.equal(f.nodes.get("#map-panel").scrolled.length, 0, "opening a shared link does not also scroll the map");
    await f.click(4).promise;
    assert.equal(replaced.at(-1), `#scenario-${scenarios[4].slug}`);
    assert.equal(JSON.stringify(f.nodes.get("#map-panel").scrolled.at(-1)), JSON.stringify({block:"nearest", behavior:"smooth"}), "phones bring the selected map into view");
  }
  {
    // The trailer's <source> reports load failures, not the <video>.
    const f = fixture();
    const caption = f.nodes.get("#trailer-caption");
    f.nodes.get("#trailer-player").source.handlers.get("error")();
    assert.match(caption.textContent, /could not load/);
    caption.textContent = "";
    f.nodes.get("#trailer-player").handlers.get("error")();
    assert.match(caption.textContent, /could not load/);
  }
  {
    // Download promotion: the visitor's desktop platform only; never on phones or without detection.
    // The macOS build is arm64-only and the Linux build x86_64-only: promote those
    // only on a known matching architecture.
    const promoted = async (platform, userAgent = "", maxTouchPoints = 0, userAgentData) => {
      const f = fixture({navigator:{platform, userAgent, maxTouchPoints, userAgentData}});
      await flush();
      return platforms(f);
    };
    const hints = (platform, values) => ({platform, getHighEntropyValues: async keys => {
      assert.equal(JSON.stringify(keys), JSON.stringify(["architecture", "bitness"]), "only the needed client hints are requested");
      if (values instanceof Error) throw values;
      return values;
    }});
    const mac = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)";
    const none = ["outline", "outline", "outline"];
    assert.deepEqual(await promoted("Win32", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"), ["outline", "primary", "outline"]);
    assert.deepEqual(await promoted("MacIntel", mac), none, "Safari and Firefox report MacIntel on Intel and Apple Silicon alike");
    assert.deepEqual(await promoted("MacIntel", mac, 0, hints("macOS", {architecture:"arm", bitness:"64"})), ["primary", "outline", "outline"], "Chromium on Apple Silicon");
    assert.deepEqual(await promoted("MacIntel", mac, 0, hints("macOS", {architecture:"x86", bitness:"64"})), none, "Chromium on an Intel Mac");
    assert.deepEqual(await promoted("MacIntel", mac, 0, hints("macOS", new Error("hints unavailable"))), none, "failed hints promote nothing");
    assert.deepEqual(await promoted("Linux x86_64", "Mozilla/5.0 (X11; Linux x86_64)"), ["outline", "outline", "primary"]);
    assert.deepEqual(await promoted("Linux x86_64", "Mozilla/5.0 (X11; Linux x86_64)", 0, hints("Linux", {architecture:"x86", bitness:"64"})), ["outline", "outline", "primary"]);
    assert.deepEqual(await promoted("Linux aarch64", "Mozilla/5.0 (X11; Linux aarch64)"), none, "ARM Linux cannot run the x86_64 build");
    assert.deepEqual(await promoted("Linux armv81", "Mozilla/5.0 (X11; Linux armv81)", 0, hints("Linux", {architecture:"arm", bitness:"64"})), none);
    assert.deepEqual(await promoted("Linux i686", "Mozilla/5.0 (X11; Linux i686)"), none, "32-bit Linux cannot run the x86_64 build");
    assert.deepEqual(await promoted("Linux", "Mozilla/5.0 (X11; Linux)", 0, hints("Linux", {architecture:"x86", bitness:"32"})), none);
    assert.deepEqual(await promoted("iPhone", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", 5), none);
    assert.deepEqual(await promoted("MacIntel", mac, 5), none, "iPadOS reports MacIntel with touch");
    assert.deepEqual(await promoted("Linux armv8l", "Mozilla/5.0 (Linux; Android 14)"), none);
    const bare = fixture();
    await flush();
    assert.deepEqual(platforms(bare), none, "no navigator, no promotion");
  }
  {
    // Graphics comparison: the latest selection wins, whatever order decodes finish in.
    const f = fixture();
    const image = f.nodes.get("#comparison-image"), status = f.nodes.get("#comparison-status"), panel = f.nodes.get("#comparison-panel");
    const comparisonLoad = mode => f.loads.find(load => load.src === `assets/images/colonel-${mode}.webp`);
    const ega = f.choose("ega"), genesis = f.choose("genesis");
    assert.equal(panel.attrs.get("aria-busy"), "true");
    assert.equal(status.textContent, `Loading ${modeLabels.genesis}…`);
    comparisonLoad("genesis").completion.resolve();
    await genesis;
    comparisonLoad("ega").completion.resolve();
    await ega;
    assert.equal(image.src, "assets/images/colonel-genesis.webp", "a late EGA decode cannot replace the newer Genesis choice");
    assert.ok(image.alt.startsWith(`${modeLabels.genesis} graphics:`));
    assert.equal(f.nodes.get("#comparison-caption").textContent, modeLabels.genesis, "caption matches the radio label");
    assert.equal(status.textContent, `${modeLabels.genesis} graphics selected.`);
    assert.equal(status.attrs.has("data-tone"), false);
    assert.equal(panel.attrs.get("aria-busy"), "false");
    // Every mode's caption and alt name its page label; Upscaled restores the page's own description.
    for (const mode of ["ega", "upscaled"]) {
      const selection = f.choose(mode);
      f.loads.at(-1).completion.resolve();
      await selection;
      assert.equal(f.nodes.get("#comparison-caption").textContent, modeLabels[mode]);
      assert.ok(image.alt.startsWith(`${modeLabels[mode]} graphics:`));
    }
    assert.equal(f.nodes.get("#mode-description").textContent, initialDescription, "script and page describe Upscaled identically");
    // A failed decode reverts the radio to the mode still shown.
    const failed = f.choose("genesis");
    f.loads.at(-1).completion.reject(new Error("decode failed"));
    await failed;
    assert.equal(status.attrs.get("data-tone"), "error");
    assert.match(status.textContent, /could not load/);
    assert.deepEqual(f.radios.filter(r => r.checked).map(r => r.value), ["upscaled"], "the shown mode's radio is checked again");
    assert.equal(image.src, "assets/images/colonel-upscaled.webp");
    assert.equal(panel.attrs.get("aria-busy"), "false");
  }
  {
    // A stale failure leaves the newer selection alone.
    const f = fixture();
    const status = f.nodes.get("#comparison-status"), panel = f.nodes.get("#comparison-panel");
    const ega = f.choose("ega"), genesis = f.choose("genesis");
    const [egaLoad, genesisLoad] = f.loads.slice(-2);
    egaLoad.completion.reject(new Error("stale failure"));
    await ega;
    assert.equal(status.attrs.has("data-tone"), false, "a stale failure shows no error");
    assert.deepEqual(f.radios.filter(r => r.checked).map(r => r.value), ["genesis"], "a stale failure does not revert the radio");
    assert.equal(panel.attrs.get("aria-busy"), "true", "the newer selection is still loading");
    genesisLoad.completion.resolve();
    await genesis;
    assert.equal(f.nodes.get("#comparison-image").src, "assets/images/colonel-genesis.webp");
    assert.equal(panel.attrs.get("aria-busy"), "false");
  }
  console.log("PASS: lazily warmed low-priority decoded maps (IntersectionObserver, Save-Data aware); node reuse, rapid selection, retry, quiet status, shared mission links, page-derived mission names without a metadata fetch, trailer source errors, architecture-aware platform promotion, graphics comparison (ordering, error rollback, stale failures, aria-busy) and link fallbacks");
  settled = true;
  process.exitCode = 0;
})().catch(error => { settled = true; console.error(error); process.exitCode = 1; });
