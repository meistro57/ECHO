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

## 🚀 Phase 2: APC Locomotion & Following (Completed)

Phase 2 provides deterministic 3D pathfinding locomotion to the APC using Godot 4.7.1 built-in `NavigationRegion3D`, `NavigationMesh`, and `NavigationAgent3D`.

### Features & Navigation Setup
- **State System**: Clean state machine with `IDLE` and `FOLLOWING` states, featuring a hysteresis distance buffer (`stop_distance` = 2.0m, `start_follow_distance` = 3.2m) to guarantee smooth stopping and zero jittering.
- **Pathfinding Locomotion**: The APC navigates around obstacle crates and walls using valid navigation paths calculated by `NavigationAgent3D`.
- **Navigation Mesh**: The test room environment uses a `NavigationMesh` inside `NavigationRegion3D`, configured with `PARSED_GEOMETRY_STATIC_COLLIDERS` to automatically parse collision shapes at runtime while preserving scene resource caching.
- **Embodied Physics**: The APC moves via `CharacterBody3D` velocity and `move_and_slide()` without teleportation or clipping through walls or obstacles.
- **Live Debug HUD**: Pressing **F1** (`toggle_debug`) toggles real-time debug overlay metrics including APC State, distance to player, commanded/real velocity, floor status, slide collisions, and navigation finished status.

### Controls

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
│   │   ├── test_room.tscn      # 3D room with NavigationRegion3D, floor, walls, crate
│   │   ├── player.tscn         # First-person human player (CharacterBody3D)
│   │   └── apc.tscn            # Embodied APC character with NavigationAgent3D
│   ├── scripts/                # GDScript files (.gd)
│   │   ├── player/
│   │   │   └── player_controller.gd  # Human player movement & camera script
│   │   ├── apc/
│   │   │   └── apc_controller.gd     # APC state machine (IDLE / FOLLOWING) & locomotion
│   │   └── test_room.gd              # NavigationMesh baking & scene setup script
│   ├── ui/                     # UI overlays
│   │   ├── hud.tscn            # HUD overlay with live APC state display
│   │   └── hud.gd              # HUD controller script
│   ├── assets/                 # Project assets
│   └── tests/                  # Automated verification test suites
│       ├── test_phase1.gd      # Phase 1 automated test script
│       └── test_phase2.gd      # Phase 2 automated pathfinding & state test script
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
# Phase 1 Test
godot --headless --path client/ -s tests/test_phase1.gd

# Phase 2 Test
godot --headless --path client/ -s tests/test_phase2.gd
```

---

## ⚠️ Known Limitations (Phase 2 Baseline)

- **No Perception / Sensing**: The APC resolves target position directly from the game node tree rather than a line-of-sight vision cone or sensory memory (scheduled for Phase 3).
- **No Higher Cognitive Architecture**: Movement is purely rule-based locomotion without LLMs, goal planning, or speech synthesis (scheduled for future roadmap phases).

---

## 📜 License

This project is licensed under the [MIT License](LICENSE).
