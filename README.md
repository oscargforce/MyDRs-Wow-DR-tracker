# MyDRs

MyDRs is a lightweight World of Warcraft addon that tracks your own diminishing returns (DR) states in PvP. It is built for clarity in fast arena and battleground moments, with category icons, DR state text, cooldown swipes, and a dedicated immune glow effect.

## What It Tracks

- Stun
- Disorient
- Incapacitate
- Root
- Silence
- Knockback
- Disarm

DR window duration is 16 seconds.

## Rich Features

- Real-time DR detection from Loss of Control data.
- Option to set custom icons to your DR.
- Immediate icon display when a CC category is first applied.
- Immune state highlight with a custom animated glow effect.
- DR state labels on each icon:
  - 50%
  - IMM
- DR countdown starts when the active CC ends, so active control and DR window are visually separated.
- Icon sorting by first active time with stable order fallback.
- Drag-and-drop frame movement in test mode.
- Pixel nudging controls (arrow buttons) for exact frame placement.
- Full profile support via AceDB profiles.
- Adjustable icon size, spacing, font size, cooldown swipe alpha, and cooldown direction.
- Optional countdown numbers toggle.
- Optional icon growth direction toggle.
- Built-in animated test mode preview.

## Behavior Notes

- If a target is stunned twice while still under stun and reaches immunity, the stun icon can update to IMM immediately.
- The DR timer starts when that CC category is no longer active.

## Commands
 
- /mydrs - This opens the addon options panel.
- /mydrs test  - Toggles the test animation 