<p align="center">
  <img src="static/images/ECHO_LOGO.png" alt="ECHO Logo" width="600" />
</p>

<h1 align="center">ECHO</h1>
<p align="center"><strong>Open-Source Experimental Framework for Embodied AI Player Characters (APCs)</strong></p>

---

## 🌟 Core Concept

<img width="1201" height="1316" alt="image" src="https://github.com/user-attachments/assets/29acb66c-81a5-4f28-beba-a1175f6be00a" />

ECHO is an experimental framework exploring a new paradigm in game AI:

- **Shared Co-Presence**: A human-controlled player and an AI-controlled player character (APC) occupy the exact same 3D physical environment.
- **Embodied, Not a Chatbot**: The APC is an embodied entity in the game world with a physical body, location, orientation, line of sight, and navigation limits—not a floating text box or conversational agent.
- **Legal Game Actions**: The APC perceives its environment, evaluates decisions, and acts exclusively through structured legal game actions (`MOVE`, `INTERACT`, `DROP`, `SPEAK`) via standard physics and navigation systems, never by direct scene state hacking or teleportation.
- **First Proof of Concept Target**: One room, one human player, one APC, and one interactive object (`RedBox`).

---

## 🚀 Current Project Status: Phase 7 Completed

ECHO is built targeting **Godot 4.7.1 Stable**. The framework implements a complete 6-tier cognitive and physical architecture pipeline with deterministic fallback:

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
       └─────────────────┴──────────► TaskController / ActionRequest
                                           │
                                           ├──────────────────────────┐
                                           ▼                          ▼
                                    ActionController        InteractionController
                                    (Locomotion Authority)  (Object Authority)
                                           │                          │
                                           ▼                          ▼
                                    CharacterBody3D            CarrySocket / RedBox
```

### 🧠 Cognitive & Physical Architecture Components

1. **Structured Perception (`APCPerception`) [Phase 3]**:
   - Engine-native non-omniscient sensing evaluating distance (`max_view_distance` = 15.0m), field of view (`field_of_view_degrees` = 110.0°), and physics raycast line-of-sight occlusion.
   - Short-term memory tracking last-seen position and elapsed seconds before expiring (`memory_duration` = 3.0s).

2. **APC Brain (`APCBrain`) & Dual Modes [Phase 4 / Phase 6]**:
   - Orchestrates decision-making between `DeterministicBrain` and `AIBrain`.
   - **Deterministic Mode**: Rule-based state machine (`FOLLOW_PLAYER`, `LOOK_AT_PLAYER`, `WAIT`, `IDLE`).
   - **AI Mode**: Sends compact perception context to OpenRouter/DeepSeek via `submit_apc_action` or `submit_apc_task` tool schemas.
   - **Automatic Fallback**: Any network failure, rate limit, timeout, or validation rejection instantly falls back to `DeterministicBrain`.

3. **AI Decision Adapter (`AIDecisionAdapter`) [Phase 6 / Phase 7]**:
   - Strict validation pipeline inspecting returned tool calls (`submit_apc_action` and `submit_apc_task`).
   - Enforces allowed action enums (`IDLE`, `WAIT`, `FOLLOW_PLAYER`, `LOOK_AT_PLAYER`, `LOOK_AT_OBJECT`, `MOVE_TO_OBJECT`, `PICK_UP_OBJECT`, `DROP_HELD_OBJECT`, `GIVE_OBJECT_TO_PLAYER`), target ID existence, target type rules, and duration limits.
   - Rejects raw model step injection attempts, invented targets, code execution attempts, file paths, and shell commands.

4. **Physical Object Interaction (`InteractionController` & `CarrySocket`) [Phase 7]**:
   - Sole authority for object pickup, carry socket attachment, ground placement raycasting, and giving objects to the player.
   - Preserves object identity and disables collision shapes while held.

5. **Sequential Task Execution (`TaskController`) [Phase 7]**:
   - Executes multi-step trusted tasks (`BRING_OBJECT_TO_PLAYER`).
   - Expands tasks into trusted steps (`MOVE_TO_OBJECT` -> `PICK_UP_OBJECT` -> `FOLLOW_PLAYER` -> `GIVE_OBJECT_TO_PLAYER`).

6. **Live Debug HUD (F1 / F3 / F4 / F5)**:
   - Displays APC State, Brain Mode, AI Status, Task Status, Held Object, Latency, Token usage, Perception metrics, and Event Log.

---

## 🎮 Controls

| Action | Control |
| --- | --- |
| **Move** | `W` `A` `S` `D` |
| **Look Around** | `Mouse` |
| **Jump** | `Space` |
| **Release / Recapture Mouse** | `Escape` or Left Click |
| **Toggle Debug HUD** | `F1` |
| **Test AI Connectivity** | `F3` |
| **Toggle Brain Mode** | `F4` (DETERMINISTIC / AI) |
| **Test Bring Red Box Task** | `F5` |

---

## 📂 Repository Structure

```
ECHO/
├── client/                     # Godot 4.7.1 Project Root
│   ├── project.godot           # Main Godot project settings & InputMap
│   ├── scenes/                 # Scene files (.tscn)
│   │   ├── main.tscn           # Main launch scene
│   │   ├── test_room.tscn      # 3D room with NavigationRegion3D, floor, walls, crate, & RedBox
│   │   ├── player.tscn         # First-person human player (CharacterBody3D)
│   │   ├── apc.tscn            # Embodied APC character with CarrySocket
│   │   └── objects/
│   │       └── red_box.tscn    # Perceivable Red Box object
│   ├── scripts/                # GDScript files (.gd)
│   │   ├── player/
│   │   │   └── player_controller.gd  # Human player movement & camera script
│   │   ├── apc/
│   │   │   ├── apc_controller.gd     # APC root orchestration script
│   │   │   ├── apc_brain.gd          # Dual-mode brain orchestrator
│   │   │   ├── deterministic_brain.gd# Deterministic rule-based brain
│   │   │   ├── ai_brain.gd           # AI decision brain component
│   │   │   ├── ai_decision_adapter.gd# Tool call & payload validation adapter
│   │   │   ├── action_controller.gd  # Locomotion & action execution controller
│   │   │   ├── interaction_controller.gd # Object pickup, drop, & give controller
│   │   │   ├── task_controller.gd    # Sequential multi-step task execution controller
│   │   │   ├── task_request.gd       # Typed TaskRequest model with step expansion
│   │   │   ├── task_result.gd        # Typed TaskResult state tracking model
│   │   │   ├── carried_object_socket.gd # CarrySocket node attachment & collision manager
│   │   │   ├── action_types.gd       # Typed Action enum, ActionRequest, & ActionResult
│   │   │   └── apc_perception.gd     # Engine-native perception & FOV/LOS raycast component
│   │   ├── ai/
│   │   │   ├── ai_service.gd         # AIService node
│   │   │   ├── ai_provider.gd        # Base AI provider class
│   │   │   ├── ai_request.gd         # Typed AI request model
│   │   │   ├── ai_response.gd        # Typed AI response model
│   │   │   └── providers/
│   │   │       ├── openrouter_provider.gd # OpenRouter provider
│   │   │       └── deepseek_provider.gd   # Direct DeepSeek provider
│   │   ├── objects/
│   │   │   ├── portable_object.gd    # Portable object base script & contract
│   │   │   └── red_box.gd            # Red Box object script extending PortableObject
│   │   └── test_room.gd              # NavigationMesh baking & scene setup script
│   ├── ui/                     # UI overlays
│   │   ├── hud.tscn            # Debug HUD overlay scene
│   │   └── hud.gd              # Debug HUD controller script
│   └── tests/                  # Automated verification test suites
│       ├── test_phase1.gd      # Phase 1 environment & player test
│       ├── test_phase2.gd      # Phase 2 pathfinding & locomotion test
│       ├── test_phase3.gd      # Phase 3 structured perception test
│       ├── test_phase4.gd      # Phase 4 action & brain pipeline test
│       ├── test_phase5.gd      # Phase 5 AI connectivity layer test
│       ├── test_phase6.gd      # Phase 6 AI decision bridge & validation test
│       └── test_phase7.gd      # Phase 7 object interaction & task execution test
├── docs/                       # Project Documentation
│   ├── VISION.md               # Core philosophy & vision
│   ├── ARCHITECTURE.md         # Component & cognitive pipeline architecture
│   ├── ROADMAP.md              # Multi-phase development roadmap
│   ├── AI_PROVIDERS.md         # Phase 5 provider architecture documentation
│   ├── AI_DECISION_BRIDGE.md   # Phase 6 AI decision bridge documentation
│   ├── OBJECT_INTERACTION.md   # Phase 7 object interaction architecture
│   └── TASK_EXECUTION.md       # Phase 7 task execution architecture
├── static/                     # Repository branding & media
│   └── images/
│       └── ECHO_LOGO.png       # Official ECHO framework logo
├── .env.example                # Configuration template file
├── .gitignore                  # Godot 4.x git ignore rules
├── LICENSE                     # MIT License
└── README.md                   # Repository overview & run instructions
```

---

## 🏃 Opening and Running in Godot 4.7.1 Stable

### Prerequisites
- [Godot Engine 4.7.1 Stable](https://godotengine.org/download).

### Exact Steps to Run

#### Option 1: Via Godot Editor GUI
1. Clone this repository:
   ```bash
   git clone https://github.com/meistro57/ECHO.git
   ```
2. Launch **Godot Engine 4.7.1**.
3. Click **Import**, browse to `ECHO/client/project.godot`, and select it.
4. Click **Import & Edit**.
5. Press **F5** (or click **Play**) to launch `res://scenes/main.tscn`.

#### Option 2: Via Terminal Command Line
From the repository root directory, run:

```bash
# Launch project in 3D test room (Deterministic Mode default)
godot --path client/

# Launch project in AI Decision Mode (OpenRouter)
ECHO_BRAIN_MODE=ai ECHO_AI_ENABLED=true ECHO_AI_PROVIDER=openrouter OPENROUTER_API_KEY=<key> godot --path client/
```

To run the automated verification test suites:

```bash
# Phase 1 Test (Foundation)
godot --headless --path client/ -s tests/test_phase1.gd

# Phase 2 Test (Locomotion & Navigation)
godot --headless --path client/ -s tests/test_phase2.gd

# Phase 3 Test (Structured Perception)
godot --headless --path client/ -s tests/test_phase3.gd

# Phase 4 Test (Action & Brain Pipeline)
godot --headless --path client/ -s tests/test_phase4.gd

# Phase 5 Test (AI Provider Connectivity)
godot --headless --path client/ -s tests/test_phase5.gd

# Phase 6 Test (AI Decision Bridge & Validation)
godot --headless --path client/ -s tests/test_phase6.gd

# Phase 7 Test (Object Interaction & Task Execution)
godot --headless --path client/ -s tests/test_phase7.gd
```

---

## ⚠️ Scope & Known Limitations (Phase 7 Baseline)

- **Single Object Target**: Currently configured for one portable object (`RedBox`).
- **No General Inventory Grid / Skeletal Rigging**: Object carrying uses simple node attachment (`CarrySocket`) without skeletal hand IK or inventory grid management.
- **No Speech / Conversation**: Speech recognition and text-to-speech are scheduled for future roadmap phases.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
