# WarlocksFriend

WarlocksFriend is a World of Warcraft 3.3.5 addon for Demonology Warlocks. It shows combat alerts for filler spell priority, curse choice, missing DoTs, expiring auras, and the Glyph of Life Tap spell power buff.

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
- Curse recommendation priority:
  - If the target does not have an external magic-vulnerability debuff: Curse of the Elements
  - If Curse of the Elements is covered by Earth and Moon, Ebon Plague, or another Warlock: Curse of Doom on bosses
  - If the target is a simple mob or player: Curse of Agony instead of Curse of Doom
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
- Configurable sounds for general alerts and expiration alerts.
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
  - When targeting any hostile mob
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
- Curse recommendation:
  - Auto, always Elements, always Doom, always Agony, or disabled
  - Use group scan
  - Treat another Warlock as assigned to Curse of the Elements
  - Prefer Curse of Agony on simple mobs
- Sounds:
  - General alert sound
  - Expiration alert sound
  - Presets, custom file paths, test buttons, and reset buttons
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
/wf mode mob
/wf mode target
/wf mode focus
```

Curse recommendation:

```text
/wf curse auto
/wf curse elements
/wf curse doom
/wf curse agony
/wf curse off
/wf curse groupscan on
/wf curse groupscan off
/wf curse warlock on
/wf curse warlock off
/wf curse agonymobs on
/wf curse agonymobs off
```

Sounds:

```text
/wf sound alert <preset|path>
/wf sound expire <preset|path>
/wf sound test alert
/wf sound test expire
/wf sound reset alert
/wf sound reset expire
```

Available sound presets:

```text
none
raidwarning
alarm3
levelup
wardrum
scourgehorn
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

## Activation Modes

WarlocksFriend can be configured to stay disabled, activate on any hostile target, activate only while targeting a boss, or activate only while a boss is set as focus.

Boss detection checks for a hostile unit with:

```text
UnitClassification(unit) == "worldboss"
```

or the Wrath-friendly fallback:

```text
UnitLevel(unit) == -1
```

## Notes

In normal Wrath gameplay, Incinerate is a direct damage spell rather than a target debuff. WarlocksFriend still includes an Incinerate expiration setting because some private servers may expose custom aura behavior. If no Incinerate aura exists on the target, that warning simply will not fire.

Curse recommendations use the current target's debuffs first. Group and raid scanning is a prediction layer for Balance Druids with Earth and Moon, Unholy Death Knights with Ebon Plaguebringer, and optionally another Warlock assigned to Curse of the Elements. Talent inspection is asynchronous in Wrath, so it may take a few seconds to learn nearby group members.

Custom sound paths should point to files the WoW client can load, for example:

```text
Interface\AddOns\WarlocksFriend\Sounds\my-alert.ogg
```

The addon does not cast spells or create protected action buttons. It only displays passive alerts.
