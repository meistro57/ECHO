class_name AudioBuffer
extends RefCounted

var samples: PackedFloat32Array = PackedFloat32Array()
var sample_rate: int = 16000
var channels: int = 1

func _init(p_samples: PackedFloat32Array = PackedFloat32Array(), p_sample_rate: int = 16000, p_channels: int = 1) -> void:
	samples = p_samples
	sample_rate = p_sample_rate
	channels = p_channels

func is_empty() -> bool:
	return samples.is_empty()

func get_duration() -> float:
	if sample_rate <= 0 or channels <= 0:
		return 0.0
	return float(samples.size()) / float(sample_rate * channels)
