# ART BIBLE: Impossible Carnival

STATUS: design spec. Nothing here has been seen in Studio, on a phone, or by a player. Timings marked HYPOTHESIS are untested.

## Style
"Impossible Carnival": a fairground built where physics is a rumor. Bright, flat-shaded, chunky Parts; gold, glow trim, and bold single-silhouette props against a dark-ish sky. Floating things, arches, rings, stripes. No realism, no gore. Everything is built from procedural Roblox Parts (no uploaded meshes yet).

## Design tokens
| Token | Hex | Meaning |
|---|---|---|
| cyan gravity | #33E0FF | gravity capsule, active gravity effects, STEAL |
| amber objective | #FFB020 | Vault, goal, core, anything you should go to |
| violet planted field | #9B5CFF | planted gravity well |
| magenta hostile | #FF2E88 | Rogue Law Bot, drone, alarm |
| neutral white/yellow | #FFF6C2 | accessibility high-contrast outline/fallback |

Color is never the only carrier of meaning (see shape grammar).

## Shape grammar
- Bot telegraph: rotating chevrons (magenta) above/around the bot, 1.1 s.
- Planted well: concentric rings (violet), radius 26 studs, 4 s.
- Vault: arch (amber), the only arch in the arena.
- Gravity capsule: glowing sphere/pill inside chicken chest (cyan).
- Drone vision: cone wedge on floor; lit 34 studs, blackout 13 studs; narrower cone shown during blackout.
- Lawball: sphere with a single ring band.

## Silhouette rules
- 32 px (tiny icon / far thumbnail): each hero object must be identifiable as one solid blob shape: chicken = round body + comb; vault = arch; bot = tall trapezoid with chevron crown; lawball = circle with band; drone = flat disc with wedge. No detail needed below 32 px; color + shape together.
- 120 px (thumbnail/mobile HUD scale): add one interior accent each (capsule glow, arch keystone, chevrons, ring band). Max 2 colors per object plus neutral outline.
- Test by blurring/desaturating: all five must still be distinguishable in grayscale. (NOT_RUN)

## Object specs
- Giant Golden Chicken: radius 6 studs (Config chickenRadius), amber-gold body, cyan capsule glow on chest, simple beak/comb, no face detail. Floats at hoverHeight 14 when stolen. Wobble when gravity active.
- Vault: box 22 x 12 studs (hx 11, hz 6) at z=52; arch frame amber with neutral outline; interior dark so chicken reads against it; idle pulse slow.
- Rogue Law Bot: radius 3.5 studs; magenta trim, dark body; chevrons rotate during telegraph; stunned = chevrons stop, body dims, stars/spin optional.
- Lawball: radius 1.5 studs; cyan core, white ring band; trail while flying; returns over 2.2 s.
- Drone: magenta disc, cone wedge; alarm = faster pulse + magenta flash ring (not full-screen).
- Arena (Sky Vault City): floating platform at platformY 6, pylons (2), carnival stripes; city (heist) = four 28x28 stud blocks.

## Animation timing hypotheses (HYPOTHESIS, untested)
- STEAL pull: 0.35 s ease-in; capsule streams to the player's hand.
- Throw: lawball travels 125 studs/s; trail 0.25 s.
- Bank/impulse on chicken: squash 0.12 s then recover 0.25 s.
- Bot telegraph: chevrons rotate 1 rev/s for the 1.1 s config window; the rotation must start on telegraph tick 0.
- Vault swallow: shrink to 0 over 0.3 s, confetti burst 0.5 s.
- Well: rings expand over 0.4 s, contract in last 0.5 s of the 4 s life.
- Recovery tether window: 2.5 s ring countdown around the lawball slot.

## Photosensitivity rules
- No flash more than 3 per second anywhere; no full-screen flashes; no red-saturated flashing.
- Max flashing area: small (well under 25% of view); prefer fade/scale over strobe.
- Blackout: dim via smooth 0.5 s ramp, never a hard cut.
- Alarm/telegraph use rotation/scale pulse at <= 2 Hz.
- Verify with a photosensitivity analysis tool before release (NOT_RUN).

## Reduced motion
- Setting disables screen shake, camera bob, particle bursts, trails; replaces with static icon + short fade.
- Telegraph chevrons remain (they are gameplay information) but rotate slowly or step instead of spin.
- Ring/chevron meaning preserved without motion.

## Quality tier table (Adaptive Reality Engine: Auto + Survival/Lite/Balanced/High/Ultra; decorative FX only)
| Scales with tier (decorative) | Never scales (gameplay) |
|---|---|
| particle count, trails, glow/bloom, ambient city props, confetti, shadows, decorative animation rate | hitboxes, radii, speeds, timings (telegraph, well, blackout), bot/drone AI, vault box, scoring/witness, telegraph chevrons visibility, well ring visibility, vault arch visibility, vision cone, HUD buttons |
Survival tier: gameplay-critical shapes remain; all decoration off. Tier selection never reads or writes server state.
