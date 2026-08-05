class_name WorldStateRegistry
extends RefCounted

var _entities: Dictionary = {} # persistent_id -> PersistentEntity

func register_entity(entity: PersistentEntity) -> bool:
	if entity == null or entity.persistent_id.is_empty():
		last_error = "Invalid persistent entity"
		return false
	if _entities.has(entity.persistent_id):
		last_error = "Duplicate persistent_id '%s'" % entity.persistent_id
		return false
	_entities[entity.persistent_id] = entity
	return true

func unregister_entity(persistent_id: String) -> bool:
	if not _entities.has(persistent_id):
		last_error = "Persistent entity '%s' not registered" % persistent_id
		return false
	_entities.erase(persistent_id)
	return true

func get_entity(persistent_id: String) -> PersistentEntity:
	if _entities.has(persistent_id):
		return _entities[persistent_id] as PersistentEntity
	return null

func get_all_entities() -> Array:
	var result: Array = []
	for entity in _entities.values():
		result.append(entity)
	return result

func contains_id(persistent_id: String) -> bool:
	return _entities.has(persistent_id)

func get_count() -> int:
	return _entities.size()

func clear() -> void:
	_entities.clear()

var last_error: String = "None"
