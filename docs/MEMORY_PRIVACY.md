# Memory Privacy and Control

## Local-only storage

Phase 9 memory is stored only in the local user data directory (`user://...`).
No persistent memory is written to repository paths.

## Data minimization

The memory system stores compact structured facts, not raw streams.

Stored fields are limited to:

- typed memory metadata
- short summary
- timestamp
- entity IDs
- event type
- source and verification flag

## Explicitly blocked content

`MemoryPolicy` rejects records containing:

- API keys and secret-like tokens
- provider authorization headers
- raw audio references
- full transcript fields
- unsupported memory types
- empty or oversized summaries

## User inspection and editing

The debug HUD memory section exposes:

- memory enabled state
- total record count
- current session ID
- last stored memory type
- last query count
- last memory error
- memory file path
- record list
- delete selected record action
- clear-all action with confirmation

## Forgetting guarantees

- targeted delete by selected record ID
- ambiguous `forget` requests require clarification
- no broad ambiguous delete wipes the database
- clear-all always requires confirmation

## AI memory boundary

Memory answers are generated from retrieved records only.
If nothing matches, APC states: `I don't have a stored memory of that.`
No hidden reasoning or unrestricted memory dump is stored.

## Operational safety

If memory is disabled (`ECHO_MEMORY_ENABLED=false`):

- movement, voice, and command flow still function
- memory commands return safe disabled responses
- no persistent memory writes are attempted
