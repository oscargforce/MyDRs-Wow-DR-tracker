# MyDRs (Oscar DR Tracker)

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
- Immediate icon display when a CC category is first applied.
- Immune state highlight with a custom animated glow effect.
- DR state labels on each icon:
  - 50%
  - IMM
- DR countdown starts when the active CC ends, so active control and DR window are visually separated.
- Duplicate root suppression for spells that also report a non-root control row.
- Spell-category override handling for special cases (example: Dragon's Breath, Blind, Cyclone).
- Filters out known non-DR Loss of Control events to reduce false positives.
- Icon sorting by first active time with stable order fallback.
- Drag-and-drop frame movement in test mode.
- Pixel nudging controls (arrow buttons) for exact frame placement.
- Full profile support via AceDB profiles.
- Adjustable icon size, spacing, font size, cooldown swipe alpha, and cooldown direction.
- Optional countdown numbers toggle.
- Optional icon growth direction toggle.
- Built-in animated test mode preview.

## Behavior Notes

- Icons represent DR category state, not only cooldown state.
- If a target is stunned twice while still under stun and reaches immunity, the stun icon can update to IMM immediately.
- The DR timer starts when that CC category is no longer active.

## Commands

- /mydrs

This opens the addon options panel.

## Installation

1. Place the MyDRs folder in your AddOns directory:
   World of Warcraft/_retail_/Interface/AddOns/
2. Restart WoW or run /reload.
3. Open options with /mydrs.

## Options Included

- Enable Test Mode
- Grow Icons From Left
- Reverse Cooldown Swipe
- Show Countdown Text
- Icon Size
- Icon Padding
- Font Size
- Cooldown Swipe Alpha
- Profile management

## Technical Summary

MyDRs uses:

- AceAddon-3.0
- AceEvent-3.0
- AceConsole-3.0
- AceDB-3.0
- AceConfig-3.0 and AceConfigDialog-3.0
- C_LossOfControl API

The core state model stores per-category activity, application count, active aura IDs, last seen start time, current stacks, and DR expiry.
