"use strict";

const graphics = {
  ega: { name: "EGA", description: "The original PC artwork and palette, preserved for the familiar look you remember.", alt: "EGA graphics: the original pixel-art Colonel in his office and original briefing lettering." },
  genesis: { name: "Genesis", description: "Original-resolution Genesis artwork where available, while the PC version remains the gameplay source.", alt: "Genesis graphics: the donor Colonel portrait and office artwork, displaying the same original PC briefing." },
  upscaled: { name: "Upscaled", description: "The remastered artwork in high resolution, with carefully rebuilt lettering. Upscaled is the game’s default graphics mode.", alt: "Upscaled graphics: the Colonel in his office, with restored portrait, desk and briefing lettering." }
};

const comparisonImage = document.querySelector("#comparison-image");
const comparisonStatus = document.querySelector("#comparison-status");
const comparisonPanel = document.querySelector("#comparison-panel");
let comparisonSequence = 0;
let currentMode = "upscaled";

async function loadImage(src) {
  const image = new Image();
  image.src = src;
  await image.decode();
  return image;
}

document.querySelectorAll('input[name="graphics"]').forEach(input => {
  input.addEventListener("change", async () => {
    const mode = input.value;
    const sequence = ++comparisonSequence;
    comparisonPanel.setAttribute("aria-busy", "true");
    comparisonStatus.removeAttribute("data-tone");
    comparisonStatus.textContent = `Loading ${graphics[mode].name}…`;
    try {
      const src = `assets/images/colonel-${mode}.webp`;
      await loadImage(src);
      if (sequence !== comparisonSequence) return;
      comparisonImage.src = src;
      comparisonImage.alt = graphics[mode].alt;
      document.querySelector("#comparison-caption").textContent = graphics[mode].name;
      document.querySelector("#mode-description").textContent = graphics[mode].description;
      currentMode = mode;
      comparisonStatus.textContent = `${graphics[mode].name} graphics selected.`;
    } catch {
      if (sequence !== comparisonSequence) return;
      document.querySelector(`#mode-${currentMode}`).checked = true;
      comparisonStatus.setAttribute("data-tone", "error");
      comparisonStatus.textContent = "That screenshot could not load. Please try selecting it again.";
    } finally {
      if (sequence === comparisonSequence) comparisonPanel.setAttribute("aria-busy", "false");
    }
  });
});

let mapImage = document.querySelector("#scenario-image");
const mapPanel = document.querySelector("#map-panel");
const mapStatus = document.querySelector("#map-status");
const mapFull = document.querySelector("#map-full");
const mapLinks = [...document.querySelectorAll("[data-scenario]")];
const mapImages = new Map();
const initialMapSource = mapImage.src;
let mapSequence = 0;

function showMapImage(image, alt) {
  image.id = mapImage.id;
  image.width = mapImage.width;
  image.height = mapImage.height;
  image.alt = alt;
  if (image !== mapImage) {
    mapImage.replaceWith(image);
    mapImage = image;
  }
}

function loadMap(src) {
  if (mapImages.has(src)) return mapImages.get(src);
  const image = new Image();
  image.decoding = "async";
  image.fetchPriority = "low";
  image.src = src;
  const ready = image.decode().then(() => image).catch(error => {
    mapImages.delete(src);
    throw error;
  });
  mapImages.set(src, ready);
  return ready;
}

// Warm the missions at low priority once the section approaches, the initial map
// first. Keep the decoded image nodes so selecting a map never relies on another
// cache lookup. With Save-Data on, maps load only when a mission is selected.
const saveData = typeof navigator !== "undefined" && navigator.connection?.saveData === true;
let mapsWarmed = false;
function warmMaps() {
  if (mapsWarmed) return;
  mapsWarmed = true;
  const initial = mapLinks.filter(link => link.href === initialMapSource);
  [...initial, ...mapLinks.filter(link => link.href !== initialMapSource)].forEach(link => {
    loadMap(link.href).then(image => {
      if (mapSequence === 0 && link.href === initialMapSource) showMapImage(image, mapImage.alt);
    }).catch(() => {});
  });
}
const scenarioSection = document.querySelector("#scenarios");
if (!saveData) {
  if (typeof IntersectionObserver !== "function" || !scenarioSection) warmMaps();
  else {
    const observer = new IntersectionObserver(entries => {
      if (!entries.some(entry => entry.isIntersecting)) return;
      observer.disconnect();
      warmMaps();
    }, { rootMargin: "1500px 0px" });
    observer.observe(scenarioSection);
    const picker = document.querySelector(".scenario-picker");
    picker?.addEventListener("pointerenter", warmMaps, { once: true });
    picker?.addEventListener("focusin", warmMaps, { once: true });
  }
}

const reducedMotion = () => typeof matchMedia === "function" && matchMedia("(prefers-reduced-motion: reduce)").matches;

async function enableMaps() {
  let scenarios;
  try {
    const response = await fetch("scenarios.json");
    if (!response.ok) throw new Error("Scenario content unavailable");
    scenarios = await response.json();
  } catch {
    mapStatus.setAttribute("data-tone", "notice");
    mapStatus.textContent = "Select a mission to open its full-size map.";
    return;
  }
  async function select(link, scenario, reveal) {
    const sequence = ++mapSequence;
    mapStatus.removeAttribute("data-tone");
    mapStatus.textContent = `Loading ${scenario.name}…`;
    mapPanel.setAttribute("aria-busy", "true");
    try {
      const image = await loadMap(link.href);
      if (sequence !== mapSequence) return;
      showMapImage(image, `Restored manual map of ${scenario.name}, showing its roads, terrain, river crossings and marked positions.`);
      mapFull.href = link.href;
      mapFull.setAttribute("aria-label", `Open full-size restored map of ${scenario.name}`);
      document.querySelectorAll("[data-brief]").forEach(brief => {
        brief.hidden = brief.dataset.brief !== scenario.slug;
      });
      document.querySelector("#map-open-link").href = link.href;
      document.querySelector("#map-caption").textContent = scenario.name;
      mapLinks.forEach(item => item.removeAttribute("aria-current"));
      link.setAttribute("aria-current", "true");
      mapStatus.textContent = `${scenario.name} map selected.`;
      if (typeof history !== "undefined") history.replaceState(null, "", `#scenario-${scenario.slug}`);
      if (reveal && typeof matchMedia === "function" && matchMedia("(max-width: 800px)").matches)
        mapPanel.scrollIntoView?.({ block: "nearest", behavior: reducedMotion() ? "auto" : "smooth" });
    } catch {
      if (sequence !== mapSequence) return;
      mapStatus.setAttribute("data-tone", "error");
      mapStatus.textContent = "That map could not load. Please try again, or open its link in a new tab.";
    } finally {
      if (sequence === mapSequence) mapPanel.setAttribute("aria-busy", "false");
    }
  }
  mapLinks.forEach(link => {
    link.addEventListener("click", async event => {
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      const scenario = scenarios.find(item => item.slug === link.dataset.scenario);
      if (!scenario) return;
      event.preventDefault();
      await select(link, scenario, true);
    });
  });
  // A shared #scenario-<slug> link opens that mission's map.
  const requested = typeof location !== "undefined" && location.hash.startsWith("#scenario-") ? location.hash.slice(10) : "";
  const shared = scenarios.find(item => item.slug === requested);
  const sharedLink = shared && mapLinks.find(link => link.dataset.scenario === shared.slug);
  if (sharedLink) {
    scenarioSection?.scrollIntoView?.();
    await select(sharedLink, shared, false);
  }
}
enableMaps();

const trailer = document.querySelector("#trailer-player");
const showTrailerError = () => {
  document.querySelector("#trailer-caption").textContent = "The trailer could not load. Reload the page or try another browser.";
};
trailer.addEventListener("error", showTrailerError);
trailer.querySelector?.("source:last-of-type")?.addEventListener("error", showTrailerError);

// S5: downloads have equal weight without JavaScript; promote the visitor's own
// desktop platform when it can be detected. Phones and tablets promote nothing.
function desktopPlatform() {
  if (typeof navigator === "undefined") return "";
  const agent = navigator.userAgent || "";
  if (/Android|iPhone|iPad|iPod|CrOS/.test(agent) || (/Mac/.test(navigator.platform || "") && navigator.maxTouchPoints > 1)) return "";
  const name = (navigator.userAgentData?.platform || navigator.platform || agent).toLowerCase();
  return name.includes("mac") ? "macos" : name.includes("win") ? "windows" : name.includes("linux") ? "linux" : "";
}
const platform = desktopPlatform();
document.querySelectorAll(".download-button[data-platform]").forEach(button => {
  if (platform && button.dataset.platform === platform) button.classList.replace("button-outline", "button-primary");
});
