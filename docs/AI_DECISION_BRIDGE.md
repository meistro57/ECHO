# ECHO Phase 6: AI Decision Bridge Architecture

## 🛡️ Core Philosophy & Security Boundaries

Phase 6 connects the provider-neutral `AIService` (Phase 5) to the APC action pipeline, allowing configured LLMs to propose legal game actions through structured tool calls while preserving absolute engine security and deterministic gameplay fallback.

```
Perception (APCPerception)
       │
       ▼
   APCBrain ───────────────► Mode Selection (DETERMINISTIC / AI)
       │                                     │
       ├─────────────────┬───────────────────┘
       ▼                 ▼
DeterministicBrain    AIBrain ──► AIService ──► OpenRouter / DeepSeek
       │                 │                             │
       │                 ▼                             │
       │         AIDecisionAdapter ◄───────────────────┘
       │                 │
       │        (Strict Validation)
       │                 │
       └─────────────────┴──────────► ActionRequest
                                           │
                                           ▼
                                    ActionController
                                           │
                                           ▼
                                    CharacterBody3D
```

### 🛑 Security & Control Isolation Rules
1. **Zero Direct Scene Access**: The AI model **never** receives direct scene node references, `CharacterBody3D` access, `NavigationAgent3D` access, velocity vectors, or transform mutations.
2. **Action-Constrained Output**: The AI model communicates **exclusively** by calling the single registered tool `submit_apc_action`.
3. **No Unrestricted Capabilities**: Code execution (`RUN_CODE`), arbitrary API calls (`CALL_API`), file system access (`READ_FILE`, `WRITE_FILE`), inventory manipulation, and combat actions are strictly prohibited and actively rejected by validation.
4. **Deterministic Fallback**: If AI connectivity is disabled, unconfigured, times out, yields malformed JSON, or proposes an invalid action, the APC immediately falls back to `DeterministicBrain`.

---

## 🎛️ Brain Modes & Controls

- **Modes**:
  - `DETERMINISTIC`: Pure rule-based state machine evaluating player visibility and proximity.
  - `AI`: Periodically queries the configured AI provider for decisions via `submit_apc_action`.
- **Configuration**:
  - `ECHO_BRAIN_MODE` environment variable (`deterministic` or `ai`).
- **Manual Toggle**:
  - Pressing **F4** (`toggle_brain_mode`) dynamically switches between `DETERMINISTIC` and `AI` modes. Switching to `AI` without a configured provider automatically stays in `DETERMINISTIC` mode and logs a warning.

---

## 🛠️ Tool Schema (`submit_apc_action`)

The LLM is provided with a single tool definition:

```json
{
  "type": "function",
  "function": {
    "name": "submit_apc_action",
    "description": "Submit exactly one legal action for the APC to execute.",
    "parameters": {
      "type": "object",
      "properties": {
        "action": {
          "type": "string",
          "enum": ["IDLE", "WAIT", "FOLLOW_PLAYER", "LOOK_AT_PLAYER", "LOOK_AT_OBJECT", "MOVE_TO_OBJECT"]
        },
        "target_id": {
          "type": "string",
          "description": "Target entity ID (e.g. human_player or red_box)"
        },
        "duration": {
          "type": "number",
          "description": "Action duration in seconds"
        },
        "reason": {
          "type": "string",
          "description": "Short explanation for decision"
        }
      },
      "required": ["action"],
      "additionalProperties": false
    }
  }
}
```

---

## 📊 Input Context Schema

The `AIBrain` builds a compact perception payload for the user message:

```json
{
  "self": {
    "state": "IDLE",
    "current_action": "WAIT"
  },
  "human_player": {
    "id": "human_player",
    "visible": true,
    "distance": 6.4,
    "relative_direction": "front_left"
  },
  "nearby_objects": [
    {
      "id": "red_box",
      "visible": true,
      "distance": 4.2,
      "relative_direction": "right"
    }
  ],
  "available_actions": [
    "IDLE", "WAIT", "FOLLOW_PLAYER", "LOOK_AT_PLAYER", "LOOK_AT_OBJECT", "MOVE_TO_OBJECT"
  ],
  "valid_target_ids": [
    "human_player", "red_box"
  ]
}
```

---

## 🔍 Validation Pipeline (`AIDecisionAdapter`)

Before an AI request translates into an `ActionRequest`, it passes through 10 strict validation gates:

1. **Tool Name Verification**: Must be `submit_apc_action`.
2. **Action Existence**: Action string must match an allowed action (`IDLE`, `WAIT`, `FOLLOW_PLAYER`, `LOOK_AT_PLAYER`, `LOOK_AT_OBJECT`, `MOVE_TO_OBJECT`).
3. **Keyword Inspection**: Rejects any forbidden keywords (`RUN_CODE`, `CALL_API`, `READ_FILE`, `WRITE_FILE`, `eval`, `exec`, etc.).
4. **Target Requirement**: Requires a `target_id` when the action demands one (`FOLLOW_PLAYER`, `LOOK_AT_PLAYER`, `LOOK_AT_OBJECT`, `MOVE_TO_OBJECT`).
5. **Target Existence**: `target_id` must match a currently known perceived entity from the snapshot (`human_player` or `red_box`). Invented IDs are rejected.
6. **Target Type Enforcement**:
   - `FOLLOW_PLAYER` and `LOOK_AT_PLAYER` must specify `target_id = "human_player"`.
   - `LOOK_AT_OBJECT` and `MOVE_TO_OBJECT` must specify a known non-player object ID.
7. **Target Position Resolution**: Position is resolved directly from actual game perception data (never trusted from model text).
8. **Duration Boundary**: Clamped to $[0.0, 30.0]$ seconds.
9. **Reason Sanitization**: Truncated to 100 characters max.
10. **Stale Request Check**: Responses arriving after request cancellation or timeout are dropped.
