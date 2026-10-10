# b3dp.mw — project notes

Godot 4.7 first-person RPG prototype (Morrowind-style). GDScript. Main scene: `test_level.tscn`.
Repo: github.com/sethdexter/b3dp.mw (branch main). Big source art (`*.blend`, `*.psd`) is gitignored.

## Working conventions
- Edit files directly in this folder. Close a script in the Godot editor before external edits, or it may save its old copy over them.
- Watch for load cycles: don't `preload` scenes that lead back to the preloading script (caused "non-existent resource" errors). Use `load()` at runtime instead.
- Item data is shared through `Item.get_template()`: per-instance copies are made with `make_instance()`, and held/equip/consume values are read from the original `.tres`.
- The player is in group `"player"`. `BaseCharacter.is_dead` locks input and AI.

## Character architecture (BaseCharacter + component nodes)
`systems/character/basecharacter.gd`: exports refs to the components below, plus `starting_items`.
- `attributesComponent`: strength, vigor, agility, intelligence, wisdom (`base_*` exports, `get_attribute(name)`).
- `statsComponent`: health (str/vig), stamina (vig/agi), magicka (int/wis). Regen, `spend_stamina`, `has_stamina`, `restore_all`. Emits `s_has_died`.
- `skillsComponent`: 12 skills (`get_skill(id)`). `Skill` levels from XP (`add_xp`).
- `combatComponent`: `attack()` uses the equipped weapon and its best damage type, scaled by attribute + skill; `take_damage()` subtracts armour (piece × armour-skill bonus) and trains armour skills.
- `inventoryComponent`: `Dictionary[Item, int]` stacks; respects `maxStackCount`, overflow creates new stacks.
- `equipmentComponent`: slots right_hand/left_hand/head/chest/feet/back; applies attribute modifiers; `get_weapon()`, `get_armor_pieces()`.
- `controllerComponent`: movement (walk toggle Caps, sprint Shift, dash Alt, eased; stamina costs), mouse look, E interact via raycast.
- `meleeComponent` (LMB swing), `spellCasterComponent` (RMB, `Spell` resources in `databases/spell_database`), `heldItemsComponent` (first-person held items), `respawnComponent` (death fade + respawn).

## UI (`systems/ui`)
- `itemListView.gd`: shared list (chest bottom-left, player bottom-right). Parchment text, highlight sized to the text.
- `playerInventoryUI`: Tab open, wheel select, RMB switch side, LMB take/store/equip/use, Q drop (Shift = stack).
- `screenEffects`: no HUD bars. Health = red vignette, desaturation, heartbeat; magicka = desaturation; stamina = blur + breathing edges; `fade_to()`.

## Items
`databases/item.gd` (Item), `weaponItem.gd`, registry autoload `item_list` (`databases/itemDB.gd`, keyed by id string).
Items: torch, swords, leather cap/cuirass (light), iron boots (heavy), travel cloak, health/magicka/stamina potions.
World pickups: `InteractableComponent` (itemId, or a runtime `item`). Dropped items: `systems/items/droppedItem.tscn`.

## Mobs
- `mobAIComponent`: idle → wander → chase (sight/aggro on hit) → attack (telegraph) → return (leash). Direct steering, no navmesh yet.
- `trainingDummy.gd`: hit wobble/knockdown; `respawns=false` for real mobs (corpse sinks, then freed). `loot` (id → amount) spawns DroppedItems on death (goblin: rusty sword + health potion; orc: black iron sword + 2 stamina potions).
- `mobModel.gd`: instances an FBX, strips lights/cameras, fits height, applies textures by material name, plays clips by role (idle/walk/run/attack/hit/death) from `animations_folder` (matched by filename) or `animation_sources`; procedural bob if no clips.
- Mobs: `systems/character/mobs/goblin.tscn`, `orc.tscn`. Old dummies: `trainingDummy.tscn`, `bruteDummy.tscn`.
- Art: `assets/models/characters/goblin|orc`. Clips go in `anims/` (Mixamo, In Place, FBX with skin). The orc is unrigged; its real colour texture is missing (using one extracted from ogre15).

## Open / next
- Rig + animate goblin/orc (Mixamo) — art task, owned by the user.
- Navmesh pathfinding, more mob types. Loot: maybe drop chances later.
