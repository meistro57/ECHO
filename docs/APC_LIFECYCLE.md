# APC Lifecycle

This document describes the expected lifecycle of an ECHO AI Player Character.

## 1. Spawn

The APC enters the shared scene with a stable identity, physical body, collision, navigation agent, and registered components. Reusable character scenes should use clean local transforms; the world owns spawn placement.

## 2. World readiness

The APC waits for required systems before acting:

- scene dependencies are resolved
- navigation map is synchronized
- perception targets are registered
- persistence restoration is complete when enabled

Until readiness is confirmed, the APC remains in a safe idle state.

## 3. Perception

The APC updates a structured snapshot at a controlled interval. Visibility depends on range, field of view, line of sight, and short-term last-seen memory.

## 4. Decision

The active brain consumes the latest snapshot and proposes one legal action or trusted task. Deterministic mode remains available even when AI mode is configured.

## 5. Validation

Requests are checked against the current legal catalogue, valid targets, action requirements, task state, and request freshness.

## 6. Execution

Controllers translate approved intentions into navigation, rotation, interaction, and task steps. The APC receives structured progress, completion, failure, or cancellation results.

## 7. Learning and persistence

Completed grounded events may create structured memories. Registered world entities may save selected state. Perception snapshots and hidden reasoning are not persisted.

## 8. Shutdown

Pending network requests, audio capture, tasks, and temporary files are cancelled or cleaned safely. World state and memory save independently, and either subsystem must tolerate the other failing.
