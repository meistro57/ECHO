# ECHO AI Pipeline

ECHO treats language models as optional decision providers, not as the game engine.

## Core flow

```text
World
  ↓
Perception Snapshot
  ↓
Deterministic Brain or AI Brain
  ↓
Validated ActionRequest or TaskRequest
  ↓
Action / Interaction / Task Controllers
  ↓
Navigation, Physics, and World Changes
  ↓
Action Result and Updated Perception
```

## Provider layer

OpenRouter and direct DeepSeek connectivity sit behind a provider-neutral service. Provider code owns HTTP details, authentication headers, request formatting, response parsing, timeouts, and sanitized errors.

The APC brain never contains provider-specific networking code.

## Context boundary

AI providers receive only the compact context needed for the current decision:

- current perception
- APC state
- current action or task
- legal actions
- trusted task types
- valid entity IDs
- previous sanitized result

They do not receive API keys, full scene trees, raw node paths, files, environment variables, hidden reasoning, or unrestricted tools.

## Execution boundary

A model may propose a legal action or trusted task. It may not directly manipulate velocity, transforms, physics bodies, objects, files, or operating-system commands.

Every response is checked for schema, action legality, target validity, request freshness, and allowed fields before execution.

## Failure behaviour

Malformed output, stale responses, timeouts, provider errors, and unsupported requests activate a deterministic fallback or safe WAIT state. Gameplay remains responsive and local systems continue operating.
