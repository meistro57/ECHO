# ECHO Phase 8: Shared Attention Architecture

## 👁️ Overview

`PlayerAttention` tracks the human player's visual gaze and aiming vector in real-time, providing shared attention context so natural relative references (such as "that", "it", "this box") resolve seamlessly to physical objects in the 3D room.

---

## 🔬 Gaze Raycasting & Attention Snapshot

The `PlayerAttention` node performs a physics raycast from the player's first-person camera along the forward view vector:

```gdscript
func get_attention_snapshot() -> Dictionary:
	return {
		"aim_target_id": aim_target_id,        # e.g. "red_box"
		"aim_target_distance": aim_target_distance, # e.g. 3.4m
		"is_target_visible": is_target_visible,  # true / false
		"recent_target_id": recent_target_id    # retained for 3.0s after looking away
	}
```

### Reference Resolution Procedure
1. When the player says: *"Bring me that"*, `CommandGrounder` checks `attention_snapshot.aim_target_id`.
2. If `aim_target_id == "red_box"`, the command grounds instantly to `TaskRequest("BRING_OBJECT_TO_PLAYER", "red_box")`.
3. If no aim target is active and multiple objects exist in perception, the system requests one-turn clarification ("Which object do you mean?").
