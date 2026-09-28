# Modular Architecture Objectives

## Vision

Build the game as a modular, component-based RPG where complex scenes are assembled from small reusable parts.

The architecture should support players, enemies, containers, pickups, doors, switches, spell targets, and other world objects without creating large monolithic scripts.

## Core Rules

- Resources contain data.
- Components contain behavior.
- Actors compose components.
- Scenes define composition and presentation.
- Signals connect systems without unnecessary hard references.
- Shared behavior belongs in reusable components, not level scripts.
- Gameplay tests should live in dedicated test scenes or test scripts, not production initialization code.

## Target Project Structure

```text
systems/
├── actors/
│   ├── base_actor.gd
│   ├── character.gd
│   └── enemy.gd
├── components/
│   ├── movement/
│   ├── interaction/
│   ├── inventory/
│   ├── equipment/
│   ├── combat/
│   ├── attributes/
│   ├── stats/
│   └── effects/
├── resources/
│   ├── items/
│   ├── weapons/
│   ├── armor/
│   ├── spells/
│   └── abilities/
└── world/
    ├── interactables/
    ├── containers/
    ├── pickups/
    └── damage_zones/
```

## Actor Composition

### Player

```text
Player
├── CharacterBody3D
├── Visuals
├── CameraRig
├── MovementComponent
├── InteractionComponent
├── AttributesComponent
├── StatsComponent
├── InventoryComponent
├── EquipmentComponent
├── CombatComponent
└── EffectsComponent
```

### Enemy

```text
Enemy
├── CharacterBody3D
├── EnemyMovementComponent
├── DetectionComponent
├── AttributesComponent
├── StatsComponent
├── CombatComponent
└── LootComponent
```

Actors should only compose and expose their components. They should not contain every gameplay system themselves.

## Component Responsibilities

### MovementComponent

Own movement, gravity, jumping, sprinting, camera movement, and eventually movement states.

### InteractionComponent

Detect the object in front of the actor, manage the active interaction prompt, and activate the selected interactable.

It should not contain inventory, chest, or item-specific logic.

### InventoryComponent

Own stored item instances, stack counts, weight limits, encumbrance, and inventory signals.

### EquipmentComponent

Own equipment slots, equip and unequip operations, and equipment-related signals.

### CombatComponent

Own attack requests, damage application, healing, armor mitigation, and combat signals.

### StatsComponent

Own health, stamina, magicka, death/depletion signals, and current resource values.

### EffectsComponent

Own temporary buffs, debuffs, damage-over-time effects, and effect expiration.

## Resource Responsibilities

Items, weapons, armor, spells, skills, and effects should be data resources. They should define values and configuration without directly controlling scene nodes.

Suggested item hierarchy:

```text
Item
├── WeaponItem
├── ArmorItem
├── ConsumableItem
└── QuestItem
```

## World Object Composition

A chest should be assembled rather than implemented as one large script:

```text
Chest
├── Mesh
├── CollisionShape3D
├── InteractableComponent
└── ContainerComponent
```

The interaction component detects the chest. The container component owns its contents. The player inventory component handles item transfer.

The same pattern should later support:

- Pickups
- Doors
- Switches
- Levers
- NPC conversations
- Spell targets
- Damage zones
- Loot containers

## Implementation Objectives

- [x] Choose one authoritative movement architecture.
- [x] Keep RPG systems separate from locomotion.
- [x] Clean up and standardize the Item API.
- [x] Split interaction detection from movement.
- [x] Create a reusable InteractionComponent.
- [x] Create a reusable ContainerComponent.
- [x] Build one complete modular chest.
- [x] Support chest interaction, prompts, contents, and loot transfer.
- [x] Move character combat and inventory tests out of `BaseCharacter._ready()`.
- [x] Create a dedicated character/system test scene.
- [x] Replace direct cross-component assumptions with signals or clear interfaces.
- [x] Add reusable enemy composition using the same stats and combat systems.
- [x] Add spell and effect composition after the item and combat foundations are stable.

## Architecture Decisions

### Movement Authority

The project will keep `systems/components/controllerComponent.gd` as the authoritative movement controller for the current player.

Reasons:

- It is the controller instantiated by the active `player.tscn`.
- It already fits the component-based RPG architecture.
- It keeps the player scene and RPG systems under project ownership.
- It avoids replacing the active player with the imported addon architecture before the project has a clear need for its extra movement states.

The `addons/fp_controller` FSM remains a reference and optional future source for crouch, climb, slide, and other movement states. It should not run alongside `ControllerComponent`.

### Interaction Boundary

`ControllerComponent` owns movement and camera behavior only. `InteractionComponent` owns the interaction raycast, active target, prompt visibility, and interaction activation.

The interaction component is attached separately to the player scene and passes the player actor to world-side interactables. This keeps locomotion independent from chests, pickups, containers, and other world behaviors.

### Container and Chest Prototype

The first container prototype is now data-driven. The chest scene provides an `item_ids` list to `ContainerComponent`, which resolves item resources through `item_list` and transfers its contents through the actor's `inventoryComponent`.

The container is one-time use for now. It records an opened state, emits `opened`, `inventory_updated`, and `emptied`, and blocks duplicate transfers. Chest animation, a real container inventory UI, and partial item selection remain presentation and interaction follow-up work.

### Item API

The existing `Item` resource schema remains the source of truth for the current prototype:

- `Name` identifies the display name.
- `isEquippable` controls whether equipment is allowed.
- `equippableSlots` lists valid equipment slots.
- `isEquipped` tracks the current equipment state.

`EquipmentComponent` now uses this schema consistently and emits `equipment_changed` after successful changes.

### Character System Tests

Production character spawning no longer adds test items, performs self-attacks, or runs the timer probe. Those checks now live in `test/character_system_test.tscn` and `test/character_system_test.gd`.

### Capability Boundaries

Actors now expose small capability methods for world and combat systems:

- `receive_item(item, amount)`
- `receive_damage(raw_damage)`
- `receive_healing(amount)`

Containers, pickups, and combat no longer need to reach directly into another actor's inventory, stats, or combat child nodes. Component signals continue to report inventory, equipment, stat, and container changes.

### Enemy Composition

`systems/actors/enemy.tscn` composes the shared attributes, stats, skills, inventory, equipment, and combat components without including the player camera or movement controller. The character system test scene now verifies player-to-enemy damage through the shared actor capability boundary.

### Spell and Effect Foundation

Spells are now data resources with costs, cooldown metadata, and typed effect resources. `EffectComponent` owns active effect references and emits `effects_changed`. `databases/spell_database/firebolt.tres` is the first sample composition.

Casting rules, resource costs, timed expiration, and visual spell delivery are intentionally follow-up systems; the resource boundary is established first.

## First Milestone: Modular Chest

The first proof of the architecture should be a complete chest workflow:

1. Player raycasts against an interactable chest.
2. The chest displays an interaction prompt.
3. The player presses the interaction action.
4. The chest opens or changes state.
5. The container exposes its item contents.
6. Items transfer into the player inventory.
7. Inventory emits an update signal.
8. The chest prevents invalid duplicate transfers.

The chest should work without knowing the concrete player scene. It should depend on an inventory capability or interface instead.

## Current Project Risks

- There are two competing movement/controller systems: the custom controller and the imported FSM controller.
- `BaseCharacter._ready()` currently performs combat and inventory test actions.
- `EquipmentComponent` uses property names that do not match the current `Item` resource API.
- Interaction activation currently has more than one possible trigger path.
- Input action names are split between custom movement names and Godot `ui_*` names.
- Several systems are still experimental and should be promoted only after they have a concrete scene use case.

## Definition of Done

The architecture is moving in the right direction when:

- A new actor can be assembled mostly by adding components to a scene.
- A new interactable does not require changes to the player controller.
- Items can be added or changed through resources rather than hardcoded scripts.
- Combat works for both players and enemies through shared components.
- Components communicate through typed references, signals, or small capability interfaces.
- Test behavior is isolated from production gameplay scenes.
- A complex level script is not required to coordinate ordinary object behavior.
