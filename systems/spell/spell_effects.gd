extends Resource
class_name Effect

func effect_attribute(a: Attribute, additive_value: int, additive_modifier: float = 1):
	a.updateValue(additive_value, additive_modifier)
	return a
	
func timer(duration_msec: int) -> bool:
	var init_time: int
	if !init_time:
		init_time = Time.get_ticks_msec()
		print(init_time)
	if Time.get_ticks_msec() < init_time + duration_msec:
		return true
	return false

#func cooldown(timer_amount: float) -> bool:
#	if !is_on_cooldown:
#		while timer(timer_amount):
#			print("time is %s" % [time_pressed])
#			is_on_cooldown = true
#			return true
#	print("cooldown has ended")
#	is_on_cooldown = false
#	return false
