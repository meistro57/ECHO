# ECHO Phase 7: Task Execution Architecture

## 📋 Overview

The `TaskController` manages sequential, multi-step tasks for the APC, enabling complex behaviors such as bringing an object to the human player (`BRING_OBJECT_TO_PLAYER`).

```
TaskRequest ("BRING_OBJECT_TO_PLAYER", "red_box")
       │
       ▼ (Trusted Step Expansion)
  Step 1: MOVE_TO_OBJECT ("red_box")
  Step 2: PICK_UP_OBJECT ("red_box")
  Step 3: FOLLOW_PLAYER ("human_player")
  Step 4: GIVE_OBJECT_TO_PLAYER ("human_player")
       │
       ▼ (Sequential Execution)
  TaskController ──► ActionController / InteractionController
```

---

## 🛡️ Trusted Task Expansion & AI Safety

1. **Model Step Injection Guard**: The AI provider communicates using the `submit_apc_task` tool (`task_type = "BRING_OBJECT_TO_PLAYER"`, `target_id = "red_box"`). The AI model **cannot** supply raw steps.
2. **Deterministic Step Generation**: ECHO expands validated task requests into trusted, immutable action sequences.
3. **Sequential Step Validation**: Each step must succeed before the `TaskController` advances to the next step. If any step fails (e.g. pickup blocked or range exceeded), the task stops immediately and reports `FAILED`.

---

## ⚙️ Supported Task Types

- `BRING_OBJECT_TO_PLAYER`:
  - Step 1: `MOVE_TO_OBJECT` (`red_box`)
  - Step 2: `PICK_UP_OBJECT` (`red_box`)
  - Step 3: `FOLLOW_PLAYER` (`human_player`, until within giving distance $2.0\text{m}$)
  - Step 4: `GIVE_OBJECT_TO_PLAYER` (`human_player`)

---

## 🎮 Deterministic Testing (F5)

Pressing **F5** (`test_bring_red_box`) directly invokes `task_controller.start_task(TaskRequest.new("BRING_OBJECT_TO_PLAYER", "red_box"))` without querying an AI provider, allowing full physical task pipeline testing in deterministic mode.
