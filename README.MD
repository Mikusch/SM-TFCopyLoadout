# [TF2] Copy Player Loadouts

A SourceMod plugin that allows admins to copy other player's loadouts, whether for fun or testing purposes.

## Requirements

- [TF2 Utils](https://github.com/nosoop/SM-TFUtils)
- [TF2 Econ Data](https://github.com/nosoop/SM-TFEconData)

## Commands

### sm_copyloadout

```
sm_copyloadout <source> [target] [persist]
```

Copies the loadout of a source player onto the target player(s).

| Parameter | Description |
|-----------|-------------|
| `source` | The player whose loadout will be copied (required) |
| `target` | The player(s) to receive the loadout (optional, defaults to yourself) |
| `persist` | Set to `1` to copy the loadout on every spawn (optional, defaults to `0`) |

**Examples:**
- `sm_copyloadout Mikusch` - Copies the loadout of Mikusch onto yourself
- `sm_copyloadout Mikusch @bots` - Copies the loadout of Mikusch onto all bots
- `sm_copyloadout Mikusch @bots 1` - Copies the loadout of Mikusch onto all bots, persisting across respawns

### sm_copyloadout_clear

```
sm_copyloadout_clear [target]
```

Clears loadout persistence and regenerates the player back to their default loadout.

| Parameter | Description |
|-----------|-------------|
| `target` | The player(s) to clear (optional, defaults to yourself) |

**Examples:**
- `sm_copyloadout_clear` - Clears your own loadout persistence
- `sm_copyloadout_clear @bots` - Clears loadout persistence for all bots