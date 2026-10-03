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
const scenarios = JSON.parse(fs.readFileSync(path.join(__dirname, "dist/scenarios.json")));
const source = fs.readFileSync(path.join(__dirname, "dist/app.js"), "utf8");
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
  for (const id of ["comparison-image", "comparison-status", "comparison-panel", "map-panel", "map-status", "map-full", "map-open-link", "map-caption", "trailer-caption", "scenarios"])
    nodes.set(`#${id}`, element());
  nodes.set(".scenario-picker", element());
  const trailerSource = element();
  nodes.set("#trailer-player", element({source: trailerSource, querySelector: selector => selector === "source:last-of-type" ? trailerSource : null}));
  nodes.set("#scenario-image", element({id:"scenario-image", width:1254, height:1254,
    src:`https://example.test/assets/maps/manual-map-${scenarios[0].slug}.webp`, alt:"Initial mission map"}));
  const links = scenarios.map(s => element({dataset:{scenario:s.slug}, href:`https://example.test/assets/maps/manual-map-${s.slug}.webp`}));
  const briefs = scenarios.map(s => element({dataset:{brief:s.slug}, hidden:s.slug !== scenarios[0].slug}));
  const downloads = ["macos", "windows", "linux"].map(platform => element({dataset:{platform}, classes:["button", "button-outline", "download-button"]}));
  const loads = [];
  const metadata = deferred();
  const Image = function() {
    const image = element({completion:deferred()});
    image.decode = () => { loads.push(image); return image.completion.promise; };
    return image;
  };
  const selectors = {"[data-scenario]": links, "[data-brief]": briefs, ".download-button[data-platform]": downloads};
  const document = {
    querySelector: selector => nodes.get(selector),
    querySelectorAll: selector => selectors[selector] || []
  };
  vm.runInNewContext(source, {Image, document, fetch:() => metadata.promise, ...globals});
  const enable = async () => {
    metadata.resolve({ok:true, json:async () => scenarios});
    await flush();
  };
  const click = (index, extra = {}) => {
    let prevented = false;
    const promise = links[index].handlers.get("click")({preventDefault(){prevented = true;}, ...extra});
    return {promise, get prevented() { return prevented; }};
  };
  return {nodes, links, briefs, downloads, loads, metadata, enable, click};
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
    f.metadata.reject(new Error("metadata unavailable"));
    await flush();
    assert.equal(f.loads.length, 8, "preloading is independent of scenario metadata");
    assert.equal(f.links[0].handlers.has("click"), false, "ordinary map links remain usable without metadata");
    assert.equal(f.nodes.get("#map-status").attrs.get("data-tone"), "notice");
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
    const nav = (platform, userAgent = "", maxTouchPoints = 0) => fixture({navigator:{platform, userAgent, maxTouchPoints}});
    assert.deepEqual(platforms(nav("Win32", "Mozilla/5.0 (Windows NT 10.0; Win64; x64)")), ["outline", "primary", "outline"]);
    assert.deepEqual(platforms(nav("MacIntel", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)")), ["primary", "outline", "outline"]);
    assert.deepEqual(platforms(nav("Linux x86_64", "Mozilla/5.0 (X11; Linux x86_64)")), ["outline", "outline", "primary"]);
    assert.deepEqual(platforms(nav("iPhone", "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", 5)), ["outline", "outline", "outline"]);
    assert.deepEqual(platforms(nav("MacIntel", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", 5)), ["outline", "outline", "outline"], "iPadOS reports MacIntel with touch");
    assert.deepEqual(platforms(nav("Linux armv8l", "Mozilla/5.0 (Linux; Android 14)")), ["outline", "outline", "outline"]);
    assert.deepEqual(platforms(fixture()), ["outline", "outline", "outline"], "no navigator, no promotion");
  }
  console.log("PASS: lazily warmed low-priority decoded maps (IntersectionObserver, Save-Data aware); node reuse, rapid selection, retry, quiet status, shared mission links, trailer source errors, platform promotion and link fallbacks");
  settled = true;
  process.exitCode = 0;
})().catch(error => { settled = true; console.error(error); process.exitCode = 1; });
