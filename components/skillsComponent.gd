extends Node
class_name SkillsComponent

@export var currentCharacter: Node3D

##declared here as lost of skills is static
var short_blade: Skill = Skill.new("Short Blade")
var long_blade:  Skill = Skill.new("Long Blade");
var light_armor: Skill = Skill.new("Light Armour")
var heavy_armor: Skill = Skill.new("Heavy Armour");
## The two schools of magic. Lux: fire and warmth (safe, but it eats what the fire eats). Nox: the dark's own power
## (cheap, but every cast costs you light: the dread creeps closer, and for the island's people, despair).
var lux: Skill = Skill.new("Lux")
var nox: Skill = Skill.new("Nox")
var stealth:     Skill = Skill.new("Stealth")
var deception:   Skill = Skill.new("Deception");                                           
var athletics:   Skill = Skill.new("Athletics")
var acrobatics:  Skill = Skill.new("Acrobatics");
## Gathering (world/camplife.gd gather()): the more practised, the more you get out of the same tree, patch or kill.
var woodcraft:   Skill = Skill.new("Woodcraft") # chopping, cutting sap
var foraging:    Skill = Skill.new("Foraging") # fungus, salt
var hunting:     Skill = Skill.new("Hunting") # butchering a carcass

##so accessable
var skills_list = [short_blade, long_blade, light_armor, heavy_armor,
				   lux, nox,
				   stealth, deception, athletics, acrobatics, woodcraft, foraging, hunting]

##ability list is dynamic
var abilities_dict = {
	"slot_1": ""
}

## Look up a skill by id or name: "long_blade", "Long Blade". Null if unknown.
func get_skill(skill_name: String) -> Skill:
	if skill_name == "":
		return null
	var value = get(skill_name.to_lower().replace(" ", "_"))
	return value if value is Skill else null

func list_skills():
	for i in skills_list:
		print("%s: %d" % [i.Name, i.get_level()])
	return
	
func _ready():
	for skill in skills_list:
		if (skill):        
			continue
	print("skills component initialized...")
