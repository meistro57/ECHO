# Phase 9 Memory System

## Overview

Phase 9 adds explicit, structured persistent memory for the APC. Memory is local-only, inspectable, and bounded. It is separate from live perception and separate from transient conversation state.

Runtime flow:

1. Game event
2. `MemoryPolicy` validation
3. `MemoryRecord` creation
4. `MemoryService` persistence via `MemoryStore`
5. `JSONMemoryStore` save to `user://echo_memory.json`

## Storage format and path

- Default file: `user://echo_memory.json`
- Configurable via `ECHO_MEMORY_FILE`
- JSON format is human-readable and valid UTF-8 text
- Save path is never `res://`

Saved schema:

```json
{
	"version": 1,
	"previous_session_id": "sess_...",
	"records": [
		{
			"memory_id": "mem_...",
			"memory_type": "TASK_COMPLETION",
			"summary": "The APC brought the Red Box to the human player.",
			"timestamp_unix": 0.0,
			"session_id": "sess_...",
			"importance": 0.9,
			"entities": ["human_player", "red_box"],
			"event_type": "BRING_OBJECT_TO_PLAYER",
			"source": "task_controller",
			"verified": true,
			"metadata": {}
		}
	]
}
```

## Memory types

Supported Phase 9 types:

- `TASK_COMPLETION`
- `TASK_FAILURE`
- `PLAYER_PREFERENCE`
- `IMPORTANT_STATEMENT`
- `LOCATION_EVENT`

Unsupported types are rejected by policy.

## What gets stored

Automatic storage is limited to:

- trusted task completion
- trusted task failure with reason

Explicit player commands:

- `remember that ...`
- `remember I ...`
- `my preference is ...`
- `forget ...`

Ordinary chatter is not auto-stored.

## Query rules and ranking

`MemoryQuery` supports:

- memory types
- entity IDs
- event type
- session ID
- time range
- max results
- minimum importance

Phase 9 relevance order:

1. exact entity match
2. exact event-type match
3. recency
4. importance

Max records passed to memory answer context defaults to `5`.

## Session tracking

`MemoryService` tracks:

- `current_session_id`
- `session_start_unix`
- `previous_session_id`

No memory record is created solely for session start/end.

## Forgetting flow

- `forget <term>` searches candidates
- if exactly one match, delete it
- if multiple matches, ask for clarification
- broad ambiguous requests do not wipe all memory

Debug clear-all exists and requires explicit confirmation.

## Record limits and pruning

Config:

- `ECHO_MEMORY_ENABLED=true`
- `ECHO_MEMORY_MAX_RECORDS=500`
- `ECHO_MEMORY_MAX_QUERY_RESULTS=5`
- `ECHO_MEMORY_FILE=echo_memory.json`

Pruning policy when capacity is exceeded:

1. preserve explicit player memories first
2. prune oldest low-importance non-explicit records first
3. only prune explicit memories if no alternative remains

## Corruption and failure recovery

`JSONMemoryStore` handles:

- missing file: clean start
- corrupt JSON: move corrupt file to `.bak`, continue safely
- failed writes: keep existing file intact
- duplicate IDs: skip duplicates on load

Failures are surfaced through `last_memory_error` and do not crash gameplay.
