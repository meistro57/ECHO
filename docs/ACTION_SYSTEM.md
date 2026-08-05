# ECHO Action System

The action system is the boundary between intention and physical execution.

## Responsibilities

A brain may request an action. It may not execute one.

The action layer:

- exposes the current legal action catalogue
- validates required parameters
- resolves stable entity IDs
- rejects unsupported actions and invented targets
- starts approved execution
- reports structured status and results

## Initial legal actions

Examples include:

- IDLE
- WAIT
- FOLLOW_PLAYER
- LOOK_AT_PLAYER
- LOOK_AT_OBJECT
- MOVE_TO_OBJECT
- PICK_UP_OBJECT
- DROP_HELD_OBJECT
- GIVE_OBJECT_TO_PLAYER

Only implemented and tested actions may appear in the catalogue.

## Authority boundaries

- ActionController owns locomotion and rotation requests.
- InteractionController owns raw object attachment, release, and physics changes.
- TaskController owns ordered multi-step execution.
- AI and deterministic brains produce requests only.

## Results

Every action should return a structured result containing the requested action, status, success, timestamps, and a sanitized message or failure reason.

Typical states are pending, running, completed, failed, and cancelled.

## Rule

> No intention reaches physics without passing through a legal, validated action boundary.
