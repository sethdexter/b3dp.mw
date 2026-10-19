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
Items: torch, swords, leather cap/cuirass (light), iron boots (heavy), travel cloak, health/magicka/stamina potions.
World pickups: `InteractableComponent` (itemId, or a runtime `item`). Dropped items: `items/scenes/droppedItem.tscn`.

## Mobs
- `mobAIComponent`: idle → wander → chase (sight/aggro on hit) → attack (telegraph) → return (leash). Direct steering, no navmesh yet.
- `trainingDummy.gd`: hit wobble/knockdown; `respawns=false` for real mobs (corpse sinks, then freed). `loot` (id → amount) spawns DroppedItems on death (goblin: rusty sword + health potion; orc: black iron sword + 2 stamina potions).
- `mobModel.gd`: instances an FBX, strips lights/cameras, fits height, applies textures by material name, plays clips by role (idle/walk/run/attack/hit/death) from `animations_folder` (matched by filename) or `animation_sources`; procedural bob if no clips.
- Mobs: `characters/mobs/goblin.tscn`, `orc.tscn`. Old dummies: `trainingDummy.tscn`, `bruteDummy.tscn`.
- Art: `assets/models/characters/goblin|orc`. Clips go in `anims/` (Mixamo, In Place, FBX with skin). The orc is unrigged; its real colour texture is missing (using one extracted from ogre15).

## Folk (drifters, bandits, camps)
- `characters/folk/drifter.tscn` / `bandit.tscn`: BaseCharacter + mobAI (drifters `aggressive=false`, fight back when hit) + `talker.gd` (look + E: greeting then rumours, random name).
- `folkFigure.gd`: placeholder hooded figure built from primitives. Swap for real models later (use MobModel like the goblin).
- `world/camps.gd` (Camps node): every camp and person on the island is a plain record (`Camp`, `Folk` inner classes), generated at load (~90 ms, ~950 camps / ~2400 people, 1-4 per camp). A slice of records per frame (`records_per_frame`) walks far folk straight to their `home` and spawns/frees real nodes within 120 / past 200 m. Group AI lives on the records: shared aggro per camp, drifter bands migrating to another camp together, bandit bands raiding drifter camps (near the player: real fights via `mobAI.foe`; far: dice rolls kill records). Add new group behaviours in `_tick_camp`. Camps are kept clear of tree roots via `DeadTrees.tree_near()`.
- mobAI holds still beyond 50 m of the player (no terrain/tree colliders out there) and drops onto the ground when it wakes.

## Needs (hunger, thirst)
- `components/needsComponent.gd` (node `needs` on the player): 0-100 hunger/thirst, drain over `*_minutes`, faster sprinting; stage messages via `Talker.notify()`; weak = slower stamina regen; 0 = health loss. Sliders on the node.
- Food/drink items use `spells/effects/nourishEffect.gd` (food / water amounts): bread, dried_meat, water_skin, ash_wine in `items/data/`. In bandit chests and drifter/bandit drops.

## Darkness, coins, trade, jobs
- `components/darknessComponent.gd` (node `darkness` on the player): in light = near a `campfire` or a lit `light_source` torch. Dark: stamina then health drain; mobs aggro from `dark_aggro_multiplier` further.
- Coins = item `coin`; every Item has `value`. A ContainerComponent with `shop = true` (drifters: `talker/wares`) charges value x `sell_markup` to take, pays value x `buy_ratio` to store (`PlayerInventoryUI._pay_for`).
- Talker `gives_jobs`: fetch or bandit-bounty jobs, kept on the Camps `Folk` record (`job`, `asked`); `Camps.bandit_camp_near()`.

## Camp kinds, places, character states
- Camp `kind`: drifter / bandit / goblin / orc. Bandits raid or send roaming war bands (`_send_band`, `_prey_near`).
- Everyone is a character (a `Folk` record) and starts at a fire. No people are placed by the world: what a character is doing is the state of its group (`Camp.wild`: "" at a fire, wanderer, pilgrims, mourner, toll, ambush, starved, stalker, pack, lurer/falselight (orc), homeward). Every state has a way in and out (minds.gd, `_tick_band`, encounters.gd). `Camp.den` = the camp a band goes back to (`_go_home`, `_tick_homeward`; no den = nearest own kind, or a new camp where they stand).
- Places (`_make_encounter`, own grid `encounter_cell`): remains, cairn, hanged, coldfire, spring, fungus (+ bells, salt). `_tick_spot`.
- New characters: `_pull()` every `pull_every` s pulls a lost soul toward a lit fire / cairn (rarer as humans near `souls_target`). Monster dens regrow (`den_regrow`), send packs / false lights (`_den_acts`). Wanderers with a torch who find no fire make one (`_found_camp`, `found_after`, `fire_gap`); groups relight cold fires within `coldfire_spot`; a drifter camp leaves `keepers` behind when it moves.

## Ecosystem (food chain)
- Game: herds (`Camp.wild == "herd"`, `job.count`) breed logistically toward `herd_cap`, split when full (`herds_max`), drift; hunted out = gone (`_tick_herd`, `_new_herd`, Camps > Game).
- Hunting: camplife forage goes to fungus with stock, else the nearest herd (`hunt_range`), follows it, kills `hunt_kills` x `meat_per_kill` raw meat (`hunt()`). No herd, no hunt.
- Sources: springs / fungus / salt share one stock for player and NPCs (`camplife.SOURCES`, `regrow()`, `take()`, `fill_skins()`, `pick_caps()`, source.gd uses the same `regrow`); bare places regrow slower (`bare_slow`); bare ones aren't chosen (`has_stock`).
- Greyhorns (`characters/game/greyhorn.tscn`, placeholder `greyhornFigure.gd`): near you a herd is real bodies (`_herd_bodies_tick`, `herd_show_max`), they bolt from you (`flee_range`); a body you kill drops a `greyhorn_carcass` and lowers the herd's count; sim hunting kills drop bodies with no loot (the hunter has the meat). `raw_meat` = Greyhorn Meat.
- Blackflesh (`blackflesh.tres`, from goblin/orc carcasses and kills): people eat it only when starving (`camplife._best(starving)`), costing light/safety and despair for good (`blackflesh_dark`, `blackflesh_despair`); for you it hurts (DamageEffect). Nobody eats their own kind. `Camps._feed(killer, victim)` runs for dice kills and real fights near you.
- Loaded = sim: asleep bodies (50 m+) walk the record's walk; awake ones off their sim target re-path and step past snags (`unstick_after`); dead characters drop exactly what they carried (`TrainingDummy.exact_loot`).
- Same rules as you: every character has `Folk.hp` (0-100). Out of the light past your DarknessComponent `dread_time` it drains at your `health_drain` (as a share of your max health); food/water at 0 drain it at your NeedsComponent rates (`minds._dark_wears`, `_starve_wears`, `_die`); resting at a fire heals (`rest_heal`). Your hunger/thirst minutes come from Minds `food_drain`/`water_drain`. One torch: `TorchBurn.burn_time` (600 s) and `max_lights` are read by camplife (`npc_torch_time`, `torch_lights`); travellers light only at fires (`tend_torch`), chores carry brands for the trip (shortcut: free until crafting), stationary dark states burn their torches (`lit_until`) and go back when it's out.
- The dead far from you leave a body place (`starved_dead`, `Camps.leave_body`) with what they carried; gone after `body_decay`.
- Soak test: `tools/soak.gd` (headless; deletes the save first).
- Save/load: `world/saveGame.gd` (Camps child "save"). F5 save, F9 load, Shift+F9 fresh island; autosave every `autosave_every` real s and on quit; loads on start if `user://island.save` exists. Saves every Camp/Folk record (references as indices), clock, world log, pull timer, cut trees, storm, and the player (position, stats, needs, respawn, pack with per-item wear/fuel/lights, worn items). Add new record fields to `save()` / `load_world()`.
- Nothing from nothing: traders sell their camp's crate (or their pack on the road; `campStoreSync.whole`, `which = "pack"`) and your coin goes into it, selling is paid from it; job pay / starved thanks come out of their pack and crate, toll coin into the toll-taker's pack. Travellers take `road_share` and `road_torches` from their camp; a fire only lights a torch someone has (a camp of their kind spares one). Coin need = coins held (`minds.coin_worth`). Monster bodies drop their carcass + what they carried. Corpse loot and things you drop become `sack` places (`Camps.drop_sack`, `_tick_sack`) anyone can pick up. Record health (`Folk.hp`) and body health sync both ways (`_hp_from_body` / `_hp_to_body`). You heal at a fire (`DarknessComponent._rest`, Minds `rest_heal`). Shortcut left: chore brands are free until fires need fuel.
- Characters trade (camplife Trade sliders): travellers buy what they lack at a camp of their kind (`buy`, `price` = value x `npc_markup`, above `sell_floor`); a camp short of water/food with coin sends a `trade` chore to the nearest same-kind camp with surplus within `aid_range` (`_seller`), coin into the seller's crate. Raiders who win carry off coin, food and water; war bands pick the richest camp in reach (`_prey_near`).
- Water is the island's limit: a camp with no spring in reach and low water moves (`camplife._plan` evacuate); new fires are only made near a spring (`_room_for_fire`).
- Camp props are real (`Camps._make_real`): every clutter barrel/crate is a container holding its share of `Camp.barrel` / `Camp.crate` (`campStoreSync.gd` splits a store across a camp's containers); bottles/coins/daggers/staffs/swords are `campDisplay.gd` pickups of the camp's crate items (one shown per one they have; `campClutter.ITEMS`, `have` filters what's set out). Camps start with `camplife.goods_start`. Remains hold `Camp.crate` too (`remains_stock`), and NPC looters take exactly that.
- Monsters: hunger (`minds._monster_think`, `monster_food_drain`), eat raw meat from pack / den larder (`Camp.crate`), starve at 0. Hungry packs smell herds (`smell_range`) and bring the kill home (`_pack_hunts`); homeward bands unload into the den / camp stores. Dens grow only when the larder holds `breed_meat`. Off-screen raid kills feed monsters (and people butcher monsters).

## Bleak encounters + ash storm
- `world/encounters.gd` (runtime child `encounters` of Camps; sliders on that node): rules for the bleak states and places: hanged, coldfire, mourner, pilgrims (end at the bell), falselight (a real orc), starved, toll, bell (synth bell sound, Sunken Key), ash storm (fog/sun/ash, `TorchBurn.burn_rate`; hunters are real goblins from the nearest den, `_hunters`). Weights per place in Camps > Places. Talkers get `role` for special lines.

## Minds (needs, traits, memories, rep)
- `world/minds.gd` (runtime child `minds` of Camps): per-Folk `needs`/`traits`/`memories`, `think()` from the Camps sweep picks beg/extort/mourn/pilgrimage/wander/turn/reform/hunt, which `_become()` a one-person encounter. `Camp.rep` from feeding/jobs/trade/kills; `hates()` makes camps attack. Empty drifter camps go `coldfire`. Talkers use `mood_line()`.

## Meetings + food/water sources
- `world/meetings.gd` (runtime child `meetings`): grid of all groups every `meet_every` s; hostile groups raid neighbours, drifters share food / merge / join pilgrims / relight cold fires / loot remains. `log_lines` shown on the M map.
- `world/props/source.gd`: E to drink / fill water skins / take items, stock regrows (state on the Camp record `job`). Springs + ash fungus are encounter kinds; `waterBarrel.tscn` at every drifter camp. Goblins/orcs drop `raw_meat`; fungus gives `ash_cap`.

## Camp life (chores)
- `world/camplife.gd` (runtime child `camplife`): camps keep `supplies` (food) + `water` stores; every `plan_every` s idle members get chores in `Folk.task`: forage (fungus or hunt nearby), water (spring), supply (carry food to a needy drifter camp), evacuate (move camp). `step()` is called from the Camps sweep for loaded and unloaded folk; movement via `_send` so nodes walk it for real. Map draws chore arrows; raid lines are arrows.

## Travellers
- camplife.gd `steer()` (from Camps `_tick_band`): roaming human bands carry torches (`job.fuel`/`spares`), seek springs / fire (own-kind camp or cairn) / fungus by need, rest and take from camp stores, lead holds a `road_torch` when loaded; lit torch refills light (minds).

## Real items (mind redesign stage A+B)
- No abstract stores: `Folk.inv`, `Camp.barrel` / `Camp.crate` (item id -> count). camplife.gd: `self_care()` eats/drinks items (NourishEffect values), chores move items (spring -> water_skin -> barrel, fungus/hunt -> crate), travellers carry skins/food/torches. Camp barrel + crate are chest containers synced by `world/props/campStoreSync.gd` (bandit chest = their crate).

## Open / next
- Rig + animate goblin/orc (Mixamo) — art task, owned by the user.
- Navmesh pathfinding, more mob types. Loot: maybe drop chances later.
