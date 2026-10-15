---
name: abrams-promo-planning
description: Plan and script an Abrams Battle Tank fan-remaster promo using source-grounded claims, consistent reference artwork and an animatic before paid video generation.
---

Use `tools/promo/brief.json` as the template brief for format, models, style and shots. Its `narration` is the superseded v1 script (`narration_status`): each production keeps its own approved script in `<production>/approved-script.json` (v3 and later) or `<production>/production-brief.json`, and that file is the one to voice, caption and check. Confirm aspect ratio, length and style before rendering; use the approved spending limit for paid calls. Paid calls also need `<production>/production-state.json` with `script_status: "approved"`. Read README.md and NOTICE.md for product claims and the original-game requirement.

Follow the approved voice direction for the production. Nell replaced the professorly direction with her own thrilling script, revised across cuts, and explicitly authorized an engaging delivery. Preserve its intentional short sentences. Keep acting direction separate from spoken words. Working if: the spoken script matches Nell's approved version and its delivery follows the current brief rather than a superseded style.

Make an animatic with source screenshots and the restored cover before generating motion shots. Keep reference identity consistent across keyframes and video. Preserve the complete 4:3 game display. Generated exterior shots are illustrative sequences, never evidence of in-game graphics or performance. Modern graphics remain experimental.

Use Hyperframes for HTML compositions, Motion Canvas when a procedural transition benefits the shot, Manim for geometric comparison graphics, OpenTimelineIO for the editorial timeline and FFmpeg for final encoding and mixing. Choose shot-specific contributions rather than duplicating entire scenes across renderers.

Creative Commons footage is optional. `yt-dlp` search results and platform licence labels are candidates, not rights proof. Before downloading for inclusion, record the uploader, exact source URL, licence version, attribution, provenance and permission for the intended promotional use. Omit uncertain material.

Working if: every spoken product claim has a source, the animatic precedes paid motion generation, and the final timeline distinguishes captured screens from illustrative footage.
