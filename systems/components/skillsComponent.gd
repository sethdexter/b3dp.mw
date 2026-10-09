extends Node
class_name SkillsComponent

@export var currentCharacter: Node3D

##declared here as lost of skills is static
var short_blade: Skill = Skill.new("Short Blade")
var long_blade:  Skill = Skill.new("Long Blade");
var light_armor: Skill = Skill.new("Light Armour")
var heavy_armor: Skill = Skill.new("Heavy Armour");
var destruction: Skill = Skill.new("Destruction")
var restoration: Skill = Skill.new("Restoration");
var mysticism:   Skill = Skill.new("Mysticism")
var alteration:  Skill = Skill.new("Alteration");
var stealth:     Skill = Skill.new("Stealth")
var deception:   Skill = Skill.new("Deception");                                           
var athletics:   Skill = Skill.new("Athletics")
var acrobatics:  Skill = Skill.new("Acrobatics");

##so accessable
var skills_list = [short_blade, long_blade, light_armor, heavy_armor,
				   destruction, restoration, mysticism, alteration,
				   stealth, deception, athletics, acrobatics]

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
