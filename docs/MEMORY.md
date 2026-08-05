# ECHO Memory

ECHO memory stores selected, grounded facts and completed experiences. It is not a transcript archive and not an invented biography.

## What may be remembered

- completed trusted tasks
- useful task failures
- explicit player statements marked for memory
- validated preferences
- selected important world or location events

## What is not stored

- API keys or environment variables
- raw microphone audio
- hidden reasoning
- full provider responses
- frame-by-frame positions
- ordinary conversation by default
- temporary debug output
- unverified model claims

## Record shape

A memory record should include a stable ID, type, concise summary, timestamp, session ID, involved entity IDs, source, importance, and verification status.

## Retrieval

Retrieval begins with exact entities, event types, recency, and importance. Only a small relevant set is supplied to an AI provider. ECHO does not send its entire memory store for every request.

## Forgetting and control

Local users must be able to inspect and delete records. Ambiguous deletion requests require clarification. Clearing memory is separate from resetting world state.

## Grounding rule

A task is remembered as successful only after the trusted TaskController reports completion. A model cannot declare its own intention to be a completed memory.
