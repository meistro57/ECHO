# ECHO Design Principles

These principles guide implementation and review.

## 1. Prove the smallest useful thing

Each phase must end in a runnable, observable result. Avoid building infrastructure for hypothetical needs before the current proof works.

## 2. Preserve authority boundaries

- Perception observes.
- Brains choose intentions.
- Validators approve legal requests.
- Action controllers own movement.
- Interaction controllers own objects.
- Task controllers own multi-step execution.
- Persistence services own stored state.

No layer may quietly seize another layer's authority.

## 3. AI is optional

Every AI-powered capability requires a deterministic fallback. Provider failure must degrade gracefully rather than disable the world.

## 4. No omniscience

The APC receives only information justified by its body, sensors, memory, communications, or explicit game rules.

## 5. Structured interfaces first

Use stable IDs, typed requests, validated results, and compact schemas. Natural language may enter at the edge, but execution remains structured.

## 6. Physical consequences matter

Normal movement uses navigation, velocity, collision, and physics. Objects are carried, dropped, and restored through explicit world rules rather than teleportation.

## 7. Inspectability over mystery

Actions, memories, tasks, save records, and failures should be visible and understandable to developers and local users.

## 8. Safe growth

Every phase must preserve prior behaviour, include tests, document limitations, and avoid implementing later phases by accident.

## Review question

Before merging a feature, ask:

> Does this strengthen the embodied loop without weakening its boundaries?
