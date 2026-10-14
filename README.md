# b3dp.mw

*Ash falls on a dead island. Fires gutter in the rain. Something stirs between the twisted trees.*

A first-person RPG in the spirit of **Morrowind**, built in **Godot 4.7** with GDScript: downsampled 90s textures, dingy colours, ash and fog, and a world that feels slightly wrong.

## The island
- **12 km of generated terrain** ([Terrain3D](https://github.com/TokisanGames/Terrain3D)): rolling grassland, desert dunes, marsh and banded, snow-capped mountains, rising out of a foam-edged sea.
- **Dead forests** of procedurally grown trees, wind-blown alien grass and desert shoots, and scattered boulders.
- **Weather**: ash fall, rain with splashes, ashy fog, flickering torchlight and campfires with curling smoke.

## The wanderer
- Morrowind-style character sheet: **attributes, skills that level with use**, health / stamina / magicka.
- **Melee by direction**: the last movement key you press picks the swing (chop, thrust, left or right sweep), and a hit only lands if the blade itself connects.
- **Spells** built from parts: a *delivery* (projectile, touch, self) plus a list of *effects* (damage, restore). Spit **Flame Breath** at your foes.
- Inventory, equipment, containers, loot sacks and potions, all on a parchment-and-candlelight UI with no HUD bars: pain reddens the vignette, exhaustion blurs the edges.

## The things in the dark
- Goblins and orcs that wander, notice you, chase, telegraph their blows and leash home.
- Pathfinding baked around you as you roam, so they can follow you anywhere on the island.

## Layout
`levels/` `player/` `characters/` `components/` `items/` `spells/` `world/` `effects/` `ui/` `assets/` `tools/`. More detail in [NOTES.md](NOTES.md).

## Running
Open the project in Godot 4.7 (Forward+). The main scene is `levels/test_level.tscn`. Regenerate the island with
`godot --headless --path . -s res://tools/generate_terrain.gd`.

*Work in progress.*
