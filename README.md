# WarlocksFriend

WarlocksFriend is a World of Warcraft 3.3.5 addon for Demonology Warlocks. It shows combat alerts for filler spell priority, missing DoTs, expiring auras, and the Glyph of Life Tap spell power buff.

## Requirements

- World of Warcraft 3.3.5 client
- Warlock character
- Metamorphosis talent learned

The addon stays silent for non-warlocks and for warlocks without Metamorphosis.

## Features

- Combat-only alerts.
- Filler recommendation priority:
  - Decimation active: Soul Fire
  - Molten Core active: Incinerate
  - Otherwise: Shadow Bolt
- Missing current-target debuff warnings:
  - Immolate
  - Corruption
- Missing player buff warning:
  - Life Tap spell power buff
- About-to-expire warnings with a separate sound:
  - Life Tap buff
  - Corruption debuff
  - Immolate debuff
  - Incinerate debuff, if the server exposes Incinerate as a target aura
- Movable or locked alert frame.
- Optional ElvUI integration when ElvUI is loaded.

## Settings

Open the addon settings from:

```text
Interface -> AddOns -> WarlocksFriend
```

Available settings:

- Lock alert frame
- Active mode:
  - Never
  - Only when targeting a boss
  - Only when a boss is on focus
- About-to-expire warning lead times:
  - Life Tap buff
  - Corruption debuff
  - Immolate debuff
  - Incinerate debuff
- Frame appearance:
  - Show background
  - Show border
  - Center text
- ElvUI integration, when available:
  - Use ElvUI style
  - Use ElvUI mover
  - Open ElvUI anchors

Settings are saved per character.

## Slash Commands

Main commands:

```text
/wf
/warlocksfriend
```

Options and status:

```text
/wf options
/wf status
```

Frame movement:

```text
/wf lock
/wf unlock
/wf resetpos
```

Activation mode:

```text
/wf mode never
/wf mode target
/wf mode focus
```

Expiration warning thresholds:

```text
/wf threshold lifetap <seconds>
/wf threshold corruption <seconds>
/wf threshold immolate <seconds>
/wf threshold incinerate <seconds>
```

Examples:

```text
/wf threshold lifetap 3
/wf threshold corruption 1.5
```

Frame appearance:

```text
/wf background on
/wf background off
/wf border on
/wf border off
/wf center on
/wf center off
```

Equivalent grouped style command:

```text
/wf style background on
/wf style border off
/wf style center on
```

ElvUI commands:

```text
/wf elvui style on
/wf elvui style off
/wf elvui mover on
/wf elvui mover off
/wf elvui anchors
```

## Boss Activation

WarlocksFriend can be configured to activate only for boss fights. Boss detection checks for a hostile unit with:

```text
UnitClassification(unit) == "worldboss"
```

or the Wrath-friendly fallback:

```text
UnitLevel(unit) == -1
```

## Notes

In normal Wrath gameplay, Incinerate is a direct damage spell rather than a target debuff. WarlocksFriend still includes an Incinerate expiration setting because some private servers may expose custom aura behavior. If no Incinerate aura exists on the target, that warning simply will not fire.

The addon does not cast spells or create protected action buttons. It only displays passive alerts.
