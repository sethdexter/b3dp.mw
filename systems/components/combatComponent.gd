extends Node
class_name CombatComponent

@export var currentCharacter: Node3D
## Base (natural) armour. Equipped armour is added on top, see get_armor().
@export var armor_rating: int = 0

func _ready():
	print("Combat component initialized for: ", currentCharacter.name)

## Base armour + armour from equipped items.
## Base armour + equipped armour, each piece boosted by its armour skill.
func get_armor() -> float:
	var total := float(armor_rating)
	var equip = _equipment()
	if equip:
		for piece: Item in equip.get_armor_pieces():
			var mult := 1.0
			var skill := _get_skill(piece.get_armor_skill())
			if skill:
				mult += (skill.get_level() - 1) * armor_skill_scale
			total += piece.get_armor_rating() * mult
	return total

func _equipment() -> EquipmentComponent:
	if currentCharacter and "equipmentComponent" in currentCharacter:
		return currentCharacter.equipmentComponent
	return null

## When hit, one worn armour piece (weighted by its rating) trains its skill.
func _train_armor() -> void:
	var equip = _equipment()
	if not equip:
		return
	var pieces: Array[Item] = equip.get_armor_pieces()
	if pieces.is_empty():
		return
	var total := 0
	for p in pieces:
		total += p.get_armor_rating()
	var roll := randi_range(1, total)
	for p in pieces:
		roll -= p.get_armor_rating()
		if roll <= 0:
			train_skill(p.get_armor_skill(), xp_per_hit)
			return

## Currently equipped weapon (right hand), or null.
func get_weapon() -> WeaponItem:
	if currentCharacter and "equipmentComponent" in currentCharacter and currentCharacter.equipmentComponent:
		return currentCharacter.equipmentComponent.get_weapon()
	return null

# Takes damage and applies armor mitigation
func take_damage(target_stat: Stat, raw_damage: int):
	# Simple armor math: Damage - Armor (Minimum 1 damage)
	var final_damage: int = maxi(1, roundi(raw_damage - get_armor()))
	
	# We use change_current with a negative value for damage
	target_stat.change_current(-final_damage)
	_train_armor()
	
	print("%s took %d damage (%d mitigated). Remaining: %d" % [
		currentCharacter.name, 
		final_damage, 
		raw_damage - final_damage, 
		target_stat.currentValue
	])

func heal_damage(target_stat: Stat, amount: int):
	target_stat.change_current(amount)
	print("%s healed for %d. Current: %d" % [
		currentCharacter.name, 
		amount, 
		target_stat.currentValue
	])

## How much each point above 10 in the attribute adds to damage.
@export var attribute_damage_scale: float = 0.03
## How much each skill level above 1 adds to damage.
@export var skill_damage_scale: float = 0.05
## XP gained per successful hit.
@export var xp_per_hit: float = 1.0
## How much each armour skill level above 1 adds to that piece's armour.
@export var armor_skill_scale: float = 0.05

## weapon: defaults to the equipped weapon.
## attack_type: "slashDamage" / "pierceDamage" / "bludgeiningDamage"; defaults to the weapon's strongest.
func attack(target_character: BaseCharacter, weapon: WeaponItem = null, attack_type: String = ""):
	if weapon == null:
		weapon = get_weapon()
	if weapon == null:
		print("No weapon equipped!")
		return

	if attack_type == "":
		attack_type = _best_attack_type(weapon)
	var base_damage: int = weapon.attackTypes.get(attack_type, 0)
	var damage_value := scaled_damage(base_damage, weapon.governingSkill, "strength")

	var target_health = target_character.statComponent.health

	print("%s attacks %s for %d %s damage!" % [currentCharacter.Name, target_character.Name, damage_value, attack_type])

	target_character.combatComponent.take_damage(target_health, damage_value)
	train_skill(weapon.governingSkill, xp_per_hit)

## Base damage scaled by an attribute (10 = no change) and a skill (level 1 = no change).
func scaled_damage(base_damage: int, skill_name: String, attribute_name: String) -> int:
	var mult := 1.0
	var attrs = currentCharacter.get("attributeComponent") if currentCharacter else null
	if attrs:
		var attr: Attribute = attrs.get_attribute(attribute_name)
		if attr:
			mult += (attr.get_value() - 10) * attribute_damage_scale
	var skill := _get_skill(skill_name)
	if skill:
		mult += (skill.get_level() - 1) * skill_damage_scale
	return maxi(1, roundi(base_damage * maxf(0.1, mult)))

## Give XP to one of this character's skills (no-op if missing).
func train_skill(skill_name: String, amount: float) -> void:
	var skill := _get_skill(skill_name)
	if skill:
		skill.add_xp(amount)

func _get_skill(skill_name: String) -> Skill:
	var skills = currentCharacter.get("skillComponent") if currentCharacter else null
	return skills.get_skill(skill_name) if skills else null

func _best_attack_type(weapon: WeaponItem) -> String:
	var best := ""
	var best_value := -1
	for key in weapon.attackTypes:
		if weapon.attackTypes[key] > best_value:
			best = key
			best_value = weapon.attackTypes[key]
	return best

# Inside CombatComponent.gd

func heal(target_character: BaseCharacter, target_stat: Stat, amount: int):
	if target_character == null or target_stat == null:
		print("Heal failed: Target or Stat is null")
		return
	
	var f_string = "%s heals %s for %d!..." % [currentCharacter.Name, target_character.Name, amount]
	print(f_string)
	
	# We call the target's combatComponent to handle the actual resource change
	# This ensures the logic (and any local mitigation/buffs) stays with the receiver
	target_character.combatComponent.heal_damage(target_stat, amount)

func heal_target(target_character: BaseCharacter, amount: int):
	print("%s casts heal on %s!" % [currentCharacter.name, target_character.name])
	var target_health = target_character.statComponent.health
	target_character.combatComponent.heal_damage(target_health, amount)
