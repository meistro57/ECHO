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
- **First Proof of Concept Target**: One room, one human player, one APC, and one interactive object.

---

## 🚀 Current Project Status: Phase 4 Completed

ECHO is built targeting **Godot 4.7.1 Stable**. The framework currently implements a complete 4-tier cognitive architecture pipeline:

```
Perceive (APCPerception)
   ↓
Decide (APCBrain)
   ↓
Request Legal Action (ActionRequest)
   ↓
Execute (ActionController) -> Locomotion / Rotation / Velocity
```

### 🧠 Cognitive Architecture Components

1. **Structured Perception (`APCPerception`) [Phase 3]**:
   - Engine-native non-omniscient sensing evaluating distance (`max_view_distance` = 15.0m), field of view (`field_of_view_degrees` = 110.0°), and physics raycast line-of-sight occlusion.
   - short-term memory tracking last-seen position and elapsed seconds before expiring (`memory_duration` = 3.0s).
   - Entity recognition supporting the Human Player and portable objects (`RedBox`).

2. **APC Brain (`APCBrain`) [Phase 4]**:
   - Isolated decision component that consumes perception snapshots and produces typed `ActionRequest` objects.
   - Strictly decoupled from physics, navigation, and `CharacterBody3D`.
   - Deterministic rule set:
     - Player visible & distance > 3.2m -> `FOLLOW_PLAYER`
     - Player visible & distance <= 3.2m -> `LOOK_AT_PLAYER`
     - Player hidden / not visible -> `WAIT`
     - No perception data -> `IDLE`

3. **Action & Execution Controller (`ActionController`) [Phase 4]**:
   - Only component authorized to command locomotion, rotation, and physical velocity on `CharacterBody3D`.
   - Executes `FOLLOW_PLAYER` navigation, `LOOK_AT_PLAYER` smooth facing rotation, `WAIT` stationary holding, and `IDLE`.
   - Maintains a rolling 20-entry debug log tracking perception changes and decision transitions.

4. **Live Debug HUD (F1)**:
   - Displays real-time metrics including APC State, Brain Decision, Action Execution Status, Perception metrics (Distance, FOV, Line of Sight, Last-Seen timer), and rolling Event Log.

---

## 🎮 Controls

| Action | Control |
| --- | --- |
| **Move** | `W` `A` `S` `D` |
| **Look Around** | `Mouse` |
| **Jump** | `Space` |
| **Release / Recapture Mouse** | `Escape` or Left Click |
| **Toggle Debug HUD** | `F1` |

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
│   │   ├── apc.tscn            # Embodied APC character with Brain, Perception, & ActionController
│   │   └── objects/
│   │       └── red_box.tscn    # Perceivable Red Box object
│   ├── scripts/                # GDScript files (.gd)
│   │   ├── player/
│   │   │   └── player_controller.gd  # Human player movement & camera script
│   │   ├── apc/
│   │   │   ├── apc_controller.gd     # APC root orchestration script
│   │   │   ├── apc_brain.gd          # APC decision brain component
│   │   │   ├── action_controller.gd  # Locomotion & action execution controller
│   │   │   ├── action_types.gd       # Typed Action enum, ActionRequest, & ActionResult
│   │   │   └── apc_perception.gd     # Engine-native perception & FOV/LOS raycast component
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
│       └── test_phase4.gd      # Phase 4 action & brain pipeline test
├── docs/                       # Project Documentation
│   ├── VISION.md               # Core philosophy & vision
│   ├── ARCHITECTURE.md         # Component & cognitive pipeline architecture
│   └── ROADMAP.md              # Multi-phase development roadmap
├── static/                     # Repository branding & media
│   └── images/
│       └── ECHO_LOGO.png       # Official ECHO framework logo
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
# Launch project in 3D test room
godot --path client/
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
```

---

## ⚠️ Scope & Known Limitations (Phase 4 Baseline)

- **Rule-Based Brain**: Decision logic is currently driven by deterministic perception rules prior to LLM/planner integration.
- **No LLMs / Speech / Natural Language**: Language models, speech synthesis, and natural language understanding are scheduled for future roadmap phases.
- **No Combat / Inventory / Databases**: The framework focuses strictly on embodied co-presence and physical action execution.

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
