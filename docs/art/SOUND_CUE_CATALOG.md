# Sound Cue Catalog

All cues: original, synthesized (`tools/synth_audio.py`), NOT_UPLOADED, NOT auditioned in-game. Every cue needs a visual fallback so sound-off play is equivalent. Trigger events are design intent; wiring status unverified.

| wav | Trigger event | Visual fallback (sound-off parity) |
|---|---|---|
| steal_suction | STEAL accepted within 18 studs | cyan capsule stream to hand + chicken lifts |
| lawball_throw_whoosh | THROW fired | lawball trail + hand recoil |
| gravity_well_hum (loop 2s) | PLANT well active (4 s), loop while alive | violet concentric rings pulsing |
| bank_boing | lawball/chicken hits wall or pylon, or impulse on chicken | squash/stretch on chicken + small spark |
| bot_telegraph_alert | Bot enters Telegraph (1.1 s) | rotating magenta chevrons + ground warning shape |
| rubberband_recover | Recovery Tether recall within 2.5 s | lawball retracts along a visible tether line; ring countdown |
| vault_swallow_victory | server-certified goal (scoredEventId) | vault arch flash (<3 Hz), chicken shrinks into vault, banner |
| miss_squeak | THROW misses (real miss) | chicken unmoved + "MISS" text + Recovery ring appears |
| ui_press | any button press (STEAL/THROW/PLANT/AGAIN) | button depress animation |
| blackout_powerdown | CUT POWER succeeds, 22 s blackout begins | smooth screen dim + drone cone shrinks (34 -> 13) |
| drone_alarm | OPEN ESCAPE gate opens (alarm) | magenta pulse ring on gate + drone speed-up trail |
| heist_escape_sting | player reaches exit with core | exit zone burst + banner |

Mixing notes (HYPOTHESIS): UI < gameplay < alarms; hum under 30% volume; ducking of hum on telegraph. Provide a master mute and sound-off test pass before release (NOT_RUN).
