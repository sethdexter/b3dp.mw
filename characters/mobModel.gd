class_name MobModel
extends Node3D

## Instances an imported character model (FBX/GLB), scales it to `target_height`,
## stands it on the ground, applies textures by material name, and loops its animation
## with playback speed driven by how fast the mob moves (see MobAIComponent.animator).

@export var model_scene: PackedScene
## Final height in metres (model is uniformly scaled to fit).
@export var target_height: float = 1.8
## Turn the model if it faces the wrong way (mobs walk toward -Z).
@export var model_yaw_degrees: float = 0.0

@export_group("Textures")
## Used for any surface not matched below.
@export var albedo_default: Texture2D
## Material-name substring (case-insensitive) -> albedo texture, e.g. { "pPipe": weapon.png }.
@export var material_textures: Dictionary[String, Texture2D] = {}
@export var normal_map: Texture2D
## Keep the model's own imported materials instead (if its textures import fine).
@export var keep_imported_materials := false

@export_group("Animation")
## Extra clips from other files (e.g. one Mixamo FBX per animation), by role:
## "idle", "walk", "run", "attack", "hit", "death". Each scene's first animation is used.
## Clips must come from the same rig as the model (same bone names).
@export var animation_sources: Dictionary[String, PackedScene] = {}
## Or point at a folder of clip files and they're matched by filename:
## *idle*, *walk*, *run*, *attack*/*punch*/*slash*/*swing*, *hit*/*impact*/*react*, *death*/*dying*/*die*.
@export_dir var animations_folder: String = ""
## Or name clips already inside the model / its import slices, by role.
@export var clip_names: Dictionary[String, String] = {}
## Speeds (m/s) the walk/run clips were authored at, so feet don't slide.
@export var walk_clip_speed: float = 1.5
@export var run_clip_speed: float = 3.5
## Above this speed use the run clip (if there is one).
@export var run_threshold: float = 2.5
@export var blend_time: float = 0.2

@export_group("Fallback (no clips)")
## With a single unnamed animation: loop it, speed-scaled by movement.
@export var anim_reference_speed: float = 1.5
@export var idle_anim_speed: float = 0.15
## With no animation at all: bob + breathe procedurally.
@export var procedural_bob_height: float = 0.06
@export var procedural_breath: float = 0.015

var model: Node3D
var anim_player: AnimationPlayer

func _ready() -> void:
	if model_scene == null:
		push_warning("MobModel: no model_scene set.")
		return
	model = model_scene.instantiate() as Node3D
	# Exported scenes often carry their own lights/cameras/environments (the orc FBX
	# has a Blender "Light" and "Camera"). Strip them before they enter the tree,
	# or they blow out the level's lighting and can take over the view.
	_strip_scene_extras(model)
	add_child(model)
	model.rotation_degrees.y = model_yaw_degrees
	if not keep_imported_materials:
		_apply_materials(model)
	_fit_to_height()
	_setup_animation()

func _strip_scene_extras(root: Node) -> void:
	for child in root.get_children():
		if child is Light3D or child is Camera3D or child is WorldEnvironment:
			root.remove_child(child)
			child.free()
		else:
			_strip_scene_extras(child)

func _apply_materials(root: Node) -> void:
	var cache: Dictionary = {}
	for mi in _mesh_instances(root):
		if mi.mesh == null:
			continue
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			var mat_name := src.resource_name if src else ""
			var tex := _texture_for(mat_name)
			var key := str(tex)
			if not cache.has(key):
				var mat := StandardMaterial3D.new()
				mat.albedo_texture = tex
				mat.roughness = 0.9
				if normal_map:
					mat.normal_enabled = true
					mat.normal_texture = normal_map
				cache[key] = mat
			mi.set_surface_override_material(i, cache[key])

func _texture_for(mat_name: String) -> Texture2D:
	var lower := mat_name.to_lower()
	for key in material_textures:
		if lower.contains(key.to_lower()):
			return material_textures[key]
	return albedo_default

func _fit_to_height() -> void:
	var box := _combined_aabb()
	if box.size.y <= 0.0001:
		return
	var s := target_height / box.size.y
	model.scale = Vector3.ONE * s
	# Re-measure after scaling and stand it on y=0, centred.
	box = _combined_aabb()
	var c := box.get_center()
	model.position -= Vector3(c.x, box.position.y, c.z)

## AABB of all meshes, in this node's local space.
func _combined_aabb() -> AABB:
	var result := AABB()
	var first := true
	var inv := global_transform.affine_inverse()
	for mi in _mesh_instances(model):
		var box: AABB = (inv * mi.global_transform) * mi.get_aabb()
		if first:
			result = box
			first = false
		else:
			result = result.merge(box)
	return result

func _mesh_instances(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for child in root.get_children():
		out.append_array(_mesh_instances(child))
	return out

const ROLES := ["idle", "walk", "run", "attack", "hit", "death"]
const LIBRARY := "mob"

## role -> playable animation name
var clips: Dictionary[String, String] = {}
var _one_shot := ""          # attack/hit/death currently playing
var _dead := false
var _single_clip := ""       # fallback: only one unnamed animation
var _proc_time := 0.0
var _proc_speed := 0.0
var _model_rest_y := 0.0

func _setup_animation() -> void:
	_model_rest_y = model.position.y
	anim_player = _find_anim_player(model)
	if anim_player == null and not animation_sources.is_empty():
		# Model has no player of its own: add one beside the skeleton's root.
		anim_player = AnimationPlayer.new()
		model.add_child(anim_player)
	if anim_player == null:
		return
	anim_player.animation_finished.connect(_on_animation_finished)

	# 1. clips from separate files (explicit ones win over folder matches)
	var sources := _scan_animation_folder()
	sources.merge(animation_sources, true)
	var lib := AnimationLibrary.new()
	for role in sources:
		var anim := _first_animation(sources[role])
		if anim:
			anim = anim.duplicate()
			lib.add_animation(role, anim)
			clips[role] = LIBRARY + "/" + role
	if lib.get_animation_list().size() > 0:
		anim_player.add_animation_library(LIBRARY, lib)

	# 2. clips named inside the model
	for role in clip_names:
		if anim_player.has_animation(clip_names[role]):
			clips[role] = clip_names[role]

	# Loop the locomotion clips; one-shots play once.
	for role in clips:
		var a := anim_player.get_animation(clips[role])
		a.loop_mode = Animation.LOOP_LINEAR if role in ["idle", "walk", "run"] else Animation.LOOP_NONE

	if clips.is_empty():
		var names := anim_player.get_animation_list()
		if not names.is_empty():
			_single_clip = names[0]
			anim_player.get_animation(_single_clip).loop_mode = Animation.LOOP_LINEAR
			anim_player.play(_single_clip)
			anim_player.speed_scale = idle_anim_speed
		return
	_play_role("idle")

const ROLE_KEYWORDS := {
	"idle": ["idle"],
	"walk": ["walk"],
	"run": ["run", "sprint"],
	"attack": ["attack", "punch", "slash", "swing", "strike"],
	"hit": ["hit", "impact", "react"],
	"death": ["death", "dying", "die"],
}

func _scan_animation_folder() -> Dictionary[String, PackedScene]:
	var found: Dictionary[String, PackedScene] = {}
	if animations_folder == "":
		return found
	var dir := DirAccess.open(animations_folder)
	if dir == null:
		push_warning("MobModel: can't open animations_folder %s" % animations_folder)
		return found
	for file in dir.get_files():
		file = file.trim_suffix(".remap").trim_suffix(".import")
		var ext := file.get_extension().to_lower()
		if ext not in ["fbx", "glb", "gltf", "blend"]:
			continue
		var lower := file.to_lower()
		for role in ROLE_KEYWORDS:
			if found.has(role):
				continue
			for kw in ROLE_KEYWORDS[role]:
				if lower.contains(kw):
					var scene := load(animations_folder.path_join(file)) as PackedScene
					if scene:
						found[role] = scene
					break
	return found

func _first_animation(scene: PackedScene) -> Animation:
	if scene == null:
		return null
	var inst := scene.instantiate()
	var player := _find_anim_player(inst)
	var anim: Animation = null
	if player:
		var names := player.get_animation_list()
		for n in names:
			if n != "RESET":
				anim = player.get_animation(n)
				break
	inst.free()
	return anim

func _play_role(role: String, custom_speed: float = 1.0) -> bool:
	if not clips.has(role):
		return false
	var name_ := clips[role]
	if anim_player.current_animation != name_:
		anim_player.play(name_, blend_time)
	anim_player.speed_scale = custom_speed
	return true

func _on_animation_finished(anim_name: StringName) -> void:
	if _one_shot != "" and String(anim_name) == clips.get(_one_shot, ""):
		if _one_shot == "death":
			return # hold the last frame
		_one_shot = ""
		_play_role("idle")

func _find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root
	for child in root.get_children():
		var found := _find_anim_player(child)
		if found:
			return found
	return null

## Called by MobAIComponent every physics frame with the mob's horizontal speed.
func set_move_speed(speed: float) -> void:
	_proc_speed = speed
	if anim_player == null or _dead:
		return
	if _single_clip != "":
		anim_player.speed_scale = maxf(idle_anim_speed, speed / maxf(0.01, anim_reference_speed))
		return
	if _one_shot != "":
		return
	if speed < 0.2:
		_play_role("idle")
	elif speed >= run_threshold and clips.has("run"):
		_play_role("run", speed / run_clip_speed)
	elif clips.has("walk"):
		_play_role("walk", speed / walk_clip_speed)
	elif clips.has("run"):
		_play_role("run", speed / run_clip_speed)

## True if this model has a real clip for the role (MobAI/TrainingDummy skip their tween fakes).
func has_clip(role: String) -> bool:
	return clips.has(role)

func play_attack() -> bool:
	return _play_one_shot("attack")

func play_hit() -> bool:
	return _play_one_shot("hit")

func play_death() -> bool:
	_dead = true
	return _play_one_shot("death")

func _play_one_shot(role: String) -> bool:
	if anim_player == null or not clips.has(role):
		return false
	_one_shot = role
	anim_player.play(clips[role], blend_time * 0.5)
	anim_player.speed_scale = 1.0
	anim_player.seek(0.0, true)
	return true

## Freeze the animation (death without a death clip).
func stop_animation() -> void:
	_dead = true
	if anim_player and not clips.has("death"):
		anim_player.pause()

## Procedural life for models with no animation at all (e.g. the unrigged orc).
func _process(delta: float) -> void:
	if model == null or anim_player != null or _dead:
		return
	_proc_time += delta
	var moving := clampf(_proc_speed / 1.5, 0.0, 1.0)
	# Footstep bob while moving, slow breathing while still.
	var step := absf(sin(_proc_time * (4.0 + _proc_speed * 2.5))) * procedural_bob_height * moving
	var breath := sin(_proc_time * 1.6) * procedural_breath * (1.0 - moving)
	model.position.y = _model_rest_y + step
	model.scale.y = model.scale.x * (1.0 + breath)
