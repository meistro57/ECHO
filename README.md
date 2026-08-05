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

## 🚀 Current Project Status: Phase 6 Completed

ECHO is built targeting **Godot 4.7.1 Stable**. The framework implements a complete 5-tier cognitive architecture pipeline with deterministic fallback:

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

### 🧠 Cognitive Architecture Components

1. **Structured Perception (`APCPerception`) [Phase 3]**:
   - Engine-native non-omniscient sensing evaluating distance (`max_view_distance` = 15.0m), field of view (`field_of_view_degrees` = 110.0°), and physics raycast line-of-sight occlusion.
   - Short-term memory tracking last-seen position and elapsed seconds before expiring (`memory_duration` = 3.0s).

2. **APC Brain (`APCBrain`) & Dual Modes [Phase 4 / Phase 6]**:
   - Orchestrates decision-making between `DeterministicBrain` and `AIBrain`.
   - **Deterministic Mode**: Rule-based state machine (`FOLLOW_PLAYER`, `LOOK_AT_PLAYER`, `WAIT`, `IDLE`).
   - **AI Mode**: Sends compact perception context to OpenRouter/DeepSeek via `submit_apc_action` tool schema.
   - **Automatic Fallback**: Any network failure, rate limit, timeout, or validation rejection instantly falls back to `DeterministicBrain`.

3. **AI Decision Adapter (`AIDecisionAdapter`) [Phase 6]**:
   - Strict 10-gate validation pipeline inspecting returned tool calls.
   - Enforces allowed action enums (`IDLE`, `WAIT`, `FOLLOW_PLAYER`, `LOOK_AT_PLAYER`, `LOOK_AT_OBJECT`, `MOVE_TO_OBJECT`), target ID existence, target type rules, and duration limits.
   - Rejects invented targets, code execution attempts, file paths, and shell commands.

4. **Action & Execution Controller (`ActionController`) [Phase 4 / Phase 6]**:
   - Only component authorized to command locomotion, rotation, and physical velocity on `CharacterBody3D`.
   - Maintains a rolling 20-entry debug log.

5. **Live Debug HUD (F1 / F3 / F4)**:
   - Displays APC State, Brain Mode (`DETERMINISTIC`/`AI`), AI Decision Status, Provider, Model, Latency, Token usage, Perception metrics, and Event Log.

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
│   │   ├── apc.tscn            # Embodied APC character
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
│   │   │   └── red_box.gd            # Red Box object metadata script
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
│       └── test_phase6.gd      # Phase 6 AI decision bridge & validation test
├── docs/                       # Project Documentation
│   ├── VISION.md               # Core philosophy & vision
│   ├── ARCHITECTURE.md         # Component & cognitive pipeline architecture
│   ├── ROADMAP.md              # Multi-phase development roadmap
│   ├── AI_PROVIDERS.md         # Phase 5 provider architecture documentation
│   └── AI_DECISION_BRIDGE.md   # Phase 6 AI decision bridge documentation
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
```

---

## ⚠️ Scope & Known Limitations (Phase 6 Baseline)

- **Constrained Toolset**: The AI model may only select actions from the legal action list (`IDLE`, `WAIT`, `FOLLOW_PLAYER`, `LOOK_AT_PLAYER`, `LOOK_AT_OBJECT`, `MOVE_TO_OBJECT`).
- **No Object Interaction / Inventory / Speech**: Object pickup, inventory systems, speech synthesis, and combat are scheduled for future roadmap phases.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
