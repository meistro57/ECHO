# Contributing to ECHO

ECHO grows through small, testable phases. Contributions should strengthen the embodied loop without weakening its authority boundaries.

## Before coding

1. Read `README.md`, `ROADMAP.md`, `docs/ARCHITECTURE.md`, `docs/PHILOSOPHY.md`, and `docs/DESIGN_PRINCIPLES.md`.
2. Inspect the existing repository before changing files.
3. For Godot work, follow the workflow in `fernforestgames/agent-skill-godot` and use documentation matching the project's installed Godot version.
4. Confirm which roadmap phase the change belongs to.

## Development rules

- Implement only the requested phase or issue.
- Preserve working behaviour from earlier phases.
- Prefer clear, typed GDScript and small components.
- Never manually invent `uid://` values.
- Use InputMap actions rather than hard-coded keys where appropriate.
- Keep AI provider code separate from APC behaviour.
- Never commit credentials, runtime saves, raw audio, or generated cache files.
- Do not let perception, brains, or language systems bypass validated controllers.

## Validation

Run from the Godot project directory:

```bash
godot --headless --import
```

Then run available syntax checks and all phase tests affected by the change. Launch the main scene and perform the documented manual acceptance test.

## Pull requests

A pull request should explain:

- the problem or phase addressed
- files and systems changed
- architecture boundaries preserved
- automated and manual test results
- known limitations
- confirmation that later-phase features were not added accidentally

Small, working bolts beat enormous mystery machinery.
