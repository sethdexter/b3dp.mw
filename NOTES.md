# b3dp.mw — project notes

Godot 4.7 first-person RPG prototype (Morrowind-style). GDScript. Main scene: `levels/test_level.tscn`.
Repo: github.com/sethdexter/b3dp.mw (branch main). Big source art (`*.blend`, `*.psd`) is gitignored.

## Folder layout (by feature)
`levels/` `player/` `characters/` (+`mobs/`) `components/` `items/` (`data/`, `scenes/`) `spells/` (`data/`, `effects/`, `delivery/`, `projectile/`)
`world/` (terrain data, foliage, trees, water, `props/`) `effects/` (fire, smoke, shaders) `ui/` `assets/` (raw art: models, textures, sky, fonts, terrain) `tools/`.
Spells: a `Spell` = cost + one `SpellDelivery` (projectile/self/touch) + a list of `SpellEffect`s (damage, restore). Potions use the same effects.

## Working conventions
- Edit files directly in this folder. Close a script in the Godot editor before external edits, or it may save its old copy over them.
- Watch for load cycles: don't `preload` scenes that lead back to the preloading script (caused "non-existent resource" errors). Use `load()` at runtime instead.
- Item data is shared through `Item.get_template()`: per-instance copies are made with `make_instance()`, and held/equip/consume values are read from the original `.tres`.
- The player is in group `"player"`. `BaseCharacter.is_dead` locks input and AI.

## Character architecture (BaseCharacter + component nodes)
`characters/basecharacter.gd`: exports refs to the components below, plus `starting_items`.
- `attributesComponent`: strength, vigor, agility, intelligence, wisdom (`base_*` exports, `get_attribute(name)`).
- `statsComponent`: health (str/vig), stamina (vig/agi), magicka (int/wis). Regen, `spend_stamina`, `has_stamina`, `restore_all`. Emits `s_has_died`.
- `skillsComponent`: 12 skills (`get_skill(id)`). `Skill` levels from XP (`add_xp`).
- `combatComponent`: `attack()` uses the equipped weapon and its best damage type, scaled by attribute + skill; `take_damage()` subtracts armour (piece × armour-skill bonus) and trains armour skills.
- `inventoryComponent`: `Dictionary[Item, int]` stacks; respects `maxStackCount`, overflow creates new stacks.
- `equipmentComponent`: slots right_hand/left_hand/head/chest/feet/back; applies attribute modifiers; `get_weapon()`, `get_armor_pieces()`.
- `controllerComponent`: movement (walk toggle Caps, sprint Shift, dash Alt, eased; stamina costs), mouse look, E interact via raycast.
- `meleeComponent` (LMB swing), `spellCasterComponent` (RMB "cast", `Spell` resources in `spells/data`), `heldItemsComponent` (first-person held items), `respawnComponent` (death fade + respawn).

## UI (`ui/`)
- `itemListView.gd`: shared list (chest bottom-left, player bottom-right). Parchment text, highlight sized to the text.
- `playerInventoryUI`: Tab open, wheel select, RMB switch side, LMB take/store/equip/use, Q drop (Shift = stack).
- `screenEffects`: no HUD bars. Health = red vignette, desaturation, heartbeat; magicka = desaturation; stamina = blur + breathing edges; `fade_to()`.

## Items
`items/item.gd` (Item), `weaponItem.gd`, registry autoload `item_list` (`items/itemDB.gd`, keyed by id string). Item data in `items/data/`.
Items: torch, swords, leather cap/cuirass, iron boots, travel cloak, potions; food (bread, dried meat, greyhorn meat, ash cap, blackflesh, ash wine, water skin); materials (ash wood, kindling, tinder, resin, bone, sinew, hide, cloth, scrap metal, salt, spores, carcasses); tools that wear (`tool` + `durability`, `items/tools.gd`: hatchet "axe", bone knife "knife", flint "spark"); coin; sunken key.
World pickups: `InteractableComponent` (itemId, or a runtime `item`). Dropped items: `items/scenes/droppedItem.tscn`.

## Mobs
- `mobAIComponent`: idle → wander → chase (sight/aggro on hit) → attack (telegraph) → return (leash). Direct steering, no navmesh yet.
- `trainingDummy.gd`: hit wobble/knockdown; `respawns=false` for real mobs (corpse sinks, then freed). `loot` (id → amount) spawns DroppedItems on death (goblin: rusty sword + health potion; orc: black iron sword + 2 stamina potions).
- `mobModel.gd`: instances an FBX, strips lights/cameras, fits height, applies textures by material name, plays clips by role (idle/walk/run/attack/hit/death) from `animations_folder` (matched by filename) or `animation_sources`; procedural bob if no clips.
- Mobs: `characters/mobs/goblin.tscn`, `orc.tscn`. Old dummies: `trainingDummy.tscn`, `bruteDummy.tscn`.
- Art: `assets/models/characters/goblin|orc`. Clips go in `anims/` (Mixamo, In Place, FBX with skin). The orc is unrigged; its real colour texture is missing (using one extracted from ogre15).

## Folk bodies
- `characters/folk/drifter.tscn` / `bandit.tscn`: BaseCharacter + mobAI (drifters `aggressive=false`, fight back when hit) + `talker.gd` (look + E: greeting, rumours, jobs, trade wares). `folkFigure.gd` = placeholder hooded figure (swap for real models later).
- Needs on the player: `components/needsComponent.gd` (hunger/thirst; rates shared with Minds). Darkness: `components/darknessComponent.gd` (light = a campfire's `light_radius` or a lit torch; dark drains stamina then health; you heal resting at a fire).

## The island sim: architecture
Everything is records; nodes are only the view. `world/camps.gd` (node "Camps") owns them and makes these runtime children:

| child | file | job |
|---|---|---|
| `minds` | `world/minds.gd` | each character's needs / traits / memories, `think()`, state changes (`_become`), dark + hunger wear, death, camp rep |
| `camplife` | `world/camplife.gd` | real items: packs, barrels, crates, eating, chores, fires, roles, torches, lighting, trade, travellers (`steer`) |
| `encounters` | `world/encounters.gd` | the bleak states and places (rules + visuals), ash storm, you making / relighting / joining fires |
| `meetings` | `world/meetings.gd` | groups meeting on a coarse grid: raids, sharing, merging, looting, relighting |
| `clock` | `world/simClock.gd` | sim time (`SimClock.now`), `[` `]` speed |
| `fate` | `world/fate.gd` | rare events on any group: grey cough (sickness, spreads; ashwife cures faster), the Lightless (fire half snuffed), foul water, old-world cache, ill omen, scattered herd |
| `save` | `world/saveGame.gd` | F5 save, F9 load, Shift+F9 fresh island, autosave; add new record fields to `save()` / `load_world()` |

- **Records.** `Camp` = any group or place, keyed by `wild`: "" = a fire's camp; wanderer, pilgrims, mourner, toll, ambush, starved, stalker, pack, lurer/falselight, homeward; places: remains, cairn, hanged, coldfire, spring, fungus, salt, bell, herd, copse, sap, sack, starved_dead. `Camp.job` holds per-record state (fire_fuel, roles, stock, count/max, lit_until...). `Folk` = a character (needs, traits, memories, hp, inv, task).
- **Sweep.** `records_per_frame` records per frame tick whether you're near or not (`_tick_camp`, `_tick_band`, `_tick_spot`, `minds.think`, `camplife.step`). Within `spawn_radius` (120 m) records get real nodes (freed past `despawn_radius`). Loaded = sim: bodies walk the record's path, share its health (`_hp_from_body` / `_hp_to_body`), carry its exact pack; fights near you are real, far ones are dice.
- **Everyone is a character.** Nobody is placed: the world places camps (one per `cell_size` cell, `camp_chance`) and places (`encounter_cell` grid). New people are pulled out of the dark toward lit fires / cairns (`_pull`, `souls_target`; bigger fires pull more, a storyteller sometimes brings an extra). Monster dens regrow when their larder is fed. The dead stay dead and leave a body place (`leave_body`) or a sack.
- **States, not roles.** What a character is doing is the state of its group (`Camp.wild`); every state has a way in and out (minds `_decide_in_camp`, `_become`, encounters, `_tick_band`). Bands carry torches and only go where their torch reaches (`_reach`).
- **Knowing the island.** Nobody is omniscient: each Folk remembers places it has seen (`Folk.known` = [place, remembered pos], off by up to `misremember`, `memory_size` per kind of place; minds `look` every `look_every` within `sight_range`; a camp's people start knowing `known_start` round it, the pulled know nothing). Chores and travellers go where they remember (`minds.recall`); seeing it corrects it; not there = cast about (`search_radius`, `search_tries`) then forget. Nothing known = an explore chore (`explore_range`). Monster packs smell herds, else go to one they remember. Fires are seen from afar (no memory needed). Loaded bodies steer round tree trunks (`mobAI._round_trees`; the trees aren't in the navmesh).
- **Nothing from nothing.** Every item is real and moves: packs (`Folk.inv`), camp `barrel` / `crate`, place stocks. Near you crates, barrels and displays are the same store (`world/props/campStoreSync.gd`, `campDisplay.gd`); traders sell their camp's crate. Coin, food and water move by trade, raids, theft and gifts.

## Resources (food chain)
- **Water:** springs (SOURCES stock, regrow; bare ones regrow slower). Camps without a spring in reach move (evacuate); new fires only near a spring (`_room_for_fire`). Water is the island's limit.
- **Food:** ash fungus; greyhorn herds (breed toward `herd_cap`, split, drift, flee you; hunting gives meat; real bodies near you). Blackflesh (monster meat) only when starving, with costs. Monsters hunt herds and people and feed their den larder.
- **Wood:** copses of small trees, the only wood that cuts (logs + kindling + tinder; they regrow). Giant trees are iron-hard.
- **Resin (sap):** only from sap nodes on giant trees (`wild "sap"`; a knife for you, the sap chore for drawers). Makes torches, renews spent ones.
- **Salt, coin, goods:** salt crusts; coin and goods start in camp crates (`goods_start`) and only move after that.

## Fire (the heart of it)
- A camp fire burns `job.fire_fuel` (one log = `wood_burn`); its people feed it from the crate (`camplife._tend_fire`). No wood = `Camps.fire_out`: cold fire, the camp leaves as a band. Storms burn it a bit faster (`storm_fire_burn`). Raids hurt it only through stolen stores and dead keepers.
- **Size:** logs on it (`fire_logs`) = flame/light scale (`fireFeed.gd` sets `light_radius`), `capacity` (`people_per_log` each) and tier: **bonfire** below `hearth_logs`, **hearth** below `pyre_logs`, then **pyre**. A hearth also needs a firekeeper + storyteller, a pyre every role (`log_cap`). Firekeepers keep `keeper_spare` logs extra so fires can grow. Names everywhere: `fire_name()` = "Drifter hearth".
- **Crowding:** more people than capacity = someone leaves (`crowded_leave`); full fires take no settlers.
- **Lighting:** spark (lit torch or flint) + tinder + kindling + `light_logs` logs; catches at `light_chance` (worse in storms); failure burns the tinder. Embers after a long burn relight with kindling + logs. Same for NPCs (`can_light` / `_light`) and you.
- **Torches:** one burns `TorchBurn.burn_time`, chain-lit from the next; made from logs + resin (`sap_per_log`; a wickbearer gets `torches_per_log`, else 1); resin renews a spent one. Bandit torches last `bandit_torch` x. Chores take torches for the trip (no torch, no chore).

## Camps and roles
- **Chores** (`camplife._plan`, every `plan_every` s): water, forage/hunt, wood, sap, trade, supply (drifters help hungry camps), evacuate. The fittest goes, or the role holder. Camps start lean (`barrel_per_person`, `crate_per_person`) so they go out early.
- **Roles** (`ROLES`, `Camp.job.roles`): firekeeper (never leaves; grows the fire), drawer (wood, sap), waterbearer (water), wickbearer (torches), storyteller (hearth+: belonging up, despair down, pulls souls), ashwife (heals faster).
- **Crime:** cinder-thief NPCs steal the wood and run (`cinder_chance` / `cinder_caught`). You stealing in sight (`theft_sight`) = cinder-thief: rep -100, they attack.
- **Travellers:** bands seek springs / fungus / fires by need, rest at fires for `rest_time`, take `road_share` from their camp, buy what they lack.
- **Start camp:** the start scene's campfire is a real drifter camp (`start_camp`, `start_people`).

## You in the sim
- Same rules as everyone: your hunger / thirst / dark rates are theirs; you heal at fires; torches burn the same.
- **E** on a fire: feed a log (raises rep). **G**: make your own fire. Relight cold fires (walk up with the makings). **J** at a drifter fire: join (needs `join_rep` and room); J again: take the next role (its effect is yours; the holder steps aside). Members share the stores.
- Trade with any talker (their camp's crate, or their pack on the road); steal and you may be seen. Jobs from talkers; rep per camp (`hates` = attack).
- Chop small trees (E, hatchet faster, loud), cut sap (knife), drink / fill at springs, pick fungus, hunt greyhorns.

- **The mind** (minds "The mind" sliders): traits greed, courage, piety, cruelty, despair, kindness (who shares / carries food), curiosity (who explores, how far they notice). States in `Folk.job.<state>_until`: shaken (dread, raids, the Lightless, a killing: no chores, safety slow), hardened (kept their nerve after losing kin: braver for good), hopeful (long at a told-to hearth/pyre: despair eases), broken (despair >= `broken_at`: may walk into the dark without a light). Talkers say state lines (`state_lines`).
- **Duties:** a role you hold is work you owe (camplife `_duties`, `credit`): firekeeper/storyteller be at the fire, drawer bring wood/resin/kindling/tinder, waterbearer water skins, wickbearer torches, ashwife food/potions, into your camp's stores at least every `duty_time`, or they give it to someone else (rep -5).
- **Joining bandits:** J works at bandit fires too; your camp's people never attack you. Bad blood fades (+1 rep per `rep_heal_every`); a cinder-thief is forgiven after `forgive_after`.
- **Shared knowledge:** people at a fire (every plan) and on the road tell each other what they've seen (`minds.share`).
- **Poses:** loaded bodies chop/cut/pick while working a chore, sit by their fire when idle there, and show their role in their name (`Camps._pose`, look only).


## Look
- Ground fog: cheap height fog laid at your feet (encounters `ground_fog_height` / `ground_fog_density`), hollows fill with it; no volumetrics.
- Dead brush: `deadTrees.gd` scatters `brush_count` squat dead shrubs (chunked MultiMesh, no colliders, no shadows, drawn to `brush_view`).
- Smoulders (camps `smoulders`, `smoulder_radius`): charred stumps with a low unshadowed glow. Near one the dark holds off (DarknessComponent group "reprieve"; minds skips dark wear) but nothing heals: a reprieve only.

## Debug map (M)
- `ui/simMap.gd`: island, places (redrawn every 2 s), fires (dot size = tier, gold ring = pyre, white = yours), people, chores, raids, log pulses. N / Shift+N watch the next character; mouse wheel (map open) picks the category (All / Camps / Wanderers / Bandits / Monsters); B back to you. While the map or watch is up you can't die.
- `tools/soak.gd`: headless fast-forward report (fires, tiers, sap, deaths). Deletes the save first.

## Open / next
- Small magics (Kindle, Mend, Dew, Ward, Sense): every spell costs reagents.
- Crafting (recipes drafted: torch, kindling, flint, bone knife, hatchet, staff, dried meat, water skin, cloak, leather, salve).
- Roles you hold carry no duties yet; bandit camps can't be joined; tinder doesn't get damp; NPC sap needs no knife.
- Loaded visuals: wanderers are Mixamo-rigged (rig/umber.fbx + rig/anims, sit/work from Camps._pose); bleached/soot/moss robes still need their own rigs; roles invisible. Rig + animate goblin/orc (art, the user's).
- Navmesh pathfinding, more mob types.
