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
      comparisonStatus.textContent = "That screenshot could not load. Please try selecting it again.";
    } finally {
      if (sequence === comparisonSequence) comparisonPanel.setAttribute("aria-busy", "false");
    }
  });
});

const mapImage = document.querySelector("#scenario-image");
const mapPanel = document.querySelector("#map-panel");
const mapStatus = document.querySelector("#map-status");
const mapFull = document.querySelector("#map-full");
let mapSequence = 0;

async function enableMaps() {
  let scenarios;
  try {
    const response = await fetch("scenarios.json");
    if (!response.ok) throw new Error("Scenario content unavailable");
    scenarios = await response.json();
  } catch {
    mapStatus.textContent = "Select a mission to open its full-size map.";
    return;
  }
  document.querySelectorAll("[data-scenario]").forEach(link => {
    link.addEventListener("click", async event => {
      if (event.ctrlKey || event.metaKey || event.shiftKey || event.altKey) return;
      const scenario = scenarios.find(item => item.slug === link.dataset.scenario);
      if (!scenario) return;
      event.preventDefault();
      const sequence = ++mapSequence;
      mapStatus.textContent = `Loading ${scenario.name}…`;
      mapPanel.setAttribute("aria-busy", "true");
      try {
        await loadImage(link.href);
        if (sequence !== mapSequence) return;
        mapImage.src = link.href;
        mapImage.alt = `Restored manual map of ${scenario.name}, showing its roads, terrain, river crossings and marked positions.`;
        mapFull.href = link.href;
        mapFull.setAttribute("aria-label", `Open full-size restored map of ${scenario.name}`);
        document.querySelectorAll("[data-brief]").forEach(brief => {
          brief.hidden = brief.dataset.brief !== scenario.slug;
        });
        document.querySelector("#map-open-link").href = link.href;
        document.querySelector("#map-caption").textContent = scenario.name;
        document.querySelectorAll("[data-scenario]").forEach(item => item.removeAttribute("aria-current"));
        link.setAttribute("aria-current", "true");
        mapStatus.textContent = `${scenario.name} map selected.`;
      } catch {
        if (sequence !== mapSequence) return;
        mapStatus.textContent = "That map could not load. Please try again, or open its link in a new tab.";
      } finally {
        if (sequence === mapSequence) mapPanel.setAttribute("aria-busy", "false");
      }
    });
  });
}
enableMaps();

const trailer = document.querySelector("#trailer-player");
// Keep initial playback quiet. The visitor can unmute using native controls.
trailer.muted = true;
trailer.addEventListener("error", () => {
  document.querySelector("#trailer-caption").textContent = "The trailer could not load. Use the download link below to watch it.";
});
