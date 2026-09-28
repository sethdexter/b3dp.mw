extends Resource
class_name Effect

@export var id: String
@export var display_name: String
@export var duration_seconds: float = 0.0
@export var additive_value: int = 0
@export var multiplicative_value: float = 1.0

func apply_to(attribute: Attribute, source_id: String) -> void:
	if attribute:
		attribute.add_modifier(source_id, additive_value, multiplicative_value)

func remove_from(attribute: Attribute, source_id: String) -> void:
	if attribute:
		attribute.remove_modifier(source_id)
