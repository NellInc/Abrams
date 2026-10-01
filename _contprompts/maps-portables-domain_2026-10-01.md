# NATO maps, public portable builds and custom domain

## Authority and outcomes

Nell's 2026-10-01 request authorizes all eight maps matching the approved second Mossel treatment, guide PDF map pairs, normal unmuted user-controlled site video with no separate trailer download link, public Windows/Linux builds, and Namecheap DNS connecting abramsremastered.com to GitHub Pages. Scoped source/site commits, pushes, native CI input upload/dispatch and fresh release publication are ordinary steps for these named targets. Original PC/Genesis games must remain excluded. Previous macOS signing/notarization hold remains. Local sound remains off.

Required proof: eight reviewed maps with provenance; final rendered 39-page PDF with eight landscape pairs; website static/rendered/native-video-property checks; fresh native Windows/Linux core/setup/About CI plus archive, runtime and GPL-source audits; public assets' served hashes; apex/www authoritative DNS, HTTPS and served Pages bytes. Native synthetic smoke does not prove real-game playtesting.

## Verified outcomes

All eight NATO-inspired maps are integrated in reference PNGs and website WebPs, with exact prompts and provenance. The 39-page guide pairs maps on landscape pages 4, 6, 8, 10, 12, 14, 16 and 18. Final PDF SHA256: d65d4990e20ee78c805a8466a76ae1f7c678f14a68ab27fb9494706c0966692d. All pairs and retained credits/vehicle layouts were rendered and reviewed. Root focused tests: 100 run, one skipped; isolated source kit: 110 run, seven skipped. Both passed.

Source freeze a2d59c110af84b7e1d1388ffa0715be93ff59276 produced the original-free alpha.4 input. Native build run 36897663383 passed on Windows 2022 and Ubuntu 22.04, including synthetic core, launcher/setup/About checks. Runtime manifests, native build receipts and corresponding GPL sources were audited. Public release https://github.com/NellInc/Abrams/releases/tag/v0.1.0-alpha.4 contains exactly two app ZIPs, two matching source TARs and SHA256SUMS.txt. Root anonymously downloaded and hash-verified all five assets. Native synthetic smoke does not prove a full mission with real PC files. Modal was unnecessary.

Website source commit dac97bd3f857063f1cd92e23f5fa713164d739b8 includes all maps, the paired guide, three platform downloads, custom-domain metadata and unmuted user-controlled trailer playback. No autoplay or separate MP4 link; native player download remains unrestricted. Desktop/mobile rendering and all eight selectors passed; local audio was not played. Four detector warnings were triaged as intentional existing styles. Publication used only scoped website changes in the protected managed release worktree. Main SHA f0f3ab10c7b1f40fa4d51c2af98fdd69a3daac53, Pages run 36903104314 and Source-only safeguards 36903104307 passed. All 45 public site files match reviewed bytes at GitHub's HTTP edge using explicit resolution. This verifies deployment bytes, not working public DNS or HTTPS.

Detailed receipts and logs: artifacts/release-20261001-portables/. PDF renders: artifacts/reference-20261001/. These are local ignored evidence, not release assets. Never publish private alpha.3, which retains CI build inputs. The source branch has unrelated game development absent from main; do not merge its whole history. Do not remove or unpin the managed website release worktree.

## Remaining domain gate

Pages cname is abramsremastered.com. Namecheap authoritative DNS confirms www CNAME nellinc.github.io. Both authoritative servers still return no apex A records. Replace the apex URL redirect with A records 185.199.108.153, 185.199.109.153, 185.199.110.153 and 185.199.111.153, preserving email forwarding, SPF, nameservers and unrelated records. Chrome was visibly in concurrent use and switching away during DNS edits. An availability question is pending: leave Advanced DNS untouched and pause other Chrome controllers briefly. No apex write has been attempted. Re-open fresh UI state after availability is confirmed.

After saving, verify both authoritative servers and recursive resolution, then GitHub's certificate and HTTPS enforcement, then served bytes through normal public HTTPS and the www redirect. Current https_enforced=false reflects the pending custom-domain certificate; do not claim the custom domain is live.

A proposed temporary fallback clearing the Pages cname was rejected by auto-review as outside the requested domain configuration. It was not executed. Do not retry, rephrase or indirectly clear it. A fallback would need explicit user approval because it removes the requested custom-domain setting. No unattended continuation is scheduled.

## Map-preloading follow-up

Nell requested background loading for the eight mission maps, explicitly answered "Publish the fix", and renewed the request to finish DNS/GitHub wiring. Source commit 5072d1720a13be0cd755762b182463c3798182aa and main publication d2416e76e64ee1bad47093f359784154dd2d228a preload/decode all eight maps at low priority and reuse their image nodes, including the initial map. Tests cover pending and repeated selections, late results, failure/retry and modified-click/direct-link fallbacks. Browser proof: eight completed background map requests, then eight correct selections with network offline and HTTP cache disabled, zero new map requests. Desktop/mobile have no horizontal overflow. Four existing detector warnings were retained because this change preserves the visual design. Evidence: artifacts/map-preload-20261001/.

Pages run 36928276160 and main safeguards 36928276180 passed. Served index and app.js match the reviewed main bytes at GitHub's HTTP edge. Concurrent main commits adding llms.txt were inspected and preserved through a fast-forward before the scoped cherry-pick; they are absent from the game source branch and must not be overwritten.

Namecheap was briefly reachable through native Chrome. Its existing apex redirect was opened for editing as an A record, and 185.199.108.153 is visible in the unsaved editor. Save activation did not produce a persisted record; both authoritative servers still returned no A answers. Chrome then switched away during the next fresh-state check, before any keyboard input was sent. Current availability question asks Nell to pause other Chrome controllers and leave Advanced DNS selected. No DNS completion or HTTPS acceptance is claimed. Reopen fresh UI state once Chrome is free; confirm form input/save through ordinary keyboard events and authoritative DNS before proceeding with the remaining three addresses. The earlier sentence about no apex write attempt describes the prior phase; this attempt remains uncommitted and unverified.

## Deviations

The guide retains each portrait briefing and replaces its following terrain-only page with a landscape map-pair page. This preserves prose, vehicle entries and the 39-page count. A new public portable release avoids exposing existing private draft inputs. Main needed the source branch's existing binary PDF classification in .gitattributes; raw hash and original-content checks remain enabled. A failed broad source cherry-pick into older main was aborted, then replaced with the scoped website-only publication.
