# ECHO Development Roadmap

## Phase 0: Repository Foundation & Setup (Current)
- Establish repository structure, licensing, `.gitignore`, and core documentation.
- Configure Godot 4.x project layout under `client/`.
- Build lightweight title screen launching cleanly in Godot.

## Phase 1: Minimal Proof of Concept
- Single 3D room with `NavigationRegion3D` and collision walls/floor.
- First-person Human Player controller (`CharacterBody3D`).
- Embodied AI Player Character (APC) with physical movement, perception, decision brain, memory, and pathfinding.
- Interactive object (`Red Cube`) supporting pickup, carry, and drop operations.
- HUD UI showing live telemetry and text dialogue feed.

## Phase 2: Multi-Object & Spatial Navigation
- Multiple rooms connected by portals/doorways.
- Spatial memory enabling APC to remember object locations out of line of sight.
- Multiple interactable object types (switches, containers, obstacles).

## Phase 3: Advanced Perception & Co-op Interaction
- Visual raycast occlusion and auditory perception (hearing player steps).
- Co-op physical puzzles requiring human player and APC coordination.

## Phase 4: Pluggable AI Backends
- Local LLM / IPC integration for high-level reasoning.
- Fallback heuristic brain modules for offline execution.
