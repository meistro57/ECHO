# ECHO Phase 7: Object Interaction Architecture

## 📦 Overview

Phase 7 introduces physical object manipulation to ECHO, allowing the Embodied AI Player Character (APC) to perceive, move to, pick up, carry, drop, and present portable objects (`RedBox`).

```
APCController (Root Orchestration)
   ├── InteractionController ──► Validates range (1.5m), line of sight, and state
   │         │
   │         ▼
   ├── CarrySocket ────────────► Reparents object & resets transform
   │         │
   │         ▼
   └── PortableObject ─────────► Holds metadata (object_id, is_held, holder_id)
```

---

## 🔒 Security & Object Authority Rules

1. **Sole Object Authority (`InteractionController`)**: No component other than `InteractionController` is permitted to attach objects to `CarrySocket`, toggle collision shapes, alter object transforms, or detach objects.
2. **No Arbitrary Node Teleportation**: `PICK_UP_OBJECT` fails safely if the target object is outside interaction range ($1.5\text{m}$) or obstructed by geometry.
3. **Identity Preservation**: Objects are never deleted or recreated during pickup or drop; node identity and memory references remain intact.

---

## 🎒 Portable Object Contract (`PortableObject`)

All interactive objects implement the `PortableObject` contract (`StaticBody3D`):

```gdscript
class_name PortableObject
extends StaticBody3D

@export var object_id: String = "red_box"
@export var display_name: String = "Red Box"
@export var category: String = "portable_object"
@export var is_portable: bool = true
@export var is_held: bool = false
@export var current_holder_id: String = ""
```

Required groups: `perceivable`, `portable_object`.

---

## ✋ Carry Socket (`CarriedObjectSocket`)

The `CarrySocket` is a `Node3D` attached to the APC torso at `(0, 0.4, -0.6)`:
- **Attachment**: Reparents the target object to `CarrySocket`, resets its local transform to `IDENTITY`, marks `is_held = true`, and disables object collision shapes so it does not collide with the APC body.
- **Detachment**: Reparents object back to the world root scene, restores collision shapes, and places it at the calculated surface position.

---

## 🎯 Pickup, Drop, and Give Procedures

### 1. `request_pick_up(target_id: String)`
- Validates object exists, is in range ($\le 1.5\text{m}$), is portable, and is not already held.
- Attaches object to `CarrySocket`.

### 2. `request_drop()`
- Performs a downward raycast in front of the APC (`1.0m` forward) to locate ground collision geometry.
- Detaches object cleanly at the ground surface point.

### 3. `request_give_to_player()`
- Validates proximity to human player ($\le 2.0\text{m}$).
- Places object safely on the floor in front of the player.
