extends Node
class_name Timer_Test

var timer : Timer

func _ready():
	# Create a new Timer node
	timer = Timer.new()
	# Add the Timer as a child of this object
	add_child(timer)
	
	# Set it to one-shot (it will stop after it finishes)
	timer.one_shot = true
	# Set the duration for the timer (in seconds)
	timer.wait_time = 5 #seconds
	# Start the timer	
	timer.start()
	# Connect the timeout signal to the _on_timeout method
	#timer.connect("timeout", self, "_on_timeout")

# This function is called when the timer finishes
func _on_timeout():
	print("Timer finished!")
	# Perform any actions needed when the timer ends
