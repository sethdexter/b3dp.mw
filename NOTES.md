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

## Camp kinds and encounters
- Camp `kind`: drifter / bandit / goblin / orc. Bandits raid or send roaming war bands (`_send_band`, `_prey_near`).
- Encounters (`Camp.wild`, own grid `encounter_cell`): wanderer, pack (roam forever), ambush (static bandits, no fire), remains (clutter + loot sack, `looted`), cairn (lone burning torch). `_make_encounter`, `_tick_spot`.

## Bleak encounters + ash storm
- `world/encounters.gd` (runtime child `encounters` of Camps; sliders on that node): hanged, coldfire, mourner, pilgrims, falselight, starved, toll, bell (synth bell sound, Sunken Key), ash storm (fog/sun/ash, `TorchBurn.burn_rate`, goblin hunters). Weights per kind in Camps > Encounters. Talkers get `role` for special lines.

## Minds (needs, traits, memories, rep)
- `world/minds.gd` (runtime child `minds` of Camps): per-Folk `needs`/`traits`/`memories`, `think()` from the Camps sweep picks beg/extort/mourn/pilgrimage/wander/turn/reform/hunt, which `_become()` a one-person encounter. `Camp.rep` from feeding/jobs/trade/kills; `hates()` makes camps attack. Empty drifter camps go `coldfire`. Talkers use `mood_line()`.

## Meetings + food/water sources
- `world/meetings.gd` (runtime child `meetings`): grid of all groups every `meet_every` s; hostile groups raid neighbours, drifters share food / merge / join pilgrims / relight cold fires / loot remains. `log_lines` shown on the M map.
- `world/props/source.gd`: E to drink / fill water skins / take items, stock regrows (state on the Camp record `job`). Springs + ash fungus are encounter kinds; `waterBarrel.tscn` at every drifter camp. Goblins/orcs drop `raw_meat`; fungus gives `ash_cap`.

## Open / next
- Rig + animate goblin/orc (Mixamo) — art task, owned by the user.
- Navmesh pathfinding, more mob types. Loot: maybe drop chances later.
