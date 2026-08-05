# ECHO Phase 8: Command Grounding Architecture

## 🎯 Overview

The `CommandGrounder` is responsible for parsing raw human natural language (spoken transcripts or typed text commands) and mapping them strictly into validated `ActionRequest` or `TaskRequest` structures.

---

## 🔍 Supported Spoken Commands

| Human Spoken Command | Grounded Output | Notes |
| --- | --- | --- |
| "Follow me", "Come here" | `ActionRequest(FOLLOW_PLAYER)` | Commands APC to follow human player |
| "Wait", "Stop" | `ActionRequest(WAIT)` | Commands APC to stop and wait |
| "Look at me" | `ActionRequest(LOOK_AT_PLAYER)` | Commands APC to face human player |
| "Look at the red box" | `ActionRequest(LOOK_AT_OBJECT)` | Target: `red_box` |
| "Go to the red box" | `ActionRequest(MOVE_TO_OBJECT)` | Target: `red_box` |
| "Bring me the red box" | `TaskRequest(BRING_OBJECT_TO_PLAYER)` | Expands into trusted multi-step task |
| "Pick up the red box" | `ActionRequest(PICK_UP_OBJECT)` | Target: `red_box` (validates range $\le 1.5\text{m}$) |
| "Drop the box", "Drop it" | `ActionRequest(DROP_HELD_OBJECT)` | Validates APC holds an object |
| "Give me the box" | `ActionRequest(GIVE_OBJECT_TO_PLAYER)` | Validates APC holds an object |
| "Cancel", "Cancel task" | Cancel Signal | Cancels active task & speech playback |

---

## 💬 One-Turn Clarification Flow

When a spoken command contains ambiguous entity references (e.g. "Bring me the box" when multiple boxes exist without an active gaze aim target):
1. `CommandGrounder` returns `needs_clarification = true` and `clarification_prompt = "Which object do you mean?"`.
2. `ConversationController` enters state `AWAITING_CLARIFICATION` ($15\text{s}$ timeout).
3. The APC speaks: "Which object do you mean?".
4. The user responds: "The red one".
5. `CommandGrounder` resolves target `red_box` and issues `TaskRequest("BRING_OBJECT_TO_PLAYER", "red_box")`.
