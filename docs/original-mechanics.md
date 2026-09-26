# Original mechanics ledger

## Evidence boundary

Source: supplied `Abrams-Battle-Tank_Manual_DOS_EN.pdf`, 48 scanned PDF pages. Page references below use the manual's **printed page numbers**; PDF page = printed page + 4. `reference/manual-pages/scan-NNN.jpg` uses zero-based PDF image order, so printed p4 is scan-007.jpg. Local OCR is `reference/manual-text.txt`; the preserved embedded-image OCR is `reference/manual-pages/embedded-scan-ocr.txt`. OCR is a search aid and contains errors. The controls, operating rules, ammunition, mission objectives and M1A1 table below were read visually in the extracted page images. `pdftotext -layout` produced no meaningful text; `pdfimages -j` extracted the original scans and Tesseract supplied searchable text. A subset is also rendered with Poppler.

**Manual fact** means documented behavior, not proof of how the executable implements it. **Unresolved** means executable traces, data decoding or disassembly are required before claiming faithful parity. The manual itself warns that its mission maps are rough sketches, not authoritative geography or enemy activity (p23). This ledger establishes finite acceptance questions, not completion of a reconstruction.

## Controls and stations

| Surface | Manual facts | Source |
|---|---|---|
| Station selection | F1 gunner, F2 tank commander, F3 cupola, F4 driver. Gunner is initial station when entering the tank. | pp4,6,16 |
| Gunner | A align turret; C toggle hull/turret control; L lock selected target; M fire machine gun; R radio; S smoke; T thermal; Z cycles 1x/3x/10x; 1 HEAT, 2 SABOT, 3 AX; Enter target; Space fire. | pp5,17 |
| Commander | A/C/R/T as above; D damage screen; Z close-up/whole-area map; F7 current turret bearing, F8 bearing+90 degrees, F9 +180, F10 +270. Scan is view-only, without rotating turret or hull. | pp5,13,19 |
| Cupola | Listed commands A and C; elevated outside view especially useful for aircraft spotting. Turret movement explicitly available, no tank icon. | pp6,13,19 |
| Driver | Listed commands A and C; heading, speed, fuel, temperature indicators. Turret movement explicitly available, no tank icon. | pp6,13,20 |
| Loader | Automatic loading; no playable station screen. | p20 |
| Hull movement | Up/keypad8 forward, down/keypad2 reverse, left/keypad4 left, right/keypad6 right. p12 explicitly names F1/F2/F4 as hull-driving stations. | pp7,12 |
| Turret movement | Up raises sight, down lowers; left/right rotate turret. Available at all four stations. | pp7,13 |
| Stop | Keypad5 stops hull or turret movement. p12 describes it as stopping all movement. Exact cross-mode stopping behavior unresolved. | pp7,12 |
| Pause | Esc pauses scenario; any key resumes. In menus Esc backs out. | p7 |
| Quit | Q opens quit choices; Continue the Battle cancels, Quit Anyway or Abandon the M1 confirms. | pp6,10-11 |
| Sound/simulation speed | F5 sound toggle; Shift+3 cycles slow/medium/fast system speed, default fast. Timing multipliers unresolved. | p6 |
| Joystick | Fore/aft and left/right move; one button stops, other fires. Button identities and analog mapping unresolved. | p7 |

The station command lists are a conservative documented capability boundary. They do not prove that every unlisted key is ignored in the DOS executable. In particular, hull driving from cupola needs an observed test: p12 excludes it while p6 exposes C there.

## Movement, engine and supplies

| ID | Manual fact | Source | Remaining parity question |
|---|---|---|---|
| MOV-01 | Holding left/right initiates spin; longer holding makes spin faster. Up/down stops spin and moves forward/backward. | p12 | Acceleration, turn-rate curve, inertia, key repeat and simultaneous inputs. |
| MOV-02 | Heading is hull direction, bearing is turret direction; north0/east90/south180/west270. Tank mode controls hull/turret as a unit; turret mode changes bearing without heading. A aligns turret with hull front. | pp12-13,16-17 | Rotation coupling with existing turret offset, alignment duration and elevation reset. |
| MOV-03 | Governor on limits speed to about72km/h; off about100km/h. Off-road maximum is lower. | pp14,17 | Reverse speed, terrain coefficients, slope, collision, road detection, acceleration/braking. |
| MOV-04 | Ungoverned overheating slows tank, continued strain burns engine and stalls irrecoverably. Governor setting can change at base. | p14 | Heat gain/cooling, thresholds, speed penalty, default governor state. |
| SUP-01 | Fuel capacity100 gallons. Refuel/rearm by returning to base, unlimited visits; rearming also refuels. Each mission starts near a base and has at least one. | pp14,19 | Base proximity trigger, servicing delay, damage repair, exact fuel consumption. |
| SUP-02 | Fuel depletion immobilizes tank. p14 calls the command over, while p19 says player must wait for enemy attack. | pp14,19 | Immediate failure versus immobility until destruction is unresolved. |
| SUP-03 | Motor Pool offers ammo mix and governor selection; keypad4/6 changes mix. | pp7,9-11 | Initial allocation, total-capacity accounting, AX slot cost, smoke inventory, UI constraints. |
| SUP-04 | Vehicle table lists40 cannon rounds,80 MG rounds and nominal4-second reload for M1A1. | p33 | Runtime confirmation; table does not specify each ammunition type and AX is explicitly slower. |

## Weapons and targeting

| Weapon | Manual effectiveness and range | Source |
|---|---|---|
| SABOT | Very effective armor; ineffective infantry, constructions and aircraft; up to2500m. | p20 |
| HEAT | Very effective infantry/constructions, effective armor, ineffective aircraft; up to2000m. | p20 |
| AX | Very effective aircraft; somewhat effective armor/infantry/constructions, especially at extended range;770-4000m. Large size/wire guidance makes loading slower. | p21 |
| COAX | Mildly effective infantry/very light armor; marginally effective to ineffective aircraft;0-1000m. Quick reload independent of main rounds. | p21 |
| Cannon |120mm Rheinmetall, fires SABOT/HEAT/AX; effectiveness depends on round. | p21 |
| Smoke | Conceals from enemies without thermal, defensive against sight-guided Spigot/Sagger; about20seconds, up to100m. | p21 |

The M1A1 table's generic2250m range (p33) differs from round-specific ranges. Preserve both as source facts; do not silently substitute2250m as a universal cannon cutoff. Glossary p41 describes SABOT1600m/s and HEAT900m/s, but these are background ballistic claims and require executable confirmation before use as simulation constants.

- **TGT-01:** Enter activates TADS and cycles through onscreen targets, then switches the box off after the last. Trees, mountains and own base cannot be targeted (pp14,17).
- **TGT-02:** L centers the sight on the selected TADS box. Target readout gives identity, range and selected weapon/loading status, including guided-weapon in-flight tracking status (pp14,18).
- **TGT-03:** EGA range readout probability bands: grey less than25%; green less than50%; yellow greater than50%; red greater than75% (p18). Exact boundaries at25/50/75 and the probability formula are unspecified.
- **TGT-04:** Thermal view operates through smoke and darkness and uses red/black, or monochrome shades on Hercules (p17).
- **TGT-05:** Normal/medium/long optical zoom is1x/3x/10x (pp5,17). Field of view, projection and detection distance are unspecified.
- **TGT-06:** Radio sounds a Morse-like notification; R retrieves conditions messages and does nothing with no pending message (p14).
- **TGT-07:** Incoming hit supplies attacker bearing (p23). Display lifetime/precision and source selection unresolved.
- **TGT-08:** Tactics state HEAT/AX return fire can disrupt missile guidance, SABOT cannot; movement reduces chance of being hit; frontal facing and attacking enemy rear/flank are recommended (p22). Exact damage/accuracy implementation unresolved.

Required runtime experiments: target ordering and offscreen eligibility, occlusion, lock persistence and moving-target tracking, fire without lock, minimum-range enforcement, projectile flight timing, guided tracking interruption, reload cancellation on ammunition switch, MG burst count, smoke geometry and enemy thermal exemptions, difficulty accuracy effects, friendly fire and score penalties.

## Instruments, damage and rendering contract

- Gunner view faces turret bearing, with bearing across top; tank icon sits on a moving north-up grid, showing hull/turret orientation and mode (p16).
- Commander has multiview periscope, overhead map, speed/fuel gauges, tank icon and miniature damage screen; D expands damage and any key returns (pp18-19).
- EGA mode icon: tank control white hull/grey turret; turret control grey hull/white turret (pp13,16).
- Armor condition EGA: green okay, yellow severely damaged, red destroyed. A further hit in an armor-destroyed region may destroy the tank (pp16-17).
- Engine temperature EGA: green normal, yellow hot, red overheating; overheating additionally blinks (p17).
- Systems EGA: green fully operational, yellow partial, red nonoperational (p19).
- CGA/Hercules alternate color coding appears in printed tables. They are distinct display modes, not verified by an EGA-only reconstruction (pp13,16-19).
- Exact armor regions, penetration, subsystem list and failure effects, repair, crew casualties, hit location, impact angle, HUD pixel layout, scan timing, sound synthesis and palette indices require executable/resource evidence.

## Menu, scenario and campaign rules

- Eight scenarios, each with a mission goal; playable separately or as campaign. Scenarios have no time limit (p8). This does not exclude timed movement of mission actors.
- Main menu: Scenario, Campaign, M1-Info, Exit (p9). M1-Info presents crew, ammo and armament information (pp11-12).
- Scenario settings: mission; day/night; Novice/Moderate/Expert. Higher difficulty reduces shooting ease, makes movement/angle matter, brings more/tougher enemies and makes a good score harder (p10).
- Begin sequence: mission title, Space to continue, Colonel Wilson briefing, Motor Pool ammo/governor selection (p10).
- Original startup includes a vehicle-identification check once per boot, using manual vehicle information; wrong response returns to menu (p10). A reconstruction must explicitly decide whether this historic interaction is included; the ledger does not require bypassing it.
- Scenarios finish on objective success, death or confirmed quit; individual scenarios are not saved. Wilson review then summary; score0-500 based on kills/objective completion (p10).
- Campaign plays all eight scenarios with settings decided by the game. Name up to8 characters. Continue resumes existing campaign; Review shows completed count as Days minus1 (pp10-11).
- Campaign rating0-100 is a rough average of scenario scores; ranks run from Warrant Officer to Captain. Exact rank thresholds and normalization unresolved (p11).
- Mid-mission quit marks that mission over. After review, Take R+R saves/returns to menu; Continue proceeds. Campaigns autosave and can be erased via Review (p11).
- Exact mission ordering/randomization, save format, scoring weights, failure progression, medals/ranks beyond endpoints and all dialogue strings require original data/runtime evidence.

## Eight mission contracts

These are documented goals, with original spelling preserved. Map sketches establish a rough spatial brief only. All exact routes, actor counts except explicit counts, spawn coordinates, triggers, timing and victory/failure predicates remain unresolved.

| Mission | Primary documented objective | Secondary/conditions | Source |
|---|---|---|---|
| The Mossel Defense | Survive and destroy all attacking Soviet vehicles. | Waves approach the Mossel crossing/player position. | pp23-24 |
| Siegen Infiltration | Locate and destroy Soviet base or bases. | Rumor one or two; hilly terrain, reported Hind presence. Count needs runtime confirmation. | p24 |
| Nuremberg Highway | Clear Soviet forces along highway, reopen supply route to stranded Allied base. | Heavy ATGW activity in hills by road. | p24 |
| Mass Destruction | Destroy three enemy bases in vicinity. | Near Emes River; enemy approaches from north/west. | p25 |
| The Road to Bonn | Destroy Mainz bridge. | Destroy as much Soviet reconnaissance team as possible. | pp25-26 |
| Hannover Push | Destroy Soviet base near Hannover. | Locate/eliminate communications fort near base, described east of it. | p26 |
| Convoy | Escort/guard five trucks until arrival at Allied Weller base across Rhine. | Protect the trucks; permitted losses and exact success threshold unspecified. | p27 |
| The Mossel Intercept | Find downed Allied vehicles before Soviet patrol arrives, escort them to own base. | Patrol moves south along Mossel; casualty count unspecified. | pp27-28 |

## Vehicle reference versus executable behavior

The manual's vehicle chapter (pp28-38) contains recognition silhouettes, real-world descriptive claims and game-like speed/ammo/reload/range/threat tables. These are reference inputs, not an executable data format. Candidate roster from OCR: ACRV-2, BMP-1, BMP-2, BRDM-2, BRDM-3, BTR, FST, M113, M1A1, M2 Bradley, M60A3, Mi-24 Hind, T-62, T-64, T-72, T-80. Names other than M1A1/M113 and mission-mentioned Hind await visual table audit before entering production identifiers.

M1A1 p33 visually checked: length7.91m, width3.65m, height2.37m, mass63tons;72km/h;120mm cannon40rounds;7.62mm MG80rounds;4-second reload;2250m range;very heavy Chobham armor. Geometry dimensions describe the reference vehicle and do not prove the polygon model's scale.

## Finite parity completion matrix

| Lane | Evidence required to close |
|---|---|
| Input/stations | Recorded DOS tests for every listed key, station restrictions, release/hold behavior and mode coupling. |
| Movement/engine | Controlled road/off-road acceleration, braking, turn, reverse, heat/fuel traces at known system speed. |
| Combat | Per-weapon timing/range/target-class trials; extracted or traced damage, hit probability, guidance and smoke rules. |
| Missions | Decoded maps/routes/spawns/triggers plus start-to-end success and failure traces for all eight. |
| Presentation | Resource provenance, palette/font/model decoding, matched station screenshots and audio comparisons. |
| Campaign | Original progression, scoring/rank/save traces and corresponding reconstruction tests. |

No lane is closed by this manual inspection alone. Any reconstruction constant without evidence from this ledger or original executable/resources must be labeled provisional in implementation or test documentation.
