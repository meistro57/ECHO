# ECHO Save File Schema

World state saves are local, human-readable JSON files.

## Envelope

```json
{
	"schema_version": 1,
	"world_id": "echo_test_room",
	"saved_at_unix": 0.0,
	"session_id": "sess_...",
	"entities": [],
	"world_flags": {}
}
```

| Field | Type | Meaning |
| --- | --- | --- |
| `schema_version` | int | Current version is `1`. Newer versions are rejected. |
| `world_id` | string | Identifies the world the save belongs to. Mismatched saves are rejected. |
| `saved_at_unix` | float | Unix timestamp of the save. |
| `session_id` | string | ECHO session at save time (shared with MemoryService). |
| `entities` | array | Serialized `WorldStateRecord` dictionaries. |
| `world_flags` | dict | Validated allowlisted flags. |

## Entity record

```json
{
	"persistent_id": "red_box",
	"entity_type": "portable_object",
	"transform": {
		"basis_x": [1, 0, 0],
		"basis_y": [0, 1, 0],
		"basis_z": [0, 0, 1],
		"origin": [3, 0.5, 2]
	},
	"linear_velocity": [0, 0, 0],
	"angular_velocity": [0, 0, 0],
	"sleeping": false,
	"physics_mode": "static",
	"held_by": "",
	"parent_persistent_id": "",
	"custom_state": {},
	"saved_at_unix": 0.0
}
```

| Field | Meaning |
| --- | --- |
| `persistent_id` | Stable entity ID (e.g. `red_box`), never an instance ID. |
| `entity_type` | Matches the registered entity type. Mismatches are rejected on load. |
| `transform` | Explicit `Transform3D`: basis rows + origin as float arrays. |
| `linear_velocity` / `angular_velocity` | Saved only when physics state persistence is enabled. |
| `sleeping` | Physics sleeping flag. |
| `physics_mode` | `static`, `rigid`, or `character`. |
| `held_by` | Holder ID (`apc`) when the object was carried at save time. |
| `parent_persistent_id` | Reserved for parent relationships. |
| `custom_state` | Entity-specific data (e.g. `collision_disabled`). |

## Never serialized

- Node references
- Scene paths
- RIDs
- Resources
- Perception snapshots
- Hidden reasoning
- API keys or environment variables
- Frame-by-frame position histories

## Transform validation

On load every transform must be:

- finite (no NaN, no infinity)
- within `ECHO_WORLD_BOUNDS` (`world_bounds_min` / `world_bounds_max`)

Invalid transforms fall back to the entity's default scene transform.
