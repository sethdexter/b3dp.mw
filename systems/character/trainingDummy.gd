class_name TrainingDummy
extends Node

## Training dummy reactions: wobbles when hit, topples over at 0 health
## (sets is_dead so its MobAIComponent stops), then stands back up with full health.
## Movement, aggro and attacks live in the sibling MobAIComponent.

@export var character: BaseCharacter
## Node that wobbles/topples (pivot should be at the dummy's feet).
@export var visual: Node3D
## Stands back up after respawn_time (training dummy). Off = stays dead, then despawns.
@export var respawns := true
@export var respawn_time: float = 3.0
## Seconds a corpse lies there before sinking away (when respawns is off).
@export var corpse_time: float = 10.0
@export var wobble_degrees: float = 12.0
## Items dropped on death when respawns is off (item_list id -> amount).
@export var loot: Dictionary[String, int] = {}

@onready var _collision: CollisionShape3D = character.get_node_or_null("CollisionShape3D") if character else null
@onready var _ai: MobAIComponent = _find_ai()

var _wobble: Tween
var _last_health := -1

func _ready() -> void:
	if not character:
		character = get_parent() as BaseCharacter
	if not character or not character.statComponent:
		push_error("TrainingDummy: needs a BaseCharacter parent with a StatsComponent.")
		return
	var health: Stat = character.statComponent.health
	_last_health = health.currentValue
	health.value_changed.connect(_on_health_changed)
	health.depleted.connect(_on_depleted)

func _find_ai() -> MobAIComponent:
	if not character:
		return null
	for child in character.get_children():
		if child is MobAIComponent:
			return child
	return null

func _on_health_changed(current: int, _max_val: int) -> void:
	var attacking := _ai != null and _ai.is_attacking
	if _last_health >= 0 and current < _last_health and not character.is_dead and not attacking:
		var model := _find_mob_model()
		if not (model and model.play_hit()):
			_play_wobble()
	_last_health = current

func _play_wobble() -> void:
	if not visual:
		return
	if _wobble and _wobble.is_valid():
		_wobble.kill()
	visual.rotation_degrees.x = 0.0
	_wobble = create_tween()
	_wobble.tween_property(visual, "rotation_degrees:x", -wobble_degrees, 0.06)
	_wobble.tween_property(visual, "rotation_degrees:x", wobble_degrees * 0.5, 0.12)
	_wobble.tween_property(visual, "rotation_degrees:x", 0.0, 0.18)

func _on_depleted() -> void:
	if character.is_dead:
		return
	character.is_dead = true
	print("%s is knocked down." % character.Name)
	if _wobble and _wobble.is_valid():
		_wobble.kill()
	if _collision:
		_collision.set_deferred("disabled", true)
	# Death clip if the model has one, else topple the whole visual over.
	var model := _find_mob_model()
	var animated := model != null and model.play_death()
	if model and not animated:
		model.stop_animation()
	if visual and not animated:
		var fall := create_tween()
		fall.tween_property(visual, "rotation_degrees:x", -85.0, 0.5) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if not respawns:
		_drop_loot()
		await get_tree().create_timer(corpse_time).timeout
		var sink := create_tween()
		sink.tween_property(character, "global_position:y", character.global_position.y - 2.0, 2.0)
		await sink.finished
		character.queue_free()
		return
	await get_tree().create_timer(respawn_time).timeout
	_stand_up()

func _drop_loot() -> void:
	for id in loot:
		var item: Item = item_list.get_item_instance(id)
		if not item:
			continue
		var dropped: DroppedItem = load("res://systems/items/droppedItem.tscn").instantiate()
		get_tree().current_scene.add_child(dropped)
		var dir := Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
		dropped.setup(item, loot[id], character.global_position + Vector3.UP + dir * 0.3, dir)

func _find_mob_model() -> MobModel:
	if visual:
		for child in visual.get_children():
			if child is MobModel:
				return child
	return null

func _stand_up() -> void:
	var health: Stat = character.statComponent.health
	health.change_current(health.get_max_value())
	_last_health = health.currentValue
	if visual:
		var rise := create_tween()
		rise.tween_property(visual, "rotation_degrees:x", 0.0, 0.6) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		await rise.finished
	if _collision:
		_collision.disabled = false
	character.is_dead = false
