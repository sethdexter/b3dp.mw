extends MobModel
## A wanderer's body: one of the Mixamo-rigged ragged robes (assets/models/characters/wanderer/rig/<variant>.fbx,
## textures in rig/<variant>/), picked by who they are (the same person always wears the same one). The robes differ
## in cut, so each has its own rig; a variant not rigged yet falls back to umber.
## Clips come from rig/anims/ by filename (idle, walk, run, sit, work, hit, death). Camps sets `pose` from what
## the record's doing: "sit" (by the fire) and "work" (chopping, cutting, picking, filling).

const VARIANTS := ["umber", "bleached", "soot", "moss"]
const PARTS := ["head", "ear", "torso", "robe", "sleeve", "bracer", "hand", "leg", "shin", "foot"]

## Straightens the walk/run clips' forward lean (degrees back at the spine; negative leans further forward).

@export var walk_lean_fix := 12.0

## Tilts one bone after the animation has posed it.
class Tilt extends SkeletonModifier3D:
	var bone := -1
	var degrees := 0.0
	func _process_modification() -> void:
		var sk := get_skeleton()
		if sk and bone >= 0:
			sk.set_bone_pose_rotation(bone, sk.get_bone_pose_rotation(bone) * Quaternion(Vector3.RIGHT, deg_to_rad(-degrees)))

var _tilt: Tilt

func _ready() -> void:
	_build.call_deferred() # (Camps tags the body with its record just after it's added)

func _build() -> void:
	var f = null
	var n: Node = get_parent()
	while n and f == null:
		f = n.get_meta("folk") if n.has_meta("folk") else null
		n = n.get_parent()
	var v: String = VARIANTS[absi(hash(f.name)) % VARIANTS.size()] if f and f.name != "" else VARIANTS.pick_random()
	if not ResourceLoader.exists("res://assets/models/characters/wanderer/rig/%s.fbx" % v):
		v = "umber"
	model_scene = load("res://assets/models/characters/wanderer/rig/%s.fbx" % v)
	var dir := "res://assets/models/characters/wanderer/rig/%s/" % v
	for p in PARTS:
		material_textures[p] = load(dir + p + ".png")
	super._ready()
	var sk := model.find_children("*", "Skeleton3D", true, false)
	if sk:
		_tilt = Tilt.new()
		_tilt.bone = sk[0].find_bone("mixamorig_Spine")
		sk[0].add_child(_tilt)
	var glow: Texture2D = load(dir + "head_glow.png")
	for mi in _mesh_instances(model):
		for i in mi.get_surface_override_material_count():
			var m := mi.get_surface_override_material(i) as StandardMaterial3D
			if m == null:
				continue
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR # torn cloth: cut-outs, not blending
			m.cull_mode = BaseMaterial3D.CULL_DISABLED # you see the inside of the rags through the tears
			if m.albedo_texture == material_textures["head"]:
				m.emission_enabled = true
				m.emission_texture = glow

func _process(delta: float) -> void:
	super._process(delta)
	if _tilt and anim_player:
		var walking := anim_player.current_animation in [clips.get("walk", ""), clips.get("run", "")]
		_tilt.degrees = walk_lean_fix
		_tilt.influence = move_toward(_tilt.influence, 1.0 if walking else 0.0, delta / maxf(blend_time, 0.01))
