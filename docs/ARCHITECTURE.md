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
 │    PerceptionModule    │         │    ActionExecutor    │
 └─────────────┬──────────┘         └──────────▲───────────┘
               │                               │
         Environment                     Legal Action
            Data                          Request
               │                               │
 ┌─────────────▼──────────┐         ┌──────────┴───────────┐
 │      MemoryModule      │────────►│     BrainModule      │
 └────────────────────────┘         └──────────────────────┘
```

---

## Core Components

### 1. PerceptionModule (`scripts/perception_module.gd`)
- Queries nodes in the `perceivable` group within vision radius.
- Filters by proximity and line of sight.
- Returns a structured dictionary containing positions, states, distances, and entity identifiers.

### 2. MemoryModule (`scripts/memory_module.gd`)
- Stores recent perception history, conversation history, and past action results.
- Provides contextual summaries for decision making.

### 3. BrainModule (`scripts/brain_module.gd`)
- Evaluates user directives alongside perception snapshots and memory summaries.
- Produces a **Structured Legal Action** request (`MOVE`, `INTERACT`, `DROP`, `SPEAK`, `WAIT`, `STOP`).

### 4. ActionExecutor (`scripts/action_executor.gd`)
- Translates legal action requests into physical engine commands.
- Drives `CharacterBody3D` velocity via `NavigationAgent3D`.
- Executes object interactions through `InteractiveObject` methods without scene state hacking.

### 5. InteractiveObject (`scripts/interactive_object.gd`)
- Base class for interactable world items (`RigidBody3D` or `Area3D`).
- Exposes metadata for perception and methods for legal pickup and drop behavior.
