# b3dp.mw

*Ash falls on a dead island. Fires gutter in the dark. No one walks out of the dark. They are pulled.*

A first-person RPG in the spirit of **Morrowind**, built in **Godot 4.7** with GDScript: downsampled 90s textures, dingy colours, ash and fog, and a world that feels slightly wrong. Fire is life; the dark is death.

## The island
- **12 km of generated terrain** ([Terrain3D](https://github.com/TokisanGames/Terrain3D)): rolling grassland, desert dunes, marsh and banded, snow-capped mountains, rising out of a foam-edged sea.
- **Dead forests** of procedurally grown trees (the old giants hard as iron), copses of small dead trees you can cut, dead brush, wind-blown grass and scattered boulders.
- **Weather**: ash storms that blacken the sky and eat your torches, ground fog pooling in the hollows, smouldering stumps glowing in the dark.

## A living island
Every person, band, den and place on the island is simulated all the time, near you or not. Coming close only gives them a body: what they do loaded is exactly what they do off-screen.
- **Everyone is a character.** Nobody is placed by hand. Lost souls are pulled out of the dark toward lit fires; what someone is doing (living at a fire, wandering, mourning a grave, taking tolls, lying in ambush, collapsed and begging, hunting you) is just the state they're in, reached through their needs, traits and memories.
- **Nothing comes from nothing.** Every loaf, water skin, log, torch and coin is a real item that moves: carried, stored in crates and barrels, traded, stolen, looted from the dead.
- **Fire is the heart of it.** Fires burn real wood and grow with it, from bonfire to hearth to pyre, keeping more people and pulling more souls. Lighting one takes a spark, tinder, kindling and logs, and it can fail. Let it die and the camp scatters.
- **Camps live by their people.** Firekeepers, drawers, waterbearers, wickbearers, storytellers and ashwives fetch water, cut wood, bleed sap from the giants, hunt greyhorn herds and trade with neighbours. Cinder-thieves steal the fire's wood and run.
- **Nobody knows the whole island.** People remember what they've seen, a little wrong, tell each other round the fire, and send someone out exploring when no one knows where to look.
- **Minds.** Kindness, curiosity, greed, courage, piety, cruelty and despair. The dread in the dark shakes people; loss hardens some; old stories bring hope; the broken walk into the dark without a light.
- **Fate.** Rarely, something befalls a group: the grey cough, the Lightless passing in the night, a fouled spring, a sealed cache of the old world, an ill omen.

## The wanderer
- Morrowind-style character sheet: **attributes, skills that level with use**, health / stamina / magicka, hunger and thirst. Out of the light, dread and then death.
- **Melee by direction**: the last movement key you press picks the swing (chop, thrust, left or right sweep), and a hit only lands if the blade itself connects.
- **Spells** built from parts: a *delivery* (projectile, touch, self) plus a list of *effects* (damage, restore). Spit **Flame Breath** at your foes.
- **Live by the same rules as everyone**: feed a camp's fire to earn its trust, join it and take a role (and do its work), build your own fire, relight cold ones, chop, cut sap, trade, or steal, if no one's watching.
- Inventory, equipment, containers, tools that wear out, loot sacks and potions, all on a parchment-and-candlelight UI with no HUD bars: pain reddens the vignette, exhaustion blurs the edges.
- **Saves the whole island**: F5 save, F9 load, Shift+F9 a fresh island; autosaves.

## The things in the dark
- Goblin and orc dens that hunt herds and people when hungry, send packs out and hold false lights to lure travellers in.
- Bandits who raid camps, set tolls on the roads and send war bands out.

## Debug
Press **M** for an overhead map of the whole simulation (every fire, band, herd and chore, with log pulses where things happen); **N** to follow someone with the watch camera (mouse wheel picks All / Camps / Wanderers / Bandits / Monsters), **B** to come back; **[ ]** to change the sim's speed.

## Layout
`levels/` `player/` `characters/` `components/` `items/` `spells/` `world/` `effects/` `ui/` `assets/` `tools/`. The simulation lives in `world/` (`camps.gd` and its children: `minds`, `camplife`, `encounters`, `meetings`, `fate`). More detail in [NOTES.md](NOTES.md).

## Running
Open the project in Godot 4.7 (Forward+). The main scene is `levels/test_level.tscn`. Regenerate the island with
`godot --headless --path . -s res://tools/generate_terrain.gd`; fast-forward the simulation headless with
`godot --headless --path . -s res://tools/soak.gd`.

*Work in progress.*
