# Bakes an island (desert, grassland, marsh, mountains) heightmap + texture control map into Terrain3D data.
# Run: godot --headless --path . -s res://tools/generate_terrain.gd
extends SceneTree

const SIZE := 6144 # heightmap pixels per side (Terrain3D caps a map at 32 x 256 = 8192)
const SPACING := 2.0 # metres per pixel -> 12 km x 12 km
const MOUNTAIN_HEIGHT := 1800.0 # tallest ranges; others are scaled down by the variety noise
const PEAK_SOFT_CAP := 1000.0 # heights above this are squashed to 40%
const SEA_LEVEL := -10.0 # keep in sync with the Sea node in test_level.tscn
const ISLAND := Vector2(0.6, 0.9) # coast starts / ends, as a fraction of the map half-width
const SPAWN_FLAT := Vector2(100.0, 400.0) # flat radius around origin, blend distance
const SPAWN_NO_MOUNTAINS := Vector2(400.0, 1000.0) # no mountains within this, full mountains beyond
const OUT_DIR := "res://terrain/data"

func _initialize() -> void:
	var biome := _noise(0.0005, 3, FastNoiseLite.FRACTAL_FBM, 1)
	var wet := _noise(0.0012, 2, FastNoiseLite.FRACTAL_FBM, 5)
	var ridges := _noise(0.00045, 5, FastNoiseLite.FRACTAL_RIDGED, 2)
	var dunes := _noise(0.02, 3, FastNoiseLite.FRACTAL_FBM, 3)
	var hills := _noise(0.0012, 4, FastNoiseLite.FRACTAL_FBM, 4)
	var variety := _noise(0.0004, 2, FastNoiseLite.FRACTAL_FBM, 7) # flat plains vs hilly country, low vs high ranges
	var bumps := _noise(0.01, 3, FastNoiseLite.FRACTAL_FBM, 8)
	var swells := _noise(0.004, 3, FastNoiseLite.FRACTAL_FBM, 11) # mid-size hills so no area is flat
	var coast := _noise(0.001, 3, FastNoiseLite.FRACTAL_FBM, 6)
	var breakup := _noise(0.008, 4, FastNoiseLite.FRACTAL_FBM, 9) # ragged texture borders
	var patches := _noise(0.015, 3, FastNoiseLite.FRACTAL_FBM, 10) # dirt in grass, scrub in desert

	# texture ids, matching the texture_list order in test_level.tscn
	const GRASS := 0
	const SAND := 1
	const MARSH := 2
	const ROCK := 3
	const SNOW := 4
	const ROCK_DARK := 5
	const ROCK_LIGHT := 6
	var enc_base := Terrain3DUtil.enc_base(1) # control map bit layout, as multipliers
	var enc_overlay := Terrain3DUtil.enc_overlay(1)
	var enc_blend := Terrain3DUtil.enc_blend(1)

	var heights := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	var base := PackedByteArray() # pass 1 picks the two strongest biome textures per pixel...
	var over := PackedByteArray()
	var blend := PackedByteArray()
	base.resize(SIZE * SIZE)
	over.resize(SIZE * SIZE)
	blend.resize(SIZE * SIZE)
	var w := PackedFloat32Array([0, 0, 0, 0, 0])
	var half := SIZE / 2
	for y in SIZE:
		for x in SIZE:
			var dist := Vector2(x - half, y - half).length() * SPACING
			var r := dist / (half * SPACING) + coast.get_noise_2d(x, y) * 0.15
			var land := 1.0 - smoothstep(ISLAND.x, ISLAND.y, r) # 1 inland, 0 open sea

			# biome weights: desert on low biome values, mountains on high, grassland between
			var b := biome.get_noise_2d(x, y)
			var w_desert := 1.0 - smoothstep(-0.3, -0.1, b)
			var w_mount := smoothstep(-0.05, 0.45, b) * smoothstep(SPAWN_NO_MOUNTAINS.x, SPAWN_NO_MOUNTAINS.y, dist)
			var w_grass := maxf(0.0, 1.0 - w_desert - w_mount)
			var w_marsh := w_grass * smoothstep(0.15, 0.35, wet.get_noise_2d(x, y)) # wet patches of grassland

			var v := smoothstep(-0.4, 0.4, variety.get_noise_2d(x, y))
			var rolling := 30.0 + hills.get_noise_2d(x, y) * lerpf(35.0, 100.0, v) + swells.get_noise_2d(x, y) * 15.0 + bumps.get_noise_2d(x, y) * 4.0
			var desert := 15.0 + hills.get_noise_2d(x, y) * 30.0 + swells.get_noise_2d(x, y) * 10.0 + absf(dunes.get_noise_2d(x, y)) * 10.0
			var mount := rolling + pow(ridges.get_noise_2d(x, y) * 0.5 + 0.5, 1.5) * MOUNTAIN_HEIGHT * lerpf(0.35, 1.0, v) # ^1.5 keeps broad bases with valleys between
			if mount > PEAK_SOFT_CAP:
				mount = PEAK_SOFT_CAP + (mount - PEAK_SOFT_CAP) * 0.4 # flatten only the tallest peaks
			var h := rolling * w_grass + desert * w_desert + mount * w_mount
			h = lerpf(h, 2.0, w_marsh) # marsh sits just above the sea
			h = lerpf(-40.0, h, land) + SEA_LEVEL
			h = lerpf(-1.0, h, smoothstep(SPAWN_FLAT.x, SPAWN_FLAT.y, dist)) # sit under the existing level
			var i := y * SIZE + x
			heights[i] = h

			# texture weights: like the biome weights but wider and noisier, so textures bleed into each other
			var n := breakup.get_noise_2d(x, y)
			var bt := b + n * 0.3
			var t_desert := 1.0 - smoothstep(-0.55, 0.05, bt)
			var t_mount := smoothstep(-0.1, 0.55, bt) * smoothstep(SPAWN_NO_MOUNTAINS.x, SPAWN_NO_MOUNTAINS.y, dist)
			var t_grass := maxf(0.0, 1.0 - t_desert - t_mount)
			var t_marsh := t_grass * smoothstep(0.05, 0.4, wet.get_noise_2d(x, y) + n * 0.35)
			var patch := smoothstep(-0.1, 0.6, patches.get_noise_2d(x, y) + n * 0.3)
			var beach := 1.0 - smoothstep(SEA_LEVEL + 1.0, SEA_LEVEL + 10.0, h + n * 8.0)
			var snow := smoothstep(900.0, 1400.0, h + n * 300.0)
			var keep := (1.0 - beach) * (1.0 - snow)
			w[GRASS] = ((t_grass - t_marsh) + t_desert * patch * 0.6) * keep
			w[MARSH] = t_marsh * keep
			w[SAND] = (t_desert + t_grass * patch * 0.8) * keep + beach
			w[ROCK] = t_mount * keep
			w[SNOW] = snow
			var a := 0
			for t in 5:
				if w[t] > w[a]: a = t
			var c := 1 if a == 0 else 0
			for t in 5:
				if t != a and w[t] > w[c]: c = t
			base[i] = a
			over[i] = c
			blend[i] = int(255.0 * w[c] / maxf(w[a] + w[c], 0.001))
		if y % 512 == 0:
			print("rows %d / %d" % [y, SIZE])

	# ...pass 2 lays rock over steep slopes, paints mountain strata / crevices / ridges, then packs the control bits
	const K := 4 # curvature sample offset in pixels
	var control := PackedInt32Array()
	control.resize(SIZE * SIZE)
	for y in SIZE:
		for x in SIZE:
			var i := y * SIZE + x
			var gx := heights[mini(i + 1, SIZE * SIZE - 1)] - heights[maxi(i - 1, 0)]
			var gy := heights[mini(i + SIZE, SIZE * SIZE - 1)] - heights[maxi(i - SIZE, 0)]
			var steep := int(255.0 * smoothstep(0.6, 1.1, sqrt(gx * gx + gy * gy) / (2.0 * SPACING))) # ~30-48 degrees
			var o := over[i]
			var bl := blend[i]
			var bs := base[i]
			if bs != ROCK and bs != SNOW and steep > bl:
				o = ROCK
				bl = steep
			elif bs == ROCK and o != SNOW and x >= K and y >= K and x < SIZE - K and y < SIZE - K:
				# strata: broad noisy bands of pale rock by height (soft like the snow line), plus ridges;
				# crevices pull toward dark rock. Signed so light and dark meet at zero blend, no seams.
				var n := breakup.get_noise_2d(x, y)
				var light := 0.5 + 0.5 * sin((heights[i] + n * 150.0) * 0.025)
				var lap := (heights[i - K] + heights[i + K] + heights[i - K * SIZE] + heights[i + K * SIZE]) * 0.25 - heights[i]
				var t := light * 0.7 + smoothstep(0.3, 3.0, -lap) * 0.3 - smoothstep(0.3, 3.0, lap)
				o = ROCK_LIGHT if t >= 0.0 else ROCK_DARK
				bl = int(200.0 * minf(absf(t), 1.0))
			control[i] = bs * enc_base | o * enc_overlay | bl * enc_blend

	var height := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RF, heights.to_byte_array())
	var control_img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RF, control.to_byte_array())

	var terrain := Terrain3D.new()
	terrain.set_collision_enabled(false) # headless bake only; the scene node has its own collision
	root.add_child(terrain)
	await process_frame # root only enters the tree once the main loop starts
	terrain.vertex_spacing = SPACING
	terrain.data.import_images([height, control_img, null], Vector3(-half * SPACING, 0, -half * SPACING), 0.0, 1.0)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	terrain.data.save_directory(OUT_DIR)
	print("regions: %d, height at 1km,1km: %.1f, at 3.9km: %.1f" % [terrain.data.get_region_count(),
		terrain.data.get_height(Vector3(1000, 0, 1000)), terrain.data.get_height(Vector3(3900, 0, 0))])
	quit()

func _noise(freq: float, octaves: int, fractal: int, seed_: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed_
	n.frequency = freq
	n.fractal_octaves = octaves
	n.fractal_type = fractal
	return n
