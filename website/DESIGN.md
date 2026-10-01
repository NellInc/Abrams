---
name: Abrams project webpage
description: An artwork-led exhibit for the M1 Abrams Battle Tank Fan Remaster.
colors:
  ink: "#181a17"
  surface: "#232620"
  paper: "#fff2db"
  muted: "#c3c7b9"
  orange: "#ff753d"
  yellow: "#ffd02f"
  line: "#45493f"
  map-paper: "#f5efd9"
  map-ink: "#252b20"
  map-accent: "#80361e"
  primary-hover: "#ffe477"
  outline-border: "#707664"
  mode-border: "#616957"
  screen-background: "#080a08"
  map-muted: "#505742"
  map-divider: "#adae98"
  map-hover: "#e7dec0"
typography:
  display:
    fontFamily: '"Barlow Condensed", Arial, sans-serif'
    fontSize: "clamp(3.2rem, 6.65vw, 6rem)"
    fontWeight: 600
    lineHeight: 0.93
    letterSpacing: "-0.015em"
  headline:
    fontFamily: '"Barlow Condensed", Arial, sans-serif'
    fontSize: "clamp(2.65rem, 4.8vw, 4.8rem)"
    fontWeight: 600
    lineHeight: 1.03
    letterSpacing: "-0.015em"
  title:
    fontFamily: '"Barlow Condensed", Arial, sans-serif'
    fontSize: "1.8rem"
    fontWeight: 600
    lineHeight: 1.15
  body:
    fontFamily: "Arial, Helvetica, sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.65
  button-label:
    fontFamily: "Arial, Helvetica, sans-serif"
    fontSize: "0.9375rem"
    fontWeight: 700
    lineHeight: 1.4
  navigation-label:
    fontFamily: "Arial, Helvetica, sans-serif"
    fontSize: "0.875rem"
    fontWeight: 700
    lineHeight: 1.65
  mission-label:
    fontFamily: '"Barlow Condensed", Arial, sans-serif'
    fontSize: "1.45rem"
    fontWeight: 400
    lineHeight: 1.2
rounded:
  control: "4px"
  gallery-image: "6px"
  comparison-frame: "8px"
  brand-icon: "9px"
spacing:
  option-gap: "6px"
  action-gap: "12px"
  caption-gap: "16px"
  mobile-gutter: "20px"
  compact-grid-gap: "24px"
  gallery-row-gap: "28px"
  navigation-gap: "30px"
  grid-gap: "36px"
  heading-gap: "50px"
  desktop-gutter: "56px"
components:
  button-primary:
    backgroundColor: "{colors.yellow}"
    textColor: "{colors.ink}"
    typography: "{typography.button-label}"
    rounded: "{rounded.control}"
    padding: "13px 23px"
  button-primary-hover:
    backgroundColor: "{colors.primary-hover}"
    textColor: "{colors.ink}"
  button-outline:
    textColor: "{colors.paper}"
    typography: "{typography.button-label}"
    rounded: "{rounded.control}"
    padding: "13px 23px"
  button-outline-hover:
    backgroundColor: "{colors.surface}"
  mode-option:
    textColor: "{colors.paper}"
    typography: "{typography.navigation-label}"
    rounded: "{rounded.control}"
    padding: "8px 12px"
  mode-option-selected:
    backgroundColor: "{colors.orange}"
    textColor: "{colors.ink}"
  mission-link:
    textColor: "{colors.map-ink}"
    typography: "{typography.mission-label}"
    padding: "12px 14px"
  mission-link-selected:
    backgroundColor: "{colors.map-accent}"
    textColor: "{colors.paper}"
  navigation-link:
    textColor: "{colors.paper}"
    typography: "{typography.navigation-label}"
    padding: "8px 0"
  navigation-action:
    textColor: "{colors.paper}"
    typography: "{typography.navigation-label}"
    rounded: "{rounded.control}"
    padding: "10px 18px"
---

# Design System: Abrams project webpage

## Overview

**Creative North Star: "The remastered game box"**

This child website takes its visual authority from the approved remastered cover, game screenshots and restored manual maps. Upright condensed titles, cream text and hot accents give the dark sections the presence of a game box; the map section changes to ivory and olive for close reading.

The presentation is spacious around large artwork and compact around interactive choices. The metaphor describes the implemented site. It does not prescribe the parent Godot game or establish a persistent stack or workflow preference.

**Key Characteristics:**
- Approved artwork carries the identity.
- Barlow Condensed titles sit above clear Arial body copy.
- Dark exhibit surfaces alternate with a light map-reading surface.
- Rectangular controls show selection through color and visible focus.

## Colors

The box-art yellow and flame orange warm a near-black, olive-tinted ground; restored-map ivory provides a distinct reading surface. Frontmatter owns the exact values.

### Primary
- **Box-art yellow** (`yellow`): primary actions, platform strip, selection and dark-surface focus outlines.
- **Flame orange** (`orange`): Fan Remaster subtitle and selected graphics mode.

### Secondary
- **Map rust** (`map-accent`): current mission, map feedback and focus on the ivory surface.

### Neutral
- **Near-black ink** (`ink`) and **olive charcoal** (`surface`): page background and the raised tonal band used for credits.
- **Warm cream** (`paper`), **muted sage** (`muted`) and **olive divider** (`line`): reading hierarchy and separation on dark sections.
- **Map ivory** (`map-paper`), **map ink** (`map-ink`) and **map-muted**: the map section's paper, primary text and supporting copy.
- Border and hover entries describe the existing controls; they are not a generated tonal scale.

## Typography

Self-hosted Barlow Condensed Semibold supplies display headings, section headings and compact descriptive titles. Arial, with Helvetica and sans-serif fallbacks, supplies paragraphs, buttons and main navigation. The font file has weight 600; some display-family labels inherit normal weight in the current CSS.

The frontmatter records the base hierarchy. The hero subtitle uses 0.56em of the title, orange and expanded tracking. Supporting text ranges from 0.8125rem captions to a 1.05rem hero description. The hero description is limited to 43ch; installation prose uses 49ch at desktop and up to 65ch in the narrower layout.

Responsive display sizing follows the existing breakpoints: the hero reaches 4.2rem with 0.95 line height at 520px and below, then 3.65rem at 360px and below. Section headings become 3.1rem in the small layout. No modular type ratio is established.

## Layout

A centered shell has a 1280px maximum width and 56px desktop gutters. Gutters narrow to 36px at 1100px, 20px at 800px and 16px at 360px. The header has its own 1550px maximum width.

The hero uses a 1.12:1 text/art grid. Comparison uses 1.85:1; missions use 1:1.42; installation uses equal columns. At 800px the comparison, mission and installation grids become single-column, while the mission sidebar briefly uses two columns. At 520px the hero and screenshot gallery also become single-column, and mission choices form a two-column grid. The main navigation wraps visibly onto its own row at 800px, with no hidden-menu dependency.

Section spacing is intentionally generous and varies by content, with desktop section padding approximately 72px to 108px and small-screen sections generally 54px. These are observed compositions, not a new universal spacing scale. The frontmatter captures recurring gaps and gutters only.

## Elevation & Depth

Artwork and tonal bands provide most depth. Only the cover has a substantial cast shadow, giving the intact box art physical presence; controls and content groupings remain flat. The sidecar records the exact cover shadow.

The cover settles once over 1.15 seconds, using the custom ease, from a 14px vertical offset and three-degree rotation to two degrees. Mobile disables that animation and uses a one-degree tilt. Reduced motion disables animations, transitions and smooth scrolling; its final cover tilt is two degrees. Control color changes use 0.18-second ease transitions where declared. No looping or scroll-triggered reveal is present.

## Shapes

Controls use a small corner radius. Screenshot frames are slightly softer, with separate gallery-image and comparison-frame radii, while the square brand icon has the largest documented radius. Thin borders separate navigation choices, feature descriptions and credits. The cover remains a complete rectangular image. There is no reusable card shell in this implementation.

## Components

### Buttons

Primary actions use yellow with ink text. The outline variant uses cream text and an olive border on the dark ground. Both have a minimum height of 48px, centered bold labels and the frontmatter padding. Primary hover lightens the yellow; outline hover adds the surface fill and cream border. Focus uses a three-pixel yellow outline offset by five pixels.

### Graphics mode radio labels

Three native, visually clipped radios control the EGA, Genesis and Upscaled choices. Their labels have a minimum height of 46px and an olive border; selection fills the label orange with ink text. Unselected hover uses the surface fill. A focused radio outlines its label in yellow with a four-pixel offset. Checked styling takes precedence over hover.

### Mission links

The mission selector uses real image links, with the currently displayed mission marked by `aria-current`. Rust fill and cream text identify selection; unselected hover uses the map-hover neutral. Desktop rows are separated by thin rules. At 520px and below, each link becomes a rounded, bordered grid choice with a minimum height of 54px. Focus uses map rust on the light ground. Selected styling takes precedence over hover.

### Navigation

The main navigation uses bold Arial, plain text links and one bordered alpha action. Hover turns links yellow; keyboard focus retains the common yellow outline. It stays visible and wraps on narrow screens. No persistent active-navigation style is implemented.

## Do's and Don'ts

### Do
- Do preserve complete cover lettering and the proportions of screenshots and maps. Working if: the supplied title remains visible, station images remain 4:3 and maps remain square.
- Do keep display headings in Barlow Condensed and reading copy in Arial. Working if: computed typography follows the documented roles.
- Do retain visible keyboard focus, native radio selection and reduced-motion behavior. Working if: keyboard users can locate and operate each gallery control, and reduced-motion mode disables the cover animation and transitions.

### Don't
- Don't crop approved artwork into decorative fragments. Working if: the cover, instruments and map legends remain readable in their full compositions.
- Don't substitute generic dashboard cards or military-interface decoration for the artwork-led exhibit. Working if: screenshots and maps remain the visual evidence, with controls limited to their actual functions.
