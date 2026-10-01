"use strict";
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
function fixture() {
  const nodes = new Map();
  const element = (props = {}) => ({
    attrs: new Map(), handlers: new Map(), ...props,
    setAttribute(name, value) { this.attrs.set(name, value); },
    removeAttribute(name) { this.attrs.delete(name); },
    addEventListener(name, callback) { this.handlers.set(name, callback); },
    replaceWith(next) { assert.equal(nodes.get("#scenario-image"), this); nodes.set("#scenario-image", next); }
  });
  for (const id of ["comparison-image", "comparison-status", "comparison-panel", "map-panel", "map-status", "map-full", "map-open-link", "map-caption", "trailer-player", "trailer-caption"])
    nodes.set(`#${id}`, element());
  nodes.set("#scenario-image", element({id:"scenario-image", width:1254, height:1254,
    src:`https://example.test/assets/maps/manual-map-${scenarios[0].slug}.webp`, alt:"Initial mission map"}));
  const links = scenarios.map(s => element({dataset:{scenario:s.slug}, href:`https://example.test/assets/maps/manual-map-${s.slug}.webp`}));
  const briefs = scenarios.map(s => element({dataset:{brief:s.slug}, hidden:s.slug !== scenarios[0].slug}));
  const loads = [];
  const metadata = deferred();
  const Image = function() {
    const image = element({completion:deferred()});
    image.decode = () => { loads.push(image); return image.completion.promise; };
    return image;
  };
  const document = {
    querySelector: selector => nodes.get(selector),
    querySelectorAll: selector => selector === "[data-scenario]" ? links : selector === "[data-brief]" ? briefs : []
  };
  vm.runInNewContext(source, {Image, document, fetch:() => metadata.promise});
  const enable = async () => {
    metadata.resolve({ok:true, json:async () => scenarios});
    await flush();
  };
  const click = (index, extra = {}) => {
    let prevented = false;
    const promise = links[index].handlers.get("click")({preventDefault(){prevented = true;}, ...extra});
    return {promise, get prevented() { return prevented; }};
  };
  return {nodes, links, briefs, loads, metadata, enable, click};
}
(async () => {
  {
    const f = fixture();
    assert.equal(f.loads.length, 8, "all maps start before scenario metadata resolves");
    assert.equal(new Set(f.loads.map(i => i.src)).size, 8);
    assert.ok(f.loads.every(i => i.decoding === "async" && i.fetchPriority === "low"));
    f.loads.forEach(i => i.completion.resolve());
    await f.enable();
    assert.equal(f.nodes.get("#scenario-image"), f.loads[0], "the initial map also uses its decoded node before scrolling");
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
    const f = fixture();
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
    assert.equal(f.nodes.get("#map-panel").attrs.get("aria-busy"), "false");
    const recovered = f.click(3);
    f.loads[9].completion.resolve();
    await recovered.promise;
    assert.equal(f.nodes.get("#map-caption").textContent, scenarios[3].name);
  }
  {
    const f = fixture();
    f.metadata.reject(new Error("metadata unavailable"));
    await flush();
    assert.equal(f.loads.length, 8, "preloading is independent of scenario metadata");
    assert.equal(f.links[0].handlers.has("click"), false, "ordinary map links remain usable without metadata");
  }
  console.log("PASS: eight eager low-priority decoded maps; node reuse, rapid selection, retry and link fallbacks");
})().catch(error => { console.error(error); process.exitCode = 1; });
