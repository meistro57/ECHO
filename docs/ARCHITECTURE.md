# ECHO System Architecture

## Overview

The ECHO architecture cleanly decouples perception, cognitive decision making, and physical action execution inside Godot 4.x (GDScript).

```
 ┌─────────────────────────────────────────────────────────┐
 │                       ECHO WORLD                        │
 │  (3D Environment, NavigationMesh, InteractiveObjects)   │
 └─────────────┬───────────────────────────────▲───────────┘
               │                               │
       Perception Scan                 Physical Execution
               │                               │
 ┌─────────────▼──────────┐         ┌──────────┴───────────┐
 │      APCPerception     │         │   ActionController   │
 └─────────────┬──────────┘         └──────────▲───────────┘
               │                               │
         Environment                     Legal Action
            Data                          Request
               │                               │
 ┌─────────────▼──────────┐         ┌──────────┴───────────┐
 │     MemoryService      │────────►│        APCBrain      │
 └────────────────────────┘         └──────────────────────┘
```

---

## Core Components

### 1. APCPerception (`scripts/apc/apc_perception.gd`) [Phase 3]
- Queries nodes in the `perceivable` group within vision radius.
- Filters by proximity, field of view, and line of sight raycasts.
- Returns a structured snapshot dictionary containing positions, states, distances, visibility, and entity identifiers.
- Short-term last-seen memory (`memory_duration` = 3.0s) retains positions after an entity leaves view.

### 2. MemoryService (`scripts/memory/memory_service.gd`) [Phase 9]
- Stores grounded, structured persistent memory (task outcomes, explicit player statements) in `user://echo_memory.json`.
- Query, forget, and recall flows are policy-validated; records are bounded, inspectable, and deletable.
- Separate from perception, conversation state, and world state persistence.

### 3. APCBrain (`scripts/apc/apc_brain.gd`) [Phase 4 / Phase 6]
- Evaluates the perception snapshot and produces a **structured legal action** (`ActionRequest`) or trusted task (`TaskRequest`).
- Dual modes: `DeterministicBrain` (rule-based) and `AIBrain` (provider-neutral AI with strict `AIDecisionAdapter` validation).
- Automatic deterministic fallback on any AI failure.

### 4. ActionController (`scripts/apc/action_controller.gd`) [Phase 4]
- Translates legal action requests into physical engine commands.
- Drives `CharacterBody3D` velocity via `NavigationAgent3D`.
- Owns locomotion, rotation, and wait/idle behaviour.

### 5. InteractionController & TaskController (`scripts/apc/interaction_controller.gd`, `scripts/apc/task_controller.gd`) [Phase 7]
- `InteractionController` is the sole authority for object pickup, carry-socket attachment, drop, and give.
- `TaskController` owns ordered multi-step execution of trusted tasks (`BRING_OBJECT_TO_PLAYER`).

### 6. PortableObject (`scripts/objects/portable_object.gd`) [Phase 7]
- Base contract for interactable portable items (`StaticBody3D`), e.g. `RedBox`.
- Exposes metadata for perception and methods for legal held-state changes.

### 7. WorldStateService (`scripts/world_state/world_state_service.gd`) [Phase 10]
- Persists selected world state across sessions without serializing the SceneTree.
- `WorldStateRegistry` tracks `PersistentEntity` components; `WorldStateRecord` serializes explicit transforms; `JSONWorldStateStore` performs atomic saves with a `.backup.json` fallback; `WorldStateMigrator` enforces schema versioning.
- Only registered entities (Red Box, optional APC/player positions) and validated world flags are saved.
- Restores transforms, held state, and physics through existing controller APIs after scene load, with bounds, floor, and collision validation.

### 8. Speech & Conversation (`scripts/audio/speech_service.gd`, `scripts/conversation/conversation_controller.gd`) [Phase 8]
- Push-to-talk capture, provider-neutral STT/TTS, typed command fallback, and subtitles/TTS responses.
- `CommandGrounder` maps transcripts to validated `ActionRequest` / `TaskRequest` / memory intents.
- `PlayerAttention` provides gaze-based shared attention for relative references.
