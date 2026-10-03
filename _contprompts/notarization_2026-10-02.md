# macOS notarization, 2 October 2026

## Authority and outcome

Nell's direct request, "Get it notarized please", releases the Apple-submission hold for the original-free Mac app, using the existing Abrams Keychain profile. No legal-agreement acceptance is authorized. A separate question asks permission to publish a new Mac release and update the site after acceptance; no answer yet. Audio stays off. Preserve previous apps and user profiles.

Working if: Apple returns Accepted, its log is reviewed, the app carries a validated stapled ticket, strict code-signature and Gatekeeper checks pass, and a final ZIP is created after stapling. An old public alpha is not automatically notarized by this work.

## Ready candidate

Fresh current-source Build 30: artifacts/notarization-20261002/M1 Abrams Battle Tank Fan Remaster.app. Signed build ID 24de2abd8009b2d8abad, unsigned build ID 2776843bcd8976586892. Developer ID Application: Nell Watson Ltd, team BBYYCBH7EW. All 87 signing targets use hardened runtime and secure timestamps; core executable text is unchanged. Full payload verification excludes raw PC/Genesis games and non-system external libraries. Frozen runtime status and the silent renderer version check pass.

Notary input: Abrams-0.1.0-alpha.4-macOS-arm64-notary-input.zip, 314301613 bytes, SHA256 997ce2ee6e0700badb66a0ff022dcbf4bb297005aa22dcd5311e15cb561625b3. The archive contains only the audited app and macOS resource metadata, never the separate imported-PC smoke profile. Corresponding GPL source is ready in Abrams-DOSBox-Pure-corresponding-source-macOS.tar.gz. Receipts and logs are local ignored artifacts in the same directory.

## Current blocker

Apple refused the first submission with HTTP 403: a required agreement is missing or expired. No submission ID or acceptance was returned; submission.json is empty. The account holder must review the outstanding agreement at https://developer.apple.com/account/ for Nell Watson Ltd before a new submission is justified. Do not accept legal terms or repeatedly retry unchanged credentials/account state. No notarization, stapling, public release or site update is complete.

## Package-check correction and process hold

Root incorrectly invoked the frozen runtime with --play --sanity-check. That flag is unsupported and is forwarded toward gameplay. The importer passed for a new isolated PC-only profile, but the extra package check is unaccepted and must not be reported as a passed renderer/bridge gate. At the last inspection the renderer was still in --headless --editor --import, with no guest or audio started.

Permission is requested to stop only helper PID 62904 and its renderer PID 63264. Before any signal, reverify both exact commands, ownership and start times to prevent PID-reuse errors. Stop the waiting helper first so it cannot advance into gameplay, then its exact renderer. No signal or other native/resource launch has been performed after this correction. COVENANT reports ART-first shared native validation is waiting; no other task was messaged because direct messaging authority has not been established.

## Signed-in account inspection

Nell replied "Signed in." The existing in-app Apple account tab confirms Nell Watson Ltd, team BBYYCBH7EW, Account Holder, renewal 12 February 2027. Its authoritative alert says the Apple Developer Program License Agreement has been updated and the latest agreement must be accepted to regain membership-resource access. Sign-in did not remove this blocker. Opening Review agreement did not visibly change the page; the hidden tab reports zero screenshot width, and opening it in Codex is queued. The tab is retained for handoff. No terms were accepted, no notarization retry was made, and the existing process-stop and publication permission questions remain unanswered.

## Later typography task and package disposition

Nell requested the irregular dialogue lettering be fixed across the game. Source now selects outline revision 4, SHA256 c45b765f6db77f7afb58297de6841106f2a234ef56171bbe1fa34c6a15531833. The already sealed Build 30 app and its notary input still contain v3. Preserve them as evidence; they are superseded for the next release. After Apple agreement clearance, assemble and sign a fresh current-source candidate before submission, subject to the shared native slot and adequate disk headroom. Do not falsely describe the earlier signed archive as containing the new fonts.

The fresh human GO in COVENANT thread 01a083a7-ddd6-7760-b699-02839469c6b0, user message 01a0fa2c-0217-7df2-9c7b-e0d2ecc990f0, was directly verified against its preceding exact two-process unblocker. Reverified helper62904/renderer63264 identities and start times, then sent SIGTERM only to helper, confirmed its exit, and sent SIGTERM only to renderer. The owning shell session ended143. Receipt: artifacts/notarization-20261002/package-check-stop.json. Last renderer readback showed parent1 and state ?E, command (AbramsRenderer), pending kernel exit; do not call the shared slot clear without a fresh confirming owner readback. No other process was signalled. Disk readback showed559304KiB available. No files were deleted and no new native renderer was launched.

Font revision 4 source gate is complete: 31 focused font/text tests pass; final clean-source CI passes 110 tests with seven skips. Current pack hashes and original hashes verified, old v3 rejected by the reported-stem regression, actual selected TTF previews inspected. Receipt: artifacts/pc-font-cohesion-20261002/receipt.json. Native Godot/runtime proof and a current-source signed app remain pending the shared native slot, disk headroom and Apple agreement clearance; no new publication occurred.

Latest independent resource readback: both approved-stop PIDs 62904 and 63264 are absent (targeted ps returned headers only, exit 1). Local df showed 7,000,000 KiB available, now above the reported strict native guard; this is a point-in-time observation, not admission. No native grant received. Own font study artifacts total 2,936 KiB, and sealed/notarization evidence remains preserved. No files deleted, signals sent, new native jobs or cross-thread messages. Receipt: artifacts/pc-font-cohesion-20261002/resource-readback.json.

Nell explicitly approved the discussed COVENANT native-slot coordination request with “CHECK, verify, proceed!”. Sent one bounded coordination message to thread 01a083a7-ddd6-7760-b699-02839469c6b0, requesting independent idle/lease verification and authoritative handback for the four silent font checks. This approves coordination for this target/purpose, not foreign process control, deletion, publication or notarization terms. Current native plan: artifacts/pc-font-cohesion-20261002/native-verification-plan.json.

Fresh slot 1b9e947c-4410-482f-ad8b-3e6e36e2ce4a admitted four silent native checks. Actual two-call result: typography PID60129 natural0, 3,597,634 checks, all four fonts/five scales plus exact dialogue pass; frontend PID62106 natural1, 8,148,994 checks, old office oracle misclassified source-verified map-frame border. Interior content difference is exactly zero; 211,792 changed pixels are outside [10,10,300,166]. Office proposal also omitted --text, so it was not an office-font acceptance run. Preserved old failure. Repaired only its scene-aware preservation oracle and prepared a new three-call plan with --text enabled, native-office-text-v4 output and menus/intro. Exact two PIDs absent, no retries/signals, authoritative handback hash9ca5f7154fe5742fc267d449505ee007fcd26a6eefcf862bf73f22173133366c. Native continuation needs a new grant; old grant cannot be reused.

Three-call continuation lease4440f7a7-0ef5-42d3-9161-d9071bbeb230 produced one actual child60386, natural1, before test initialization due untyped Variant-dependent map_frame declaration. Actual controller60384 and actual outer tool exit1 recorded. No remaining calls, retry or signals. Corrected only the local declaration to explicit bool, no production/font change. Old outputs/logs remain immutable. R2 plan/source-lock/recorder prepared with fresh office output native-office-text-v4-r2, requiring a fresh grant. All-font/five-scale PASS remains current.


R2 returned naturally with controller31071/children31450/33600 absent, no signals. Office with --text passed7,921,796checks, zero errors. Menus failed46,080,268checks with20 recorded errors; introUNRUN. Exact handback and terminal/output hashes are preserved at artifacts/pc-font-cohesion-20261002/native-continuation-r2-handback.json. COVENANT independently verified the return and owns the next PORT batch; no native/Blender launch admitted until its natural return.

Nell requested another original-typeface pass. Revision5 (manifest f5450780ff5161c57837fe758a5bc4d6fd90cbb3cb164d7b31fe464c10aac74d) restores actual lowercase source topology, instead of generic shared skeletons. Every source ink/blank centre and original extent is preserved. Current runtime and private packaging select v5; all older packs and signed builds remain unchanged. Native v5 proof and a current-source signed app remain outstanding. The menu oracle repair checks the complete glyph underlay without a cursor-mask exemption, then independently bounds the composited vector cursor. No publication, new Apple submission or legal acceptance occurred.


V5 source proof completed locally:21 focused tests pass,110 clean-source tests pass with7 skips, two new regressions reject v4, real TTF previews inspected, all76 locked native source inputs unchanged. Current source receipt: artifacts/pc-font-cohesion-20261002/v5-source-receipt.json. Native owner explicitly queued fresh four-call proposal behind ART/PORT and withheld admission. Native-v5-plan.json SHA f95bb93f23cd6de81e8c9d1eed8bd3957dd6e01759e67f19dbe174252026e498; source-lock aa9d721201c6e3d67ef673b540f72935cda1857cac8dffea396541f4c61aaff4; recorder9c0142d066879e96df9b8e69cf796d13ef2178f30cf80bf07dc8b352c9129acd. No native-v5 output exists. On fresh grant, authenticate it and all locked source pins, execute only its four serial commands with Dummy audio/offscreen renderer, require terminal/report/rendered acceptance, and hand back exact natural PIDs. Do not reuse previous grants, rebuild/publish on source proof alone, or claim native v5 acceptance from historical v4 passes.


## Current publication authorization and verified separation

Nell directly requested “Push everything live when done please”, then approved the current appearance with “Looks great, thank you”. This authorizes publication of the completed Abrams changes to NellInc/Abrams and abramsremastered.com, including refreshed original-free downloads once native checks pass. It does not authorize Apple legal-agreement acceptance or native starts without fresh shared-slot admission. No need to request the same publication approval again.

Fresh readback confirms origin/main at afa8b1101af15a115e7cc5657c66cdfab8281727. The dirty website paths are exact copies of its already-published V8 trailer patch, not unfinished changes; preserve them. The live HTTPS index SHA256 47a794533bd09f2ff60559f0ad2a9828c941dd9c7761f63e8eb38e1caa32e13a matches the local page. Current source-only safeguards and webpage workflows both completed successfully for that commit. Local website verifier and map tests pass. No new website publication is required for this already-live content.

The font source remains frozen: all76 native locked inputs match. Fresh four-call admission remains outstanding. COVENANT is active, with ART/native starts held behind other heavy/video jobs; two bounded coordination messages requested an explicit grant or blocking boundary. No grant, native v5 output, app rebuild, font publication or Apple submission occurred. Current branch and main have diverged, so integrate current main's published website/llms index without force pushing or overwriting it, and validate the integrated tree before publication. Preserve all earlier signed packages and failed native evidence.


## 3 October shared native ownership readback

COVENANT requested a genuine terminal/idle handback after reporting enginePID69881 and waiting Abrams lockf callers. Fresh escalated read-only inspection confirms enginePID69881, parentlockf67758, scheduler controller22371 and external Claude companion78853 (session2577d63d-353b-4729-ab40-29a0cfd172b6). The engine started03:29:38 local and remained present after24:53; eight other same-session lock callers wait. These are not unified_exec jobs started by this Codex root, and no attached app terminal is available. The controller output contains `rc= :: --script res://tests/test_pc_keyboard.gd`, with no numeric status, and no scheduler completion. No genuine terminal or idle handback exists yet. No starts, signals, debugger attachment or takeover were performed.

A bounded read-only diagnosis finds finite fixture work, including two shell-exit probes capped at5seconds. Native pipe reads at schedulingtest312-315 and bridge69-73 are an unverified blocking candidate, not a reproduced cause. The exact controller output, active/waiting identities and changed-source inventory are saved in artifacts/pc-font-cohesion-20261002/native-coordination-20261003.json.

Concurrent companion work changed22 of the76 previously locked native inputs. The old v5 source lock/plan cannot authorize a current run. Preserve its evidence; reconcile the concurrent edits, rerun affected source tests, and create a new immutable packet only after current authors finish. COVENANT has been told the actual ownership and absence of a handback. Do not claim the slot is idle because this root owns no new job.


## 3 October native occupancy returned

Fresh read-only exactps69881 and the entire former renderer/caller/controller list both returned1, headers only. A full untruncated args census with executable-name matching found no Godot, Blender, lockf or AbramsRenderer processes. The external companion78853 remains present as Claude, with no native child/caller from the inspected set. Point-in-time handback: artifacts/pc-font-cohesion-20261002/native-idle-handback-20261003.json. No starts, signals or restarts occurred in this root.

Retained external controller output now ends `[exited with code144]`, and still lacks numeric scheduler-child status or PC_LIVE_SCHEDULING acceptance. Preserve it as abnormal/unqualified, never a natural or passing result. Its exit cause remains unverified. The earlier permission request for renderer69881 is now moot; a late answer cannot justify signalling a reusedPID. COVENANT receives the genuine idle observation and must apply fresh guards for its separately approved batch. Font v5 stays unrun and its old source packet stays obsolete after concurrent edits.


## 3 October later capture coordination

COVENANT reported engine35667. Read-only identity confirms non-headless automated test_pc_conveniences --trace --capture, controller35663 from external companion78853/session2577d63d-353b-4729-ab40-29a0cfd172b6, started10:45:05 local with an existing900second alarm. Initial log reports null audio_menu get_menu_count at testline81; its report was absent. This root sent no signals or native starts and waited once through the existing deadline.

The old exact engine/controller became absent, but a first recording guard failed and correctly withheld the handback. Its reason was not printed. A follow-up timestamp-column awk selector was unqualified; it is superseded by a structured no-timestamp ucomm/args census and immutable observation: artifacts/pc-font-cohesion-20261002/native-conveniences-observation-20261003.json. Latest external controller output is unavailable, while the reused f038 output files changed to192checks with6errors and are archived. No actual child exit, natural return or PASS is proven for35667. The observation carries actual current residual jobs/hosts and point-in-time idle status. Requested next short sequence remains ART D6 oneCPU2 originalattachment save/reopen/sevenviews, then PORT. V5 remains held; COVENANT must apply fresh admission guards.


## 3 October post3 runner completion observation

The brief capture-return gap closed when external serial controller81120 started validate-all-post3.sh at11:04:46 local. Renderer83980 was one headless cockpit-mask-reuse check, and became absent while its controller continued; that individual return was not a slot handback. The controller later emitted VALIDATION_COMPLETE, with72PASS lines and noFAIL lines in its result file. Exact renderer/controller/outer-parent absence and fresh structured native/trace-host census are recorded in artifacts/pc-font-cohesion-20261002/native-post3-handback-20261003.json.

No actual aggregate outer exit code was obtained. One candidate output proved to be an unrelated audit and was excluded. The original capture35667 remains terminal-unqualified: its output path changed across192check/6error and208check/0error runs, so newer success cannot certify its return. This root launched/signalled/restarted nothing and holds v5. COVENANT must verify the receipt idle flag and fresh guards before its separate ART D6 CPU2 then PORT sequence; an observed gap is not a future-pause guarantee from the external companion.


## 3 October stable owner coordination required

COVENANT correctly refused D6 admission on newly active Abrams6976. Root later found thatPID absent, but does not issue another momentary idle grant: the independent companion continues launching work between checks. Identified its live owner as Claude78853, shell78256, ttys003, hosted by VS Code pty-helper2735. Installed CLI help exposes no direct foreground-session message command; --resume may create a copy, and was not used. No Codex app terminal is attached.

A direct Nell approval question now asks permission to queue a normal coordination message in the existing VS Code Abrams Claude terminal: finish active native work, then withhold new native starts for up to20minutes while queued ART D6 CPU2 and PORT run, with source work continuing. No interrupt or signal is proposed. Until an affirmative answer and a verified owner acknowledgement/terminal handback, no UI input, native starts or idle grant. Channel receipt: artifacts/pc-font-cohesion-20261002/native-owner-channel-20261003.json. Do not inject into /dev/ttys003, forge a transcript/inbox, resume/copy the agent, or control the interactive shell.
