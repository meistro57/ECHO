# World State Recovery

## Recovery order

When the world state service starts (or is explicitly told to load), recovery follows a strict order:

1. **Active save** (`user://echo_world_state.json`) — validated for schema, world ID, and entity records.
2. **Backup save** (`user://echo_world_state.backup.json`) — used only when the active file is missing or invalid.
3. **Default scene state** — when no usable save exists, entities stay at their scene transforms.

A good backup is never overwritten by bad data: the backup is only replaced from the active file during a successful, validated save.

## Corruption handling

- Active file corrupt → service falls back to the backup, or to default scene state, and records a sanitized `last_error`.
- Backup also corrupt → default scene state; no crash.
- Temporary write fails or fails JSON validation → the active file is left untouched.
- Duplicate or empty `persistent_id` entries in a save are skipped and reported.

## Safe restoration

Before applying a saved transform the service validates:

- finite values (no NaN / infinity)
- world bounds
- entity type match
- floor presence (downward raycast)
- no overlap with walls, the crate, the APC, or the player (shape query)

If any check fails, the entity falls back to its default scene transform. A post-load verification pass re-checks every restored free entity one physics frame later and corrects invalid placements.

## Held-object restoration

- If the Red Box was held at save time (`held_by = "apc"`), the service attaches it to the APC's `CarrySocket` after all entity transforms are applied.
- The object is never restored as both attached and a free body.
- If the APC or CarrySocket is unavailable, the box is placed at its saved (validated) free transform instead.

## Reset world state

`reset_world_state()`:

- deletes the active save and the backup
- clears world flags
- detaches any held objects and restores registered entities to default transforms
- preserves APC memory (separate store)
- requires explicit confirmation

## Common failure scenarios

| Scenario | Result |
| --- | --- |
| Missing file | Clean start with default scene state |
| Corrupt active, valid backup | Load from backup |
| Corrupt active and backup | Default scene state |
| Wrong `world_id` | Rejected with sanitized error; nothing applied |
| Newer `schema_version` | Rejected; no migration attempted |
| Older `schema_version` | Rejected (no older version exists at v1) |
| Permission/write failure | `last_error` set; active file untouched |
| Persistence disabled | No reads, no writes; gameplay unaffected |
