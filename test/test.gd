extends Resource
class_name Test

var my_thread: Thread = Thread.new()
var result: int = 0

func t_thread():
	pass
	
var is_active: bool
var init_time: int

func timer(duration_msec: int) -> bool:
	
	if !init_time:
		init_time = Time.get_ticks_msec()

	if Time.get_ticks_msec() < init_time + duration_msec:
		
		#print(Time.get_ticks_msec())
		#print(init_time + duration_msec)
		#print(false)
		return true
	return false
 
	#my_thread.start(calculate_sum)
#			print("Thread started for calculation.")

	# Wait for the thread to finish
	#result = my_thread.wait_to_finish() 
	#print("Calculation complete! Result:", result)
	#ass

func _ready():
	print("test model init..")

#func calculate_sum(duration):
#	return
	#var sum = 0
	#for i in range(start, end + 1):
	#	sum += i
	#return sum 
