# ECHO Vision & Core Philosophy

## Overview

**ECHO** is an experimental open-source framework for **Embodied AI Player Characters (APCs)** in 3D game environments.

Unlike traditional non-player characters (NPCs) driven by fixed state machines or conversational chatbots restricted to text boxes, an **APC** is a fully embodied entity that shares the same virtual world, physical rules, perception constraints, and action interface as a human player.

---

## Core Principles

### 1. Embodiment over Interface
An APC is an entity *inside* the 3D world. It possesses a physical body, location, orientation, line of sight, and navigation limits. It interacts with the world using the same physical laws and collision rules as the human player.

### 2. Legal Actions, Not Direct State Mutations
The AI character does not "teleport" objects into its hands or directly overwrite scene node properties. Instead, AI decisions generate **structured legal game actions** (e.g. `MOVE_TO`, `PICK_UP`, `DROP`, `SPEAK`) which are physically executed step-by-step through the engine's movement and interaction system.

### 3. Perception & Memory Loop
The APC perceives its environment through simulated senses (proximity, line of sight, raycasts) and builds a structured model of surrounding objects and entities. This perception fuels a decision-making loop (`Perceive → Think → Remember → Act → Connect`).

### 4. Shared Co-Presence
A human player and an AI companion inhabit the exact same 3D space, enabling cooperative physical problem solving, spatial understanding, and rich emergent gameplay.

---

## Initial Proof of Concept Target

The primary objective is to create the minimal working foundation:
- **One 3D Room**: Bounded environment with collision geometry and navigation mesh.
- **One Human Player**: First-person 3D character controller.
- **One AI Player Character (APC)**: Physical character with perception, decision brain, memory, and pathfinding action executor.
- **One Interactive Object**: A 3D object that can be perceived, approached, legally picked up, carried, and placed.
