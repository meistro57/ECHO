# Phase 10: World State Persistence

## Overview

Phase 10 persists selected world state across sessions without serializing the entire SceneTree. Only explicitly registered persistent entities and validated world facts are saved.

Primary proof: move the Red Box, exit, reload — the Red Box reappears at its saved position and orientation, with valid held, physics, and owner state.

## Architecture

```
Persistent entity changes
        ↓
WorldStateRegistry  (registered PersistentEntity components)
        ↓
WorldStateService   (capture, validate, serialize)
        ↓
validated WorldStateRecord
        ↓
JSONWorldStateStore (atomic save + backup)
```

Load flow:

```
JSONWorldStateStore → schema validation → WorldStateMigrator → entity lookup
        → safe state application → post-load verification → world_state_loaded
```

## Components

| File | Role |
| --- | --- |
| `world_state_service.gd` | Orchestration, env config, save/load/reset, autosave, dirty tracking |
| `world_state_registry.gd` | Register/unregister/lookup of `PersistentEntity` components, duplicate rejection |
| `world_state_record.gd` | Typed record with explicit transform serialization and finite-value validation |
| `persistent_entity.gd` | Reusable component attached to scene entities (`EXISTING_SCENE_ENTITY` policy) |
| `world_state_migrator.gd` | Schema versioning (current 1, rejects newer/older unknown versions) |
| `world_state_store.gd` | Store interface |
| `providers/json_world_state_store.gd` | Atomic JSON save with `.backup.json` retention |
| `providers/mock_world_state_store.gd` | In-memory test store |

## Initial persistent entities

- Red Box (`persistent_id = "red_box"`) — required, embedded in `red_box.tscn` via the `WorldState` component
- Optional APC position (`ECHO_SAVE_APC_POSITION`)
- Optional player position (`ECHO_SAVE_PLAYER_POSITION`)
- Validated world flags

Stable IDs are used (`red_box`), never runtime instance IDs.

## Storage

- Default path: `user://echo_world_state.json`
- Backup: `user://echo_world_state.backup.json`
- Configurable via `ECHO_WORLD_STATE_FILE`
- Never written to `res://`, never committed to the repository

## Save triggers

- Manual save: `F8` (HUD button "Save World (F8)"; F7 remains memory-clear)
- Save on clean exit (`NOTIFICATION_WM_CLOSE_REQUEST`)
- Optional autosave (`ECHO_WORLD_AUTOSAVE`, throttle `ECHO_WORLD_AUTOSAVE_DELAY_SECONDS`)

Autosave is triggered by dirty-state polling (transform/held changes) and by world-flag events (Red Box delivered, first command).

## World flags

Validated allowlist only:

- `tutorial_completed`
- `red_box_delivered_once`
- `first_voice_command_completed`

Arbitrary keys are rejected by `set_world_flag`.

## Reset world state

`reset_world_state()` deletes only world state (active + backup files), restores registered entities to their default scene transforms, detaches held objects, and clears world flags. APC memory is preserved. Requires confirmation (HUD button double-press or `F9` double-press).

## Configuration

| Variable | Default |
| --- | --- |
| `ECHO_WORLD_STATE_ENABLED` | `true` |
| `ECHO_WORLD_STATE_FILE` | `echo_world_state.json` |
| `ECHO_WORLD_ID` | `echo_test_room` |
| `ECHO_WORLD_AUTOSAVE` | `true` |
| `ECHO_WORLD_AUTOSAVE_DELAY_SECONDS` | `1.0` |
| `ECHO_SAVE_PLAYER_POSITION` | `false` |
| `ECHO_SAVE_APC_POSITION` | `false` |
| `ECHO_WORLD_BOUNDS` | `-9,0,-9,9,3,9` |

## Authority boundaries

No persistence logic is placed inside APCController, APCPerception, ActionController, InteractionController, TaskController, MemoryService, AI providers, or the HUD. The service reads state and applies it through existing public APIs (e.g., `CarriedObjectSocket.attach_object` for held restoration).
